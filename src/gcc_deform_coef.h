#ifndef GCC_DEFORM_COEF_H
#define GCC_DEFORM_COEF_H

/*
 * gcc_deform_coef.h — 抖音官方形变强度系数表
 *
 * 来源（逐字提取，非推断）：
 *   analysis/effect_backup_before_Arestore/bcce4ab.../DyShape/AmazingFeature/
 *     lua/FaceWarpXControl.lua  → onEvent() 里 66 条 setIntensity()
 *
 * 数据链路（官方）：
 *   composer tag (value, 范围 -1..1，0=中性)
 *     → onEvent 按 tag 乘以下系数
 *     → intensityMap[36 键]
 *     → onUpdate 把每个键分流到 boundaryWarpInfos / organWarpInfos
 *     → FaceWarpXRenererSystem 用 warpXModel 的 36 组位移场做顶点变换
 *
 * 我们这条链路：
 *   gcc_slot_get_local(tag) 得到 0..1（0.5 中性）
 *     → (v - 0.5) 得 -0.5..0.5
 *     → gcc_deform_coef(tag) 乘官方系数
 *     → MeshWarpParams.xxxK（-1..1 量级，与官方 value 一致）
 *     → MSL gcc_mesh_vertex 做径向位移
 *
 * ★ 量纲说明（重要，别踩）：
 *   官方系数是「composer 强度倍数」，不是「位移量」。中间还隔着
 *   warpXModel 的 36 组真实位移场（473045 B），那部分尚未解析。
 *   所以本表解决的是「滑条 → 引擎强度」这一层的保真，
 *   「强度 → 实际位移曲线」仍需 warpXModel（见下方 GCC_DEFORM_NOTE）。
 *
 * ★ 正负分通道（官方行为）：
 *   多数 fd_*_v6 在 value>0 走 _positive、value<0 走 _negative，
 *   两个通道互斥且各自独立乘系数（本项目两个方向系数相同）。
 *   少数单向键（fd_underjaw_v6 / fd_mouse_corner_v6）只有 positive。
 */

#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    const char *tag;        /* composer tag / 槽位 tag */
    float       coef;       /* 官方 onEvent 乘数 */
    int         bidirectional; /* 1 = 正负分通道；0 = 单向 */
    const char *warp_key;   /* 对应 warpXModel 的键（正通道） */
} GccDeformCoef;

/* 23 个 tag，逐条抄自 FaceWarpXControl.lua onEvent */
static const GccDeformCoef GCC_DEFORM_COEFS[] = {
    /* tag                                  coef  双向  warpXModel 键 */
    { "Face_ALL",                          1.00f, 0, "Face_ALL_video" },
    { "smaller_head",                      1.00f, 0, "xiaotou_boundary" },
    { "Eye_ALL",                           1.32f, 0, "Eye_ALL_video" },
    { "Internal_Deform_Face",              1.00f, 0, "Internal_Deform_Face_video" },
    { "Internal_Deform_CutFace",           1.00f, 0, "Internal_Deform_CutFace_video" },
    { "Internal_Deform_Zoom_Cheekbone",    1.00f, 0, "Internal_Deform_Zoom_Cheekbone_video" },
    { "Internal_Deform_Forehead",          1.50f, 1, "Internal_Deform_Forehead_video_positive" },
    { "Internal_Deform_Nose",              1.00f, 0, "Internal_Deform_Nose_video" },
    { "Mouth_ALL",                         1.10f, 1, "Mouth_ALL_video_positive" },

    /* fd_*_v6 系列：官方一律 ×2.0 */
    { "fd_pupil_v6",                       2.00f, 1, "fd_pupil_v6_positive" },
    { "fd_lower_eyelid_v6",                2.00f, 1, "fd_lower_eyelid_v6_positive" },
    { "fd_mouse_position_v6",              2.00f, 1, "fd_mouse_position_v5_positive" },
    { "fd_mouse_width_v6",                 2.00f, 1, "fd_mouse_width_v6_positive" },
    { "fd_upper_lip_v6",                   2.00f, 1, "fd_upper_lip_v6_positive" },
    { "fd_nose_wing_v6",                   2.00f, 1, "fd_nose_wing_v6_positive" },
    { "fd_nose_bridge_v6",                 2.00f, 1, "fd_nose_bridge_v6_positive" },
    { "fd_mouse_corner_v6",                2.00f, 0, "fd_mouse_corner_v6" },
    { "fd_underjaw_v6",                    1.00f, 0, "fd_underjaw_v6_positive" },
    { "fd_nose_tip_v6",                    1.00f, 1, "fd_nose_tip_v6_positive" },
    { "fd_jaw_v6",                         1.00f, 1, "fd_jaw_v6_positive" },
    { "fd_outer_corner_v6",                1.00f, 1, "fd_outer_corner_v6_positive" },
};

#define GCC_DEFORM_COEF_COUNT ((int)(sizeof(GCC_DEFORM_COEFS)/sizeof(GCC_DEFORM_COEFS[0])))

/* 按 tag 查官方系数；查不到返回 1.0（不放大也不缩小） */
static inline float gcc_deform_coef(const char *tag) {
    if (!tag) return 1.0f;
    for (int i = 0; i < GCC_DEFORM_COEF_COUNT; i++) {
        const char *a = GCC_DEFORM_COEFS[i].tag, *b = tag;
        while (*a && *a == *b) { a++; b++; }
        if (*a == 0 && *b == 0) return GCC_DEFORM_COEFS[i].coef;
    }
    return 1.0f;
}

/*
 * 把 UI 滑条值（0..1，0.5 中性）按官方口径转成 warp 强度（-1..1，0 中性）。
 *
 *   raw = (v - 0.5) * 2           → -1..1（gcc_slot_set 的 WARP 换算一致）
 *   out = raw * coef              → 官方 onEvent 的乘数
 *
 * 注意：官方 warpXRenderer 拿到的是这个「放大后」的强度，
 *       所以 ×2.0 不是我们额外加戏，是官方原本就有的。
 */
static inline float gcc_deform_intensity(float slider01, const char *tag) {
    float raw = (slider01 - 0.5f) * 2.0f;
    return raw * gcc_deform_coef(tag);
}

/* ------------------------------------------------------------------ *
 * 尚未解析的部分（诚实记录，勿当成已解决）
 *
 * DyShape/AmazingFeature/warpX/modelInfo.warpXModel  473045 B
 *   - +6976  : 36 个 [u32 len][name] 键名表，结束 +7985
 *   - +8001  : u32 36（键数量）
 *   - +8153  : 顶点/三角形索引表（u32 序列 7415, 11818, ...）
 *   - +75960 起: 分段 float 位移场（|v|<2），夹杂其它结构
 *   - 文件尾部 32KB 全为 0.0 的 float
 *   - xshader/single_person.metal.vert 是直通顶点（不做位移），
 *     位移由 FaceWarpXRenererSystem 在 CPU 侧算好后写入顶点缓冲。
 *
 * 要 100% 复刻形变曲线，需要：
 *   1) 完整解析 36 组位移场（每组 N 顶点 × 2/3 分量）
 *   2) 与 FACE145 / 106 点拓扑对齐
 *   3) 在 vertex shader 里按 intensity 线性混合 36 组偏移
 * 这是下一步工作，本表只负责「滑条 → 强度」这一层。
 * ------------------------------------------------------------------ */

#ifdef __cplusplus
}
#endif

#endif /* GCC_DEFORM_COEF_H */
