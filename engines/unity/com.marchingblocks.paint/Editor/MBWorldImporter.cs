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
            /// <summary>What else the user must be told (a transition image not found, an ignored key…).</summary>
            public List<string> Warnings = new List<string>();

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
                    parts.AddRange(Warnings);
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
            // THE FLOOR of the water (water_floor): any value but 0.25, 0 or -0.25 refuses the world.
            var decoded = MBJson.Parse(text);
            if (!MBWater.ReadFloor(decoded, out double waterFloor, out string floorError))
            {
                result.Error = floorError;
                return result;
            }

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
                        // ANIMATED TEXTURES: the animated copies of the tileset's materials (one set per tileset folder).
                        else w.animatedMaterials = MBLitMaterials.BuildAnimated(tilesPath, w.tiles, result.Warnings);
                    }
                }
                var cells = new List<Vector3Int>(layer.Cells.Count);
                foreach (var c in layer.Cells) cells.Add(new Vector3Int(c.x, c.y, c.z));
                w.SetCells(cells);
                // Step 8: the layer's variant weights and choices, as the file gives them.
                w.SetVariants(layer.VariantWeights, layer.VariantChoices);
                // A visible layer is built when it becomes active (OnEnable); a hidden one when it is shown.
                go.SetActive(layer.Visible);
                result.Layers.Add(w);
            }
            // TRANSITIONS (optional): how the layers blend where they meet — a component on the root, which dresses the
            // tiles of its children.
            var transitions = MBTransitions.Read(decoded);
            if (!transitions.Ok) result.Warnings.Add("transitions ignored: " + transitions.Error);
            else if (transitions.Pairs.Count > 0)
            {
                var t = root.AddComponent<MarchingBlocksTransitions>();
                t.overlayShader = Shader.Find("MarchingBlocks/Transition Overlay");
                foreach (var p in transitions.Pairs)
                    t.pairs.Add(new MarchingBlocksTransitions.Pair
                    {
                        a = p.A, b = p.B, active = p.Active,
                        aCoversB = MarchingBlocksTransitions.Settings.From(p.ACoversB),
                        bCoversA = MarchingBlocksTransitions.Settings.From(p.BCoversA),
                    });
                foreach (var rep in transitions.Representatives)
                {
                    Texture2D image = null;
                    if (rep.Image != null)
                    {
                        string imagePath = MBWorldFile.ResolveRelative(worldJsonAssetPath, rep.Image);
                        image = AssetDatabase.LoadAssetAtPath<Texture2D>(imagePath);
                        if (image == null) result.Warnings.Add($"transition image not found: {imagePath}");
                    }
                    t.representatives.Add(new MarchingBlocksTransitions.Representative
                    {
                        image = image,
                        color = new Color((float)rep.Color[0], (float)rep.Color[1], (float)rep.Color[2], (float)rep.Color[3]),
                        scale = (float)rep.Scale, roughness = (float)rep.Roughness,
                    });
                }
                foreach (var c in transitions.Choices)
                    t.choices.Add(new MarchingBlocksTransitions.Choice { vertex = new Vector3Int(c.Key.x, c.Key.y, c.Key.z), layer = c.Value });
                t.DressAll();
            }
            string worldFolder = Path.GetDirectoryName(worldJsonAssetPath).Replace("\\", "/");
            string generated = worldFolder + "/" + MBLitMaterials.GeneratedFolder;
            MarchingBlocksWorld frameFrom = null;
            foreach (var l in result.Layers) if (l.tileset != null && l.tiles != null) { frameFrom = l; break; }

            // FOLIAGE (optional): the plants, on a child of the root — their models as the importer made them, their
            // materials copied with the wind on.
            var foliage = MBFoliage.Read(decoded);
            if (!foliage.Ok) result.Warnings.Add("foliage ignored: " + foliage.Error);
            else if (foliage.Plants.Count > 0 || foliage.Models.Count > 0)
            {
                var go = new GameObject("Foliage");
                go.transform.SetParent(root.transform, false);
                go.SetActive(false);
                var f = go.AddComponent<MarchingBlocksFoliage>();
                f.frameFrom = frameFrom;
                foreach (var m in foliage.Models)
                {
                    GameObject prefab = null;
                    var sources = new List<Material>();
                    var winds = new List<Material>();
                    if (m.Mesh == null) result.Warnings.Add($"the foliage model '{m.Name}' has no mesh (missing when the world was exported)");
                    else
                    {
                        string meshPath = MBWorldFile.ResolveRelative(worldJsonAssetPath, m.Mesh);
                        prefab = AssetDatabase.LoadAssetAtPath<GameObject>(meshPath);
                        if (prefab == null) result.Warnings.Add($"foliage model not found: {meshPath}");
                        else
                            foreach (var r in prefab.GetComponentsInChildren<Renderer>(true))
                                foreach (var mat in r.sharedMaterials)
                                    if (mat != null && !sources.Contains(mat))
                                    {
                                        sources.Add(mat);
                                        winds.Add(MBLitMaterials.WindCopy(mat, generated));
                                    }
                    }
                    f.models.Add(new MarchingBlocksFoliage.Model
                    {
                        id = m.Id, name = m.Name, prefab = prefab, groundOffset = (float)m.GroundOffset, scale = (float)m.Scale,
                        scaleRandom = (float)m.ScaleRandom, footprint = (float)m.Footprint, height = (float)m.Height,
                        wind = (float)m.Wind, sources = sources, windMaterials = winds,
                    });
                }
                foreach (var p in foliage.Plants)
                    f.plants.Add(new MarchingBlocksFoliage.Plant
                    {
                        model = p.Model, point = new Vector3((float)p.X, (float)p.Y, (float)p.Z), yaw = (float)p.Yaw,
                        scale = (float)p.Scale, planted = p.Planted,
                    });
                go.SetActive(true);
            }

            // WATER (optional): each baked sheet with the look the author suggested (an example material).
            var water = MBWater.Read(decoded);
            if (!water.Ok) result.Warnings.Add("water ignored: " + water.Error);
            else if (water.Layers.Count > 0)
            {
                var go = new GameObject("Water");
                go.transform.SetParent(root.transform, false);
                go.SetActive(false);
                var wc = go.AddComponent<MarchingBlocksWater>();
                wc.frameFrom = frameFrom;
                wc.waterFloor = MarchingBlocksWater.FloorKindOf(waterFloor);
                foreach (var l in water.Layers)
                {
                    GameObject sheet = null;
                    if (l.Mesh != null)
                    {
                        string sheetPath = MBWorldFile.ResolveRelative(worldJsonAssetPath, l.Mesh);
                        sheet = AssetDatabase.LoadAssetAtPath<GameObject>(sheetPath);
                        if (sheet == null) result.Warnings.Add($"water sheet not found: {sheetPath}");
                    }
                    var sources = new List<Vector3Int>();
                    foreach (var c in l.Sources) sources.Add(new Vector3Int(c.x, c.y, c.z));
                    wc.layers.Add(new MarchingBlocksWater.Layer
                    {
                        name = l.Name, visible = l.Visible, look = l.Look, sheet = sheet,
                        material = MBWaterLooks.Material(l.Look, generated), sources = sources,
                    });
                }
                go.SetActive(true);
            }
            AssetDatabase.SaveAssets();

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
