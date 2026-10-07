// MarchingBlocks Paint for Unity — THE REPRISE PROVEN: MBWater.World with a previous world and the changed cells (what
// the editor does after a gesture) returns the SAME water as a whole computation, and the mesher with its memory the SAME
// sheet as a mesher without one. The reprise has no case of its own (engines/PARITE.md §12, 3): it must give what the
// whole computation gives — checked after every gesture of three kinds:
//   - SYSTEMATIC: every cell next to the water (a course, a lake, the sea's surface, and their neighbours) toggled, then
//     put back — where the footprints end, the floors, the lips, the rims;
//   - SCRIPTED, on worlds built for it: a deep crater's rim (the lake rises above the source), a hole off a river's path on
//     a plateau, a duct far from a river that makes its pool sea water or not, a river among three that stops (its
//     neighbours' waterfalls lose or regain a free end), a basin made deeper under its waterfall (the foam rises);
//   - RANDOM: anywhere, near the water, far above everything, and back to the start in one large gesture.
// It must also TAKE AGAIN something, or it proves nothing: the bodies and sheets taken again are counted.
//
// No Unity dependency: compiled by the Test Runner and by the .NET conformance-runner.

using System;
using System.Collections.Generic;
using static MarchingBlocks.Paint.Tests.ParityCheck;

namespace MarchingBlocks.Paint.Tests
{
    public static class WaterIncrementalCheck
    {
        sealed class Setup
        {
            public string Name;
            public HashSet<Int3> Cells;
            public List<Int3> Sources = new List<Int3>();
            /// <summary>Gestures made on purpose: each is applied (cells toggled), checked, then undone and checked again.</summary>
            public List<List<Int3>> Scripted = new List<List<Int3>>();
        }

        static Int3 P(int x, int y, int z) => new Int3(x, y, z);

        static void Box(HashSet<Int3> s, int x0, int y0, int z0, int x1, int y1, int z1, bool full = true)
        {
            for (int x = x0; x <= x1; x++)
                for (int y = y0; y <= y1; y++)
                    for (int z = z0; z <= z1; z++)
                        if (full) s.Add(P(x, y, z)); else s.Remove(P(x, y, z));
        }

        static List<Setup> Setups(Dictionary<string, object> worlds)
        {
            var list = new List<Setup>();
            Setup FromFile(string name, params Int3[] sources)
            {
                var s = new Setup { Name = name, Cells = Cells(worlds[name]) };
                s.Sources.AddRange(sources);
                list.Add(s);
                return s;
            }
            // Les mondes du fichier du maillage, avec les sources de leurs cas.
            var stairs = FromFile("stairs", P(0, 3, 1), P(0, 3, 0), P(0, 3, 2));
            // Une rivière sur trois s'arrête (sa source dans la matière) : ses voisines gagnent un bout libre.
            stairs.Scripted.Add(new List<Int3> { P(0, 3, 1) });
            FromFile("island", P(-1, 2, -1), P(4, 4, 4), P(9, 1, 9));
            var basin = FromFile("a cliff above a basin", P(2, 5, 1));
            // Le bassin rehaussé d'un rang (x = 6 ; z = −1 et 3) : le lac monte d'une case sous la cascade, son remous aussi.
            var ring = new List<Int3>();
            for (int z = -1; z <= 3; z++) ring.Add(P(6, 2, z));
            for (int x = 3; x <= 5; x++) { ring.Add(P(x, 2, -1)); ring.Add(P(x, 2, 3)); }
            basin.Scripted.Add(ring);
            FromFile("crater in a plain", P(6, 3, 6));
            FromFile("crater near the edge", P(2, 2, 6));
            FromFile("a slab on a pillar", P(10, 2, 10));
            FromFile("closed cave", P(2, 2, 2));

            // UN CRATÈRE PROFOND, la source au fond : le lac monte à 3, au-dessus de la source et du fond.
            var crater = new Setup { Name = "a deep crater, the source on its floor", Cells = new HashSet<Int3>() };
            Box(crater.Cells, 0, 0, 0, 12, 0, 12);
            for (int x = 3; x <= 9; x++)
                for (int z = 3; z <= 9; z++)
                    if (x == 3 || x == 9 || z == 3 || z == 9) Box(crater.Cells, x, 1, z, x, 4, z);
            crater.Cells.Remove(P(6, 4, 3));   // l'échancrure : le seuil
            crater.Sources.Add(P(6, 1, 6));
            crater.Scripted.Add(new List<Int3> { P(4, 3, 3) });          // une brèche à mi-hauteur du rebord
            crater.Scripted.Add(new List<Int3> { P(6, 4, 3) });          // l'échancrure fermée
            list.Add(crater);

            // UN PLATEAU : la rivière part du milieu vers le bord le plus proche ; un trou creusé de côté la détourne.
            var plateau = new Setup { Name = "a plateau, a river to its nearest edge", Cells = new HashSet<Int3>() };
            Box(plateau.Cells, 0, 0, 0, 10, 0, 10);
            plateau.Sources.Add(P(5, 1, 5));
            plateau.Scripted.Add(new List<Int3> { P(5, 0, 2) });
            plateau.Scripted.Add(new List<Int3> { P(2, 0, 5) });
            list.Add(plateau);

            // UNE MARE DE MER au fond d'un puits du plateau, reliée à la mer par un conduit LOIN de la rivière qui y tombe :
            // le conduit bouché, la mare n'est plus la mer — la rivière doit changer, sans case changée dans son emprise.
            var duct = new Setup { Name = "a pool fed by the sea through a duct", Cells = new HashSet<Int3>() };
            Box(duct.Cells, 0, 0, 0, 20, 0, 6);
            Box(duct.Cells, 8, 1, 0, 20, 4, 6);
            Box(duct.Cells, 14, 1, 2, 16, 4, 4, false);   // le puits
            Box(duct.Cells, 8, 1, 3, 13, 1, 3, false);    // le conduit, sous le niveau de la mer
            duct.Sources.Add(P(-1, 2, 3));                // la mer, niveau 2
            duct.Sources.Add(P(18, 5, 3));                // la rivière du plateau
            duct.Scripted.Add(new List<Int3> { P(10, 1, 3) });
            list.Add(duct);
            return list;
        }

        public static List<string> Run(Dictionary<string, object> meshConf, int randomGestures, int seed, out int checks,
            out string stats)
        {
            var failures = new List<string>();
            int count = 0;
            int bodiesTaken = 0, bodiesTotal = 0, sheetsTaken = 0;
            var rnd = new Random(seed);
            foreach (var st in Setups((Dictionary<string, object>)meshConf["worlds"]))
            {
                var cells = st.Cells;
                var sources = st.Sources;
                var original = new HashSet<Int3>(cells);
                var memory = new WaterMeshMemory();
                var before = MBWater.World(cells, sources);
                MBWaterMesh.Arrays(before.Bodies, cells, before.Box, memory);
                int localFailures = 0;
                // Un geste : les cases basculées ; vérifié contre le calcul entier, puis le monde suivant part de lui.
                void Gesture(string what, ICollection<Int3> toggle)
                {
                    var changed = new HashSet<Int3>();
                    foreach (var c in toggle)
                    {
                        if (!cells.Remove(c)) cells.Add(c);
                        changed.Add(c);
                    }
                    if (cells.Count == 0) { foreach (var c in changed) cells.Add(c); return; }
                    var whole = MBWater.World(cells, sources);
                    var again = MBWater.World(cells, sources, before, changed);
                    count++;
                    string why = null;
                    for (int k = 0; k < sources.Count && why == null; k++)
                    {
                        bodiesTotal++;
                        if (ReferenceEquals(again.Bodies[k], before.Bodies[k])) bodiesTaken++;
                        var w = SameBody(again.Bodies[k], whole.Bodies[k]);
                        if (w != null) why = $"body {k} {w}";
                    }
                    if (why == null && !again.Sea.SetEquals(whole.Sea)) why = "the sea differs from the whole computation";
                    if (why == null)
                    {
                        var withMemory = MBWaterMesh.Arrays(again.Bodies, cells, again.Box, memory);
                        sheetsTaken += memory.ReusedSheets;
                        var bag = WaterMeshConformanceCheck.SameBag(
                            WaterMeshConformanceCheck.Triangles(MBWaterMesh.Arrays(whole.Bodies, cells)),
                            WaterMeshConformanceCheck.Triangles(withMemory));
                        if (bag != null) why = "the sheet with the memory differs — " + bag;
                    }
                    if (why != null && localFailures++ < 3) failures.Add($"{st.Name}, {what}: {why}");
                    before = again;
                }
                // 1. SCRIPTÉS : chacun, puis défait.
                for (int s = 0; s < st.Scripted.Count; s++)
                {
                    Gesture($"scripted gesture {s}", st.Scripted[s]);
                    Gesture($"scripted gesture {s} undone", st.Scripted[s]);
                }
                // 2. SYSTÉMATIQUES : chaque case au contact de l'eau, basculée puis remise.
                var near = new HashSet<Int3>();
                foreach (var b in before.Bodies)
                {
                    if (b == null) continue;
                    var around = new List<Int3>();
                    foreach (var s in b.Course) around.Add(s.Cell);
                    if (b.Kind != "sea") around.AddRange(b.Water);
                    else around.AddRange(MBWater.Surface(b.Water, cells));
                    foreach (var c in around)
                        for (int dx = -1; dx <= 1; dx++)
                            for (int dy = -1; dy <= 1; dy++)
                                for (int dz = -1; dz <= 1; dz++)
                                    near.Add(P(c.x + dx, c.y + dy, c.z + dz));
                }
                var nearList = new List<Int3>(near);
                nearList.Sort((p, q) => p.x != q.x ? p.x.CompareTo(q.x) : p.y != q.y ? p.y.CompareTo(q.y) : p.z.CompareTo(q.z));
                // Au plus 400 par monde (la mer de l'île en aurait des milliers) : un sur n, dans l'ordre.
                int step = Math.Max(1, nearList.Count / 400);
                for (int i = 0; i < nearList.Count; i += step)
                {
                    var one = new[] { nearList[i] };
                    Gesture($"toggle {nearList[i]}", one);
                    Gesture($"toggle {nearList[i]} undone", one);
                }
                // 3. AU HASARD, sans défaire : le monde dérive, et revient d'un seul grand geste de temps en temps.
                var lo = new Int3(int.MaxValue, int.MaxValue, int.MaxValue);
                var hi = new Int3(int.MinValue, int.MinValue, int.MinValue);
                foreach (var c in original)
                {
                    lo = new Int3(Math.Min(lo.x, c.x), Math.Min(lo.y, c.y), Math.Min(lo.z, c.z));
                    hi = new Int3(Math.Max(hi.x, c.x), Math.Max(hi.y, c.y), Math.Max(hi.z, c.z));
                }
                for (int g = 0; g < randomGestures; g++)
                {
                    var toggle = new HashSet<Int3>();
                    int pick = rnd.Next(10);
                    if (pick == 0)
                    {
                        foreach (var c in MBWater.ChangedBetween(cells, original)) toggle.Add(c);
                        if (toggle.Count > 0) Gesture("back to the start", toggle);
                        continue;
                    }
                    Int3 at;
                    int size = 1 + rnd.Next(2);
                    if (pick <= 5 && nearList.Count > 0) at = nearList[rnd.Next(nearList.Count)];
                    else if (pick <= 7) at = P(rnd.Next(lo.x, hi.x + 1), hi.y + 1 + rnd.Next(2), rnd.Next(lo.z, hi.z + 1));
                    else at = P(rnd.Next(lo.x - 2, hi.x + 3), rnd.Next(lo.y - 1, hi.y + 3), rnd.Next(lo.z - 2, hi.z + 3));
                    bool set = rnd.Next(2) == 0;
                    for (int dx = 0; dx < size; dx++)
                        for (int dz = 0; dz < size; dz++)
                        {
                            var c = P(at.x + dx, at.y, at.z + dz);
                            if (cells.Contains(c) != set) toggle.Add(c);
                        }
                    if (toggle.Count > 0) Gesture($"random gesture {g} at {at}", toggle);
                }
            }
            checks = count;
            stats = $"{bodiesTaken} of {bodiesTotal} bodies taken again, {sheetsTaken} sheets kept by the memory";
            if (bodiesTaken == 0) failures.Add("the reprise never took a body again: it proves nothing");
            if (bodiesTaken == bodiesTotal) failures.Add("the reprise took EVERY body again: the gestures never reached the water");
            return failures;
        }

        static string SameBody(WaterBody g, WaterBody e)
        {
            if (g.Kind != e.Kind || g.Error != e.Error || g.End != e.End || g.Level != e.Level)
                return $"is {g.Kind}/{g.Error}/{g.End}/{g.Level}, the whole computation says {e.Kind}/{e.Error}/{e.End}/{e.Level}";
            if (!g.Water.SetEquals(e.Water)) return "has other water cells";
            if (g.Lakes.Count != e.Lakes.Count) return "has another number of lakes";
            for (int k = 0; k < g.Lakes.Count; k++)
                if (g.Lakes[k].Level != e.Lakes[k].Level || !g.Lakes[k].Cells.SetEquals(e.Lakes[k].Cells)) return $"lake {k} differs";
            if (g.Course.Count != e.Course.Count) return "has another course";
            for (int k = 0; k < g.Course.Count; k++)
                if (!g.Course[k].Cell.Equals(e.Course[k].Cell) || g.Course[k].Kind != e.Course[k].Kind || g.Course[k].Lake != e.Course[k].Lake)
                    return $"step {k} differs";
            return null;
        }
    }
}
