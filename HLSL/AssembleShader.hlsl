//forward pass
#ifndef ASSEMBLE_FORWARDPASS_HLSL
#define ASSEMBLE_FORWARDPASS_HLSL

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "HLSL/TetraLib/Noise.hlsl"

TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
float4 _MainTex_ST;
float4 _Color;
float _StartClip;
float _EndClip;
float _VoronoiScale;
float4 _ClipColor;
float4 _SecClipColor;

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

    lightingIn.bakedGI = SAMPLE_GI(input.staticLightmapUV, Input.vertexSH, Input.normalWS);
	
    lightingIn.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(Input.positionCS);
    lightingIn.shadowMask = SAMPLE_SHADOWMASK(Input.staticLightmapUV);

	float3 nodePos;
	float voronoi = Voronoi3D(Input.positionWS, _VoronoiScale, nodePos);
	float camDist = length(_WorldSpaceCameraPos - nodePos);
	float alphaFac = 1 - (camDist - _StartClip) / (_EndClip - _StartClip) * 2;

	SurfaceData surfaceIn = (SurfaceData)0;
	surfaceIn.albedo = surfaceCol.rgb;
	surfaceIn.alpha = clamp (alphaFac, 0, 1);
	surfaceIn.specular = 1;
	surfaceIn.smoothness = _Smoothness;
	surfaceIn.metallic = _Metallic;
	surfaceIn.occlusion = 1.0f;
	
	if (alphaFac > 1)
		surfaceIn.emission = lerp(_ClipColor, float4(0,0,0,0), clamp(alphaFac, 1, 2) - 1);
	else
		surfaceIn.emission = lerp(_SecClipColor, _ClipColor, clamp(alphaFac, 0, 1));
	
	#if UNITY_VERSION >= 202120
		return UniversalFragmentPBR(lightingIn, surfaceIn);
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