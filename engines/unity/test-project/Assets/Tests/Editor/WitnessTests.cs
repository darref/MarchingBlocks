// The Unity package on the REAL witness, through the REAL glTF importer (glTFast).
//
// Assets/witness.mbset, witness_cells.json and witness_expected.json are written by MarchingBlocks
// (DEV_TOOLS/preparer_essai_unity.gd); witness_expected.json is what the MarchingBlocks tool itself
// places on those cells. Three checks, and the first and last do not rely on this package's own maths:
//   1. the frame: a right-handed → left-handed conversion is necessarily a REFLECTION, and up stays up;
//   2. the placements: the same tiles, turns and positions as MarchingBlocks;
//   3. the geometry: every placed triangle, fingerprinted in format space, must be MarchingBlocks' own.

using System.Collections.Generic;
using System.IO;
using NUnit.Framework;
using UnityEditor;
using UnityEngine;
using MarchingBlocks.Paint;

public sealed class WitnessTests
{
    const string Folder = "Assets/witness.mbset";

    static List<object> ReadJson(string path) => (List<object>)MBJson.Parse(File.ReadAllText(path));

    static MBTileset LoadSet()
    {
        var manifest = AssetDatabase.LoadAssetAtPath<TextAsset>(Folder + "/tileset.json");
        var tiles = AssetDatabase.LoadAssetAtPath<GameObject>(Folder + "/tiles.glb");
        Assert.IsNotNull(manifest, "tileset.json is not imported as a TextAsset — run preparer_essai_unity.gd");
        Assert.IsNotNull(tiles, "tiles.glb is not imported as a GameObject — is glTFast installed?");
        var set = MBTileset.Load(manifest, tiles, out var error);
        Assert.IsNull(error, error);
        return set;
    }

    [Test]
    public void TheImporterFrameIsAReflectionAndKeepsUpUp()
    {
        var set = LoadSet();
        Debug.Log($"glTFast frame: X→{set.Frame.GetColumn(0)} Y→{set.Frame.GetColumn(1)} Z→{set.Frame.GetColumn(2)} unit={set.Unit}");
        Assert.IsTrue(set.Mirrored, "a right-handed to left-handed conversion must be a reflection");
        Vector3 up = set.Frame.MultiplyVector(Vector3.up).normalized;
        Assert.That(Vector3.Distance(up, Vector3.up), Is.LessThan(1e-4f), $"format +Y goes to {up}, not to Unity's up");
    }

    [Test]
    public void TheWitnessIsPlacedExactlyAsMarchingBlocksPlacesIt()
    {
        var set = LoadSet();
        var go = new GameObject("witness test");
        try
        {
            var world = Build(go);
            var expected = ReadJson("Assets/witness_expected.json");
            int tiles = 0;
            foreach (List<object> e in expected) if (e[3] != null) tiles++;
            Assert.AreEqual("", world.LastError);
            Assert.AreEqual(0, world.LastMissing, "red cubes on the witness");
            Assert.AreEqual(tiles, world.LastPlaced, "tile count");

            // What was placed: (tile, position in format space, quarter turns read back from the rotation).
            var placed = new Dictionary<string, int>();
            var container = go.transform.GetChild(0);
            foreach (Transform t in container)
            {
                Vector3 f = set.FrameInverse.MultiplyVector(t.localPosition);
                placed.TryGetValue(Key(t.name, f, TurnsOf(set, t)), out var n);
                placed[Key(t.name, f, TurnsOf(set, t))] = n + 1;
            }
            var offset = set.Rule.PieceOffset;
            int mismatches = 0;
            string first = null;
            foreach (List<object> e in expected)
            {
                if (e[3] == null) continue;
                var v = new Vector3(MBJson.AsLong(e[0]) + offset.x, MBJson.AsLong(e[1]) + offset.y, MBJson.AsLong(e[2]) + offset.z);
                string k = Key((string)e[3], v, (int)MBJson.AsLong(e[4]));
                if (placed.TryGetValue(k, out var n) && n > 0) placed[k] = n - 1;
                else { mismatches++; first = first ?? k; }
            }
            Assert.AreEqual(0, mismatches, $"placements MarchingBlocks makes and this package does not, e.g. {first}");
        }
        finally { Object.DestroyImmediate(go); }
    }

    // THE PLACED GEOMETRY, fingerprinted exactly as MarchingBlocks does it (preparer_essai_unity.gd): the
    // centre of every placed triangle, in FORMAT space, times 1200 (the witness coordinates are multiples
    // of 1/12, so these are exact integers — no rounding can differ between engines), sorted, MD5.
    // One tile turned or mirrored the wrong way changes it. (A seam-closure check was tried first and
    // proved blind: the thinned witness tiles are closed, disjoint boxes, so any rotation closes.)
    [Test]
    public void ThePlacedGeometryIsMarchingBlocksOwn()
    {
        var set = LoadSet();
        var go = new GameObject("witness geometry");
        try
        {
            Build(go);
            var container = go.transform.GetChild(0);
            var centres = new List<string>();
            foreach (Transform t in container)
            {
                var mesh = t.GetComponent<MeshFilter>().sharedMesh;
                var m = set.FrameInverse * (container.worldToLocalMatrix * t.localToWorldMatrix);
                var verts = mesh.vertices;
                for (int s = 0; s < mesh.subMeshCount; s++)
                {
                    var tri = mesh.GetTriangles(s);
                    for (int i = 0; i < tri.Length; i += 3)
                    {
                        Vector3 c = (m.MultiplyPoint3x4(verts[tri[i]]) + m.MultiplyPoint3x4(verts[tri[i + 1]])
                                     + m.MultiplyPoint3x4(verts[tri[i + 2]])) * 400f;
                        centres.Add($"{Mathf.RoundToInt(c.x)},{Mathf.RoundToInt(c.y)},{Mathf.RoundToInt(c.z)}");
                    }
                }
            }
            centres.Sort(System.StringComparer.Ordinal);
            string fingerprint;
            using (var md5 = System.Security.Cryptography.MD5.Create())
            {
                var bytes = md5.ComputeHash(System.Text.Encoding.UTF8.GetBytes(string.Join("\n", centres)));
                fingerprint = System.BitConverter.ToString(bytes).Replace("-", "").ToLowerInvariant();
            }
            var geometry = (Dictionary<string, object>)MBJson.Parse(File.ReadAllText("Assets/witness_geometry.json"));
            Debug.Log($"witness geometry: {centres.Count} triangles, fingerprint {fingerprint} (MarchingBlocks: {geometry["centroids_md5"]})");
            Assert.AreEqual(MBJson.AsLong(geometry["triangles"]), (long)centres.Count, "triangle count");
            Assert.AreEqual((string)geometry["centroids_md5"], fingerprint,
                "the placed geometry differs from MarchingBlocks' — a tile turned, mirrored or offset");
        }
        finally { Object.DestroyImmediate(go); }
    }

    // THE TOOLS AIM THROUGH THE MEASURED FRAME. glTFast mirrors X: a ray taken from the world must be
    // brought back to format space by the inverse of that map, or it would hit the wrong side of the
    // matter. The expected cells come from the witness cells alone, not from the package's maths.
    [Test]
    public void TheMatterIsAimedThroughTheMirroredFrame()
    {
        var go = new GameObject("witness aim");
        try
        {
            var world = Build(go);
            Assert.IsTrue(LoadSet().Mirrored, "this test is only worth something on a mirroring importer");
            var cells = world.Cells;
            Int3 top = default, east = default;
            bool first = true;
            foreach (var c in cells)
            {
                if (first || c.y > top.y || (c.y == top.y && MBTools.Compare(c, top) < 0)) top = c;
                if (first || c.x > east.x || (c.x == east.x && MBTools.Compare(c, east) < 0)) east = c;
                first = false;
            }
            var toWorld = world.FormatToWorld;
            Hit Shoot(Vector3 from, Vector3 dir) =>
                world.RayAgainstCells(new Ray(toWorld.MultiplyPoint3x4(from), toWorld.MultiplyVector(dir).normalized));

            var down = Shoot(new Vector3(top.x + 0.5f, top.y + 20.5f, top.z + 0.5f), Vector3.down);
            Assert.IsTrue(down.Touched, "a ray from above the highest cell touches nothing");
            Assert.AreEqual(top, down.Cell, "from above: wrong cell");
            Assert.AreEqual(new Int3(0, 1, 0), down.Normal, "from above: wrong face");

            var west = Shoot(new Vector3(east.x + 20.5f, east.y + 0.5f, east.z + 0.5f), Vector3.left);
            Assert.IsTrue(west.Touched, "a ray from +X towards the easternmost cell touches nothing");
            Assert.AreEqual(east, west.Cell, "from +X: wrong cell — is the mirror undone?");
            Assert.AreEqual(new Int3(1, 0, 0), west.Normal, "from +X: wrong face");
        }
        finally { Object.DestroyImmediate(go); }
    }

    // The fake artist's work (DEV_TOOLS/faux_artiste.gd), sliced by MarchingBlocks: its texture and UVs
    // must reach every tile through glTFast. MarchingBlocks proves the same on its side; this is the far end.
    [Test]
    public void TheArtistsTextureArrivesOnEveryTile()
    {
        var manifest = AssetDatabase.LoadAssetAtPath<TextAsset>("Assets/faux.mbset/tileset.json");
        var tiles = AssetDatabase.LoadAssetAtPath<GameObject>("Assets/faux.mbset/tiles.glb");
        Assert.IsNotNull(manifest, "faux.mbset/tileset.json is missing — run preparer_essai_unity.gd");
        Assert.IsNotNull(tiles, "faux.mbset/tiles.glb is not imported as a GameObject");
        var set = MBTileset.Load(manifest, tiles, out var error);
        Assert.IsNull(error, error);
        int without = 0;
        string first = null;
        foreach (var kv in set.Tiles)
        {
            var mesh = kv.Value.Mesh;
            bool uv = mesh != null && mesh.vertexCount > 0 && mesh.uv.Length == mesh.vertexCount;
            bool texture = false;
            foreach (var m in kv.Value.Materials)
                if (m != null)
                    foreach (var p in m.GetTexturePropertyNames())
                        if (m.GetTexture(p) != null) texture = true;
            if (!uv || !texture) { without++; first = first ?? kv.Key; }
        }
        Debug.Log($"fake artist: {set.Tiles.Count} tiles, {without} without texture or UVs");
        Assert.AreEqual(52, set.Tiles.Count, "the fake artist's set is not one tile per key of the world");
        Assert.AreEqual(0, without, $"tiles without the artist's texture or UVs, e.g. {first}. "
            + $"glTFast says: {ImporterReport("Assets/faux.mbset/tiles.glb")}");
    }

    // What glTFast's importer reported ("see inspector for details"), read by reflection so that this test
    // does not depend on glTFast's API: the console only says that the import failed, never why.
    static string ImporterReport(string path)
    {
        var importer = AssetImporter.GetAtPath(path);
        if (importer == null) return "no importer";
        var field = importer.GetType().GetField("reportItems",
            System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic);
        if (!(field?.GetValue(importer) is System.Array items)) return "no report";
        var lines = new List<string>();
        foreach (var item in items)
        {
            var t = item.GetType();
            var type = t.GetField("Type")?.GetValue(item) ?? t.GetProperty("Type")?.GetValue(item);
            var code = t.GetField("Code")?.GetValue(item) ?? t.GetProperty("Code")?.GetValue(item);
            var messages = t.GetField("Messages")?.GetValue(item) ?? t.GetProperty("Messages")?.GetValue(item);
            var text = messages is string[] m ? string.Join(" ", m) : "";
            var full = t.GetMethod("ToString", System.Type.EmptyTypes)?.Invoke(item, null);
            lines.Add($"{type} {code} {text} {full}");
        }
        return lines.Count == 0 ? "nothing" : string.Join(" | ", lines);
    }

    static MarchingBlocksWorld Build(GameObject go)
    {
        var world = go.AddComponent<MarchingBlocksWorld>();
        world.tileset = AssetDatabase.LoadAssetAtPath<TextAsset>(Folder + "/tileset.json");
        world.tiles = AssetDatabase.LoadAssetAtPath<GameObject>(Folder + "/tiles.glb");
        world.cellSize = 1f;
        foreach (List<object> c in ReadJson("Assets/witness_cells.json"))
            world.SetCell(new Vector3Int((int)MBJson.AsLong(c[0]), (int)MBJson.AsLong(c[1]), (int)MBJson.AsLong(c[2])), true);
        world.Rebuild();
        return world;
    }

    // Shared with WorldImportTests.cs.
    internal static string Key(string tile, Vector3 formatPosition, int turns) =>
        $"{tile}@{Mathf.RoundToInt(formatPosition.x * 100)},{Mathf.RoundToInt(formatPosition.y * 100)},{Mathf.RoundToInt(formatPosition.z * 100)}/{((turns % 4) + 4) % 4}";

    // Which quarter turn does this rotation make, once brought back to format space?
    internal static int TurnsOf(MBTileset set, Transform t)
    {
        var r = Matrix4x4.Rotate(t.localRotation);
        var z = set.FrameInverse.MultiplyVector(r.MultiplyVector(set.Frame.MultiplyVector(Vector3.forward)));
        if (z.x > 0.5f) return 1;
        if (z.z < -0.5f) return 2;
        if (z.x < -0.5f) return 3;
        return 0;
    }
}
