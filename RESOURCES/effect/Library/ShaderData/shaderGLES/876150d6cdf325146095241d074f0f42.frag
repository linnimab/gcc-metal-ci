#version 300 es
#define ae_insert_flip_uniform
#undef ae_insert_flip_uniform
precision highp float;
precision highp int;

uniform mediump sampler2D _MainTex;
uniform vec4 u_color;
uniform float u_opacity;

in vec2 v_texCoord;
layout(location = 0) out vec4 o_fragColor;

void main()
{
    vec4 _43 = texture(_MainTex, v_texCoord) * u_color;
    vec4 _85 = _43;
    _85.w = _43.w * u_opacity;
    o_fragColor = _85;
}

