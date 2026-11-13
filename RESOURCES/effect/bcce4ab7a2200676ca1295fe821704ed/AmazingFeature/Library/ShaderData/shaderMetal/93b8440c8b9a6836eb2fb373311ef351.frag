#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct main0_out
{
    float4 o_fragColor [[color(0)]];
};

struct main0_in
{
    float2 textureCoordinate [[user(locn0)]];
};

fragment main0_out main0(main0_in in [[stage_in]], texture2d<float> maskTexture [[texture(0)]], sampler maskTextureSmplr [[sampler(0)]])
{
    main0_out out = {};
    out.o_fragColor = float4(maskTexture.sample(maskTextureSmplr, in.textureCoordinate).xyz, 1.0);
    return out;
}

