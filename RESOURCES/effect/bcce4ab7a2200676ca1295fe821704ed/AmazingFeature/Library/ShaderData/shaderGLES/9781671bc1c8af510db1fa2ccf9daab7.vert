#version 300 es
#define ae_insert_flip_uniform
#undef ae_insert_flip_uniform

const int _283[256] = int[](151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225, 140, 36, 103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148, 247, 120, 234, 75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32, 57, 177, 33, 88, 237, 149, 56, 87, 174, 20, 125, 136, 171, 168, 68, 175, 74, 165, 71, 134, 139, 48, 27, 166, 77, 146, 158, 231, 83, 111, 229, 122, 60, 211, 133, 230, 220, 105, 92, 41, 55, 46, 245, 40, 244, 102, 143, 54, 65, 25, 63, 161, 1, 216, 80, 73, 209, 76, 132, 187, 208, 89, 18, 169, 200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109, 198, 173, 186, 3, 64, 52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126, 255, 82, 85, 212, 207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183, 170, 213, 119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43, 172, 9, 129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112, 104, 218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162, 241, 81, 51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31, 181, 199, 106, 157, 184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205, 93, 222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180);

uniform float _ContourPointCount;
uniform float _PointCount;
uniform float _Spread;
uniform float _StartOffset;
uniform float _CurrentTime;
uniform float _Speed;
uniform mediump sampler2D _ContourTex;
uniform float _NoiseAmplitude;
uniform float _NoiseFrequency;
uniform float _Scale;
uniform mediump int _FlipY;
uniform mediump int _FlipX;
uniform mediump int _RotateMode;
uniform float _RotateSpeed;
uniform float _ScreenRatio;
uniform vec2 _PointSize;
uniform vec2 _Offset;

out vec2 g_vary_uv0;
layout(location = 1) in vec2 attTexcoord0;
layout(location = 0) in vec3 attPosition;
out float indexRatio;

void main()
{
    g_vary_uv0 = attTexcoord0;
    int _384 = int(attPosition.x);
    int _389 = int(attPosition.y);
    mediump float _393 = float(_384);
    indexRatio = _393 / _PointCount;
    float _419 = (-((_CurrentTime * _Speed) * _ContourPointCount)) * 0.00200000009499490261077880859375 + (_ContourPointCount * 5.0 + (_393 * ((_ContourPointCount / _PointCount) * _Spread) + (_ContourPointCount * _StartOffset)));
    int _425 = int(_ContourPointCount);
    int _426 = int(floor(_419)) % _425;
    int _437 = int(floor(_ContourPointCount * 0.006666666828095912933349609375 + _419)) % _425;
    mediump vec4 _475 = textureLod(_ContourTex, vec2((float(_426 % 64) + 0.5) * 0.015625, (float(_426 / 64) + 0.5) * 0.015625), 0.0);
    mediump vec4 _487 = textureLod(_ContourTex, vec2((float(_437 % 64) + 0.5) * 0.015625, (float(_437 / 64) + 0.5) * 0.015625), 0.0);
    float _497 = (_475.x * 255.0 + _475.y) * 0.0039215688593685626983642578125 + (-0.5);
    float _509 = (-(_475.z * 255.0 + _475.w)) * 0.0039215688593685626983642578125 + 0.5;
    vec2 _511 = vec2(_497 * 2.0, _509 * 2.0);
    float _520 = (_487.x * 255.0 + _487.y) * 0.0039215688593685626983642578125 + (-0.5);
    float _529 = (-(_487.z * 255.0 + _487.w)) * 0.0039215688593685626983642578125 + 0.5;
    vec2 _531 = vec2(_520 * 2.0, _529 * 2.0);
    vec2 _544 = normalize(vec2(_520 * 2.0 + (_497 * (-2.0)), _529 * 2.0 + (_509 * (-2.0))));
    float _1054;
    if (_NoiseAmplitude > 0.100000001490116119384765625)
    {
        float _575 = (_NoiseFrequency * 0.0199999995529651641845703125) * _CurrentTime + (float(_283[_384 % 256]) * 0.0039215688593685626983642578125);
        float _850 = floor(_575);
        int _852 = int(_850) & 255;
        float _856 = _575 - _850;
        float _889 = (_856 * _856) * _856;
        float _895 = _856 * (_856 * 6.0 + (-15.0)) + 10.0;
        _1054 = (((-_889) * _895 + 1.0) * (float((_283[_852] % 3) - 1) * _856) + ((_889 * _895) * (float((_283[_852 + 1] % 3) - 1) * (_856 - 1.0)))) * _NoiseAmplitude;
    }
    else
    {
        _1054 = 0.0;
    }
    float _607 = 0.00999999977648258209228515625 * (_Scale * (-0.199999988079071044921875) + _1054);
    vec2 _1055;
    if (_RotateMode == 1)
    {
        _1055 = normalize(_531 - _511);
    }
    else
    {
        vec2 _1056;
        if (_RotateMode == 2)
        {
            vec2 _658 = normalize(_531 - _511);
            _1056 = vec2(-_658.y, _658.x);
        }
        else
        {
            vec2 _1057;
            if (_RotateMode == 3)
            {
                float _681 = float(_283[_384 % 256]) * 0.0039215688593685626983642578125 + _CurrentTime;
                float _920 = floor(_681);
                int _922 = int(_920) & 255;
                float _926 = _681 - _920;
                float _959 = (_926 * _926) * _926;
                float _965 = _926 * (_926 * 6.0 + (-15.0)) + 10.0;
                float _706 = mod((sin(float(_384 + 1) * floor(sin((((-_959) * _965 + 1.0) * (float((_283[_922] % 3) - 1) * _926) + ((_959 * _965) * (float((_283[_922 + 1] % 3) - 1) * (_926 - 1.0)))) * _RotateSpeed) * 3.0)) * 0.5 + 0.5) * 43567.546875, 1.0) * 6.28318500518798828125;
                _1057 = vec2(cos(_706), sin(_706));
            }
            else
            {
                _1057 = vec2(1.0, 0.0);
            }
            _1056 = _1057;
        }
        _1055 = _1056;
    }
    vec2 _1065;
    if (_389 == 0)
    {
        _1065 = vec2(_ScreenRatio * (_1055.y - _1055.x), (-_1055.x) - _1055.y);
    }
    else
    {
        vec2 _1066;
        if (_389 == 1)
        {
            _1066 = vec2(_ScreenRatio * (_1055.y + _1055.x), _1055.y - _1055.x);
        }
        else
        {
            vec2 _1067;
            if (_389 == 2)
            {
                _1067 = vec2(_ScreenRatio * (_1055.x - _1055.y), _1055.x + _1055.y);
            }
            else
            {
                vec2 _1068;
                if (_389 == 3)
                {
                    _1068 = vec2((-_ScreenRatio) * (_1055.x + _1055.y), _1055.x - _1055.y);
                }
                else
                {
                    _1068 = vec2(0.0);
                }
                _1067 = _1068;
            }
            _1066 = _1067;
        }
        _1065 = _1066;
    }
    gl_Position = vec4(_Offset.x * 0.00999999977648258209228515625 + (((_FlipX == 1) ? (-1.0) : 1.0) * (_497 * 2.0 + (_607 * (-_544.y))) + ((_1065.x * _PointSize.x) * 0.001000000047497451305389404296875)), _Offset.y * 0.00999999977648258209228515625 + (((_FlipY == 1) ? (-1.0) : 1.0) * (_509 * 2.0 + (_607 * _544.x)) + ((_1065.y * _PointSize.y) * 0.001000000047497451305389404296875)), 0.0, 1.0);
}

