#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct buffer_t
{
    float _Intensity;
    float _Opacity;
    float _EnableOpacity;
    float4 _BaseColor;
    float _EnableReflection;
    float _ReflectionIntensity;
    float _ReflectionOpacity;
};

struct main0_out
{
    float4 o_FragColor [[color(0)]];
};

struct main0_in
{
    float2 texCoord [[user(locn0)]];
    float2 sucaiTexCoord [[user(locn1)]];
    float weight [[user(locn2)]];
};

fragment main0_out main0(main0_in in [[stage_in]], constant buffer_t& buffer, texture2d<float> _InputTexture [[texture(0)]], texture2d<float> _BaseTexture [[texture(1)]], texture2d<float> _OpacityTexture [[texture(2)]], texture2d<float> _ReflectionTexture [[texture(3)]], sampler _InputTextureSmplr [[sampler(0)]], sampler _BaseTextureSmplr [[sampler(1)]], sampler _OpacityTextureSmplr [[sampler(2)]], sampler _ReflectionTextureSmplr [[sampler(3)]])
{
    main0_out out = {};
    float4 _119 = _InputTexture.sample(_InputTextureSmplr, in.texCoord);
    float4 _125 = _BaseTexture.sample(_BaseTextureSmplr, in.sucaiTexCoord);
    float4 _292 = _125;
    _292.w = _125.w * fast::clamp(buffer._Intensity * buffer._Opacity, 0.0, 1.0);
    float4 _303;
    if (buffer._EnableOpacity > 0.5)
    {
        float4 _156 = _292 * buffer._BaseColor;
        float4 _296 = _156;
        _296.w = _156.w * _OpacityTexture.sample(_OpacityTextureSmplr, in.sucaiTexCoord).x;
        _303 = _296;
    }
    else
    {
        _303 = _292;
    }
    float3 _166 = _119.xyz;
    float3 _250 = (fma(_166 - float3(1.0), float3(1.0) - _303.xyz, float3(1.0)) * (_303.w * in.weight)) + (_166 * fma(-_303.w, in.weight, 1.0));
    float3 _304;
    if (buffer._EnableReflection > 0.5)
    {
        float4 _192 = _ReflectionTexture.sample(_ReflectionTextureSmplr, in.sucaiTexCoord);
        float _201 = _192.w * fast::clamp(buffer._ReflectionIntensity * buffer._ReflectionOpacity, 0.0, 1.0);
        _304 = ((_250 * _192.xyz) * (_201 * in.weight)) + (_250 * fma(-_201, in.weight, 1.0));
    }
    else
    {
        _304 = _250;
    }
    out.o_FragColor = float4(_304, _119.w);
    return out;
}

