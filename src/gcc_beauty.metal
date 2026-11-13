//
// gcc_beauty.metal — 美颜渲染着色器
//
// 每个 pass 对应 BeautyPipeline 里的一个阶段。
// 所有坐标约定：纹理空间 [0,1]，左上原点（与 Metal 纹理一致）。
//

#include <metal_stdlib>
using namespace metal;

// ============================ 公共结构 ============================

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// 全屏三角形（不需要 vertex buffer）
vertex VertexOut gcc_fullscreen_vertex(uint vid [[vertex_id]]) {
    // 三个顶点覆盖整个屏幕
    float2 pos[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };
    float2 uvs[3] = {
        float2(0.0, 1.0),
        float2(2.0, 1.0),
        float2(0.0, -1.0)
    };
    VertexOut o;
    o.position = float4(pos[vid], 0.0, 1.0);
    o.uv = uvs[vid];
    return o;
}

// ============================ Pass 0: YUV → RGB ============================
// 相机输出 NV12（Y + UV 双平面），转成 RGB 供后续处理。
// 系数用 BT.709（iOS 相机默认）。

struct YUVParams {
    float3x3 matrix;      // YUV→RGB 矩阵
    float3   offset;      // 偏移
};

fragment float4 gcc_yuv_to_rgb(VertexOut in [[stage_in]],
                               texture2d<float> texY [[texture(0)]],
                               texture2d<float> texUV [[texture(1)]],
                               constant YUVParams &p [[buffer(0)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float y = texY.sample(s, in.uv).r;
    float2 uv = texUV.sample(s, in.uv).rg;
    float3 yuv = float3(y, uv);
    float3 rgb = p.matrix * (yuv + p.offset);
    return float4(rgb, 1.0);
}

// ============================ Pass 1: 磨皮 ============================
// 双边滤波近似：按颜色相似度加权平均邻域，保留边缘。

struct SmoothParams {
    float2 texelSize;
    float  intensity;      // 0~1
    float  radius;         // 采样半径（像素）
};

fragment float4 gcc_smooth(VertexOut in [[stage_in]],
                           texture2d<float> src [[texture(0)]],
                           texture2d<float> mask [[texture(1)]],
                           constant SmoothParams &p [[buffer(0)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);

    float4 center = src.sample(s, in.uv);
    float m = mask.sample(s, in.uv).r;   // 皮肤区域蒙版
    if (m < 0.01 || p.intensity < 0.001) {
        return center;
    }

    float3 sum = float3(0.0);
    float  wsum = 0.0;
    int    r = (int)p.radius;

    // 5x5 采样，够用且快
    for (int dy = -2; dy <= 2; ++dy) {
        for (int dx = -2; dx <= 2; ++dx) {
            float2 off = float2(dx, dy) * p.texelSize * r * 0.5;
            float4 smp = src.sample(s, in.uv + off);
            float3 d = smp.rgb - center.rgb;
            float dist2 = dot(d, d);
            float spat = exp(-(float)(dx*dx + dy*dy) * 0.3);
            float rang = exp(-dist2 * 60.0);
            float w = spat * rang;
            sum += smp.rgb * w;
            wsum += w;
        }
    }
    float3 blurred = sum / max(wsum, 1e-5);
    float  k = p.intensity * m;
    return float4(mix(center.rgb, blurred, k), 1.0);
}


// ============================ Pass 3: 妆容混合 ============================
// 用 uSTMatrix 把模板坐标映射到妆容贴图 UV，采样后按 alpha 混合。

struct MakeupParams {
    float4 stMatrixX;     // [scaleX, 0, 0, offsetX]
    float4 stMatrixY;     // [0, scaleY, 0, offsetY]
    float4 color;         // 妆容颜色（RGBA，用于非贴图模式）
    float  intensity;     // 0~1
    float2 texelSize;
    float  useTexture;    // 1=用贴图 alpha，0=用 color
};

fragment float4 gcc_makeup(VertexOut in [[stage_in]],
                           texture2d<float> src [[texture(0)]],
                           texture2d<float> makeupTex [[texture(1)]],
                           constant MakeupParams &p [[buffer(0)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);

    float4 base = src.sample(s, in.uv);
    if (p.intensity < 0.001) {
        return base;
    }

    // in.uv 是屏幕上该像素的位置，需要先映射回模板空间
    // 简化：假设模板空间就是 uv * 1024
    float2 templPos = in.uv * 1024.0;

    // 用 uSTMatrix 映射到妆容贴图 UV
    // u = X * scaleX + offsetX
    float2 makeupUV;
    makeupUV.x = templPos.x * p.stMatrixX.x + p.stMatrixX.w;
    makeupUV.y = templPos.y * p.stMatrixY.y + p.stMatrixY.w;

    float4 makeup;
    if (p.useTexture > 0.5) {
        if (any(makeupUV < 0.0) || any(makeupUV > 1.0)) {
            return base;
        }
        makeup = makeupTex.sample(s, makeupUV);
    } else {
        makeup = p.color;
        // 无贴图时用圆形范围限制
        float2 d = makeupUV - 0.5;
        float r = length(d);
        makeup.a *= smoothstep(0.5, 0.2, r);
    }

    float a = makeup.a * p.intensity;
    return float4(mix(base.rgb, makeup.rgb, a), base.a);
}

// ============================ Pass 4: 调色 + LUT ============================
// 6 项调色 + LUT 混合。

struct ColorParams {
    float brightness;   // 0.5 中性
    float contrast;     // 0.5 中性
    float saturation;   // 0.5 中性
    float temperature;  // 0.5 中性
    float vignette;     // 0 关
    float grain;        // 0 关
    float lutMix;       // 0=原图
    float seed;
    float lutSize;      // 512（64³ tiled）
};

// 64³ LUT 采样（8x8 网格，每格 64x64）
static float3 sampleLUT(texture2d<float> lut, float3 color, float lutSize) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);

    color = clamp(color, 0.0, 1.0);
    float blue = color.b * 63.0;
    float b0 = floor(blue);
    float b1 = min(b0 + 1.0, 63.0);
    float bf = blue - b0;

    // 8x8 网格
    float2 tile0 = float2(fmod(b0, 8.0), floor(b0 / 8.0));
    float2 tile1 = float2(fmod(b1, 8.0), floor(b1 / 8.0));

    float cell = lutSize / 8.0;     // 64
    float texel = 1.0 / lutSize;

    // 在格子内加上 r,g 偏移
    float2 uv0 = (tile0 * cell + color.rg * (cell - 1.0) + 0.5) * texel;
    float2 uv1 = (tile1 * cell + color.rg * (cell - 1.0) + 0.5) * texel;

    float3 c0 = lut.sample(s, uv0).rgb;
    float3 c1 = lut.sample(s, uv1).rgb;
    return mix(c0, c1, bf);
}

fragment float4 gcc_color_grade(VertexOut in [[stage_in]],
                                texture2d<float> src [[texture(0)]],
                                texture2d<float> lut [[texture(1)]],
                                constant ColorParams &p [[buffer(0)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float4 c = src.sample(s, in.uv);
    float3 rgb = c.rgb;

    // 亮度
    rgb += (p.brightness - 0.5) * 2.0 * 0.25;
    // 对比度
    float ct = 1.0 + (p.contrast - 0.5) * 1.2;
    rgb = (rgb - 0.5) * ct + 0.5;
    // 饱和度
    float luma = dot(rgb, float3(0.299, 0.587, 0.114));
    rgb = mix(float3(luma), rgb, 1.0 + (p.saturation - 0.5) * 2.0);
    // 色温
    float w = (p.temperature - 0.5) * 2.0;
    rgb.r += w * 0.15;
    rgb.b -= w * 0.15;
    // 暗角
    if (p.vignette > 0.001) {
        float2 d = in.uv - 0.5;
        float r = length(d) * 1.414;
        rgb *= 1.0 - p.vignette * r * r;
    }
    // 颗粒
    if (p.grain > 0.001) {
        float n = fract(sin(dot(in.uv * p.seed, float2(12.9898, 78.233))) * 43758.5453);
        rgb += (n - 0.5) * p.grain * 0.1;
    }
    // LUT
    if (p.lutMix > 0.001) {
        float3 lc = sampleLUT(lut, clamp(rgb, 0.0, 1.0), p.lutSize);
        rgb = mix(rgb, lc, p.lutMix);
    }

    return float4(clamp(rgb, 0.0, 1.0), c.a);
}

// ============================ 直通（无处理时用）============================

fragment float4 gcc_passthrough(VertexOut in [[stage_in]],
                                texture2d<float> src [[texture(0)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    return src.sample(s, in.uv);
}

// ============================ 网格驱动渲染 ============================
// 解决「妆容不跟脸动」：模板坐标由网格顶点插值到片元，
// 不是拿屏幕 uv 当模板坐标。

// 每个网格顶点：屏幕位置(归一化) + 模板坐标(0~1024) + 贴图UV
struct MeshVertexIn {
    float2 screenPos  [[attribute(0)]];   // 0~1 屏幕位置
    float2 templPos   [[attribute(1)]];   // 0~1024 模板坐标
    float2 uv         [[attribute(2)]];   // 原图 UV
};

struct MeshVertexOut {
    float4 position [[position]];
    float2 templPos;
    float2 uv;
    float  valid;      // 顶点是否有效（非 -1 填充）
};

// 形变参数：把网格顶点从「模板位置」映射到「屏幕位置」时叠加形变
// 23 个形变槽位，按人脸解剖分区。
// 所有强度都是「相对中性的偏移」：0 = 不变形，正负 = 两个方向。
// 上层用 gcc_beauty_params_neutral()（全 0.5）减 0.5 得到这里的值。
// ★ 全部用 float 标量，不用 float2/float4：
//   MSL 的 float2 需要 8 字节对齐、float4 需要 16 字节，而 C 的 float[N]
//   只需要 4 字节。混用会导致字段偏移错位（实测最大差 32 字节），
//   编译器不报错，只在运行时表现为画面异常。
struct MeshWarpParams {
    float mvp[16];          // 模板坐标 → 屏幕位置（4x4，行主序）

    // ---- 全脸区 ----
    float centerX, centerY;         // 人脸中心（模板坐标 0~1024）
    float faceSlim, faceSmall;      // 瘦脸 / 小脸
    float faceCut, headSmall;       // 窄脸 / 小头

    // ---- 眼部区 ----
    float eyeLX, eyeLY;             // 左眼中心
    float eyeRX, eyeRY;             // 右眼中心
    float eyeRadius;
    float eyeSizeK, pupilK, lowerEyelidK, eyeDistK;
    float eyeCornerK, eyePosK, eyeTailUpK, browLiftK;

    // ---- 嘴部区 ----
    float mouthCX, mouthCY;
    float mouthRadius;
    float mouthShapeK, mouthPosK, mouthWidthK, upperLipK;
    float smileK;

    // ---- 鼻部区 ----
    float noseCX, noseCY;
    float noseRadius;
    float noseSlimK, noseWingK, noseBridgeK, nosePosK;

    // ---- 下巴区 ----
    float chinCX, chinCY;
    float chinRadius;
    float chinLengthK, chinPointyK;

    // ---- 颧骨区 ----
    float cheekCX, cheekCY;
    float cheekRadius;
    float cheekboneK, cheekboneSlimK;

    // ---- 额头区 ----
    float foreheadCX, foreheadCY;
    float foreheadRadius;
    float foreheadK;
};

// 高斯衰减：dist 在 radius 内有效，超出衰减到 0
static float warpFalloff(float2 d, float radius) {
    float d2 = dot(d, d) / max(radius * radius, 1e-6);
    return exp(-d2 * 2.0);
}

// 双行分层走：把 51 槽位的 23 个形变按区域累加到顶点上。
// 全部在模板坐标空间算，最后一次性映射到屏幕，避免多次往返失真。
vertex MeshVertexOut gcc_mesh_vertex(MeshVertexIn in [[stage_in]],
                                     constant MeshWarpParams &p [[buffer(1)]]) {
    MeshVertexOut o;

    // 起点是模板坐标本身
    float2 tp = in.templPos;

    // ---------- 全脸区：横向收紧 + 整体缩放 ----------
    {
        float2 d = tp - float2(p.centerX, p.centerY);
        float w = warpFalloff(d, 1024.0);      // 全脸都用
        // 横向收（瘦脸）+ 纵向不动
        tp.x -= d.x * p.faceSlim * 0.10 * w;
        // 小脸：整体向中心收缩
        tp -= d * p.faceSmall * 0.08 * w;
        // 窄脸：再收一层横向
        tp.x -= d.x * p.faceCut * 0.08 * w;
        // 小头：整体缩放（围绕中心）
        float scale = 1.0 - p.headSmall * 0.10 * w;
        tp = float2(p.centerX, p.centerY) + (tp - float2(p.centerX, p.centerY)) * scale;
    }

    // ---------- 眼部区 ----------
    {
        float wL = warpFalloff(tp - float2(p.eyeLX, p.eyeLY), p.eyeRadius);
        float wR = warpFalloff(tp - float2(p.eyeRX, p.eyeRY), p.eyeRadius);
        float w = max(wL, wR);
        float2 ec = (wL >= wR) ? float2(p.eyeLX, p.eyeLY) : float2(p.eyeRX, p.eyeRY);
        float2 d = tp - ec;

        // 大眼：径向扩张
        tp += d * p.eyeSizeK * 0.22 * w;
        // 瞳孔：只在很小范围（radius*0.35）
        tp += d * p.pupilK * 0.18 * warpFalloff(d, p.eyeRadius * 0.35);
        // 眼睑下至：只推下半部分
        if (d.y > 0.0) tp.y += p.lowerEyelidK * 6.0 * w * (d.y / max(p.eyeRadius, 1e-3));
        // ---- 眼距（SHAPE[30] eye_far）----
        // 左右眼各向外/内推，只作用于该眼半径内
        tp.x += sign(d.x) * p.eyeDistK * 10.0 * w;

        // ---- 眼角（WARP[31] fd_outer_corner_v6）----
        // 只拉外侧（远离鼻梁那边）
        {
            float outerX = (ec.x < p.centerX) ? -1.0 : 1.0;   // 该眼的外侧方向
            float oc = smoothstep(0.2, 1.0, d.x * outerX / max(p.eyeRadius, 1e-3));
            tp.x += outerX * p.eyeCornerK * 6.0 * w * oc;
        }

        // ---- 眼位（SHAPE[32] eye_move）----
        // 整体上下平移，按 w 衰减
        tp.y += p.eyePosK * 9.0 * w;

        // ---- 眼尾上扬（WARP[34] fd_outer_corner_v6 + eye_eyecorner）----
        {
            float outerX = (ec.x < p.centerX) ? -1.0 : 1.0;
            float oc = smoothstep(0.3, 1.0, d.x * outerX / max(p.eyeRadius, 1e-3));
            tp.y -= p.eyeTailUpK * 7.0 * w * oc;
        }

        // ---- 眉挑（SHAPE[35] eye_eyebrowjump）----
        // 只作用于眼睛上方 [0.55, 1.4] 倍半径的带状区
        {
            float up = -d.y / max(p.eyeRadius, 1e-3);         // 上方为正
            float band = smoothstep(0.55, 0.9, up) * (1.0 - smoothstep(1.0, 1.4, up));
            tp.y -= p.browLiftK * 8.0 * w * band;
        }
    }

    // ---------- 嘴部区 ----------
    {
        float w = warpFalloff(tp - float2(p.mouthCX, p.mouthCY), p.mouthRadius);
        float2 d = tp - float2(p.mouthCX, p.mouthCY);
        float2 dn = d / max(p.mouthRadius, 1e-3);

        // 嘴形：整体缩放
        tp = float2(p.mouthCX, p.mouthCY) + d * (1.0 + p.mouthShapeK * 0.12 * w);
        // 嘴巴位置：整体上下移动
        tp.y += p.mouthPosK * 10.0 * w;
        // 嘴巴宽度：横向拉伸
        tp.x += d.x * p.mouthWidthK * 0.15 * w;
        // 丰上唇：上唇区变厚（向上扩）
        if (dn.y < 0.0) tp.y -= p.upperLipK * 6.0 * w;
        // 微笑：嘴角上扬
        if (abs(dn.x) > 0.4) tp.y -= p.smileK * 8.0 * w;
    }

    // ---------- 鼻部区 ----------
    {
        float w = warpFalloff(tp - float2(p.noseCX, p.noseCY), p.noseRadius);
        float2 d = tp - float2(p.noseCX, p.noseCY);
        // 瘦鼻：横向收紧
        tp.x -= d.x * p.noseSlimK * 0.18 * w;
        // 鼻翼：两侧收
        if (abs(d.x) > p.noseRadius * 0.3)
            tp.x -= sign(d.x) * p.noseWingK * 5.0 * w;
        // 鼻梁：纵向拉
        tp.y -= d.y * p.noseBridgeK * 0.12 * w;
        // 鼻位：整体平移
        tp.y += p.nosePosK * 8.0 * w;
    }

    // ---------- 下巴区 ----------
    {
        float w = warpFalloff(tp - float2(p.chinCX, p.chinCY), p.chinRadius);
        float2 d = tp - float2(p.chinCX, p.chinCY);
        // 下颚：纵向拉长
        tp.y += d.y * p.chinLengthK * 0.15 * w;
        // 尖下巴：底部横向收
        if (d.y > 0.0) tp.x -= d.x * p.chinPointyK * 0.25 * w;
    }

    // ---------- 颧骨区 ----------
    {
        float w = warpFalloff(tp - float2(p.cheekCX, p.cheekCY), p.cheekRadius);
        float2 d = tp - float2(p.cheekCX, p.cheekCY);
        // 立体：向外推（增强）
        tp += d * p.cheekboneK * 0.10 * w;
        // 瘦颧骨：向内收
        tp -= d * p.cheekboneSlimK * 0.12 * w;
    }

    // ---------- 额头区 ----------
    {
        float w = warpFalloff(tp - float2(p.foreheadCX, p.foreheadCY), p.foreheadRadius);
        // 额头：上推
        tp.y -= p.foreheadK * 10.0 * w;
    }

    // ---------- 模板坐标 → 屏幕 ----------
    float4 clip = p.mvp * float4(tp, 0.0, 1.0);
    float2 sp = clip.xy / max(abs(clip.w), 1e-5);

    o.position = float4(sp * 2.0 - 1.0, 0.0, 1.0);   // 0~1 → -1~1
    o.position.y = -o.position.y;                     // Metal 上屏 Y 翻转
    o.templPos = in.templPos;                         // ★ 妆容用原始模板坐标
    o.uv = in.uv;
    o.valid = 1.0;
    return o;
}

// 网格片元：采原图 + 按模板坐标贴妆容
// ★ 全 float 标量：MSL 的 float2/float4 有 8/16 字节对齐要求，
//   C 的 float[N] 只 4 字节，混用会让字段偏移错位（已在 MeshWarpParams 踩过）。
struct MeshFragParams {
    float stScaleX, stOffsetX;      // 模板 → 妆容贴图 UV
    float stScaleY, stOffsetY;
    float makeupIntensity;          // 强度（滑条值）
    float makeupOpacity;            // 材质 opacity
    float openMouth;                // 1 = 张嘴（用 mask.g），0 = 闭嘴（用 mask.r）
    float smoothIntensity;
    float texelSizeX, texelSizeY;
    float useMakeupTex;             // 1 = 用 LUT 查表；0 = 用固定色
    float makeupColorR, makeupColorG, makeupColorB, makeupColorA;  // 兜底色
    // 分区妆容（多个妆容可同时叠加）
    float lipIntensity;
    float blushIntensity;
    float eyeIntensity;
    float teethIntensity;

    // ---- 局部美颜（合并进本结构，避免第二个 buffer）----
    float eyeLX, eyeLY, eyeRX, eyeRY;    // 双眼中心（模板坐标）
    float mouthCX, mouthCY;
    float noseCX, noseCY;
    float faceCX, faceCY;
    float darkCircleK;                   // 黑眼圈
    float nasolabialK;                   // 法令纹
    float eyeBrightenK;                  // 亮眼
    float rosyK;                         // 红润
    float whitenK;                       // 美白
    float clarityK;                      // 清晰（锐化）
};


// ============================ 局部美颜：黑眼圈 / 法令纹 / 亮眼 ============================
// 这 3 项在安卓侧是 JS 实现（__gccBeauty.set("dark"/"smile"/"eye", v)），
// iOS 无 JS 运行时，改为直接在片元里按区域权重处理。
//
// 参数（都在模板坐标 0~1024 空间）：
//   eyeCenterL/R : 双眼中心
//   mouthCenter  : 嘴中心
//   noseCenter   : 鼻中心



// 黑眼圈：眼下区域提亮 + 降饱和
static float3 applyDarkCircle(float3 c, float2 tp, constant MeshFragParams &p) {
    if (p.darkCircleK < 0.001) return c;

    // 眼下区域：眼中心下方 0.3~1.2 倍眼半径，横向 ±0.9 倍
    float2 eL = float2(p.eyeLX, p.eyeLY);
    float2 eR = float2(p.eyeRX, p.eyeRY);
    float r = 55.0;   // 眼部基准半径（模板单位）

    float w = 0.0;
    float2 dc = float2(0.0);
    // 左眼
    {
        float2 d = tp - eL;
        float dy = d.y - r * 0.55;            // 下移到眼袋位置
        float wx = 1.0 - smoothstep(r * 0.4, r * 1.1, abs(d.x));
        float wy = exp(-(dy * dy) / (r * r * 0.28));
        if (wy * wx > w) { w = wy * wx; dc = d; }
    }
    // 右眼
    {
        float2 d = tp - eR;
        float dy = d.y - r * 0.55;
        float wx = 1.0 - smoothstep(r * 0.4, r * 1.1, abs(d.x));
        float wy = exp(-(dy * dy) / (r * r * 0.28));
        if (wy * wx > w) { w = wy * wx; dc = d; }
    }
    if (w < 0.01) return c;

    float k = p.darkCircleK * w;
    // 提亮（黑眼圈通常比周围暗）
    float3 lifted = c + float3(0.055) * k;
    // 降饱和（压掉青紫色）
    float L = dot(lifted, float3(0.299, 0.587, 0.114));
    lifted = mix(float3(L), lifted, 1.0 - 0.35 * k);
    return mix(c, lifted, k);
}

// 法令纹：鼻翼到嘴角的斜向带，柔化 + 提亮
static float3 applyNasolabial(float3 c, float2 tp, constant MeshFragParams &p) {
    if (p.nasolabialK < 0.001) return c;

    // 从鼻翼指向嘴角的线段，两侧 ±22 像素内衰减
    float2 a = float2(p.noseCX, p.noseCY + 15.0);
    float2 b = float2(p.mouthCX, p.mouthCY - 10.0);
    float2 ab = b - a;
    float len2 = max(dot(ab, ab), 1e-3);
    float tt = clamp(dot(tp - a, ab) / len2, 0.0, 1.0);
    float2 closest = a + ab * tt;
    float dist = length(tp - closest);

    float w = 1.0 - smoothstep(12.0, 30.0, dist);
    // 只在左右两侧（排除鼻梁中线）
    float side = smoothstep(15.0, 35.0, abs(tp.x - p.noseCX));
    w *= side;
    if (w < 0.01) return c;

    float k = p.nasolabialK * w;
    float3 lifted = c + float3(0.045) * k;   // 提亮阴影
    return mix(c, lifted, k);
}

// 亮眼：眼白区域提亮 + 去红血丝
static float3 applyEyeBrighten(float3 c, float2 tp, constant MeshFragParams &p) {
    if (p.eyeBrightenK < 0.001) return c;

    float2 eL = float2(p.eyeLX, p.eyeLY);
    float2 eR = float2(p.eyeRX, p.eyeRY);
    float r = 55.0;

    float wL = exp(-dot(tp - eL, tp - eL) / (r * r * 0.55));
    float wR = exp(-dot(tp - eR, tp - eR) / (r * r * 0.55));
    float w = max(wL, wR);
    if (w < 0.01) return c;

    float k = p.eyeBrightenK * w;
    // 眼白判定：亮度高且饱和度低
    float L = dot(c, float3(0.299, 0.587, 0.114));
    float mx = max(max(c.r, c.g), c.b);
    float mn = min(min(c.r, c.g), c.b);
    float sat = (mx > 0.001) ? (mx - mn) / mx : 0.0;
    float isWhite = smoothstep(0.45, 0.62, L) * (1.0 - smoothstep(0.18, 0.32, sat));

    float kk = k * isWhite;
    float3 lifted = c + float3(0.07) * kk;
    // 轻微降红（去血丝）
    lifted.r = lifted.r * (1.0 - 0.10 * kk);
    return mix(c, lifted, kk);
}

// 红润：颧骨区域叠加暖色
static float3 applyRosy(float3 c, float2 tp, constant MeshFragParams &p) {
    if (p.rosyK < 0.001) return c;

    float r = 70.0;
    float2 cL = float2(p.faceCX - 150.0, p.faceCY + 20.0);
    float2 cR = float2(p.faceCX + 150.0, p.faceCY + 20.0);

    float wL = exp(-dot(tp - cL, tp - cL) / (r * r));
    float wR = exp(-dot(tp - cR, tp - cR) / (r * r));
    float w = max(wL, wR);
    if (w < 0.01) return c;

    float k = p.rosyK * w * 0.35;
    float3 rosy = float3(0.98, 0.62, 0.62);
    return mix(c, c * 0.85 + rosy * 0.15, k);
}

// ============================ 妆容：4x4 LUT 查表上色 ============================
// 逐行移植自抖音官方 lips_keypoint2999.frag。
// 关键：颜色不是固定值，而是「用当前画面颜色去 LUT 里查」——
//       9 个色号的差异全在各自 64x64 的 lookup 贴图里，代码完全通用。
//
// 官方原文：
//   float blueColor = textureColor.b * 15.0;
//   quad1.y = clamp(floor(blueColor*0.25), 0, 4);
//   quad1.x = clamp(blueColor - quad1.y*4, 0, 4);
//   texPos.x = quad.x*0.25 + 0.0078125 + 0.234375*color.r;
//   newColor = mix(tex(lut,texPos1), tex(lut,texPos2), fract(blueColor));

static float3 makeupLookup(texture2d<float> lut, sampler s, float3 src) {
    float blueColor = src.b * 15.0;
    float floorB = floor(blueColor);
    float ceilB  = ceil(blueColor);

    // quad1（下界格）
    float q1y = clamp(floor(floorB * 0.25), 0.0, 4.0);
    float q1x = clamp(floorB - q1y * 4.0, 0.0, 4.0);
    // quad2（上界格）
    float q2y = clamp(floor(ceilB * 0.25), 0.0, 4.0);
    float q2x = clamp(ceilB - q2y * 4.0, 0.0, 4.0);

    // 官方常量：0.0078125 = 1/128（半像素偏移），0.234375 = 30/128（格内跨度）
    float2 pos1 = float2(q1x * 0.25 + 0.0078125 + 0.234375 * src.r,
                         q1y * 0.25 + 0.0078125 + 0.234375 * src.g);
    float2 pos2 = float2(q2x * 0.25 + 0.0078125 + 0.234375 * src.r,
                         q2y * 0.25 + 0.0078125 + 0.234375 * src.g);

    float3 c1 = lut.sample(s, pos1).rgb;
    float3 c2 = lut.sample(s, pos2).rgb;
    return mix(c1, c2, fract(blueColor));
}

fragment float4 gcc_mesh_fragment(MeshVertexOut in [[stage_in]],
                                  texture2d<float> srcTex     [[texture(0)]],
                                  texture2d<float> makeupTex  [[texture(1)]],
                                  texture2d<float> skinMask   [[texture(2)]],
                                  constant MeshFragParams &p  [[buffer(0)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);

    // 原图颜色
    float4 base = srcTex.sample(s, in.uv);
    float3 rgb = base.rgb;

    // ---- 磨皮（局部 5x5 双边近似，按皮肤蒙版加权）----
    if (p.smoothIntensity > 0.001) {
        float m = skinMask.sample(s, in.uv).r;
        if (m > 0.01) {
            float3 sum = float3(0.0);
            float  wsum = 0.0;
            for (int dy = -2; dy <= 2; ++dy) {
                for (int dx = -2; dx <= 2; ++dx) {
                    float2 off = float2(dx, dy) * p.texelSize * 1.2;
                    float3 smp = srcTex.sample(s, in.uv + off).rgb;
                    float3 dd = smp - rgb;
                    float w = exp(-(float)(dx*dx+dy*dy) * 0.3)
                            * exp(-dot(dd,dd) * 60.0);
                    sum += smp * w;
                    wsum += w;
                }
            }
            float3 blurred = sum / max(wsum, 1e-5);
            rgb = mix(rgb, blurred, p.smoothIntensity * m);
        }
    }

    // ---- 美白：整体提亮 L 通道，保留色相 ----
    if (p.whitenK > 0.001) {
        float m = skinMask.sample(s, in.uv).r;
        if (m > 0.01) {
            float L = dot(rgb, float3(0.299, 0.587, 0.114));
            // 只抬亮暗部，高光不过曝
            float lift = (1.0 - L) * p.whitenK * 0.22 * m;
            rgb += float3(lift);
        }
    }

    // ---- 清晰：非锐化掩模（unsharp mask）----
    if (p.clarityK > 0.001) {
        float3 blur = float3(0.0);
        blur += srcTex.sample(s, in.uv + float2(-p.texelSizeX, 0.0)).rgb;
        blur += srcTex.sample(s, in.uv + float2( p.texelSizeX, 0.0)).rgb;
        blur += srcTex.sample(s, in.uv + float2(0.0, -p.texelSizeY)).rgb;
        blur += srcTex.sample(s, in.uv + float2(0.0,  p.texelSizeY)).rgb;
        blur *= 0.25;
        rgb = rgb + (rgb - blur) * (p.clarityK * 0.6);
    }

    // ---- 局部美颜：黑眼圈 / 法令纹 / 亮眼 / 红润 ----
    // 都在模板坐标空间做区域加权，顺序：先修瑕，再上色
    {
        float2 tp = in.templPos;
        rgb = applyDarkCircle(rgb, tp, p);
        rgb = applyNasolabial(rgb, tp, p);
        rgb = applyEyeBrighten(rgb, tp, p);
        rgb = applyRosy(rgb, tp, p);
    }

    // ---- 妆容：严格对齐官方 shader ----
    //
    // 官方逻辑（lips_keypoint2999.frag）：
    //   vec4 mask = texture2D(maskImageTexture, sucaiTexCoord);
    //   float alpha = (openMouth > 0) ? mask.g : mask.r;
    //   vec4 tem = addLipColor(src);          // ← 用 LUT 查表
    //   gl_FragColor = mix(src, tem, alpha * intensity * opacity);
    //
    // 注意：makeupTex 是 LUT 查表贴图（lookup），skinMask 位置改用
    //       makeupMask 传 mask 贴图。这里复用了 texture(1)=LUT, texture(2)=mask。
    if (p.makeupIntensity > 0.001 && p.useMakeupTex > 0.5) {
        float2 mUV;
        mUV.x = in.templPos.x * p.stScaleX + p.stOffsetX;
        mUV.y = in.templPos.y * p.stScaleY + p.stOffsetY;

        if (all(mUV >= 0.0) && all(mUV <= 1.0)) {
            // alpha: 张嘴用 g 通道（牙齿），闭嘴用 r 通道
            float4 maskS = skinMask.sample(s, mUV);
            float alpha = (p.openMouth > 0.5) ? maskS.g : maskS.r;

            // 用当前画面颜色查 4x4 LUT，得到上色后的颜色
            float3 colored = makeupLookup(makeupTex, s, rgb);

            rgb = mix(rgb, colored, alpha * p.makeupIntensity * p.makeupOpacity);
        }
    } else if (p.makeupIntensity > 0.001) {
        // 无 LUT 时的兜底：用固定色 + 模板空间圆形范围
        float2 mUV;
        mUV.x = in.templPos.x * p.stScaleX + p.stOffsetX;
        mUV.y = in.templPos.y * p.stScaleY + p.stOffsetY;
        if (all(mUV >= 0.0) && all(mUV <= 1.0)) {
            float2 c = mUV - 0.5;
            float a = smoothstep(0.5, 0.15, length(c));
            float3 col = float3(p.makeupColorR, p.makeupColorG, p.makeupColorB);
            rgb = mix(rgb, col, a * p.makeupIntensity * p.makeupColorA);
        }
    }

    return float4(rgb, base.a);
}

// ============================ BGRA 直通 ============================
// iOS 相机输出 kCVPixelFormatType_32BGRA，CVOpenGLESTextureCache /
// CVMetalTextureCache 建出的纹理是 BGRA8Unorm。
// 这个 pass 做 通道交换 并输出 RGBA，后续 pass 全部按 RGBA 处理。
fragment float4 gcc_bgra_to_rgba(VertexOut in [[stage_in]],
                                 texture2d<float> srcBGRA [[texture(0)]],
                                 constant float2 &flip [[buffer(0)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float2 uv = in.uv;
    if (flip.x > 0.5) uv.x = 1.0 - uv.x;   // 前置镜像
    if (flip.y > 0.5) uv.y = 1.0 - uv.y;   // 上下翻转
    float4 c = srcBGRA.sample(s, uv);
    return float4(c.b, c.g, c.r, c.a);     // BGRA → RGBA
}

// ============================ 调色 8 项 + 官方 LUT（MSL 版）============================
// ★ 逐字翻译自 color_fx.c 的 kFS —— 公式一个字符都没改。
//   源 shader 已按抖音官方 shaderGLES 口径（fe9aea85 / b8441423 / 538e71c0）
//   校准过，这里只做语言转换（GLSL ES 1.0 → Metal Shading Language）。
//
// 差异仅 3 处（都是语言必需，不影响数值）：
//   1) vec3 → float3, mat3 → float3x3
//   2) texture2D → sample
//   3) gl_FragColor → 返回值

struct GradeParams {
    float lutMix;       // uLutMix
    float bright;       // uBright   (0.5 中性)
    float contra;       // uContra   (0.5 中性)
    float satur;        // uSatur    (0.5 中性)
    float warm;         // uWarm     (0.5 中性)
    float vign;         // uVign
    float grain;        // uGrain
    float seed;         // uSeed
    float flip;         // uFlip (1 = 上下翻转)
    float lutOn;        // uLutOn
    float exposure;     // uExposure
    float brightness;   // uBrightness
    float temperature;  // uTemperature
    float tint;         // uTint
    float contrast;     // uContrast
    float saturation;   // uSaturation
    float2 res;         // uRes
};

fragment float4 gcc_grade_msl(VertexOut in [[stage_in]],
                              texture2d<float> uTex [[texture(0)]],
                              texture2d<float> uLut [[texture(1)]],
                              constant GradeParams &p [[buffer(0)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);

    // vec2 uv = (uFlip == 1) ? vec2(vUV.x, 1.0 - vUV.y) : vUV;
    float2 uv = (p.flip > 0.5) ? float2(in.uv.x, 1.0 - in.uv.y) : in.uv;
    float4 src = uTex.sample(s, uv);
    float3 c = src.rgb;
    // 官方：_494 = 像素 alpha，作为逐像素强度掩码，所有参数都乘它
    float k494 = src.a;

    // ---- 官方 LUT（64³ tiled，8x8 块 / 每块 64x64）----
    if (p.lutOn > 0.5) {
        float3 q = clamp(c, 0.0, 1.0);
        float bs   = q.b * 63.0;
        float blk  = floor(bs);
        float blk2 = min(ceil(bs), 63.0);
        float row  = floor(blk * 0.125);
        float row2 = floor(blk2 * 0.125);
        float2 uv1 = float2((blk  - row  * 8.0) * 0.125, row  * 0.125)
                   + float2(0.0009765625) + q.rg * 0.123046875;
        float2 uv2 = float2((blk2 - row2 * 8.0) * 0.125, row2 * 0.125)
                   + float2(0.0009765625) + q.rg * 0.123046875;
        uv1.y = 1.0 - uv1.y;
        uv2.y = 1.0 - uv2.y;
        float3 lutC = mix(uLut.sample(s, uv1).rgb, uLut.sample(s, uv2).rgb, fract(bs));
        c = mix(c, lutC, p.lutMix);
    }

    // ---- 抖音官方 FilterV2 色彩校正 ----
    c *= pow(2.0, p.exposure * k494);
    c += float3(p.brightness * k494);
    {
        float w = p.temperature * k494;          // 官方: _537 = _Temperature * _494
        float t = (w * -1.5384614) * (((w * 1.5384614) < 0.0) ? 0.1 : 0.05) + 0.31271;
        float ss = (p.tint * k494) * 0.07692307 + (2.87 * t - 3.0 * t * t) -0.27509507;
        float uu = t / ss;
        float vv = (1.0 - t - ss) / ss;
        float3x3 m1 = float3x3(
            float3(0.390405,   0.0708416,  0.0231082),
            float3(0.549941,   0.963172,   0.128021),
            float3(0.00892632, 0.00135775, 0.936245));
        float3x3 m2 = float3x3(
            float3( 2.85847,  -0.210182, -0.041812),
            float3(-1.62879,   1.15820,  -0.118169),
            float3(-0.024891,  0.00032428, 1.06867));
        // ★ 官方原文（fe9aea85.frag）第三分量是:
        //   1.08728 / (0.9834 * _671 + (0.003 * _666 + 0.0136))
        //   之前翻译漏了 0.003 * _666 这一项，导致蓝色通道系统性偏高 ~8.5%
        float3 d = float3(0.949237 / (-0.1624 * vv + 0.7328 * uu + 0.4296),
                          1.03542 / ( 0.0061 * vv -0.7036 * uu + 1.6975),
                          1.08728 / ( 0.9834 * vv + (0.003 * uu + 0.0136)));
        c = m2 * ((m1 * c) * d);
    }
    c = (c - float3(0.21763764)) * (p.contrast * k494 + 1.0) + float3(0.21763764);
    {
        float L = dot(c, float3(0.2126, 0.7152, 0.0722));
        c = mix(float3(L), c, p.saturation * k494 + 1.0);
    }

    // ---- 色调六项（与安卓同式中点 0.5）----
    c = c + float3((p.bright - 0.5) * 0.50);
    {
        float k = 1.0 + (p.contra - 0.5) * 1.20;
        c = (c - 0.5) * k + 0.5;
    }
    {
        float L2 = dot(c, float3(0.299, 0.587, 0.114));
        c = mix(float3(L2), c, p.satur * 2.0);
    }
    {
        float w = (p.warm - 0.5) * 0.24;
        c.r += w; c.b -= w; c.g += w * 0.30;
    }
    if (p.vign > 0.001) {
        float2 d = (uv - 0.5) * float2(p.res.x / max(p.res.y, 1.0), 1.0);
        float r = dot(d, d) * 3.2;
        c *= 1.0 - p.vign * clamp(r, 0.0, 1.0);
    }
    if (p.grain > 0.001) {
        float n = fract(sin(dot(uv * p.res + float2(p.seed, p.seed),
                               float2(12.9898, 78.233))) * 43758.5453);
        c += (n - 0.5) * (p.grain * 0.16);
    }

    return float4(clamp(c, 0.0, 1.0), 1.0);
}


// ============================================================================
// ★ 官方 freid 逐像素位移场形变（第 3 项）
//
// 来源（逐字移植，非推断）：
//   ① analysis/.../AmazingFeature/yunfu_fengying_liuchang/
//        shaderMetal/f6b6dfb8a5768ba3d18c52c1ddfab413.frag
//      官方 MSL 原文：
//        float4 _42 = (((flowTexture.sample(...) - float4(0.5)) * 0.125)
//                      * _22) * fast::clamp(buffer.flowLevel, 0.0, 1.0);
//        _MainTex.sample(..., uv_screen + (mvpMat * float4(_42.x, -_42.y,0,0)).xy)
//      其中 _22 = maskTexture.r（docs/85 §3 / docs/86 §3：「freid = 位移场采样算子」）
//   ② DyClarity/AmazingFeature/xshader/facewarp.metal.frag
//      官方把 faceMask.png 的 B/G 通道导出成 RG 位移纹理：
//        out.o_FragColor = float4(mask.z, mask.y, 0.0, 0.0);
//   ③ DyClarity/AmazingFeature/image/faceMask.png（512×512）
//      实测：内部 28.8% 像素 B/G 为连续渐变（梯度 0.0037），
//            外部为 0 ⇒ 需门控，否则 (0-0.5)*0.125 产生错误位移。
//   ④ DyShape/.../warpX/modelInfo.warpXModel
//      实测多尺度衰减权重：0.5894→0.1476→0.0369→0.0092（1/4 金字塔），
//      后续 0.00058→0.000036（1/16）⇒ 边界 falloff 用同款分层。
//
// 与 gcc_mesh_vertex 的关系：不是替换，是叠加。
//   网格形变负责「妆容/贴图的顶点跟随」，flow 负责「画面像素重采样」，
//   两者分别对应抖音的 FaceWarpXRenderer 与 freid 节点，妆效节点一个不删。
// ============================================================================

struct GccFlowParams {
    // 全部用 float 标量，避免 MSL/C 的 float2/float4 对齐错位（项目既有教训）
    float flowLevel;      // 官方 clamp(flowLevel,0,1)
    float mvp00; float mvp01;   // 只需 2x2 部分：uv 偏移是 vec4(x,y,0,0)
    float mvp10; float mvp11;
    float faceCX;         // 人脸中心（UV）
    float faceCY;
    float faceW;          // 人脸框宽高（UV），用于把模板场对齐到实际人脸
    float faceH;
    float boundaryFalloff; // 边界多尺度衰减强度（warpX 1/4 金字塔口径）
    float enable;         // 0/1 总开关
    float maskConf;       // 掩膜淡入淡出置信度（与 One Euro 配套）
};

// 官方 1/4 金字塔边界 falloff（warpXModel +239428 实测序列）
static float gcc_flow_boundary(float r) {
    // r = 归一化半径 0~1；官方权重 0.5894/0.1476/0.0369/0.0092/0.00058...
    float a = 0.5894f * exp(-r * r * 4.0f);
    float b = 0.1476f * exp(-r * r * 1.0f);
    float c = 0.0369f * exp(-r * r * 0.25f);
    float d = 0.0092f * exp(-r * r * 0.0625f);
    return a + b + c + d;
}

fragment float4 gcc_flow_warp(
    VertexOut in [[stage_in]],
    constant GccFlowParams &p [[buffer(0)]],
    texture2d<float> srcTex   [[texture(0)]],   // 当前画面
    texture2d<float> flowTex  [[texture(1)]],   // faceMask.png（R=原B, G=原G）
    texture2d<float> maskTex  [[texture(2)]],   // 人脸蒙版（.r 为权重）
    sampler s [[sampler(0)]],
    sampler fs [[sampler(1)]],
    sampler ms [[sampler(2)]])
{
    float2 uv = in.uv;
    float4 src = srcTex.sample(s, uv);

    if (p.enable < 0.5f || p.flowLevel < 0.0001f) return src;

    // ---- 官方公式逐字：_22 = mask.r ----
    float m = maskTex.sample(ms, uv).r;

    // ---- 官方公式逐字：(flow - 0.5) * 0.125 * mask * clamp(level,0,1) ----
    // flowTex 的 R/G 是 facewarp.frag 导出的位移编码。
    // 外部区域编码为 0，直接算会得到 -0.0625 的错误位移 → 用 fg/fr 门控。
    float4 flowRaw = flowTex.sample(fs, uv);
    // faceMask 外部区域编码为 0；独立蒙版（ganmask）边缘也为 0。
    // 二者相乘即官方的「mask.r × flow」，不再让位移自己当蒙版（避免平方衰减）。
    float inside = step(0.004f, flowRaw.r + flowRaw.g);
    float4 flow = (flowRaw - float4(0.5f, 0.5f, 0.0f, 0.0f)) * 0.125f;

    // ---- warpX 多尺度边界衰减（1/4 金字塔，实测权重）----
    float2 d = (uv - float2(p.faceCX, p.faceCY)) / float2(max(p.faceW,1e-4f), max(p.faceH,1e-4f));
    float r = length(d);
    float bw = mix(1.0f, gcc_flow_boundary(r), clamp(p.boundaryFalloff, 0.0f, 1.0f));

    float level = clamp(p.flowLevel, 0.0f, 1.0f) * p.maskConf;
    float4 off = flow * m * level * inside * bw;

    // ---- 官方 mvpMat：只用左上 2x2，y 取负 ----
    float2 duv = float2(
        p.mvp00 * off.x + p.mvp01 * (-off.y),
        p.mvp10 * off.x + p.mvp11 * (-off.y));

    // 采样点钳在画面内，避免边界读到黑边
    float2 suv = clamp(uv + duv, float2(0.001f), float2(0.999f));
    float4 warped = srcTex.sample(s, suv);

    // 位移区外保持原像素（inside 已门控）
    return mix(src, warped, clamp(m * inside * level, 0.0f, 1.0f));
}
