#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct buffer_t
{
    float texBlurWidthOffset;
    float texBlurHeightOffset;
};

struct main0_out
{
    float2 textureCoordinate [[user(locn0)]];
    float4 textureShift_1 [[user(locn1)]];
    float4 textureShift_2 [[user(locn2)]];
    float4 textureShift_3 [[user(locn3)]];
    float4 textureShift_4 [[user(locn4)]];
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
    out.gl_Position = float4(in.attPosition, 1.0);
    out.textureCoordinate = in.attTexcoord0;
    float2 _35 = float2(buffer.texBlurWidthOffset * 2.5, buffer.texBlurHeightOffset * 2.5);
    out.textureShift_1 = float4(out.textureCoordinate - _35, out.textureCoordinate + _35);
    float2 _52 = _35 * 2.0;
    out.textureShift_2 = float4(out.textureCoordinate - _52, out.textureCoordinate + _52);
    float2 _67 = _35 * 3.0;
    out.textureShift_3 = float4(out.textureCoordinate - _67, out.textureCoordinate + _67);
    float2 _82 = _35 * 4.0;
    out.textureShift_4 = float4(out.textureCoordinate - _82, out.textureCoordinate + _82);
    out.gl_Position.z = (out.gl_Position.z + out.gl_Position.w) * 0.5;       // Adjust clip-space for Metal
    return out;
}

