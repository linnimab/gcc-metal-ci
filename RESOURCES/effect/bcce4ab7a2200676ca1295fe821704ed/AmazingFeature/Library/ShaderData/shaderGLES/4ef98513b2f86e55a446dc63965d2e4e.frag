#version 300 es
#define ae_insert_flip_uniform
#undef ae_insert_flip_uniform
precision highp float;
precision highp int;

uniform int openMouth;
uniform float _Intensity;
uniform float _Opacity;
uniform float _EnableOpacity;
uniform vec4 _BaseColor;
uniform highp sampler2D _BaseTexture;
uniform highp sampler2D _MaskTexture;
uniform highp sampler2D _OpacityTexture;

in vec2 v2f_materialTexCoord;
layout(location = 0) out vec4 o_FragColor;

void main()
{
    vec4 _188 = texture(_BaseTexture, v2f_materialTexCoord);
    vec4 _254 = _188;
    _254.w = _188.w * (((openMouth > 0) ? texture(_MaskTexture, v2f_materialTexCoord).x : 1.0) * clamp(_Intensity * _Opacity, 0.0, 1.0));
    vec4 _259;
    if (_EnableOpacity > 0.5)
    {
        vec4 _219 = _254 * _BaseColor;
        vec4 _258 = _219;
        _258.w = _219.w * texture(_OpacityTexture, v2f_materialTexCoord).x;
        _259 = _258;
    }
    else
    {
        _259 = _254;
    }
    o_FragColor = _259;
}

