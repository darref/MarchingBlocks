// MarchingBlocks Paint for Unity — THE PLANTS OF A WORLD, and their wind.
//
// world.json may carry `foliage`: models (a .glb copied in the world's foliage/ folder, its ground offset, scale, height,
// wind…) and plants (a point ON THE GROUND in format space, a yaw, a scale). Import World puts this component on a
// child of the world's root; it places every plant (never saved with the scene: rebuilt from the list, like the tiles):
//   T = translate(p + (0, ground_offset · s, 0)) · rotateY(yaw) · scale(s), s = model scale × plant scale (MBFoliage.Place),
// converted to Unity through the frame MEASURED on a layer's tileset (the same importer read the models), and gives
// every renderer its wind data (MBFoliage.WindData) for MarchingBlocks/Lit with the wind on.
//
// ⚠ The model's own skeleton animation is not played (neither in MarchingBlocks).

using System.Collections.Generic;
using UnityEngine;

namespace MarchingBlocks.Paint
{
    [ExecuteAlways]
    [AddComponentMenu("MarchingBlocks/MarchingBlocks Foliage")]
    public sealed class MarchingBlocksFoliage : MonoBehaviour
    {
        [System.Serializable]
        public struct Model
        {
            public int id;
            public string name;
            [Tooltip("The model as your glTF importer made it (foliage/<model>.glb); none: its plants are not shown.")]
            public GameObject prefab;
            [Tooltip("How far its origin sits above the ground, in model units (negative buries it).")] public float groundOffset;
            [Min(0f)] public float scale;
            [Range(0f, 0.9f)] public float scaleRandom;
            [Tooltip("Radius in cells, at scale 1.")] public float footprint;
            [Tooltip("The top of the model above its origin, in model units.")] public float height;
            [Range(0f, 1f)] public float wind;
            [Tooltip("The wind copies of its materials (MarchingBlocks/Lit), by material order of each renderer.")]
            public List<Material> sources;
            public List<Material> windMaterials;
        }

        [System.Serializable]
        public struct Plant
        {
            public int model;
            [Tooltip("The point ON THE GROUND, in format space.")] public Vector3 point;
            [Tooltip("Radians around +Y.")] public float yaw;
            public float scale;
            [Tooltip("Planted (true) or placed in the air.")] public bool planted;
        }

        [Tooltip("The layer whose tileset gives the frame (the conversion of your glTF importer) and the cell size.")]
        public MarchingBlocksWorld frameFrom;
        public List<Model> models = new List<Model>();
        public List<Plant> plants = new List<Plant>();

        const string ContainerName = "MarchingBlocks plants (generated)";
        static MaterialPropertyBlock block;

        public int LastPlaced { get; private set; }

        void OnEnable() => Rebuild();
        void OnValidate()
        {
#if UNITY_EDITOR
            UnityEditor.EditorApplication.delayCall += () => { if (this != null && isActiveAndEnabled) Rebuild(); };
#endif
        }

        public FoliageModel ToRule(Model m) => new FoliageModel
        {
            Id = m.id, Name = m.name, GroundOffset = m.groundOffset, Scale = m.scale, ScaleRandom = m.scaleRandom,
            Footprint = m.footprint, Height = m.height, Wind = m.wind,
        };

        public static MarchingBlocks.Paint.Plant ToRule(Plant p) => new MarchingBlocks.Paint.Plant
        {
            Model = p.model, X = p.point.x, Y = p.point.y, Z = p.point.z, Yaw = p.yaw, Scale = p.scale, Planted = p.planted,
        };

        /// <summary>Places every plant again.</summary>
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
            if (!isActiveAndEnabled) return;
            // Format space → world, and the importer's own conversion undone on the model's vertices.
            Matrix4x4 formatToWorld = frameFrom != null ? frameFrom.FormatToWorld : transform.localToWorldMatrix;
            Matrix4x4 importerInverse = frameFrom != null ? frameFrom.ImporterFrameInverse : Matrix4x4.identity;
            var worldToFormat = formatToWorld.inverse;
            var byId = new Dictionary<int, Model>();
            foreach (var m in models) byId[m.id] = m;
            if (block == null) block = new MaterialPropertyBlock();
            foreach (var p in plants)
            {
                if (!byId.TryGetValue(p.model, out var m) || m.prefab == null) continue;
                var rm = ToRule(m);
                var rp = ToRule(p);
                var pose = MBFoliage.Place(rm, rp);
                var T = Matrix4x4.TRS(new Vector3((float)pose.Origin.x, (float)pose.Origin.y, (float)pose.Origin.z),
                    Quaternion.AngleAxis((float)(pose.Yaw * 180.0 / System.Math.PI), Vector3.up), Vector3.one * (float)pose.Scale);
                var world = formatToWorld * T * importerInverse;
                var go = Instantiate(m.prefab, container);
                go.name = m.name;
                go.hideFlags = HideFlags.DontSave;
                go.transform.position = world.GetColumn(3);
                go.transform.rotation = world.rotation;
                var parentScale = container.lossyScale;
                var ls = world.lossyScale;
                go.transform.localScale = new Vector3(ls.x / parentScale.x, ls.y / parentScale.y, ls.z / parentScale.z);
                var wind = MBFoliage.WindData(rm, rp);
                foreach (var r in go.GetComponentsInChildren<Renderer>(true))
                {
                    if (m.windMaterials != null && m.sources != null)
                    {
                        var mats = r.sharedMaterials;
                        for (int k = 0; k < mats.Length; k++)
                        {
                            int i = m.sources.IndexOf(mats[k]);
                            if (i >= 0 && i < m.windMaterials.Count && m.windMaterials[i] != null) mats[k] = m.windMaterials[i];
                        }
                        r.sharedMaterials = mats;
                    }
                    block.Clear();
                    block.SetVector("_MBWind", new Vector4((float)wind.Ground, (float)wind.Height, (float)wind.Phase, (float)wind.Amplitude));
                    block.SetMatrix("_MBWorldToFormat", worldToFormat);
                    block.SetMatrix("_MBFormatToWorld", formatToWorld);
                    r.SetPropertyBlock(block);
                }
                LastPlaced++;
            }
        }
    }
}
