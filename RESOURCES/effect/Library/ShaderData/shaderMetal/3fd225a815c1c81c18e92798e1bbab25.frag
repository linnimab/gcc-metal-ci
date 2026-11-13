#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct buffer_t
{
    float useFaceMask;
    float useSkinTex;
    float smoothFactor;
    float smoothIntensity;
    float eyeBrillianceIntensity;
    float darkCirclesIntensity;
    float smileLinesIntensity;
};

struct main0_out
{
    float4 o_fragColor [[color(0)]];
};

struct main0_in
{
    float2 uv [[user(locn0)]];
};

fragment main0_out main0(main0_in in [[stage_in]], constant buffer_t& buffer, texture2d<float> inputTexture [[texture(0)]], texture2d<float> blendTexture [[texture(1)]], texture2d<float> blur3Texture [[texture(2)]], texture2d<float> blur4Texture [[texture(3)]], texture2d<float> facemaskTexture [[texture(4)]], texture2d<float> skinsegTexture [[texture(5)]], sampler inputTextureSmplr [[sampler(0)]], sampler blendTextureSmplr [[sampler(1)]], sampler blur3TextureSmplr [[sampler(2)]], sampler blur4TextureSmplr [[sampler(3)]], sampler facemaskTextureSmplr [[sampler(4)]], sampler skinsegTextureSmplr [[sampler(5)]])
{
    main0_out out = {};
    float2 _22 = float2(in.uv.x, 1.0 - in.uv.y);
    float4 _32 = inputTexture.sample(inputTextureSmplr, in.uv);
    float4 _37 = blendTexture.sample(blendTextureSmplr, in.uv);
    float4 _52 = facemaskTexture.sample(facemaskTextureSmplr, _22);
    float _57 = _37.w;
    float _63 = 1.0 - (_57 / (_57 + 0.19099999964237213134765625));
    float4 _68 = skinsegTexture.sample(skinsegTextureSmplr, _22);
    float _69 = _68.w;
    float _74 = _52.z;
    float3 _137 = blur4Texture.sample(blur4TextureSmplr, in.uv).xyz;
    float3 _163 = mix(_32.xyz, mix(fast::clamp((_137 + ((((_37.xyz * 0.5) - (blur3Texture.sample(blur3TextureSmplr, in.uv).xyz * 0.5)) + float3(0.5)) * 2.0)) - float3(1.0), float3(0.0), float3(1.0)), _137, float3(buffer.smoothFactor)), float3(buffer.smoothIntensity * fma(_69 * _63, (1.0 - buffer.useFaceMask) * buffer.useSkinTex, fma((mix(_69, _74, step(0.00999999977648258209228515625, _74)) * _69) * _63, buffer.useFaceMask * buffer.useSkinTex, (_74 * _63) * (buffer.useFaceMask * (1.0 - buffer.useSkinTex))))));
    float _170 = _52.y;
    float _171 = step(0.100000001490116119384765625, _170);
    float _174 = _52.x;
    float _175 = step(0.100000001490116119384765625, _174);
    float3 _205 = mix(_163, fast::max(_163, fast::clamp(_137 + ((_163 - _137) * 2.5), float3(0.0), float3(0.60000002384185791015625))), float3(((buffer.eyeBrillianceIntensity * _170) * 1.5) * ((step(0.00999999977648258209228515625, buffer.eyeBrillianceIntensity) * _171) * _175)));
    float3 _248 = mix(_205, fast::min(_205 + fast::clamp(((_137 - _205) * 1.2999999523162841796875) + (_137 * 0.04500000178813934326171875), float3(0.0), float3(0.20000000298023223876953125)), float3(1.0)), float3((buffer.darkCirclesIntensity * _174) * ((step(0.00999999977648258209228515625, buffer.darkCirclesIntensity) * _175) * step(_170, 0.5))));
    out.o_fragColor = float4(mix(_248, fast::min(_248 + fast::clamp(((_137 - _248) * 5.0) + (_137 * 0.0500000007450580596923828125), float3(0.0), float3(1.0)), float3(1.0)), float3(((buffer.smileLinesIntensity * _170) * 0.300000011920928955078125) * ((step(0.00999999977648258209228515625, buffer.smileLinesIntensity) * _171) * step(_174, 0.5)))), _32.w);
    return out;
}

