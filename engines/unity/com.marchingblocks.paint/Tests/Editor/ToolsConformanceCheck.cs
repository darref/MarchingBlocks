// MarchingBlocks Paint for Unity — runs tools_conformance.json against Tools (MBTools.cs).
//
// No Unity dependency: the same file is compiled by the Test Runner (ToolsConformanceTests.cs) and by
// the .NET conformance-runner outside Unity. Returns one line per failing case, empty when all pass.

using System;
using System.Collections.Generic;
using System.Linq;

namespace MarchingBlocks.Paint.Tests
{
    public static class ToolsConformanceCheck
    {
        public const string Format = "marchingblocks-tools-conformance";
        public const int SupportedVersion = 1;

        public static List<string> Run(Dictionary<string, object> conf, out int cases)
        {
            var failures = new List<string>();
            cases = 0;
            if ((string)conf["format"] != Format || MBJson.AsLong(conf["version"]) > SupportedVersion)
            {
                failures.Add("not a tools conformance file this plugin reads");
                return failures;
            }
            var limits = (Dictionary<string, object>)conf["limits"];
            if (MBJson.AsLong(limits["box_volume_max"]) != MBTools.BoxVolumeMax)
                failures.Add($"box_volume_max is {limits["box_volume_max"]}, the plugin uses {MBTools.BoxVolumeMax}");
            var world = Cells(conf["world"]);
            foreach (Dictionary<string, object> c in (List<object>)conf["cases"])
            {
                cases++;
                string why;
                try { why = RunCase(c, world); }
                catch (Exception e) { why = e.GetType().Name + ": " + e.Message; }
                if (why != null) failures.Add($"{c["name"]} — {why}");
            }
            return failures;
        }

        static string RunCase(Dictionary<string, object> c, HashSet<Int3> world)
        {
            var i = (Dictionary<string, object>)c["input"];
            var e = (Dictionary<string, object>)c["expected"];
            HashSet<Int3> CellsOf(string key) => i[key] is string ? world : Cells(i[key]);
            switch ((string)c["kind"])
            {
                case "ray":
                {
                    var cells = CellsOf("cells");
                    var o = Doubles(i["origin"]);
                    var d = Doubles(i["direction"]);
                    var hit = MBTools.Ray(cells.Contains, o[0], o[1], o[2], d[0], d[1], d[2],
                        MBJson.AsDouble(i["reach"]), Cells(i["ignore"]));
                    string got = $"{hit.Touched} {hit.Cell} {hit.Normal}";
                    string want = $"{(bool)e["hit"]} {Vec(e["cell"])} {Vec(e["normal"])}";
                    return got == want ? null : $"expected {want}, got {got}";
                }
                case "anchor":
                {
                    var hit = new Hit { Touched = (bool)i["hit"], Cell = Vec(i["cell"]), Normal = Vec(i["normal"]) };
                    var got = MBTools.Anchor(ToolOf((string)i["tool"]), hit);
                    return got.Equals(Vec(e["anchor"])) ? null : $"expected {Vec(e["anchor"])}, got {got}";
                }
                case "brush":
                    return Same("cells", MBTools.Brush(Vec(i["anchor"]), Vec(i["normal"]),
                        (int)MBJson.AsLong(i["size"]), ShapeOf((string)i["shape"])), e["cells"]);
                case "change":
                {
                    var cells = CellsOf("cells");
                    var ch = MBTools.Modify(ToolOf((string)i["tool"]), Cells(i["targets"]), cells.Contains);
                    return Same("set", ch.Set, e["set"]) ?? Same("clear", ch.Clear, e["clear"]);
                }
                case "selection":
                    return SameChange(MBTools.Operate(CellsOf("cells"), Cells(i["selection"]), OpOf((string)i["op"])), e);
                case "box":
                {
                    var box = MBTools.Box(Vec(i["a"]), Vec(i["b"]), (bool)i["hollow"]);
                    long count = MBJson.AsLong(e["count"]);
                    if (box.Count != count) return $"expected {count} cells, got {box.Count}";
                    return e.ContainsKey("cells") ? Same("cells", box, e["cells"]) : null;
                }
                case "move":
                    return SameChange(MBTools.Move(CellsOf("cells"), Cells(i["selection"]), Vec(i["offset"])), e);
                case "copy":
                    return Same("clipboard", MBTools.Copy(CellsOf("cells"), Cells(i["selection"])), e["clipboard"]);
                case "paste":
                    return SameChange(MBTools.Paste(CellsOf("cells"), Cells(i["clipboard"]), Vec(i["anchor"])), e);
            }
            return $"unknown kind {c["kind"]}";
        }

        static string SameChange(Change ch, Dictionary<string, object> e) =>
            Same("set", ch.Set, e["set"]) ?? Same("clear", ch.Clear, e["clear"]) ??
            Same("selection", ch.Selection, e["selection"]);

        // Sets are compared sorted; lists (brush, clipboard) must also come out in the same order.
        static string Same(string what, IEnumerable<Int3> got, object expected)
        {
            var g = got is List<Int3> l ? l : MBTools.Sorted(got);
            var w = MBTools.Sorted(Cells(expected));
            if (got is List<Int3> && !g.SequenceEqual(MBTools.Sorted(g))) return $"{what} is not sorted";
            if (g.SequenceEqual(w)) return null;
            string Show(List<Int3> x) => x.Count > 8 ? $"{x.Count} cells" : string.Join(" ", x);
            return $"{what}: expected {Show(w)}, got {Show(g)}";
        }

        static BrushTool ToolOf(string s) => s == "add" ? BrushTool.Add : s == "dig" ? BrushTool.Dig : s == "select" ? BrushTool.Select
            : throw new ArgumentException("tool " + s);

        static BrushShape ShapeOf(string s) => s == "sphere" ? BrushShape.Sphere : s == "cube" ? BrushShape.Cube
            : s == "disc" ? BrushShape.Disc : throw new ArgumentException("shape " + s);

        static SelectionOp OpOf(string s)
        {
            switch (s)
            {
                case "delete": return SelectionOp.Delete;
                case "extrude_up": return SelectionOp.ExtrudeUp;
                case "extrude_down": return SelectionOp.ExtrudeDown;
                case "grow": return SelectionOp.Grow;
                case "shrink": return SelectionOp.Shrink;
                case "connected": return SelectionOp.Connected;
                case "fill": return SelectionOp.Fill;
            }
            throw new ArgumentException("op " + s);
        }

        static Int3 Vec(object o)
        {
            var a = (List<object>)o;
            return new Int3((int)MBJson.AsLong(a[0]), (int)MBJson.AsLong(a[1]), (int)MBJson.AsLong(a[2]));
        }

        static double[] Doubles(object o) => ((List<object>)o).Select(MBJson.AsDouble).ToArray();

        static HashSet<Int3> Cells(object o)
        {
            var s = new HashSet<Int3>();
            foreach (var p in (List<object>)o) s.Add(Vec(p));
            return s;
        }
    }
}
