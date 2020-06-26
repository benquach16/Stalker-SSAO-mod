/*	Screen-Space Directional Occlusion.
Based on Tobias Ritschel tech paper.
Implemented by K.D. (OGSE team)
Last Changed for DX10: 04.11.2018
*/
#include "common.h"

static const float3 arr[32] = 
{
		float3(-0.134, 0.044, -0.825),
		float3(0.045, -0.431, -0.529),
		float3(-0.537, 0.195, -0.371),
		float3(0.525, -0.397, 0.713),
		float3(0.895, 0.302, 0.139),
		float3(-0.613, -0.408, -0.141),
		float3(0.307, 0.822, 0.169),
		float3(-0.819, 0.037, -0.388),
		float3(0.376, 0.009, 0.193),
		float3(-0.006, -0.103, -0.035),
		float3(0.098, 0.393, 0.019),
		float3(0.542, -0.218, -0.593),
		float3(0.526, -0.183, 0.424),
		float3(-0.529, -0.178, 0.684),
		float3(0.066, -0.657, -0.570),
		float3(-0.214, 0.288, 0.188),
		float3(-0.689, -0.222, -0.192),
		float3(-0.008, -0.212, -0.721),
		float3(0.053, -0.863, 0.054),
		float3(0.639, -0.558, 0.289),
		float3(-0.255, 0.958, 0.099),
		float3(-0.488, 0.473, -0.381),
		float3(-0.592, -0.332, 0.137),
		float3(0.080, 0.756, -0.494),
		float3(-0.638, 0.319, 0.686),
		float3(-0.663, 0.230, -0.634),
		float3(0.235, -0.547, 0.664),
		float3(0.164, -0.710, 0.086),
		float3(-0.009, 0.493, -0.038),
		float3(-0.322, 0.147, -0.105),
		float3(-0.554, -0.725, 0.289),
		float3(0.534, 0.157, -0.250),
};

#define DISCARD_THRESHOLD 0.8
#define DISCARD_THRESHOLD_2 1.0
#define BLEND_FACTOR 1.8

//modified SSDO function
//passing in threshold gives us the ability to modify threshold based on distance
float accumulate(int i, float3 P, float3 N, uint iSample, float scale, float threshold, float bias)
{
	float3 occ_pos_view = P.xyz + (arr[i] + N) * scale;
	float4 occ_pos_screen = proj_to_screen(mul(m_P, float4(occ_pos_view, 1.0)));
	occ_pos_screen.xy /= occ_pos_screen.w;
	#ifdef USE_MSAA
	gbuffer_data gbd = gbuffer_load_data(occ_pos_screen, iSample);
	#else
	gbuffer_data gbd = gbuffer_load_data(occ_pos_screen.xy);
	#endif

	float screen_occ = gbd.P.z;
	screen_occ = lerp(screen_occ, 0.f, is_sky(screen_occ));
	float is_occluder = step(occ_pos_view.z, screen_occ);
	float dist = abs(P.z - screen_occ);
	float tmp = smoothstep(0.0, 1.0, saturate(dist - threshold));
	
	//float tmp = step(threshold, dist); // old threshold function. if its too blurry try switching
	//float amount = saturate(dist);
	//only consider if screen_occ is greater than P.z
	
	//darker the farther away it is
	//original code did something similar, and looks surprisingly good
	float amount = saturate(0.8 - screen_occ);
	tmp += step(screen_occ + bias, P.z);
	
	//grass filter
	float occ_coeff = saturate(is_occluder + amount+tmp);
	return occ_coeff;
}

//john chapman ssao
//doesn't work right now
float accumulate2(int i, float3 P, float3 N, uint iSample, float scale, float threshold, float3x3 TBN)
{
	float3 sample = mul(TBN, arr[i]);
	sample = P + sample * 0.2;
	float4 occ_pos_screen = proj_to_screen(mul(m_P, float4(sample, 1.0)));
	occ_pos_screen.xy /= occ_pos_screen.w;
	
	#ifdef USE_MSAA
	gbuffer_data gbd = gbuffer_load_data(occ_pos_screen, iSample);
	#else
	gbuffer_data gbd = gbuffer_load_data(occ_pos_screen.xy);
	#endif

	float screen_occ = gbd.P.z;
	float occ_coeff = (screen_occ >= P.z + 0.025) ? 1.0 : 0.0;
	float range_check = smoothstep(0.0f, 1.0f, 0.2f/abs(P.z - screen_occ));
	occ_coeff *= range_check;
	return occ_coeff;
}

float calc_scale(float radius, float depth)
{
	//float normalized = depth * 0.5 + 0.5;
	return radius / depth;
	//return (radius*0.5) * ((depth * 0.1) + 0.3);
}

#ifndef SSAO_QUALITY
float3 calc_ssdo (float3 P, float3 N, float2 tc, uint iSample, float radius, int samples)
{
	return 1;
}
#else // SSAO_QUALITY
float3 calc_ssdo (float3 P, float3 N, float2 tc, uint iSample, float radius, int samples)
{
	float3 occ = float3(0,0,0);
	float scale = calc_scale(radius, P.z);
	//probably faster to unroll... possibly 32x generated instructions though, not to mention code cleanliness suffers
	//profile with ssdo_fast
	//static int samples = 32;
	//[unroll]
	for (int i = 0; i < samples; i++)
	{
		float3 occ_pos_view = P.xyz + (arr[i] + N) * scale;
		float4 occ_pos_screen = proj_to_screen(mul(m_P, float4(occ_pos_view, 1.0)));
		occ_pos_screen.xy /= occ_pos_screen.w;
		#ifdef USE_MSAA
		gbuffer_data gbd = gbuffer_load_data(occ_pos_screen, iSample);
		#else
		gbuffer_data gbd = gbuffer_load_data(occ_pos_screen.xy);
		#endif

		float screen_occ = gbd.P.z;
		screen_occ = lerp(screen_occ, 0.f, is_sky(screen_occ));
		float is_occluder = step(occ_pos_view.z, screen_occ);
		float occ_coeff = saturate(is_occluder + saturate(2.1 - screen_occ) + step(DISCARD_THRESHOLD, abs(P.z-screen_occ)));
		occ += float3(occ_coeff, occ_coeff, occ_coeff);
	}
	occ /= samples;
	occ = saturate(occ);
	return (occ + (1 - occ)*(1 - BLEND_FACTOR));
}

//SSAO_QUALITY is basically worthless now. need to use it to generate permutations with less samples
//also using this function means that you always get SSDO, regardless of if you have it enabled.
float3 calc_ssdo_fast (float3 P, float3 N, float2 tc, uint iSample, float radius, float grass)
{
	float occ = 0.f;
	float scale = calc_scale(radius, P.z);
	const int cSamples = 32;
	//float3 randomVec = normalize(arr[0]);
	//float3 bitangent = cross(randomVec, N);
	//float3x3 TBN = float3x3(N, bitangent, randomVec);
	[unroll]
	for (int i = 0; i < cSamples; i++)
	{
		float occ_coeff = accumulate(i, P, N, iSample, scale, DISCARD_THRESHOLD, 0.2);
		occ += occ_coeff;
	}
	occ /= cSamples;
	occ += grass;
	occ = saturate(occ);
	occ = occ + (1 - occ)*(1 - BLEND_FACTOR);
	//scalar ops then covert to float3 at the end
	return float3(occ, occ, occ);
}

//rougher calculation with some contrast
float3 calc_ssdo_fast_rough (float3 P, float3 N, float2 tc, uint iSample, float radius)
{
	float occ = 0.f;
	float scale = calc_scale(radius, P.z);
	const int cSamples = 20;
	[unroll]
	for (int i = 0; i < cSamples; i++)
	{
		float occ_coeff = accumulate(i, P, N, iSample, scale, DISCARD_THRESHOLD_2, 0.6);
		occ += occ_coeff;
	}
	occ /= cSamples;
	occ = saturate(occ);
	occ = occ + (1 - occ)*(1 - 0.8);
	occ = ((occ - 0.5f) * 1.1) + 0.5f;
	//scalar ops then covert to float3 at the end
	return float3(occ, occ, occ);
}
#endif // SSAO_QUALITY