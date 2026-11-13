#version 300 es
#define ae_insert_flip_uniform
#undef ae_insert_flip_uniform
precision highp float;
precision highp int;

uniform mediump sampler2D inputTexture;

in vec2 textureCoordinate;
in vec4 textureShift_1;
in vec4 textureShift_2;
in vec4 textureShift_3;
in vec4 textureShift_4;
layout(location = 0) out vec4 o_fragColor;

void main()
{
    mediump vec4 _19 = texture(inputTexture, textureCoordinate);
    mediump vec3 _29 = _19.xyz;
    mediump float _35 = _19.y;
    mediump vec4 _42 = texture(inputTexture, textureShift_1.xy);
    mediump vec3 _47 = _42.xyz;
    mediump float _56 = 1.0 - min(distance(_29, _47) * 5.248638629913330078125, 1.0);
    mediump float _68 = _42.y;
    mediump vec4 _74 = texture(inputTexture, textureShift_1.zw);
    mediump vec3 _78 = _74.xyz;
    mediump float _84 = 1.0 - min(distance(_29, _78) * 5.248638629913330078125, 1.0);
    mediump float _96 = _74.y;
    mediump vec4 _103 = texture(inputTexture, textureShift_2.xy);
    mediump vec3 _107 = _103.xyz;
    mediump float _114 = 1.0 - min(distance(_29, _107) * 5.248638629913330078125, 1.0);
    mediump float _126 = _103.y;
    mediump vec4 _132 = texture(inputTexture, textureShift_2.zw);
    mediump vec3 _136 = _132.xyz;
    mediump float _142 = 1.0 - min(distance(_29, _136) * 5.248638629913330078125, 1.0);
    mediump float _154 = _132.y;
    mediump vec4 _161 = texture(inputTexture, textureShift_3.xy);
    mediump vec3 _165 = _161.xyz;
    mediump float _172 = 1.0 - min(distance(_29, _165) * 5.248638629913330078125, 1.0);
    mediump float _184 = _161.y;
    mediump vec4 _190 = texture(inputTexture, textureShift_3.zw);
    mediump vec3 _194 = _190.xyz;
    mediump float _200 = 1.0 - min(distance(_29, _194) * 5.248638629913330078125, 1.0);
    mediump float _212 = _190.y;
    mediump vec4 _219 = texture(inputTexture, textureShift_4.xy);
    mediump vec3 _223 = _219.xyz;
    mediump float _230 = 1.0 - min(distance(_29, _223) * 5.248638629913330078125, 1.0);
    mediump float _242 = _219.y;
    mediump vec4 _248 = texture(inputTexture, textureShift_4.zw);
    mediump vec3 _252 = _248.xyz;
    mediump float _258 = 1.0 - min(distance(_29, _252) * 5.248638629913330078125, 1.0);
    mediump float _270 = _248.y;
    float _410 = -((((((((_35 + _68) + _96) + _126) + _154) + _184) + _212) + _242) + _270);
    o_fragColor = vec4((((((((((_29 * 0.180000007152557373046875) + (_47 * (0.1500000059604644775390625 * _56))) + (_78 * (0.1500000059604644775390625 * _84))) + (_107 * (0.119999997317790985107421875 * _114))) + (_136 * (0.119999997317790985107421875 * _142))) + (_165 * (0.07999999821186065673828125 * _172))) + (_194 * (0.07999999821186065673828125 * _200))) + (_223 * (0.0500000007450580596923828125 * _230))) + (_252 * (0.0500000007450580596923828125 * _258))) / vec3(0.0500000007450580596923828125 * _258 + (0.0500000007450580596923828125 * _230 + (0.07999999821186065673828125 * _200 + (0.07999999821186065673828125 * _172 + (0.119999997317790985107421875 * _142 + (0.119999997317790985107421875 * _114 + (0.1500000059604644775390625 * _84 + (0.1500000059604644775390625 * _56 + 0.180000007152557373046875)))))))), pow(_410 * 0.125 + _270, 2.0) * 0.0500000007450580596923828125 + (pow(_410 * 0.125 + _242, 2.0) * 0.0500000007450580596923828125 + (pow(_410 * 0.125 + _212, 2.0) * 0.07999999821186065673828125 + (pow(_410 * 0.125 + _184, 2.0) * 0.07999999821186065673828125 + (pow(_410 * 0.125 + _154, 2.0) * 0.119999997317790985107421875 + (pow(_410 * 0.125 + _126, 2.0) * 0.119999997317790985107421875 + (pow(_410 * 0.125 + _96, 2.0) * 0.1500000059604644775390625 + (pow(_410 * 0.125 + _35, 2.0) * 0.180000007152557373046875 + (pow(_410 * 0.125 + _68, 2.0) * 0.1500000059604644775390625)))))))));
}

