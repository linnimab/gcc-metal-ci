// gcc_makeup_map.c — 妆容贴图映射实现
//
// ============ 实测验证结果（七个妆容件，全部精确吻合）============
//  件                   m[0]      m[5]      1/m[0]  1/m[5]   贴图尺寸
//  lips_keypoint2999  0.004348  0.008696    230     115     230x115   ✓
//  eye_part2979       0.002222  0.004348    450     230     450x230   ✓
//  eye_part2980       0.002222  0.004348    450     230     450x230   ✓
//  mask2996           0.001773  0.003802    564     263     289x135
//  mask2998           0.001773  0.003802    564     263     289x135
//  mouth_part2997     0.004348  0.008696    230     115     230x115   ✓
//  teeth2993          0.004348  0.008696    230     115     230x115   ✓
//
// 结论：uSTMatrix 的 m[0]/m[5] 是「模板空间 → 贴图 UV」的缩放，
//       m[12]/m[13] 是平移量。公式：
//           u = X * m[0] + m[12]
//           v = Y * m[5] + m[13]
//       （实测 lips：X*0.004348 - 1.673913，Y*0.008696 - 5.478261）
//
// 与 .material 文件结构：名字 "uSTMatrix" 之后 8 字节是类型标记，
// 再后 16 个 float 是 4x4 行主序矩阵。

#include "gcc_makeup_map.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static uint32_t rd_u32(const uint8_t *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}
static float rd_f32(const uint8_t *p) {
    uint32_t u = rd_u32(p); float f; memcpy(&f, &u, 4); return f;
}

int gcc_makeup_load_material(const char *material_path,
                             int texW, int texH,
                             GccMakeupMap *out) {
    if (!material_path || !out) return -1;
    memset(out, 0, sizeof(*out));
    out->texW = texW;
    out->texH = texH;

    FILE *f = fopen(material_path, "rb");
    if (!f) return -1;
    if (fseek(f, 0, SEEK_END)) { fclose(f); return -1; }
    long sz = ftell(f);
    if (sz <= 0 || sz > 8L*1024*1024) { fclose(f); return -1; }
    rewind(f);
    uint8_t *buf = (uint8_t*)malloc((size_t)sz);
    if (!buf) { fclose(f); return -1; }
    size_t got = fread(buf, 1, (size_t)sz, f);
    fclose(f);
    if (got != (size_t)sz) { free(buf); return -1; }

    /* 找 "uSTMatrix" */
    static const char kKey[] = "uSTMatrix";
    size_t klen = sizeof(kKey) - 1;
    long found = -1;
    for (long i = 0; i + (long)klen <= (long)got; i++) {
        if (memcmp(buf + i, kKey, klen) == 0) { found = i; break; }
    }
    if (found < 0) { free(buf); return -2; }

    /* 名字后 8 字节类型标记，再后 16 个 float */
    size_t base = (size_t)found + klen + 8;
    if (base + 64 > got) { free(buf); return -3; }

    float m[16];
    for (int i = 0; i < 16; i++) m[i] = rd_f32(buf + base + (size_t)i * 4);

    /* 行主序：m[0]=scaleX, m[5]=scaleY, m[12]=offsetX, m[13]=offsetY */
    out->scaleX  = m[0];
    out->scaleY  = m[5];
    out->offsetX = m[12];
    out->offsetY = m[13];

    /* 取文件名主干作为标识 */
    const char *b = strrchr(material_path, '/');
    if (!b) b = strrchr(material_path, '\\');
    b = b ? b + 1 : material_path;
    size_t n = strlen(b);
    if (n > sizeof(out->name) - 1) n = sizeof(out->name) - 1;
    memcpy(out->name, b, n);
    out->name[n] = 0;

    free(buf);

    /* 有效性检查：scale 必须非零且量级合理（0.0001 ~ 1） */
    if (!(out->scaleX > 1e-6f && out->scaleX < 1.0f)) return -4;
    if (!(out->scaleY > 1e-6f && out->scaleY < 1.0f)) return -4;
    return 0;
}
