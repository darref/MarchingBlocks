// Two MarchingBlocksWorld layers of ONE world (the tileset rule, step 7), on the REAL witness tileset.
//
// The placement rule itself is guarded by conformance.json (its layered cases come from MarchingBlocks' own
// reference). This guards the COMPONENT: sibling GameObjects are the layers of one world, in child order;
// Apply takes the cells it sets from the other layers and the whole change is ONE undo step; an inactive
// layer leaves the world.

using System.Collections.Generic;
using NUnit.Framework;
using UnityEditor;
using UnityEngine;
using MarchingBlocks.Paint;

public sealed class LayersTests
{
    const string Folder = "Assets/witness.mbset";
    const string ContainerName = "MarchingBlocks tiles (generated)";

    static MarchingBlocksWorld Layer(Transform parent, string name, int x0, int x1, int y1)
    {
        var go = new GameObject(name);
        go.transform.SetParent(parent, false);
        var w = go.AddComponent<MarchingBlocksWorld>();
        w.tileset = AssetDatabase.LoadAssetAtPath<TextAsset>(Folder + "/tileset.json");
        w.tiles = AssetDatabase.LoadAssetAtPath<GameObject>(Folder + "/tiles.glb");
        Assert.IsNotNull(w.tileset, "run preparer_essai_unity.gd");
        for (int x = x0; x <= x1; x++)
            for (int y = 0; y <= y1; y++)
                for (int z = 0; z < 6; z++)
                    w.SetCell(new Vector3Int(x, y, z), true);
        return w;
    }

    // What a layer placed, as tile@vertex/turns keys (format space), compared with what the rule asks of it.
    static HashSet<string> Placed(MarchingBlocksWorld w, MBTileset set)
    {
        var keys = new HashSet<string>();
        var container = w.transform.Find(ContainerName);
        if (container == null) return keys;
        foreach (Transform t in container)
            if (t.name != "missing tile")
                keys.Add(WitnessTests.Key(t.name, set.FrameInverse.MultiplyVector(t.localPosition), WitnessTests.TurnsOf(set, t)));
        return keys;
    }

    static HashSet<string> Wanted(MarchingBlocksWorld[] layers, int which, MBTileset set)
    {
        var cells = new List<HashSet<Int3>>();
        var visible = new List<bool>();
        var rules = new List<Rule>();
        foreach (var l in layers) { cells.Add(l.Cells); visible.Add(l.gameObject.activeSelf); rules.Add(set.Rule); }
        var keys = new HashSet<string>();
        var o = set.Rule.PieceOffset;
        foreach (var p in Rule.PlacementsLayered(cells, visible, rules)[which])
            if (p.Tile != null)
                keys.Add(WitnessTests.Key(p.Tile, new Vector3(p.Vertex.x + o.x, p.Vertex.y + o.y, p.Vertex.z + o.z), p.QuarterTurns));
        return keys;
    }

    [Test]
    public void SiblingLayersAreOneWorld()
    {
        var root = new GameObject("two layers");
        try
        {
            var a = Layer(root.transform, "A", 0, 5, 1);
            var b = Layer(root.transform, "B", 6, 9, 2);
            a.RebuildWorld();
            var set = MBTileset.Load(a.tileset, a.tiles, out var error);
            Assert.IsNull(error, error);
            var layers = new[] { a, b };
            CollectionAssert.AreEqual(layers, a.Layers(), "the layers are the siblings, in child order");
            Assert.IsTrue(Wanted(layers, 0, set).SetEquals(Placed(a, set)), "A places what the rule asks of it");
            Assert.IsTrue(Wanted(layers, 1, set).SetEquals(Placed(b, set)), "B places what the rule asks of it");
            var alone = new HashSet<string>();
            var o = set.Rule.PieceOffset;
            foreach (var p in set.Rule.Placements(a.Cells))
                if (p.Tile != null) alone.Add(WitnessTests.Key(p.Tile, new Vector3(p.Vertex.x + o.x, p.Vertex.y + o.y, p.Vertex.z + o.z), p.QuarterTurns));
            Assert.IsFalse(alone.SetEquals(Placed(a, set)), "control: alone, A would place its own wall at the border");

            // A cell belongs to one layer: painting it in B takes it from A — and ONE undo gives it back.
            var taken = new Int3(5, 0, 0);
            Undo.IncrementCurrentGroup();
            Undo.RecordObjects(b.LayerObjects(), "Add matter");
            var change = new Change();
            change.Set.Add(taken);
            b.Apply(change);
            Assert.IsFalse(a.Cells.Contains(taken), "painting in B takes the cell from A");
            Assert.IsTrue(b.Cells.Contains(taken));
            Assert.IsTrue(Wanted(layers, 0, set).SetEquals(Placed(a, set)), "A is rebuilt around the border that moved");
            Undo.PerformUndo();
            a.RebuildWorld();
            Assert.IsTrue(a.Cells.Contains(taken), "one undo gives the cell back to A");
            Assert.IsFalse(b.Cells.Contains(taken), "… and takes it from B");

            // An inactive layer leaves the world: B closes without A, and A places nothing.
            a.gameObject.SetActive(false);
            a.Rebuild();
            Assert.IsTrue(Wanted(layers, 1, set).SetEquals(Placed(b, set)), "A hidden: B places what it would place alone");
            Assert.AreEqual(0, Placed(a, set).Count, "a hidden layer places nothing");
        }
        finally { Object.DestroyImmediate(root); }
    }
}
