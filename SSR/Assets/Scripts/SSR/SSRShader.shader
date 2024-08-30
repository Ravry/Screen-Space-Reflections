Shader "CustomEffects/SSR"
{
    Properties
    {
        _StepSize("Step Size", Float) = 0.1
        _MaxSteps("Max Steps", Integer) = 100
        _ReflectionStrength("Reflection Strength", Range(0, 1)) = 1
    }

        HLSLINCLUDE
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

    TEXTURE2D(_CameraOpaqueTexture);
    SAMPLER(sampler_CameraOpaqueTexture);

    float _StepSize;
    int _MaxSteps;
    float _ReflectionStrength;

    float4 FragSSR(Varyings input) : SV_Target
    {
        float2 uv = input.texcoord;
        float3 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv).rgb;
        float depth;

#if UNITY_REVERSED_Z
        depth = SampleSceneDepth(uv);
#else
        // Adjust z to match NDC for OpenGL
        depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(uv));
#endif
        float3 worldPos = ComputeWorldSpacePosition(uv, depth, UNITY_MATRIX_I_VP);
        float3 normal = SampleSceneNormals(uv);
        
        float3 viewDir = normalize(worldPos - _WorldSpaceCameraPos);
        float3 reflection = reflect(viewDir, normal);

        float3 rayPosWS = worldPos;
        float2 rayUV = uv;
        bool rayHit = false;


        [loop]
        for (int i = 0; i < _MaxSteps; i++)
        {

            rayPosWS += reflection * _StepSize;
            float4 clipPos = mul(UNITY_MATRIX_VP, float4(rayPosWS, 1.0));
            float3 ndcPos = clipPos.xyz / clipPos.w;
            rayUV = ndcPos.xy * 0.5 + 0.5;

            if (rayUV.x < 0.0 || rayUV.x > 1.0 || rayUV.y < 0.0 || rayUV.y > 1.0)
            {
                break;
            }

            float rayDepth;
#if UNITY_REVERSED_Z
            rayDepth = SampleSceneDepth(rayUV);
#else
            rayDepth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(rayUV));
#endif



            if (rayPosWS.z - rayDepth > 0)
            {
                rayHit = true;
                break;
            }
        }

        float3 reflectionColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, rayUV).rgb;


        return float4(rayHit ? lerp(color, reflectionColor, _ReflectionStrength) : color, 1);
    }

        ENDHLSL

        SubShader
    {
        Tags{ "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
            LOD 100
            ZTest Always
            ZWrite Off
            Cull Off

            Pass
        {
            Name "ScreenSpaceReflections"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragSSR
            ENDHLSL
        }
    }
}