// MarchingBlocks Paint for Unity — THE SIX WATER LOOKS (the app's eau_presets.gd, ported), on the baked sheet's CONTRACT:
// COLOR_0 r, g the flow along x and z (from [-1, 1] to [0, 1]); b the kind (0 still, 0.5 river, 0.75 foam, 1 waterfall);
// a the depth below / 8 (still water and rivers) or the amount of foam (waterfall, foam); NORMAL the shape; TEXCOORD_0
// x, z on still water and rivers, across, height on a waterfall.
//
// ⚠ WHAT DIFFERS FROM THE APP, ON PURPOSE: the app reads the depth of the RENDERED terrain (the depth buffer) and the
// screen texture (refraction, the relief's reflection). Neither is dependable in Unity's three pipelines without
// settings of yours; here the depth is the CONTRACT's (in cells), the bottom shows through TRANSPARENCY (no
// refraction) and the reflection is the environment's (no screen-space reflection). Every position is in FORMAT space
// (cells), as in the app.

#ifndef MB_WATER_CORE_INCLUDED
#define MB_WATER_CORE_INCLUDED

float4x4 _MBWorldToFormat;
float4x4 _MBFormatToWorld;
float _MBClock;
float _MBClockSet;
float4 _ColorA;        // per look: the main colour
float4 _ColorB;        // the deep colour
float4 _ColorC;        // foam / third colour
float4 _ColorD;        // a fourth colour
float4 _Params;        // per look (see MBWaterLooks.cs)
float4 _Params2;

float MBWaterTime() { return _MBClockSet > 0.5 ? _MBClock : _Time.y; }

float wBruit(float2 p) { return frac(sin(dot(floor(p), float2(127.1, 311.7))) * 43758.5453); }

float wBruitLisse(float2 p)
{
    float2 i = floor(p);
    float2 f = smoothstep(0.0, 1.0, frac(p));
    float a = wBruit(i), b = wBruit(i + float2(1, 0)), c = wBruit(i + float2(0, 1)), d = wBruit(i + float2(1, 1));
    return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
}

float wHauteurVagues(float2 p, float2 flux, float defile, float t)
{
    float2 n = float2(-flux.y, flux.x);
    float2 q = float2(dot(p, n), dot(p, flux) - defile);
    float h = 0.50 * sin(q.y * 1.35 + q.x * 0.35 + t * 1.1)
        + 0.32 * sin(q.y * 2.30 - q.x * 1.10 - t * 1.6)
        + 0.18 * sin(q.x * 3.10 + q.y * 1.70 + t * 2.3);
    return h + 0.45 * wBruitLisse(q * 1.3);
}

float3 wNormaleVagues(float2 p, float2 flux, float defile, float t, float relief)
{
    float e = 0.04;
    float h0 = wHauteurVagues(p, flux, defile, t);
    float hx = wHauteurVagues(p + float2(e, 0), flux, defile, t);
    float hz = wHauteurVagues(p + float2(0, e), flux, defile, t);
    return normalize(float3(-(hx - h0) / e * relief, 1.0, -(hz - h0) / e * relief));
}

float2 wHasard2(float2 p) { return frac(sin(float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)))) * 43758.5453); }

float wBordDeCellule(float2 p, float t)
{
    float2 i = floor(p);
    float2 f = frac(p);
    float d1 = 8.0, d2 = 8.0;
    for (int y = -1; y <= 1; y++)
        for (int x = -1; x <= 1; x++)
        {
            float2 g = float2(x, y);
            float2 o = 0.5 + 0.5 * sin(t * 0.3 + 6.2831 * wHasard2(i + g));
            float2 r = g + o - f;
            float d = dot(r, r);
            if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) d2 = d;
        }
    return sqrt(d2) - sqrt(d1);
}

float wBulleRonde(float2 q) { return 1.0 - smoothstep(0.18, 0.32, length(frac(q) - 0.5)); }

// The waterfall and its churn: (threads, foam, smooth lip), in [0, 1].
float3 wMotifCascade(float2 uv, float t, float nHaut, float mousse)
{
    float y = uv.y;
    float a = wBruitLisse(float2(uv.x * 4.5, (y + t * 2.2) * 0.35));
    float b = wBruitLisse(float2(uv.x * 11.0 + 7.3, (y + t * 3.1) * 0.75));
    float c = wBruitLisse(float2(uv.x * 27.0 + 1.7, (y + t * 4.3) * 1.9));
    float filets = saturate(smoothstep(0.42, 0.82, a) * 0.5 + smoothstep(0.5, 0.88, b) * 0.45 + smoothstep(0.6, 0.9, c) * 0.4);
    float lisse = smoothstep(0.45, 0.85, nHaut) * (1.0 - mousse);
    filets *= 1.0 - lisse * 0.9;
    float bouillon = wBruitLisse(float2(uv.x * 3.5 + t * 0.25, (y - t * 0.8) * 2.6)) * 0.6
        + wBruitLisse(float2(uv.x * 9.0 - t * 0.4, (y - t * 1.3) * 6.5)) * 0.4;
    float e = smoothstep(0.2, 0.7, mousse + (bouillon - 0.5) * 0.75);
    return float3(filets, e, lisse);
}

float3 wCouleurCascade(float3 cEau, float3 cEcume, float3 m, float bord)
{
    float3 base = lerp(lerp(cEau, cEcume, 0.32), cEau * 1.2 + 0.05, m.z);
    base = lerp(base, cEcume, bord * 0.35);
    return lerp(lerp(base, cEcume, m.x * 0.9), cEcume, m.y);
}

float wCaustique(float2 p, float t)
{
    float2 q = p + 0.35 * float2(sin(p.y * 1.3 + t), cos(p.x * 1.1 - t * 0.9));
    float2x2 rot = float2x2(0.80, -0.60, 0.60, 0.80);
    float v = 0.0, w = 0.0;
    for (int i = 0; i < 3; i++)
    {
        q = mul(rot, q) * 1.62;
        v += sin(q.x + t * (1.0 + i * 0.27)) * cos(q.y - t * (0.8 + i * 0.19));
        w += 1.0;
    }
    float crete = saturate(1.0 - abs(v / w));
    return pow(crete, 4.0);
}

// The clapot: a light swell that lifts the sheets AND the waterfalls (x, z only: a lip and its blade move together).
float wClapot(float3 pF, float t, float amount, float4 k) { return amount * sin(pF.z * k.x + pF.x * k.y + t * k.z); }

// What a look gives at a point: albedo, emission, alpha, smoothness, and whether the light counts (0: unlit).
struct MBWaterOut
{
    float3 albedo;
    float3 emission;
    float alpha;
    float smoothness;
    float lit;
    float3 normalF;    // the normal in FORMAT space
};

MBWaterOut MBWaterShade(float3 pF, float3 nF, float4 colour, float2 uv, float3 viewF)
{
    MBWaterOut o;
    float t = MBWaterTime();
    float2 courant = colour.rg * 2.0 - 1.0;
    float genre = colour.b;
    float mousse = colour.a;
    bool courante = genre > 0.25;
    bool cascade = genre > 0.6;
    bool remous = cascade && genre < 0.9;
    float2 flux = length(courant) > 0.1 ? normalize(courant) : float2(0.6, 0.8);
    // THE DEPTH, from the contract (cells / 8, capped at 1): the app reads the rendered terrain instead.
    float prof = cascade ? 0.0 : colour.a * 8.0;
    float bordC = 1.0 - abs(dot(normalize(nF), viewF));
    o.normalF = cascade ? normalize(nF) : float3(0, 1, 0);
    o.lit = 1.0;
    o.alpha = 1.0;
    o.emission = 0;
    o.smoothness = 0.94;
#if defined(_MB_LOOK_CLEAR) || defined(_MB_LOOK_REFLECTIVE) || defined(_MB_LOOK_SWAMP) || defined(_MB_LOOK_ACID)
    float vitesse = courante ? _Params.y : _Params.z;
    float defile = t * vitesse;
    float3 nw = cascade ? normalize(nF) : wNormaleVagues(pF.xz, flux, defile, t, _Params.w);
    o.normalF = nw;
#endif
#if defined(_MB_LOOK_CLEAR)
    // _ColorA tint, _ColorB deep tint, _ColorC foam; _Params.x absorption.
    float3 m = wMotifCascade(uv, t, normalize(nF).y, mousse);
    float transmis = exp(-prof * _Params.x * 0.5);
    float3 eau = lerp(_ColorA.rgb, _ColorB.rgb, 1.0 - exp(-prof * 0.35));
    o.albedo = cascade ? wCouleurCascade(_ColorA.rgb, _ColorC.rgb, m, bordC) : eau;
    o.alpha = remous ? m.y : (cascade ? 1.0 : saturate(1.0 - transmis + 0.25));
    o.smoothness = cascade ? lerp(0.55, 0.9, m.z) : 0.94;
#elif defined(_MB_LOOK_REFLECTIVE)
    // _ColorA tint, _ColorB waterfall tint, _ColorC foam; _Params.x absorption, _Params2.x minimum opacity.
    float3 m = wMotifCascade(uv, t, normalize(nF).y, mousse);
    float fresnel = 0.02 + 0.98 * pow(1.0 - saturate(dot(nw, viewF)), 5.0);
    o.albedo = cascade ? wCouleurCascade(_ColorB.rgb, _ColorC.rgb, m, bordC) : _ColorA.rgb;
    o.alpha = remous ? m.y : (cascade ? 0.92 : saturate(max(max(_Params2.x, fresnel), 1.0 - exp(-prof * _Params.x))));
    o.smoothness = cascade ? lerp(0.55, 0.9, m.z) : 0.97;
#elif defined(_MB_LOOK_LAVA)
    // _ColorA crust, _ColorB hot rock, _ColorC magma; _Params.x glow, _Params.y/z speeds, _Params.w plate size.
    float3 m = wMotifCascade(uv, t * 0.3, normalize(nF).y, mousse);
    float defile = t * (courante ? _Params.y : _Params.z);
    float2 p = pF.xz * _Params.w - flux * defile;
    float bord = wBordDeCellule(p, t);
    float fissure = 1.0 - smoothstep(0.0, 0.13, bord);
    float chaleur = smoothstep(0.05, 0.6, prof) * (0.75 + 0.25 * sin(t * 1.3 + wBruitLisse(p * 2.0) * 6.0));
    float3 albedo = lerp(_ColorA.rgb, _ColorB.rgb, wBruitLisse(p * 3.0) * 0.6);
    float lueur = fissure * chaleur + 0.08 * chaleur;
    float s = saturate(m.x * 0.8 + m.y);
    o.albedo = cascade ? lerp(_ColorB.rgb, _ColorA.rgb, s * 0.75) : albedo;
    o.emission = _ColorC.rgb * _Params.x * (cascade ? (1.0 - s * 0.7) * 0.8 : lueur);
    o.smoothness = 0.1;
    o.alpha = remous ? m.y : 1.0;
#elif defined(_MB_LOOK_SWAMP)
    // _ColorA murky, _ColorB deep murky, _ColorC duckweed, _ColorD mud; _Params.x absorption.
    float3 m = wMotifCascade(uv, t, normalize(nF).y, mousse);
    float transmis = exp(-prof * _Params.x);
    float3 eau = lerp(_ColorA.rgb, _ColorB.rgb, 1.0 - exp(-prof * 0.8));
    float2 q = pF.xz * 0.9 - flux * defile;
    float plaque = smoothstep(0.58, 0.68, wBruitLisse(q) * 0.7 + wBruitLisse(q * 3.1) * 0.3);
    float2 cb = floor(pF.xz * 5.0);
    float bulle = step(0.992, wBruit(cb + floor(t * 0.6 + wBruit(cb) * 10.0))) * (1.0 - plaque) * wBulleRonde(pF.xz * 5.0);
    float3 c = lerp(eau, _ColorC.rgb * (0.8 + 0.4 * wBruit(floor(q * 9.0))), plaque);
    c = lerp(c, float3(0.34, 0.37, 0.24), bulle);
    o.albedo = cascade ? wCouleurCascade(lerp(_ColorA.rgb, _ColorD.rgb, 0.5) * 1.6, float3(0.62, 0.58, 0.42), m, bordC) : c;
    o.smoothness = cascade ? 0.3 : lerp(0.85, 0.15, plaque);
    o.alpha = remous ? m.y : 1.0;
#elif defined(_MB_LOOK_ACID)
    // _ColorA acid, _ColorB deep acid, _ColorC foam; _Params.x luminescence.
    float3 m = wMotifCascade(uv, t, normalize(nF).y, mousse);
    float3 teinte = lerp(_ColorA.rgb, _ColorB.rgb, 1.0 - exp(-prof * 0.6));
    float h = wHauteurVagues(pF.xz, flux, defile, t);
    float crete = smoothstep(0.4, 1.0, h);
    float2 cb = floor(pF.xz * 6.0);
    float bulle = step(0.985, wBruit(cb + floor(t * 1.5 + wBruit(cb) * 10.0))) * wBulleRonde(pF.xz * 6.0);
    float blanc = cascade ? saturate(m.x * 0.45 + m.y * 0.8) : bulle;
    o.albedo = lerp(teinte * 0.3, _ColorC.rgb, blanc);
    o.emission = lerp(teinte * _Params.x * (0.55 + 0.45 * crete), _ColorC.rgb * _Params.x * 1.3, blanc);
    o.smoothness = 0.9;
    o.alpha = remous ? m.y : (cascade ? 1.0 : 0.92);
#else
    // STYLIZED (RiverStones): unlit, three tones by depth, a quantized swell along the flow, caustics in the shallow.
    // _ColorA light blue, _ColorB deep blue, _ColorC fringe, _ColorD lines; _Params.x/y thresholds, z/w speeds.
    o.lit = 0.0;
    float defile = t * (courante ? _Params.z : _Params.w);
    float p = saturate(prof / 1.9);
    float3 c = lerp(_ColorC.rgb, _ColorA.rgb, smoothstep(0.0, _Params.x, p));
    c = lerp(c, _ColorB.rgb, smoothstep(_Params.x * 0.8, _Params.y, p));
    float reseau = wCaustique(pF.xz * 1.15, t * 0.85);
    float lum = smoothstep(0.30, 0.42, reseau) * 0.42 + smoothstep(0.62, 0.72, reseau) * 0.58;
    c = lerp(c, float3(0.92, 1.0, 0.96), lum * (1.0 - smoothstep(0.18, 0.62, p)) * 0.6);
    float2 n = float2(-flux.y, flux.x);
    float2 q = float2(dot(pF.xz, n), (dot(pF.xz, flux) - defile) * (courante ? 0.6 : 0.17));
    float houle = 0.52 * (sin(q.x * 1.15 + q.y * 2.3) + 0.65 * sin(q.x * 2.10 - q.y * 1.7 + 1.3) + 0.40 * sin(q.x * 0.55 + q.y * 3.4 - 0.7));
    float marche = floor(saturate(houle * 0.5 + 0.5) * 2.997) / 2.0;
    float force = courante ? 0.9 : 0.35;
    float ampleur = 0.10 + 0.13 * force;
    float trait = smoothstep(0.86, 1.02, houle);
    float furtif = step(0.40, wBruit(float2(q.x * 0.30, floor(q.y * 0.6))));
    float lignes = trait * furtif * (0.35 + 0.65 * force);
    c *= 1.0 - ampleur + ampleur * 2.0 * marche;
    c = lerp(c, _ColorD.rgb, saturate(lignes * 0.5));
    float3 mc = wMotifCascade(uv, t, normalize(nF).y, mousse);
    float modele = 0.78 + 0.32 * saturate(dot(normalize(nF), normalize(float3(0.45, 0.75, 0.5))));
    float3 chute = lerp(lerp(_ColorB.rgb, _ColorA.rgb, 0.55), _ColorA.rgb * 1.1, mc.z) * modele;
    chute = lerp(chute, _ColorC.rgb, bordC * 0.45);
    chute = lerp(chute, _ColorD.rgb, mc.x * 0.85);
    chute = lerp(chute, _ColorD.rgb, mc.y);
    o.albedo = 0;
    o.emission = cascade ? chute : c;
    o.smoothness = 0.0;
    o.alpha = remous ? mc.y : 1.0;
#endif
    return o;
}

#endif
