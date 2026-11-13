// test_mesh.c — gcc_face_mesh 单元测试（不依赖 iOS / Metal，跨平台）
//
// 编译（独立运行）：
//   POSIX : cc -DGCC_STANDALONE_TEST -std=c11 test_mesh.c gcc_face_mesh.c -o test_mesh -lm
//   MSVC  : cl /DGCC_STANDALONE_TEST /std:c11 test_mesh.c gcc_face_mesh.c
//
// 用法：
//   ./test_mesh <effect_root>            # 跑内置断言表
//   ./test_mesh --dump <file.mesh>       # 单文件详细输出
//
// ============== 基准值来源 ==============
// 下列断言值来自抖音官方下发特效包 5 个 mesh 的实测解析，
// 已在 Python 参考实现中逐字节复核。任何一项不符即视为解析器回归。
//
//   name                    verts valid stride  tris  bbox
//   Face145_mesh             870   870    20   1536  (46,24)-(994,1127)
//   lips_keypoint2999_mesh  1475  1475    16    985  (194,67)-(805,916)
//   mask2998_mesh           1475  1475    16   1104  (194,67)-(805,916)
//   eye_part2980_mesh        820   820    16   1570  (275,367)-(723,560)
//   mask_faceuv22994_mesh   1770   295    20    394  (119,147)-(588,822)
//
// 关键格式规律（不可违背）：
//   len == 12 + cnt * 4
//   UV 格式: 5 float/顶点 = [X][Y][pad][U][V]，20 字节，pad 必须为 0
//   XY 格式: 4 float/顶点 = [pad][pad][X][Y]，16 字节，前两 float 必须为 0
//   X/Y == -1 是「无对应3D位置」的填充槽，不算有效顶点

/* 独立测试程序：仅在定义 GCC_STANDALONE_TEST 时编译，
   避免与 App 的 main() 冲突（Xcode 会自动扫描 src/ 下所有 .c） */
#ifdef GCC_STANDALONE_TEST

#include "gcc_face_mesh.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <sys/stat.h>

#if defined(_WIN32)
  #include <windows.h>
#else
  #include <dirent.h>
#endif

// ---------------------------- 断言框架 ----------------------------

static int g_pass = 0;
static int g_fail = 0;

#define CHECK(cond, ...) do {                                        \
    if (cond) { g_pass++; }                                          \
    else { g_fail++; printf("  FAIL: "); printf(__VA_ARGS__); printf("\n"); } \
} while (0)

// ---------------------------- 跨平台目录遍历 ----------------------------

#if defined(_WIN32)

typedef struct { HANDLE h; WIN32_FIND_DATAA fd; int first; } DirIter;

static int dir_open(DirIter *it, const char *path) {
    char pat[1200];
    snprintf(pat, sizeof(pat), "%s\\*", path);
    it->h = FindFirstFileA(pat, &it->fd);
    it->first = 1;
    return (it->h != INVALID_HANDLE_VALUE);
}

// 返回 1 表示取到一项；name = 文件名，is_dir = 是否目录
static int dir_next(DirIter *it, char *name, size_t cap, int *is_dir) {
    for (;;) {
        if (it->first) it->first = 0;
        else if (!FindNextFileA(it->h, &it->fd)) return 0;
        if (it->fd.cFileName[0] == '.') continue;
        snprintf(name, cap, "%s", it->fd.cFileName);
        *is_dir = (it->fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) ? 1 : 0;
        return 1;
    }
}

static void dir_close(DirIter *it) {
    if (it->h != INVALID_HANDLE_VALUE) { FindClose(it->h); it->h = INVALID_HANDLE_VALUE; }
}

#else

// 记父目录：stat 必须用完整路径，裸文件名在 CWD 下找不到
typedef struct { DIR *d; char parent[1024]; } DirIter;

static int dir_open(DirIter *it, const char *path) {
    it->d = opendir(path);
    if (!it->d) return 0;
    snprintf(it->parent, sizeof(it->parent), "%s", path);
    return 1;
}

// POSIX 没有 d_type 的保证，用 stat 判目录
static int dir_next(DirIter *it, char *name, size_t cap, int *is_dir) {
    struct dirent *e;
    while ((e = readdir(it->d))) {
        if (e->d_name[0] == '.') continue;
        snprintf(name, cap, "%s", e->d_name);
        *is_dir = 0;
#if defined(DT_DIR)
        if (e->d_type == DT_DIR) { *is_dir = 1; return 1; }
        if (e->d_type != DT_UNKNOWN) { *is_dir = 0; return 1; }
#endif
        {
            // 关键：必须拼父目录，否则 stat 在 CWD 下找不到
            char full[2048];
            snprintf(full, sizeof(full), "%s/%s", it->parent, e->d_name);
            struct stat st;
            if (stat(full, &st) == 0 && S_ISDIR(st.st_mode)) *is_dir = 1;
        }
        return 1;
    }
    return 0;
}

static void dir_close(DirIter *it) { if (it->d) closedir(it->d); }

#endif

// ---------------------------- 基准表 ----------------------------

typedef struct {
    const char *name;
    int verts, valid, stride, tris;
    float bx0, by0, bx1, by1;
} Baseline;

static const Baseline kBaseline[] = {
    { "Face145_mesh",            870,  870, 20, 1536,  46,  24, 994, 1127 },
    { "lips_keypoint2999_mesh", 1475, 1475, 16,  985, 194,  67, 805,  916 },
    { "mask2998_mesh",          1475, 1475, 16, 1104, 194,  67, 805,  916 },
    { "eye_part2980_mesh",       820,  820, 16, 1570, 275, 367, 723,  560 },
    { "mask_faceuv22994_mesh",  1770,  295, 20,  394, 119, 147, 588,  822 },
};
#define BASELINE_COUNT ((int)(sizeof(kBaseline)/sizeof(kBaseline[0])))

#define BBOX_TOL 3.0f

// ---------------------------- 工具 ----------------------------

static unsigned char *read_file(const char *path, size_t *out_len) {
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    if (fseek(f, 0, SEEK_END)) { fclose(f); return NULL; }
    long sz = ftell(f);
    if (sz <= 0) { fclose(f); return NULL; }
    rewind(f);
    unsigned char *buf = (unsigned char*)malloc((size_t)sz);
    if (!buf) { fclose(f); return NULL; }
    size_t got = fread(buf, 1, (size_t)sz, f);
    fclose(f);
    if (got != (size_t)sz) { free(buf); return NULL; }
    *out_len = got;
    return buf;
}

static unsigned int rd_u32le(const unsigned char *p) {
    return (unsigned)p[0] | ((unsigned)p[1] << 8)
         | ((unsigned)p[2] << 16) | ((unsigned)p[3] << 24);
}

static int ends_with(const char *s, const char *suffix) {
    size_t a = strlen(s), b = strlen(suffix);
    if (a < b) return 0;
    return strcmp(s + a - b, suffix) == 0;
}

// ---------------------------- 测试1：block2 公式 ----------------------------
// 遍历所有 .mesh，校验 len == 12 + cnt*4。
// 这条规律在全部 39 个 mesh 上成立，是格式最硬的约束。

static void test_block2_formula(const char *root) {
    printf("\n[test_block2_formula] 校验 len == 12 + cnt*4\n");

    char stack[32][1024];
    int sp = 0;
    snprintf(stack[sp++], sizeof(stack[0]), "%s", root);

    int checked = 0;
    while (sp > 0) {
        char cur[1024];
        snprintf(cur, sizeof(cur), "%s", stack[--sp]);

        DirIter it;
        if (!dir_open(&it, cur)) continue;

        char nm[512];
        int isdir = 0;
        while (dir_next(&it, nm, sizeof(nm), &isdir)) {
            char path[2048];
            snprintf(path, sizeof(path), "%s/%s", cur, nm);

            if (isdir) {
                if (sp < 32) snprintf(stack[sp++], sizeof(stack[0]), "%s", path);
                continue;
            }
            if (!ends_with(nm, ".mesh")) continue;

            size_t len = 0;
            unsigned char *d = read_file(path, &len);
            if (!d || len < 0x6C + 40) { free(d); continue; }

            unsigned nameLen = rd_u32le(d + 0x68);
            if (nameLen >= 1 && nameLen <= 200 && 0x6C + nameLen + 32 <= len) {
                size_t off = 0x6C + nameLen + 32;
                while (off + 16 <= len) {
                    unsigned tag = rd_u32le(d + off);
                    unsigned pl  = rd_u32le(d + off + 4);
                    if (pl > len - off - 8) break;
                    if (tag == 0xD31FDA6Au && pl >= 12) {
                        unsigned cnt = rd_u32le(d + off + 8 + 8);
                        unsigned expect = 12 + cnt * 4;
                        CHECK(expect == pl,
                              "%s: len=%u 但 12+cnt*4=%u (cnt=%u)", nm, pl, expect, cnt);
                        checked++;
                        break;
                    }
                    off += 8 + pl;
                }
            }
            free(d);
        }
        dir_close(&it);
    }
    printf("  检查了 %d 个 mesh\n", checked);
}

// ---------------------------- 测试2：基准值断言 ----------------------------

static void check_one_mesh(const char *path, const Baseline *b) {
    GccFaceMesh m;
    int rc = gcc_mesh_parse_file(path, &m);
    CHECK(rc == 0, "解析失败 rc=%d (%s)", rc, b->name);
    if (rc != 0) return;

    CHECK(m.vert_count == b->verts,
          "%s 顶点数 %d != 期望 %d", b->name, m.vert_count, b->verts);
    CHECK(m.stride_bytes == b->stride,
          "%s stride %d != 期望 %d", b->name, m.stride_bytes, b->stride);
    CHECK(m.valid_count == b->valid,
          "%s 有效顶点 %d != 期望 %d", b->name, m.valid_count, b->valid);

    int tris = m.index_count / 3;
    CHECK(tris == b->tris, "%s 三角形 %d != 期望 %d", b->name, tris, b->tris);

    CHECK(fabsf(m.bbox_minx - b->bx0) <= BBOX_TOL,
          "%s bbox_minx %.1f != %.1f", b->name, m.bbox_minx, b->bx0);
    CHECK(fabsf(m.bbox_miny - b->by0) <= BBOX_TOL,
          "%s bbox_miny %.1f != %.1f", b->name, m.bbox_miny, b->by0);
    CHECK(fabsf(m.bbox_maxx - b->bx1) <= BBOX_TOL,
          "%s bbox_maxx %.1f != %.1f", b->name, m.bbox_maxx, b->bx1);
    CHECK(fabsf(m.bbox_maxy - b->by1) <= BBOX_TOL,
          "%s bbox_maxy %.1f != %.1f", b->name, m.bbox_maxy, b->by1);

    int bad = 0;
    for (int i = 0; i < m.index_count; i++)
        if (m.indices[i] >= m.vert_count) bad++;
    CHECK(bad == 0, "%s 有 %d 个越界索引", b->name, bad);

    if (m.format == GCC_MESH_FORMAT_A) {
        int baduv = 0;
        for (int i = 0; i < m.vert_count; i++) {
            if (m.verts[i].x < -0.5f) continue;
            if (m.verts[i].u < 0.0f || m.verts[i].u > 1.5f ||
                m.verts[i].v < 0.0f || m.verts[i].v > 1.5f) baduv++;
        }
        CHECK(baduv == 0, "%s 有 %d 个越界 UV", b->name, baduv);
    }

    printf("  %-26s %4dv/%4dt stride=%d %s\n",
           b->name, m.vert_count, tris, m.stride_bytes,
           (m.format == GCC_MESH_FORMAT_A) ? "UV" : "XY");

    gcc_mesh_free(&m);
}

static void test_baseline(const char *root) {
    printf("\n[test_baseline] 校验 5 个网格的顶点/索引/bbox\n");

    char stack[32][1024];
    int sp = 0;
    snprintf(stack[sp++], sizeof(stack[0]), "%s", root);

    int found[BASELINE_COUNT];
    memset(found, 0, sizeof(found));

    while (sp > 0) {
        char cur[1024];
        snprintf(cur, sizeof(cur), "%s", stack[--sp]);

        DirIter it;
        if (!dir_open(&it, cur)) continue;

        char nm[512];
        int isdir = 0;
        while (dir_next(&it, nm, sizeof(nm), &isdir)) {
            char path[2048];
            snprintf(path, sizeof(path), "%s/%s", cur, nm);

            if (isdir) {
                if (sp < 32) snprintf(stack[sp++], sizeof(stack[0]), "%s", path);
                continue;
            }
            if (!ends_with(nm, ".mesh")) continue;

            size_t len = 0;
            unsigned char *d = read_file(path, &len);
            if (!d || len < 0x6C + 8) { free(d); continue; }
            unsigned nameLen = rd_u32le(d + 0x68);
            if (nameLen < 1 || nameLen > 200 || 0x6C + nameLen > len) { free(d); continue; }
            char inner[256];
            memcpy(inner, d + 0x6C, nameLen);
            inner[nameLen] = 0;
            free(d);

            for (int i = 0; i < BASELINE_COUNT; i++) {
                if (strcmp(inner, kBaseline[i].name) == 0 && !found[i]) {
                    found[i] = 1;
                    check_one_mesh(path, &kBaseline[i]);
                    break;
                }
            }
        }
        dir_close(&it);
    }

    for (int i = 0; i < BASELINE_COUNT; i++)
        if (!found[i])
            printf("  跳过 %s（未找到该 mesh）\n", kBaseline[i].name);
}

// ---------------------------- 测试3：单文件 dump ----------------------------

static void dump_one(const char *path) {
    GccFaceMesh m;
    int rc = gcc_mesh_parse_file(path, &m);
    printf("rc = %d\n", rc);
    if (rc != 0) return;

    printf("verts   = %d (valid %d)\n", m.vert_count, m.valid_count);
    printf("indices = %d (tris %d)\n", m.index_count, m.index_count / 3);
    printf("stride  = %d\n", m.stride_bytes);
    printf("format  = %c\n", m.format == GCC_MESH_FORMAT_A ? 'A' : 'B');
    printf("bbox    = (%.2f, %.2f) - (%.2f, %.2f)\n",
           m.bbox_minx, m.bbox_miny, m.bbox_maxx, m.bbox_maxy);

    int deg = 0, tris = m.index_count / 3;
    for (int i = 0; i < tris; i++) {
        unsigned a = m.indices[i*3], b2 = m.indices[i*3+1], c = m.indices[i*3+2];
        if (a == b2 || b2 == c || a == c) deg++;
    }
    printf("degenerate tris = %d (%.1f%%)  <- 正常，是边界线编码\n",
           deg, 100.0 * deg / (tris > 0 ? tris : 1));

    printf("first 5 verts:\n");
    for (int i = 0; i < 5 && i < m.vert_count; i++)
        printf("  v%-4d xy(%.1f,%.1f) uv(%.4f,%.4f)\n", i,
               m.verts[i].x, m.verts[i].y, m.verts[i].u, m.verts[i].v);

    gcc_mesh_free(&m);
}

// ---------------------------- main ----------------------------

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr,
            "usage:\n"
            "  %s <effect_root>          跑全部断言\n"
            "  %s --dump <file.mesh>     单文件详细输出\n", argv[0], argv[0]);
        return 1;
    }

    if (strcmp(argv[1], "--dump") == 0 && argc >= 3) {
        dump_one(argv[2]);
        return 0;
    }

    printf("=== gcc_face_mesh 单元测试 ===\n");
    printf("root: %s\n", argv[1]);

    test_block2_formula(argv[1]);
    test_baseline(argv[1]);

    printf("\n================================\n");
    printf("PASS %d / FAIL %d\n", g_pass, g_fail);
    printf("================================\n");
    return g_fail == 0 ? 0 : 3;
}

#endif /* GCC_STANDALONE_TEST */
