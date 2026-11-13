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
    float4 _202 = _BaseTexture.sample(_BaseTextureSmplr, in.v2f_materialTexCoord);
    float4 _279 = _202;
    _279.w = _202.w * fast::clamp(buffer._Intensity * buffer._Opacity, 0.0, 1.0);
    float4 _292;
    if (buffer._EnableOpacity > 0.5)
    {
        float4 _222 = _279 * buffer._BaseColor;
        float4 _283 = _222;
        _283.w = _222.w * _OpacityTexture.sample(_OpacityTextureSmplr, in.v2f_materialTexCoord).x;
        _292 = _283;
    }
    else
    {
        _292 = _279;
    }
    float3 _262 = ((_292.xyz * _292.w) + float3(1.0)) - float3(_292.w);
    float4 _287 = _292;
    _287.x = _262.x;
    float4 _289 = _287;
    _289.y = _262.y;
    float4 _291 = _289;
    _291.z = _262.z;
    out.o_FragColor = _291;
    return out;
}

