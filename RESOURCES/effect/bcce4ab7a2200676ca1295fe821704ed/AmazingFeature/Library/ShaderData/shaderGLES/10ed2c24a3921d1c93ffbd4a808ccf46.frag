#version 300 es
#define ae_insert_flip_uniform
#undef ae_insert_flip_uniform
precision highp float;
precision highp int;

uniform mediump sampler2D inputImageTexture;
uniform mediump sampler2D _MaskTexture;
uniform mediump float _MaskMinCoord;
uniform mediump float _MaskMaxCoord;

in vec2 texCoord;
in vec2 maskTexCoord;
layout(location = 0) out vec4 o_FragColor;

void main()
{
    o_FragColor = ((texture(inputImageTexture, texCoord) * texture(_MaskTexture, maskTexCoord).x) * step(_MaskMinCoord, maskTexCoord.x)) * step(maskTexCoord.x, _MaskMaxCoord);
}

