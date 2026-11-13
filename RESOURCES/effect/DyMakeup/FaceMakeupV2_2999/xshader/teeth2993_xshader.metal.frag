#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct buffer_t
{
    int openMouth;
    float intensity;
    float opacity;
};

struct main0_out
{
    float4 o_FragColor [[color(0)]];
};

struct main0_in
{
    float2 sucaiTexCoord [[user(sucaiTexCoord)]];
    float2 segCoord [[user(segCoord)]];
};

fragment main0_out main0(main0_in in [[stage_in]], constant buffer_t& buffer, float4 subpassColor0 [[color(0)]], texture2d<float> lutImageTexture [[texture(0)]], texture2d<float> maskImageTexture [[texture(1)]], texture2d<float> segMaskTexture [[texture(2)]], sampler lutImageTextureSmplr [[sampler(0)]], sampler maskImageTextureSmplr [[sampler(1)]], sampler segMaskTextureSmplr [[sampler(2)]])
{
    main0_out out = {};
    float4 _211 = subpassColor0;
    if (buffer.openMouth < 1)
    {
        out.o_FragColor = _211;
    }
    else
    {
        float _225 = float(half4(_211).z) * 15.0;
        float _227 = floor(_225);
        float _231 = fast::max(fast::min(4.0, floor(_227 * 0.25)), 0.0);
        float _243 = ceil(_225);
        float _247 = fast::max(fast::min(floor(_243 * 0.25), 4.0), 0.0);
        half4 _350 = half4(_211);
        half _263 = _350.x;
        half4 _352 = half4(_211);
        half _272 = _352.y;
        out.o_FragColor = mix(_211, mix(_211, mix(_211, mix(lutImageTexture.sample(lutImageTextureSmplr, float2(half2(half(fma(0.234375, float(_263), fma(fast::max(fast::min(4.0, fma(-_231, 4.0, _227)), 0.0), 0.25, 0.0078125))), half(fma(0.234375, float(_272), fma(_231, 0.25, 0.0078125)))))), lutImageTexture.sample(lutImageTextureSmplr, float2(half2(half(fma(0.234375, float(_263), fma(fast::max(fast::min(fma(-_247, 4.0, _243), 4.0), 0.0), 0.25, 0.0078125))), half(fma(0.234375, float(_272), fma(_247, 0.25, 0.0078125)))))), float4(fract(_225))), float4(half4(half4(maskImageTexture.sample(maskImageTextureSmplr, in.sucaiTexCoord)).z))), float4(any(fast::clamp(in.segCoord, float2(0.0), float2(1.0)) != in.segCoord) ? 1.0 : float(half4(segMaskTexture.sample(segMaskTextureSmplr, in.segCoord)).x))), float4(buffer.intensity * buffer.opacity));
    }
    return out;
}

