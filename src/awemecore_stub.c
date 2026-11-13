// awemecore_stub.c — 轻量替代 984MB 的 AwemeCore.framework（仅链接/加载用）
//
// 背景（2026-11-10 真机签名失败）：
//   全能签/zsign 在 iOS 进程里 mmap 984MB 的 AwemeCore 失败，
//   errno 12 (ENOMEM) → "Signed Failed"。iOS 用户态进程地址空间装不下这么大的
//   单文件 mmap，与包内容、证书无关。
//
// AwemeCore 对本工程的实际作用只有一处：给 js_runtime.c 提供 8 个 LEPUS/NAPI
// 符号（QuickJS 运行时壳）。其余 98% 是抖音主程序本体，我们一个字节都用不到。
//
// 本文件提供这 8 个符号的安全桩：
//   LEPUS_NewRuntime() 返回 NULL
//     → js_runtime_init() 第一步就走 if(!g_rt) return -1，
//       优雅失败，状态栏显示 js[rt=-1 ... ready=0]，不会崩、不会跳野指针。
//   其余全部空操作 / 返回 0。
//
// 同时 EffectSDKFramework 对 @rpath/AwemeCore.framework/AwemeCore 的强依赖，
// 由 pack_ipa.py（--keep 去掉 AwemeCore）就地改成 LC_LOAD_WEAK_DYLIB：
// dyld 找不到这个 framework 时不再 abort，只把符号绑 0。主程序自身对这 8 个
// 符号的引用在链接期已由本文件解析，不走 dyld ordinal，因此不受影响。
//
// ⚠ 明确代价：桩构建里 JS 运行时不可用 → 依赖 JS 场景脚本（bootstrap.js /
//   FaceDistortionController.js 等）的功能不会生效。composer 直连的 51 槽位、
//   算法装载、LUT、拍照录像、调色全部照常，可先验证这条主线。
//   需要 JS 时，把 workflow 的 LITE 关掉、回到完整 AwemeCore 包，并在 PC 上签名
//   （PC 内存足够 mmap 984MB）。
//
// 注意：bef_effect_javascript_* 这 4 个符号由 EffectSDKFramework 提供，
// 本文件绝不定义，否则链接期重复符号。

#include <stddef.h>

typedef void *JsRuntime;
typedef void *JsContext;
typedef void *NapiEnv;

// 返回 NULL：让 js_runtime_init 在第一步优雅退出。
JsRuntime LEPUS_NewRuntime(void) { return NULL; }
void      LEPUS_FreeRuntime(JsRuntime rt) { (void)rt; }
JsContext LEPUS_NewContext(JsRuntime rt) { (void)rt; return NULL; }
void      LEPUS_FreeContext(JsContext ctx) { (void)ctx; }
void      LEPUS_SetRuntimeInfo(JsRuntime rt, const char *info) {
    (void)rt; (void)info;
}

NapiEnv   napi_new_env(void) { return NULL; }
void      napi_free_env(NapiEnv env) { (void)env; }
void      napi_attach_quickjs(NapiEnv env, JsContext ctx) {
    (void)env; (void)ctx;
}
