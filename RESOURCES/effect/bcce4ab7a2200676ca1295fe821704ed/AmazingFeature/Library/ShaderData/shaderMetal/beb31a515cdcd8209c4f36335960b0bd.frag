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

constant float4 _512 = {};

struct main0_out
{
    float4 o_FragColor [[color(0)]];
};

struct main0_in
{
    float2 v2f_materialTexCoord [[user(locn0)]];
    float2 v2f_texCoord [[user(locn1)]];
};

fragment main0_out main0(main0_in in [[stage_in]], constant buffer_t& buffer, texture2d<float> u_FBOTexture [[texture(0)]], texture2d<float> _BaseTexture [[texture(1)]], texture2d<float> _OpacityTexture [[texture(2)]], sampler u_FBOTextureSmplr [[sampler(0)]], sampler _BaseTextureSmplr [[sampler(1)]], sampler _OpacityTextureSmplr [[sampler(2)]])
{
    main0_out out = {};
    float4 _275 = _BaseTexture.sample(_BaseTextureSmplr, in.v2f_materialTexCoord);
    float4 _476 = _275;
    _476.w = _275.w * fast::clamp(buffer._Intensity * buffer._Opacity, 0.0, 1.0);
    float4 _502;
    if (buffer._EnableOpacity > 0.5)
    {
        float4 _295 = _476 * buffer._BaseColor;
        float4 _480 = _295;
        _480.w = _295.w * _OpacityTexture.sample(_OpacityTextureSmplr, in.v2f_materialTexCoord).x;
        _502 = _480;
    }
    else
    {
        _502 = _476;
    }
    float4 _320 = u_FBOTexture.sample(u_FBOTextureSmplr, in.v2f_texCoord);
    float _357 = _320.x;
    float _377 = 2.0 * _357;
    float _362 = _320.y;
    float _406 = 2.0 * _362;
    float _367 = _320.z;
    float _435 = 2.0 * _367;
    float4 _488 = _512;
    _488.x = (_502.x < 0.5) ? fma(_377, _502.x, (_357 * _357) * fma(-2.0, _502.x, 1.0)) : fma(sqrt(_357), fma(2.0, _502.x, -1.0), _377 * (1.0 - _502.x));
    float4 _490 = _488;
    _490.y = (_502.y < 0.5) ? fma(_406, _502.y, (_362 * _362) * fma(-2.0, _502.y, 1.0)) : fma(sqrt(_362), fma(2.0, _502.y, -1.0), _406 * (1.0 - _502.y));
    float4 _492 = _490;
    _492.z = (_502.z < 0.5) ? fma(_435, _502.z, (_367 * _367) * fma(-2.0, _502.z, 1.0)) : fma(sqrt(_367), fma(2.0, _502.z, -1.0), _435 * (1.0 - _502.z));
    out.o_FragColor = float4(mix(_320.xyz, _492.xyz, float3(_502.w)), 1.0);
    return out;
}

