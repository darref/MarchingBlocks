// MarchingBlocks Paint for Unity — the aim and the navigation switch, inside Unity's Test Runner.
// Outside Unity, ../../conformance-runner runs the same AimCheck with the .NET SDK.

using NUnit.Framework;

namespace MarchingBlocks.Paint.Tests
{
    public sealed class AimTests
    {
        [Test]
        public void TabAlternatesTwoAimsAndSpaceTogglesNavigation()
        {
            var failures = AimCheck.Run(out int checks);
            Assert.Greater(checks, 0, "no aim check was run");
            Assert.IsEmpty(failures, string.Join("\n", failures));
        }
    }
}
