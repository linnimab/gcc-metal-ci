#version 300 es
#define ae_insert_flip_uniform
#undef ae_insert_flip_uniform
precision highp float;
precision highp int;

uniform mediump sampler2D maskTexture;

in vec2 textureCoordinate;
layout(location = 0) out vec4 o_fragColor;

void main()
{
    o_fragColor = vec4(texture(maskTexture, textureCoordinate).xyz, 1.0);
}

