// MarchingBlocks Paint for Unity — READS A MARCHINGBLOCKS WORLD.
//
// A `<name>.mbworld/` folder made by MarchingBlocks holds `world.json` and one `.mbset` tileset folder per
// tile source, inside it. This file only READS world.json and resolves its paths: it has no Unity
// dependency, so it is tested outside the editor too (see conformance-runner). Building the scene is
// Editor/MBWorldImporter.cs.
//
// THE RULE (the README of every .mbworld says the same, and Tests/world_conformance.json holds the cases
// every plugin must pass):
//   format   "marchingblocks-world"; version: refuse anything newer than 1.
//   layers   in order; each has a name (a string), visible (true/false), tileset (a tileset.json path
//            RELATIVE to world.json, or null: a layer without tiles — its cells still travel, and it
//            must say it has no tiles, never invent some), and cells: a flat array of integers, x y z
//            per cell, in FORMAT space (cell c covers [c, c+1], +Y up). Its length is a multiple of 3,
//            and the same cell never appears twice.
//   Refuse the whole file, and say why, if any of these does not hold.

using System;
using System.Collections.Generic;

namespace MarchingBlocks.Paint
{
    public sealed class WorldLayer
    {
        public string Name;
        public bool Visible;
        /// <summary>The tileset.json path as written in world.json (relative to it), or null.</summary>
        public string Tileset;
        /// <summary>The cells, in format space, in the order world.json lists them.</summary>
        public List<Int3> Cells = new List<Int3>();
    }

    public sealed class WorldFileResult
    {
        /// <summary>"" when the file was read; otherwise why it was refused (and Layers is empty).</summary>
        public string Error = "";
        public string Name = "";
        public List<WorldLayer> Layers = new List<WorldLayer>();
        public bool Ok => Error == "";
    }

    public static class MBWorldFile
    {
        public const string Format = "marchingblocks-world";
        public const int SupportedVersion = 1;

        /// <summary>Reads the text of a world.json.</summary>
        public static WorldFileResult Read(string json)
        {
            object decoded;
            try { decoded = MBJson.Parse(json); }
            // MBJson throws FormatException on bad JSON, and index or overflow errors on truncated text or
            // huge numbers: all of them mean the same thing here.
            catch (Exception e) { return Refuse("world.json is not valid JSON: " + e.Message); }
            return Read(decoded);
        }

        /// <summary>Reads a world.json already decoded by MBJson.</summary>
        public static WorldFileResult Read(object decoded)
        {
            if (!(decoded is Dictionary<string, object> world)
                || !world.TryGetValue("format", out var f) || !(f is string fs) || fs != Format)
                return Refuse("not a MarchingBlocks world");
            world.TryGetValue("version", out var v);
            if (!IsInteger(v, out long version) || version < 1)
                return Refuse("no valid version");
            if (version > SupportedVersion)
                return Refuse($"this world is format version {version}, newer than this plugin ({SupportedVersion}): update the plugin");
            if (!world.TryGetValue("layers", out var ls) || !(ls is List<object> layers))
                return Refuse("layers is not an array");

            var result = new WorldFileResult();
            result.Name = world.TryGetValue("name", out var n) && n is string ns ? ns : "";
            foreach (var item in layers)
            {
                if (!(item is Dictionary<string, object> layer)
                    || !layer.TryGetValue("name", out var ln) || !(ln is string name)
                    || !layer.TryGetValue("visible", out var lv) || !(lv is bool visible))
                    return Refuse("a layer has no name or no visibility");
                layer.TryGetValue("tileset", out var t);
                if (t != null && !(t is string))
                    return Refuse($"layer '{name}': tileset is neither a path nor null");
                if (!layer.TryGetValue("cells", out var c) || !(c is List<object> flat) || flat.Count % 3 != 0)
                    return Refuse($"layer '{name}': cells is not a list of x y z triples");

                var out_ = new WorldLayer { Name = name, Visible = visible, Tileset = (string)t };
                var seen = new HashSet<Int3>();
                for (int i = 0; i < flat.Count; i += 3)
                {
                    if (!IsCoordinate(flat[i], out int x) || !IsCoordinate(flat[i + 1], out int y) || !IsCoordinate(flat[i + 2], out int z))
                        return Refuse($"layer '{name}': a cell coordinate is not an integer");
                    var key = new Int3(x, y, z);
                    if (!seen.Add(key))
                        return Refuse($"layer '{name}': the cell ({x}, {y}, {z}) appears twice");
                    out_.Cells.Add(key);
                }
                result.Layers.Add(out_);
            }
            return result;
        }

        /// <summary>The path of a file named RELATIVE to world.json: joined to world.json's folder, with
        /// '.' and '..' resolved and '/' separators (Unity asset paths). "Assets/w.mbworld/world.json" and
        /// "rock.mbset/tileset.json" give "Assets/w.mbworld/rock.mbset/tileset.json".</summary>
        public static string ResolveRelative(string worldJsonPath, string relative)
        {
            string world = worldJsonPath.Replace('\\', '/');
            int slash = world.LastIndexOf('/');
            string folder = slash >= 0 ? world.Substring(0, slash) : "";
            return Normalize(folder == "" ? relative : folder + "/" + relative);
        }

        /// <summary>The tiles file of a tileset: its manifest's "tiles_file" (default "tiles.glb"), next to
        /// the tileset.json.</summary>
        public static string TilesPath(string tilesetJsonPath, string manifestJson)
        {
            string file = "tiles.glb";
            try
            {
                if (MBJson.Parse(manifestJson) is Dictionary<string, object> m
                    && m.TryGetValue("tiles_file", out var tf) && tf is string s && s != "")
                    file = s;
            }
            catch (Exception) { }  // an unreadable manifest is reported by MBTileset.Load, not here
            return ResolveRelative(tilesetJsonPath, file);
        }

        static string Normalize(string path)
        {
            var parts = new List<string>();
            foreach (var p in path.Replace('\\', '/').Split('/'))
            {
                if (p == "" || p == ".") continue;
                if (p == ".." && parts.Count > 0 && parts[parts.Count - 1] != "..") parts.RemoveAt(parts.Count - 1);
                else parts.Add(p);
            }
            return string.Join("/", parts);
        }

        static WorldFileResult Refuse(string why) => new WorldFileResult { Error = why };

        // MBJson gives integers as long, and a writer may print 3 as 3.0: both are integers.
        static bool IsInteger(object v, out long value)
        {
            value = 0;
            if (v is long l) { value = l; return true; }
            if (v is double d && !double.IsNaN(d) && !double.IsInfinity(d) && Math.Floor(d) == d
                && d >= long.MinValue && d <= long.MaxValue)
            { value = (long)d; return true; }
            return false;
        }

        static bool IsCoordinate(object v, out int value)
        {
            value = 0;
            if (!IsInteger(v, out long l) || l < int.MinValue || l > int.MaxValue) return false;
            value = (int)l;
            return true;
        }
    }
}
