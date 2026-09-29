// MarchingBlocks Paint for Unity — runs world_conformance.json against the world reader (MBWorldFile.cs).
//
// No Unity dependency: the same file is compiled by the Test Runner (WorldConformanceTests.cs) and by the
// .NET conformance-runner outside Unity. Returns one line per failure, empty when all pass.
// The expected answers come from the MarchingBlocks tool's own reader; a refusal is written
// {"error": true}: the REASON is not imposed on plugins, only the refusal.

using System;
using System.Collections.Generic;

namespace MarchingBlocks.Paint.Tests
{
    public static class WorldConformanceCheck
    {
        public const string Format = "marchingblocks-world-conformance";
        public const int SupportedVersion = 1;

        public static List<string> Run(Dictionary<string, object> conf, out int cases)
        {
            var failures = new List<string>();
            cases = 0;
            if (!(conf.TryGetValue("format", out var f) && f as string == Format) || MBJson.AsLong(conf["version"]) > SupportedVersion)
            {
                failures.Add("not a world conformance file this plugin reads");
                return failures;
            }
            int refusals = 0, good = 0;
            bool negative = false, hidden = false, withoutTiles = false, empty = false;
            foreach (Dictionary<string, object> c in (List<object>)conf["cases"])
            {
                cases++;
                var expected = (Dictionary<string, object>)c["expected"];
                WorldFileResult got;
                try { got = MBWorldFile.Read(c["world"]); }
                catch (Exception e) { failures.Add($"{c["name"]} — {e.GetType().Name}: {e.Message}"); continue; }
                if (expected.ContainsKey("error"))
                {
                    refusals++;
                    if (got.Ok) failures.Add($"{c["name"]} — must be REFUSED, was read ({got.Layers.Count} layers)");
                    continue;
                }
                good++;
                if (!got.Ok) { failures.Add($"{c["name"]} — refused: {got.Error}"); continue; }
                var layers = (List<object>)expected["layers"];
                if (layers.Count != got.Layers.Count)
                {
                    failures.Add($"{c["name"]} — {got.Layers.Count} layers, expected {layers.Count}");
                    continue;
                }
                for (int i = 0; i < layers.Count; i++)
                {
                    var e = (Dictionary<string, object>)layers[i];
                    var g = got.Layers[i];
                    string where = $"{c["name"]}, layer {i}";
                    if ((string)e["name"] != g.Name) failures.Add($"{where} — name '{g.Name}', expected '{e["name"]}'");
                    if ((bool)e["visible"] != g.Visible) failures.Add($"{where} — visible {g.Visible}, expected {e["visible"]}");
                    if (e["tileset"] as string != g.Tileset) failures.Add($"{where} — tileset '{g.Tileset}', expected '{e["tileset"]}'");
                    var cells = (List<object>)e["cells"];
                    if (cells.Count != g.Cells.Count) failures.Add($"{where} — {g.Cells.Count} cells, expected {cells.Count}");
                    else
                        for (int k = 0; k < cells.Count; k++)
                        {
                            var p = (List<object>)cells[k];
                            var want = new Int3((int)MBJson.AsLong(p[0]), (int)MBJson.AsLong(p[1]), (int)MBJson.AsLong(p[2]));
                            if (!want.Equals(g.Cells[k])) { failures.Add($"{where} — cell {k} is {Show(g.Cells[k])}, expected {Show(want)}"); break; }
                        }
                    // What the good case must exercise, read from the EXPECTED side, never from ours.
                    if (e["tileset"] == null) withoutTiles = true;
                    if (!(bool)e["visible"]) hidden = true;
                    if (cells.Count == 0) empty = true;
                    foreach (List<object> p in cells)
                        if (MBJson.AsLong(p[0]) < 0 || MBJson.AsLong(p[1]) < 0 || MBJson.AsLong(p[2]) < 0) negative = true;
                }
            }
            // THE CASES EXERCISE WHAT THEY NAME: a case that never refuses, or never shows a hidden layer,
            // would guard nothing.
            if (good < 1 || refusals < 6)
                failures.Add($"the world cases hold {good} good world(s) and {refusals} refusal(s): at least 1 and 6 are needed");
            if (!(negative && hidden && withoutTiles && empty))
                failures.Add("the good world must hold a negative cell, a hidden layer, a layer without tiles and an empty layer");

            // PATHS ARE RELATIVE TO world.json. Written by hand, not computed by the function under test.
            Expect(failures, MBWorldFile.ResolveRelative("Assets/My World.mbworld/world.json", "rock.mbset/tileset.json"),
                "Assets/My World.mbworld/rock.mbset/tileset.json", "a tileset next to world.json");
            Expect(failures, MBWorldFile.ResolveRelative("Assets/a/w.mbworld/world.json", "../shared.mbset/./tileset.json"),
                "Assets/a/shared.mbset/tileset.json", "'..' and '.' are resolved");
            Expect(failures, MBWorldFile.ResolveRelative("Assets\\w.mbworld\\world.json", "rock.mbset/tileset.json"),
                "Assets/w.mbworld/rock.mbset/tileset.json", "Windows separators become '/'");
            Expect(failures, MBWorldFile.TilesPath("Assets/w.mbworld/rock.mbset/tileset.json", "{\"tiles_file\": \"tiles.glb\"}"),
                "Assets/w.mbworld/rock.mbset/tiles.glb", "the tiles file is next to its tileset.json");
            Expect(failures, MBWorldFile.TilesPath("Assets/w.mbworld/rock.mbset/tileset.json", "{}"),
                "Assets/w.mbworld/rock.mbset/tiles.glb", "tiles.glb when the manifest does not name it");

            // A file that is not JSON at all is refused, not thrown.
            if (MBWorldFile.Read("{\"format\": \"marchingblocks-world\", \"layers\": [").Ok)
                failures.Add("truncated JSON is read instead of refused");
            return failures;
        }

        static void Expect(List<string> failures, string got, string expected, string what)
        {
            if (got != expected) failures.Add($"path: {what} — got '{got}', expected '{expected}'");
        }

        static string Show(Int3 c) => $"({c.x}, {c.y}, {c.z})";
    }
}
