// Runs every case of conformance.json through the Unity plugin's Rule, and every case of
// tools_conformance.json through its Tools, and every case of world_conformance.json through its world
// reader (MBWorldFile), and the aim and navigation switch (AimState) through AimCheck, and exits 1 on any divergence. LangVersion 9: the same language level Unity compiles the package with.
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MarchingBlocks.Paint;
using MarchingBlocks.Paint.Tests;

static class Program
{
    static int Main(string[] args)
    {
        if (args.Length == 2 && args[0] == "--water-timing") return WaterTiming(args[1]);
        string path = args.Length > 0 ? args[0] : "../com.marchingblocks.paint/Tests/conformance.json";
        var conf = (Dictionary<string, object>)MBJson.Parse(File.ReadAllText(path));
        var tilesets = (Dictionary<string, object>)conf["tilesets"];
        int cases = 0, failed = 0, placements = 0;
        foreach (Dictionary<string, object> c in (List<object>)conf["cases"])
        {
            cases++;
            var rule = new Rule(conf, (Dictionary<string, object>)tilesets[(string)c["tileset"]]);
            var cells = new HashSet<Int3>();
            foreach (List<object> p in (List<object>)c["cells"])
                cells.Add(new Int3((int)MBJson.AsLong(p[0]), (int)MBJson.AsLong(p[1]), (int)MBJson.AsLong(p[2])));
            var got = rule.Placements(cells);
            var expected = (List<object>)c["expected"];
            placements += expected.Count;
            string first = null;
            for (int i = 0; i < Math.Max(got.Count, expected.Count) && first == null; i++)
            {
                string e = i < expected.Count ? Show((List<object>)expected[i]) : "nothing";
                string g = i < got.Count ? Show(got[i]) : "nothing";
                if (e != g) first = $"at {i}: expected {e}, got {g}";
            }
            if (first != null)
            {
                failed++;
                Console.WriteLine($"  FAIL {c["name"]} — {first}");
            }
        }
        // A newer format must be refused.
        conf["version"] = (long)Rule.SupportedVersion + 1;
        bool refused = Rule.Check(conf) != "";
        if (!refused) { failed++; Console.WriteLine("  FAIL a newer format is accepted"); }
        conf["version"] = (long)Rule.SupportedVersion;
        // One tile per key: a manifest that still lists copies per key must be refused, never misread.
        conf["tiles"] = new Dictionary<string, object> { ["corner_b1h0"] = new List<object> { "corner_b1h0", "corner_b1h0_2" } };
        if (!Rule.Check(conf).Contains("one tile per key")) { failed++; Console.WriteLine("  FAIL a list of copies is accepted"); }
        conf["tiles"] = new Dictionary<string, object> { ["corner_b1h0"] = "corner_b1h0" };
        if (Rule.Check(conf) != "") { failed++; Console.WriteLine("  FAIL one tile per key is refused"); }
        Console.WriteLine($"{cases} cases, {placements} placements, {failed} failure(s)");

        var variantFailures = VariantConformanceCheck.Run((Dictionary<string, object>)MBJson.Parse(File.ReadAllText(path)), out int variantCases, out int variantPlacements);
        foreach (var f in variantFailures) Console.WriteLine("  FAIL variants: " + f);
        Console.WriteLine($"{variantCases} variant cases, {variantPlacements} placements, {variantFailures.Count} failure(s)");
        failed += variantFailures.Count;

        var layeredFailures = LayeredConformanceCheck.Run((Dictionary<string, object>)MBJson.Parse(File.ReadAllText(path)), out int layeredCases, out int layeredPlacements);
        foreach (var f in layeredFailures) Console.WriteLine("  FAIL layers: " + f);
        Console.WriteLine($"{layeredCases} layered cases, {layeredPlacements} placements, {layeredFailures.Count} failure(s)");
        failed += layeredFailures.Count;

        string toolsPath = args.Length > 1 ? args[1] : "../com.marchingblocks.paint/Tests/tools_conformance.json";
        var toolsFailures = ToolsConformanceCheck.Run((Dictionary<string, object>)MBJson.Parse(File.ReadAllText(toolsPath)), out int toolCases);
        foreach (var f in toolsFailures) Console.WriteLine("  FAIL tools: " + f);
        Console.WriteLine($"{toolCases} tools cases, {toolsFailures.Count} failure(s)");
        failed += toolsFailures.Count;

        string worldPath = args.Length > 2 ? args[2] : "../com.marchingblocks.paint/Tests/world_conformance.json";
        var worldFailures = WorldConformanceCheck.Run((Dictionary<string, object>)MBJson.Parse(File.ReadAllText(worldPath)), out int worldCases);
        foreach (var f in worldFailures) Console.WriteLine("  FAIL world: " + f);
        Console.WriteLine($"{worldCases} world cases, {worldFailures.Count} failure(s)");
        failed += worldFailures.Count;

        // THE PARITY FILES (engines/PARITE.md): six files, read IN ADDITION — the three above never change.
        string tests = Path.GetDirectoryName(Path.GetFullPath(path));
        foreach (var (file, run) in Parity)
        {
            var conf2 = (Dictionary<string, object>)MBJson.Parse(File.ReadAllText(Path.Combine(tests, file)));
            var parityFailures = run(conf2, out int parityCases);
            foreach (var f in parityFailures) Console.WriteLine($"  FAIL {file}: " + f);
            Console.WriteLine($"{parityCases} cases of {file}, {parityFailures.Count} failure(s)");
            failed += parityFailures.Count;
        }

        // THE REPRISE (engines/PARITE.md §12, 3): incremental == whole, on random gestures over the mesh file's worlds.
        var meshConf = (Dictionary<string, object>)MBJson.Parse(File.ReadAllText(Path.Combine(tests, "water_mesh_conformance.json")));
        var incFailures = WaterIncrementalCheck.Run(meshConf, 150, 2026, out int incChecks, out string incStats);
        foreach (var f in incFailures) Console.WriteLine("  FAIL water reprise: " + f);
        Console.WriteLine($"{incChecks} water gestures, incremental == whole ({incStats}), {incFailures.Count} failure(s)");
        failed += incFailures.Count;

        // THE EXPORTED WORLD (hors git, DEV_TOOLS/preparer_eau_unity.gd): the rule and the mesher against MarchingBlocks' sheets.
        string exported = Path.GetFullPath(Path.Combine(tests, "../../test-project/Assets/water_world_expected.json"));
        if (File.Exists(exported))
        {
            var exFailures = WaterMeshConformanceCheck.RunExportedWorld((Dictionary<string, object>)MBJson.Parse(File.ReadAllText(exported)),
                out int exLayers, out int exTriangles);
            foreach (var f in exFailures) Console.WriteLine("  FAIL exported water world: " + f);
            Console.WriteLine($"{exLayers} water layers of the exported world ({exTriangles} triangles), {exFailures.Count} failure(s)");
            failed += exFailures.Count;
        }
        else Console.WriteLine("(no exported water world: run DEV_TOOLS/preparer_eau_unity.gd to check it)");

        var wheelFailures = WheelCheck.Run(out int wheelChecks);
        foreach (var f in wheelFailures) Console.WriteLine("  FAIL wheel: " + f);
        Console.WriteLine($"{wheelChecks} wheel checks, {wheelFailures.Count} failure(s)");
        failed += wheelFailures.Count;

        var aimFailures = AimCheck.Run(out int aimChecks);
        foreach (var f in aimFailures) Console.WriteLine("  FAIL aim: " + f);
        Console.WriteLine($"{aimChecks} aim checks, {aimFailures.Count} failure(s)");
        failed += aimFailures.Count;
        Console.WriteLine(failed == 0 ? "VERDICT: OK" : "VERDICT: FAILED");
        return failed == 0 ? 0 : 1;
    }

    delegate List<string> ParityRun(Dictionary<string, object> conf, out int cases);

    static readonly (string, ParityRun)[] Parity =
    {
        ("editing_conformance.json", EditingConformanceCheck.Run),
        ("animation_conformance.json", AnimationConformanceCheck.Run),
        ("transitions_conformance.json", TransitionsConformanceCheck.Run),
        ("foliage_conformance.json", FoliageConformanceCheck.Run),
        ("water_conformance.json", WaterConformanceCheck.Run),
        ("water_mesh_conformance.json", WaterMeshConformanceCheck.Run),
    };

    static string Show(List<object> e) =>
        $"[{MBJson.AsLong(e[0])},{MBJson.AsLong(e[1])},{MBJson.AsLong(e[2])},{(e[3] == null ? "null" : (string)e[3])},{MBJson.AsLong(e[4])}]";

    static string Show(Placement p) =>
        $"[{p.Vertex.x},{p.Vertex.y},{p.Vertex.z},{p.Tile ?? "null"},{p.QuarterTurns}]";

    // ── THE TIMES OF THE WATER IN C# (engines/PARITE.md §12, the budget), on the example dumped by preparer_eau_unity.gd ──

    static int WaterTiming(string file)
    {
        var sw = System.Diagnostics.Stopwatch.StartNew();
        var conf = (Dictionary<string, object>)MBJson.Parse(File.ReadAllText(file));
        var flat = (List<object>)conf["cells"];
        var cells = new HashSet<Int3>();
        for (int i = 0; i < flat.Count; i += 3)
            cells.Add(new Int3((int)MBJson.AsLong(flat[i]), (int)MBJson.AsLong(flat[i + 1]), (int)MBJson.AsLong(flat[i + 2])));
        var all = new List<Int3>();
        var owner = new List<int>();
        var layers = (List<object>)conf["layers"];
        for (int l = 0; l < layers.Count; l++)
        {
            var s = (List<object>)((Dictionary<string, object>)layers[l])["sources"];
            for (int i = 0; i < s.Count; i += 3)
            {
                all.Add(new Int3((int)MBJson.AsLong(s[i]), (int)MBJson.AsLong(s[i + 1]), (int)MBJson.AsLong(s[i + 2])));
                owner.Add(l);
            }
        }
        Console.WriteLine($"example: {cells.Count} full cells, {layers.Count} water layers, {all.Count} sources (read in {sw.ElapsedMilliseconds} ms)");
        double Best(Func<double> f) { double b = double.MaxValue; for (int k = 0; k < 3; k++) b = Math.Min(b, f()); return b; }
        double Ms(Action a) { var t = System.Diagnostics.Stopwatch.StartNew(); a(); return t.Elapsed.TotalMilliseconds; }
        WaterWorld w = null;
        double rule = Best(() => Ms(() => w = MBWater.World(cells, all)));
        Console.WriteLine($"RULE, whole (MBWater.World): {rule:F0} ms · sea {w.Sea.Count} cells");
        List<WaterBody> Bodies(WaterWorld ww, int l) { var o = new List<WaterBody>(); for (int k = 0; k < all.Count; k++) if (owner[k] == l) o.Add(ww.Bodies[k]); return o; }
        double sheets = 0;
        var memories = new List<WaterMeshMemory>();
        for (int l = 0; l < layers.Count; l++)
        {
            WaterSheetArrays a = null;
            var bodies = Bodies(w, l);
            double t = Best(() => Ms(() => a = MBWaterMesh.Arrays(bodies, cells, w.Box, null)));
            sheets += t;
            var kinds = new Dictionary<string, int>();
            foreach (var b in bodies) { string k = b.Error != "" ? "refused" : b.Kind; kinds[k] = (kinds.TryGetValue(k, out var n) ? n : 0) + 1; }
            var m = new WaterMeshMemory();
            MBWaterMesh.Arrays(bodies, cells, w.Box, m);
            memories.Add(m);
            Console.WriteLine($"  SHEET layer {l} ({string.Join(", ", kinds.Select(kv => kv.Key + " " + kv.Value))}): {t:F0} ms · {a.TriangleCount} triangles");
        }
        Console.WriteLine($"SHEETS, whole, every layer: {sheets:F0} ms");
        Console.WriteLine($"EVERYTHING AGAIN (rule + sheets): {rule + sheets:F0} ms");
        HashSet<Int3> copy = null;
        Console.WriteLine($"a copy of the cells (what the editor hands to its thread): {Best(() => Ms(() => copy = new HashSet<Int3>(cells))):F0} ms");
        Console.WriteLine($"the changed cells, by comparing two copies: {Best(() => Ms(() => MBWater.ChangedBetween(cells, copy))):F0} ms");
        // A GESTURE, with the reprise: a cell set beside a river, then a cell set far from any water (above the top).
        var near = new Int3(0, 0, 0);
        bool found = false;
        foreach (var b in w.Bodies)
        {
            if (found || b.Error != "" || b.Kind != "river" || b.Course.Count == 0) continue;
            var c0 = b.Course[b.Course.Count / 2].Cell;
            foreach (var d in new[] { new Int3(1, 0, 0), new Int3(-1, 0, 0), new Int3(0, 0, 1), new Int3(0, 0, -1) })
                if (!cells.Contains(c0 + d) && !w.Sea.Contains(c0 + d)) { near = c0 + d; found = true; break; }
        }
        var top = new Int3(0, int.MinValue, 0);
        foreach (var c in cells) if (c.y > top.y) top = c;
        foreach (var (what, at) in new[] { ("a cell set beside a river", near), ("a cell set far from the water (on the summit)", top + new Int3(0, 1, 0)) })
        {
            var mems = new List<WaterMeshMemory>();
            for (int l = 0; l < layers.Count; l++) { var m = new WaterMeshMemory(); MBWaterMesh.Arrays(Bodies(w, l), cells, w.Box, m); mems.Add(m); }
            cells.Add(at);
            var changed = new HashSet<Int3> { at };
            WaterWorld w2 = null;
            double r2 = Ms(() => w2 = MBWater.World(cells, all, w, changed));
            int taken = 0;
            for (int k = 0; k < all.Count; k++) if (ReferenceEquals(w2.Bodies[k], w.Bodies[k])) taken++;
            double s2 = Ms(() =>
            {
                for (int l = 0; l < layers.Count; l++)
                {
                    var b1 = Bodies(w, l);
                    var b2 = Bodies(w2, l);
                    bool same = true;
                    for (int k = 0; k < b1.Count; k++)
                        if (!ReferenceEquals(b1[k], b2[k]) && !(b1[k].Error != "" && b2[k].Error != "")) same = false;
                    if (same) continue;   // a layer whose bodies are all taken again keeps its sheet
                    MBWaterMesh.Arrays(b2, cells, w2.Box, mems[l]);
                }
            });
            Console.WriteLine($"GESTURE — {what} {at}: rule {r2:F0} ms ({taken} of {all.Count} sources taken again), sheets {s2:F0} ms, total {r2 + s2:F0} ms");
            cells.Remove(at);
        }
        return 0;
    }
}
