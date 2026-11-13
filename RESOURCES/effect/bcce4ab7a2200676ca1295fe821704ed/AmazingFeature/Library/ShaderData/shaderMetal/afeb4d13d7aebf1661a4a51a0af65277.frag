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
    float4 _203 = _BaseTexture.sample(_BaseTextureSmplr, in.v2f_materialTexCoord);
    float4 _280 = _203;
    _280.w = _203.w * fast::clamp(buffer._Intensity * buffer._Opacity, 0.0, 1.0);
    float4 _293;
    if (buffer._EnableOpacity > 0.5)
    {
        float4 _223 = _280 * buffer._BaseColor;
        float4 _284 = _223;
        _284.w = _223.w * _OpacityTexture.sample(_OpacityTextureSmplr, in.v2f_materialTexCoord).x;
        _293 = _284;
    }
    else
    {
        _293 = _280;
    }
    float3 _263 = ((_293.xyz * _293.w) + float3(1.0)) - float3(_293.w);
    float4 _288 = _293;
    _288.x = _263.x;
    float4 _290 = _288;
    _290.y = _263.y;
    float4 _292 = _290;
    _292.z = _263.z;
    out.o_FragColor = _292;
    return out;
}

