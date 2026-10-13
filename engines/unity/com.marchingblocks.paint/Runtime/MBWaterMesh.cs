// MarchingBlocks Paint for Unity — THE WATER SHEET: what the water rule (MBWater.cs) deduced, made into surfaces.
//
// The reference is MarchingBlocks' eau_maillage.gd (tableaux_du_maillage), ported line by line; its cases are
// Tests/water_mesh_conformance.json (a BAG of triangles, compared without order — engines/PARITE.md §12). Like MBRule.cs
// and MBWater.cs, this file has no Unity dependency: the .NET conformance-runner compiles it as is.
//
// THE DATA CONTRACT, carried by every vertex (the same as the baked water/<name>.glb):
//   COLOR r, g — the flow in the plane (x, z), from [−1, 1] to [0, 1]; (0.5, 0.5) = still water;
//   COLOR b    — the KIND: 0 still (lake, sea), 0.5 river, 0.75 foam, 1 waterfall;
//   COLOR a    — the depth under the surface in cells / 8 (capped at 1; 1 without a floor); the FOAM on a waterfall;
//   UV         — (x, z) of the world on flat water; (across, y) on a waterfall.
// Everything is in FORMAT space (cell c covers [c, c+1], +Y up), triangles COUNTER-CLOCKWISE seen from the front (glTF).
//
// Floats: computed in double, stored in 32-bit floats — as MarchingBlocks does (Godot's Vector3 and Color are 32-bit).

using System;
using System.Collections.Generic;

namespace MarchingBlocks.Paint
{
    /// <summary>A 32-bit vector, as the engine stores it.</summary>
    public struct WaterVec3
    {
        public float x, y, z;
        public WaterVec3(double x, double y, double z) { this.x = (float)x; this.y = (float)y; this.z = (float)z; }
        public override string ToString() => $"({x}, {y}, {z})";
    }

    /// <summary>The arrays of a water sheet, before the engine stores them (format space, glTF winding).</summary>
    public sealed class WaterSheetArrays
    {
        public readonly List<WaterVec3> Positions = new List<WaterVec3>();
        public readonly List<WaterVec3> Normals = new List<WaterVec3>();
        /// <summary>COLOR_0, four floats per vertex (r, g, b, a).</summary>
        public readonly List<float> Colors = new List<float>();
        /// <summary>TEXCOORD_0, two floats per vertex (u, v), glTF's convention.</summary>
        public readonly List<float> UVs = new List<float>();
        /// <summary>Three per triangle, COUNTER-CLOCKWISE seen from the front ((B − A) × (C − A) on the side of the normals).</summary>
        public readonly List<int> Triangles = new List<int>();
        public int VertexCount => Positions.Count;
        public int TriangleCount => Triangles.Count / 3;
    }

    /// <summary>What the mesher keeps from one call to the next (eau_maillage.gd, `memoire`): the flat rectangles of each
    /// body (reused while the rule returns the SAME body object — MBWater.World with a previous world), the compiled
    /// waterfalls by their fields, the compiled springs by their cell. One per water layer.</summary>
    public sealed class WaterMeshMemory
    {
        internal readonly Dictionary<int, (WaterBody body, List<MBWaterMesh.Flat> flats)> Sheets =
            new Dictionary<int, (WaterBody, List<MBWaterMesh.Flat>)>();
        internal Dictionary<MBWaterMesh.FallKey, MBWaterMesh.Grid[]> Falls = new Dictionary<MBWaterMesh.FallKey, MBWaterMesh.Grid[]>();
        internal Dictionary<Int3, MBWaterMesh.Grid[]> Springs = new Dictionary<Int3, MBWaterMesh.Grid[]>();
        /// <summary>The floor r everything kept was made for: another floor, a fresh memory (the heights changed).</summary>
        internal double Floor = MBWaterMesh.FloorDefault;
        /// <summary>How many bodies' sheets the last call took from the memory (a diagnosis).</summary>
        public int ReusedSheets { get; internal set; }
    }

    public static class MBWaterMesh
    {
        /// <summary>A still sheet at its top row + Surface, a band at its cell + River — those of an INSET floor (0.25).</summary>
        public const double Surface = 0.7;       // NAPPE
        public const double River = 0.05;        // RIVIERE (a THICK band since 13 October 2026; -0.15 before)
        /// <summary>THE FLOOR r (world.json water_floor): where the ground of the tiles is drawn — the top of a full cell
        /// y − 1 is seen at y − r (0.25 inset, 0 centred, −0.25 outset). A sheet at L + SheetHeight(r), a band at
        /// y + BandHeight(r), a waterfall's plane moved by Advance(r). At r = 0.25 they are Surface and River.</summary>
        public const double FloorDefault = 0.25; // SOL_DEFAUT
        public const double Thin = 0.05;         // MINCE
        public const double AboveFloor = 0.3;    // AU_DESSUS_DU_SOL (0.1 before 13 October 2026: a sheet of paper)
        public const double BandDepth = AboveFloor / 8.0;   // PROFONDEUR_DE_BANDE: a band's COLOR.a (its thickness / 8)
        public static double SheetHeight(double r) => 1.0 - Math.Abs(r) - Thin;
        public static double BandHeight(double r) => AboveFloor - r;
        public static double Advance(double r) => FloorDefault - r;
        public const double Overlap = 0.45;      // DEBORD
        public const double Sheet = 0.35;        // LAME
        public const double Arc = 0.7;           // ARC
        public const double Flare = 0.04;        // EVASE
        public const double FlareMax = 0.2;      // EVASE_MAXI
        public const double IntoRock = 0.4;      // DANS_LA_ROCHE
        public const double Rounding = 0.35;     // ARRONDI
        public const double Overhang = 0.1;      // DEPASSE
        public const double Churn = 0.85;        // REMOUS
        public const double Spray = 0.9;         // EMBRUN
        public const double FoamRise = 1.3;      // MONTEE_D_ECUME
        public const double Horizon = 2000.0;    // LARGE
        public const double Spring = 0.7;        // SOURCE
        public const double SpringDome = 0.08;   // SOURCE_DOME

        public const double Still = 0.0, Flowing = 0.5, Foam = 0.75, Fall = 1.0;

        static readonly Int3 Up = new Int3(0, 1, 0);
        static readonly Int3 Down = new Int3(0, -1, 0);
        static readonly Int3[] Horizontal = { new Int3(1, 0, 0), new Int3(-1, 0, 0), new Int3(0, 0, 1), new Int3(0, 0, -1) };

        // ── what is built before the arrays ─────────────────────────────────────────────────────────────────────────

        /// <summary>A COLOR_0, stored in 32 bits (Godot's Color).</summary>
        internal struct Col : IEquatable<Col>
        {
            public float r, g, b, a;
            public bool Equals(Col o) => r == o.r && g == o.g && b == o.b && a == o.a;
            public override bool Equals(object o) => o is Col c && Equals(c);
            public override int GetHashCode() => r.GetHashCode() ^ (g.GetHashCode() * 31) ^ (b.GetHashCode() * 97) ^ (a.GetHashCode() * 193);
        }

        /// <summary>A horizontal rectangle {x0, x1, z0, z1, h, color} — or, when Points is set, the points of something
        /// else (the top of a waterfall) to insert in the flats, nothing to draw.</summary>
        internal sealed class Flat
        {
            public double X0, X1, Z0, Z1, H;
            public Col Color;
            public List<WaterVec3> Points;
        }

        /// <summary>A compiled grid: vertices and triangles counted from 0, in MarchingBlocks' order (Godot's: clockwise).</summary>
        internal sealed class Grid
        {
            public WaterVec3[] V = new WaterVec3[0], N = new WaterVec3[0];
            public Col[] C = new Col[0];
            public double[] U = new double[0], W = new double[0];   // uv, as Godot's Vector2 (32-bit)
            public int[] I = new int[0];
            public List<WaterVec3> TopRow;   // a waterfall's top row (T-junction points)
        }

        /// <summary>A waterfall retained in SEEN (eau_maillage.gd `_lame`), merged with the others of its plane and place.</summary>
        internal sealed class Waterfall
        {
            public int Axis, Sense, Along;
            public double Plane, Top, Foot, Ground;
            public Int3 D;
            public bool Straight, Free0, Free1;
            public double U0, U1;
        }

        /// <summary>Everything the rest of the computation reads of a waterfall: the same key, the same grids (floats
        /// compared EXACTLY, as MarchingBlocks does).</summary>
        internal readonly struct FallKey : IEquatable<FallKey>
        {
            readonly int axis, sense, along, dx, dy, dz;
            readonly double plane, top, foot, ground;
            readonly bool free0, free1;
            public FallKey(Waterfall l)
            {
                axis = l.Axis; sense = l.Sense; along = l.Along; plane = l.Plane; top = l.Top; foot = l.Foot; ground = l.Ground;
                dx = l.D.x; dy = l.D.y; dz = l.D.z; free0 = l.Free0; free1 = l.Free1;
            }
            public bool Equals(FallKey o) => axis == o.axis && sense == o.sense && along == o.along && plane == o.plane
                && top == o.top && foot == o.foot && ground == o.ground && dx == o.dx && dy == o.dy && dz == o.dz
                && free0 == o.free0 && free1 == o.free1;
            public override bool Equals(object o) => o is FallKey k && Equals(k);
            public override int GetHashCode()
            {
                int h = 17;
                foreach (var x in new[] { axis, sense, along, dx, dz, plane.GetHashCode(), top.GetHashCode(), foot.GetHashCode(),
                    ground.GetHashCode(), free0 ? 1 : 0, free1 ? 1 : 0 })
                    h = h * 31 + x;
                return h;
            }
        }

        sealed class Seen
        {
            public List<HashSet<Int3>> Dormant = new List<HashSet<Int3>>();
            public HashSet<Int3> Bands = new HashSet<Int3>();
            public Dictionary<(int, long, int), Waterfall> Falls = new Dictionary<(int, long, int), Waterfall>();
            public List<(int, long, int)> FallOrder = new List<(int, long, int)>();
            /// <summary>All the water of the layer: a band is not closed by a flank on the side of another water.</summary>
            public HashSet<Int3> Waters = new HashSet<Int3>();
            public double Floor = FloorDefault;
        }

        static Col Color(double fx, double fz, double kind, double a) => new Col
        {
            r = (float)(fx * 0.5 + 0.5), g = (float)(fz * 0.5 + 0.5), b = (float)kind, a = (float)Clamp(a, 0.0, 1.0),
        };

        static double Clamp(double v, double lo, double hi) => v < lo ? lo : v > hi ? hi : v;
        static double Lerp(double a, double b, double t) => a + (b - a) * t;
        /// <summary>Godot's roundi: half away from zero.</summary>
        static long RoundI(double v) => (long)Math.Round(v, MidpointRounding.AwayFromZero);
        static int K(double v) => (int)RoundI(v * 20.0);
        static WaterVec3 V(double x, double y, double z) => new WaterVec3(x, y, z);

        // ── THE ARRAYS OF THE SHEET (tableaux_du_maillage) ─────────────────────────────────────────────────────────

        /// <summary>The sheet of ONE water layer: its bodies (MBWater.World, in order — a body with an error draws nothing),
        /// against the full cells of EVERY tile layer. <paramref name="memory"/>: kept by the caller from one call to the
        /// next (one per water layer), or null.</summary>
        public static WaterSheetArrays Arrays(IList<WaterBody> bodies, ICollection<Int3> cells, WaterMeshMemory memory = null,
            double floor = FloorDefault) =>
            Arrays(bodies, cells, MBWater.BoxOf(cells), memory, floor);

        /// <summary>The same, with the box of the world already known (MBWater.World returns it).</summary>
        /// <param name="floor">The floor r (FloorDefault: inset).</param>
        public static WaterSheetArrays Arrays(IList<WaterBody> bodies, ICollection<Int3> cells, WaterBox box, WaterMeshMemory memory,
            double floor = FloorDefault)
        {
            var a = new WaterSheetArrays();
            var flats = new List<Flat>();
            var seen = new Seen { Floor = floor };
            var springs = new List<Int3>();
            // Les eaux DORMANTES (océan, lacs, lacs des rivières) : une cascade qui tombe dans l'une d'elles pose son remous
            // sur SA nappe, pas au fond.
            foreach (var r in bodies)
            {
                if (r == null || r.Error != "") continue;
                if (r.Kind == "sea" || r.Kind == "lake") { seen.Dormant.Add(r.Water); seen.Waters.UnionWith(r.Water); }
                else if (r.Kind == "river")
                {
                    foreach (var lake in r.Lakes) { seen.Dormant.Add(lake.Cells); seen.Waters.UnionWith(lake.Cells); }
                    foreach (var e in r.Course) seen.Waters.Add(e.Cell);
                }
            }
            // Tout ce que la mémoire garde dépend du sol (les hauteurs) : un autre sol, une mémoire neuve.
            if (memory != null && memory.Floor != floor)
            {
                memory.Sheets.Clear();
                memory.Falls.Clear();
                memory.Springs.Clear();
            }
            if (memory != null) memory.Floor = floor;
            var keep = memory != null ? memory.Sheets : new Dictionary<int, (WaterBody, List<Flat>)>();
            var used = new HashSet<int>();
            int reused = 0;
            for (int j = 0; j < bodies.Count; j++)
            {
                var r = bodies[j];
                if (r == null || r.Error != "") continue;
                if (keep.TryGetValue(j, out var kept) && ReferenceEquals(kept.Item1, r))
                {
                    flats.AddRange(kept.Item2);
                    reused++;
                }
                else
                {
                    var sheets = SheetsOfBody(r, cells, box, floor);
                    keep[j] = (r, sheets);
                    flats.AddRange(sheets);
                }
                used.Add(j);
                if (r.Kind == "river") RiverOf(a, r.Course, cells, flats, seen, springs);
            }
            foreach (var j in new List<int>(keep.Keys)) if (!used.Contains(j)) keep.Remove(j);
            var foam = new List<Grid>();
            var fallsBefore = memory != null ? memory.Falls : new Dictionary<FallKey, Grid[]>();
            var fallsNow = new Dictionary<FallKey, Grid[]>();
            PlaceWaterfalls(a, seen, foam, flats, fallsBefore, fallsNow);
            var springsBefore = memory != null ? memory.Springs : new Dictionary<Int3, Grid[]>();
            var springsNow = new Dictionary<Int3, Grid[]>();
            foreach (var c in springs)
            {
                if (!springsBefore.TryGetValue(c, out var gs))
                {
                    var raw = SpringOf(c, floor);
                    gs = new[] { Compile(raw[0]), Compile(raw[1]) };
                }
                springsNow[c] = gs;
                foam.AddRange(gs);
            }
            if (memory != null)
            {
                memory.Falls = fallsNow;
                memory.Springs = springsNow;
                memory.ReusedSheets = reused;
            }
            PlaceFlats(a, flats);
            foreach (var g in foam) Place(a, g);
            return a;
        }

        /// <summary>The rectangles of a body's sheets: the sea (and its horizon), a lake, the lakes of a river.</summary>
        static List<Flat> SheetsOfBody(WaterBody r, ICollection<Int3> cells, WaterBox b, double floor)
        {
            var flats = new List<Flat>();
            double top = SheetHeight(floor);
            switch (r.Kind)
            {
                case "sea":
                {
                    int level = r.Level;
                    double h = double.NaN;
                    if (!b.Empty && level > b.Hi.y) h = level + top;   // le monde est noyé : l'eau s'arrête au-dessus
                    flats.AddRange(SheetRectangles(r.Water, cells, level, h, floor));
                    flats.AddRange(OffShore(b, level + top));
                    break;
                }
                case "lake":
                    flats.AddRange(SheetRectangles(r.Water, cells, r.Level, double.NaN, floor));
                    break;
                case "river":
                    foreach (var lake in r.Lakes) flats.AddRange(SheetRectangles(lake.Cells, cells, lake.Level, double.NaN, floor));
                    break;
            }
            return flats;
        }

        /// <summary>THE DRAWN SURFACE of still water of level <paramref name="level"/> (surface_dessinee): MBWater.Surface (nothing
        /// above), PLUS its cells at the level under a ceiling (water under a floating storey: there is air above it).</summary>
        public static List<Int3> DrawnSurface(ICollection<Int3> water, ICollection<Int3> cells, int level)
        {
            var s = MBWater.Surface(water, cells);
            foreach (var c in water)
                if (c.y == level && cells.Contains(c + Up)) s.Add(c);
            return s;
        }

        // LES RECTANGLES D'UNE NAPPE (rectangles_de_nappe) : chaque case de surface est le rectangle débordant sous ses
        // voisines pleines, à sa rangée + NAPPE ; unis par rangées (x), puis par bandes voisines en z de même étendue.
        static List<Flat> SheetRectangles(ICollection<Int3> water, ICollection<Int3> cells, int level, double forcedH, double floor)
        {
            double top = SheetHeight(floor);
            var depths = new Dictionary<Int3, int>();
            foreach (var c in DrawnSurface(water, cells, level)) depths[c] = MBWater.Depth(water, cells, c);
            var sorted = new List<Int3>(depths.Keys);
            // L'ordre (y, z, x) : la sortie ne dépend d'aucune table de hachage.
            sorted.Sort((p, q) => p.y != q.y ? p.y.CompareTo(q.y) : p.z != q.z ? p.z.CompareTo(q.z) : p.x.CompareTo(q.x));
            // 1. Les rangées.
            var rows = new List<Row>();
            Row cur = null;
            foreach (var c in sorted)
            {
                int p = depths[c];
                var colour = Color(0, 0, Still, p < 0 ? 1.0 : p / 8.0);
                double xm = cells.Contains(c + new Int3(-1, 0, 0)) ? Overlap : 0.0;
                double xp = cells.Contains(c + new Int3(1, 0, 0)) ? Overlap : 0.0;
                double zm = cells.Contains(c + new Int3(0, 0, -1)) ? Overlap : 0.0;
                double zp = cells.Contains(c + new Int3(0, 0, 1)) ? Overlap : 0.0;
                if (cur != null && cur.Y == c.y && cur.Z == c.z && cur.End == c.x && cur.Xp == 0.0 && xm == 0.0
                    && cur.Zm == zm && cur.Zp == zp && cur.Color.Equals(colour))
                {
                    cur.End = c.x + 1;
                    cur.Xp = xp;
                    continue;
                }
                if (cur != null) rows.Add(cur);
                cur = new Row { Y = c.y, Z = c.z, Start = c.x, End = c.x + 1, Xm = xm, Xp = xp, Zm = zm, Zp = zp, Color = colour };
            }
            if (cur != null) rows.Add(cur);
            // 2. Les bandes voisines en z, de même étendue.
            var rects = new List<Flat>();
            var open = new Dictionary<(int, int, double, double, Col), Flat>();
            foreach (var b in rows)
            {
                double x0 = b.Start - b.Xm;
                double x1 = b.End + b.Xp;
                var key = (b.Y, b.Z, x0, x1, b.Color);
                if (open.TryGetValue(key, out var r))
                {
                    open.Remove(key);
                    r.Z1 = b.Z + 1 + b.Zp;
                }
                else
                {
                    r = new Flat
                    {
                        X0 = x0, X1 = x1, Z0 = b.Z - b.Zm, Z1 = b.Z + 1 + b.Zp,
                        H = !double.IsNaN(forcedH) ? forcedH : b.Y + top, Color = b.Color,
                    };
                    rects.Add(r);
                }
                if (b.Zp == 0.0) open[(b.Y, b.Z + 1, x0, x1, b.Color)] = r;
            }
            return rects;
        }

        sealed class Row
        {
            public int Y, Z, Start, End;
            public double Xm, Xp, Zm, Zp;
            public Col Color;
        }

        /// <summary>The sea beyond the box of the world: four large rectangles around it, without a floor. No world: one.</summary>
        static List<Flat> OffShore(WaterBox b, double h)
        {
            var c = Color(0, 0, Still, 1.0);
            Flat R(double x0, double x1, double z0, double z1) => new Flat { X0 = x0, X1 = x1, Z0 = z0, Z1 = z1, H = h, Color = c };
            if (b.Empty) return new List<Flat> { R(-Horizon, Horizon, -Horizon, Horizon) };
            double bx0 = b.Lo.x, bx1 = b.Hi.x + 1, bz0 = b.Lo.z, bz1 = b.Hi.z + 1;
            return new List<Flat>
            {
                R(-Horizon, Horizon, -Horizon, bz0), R(-Horizon, Horizon, bz1, Horizon), R(-Horizon, bx0, bz0, bz1),
                R(bx1, Horizon, bz0, bz1),
            };
        }

        /// <summary>The cell c at height h, overlapping by Overlap under each full neighbour of its row.</summary>
        static Flat CellFlat(Int3 c, double h, ICollection<Int3> cells, Col colour)
        {
            double xm = cells.Contains(c + new Int3(-1, 0, 0)) ? Overlap : 0.0;
            double xp = cells.Contains(c + new Int3(1, 0, 0)) ? Overlap : 0.0;
            double zm = cells.Contains(c + new Int3(0, 0, -1)) ? Overlap : 0.0;
            double zp = cells.Contains(c + new Int3(0, 0, 1)) ? Overlap : 0.0;
            return new Flat { X0 = c.x - xm, X1 = c.x + 1 + xp, Z0 = c.z - zm, Z1 = c.z + 1 + zp, H = h, Color = colour };
        }

        static readonly Int3[] Sides = { new Int3(-1, 0, 0), new Int3(1, 0, 0), new Int3(0, 0, -1), new Int3(0, 0, 1) };

        // LA BANDE d'une rivière sur la case c (_bande) et ses FLANCS, posés dans `a` aussitôt. Chaque côté, par sa voisine n
        // de la même rangée — PLEINE : la bande déborde de Overlap sous la roche ; EAU de la couche posée sur la matière :
        // rien ; eau au-dessus du VIDE (la lèvre d'une cascade) : Advance ; SÈCHE sur un sol : la bande s'arrête au bord de
        // sa case et descend en flanc sous le sol ; SÈCHE au-dessus du vide : elle s'arrête Thin − r hors de la roche.
        static Flat Band(WaterSheetArrays a, Int3 c, ICollection<Int3> cells, HashSet<Int3> waters, double floor, Col colour)
        {
            double h = c.y + BandHeight(floor);
            double low = c.y - floor - Thin;
            var edges = new double[4];
            var flanks = new List<int>();
            for (int s = 0; s < 4; s++)
            {
                var n = c + Sides[s];
                double e;
                if (cells.Contains(n)) e = Overlap;
                else if (waters.Contains(n)) e = cells.Contains(n + Down) ? 0.0 : Advance(floor);
                else
                {
                    e = cells.Contains(n + Down) ? 0.0 : Thin - floor;
                    flanks.Add(s);
                }
                edges[s] = e;
            }
            var r = new Flat { X0 = c.x - edges[0], X1 = c.x + 1 + edges[1], Z0 = c.z - edges[2], Z1 = c.z + 1 + edges[3], H = h, Color = colour };
            foreach (var s in flanks)
            {
                var d = Sides[s];
                WaterVec3 p0, p1;
                if (d.x != 0)
                {
                    double x = d.x < 0 ? r.X0 : r.X1;
                    p0 = V(x, 0, r.Z0);
                    p1 = V(x, 0, r.Z1);
                }
                else
                {
                    double z = d.z < 0 ? r.Z0 : r.Z1;
                    p0 = V(r.X0, 0, z);
                    p1 = V(r.X1, 0, z);
                }
                double u0 = d.x != 0 ? p0.z : p0.x;
                double u1 = d.x != 0 ? p1.z : p1.x;
                Quad(a, new[] { V(p0.x, h, p0.z), V(p1.x, h, p1.z), V(p1.x, low, p1.z), V(p0.x, low, p0.z) }, V(d.x, d.y, d.z), colour,
                    new[] { u0, h, u1, h, u1, low, u0, low });
            }
            return r;
        }

        /// <summary>A quad (_quad), corners in outline order, normal n: two triangles in the FORMAT's winding, (P0, P1, P2)
        /// and (P0, P2, P3) if (P1 − P0) × (P2 − P0) is on the side of n, else (P0, P2, P1) and (P0, P3, P2).</summary>
        static void Quad(WaterSheetArrays a, WaterVec3[] p, WaterVec3 n, Col c, double[] uv)
        {
            int b = a.Positions.Count;
            for (int k = 0; k < 4; k++) AddVertex(a, p[k], n, c, uv[2 * k], uv[2 * k + 1]);
            // (P1 − P0) × (P2 − P0), en 32 bits comme le Vector3 de Godot.
            double ax = (float)(p[1].x - p[0].x), ay = (float)(p[1].y - p[0].y), az = (float)(p[1].z - p[0].z);
            double bx = (float)(p[2].x - p[0].x), by = (float)(p[2].y - p[0].y), bz = (float)(p[2].z - p[0].z);
            double xx = ay * bz - az * by, xy = az * bx - ax * bz, xz = ax * by - ay * bx;
            if (xx * n.x + xy * n.y + xz * n.z > 0.0)
            {
                a.Triangles.Add(b); a.Triangles.Add(b + 1); a.Triangles.Add(b + 2);
                a.Triangles.Add(b); a.Triangles.Add(b + 2); a.Triangles.Add(b + 3);
            }
            else
            {
                a.Triangles.Add(b); a.Triangles.Add(b + 2); a.Triangles.Add(b + 1);
                a.Triangles.Add(b); a.Triangles.Add(b + 3); a.Triangles.Add(b + 2);
            }
        }

        static bool IsHorizontal(Int3 d) => d.y == 0 && Math.Abs(d.x) + Math.Abs(d.z) == 1;

        /// <summary>The FLOW at step i of a course (horizontal, or zero): towards the next cell if it is beside, else from the
        /// previous one.</summary>
        public static Int3 FlowOf(IList<WaterStep> course, int i)
        {
            var c = course[i].Cell;
            if (i + 1 < course.Count && IsHorizontal(course[i + 1].Cell - c)) return course[i + 1].Cell - c;
            if (i > 0 && IsHorizontal(c - course[i - 1].Cell)) return c - course[i - 1].Cell;
            return new Int3(0, 0, 0);
        }

        // UNE RIVIÈRE (_riviere) : une bande par case du cours qui repose sur la matière (une case, une bande, toutes rivières
        // de la couche réunies) ; une cascade par suite de chutes ; la SOURCE à la première case si elle coule sur la matière.
        static void RiverOf(WaterSheetArrays a, List<WaterStep> course, ICollection<Int3> cells, List<Flat> flats, Seen seen, List<Int3> springs)
        {
            int n = course.Count;
            if (n > 0 && course[0].Kind == "flow" && cells.Contains(course[0].Cell + Down) && !springs.Contains(course[0].Cell))
                springs.Add(course[0].Cell);
            for (int i = 0; i < n; i++)
            {
                var e = course[i];
                var c = e.Cell;
                if (e.Kind == "lake" || !cells.Contains(c + Down) || seen.Bands.Contains(c)) continue;
                var d = FlowOf(course, i);
                seen.Bands.Add(c);
                flats.Add(Band(a, c, cells, seen.Waters, seen.Floor, Color(d.x, d.z, Flowing, BandDepth)));
            }
            int k = 0;
            while (k < n)
            {
                var c = course[k].Cell;
                if (course[k].Kind == "fall")
                {
                    int j = k;
                    while (j < n && course[j].Kind == "fall") j++;
                    var lip = k > 0 ? course[k - 1].Cell : c + Up;
                    var d = new Int3(0, 0, 0);
                    if (k >= 2 && IsHorizontal(lip - course[k - 2].Cell)) d = lip - course[k - 2].Cell;
                    else
                        foreach (var f in Horizontal)
                            if (cells.Contains(c - f)) { d = f; break; }
                    Retain(lip, course[j - 1].Cell, d, cells, seen);
                    k = j;
                }
                else k++;
            }
        }

        // LA CASCADE retenue (_lame), sur le plan de la falaise qu'elle quitte ; deux qui tombent au même endroit n'en font
        // qu'une, de la plus haute lèvre au plus bas pied.
        static void Retain(Int3 lip, Int3 bottom, Int3 d, ICollection<Int3> cells, Seen seen)
        {
            double floor = seen.Floor;
            double top = lip.y + BandHeight(floor);
            double foot = (bottom.y - 1) + SheetHeight(floor);
            double ground = cells.Contains(bottom + Down) ? bottom.y + BandHeight(floor) : foot;
            // Tombée dans un creux qu'elle remplit : le remous est sur la nappe de l'eau dormante qui noie `bottom`.
            foreach (var water in seen.Dormant)
                if (water.Contains(bottom))
                {
                    var h = bottom;
                    while (water.Contains(h + Up)) h += Up;
                    ground = h.y + SheetHeight(floor);
                    foot = Math.Min(foot, ground - 0.15);
                    break;
                }
            int axis = d.x != 0 ? 0 : 2;
            int sense = d.x != 0 ? d.x : d.z;
            int along = axis == 0 ? lip.z : lip.x;
            double plane;
            if (sense == 0)
            {
                axis = 2;
                sense = 1;
                along = lip.x;
                plane = lip.z + 0.5;
            }
            else
            {
                int edge = axis == 0 ? lip.x : lip.z;
                plane = sense > 0 ? edge : edge + 1;
                // La falaise est au plan − r (le sol) : la cascade garde la place qu'elle a devant une roche en retrait.
                plane += Advance(floor) * sense;
            }
            var key = (axis, RoundI(plane * 20.0), along);
            if (!seen.Falls.TryGetValue(key, out var l))
            {
                seen.Falls[key] = new Waterfall
                {
                    Axis = axis, Sense = sense, Plane = plane, Along = along, Top = top, Foot = foot, Ground = ground, D = d,
                };
                seen.FallOrder.Add(key);
            }
            else
            {
                l.Top = Math.Max(l.Top, top);
                l.Foot = Math.Min(l.Foot, foot);
                l.Ground = Math.Min(l.Ground, ground);
            }
        }

        /// <summary>The successive drops of a waterfall sheet (32-bit, as MarchingBlocks keeps them).</summary>
        static List<double> Drops(double total)
        {
            var c = new List<double>();
            foreach (var h in new[] { 0.0, 0.02, 0.06, 0.12, 0.2, 0.3, 0.42, 0.55, Arc })
                if (h < total - 0.01) c.Add((float)h);
            double k = Arc + 0.5;
            while (k < total - 0.2)
            {
                c.Add((float)k);
                k += 0.5;
            }
            c.Add((float)total);
            return c;
        }

        static double Out(double drop) =>
            Sheet * Math.Sqrt(Clamp(drop / Arc, 0.0, 1.0)) + Math.Min(Flare * Math.Max(drop - Arc, 0.0), FlareMax);

        static double Profile(double u, double u0, double u1, bool free0, bool free1)
        {
            double r = 1.0;
            if (free0 && u < u0 + Rounding)
            {
                double t = Clamp((u - u0) / Rounding, 0.0, 1.0);
                r = Math.Min(r, Math.Sqrt(1.0 - (1.0 - t) * (1.0 - t)));
            }
            if (free1 && u > u1 - Rounding)
            {
                double t = Clamp((u1 - u) / Rounding, 0.0, 1.0);
                r = Math.Min(r, Math.Sqrt(1.0 - (1.0 - t) * (1.0 - t)));
            }
            return r;
        }

        static double Before(double r, double drop) => Lerp(-IntoRock * Clamp(drop / 0.15, 0.0, 1.0), Out(drop), r);

        static WaterVec3 PointOf(Waterfall l, double u, double drop)
        {
            double r = l.Straight ? 0.0 : Profile(u, l.U0, l.U1, l.Free0, l.Free1);
            double p = l.Plane + (l.Straight ? 0.0 : Before(r, drop)) * l.Sense;
            double y = l.Top - drop;
            return l.Axis == 0 ? V(p, y, u) : V(u, y, p);
        }

        static WaterVec3 NormalOf(Waterfall l, double u, double drop)
        {
            const double e = 0.01;
            var a = PointOf(l, u + e, drop);
            var b = PointOf(l, u - e, drop);
            var c = PointOf(l, u, drop + e);
            var d = PointOf(l, u, Math.Max(drop - e, 0.0));
            // Les différences de points 32 bits, comme le Vector3 de Godot.
            double tux = (float)(a.x - b.x), tuy = (float)(a.y - b.y), tuz = (float)(a.z - b.z);
            double thx = (float)(c.x - d.x), thy = (float)(c.y - d.y), thz = (float)(c.z - d.z);
            int s = l.Axis == 0 ? -l.Sense : l.Sense;
            double nx = (thy * tuz - thz * tuy) * s, ny = (thz * tux - thx * tuz) * s, nz = (thx * tuy - thy * tux) * s;
            double len = Math.Sqrt(nx * nx + ny * ny + nz * nz);
            if (len < 1e-9) return l.Axis == 0 ? V(l.Sense, 0, 0) : V(0, 0, l.Sense);
            return V(nx / len, ny / len, nz / len);
        }

        // Les cascades retenues : chacune posée tout de suite (opaque), son remous gardé pour la fin (transparent). Un bout
        // sans voisine sur son plan s'arrondit et rentre dans la roche ; un bout qui en a une reste droit.
        static void PlaceWaterfalls(WaterSheetArrays a, Seen seen, List<Grid> foam, List<Flat> flats,
            Dictionary<FallKey, Grid[]> before, Dictionary<FallKey, Grid[]> after)
        {
            foreach (var key in seen.FallOrder)
            {
                var l = seen.Falls[key];
                l.Straight = l.D.x == 0 && l.D.y == 0 && l.D.z == 0;
                l.Free0 = !l.Straight && !seen.Falls.ContainsKey((key.Item1, key.Item2, l.Along - 1));
                l.Free1 = !l.Straight && !seen.Falls.ContainsKey((key.Item1, key.Item2, l.Along + 1));
                var signature = new FallKey(l);
                if (!before.TryGetValue(signature, out var done)) done = Compute(l);
                after[signature] = done;
                Place(a, done[0]);
                // Son haut est sur le bout de la bande qui y arrive : ses sommets y sont insérés (pas de jonction en T).
                flats.Add(new Flat { Points = done[0].TopRow });
                foam.Add(done[1]);
                foam.Add(done[2]);
            }
        }

        /// <summary>A retained waterfall: [its compiled sheet (with its top row), its ring of foam, its spray].</summary>
        static Grid[] Compute(Waterfall l)
        {
            l.U0 = l.Along - (l.Free0 ? Overhang : 0.0);
            l.U1 = l.Along + 1.0 + (l.Free1 ? Overhang : 0.0);
            var us = Across(l);
            double top = l.Top, ground = l.Ground, total = top - l.Foot;
            double fx = l.D.x, fz = l.D.z;
            var g = new RawGrid();
            foreach (var drop in Drops(total))
            {
                var row = g.NewRow();
                foreach (var u in us)
                {
                    var p = PointOf(l, u, drop);
                    double e = Clamp(1.0 - (p.y - ground) / FoamRise, 0.0, 1.0);
                    row.Add(p, NormalOf(l, u, drop), Color(fx, fz, Fall, e * e), u, p.y);
                }
            }
            // LE REMOUS : au pied, là où la nappe traverse l'eau. Chaque point du pied s'écarte selon la normale de la nappe.
            double dropAtGround = Clamp(top - ground, 0.0, total);
            var feet = new List<WaterVec3>();
            var dirs = new List<WaterVec3>();
            foreach (var u in us)
            {
                var p = PointOf(l, u, dropAtGround);
                var n = NormalOf(l, u, dropAtGround);
                double hx = n.x, hz = n.z;
                if (Math.Sqrt(hx * hx + hz * hz) < 0.2)
                {
                    if (l.Axis == 0) { hx = l.Sense; hz = 0; } else { hx = 0; hz = l.Sense; }
                }
                // Le Vector3 normalisé de Godot, en 32 bits.
                float fhx = (float)hx, fhz = (float)hz;
                double len = Math.Sqrt((double)fhx * fhx + (double)fhz * fhz);
                feet.Add(V(p.x, ground, p.z));
                dirs.Add(V(fhx / len, 0, fhz / len));
            }
            var ring = Crown(feet, dirs, us, fx, fz, ground, new[] { 0.0, 0.25, 0.55, Churn }, new[] { 0.0, 0.0, 0.0, 0.0 },
                new[] { 1.0, 0.85, 0.45, 0.0 }, true, null);
            // Les embruns montent DEVANT la nappe seulement : sur les bouts arrondis ils s'effacent.
            var weights = new double[us.Count];
            for (int i = 0; i < us.Count; i++)
                weights[i] = l.Straight ? 1.0 : Math.Pow(Profile(us[i], l.U0, l.U1, l.Free0, l.Free1), 3.0);
            var spray = Crown(feet, dirs, us, fx, fz, ground, new[] { 0.06, 0.16, 0.22, 0.2 }, new[] { 0.0, 0.3, 0.6, Spray },
                new[] { 0.95, 0.7, 0.35, 0.0 }, false, weights);
            var sheet = Compile(g);
            sheet.TopRow = g.Rows.Count > 0 ? new List<WaterVec3>(g.Rows[0].P) : new List<WaterVec3>();
            return new[] { sheet, Compile(ring), Compile(spray) };
        }

        /// <summary>The points across a waterfall: the free ends finely, the cell borders, the middle.</summary>
        static List<double> Across(Waterfall l)
        {
            double u0 = l.U0, u1 = l.U1;
            var us = new List<double>();
            // Des multiples de 0,05 (le haut de la nappe est inséré dans la bande, comparée en vingtièmes).
            foreach (var f in new[] { 0.0, 0.05, 0.1, 0.2, 0.3, Rounding })
            {
                if (l.Free0) us.Add(u0 + f);
                if (l.Free1) us.Add(u1 - f);
            }
            int a = l.Along;
            us.Add(a);
            us.Add(a + 0.5);
            us.Add(a + 1.0);
            us.Sort();
            var kept = new List<double>();
            foreach (var u in us)
            {
                if (u < u0 - 0.001 || u > u1 + 0.001) continue;
                if (kept.Count == 0 || u - kept[kept.Count - 1] > 0.005) kept.Add(u);
            }
            return kept;
        }

        /// <summary>A crown of foam around the foot: row k at offsets[k] from the foot, rises[k] above the water, foam[k]
        /// (× weights[i] when given). flat: the ring laid on the water (normal up, 0.02 above); else the spray, standing.</summary>
        static RawGrid Crown(List<WaterVec3> feet, List<WaterVec3> dirs, List<double> us, double fx, double fz, double ground,
            double[] offsets, double[] rises, double[] foams, bool flat, double[] weights)
        {
            var g = new RawGrid();
            for (int k = 0; k < offsets.Length; k++)
            {
                var row = g.NewRow();
                for (int i = 0; i < us.Count; i++)
                {
                    var f = feet[i];
                    var d = dirs[i];
                    // En 32 bits, comme le Vector3 de Godot : pied + dir × écart + (0, montée, 0).
                    float o = (float)offsets[k];
                    float lift = (float)(rises[k] + (flat ? 0.02 : 0.0));
                    float px = f.x + d.x * o, py = f.y + d.y * o, pz = f.z + d.z * o;
                    py += lift;
                    var p = new WaterVec3(px, py, pz);
                    row.Add(p, flat ? V(0, 1, 0) : d, Color(fx, fz, Foam, foams[k] * (weights != null ? weights[i] : 1.0)),
                        us[i], flat ? ground - offsets[k] * 1.5 : p.y);
                }
            }
            return g;
        }

        // LA SOURCE d'une rivière, sur la bande de la case c : un bouillon d'écume en disque, bombé au centre, et un voile.
        static RawGrid[] SpringOf(Int3 c, double floor)
        {
            float cx = (float)(c.x + 0.5), cy = (float)(c.y + BandHeight(floor)), cz = (float)(c.z + 0.5);
            const int turns = 16;
            var disc = new RawGrid();
            var radii = new[] { 0.0, 0.2, 0.42, Spring };
            var lifts = new[] { SpringDome, SpringDome * 0.7, SpringDome * 0.3, 0.02 };
            var foams = new[] { 1.0, 0.95, 0.6, 0.0 };
            for (int k = 0; k < radii.Length; k++)
            {
                var row = disc.NewRow();
                for (int i = 0; i <= turns; i++)
                {
                    double ang = 2.0 * Math.PI * (i % turns) / turns;
                    float dx = (float)Math.Cos(ang), dz = (float)Math.Sin(ang);
                    float r = (float)radii[k], lift = (float)lifts[k];
                    row.Add(new WaterVec3(cx + dx * r, cy + lift, cz + dz * r), V(0, 1, 0), Color(0, 0, Foam, foams[k]),
                        ang * 0.6, cy - radii[k] * 1.5);
                }
            }
            var veil = new RawGrid();
            var vr = new[] { 0.12, 0.2, 0.24 };
            var vh = new[] { 0.02, 0.18, 0.34 };
            var vf = new[] { 0.8, 0.45, 0.0 };
            for (int k = 0; k < 3; k++)
            {
                var row = veil.NewRow();
                for (int i = 0; i <= turns; i++)
                {
                    double ang = 2.0 * Math.PI * (i % turns) / turns;
                    float dx = (float)Math.Cos(ang), dz = (float)Math.Sin(ang);
                    float r = (float)vr[k], h = (float)vh[k];
                    row.Add(new WaterVec3(cx + dx * r, cy + h, cz + dz * r), new WaterVec3(dx, 0, dz), Color(0, 0, Foam, vf[k]),
                        ang * 0.6, cy + vh[k]);
                }
            }
            return new[] { disc, veil };
        }

        // ── grids ───────────────────────────────────────────────────────────────────────────────────────────────────

        sealed class RawRow
        {
            public readonly List<WaterVec3> P = new List<WaterVec3>(), N = new List<WaterVec3>();
            public readonly List<Col> C = new List<Col>();
            public readonly List<double> U = new List<double>(), W = new List<double>();
            public void Add(WaterVec3 p, WaterVec3 n, Col c, double u, double v)
            {
                P.Add(p); N.Add(n); C.Add(c); U.Add((float)u); W.Add((float)v);
            }
        }

        sealed class RawGrid
        {
            public readonly List<RawRow> Rows = new List<RawRow>();
            public RawRow NewRow() { var r = new RawRow(); Rows.Add(r); return r; }
        }

        /// <summary>A grid in triangles (_grille_compilee): each quad (i, j) gives (k0, k1, k2) and (k0, k2, k3); a triangle
        /// without area is dropped; each is turned after the normal of its FIRST corner; unused vertices are removed.</summary>
        static Grid Compile(RawGrid g)
        {
            var grid = new Grid();
            int nr = g.Rows.Count;
            if (nr < 2) return grid;
            int nc = g.Rows[0].P.Count;
            var v = new WaterVec3[nr * nc];
            var ns = new WaterVec3[nr * nc];
            var cs = new Col[nr * nc];
            var us = new double[nr * nc];
            var ws = new double[nr * nc];
            for (int i = 0; i < nr; i++)
                for (int j = 0; j < nc; j++)
                {
                    int k = i * nc + j;
                    var row = g.Rows[i];
                    v[k] = row.P[j]; ns[k] = row.N[j]; cs[k] = row.C[j]; us[k] = row.U[j]; ws[k] = row.W[j];
                }
            var idx = new List<int>();
            var t = new int[3];
            for (int i = 0; i < nr - 1; i++)
                for (int j = 0; j < nc - 1; j++)
                {
                    int k0 = i * nc + j, k1 = i * nc + j + 1, k2 = (i + 1) * nc + j + 1, k3 = (i + 1) * nc + j;
                    for (int s = 0; s < 2; s++)
                    {
                        int a0 = k0, a1 = s == 0 ? k1 : k2, a2 = s == 0 ? k2 : k3;
                        // (v1 − v0) × (v2 − v0), en 32 bits comme le Vector3 de Godot.
                        double ax = (float)(v[a1].x - v[a0].x), ay = (float)(v[a1].y - v[a0].y), az = (float)(v[a1].z - v[a0].z);
                        double bx = (float)(v[a2].x - v[a0].x), by = (float)(v[a2].y - v[a0].y), bz = (float)(v[a2].z - v[a0].z);
                        double xx = ay * bz - az * by, xy = az * bx - ax * bz, xz = ax * by - ay * bx;
                        if (Math.Sqrt(xx * xx + xy * xy + xz * xz) < 1e-7) continue;
                        // Tourné d'après la normale de son PREMIER sommet.
                        if (xx * ns[a0].x + xy * ns[a0].y + xz * ns[a0].z > 0.0) { idx.Add(a0); idx.Add(a2); idx.Add(a1); }
                        else { idx.Add(a0); idx.Add(a1); idx.Add(a2); }
                    }
                }
            // Les sommets qu'aucun triangle n'emploie sont retirés (le centre d'un disque).
            var renum = new int[v.Length];
            for (int i = 0; i < renum.Length; i++) renum[i] = -1;
            foreach (var i in idx) renum[i] = 0;
            int kept = 0;
            for (int i = 0; i < renum.Length; i++) if (renum[i] == 0) renum[i] = kept++;
            grid.V = new WaterVec3[kept]; grid.N = new WaterVec3[kept]; grid.C = new Col[kept];
            grid.U = new double[kept]; grid.W = new double[kept];
            for (int i = 0; i < renum.Length; i++)
                if (renum[i] >= 0)
                {
                    int k = renum[i];
                    grid.V[k] = v[i]; grid.N[k] = ns[i]; grid.C[k] = cs[i]; grid.U[k] = us[i]; grid.W[k] = ws[i];
                }
            grid.I = new int[idx.Count];
            for (int i = 0; i < idx.Count; i++) grid.I[i] = renum[idx[i]];
            return grid;
        }

        /// <summary>Lays a compiled grid into the arrays, in the format's winding (MarchingBlocks' order reversed).</summary>
        static void Place(WaterSheetArrays a, Grid g)
        {
            int b = a.Positions.Count;
            for (int k = 0; k < g.V.Length; k++) AddVertex(a, g.V[k], g.N[k], g.C[k], g.U[k], g.W[k]);
            for (int t = 0; t < g.I.Length; t += 3)
            {
                a.Triangles.Add(b + g.I[t]);
                a.Triangles.Add(b + g.I[t + 2]);
                a.Triangles.Add(b + g.I[t + 1]);
            }
        }

        static void AddVertex(WaterSheetArrays a, WaterVec3 p, WaterVec3 n, Col c, double u, double v)
        {
            a.Positions.Add(p);
            a.Normals.Add(n);
            a.Colors.Add(c.r); a.Colors.Add(c.g); a.Colors.Add(c.b); a.Colors.Add(c.a);
            a.UVs.Add((float)u); a.UVs.Add((float)v);
        }

        // ── LES PLATS SANS JONCTION EN T (_poser_les_plats) ───────────────────────────────────────────────────────────
        // Chaque rectangle horizontal ; un sommet d'un AUTRE rectangle de même hauteur posé sur l'un de ses côtés y est
        // inséré, et le rectangle est alors dessiné en éventail autour de son centre. Comparé en vingtièmes, exactement.
        static void PlaceFlats(WaterSheetArrays a, List<Flat> flats)
        {
            var setZ = new Dictionary<(int, int), HashSet<int>>();   // (h, z) → x des sommets sur cette ligne
            var setX = new Dictionary<(int, int), HashSet<int>>();   // (h, x) → z
            foreach (var r in flats)
            {
                if (r.Points != null)
                {
                    foreach (var q in r.Points)
                    {
                        Note(setZ, (K(q.y), K(q.z)), K(q.x));
                        Note(setX, (K(q.y), K(q.x)), K(q.z));
                    }
                    continue;
                }
                int hk = K(r.H);
                foreach (var x in new[] { r.X0, r.X1 })
                    foreach (var z in new[] { r.Z0, r.Z1 })
                    {
                        Note(setZ, (hk, K(z)), K(x));
                        Note(setX, (hk, K(x)), K(z));
                    }
            }
            var onZ = Sorted(setZ);
            var onX = Sorted(setX);
            var outline = new List<(int, int)>();
            foreach (var r in flats)
            {
                if (r.Points != null) continue;
                int hk = K(r.H), x0 = K(r.X0), x1 = K(r.X1), z0 = K(r.Z0), z1 = K(r.Z1);
                // Le tour, dans un sens fixe : (x0,z0) → (x1,z0) → (x1,z1) → (x0,z1).
                outline.Clear();
                outline.Add((x0, z0));
                foreach (var x in Between(onZ, (hk, z0), x0, x1)) outline.Add((x, z0));
                outline.Add((x1, z0));
                foreach (var z in Between(onX, (hk, x1), z0, z1)) outline.Add((x1, z));
                outline.Add((x1, z1));
                var back = Between(onZ, (hk, z1), x0, x1);
                for (int i = back.Count - 1; i >= 0; i--) outline.Add((back[i], z1));
                outline.Add((x0, z1));
                var up = Between(onX, (hk, x0), z0, z1);
                for (int i = up.Count - 1; i >= 0; i--) outline.Add((x0, up[i]));
                double h = r.H;
                var c = r.Color;
                var nUp = V(0, 1, 0);
                int b = a.Positions.Count;
                if (outline.Count == 4)
                {
                    // Deux triangles (P0, P2, P1) et (P0, P3, P2), dans le sens du format.
                    AddVertex(a, V(r.X0, h, r.Z0), nUp, c, r.X0, r.Z0);
                    AddVertex(a, V(r.X1, h, r.Z0), nUp, c, r.X1, r.Z0);
                    AddVertex(a, V(r.X1, h, r.Z1), nUp, c, r.X1, r.Z1);
                    AddVertex(a, V(r.X0, h, r.Z1), nUp, c, r.X0, r.Z1);
                    a.Triangles.Add(b); a.Triangles.Add(b + 2); a.Triangles.Add(b + 1);
                    a.Triangles.Add(b); a.Triangles.Add(b + 3); a.Triangles.Add(b + 2);
                    continue;
                }
                var centre = V((r.X0 + r.X1) * 0.5, h, (r.Z0 + r.Z1) * 0.5);
                AddVertex(a, centre, nUp, c, centre.x, centre.z);
                foreach (var t in outline)
                {
                    var p = V(t.Item1 / 20.0, h, t.Item2 / 20.0);
                    AddVertex(a, p, nUp, c, p.x, p.z);
                }
                int n = outline.Count;
                // L'éventail (C, P(k+1), P(k)) dans le sens du format.
                for (int k = 0; k < n; k++)
                {
                    a.Triangles.Add(b);
                    a.Triangles.Add(b + 1 + (k + 1) % n);
                    a.Triangles.Add(b + 1 + k);
                }
            }
        }

        static void Note(Dictionary<(int, int), HashSet<int>> d, (int, int) key, int v)
        {
            if (!d.TryGetValue(key, out var l)) d[key] = l = new HashSet<int>();
            l.Add(v);
        }

        static Dictionary<(int, int), List<int>> Sorted(Dictionary<(int, int), HashSet<int>> d)
        {
            var o = new Dictionary<(int, int), List<int>>(d.Count);
            foreach (var kv in d)
            {
                var l = new List<int>(kv.Value);
                l.Sort();
                o[kv.Key] = l;
            }
            return o;
        }

        /// <summary>The sorted values of the line strictly between a and b.</summary>
        static List<int> Between(Dictionary<(int, int), List<int>> d, (int, int) key, int a, int b)
        {
            var o = new List<int>();
            if (!d.TryGetValue(key, out var l)) return o;
            // bsearch(a, false) : le premier strictement après a.
            int lo = 0, hi = l.Count;
            while (lo < hi)
            {
                int m = (lo + hi) >> 1;
                if (l[m] <= a) lo = m + 1; else hi = m;
            }
            for (int i = lo; i < l.Count && l[i] < b; i++) o.Add(l[i]);
            return o;
        }
    }
}
