#ifndef GCC_ONE_EURO_H
#define GCC_ONE_EURO_H

/*
 * gcc_one_euro.h — 自适应低通滤波（One Euro Filter）
 *
 * 依据（逐字抄自项目文档）：
 *   docs/83-抖音人脸管线规格书.md §4「平滑/滤波链 —— 抖音不抖的真正原因」
 *     「min_cutoff / beta / d_cutoff 是 One Euro Filter 的标准三参数」
 *     「我们的 extrapolated() 线性外推 + 固定 alpha 是"抖动放大器"，
 *       抖音用的是自适应截止频率滤波」
 *   docs/83 §8-1「本轮可直接落地的三项」：
 *     「换平滑器：把 extrapolated() 的线性外推换成 One-Euro Filter，
 *       参数直接照抄 moe_* / oe_* 语义
 *       （min_cutoff=1.0, beta=0.007, d_cutoff=1.0 为通用起点）」
 *   docs/133 官方 18 项参数（逐字）：
 *     oe_min_cutoff=1.0, oe_beta=0.007, oe_d_cutoff=1.0
 *     moe_min_cutoff=1.0, moe_beta=0.007, moe_float_d_cutoff=1.0
 *     moe_down_sampling_rate=2
 *
 * 原理：截止频率随速度自适应 —— 慢速时低截止（压抖动），
 *       快速时抬高截止（降延迟，避免"跟不上"）。固定 alpha 做不到这点。
 *
 *   alpha(cutoff, dt) = 1 / (1 + 1/(2*pi*cutoff*dt))
 *   dx    = (x - x_prev) / dt            （导数）
 *   dx_hat = lowpass(dx, alpha(d_cutoff, dt))
 *   cutoff = min_cutoff + beta * |dx_hat|
 *   x_hat  = lowpass(x,  alpha(cutoff, dt))
 *
 * 用途：Vision 76 点逐点滤波。76 点 × 2 坐标 = 152 路独立滤波器。
 *       输入/输出都是 0~1 归一化坐标；内部自动 ×1024 到模板空间，
 *       使官方 oe_beta=0.007 的量级假设成立（见 GCC_OE_COORD_SCALE）。
 *       抖音有 106 点 + 3D 拟合，我们的点数少，但"时序平滑"这一课可以补齐。
 *
 * 线程：单个 GccOneEuroBank 只在一个串行队列里用，不加锁。
 */

#include <math.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

/* 抖音官方参数（docs/133）。可在运行时覆盖，但默认值就是官方值。 */
#define GCC_OE_MIN_CUTOFF   1.0f
#define GCC_OE_BETA         0.007f
#define GCC_OE_D_CUTOFF     1.0f
#define GCC_OE_MAX_POINTS   128      /* Vision 76 点，留余量 */

/*
 * ★ 坐标量级对齐（数值仿真定标，见 ios_debug/verify_scale.py）：
 *   官方 oe_beta=0.007 是给【像素坐标】标定的，速度量级几百。
 *   Vision 给的是 0~1 归一化坐标，速度量级 ~0.2 —— 直接套用会让
 *   自适应截止项几乎失效（阶跃跟随 1.50s、慢摆幅度丢 13%）。
 *
 *   我们 shader 本来就用 1024×1024 模板空间。把坐标先乘 1024 再滤波，
 *   量级就与官方像素坐标对齐：跟随 1.10s、慢摆保持 97.8%、抖动仍压 55%。
 *
 *   这样既不动官方三个参数，也不需要另调一套 β。
 */
#define GCC_OE_COORD_SCALE  1024.0f

typedef struct {
    float min_cutoff;
    float beta;
    float d_cutoff;
    float x_prev;       /* 上一次滤波输出 */
    float dx_prev;      /* 上一次导数滤波输出 */
    int   has_prev;     /* 0 = 首帧未初始化 */
    double t_prev;      /* 上一帧时间戳（秒） */
} GccOneEuro;

typedef struct {
    GccOneEuro ch[GCC_OE_MAX_POINTS * 2];  /* 每点 x/y 两路 */
    int   n_ch;                            /* 实际通道数 */
    int   inited;
    float face_conf;      /* 掩膜平滑用：当前人脸置信度 0~1（时间淡入淡出） */
    int   lost_frames;    /* 连续丢帧计数 */
    double last_valid_t;  /* 最后一次有效人脸的时间 */
} GccOneEuroBank;

/* 初始化一批滤波器；n = 坐标分量数（点数×2） */
static inline void gcc_oe_bank_init(GccOneEuroBank *b, int n) {
    if (!b) return;
    memset(b, 0, sizeof(*b));
    if (n > GCC_OE_MAX_POINTS * 2) n = GCC_OE_MAX_POINTS * 2;
    b->n_ch = n;
    for (int i = 0; i < n; i++) {
        b->ch[i].min_cutoff = GCC_OE_MIN_CUTOFF;
        b->ch[i].beta       = GCC_OE_BETA;
        b->ch[i].d_cutoff   = GCC_OE_D_CUTOFF;
    }
    b->inited = 1;
    b->face_conf = 0.0f;
    b->lost_frames = 0;
}

static inline float gcc_oe_alpha(float cutoff, float dt) {
    if (cutoff <= 0.0f || dt <= 0.0f) return 1.0f;
    float tau = 1.0f / (2.0f * 3.14159265358979323846f * cutoff);
    return 1.0f / (1.0f + tau / dt);
}

/* 单路一步。t 单位秒，单调递增。 */
static inline float gcc_oe_step(GccOneEuro *f, float x, double t) {
    if (!f->has_prev) {
        f->x_prev  = x;
        f->dx_prev = 0.0f;
        f->has_prev = 1;
        f->t_prev = t;
        return x;                 /* 首帧直通，避免从 0 爬升 */
    }
    float dt = (float)(t - f->t_prev);
    if (dt <= 0.0f) dt = 1.0f / 30.0f;   /* 时间戳异常兜底 */
    if (dt > 0.25f) dt = 0.25f;           /* 大间隔（切后台）不放大导数 */
    f->t_prev = t;

    /* 1) 导数 + 导数低通 */
    float dx = (x - f->x_prev) / dt;
    float a_d = gcc_oe_alpha(f->d_cutoff, dt);
    float dx_hat = a_d * dx + (1.0f - a_d) * f->dx_prev;
    f->dx_prev = dx_hat;

    /* 2) 自适应截止频率：速度越快，截止越高 → 延迟越低 */
    float cutoff = f->min_cutoff + f->beta * fabsf(dx_hat);

    /* 3) 值低通 */
    float a = gcc_oe_alpha(cutoff, dt);
    float x_hat = a * x + (1.0f - a) * f->x_prev;
    f->x_prev = x_hat;
    return x_hat;
}

/*
 * 对一整帧关键点做滤波。
 *   in/out : 交错 (x,y) float 数组，可同一块内存（原地）
 *   n      : float 个数（点数×2）
 *   t      : 当前时间戳（秒）
 * 返回：滤波后的分量数
 */
static inline int gcc_oe_bank_apply(GccOneEuroBank *b,
                                    const float *in, float *out,
                                    int n, double t) {
    if (!b || !b->inited || !in || !out || n <= 0) return 0;
    if (n > b->n_ch) n = b->n_ch;
    if (n > GCC_OE_MAX_POINTS * 2) n = GCC_OE_MAX_POINTS * 2;
    /* 在模板空间滤波（量级与官方像素坐标对齐），输出再缩回归一化 */
    for (int i = 0; i < n; i++) {
        float xs = in[i] * GCC_OE_COORD_SCALE;
        float ys = gcc_oe_step(&b->ch[i], xs, t);
        out[i] = ys / GCC_OE_COORD_SCALE;
    }
    return n;
}

/* 人脸重新出现 / 长时间丢失后重置，避免旧状态把新脸拉偏 */
static inline void gcc_oe_bank_reset(GccOneEuroBank *b) {
    if (!b) return;
    int n = b->n_ch;
    gcc_oe_bank_init(b, n);
}

/* ------------------------------------------------------------------ *
 * 掩膜平滑（时间维度）
 *
 * docs/133 理论依据：「蒙版抖动 = 关键点逐帧抖动经掩膜放大」。
 * 除了一维滤波，还要在「人脸出现/消失」时做淡入淡出，
 * 否则 mask 会硬切 → 额头「会动的波纹」/黑贴纸。
 *
 * 官方参数：smooth_window_size=5, facemask_smooth_type=1,
 *           enable_face_anti_aliasing=1, enable_face_smooth=1
 * 这里用 5 帧线性淡入（对应 window=5），淡出按 2 倍（更保守）。
 * ------------------------------------------------------------------ */
#define GCC_FACE_FADE_IN   5
#define GCC_FACE_FADE_OUT  10

static inline float gcc_face_conf_on_found(GccOneEuroBank *b) {
    b->lost_frames = 0;
    float c = b->face_conf + 1.0f / (float)GCC_FACE_FADE_IN;
    if (c > 1.0f) c = 1.0f;
    b->face_conf = c;
    return c;
}

static inline float gcc_face_conf_on_lost(GccOneEuroBank *b) {
    b->lost_frames++;
    float c = b->face_conf - 1.0f / (float)GCC_FACE_FADE_OUT;
    if (c < 0.0f) c = 0.0f;
    b->face_conf = c;
    return c;
}

#ifdef __cplusplus
}
#endif

#endif /* GCC_ONE_EURO_H */
