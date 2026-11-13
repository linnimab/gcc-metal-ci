#version 300 es

uniform mat4 mvpMat;

layout(location = 0) in vec3 attPosition;
out vec2 uv;
layout(location = 1) in vec2 attTexcoord0;
out vec2 uv_screen;

void main()
{
    gl_Position = mvpMat * vec4(attPosition.xy, 0.0, 1.0);
    uv = attTexcoord0;
    uv = vec2(attTexcoord0.x, 1.0 - attTexcoord0.y);
    uv_screen = ((gl_Position.xy / vec2(gl_Position.w)) * 0.5) + vec2(0.5);
}

