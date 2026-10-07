// MarchingBlocks Paint for Unity — THE WATER RULE: where water goes, deduced from its sources and the cells.
//
// Water never changes cells. It is DEDUCED from the sources and the cells of EVERY tile layer (hidden ones too), and
// again after every change. Three cases, one question — "where can the water go?":
//   - a SEA: the source has nothing full below it in its column. Every empty cell joined to the horizon without going
//     above the source's level (a cavity fills only through a duct open below the level). ONE sea only.
//   - a LAKE: fallen to the ground, the water finds no cell to fall from at its floor — a hollow. It fills by priority
//     flood up to its threshold. A lake whose threshold has, flat, a fall or other water within OverflowReach cells
//     overflows: it is the first lake of a river.
//   - a RIVER: the shortest flat path to a cell it can fall from, the fall, and again; it ends leaving the box
//     ("leaves"), joining other water ("joins"), or in a hollow without way out ("closed").
//
// Neighbours are always visited in the order +x, −x, +z, −z, down, up; the heap is tied by insertion order. The BOX is
// the box of the full cells grown by one; its sides and its bottom (not its top) are the HORIZON.
//
// Like MBRule.cs, this file has no Unity dependency: Tests/water_conformance.json (computed by the MarchingBlocks tool,
// fluides.gd) proves it behaves exactly like the tool. Everything is in FORMAT space (cell c covers [c, c+1], +Y up).

using System;
using System.Collections.Generic;

namespace MarchingBlocks.Paint
{
    /// <summary>One lake: its level (the highest row of water cells) and its cells.</summary>
    public sealed class WaterLake
    {
        public int Level;
        public HashSet<Int3> Cells = new HashSet<Int3>();
    }

    /// <summary>One step of a river: a flat cell ("flow"), a falling cell ("fall"), or the entry into lake Lake ("lake").</summary>
    public struct WaterStep
    {
        public Int3 Cell;
        /// <summary>"flow", "fall" or "lake".</summary>
        public string Kind;
        /// <summary>The index of the lake (in WaterBody.Lakes) for a "lake" step; −1 otherwise.</summary>
        public int Lake;
    }

    /// <summary>What one source becomes.</summary>
    public sealed class WaterBody
    {
        /// <summary>"sea", "lake", "river", or "" when the source is refused.</summary>
        public string Kind = "";
        /// <summary>"" or in_matter, in_water, too_large, too_long, one_sea_only.</summary>
        public string Error = "";
        /// <summary>A sea's or a lake's level (the highest row of water cells); 0 otherwise.</summary>
        public int Level;
        /// <summary>A river: "leaves", "joins" or "closed"; a lake: "closed" in a closed cavity; "" otherwise.</summary>
        public string End = "";
        /// <summary>All the water of this source: a sea's cells, a lake's cells, a river's LAKES' cells.</summary>
        public HashSet<Int3> Water = new HashSet<Int3>();
        public List<WaterLake> Lakes = new List<WaterLake>();
        public List<WaterStep> Course = new List<WaterStep>();
        /// <summary>THE FOOTPRINT (fluides.gd, `emprise`): the box of every cell this source looked at, grown by one. A cell
        /// changed OUTSIDE it, the box of the world unchanged where it looked and the sea taken again, cannot change what
        /// the source becomes: MBWater.World takes the SAME object again. False: never taken again (an error, a sea without
        /// a world).</summary>
        public bool HasFootprint;
        public Int3 FootprintLo, FootprintHi;
        /// <summary>The box of the world when this body was computed.</summary>
        public WaterBox SeenBox;
    }

    /// <summary>The water of a whole world: one body per source, in the order given, and the sea's cells.</summary>
    public sealed class WaterWorld
    {
        public List<WaterBody> Bodies = new List<WaterBody>();
        public HashSet<Int3> Sea = new HashSet<Int3>();
        /// <summary>The sources, in the order given (what a later World(…, before, changed) reads).</summary>
        public List<Int3> Sources = new List<Int3>();
        /// <summary>The box of the world (the full cells grown by one).</summary>
        public WaterBox Box;
    }

    /// <summary>A water layer of world.json.</summary>
    public sealed class WaterLayer
    {
        public string Name;
        public bool Visible;
        /// <summary>A SUGGESTION: stylized, clear, reflective, lava, swamp, acid — an unknown look is accepted.</summary>
        public string Look;
        /// <summary>The baked water mesh (.glb), RELATIVE to world.json, or null.</summary>
        public string Mesh;
        public List<Int3> Sources = new List<Int3>();
    }

    public sealed class WaterFileResult
    {
        /// <summary>"" when the key was read; otherwise why it was refused (and Layers is empty).</summary>
        public string Error = "";
        public List<WaterLayer> Layers = new List<WaterLayer>();
        public bool Ok => Error == "";
    }

    /// <summary>The box of the world: the box of the full cells grown by one. Its sides and its bottom (not its top) are
    /// the horizon.</summary>
    public struct WaterBox : IEquatable<WaterBox>
    {
        public bool Empty;
        public Int3 Lo, Hi;
        public bool Horizon(Int3 c) => c.x == Lo.x || c.y == Lo.y || c.z == Lo.z || c.x == Hi.x || c.z == Hi.z;
        public bool Equals(WaterBox o) => Empty == o.Empty && (Empty || (Lo.Equals(o.Lo) && Hi.Equals(o.Hi)));
        public override bool Equals(object o) => o is WaterBox b && Equals(b);
        public override int GetHashCode() => Empty ? 0 : Lo.GetHashCode() ^ (Hi.GetHashCode() * 7);
    }

    public static class MBWater
    {
        /// <summary>A lake (or the lake of a river) of more cells is refused (too_large). Never the sea.</summary>
        public const int VolumeMax = 64 * 64 * 64;
        /// <summary>A river of more steps is refused (too_long).</summary>
        public const int StepsMax = 4096;
        /// <summary>A lake overflows when a fall is at most this many cells flat from its threshold.</summary>
        public const int OverflowReach = 4;

        static readonly Int3[] Horizontal = { new Int3(1, 0, 0), new Int3(-1, 0, 0), new Int3(0, 0, 1), new Int3(0, 0, -1) };
        static readonly Int3[] Neighbours =
        {
            new Int3(1, 0, 0), new Int3(-1, 0, 0), new Int3(0, 0, 1), new Int3(0, 0, -1), new Int3(0, -1, 0), new Int3(0, 1, 0),
        };
        static readonly Int3 Down = new Int3(0, -1, 0);
        static readonly Int3 Up = new Int3(0, 1, 0);

        /// <summary>THE BOX of the world: the box of the full cells grown by one cell (empty world: Empty).</summary>
        public static WaterBox BoxOf(ICollection<Int3> cells)
        {
            if (cells.Count == 0) return new WaterBox { Empty = true };
            int x0 = int.MaxValue, y0 = int.MaxValue, z0 = int.MaxValue, x1 = int.MinValue, y1 = int.MinValue, z1 = int.MinValue;
            foreach (var c in cells)
            {
                x0 = Math.Min(x0, c.x); y0 = Math.Min(y0, c.y); z0 = Math.Min(z0, c.z);
                x1 = Math.Max(x1, c.x); y1 = Math.Max(y1, c.y); z1 = Math.Max(z1, c.z);
            }
            return new WaterBox { Lo = new Int3(x0 - 1, y0 - 1, z0 - 1), Hi = new Int3(x1 + 1, y1 + 1, z1 + 1) };
        }

        /// <summary>Is the source in the VOID — nothing full below it in its column (down to the bottom of the box)?</summary>
        public static bool InTheVoid(ICollection<Int3> cells, Int3 source) => InTheVoid(cells, source, BoxOf(cells));

        static bool InTheVoid(ICollection<Int3> cells, Int3 source, WaterBox b)
        {
            if (b.Empty) return true;
            var c = source;
            while (c.y > b.Lo.y)
            {
                c += Down;
                if (cells.Contains(c)) return false;
            }
            return true;
        }

        /// <summary>THE WATER OF A WORLD: the sea first (the first source in the void, in source order — any other source in
        /// the void is refused, one_sea_only), then every other source against the sea only (their order does not
        /// matter).</summary>
        public static WaterWorld World(ICollection<Int3> cells, IList<Int3> sources) => World(cells, sources, null, null);

        /// <summary>THE SAME, TAKING AGAIN what has not changed (fluides.gd `monde` with `avant` and `changees` — the reprise
        /// of MarchingBlocks): <paramref name="before"/> a previous result, <paramref name="changed"/> the full cells added or
        /// removed since. A source whose FOOTPRINT holds no changed cell, under a box of the world unchanged where it looked,
        /// is taken again AS IS (the same WaterBody object: the mesher keeps its sheet); a source that is not the sea also
        /// needs the sea to be taken again. <paramref name="changed"/> null: everything is computed. The result is the
        /// same as a whole computation (the bench checks it on random gestures).</summary>
        public static WaterWorld World(ICollection<Int3> cells, IList<Int3> sources, WaterWorld before, ICollection<Int3> changed,
            WaterBox? box = null)
        {
            var b = box ?? BoxOf(cells);
            var bodies = new WaterBody[sources.Count];
            var old = new Dictionary<Int3, WaterBody>();
            if (changed != null && before != null)
                for (int i = 0; i < before.Sources.Count && i < before.Bodies.Count; i++) old[before.Sources[i]] = before.Bodies[i];
            WaterBody TakeAgain(Int3 s)
            {
                if (!old.TryGetValue(s, out var r) || r == null || r.Error != "" || !r.HasFootprint || !BoxCompatible(r, b))
                    return null;
                foreach (var c in changed)
                    if (c.x >= r.FootprintLo.x && c.y >= r.FootprintLo.y && c.z >= r.FootprintLo.z
                        && c.x <= r.FootprintHi.x && c.y <= r.FootprintHi.y && c.z <= r.FootprintHi.z)
                        return null;
                return r;
            }
            int seas = 0;
            bool seaTaken = true;
            for (int i = 0; i < sources.Count; i++)
            {
                var s = sources[i];
                if (cells.Contains(s) || !InTheVoid(cells, s, b)) continue;
                // UN SEUL OCÉAN : le premier dans l'ordre des sources ; un autre est refusé.
                if (seas > 0) { bodies[i] = new WaterBody { Error = "one_sea_only" }; continue; }
                seas++;
                var r = TakeAgain(s);
                if (r == null || r.Kind != "sea")
                {
                    seaTaken = false;
                    r = Source(cells, s, new HashSet<Int3>(), b);
                }
                bodies[i] = r;
            }
            // La mer reprise, et aucune de perdue : son eau aussi.
            int seasBefore = 0;
            if (before != null) foreach (var r in before.Bodies) if (r != null && r.Kind == "sea") seasBefore++;
            seaTaken = seaTaken && old.Count > 0 && seas == seasBefore;
            var w = new WaterWorld { Box = b };
            w.Sources.AddRange(sources);
            if (seaTaken) w.Sea = before.Sea;
            else
            {
                // UN SEUL OCÉAN : son eau EST l'eau de mer, partagée (jamais recopiée).
                WaterBody only = null;
                int carrying = 0;
                foreach (var r in bodies)
                    if (r != null && r.Water.Count > 0) { only = r; carrying++; }
                if (carrying == 1) w.Sea = only.Water;
                else foreach (var r in bodies) if (r != null) foreach (var c in r.Water) w.Sea.Add(c);
            }
            for (int i = 0; i < sources.Count; i++)
                if (bodies[i] == null)
                {
                    var r = seaTaken ? TakeAgain(sources[i]) : null;
                    if (r == null || r.Kind == "sea") r = Source(cells, sources[i], w.Sea, b);
                    bodies[i] = r;
                }
            w.Bodies.AddRange(bodies);
            return w;
        }

        /// <summary>Has the box of the world changed WHERE the source looked? Each face that moved must stay outside the
        /// footprint, at its old place and at its new one.</summary>
        static bool BoxCompatible(WaterBody r, WaterBox b)
        {
            var rb = r.SeenBox;
            if (rb.Empty || b.Empty) return rb.Empty && b.Empty;
            int[] elo = { r.FootprintLo.x, r.FootprintLo.y, r.FootprintLo.z }, ehi = { r.FootprintHi.x, r.FootprintHi.y, r.FootprintHi.z };
            int[] alo = { rb.Lo.x, rb.Lo.y, rb.Lo.z }, ahi = { rb.Hi.x, rb.Hi.y, rb.Hi.z };
            int[] nlo = { b.Lo.x, b.Lo.y, b.Lo.z }, nhi = { b.Hi.x, b.Hi.y, b.Hi.z };
            for (int k = 0; k < 3; k++)
            {
                if (alo[k] != nlo[k] && elo[k] <= Math.Max(alo[k], nlo[k])) return false;
                if (ahi[k] != nhi[k] && ehi[k] >= Math.Min(ahi[k], nhi[k])) return false;
            }
            return true;
        }

        /// <summary>The full cells added or removed between two states of the world.</summary>
        public static HashSet<Int3> ChangedBetween(ICollection<Int3> before, ICollection<Int3> after)
        {
            var d = new HashSet<Int3>();
            foreach (var c in after) if (!before.Contains(c)) d.Add(c);
            foreach (var c in before) if (!after.Contains(c)) d.Add(c);
            return d;
        }

        /// <summary>ONE source, against the water already there (<paramref name="water"/>: the sea, which it may join).</summary>
        public static WaterBody Source(ICollection<Int3> cells, Int3 s, ICollection<Int3> water) =>
            Source(cells, s, water, BoxOf(cells));

        static WaterBody Source(ICollection<Int3> cells, Int3 s, ICollection<Int3> water, WaterBox b)
        {
            var r = new WaterBody();
            if (cells.Contains(s)) { r.Error = "in_matter"; return r; }
            if (water.Contains(s)) { r.Error = "in_water"; return r; }
            if (InTheVoid(cells, s, b))
            {
                r.Kind = "sea";
                r.Level = s.y;
                r.Water = Sea(cells, s.y, b);
                // La mer dépend de toute la boîte sous son niveau, et de la rangée du dessus (sa surface).
                r.SeenBox = b;
                if (!b.Empty)
                {
                    r.HasFootprint = true;
                    r.FootprintLo = b.Lo;
                    r.FootprintHi = new Int3(b.Hi.x, s.y + 1, b.Hi.z);
                }
                return r;
            }
            var lakeCells = new HashSet<Int3>();
            Int3 lo = s, hi = s;
            // Le clic au-dessus du sol : on descend jusqu'à lui, sans rien noter (borné au fond de la boîte).
            var c = s;
            while (!cells.Contains(c + Down) && c.y > b.Lo.y)
            {
                c += Down;
                if (water.Contains(c)) { r.Error = "in_water"; return r; }
            }
            var course = new List<WaterStep>();
            var lakes = new List<WaterLake>();
            ICollection<Int3> ignore = new HashSet<Int3>();
            bool first = true;
            int steps = 0;
            while (true)
            {
                steps++;
                if (steps > StepsMax || course.Count > StepsMax) return Refuse(r, "too_long");
                var flat = Flat(cells, b, water, lakeCells, c, ignore, VolumeMax);
                if (flat.Error != null) return Refuse(r, flat.Error);
                Extend(ref lo, ref hi, flat.Seen.Keys);
                if (flat.Hollow)
                {
                    var hollow = Hollow(cells, b, water, lakeCells, c, s.y, VolumeMax);
                    if (hollow.Seen != null) Extend(ref lo, ref hi, hollow.Seen);
                    if (hollow.Error != null) return Refuse(r, hollow.Error);
                    lakes.Add(new WaterLake { Level = hollow.Level, Cells = hollow.Cells });
                    foreach (var k in hollow.Cells) lakeCells.Add(k);
                    if (first && !(hollow.Way == "leaves"
                        && FallNear(cells, b, water, lakeCells, hollow.Threshold, hollow.Cells, ref lo, ref hi)))
                    {
                        r.Kind = "lake";
                        r.Level = hollow.Level;
                        r.End = hollow.Way == "closed" ? "closed" : "";
                        break;
                    }
                    // Le lac déborde (une chute proche de son seuil) : il est le premier lac d'une rivière.
                    first = false;
                    r.Kind = "river";
                    course.Add(new WaterStep { Cell = c, Kind = "lake", Lake = lakes.Count - 1 });
                    if (hollow.Way == "closed") { r.End = "closed"; break; }
                    // Un lac qui touche une autre eau à son seuil s'y déverse directement.
                    var t = hollow.Threshold.Value;
                    if (water.Contains(t) || lakeCells.Contains(t)) { r.End = "joins"; break; }
                    c = t;
                    ignore = hollow.Cells;
                    continue;
                }
                first = false;
                r.Kind = "river";
                foreach (var k in flat.Path)
                    if (course.Count == 0 || !course[course.Count - 1].Cell.Equals(k))
                        course.Add(new WaterStep { Cell = k, Kind = "flow", Lake = -1 });
                if (flat.End != "") { r.End = flat.End; break; }
                ignore = new HashSet<Int3>();
                // La chute : jusqu'au sol, à une eau, ou hors du monde (par le FOND seulement).
                var u = flat.Path[flat.Path.Count - 1];
                string end = "";
                while (true)
                {
                    var v = u + Down;
                    if (water.Contains(v) || lakeCells.Contains(v)) { end = "joins"; break; }
                    if (cells.Contains(v)) break;
                    course.Add(new WaterStep { Cell = v, Kind = "fall", Lake = -1 });
                    Extend(ref lo, ref hi, v);
                    u = v;
                    if (v.y == b.Lo.y) { end = "leaves"; break; }
                }
                if (end != "") { r.End = end; break; }
                c = u;
            }
            r.Course = course;
            r.Lakes = lakes;
            r.Water = lakeCells;
            Extend(ref lo, ref hi, c);
            r.HasFootprint = true;
            r.FootprintLo = lo - new Int3(1, 1, 1);
            r.FootprintHi = hi + new Int3(1, 1, 1);
            r.SeenBox = b;
            return r;
        }

        static void Extend(ref Int3 lo, ref Int3 hi, Int3 k)
        {
            lo = new Int3(Math.Min(lo.x, k.x), Math.Min(lo.y, k.y), Math.Min(lo.z, k.z));
            hi = new Int3(Math.Max(hi.x, k.x), Math.Max(hi.y, k.y), Math.Max(hi.z, k.z));
        }

        static void Extend(ref Int3 lo, ref Int3 hi, IEnumerable<Int3> cells)
        {
            foreach (var k in cells) Extend(ref lo, ref hi, k);
        }

        static WaterBody Refuse(WaterBody r, string error)
        {
            r.Kind = "";
            r.Error = error;
            r.Water = new HashSet<Int3>();
            r.Lakes = new List<WaterLake>();
            r.Course = new List<WaterStep>();
            r.End = "";
            return r;
        }

        /// <summary>THE SEA at a level: every empty cell of the box, at most at that level, joined by faces to the horizon.
        /// Never refused for its size.</summary>
        public static HashSet<Int3> Sea(ICollection<Int3> cells, int level) => Sea(cells, level, BoxOf(cells));

        static HashSet<Int3> Sea(ICollection<Int3> cells, int level, WaterBox b)
        {
            var water = new HashSet<Int3>();
            if (b.Empty || level < b.Lo.y) return water;
            int top = Math.Min(level, b.Hi.y);
            // Par tronçons de colonne : un intervalle vertical de cases vides sous le niveau. Le tronçon du bas de chaque
            // colonne touche le fond (l'horizon) ; les autres sont de la mer s'ils touchent, par une face, un tronçon de mer
            // d'une colonne voisine.
            var full = new Dictionary<(int, int), List<int>>();
            foreach (var c in cells)
                if (c.y <= top)
                {
                    if (!full.TryGetValue((c.x, c.z), out var ys)) full[(c.x, c.z)] = ys = new List<int>();
                    ys.Add(c.y);
                }
            var tx = new List<int>(); var tz = new List<int>(); var t0 = new List<int>(); var t1 = new List<int>();
            var start = new Dictionary<(int, int), (int, int)>();
            for (int x = b.Lo.x; x <= b.Hi.x; x++)
                for (int z = b.Lo.z; z <= b.Hi.z; z++)
                {
                    int firstSegment = t0.Count;
                    int y = b.Lo.y;
                    if (full.TryGetValue((x, z), out var ys))
                    {
                        ys.Sort();
                        foreach (var f in ys)
                        {
                            if (f > y) { tx.Add(x); tz.Add(z); t0.Add(y); t1.Add(f - 1); }
                            y = f + 1;
                        }
                    }
                    if (y <= top) { tx.Add(x); tz.Add(z); t0.Add(y); t1.Add(top); }
                    start[(x, z)] = (firstSegment, t0.Count - firstSegment);
                }
            var inside = new bool[t0.Count];
            var queue = new List<int>();
            for (int i = 0; i < t0.Count; i++)
                if (t0[i] == b.Lo.y) { inside[i] = true; queue.Add(i); }
            for (int n = 0; n < queue.Count; n++)
            {
                int i = queue[n];
                foreach (var f in Horizontal)
                {
                    if (!start.TryGetValue((tx[i] + f.x, tz[i] + f.z), out var se)) continue;
                    for (int j = se.Item1; j < se.Item1 + se.Item2; j++)
                        if (!inside[j] && t0[j] <= t1[i] && t1[j] >= t0[i]) { inside[j] = true; queue.Add(j); }
                }
            }
            foreach (int i in queue)
                for (int y = t0[i]; y <= t1[i]; y++) water.Add(new Int3(tx[i], y, tz[i]));
            return water;
        }

        // ── le tas : une clé de 64 bits (priorité décalée dans les 32 bits hauts, ordre d'insertion dans les bas) ──

        const long Bias = 1L << 20;

        static long Key(int priority, int order) => ((priority + Bias) << 32) | (uint)order;

        static void Push(List<long> heap, long key)
        {
            heap.Add(key);
            int i = heap.Count - 1;
            while (i > 0)
            {
                int p = (i - 1) >> 1;
                if (heap[i] >= heap[p]) break;
                (heap[i], heap[p]) = (heap[p], heap[i]);
                i = p;
            }
        }

        static long Pop(List<long> heap)
        {
            long top = heap[0];
            int n = heap.Count - 1;
            heap[0] = heap[n];
            heap.RemoveAt(n);
            int i = 0;
            while (true)
            {
                int g = 2 * i + 1;
                if (g >= n) break;
                int m = g;
                if (g + 1 < n && heap[g + 1] < heap[g]) m = g + 1;
                if (heap[m] >= heap[i]) break;
                (heap[i], heap[m]) = (heap[m], heap[i]);
                i = m;
            }
            return top;
        }

        sealed class HollowResult
        {
            public string Error;
            public int Level;
            public HashSet<Int3> Cells = new HashSet<Int3>();
            public Int3? Threshold;
            /// <summary>"leaves", "joins" or "closed".</summary>
            public string Way;
            /// <summary>Every cell visited (the footprint); null on an error.</summary>
            public HashSet<Int3> Seen;
        }

        // LE CREUX : remplissage par priorité depuis c ; l'eau déjà là (fixe, lacs) fait office d'issue. Sans issue (cavité
        // close), le lac monte jusqu'à `ceiling`.
        static HollowResult Hollow(ICollection<Int3> cells, WaterBox b, ICollection<Int3> fixedWater, ICollection<Int3> lakes,
            Int3 c, int ceiling, int max)
        {
            var heap = new List<long>();
            var entries = new List<Int3> { c };
            var seen = new HashSet<Int3> { c };
            var pred = new Dictionary<Int3, Int3>();
            var prio = new Dictionary<Int3, int> { [c] = c.y };
            Push(heap, Key(c.y, 0));
            var out_ = new List<Int3>();
            while (heap.Count > 0)
            {
                long k = Pop(heap);
                int p = (int)((k >> 32) - Bias);
                var u = entries[(int)(k & 0xFFFFFFFFL)];
                bool isWater = fixedWater.Contains(u) || lakes.Contains(u);
                if (isWater || b.Horizon(u))
                {
                    // L'issue : tout ce qui est sorti sous P est le lac.
                    var r = new HollowResult { Level = p - 1, Way = isWater ? "joins" : "leaves", Seen = seen };
                    foreach (var s in out_) if (prio[s] < p) r.Cells.Add(s);
                    // Le seuil : la première case du chemin dont la priorité atteint P.
                    var path = new List<Int3>();
                    Int3 w = u;
                    while (true)
                    {
                        path.Insert(0, w);
                        if (!pred.TryGetValue(w, out var before)) break;
                        w = before;
                    }
                    foreach (var s in path) if (prio[s] >= p) { r.Threshold = s; break; }
                    return r;
                }
                out_.Add(u);
                if (out_.Count > max) return new HollowResult { Error = "too_large" };
                foreach (var f in Neighbours)
                {
                    var v = u + f;
                    if (seen.Contains(v) || cells.Contains(v) || v.x < b.Lo.x || v.y < b.Lo.y || v.z < b.Lo.z
                        || v.x > b.Hi.x || v.y > b.Hi.y || v.z > b.Hi.z)
                        continue;
                    seen.Add(v);
                    pred[v] = u;
                    int q = Math.Max(p, v.y);
                    prio[v] = q;
                    Push(heap, Key(q, entries.Count));
                    entries.Add(v);
                }
            }
            // Cavité close : le lac monte jusqu'au plafond demandé, ou jusqu'au haut de la cavité si elle est plus basse.
            var closed = new HollowResult { Way = "closed", Level = c.y, Seen = seen };
            foreach (var s in out_)
                if (prio[s] <= ceiling)
                {
                    closed.Cells.Add(s);
                    closed.Level = Math.Max(closed.Level, s.y);
                }
            return closed;
        }

        sealed class FlatResult
        {
            public string Error;
            public bool Hollow;
            public List<Int3> Path;
            /// <summary>"" (falls next), "leaves" or "joins".</summary>
            public string End;
            /// <summary>Every cell visited (the footprint); null on an error.</summary>
            public Dictionary<Int3, Int3?> Seen;
        }

        // LA COULÉE À PLAT : depuis c, à son étage, le plus court chemin (largeur d'abord, voisins dans l'ordre) jusqu'à une
        // case d'où l'eau tombe, rejoint une eau, ou quitte le monde. `ignore` : le lac qu'on vient de quitter.
        static FlatResult Flat(ICollection<Int3> cells, WaterBox b, ICollection<Int3> fixedWater, ICollection<Int3> lakes,
            Int3 c, ICollection<Int3> ignore, int max)
        {
            var pred = new Dictionary<Int3, Int3?> { [c] = null };
            var queue = new List<Int3> { c };
            int i = 0;
            while (i < queue.Count)
            {
                var u = queue[i++];
                var d = u + Down;
                string end = "?";
                if (!ignore.Contains(d) && (fixedWater.Contains(d) || lakes.Contains(d))) end = "joins";
                else if (!cells.Contains(d) && !ignore.Contains(d) && d.y >= b.Lo.y) end = "";
                else if (b.Horizon(u)) end = "leaves";
                if (end == "?")
                    foreach (var f in Horizontal)
                    {
                        var v = u + f;
                        if (cells.Contains(v) || v.x < b.Lo.x || v.z < b.Lo.z || v.x > b.Hi.x || v.z > b.Hi.z || pred.ContainsKey(v))
                            continue;
                        if (fixedWater.Contains(v) || lakes.Contains(v)) { end = "joins"; break; }
                        pred[v] = u;
                        queue.Add(v);
                    }
                if (end != "?")
                {
                    var path = new List<Int3>();
                    Int3? w = u;
                    while (w.HasValue) { path.Insert(0, w.Value); w = pred[w.Value]; }
                    return new FlatResult { Path = path, End = end, Seen = pred };
                }
                if (queue.Count > max) return new FlatResult { Error = "too_large" };
            }
            return new FlatResult { Hollow = true, Seen = pred };
        }

        // Depuis le seuil d'un lac, l'eau trouve-t-elle à plat une chute (ou une autre eau, ou le bord) à au plus
        // OverflowReach cases ? La même coulée que la rivière, bornée.
        static bool FallNear(ICollection<Int3> cells, WaterBox b, ICollection<Int3> fixedWater, ICollection<Int3> lakes,
            Int3? threshold, ICollection<Int3> lake, ref Int3 lo, ref Int3 hi)
        {
            if (!threshold.HasValue) return false;
            int reach = 2 * OverflowReach + 1;
            var flat = Flat(cells, b, fixedWater, lakes, threshold.Value, lake, Math.Min(VolumeMax, reach * reach));
            if (flat.Seen != null) Extend(ref lo, ref hi, flat.Seen.Keys);
            return flat.Path != null && flat.Path.Count - 1 <= OverflowReach;
        }

        /// <summary>THE WIDTH OF A RIVER when it is placed: <paramref name="width"/> sources side by side, ACROSS the first
        /// horizontal step of the river placed at s, centred on s (one more on the + side when even), s first. Only the
        /// neighbours that ARE rivers stay; a source that is not a river (a lake, a sea) does not widen.</summary>
        public static List<Int3> RiverWidth(ICollection<Int3> cells, Int3 s, int width, ICollection<Int3> water = null)
        {
            water = water ?? new HashSet<Int3>();
            var b = BoxOf(cells);
            var r = Source(cells, s, water, b);
            var result = new List<Int3> { s };
            if (width <= 1 || r.Kind != "river") return result;
            var across = new Int3(1, 0, 0);
            for (int i = 1; i < r.Course.Count; i++)
            {
                var a = r.Course[i - 1].Cell;
                var next = r.Course[i].Cell;
                if (a.x != next.x || a.z != next.z)
                {
                    across = next.x != a.x ? new Int3(0, 0, 1) : new Int3(1, 0, 0);
                    break;
                }
            }
            int low = -((width - 1) / 2);
            for (int k = low; k < low + width; k++)
            {
                if (k == 0) continue;
                var c = new Int3(s.x + across.x * k, s.y, s.z + across.z * k);
                if (cells.Contains(c)) continue;
                var rc = Source(cells, c, water, b);
                if (rc.Error == "" && rc.Kind == "river") result.Add(c);
            }
            return result;
        }

        /// <summary>THE SURFACE of some water: its cells whose cell above is neither water nor full.</summary>
        public static List<Int3> Surface(ICollection<Int3> water, ICollection<Int3> cells)
        {
            var s = new List<Int3>();
            foreach (var c in water)
            {
                var h = c + Up;
                if (!water.Contains(h) && !cells.Contains(h)) s.Add(c);
            }
            return s;
        }

        /// <summary>THE DEPTH below a water cell: water cells down to the floor (the cell included); −1 when the water
        /// reaches the bottom of the world without a floor.</summary>
        public static int Depth(ICollection<Int3> water, ICollection<Int3> cells, Int3 c)
        {
            int n = 0;
            var u = c;
            while (water.Contains(u)) { n++; u += Down; }
            return cells.Contains(u) ? n : -1;
        }

        /// <summary>Reads the optional "water" key of a world.json decoded by MBJson. Absent: no water layer. Refuses the
        /// key, and says why, when a layer has no name, visibility or look, a mesh that is neither a path nor null, or
        /// sources that are not integer x y z triples.</summary>
        public static WaterFileResult Read(object decodedWorld)
        {
            var result = new WaterFileResult();
            if (!(decodedWorld is Dictionary<string, object> world)) return Refuse("not a MarchingBlocks world");
            if (!world.TryGetValue("water", out var list)) return result;
            if (!(list is List<object> layers)) return Refuse("water is not an array");
            foreach (var item in layers)
            {
                if (!(item is Dictionary<string, object> e)
                    || !e.TryGetValue("name", out var n) || !(n is string name)
                    || !e.TryGetValue("visible", out var v) || !(v is bool visible)
                    || !e.TryGetValue("look", out var l) || !(l is string look))
                    return Refuse("a water layer has no name, visibility or look");
                e.TryGetValue("mesh", out var m);
                if (m != null && !(m is string)) return Refuse($"water '{name}': mesh is neither a path nor null");
                if (!e.TryGetValue("sources", out var sv) || !(sv is List<object> flat) || flat.Count % 3 != 0)
                    return Refuse($"water '{name}': sources is not a list of x y z triples");
                var layer = new WaterLayer { Name = name, Visible = visible, Look = look, Mesh = (string)m };
                for (int i = 0; i < flat.Count; i += 3)
                {
                    if (!Coordinate(flat[i], out int x) || !Coordinate(flat[i + 1], out int y) || !Coordinate(flat[i + 2], out int z))
                        return Refuse($"water '{name}': a source coordinate is not an integer");
                    layer.Sources.Add(new Int3(x, y, z));
                }
                result.Layers.Add(layer);
            }
            return result;
        }

        static WaterFileResult Refuse(string why) => new WaterFileResult { Error = why };

        static bool Coordinate(object o, out int value)
        {
            value = 0;
            double d;
            if (o is long l) d = l;
            else if (o is double dd) d = dd;
            else return false;
            if (double.IsNaN(d) || double.IsInfinity(d) || Math.Floor(d) != d || d < int.MinValue || d > int.MaxValue) return false;
            value = (int)d;
            return true;
        }
    }
}
