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
    float4 _173 = _BaseTexture.sample(_BaseTextureSmplr, in.v2f_materialTexCoord);
    float4 _228 = _173;
    _228.w = _173.w * fast::clamp(buffer._Intensity * buffer._Opacity, 0.0, 1.0);
    float4 _233;
    if (buffer._EnableOpacity > 0.5)
    {
        float4 _193 = _228 * buffer._BaseColor;
        float4 _232 = _193;
        _232.w = _193.w * _OpacityTexture.sample(_OpacityTextureSmplr, in.v2f_materialTexCoord).x;
        _233 = _232;
    }
    else
    {
        _233 = _228;
    }
    out.o_FragColor = _233;
    return out;
}

