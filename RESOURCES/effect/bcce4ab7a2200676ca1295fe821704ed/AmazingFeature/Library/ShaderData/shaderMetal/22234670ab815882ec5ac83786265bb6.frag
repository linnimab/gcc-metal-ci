#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct buffer_t
{
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

fragment main0_out main0(main0_in in [[stage_in]], constant buffer_t& buffer, texture2d<float> _BaseTexture [[texture(0)]], texture2d<float> _OpacityTexture [[texture(1)]], sampler _BaseTextureSmplr [[sampler(0)]], sampler _OpacityTextureSmplr [[sampler(1)]])
{
    main0_out out = {};
    float4 _174 = _BaseTexture.sample(_BaseTextureSmplr, in.v2f_materialTexCoord);
    float4 _229 = _174;
    _229.w = _174.w * fast::clamp(buffer._Intensity * buffer._Opacity, 0.0, 1.0);
    float4 _234;
    if (buffer._EnableOpacity > 0.5)
    {
        float4 _194 = _229 * buffer._BaseColor;
        float4 _233 = _194;
        _233.w = _194.w * _OpacityTexture.sample(_OpacityTextureSmplr, in.v2f_materialTexCoord).x;
        _234 = _233;
    }
    else
    {
        _234 = _229;
    }
    out.o_FragColor = _234;
    return out;
}

