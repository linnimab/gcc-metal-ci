#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct buffer_t
{
    int openMouth;
    float _Intensity;
    float _Opacity;
};

struct main0_out
{
    float4 o_FragColor [[color(0)]];
};

struct main0_in
{
    float2 v2f_materialTexCoord [[user(locn0)]];
};

fragment main0_out main0(main0_in in [[stage_in]], constant buffer_t& buffer, float4 subpass0 [[color(0)]], texture2d<float> _LutTexture [[texture(0)]], texture2d<float> _MaskTexture [[texture(1)]], sampler _LutTextureSmplr [[sampler(0)]], sampler _MaskTextureSmplr [[sampler(1)]])
{
    main0_out out = {};
    float4 _208 = subpass0;
    float4 _335;
    if (buffer.openMouth > 0)
    {
        float _214 = _208.z * 63.0;
        float _216 = floor(_214);
        float _218 = ceil(_214);
        float _222 = fast::clamp(floor(_216 * 0.125), 0.0, 8.0);
        float _234 = fast::clamp(floor(_218 * 0.125), 0.0, 8.0);
        float2 _247 = float2(0.0009765625) + (_208.xy * 0.123046875);
        float2 _251 = (float2(fast::clamp(fma(-_222, 8.0, _216), 0.0, 8.0), _222) * 0.125) + _247;
        float2 _330 = _251;
        _330.y = 1.0 - _251.y;
        float2 _259 = (float2(fast::clamp(fma(-_234, 8.0, _218), 0.0, 8.0), _234) * 0.125) + _247;
        float2 _333 = _259;
        _333.y = 1.0 - _259.y;
        _335 = mix(_208, mix(_LutTexture.sample(_LutTextureSmplr, _330), _LutTexture.sample(_LutTextureSmplr, _333), float4(fract(_214))), float4(_MaskTexture.sample(_MaskTextureSmplr, in.v2f_materialTexCoord).x * fast::clamp(buffer._Intensity * buffer._Opacity, 0.0, 1.0)));
    }
    else
    {
        _335 = _208;
    }
    out.o_FragColor = _335;
    return out;
}

