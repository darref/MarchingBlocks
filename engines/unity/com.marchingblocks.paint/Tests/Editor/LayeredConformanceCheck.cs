// MarchingBlocks Paint for Unity — runs the LAYERED cases of conformance.json (worlds of several layers, the
// tileset rule's step 7) against Rule.PlacementsLayered.
//
// No Unity dependency: the same file is compiled by the Test Runner (ConformanceTests.cs) and by the .NET
// conformance-runner outside Unity. Returns one line per failure, empty when all pass. The expected lists
// come from the MarchingBlocks tool's own reference.

using System.Collections.Generic;

namespace MarchingBlocks.Paint.Tests
{
    public static class LayeredConformanceCheck
    {
        public static List<string> Run(Dictionary<string, object> conf, out int cases, out int placements)
        {
            var failures = new List<string>();
            cases = 0;
            placements = 0;
            if (!conf.TryGetValue("layered_cases", out var lc))
            {
                failures.Add("conformance.json has no layered cases");
                return failures;
            }
            var tilesets = (Dictionary<string, object>)conf["tilesets"];
            int differAlone = 0;
            bool hiddenEmpty = false;
            foreach (Dictionary<string, object> c in (List<object>)lc)
            {
                cases++;
                var layers = (List<object>)c["layers"];
                var cells = new List<HashSet<Int3>>();
                var visible = new List<bool>();
                var rules = new List<Rule>();
                var settings = new List<VariantSettings>();
                var tilesetVariants = conf.TryGetValue("tileset_variants", out var tv) ? (Dictionary<string, object>)tv : null;
                foreach (Dictionary<string, object> l in layers)
                {
                    var set = new HashSet<Int3>();
                    foreach (List<object> p in (List<object>)l["cells"])
                        set.Add(new Int3((int)MBJson.AsLong(p[0]), (int)MBJson.AsLong(p[1]), (int)MBJson.AsLong(p[2])));
                    cells.Add(set);
                    visible.Add((bool)l["visible"]);
                    string ts = (string)l["tileset"];
                    rules.Add(new Rule(conf, (Dictionary<string, object>)tilesets[ts],
                        tilesetVariants != null && tilesetVariants.TryGetValue(ts, out var vs) ? (Dictionary<string, object>)vs : null));
                    settings.Add(VariantConformanceCheck.Settings(l));
                }
                var got = Rule.PlacementsLayered(cells, visible, rules, settings);
                var expected = (List<object>)c["expected"];
                for (int i = 0; i < layers.Count; i++)
                {
                    var e = (List<object>)expected[i];
                    placements += e.Count;
                    string first = null;
                    for (int k = 0; k < System.Math.Max(e.Count, got[i].Count) && first == null; k++)
                    {
                        string es = k < e.Count ? Show((List<object>)e[k]) : "nothing";
                        string gs = k < got[i].Count ? Show(got[i][k]) : "nothing";
                        if (es != gs) first = $"layer {i} at {k}: expected {es}, got {gs}";
                    }
                    if (first != null) failures.Add($"{c["name"]} — {first}");
                    if (!visible[i]) hiddenEmpty |= e.Count == 0;
                    else
                    {
                        var alone = rules[i].Placements(cells[i], settings[i]);
                        bool same = alone.Count == e.Count;
                        for (int k = 0; same && k < e.Count; k++) same = Show(alone[k]) == Show((List<object>)e[k]);
                        if (!same) differAlone++;
                    }
                }
            }
            // The cases must exercise what they name.
            if (differAlone < 4) failures.Add($"the layered cases do not exercise the union ({differAlone} layer(s) differ from alone)");
            if (!hiddenEmpty) failures.Add("no layered case has a hidden layer that places nothing");
            return failures;
        }

        static string Show(List<object> e) =>
            $"[{MBJson.AsLong(e[0])},{MBJson.AsLong(e[1])},{MBJson.AsLong(e[2])},{(e[3] == null ? "null" : (string)e[3])},{MBJson.AsLong(e[4])}]";

        static string Show(Placement p) =>
            $"[{p.Vertex.x},{p.Vertex.y},{p.Vertex.z},{p.Tile ?? "null"},{p.QuarterTurns}]";
    }
}
