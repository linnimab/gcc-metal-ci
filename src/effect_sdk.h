// effect_sdk.h — 运行时解耦版（2026-11-11）
//
// 真机二分结论：7KB 空壳（只链系统框架）能起；正式包在主函数之前被
// EffectSDKFramework 的 dyld 挂载拖死、零输出。故主程序不再 LC_LOAD_DYLIB 该库，
// 全部 bef_* 改为函数指针，由 effect_dynamic.c 在 UI 起来后 dlopen/dlsym。
// 挂载失败时指针指向安全 no-op（返回 -3），界面/相机/调色/拍照录像照常存活。
// 妆效节点、资源包、画质、分辨率、算法频率、精度全部保持不变。

#ifndef EFFECT_SDK_H
#define EFFECT_SDK_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef int64_t BefEffectHandle;

/* ---- 运行时引擎挂载 API ---- */
int         gcc_engine_load(void);      /* 0 = 全部符号就位；>0 = 缺失数；<0 = dlopen 失败 */
int         gcc_engine_loaded(void);
const char *gcc_engine_report(void);
const char *gcc_engine_error(void);

/* 每个 bef_* 映射到同名函数指针；所有既有调用点无需改动。 */
extern int (*gcc_fn_bef_effect_create)(BefEffectHandle *out_handle);
#define bef_effect_create gcc_fn_bef_effect_create
extern int (*gcc_fn_bef_effect_create_handle)(bool use_gl, BefEffectHandle *out_handle);
#define bef_effect_create_handle gcc_fn_bef_effect_create_handle
extern int (*gcc_fn_bef_effect_destroy)(BefEffectHandle handle);
#define bef_effect_destroy gcc_fn_bef_effect_destroy
extern int (*gcc_fn_bef_effect_init)(BefEffectHandle handle);
#define bef_effect_init gcc_fn_bef_effect_init
extern int (*gcc_fn_bef_effect_init_with_resource_finder_v2)(BefEffectHandle handle, void *arg1, void *arg2, void *finder_or_null, void *arg4);
#define bef_effect_init_with_resource_finder_v2 gcc_fn_bef_effect_init_with_resource_finder_v2
extern int (*gcc_fn_bef_effect_init_with_gpdevice)(BefEffectHandle handle, void *gp_device);
#define bef_effect_init_with_gpdevice gcc_fn_bef_effect_init_with_gpdevice
extern int (*gcc_fn_bef_effect_init_with_resource_finder_and_gpdevice)(BefEffectHandle handle, void *finder, void *gp_device);
#define bef_effect_init_with_resource_finder_and_gpdevice gcc_fn_bef_effect_init_with_resource_finder_and_gpdevice
extern int (*gcc_fn_bef_effect_init_with_resource_finder)(BefEffectHandle handle, void *finder);
#define bef_effect_init_with_resource_finder gcc_fn_bef_effect_init_with_resource_finder
extern int (*gcc_fn_bef_effect_set_cache_directory)(BefEffectHandle handle, const char *dir);
#define bef_effect_set_cache_directory gcc_fn_bef_effect_set_cache_directory
extern int (*gcc_fn_bef_effect_set_width_height)(BefEffectHandle handle, int width, int height);
#define bef_effect_set_width_height gcc_fn_bef_effect_set_width_height
extern int (*gcc_fn_bef_effect_set_sticker)(BefEffectHandle handle, const char *effect_dir);
#define bef_effect_set_sticker gcc_fn_bef_effect_set_sticker
extern int (*gcc_fn_bef_effect_set_sticker_with_tag)(BefEffectHandle handle, const char *effect_dir, const char *tag);
#define bef_effect_set_sticker_with_tag gcc_fn_bef_effect_set_sticker_with_tag
extern int (*gcc_fn_bef_effect_set_sticker_with_tag_v2)(BefEffectHandle handle, const char *effect_dir, const char *tag, void *arg);
#define bef_effect_set_sticker_with_tag_v2 gcc_fn_bef_effect_set_sticker_with_tag_v2
extern int (*gcc_fn_bef_effect_load_gpu_resource)(BefEffectHandle handle);
#define bef_effect_load_gpu_resource gcc_fn_bef_effect_load_gpu_resource
extern int (*gcc_fn_bef_effect_load_algorithm)(BefEffectHandle handle, const char *algo_name);
#define bef_effect_load_algorithm gcc_fn_bef_effect_load_algorithm
extern int (*gcc_fn_bef_effect_use_amazing_builtin)(BefEffectHandle handle, bool enable);
#define bef_effect_use_amazing_builtin gcc_fn_bef_effect_use_amazing_builtin
extern int (*gcc_fn_bef_effect_set_render_api)(BefEffectHandle handle, bool use_gl);
#define bef_effect_set_render_api gcc_fn_bef_effect_set_render_api
extern int (*gcc_fn_bef_effect_process_texture)(BefEffectHandle handle, int texture_id, int width, int height, int rotation, double timestamp);
#define bef_effect_process_texture gcc_fn_bef_effect_process_texture
extern int (*gcc_fn_bef_effect_process_texture_device_texture)(BefEffectHandle handle, int device_texture, int width, int height, int rotation, double timestamp);
#define bef_effect_process_texture_device_texture gcc_fn_bef_effect_process_texture_device_texture
extern int (*gcc_fn_bef_effect_process_texture_with_extra_info)(BefEffectHandle handle, int texture_id, int width, int height, int rotation, double timestamp, void *extra);
#define bef_effect_process_texture_with_extra_info gcc_fn_bef_effect_process_texture_with_extra_info
extern int (*gcc_fn_bef_effect_process_texture_with_native_buffer)(BefEffectHandle handle, void *cv_pixel_buffer, int width, int height, int rotation, double timestamp);
#define bef_effect_process_texture_with_native_buffer gcc_fn_bef_effect_process_texture_with_native_buffer
extern int (*gcc_fn_bef_effect_process_textures_with_native_buffers)(BefEffectHandle handle, void **buffers, int count, int width, int height, int rotation, double timestamp);
#define bef_effect_process_textures_with_native_buffers gcc_fn_bef_effect_process_textures_with_native_buffers
extern int (*gcc_fn_bef_effect_set_camera_device_position)(BefEffectHandle handle, bool is_front);
#define bef_effect_set_camera_device_position gcc_fn_bef_effect_set_camera_device_position
extern int (*gcc_fn_bef_effect_set_orientation)(BefEffectHandle handle, int orientation);
#define bef_effect_set_orientation gcc_fn_bef_effect_set_orientation
extern int (*gcc_fn_bef_effect_set_frame_orientation)(BefEffectHandle handle, int orientation);
#define bef_effect_set_frame_orientation gcc_fn_bef_effect_set_frame_orientation
extern int (*gcc_fn_bef_effect_process_touch_down_event)(BefEffectHandle handle, float x, float y);
#define bef_effect_process_touch_down_event gcc_fn_bef_effect_process_touch_down_event
extern int (*gcc_fn_bef_effect_process_touch_up_event)(BefEffectHandle handle, float x, float y);
#define bef_effect_process_touch_up_event gcc_fn_bef_effect_process_touch_up_event
extern int (*gcc_fn_bef_effect_process_touchEvent)(BefEffectHandle handle, int type, float x, float y);
#define bef_effect_process_touchEvent gcc_fn_bef_effect_process_touchEvent
extern int (*gcc_fn_bef_effect_process_pan_event)(BefEffectHandle handle, float dx, float dy);
#define bef_effect_process_pan_event gcc_fn_bef_effect_process_pan_event
extern int (*gcc_fn_bef_effect_process_scaleEvent)(BefEffectHandle handle, float scale);
#define bef_effect_process_scaleEvent gcc_fn_bef_effect_process_scaleEvent
extern int (*gcc_fn_bef_effect_process_rotationEvent)(BefEffectHandle handle, float angle);
#define bef_effect_process_rotationEvent gcc_fn_bef_effect_process_rotationEvent
extern int (*gcc_fn_bef_effect_process_double_click_event)(BefEffectHandle handle);
#define bef_effect_process_double_click_event gcc_fn_bef_effect_process_double_click_event
extern int (*gcc_fn_bef_effect_set_beauty)(BefEffectHandle handle, const char *key, float a, float b);
#define bef_effect_set_beauty gcc_fn_bef_effect_set_beauty
extern int (*gcc_fn_bef_effect_set_reshape_face)(BefEffectHandle handle, const char *key, float a, float b);
#define bef_effect_set_reshape_face gcc_fn_bef_effect_set_reshape_face
extern int (*gcc_fn_bef_effect_set_makeup)(BefEffectHandle handle, const char *key, void *param);
#define bef_effect_set_makeup gcc_fn_bef_effect_set_makeup
extern int (*gcc_fn_bef_effect_set_color_filter)(BefEffectHandle handle, const char *key, float intensity);
#define bef_effect_set_color_filter gcc_fn_bef_effect_set_color_filter
extern int (*gcc_fn_bef_effect_set_color_filter_v2)(BefEffectHandle handle, const char *key, float intensity);
#define bef_effect_set_color_filter_v2 gcc_fn_bef_effect_set_color_filter_v2
extern int (*gcc_fn_bef_effect_update_beauty)(BefEffectHandle handle, float fSmoothIntensity, float fBrightenIntensity);
#define bef_effect_update_beauty gcc_fn_bef_effect_update_beauty
extern int (*gcc_fn_bef_effect_set_intensity)(BefEffectHandle handle, int bef_intensity_type, float intensity);
#define bef_effect_set_intensity gcc_fn_bef_effect_set_intensity
extern int (*gcc_fn_bef_effect_set_composer)(BefEffectHandle handle, const char *path);
#define bef_effect_set_composer gcc_fn_bef_effect_set_composer
extern int (*gcc_fn_bef_effect_composer_set_nodes)(BefEffectHandle handle, const char **nodes, int count);
#define bef_effect_composer_set_nodes gcc_fn_bef_effect_composer_set_nodes
extern int (*gcc_fn_bef_effect_composer_set_nodes_with_tags)(BefEffectHandle handle, const char **nodes, int count, const char **tags, int tag_count);
#define bef_effect_composer_set_nodes_with_tags gcc_fn_bef_effect_composer_set_nodes_with_tags
extern int (*gcc_fn_bef_effect_composer_append_nodes)(BefEffectHandle handle, const char **nodes, int count);
#define bef_effect_composer_append_nodes gcc_fn_bef_effect_composer_append_nodes
extern int (*gcc_fn_bef_effect_composer_append_nodes_with_tags)(BefEffectHandle handle, const char **nodes, int count, const char **tags, int tag_count);
#define bef_effect_composer_append_nodes_with_tags gcc_fn_bef_effect_composer_append_nodes_with_tags
extern int (*gcc_fn_bef_effect_composer_update_node)(BefEffectHandle handle, const char *node, const char *key, float value);
#define bef_effect_composer_update_node gcc_fn_bef_effect_composer_update_node
extern int (*gcc_fn_bef_effect_composer_reload_nodes)(BefEffectHandle handle, const char **nodes, int count);
#define bef_effect_composer_reload_nodes gcc_fn_bef_effect_composer_reload_nodes
extern int (*gcc_fn_bef_effect_composer_set_mode)(BefEffectHandle handle, int mode, int sub_mode);
#define bef_effect_composer_set_mode gcc_fn_bef_effect_composer_set_mode
extern int (*gcc_fn_bef_effect_composer_dump_nodes)(BefEffectHandle handle, char *buffer, int capacity);
#define bef_effect_composer_dump_nodes gcc_fn_bef_effect_composer_dump_nodes
extern int (*gcc_fn_bef_effect_composer_get_node_value)(BefEffectHandle handle, const char *node, float *out_value);
#define bef_effect_composer_get_node_value gcc_fn_bef_effect_composer_get_node_value
extern int (*gcc_fn_bef_effect_composer_get_node_paths)(BefEffectHandle handle, char *buffer, int capacity);
#define bef_effect_composer_get_node_paths gcc_fn_bef_effect_composer_get_node_paths
extern int (*gcc_fn_bef_effect_composer_update_multiple_nodes)(BefEffectHandle handle, const char **nodes, const char **keys, const float *values, int count);
#define bef_effect_composer_update_multiple_nodes gcc_fn_bef_effect_composer_update_multiple_nodes
extern int (*gcc_fn_bef_effect_composer_release_dump_result)(BefEffectHandle handle, char *buffer);
#define bef_effect_composer_release_dump_result gcc_fn_bef_effect_composer_release_dump_result
extern int (*gcc_fn_bef_effect_set_render_cache_texture)(BefEffectHandle handle, int texture_id);
#define bef_effect_set_render_cache_texture gcc_fn_bef_effect_set_render_cache_texture
extern int (*gcc_fn_bef_effect_set_render_cache_texture_with_buffer)(BefEffectHandle handle, void *buffer, int width, int height);
#define bef_effect_set_render_cache_texture_with_buffer gcc_fn_bef_effect_set_render_cache_texture_with_buffer
extern int (*gcc_fn_bef_effect_set_render_cache_int_value)(BefEffectHandle handle, const char *key, int value);
#define bef_effect_set_render_cache_int_value gcc_fn_bef_effect_set_render_cache_int_value
extern int (*gcc_fn_bef_effect_set_render_cache_string_value)(BefEffectHandle handle, const char *key, const char *value);
#define bef_effect_set_render_cache_string_value gcc_fn_bef_effect_set_render_cache_string_value
extern int (*gcc_fn_bef_effect_send_msg)(BefEffectHandle handle, int64_t what, int64_t arg1, int64_t arg2, const char *payload);
#define bef_effect_send_msg gcc_fn_bef_effect_send_msg
extern int (*gcc_fn_bef_effect_get_remark)(BefEffectHandle handle, const char **out);
#define bef_effect_get_remark gcc_fn_bef_effect_get_remark
extern int (*gcc_fn_bef_effect_get_face_count)(BefEffectHandle handle);
#define bef_effect_get_face_count gcc_fn_bef_effect_get_face_count
extern int (*gcc_fn_bef_effect_javascript_binding_engine)(void *env, void *arg2, void *arg3);
#define bef_effect_javascript_binding_engine gcc_fn_bef_effect_javascript_binding_engine
extern int (*gcc_fn_bef_effect_javascript_set_resource_finder)(void *handle, void *finder_ctx, void *finder_fn);
#define bef_effect_javascript_set_resource_finder gcc_fn_bef_effect_javascript_set_resource_finder
extern int (*gcc_fn_bef_effect_javascript_set_scene_key)(void *handle, const char *scene_key);
#define bef_effect_javascript_set_scene_key gcc_fn_bef_effect_javascript_set_scene_key
extern int (*gcc_fn_bef_effect_javascript_set_ab_config)(void *handle, const char *json);
#define bef_effect_javascript_set_ab_config gcc_fn_bef_effect_javascript_set_ab_config

#ifdef __cplusplus
}
#endif

#endif /* EFFECT_SDK_H */
