// MarchingBlocks Paint for Unity — the tools, inside Unity's Test Runner.
//
// tools_conformance.json is computed by the MarchingBlocks tool's own editing tools and shipped with the
// Unity and Unreal plugins. Outside Unity, ../../conformance-runner runs the same check with the .NET SDK.
// The last test goes through the component: what a tool returns is applied, and Undo takes it back.

using System.Collections.Generic;
using System.IO;
using NUnit.Framework;
using UnityEditor;
using UnityEngine;

namespace MarchingBlocks.Paint.Tests
{
    public sealed class ToolsConformanceTests
    {
        static string CasesPath()
        {
            var info = UnityEditor.PackageManager.PackageInfo.FindForAssembly(typeof(MBTools).Assembly);
            return Path.Combine(info.resolvedPath, "Tests", "tools_conformance.json");
        }

        [Test]
        public void EveryToolCaseIsReproduced()
        {
            var conf = (Dictionary<string, object>)MBJson.Parse(File.ReadAllText(CasesPath()));
            var failures = ToolsConformanceCheck.Run(conf, out int cases);
            Assert.Greater(cases, 0, "no tools case was run");
            Assert.IsEmpty(failures, string.Join("\n", failures));
        }

        [Test]
        public void AnAppliedChangeIsUndoneByUndo()
        {
            var go = new GameObject("tools undo test");
            try
            {
                var world = go.AddComponent<MarchingBlocksWorld>();
                world.ClearCells();
                var room = new Change();
                foreach (var c in MBTools.Box(new Int3(0, 0, 0), new Int3(2, 2, 2), true)) room.Set.Add(c);
                Undo.IncrementCurrentGroup();
                Undo.RecordObject(world, "Fill");
                Assert.AreEqual(26, world.Apply(room), "a hollow 3x3x3 room sets 26 cells");
                Assert.AreEqual(26, world.CellCount);
                Assert.IsFalse(world.HasCell(new Vector3Int(1, 1, 1)), "the room is hollow");
                Undo.PerformUndo();
                Assert.AreEqual(0, world.CellCount, "Undo takes the whole room back");
                Assert.IsFalse(world.Cells.Contains(new Int3(0, 0, 0)), "and the index follows the undone list");
            }
            finally { Object.DestroyImmediate(go); }
        }
    }
}
