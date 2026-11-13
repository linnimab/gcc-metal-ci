#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct buffer_t
{
    float4 u_color;
    float u_opacity;
};

struct main0_out
{
    float4 o_fragColor [[color(0)]];
};

struct main0_in
{
    float2 v_texCoord [[user(locn0)]];
};

fragment main0_out main0(main0_in in [[stage_in]], constant buffer_t& buffer, texture2d<float> _MainTex [[texture(0)]], sampler _MainTexSmplr [[sampler(0)]])
{
    main0_out out = {};
    float4 _43 = _MainTex.sample(_MainTexSmplr, in.v_texCoord) * buffer.u_color;
    float4 _85 = _43;
    _85.w = _43.w * buffer.u_opacity;
    out.o_fragColor = _85;
    return out;
}

