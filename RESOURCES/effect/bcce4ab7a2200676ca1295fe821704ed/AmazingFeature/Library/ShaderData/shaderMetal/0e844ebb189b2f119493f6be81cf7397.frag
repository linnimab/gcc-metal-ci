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
    float2 v2f_texCoord [[user(locn1)]];
};

fragment main0_out main0(main0_in in [[stage_in]], constant buffer_t& buffer, texture2d<float> u_FBOTexture [[texture(0)]], texture2d<float> _LutTexture [[texture(1)]], texture2d<float> _MaskTexture [[texture(2)]], sampler u_FBOTextureSmplr [[sampler(0)]], sampler _LutTextureSmplr [[sampler(1)]], sampler _MaskTextureSmplr [[sampler(2)]])
{
    main0_out out = {};
    float4 _213 = u_FBOTexture.sample(u_FBOTextureSmplr, in.v2f_texCoord);
    float4 _341;
    if (buffer.openMouth > 0)
    {
        float _219 = _213.z * 63.0;
        float _221 = floor(_219);
        float _223 = ceil(_219);
        float _227 = fast::clamp(floor(_221 * 0.125), 0.0, 8.0);
        float _239 = fast::clamp(floor(_223 * 0.125), 0.0, 8.0);
        float2 _252 = float2(0.0009765625) + (_213.xy * 0.123046875);
        float2 _256 = (float2(fast::clamp(fma(-_227, 8.0, _221), 0.0, 8.0), _227) * 0.125) + _252;
        float2 _336 = _256;
        _336.y = 1.0 - _256.y;
        float2 _264 = (float2(fast::clamp(fma(-_239, 8.0, _223), 0.0, 8.0), _239) * 0.125) + _252;
        float2 _339 = _264;
        _339.y = 1.0 - _264.y;
        _341 = mix(_213, mix(_LutTexture.sample(_LutTextureSmplr, _336), _LutTexture.sample(_LutTextureSmplr, _339), float4(fract(_219))), float4(_MaskTexture.sample(_MaskTextureSmplr, in.v2f_materialTexCoord).x * fast::clamp(buffer._Intensity * buffer._Opacity, 0.0, 1.0)));
    }
    else
    {
        _341 = _213;
    }
    out.o_FragColor = _341;
    return out;
}

