// MarchingBlocks Paint for Unity — TRANSITIONS BETWEEN LAYERS: the rule, the reader, and the cell texture.
//
// world.json may carry `transitions` (optional): how two tile layers BLEND where they meet. The geometry never changes
// (the tiles are the ones the tileset rule places); only the LOOK of the surface does: where the rule says so, the OTHER
// layer's representative (an image projected in a box, times a colour) is drawn over the surface, with an alpha.
//
// This file has no Unity dependency: Tests/transitions_conformance.json (computed by the MarchingBlocks tool itself) is
// run against it outside Unity too (conformance-runner). Its rules_text says every rule in full. The shader
// (Shaders/MarchingBlocksTransition.shader) follows Blend line by line, on the GPU.

using System;
using System.Collections.Generic;

namespace MarchingBlocks.Paint
{
    /// <summary>How one layer covers another (one DIRECTION of a pair).</summary>
    public struct TransitionSettings
    {
        /// <summary>The width of the blend: 0.05 a sharp border, 1 a gradient over the whole band.</summary>
        public double Softness;
        /// <summary>How far the covering layer goes past the middle, in [-0.5, 0.5] (negative: it recedes).</summary>
        public double Reach;
        /// <summary>How irregular the border is, in [0, 1].</summary>
        public double Irregularity;
        /// <summary>The size of that noise (per cell), in [0.25, 6].</summary>
        public double Grain;
        /// <summary>The covering layer fills the HOLLOWS (dark parts of the covered representative) first, in [0, 1].</summary>
        public double FillsHollows;

        public static readonly TransitionSettings Default = new TransitionSettings
        { Softness = 0.45, Reach = 0.2, Irregularity = 0.35, Grain = 1.5, FillsHollows = 0.5 };

        public static readonly string[] Names = { "softness", "reach", "irregularity", "grain", "fills_hollows" };
        static readonly double[] Low = { 0.05, -0.5, 0.0, 0.25, 0.0 };
        static readonly double[] High = { 1.0, 0.5, 1.0, 6.0, 1.0 };

        public double this[int k]
        {
            get => k == 0 ? Softness : k == 1 ? Reach : k == 2 ? Irregularity : k == 3 ? Grain : FillsHollows;
            set
            {
                if (k == 0) Softness = value; else if (k == 1) Reach = value; else if (k == 2) Irregularity = value;
                else if (k == 3) Grain = value; else FillsHollows = value;
            }
        }

        /// <summary>Settings read under their names: a missing one takes its default, one out of range is clamped. A
        /// value that is not a number is a missing one here (the world reader refuses it before).</summary>
        public static TransitionSettings From(object decoded)
        {
            var s = Default;
            var d = decoded as Dictionary<string, object>;
            for (int k = 0; k < Names.Length; k++)
            {
                double v = s[k];
                if (d != null && d.TryGetValue(Names[k], out var x) && (x is long || x is double)) v = MBJson.AsDouble(x);
                s[k] = Math.Min(High[k], Math.Max(Low[k], v));
            }
            return s;
        }

        public Dictionary<string, object> ToJson()
        {
            var o = new Dictionary<string, object>();
            for (int k = 0; k < Names.Length; k++) o[Names[k]] = this[k];
            return o;
        }
    }

    public sealed class TransitionPair
    {
        /// <summary>Layer indices (in world.json's layers), A &lt; B.</summary>
        public int A, B;
        public bool Active;
        public TransitionSettings ACoversB, BCoversA;
    }

    public sealed class TransitionRepresentative
    {
        /// <summary>A PNG path RELATIVE to world.json, or null (plain colour).</summary>
        public string Image;
        /// <summary>Multiplies the image AS IS (no sRGB conversion of the colour).</summary>
        public double[] Color = { 1, 1, 1, 1 };
        /// <summary>World cells per repeat of the image (at least 0.01).</summary>
        public double Scale = 1;
        public double Roughness = 1;
    }

    public sealed class TransitionsResult
    {
        /// <summary>"" when read; otherwise why the file is refused.</summary>
        public string Error = "";
        public bool Ok => Error == "";
        public List<TransitionPair> Pairs = new List<TransitionPair>();
        /// <summary>One per layer, in layer order (empty when the world has no transitions).</summary>
        public List<TransitionRepresentative> Representatives = new List<TransitionRepresentative>();
        /// <summary>At a vertex (FORMAT space), the layer that covers — sorted by vertex (x, then y, then z).</summary>
        public List<KeyValuePair<Int3, int>> Choices = new List<KeyValuePair<Int3, int>>();
    }

    /// <summary>What the blend gives at a point: nothing (Drawn false), or the owner, the other layer, s (the other's
    /// share), the vote for "the other covers", and the alpha with which the OTHER layer's representative is drawn.</summary>
    public struct BlendResult
    {
        public bool Drawn;
        public int Owner, Other;
        public double S, Vote, Alpha;
    }

    public static class MBTransitions
    {
        /// <summary>Layers 0 to 254 blend: a rank and a choice each fit in a byte of their own (two bytes per cell).</summary>
        public const int LayersMax = 255;
        /// <summary>The cell texture is the box of the cells grown by this margin.</summary>
        public const int Margin = 6;

        // ---- the rule ----

        /// <summary>The trilinear weight of corner k = dx + 2 dy + 4 dz at f in [0, 1]^3.</summary>
        public static double Weight(int k, double fx, double fy, double fz) =>
            ((k & 1) != 0 ? fx : 1.0 - fx) * ((k & 2) != 0 ? fy : 1.0 - fy) * ((k & 4) != 0 ? fz : 1.0 - fz);

        /// <summary>THE BLEND at a point of the tile of vertex v. <paramref name="ranks"/>: the layer index of the eight
        /// cells v + d (k = dx + 2 dy + 4 dz; −1 empty); f = clamp(p − v − 1/2, 0, 1); <paramref name="choices"/>: the
        /// layer chosen at the eight VERTICES v + d (−1 none); <paramref name="table"/>(C, D): the settings when C covers
        /// D, or null when that direction is not active; <paramref name="luminance"/>(L): the luminance of layer L's
        /// representative at the point; n: the noise in [0, 1].</summary>
        public static BlendResult Blend(int[] ranks, double fx, double fy, double fz, int[] choices,
            Func<int, int, TransitionSettings?> table, Func<int, double> luminance, double n)
        {
            var none = new BlendResult();
            int owner = int.MaxValue;
            foreach (var r in ranks) if (r >= 0 && r < owner) owner = r;
            if (owner == int.MaxValue) return none;
            double wOwner = 0;
            var parts = new Dictionary<int, double>();
            for (int k = 0; k < 8; k++)
            {
                int r = ranks[k];
                if (r < 0) continue;
                double w = Weight(k, fx, fy, fz);
                if (r == owner) wOwner += w;
                else parts[r] = (parts.TryGetValue(r, out var p) ? p : 0.0) + w;
            }
            // The tie goes to the first corner in k order: the first STRICTLY larger part wins.
            int other = -1;
            double best = 0;
            for (int k = 0; k < 8; k++)
            {
                int r = ranks[k];
                if (r >= 0 && r != owner && parts[r] > best) { best = parts[r]; other = r; }
            }
            if (other < 0) return none;
            var otherCovers = table(other, owner);
            var ownerCovers = table(owner, other);
            if (otherCovers == null || ownerCovers == null) return none;
            double s = best / (best + wOwner);
            int priority = Math.Min(owner, other);
            double vote = 0;
            for (int k = 0; k < 8; k++)
            {
                int c = choices != null && k < choices.Length ? choices[k] : -1;
                int covering = c == owner || c == other ? c : priority;
                if (covering == other) vote += Weight(k, fx, fy, fz);
            }
            double aOther = Visible(otherCovers.Value, s, luminance(owner), n);
            double aOwner = 1.0 - Visible(ownerCovers.Value, 1.0 - s, luminance(other), n);
            return new BlendResult
            {
                Drawn = true, Owner = owner, Other = other, S = s, Vote = vote,
                Alpha = vote * aOther + (1.0 - vote) * aOwner,
            };
        }

        /// <summary>How much of the covering layer shows, its share of the cells being x and h the covered layer's
        /// luminance: smoothstep around 0.5 of x shifted by (reach + fills_hollows (0.5 − h) + irregularity (n − 0.5))
        /// 4 x (1 − x) — the shift is ZERO at both ends.</summary>
        public static double Visible(TransitionSettings g, double x, double h, double n)
        {
            double shift = (g.Reach + g.FillsHollows * (0.5 - h) + g.Irregularity * (n - 0.5)) * 4.0 * x * (1.0 - x);
            return SmoothStep(0.5 - g.Softness * 0.5, 0.5 + g.Softness * 0.5, x + shift);
        }

        public static double SmoothStep(double e0, double e1, double x)
        {
            double t = Math.Min(1.0, Math.Max(0.0, (x - e0) / (e1 - e0)));
            return t * t * (3.0 - 2.0 * t);
        }

        /// <summary>The ACTIVE directions of the pairs: (C, D) → the settings when C covers D. A pair with a layer
        /// beyond the 255th blends nothing.</summary>
        public static Dictionary<(int, int), TransitionSettings> Table(IEnumerable<TransitionPair> pairs)
        {
            var t = new Dictionary<(int, int), TransitionSettings>();
            foreach (var p in pairs)
            {
                if (!p.Active || p.A >= LayersMax || p.B >= LayersMax || p.A < 0 || p.B < 0) continue;
                t[(p.A, p.B)] = p.ACoversB;
                t[(p.B, p.A)] = p.BCoversA;
            }
            return t;
        }

        // ---- the cell texture (the RECOMMENDED packing) ----

        /// <summary>TWO bytes per cell (an RG texture) over the box of the cells grown by 6: R = rank + 1 (0 empty, or a
        /// layer ≥ 255), G = the rank chosen at that vertex + 1 (0 none); a choice outside the box is dropped. Texel
        /// (x, y, z) = cell − origin; index i = (z · size.y + y) · size.x + x, its bytes 2 i (R) and 2 i + 1 (G). No
        /// cell: origin 0, size 1.</summary>
        public static byte[] CellTexture(IEnumerable<KeyValuePair<Int3, int>> cells, IEnumerable<KeyValuePair<Int3, int>> choices,
            out Int3 origin, out Int3 size)
        {
            bool any = false;
            Int3 lo = default, hi = default;
            foreach (var kv in cells)
            {
                var c = kv.Key;
                if (!any) { lo = hi = c; any = true; continue; }
                lo = new Int3(Math.Min(lo.x, c.x), Math.Min(lo.y, c.y), Math.Min(lo.z, c.z));
                hi = new Int3(Math.Max(hi.x, c.x), Math.Max(hi.y, c.y), Math.Max(hi.z, c.z));
            }
            if (!any)
            {
                origin = default;
                size = new Int3(1, 1, 1);
                return new byte[2];
            }
            origin = new Int3(lo.x - Margin, lo.y - Margin, lo.z - Margin);
            size = new Int3(hi.x - lo.x + 2 * Margin + 1, hi.y - lo.y + 2 * Margin + 1, hi.z - lo.z + 2 * Margin + 1);
            var bytes = new byte[2L * size.x * size.y * size.z];
            foreach (var kv in cells)
            {
                long i = Index(origin, size, kv.Key);
                bytes[2 * i] = Byte(kv.Value);
            }
            foreach (var kv in choices)
            {
                long i = Index(origin, size, kv.Key);
                if (i >= 0) bytes[2 * i + 1] = Byte(kv.Value);
            }
            return bytes;
        }

        /// <summary>The index of a cell in the texture, or −1 outside its box.</summary>
        public static long Index(Int3 origin, Int3 size, Int3 c)
        {
            int x = c.x - origin.x, y = c.y - origin.y, z = c.z - origin.z;
            if (x < 0 || y < 0 || z < 0 || x >= size.x || y >= size.y || z >= size.z) return -1;
            return ((long)z * size.y + y) * size.x + x;
        }

        static byte Byte(int rank) => (byte)(rank >= 0 && rank < LayersMax ? rank + 1 : 0);

        // ---- reading world.json ----

        /// <summary>Reads the `transitions` key of a world.json decoded by MBJson. Absent: nothing blends (every list
        /// empty). Settings are completed and clamped, a representative's scale is at least 0.01 and its roughness in
        /// [0, 1], the choices sorted by vertex. Refused, with the reason, if the file breaks the rule.</summary>
        public static TransitionsResult Read(object decodedWorld)
        {
            var r = new TransitionsResult();
            if (!(decodedWorld is Dictionary<string, object> world)) return Refuse("not a MarchingBlocks world");
            int layers = world.TryGetValue("layers", out var lo) && lo is List<object> ll ? ll.Count : 0;
            if (!world.TryGetValue("transitions", out var to) || to == null) return r;
            if (!(to is Dictionary<string, object> t)) return Refuse("transitions is not an object");
            object po = t.TryGetValue("pairs", out var pv) ? pv : new List<object>();
            if (!(po is List<object> pairs)) return Refuse("transitions: pairs is not an array");
            var seen = new HashSet<(int, int)>();
            foreach (var item in pairs)
            {
                if (!(item is Dictionary<string, object> p) || !p.TryGetValue("a", out var ao) || !IsInteger(ao, out long a)
                    || !p.TryGetValue("b", out var bo) || !IsInteger(bo, out long b)
                    || !p.TryGetValue("active", out var ac) || !(ac is bool active))
                    return Refuse("transitions: a pair has no layers a, b or no active");
                if (a < 0 || b >= layers || a >= b) return Refuse($"transitions: the pair {a}, {b} is not two layers a < b");
                if (!seen.Add(((int)a, (int)b))) return Refuse($"transitions: the pair {a}, {b} appears twice");
                var dirs = new TransitionSettings[2];
                string[] keys = { "a_covers_b", "b_covers_a" };
                for (int k = 0; k < 2; k++)
                {
                    if (!p.TryGetValue(keys[k], out var so) || !(so is Dictionary<string, object> s))
                        return Refuse($"transitions: the pair {a}, {b} has no {keys[k]}");
                    foreach (var kv in s)
                        if (!(kv.Value is long || kv.Value is double))
                            return Refuse($"transitions: the setting {kv.Key} of the pair {a}, {b} is not a number");
                    dirs[k] = TransitionSettings.From(s);
                }
                r.Pairs.Add(new TransitionPair { A = (int)a, B = (int)b, Active = active, ACoversB = dirs[0], BCoversA = dirs[1] });
            }
            if (!t.TryGetValue("representatives", out var ro) || !(ro is List<object> reps) || reps.Count != layers)
                return Refuse("transitions: representatives is not one per layer");
            foreach (var item in reps)
            {
                if (!(item is Dictionary<string, object> rep) || (rep.TryGetValue("image", out var im) && im != null && !(im is string)))
                    return Refuse("transitions: a representative's image is neither a path nor null");
                if (!rep.TryGetValue("color", out var co) || !(co is List<object> color) || color.Count != 4
                    || !color.TrueForAll(x => x is long || x is double))
                    return Refuse("transitions: a representative's color is not four numbers");
                if (!rep.TryGetValue("scale", out var sc) || !(sc is long || sc is double)
                    || !rep.TryGetValue("roughness", out var ru) || !(ru is long || ru is double))
                    return Refuse("transitions: a representative's scale or roughness is not a number");
                r.Representatives.Add(new TransitionRepresentative
                {
                    Image = im as string,
                    Color = new[] { MBJson.AsDouble(color[0]), MBJson.AsDouble(color[1]), MBJson.AsDouble(color[2]), MBJson.AsDouble(color[3]) },
                    Scale = Math.Max(MBJson.AsDouble(sc), 0.01),
                    Roughness = Math.Min(1.0, Math.Max(0.0, MBJson.AsDouble(ru))),
                });
            }
            object fo = t.TryGetValue("choices", out var fv) ? fv : new List<object>();
            if (!(fo is List<object> flat) || flat.Count % 4 != 0) return Refuse("transitions: choices is not a list of x y z L");
            var chosen = new HashSet<Int3>();
            for (int i = 0; i < flat.Count; i += 4)
            {
                var v = new long[4];
                for (int k = 0; k < 4; k++)
                    if (!IsInteger(flat[i + k], out v[k]) || v[k] < int.MinValue || v[k] > int.MaxValue)
                        return Refuse("transitions: a choice is not made of integers");
                var s = new Int3((int)v[0], (int)v[1], (int)v[2]);
                if (!chosen.Add(s)) return Refuse($"transitions: the vertex {s} is chosen twice");
                if (v[3] < 0 || v[3] >= layers) return Refuse($"transitions: a choice names layer {v[3]}, which does not exist");
                r.Choices.Add(new KeyValuePair<Int3, int>(s, (int)v[3]));
            }
            r.Choices.Sort((x, y) => MBTools.Compare(x.Key, y.Key));
            return r;
        }

        static TransitionsResult Refuse(string why) => new TransitionsResult { Error = why };

        static bool IsInteger(object v, out long value)
        {
            value = 0;
            if (v is long l) { value = l; return true; }
            if (v is double d && !double.IsNaN(d) && !double.IsInfinity(d) && Math.Floor(d) == d
                && d >= long.MinValue && d <= long.MaxValue) { value = (long)d; return true; }
            return false;
        }
    }
}
