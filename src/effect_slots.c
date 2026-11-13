// effect_slots.c - 把安卓侧逆向出来的滑条表落到 iOS 的 composer 直连上
//
// 这是 iOS 侧相对安卓最大的结构性优势：
// 安卓为了让这 24 个形变 tag 进引擎，走的是
//     Java biPush -> pendingWarps -> drainBeautyMailbox -> jsQueue
//     -> __gccEmit -> apjs.EventManager.sendEventAllScene
//     -> Lua onEvent(BET_COMPOSER=1300) -> loadBoundaryWarpInfo
//     -> FaceWarpXRenderer component
// 中间踩了寄存器上限 / JS 脚本长度上限(SIGSEGV) / 队列容量 / 启动竞态。
//
// iOS 上只需要：
//     bef_effect_composer_update_node(handle, EFFECT_ID, tag, value)
// 一步到位，且值可以直接从 get_node_value 读回验证。

#include "effect_slots.h"
#include "effect_sdk.h"
#include "effect_bridge.h"

#include <stdio.h>
#include <string.h>

// 安卓侧硬编码的那一个 composer 节点路径（config.json 里 effect.Link[0]）
// 来自 assets/effect/bcce4ab7a2200676ca1295fe821704ed/config.json
#define GCC_EFFECT_ID "bcce4ab7a2200676ca1295fe821704ed"

static int g_initialized = 0;
static int g_ok_count   = 0;
static int g_fail_count = 0;

// ---------------------------------------------------------------------------
// 启动自检：滑条表的 tag 必须都能在引擎的真实 tag 列表里找到
// ---------------------------------------------------------------------------
static int is_engine_warp_tag(const char *t) {
    if (!t) return 0;
    for (int i = 0; i < GCC_ENGINE_WARP_COUNT; i++) {
        if (strcmp(t, GCC_ENGINE_WARP_TAGS[i]) == 0) return 1;
    }
    return 0;
}

int gcc_slots_selfcheck(void) {
    int warp = 0, mk = 0, other = 0, missing = 0;
    for (int i = 0; i < GCC_SLOT_COUNT; i++) {
        const GccSlot *s = &GCC_SLOTS[i];
        if (s->kind == GCC_KIND_WARP) {
            warp++;
            if (!is_engine_warp_tag(s->tag)) {
                missing++;
                fprintf(stderr, "[slots] WARN idx=%d %s tag=%s NOT in engine list\n",
                        i, s->label, s->tag);
            }
        } else if (s->kind == GCC_KIND_MK) {
            mk++;
        } else {
            other++;
        }
    }
    fprintf(stderr,
            "[slots] selfcheck total=%d warp=%d mk=%d other=%d warp_tag_missing=%d\n",
            GCC_SLOT_COUNT, warp, mk, other, missing);
    return missing;
}

// ---------------------------------------------------------------------------
// 唯一入口：按滑条 index 和归一化值 [0,1] 写引擎
//
// 值与安卓完全一致：
//   WARP —— 安卓 pendingWarps.put(tag, (v-0.5)*2)  =>  (v-0.5)*2 范围 [-1,1]
//   MK   —— 安卓 pendingWarps.put(tag, v)          =>  v 范围 [0,1]
//
// 返回 0 成功。不返回 -1 之外的负数错误码。
// ---------------------------------------------------------------------------
int gcc_slot_set(int index, float v) {
    if (index < 0 || index >= GCC_SLOT_COUNT) return -1;
    const GccSlot *s = &GCC_SLOTS[index];

    if (v < 0.0f) v = 0.0f;
    if (v > 1.0f) v = 1.0f;
    gcc_slot_record(index, v);

    BefEffectHandle h = bef_handle();
    if (!h) return -1;

    switch (s->kind) {
    case GCC_KIND_NONE:
        return 0;

    case GCC_KIND_WARP: {
        float w = (v - 0.5f) * 2.0f;
        int rc = bef_effect_composer_update_node(h, GCC_EFFECT_ID, s->tag, w);
        if (rc == 0) g_ok_count++; else g_fail_count++;
        return rc;
    }

    case GCC_KIND_MK: {
        int rc = bef_effect_composer_update_node(h, GCC_EFFECT_ID, s->tag, v);
        if (rc == 0) g_ok_count++; else g_fail_count++;
        return rc;
    }

    // ========================================================================
    // 2026-11-10 P0 修复：kind 0/1/2 原先调用的 bef_effect_set_beauty /
    // bef_effect_set_reshape_face 在 iOS EffectSDKFramework 里是 0xa8 字节的
    // 「mov w0,#-3」桩（effect_sdk.h、docs/119 §1.2）。它们恒返回 -3、什么都不写；
    // 上层 gcc_slot_set 直接把 -3 返回，滑条看着「已生效」实则无效。
    //
    // iOS 侧真正有实现（真体反汇编）的是：
    //   bef_effect_update_beauty @0x1c9b8  (handle, smooth, brighten)  -1=不改该分量
    //   bef_effect_set_intensity @0x1c59c
    // 以及本文件头注释写明的「iOS 全走 composer_update_node 一步到位」。
    //
    // 修法：能映射到 update_beauty 两个分量的走真体，其余一律写 composer 节点
    // （配合 bef_init 第 7 步补的 bef_effect_set_composer，节点表现在是真实的）。
    // 所有分支都计入 g_ok_count/g_fail_count，让 gcc_slot_dump 反映真实成功率，
    // 不再出现「rc=0 假成功」。
    // ========================================================================
    case GCC_KIND_JS: {
        // 磨皮(skin)→smooth 分量；其余（黑眼圈/法令纹/亮眼）无对应分量，走 composer。
        int rc;
        if (strcmp(s->tag, "skin") == 0) {
            rc = bef_effect_update_beauty(h, v, -1.0f);
        } else {
            rc = bef_effect_composer_update_node(h, GCC_EFFECT_ID, s->tag, v);
        }
        if (rc == 0) g_ok_count++; else g_fail_count++;
        return rc;
    }

    case GCC_KIND_GLU: {
        // sharpen/whiten 在安卓是自写 GLSL uniform；iOS 没有 rgbProgram，
        // 用 update_beauty 真体近似：whiten→brighten，sharpen→smooth 分量。
        // （sharpen 无独立分量，属近似映射，待真机 A/B。）
        int rc = (strcmp(s->tag, "sharpen") == 0)
               ? bef_effect_update_beauty(h, v, -1.0f)
               : bef_effect_update_beauty(h, -1.0f, v);
        if (rc == 0) g_ok_count++; else g_fail_count++;
        return rc;
    }

    case GCC_KIND_SHAPE: {
        // 弃用恒 -3 的 set_reshape_face，改走 composer（眼距/眼位/眉挑）。
        // 形变值语义与 WARP 一致：(v-0.5)*2，范围 [-1,1]。
        int rc = bef_effect_composer_update_node(h, GCC_EFFECT_ID, s->tag,
                                                  (v - 0.5f) * 2.0f);
        if (rc == 0) g_ok_count++; else g_fail_count++;
        return rc;
    }

    default:
        return -1;
    }
}

// ---------------------------------------------------------------------------
// 一次性把整张表写一遍（验收用：不用拖 51 根滑条）
// ---------------------------------------------------------------------------
int gcc_slot_set_all(float v) {
    int bad = 0;
    for (int i = 0; i < GCC_SLOT_COUNT; i++) {
        if (gcc_slot_set(i, v) != 0) bad++;
    }
    fprintf(stderr, "[slots] set_all v=%.3f bad=%d\n", v, bad);
    return bad;
}

// ---------------------------------------------------------------------------
// 读回验证：dump 节点当前值，确认写进去了
// ---------------------------------------------------------------------------
int gcc_slot_dump(void) {
    BefEffectHandle h = bef_handle();
    if (!h) return -1;
    char buf[4096];
    memset(buf, 0, sizeof(buf));
    int rc = bef_effect_composer_dump_nodes(h, buf, (int)sizeof(buf));
    fprintf(stderr, "[slots] dump rc=%d ok=%d fail=%d\n%s\n",
            rc, g_ok_count, g_fail_count, buf);
    return rc;
}

// 只读单个 tag 的当前值（写后立刻验证，比 dump 全量轻）
float gcc_slot_get(const char *tag) {
    BefEffectHandle h = bef_handle();
    if (!h || !tag) return -999.0f;
    float out = -997.0f;
    int rc = bef_effect_composer_get_node_value(h, tag, &out);
    if (rc != 0) { fprintf(stderr, "[slots] get %s rc=%d\n", tag, rc); return -996.0f; }
    return out;
}
/* ------------------------------------------------------------------ *
 * 本地值缓存
 *
 * gcc_slot_get(tag) 走的是 bef_effect_composer_get_node_value ——
 * 那是从【引擎】读，没有引擎时返回 -996/-999，读不到 UI 滑条的本地状态。
 *
 * UI → 渲染参数必须走本地缓存，否则形变/妆容参数全是无效值。
 * ------------------------------------------------------------------ */
static float g_value[GCC_SLOT_COUNT];
static int   g_value_inited = 0;

static void g_value_ensure_init(void) {
    if (g_value_inited) return;
    for (int i = 0; i < GCC_SLOT_COUNT; i++) {
        /* 形变类中性 0.5，其它 0 —— 与安卓 BI_NEUT 一致 */
        g_value[i] = (GCC_SLOTS[i].kind == GCC_KIND_WARP) ? 0.5f : 0.0f;
    }
    g_value_inited = 1;
}

/* 按槽位下标读本地值（不动引擎，纯内存） */
float gcc_slot_get_at(int index) {
    g_value_ensure_init();
    if (index < 0 || index >= GCC_SLOT_COUNT) return 0.0f;
    return g_value[index];
}

/* 记录本地值（由 gcc_slot_set 内部调用） */
void gcc_slot_record(int index, float v) {
    g_value_ensure_init();
    if (index < 0 || index >= GCC_SLOT_COUNT) return;
    g_value[index] = v;
}

/* 按标签找下标；返回 -1 表示没这个 tag */
int gcc_slot_index_of(const char *tag) {
    if (!tag) return -1;
    for (int i = 0; i < GCC_SLOT_COUNT; i++) {
        const char *a = GCC_SLOTS[i].tag, *b = tag;
        if (!a) continue;
        while (*a && *a == *b) { a++; b++; }
        if (*a == 0 && *b == 0) return i;
    }
    return -1;
}

/* 按标签读本地值（UI 侧用这个，不用 gcc_slot_get） */
float gcc_slot_get_local(const char *tag) {
    int idx = gcc_slot_index_of(tag);
    if (idx < 0) return 0.0f;
    return gcc_slot_get_at(idx);
}



int gcc_slots_init(void) {
    g_initialized = 1;
    int missing = gcc_slots_selfcheck();

    // ========================================================================
    // 2026-11-10：把「常量表自检」升级成「引擎真实节点自检」。
    // 旧注释自己就说了：slotmiss=0 只证明与编译期常量表自洽，不证明引擎认这些 tag。
    // bef_effect_composer_get_node_paths 是 iOS 导出真实现（@0x3b94c，504 B，非桩）。
    // 注意：调用时机在 bef_init 之后（composer 已装载），此时读到的才是真实节点表。
    // ========================================================================
    BefEffectHandle h = bef_handle();
    if (h) {
        static char paths[8192];
        memset(paths, 0, sizeof(paths));
        int rc = bef_effect_composer_get_node_paths(h, paths, (int)sizeof(paths));
        if (rc == 0 && paths[0]) {
            fprintf(stderr, "[slots] engine node paths: %s\n", paths);
            int hit = 0, tot = 0;
            for (int i = 0; i < GCC_SLOT_COUNT; i++) {
                const GccSlot *s = &GCC_SLOTS[i];
                if (s->kind != GCC_KIND_WARP || !s->tag) continue;
                tot++;
                if (strstr(paths, s->tag)) hit++;
            }
            fprintf(stderr, "[slots] engine-hit %d/%d warp tags present\n", hit, tot);
        } else {
            fprintf(stderr, "[slots] get_node_paths rc=%d (engine table empty?)\n", rc);
        }
    }
    return missing;
}

int gcc_slots_ready(void) { return g_initialized; }
