#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct buffer_t
{
    float _MaskMinCoord;
    float _MaskMaxCoord;
};

struct main0_out
{
    float4 o_FragColor [[color(0)]];
};

struct main0_in
{
    float2 texCoord [[user(locn0)]];
    float2 maskTexCoord [[user(locn1)]];
};

fragment main0_out main0(main0_in in [[stage_in]], constant buffer_t& buffer, texture2d<float> inputImageTexture [[texture(0)]], texture2d<float> _MaskTexture [[texture(1)]], sampler inputImageTextureSmplr [[sampler(0)]], sampler _MaskTextureSmplr [[sampler(1)]])
{
    main0_out out = {};
    out.o_FragColor = ((inputImageTexture.sample(inputImageTextureSmplr, in.texCoord) * _MaskTexture.sample(_MaskTextureSmplr, in.maskTexCoord).x) * step(buffer._MaskMinCoord, in.maskTexCoord.x)) * step(in.maskTexCoord.x, buffer._MaskMaxCoord);
    return out;
}

