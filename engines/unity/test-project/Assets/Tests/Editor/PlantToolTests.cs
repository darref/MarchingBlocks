// THE PLANT TOOL THROUGH THE SCENE-VIEW EDITOR (finitions, 7 October 2026), on the parity world
// (DEV_TOOLS/preparer_parite_unity.gd) imported by the REAL glTF importer: Rock (x < 8) and Sand two cells thick, a
// lake in a 3 × 3 hollow of Rock (x 2–4, z 9–11), a block of Lava on Sand, five trees (footprint 0.5).
// Each gesture is what ScenePlant does on a press, a drag and a release, with the world ray a click there would give. The
// expected values come from elsewhere than the code under test: the thinned witness surface is a quarter cell below the
// top of the cells (1.75), the edge of the cells is x = 16, the lake is at y = 1 in the hollow, distances recomputed here.
// The editor's state is private and static: it is read and set through reflection.

using System;
using System.Collections.Generic;
using System.Reflection;
using NUnit.Framework;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using MarchingBlocks.Paint;
using MarchingBlocks.Paint.EditorTools;

public sealed class PlantToolTests
{
    const BindingFlags Static = BindingFlags.Static | BindingFlags.NonPublic;
    const BindingFlags Instance = BindingFlags.Instance | BindingFlags.NonPublic;
    static readonly Type T = typeof(MarchingBlocksWorldEditor);
    static object ModeOf(string name) => Enum.Parse(T.GetNestedType("Mode", BindingFlags.NonPublic), name);
    static PlantSettings Plant => (PlantSettings)T.GetField("plant", Static).GetValue(null);

    MBWorldImporter.Result r;
    MarchingBlocksFoliage foliage;
    Editor editor;
    Matrix4x4 F;
    object savedMode;

    [SetUp]
    public void SetUp()
    {
        EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);
        Assert.IsNotNull(AssetDatabase.LoadAssetAtPath<TextAsset>(ParityCaptures.WorldJson), "run preparer_parite_unity.gd");
        r = MBWorldImporter.Import(ParityCaptures.WorldJson);
        Assert.AreEqual("", r.Error);
        foliage = r.Root.GetComponentInChildren<MarchingBlocksFoliage>();
        Assert.IsNotNull(foliage);
        F = r.Layers[0].FormatToWorld;
        editor = Editor.CreateEditor(r.Layers[0]);
        savedMode = T.GetField("mode", Static).GetValue(null);
        T.GetField("mode", Static).SetValue(null, ModeOf("Plant"));
        T.GetField("plantDraw", Static).SetValue(null, new System.Random(7));
        var s = Plant;
        s.Model = -1; s.Mode = FoliageMode.Free; s.Radius = 3f; s.Tries = 12; s.Spacing = 0f; s.MaxSlope = 40f; s.RandomYaw = true;
        Undo.ClearAll();
    }

    [TearDown]
    public void TearDown()
    {
        T.GetField("mode", Static).SetValue(null, savedMode);
        UnityEngine.Object.DestroyImmediate(editor);
        UnityEngine.Object.DestroyImmediate(r.Root);
    }

    // The world ray of a click straight above a format point.
    Ray Above(float x, float y, float z) =>
        new Ray(F.MultiplyPoint3x4(new Vector3(x, y + 20f, z)), F.MultiplyVector(Vector3.down).normalized);

    // ⚠ A Scene-view event built outside a GUI pass reads as « Ignore » (its rawType stays MouseDown): ScenePlant would
    // see nothing (seen). The press, the drag and the release are handed to what ScenePlant calls on them.
    void Press(Ray ray, bool ctrl = false, bool shift = false) =>
        T.GetMethod("StartPlant", Instance).Invoke(editor, new object[] { ray, ctrl, shift });
    void Drag(Ray ray) => T.GetMethod("PlantDrag", Instance).Invoke(editor, new object[] { ray });
    void Release() => T.GetMethod("EndPlant", Instance).Invoke(editor, null);

    void Click(float x, float y, float z, bool ctrl = false, bool shift = false)
    {
        Press(Above(x, y, z), ctrl, shift);
        Release();
    }

    string Status => (string)T.GetField("status", Instance).GetValue(editor);

    [Test]
    public void AClickPlantsOnTheSurfaceYouSeeAndOneUndoTakesItBack()
    {
        Assert.AreEqual(5, foliage.plants.Count);
        // Off the centre of a cell: an aim rounded to its cell's centre would pass a test that clicks at x.5.
        Click(1.3f, 2f, 6.7f);
        Assert.AreEqual(6, foliage.plants.Count, Status);
        var p = foliage.plants[5];
        Assert.AreEqual(1.75f, p.point.y, 0.02f, "on the TILES (1.75), not on the cells (2)");
        Assert.Less(new Vector2(p.point.x - 1.3f, p.point.z - 6.7f).magnitude, 0.02f, $"where the click was ({p.point})");
        Assert.AreEqual(1, p.model, "the first model when none is chosen");
        Assert.IsTrue(p.planted);
        Assert.AreEqual(6, foliage.LastPlaced, "the new plant is drawn");
        Undo.PerformUndo();
        Assert.AreEqual(5, foliage.plants.Count, "Ctrl+Z takes it back");
        Undo.PerformRedo();
        Assert.AreEqual(6, foliage.plants.Count, "Ctrl+Y gives it back");
    }

    [Test]
    public void TheModesRefuseAndSayWhy()
    {
        // At the edge of the cells (x = 16): free refuses, overflow takes it.
        Click(15.8f, 2f, 2.5f);
        Assert.AreEqual(5, foliage.plants.Count, "free refuses at the edge");
        StringAssert.Contains("edge", Status);
        Plant.Mode = FoliageMode.Overflow;
        Click(15.8f, 2f, 2.5f);
        Assert.AreEqual(6, foliage.plants.Count, Status);
        // In the lake of the hollow: refused, even overflowing.
        Click(3.5f, 2f, 10.5f);
        Assert.AreEqual(6, foliage.plants.Count, "in the lake");
        StringAssert.Contains("water", Status);
        // On a plant: refused.
        Click(1.5f, 2f, 2.5f);
        Assert.AreEqual(6, foliage.plants.Count, "on a plant");
        // In the air, on the plane of the floor (0): over nothing, planted at y = 0; inside the matter, refused.
        Plant.Mode = FoliageMode.Air;
        Click(20.5f, 0f, 3.5f);
        Assert.AreEqual(7, foliage.plants.Count, Status);
        Assert.AreEqual(0f, foliage.plants[6].point.y, 1e-4f);
        Assert.IsFalse(foliage.plants[6].planted);
        Click(5.5f, 0f, 6.5f);
        Assert.AreEqual(7, foliage.plants.Count, "in the air but inside the matter");
        StringAssert.Contains("inside the matter", Status);
    }

    [Test]
    public void TheChosenModelIsPlanted()
    {
        var wide = foliage.models[0];
        wide.id = 9;
        wide.name = "Wide";
        foliage.models.Add(wide);
        Plant.Model = 9;
        Click(5.3f, 2f, 7.7f);
        Assert.AreEqual(9, foliage.plants[foliage.plants.Count - 1].model, Status);
    }

    [Test]
    public void ABrushStrokeIsOneUndoAndItsPlantsRespectEachOther()
    {
        Plant.Radius = 1.5f;
        Plant.Tries = 20;
        int before = foliage.plants.Count;
        Press(Above(5f, 2f, 9f), ctrl: true);
        int afterOne = foliage.plants.Count;
        // ⚠ Unity opens a new undo group at each GUI event: without it here, a stroke that does not collapse its dabs
        // into one step still came back in one Ctrl+Z (mutation muted, seen).
        Undo.IncrementCurrentGroup();
        Drag(Above(5.2f, 2f, 9f));
        Assert.AreEqual(afterOne, foliage.plants.Count, "a drag shorter than 0.4 radius dabs nothing");
        Drag(Above(10f, 2f, 9f));
        int afterTwo = foliage.plants.Count;
        Release();
        Assert.Greater(afterOne, before, "a dab plants");
        Assert.Greater(afterTwo, afterOne, "dragging further gives a second dab");
        var models = new Dictionary<int, MarchingBlocksFoliage.Model>();
        foreach (var m in foliage.models) models[m.id] = m;
        for (int i = before; i < foliage.plants.Count; i++)
        {
            var p = foliage.plants[i];
            Assert.AreEqual(1.75f, p.point.y, 0.05f, $"plant {i} on the surface");
            for (int j = 0; j < foliage.plants.Count; j++)
            {
                if (j == i) continue;
                var q = foliage.plants[j];
                float d = new Vector2(p.point.x - q.point.x, p.point.z - q.point.z).magnitude;
                float sum = models[p.model].footprint * models[p.model].scale * p.scale + models[q.model].footprint * models[q.model].scale * q.scale;
                Assert.GreaterOrEqual(d, sum - 1e-4f, $"plants {i} and {j} overlap (free)");
            }
        }
        Undo.PerformUndo();
        Assert.AreEqual(before, foliage.plants.Count, "ONE Ctrl+Z takes the whole stroke back");
    }

    [Test]
    public void ShiftErasesWithinTheBrushAndUndoGivesThemBack()
    {
        Plant.Radius = 2f;
        // Around (5.5, 4.5): the tree there goes, the one at (1.5, 2.5) — 4.5 away — stays.
        var centre = new Vector3(5.5f, 1.75f, 4.5f);
        int inside = 0;
        foreach (var p in foliage.plants)
            if (new Vector2(p.point.x - centre.x, p.point.z - centre.z).magnitude <= 2f && Vector3.Distance(p.point, centre) <= 2.5f) inside++;
        Assert.AreEqual(1, inside);
        Click(5.5f, 2f, 4.5f, shift: true);
        Assert.AreEqual(4, foliage.plants.Count, Status);
        Undo.PerformUndo();
        Assert.AreEqual(5, foliage.plants.Count, "Ctrl+Z gives it back");
    }

    [Test]
    public void TheWheelSetsTheBrushAndCtrlStaysTheFloor()
    {
        var wheel = T.GetMethod("HandleWheel", Instance);
        var alt = new Event { type = EventType.ScrollWheel, delta = new Vector2(0, -3), modifiers = EventModifiers.Alt };
        Assert.IsTrue((bool)wheel.Invoke(editor, new object[] { alt }));
        Assert.AreEqual(3.5f, Plant.Radius, 1e-5f, "Alt + wheel up: the brush grows");
        var shift = new Event { type = EventType.ScrollWheel, delta = new Vector2(-3, 0), modifiers = EventModifiers.Shift };
        Assert.IsTrue((bool)wheel.Invoke(editor, new object[] { shift }));
        Assert.AreEqual(13, Plant.Tries, "Shift + wheel up: the density");
        int floor = r.Layers[0].floor;
        var ctrl = new Event { type = EventType.ScrollWheel, delta = new Vector2(0, -3), modifiers = EventModifiers.Control };
        Assert.IsTrue((bool)wheel.Invoke(editor, new object[] { ctrl }));
        Assert.AreEqual(floor + 1, r.Layers[0].floor, "Ctrl + wheel: still the floor");
        var plain = new Event { type = EventType.ScrollWheel, delta = new Vector2(0, -3) };
        Assert.IsFalse((bool)wheel.Invoke(editor, new object[] { plain }), "the plain wheel stays Unity's zoom");
    }

    [Test]
    public void AWorldWithoutFoliageSaysSo()
    {
        UnityEngine.Object.DestroyImmediate(foliage.gameObject);
        Click(1.3f, 2f, 6.7f);
        StringAssert.Contains("no MarchingBlocks Foliage", Status);
    }
}
