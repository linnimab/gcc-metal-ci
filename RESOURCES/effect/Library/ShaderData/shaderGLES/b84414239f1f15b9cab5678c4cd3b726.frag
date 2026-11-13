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
uniform float _Exposure;
uniform float _Brightness;
uniform float _Temperature;
uniform float _Tint;
uniform float _Contrast;
uniform float _Saturation;
uniform highp sampler2D _LutTexture;

layout(location = 0) FRAME_BUFFERFETCH_STORAGE_QUALIFIER vec4 o_FragColor;

void main()
{
    subpass0 = _Globals_gl_LastFragColor;
    vec4 _452 = subpass0;
    float _457 = floor(_452.z * 63.0);
    float _459 = floor(_457 * 0.125);
    vec2 _475 = ((vec2((-_459) * 8.0 + _457, _459) * 0.125) + vec2(0.0009765625)) + (_452.xy * 0.123046875);
    vec2 _717 = _475;
    _717.y = 1.0 - _475.y;
    float _491 = _452.w;
    vec3 _494 = mix(_452.xyz, texture(_LutTexture, _717).xyz, vec3(_Intensity * _491));
    vec4 _720 = _452;
    _720.x = _494.x;
    vec4 _722 = _720;
    _722.y = _494.y;
    vec4 _724 = _722;
    _724.z = _494.z;
    vec3 _509 = _724.xyz * pow(2.0, _Exposure * _491);
    vec4 _727 = _724;
    _727.x = _509.x;
    vec4 _729 = _727;
    _729.y = _509.y;
    vec4 _731 = _729;
    _731.z = _509.z;
    vec3 _522 = _731.xyz + vec3(_Brightness * _491);
    vec4 _733 = _731;
    _733.x = _522.x;
    vec4 _735 = _733;
    _735.y = _522.y;
    vec4 _737 = _735;
    _737.z = _522.z;
    float _534 = _Temperature * _491;
    float _616 = (_534 * (-1.5384614467620849609375)) * (((_534 * 1.5384614467620849609375) < 0.0) ? 0.100000001490116119384765625 : 0.0500000007450580596923828125) + 0.312709987163543701171875;
    float _621 = (_Tint * _491) * 0.076923072338104248046875 + ((2.86999988555908203125 * _616 + (-((3.0 * _616) * _616))) - 0.2750950753688812255859375);
    float _663 = _616 / _621;
    float _671 = ((1.0 - _616) - _621) / _621;
    vec3 _705 = mat3(vec3(2.85846996307373046875, -1.62879002094268798828125, -0.0248910002410411834716796875), vec3(-0.21018199622631072998046875, 1.1582000255584716796875, 0.0003242809907533228397369384765625), vec3(-0.0418119989335536956787109375, -0.118169002234935760498046875, 1.0686700344085693359375)) * ((mat3(vec3(0.390404999256134033203125, 0.549941003322601318359375, 0.008926319889724254608154296875), vec3(0.070841602981090545654296875, 0.963172018527984619140625, 0.001357750035822391510009765625), vec3(0.02310819923877716064453125, 0.1280210018157958984375, 0.936245024204254150390625)) * _737.xyz) * vec3(0.94923698902130126953125 / ((-0.1624000072479248046875) * _671 + (0.732800006866455078125 * _663 + 0.4296000003814697265625)), 1.035419940948486328125 / (0.006099999882280826568603515625 * _671 + ((-0.703599989414215087890625) * _663 + 1.6974999904632568359375)), 1.0872800350189208984375 / (0.98339998722076416015625 * _671 + (0.0030000000260770320892333984375 * _663 + 0.013600000180304050445556640625))));
    vec4 _745 = _737;
    _745.x = _705.x;
    vec4 _747 = _745;
    _747.y = _705.y;
    vec4 _749 = _747;
    _749.z = _705.z;
    vec3 _561 = ((_749.xyz - vec3(0.21763764321804046630859375)) * (_Contrast * _491 + 1.0)) + vec3(0.21763764321804046630859375);
    vec4 _751 = _749;
    _751.x = _561.x;
    vec4 _753 = _751;
    _753.y = _561.y;
    vec4 _755 = _753;
    _755.z = _561.z;
    vec3 _580 = mix(vec3(dot(_755.xyz, vec3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875))), _755.xyz, vec3(_Saturation * _491 + 1.0));
    vec4 _757 = _755;
    _757.x = _580.x;
    vec4 _759 = _757;
    _759.y = _580.y;
    vec4 _761 = _759;
    _761.z = _580.z;
    o_FragColor = _761;
}

