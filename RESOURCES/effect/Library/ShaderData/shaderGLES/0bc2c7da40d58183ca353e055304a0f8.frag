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
uniform highp sampler2D segMaskTexture;

in vec2 v2f_materialTexCoord;
in vec2 v2f_segCoord;
layout(location = 0) FRAME_BUFFERFETCH_STORAGE_QUALIFIER vec4 o_FragColor;

void main()
{
    vec4 _256 = texture(_BaseTexture, v2f_materialTexCoord);
    vec4 _376 = _256;
    _376.w = _256.w * (((openMouth > 0) ? texture(_MaskTexture, v2f_materialTexCoord).x : 1.0) * clamp(_Intensity * _Opacity, 0.0, 1.0));
    vec4 _397;
    if (_EnableOpacity > 0.5)
    {
        vec4 _287 = _376 * _BaseColor;
        vec4 _380 = _287;
        _380.w = _287.w * texture(_OpacityTexture, v2f_materialTexCoord).x;
        _397 = _380;
    }
    else
    {
        _397 = _376;
    }
    float _321 = _397.w * (((clamp(v2f_segCoord.x, 0.0, 1.0) != v2f_segCoord.x) || (clamp(v2f_segCoord.y, 0.0, 1.0) != v2f_segCoord.y)) ? 1.0 : texture(segMaskTexture, v2f_segCoord).x);
    o_FragColor = vec4(((_397.xyz * _321) + vec3(1.0)) - vec3(_321), _321);
}

