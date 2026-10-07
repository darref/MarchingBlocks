// MarchingBlocks Paint for Unity — the six parity files (engines/PARITE.md), inside Unity's Test Runner: editing,
// animation, transitions, foliage, water, water mesh. Computed by the MarchingBlocks tool itself and shipped with every plugin.
// Outside Unity, ../../conformance-runner runs the same checks with the .NET SDK.

using System.Collections.Generic;
using System.IO;
using NUnit.Framework;

namespace MarchingBlocks.Paint.Tests
{
    public sealed class ParityConformanceTests
    {
        delegate List<string> Check(Dictionary<string, object> conf, out int cases);

        static void Run(string file, Check check)
        {
            var info = UnityEditor.PackageManager.PackageInfo.FindForAssembly(typeof(MBWorldFile).Assembly);
            var conf = (Dictionary<string, object>)MBJson.Parse(File.ReadAllText(Path.Combine(info.resolvedPath, "Tests", file)));
            var failures = check(conf, out int cases);
            Assert.Greater(cases, 0, "no case was run");
            Assert.IsEmpty(failures, string.Join("\n", failures));
        }

        [Test] public void EveryEditingCaseIsReproduced() => Run("editing_conformance.json", EditingConformanceCheck.Run);
        [Test] public void EveryAnimationCaseIsReproduced() => Run("animation_conformance.json", AnimationConformanceCheck.Run);
        [Test] public void EveryTransitionsCaseIsReproduced() => Run("transitions_conformance.json", TransitionsConformanceCheck.Run);
        [Test] public void EveryFoliageCaseIsReproduced() => Run("foliage_conformance.json", FoliageConformanceCheck.Run);
        [Test] public void EveryWaterCaseIsReproduced() => Run("water_conformance.json", WaterConformanceCheck.Run);
        [Test] public void EveryWaterMeshCaseIsReproduced() => Run("water_mesh_conformance.json", WaterMeshConformanceCheck.Run);

        [Test]
        public void TheWaterSheetIsRebuiltAfterTheGestureOnly()
        {
            var failures = WaterFollowCheck.Run(out int checks);
            Assert.Greater(checks, 0);
            Assert.IsEmpty(failures, string.Join("\n", failures));
        }

        // The reprise of the water (a previous world, the changed cells) gives what the whole computation gives.
        [Test]
        public void TheWaterReprisePutsBackWhatTheWholeComputationGives()
        {
            var info = UnityEditor.PackageManager.PackageInfo.FindForAssembly(typeof(MBWorldFile).Assembly);
            var conf = (Dictionary<string, object>)MBJson.Parse(File.ReadAllText(Path.Combine(info.resolvedPath, "Tests", "water_mesh_conformance.json")));
            var failures = WaterIncrementalCheck.Run(conf, 60, 7, out int checks, out string stats);
            UnityEngine.Debug.Log($"MB WATER REPRISE {checks} gestures: {stats}");
            Assert.Greater(checks, 0);
            Assert.IsEmpty(failures, string.Join("\n", failures));
        }
    }
}
