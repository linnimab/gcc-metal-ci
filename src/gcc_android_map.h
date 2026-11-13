#ifndef GCC_ANDROID_MAP_H
#define GCC_ANDROID_MAP_H

/*
 * gcc_android_map.h — 51 槽位的安卓真值表
 *
 * 数据来源（逐字抄自）：
 *   android/gate/src/main/java/com/gcc/gate/CameraActivity.java
 *     BI_LABEL[51]  —— 中文标签
 *     BI_WKEY[51]   —— DyMakeup 场景的 composer key（可为 null）
 *     BI_KEY[51]    —— JS facedistortion_* 后缀（可为 null）
 *     BI_NEUT[51]   —— 中性值（形变 0.5，其它 0）
 *
 * 重要事实：
 *   1. composer key 只有 30 个非空，其余 21 项只能走 JS 通道。
 *      iOS 侧没有 JS 运行时，这 21 项必须用几何形变实现（已在 warp shader 里做）。
 *   2. BI_KEY（JS）和 BI_WKEY（composer）是两个独立通道，语义不完全等价：
 *        槽位 23「窄脸」  JS=face_zoom        composer=Internal_Deform_CutFace
 *        槽位 11「小脸」  JS=face_jawbonezoom composer=Internal_Deform_Face
 *      安卓两个通道都写，iOS 只有 composer，所以要按 BI_WKEY 取。
 *   3. 槽位 14「立体」与 24「瘦颧骨」共用 Internal_Deform_Zoom_Cheekbone —— 
 *      引擎只有一个颧骨通道，两项同时拉会叠加，这是抖音原本的行为。
 */

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define GCC_ANDROID_SLOT_COUNT 51

typedef struct {
    int         index;        /* 槽位下标 0..50 */
    const char *label;        /* 中文标签（BI_LABEL） */
    const char *wkey;         /* composer key（BI_WKEY），NULL = 无 */
    const char *jskey;        /* JS key（BI_KEY），NULL = 无 */
    float       neutral;      /* 中性值（BI_NEUT） */
} GccAndroidSlot;

static const GccAndroidSlot GCC_ANDROID_SLOTS[GCC_ANDROID_SLOT_COUNT] = {
/* idx  label          wkey                              jskey                 neut */
{  0, "无",           NULL,                             NULL,                 0.0f },
{  1, "磨皮",         "skin",                           "skin",               0.0f },
{  2, "瘦脸",         "Face_ALL",                       "face_zoom",          0.5f },
{  3, "小头",         "smaller_head",                   NULL,                 0.5f },
{  4, "大眼",         "Eye_ALL",                        "eye_zoom",           0.5f },
{  5, "眼妆",         "Eye_Female_01",                  NULL,                 0.0f },
{  6, "瞳孔大小",      "fd_pupil_v6",                    NULL,                 0.5f },
{  7, "眼睑下至",      "fd_lower_eyelid_v6",             NULL,                 0.5f },
{  8, "清晰",         "sharpen",                        "sharpen",            0.0f },
{  9, "美白",         "whiten",                         "whiten",             0.0f },
{ 10, "微笑",         "fd_mouse_corner_v6",             "lips_smlie",         0.5f },
{ 11, "小脸",         "Internal_Deform_Face",           "face_jawbonezoom",   0.5f },
{ 12, "口红",         "Lips_female",                    NULL,                 0.0f },
{ 13, "腮红",         "Blusher_female",                 NULL,                 0.0f },
{ 14, "立体",         "Internal_Deform_Zoom_Cheekbone", "face_cheekbonezoom", 0.5f },
{ 15, "白牙",         "Teeth_ALL",                      NULL,                 0.0f },
{ 16, "黑眼圈",       "dark",                           "dark",               0.0f },
{ 17, "法令纹",       "smile",                          "smile",              0.0f },
{ 18, "嘴形",         "Mouth_ALL",                      "lips_zoom",          0.5f },
{ 19, "嘴巴位置",      "fd_mouse_position_v6",           "lips_move",          0.5f },
{ 20, "嘴巴宽度",      "fd_mouse_width_v6",              NULL,                 0.5f },
{ 21, "丰上唇",        "fd_upper_lip_v6",                "lips_enhance",       0.5f },
{ 22, "额头",         "Internal_Deform_Forehead",       "face_forehad",       0.5f },
{ 23, "窄脸",         "Internal_Deform_CutFace",        "face_zoom",          0.5f },
{ 24, "瘦颧骨",        "Internal_Deform_Zoom_Cheekbone", "face_cheekbonezoom", 0.5f },
{ 25, "下颚",         "fd_underjaw_v6",                  "face_chinmove",      0.5f },
{ 26, "瘦鼻",         "Internal_Deform_Nose",           "nose_zoom",          0.5f },
{ 27, "鼻翼",         "fd_nose_wing_v6",                NULL,                 0.5f },
{ 28, "鼻梁",         "fd_nose_bridge_v6",               NULL,                 0.5f },
{ 29, "亮眼",         "eye",                            "eye",                0.0f },
{ 30, "眼距",         NULL,                             "eye_far",            0.5f },
{ 31, "眼角",         NULL,                             "eye_rotate",         0.5f },
{ 32, "眼位",         NULL,                             "eye_move",           0.5f },
{ 33, "鼻位",         "fd_nose_tip_v6",                 "nose_move",          0.5f },
{ 34, "眼尾上扬",      "fd_outer_corner_v6",             "eye_eyecorner",      0.5f },
{ 35, "眉挑",         NULL,                             "eye_eyebrowjump",    0.5f },
{ 36, "尖下巴",        "fd_jaw_v6",                      "face_chinpointy",    0.5f },
{ 37, "口红·冻伤",     "Lips_Female_ds",                 NULL,                 0.0f },
{ 38, "口红·复古",     "Lips_Female_fg",                 NULL,                 0.0f },
{ 39, "口红·西柚",     "Lips_Female_xy",                 NULL,                 0.0f },
{ 40, "口红·元气",     "Lips_Female_yq",                 NULL,                 0.0f },
{ 41, "腮红·冻伤",     "Blusher_Female_ds",              NULL,                 0.0f },
{ 42, "腮红·蔷薇",     "Blusher_Female_qw",              NULL,                 0.0f },
{ 43, "腮红·甜橙",     "Blusher_Female_tc",              NULL,                 0.0f },
{ 44, "腮红·棕调",     "Blusher_Female_zx",              NULL,                 0.0f },
{ 45, "眼妆·男",       "Eye_Male_01",                    NULL,                 0.0f },
{ 46, "底妆",         "Facial_ALL",                     NULL,                 0.0f },
{ 47, "底妆·精灵",     "Facial_ALL_jl",                  NULL,                 0.0f },
{ 48, "底妆·水光",     "Facial_ALL_sg",                  NULL,                 0.0f },
{ 49, "底妆·氤氲",     "Facial_ALL_yj",                  NULL,                 0.0f },
{ 50, "底妆·V脸",      "Facial_ALL_vl",                  NULL,                 0.0f },
};

/* ------------------------------------------------------------------ *
 * 口红 / 腮红 / 眼妆的「性别对偶」tag
 *
 * makeup.lua 的 onUpdate 按人脸性别分派：
 *   if attr.boyProb < 0.4 then 用 lips_female_intensity
 *   else                        用 lips_male_intensity
 * 面板只发女性 tag，如果人脸被判成男性就完全不上色
 * （表现：滑条拖满没反应，日志一切正常）。
 * 所以安卓侧做了单向镜像写入 —— iOS 也照做。
 * ------------------------------------------------------------------ */
static inline const char *gcc_mirror_gender_tag(const char *key) {
    if (!key) return NULL;
    struct { const char *from, *to; } M[] = {
        { "Lips_female",       "Lips_Male" },
        { "Lips_Female_ds",    "Lips_Male_ds" },
        { "Lips_Female_fg",    "Lips_Male_fg" },
        { "Lips_Female_xy",    "Lips_Male_xy" },
        { "Lips_Female_yq",    "Lips_Male_yq" },
        { "Blusher_female",    "Blusher_Male" },
        { "Blusher_Female_ds", "Blusher_Male_ds" },
        { "Blusher_Female_qw", "Blusher_Male_qw" },
        { "Blusher_Female_tc", "Blusher_Male_tc" },
        { "Blusher_Female_zx", "Blusher_Male_zx" },
        { "Eye_Female_01",     "Eye_Male_01" },
    };
    for (size_t i = 0; i < sizeof(M) / sizeof(M[0]); i++) {
        const char *a = M[i].from, *b = key;
        while (*a && *a == *b) { a++; b++; }
        if (*a == 0 && *b == 0) return M[i].to;
    }
    return NULL;
}

/* 口红家族（互斥：同时只能有一个非零）—— 槽位 12/37/38/39/40 */
static inline int gcc_is_lip_family(const char *key) {
    if (!key) return 0;
    const char *names[] = {
        "Lips_female", "Lips_Female_ds", "Lips_Female_fg",
        "Lips_Female_xy", "Lips_Female_yq",
        "Lips_Male", "Lips_Male_ds", "Lips_Male_fg",
        "Lips_Male_xy", "Lips_Male_yq"
    };
    for (size_t i = 0; i < sizeof(names)/sizeof(names[0]); i++) {
        const char *a = names[i], *b = key;
        while (*a && *a == *b) { a++; b++; }
        if (*a == 0 && *b == 0) return 1;
    }
    return 0;
}

/* 腮红家族 —— 槽位 13/41/42/43/44 */
static inline int gcc_is_blush_family(const char *key) {
    if (!key) return 0;
    const char *names[] = {
        "Blusher_female", "Blusher_Female_ds", "Blusher_Female_qw",
        "Blusher_Female_tc", "Blusher_Female_zx",
        "Blusher_Male", "Blusher_Male_ds", "Blusher_Male_qw",
        "Blusher_Male_tc", "Blusher_Male_zx"
    };
    for (size_t i = 0; i < sizeof(names)/sizeof(names[0]); i++) {
        const char *a = names[i], *b = key;
        while (*a && *a == *b) { a++; b++; }
        if (*a == 0 && *b == 0) return 1;
    }
    return 0;
}

/* 底妆家族 —— 槽位 46/47/48/49/50 */
static inline int gcc_is_facial_family(const char *key) {
    if (!key) return 0;
    const char *names[] = {
        "Facial_ALL", "Facial_ALL_jl", "Facial_ALL_sg",
        "Facial_ALL_yj", "Facial_ALL_vl"
    };
    for (size_t i = 0; i < sizeof(names)/sizeof(names[0]); i++) {
        const char *a = names[i], *b = key;
        while (*a && *a == *b) { a++; b++; }
        if (*a == 0 && *b == 0) return 1;
    }
    return 0;
}

#ifdef __cplusplus
}
#endif

#endif /* GCC_ANDROID_MAP_H */
