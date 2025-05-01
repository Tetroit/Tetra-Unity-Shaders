//shadow cast pass
#ifndef TESTSHADER_SHADOWPASS_HLSL
#define TESTSHADER_SHADOWPASS_HLSL

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


float3 _LightDirection;

struct to_vert
{
	float3 positionOS : POSITION;
	float3 normalOS : NORMAL;
	
};

struct vert2frag
{
	float4 positionCS : SV_POSITION;
};

float4 GetShadowCasterPositionCS(float3 positionWS, float3 normalWS) {
	float3 lightDirectionWS = _LightDirection;
	float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
#if UNITY_REVERSED_Z
	positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#else
	positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#endif
	return positionCS;
}

vert2frag vert (to_vert Input)
{
	vert2frag Output;

	VertexPositionInputs posnInputs = GetVertexPositionInputs(Input.positionOS);
	VertexNormalInputs normInputs = GetVertexNormalInputs(Input.normalOS);

	Output.positionCS = GetShadowCasterPositionCS(posnInputs.positionWS, normInputs.normalWS);

	return Output;
};



float4 frag (vert2frag Input) : SV_TARGET
{
	return 0;
};

#endif
//TESTSHADER_SHADOWPASS_HLSL