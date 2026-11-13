// CameraViewController.h — 相机预览 + 特效处理。
//
// 预览链路（Metal 版）：
//   AVCaptureSession -> CVPixelBuffer (kCVPixelFormatType_32BGRA)
//     -> CVMetalTextureCacheCreateTextureFromImage 零拷贝造 MTLTexture
//     -> GccMetalBeauty 多 pass（磨皮/形变/妆容/调色，全是 MSL）
//     -> MTKView 上屏 + 拍照/录像从 drawable 读回
//
// ★ 显示层已全量改为 Metal / MTKView，不再用 GLKView / OpenGL ES。
//   gcc_beauty.metal 逐字移植抖音官方 GLSL，与安卓 setRenderApi 语义等价。

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface CameraViewController : UIViewController

@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, strong) dispatch_queue_t videoQueue;

// 最近一帧的处理结果，-1 表示还没跑过。
@property (nonatomic, assign) int lastProcessResult;
@property (nonatomic, assign) NSInteger frameCount;

// 引擎初始化结果；0 表示成功。
@property (nonatomic, assign) int initResult;
// 最近一帧引擎返回的纹理 id（用于回显），0 表示还没有。
@property (nonatomic, assign) unsigned int outputTexture;

- (void)startPreview;
- (void)stopPreview;

// 把一帧交给特效引擎。texture 必须是 GL texture id（由 CVOpenGLESTextureCache 造出）。
- (int)processPixelBuffer:(CVPixelBufferRef)pixelBuffer
                  texture:(unsigned int)texture
                    width:(int)width
                   height:(int)height
               timestamp:(double)timestamp;

@end
