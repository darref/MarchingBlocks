// MarchingBlocks Paint for Unity — runs water_mesh_conformance.json against the water mesher (MBWaterMesh.cs): from GIVEN
// bodies of one water layer (the output of water_world) and the full cells of a world, the sheet as a BAG of triangles,
// compared without order (engines/PARITE.md §12): same count; every expected triangle matched to a distinct triangle of
// ours equal under one of its three rotations (never a reflection), corner by corner within the file's tolerances.
// The matching itself is proven first (shuffled, rotated, noised: equal; a corner moved, a triangle reversed, one doubled,
// colours in 8 bits: different) — a comparison never seen to fail guards nothing.
//
// No Unity dependency: compiled by the Test Runner and by the .NET conformance-runner.

using System;
using System.Collections.Generic;
using static MarchingBlocks.Paint.Tests.ParityCheck;

namespace MarchingBlocks.Paint.Tests
{
    public static class WaterMeshConformanceCheck
    {
        public const string Format = "marchingblocks-water-mesh-conformance";
        static readonly string[] Kinds = { "water_mesh" };

        /// <summary>Tolerances of a corner [px py pz nx ny nz r g b a u v] (the file's own are checked against these).</summary>
        public static double TolPosition = 1e-4, TolNormal = 1e-3, TolColor = 1e-4, TolUV = 1e-4;

        public static List<string> Run(Dictionary<string, object> conf, out int cases)
        {
            var worlds = new Dictionary<string, HashSet<Int3>>();
            if (conf.TryGetValue("worlds", out var ws))
                foreach (var kv in (Dictionary<string, object>)ws) worlds[kv.Key] = Cells(kv.Value);
            var pre = new List<string>();
            // Les tolérances et les constantes du fichier sont celles du mailleur.
            if (conf.TryGetValue("tolerances", out var tl))
            {
                var t = (Dictionary<string, object>)tl;
                if (D(t["position"]) != TolPosition || D(t["normal"]) != TolNormal || D(t["color"]) != TolColor || D(t["uv"]) != TolUV)
                    pre.Add("the file's tolerances differ from the bench's");
            }
            else pre.Add("the file has no tolerances");
            if (conf.TryGetValue("constants", out var cs))
            {
                var c = (Dictionary<string, object>)cs;
                var mine = new Dictionary<string, double>
                {
                    ["surface"] = MBWaterMesh.Surface, ["river"] = MBWaterMesh.River, ["overlap"] = MBWaterMesh.Overlap,
                    ["sheet"] = MBWaterMesh.Sheet, ["arc"] = MBWaterMesh.Arc, ["flare"] = MBWaterMesh.Flare,
                    ["flare_max"] = MBWaterMesh.FlareMax, ["into_rock"] = MBWaterMesh.IntoRock, ["rounding"] = MBWaterMesh.Rounding,
                    ["overhang"] = MBWaterMesh.Overhang, ["churn"] = MBWaterMesh.Churn, ["spray"] = MBWaterMesh.Spray,
                    ["foam_rise"] = MBWaterMesh.FoamRise, ["horizon"] = MBWaterMesh.Horizon, ["spring"] = MBWaterMesh.Spring,
                    ["spring_dome"] = MBWaterMesh.SpringDome,
                };
                foreach (var kv in c)
                    if (!mine.TryGetValue(kv.Key, out var m)) pre.Add($"unknown constant '{kv.Key}': this bench must learn it");
                    else if (Math.Abs(m - D(kv.Value)) > 1e-12) pre.Add($"constant {kv.Key}: {F(m)}, the file says {F(D(kv.Value))}");
            }
            var kinds = new HashSet<double>();
            Dictionary<string, object> basin = null;
            var failures = ParityCheck.Run(conf, Format, Kinds, (kind, i, e) =>
            {
                var cells = worlds[(string)i["world"]];
                var bodies = new List<WaterBody>();
                foreach (Dictionary<string, object> b in (List<object>)i["bodies"]) bodies.Add(BodyFromJson(b));
                var want = Unfold((Dictionary<string, object>)e);
                foreach (var t in want) kinds.Add(t[8]);
                if (want.Count > 1000) basin = (Dictionary<string, object>)e;
                var got = Triangles(MBWaterMesh.Arrays(bodies, cells));
                var why = SameBag(want, got);
                if (why == null) return null;
                return why + " — summary: " + Summary(got) + ", expected " + Summary(want);
            }, out cases, out _);
            failures.InsertRange(0, pre);
            foreach (var k in new[] { 0.0, 0.5, 0.75, 1.0 })
                if (!kinds.Contains(k)) failures.Add($"no water mesh case exercises the kind {k}");
            // LA COMPARAISON ELLE-MÊME, éprouvée sur le plus grand cas.
            if (basin == null) failures.Add("no case of more than 1000 triangles to prove the matching on");
            else failures.AddRange(ProveTheMatching(Unfold(basin)));
            return failures;
        }

        /// <summary>THE EXPORTED WORLD (DEV_TOOLS/preparer_eau_unity.gd, water_world_expected.json): the plugin's whole chain —
        /// its rule (MBWater.World, every source of every water layer at once) then its mesher, layer by layer — against
        /// the triangles MarchingBlocks computed for the sheets it baked. What the 14 cases do not exercise is there: two
        /// waterfalls of one place merged, two rivers on the same cells (one cell, one band).</summary>
        public static List<string> RunExportedWorld(Dictionary<string, object> conf, out int layers, out int triangles)
        {
            var failures = new List<string>();
            layers = 0;
            triangles = 0;
            var cells = Cells(conf["cells"]);
            var all = new List<Int3>();
            var owner = new List<int>();
            var ls = (List<object>)conf["layers"];
            for (int i = 0; i < ls.Count; i++)
                foreach (var s in (List<object>)((Dictionary<string, object>)ls[i])["sources"]) { all.Add(Vec(s)); owner.Add(i); }
            var w = MBWater.World(cells, all);
            for (int i = 0; i < ls.Count; i++)
            {
                var l = (Dictionary<string, object>)ls[i];
                var bodies = new List<WaterBody>();
                for (int k = 0; k < all.Count; k++) if (owner[k] == i) bodies.Add(w.Bodies[k]);
                var want = Unfold(l);
                var got = Triangles(MBWaterMesh.Arrays(bodies, cells, w.Box, null));
                layers++;
                triangles += want.Count;
                var why = SameBag(want, got);
                if (why != null) failures.Add($"layer {l["name"]}: {why} — summary {Summary(got)}, expected {Summary(want)}");
            }
            return failures;
        }

        /// <summary>A body of the file (English, as water_world writes it) → what the plugin's rule returns.</summary>
        public static WaterBody BodyFromJson(Dictionary<string, object> b)
        {
            var r = new WaterBody
            {
                Kind = (string)b["kind"], Error = (string)b["error"], Level = I(b["level"]), End = (string)b["end"],
                Water = Cells(b["water"]),
            };
            foreach (Dictionary<string, object> l in (List<object>)b["lakes"])
                r.Lakes.Add(new WaterLake { Level = I(l["level"]), Cells = Cells(l["cells"]) });
            foreach (List<object> s in (List<object>)b["course"])
                r.Course.Add(new WaterStep { Cell = new Int3(I(s[0]), I(s[1]), I(s[2])), Kind = (string)s[3], Lake = I(s[4]) });
            return r;
        }

        /// <summary>The expected triangles, unfolded: vertices[i] for each index, 36 numbers per triangle.</summary>
        public static List<double[]> Unfold(Dictionary<string, object> expected)
        {
            var vs = new List<double[]>();
            foreach (var v in (List<object>)expected["vertices"]) vs.Add(Doubles(v));
            var o = new List<double[]>();
            foreach (List<object> t in (List<object>)expected["triangles"])
            {
                var tri = new double[36];
                for (int k = 0; k < 3; k++) Array.Copy(vs[I(t[k])], 0, tri, 12 * k, 12);
                o.Add(tri);
            }
            return o;
        }

        /// <summary>Our arrays as triangles of 36 numbers, in the format's winding.</summary>
        public static List<double[]> Triangles(WaterSheetArrays a)
        {
            var o = new List<double[]>();
            for (int t = 0; t < a.Triangles.Count; t += 3)
            {
                var tri = new double[36];
                for (int k = 0; k < 3; k++)
                {
                    int i = a.Triangles[t + k];
                    var p = a.Positions[i];
                    var n = a.Normals[i];
                    double[] c = { p.x, p.y, p.z, n.x, n.y, n.z, a.Colors[4 * i], a.Colors[4 * i + 1], a.Colors[4 * i + 2],
                        a.Colors[4 * i + 3], a.UVs[2 * i], a.UVs[2 * i + 1] };
                    Array.Copy(c, 0, tri, 12 * k, 12);
                }
                o.Add(tri);
            }
            return o;
        }

        static bool CornerNear(double[] a, int ia, double[] b, int ib)
        {
            for (int k = 0; k < 12; k++)
            {
                double tol = k < 3 ? TolPosition : k < 6 ? TolNormal : k < 10 ? TolColor : TolUV;
                if (Math.Abs(a[ia + k] - b[ib + k]) > tol) return false;
            }
            return true;
        }

        static (long, long, long) Bucket(double[] t) => (
            (long)Math.Round((t[0] + t[12] + t[24]) / 3.0 * 100.0, MidpointRounding.AwayFromZero),
            (long)Math.Round((t[1] + t[13] + t[25]) / 3.0 * 100.0, MidpointRounding.AwayFromZero),
            (long)Math.Round((t[2] + t[14] + t[26]) / 3.0 * 100.0, MidpointRounding.AwayFromZero));

        /// <summary>THE BAG MATCHING, as rules_text asks: null when equal, else why (the triangle not found).</summary>
        public static string SameBag(List<double[]> want, List<double[]> got)
        {
            if (want.Count != got.Count) return $"{got.Count} triangles instead of {want.Count}";
            var buckets = new Dictionary<(long, long, long), List<int>>();
            for (int i = 0; i < got.Count; i++)
            {
                var k = Bucket(got[i]);
                if (!buckets.TryGetValue(k, out var l)) buckets[k] = l = new List<int>();
                l.Add(i);
            }
            var taken = new bool[got.Count];
            foreach (var t in want)
            {
                var k0 = Bucket(t);
                bool found = false;
                for (int dx = -1; dx <= 1 && !found; dx++)
                    for (int dy = -1; dy <= 1 && !found; dy++)
                        for (int dz = -1; dz <= 1 && !found; dz++)
                        {
                            if (!buckets.TryGetValue((k0.Item1 + dx, k0.Item2 + dy, k0.Item3 + dz), out var l)) continue;
                            foreach (var i in l)
                            {
                                if (taken[i]) continue;
                                var o = got[i];
                                for (int r = 0; r < 3; r++)
                                    if (CornerNear(t, 0, o, 12 * r) && CornerNear(t, 12, o, 12 * ((r + 1) % 3))
                                        && CornerNear(t, 24, o, 12 * ((r + 2) % 3)))
                                    {
                                        found = true;
                                        taken[i] = true;
                                        break;
                                    }
                                if (found) break;
                            }
                        }
                if (!found)
                    return $"no triangle for ({F(t[0])}, {F(t[1])}, {F(t[2])}) ({F(t[12])}, {F(t[13])}, {F(t[14])}) " +
                        $"({F(t[24])}, {F(t[25])}, {F(t[26])}) kind {F(t[8])}";
            }
            return null;
        }

        /// <summary>Count and area per kind (b of the first corner): a diagnosis, not the comparison.</summary>
        public static string Summary(List<double[]> tris)
        {
            var count = new SortedDictionary<double, int>();
            var area = new SortedDictionary<double, double>();
            foreach (var t in tris)
            {
                double ax = t[12] - t[0], ay = t[13] - t[1], az = t[14] - t[2], bx = t[24] - t[0], by = t[25] - t[1], bz = t[26] - t[2];
                double x = ay * bz - az * by, y = az * bx - ax * bz, z = ax * by - ay * bx;
                count[t[8]] = (count.TryGetValue(t[8], out var c) ? c : 0) + 1;
                area[t[8]] = (area.TryGetValue(t[8], out var s) ? s : 0) + 0.5 * Math.Sqrt(x * x + y * y + z * z);
            }
            var parts = new List<string>();
            foreach (var kv in count) parts.Add($"kind {kv.Key}: {kv.Value} triangles, area {area[kv.Key]:F3}");
            return "{" + string.Join("; ", parts) + "}";
        }

        /// <summary>The matching proven on a real case: shuffled, rotated, noised under the tolerance — the same; a corner
        /// moved by 2e-4, a triangle reversed, a triangle doubled in place of another, colours in 8 bits — different.</summary>
        public static List<string> ProveTheMatching(List<double[]> basin)
        {
            var f = new List<string>();
            var rnd = new Random(7);
            var mixed = new List<double[]>();
            foreach (var t in basin)
            {
                int r = rnd.Next(3);
                var turned = new double[36];
                for (int k = 0; k < 36; k++) turned[k] = t[(k + 12 * r) % 36];
                for (int k = 0; k < 36; k++)
                {
                    double amplitude = k % 12 >= 3 && k % 12 < 6 ? 5e-4 : 5e-5;
                    turned[k] += rnd.Next(2) == 0 ? amplitude : -amplitude;
                }
                mixed.Insert(rnd.Next(mixed.Count + 1), turned);
            }
            var why = SameBag(basin, mixed);
            if (why != null) f.Add("the matching: shuffled, rotated, noised under the tolerance must be the same — " + why);
            var moved = Copy(basin);
            moved[500][13] += 2e-4;
            if (SameBag(basin, moved) == null) f.Add("the matching: a corner moved by 2e-4 must differ");
            var reversed = Copy(basin);
            var rt = reversed[300];
            var tmp = new double[12];
            Array.Copy(rt, 12, tmp, 0, 12);
            Array.Copy(rt, 24, rt, 12, 12);
            Array.Copy(tmp, 0, rt, 24, 12);
            if (SameBag(basin, reversed) == null) f.Add("the matching: a reversed triangle must differ (the winding is the contract)");
            var doubled = Copy(basin);
            doubled[10] = (double[])doubled[11].Clone();
            if (SameBag(basin, doubled) == null) f.Add("the matching: a triangle doubled in place of another must differ");
            var eight = Copy(basin);
            foreach (var t in eight)
                for (int k = 0; k < 3; k++)
                    for (int j = 6; j < 10; j++) t[12 * k + j] = Math.Round(t[12 * k + j] * 255.0) / 255.0;
            if (SameBag(basin, eight) == null) f.Add("the matching: colours in 8 bits must differ");
            return f;
        }

        static List<double[]> Copy(List<double[]> l)
        {
            var o = new List<double[]>(l.Count);
            foreach (var t in l) o.Add((double[])t.Clone());
            return o;
        }
    }
}
