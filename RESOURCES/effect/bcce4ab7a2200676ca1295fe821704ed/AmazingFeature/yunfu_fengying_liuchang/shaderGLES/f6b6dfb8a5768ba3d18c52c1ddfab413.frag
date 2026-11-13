#version 300 es
precision highp float;
precision highp int;

uniform mediump sampler2D maskTexture;
uniform mediump sampler2D flowTexture;
uniform mediump float flowLevel;
uniform mat4 mvpMat;
uniform mediump sampler2D ganTexture;
uniform mediump sampler2D _MainTex;
uniform mediump float transparency;
uniform mediump float enable;
uniform mediump float isGan;
uniform mediump float alphaMut;

in highp vec2 uv;
in highp vec2 uv_screen;
layout(location = 0) out mediump vec4 color;

void main()
{
    mediump vec4 _19 = texture(maskTexture, uv);
    mediump float _22 = _19.x;
    mediump vec4 _42 = (((texture(flowTexture, uv) - vec4(0.5)) * 0.125) * _22) * clamp(flowLevel, 0.0, 1.0);
    mediump vec4 _72 = texture(ganTexture, uv);
    color = mix(vec4(texture(_MainTex, uv_screen + (mvpMat * vec4(_42.x, -_42.y, 0.0, 0.0)).xy).xyz, (_22 * transparency) * enable), vec4(mix(texture(_MainTex, uv_screen).xyz, _72.xyz, vec3((_72.w * transparency) * _22)), enable), vec4(isGan));
    color.a *= alphaMut;
}
