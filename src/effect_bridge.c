// effect_bridge.c - ????? iOS ????
//
// ?????????:?????? Android ????????,?? Java ????
// effect_sdk.h ?? C ?????????????????,??? Android ???????
//
// Android ??????(Redmi K30 Pro / MuMu,? docs/92 ? analysis/runtime ??):
//   nativeCreateHandle(false)                  -> 1          (? 0 ???,license ????)
//   nativeSetCameraPosition(true)              -> OK
//   nativeSetOrientation(0)                    -> OK
//   nativeInitResourceFinder(finder,720,1280,home) -> 0    (? 0,0,"" ?????? -6)
//   nativeSetStickerPath(<? config.json ????>) -> 0  (?????? SEGV)
//   nativeSendMessage(h,1,1,0,"")              -> 0
//   setBeautify / setReshape / setFilter / composerSetNodes -> ?? 0

#include "effect_sdk.h"
#include "resource_finder.h"
#include "effect_bridge.h"
#include "js_runtime.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>
#include <unistd.h>          // chdir —— 引擎按 cwd 解析相对资源路径

static BefEffectHandle g_handle = 0;
static char g_root[512] = {0};

/* effect 叶目录名 = composer 节点路径（assets/effect/<hash>/config.json 所在目录）。
   Android CameraActivity.java:4073 实测：此值 get_node_paths 原样回读、零报错；
   传 "DySmooth/AmazingFeature/" 之类反而报 config.json 不存在。
   与 effect_slots.c 的 GCC_EFFECT_ID 保持字面一致。 */
#define GCC_EFFECT_ID_B "bcce4ab7a2200676ca1295fe821704ed"

// ★ 启动自检状态（供状态栏 bef_algo_report 读取）
static int  g_gpu_rc = -999, g_algo_ok = -1, g_builtin_rc = -999, g_composer_rc = -999;
static char g_algo_report[256] = "algo=not-init";

// ---------------------------------------------------------------------------
// ???????
// ---------------------------------------------------------------------------
void bef_rf_set_root(const char *root) {
    if (!root) { g_root[0] = 0; return; }
    strncpy(g_root, root, sizeof(g_root) - 1);
    g_root[sizeof(g_root) - 1] = 0;
}

char *bef_rf_find_resource(const char *name) {
    if (!name || !g_root[0]) { return NULL; }
    size_t n = strlen(g_root) + strlen(name) + 2;
    char *full = (char *)malloc(n);
    if (!full) { return NULL; }
    snprintf(full, n, "%s/%s", g_root, name);
    return full;
}

void bef_rf_release_resource(char *path) {
    free(path);
}

// ---------------------------------------------------------------------------
// ???:?? Android ? 7 ?
// ---------------------------------------------------------------------------
int bef_init(const char *resource_root,
             const char *effect_leaf_dir,
             int width, int height,
             bool front_camera) {
    /* 启动壳解耦：UI 起来后再挂载特效库；失败走安全 no-op */
    gcc_engine_load();
    BefEffectHandle h = 0;
    int rc;

    bef_rf_set_root(resource_root);

    // 1. ????Android ?? false;iOS ????? false?
    rc = bef_effect_create_handle(false, &h);
    if (rc != 0 || h == 0) {
        // ??:?????? create ????
        rc = bef_effect_create(&h);
        if (rc != 0 || h == 0) {
            fprintf(stderr, "[bridge] create_handle rc=%d h=%lld\n", rc, (long long)h);
            return rc;
        }
    }
    g_handle = h;

    // 2. ????
    bef_effect_set_camera_device_position(h, front_camera);
    bef_effect_set_orientation(h, 0);

    // 3. ??????????? 0 ? Android ? -6 ??????
    if (resource_root) {
        bef_effect_set_cache_directory(h, resource_root);
    }
    bef_effect_set_width_height(h, width, height);

    // 4. ??????
    //
    // ? ????(??????? + iOS @0x1324c ?????):
    //   bef_effect_init_with_resource_finder ? 12 ?? thunk:
    //       mov x5, x4 / mov x4, #0x0 / b <v2>
    //   ? 4 ?????? v2(handle, a, b, NULL, finder),? v2 ??4??
    //     cbz ? ?? -6????? 4 ???? -6?
    //   ??? JNI ? 5 ???(nativeInitResourceFinder(handle,finder,w,h,dir)),
    //   iOS ??,????? _v2 ????? 4 ?(? NULL ? -6)?
    //
    // iOS ? finder ???:SDK ?? bef_rf_find_resource ????(?
    // resource_finder.h)???? finder ?? v2 ?? 5 ?(thunk ??? x4?x5),
    // ? 4 ????? NULL ??,??? -6 ???
    void *finder_handle = (void *)&g_handle;      // ? NULL ??,?? cbz ? -6
    void *finder        = (void *)bef_rf_find_resource;

    rc = bef_effect_init_with_resource_finder_v2(h,
                                                  (void *)(intptr_t)width,   // arg1
                                                  (void *)(intptr_t)height,  // arg2
                                                  finder_handle,             // arg3(??? NULL)
                                                  finder);                   // arg4
    if (rc != 0) {
        fprintf(stderr, "[bridge] init_with_resource_finder_v2 rc=%d,?? _v2(arg3=NULL)\n", rc);
        rc = bef_effect_init_with_resource_finder_v2(h,
                                                      (void *)(intptr_t)width,
                                                      (void *)(intptr_t)height,
                                                      NULL, finder);
    }
    if (rc != 0) {
        fprintf(stderr, "[bridge] init_v2 ???? rc=%d,??? init\n", rc);
        rc = bef_effect_init(h);
    }
    if (rc != 0) {
        fprintf(stderr, "[bridge] init rc=%d\n", rc);
        return rc;
    }

    // 5. JS 运行时必须在 set_sticker 之前建好。
    //
    //    理由：effect 包的 config.json 里 AmazingScene 会加载 main.bundle，
    //    bundle 里的 bootstrap.js / AmazingProRuntime.js 在 set_sticker 解析时就会
    //    被 JSScriptSystem 求值。引擎侧要通过 bef_effect_javascript_binding_engine
    //    拿到的 napi_env 才能跑起来；等 set_sticker 之后再建，JS 已经错过了启动点。
    //
    //    失败不 return：JS 起不来只影响依赖 JS 层的能力（美颜 4 项 / 美型 19 项 /
    //    妆效 12 项），C 接口那部分（composer 节点、滤镜、调色）仍然可用。
    {
        int jrc = js_runtime_init(resource_root, "AmazingModule");
        fprintf(stderr, "[bridge] js_runtime_init rc=%d %s %s\n",
                jrc, js_runtime_report(), js_runtime_error());
    }

    // 6. ????????? config.json ????,?????? SDK ????
    if (effect_leaf_dir) {
        rc = bef_effect_set_sticker(h, effect_leaf_dir);
        if (rc != 0) {
            fprintf(stderr, "[bridge] set_sticker rc=%d (%s)\n", rc, effect_leaf_dir);
            return rc;
        }
    }

    // ========================================================================
    // 6.5 ★ 2026-11-10：算法 / 人脸引擎装载层（此前 iOS 完全缺失）
    //   Android CameraActivity.java:3994-4213 的实证顺序：
    //     chdir(资源根) → set_sticker → load_gpu_resource → load_algorithm × 5
    //   没有这一层，face_0 不出人脸网格，妆容/形变/磨皮全部「装载了但不动」。
    //   包内 algorithmConfig.json 已声明 face_0 / FaceAlign / facefitting_3d_0 /
    //   script_0 / matting_0 / expression_detect_0 六个算法节点及各自 model_name，
    //   引擎在 set_sticker 解析 config 时自行完成「算法→模型」映射（iOS 无
    //   set_assigned_model_names 导出，也不需要）。
    //   失败不 return：让上层仍能看到画面 + 状态栏诊断。
    // ========================================================================
    if (resource_root && resource_root[0]) {
        chdir(resource_root);   // 引擎按 cwd 解析 Internal_*/config.json 相对路径
        fprintf(stderr, "[ALGO] chdir -> %s\n", resource_root);
    }
    {
        int gpu_rc = bef_effect_load_gpu_resource(h); g_gpu_rc = gpu_rc;
        fprintf(stderr, "[ALGO] load_gpu_resource -> %d\n", gpu_rc);

        static const char *algos[] = {
            "face", "nh_face_align", "facefitting_3d", "matting", "expression_detect"
        };
        int ok = 0;
        for (int i = 0; i < 5; i++) {
            int arc = bef_effect_load_algorithm(h, algos[i]);
            fprintf(stderr, "[ALGO] load_algorithm(%s) -> %d\n", algos[i], arc);
            if (arc == 0) ok++;
        }
        fprintf(stderr, "[ALGO] loaded %d/5\n", ok); g_algo_ok = ok;

        // 原生美颜总开关（docs/119）：默认关闭。本包 Internal_* 全是 713B 的
        //   EmptyFeature 空壳，打开它会以 priority 11999 抢掉
        //   FaceMakeup* / FaceDeformation* / FaceBeauty* 三个场景键。
        int nb_rc = bef_effect_use_amazing_builtin(h, false); g_builtin_rc = nb_rc;
        fprintf(stderr, "[ALGO] use_amazing_builtin(false) -> %d\n", nb_rc);
    }

    // 7. ★ 2026-11-10：初始化阶段就把 composer 素材装载好。
    //    旧代码只在用户点「美颜」开关（bef_apply_default_look）时才挂节点，
    //    但 gcc_slots_init / slotPanel pushAll 都发生在那之前 —— 开机时 51 根滑条
    //    写的是一张还没装载的空表，update_node 全 rc=0 假成功，画面却没反应。
    //    依据 Android CameraActivity.java:4087-4104，正确顺序是
    //      set_composer(装素材) → composer_set_nodes(挂节点)，
    //    两者都必须在任何 update_node 之前完成。
    {
        static const char *nodes[1] = { GCC_EFFECT_ID_B };
        int comp_rc = bef_effect_set_composer(h, nodes[0]);
        int cn_rc   = bef_effect_composer_set_nodes(h, nodes, 1); g_composer_rc = cn_rc;
        fprintf(stderr, "[bridge] init: set_composer=%d composer_set_nodes=%d\n",
                comp_rc, cn_rc);
    }

    return 0;
}

void bef_shutdown(void) {
    // JS 运行时先拆（它持有 env/ctx/rt，引擎对象还活着时拆更安全）
    js_runtime_shutdown();
    if (g_handle) {
        bef_effect_destroy(g_handle);
        g_handle = 0;
    }
}

// ---------------------------------------------------------------------------
// ????:???? Android ??? 0 ?????
// ---------------------------------------------------------------------------
int bef_apply_default_look(void) {
    if (!g_handle) { return -1; }

    // ========================================================================
    // 2026-11-10：对齐 Android 侧实证（CameraActivity.java:4065-4104）。
    // 旧代码是 {"face","freid","skin_seg","blit"} 四个编出来的短名，两个错误：
    //   1) 名字不对 —— composer 节点路径 = effect 叶目录名本身，不是短名
    //   2) 缺 bef_effect_set_composer —— 不调它，update_node 全 rc=0 却写进空表
    // 装载主体已在 bef_init 第 7 步做过；这里只在「打开美颜」时重新确认节点并设默认强度。
    // ========================================================================
    static const char *look_nodes[1] = { GCC_EFFECT_ID_B };

    int comp_rc = bef_effect_set_composer(g_handle, look_nodes[0]);
    fprintf(stderr, "[bridge] set_composer('%s') -> %d%s\n",
            look_nodes[0], comp_rc, comp_rc == 0 ? "  (素材已装载)" : "  (失败)");

    int rc = bef_effect_composer_set_nodes(g_handle, look_nodes, 1);
    fprintf(stderr, "[bridge] composer_set_nodes(1) -> %d\n", rc);
    if (rc != 0) { return rc; }

    // ? ????:bef_effect_set_beauty / bef_effect_set_reshape_face ????
    // ???? -3(0xa8 ?? stub,?? mov w0,#-3),iOS ???????
    // ?? -3 ????????????,???????????
    // ???????? bef_effect_update_beauty(handle, smooth, brighten),
    // ??? .rodata ?? + iOS/??????????
    rc = bef_effect_update_beauty(g_handle, 0.8f, 0.8f);
    if (rc != 0) {
        fprintf(stderr, "[bridge] update_beauty rc=%d\n", rc);
        // ? return:????????????/????,? rc ?????
    }

    if ((rc = bef_effect_set_color_filter_v2(g_handle, "", 0.5f)) != 0) { return rc; }
    if ((rc = bef_effect_composer_update_node(g_handle, "blit", "intensity", 0.8f)) != 0) { return rc; }

    bef_effect_send_msg(g_handle, 1, 1, 0, "");
    return rc;
}

// ? ???????????,? CameraViewController ??
// ????(.rodata):
//   "[Slota]bef_effect_update_beauty : fSmoothIntensity is %f, fBrightenIntensity is %f"
int bef_set_beauty_intensity(float smooth, float brighten) {
    if (!g_handle) { return -1; }
    return bef_effect_update_beauty(g_handle, smooth, brighten);
}

// ---------------------------------------------------------------------------
// ??
// ---------------------------------------------------------------------------
int bef_process_frame(int device_texture, int width, int height, double timestamp) {
    if (!g_handle) { return -1; }
    return bef_effect_process_texture_device_texture(g_handle, device_texture,
                                                      width, height, 0, timestamp);
}

const char *bef_version(void) {
    // SDK ??? bef_effect_get_version;? get_remark ????????,
    // ??????????(????????,?????)?
    static char buf[64] = {0};
    const char *p = NULL;
    if (g_handle && bef_effect_get_remark(g_handle, &p) == 0 && p) {
        strncpy(buf, p, sizeof(buf) - 1);
        return buf;
    }
    return "effect-sdk";
}

// ★ 2026-11-10：把「算法/人脸引擎 + JS 运行时」的启动结果合成一行，
//   CameraViewController 的状态栏直接显示，真机第一眼即可定位卡在哪一环。
const char *bef_algo_report(void) {
    snprintf(g_algo_report, sizeof(g_algo_report),
             "eng[%s] gpu=%d algo=%d/5 builtin=%d composer=%d | js[%s]",
              gcc_engine_report(), g_gpu_rc, g_algo_ok, g_builtin_rc, g_composer_rc,
             js_runtime_report());
    return g_algo_report;
}
BefEffectHandle bef_handle(void) {
    return g_handle;
}
