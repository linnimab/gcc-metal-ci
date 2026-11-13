#version 300 es
#define ae_insert_flip_uniform
#undef ae_insert_flip_uniform

uniform float texBlurWidthOffset;
uniform float texBlurHeightOffset;

layout(location = 0) in vec3 attPosition;
out vec2 textureCoordinate;
layout(location = 1) in vec2 attTexcoord0;
out vec4 textureShift_1;
out vec4 textureShift_2;
out vec4 textureShift_3;
out vec4 textureShift_4;

void main()
{
    gl_Position = vec4(attPosition, 1.0);
    textureCoordinate = attTexcoord0;
    vec2 _35 = vec2(texBlurWidthOffset * 2.5, texBlurHeightOffset * 2.5);
    textureShift_1 = vec4(textureCoordinate - _35, textureCoordinate + _35);
    vec2 _52 = _35 * 2.0;
    textureShift_2 = vec4(textureCoordinate - _52, textureCoordinate + _52);
    vec2 _67 = _35 * 3.0;
    textureShift_3 = vec4(textureCoordinate - _67, textureCoordinate + _67);
    vec2 _82 = _35 * 4.0;
    textureShift_4 = vec4(textureCoordinate - _82, textureCoordinate + _82);
}

