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

constant float4 _508 = {};

struct main0_out
{
    float4 o_FragColor [[color(0)]];
};

struct main0_in
{
    float2 v2f_materialTexCoord [[user(locn0)]];
};

fragment main0_out main0(main0_in in [[stage_in]], constant buffer_t& buffer, float4 subpass0 [[color(0)]], texture2d<float> _BaseTexture [[texture(0)]], texture2d<float> _OpacityTexture [[texture(1)]], sampler _BaseTextureSmplr [[sampler(0)]], sampler _OpacityTextureSmplr [[sampler(1)]])
{
    main0_out out = {};
    float4 _275 = _BaseTexture.sample(_BaseTextureSmplr, in.v2f_materialTexCoord);
    float4 _472 = _275;
    _472.w = _275.w * fast::clamp(buffer._Intensity * buffer._Opacity, 0.0, 1.0);
    float4 _498;
    if (buffer._EnableOpacity > 0.5)
    {
        float4 _295 = _472 * buffer._BaseColor;
        float4 _476 = _295;
        _476.w = _295.w * _OpacityTexture.sample(_OpacityTextureSmplr, in.v2f_materialTexCoord).x;
        _498 = _476;
    }
    else
    {
        _498 = _472;
    }
    float4 _317 = subpass0;
    float _354 = _317.x;
    float _374 = 2.0 * _354;
    float _359 = _317.y;
    float _403 = 2.0 * _359;
    float _364 = _317.z;
    float _432 = 2.0 * _364;
    float4 _484 = _508;
    _484.x = (_498.x < 0.5) ? fma(_374, _498.x, (_354 * _354) * fma(-2.0, _498.x, 1.0)) : fma(sqrt(_354), fma(2.0, _498.x, -1.0), _374 * (1.0 - _498.x));
    float4 _486 = _484;
    _486.y = (_498.y < 0.5) ? fma(_403, _498.y, (_359 * _359) * fma(-2.0, _498.y, 1.0)) : fma(sqrt(_359), fma(2.0, _498.y, -1.0), _403 * (1.0 - _498.y));
    float4 _488 = _486;
    _488.z = (_498.z < 0.5) ? fma(_432, _498.z, (_364 * _364) * fma(-2.0, _498.z, 1.0)) : fma(sqrt(_364), fma(2.0, _498.z, -1.0), _432 * (1.0 - _498.z));
    out.o_FragColor = float4(mix(_317.xyz, _488.xyz, float3(_498.w)), 1.0);
    return out;
}

