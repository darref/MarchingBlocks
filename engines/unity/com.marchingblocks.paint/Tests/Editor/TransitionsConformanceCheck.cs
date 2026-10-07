// MarchingBlocks Paint for Unity — runs transitions_conformance.json against MBTransitions.cs: the blend at a point, the
// settings of one direction, the table of active directions, the cell texture, and the reading of world.json.
//
// No Unity dependency: compiled by the Test Runner and by the .NET conformance-runner.

using System.Collections.Generic;
using static MarchingBlocks.Paint.Tests.ParityCheck;

namespace MarchingBlocks.Paint.Tests
{
    public static class TransitionsConformanceCheck
    {
        public const string Format = "marchingblocks-transitions-conformance";
        static readonly string[] Kinds = { "blend", "settings", "table", "cell_texture", "read" };

        public static List<string> Run(Dictionary<string, object> conf, out int cases)
        {
            int drawn = 0, nothing = 0, voted = 0, accepted = 0, refused = 0;
            var failures = ParityCheck.Run(conf, Format, Kinds, (kind, i, e) =>
            {
                switch (kind)
                {
                    case "blend":
                    {
                        var ranks = Ints(i["ranks"]);
                        var choices = Ints(i["choices"]);
                        var f = Doubles(i["f"]);
                        var table = (Dictionary<string, object>)i["table"];
                        var h = (Dictionary<string, object>)i["h"];
                        var got = MBTransitions.Blend(ranks, f[0], f[1], f[2], choices,
                            (c, d) => table.TryGetValue($"{c}|{d}", out var s) ? TransitionSettings.From(s) : (TransitionSettings?)null,
                            l => h.TryGetValue(l.ToString(), out var v) ? D(v) : 0.5, D(i["n"]));
                        var ex = (Dictionary<string, object>)e;
                        if (ex.Count == 0)
                        {
                            nothing++;
                            return got.Drawn ? $"nothing expected, got owner {got.Owner} other {got.Other} alpha {F(got.Alpha)}" : null;
                        }
                        drawn++;
                        if (D(ex["vote"]) > 0 && D(ex["vote"]) < 1) voted++;
                        if (!got.Drawn) return "nothing drawn";
                        if (got.Owner != I(ex["owner"]) || got.Other != I(ex["other"]))
                            return $"owner {got.Owner} other {got.Other}, expected {ex["owner"]} {ex["other"]}";
                        return SameNumber("s", got.S, ex["s"]) ?? SameNumber("vote", got.Vote, ex["vote"])
                            ?? SameNumber("alpha", got.Alpha, ex["alpha"]);
                    }
                    case "settings":
                        return SameJson("settings", TransitionSettings.From(i).ToJson(), e);
                    case "table":
                    {
                        var pairs = new List<TransitionPair>();
                        foreach (Dictionary<string, object> p in (List<object>)i["pairs"])
                            pairs.Add(new TransitionPair
                            {
                                A = I(p["a"]), B = I(p["b"]), Active = (bool)p["active"],
                                ACoversB = TransitionSettings.From(p["a_covers_b"]), BCoversA = TransitionSettings.From(p["b_covers_a"]),
                            });
                        var got = new Dictionary<string, object>();
                        foreach (var kv in MBTransitions.Table(pairs)) got[$"{kv.Key.Item1}|{kv.Key.Item2}"] = kv.Value.ToJson();
                        return SameJson("table", got, e);
                    }
                    case "cell_texture":
                    {
                        var cells = new List<KeyValuePair<Int3, int>>();
                        foreach (List<object> c in (List<object>)i["cells"]) cells.Add(new KeyValuePair<Int3, int>(Vec(c), I(c[3])));
                        var choices = new List<KeyValuePair<Int3, int>>();
                        foreach (List<object> c in (List<object>)i["choices"]) choices.Add(new KeyValuePair<Int3, int>(Vec(c), I(c[3])));
                        var bytes = MBTransitions.CellTexture(cells, choices, out var origin, out var size);
                        var ex = (Dictionary<string, object>)e;
                        if (!origin.Equals(Vec(ex["origin"])) || !size.Equals(Vec(ex["size"])))
                            return $"origin {origin} size {size}, expected {Vec(ex["origin"])} {Vec(ex["size"])}";
                        // Only the non-zero bytes are listed, in the texture's own order.
                        var got = new List<object>();
                        for (int z = 0; z < size.z; z++)
                            for (int y = 0; y < size.y; y++)
                                for (int x = 0; x < size.x; x++)
                                {
                                    byte b = bytes[((long)z * size.y + y) * size.x + x];
                                    if (b != 0) got.Add(new List<object> { (long)x, (long)y, (long)z, (long)b });
                                }
                        return SameJson("bytes", got, ex["bytes"]);
                    }
                    case "read":
                    {
                        var got = MBTransitions.Read(i);
                        var ex = (Dictionary<string, object>)e;
                        if (ex.ContainsKey("error"))
                        {
                            refused++;
                            return got.Ok ? "must be REFUSED, was read" : null;
                        }
                        accepted++;
                        if (!got.Ok) return "refused: " + got.Error;
                        return SameJson("transitions", ToJson(got), e);
                    }
                }
                return "unreachable";
            }, out cases, out var kinds);

            if (conf.TryGetValue("limits", out var l))
            {
                var limits = (Dictionary<string, object>)l;
                if (I(limits["layers_max"]) != MBTransitions.LayersMax || I(limits["margin"]) != MBTransitions.Margin)
                    failures.Add("the transitions limits differ from the plugin's");
            }
            if (conf.TryGetValue("settings", out var so))
            {
                var defaults = ((Dictionary<string, object>)so)["defaults"];
                var why = SameJson("defaults", TransitionSettings.Default.ToJson(), defaults);
                if (why != null) failures.Add(why);
            }
            // THE CASES EXERCISE WHAT THEY NAME.
            if (drawn == 0 || nothing == 0 || voted == 0) failures.Add("the blend cases must draw, draw nothing, and split a vote");
            if (accepted < 2 || refused < 10) failures.Add($"the read cases accept {accepted} and refuse {refused}: 2 and 10 are needed");
            return failures;
        }

        static int[] Ints(object o)
        {
            var l = (List<object>)o;
            var a = new int[l.Count];
            for (int k = 0; k < l.Count; k++) a[k] = I(l[k]);
            return a;
        }

        static Dictionary<string, object> ToJson(TransitionsResult r)
        {
            var pairs = new List<object>();
            foreach (var p in r.Pairs)
                pairs.Add(new Dictionary<string, object>
                {
                    ["a"] = (long)p.A, ["b"] = (long)p.B, ["active"] = p.Active,
                    ["a_covers_b"] = p.ACoversB.ToJson(), ["b_covers_a"] = p.BCoversA.ToJson(),
                });
            var reps = new List<object>();
            foreach (var rep in r.Representatives)
                reps.Add(new Dictionary<string, object>
                {
                    ["image"] = rep.Image, ["color"] = new List<object> { rep.Color[0], rep.Color[1], rep.Color[2], rep.Color[3] },
                    ["scale"] = rep.Scale, ["roughness"] = rep.Roughness,
                });
            var choices = new List<object>();
            foreach (var kv in r.Choices)
                choices.Add(new List<object> { (long)kv.Key.x, (long)kv.Key.y, (long)kv.Key.z, (long)kv.Value });
            return new Dictionary<string, object> { ["pairs"] = pairs, ["representatives"] = reps, ["choices"] = choices };
        }
    }
}
