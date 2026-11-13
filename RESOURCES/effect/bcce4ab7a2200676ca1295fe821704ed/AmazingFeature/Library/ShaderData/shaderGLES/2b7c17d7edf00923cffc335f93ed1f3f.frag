#version 300 es
#define ae_insert_flip_uniform
#undef ae_insert_flip_uniform
precision highp float;
precision highp int;

uniform mediump sampler2D _InputTexture;
uniform mediump sampler2D _BaseTexture;
uniform float _Intensity;
uniform float _Opacity;
uniform float _EnableOpacity;
uniform mediump sampler2D _OpacityTexture;
uniform vec4 _BaseColor;
uniform float _EnableReflection;
uniform mediump sampler2D _ReflectionTexture;
uniform float _ReflectionIntensity;
uniform float _ReflectionOpacity;

in vec2 texCoord;
in vec2 sucaiTexCoord;
in float weight;
layout(location = 0) out vec4 o_FragColor;

void main()
{
    mediump vec4 _119 = texture(_InputTexture, texCoord);
    mediump vec4 _125 = texture(_BaseTexture, sucaiTexCoord);
    vec4 _292 = _125;
    _292.w = _125.w * clamp(_Intensity * _Opacity, 0.0, 1.0);
    vec4 _303;
    if (_EnableOpacity > 0.5)
    {
        vec4 _156 = _292 * _BaseColor;
        vec4 _296 = _156;
        _296.w = _156.w * texture(_OpacityTexture, sucaiTexCoord).x;
        _303 = _296;
    }
    else
    {
        _303 = _292;
    }
    vec3 _166 = _119.xyz;
    vec3 _250 = (((_166 - vec3(1.0)) * (vec3(1.0) - _303.xyz) + vec3(1.0)) * (_303.w * weight)) + (_166 * ((-_303.w) * weight + 1.0));
    vec3 _304;
    if (_EnableReflection > 0.5)
    {
        mediump vec4 _192 = texture(_ReflectionTexture, sucaiTexCoord);
        float _201 = _192.w * clamp(_ReflectionIntensity * _ReflectionOpacity, 0.0, 1.0);
        _304 = ((_250 * _192.xyz) * (_201 * weight)) + (_250 * ((-_201) * weight + 1.0));
    }
    else
    {
        _304 = _250;
    }
    o_FragColor = vec4(_304, _119.w);
}

