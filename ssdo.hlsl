/*	Screen-Space Directional Occlusion.
Based on Tobias Ritschel tech paper.
Implemented by K.D. (OGSE team)
Last Changed for DX10: 04.11.2018
*/
#include "common.h"
static const float3 arr[7] = 
{
	float3(	0.8113	,	0.0000	,	-0.4	),
	float3(	0.3183	,	0.6913	,	-0.3	),
	float3(	-0.2074	,	0.5981	,	-0.5	),
	float3(	-0.5497	,	0.3373	,	-0.5	),
	float3(	-0.8652	,	-0.4010	,	-1.0	),
	float3(	-0.1994	,	-0.5347	,	-0.5	),
	float3(	0.4934	,	-0.5759	,	-0.8	),
};

#ifndef SSAO_QUALITY
float3 calc_ssdo (float3 P, float3 N, float2 tc, uint iSample)
{
	return 1;
}
#else // SSAO_QUALITY
float3 calc_ssdo (float3 P, float3 N, float2 tc, uint iSample)
{
	int quality = SSAO_QUALITY + 1;
	float3 occ = float3(0,0,0);
	float scale = P.z/10.f * SSDO_RADIUS;
	for (int a = 1; a < quality; ++a)
	{
		scale *= a;
		for (int i = 0; i < 7; i++)
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
			float occ_coeff = saturate(is_occluder + saturate(2.1 - screen_occ) + step(SSDO_DISCARD_THRESHOLD, abs(P.z-screen_occ)));
			occ += float3(occ_coeff, occ_coeff, occ_coeff);
		}
	}
	occ /= (7 * SSAO_QUALITY);
	occ = saturate(occ);
	return (occ + (1 - occ)*(1 - SSDO_BLEND_FACTOR));
}
#endif // SSAO_QUALITY