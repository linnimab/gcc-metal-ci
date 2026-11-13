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
    float4 _48 = _InputTexture.sample(_InputTextureSmplr, in.texCoord);
    float4 _54 = _BaseTexture.sample(_BaseTextureSmplr, in.sucaiTexCoord);
    float4 _172 = _54;
    _172.w = _54.w * fast::clamp(buffer._Intensity * buffer._Opacity, 0.0, 1.0);
    float4 _182;
    if (buffer._EnableOpacity > 0.5)
    {
        float4 _86 = _172 * buffer._BaseColor;
        float4 _176 = _86;
        _176.w = _86.w * _OpacityTexture.sample(_OpacityTextureSmplr, in.sucaiTexCoord).x;
        _182 = _176;
    }
    else
    {
        _182 = _172;
    }
    float3 _183;
    if (buffer._EnableReflection > 0.5)
    {
        _183 = _ReflectionTexture.sample(_ReflectionTextureSmplr, in.sucaiTexCoord).xyz;
    }
    else
    {
        _183 = mix(_48.xyz, _182.xyz, float3(_182.w * in.weight));
    }
    out.o_FragColor = float4(_183, _48.w);
    return out;
}

