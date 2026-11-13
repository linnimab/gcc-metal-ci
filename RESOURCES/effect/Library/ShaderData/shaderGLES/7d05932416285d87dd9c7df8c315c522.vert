#version 300 es
#define ae_insert_flip_uniform
#undef ae_insert_flip_uniform

uniform mat4 uMVPMatrix;
uniform mat4 uSTMatrix;
uniform mat4 uSegMatrix;

layout(location = 0) in vec4 attPosition;
layout(location = 1) in vec2 attTexcoord0;
out vec2 v2f_materialTexCoord;
out vec2 v2f_texCoord;
out vec2 v2f_segCoord;

void main()
{
    vec4 _107 = vec4(attPosition.xy, 0.0, 1.0);
    vec4 _108 = uMVPMatrix * _107;
    v2f_materialTexCoord = (uSTMatrix * vec4(attTexcoord0, 0.0, 1.0)).xy;
    v2f_texCoord = (_108.xy * 0.5) + vec2(0.5);
    v2f_segCoord = (uSegMatrix * _107).xy;
    gl_Position = _108;
}

