Shader "MyShaders/AssembleShader"
{
    Properties
    {
        [MainTextre] _MainTex ("Texture", 2D) = "white" {}
        [MainColor] _Color ("Color", Color) = (1,1,1,1)
        _Smoothness ("Smoothness", Float) = 0.5
        _Metallic ("Metallic", Float) = 0.5
        _StartClip ("Start Clip Distance", Float) = 3.0
        _EndClip ("End Clip Distance", Float) = 3.1
        _VoronoiScale ("Tile Scale", Float) = 0.1
        _FilmThickness ("Film thickness", Float) = 0.01
        _IOR ("IOR", Float) = 1
        [HDR] _ClipColor ("Clip Color", Color) = (0,8,8,4)
        [HDR] _SecClipColor ("Secondary Clip Color", Color) = (4,2,8,4)
    }
    SubShader
    {
        Tags { 
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
            "Queue" = "Transparent"
        }
        LOD 100

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite On

            HLSLPROGRAM

//-----------------------------DEFINES------------------------------//
            //specular
            #define _SPECULAR_COLOR

            //lights and shadows
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES

            //shadows
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            //lightmaps
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON

            //reflections
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING

            //pipeline
            #pragma multi_compile _ _FORWARD_PLUS


//-----------------------------------------------------------------//

            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "HLSL/BubbleForward.hlsl"

            ENDHLSL
        }

        //Pass
        //{
        //    Name "ShadowPass"
        //    Tags{"LightMode" = "ShadowCaster"}
            
        //    HLSLPROGRAM

        //    //#pragma vertex ShadowPassVertex
        //    //#pragma fragment ShadowPassFragment

        //    #pragma vertex vert
        //    #pragma fragment frag
            
        //    //#include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
        //    #include "HLSL/ShadowCastPass.hlsl"

        //    ENDHLSL
        //}
        //Pass
        //{
        //    Name "DepthNormals"
        //    Tags
        //    {
        //        "LightMode" = "DepthNormals"
        //    }

        //    // -------------------------------------
        //    // Render State Commands
        //    ZWrite On
        //    Cull[_Cull]

        //    HLSLPROGRAM
        //    #pragma target 2.0

        //    // -------------------------------------
        //    // Shader Stages
        //    #pragma vertex DepthNormalsVertex
        //    #pragma fragment DepthNormalsFragment

        //    // -------------------------------------
        //    // Material Keywords
        //    #pragma shader_feature_local _NORMALMAP
        //    #pragma shader_feature_local _PARALLAXMAP
        //    #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
        //    #pragma shader_feature_local _ALPHATEST_ON
        //    #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

        //    // -------------------------------------
        //    // Unity defined keywords
        //    #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

        //    // -------------------------------------
        //    // Universal Pipeline keywords
        //    #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

        //    //--------------------------------------
        //    // GPU Instancing
        //    #pragma multi_compile_instancing
        //    #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

        //    // -------------------------------------
        //    // Includes
        //    #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
        //    #include "Packages/com.unity.render-pipelines.universal/Shaders/LitDepthNormalsPass.hlsl"
        //    ENDHLSL
        //}
    }
}
