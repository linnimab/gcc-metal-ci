// color_fx.h — iOS 端「调色 8 项 + 官方 LUT 滤镜」GL 通道。
//
// 来源：Android CameraActivity.java buildRgbProgram()（:6870-6975），逐行移植。
// 安卓侧实证（docs/114、docs/119）：这 8 项调色 + 5/8 档 LUT 全部是「自写 GLSL
// 在 drawTexture 最后一 pass 完成」，完全绕开 EffectSDK，与 composer / JS / 内置
// 美颜包无关 —— 因此也是 iOS 端最容易补齐、且不需要真机就能 CI 验证的一块能力。
//
// 与安卓的差异（必须在注释里说清，避免以后误判）：
//   - 安卓把美白/锐化也做在同一个 pass（uWhiten/uSharpen）。
//     iOS 侧 51 槽位表已把 whiten/sharpen 映射到 update_beauty（effect_slots.c），
//     为避免「两处同时生效、效果叠加过头」，本模块不重复做美白/锐化，只做
//     色调六项 + LUT。若真机 A/B 认为引擎那条无效，再打开 GCC_FX_DO_WHITEN_SHARPEN。
//   - 相机帧在 iOS 是上下颠倒的，由 uFlip 处理（安卓在上一 pass 已摆正）。
//
// 本模块不依赖 EffectSDK / AwemeCore / JS，纯 OpenGLES2 + CoreGraphics，
// 单独编译即可（CI 里只需把 color_fx.c 加进 Xcode target）。

#ifndef GCC_COLOR_FX_H
#define GCC_COLOR_FX_H

#include <stddef.h>
#include <OpenGLES/ES2/gl.h>

#ifdef __cplusplus
extern "C" {
#endif

// 中性值 = 0.5（亮度/对比度/饱和度/色温），暗角/颗粒中性 = 0.0。
// 与安卓 fxBright/fxContra/fxSatur/fxWarm/fxVign/fxGrain 逐字对应。
typedef struct {
    float bright;    // 0.5 中性；±0.25 线性提降
    float contra;    // 0.5 中性；0.5..1.6 倍
    float satur;     // 0.5 中性；0..2 倍
    float warm;      // 0.5 中性；>0.5 加红减蓝
    float vign;      // 0 关；按到中心距离平方压暗
    float grain;     // 0 关；hash 噪声
    float lut_mix;   // LUT 混合强度 0..1；0=原图
    float seed;      // 颗粒噪声种子，每帧递增
} GccColorFx;

// 返回中性配置。
GccColorFx gcc_fx_neutral(void);

// 编译调色 program + 建全屏 quad。返回 0 成功。
// 必须在已 setCurrentContext 的 GL 线程调用一次。
int  gcc_fx_init(void);

// 上传一张 512x512 64³ tiled LUT 贴图。
// rgba 必须是 512*512*4 字节、非预乘 RGBA8、行序与 PNG 像素一致（左上→右下）。
// PNG 解码由调用方（CameraViewController.m 用 UIImage）完成 —— iOS 没有
// CGImageCreateWithPNGDataProvider 这个公开 API，放 .c 里会编译失败。
// 多次调用复用同一纹理对象、替换内容。lut_mix=0 时不采样，可先设 0 再换图。
int  gcc_fx_load_lut(const unsigned char *rgba, size_t bytes);

// 用当前 GccColorFx 画一帧：把 tex 经调色后输出到「当前绑定的 framebuffer」。
// tex      : 输入 GL texture id（引擎输出或原图相机纹理）
// w, h     : 纹理像素尺寸（用于 uTexel / uRes）
// flip     : 1 = 上下翻转（iOS 相机纹理需要）
// fx       : 本帧参数
// 返回 0 成功；program/纹理未就绪返回非 0（调用方应回退到直通 blit）。
int  gcc_fx_draw(GLuint tex, int w, int h, int flip, int mirror,
                 float frame_aspect, float view_aspect, const GccColorFx *fx);

// 释放 program / vbo / LUT 纹理。
void gcc_fx_shutdown(void);

// 诊断：最近一次 glGetProgramiv(LINK_STATUS) 的日志（失败时排查用）。
const char *gcc_fx_last_error(void);

#ifdef __cplusplus
}
#endif

#endif /* GCC_COLOR_FX_H */
