// MarchingBlocks Paint for Unity — the conformance cases, inside Unity's Test Runner.
//
// conformance.json is shipped with every MarchingBlocks plugin (Godot, Unity, Unreal): the SAME cases,
// computed by the MarchingBlocks tool's own placement rule. This plugin must reproduce every one.
// Outside Unity, ../../conformance-runner runs the same check with the .NET SDK.
// The frame test builds an importer that MIRRORS (as a left-handed engine must) and checks that a
// quarter turn still sends format +Z towards format +X once converted back.

using System.Collections.Generic;
using System.IO;
using NUnit.Framework;
using UnityEngine;

namespace MarchingBlocks.Paint.Tests
{
    public sealed class ConformanceTests
    {
        static string ConformancePath()
        {
            var info = UnityEditor.PackageManager.PackageInfo.FindForAssembly(typeof(Rule).Assembly);
            return Path.Combine(info.resolvedPath, "Tests", "conformance.json");
        }

        [Test]
        public void EveryCaseIsReproduced()
        {
            var conf = (Dictionary<string, object>)MBJson.Parse(File.ReadAllText(ConformancePath()));
            var tilesets = (Dictionary<string, object>)conf["tilesets"];
            foreach (Dictionary<string, object> c in (List<object>)conf["cases"])
            {
                var rule = new Rule(conf, (Dictionary<string, object>)tilesets[(string)c["tileset"]]);
                var cells = new HashSet<Int3>();
                foreach (List<object> p in (List<object>)c["cells"])
                    cells.Add(new Int3((int)MBJson.AsLong(p[0]), (int)MBJson.AsLong(p[1]), (int)MBJson.AsLong(p[2])));
                var got = rule.Placements(cells);
                var expected = (List<object>)c["expected"];
                Assert.AreEqual(expected.Count, got.Count, $"{c["name"]}: placement count");
                for (int i = 0; i < expected.Count; i++)
                {
                    var e = (List<object>)expected[i];
                    var g = got[i];
                    string where = $"{c["name"]} at {i}";
                    Assert.AreEqual(new Int3((int)MBJson.AsLong(e[0]), (int)MBJson.AsLong(e[1]), (int)MBJson.AsLong(e[2])), g.Vertex, where);
                    Assert.AreEqual(e[3] as string, g.Tile, where);
                    Assert.AreEqual((int)MBJson.AsLong(e[4]), g.QuarterTurns, where);
                }
            }
        }

        [Test]
        public void AListOfCopiesIsRefused()
        {
            var conf = (Dictionary<string, object>)MBJson.Parse(File.ReadAllText(ConformancePath()));
            conf["tiles"] = new Dictionary<string, object> { ["corner_b1h0"] = new List<object> { "corner_b1h0", "corner_b1h0_2" } };
            StringAssert.Contains("one tile per key", Rule.Check(conf));
            conf["tiles"] = new Dictionary<string, object> { ["corner_b1h0"] = "corner_b1h0" };
            Assert.AreEqual("", Rule.Check(conf));
        }

        [Test]
        public void ANewerFormatIsRefused()
        {
            var conf = (Dictionary<string, object>)MBJson.Parse(File.ReadAllText(ConformancePath()));
            conf["version"] = (long)Rule.SupportedVersion + 1;
            Assert.AreNotEqual("", Rule.Check(conf));
        }

        [Test]
        public void TheFrameIsMeasuredEvenWhenTheImporterMirrors()
        {
            var conf = (Dictionary<string, object>)MBJson.Parse(File.ReadAllText(ConformancePath()));
            conf["format"] = Rule.Format;
            conf["tiles"] = new Dictionary<string, object>();
            var manifest = new TextAsset(ToJson(conf));

            // An importer that mirrors X and scales by 100, as a left-handed, centimetre engine could.
            var root = new GameObject("tiles");
            var marker = new GameObject("mb_frame");
            marker.transform.SetParent(root.transform, false);
            var mesh = new Mesh
            {
                vertices = new[] { Vector3.zero, new Vector3(-100, 0, 0), new Vector3(0, 200, 0), new Vector3(0, 0, 300) },
                triangles = new[] { 0, 2, 1, 0, 1, 3, 0, 3, 2, 1, 2, 3 },
            };
            marker.AddComponent<MeshFilter>().sharedMesh = mesh;
            try
            {
                var set = MBTileset.Load(manifest, root, out var error);
                Assert.IsNull(error, error);
                Assert.IsTrue(set.Mirrored, "the mirror is not detected");
                Assert.AreEqual(100f, set.Unit, 1e-3f, "the importer scale is not measured");
                // Format +Z is engine (0,0,300)/3 = (0,0,100); a quarter turn must send it to format +X,
                // which this importer puts at (−100, 0, 0).
                var turned = set.RotationInRoot(1).MultiplyVector(new Vector3(0, 0, 100));
                Assert.That(Vector3.Distance(turned, new Vector3(-100, 0, 0)), Is.LessThan(1e-3f),
                    $"a quarter turn sends +Z to {turned}, not to the converted +X");
            }
            finally
            {
                Object.DestroyImmediate(root);
                Object.DestroyImmediate(mesh);
            }
        }

        // Just enough JSON writing for the test manifest.
        static string ToJson(object v)
        {
            switch (v)
            {
                case null: return "null";
                case string s: return "\"" + s.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
                case bool b: return b ? "true" : "false";
                case long l: return l.ToString(System.Globalization.CultureInfo.InvariantCulture);
                case double d: return d.ToString("R", System.Globalization.CultureInfo.InvariantCulture);
                case Dictionary<string, object> o:
                    var parts = new List<string>();
                    foreach (var kv in o) parts.Add(ToJson(kv.Key) + ":" + ToJson(kv.Value));
                    return "{" + string.Join(",", parts) + "}";
                case List<object> a:
                    var items = new List<string>();
                    foreach (var x in a) items.Add(ToJson(x));
                    return "[" + string.Join(",", items) + "]";
                default: return v.ToString();
            }
        }
    }
}
