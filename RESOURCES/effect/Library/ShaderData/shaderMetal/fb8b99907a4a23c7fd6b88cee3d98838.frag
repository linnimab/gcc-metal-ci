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

fragment main0_out main0(main0_in in [[stage_in]], texture2d<float> inputTexture [[texture(0)]], texture2d<float> blurTexture [[texture(1)]], texture2d<float> lutTexture [[texture(2)]], sampler inputTextureSmplr [[sampler(0)]], sampler blurTextureSmplr [[sampler(1)]], sampler lutTextureSmplr [[sampler(2)]])
{
    main0_out out = {};
    float4 _132 = inputTexture.sample(inputTextureSmplr, in.textureCoordinate);
    float4 _137 = blurTexture.sample(blurTextureSmplr, in.textureCoordinate);
    float3 _141 = _132.xyz;
    float _145 = _132.x;
    float _146 = _132.y;
    float4 _148 = float4(_145, _146, _132.z, _137.w);
    float _159 = distance(float3(0.0), fast::max(_137.xyz - _141, float3(0.0)));
    float _161 = _159 * 28.8675098419189453125;
    float4 _332;
    if ((_161 > 0.5) && (_161 < 5.0))
    {
        float _209 = _132.z * 63.0;
        float _211 = floor(_209);
        float _213 = floor(_211 * 0.125);
        float _223 = ceil(_209);
        float _225 = floor(_223 * 0.125);
        float _250 = fma(0.123046875, _146, fma(_213, 0.125, 0.0009765625));
        float2 _313 = float2(fma(0.123046875, _145, fma(fma(-_213, 8.0, _211), 0.125, 0.0009765625)), _250);
        _313.y = 1.0 - _250;
        float _272 = fma(0.123046875, _146, fma(_225, 0.125, 0.0009765625));
        float2 _324 = float2(fma(0.123046875, _145, fma(fma(-_225, 8.0, _223), 0.125, 0.0009765625)), _272);
        _324.y = 1.0 - _272;
        float3 _187 = mix(_141, mix(lutTexture.sample(lutTextureSmplr, _313), lutTexture.sample(lutTextureSmplr, _324), float4(fract(_209))).xyz, float3(fma(_159, 2.5663216114044189453125, 0.3549999892711639404296875)));
        float4 _326 = _148;
        _326.x = _187.x;
        float4 _328 = _326;
        _328.y = _187.y;
        float4 _330 = _328;
        _330.z = _187.z;
        _332 = _330;
    }
    else
    {
        _332 = _148;
    }
    out.o_fragColor = _332;
    return out;
}

