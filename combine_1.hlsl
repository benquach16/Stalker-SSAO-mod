#include "anomaly_shaders.h"
#include "common.h"

//#define USE_SUPER_SPECULAR
//#define USE_ORIGINAL_SSAO
//#define HBAO_WORLD_JITTER

#include "lmodel.h"
#include "hmodel.h"

uniform	Texture2D					s_half_depth;
#include "ssao.ps"

#ifdef HDAO
#define USE_HDAO 1
#endif

#ifdef SM_5
Texture2D<float> s_occ;
#endif // SM_5

#if SSAO_QUALITY <=3
#include "ssdo.ps"

#else
#ifndef USE_HDAO
#define USE_HDAO
#endif
#endif


#ifdef USE_HDAO
#if SSAO_QUALITY > 3
#include "ssao_hdao_new.ps"
#endif
#define USE_HDAO_CODE
#if SSAO_QUALITY <=3
#define  g_f2RTSize ( pos_decompression_params2.xy )

#define g_txDepth s_position
#define g_txNormal s_normal

#include "ssao_hdao.ps"
#endif
#else // USE_HDAO
#ifdef	USE_HBAO
#include "ssao_hbao.ps"
#endif	//	USE_HBAO
#endif // USE_HDAO


struct	_input
{
	float4	tc0	: TEXCOORD0;	// tc.xy, tc.w = tonemap scale
	float2	tcJ	: TEXCOORD1;	// jitter coords
	float4 pos2d : SV_Position;
};

struct	_out
{
	float4	low		: SV_Target0;
	float4	high	: SV_Target1;
};

//	TODO:	DX10: Replace Sample with Load
#ifndef MSAA_OPTIMIZATION
_out main ( _input I )
#else
_out main ( _input I, uint iSample : SV_SAMPLEINDEX )
#endif
{
	gbuffer_data gbd = gbuffer_load_data( GLD_P(I.tc0, I.pos2d, ISAMPLE) );
	
	// Sample the buffers:
	float4	P = float4( gbd.P, gbd.mtl );	// position.(mtl or sun)
	float4	N = float4( gbd.N, gbd.hemi );		// normal.hemi
	float4	D = float4( gbd.C, gbd.gloss );		// rgb.gloss
	float grass = gbd.extra;
#ifndef USE_MSAA
	float4	L = s_accumulator.Sample( smp_nofilter, I.tc0);	// diffuse.specular
#else
	float4   L = s_accumulator.Load( int3( I.tc0 * pos_decompression_params2.xy, 0 ), ISAMPLE );
#endif

#ifdef USE_SUPER_SPECULAR
	{
		float ds = dot( D.rgb, 1.h/3.h );
		D.w = max( D.w, ds*ds/8.h );
	}
#endif

#ifdef FORCE_GLOSS
	D.w = FORCE_GLOSS;
#endif

#ifdef USE_GAMMA_22
	D.rgb = ( D.rgb*D.rgb ); // pow(2.2)
#endif

        // static sun
	float mtl = P.w;

#ifdef USE_R2_STATIC_SUN
	float sun_occ = P.w*2;

	mtl = xmaterial;
	L += Ldynamic_color * sun_occ * plight_infinity	(mtl, P.xyz, N.xyz, Ldynamic_dir);
#endif

	// hemisphere
	float3 hdiffuse, hspecular;

	//  Calculate SSAO

#ifdef USE_MSAA
	int2	texCoord = int2( I.tc0 * pos_decompression_params2.xy );
#endif
	
	float3 occ = float3(1.f,1.f,1.f);
#ifdef USE_HDAO
#ifdef SM_5
#if SSAO_QUALITY > 3
     occ = s_occ.Sample( smp_nofilter, I.tc0);	
#else // SSAO_QUALITY > 3
	 occ = calc_hdao( CS_P(P, N, I.tc0, I.tcJ, I.pos2d, ISAMPLE ) );
#endif // SSAO_QUALITY > 3
#else // SM_5
#if SSAO_QUALITY > 3
	 occ = calc_new_hdao( CS_P(P, N, I.tc0, I.tcJ, I.pos2d, ISAMPLE ) );
#else // SSAO_QUALITY > 3
	 occ = calc_hdao( CS_P(P, N, I.tc0, I.tcJ, I.pos2d, ISAMPLE ) );
#endif // SSAO_QUALITY > 3
#endif // SM_5
#else // USE_HDAO
#ifdef USE_HBAO
	 occ = calc_hbao( P.z, N, I.tc0, I.pos2d );
#else // USE_HBAO
	//Implementation here now takes radius as parameter
	//occ = calc_ssdo(P, N, I.tc0, ISAMPLE, 2.0f, 32);
	occ = calc_ssdo_fast(P, N, I.tc0, ISAMPLE, 0.5f, grass);
#endif
#endif // USE_HDAO
	// Second pass for SSAO
	// A larger radius pass that uses less samples and is applied regardless of lighting.
	// if we do it here, should be cache friendly (?)
	//float3 occ_rough = calc_ssdo_fast_rough(P, N, I.tc0, ISAMPLE, 5.0f, grass);
	//occ = occ * occ_rough;
	hmodel	(hdiffuse, hspecular, mtl, N.w, D.w, P.xyz, N.xyz);
	hdiffuse *= occ;
	hspecular *= occ;

	float4         light       = float4         (L.rgb + hdiffuse, L.w)        ;
	float4         C           = D*light       ;                             // rgb.gloss * light(diffuse.specular)
	float3         spec        = C.www * L.rgb + hspecular * C.rgba;              // replicated specular

#ifdef         USE_SUPER_SPECULAR
                      spec      = (C.rgb*.5h + .5h)*C.w + hspecular        ;
#endif

		float3       color     = C.rgb + spec     ;

////////////////////////////////////////////////////////////////////////////////
/// For Test ///////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
#ifdef         DBG_TEST_NMAP
//. hemi + sun + lighting + specular
					color 	= 	hdiffuse + L.rgb + N;
#endif

#ifdef         DBG_TEST_NMAP_SPEC
//. hemi + sun + lighting + specular
					color 	= 	hdiffuse + L.rgb + N + spec;
#endif

#ifdef         DBG_TEST_LIGHT
//. hemi + sun + lighting + specular
					color 	= 	hdiffuse + L.rgb;
#endif

#ifdef         DBG_TEST_LIGHT_SPEC
//. hemi + sun + lighting + specular
					color 	= 	hdiffuse + L.rgb + spec;
#endif

#ifdef         DBG_TEST_SPEC
//. only lighting and specular
					color 		= spec;
#endif
////////////////////////////////////////////////////////////////////////////////

        // here should be distance fog
        float3        	pos        		= P.xyz;
        float         	distance		= length		(pos);
        float         	fog				= saturate		(distance*fog_params.w + fog_params.x); //
                      	color			= lerp     		(color,fog_color,fog);        			//
        float        	skyblend		= saturate		(fog*fog);


#ifdef         DBG_TMAPPING
        color                        	= D.xyz;
#endif
        float          	tm_scale        = I.tc0.w;                // interpolated from VS

#ifdef        USE_SUPER_SPECULAR
        color        	= spec          - hspecular	;
#endif
		//color 		= N; //show normals
//		color                        	= D.xyz;


		//occ_rough = saturate(occ_rough);
		//color = occ_rough;
		//occ_rough = occ_rough * 0.5 + 0.5;
		occ = occ * 0.5 + 0.5;
		color = occ * color;
        _out        	o;
        tonemap        	(o.low, o.high, color, tm_scale )	;
                        o.low.a         = skyblend	;
						o.high.a		= skyblend	;

		return        	o;
}
