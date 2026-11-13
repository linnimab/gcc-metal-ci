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
    float4 textureShift_1 [[user(locn1)]];
    float4 textureShift_2 [[user(locn2)]];
    float4 textureShift_3 [[user(locn3)]];
    float4 textureShift_4 [[user(locn4)]];
};

fragment main0_out main0(main0_in in [[stage_in]], texture2d<float> inputTexture [[texture(0)]], sampler inputTextureSmplr [[sampler(0)]])
{
    main0_out out = {};
    float4 _19 = inputTexture.sample(inputTextureSmplr, in.textureCoordinate);
    float3 _29 = _19.xyz;
    float3 _47 = inputTexture.sample(inputTextureSmplr, in.textureShift_1.xy).xyz;
    float _56 = 1.0 - fast::min(distance(_29, _47) * 5.248638629913330078125, 1.0);
    float3 _78 = inputTexture.sample(inputTextureSmplr, in.textureShift_1.zw).xyz;
    float _84 = 1.0 - fast::min(distance(_29, _78) * 5.248638629913330078125, 1.0);
    float3 _107 = inputTexture.sample(inputTextureSmplr, in.textureShift_2.xy).xyz;
    float _114 = 1.0 - fast::min(distance(_29, _107) * 5.248638629913330078125, 1.0);
    float3 _136 = inputTexture.sample(inputTextureSmplr, in.textureShift_2.zw).xyz;
    float _142 = 1.0 - fast::min(distance(_29, _136) * 5.248638629913330078125, 1.0);
    float3 _165 = inputTexture.sample(inputTextureSmplr, in.textureShift_3.xy).xyz;
    float _172 = 1.0 - fast::min(distance(_29, _165) * 5.248638629913330078125, 1.0);
    float3 _194 = inputTexture.sample(inputTextureSmplr, in.textureShift_3.zw).xyz;
    float _200 = 1.0 - fast::min(distance(_29, _194) * 5.248638629913330078125, 1.0);
    float3 _223 = inputTexture.sample(inputTextureSmplr, in.textureShift_4.xy).xyz;
    float _230 = 1.0 - fast::min(distance(_29, _223) * 5.248638629913330078125, 1.0);
    float3 _252 = inputTexture.sample(inputTextureSmplr, in.textureShift_4.zw).xyz;
    float _258 = 1.0 - fast::min(distance(_29, _252) * 5.248638629913330078125, 1.0);
    out.o_fragColor = float4((((((((((_29 * 0.180000007152557373046875) + (_47 * (0.1500000059604644775390625 * _56))) + (_78 * (0.1500000059604644775390625 * _84))) + (_107 * (0.119999997317790985107421875 * _114))) + (_136 * (0.119999997317790985107421875 * _142))) + (_165 * (0.07999999821186065673828125 * _172))) + (_194 * (0.07999999821186065673828125 * _200))) + (_223 * (0.0500000007450580596923828125 * _230))) + (_252 * (0.0500000007450580596923828125 * _258))) / float3(fma(0.0500000007450580596923828125, _258, fma(0.0500000007450580596923828125, _230, fma(0.07999999821186065673828125, _200, fma(0.07999999821186065673828125, _172, fma(0.119999997317790985107421875, _142, fma(0.119999997317790985107421875, _114, fma(0.1500000059604644775390625, _84, fma(0.1500000059604644775390625, _56, 0.180000007152557373046875))))))))), _19.w);
    return out;
}

