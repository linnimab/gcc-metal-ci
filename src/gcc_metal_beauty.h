// gcc_metal_beauty.h — Metal 美颜渲染器（iOS 原生实现）
//
// 设计原则：
//   1. 不依赖 EffectSDK / AwemeCore，纯 Metal + CoreVideo
//   2. 用 gcc_face_mesh 解析的特效包网格驱动形变
//   3. 用 gcc_makeup_map 解析的 uSTMatrix 驱动妆容贴图
//   4. 分阶段可验证：每个 pass 单独可开关
//
// 渲染管线（从相机帧到上屏）：
//   CVPixelBuffer(YUV/NV12)
//     → [pass0] YUV→RGB 转换到纹理
//     → [pass1] 人脸网格变形（形变拉条）
//     → [pass2] 磨皮/美白（皮肤区域）
//     → [pass3] 妆容贴图混合（口红/腮红/眼妆）
//     → [pass4] LUT 调色 + 8项调色
//     → MTKView 上屏
//
// 每个 pass 独立可关，便于定位问题。

#ifndef GCC_METAL_BEAUTY_H
#define GCC_METAL_BEAUTY_H

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

// 美颜参数（全部归一化到 0~1，与抖音滑条一致）
typedef struct {
    // ---------- 磨皮 / 肤质组（slot 1 / 8 / 9 / 16 / 17 / 29）----------
    float smooth;          // [1]  磨皮
    float whiten;          // [9]  美白
    float clarity;         // [8]  清晰（锐化）
    float rosy;            // 红润（未在 51 槽内，保留）
    float darkCircle;      // [16] 黑眼圈
    float nasolabial;      // [17] 法令纹
    float eyeBrighten;     // [29] 亮眼

    // ---------- 形变组（0.5 为中性；严格对应 23 个 WARP 槽位）----------
    float faceSlim;        // [2]  瘦脸      Face_ALL
    float headSmall;       // [3]  小头      smaller_head
    float eyeSize;         // [4]  大眼      Eye_ALL
    float pupilSize;       // [6]  瞳孔大小   fd_pupil_v6
    float lowerEyelid;     // [7]  眼睑下至   fd_lower_eyelid_v6
    float smile;           // [10] 微笑      fd_mouse_corner_v6
    float faceSmall;       // [11] 小脸      Internal_Deform_Face
    float cheekbone;       // [14] 立体      Internal_Deform_Zoom_Cheekbone
    float mouthShape;      // [18] 嘴形      Mouth_ALL
    float mouthPos;        // [19] 嘴巴位置   fd_mouse_position_v6
    float mouthWidth;      // [20] 嘴巴宽度   fd_mouse_width_v6
    float upperLip;        // [21] 丰上唇    fd_upper_lip_v6
    float foreheadHeight;  // [22] 额头      Internal_Deform_Forehead
    float cutFace;         // [23] 窄脸      Internal_Deform_CutFace
    float cheekboneSlim;   // [24] 瘦颧骨    Internal_Deform_Zoom_Cheekbone
    float chinLength;      // [25] 下颚      fd_underjaw_v6
    float noseSlim;        // [26] 瘦鼻      Internal_Deform_Nose
    float noseWidth;       // [27] 鼻翼      fd_nose_wing_v6
    float noseBridge;      // [28] 鼻梁      fd_nose_bridge_v6
    float eyeDist;         // [30] 眼距      eye_far
    float eyeCorner;       // [31] 眼角      fd_outer_corner_v6
    float eyePos;          // [32] 眼位      eye_move
    float nosePos;         // [33] 鼻位      fd_nose_tip_v6
    float eyeTailUp;       // [34] 眼尾上扬   fd_outer_corner_v6
    float browLift;        // [35] 眉挑      eye_eyebrowjump
    float chinPointy;      // [36] 尖下巴    fd_jaw_v6

    // ---------- 妆容组（0=关，1=满）----------
    float lipColor;        // [12] 口红（基础色）
    float blush;           // [13] 腮红（基础色）
    float eyeShadow;       // [5]  眼妆
    float eyebrow;         // 眉毛（未在 51 槽内，保留）
    float teeth;           // [15] 白牙
    float foundation;      // [46] 底妆

    // 具体色号强度（0=关）—— 与基础色叠加，取最大
    float lipFrostbite;    // [37] 口红·冻伤
    float lipRetro;        // [38] 口红·复古
    float lipGrapefruit;   // [39] 口红·西柚
    float lipVitality;     // [40] 口红·元气
    float blushFrostbite;  // [41] 腮红·冻伤
    float blushRose;       // [42] 腮红·薔薇
    float blushOrange;     // [43] 腮红·甜橙
    float blushBrown;      // [44] 腮红·棕调
    float eyeShadowMale;   // [45] 眼妆·男

    // 整套妆容预设强度（0=关）
    float presetFairy;     // [47] 精灵
    float presetDewy;      // [48] 水光
    float presetHazy;      // [49] 氤氲
    float presetVFace;     // [50] V脸

    // ---------- 调色组（0.5 为中性）----------
    float brightness;
    float contrast;
    float saturation;
    float temperature;
    float vignette;
    float grain;

    // ---------- 调试开关 ----------
    int   debugMesh;       // 1=显示网格线
    int   debugMask;       // 1=显示妆容蒙版
} GccBeautyParams;

// 默认参数（全部中性）
GccBeautyParams gcc_beauty_params_neutral(void);

/* 官方 freid 逐像素位移场参数（与 gcc_beauty.metal 的 GccFlowParams 逐字段一致）。
   全部 float 标量：12 个 × 4B = 48B，无对齐歧义。 */
typedef struct {
    float flowLevel;
    float mvp00, mvp01, mvp10, mvp11;
    float faceCX, faceCY, faceW, faceH;
    float boundaryFalloff;
    float enable;
    float maskConf;
} GccFlowParams;

@interface GccMetalBeauty : NSObject

// 初始化。device 传 MTLCreateSystemDefaultDevice() 的结果。
// 返回 nil 表示初始化失败（shader 编译错误等）。
- (nullable instancetype)initWithDevice:(id<MTLDevice>)device
                            colorPixelFormat:(MTLPixelFormat)format
                              resourceRoot:(NSString *)resourceRoot;

// 加载特效包网格（gcc_face_mesh 能解析的 .mesh 文件路径）
// 返回 0 成功。可多次调用加载不同的网格。
- (int)loadMesh:(NSString *)meshPath forRole:(NSString *)role;

// 加载妆容贴图（PNG）+ 对应 material。
// role 如 "lips" / "blush" / "eye"
- (int)loadMakeupTexture:(NSString *)pngPath
                material:(NSString *)materialPath
                forRole:(NSString *)role;

// 每帧：把相机帧渲染到 target 纹理。
// 必须在 Metal 命令缓冲区已开启的情况下调用。
- (void)renderPixelBuffer:(CVPixelBufferRef)pixelBuffer
                 intoTexture:(id<MTLTexture>)target
                  parameters:(GccBeautyParams)params
                  commandBuffer:(id<MTLCommandBuffer>)cmdBuf;

// 设置人脸关键点（屏幕归一化坐标，来自 Vision）。
// points 是 [x0,y0, x1,y1, ...]，count 是点数。
// 传 NULL 表示本帧无人脸。
// 加载皮肤蒙版（磨皮只在蒙版非零区域生效）。
// 传 nil 则生成全白蒙版 —— 整幅画面都参与磨皮。
- (int)loadSkinMask:(nullable NSString *)pngPath;

// 加载 512x512 的 64³ tiled LUT（8x8 格子）。
// 传 nil 或加载失败时，调色仍生效但滤镜不生效。
- (int)loadLUT:(nullable NSString *)pngPath;

// 调色 8 项（与 color_fx.h 的 GccColorFx 一一对应，逐字翻译自同一份 GLSL）
- (void)setColorFxBright:(float)b contra:(float)c satur:(float)s warm:(float)w
                    vign:(float)v grain:(float)g lutMix:(float)lm seed:(float)sd;

// 前置镜像（左右翻转）。抖音官方自拍是镜像的。
@property (nonatomic, assign) BOOL mirror;

- (void)setFaceLandmarks:(const float *)points count:(int)count;
- (void)setFaceMaskConfidence:(float)confidence;
- (void)setFilterV2:(int)filterIndex;
- (void)loadFlowField:(UIImage *)flowImage mask:(UIImage *)maskImage;

// 运行时诊断：返回当前状态（网格数、贴图数、shader 编译情况）
// 切换当前激活的妆角色号（role = effect_slots.h 里的 tag，如 "Lips_Female_ds"）
- (void)setActiveMakeupRole:(nullable NSString *)role;

- (NSString *)diagnostics;

// 结构化自检报告（每项一行，缺失项显式标 MISSING）
- (NSString *)checklistReport;

// 关键项缺失数：0 = 基础美颜可跑
- (int)checklistMissingCount;

@end

NS_ASSUME_NONNULL_END

#endif /* GCC_METAL_BEAUTY_H */
