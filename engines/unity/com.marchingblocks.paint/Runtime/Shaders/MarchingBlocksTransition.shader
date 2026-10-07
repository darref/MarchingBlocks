// MarchingBlocks Paint for Unity — THE TRANSITION OVERLAY: drawn OVER the tiles' own materials, on the same mesh (a
// second renderer per tile, see MarchingBlocksTransitions.cs), it shows the OTHER layer's representative where the
// rule says so, in transparency, and nothing elsewhere. Unity has no "next pass" over a material, and a material added
// to a renderer only redraws its LAST submesh: hence a second renderer with this material on EVERY submesh.
//
// Lit like the tiles (the app's overlay is a lit spatial shader): URP — UniversalFragmentPBR (its SubShader needs the
// URP package); Built-in — a Standard surface shader, alpha:fade. HDRP: not supported.

Shader "MarchingBlocks/Transition Overlay"
{
    Properties
    {
        [Toggle] _MBShowChoices ("Show painted choices", Float) = 0
        // Declared so that Unity keeps them when it rebuilds the material's properties (set by MarchingBlocksTransitions).
        [HideInInspector] _MBCells ("", 3D) = "" {}
        [HideInInspector] _MBTable ("", 2D) = "black" {}
        [HideInInspector] _MBReps ("", 2DArray) = "" {}
        [HideInInspector] _MBRepData ("", 2D) = "black" {}
        [HideInInspector] _MBCellsOrigin ("", Vector) = (0, 0, 0, 0)
        [HideInInspector] _MBCellsSize ("", Vector) = (1, 1, 1, 0)
    }

    SubShader
    {
        PackageRequirements { "com.unity.render-pipelines.universal" }
        Tags { "RenderPipeline" = "UniversalPipeline" "Queue" = "Transparent+10" "RenderType" = "Transparent" "IgnoreProjector" = "True" }
        Pass
        {
            Name "MBTransition"
            Tags { "LightMode" = "UniversalForward" }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            ZTest LEqual
            Offset -1, -1

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #pragma multi_compile_fog
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "MBTransitionCore.hlsl"

            struct Attributes { float4 positionOS : POSITION; float3 normalOS : NORMAL; };
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionF : TEXCOORD0;
                float3 normalF : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 positionWS : TEXCOORD3;
                float fog : TEXCOORD4;
            };

            Varyings vert(Attributes v)
            {
                Varyings o;
                o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
                o.positionCS = TransformWorldToHClip(o.positionWS);
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.positionF = mul(_MBWorldToFormat, float4(o.positionWS, 1.0)).xyz;
                o.normalF = mul((float3x3)_MBWorldToFormat, o.normalWS);
                o.fog = ComputeFogFactor(o.positionCS.z);
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float roughness;
                float4 look = MBTransition(i.positionF, normalize(i.normalF), roughness);
                clip(look.a - 0.004);
                float3 n = normalize(i.normalWS);
                InputData d = (InputData)0;
                d.positionWS = i.positionWS;
                d.positionCS = i.positionCS;
                d.normalWS = n;
                d.viewDirectionWS = GetWorldSpaceNormalizeViewDir(i.positionWS);
                d.shadowCoord = TransformWorldToShadowCoord(i.positionWS);
                d.fogCoord = i.fog;
                d.bakedGI = SampleSH(n);
                d.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(i.positionCS);
                d.shadowMask = half4(1, 1, 1, 1);
                SurfaceData s = (SurfaceData)0;
                s.albedo = look.rgb;
                s.alpha = look.a;
                s.smoothness = 1.0 - roughness;
                s.occlusion = 1.0;
                s.normalTS = float3(0, 0, 1);
                half4 c = UniversalFragmentPBR(d, s);
                c.rgb = MixFog(c.rgb, i.fog);
                c.a = look.a;
                return c;
            }
            ENDHLSL
        }
    }

    SubShader
    {
        Tags { "Queue" = "Transparent+10" "RenderType" = "Transparent" "IgnoreProjector" = "True" }
        Pass
        {
            Name "MBTransition"
            Tags { "LightMode" = "ForwardBase" }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            ZTest LEqual
            Offset -1, -1

            CGPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            #include "UnityCG.cginc"
            #include "UnityPBSLighting.cginc"
            #include "AutoLight.cginc"
            #include "MBTransitionCore.hlsl"

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 positionF : TEXCOORD0;
                float3 normalF : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 positionWS : TEXCOORD3;
                UNITY_FOG_COORDS(4)
                UNITY_SHADOW_COORDS(5)
            };

            v2f vert(appdata_full v)
            {
                v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                o.positionWS = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.pos = UnityWorldToClipPos(o.positionWS);
                o.normalWS = UnityObjectToWorldNormal(v.normal);
                o.positionF = mul(_MBWorldToFormat, float4(o.positionWS, 1.0)).xyz;
                o.normalF = mul((float3x3)_MBWorldToFormat, o.normalWS);
                UNITY_TRANSFER_FOG(o, o.pos);
                UNITY_TRANSFER_SHADOW(o, 0);
                return o;
            }

            // The Standard model of the Built-in pipeline (UNITY_BRDF_PBS), the main light, the ambient probe and the
            // reflection probe: the overlay is lit like the tiles under it.
            fixed4 frag(v2f i) : SV_Target
            {
                float roughness;
                float4 look = MBTransition(i.positionF, normalize(i.normalF), roughness);
                clip(look.a - 0.004);
                float3 n = normalize(i.normalWS);
                float3 viewDir = normalize(UnityWorldSpaceViewDir(i.positionWS));
                half oneMinusReflectivity;
                half3 specColor;
                half3 albedo = DiffuseAndSpecularFromMetallic(look.rgb, 0.0, specColor, oneMinusReflectivity);
                UNITY_LIGHT_ATTENUATION(atten, i, i.positionWS);
                UnityLight light;
                light.color = _LightColor0.rgb * atten;
                light.dir = normalize(_WorldSpaceLightPos0.xyz);
                UnityIndirect indirect;
                indirect.diffuse = ShadeSH9(float4(n, 1.0));
                Unity_GlossyEnvironmentData g;
                g.roughness = SmoothnessToPerceptualRoughness(1.0 - roughness);
                g.reflUVW = reflect(-viewDir, n);
                indirect.specular = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, g);
                half4 c = UNITY_BRDF_PBS(albedo, specColor, oneMinusReflectivity, 1.0 - roughness, n, viewDir, light, indirect);
                c.a = look.a;
                UNITY_APPLY_FOG(i.fogCoord, c);
                return c;
            }
            ENDCG
        }
    }
}
