#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct buffer_t
{
    float4x4 uMVPMatrix;
    float4x4 uSTMatrix;
};

struct main0_out
{
    float2 texCoord [[user(locn0)]];
    float2 maskTexCoord [[user(locn1)]];
    float4 gl_Position [[position]];
};

struct main0_in
{
    float3 attPosition [[attribute(0)]];
    float3 attTexcoord0 [[attribute(1)]];
};

vertex main0_out main0(main0_in in [[stage_in]], constant buffer_t& buffer)
{
    main0_out out = {};
    out.gl_Position = buffer.uMVPMatrix * float4(in.attPosition.xy, 0.0, 1.0);
    out.texCoord = (out.gl_Position.xy * 0.5) + float2(0.5);
    out.maskTexCoord = float2((buffer.uSTMatrix * float4(in.attTexcoord0.xy, 0.0, 1.0)).xy);
    out.gl_Position.z = (out.gl_Position.z + out.gl_Position.w) * 0.5;       // Adjust clip-space for Metal
    return out;
}

