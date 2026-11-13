// js_runtime.c — iOS 侧自建 JS 运行时（LEPUS/QuickJS + N-API）。
//
// 证据链（全部来自 EffectSDKFramework / AwemeCore 反汇编，见 docs/124）：
//
// 1) EffectSDKFramework 自己不实现 JS 运行时，这 5 个符号全是 undef，由 AwemeCore 提供：
//      _LEPUS_NewRuntime     AwemeCore 0x13045ed4
//      _LEPUS_NewContext     AwemeCore 0x130c11b8
//      _LEPUS_SetRuntimeInfo AwemeCore 0x13047b20
//      _napi_new_env         AwemeCore 0x13045bb4   (malloc 0x4c8)
//      _napi_attach_quickjs  AwemeCore 0x1304b658
//
// 2) AwemeCore 的 QuickJSVM 构造函数 0x13051c5c 就是标准做法：
//      env  = this->env            (基类 ctor 0x13045b28 里调 napi_new_env)
//      rt   = LEPUS_NewRuntime()   (经 0x13045e64 单例包装，含 LEPUS_SetRuntimeInfo)
//      ctx  = LEPUS_NewContext(rt)
//      napi_attach_quickjs(env, ctx)     ← 只两参，见下方 extern 处的反汇编证据
//    原始指令：
//      0x13051ca8  bl  #0x130c11b8         ; LEPUS_NewContext(rt)
//      0x13051cb0  str x1, [x19, #0x20]    ; this+0x20 = ctx
//      0x13051cb4  ldr x0, [x19, #8]       ; x0 = env
//      0x13051cb8  bl  #0x1304b658         ; napi_attach_quickjs(env, ctx)
//    注意 x1 在 0x13051cac 被 `mov x1, x0` 赋成 ctx，x2 从未被设置 —— 所以是二参。
//
// 3) EffectSDKFramework 里 bef_effect_javascript_binding_engine 只有一个调用点 0x16d694，
//    它按这个顺序做三件事：
//      bef_effect_javascript_set_url_translate_func(x0, fn)
//      bef_effect_javascript_set_scene_key(x0, "AmazingModule")
//      bef_effect_javascript_binding_engine(x0, arg3, 0)   ← x0 就是 napi_env
//    这三个 setter 都不使用 x0（各自取内部单例），所以 handle 传 0 是安全的。
//
// 结论：只要按上面顺序把运行时建出来并 bind 给引擎，effect 包里的 bootstrap.js /
// AmazingProRuntime.js / FaceDistortionController.js 就会开始跑，安卓那套
// __gccShape / __gccBeauty / __gccFx 的等价能力才可能在 iOS 上出现。
//
// ⚠ 本文件尚未在真机验证过（本机无 Mac、无 iOS 设备）。所有返回值都通过
//   js_runtime_report() 暴露，接上真机后第一件事就是看这份报告。

#include "js_runtime.h"
#include "effect_sdk.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>
#include <dlfcn.h>

// --- AwemeCore 提供的 JS 运行时（签名由 AwemeCore 反汇编确认）----------------
// LEPUS 是 QuickJS 的字节跳动分支，LEPUS_* 与 JS_* 一一对应。
typedef void *JsRuntime;   // LEPUSRuntime*
typedef void *JsContext;   // LEPUSContext*
typedef void *NapiEnv;     // napi_env

// ★ 启动期不强链 AwemeCore：8 个 JS 运行时符号改为运行时取址。
//   effect_dynamic.c 以 RTLD_NOW|RTLD_GLOBAL dlopen EffectSDKFramework 时，
//   dyld 连带把它的强依赖 AwemeCore(1GB) 加载进进程，且符号为 GLOBAL，
//   此后 RTLD_DEFAULT 的 dlsym 即可拿到真符号。开屏那一秒不映射 1GB。
typedef JsRuntime (*fn_NewRuntime)(void);
typedef void      (*fn_FreeRuntime)(JsRuntime);
typedef JsContext (*fn_NewContext)(JsRuntime);
typedef void      (*fn_FreeContext)(JsContext);
typedef void      (*fn_SetRuntimeInfo)(JsRuntime, const char *);
typedef NapiEnv   (*fn_napi_new_env)(void);
typedef void      (*fn_napi_free_env)(NapiEnv);
typedef void      (*fn_napi_attach_quickjs)(NapiEnv, JsContext);

static fn_NewRuntime        p_NewRuntime = NULL;
static fn_FreeRuntime       p_FreeRuntime = NULL;
static fn_NewContext        p_NewContext = NULL;
static fn_FreeContext       p_FreeContext = NULL;
static fn_SetRuntimeInfo    p_SetRuntimeInfo = NULL;
static fn_napi_new_env      p_napi_new_env = NULL;
static fn_napi_free_env     p_napi_free_env = NULL;
static fn_napi_attach_quickjs p_napi_attach_quickjs = NULL;

static char g_bind_error[256] = "";

static int js_bind_symbols(void) {
    void *h = RTLD_DEFAULT;                 // 真库已由 dlopen 连带加载
    void *ac = dlopen("@executable_path/Frameworks/AwemeCore.framework/AwemeCore", RTLD_NOW | RTLD_GLOBAL);
    void *hh[2]; int nh = 0;
    hh[nh++] = h; if (ac) hh[nh++] = ac;
    #define BIND(p, name) do { \
        for (int k = 0; k < nh && !(p); k++) (p) = (void *)dlsym(hh[k], name); \
    } while (0)
    BIND(p_NewRuntime,         "LEPUS_NewRuntime");
    BIND(p_FreeRuntime,        "LEPUS_FreeRuntime");
    BIND(p_NewContext,         "LEPUS_NewContext");
    BIND(p_FreeContext,        "LEPUS_FreeContext");
    BIND(p_SetRuntimeInfo,      "LEPUS_SetRuntimeInfo");
    BIND(p_napi_new_env,        "napi_new_env");
    BIND(p_napi_free_env,       "napi_free_env");
    BIND(p_napi_attach_quickjs,  "napi_attach_quickjs");
    #undef BIND
    if (!p_NewRuntime || !p_FreeRuntime || !p_NewContext || !p_FreeContext ||
        !p_SetRuntimeInfo || !p_napi_new_env || !p_napi_free_env || !p_napi_attach_quickjs) {
        snprintf(g_bind_error, sizeof(g_bind_error),
                 "js symbols unresolved (rt=%d ctx=%d env=%d attach=%d)",
                 p_NewRuntime != NULL, p_NewContext != NULL,
                 p_napi_new_env != NULL, p_napi_attach_quickjs != NULL);
        return -1;
    }
    return 0;
}

// javascript_* 接口已由 effect_sdk.h 以运行时函数指针形式提供（dlopen 后解析）。

// --- 状态 -------------------------------------------------------------------
static JsRuntime g_rt = NULL;
static JsContext g_ctx = NULL;
static NapiEnv   g_env = NULL;

static int g_ready = 0;
static int g_rc_rt = -999, g_rc_ctx = -999, g_rc_env = -999;
static int g_rc_attach = -999, g_rc_bind = -999, g_rc_finder = -999, g_rc_key = -999;

static char g_report[256] = "not-init";
static char g_error[256] = "";

// resource finder 回调：引擎要资源时按 root/name 拼绝对路径交回去。
static char g_root[1024] = {0};

static void *js_find_resource(const char *name) {
    if (!name || !g_root[0]) { return NULL; }
    size_t n = strlen(g_root) + strlen(name) + 2;
    char *full = (char *)malloc(n);
    if (!full) { return NULL; }
    snprintf(full, n, "%s/%s", g_root, name);
    return full;
}

static void refresh_report(void) {
    snprintf(g_report, sizeof(g_report),
             "rt=%d ctx=%d env=%d attach=%d bind=%d finder=%d key=%d ready=%d",
             g_rc_rt, g_rc_ctx, g_rc_env, g_rc_attach, g_rc_bind,
             g_rc_finder, g_rc_key, g_ready);
}

int js_runtime_init(const char *resource_root, const char *scene_key) {
    if (g_ready) { return 0; }
    if (js_bind_symbols() != 0) {
        snprintf(g_error, sizeof(g_error), "%s", g_bind_error);
        refresh_report();
        return -90;
    }

    if (resource_root && resource_root[0]) {
        strncpy(g_root, resource_root, sizeof(g_root) - 1);
        g_root[sizeof(g_root) - 1] = 0;
    }
    if (!scene_key || !scene_key[0]) { scene_key = "AmazingModule"; }

    // 1) runtime
    g_rt = p_NewRuntime();
    g_rc_rt = g_rt ? 0 : -1;
    if (!g_rt) {
        snprintf(g_error, sizeof(g_error), "p_NewRuntime returned NULL");
        refresh_report();
        return -1;
    }
    p_SetRuntimeInfo(g_rt, "GoodColorCam");

    // 2) context
    g_ctx = p_NewContext(g_rt);
    g_rc_ctx = g_ctx ? 0 : -1;
    if (!g_ctx) {
        snprintf(g_error, sizeof(g_error), "p_NewContext returned NULL");
        p_FreeRuntime(g_rt); g_rt = NULL;
        refresh_report();
        return -2;
    }

    // 3) napi env
    g_env = p_napi_new_env();
    g_rc_env = g_env ? 0 : -1;
    if (!g_env) {
        snprintf(g_error, sizeof(g_error), "p_napi_new_env returned NULL");
        p_FreeContext(g_ctx); g_ctx = NULL;
        p_FreeRuntime(g_rt);  g_rt  = NULL;
        refresh_report();
        return -3;
    }

    // 4) 把 env 挂到 ctx 上（引擎从这里拿到 napi，再注册自己的全局桥）
    //    注意是 ctx 不是 rt：napi_attach_quickjs 内部把包装对象写回 ctx+0x158。
    p_napi_attach_quickjs(g_env, g_ctx);
    g_rc_attach = 0;

    // 5) 资源查找回调：JS 里 require('xxx') / loadScene 都要走这里
    //    setter 内部只取单例、不用 handle，所以第一个参数传 0。
    g_rc_finder = bef_effect_javascript_set_resource_finder(0, (void *)g_ctx, (void *)js_find_resource);

    // 6) 场景键：抖音官方是 "AmazingModule"
    g_rc_key = bef_effect_javascript_set_scene_key(0, scene_key);

    // 7) 绑引擎。第二个参数引擎自己那份 bootstrap(0x16d694) 传的是它的 arg3，
    //    在只有 env 的场景下传 NULL；第三个参数引擎固定传 0。
    g_rc_bind = bef_effect_javascript_binding_engine((void *)g_env, NULL, NULL);

    g_ready = 1;
    snprintf(g_error, sizeof(g_error), "");
    refresh_report();
    return 0;
}

void js_runtime_shutdown(void) {
    if (g_env && p_napi_free_env) { p_napi_free_env(g_env); g_env = NULL; }
    if (g_ctx) { p_FreeContext(g_ctx); g_ctx = NULL; }
    if (g_rt)  { p_FreeRuntime(g_rt);  g_rt  = NULL; }
    g_ready = 0;
    refresh_report();
}

const char *js_runtime_error(void) { return g_error; }
int js_runtime_ready(void) { return g_ready; }
const char *js_runtime_report(void) { return g_report; }
