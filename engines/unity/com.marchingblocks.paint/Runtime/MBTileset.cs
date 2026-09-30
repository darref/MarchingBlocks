// MarchingBlocks Paint for Unity — a loaded tileset: the rule, the tile meshes, and the FRAME.
//
// tileset.json arrives as a TextAsset. tiles.glb arrives as whatever GameObject your glTF importer
// makes of it (glTFast, UnityGLTF…). Importers convert glTF's right-handed frame to Unity's left-handed
// one in different ways — in the vertices, or in the node poses. This class does not guess which:
// tiles.glb carries a marker whose vertices are exactly (0,0,0), (1,0,0), (0,2,0), (0,0,3) in format
// space. Wherever the importer put them, their lengths 1, 2, 3 tell the axes apart: that map IS the
// conversion (mirror and scale included), and the cell grid is converted by the very same map.

using System.Collections.Generic;
using UnityEngine;

namespace MarchingBlocks.Paint
{
    public sealed class MBTileset
    {
        public struct Tile
        {
            public Mesh Mesh;
            public Material[] Materials;
            /// <summary>The tile node's pose relative to the imported root (importer conversion included).</summary>
            public Matrix4x4 Pose;
        }

        public Rule Rule;
        public readonly Dictionary<string, Tile> Tiles = new Dictionary<string, Tile>();
        /// <summary>Format space → imported-root space. Linear: columns are the images of the format axes.</summary>
        public Matrix4x4 Frame = Matrix4x4.identity;
        public Matrix4x4 FrameInverse = Matrix4x4.identity;
        /// <summary>Length of one format unit in imported-root space (1 for glTFast, 100 for a cm importer…).</summary>
        public float Unit = 1f;
        public bool Mirrored;

        /// <summary>Returns null and sets error when the tileset cannot be used — and says why.</summary>
        public static MBTileset Load(TextAsset manifestAsset, GameObject tilesRoot, out string error)
        {
            error = null;
            if (manifestAsset == null) { error = "no tileset.json assigned"; return null; }
            if (tilesRoot == null) { error = "no tiles.glb assigned (import it with a glTF importer such as glTFast)"; return null; }

            Dictionary<string, object> manifest;
            try { manifest = MBJson.Parse(manifestAsset.text) as Dictionary<string, object>; }
            catch (System.FormatException e) { error = "tileset.json is not valid JSON: " + e.Message; return null; }
            if (manifest == null || !manifest.TryGetValue("format", out var f) || (string)f != Rule.Format)
            { error = "not a MarchingBlocks tileset"; return null; }
            string why = Rule.Check(manifest);
            if (why != "") { error = why; return null; }

            var set = new MBTileset { Rule = new Rule(manifest) };
            var nodes = new Dictionary<string, Transform>();
            Index(tilesRoot.transform, nodes);
            Matrix4x4 toRoot = tilesRoot.transform.worldToLocalMatrix;

            // The frame, measured on the marker.
            var marker = manifest.TryGetValue("frame_marker", out var fm) ? (Dictionary<string, object>)fm : null;
            string markerName = marker != null ? (string)marker["node"] : "mb_frame";
            if (!nodes.TryGetValue(markerName, out var markerNode) || markerNode.GetComponent<MeshFilter>() == null)
            { error = $"tiles.glb has no frame marker '{markerName}': re-export the tileset with MarchingBlocks"; return null; }
            if (!set.MeasureFrame(markerNode.GetComponent<MeshFilter>().sharedMesh, toRoot * markerNode.localToWorldMatrix, out error))
                return null;

            var missing = new List<string>();
            foreach (var key in set.Rule.Tiles)
            {
                string name = key.Value;
                if (!nodes.TryGetValue(name, out var node) || node.GetComponent<MeshFilter>() == null)
                { missing.Add(name); continue; }
                var r = node.GetComponent<MeshRenderer>();
                set.Tiles[name] = new Tile
                {
                    Mesh = node.GetComponent<MeshFilter>().sharedMesh,
                    Materials = r != null ? r.sharedMaterials : new Material[0],
                    Pose = toRoot * node.localToWorldMatrix,
                };
            }
            if (missing.Count > 0)
            {
                error = $"{missing.Count} tile(s) listed in tileset.json are not in tiles.glb: " +
                        string.Join(", ", missing.GetRange(0, Mathf.Min(5, missing.Count)));
                return null;
            }
            return set;
        }

        static void Index(Transform t, Dictionary<string, Transform> nodes)
        {
            if (!nodes.ContainsKey(t.name)) nodes[t.name] = t;
            for (int i = 0; i < t.childCount; i++) Index(t.GetChild(i), nodes);
        }

        bool MeasureFrame(Mesh mesh, Matrix4x4 pose, out string error)
        {
            error = null;
            var axes = new Vector3[3];
            var found = new bool[3];
            float unit = float.MaxValue;
            var points = new List<Vector3>();
            foreach (var v in mesh.vertices)
            {
                var p = pose.MultiplyPoint3x4(v);
                if (p.magnitude > 1e-4f) { points.Add(p); unit = Mathf.Min(unit, p.magnitude); }
            }
            if (points.Count == 0) { error = "the frame marker is empty"; return false; }
            foreach (var p in points)
            {
                int axis = Mathf.RoundToInt(p.magnitude / unit) - 1;   // lengths 1, 2, 3 → x, y, z
                if (axis < 0 || axis > 2) { error = "the frame marker is not the one MarchingBlocks writes"; return false; }
                axes[axis] = p / (axis + 1);
                found[axis] = true;
            }
            if (!found[0] || !found[1] || !found[2]) { error = "the frame marker lost a point on import"; return false; }
            Frame = Matrix4x4.identity;
            Frame.SetColumn(0, axes[0]);
            Frame.SetColumn(1, axes[1]);
            Frame.SetColumn(2, axes[2]);
            FrameInverse = Frame.inverse;
            Unit = unit;
            Mirrored = Frame.determinant < 0f;
            return true;
        }

        /// <summary>A quarter-turn rotation (format space, right-hand about +Y: +Z turns towards +X),
        /// expressed in imported-root space: F · R · F⁻¹. Always a proper rotation, even when F mirrors.</summary>
        public Matrix4x4 RotationInRoot(int quarterTurns)
        {
            int q = ((quarterTurns % 4) + 4) % 4;
            float c = q == 0 ? 1 : q == 2 ? -1 : 0;
            float s = q == 1 ? 1 : q == 3 ? -1 : 0;
            var r = Matrix4x4.identity;
            // x' = c·x + s·z ; z' = −s·x + c·z   →   q = 1 sends +Z (0,0,1) to +X (1,0,0).
            r.m00 = c; r.m02 = s;
            r.m20 = -s; r.m22 = c;
            return Frame * r * FrameInverse;
        }
    }
}
