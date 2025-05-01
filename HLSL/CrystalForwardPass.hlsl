//forward pass
#ifndef CRYSTAL_FORWARDPASS_HLSL
#define CRYSTAL_FORWARDPASS_HLSL

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "HLSL/TetraLib/Noise.hlsl"
#include "HLSL/TetraLib/Interference.hlsl"

TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
float4 _MainTex_ST;
float4 _Color;
float _StartClip;
float _EndClip;
float _VoronoiScale;
float4 _ReflectionColor;
float4 _FresnelColor;
float _FresnelFac;

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




// Computes the scalar specular term for Minimalist CookTorrance BRDF
// NOTE: needs to be multiplied with reflectance f0, i.e. specular color to complete
half DirectBRDFSpecular_EXP(BRDFData brdfData, half3 normalWS, half3 lightDirectionWS, half3 viewDirectionWS)
{
    float3 lightDirectionWSFloat3 = float3(lightDirectionWS);
    float3 halfDir = SafeNormalize(lightDirectionWSFloat3 + float3(viewDirectionWS));

    float NoH = saturate(dot(float3(normalWS), halfDir));
    half LoH = half(saturate(dot(lightDirectionWSFloat3, halfDir)));

    // GGX Distribution multiplied by combined approximation of Visibility and Fresnel
    // BRDFspec = (D * V * F) / 4.0
    // D = roughness^2 / ( NoH^2 * (roughness^2 - 1) + 1 )^2
    // V * F = 1.0 / ( LoH^2 * (roughness + 0.5) )
    // See "Optimizing PBR for Mobile" from Siggraph 2015 moving mobile graphics course
    // https://community.arm.com/events/1155

    // Final BRDFspec = roughness^2 / ( NoH^2 * (roughness^2 - 1) + 1 )^2 * (LoH^2 * (roughness + 0.5) * 4.0)
    // We further optimize a few light invariant terms
    // brdfData.normalizationTerm = (roughness + 0.5) * 4.0 rewritten as roughness * 4.0 + 2.0 to a fit a MAD.
    float d = NoH * NoH * brdfData.roughness2MinusOne + 1.00001f;

    half LoH2 = LoH * LoH;
    half specularTerm = brdfData.roughness2 / ((d * d) * max(0.1h, LoH2) * brdfData.normalizationTerm) * 1.0f;

    half specularMapped = 0;


    // On platforms where half actually means something, the denominator has a risk of overflow
    // clamp below was added specifically to "fix" that, but dx compiler (we convert bytecode to metal/gles)
    // sees that specularTerm have only non-negative terms, so it skips max(0,..) in clamp (leaving only min(100,...))
#if REAL_IS_HALF
    specularTerm = specularTerm - HALF_MIN;
    // Update: Conservative bump from 100.0 to 1000.0 to better match the full float specular look.
    // Roughly 65504.0 / 32*2 == 1023.5,
    // or HALF_MAX / ((mobile) MAX_VISIBLE_LIGHTS * 2),
    // to reserve half of the per light range for specular and half for diffuse + indirect + emissive.
    specularTerm = clamp(specularTerm, 0.0, 1000.0); // Prevent FP16 overflow on mobiles
#endif

    return specularMapped;
}





half3 LightingPhysicallyBased_EXP(BRDFData brdfData, BRDFData brdfDataClearCoat,
    half3 lightColor, half3 lightDirectionWS, half lightAttenuation,
    half3 normalWS, half3 viewDirectionWS,
    half clearCoatMask, bool specularHighlightsOff, half3 reflection)
{
    half NdotL = saturate(dot(normalWS, lightDirectionWS));
    half3 radiance = lightColor * (lightAttenuation * NdotL);

    half3 brdf = brdfData.diffuse;
    

#ifndef _SPECULARHIGHLIGHTS_OFF
    [branch] if (!specularHighlightsOff)
    {
        brdf += brdfData.specular * DirectBRDFSpecular_EXP(brdfData, normalWS, lightDirectionWS, viewDirectionWS);


#if defined(_CLEARCOAT) || defined(_CLEARCOATMAP)
        // Clear coat evaluates the specular a second timw and has some common terms with the base specular.
        // We rely on the compiler to merge these and compute them only once.
        half brdfCoat = kDielectricSpec.r * DirectBRDFSpecular_EXP(brdfDataClearCoat, normalWS, lightDirectionWS, viewDirectionWS);

            // Mix clear coat and base layer using khronos glTF recommended formula
            // https://github.com/KhronosGroup/glTF/blob/master/extensions/2.0/Khronos/KHR_materials_clearcoat/README.md
            // Use NoV for direct too instead of LoH as an optimization (NoV is light invariant).
            half NoV = saturate(dot(normalWS, viewDirectionWS));
            // Use slightly simpler fresnelTerm (Pow4 vs Pow5) as a small optimization.
            // It is matching fresnel used in the GI/Env, so should produce a consistent clear coat blend (env vs. direct)
            half coatFresnel = kDielectricSpec.x + kDielectricSpec.a * Pow4(1.0 - NoV);

        brdf = brdf * (1.0 - clearCoatMask * coatFresnel) + brdfCoat * clearCoatMask;
#endif // _CLEARCOAT
    }
#endif // _SPECULARHIGHLIGHTS_OFF

    return brdf * radiance + reflection * lightColor * lightAttenuation;
    //return refraction * half3(0.3f, 0.1f, 0.2f);
}

half3 LightingPhysicallyBased_EXP(BRDFData brdfData, BRDFData brdfDataClearCoat, Light light, half3 normalWS, half3 viewDirectionWS, half clearCoatMask, bool specularHighlightsOff, half3 reflection)
{
    return LightingPhysicallyBased_EXP(brdfData, brdfDataClearCoat, light.color, light.direction, light.distanceAttenuation * light.shadowAttenuation, normalWS, viewDirectionWS, clearCoatMask, specularHighlightsOff, reflection);
}




half4 UniversalFragmentPBR_EXP(InputData inputData, SurfaceData surfaceData)
{
    #if defined(_SPECULARHIGHLIGHTS_OFF)
    bool specularHighlightsOff = true;
    #else
    bool specularHighlightsOff = false;
    #endif
    BRDFData brdfData;

    // NOTE: can modify "surfaceData"...
    InitializeBRDFData(surfaceData, brdfData);

    #if defined(DEBUG_DISPLAY)
    half4 debugColor;

    if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor))
    {
        return debugColor;
    }
    #endif

    // Clear-coat calculation...
    BRDFData brdfDataClearCoat = CreateClearCoatBRDFData(surfaceData, brdfData);
    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
    uint meshRenderingLayers = GetMeshRenderingLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);

    // NOTE: We don't apply AO to the GI here because it's done in the lighting calculation below...
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    LightingData lightingData = CreateLightingData(inputData, surfaceData);

    lightingData.giColor = GlobalIllumination(brdfData, brdfDataClearCoat, surfaceData.clearCoatMask,
                                              inputData.bakedGI, aoFactor.indirectAmbientOcclusion, inputData.positionWS,
                                              inputData.normalWS, inputData.viewDirectionWS, inputData.normalizedScreenSpaceUV);

    half reflectionMask = 0;
    half refractionMask = 0;

    half3 reflectionDir = normalize(inputData.viewDirectionWS - 3 * inputData.normalWS * dot(inputData.viewDirectionWS, inputData.normalWS));    //yes I put 3, this is not a mistake
    reflectionDir = mul(reflectionDir, (float3x3)UNITY_MATRIX_I_V);
    half reflectionFac = dot(reflectionDir, half3(0,0,1));

    if ((reflectionFac < 0.01 && reflectionFac > -0.01 || reflectionFac < 0.07 && reflectionFac > 0.03))
        reflectionMask = max(0,dot(inputData.normalWS, inputData.viewDirectionWS));

    if (reflectionFac > _FresnelFac)
        refractionMask = invLerpByMinAndScale(reflectionFac, _FresnelFac, 1/(1-_FresnelFac));

    half3 reflectionCol = reflectionMask * _ReflectionColor.rgb;
    half3 refractionCol = refractionMask * _FresnelColor.rgb;

    lightingData.giColor = lerp(lightingData.giColor, softLight(lightingData.giColor, refractionCol), refractionMask);

#ifdef _LIGHT_LAYERS
    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
#endif
    {
        lightingData.mainLightColor = LightingPhysicallyBased_EXP(brdfData, brdfDataClearCoat,
                                                              mainLight,
                                                              inputData.normalWS, inputData.viewDirectionWS,
                                                              surfaceData.clearCoatMask, specularHighlightsOff, reflectionCol);
    }

    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();

    #if USE_FORWARD_PLUS
    for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK

        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

#ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
#endif
        {
            lightingData.additionalLightsColor += LightingPhysicallyBased_EXP(brdfData, brdfDataClearCoat, light,
                                                                          inputData.normalWS, inputData.viewDirectionWS,
                                                                          surfaceData.clearCoatMask, specularHighlightsOff, reflectionCol);
        }
    }
    #endif

    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

#ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
#endif
        {
            lightingData.additionalLightsColor += LightingPhysicallyBased_EXP(brdfData, brdfDataClearCoat, light,
                                                                          inputData.normalWS, inputData.viewDirectionWS,
                                                                          surfaceData.clearCoatMask, specularHighlightsOff, reflectionCol);
        }
    LIGHT_LOOP_END
    #endif

    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
    lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;
    #endif

#if REAL_IS_HALF
    // Clamp any half.inf+ to HALF_MAX
    return min(CalculateFinalColor(lightingData, surfaceData.alpha), HALF_MAX);
#else
    return CalculateFinalColor(lightingData, surfaceData.alpha);
#endif
}






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

	SurfaceData surfaceIn = (SurfaceData)0;
	surfaceIn.albedo = surfaceCol.rgb;
	surfaceIn.specular = 1;
	surfaceIn.smoothness = _Smoothness;
	surfaceIn.metallic = _Metallic;
	surfaceIn.occlusion = 1.0f;
	
	return UniversalFragmentPBR_EXP(lightingIn, surfaceIn);
};

#endif
//CRYSTAL_FORWARDPASS_HLSL