// THE PARITY WORLD (DEV_TOOLS/preparer_parite_unity.gd), imported by Import World through the REAL glTF importer, and
// the editing tools of the parity THROUGH THE SCENE-VIEW EDITOR. What the conformance cases cannot see:
//   - the transitions dress the tiles where Rock and Sand meet, and the overlay DRAWS (pixels compared with and without);
//   - the animated tiles wear MarchingBlocks/Lit, each with the phase of its origin;
//   - the plants stand where the rule puts them; the water sheet wears the look the author suggested;
//   - Extrude (Shift: extend), Widen, Shrink, Room from selection, the wheel (Ctrl: the floor; plain: Unity's zoom).
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

public sealed class ParityWorldTests
{
    const string ContainerName = "MarchingBlocks tiles (generated)";

    static MBWorldImporter.Result Import()
    {
        Assert.IsNotNull(AssetDatabase.LoadAssetAtPath<TextAsset>(ParityCaptures.WorldJson), "run preparer_parite_unity.gd");
        var r = MBWorldImporter.Import(ParityCaptures.WorldJson);
        Assert.AreEqual("", r.Error);
        return r;
    }

    [Test]
    public void TheTransitionsDressTheTilesWhereTheLayersMeet()
    {
        var r = Import();
        try
        {
            var t = r.Root.GetComponent<MarchingBlocksTransitions>();
            Assert.IsNotNull(t, "the world has a pair: the root gets the transitions");
            Assert.AreEqual(1, t.pairs.Count);
            Assert.Greater(t.OverlayCount, 0, "the tiles along the border get an overlay");
            // Only where Rock (x < 8) and Sand meet: every dressed tile's eight cells straddle x = 8.
            foreach (var l in t.Layers())
                foreach (var p in l.PlacedObjects)
                    if (p.Object.transform.Find("MarchingBlocks transition (generated)") != null)
                        Assert.AreEqual(7, p.Vertex.x, $"a tile dressed away from the border, at {p.Vertex}");
            var m = t.OverlayMaterial;
            Assert.IsNotNull(m.GetTexture("_MBCells"), "the cell texture");
            Assert.IsNotNull(m.GetTexture("_MBTable"), "the table");
            Assert.IsNotNull(m.GetTexture("_MBRepData"), "the representatives' data");
        }
        finally { UnityEngine.Object.DestroyImmediate(r.Root); }
    }

    // ⚠ The overlay once drew NOTHING after an asset import (Unity dropped the undeclared arrays of its material): a
    // count of overlays could not see it. The picture of the border is compared with the transitions on and off.
    [Test]
    public void TheOverlayDrawsSomethingAlongTheBorder()
    {
        EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);
        var r = Import();
        try
        {
            var F = r.Layers[0].FormatToWorld;
            var cam = Camera.main;
            var eye = F.MultiplyPoint3x4(new Vector3(8f, 5.5f, 1.5f));
            cam.transform.position = eye;
            cam.transform.rotation = Quaternion.LookRotation(F.MultiplyPoint3x4(new Vector3(8f, 1.75f, 6f)) - eye, Vector3.up);
            UnityEngine.Object.DestroyImmediate(ParityCaptures.Render(cam, 320, 180));   // warm-up (see ParityCaptures)
            var on = ParityCaptures.Render(cam, 320, 180);
            r.Root.GetComponent<MarchingBlocksTransitions>().enabled = false;
            var off = ParityCaptures.Render(cam, 320, 180);
            double diff = 0;
            var a = on.GetPixels32();
            var b = off.GetPixels32();
            for (int k = 0; k < a.Length; k++) diff += Math.Abs(a[k].r - b[k].r) + Math.Abs(a[k].g - b[k].g) + Math.Abs(a[k].b - b[k].b);
            diff /= a.Length;
            UnityEngine.Object.DestroyImmediate(on);
            UnityEngine.Object.DestroyImmediate(off);
            Assert.Greater(diff, 2.0, $"the overlay changes {diff:F2} per pixel on average: it draws nothing");
        }
        finally { UnityEngine.Object.DestroyImmediate(r.Root); }
    }

    [Test]
    public void TheAnimatedTilesWearTheLitCopyAndThePhaseOfTheirOrigin()
    {
        var r = Import();
        try
        {
            var lava = r.Layers[2];
            Assert.AreEqual("Lava", lava.name);
            Assert.IsNotNull(lava.animatedMaterials, "tiles.glb names animated materials: the set is made");
            Assert.Greater(lava.animatedMaterials.entries.Count, 0);
            var manifest = (Dictionary<string, object>)MBJson.Parse(lava.tileset.text);
            var offset = manifest.TryGetValue("piece_offset", out var po) ? ParityCheckVec(po) : new Int3(1, 1, 1);
            int checkedTiles = 0;
            var block = new MaterialPropertyBlock();
            foreach (var p in lava.PlacedObjects)
            {
                var rd = p.Object.GetComponent<MeshRenderer>();
                foreach (var mat in rd.sharedMaterials)
                    Assert.AreEqual("MarchingBlocks/Lit", mat.shader.name, $"tile {p.Vertex}: its material");
                rd.GetPropertyBlock(block);
                float want = (float)MBAnimation.PhaseOf(p.Vertex.x + offset.x, p.Vertex.y + offset.y, p.Vertex.z + offset.z);
                Assert.AreEqual(want, block.GetFloat("_MBPhase"), 1e-6f, $"tile {p.Vertex}: the phase of ITS origin");
                checkedTiles++;
            }
            Assert.Greater(checkedTiles, 0);
            var anim = lava.animatedMaterials.entries[0].animated;
            Assert.IsNotNull(anim.GetTexture("_MBFramesAlbedo"), "the frames travel in a Texture2DArray");
            Assert.AreEqual(4, ((Texture2DArray)anim.GetTexture("_MBFramesAlbedo")).depth, "four frames");
            Assert.AreEqual(new Vector4(4, 4, 0, 0), anim.GetVector("_MBFramesAlbedoParams"), "4 frames, 4 fps, no ping-pong, not synced");
        }
        finally { UnityEngine.Object.DestroyImmediate(r.Root); }
    }

    // THE FRAMES FOLLOW THE CLOCK, on the GPU: the scroll turned off, the lava at t = 0 and t = 0.25 (4 frames per second)
    // shows another frame; at t = 1 (a whole turn of 4 frames) the same picture again.
    [Test]
    public void TheFramesFollowTheClock()
    {
        EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);
        var r = Import();
        var anim = r.Layers[2].animatedMaterials.entries;
        var saved = new List<Vector4>();
        try
        {
            foreach (var e in anim) { saved.Add(e.animated.GetVector("_MBScrollAlbedo")); e.animated.SetVector("_MBScrollAlbedo", Vector4.zero); }
            var F = r.Layers[0].FormatToWorld;
            var cam = Camera.main;
            var eye = F.MultiplyPoint3x4(new Vector3(10f, 6f, 8f));
            cam.transform.position = eye;
            cam.transform.rotation = Quaternion.LookRotation(F.MultiplyPoint3x4(new Vector3(12.5f, 3f, 12.5f)) - eye, Vector3.up);
            Texture2D At(float t)
            {
                Shader.SetGlobalFloat("_MBClockSet", 1f);
                Shader.SetGlobalFloat("_MBClock", t);
                UnityEngine.Object.DestroyImmediate(ParityCaptures.Render(cam, 320, 180));
                return ParityCaptures.Render(cam, 320, 180);
            }
            double Diff(Texture2D a, Texture2D b)
            {
                var pa = a.GetPixels32();
                var pb = b.GetPixels32();
                double d = 0;
                for (int k = 0; k < pa.Length; k++) d += Math.Abs(pa[k].r - pb[k].r) + Math.Abs(pa[k].g - pb[k].g);
                return d / pa.Length;
            }
            var t0 = At(0f);
            var t1 = At(0.25f);
            var t4 = At(1f);
            double next = Diff(t0, t1), turn = Diff(t0, t4);
            Assert.Greater(next, 2.0, $"a quarter second later the lava shows the same frame ({next:F2} per pixel)");
            Assert.Less(turn, 0.5, $"a whole turn later the picture differs ({turn:F2} per pixel)");
        }
        finally
        {
            for (int k = 0; k < anim.Count; k++) anim[k].animated.SetVector("_MBScrollAlbedo", saved.Count > k ? saved[k] : Vector4.zero);
            Shader.SetGlobalFloat("_MBClockSet", 0f);
            UnityEngine.Object.DestroyImmediate(r.Root);
        }
    }

    static Int3 ParityCheckVec(object o)
    {
        var l = (List<object>)o;
        return new Int3((int)MBJson.AsLong(l[0]), (int)MBJson.AsLong(l[1]), (int)MBJson.AsLong(l[2]));
    }

    [Test]
    public void ThePlantsStandWhereTheRulePutsThemAndSwayInTheWind()
    {
        var r = Import();
        try
        {
            var f = r.Root.GetComponentInChildren<MarchingBlocksFoliage>();
            Assert.IsNotNull(f);
            Assert.AreEqual(5, f.LastPlaced, "five plants");
            var F = r.Layers[0].FormatToWorld;
            var container = f.transform.Find("MarchingBlocks plants (generated)");
            for (int i = 0; i < f.plants.Count; i++)
            {
                var p = f.plants[i];
                var m = f.models[0];
                float s = m.scale * p.scale;
                var want = F.MultiplyPoint3x4(p.point + new Vector3(0, m.groundOffset * s, 0));
                var got = container.GetChild(i).position;
                Assert.Less((got - want).magnitude, 1e-4f, $"plant {i}: at {got}, expected {want}");
                foreach (var rd in container.GetChild(i).GetComponentsInChildren<Renderer>())
                {
                    Assert.AreEqual("MarchingBlocks/Lit", rd.sharedMaterial.shader.name, "the wind copy");
                    Assert.IsTrue(rd.sharedMaterial.IsKeywordEnabled("_MB_WIND"), "the wind is on");
                    var block = new MaterialPropertyBlock();
                    rd.GetPropertyBlock(block);
                    var w = MBFoliage.WindData(f.ToRule(m), MarchingBlocksFoliage.ToRule(p));
                    Assert.AreEqual((float)w.Phase, block.GetVector("_MBWind").z, 1e-5f, "its wind phase");
                }
            }
        }
        finally { UnityEngine.Object.DestroyImmediate(r.Root); }
    }

    // THE WIND MOVES THE PLANTS: the same view at two times of the one clock differs; without the wind keyword it does not.
    [Test]
    public void ThePlantsSwayWithTheClock()
    {
        EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);
        var r = Import();
        try
        {
            var f = r.Root.GetComponentInChildren<MarchingBlocksFoliage>();
            var F = r.Layers[0].FormatToWorld;
            var p = f.plants[0].point;
            var cam = Camera.main;
            var eye = F.MultiplyPoint3x4(p + new Vector3(0f, 1.6f, 2.2f));   // looking towards -z: away from the lake and the lava, which move too
            cam.transform.position = eye;
            cam.transform.rotation = Quaternion.LookRotation(F.MultiplyPoint3x4(p + new Vector3(0f, 1.1f, 0f)) - eye, Vector3.up);
            double Diff(float t0, float t1)
            {
                Shader.SetGlobalFloat("_MBClockSet", 1f);
                Shader.SetGlobalFloat("_MBClock", t0);
                UnityEngine.Object.DestroyImmediate(ParityCaptures.Render(cam, 320, 180));
                var a = ParityCaptures.Render(cam, 320, 180);
                Shader.SetGlobalFloat("_MBClock", t1);
                var b = ParityCaptures.Render(cam, 320, 180);
                double d = 0;
                var pa = a.GetPixels32();
                var pb = b.GetPixels32();
                for (int k = 0; k < pa.Length; k++) d += Math.Abs(pa[k].g - pb[k].g);
                UnityEngine.Object.DestroyImmediate(a);
                UnityEngine.Object.DestroyImmediate(b);
                return d / pa.Length;
            }
            double windy = Diff(0f, 1.7f);
            var mats = f.models[0].windMaterials;
            foreach (var m in mats) m.DisableKeyword("_MB_WIND");
            double still;
            try { still = Diff(0f, 1.7f); }
            finally { foreach (var m in mats) m.EnableKeyword("_MB_WIND"); }
            Shader.SetGlobalFloat("_MBClockSet", 0f);
            Assert.Greater(windy, 0.05, $"the plant does not move in the wind ({windy:F3} per pixel)");
            Assert.Less(still, windy / 4, $"without the wind something else moves ({still:F3} against {windy:F3})");
        }
        finally { UnityEngine.Object.DestroyImmediate(r.Root); }
    }

    [Test]
    public void TheWaterSheetWearsTheSuggestedLook()
    {
        var r = Import();
        try
        {
            var w = r.Root.GetComponentInChildren<MarchingBlocksWater>();
            Assert.IsNotNull(w);
            Assert.AreEqual(1, w.layers.Count);
            Assert.AreEqual("clear", w.layers[0].look);
            var sheet = w.transform.Find("MarchingBlocks water (generated)").GetChild(0);
            var rd = sheet.GetComponentInChildren<Renderer>();
            Assert.AreEqual("MarchingBlocks/Water", rd.sharedMaterial.shader.name);
            Assert.IsTrue(rd.sharedMaterial.IsKeywordEnabled("_MB_LOOK_CLEAR"));
            // The water cells, deduced again from the sources and the cells (the rule): a lake in the hollow.
            var cells = w.WaterCells();
            Assert.AreEqual(1, cells.Count);
            Assert.AreEqual("", cells[0].Bodies[0].Error);
            Assert.IsTrue(cells[0].Bodies[0].Water.Contains(new Int3(3, 1, 10)), "the hollow holds water");
        }
        finally { UnityEngine.Object.DestroyImmediate(r.Root); }
    }

    // ── The editing tools, through the editor ─────────────────────────────────────────────────────

    const BindingFlags Static = BindingFlags.Static | BindingFlags.NonPublic;
    const BindingFlags Instance = BindingFlags.Instance | BindingFlags.NonPublic;
    static readonly Type T = typeof(MarchingBlocksWorldEditor);
    static HashSet<Int3> Selection => (HashSet<Int3>)T.GetField("selection", Static).GetValue(null);

    static (GameObject, MarchingBlocksWorld, Editor) Slab()
    {
        var go = new GameObject("parity editing test");
        var w = go.AddComponent<MarchingBlocksWorld>();
        var cells = new List<Vector3Int>();
        for (int x = 0; x < 5; x++) for (int z = 0; z < 5; z++) cells.Add(new Vector3Int(x, 0, z));
        w.SetCells(cells);
        w.floor = 0;
        Selection.Clear();
        Undo.ClearAll();
        return (go, w, Editor.CreateEditor(w));
    }

    [Test]
    public void ExtrudePlacesExtendsAndTheFloorFollows()
    {
        var (go, w, editor) = Slab();
        try
        {
            var extrude = T.GetMethod("Extrude", Instance, null, new[] { typeof(ExtrudeDirection), typeof(ExtrudeMode) }, null);
            // Place, without a selection: the floor's matter, one layer up — 25 cells; the floor follows.
            extrude.Invoke(editor, new object[] { ExtrudeDirection.Up, ExtrudeMode.Place });
            Assert.AreEqual(50, w.CellCount);
            Assert.AreEqual(1, w.floor, "the floor follows the step");
            // Extend, on a selection of one cell: nothing set, the selection grows a step.
            Selection.Add(new Int3(2, 1, 2));
            extrude.Invoke(editor, new object[] { ExtrudeDirection.Up, ExtrudeMode.Extend });
            Assert.AreEqual(50, w.CellCount, "Extend sets nothing");
            CollectionAssert.AreEquivalent(new[] { new Int3(2, 1, 2), new Int3(2, 2, 2) }, Selection);
            Undo.PerformUndo();
            Assert.AreEqual(1, w.floor, "Ctrl+Z: the Extend's floor step goes back");
            Undo.PerformUndo();
            Assert.AreEqual(25, w.CellCount, "Ctrl+Z again: the extrusion goes back");
            Assert.AreEqual(0, w.floor, "and its floor");
        }
        finally { Selection.Clear(); UnityEngine.Object.DestroyImmediate(editor); UnityEngine.Object.DestroyImmediate(go); }
    }

    [Test]
    public void WidenShrinkAndRoomFromSelection()
    {
        var (go, w, editor) = Slab();
        try
        {
            Selection.Add(new Int3(2, 1, 2));
            T.GetMethod("Widen", Instance).Invoke(editor, null);
            Assert.AreEqual(5, Selection.Count, "a cross of five");
            T.GetMethod("Operate", Instance).Invoke(editor, new object[] { SelectionOp.ShrinkEdge });
            CollectionAssert.AreEquivalent(new[] { new Int3(2, 1, 2) }, Selection, "the cross loses its ends");
            // A 3 × 3 footprint on the slab: a room one floor high rises from it.
            Selection.Clear();
            for (int x = 1; x <= 3; x++) for (int z = 1; z <= 3; z++) Selection.Add(new Int3(x, 0, z));
            T.GetField("roomFloors", Static).SetValue(null, 1);
            T.GetField("roomUp", Static).SetValue(null, true);
            var want = MBShapes.RoomFromSelection(w.Cells, Selection, 1, true, out _, out _);
            int before = w.CellCount;
            T.GetMethod("RoomFromSelection", Instance).Invoke(editor, null);
            Assert.AreEqual(before + want.Set.Count - want.Clear.Count, w.CellCount, "the room's cells reach the world");
        }
        finally { Selection.Clear(); UnityEngine.Object.DestroyImmediate(editor); UnityEngine.Object.DestroyImmediate(go); }
    }

    [Test]
    public void TheSelectBrushTakesTheEmptyCellsOnlyWhenAsked()
    {
        var (go, w, editor) = Slab();
        var touch = T.GetMethod("Touch", Instance);
        var select = Enum.Parse(T.GetNestedType("Mode", BindingFlags.NonPublic), "Select");
        var savedMode = T.GetField("mode", Static).GetValue(null);
        try
        {
            T.GetField("mode", Static).SetValue(null, select);
            // A full cell (2, 0, 2) and the empty one above it.
            var cells = new List<Int3> { new Int3(2, 0, 2), new Int3(2, 1, 2) };
            T.GetField("selectEmpty", Static).SetValue(null, false);
            touch.Invoke(editor, new object[] { BrushTool.Select, new Int3(2, 0, 2), new Hit(), cells, false });
            CollectionAssert.AreEquivalent(new[] { new Int3(2, 0, 2) }, Selection, "the matter only");
            T.GetField("lastKey", Instance).SetValue(editor, null);
            T.GetField("selectEmpty", Static).SetValue(null, true);
            touch.Invoke(editor, new object[] { BrushTool.Select, new Int3(2, 0, 2), new Hit(), cells, false });
            CollectionAssert.AreEquivalent(cells, Selection, "Select empty cells too");
        }
        finally
        {
            T.GetField("selectEmpty", Static).SetValue(null, false);
            T.GetField("mode", Static).SetValue(null, savedMode);
            Selection.Clear(); UnityEngine.Object.DestroyImmediate(editor); UnityEngine.Object.DestroyImmediate(go);
        }
    }

    [Test]
    public void TheWheelTakesCtrlForTheFloorAndLeavesThePlainWheelToUnity()
    {
        var (go, w, editor) = Slab();
        var wheel = T.GetMethod("HandleWheel", Instance);
        try
        {
            var plain = new Event { type = EventType.ScrollWheel, delta = new Vector2(0, -3) };
            Assert.IsFalse((bool)wheel.Invoke(editor, new object[] { plain }), "the plain wheel is Unity's zoom");
            Assert.AreEqual(EventType.ScrollWheel, plain.type, "and it is not used");
            var ctrl = new Event { type = EventType.ScrollWheel, delta = new Vector2(0, -3), modifiers = EventModifiers.Control };
            Assert.IsTrue((bool)wheel.Invoke(editor, new object[] { ctrl }));
            Assert.AreEqual(1, w.floor, "Ctrl + wheel up: one floor higher");
            Assert.AreEqual(EventType.Used, ctrl.type);
            // Shift + wheel on Windows arrives as a horizontal scroll: read too.
            Selection.Add(new Int3(2, 0, 2));
            T.GetField("mode", Static).SetValue(null, Enum.Parse(T.GetNestedType("Mode", BindingFlags.NonPublic), "Select"));
            var shift = new Event { type = EventType.ScrollWheel, delta = new Vector2(-3, 0), modifiers = EventModifiers.Shift };
            Assert.IsTrue((bool)wheel.Invoke(editor, new object[] { shift }));
            CollectionAssert.AreEquivalent(new[] { new Int3(2, 0, 2), new Int3(2, 1, 2) }, Selection, "Shift + wheel up: Extend selection ↑");
        }
        finally { Selection.Clear(); UnityEngine.Object.DestroyImmediate(editor); UnityEngine.Object.DestroyImmediate(go); }
    }
}
