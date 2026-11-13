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
    mediump vec3 _47 = texture(inputTexture, textureShift_1.xy).xyz;
    mediump float _56 = 1.0 - min(distance(_29, _47) * 5.248638629913330078125, 1.0);
    mediump vec3 _78 = texture(inputTexture, textureShift_1.zw).xyz;
    mediump float _84 = 1.0 - min(distance(_29, _78) * 5.248638629913330078125, 1.0);
    mediump vec3 _107 = texture(inputTexture, textureShift_2.xy).xyz;
    mediump float _114 = 1.0 - min(distance(_29, _107) * 5.248638629913330078125, 1.0);
    mediump vec3 _136 = texture(inputTexture, textureShift_2.zw).xyz;
    mediump float _142 = 1.0 - min(distance(_29, _136) * 5.248638629913330078125, 1.0);
    mediump vec3 _165 = texture(inputTexture, textureShift_3.xy).xyz;
    mediump float _172 = 1.0 - min(distance(_29, _165) * 5.248638629913330078125, 1.0);
    mediump vec3 _194 = texture(inputTexture, textureShift_3.zw).xyz;
    mediump float _200 = 1.0 - min(distance(_29, _194) * 5.248638629913330078125, 1.0);
    mediump vec3 _223 = texture(inputTexture, textureShift_4.xy).xyz;
    mediump float _230 = 1.0 - min(distance(_29, _223) * 5.248638629913330078125, 1.0);
    mediump vec3 _252 = texture(inputTexture, textureShift_4.zw).xyz;
    mediump float _258 = 1.0 - min(distance(_29, _252) * 5.248638629913330078125, 1.0);
    o_fragColor = vec4((((((((((_29 * 0.180000007152557373046875) + (_47 * (0.1500000059604644775390625 * _56))) + (_78 * (0.1500000059604644775390625 * _84))) + (_107 * (0.119999997317790985107421875 * _114))) + (_136 * (0.119999997317790985107421875 * _142))) + (_165 * (0.07999999821186065673828125 * _172))) + (_194 * (0.07999999821186065673828125 * _200))) + (_223 * (0.0500000007450580596923828125 * _230))) + (_252 * (0.0500000007450580596923828125 * _258))) / vec3(0.0500000007450580596923828125 * _258 + (0.0500000007450580596923828125 * _230 + (0.07999999821186065673828125 * _200 + (0.07999999821186065673828125 * _172 + (0.119999997317790985107421875 * _142 + (0.119999997317790985107421875 * _114 + (0.1500000059604644775390625 * _84 + (0.1500000059604644775390625 * _56 + 0.180000007152557373046875)))))))), _19.w);
}

