//forward pass
#ifndef TESTSHADER_FORWARDPASS_HLSL
#define TESTSHADER_FORWARDPASS_HLSL

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
float4 _MainTex_ST;
float4 _Color;
float _Smoothness;

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



float4 frag (vert2frag Input) : SV_TARGET
{
	float4 mainTexCol = SAMPLE_TEXTURE2D(_MainTex ,sampler_MainTex, Input.UV);
	float4 surfaceCol = _Color * mainTexCol;
	

	InputData lightingIn = (InputData)0;
	lightingIn.positionWS = Input.positionWS;
	lightingIn.normalWS = normalize(Input.normalWS);
	lightingIn.viewDirectionWS = GetWorldSpaceNormalizeViewDir(Input.positionWS);
	lightingIn.shadowCoord = TransformWorldToShadowCoord(Input.positionWS);

	SurfaceData surfaceIn = (SurfaceData)0;
	surfaceIn.albedo = surfaceCol.rgb;
	surfaceIn.alpha = surfaceCol.a;
	surfaceIn.specular = 1;
	surfaceIn.smoothness = _Smoothness;
	
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