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
            var shapeWorlds = new Dictionary<string, HashSet<Int3>>();
            if (conf.TryGetValue("shape_worlds", out var sw))
                foreach (var kv in (Dictionary<string, object>)sw) shapeWorlds[kv.Key] = Cells(kv.Value);
            if (MBJson.AsLong(limits["shape_length_max"]) != MBShapes.LengthMax || MBJson.AsLong(limits["shape_span_max"]) != MBShapes.SpanMax)
                failures.Add("shape limits differ from the plugin's");
            foreach (Dictionary<string, object> c in (List<object>)conf["cases"])
            {
                cases++;
                string why;
                try { why = RunCase(c, world, shapeWorlds); }
                catch (Exception e) { why = e.GetType().Name + ": " + e.Message; }
                if (why != null) failures.Add($"{c["name"]} — {why}");
            }
            return failures;
        }

        static string RunCase(Dictionary<string, object> c, HashSet<Int3> world, Dictionary<string, HashSet<Int3>> shapeWorlds)
        {
            var i = (Dictionary<string, object>)c["input"];
            var e = (Dictionary<string, object>)c["expected"];
            HashSet<Int3> CellsOf(string key) => i.ContainsKey("world") ? shapeWorlds[(string)i["world"]]
                : i[key] is string ? world : Cells(i[key]);
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
                case "wall_normal":
                {
                    var got = MBShapes.WallNormal(CellsOf("cells"), Vec(i["cell"]), Vec(i["face"]));
                    return got.Equals(Vec(e["normal"])) ? null : $"expected {Vec(e["normal"])}, got {got}";
                }
                case "special_shape":
                {
                    ShapeResult r;
                    var shape = SpecialShapeOf((string)i["shape"]);
                    if (shape == null) { r = new ShapeResult { Error = "unknown_shape" }; }
                    else
                    {
                        var req = new ShapeRequest
                        {
                            Shape = shape.Value, A = Vec(i["a"]), FaceA = Vec(i["face_a"]), Connect = (bool)i["connect"],
                            Profile = ProfileOf((string)i["profile"]), Size = (int)MBJson.AsLong(i["size"]),
                            Length = (int)MBJson.AsLong(i["length"]), Rail = (bool)i["rail"],
                        };
                        if (req.Connect) { req.B = Vec(i["b"]); req.FaceB = Vec(i["face_b"]); }
                        r = MBShapes.Build(CellsOf("cells"), req);
                    }
                    string got = $"{r.Error}/{r.Opened}/{r.Repaired}";
                    string want = $"{(string)e["error"]}/{(bool)e["opened"]}/{MBJson.AsLong(e["repaired"])}";
                    if (got != want) return $"error/opened/repaired: expected {want}, got {got}";
                    return Same("set", r.Set, e["set"]) ?? Same("clear", r.Clear, e["clear"]);
                }
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

        static SpecialShape? SpecialShapeOf(string s) => s == "tunnel" ? SpecialShape.Tunnel : s == "well" ? SpecialShape.Well
            : s == "bridge" ? SpecialShape.Bridge : s == "balcony" ? SpecialShape.Balcony : (SpecialShape?)null;

        static ShapeProfile ProfileOf(string s) => s == "round" ? ShapeProfile.Round : s == "square" ? ShapeProfile.Square
            : s == "arch" ? ShapeProfile.Arch : throw new ArgumentException("profile " + s);

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
