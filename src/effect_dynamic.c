// effect_dynamic.c — 特效库运行时挂载（启动壳解耦）
#include "effect_sdk.h"
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

static void *g_h = NULL;
static int   g_loaded = 0;
static int   g_rc = -1;
static char  g_report[256] = "engine=not-loaded";
static char  g_error[256] = "";
static char g_pre_err[1200] = "";

/* 未挂载/挂载失败时的安全兜底：忽略多余寄存器参数，统一返回 -3。 */
static int gcc_stub(void) { return -3; }

int (*gcc_fn_bef_effect_create)(BefEffectHandle *out_handle) = NULL;
int (*gcc_fn_bef_effect_create_handle)(bool use_gl, BefEffectHandle *out_handle) = NULL;
int (*gcc_fn_bef_effect_destroy)(BefEffectHandle handle) = NULL;
int (*gcc_fn_bef_effect_init)(BefEffectHandle handle) = NULL;
int (*gcc_fn_bef_effect_init_with_resource_finder_v2)(BefEffectHandle handle, void *arg1, void *arg2, void *finder_or_null, void *arg4) = NULL;
int (*gcc_fn_bef_effect_init_with_gpdevice)(BefEffectHandle handle, void *gp_device) = NULL;
int (*gcc_fn_bef_effect_init_with_resource_finder_and_gpdevice)(BefEffectHandle handle, void *finder, void *gp_device) = NULL;
int (*gcc_fn_bef_effect_init_with_resource_finder)(BefEffectHandle handle, void *finder) = NULL;
int (*gcc_fn_bef_effect_set_cache_directory)(BefEffectHandle handle, const char *dir) = NULL;
int (*gcc_fn_bef_effect_set_width_height)(BefEffectHandle handle, int width, int height) = NULL;
int (*gcc_fn_bef_effect_set_sticker)(BefEffectHandle handle, const char *effect_dir) = NULL;
int (*gcc_fn_bef_effect_set_sticker_with_tag)(BefEffectHandle handle, const char *effect_dir, const char *tag) = NULL;
int (*gcc_fn_bef_effect_set_sticker_with_tag_v2)(BefEffectHandle handle, const char *effect_dir, const char *tag, void *arg) = NULL;
int (*gcc_fn_bef_effect_load_gpu_resource)(BefEffectHandle handle) = NULL;
int (*gcc_fn_bef_effect_load_algorithm)(BefEffectHandle handle, const char *algo_name) = NULL;
int (*gcc_fn_bef_effect_use_amazing_builtin)(BefEffectHandle handle, bool enable) = NULL;
int (*gcc_fn_bef_effect_set_render_api)(BefEffectHandle handle, bool use_gl) = NULL;
int (*gcc_fn_bef_effect_process_texture)(BefEffectHandle handle, int texture_id, int width, int height, int rotation, double timestamp) = NULL;
int (*gcc_fn_bef_effect_process_texture_device_texture)(BefEffectHandle handle, int device_texture, int width, int height, int rotation, double timestamp) = NULL;
int (*gcc_fn_bef_effect_process_texture_with_extra_info)(BefEffectHandle handle, int texture_id, int width, int height, int rotation, double timestamp, void *extra) = NULL;
int (*gcc_fn_bef_effect_process_texture_with_native_buffer)(BefEffectHandle handle, void *cv_pixel_buffer, int width, int height, int rotation, double timestamp) = NULL;
int (*gcc_fn_bef_effect_process_textures_with_native_buffers)(BefEffectHandle handle, void **buffers, int count, int width, int height, int rotation, double timestamp) = NULL;
int (*gcc_fn_bef_effect_set_camera_device_position)(BefEffectHandle handle, bool is_front) = NULL;
int (*gcc_fn_bef_effect_set_orientation)(BefEffectHandle handle, int orientation) = NULL;
int (*gcc_fn_bef_effect_set_frame_orientation)(BefEffectHandle handle, int orientation) = NULL;
int (*gcc_fn_bef_effect_process_touch_down_event)(BefEffectHandle handle, float x, float y) = NULL;
int (*gcc_fn_bef_effect_process_touch_up_event)(BefEffectHandle handle, float x, float y) = NULL;
int (*gcc_fn_bef_effect_process_touchEvent)(BefEffectHandle handle, int type, float x, float y) = NULL;
int (*gcc_fn_bef_effect_process_pan_event)(BefEffectHandle handle, float dx, float dy) = NULL;
int (*gcc_fn_bef_effect_process_scaleEvent)(BefEffectHandle handle, float scale) = NULL;
int (*gcc_fn_bef_effect_process_rotationEvent)(BefEffectHandle handle, float angle) = NULL;
int (*gcc_fn_bef_effect_process_double_click_event)(BefEffectHandle handle) = NULL;
int (*gcc_fn_bef_effect_set_beauty)(BefEffectHandle handle, const char *key, float a, float b) = NULL;
int (*gcc_fn_bef_effect_set_reshape_face)(BefEffectHandle handle, const char *key, float a, float b) = NULL;
int (*gcc_fn_bef_effect_set_makeup)(BefEffectHandle handle, const char *key, void *param) = NULL;
int (*gcc_fn_bef_effect_set_color_filter)(BefEffectHandle handle, const char *key, float intensity) = NULL;
int (*gcc_fn_bef_effect_set_color_filter_v2)(BefEffectHandle handle, const char *key, float intensity) = NULL;
int (*gcc_fn_bef_effect_update_beauty)(BefEffectHandle handle, float fSmoothIntensity, float fBrightenIntensity) = NULL;
int (*gcc_fn_bef_effect_set_intensity)(BefEffectHandle handle, int bef_intensity_type, float intensity) = NULL;
int (*gcc_fn_bef_effect_set_composer)(BefEffectHandle handle, const char *path) = NULL;
int (*gcc_fn_bef_effect_composer_set_nodes)(BefEffectHandle handle, const char **nodes, int count) = NULL;
int (*gcc_fn_bef_effect_composer_set_nodes_with_tags)(BefEffectHandle handle, const char **nodes, int count, const char **tags, int tag_count) = NULL;
int (*gcc_fn_bef_effect_composer_append_nodes)(BefEffectHandle handle, const char **nodes, int count) = NULL;
int (*gcc_fn_bef_effect_composer_append_nodes_with_tags)(BefEffectHandle handle, const char **nodes, int count, const char **tags, int tag_count) = NULL;
int (*gcc_fn_bef_effect_composer_update_node)(BefEffectHandle handle, const char *node, const char *key, float value) = NULL;
int (*gcc_fn_bef_effect_composer_reload_nodes)(BefEffectHandle handle, const char **nodes, int count) = NULL;
int (*gcc_fn_bef_effect_composer_set_mode)(BefEffectHandle handle, int mode, int sub_mode) = NULL;
int (*gcc_fn_bef_effect_composer_dump_nodes)(BefEffectHandle handle, char *buffer, int capacity) = NULL;
int (*gcc_fn_bef_effect_composer_get_node_value)(BefEffectHandle handle, const char *node, float *out_value) = NULL;
int (*gcc_fn_bef_effect_composer_get_node_paths)(BefEffectHandle handle, char *buffer, int capacity) = NULL;
int (*gcc_fn_bef_effect_composer_update_multiple_nodes)(BefEffectHandle handle, const char **nodes, const char **keys, const float *values, int count) = NULL;
int (*gcc_fn_bef_effect_composer_release_dump_result)(BefEffectHandle handle, char *buffer) = NULL;
int (*gcc_fn_bef_effect_set_render_cache_texture)(BefEffectHandle handle, int texture_id) = NULL;
int (*gcc_fn_bef_effect_set_render_cache_texture_with_buffer)(BefEffectHandle handle, void *buffer, int width, int height) = NULL;
int (*gcc_fn_bef_effect_set_render_cache_int_value)(BefEffectHandle handle, const char *key, int value) = NULL;
int (*gcc_fn_bef_effect_set_render_cache_string_value)(BefEffectHandle handle, const char *key, const char *value) = NULL;
int (*gcc_fn_bef_effect_send_msg)(BefEffectHandle handle, int64_t what, int64_t arg1, int64_t arg2, const char *payload) = NULL;
int (*gcc_fn_bef_effect_get_remark)(BefEffectHandle handle, const char **out) = NULL;
int (*gcc_fn_bef_effect_get_face_count)(BefEffectHandle handle) = NULL;
int (*gcc_fn_bef_effect_javascript_binding_engine)(void *env, void *arg2, void *arg3) = NULL;
int (*gcc_fn_bef_effect_javascript_set_resource_finder)(void *handle, void *finder_ctx, void *finder_fn) = NULL;
int (*gcc_fn_bef_effect_javascript_set_scene_key)(void *handle, const char *scene_key) = NULL;
int (*gcc_fn_bef_effect_javascript_set_ab_config)(void *handle, const char *json) = NULL;

#define GCC_INIT(n)  gcc_fn_##n = (__typeof__(gcc_fn_##n))gcc_stub;
#define GCC_LOAD(n)  do { void *q_ = dlsym(g_h, #n); if (q_) { memcpy(&gcc_fn_##n, &q_, sizeof(q_)); ok_++; } else { miss_++; } } while (0)

static void gcc_init_stubs(void) {
    GCC_INIT(bef_effect_create);
    GCC_INIT(bef_effect_create_handle);
    GCC_INIT(bef_effect_destroy);
    GCC_INIT(bef_effect_init);
    GCC_INIT(bef_effect_init_with_resource_finder_v2);
    GCC_INIT(bef_effect_init_with_gpdevice);
    GCC_INIT(bef_effect_init_with_resource_finder_and_gpdevice);
    GCC_INIT(bef_effect_init_with_resource_finder);
    GCC_INIT(bef_effect_set_cache_directory);
    GCC_INIT(bef_effect_set_width_height);
    GCC_INIT(bef_effect_set_sticker);
    GCC_INIT(bef_effect_set_sticker_with_tag);
    GCC_INIT(bef_effect_set_sticker_with_tag_v2);
    GCC_INIT(bef_effect_load_gpu_resource);
    GCC_INIT(bef_effect_load_algorithm);
    GCC_INIT(bef_effect_use_amazing_builtin);
    GCC_INIT(bef_effect_set_render_api);
    GCC_INIT(bef_effect_process_texture);
    GCC_INIT(bef_effect_process_texture_device_texture);
    GCC_INIT(bef_effect_process_texture_with_extra_info);
    GCC_INIT(bef_effect_process_texture_with_native_buffer);
    GCC_INIT(bef_effect_process_textures_with_native_buffers);
    GCC_INIT(bef_effect_set_camera_device_position);
    GCC_INIT(bef_effect_set_orientation);
    GCC_INIT(bef_effect_set_frame_orientation);
    GCC_INIT(bef_effect_process_touch_down_event);
    GCC_INIT(bef_effect_process_touch_up_event);
    GCC_INIT(bef_effect_process_touchEvent);
    GCC_INIT(bef_effect_process_pan_event);
    GCC_INIT(bef_effect_process_scaleEvent);
    GCC_INIT(bef_effect_process_rotationEvent);
    GCC_INIT(bef_effect_process_double_click_event);
    GCC_INIT(bef_effect_set_beauty);
    GCC_INIT(bef_effect_set_reshape_face);
    GCC_INIT(bef_effect_set_makeup);
    GCC_INIT(bef_effect_set_color_filter);
    GCC_INIT(bef_effect_set_color_filter_v2);
    GCC_INIT(bef_effect_update_beauty);
    GCC_INIT(bef_effect_set_intensity);
    GCC_INIT(bef_effect_set_composer);
    GCC_INIT(bef_effect_composer_set_nodes);
    GCC_INIT(bef_effect_composer_set_nodes_with_tags);
    GCC_INIT(bef_effect_composer_append_nodes);
    GCC_INIT(bef_effect_composer_append_nodes_with_tags);
    GCC_INIT(bef_effect_composer_update_node);
    GCC_INIT(bef_effect_composer_reload_nodes);
    GCC_INIT(bef_effect_composer_set_mode);
    GCC_INIT(bef_effect_composer_dump_nodes);
    GCC_INIT(bef_effect_composer_get_node_value);
    GCC_INIT(bef_effect_composer_get_node_paths);
    GCC_INIT(bef_effect_composer_update_multiple_nodes);
    GCC_INIT(bef_effect_composer_release_dump_result);
    GCC_INIT(bef_effect_set_render_cache_texture);
    GCC_INIT(bef_effect_set_render_cache_texture_with_buffer);
    GCC_INIT(bef_effect_set_render_cache_int_value);
    GCC_INIT(bef_effect_set_render_cache_string_value);
    GCC_INIT(bef_effect_send_msg);
    GCC_INIT(bef_effect_get_remark);
    GCC_INIT(bef_effect_get_face_count);
    GCC_INIT(bef_effect_javascript_binding_engine);
    GCC_INIT(bef_effect_javascript_set_resource_finder);
    GCC_INIT(bef_effect_javascript_set_scene_key);
    GCC_INIT(bef_effect_javascript_set_ab_config);
}

int gcc_engine_load(void) {
    if (g_h) return g_rc;
    gcc_init_stubs();

    char exe[4096] = {0}; uint32_t sz = (uint32_t)sizeof(exe);
    if (_NSGetExecutablePath(exe, &sz) == 0) {
        char *slash = strrchr(exe, '/'); if (slash) *slash = 0;
    } else { strcpy(exe, "@executable_path"); }
    char path[4300];
    snprintf(path, sizeof(path), "%s/Frameworks/EffectSDKFramework.framework/EffectSDKFramework", exe);

    /* ★ 运行时 dlopen 的 @rpath 解析在 /Applications(rootful jbroot) 下不覆盖
       主程序 rpath；dyld 报 "Library not loaded: @rpath/AwemeCore.framework/..."。
       按真实依赖拓扑把三个 @rpath 库用绝对路径 RTLD_GLOBAL 预挂进进程：
       dyld 以 install-name 命中已加载镜像，SDK 随后即可解析到它们。
       顺序：boringssl → TTFFmpeg → AwemeCore，最后才是 SDK。 */
    {
        const char *pre[] = {
            "boringssl.framework/boringssl",
            "TTFFmpeg.framework/TTFFmpeg",
            "AwemeCore.framework/AwemeCore",
            NULL
        };
        for (int i = 0; pre[i]; i++) {
            char dep[4300];
            snprintf(dep, sizeof(dep), "%s/Frameworks/%s", exe, pre[i]);
            void *dh = dlopen(dep, RTLD_LAZY | RTLD_GLOBAL);
            if (!dh) {
                const char *e_ = dlerror();
                char add[420];
                snprintf(add, sizeof(add), "pre[%s]=%s; ", pre[i], e_ ? e_ : "?");
                size_t used = strlen(g_pre_err);
                if (used + strlen(add) + 1 < sizeof(g_pre_err))
                    memcpy(g_pre_err + used, add, strlen(add) + 1);
            } else {
                char add[160];
                snprintf(add, sizeof(add), "pre[%s]=OK; ", pre[i]);
                size_t used = strlen(g_pre_err);
                if (used + strlen(add) + 1 < sizeof(g_pre_err))
                    memcpy(g_pre_err + used, add, strlen(add) + 1);
            }
        }
    }

    const char *cands[] = { path,
        "@executable_path/Frameworks/EffectSDKFramework.framework/EffectSDKFramework",
        "@rpath/EffectSDKFramework.framework/EffectSDKFramework", NULL };
    for (int i = 0; cands[i]; i++) {
        g_h = dlopen(cands[i], RTLD_LAZY | RTLD_GLOBAL);
        if (!g_h) {
            const char *de1 = dlerror();
            snprintf(g_error, sizeof(g_error), "lazy:%s", de1 ? de1 : "?");
            g_h = dlopen(cands[i], RTLD_NOW | RTLD_GLOBAL);
        }
        if (g_h) { snprintf(g_error, sizeof(g_error), "dlopen ok: %s", cands[i]); break; }
        const char *de_ = dlerror();
        snprintf(g_error, sizeof(g_error), "%s", de_ ? de_ : "dlopen failed");
    }
    if (!g_h) {
        g_rc = -1; g_loaded = 0;
        snprintf(g_report, sizeof(g_report), "engine=dlopen-FAILED PRE[%s] | %s", g_pre_err, g_error);
        return g_rc;
    }

    int ok_ = 0, miss_ = 0;
    GCC_LOAD(bef_effect_create);
    GCC_LOAD(bef_effect_create_handle);
    GCC_LOAD(bef_effect_destroy);
    GCC_LOAD(bef_effect_init);
    GCC_LOAD(bef_effect_init_with_resource_finder_v2);
    GCC_LOAD(bef_effect_init_with_gpdevice);
    GCC_LOAD(bef_effect_init_with_resource_finder_and_gpdevice);
    GCC_LOAD(bef_effect_init_with_resource_finder);
    GCC_LOAD(bef_effect_set_cache_directory);
    GCC_LOAD(bef_effect_set_width_height);
    GCC_LOAD(bef_effect_set_sticker);
    GCC_LOAD(bef_effect_set_sticker_with_tag);
    GCC_LOAD(bef_effect_set_sticker_with_tag_v2);
    GCC_LOAD(bef_effect_load_gpu_resource);
    GCC_LOAD(bef_effect_load_algorithm);
    GCC_LOAD(bef_effect_use_amazing_builtin);
    GCC_LOAD(bef_effect_set_render_api);
    GCC_LOAD(bef_effect_process_texture);
    GCC_LOAD(bef_effect_process_texture_device_texture);
    GCC_LOAD(bef_effect_process_texture_with_extra_info);
    GCC_LOAD(bef_effect_process_texture_with_native_buffer);
    GCC_LOAD(bef_effect_process_textures_with_native_buffers);
    GCC_LOAD(bef_effect_set_camera_device_position);
    GCC_LOAD(bef_effect_set_orientation);
    GCC_LOAD(bef_effect_set_frame_orientation);
    GCC_LOAD(bef_effect_process_touch_down_event);
    GCC_LOAD(bef_effect_process_touch_up_event);
    GCC_LOAD(bef_effect_process_touchEvent);
    GCC_LOAD(bef_effect_process_pan_event);
    GCC_LOAD(bef_effect_process_scaleEvent);
    GCC_LOAD(bef_effect_process_rotationEvent);
    GCC_LOAD(bef_effect_process_double_click_event);
    GCC_LOAD(bef_effect_set_beauty);
    GCC_LOAD(bef_effect_set_reshape_face);
    GCC_LOAD(bef_effect_set_makeup);
    GCC_LOAD(bef_effect_set_color_filter);
    GCC_LOAD(bef_effect_set_color_filter_v2);
    GCC_LOAD(bef_effect_update_beauty);
    GCC_LOAD(bef_effect_set_intensity);
    GCC_LOAD(bef_effect_set_composer);
    GCC_LOAD(bef_effect_composer_set_nodes);
    GCC_LOAD(bef_effect_composer_set_nodes_with_tags);
    GCC_LOAD(bef_effect_composer_append_nodes);
    GCC_LOAD(bef_effect_composer_append_nodes_with_tags);
    GCC_LOAD(bef_effect_composer_update_node);
    GCC_LOAD(bef_effect_composer_reload_nodes);
    GCC_LOAD(bef_effect_composer_set_mode);
    GCC_LOAD(bef_effect_composer_dump_nodes);
    GCC_LOAD(bef_effect_composer_get_node_value);
    GCC_LOAD(bef_effect_composer_get_node_paths);
    GCC_LOAD(bef_effect_composer_update_multiple_nodes);
    GCC_LOAD(bef_effect_composer_release_dump_result);
    GCC_LOAD(bef_effect_set_render_cache_texture);
    GCC_LOAD(bef_effect_set_render_cache_texture_with_buffer);
    GCC_LOAD(bef_effect_set_render_cache_int_value);
    GCC_LOAD(bef_effect_set_render_cache_string_value);
    GCC_LOAD(bef_effect_send_msg);
    GCC_LOAD(bef_effect_get_remark);
    GCC_LOAD(bef_effect_get_face_count);
    GCC_LOAD(bef_effect_javascript_binding_engine);
    GCC_LOAD(bef_effect_javascript_set_resource_finder);
    GCC_LOAD(bef_effect_javascript_set_scene_key);
    GCC_LOAD(bef_effect_javascript_set_ab_config);
    g_rc = miss_;
    g_loaded = (miss_ == 0) ? 1 : 0;
    snprintf(g_report, sizeof(g_report), "engine=%s resolved=%d/%d miss=%d",
             g_loaded ? "READY" : "PARTIAL", ok_, ok_ + miss_, miss_);
    fprintf(stderr, "[engine] %s | %s\n", g_report, g_error);
    return g_rc;
}

int         gcc_engine_loaded(void) { return g_loaded; }
const char *gcc_engine_report(void)  { return g_report; }
const char *gcc_engine_error(void)   { return g_error; }

/* main() 之前把指针全部落到安全桩：即便 gcc_engine_load 从未被调用也不会跳 NULL。 */
__attribute__((constructor)) static void gcc_bootstrap(void) {
    gcc_init_stubs();
    snprintf(g_report, sizeof(g_report), "engine=stub (pending load)");
}
