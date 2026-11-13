// js_runtime.h — iOS 侧自建 JS 运行时（QuickJS/LEPUS + N-API），把 effect 包的 main.bundle 跑起来。
//
// 背景：安卓端所有美颜/美型/妆效功能都挂在 effect 包的 JS 层（AmazingProRuntime.js /
// FaceDistortionController.js / Plugins/*.js），iOS 侧此前只调了 bef_effect_* 的 C 接口，
// 完全绕过了 JS 层，所以能力只有安卓的 15%。本模块补上这一层。
//
// 引擎内部调用链（EffectSDKFramework 反汇编 0x16d694 / 0x3f8f8）：
//     set_url_translate_func(h, fn)
//     set_scene_key(h, "AmazingModule")
//     bef_effect_javascript_binding_engine(env, arg2, 0)   ← 只做注册，不建运行时
// 运行时由 AwemeCore 提供：LEPUS_NewRuntime / LEPUS_NewContext / napi_new_env / napi_attach_quickjs。
#ifndef JS_RUNTIME_H
#define JS_RUNTIME_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// 建运行时 + 绑定引擎。成功后引擎才会执行 effect 包里的 bootstrap.js 与业务 JS。
// resource_root：effect 资源根目录（与 bef_init 传的是同一个）。
// scene_key：场景键，抖音官方用 "AmazingModule"。
// 返回 0 成功；非 0 见 js_runtime_error()。
int  js_runtime_init(const char *resource_root, const char *scene_key);

// 拆运行时（在 bef_shutdown 之前调）。
void js_runtime_shutdown(void);

// 失败原因（不是 malloc 出来的，别 free）。
const char *js_runtime_error(void);

// 运行时状态：1 = 已建，0 = 未建。
int  js_runtime_ready(void);

// 诊断：各步骤返回值，形如 "rt=1 ctx=1 env=1 attach=0 bind=0 finder=0 key=0"。
const char *js_runtime_report(void);

#ifdef __cplusplus
}
#endif

#endif /* JS_RUNTIME_H */
