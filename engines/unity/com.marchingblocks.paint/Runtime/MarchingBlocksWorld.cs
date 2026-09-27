// MarchingBlocks Paint for Unity — ONE WORLD LAYER: you paint cells, the tiles follow.
//
// Cells are stored in FORMAT space (the tileset's own grid). What you see is converted through the
// tileset's measured frame, so the cells and the tiles always agree, whatever your glTF importer did.
// One component is one layer: its tiles only ever look at its own cells. Stack several GameObjects for
// several layers (rock, ice…), each with its own tileset.
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
        [Tooltip("Size of one cell, in Unity units.")]
        [Min(0.01f)] public float cellSize = 1f;
        [Tooltip("The floor the brush paints on, in cells.")]
        public int floor;

        [SerializeField, HideInInspector] List<Vector3Int> cells = new List<Vector3Int>();

        const string ContainerName = "MarchingBlocks tiles (generated)";
        MBTileset loaded;
        static Mesh errorMesh;
        static Material errorMaterial;

        public string LastError { get; private set; } = "";
        public int LastPlaced { get; private set; }
        public int LastMissing { get; private set; }
        public int CellCount => cells.Count;

        void OnEnable() => Rebuild();

        void OnValidate()
        {
            loaded = null;
#if UNITY_EDITOR
            // Objects cannot be created or destroyed inside OnValidate.
            UnityEditor.EditorApplication.delayCall += () => { if (this != null) Rebuild(); };
#endif
        }

        public bool HasCell(Vector3Int c) => cells.Contains(c);

        /// <summary>Adds or removes a cell. Call Rebuild() afterwards (once per stroke is enough).</summary>
        public void SetCell(Vector3Int c, bool full)
        {
            if (full && !cells.Contains(c)) cells.Add(c);
            else if (!full) cells.Remove(c);
        }

        public void ClearCells() => cells.Clear();

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

        /// <summary>World matrix of a unit cube filling the given cell — for gizmos and handles.</summary>
        public Matrix4x4 CellMatrix(Vector3Int c) =>
            FormatToWorld * Matrix4x4.Translate(new Vector3(c.x + 0.5f, c.y + 0.5f, c.z + 0.5f));

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
            LastPlaced = 0;
            LastMissing = 0;
            var set = Tileset;
            if (set == null) return;

            container.localPosition = Vector3.zero;
            container.localRotation = Quaternion.identity;
            container.localScale = Vector3.one * (cellSize / set.Unit);

            var formatCells = new HashSet<Int3>();
            foreach (var c in cells) formatCells.Add(new Int3(c.x, c.y, c.z));
            var offset = set.Rule.PieceOffset;
            foreach (var p in set.Rule.Placements(formatCells))
            {
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
                go.AddComponent<MeshRenderer>().sharedMaterials = tile.Materials;
                LastPlaced++;
            }
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
