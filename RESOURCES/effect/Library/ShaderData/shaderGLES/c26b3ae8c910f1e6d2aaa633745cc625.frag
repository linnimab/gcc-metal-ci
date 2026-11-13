#version 300 es
#ifdef GL_EXT_shader_framebuffer_fetch
#extension GL_EXT_shader_framebuffer_fetch : enable
#define FRAME_BUFFERFETCH_STORAGE_QUALIFIER inout
#define _Globals_gl_LastFragColor o_FragColor
#elif defined(GL_ARM_shader_framebuffer_fetch)
#extension GL_ARM_shader_framebuffer_fetch : enable
#define FRAME_BUFFERFETCH_STORAGE_QUALIFIER out
#define _Globals_gl_LastFragColor gl_LastFragColorARM
#endif
#define ae_insert_flip_uniform
#undef ae_insert_flip_uniform
precision highp float;
precision highp int;

highp vec4 subpass0;
uniform int openMouth;
uniform float _Intensity;
uniform float _Opacity;
uniform highp sampler2D _LutTexture;
uniform highp sampler2D _MaskTexture;

in vec2 v2f_materialTexCoord;
layout(location = 0) FRAME_BUFFERFETCH_STORAGE_QUALIFIER vec4 o_FragColor;

void main()
{
    subpass0 = _Globals_gl_LastFragColor;
    vec4 _208 = subpass0;
    vec4 _335;
    if (openMouth > 0)
    {
        float _214 = _208.z * 63.0;
        float _216 = floor(_214);
        float _218 = ceil(_214);
        float _222 = clamp(floor(_216 * 0.125), 0.0, 8.0);
        float _234 = clamp(floor(_218 * 0.125), 0.0, 8.0);
        vec2 _247 = vec2(0.0009765625) + (_208.xy * 0.123046875);
        vec2 _251 = (vec2(clamp((-_222) * 8.0 + _216, 0.0, 8.0), _222) * 0.125) + _247;
        vec2 _330 = _251;
        _330.y = 1.0 - _251.y;
        vec2 _259 = (vec2(clamp((-_234) * 8.0 + _218, 0.0, 8.0), _234) * 0.125) + _247;
        vec2 _333 = _259;
        _333.y = 1.0 - _259.y;
        _335 = mix(_208, mix(texture(_LutTexture, _330), texture(_LutTexture, _333), vec4(fract(_214))), vec4(texture(_MaskTexture, v2f_materialTexCoord).x * clamp(_Intensity * _Opacity, 0.0, 1.0)));
    }
    else
    {
        _335 = _208;
    }
    o_FragColor = _335;
}

