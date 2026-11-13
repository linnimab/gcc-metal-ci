#version 300 es
#define ae_insert_flip_uniform
#undef ae_insert_flip_uniform
precision highp float;
precision highp int;

uniform int openMouth;
uniform float _Intensity;
uniform float _Opacity;
uniform highp sampler2D u_FBOTexture;
uniform highp sampler2D _LutTexture;
uniform highp sampler2D _MaskTexture;

in vec2 v2f_materialTexCoord;
in vec2 v2f_texCoord;
layout(location = 0) out vec4 o_FragColor;

void main()
{
    vec4 _213 = texture(u_FBOTexture, v2f_texCoord);
    vec4 _341;
    if (openMouth > 0)
    {
        float _219 = _213.z * 63.0;
        float _221 = floor(_219);
        float _223 = ceil(_219);
        float _227 = clamp(floor(_221 * 0.125), 0.0, 8.0);
        float _239 = clamp(floor(_223 * 0.125), 0.0, 8.0);
        vec2 _252 = vec2(0.0009765625) + (_213.xy * 0.123046875);
        vec2 _256 = (vec2(clamp((-_227) * 8.0 + _221, 0.0, 8.0), _227) * 0.125) + _252;
        vec2 _336 = _256;
        _336.y = 1.0 - _256.y;
        vec2 _264 = (vec2(clamp((-_239) * 8.0 + _223, 0.0, 8.0), _239) * 0.125) + _252;
        vec2 _339 = _264;
        _339.y = 1.0 - _264.y;
        _341 = mix(_213, mix(texture(_LutTexture, _336), texture(_LutTexture, _339), vec4(fract(_219))), vec4(texture(_MaskTexture, v2f_materialTexCoord).x * clamp(_Intensity * _Opacity, 0.0, 1.0)));
    }
    else
    {
        _341 = _213;
    }
    o_FragColor = _341;
}

