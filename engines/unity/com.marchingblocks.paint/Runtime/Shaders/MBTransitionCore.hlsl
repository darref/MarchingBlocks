// MarchingBlocks Paint for Unity — THE BLEND, on the GPU (MBTransitions.Blend, line by line; the app's SHADER, transitions.gd).
// Shared by the Built-in and URP passes of MarchingBlocksTransition.shader: no pipeline include here.
//
// Every position here is in FORMAT space (right-handed, +Y up, 1 = one cell): the pass converts the world position by
// _MBWorldToFormat (the inverse of the layer's FormatToWorld — the measured frame of the importer, mirror included).
// The tile's vertex v comes from the TILE (_MBVertex, set per renderer), never from the point: on a joint, the point
// belongs to two tiles.

#ifndef MB_TRANSITION_CORE_INCLUDED
#define MB_TRANSITION_CORE_INCLUDED

#if defined(SHADER_TARGET_SURFACE_ANALYSIS)
// The Built-in surface shader's analysis pass: only the shape of the function matters.
float4x4 _MBWorldToFormat;
float4 MBTransition(float3 p, float3 n, out float roughness) { roughness = 1.0; return float4(p * 0.0 + n * 0.0, 1.0); }
#else

Texture3D _MBCells;            // one byte per cell: low nibble rank + 1, high nibble chosen rank + 1
Texture2D _MBTable;            // when Y covers X: (2X, Y) active, softness, reach, irregularity; (2X + 1, Y) fills_hollows, grain
Texture2DArray _MBReps;        // one slice per layer (white when the representative has no image)
SamplerState sampler_MBReps;
float4 _MBCellsOrigin;
float4 _MBCellsSize;
Texture2D _MBRepData;          // (k, 0): layer k's colour; (k, 1): x scale (cells per repeat), y roughness
float4x4 _MBWorldToFormat;
float4 _MBVertex;              // the tile's vertex v (per renderer)
float _MBShowChoices;

float MBHash(float3 p)
{
    p = frac(p * 0.3183099 + float3(0.11, 0.17, 0.13));
    p *= 17.0;
    return frac(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float MBNoise(float3 x)
{
    float3 i = floor(x);
    float3 f = frac(x);
    f = f * f * (3.0 - 2.0 * f);
    return lerp(lerp(lerp(MBHash(i), MBHash(i + float3(1, 0, 0)), f.x), lerp(MBHash(i + float3(0, 1, 0)), MBHash(i + float3(1, 1, 0)), f.x), f.y),
        lerp(lerp(MBHash(i + float3(0, 0, 1)), MBHash(i + float3(1, 0, 1)), f.x), lerp(MBHash(i + float3(0, 1, 1)), MBHash(i + float3(1, 1, 1)), f.x), f.y), f.z);
}

// The representative of layer k at p, projected in a box (weights |n|^4).
float4 MBAspect(int k, float3 p, float3 n)
{
    float3 w = pow(abs(n), 4.0);
    w /= (w.x + w.y + w.z);
    float e = max(_MBRepData.Load(int3(k, 1, 0)).x, 0.01);
    float4 c = _MBReps.Sample(sampler_MBReps, float3(p.zy / e, k)) * w.x
        + _MBReps.Sample(sampler_MBReps, float3(p.xz / e, k)) * w.y
        + _MBReps.Sample(sampler_MBReps, float3(p.xy / e, k)) * w.z;
    return c * _MBRepData.Load(int3(k, 0, 0));
}

float MBVisible(float4 p1, float4 p2, float sc, float h, float n)
{
    float shift = (p1.b + p2.r * (0.5 - h) + p1.a * (n - 0.5)) * 4.0 * sc * (1.0 - sc);
    return smoothstep(0.5 - p1.g * 0.5, 0.5 + p1.g * 0.5, sc + shift);
}

int MBRankAt(int3 c, int channel)
{
    int3 t = c - int3(_MBCellsOrigin.xyz);
    int3 size = int3(_MBCellsSize.xyz);
    if (t.x < 0 || t.y < 0 || t.z < 0 || t.x >= size.x || t.y >= size.y || t.z >= size.z)
        return -1;
    int v = (int)round(_MBCells.Load(int4(t, 0)).r * 255.0);
    return (channel == 0 ? (v & 15) : (v >> 4)) - 1;
}

// The look drawn over the surface at p (format space) with normal n: rgb = the OTHER layer's representative, a = its
// alpha; a = 0 where nothing blends. roughness: the other's.
float4 MBTransition(float3 p, float3 n, out float roughness)
{
    roughness = 1.0;
    int3 b = int3(round(_MBVertex.xyz));
    float3 f = saturate(p - float3(b) - 0.5);
    int r[8];
    float w[8];
    int owner = 999;
    [unroll] for (int k = 0; k < 8; k++)
    {
        int3 o = int3(k & 1, (k >> 1) & 1, (k >> 2) & 1);
        r[k] = MBRankAt(b + o, 0);
        float3 g = lerp(1.0 - f, f, float3(o));
        w[k] = g.x * g.y * g.z;
        if (r[k] >= 0 && r[k] < owner) owner = r[k];
    }
    if (owner == 999) return 0;
    float wOwner = 0.0;
    float best = 0.0;
    int other = -1;
    [unroll] for (int k2 = 0; k2 < 8; k2++)
    {
        if (r[k2] == owner) wOwner += w[k2];
        else if (r[k2] >= 0)
        {
            float part = 0.0;
            [unroll] for (int j = 0; j < 8; j++) if (r[j] == r[k2]) part += w[j];
            if (part > best) { best = part; other = r[k2]; }
        }
    }
    if (other < 0) return 0;
    float4 ao1 = _MBTable.Load(int3(2 * owner, other, 0));
    float4 oa1 = _MBTable.Load(int3(2 * other, owner, 0));
    if (ao1.r < 0.5 || oa1.r < 0.5) return 0;
    float4 ao2 = _MBTable.Load(int3(2 * owner + 1, other, 0));
    float4 oa2 = _MBTable.Load(int3(2 * other + 1, owner, 0));
    float s = best / (best + wOwner);
    int priority = min(owner, other);
    float vote = 0.0;
    bool painted = false;
    [unroll] for (int k3 = 0; k3 < 8; k3++)
    {
        int c = MBRankAt(b + int3(k3 & 1, (k3 >> 1) & 1, (k3 >> 2) & 1), 1);
        painted = painted || c >= 0;
        int covering = (c == owner || c == other) ? c : priority;
        if (covering == other) vote += w[k3];
    }
    // One noise per direction, at the grain of that direction (the app's shader; the cases give one n).
    float nOther = MBNoise(p * ao2.g);
    float hOwner = dot(MBAspect(owner, p, n).rgb, float3(0.299, 0.587, 0.114));
    float hOther = dot(MBAspect(other, p, n).rgb, float3(0.299, 0.587, 0.114));
    float aOther = MBVisible(ao1, ao2, s, hOwner, nOther);
    float aOwner = 1.0 - MBVisible(oa1, oa2, 1.0 - s, hOther, MBNoise(p * oa2.g));
    float a = vote * aOther + (1.0 - vote) * aOwner;
    if (a < 0.004) return 0;
    float3 colour = MBAspect(other, p, n).rgb;
    if (_MBShowChoices > 0.5 && painted) colour = lerp(colour, float3(1.0, 0.85, 0.2), 0.35);
    roughness = _MBRepData.Load(int3(other, 1, 0)).y;
    return float4(colour, a);
}

#endif
#endif
