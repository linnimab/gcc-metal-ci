#version 300 es
#define ae_insert_flip_uniform
#undef ae_insert_flip_uniform

uniform mat4 uMVPMatrix;

layout(location = 0) in vec3 attPosition;
out vec2 texCoord;
out vec2 sucaiTexCoord;
layout(location = 1) in vec3 attTexcoord3D0;
out float weight;

void main()
{
    gl_Position = uMVPMatrix * vec4(attPosition.xy, 0.0, 1.0);
    texCoord = (gl_Position.xy * 0.5) + vec2(0.5);
    sucaiTexCoord = attTexcoord3D0.xy;
    weight = attPosition.z * 2.0;
}

