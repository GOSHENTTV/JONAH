//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// ENBSeries TES Skyrim SE hlsl DX11 format, example adaptation
// visit http://enbdev.com for updates
// Author: Boris Vorontsov
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++



//+++++++++++++++++++++++++++++
//internal parameters, modify or add new
//+++++++++++++++++++++++++++++



//+++++++++++++++++++++++++++++
//external enb parameters, do not modify
//+++++++++++++++++++++++++++++

#include "ENBFeeder.fxh"

float CloudSpeed < string UIName = "Clouds:: Speed"; float UIMin = 0.0; float UIMax = 10.0; > = { 1.0 };
float CloudDensity < string UIName = "Clouds:: Density"; float UIMin = 0.0; float UIMax = 1.0; > = { 0.5 };

float4 ApplyClouds(float4 originalColor, float2 texCoord, float timer, Texture2D noiseTexture, sampler noiseSampler)
{
    float2 noise_coord = texCoord + (timer * CloudSpeed * 0.01);
    float noise = noiseTexture.Sample(noiseSampler, noise_coord).x;
    noise *= CloudDensity;
    return originalColor + noise;
}

float4 Timer;
float4 ScreenSize;
float4 Weather;
Texture2D TextureDownsampled;
Texture2D TextureColor;
Texture2D TextureOriginal;
Texture2D TextureDepth;
Texture2D RenderTarget1024;
Texture2D RenderTarget512;
Texture2D RenderTarget256;
Texture2D RenderTarget128;
Texture2D RenderTarget64;
Texture2D RenderTarget32;
Texture2D RenderTargetRGBA32;
Texture2D RenderTargetRGBA64F;
Texture2D noisetex < string ResourceName = "JonahPN/18690.png"; > ;
Texture2D ray < string ResourceName = "JonahPN/lightning.png"; > ;
Texture2D shape < string ResourceName = "JonahPN/LensRain.png"; > ;

static const float2 rcpFrame = float2(ScreenSize.y, ScreenSize.y * ScreenSize.z);
float b < string UIName = "Bloom:: Intensity"; float UIMin = 0.0; float UIMax = 0.25; float UIStep = 0.0005; > = { 0.067 };
int separator0 < string UIName = " "; int UIMin = 0; int UIMax = 0; > = { 0 };
bool gp < string UIName = "GPLens"; > = { false };
float gpi < string UIName = "GPLens:: Intensity"; float UIMin = 0.0; float UIMax = 0.1; float UIStep = 0.0001; > = { 0.0004 };
float gpt < string UIName = "GPLens:: Threshold"; float UIMin = 0.0; float UIMax = 60.0; > = { 29.0 };
float gpca < string UIName = "GPLens:: Chroma Distort"; float UIStep = 0.0001; > = { 0.01 };
float gpfd < string UIName = "GPLens:: Flare Dispersal"; float UIMin = 0.0; float UIMax = 10.0; > = { 1.25 };
float gphw < string UIName = "GPLens:: Halo Width"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.005; > = { 0.5 };
float gpdesat < string UIName = "GPLens:: Desaturate"; > = { 1.0 };
float3 gptint < string UIName = "GPLens:: Tint"; string UIWidget = "color"; > = { 1.0, 1.0, 1.0 };
int separator1 < string UIName = "  "; int UIMin = 0; int UIMax = 0; > = { 0 };
float3 rcol < string UIName = "MoonRay:: Color"; string UIWidget = "color"; > = { 0.25, 0.31, 0.44 };
float rin < string UIName = "MoonRay:: Intensity"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.0005; > = { 0.175 };
float rwi < string UIName = "MoonRay:: Spread"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.0005; > = { 0.05 };
float rde < string UIName = "MoonRay:: Decay"; float UIMin = 0.0; float UIMax = 100.0; float UIStep = 0.1; > = { 0.0 };
float rca < string UIName = "MoonRay:: CA"; float UIMin = -10.0; float UIMax = 10.0; float UIStep = 0.05; > = { 1.5 };
float rsc < string UIName = "MoonRay:: FrameScaling"; float UIMin = 0.05; float UIMax = 1.0; float UIStep = 0.0025; > = { 0.75 };
int separator2 < string UIName = "   "; int UIMin = 0; int UIMax = 0; > = { 0 };
float lintensity < string UIName = "RainLens:: Intensity"; float UIMin = 0.0; float UIMax = 10.0; > = { 1.0 };
float lsize < string UIName = "RainLens:: Size"; float UIStep = 0.001; > = { 0.05 };
float lspeed < string UIName = "RainLens:: Speed"; float UIMin = 0.001; float UIMax = 100.0; float UIStep = 0.1; > = { 21.0 };
float grad < string UIName = "RainLens:: Gradient"; > = { 0.4 };
float VigOffset < string UIName = "RainLens:: Vignette"; float UIStep = 0.001; > = { 0.225 };
float llight < string UIName = "RainLens:: Lighting"; > = { 4.0 };
float lspec < string UIName = "RainLens:: Refraction"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.0001; > = { 0.02 };
bool rf < string UIName = "RainLens:: Force Enable"; > = { false };
float4 Test2 < string UIName = "Test2"; string UIWidget = "color"; int UIHidden = 1; > ;
float4 Test3 < string UIName = "Test3"; string UIWidget = "color"; int UIHidden = 1; > ;

float GTA5linearDepth(float depth)
{
	depth = 1.0 - depth;
	depth = DofProj.w - depth;
	depth = 1.0 + depth;
	depth = DofProj.z / depth;
	return depth;
}

SamplerState Sampler1
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Clamp;
	AddressV = Clamp;
};
SamplerState Sampler3
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Border;
	AddressV = Border;
};
SamplerComparisonState Sampler4
{
	Filter = COMPARISON_MIN_MAG_MIP_POINT;
	AddressU = Clamp;
	AddressV = Clamp;
	ComparisonFunc = EQUAL;
};

struct VS_INPUT_POST
{
	float3 pos	: POSITION;
	float2 txcoord	: TEXCOORD0;
};
struct VS_OUTPUT_POST
{
	float4 pos	: SV_POSITION;
	float2 txcoord0	: TEXCOORD0;
};
struct VS_OUTPUT_POSTt
{
	float4 pos	: SV_POSITION;
	float2 txcoord0	: TEXCOORD0;
	float4 wpos	: TEXCOORD1;
	nointerpolation float4 txcoord2	: TEXCOORD2;
	nointerpolation bool txcoord3 : TEXCOORD3;
	nointerpolation float4 txcoord4 : TEXCOORD4;
};
struct VS_OUTPUT_POST0
{
	float4 pos	: SV_POSITION;
	float4 txcoord0	: TEXCOORD0;
};
struct VS_OUTPUT_POST1
{
	float4 pos	: SV_POSITION;
	float4 txcoord0	: TEXCOORD0;
	bool menable : TEXCOORD2;
};
struct VS_OUTPUT_POST2
{
	float4 pos	: SV_POSITION;
	float2 txcoord0	: TEXCOORD0;
	float4 txcoord1[12]	: TEXCOORD1;
	nointerpolation float4 mult[3] : MULT;
};

VS_OUTPUT_POST VS_Quad(VS_INPUT_POST IN)
{
	VS_OUTPUT_POST OUT;
	OUT.pos.xyz = IN.pos.xyz;
	OUT.pos.w = 1.0;
	OUT.txcoord0.xy = IN.txcoord.xy;
	return OUT;
}
VS_OUTPUT_POSTt VS_Pre(VS_INPUT_POST IN)
{
	VS_OUTPUT_POSTt OUT;
	OUT.pos.xyz = IN.pos.xyz;
	OUT.pos.w = 1.0;
	OUT.txcoord0.xy = IN.txcoord.xy;

	float2 timer; timer.y = modf(Timer.x * 8600.0, timer.x);
	float4 noise = abs(frac(sin(timer.x * float4(25.9796, 156.466, 78.233, 51.9592)) * 43758.5453));
	float toggle = round(frac(sin(timer.x) * 43758.5453) + 0.22) * 2.0 - 1.0;
	//float toggle; modf(sin(Timer.x * 8600.0) * 1.067, toggle);
	float4 pta = Test3;
	float2 pto = round(ViewInverse3.xy * 0.001) * 1000.0;
	float2 Pos = (noise.zw * 5400.0 - 2700.0) + pto;
	float2 lejos = (abs(abs(pto) - abs(Pos)) > 600.0);
	pta.xy = lejos ? Pos : Pos + 600.0 + 600.0;
	float4 wpos = mul(pta, WorldViewProj);
	wpos.xyz /= wpos.w;
	wpos.xyz = wpos.xyz * float3(0.5, -0.5, -0.5) + float3(0.5, 0.5, 0.5);
	wpos.xy = IN.txcoord.xy - wpos.xy;
	wpos.xy = wpos.xy * DofProj.xy * wpos.w;
	wpos.x *= toggle;
	OUT.wpos = wpos;

	OUT.txcoord2.xy = int2(abs(noise.xy * 10.0 - 5.0));
	const float w[16] = { 0.0,0.9,1.0,1.0,1.0,1.0,1.0,1.0,0.38,0.37,0.9,0.9,0.9,0.9,0.9,1.0 };
	float wday = lerp(w[(int)qWeather.x], w[(int)qWeather.y], qWeather.z);
	float t = Test2.w ? GameTime : Weather.w;
	float dn_ray = lerp(7.0, 290.0 * wday, smoothstep(4.9, 5.4, t));
	OUT.txcoord2.z = lerp(dn_ray, 7.0, smoothstep(21.0, 21.5, t));
	float dn_bloom = lerp(40.0, 4900.0 * wday, smoothstep(4.9, 5.4, t));
	OUT.txcoord2.w = lerp(dn_bloom, 40.0, smoothstep(21.0, 21.5, t));

	float2 isWeather = (qWeather.xy == 9) || (qWeather.xy == 15);
	float tf = 0;
	OUT.txcoord3 = saturate(tf + (isWeather.x || isWeather.y)) * (1.0 - saturate(ExteriorInterior));
	OUT.txcoord4.x = saturate(sin(Timer.x * 210000.0));
	OUT.txcoord4.y = saturate(sin(Timer.x * 65000.0));
	OUT.txcoord4.z = max(frac(sin(Timer.x * 15000.0) * 43758.5453), 0.4);
	OUT.txcoord4.w = timer.y * 3.0 - OUT.txcoord4.z;

	return OUT;
}
VS_OUTPUT_POST0 VS_0(VS_INPUT_POST IN)
{
	VS_OUTPUT_POST0 OUT;
	OUT.pos.xyz = IN.pos.xyz * float3(rsc.xx, 1) + float3(-(1.0 - rsc), 1.0 - rsc, 0);
	OUT.pos.w = 1.0;
	OUT.txcoord0.xy = IN.txcoord.xy;
	float2 uv = IN.txcoord.xy - MoonScreenPos.xy;
	uv.y *= ScreenSize.w;
	OUT.txcoord0.zw = uv;
	return OUT;
}
VS_OUTPUT_POST1 VS_1(VS_INPUT_POST IN)
{
	VS_OUTPUT_POST1 OUT;
	OUT.pos.xyz = IN.pos.xyz;
	OUT.pos.w = 1.0;
	OUT.txcoord0.xy = IN.txcoord.xy;
	float2 uv = IN.txcoord.xy * rsc - MoonScreenPos.xy * rsc;
	uv.y += ScreenSize.y * rde * rsc;
	OUT.txcoord0.zw = uv * (1.0 / 16.0);
	float t = Test2.w ? GameTime : Weather.w;
	OUT.menable = (MoonScreenPos.z && (t > 20.9 || t < 5.9));
	return OUT;
}
VS_OUTPUT_POST0 VS_2(VS_INPUT_POST IN)
{
	VS_OUTPUT_POST0 OUT;
	OUT.pos.xyz = IN.pos.xyz;
	OUT.pos.w = 1.0;
	OUT.txcoord0.xy = IN.txcoord.xy;
	//			no, extr,clear,clrng,cloud,overcst,smog,foggy,rain,thunder,bliz,neutl,snow,snowli,xmas,hallo
	const float w[16] = { 0.04, 0.04, 0.07, 0.06, 0.015, 0.04, 0.08, 0.09, 0.4, 0.017, 0.1, 0.04, 0.01, 0.07, 0.4, 0.33 };
	OUT.txcoord0.z = lerp(w[(int)qWeather.x], w[(int)qWeather.y], qWeather.z);
	return OUT;
}
static const uint2 seed[60] = { 150,183,140,181,148,157,218,190,184,170,212,205,137,188,125,138,129,156,164,198,127,130,152,175,163,111,147,191,117,161,124,197,220,216,106,193,176,143,173,171,209,217,103,204,141,177,159,122,201,207,134,200,211,146,195,105,196,165,107,100,178,219,186,135,101,208,123,144,162,202,115,214,149,153,108,155,168,187,136,133,145,199,110,126,121,180,215,119,172,128,160,112,203,194,139,192,113,182,169,174,154,131,206,104,142,151,116,132,166,120,102,109,179,167,118,158,210,213,114,185 };
VS_OUTPUT_POST2 VS_RainLens(VS_INPUT_POST IN, uniform uint index)
{
	VS_OUTPUT_POST2 OUT;
	OUT.pos.xyz = IN.pos.xyz;
	OUT.pos.w = 1.0;
	OUT.txcoord0.xy = IN.txcoord.xy;

	float2 offset[12];
	float2 scale[12];
	float multi[12];
	float2 focusPoint = float2(0.499, 0.52);//0.5
	float spd = lerp(0.74, 1.0, saturate(FieldOfView * 0.1 - 5.0));
	float2 uv = Test2.w ? IN.txcoord.xy * spd + (1.0 - spd) * float2(0.5, 0.19) : IN.txcoord.xy;

	[unroll] for (int i = 0; i < 12; i++)
	{
		float anim = Timer.x * seed[i + index].x * lspeed;
		float2 noise = frac(sin(floor(anim) * 12.9898 + seed[i + index] * 78.233) * 43758.5453);

		float2 coord = noise - focusPoint;
		float vignt = length(coord);
		offset[i] = coord / vignt * lerp(VigOffset, float2(1.0, 0.5), vignt * 2.0);
		offset[i].x *= ScreenSize.w;

		anim = frac(anim);
		scale[i] = (1.0 + anim * 0.7 + 0.3) * lsize;
		scale[i].x *= ScreenSize.w;
		scale[i] *= lerp(1.0, grad, noise.y);

		multi[i] = (1.0 - anim) * lintensity;

		float2 Vec; sincos(seed[i + index].x, Vec.y, Vec.x);
		OUT.txcoord1[i].xy = mul(float2x2(Vec.x, -Vec.y, Vec.y, Vec.x), (uv - focusPoint - offset[i]) / scale[i]);
		OUT.txcoord1[i].zw = (float2(i % 4, floor(i * 0.25)) + OUT.txcoord1[i].xy + 0.5) * 0.25;
	}

	OUT.mult[0] = float4(multi[0], multi[1], multi[2], multi[3]);
	OUT.mult[1] = float4(multi[4], multi[5], multi[6], multi[7]);
	OUT.mult[2] = float4(multi[8], multi[9], multi[10], multi[11]);

	return OUT;
}

float3 distort(float2 uv, float2 offset)
{
	float3 color = 0;
	float3 temp;
	float2 tempuv = uv - offset * gpca;
	if (tempuv.x >= 0.0 && tempuv.x <= 1.0 && tempuv.y >= 0.0 && tempuv.y <= 1.0)
	{
		temp = TextureOriginal.SampleLevel(Sampler1, tempuv, 0).xyz;
		temp = (dot(temp, 0.333333) > gpt) ? temp : 0;
		color.x += temp.x;
	}
	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0)
	{
		temp = TextureOriginal.SampleLevel(Sampler1, uv, 0).xyz;
		temp = (dot(temp, 0.333333) > gpt) ? temp : 0;
		color.y += temp.y;
	}
	tempuv = uv + offset * gpca;
	if (tempuv.x >= 0.0 && tempuv.x <= 1.0 && tempuv.y >= 0.0 && tempuv.y <= 1.0)
	{
		temp = TextureOriginal.SampleLevel(Sampler1, tempuv, 0).xyz;
		temp = (dot(temp, 0.333333) > gpt) ? temp : 0;
		color.z += temp.z;
	}
	return color;
}
float4 PS_Pre(VS_OUTPUT_POSTt IN) : SV_Target
{
	float4 res = 0.0;
	float2 uv = IN.wpos.xy * 0.0031;

	[branch] if (IN.txcoord3 && ViewInverse3.z > 0.25 && uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0)
	{
		float4 thun = ray.SampleLevel(Sampler3, uv, 0);
		float ray[5] = { thun, lerp(thun.x, thun.y, IN.txcoord4.x) * IN.txcoord4.y };
		thun.xyz = ray[(int)IN.txcoord2.x];
		thun.xyz *= thun.xyz;

		float3 col[5];
		float vig = smoothstep(0.0, 1.0, pow(distance(IN.wpos.x, 0.5), 3) * 6e-08);
		col[0] = lerp(float3(0.486, 0.584, 1.0), float3(1.0, 0.672, 0.553), saturate(vig));
		col[1] = float3(1.0, 0.672, 0.553);
		col[2] = float3(0.486, 0.584, 1.0);
		col[3] = float3(0.424, 0.524, 1.0);
		col[4] = float3(0.425, 0.517, 1.0);

		thun.xyz *= col[(int)IN.txcoord2.y];
		thun.xyz *= saturate(IN.txcoord4.w - IN.txcoord0.y);

		float depth = GTA5linearDepth(TextureDepth.SampleLevel(Sampler1, IN.txcoord0.xy, 0).x);
		thun.xyz *= (depth > IN.wpos.w) && (IN.wpos.w > 0.0);

		res.xyz = thun.xyz * IN.txcoord2.w * IN.txcoord4.z;
		res.w = dot(thun.xyz, 0.333333) * IN.txcoord2.z;
	}

	[branch] if (gp)
	{
		float2 flareuv = (0.5 - IN.txcoord0.xy) * gpfd;
		float2 flareuv2 = flareuv * 2.0;
		float2 halouv = normalize(flareuv) * gphw;
		float3 flare = distort(IN.txcoord0.xy + flareuv, flareuv);
		flare += distort(IN.txcoord0.xy + flareuv2, flareuv2);
		flare += distort(IN.txcoord0.xy + halouv, halouv);
		flare = lerp(dot(flare, float3(0.2126, 0.7152, 0.0722)), flare, gpdesat);
		flare *= gptint;
		res.xyz += min(flare * flare * gpi, 4096.0);
	}
	return res;
}

static const float weight[4] = { 0.29675293,0.09442139,0.01037598,0.00025940 };
static const float offset[4] = { 1.41176471,3.29411765,5.17647059,7.05882353 };
float4 PS_GaussH(VS_OUTPUT_POST IN, uniform Texture2D inputtex, uniform float srcsize, uniform bool lens) : SV_Target
{
	float3 res = inputtex.SampleLevel(Sampler1, IN.txcoord0.xy, 0).xyz * 0.19638062;
	float2 px = float2(srcsize, 0);
	[unroll] for (int i = 0; i < 4; i++)
	{
		res += inputtex.SampleLevel(Sampler1, IN.txcoord0.xy + offset[i] * px, 0).xyz * weight[i];
		res += inputtex.SampleLevel(Sampler1, IN.txcoord0.xy - offset[i] * px, 0).xyz * weight[i];
	}
	if (lens == true)
	{
		res += RenderTargetRGBA64F.SampleLevel(Sampler1, IN.txcoord0.xy, 0).xyz;
	}
	return float4(res,1);
}
float4 PS_GaussV(VS_OUTPUT_POST IN, uniform Texture2D inputtex, uniform float srcsize) : SV_Target
{
	float3 res = inputtex.SampleLevel(Sampler1, IN.txcoord0.xy, 0).xyz * 0.19638062;
	float2 px = float2(0, srcsize * ScreenSize.z);
	[unroll] for (int i = 0; i < 4; i++)
	{
		res += inputtex.SampleLevel(Sampler1, IN.txcoord0.xy + offset[i] * px, 0).xyz * weight[i];
		res += inputtex.SampleLevel(Sampler1, IN.txcoord0.xy - offset[i] * px, 0).xyz * weight[i];
	}
	return float4(res,1);
}

float4 PS_BloomMix(VS_OUTPUT_POST IN, float4 v0 : SV_Position0) : SV_Target
{
	float noise = noisetex.Load(int3((int2)v0.xy & int2(63, 63), 0)).x * 2.0 - 1.0;
	float3 res = RenderTarget1024.Sample(Sampler1, IN.txcoord0.xy).xyz * 0.6;
	res += RenderTarget512.Sample(Sampler1, IN.txcoord0.xy).xyz;
	res += RenderTarget256.Sample(Sampler1, IN.txcoord0.xy).xyz;
	res += RenderTarget128.Sample(Sampler1, IN.txcoord0.xy + IN.txcoord0.xy * noise * 0.005).xyz * 1.2;
	res += RenderTarget64.Sample(Sampler1, IN.txcoord0.xy + IN.txcoord0.xy * noise * 0.015).xyz;
	res += RenderTarget32.Sample(Sampler1, IN.txcoord0.xy + IN.txcoord0.xy * noise * 0.02).xyz * float3(0.31,0.27,0.48);
	res *= b;
	//res *= lerp(b, b * 1.3432836, saturate(ExteriorInterior));
	return float4(res,1);
}

float4 PS_mr0(VS_OUTPUT_POST0 IN) : SV_Target
{
	float mmask = saturate(1.0 - pow(dot(IN.txcoord0.zw, IN.txcoord0.zw), rwi));
	mmask *= saturate(pow(dot(IN.txcoord0.zw, IN.txcoord0.zw), rwi * 1.45) * 1.9);
	return mmask * TextureDepth.SampleCmpLevelZero(Sampler4, IN.txcoord0.xy, 1).x;
}
float4 PS_mr1(VS_OUTPUT_POST1 IN, float4 v0 : SV_Position0) : SV_Target
{
	float4 res = float4(TextureColor.Sample(Sampler1, IN.txcoord0.xy).xyz, 0);
	float noise = noisetex.Load(int3((int2)v0.xy & int2(63, 63), 0)).x * 2.0 - 1.0;
	float2 uv = IN.txcoord0.xy * rsc + IN.txcoord0.zw * noise;
	if (IN.menable)
	{
		[unroll] for (int i = 0; i < 16; i++)
		{
			uv -= IN.txcoord0.zw;
			res.w += RenderTargetRGBA32.SampleLevel(Sampler1, uv, 0).x;
		}
	}
	return res;
}
float4 PS_mr2(VS_OUTPUT_POST0 IN) : SV_Target
{
	float4 res = TextureColor.Sample(Sampler1, IN.txcoord0.xy);
	float3 samp = res.w;
	//samp.x = TextureColor.Sample(Sampler1, IN.txcoord0.xy, int2(-1,-1)).w;
	//samp.z = TextureColor.Sample(Sampler1, IN.txcoord0.xy, int2(1,1)).w;
	samp.x = TextureColor.Sample(Sampler1, IN.txcoord0.xy - rcpFrame * rca).w;
	samp.z = TextureColor.Sample(Sampler1, IN.txcoord0.xy + rcpFrame * rca).w;
	samp *= rin;
	samp *= samp;
	samp *= samp;
	res.xyz += samp * IN.txcoord0.z * rcol;
	ENBSetEffectConstant(5, 16, CloudDensity);
	ENBSetEffectConstant(5, 17, CloudSpeed);
	res = ApplyClouds(res, IN.txcoord0.xy, Timer.x, noisetex, Sampler1);
	return res;
}

float4 PS_Post0(VS_OUTPUT_POST IN) : SV_Target
{
	float3 res = TextureColor.SampleLevel(Sampler1, IN.txcoord0.xy, 0, int2(1,0)).xyz;
	res += TextureColor.SampleLevel(Sampler1, IN.txcoord0.xy, 0, int2(-1,0)).xyz;
	res += TextureColor.SampleLevel(Sampler1, IN.txcoord0.xy, 0, int2(0,1)).xyz;
	res += TextureColor.SampleLevel(Sampler1, IN.txcoord0.xy, 0, int2(0,-1)).xyz;
	res *= 0.25;
	return float4(res,1);
}
float4 PS_Post1(VS_OUTPUT_POST IN) : SV_Target
{
	float3 res = TextureColor.SampleLevel(Sampler1, IN.txcoord0.xy, 0, int2(1,1)).xyz;
	res += TextureColor.SampleLevel(Sampler1, IN.txcoord0.xy, 0, int2(1,-1)).xyz;
	res += TextureColor.SampleLevel(Sampler1, IN.txcoord0.xy, 0, int2(-1,1)).xyz;
	res += TextureColor.SampleLevel(Sampler1, IN.txcoord0.xy, 0, int2(-1,-1)).xyz;
	res *= 0.25;
	float fx = RenderTargetRGBA64F.SampleLevel(Sampler1, IN.txcoord0.xy, 0).w;
	//res = res * (1.0 - fx) + fx;
	res += fx;
	return float4(res,0);
}

float4 PS_RainLens0(VS_OUTPUT_POST2 IN) : SV_Target
{
	float4 res = TextureColor.SampleLevel(Sampler1, IN.txcoord0.xy, 0);

	const float multi[12] = { IN.mult[0],IN.mult[1],IN.mult[2] };
	[unroll] for (int i = 0; i < 12; i++)
	{
		float lens = shape.SampleLevel(Sampler1, IN.txcoord1[i].zw, 0).x;
		bool2 k1 = (0.5 >= abs(IN.txcoord1[i].xy));
		res.w += lens * k1.x * k1.y * multi[i];
	}
	return res;
}
float4 PS_RainLens1(VS_OUTPUT_POST IN, float4 v0 : SV_Position0) : SV_Target
{
	float4 res = TextureColor.SampleLevel(Sampler1, IN.txcoord0.xy, 0);

	if ((v0.x < 1) && (v0.y < 3))res.w = rf;
	if ((v0.x < 1) && (v0.y < 2))res.w = llight;
	if ((v0.x < 1) && (v0.y < 1))res.w = lspec;

	return res;
}

technique11 JonahPN < string UIName = "JonahPN Bloom"; string RenderTarget = "RenderTargetRGBA64F"; >
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Pre()));
		SetPixelShader(CompileShader(ps_5_0, PS_Pre()));
	}
}
technique11 JONAHPOLISH1
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_GaussH(TextureDownsampled, 0.000976562, 1)));
	}
}
technique11 JONAHPOLISH2 < string RenderTarget = "RenderTarget1024"; >
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_GaussV(TextureColor, 0.000976562)));
	}
}
technique11 JONAHPOLISH3
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_GaussH(RenderTarget1024, 0.001953125, 0)));
	}
}
technique11 JONAHPOLISH4 < string RenderTarget = "RenderTarget512"; >
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_GaussV(TextureColor, 0.001953125)));
	}
}
technique11 JONAHPOLISH5
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_GaussH(RenderTarget512, 0.00390625, 0)));
	}
}
technique11 JONAHPOLISH6 < string RenderTarget = "RenderTarget256"; >
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_GaussV(TextureColor, 0.00390625)));
	}
}
technique11 JONAHPOLISH7
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_GaussH(RenderTarget256, 0.0078125, 0)));
	}
}
technique11 JONAHPOLISH8 < string RenderTarget = "RenderTarget128"; >
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_GaussV(TextureColor, 0.0078125)));
	}
}
technique11 JONAHPOLISH9
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_GaussH(RenderTarget128, 0.015625, 0)));
	}
}
technique11 JONAHPOLISH10 < string RenderTarget = "RenderTarget64"; >
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_GaussV(TextureColor, 0.015625)));
	}
}
technique11 JONAHPOLISH11
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_GaussH(RenderTarget64, 0.03125, 0)));
	}
}
technique11 JONAHPOLISH12 < string RenderTarget = "RenderTarget32"; >
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_GaussV(TextureColor, 0.03125)));
	}
}
technique11 JONAHPOLISH13
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_BloomMix()));
	}
}
technique11 JONAHPOLISH14 < string RenderTarget = "RenderTargetRGBA32"; >
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_0()));
		SetPixelShader(CompileShader(ps_5_0, PS_mr0()));
	}
}
technique11 JONAHPOLISH15
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_1()));
		SetPixelShader(CompileShader(ps_5_0, PS_mr1()));
	}
}
technique11 JONAHPOLISH16
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_2()));
		SetPixelShader(CompileShader(ps_5_0, PS_mr2()));
	}
}
technique11 JONAHPOLISH17
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_Post0()));
	}
}
technique11 JONAHPOLISH18
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_Post1()));
	}
}

technique11 lJONAHPOLISH < string UIName = "JonahPN Bloom+RainLens"; string RenderTarget = "RenderTargetRGBA64F"; >
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Pre()));
		SetPixelShader(CompileShader(ps_5_0, PS_Pre()));
	}
}
technique11 lJONAHPOLISH1
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_GaussH(TextureDownsampled, 0.000976562, 1)));
	}
}
technique11 lJONAHPOLISH2 < string RenderTarget = "RenderTarget1024"; >
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_GaussV(TextureColor, 0.000976562)));
	}
}
technique11 lJONAHPOLISH3
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_GaussH(RenderTarget1024, 0.001953125, 0)));
	}
}
technique11 lJONAHPOLISH4 < string RenderTarget = "RenderTarget512"; >
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_GaussV(TextureColor, 0.001953125)));
	}
}
technique11 lJONAHPOLISH5
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_GaussH(RenderTarget512, 0.00390625, 0)));
	}
}
technique11 lJONAHPOLISH6 < string RenderTarget = "RenderTarget256"; >
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_GaussV(TextureColor, 0.00390625)));
	}
}
technique11 lJONAHPOLISH7
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_GaussH(RenderTarget256, 0.0078125, 0)));
	}
}
technique11 lJONAHPOLISH8 < string RenderTarget = "RenderTarget128"; >
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_GaussV(TextureColor, 0.0078125)));
	}
}
technique11 lJONAHPOLISH9
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_GaussH(RenderTarget128, 0.015625, 0)));
	}
}
technique11 lJONAHPOLISH10 < string RenderTarget = "RenderTarget64"; >
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_GaussV(TextureColor, 0.015625)));
	}
}
technique11 lJONAHPOLISH11
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_GaussH(RenderTarget64, 0.03125, 0)));
	}
}
technique11 lJONAHPOLISH12 < string RenderTarget = "RenderTarget32"; >
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_GaussV(TextureColor, 0.03125)));
	}
}
technique11 lJONAHPOLISH13
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_BloomMix()));
	}
}
technique11 lJONAHPOLISH14 < string RenderTarget = "RenderTargetRGBA32"; >
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_0()));
		SetPixelShader(CompileShader(ps_5_0, PS_mr0()));
	}
}
technique11 lJONAHPOLISH15
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_1()));
		SetPixelShader(CompileShader(ps_5_0, PS_mr1()));
	}
}
technique11 lJONAHPOLISH16
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_2()));
		SetPixelShader(CompileShader(ps_5_0, PS_mr2()));
	}
}
technique11 lJONAHPOLISH17
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_Post0()));
	}
}
technique11 lJONAHPOLISH18
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_Post1()));
	}
}
technique11 lJONAHPOLISH19
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_RainLens(0)));
		SetPixelShader(CompileShader(ps_5_0, PS_RainLens0()));
	}
}
technique11 lJONAHPOLISH20
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_RainLens(12)));
		SetPixelShader(CompileShader(ps_5_0, PS_RainLens0()));
	}
}
technique11 lJONAHPOLISH21
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_RainLens(24)));
		SetPixelShader(CompileShader(ps_5_0, PS_RainLens0()));
	}
}
technique11 lJONAHPOLISH22
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_RainLens(36)));
		SetPixelShader(CompileShader(ps_5_0, PS_RainLens0()));
	}
}
technique11 lJONAHPOLISH23
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_RainLens(48)));
		SetPixelShader(CompileShader(ps_5_0, PS_RainLens0()));
	}
}
technique11 lJONAHPOLISH24
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Quad()));
		SetPixelShader(CompileShader(ps_5_0, PS_RainLens1()));
	}
}
