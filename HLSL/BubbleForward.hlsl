//forward pass
#ifndef BUBBLE_FORWARDPASS_HLSL
#define BUBBLE_FORWARDPASS_HLSL

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "HLSL/TetraLib/Noise.hlsl"
#include "HLSL/TetraLib/Interference.hlsl"

TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
float4 _MainTex_ST;
float4 _Color;
float _VoronoiScale;
float4 _ClipColor;
float4 _SecClipColor;
float _FilmThickness;
float _IOR;

struct to_vert
{
	float3 positionOS : POSITION;
	float3 normalOS : NORMAL;
	float2 UV : TEXCOORD0;

};


struct vert2frag
{
	float4 positionCS : SV_POSITION;
	float2 UV : TEXCOORD0;
	float3 positionWS : TEXCOORD1;
	float3 normalWS : TEXCOORD2;
    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 8);
};

vert2frag vert (to_vert Input)
{
	vert2frag Output;
	VertexPositionInputs posnInputs = GetVertexPositionInputs(Input.positionOS);
	VertexNormalInputs normInputs = GetVertexNormalInputs(Input.normalOS);

	Output.positionCS = posnInputs.positionCS;
	Output.UV = TRANSFORM_TEX(Input.UV, _MainTex);
	Output.positionWS = posnInputs.positionWS;
	Output.normalWS = normInputs.normalWS;

	return Output;
};



float4 frag (vert2frag Input) : SV_TARGET0
{
	float4 mainTexCol = SAMPLE_TEXTURE2D(_MainTex ,sampler_MainTex, Input.UV);
	float4 surfaceCol = _Color * mainTexCol;
	

	InputData lightingIn = (InputData)0;
	lightingIn.positionWS = Input.positionWS;
	lightingIn.normalWS = normalize(Input.normalWS);
	lightingIn.viewDirectionWS = GetWorldSpaceNormalizeViewDir(Input.positionWS);

#if defined(MAIN_LIGHT_CALCULATE_SHADOWS)
    lightingIn.shadowCoord = TransformWorldToShadowCoord(Input.positionWS);
#else
    lightingIn.shadowCoord = float4(0, 0, 0, 0);
#endif
	float3 GI = SAMPLE_GI(input.staticLightmapUV, Input.vertexSH, Input.normalWS);
    lightingIn.bakedGI = GI;
	
    lightingIn.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(Input.positionCS);
    lightingIn.shadowMask = SAMPLE_SHADOWMASK(Input.staticLightmapUV);

	float3 viewDir = normalize(_WorldSpaceCameraPos - Input.positionWS);

	float3 interference = ThinFilmInterference(surfaceCol.rgb, Input.normalWS, _IOR, _FilmThickness, Input.positionWS, viewDir);

	SurfaceData surfaceIn = (SurfaceData)0;
	surfaceIn.albedo = surfaceCol.rgb;
	surfaceIn.alpha = surfaceCol.a;
	surfaceIn.specular = 1;
	surfaceIn.smoothness = _Smoothness;
	surfaceIn.metallic = _Metallic;
	surfaceIn.occlusion = 1.0f;
	
	#if UNITY_VERSION >= 202120
		return UniversalFragmentPBR(lightingIn, surfaceIn) * float4(interference,1);
	#else
		return UniversalFragmentBlinnPhong(lightingIn, 
		surfaceIn.albedo, 
		float4(surfaceIn.specular, 1), 
		surfaceIn.smoothness, 0, 
		surfaceIn.alpha);
	#endif
	//UNITY_VERSION
};

#endif
//TESTSHADER_FORWARDPASS_HLSL