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
    vec4 _202 = texture(_BaseTexture, v2f_materialTexCoord);
    vec4 _279 = _202;
    _279.w = _202.w * clamp(_Intensity * _Opacity, 0.0, 1.0);
    vec4 _292;
    if (_EnableOpacity > 0.5)
    {
        vec4 _222 = _279 * _BaseColor;
        vec4 _283 = _222;
        _283.w = _222.w * texture(_OpacityTexture, v2f_materialTexCoord).x;
        _292 = _283;
    }
    else
    {
        _292 = _279;
    }
    vec3 _262 = ((_292.xyz * _292.w) + vec3(1.0)) - vec3(_292.w);
    vec4 _287 = _292;
    _287.x = _262.x;
    vec4 _289 = _287;
    _289.y = _262.y;
    vec4 _291 = _289;
    _291.z = _262.z;
    o_FragColor = _291;
}

