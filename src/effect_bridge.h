// effect_bridge.h — effect_bridge.c 的对外接口。
#ifndef EFFECT_BRIDGE_H
#define EFFECT_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef int64_t BefEffectHandle;

// 按 Android 端验证过的顺序完成初始化。resource_root 与 effect_leaf_dir 都不能为空，
// 宽高也必须是真实值，否则后续每帧会返回 -6。
int  bef_init(const char *resource_root,
              const char *effect_leaf_dir,
              int width, int height,
              bool front_camera);

void bef_shutdown(void);

// 上美颜/滤镜 + composer 节点图。
// ⚠ 返回 0 只表示「滤镜/composer/消息通道被接受」，不表示美颜生效 ——
//    set_beauty 是恒 -3 的 stub，真美颜入口是 bef_set_beauty_intensity。
int  bef_apply_default_look(void);

// ★ 真美颜强度接口：(handle, fSmoothIntensity, fBrightenIntensity)
// 签名由 .rodata 铁证 + iOS(@0x1c9b8)/安卓(@0x358480) 双端逐指令复核。
int  bef_set_beauty_intensity(float smooth, float brighten);

// 每帧处理。device_texture 在 iOS 上传 CVPixelBuffer 的 handle。
int  bef_process_frame(int device_texture, int width, int height, double timestamp);

const char    *bef_version(void);
BefEffectHandle bef_handle(void);

// ★ 2026-11-10：算法/人脸引擎 + JS 运行时 的启动自检报告。
//   形如 "gpu=0 algo=5/5 builtin=0 js[rt=1 ctx=1 env=1 bind=0 ready=1]"
//   真机上第一行就能看出卡在哪一环，不需要连电脑抓日志。
const char    *bef_algo_report(void);

#ifdef __cplusplus
}
#endif

#endif /* EFFECT_BRIDGE_H */