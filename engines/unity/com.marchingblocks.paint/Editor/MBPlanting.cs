// MarchingBlocks Paint for Unity — THE PLANT TOOL'S WORLD: what the foliage rule (MBFoliage, proven by
// Tests/foliage_conformance.json) asks of a world painted with this package, and the three gestures of the Plant tool —
// one plant, a dab of the brush, erase.
//
// The rule reads the world through three questions: is a cell FULL (every visible layer of the world), is there WATER at
// a point (the cells the world's MarchingBlocks Water deduces), and where is the GROUND under a point. The ground is the
// one you SEE: a vertical ray against the triangles of the tiles the layers placed (the rule: « each engine looks for the
// ground by a vertical ray against ITS placed tile meshes »); where it meets none — a layer without tiles — the ground of
// the cells (MBFoliage.GroundOfCells).
//
// Everything is in FORMAT space (cell c covers [c, c + 1]), converted through the frame of the foliage's layer.
// Nothing here touches the scene: each gesture returns the plants as they should be, and the editor sets them with Undo.

using System;
using System.Collections.Generic;
using UnityEngine;

namespace MarchingBlocks.Paint.EditorTools
{
    public sealed class PlantSettings
    {
        public int Model = -1;
        public FoliageMode Mode = FoliageMode.Free;
        public float Radius = 3f;
        public int Tries = 12;
        public float Spacing;
        public float MaxSlope = (float)MBFoliage.MaxSlopeDeg;
        public bool RandomYaw = true;
    }

    /// <summary>What a gesture did: the new list of plants (null: nothing changed) and what to say.</summary>
    public sealed class PlantResult
    {
        public List<MarchingBlocksFoliage.Plant> Plants;
        public string Status = "";
        public string Reason = "";
        public int Count;
    }

    public static class MBPlanting
    {
        const double Reach = 2000.0;

        static readonly Dictionary<string, string> Reasons = new Dictionary<string, string>
        {
            { "in_matter", "inside the matter" }, { "too_steep", "the ground is too steep" }, { "in_water", "in the water" },
            { "at_edge", "its footprint is not carried by the ground (an edge)" },
            { "under_matter", "the matter above leaves no room to grow" }, { "too_close", "too close to another plant" },
            { "already_there", "a plant is already there" }, { "no_ground", "no ground under it" },
        };

        public static string Reason(string code) => Reasons.TryGetValue(code, out var r) ? r : "refused";

        /// <summary>The MarchingBlocks Foliage of a layer's world (under the world's root, its frame one of the layers),
        /// or null.</summary>
        public static MarchingBlocksFoliage FoliageOf(MarchingBlocksWorld layer)
        {
            if (layer == null) return null;
            var layers = layer.Layers();
            var root = layer.transform.parent;
            var found = root != null ? root.GetComponentsInChildren<MarchingBlocksFoliage>(true)
                : layer.GetComponentsInChildren<MarchingBlocksFoliage>(true);
            foreach (var f in found)
                if (f.frameFrom == null || layers.Contains(f.frameFrom)) return f;
            return null;
        }

        /// <summary>The model the tool plants: the chosen one, or the first of the foliage when it is unknown. -1: none.</summary>
        public static int CurrentModel(MarchingBlocksFoliage f, int chosen)
        {
            if (f == null || f.models.Count == 0) return -1;
            foreach (var m in f.models) if (m.id == chosen) return chosen;
            return f.models[0].id;
        }

        static Dictionary<int, FoliageModel> Models(MarchingBlocksFoliage f)
        {
            var d = new Dictionary<int, FoliageModel>();
            foreach (var m in f.models) d[m.id] = f.ToRule(m);
            return d;
        }

        static Matrix4x4 FrameOf(MarchingBlocksFoliage f, MarchingBlocksWorld layer) =>
            (f != null && f.frameFrom != null ? f.frameFrom : layer).FormatToWorld;

        // ── What the rule asks of the world ──────────────────────────────────────────────────────────

        sealed class Tile
        {
            public Matrix4x4 ToFormat, ToLocal;
            public Mesh Mesh;
        }

        static readonly Dictionary<Mesh, (Vector3[] v, int[] t)> Triangles = new Dictionary<Mesh, (Vector3[], int[])>();

        /// <summary>What the rule asks of a world, built once per gesture.</summary>
        public sealed class Asked
        {
            public readonly HashSet<Int3> Full = new HashSet<Int3>();
            public readonly HashSet<Int3> Water = new HashSet<Int3>();
            readonly Dictionary<(int, int), List<Tile>> columns = new Dictionary<(int, int), List<Tile>>();
            public int Tiles;
            public FoliageWorld World;

            public Asked(MarchingBlocksWorld layer, Matrix4x4 formatToWorld)
            {
                var toFormat = formatToWorld.inverse;
                foreach (var l in layer.Layers())
                {
                    if (!l.isActiveAndEnabled) continue;
                    Full.UnionWith(l.Cells);
                    foreach (var p in l.PlacedObjects)
                    {
                        if (p.Object == null) continue;
                        var mf = p.Object.GetComponent<MeshFilter>();
                        if (mf == null || mf.sharedMesh == null) continue;
                        var t = new Tile { Mesh = mf.sharedMesh, ToFormat = toFormat * p.Object.transform.localToWorldMatrix };
                        t.ToLocal = t.ToFormat.inverse;
                        var b = mf.sharedMesh.bounds;
                        float x0 = float.MaxValue, x1 = float.MinValue, z0 = float.MaxValue, z1 = float.MinValue;
                        for (int k = 0; k < 8; k++)
                        {
                            var c = t.ToFormat.MultiplyPoint3x4(b.center + Vector3.Scale(b.extents,
                                new Vector3((k & 1) == 0 ? -1 : 1, (k & 2) == 0 ? -1 : 1, (k & 4) == 0 ? -1 : 1)));
                            x0 = Mathf.Min(x0, c.x); x1 = Mathf.Max(x1, c.x); z0 = Mathf.Min(z0, c.z); z1 = Mathf.Max(z1, c.z);
                        }
                        for (int x = Mathf.FloorToInt(x0); x <= Mathf.FloorToInt(x1); x++)
                            for (int z = Mathf.FloorToInt(z0); z <= Mathf.FloorToInt(z1); z++)
                            {
                                if (!columns.TryGetValue((x, z), out var list)) columns[(x, z)] = list = new List<Tile>();
                                list.Add(t);
                            }
                        Tiles++;
                    }
                }
                var root = layer.transform.parent;
                if (root != null)
                    foreach (var w in root.GetComponentsInChildren<MarchingBlocksWater>())
                        foreach (var ww in w.WaterCells())
                            foreach (var body in ww.Bodies)
                                if (body.Water != null) Water.UnionWith(body.Water);
                World = new FoliageWorld
                {
                    Full = Full.Contains,
                    Water = q => Water.Contains(MBFoliage.WaterCell(q)),
                    GroundAt = Ground,
                };
            }

            /// <summary>THE GROUND under (x, z), below yTop: the highest triangle of a placed tile a vertical ray meets (its
            /// normal turned up); none met: the ground of the cells.</summary>
            public Ground? Ground(double x, double z, double yTop)
            {
                Ground? best = null;
                if (columns.TryGetValue((Floor(x), Floor(z)), out var list))
                {
                    var from = new Vector3((float)x, (float)yTop, (float)z);
                    foreach (var t in list)
                    {
                        var o = t.ToLocal.MultiplyPoint3x4(from);
                        var d = t.ToLocal.MultiplyVector(Vector3.down);
                        var (v, tri) = TrianglesOf(t.Mesh);
                        for (int i = 0; i + 2 < tri.Length; i += 3)
                        {
                            Vector3 a = v[tri[i]], b = v[tri[i + 1]], c = v[tri[i + 2]];
                            if (!RayTriangle(o, d, a, b, c, out var hit)) continue;
                            var p = t.ToFormat.MultiplyPoint3x4(hit);
                            if (p.y > yTop || p.y < MBFoliage.GroundSearchFloor || (best != null && p.y <= best.Value.Y)) continue;
                            var n = t.ToLocal.transpose.MultiplyVector(Vector3.Cross(b - a, c - a)).normalized;
                            if (n.y < 0) n = -n;
                            best = new Ground { Y = p.y, Normal = new Double3(n.x, n.y, n.z) };
                        }
                    }
                }
                return best ?? MBFoliage.GroundOfCells(Full.Contains, x, z, yTop);
            }
        }

        static int Floor(double v) => (int)Math.Floor(v);

        static (Vector3[] v, int[] t) TrianglesOf(Mesh m)
        {
            if (!Triangles.TryGetValue(m, out var d)) Triangles[m] = d = (m.vertices, m.triangles);
            return d;
        }

        // Möller–Trumbore, both faces, forward only.
        static bool RayTriangle(Vector3 o, Vector3 d, Vector3 a, Vector3 b, Vector3 c, out Vector3 hit)
        {
            hit = default;
            Vector3 e1 = b - a, e2 = c - a, p = Vector3.Cross(d, e2);
            float det = Vector3.Dot(e1, p);
            if (Mathf.Abs(det) < 1e-9f) return false;
            float inv = 1f / det;
            Vector3 s = o - a;
            float u = Vector3.Dot(s, p) * inv;
            if (u < 0f || u > 1f) return false;
            Vector3 q = Vector3.Cross(s, e1);
            float w = Vector3.Dot(d, q) * inv;
            if (w < 0f || u + w > 1f) return false;
            float t = Vector3.Dot(e2, q) * inv;
            if (t < 0f) return false;
            hit = o + d * t;
            return true;
        }

        public static Asked Ask(MarchingBlocksWorld layer, MarchingBlocksFoliage f = null) => new Asked(layer, FrameOf(f, layer));

        /// <summary>WHERE A WORLD RAY MEETS THE WORLD for a mode, in format space: in the air, the plane of the floor;
        /// planted, the matter (the exact point of the face the ray enters by). False: nowhere.</summary>
        public static bool AimedPoint(MarchingBlocksWorld layer, MarchingBlocksFoliage f, Func<Int3, bool> full, Ray ray,
            FoliageMode mode, out Vector3 point)
        {
            point = default;
            var toFormat = FrameOf(f, layer).inverse;
            Vector3 o = toFormat.MultiplyPoint3x4(ray.origin);
            Vector3 d = toFormat.MultiplyVector(ray.direction).normalized;
            if (mode == FoliageMode.Air)
            {
                if (Mathf.Abs(d.y) < 1e-9f) return false;
                float t = (layer.floor - o.y) / d.y;
                if (t <= 0f) return false;
                point = o + d * t;
                return true;
            }
            var hit = MBTools.Ray(full, o.x, o.y, o.z, d.x, d.y, d.z, Reach);
            if (!hit.Touched) return false;
            int axis = hit.Normal.x != 0 ? 0 : hit.Normal.y != 0 ? 1 : 2;
            int cell = axis == 0 ? hit.Cell.x : axis == 1 ? hit.Cell.y : hit.Cell.z;
            int n = axis == 0 ? hit.Normal.x : axis == 1 ? hit.Normal.y : hit.Normal.z;
            float plane = cell + (n > 0 ? 1 : 0);
            if (Mathf.Abs(d[axis]) < 1e-12f) return false;
            point = o + d * ((plane - o[axis]) / d[axis]);
            point[axis] = plane;
            return true;
        }

        static MarchingBlocksFoliage.Plant FromRule(Plant p) => new MarchingBlocksFoliage.Plant
        {
            model = p.Model, point = new Vector3((float)p.X, (float)p.Y, (float)p.Z), yaw = (float)p.Yaw, scale = (float)p.Scale,
            planted = p.Planted,
        };

        // ── The three gestures ─────────────────────────────────────────────────────────────────────

        /// <summary>ONE PLANT where the ray points. <paramref name="draw"/>: yaw, then scale.</summary>
        public static PlantResult PlantAt(MarchingBlocksWorld layer, MarchingBlocksFoliage f, Ray ray, PlantSettings s,
            System.Random draw, Asked asked = null)
        {
            var models = Models(f);
            int id = CurrentModel(f, s.Model);
            if (id < 0) return new PlantResult { Status = "Plant — choose a model (the foliage of this world has none).", Reason = "no_model" };
            var m = models[id];
            asked = asked ?? Ask(layer, f);
            if (!AimedPoint(layer, f, asked.World.Full, ray, s.Mode, out var aim))
                return new PlantResult { Status = "Plant — point at the world.", Reason = "no_ground" };
            var p = new Plant { Model = id, X = aim.x, Y = aim.y, Z = aim.z, Planted = s.Mode != FoliageMode.Air };
            var normal = new Double3(0, 1, 0);
            if (s.Mode != FoliageMode.Air)
            {
                var g = asked.World.GroundAt(aim.x, aim.z, aim.y + 1.0);
                if (g == null) return new PlantResult { Status = "Plant — not planted: no ground under it.", Reason = "no_ground" };
                p.Y = g.Value.Y;
                normal = g.Value.Normal;
            }
            p.Yaw = s.RandomYaw ? draw.NextDouble() * 2.0 * Math.PI : 0.0;
            p.Scale = MBFoliage.DrawScale(m, draw.NextDouble());
            var there = new List<Plant>();
            foreach (var q in f.plants) there.Add(MarchingBlocksFoliage.ToRule(q));
            var index = new PlantIndex(models, there);
            string why = MBFoliage.Check(m, p, normal, s.Mode, asked.World, index, models, s.Spacing, s.MaxSlope);
            if (why != "") return new PlantResult { Status = $"Plant — not planted: {Reason(why)}.", Reason = why };
            var list = new List<MarchingBlocksFoliage.Plant>(f.plants) { FromRule(p) };
            return new PlantResult { Plants = list, Status = $"Plant — planted ({list.Count} plant(s)).", Count = 1 };
        }

        /// <summary>A DAB OF THE BRUSH around the point the ray meets: Tries spots drawn in the disc (angle, distance, yaw,
        /// scale — the tool's order), each put on the ground and checked; accepted ones respect each other.</summary>
        public static PlantResult SowAt(MarchingBlocksWorld layer, MarchingBlocksFoliage f, Ray ray, PlantSettings s,
            System.Random draw, Asked asked = null)
        {
            var models = Models(f);
            int id = CurrentModel(f, s.Model);
            if (id < 0) return new PlantResult { Status = "Plant — choose a model (the foliage of this world has none)." };
            var m = models[id];
            asked = asked ?? Ask(layer, f);
            if (!AimedPoint(layer, f, asked.World.Full, ray, s.Mode, out var centre))
                return new PlantResult { Status = "Plant — point at the world." };
            var candidates = new List<BrushCandidate>();
            for (int i = 0; i < s.Tries; i++)
            {
                double angle = draw.NextDouble() * 2.0 * Math.PI;
                double dist = Math.Sqrt(draw.NextDouble()) * s.Radius;
                double yaw = s.RandomYaw ? draw.NextDouble() * 2.0 * Math.PI : 0.0;
                double scale = MBFoliage.DrawScale(m, draw.NextDouble());
                candidates.Add(new BrushCandidate { X = centre.x + Math.Cos(angle) * dist, Z = centre.z + Math.Sin(angle) * dist, Yaw = yaw, Scale = scale });
            }
            var there = new List<Plant>();
            foreach (var q in f.plants) there.Add(MarchingBlocksFoliage.ToRule(q));
            var index = new PlantIndex(models, there);
            // The ground is looked for below the dab (planted), or the plane itself (in the air).
            double yTop = s.Mode == FoliageMode.Air ? centre.y : centre.y + 1.5;
            var r = MBFoliage.Brush(m, yTop, candidates, s.Mode, asked.World, index, models, s.Spacing, s.MaxSlope);
            var refused = new List<string>();
            foreach (var kv in r.Refused) refused.Add($"{kv.Value} {kv.Key.Replace('_', ' ')}");
            string said = refused.Count > 0 ? ", refused: " + string.Join(", ", refused) : "";
            if (r.Plants.Count == 0) return new PlantResult { Status = $"Plant — nothing planted in this dab{said}." };
            var list = new List<MarchingBlocksFoliage.Plant>(f.plants);
            foreach (var p in r.Plants) list.Add(FromRule(p));
            return new PlantResult { Plants = list, Status = $"Plant — {r.Plants.Count} planted{said}.", Count = r.Plants.Count };
        }

        /// <summary>ERASE around the point the ray meets: the plants within the radius in the plane, within radius + 2 in
        /// height and radius + 0.5 in space (the tool's rule).</summary>
        public static PlantResult EraseAt(MarchingBlocksWorld layer, MarchingBlocksFoliage f, Ray ray, PlantSettings s, Asked asked = null)
        {
            asked = asked ?? Ask(layer, f);
            if (!AimedPoint(layer, f, asked.World.Full, ray, s.Mode, out var centre))
                return new PlantResult { Status = "Plant — point at the world." };
            var kept = new List<MarchingBlocksFoliage.Plant>();
            int removed = 0;
            foreach (var p in f.plants)
            {
                var q = p.point;
                if (new Vector2(q.x - centre.x, q.z - centre.z).magnitude <= s.Radius && Mathf.Abs(q.y - centre.y) <= s.Radius + 2f
                    && Vector3.Distance(q, centre) <= s.Radius + 0.5f) { removed++; continue; }
                kept.Add(p);
            }
            if (removed == 0) return new PlantResult { Status = "Plant — no plant within the brush to erase." };
            return new PlantResult { Plants = kept, Status = $"Plant — {removed} removed, {kept.Count} left.", Count = removed };
        }
    }
}
