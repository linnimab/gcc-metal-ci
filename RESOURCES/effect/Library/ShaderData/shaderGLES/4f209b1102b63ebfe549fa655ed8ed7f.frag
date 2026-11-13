#version 300 es
#define ae_insert_flip_uniform
#undef ae_insert_flip_uniform
precision highp float;
precision highp int;

uniform mediump sampler2D u_FBOTexture;

layout(location = 0) out vec4 o_FragColor;
in vec2 textureCoordinate;

void main()
{
    o_FragColor = texture(u_FBOTexture, textureCoordinate);
}

