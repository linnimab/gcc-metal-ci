#version 300 es
#define ae_insert_flip_uniform
#undef ae_insert_flip_uniform

layout(location = 0) in vec3 attPosition;
layout(location = 1) in vec2 attTexcoord0;
out vec2 v2f_v_texCoord;

void main()
{
    v2f_v_texCoord = attTexcoord0;
    gl_Position = vec4(attPosition, 1.0);
}

