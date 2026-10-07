// MarchingBlocks Paint for Unity — ANIMATED TEXTURES: the rule and the reader.
//
// A material of tiles.glb may carry extras.mb_animation (format "marchingblocks-animation", version 1): per channel
// (albedo, normal, orm, emission), a scroll, a frames track (images that travel in <set>.mbset/animation/), a pulse
// (emission only). The material itself shows frame 0: ignoring the animation still shows the tile right.
//
// THE EXTRAS ARE READ FROM tiles.glb ITSELF (ReadGlbJson), never through the glTF importer: glTFast does not expose
// material extras in a dependable way. A material is matched by its NAME (several materials of the file may carry the
// same name: they are copies of one material — the same animation).
//
// This file has no Unity dependency: Tests/animation_conformance.json (computed by the MarchingBlocks tool itself) is
// run against it outside Unity too (conformance-runner). Its rules_text says every rule in full.

using System;
using System.Collections.Generic;
using System.Text;

namespace MarchingBlocks.Paint
{
    public sealed class ScrollTrack
    {
        /// <summary>Image repeats per second along u and v, in [-10, 10].</summary>
        public double U, V = -0.25;
        public bool Synced = true;
    }

    public sealed class FramesTrack
    {
        /// <summary>Paths RELATIVE to the .mbset folder, in order (1 to 256).</summary>
        public List<string> Images = new List<string>();
        public double Fps = 12.0;
        public bool PingPong;
        public bool Synced;
    }

    public sealed class PulseTrack
    {
        public double Frequency = 0.5, Minimum = 0.2;
        public bool Synced;
    }

    public sealed class AnimationChannel
    {
        public ScrollTrack Scroll;
        public FramesTrack Frames;
        /// <summary>The emission channel only.</summary>
        public PulseTrack Pulse;
        public bool IsEmpty => Scroll == null && Frames == null && Pulse == null;
    }

    /// <summary>A material's animation, normalized: only known channels and tracks, every value typed and clamped.</summary>
    public sealed class MaterialAnimation
    {
        public static readonly string[] ChannelNames = { "albedo", "normal", "orm", "emission" };
        /// <summary>By channel name; a channel without a track is absent.</summary>
        public readonly Dictionary<string, AnimationChannel> Channels = new Dictionary<string, AnimationChannel>();
        public bool IsEmpty => Channels.Count == 0;

        public AnimationChannel Channel(string name) => Channels.TryGetValue(name, out var c) ? c : null;

        /// <summary>The normalized animation in the format that travels ({} when there is none) — what the
        /// conformance cases compare.</summary>
        public Dictionary<string, object> ToJson()
        {
            var o = new Dictionary<string, object>();
            if (IsEmpty) return o;
            o["format"] = MBAnimation.Format;
            o["version"] = (long)MBAnimation.SupportedVersion;
            foreach (var kv in Channels)
            {
                var tracks = new Dictionary<string, object>();
                var c = kv.Value;
                if (c.Scroll != null)
                    tracks["scroll"] = new Dictionary<string, object> { ["u"] = c.Scroll.U, ["v"] = c.Scroll.V, ["synced"] = c.Scroll.Synced };
                if (c.Frames != null)
                    tracks["frames"] = new Dictionary<string, object>
                    {
                        ["images"] = new List<object>(c.Frames.Images), ["fps"] = c.Frames.Fps,
                        ["ping_pong"] = c.Frames.PingPong, ["synced"] = c.Frames.Synced,
                    };
                if (c.Pulse != null)
                    tracks["pulse"] = new Dictionary<string, object>
                    { ["frequency"] = c.Pulse.Frequency, ["minimum"] = c.Pulse.Minimum, ["synced"] = c.Pulse.Synced };
                o[kv.Key] = tracks;
            }
            return o;
        }
    }

    public static class MBAnimation
    {
        public const string Format = "marchingblocks-animation";
        public const int SupportedVersion = 1;
        public const int FramesMax = 256;
        public const double FpsMax = 60.0;
        public const double ScrollMax = 10.0;
        public const long PixelsMax = 1L << 26;

        // ---- reading ----

        /// <summary>Reads extras.mb_animation (decoded by MBJson). Not an animation, or a newer version: an EMPTY
        /// animation (show the still material). A value of the wrong type takes its default, a number out of range is
        /// clamped, an unknown channel or track is ignored, a frames track without a frame and a pulse outside the
        /// emission do not exist.</summary>
        public static MaterialAnimation Read(object mbAnimation)
        {
            var a = new MaterialAnimation();
            if (!(mbAnimation is Dictionary<string, object> e) || !e.TryGetValue("format", out var f) || f as string != Format)
                return a;
            if (!e.TryGetValue("version", out var v) || !IsInteger(v, out long version) || version < 1 || version > SupportedVersion)
                return a;
            foreach (var name in MaterialAnimation.ChannelNames)
            {
                if (!e.TryGetValue(name, out var co) || !(co is Dictionary<string, object> c)) continue;
                var ch = new AnimationChannel();
                if (c.TryGetValue("scroll", out var so) && so is Dictionary<string, object> s)
                    ch.Scroll = new ScrollTrack
                    {
                        U = Clamp(Number(s, "u", 0.0), -ScrollMax, ScrollMax),
                        V = Clamp(Number(s, "v", -0.25), -ScrollMax, ScrollMax),
                        Synced = Bool(s, "synced", true),
                    };
                if (c.TryGetValue("frames", out var fo) && fo is Dictionary<string, object> fr)
                {
                    var t = new FramesTrack
                    {
                        Fps = Clamp(Number(fr, "fps", 12.0), 0.1, FpsMax),
                        PingPong = Bool(fr, "ping_pong", false),
                        Synced = Bool(fr, "synced", false),
                    };
                    if (fr.TryGetValue("images", out var io) && io is List<object> images)
                        foreach (var p in images)
                            if (p is string ps && ps != "" && t.Images.Count < FramesMax) t.Images.Add(ps);
                    if (t.Images.Count > 0) ch.Frames = t;
                }
                if (name == "emission" && c.TryGetValue("pulse", out var po) && po is Dictionary<string, object> pu)
                    ch.Pulse = new PulseTrack
                    {
                        Frequency = Clamp(Number(pu, "frequency", 0.5), 0.0, 20.0),
                        Minimum = Clamp(Number(pu, "minimum", 0.2), 0.0, 1.0),
                        Synced = Bool(pu, "synced", false),
                    };
                if (!ch.IsEmpty) a.Channels[name] = ch;
            }
            return a;
        }

        /// <summary>The JSON chunk of a binary glTF (.glb): a 12-byte header (magic "glTF", version 2, length), then the
        /// first chunk — its length, its type "JSON", the text. Null when the bytes are not a .glb.</summary>
        public static string ReadGlbJson(byte[] glb)
        {
            if (glb == null || glb.Length < 20) return null;
            if (BitConverter.ToUInt32(glb, 0) != 0x46546C67u) return null;          // "glTF"
            uint length = BitConverter.ToUInt32(glb, 12);
            if (BitConverter.ToUInt32(glb, 16) != 0x4E4F534Au) return null;         // "JSON"
            if (20L + length > glb.Length) return null;
            return Encoding.UTF8.GetString(glb, 20, (int)length).TrimEnd(' ', '\0');
        }

        /// <summary>The animation of every material of a glTF JSON, by material NAME (materials without an animation
        /// are absent). Two materials of one name are copies of one material: the first animated one is kept.</summary>
        public static Dictionary<string, MaterialAnimation> MaterialAnimations(string gltfJson)
        {
            var result = new Dictionary<string, MaterialAnimation>();
            object decoded;
            try { decoded = MBJson.Parse(gltfJson); }
            catch (Exception) { return result; }
            if (!(decoded is Dictionary<string, object> root) || !root.TryGetValue("materials", out var mo) || !(mo is List<object> materials))
                return result;
            foreach (var m in materials)
            {
                if (!(m is Dictionary<string, object> mat) || !mat.TryGetValue("name", out var n) || !(n is string name)) continue;
                if (result.ContainsKey(name)) continue;
                if (!mat.TryGetValue("extras", out var x) || !(x is Dictionary<string, object> extras)
                    || !extras.TryGetValue("mb_animation", out var anim)) continue;
                var a = Read(anim);
                if (!a.IsEmpty) result[name] = a;
            }
            return result;
        }

        // ---- the rule (the shader follows it line by line) ----

        /// <summary>The frame shown at time t, of n frames: k = floor(t · fps + phase · n); ping-pong (n > 1): p = 2n − 2,
        /// k mod p, then k or p − k; else k mod n. Mod is always ≥ 0. Phase 0 for a synced track.</summary>
        public static int FrameAt(int count, double fps, bool pingPong, double t, double phase)
        {
            if (count <= 0) return 0;
            long k = (long)Math.Floor(t * fps + phase * count);
            if (pingPong && count > 1)
            {
                long p = 2L * count - 2;
                k = Mod(k, p);
                return (int)(k < count ? k : p - k);
            }
            return (int)Mod(k, count);
        }

        /// <summary>The emission factor at time t: 1 when the frequency is 0 or less; else minimum + (1 − minimum) ·
        /// (0.5 + 0.5 cos(2π (t · frequency + phase))).</summary>
        public static double PulseAt(double frequency, double minimum, double t, double phase)
        {
            if (frequency <= 0.0) return 1.0;
            return minimum + (1.0 - minimum) * (0.5 + 0.5 * Math.Cos(2.0 * Math.PI * (t * frequency + phase)));
        }

        /// <summary>The UV offset at time t: (u, v) · (t + (synced ? 0 : 7 · phase)), added to the UVs.</summary>
        public static void ScrollAt(double u, double v, double t, bool synced, double phase, out double du, out double dv)
        {
            double m = t + (synced ? 0.0 : 7.0 * phase);
            du = u * m;
            dv = v * m;
        }

        /// <summary>THE PHASE of a tile: a hash of its ORIGIN in FORMAT space (the vertex v + piece_offset — never the
        /// engine position, which a frame mirrors and scales). In double precision, on the CPU, once per tile.</summary>
        public static double PhaseOf(double ox, double oy, double oz)
        {
            double px = Fract(Math.Floor(ox + 0.5) * 0.3183099 + 0.71) * 17.0;
            double py = Fract(Math.Floor(oy + 0.5) * 0.3183099 + 0.113) * 17.0;
            double pz = Fract(Math.Floor(oz + 0.5) * 0.3183099 + 0.419) * 17.0;
            return Fract(px * py * pz * (px + py + pz));
        }

        static double Fract(double x) => x - Math.Floor(x);
        static long Mod(long a, long n) => ((a % n) + n) % n;
        static double Clamp(double x, double lo, double hi) => x < lo ? lo : x > hi ? hi : x;

        static double Number(Dictionary<string, object> d, string key, double fallback) =>
            d.TryGetValue(key, out var v) && (v is long || v is double) ? MBJson.AsDouble(v) : fallback;

        static bool Bool(Dictionary<string, object> d, string key, bool fallback) =>
            d.TryGetValue(key, out var v) && v is bool b ? b : fallback;

        static bool IsInteger(object v, out long value)
        {
            value = 0;
            if (v is long l) { value = l; return true; }
            if (v is double d && Math.Floor(d) == d && !double.IsInfinity(d)) { value = (long)d; return true; }
            return false;
        }
    }
}
