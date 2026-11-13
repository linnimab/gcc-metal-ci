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
uniform highp sampler2D segMaskTexture;

in vec2 v2f_materialTexCoord;
in vec2 v2f_segCoord;
layout(location = 0) out vec4 o_FragColor;

void main()
{
    vec4 _255 = texture(_BaseTexture, v2f_materialTexCoord);
    vec4 _375 = _255;
    _375.w = _255.w * (((openMouth > 0) ? texture(_MaskTexture, v2f_materialTexCoord).x : 1.0) * clamp(_Intensity * _Opacity, 0.0, 1.0));
    vec4 _396;
    if (_EnableOpacity > 0.5)
    {
        vec4 _286 = _375 * _BaseColor;
        vec4 _379 = _286;
        _379.w = _286.w * texture(_OpacityTexture, v2f_materialTexCoord).x;
        _396 = _379;
    }
    else
    {
        _396 = _375;
    }
    float _320 = _396.w * (((clamp(v2f_segCoord.x, 0.0, 1.0) != v2f_segCoord.x) || (clamp(v2f_segCoord.y, 0.0, 1.0) != v2f_segCoord.y)) ? 1.0 : texture(segMaskTexture, v2f_segCoord).x);
    o_FragColor = vec4(((_396.xyz * _320) + vec3(1.0)) - vec3(_320), _320);
}

