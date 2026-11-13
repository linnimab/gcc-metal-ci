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
uniform highp sampler2D u_FBOTexture;

in vec2 v2f_materialTexCoord;
in vec2 v2f_texCoord;
layout(location = 0) out vec4 o_FragColor;

vec4 _512;

void main()
{
    vec4 _275 = texture(_BaseTexture, v2f_materialTexCoord);
    vec4 _476 = _275;
    _476.w = _275.w * clamp(_Intensity * _Opacity, 0.0, 1.0);
    vec4 _502;
    if (_EnableOpacity > 0.5)
    {
        vec4 _295 = _476 * _BaseColor;
        vec4 _480 = _295;
        _480.w = _295.w * texture(_OpacityTexture, v2f_materialTexCoord).x;
        _502 = _480;
    }
    else
    {
        _502 = _476;
    }
    vec4 _320 = texture(u_FBOTexture, v2f_texCoord);
    float _357 = _320.x;
    float _377 = 2.0 * _357;
    float _362 = _320.y;
    float _406 = 2.0 * _362;
    float _367 = _320.z;
    float _435 = 2.0 * _367;
    vec4 _488 = _512;
    _488.x = (_502.x < 0.5) ? (_377 * _502.x + ((_357 * _357) * ((-2.0) * _502.x + 1.0))) : (sqrt(_357) * (2.0 * _502.x + (-1.0)) + (_377 * (1.0 - _502.x)));
    vec4 _490 = _488;
    _490.y = (_502.y < 0.5) ? (_406 * _502.y + ((_362 * _362) * ((-2.0) * _502.y + 1.0))) : (sqrt(_362) * (2.0 * _502.y + (-1.0)) + (_406 * (1.0 - _502.y)));
    vec4 _492 = _490;
    _492.z = (_502.z < 0.5) ? (_435 * _502.z + ((_367 * _367) * ((-2.0) * _502.z + 1.0))) : (sqrt(_367) * (2.0 * _502.z + (-1.0)) + (_435 * (1.0 - _502.z)));
    o_FragColor = vec4(mix(_320.xyz, _492.xyz, vec3(_502.w)), 1.0);
}

