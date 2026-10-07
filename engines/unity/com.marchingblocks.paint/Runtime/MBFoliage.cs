// MarchingBlocks Paint for Unity — THE FOLIAGE RULE, as pure functions.
//
// Plants (trees, bushes: a .glb model each) placed on a MarchingBlocks world. This file holds the RULE only: where a
// plant may grow (three modes, seven refusals), the brush, where its model sits, the wind data of each plant and the
// sway of a vertex — and the reader of the "foliage" key of world.json. No Unity dependency: Tests/foliage_conformance.json
// (computed by the MarchingBlocks tool itself) proves it outside the editor too (see conformance-runner). Its rules_text
// says every rule in full.
//
// Everything is in FORMAT space: right-handed, +Y up, one unit = one cell. An engine converts through the measured
// frame (MBTileset.Frame) — a wind shader too.
//
// Référence : addons/marchingblocks_core/feuillage.gd (FE.verifier, _semer_un, transformation, vent_du_plant,
// balancement, sol_des_cases, case_d_eau) et format_monde.gd (lire_feuillage), ligne à ligne.

using System;
using System.Collections.Generic;

namespace MarchingBlocks.Paint
{
    /// <summary>A foliage model (one .glb). Numbers in MODEL units unless said otherwise.</summary>
    public sealed class FoliageModel
    {
        public int Id;
        public string Name = "";
        /// <summary>The .glb path RELATIVE to world.json, or null (the file was missing when the world was exported).</summary>
        public string Mesh;
        /// <summary>How far the model's origin sits ABOVE the ground (negative buries it).</summary>
        public double GroundOffset = 0.0;
        public double Scale = 1.0;
        /// <summary>Each plant draws a factor in [1 − a, 1 + a] (a at most 0.9).</summary>
        public double ScaleRandom = 0.2;
        /// <summary>The footprint radius, in CELLS at scale 1.</summary>
        public double Footprint = 0.5;
        /// <summary>The top of the model above its origin.</summary>
        public double Height = 1.0;
        /// <summary>0 still, 1 the full sway.</summary>
        public double Wind = 0.5;
    }

    /// <summary>A plant: its model, the point ON THE GROUND (format space), its yaw (radians about +Y), its own scale draw,
    /// and whether it was planted (or placed in the air).</summary>
    public sealed class Plant
    {
        public int Model;
        public double X, Y, Z;
        public double Yaw;
        public double Scale = 1.0;
        public bool Planted;
    }

    public enum FoliageMode { Air, Free, Overflow }

    public struct Double3
    {
        public double x, y, z;
        public Double3(double x, double y, double z) { this.x = x; this.y = y; this.z = z; }
        public override string ToString() => $"({x}, {y}, {z})";
    }

    /// <summary>The ground found under a point: its height and its normal.</summary>
    public struct Ground
    {
        public double Y;
        public Double3 Normal;
    }

    /// <summary>How the rule reads the world. <see cref="GroundAt"/>(x, z, yTop): the ground below yTop, or null — on real
    /// tiles, a vertical ray against the placed tile meshes; without tiles, <see cref="MBFoliage.GroundOfCells"/>.
    /// <see cref="Water"/>(point): water there (optional; see <see cref="MBFoliage.WaterCell"/>).</summary>
    public sealed class FoliageWorld
    {
        public Func<Int3, bool> Full;
        public Func<double, double, double, Ground?> GroundAt;
        public Func<Double3, bool> Water;
    }

    /// <summary>Where a plant's model sits: T = translate(Origin) · rotateY(Yaw) · scale(Scale).</summary>
    public struct PlantPose
    {
        public Double3 Origin;
        public double Yaw;
        public double Scale;
        /// <summary>Column i of T's 3 × 3 part (0: x, 1: y, 2: z).</summary>
        public Double3 Column(int i)
        {
            double c = Math.Cos(Yaw), s = Math.Sin(Yaw);
            switch (i)
            {
                case 0: return new Double3(c * Scale, 0, -s * Scale);
                case 1: return new Double3(0, Scale, 0);
                default: return new Double3(s * Scale, 0, c * Scale);
            }
        }
    }

    /// <summary>What a wind shader needs per plant: the ground (the plant's y), its height above the ground, its phase
    /// (from its position), its amplitude (the model's wind).</summary>
    public struct PlantWind
    {
        public double Ground, Height, Phase, Amplitude;
    }

    /// <summary>A brush candidate: where (x, z) and its draw (yaw, scale).</summary>
    public struct BrushCandidate
    {
        public double X, Z, Yaw, Scale;
    }

    public sealed class BrushResult
    {
        /// <summary>The accepted plants, in candidate order (already in the index).</summary>
        public readonly List<Plant> Plants = new List<Plant>();
        /// <summary>The refusals counted by reason (no_ground, in_matter, too_steep, …).</summary>
        public readonly Dictionary<string, int> Refused = new Dictionary<string, int>();
    }

    /// <summary>The plants by bucket of 4 × 4 cells, so a candidate is never compared to thousands of plants. The ORDER
    /// of <see cref="Near"/> (buckets by x, then z, then insertion) is the tool's: the first refusal met is the one said.</summary>
    public sealed class PlantIndex
    {
        public const double Bucket = 4.0;
        readonly Dictionary<(int, int), List<Plant>> buckets = new Dictionary<(int, int), List<Plant>>();
        readonly IDictionary<int, FoliageModel> models;
        /// <summary>The largest footprint radius (scaled) of the indexed plants of a known model.</summary>
        public double MaxRadius { get; private set; }

        public PlantIndex(IDictionary<int, FoliageModel> models, IEnumerable<Plant> plants = null)
        {
            this.models = models;
            if (plants != null) foreach (var p in plants) Add(p);
        }

        static (int, int) Key(double x, double z) => ((int)Math.Floor(x / Bucket), (int)Math.Floor(z / Bucket));

        public void Add(Plant p)
        {
            var k = Key(p.X, p.Z);
            if (!buckets.TryGetValue(k, out var list)) buckets[k] = list = new List<Plant>();
            list.Add(p);
            if (models.TryGetValue(p.Model, out var m)) MaxRadius = Math.Max(MaxRadius, MBFoliage.Radius(m, p));
        }

        public void Remove(Plant p)
        {
            if (buckets.TryGetValue(Key(p.X, p.Z), out var list)) list.Remove(p);
        }

        /// <summary>The plants within <paramref name="reach"/> of (x, z) in the plane, and within reach + 2 in height.</summary>
        public List<Plant> Near(double x, double y, double z, double reach)
        {
            var result = new List<Plant>();
            var lo = Key(x - reach, z - reach);
            var hi = Key(x + reach, z + reach);
            for (int bx = lo.Item1; bx <= hi.Item1; bx++)
                for (int bz = lo.Item2; bz <= hi.Item2; bz++)
                {
                    if (!buckets.TryGetValue((bx, bz), out var list)) continue;
                    foreach (var q in list)
                        if (Planar(q.X - x, q.Z - z) <= reach && Math.Abs(q.Y - y) <= reach + 2.0) result.Add(q);
                }
            return result;
        }

        internal static double Planar(double dx, double dz) => Math.Sqrt(dx * dx + dz * dz);
    }

    public static class MBFoliage
    {
        public const double MaxSlopeDeg = 40.0;
        public const double GroundTolerance = 0.35;
        public const int EdgeSamples = 8;
        /// <summary>Two plants closer than this are the same plant.</summary>
        public const double Duplicate = 0.05;
        /// <summary>Water at q is the cell (floor(q.x), floor(q.y + WaterOffset), floor(q.z)).</summary>
        public const double WaterOffset = 0.2;
        public const int GroundSearchFloor = -64;
        /// <summary>The wind direction in the x z plane (not normalized). 0.35 in single precision, as the tool's shader.</summary>
        public const double WindDirectionX = 1.0, WindDirectionZ = 0.349999994039536;

        // ---- the plant ----

        /// <summary>The plant's total scale: the model's × its own draw.</summary>
        public static double ScaleOf(FoliageModel m, Plant p) => m.Scale * p.Scale;

        /// <summary>The plant's footprint radius, in cells.</summary>
        public static double Radius(FoliageModel m, Plant p) => m.Footprint * ScaleOf(m, p);

        /// <summary>Its height above the ground, in cells: max(0, (height + ground_offset) · s).</summary>
        public static double HeightAboveGround(FoliageModel m, Plant p) => Math.Max(0.0, (m.Height + m.GroundOffset) * ScaleOf(m, p));

        /// <summary>Where the model sits: T = translate(p + (0, ground_offset · s, 0)) · rotateY(yaw) · scale(s).</summary>
        public static PlantPose Place(FoliageModel m, Plant p)
        {
            double s = ScaleOf(m, p);
            return new PlantPose { Origin = new Double3(p.X, p.Y + m.GroundOffset * s, p.Z), Yaw = p.Yaw, Scale = s };
        }

        // ---- the rule ----

        /// <summary>May this plant (already drawn: point, yaw, scale) grow there in this mode? "" when it may, else the
        /// reason: in_matter, too_steep, in_water, at_edge, under_matter, too_close, already_there. <paramref name="normal"/>:
        /// the ground's normal at the point (up in the air). <paramref name="spacing"/>: the brush's minimum distance to
        /// the other plants, in every mode.</summary>
        public static string Check(FoliageModel m, Plant p, Double3 normal, FoliageMode mode, FoliageWorld world,
            PlantIndex index, IDictionary<int, FoliageModel> models, double spacing = 0.0, double maxSlopeDeg = MaxSlopeDeg)
        {
            double r = Radius(m, p);
            // 1. Les voisins : d'abord le doublon, dans tous les modes.
            double reach = Math.Max(spacing, Duplicate);
            if (mode == FoliageMode.Free) reach = Math.Max(reach, r + index.MaxRadius);
            foreach (var q in index.Near(p.X, p.Y, p.Z, reach))
            {
                double d = PlantIndex.Planar(q.X - p.X, q.Z - p.Z);
                if (d < Duplicate) return "already_there";
                if (d < spacing) return "too_close";
                if (mode == FoliageMode.Free && models.TryGetValue(q.Model, out var mq) && d < r + Radius(mq, q))
                    return "too_close";
            }
            // 2. Dans l'air : seule la case du point compte.
            if (mode == FoliageMode.Air)
                return world.Full(new Int3(Floor(p.X), Floor(p.Y), Floor(p.Z))) ? "in_matter" : "";
            // 3. Planté : la pente, l'eau.
            double len = Math.Sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z);
            double ny = len > 0 ? normal.y / len : 0.0;
            if (ny < Math.Cos(maxSlopeDeg * Math.PI / 180.0) - 1e-6) return "too_steep";
            if (world.Water != null && world.Water(new Double3(p.X, p.Y + 0.1, p.Z))) return "in_water";
            if (mode != FoliageMode.Free) return "";
            // 4. Voisinage libre : l'empreinte portée par le sol, à peu près à la même hauteur…
            var edge = new double[EdgeSamples + 1, 2];
            for (int k = 0; k < EdgeSamples; k++)
            {
                double a = 2.0 * Math.PI * k / EdgeSamples;
                edge[k + 1, 0] = Math.Cos(a) * r;
                edge[k + 1, 1] = Math.Sin(a) * r;
            }
            for (int k = 1; k <= EdgeSamples; k++)
            {
                // ⚠ GDScript saute un point du bord qui vaudrait exactement (0, 0) — un rayon nul : tout le bord.
                if (edge[k, 0] == 0.0 && edge[k, 1] == 0.0) continue;
                var g = world.GroundAt(p.X + edge[k, 0], p.Z + edge[k, 1], p.Y + 1.0);
                if (g == null || Math.Abs(g.Value.Y - p.Y) > GroundTolerance) return "at_edge";
            }
            // … et rien de plein au-dessus, au centre et à mi-rayon.
            double h = HeightAboveGround(m, p);
            int y0 = Floor(p.Y + 0.3), y1 = Floor(p.Y + Math.Max(h, 0.3));
            for (int k = 0; k <= EdgeSamples; k++)
            {
                double qx = p.X + edge[k, 0] * 0.5, qz = p.Z + edge[k, 1] * 0.5;
                for (int y = y0; y <= y1; y++)
                    if (world.Full(new Int3(Floor(qx), y, Floor(qz)))) return "under_matter";
            }
            return "";
        }

        /// <summary>THE BRUSH, its candidates given in order (an engine draws them as it likes: x, z in the brush's disc,
        /// then yaw and scale). Planted modes look for the ground below <paramref name="yTop"/> (none: no_ground); air puts
        /// the plant at yTop. Each candidate is checked; an accepted plant joins <paramref name="index"/> AT ONCE.</summary>
        public static BrushResult Brush(FoliageModel m, double yTop, IEnumerable<BrushCandidate> candidates, FoliageMode mode,
            FoliageWorld world, PlantIndex index, IDictionary<int, FoliageModel> models, double spacing = 0.0,
            double maxSlopeDeg = MaxSlopeDeg)
        {
            var result = new BrushResult();
            foreach (var c in candidates)
            {
                double y = yTop;
                var n = new Double3(0, 1, 0);
                if (mode != FoliageMode.Air)
                {
                    var g = world.GroundAt(c.X, c.Z, yTop);
                    if (g == null) { Count(result.Refused, "no_ground"); continue; }
                    y = g.Value.Y;
                    n = g.Value.Normal;
                }
                var p = new Plant { Model = m.Id, X = c.X, Y = y, Z = c.Z, Yaw = c.Yaw, Scale = c.Scale, Planted = mode != FoliageMode.Air };
                string why = Check(m, p, n, mode, world, index, models, spacing, maxSlopeDeg);
                if (why != "") { Count(result.Refused, why); continue; }
                result.Plants.Add(p);
                index.Add(p);
            }
            return result;
        }

        /// <summary>The scale a plant draws: a factor in [1 − a, 1 + a], a = scale_random clamped to [0, 0.9];
        /// <paramref name="unit"/> in [0, 1).</summary>
        public static double DrawScale(FoliageModel m, double unit)
        {
            double a = Math.Max(0.0, Math.Min(0.9, m.ScaleRandom));
            return 1.0 - a + 2.0 * a * unit;
        }

        /// <summary>The water cell read at point q: (floor(q.x), floor(q.y + 0.2), floor(q.z)).</summary>
        public static Int3 WaterCell(Double3 q) => new Int3(Floor(q.x), Floor(q.y + WaterOffset), Floor(q.z));

        /// <summary>THE GROUND OF CELLS (no tiles): in column (floor(x), floor(z)), from floor(yTop) − 1 down to
        /// <paramref name="yBottom"/>, the first full cell with an empty cell above: ground y + 1, normal up; else null.</summary>
        public static Ground? GroundOfCells(Func<Int3, bool> full, double x, double z, double yTop, int yBottom = GroundSearchFloor)
        {
            int cx = Floor(x), cz = Floor(z);
            for (int y = Floor(yTop) - 1; y >= yBottom; y--)
                if (full(new Int3(cx, y, cz)) && !full(new Int3(cx, y + 1, cz)))
                    return new Ground { Y = y + 1, Normal = new Double3(0, 1, 0) };
            return null;
        }

        // ---- the wind ----

        /// <summary>What the wind shader needs for this plant: (ground = p.y, height above ground, phase = (0.37 x + 0.71 z)
        /// mod 2π, amplitude = the model's wind).</summary>
        public static PlantWind WindData(FoliageModel m, Plant p)
        {
            double phase = (p.X * 0.37 + p.Z * 0.71) % (2.0 * Math.PI);
            if (phase < 0) phase += 2.0 * Math.PI;
            return new PlantWind { Ground = p.Y, Height = HeightAboveGround(m, p), Phase = phase, Amplitude = m.Wind };
        }

        /// <summary>THE SWAY of a vertex P (format WORLD space) with normal N at time t — the vertex shader of the wind, line
        /// by line: bent ∝ h², two gusts, the leaves' shiver along the normal. A height of 0 does not move.</summary>
        public static Double3 Sway(Double3 vertex, Double3 normal, PlantWind w, double t,
            double directionX = WindDirectionX, double directionZ = WindDirectionZ)
        {
            if (w.Height <= 0.0) return vertex;
            double h = Math.Max(0.0, Math.Min(1.0, (vertex.y - w.Ground) / w.Height));
            double amp = w.Amplitude * w.Height * 0.05;
            double b = 0.35 + 0.6 * Math.Sin(t * 1.1 + w.Phase) + 0.3 * Math.Sin(t * 2.3 + w.Phase * 1.7);
            double len = Math.Sqrt(directionX * directionX + directionZ * directionZ);
            double k = b * amp * h * h / len;
            var v = new Double3(vertex.x + directionX * k, vertex.y, vertex.z + directionZ * k);
            double shiver = Math.Sin(t * 7.0 + v.x * 2.1 + v.y * 1.7 + v.z * 2.9) * 0.015 * w.Amplitude * h;
            return new Double3(v.x + normal.x * shiver, v.y + normal.y * shiver, v.z + normal.z * shiver);
        }

        // ---- the file ----

        public sealed class FileResult
        {
            /// <summary>"" when read; otherwise why the WHOLE file is refused (Models and Plants are then empty).</summary>
            public string Error = "";
            public readonly List<FoliageModel> Models = new List<FoliageModel>();
            public readonly List<Plant> Plants = new List<Plant>();
            public bool Ok => Error == "";
        }

        /// <summary>Reads the "foliage" key of a world.json already decoded by MBJson. Absent: no plant. A malformed entry,
        /// a number of another type, an id twice, or a plant of an unknown model refuses the whole file.</summary>
        public static FileResult Read(object decodedWorld)
        {
            var r = new FileResult();
            if (!(decodedWorld is Dictionary<string, object> world)) return Refuse("not a MarchingBlocks world");
            if (!world.TryGetValue("foliage", out var d) || d == null) return r;
            if (!(d is Dictionary<string, object> fo)) return Refuse("foliage is not an object");
            object list = fo.TryGetValue("models", out var ml) ? ml : new List<object>();
            if (!(list is List<object> models)) return Refuse("foliage: models is not an array");
            var ids = new HashSet<int>();
            for (int i = 0; i < models.Count; i++)
            {
                if (!(models[i] is Dictionary<string, object> e)) return Refuse("foliage: a model is not an object");
                if (!e.TryGetValue("id", out var idv) || !IsInteger(idv, out long id)) return Refuse("foliage: a model has no integer id");
                var m = new FoliageModel { Id = (int)id, Name = $"Model {i + 1}" };
                if (e.TryGetValue("name", out var nv))
                {
                    if (!(nv is string ns)) return Refuse("foliage: a model's name is not a string");
                    m.Name = ns;
                }
                if (e.TryGetValue("mesh", out var mv) && mv != null)
                {
                    if (!(mv is string ms)) return Refuse("foliage: a model's mesh is neither a path nor null");
                    m.Mesh = ms;
                }
                string bad = null;
                m.GroundOffset = Number(e, "ground_offset", m.GroundOffset, ref bad);
                m.Scale = Number(e, "scale", m.Scale, ref bad);
                m.ScaleRandom = Number(e, "scale_random", m.ScaleRandom, ref bad);
                m.Footprint = Number(e, "footprint", m.Footprint, ref bad);
                m.Height = Number(e, "height", m.Height, ref bad);
                m.Wind = Number(e, "wind", m.Wind, ref bad);
                if (bad != null) return Refuse($"foliage: model {i}: '{bad}' is not a number");
                if (!ids.Add(m.Id)) return Refuse($"foliage: model id {m.Id} appears twice");
                r.Models.Add(m);
            }
            object pl = fo.TryGetValue("plants", out var pv) ? pv : new List<object>();
            if (!(pl is List<object> flat) || flat.Count % 7 != 0) return Refuse("foliage: plants are not groups of seven numbers");
            for (int k = 0; k < flat.Count; k += 7)
            {
                for (int j = 0; j < 7; j++)
                    if (!IsNumber(flat[k + j])) return Refuse($"foliage: plant {k / 7} is not made of numbers");
                int model = (int)MBJson.AsDouble(flat[k]);
                if (!ids.Contains(model)) return Refuse($"foliage: plant {k / 7} uses model {model}, which does not exist");
                r.Plants.Add(new Plant
                {
                    Model = model, X = MBJson.AsDouble(flat[k + 1]), Y = MBJson.AsDouble(flat[k + 2]), Z = MBJson.AsDouble(flat[k + 3]),
                    Yaw = MBJson.AsDouble(flat[k + 4]), Scale = MBJson.AsDouble(flat[k + 5]), Planted = (long)MBJson.AsDouble(flat[k + 6]) != 0,
                });
            }
            return r;
        }

        static FileResult Refuse(string why) => new FileResult { Error = why };

        static double Number(Dictionary<string, object> e, string key, double fallback, ref string bad)
        {
            if (!e.TryGetValue(key, out var v)) return fallback;
            if (!IsNumber(v)) { bad = bad ?? key; return fallback; }
            return MBJson.AsDouble(v);
        }

        static bool IsNumber(object v) => v is long || v is double;

        static bool IsInteger(object v, out long value)
        {
            value = 0;
            if (v is long l) { value = l; return true; }
            if (v is double d && !double.IsNaN(d) && !double.IsInfinity(d) && Math.Floor(d) == d) { value = (long)d; return true; }
            return false;
        }

        static void Count(Dictionary<string, int> refused, string why) =>
            refused[why] = refused.TryGetValue(why, out var n) ? n + 1 : 1;

        static int Floor(double v) => (int)Math.Floor(v);
    }
}
