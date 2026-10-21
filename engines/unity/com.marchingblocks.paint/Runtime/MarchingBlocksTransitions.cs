// MarchingBlocks Paint for Unity — TRANSITIONS BETWEEN LAYERS, drawn over the tiles.
//
// Put on the PARENT of the layers (the root Import World makes): the MarchingBlocksWorld children are the layers, in
// world.json's order — the layer index is the rank of the rule (MBTransitions.Blend). Where two layers of an ACTIVE
// pair meet, the tiles get a second renderer (a child, never saved) with the overlay material on every submesh: it
// draws the OTHER layer's representative over the tile's own material, with the alpha of the rule. The geometry
// never changes.
//
// ⚠ WHY A SECOND RENDERER: Unity has no pass laid over a material, and a material added to a renderer only redraws
// its LAST submesh — tiles have several. Only the tiles where two blending layers meet get one (the others would draw
// nothing at all), and it follows every rebuild of a layer (MarchingBlocksWorld.Rebuilt).
//
// The cell texture (one byte per cell, MBTransitions.CellTexture), the table of active directions and the
// representatives (a Texture2DArray, one slice per layer) are built here, at runtime, from the serialized data.

using System.Collections.Generic;
using UnityEngine;

namespace MarchingBlocks.Paint
{
    [ExecuteAlways]
    [AddComponentMenu("MarchingBlocks/MarchingBlocks Transitions")]
    public sealed class MarchingBlocksTransitions : MonoBehaviour
    {
        [System.Serializable]
        public struct Settings
        {
            [Range(0.05f, 1f)] public float softness;
            [Range(-0.5f, 0.5f)] public float reach;
            [Range(0f, 1f)] public float irregularity;
            [Range(0.25f, 6f)] public float grain;
            [Range(0f, 1f)] public float fillsHollows;

            public static Settings From(TransitionSettings s) => new Settings
            {
                softness = (float)s.Softness, reach = (float)s.Reach, irregularity = (float)s.Irregularity,
                grain = (float)s.Grain, fillsHollows = (float)s.FillsHollows,
            };
        }

        [System.Serializable]
        public struct Pair
        {
            [Tooltip("Layer index (in the order of the layers), a < b.")] public int a;
            public int b;
            public bool active;
            [Tooltip("How layer a covers layer b.")] public Settings aCoversB;
            [Tooltip("How layer b covers layer a.")] public Settings bCoversA;
        }

        [System.Serializable]
        public struct Representative
        {
            [Tooltip("Projected in a box over the other layer's surface; none: plain colour.")] public Texture2D image;
            [Tooltip("Multiplies the image as is.")] public Color color;
            [Tooltip("World cells per repeat of the image.")] [Min(0.01f)] public float scale;
            [Range(0f, 1f)] public float roughness;
        }

        [System.Serializable]
        public struct Choice
        {
            public Vector3Int vertex;
            public int layer;
        }

        [Tooltip("The overlay shader (MarchingBlocks/Transition Overlay).")]
        public Shader overlayShader;
        public List<Pair> pairs = new List<Pair>();
        [Tooltip("One per layer, in layer order.")]
        public List<Representative> representatives = new List<Representative>();
        [Tooltip("At a vertex (format space), the layer that covers.")]
        public List<Choice> choices = new List<Choice>();
        [Tooltip("Tints the vertices where a choice was painted.")]
        public bool showChoices;

        const string OverlayName = "MarchingBlocks transition (generated)";
        Material material;
        Texture3D cellTexture;
        Texture2D tableTexture;
        Texture2DArray repTexture;
        Texture2D repDataTexture;
        MaterialPropertyBlock block;
        bool dirty = true;

        /// <summary>How many tiles carry an overlay since the last dressing — for tests and the inspector.</summary>
        public int OverlayCount { get; private set; }

        /// <summary>The overlay material (one per world), with the textures the shader reads — for tests.</summary>
        public Material OverlayMaterial => material;

        void OnEnable()
        {
            MarchingBlocksWorld.Rebuilt += OnLayerRebuilt;
            dirty = true;
            DressAll();
        }

        void OnDisable()
        {
            MarchingBlocksWorld.Rebuilt -= OnLayerRebuilt;
            foreach (var l in Layers()) Undress(l);
            Release();
        }

        void OnValidate() => dirty = true;

        /// <summary>The layers: the MarchingBlocksWorld components of the children, in order (active or not).</summary>
        public List<MarchingBlocksWorld> Layers()
        {
            var result = new List<MarchingBlocksWorld>();
            for (int i = 0; i < transform.childCount; i++)
            {
                var w = transform.GetChild(i).GetComponent<MarchingBlocksWorld>();
                if (w != null) result.Add(w);
            }
            return result;
        }

        void OnLayerRebuilt(MarchingBlocksWorld layer)
        {
            if (this == null || !isActiveAndEnabled || layer.transform.parent != transform) return;
            // The cells changed: the texture is rebuilt once per change, then every layer is dressed as it rebuilds.
            BuildCellTexture();
            Dress(layer);
        }

        /// <summary>Rebuilds the textures and dresses every layer — after the data changed (pairs, representatives).</summary>
        public void DressAll()
        {
            if (!isActiveAndEnabled) return;
            dirty = true;
            BuildCellTexture();
            foreach (var l in Layers()) Dress(l);
        }

        void Update()
        {
            if (dirty) DressAll();
        }

        // ---- the data the shader reads ----

        Dictionary<(int, int), TransitionSettings> Table()
        {
            var list = new List<TransitionPair>();
            foreach (var p in pairs)
                list.Add(new TransitionPair { A = p.a, B = p.b, Active = p.active, ACoversB = ToRule(p.aCoversB), BCoversA = ToRule(p.bCoversA) });
            return MBTransitions.Table(list);
        }

        static TransitionSettings ToRule(Settings s) => TransitionSettings.From(new Dictionary<string, object>
        {
            ["softness"] = (double)s.softness, ["reach"] = (double)s.reach, ["irregularity"] = (double)s.irregularity,
            ["grain"] = (double)s.grain, ["fills_hollows"] = (double)s.fillsHollows,
        });

        void BuildCellTexture()
        {
            var cells = new List<KeyValuePair<Int3, int>>();
            var layers = Layers();
            for (int i = 0; i < layers.Count; i++)
            {
                // Hidden layers place no cell.
                if (!layers[i].isActiveAndEnabled) continue;
                foreach (var c in layers[i].Cells) cells.Add(new KeyValuePair<Int3, int>(c, i));
            }
            var chosen = new List<KeyValuePair<Int3, int>>();
            foreach (var c in choices) chosen.Add(new KeyValuePair<Int3, int>(new Int3(c.vertex.x, c.vertex.y, c.vertex.z), c.layer));
            var bytes = MBTransitions.CellTexture(cells, chosen, out var origin, out var size);
            if (cellTexture == null || cellTexture.width != size.x || cellTexture.height != size.y || cellTexture.depth != size.z)
            {
                Free(cellTexture);
                cellTexture = new Texture3D(size.x, size.y, size.z, TextureFormat.RG16, false)
                { name = "MarchingBlocks cells", filterMode = FilterMode.Point, wrapMode = TextureWrapMode.Clamp, hideFlags = HideFlags.DontSave };
            }
            cellTexture.SetPixelData(bytes, 0);
            cellTexture.Apply(false);
            EnsureMaterial();
            material.SetTexture("_MBCells", cellTexture);
            material.SetVector("_MBCellsOrigin", new Vector4(origin.x, origin.y, origin.z, 0));
            material.SetVector("_MBCellsSize", new Vector4(size.x, size.y, size.z, 0));
            if (dirty) { BuildTableAndRepresentatives(); dirty = false; }
        }

        void EnsureMaterial()
        {
            if (material != null) return;
            var shader = overlayShader != null ? overlayShader : Shader.Find("MarchingBlocks/Transition Overlay");
            material = new Material(shader) { name = "MarchingBlocks transition overlay", hideFlags = HideFlags.DontSave };
            dirty = true;
        }

        void BuildTableAndRepresentatives()
        {
            // Sized on the real number of layers (at most 255; 15 whatever happened before 21 October 2026).
            int n = Mathf.Clamp(Mathf.Max(Layers().Count, representatives.Count), 1, MBTransitions.LayersMax);
            // When Y covers X: (2X, Y) = active, softness, reach, irregularity; (2X + 1, Y) = fills_hollows, grain.
            if (tableTexture != null && tableTexture.height != n) { Free(tableTexture); tableTexture = null; }
            if (repDataTexture != null && repDataTexture.width != n) { Free(repDataTexture); repDataTexture = null; }
            if (tableTexture == null)
                tableTexture = new Texture2D(2 * n, n, TextureFormat.RGBAFloat, false, true)
                { name = "MarchingBlocks transition table", filterMode = FilterMode.Point, wrapMode = TextureWrapMode.Clamp, hideFlags = HideFlags.DontSave };
            // Pixel (x, y) is index y · width + x: the shader loads (2X, Y), X the COVERED layer, Y the covering one.
            var flipped = new Color[2 * n * n];
            foreach (var kv in Table())
            {
                int covering = kv.Key.Item1, covered = kv.Key.Item2;
                if (covering >= n || covered >= n) continue;
                var s = kv.Value;
                flipped[covering * 2 * n + 2 * covered] = new Color(1f, (float)s.Softness, (float)s.Reach, (float)s.Irregularity);
                flipped[covering * 2 * n + 2 * covered + 1] = new Color((float)s.FillsHollows, (float)s.Grain, 0f, 0f);
            }
            tableTexture.SetPixels(flipped);
            tableTexture.Apply(false);

            // The representatives: one slice per layer, at the size of the largest image (white without one).
            int w = 4, h = 4;
            foreach (var r in representatives)
                if (r.image != null) { w = Mathf.Max(w, r.image.width); h = Mathf.Max(h, r.image.height); }
            w = Mathf.Min(w, 1024);
            h = Mathf.Min(h, 1024);
            Free(repTexture);
            repTexture = new Texture2DArray(w, h, n, TextureFormat.RGBA32, true, false)
            { name = "MarchingBlocks representatives", wrapMode = TextureWrapMode.Repeat, filterMode = FilterMode.Trilinear, hideFlags = HideFlags.DontSave };
            var white = new Color32[w * h];
            for (int k = 0; k < white.Length; k++) white[k] = new Color32(255, 255, 255, 255);
            // The representatives' colour and settings: an N × 2 texture (row 0 colour, row 1 scale, roughness). A texture,
            // not a uniform array: an array set on a material is not one of its properties, and Unity drops it whenever it
            // rebuilds the material's properties (seen: the overlay drew nothing after an asset import).
            if (repDataTexture == null)
                repDataTexture = new Texture2D(n, 2, TextureFormat.RGBAFloat, false, true)
                { name = "MarchingBlocks representatives data", filterMode = FilterMode.Point, wrapMode = TextureWrapMode.Clamp, hideFlags = HideFlags.DontSave };
            var data = new Color[2 * n];
            for (int k = 0; k < n; k++)
            {
                var slice = white;
                data[k] = Color.white;
                data[n + k] = new Color(1f, 1f, 0f, 0f);
                if (k < representatives.Count)
                {
                    var r = representatives[k];
                    data[k] = r.color;
                    data[n + k] = new Color(Mathf.Max(r.scale, 0.01f), Mathf.Clamp01(r.roughness), 0f, 0f);
                    if (r.image != null) slice = Resample(r.image, w, h) ?? white;
                }
                repTexture.SetPixels32(slice, k, 0);
            }
            repTexture.Apply(true, false);
            repDataTexture.SetPixels(data);
            repDataTexture.Apply(false);
            material.SetTexture("_MBTable", tableTexture);
            material.SetTexture("_MBReps", repTexture);
            material.SetTexture("_MBRepData", repDataTexture);
            material.SetFloat("_MBShowChoices", showChoices ? 1f : 0f);
        }

        // An image at another size, sampled bilinearly. Its texture must be readable (Import World makes it so); else
        // it is drawn through a temporary RenderTexture.
        static Color32[] Resample(Texture2D image, int w, int h)
        {
            if (image.isReadable && image.width == w && image.height == h) return image.GetPixels32();
            var rt = RenderTexture.GetTemporary(w, h, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.sRGB);
            var previous = RenderTexture.active;
            Graphics.Blit(image, rt);
            RenderTexture.active = rt;
            var copy = new Texture2D(w, h, TextureFormat.RGBA32, false, false);
            copy.ReadPixels(new Rect(0, 0, w, h), 0, 0);
            copy.Apply();
            RenderTexture.active = previous;
            RenderTexture.ReleaseTemporary(rt);
            var px = copy.GetPixels32();
            Free(copy);
            return px;
        }

        // ---- dressing the tiles ----

        void Dress(MarchingBlocksWorld layer)
        {
            Undress(layer);
            if (!layer.isActiveAndEnabled) return;
            EnsureMaterial();
            if (dirty) BuildCellTexture();
            var layers = Layers();
            int mine = layers.IndexOf(layer);
            if (mine < 0 || mine >= MBTransitions.LayersMax) return;
            var table = Table();
            if (table.Count == 0) return;
            // The rank of every cell of the visible layers.
            var rank = new Dictionary<Int3, int>();
            for (int i = 0; i < layers.Count; i++)
                if (layers[i].isActiveAndEnabled)
                    foreach (var c in layers[i].Cells) rank[c] = i;
            if (block == null) block = new MaterialPropertyBlock();
            var toFormat = layer.FormatToWorld.inverse;
            int count = 0;
            foreach (var t in layer.PlacedObjects)
            {
                if (t.Object == null || !Blends(t.Vertex, rank, table)) continue;
                var source = t.Object.GetComponent<MeshFilter>();
                var sourceRenderer = t.Object.GetComponent<MeshRenderer>();
                if (source == null || source.sharedMesh == null) continue;
                var go = new GameObject(OverlayName) { hideFlags = HideFlags.DontSave | HideFlags.NotEditable };
                go.transform.SetParent(t.Object.transform, false);
                go.AddComponent<MeshFilter>().sharedMesh = source.sharedMesh;
                var r = go.AddComponent<MeshRenderer>();
                var mats = new Material[Mathf.Max(1, source.sharedMesh.subMeshCount)];
                for (int k = 0; k < mats.Length; k++) mats[k] = material;
                r.sharedMaterials = mats;
                r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                r.receiveShadows = false;
                if (sourceRenderer != null) r.renderingLayerMask = sourceRenderer.renderingLayerMask;
                block.Clear();
                block.SetVector("_MBVertex", new Vector4(t.Vertex.x, t.Vertex.y, t.Vertex.z, 0));
                block.SetMatrix("_MBWorldToFormat", toFormat);
                r.SetPropertyBlock(block);
                count++;
            }
            OverlayCount = 0;
            foreach (var l in layers) OverlayCount += CountOverlays(l);
        }

        /// <summary>True when the eight cells around the tile of vertex v hold two layers of an active pair: only there
        /// can the overlay draw something.</summary>
        static bool Blends(Int3 v, Dictionary<Int3, int> rank, Dictionary<(int, int), TransitionSettings> table)
        {
            var seen = new List<int>(8);
            for (int k = 0; k < 8; k++)
            {
                var c = new Int3(v.x + (k & 1), v.y + ((k >> 1) & 1), v.z + ((k >> 2) & 1));
                if (rank.TryGetValue(c, out var r) && r < MBTransitions.LayersMax && !seen.Contains(r)) seen.Add(r);
            }
            for (int i = 0; i < seen.Count; i++)
                for (int j = 0; j < seen.Count; j++)
                    if (i != j && table.ContainsKey((seen[i], seen[j])) && table.ContainsKey((seen[j], seen[i]))) return true;
            return false;
        }

        static int CountOverlays(MarchingBlocksWorld layer)
        {
            int n = 0;
            foreach (var t in layer.PlacedObjects)
                if (t.Object != null && t.Object.transform.Find(OverlayName) != null) n++;
            return n;
        }

        static void Undress(MarchingBlocksWorld layer)
        {
            if (layer == null) return;
            foreach (var t in layer.PlacedObjects)
            {
                if (t.Object == null) continue;
                var o = t.Object.transform.Find(OverlayName);
                if (o != null) Free(o.gameObject);
            }
        }

        void Release()
        {
            Free(material);
            Free(cellTexture);
            Free(tableTexture);
            Free(repTexture);
            Free(repDataTexture);
            material = null;
            cellTexture = null;
            tableTexture = null;
            repTexture = null;
            repDataTexture = null;
        }

        static void Free(Object o)
        {
            if (o == null) return;
            if (Application.isPlaying) Object.Destroy(o); else Object.DestroyImmediate(o);
        }
    }
}
