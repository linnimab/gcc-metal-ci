#pragma clang diagnostic ignored "-Wmissing-prototypes"
#pragma clang diagnostic ignored "-Wmissing-braces"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

template<typename T, size_t Num>
struct spvUnsafeArray
{
    T elements[Num ? Num : 1];
    
    thread T& operator [] (size_t pos) thread
    {
        return elements[pos];
    }
    constexpr const thread T& operator [] (size_t pos) const thread
    {
        return elements[pos];
    }
    
    device T& operator [] (size_t pos) device
    {
        return elements[pos];
    }
    constexpr const device T& operator [] (size_t pos) const device
    {
        return elements[pos];
    }
    
    constexpr const constant T& operator [] (size_t pos) const constant
    {
        return elements[pos];
    }
    
    threadgroup T& operator [] (size_t pos) threadgroup
    {
        return elements[pos];
    }
    constexpr const threadgroup T& operator [] (size_t pos) const threadgroup
    {
        return elements[pos];
    }
};

// Implementation of the GLSL mod() function, which is slightly different than Metal fmod()
template<typename Tx, typename Ty>
inline Tx mod(Tx x, Ty y)
{
    return x - y * floor(x / y);
}

struct buffer_t
{
    float _ContourPointCount;
    float _PointCount;
    float _Spread;
    float _StartOffset;
    float _CurrentTime;
    float _Speed;
    float _NoiseAmplitude;
    float _NoiseFrequency;
    float _Scale;
    int _FlipY;
    int _FlipX;
    int _RotateMode;
    float _RotateSpeed;
    float _ScreenRatio;
    float2 _PointSize;
    float2 _Offset;
};

constant spvUnsafeArray<int, 256> _283 = spvUnsafeArray<int, 256>({ 151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225, 140, 36, 103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148, 247, 120, 234, 75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32, 57, 177, 33, 88, 237, 149, 56, 87, 174, 20, 125, 136, 171, 168, 68, 175, 74, 165, 71, 134, 139, 48, 27, 166, 77, 146, 158, 231, 83, 111, 229, 122, 60, 211, 133, 230, 220, 105, 92, 41, 55, 46, 245, 40, 244, 102, 143, 54, 65, 25, 63, 161, 1, 216, 80, 73, 209, 76, 132, 187, 208, 89, 18, 169, 200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109, 198, 173, 186, 3, 64, 52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126, 255, 82, 85, 212, 207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183, 170, 213, 119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43, 172, 9, 129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112, 104, 218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162, 241, 81, 51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31, 181, 199, 106, 157, 184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205, 93, 222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180 });

struct main0_out
{
    float2 g_vary_uv0 [[user(locn0)]];
    float indexRatio [[user(locn1)]];
    float4 gl_Position [[position]];
};

struct main0_in
{
    float3 attPosition [[attribute(0)]];
    float2 attTexcoord0 [[attribute(1)]];
};

vertex main0_out main0(main0_in in [[stage_in]], constant buffer_t& buffer, texture2d<float> _ContourTex [[texture(0)]], sampler _ContourTexSmplr [[sampler(0)]])
{
    main0_out out = {};
    out.g_vary_uv0 = in.attTexcoord0;
    int _384 = int(in.attPosition.x);
    int _389 = int(in.attPosition.y);
    float _393 = float(_384);
    out.indexRatio = _393 / buffer._PointCount;
    float _419 = fma(-((buffer._CurrentTime * buffer._Speed) * buffer._ContourPointCount), 0.00200000009499490261077880859375, fma(buffer._ContourPointCount, 5.0, fma(_393, (buffer._ContourPointCount / buffer._PointCount) * buffer._Spread, buffer._ContourPointCount * buffer._StartOffset)));
    int _425 = int(buffer._ContourPointCount);
    int _426 = int(floor(_419)) % _425;
    int _437 = int(floor(fma(buffer._ContourPointCount, 0.006666666828095912933349609375, _419))) % _425;
    float4 _475 = _ContourTex.sample(_ContourTexSmplr, float2((float(_426 % 64) + 0.5) * 0.015625, (float(_426 / 64) + 0.5) * 0.015625), level(0.0));
    float4 _487 = _ContourTex.sample(_ContourTexSmplr, float2((float(_437 % 64) + 0.5) * 0.015625, (float(_437 / 64) + 0.5) * 0.015625), level(0.0));
    float _497 = fma(fma(_475.x, 255.0, _475.y), 0.0039215688593685626983642578125, -0.5);
    float _509 = fma(-fma(_475.z, 255.0, _475.w), 0.0039215688593685626983642578125, 0.5);
    float2 _511 = float2(_497 * 2.0, _509 * 2.0);
    float _520 = fma(fma(_487.x, 255.0, _487.y), 0.0039215688593685626983642578125, -0.5);
    float _529 = fma(-fma(_487.z, 255.0, _487.w), 0.0039215688593685626983642578125, 0.5);
    float2 _531 = float2(_520 * 2.0, _529 * 2.0);
    float2 _544 = fast::normalize(float2(fma(_520, 2.0, _497 * (-2.0)), fma(_529, 2.0, _509 * (-2.0))));
    float _1054;
    if (buffer._NoiseAmplitude > 0.100000001490116119384765625)
    {
        float _575 = fma(buffer._NoiseFrequency * 0.0199999995529651641845703125, buffer._CurrentTime, float(_283[_384 % 256]) * 0.0039215688593685626983642578125);
        float _850 = floor(_575);
        int _852 = int(_850) & 255;
        float _856 = _575 - _850;
        float _889 = (_856 * _856) * _856;
        float _895 = fma(_856, fma(_856, 6.0, -15.0), 10.0);
        _1054 = fma(fma(-_889, _895, 1.0), float((_283[_852] % 3) - 1) * _856, (_889 * _895) * (float((_283[_852 + 1] % 3) - 1) * (_856 - 1.0))) * buffer._NoiseAmplitude;
    }
    else
    {
        _1054 = 0.0;
    }
    float _607 = 0.00999999977648258209228515625 * fma(buffer._Scale, -0.199999988079071044921875, _1054);
    float2 _1055;
    if (buffer._RotateMode == 1)
    {
        _1055 = fast::normalize(_531 - _511);
    }
    else
    {
        float2 _1056;
        if (buffer._RotateMode == 2)
        {
            float2 _658 = fast::normalize(_531 - _511);
            _1056 = float2(-_658.y, _658.x);
        }
        else
        {
            float2 _1057;
            if (buffer._RotateMode == 3)
            {
                float _681 = fma(float(_283[_384 % 256]), 0.0039215688593685626983642578125, buffer._CurrentTime);
                float _920 = floor(_681);
                int _922 = int(_920) & 255;
                float _926 = _681 - _920;
                float _959 = (_926 * _926) * _926;
                float _965 = fma(_926, fma(_926, 6.0, -15.0), 10.0);
                float _706 = mod(fma(sin(float(_384 + 1) * floor(sin(fma(fma(-_959, _965, 1.0), float((_283[_922] % 3) - 1) * _926, (_959 * _965) * (float((_283[_922 + 1] % 3) - 1) * (_926 - 1.0))) * buffer._RotateSpeed) * 3.0)), 0.5, 0.5) * 43567.546875, 1.0) * 6.28318500518798828125;
                _1057 = float2(cos(_706), sin(_706));
            }
            else
            {
                _1057 = float2(1.0, 0.0);
            }
            _1056 = _1057;
        }
        _1055 = _1056;
    }
    float2 _1065;
    if (_389 == 0)
    {
        _1065 = float2(buffer._ScreenRatio * (_1055.y - _1055.x), (-_1055.x) - _1055.y);
    }
    else
    {
        float2 _1066;
        if (_389 == 1)
        {
            _1066 = float2(buffer._ScreenRatio * (_1055.y + _1055.x), _1055.y - _1055.x);
        }
        else
        {
            float2 _1067;
            if (_389 == 2)
            {
                _1067 = float2(buffer._ScreenRatio * (_1055.x - _1055.y), _1055.x + _1055.y);
            }
            else
            {
                float2 _1068;
                if (_389 == 3)
                {
                    _1068 = float2((-buffer._ScreenRatio) * (_1055.x + _1055.y), _1055.x - _1055.y);
                }
                else
                {
                    _1068 = float2(0.0);
                }
                _1067 = _1068;
            }
            _1066 = _1067;
        }
        _1065 = _1066;
    }
    out.gl_Position = float4(fma(buffer._Offset.x, 0.00999999977648258209228515625, fma((buffer._FlipX == 1) ? (-1.0) : 1.0, fma(_497, 2.0, _607 * (-_544.y)), (_1065.x * buffer._PointSize.x) * 0.001000000047497451305389404296875)), fma(buffer._Offset.y, 0.00999999977648258209228515625, fma((buffer._FlipY == 1) ? (-1.0) : 1.0, fma(_509, 2.0, _607 * _544.x), (_1065.y * buffer._PointSize.y) * 0.001000000047497451305389404296875)), 0.0, 1.0);
    out.gl_Position.z = (out.gl_Position.z + out.gl_Position.w) * 0.5;       // Adjust clip-space for Metal
    return out;
}

