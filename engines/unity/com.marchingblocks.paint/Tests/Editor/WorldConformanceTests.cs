// MarchingBlocks Paint for Unity — the world reader, inside Unity's Test Runner.
//
// world_conformance.json is computed by the MarchingBlocks tool's own world reader and shipped with every
// plugin. Outside Unity, ../../conformance-runner runs the same check with the .NET SDK.

using System.Collections.Generic;
using System.IO;
using NUnit.Framework;

namespace MarchingBlocks.Paint.Tests
{
    public sealed class WorldConformanceTests
    {
        static string CasesPath()
        {
            var info = UnityEditor.PackageManager.PackageInfo.FindForAssembly(typeof(MBWorldFile).Assembly);
            return Path.Combine(info.resolvedPath, "Tests", "world_conformance.json");
        }

        [Test]
        public void EveryWorldCaseIsReproduced()
        {
            var conf = (Dictionary<string, object>)MBJson.Parse(File.ReadAllText(CasesPath()));
            var failures = WorldConformanceCheck.Run(conf, out int cases);
            Assert.Greater(cases, 0, "no world case was run");
            Assert.IsEmpty(failures, string.Join("\n", failures));
        }
    }
}
