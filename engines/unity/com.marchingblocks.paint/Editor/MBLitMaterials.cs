// MarchingBlocks Paint for Unity — MARCHINGBLOCKS/LIT COPIES OF YOUR IMPORTER'S MATERIALS, as assets.
//
//   - ANIMATED TILES: tiles.glb carries extras.mb_animation on some materials. The extras are read from the .glb ITSELF
//     (MBAnimation.ReadGlbJson — glTFast does not expose material extras in a dependable way), matched by material
//     NAME; each animated material gets a MarchingBlocks/Lit copy whose frames are Texture2DArrays made from the images
//     that travel in <set>.mbset/animation/. Saved in "<set>.mbset/MarchingBlocks generated/", with the MBAnimatedSet.
//   - PLANTS IN THE WIND: each material of a foliage model gets a MarchingBlocks/Lit copy with the wind on.
//
// ⚠ The copy READS the importer's material by property names: glTFast's (baseColorTexture, metallicRoughnessTexture…)
// first, then Unity's usual ones (_BaseMap, _MainTex, _BumpMap…). Another importer's custom names are not read: the
// copy then shows a white material — say so, never guess.

using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

namespace MarchingBlocks.Paint.EditorTools
{
    public static class MBLitMaterials
    {
        public const string LitShaderPath = "Packages/com.marchingblocks.paint/Runtime/Shaders/MarchingBlocksLit.shader";
        public const string GeneratedFolder = "MarchingBlocks generated";

        public static Shader LitShader()
        {
            var s = AssetDatabase.LoadAssetAtPath<Shader>(LitShaderPath);
            return s != null ? s : Shader.Find("MarchingBlocks/Lit");
        }

        /// <summary>The animated materials of a tileset (tiles.glb at this asset path, imported as tilesRoot): made, or
        /// remade, as assets next to it. Null when no material is animated. <paramref name="warnings"/> says what could
        /// not be done (an image not found, too many pixels).</summary>
        public static MBAnimatedSet BuildAnimated(string tilesGlbPath, GameObject tilesRoot, List<string> warnings)
        {
            if (tilesRoot == null || !File.Exists(tilesGlbPath)) return null;
            var json = MBAnimation.ReadGlbJson(File.ReadAllBytes(tilesGlbPath));
            if (json == null) return null;
            var animations = MBAnimation.MaterialAnimations(json);
            if (animations.Count == 0) return null;
            string setFolder = Path.GetDirectoryName(tilesGlbPath).Replace('\\', '/');
            string outFolder = setFolder + "/" + GeneratedFolder;
            if (!AssetDatabase.IsValidFolder(outFolder)) AssetDatabase.CreateFolder(setFolder, GeneratedFolder);

            var sources = new List<Material>();
            foreach (var r in tilesRoot.GetComponentsInChildren<Renderer>(true))
                foreach (var m in r.sharedMaterials)
                    if (m != null && !sources.Contains(m)) sources.Add(m);

            string setPath = outFolder + "/animated.asset";
            var set = AssetDatabase.LoadAssetAtPath<MBAnimatedSet>(setPath);
            if (set == null)
            {
                set = ScriptableObject.CreateInstance<MBAnimatedSet>();
                AssetDatabase.CreateAsset(set, setPath);
            }
            set.entries.Clear();
            foreach (var source in sources)
            {
                if (!animations.TryGetValue(source.name, out var anim)) continue;
                var copy = Copy(source, outFolder + "/" + Safe(source.name) + ".mat");
                ApplyAnimation(copy, anim, setFolder, outFolder + "/" + Safe(source.name), warnings);
                EditorUtility.SetDirty(copy);
                set.entries.Add(new MBAnimatedSet.Entry { source = source, animated = copy });
            }
            EditorUtility.SetDirty(set);
            AssetDatabase.SaveAssets();
            if (set.entries.Count == 0)
                warnings.Add($"tiles.glb names {animations.Count} animated material(s), none of them is used by the imported tiles");
            return set;
        }

        /// <summary>The wind copy of a plant's material (an asset in <paramref name="folder"/>).</summary>
        public static Material WindCopy(Material source, string folder)
        {
            if (!AssetDatabase.IsValidFolder(folder))
            {
                string parent = Path.GetDirectoryName(folder).Replace('\\', '/');
                AssetDatabase.CreateFolder(parent, Path.GetFileName(folder));
            }
            var copy = Copy(source, folder + "/" + Safe(source.name) + " (wind).mat");
            copy.SetFloat("_Wind", 1f);
            copy.EnableKeyword("_MB_WIND");
            EditorUtility.SetDirty(copy);
            return copy;
        }

        static string Safe(string n)
        {
            foreach (var c in Path.GetInvalidFileNameChars()) n = n.Replace(c, '_');
            return n == "" ? "material" : n;
        }

        /// <summary>A MarchingBlocks/Lit material with the glTF parameters of the source, saved (or updated) at path.</summary>
        static Material Copy(Material source, string path)
        {
            var m = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (m == null)
            {
                m = new Material(LitShader());
                AssetDatabase.CreateAsset(m, path);
            }
            else m.shader = LitShader();
            m.name = Path.GetFileNameWithoutExtension(path);
            m.SetColor("_BaseColor", GetColor(source, Color.white, "baseColorFactor", "_BaseColor", "_Color"));
            m.SetTexture("_BaseMap", GetTexture(source, "baseColorTexture", "_BaseMap", "_MainTex"));
            m.SetFloat("_MetallicFactor", GetFloat(source, 0f, "metallicFactor", "_Metallic"));
            float roughness = source.HasProperty("roughnessFactor") ? source.GetFloat("roughnessFactor")
                : source.HasProperty("_Smoothness") ? 1f - source.GetFloat("_Smoothness")
                : source.HasProperty("_Glossiness") ? 1f - source.GetFloat("_Glossiness") : 1f;
            m.SetFloat("_RoughnessFactor", roughness);
            m.SetTexture("_MetallicRoughnessMap", GetTexture(source, "metallicRoughnessTexture"));
            m.SetTexture("_OcclusionMap", GetTexture(source, "occlusionTexture", "_OcclusionMap"));
            m.SetFloat("_OcclusionStrength", GetFloat(source, 1f, "occlusionTexture_strength", "_OcclusionStrength"));
            var normal = GetTexture(source, "normalTexture", "_BumpMap");
            m.SetTexture("_NormalMap", normal);
            m.SetFloat("_NormalScale", GetFloat(source, 1f, "normalTexture_scale", "_BumpScale"));
            m.SetColor("_EmissionColor", GetColor(source, Color.black, "emissiveFactor", "_EmissionColor"));
            m.SetTexture("_EmissionMap", GetTexture(source, "emissiveTexture", "_EmissionMap"));
            bool alphaTest = source.IsKeywordEnabled("_ALPHATEST_ON") || source.IsKeywordEnabled("_ALPHATEST");
            m.SetFloat("_AlphaTest", alphaTest ? 1f : 0f);
            if (alphaTest) m.EnableKeyword("_MB_ALPHATEST"); else m.DisableKeyword("_MB_ALPHATEST");
            m.SetFloat("_Cutoff", GetFloat(source, 0.5f, "alphaCutoff", "_Cutoff"));
            m.SetFloat("_Cull", GetFloat(source, 2f, "_CullMode", "_Cull"));
            return m;
        }

        static Color GetColor(Material m, Color fallback, params string[] names)
        {
            foreach (var n in names) if (m.HasProperty(n)) return m.GetColor(n);
            return fallback;
        }

        static float GetFloat(Material m, float fallback, params string[] names)
        {
            foreach (var n in names) if (m.HasProperty(n)) return m.GetFloat(n);
            return fallback;
        }

        static Texture GetTexture(Material m, params string[] names)
        {
            foreach (var n in names) if (m.HasProperty(n) && m.GetTexture(n) != null) return m.GetTexture(n);
            return null;
        }

        static readonly (string channel, string suffix, bool linear)[] Channels =
        {
            ("albedo", "Albedo", false), ("normal", "Normal", true), ("orm", "ORM", true), ("emission", "Emission", false),
        };

        static void ApplyAnimation(Material m, MaterialAnimation anim, string setFolder, string assetBase, List<string> warnings)
        {
            foreach (var (channel, suffix, linear) in Channels)
            {
                var c = anim.Channel(channel);
                var frames = c?.Frames;
                var scroll = c?.Scroll;
                m.SetVector("_MBScroll" + suffix, scroll == null ? new Vector4(0, 0, 1, 0)
                    : new Vector4((float)scroll.U, (float)scroll.V, scroll.Synced ? 1 : 0, 1));
                Texture2DArray array = null;
                if (frames != null)
                {
                    array = BuildArray(frames.Images, setFolder, linear, assetBase + "_" + channel + ".asset", warnings);
                    if (array == null) warnings.Add($"material '{m.name}': the {channel} frames could not be read — frame 0 is shown");
                }
                m.SetTexture("_MBFrames" + suffix, array);
                m.SetVector("_MBFrames" + suffix + "Params", array == null ? new Vector4(0, 12, 0, 0)
                    : new Vector4(array.depth, (float)frames.Fps, frames.PingPong ? 1 : 0, frames.Synced ? 1 : 0));
                // Emission with frames but no emissive colour would stay black: the frames ARE the emission.
                if (channel == "emission" && array != null && m.GetColor("_EmissionColor").maxColorComponent <= 0f)
                    m.SetColor("_EmissionColor", Color.white);
            }
            var pulse = anim.Channel("emission")?.Pulse;
            m.SetVector("_MBPulse", pulse == null ? new Vector4(0.5f, 0.2f, 0, 0)
                : new Vector4((float)pulse.Frequency, (float)pulse.Minimum, pulse.Synced ? 1 : 0, 1));
        }

        /// <summary>The frames of a track, in order, as ONE Texture2DArray asset (every frame at the size of the first).
        /// Null when an image is missing or the frames hold more than MBAnimation.PixelsMax pixels.</summary>
        static Texture2DArray BuildArray(List<string> images, string setFolder, bool linear, string assetPath, List<string> warnings)
        {
            var frames = new List<Texture2D>();
            try
            {
                foreach (var rel in images)
                {
                    string path = MBWorldFile.ResolveRelative(setFolder + "/tileset.json", rel);
                    if (!File.Exists(path)) { warnings.Add("animation image not found: " + path); return null; }
                    var t = new Texture2D(2, 2, TextureFormat.RGBA32, false, linear);
                    if (!t.LoadImage(File.ReadAllBytes(path))) { warnings.Add("animation image unreadable: " + path); return null; }
                    frames.Add(t);
                }
                if (frames.Count == 0) return null;
                int w = frames[0].width, h = frames[0].height;
                if ((long)w * h * frames.Count > MBAnimation.PixelsMax)
                {
                    warnings.Add($"animation of {frames.Count} frames of {w}×{h}: more than {MBAnimation.PixelsMax} pixels");
                    return null;
                }
                var array = new Texture2DArray(w, h, frames.Count, TextureFormat.RGBA32, true, linear)
                { wrapMode = TextureWrapMode.Repeat, filterMode = FilterMode.Trilinear, anisoLevel = 4 };
                for (int k = 0; k < frames.Count; k++)
                {
                    var f = frames[k];
                    Color32[] px = f.width == w && f.height == h ? f.GetPixels32() : Resized(f, w, h);
                    array.SetPixels32(px, k, 0);
                }
                array.Apply(true, false);
                var old = AssetDatabase.LoadAssetAtPath<Texture2DArray>(assetPath);
                if (old != null) AssetDatabase.DeleteAsset(assetPath);
                AssetDatabase.CreateAsset(array, assetPath);
                return array;
            }
            finally { foreach (var f in frames) Object.DestroyImmediate(f); }
        }

        static Color32[] Resized(Texture2D f, int w, int h)
        {
            var px = new Color32[w * h];
            for (int y = 0; y < h; y++)
                for (int x = 0; x < w; x++)
                    px[y * w + x] = f.GetPixelBilinear((x + 0.5f) / w, (y + 0.5f) / h);
            return px;
        }
    }
}
