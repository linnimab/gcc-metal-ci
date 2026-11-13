#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct buffer_t
{
    float intensity;
    float opacity;
};

struct main0_out
{
    float4 o_FragColor [[color(0)]];
};

struct main0_in
{
    float2 sucaiTexCoord [[user(sucaiTexCoord)]];
};

fragment main0_out main0(main0_in in [[stage_in]], constant buffer_t& buffer, float4 subpassColor0 [[color(0)]], texture2d<float> sucaiImageTexture [[texture(0)]], sampler sucaiImageTextureSmplr [[sampler(0)]])
{
    main0_out out = {};
    float4 _199 = subpassColor0;
    float4 _115 = sucaiImageTexture.sample(sucaiImageTextureSmplr, in.sucaiTexCoord);
    float4 _124 = _115 * fast::clamp(buffer.intensity * buffer.opacity, 0.0, 1.0);
    half4 _353 = half4(_199);
    half _128 = _353.w;
    float _138 = _124.w;
    float3 _153 = fast::clamp(float3(half4(_199).xyz) / float3(half3(fma(step(half(0.0), -_128), half(9.9999999747524270787835121154785e-07), _128))), float3(0.0), float3(1.0));
    float3 _162 = fast::clamp(_124.xyz / float3(fma(step(0.0, -_138), 9.9999999747524270787835121154785e-07, _138)), float3(0.0), float3(1.0));
    float _210 = _153.x;
    float _212 = _162.x;
    float _338;
    if (_212 < 0.5)
    {
        _338 = fma(2.0 * _210, _212, (_210 * _210) * fma(-2.0, _212, 1.0));
    }
    else
    {
        _338 = fma(sqrt(_210), fma(2.0, _212, -1.0), (2.0 * _210) * (1.0 - _212));
    }
    float _215 = _153.y;
    float _217 = _162.y;
    float _339;
    if (_217 < 0.5)
    {
        _339 = fma(2.0 * _215, _217, (_215 * _215) * fma(-2.0, _217, 1.0));
    }
    else
    {
        _339 = fma(sqrt(_215), fma(2.0, _217, -1.0), (2.0 * _215) * (1.0 - _217));
    }
    float _220 = _153.z;
    float _222 = _162.z;
    float _340;
    if (_222 < 0.5)
    {
        _340 = fma(2.0 * _220, _222, (_220 * _220) * fma(-2.0, _222, 1.0));
    }
    else
    {
        _340 = fma(sqrt(_220), fma(2.0, _222, -1.0), (2.0 * _220) * (1.0 - _222));
    }
    float _182 = fma(_138, float(half(1.0) - _128), float(_128));
    out.o_FragColor = float4(mix(_153, float3(_338, _339, _340), float3(_138)) * _182, _182);
    return out;
}

