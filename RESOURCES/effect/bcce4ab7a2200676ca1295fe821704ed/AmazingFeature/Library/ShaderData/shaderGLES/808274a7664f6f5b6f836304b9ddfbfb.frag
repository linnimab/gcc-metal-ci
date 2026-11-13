#version 300 es
#define ae_insert_flip_uniform
#undef ae_insert_flip_uniform
precision highp float;
precision highp int;

uniform mediump sampler2D inputTexture;
uniform mediump sampler2D blendTexture;
uniform mediump sampler2D blur3Texture;
uniform mediump sampler2D blur4Texture;
uniform mediump sampler2D facemaskTexture;
uniform mediump sampler2D skinsegTexture;
uniform mediump float useFaceMask;
uniform mediump float useSkinTex;
uniform mediump float smoothFactor;
uniform mediump float smoothIntensity;
uniform mediump float eyeBrillianceIntensity;
uniform mediump float darkCirclesIntensity;
uniform mediump float smileLinesIntensity;

in vec2 uv;
layout(location = 0) out vec4 o_fragColor;

void main()
{
    vec2 _22 = vec2(uv.x, 1.0 - uv.y);
    mediump vec4 _32 = texture(inputTexture, uv);
    mediump vec4 _37 = texture(blendTexture, uv);
    mediump vec4 _52 = texture(facemaskTexture, _22);
    mediump float _57 = _37.w;
    mediump float _63 = 1.0 - (_57 / (_57 + 0.19099999964237213134765625));
    mediump vec4 _68 = texture(skinsegTexture, _22);
    mediump float _69 = _68.w;
    mediump float _74 = _52.z;
    mediump vec3 _137 = texture(blur4Texture, uv).xyz;
    mediump vec3 _163 = mix(_32.xyz, mix(clamp((_137 + ((((_37.xyz * 0.5) - (texture(blur3Texture, uv).xyz * 0.5)) + vec3(0.5)) * 2.0)) - vec3(1.0), vec3(0.0), vec3(1.0)), _137, vec3(smoothFactor)), vec3(smoothIntensity * ((_69 * _63) * ((1.0 - useFaceMask) * useSkinTex) + (((mix(_69, _74, step(0.00999999977648258209228515625, _74)) * _69) * _63) * (useFaceMask * useSkinTex) + ((_74 * _63) * (useFaceMask * (1.0 - useSkinTex)))))));
    mediump float _170 = _52.y;
    mediump float _171 = step(0.100000001490116119384765625, _170);
    mediump float _174 = _52.x;
    mediump float _175 = step(0.100000001490116119384765625, _174);
    mediump vec3 _205 = mix(_163, max(_163, clamp(_137 + ((_163 - _137) * 2.5), vec3(0.0), vec3(0.60000002384185791015625))), vec3(((eyeBrillianceIntensity * _170) * 1.5) * ((step(0.00999999977648258209228515625, eyeBrillianceIntensity) * _171) * _175)));
    mediump vec3 _248 = mix(_205, min(_205 + clamp(((_137 - _205) * 1.2999999523162841796875) + (_137 * 0.04500000178813934326171875), vec3(0.0), vec3(0.20000000298023223876953125)), vec3(1.0)), vec3((darkCirclesIntensity * _174) * ((step(0.00999999977648258209228515625, darkCirclesIntensity) * _175) * step(_170, 0.5))));
    o_fragColor = vec4(mix(_248, min(_248 + clamp(((_137 - _248) * 5.0) + (_137 * 0.0500000007450580596923828125), vec3(0.0), vec3(1.0)), vec3(1.0)), vec3(((smileLinesIntensity * _170) * 0.300000011920928955078125) * ((step(0.00999999977648258209228515625, smileLinesIntensity) * _171) * step(_174, 0.5)))), _32.w);
}

