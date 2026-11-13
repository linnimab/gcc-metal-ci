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

in vec2 texCoord;
in vec2 sucaiTexCoord;
in float weight;
layout(location = 0) out vec4 o_FragColor;

void main()
{
    mediump vec4 _48 = texture(_InputTexture, texCoord);
    mediump vec4 _54 = texture(_BaseTexture, sucaiTexCoord);
    vec4 _172 = _54;
    _172.w = _54.w * clamp(_Intensity * _Opacity, 0.0, 1.0);
    vec4 _182;
    if (_EnableOpacity > 0.5)
    {
        vec4 _86 = _172 * _BaseColor;
        vec4 _176 = _86;
        _176.w = _86.w * texture(_OpacityTexture, sucaiTexCoord).x;
        _182 = _176;
    }
    else
    {
        _182 = _172;
    }
    vec3 _183;
    if (_EnableReflection > 0.5)
    {
        _183 = texture(_ReflectionTexture, sucaiTexCoord).xyz;
    }
    else
    {
        _183 = mix(_48.xyz, _182.xyz, vec3(_182.w * weight));
    }
    o_FragColor = vec4(_183, _48.w);
}

