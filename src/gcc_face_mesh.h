// gcc_face_mesh.h — 抖音特效包 .mesh 解析器（iOS / 纯 C）
//
// 支持两种实测确认的格式（详见 .c 文件头注释）：
//   A: 每顶点 20 字节 [U][V][X][Y][pad0]  —— 人脸主网格（带 UV）
//   B: 每顶点 16 字节 [0][0][X][Y]        —— 妆容网格（仅坐标）
//
// 实测数据（2026-11-12，淡感萌颜包）：
//   Face145_mesh        格式A  870 顶点  @0x00DD
//   mask_faceuv22994    格式A  295 顶点  @0x00E6
//   eye_part_faceu2992  格式A  164 顶点  @0x00E8
//   lips_keypoint2999   格式B  225 顶点  @0x00F7
//   mask2998            格式B  225 顶点  @0x00EE
//   eye_part2980        格式B  500 顶点  @0x00F2
//
// 不依赖 Metal / UIKit，可在 CI 单独测试。

#ifndef GCC_FACE_MESH_H
#define GCC_FACE_MESH_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// 调试：遍历 AMGSerializedFile 的属性块流，返回块数与最大 payload。
int  gcc_mesh_scan_blocks(const uint8_t *data, size_t len,
                          int *out_blocks, int *out_max_payload);


#define GCC_MESH_FORMAT_A 1   // 带 UV 的人脸网格
#define GCC_MESH_FORMAT_B 2   // 仅坐标的妆容网格

typedef struct {
    float u, v;      // 归一化 UV（格式 B 时为 0）
    float x, y;      // 模板空间坐标
} GccMeshVertex;

typedef struct {
    GccMeshVertex *verts;
    int            vert_count;

    uint16_t      *indices;
    int            index_count;   // 通常 = 三角形数 * 3

    float bbox_minx, bbox_miny, bbox_maxx, bbox_maxy;

    int   format;                 // GCC_MESH_FORMAT_A / B
    int   stride_bytes;           // 每顶点字节数（20=带UV, 16=仅坐标）
    int   valid_count;            // 有效顶点数（排除 X=Y=-1 的填充槽）
} GccFaceMesh;

// 解析内存中的 .mesh 内容。成功 0；失败负值：
//   -1 magic/长度问题  -2 找不到顶点区  -3 顶点数不足
int  gcc_mesh_parse(const uint8_t *data, size_t len, GccFaceMesh *out);

// 从文件解析。
int  gcc_mesh_parse_file(const char *path, GccFaceMesh *out);

// 释放。
void gcc_mesh_free(GccFaceMesh *m);

// 打印摘要到 stderr。
void gcc_mesh_dump(const GccFaceMesh *m);

#ifdef __cplusplus
}
#endif

#endif /* GCC_FACE_MESH_H */
