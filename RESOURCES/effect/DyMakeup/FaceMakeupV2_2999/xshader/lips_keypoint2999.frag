
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
uniform sampler2D maskImageTexture;
uniform sampler2D lutImageTexture;

uniform float intensity;
uniform int openMouth;

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

vec4 addLipColor(vec4 textureColor)
{
    float blueColor = textureColor.b * 15.0;
    float floorBlurColor = floor(blueColor);
    vec2 quad1;
    quad1.y = max(min(4.0,floor(floorBlurColor * 0.25)),0.0);
    quad1.x = max(min(4.0,floorBlurColor - (quad1.y * 4.0)),0.0);

    float ceilBlurColor = ceil(blueColor);
    vec2 quad2;
    quad2.y = max(min(floor(ceilBlurColor * 0.25),4.0),0.0);
    quad2.x = max(min(ceilBlurColor - (quad2.y * 4.0),4.0),0.0);

    vec2 texPos1;
    texPos1.x = (quad1.x * 0.25) + 0.0078125 + ((0.234375) * textureColor.r);
    texPos1.y = (quad1.y * 0.25) + 0.0078125 + ((0.234375) * textureColor.g);

    vec2 texPos2;
    texPos2.x = (quad2.x * 0.25) + 0.0078125 + ((0.234375) * textureColor.r);
    texPos2.y = (quad2.y * 0.25) + 0.0078125 + ((0.234375) * textureColor.g);

    vec4 newColor1 = texture2D(lutImageTexture, texPos1);
    vec4 newColor2 = texture2D(lutImageTexture, texPos2);

    vec4 newColor = mix(newColor1, newColor2, fract(blueColor));
    return newColor;
}

void main()
{
    lowp vec4 src = textureFromInput();
    vec4 mask = texture2D(maskImageTexture, sucaiTexCoord);
    float alpha = (openMouth > 0) ? mask.g : mask.r;      // close, open, teeth
    vec4 tem = addLipColor(src);
#ifdef USE_SEG
    float seg_opacity = (texture2D(segMaskTexture, segCoord)).x;
    if(clamp(segCoord, 0.0, 1.0) != segCoord) seg_opacity = 1.;
    tem = mix(src, tem, seg_opacity);
#endif
    gl_FragColor = mix(src, tem, alpha * intensity * opacity);
}
