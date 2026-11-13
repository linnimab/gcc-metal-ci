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
    float2 segCoord [[user(segCoord)]];
};

fragment main0_out main0(main0_in in [[stage_in]], constant buffer_t& buffer, float4 subpassColor0 [[color(0)]], texture2d<float> sucaiImageTexture [[texture(0)]], texture2d<float> segMaskTexture [[texture(1)]], sampler sucaiImageTextureSmplr [[sampler(0)]], sampler segMaskTextureSmplr [[sampler(1)]])
{
    main0_out out = {};
    float4 _160 = subpassColor0;
    float4 _59 = sucaiImageTexture.sample(sucaiImageTextureSmplr, in.sucaiTexCoord) * fast::clamp(buffer.intensity * buffer.opacity, 0.0, 1.0);
    half4 _184 = half4(_160);
    half _65 = _184.w;
    float _75 = _59.w;
    float3 _90 = fast::clamp(float3(half4(_160).xyz) / float3(half3(fma(step(half(0.0), -_65), half(9.9999999747524270787835121154785e-07), _65))), float3(0.0), float3(1.0));
    float _119 = fma(_75, float(half(1.0) - _65), float(_65));
    out.o_FragColor = float4(mix(_90, mix(_90, _90 * fast::clamp(_59.xyz / float3(fma(step(0.0, -_75), 9.9999999747524270787835121154785e-07, _75)), float3(0.0), float3(1.0)), float3(_75)), float3(any(fast::clamp(in.segCoord, float2(0.0), float2(1.0)) != in.segCoord) ? 1.0 : float(half4(segMaskTexture.sample(segMaskTextureSmplr, in.segCoord)).x))) * _119, _119);
    return out;
}

