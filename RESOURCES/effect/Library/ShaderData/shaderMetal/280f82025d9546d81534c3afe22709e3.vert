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
    float2 v2f_materialTexCoord [[user(locn0)]];
    float2 v2f_texCoord [[user(locn1)]];
    float2 v2f_segCoord [[user(locn2)]];
    float4 gl_Position [[position]];
};

struct main0_in
{
    float4 attPosition [[attribute(0)]];
    float2 attTexcoord0 [[attribute(1)]];
};

vertex main0_out main0(main0_in in [[stage_in]], constant buffer_t& buffer)
{
    main0_out out = {};
    float4 _107 = float4(in.attPosition.xy, 0.0, 1.0);
    float4 _108 = buffer.uMVPMatrix * _107;
    out.v2f_materialTexCoord = (buffer.uSTMatrix * float4(in.attTexcoord0, 0.0, 1.0)).xy;
    out.v2f_texCoord = (_108.xy * 0.5) + float2(0.5);
    out.v2f_segCoord = (buffer.uSegMatrix * _107).xy;
    out.gl_Position = _108;
    out.gl_Position.z = (out.gl_Position.z + out.gl_Position.w) * 0.5;       // Adjust clip-space for Metal
    return out;
}

