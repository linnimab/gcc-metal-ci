// gcc_metal_beauty.m — Metal 美颜渲染器实现
//
// 遵循 gcc_metal_beauty.h 的接口。核心设计：
//   - 每个 pass 用一个 render pipeline，可单独开关
//   - 中间结果在私有纹理间 ping-pong
//   - 网格/贴图数据来自 gcc_face_mesh / gcc_makeup_map（纯 C 模块）

#import "gcc_metal_beauty.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include "gcc_face_mesh.h"
#include "gcc_makeup_map.h"

#include <string.h>
#include <math.h>

// ============================ 参数默认值 ============================

GccBeautyParams gcc_beauty_params_neutral(void) {
    GccBeautyParams p;
    memset(&p, 0, sizeof(p));

    // ---------- 形变组：全部 0.0（中性）----------
    // ★ 量纲有两层，别混：
    //   层 1 槽位/UI/持久化：0..1，0.5 中性（effect_slots.c、GccSlotPanel、
    //      NSUserDefaults 都存在这一层，保持不动）
    //   层 2 GccBeautyParams → MeshWarpParams：-1..1，0 中性
    //      beautyParams 里的 W(tag) / WA(i) 完成层 1→层 2 的换算，
    //      并按 gcc_deform_coef.h 乘抖音官方系数。
    //   beauty.m 打包时直接 wp.xxx = pp.xxx，不再减 0.5。
    // 所以 memset 置 0 对形变组恰好就是中性，下面显式赋值只为便于审阅。
    p.faceSlim       = 0.0f;   // [2]  瘦脸
    p.headSmall      = 0.0f;   // [3]  小头
    p.eyeSize        = 0.0f;   // [4]  大眼
    p.pupilSize      = 0.0f;   // [6]  瞳孔大小
    p.lowerEyelid    = 0.0f;   // [7]  眼睑下至
    p.smile          = 0.0f;   // [10] 微笑
    p.faceSmall      = 0.0f;   // [11] 小脸
    p.cheekbone      = 0.0f;   // [14] 立体
    p.mouthShape     = 0.0f;   // [18] 嘴形
    p.mouthPos       = 0.0f;   // [19] 嘴巴位置
    p.mouthWidth     = 0.0f;   // [20] 嘴巴宽度
    p.upperLip       = 0.0f;   // [21] 丰上唇
    p.foreheadHeight = 0.0f;   // [22] 额头
    p.cutFace        = 0.0f;   // [23] 窄脸
    p.cheekboneSlim  = 0.0f;   // [24] 瘦颧骨
    p.chinLength     = 0.0f;   // [25] 下颚
    p.noseSlim       = 0.0f;   // [26] 瘦鼻
    p.noseWidth      = 0.0f;   // [27] 鼻翼
    p.noseBridge     = 0.0f;   // [28] 鼻梁
    p.eyeDist        = 0.0f;   // [30] 眼距
    p.eyeCorner      = 0.0f;   // [31] 眼角
    p.eyePos         = 0.0f;   // [32] 眼位
    p.nosePos        = 0.0f;   // [33] 鼻位
    p.eyeTailUp      = 0.0f;   // [34] 眼尾上扬
    p.browLift       = 0.0f;   // [35] 眉挑
    p.chinPointy     = 0.0f;   // [36] 尖下巴

    // ---------- 调色组：0.5（中性）----------
    p.brightness  = 0.5f;
    p.contrast    = 0.5f;
    p.saturation  = 0.5f;
    p.temperature = 0.5f;

    // ---------- 美颜 / 妆容：0（关闭）----------
    // memset 已置 0，这里显式写出便于审阅，防止将来改 memset
    p.smooth = p.whiten = p.clarity = p.rosy = 0.0f;
    p.darkCircle = p.nasolabial = p.eyeBrighten = 0.0f;
    p.lipColor = p.blush = p.eyeShadow = p.eyebrow = p.teeth = 0.0f;
    p.foundation = 0.0f;
    p.lipFrostbite = p.lipRetro = p.lipGrapefruit = p.lipVitality = 0.0f;
    p.blushFrostbite = p.blushRose = p.blushOrange = p.blushBrown = 0.0f;
    p.eyeShadowMale = 0.0f;
    p.presetFairy = p.presetDewy = p.presetHazy = p.presetVFace = 0.0f;
    p.vignette = p.grain = 0.0f;

    return p;
}

// ============================ Metal 结构体（与 shader 对应）============================

typedef struct { float m[9]; float off[3]; } YUVUniform;

typedef struct {
    float texelSize[2];
    float intensity;
    float radius;
} SmoothUniform;


typedef struct {
    float stX[4];
    float stY[4];
    float color[4];
    float intensity;
    float texelSize[2];
    float useTexture;
} MakeupUniform;

typedef struct {
    float brightness, contrast, saturation, temperature;
    float vignette, grain, lutMix, seed;
    float lutSize;
} ColorUniform;


// ============================ 实现 ============================

@implementation GccMetalBeauty {
    id<MTLDevice>              _device;
    id<MTLCommandQueue>        _queue;

    // 相机帧零拷贝纹理缓存
    CVMetalTextureCacheRef _texCache;
    id<MTLRenderPipelineState> _pipeBGRA;

    // pipelines
    id<MTLRenderPipelineState> _pipeYUV;
    id<MTLRenderPipelineState> _pipeSmooth;
    id<MTLRenderPipelineState> _pipeMakeup;
    id<MTLRenderPipelineState> _pipeColor;
    id<MTLRenderPipelineState> _pipeGrade;
    id<MTLRenderPipelineState> _pipePass;

    // 中间纹理（ping-pong）
    id<MTLTexture> _texA;
    id<MTLTexture> _texB;
    id<MTLTexture> _texMask;
    id<MTLTexture> _texLUT;
    id<MTLTexture> _texFlow;    // 官方 faceMask.png（B/G → RG 位移编码）
    id<MTLTexture> _texFlowMask; // 人脸蒙版
    GccFlowParams _flowParams;

    // 妆容贴图（按 role）
    NSMutableDictionary<NSString*, id<MTLTexture>> *_makeupTex;
    NSMutableDictionary<NSString*, NSData*>        *_makeupMat;   // uSTMatrix

    // 网格（NSData 原始 + MTLBuffer 上传后）
    NSMutableDictionary<NSString*, NSData*> *_meshData;
    NSMutableDictionary<NSString*, id<MTLBuffer>> *_meshVB;
    NSMutableDictionary<NSString*, id<MTLBuffer>> *_meshIB;
    NSMutableDictionary<NSString*, NSNumber*>     *_meshIdxCount;

    // 网格渲染 pipeline
    id<MTLRenderPipelineState> _pipeMesh;
    id<MTLRenderPipelineState> _pipeFlow;

    // 人脸关键点（归一化）
    float  _landmarks[256];
    int    _landmarkCount;
    float  _faceMaskConf;   // 掩膜淡入淡出置信度 0~1
    int    _filterV2;       // 官方 FilterV2 档位 0=无 / 1..3=main.scene 三档
    float  _fvExposure, _fvBrightness, _fvTemperature, _fvTint;
    float  _fvContrast, _fvSaturation, _fvIntensity;
    BOOL   _mirror;                 // 前置镜像开关

    // 调色参数（与 color_fx.h 的 GccColorFx 一一对应）
    float  _fxBright, _fxContra, _fxSatur, _fxWarm;
    float  _fxVign, _fxGrain, _fxLutMix, _fxSeed;
    BOOL   _fxReady;

    // 状态
    NSUInteger _texWidth;
    NSUInteger _texHeight;
    NSMutableString *_diag;

    // 当前激活的妆角色号（决定 makeup pass 用哪张贴图）
    NSString *_activeMakeupRole;

    // 资源自检表：role -> 状态字符串
    NSMutableDictionary<NSString*, NSString*> *_checklist;
    NSString *_resourceRoot;
}

- (nullable instancetype)initWithDevice:(id<MTLDevice>)device
                        colorPixelFormat:(MTLPixelFormat)format
                           resourceRoot:(NSString *)resourceRoot {
    self = [super init];
    if (!self || !device) return nil;

    _device = device;
    _queue = [device newCommandQueue];
    if (!_queue) return nil;

    _resourceRoot = resourceRoot ?: @"";
    _makeupTex = [NSMutableDictionary dictionary];
    _makeupMat = [NSMutableDictionary dictionary];
    _meshData  = [NSMutableDictionary dictionary];
    _meshVB    = [NSMutableDictionary dictionary];
    _meshIB    = [NSMutableDictionary dictionary];
    _meshIdxCount = [NSMutableDictionary dictionary];
    _diag = [NSMutableString string];
    _checklist = [NSMutableDictionary dictionary];
    _landmarkCount = 0;

    // 编译 shader：从 bundle 里找 default.metallib
    NSError *err = nil;
    id<MTLLibrary> lib = [device newDefaultLibrary];
    if (!lib) {
        // 尝试从资源目录加载源码编译
        NSString *metalPath = [resourceRoot stringByAppendingPathComponent:@"gcc_beauty.metal"];
        NSString *src = [NSString stringWithContentsOfFile:metalPath
                                                  encoding:NSUTF8StringEncoding
                                                     error:&err];
        if (src) {
            lib = [device newLibraryWithSource:src options:nil error:&err];
        }
    }
    if (!lib) {
        [_diag appendFormat:@"metallib=MISSING(%@) ", err.localizedDescription ?: @"nil"];
        return nil;
    }
    [_diag appendString:@"lib=ok "];

    // 构建各 pipeline
    #define MKPIPE(ivar, frag) do { \
        MTLRenderPipelineDescriptor *d = [MTLRenderPipelineDescriptor new]; \
        d.vertexFunction   = [lib newFunctionWithName:@"gcc_fullscreen_vertex"]; \
        d.fragmentFunction = [lib newFunctionWithName:frag]; \
        d.colorAttachments[0].pixelFormat = format; \
        ivar = [device newRenderPipelineStateWithDescriptor:d error:&err]; \
        if (!ivar) [_diag appendFormat:@"%s=FAIL ", [frag UTF8String]]; \
    } while (0)

    // CVMetalTextureCache：CVPixelBuffer → Metal texture 零拷贝
    CVReturn cvr = CVMetalTextureCacheCreate(kCFAllocatorDefault, NULL,
                                             _device, NULL, &_texCache);
    if (cvr != kCVReturnSuccess) {
        [_diag appendFormat:@"texCache=FAIL(%d) ", cvr];
    }

    MKPIPE(_pipeBGRA,   @"gcc_bgra_to_rgba");
    MKPIPE(_pipeYUV,    @"gcc_yuv_to_rgb");
    MKPIPE(_pipeSmooth, @"gcc_smooth");
    MKPIPE(_pipeMakeup, @"gcc_makeup");
    MKPIPE(_pipeColor,  @"gcc_color_grade");
    MKPIPE(_pipeGrade,  @"gcc_grade_msl");
    MKPIPE(_pipePass,   @"gcc_passthrough");
    #undef MKPIPE

    // 网格渲染 pipeline（带顶点属性）
    {
        MTLVertexDescriptor *vd = [MTLVertexDescriptor vertexDescriptor];
        // attribute 0: screenPos (float2)
        vd.attributes[0].format = MTLVertexFormatFloat2;
        vd.attributes[0].offset = 0;
        vd.attributes[0].bufferIndex = 0;
        // attribute 1: templPos (float2)
        vd.attributes[1].format = MTLVertexFormatFloat2;
        vd.attributes[1].offset = sizeof(float) * 2;
        vd.attributes[1].bufferIndex = 0;
        // attribute 2: uv (float2)
        vd.attributes[2].format = MTLVertexFormatFloat2;
        vd.attributes[2].offset = sizeof(float) * 4;
        vd.attributes[2].bufferIndex = 0;
        // 每顶点 6 float
        vd.layouts[0].stride = sizeof(float) * 6;

        MTLRenderPipelineDescriptor *d = [MTLRenderPipelineDescriptor new];
        d.vertexFunction   = [lib newFunctionWithName:@"gcc_mesh_vertex"];
        d.fragmentFunction = [lib newFunctionWithName:@"gcc_mesh_fragment"];
        d.vertexDescriptor = vd;
        d.colorAttachments[0].pixelFormat = format;
        _pipeMesh = [device newRenderPipelineStateWithDescriptor:d error:&err];
        if (!_pipeMesh) {
            [_diag appendFormat:@"pipeMesh=FAIL(%@) ", err.localizedDescription ?: @"nil"];
        } else {
            [_diag appendString:@"pipeMesh=ok "];
        }
    }

    // ★ 官方 freid 位移场 pass（gcc_flow_warp）
    {
        MTLRenderPipelineDescriptor *d = [MTLRenderPipelineDescriptor new];
        d.vertexFunction   = [lib newFunctionWithName:@"gcc_fullscreen_vertex"];
        d.fragmentFunction = [lib newFunctionWithName:@"gcc_flow_warp"];
        d.colorAttachments[0].pixelFormat = format;
        _pipeFlow = [device newRenderPipelineStateWithDescriptor:d error:&err];
        if (!_pipeFlow) {
            [_diag appendFormat:@"pipeFlow=FAIL(%@) ", err.localizedDescription ?: @"nil"];
        } else {
            [_diag appendString:@"pipeFlow=ok "];
        }
    }

    [_diag appendString:@"pipes=ok "];
    return self;
}

// ---------------------------- 纹理管理 ----------------------------

- (BOOL)ensureTextures:(NSUInteger)w height:(NSUInteger)h {
    if (_texA && _texWidth == w && _texHeight == h) return YES;

    MTLTextureDescriptor *d =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                           width:w height:h mipmapped:NO];
    d.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite
            | MTLTextureUsageRenderTarget;
    d.storageMode = MTLStorageModePrivate;

    _texA = [_device newTextureWithDescriptor:d];
    _texB = [_device newTextureWithDescriptor:d];
    _texMask = [_device newTextureWithDescriptor:d];

    if (!_texA || !_texB || !_texMask) return NO;
    _texWidth = w; _texHeight = h;
    return YES;
}

// ---------------------------- 加载资源 ----------------------------

- (int)loadMesh:(NSString *)meshPath forRole:(NSString *)role {
    if (!meshPath || !role) return -1;

    GccFaceMesh m;
    int rc = gcc_mesh_parse_file(meshPath.UTF8String, &m);
    if (rc != 0) {
        [_diag appendFormat:@"mesh[%@]=ERR%d ", role, rc];
        _checklist[[@"mesh:" stringByAppendingString:role]] =
            [NSString stringWithFormat:@"FAIL rc=%d", rc];
        return rc;
    }

    // 打包成紧凑数据：每顶点 5 float [x,y,u,v,valid]
    NSMutableData *packed =
        [NSMutableData dataWithLength:(NSUInteger)m.vert_count * 5 * sizeof(float)];
    float *p = (float *)packed.mutableBytes;
    for (int i = 0; i < m.vert_count; i++) {
        p[i*5+0] = m.verts[i].x;
        p[i*5+1] = m.verts[i].y;
        p[i*5+2] = m.verts[i].u;
        p[i*5+3] = m.verts[i].v;
        p[i*5+4] = (m.verts[i].x < -0.5f && m.verts[i].y < -0.5f) ? 0.0f : 1.0f;
    }

    // 索引单独存
    NSMutableData *idxData =
        [NSMutableData dataWithLength:(NSUInteger)m.index_count * sizeof(uint16_t)];
    if (m.index_count > 0 && m.indices) {
        memcpy(idxData.mutableBytes, m.indices,
               (NSUInteger)m.index_count * sizeof(uint16_t));
    }

    _meshData[[role stringByAppendingString:@":verts"]] = packed;
    _meshData[[role stringByAppendingString:@":idx"]]   = idxData;

    // ★ 构建 MTLBuffer：每顶点 6 float = [screenPos.xy][templPos.xy][uv.xy]
    //   screenPos 由 templPos 归一化得到（模板 1024 → 0~1）
    NSUInteger vcount = (NSUInteger)m.vert_count;
    NSMutableData *vbData =
        [NSMutableData dataWithLength:vcount * 6 * sizeof(float)];
    float *vb = (float *)vbData.mutableBytes;
    for (NSUInteger i = 0; i < vcount; i++) {
        float tx = m.verts[i].x, ty = m.verts[i].y;
        float tu = m.verts[i].u, tv = m.verts[i].v;
        // 无效顶点（-1 填充）也保留，避免索引错位；位置给 0
        float sx = (tx > 0.0f) ? tx / 1024.0f : 0.0f;
        float sy = (ty > 0.0f) ? ty / 1024.0f : 0.0f;
        vb[i*6+0] = sx;
        vb[i*6+1] = sy;
        vb[i*6+2] = tx;
        vb[i*6+3] = ty;
        vb[i*6+4] = tu;
        vb[i*6+5] = tv;
    }
    id<MTLBuffer> vbuf = [_device newBufferWithBytes:vbData.bytes
                                              length:vbData.length
                                             options:MTLResourceStorageModeShared];
    _meshVB[role] = vbuf;

    NSUInteger icount = (NSUInteger)m.index_count;
    if (icount > 0) {
        id<MTLBuffer> ibuf = [_device newBufferWithBytes:m.indices
                                                  length:icount * sizeof(uint16_t)
                                                 options:MTLResourceStorageModeShared];
        _meshIB[role] = ibuf;
        _meshIdxCount[role] = @(icount);
    }

    [_diag appendFormat:@"mesh[%@]=%luv/%lut vb=%lu ib=%lu ",
        role, (unsigned long)vcount, (unsigned long)(m.index_count / 3),
        (unsigned long)vcount, (unsigned long)icount];

    _checklist[[@"mesh:" stringByAppendingString:role]] =
        [NSString stringWithFormat:@"OK %luv/%lut valid=%d fmt=%c",
            (unsigned long)vcount, (unsigned long)(m.index_count / 3),
            m.valid_count, m.format == GCC_MESH_FORMAT_A ? 'A' : 'B'];

    gcc_mesh_free(&m);
    return 0;
}

- (int)loadMakeupTexture:(NSString *)pngPath
                material:(NSString *)materialPath
                forRole:(NSString *)role {
    if (!pngPath || !role) return -1;

    // 用 CoreGraphics 解 PNG
    UIImage *img = [UIImage imageWithContentsOfFile:pngPath];
    if (!img || !img.CGImage) {
        [_diag appendFormat:@"tex[%@]=IMG_FAIL ", role];
        return -2;
    }
    CGImageRef cg = img.CGImage;
    size_t w = CGImageGetWidth(cg), h = CGImageGetHeight(cg);

    // 解析 material 拿 uSTMatrix
    GccMakeupMap mm;
    int mrc = -1;
    if (materialPath) {
        mrc = gcc_makeup_load_material(materialPath.UTF8String, (int)w, (int)h, &mm);
    }

    // 上传纹理
    MTLTextureDescriptor *d =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                           width:w height:h mipmapped:NO];
    d.usage = MTLTextureUsageShaderRead;
    id<MTLTexture> tex = [_device newTextureWithDescriptor:d];
    if (!tex) return -3;

    // CGImage → RGBA8
    NSMutableData *buf = [NSMutableData dataWithLength:w * h * 4];
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(buf.mutableBytes, w, h, 8, w * 4, cs,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    if (!ctx) { CGColorSpaceRelease(cs); return -3; }
    CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), cg);
    CGContextRelease(ctx);
    CGColorSpaceRelease(cs);

    [tex replaceRegion:MTLRegionMake2D(0, 0, w, h)
           mipmapLevel:0 withBytes:buf.bytes bytesPerRow:w * 4];

    _makeupTex[role] = tex;

    if (mrc == 0) {
        NSMutableData *md = [NSMutableData dataWithLength:sizeof(GccMakeupMap)];
        memcpy(md.mutableBytes, &mm, sizeof(mm));
        _makeupMat[role] = md;
        [_diag appendFormat:@"mk[%@]=%zux%zu st(%.5f,%.5f) ", role, w, h,
                            mm.scaleX, mm.scaleY];
        _checklist[[@"makeup:" stringByAppendingString:role]] =
            [NSString stringWithFormat:@"OK %zux%zu st=(%.5f,%.5f)",
                w, h, mm.scaleX, mm.scaleY];
    } else {
        [_diag appendFormat:@"mk[%@]=%zux%zu MAT_ERR%d ", role, w, h, mrc];
        _checklist[[@"makeup:" stringByAppendingString:role]] =
            [NSString stringWithFormat:@"OK_TEX_BAD_MAT %zux%zu rc=%d", w, h, mrc];
    }
    return 0;
}

// ---------------------------- 蒙版与 LUT ----------------------------

// 通用 PNG → MTLTexture
- (id<MTLTexture>)makeTextureFromPNG:(NSString *)path
                          pixelFormat:(MTLPixelFormat)fmt
                              forceW:(size_t)fw
                              forceH:(size_t)fh {
    UIImage *img = path ? [UIImage imageWithContentsOfFile:path] : nil;
    if (!img || !img.CGImage) return nil;

    CGImageRef cg = img.CGImage;
    size_t w = fw ? fw : CGImageGetWidth(cg);
    size_t h = fh ? fh : CGImageGetHeight(cg);

    MTLTextureDescriptor *d =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:fmt
                                                           width:w height:h mipmapped:NO];
    d.usage = MTLTextureUsageShaderRead;
    id<MTLTexture> tex = [_device newTextureWithDescriptor:d];
    if (!tex) return nil;

    // 统一解成 RGBA8，再按目标格式取需要通道
    NSMutableData *buf = [NSMutableData dataWithLength:w * h * 4];
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(buf.mutableBytes, w, h, 8, w * 4, cs,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    if (!ctx) { CGColorSpaceRelease(cs); return nil; }
    CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), cg);
    CGContextRelease(ctx);
    CGColorSpaceRelease(cs);

    if (fmt == MTLPixelFormatRGBA8Unorm) {
        [tex replaceRegion:MTLRegionMake2D(0,0,w,h) mipmapLevel:0
                 withBytes:buf.bytes bytesPerRow:w*4];
    } else if (fmt == MTLPixelFormatR8Unorm) {
        // 取 R 通道（灰度蒙版）
        NSMutableData *r8 = [NSMutableData dataWithLength:w * h];
        uint8_t *src = (uint8_t *)buf.bytes;
        uint8_t *dst = (uint8_t *)r8.mutableBytes;
        for (size_t i = 0; i < w * h; i++) dst[i] = src[i * 4];
        [tex replaceRegion:MTLRegionMake2D(0,0,w,h) mipmapLevel:0
                 withBytes:r8.bytes bytesPerRow:w];
    }
    return tex;
}

- (int)loadSkinMask:(NSString *)pngPath {
    // 磨皮用的蒙版在大部分特效包里是 faceMask.png（灰度或 RGBA）
    id<MTLTexture> tex = [self makeTextureFromPNG:pngPath
                                       pixelFormat:MTLPixelFormatR8Unorm
                                           forceW:0 forceH:0];
    if (!tex) {
        // 无图时生成全白 1x1 —— 磨皮作用于整幅画面，保证功能可用
        MTLTextureDescriptor *d =
            [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm
                                                               width:1 height:1 mipmapped:NO];
        d.usage = MTLTextureUsageShaderRead;
        tex = [_device newTextureWithDescriptor:d];
        uint8_t one = 255;
        [tex replaceRegion:MTLRegionMake2D(0,0,1,1) mipmapLevel:0
                 withBytes:&one bytesPerRow:1];
        [_diag appendString:@"mask=default_white "];
        _texMask = tex;
        _checklist[@"skinMask"] = @"DEFAULT_WHITE (无素材，磨皮作用于全画面)";
        return 1;   // 返回 1 表示用了默认
    }
    _texMask = tex;
    [_diag appendFormat:@"mask=%zux%zu ", tex.width, tex.height];
    _checklist[@"skinMask"] = [NSString stringWithFormat:@"OK %zux%zu", tex.width, tex.height];
    return 0;
}

- (int)loadLUT:(NSString *)pngPath {
    if (!pngPath) {
        _texLUT = nil;
        [_checklist removeObjectForKey:@"lut"];
        return 0;
    }
    id<MTLTexture> tex = [self makeTextureFromPNG:pngPath
                                       pixelFormat:MTLPixelFormatRGBA8Unorm
                                           forceW:512 forceH:512];
    if (!tex) {
        [_diag appendString:@"lut=FAIL "];
        _checklist[@"lut"] = @"FAIL (解码失败)";
        return -2;
    }
    _texLUT = tex;
    [_diag appendFormat:@"lut=%zux%zu ", tex.width, tex.height];
    _checklist[@"lut"] = [NSString stringWithFormat:@"OK %zux%zu", tex.width, tex.height];
    return 0;
}

/* 官方基准位移场：DyClarity/AmazingFeature/image/faceMask.png 的 B/G 通道。
   按 facewarp.metal.frag 的口径导出成 RG（R=原B，G=原G）后作为 flowTex。 */
- (void)loadFlowField:(UIImage *)flowImage mask:(UIImage *)maskImage {
    _texFlow = nil;
    _texFlowMask = nil;
    if (!flowImage) { [_checklist removeObjectForKey:@"flow"]; return; }

    // 把 B/G 通道搬到 R/G：与官方 facewarp.frag 的
    //   out = vec4(mask.z, mask.y, 0, 0) 完全一致
    CGSize sz = flowImage.size;
    size_t w = (size_t)sz.width, h = (size_t)sz.height;
    if (w == 0 || h == 0 || w > 4096 || h > 4096) {
        [_checklist setObject:@"FAIL (尺寸)" forKey:@"flow"]; return;
    }
    NSMutableData *rgba = [NSMutableData dataWithLength:w * h * 4];
    UInt8 *dst = (UInt8 *)rgba.mutableBytes;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(dst, w, h, 8, w*4, cs,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(cs);
    if (!ctx) { [_checklist setObject:@"FAIL (ctx)" forKey:@"flow"]; return; }
    CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), flowImage.CGImage);
    CGContextRelease(ctx);

    for (size_t i = 0; i < w*h; i++) {
        UInt8 r = dst[i*4+0], g = dst[i*4+1], b = dst[i*4+2];
        dst[i*4+0] = b;    // R ← 原 B（官方 flow.x）
        dst[i*4+1] = g;    // G ← 原 G（官方 flow.y）
        dst[i*4+2] = 0;
        dst[i*4+3] = 255;
    }

    MTLTextureDescriptor *td = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
        width:w height:h mipmapped:NO];
    td.usage = MTLTextureUsageShaderRead;
    _texFlow = [_device newTextureWithDescriptor:td];
    if (_texFlow) {
        [_texFlow replaceRegion:MTLRegionMake2D(0,0,w,h)
                    mipmapLevel:0 withBytes:dst bytesPerRow:w*4];
    }

    // 蒙版：直接用整张 faceMask 的 B 通道当人脸权重（外部=0，内部>0）
    if (maskImage) {
        CGSize ms = maskImage.size;
        size_t mw=(size_t)ms.width, mh=(size_t)ms.height;
        if (mw>0 && mh>0 && mw<=4096 && mh<=4096) {
            NSMutableData *md=[NSMutableData dataWithLength:mw*mh*4];
            UInt8 *dd=(UInt8 *)md.mutableBytes;
            CGColorSpaceRef cs2=CGColorSpaceCreateDeviceRGB();
            CGContextRef c2=CGBitmapContextCreate(dd,mw,mh,8,mw*4,cs2,
                kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
            CGColorSpaceRelease(cs2);
            if (c2) {
                CGContextDrawImage(c2,CGRectMake(0,0,mw,mh),maskImage.CGImage);
                CGContextRelease(c2);
                MTLTextureDescriptor *t2=[MTLTextureDescriptor
                    texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                    width:mw height:mh mipmapped:NO];
                t2.usage=MTLTextureUsageShaderRead;
                _texFlowMask=[_device newTextureWithDescriptor:t2];
                if (_texFlowMask)
                    [_texFlowMask replaceRegion:MTLRegionMake2D(0,0,mw,mh)
                        mipmapLevel:0 withBytes:dd bytesPerRow:mw*4];
            }
        }
    }

    // 官方默认参数
    memset(&_flowParams, 0, sizeof(_flowParams));
    _flowParams.flowLevel = 1.0f;
    _flowParams.mvp00 = 1.0f; _flowParams.mvp11 = 1.0f;  // 单位 2x2
    _flowParams.faceCX = 0.5f; _flowParams.faceCY = 0.5f;
    _flowParams.faceW = 0.5f;  _flowParams.faceH = 0.5f;
    _flowParams.boundaryFalloff = 1.0f;
    _flowParams.enable = 1.0f;
    _flowParams.maskConf = 1.0f;
    [_checklist setObject:[NSString stringWithFormat:@"OK %zux%zu", w, h] forKey:@"flow"];
    [_diag appendFormat:@"flow=%zux%zu ", w, h];
}

- (void)setFaceLandmarks:(const float *)points count:(int)count {
    if (!points || count <= 0) { _landmarkCount = 0; return; }
    int n = count > 256 ? 256 : count;
    memcpy(_landmarks, points, (size_t)n * sizeof(float));
    _landmarkCount = n;
}
/* 官方 FilterV2 三档色彩校正真值。
   逐字解码自 analysis/.../AmazingFeature/main.scene：
     [name]\x00\x47\x98\xae\x05\x00\x00\x00[8B little-endian double]
   三档 FilterV2 节点各自的 exposure/brightness/temperature/tint/contrast/saturation。
   intensity 是官方总强度，shader 里用 lutMix / k494 承担，故此处只存不额外乘。 */
- (void)setFilterV2:(int)filterIndex {
    _filterV2 = filterIndex;
    // 全部先归零（官方多数项默认为 0）
    _fvExposure = _fvBrightness = _fvTemperature = _fvTint = 0.0f;
    _fvContrast = _fvSaturation = 0.0f;
    _fvIntensity = 0.0f;
    switch (filterIndex) {
        case 1:  // LUT 4742841142424155153-16398243369043809977.png
            _fvBrightness  =  0.01f;
            _fvSaturation  = -0.10f;
            _fvTint        =  0.01f;
            _fvIntensity   =  0.40f;
            break;
        case 2:  // LUT 5018430178703956944-12676436353678767011.png
            _fvIntensity   =  0.16f;
            break;
        case 3:  // LUT 4955288673192621240-14971763723888139659.png
            _fvTemperature =  0.04f;
            _fvContrast    =  0.01f;
            _fvIntensity   =  0.50f;
            break;
        default: break;
    }
    [_checklist setObject:[NSString stringWithFormat:@"V2=%d e=%.2f b=%.2f t=%.2f c=%.2f s=%.2f tint=%.2f I=%.2f",
        filterIndex,_fvExposure,_fvBrightness,_fvTemperature,_fvContrast,_fvSaturation,_fvTint,_fvIntensity]
        forKey:@"filterV2"];
}

/* 掩膜淡入淡出置信度：丢帧时按 10 帧退场，避免 mask 硬切出波纹。
   与 One Euro 滤波配套（docs/133 理论依据）。 */
- (void)setFaceMaskConfidence:(float)confidence {
    if (confidence < 0.0f) confidence = 0.0f;
    if (confidence > 1.0f) confidence = 1.0f;
    _faceMaskConf = confidence;
}


// ---------------------------- 渲染 ----------------------------

- (void)renderPixelBuffer:(CVPixelBufferRef)pb
              intoTexture:(id<MTLTexture>)target
               parameters:(GccBeautyParams)pp
             commandBuffer:(id<MTLCommandBuffer>)cmdBuf {
    if (!pb || !target || !cmdBuf) return;

    size_t w = CVPixelBufferGetWidth(pb);
    size_t h = CVPixelBufferGetHeight(pb);
    if (![self ensureTextures:w height:h]) return;

    // ---- Pass 0: YUV → RGB ----
    CVPixelBufferLockBaseAddress(pb, kCVPixelBufferLock_ReadOnly);
    OSType fmt = CVPixelBufferGetPixelFormatType(pb);
    BOOL isNV12 = (fmt == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange ||
                   fmt == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange);
    BOOL isBGRA = (fmt == kCVPixelFormatType_32BGRA);
    BOOL wroteFirst = NO;

    // ---- BGRA：零拷贝（相机默认输出）----
    if (isBGRA && _pipeBGRA && _texCache) {
        CVMetalTextureRef cvTex = NULL;
        CVReturn r = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault, _texCache, pb, NULL,
            MTLPixelFormatBGRA8Unorm, w, h, 0, &cvTex);
        if (r == kCVReturnSuccess && cvTex) {
            id<MTLTexture> bgraTex = CVMetalTextureGetTexture(cvTex);
            if (bgraTex) {
                float flip[2];
                flip[0] = _mirror ? 1.0f : 0.0f;   // 前置镜像
                flip[1] = 1.0f;                     // 相机帧上下颠倒

                MTLRenderPassDescriptor *rp = [MTLRenderPassDescriptor renderPassDescriptor];
                rp.colorAttachments[0].texture = _texA;
                rp.colorAttachments[0].loadAction = MTLLoadActionDontCare;
                rp.colorAttachments[0].storeAction = MTLStoreActionStore;
                id<MTLRenderCommandEncoder> enc = [cmdBuf renderCommandEncoderWithDescriptor:rp];
                [enc setRenderPipelineState:_pipeBGRA];
                [enc setFragmentTexture:bgraTex atIndex:0];
                [enc setFragmentBytes:&flip length:sizeof(flip) atIndex:0];
                [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
                [enc endEncoding];
                wroteFirst = YES;
            }
            // cvTex 由 CreateTextureFromImage 返回时已 +1，
            // 必须等本帧 GPU 用完才能释放 —— 用 addCompletedHandler 延迟，
            // 不要再 CFRetain（否则引用计数只加不减，纹理永不回收）。
            [cmdBuf addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull cb) {
                CFRelease(cvTex);
            }];
        } else {
            [_diag appendFormat:@"bgraTex=FAIL(%d) ", r];
        }
    }

    if (!wroteFirst && isNV12 && _pipeYUV) {
        uint8_t *yBase = CVPixelBufferGetBaseAddressOfPlane(pb, 0);
        uint8_t *uvBase = CVPixelBufferGetBaseAddressOfPlane(pb, 1);
        size_t yStride = CVPixelBufferGetBytesPerRowOfPlane(pb, 0);
        size_t uvStride = CVPixelBufferGetBytesPerRowOfPlane(pb, 1);

        MTLTextureDescriptor *d8 =
            [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm
                                                               width:w height:h mipmapped:NO];
        d8.usage = MTLTextureUsageShaderRead;
        id<MTLTexture> ty = [_device newTextureWithDescriptor:d8];
        [ty replaceRegion:MTLRegionMake2D(0,0,w,h) mipmapLevel:0
                withBytes:yBase bytesPerRow:yStride];

        MTLTextureDescriptor *d8uv =
            [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRG8Unorm
                                                               width:w/2 height:h/2 mipmapped:NO];
        d8uv.usage = MTLTextureUsageShaderRead;
        id<MTLTexture> tuv = [_device newTextureWithDescriptor:d8uv];
        [tuv replaceRegion:MTLRegionMake2D(0,0,w/2,h/2) mipmapLevel:0
                 withBytes:uvBase bytesPerRow:uvStride];

        YUVUniform u;
        memset(&u, 0, sizeof(u));
        // BT.709 full range
        u.m[0]=1.0f;  u.m[1]=1.0f;   u.m[2]=1.0f;
        u.m[3]=0.0f;  u.m[4]=-0.21482f; u.m[5]=2.12798f;
        u.m[6]=1.28033f; u.m[7]=-0.38059f; u.m[8]=0.0f;
        u.off[0]=-0.0625f; u.off[1]=-0.5f; u.off[2]=-0.5f;

        MTLRenderPassDescriptor *rp = [MTLRenderPassDescriptor renderPassDescriptor];
        rp.colorAttachments[0].texture = _texA;
        rp.colorAttachments[0].loadAction = MTLLoadActionDontCare;
        rp.colorAttachments[0].storeAction = MTLStoreActionStore;
        id<MTLRenderCommandEncoder> enc = [cmdBuf renderCommandEncoderWithDescriptor:rp];
        [enc setRenderPipelineState:_pipeYUV];
        [enc setFragmentTexture:ty atIndex:0];
        [enc setFragmentTexture:tuv atIndex:1];
        [enc setFragmentBytes:&u length:sizeof(u) atIndex:0];
        [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        [enc endEncoding];
    }
    CVPixelBufferUnlockBaseAddress(pb, kCVPixelBufferLock_ReadOnly);

    // ---- Pass 1: 已移除 ----
    // 磨皮改在 Pass3 的网格片元里做（gcc_mesh_fragment 的 smoothIntensity 分支）：
    //   1. 那里有皮肤蒙版，只作用于皮肤区域
    //   2. 与妆容在同一 pass，避免两次全屏采样
    // 原先这里还有一次全屏双边滤波，会与 Pass3 叠加导致磨皮过头。
    id<MTLTexture> cur = _texA;

    // ---- Pass 2 已合并进 Pass 3 的网格渲染（gcc_mesh_vertex 内含全部形变）----

    // ---- Pass 3: 网格驱动渲染（磨皮 + 妆容一起做）----
    // 用 Face145 的 870 顶点 + 1536 三角形，
    // 模板坐标由顶点插值到片元 → 妆容真正跟脸动。
    {
        id<MTLBuffer> vb = _meshVB[@"face"];
        id<MTLBuffer> ib = _meshIB[@"face"];
        NSNumber *icn = _meshIdxCount[@"face"];
        BOOL haveMesh = (vb && ib && icn && _pipeMesh);

        BOOL needSmooth = (pp.smooth > 0.001f);
        BOOL needMakeup = (pp.lipColor > 0.001f || pp.blush > 0.001f
                           || pp.eyeShadow > 0.001f);

        if (haveMesh && (needSmooth || needMakeup || _landmarkCount > 0)) {
            // 妆容图层选择：
            //   1. 若已通过 setActiveMakeupRole: 指定色号，优先用它
            //   2. 否则按强度挑（lips > blush > eye）
            NSString *mkRole = _activeMakeupRole;
            float mkInt = 0.0f;
            if (mkRole) {
                // 按色号的 kind 决定用哪个强度
                const GccMakeupPreset *pr = gcc_makeup_find(mkRole.UTF8String);
                if (pr) {
                    switch (pr->kind) {
                        case GCC_MK_LIPS:   mkInt = pp.lipColor;   break;
                        case GCC_MK_BLUSH:  mkInt = pp.blush;      break;
                        case GCC_MK_EYE:    mkInt = pp.eyeShadow;  break;
                        case GCC_MK_TEETH:  mkInt = pp.teeth;      break;
                        case GCC_MK_FACIAL: mkInt = pp.foundation; break;
                        default:            mkInt = 0.0f;          break;
                    }
                }
                if (mkInt < 0.001f) mkRole = nil;
            }
            // ★ 只有「用户没通过色号选择器指定」时才回退到基础 role。
            //   setActiveMakeupRole 传入的色号必须原样保留，否则 18 个色号
            //   全都会被这里覆盖成 Lips_female / Blusher_female 等 4 个基础色。
            if (!mkRole && !_activeMakeupRole) {
                if (pp.lipColor > 0.001f)       { mkRole = @"Lips_female";     mkInt = pp.lipColor; }
                else if (pp.blush > 0.001f)     { mkRole = @"Blusher_female";  mkInt = pp.blush; }
                else if (pp.eyeShadow > 0.001f) { mkRole = @"Eye_Female_01";   mkInt = pp.eyeShadow; }
                else if (pp.teeth > 0.001f)     { mkRole = @"Teeth_ALL";       mkInt = pp.teeth; }
            }

            GccMakeupMap mm; memset(&mm, 0, sizeof(mm));
            mm.scaleX = 1.0f; mm.scaleY = 1.0f;   // 默认直通用
            NSData *md = mkRole ? _makeupMat[mkRole] : nil;
            if (md) memcpy(&mm, md.bytes, sizeof(mm));

            // 人脸中心（屏幕归一化）
            float cx = 0.5f, cy = 0.5f, ey = 0.35f;
            if (_landmarkCount >= 4) {
                int n = _landmarkCount / 2;
                float sx = 0, sy = 0;
                for (int i = 0; i < n; i++) { sx += _landmarks[i*2]; sy += _landmarks[i*2+1]; }
                cx = sx / n; cy = sy / n;
                ey = cy * 0.6f;   // 眼区大致在上方
            }

            // ---- 模板坐标 → 屏幕 ----
            float mvp[16]; memset(mvp, 0, sizeof(mvp));
            mvp[0]  = 1.0f / 1024.0f;     // x: 模板 → 0~1
            mvp[5]  = 1.0f / 1024.0f;     // y
            mvp[10] = 1.0f;
            mvp[15] = 1.0f;

            // ---- 打包 MeshWarpParams ----
            // ★ 全部 float 标量：MSL 的 float2/float4 有 8/16 字节对齐要求，
            //   C 的 float[N] 只有 4 字节，混用会让字段偏移错位（实测差 32 字节）。
            //   字段顺序必须与 gcc_beauty.metal 的 struct 逐字一致。
            struct {
                float mvp[16];
                float centerX, centerY;
                float faceSlim, faceSmall;
                float faceCut, headSmall;
                float eyeLX, eyeLY;
                float eyeRX, eyeRY;
                float eyeRadius;
                float eyeSizeK, pupilK, lowerEyelidK, eyeDistK;
                float eyeCornerK, eyePosK, eyeTailUpK, browLiftK;
                float mouthCX, mouthCY;
                float mouthRadius;
                float mouthShapeK, mouthPosK, mouthWidthK, upperLipK;
                float smileK;
                float noseCX, noseCY;
                float noseRadius;
                float noseSlimK, noseWingK, noseBridgeK, nosePosK;
                float chinCX, chinCY;
                float chinRadius;
                float chinLengthK, chinPointyK;
                float cheekCX, cheekCY;
                float cheekRadius;
                float cheekboneK, cheekboneSlimK;
                float foreheadCX, foreheadCY;
                float foreheadRadius;
                float foreheadK;
            } wp;
            memset(&wp, 0, sizeof(wp));
            memcpy(wp.mvp, mvp, sizeof(mvp));

            // 人脸中心（模板空间 = 屏幕归一化 × 1024）
            float tcx = cx * 1024.0f, tcy = cy * 1024.0f;
            wp.centerX = tcx; wp.centerY = tcy;

            // ---- 全脸区 ----
            wp.faceSlim  = pp.faceSlim;   // [2]  瘦脸
            wp.faceSmall = pp.faceSmall;   // [11] 小脸
            wp.faceCut   = pp.cutFace;   // [23] 窄脸
            wp.headSmall = pp.headSmall;   // [3]  小头

            // ---- 眼部区 ----
            // 用 Vision 关键点估算左右眼中心（模板空间）；无关键点时退化
            float elx = tcx - 120.0f, ely = tcy - 90.0f;
            float erx = tcx + 120.0f, ery = tcy - 90.0f;
            if (_landmarkCount >= 8) {
                int hn = _landmarkCount / 2;
                float lxs = 0, lys = 0, rxs = 0, rys = 0;
                int lc = 0, rc2 = 0;
                for (int i2 = 0; i2 < hn; i2++) {
                    float px = _landmarks[i2*2]     * 1024.0f;
                    float py = _landmarks[i2*2 + 1] * 1024.0f;
                    if (py < tcy) {
                        if (px < tcx) { lxs += px; lys += py; lc++; }
                        else          { rxs += px; rys += py; rc2++; }
                    }
                }
                if (lc  > 0) { elx = lxs/lc;   ely = lys/lc;  }
                if (rc2 > 0) { erx = rxs/rc2;  ery = rys/rc2; }
            }
            wp.eyeLX = elx; wp.eyeLY = ely;
            wp.eyeRX = erx; wp.eyeRY = ery;
            wp.eyeRadius = 90.0f;

            wp.eyeSizeK     = pp.eyeSize;   // [4]  大眼
            wp.pupilK       = pp.pupilSize;   // [6]  瞳孔大小
            wp.lowerEyelidK = pp.lowerEyelid;   // [7]  眼睑下至
            wp.eyeDistK     = pp.eyeDist;   // [30] 眼距
            wp.eyeCornerK   = pp.eyeCorner;   // [31] 眼角
            wp.eyePosK      = pp.eyePos;   // [32] 眼位
            wp.eyeTailUpK   = pp.eyeTailUp;   // [34] 眼尾上扬
            wp.browLiftK    = pp.browLift;   // [35] 眉挑

            // ---- 嘴部区 ----
            wp.mouthCX = tcx;
            wp.mouthCY = tcy + 180.0f;
            wp.mouthRadius = 120.0f;
            wp.mouthShapeK = pp.mouthShape;     // [18] 嘴形
            wp.mouthPosK   = pp.mouthPos;     // [19] 嘴巴位置
            wp.mouthWidthK = pp.mouthWidth;     // [20] 嘴巴宽度
            wp.upperLipK   = pp.upperLip;     // [21] 丰上唇
            wp.smileK      = pp.smile;     // [10] 微笑

            // ---- 鼻部区 ----
            wp.noseCX = tcx;
            wp.noseCY = tcy + 60.0f;
            wp.noseRadius = 80.0f;
            wp.noseSlimK   = pp.noseSlim;     // [26] 瘦鼻
            wp.noseWingK   = pp.noseWidth;     // [27] 鼻翼
            wp.noseBridgeK = pp.noseBridge;     // [28] 鼻梁
            wp.nosePosK    = pp.nosePos;     // [33] 鼻位

            // ---- 下巴区 ----
            wp.chinCX = tcx;
            wp.chinCY = tcy + 300.0f;
            wp.chinRadius = 110.0f;
            wp.chinLengthK = pp.chinLength;     // [25] 下颚
            wp.chinPointyK = pp.chinPointy;     // [36] 尖下巴

            // ---- 颧骨区 ----
            wp.cheekCX = tcx;
            wp.cheekCY = tcy + 20.0f;
            wp.cheekRadius = 220.0f;
            wp.cheekboneK     = pp.cheekbone;  // [14] 立体
            wp.cheekboneSlimK = pp.cheekboneSlim;  // [24] 瘦颧骨

            // ---- 额头区 ----
            wp.foreheadCX = tcx;
            wp.foreheadCY = tcy - 220.0f;
            wp.foreheadRadius = 150.0f;
            wp.foreheadK = pp.foreheadHeight;   // [22] 额头

                        // ---- 打包 MeshFragParams（全 float 标量，与 MSL 逐字段对齐）----
            struct {
                float stScaleX, stOffsetX;
                float stScaleY, stOffsetY;
                float makeupIntensity;
                float makeupOpacity;
                float openMouth;
                float smoothIntensity;
                float texelSizeX, texelSizeY;
                float useMakeupTex;
                float makeupColorR, makeupColorG, makeupColorB, makeupColorA;
                float lipIntensity;
                float blushIntensity;
                float eyeIntensity;
                float teethIntensity;
                // ---- 局部美颜（与 MSL 的 MeshFragParams 后半段逐字段对应）----
                float eyeLX, eyeLY, eyeRX, eyeRY;
                float mouthCX, mouthCY;
                float noseCX, noseCY;
                float faceCX, faceCY;
                float darkCircleK;
                float nasolabialK;
                float eyeBrightenK;
                float rosyK;
                float whitenK;
                float clarityK;
            } fp;
            memset(&fp, 0, sizeof(fp));
            fp.stScaleX = mm.scaleX;  fp.stOffsetX = mm.offsetX;
            fp.stScaleY = mm.scaleY;  fp.stOffsetY = mm.offsetY;
            fp.makeupIntensity = mkInt;
            fp.makeupOpacity   = 1.0f;          // material 的 opacity 默认 1
            // ★ 张嘴判定：有关键点时按嘴部区域纵向跨度估算；
            //   无关键点（当前未接 Vision）恒为闭嘴，用 mask.r 通道。
            fp.openMouth = 0.0f;
            if (_landmarkCount >= 12) {
                float minY = 1e9f, maxY = -1e9f;
                int nPts = _landmarkCount / 2;
                for (int i2 = 0; i2 < nPts; i2++) {
                    float py = _landmarks[i2*2 + 1];
                    if (py < minY) minY = py;
                    if (py > maxY) maxY = py;
                }
                // 归一化坐标下嘴部张开超过阈值即认为张嘴
                fp.openMouth = (maxY - minY) > 0.085f ? 1.0f : 0.0f;
            }
            fp.smoothIntensity = pp.smooth;
            fp.texelSizeX = 1.0f / w;  fp.texelSizeY = 1.0f / h;
            // 有 LUT 贴图就用查表，否则用固定色兜底
            fp.useMakeupTex = (mkRole && _makeupTex[mkRole]) ? 1.0f : 0.0f;
            fp.makeupColorR = 0.95f; fp.makeupColorG = 0.35f;
            fp.makeupColorB = 0.35f; fp.makeupColorA = 1.0f;
            // 分区强度
            fp.lipIntensity   = pp.lipColor;
            fp.blushIntensity = pp.blush;
            fp.eyeIntensity   = pp.eyeShadow;
            fp.teethIntensity = pp.teeth;

            // ---- 局部美颜参数（模板坐标，与 warp 用的中心一致）----
            fp.eyeLX = elx; fp.eyeLY = ely;
            fp.eyeRX = erx; fp.eyeRY = ery;
            fp.mouthCX = tcx; fp.mouthCY = tcy + 180.0f;
            fp.noseCX  = tcx; fp.noseCY  = tcy + 60.0f;
            fp.faceCX  = tcx; fp.faceCY  = tcy;
            fp.darkCircleK   = pp.darkCircle;
            fp.nasolabialK   = pp.nasolabial;
            fp.eyeBrightenK  = pp.eyeBrighten;
            fp.rosyK         = pp.rosy;
            fp.whitenK       = pp.whiten;
            fp.clarityK      = pp.clarity;

            // ---- 掩膜时间平滑（docs/133：蒙版抖动经掩膜放大）----
            // One Euro 管「空间/逐点抖动」，这里管「人脸出现/消失的时间硬切」。
            // 所有妆效与局部美颜强度统一按置信度缩放，淡入 5 帧 / 淡出 10 帧，
            // 避免 mask 硬切导致额头波纹与黑贴纸。
            if (_faceMaskConf < 0.999f) {
                float c = _faceMaskConf;
                fp.makeupIntensity *= c;
                fp.lipIntensity   *= c;
                fp.blushIntensity *= c;
                fp.eyeIntensity   *= c;
                fp.teethIntensity *= c;
                fp.smoothIntensity *= c;
                fp.whitenK        *= c;
                fp.clarityK       *= c;
                fp.darkCircleK    *= c;
                fp.nasolabialK    *= c;
                fp.eyeBrightenK   *= c;
                fp.rosyK          *= c;
            }
                        // LUT 贴图优先（色号差异在 lookup 里）；无则用 mask 自身
            id<MTLTexture> mkTex = nil;
            if (mkRole) {
                mkTex = _makeupTex[[mkRole stringByAppendingString:@":lut"]];
                if (!mkTex) mkTex = _makeupTex[mkRole];
            }
            if (!mkTex) mkTex = _texA;

            MTLRenderPassDescriptor *rp = [MTLRenderPassDescriptor renderPassDescriptor];
            rp.colorAttachments[0].texture = _texB;
            rp.colorAttachments[0].loadAction = MTLLoadActionDontCare;
            rp.colorAttachments[0].storeAction = MTLStoreActionStore;
            id<MTLRenderCommandEncoder> enc = [cmdBuf renderCommandEncoderWithDescriptor:rp];
            [enc setRenderPipelineState:_pipeMesh];
            [enc setVertexBuffer:vb offset:0 atIndex:0];
            // ★ 形变同样按掩膜置信度缩放：人脸消失时形变收敛到 0，
            //   否则旧关键点会把网格拉出残留扭曲。
            if (_faceMaskConf < 0.999f) {
                float c = _faceMaskConf;
                wp.faceSlim *= c; wp.faceSmall *= c; wp.faceCut *= c; wp.headSmall *= c;
                wp.eyeSizeK *= c; wp.pupilK *= c; wp.lowerEyelidK *= c; wp.eyeDistK *= c;
                wp.eyeCornerK *= c; wp.eyePosK *= c; wp.eyeTailUpK *= c; wp.browLiftK *= c;
                wp.mouthShapeK *= c; wp.mouthPosK *= c; wp.mouthWidthK *= c; wp.upperLipK *= c;
                wp.smileK *= c;
                wp.noseSlimK *= c; wp.noseWingK *= c; wp.noseBridgeK *= c; wp.nosePosK *= c;
                wp.chinLengthK *= c; wp.chinPointyK *= c;
                wp.cheekboneK *= c; wp.cheekboneSlimK *= c; wp.foreheadK *= c;
            }
            [enc setVertexBytes:&wp length:sizeof(wp) atIndex:1];
            [enc setFragmentTexture:cur atIndex:0];
            [enc setFragmentTexture:mkTex ?: cur atIndex:1];
            // texture(2) = mask 贴图（官方 shader 的 maskImageTexture）
            //   有激活色号时用该色号的 mask；否则退到全白
            id<MTLTexture> maskTex = mkRole ? _makeupTex[mkRole] : nil;
            [enc setFragmentTexture:maskTex ?: (_texMask ?: cur) atIndex:2];
            [enc setFragmentBytes:&fp length:sizeof(fp) atIndex:0];

            NSUInteger idxCount = icn.unsignedIntegerValue;
            if (idxCount >= 3) {
                [enc drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                indexCount:idxCount
                                 indexType:MTLIndexTypeUInt16
                               indexBuffer:ib
                         indexBufferOffset:0];
            }
            [enc endEncoding];

        // ---- ★ 官方 freid 逐像素位移场（第 3 项）----
        // 网格 pass 输出在 _texB，这里重采样写回 _texA，再做后续调色。
        if (_pipeFlow && _texFlow && _texFlowMask && _flowParams.enable > 0.5f
            && _flowParams.flowLevel > 0.0001f) {
            MTLRenderPassDescriptor *rf = [MTLRenderPassDescriptor renderPassDescriptor];
            rf.colorAttachments[0].texture = _texA;
            rf.colorAttachments[0].loadAction = MTLLoadActionDontCare;
            rf.colorAttachments[0].storeAction = MTLStoreActionStore;
            id<MTLRenderCommandEncoder> ef = [cmdBuf renderCommandEncoderWithDescriptor:rf];
            [ef setRenderPipelineState:_pipeFlow];
            [ef setFragmentTexture:_texB atIndex:0];       // 当前画面
            [ef setFragmentTexture:_texFlow atIndex:1];    // 官方基准位移场
            [ef setFragmentTexture:_texFlowMask atIndex:2];// 人脸蒙版

            // 用当前人脸中心/尺寸对齐模板场（与 gcc_mesh 用的 cx/cy 同源）
            _flowParams.maskConf = _faceMaskConf;
            // flowLevel 由总形变强度驱动：取全脸类形变的最大绝对值
            float maxDeform = fmaxf(fabsf(wp.faceSlim), fabsf(wp.faceSmall));
            maxDeform = fmaxf(maxDeform, fabsf(wp.faceCut));
            maxDeform = fmaxf(maxDeform, fabsf(wp.eyeSizeK));
            _flowParams.flowLevel = fminf(maxDeform, 1.0f);

            [ef setFragmentBytes:&_flowParams length:sizeof(_flowParams) atIndex:0];
            [ef drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
            [ef endEncoding];
            cur = _texA;   // 结果已在 _texA，跳过 swap
        } else {
            id<MTLTexture> sw = _texA; _texA = _texB; _texB = sw;
            cur = _texA;
            }
        }
    }

    // ---- Pass 4: 调色 8 项 + 官方 LUT（MSL 版，逐字翻译自 color_fx.c）----
    if (_pipeGrade) {
        struct {
            float lutMix, bright, contra, satur, warm;
            float vign, grain, seed, flip, lutOn;
            float exposure, brightness, temperature, tint;
            float contrast, saturation;
            float res[2];
        } g;
        memset(&g, 0, sizeof(g));
        g.lutMix  = _fxLutMix;
        g.bright  = _fxBright;
        g.contra  = _fxContra;
        g.satur   = _fxSatur;
        g.warm    = _fxWarm;
        g.vign    = _fxVign;
        g.grain   = _fxGrain;
        g.seed    = _fxSeed;
        g.flip    = 0.0f;                       // BGRA pass 已处理上下翻转
        g.lutOn   = (_texLUT && _fxLutMix > 0.001f) ? 1.0f : 0.0f;
        // 官方 FilterV2 四项：当前未接 UI，保持中性（0 = 无影响）
        // ★ 官方 FilterV2 三档真值（main.scene 逐字解码），不再是恒 0。
        //   之前五档滤镜颜色不对的根因就是这 6 项全被写死 0。
        g.exposure    = _fvExposure;
        g.brightness  = _fvBrightness;
        g.temperature = _fvTemperature;
        g.tint        = _fvTint;
        g.contrast    = _fvContrast;
        g.saturation  = _fvSaturation;
        g.res[0] = (float)w;
        g.res[1] = (float)h;

        MTLRenderPassDescriptor *rp = [MTLRenderPassDescriptor renderPassDescriptor];
        rp.colorAttachments[0].texture = target;
        rp.colorAttachments[0].loadAction = MTLLoadActionDontCare;
        rp.colorAttachments[0].storeAction = MTLStoreActionStore;
        id<MTLRenderCommandEncoder> enc = [cmdBuf renderCommandEncoderWithDescriptor:rp];
        [enc setRenderPipelineState:_pipeGrade];
        [enc setFragmentTexture:cur atIndex:0];
        [enc setFragmentTexture:_texLUT ?: cur atIndex:1];
        [enc setFragmentBytes:&g length:sizeof(g) atIndex:0];
        [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        [enc endEncoding];
    } else if (_pipePass) {
        MTLRenderPassDescriptor *rp = [MTLRenderPassDescriptor renderPassDescriptor];
        rp.colorAttachments[0].texture = target;
        rp.colorAttachments[0].loadAction = MTLLoadActionDontCare;
        rp.colorAttachments[0].storeAction = MTLStoreActionStore;
        id<MTLRenderCommandEncoder> enc = [cmdBuf renderCommandEncoderWithDescriptor:rp];
        [enc setRenderPipelineState:_pipePass];
        [enc setFragmentTexture:cur atIndex:0];
        [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        [enc endEncoding];
    }
}

- (void)setColorFxBright:(float)b contra:(float)c satur:(float)s warm:(float)w
                    vign:(float)v grain:(float)g lutMix:(float)lm seed:(float)sd {
    _fxBright = b; _fxContra = c; _fxSatur = s; _fxWarm = w;
    _fxVign = v;   _fxGrain = g;  _fxLutMix = lm; _fxSeed = sd;
    _fxReady = YES;
}

- (void)setMirror:(BOOL)mirror {
    _mirror = mirror;
}

- (BOOL)mirror {
    return _mirror;
}

- (void)setActiveMakeupRole:(NSString *)role {
    _activeMakeupRole = [role copy];
    _checklist[@"activeMakeup"] = role ?: @"(none)";
}

- (NSString *)diagnostics {
    return [_diag copy];
}

// 结构化自检报告：每项一行，便于状态栏/落盘直接判读
- (NSString *)checklistReport {
    NSMutableString *r = [NSMutableString string];

    // 固定顺序输出，缺失项要显式标 MISSING（不能静默省略）
    NSArray *order = @[
        @"mesh:face", @"mesh:lips", @"mesh:blush", @"mesh:eye",
        @"makeup:lips", @"makeup:blush", @"makeup:eye",
        @"skinMask", @"lut",
    ];
    for (NSString *k in order) {
        NSString *v = _checklist[k];
        [r appendFormat:@"%@ = %@\n", k, v ?: @"MISSING"];
    }

    // pipeline 状态
    [r appendFormat:@"pipe:bgra   = %@\n", _pipeBGRA   ? @"OK" : @"FAIL"];
    [r appendFormat:@"pipe:mesh   = %@\n", _pipeMesh   ? @"OK" : @"FAIL"];
    [r appendFormat:@"pipe:grade  = %@\n", _pipeGrade  ? @"OK" : @"FAIL"];
    [r appendFormat:@"pipe:smooth = %@\n", _pipeSmooth ? @"OK" : @"FAIL"];
    [r appendFormat:@"texCache    = %@\n", _texCache   ? @"OK" : @"FAIL"];
    [r appendFormat:@"mirror      = %@\n", _mirror     ? @"ON" : @"OFF"];

    return r;
}

// 自检结论：0 = 关键项齐全（基础美颜可跑）；>0 = 缺失项数
- (int)checklistMissingCount {
    int miss = 0;
    if (!_checklist[@"mesh:face"])  miss++;   // 人脸网格必需
    if (!_texMask)                  miss++;   // 蒙版必需（有默认白兜底）
    if (!_pipeBGRA)                 miss++;   // BGRA 通道必需
    if (!_pipeGrade)                miss++;   // 调色必需
    return miss;
}

- (void)dealloc {
    if (_texCache) { CVMetalTextureCacheFlush(_texCache, 0); CFRelease(_texCache); }
}

@end
