// SEEN IN THE PICTURE — captures of the parity world (DEV_TOOLS/preparer_parite_unity.gd), rendered by the package in
// THIS project's pipeline, for a human (or Claude, with an image reader) to judge. No shader is guarded by a case: a
// look is judged in the picture.
//
//   Unity.exe -batchmode -projectPath . -executeMethod ParityCaptures.CaptureAll -mbOut <folder> [-mbTime <seconds>]
//
// (NOT -nographics: nothing would be drawn.) Writes <folder>/<pipeline>_<shot>.png and exits.

using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using MarchingBlocks.Paint;
using MarchingBlocks.Paint.EditorTools;

public static class ParityCaptures
{
    public const string WorldJson = "Assets/parity_world.mbworld/world.json";

    static string Arg(string name, string fallback)
    {
        var args = Environment.GetCommandLineArgs();
        for (int i = 0; i < args.Length - 1; i++) if (args[i] == name) return args[i + 1];
        return fallback;
    }

    public static string PipelineName()
    {
        var rp = UnityEngine.Rendering.GraphicsSettings.currentRenderPipeline;
        return rp == null ? "builtin" : rp.GetType().Name.Contains("Universal") ? "urp" : rp.GetType().Name;
    }

    public static void CaptureAll()
    {
        int code = 0;
        try
        {
            string folder = Arg("-mbOut", Path.GetFullPath("Captures"));
            Directory.CreateDirectory(folder);
            float time = float.Parse(Arg("-mbTime", "0"), System.Globalization.CultureInfo.InvariantCulture);
            // What the shaders say: a shader that does not compile draws nothing, without a word in the log.
            foreach (var name in new[] { "MarchingBlocks/Transition Overlay", "MarchingBlocks/Lit", "MarchingBlocks/Water" })
            {
                var sh = Shader.Find(name);
                if (sh == null) { Debug.LogError("MB SHADER missing: " + name); continue; }
                foreach (var m in ShaderUtil.GetShaderMessages(sh))
                    Debug.Log($"MB SHADER {name}: {m.severity} {m.message} ({m.file}:{m.line})");
                Debug.Log($"MB SHADER {name}: supported {sh.isSupported}, {ShaderUtil.GetShaderMessageCount(sh)} message(s)");
            }
            foreach (var kv in Capture(time))
            {
                string path = Path.Combine(folder, $"{PipelineName()}_{kv.Key}.png");
                File.WriteAllBytes(path, kv.Value.EncodeToPNG());
                Debug.Log("MB CAPTURE " + path);
            }
        }
        catch (Exception e) { Debug.LogException(e); code = 1; }
        EditorApplication.Exit(code);
    }

    /// <summary>Imports the parity world into a new scene and renders the shots. The world's clock is set to
    /// <paramref name="time"/> (MarchingBlocks/Lit reads _MBClock).</summary>
    public static Dictionary<string, Texture2D> Capture(float time)
    {
        EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);
        Shader.SetGlobalFloat("_MBClock", time);
        Shader.SetGlobalFloat("_MBClockSet", 1f);
        var r = MBWorldImporter.Import(WorldJson);
        if (r.Error != "") throw new Exception("import: " + r.Error);
        if (r.Warning != "") Debug.LogWarning("MB import: " + r.Warning);
        var tr = r.Root.GetComponent<MarchingBlocksTransitions>();
        Debug.Log("MB OVERLAYS " + (tr != null ? tr.OverlayCount.ToString() : "no transitions component"));
        if (tr != null && tr.OverlayMaterial != null)
        {
            var mat = tr.OverlayMaterial;
            var table = mat.GetTexture("_MBTable") as Texture2D;
            var cells = mat.GetTexture("_MBCells") as Texture3D;
            Debug.Log($"MB TABLE {(table == null ? "null" : table.GetPixel(0, 1) + " " + table.GetPixel(2, 0))} CELLS {(cells == null ? "null" : cells.width + "x" + cells.height + "x" + cells.depth)} origin {mat.GetVector("_MBCellsOrigin")} reps {mat.GetTexture("_MBReps")}");
        }
        var layer = r.Layers[0];
        var F = layer.FormatToWorld;
        var cam = Camera.main;
        cam.fieldOfView = 45f;
        cam.nearClipPlane = 0.05f;
        cam.farClipPlane = 500f;
        cam.backgroundColor = new Color(0.55f, 0.65f, 0.75f);
        cam.clearFlags = CameraClearFlags.SolidColor;
        var light = UnityEngine.Object.FindAnyObjectByType<Light>();
        if (light != null) light.transform.rotation = Quaternion.Euler(50f, -30f, 0f);
        var shots = new Dictionary<string, Texture2D>();
        // Points in FORMAT space (the world is 16 × 16 cells): the camera, then where it looks.
        var views = new (string, Vector3, Vector3)[]
        {
            ("overview", new Vector3(8f, 14f, -9f), new Vector3(8f, 1f, 7f)),
            ("transition", new Vector3(8f, 5.5f, 1.5f), new Vector3(8f, 1.75f, 6f)),
            ("lava", new Vector3(10f, 6f, 8f), new Vector3(12.5f, 3f, 12.5f)),
            ("lake", new Vector3(3f, 5f, 6f), new Vector3(3f, 1.5f, 10f)),
        };
        // ⚠ A WARM-UP RENDER (seen in URP): the first Camera.Render after the import showed some tiles with the OTHER
        // layer's material, a different patch at every run; every later render is right.
        cam.transform.position = F.MultiplyPoint3x4(views[0].Item2);
        cam.transform.rotation = Quaternion.LookRotation(F.MultiplyPoint3x4(views[0].Item3) - cam.transform.position, Vector3.up);
        UnityEngine.Object.DestroyImmediate(Render(cam, 1280, 720));
        foreach (var (name, eye, at) in views)
        {
            var e = F.MultiplyPoint3x4(eye);
            var a = F.MultiplyPoint3x4(at);
            cam.transform.position = e;
            cam.transform.rotation = Quaternion.LookRotation(a - e, Vector3.up);
            shots[name] = Render(cam, 1280, 720);
        }
        return shots;
    }

    public static Texture2D Render(Camera cam, int w, int h)
    {
        var rt = RenderTexture.GetTemporary(w, h, 24, RenderTextureFormat.ARGB32);
        var previous = cam.targetTexture;
        cam.targetTexture = rt;
        cam.Render();
        var active = RenderTexture.active;
        RenderTexture.active = rt;
        var tex = new Texture2D(w, h, TextureFormat.RGB24, false);
        tex.ReadPixels(new Rect(0, 0, w, h), 0, 0);
        tex.Apply();
        RenderTexture.active = active;
        cam.targetTexture = previous;
        RenderTexture.ReleaseTemporary(rt);
        return tex;
    }
}
