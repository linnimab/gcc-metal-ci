#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct buffer_t
{
    float _Ratio;
    float4 _AlbedoColor;
    float4 _AlbedoColor2;
    int _GradientType;
};

struct main0_out
{
    float4 o_fragColor [[color(0)]];
};

struct main0_in
{
    float2 g_vary_uv0 [[user(locn0)]];
    float indexRatio [[user(locn1)]];
};

fragment main0_out main0(main0_in in [[stage_in]], constant buffer_t& buffer, texture2d<float> _AlbedoTexture [[texture(0)]], sampler _AlbedoTextureSmplr [[sampler(0)]])
{
    main0_out out = {};
    float2 _144;
    if (buffer._Ratio < 1.0)
    {
        float2 _133 = in.g_vary_uv0;
        _133.x = ((in.g_vary_uv0.x - 0.5) / buffer._Ratio) + 0.5;
        _144 = _133;
    }
    else
    {
        float2 _136 = in.g_vary_uv0;
        _136.y = fma(in.g_vary_uv0.y - 0.5, buffer._Ratio, 0.5);
        _144 = _136;
    }
    float4 _146;
    if (buffer._GradientType == 1)
    {
        _146 = mix(buffer._AlbedoColor, buffer._AlbedoColor2, float4(in.indexRatio));
    }
    else
    {
        float4 _147;
        if (in.indexRatio <= 0.5)
        {
            _147 = mix(buffer._AlbedoColor, buffer._AlbedoColor2, float4(in.indexRatio * 2.0));
        }
        else
        {
            _147 = mix(buffer._AlbedoColor2, buffer._AlbedoColor, float4((in.indexRatio - 0.5) * 2.0));
        }
        _146 = _147;
    }
    float4 _96 = _AlbedoTexture.sample(_AlbedoTextureSmplr, _144);
    float4 _98 = _96 * _146;
    bool _102 = _144.x < 0.0;
    bool _109;
    if (!_102)
    {
        _109 = _144.x > 1.0;
    }
    else
    {
        _109 = _102;
    }
    bool _116;
    if (!_109)
    {
        _116 = _144.y < 0.0;
    }
    else
    {
        _116 = _109;
    }
    bool _123;
    if (!_116)
    {
        _123 = _144.y > 1.0;
    }
    else
    {
        _123 = _116;
    }
    float4 _153;
    if (_123)
    {
        float4 _142 = _98;
        _142.w = 0.0;
        _153 = _142;
    }
    else
    {
        _153 = _98;
    }
    out.o_fragColor = _153;
    return out;
}

