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
uniform float _Intensity;
uniform float _Opacity;
uniform float _EnableOpacity;
uniform vec4 _BaseColor;
uniform highp sampler2D _BaseTexture;
uniform highp sampler2D _OpacityTexture;

in vec2 v2f_materialTexCoord;
layout(location = 0) FRAME_BUFFERFETCH_STORAGE_QUALIFIER vec4 o_FragColor;

vec4 _508;

void main()
{
    subpass0 = _Globals_gl_LastFragColor;
    vec4 _275 = texture(_BaseTexture, v2f_materialTexCoord);
    vec4 _472 = _275;
    _472.w = _275.w * clamp(_Intensity * _Opacity, 0.0, 1.0);
    vec4 _498;
    if (_EnableOpacity > 0.5)
    {
        vec4 _295 = _472 * _BaseColor;
        vec4 _476 = _295;
        _476.w = _295.w * texture(_OpacityTexture, v2f_materialTexCoord).x;
        _498 = _476;
    }
    else
    {
        _498 = _472;
    }
    vec4 _317 = subpass0;
    float _354 = _317.x;
    float _374 = 2.0 * _354;
    float _359 = _317.y;
    float _403 = 2.0 * _359;
    float _364 = _317.z;
    float _432 = 2.0 * _364;
    vec4 _484 = _508;
    _484.x = (_498.x < 0.5) ? (_374 * _498.x + ((_354 * _354) * ((-2.0) * _498.x + 1.0))) : (sqrt(_354) * (2.0 * _498.x + (-1.0)) + (_374 * (1.0 - _498.x)));
    vec4 _486 = _484;
    _486.y = (_498.y < 0.5) ? (_403 * _498.y + ((_359 * _359) * ((-2.0) * _498.y + 1.0))) : (sqrt(_359) * (2.0 * _498.y + (-1.0)) + (_403 * (1.0 - _498.y)));
    vec4 _488 = _486;
    _488.z = (_498.z < 0.5) ? (_432 * _498.z + ((_364 * _364) * ((-2.0) * _498.z + 1.0))) : (sqrt(_364) * (2.0 * _498.z + (-1.0)) + (_432 * (1.0 - _498.z)));
    o_FragColor = vec4(mix(_317.xyz, _488.xyz, vec3(_498.w)), 1.0);
}

