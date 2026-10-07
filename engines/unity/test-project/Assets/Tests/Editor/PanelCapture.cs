// THE INSPECTOR PANEL, PHOTOGRAPHED (finitions, 7 October 2026): the parity world imported, a layer selected, Paint on —
// once with a selection (Extrude ↑ ↓ Facing, Shrink, Widen), once with the Plant tool (the model, the three modes, the
// brush). What a test cannot see — an icon, a row that overflows — is judged on the picture.
//
//   Unity.exe -projectPath <test-project> -executeMethod PanelCapture.Capture -mbOut <folder>
// (WITH a window: the panel must be drawn on the screen; the editor quits by itself.)

using System;
using System.Reflection;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using MarchingBlocks.Paint;
using MarchingBlocks.Paint.EditorTools;

public static class PanelCapture
{
    static string outDir;
    static int frame;
    static int step;
    static EditorWindow inspector;
    static MBWorldImporter.Result world;

    public static void Capture()
    {
        var args = Environment.GetCommandLineArgs();
        for (int i = 0; i < args.Length - 1; i++) if (args[i] == "-mbOut") outDir = args[i + 1];
        if (string.IsNullOrEmpty(outDir)) outDir = "panel_capture";
        System.IO.Directory.CreateDirectory(outDir);
        EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);
        world = MBWorldImporter.Import(ParityCaptures.WorldJson);
        var T = typeof(MarchingBlocksWorldEditor);
        T.GetField("editing", BindingFlags.Static | BindingFlags.NonPublic).SetValue(null, true);
        var sel = (System.Collections.Generic.HashSet<Int3>)T.GetField("selection", BindingFlags.Static | BindingFlags.NonPublic).GetValue(null);
        sel.Clear();
        sel.Add(new Int3(2, 1, 2));
        sel.Add(new Int3(3, 1, 2));
        Selection.activeGameObject = world.Layers[0].gameObject;
        var type = typeof(Editor).Assembly.GetType("UnityEditor.InspectorWindow");
        inspector = EditorWindow.GetWindow(type);
        inspector.position = new Rect(60, 60, 440, 900);
        inspector.Show();
        inspector.Focus();
        EditorApplication.update += Tick;
    }

    static void Tick()
    {
        frame++;
        // The selection is set again until the picture: the editor's start may forget it.
        if (world.Root != null && Selection.activeGameObject != world.Layers[0].gameObject)
            Selection.activeGameObject = world.Layers[0].gameObject;
        inspector.Repaint();
        // The editor forgets the selection of another object when it opens: given again once it is open.
        if (step == 0 && frame == 60)
        {
            var sel = (System.Collections.Generic.HashSet<Int3>)typeof(MarchingBlocksWorldEditor)
                .GetField("selection", BindingFlags.Static | BindingFlags.NonPublic).GetValue(null);
            sel.Add(new Int3(2, 1, 2));
            sel.Add(new Int3(3, 1, 2));
        }
        if (frame < 120) return;
        var T = typeof(MarchingBlocksWorldEditor);
        if (step == 0)
        {
            Shoot("unity_panel_selection.png");
            T.GetField("mode", BindingFlags.Static | BindingFlags.NonPublic)
                .SetValue(null, Enum.Parse(T.GetNestedType("Mode", BindingFlags.NonPublic), "Plant"));
            ((System.Collections.Generic.HashSet<Int3>)T.GetField("selection", BindingFlags.Static | BindingFlags.NonPublic).GetValue(null)).Clear();
            step = 1;
            frame = 0;
            return;
        }
        Shoot("unity_panel_plant.png");
        EditorApplication.update -= Tick;
        EditorApplication.Exit(0);
    }

    static void Shoot(string name)
    {
        var r = inspector.position;
        float k = EditorGUIUtility.pixelsPerPoint;
        int w = Mathf.RoundToInt(r.width * k), h = Mathf.RoundToInt(r.height * k);
        var pixels = UnityEditorInternal.InternalEditorUtility.ReadScreenPixel(new Vector2(r.x * k, r.y * k), w, h);
        var t = new Texture2D(w, h, TextureFormat.RGBA32, false);
        t.SetPixels(pixels);
        t.Apply();
        System.IO.File.WriteAllBytes(System.IO.Path.Combine(outDir, name), t.EncodeToPNG());
        UnityEngine.Object.DestroyImmediate(t);
        Debug.Log("PanelCapture: " + name);
    }
}
