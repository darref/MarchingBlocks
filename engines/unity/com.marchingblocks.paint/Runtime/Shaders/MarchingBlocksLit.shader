// MarchingBlocks Paint for Unity — THE MATERIAL OF ANIMATED TILES AND OF PLANTS IN THE WIND.
//
// A glTF metallic-roughness material (copied from the one your glTF importer made: MBLitMaterials.cs), plus
//   - the ANIMATED TEXTURES of extras.mb_animation: frames (a Texture2DArray per channel), scroll, pulse — one clock
//     for every material; the phase of a tile is computed on the CPU, in double precision, and set per renderer;
//   - the WIND of a plant (keyword _MB_WIND): its vertices sway in FORMAT space (MBFoliage.Sway, line by line).
// Two pipelines: URP (its SubShader needs the URP package) and the Built-in pipeline (a Standard surface shader).
// HDRP: not supported.

Shader "MarchingBlocks/Lit"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        _BaseMap ("Base Color Tex", 2D) = "white" {}
        _MetallicFactor ("Metallic", Range(0, 1)) = 0
        _RoughnessFactor ("Roughness", Range(0, 1)) = 1
        _MetallicRoughnessMap ("Metallic-Roughness Tex (G rough, B metal)", 2D) = "white" {}
        _OcclusionStrength ("Occlusion Strength", Range(0, 1)) = 1
        _OcclusionMap ("Occlusion Tex (R)", 2D) = "white" {}
        _NormalScale ("Normal Scale", Float) = 1
        [Normal] _NormalMap ("Normal Tex", 2D) = "bump" {}
        [HDR] _EmissionColor ("Emissive", Color) = (0, 0, 0, 1)
        _EmissionMap ("Emission Tex", 2D) = "white" {}
        _Cutoff ("Alpha Cutoff", Range(0, 1)) = 0.5
        [Toggle(_MB_ALPHATEST)] _AlphaTest ("Alpha Test", Float) = 0
        [Toggle(_MB_WIND)] _Wind ("Wind (plants)", Float) = 0
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 2

        [HideInInspector] _MBFramesAlbedo ("", 2DArray) = "" {}
        [HideInInspector] _MBFramesNormal ("", 2DArray) = "" {}
        [HideInInspector] _MBFramesORM ("", 2DArray) = "" {}
        [HideInInspector] _MBFramesEmission ("", 2DArray) = "" {}
        [HideInInspector] _MBFramesAlbedoParams ("", Vector) = (0, 12, 0, 0)
        [HideInInspector] _MBFramesNormalParams ("", Vector) = (0, 12, 0, 0)
        [HideInInspector] _MBFramesORMParams ("", Vector) = (0, 12, 0, 0)
        [HideInInspector] _MBFramesEmissionParams ("", Vector) = (0, 12, 0, 0)
        [HideInInspector] _MBScrollAlbedo ("", Vector) = (0, 0, 1, 0)
        [HideInInspector] _MBScrollNormal ("", Vector) = (0, 0, 1, 0)
        [HideInInspector] _MBScrollORM ("", Vector) = (0, 0, 1, 0)
        [HideInInspector] _MBScrollEmission ("", Vector) = (0, 0, 1, 0)
        [HideInInspector] _MBPulse ("", Vector) = (0.5, 0.2, 0, 0)
    }

    // ── URP ─────────────────────────────────────────────────────────────────────────────────────────────
    SubShader
    {
        PackageRequirements { "com.unity.render-pipelines.universal" }
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" "Queue" = "Geometry" }
        Cull [_Cull]

        HLSLINCLUDE
        #define MB_URP 1
        #pragma target 4.5
        #pragma shader_feature_local _MB_WIND
        #pragma shader_feature_local _MB_ALPHATEST
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "MBLitCore.hlsl"

        struct MBAttributes
        {
            float4 positionOS : POSITION;
            float3 normalOS : NORMAL;
            float4 tangentOS : TANGENT;
            float2 uv : TEXCOORD0;
        };

        float3 MBPositionWS(MBAttributes v, float3 normalWS)
        {
            float3 p = TransformObjectToWorld(v.positionOS.xyz);
            #if defined(_MB_WIND)
            p = MBSway(p, normalWS);
            #endif
            return p;
        }
        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #pragma multi_compile_fog

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 tangentWS : TEXCOORD2;
                float2 uv : TEXCOORD3;
                float fog : TEXCOORD4;
            };

            Varyings vert(MBAttributes v)
            {
                Varyings o;
                VertexNormalInputs n = GetVertexNormalInputs(v.normalOS, v.tangentOS);
                o.positionWS = MBPositionWS(v, n.normalWS);
                o.positionCS = TransformWorldToHClip(o.positionWS);
                o.normalWS = n.normalWS;
                o.tangentWS = float4(n.tangentWS, v.tangentOS.w * GetOddNegativeScale());
                o.uv = v.uv;
                o.fog = ComputeFogFactor(o.positionCS.z);
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                MBSurface s = MBEvaluate(i.uv);
                #if defined(_MB_ALPHATEST)
                clip(s.alpha - _Cutoff);
                #endif
                float3 bitangent = i.tangentWS.w * cross(i.normalWS, i.tangentWS.xyz);
                float3 normalWS = normalize(TransformTangentToWorld(s.normalTS, float3x3(i.tangentWS.xyz, bitangent, i.normalWS)));
                InputData d = (InputData)0;
                d.positionWS = i.positionWS;
                d.positionCS = i.positionCS;
                d.normalWS = normalWS;
                d.viewDirectionWS = GetWorldSpaceNormalizeViewDir(i.positionWS);
                d.shadowCoord = TransformWorldToShadowCoord(i.positionWS);
                d.fogCoord = i.fog;
                d.bakedGI = SampleSH(normalWS);
                d.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(i.positionCS);
                d.shadowMask = half4(1, 1, 1, 1);
                SurfaceData sd = (SurfaceData)0;
                sd.albedo = s.albedo;
                sd.alpha = 1.0;
                sd.metallic = s.metallic;
                sd.smoothness = s.smoothness;
                sd.occlusion = s.occlusion;
                sd.emission = s.emission;
                sd.normalTS = s.normalTS;
                half4 c = UniversalFragmentPBR(d, sd);
                c.rgb = MixFog(c.rgb, i.fog);
                return c;
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            ColorMask 0
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            float3 _LightDirection;
            float3 _LightPosition;
            struct Varyings { float4 positionCS : SV_POSITION; float2 uv : TEXCOORD0; };
            Varyings vert(MBAttributes v)
            {
                Varyings o;
                float3 normalWS = TransformObjectToWorldNormal(v.normalOS);
                float3 positionWS = MBPositionWS(v, normalWS);
                #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                float3 l = normalize(_LightPosition - positionWS);
                #else
                float3 l = _LightDirection;
                #endif
                o.positionCS = ApplyShadowClamping(TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, l)));
                o.uv = v.uv;
                return o;
            }
            half4 frag(Varyings i) : SV_Target
            {
                #if defined(_MB_ALPHATEST)
                clip(MB_SAMPLE2D(_BaseMap, i.uv).a * _BaseColor.a - _Cutoff);
                #endif
                return 0;
            }
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            ZWrite On
            ColorMask R
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            struct Varyings { float4 positionCS : SV_POSITION; float2 uv : TEXCOORD0; };
            Varyings vert(MBAttributes v)
            {
                Varyings o;
                o.positionCS = TransformWorldToHClip(MBPositionWS(v, TransformObjectToWorldNormal(v.normalOS)));
                o.uv = v.uv;
                return o;
            }
            half4 frag(Varyings i) : SV_Target
            {
                #if defined(_MB_ALPHATEST)
                clip(MB_SAMPLE2D(_BaseMap, i.uv).a * _BaseColor.a - _Cutoff);
                #endif
                return i.positionCS.z;
            }
            ENDHLSL
        }

        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode" = "DepthNormals" }
            ZWrite On
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            struct Varyings { float4 positionCS : SV_POSITION; float3 normalWS : TEXCOORD0; float2 uv : TEXCOORD1; };
            Varyings vert(MBAttributes v)
            {
                Varyings o;
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.positionCS = TransformWorldToHClip(MBPositionWS(v, o.normalWS));
                o.uv = v.uv;
                return o;
            }
            half4 frag(Varyings i) : SV_Target
            {
                #if defined(_MB_ALPHATEST)
                clip(MB_SAMPLE2D(_BaseMap, i.uv).a * _BaseColor.a - _Cutoff);
                #endif
                return half4(NormalizeNormalPerPixel(i.normalWS), 0.0);
            }
            ENDHLSL
        }
    }

    // ── Built-in ────────────────────────────────────────────────────────────────────────────────────────
    SubShader
    {
        Tags { "RenderType" = "Opaque" "Queue" = "Geometry" }
        Cull [_Cull]
        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows vertex:vert addshadow
        #pragma target 4.5
        #pragma shader_feature_local _MB_WIND
        #pragma shader_feature_local _MB_ALPHATEST
        #include "MBLitCore.hlsl"

        struct Input
        {
            float2 mbUV;
        };

        void vert(inout appdata_full v, out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);
            o.mbUV = v.texcoord.xy;
            #if defined(_MB_WIND)
            float3 normalWS = UnityObjectToWorldNormal(v.normal);
            float3 p = MBSway(mul(unity_ObjectToWorld, v.vertex).xyz, normalWS);
            v.vertex.xyz = mul(unity_WorldToObject, float4(p, 1.0)).xyz;
            #endif
        }

        void surf(Input i, inout SurfaceOutputStandard o)
        {
            MBSurface s = MBEvaluate(i.mbUV);
            #if defined(_MB_ALPHATEST)
            clip(s.alpha - _Cutoff);
            #endif
            o.Albedo = s.albedo;
            o.Alpha = 1.0;
            o.Metallic = s.metallic;
            o.Smoothness = s.smoothness;
            o.Occlusion = s.occlusion;
            o.Emission = s.emission;
            o.Normal = s.normalTS;
        }
        ENDCG
    }
}
