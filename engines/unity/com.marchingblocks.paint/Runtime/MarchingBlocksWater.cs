// MarchingBlocks Paint for Unity — THE WATER OF A WORLD.
//
// world.json may carry `water`: layers of water, each with its sources and the sheet MarchingBlocks BAKED (water/<name>.glb,
// in format space; every vertex carries the water data — COLOR_0 r, g the flow, b the kind, a the depth or the foam).
// Import World puts this component on a child of the world's root; it shows each sheet (never saved with the scene),
// with the material you choose — the six looks shipped with the plugin (MarchingBlocks/Water) are EXAMPLES, not an
// obligation: any shader that reads the vertex colours gets the same data.
//
// WHEN YOU PAINT, the water is deduced again from the sources and the cells of every layer (MBWater.World, the rule of
// MarchingBlocks, Tests/water_conformance.json) and its SHEET is rebuilt (MBWaterMesh, MarchingBlocks' eau_maillage,
// Tests/water_mesh_conformance.json) — the same triangles MarchingBlocks bakes:
//   - never during a stroke: the sheet is only said STALE (MBWaterFollow);
//   - after half a second without a new gesture, on a worker thread, from a COPY of the cells; only what the gesture
//     reached is computed again (the reprise of MarchingBlocks: a body whose footprint was not touched is taken again,
//     with its sheet); the new meshes are swapped in on the main thread;
//   - "Rebuild water" (the inspector, or RebuildWater()) is always there; the automatic follow cuts itself when a rebuild
//     took more than a second (a very large sea), and the sheet stays stale until the button.
// Until the first rebuild the baked sheet is shown; the rebuilt sheet replaces it, placed the same way.

using System.Collections.Generic;
using System.Diagnostics;
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.Rendering;

namespace MarchingBlocks.Paint
{
    [ExecuteAlways]
    [AddComponentMenu("MarchingBlocks/MarchingBlocks Water")]
    public sealed class MarchingBlocksWater : MonoBehaviour
    {
        [System.Serializable]
        public struct Layer
        {
            public string name;
            public bool visible;
            [Tooltip("A suggestion of the author: stylized, clear, reflective, lava, swamp, acid (or anything else).")]
            public string look;
            [Tooltip("The baked sheet (water/<name>.glb) as your glTF importer made it; shown until the water is rebuilt.")]
            public GameObject sheet;
            [Tooltip("The material of the sheet: one of the six looks, or yours.")]
            public Material material;
            [Tooltip("Where the water was placed, in format space.")]
            public List<Vector3Int> sources;
        }

        [Tooltip("The layer whose tileset gives the frame (the conversion of your glTF importer) and the cell size.")]
        public MarchingBlocksWorld frameFrom;
        public List<Layer> layers = new List<Layer>();

        /// <summary>Where the ground of the tiles is drawn (world.json water_floor): the heights of the rebuilt sheet follow it.</summary>
        public enum Floor { Inset, Centred, Outset }
        [Tooltip("Where the ground of the tiles is drawn, for the heights of the rebuilt water (world.json water_floor): " +
            "inset 0.25, centred 0, outset -0.25. Set by the import.")]
        public Floor waterFloor = Floor.Inset;
        /// <summary>The floor r of waterFloor: 0.25, 0 or −0.25.</summary>
        public double FloorValue => waterFloor == Floor.Centred ? 0.0 : waterFloor == Floor.Outset ? -0.25 : 0.25;
        /// <summary>The Floor of a water_floor value (0.25, 0, −0.25; anything else: inset).</summary>
        public static Floor FloorKindOf(double r) => r == 0.0 ? Floor.Centred : r == -0.25 ? Floor.Outset : Floor.Inset;
        [Tooltip("Rebuild the water sheets half a second after each gesture (on a worker thread). Cuts itself when a rebuild " +
            "takes more than a second: then use Rebuild water.")]
        public bool followPainting = true;

        const string ContainerName = "MarchingBlocks water (generated)";
        readonly List<WaterWorld> lastWorlds = new List<WaterWorld>();
        static MaterialPropertyBlock block;
        static Material fallbackMaterial;

        // ── the rebuilt sheets ──
        readonly MBWaterFollow follow = new MBWaterFollow();
        Mesh[] rebuilt;
        // What the worker reads and writes (one rebuild at a time): the previous water, the cells it was computed on, the
        // mesher's memory of each water layer.
        WaterWorld previous;
        HashSet<Int3> previousCells;
        readonly List<WaterMeshMemory> memories = new List<WaterMeshMemory>();
        Task<Result> running;
        int runningTicket;
        Stopwatch runningClock;

        /// <summary>When the sheet is rebuilt, and whether it is stale (read by the inspector).</summary>
        public MBWaterFollow Follow => follow;
        /// <summary>The last rebuild, said: bodies taken again, times.</summary>
        public string LastRebuildReport { get; private set; } = "";
        /// <summary>The bodies taken again by the last rebuild, and how many there were.</summary>
        public int LastTaken { get; private set; }
        public int LastBodies { get; private set; }
        /// <summary>The rebuilt sheet of a layer (importer space, placed like the baked one), or null (the baked one shows).</summary>
        public Mesh RebuiltMesh(int layer) => rebuilt != null && layer < rebuilt.Length ? rebuilt[layer] : null;
        /// <summary>A rebuild is running on the worker thread.</summary>
        public bool Rebuilding => running != null;

        sealed class Result
        {
            public WaterWorld World;
            public HashSet<Int3> Cells;
            public List<WaterSheetArrays> Sheets = new List<WaterSheetArrays>();
            public int Taken, Bodies;
            public double WorkerSeconds;
        }

        void OnEnable()
        {
            MarchingBlocksWorld.Rebuilt += OnLayerRebuilt;
#if UNITY_EDITOR
            UnityEditor.EditorApplication.update += Tick;
#endif
            follow.Enabled = followPainting;
            Rebuild();
        }

        void OnDisable()
        {
            MarchingBlocksWorld.Rebuilt -= OnLayerRebuilt;
#if UNITY_EDITOR
            UnityEditor.EditorApplication.update -= Tick;
#endif
        }

        void OnDestroy()
        {
            if (rebuilt != null) foreach (var m in rebuilt) if (m != null) DestroyImmediate(m);
        }

        void OnValidate()
        {
            follow.Enabled = followPainting;
            // The sources may have changed: the sheet is stale.
            follow.Changed(Now());
#if UNITY_EDITOR
            UnityEditor.EditorApplication.delayCall += () => { if (this != null && isActiveAndEnabled) Rebuild(); };
#endif
        }

        void OnLayerRebuilt(MarchingBlocksWorld layer)
        {
            if (this == null || !isActiveAndEnabled || layer.transform.parent != transform.parent) return;
            lastWorlds.Clear();
            follow.Changed(Now());
        }

        static double Now()
        {
#if UNITY_EDITOR
            return UnityEditor.EditorApplication.timeSinceStartup;
#else
            return Time.realtimeSinceStartupAsDouble;
#endif
        }

        void Update()
        {
            if (Application.isPlaying) Tick();
        }

        /// <summary>The follow, one step: a finished rebuild is swapped in; a due one (the gesture over, the calm) starts on
        /// a worker thread. Called by the editor's update loop (in play mode, by Update).</summary>
        public void Tick()
        {
            if (this == null || !isActiveAndEnabled) return;
            if (running != null && running.IsCompleted) Collect();
            // Un geste tenu : un outil de la vue (le pinceau, une boîte, la poignée d'Unity) a la main.
            if (follow.Due(Now(), GUIUtility.hotControl != 0)) Launch();
        }

        void Launch()
        {
            var cells = AllCells();
            var sources = SourcesByLayer();
            var before = previous;
            var beforeCells = previousCells;
            double floor = FloorValue;
            runningTicket = follow.Start();
            runningClock = Stopwatch.StartNew();
            running = Task.Run(() => Compute(cells, sources, before, beforeCells, memories, floor));
        }

        void Collect()
        {
            var task = running;
            running = null;
            if (task.IsFaulted)
            {
                follow.Failed();
                UnityEngine.Debug.LogException(task.Exception);
                return;
            }
            Swap(task.Result, runningTicket, runningClock);
        }

        /// <summary>REBUILD WATER: the sheets again, now, on this thread (the button). Waits for a running rebuild first.</summary>
        public void RebuildWater()
        {
            if (running != null)
            {
                try { running.Wait(); } catch (System.AggregateException) { }
                Collect();
            }
            var clock = Stopwatch.StartNew();
            int ticket = follow.Start();
            Result r;
            try { r = Compute(AllCells(), SourcesByLayer(), previous, previousCells, memories, FloorValue); }
            catch { follow.Failed(); throw; }
            Swap(r, ticket, clock);
        }

        // Le résultat d'une reconstruction : gardé pour la reprise suivante, posé s'il est encore celui du monde. Le temps est
        // compté jusqu'aux maillages posés : c'est lui qui coupe le suivi.
        void Swap(Result r, int ticket, Stopwatch clock)
        {
            previous = r.World;
            previousCells = r.Cells;
            bool current = follow.Current(ticket);
            if (current)
            {
                var frame = frameFrom != null ? frameFrom.ImporterFrameInverse.inverse : Matrix4x4.identity;
                var meshes = new Mesh[layers.Count];
                for (int i = 0; i < layers.Count && i < r.Sheets.Count; i++) meshes[i] = ToMesh(r.Sheets[i], frame, layers[i].name);
                if (rebuilt != null) foreach (var m in rebuilt) if (m != null) DestroyImmediate(m);
                rebuilt = meshes;
                Rebuild();
            }
            follow.Finished(ticket, clock.Elapsed.TotalSeconds);
            LastTaken = r.Taken;
            LastBodies = r.Bodies;
            LastRebuildReport = $"{(current ? "" : "obsolete, not shown: ")}{r.Taken} of {r.Bodies} bodies taken again, " +
                $"{clock.Elapsed.TotalMilliseconds:F0} ms (worker {r.WorkerSeconds * 1000:F0} ms)";
        }

        /// <summary>Forgets the rebuilt sheets and shows the BAKED ones again (until the next rebuild, which starts afresh).</summary>
        public void ShowBakedSheets()
        {
            if (running != null) { try { running.Wait(); } catch (System.AggregateException) { } running = null; follow.Failed(); }
            if (rebuilt != null) foreach (var m in rebuilt) if (m != null) DestroyImmediate(m);
            rebuilt = null;
            previous = null;
            previousCells = null;
            memories.Clear();
            Rebuild();
        }

        /// <summary>The cells of every tile layer of the world (hidden ones too), copied.</summary>
        HashSet<Int3> AllCells()
        {
            var cells = new HashSet<Int3>();
            if (transform.parent != null)
                for (int i = 0; i < transform.parent.childCount; i++)
                {
                    var w = transform.parent.GetChild(i).GetComponent<MarchingBlocksWorld>();
                    if (w != null) cells.UnionWith(w.Cells);
                }
            return cells;
        }

        List<List<Int3>> SourcesByLayer()
        {
            var o = new List<List<Int3>>();
            foreach (var l in layers)
            {
                var s = new List<Int3>();
                if (l.sources != null) foreach (var c in l.sources) s.Add(new Int3(c.x, c.y, c.z));
                o.Add(s);
            }
            return o;
        }

        // ── pur C# : ce qui tourne sur le fil ──

        static Result Compute(HashSet<Int3> cells, List<List<Int3>> sources, WaterWorld before, HashSet<Int3> beforeCells,
            List<WaterMeshMemory> memories, double floor = MBWaterMesh.FloorDefault)
        {
            var clock = Stopwatch.StartNew();
            var all = new List<Int3>();
            foreach (var l in sources) all.AddRange(l);
            HashSet<Int3> changed = before != null && beforeCells != null ? MBWater.ChangedBetween(beforeCells, cells) : null;
            var w = MBWater.World(cells, all, before, changed);
            var r = new Result { World = w, Cells = cells, Bodies = all.Count };
            while (memories.Count < sources.Count) memories.Add(new WaterMeshMemory());
            int k = 0;
            for (int i = 0; i < sources.Count; i++)
            {
                var bodies = w.Bodies.GetRange(k, sources[i].Count);
                if (before != null)
                    for (int j = 0; j < bodies.Count; j++)
                        if (k + j < before.Bodies.Count && ReferenceEquals(bodies[j], before.Bodies[k + j])) r.Taken++;
                k += sources[i].Count;
                // Le sol : un autre sol vide la mémoire de la couche (MBWaterMesh.Arrays), les hauteurs ont changé.
                r.Sheets.Add(MBWaterMesh.Arrays(bodies, cells, w.Box, memories[i], floor));
            }
            r.WorkerSeconds = clock.Elapsed.TotalSeconds;
            return r;
        }

        /// <summary>A sheet (format space, glTF winding) as a Unity mesh in the IMPORTER's space — the space of the baked
        /// sheet as the glTF importer made it, so that it is placed the same way: positions and normals through the frame
        /// (MEASURED on the tileset: glTFast mirrors X), v flipped (glTFast flips v: the shaders flip it back), the winding
        /// reversed when the frame mirrors.</summary>
        public static Mesh ToMesh(WaterSheetArrays a, Matrix4x4 frame, string name)
        {
            int n = a.VertexCount;
            var v = new Vector3[n];
            var nn = new Vector3[n];
            var c = new Color[n];
            var uv = new Vector2[n];
            for (int i = 0; i < n; i++)
            {
                var p = a.Positions[i];
                var q = a.Normals[i];
                v[i] = frame.MultiplyPoint3x4(new Vector3(p.x, p.y, p.z));
                nn[i] = frame.MultiplyVector(new Vector3(q.x, q.y, q.z)).normalized;
                c[i] = new Color(a.Colors[4 * i], a.Colors[4 * i + 1], a.Colors[4 * i + 2], a.Colors[4 * i + 3]);
                uv[i] = new Vector2(a.UVs[2 * i], 1f - a.UVs[2 * i + 1]);
            }
            var t = a.Triangles.ToArray();
            if (frame.determinant < 0f)
                for (int k = 0; k < t.Length; k += 3) (t[k + 1], t[k + 2]) = (t[k + 2], t[k + 1]);
            var m = new Mesh { name = name + " (rebuilt)", hideFlags = HideFlags.DontSave };
            m.indexFormat = n > 65535 ? IndexFormat.UInt32 : IndexFormat.UInt16;
            m.vertices = v;
            m.normals = nn;
            m.colors = c;
            m.uv = uv;
            m.triangles = t;
            m.RecalculateBounds();
            return m;
        }

        /// <summary>Shows every sheet again: the rebuilt one of a layer when there is one, else the baked one.</summary>
        public void Rebuild()
        {
            var container = transform.Find(ContainerName);
            if (container == null)
            {
                var go = new GameObject(ContainerName) { hideFlags = HideFlags.DontSave };
                container = go.transform;
                container.SetParent(transform, false);
            }
            for (int i = container.childCount - 1; i >= 0; i--)
            {
                var child = container.GetChild(i).gameObject;
                if (Application.isPlaying) Destroy(child); else DestroyImmediate(child);
            }
            lastWorlds.Clear();
            if (!isActiveAndEnabled) return;
            Matrix4x4 formatToWorld = frameFrom != null ? frameFrom.FormatToWorld : transform.localToWorldMatrix;
            Matrix4x4 importerInverse = frameFrom != null ? frameFrom.ImporterFrameInverse : Matrix4x4.identity;
            var world = formatToWorld * importerInverse;
            for (int li = 0; li < layers.Count; li++)
            {
                var l = layers[li];
                var mesh = RebuiltMesh(li);
                GameObject go;
                if (mesh != null)
                {
                    go = new GameObject(l.name, typeof(MeshFilter), typeof(MeshRenderer));
                    go.transform.SetParent(container, false);
                    go.GetComponent<MeshFilter>().sharedMesh = mesh;
                    if (l.material == null)
                    {
                        if (fallbackMaterial == null)
                            fallbackMaterial = new Material(Shader.Find("MarchingBlocks/Water")) { hideFlags = HideFlags.DontSave };
                        go.GetComponent<MeshRenderer>().sharedMaterial = fallbackMaterial;
                    }
                }
                else if (l.sheet != null) go = Instantiate(l.sheet, container);
                else continue;
                go.name = l.name;
                go.hideFlags = HideFlags.DontSave;
                go.transform.position = world.GetColumn(3);
                go.transform.rotation = world.rotation;
                var ps = container.lossyScale;
                var ls = world.lossyScale;
                go.transform.localScale = new Vector3(ls.x / ps.x, ls.y / ps.y, ls.z / ps.z);
                if (block == null) block = new MaterialPropertyBlock();
                foreach (var r in go.GetComponentsInChildren<Renderer>(true))
                {
                    if (l.material != null)
                    {
                        var mats = r.sharedMaterials;
                        for (int k = 0; k < mats.Length; k++) mats[k] = l.material;
                        r.sharedMaterials = mats;
                    }
                    r.shadowCastingMode = ShadowCastingMode.Off;
                    // The looks work in FORMAT space (cells), as in MarchingBlocks.
                    block.Clear();
                    block.SetMatrix("_MBWorldToFormat", formatToWorld.inverse);
                    block.SetMatrix("_MBFormatToWorld", formatToWorld);
                    r.SetPropertyBlock(block);
                }
                go.SetActive(l.visible);
            }
        }

        /// <summary>The water deduced NOW from the sources and the cells of every layer of the world (hidden ones too) —
        /// one result per water layer, in order. ONE sea: taking the sources of every water layer in order, a second
        /// source in the void is refused (one_sea_only).</summary>
        public List<WaterWorld> WaterCells()
        {
            if (lastWorlds.Count == layers.Count) return lastWorlds;
            lastWorlds.Clear();
            var cells = AllCells();
            // The sources of every layer, in order, through the rule at once (the sea is decided across layers).
            var all = new List<Int3>();
            var owner = new List<int>();
            for (int i = 0; i < layers.Count; i++)
                if (layers[i].sources != null)
                    foreach (var s in layers[i].sources) { all.Add(new Int3(s.x, s.y, s.z)); owner.Add(i); }
            var result = MBWater.World(cells, all);
            for (int i = 0; i < layers.Count; i++)
            {
                var mine = new WaterWorld();
                for (int k = 0; k < all.Count; k++)
                    if (owner[k] == i) mine.Bodies.Add(result.Bodies[k]);
                mine.Sea.UnionWith(result.Sea);
                lastWorlds.Add(mine);
            }
            return lastWorlds;
        }

        void OnDrawGizmosSelected()
        {
            if (frameFrom == null) return;
            var m = Gizmos.matrix;
            Gizmos.matrix = frameFrom.FormatToWorld;
            Gizmos.color = new Color(0.2f, 0.6f, 1f, 0.35f);
            foreach (var w in WaterCells())
                foreach (var b in w.Bodies)
                {
                    if (b.Water == null) continue;
                    foreach (var c in b.Water) Gizmos.DrawCube(new Vector3(c.x + 0.5f, c.y + 0.5f, c.z + 0.5f), Vector3.one * 0.9f);
                    foreach (var step in b.Course)
                        Gizmos.DrawCube(new Vector3(step.Cell.x + 0.5f, step.Cell.y + 0.5f, step.Cell.z + 0.5f), Vector3.one * 0.6f);
                }
            Gizmos.matrix = m;
        }
    }
}
