#version 300 es
#define ae_insert_flip_uniform
#undef ae_insert_flip_uniform
precision highp float;
precision highp int;

uniform mediump sampler2D inputTexture;
uniform mediump sampler2D blurTexture;
uniform mediump sampler2D lutTexture;

in vec2 textureCoordinate;
layout(location = 0) out vec4 o_fragColor;

void main()
{
    mediump vec4 _132 = texture(inputTexture, textureCoordinate);
    mediump vec4 _137 = texture(blurTexture, textureCoordinate);
    mediump vec3 _141 = _132.xyz;
    mediump float _145 = _132.x;
    mediump float _146 = _132.y;
    mediump vec4 _148 = vec4(_145, _146, _132.z, _137.w);
    mediump float _159 = distance(vec3(0.0), max(_137.xyz - _141, vec3(0.0)));
    mediump float _161 = _159 * 28.8675098419189453125;
    mediump vec4 _332;
    if ((_161 > 0.5) && (_161 < 5.0))
    {
        mediump float _209 = _132.z * 63.0;
        float _211 = floor(_209);
        float _213 = floor(_211 * 0.125);
        float _223 = ceil(_209);
        float _225 = floor(_223 * 0.125);
        float _250 = 0.123046875 * _146 + (_213 * 0.125 + 0.0009765625);
        vec2 _313 = vec2(0.123046875 * _145 + (((-_213) * 8.0 + _211) * 0.125 + 0.0009765625), _250);
        _313.y = 1.0 - _250;
        float _272 = 0.123046875 * _146 + (_225 * 0.125 + 0.0009765625);
        vec2 _324 = vec2(0.123046875 * _145 + (((-_225) * 8.0 + _223) * 0.125 + 0.0009765625), _272);
        _324.y = 1.0 - _272;
        mediump vec3 _187 = mix(_141, mix(texture(lutTexture, _313), texture(lutTexture, _324), vec4(fract(_209))).xyz, vec3(_159 * 2.5663216114044189453125 + 0.3549999892711639404296875));
        mediump vec4 _326 = _148;
        _326.x = _187.x;
        mediump vec4 _328 = _326;
        _328.y = _187.y;
        mediump vec4 _330 = _328;
        _330.z = _187.z;
        _332 = _330;
    }
    else
    {
        _332 = _148;
    }
    o_fragColor = _332;
}

