// MarchingBlocks Paint for Unity — runs editing_conformance.json against the editing rules: Extrude (MBTools.Extrude),
// Shrink (SelectionOp.ShrinkEdge), Widen (MBTools.WidenFlat), the Select brush (MBTools.SelectBrush) and Room from
// selection (MBShapes.RoomFromSelection). The answers come from the MarchingBlocks tool itself.
//
// No Unity dependency: compiled by the Test Runner and by the .NET conformance-runner.

using System.Collections.Generic;
using static MarchingBlocks.Paint.Tests.ParityCheck;

namespace MarchingBlocks.Paint.Tests
{
    public static class EditingConformanceCheck
    {
        public const string Format = "marchingblocks-editing-conformance";
        static readonly string[] Kinds = { "extrude", "shrink_edge", "widen_flat", "select_brush", "room_from_selection" };

        public static List<string> Run(Dictionary<string, object> conf, out int cases)
        {
            HashSet<Int3> world = conf.TryGetValue("world_cells", out var w) ? Cells(w) : new HashSet<Int3>();
            var pairs = new HashSet<string>();
            var errors = new HashSet<string>();
            var failures = ParityCheck.Run(conf, Format, Kinds, (kind, i, e) =>
            {
                HashSet<Int3> CellsOf(object o) => o is string ? world : Cells(o);
                switch (kind)
                {
                    case "extrude":
                    {
                        var dir = Direction((string)i["direction"]);
                        var mode = Mode((string)i["mode"]);
                        pairs.Add(dir + " " + mode);
                        var got = MBTools.Extrude(CellsOf(i["cells"]), I(i["floor"]), dir, Cells(i["selection"]), mode);
                        var ex = (Dictionary<string, object>)e;
                        return SameCells("set", got.Set, ex["set"]) ?? SameCells("clear", got.Clear, ex["clear"])
                            ?? SameCells("selection", got.Selection, ex["selection"])
                            ?? (got.Step.Equals(Vec(ex["step"])) ? null : $"step {got.Step}, expected {Vec(ex["step"])}");
                    }
                    case "shrink_edge":
                        return SameCells("selection", MBTools.Operate(new HashSet<Int3>(), Cells(i["selection"]),
                            SelectionOp.ShrinkEdge).Selection, e);
                    case "widen_flat":
                        return SameCells("selection", MBTools.WidenFlat(Cells(i["selection"])), e);
                    case "select_brush":
                    {
                        var cells = CellsOf(i["cells"]);
                        var targets = new List<Int3>();
                        foreach (var p in (List<object>)i["targets"]) targets.Add(Vec(p));
                        var got = MBTools.SelectBrush(Cells(i["selection"]), targets, cells.Contains,
                            (bool)i["include_empty"], (bool)i["deselect"]);
                        return SameCells("selection", got, e);
                    }
                    case "room_from_selection":
                    {
                        var ex = (Dictionary<string, object>)e;
                        var got = MBShapes.RoomFromSelection(CellsOf(i["cells"]), Cells(i["selection"]), I(i["floors"]),
                            (bool)i["up"], out var lo, out var hi);
                        errors.Add((string)ex["error"]);
                        if (got.Error != (string)ex["error"]) return $"error '{got.Error}', expected '{ex["error"]}'";
                        var box = (List<object>)ex["box"];
                        string boxWhy = box.Count == 0
                            ? (got.Error != "" ? null : "a box was expected empty")
                            : (lo.Equals(Vec(box[0])) && hi.Equals(Vec(box[1])) ? null
                                : $"box {lo}–{hi}, expected {Vec(box[0])}–{Vec(box[1])}");
                        return SameCells("set", got.Set, ex["set"]) ?? SameCells("clear", got.Clear, ex["clear"])
                            ?? (got.Repaired == I(ex["repaired"]) ? null : $"repaired {got.Repaired}, expected {ex["repaired"]}")
                            ?? boxWhy;
                    }
                }
                return "unreachable";
            }, out cases, out var kinds);

            if (conf.TryGetValue("limits", out var l))
            {
                var limits = (Dictionary<string, object>)l;
                if (MBJson.AsLong(limits["box_volume_max"]) != MBShapes.VolumeMax) failures.Add("box_volume_max differs from the plugin's");
                if (MBJson.AsLong(limits["room_floors_max"]) != MBShapes.RoomFloorsMax) failures.Add("room_floors_max differs from the plugin's");
            }
            // THE CASES EXERCISE WHAT THEY NAME: the nine pairs of Extrude, every refusal of Room.
            if (pairs.Count != 9) failures.Add($"the extrude cases cover {pairs.Count} direction × mode pairs, 9 are needed");
            foreach (var why in new[] { "", "too_small", "empty" })
                if (!errors.Contains(why)) failures.Add($"no room_from_selection case ends with '{why}'");
            return failures;
        }

        static ExtrudeDirection Direction(string s) =>
            s == "up" ? ExtrudeDirection.Up : s == "down" ? ExtrudeDirection.Down
            : s == "facing" ? ExtrudeDirection.Facing : throw new System.FormatException("direction " + s);

        static ExtrudeMode Mode(string s) =>
            s == "place" ? ExtrudeMode.Place : s == "extend" ? ExtrudeMode.Extend
            : s == "shift" ? ExtrudeMode.Shift : throw new System.FormatException("mode " + s);
    }
}
