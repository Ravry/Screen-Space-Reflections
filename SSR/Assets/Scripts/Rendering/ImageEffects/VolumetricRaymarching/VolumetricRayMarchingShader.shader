Shader "CustomEffects/ImprovedVRM"
{
    Properties
    {
        _MaxSteps("Max Steps", Integer) = 100
        _MaxDistance("Max Distance", Float) = 100
        _Epsilon("Epsilon", Float) = 0.001
        _VolumetricSphere("Volumetric Sphere", Vector) = (0, 0, 0, 1)
        _SphereColor("Sphere Color", Color) = (1, 1, 1, 1)
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

    int _MaxSteps;
    float _MaxDistance;
    float _Epsilon;
    float4 _VolumetricSphere;
    float4 _SphereColor;

    float sphereSDF(float3 p, float3 center, float radius)
    {
        return length(p - center) - radius;
    }

    float4 FragSSR(Varyings input) : SV_Target
    {
        float2 uv = input.texcoord;
        float3 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv).rgb;
        float sceneDepth = SampleSceneDepth(uv);
        float sceneDepthLinear = LinearEyeDepth(sceneDepth, _ZBufferParams);
        float3 normal = normalize(SampleSceneNormals(uv));

        float3 worldPos = ComputeWorldSpacePosition(uv, sceneDepth, UNITY_MATRIX_I_VP);
        float3 viewDir = normalize(worldPos - _WorldSpaceCameraPos); 
        
        float3 rayOrigin = _WorldSpaceCameraPos;
        float3 rayDir = viewDir;

        float t = 0;
        bool hit = false;
        float hitDepth = 0;

        [loop]
        for (int i = 0; i < _MaxSteps; i++)
        {
            float3 p = rayOrigin + rayDir * t;
            float d = sphereSDF(p, _VolumetricSphere.xyz, _VolumetricSphere.w);

            // Check if the current point is behind scene geometry
            float4 clipPos = mul(UNITY_MATRIX_VP, float4(p, 1.0));
            float2 screenUV = (clipPos.xy / clipPos.w) * 0.5 + 0.5;
            float rayDepth = LinearEyeDepth(clipPos.z / clipPos.w, _ZBufferParams);

            [branch]
            if (rayDepth > sceneDepthLinear)
            {
                // Ray has passed behind scene geometry, stop marching
                break;
            }

            [branch]
            if (d < _Epsilon)
            {
                hit = true;
                break;
            }

            t += d;

            [branch]
            if (t > _MaxDistance)
                break;
        }

        [branch]
        if (hit)
        {
            return float4(_SphereColor.rgb, 1);
        }

        return float4(color, 1);
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
            Name "ScreenSpaceRaymarching"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragSSR
            ENDHLSL
        }
    }
}