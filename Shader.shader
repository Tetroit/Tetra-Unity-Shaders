Shader "MyShaders/Shader"
{
    Properties
    {
        [MainTextre] _MainTex ("Texture", 2D) = "white" {}
        [MainColor] _Color ("Color", Color) = (1,1,1,1)
        _Smoothness ("Smoothness", Float) = 1

        [HideInInspector] _SurfaceType ("Surface Type", Float) = 0
    }
    SubShader
    {
        Tags { 
        "RenderType" = "Transparent"
        "RenderPipeline" = "UniversalPipeline"
        "Queue" = "Transparent"
        }
        LOD 100

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off

            HLSLPROGRAM

            #define _SPECULAR_COLOR
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #pragma vertex vert
            #pragma fragment frag

            #include "HLSL/TestShader.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "ShadowPass"
            Tags{"LightMode" = "ShadowCaster"}

            HLSLPROGRAM

            //#pragma vertex ShadowPassVertex
            //#pragma fragment ShadowPassFragment

            #pragma vertex vert
            #pragma fragment frag
            
            //#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            #include "HLSL/ShadowCastPass.hlsl"

            ENDHLSL
        }
    }

    CustomEditor "CustomMaterialEditor"
}
