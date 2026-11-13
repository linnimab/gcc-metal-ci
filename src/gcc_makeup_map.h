// gcc_makeup_map.h — 妆容贴图映射（模板坐标 → 贴图 UV）
//
// ============ 逆向结论（EffectSDK .material 反序列化实证）============
// .material 文件是 %SerializedFormat% 格式，明文含两类矩阵：
//   uMVPMatrix  4x4 单位矩阵（渲染用，与妆容无关）
//   uSTMatrix   4x4 采样矩阵（★ 关键：模板坐标 → 贴图 UV）
//
// 实测 uSTMatrix（行主序 16 个 float）：
//   lips_keypoint2999 (贴图 230x115):
//     [ 0.004348, 0, 0, 0 ]
//     [ 0,        0, 0, 0 ]
//     [ 0.008686, 0, 0, 0 ]
//     [ 1,        0, -0.418, -1.369 ]
//     验证：1/0.004348 = 229.9 ≈ 230 (贴图宽)
//           1/0.008686 = 115.1 ≈ 115 (贴图高)  ★ 完全吻合
//
//   mask2996 (贴图 289x135):
//     [ 0.001773, 0, 0, 0 ]
//     [ 0.003800, 0, 0, 0 ]
//     验证：1/0.001773 = 564.0
//           1/0.003800 = 263.2
//           → 说明它覆盖的是模板空间 564x263 的区域
//
// ============ 用法 ============
//   uv.x = (X - offsetX) * scaleX
//   uv.y = (Y - offsetY) * scaleY
//   其中 scaleX/scaleY 取自 uSTMatrix 的非零元，
//   offset 由矩阵第四行给出（实测为负值，即平移量）。
//
// 这意味着：**做妆容不需要解析妆容网格的二进制格式**，
// 只需要：
//   1. Face145 的 (X,Y) 模板坐标（已验证可解析）
//   2. 每个妆容件的 uSTMatrix（明文在 .material）
//   3. 妆容 PNG 贴图
// 三者相除相乘即可得到贴图采样 UV。

#ifndef GCC_MAKEUP_MAP_H
#define GCC_MAKEUP_MAP_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// 单个妆容件的映射参数
typedef struct {
    char   name[32];     // 如 "lips_keypoint2999"
    float  scaleX, scaleY;   // 取自 uSTMatrix
    float  offsetX, offsetY; // 平移量
    int    texW, texH;       // 贴图像素尺寸
} GccMakeupMap;

// 从 .material 文件解析出 uSTMatrix 并填充 GccMakeupMap。
// texW/texH 由调用方从 PNG 头读出后传入。
// 成功返回 0。
int gcc_makeup_load_material(const char *material_path,
                             int texW, int texH,
                             GccMakeupMap *out);

// 把模板坐标 (X,Y) 映射到贴图 UV [0,1]
static inline void gcc_makeup_uv(const GccMakeupMap *m, float X, float Y,
                                 float *u, float *v) {
    float su = (X - m->offsetX) * m->scaleX;
    float sv = (Y - m->offsetY) * m->scaleY;
    *u = su < 0.0f ? 0.0f : (su > 1.0f ? 1.0f : su);
    *v = sv < 0.0f ? 0.0f : (sv > 1.0f ? 1.0f : sv);
}


// ============================ 色号 → 贴图 映射表 ============================
//
// 来源：DyMakeup/FaceMakeupV2_2999/lua/makeup.lua
//       Unify_lips / Unify_brusher / Unify_facial / Unify_eyepart 索引分支。
//
// 官方逻辑（行 678~784）：
//   tag == "Lips_Female_ds"  -> Unify_lips = 1
//   tag == "Lips_Female_fg"  -> Unify_lips = 2
//   tag == "Lips_Female_xy"  -> Unify_lips = 3
//   tag == "Lips_Female_yq"  -> Unify_lips = 4
//   tag == "Blusher_Female_ds" -> Unify_brusher = 1
//   ... 等
//
// 然后（行 418~570）按索引选 mask 实体：
//   Unify_brusher 0 -> mask2996,  1 -> mask2984,  2 -> mask2983
//                  3 -> mask2982, 4 -> mask2981
//   Unify_facial  0 -> mask2989,  1 -> mask2990,  2 -> mask2991
//                  3 -> mask2992, 4 -> mask2995
//   Unify_lips    0..4 共用 lipsKeyPoint_mask2999（靠 lookup 贴图区分色号）
//   Unify_eyepart 0 -> eyepart2979 / eyepart2980

typedef enum {
    GCC_MK_LIPS = 0,
    GCC_MK_BLUSH,
    GCC_MK_EYE,
    GCC_MK_FACIAL,
    GCC_MK_TEETH,
    GCC_MK_KIND_COUNT
} GccMakeupKind;

// 一个色号条目
typedef struct {
    const char *tag;        // effect_slots.h 里的 tag，如 "Lips_Female_ds"
    int         kind;       // GccMakeupKind
    int         unifyIdx;   // Unify_* 索引（0~4）
    const char *maskDir;    // image 下的子目录名（mask 贴图）
    const char *lookupDir;  // image 下的子目录名（lookup 贴图），NULL 表示用 mask 自身
} GccMakeupPreset;

// 17 个色号（口红5 + 腮红5 + 眼妆2 + 底妆5）
static const GccMakeupPreset GCC_MAKEUP_PRESETS[] = {
    // ---- 口红：共用 mask2999，色号差异在 lookup 贴图 ----
    { "Lips_female",         GCC_MK_LIPS, 0, "lipsKeyPoint_mask2999", "lipsKeyPoint_lookup2999" },
    { "Lips_Female_ds",      GCC_MK_LIPS, 1, "lipsKeyPoint_mask2999", "lipsKeyPoint_lookup2999" },
    { "Lips_Female_fg",      GCC_MK_LIPS, 2, "lipsKeyPoint_mask2999", "lipsKeyPoint_lookup2999" },
    { "Lips_Female_xy",      GCC_MK_LIPS, 3, "lipsKeyPoint_mask2999", "lipsKeyPoint_lookup2999" },
    { "Lips_Female_yq",      GCC_MK_LIPS, 4, "lipsKeyPoint_mask2999", "lipsKeyPoint_lookup2999" },

    // ---- 腮红：每个色号有独立 mask ----
    { "Blusher_female",      GCC_MK_BLUSH, 0, "mask2996", NULL },
    { "Blusher_Female_ds",   GCC_MK_BLUSH, 1, "mask2984", NULL },
    { "Blusher_Female_qw",   GCC_MK_BLUSH, 2, "mask2983", NULL },
    { "Blusher_Female_tc",   GCC_MK_BLUSH, 3, "mask2982", NULL },
    { "Blusher_Female_zx",   GCC_MK_BLUSH, 4, "mask2981", NULL },

    // ---- 眼妆 ----
    { "Eye_Female_01",       GCC_MK_EYE,   0, "eyepart2979", NULL },
    { "Eye_Male_01",         GCC_MK_EYE,   0, "eyepart2980", NULL },

    // ---- 底妆 / 整装预设 ----
    { "Facial_ALL",          GCC_MK_FACIAL, 0, "mask2989", NULL },
    { "Facial_ALL_jl",       GCC_MK_FACIAL, 1, "mask2990", NULL },
    { "Facial_ALL_sg",       GCC_MK_FACIAL, 2, "mask2991", NULL },
    { "Facial_ALL_yj",       GCC_MK_FACIAL, 3, "mask2992", NULL },
    { "Facial_ALL_vl",       GCC_MK_FACIAL, 4, "mask2995", NULL },

    // ---- 牙齿 ----
    { "Teeth_ALL",           GCC_MK_TEETH,  0, "teeth_mask2997", "teeth_lookup2997" },
};

#define GCC_MAKEUP_PRESET_COUNT \
    ((int)(sizeof(GCC_MAKEUP_PRESETS) / sizeof(GCC_MAKEUP_PRESETS[0])))

// 按 tag 查预设；返回 NULL 表示没有这个色号
static inline const GccMakeupPreset *gcc_makeup_find(const char *tag) {
    if (!tag) return 0;
    for (int i = 0; i < GCC_MAKEUP_PRESET_COUNT; i++) {
        const char *a = GCC_MAKEUP_PRESETS[i].tag;
        const char *b = tag;
        while (*a && *a == *b) { a++; b++; }
        if (*a == 0 && *b == 0) return &GCC_MAKEUP_PRESETS[i];
    }
    return 0;
}

// 按 kind + unifyIdx 查预设
static inline const GccMakeupPreset *gcc_makeup_at(int kind, int unifyIdx) {
    for (int i = 0; i < GCC_MAKEUP_PRESET_COUNT; i++) {
        if (GCC_MAKEUP_PRESETS[i].kind == kind &&
            GCC_MAKEUP_PRESETS[i].unifyIdx == unifyIdx) {
            return &GCC_MAKEUP_PRESETS[i];
        }
    }
    return 0;
}

#ifdef __cplusplus
}
#endif

#endif /* GCC_MAKEUP_MAP_H */
