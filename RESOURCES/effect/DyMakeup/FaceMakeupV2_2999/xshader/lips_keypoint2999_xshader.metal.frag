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
    float4 _213 = subpassColor0;
    float4 _150 = maskImageTexture.sample(maskImageTextureSmplr, in.sucaiTexCoord);
    half _340;
    if (buffer.openMouth > 0)
    {
        _340 = half4(_150).y;
    }
    else
    {
        _340 = half4(_150).x;
    }
    float _229 = float(half4(_213).z) * 15.0;
    float _231 = floor(_229);
    float _236 = fast::max(fast::min(4.0, floor(_231 * 0.25)), 0.0);
    float _247 = ceil(_229);
    float _252 = fast::max(fast::min(floor(_247 * 0.25), 4.0), 0.0);
    half4 _363 = half4(_213);
    half _267 = _363.x;
    half4 _365 = half4(_213);
    half _276 = _365.y;
    out.o_FragColor = mix(_213, mix(_213, mix(lutImageTexture.sample(lutImageTextureSmplr, float2(half2(half(fma(0.234375, float(_267), fma(fast::max(fast::min(4.0, fma(-_236, 4.0, _231)), 0.0), 0.25, 0.0078125))), half(fma(0.234375, float(_276), fma(_236, 0.25, 0.0078125)))))), lutImageTexture.sample(lutImageTextureSmplr, float2(half2(half(fma(0.234375, float(_267), fma(fast::max(fast::min(fma(-_252, 4.0, _247), 4.0), 0.0), 0.25, 0.0078125))), half(fma(0.234375, float(_276), fma(_252, 0.25, 0.0078125)))))), float4(fract(_229))), float4(any(fast::clamp(in.segCoord, float2(0.0), float2(1.0)) != in.segCoord) ? 1.0 : float(half4(segMaskTexture.sample(segMaskTextureSmplr, in.segCoord)).x))), float4((float(_340) * buffer.intensity) * buffer.opacity));
    return out;
}

