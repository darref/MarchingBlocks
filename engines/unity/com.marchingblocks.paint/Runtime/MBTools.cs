// MarchingBlocks Paint for Unity — THE WORLD EDITING TOOLS, as pure functions.
//
// The same tools as the MarchingBlocks tool: aim at the matter, a brush with a size and a shape, a
// selection (paint, rectangle or box — hollow or not), and what you do with it: fill, delete, extrude,
// grow, shrink, connected, move, copy, paste.
//
// Every function here reads cells and RETURNS what changes; nothing is applied. The editor applies the
// result with Unity's Undo. Like MBRule.cs, this file has no Unity dependency: Tests/tools_conformance.json
// (computed by the MarchingBlocks tool itself, shipped with every plugin) proves it behaves exactly
// like the tool. Its rules_text says every rule in full.
//
// Everything is in FORMAT space: cell c covers [c, c+1] on each axis, +Y is up.

using System;
using System.Collections.Generic;

namespace MarchingBlocks.Paint
{
    public enum BrushTool { Add, Dig, Select }
    public enum BrushShape { Sphere, Cube, Disc }
    public enum SelectionOp { Delete, ExtrudeUp, ExtrudeDown, Grow, Shrink, Connected, Fill }

    /// <summary>What a click aims at: the floor plane (Grid) or the matter itself (Sculpt).</summary>
    public enum BrushAim { Grid, Sculpt }

    /// <summary>
    /// The aim, and whether you are navigating. Navigating is NOT a third aim: it is a switch (Space) that
    /// hands the mouse and keys back to the engine's own camera, and the aim you had comes back unchanged
    /// when you switch it off. Tab alternates Grid and Sculpt, and choosing an aim — by Tab or by its
    /// button — stops navigating: you pick an aim to aim, not to fly. The same rules as the MarchingBlocks
    /// tool.
    /// </summary>
    public readonly struct AimState
    {
        public readonly BrushAim Aim;
        public readonly bool Navigating;

        public AimState(BrushAim aim, bool navigating) { Aim = aim; Navigating = navigating; }

        /// <summary>Grid, not navigating.</summary>
        public static AimState Start => new AimState(BrushAim.Grid, false);

        /// <summary>Tab: the other aim, and navigation off.</summary>
        public AimState Tab() => new AimState(Aim == BrushAim.Grid ? BrushAim.Sculpt : BrushAim.Grid, false);

        /// <summary>Space: navigation on or off, the aim kept.</summary>
        public AimState Space() => new AimState(Aim, !Navigating);

        /// <summary>An aim's button: that aim, and navigation off.</summary>
        public AimState Choose(BrushAim aim) => new AimState(aim, false);

        /// <summary>A click paints only when not navigating.</summary>
        public bool Paints => !Navigating;

        public override string ToString() => Aim + (Navigating ? " + navigating" : "");
    }

    /// <summary>What a tool changes: cells to set, cells to clear, and the selection AFTER.</summary>
    public sealed class Change
    {
        public readonly HashSet<Int3> Set = new HashSet<Int3>();
        public readonly HashSet<Int3> Clear = new HashSet<Int3>();
        public readonly HashSet<Int3> Selection = new HashSet<Int3>();
        public bool IsEmpty => Set.Count == 0 && Clear.Count == 0;
    }

    public struct Hit
    {
        public bool Touched;
        public Int3 Cell;
        /// <summary>The face the ray entered by. Zero when nothing was touched.</summary>
        public Int3 Normal;
    }

    public static class MBTools
    {
        /// <summary>A box of more cells returns empty: two corners far apart by accident (a ray lost on
        /// the horizon) would otherwise freeze the editor.</summary>
        public const int BoxVolumeMax = 1048576;

        public static readonly Int3[] Faces =
        {
            new Int3(1, 0, 0), new Int3(-1, 0, 0), new Int3(0, 1, 0),
            new Int3(0, -1, 0), new Int3(0, 0, 1), new Int3(0, 0, -1),
        };

        public static int Compare(Int3 a, Int3 b) =>
            a.x != b.x ? a.x.CompareTo(b.x) : a.y != b.y ? a.y.CompareTo(b.y) : a.z.CompareTo(b.z);

        public static List<Int3> Sorted(IEnumerable<Int3> cells)
        {
            var l = new List<Int3>(cells);
            l.Sort(Compare);
            return l;
        }

        /// <summary>THE RAY AGAINST THE MATTER — cell by cell (Amanatides &amp; Woo). Aim at the CELLS,
        /// never at the rendered tiles: those are sculpted and overflow their cell. The start cell is
        /// skipped (a camera inside the matter would hit its own cell). <paramref name="ignore"/> is
        /// walked through as empty: what the current Add stroke just placed, or dragging would build a
        /// tower towards the camera.</summary>
        public static Hit Ray(Func<Int3, bool> full, double ox, double oy, double oz,
                              double dx, double dy, double dz, double reach, ICollection<Int3> ignore = null)
        {
            var none = new Hit();
            double len = Math.Sqrt(dx * dx + dy * dy + dz * dz);
            if (len < 1e-6) return none;
            double[] o = { ox, oy, oz };
            double[] d = { dx / len, dy / len, dz / len };
            int[] c = { (int)Math.Floor(ox), (int)Math.Floor(oy), (int)Math.Floor(oz) };
            int[] step = new int[3];
            double[] tMax = { double.PositiveInfinity, double.PositiveInfinity, double.PositiveInfinity };
            double[] tDelta = { double.PositiveInfinity, double.PositiveInfinity, double.PositiveInfinity };
            for (int a = 0; a < 3; a++)
            {
                if (Math.Abs(d[a]) < 1e-12) continue;
                step[a] = d[a] > 0 ? 1 : -1;
                double edge = d[a] > 0 ? c[a] + 1 : c[a];
                tMax[a] = (edge - o[a]) / d[a];
                tDelta[a] = Math.Abs(1.0 / d[a]);
            }
            while (true)
            {
                // The nearest boundary; on a tie, the lowest axis.
                int a = 0;
                if (tMax[1] < tMax[a]) a = 1;
                if (tMax[2] < tMax[a]) a = 2;
                if (tMax[a] > reach) return none;
                c[a] += step[a];
                tMax[a] += tDelta[a];
                var cell = new Int3(c[0], c[1], c[2]);
                if ((ignore == null || !ignore.Contains(cell)) && full(cell))
                {
                    var n = new int[3];
                    n[a] = -step[a];
                    return new Hit { Touched = true, Cell = cell, Normal = new Int3(n[0], n[1], n[2]) };
                }
            }
        }

        /// <summary>Where the brush stands. Add places AGAINST the face it aims at; the other tools act
        /// ON the cell. Without a hit (the floor plane), the cell itself.</summary>
        public static Int3 Anchor(BrushTool tool, Hit hit) =>
            tool == BrushTool.Add && hit.Touched ? hit.Cell + hit.Normal : hit.Cell;

        /// <summary>The cells of a brush, sorted. Size 1 is one cell; the radius is size - 1.
        /// Disc: the sphere cut by the plane across the normal — it dresses or digs a wall without
        /// thickening it. Without a normal the plane is horizontal.</summary>
        public static List<Int3> Brush(Int3 anchor, Int3 normal, int size, BrushShape shape)
        {
            int r = Math.Max(0, size - 1);
            var n = normal.Equals(default(Int3)) ? new Int3(0, 1, 0) : normal;
            var cells = new List<Int3>();
            for (int x = -r; x <= r; x++)
            for (int y = -r; y <= r; y++)
            for (int z = -r; z <= r; z++)
            {
                int l2 = x * x + y * y + z * z;
                bool inside = shape == BrushShape.Cube ? true
                    : shape == BrushShape.Disc ? l2 <= r * r && x * n.x + y * n.y + z * n.z == 0
                    : l2 <= r * r;
                if (inside) cells.Add(anchor + new Int3(x, y, z));
            }
            cells.Sort(Compare);
            return cells;
        }

        /// <summary>What a brush stroke changes: Add only sets empty cells, Dig only clears full ones,
        /// Select changes no cell.</summary>
        public static Change Modify(BrushTool tool, IEnumerable<Int3> targets, Func<Int3, bool> full)
        {
            var ch = new Change();
            foreach (var c in targets)
            {
                bool f = full(c);
                if (tool == BrushTool.Add && !f) ch.Set.Add(c);
                else if (tool == BrushTool.Dig && f) ch.Clear.Add(c);
            }
            return ch;
        }

        /// <summary>The operations on a selection. A selection is a set of cells, full OR empty: a box
        /// drawn in the air is a room you have not built yet. Operations that need matter filter it.</summary>
        public static Change Operate(ICollection<Int3> cells, ICollection<Int3> selection, SelectionOp op)
        {
            var ch = new Change();
            switch (op)
            {
                case SelectionOp.Delete:
                    foreach (var c in selection) if (cells.Contains(c)) ch.Clear.Add(c);
                    break;
                case SelectionOp.ExtrudeUp:
                case SelectionOp.ExtrudeDown:
                    var step = new Int3(0, op == SelectionOp.ExtrudeUp ? 1 : -1, 0);
                    foreach (var c in selection)
                    {
                        var p = c + step;
                        if (!cells.Contains(p)) ch.Set.Add(p);
                        ch.Selection.Add(p);
                    }
                    break;
                case SelectionOp.Grow:
                    foreach (var c in selection)
                    {
                        if (cells.Contains(c)) ch.Selection.Add(c);
                        foreach (var f in Faces) if (cells.Contains(c + f)) ch.Selection.Add(c + f);
                    }
                    break;
                case SelectionOp.Shrink:
                    foreach (var c in selection)
                    {
                        if (!cells.Contains(c)) continue;
                        bool inner = true;
                        foreach (var f in Faces) if (!selection.Contains(c + f)) { inner = false; break; }
                        if (inner) ch.Selection.Add(c);
                    }
                    break;
                case SelectionOp.Fill:
                    // The selection stays: fill, extrude, fill is how a room goes up.
                    foreach (var c in selection)
                    {
                        ch.Selection.Add(c);
                        if (!cells.Contains(c)) ch.Set.Add(c);
                    }
                    break;
                case SelectionOp.Connected:
                    var queue = new Stack<Int3>();
                    foreach (var c in selection)
                        if (cells.Contains(c) && ch.Selection.Add(c)) queue.Push(c);
                    while (queue.Count > 0)
                    {
                        var c = queue.Pop();
                        foreach (var f in Faces)
                        {
                            var v = c + f;
                            if (cells.Contains(v) && ch.Selection.Add(v)) queue.Push(v);
                        }
                    }
                    break;
            }
            return ch;
        }

        /// <summary>Every cell between two corners, bounds included, full or empty. Hollow keeps the skin
        /// only (a room); a box thinner than three cells on an axis has no inside and stays solid.
        /// More than <see cref="BoxVolumeMax"/> cells: empty — say so to the user.</summary>
        public static HashSet<Int3> Box(Int3 a, Int3 b, bool hollow)
        {
            var lo = new Int3(Math.Min(a.x, b.x), Math.Min(a.y, b.y), Math.Min(a.z, b.z));
            var hi = new Int3(Math.Max(a.x, b.x), Math.Max(a.y, b.y), Math.Max(a.z, b.z));
            var cells = new HashSet<Int3>();
            long volume = (long)(hi.x - lo.x + 1) * (hi.y - lo.y + 1) * (hi.z - lo.z + 1);
            if (volume > BoxVolumeMax) return cells;
            for (int x = lo.x; x <= hi.x; x++)
            for (int y = lo.y; y <= hi.y; y++)
            for (int z = lo.z; z <= hi.z; z++)
            {
                if (hollow && x > lo.x && x < hi.x && y > lo.y && y < hi.y && z > lo.z && z < hi.z) continue;
                cells.Add(new Int3(x, y, z));
            }
            return cells;
        }

        /// <summary>Moves the selected matter. A move that overlaps itself neither clears what it just
        /// set nor sets what stays; matter already at the destination stays (a move merges).</summary>
        public static Change Move(ICollection<Int3> cells, ICollection<Int3> selection, Int3 offset)
        {
            var ch = new Change();
            var source = new HashSet<Int3>();
            foreach (var c in selection) if (cells.Contains(c)) source.Add(c);
            foreach (var c in source) ch.Selection.Add(c + offset);
            foreach (var c in source) if (!ch.Selection.Contains(c)) ch.Clear.Add(c);
            foreach (var c in ch.Selection) if (!cells.Contains(c) || ch.Clear.Contains(c)) ch.Set.Add(c);
            return ch;
        }

        /// <summary>The selected matter, relative to the middle of its bottom face, sorted. That anchor is
        /// where it lands when pasted against the face you aim at.</summary>
        public static List<Int3> Copy(ICollection<Int3> cells, ICollection<Int3> selection)
        {
            var full = new List<Int3>();
            foreach (var c in selection) if (cells.Contains(c)) full.Add(c);
            if (full.Count == 0) return full;
            var lo = full[0];
            var hi = full[0];
            foreach (var c in full)
            {
                lo = new Int3(Math.Min(lo.x, c.x), Math.Min(lo.y, c.y), Math.Min(lo.z, c.z));
                hi = new Int3(Math.Max(hi.x, c.x), Math.Max(hi.y, c.y), Math.Max(hi.z, c.z));
            }
            // FLOOR of the half-sum: integer division truncates towards zero and would shift a paste
            // by one cell in negative coordinates.
            var anchor = new Int3(FloorHalf(lo.x + hi.x), lo.y, FloorHalf(lo.z + hi.z));
            var rel = new List<Int3>();
            foreach (var c in full) rel.Add(c - anchor);
            rel.Sort(Compare);
            return rel;
        }

        static int FloorHalf(int s) => (int)Math.Floor(s / 2.0);

        /// <summary>Pastes a clipboard at an anchor. Only empty cells are set; the selection becomes the
        /// pasted cells.</summary>
        public static Change Paste(ICollection<Int3> cells, IEnumerable<Int3> clipboard, Int3 anchor)
        {
            var ch = new Change();
            foreach (var d in clipboard)
            {
                var c = anchor + d;
                ch.Selection.Add(c);
                if (!cells.Contains(c)) ch.Set.Add(c);
            }
            return ch;
        }
    }
}
