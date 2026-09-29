// MarchingBlocks Paint for Unity — IMPORTS A PAINTED MARCHINGBLOCKS WORLD.
//
// Copy the whole `<name>.mbworld/` folder made by MarchingBlocks into your Assets (a glTF importer such as
// glTFast must import the tiles.glb of each .mbset inside it), then Tools > MarchingBlocks > Import World…
// and pick its world.json. You get one GameObject named after the world, with one child per layer, in
// order: each has a MarchingBlocksWorld component with the layer's tileset, tiles and cells, and is active
// only if the layer was visible. The whole import is ONE undo step.
//
// A layer without tiles (its tileset is null in world.json) still arrives with its cells, and the import
// SAYS so: nothing is invented to fill it.

using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

namespace MarchingBlocks.Paint.EditorTools
{
    public static class MBWorldImporter
    {
        public sealed class Result
        {
            /// <summary>"" when the world was imported; otherwise why it was not (and Root is null).</summary>
            public string Error = "";
            public GameObject Root;
            /// <summary>The layers, in world.json's order.</summary>
            public List<MarchingBlocksWorld> Layers = new List<MarchingBlocksWorld>();
            /// <summary>Layers whose tileset is null in world.json: they carry cells and no tiles.</summary>
            public List<string> WithoutTiles = new List<string>();
            /// <summary>Layers whose tileset.json or tiles file was not found (or not imported) in Assets.</summary>
            public List<string> Missing = new List<string>();

            /// <summary>What the user must be told, or "" when every layer has its tiles.</summary>
            public string Warning
            {
                get
                {
                    var parts = new List<string>();
                    if (WithoutTiles.Count > 0)
                        parts.Add("layers without tiles (their cells are imported, no tile is placed): " + string.Join(", ", WithoutTiles));
                    if (Missing.Count > 0)
                        parts.Add("tiles not found: " + string.Join("; ", Missing)
                            + ". Copy the whole .mbworld folder into Assets, with a glTF importer (glTFast) installed");
                    return string.Join(". ", parts);
                }
            }
        }

        [MenuItem("Tools/MarchingBlocks/Import World...")]
        static void ImportFromMenu()
        {
            string picked = EditorUtility.OpenFilePanel("Import a MarchingBlocks world (world.json)", Application.dataPath, "json");
            if (string.IsNullOrEmpty(picked)) return;
            string assetPath = ToAssetPath(picked);
            if (assetPath == null)
            {
                EditorUtility.DisplayDialog("MarchingBlocks", "Pick a world.json INSIDE this project's Assets folder: "
                    + "copy the whole .mbworld folder into Assets first, so that its tiles are imported.", "OK");
                return;
            }
            var r = Import(assetPath);
            if (r.Error != "")
            {
                EditorUtility.DisplayDialog("MarchingBlocks", "This world cannot be imported: " + r.Error, "OK");
                return;
            }
            Selection.activeGameObject = r.Root;
            if (r.Warning != "") Debug.LogWarning($"MarchingBlocks world '{r.Root.name}': {r.Warning}", r.Root);
            else Debug.Log($"MarchingBlocks world '{r.Root.name}': {r.Layers.Count} layer(s) imported", r.Root);
        }

        /// <summary>An absolute path inside this project's Assets folder, as an asset path ("Assets/…"); null
        /// when it is outside.</summary>
        public static string ToAssetPath(string absolute)
        {
            string full = Path.GetFullPath(absolute).Replace('\\', '/');
            string assets = Path.GetFullPath(Application.dataPath).Replace('\\', '/').TrimEnd('/');
            if (full.Length <= assets.Length || !full.StartsWith(assets + "/", System.StringComparison.OrdinalIgnoreCase))
                return null;
            return "Assets" + full.Substring(assets.Length);
        }

        /// <summary>Imports the world.json at this asset path ("Assets/…/world.json") into the open scene.</summary>
        public static Result Import(string worldJsonAssetPath, Transform parent = null)
        {
            var result = new Result();
            string text;
            try { text = File.ReadAllText(worldJsonAssetPath); }
            catch (System.Exception e) { result.Error = "world.json cannot be read: " + e.Message; return result; }
            var world = MBWorldFile.Read(text);
            if (!world.Ok) { result.Error = world.Error; return result; }

            string name = world.Name != "" ? world.Name
                : Path.GetFileNameWithoutExtension(Path.GetDirectoryName(worldJsonAssetPath) ?? "world");
            var root = new GameObject(name);
            if (parent != null) root.transform.SetParent(parent, false);
            foreach (var layer in world.Layers)
            {
                var go = new GameObject(layer.Name == "" ? "Layer" : layer.Name);
                go.transform.SetParent(root.transform, false);
                // Inactive while it is filled: an active component would rebuild on AddComponent, for nothing.
                go.SetActive(false);
                var w = go.AddComponent<MarchingBlocksWorld>();
                if (layer.Tileset == null) result.WithoutTiles.Add(layer.Name);
                else
                {
                    string tilesetPath = MBWorldFile.ResolveRelative(worldJsonAssetPath, layer.Tileset);
                    w.tileset = AssetDatabase.LoadAssetAtPath<TextAsset>(tilesetPath);
                    if (w.tileset == null) result.Missing.Add($"{layer.Name} ({tilesetPath})");
                    else
                    {
                        string tilesPath = MBWorldFile.TilesPath(tilesetPath, w.tileset.text);
                        w.tiles = AssetDatabase.LoadAssetAtPath<GameObject>(tilesPath);
                        if (w.tiles == null) result.Missing.Add($"{layer.Name} ({tilesPath})");
                    }
                }
                var cells = new List<Vector3Int>(layer.Cells.Count);
                foreach (var c in layer.Cells) cells.Add(new Vector3Int(c.x, c.y, c.z));
                w.SetCells(cells);
                // A visible layer is built when it becomes active (OnEnable); a hidden one when it is shown.
                go.SetActive(layer.Visible);
                result.Layers.Add(w);
            }
            // ONE undo step: registering the root takes its whole hierarchy with it.
            Undo.IncrementCurrentGroup();
            int group = Undo.GetCurrentGroup();
            Undo.RegisterCreatedObjectUndo(root, "Import MarchingBlocks world");
            Undo.CollapseUndoOperations(group);
            result.Root = root;
            return result;
        }
    }
}
