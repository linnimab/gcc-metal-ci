#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct main0_out
{
    float4 o_fragColor [[color(0)]];
};

struct main0_in
{
    float2 varUV [[user(locn0)]];
};

fragment main0_out main0(main0_in in [[stage_in]], texture2d<float> _MainTex [[texture(0)]], sampler _MainTexSmplr [[sampler(0)]])
{
    main0_out out = {};
    out.o_fragColor = _MainTex.sample(_MainTexSmplr, in.varUV);
    return out;
}

