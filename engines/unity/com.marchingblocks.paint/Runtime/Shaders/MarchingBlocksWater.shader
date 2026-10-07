// MarchingBlocks Paint for Unity — THE SIX WATER LOOKS, on the baked sheet (water/<name>.glb). EXAMPLES, not an
// obligation: any shader that reads the vertex colours gets the same data (see MBWaterCore.hlsl for the contract and
// what differs from the app). One keyword per look; MBWaterLooks.cs makes the six materials.
// Two pipelines: URP (its SubShader needs the URP package) and the Built-in pipeline. HDRP: not supported.

Shader "MarchingBlocks/Water"
{
    Properties
    {
        [KeywordEnum(Stylized, Clear, Reflective, Lava, Swamp, Acid)] _MB_LOOK ("Look", Float) = 0
        _ColorA ("Colour A", Color) = (0.22, 0.53, 0.74, 1)
        _ColorB ("Colour B", Color) = (0.06, 0.22, 0.45, 1)
        _ColorC ("Colour C", Color) = (0.34, 0.61, 0.74, 1)
        _ColorD ("Colour D", Color) = (0.96, 0.99, 1.0, 1)
        _Params ("Parameters", Vector) = (0.15, 0.72, 1.6, 0.25)
        _Params2 ("Parameters 2", Vector) = (0.35, 0, 0, 0)
        _Clapot ("Clapot (amount, k z, k x, speed)", Vector) = (0.03, 0.55, 0.85, 1.9)
    }

    SubShader
    {
        PackageRequirements { "com.unity.render-pipelines.universal" }
        Tags { "RenderPipeline" = "UniversalPipeline" "Queue" = "Transparent" "RenderType" = "Transparent" }
        Pass
        {
            Name "MBWater"
            Tags { "LightMode" = "UniversalForward" }
            Blend One OneMinusSrcAlpha
            ZWrite On
            Cull Off
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_local _MB_LOOK_STYLIZED _MB_LOOK_CLEAR _MB_LOOK_REFLECTIVE _MB_LOOK_LAVA _MB_LOOK_SWAMP _MB_LOOK_ACID
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #pragma multi_compile_fog
            // Premultiplied alpha: the diffuse fades with the alpha, the highlights stay (URP's own transparent mode).
            #define _ALPHAPREMULTIPLY_ON 1
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "MBWaterCore.hlsl"
            float4 _Clapot;

            struct Attributes { float4 positionOS : POSITION; float3 normalOS : NORMAL; float4 color : COLOR; float2 uv : TEXCOORD0; };
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 positionF : TEXCOORD1;
                float3 normalF : TEXCOORD2;
                float4 color : TEXCOORD3;
                float2 uv : TEXCOORD4;
                float fog : TEXCOORD5;
            };

            Varyings vert(Attributes v)
            {
                Varyings o;
                float3 pw = TransformObjectToWorld(v.positionOS.xyz);
                float3 pF = mul(_MBWorldToFormat, float4(pw, 1.0)).xyz;
                pF.y += wClapot(pF, MBWaterTime(), _Clapot.x, float4(_Clapot.y, _Clapot.z, _Clapot.w, 0));
                o.positionWS = mul(_MBFormatToWorld, float4(pF, 1.0)).xyz;
                o.positionF = pF;
                o.normalF = mul((float3x3)_MBWorldToFormat, TransformObjectToWorldNormal(v.normalOS));
                o.positionCS = TransformWorldToHClip(o.positionWS);
                o.color = v.color;
                o.uv = float2(v.uv.x, 1.0 - v.uv.y);   // back to glTF UVs (the importer flips v)
                o.fog = ComputeFogFactor(o.positionCS.z);
                return o;
            }

            half4 frag(Varyings i, bool front : SV_IsFrontFace) : SV_Target
            {
                float3 viewWS = GetWorldSpaceNormalizeViewDir(i.positionWS);
                float3 viewF = normalize(mul((float3x3)_MBWorldToFormat, viewWS));
                MBWaterOut w = MBWaterShade(i.positionF, normalize(i.normalF), i.color, i.uv, viewF);
                clip(w.alpha - 0.04);
                float3 n = normalize(mul((float3x3)_MBFormatToWorld, w.normalF));
                if (!front) n = -n;
                half3 c = w.emission;
                if (w.lit > 0.5)
                {
                    InputData d = (InputData)0;
                    d.positionWS = i.positionWS;
                    d.positionCS = i.positionCS;
                    d.normalWS = n;
                    d.viewDirectionWS = viewWS;
                    d.shadowCoord = TransformWorldToShadowCoord(i.positionWS);
                    d.bakedGI = SampleSH(n);
                    d.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(i.positionCS);
                    d.shadowMask = half4(1, 1, 1, 1);
                    SurfaceData s = (SurfaceData)0;
                    s.albedo = w.albedo;
                    s.alpha = w.alpha;
                    s.smoothness = w.smoothness;
                    s.occlusion = 1.0;
                    s.emission = w.emission;
                    s.normalTS = float3(0, 0, 1);
                    c = UniversalFragmentPBR(d, s).rgb;
                }
                c = MixFog(c, i.fog);
                return half4(c * (w.lit > 0.5 ? 1.0 : w.alpha), w.alpha);
            }
            ENDHLSL
        }
    }

    SubShader
    {
        Tags { "Queue" = "Transparent" "RenderType" = "Transparent" }
        ZWrite On
        Cull Off
        CGPROGRAM
        #pragma surface surf Standard alpha:premul vertex:vert nolightmap nometa noshadow
        #pragma target 4.5
        #pragma multi_compile_local _MB_LOOK_STYLIZED _MB_LOOK_CLEAR _MB_LOOK_REFLECTIVE _MB_LOOK_LAVA _MB_LOOK_SWAMP _MB_LOOK_ACID
        #include "MBWaterCore.hlsl"
        float4 _Clapot;

        struct Input
        {
            float3 positionF;
            float3 normalF;
            float4 colour;
            float2 waterUV;
            float3 viewDir;
            float3 worldNormal;
            INTERNAL_DATA
        };

        void vert(inout appdata_full v, out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);
            float3 pw = mul(unity_ObjectToWorld, v.vertex).xyz;
            float3 pF = mul(_MBWorldToFormat, float4(pw, 1.0)).xyz;
            pF.y += wClapot(pF, MBWaterTime(), _Clapot.x, float4(_Clapot.y, _Clapot.z, _Clapot.w, 0));
            v.vertex.xyz = mul(unity_WorldToObject, float4(mul(_MBFormatToWorld, float4(pF, 1.0)).xyz, 1.0)).xyz;
            o.positionF = pF;
            o.normalF = mul((float3x3)_MBWorldToFormat, UnityObjectToWorldNormal(v.normal));
            o.colour = v.color;
            o.waterUV = float2(v.texcoord.x, 1.0 - v.texcoord.y);   // back to glTF UVs (the importer flips v)
            // The sheet has no tangents: any frame around the normal will do, the normal is given in world space below.
            float3 n = v.normal;
            float3 tg = normalize(abs(n.y) < 0.99 ? cross(n, float3(0, 1, 0)) : cross(n, float3(1, 0, 0)));
            v.tangent = float4(tg, 1.0);
        }

        void surf(Input i, inout SurfaceOutputStandard o)
        {
            float3 viewWS = normalize(UnityWorldSpaceViewDir(mul(_MBFormatToWorld, float4(i.positionF, 1.0)).xyz));
            float3 viewF = normalize(mul((float3x3)_MBWorldToFormat, viewWS));
            MBWaterOut w = MBWaterShade(i.positionF, normalize(i.normalF), i.colour, i.waterUV, viewF);
            clip(w.alpha - 0.04);
            float3 nW = normalize(mul((float3x3)_MBFormatToWorld, w.normalF));
            float3 tX = WorldNormalVector(i, float3(1, 0, 0));
            float3 tY = WorldNormalVector(i, float3(0, 1, 0));
            float3 tZ = WorldNormalVector(i, float3(0, 0, 1));
            o.Normal = normalize(float3(dot(nW, tX), dot(nW, tY), dot(nW, tZ)));
            o.Albedo = w.albedo;
            o.Emission = w.lit > 0.5 ? w.emission : w.emission * w.alpha;
            o.Smoothness = w.smoothness;
            o.Metallic = 0.0;
            o.Alpha = w.alpha;
        }
        ENDCG
    }
}
