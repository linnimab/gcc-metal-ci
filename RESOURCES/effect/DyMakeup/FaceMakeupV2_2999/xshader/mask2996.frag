
#if defined(AE_FRAMEBUFFER_FETCH)
    #if defined(GL_EXT_shader_framebuffer_fetch)
        #extension GL_EXT_shader_framebuffer_fetch : require
    #elif defined(GL_ARM_shader_framebuffer_fetch)
        #extension GL_ARM_shader_framebuffer_fetch : require
    #endif
#endif
#define ae_insert_flip_uniform // FlipPatch will insert flip uniform here

precision highp float;
varying vec2 texCoord;
varying vec2 sucaiTexCoord;
uniform float opacity;

uniform sampler2D u_FBOTexture;
uniform sampler2D sucaiImageTexture;

uniform float intensity;

#ifdef USE_SEG
varying vec2 segCoord;
uniform sampler2D segMaskTexture;
#endif

lowp vec4 textureFromInput()
{
    #if defined(AE_FRAMEBUFFER_FETCH)
        #if defined(GL_EXT_shader_framebuffer_fetch)
            lowp vec4 result = gl_LastFragData[0].rgba;
        #elif defined(GL_ARM_shader_framebuffer_fetch)
            lowp vec4 result = gl_LastFragColorARM;
        #else
            #error AE_FRAMEBUFFER_FETCH but no ext found!
        #endif
    #else
        lowp vec4 result = texture2D(u_FBOTexture, texCoord);
    #endif
    return result;
}


#ifndef BLEND_MULTIPLY
#define BLEND_MULTIPLY

vec3 blendMultiply(vec3 base, vec3 blend) {
    return base * blend;
}

vec3 blendMultiply(vec3 base, vec3 blend, float opacity) {
    return (blendMultiply(base, blend) * opacity + blend * (1.0 - opacity));
}

#endif

#define blendModel blendMultiply

void main(void)
{
    lowp vec4 src = textureFromInput();
    vec4 sucai = texture2D(sucaiImageTexture, sucaiTexCoord) * clamp(intensity * opacity, 0.0, 1.0);

    float nonZeroSrcAlpha = step(0.0, -src.a) * 0.000001 + src.a;
    float nonZeroSucaiAlpha = step(0.0, -sucai.a) * 0.000001 + sucai.a;

    vec3 srcColor = clamp(src.rgb / nonZeroSrcAlpha, 0.0, 1.0);
    vec3 blendColor = blendModel(srcColor, clamp(sucai.rgb / nonZeroSucaiAlpha, 0.0, 1.0));
    blendColor = mix(srcColor, blendColor, sucai.a);
    float blendAlpha = src.a + sucai.a * (1.0 - src.a);

#ifdef USE_SEG
    float seg_opacity = (texture2D(segMaskTexture, segCoord)).x;
    if(clamp(segCoord, 0.0, 1.0) != segCoord) seg_opacity = 1.;
    blendColor = mix(srcColor, blendColor, seg_opacity);
#endif
    gl_FragColor = vec4(blendColor * blendAlpha, blendAlpha);
}
