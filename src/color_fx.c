// color_fx.c — 调色 8 项 + 官方 LUT 滤镜的 GL 实现。
//
// Fragment shader 逐行移植自 Android CameraActivity.java:6881-6974。
// 唯一的语义差异见 color_fx.h 顶部：iOS 不在此 pass 做美白/锐化（避免与
// effect_slots.c 的 update_beauty 映射叠加），只保留色调六项 + LUT。
//
// LUT 采样公式 = 抖音官方下发 shaderGLES（不是自家安卓推导式）：
//   blk=floor(b*63), row=floor(blk/8), uv=(vec2(blk-row*8,row)/8+1/1024)+rg/8.125
//   uv.y = 1-uv.y（官方在 shader 里翻），蓝通道用 ceil+fract 双块插值。
// 必须 highp：mediump 在 512 尺度上步进约 0.5 像素，会出斜条纹。

#include "color_fx.h"

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

// ---------------------------------------------------------------------------
// shader
// ---------------------------------------------------------------------------
static const char *kVS =
    "attribute vec2 aPos;"
    "varying vec2 vUV;"
    "uniform float uMirror;"
    "uniform vec2  uAspect;"
    "void main(){"
    "  vec2 uv = vec2(aPos.x, 1.0 - aPos.y);"
    "  if (uMirror > 0.5) uv.x = 1.0 - uv.x;"
    "  vUV = (uv - 0.5) * uAspect + 0.5;"
    "  gl_Position = vec4(aPos * 2.0 - 1.0, 0.0, 1.0);"
    "}";

static const char *kFS =
    "#ifdef GL_FRAGMENT_PRECISION_HIGH\n"
    "precision highp float;\n"
    "#else\n"
    "precision mediump float;\n"
    "#endif\n"
    "uniform sampler2D uTex;\n"
    "uniform sampler2D uLut;\n"
    "uniform float uLutOn;\n"
    "uniform float uLutMix;\n"
    "uniform float uBright;\n"
    "uniform float uContra;\n"
    "uniform float uSatur;\n"
    "uniform float uWarm;\n"
    "uniform float uVign;\n"
    "uniform float uGrain;\n"
    "uniform float uSeed;\n"
    "uniform vec2  uRes;\n"
    "uniform int   uFlip;\n"
    "uniform float uExposure;\n"
    "uniform float uBrightness;\n"
    "uniform float uTemperature;\n"
    "uniform float uTint;\n"
    "uniform float uContrast;\n"
    "uniform float uSaturation;\n"
    "varying vec2 vUV;\n"
    "void main(){\n"
    "  vec2 uv = (uFlip == 1) ? vec2(vUV.x, 1.0 - vUV.y) : vUV;\n"
    "  vec3 c = texture2D(uTex, uv).rgb;\n"
    // ---- 官方 LUT（64³ tiled，8x8 块 / 每块 64x64）----
    // ---- 抖音官方 shaderGLES 口径（fe9aea85 / b8441423 / 538e71c0）----
    "  if (uLutOn > 0.5) {\n"
    "    vec3 q = clamp(c, 0.0, 1.0);\n"
    "    float bs = q.b * 63.0;\n"
    "    float blk = floor(bs);\n"
    "    float blk2 = min(ceil(bs), 63.0);\n"
    "    float row = floor(blk * 0.125);\n"
    "    float row2 = floor(blk2 * 0.125);\n"
    "    vec2 uv1 = vec2((blk - row * 8.0) * 0.125, row * 0.125) + vec2(0.0009765625) + q.rg * 0.123046875;\n"
    "    vec2 uv2 = vec2((blk2 - row2 * 8.0) * 0.125, row2 * 0.125) + vec2(0.0009765625) + q.rg * 0.123046875;\n"
    "    uv1.y = 1.0 - uv1.y;\n"
    "    uv2.y = 1.0 - uv2.y;\n"
    "    vec3 lutC = mix(texture2D(uLut, uv1).rgb, texture2D(uLut, uv2).rgb, fract(bs));\n"
    "    c = mix(c, lutC, uLutMix);\n"
    "  }\n"
    // ---- 抖音官方 FilterV2 色彩校正（fe9aea85.frag / b8441423.frag）----
    "  c *= pow(2.0, uExposure);\n"
    "  c += vec3(uBrightness);\n"
    "  { float w = uTemperature;\n"
    "    float t = (w * -1.5384614) * (((w * 1.5384614) < 0.0) ? 0.1 : 0.05) + 0.31271;\n"
    "    float s = uTint * 0.07692307 + (2.87 * t - 3.0 * t * t) - 0.27509507;\n"
    "    float u = t / s; float v = (1.0 - t - s) / s;\n"
    "    mat3 m1 = mat3(0.390405,0.0708416,0.0231082, 0.549941,0.963172,0.128021, 0.00892632,0.00135775,0.936245);\n"
    "    mat3 m2 = mat3(2.85847,-0.210182,-0.041812, -1.62879,1.15820,-0.118169, -0.024891,0.00032428,1.06867);\n"
    "    vec3 d = vec3(0.949237 / (-0.1624 * v + 0.7328 * u + 0.4296),\n"
    "                  1.03542 / (0.0061 * v - 0.7036 * u + 1.6975),\n"
    "                  1.08728 / (0.9834 * u + 0.0136));\n"
    "    c = m2 * ((m1 * c) * d); }\n"
    "  c = (c - vec3(0.21763764)) * (uContrast + 1.0) + vec3(0.21763764);\n"
    "  { float L = dot(c, vec3(0.2126, 0.7152, 0.0722));\n"
    "    c = mix(vec3(L), c, uSaturation + 1.0); }\n"
    // ---- 色调六项（与安卓同式中点 0.5）----
    "  c = c + vec3((uBright - 0.5) * 0.50);\n"
    "  { float k = 1.0 + (uContra - 0.5) * 1.20;\n"
    "    c = (c - 0.5) * k + 0.5; }\n"
    "  { float L2 = dot(c, vec3(0.299, 0.587, 0.114));\n"
    "    c = mix(vec3(L2), c, uSatur * 2.0); }\n"
    "  { float w = (uWarm - 0.5) * 0.24;\n"
    "    c.r += w; c.b -= w; c.g += w * 0.30; }\n"
    "  if (uVign > 0.001) {\n"
    "    vec2 d = (uv - 0.5) * vec2(uRes.x / max(uRes.y, 1.0), 1.0);\n"
    "    float r = dot(d, d) * 3.2;\n"
    "    c *= 1.0 - uVign * clamp(r, 0.0, 1.0);\n"
    "  }\n"
    "  if (uGrain > 0.001) {\n"
    "    float n = fract(sin(dot(uv * uRes + vec2(uSeed), vec2(12.9898, 78.233))) * 43758.5453);\n"
    "    c += (n - 0.5) * (uGrain * 0.16);\n"
    "  }\n"
    "  gl_FragColor = vec4(clamp(c, 0.0, 1.0), 1.0);\n"
    "}\n";

// ---------------------------------------------------------------------------
// GL 状态
// ---------------------------------------------------------------------------
static GLuint g_prog = 0;
static GLuint g_vbo  = 0;
static GLuint g_lut  = 0;      // 当前 LUT 纹理；0 = 无
static char   g_err[512] = {0};

// uniform locations（program 建好后一次性取）
static GLint uTex, uLut, uLutOn, uLutMix, uBright, uContra, uSatur,
              uWarm, uVign, uGrain, uSeed, uRes, uFlip,
              uMirror, uAspect, uExposure, uBrightness, uTemperature,
              uTint, uContrast, uSaturation;

static GLuint compile_shader(GLenum type, const char *src) {
    GLuint s = glCreateShader(type);
    glShaderSource(s, 1, &src, NULL);
    glCompileShader(s);
    GLint ok = 0;
    glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[512] = {0};
        glGetShaderInfoLog(s, sizeof(log), NULL, log);
        snprintf(g_err, sizeof(g_err), "compile %s: %s",
                 type == GL_VERTEX_SHADER ? "VS" : "FS", log);
        glDeleteShader(s);
        return 0;
    }
    return s;
}

GccColorFx gcc_fx_neutral(void) {
    GccColorFx f;
    f.bright = 0.5f; f.contra = 0.5f; f.satur = 0.5f; f.warm = 0.5f;
    f.vign = 0.0f;   f.grain = 0.0f;  f.lut_mix = 0.0f; f.seed = 0.0f;
    return f;
}

int gcc_fx_init(void) {
    if (g_prog) return 0;   // 已初始化
    g_err[0] = 0;

    GLuint v = compile_shader(GL_VERTEX_SHADER, kVS);
    if (!v) return -1;
    GLuint f = compile_shader(GL_FRAGMENT_SHADER, kFS);
    if (!f) { glDeleteShader(v); return -2; }

    GLuint p = glCreateProgram();
    glAttachShader(p, v);
    glAttachShader(p, f);
    glBindAttribLocation(p, 0, "aPos");
    glLinkProgram(p);

    GLint ok = 0;
    glGetProgramiv(p, GL_LINK_STATUS, &ok);
    if (!ok) {
        glGetProgramInfoLog(p, sizeof(g_err), NULL, g_err);
        glDeleteProgram(p);
        glDeleteShader(v); glDeleteShader(f);
        return -3;
    }
    glDeleteShader(v);
    glDeleteShader(f);

    uTex    = glGetUniformLocation(p, "uTex");
    uLut    = glGetUniformLocation(p, "uLut");
    uLutOn  = glGetUniformLocation(p, "uLutOn");
    uLutMix = glGetUniformLocation(p, "uLutMix");
    uBright = glGetUniformLocation(p, "uBright");
    uContra = glGetUniformLocation(p, "uContra");
    uSatur  = glGetUniformLocation(p, "uSatur");
    uWarm   = glGetUniformLocation(p, "uWarm");
    uVign   = glGetUniformLocation(p, "uVign");
    uGrain  = glGetUniformLocation(p, "uGrain");
    uSeed   = glGetUniformLocation(p, "uSeed");
    uRes    = glGetUniformLocation(p, "uRes");
    uFlip   = glGetUniformLocation(p, "uFlip");
    uMirror = glGetUniformLocation(p, "uMirror");
    uAspect = glGetUniformLocation(p, "uAspect");
    uExposure   = glGetUniformLocation(p, "uExposure");
    uBrightness = glGetUniformLocation(p, "uBrightness");
    uTemperature= glGetUniformLocation(p, "uTemperature");
    uTint       = glGetUniformLocation(p, "uTint");
    uContrast   = glGetUniformLocation(p, "uContrast");
    uSaturation = glGetUniformLocation(p, "uSaturation");

    // 全屏 quad（与 CameraViewController.m 的 buildBlitProgram 同布局）
    static const GLfloat quad[8] = {
        0.0f, 0.0f,  1.0f, 0.0f,  0.0f, 1.0f,  1.0f, 1.0f,
    };
    glGenBuffers(1, &g_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, g_vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quad), quad, GL_STATIC_DRAW);

    g_prog = p;
    return 0;
}

// ---------------------------------------------------------------------------
// LUT：接收「已经解成 RGBA8、按 PNG 原始行序（左上→右下）排列」的字节缓冲。
//
// 为什么 PNG 解码不放在这里：CGImageCreateWithPNGDataProvider 不是 iOS 公开
// API（macOS 才有），放进来 CI 会编译失败。解码由 CameraViewController.m 用
// UIImage 完成，把 512*512*4 的 RGBA 字节传进来 —— 本模块只管上传成 GL 纹理。
// 这也和安卓侧一致：安卓 Bitmap.decode 拿到像素后直接 glTexImage2D。
//
// 调用方需保证 rgba 是 512x512 RGBA8、非预乘、行序与 PNG 一致。
// ---------------------------------------------------------------------------
int gcc_fx_load_lut(const unsigned char *rgba, size_t bytes) {
    if (!rgba) return -1;
    if (bytes != 512 * 512 * 4) {
        snprintf(g_err, sizeof(g_err), "LUT bytes %zu != %d", bytes, 512 * 512 * 4);
        return -2;
    }

    if (g_lut == 0) glGenTextures(1, &g_lut);
    glBindTexture(GL_TEXTURE_2D, g_lut);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    // 绝不开 mipmap（docs/114 §二.5）
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 512, 512, 0,
                 GL_RGBA, GL_UNSIGNED_BYTE, rgba);

    GLenum e = glGetError();
    if (e != GL_NO_ERROR) {
        snprintf(g_err, sizeof(g_err), "glTexImage2D err=0x%x", e);
        return -7;
    }
    return 0;
}

// ---------------------------------------------------------------------------
// 画一帧
// ---------------------------------------------------------------------------
int gcc_fx_draw(GLuint tex, int w, int h, int flip, int mirror,
                 float frame_aspect, float view_aspect, const GccColorFx *fx) {
    if (!g_prog || tex == 0 || !fx) return -1;

    glUseProgram(g_prog);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, tex);
    glUniform1i(uTex, 0);

    // 没有 LUT 时绑一张 1x1 占位，避免采样器悬空；uLutOn=0 时 shader 不采样。
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, g_lut ? g_lut : tex);
    glUniform1i(uLut, 1);

    int lutOn = (g_lut != 0 && fx->lut_mix > 0.001f) ? 1 : 0;
    glUniform1f(uLutOn,  (float)lutOn);
    glUniform1f(uLutMix, fx->lut_mix);
    glUniform1f(uBright, fx->bright);
    glUniform1f(uContra, fx->contra);
    glUniform1f(uSatur,  fx->satur);
    glUniform1f(uWarm,   fx->warm);
    glUniform1f(uVign,   fx->vign);
    glUniform1f(uGrain,  fx->grain);
    glUniform1f(uSeed,   fx->seed);
    glUniform2f(uRes,    (float)w, (float)h);
    glUniform1i(uFlip,   flip);
    glUniform1f(uMirror, mirror ? 1.0f : 0.0f);
    // aspect-fill：帧宽高比 / 视图宽高比；保持原分辨率，只居中裁切取景，不拉伸。
    float ar = (view_aspect > 0.0001f) ? (frame_aspect / view_aspect) : 1.0f;
    float sx = (ar > 1.0f) ? (1.0f / ar) : 1.0f;
    float sy = (ar < 1.0f) ? ar : 1.0f;
    glUniform2f(uAspect, sx, sy);
    // 官方 FilterV2 色校正：本轮参数取中性（与官方 JS 默认 colorCorrEnabled=false 一致）；
    // 五档各自的 main.scene 参数留作下一轮按官方下发值还原，不在此猜。
    glUniform1f(uExposure, 0.0f);
    glUniform1f(uBrightness, 0.0f);
    glUniform1f(uTemperature, 0.0f);
    glUniform1f(uTint, 0.0f);
    glUniform1f(uContrast, 0.0f);
    glUniform1f(uSaturation, 0.0f);

    glBindBuffer(GL_ARRAY_BUFFER, g_vbo);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, 0);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    // 复位到 TEXTURE0，避免影响调用方/引擎后续绑定
    glActiveTexture(GL_TEXTURE0);
    return 0;
}

void gcc_fx_shutdown(void) {
    if (g_lut)  { glDeleteTextures(1, &g_lut);  g_lut = 0; }
    if (g_vbo)  { glDeleteBuffers(1, &g_vbo);   g_vbo = 0; }
    if (g_prog) { glDeleteProgram(g_prog);      g_prog = 0; }
}

const char *gcc_fx_last_error(void) { return g_err; }
