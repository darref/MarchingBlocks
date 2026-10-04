// THE VARIANTS (the tileset rule, step 8) in Unity, through the REAL glTF importer (glTFast).
//
// Assets/varied.mbset and varied_expected.json are written by MarchingBlocks (DEV_TOOLS/preparer_essai_unity.gd):
// the witness tileset plus two variants of the key of a flat floor, and what the MarchingBlocks tool itself places
// on a 6 × 6 floor with the weights [1, 2, 1]. Then the Variant tool of the Scene-view editor: a click shows the next
// variant, one Undo gives the previous one back, Shift + click gives the tile back to the random draw.
// The editor's click is private: it is reached through reflection, with the vertex a click would find.

using System.Collections.Generic;
using System.IO;
using System.Reflection;
using NUnit.Framework;
using UnityEditor;
using UnityEngine;
using MarchingBlocks.Paint;
using MarchingBlocks.Paint.EditorTools;

public sealed class VariantTests
{
    const string Folder = "Assets/varied.mbset";

    static Dictionary<string, object> Expected() =>
        (Dictionary<string, object>)MBJson.Parse(File.ReadAllText("Assets/varied_expected.json"));

    static MarchingBlocksWorld Build(GameObject go, Dictionary<string, object> exp)
    {
        var w = go.AddComponent<MarchingBlocksWorld>();
        w.tileset = AssetDatabase.LoadAssetAtPath<TextAsset>(Folder + "/tileset.json");
        w.tiles = AssetDatabase.LoadAssetAtPath<GameObject>(Folder + "/tiles.glb");
        Assert.IsNotNull(w.tileset, "varied.mbset/tileset.json is not imported — run preparer_essai_unity.gd");
        Assert.IsNotNull(w.tiles, "varied.mbset/tiles.glb is not imported — is glTFast installed?");
        var cells = new List<Vector3Int>();
        foreach (List<object> c in (List<object>)exp["cells"])
            cells.Add(new Vector3Int((int)MBJson.AsLong(c[0]), (int)MBJson.AsLong(c[1]), (int)MBJson.AsLong(c[2])));
        w.SetCells(cells);
        var weights = new List<int>();
        foreach (var x in (List<object>)exp["weights"]) weights.Add((int)MBJson.AsLong(x));
        w.SetVariantWeights((string)exp["key"], weights.ToArray());
        return w;
    }

    [Test]
    public void TheVariantsArePlacedAsMarchingBlocksPlacesThem()
    {
        var exp = Expected();
        var go = new GameObject("variant test");
        try
        {
            var w = Build(go, exp);
            Assert.AreEqual("", w.LastError);
            Assert.AreEqual(0, w.LastMissing, "red cubes");
            var names = (List<object>)exp["tiles"];
            string key = (string)exp["key"];
            int checkedVariants = 0, variantsPlaced = 0, mismatches = 0;
            string first = null;
            foreach (List<object> e in (List<object>)exp["expected"])
            {
                if (e[3] == null) continue;
                var v = new Int3((int)MBJson.AsLong(e[0]), (int)MBJson.AsLong(e[1]), (int)MBJson.AsLong(e[2]));
                Assert.IsTrue(w.VariantAt(v, out var k, out int count, out int current), $"nothing placed at {v}");
                if (k != key) continue;
                checkedVariants++;
                string placed = (string)names[current];
                if (current > 0) variantsPlaced++;
                if (placed != (string)e[3]) { mismatches++; first = first ?? $"{v}: expected {e[3]}, placed {placed}"; }
            }
            Assert.AreEqual(0, mismatches, $"variants MarchingBlocks places and this package does not, e.g. {first}");
            Assert.Greater(variantsPlaced, 0, "the draw places variants");
            Assert.Less(variantsPlaced, checkedVariants, "… and base tiles");
        }
        finally { UnityEngine.Object.DestroyImmediate(go); }
    }

    [Test]
    public void TheVariantToolCyclesUndoesAndGivesBackToTheDraw()
    {
        var exp = Expected();
        var go = new GameObject("variant tool test");
        Editor editor = null;
        var T = typeof(MarchingBlocksWorldEditor);
        var modeField = T.GetField("mode", BindingFlags.Static | BindingFlags.NonPublic);
        object savedMode = modeField.GetValue(null);
        try
        {
            var w = Build(go, exp);
            editor = Editor.CreateEditor(w);
            Undo.ClearAll();
            var names = (List<object>)exp["tiles"];
            var vp = (List<object>)exp["vertex"];
            var v = new Int3((int)MBJson.AsLong(vp[0]), (int)MBJson.AsLong(vp[1]), (int)MBJson.AsLong(vp[2]));
            var click = T.GetMethod("ClickVariant", BindingFlags.Instance | BindingFlags.NonPublic);
            Assert.IsTrue(w.VariantAt(v, out _, out int count, out int start));
            Assert.AreEqual(2, count, "the floor key has two variants");
            click.Invoke(editor, new object[] { v, false });
            Assert.AreEqual((start + 1) % 3, w.VariantChoices[v], "a click chooses the next variant");
            w.VariantAt(v, out _, out _, out int now);
            Assert.AreEqual((start + 1) % 3, now, "… and the world places it");
            click.Invoke(editor, new object[] { v, false });
            w.VariantAt(v, out _, out _, out now);
            Assert.AreEqual((start + 2) % 3, now, "a second click, the next one");
            Undo.PerformUndo();
            w.Rebuild();
            w.VariantAt(v, out _, out _, out now);
            Assert.AreEqual((start + 1) % 3, now, "one Undo gives the previous one back");
            click.Invoke(editor, new object[] { v, true });
            Assert.IsFalse(w.VariantChoices.ContainsKey(v), "Shift + click: back to the random draw");
            w.VariantAt(v, out _, out _, out now);
            Assert.AreEqual(start, now, "… the drawn tile again");
            // The ray finds the same vertex: from above, onto the top of cell (2, 0, 2).
            var top = w.FormatToWorld.MultiplyPoint3x4(new Vector3(2.5f, 1f, 2.5f));
            var up = w.FormatToWorld.MultiplyVector(Vector3.up).normalized;
            var found = w.TileUnderRay(new Ray(top + up * 10f, -up));
            Assert.IsTrue(found.HasValue && found.Value.Equals(v), $"the tile under a ray onto the top of (2, 0, 2) is {v}, got {found}");
        }
        finally
        {
            if (editor != null) UnityEngine.Object.DestroyImmediate(editor);
            UnityEngine.Object.DestroyImmediate(go);
            modeField.SetValue(null, savedMode);
        }
    }
}
