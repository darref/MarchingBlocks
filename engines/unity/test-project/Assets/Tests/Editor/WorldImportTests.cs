// The world import on a REAL painted world exported by MarchingBlocks, through the REAL glTF importer.
//
// Assets/witness_world.mbworld and witness_world_expected.json are written by MarchingBlocks
// (DEV_TOOLS/preparer_essai_unity.gd): three layers — Rock (the witness shape), Ice (HIDDEN, same tile
// source, so the same .mbset folder) and Draft (no tiles). The expected cells, visibility and placements
// come from MarchingBlocks' own reference, never from this package.

using System.Collections.Generic;
using System.IO;
using NUnit.Framework;
using UnityEditor;
using UnityEngine;
using MarchingBlocks.Paint;
using MarchingBlocks.Paint.EditorTools;

public sealed class WorldImportTests
{
    const string WorldJson = "Assets/witness_world.mbworld/world.json";
    const string ContainerName = "MarchingBlocks tiles (generated)";

    static List<object> Expected() => (List<object>)MBJson.Parse(File.ReadAllText("Assets/witness_world_expected.json"));

    [Test]
    public void EveryLayerArrivesInOrderWithItsCellsVisibilityAndTiles()
    {
        Assert.IsNotNull(AssetDatabase.LoadAssetAtPath<TextAsset>(WorldJson), "run preparer_essai_unity.gd");
        var r = MBWorldImporter.Import(WorldJson);
        try
        {
            Assert.AreEqual("", r.Error);
            Assert.AreEqual("witness_world", r.Root.name, "the root is named after the world");
            var expected = Expected();
            Assert.AreEqual(expected.Count, r.Root.transform.childCount, "one child per layer");
            Assert.AreEqual(expected.Count, r.Layers.Count);
            CollectionAssert.AreEqual(new[] { "Draft" }, r.WithoutTiles, "the layer without tiles is named");
            CollectionAssert.IsEmpty(r.Missing, "tiles not found");
            StringAssert.Contains("Draft", r.Warning, "the warning names the layer without tiles");
            for (int i = 0; i < expected.Count; i++)
            {
                var e = (Dictionary<string, object>)expected[i];
                var w = r.Layers[i];
                string name = (string)e["name"];
                Assert.AreSame(r.Root.transform.GetChild(i).gameObject, w.gameObject, $"{name}: layer order");
                Assert.AreEqual(name, w.name, "layer name");
                Assert.AreEqual((bool)e["visible"], w.gameObject.activeSelf, $"{name}: active = visible");
                var want = new HashSet<Int3>();
                foreach (List<object> c in (List<object>)e["cells"])
                    want.Add(new Int3((int)MBJson.AsLong(c[0]), (int)MBJson.AsLong(c[1]), (int)MBJson.AsLong(c[2])));
                Assert.IsTrue(want.SetEquals(w.Cells), $"{name}: the cells differ ({w.CellCount} imported, {want.Count} expected)");
                Assert.AreEqual(want.Count, w.CellCount, $"{name}: a cell stored twice");
            }
            // Two layers of the same source share ONE tileset folder, hence the same assets.
            Assert.AreSame(r.Layers[0].tileset, r.Layers[1].tileset, "Rock and Ice share their tileset.json");
            Assert.AreSame(r.Layers[0].tiles, r.Layers[1].tiles, "Rock and Ice share their tiles.glb");
            // The layer without tiles gets none: nothing is invented.
            Assert.IsNull(r.Layers[2].tileset);
            Assert.IsNull(r.Layers[2].tiles);
        }
        finally { if (r.Root != null) Object.DestroyImmediate(r.Root); }
    }

    [Test]
    public void EachLayerPlacesExactlyWhatMarchingBlocksPlaces()
    {
        var r = MBWorldImporter.Import(WorldJson);
        try
        {
            Assert.AreEqual("", r.Error);
            var expected = Expected();
            int checkedLayers = 0;
            for (int i = 0; i < expected.Count; i++)
            {
                var e = (Dictionary<string, object>)expected[i];
                var w = r.Layers[i];
                string name = (string)e["name"];
                // A hidden layer is built when it is shown; build it here to compare it too.
                if (!w.gameObject.activeSelf) w.Rebuild();
                var container = w.transform.Find(ContainerName);
                if (e["expected"] == null)
                {
                    Assert.AreEqual(0, w.LastPlaced, $"{name}: a layer without tiles placed some");
                    Assert.IsTrue(container == null || container.childCount == 0, $"{name}: something was placed");
                    continue;
                }
                checkedLayers++;
                var set = MBTileset.Load(w.tileset, w.tiles, out var error);
                Assert.IsNull(error, error);
                var poses = (List<object>)e["expected"];
                int tiles = 0;
                foreach (List<object> p in poses) if (p[3] != null) tiles++;
                Assert.AreEqual("", w.LastError, name);
                Assert.Greater(tiles, 0, $"{name}: the expectation places nothing, it would guard nothing");
                Assert.AreEqual(tiles, w.LastPlaced, $"{name}: tile count");
                Assert.AreEqual(poses.Count - tiles, w.LastMissing, $"{name}: red cubes");

                var placed = new Dictionary<string, int>();
                foreach (Transform t in container)
                {
                    if (t.name == "missing tile") continue;
                    string k = WitnessTests.Key(t.name, set.FrameInverse.MultiplyVector(t.localPosition), WitnessTests.TurnsOf(set, t));
                    placed.TryGetValue(k, out var n);
                    placed[k] = n + 1;
                }
                var offset = set.Rule.PieceOffset;
                int mismatches = 0;
                string first = null;
                foreach (List<object> p in poses)
                {
                    if (p[3] == null) continue;
                    var v = new Vector3(MBJson.AsLong(p[0]) + offset.x, MBJson.AsLong(p[1]) + offset.y, MBJson.AsLong(p[2]) + offset.z);
                    string k = WitnessTests.Key((string)p[3], v, (int)MBJson.AsLong(p[4]));
                    if (placed.TryGetValue(k, out var n) && n > 0) placed[k] = n - 1;
                    else { mismatches++; first = first ?? k; }
                }
                Debug.Log($"world layer {name}: {tiles} placements expected, {mismatches} not placed");
                Assert.AreEqual(0, mismatches, $"{name}: placements MarchingBlocks makes and this package does not, e.g. {first}");
            }
            Assert.AreEqual(2, checkedLayers, "Rock and Ice must both be compared");
        }
        finally { if (r.Root != null) Object.DestroyImmediate(r.Root); }
    }

    [Test]
    public void TheWholeImportIsOneUndoStep()
    {
        var r = MBWorldImporter.Import(WorldJson);
        Assert.AreEqual("", r.Error);
        var root = r.Root;
        Undo.PerformUndo();
        bool gone = root == null;
        if (!gone) Object.DestroyImmediate(root);
        Assert.IsTrue(gone, "one Undo does not take the imported world back");
    }

    [Test]
    public void ANewerWorldIsRefusedAndLeavesNothing()
    {
        string path = "Assets/witness_world.mbworld/newer_world.json";
        File.WriteAllText(path, File.ReadAllText(WorldJson).Replace("\"version\": 1", "\"version\": 2"));
        try
        {
            Assert.IsTrue(File.ReadAllText(path).Contains("\"version\": 2"), "the test could not write a newer world");
            int before = Object.FindObjectsByType<MarchingBlocksWorld>(FindObjectsInactive.Include).Length;
            var r = MBWorldImporter.Import(path);
            Assert.AreNotEqual("", r.Error, "a newer world is imported");
            Assert.IsNull(r.Root);
            Assert.AreEqual(before, Object.FindObjectsByType<MarchingBlocksWorld>(FindObjectsInactive.Include).Length,
                "a refused world left layers behind");
        }
        finally { File.Delete(path); }
    }
}
