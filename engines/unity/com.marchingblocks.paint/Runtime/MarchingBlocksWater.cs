// MarchingBlocks Paint for Unity — THE WATER OF A WORLD.
//
// world.json may carry `water`: layers of water, each with its sources and the sheet MarchingBlocks BAKED (water/<name>.glb,
// in format space; every vertex carries the water data — COLOR_0 r, g the flow, b the kind, a the depth or the foam).
// Import World puts this component on a child of the world's root; it shows each sheet (never saved with the scene),
// with the material you choose — the six looks shipped with the plugin (MarchingBlocks/Water) are EXAMPLES, not an
// obligation: any shader that reads the vertex colours gets the same data.
//
// WHEN YOU PAINT, the water CELLS are deduced again from the sources and the cells of every layer (MBWater.World, the
// rule of MarchingBlocks, its cases in Tests/water_conformance.json) and drawn as gizmos when this object is selected.
// ⚠ The SHEET itself is not rebuilt in Unity: the mesh of the water (MarchingBlocks' eau_maillage) has no cases yet —
// export the world again from MarchingBlocks to get a new sheet.

using System.Collections.Generic;
using UnityEngine;

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
            [Tooltip("The baked sheet (water/<name>.glb) as your glTF importer made it; none: nothing to draw.")]
            public GameObject sheet;
            [Tooltip("The material of the sheet: one of the six looks, or yours.")]
            public Material material;
            [Tooltip("Where the water was placed, in format space.")]
            public List<Vector3Int> sources;
        }

        [Tooltip("The layer whose tileset gives the frame (the conversion of your glTF importer) and the cell size.")]
        public MarchingBlocksWorld frameFrom;
        public List<Layer> layers = new List<Layer>();

        const string ContainerName = "MarchingBlocks water (generated)";
        readonly List<WaterWorld> lastWorlds = new List<WaterWorld>();
        static MaterialPropertyBlock block;

        void OnEnable()
        {
            MarchingBlocksWorld.Rebuilt += OnLayerRebuilt;
            Rebuild();
        }

        void OnDisable() => MarchingBlocksWorld.Rebuilt -= OnLayerRebuilt;

        void OnValidate()
        {
#if UNITY_EDITOR
            UnityEditor.EditorApplication.delayCall += () => { if (this != null && isActiveAndEnabled) Rebuild(); };
#endif
        }

        void OnLayerRebuilt(MarchingBlocksWorld layer)
        {
            if (this != null && isActiveAndEnabled && layer.transform.parent == transform.parent) lastWorlds.Clear();
        }

        /// <summary>Shows every sheet again.</summary>
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
            foreach (var l in layers)
            {
                if (l.sheet == null) continue;
                var go = Instantiate(l.sheet, container);
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
                    r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
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
            var cells = new HashSet<Int3>();
            if (transform.parent != null)
                for (int i = 0; i < transform.parent.childCount; i++)
                {
                    var w = transform.parent.GetChild(i).GetComponent<MarchingBlocksWorld>();
                    if (w != null) cells.UnionWith(w.Cells);
                }
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
