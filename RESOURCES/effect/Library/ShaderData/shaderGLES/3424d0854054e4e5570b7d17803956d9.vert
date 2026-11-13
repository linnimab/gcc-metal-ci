#version 300 es
#define ae_insert_flip_uniform
#undef ae_insert_flip_uniform

layout(location = 0) in vec3 attPosition;
out vec2 uv;
layout(location = 1) in vec2 attTexcoord0;

void main()
{
    gl_Position = vec4(attPosition, 1.0);
    uv = attTexcoord0;
}

