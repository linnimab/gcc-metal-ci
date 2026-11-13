#version 300 es
#define ae_insert_flip_uniform
#undef ae_insert_flip_uniform
precision highp float;
precision highp int;

uniform mediump sampler2D _MainTex;

layout(location = 0) out vec4 o_fragColor;
in vec2 varUV;

void main()
{
    o_fragColor = texture(_MainTex, varUV);
}

