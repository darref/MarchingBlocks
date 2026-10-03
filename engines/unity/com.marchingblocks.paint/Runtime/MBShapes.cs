// MarchingBlocks Paint for Unity — THE SPECIAL SHAPES: tunnel, well, bridge, balcony and stairs.
//
// A tunnel digs into a wall and a well into a floor or a ceiling, square to it; in one click they go
// through to the next cave (or Length cells deep), and Connect joins two faces anywhere — slanted walls
// included — with both ends open. A bridge builds a deck across the air from a wall; a balcony puts a
// slab with its rail against a wall; stairs climb a wall to the clicked height, or join two floors.
//
// Like MBTools.cs, no Unity dependency: Tests/tools_conformance.json (computed by the MarchingBlocks tool)
// proves this file gives exactly the tool's cells, case by case; its rules_text says every rule in full.
// Everything is INTEGER (cell centres, squared distances in 64 bits): no rounding can differ.
//
// FORMAT space: cell c covers [c, c+1] on each axis, +Y is up.

using System;
using System.Collections.Generic;

namespace MarchingBlocks.Paint
{
    // Room is LAST, so nothing a scene saved is renumbered. It is DRAWN (a rectangle on the floor), not clicked:
    // MBShapes.Room, never Build.
    public enum SpecialShape { Tunnel, Well, Bridge, Balcony, Stairs, Room }
    public enum ShapeProfile { Round, Square, Arch }

    /// <summary>What a special shape asks for.</summary>
    public struct ShapeRequest
    {
        public SpecialShape Shape;
        public Int3 A, FaceA;
        public bool Connect;
        public Int3 B, FaceB;
        public ShapeProfile Profile;
        public int Size;
        public int Length;
        public bool Rail;
        /// <summary>One-click stairs: how deep each step is, 1 to MBShapes.StepMax cells.</summary>
        public int Step;
    }

    /// <summary>What it changes, or why it refuses (Error is "" when it does not).</summary>
    public sealed class ShapeResult
    {
        public readonly HashSet<Int3> Set = new HashSet<Int3>();
        public readonly HashSet<Int3> Clear = new HashSet<Int3>();
        public string Error = "";
        public bool Opened;
        public int Repaired;
        public bool IsEmpty => Set.Count == 0 && Clear.Count == 0;
    }

    public static class MBShapes
    {
        public const int LengthMax = 64;
        public const int SpanMax = 128;
        public const int StepMax = 4;
        public const long VolumeMax = 1048576;
        public const int RoomFloorsMax = 32;

        /// <summary>A ROOM: a rectangle drawn flat on a floor (a and b its corners, a.y the floor's y), raised UP — the
        /// rectangle is the room's floor — or DOWN — it is its ceiling — by `floors` free floors. A shell one cell
        /// thick, its inside dug out. At least 3 × 3 (too_small). Nothing changes on an error.</summary>
        public static ShapeResult Room(ICollection<Int3> cells, Int3 a, Int3 b, int floors, bool up)
        {
            var r = new ShapeResult();
            int x0 = Math.Min(a.x, b.x), x1 = Math.Max(a.x, b.x), z0 = Math.Min(a.z, b.z), z1 = Math.Max(a.z, b.z);
            if (x1 - x0 < 2 || z1 - z0 < 2) { r.Error = "too_small"; return r; }
            int e = Math.Max(1, Math.Min(floors, RoomFloorsMax));
            int y0 = up ? a.y : a.y - e - 1, y1 = y0 + e + 1;
            if ((long)(x1 - x0 + 1) * (z1 - z0 + 1) * (e + 2) > VolumeMax) { r.Error = "too_large"; return r; }
            for (int x = x0; x <= x1; x++)
                for (int z = z0; z <= z1; z++)
                    for (int y = y0; y <= y1; y++)
                    {
                        var c = new Int3(x, y, z);
                        if (x == x0 || x == x1 || z == z0 || z == z1 || y == y0 || y == y1)
                        { if (!cells.Contains(c)) r.Set.Add(c); }
                        else if (cells.Contains(c)) r.Clear.Add(c);
                    }
            r.Repaired = Repair(cells, r.Set, r.Clear, false);
            return r;
        }

        static readonly Int3[] Horizontal = { new Int3(1, 0, 0), new Int3(-1, 0, 0), new Int3(0, 0, 1), new Int3(0, 0, -1) };
        static readonly Int3[][] Planes =
        {
            new[] { new Int3(1, 0, 0), new Int3(0, 1, 0) },
            new[] { new Int3(1, 0, 0), new Int3(0, 0, 1) },
            new[] { new Int3(0, 1, 0), new Int3(0, 0, 1) },
        };
        static readonly Int3 Zero = new Int3(0, 0, 0);
        static readonly Int3 Up = new Int3(0, 1, 0);

        static long Dot(Int3 a, Int3 b) => (long)a.x * b.x + (long)a.y * b.y + (long)a.z * b.z;
        static int Sign(long x) => x > 0 ? 1 : x < 0 ? -1 : 0;
        static Int3 Mul(Int3 a, int k) => new Int3(a.x * k, a.y * k, a.z * k);
        static Int3 Neg(Int3 a) => new Int3(-a.x, -a.y, -a.z);

        public static bool Digs(SpecialShape s) => s == SpecialShape.Tunnel || s == SpecialShape.Well;

        /// <summary>The normal of a wall, ESTIMATED: a 45° wall is a staircase of cells whose faces say ±X or
        /// ±Z, never the slant. Sum the exposed horizontal faces of the 3×3×3 window, snap to eight directions.</summary>
        public static Int3 WallNormal(ICollection<Int3> cells, Int3 c, Int3 face)
        {
            long sx = 0, sz = 0;
            for (int x = -1; x <= 1; x++)
                for (int y = -1; y <= 1; y++)
                    for (int z = -1; z <= 1; z++)
                    {
                        var q = c + new Int3(x, y, z);
                        if (!cells.Contains(q)) continue;
                        foreach (var f in Horizontal)
                            if (!cells.Contains(q + f)) { sx += f.x; sz += f.z; }
                    }
            long m = Math.Max(Math.Abs(sx), Math.Abs(sz));
            if (m == 0) return face;
            var n = new Int3(2 * Math.Abs(sx) >= m ? Sign(sx) : 0, 0, 2 * Math.Abs(sz) >= m ? Sign(sz) : 0);
            return Dot(n, face) <= 0 ? face : n;
        }

        /// <summary>The normal a shape keeps for a clicked face, or zero when that face does not suit it.
        /// Connected stairs want a floor (the top face), every other wall shape a horizontal face.</summary>
        public static Int3 NormalFor(SpecialShape s, ICollection<Int3> cells, Int3 c, Int3 face, bool connect = false)
        {
            if (s == SpecialShape.Well)
                return face.x == 0 && face.z == 0 && face.y != 0 ? face : Zero;
            if (s == SpecialShape.Stairs && connect)
                return face.Equals(Up) ? face : Zero;
            if (face.y != 0 || (face.x == 0 && face.z == 0)) return Zero;
            return WallNormal(cells, c, face);
        }

        /// <summary>The error for an end that NormalFor refuses.</summary>
        public static string EndError(SpecialShape s, bool connect) =>
            s == SpecialShape.Well ? "needs_floor_or_ceiling"
            : s == SpecialShape.Stairs && connect ? "needs_a_floor" : "needs_a_wall";

        public static ShapeResult Build(ICollection<Int3> cells, ShapeRequest r)
        {
            var res = new ShapeResult();
            int h = Math.Max(1, Math.Min(7, r.Size)) - 1;
            int length = Math.Max(1, Math.Min(LengthMax, r.Length));
            bool dig = Digs(r.Shape);
            bool connect = r.Connect && r.Shape != SpecialShape.Balcony;
            var na = NormalFor(r.Shape, cells, r.A, r.FaceA, connect);
            if (na.Equals(Zero)) { res.Error = EndError(r.Shape, connect); return res; }
            HashSet<Int3> chosen;
            if (r.Shape == SpecialShape.Balcony)
                chosen = Balcony(r.A, na, length, h, r.Rail);
            else if (r.Shape == SpecialShape.Stairs)
            {
                if (connect)
                {
                    if (NormalFor(r.Shape, cells, r.B, r.FaceB, true).Equals(Zero)) { res.Error = "needs_a_floor"; return res; }
                    if (r.B.Equals(r.A)) { res.Error = "same_cell"; return res; }
                    if (Dot(r.B - r.A, r.B - r.A) > (long)SpanMax * SpanMax) { res.Error = "too_far"; return res; }
                    chosen = StairsBetween(cells, r.A, r.B, h, r.Rail);
                    if (chosen == null) { res.Error = "too_steep"; return res; }
                }
                else
                {
                    int step = Math.Max(1, Math.Min(StepMax, r.Step));
                    chosen = Stairs(cells, r.A, na, length, step, h, r.Rail);
                }
            }
            else
            {
                var points = new List<Int3>();
                if (connect)
                {
                    var nb = NormalFor(r.Shape, cells, r.B, r.FaceB);
                    if (nb.Equals(Zero)) { res.Error = EndError(r.Shape, false); return res; }
                    if (r.B.Equals(r.A)) { res.Error = "same_cell"; return res; }
                    if (Dot(r.B - r.A, r.B - r.A) > (long)SpanMax * SpanMax) { res.Error = "too_far"; return res; }
                    var da = dig ? Neg(na) : na;
                    var db = dig ? Neg(nb) : nb;
                    var ea = r.A + Mul(da, Leg(r.A, da, r.B, h));
                    var eb = r.B + Mul(db, Leg(r.B, db, r.A, h));
                    foreach (var q in new[] { r.A, ea, eb, r.B })
                        if (points.Count == 0 || !points[points.Count - 1].Equals(q)) points.Add(q);
                }
                else
                {
                    // One click: dig to the far wall cell before the first empty cell (or Length deep); a
                    // bridge runs to the first full cell in front.
                    var s = dig ? Neg(na) : na;
                    var end = Zero;
                    bool found = false;
                    for (int k = 1; k <= length; k++)
                    {
                        var q = r.A + Mul(s, k);
                        if (cells.Contains(q) != dig)
                        {
                            end = dig && k > 1 ? q - s : q;
                            found = true;
                            break;
                        }
                    }
                    if (!found)
                    {
                        if (!dig) { res.Error = "nothing_in_front"; return res; }
                        end = r.A + Mul(s, length);
                    }
                    res.Opened = found;
                    points.Add(r.A);
                    points.Add(end);
                }
                string profile = r.Shape == SpecialShape.Bridge ? "deck"
                    : r.Profile == ShapeProfile.Square ? "square" : r.Profile == ShapeProfile.Arch ? "arch" : "round";
                chosen = Sweep(points, h, profile, r.Rail, out string error);
                if (error != "") { res.Error = error; return res; }
            }
            foreach (var q in chosen)
            {
                if (dig && cells.Contains(q)) res.Clear.Add(q);
                else if (!dig && !cells.Contains(q)) res.Set.Add(q);
            }
            res.Repaired = Repair(cells, res.Set, res.Clear, dig);
            return res;
        }

        /// <summary>One-click stairs against a wall: they ARRIVE level with the clicked cell. Row j (the smallest
        /// j >= 1 with (d.n)^2 <= j^2 |n|^2) has its top at a.y - (j - 1) / step; they end at the first row whose
        /// top cells are all full already (the ground), or after Length rows.</summary>
        static HashSet<Int3> Stairs(ICollection<Int3> cells, Int3 a, Int3 n, int length, int step, int h, bool rail)
        {
            long nn = Dot(n, n);
            var m = new Int3(-n.z, 0, n.x);
            int reach = length + h + 1;
            var rows = new List<Int3>[length + 1];
            for (int x = -reach; x <= reach; x++)
                for (int z = -reach; z <= reach; z++)
                {
                    var d = new Int3(x, 0, z);
                    long along = Dot(d, n), side = Dot(d, m);
                    if (along <= 0 || side * side > (long)h * h * nn) continue;
                    int j = 1;
                    while (along * along > (long)j * j * nn) j++;
                    if (j > length) continue;
                    if (rows[j] == null) rows[j] = new List<Int3>();
                    rows[j].Add(d);
                }
            var body = new HashSet<Int3>();
            for (int j = 1; j <= length; j++)
            {
                if (rows[j] == null) continue;
                int top = a.y - (j - 1) / step;
                bool grounded = true;
                foreach (var d in rows[j])
                    if (!cells.Contains(new Int3(a.x + d.x, top, a.z + d.z))) { grounded = false; break; }
                if (grounded) break;
                foreach (var d in rows[j])
                {
                    long side = Dot(d, m);
                    bool edge = rail && h >= 1 && side * side > (long)(h - 1) * (h - 1) * nn;
                    Column(cells, body, new Int3(a.x + d.x, top, a.z + d.z), edge);
                }
            }
            return body;
        }

        /// <summary>Connected stairs, floor to floor, straight across from the lower end L to the higher H; null
        /// when steeper than one cell up per cell across (too_steep).</summary>
        static HashSet<Int3> StairsBetween(ICollection<Int3> cells, Int3 a, Int3 b, int h, bool rail)
        {
            var lo = a.y <= b.y ? a : b;
            var hi = a.y <= b.y ? b : a;
            var loFlat = new Int3(lo.x, 0, lo.z);
            var dv = new Int3(hi.x - lo.x, 0, hi.z - lo.z);
            long ddv = Dot(dv, dv);
            long rise = hi.y - lo.y;
            if (rise * rise > ddv) return null;
            var u = new Int3(-dv.z, 0, dv.x);
            var columns = new HashSet<Int3>();
            for (int x = Math.Min(lo.x, hi.x) - h - 1; x <= Math.Max(lo.x, hi.x) + h + 1; x++)
                for (int z = Math.Min(lo.z, hi.z) - h - 1; z <= Math.Max(lo.z, hi.z) + h + 1; z++)
                {
                    var d = new Int3(x - lo.x, 0, z - lo.z);
                    long t = Dot(d, dv), side = Dot(d, u);
                    if (t >= 0 && t <= ddv && side * side <= (long)h * h * ddv) columns.Add(new Int3(x, 0, z));
                }
            foreach (var q in AxisWalk(loFlat, new Int3(hi.x, 0, hi.z))) columns.Add(q);
            var body = new HashSet<Int3>();
            foreach (var c in columns)
            {
                var d = c - loFlat;
                long t = Math.Max(0, Math.Min(ddv, Dot(d, dv)));
                long side = Dot(d, u);
                bool edge = rail && h >= 1 && side * side > (long)(h - 1) * (h - 1) * ddv;
                Column(cells, body, new Int3(c.x, (int)(lo.y + t * rise / ddv), c.z), edge);
            }
            return body;
        }

        /// <summary>A stairs column: its top and every empty cell below it down to the ground; with no ground
        /// within LengthMax cells, the top and the cell under it. A full top adds nothing. An edge column carries
        /// the rail, the cell above its top.</summary>
        static void Column(ICollection<Int3> cells, HashSet<Int3> body, Int3 top, bool edge)
        {
            if (cells.Contains(top)) return;
            body.Add(top);
            var below = new List<Int3>();
            bool ground = false;
            for (int k = 1; k <= LengthMax; k++)
            {
                var q = new Int3(top.x, top.y - k, top.z);
                if (cells.Contains(q)) { ground = true; break; }
                below.Add(q);
            }
            if (ground) foreach (var q in below) body.Add(q);
            else body.Add(new Int3(top.x, top.y - 1, top.z));
            if (edge) body.Add(top + Up);
        }

        /// <summary>A leg leaves its face square to it over h + 1 cells, never beyond a third of the way.</summary>
        static int Leg(Int3 start, Int3 dir, Int3 other, int h)
        {
            long want = h + 1;
            long nn = Dot(dir, dir);
            int k = 0;
            while ((long)k * k * nn < want * want) k++;
            long w = Dot(dir, other - start);
            long dd = Dot(other - start, other - start);
            while (k > 0 && w > 0 && 3L * k * w > dd) k--;
            return k;
        }

        /// <summary>The cells crossed by the axis from p0 to p1, one axis per step; a tie goes to the lowest axis.</summary>
        public static List<Int3> AxisWalk(Int3 p0, Int3 p1)
        {
            var d = p1 - p0;
            long[] ad = { Math.Abs((long)d.x), Math.Abs((long)d.y), Math.Abs((long)d.z) };
            int[] s = { Sign(d.x), Sign(d.y), Sign(d.z) };
            long[] k = { 0, 0, 0 };
            var c = p0;
            var outp = new List<Int3> { c };
            long steps = ad[0] + ad[1] + ad[2];
            for (long n = 0; n < steps; n++)
            {
                int best = -1;
                for (int i = 0; i < 3; i++)
                {
                    if (k[i] >= ad[i]) continue;
                    if (best < 0 || (2 * k[i] + 1) * ad[best] < (2 * k[best] + 1) * ad[i]) best = i;
                }
                if (best == 0) c.x += s[0]; else if (best == 1) c.y += s[1]; else c.z += s[2];
                k[best]++;
                outp.Add(c);
            }
            return outp;
        }

        static HashSet<Int3> Sweep(List<Int3> points, int h, string profile, bool rail, out string error)
        {
            error = "";
            var body = new HashSet<Int3>();
            var rails = new HashSet<Int3>();
            var walkway = new HashSet<Int3>();
            bool withRail = profile == "deck" && rail && h >= 1;
            int last = points.Count - 1;
            if (last < 1) { error = "same_cell"; return body; }
            long h2 = (long)h * h;
            for (int i = 0; i < last; i++)
            {
                var p0 = points[i];
                var p1 = points[i + 1];
                long e0 = i > 0 ? h : 0;
                long e1 = i + 1 < last ? h : 0;
                int margin = h + 2 + (int)Math.Max(e0, e1);
                var lo = new Int3(Math.Min(p0.x, p1.x) - margin, Math.Min(p0.y, p1.y) - margin, Math.Min(p0.z, p1.z) - margin);
                var hi = new Int3(Math.Max(p0.x, p1.x) + margin, Math.Max(p0.y, p1.y) + margin, Math.Max(p0.z, p1.z) + margin);
                if ((long)(hi.x - lo.x + 1) * (hi.y - lo.y + 1) * (hi.z - lo.z + 1) > VolumeMax) { error = "too_large"; return body; }
                var dv = p1 - p0;
                long ddv = Dot(dv, dv);
                var u = new Int3(1, 0, 0);
                var v = new Int3(0, 0, 1);
                if (dv.x != 0 || dv.z != 0)
                {
                    u = new Int3(-dv.z, 0, dv.x);
                    v = new Int3(-dv.x * dv.y, dv.x * dv.x + dv.z * dv.z, -dv.y * dv.z);
                }
                long uu = Dot(u, u), vv = Dot(v, v);
                foreach (var q in AxisWalk(p0, p1)) body.Add(q);
                for (int x = lo.x; x <= hi.x; x++)
                    for (int y = lo.y; y <= hi.y; y++)
                        for (int z = lo.z; z <= hi.z; z++)
                        {
                            var q = new Int3(x, y, z);
                            var d = q - p0;
                            long t = Dot(d, dv);
                            if (t < 0 && (e0 == 0 || t * t > e0 * e0 * ddv)) continue;
                            if (t > ddv && (e1 == 0 || (t - ddv) * (t - ddv) > e1 * e1 * ddv)) continue;
                            long ca = Dot(d, u), cb = Dot(d, v);
                            long a2 = ca * ca, b2 = cb * cb;
                            switch (profile)
                            {
                                case "round":
                                    if (a2 * vv + b2 * uu <= h2 * uu * vv) body.Add(q);
                                    break;
                                case "square":
                                    if (a2 <= h2 * uu && b2 <= h2 * vv) body.Add(q);
                                    break;
                                case "arch":
                                    if (cb >= 0) { if (a2 * vv + b2 * uu <= h2 * uu * vv) body.Add(q); }
                                    else if (a2 <= h2 * uu && b2 <= h2 * vv) body.Add(q);
                                    break;
                                case "deck":
                                    if (a2 <= h2 * uu && 4 * b2 <= vv) body.Add(q);
                                    else if (withRail && cb > 0 && 4 * b2 <= 9 * vv && a2 <= h2 * uu)
                                    {
                                        if (a2 > (long)(h - 1) * (h - 1) * uu) rails.Add(q);
                                        else walkway.Add(q);
                                    }
                                    break;
                            }
                        }
            }
            foreach (var q in rails)
                if (!walkway.Contains(q)) body.Add(q);
            return body;
        }

        static HashSet<Int3> Balcony(Int3 a, Int3 n, int depth, int h, bool rail)
        {
            var body = new HashSet<Int3>();
            long nn = Dot(n, n);
            var m = new Int3(-n.z, 0, n.x);
            bool withRail = rail && h >= 1 && depth >= 2;
            int reach = depth + h + 1;
            for (int x = -reach; x <= reach; x++)
                for (int z = -reach; z <= reach; z++)
                {
                    var d = new Int3(x, 0, z);
                    long along = Dot(d, n), side = Dot(d, m);
                    if (along <= 0 || along * along > (long)depth * depth * nn || side * side > (long)h * h * nn) continue;
                    body.Add(a + d);
                    if (withRail)
                    {
                        bool inner = along * along <= (long)(depth - 1) * (depth - 1) * nn && side * side <= (long)(h - 1) * (h - 1) * nn;
                        if (!inner) body.Add(a + d + Up);
                    }
                }
            return body;
        }

        /// <summary>No two cells may touch by an edge only. By rounds, order-free: every 2×2 checkerboard
        /// around a cell changed in the previous round; dig clears its full pair, add sets its empty pair.</summary>
        static int Repair(ICollection<Int3> cells, HashSet<Int3> set, HashSet<Int3> clear, bool dig)
        {
            bool Full(Int3 c) => set.Contains(c) || (cells.Contains(c) && !clear.Contains(c));
            var front = new List<Int3>(dig ? clear : set);
            int added = 0;
            while (front.Count > 0)
            {
                var change = new HashSet<Int3>();
                foreach (var c in front)
                    foreach (var plane in Planes)
                    {
                        var e1 = plane[0];
                        var e2 = plane[1];
                        foreach (var o in new[] { c, c - e1, c - e2, c - e1 - e2 })
                        {
                            Int3 p00 = o, p10 = o + e1, p01 = o + e2, p11 = o + e1 + e2;
                            bool f00 = Full(p00), f10 = Full(p10), f01 = Full(p01), f11 = Full(p11);
                            if (f00 == f11 && f10 == f01 && f00 != f10)
                            {
                                if (f00 == dig) { change.Add(p00); change.Add(p11); }
                                else { change.Add(p10); change.Add(p01); }
                            }
                        }
                    }
                front = new List<Int3>();
                foreach (var q in change)
                {
                    if (dig) clear.Add(q); else set.Add(q);
                    front.Add(q);
                    added++;
                }
                if (added > VolumeMax) break;
            }
            return added;
        }
    }
}
