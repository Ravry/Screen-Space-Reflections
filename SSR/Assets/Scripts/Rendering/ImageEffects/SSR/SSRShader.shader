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
// #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

    uniform sampler2D _GBuffer2;
    sampler2D _CameraDepthTexture;

    float _StepSize;
    int _MaxSteps;
    float _ReflectionStrength;
    float3 _WorldSpaceViewDir;

    float4 FragSSR(Varyings input) : SV_Target
    {
        float2 uv = input.texcoord;
        float3 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv).rgb;
        float depthRaw = tex2D(_CameraDepthTexture, uv);
        float4 gbuff = tex2D(_GBuffer2, uv);
        float smoothness = gbuff.w;
        float3 normal = normalize(gbuff.rgb);

        float4 posClipSpace = float4(uv * 2 - 1, depthRaw, 1);
        float4 posViewSpace = mul(UNITY_MATRIX_I_P, posClipSpace);
        posViewSpace /= posViewSpace.w;
        posViewSpace.y *= -1;
        float4 posWorldSpace = mul(UNITY_MATRIX_I_V, posViewSpace);

        float3 viewDir = normalize(float3(posWorldSpace.xyz) - _WorldSpaceCameraPos);
        
        float3 reflectionRayWorldSpace = reflect(viewDir, normal);
        float3 reflectionRayViewSpace = mul(UNITY_MATRIX_V, float4(reflectionRayWorldSpace, 0));
        reflectionRayViewSpace.z *= -1;
        posViewSpace.z *= -1;

        float viewReflectDot = saturate(dot(viewDir, reflectionRayWorldSpace));
        float cameraViewReflectDot = saturate(dot(_WorldSpaceViewDir, reflectionRayWorldSpace));
        
        float _StepSize2 = _StepSize;

        float thickness = _StepSize * 2;
        float oneMiusViewReflectDot = sqrt(1 - viewReflectDot);
        _StepSize2 /= oneMiusViewReflectDot;
        thickness /= oneMiusViewReflectDot;

        float3 currentRayPosViewSpace = posViewSpace.xyz;
        float4 currentUV;
        bool rayDidHit = false;

        bool doRayMarch = smoothness > 0;

        float maxRayLength = _MaxSteps * _StepSize2;
        float maxDist = lerp(min(posViewSpace.z, maxRayLength), maxRayLength, cameraViewReflectDot);
        float numSteps_f = maxDist / _StepSize2;
        _MaxSteps = max(numSteps_f, 0);
        
        float edgeFade;


        [branch]
        if (doRayMarch)
        {
            [loop]
            for (int i = 0; i < _MaxSteps; i++)
            {
                currentRayPosViewSpace += reflectionRayViewSpace * _StepSize2;

                currentUV = mul(UNITY_MATRIX_P, float4(currentRayPosViewSpace.x, currentRayPosViewSpace.y * -1, currentRayPosViewSpace.z * -1, 1));
                currentUV /= currentUV.w;
                currentUV.x *= 0.5f;
                currentUV.y *= 0.5f;
                currentUV.x += 0.5f;
                currentUV.y += 0.5f;

                float2 screenEdgeFade = smoothstep(0.0, 0.1, float2(
                    min(currentUV.x, 1.0 - currentUV.x),
                    min(currentUV.y, 1.0 - currentUV.y)
                    ));
                edgeFade = min(screenEdgeFade.x, screenEdgeFade.y);

                [branch]
                if (currentUV.x >= 1 || currentUV.x < 0 || currentUV.y >= 1 || currentUV.y < 0) {
                    break;
                }

                float sampledDepth = tex2D(_CameraDepthTexture, currentUV.xy);

                [branch]
                if (abs(depthRaw - sampledDepth) > 0 && sampledDepth != 0)
                {
                    float depthDelta = currentRayPosViewSpace.z - LinearEyeDepth(sampledDepth, _ZBufferParams);

                    [branch]
                    if (depthDelta > 0 && depthDelta < _StepSize2 * 2)
                    {
                        rayDidHit = true;
                        break;
                    }
                }
            }
        }

        float3 reflectionColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, currentUV.xy).rgb;

        return float4(rayDidHit ? lerp(color, reflectionColor, _ReflectionStrength * smoothness * edgeFade) : color, 1);
        //return float4(normal.rgb, 1);
    }

        ENDHLSL

        SubShader
    {
        Tags{ "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
            LOD 100
            ZTest Never
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