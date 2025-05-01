#ifndef TETRALIB_INTERFERENCE_INCLUDED
#define TETRALIB_INTERFERENCE_INCLUDED

#include "./Math.hlsl"

float3 WavelengthToColor(float wl)
{
	float3 rgb = float3(0,0,0);
	if ((wl >= 380)	&& (wl < 440))
	{
		rgb.r = 1 - invLerpByMinAndScale(wl, 380, 0.016666f);
		rgb.g = 0;
		rgb.b = 1;
	}
	
	else if ((wl >= 440) && (wl < 490))
	{
		rgb.r = 0;
		rgb.g = invLerpByMinAndScale(wl, 440, 0.02f);
		rgb.b = 1;
	}
	else if ((wl >= 490) && (wl < 510))
	{
		rgb.r = 0;
		rgb.g = 1;
		rgb.b = 1 - invLerpByMinAndScale(wl, 490, 0.02f);
	}
	else if ((wl >= 510) && (wl < 580))
	{
		rgb.r = invLerpByMinAndScale(wl, 510, 0.014285f);
		rgb.g = 1;
		rgb.b = 0;
	}
	else if ((wl >= 580) && (wl < 645))
	{
		rgb.r = 1;
		rgb.g = 1 - invLerpByMinAndScale(wl, 580, 0.015384f);
		rgb.b = 0;
	}
	else if ((wl >= 645) && (wl < 780))
	{
		rgb.r = 1;
		rgb.g = 0;
		rgb.b = 0;
	}
	else
	{
		rgb = float3(0,0,0);
	}

	if ((wl >= 700) && (wl < 780))
		rgb *= (1 - invLerpByMinAndScale(wl, 700, 0.0125f));
	else if ((wl >= 380) && (wl < 420))
		rgb *= (invLerpByMinAndScale(wl, 380, 0.025f));
	return rgb;
}

float3 ThinFilmInterference(float3 LightColor, float3 NormalWS, float IOR, float Thickness, float3 PositionWS, float3 ViewDirWS)
{
	//nothing is affected
	if (Thickness <= 0)
	return 0;

	float sin_n1 = sin2(-ViewDirWS, NormalWS);
	//Snell's Law
	float sin_n2 = sin_n1 / IOR;
	float cos_n2 = sqrt(1 - sin_n2 * sin_n2);
	
	float OPD = 2*IOR*Thickness*cos_n2;
	float minPeak = OPD * 1.282051f;// 1000/780
	float maxPeak = OPD * 2.631578f;// 1000/380

	//too many resonances, nothing is really affected
	float peakCnt = floor(maxPeak) - floor(minPeak);
	float peakCntF = maxPeak - minPeak;
	if (peakCnt > 20) return 1;
	if (peakCnt <= 0.1) return 0;

	float3 sumPeaks = float3(0,0,0);
	for (float i = ceil(minPeak); i < maxPeak; i++)
	{
		if (i > 0)
			sumPeaks += WavelengthToColor(OPD * 1000/i);
	}
	return sumPeaks / peakCntF;
}
#endif 
//TETRALIB_INTERFERENCE_INCLUDED