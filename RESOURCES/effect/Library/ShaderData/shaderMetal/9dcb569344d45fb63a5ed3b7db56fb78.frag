#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct buffer_t
{
    int openMouth;
    float _Intensity;
    float _Opacity;
    float _EnableOpacity;
    float4 _BaseColor;
};

struct main0_out
{
    float4 o_FragColor [[color(0)]];
};

struct main0_in
{
    float2 v2f_materialTexCoord [[user(locn0)]];
};

fragment main0_out main0(main0_in in [[stage_in]], constant buffer_t& buffer, texture2d<float> _BaseTexture [[texture(0)]], texture2d<float> _MaskTexture [[texture(1)]], texture2d<float> _OpacityTexture [[texture(2)]], sampler _BaseTextureSmplr [[sampler(0)]], sampler _MaskTextureSmplr [[sampler(1)]], sampler _OpacityTextureSmplr [[sampler(2)]])
{
    main0_out out = {};
    float4 _188 = _BaseTexture.sample(_BaseTextureSmplr, in.v2f_materialTexCoord);
    float4 _254 = _188;
    _254.w = _188.w * (((buffer.openMouth > 0) ? _MaskTexture.sample(_MaskTextureSmplr, in.v2f_materialTexCoord).x : 1.0) * fast::clamp(buffer._Intensity * buffer._Opacity, 0.0, 1.0));
    float4 _259;
    if (buffer._EnableOpacity > 0.5)
    {
        float4 _219 = _254 * buffer._BaseColor;
        float4 _258 = _219;
        _258.w = _219.w * _OpacityTexture.sample(_OpacityTextureSmplr, in.v2f_materialTexCoord).x;
        _259 = _258;
    }
    else
    {
        _259 = _254;
    }
    out.o_FragColor = _259;
    return out;
}

