#version 300 es
#define ae_insert_flip_uniform
#undef ae_insert_flip_uniform

uniform mat4 u_MVP;

layout(location = 0) in vec3 attPosition;
out vec2 v_texCoord;
layout(location = 1) in vec2 attTexcoord0;

void main()
{
    gl_Position = u_MVP * vec4(attPosition, 1.0);
    v_texCoord = vec2(attTexcoord0.x, attTexcoord0.y);
}

