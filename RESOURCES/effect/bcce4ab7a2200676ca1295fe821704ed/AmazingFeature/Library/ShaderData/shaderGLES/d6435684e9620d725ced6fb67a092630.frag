#version 300 es
#define ae_insert_flip_uniform
#undef ae_insert_flip_uniform
precision highp float;
precision highp int;

uniform float _Ratio;
uniform vec4 _AlbedoColor;
uniform vec4 _AlbedoColor2;
uniform mediump int _GradientType;
uniform mediump sampler2D _AlbedoTexture;

in vec2 g_vary_uv0;
in mediump float indexRatio;
layout(location = 0) out vec4 o_fragColor;

void main()
{
    vec2 _144;
    if (_Ratio < 1.0)
    {
        vec2 _133 = g_vary_uv0;
        _133.x = ((g_vary_uv0.x - 0.5) / _Ratio) + 0.5;
        _144 = _133;
    }
    else
    {
        vec2 _136 = g_vary_uv0;
        _136.y = (g_vary_uv0.y - 0.5) * _Ratio + 0.5;
        _144 = _136;
    }
    vec4 _146;
    if (_GradientType == 1)
    {
        _146 = mix(_AlbedoColor, _AlbedoColor2, vec4(indexRatio));
    }
    else
    {
        vec4 _147;
        if (indexRatio <= 0.5)
        {
            _147 = mix(_AlbedoColor, _AlbedoColor2, vec4(indexRatio * 2.0));
        }
        else
        {
            _147 = mix(_AlbedoColor2, _AlbedoColor, vec4((indexRatio - 0.5) * 2.0));
        }
        _146 = _147;
    }
    mediump vec4 _96 = texture(_AlbedoTexture, _144);
    vec4 _98 = _96 * _146;
    bool _102 = _144.x < 0.0;
    bool _109;
    if (!_102)
    {
        _109 = _144.x > 1.0;
    }
    else
    {
        _109 = _102;
    }
    bool _116;
    if (!_109)
    {
        _116 = _144.y < 0.0;
    }
    else
    {
        _116 = _109;
    }
    bool _123;
    if (!_116)
    {
        _123 = _144.y > 1.0;
    }
    else
    {
        _123 = _116;
    }
    vec4 _153;
    if (_123)
    {
        vec4 _142 = _98;
        _142.w = 0.0;
        _153 = _142;
    }
    else
    {
        _153 = _98;
    }
    o_fragColor = _153;
}

