// mini_js_runtime.c — 轻量 JS 运行时（系统 JavaScriptCore 实现 LEPUS/NAPI 契约）
// 契约来源：AwemeCore 反汇编（QuickJSVM ctor / napi_attach_quickjs 二参 / ctx+0x158）。
// 目标：SDK 自带 JSScriptSystem 拿到 napi_env 后能创建 runtime/context 并执行
// effect 包里的 bootstrap.js / AmazingProRuntime.js，激活妆效节点。
#include <stdlib.h>
#include <string.h>
#include <objc/objc.h>
#include <JavaScriptCore/JavaScriptCore.h>

typedef void *JsRuntime;
typedef void *JsContext;
typedef void *NapiEnv;

// LEPUSRuntime / LEPUSContext 用 JSGlobalContextRef 家族对象承载。
// 结构体里塞一个 malloc 的 token，保证「非 NULL」且可 free。
typedef struct { JSContextGroupRef group; char info[64]; } GccRt;
typedef struct { JSGlobalContextRef ctx; void *attached; } GccCtx;
typedef struct { void *ctx; char pad[512]; } GccEnv;

JsRuntime gcc_builtin_LEPUS_NewRuntime(void) {
    GccRt *r = (GccRt *)calloc(1, sizeof(GccRt));
    if (!r) return NULL;
    r->group = JSContextGroupCreate();
    return (JsRuntime)r;
}
void gcc_builtin_LEPUS_FreeRuntime(JsRuntime rt) {
    if (!rt) return;
    GccRt *r = (GccRt *)rt;
    if (r->group) JSContextGroupRelease(r->group);
    free(r);
}
JsContext gcc_builtin_LEPUS_NewContext(JsRuntime rt) {
    if (!rt) return NULL;
    GccCtx *c = (GccCtx *)calloc(1, sizeof(GccCtx));
    if (!c) return NULL;
    c->ctx = JSGlobalContextCreateInGroup(((GccRt *)rt)->group, NULL);
    return (JsContext)c;
}
void gcc_builtin_LEPUS_FreeContext(JsContext ctx) {
    if (!ctx) return;
    GccCtx *c = (GccCtx *)ctx;
    if (c->ctx) JSGlobalContextRelease((JSGlobalContextRef)c->ctx);
    free(c);
}
void gcc_builtin_LEPUS_SetRuntimeInfo(JsRuntime rt, const char *info) {
    if (!rt) return;
    strncpy(((GccRt *)rt)->info, info ? info : "", sizeof(((GccRt *)rt)->info) - 1);
}
NapiEnv gcc_builtin_napi_new_env(void) {
    GccEnv *e = (GccEnv *)calloc(1, sizeof(GccEnv));
    return (NapiEnv)e;
}
void gcc_builtin_napi_free_env(NapiEnv env) { free(env); }
// 二参：把包装对象挂回 ctx+0x158 的等价语义；这里用 GccCtx.attached 保存 env。
void gcc_builtin_napi_attach_quickjs(NapiEnv env, JsContext ctx) {
    if (!ctx) return;
    GccCtx *c = (GccCtx *)ctx;
    c->attached = env;
    if (env) ((GccEnv *)env)->ctx = ctx;
}
