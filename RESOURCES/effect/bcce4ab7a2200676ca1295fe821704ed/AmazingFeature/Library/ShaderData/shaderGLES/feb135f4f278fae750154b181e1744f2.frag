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

uniform int openMouth;
uniform float _Intensity;
uniform float _Opacity;
uniform float _EnableOpacity;
uniform vec4 _BaseColor;
uniform highp sampler2D _BaseTexture;
uniform highp sampler2D _MaskTexture;
uniform highp sampler2D _OpacityTexture;

in vec2 v2f_materialTexCoord;
layout(location = 0) FRAME_BUFFERFETCH_STORAGE_QUALIFIER vec4 o_FragColor;

void main()
{
    vec4 _189 = texture(_BaseTexture, v2f_materialTexCoord);
    vec4 _255 = _189;
    _255.w = _189.w * (((openMouth > 0) ? texture(_MaskTexture, v2f_materialTexCoord).x : 1.0) * clamp(_Intensity * _Opacity, 0.0, 1.0));
    vec4 _260;
    if (_EnableOpacity > 0.5)
    {
        vec4 _220 = _255 * _BaseColor;
        vec4 _259 = _220;
        _259.w = _220.w * texture(_OpacityTexture, v2f_materialTexCoord).x;
        _260 = _259;
    }
    else
    {
        _260 = _255;
    }
    o_FragColor = _260;
}

