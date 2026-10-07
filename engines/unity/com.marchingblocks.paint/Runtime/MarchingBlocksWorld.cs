// MarchingBlocks Paint for Unity — ONE WORLD LAYER: you paint cells, the tiles follow.
//
// Cells are stored in FORMAT space (the tileset's own grid). What you see is converted through the
// tileset's measured frame, so the cells and the tiles always agree, whatever your glTF importer did.
// One component is one LAYER, with its own tileset. MarchingBlocksWorld components on SIBLING GameObjects (the
// children of one parent) are the layers of ONE world (rock, ice…), and their order among the children is
// their PRIORITY (the first is the highest). The rule reads every active layer together — no wall where two
// layers meet — and a vertex is placed by the highest layer among its 8 cells, with that layer's tiles. A
// cell belongs to one layer: Apply removes the cells it sets from the other layers. An inactive layer is
// hidden: the world closes without it.
//
// The generated tiles are NOT saved with the scene: they are rebuilt from the cells whenever the
// component is enabled, so a scene only stores what you painted.

using System.Collections.Generic;
using UnityEngine;

namespace MarchingBlocks.Paint
{
    [ExecuteAlways]
    [AddComponentMenu("MarchingBlocks/MarchingBlocks World")]
    public sealed class MarchingBlocksWorld : MonoBehaviour
    {
        [Tooltip("The tileset.json inside a .mbset folder made by MarchingBlocks.")]
        public TextAsset tileset;
        [Tooltip("The tiles.glb of the same .mbset folder, as imported by your glTF importer (glTFast, UnityGLTF…).")]
        public GameObject tiles;
        [Tooltip("The animated copies of the tileset's materials (textures animated in MarchingBlocks). Made by Import World, or by the button below.")]
        public MBAnimatedSet animatedMaterials;
        [Tooltip("Size of one cell, in Unity units.")]
        [Min(0.01f)] public float cellSize = 1f;
        [Tooltip("The floor the brush paints on, in cells.")]
        public int floor;

        [SerializeField, HideInInspector] List<Vector3Int> cells = new List<Vector3Int>();

        /// <summary>VARIANTS (the tileset rule, step 8) — the weights of the random draw for one key:
        /// [base, variant 1, variant 2, …] (a missing entry is 1, a negative one 0).</summary>
        [System.Serializable]
        public struct VariantWeight
        {
            public string key;
            public int[] weights;
        }

        /// <summary>The variant CHOSEN at a vertex (format space): 0 is the base tile. The Variant tool sets it.</summary>
        [System.Serializable]
        public struct VariantChoice
        {
            public Vector3Int vertex;
            public int choice;
        }

        [Tooltip("Variants: the weights of the random draw per key — base tile first, then each variant. Same world, same tiles: the draw is a hash of the vertex, never random.")]
        public List<VariantWeight> variantWeights = new List<VariantWeight>();
        [SerializeField, HideInInspector] List<VariantChoice> variantChoices = new List<VariantChoice>();
        // The tile placed at each vertex by the last Rebuild — what the Variant tool reads.
        [System.NonSerialized] Dictionary<Int3, string> placedTiles = new Dictionary<Int3, string>();
        // An INDEX of the list above, never a second copy of the truth: rebuilt from the list whenever
        // it may have changed behind our back (undo, a scene reload, OnValidate).
        [System.NonSerialized] HashSet<Int3> index;

        /// <summary>A tile placed by the last Rebuild: its vertex (format space) and its GameObject.</summary>
        public readonly struct PlacedTile
        {
            public readonly Int3 Vertex;
            public readonly GameObject Object;
            public PlacedTile(Int3 vertex, GameObject o) { Vertex = vertex; Object = o; }
        }

        /// <summary>Every tile placed by the last Rebuild (red cubes of missing tiles excluded).</summary>
        public IReadOnlyList<PlacedTile> PlacedObjects => placedObjects;
        [System.NonSerialized] readonly List<PlacedTile> placedObjects = new List<PlacedTile>();

        /// <summary>Raised at the end of every Rebuild of a layer: what dresses the tiles (transitions, animated
        /// materials) dresses them again. Not raised by a hidden layer, which places nothing.</summary>
        public static event System.Action<MarchingBlocksWorld> Rebuilt;

        const string ContainerName = "MarchingBlocks tiles (generated)";
        MBTileset loaded;
        static MaterialPropertyBlock phaseBlock;
        static Mesh errorMesh;
        static Material errorMaterial;

        public string LastError { get; private set; } = "";
        public int LastPlaced { get; private set; }
        public int LastMissing { get; private set; }
        public int CellCount => cells.Count;

        void OnEnable() => RebuildWorld();

        void OnDisable()
        {
            // A hidden layer leaves the world: the others close without it. Not while the scene closes —
            // its layers are going too.
            if (!gameObject.scene.isLoaded) return;
            foreach (var l in Layers()) if (l != this && l != null && l.isActiveAndEnabled) l.Rebuild();
        }

        /// <summary>The layers of this component's world, in priority order: the MarchingBlocksWorld
        /// components on this GameObject's siblings (itself included); just itself without a parent.</summary>
        public List<MarchingBlocksWorld> Layers()
        {
            var result = new List<MarchingBlocksWorld>();
            var parent = transform.parent;
            if (parent == null) { result.Add(this); return result; }
            for (int i = 0; i < parent.childCount; i++)
            {
                var w = parent.GetChild(i).GetComponent<MarchingBlocksWorld>();
                if (w != null) result.Add(w);
            }
            return result;
        }

        /// <summary>Every layer of the world, as Unity objects — record them ALL before Apply
        /// (Undo.RecordObjects): Apply takes cells from the other layers.</summary>
        public Object[] LayerObjects() => Layers().ToArray();

        /// <summary>Rebuilds every layer of the world (a change of cells moves the borders of the others).</summary>
        public void RebuildWorld()
        {
            foreach (var l in Layers()) l.Rebuild();
        }

        void OnValidate()
        {
            loaded = null;
#if UNITY_EDITOR
            // Objects cannot be created or destroyed inside OnValidate.
            UnityEditor.EditorApplication.delayCall += () => { if (this != null) Rebuild(); };
#endif
        }

        /// <summary>The painted cells, in format space. Read-only: change them through Apply or SetCell.</summary>
        public HashSet<Int3> Cells
        {
            get
            {
                if (index == null || index.Count != cells.Count) Reindex();
                return index;
            }
        }

        void Reindex()
        {
            index = new HashSet<Int3>();
            foreach (var c in cells) index.Add(new Int3(c.x, c.y, c.z));
        }

        public bool HasCell(Vector3Int c) => Cells.Contains(new Int3(c.x, c.y, c.z));

        /// <summary>Adds or removes a cell. Call Rebuild() afterwards (once per stroke is enough).</summary>
        public void SetCell(Vector3Int c, bool full)
        {
            var k = new Int3(c.x, c.y, c.z);
            if (full && Cells.Add(k)) cells.Add(c);
            else if (!full && Cells.Remove(k)) cells.Remove(c);
        }

        /// <summary>Applies what a tool returned (MBTools.cs): clears, then sets. Record the undo BEFORE
        /// calling this (Undo.RecordObject); the tiles are rebuilt once. Returns the cells changed.</summary>
        public int Apply(Change change)
        {
            int n = 0;
            var set = Cells;
            foreach (var c in change.Clear) if (set.Remove(c)) n++;
            foreach (var c in change.Set) if (set.Add(c)) n++;
            // A CELL BELONGS TO ONE LAYER: what this change sets leaves the other layers of the world.
            foreach (var l in Layers())
                if (l != this && l.Take(change.Set) > 0) n++;
            if (n == 0) return 0;
            // The list is rewritten in ONE pass: removing cell by cell from a List is quadratic, and a
            // box of a few thousand cells would freeze the editor.
            cells.Clear();
            foreach (var c in set) cells.Add(new Vector3Int(c.x, c.y, c.z));
            RebuildWorld();
            return n;
        }

        public void ClearCells() { cells.Clear(); index = null; }

        /// <summary>Removes these cells from this layer, without rebuilding. Returns how many it held.</summary>
        public int Take(IEnumerable<Int3> taken)
        {
            int n = 0;
            var set = Cells;
            foreach (var c in taken) if (set.Remove(c)) n++;
            if (n == 0) return 0;
            cells.Clear();
            foreach (var c in set) cells.Add(new Vector3Int(c.x, c.y, c.z));
            return n;
        }

        /// <summary>Replaces ALL the cells (format space), in one pass — a duplicate is kept once. Record the
        /// undo before calling this; call Rebuild() afterwards.</summary>
        /// <summary>The variant settings of this layer (step 8), for the rule.</summary>
        public VariantSettings Variants
        {
            get
            {
                var s = new VariantSettings();
                foreach (var w in variantWeights)
                    if (!string.IsNullOrEmpty(w.key) && w.weights != null) s.Weights[w.key] = w.weights;
                foreach (var c in variantChoices)
                    s.Choices[new Int3(c.vertex.x, c.vertex.y, c.vertex.z)] = c.choice;
                return s;
            }
        }

        /// <summary>The weights of one key's draw (null removes them). Record the undo first; rebuilds.</summary>
        public void SetVariantWeights(string key, int[] weights)
        {
            variantWeights.RemoveAll(w => w.key == key);
            if (weights != null) variantWeights.Add(new VariantWeight { key = key, weights = weights });
            Rebuild();
        }

        /// <summary>The variant chosen at a vertex (null gives it back to the draw). Record the undo first
        /// (Undo.RecordObject); rebuilds.</summary>
        public void SetVariantChoice(Int3 vertex, int? choice)
        {
            variantChoices.RemoveAll(c => c.vertex.x == vertex.x && c.vertex.y == vertex.y && c.vertex.z == vertex.z);
            if (choice.HasValue)
                variantChoices.Add(new VariantChoice { vertex = new Vector3Int(vertex.x, vertex.y, vertex.z), choice = choice.Value });
            Rebuild();
        }

        /// <summary>Replaces every variant weight and choice, WITHOUT rebuilding (the importer fills an inactive
        /// layer; it is built when it becomes active).</summary>
        public void SetVariants(Dictionary<string, int[]> weights, IEnumerable<KeyValuePair<Int3, int>> choices)
        {
            variantWeights.Clear();
            foreach (var kv in weights) variantWeights.Add(new VariantWeight { key = kv.Key, weights = kv.Value });
            variantChoices.Clear();
            foreach (var kv in choices)
                variantChoices.Add(new VariantChoice { vertex = new Vector3Int(kv.Key.x, kv.Key.y, kv.Key.z), choice = kv.Value });
        }

        /// <summary>Every chosen variant, {vertex: choice}.</summary>
        public Dictionary<Int3, int> VariantChoices => Variants.Choices;

        /// <summary>The tile this layer placed at a vertex: its key, how many variants the key has, which one is
        /// placed (0 the base). False when this layer placed nothing there.</summary>
        public bool VariantAt(Int3 vertex, out string key, out int count, out int current)
        {
            key = null; count = 0; current = 0;
            var set = Tileset;
            if (set == null || !placedTiles.TryGetValue(vertex, out var tile) || tile == null) return false;
            foreach (var kv in set.Rule.Tiles)
            {
                var list = set.Rule.Variants.TryGetValue(kv.Key, out var l) ? l : null;
                int i = kv.Value == tile ? 0 : (list != null ? list.IndexOf(tile) + 1 : 0);
                if (kv.Value == tile || i > 0)
                {
                    key = kv.Key;
                    count = list != null ? list.Count : 0;
                    current = i;
                    return true;
                }
            }
            return false;
        }

        /// <summary>The TILE under a world-space ray — the vertex of the piece on the face the ray meets in this
        /// layer's cells (MBTools.TileVertex) — or null when the ray meets none.</summary>
        public Int3? TileUnderRay(Ray ray, float reach = 1000f)
        {
            var toFormat = FormatToWorld.inverse;
            Vector3 o = toFormat.MultiplyPoint3x4(ray.origin);
            Vector3 d = toFormat.MultiplyVector(ray.direction).normalized;
            var cellsNow = Cells;
            var hit = MBTools.Ray(cellsNow.Contains, o.x, o.y, o.z, d.x, d.y, d.z, reach);
            if (!hit.Touched) return null;
            return MBTools.TileVertex(o.x, o.y, o.z, d.x, d.y, d.z, hit.Cell, hit.Normal);
        }

        public void SetCells(IEnumerable<Vector3Int> newCells)
        {
            cells.Clear();
            index = new HashSet<Int3>();
            foreach (var c in newCells)
                if (index.Add(new Int3(c.x, c.y, c.z))) cells.Add(c);
        }

        MBTileset Tileset
        {
            get
            {
                if (loaded == null)
                {
                    loaded = MBTileset.Load(tileset, tiles, out var error);
                    LastError = error ?? "";
                }
                return loaded;
            }
        }

        /// <summary>Format space → world space: this transform, the cell size, and the measured frame.</summary>
        public Matrix4x4 FormatToWorld
        {
            get
            {
                var t = Tileset;
                float unit = t != null ? t.Unit : 1f;
                var frame = t != null ? t.Frame : Matrix4x4.identity;
                return transform.localToWorldMatrix * Matrix4x4.Scale(Vector3.one * (cellSize / unit)) * frame;
            }
        }

        /// <summary>The importer's conversion, undone: its imported-root space → format space (the inverse of the frame
        /// MEASURED on the tileset's marker). A model or a water sheet read by the same importer is brought back to format
        /// space by it: FormatToWorld · ImporterFrameInverse places it.</summary>
        public Matrix4x4 ImporterFrameInverse => Tileset != null ? Tileset.FrameInverse : Matrix4x4.identity;

        /// <summary>The cell of the current floor under a world-space ray, if the ray meets the floor.</summary>
        public bool CellUnderRay(Ray ray, out Vector3Int cell)
        {
            cell = default;
            var toFormat = FormatToWorld.inverse;
            Vector3 o = toFormat.MultiplyPoint3x4(ray.origin);
            Vector3 d = toFormat.MultiplyVector(ray.direction);
            if (Mathf.Abs(d.y) < 1e-6f) return false;
            float t = (floor - o.y) / d.y;
            if (t <= 0f) return false;
            Vector3 hit = o + d * t;
            // Cell c covers [c, c+1]: the FLOOR of the hit, never a rounding.
            cell = new Vector3Int(Mathf.FloorToInt(hit.x), floor, Mathf.FloorToInt(hit.z));
            return true;
        }

        /// <summary>The ray against the MATTER (the cells, never the rendered tiles), in format space.
        /// Converted through the measured frame, so a mirroring importer aims right too.
        /// <paramref name="ignore"/>: what the current Add stroke placed (see MBTools.Ray).</summary>
        public Hit RayAgainstCells(Ray ray, ICollection<Int3> ignore = null, float reach = 1000f)
        {
            var toFormat = FormatToWorld.inverse;
            Vector3 o = toFormat.MultiplyPoint3x4(ray.origin);
            Vector3 d = toFormat.MultiplyVector(ray.direction).normalized;
            var cellsNow = Cells;
            return MBTools.Ray(cellsNow.Contains, o.x, o.y, o.z, d.x, d.y, d.z, reach, ignore);
        }

        /// <summary>A format-space direction seen from the world: which way a format axis points on screen.</summary>
        public Vector3 FormatDirectionToWorld(Vector3 d) => FormatToWorld.MultiplyVector(d);

        /// <summary>A world-space direction in format space.</summary>
        public Vector3 WorldDirectionToFormat(Vector3 d) => FormatToWorld.inverse.MultiplyVector(d);

        /// <summary>World matrix of a unit cube filling the given cell — for gizmos and handles.</summary>
        public Matrix4x4 CellMatrix(Vector3Int c) =>
            FormatToWorld * Matrix4x4.Translate(new Vector3(c.x + 0.5f, c.y + 0.5f, c.z + 0.5f));

        public Matrix4x4 CellMatrix(Int3 c) => CellMatrix(new Vector3Int(c.x, c.y, c.z));

        public void Rebuild()
        {
            Reindex();
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
            LastPlaced = 0;
            LastMissing = 0;
            placedTiles.Clear();
            placedObjects.Clear();
            var set = Tileset;
            if (set == null) return;

            container.localPosition = Vector3.zero;
            container.localRotation = Quaternion.identity;
            container.localScale = Vector3.one * (cellSize / set.Unit);

            // Step 7: the rule reads EVERY layer of the world; this layer keeps the vertices it owns.
            var layers = Layers();
            var allCells = new List<HashSet<Int3>>();
            var visible = new List<bool>();
            var rules = new List<Rule>();
            var variants = new List<VariantSettings>();
            foreach (var l in layers)
            {
                allCells.Add(l.Cells);
                visible.Add(l.isActiveAndEnabled);
                rules.Add(l == this ? set.Rule : null);
                variants.Add(l == this ? Variants : null);
            }
            int mine = layers.IndexOf(this);
            if (!isActiveAndEnabled) return;   // a hidden layer places nothing
            var offset = set.Rule.PieceOffset;
            foreach (var p in Rule.PlacementsLayered(allCells, visible, rules, variants)[mine])
            {
                placedTiles[p.Vertex] = p.Tile;
                // The piece of vertex v is centred at F(v + piece_offset), in container space.
                Vector3 centre = set.Frame.MultiplyVector(new Vector3(
                    p.Vertex.x + offset.x, p.Vertex.y + offset.y, p.Vertex.z + offset.z));
                if (p.Tile == null || !set.Tiles.TryGetValue(p.Tile, out var tile))
                {
                    AddError(container, centre, set.Unit);
                    LastMissing++;
                    continue;
                }
                var m = Matrix4x4.Translate(centre) * set.RotationInRoot(p.QuarterTurns) * tile.Pose;
                var go = new GameObject(p.Tile) { hideFlags = HideFlags.DontSave };
                go.transform.SetParent(container, false);
                go.transform.localPosition = m.GetColumn(3);
                go.transform.localRotation = m.rotation;
                go.transform.localScale = m.lossyScale;
                go.AddComponent<MeshFilter>().sharedMesh = tile.Mesh;
                var renderer = go.AddComponent<MeshRenderer>();
                if (animatedMaterials == null) renderer.sharedMaterials = tile.Materials;
                else
                {
                    // ANIMATED TEXTURES: the animated copies, and the tile's PHASE — the hash of its ORIGIN in format space
                    // (v + piece_offset), in double, once per tile (never the engine position: a frame mirrors, scales).
                    var mats = new Material[tile.Materials.Length];
                    bool animated = false;
                    for (int k = 0; k < mats.Length; k++)
                    {
                        mats[k] = animatedMaterials.Swap(tile.Materials[k]);
                        animated |= mats[k] != tile.Materials[k];
                    }
                    renderer.sharedMaterials = mats;
                    if (animated)
                    {
                        if (phaseBlock == null) phaseBlock = new MaterialPropertyBlock();
                        phaseBlock.Clear();
                        phaseBlock.SetFloat("_MBPhase", (float)MBAnimation.PhaseOf(
                            p.Vertex.x + offset.x, p.Vertex.y + offset.y, p.Vertex.z + offset.z));
                        renderer.SetPropertyBlock(phaseBlock);
                    }
                }
                placedObjects.Add(new PlacedTile(p.Vertex, go));
                LastPlaced++;
            }
            Rebuilt?.Invoke(this);
        }

        // A red cube where the tileset lacks the tile the rule asks for. Nothing is ever filled in:
        // a hole must be seen where it happens.
        void AddError(Transform container, Vector3 centre, float unit)
        {
            if (errorMesh == null) errorMesh = Resources.GetBuiltinResource<Mesh>("Cube.fbx");
            if (errorMaterial == null)
            {
                errorMaterial = new Material(Shader.Find("Hidden/Internal-Colored")) { hideFlags = HideFlags.DontSave };
                errorMaterial.color = new Color(0.9f, 0.2f, 0.15f, 0.75f);
            }
            var go = new GameObject("missing tile") { hideFlags = HideFlags.DontSave };
            go.transform.SetParent(container, false);
            go.transform.localPosition = centre;
            go.transform.localScale = Vector3.one * unit * 0.5f;
            go.AddComponent<MeshFilter>().sharedMesh = errorMesh;
            go.AddComponent<MeshRenderer>().sharedMaterial = errorMaterial;
        }
    }
}
