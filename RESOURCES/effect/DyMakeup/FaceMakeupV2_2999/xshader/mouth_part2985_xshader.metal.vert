#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct buffer_t
{
    float4x4 uMVPMatrix;
    float4x4 uSTMatrix;
    float4x4 uSegMatrix;
};

struct main0_out
{
    float2 texCoord [[user(texCoord)]];
    float2 sucaiTexCoord [[user(sucaiTexCoord)]];
    float2 segCoord [[user(segCoord)]];
    float4 gl_Position [[position]];
};

struct main0_in
{
    float2 attPosition [[attribute(0)]];
    float2 attUV [[attribute(1)]];
};

vertex main0_out main0(main0_in in [[stage_in]], constant buffer_t& buffer)
{
    main0_out out = {};
    float4 _22 = float4(in.attPosition, 0.0, 1.0);
    out.gl_Position = buffer.uMVPMatrix * _22;
    out.texCoord = (out.gl_Position.xy * 0.5) + float2(0.5);
    out.sucaiTexCoord = (buffer.uSTMatrix * float4(in.attUV, 0.0, 1.0)).xy;
    out.segCoord = (buffer.uSegMatrix * _22).xy;
    out.gl_Position.z = (out.gl_Position.z + out.gl_Position.w) * 0.5;       // Adjust clip-space for Metal
    return out;
}

