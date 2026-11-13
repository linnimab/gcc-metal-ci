// effect_slots.h - 从安卓侧逆向出来的 51 行滑条表，原样搬到 iOS
//
// 来源：F:\GoodColorCam\work_apk\apkt\full\smali_classes6\com\gcc\gate\CameraActivity.smali
//       .method static constructor <clinit> 里的 BI_KIND / BI_WKEY / BI_LABEL / BI_KEY
//       （values 数组由 filled-new-array/range {v3 .. v53} 构造，51 项一一对应）
//
// kind 语义（与安卓 CameraActivity.biPush 完全一致）：
//   0 = IT_JS    __gccBeauty.set(key, v)        —— 走 JS 运行时
//   1 = IT_GLU   setGlUniform(key, v)           —— 直接写 GL uniform
//   2 = IT_SHAPE __gccShape.set(key, v)         —— 走 JS，再落 FaceDistortionController
//   5 = IT_NONE  跳过（占位行）
//   6 = IT_WARP  composer 节点 (tag, (v-0.5)*2) —— 形变，±1 范围
//   7 = IT_MK    composer 节点 (tag, v)         —— 妆容，0..1 范围
//
// iOS 上没有 JS 运行时也能跑 kind 6 / 7 —— 这正是 value 所在：
// 安卓为了让这 24 个形变 tag 真正进引擎，绕了 Java→jsQueue→__gccEmit→Lua→composer
// 十几轮；iOS 一个 bef_effect_composer_update_node() 直调就行。
//
// 注意（重要）：kind 0 / 1 / 2 在 iOS 侧不能照抄。
//   - kind 2 依赖 FaceDistortionController.js，iOS 无 JS 则无效
//   - kind 1 的 setGlUniform 是安卓 smali 里的私有方法名，不是 SDK 符号
//   - kind 0 依赖 __gccBeauty，iOS 无 JS 则无效
// 这三类在 iOS 上要走各自的原生接口（bef_effect_set_beauty / update_beauty /
// set_color_filter_v2），见表里 ios_api 字段。

#ifndef GCC_EFFECT_SLOTS_H
#define GCC_EFFECT_SLOTS_H

#include <stddef.h>

typedef enum {
    GCC_KIND_JS    = 0,
    GCC_KIND_GLU   = 1,
    GCC_KIND_SHAPE = 2,
    GCC_KIND_NONE  = 5,
    GCC_KIND_WARP  = 6,
    GCC_KIND_MK    = 7
} GccKind;

typedef struct {
    const char *label;    // 中文标签（用于 UI / 日志）
    int         kind;     // GccKind
    const char *tag;      // BI_WKEY：composer 节点 tag 或 JS 键
    const char *js_key;   // BI_KEY：JS 侧额外键，NULL 表示无
} GccSlot;

// 51 行，顺序与安卓 UI 完全一致
static const GccSlot GCC_SLOTS[] = {
    /*  0 */ { "无",         GCC_KIND_NONE,  NULL,                           NULL },
    /*  1 */ { "磨皮",       GCC_KIND_JS,    "skin",                         "skin" },
    /*  2 */ { "瘦脸",       GCC_KIND_WARP,  "Face_ALL",                     "face_zoom" },
    /*  3 */ { "小头",       GCC_KIND_WARP,  "smaller_head",                 NULL },
    /*  4 */ { "大眼",       GCC_KIND_WARP,  "Eye_ALL",                      "eye_zoom" },
    /*  5 */ { "眼妆",       GCC_KIND_MK,    "Eye_Female_01",                NULL },
    /*  6 */ { "瞳孔大小",   GCC_KIND_WARP,  "fd_pupil_v6",                  NULL },
    /*  7 */ { "眼睑下至",   GCC_KIND_WARP,  "fd_lower_eyelid_v6",           NULL },
    /*  8 */ { "清晰",       GCC_KIND_GLU,   "sharpen",                      "sharpen" },
    /*  9 */ { "美白",       GCC_KIND_GLU,   "whiten",                       "whiten" },
    /* 10 */ { "微笑",       GCC_KIND_WARP,  "fd_mouse_corner_v6",           "lips_smlie" },
    /* 11 */ { "小脸",       GCC_KIND_WARP,  "Internal_Deform_Face",         "face_jawbonezoom" },
    /* 12 */ { "口红",       GCC_KIND_MK,    "Lips_female",                  NULL },
    /* 13 */ { "腮红",       GCC_KIND_MK,    "Blusher_female",               NULL },
    /* 14 */ { "立体",       GCC_KIND_WARP,  "Internal_Deform_Zoom_Cheekbone","face_cheekbonezoom" },
    /* 15 */ { "白牙",       GCC_KIND_MK,    "Teeth_ALL",                    NULL },
    /* 16 */ { "黑眼圈",     GCC_KIND_JS,    "dark",                         "dark" },
    /* 17 */ { "法令纹",     GCC_KIND_JS,    "smile",                        "smile" },
    /* 18 */ { "嘴形",       GCC_KIND_WARP,  "Mouth_ALL",                    "lips_zoom" },
    /* 19 */ { "嘴巴位置",   GCC_KIND_WARP,  "fd_mouse_position_v6",         "lips_move" },
    /* 20 */ { "嘴巴宽度",   GCC_KIND_WARP,  "fd_mouse_width_v6",            NULL },
    /* 21 */ { "丰上唇",     GCC_KIND_WARP,  "fd_upper_lip_v6",              "lips_enhance" },
    /* 22 */ { "额头",       GCC_KIND_WARP,  "Internal_Deform_Forehead",     "face_forehad" },
    /* 23 */ { "窄脸",       GCC_KIND_WARP,  "Internal_Deform_CutFace",      "face_zoom" },
    /* 24 */ { "瘦颧骨",     GCC_KIND_WARP,  "Internal_Deform_Zoom_Cheekbone","face_cheekbonezoom" },
    /* 25 */ { "下颚",       GCC_KIND_WARP,  "fd_underjaw_v6",               "face_chinmove" },
    /* 26 */ { "瘦鼻",       GCC_KIND_WARP,  "Internal_Deform_Nose",         "nose_zoom" },
    /* 27 */ { "鼻翼",       GCC_KIND_WARP,  "fd_nose_wing_v6",              NULL },
    /* 28 */ { "鼻梁",       GCC_KIND_WARP,  "fd_nose_bridge_v6",            NULL },
    /* 29 */ { "亮眼",       GCC_KIND_JS,    "eye",                          "eye" },
    /* 30 */ { "眼距",       GCC_KIND_SHAPE, "eye_far",                      "eye_far" },
    /* 31 */ { "眼角",       GCC_KIND_WARP,  "fd_outer_corner_v6",           "eye_rotate" },
    /* 32 */ { "眼位",       GCC_KIND_SHAPE, "eye_move",                     "eye_move" },
    /* 33 */ { "鼻位",       GCC_KIND_WARP,  "fd_nose_tip_v6",               "nose_move" },
    /* 34 */ { "眼尾上扬",   GCC_KIND_WARP,  "fd_outer_corner_v6",           "eye_eyecorner" },
    /* 35 */ { "眉挑",       GCC_KIND_SHAPE, "eye_eyebrowjump",              "eye_eyebrowjump" },
    /* 36 */ { "尖下巴",     GCC_KIND_WARP,  "fd_jaw_v6",                    "face_chinpointy" },
    /* 37 */ { "口红·冻伤",  GCC_KIND_MK,    "Lips_Female_ds",               NULL },
    /* 38 */ { "口红·复古",  GCC_KIND_MK,    "Lips_Female_fg",               NULL },
    /* 39 */ { "口红·西柚",  GCC_KIND_MK,    "Lips_Female_xy",               NULL },
    /* 40 */ { "口红·元气",  GCC_KIND_MK,    "Lips_Female_yq",               NULL },
    /* 41 */ { "腮红·冻伤",  GCC_KIND_MK,    "Blusher_Female_ds",            NULL },
    /* 42 */ { "腮红·薔薇",  GCC_KIND_MK,    "Blusher_Female_qw",            NULL },
    /* 43 */ { "腮红·甜橙",  GCC_KIND_MK,    "Blusher_Female_tc",            NULL },
    /* 44 */ { "腮红·棕调",  GCC_KIND_MK,    "Blusher_Female_zx",            NULL },
    /* 45 */ { "眼妆·男",    GCC_KIND_MK,    "Eye_Male_01",                  NULL },
    /* 46 */ { "底妆",       GCC_KIND_MK,    "Facial_ALL",                   NULL },
    /* 47 */ { "精灵",       GCC_KIND_MK,    "Facial_ALL_jl",                NULL },
    /* 48 */ { "水光",       GCC_KIND_MK,    "Facial_ALL_sg",                NULL },
    /* 49 */ { "氤氲",       GCC_KIND_MK,    "Facial_ALL_yj",                NULL },
    /* 50 */ { "V脸",        GCC_KIND_MK,    "Facial_ALL_vl",                NULL },
};

#define GCC_SLOT_COUNT ((int)(sizeof(GCC_SLOTS) / sizeof(GCC_SLOTS[0])))

// 引擎侧形变通道的 24 个 tag（composer 节点下真实存在的）
// 用于启动自检：把滑条表的 tag 与这张表比对，缺的能立刻发现
static const char *const GCC_ENGINE_WARP_TAGS[] = {
    "Face_ALL", "Face_ALL_boy", "Face_ALL_girl",
    "Internal_Deform_Face", "Internal_Deform_CutFace",
    "Internal_Deform_Zoom_Cheekbone", "Internal_Deform_Forehead",
    "Eye_ALL", "Internal_Deform_Nose", "Mouth_ALL",
    "fd_mouse_position_v5", "fd_mouse_position_v6",
    "fd_lower_eyelid_v6", "fd_mouse_corner_v6", "fd_mouse_width_v6",
    "fd_nose_bridge_v6", "fd_pupil_v6", "fd_underjaw_v6",
    "fd_upper_lip_v6", "fd_nose_wing_v6", "smaller_head",
    "fd_nose_tip_v6", "fd_outer_corner_v6", "fd_jaw_v6",
};

#define GCC_ENGINE_WARP_COUNT \
    ((int)(sizeof(GCC_ENGINE_WARP_TAGS) / sizeof(GCC_ENGINE_WARP_TAGS[0])))

#ifdef __cplusplus
extern "C" {
#endif

// 启动自检：返回滑条表里 WARP tag 找不到对应引擎 tag 的个数（0 = 全部对得上）
int   gcc_slots_selfcheck(void);
int   gcc_slots_init(void);
int   gcc_slots_ready(void);

// 主入口：按滑条 index（0..50）和归一化值 [0,1] 写引擎
int   gcc_slot_set(int index, float v);
int   gcc_slot_set_all(float v);

// 读回验证
int   gcc_slot_dump(void);
float gcc_slot_get(const char *tag);        /* 从引擎读（无引擎返回 -996/-999） */

/* 以下三个读【本地缓存】，UI → 渲染参数必须用这些 */
float gcc_slot_get_at(int index);
float gcc_slot_get_local(const char *tag);
int   gcc_slot_index_of(const char *tag);
void  gcc_slot_record(int index, float v);

#ifdef __cplusplus
}
#endif

#endif // GCC_EFFECT_SLOTS_H
