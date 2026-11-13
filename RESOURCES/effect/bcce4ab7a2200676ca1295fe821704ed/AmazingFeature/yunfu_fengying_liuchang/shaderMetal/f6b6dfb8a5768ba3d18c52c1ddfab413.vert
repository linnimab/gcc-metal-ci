#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct buffer_t
{
    float4x4 mvpMat;
};

struct main0_out
{
    float2 uv [[user(locn0)]];
    float2 uv_screen [[user(locn1)]];
    float4 gl_Position [[position]];
};

struct main0_in
{
    float3 attPosition [[attribute(0)]];
    float2 attTexcoord0 [[attribute(1)]];
};

vertex main0_out main0(main0_in in [[stage_in]], constant buffer_t& buffer)
{
    main0_out out = {};
    out.gl_Position = buffer.mvpMat * float4(in.attPosition.xy, 0.0, 1.0);
    out.uv = in.attTexcoord0;
    out.uv = float2(in.attTexcoord0.x, 1.0 - in.attTexcoord0.y);
    out.uv_screen = ((out.gl_Position.xy / float2(out.gl_Position.w)) * 0.5) + float2(0.5);
    out.gl_Position.z = (out.gl_Position.z + out.gl_Position.w) * 0.5;       // Adjust clip-space for Metal
    return out;
}

