#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct buffer_t
{
    float _Intensity;
    float _Exposure;
    float _Brightness;
    float _Temperature;
    float _Tint;
    float _Contrast;
    float _Saturation;
};

struct main0_out
{
    float4 o_FragColor [[color(0)]];
};

struct main0_in
{
    float2 v2f_v_texCoord [[user(locn0)]];
};

fragment main0_out main0(main0_in in [[stage_in]], constant buffer_t& buffer, texture2d<float> u_FBOTexture [[texture(0)]], texture2d<float> _LutTexture [[texture(1)]], sampler u_FBOTextureSmplr [[sampler(0)]], sampler _LutTextureSmplr [[sampler(1)]])
{
    main0_out out = {};
    float4 _455 = u_FBOTexture.sample(u_FBOTextureSmplr, in.v2f_v_texCoord);
    float _460 = floor(_455.z * 63.0);
    float _462 = floor(_460 * 0.125);
    float2 _478 = ((float2(fma(-_462, 8.0, _460), _462) * 0.125) + float2(0.0009765625)) + (_455.xy * 0.123046875);
    float2 _728 = _478;
    _728.y = 1.0 - _478.y;
    float _494 = _455.w;
    float3 _497 = mix(_455.xyz, _LutTexture.sample(_LutTextureSmplr, _728).xyz, float3(buffer._Intensity * _494));
    float4 _731 = _455;
    _731.x = _497.x;
    float4 _733 = _731;
    _733.y = _497.y;
    float4 _735 = _733;
    _735.z = _497.z;
    float3 _512 = _735.xyz * pow(2.0, buffer._Exposure * _494);
    float4 _738 = _735;
    _738.x = _512.x;
    float4 _740 = _738;
    _740.y = _512.y;
    float4 _742 = _740;
    _742.z = _512.z;
    float3 _525 = _742.xyz + float3(buffer._Brightness * _494);
    float4 _744 = _742;
    _744.x = _525.x;
    float4 _746 = _744;
    _746.y = _525.y;
    float4 _748 = _746;
    _748.z = _525.z;
    float _537 = buffer._Temperature * _494;
    float _619 = fma(_537 * (-1.5384614467620849609375), ((_537 * 1.5384614467620849609375) < 0.0) ? 0.100000001490116119384765625 : 0.0500000007450580596923828125, 0.312709987163543701171875);
    float _624 = fma(buffer._Tint * _494, 0.076923072338104248046875, fma(2.86999988555908203125, _619, -((3.0 * _619) * _619)) - 0.2750950753688812255859375);
    float _666 = _619 / _624;
    float _674 = ((1.0 - _619) - _624) / _624;
    float3 _708 = float3x3(float3(2.85846996307373046875, -1.62879002094268798828125, -0.0248910002410411834716796875), float3(-0.21018199622631072998046875, 1.1582000255584716796875, 0.0003242809907533228397369384765625), float3(-0.0418119989335536956787109375, -0.118169002234935760498046875, 1.0686700344085693359375)) * ((float3x3(float3(0.390404999256134033203125, 0.549941003322601318359375, 0.008926319889724254608154296875), float3(0.070841602981090545654296875, 0.963172018527984619140625, 0.001357750035822391510009765625), float3(0.02310819923877716064453125, 0.1280210018157958984375, 0.936245024204254150390625)) * _748.xyz) * float3(0.94923698902130126953125 / fma(-0.1624000072479248046875, _674, fma(0.732800006866455078125, _666, 0.4296000003814697265625)), 1.035419940948486328125 / fma(0.006099999882280826568603515625, _674, fma(-0.703599989414215087890625, _666, 1.6974999904632568359375)), 1.0872800350189208984375 / fma(0.98339998722076416015625, _674, fma(0.0030000000260770320892333984375, _666, 0.013600000180304050445556640625))));
    float4 _756 = _748;
    _756.x = _708.x;
    float4 _758 = _756;
    _758.y = _708.y;
    float4 _760 = _758;
    _760.z = _708.z;
    float3 _564 = ((_760.xyz - float3(0.21763764321804046630859375)) * fma(buffer._Contrast, _494, 1.0)) + float3(0.21763764321804046630859375);
    float4 _762 = _760;
    _762.x = _564.x;
    float4 _764 = _762;
    _764.y = _564.y;
    float4 _766 = _764;
    _766.z = _564.z;
    float3 _583 = mix(float3(dot(_766.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875))), _766.xyz, float3(fma(buffer._Saturation, _494, 1.0)));
    float4 _768 = _766;
    _768.x = _583.x;
    float4 _770 = _768;
    _770.y = _583.y;
    float4 _772 = _770;
    _772.z = _583.z;
    out.o_FragColor = _772;
    return out;
}

