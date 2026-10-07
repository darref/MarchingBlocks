// MarchingBlocks Paint for Unity — runs water_conformance.json against the water rule (MBWater.cs): the water of a
// world (water_world), the width of a river at placement (river_width), the surface and the depth (surface_depth), and
// the reading of the "water" key of world.json (read). The answers come from the MarchingBlocks tool itself (fluides.gd).
//
// No Unity dependency: compiled by the Test Runner and by the .NET conformance-runner.

using System.Collections.Generic;
using static MarchingBlocks.Paint.Tests.ParityCheck;

namespace MarchingBlocks.Paint.Tests
{
    public static class WaterConformanceCheck
    {
        public const string Format = "marchingblocks-water-conformance";
        static readonly string[] Kinds = { "water_world", "river_width", "surface_depth", "read" };

        public static List<string> Run(Dictionary<string, object> conf, out int cases)
        {
            var worlds = new Dictionary<string, HashSet<Int3>>();
            if (conf.TryGetValue("worlds", out var ws))
                foreach (var kv in (Dictionary<string, object>)ws) worlds[kv.Key] = Cells(kv.Value);
            // Ce que les attendus exercent, lu du côté ATTENDU, jamais du nôtre.
            var seen = new HashSet<string>();
            int refusedReads = 0, goodReads = 0;
            var failures = ParityCheck.Run(conf, Format, Kinds, (kind, i, e) =>
            {
                switch (kind)
                {
                    case "water_world":
                    {
                        var sources = new List<Int3>();
                        foreach (var p in (List<object>)i["sources"]) sources.Add(Vec(p));
                        var got = MBWater.World(worlds[(string)i["world"]], sources);
                        var ex = (Dictionary<string, object>)e;
                        var bodies = (List<object>)ex["bodies"];
                        if (bodies.Count != got.Bodies.Count) return $"{got.Bodies.Count} bodies, expected {bodies.Count}";
                        for (int k = 0; k < bodies.Count; k++)
                        {
                            var eb = (Dictionary<string, object>)bodies[k];
                            seen.Add("kind " + eb["kind"]);
                            seen.Add("end " + eb["end"]);
                            seen.Add("error " + eb["error"]);
                            var why = SameBody($"body {k}", got.Bodies[k], eb);
                            if (why != null) return why;
                        }
                        return SameCells("sea", got.Sea, ex["sea"]);
                    }
                    case "river_width":
                    {
                        var got = MBWater.RiverWidth(worlds[(string)i["world"]], Vec(i["source"]), I(i["width"]));
                        var want = (List<object>)e;
                        if (got.Count != want.Count) return $"{got.Count} sources, expected {want.Count}";
                        // Dans l'ordre : s d'abord, puis les voisines de − à +.
                        for (int k = 0; k < want.Count; k++)
                            if (!got[k].Equals(Vec(want[k]))) return $"source {k} is {got[k]}, expected {Vec(want[k])}";
                        return null;
                    }
                    case "surface_depth":
                    {
                        var cells = worlds[(string)i["world"]];
                        var water = Cells(i["water"]);
                        var ex = (Dictionary<string, object>)e;
                        var why = SameCells("surface", MBWater.Surface(water, cells), ex["surface"]);
                        if (why != null) return why;
                        var depth = (List<object>)ex["depth"];
                        var asked = (List<object>)i["cells"];
                        if (depth.Count != asked.Count) return "depth: not one per cell";
                        for (int k = 0; k < asked.Count; k++)
                        {
                            var d = (List<object>)depth[k];
                            int got = MBWater.Depth(water, cells, Vec(asked[k]));
                            if (got == -1) seen.Add("depth -1");
                            if (got != I(d[3])) return $"depth at {Vec(asked[k])}: {got}, expected {d[3]}";
                        }
                        return null;
                    }
                    case "read":
                    {
                        var got = MBWater.Read(i);
                        if (e is Dictionary<string, object> ed && ed.ContainsKey("error"))
                        {
                            refusedReads++;
                            return got.Ok ? "must be REFUSED, was read" : null;
                        }
                        goodReads++;
                        if (!got.Ok) return "refused: " + got.Error;
                        var asJson = new List<object>();
                        foreach (var l in got.Layers)
                        {
                            var sources = new List<object>();
                            foreach (var s in l.Sources) sources.Add(new List<object> { (long)s.x, (long)s.y, (long)s.z });
                            asJson.Add(new Dictionary<string, object>
                            {
                                ["name"] = l.Name, ["visible"] = l.Visible, ["look"] = l.Look, ["mesh"] = l.Mesh, ["sources"] = sources,
                            });
                        }
                        return SameJson("water", asJson, e);
                    }
                }
                return "unreachable";
            }, out cases, out _);

            if (conf.TryGetValue("limits", out var lm))
            {
                var limits = (Dictionary<string, object>)lm;
                if (MBJson.AsLong(limits["volume_max"]) != MBWater.VolumeMax || MBJson.AsLong(limits["steps_max"]) != MBWater.StepsMax
                    || MBJson.AsLong(limits["overflow_reach"]) != MBWater.OverflowReach)
                    failures.Add("the water limits differ from the plugin's");
            }
            // LES CAS EXERCENT CE QU'ILS NOMMENT.
            foreach (var need in new[] { "kind sea", "kind lake", "kind river", "end leaves", "end joins", "end closed",
                "error in_matter", "error in_water", "error one_sea_only", "depth -1" })
                if (!seen.Contains(need)) failures.Add($"no water case exercises '{need}'");
            if (goodReads < 2 || refusedReads < 5)
                failures.Add($"the read cases hold {goodReads} good world(s) and {refusedReads} refusal(s): at least 2 and 5 are needed");
            return failures;
        }

        static string SameBody(string where, WaterBody g, Dictionary<string, object> e)
        {
            if (g.Kind != (string)e["kind"]) return $"{where}: kind '{g.Kind}', expected '{e["kind"]}'";
            if (g.Error != (string)e["error"]) return $"{where}: error '{g.Error}', expected '{e["error"]}'";
            if (g.End != (string)e["end"]) return $"{where}: end '{g.End}', expected '{e["end"]}'";
            if (g.Level != I(e["level"])) return $"{where}: level {g.Level}, expected {e["level"]}";
            var why = SameCells($"{where} water", g.Water, e["water"]);
            if (why != null) return why;
            var lakes = (List<object>)e["lakes"];
            if (lakes.Count != g.Lakes.Count) return $"{where}: {g.Lakes.Count} lakes, expected {lakes.Count}";
            for (int k = 0; k < lakes.Count; k++)
            {
                var el = (Dictionary<string, object>)lakes[k];
                if (g.Lakes[k].Level != I(el["level"])) return $"{where} lake {k}: level {g.Lakes[k].Level}, expected {el["level"]}";
                why = SameCells($"{where} lake {k}", g.Lakes[k].Cells, el["cells"]);
                if (why != null) return why;
            }
            var course = (List<object>)e["course"];
            if (course.Count != g.Course.Count) return $"{where}: {g.Course.Count} steps, expected {course.Count}";
            for (int k = 0; k < course.Count; k++)
            {
                var s = (List<object>)course[k];
                var gs = g.Course[k];
                var cell = new Int3(I(s[0]), I(s[1]), I(s[2]));
                if (!gs.Cell.Equals(cell) || gs.Kind != (string)s[3] || gs.Lake != I(s[4]))
                    return $"{where} step {k}: {gs.Cell} {gs.Kind} {gs.Lake}, expected {cell} {s[3]} {s[4]}";
            }
            return null;
        }
    }
}
