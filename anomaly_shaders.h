#ifndef        ANOMALY_SHADERS_H
#define        ANOMALY_SHADERS_H
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   //Anomaly shaders 1.5																 				 			  //
  //Credits to KD, Anonim, Crossire, daemonjax, Zhora Cementow, Meltac, X-Ray Oxygen, FozeSt, Zagolski, SonicEthers, //
 //David Hoskins, BigWIngs																							//
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	#define	LUMINANCE_VECTOR float3(0.2125, 0.7154, 0.0721)
	
//////////////////////////////////////////////////////////////
// Screen space sunshafts
	#define SS_INTENSITY float(0.35)		
	#define SS_BLEND_FACTOR float(0.8)		
	#define SS_LENGTH float(1.0)				

//////////////////////////////////////////////////////////////
// SSDO
	#define SSDO_RADIUS float(0.25)					// radius of ssdo
	#define SSDO_DISCARD_THRESHOLD float(1.5)		// maximum difference in pixel depth. lower value can fix slopes
	#define SSDO_COLOR_BLEEDING float(20.0)			// power of colored shadows. changes overall intensity so use it along with blend factor
	#define SSDO_BLEND_FACTOR float(1.4)			// intensity of shadows
	#define SSDO_GRASS_EPS float(0.2) // really want to make sure we don't add anything if 0
	#define SSDO_GRASS_CONTIRUBTION float(1.2)      // amount to add to grass to ignore in AO shader

//////////////////////////////////////////////////////////////
// Motion blur
	#define MBLUR_SAMPLES 	half(12)
	#define MBLUR_CLAMP	half(0.001)	
	//#define MBLUR_WPN //disabled mblur for weapon
	
/////////////////////////////////////////////////////////////
// Bokeh DoF
	#define BOKEH_AMOUNT float(256.0)

#endif