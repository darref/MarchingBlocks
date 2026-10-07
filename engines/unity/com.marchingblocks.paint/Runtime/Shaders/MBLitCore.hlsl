// MarchingBlocks Paint for Unity — what MarchingBlocks/Lit computes, in both pipelines: the glTF metallic-roughness
// material of a tile or a plant, its ANIMATED TEXTURES (MBAnimation: frames, scroll, pulse — the rule, line by line) and
// the WIND of a plant (MBFoliage.Sway, line by line). The pass of each pipeline declares MB_URP or not, then lights the
// result with its own model (URP: UniversalFragmentPBR; Built-in: the Standard surface shader).

#ifndef MB_LIT_CORE_INCLUDED
#define MB_LIT_CORE_INCLUDED

#if defined(MB_URP)
    #define MB_TEX2D(n) TEXTURE2D(n); SAMPLER(sampler##n)
    #define MB_TEX2DARRAY(n) TEXTURE2D_ARRAY(n); SAMPLER(sampler##n)
    #define MB_SAMPLE2D(n, uv) SAMPLE_TEXTURE2D(n, sampler##n, uv)
    #define MB_SAMPLE2DARRAY(n, uv, i) SAMPLE_TEXTURE2D_ARRAY(n, sampler##n, uv, i)
    #define MB_UNPACK_NORMAL(p, s) UnpackNormalScale(p, s)
#else
    #define MB_TEX2D(n) UNITY_DECLARE_TEX2D(n)
    #define MB_TEX2DARRAY(n) UNITY_DECLARE_TEX2DARRAY(n)
    #define MB_SAMPLE2D(n, uv) UNITY_SAMPLE_TEX2D(n, uv)
    #define MB_SAMPLE2DARRAY(n, uv, i) UNITY_SAMPLE_TEX2DARRAY(n, float3(uv, i))
    #define MB_UNPACK_NORMAL(p, s) UnpackScaleNormal(p, s)
#endif

// The material (a copy of the importer's glTF material).
MB_TEX2D(_BaseMap);
MB_TEX2D(_MetallicRoughnessMap);   // glTF: G roughness, B metal
MB_TEX2D(_OcclusionMap);           // R
MB_TEX2D(_NormalMap);
MB_TEX2D(_EmissionMap);
float4 _BaseColor;
float _MetallicFactor;
float _RoughnessFactor;
float _OcclusionStrength;
float _NormalScale;
float4 _EmissionColor;
float _Cutoff;

// The animation (MBAnimation): per channel, frames (count, fps, ping-pong, synced) and a scroll (u, v, synced, on).
MB_TEX2DARRAY(_MBFramesAlbedo);
MB_TEX2DARRAY(_MBFramesNormal);
MB_TEX2DARRAY(_MBFramesORM);       // R occlusion, G roughness, B metal
MB_TEX2DARRAY(_MBFramesEmission);
float4 _MBFramesAlbedoParams, _MBFramesNormalParams, _MBFramesORMParams, _MBFramesEmissionParams;
float4 _MBScrollAlbedo, _MBScrollNormal, _MBScrollORM, _MBScrollEmission;
float4 _MBPulse;                   // frequency, minimum, synced, on

// Per renderer: the tile's phase (MBAnimation.PhaseOf, on the CPU, in double), the plant's wind data.
float _MBPhase;
float4 _MBWind;                    // ground, height, phase, amplitude — FORMAT space
float4x4 _MBWorldToFormat;
float4x4 _MBFormatToWorld;

// ONE CLOCK for every material: Unity's time, unless _MBClockSet (captures, tests).
float _MBClock;
float _MBClockSet;
float4 _MBWindDirection;           // x, z (default 1, 0.35)

float MBTime()
{
    return _MBClockSet > 0.5 ? _MBClock : _Time.y;
}

// k = floor(t fps + phase n); ping-pong (n > 1): p = 2n - 2, k mod p, then k or p - k; else k mod n.
float MBFrame(float4 params, float t)
{
    float n = params.x;
    float phase = params.w > 0.5 ? 0.0 : _MBPhase;
    float k = floor(t * params.y + phase * n);
    if (params.z > 0.5 && n > 1.0)
    {
        float p = 2.0 * n - 2.0;
        k = k - p * floor(k / p);
        return k < n ? k : p - k;
    }
    return k - n * floor(k / n);
}

float2 MBScroll(float4 scroll, float t)
{
    if (scroll.w < 0.5) return 0;
    return scroll.xy * (t + (scroll.z > 0.5 ? 0.0 : 7.0 * _MBPhase));
}

float MBPulseFactor(float t)
{
    if (_MBPulse.w < 0.5 || _MBPulse.x <= 0.0) return 1.0;
    float phase = _MBPulse.z > 0.5 ? 0.0 : _MBPhase;
    return lerp(_MBPulse.y, 1.0, 0.5 + 0.5 * cos(6.28318530718 * (t * _MBPulse.x + phase)));
}

struct MBSurface
{
    float3 albedo;
    float alpha;
    float metallic;
    float smoothness;
    float occlusion;
    float3 emission;
    float3 normalTS;
};

MBSurface MBEvaluate(float2 uv)
{
    float t = MBTime();
    MBSurface s;
    // glTF UVs: Unity's importers flip v (glTFast: v' = 1 - v); a scroll in v is then reversed — the rule is in glTF UVs.
    float2 uvA = uv + MBScroll(_MBScrollAlbedo, t) * float2(1, -1);
    float4 base = _MBFramesAlbedoParams.x > 0.5
        ? MB_SAMPLE2DARRAY(_MBFramesAlbedo, uvA, MBFrame(_MBFramesAlbedoParams, t))
        : MB_SAMPLE2D(_BaseMap, uvA);
    base *= _BaseColor;
    s.albedo = base.rgb;
    s.alpha = base.a;

    float2 uvO = uv + MBScroll(_MBScrollORM, t) * float2(1, -1);
    float occlusion, roughness, metallic;
    if (_MBFramesORMParams.x > 0.5)
    {
        float4 orm = MB_SAMPLE2DARRAY(_MBFramesORM, uvO, MBFrame(_MBFramesORMParams, t));
        occlusion = orm.r;
        roughness = orm.g;
        metallic = orm.b;
    }
    else
    {
        float4 mr = MB_SAMPLE2D(_MetallicRoughnessMap, uvO);
        occlusion = MB_SAMPLE2D(_OcclusionMap, uvO).r;
        roughness = mr.g;
        metallic = mr.b;
    }
    s.occlusion = lerp(1.0, occlusion, _OcclusionStrength);
    s.smoothness = 1.0 - saturate(roughness * _RoughnessFactor);
    s.metallic = saturate(metallic * _MetallicFactor);

    float2 uvN = uv + MBScroll(_MBScrollNormal, t) * float2(1, -1);
    if (_MBFramesNormalParams.x > 0.5)
    {
        float3 n = MB_SAMPLE2DARRAY(_MBFramesNormal, uvN, MBFrame(_MBFramesNormalParams, t)).rgb * 2.0 - 1.0;
        n.xy *= _NormalScale;
        s.normalTS = normalize(n);
    }
    else
        s.normalTS = MB_UNPACK_NORMAL(MB_SAMPLE2D(_NormalMap, uvN), _NormalScale);

    float2 uvE = uv + MBScroll(_MBScrollEmission, t) * float2(1, -1);
    float3 e = _MBFramesEmissionParams.x > 0.5
        ? MB_SAMPLE2DARRAY(_MBFramesEmission, uvE, MBFrame(_MBFramesEmissionParams, t)).rgb
        : MB_SAMPLE2D(_EmissionMap, uvE).rgb;
    s.emission = e * _EmissionColor.rgb * MBPulseFactor(t);
    return s;
}

// THE WIND (MBFoliage.Sway): a vertex of a plant, in WORLD space, with its world normal — moved in FORMAT space.
float3 MBSway(float3 positionWS, float3 normalWS)
{
    if (_MBWind.y <= 0.0) return positionWS;
    float t = MBTime();
    float3 p = mul(_MBWorldToFormat, float4(positionWS, 1.0)).xyz;
    float3 n = normalize(mul((float3x3)_MBWorldToFormat, normalWS));
    float h = saturate((p.y - _MBWind.x) / _MBWind.y);
    float amp = _MBWind.w * _MBWind.y * 0.05;
    float b = 0.35 + 0.6 * sin(t * 1.1 + _MBWind.z) + 0.3 * sin(t * 2.3 + _MBWind.z * 1.7);
    float2 d = _MBWindDirection.x == 0.0 && _MBWindDirection.y == 0.0 ? float2(1.0, 0.35) : _MBWindDirection.xy;
    p.xz += normalize(d) * b * amp * h * h;
    p += n * sin(t * 7.0 + dot(p, float3(2.1, 1.7, 2.9))) * 0.015 * _MBWind.w * h;
    return mul(_MBFormatToWorld, float4(p, 1.0)).xyz;
}

#endif
