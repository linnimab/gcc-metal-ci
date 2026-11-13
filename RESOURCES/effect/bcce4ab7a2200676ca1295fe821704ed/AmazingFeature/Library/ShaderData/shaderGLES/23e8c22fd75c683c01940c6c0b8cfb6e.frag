#version 300 es
#define ae_insert_flip_uniform
#undef ae_insert_flip_uniform
precision highp float;
precision highp int;

uniform float _Intensity;
uniform float _Opacity;
uniform float _EnableOpacity;
uniform vec4 _BaseColor;
uniform highp sampler2D _BaseTexture;
uniform highp sampler2D _OpacityTexture;

in vec2 v2f_materialTexCoord;
layout(location = 0) out vec4 o_FragColor;

void main()
{
    vec4 _173 = texture(_BaseTexture, v2f_materialTexCoord);
    vec4 _228 = _173;
    _228.w = _173.w * clamp(_Intensity * _Opacity, 0.0, 1.0);
    vec4 _233;
    if (_EnableOpacity > 0.5)
    {
        vec4 _193 = _228 * _BaseColor;
        vec4 _232 = _193;
        _232.w = _193.w * texture(_OpacityTexture, v2f_materialTexCoord).x;
        _233 = _232;
    }
    else
    {
        _233 = _228;
    }
    o_FragColor = _233;
}

