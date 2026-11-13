#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct buffer_t
{
    float4x4 uMVPMatrix;
};

struct main0_out
{
    float2 texCoord [[user(locn0)]];
    float2 sucaiTexCoord [[user(locn1)]];
    float weight [[user(locn2)]];
    float4 gl_Position [[position]];
};

struct main0_in
{
    float3 attPosition [[attribute(0)]];
    float3 attTexcoord3D0 [[attribute(1)]];
};

vertex main0_out main0(main0_in in [[stage_in]], constant buffer_t& buffer)
{
    main0_out out = {};
    out.gl_Position = buffer.uMVPMatrix * float4(in.attPosition.xy, 0.0, 1.0);
    out.texCoord = (out.gl_Position.xy * 0.5) + float2(0.5);
    out.sucaiTexCoord = in.attTexcoord3D0.xy;
    out.weight = in.attPosition.z * 2.0;
    out.gl_Position.z = (out.gl_Position.z + out.gl_Position.w) * 0.5;       // Adjust clip-space for Metal
    return out;
}

