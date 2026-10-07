// THE REBUILT WATER, in Unity (engines/PARITE.md §12, 3 to 5), on the world DEV_TOOLS/preparer_eau_unity.gd exports (a sea and
// its horizon, a slab over the sea, two waterfalls of one place merged, two rivers on the same cells, a deep lake, three
// rivers down stairs; three water layers, their sheets BAKED by MarchingBlocks):
//   - END TO END: the sheet rebuilt by the plugin from the sources = the baked sheet as glTFast read it (bag of triangles in
//     format space, colours to 1/255) — the frame, the v flip, the winding, measured on the real importer;
//   - THE FOLLOW: a stroke makes the sheet stale and starts nothing while it is held; after the calm a rebuild runs on a
//     worker thread, takes again what the gesture did not reach, and its sheet is the whole computation's;
//   - the times, logged ("MB WATER TIME").
// And WaterCaptures.CaptureAll: the baked and the rebuilt sheet under the six looks, to be judged in the picture.
//   Unity.exe -batchmode -projectPath . -executeMethod WaterCaptures.CaptureAll -mbOut <folder>

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using NUnit.Framework;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using MarchingBlocks.Paint;
using MarchingBlocks.Paint.EditorTools;
using MarchingBlocks.Paint.Tests;

public sealed class WaterRebuildTests
{
    public const string WorldJson = "Assets/water_world.mbworld/world.json";

    public static MBWorldImporter.Result Import()
    {
        Assert.IsNotNull(AssetDatabase.LoadAssetAtPath<TextAsset>(WorldJson), "run DEV_TOOLS/preparer_eau_unity.gd");
        var r = MBWorldImporter.Import(WorldJson);
        Assert.AreEqual("", r.Error);
        return r;
    }

    /// <summary>The triangles of a Unity mesh brought back to FORMAT space: <paramref name="toFormat"/> (importer space →
    /// format), v flipped back, the winding reversed when the conversion mirrors.</summary>
    public static List<double[]> FormatTriangles(Mesh m, Matrix4x4 toFormat)
    {
        var v = m.vertices;
        var n = m.normals;
        var c = m.colors;
        var uv = m.uv;
        var t = m.triangles;
        bool mirror = toFormat.determinant < 0f;
        var o = new List<double[]>();
        for (int k = 0; k < t.Length; k += 3)
        {
            var tri = new double[36];
            int[] ids = mirror ? new[] { t[k], t[k + 2], t[k + 1] } : new[] { t[k], t[k + 1], t[k + 2] };
            for (int j = 0; j < 3; j++)
            {
                int i = ids[j];
                var p = toFormat.MultiplyPoint3x4(v[i]);
                var q = toFormat.MultiplyVector(n[i]).normalized;
                double[] corner = { p.x, p.y, p.z, q.x, q.y, q.z, c[i].r, c[i].g, c[i].b, c[i].a, uv[i].x, 1.0 - uv[i].y };
                Array.Copy(corner, 0, tri, 12 * j, 12);
            }
            o.Add(tri);
        }
        return o;
    }

    /// <summary>The baked sheet of a layer, as glTFast imported it: its mesh and the matrix of its node in the sheet.</summary>
    static (Mesh, Matrix4x4) Baked(MarchingBlocksWater.Layer l)
    {
        Assert.IsNotNull(l.sheet, $"layer {l.name}: no baked sheet");
        var mf = l.sheet.GetComponentInChildren<MeshFilter>();
        var node = l.sheet.transform.worldToLocalMatrix * mf.transform.localToWorldMatrix;
        return (mf.sharedMesh, node);
    }

    static string SameBag(List<double[]> want, List<double[]> got, double colour)
    {
        double keep = WaterMeshConformanceCheck.TolColor;
        WaterMeshConformanceCheck.TolColor = colour;
        try { return WaterMeshConformanceCheck.SameBag(want, got); }
        finally { WaterMeshConformanceCheck.TolColor = keep; }
    }

    [Test]
    public void TheRebuiltSheetIsTheBakedSheetOfTheExportedWorld()
    {
        var r = Import();
        try
        {
            var w = r.Root.GetComponentInChildren<MarchingBlocksWater>();
            Assert.IsNotNull(w);
            Assert.AreEqual(3, w.layers.Count);
            var clock = Stopwatch.StartNew();
            w.RebuildWater();
            UnityEngine.Debug.Log($"MB WATER TIME the whole water world rebuilt (button): {clock.Elapsed.TotalMilliseconds:F0} ms");
            var toFormat = w.frameFrom.ImporterFrameInverse;
            Assert.Less(toFormat.determinant, 0f, "glTFast mirrors (X → −X): measured on the tileset");
            for (int i = 0; i < w.layers.Count; i++)
            {
                var (bakedMesh, node) = Baked(w.layers[i]);
                var baked = FormatTriangles(bakedMesh, toFormat * node);
                var mine = FormatTriangles(w.RebuiltMesh(i), toFormat);
                Assert.Greater(baked.Count, 0);
                // Les couleurs du .glb sont sur 8 bits, TRONQUÉES (mesuré : 2,8e-3, plus qu'un demi-pas) : à 1/255 près.
                var why = SameBag(baked, mine, 1.0 / 255.0 + 1e-5);
                Assert.IsNull(why, $"layer {w.layers[i].name}: the rebuilt sheet is not the baked one — {why} — rebuilt " +
                    $"{WaterMeshConformanceCheck.Summary(mine)}, baked {WaterMeshConformanceCheck.Summary(baked)}");
                // Et ce qui est montré est bien la nappe refaite, avec le matériau de la couche.
                var shown = w.transform.Find("MarchingBlocks water (generated)").Find(w.layers[i].name);
                Assert.AreSame(w.RebuiltMesh(i), shown.GetComponent<MeshFilter>().sharedMesh, "the rebuilt sheet is shown");
                Assert.AreSame(w.layers[i].material, shown.GetComponent<MeshRenderer>().sharedMaterial);
            }
        }
        finally { UnityEngine.Object.DestroyImmediate(r.Root); }
    }

    static void WaitForTheRebuild(MarchingBlocksWater w)
    {
        var clock = Stopwatch.StartNew();
        while (w.Rebuilding && clock.Elapsed.TotalSeconds < 30)
        {
            System.Threading.Thread.Sleep(10);
            w.Tick();
        }
        Assert.IsFalse(w.Rebuilding, "the rebuild did not end in 30 s");
    }

    [Test]
    public void AStrokeMakesTheSheetStaleAndTheCalmRebuildsItOffTheMainThread()
    {
        var r = Import();
        try
        {
            var w = r.Root.GetComponentInChildren<MarchingBlocksWater>();
            w.RebuildWater();
            Assert.IsFalse(w.Follow.Stale);
            var before = w.RebuiltMesh(2);
            // A STROKE: a cell set on the stairs, in the course of the middle river (the Rivers layer).
            var layer = r.Layers[0];
            var change = new Change();
            change.Set.Add(new Int3(27, 6, 2));
            layer.Apply(change);
            Assert.IsTrue(w.Follow.Stale, "a stroke makes the sheet stale");
            // Held: nothing starts, even after the calm.
            System.Threading.Thread.Sleep(600);
            GUIUtility.hotControl = 12345;
            try { w.Tick(); }
            finally { GUIUtility.hotControl = 0; }
            Assert.IsFalse(w.Rebuilding, "never during a gesture");
            Assert.AreSame(before, w.RebuiltMesh(2), "the sheet did not move during the gesture");
            // Released: the next tick starts the rebuild on a worker thread.
            var clock = Stopwatch.StartNew();
            w.Tick();
            double launch = clock.Elapsed.TotalMilliseconds;
            Assert.IsTrue(w.Rebuilding, "after the calm, a rebuild runs");
            WaitForTheRebuild(w);
            UnityEngine.Debug.Log($"MB WATER TIME a stroke on the stairs: the main thread gave {launch:F1} ms to start it; " +
                w.LastRebuildReport);
            Assert.IsFalse(w.Follow.Stale, "rebuilt: up to date");
            Assert.AreNotSame(before, w.RebuiltMesh(2), "a new sheet is shown");
            Assert.Greater(w.LastTaken, 0, "the bodies the stroke did not reach are taken again");
            Assert.Less(w.LastTaken, w.LastBodies, "the river the stroke stopped is computed again");
            // Its sheet is the whole computation's, layer by layer.
            var cells = new HashSet<Int3>(layer.Cells);
            var all = new List<Int3>();
            foreach (var l in w.layers) foreach (var s in l.sources) all.Add(new Int3(s.x, s.y, s.z));
            var whole = MBWater.World(cells, all);
            int k = 0;
            var toFormat = w.frameFrom.ImporterFrameInverse;
            for (int i = 0; i < w.layers.Count; i++)
            {
                var bodies = whole.Bodies.GetRange(k, w.layers[i].sources.Count);
                k += bodies.Count;
                var want = WaterMeshConformanceCheck.Triangles(MBWaterMesh.Arrays(bodies, cells));
                var why = WaterMeshConformanceCheck.SameBag(want, FormatTriangles(w.RebuiltMesh(i), toFormat));
                Assert.IsNull(why, $"layer {w.layers[i].name} after the stroke: {why}");
            }
            // The cell taken away: a gesture again.
            change = new Change();
            change.Clear.Add(new Int3(27, 6, 2));
            layer.Apply(change);
            Assert.IsTrue(w.Follow.Stale);
            System.Threading.Thread.Sleep(600);
            w.Tick();
            WaitForTheRebuild(w);
            UnityEngine.Debug.Log("MB WATER TIME the stroke undone: " + w.LastRebuildReport);
            var (bakedMesh, node) = Baked(w.layers[2]);
            Assert.IsNull(SameBag(FormatTriangles(bakedMesh, toFormat * node), FormatTriangles(w.RebuiltMesh(2), toFormat),
                1.0 / 255.0 + 1e-5), "back to the baked sheet once the cell is gone");
        }
        finally { UnityEngine.Object.DestroyImmediate(r.Root); }
    }

    [Test]
    public void ARebuildOvertakenByAGestureIsNotShown()
    {
        var r = Import();
        try
        {
            var w = r.Root.GetComponentInChildren<MarchingBlocksWater>();
            w.RebuildWater();
            var before = w.RebuiltMesh(0);
            var change = new Change();
            change.Set.Add(new Int3(30, 3, 10));
            r.Layers[0].Apply(change);
            System.Threading.Thread.Sleep(600);
            w.Tick();
            Assert.IsTrue(w.Rebuilding);
            // A new gesture while the worker runs: its result is no longer the world's.
            change = new Change();
            change.Set.Add(new Int3(31, 3, 10));
            r.Layers[0].Apply(change);
            WaitForTheRebuild(w);
            Assert.IsTrue(w.Follow.Stale, "overtaken: still stale");
            Assert.AreSame(before, w.RebuiltMesh(0), "the obsolete sheet is not shown");
            StringAssert.StartsWith("obsolete", w.LastRebuildReport);
            System.Threading.Thread.Sleep(600);
            w.Tick();
            WaitForTheRebuild(w);
            Assert.IsFalse(w.Follow.Stale, "the next rebuild after the calm is shown");
            Assert.AreNotSame(before, w.RebuiltMesh(0));
        }
        finally { UnityEngine.Object.DestroyImmediate(r.Root); }
    }

    [Test]
    public void TheFollowCutsItselfBeyondASecondAndTheButtonStaysThere()
    {
        var r = Import();
        try
        {
            var w = r.Root.GetComponentInChildren<MarchingBlocksWater>();
            w.RebuildWater();
            var f = w.Follow;
            int t = f.Start();
            f.Finished(t, 1.5);
            Assert.IsTrue(f.CutOff);
            // Au-dessus de l'emprise de la mer (niveau 2, + 1) et loin des autres eaux : tout le reste se reprend.
            var change = new Change();
            change.Set.Add(new Int3(30, 4, 10));
            r.Layers[0].Apply(change);
            System.Threading.Thread.Sleep(600);
            w.Tick();
            Assert.IsFalse(w.Rebuilding, "cut: nothing automatic");
            Assert.IsTrue(f.Stale, "the sheet stays stale");
            w.RebuildWater();
            Assert.IsFalse(f.Stale, "the button rebuilds");
            Assert.Greater(w.LastTaken, 0, "the button takes again what the gesture did not reach");
            Assert.IsFalse(f.CutOff, "fast again: the follow is re-armed");
        }
        finally { UnityEngine.Object.DestroyImmediate(r.Root); }
    }
}

public static class WaterCaptures
{
    static string Arg(string name, string fallback)
    {
        var args = Environment.GetCommandLineArgs();
        for (int i = 0; i < args.Length - 1; i++) if (args[i] == name) return args[i + 1];
        return fallback;
    }

    public static void CaptureAll()
    {
        int code = 0;
        try
        {
            string folder = Arg("-mbOut", Path.GetFullPath("Captures"));
            Directory.CreateDirectory(folder);
            EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);
            Shader.SetGlobalFloat("_MBClock", 1.25f);
            Shader.SetGlobalFloat("_MBClockSet", 1f);
            var r = MBWorldImporter.Import(WaterRebuildTests.WorldJson);
            if (r.Error != "") throw new Exception("import: " + r.Error);
            var w = r.Root.GetComponentInChildren<MarchingBlocksWater>();
            var F = r.Layers[0].FormatToWorld;
            var cam = Camera.main;
            cam.fieldOfView = 50f;
            cam.nearClipPlane = 0.05f;
            cam.farClipPlane = 800f;
            cam.backgroundColor = new Color(0.55f, 0.65f, 0.75f);
            cam.clearFlags = CameraClearFlags.SolidColor;
            var light = UnityEngine.Object.FindAnyObjectByType<Light>();
            if (light != null) light.transform.rotation = Quaternion.Euler(50f, -30f, 0f);
            // En espace du FORMAT : l'œil, puis où il regarde.
            var views = new (string, Vector3, Vector3)[]
            {
                ("overview", new Vector3(18f, 24f, -16f), new Vector3(18f, 3f, 12f)),
                ("merged_falls", new Vector3(1f, 9f, 4f), new Vector3(7.5f, 5f, 9.5f)),
                ("stairs", new Vector3(21f, 9f, -5f), new Vector3(28f, 4f, 2f)),
                ("lake", new Vector3(20f, 10f, 12f), new Vector3(20f, 5f, 17.5f)),
                ("sea_slab", new Vector3(-4f, 5f, 24f), new Vector3(1.5f, 2.5f, 19f)),
            };
            void Look(Vector3 eye, Vector3 at)
            {
                var e = F.MultiplyPoint3x4(eye);
                cam.transform.position = e;
                cam.transform.rotation = Quaternion.LookRotation(F.MultiplyPoint3x4(at) - e, Vector3.up);
            }
            Look(views[0].Item2, views[0].Item3);
            UnityEngine.Object.DestroyImmediate(ParityCaptures.Render(cam, 640, 360));   // warm-up (see ParityCaptures)
            string pipeline = ParityCaptures.PipelineName();
            foreach (var look in MBWaterLooks.Looks)
            {
                for (int i = 0; i < w.layers.Count; i++)
                {
                    var l = w.layers[i];
                    l.material = MBWaterLooks.Material(look, "Assets/water_world.mbworld/" + MBLitMaterials.GeneratedFolder);
                    w.layers[i] = l;
                }
                // Baked first (a fresh component shows the baked sheets), then rebuilt.
                foreach (var (name, eye, at) in look == "stylized" ? views : new[] { views[0], views[1] })
                {
                    var shots = new Texture2D[2];
                    for (int pass = 0; pass < 2; pass++)
                    {
                        if (pass == 0) w.ShowBakedSheets();
                        else w.RebuildWater();
                        Look(eye, at);
                        UnityEngine.Object.DestroyImmediate(ParityCaptures.Render(cam, 640, 360));
                        shots[pass] = ParityCaptures.Render(cam, 640, 360);
                        File.WriteAllBytes(Path.Combine(folder, $"{pipeline}_water_{look}_{name}_{(pass == 0 ? "baked" : "rebuilt")}.png"),
                            shots[pass].EncodeToPNG());
                    }
                    var a = shots[0].GetPixels32();
                    var b = shots[1].GetPixels32();
                    double diff = 0;
                    int differing = 0;
                    for (int k = 0; k < a.Length; k++)
                    {
                        int d = Math.Abs(a[k].r - b[k].r) + Math.Abs(a[k].g - b[k].g) + Math.Abs(a[k].b - b[k].b);
                        diff += d;
                        if (d > 6) differing++;
                    }
                    UnityEngine.Debug.Log($"MB WATER PICTURE {pipeline} {look} {name}: baked vs rebuilt {diff / a.Length:F3} per pixel, " +
                        $"{differing} pixel(s) differ by more than 6");
                    UnityEngine.Object.DestroyImmediate(shots[0]);
                    UnityEngine.Object.DestroyImmediate(shots[1]);
                }
            }
        }
        catch (Exception e) { UnityEngine.Debug.LogException(e); code = 1; }
        EditorApplication.Exit(code);
    }
}
