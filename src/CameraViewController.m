// CameraViewController.m — 相机预览与每帧特效处理。

//

// ★★★ 本轮重写（2026-10-24）★★★

// 旧版有三个致命缺陷，任何一个都会让 App 黑屏或静默失败：

//   1. viewDidLoad 里没有创建任何显示层 → App 全黑。

//      现在补 GLKView + EAGLContext。

//   2. deviceTexture = (int)(uintptr_t)base —— 把 CPU 像素首地址当纹理句柄。

//      安卓侧实测 process_texture 收的是 GL texture id，不是内存地址。

//      现在用 CVOpenGLESTextureCache 造真正的 GL texture。

//   3. bef_init 从没被调用 → g_handle == 0 → 所有 bridge 调用直接 -1。

//      现在在 viewDidLoad 里调，并把 result 显示到状态栏。



#import "CameraViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Vision/Vision.h>
#import <AudioToolbox/AudioToolbox.h>
#import <MediaPlayer/MediaPlayer.h>

#import "effect_bridge.h"

#import "resource_finder.h"   // ★ bef_rf_set_root 在这里声明

#import "js_runtime.h"        // ★ js_runtime_report —— 状态栏显示 JS 引擎状态

#import "effect_slots.h"      // ★ gcc_slots_* —— 51 行滑条表直连 composer

#import "slot_panel.h"        // ★ GccSlotPanel —— 51 根滑条原生 UI

#import "color_fx.h"          // 调色 6 项 + 官方 LUT 滤镜
#import "gcc_makeup_map.h"     // ★ GCC_MAKEUP_PRESETS / GCC_MK_*（妆容色号表）

extern const char *gcc_engine_error(void);   // 运行时引擎挂载诊断



#import <Metal/Metal.h>

#import <MetalKit/MetalKit.h>

#import "gcc_metal_beauty.h"
#import "gcc_one_euro.h"
#import "gcc_deform_coef.h"

#import <OpenGLES/ES2/gl.h>

#import <OpenGLES/ES2/glext.h>

#import <CoreVideo/CoreVideo.h>

#import <CoreGraphics/CoreGraphics.h>   // ★ CGBitmapContext（LUT PNG 解码）

#import <ImageIO/ImageIO.h>             // （UIImage 解码 PNG 走 ImageIO）

#import <time.h>                        // time() —— 录像文件名



@interface CameraViewController () <MTKViewDelegate>

@property (nonatomic, strong) UILabel *statusLabel;

@property (nonatomic, assign) BOOL isFrontCamera;

@property (nonatomic, strong) UISegmentedControl *beautySwitch;

@property (nonatomic, strong) GccSlotPanel *slotPanel;

@property (nonatomic, strong) UIButton *panelToggle;



// ★ 2026-11-10：调色 + LUT 滤镜（对齐安卓 rgbProgram / 5 档官方 LUT）

@property (nonatomic, strong) UISegmentedControl *filterSwitch;

@property (nonatomic, assign) GccColorFx colorFx;
@property (nonatomic, copy)   NSString *activeMakeupTag;
@property (nonatomic, strong) UISegmentedControl *makeupKindSwitch;   // 妆容类别
@property (nonatomic, strong) UISegmentedControl *makeupShadeSwitch;  // 色号
@property (nonatomic, strong) NSArray<NSNumber *> *curShadePresets;   // 当前类别下的预设索引
// 各类妆容强度（色号被选中时置 1，可由滑条改）
@property (nonatomic, assign) float lipStrength;
@property (nonatomic, assign) float blushStrength;
@property (nonatomic, assign) float eyeStrength;
@property (nonatomic, assign) float teethStrength;
@property (nonatomic, assign) float foundationStrength;

@property (nonatomic, assign) BOOL fxReady;

// LUT 档位 → PNG 文件名（bundle 内都已存在，见 RESOURCES/effect/.../texture/）

@property (nonatomic, strong) NSArray<NSString *> *lutNames;



// ★ 2026-11-10：调色 6 项滑条面板（对齐安卓 fxBright/fxContra/fxSatur/fxWarm/fxVign/fxGrain）

@property (nonatomic, strong) UIView *colorPanel;

@property (nonatomic, strong) NSMutableArray<UISlider *> *colorSliders;

@property (nonatomic, strong) UIButton *colorToggle;



// ★ 2026-11-10：拍照 / 录像

@property (nonatomic, assign) BOOL photoRequested;   // UI 线程置位，GL 线程读帧后清零

@property (nonatomic, assign) NSInteger photoSeq;

@property (nonatomic, strong) UIButton *photoButton;

@property (nonatomic, strong) UIButton *recordButton;
@property (nonatomic, strong) UIButton *torchButton;
@property (nonatomic, strong) UISegmentedControl *ratioSwitch;
@property (nonatomic, assign) BOOL torchOn;
@property (nonatomic, assign) CGFloat captureAspect;
@property (nonatomic, assign) float lastVolume;

// ---- Apple Vision 人脸关键点 ----
@property (nonatomic, strong) VNDetectFaceLandmarksRequest *faceReq;
@property (nonatomic, strong) dispatch_queue_t faceQueue;
@property (nonatomic, assign) float *facePoints;
@property (nonatomic, assign) int  facePointCount;
@property (nonatomic, assign) int  faceFrameSkip;
@property (nonatomic, assign) BOOL faceDetecting;
@property (nonatomic, assign) BOOL faceEverFound;

// ---- 时序平滑（抖音 One Euro 口径，docs/83 §4 / §8-1、docs/133）----
@property (nonatomic, assign) GccOneEuroBank faceFilter;   // 152 路逐坐标滤波
@property (nonatomic, assign) double faceT;                // 单调递增时间戳（秒）
@property (nonatomic, assign) float faceMaskConf;          // 掩膜淡入淡出置信度
// 当前生效的妆容色号索引（0..4），供 shader 选 LUT 贴图
@property (nonatomic, assign) int activeLipShade;
@property (nonatomic, assign) int activeBlushShade;
@property (nonatomic, assign) int activeFacialShade;   // 0 = 全屏, 0.75 = 4:3, 9/16 = 16:9 ...

@property (nonatomic, assign) BOOL recording;

@property (nonatomic, strong) AVAssetWriter *videoWriter;

@property (nonatomic, strong) AVAssetWriterInput *videoWriterInput;

@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *videoAdaptor;

@property (nonatomic, assign) int64_t videoFrameNo;

@property (nonatomic, strong) NSURL *videoOutURL;

@property (nonatomic, assign) CMTime videoStartTime;



// 显示层

@property (nonatomic, strong) MTKView *metalView;

@property (nonatomic, strong) id<MTLDevice> mtlDevice;

@property (nonatomic, strong) id<MTLCommandQueue> mtlQueue;

@property (nonatomic, strong) GccMetalBeauty *beauty;



// 当前正在显示的纹理（引擎输出，或原图模式下的相机纹理）

@property (nonatomic, assign) int displayWidth;

@property (nonatomic, assign) int displayHeight;

@end



@implementation CameraViewController



- (void)viewDidLoad {

    [super viewDidLoad];

    self.view.backgroundColor = [UIColor blackColor];

    self.lastProcessResult = -1;

    self.frameCount = 0;

    self.initResult = -1;

    self.videoQueue = dispatch_queue_create("camera.video", DISPATCH_QUEUE_SERIAL);



    [self setupMetal];

    [self setupOverlay];



    // ★ 调色通道必须与 GLKView 共用一个 EAGLContext。setupGL 已经 setCurrent，

    //   这里编译 program + 建 quad；失败不影响相机（drawInRect 会回退直通 blit）。

    self.colorFx = gcc_fx_neutral();

    self.lutNames = @[

        @"",                                                        // 0 原图

        @"4955288673192621240-14971763723888139659.png",          // 1 淡颜

        @"5018430178703956944-12676436353678767011.png",          // 2 草莓

        @"4742841142424155153-16398243369043809977.png",          // 3 官方

        @"lut_tianran_3.png",                                     // 4 清透

        @"lut_tianran_2.png",                                     // 5 浓郁

    ];

    int fxrc = gcc_fx_init();

    self.fxReady = (fxrc == 0);

    NSLog(@"[gcc] gcc_fx_init -> %d %s", fxrc, gcc_fx_last_error());



    // 恢复上次的参数（在加载资源前，这样色号能直接用上）
    [self setupMakeupPicker];
    [self setupTorchButton];
    [self setupRatioSwitch];
    [self setupVolumeButtonCapture];
    [self setupFaceDetection];
    [self loadParams];
    [self loadBeautyResources];

    [self initEngine];

    // 翻转键：挪到右上角第二排，避开左上角状态文字与底部参数面板

    UIButton *flipBtn = [UIButton buttonWithType:UIButtonTypeSystem];

    [flipBtn setTitle:@"翻转" forState:UIControlStateNormal];

    flipBtn.translatesAutoresizingMaskIntoConstraints = NO;

    flipBtn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.45];

    [flipBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    [flipBtn addTarget:self action:@selector(onFlipCameraTapped:)

      forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:flipBtn];

    [NSLayoutConstraint activateConstraints:@[

        [flipBtn.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:44],

        [flipBtn.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],

        [flipBtn.widthAnchor constraintEqualToConstant:64],

        [flipBtn.heightAnchor constraintEqualToConstant:30],

    ]];



    [self startPreview];

}



- (void)dealloc {
    @try {
        [[AVAudioSession sharedInstance] removeObserver:self forKeyPath:@"outputVolume"];
    } @catch (__unused NSException *e) { }
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [self stopPreview];

    gcc_fx_shutdown();

    bef_shutdown();

    // VNRequest.completionHandler 是 readonly；释放整个 request 即可。
    self.faceReq = nil;
    free(self.facePoints);
    self.facePoints = NULL;
    self.facePointCount = 0;
}



#pragma mark - 显示层



- (void)setupMetal {

    self.mtlDevice = MTLCreateSystemDefaultDevice();

    if (!self.mtlDevice) { NSLog(@"[gcc] Metal 不可用"); return; }

    self.mtlQueue = [self.mtlDevice newCommandQueue];



    self.metalView = [[MTKView alloc] initWithFrame:self.view.bounds

                                             device:self.mtlDevice];

    self.metalView.delegate = self;

    self.metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;

    self.metalView.framebufferOnly = NO;        // 拍照要读回

    self.metalView.enableSetNeedsDisplay = NO;

    self.metalView.paused = YES;

    self.metalView.autoresizingMask =

        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    [self.view addSubview:self.metalView];



    NSString *root = [[NSBundle mainBundle] pathForResource:@"effect" ofType:nil];

    self.beauty = [[GccMetalBeauty alloc] initWithDevice:self.mtlDevice

                                        colorPixelFormat:self.metalView.colorPixelFormat

                                           resourceRoot:root ?: @""];

    NSLog(@"[gcc] beauty: %@", self.beauty ? [self.beauty diagnostics] : @"init FAIL");

    self.beauty.mirror = self.isFrontCamera;

}



#pragma mark - 资源加载



- (void)loadBeautyResources {

    if (!self.beauty) return;



    NSBundle *mb = [NSBundle mainBundle];

    // effect 作为 folder reference 打进 bundle，落在 <App>.app/effect/

    NSString *eff = [mb pathForResource:@"effect" ofType:nil];

    if (!eff) {

        NSLog(@"[gcc] effect 目录缺失，跳过网格加载");

        return;

    }



    // ---- Face145 网格（人形基础网格，870 顶点 / 1536 三角形）----

    // 发包路径：effect/model/1028782778348757535-15545791325270837929.mesh

    NSArray *faceCands = @[

        @"model/1028782778348757535-15545791325270837929.mesh",

        @"bcce4ab7a2200676ca1295fe821704ed/AmazingFeature/model/1028782778348757535-15545791325270837929.mesh",

    ];

    int rcm = -1;

    for (NSString *rel in faceCands) {

        NSString *p = [eff stringByAppendingPathComponent:rel];

        if (![[NSFileManager defaultManager] fileExistsAtPath:p]) continue;

        rcm = [self.beauty loadMesh:p forRole:@"face"];

        NSLog(@"[gcc] loadMesh(face) <- %@ -> %d", rel, rcm);

        if (rcm == 0) break;

    }

    if (rcm != 0) NSLog(@"[gcc] Face145 网格加载失败");



    // ---- 妆容网格（发包版缺 DyMakeup，先探测，缺了不影响基础美颜）----

    NSDictionary *mkMeshes = @{

        @"lips":  @"DyMakeup/FaceMakeupV2_2999/mesh/lips_keypoint2999_mesh.mesh",

        @"blush": @"DyMakeup/FaceMakeupV2_2999/mesh/mask2998_mesh.mesh",

        @"eye":   @"DyMakeup/FaceMakeupV2_2999/mesh/eye_part2980_mesh.mesh",

    };

    for (NSString *role in mkMeshes) {

        NSString *p = [eff stringByAppendingPathComponent:mkMeshes[role]];

        if (![[NSFileManager defaultManager] fileExistsAtPath:p]) {

            NSLog(@"[gcc] 妆容网格 %@ 缺失（发包版无 DyMakeup）", role);

            continue;

        }

        int rc = [self.beauty loadMesh:p forRole:role];

        NSLog(@"[gcc] loadMesh(%@) -> %d", role, rc);

    }



    // ---- 妆容：按 effect_slots.h 的色号映射表加载 ----
    // gcc_makeup_map.h 的 GCC_MAKEUP_PRESETS 给出 18 个色号各自的 mask 目录，
    // 以及口红/牙齿共用的 lookup 贴图。
    [self loadAllMakeupPresets:eff];

    // ---- ★ 官方 freid 基准位移场（第 3 项）----
    // DyClarity/AmazingFeature/image/faceMask.png 的 B/G 通道是官方
    // facewarp.metal.frag 导出的 RG 位移编码；flow_composite 用
    // (flow-0.5)*0.125*mask*level 做逐像素重采样。
    // 与 skinMask 用同一批候选路径（仓库里有两份，逐字节同源）。
    NSArray *flowCands = @[
        @"bcce4ab7a2200676ca1295fe821704ed/DyClarity/AmazingFeature/image/faceMask.png",
        @"bcce4ab7a2200676ca1295fe821704ed/AmazingFeature/image/faceMask.png",
        @"image/faceMask.png",
    ];
    NSString *flowPath = nil;
    for (NSString *rel in flowCands) {
        NSString *p = [eff stringByAppendingPathComponent:rel];
        if ([[NSFileManager defaultManager] fileExistsAtPath:p]) { flowPath = p; break; }
    }
    // 官方口径：flow 与 mask 是两张独立贴图
    //   flow = DyClarity/.../image/faceMask.png（B/G → RG 位移编码，facewarp.frag 导出）
    //   mask = yunfu_fengying_liuchang/ganmask.png（320×320 径向人脸权重，中心 255 四角 0）
    NSArray *ganCands = @[
        @"bcce4ab7a2200676ca1295fe821704ed/AmazingFeature/yunfu_fengying_liuchang/ganmask.png",
        @"yunfu_fengying_liuchang/ganmask.png",
    ];
    NSString *ganPath = nil;
    for (NSString *rel in ganCands) {
        NSString *p = [eff stringByAppendingPathComponent:rel];
        if ([[NSFileManager defaultManager] fileExistsAtPath:p]) { ganPath = p; break; }
    }
    if (flowPath) {
        UIImage *fi = [UIImage imageWithContentsOfFile:flowPath];
        UIImage *gi = ganPath ? [UIImage imageWithContentsOfFile:ganPath] : fi;
        [self.beauty loadFlowField:fi mask:gi];
        NSLog(@"[gcc] flowField <- %@  mask <- %@",
              flowPath.lastPathComponent, ganPath ? ganPath.lastPathComponent : @"flow(兜底)");
    } else {
        NSLog(@"[gcc] flowField 缺失，跳过 freid pass（不影响其它妆效节点）");
    }

    // ---- 皮肤蒙版（磨皮用）----

    // AmazingFeature/image/faceMask.png

    NSArray *maskCands = @[

        @"bcce4ab7a2200676ca1295fe821704ed/AmazingFeature/image/faceMask.png",

        @"image/faceMask.png",

    ];

    BOOL maskLoaded = NO;

    for (NSString *rel in maskCands) {

        NSString *p = [eff stringByAppendingPathComponent:rel];

        if (![[NSFileManager defaultManager] fileExistsAtPath:p]) continue;

        [self.beauty loadSkinMask:p];

        maskLoaded = YES;

        NSLog(@"[gcc] skinMask <- %@", rel);

        break;

    }

    if (!maskLoaded) {

        [self.beauty loadSkinMask:nil];   // 生成全白，保证磨皮可用

        NSLog(@"[gcc] skinMask 缺失，使用全白默认");

    }



    // ---- LUT（滤镜当前档）----

    [self loadCurrentLUT];



    NSLog(@"[gcc] 资源加载完成: %@", [self.beauty diagnostics]);

    // ---- 调色恒等自检（离线数学验证，无需真机）----
    // 中性参数下 gcc_grade_msl 必须是恒等变换。
    // 这条断言拦截「滤镜颜色不对」类回归：历史上曾因翻译漏掉官方
    // shader 的 0.003*_666 项，导致蓝色通道系统性偏高 8.5%。
    [self runGradeIdentitySelfTest];



    // ---- 资源自检：结果落盘，设备侧直接读 ----

    NSString *report = [self.beauty checklistReport];

    int miss = [self.beauty checklistMissingCount];

    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,

                        NSUserDomainMask, YES) firstObject];

    NSString *path = [dir stringByAppendingPathComponent:@"gcc_checklist.txt"];

    NSString *body = [NSString stringWithFormat:

        @"=== GoodColorCam 资源自检 ===\n%@\n关键项缺失: %d\n",

        report, miss];

    [body writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];



    NSLog(@"[gcc] 自检:\n%@", body);

    if (miss > 0) {

        NSLog(@"[gcc] ⚠ 关键项缺 %d 项，基础美颜可能不完整", miss);

    }

}



// 调色恒等自检：中性参数下输出必须等于输入（CPU 侧复算 gcc_grade_msl 同一套公式）
//
// 历史背景：官方 fe9aea85.frag 的色域变换第三分量是
//   1.08728 / (0.9834*_671 + (0.003*_666 + 0.0136))
// 曾漏掉 0.003*_666 项，导致中性参数下蓝色通道系统性偏高 8.5%，
// 用户表现为「所有滤镜颜色都不对」。此自检确保不再回归。
- (void)runGradeIdentitySelfTest {
    // 中性：exposure/brightness/temperature/tint/contrast/saturation 全 0，
    //       bright/contra/satur/warm 全 0.5，k494 = 1
    const double t0 = 0.312709987163543701171875;
    const double s0 = (2.87 * t0 + (-(3.0 * t0) * t0)) - 0.2750950753688812255859375;
    const double u0 = t0 / s0;
    const double v0 = ((1.0 - t0) - s0) / s0;
    const double d0 = 0.94923698902130126953125 / ((-0.1624) * v0 + (0.7328 * u0 + 0.4296));
    const double d1 = 1.035419940948486328125 / (0.0061 * v0 + ((-0.7036) * u0 + 1.6975));
    const double d2 = 1.0872800350189208984375 / (0.9834 * v0 + (0.003 * u0 + 0.0136));

    // MSL float3x3 列主序：m[col][row]
    const double m1[3][3] = {
        { 0.390405,    0.549941,   0.00892632 },
        { 0.0708416,   0.963172,   0.00135775 },
        { 0.0231082,   0.128021,   0.936245   }
    };
    const double m2[3][3] = {
        {  2.85847,   -1.62879,  -0.024891   },
        { -0.210182,   1.15820,   0.00032428 },
        { -0.041812,  -0.118169,  1.06867    }
    };

    double maxerr = 0.0;
    const double samples[7] = { 0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0 };

    for (int k = 0; k < 7; k++) {
        double in = samples[k];
        double c0 = in, c1 = in, c2 = in;

        // FilterV2 色域变换
        double tmp[3], mid[3], out[3];
        for (int i = 0; i < 3; i++)
            tmp[i] = m1[0][i]*c0 + m1[1][i]*c1 + m1[2][i]*c2;
        mid[0] = tmp[0]*d0; mid[1] = tmp[1]*d1; mid[2] = tmp[2]*d2;
        for (int i = 0; i < 3; i++)
            out[i] = m2[0][i]*mid[0] + m2[1][i]*mid[1] + m2[2][i]*mid[2];

        // contrast（中性 0）、saturation（中性 0）
        for (int i = 0; i < 3; i++)
            out[i] = (out[i] - 0.21763764) * (0.0 + 1.0) + 0.21763764;
        {
            double L = 0.2126*out[0] + 0.7152*out[1] + 0.0722*out[2];
            for (int i = 0; i < 3; i++)
                out[i] = L + (out[i] - L) * (0.0 + 1.0);
        }

        // 色调六项（全中性 0.5）
        for (int i = 0; i < 3; i++) out[i] += (0.5 - 0.5) * 0.50;
        {
            double kk = 1.0 + (0.5 - 0.5) * 1.20;
            for (int i = 0; i < 3; i++) out[i] = (out[i] - 0.5) * kk + 0.5;
        }
        {
            double L2 = 0.299*out[0] + 0.587*out[1] + 0.114*out[2];
            for (int i = 0; i < 3; i++) out[i] = L2 + (out[i] - L2) * (0.5 * 2.0);
        }
        {
            double w = (0.5 - 0.5) * 0.24;
            out[0] += w; out[2] -= w; out[1] += w * 0.30;
        }

        // 恒等检查：三通道都应等于输入
        for (int i = 0; i < 3; i++) {
            double e = fabs(out[i] - in);
            if (e > maxerr) maxerr = e;
        }
    }

    BOOL pass = (maxerr < 1e-5);
    NSLog(@"[gcc] 调色恒等自检: maxerr=%.8f -> %@",
          maxerr, pass ? @"PASS" : @"FAIL(中性参数会偏色)");

    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                        NSUserDomainMask, YES) firstObject];
    NSString *p = [dir stringByAppendingPathComponent:@"gcc_selftest.txt"];
    NSString *body = [NSString stringWithFormat:
        @"调色恒等自检: %@\n"
        @"maxerr = %.8f  (阈值 1e-5)\n"
        @"含义: gcc_grade_msl 在全中性参数下必须是恒等变换。\n"
        @"历史: 曾漏掉官方 shader 的 0.003*_666 项 -> 蓝通道偏高 8.5%%\n",
        pass ? @"PASS" : @"FAIL", maxerr];
    [body writeToFile:p atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

#pragma mark - Apple Vision 人脸关键点

- (void)setupFaceDetection {
    self.faceQueue = dispatch_queue_create("com.gcc.face", DISPATCH_QUEUE_SERIAL);
    self.facePoints = NULL;
    self.facePointCount = 0;
    self.faceFrameSkip = 0;
    self.faceDetecting = NO;
    self.faceEverFound = NO;

    // ★ One Euro 滤波：76 点 × 2 坐标 = 152 路。
    //   官方参数 min_cutoff=1.0 / beta=0.007 / d_cutoff=1.0（docs/133）。
    //   初始化成最大点数，实际按每帧点数取用。
    gcc_oe_bank_init(&self->_faceFilter, GCC_OE_MAX_POINTS * 2);
    self.faceT = 0.0;
    self.faceMaskConf = 0.0f;

    if (@available(iOS 11.0, *)) {
        self.faceReq = [[VNDetectFaceLandmarksRequest alloc]
            initWithCompletionHandler:^(VNRequest *req, NSError *err) {
                [self onFaceDetected:req error:err];
            }];
    }
    NSLog(@"[gcc] Vision 人脸关键点已启用（每 3 帧一次）");
}

- (void)onFaceDetected:(VNRequest *)req error:(NSError *)err {
    self.faceDetecting = NO;
    if (err) { NSLog(@"[gcc] face detect err: %@", err.localizedDescription); return; }

    VNFaceObservation *face = nil;
    for (VNObservation *o in (req.results ?: @[])) {
        if ([o isKindOfClass:[VNFaceObservation class]]) { face = (VNFaceObservation *)o; break; }
    }
    if (!face || !face.landmarks) {
        // ★ 掩膜淡出：不立刻清零，按 10 帧线性退场，避免 mask 硬切出波纹。
        float conf = gcc_face_conf_on_lost(&self->_faceFilter);
        self.faceMaskConf = conf;
        if (conf > 0.001f && self.faceEverFound) {
            // 保留上一帧关键点，只降置信度。beauty ivar 统一在主队列写。
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.beauty setFaceMaskConfidence:conf];
            });
            return;
        }
        self.facePointCount = 0;
        self.faceEverFound = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.beauty setFaceMaskConfidence:0.0f];
        });
        return;
    }

    CGRect bb = face.boundingBox;
    // pointsInImage 返回 const CGPoint*（Vision 内部用 simd，公开头是 CGPoint）
    // VNFaceLandmarkRegion2D 公开 API：normalizedPoints（相对人脸框 0..1）。
    NSArray<NSValue *> *norm = face.landmarks.allPoints.normalizedPoints;
    NSUInteger n = norm.count;
    if (n == 0) return;

    int cap = (int)(n * 2);
    if (cap > 256) cap = 256;
    float *buf = (float *)malloc(sizeof(float) * (size_t)cap);
    if (!buf) return;

    for (int i = 0; i < cap / 2; i++) {
        CGPoint q = [norm[(NSUInteger)i] CGPointValue];   // 相对人脸框，原点左下
        float x = bb.origin.x + q.x * bb.size.width;
        float y = 1.0f - (bb.origin.y + q.y * bb.size.height);
        buf[i*2]     = x;
        buf[i*2 + 1] = y;
    }

    // ★ 时间戳：每次有效检测 +1/20 秒（每 3 帧一次 ≈ 20Hz @60fps）
    double nowT = self.faceT + 1.0 / 20.0;
    self.faceT = nowT;

    // ★ 逐坐标 One Euro 滤波（原地）。慢速压抖动，快速自动抬截止降延迟。
    gcc_oe_bank_apply(&self->_faceFilter, buf, buf, cap, nowT);

    // ★ 掩膜淡入：5 帧线性进场（对应官方 smooth_window_size=5）
    float conf = gcc_face_conf_on_found(&self->_faceFilter);
    self.faceMaskConf = conf;

    // 人脸框中心/尺度突变时重置滤波器，避免旧脸把新脸拉偏
    // （多人脸切换、从侧脸转正脸）
    static float s_lastCx = -1.0f, s_lastCy = -1.0f, s_lastW = -1.0f;
    float cxNow = bb.origin.x + bb.size.width * 0.5f;
    float cyNow = bb.origin.y + bb.size.height * 0.5f;
    if (s_lastW > 0.0f &&
        (fabsf(cxNow - s_lastCx) > 0.18f || fabsf(cyNow - s_lastCy) > 0.18f ||
         fabsf(bb.size.width - s_lastW) > 0.15f)) {
        gcc_oe_bank_reset(&self->_faceFilter);
        gcc_oe_bank_apply(&self->_faceFilter, buf, buf, cap, nowT);
        conf = 1.0f / (float)GCC_FACE_FADE_IN;
        self.faceMaskConf = conf;
        NSLog(@"[gcc] 人脸突变 → 重置 One Euro");
    }
    s_lastCx = cxNow; s_lastCy = cyNow; s_lastW = bb.size.width;

    // ★ 生命周期：buf 的所有权交给 self.facePoints（属性持有）。
    //   主队列回调只能读 self.facePoints，不能用局部 buf —— 否则下一帧
    //   free(old) 会让主队列拿到悬空指针。
    int  capCopy = cap;
    float confCopy = conf;
    dispatch_async(self.faceQueue, ^{
        float *old = self.facePoints;
        self.facePoints = buf;              // 属性接管所有权
        self.facePointCount = capCopy;
        self.faceEverFound = YES;
        free(old);                          // 释放的是「上一帧」的 buf
        // 主队列只从属性读，不碰已完成使命的局部变量
        dispatch_async(dispatch_get_main_queue(), ^{
            float *live = self.facePoints;
            int    nLive = self.facePointCount;
            if (live && nLive > 0) {
                [self.beauty setFaceLandmarks:live count:nLive];
            }
            [self.beauty setFaceMaskConfidence:confCopy];
        });
    });
    // buf 已移交，此处不再使用
}

- (void)requestFaceDetection:(CVPixelBufferRef)pb {
    if (!self.faceReq || self.faceDetecting) return;
    self.faceFrameSkip++;
    if (self.faceFrameSkip < 3) return;
    self.faceFrameSkip = 0;
    self.faceDetecting = YES;

    CVPixelBufferRetain(pb);
    dispatch_async(self.faceQueue, ^{
        @autoreleasepool {
            VNImageRequestHandler *h = [[VNImageRequestHandler alloc]
                initWithCVPixelBuffer:pb options:@{}];
            NSError *e = nil;
            [h performRequests:@[self.faceReq] error:&e];
            if (e) NSLog(@"[gcc] face perf err: %@", e.localizedDescription);
        }
        CVPixelBufferRelease(pb);
        dispatch_async(dispatch_get_main_queue(), ^{ self.faceDetecting = NO; });
    });
}

#pragma mark - 闪光灯

- (void)setupTorchButton {
    self.torchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.torchButton setTitle:@"⚡︎" forState:UIControlStateNormal];
    self.torchButton.titleLabel.font = [UIFont systemFontOfSize:18];
    [self.torchButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.torchButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18];
    self.torchButton.layer.cornerRadius = 6;
    self.torchButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.torchButton addTarget:self action:@selector(onTorchTapped:)
               forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.torchButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.torchButton.leadingAnchor constraintEqualToAnchor:self.photoButton.trailingAnchor constant:10],
        [self.torchButton.centerYAnchor constraintEqualToAnchor:self.photoButton.centerYAnchor],
        [self.torchButton.widthAnchor constraintEqualToConstant:44],
        [self.torchButton.heightAnchor constraintEqualToConstant:36],
    ]];

    // 前置没有闪光灯，默认置灰
    [self refreshTorchAvailability];
}

- (void)refreshTorchAvailability {
    AVCaptureDevice *dev = [self currentVideoDevice];
    BOOL has = (dev != nil && [dev hasTorch] && [dev isTorchAvailable]);
    self.torchButton.enabled = has;
    self.torchButton.alpha = has ? 1.0 : 0.4;
    if (!has) self.torchOn = NO;
}

- (AVCaptureDevice *)currentVideoDevice {
    for (AVCaptureDeviceInput *in in self.session.inputs) {
        if ([in.device hasMediaType:AVMediaTypeVideo]) return in.device;
    }
    return nil;
}

- (void)onTorchTapped:(UIButton *)sender {
    AVCaptureDevice *dev = [self currentVideoDevice];
    if (!dev || ![dev hasTorch]) {
        [self toast:@"这个摄像头没有闪光灯"];
        return;
    }
    NSError *err = nil;
    if ([dev lockForConfiguration:&err]) {
        // 安卓：只改 FLASH_MODE，不重开相机。iOS 对应 torch 模式
        dev.torchMode = self.torchOn ? AVCaptureTorchModeOff : AVCaptureTorchModeOn;
        // 亮度取 1.0（安卓 TORCH 也是满亮度）
        if (dev.torchMode == AVCaptureTorchModeOn && [dev isTorchModeSupported:AVCaptureTorchModeOn]) {
            [dev setTorchModeOnWithLevel:1.0 error:nil];
        }
        [dev unlockForConfiguration];
        self.torchOn = !self.torchOn;
        [sender setTitleColor:(self.torchOn ? [UIColor yellowColor] : [UIColor whiteColor])
                     forState:UIControlStateNormal];
        NSLog(@"[gcc] torch=%@", self.torchOn ? @"on" : @"off");
    } else {
        NSLog(@"[gcc] torch 失败: %@", err);
        [self toast:@"闪光灯切换失败"];
    }
}

#pragma mark - 画面比例

- (void)setupRatioSwitch {
    // 安卓侧只有 fill（铺满不留黑边）；iOS 补上常用比例，默认全屏 = 与安卓一致
    self.ratioSwitch = [[UISegmentedControl alloc] initWithItems:@[@"全屏", @"16:9", @"4:3", @"1:1"]];
    self.ratioSwitch.selectedSegmentIndex = 0;   // 全屏，对齐安卓的 fill
    self.ratioSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.ratioSwitch.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.45];
    [self.ratioSwitch addTarget:self action:@selector(onRatioChanged:)
               forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.ratioSwitch];

    [NSLayoutConstraint activateConstraints:@[
        [self.ratioSwitch.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [self.ratioSwitch.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:44],
        [self.ratioSwitch.widthAnchor constraintEqualToConstant:200],
        [self.ratioSwitch.heightAnchor constraintEqualToConstant:30],
    ]];

    self.captureAspect = 0.0;   // 全屏
}

- (void)onRatioChanged:(UISegmentedControl *)sender {
    switch (sender.selectedSegmentIndex) {
        case 0: self.captureAspect = 0.0;  break;              // 全屏（fill，同安卓）
        case 1: self.captureAspect = 9.0/16.0; break;          // 16:9 竖
        case 2: self.captureAspect = 3.0/4.0;  break;          // 4:3 竖
        case 3: self.captureAspect = 1.0;      break;          // 1:1
        default: self.captureAspect = 0.0; break;
    }
    [self applyAspectToPreview];
    NSLog(@"[gcc] 比例 -> %.3f", self.captureAspect);
}

- (void)applyAspectToPreview {
    // 全屏：铺满（同安卓 ScreenFit 的 fill 语义）
    // 其它：等比适应，上下（或左右）留黑边
    if (!self.metalView) return;
    CGFloat vw = self.view.bounds.size.width;
    CGFloat vh = self.view.bounds.size.height;
    if (self.captureAspect <= 0.0) {
        self.metalView.frame = self.view.bounds;
        self.metalView.layer.masksToBounds = NO;
        return;
    }
    CGFloat h = vw / self.captureAspect;
    if (h > vh) h = vh;
    CGFloat w = h * self.captureAspect;
    CGFloat x = (vw - w) * 0.5;
    CGFloat y = (vh - h) * 0.5;
    self.metalView.frame = CGRectMake(x, y, w, h);
    self.metalView.layer.masksToBounds = YES;
}

#pragma mark - 音量键拍照

- (void)setupVolumeButtonCapture {
    // iOS 没有「拦截音量键」的公开 API。可行做法：
    //   1) 在 AVCaptureSession 运行时，系统会把音量键交给 AVFoundation（拍照/录像）
    //   2) 自己监听 AVAudioSession 的输出音量变化来触发
    // 这里用方案 2：观察 outputVolume，值变化即视为按键。
    AVAudioSession *s = [AVAudioSession sharedInstance];
    NSError *err = nil;
    [s setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&err];
    [s setCategory:AVAudioSessionCategoryAmbient error:&err];

    self.lastVolume = s.outputVolume;
    [s addObserver:self
        forKeyPath:@"outputVolume"
           options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
           context:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(onVolumeChanged:)
            name:@"AVSystemController_SystemVolumeDidChangeNotification"
          object:nil];
    NSLog(@"[gcc] 音量键拍照已启用（初始音量 %.2f）", self.lastVolume);
}

- (void)observeValueForKeyPath:(NSString *)kp ofObject:(id)obj
                        change:(NSDictionary *)ch context:(void *)ctx {
    if ([kp isEqualToString:@"outputVolume"]) {
        float old = [ch[NSKeyValueChangeOldKey] floatValue];
        float now = [ch[NSKeyValueChangeNewKey] floatValue];
        if (fabsf(now - old) > 0.001f) {
            [self onVolumeKeyPressed];
        }
    }
}

- (void)onVolumeChanged:(NSNotification *)note {
    // 私有通知，部分机型会带 AVCSystemControllerVolumeChanged
    NSDictionary *u = note.userInfo;
    NSString *reason = u[@"AVSystemController_AudioVolumeChangeReasonNotificationParameter"];
    if (reason && ![reason isEqualToString:@"ExplicitVolumeChange"]) return;
    [self onVolumeKeyPressed];
}

- (void)onVolumeKeyPressed {
    // 只在预览态生效，避免录像时误触
    if (self.recording) return;
    NSLog(@"[gcc] 音量键 -> 拍照");
    [self onPhotoTapped:nil];
}

- (void)toast:(NSString *)msg {
    NSLog(@"[gcc] %@", msg);
    if (self.statusLabel) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.statusLabel.text = msg;
            self.statusLabel.alpha = 1.0;
            [UIView animateWithDuration:2.0 delay:2.0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{ self.statusLabel.alpha = 0.0; }
                             completion:nil];
        });
    }
}

#pragma mark - 色号选择 UI

// 妆容类别（对应 GccMakeupKind）
static NSString *const kGccMakeupKindNames[] = {
    @"口红", @"腮红", @"眼妆", @"底妆", @"牙齿"
};

- (void)setupMakeupPicker {
    // ---- 类别选择 ----
    NSMutableArray *kindNames = [NSMutableArray array];
    for (int k = 0; k < GCC_MK_KIND_COUNT; k++) {
        // 只列出真的有预设的类别
        BOOL has = NO;
        for (int i = 0; i < GCC_MAKEUP_PRESET_COUNT; i++) {
            if (GCC_MAKEUP_PRESETS[i].kind == k) { has = YES; break; }
        }
        if (has) [kindNames addObject:kGccMakeupKindNames[k]];
    }
    if (kindNames.count == 0) return;

    self.makeupKindSwitch = [[UISegmentedControl alloc] initWithItems:kindNames];
    self.makeupKindSwitch.selectedSegmentIndex = 0;
    self.makeupKindSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.makeupKindSwitch.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.45];
    [self.makeupKindSwitch addTarget:self action:@selector(onMakeupKindChanged:)
                    forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.makeupKindSwitch];

    // ---- 色号选择 ----
    self.makeupShadeSwitch = [[UISegmentedControl alloc] initWithItems:@[@"-"]];
    self.makeupShadeSwitch.selectedSegmentIndex = 0;
    self.makeupShadeSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.makeupShadeSwitch.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.45];
    [self.makeupShadeSwitch addTarget:self action:@selector(onMakeupShadeChanged:)
                      forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.makeupShadeSwitch];

    // 布局：放在 beautySwitch 上方
    [NSLayoutConstraint activateConstraints:@[
        [self.makeupKindSwitch.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [self.makeupKindSwitch.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],
        [self.makeupKindSwitch.bottomAnchor constraintEqualToAnchor:self.makeupShadeSwitch.topAnchor constant:-6],
        [self.makeupKindSwitch.heightAnchor constraintEqualToConstant:32],

        [self.makeupShadeSwitch.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [self.makeupShadeSwitch.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],
        [self.makeupShadeSwitch.bottomAnchor constraintEqualToAnchor:self.filterSwitch.topAnchor constant:-8],
        [self.makeupShadeSwitch.heightAnchor constraintEqualToConstant:32],
    ]];

    [self refreshShadeSwitch];
    NSLog(@"[gcc] 色号选择器已创建: %lu 个类别", (unsigned long)kindNames.count);
}

// 按当前类别刷新色号段
- (void)refreshShadeSwitch {
    NSInteger kindIdx = self.makeupKindSwitch.selectedSegmentIndex;
    if (kindIdx < 0) return;

    // 把「有预设的类别」映射回真实的 kind 值
    NSMutableArray *realKinds = [NSMutableArray array];
    for (int k = 0; k < GCC_MK_KIND_COUNT; k++) {
        for (int i = 0; i < GCC_MAKEUP_PRESET_COUNT; i++) {
            if (GCC_MAKEUP_PRESETS[i].kind == k) { [realKinds addObject:@(k)]; break; }
        }
    }
    if (kindIdx >= (NSInteger)realKinds.count) return;
    int kind = [realKinds[kindIdx] intValue];

    // 收集该类别的所有预设
    NSMutableArray *names = [NSMutableArray array];
    NSMutableArray *idxs  = [NSMutableArray array];
    for (int i = 0; i < GCC_MAKEUP_PRESET_COUNT; i++) {
        if (GCC_MAKEUP_PRESETS[i].kind != kind) continue;
        NSString *tag = [NSString stringWithUTF8String:GCC_MAKEUP_PRESETS[i].tag];
        // tag 去掉前缀，显示短名
        NSString *shortName = tag;
        if ([shortName hasPrefix:@"Lips_Female_"]) shortName = [shortName substringFromIndex:12];
        else if ([shortName hasPrefix:@"Lips_"])   shortName = [shortName substringFromIndex:5];
        else if ([shortName hasPrefix:@"Blusher_Female_"]) shortName = [shortName substringFromIndex:15];
        else if ([shortName hasPrefix:@"Blusher_"]) shortName = [shortName substringFromIndex:8];
        else if ([shortName hasPrefix:@"Facial_ALL_"]) shortName = [shortName substringFromIndex:11];
        else if ([shortName hasPrefix:@"Facial_"]) shortName = [shortName substringFromIndex:7];
        else if ([shortName hasPrefix:@"Eye_"])    shortName = [shortName substringFromIndex:4];
        [names addObject:shortName];
        [idxs addObject:@(i)];
    }
    self.curShadePresets = idxs;

    // 重建分段控件
    [self.makeupShadeSwitch removeAllSegments];
    for (NSUInteger i = 0; i < names.count; i++) {
        [self.makeupShadeSwitch insertSegmentWithTitle:names[i] atIndex:i animated:NO];
    }
    if (names.count) self.makeupShadeSwitch.selectedSegmentIndex = 0;
    NSLog(@"[gcc] 类别 %d 有 %lu 个色号", kind, (unsigned long)names.count);
}

- (void)onMakeupKindChanged:(UISegmentedControl *)sender {
    [self refreshShadeSwitch];
    // 切类别时自动选中第一个色号
    [self onMakeupShadeChanged:self.makeupShadeSwitch];
}

- (void)onMakeupShadeChanged:(UISegmentedControl *)sender {
    NSInteger si = sender.selectedSegmentIndex;
    if (si < 0 || si >= (NSInteger)self.curShadePresets.count) return;
    int presetIdx = [self.curShadePresets[si] intValue];
    if (presetIdx < 0 || presetIdx >= GCC_MAKEUP_PRESET_COUNT) return;

    const GccMakeupPreset *pr = &GCC_MAKEUP_PRESETS[presetIdx];
    [self selectMakeupPreset:pr->tag];

    // 同时把对应类别的强度拉起来（否则 alpha=0 看不见效果）
    float cur = 1.0f;
    switch (pr->kind) {
        case GCC_MK_LIPS:   self.lipStrength   = cur; break;
        case GCC_MK_BLUSH:  self.blushStrength = cur; break;
        case GCC_MK_EYE:    self.eyeStrength   = cur; break;
        case GCC_MK_TEETH:  self.teethStrength = cur; break;
        case GCC_MK_FACIAL: self.foundationStrength = cur; break;
        default: break;
    }
}

#pragma mark - 参数持久化

// 存储键
static NSString *const kGccKeyColorFx   = @"gcc.colorFx";
static NSString *const kGccKeyFilterIdx = @"gcc.filterIdx";
static NSString *const kGccKeyMakeupTag = @"gcc.makeupTag";
static NSString *const kGccKeyBeautyOn  = @"gcc.beautyOn";
static NSString *const kGccKeySlots     = @"gcc.slots";

// 保存：调色 8 项 + 滤镜档 + 色号 + 美颜开关
- (void)saveParams {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    GccColorFx fx = self.colorFx;
    [ud setFloat:fx.bright  forKey:[kGccKeyColorFx stringByAppendingString:@".bright"]];
    [ud setFloat:fx.contra  forKey:[kGccKeyColorFx stringByAppendingString:@".contra"]];
    [ud setFloat:fx.satur   forKey:[kGccKeyColorFx stringByAppendingString:@".satur"]];
    [ud setFloat:fx.warm    forKey:[kGccKeyColorFx stringByAppendingString:@".warm"]];
    [ud setFloat:fx.vign    forKey:[kGccKeyColorFx stringByAppendingString:@".vign"]];
    [ud setFloat:fx.grain   forKey:[kGccKeyColorFx stringByAppendingString:@".grain"]];
    [ud setFloat:fx.lut_mix forKey:[kGccKeyColorFx stringByAppendingString:@".lutMix"]];
    [ud setInteger:(NSInteger)self.filterSwitch.selectedSegmentIndex forKey:kGccKeyFilterIdx];
    [ud setInteger:(NSInteger)self.beautySwitch.selectedSegmentIndex forKey:kGccKeyBeautyOn];
    if (self.activeMakeupTag) [ud setObject:self.activeMakeupTag forKey:kGccKeyMakeupTag];

    // 51 槽位值：GccSlotPanel 没有 getter，改从引擎侧读回。
    // 用 gcc_slot_get_local(tag) 读【本地缓存】；gcc_slot_get 是从引擎读，无引擎返回 -996。
    {
        NSMutableArray *vals = [NSMutableArray array];
        for (int i = 0; i < GCC_SLOT_COUNT; i++) {
            const char *tag = GCC_SLOTS[i].tag;
            float v = tag ? gcc_slot_get_local(tag) : 0.0f;
            [vals addObject:@(v)];
        }
        [ud setObject:vals forKey:kGccKeySlots];
    }
    [ud synchronize];
    NSLog(@"[gcc] 参数已保存");
}

// 恢复：返回 YES 表示有存档
- (BOOL)loadParams {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString *k = kGccKeyColorFx;

    // 没有存档时 ud 返回 0，需要先判断是否存在
    if ([ud objectForKey:[k stringByAppendingString:@".bright"]] == nil) {
        NSLog(@"[gcc] 无参数存档，用中性值");
        return NO;
    }

    GccColorFx fx = self.colorFx;
    fx.bright  = [ud floatForKey:[k stringByAppendingString:@".bright"]];
    fx.contra  = [ud floatForKey:[k stringByAppendingString:@".contra"]];
    fx.satur   = [ud floatForKey:[k stringByAppendingString:@".satur"]];
    fx.warm    = [ud floatForKey:[k stringByAppendingString:@".warm"]];
    fx.vign    = [ud floatForKey:[k stringByAppendingString:@".vign"]];
    fx.grain   = [ud floatForKey:[k stringByAppendingString:@".grain"]];
    fx.lut_mix = [ud floatForKey:[k stringByAppendingString:@".lutMix"]];
    self.colorFx = fx;

    NSInteger fi = [ud integerForKey:kGccKeyFilterIdx];
    if (fi >= 0 && fi < (NSInteger)self.lutNames.count) {
        self.filterSwitch.selectedSegmentIndex = fi;
    }
    NSInteger bi = [ud integerForKey:kGccKeyBeautyOn];
    if (bi >= 0 && bi < (NSInteger)self.beautySwitch.numberOfSegments) {
        self.beautySwitch.selectedSegmentIndex = bi;
    }
    NSString *tag = [ud stringForKey:kGccKeyMakeupTag];
    if (tag.length) self.activeMakeupTag = tag;

    NSArray *vals = [ud arrayForKey:kGccKeySlots];
    if (vals.count) {
        // 直接写回引擎（gcc_slot_set(index, v) 是 effect_slots.h 的真实接口）
        for (NSUInteger i = 0; i < vals.count && i < (NSUInteger)GCC_SLOT_COUNT; i++) {
            gcc_slot_set((int)i, [vals[i] floatValue]);
        }
        // 让 UI 同步（pushAll 会把当前值再灌一遍引擎，避免状态不一致）
        [self.slotPanel pushAll];
    }
    NSLog(@"[gcc] 参数已恢复: filter=%ld beauty=%ld slots=%lu makeup=%@",
          (long)fi, (long)bi, (unsigned long)vals.count, tag ?: @"-");
    return YES;
}

// 按 gcc_makeup_map.h 的映射表，加载全部 18 个色号的 mask 贴图。
// 每个色号加载成独立 role，由 selectMakeupPreset: 切换。
- (void)loadAllMakeupPresets:(NSString *)eff {
    const char *base = "DyMakeup/FaceMakeupV2_2999";
    int loaded = 0;

    for (int i = 0; i < GCC_MAKEUP_PRESET_COUNT; i++) {
        const GccMakeupPreset *pr = &GCC_MAKEUP_PRESETS[i];
        if (!pr->tag || !pr->maskDir) continue;

        NSString *maskRel = [NSString stringWithFormat:
            @"%s/image/%s/%s_000.png", base, pr->maskDir, pr->maskDir];
        NSString *maskPath = [eff stringByAppendingPathComponent:maskRel];
        if (![[NSFileManager defaultManager] fileExistsAtPath:maskPath]) {
            NSLog(@"[gcc] 色号 %s 的 mask 缺失: %@", pr->tag, maskRel);
            continue;
        }

        NSString *lutPath = nil;
        if (pr->lookupDir) {
            NSString *lutRel = [NSString stringWithFormat:
                @"%s/image/%s/%s_000.png", base, pr->lookupDir, pr->lookupDir];
            NSString *p = [eff stringByAppendingPathComponent:lutRel];
            if ([[NSFileManager defaultManager] fileExistsAtPath:p]) lutPath = p;
        }

        NSString *matName = nil;
        switch (pr->kind) {
            case GCC_MK_LIPS:   matName = @"lips_keypoint2999_MATERIAL.material"; break;
            case GCC_MK_BLUSH:  matName = @"mask2998_MATERIAL.material"; break;
            case GCC_MK_EYE:    matName = @"eye_part2980_MATERIAL.material"; break;
            case GCC_MK_TEETH:  matName = @"teeth2993_MATERIAL.material"; break;
            default:            matName = nil; break;
        }
        NSString *matPath = nil;
        if (matName) {
            NSString *rel = [NSString stringWithFormat:@"%s/material/%@", base, matName];
            NSString *p = [eff stringByAppendingPathComponent:rel];
            if ([[NSFileManager defaultManager] fileExistsAtPath:p]) matPath = p;
        }

        NSString *role = [NSString stringWithUTF8String:pr->tag];
        int rc = [self.beauty loadMakeupTexture:maskPath
                                       material:matPath
                                        forRole:role];
        if (lutPath) {
            [self.beauty loadMakeupTexture:lutPath
                                   material:matPath
                                    forRole:[role stringByAppendingString:@":lut"]];
        }
        if (rc == 0) loaded++;
        NSLog(@"[gcc] 色号 %@ (kind=%d unify=%d) -> %d  mask=%s",
              role, pr->kind, pr->unifyIdx, rc, pr->maskDir);
    }
    NSLog(@"[gcc] 妆容色号加载完成: %d / %d", loaded, GCC_MAKEUP_PRESET_COUNT);
}

// 切换当前色号（由滑条或色号按钮调用）
- (void)selectMakeupPreset:(const char *)tag {
    if (!tag || !self.beauty) return;
    NSString *role = [NSString stringWithUTF8String:tag];
    [self.beauty setActiveMakeupRole:role];
    self.activeMakeupTag = role;
    [self saveParams];
    NSLog(@"[gcc] 当前色号 -> %@", role);
}

// 按 filterSwitch 当前档加载 LUT

- (void)loadCurrentLUT {

    if (!self.beauty) return;

    NSInteger idx = self.filterSwitch.selectedSegmentIndex;

    // ★ 官方 FilterV2 色彩校正：与 LUT 同源 main.scene，三档对应下标 1..3。
    //   放在这里统一管理，切档 / 启动 / 恢复三个入口全部自动覆盖。
    [self.beauty setFilterV2:(idx >= 1 && idx <= 3) ? (int)idx : 0];

    if (idx <= 0 || idx >= (NSInteger)self.lutNames.count) {

        [self.beauty loadLUT:nil];

        return;

    }

    NSString *name = self.lutNames[idx];

    if (name.length == 0) { [self.beauty loadLUT:nil]; return; }



    NSBundle *mb = [NSBundle mainBundle];

    NSString *eff = [mb pathForResource:@"effect" ofType:nil];

    if (!eff) return;

    NSArray *cands = @[

        [NSString stringWithFormat:@"texture/%@", name],

        [NSString stringWithFormat:@"bcce4ab7a2200676ca1295fe821704ed/AmazingFeature/texture/%@", name],

    ];

    for (NSString *rel in cands) {

        NSString *p = [eff stringByAppendingPathComponent:rel];

        if (![[NSFileManager defaultManager] fileExistsAtPath:p]) continue;

        int rc = [self.beauty loadLUT:p];

        NSLog(@"[gcc] loadLUT[%ld] %@ -> %d", (long)idx, name, rc);

        return;

    }

    NSLog(@"[gcc] LUT %@ 未找到", name);

}



#pragma mark - 引擎



- (void)initEngine {

    // ★ 资源根优先用 App bundle 里的 effect/（随包发布的淡感萌颜特效包），

    //   找不到再退回 Documents/effect（供运行时拷入新特效用）。

    //

    //   RESOURCES/effect 作为 folder reference 打进 bundle 后，

    //   会落在 <App>.app/effect/，保留 effect/<hash>/AmazingFeature/... 层级。

    NSFileManager *fm = [NSFileManager defaultManager];



    NSString *bundleEffect = [[NSBundle mainBundle] pathForResource:@"effect" ofType:nil];

    NSString *doc = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,

                                                        NSUserDomainMask, YES).firstObject;

    NSString *docEffect = [doc stringByAppendingPathComponent:@"effect"];



    NSString *root = nil;

    if (bundleEffect && [fm fileExistsAtPath:bundleEffect]) {

        root = bundleEffect;

        NSLog(@"[gcc] using bundled effect root: %@", root);

    } else {

        root = docEffect;

        [fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL];

        NSLog(@"[gcc] bundled effect missing, using Documents: %@", root);

    }



    NSString *leaf = [root stringByAppendingPathComponent:

                      @"bcce4ab7a2200676ca1295fe821704ed"];

    BOOL hasLeaf = [fm fileExistsAtPath:leaf];

    NSLog(@"[gcc] leaf=%@ exists=%d", leaf, hasLeaf);



    bef_rf_set_root([root UTF8String]);



    int rc = bef_init([root UTF8String], [leaf UTF8String], 720, 1280, YES);

    self.initResult = rc;

    NSLog(@"[gcc] bef_init(root=%@, leaf=%@) -> %d", root, leaf, rc);



    // 51 行滑条表自检：把安卓侧逆向出来的 tag 逐个和引擎真实 tag 列表比对。

    // 缺的会当场打 WARN —— 这是 iOS 侧不需要 JS 中转也能验的第一件事。

    int slotMissing = gcc_slots_init();

    NSLog(@"[gcc] gcc_slots_init -> missing=%d (0 = 全部对得上)", slotMissing);



    [self refreshStatusWithPrefix:[NSString stringWithFormat:@"init=%d leaf=%d slotmiss=%d\n",

                                    rc, hasLeaf, slotMissing]];

}



#pragma mark - UI



- (void)setupOverlay {

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];

    self.statusLabel.textColor = [UIColor greenColor];

    self.statusLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];

    self.statusLabel.numberOfLines = 0;

    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:self.statusLabel];



    self.beautySwitch = [[UISegmentedControl alloc] initWithItems:@[@"原图", @"美颜"]];

    self.beautySwitch.selectedSegmentIndex = 1;

    self.beautySwitch.translatesAutoresizingMaskIntoConstraints = NO;

    [self.beautySwitch addTarget:self action:@selector(onBeautyToggle:)

               forControlEvents:UIControlEventValueChanged];

    [self.view addSubview:self.beautySwitch];



    // ★ 官方 LUT 滤镜档位（下标与 lutNames 对齐：原图/淡颜/草莓/官方/清透/浓郁）

    self.filterSwitch = [[UISegmentedControl alloc] initWithItems:

                         @[@"原图", @"淡颜", @"草莓", @"官方", @"清透", @"浓郁"]];

    self.filterSwitch.selectedSegmentIndex = 0;

    self.filterSwitch.translatesAutoresizingMaskIntoConstraints = NO;

    [self.filterSwitch addTarget:self action:@selector(onFilterChanged:)

                forControlEvents:UIControlEventValueChanged];

    [self.view addSubview:self.filterSwitch];



    // ---- 51 根滑条面板（默认收起，点左上角「滑条」展开）----

    CGFloat pw = self.view.bounds.size.width;

    self.slotPanel = [[GccSlotPanel alloc] initWithWidth:pw];

    self.slotPanel.translatesAutoresizingMaskIntoConstraints = NO;

    self.slotPanel.hidden = YES;

    [self.view addSubview:self.slotPanel];



    self.panelToggle = [UIButton buttonWithType:UIButtonTypeSystem];

    [self.panelToggle setTitle:@"滑条" forState:UIControlStateNormal];

    self.panelToggle.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];

    [self.panelToggle setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    self.panelToggle.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18];

    self.panelToggle.layer.cornerRadius = 6;

    self.panelToggle.translatesAutoresizingMaskIntoConstraints = NO;

    [self.panelToggle addTarget:self action:@selector(onPanelToggle:)

               forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:self.panelToggle];



    // ★ 调色 6 项滑条面板（默认收起）

    [self buildColorPanel];



    // ★ 拍照 / 录像按钮

    self.photoButton = [UIButton buttonWithType:UIButtonTypeSystem];

    [self.photoButton setTitle:@"拍照" forState:UIControlStateNormal];

    [self.photoButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    self.photoButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.22];

    self.photoButton.layer.cornerRadius = 8;

    self.photoButton.translatesAutoresizingMaskIntoConstraints = NO;

    [self.photoButton addTarget:self action:@selector(onPhotoTapped:)

               forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:self.photoButton];



    self.recordButton = [UIButton buttonWithType:UIButtonTypeSystem];

    [self.recordButton setTitle:@"● 录像" forState:UIControlStateNormal];

    [self.recordButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    self.recordButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.22];

    self.recordButton.layer.cornerRadius = 8;

    self.recordButton.translatesAutoresizingMaskIntoConstraints = NO;

    [self.recordButton addTarget:self action:@selector(onRecordTapped:)

                forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:self.recordButton];



    // ★ 调色按钮（放在面板开关旁边）

    self.colorToggle = [UIButton buttonWithType:UIButtonTypeSystem];

    [self.colorToggle setTitle:@"调色" forState:UIControlStateNormal];

    self.colorToggle.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];

    [self.colorToggle setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    self.colorToggle.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18];

    self.colorToggle.layer.cornerRadius = 6;

    self.colorToggle.translatesAutoresizingMaskIntoConstraints = NO;

    [self.colorToggle addTarget:self action:@selector(onColorToggle:)

               forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:self.colorToggle];

    [NSLayoutConstraint activateConstraints:@[

        [self.statusLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],

        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],

        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],



        [self.beautySwitch.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16],

        // ★ 滤镜档放在「原图/美颜」上方一行

        [self.filterSwitch.bottomAnchor constraintEqualToAnchor:self.beautySwitch.topAnchor constant:-8],

        [self.filterSwitch.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],

        [self.filterSwitch.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],

        [self.filterSwitch.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],

        [self.beautySwitch.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],



        [self.panelToggle.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],

        [self.panelToggle.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],

        [self.panelToggle.widthAnchor constraintEqualToConstant:52],

        [self.panelToggle.heightAnchor constraintEqualToConstant:28],



        [self.slotPanel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],

        [self.slotPanel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [self.slotPanel.bottomAnchor constraintEqualToAnchor:self.filterSwitch.topAnchor constant:-8],

        [self.slotPanel.heightAnchor constraintEqualToConstant:260],



        // ★ 调色面板（在滤镜档上方，默认收起；展开时高 200）

        [self.colorPanel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],

        [self.colorPanel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [self.colorPanel.bottomAnchor constraintEqualToAnchor:self.filterSwitch.topAnchor constant:-8],

        [self.colorPanel.heightAnchor constraintEqualToConstant:200],



        // ★ 调色按钮：左上角，紧挨「滑条」左侧

        [self.colorToggle.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],

        [self.colorToggle.trailingAnchor constraintEqualToAnchor:self.panelToggle.leadingAnchor constant:-8],

        [self.colorToggle.widthAnchor constraintEqualToConstant:52],

        [self.colorToggle.heightAnchor constraintEqualToConstant:28],



        // ★ 拍照 / 录像：底部，分列「原图/美颜」两侧

        [self.photoButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16],

        [self.photoButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],

        [self.photoButton.widthAnchor constraintEqualToConstant:72],

        [self.photoButton.heightAnchor constraintEqualToConstant:36],



        [self.recordButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16],

        [self.recordButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],

        [self.recordButton.widthAnchor constraintEqualToConstant:80],

        [self.recordButton.heightAnchor constraintEqualToConstant:36],

    ]];

}



// 调色 6 项滑条：下标与 GccColorFx 字段顺序一致。

// 中性值：bright/contra/satur/warm = 0.5，vign/grain = 0.0。

static const char *kColorNames[] = {"亮度","对比","饱和","色温","暗角","颗粒"};



- (void)buildColorPanel {

    self.colorPanel = [[UIView alloc] initWithFrame:CGRectZero];

    self.colorPanel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.35];

    self.colorPanel.translatesAutoresizingMaskIntoConstraints = NO;

    self.colorPanel.hidden = YES;

    [self.view addSubview:self.colorPanel];



    self.colorSliders = [NSMutableArray array];

    CGFloat rowH = 30.0f;

    for (int i = 0; i < 6; i++) {

        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(8, i * rowH + 2, 52, rowH - 4)];

        lbl.text = [NSString stringWithUTF8String:kColorNames[i]];

        lbl.textColor = [UIColor colorWithWhite:0.92 alpha:1.0];

        lbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];

        [self.colorPanel addSubview:lbl];



        UISlider *sl = [[UISlider alloc] initWithFrame:CGRectMake(64, i * rowH + 2,

                                                                   200, rowH - 4)];

        sl.minimumValue = 0.0f;

        sl.maximumValue = 1.0f;

        sl.value = (i < 4) ? 0.5f : 0.0f;

        sl.tag = i;

        [sl addTarget:self action:@selector(onColorSlider:)

            forControlEvents:UIControlEventValueChanged];

        [self.colorPanel addSubview:sl];

        [self.colorSliders addObject:sl];

    }

    // 布局用 autoresizing：面板宽度随屏幕，滑条按比例不好写死，

    // 这里在 layoutSubviews 里按 bounds 重排（见下方 viewDidLayoutSubviews）。

}



- (void)viewDidLayoutSubviews {

    [super viewDidLayoutSubviews];

    CGFloat w = self.colorPanel.bounds.size.width;

    if (w <= 0) return;

    NSInteger i = 0;

    for (UIView *sub in self.colorPanel.subviews) {

        if ([sub isKindOfClass:[UISlider class]]) {

            sub.frame = CGRectMake(64, i * 30.0 + 2, w - 76, 26);

            i++;

        }

    }

}



- (void)onColorToggle:(UIButton *)sender {
    BOOL willShow = self.colorPanel.hidden;
    self.colorPanel.hidden = !willShow;

    // 两个面板互斥
    if (willShow) {
        self.slotPanel.hidden = YES;
        [self.panelToggle setTitle:@"滑条" forState:UIControlStateNormal];
    }
    [sender setTitle:(self.colorPanel.hidden ? @"调色" : @"收调色")
            forState:UIControlStateNormal];
}



- (void)onColorSlider:(UISlider *)sl {
    [self saveParams];

    GccColorFx f = self.colorFx;

    float v = sl.value;

    switch (sl.tag) {

        case 0: f.bright = v; break;

        case 1: f.contra = v; break;

        case 2: f.satur  = v; break;

        case 3: f.warm   = v; break;

        case 4: f.vign   = v; break;

        case 5: f.grain  = v; break;

    }

    self.colorFx = f;

}

- (void)onPanelToggle:(UIButton *)sender {
    BOOL willShow = self.slotPanel.hidden;
    self.slotPanel.hidden = !willShow;

    // 两个面板互斥：同一时间只显示一个，否则会重叠
    if (willShow) {
        self.colorPanel.hidden = YES;
        [self.colorToggle setTitle:@"调色" forState:UIControlStateNormal];
        [self.slotPanel pushAll];
    }
    [sender setTitle:(self.slotPanel.hidden ? @"滑条" : @"收起")
            forState:UIControlStateNormal];
}



// ★ 2026-11-10：切换官方 LUT 滤镜档。

//   PNG 解码用 UIImage（iOS 公开 API），拿到 512x512 RGBA8 后交给纯 C 的

//   gcc_fx_load_lut 上传。CG 位图默认带预乘 alpha，LUT 色卡本身 alpha=255，

//   所以预乘不影响 RGB；用 CGBitmapContext 重绘保证 RGBA8 / 非 565。

- (void)onFilterChanged:(UISegmentedControl *)sender {
    [self saveParams];

    [self loadCurrentLUT];

    NSInteger idx = sender.selectedSegmentIndex;

    GccColorFx fx = self.colorFx;

    if (idx <= 0 || idx >= (NSInteger)self.lutNames.count ||

        self.lutNames[idx].length == 0) {

        fx.lut_mix = 0.0f;                 // 原图

        self.colorFx = fx;

        NSLog(@"[gcc] filter -> 原图 (lut off)");

        return;

    }



    NSString *name = self.lutNames[idx];

    // LUT PNG 随 effect 资源打进 bundle，位于 effect/<hash>/AmazingFeature/texture/

    NSString *path = [[NSBundle mainBundle] pathForResource:[name stringByDeletingPathExtension]

                                                     ofType:@"png"];

    if (!path) {

        // fallback：在 bundle 根目录递归找同名文件（folder reference 层级差异）

        NSString *root = [[NSBundle mainBundle] bundlePath];

        NSArray *matches = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:root error:NULL];

        for (NSString *sub in matches) {

            if ([[sub lastPathComponent] isEqualToString:name]) {

                path = [root stringByAppendingPathComponent:sub];

                break;

            }

        }

    }

    if (!path) {

        NSLog(@"[gcc] filter '%@' PNG not found in bundle", name);

        fx.lut_mix = 0.0f;

        self.colorFx = fx;

        return;

    }



    UIImage *ui = [UIImage imageWithContentsOfFile:path];

    CGImageRef cg = ui.CGImage;

    if (!cg) { NSLog(@"[gcc] filter decode fail: %@", path); return; }

    size_t w = CGImageGetWidth(cg), h = CGImageGetHeight(cg);

    if (w != 512 || h != 512) {

        NSLog(@"[gcc] filter size %zux%zu != 512", w, h);

        return;

    }



    size_t bytes = 512 * 512 * 4;

    unsigned char *rgba = (unsigned char *)calloc(1, bytes);

    if (!rgba) return;

    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();

    CGContextRef ctx = CGBitmapContextCreate(rgba, 512, 512, 8, 512 * 4, cs,

                        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);

    CGColorSpaceRelease(cs);

    if (ctx) {

        CGContextDrawImage(ctx, CGRectMake(0, 0, 512, 512), cg);

        CGContextRelease(ctx);

        // 基准：抖音官方 FilterV2 / shaderGLES 在片元里做 uvLut.y = 1.0 - y，

        // 上传的 LUT 纹理必须保持 CG 原始行序，这里再翻一次会把蓝通道块号全反。

        int rc = gcc_fx_load_lut(rgba, bytes);

        NSLog(@"[gcc] filter '%@' load_lut -> %d %s", name, rc, gcc_fx_last_error());

        fx.lut_mix = (rc == 0) ? 0.8f : 0.0f;   // 抖音官方默认档强度

    }

    free(rgba);

    self.colorFx = fx;

}

- (void)onBeautyToggle:(UISegmentedControl *)sender {
    [self saveParams];

    if (sender.selectedSegmentIndex == 1) {

        int rc = bef_apply_default_look();

        [self refreshStatusWithPrefix:[NSString stringWithFormat:@"apply look rc=%d\n", rc]];

        // ★ 直连 composer 打三个值，验证这条路是通的（不需要 JS 中转）：

        //   3 小头   WARP smaller_head  (v-0.5)*2 = 0.4

        //   9 美白   GLU  whiten        v = 0.6

        //   13 腮红  MK   Blusher_female v = 0.5

        int r3  = gcc_slot_set(3, 0.7f);

        int r9  = gcc_slot_set(9, 0.6f);

        int r13 = gcc_slot_set(13, 0.5f);

        float back = gcc_slot_get_local("smaller_head");

        NSLog(@"[gcc] slot probe: small_head rc=%d back=%.4f | whiten rc=%d | blusher rc=%d",

              r3, back, r9, r13);

        [self refreshStatusWithPrefix:

            [NSString stringWithFormat:@"composer probe\nslot3 rc=%d back=%.3f\nslot9=%d slot13=%d\n",

                r3, back, r9, r13]];

        gcc_slot_dump();

        // 打开美颜后把面板当前值灌一遍（面板值优先于探针值）

        [self.slotPanel pushAll];

    } else {

        // 原图：把美颜强度归零（真入口，不是恒 -3 的 set_beauty）

        int rc = bef_set_beauty_intensity(0.0f, 0.0f);

        [self refreshStatusWithPrefix:[NSString stringWithFormat:@"beauty off rc=%d\n", rc]];

    }

}



- (void)refreshStatusWithPrefix:(NSString *)prefix {

    const char *ver  = bef_version();

    const char *algo = bef_algo_report();   // 算法/人脸引擎 + JS 全链路自检

    // 落盘：设备侧直接读，不必再靠截图/口述状态栏。

    {

        NSString *dir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];

        NSString *path = [dir stringByAppendingPathComponent:@"gcc_status.txt"];

        NSString *line = [NSString stringWithFormat:

            @"sdk=%s init=%d frame=%ld process=%d | %s | err=%s\\n",

            ver ? ver : "?", self.initResult, (long)self.frameCount, self.lastProcessResult,

            algo ? algo : "?", gcc_engine_error() ? gcc_engine_error() : ""];

        [line writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];



        // 自检摘要单独落盘（避免和运行状态混在一行）

        if (self.beauty) {

            NSString *cp = [dir stringByAppendingPathComponent:@"gcc_checklist.txt"];

            NSString *rep = [self.beauty checklistReport];

            NSString *body = [NSString stringWithFormat:

                @"=== GoodColorCam 资源自检 ===\n%@\n关键项缺失: %d\n",

                rep, [self.beauty checklistMissingCount]];

            [body writeToFile:cp atomically:YES encoding:NSUTF8StringEncoding error:NULL];

        }

    }

    dispatch_async(dispatch_get_main_queue(), ^{

        self.statusLabel.text = [NSString stringWithFormat:

            @"%@sdk=%s\ninit=%d\nframe=%ld  process=%d\n%@",

            prefix,

            ver ? ver : "?",

            self.initResult,

            (long)self.frameCount,

            self.lastProcessResult,

            algo ? [NSString stringWithUTF8String:algo] : @"algo=?"];

    });

}



#pragma mark - Capture



// 翻转键：对齐抖音官方相机的前后置切换；切换后保持竖屏取帧口径不变。

- (void)onFlipCameraTapped:(id)sender {

    if (!self.session) return;

    [self.session beginConfiguration];

    AVCaptureDeviceInput *cur = (AVCaptureDeviceInput *)self.session.inputs.firstObject;

    AVCaptureDevicePosition pos = (cur && cur.device.position == AVCaptureDevicePositionFront)

                                   ? AVCaptureDevicePositionBack : AVCaptureDevicePositionFront;

    if (cur) [self.session removeInput:cur];

    AVCaptureDevice *dev = nil;

    if (@available(iOS 10.0, *)) {

        dev = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera

                                                 mediaType:AVMediaTypeVideo position:pos];

    } else {

        for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo])

            if (d.position == pos) { dev = d; break; }

    }

    NSError *e = nil;

    AVCaptureDeviceInput *in = dev ? [AVCaptureDeviceInput deviceInputWithDevice:dev error:&e] : nil;

    if (in && [self.session canAddInput:in]) [self.session addInput:in];

    else if (cur && [self.session canAddInput:cur]) [self.session addInput:cur];

    AVCaptureConnection *c = [self.videoOutput connectionWithMediaType:AVMediaTypeVideo];

    if (c.isVideoOrientationSupported) c.videoOrientation = AVCaptureVideoOrientationPortrait;

    [self.session commitConfiguration];

    self.isFrontCamera = (dev.position == AVCaptureDevicePositionFront);

    // ★ 翻转后必须同步镜像：前置像镜子（左右翻转），后置不镜像。
    //   漏了这行会导致翻到前置后预览左右仍反着，或翻到后置后还带着镜像。
    self.beauty.mirror = self.isFrontCamera;

    // 前置没有闪光灯，翻过去后置再亮起来
    if ([self respondsToSelector:@selector(refreshTorchAvailability)]) {
        [self refreshTorchAvailability];
    }
    if (self.torchOn && self.isFrontCamera) {
        // 翻到前置时把还亮着的补光灯关掉
        AVCaptureDevice *oldDev = [self currentVideoDevice];
        if (oldDev && [oldDev hasTorch] && [oldDev lockForConfiguration:nil]) {
            oldDev.torchMode = AVCaptureTorchModeOff;
            [oldDev unlockForConfiguration];
        }
        self.torchOn = NO;
        [self.torchButton setTitleColor:[UIColor whiteColor]
                              forState:UIControlStateNormal];
    }

    [self refreshStatusWithPrefix:@"[翻转] 已切换\n"];

}



- (void)startPreview {

    if (self.session) { return; }



    AVAuthorizationStatus auth = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];

    if (auth == AVAuthorizationStatusRestricted || auth == AVAuthorizationStatusDenied) {

        [self refreshStatusWithPrefix:@"camera denied\n"];

        return;

    }



    self.session = [[AVCaptureSession alloc] init];

    self.session.sessionPreset = AVCaptureSessionPreset1280x720;



    // 基准：抖音官方相机开机即前置自拍，后置退为可切换的备选。

    AVCaptureDevice *device = nil;

    if (@available(iOS 10.0, *)) {

        device = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera

                                                   mediaType:AVMediaTypeVideo

                                                   position:AVCaptureDevicePositionFront];

    }

    if (!device) device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    self.isFrontCamera = (device.position == AVCaptureDevicePositionFront);

    NSError *err = nil;

    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&err];

    if (!input) {

        [self refreshStatusWithPrefix:[NSString stringWithFormat:@"no camera: %@\n", err.localizedDescription]];

        return;

    }

    if (![self.session canAddInput:input]) {

        [self refreshStatusWithPrefix:@"cannot add input\n"];

        return;

    }

    [self.session addInput:input];



    self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];

    self.videoOutput.alwaysDiscardsLateVideoFrames = YES;

    // BGRA + IOSurface 兼容：CVOpenGLESTextureCache 需要 kCVPixelBufferIOSurfacePropertiesKey

    self.videoOutput.videoSettings = @{

        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),

        (id)kCVPixelBufferIOSurfacePropertiesKey: @{},

    };

    [self.videoOutput setSampleBufferDelegate:self queue:self.videoQueue];

    if (![self.session canAddOutput:self.videoOutput]) {

        [self refreshStatusWithPrefix:@"cannot add output\n"];

        return;

    }

    [self.session addOutput:self.videoOutput];



    AVCaptureConnection *conn = [self.videoOutput connectionWithMediaType:AVMediaTypeVideo];

    if (conn.isVideoOrientationSupported) {

        conn.videoOrientation = AVCaptureVideoOrientationPortrait;

    }



    [self.session startRunning];

}



- (void)stopPreview {

    if (self.session.isRunning) { [self.session stopRunning]; }

}



#pragma mark - Frame



- (int)processPixelBuffer:(CVPixelBufferRef)pixelBuffer

                  texture:(unsigned int)texture

                    width:(int)width

                   height:(int)height

               timestamp:(double)timestamp {

    int rc = 0;

    if (self.beautySwitch.selectedSegmentIndex != 0) {

        rc = bef_process_frame((int)texture, width, height, timestamp);

    }

    self.lastProcessResult = rc;

    self.frameCount += 1;

    return rc;

}



#pragma mark - GLKViewDelegate



- (void)drawInMTKView:(MTKView *)view {

    // 渲染在 captureOutput 里每帧一次性完成；这里不需要额外动作。

}



- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {

}



#pragma mark - 拍照 / 录像



// 从当前绑定的 framebuffer 读 RGBA 像素。GL 原点在左下，UIKit 在左上，

// 由调用方按需翻转。返回 NULL 表示失败。



// RGBA(上下颠倒) -> UIImage。用 CGBitmapContext 重绘时顺便翻正。



- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error

  contextInfo:(void *)contextInfo {

    if (error) NSLog(@"[gcc] photo save error: %@", error.localizedDescription);

    else NSLog(@"[gcc] photo save OK");

}



// 把当前 framebuffer 的一帧写进 AVAssetWriter。



- (void)onPhotoTapped:(UIButton *)sender {

    self.photoRequested = YES;

    [self refreshStatusWithPrefix:@"[拍照] 保存中...\n"];

}



- (void)onRecordTapped:(UIButton *)sender {

    if (self.recording) {

        [self stopRecording];

    } else {

        [self startRecording];

    }

}



- (void)startRecording {

    NSString *name = [NSString stringWithFormat:@"gcc_%ld.mp4", (long)time(NULL)];

    NSURL *url = [NSURL fileURLWithPath:

                  [NSTemporaryDirectory() stringByAppendingPathComponent:name]];

    NSError *err = nil;

    self.videoWriter = [[AVAssetWriter alloc] initWithURL:url

                                                 fileType:AVFileTypeMPEG4 error:&err];

    if (err || !self.videoWriter) {

        NSLog(@"[gcc] AVAssetWriter init fail: %@", err.localizedDescription);

        return;

    }



    // 录制尺寸 = GLKView drawable 的像素尺寸（与 glReadPixels 读到的 framebuffer

    // 完全一致），避免 AVAssetWriter 与像素缓冲尺寸不匹配。取偶数以兼容 H.264。

    CGFloat scale = self.view.contentScaleFactor;

    int w = (int)(self.metalView.bounds.size.width  * scale) & ~1;

    int h = (int)(self.metalView.bounds.size.height * scale) & ~1;

    if (w <= 0 || h <= 0) { w = 720; h = 1280; }

    NSDictionary *settings = @{

        AVVideoCodecKey: AVVideoCodecTypeH264,

        AVVideoWidthKey: @(w),

        AVVideoHeightKey: @(h),

        AVVideoCompressionPropertiesKey: @{

            AVVideoAverageBitRateKey: @(6000000),

            AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel,

        },

    };

    self.videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo

                                                              outputSettings:settings];

    self.videoWriterInput.expectsMediaDataInRealTime = YES;

    if (![self.videoWriter canAddInput:self.videoWriterInput]) {

        NSLog(@"[gcc] cannot add video input");

        return;

    }

    [self.videoWriter addInput:self.videoWriterInput];



    NSDictionary *pxAttrs = @{

        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),

        (id)kCVPixelBufferWidthKey: @(w),

        (id)kCVPixelBufferHeightKey: @(h),

    };

    self.videoAdaptor = [AVAssetWriterInputPixelBufferAdaptor

        assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.videoWriterInput

                                   sourcePixelBufferAttributes:pxAttrs];

    if (![self.videoWriter startWriting]) {

        NSLog(@"[gcc] startWriting fail: %@", self.videoWriter.error.localizedDescription);

        return;

    }



    self.videoFrameNo = 0;

    self.videoStartTime = kCMTimeZero;

    self.videoOutURL = url;

    self.recording = YES;

    [self.recordButton setTitle:@"■ 停止" forState:UIControlStateNormal];

    NSLog(@"[gcc] recording started %dx%d -> %@", w, h, url.path);

}



- (void)stopRecording {

    if (!self.recording) return;

    self.recording = NO;

    [self.recordButton setTitle:@"● 录像" forState:UIControlStateNormal];

    AVAssetWriter *writer = self.videoWriter;

    AVAssetWriterInput *input = self.videoWriterInput;

    NSURL *url = self.videoOutURL;

    [input markAsFinished];

    [writer finishWritingWithCompletionHandler:^{

        if (writer.status == AVAssetWriterStatusCompleted) {

            // 拷到相册/文件 App 可见目录

            NSString *doc = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,

                                NSUserDomainMask, YES).firstObject;

            NSString *dst = [doc stringByAppendingPathComponent:url.lastPathComponent];

            [[NSFileManager defaultManager] removeItemAtPath:dst error:NULL];

            NSError *ce = nil;

            [[NSFileManager defaultManager] copyItemAtPath:url.path toPath:dst error:&ce];

            NSLog(@"[gcc] recording saved -> %@ (%@)", dst, ce.localizedDescription);

        } else {

            NSLog(@"[gcc] finishWriting fail: %@", writer.error.localizedDescription);

        }

    }];

    self.videoWriter = nil;

    self.videoWriterInput = nil;

    self.videoAdaptor = nil;

}



@end



#pragma mark - Capture delegate



@implementation CameraViewController (AVCaptureVideoDataOutputSampleBufferDelegate)



- (void)captureOutput:(AVCaptureOutput *)output

didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer

       fromConnection:(AVCaptureConnection *)connection {

    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);

    if (!imageBuffer) { return; }



    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)imageBuffer;

    size_t w = CVPixelBufferGetWidth(pixelBuffer);

    size_t h = CVPixelBufferGetHeight(pixelBuffer);

    if (w == 0 || h == 0 || !self.beauty || !self.mtlQueue) { return; }



    id<CAMetalDrawable> drawable = self.metalView.currentDrawable;

    if (!drawable) { return; }



    id<MTLCommandBuffer> cmdBuf = [self.mtlQueue commandBuffer];

    if (!cmdBuf) { return; }



    self.displayWidth  = (int)w;

    self.displayHeight = (int)h;

    self.frameCount   += 1;



    // ★ 送这一帧去做人脸关键点检测（每 3 帧一次，后台队列，不阻塞渲染）
    [self requestFaceDetection:pixelBuffer];

    // 整条 Metal 链路：BGRA → 磨皮 → 形变 → 网格妆容 → 调色 → 上屏

    [self.beauty renderPixelBuffer:pixelBuffer

                       intoTexture:drawable.texture

                        parameters:[self beautyParams]

                     commandBuffer:cmdBuf];



    // 拍照 / 录像：present 之前从 drawable 读回

    [self captureFromDrawable:drawable cmdBuf:cmdBuf];



    [cmdBuf presentDrawable:drawable];

    [cmdBuf commit];



    if (self.frameCount % 30 == 0) {

        dispatch_async(dispatch_get_main_queue(), ^{

            [self refreshStatusWithPrefix:@""];

        });

    }

}



// ---- GccColorFx → GccBeautyParams ----

- (GccBeautyParams)beautyParams {
    GccBeautyParams p = gcc_beauty_params_neutral();
    GccColorFx fx = self.colorFx;
    BOOL on = (self.beautySwitch.selectedSegmentIndex != 0);

    // ---- 肤质组：从 51 槽位表读回 ----
    if (on) {
        p.smooth       = gcc_slot_get_local("skin");
        p.whiten       = gcc_slot_get_local("whiten");
        p.clarity      = gcc_slot_get_local("sharpen");
        p.darkCircle   = gcc_slot_get_local("dark");
        p.nasolabial   = gcc_slot_get_local("smile");
        p.eyeBrighten  = gcc_slot_get_local("eye");
        // rosy（红润）在 51 槽位表里没有独立项，返回 0。
        // 改为跟随「美白」的一半强度 —— 美白拉高时皮肤自然带一点血色。
        p.rosy         = p.whiten * 0.5f;
    }

    // ---- 抖音官方形变系数（gcc_deform_coef.h，逐字抄自 FaceWarpXControl.lua）----
    // UI 滑条是 0..1（0.5 中性）；官方 composer value 是 -1..1（0 中性）。
    // gcc_deform_intensity() 完成 (v-0.5)*2 再乘官方 onEvent 系数，
    // 之后 MSL 里的经验系数负责「强度 → 位移」那一层（保留不动）。
#define W(tag)  gcc_deform_intensity(gcc_slot_get_local(tag), tag)
#define WA(i)   ((gcc_slot_get_at(i) - 0.5f) * 2.0f)   // 无 composer key 的几何项

    // ---- 形变组：严格按安卓真值表 GCC_ANDROID_SLOTS 的 wkey 读回 ----
    //
    // 注意：安卓有两套通道 —— BI_WKEY（composer）与 BI_KEY（JS facedistortion）。
    //   iOS 没有 JS 运行时，只能用 composer key。
    //   有 4 项 composer key 为 NULL（眼距/眼角/眼位/眉挑），
    //   它们只能靠 GPU 几何形变（warp shader 里的 eyeDistK/eyeCornerK/eyePosK/browLiftK），
    //   GccBeautyParams 里对应的字段仍然保留，供 warp shader 使用。
    if (on) {
        p.faceSlim       = W("Face_ALL");                       // [2]
        p.headSmall      = W("smaller_head");                   // [3]
        p.eyeSize        = W("Eye_ALL");                        // [4]
        p.pupilSize      = W("fd_pupil_v6");                    // [6]
        p.lowerEyelid    = W("fd_lower_eyelid_v6");              // [7]
        p.smile          = W("fd_mouse_corner_v6");              // [10]
        p.faceSmall      = W("Internal_Deform_Face");           // [11]
        p.cheekbone      = W("Internal_Deform_Zoom_Cheekbone"); // [14]
        p.mouthShape     = W("Mouth_ALL");                      // [18]
        p.mouthPos       = W("fd_mouse_position_v6");           // [19]
        p.mouthWidth     = W("fd_mouse_width_v6");              // [20]
        p.upperLip       = W("fd_upper_lip_v6");                // [21]
        p.foreheadHeight = W("Internal_Deform_Forehead");       // [22]
        p.cutFace        = W("Internal_Deform_CutFace");        // [23]
        p.cheekboneSlim  = W("Internal_Deform_Zoom_Cheekbone"); // [24] 与[14]共用
        p.chinLength     = W("fd_underjaw_v6");                  // [25]
        p.noseSlim       = W("Internal_Deform_Nose");           // [26]
        p.noseWidth      = W("fd_nose_wing_v6");                // [27]
        p.noseBridge     = W("fd_nose_bridge_v6");              // [28]
        p.nosePos        = W("fd_nose_tip_v6");                 // [33]
        p.eyeTailUp      = W("fd_outer_corner_v6");             // [34]
        p.chinPointy     = W("fd_jaw_v6");                      // [36]

        // 以下 4 项 composer 无 key，只靠 warp shader 的几何形变。
        // 仍然读回滑条值，让 warp shader 拿到。
        p.eyeDist        = WA(30);   // [30] eye_far   —— 几何
        p.eyeCorner      = WA(31);   // [31] eye_rotate —— 几何
        p.eyePos         = WA(32);   // [32] eye_move  —— 几何
        p.browLift       = WA(35);   // [35] eye_eyebrowjump —— 几何
    }

    // ---- 妆容组：基础 5 项 + 9 个色号 + 4 个整装预设 ----
    if (on) {
        // ---- 妆容：按安卓的「互斥家族」语义 ----
        //
        // makeup.lua 里口红是一个互斥家族：Lips_female / _ds / _fg / _xy / _yq
        // 都写同一个全局 lips_female_intensity 和 Unify_lips，谁最后处理谁生效。
        // 所以同一时间只能有一个非零 —— 用「取最大且只保留最大值」实现。
        {
            float v[5] = {
                gcc_slot_get_local("Lips_female"),    gcc_slot_get_local("Lips_Female_ds"),
                gcc_slot_get_local("Lips_Female_fg"), gcc_slot_get_local("Lips_Female_xy"),
                gcc_slot_get_local("Lips_Female_yq")
            };
            float best = 0; int bi = 0;
            for (int i = 0; i < 5; i++) if (v[i] > best) { best = v[i]; bi = i; }
            p.lipColor = fmaxf(best, self.lipStrength);
            // 记录当前生效的色号索引（0..4），供 shader 选 LUT
            self.activeLipShade = bi;

            float b[5] = {
                gcc_slot_get_local("Blusher_female"),    gcc_slot_get_local("Blusher_Female_ds"),
                gcc_slot_get_local("Blusher_Female_qw"), gcc_slot_get_local("Blusher_Female_tc"),
                gcc_slot_get_local("Blusher_Female_zx")
            };
            float bb = 0; int bbi = 0;
            for (int i = 0; i < 5; i++) if (b[i] > bb) { bb = b[i]; bbi = i; }
            p.blush = fmaxf(bb, self.blushStrength);
            self.activeBlushShade = bbi;

            float fc[5] = {
                gcc_slot_get_local("Facial_ALL"),    gcc_slot_get_local("Facial_ALL_jl"),
                gcc_slot_get_local("Facial_ALL_sg"), gcc_slot_get_local("Facial_ALL_yj"),
                gcc_slot_get_local("Facial_ALL_vl")
            };
            float ff = 0; int ffi = 0;
            for (int i = 0; i < 5; i++) if (fc[i] > ff) { ff = fc[i]; ffi = i; }
            p.foundation = fmaxf(ff, self.foundationStrength);
            self.activeFacialShade = ffi;
        }

        p.eyeShadow  = fmaxf(gcc_slot_get_local("Eye_Female_01"),  self.eyeStrength);
        p.teeth      = fmaxf(gcc_slot_get_local("Teeth_ALL"),      self.teethStrength);
        // eyebrow：51 槽位表里没有独立眉毛项，用眼妆值兜底
        p.eyebrow    = p.eyeShadow;

        p.lipFrostbite   = gcc_slot_get_local("Lips_Female_ds");
        p.lipRetro       = gcc_slot_get_local("Lips_Female_fg");
        p.lipGrapefruit  = gcc_slot_get_local("Lips_Female_xy");
        p.lipVitality    = gcc_slot_get_local("Lips_Female_yq");
        p.blushFrostbite = gcc_slot_get_local("Blusher_Female_ds");
        p.blushRose      = gcc_slot_get_local("Blusher_Female_qw");
        p.blushOrange    = gcc_slot_get_local("Blusher_Female_tc");
        p.blushBrown     = gcc_slot_get_local("Blusher_Female_zx");
        p.eyeShadowMale  = gcc_slot_get_local("Eye_Male_01");

        p.presetFairy    = gcc_slot_get_local("Facial_ALL_jl");
        p.presetDewy     = gcc_slot_get_local("Facial_ALL_sg");
        p.presetHazy     = gcc_slot_get_local("Facial_ALL_yj");
        p.presetVFace    = gcc_slot_get_local("Facial_ALL_vl");
    }

    // ---- 调色 8 项透传（MSL 侧逐字对应 color_fx.c）----
    p.brightness  = fx.bright;
    p.contrast    = fx.contra;
    p.saturation  = fx.satur;
    p.temperature = fx.warm;
    p.vignette    = fx.vign;
    p.grain       = fx.grain;

    [self.beauty setColorFxBright:fx.bright contra:fx.contra satur:fx.satur
                             warm:fx.warm vign:fx.vign grain:fx.grain
                           lutMix:fx.lut_mix seed:fx.seed];
#undef W
#undef WA

    return p;
}




// ---- 从 drawable 读回像素 ----

- (void)captureFromDrawable:(id<CAMetalDrawable>)drawable

                     cmdBuf:(id<MTLCommandBuffer>)cmdBuf {

    if (!self.photoRequested && !self.recording) return;



    id<MTLTexture> tex = drawable.texture;

    if (!tex) return;

    NSUInteger tw = tex.width, th = tex.height;

    if (tw == 0 || th == 0) return;



    MTLTextureDescriptor *d =

        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:tex.pixelFormat

                                                           width:tw height:th mipmapped:NO];

    d.usage = MTLTextureUsageShaderRead;

    d.storageMode = MTLStorageModeShared;

    id<MTLTexture> rb = [self.mtlDevice newTextureWithDescriptor:d];

    if (!rb) return;



    id<MTLBlitCommandEncoder> blit = [cmdBuf blitCommandEncoder];

    if (!blit) return;

    [blit copyFromTexture:tex sourceSlice:0 sourceLevel:0

             sourceOrigin:MTLOriginMake(0, 0, 0)

               sourceSize:MTLSizeMake(tw, th, 1)

                toTexture:rb destinationSlice:0 destinationLevel:0

         destinationOrigin:MTLOriginMake(0, 0, 0)];

    [blit endEncoding];



    if (self.photoRequested) {

        self.photoRequested = NO;

        __weak typeof(self) ws = self;

        [cmdBuf addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull cb) {

            [ws savePhotoFromTexture:rb];

        }];

    }

    if (self.recording && self.videoAdaptor && self.videoWriterInput.readyForMoreMediaData) {

        self.videoFrameNo += 1;

        if ((self.videoFrameNo % 2) == 0) {

            __weak typeof(self) ws = self;

            [cmdBuf addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull cb) {

                [ws appendVideoFromTexture:rb];

            }];

        }

    }

}



- (void)savePhotoFromTexture:(id<MTLTexture>)tex {

    NSUInteger w = tex.width, h = tex.height;

    if (w == 0 || h == 0) return;

    size_t rowBytes = w * 4;

    NSMutableData *buf = [NSMutableData dataWithLength:rowBytes * h];

    [tex getBytes:buf.mutableBytes bytesPerRow:rowBytes

       fromRegion:MTLRegionMake2D(0, 0, w, h) mipmapLevel:0];

    UIImage *img = [self imageFromBGRA:buf.bytes w:(int)w h:(int)h];

    if (img) {

        UIImageWriteToSavedPhotosAlbum(img, self,

            @selector(image:didFinishSavingWithError:contextInfo:), NULL);

        self.photoSeq += 1;

        NSLog(@"[gcc] photo saved #%ld %lux%lu", (long)self.photoSeq,

              (unsigned long)w, (unsigned long)h);

    }

}



- (void)appendVideoFromTexture:(id<MTLTexture>)tex {

    NSUInteger w = tex.width, h = tex.height;

    if (w == 0 || h == 0) return;

    if (!self.videoAdaptor || !self.videoWriterInput.readyForMoreMediaData) return;



    CVPixelBufferRef pb = NULL;

    NSDictionary *attrs = @{

        (id)kCVPixelBufferCGImageCompatibilityKey: @YES,

        (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES,

        (id)kCVPixelBufferIOSurfacePropertiesKey: @{},

    };

    if (CVPixelBufferCreate(kCFAllocatorDefault, w, h,

                            kCVPixelFormatType_32BGRA,

                            (__bridge CFDictionaryRef)attrs, &pb) != kCVReturnSuccess || !pb) {

        return;

    }



    size_t srcRow = w * 4;

    NSMutableData *buf = [NSMutableData dataWithLength:srcRow * h];

    [tex getBytes:buf.mutableBytes bytesPerRow:srcRow

       fromRegion:MTLRegionMake2D(0, 0, w, h) mipmapLevel:0];



    CVPixelBufferLockBaseAddress(pb, 0);

    uint8_t *dst = (uint8_t *)CVPixelBufferGetBaseAddress(pb);

    size_t dstRow = CVPixelBufferGetBytesPerRow(pb);

    const uint8_t *src = buf.bytes;

    for (NSUInteger y = 0; y < h; y++) {

        memcpy(dst + y * dstRow, src + y * srcRow, srcRow);

    }

    CVPixelBufferUnlockBaseAddress(pb, 0);



    // ★ 首帧把 videoStartTime 定为 kCMTimeZero（原值是 kCMTimeInvalid，

    //   CMTimeAdd(kCMTimeInvalid, x) 仍是 invalid，AVAssetWriter 会直接拒收）

    if (!CMTIME_IS_VALID(self.videoStartTime)) {

        self.videoStartTime = kCMTimeZero;

    }

    CMTime ts = CMTimeAdd(self.videoStartTime,

                          CMTimeMake((int64_t)self.videoFrameNo, 30));

    [self.videoAdaptor appendPixelBuffer:pb withPresentationTime:ts];

    CVPixelBufferRelease(pb);

}



// BGRA → UIImage（Metal 纹理自上而下，与 UIKit 一致，无需翻转）

- (UIImage *)imageFromBGRA:(const unsigned char *)px w:(int)w h:(int)h {

    if (!px || w <= 0 || h <= 0) return nil;

    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();

    CGContextRef ctx = CGBitmapContextCreate(NULL, w, h, 8, w * 4, cs,

        kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);

    CGColorSpaceRelease(cs);

    if (!ctx) return nil;

    memcpy(CGBitmapContextGetData(ctx), px, (size_t)w * h * 4);

    CGImageRef cg = CGBitmapContextCreateImage(ctx);

    CGContextRelease(ctx);

    UIImage *img = cg ? [UIImage imageWithCGImage:cg] : nil;

    if (cg) CGImageRelease(cg);

    return img;

}



@end

