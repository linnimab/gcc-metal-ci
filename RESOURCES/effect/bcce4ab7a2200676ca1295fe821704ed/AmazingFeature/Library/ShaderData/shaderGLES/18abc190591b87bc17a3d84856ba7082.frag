#version 300 es
#ifdef GL_EXT_shader_framebuffer_fetch
#extension GL_EXT_shader_framebuffer_fetch : enable
#define FRAME_BUFFERFETCH_STORAGE_QUALIFIER inout
#define _Globals_gl_LastFragColor 
#elif defined(GL_ARM_shader_framebuffer_fetch)
#extension GL_ARM_shader_framebuffer_fetch : enable
#define FRAME_BUFFERFETCH_STORAGE_QUALIFIER out
#define _Globals_gl_LastFragColor gl_LastFragColorARM
#endif
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
layout(location = 0) FRAME_BUFFERFETCH_STORAGE_QUALIFIER vec4 o_FragColor;

void main()
{
    vec4 _203 = texture(_BaseTexture, v2f_materialTexCoord);
    vec4 _280 = _203;
    _280.w = _203.w * clamp(_Intensity * _Opacity, 0.0, 1.0);
    vec4 _293;
    if (_EnableOpacity > 0.5)
    {
        vec4 _223 = _280 * _BaseColor;
        vec4 _284 = _223;
        _284.w = _223.w * texture(_OpacityTexture, v2f_materialTexCoord).x;
        _293 = _284;
    }
    else
    {
        _293 = _280;
    }
    vec3 _263 = ((_293.xyz * _293.w) + vec3(1.0)) - vec3(_293.w);
    vec4 _288 = _293;
    _288.x = _263.x;
    vec4 _290 = _288;
    _290.y = _263.y;
    vec4 _292 = _290;
    _292.z = _263.z;
    o_FragColor = _292;
}

