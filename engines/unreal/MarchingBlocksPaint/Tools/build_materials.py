# MarchingBlocks Paint for Unreal — BUILDS THE PLUGIN'S MATERIALS (Content/Materials), from this text.
#
# Unreal materials are binary assets: this script is their source. It writes, with the editor's own scripting
# (MaterialEditingLibrary), one material per look, each a few parameters and Custom HLSL nodes that say the
# MarchingBlocks rule line by line:
#   M_MB_Animated       the animated textures (frames, scroll, pulse) of a tile material — the rule of
#                       Tests/animation_conformance.json; the phase comes per instance, computed on the CPU in double;
#   M_MB_Transition     the blend between two layers, laid as an OVERLAY over the tiles — Tests/transitions_conformance.json;
#   M_MB_Wind           the plants' material, swaying in the wind (World Position Offset) — Tests/foliage_conformance.json;
#   M_MB_Water_<look>   the six water presets (stylized, clear, reflective, lava, swamp, acid) on the baked sheet.
# Every rule is written in FORMAT space (right-handed, +Y up, 1 = a cell): each material receives the conversion rows
# MB_ToFormat0..2 (world -> format) and MB_ToWorld0..2 (format vector -> world), set by the plugin.
#
# Run it in the editor of a project where the plugin is installed (Tools > Execute Python Script, or
# UnrealEditor-Cmd <project> -ExecutePythonScript=<this file>). It overwrites the assets it makes.

import unreal

ROOT = "/MarchingBlocksPaint/Materials"
MEL = unreal.MaterialEditingLibrary
AT = unreal.AssetToolsHelpers.get_asset_tools()
EAL = unreal.EditorAssetLibrary

WHITE = "/Engine/EngineResources/WhiteSquareTexture.WhiteSquareTexture"
BLACK = "/Engine/EngineResources/Black.Black"
FLAT_NORMAL = "/Engine/EngineMaterials/DefaultNormal.DefaultNormal"
DEFAULT_VOLUME = "/Engine/EngineResources/DefaultVolumeTexture.DefaultVolumeTexture"
DEFAULT_ARRAY = "/Engine/EngineMaterials/WeightMapArrayPlaceholderTexture.WeightMapArrayPlaceholderTexture"

F1, F2, F3, F4 = (unreal.CustomMaterialOutputType.CMOT_FLOAT1, unreal.CustomMaterialOutputType.CMOT_FLOAT2,
                  unreal.CustomMaterialOutputType.CMOT_FLOAT3, unreal.CustomMaterialOutputType.CMOT_FLOAT4)


class Graph:
    """A material being written: nodes placed in columns, connected by name."""

    def __init__(self, name, **props):
        path = ROOT + "/" + name
        if EAL.does_asset_exist(path):
            EAL.delete_asset(path)
        self.m = AT.create_asset(name, ROOT, unreal.Material, unreal.MaterialFactoryNew())
        # Only the usages the plugin needs: every usage is one more set of shader permutations to compile.
        self.m.set_editor_property("used_with_instanced_static_meshes", props.pop("instanced", True))
        for k, v in props.items():
            self.m.set_editor_property(k, v)
        self.y = 0

    def node(self, cls, x=-1200, **props):
        self.y += 90
        n = MEL.create_material_expression(self.m, cls, x, self.y)
        for k, v in props.items():
            n.set_editor_property(k, v)
        return n

    def scalar(self, name, default=0.0):
        return self.node(unreal.MaterialExpressionScalarParameter, parameter_name=name, default_value=default)

    def vector(self, name, default=(0.0, 0.0, 0.0, 0.0)):
        return self.node(unreal.MaterialExpressionVectorParameter, parameter_name=name,
                         default_value=unreal.LinearColor(*default))

    def texture(self, name, path, sampler=None):
        n = self.node(unreal.MaterialExpressionTextureObjectParameter, parameter_name=name, texture=unreal.load_asset(path))
        if sampler is not None:
            n.set_editor_property("sampler_type", sampler)
        return n

    def instance_data(self, index):
        return self.node(unreal.MaterialExpressionPerInstanceCustomData, data_index=index)

    def custom(self, code, inputs, output_type, extra_outputs=(), x=-500, description="MarchingBlocks"):
        """inputs: [(name, node, output name)]; extra_outputs: [(name, type)]."""
        c = self.node(unreal.MaterialExpressionCustom, x=x, code=code, output_type=output_type, description=description)
        ins = []
        for name, _, _ in inputs:
            ci = unreal.CustomInput()
            ci.set_editor_property("input_name", name)
            ins.append(ci)
        c.set_editor_property("inputs", ins)
        outs = []
        for name, t in extra_outputs:
            co = unreal.CustomOutput()
            co.set_editor_property("output_name", name)
            co.set_editor_property("output_type", t)
            outs.append(co)
        if outs:
            c.set_editor_property("additional_outputs", outs)
        for name, src, out in inputs:
            MEL.connect_material_expressions(src, out, c, name)
        return c

    def mask(self, src, out, channels):
        n = self.node(unreal.MaterialExpressionComponentMask, x=-200, **{c: True for c in channels})
        MEL.connect_material_expressions(src, out, n, "")
        return n

    def to(self, src, out, prop):
        MEL.connect_material_property(src, out, prop)

    def done(self):
        MEL.layout_material_expressions(self.m)
        MEL.recompile_material(self.m)
        EAL.save_loaded_asset(self.m)
        unreal.log("MarchingBlocks: built " + self.m.get_path_name())
        return self.m

    # The format conversion every look needs.
    def rows(self):
        return ([("R%d" % i, self.vector("MB_ToFormat%d" % i, (0.01 if i == 0 else 0, 0.01 if i == 2 else 0, 0.01 if i == 1 else 0, 0)), "RGBA")
                 for i in range(3)],
                [("W%d" % i, self.vector("MB_ToWorld%d" % i, (100 if i == 0 else 0, 100 if i == 2 else 0, 100 if i == 1 else 0, 0)), "RGBA")
                 for i in range(3)])

    def world_position(self, with_offsets=False):
        return self.node(unreal.MaterialExpressionWorldPosition, world_position_shader_offset=(
            unreal.WorldPositionIncludedOffsets.WPT_DEFAULT if with_offsets else unreal.WorldPositionIncludedOffsets.WPT_EXCLUDE_ALL_SHADER_OFFSETS))


TO_FORMAT = """
float3 pf = float3(dot(R0.xyz, P) + R0.w, dot(R1.xyz, P) + R1.w, dot(R2.xyz, P) + R2.w);
"""

# ══ ANIMATED TEXTURES ═══════════════════════════════════════════════════════════════════════════════════════════════
# The rule (animation_conformance.json): k = floor(t fps + phase n); ping-pong p = 2n - 2, k mod p, k < n ? k : p - k;
# else k mod n. Scroll offset = (u, v) (t + (synced ? 0 : 7 phase)). Pulse = minimum + (1 - minimum)(0.5 + 0.5 cos(2 pi (t f
# + phase))). The phase is per instance (custom data 3), computed by the plugin in double.

ANIM_UV = """
// One channel's UV and frame. Returns the UV (xy) and the frame (z, -1 without frames).
float phaseF = FramesSynced > 0.5 ? 0.0 : Phase;
float phaseS = ScrollSynced > 0.5 ? 0.0 : Phase;
float2 uv = UV;
if (Scrolling > 0.5) uv += float2(ScrollU, ScrollV) * (T + 7.0 * phaseS);
float k = -1.0;
if (Count > 0.5)
{
    float n = floor(Count + 0.5);
    float kk = floor(T * Fps + phaseF * n);
    if (PingPong > 0.5 && n > 1.5)
    {
        float p = 2.0 * n - 2.0;
        kk = kk - p * floor(kk / p);
        k = kk < n ? kk : p - kk;
    }
    else k = kk - n * floor(kk / n);
}
return float3(uv, k);
"""


def animated():
    g = Graph("M_MB_Animated")
    uv = g.node(unreal.MaterialExpressionTextureCoordinate)
    t = g.node(unreal.MaterialExpressionTime)
    phase = g.instance_data(3)
    channels = {}
    for ch, still_path, sampler in (("BaseColor", WHITE, unreal.MaterialSamplerType.SAMPLERTYPE_COLOR),
                                     ("Normal", FLAT_NORMAL, unreal.MaterialSamplerType.SAMPLERTYPE_NORMAL),
                                     ("ORM", WHITE, None),
                                     ("Emissive", BLACK, unreal.MaterialSamplerType.SAMPLERTYPE_COLOR)):
        p = "MB_" + ch
        c = g.custom(ANIM_UV, [("UV", uv, ""), ("T", t, ""), ("Phase", phase, ""),
                               ("Count", g.scalar(p + "_Count"), ""), ("Fps", g.scalar(p + "_Fps", 12.0), ""),
                               ("PingPong", g.scalar(p + "_PingPong"), ""), ("FramesSynced", g.scalar(p + "_FramesSynced"), ""),
                               ("Scrolling", g.scalar(p + "_Scrolling"), ""), ("ScrollU", g.scalar(p + "_ScrollU"), ""),
                               ("ScrollV", g.scalar(p + "_ScrollV", -0.25), ""), ("ScrollSynced", g.scalar(p + "_ScrollSynced", 1.0), "")],
                     F3, description=ch + " UV and frame")
        uvxy = g.mask(c, "", ["r", "g"])
        # The still texture, sampled by a standard node (its own sampler type: sRGB, normal map…) — ORM (linear) in the
        # Custom node: a standard node checks its sampler type against the default texture.
        if sampler is None:
            still = g.texture(p + "_Still", still_path)
        else:
            still = g.node(unreal.MaterialExpressionTextureSampleParameter2D, parameter_name=p + "_Still",
                           texture=unreal.load_asset(still_path), sampler_type=sampler)
            MEL.connect_material_expressions(uvxy, "", still, "UVs")
        frames = g.texture(p + "_Frames", DEFAULT_ARRAY)
        channels[ch] = (c, still, frames, g.scalar(p + "_HasStill"))
    pulse = [("PulseOn", g.scalar("MB_PulseOn"), ""), ("PulseF", g.scalar("MB_PulseFrequency", 0.5), ""),
             ("PulseMin", g.scalar("MB_PulseMinimum", 0.2), ""), ("PulseSynced", g.scalar("MB_PulseSynced"), "")]
    inputs = [("T", t, ""), ("Phase", phase, "")] + pulse
    for ch, (c, still, frames, has) in channels.items():
        inputs += [(ch + "UVK", c, ""), (ch + "Still", still, "" if ch == "ORM" else "RGBA"), (ch + "Frames", frames, ""), (ch + "Has", has, "")]
    inputs += [("BaseColorFactor", g.vector("MB_BaseColorFactor", (1, 1, 1, 1)), "RGBA"),
               ("EmissiveFactor", g.vector("MB_EmissiveFactor", (0, 0, 0, 0)), "RGBA"),
               ("EmissiveStrength", g.scalar("MB_EmissiveStrength", 1.0), ""),
               ("MetallicFactor", g.scalar("MB_MetallicFactor", 0.0), ""),
               ("RoughnessFactor", g.scalar("MB_RoughnessFactor", 1.0), "")]
    code = """
// Each channel: the frames (an array) when it has some, else its still texture, else the glTF default.
float4 bc = BaseColorHas > 0.5 ? BaseColorStill : float4(1, 1, 1, 1);
if (BaseColorUVK.z >= 0.0) bc = BaseColorFrames.Sample(BaseColorFramesSampler, BaseColorUVK);
float3 nrm = NormalHas > 0.5 ? NormalStill.xyz : float3(0, 0, 1);
if (NormalUVK.z >= 0.0) nrm = NormalFrames.Sample(NormalFramesSampler, NormalUVK).xyz * 2.0 - 1.0;
float4 orm = ORMHas > 0.5 ? ORMStill.Sample(ORMStillSampler, ORMUVK.xy) : float4(1, 1, 1, 1);
if (ORMUVK.z >= 0.0) orm = ORMFrames.Sample(ORMFramesSampler, ORMUVK);
float3 em = EmissiveHas > 0.5 ? EmissiveStill.rgb : float3(1, 1, 1);
if (EmissiveUVK.z >= 0.0) em = EmissiveFrames.Sample(EmissiveFramesSampler, EmissiveUVK).rgb;
float pulse = 1.0;
if (PulseOn > 0.5 && PulseF > 0.0)
{
    float ph = PulseSynced > 0.5 ? 0.0 : Phase;
    pulse = PulseMin + (1.0 - PulseMin) * (0.5 + 0.5 * cos(6.28318530718 * (T * PulseF + ph)));
}
Normal = normalize(nrm);
Rough = orm.g * RoughnessFactor;
Metal = orm.b * MetallicFactor;
AO = orm.r;
Emit = em * EmissiveFactor.rgb * EmissiveStrength * pulse;
return bc.rgb * BaseColorFactor.rgb;
"""
    out = g.custom(code, inputs, F3, [("Normal", F3), ("Rough", F1), ("Metal", F1), ("AO", F1), ("Emit", F3)], x=-250,
                   description="MarchingBlocks animated material")
    g.to(out, "", unreal.MaterialProperty.MP_BASE_COLOR)
    g.to(out, "Normal", unreal.MaterialProperty.MP_NORMAL)
    g.to(out, "Rough", unreal.MaterialProperty.MP_ROUGHNESS)
    g.to(out, "Metal", unreal.MaterialProperty.MP_METALLIC)
    g.to(out, "AO", unreal.MaterialProperty.MP_AMBIENT_OCCLUSION)
    g.to(out, "Emit", unreal.MaterialProperty.MP_EMISSIVE_COLOR)
    return g.done()


# ══ TRANSITIONS ═════════════════════════════════════════════════════════════════════════════════════════════════════
# The rule (transitions_conformance.json, the app's SHADER line by line). The tile's vertex v comes per instance (custom
# data 0..2): on a joint a point belongs to two tiles, so v is never deduced from the point.

TRANSITION = """
struct MBT
{
    float hache(float3 p)
    {
        p = frac(p * 0.3183099 + float3(0.11, 0.17, 0.13));
        p *= 17.0;
        return frac(p.x * p.y * p.z * (p.x + p.y + p.z));
    }
    float bruit3(float3 x)
    {
        float3 i = floor(x);
        float3 f = frac(x);
        f = f * f * (3.0 - 2.0 * f);
        return lerp(lerp(lerp(hache(i), hache(i + float3(1, 0, 0)), f.x), lerp(hache(i + float3(0, 1, 0)), hache(i + float3(1, 1, 0)), f.x), f.y),
            lerp(lerp(hache(i + float3(0, 0, 1)), hache(i + float3(1, 0, 1)), f.x), lerp(hache(i + float3(0, 1, 1)), hache(i + float3(1, 1, 1)), f.x), f.y), f.z);
    }
    float visible(float4 p1, float4 p2, float s_c, float h, float n)
    {
        float decalage = (p1.b + p2.r * (0.5 - h) + p1.a * (n - 0.5)) * 4.0 * s_c * (1.0 - s_c);
        return smoothstep(0.5 - p1.g * 0.5, 0.5 + p1.g * 0.5, s_c + decalage);
    }
};
MBT M;
""" + TO_FORMAT + """
float3 nf = normalize(float3(dot(R0.xyz, N), dot(R1.xyz, N), dot(R2.xyz, N)));
int3 b = int3(round(float3(Vx, Vy, Vz)));
float3 f = saturate(pf - float3(b) - 0.5);
int3 o3 = int3(round(Origin.xyz));
int3 s3 = int3(round(Size.xyz));
int r[8];
int ch[8];
float w[8];
int proprio = 999;
[unroll] for (int k = 0; k < 8; k++)
{
    int3 o = int3(k & 1, (k >> 1) & 1, (k >> 2) & 1);
    int3 t = b + o - o3;
    int v = 0;
    if (t.x >= 0 && t.y >= 0 && t.z >= 0 && t.x < s3.x && t.y < s3.y && t.z < s3.z)
        v = (int)round(Cells.Load(int4(t, 0)).r * 255.0);
    r[k] = (v & 15) - 1;
    ch[k] = (v >> 4) - 1;
    float3 g = lerp(1.0 - f, f, float3(o));
    w[k] = g.x * g.y * g.z;
    if (r[k] >= 0 && r[k] < proprio) proprio = r[k];
}
Rough = 1.0;
if (proprio == 999) return float4(0, 0, 0, 0);
float w_proprio = 0.0;
float meilleur = 0.0;
int autre = -1;
[unroll] for (int k2 = 0; k2 < 8; k2++)
{
    if (r[k2] == proprio) w_proprio += w[k2];
    else if (r[k2] >= 0)
    {
        float part = 0.0;
        [unroll] for (int j = 0; j < 8; j++) if (r[j] == r[k2]) part += w[j];
        if (part > meilleur) { meilleur = part; autre = r[k2]; }
    }
}
if (autre < 0) return float4(0, 0, 0, 0);
float4 ao1 = Table.Load(int3(2 * proprio, autre, 0));
float4 oa1 = Table.Load(int3(2 * autre, proprio, 0));
if (ao1.r < 0.5 || oa1.r < 0.5) return float4(0, 0, 0, 0);
float4 ao2 = Table.Load(int3(2 * proprio + 1, autre, 0));
float4 oa2 = Table.Load(int3(2 * autre + 1, proprio, 0));
float s = meilleur / (meilleur + w_proprio);
int prioritaire = min(proprio, autre);
float vote_autre = 0.0;
bool peint = false;
[unroll] for (int k3 = 0; k3 < 8; k3++)
{
    int c = ch[k3];
    peint = peint || c >= 0;
    int couvrant = (c == proprio || c == autre) ? c : prioritaire;
    if (couvrant == autre) vote_autre += w[k3];
}
// The representatives, projected in a box (weights |n|^4), times their colour.
float3 bw = pow(abs(nf), 4.0);
bw /= (bw.x + bw.y + bw.z);
float4 pp = RepParams.Load(int3(proprio, 1, 0));
float4 pa = RepParams.Load(int3(autre, 1, 0));
float ep = max(pp.x, 0.01);
float ea = max(pa.x, 0.01);
float4 cp = (Reps.Sample(RepsSampler, float3(pf.zy / ep, proprio)) * bw.x + Reps.Sample(RepsSampler, float3(pf.xz / ep, proprio)) * bw.y
    + Reps.Sample(RepsSampler, float3(pf.xy / ep, proprio)) * bw.z) * RepParams.Load(int3(proprio, 0, 0));
float4 ca = (Reps.Sample(RepsSampler, float3(pf.zy / ea, autre)) * bw.x + Reps.Sample(RepsSampler, float3(pf.xz / ea, autre)) * bw.y
    + Reps.Sample(RepsSampler, float3(pf.xy / ea, autre)) * bw.z) * RepParams.Load(int3(autre, 0, 0));
float h_proprio = dot(cp.rgb, float3(0.299, 0.587, 0.114));
float h_autre = dot(ca.rgb, float3(0.299, 0.587, 0.114));
float n1 = M.bruit3(pf * ao2.g);
float a_autre = M.visible(ao1, ao2, s, h_proprio, n1);
float a_proprio = 1.0 - M.visible(oa1, oa2, 1.0 - s, h_autre, M.bruit3(pf * oa2.g));
float a = vote_autre * a_autre + (1.0 - vote_autre) * a_proprio;
if (a < 0.004) return float4(0, 0, 0, 0);
float3 couleur = ca.rgb;
if (ShowChoices > 0.5 && peint) couleur = lerp(couleur, float3(1.0, 0.85, 0.2), 0.35);
Rough = pa.y;
return float4(couleur, a);
"""


def transition():
    g = Graph("M_MB_Transition", blend_mode=unreal.BlendMode.BLEND_TRANSLUCENT,
              translucency_lighting_mode=unreal.TranslucencyLightingMode.TLM_SURFACE_PER_PIXEL_LIGHTING)
    rows, _ = g.rows()
    p = g.world_position(True)
    n = g.node(unreal.MaterialExpressionVertexNormalWS)
    inputs = [("P", p, ""), ("N", n, "")] + rows + [
        ("Vx", g.instance_data(0), ""), ("Vy", g.instance_data(1), ""), ("Vz", g.instance_data(2), ""),
        ("Origin", g.vector("MB_CellsOrigin"), ""), ("Size", g.vector("MB_CellsSize", (1, 1, 1, 0)), ""),
        ("Cells", g.texture("MB_Cells", DEFAULT_VOLUME), ""), ("Table", g.texture("MB_Table", BLACK), ""),
        ("Reps", g.texture("MB_Reps", DEFAULT_ARRAY), ""), ("RepParams", g.texture("MB_RepParams", WHITE), ""),
        ("ShowChoices", g.scalar("MB_ShowChoices"), "")]
    c = g.custom(TRANSITION, inputs, F4, [("Rough", F1)], description="MarchingBlocks transitions (the blend)")
    g.to(g.mask(c, "", ["r", "g", "b"]), "", unreal.MaterialProperty.MP_BASE_COLOR)
    g.to(g.mask(c, "", ["a"]), "", unreal.MaterialProperty.MP_OPACITY)
    g.to(c, "Rough", unreal.MaterialProperty.MP_ROUGHNESS)
    # Pushed 2 thousandths of a cell along the normal: two passes over the same geometry may not agree on depth to the bit.
    push = g.custom("return N * 0.2;", [("N", n, "")], F3, description="push along the normal")
    g.to(push, "", unreal.MaterialProperty.MP_WORLD_POSITION_OFFSET)
    return g.done()


# ══ WIND ════════════════════════════════════════════════════════════════════════════════════════════════════════════
# The rule (foliage_conformance.json, sway): h = clamp((P.y - ground) / height, 0, 1); b = 0.35 + 0.6 sin(1.1 t + phase)
# + 0.3 sin(2.3 t + 1.7 phase); P.xz += normalize(1, 0.35) b amplitude height 0.05 h^2; then P += N sin(7 t + P.(2.1, 1.7,
# 2.9)) 0.015 amplitude h. In format space; the offset goes back to the world through MB_ToWorld.

WIND = TO_FORMAT + """
float3 nf = normalize(float3(dot(R0.xyz, N), dot(R1.xyz, N), dot(R2.xyz, N)));
float haut = Wind.y;
if (haut <= 0.0) return float3(0, 0, 0);
float h = saturate((pf.y - Wind.x) / haut);
float phase = Wind.z;
float ampleur = Wind.w * haut * 0.05;
float b = 0.35 + 0.6 * sin(T * 1.1 + phase) + 0.3 * sin(T * 2.3 + phase * 1.7);
float2 s = normalize(float2(1.0, 0.35)) * b * ampleur * h * h;
float3 v = pf + float3(s.x, 0.0, s.y);
v += nf * sin(T * 7.0 + dot(v, float3(2.1, 1.7, 2.9))) * 0.015 * Wind.w * h;
float3 d = v - pf;
return float3(dot(W0.xyz, d), dot(W1.xyz, d), dot(W2.xyz, d));
"""


def wind():
    g = Graph("M_MB_Wind", blend_mode=unreal.BlendMode.BLEND_MASKED, two_sided=True, opacity_mask_clip_value=0.5)
    rows, back = g.rows()
    data = g.node(unreal.MaterialExpressionAppendVector)
    xy = g.node(unreal.MaterialExpressionAppendVector)
    MEL.connect_material_expressions(g.instance_data(0), "", xy, "A")
    MEL.connect_material_expressions(g.instance_data(1), "", xy, "B")
    xyz = g.node(unreal.MaterialExpressionAppendVector)
    MEL.connect_material_expressions(xy, "", xyz, "A")
    MEL.connect_material_expressions(g.instance_data(2), "", xyz, "B")
    MEL.connect_material_expressions(xyz, "", data, "A")
    MEL.connect_material_expressions(g.instance_data(3), "", data, "B")
    off = g.custom(WIND, [("P", g.world_position(False), ""), ("N", g.node(unreal.MaterialExpressionVertexNormalWS), ""),
                          ("Wind", data, ""), ("T", g.node(unreal.MaterialExpressionTime), "")] + rows + back, F3,
                   description="MarchingBlocks wind (sway)")
    g.to(off, "", unreal.MaterialProperty.MP_WORLD_POSITION_OFFSET)
    uv = g.node(unreal.MaterialExpressionTextureCoordinate)
    samples = {}
    samples["ORM"] = g.texture("MB_ORM_Still", WHITE)
    for ch, path, sampler in (("BaseColor", WHITE, unreal.MaterialSamplerType.SAMPLERTYPE_COLOR),
                              ("Normal", FLAT_NORMAL, unreal.MaterialSamplerType.SAMPLERTYPE_NORMAL)):
        s = g.node(unreal.MaterialExpressionTextureSampleParameter2D, parameter_name="MB_%s_Still" % ch,
                   texture=unreal.load_asset(path), sampler_type=sampler)
        MEL.connect_material_expressions(uv, "", s, "UVs")
        samples[ch] = s
    code = """
float4 bc = BaseColorHas > 0.5 ? BaseColor : float4(1, 1, 1, 1);
float4 orm = ORMHas > 0.5 ? ORM.Sample(ORMSampler, UV) : float4(1, 1, 1, 1);
Normal = NormalHas > 0.5 ? Nrm.xyz : float3(0, 0, 1);
Rough = orm.g * RoughnessFactor;
Metal = orm.b * MetallicFactor;
Mask = bc.a * BaseColorFactor.a;
return bc.rgb * BaseColorFactor.rgb;
"""
    out = g.custom(code, [("BaseColor", samples["BaseColor"], "RGBA"), ("Nrm", samples["Normal"], "RGB"), ("ORM", samples["ORM"], ""), ("UV", uv, ""),
                          ("BaseColorHas", g.scalar("MB_BaseColor_HasStill"), ""), ("NormalHas", g.scalar("MB_Normal_HasStill"), ""),
                          ("ORMHas", g.scalar("MB_ORM_HasStill"), ""), ("BaseColorFactor", g.vector("MB_BaseColorFactor", (1, 1, 1, 1)), "RGBA"),
                          ("RoughnessFactor", g.scalar("MB_RoughnessFactor", 1.0), ""), ("MetallicFactor", g.scalar("MB_MetallicFactor", 0.0), "")],
                   F3, [("Normal", F3), ("Rough", F1), ("Metal", F1), ("Mask", F1)], x=-250, description="MarchingBlocks plant look")
    g.to(out, "", unreal.MaterialProperty.MP_BASE_COLOR)
    g.to(out, "Normal", unreal.MaterialProperty.MP_NORMAL)
    g.to(out, "Rough", unreal.MaterialProperty.MP_ROUGHNESS)
    g.to(out, "Metal", unreal.MaterialProperty.MP_METALLIC)
    g.to(out, "Mask", unreal.MaterialProperty.MP_OPACITY_MASK)
    return g.done()


# ══ WATER ═══════════════════════════════════════════════════════════════════════════════════════════════════════════
# The six presets of MarchingBlocks (addons/marchingblocks_core/eau_presets.gd), rewritten in HLSL on the same data:
# COLOR_0 r g = the flow, b = the kind, a = depth / 8 or foam; TEXCOORD_0; the normal. The depth below is measured
# against the rendered terrain (the scene depth), VERTICALLY in format space, as the app does.

WATER_COMMON = """
struct MBW
{
    float bruit(float2 p) { return frac(sin(dot(floor(p), float2(127.1, 311.7))) * 43758.5453); }
    float bruit_lisse(float2 p)
    {
        float2 i = floor(p);
        float2 f = smoothstep(0.0, 1.0, frac(p));
        float a = bruit(i);
        float b = bruit(i + float2(1.0, 0.0));
        float c = bruit(i + float2(0.0, 1.0));
        float d = bruit(i + float2(1.0, 1.0));
        return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
    }
    float hauteur_vagues(float2 p, float2 flux, float defile, float t)
    {
        float2 n = float2(-flux.y, flux.x);
        float2 q = float2(dot(p, n), dot(p, flux) - defile);
        float h = 0.50 * sin(q.y * 1.35 + q.x * 0.35 + t * 1.1) + 0.32 * sin(q.y * 2.30 - q.x * 1.10 - t * 1.6)
            + 0.18 * sin(q.x * 3.10 + q.y * 1.70 + t * 2.3);
        return h + 0.45 * bruit_lisse(q * 1.3);
    }
    float3 normale_vagues(float2 p, float2 flux, float defile, float t, float relief)
    {
        float e = 0.04;
        float h0 = hauteur_vagues(p, flux, defile, t);
        float hx = hauteur_vagues(p + float2(e, 0.0), flux, defile, t);
        float hz = hauteur_vagues(p + float2(0.0, e), flux, defile, t);
        return normalize(float3(-(hx - h0) / e * relief, 1.0, -(hz - h0) / e * relief));
    }
    float3 bruit_derive(float2 p)
    {
        float2 i = floor(p);
        float2 f = frac(p);
        float2 u = f * f * (3.0 - 2.0 * f);
        float2 du = 6.0 * f * (1.0 - f);
        float a = bruit(i);
        float b = bruit(i + float2(1.0, 0.0));
        float c = bruit(i + float2(0.0, 1.0));
        float d = bruit(i + float2(1.0, 1.0));
        float k = a - b - c + d;
        return float3(a + (b - a) * u.x + (c - a) * u.y + k * u.x * u.y, du * float2(b - a + k * u.y, c - a + k * u.x));
    }
    // GLSL mat2(c0, c1) has COLUMNS c0, c1: written here as the HLSL matrix of those columns.
    float2 pente_micro(float2 p, float2 flux, float defile, float t, float pas)
    {
        float2 n = float2(-flux.y, flux.x);
        float2 q = float2(dot(p, n), dot(p, flux) - defile * 1.3);
        float2 g = float2(0.0, 0.0);
        float amp = 1.0;
        float fr = 7.0;
        float2x2 r = float2x2(1.0, 0.0, 0.0, 1.0);
        float2x2 tour = float2x2(0.80, -0.60, 0.60, 0.80);
        for (int o = 0; o < 3; o++)
        {
            float3 b = bruit_derive(mul(r, q) * fr + float2(t * 0.45 * float(o + 1), -t * 0.3));
            float efface = 1.0 - smoothstep(0.15, 0.4, pas * fr);
            g += amp * efface * fr * mul(transpose(r), b.yz);
            amp *= 0.5;
            fr *= 1.95;
            r = mul(tour, r);
        }
        return (g.x * n + g.y * flux) * 0.02;
    }
    float3 normale_eau(float2 p, float2 flux, float defile, float t, float relief, float pas, float force_micro)
    {
        float3 b = normale_vagues(p, flux, defile, t, relief);
        float2 g = pente_micro(p, flux, defile, t, pas) * force_micro;
        return normalize(float3(b.x / b.y - g.x, 1.0, b.z / b.y - g.y));
    }
    float2 hasard2(float2 p) { return frac(sin(float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)))) * 43758.5453); }
    float bord_de_cellule(float2 p, float t)
    {
        float2 i = floor(p);
        float2 f = frac(p);
        float d1 = 8.0;
        float d2 = 8.0;
        for (int y = -1; y <= 1; y++)
            for (int x = -1; x <= 1; x++)
            {
                float2 g = float2(float(x), float(y));
                float2 o = 0.5 + 0.5 * sin(t * 0.3 + 6.2831 * hasard2(i + g));
                float2 r = g + o - f;
                float d = dot(r, r);
                if (d < d1) { d2 = d1; d1 = d; }
                else if (d < d2) d2 = d;
            }
        return sqrt(d2) - sqrt(d1);
    }
    float bulle_ronde(float2 q) { return 1.0 - smoothstep(0.18, 0.32, length(frac(q) - 0.5)); }
    float3 motif_cascade(float2 uv, float t, float n_haut, float mousse)
    {
        float y = uv.y;
        float a = bruit_lisse(float2(uv.x * 4.5, (y + t * 2.2) * 0.35));
        float b = bruit_lisse(float2(uv.x * 11.0 + 7.3, (y + t * 3.1) * 0.75));
        float c = bruit_lisse(float2(uv.x * 27.0 + 1.7, (y + t * 4.3) * 1.9));
        float filets = saturate(smoothstep(0.42, 0.82, a) * 0.5 + smoothstep(0.5, 0.88, b) * 0.45 + smoothstep(0.6, 0.9, c) * 0.4);
        float lisse = smoothstep(0.45, 0.85, n_haut) * (1.0 - mousse);
        filets *= 1.0 - lisse * 0.9;
        float bouillon = bruit_lisse(float2(uv.x * 3.5 + t * 0.25, (y - t * 0.8) * 2.6)) * 0.6
            + bruit_lisse(float2(uv.x * 9.0 - t * 0.4, (y - t * 1.3) * 6.5)) * 0.4;
        float e = smoothstep(0.2, 0.7, mousse + (bouillon - 0.5) * 0.75);
        return float3(filets, e, lisse);
    }
    float3 couleur_cascade(float3 c_eau, float3 c_ecume, float3 m, float bord)
    {
        float3 base = lerp(lerp(c_eau, c_ecume, 0.32), c_eau * 1.2 + 0.05, m.z);
        base = lerp(base, c_ecume, bord * 0.35);
        return lerp(lerp(base, c_ecume, m.x * 0.9), c_ecume, m.y);
    }
    float caustique(float2 p, float t, float pied)
    {
        float2 q = p + 0.35 * float2(sin(p.y * 1.3 + t), cos(p.x * 1.1 - t * 0.9));
        float2x2 rot = float2x2(0.80, -0.60, 0.60, 0.80);
        float v = 0.0;
        float w = 0.0;
        float f = 1.0;
        for (int i = 0; i < 3; i++)
        {
            q = mul(rot, q) * 1.62;
            f *= 1.62;
            float a = 1.0 - smoothstep(0.5, 1.3, pied * f);
            v += a * sin(q.x + t * (1.0 + float(i) * 0.27)) * cos(q.y - t * (0.8 + float(i) * 0.19));
            w += a;
        }
        float crete = saturate(1.0 - abs(v / max(w, 1e-3)));
        float net = 1.0 - smoothstep(0.15, 0.40, pied * f);
        float c = pow(crete, lerp(1.5, 4.0, net)) * lerp(0.64, 1.0, net);
        return lerp(0.44, c, smoothstep(0.0, 0.6, w * 0.3333333));
    }
};
MBW W;
""" + TO_FORMAT + """
// The data of the sheet (the contract) and the frame.
float2 courant = Col.rg * 2.0 - 1.0;
float genre = Col.b;
float mousse = ColA;
float3 vn = normalize(float3(dot(R0.xyz, N), dot(R1.xyz, N), dot(R2.xyz, N)));
float3 vue = normalize(float3(dot(R0.xyz, Cam), dot(R1.xyz, Cam), dot(R2.xyz, Cam)));
// The rendered terrain behind this pixel, as a FORMAT point: along the view ray, at the scene depth.
float3 fondW = CamPos + (P - CamPos) * (SceneZ / max(PixelZ, 1e-3));
float yFond = dot(R1.xyz, fondW) + R1.w;
float prof = pf.y - yFond;
float t = T;
bool courante = genre > 0.25;
bool cascade = genre > 0.6;
bool remous = cascade && genre < 0.9;
float bord_c = 1.0 - abs(dot(vn, vue));
float2 flux = length(courant) > 0.1 ? normalize(courant) : float2(0.6, 0.8);
float pas = length(fwidth(pf.xz));
"""

# The outputs every preset writes (as the app's ALBEDO, EMISSION, ROUGHNESS, SPECULAR, NORMAL, ALPHA).
WATER_OUT = [("Emit", F3), ("Rough", F1), ("Spec", F1), ("NormalW", F3), ("Alpha", F1), ("Refract", F2)]

PRESETS = {}

PRESETS["clear"] = ("""
float3 teinte = float3(0.10, 0.42, 0.46);
float3 teinte_profonde = float3(0.02, 0.13, 0.22);
float3 ecume = float3(0.90, 0.97, 1.0);
float absorption = 0.85; float refraction = 0.035; float ampleur = 0.08; float vitesse_riviere = 1.6; float vitesse_dormante = 0.25; float micro = 0.55;
float3 m = W.motif_cascade(UV, t, vn.y, mousse);
float defile = t * (courante ? vitesse_riviere : vitesse_dormante);
float3 nw = cascade ? float3(0.0, 0.0, 1.0) : W.normale_eau(pf.xz, flux, defile, t, ampleur, pas, micro);
float p = max(prof, 0.0);
float transmis = exp(-p * absorption);
float3 eau = lerp(teinte, teinte_profonde, 1.0 - exp(-p * 0.35));
float rive = 1.0 - smoothstep(0.02, 0.12, max(prof, 0.0));
float blanc = rive * 0.7;
Refract = nw.xz * refraction * saturate(prof) * (cascade ? 0.0 : 1.0);
float3 albedo = cascade ? W.couleur_cascade(teinte, ecume, m, bord_c) : lerp(eau * (1.0 - transmis), ecume, blanc);
// The bottom seen through (Behind: the scene colour at the refracted point) is already lit: it goes in EMISSION.
Emit = cascade ? float3(0, 0, 0) : Behind * transmis * (1.0 - blanc);
Rough = cascade ? lerp(0.45, 0.1, m.z) : 0.06;
Spec = 0.55;
NormalW = cascade ? vn : nw;
Alpha = remous ? (m.y < 0.04 ? 0.0 : m.y) : 1.0;
return albedo;
""", True)

PRESETS["reflective"] = ("""
float3 teinte = float3(0.03, 0.12, 0.18);
float3 teinte_cascade = float3(0.30, 0.55, 0.70);
float3 ecume = float3(0.90, 0.97, 1.0);
float opacite_min = 0.35; float absorption = 0.9; float ampleur = 0.06; float vitesse_riviere = 1.6; float vitesse_dormante = 0.25; float micro = 0.40;
float3 m = W.motif_cascade(UV, t, vn.y, mousse);
float defile = t * (courante ? vitesse_riviere : vitesse_dormante);
float3 nw = cascade ? float3(0.0, 0.0, 1.0) : W.normale_eau(pf.xz, flux, defile, t, ampleur, pas, micro);
float3 nv = cascade ? vn : nw;
float p = max(prof, 0.0);
float fresnel = 0.02 + 0.98 * pow(1.0 - saturate(dot(nv, vue)), 5.0);
float rive = 1.0 - smoothstep(0.02, 0.12, p);
float blanc = cascade ? 1.0 : rive * 0.7;
Refract = float2(0, 0);
// The relief reflected by a screen-space march in the app: here Unreal's own reflections (sky, Lumen) do it.
Emit = float3(0, 0, 0);
Rough = cascade ? lerp(0.45, 0.1, m.z) : lerp(0.03, 0.4, blanc);
Spec = 0.8;
NormalW = nv;
Alpha = remous ? (m.y < 0.04 ? 0.0 : m.y) : (cascade ? 0.92 : saturate(max(max(opacite_min, fresnel), max(1.0 - exp(-p * absorption), blanc))));
return cascade ? W.couleur_cascade(teinte_cascade, ecume, m, bord_c) : lerp(teinte, ecume, blanc);
""", True)

PRESETS["lava"] = ("""
float3 croute = float3(0.07, 0.035, 0.03);
float3 roche_chaude = float3(0.32, 0.07, 0.02);
float3 magma = float3(1.0, 0.36, 0.06);
float incandescence = 4.0; float taille_des_plaques = 0.9; float vitesse_riviere = 0.45; float vitesse_dormante = 0.06;
float3 m = W.motif_cascade(UV, t * 0.3, vn.y, mousse);
float defile = t * (courante ? vitesse_riviere : vitesse_dormante);
float p0 = max(prof, 0.0);
float2 p = pf.xz * taille_des_plaques - flux * defile;
float bord = W.bord_de_cellule(p, t);
float fissure = 1.0 - smoothstep(0.0, 0.13, bord);
float chaleur = smoothstep(0.05, 0.6, p0) * (0.75 + 0.25 * sin(t * 1.3 + W.bruit_lisse(p * 2.0) * 6.0));
float3 albedo = lerp(croute, roche_chaude, W.bruit_lisse(p * 3.0) * 0.6);
float lueur = fissure * chaleur + 0.08 * chaleur;
float s = saturate(m.x * 0.8 + m.y);
Refract = float2(0, 0);
Emit = magma * incandescence * (cascade ? (1.0 - s * 0.7) * 0.8 : lueur);
Rough = 0.9;
Spec = 0.5;
NormalW = vn;
Alpha = remous ? (m.y < 0.04 ? 0.0 : m.y) : 1.0;
return cascade ? lerp(roche_chaude, croute, s * 0.75) : albedo;
""", True)

PRESETS["swamp"] = ("""
float3 trouble = float3(0.16, 0.19, 0.09);
float3 trouble_profond = float3(0.06, 0.08, 0.04);
float3 lentilles = float3(0.30, 0.45, 0.10);
float3 boue = float3(0.30, 0.24, 0.14);
float absorption = 3.2; float ampleur = 0.03; float vitesse_riviere = 0.8; float vitesse_dormante = 0.04; float micro = 0.25;
float3 m = W.motif_cascade(UV, t, vn.y, mousse);
float defile = t * (courante ? vitesse_riviere : vitesse_dormante);
float3 nw = cascade ? float3(0.0, 0.0, 1.0) : W.normale_eau(pf.xz, flux, defile, t, ampleur, pas, micro);
float p = max(prof, 0.0);
float transmis = exp(-p * absorption);
float3 eau = lerp(trouble, trouble_profond, 1.0 - exp(-p * 0.8));
float2 q = pf.xz * 0.9 - flux * defile;
float plaque = smoothstep(0.58, 0.68, W.bruit_lisse(q) * 0.7 + W.bruit_lisse(q * 3.1) * 0.3);
float2 cb = floor(pf.xz * 5.0);
float bulle = step(0.992, W.bruit(cb + floor(t * 0.6 + W.bruit(cb) * 10.0))) * (1.0 - plaque) * W.bulle_ronde(pf.xz * 5.0);
float3 c = lerp(eau * (1.0 - transmis), lentilles * (0.8 + 0.4 * W.bruit(floor(q * 9.0))), plaque);
c = lerp(c, float3(0.34, 0.37, 0.24), bulle);
Refract = float2(0, 0);
Emit = cascade ? float3(0, 0, 0) : Behind * transmis * (1.0 - plaque);
Rough = cascade ? 0.7 : lerp(0.15, 0.85, plaque);
Spec = 0.4;
NormalW = cascade ? vn : nw;
Alpha = remous ? (m.y < 0.04 ? 0.0 : m.y) : 1.0;
return cascade ? W.couleur_cascade(lerp(trouble, boue, 0.5) * 1.6, float3(0.62, 0.58, 0.42), m, bord_c) : c;
""", True)

PRESETS["acid"] = ("""
float3 acide = float3(0.35, 1.0, 0.12);
float3 acide_profond = float3(0.05, 0.35, 0.06);
float3 ecume = float3(0.85, 1.0, 0.35);
float luminescence = 1.6; float absorption = 1.6; float ampleur = 0.06; float vitesse_riviere = 1.4; float vitesse_dormante = 0.2; float micro = 0.45;
float3 m = W.motif_cascade(UV, t, vn.y, mousse);
float defile = t * (courante ? vitesse_riviere : vitesse_dormante);
float3 nw = cascade ? float3(0.0, 0.0, 1.0) : W.normale_eau(pf.xz, flux, defile, t, ampleur, pas, micro);
float p = max(prof, 0.0);
Refract = nw.xz * 0.02 * saturate(prof);
float transmis = exp(-p * absorption);
float3 teinte = lerp(acide, acide_profond, 1.0 - exp(-p * 0.6));
float h = W.hauteur_vagues(pf.xz, flux, defile, t);
float crete = smoothstep(0.4, 1.0, h);
float2 cb = floor(pf.xz * 6.0);
float bulle = step(0.985, W.bruit(cb + floor(t * 1.5 + W.bruit(cb) * 10.0))) * W.bulle_ronde(pf.xz * 6.0);
float rive = 1.0 - smoothstep(0.02, 0.15, p);
float blanc = cascade ? saturate(m.x * 0.45 + m.y * 0.8) : max(rive * 0.8, bulle);
Emit = lerp(teinte * luminescence * (0.55 + 0.45 * crete), ecume * luminescence * 1.3, blanc) + Behind * transmis * 0.4;
Rough = 0.1;
Spec = 0.6;
NormalW = cascade ? vn : nw;
Alpha = remous ? (m.y < 0.04 ? 0.0 : m.y) : 1.0;
return lerp(teinte * 0.3, ecume, blanc);
""", True)

PRESETS["stylized"] = ("""
float3 bleu_clair = float3(0.22, 0.53, 0.74);
float3 bleu_fonce = float3(0.06, 0.22, 0.45);
float3 bleu_frange = float3(0.34, 0.61, 0.74);
float3 couleur_ligne = float3(0.96, 0.99, 1.0);
float seuil0 = 0.15; float seuil1 = 0.72; float vitesse_riviere = 1.6; float vitesse_dormante = 0.25;
float force_caustiques = 0.6; float3 caustique_couleur = float3(0.92, 1.0, 0.96); float caustique_echelle = 1.15;
float ps = prof / 1.9;
float d_rive = abs(ps) / max(fwidth(ps), 1e-5);
float2 cp = pf.xz * caustique_echelle;
float pied = max(length(ddx(cp)), length(ddy(cp)));
float defile = t * (courante ? vitesse_riviere : vitesse_dormante);
float p = saturate(ps);
float3 c = lerp(bleu_frange, bleu_clair, smoothstep(0.0, seuil0, p));
c = lerp(c, bleu_fonce, smoothstep(seuil0 * 0.8, seuil1, p));
float reseau = W.caustique(cp, t * 0.85, pied);
float lum = smoothstep(0.30, 0.42, reseau) * 0.42 + smoothstep(0.62, 0.72, reseau) * 0.58;
c = lerp(c, caustique_couleur, lum * (1.0 - smoothstep(0.18, 0.62, p)) * force_caustiques);
float2 n = float2(-flux.y, flux.x);
float2 q = float2(dot(pf.xz, n), (dot(pf.xz, flux) - defile) * (courante ? 0.6 : 0.17));
float houle = 0.52 * (sin(q.x * 1.15 + q.y * 2.3) + 0.65 * sin(q.x * 2.10 - q.y * 1.7 + 1.3) + 0.40 * sin(q.x * 0.55 + q.y * 3.4 - 0.7));
float marche = floor(saturate(houle * 0.5 + 0.5) * 2.997) / 2.0;
float force = courante ? 0.9 : 0.35;
float ampleur = 0.10 + 0.13 * force;
float trait = smoothstep(0.86, 1.02, houle);
float furtif = step(0.40, W.bruit(float2(q.x * 0.30, floor(q.y * 0.6))));
float lignes = trait * furtif * (0.35 + 0.65 * force);
float bord_rive = (1.0 - smoothstep(0.7, 2.4, d_rive)) * (1.0 - smoothstep(0.10, 0.28, abs(prof)));
float autour = (1.0 - smoothstep(0.0, 0.16, max(prof, 0.0))) * (0.35 + 0.5 * force);
c *= 1.0 - ampleur + ampleur * 2.0 * marche;
float2 mm = float2(dot(pf.xz, n) * 6.0, (dot(pf.xz, flux) - defile * 1.3) * 14.0);
float pas_m = max(length(ddx(mm)), length(ddy(mm)));
float eclat = smoothstep(0.80, 0.93, W.bruit_lisse(mm + float2(t * 0.7, 0.0))) * (1.0 - smoothstep(0.25, 0.6, pas_m));
c = lerp(c, bleu_frange, eclat * 0.45 * (1.0 - 0.5 * p));
float encre = saturate(max(max(lignes * 0.5, 0.0), max(bord_rive * 0.85, autour)));
c = lerp(c, couleur_ligne, encre);
float3 mc = W.motif_cascade(UV, t, vn.y, mousse);
float modele = 0.78 + 0.32 * saturate(dot(vn, normalize(float3(0.45, 0.75, 0.5))));
float3 chute = lerp(lerp(bleu_fonce, bleu_clair, 0.55), bleu_clair * 1.1, mc.z) * modele;
chute = lerp(chute, bleu_frange, bord_c * 0.45);
chute = lerp(chute, couleur_ligne, mc.x * 0.85);
chute = lerp(chute, couleur_ligne, mc.y);
Refract = float2(0, 0);
Emit = cascade ? chute : c;
Rough = 1.0;
Spec = 0.0;
NormalW = vn;
Alpha = remous ? (mc.y < 0.04 ? 0.0 : mc.y) : 1.0;
return float3(0, 0, 0);
""", False)


def water(look):
    code, lit = PRESETS[look]
    g = Graph("M_MB_Water_" + look, blend_mode=unreal.BlendMode.BLEND_TRANSLUCENT, two_sided=True, tangent_space_normal=False,
              translucency_lighting_mode=unreal.TranslucencyLightingMode.TLM_SURFACE_PER_PIXEL_LIGHTING,
              instanced=False)
    if not lit:
        g.m.set_editor_property("shading_model", unreal.MaterialShadingModel.MSM_UNLIT)
    rows, back = g.rows()
    p = g.world_position(False)
    cam = g.node(unreal.MaterialExpressionCameraVectorWS)
    campos = g.node(unreal.MaterialExpressionCameraPositionWS)
    vc = g.node(unreal.MaterialExpressionVertexColor)
    common = [("P", p, ""), ("N", g.node(unreal.MaterialExpressionVertexNormalWS), ""), ("Col", vc, ""), ("ColA", vc, "A"),
              ("UV", g.node(unreal.MaterialExpressionTextureCoordinate), ""), ("T", g.node(unreal.MaterialExpressionTime), ""),
              ("Cam", cam, ""), ("CamPos", campos, ""), ("SceneZ", g.node(unreal.MaterialExpressionSceneDepth), ""),
              ("PixelZ", g.node(unreal.MaterialExpressionPixelDepth), "")] + rows
    # Pass 1: where to look behind (the refraction offset, a fraction of the screen). Pass 2: the look.
    first = g.custom(WATER_COMMON + code.replace("Behind", "float3(0, 0, 0)"), common, F3, WATER_OUT, description="refraction")
    behind = g.node(unreal.MaterialExpressionSceneColor, input_mode=unreal.MaterialSceneAttributeInputMode.OFFSET_FRACTION)
    MEL.connect_material_expressions(first, "Refract", behind, "Input")
    out = g.custom(WATER_COMMON + code, common + [("Behind", behind, "")], F3, WATER_OUT, x=-250, description="MarchingBlocks water: " + look)
    if lit:
        g.to(out, "", unreal.MaterialProperty.MP_BASE_COLOR)
        g.to(out, "Rough", unreal.MaterialProperty.MP_ROUGHNESS)
        g.to(out, "Spec", unreal.MaterialProperty.MP_SPECULAR)
        nworld = g.custom("return normalize(float3(dot(W0.xyz, Nf), dot(W1.xyz, Nf), dot(W2.xyz, Nf)));", back + [("Nf", out, "NormalW")], F3,
                          description="format normal to the world")
        g.to(nworld, "", unreal.MaterialProperty.MP_NORMAL)
    g.to(out, "Emit", unreal.MaterialProperty.MP_EMISSIVE_COLOR)
    g.to(out, "Alpha", unreal.MaterialProperty.MP_OPACITY)
    # The lapping lifts the sheet, waterfalls included, by (x, z) only: two vertices at one place move together.
    clap = {"lava": (0.015, 0.4, 0.6, 0.7), "swamp": (0.01, 0.5, 0.7, 0.9), "acid": (0.025, 0.6, 0.9, 2.1)}.get(look, (0.03, 0.55, 0.85, 1.9))
    wpo = g.custom(TO_FORMAT + "float d = %f * sin(pf.z * %f + pf.x * %f + T * %f); return float3(W0.y, W1.y, W2.y) * d;" % clap,
                   [("P", g.world_position(False), ""), ("T", g.node(unreal.MaterialExpressionTime), "")] + rows + back, F3,
                   description="lapping")
    g.to(wpo, "", unreal.MaterialProperty.MP_WORLD_POSITION_OFFSET)
    return g.done()


def main():
    if not EAL.does_directory_exist(ROOT):
        EAL.make_directory(ROOT)
    built = [animated(), transition(), wind()]
    for look in ("stylized", "clear", "reflective", "lava", "swamp", "acid"):
        built.append(water(look))
    unreal.log("MarchingBlocks: %d materials built in %s" % (len(built), ROOT))
    return built


if __name__ == "__main__":
    main()
