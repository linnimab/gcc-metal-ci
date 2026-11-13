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
    float _35 = _19.y;
    float4 _42 = inputTexture.sample(inputTextureSmplr, in.textureShift_1.xy);
    float3 _47 = _42.xyz;
    float _56 = 1.0 - fast::min(distance(_29, _47) * 5.248638629913330078125, 1.0);
    float _68 = _42.y;
    float4 _74 = inputTexture.sample(inputTextureSmplr, in.textureShift_1.zw);
    float3 _78 = _74.xyz;
    float _84 = 1.0 - fast::min(distance(_29, _78) * 5.248638629913330078125, 1.0);
    float _96 = _74.y;
    float4 _103 = inputTexture.sample(inputTextureSmplr, in.textureShift_2.xy);
    float3 _107 = _103.xyz;
    float _114 = 1.0 - fast::min(distance(_29, _107) * 5.248638629913330078125, 1.0);
    float _126 = _103.y;
    float4 _132 = inputTexture.sample(inputTextureSmplr, in.textureShift_2.zw);
    float3 _136 = _132.xyz;
    float _142 = 1.0 - fast::min(distance(_29, _136) * 5.248638629913330078125, 1.0);
    float _154 = _132.y;
    float4 _161 = inputTexture.sample(inputTextureSmplr, in.textureShift_3.xy);
    float3 _165 = _161.xyz;
    float _172 = 1.0 - fast::min(distance(_29, _165) * 5.248638629913330078125, 1.0);
    float _184 = _161.y;
    float4 _190 = inputTexture.sample(inputTextureSmplr, in.textureShift_3.zw);
    float3 _194 = _190.xyz;
    float _200 = 1.0 - fast::min(distance(_29, _194) * 5.248638629913330078125, 1.0);
    float _212 = _190.y;
    float4 _219 = inputTexture.sample(inputTextureSmplr, in.textureShift_4.xy);
    float3 _223 = _219.xyz;
    float _230 = 1.0 - fast::min(distance(_29, _223) * 5.248638629913330078125, 1.0);
    float _242 = _219.y;
    float4 _248 = inputTexture.sample(inputTextureSmplr, in.textureShift_4.zw);
    float3 _252 = _248.xyz;
    float _258 = 1.0 - fast::min(distance(_29, _252) * 5.248638629913330078125, 1.0);
    float _270 = _248.y;
    float _410 = -((((((((_35 + _68) + _96) + _126) + _154) + _184) + _212) + _242) + _270);
    out.o_fragColor = float4((((((((((_29 * 0.180000007152557373046875) + (_47 * (0.1500000059604644775390625 * _56))) + (_78 * (0.1500000059604644775390625 * _84))) + (_107 * (0.119999997317790985107421875 * _114))) + (_136 * (0.119999997317790985107421875 * _142))) + (_165 * (0.07999999821186065673828125 * _172))) + (_194 * (0.07999999821186065673828125 * _200))) + (_223 * (0.0500000007450580596923828125 * _230))) + (_252 * (0.0500000007450580596923828125 * _258))) / float3(fma(0.0500000007450580596923828125, _258, fma(0.0500000007450580596923828125, _230, fma(0.07999999821186065673828125, _200, fma(0.07999999821186065673828125, _172, fma(0.119999997317790985107421875, _142, fma(0.119999997317790985107421875, _114, fma(0.1500000059604644775390625, _84, fma(0.1500000059604644775390625, _56, 0.180000007152557373046875))))))))), fma(pow(fma(_410, 0.125, _270), 2.0), 0.0500000007450580596923828125, fma(pow(fma(_410, 0.125, _242), 2.0), 0.0500000007450580596923828125, fma(pow(fma(_410, 0.125, _212), 2.0), 0.07999999821186065673828125, fma(pow(fma(_410, 0.125, _184), 2.0), 0.07999999821186065673828125, fma(pow(fma(_410, 0.125, _154), 2.0), 0.119999997317790985107421875, fma(pow(fma(_410, 0.125, _126), 2.0), 0.119999997317790985107421875, fma(pow(fma(_410, 0.125, _96), 2.0), 0.1500000059604644775390625, fma(pow(fma(_410, 0.125, _35), 2.0), 0.180000007152557373046875, pow(fma(_410, 0.125, _68), 2.0) * 0.1500000059604644775390625)))))))));
    return out;
}

