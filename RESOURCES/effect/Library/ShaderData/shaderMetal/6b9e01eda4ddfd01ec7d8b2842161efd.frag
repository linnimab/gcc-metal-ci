#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct buffer_t
{
    int openMouth;
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
    float2 v2f_segCoord [[user(locn2)]];
};

fragment main0_out main0(main0_in in [[stage_in]], constant buffer_t& buffer, texture2d<float> _BaseTexture [[texture(0)]], texture2d<float> _MaskTexture [[texture(1)]], texture2d<float> _OpacityTexture [[texture(2)]], texture2d<float> segMaskTexture [[texture(3)]], sampler _BaseTextureSmplr [[sampler(0)]], sampler _MaskTextureSmplr [[sampler(1)]], sampler _OpacityTextureSmplr [[sampler(2)]], sampler segMaskTextureSmplr [[sampler(3)]])
{
    main0_out out = {};
    float4 _255 = _BaseTexture.sample(_BaseTextureSmplr, in.v2f_materialTexCoord);
    float4 _375 = _255;
    _375.w = _255.w * (((buffer.openMouth > 0) ? _MaskTexture.sample(_MaskTextureSmplr, in.v2f_materialTexCoord).x : 1.0) * fast::clamp(buffer._Intensity * buffer._Opacity, 0.0, 1.0));
    float4 _396;
    if (buffer._EnableOpacity > 0.5)
    {
        float4 _286 = _375 * buffer._BaseColor;
        float4 _379 = _286;
        _379.w = _286.w * _OpacityTexture.sample(_OpacityTextureSmplr, in.v2f_materialTexCoord).x;
        _396 = _379;
    }
    else
    {
        _396 = _375;
    }
    float _320 = _396.w * (((fast::clamp(in.v2f_segCoord.x, 0.0, 1.0) != in.v2f_segCoord.x) || (fast::clamp(in.v2f_segCoord.y, 0.0, 1.0) != in.v2f_segCoord.y)) ? 1.0 : segMaskTexture.sample(segMaskTextureSmplr, in.v2f_segCoord).x);
    out.o_FragColor = float4(((_396.xyz * _320) + float3(1.0)) - float3(_320), _320);
    return out;
}

