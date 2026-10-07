// MarchingBlocks Paint for Unity — runs animation_conformance.json against MBAnimation.cs: the frame, the pulse, the
// phase (on the CPU, in double precision), the scroll, and the reading of extras.mb_animation.
//
// No Unity dependency: compiled by the Test Runner and by the .NET conformance-runner.

using System.Collections.Generic;
using static MarchingBlocks.Paint.Tests.ParityCheck;

namespace MarchingBlocks.Paint.Tests
{
    public static class AnimationConformanceCheck
    {
        public const string Format = "marchingblocks-animation-conformance";
        static readonly string[] Kinds = { "frame", "pulse", "phase", "scroll", "read" };

        public static List<string> Run(Dictionary<string, object> conf, out int cases)
        {
            bool pingPong = false, emptyRead = false, fullRead = false;
            var failures = ParityCheck.Run(conf, Format, Kinds, (kind, i, e) =>
            {
                switch (kind)
                {
                    case "frame":
                    {
                        if ((bool)i["ping_pong"]) pingPong = true;
                        int got = MBAnimation.FrameAt(I(i["count"]), D(i["fps"]), (bool)i["ping_pong"], D(i["t"]), D(i["phase"]));
                        return got == I(e) ? null : $"frame {got}, expected {e}";
                    }
                    case "pulse":
                        return SameNumber("pulse", MBAnimation.PulseAt(D(i["frequency"]), D(i["minimum"]), D(i["t"]), D(i["phase"])), e, 1e-5);
                    case "phase":
                    {
                        var o = Doubles(i["origin"]);
                        return SameNumber("phase", MBAnimation.PhaseOf(o[0], o[1], o[2]), e);
                    }
                    case "scroll":
                    {
                        MBAnimation.ScrollAt(D(i["u"]), D(i["v"]), D(i["t"]), (bool)i["synced"], D(i["phase"]), out var du, out var dv);
                        return SameNumbers("scroll", new[] { du, dv }, e);
                    }
                    case "read":
                    {
                        var got = MBAnimation.Read(i).ToJson();
                        if (((Dictionary<string, object>)e).Count == 0) emptyRead = true; else fullRead = true;
                        return SameJson("animation", got, e);
                    }
                }
                return "unreachable";
            }, out cases, out var kinds);

            if (conf.TryGetValue("limits", out var l))
            {
                var limits = (Dictionary<string, object>)l;
                if (MBJson.AsLong(limits["frames_max"]) != MBAnimation.FramesMax || D(limits["fps_max"]) != MBAnimation.FpsMax
                    || D(limits["scroll_max"]) != MBAnimation.ScrollMax || MBJson.AsLong(limits["pixels_max"]) != MBAnimation.PixelsMax)
                    failures.Add("the animation limits differ from the plugin's");
            }
            if (!pingPong) failures.Add("no frame case is ping-pong");
            if (!emptyRead || !fullRead) failures.Add("the read cases must hold an animation and a refusal");

            // THE .glb READER, on a hand-made binary glTF (written here, not computed by the function under test).
            string json = "{\"materials\":[{\"name\":\"lava\",\"extras\":{\"mb_animation\":{\"format\":\"marchingblocks-animation\",\"version\":1,"
                + "\"emission\":{\"pulse\":{\"frequency\":2}}}}},{\"name\":\"rock\"},{\"name\":\"lava\"}]}";
            var bytes = new List<byte>();
            var text = System.Text.Encoding.UTF8.GetBytes(json);
            int padded = (text.Length + 3) / 4 * 4;
            bytes.AddRange(System.BitConverter.GetBytes(0x46546C67u));
            bytes.AddRange(System.BitConverter.GetBytes(2u));
            bytes.AddRange(System.BitConverter.GetBytes((uint)(20 + padded)));
            bytes.AddRange(System.BitConverter.GetBytes((uint)padded));
            bytes.AddRange(System.BitConverter.GetBytes(0x4E4F534Au));
            bytes.AddRange(text);
            for (int k = text.Length; k < padded; k++) bytes.Add((byte)' ');
            var read = MBAnimation.ReadGlbJson(bytes.ToArray());
            if (read != json) failures.Add("glb: the JSON chunk is not read back");
            else
            {
                var anims = MBAnimation.MaterialAnimations(read);
                if (anims.Count != 1 || !anims.ContainsKey("lava") || anims["lava"].Channel("emission")?.Pulse?.Frequency != 2.0)
                    failures.Add("glb: the animation of material 'lava' is not found by its name");
            }
            if (MBAnimation.ReadGlbJson(new byte[] { 1, 2, 3 }) != null) failures.Add("glb: three bytes are read as a glb");
            return failures;
        }
    }
}
