// MarchingBlocks Paint for Unity — THE PLACEMENT RULE, implemented from the tileset format itself.
//
// This file reads nothing but a tileset manifest (tileset.json): its table, corners, classes and
// context. It has no Unity dependency: Tests/conformance.json (the reference cases, shipped with
// every MarchingBlocks plugin) proves it places exactly what the MarchingBlocks tool places.
//
// Everything here is in FORMAT space: right-handed, +Y up, 1 unit = 1 cell (glTF). Converting to
// Unity's frame is MBTileset's job, measured on the frame marker — never assumed.
//
// The rule, in short (the manifest's rules_text says it in full):
//   1. a full cell c touches the 8 vertices c - corners[t];
//   2. at vertex v, bit t is set when cell v + corners[t] is full;
//   3. table[bits] gives [class, quarter_turns]; class -1 places nothing;
//   4. an outdoor-capable class is OUTDOOR when no empty cell among the 8 has a full cell above it,
//      from v.y + 2 up to the highest full cell of the layer; outdoor tries "<id>_outdoor" first;
//   5. each key has exactly one tile, tiles[key];
//   6. a missing key gives a null tile — show an error marker, never fill in.

using System;
using System.Collections.Generic;

namespace MarchingBlocks.Paint
{
    [Serializable]
    public struct Int3 : IEquatable<Int3>
    {
        public int x, y, z;
        public Int3(int x, int y, int z) { this.x = x; this.y = y; this.z = z; }
        public static Int3 operator +(Int3 a, Int3 b) => new Int3(a.x + b.x, a.y + b.y, a.z + b.z);
        public static Int3 operator -(Int3 a, Int3 b) => new Int3(a.x - b.x, a.y - b.y, a.z - b.z);
        public bool Equals(Int3 o) => x == o.x && y == o.y && z == o.z;
        public override bool Equals(object o) => o is Int3 i && Equals(i);
        public override int GetHashCode() => (x * 73856093) ^ (y * 19349663) ^ (z * 83492791);
        public override string ToString() => $"({x}, {y}, {z})";
    }

    public struct Placement
    {
        public Int3 Vertex;
        /// <summary>The tile name, or null when the tileset lacks the tile the rule asks for.</summary>
        public string Tile;
        /// <summary>Quarter turns about +Y, right-hand rule (+Z turns towards +X), in format space.</summary>
        public int QuarterTurns;
    }

    public sealed class Rule
    {
        public const string Format = "marchingblocks-tileset";
        public const int SupportedVersion = 1;

        public readonly Int3[] Corners;
        public readonly Int3 PieceOffset;
        /// <summary>{key: tile name} — one tile per key.</summary>
        public readonly Dictionary<string, string> Tiles;
        readonly int[] tableClass = new int[256];
        readonly int[] tableTurns = new int[256];
        readonly string[] classIds;
        readonly bool[] outdoorPossible;
        readonly int band;
        readonly string outdoorSuffix;

        /// <summary>"" when the manifest is usable, otherwise the reason. A NEWER format is refused:
        /// its rule may mean something else, and placing anyway would be a silent lie.</summary>
        public static string Check(Dictionary<string, object> manifest)
        {
            long version = manifest.TryGetValue("version", out var v) ? MBJson.AsLong(v) : 0;
            if (version > SupportedVersion)
                return $"made by a newer MarchingBlocks (format {version}, this plugin reads {SupportedVersion}): update the plugin";
            foreach (var field in new[] { "corners", "table", "classes", "context" })
                if (!manifest.ContainsKey(field))
                    return $"not a MarchingBlocks tileset: '{field}' is missing";
            if (((List<object>)manifest["table"]).Count != 256)
                return "the table must have 256 entries";
            return CheckTiles(manifest.TryGetValue("tiles", out var t) ? t as Dictionary<string, object> : null);
        }

        /// <summary>"" when every key names exactly one tile, otherwise the reason.</summary>
        public static string CheckTiles(Dictionary<string, object> tiles)
        {
            if (tiles == null) return "";
            foreach (var kv in tiles)
                if (!(kv.Value is string))
                    return $"tile '{kv.Key}' must be one tile name (one tile per key)";
            return "";
        }

        /// <param name="tiles">{key: tile name} — null to use the manifest's own "tiles".</param>
        public Rule(Dictionary<string, object> manifest, Dictionary<string, object> tiles = null)
        {
            string why = Check(manifest);
            if (why != "") throw new ArgumentException(why);

            var corners = (List<object>)manifest["corners"];
            Corners = new Int3[8];
            for (int t = 0; t < 8; t++) Corners[t] = ToInt3((List<object>)corners[t]);
            PieceOffset = manifest.TryGetValue("piece_offset", out var po) ? ToInt3((List<object>)po) : new Int3(1, 1, 1);

            var table = (List<object>)manifest["table"];
            for (int b = 0; b < 256; b++)
            {
                var e = (List<object>)table[b];
                tableClass[b] = (int)MBJson.AsLong(e[0]);
                tableTurns[b] = (int)MBJson.AsLong(e[1]);
            }
            var classes = (List<object>)manifest["classes"];
            classIds = new string[classes.Count];
            outdoorPossible = new bool[classes.Count];
            for (int i = 0; i < classes.Count; i++)
            {
                var c = (Dictionary<string, object>)classes[i];
                classIds[i] = (string)c["id"];
                outdoorPossible[i] = (bool)c["outdoor_possible"];
            }
            var context = (Dictionary<string, object>)manifest["context"];
            band = context.TryGetValue("band", out var bd) ? (int)MBJson.AsLong(bd) : 2;
            outdoorSuffix = context.TryGetValue("outdoor_suffix", out var sf) ? (string)sf : "_outdoor";

            Tiles = new Dictionary<string, string>();
            var source = tiles ?? (manifest.TryGetValue("tiles", out var tv) ? (Dictionary<string, object>)tv : new Dictionary<string, object>());
            string whyTiles = CheckTiles(source);
            if (whyTiles != "") throw new ArgumentException(whyTiles);
            foreach (var kv in source)
                Tiles[kv.Key] = (string)kv.Value;
        }

        static Int3 ToInt3(List<object> a) => new Int3((int)MBJson.AsLong(a[0]), (int)MBJson.AsLong(a[1]), (int)MBJson.AsLong(a[2]));

        /// <summary>Every placement for one layer, sorted by vertex (x, then y, then z).
        /// A layer only ever reads its own cells.</summary>
        public List<Placement> Placements(HashSet<Int3> cells)
        {
            int top = int.MinValue;
            foreach (var c in cells) top = Math.Max(top, c.y);
            var vertices = new HashSet<Int3>();
            foreach (var c in cells)
                for (int t = 0; t < 8; t++) vertices.Add(c - Corners[t]);

            var result = new List<Placement>();
            foreach (var v in vertices)
            {
                int bits = 0;
                for (int t = 0; t < 8; t++)
                    if (cells.Contains(v + Corners[t])) bits |= 1 << t;
                int cls = tableClass[bits];
                if (cls < 0) continue;
                string id = classIds[cls];
                string chosen = null;
                if (outdoorPossible[cls] && IsOutdoor(cells, v, top) && Has(id + outdoorSuffix))
                    chosen = id + outdoorSuffix;
                if (chosen == null && Has(id))
                    chosen = id;
                string tile = chosen != null ? Tiles[chosen] : null;
                result.Add(new Placement { Vertex = v, Tile = tile, QuarterTurns = tableTurns[bits] });
            }
            result.Sort((a, b) =>
                a.Vertex.x != b.Vertex.x ? a.Vertex.x.CompareTo(b.Vertex.x) :
                a.Vertex.y != b.Vertex.y ? a.Vertex.y.CompareTo(b.Vertex.y) :
                a.Vertex.z.CompareTo(b.Vertex.z));
            return result;
        }

        bool Has(string key) => Tiles.TryGetValue(key, out var t) && !string.IsNullOrEmpty(t);

        // Outdoor: every EMPTY cell among the 8 has nothing full above the vertex's two-cell band.
        bool IsOutdoor(HashSet<Int3> cells, Int3 v, int top)
        {
            for (int t = 0; t < 8; t++)
            {
                var e = v + Corners[t];
                if (cells.Contains(e)) continue;
                for (int y = v.y + band; y <= top; y++)
                    if (cells.Contains(new Int3(e.x, y, e.z))) return false;
            }
            return true;
        }
    }
}
