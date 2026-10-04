// MarchingBlocks Paint for Unity — runs the VARIANT cases of conformance.json (the tileset rule's step 8:
// variants placed by a weighted draw on a hash of the vertex, or by a choice) against Rule.Placements.
//
// No Unity dependency: the same file is compiled by the Test Runner (ConformanceTests.cs) and by the .NET
// conformance-runner outside Unity. Returns one line per failure, empty when all pass. The expected lists
// come from the MarchingBlocks tool's own reference.

using System.Collections.Generic;

namespace MarchingBlocks.Paint.Tests
{
    public static class VariantConformanceCheck
    {
        public static List<string> Run(Dictionary<string, object> conf, out int cases, out int placements)
        {
            var failures = new List<string>();
            cases = 0;
            placements = 0;
            if (!conf.TryGetValue("variant_cases", out var vc) || !conf.TryGetValue("tileset_variants", out var tv))
            {
                failures.Add("conformance.json has no variant cases");
                return failures;
            }
            var tilesets = (Dictionary<string, object>)conf["tilesets"];
            var variants = (Dictionary<string, object>)tv;
            int inVariant = 0, differWithout = 0;
            foreach (Dictionary<string, object> c in (List<object>)vc)
            {
                cases++;
                string name = (string)c["tileset"];
                var rule = new Rule(conf, (Dictionary<string, object>)tilesets[name], (Dictionary<string, object>)variants[name]);
                var cells = Cells((List<object>)c["cells"]);
                var settings = Settings(c);
                var got = rule.Placements(cells, settings);
                var expected = (List<object>)c["expected"];
                placements += expected.Count;
                string first = Compare(expected, got);
                if (first != null) failures.Add($"{c["name"]} — {first}");
                foreach (List<object> e in expected)
                    if (e[3] is string s && s.Contains("_var")) inVariant++;
                // Without step 8 the case must place something else — otherwise it would guard nothing.
                if (Compare(expected, new Rule(conf, (Dictionary<string, object>)tilesets[name]).Placements(cells)) != null)
                    differWithout++;
            }
            if (inVariant == 0 || inVariant >= placements) failures.Add("the variant cases must place variants AND base tiles");
            if (differWithout != cases) failures.Add($"only {differWithout} of {cases} variant cases need step 8");
            return failures;
        }

        /// <summary>A case's or a layer's variant_weights and variant_choices (x y z c, flat).</summary>
        public static VariantSettings Settings(Dictionary<string, object> c)
        {
            var s = new VariantSettings();
            if (c.TryGetValue("variant_weights", out var w))
                foreach (var kv in (Dictionary<string, object>)w)
                {
                    var list = (List<object>)kv.Value;
                    var ints = new int[list.Count];
                    for (int k = 0; k < list.Count; k++) ints[k] = (int)MBJson.AsLong(list[k]);
                    s.Weights[kv.Key] = ints;
                }
            if (c.TryGetValue("variant_choices", out var ch))
            {
                var flat = (List<object>)ch;
                for (int i = 0; i < flat.Count; i += 4)
                    s.Choices[new Int3((int)MBJson.AsLong(flat[i]), (int)MBJson.AsLong(flat[i + 1]), (int)MBJson.AsLong(flat[i + 2]))]
                        = (int)MBJson.AsLong(flat[i + 3]);
            }
            return s;
        }

        static HashSet<Int3> Cells(List<object> list)
        {
            var set = new HashSet<Int3>();
            foreach (List<object> p in list)
                set.Add(new Int3((int)MBJson.AsLong(p[0]), (int)MBJson.AsLong(p[1]), (int)MBJson.AsLong(p[2])));
            return set;
        }

        static string Compare(List<object> expected, List<Placement> got)
        {
            for (int i = 0; i < System.Math.Max(expected.Count, got.Count); i++)
            {
                string e = i < expected.Count ? Show((List<object>)expected[i]) : "nothing";
                string g = i < got.Count ? Show(got[i]) : "nothing";
                if (e != g) return $"at {i}: expected {e}, got {g}";
            }
            return null;
        }

        static string Show(List<object> e) =>
            $"[{MBJson.AsLong(e[0])},{MBJson.AsLong(e[1])},{MBJson.AsLong(e[2])},{(e[3] == null ? "null" : (string)e[3])},{MBJson.AsLong(e[4])}]";

        static string Show(Placement p) =>
            $"[{p.Vertex.x},{p.Vertex.y},{p.Vertex.z},{p.Tile ?? "null"},{p.QuarterTurns}]";
    }
}
