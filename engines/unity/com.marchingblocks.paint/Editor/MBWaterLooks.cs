// MarchingBlocks Paint for Unity — THE SIX WATER LOOKS as materials (MarchingBlocks/Water), with the colours and settings
// of MarchingBlocks' presets (eau_presets.gd). EXAMPLES: assign any material you like to a water layer.

using System.IO;
using UnityEditor;
using UnityEngine;

namespace MarchingBlocks.Paint.EditorTools
{
    public static class MBWaterLooks
    {
        public const string ShaderPath = "Packages/com.marchingblocks.paint/Runtime/Shaders/MarchingBlocksWater.shader";
        public static readonly string[] Looks = { "stylized", "clear", "reflective", "lava", "swamp", "acid" };

        /// <summary>The material of a look (an unknown look gets "stylized"), saved in <paramref name="folder"/>.</summary>
        public static Material Material(string look, string folder)
        {
            int k = System.Array.IndexOf(Looks, look);
            if (k < 0) { k = 0; look = Looks[0]; }
            if (!AssetDatabase.IsValidFolder(folder))
                AssetDatabase.CreateFolder(Path.GetDirectoryName(folder).Replace('\\', '/'), Path.GetFileName(folder));
            string path = folder + "/water_" + look + ".mat";
            var m = AssetDatabase.LoadAssetAtPath<Material>(path);
            var shader = AssetDatabase.LoadAssetAtPath<Shader>(ShaderPath) ?? Shader.Find("MarchingBlocks/Water");
            if (m == null)
            {
                m = new Material(shader);
                AssetDatabase.CreateAsset(m, path);
            }
            else m.shader = shader;
            Apply(m, k);
            EditorUtility.SetDirty(m);
            return m;
        }

        static void Apply(Material m, int k)
        {
            foreach (var l in Looks) m.DisableKeyword("_MB_LOOK_" + l.ToUpperInvariant());
            m.EnableKeyword("_MB_LOOK_" + Looks[k].ToUpperInvariant());
            m.SetFloat("_MB_LOOK", k);
            Color C(float r, float g, float b) => new Color(r, g, b, 1f);
            switch (k)
            {
                case 1: // clear: tint, deep tint, foam; absorption, river speed, still speed, relief
                    Set(m, C(0.10f, 0.42f, 0.46f), C(0.02f, 0.13f, 0.22f), C(0.90f, 0.97f, 1.0f), Color.white,
                        new Vector4(0.85f, 1.6f, 0.25f, 0.08f), Vector4.zero, new Vector4(0.03f, 0.55f, 0.85f, 1.9f));
                    break;
                case 2: // reflective
                    Set(m, C(0.03f, 0.12f, 0.18f), C(0.30f, 0.55f, 0.70f), C(0.90f, 0.97f, 1.0f), Color.white,
                        new Vector4(0.9f, 1.6f, 0.25f, 0.06f), new Vector4(0.35f, 0, 0, 0), new Vector4(0.03f, 0.55f, 0.85f, 1.9f));
                    break;
                case 3: // lava: crust, hot rock, magma; glow, river speed, still speed, plate size
                    Set(m, C(0.07f, 0.035f, 0.03f), C(0.32f, 0.07f, 0.02f), C(1.0f, 0.36f, 0.06f), Color.white,
                        new Vector4(4.0f, 0.45f, 0.06f, 0.9f), Vector4.zero, new Vector4(0.015f, 0.4f, 0.6f, 0.7f));
                    break;
                case 4: // swamp: murky, deep murky, duckweed, mud
                    Set(m, C(0.16f, 0.19f, 0.09f), C(0.06f, 0.08f, 0.04f), C(0.30f, 0.45f, 0.10f), C(0.30f, 0.24f, 0.14f),
                        new Vector4(3.2f, 0.8f, 0.04f, 0.03f), Vector4.zero, new Vector4(0.01f, 0.5f, 0.7f, 0.9f));
                    break;
                case 5: // acid: acid, deep acid, foam; luminescence
                    Set(m, C(0.35f, 1.0f, 0.12f), C(0.05f, 0.35f, 0.06f), C(0.85f, 1.0f, 0.35f), Color.white,
                        new Vector4(1.6f, 1.4f, 0.2f, 0.06f), Vector4.zero, new Vector4(0.025f, 0.6f, 0.9f, 2.1f));
                    break;
                default: // stylized: light blue, deep blue, fringe, lines; thresholds, river speed, still speed
                    Set(m, C(0.22f, 0.53f, 0.74f), C(0.06f, 0.22f, 0.45f), C(0.34f, 0.61f, 0.74f), C(0.96f, 0.99f, 1.0f),
                        new Vector4(0.15f, 0.72f, 1.6f, 0.25f), Vector4.zero, new Vector4(0.03f, 0.55f, 0.85f, 1.9f));
                    break;
            }
        }

        static void Set(Material m, Color a, Color b, Color c, Color d, Vector4 p, Vector4 p2, Vector4 clapot)
        {
            m.SetColor("_ColorA", a);
            m.SetColor("_ColorB", b);
            m.SetColor("_ColorC", c);
            m.SetColor("_ColorD", d);
            m.SetVector("_Params", p);
            m.SetVector("_Params2", p2);
            m.SetVector("_Clapot", clapot);
        }
    }
}
