// MarchingBlocks Paint for Unity — runs foliage_conformance.json against the foliage rule (MBFoliage.cs): the check in
// its three modes, the brush on given candidates, the pose, the wind data and the sway, the ground of cells, and the
// reader of the "foliage" key. The answers come from the MarchingBlocks tool itself.
//
// No Unity dependency: compiled by the Test Runner and by the .NET conformance-runner.

using System.Collections.Generic;
using static MarchingBlocks.Paint.Tests.ParityCheck;

namespace MarchingBlocks.Paint.Tests
{
    public static class FoliageConformanceCheck
    {
        public const string Format = "marchingblocks-foliage-conformance";
        static readonly string[] Kinds = { "check", "brush", "place", "wind_data", "sway", "ground_of_cells", "read" };

        public static List<string> Run(Dictionary<string, object> conf, out int cases)
        {
            var world = Cells(conf["world_cells"]);
            var water = Cells(conf["water_cells"]);
            var models = new Dictionary<int, FoliageModel>();
            foreach (var kv in (Dictionary<string, object>)conf["models"])
            {
                var e = (Dictionary<string, object>)kv.Value;
                models[I(e["id"])] = new FoliageModel
                {
                    Id = I(e["id"]), Name = (string)e["name"], GroundOffset = D(e["ground_offset"]), Scale = D(e["scale"]),
                    ScaleRandom = D(e["scale_random"]), Footprint = D(e["footprint"]), Height = D(e["height"]), Wind = D(e["wind"]),
                };
            }
            var fw = new FoliageWorld
            {
                Full = world.Contains,
                GroundAt = (x, z, y) => MBFoliage.GroundOfCells(world.Contains, x, z, y),
                Water = q => water.Contains(MBFoliage.WaterCell(q)),
            };
            var modes = new HashSet<string>();
            var reasons = new HashSet<string>();

            var failures = ParityCheck.Run(conf, Format, Kinds, (kind, i, e) =>
            {
                switch (kind)
                {
                    case "check":
                    {
                        var m = models[I(i["model"])];
                        var pt = Doubles(i["point"]);
                        var mode = Mode((string)i["mode"]);
                        modes.Add((string)i["mode"]);
                        var p = new Plant { Model = m.Id, X = pt[0], Y = pt[1], Z = pt[2], Yaw = D(i["yaw"]), Scale = D(i["scale"]),
                            Planted = mode != FoliageMode.Air };
                        var n = Doubles(i["normal"]);
                        string got = MBFoliage.Check(m, p, new Double3(n[0], n[1], n[2]), mode, fw,
                            new PlantIndex(models, Plants(i["plants"])), models, D(i["spacing"]), D(i["max_slope"]));
                        reasons.Add((string)e);
                        return got == (string)e ? null : $"'{got}', expected '{e}'";
                    }
                    case "brush":
                    {
                        var m = models[I(i["model"])];
                        modes.Add((string)i["mode"]);
                        var candidates = new List<BrushCandidate>();
                        foreach (var c in (List<object>)i["candidates"])
                        {
                            var d = Doubles(c);
                            candidates.Add(new BrushCandidate { X = d[0], Z = d[1], Yaw = d[2], Scale = d[3] });
                        }
                        var index = new PlantIndex(models, Plants(i["plants"]));
                        var got = MBFoliage.Brush(m, D(i["y_top"]), candidates, Mode((string)i["mode"]), fw, index, models,
                            D(i["spacing"]), D(i["max_slope"]));
                        var ex = (Dictionary<string, object>)e;
                        var plants = new List<object>();
                        foreach (var p in got.Plants) plants.Add(new List<object> { p.X, p.Y, p.Z, p.Yaw, p.Scale });
                        var refused = new Dictionary<string, object>();
                        foreach (var kv in got.Refused) refused[kv.Key] = (long)kv.Value;
                        foreach (var k in ((Dictionary<string, object>)ex["refused"]).Keys) reasons.Add(k);
                        return SameJson("plants", plants, ex["plants"]) ?? SameJson("refused", refused, ex["refused"]);
                    }
                    case "place":
                    {
                        var m = models[I(i["model"])];
                        var pt = Doubles(i["point"]);
                        var p = new Plant { Model = m.Id, X = pt[0], Y = pt[1], Z = pt[2], Yaw = D(i["yaw"]), Scale = D(i["scale"]), Planted = true };
                        var pose = MBFoliage.Place(m, p);
                        var ex = (Dictionary<string, object>)e;
                        var basis = (List<object>)ex["basis"];
                        for (int k = 0; k < 3; k++)
                        {
                            var col = pose.Column(k);
                            var why = SameNumbers($"basis column {k}", new[] { col.x, col.y, col.z }, basis[k], 1e-5);
                            if (why != null) return why;
                        }
                        return SameNumbers("origin", new[] { pose.Origin.x, pose.Origin.y, pose.Origin.z }, ex["origin"])
                            ?? SameNumber("height above ground", MBFoliage.HeightAboveGround(m, p), ex["height_above_ground"]);
                    }
                    case "wind_data":
                    {
                        var m = models[I(i["model"])];
                        var pt = Doubles(i["point"]);
                        var w = MBFoliage.WindData(m, new Plant { Model = m.Id, X = pt[0], Y = pt[1], Z = pt[2], Scale = D(i["scale"]), Planted = true });
                        return SameNumbers("wind", new[] { w.Ground, w.Height, w.Phase, w.Amplitude }, e);
                    }
                    case "sway":
                    {
                        var w = Doubles(i["wind"]);
                        var v = Doubles(i["vertex"]);
                        var n = Doubles(i["normal"]);
                        var dir = Doubles(i["direction"]);
                        if (!Near(dir[0], MBFoliage.WindDirectionX, 1e-6) || !Near(dir[1], MBFoliage.WindDirectionZ, 1e-6))
                            return "the wind direction of the case is not the plugin's";
                        var got = MBFoliage.Sway(new Double3(v[0], v[1], v[2]), new Double3(n[0], n[1], n[2]),
                            new PlantWind { Ground = w[0], Height = w[1], Phase = w[2], Amplitude = w[3] }, D(i["t"]));
                        return SameNumbers("vertex", new[] { got.x, got.y, got.z }, e, 1e-5);
                    }
                    case "ground_of_cells":
                    {
                        var g = MBFoliage.GroundOfCells(world.Contains, D(i["x"]), D(i["z"]), D(i["y_top"]));
                        if (e == null) return g == null ? null : $"ground {g.Value.Y}, expected none";
                        if (g == null) return $"no ground, expected {e}";
                        return SameNumber("ground", g.Value.Y, e);
                    }
                    case "read":
                    {
                        var got = MBFoliage.Read(i);
                        var ex = (Dictionary<string, object>)e;
                        if (ex.ContainsKey("error")) return got.Ok ? "must be REFUSED, was read" : null;
                        if (!got.Ok) return "refused: " + got.Error;
                        var ms = new List<object>();
                        foreach (var m in got.Models)
                            ms.Add(new Dictionary<string, object>
                            {
                                ["id"] = (long)m.Id, ["name"] = m.Name, ["mesh"] = m.Mesh, ["ground_offset"] = m.GroundOffset,
                                ["scale"] = m.Scale, ["scale_random"] = m.ScaleRandom, ["footprint"] = m.Footprint,
                                ["height"] = m.Height, ["wind"] = m.Wind,
                            });
                        var ps = new List<object>();
                        foreach (var p in got.Plants)
                            ps.Add(new List<object> { (long)p.Model, p.X, p.Y, p.Z, p.Yaw, p.Scale, p.Planted ? 1L : 0L });
                        return SameJson("foliage", new Dictionary<string, object> { ["models"] = ms, ["plants"] = ps }, e);
                    }
                }
                return "unreachable";
            }, out cases, out var kinds);

            // Les constantes du fichier sont celles du greffon.
            var k2 = (Dictionary<string, object>)conf["constants"];
            var dir2 = Doubles(k2["wind_direction"]);
            if (!Near(D(k2["max_slope_deg"]), MBFoliage.MaxSlopeDeg, 1e-9) || !Near(D(k2["ground_tolerance"]), MBFoliage.GroundTolerance, 1e-9)
                || I(k2["edge_samples"]) != MBFoliage.EdgeSamples || !Near(D(k2["duplicate"]), MBFoliage.Duplicate, 1e-9)
                || !Near(D(k2["water_offset"]), MBFoliage.WaterOffset, 1e-9) || I(k2["ground_search_floor"]) != MBFoliage.GroundSearchFloor
                || !Near(dir2[0], MBFoliage.WindDirectionX, 1e-9) || !Near(dir2[1], MBFoliage.WindDirectionZ, 1e-9))
                failures.Add("the constants of the file differ from the plugin's");
            // LES CAS EXERCENT CE QU'ILS NOMMENT (lu du côté ATTENDU).
            foreach (var m in new[] { "air", "free", "overflow" })
                if (!modes.Contains(m)) failures.Add($"no case in mode '{m}'");
            foreach (var r in new[] { "", "in_matter", "too_steep", "in_water", "at_edge", "under_matter", "too_close", "already_there", "no_ground" })
                if (!reasons.Contains(r)) failures.Add($"no case ends with '{r}'");
            return failures;
        }

        static List<Plant> Plants(object o)
        {
            var list = new List<Plant>();
            foreach (var p in (List<object>)o)
            {
                var d = Doubles(p);
                list.Add(new Plant { Model = (int)d[0], X = d[1], Y = d[2], Z = d[3], Yaw = d[4], Scale = d[5], Planted = d[6] != 0 });
            }
            return list;
        }

        static FoliageMode Mode(string s) =>
            s == "air" ? FoliageMode.Air : s == "free" ? FoliageMode.Free
            : s == "overflow" ? FoliageMode.Overflow : throw new System.FormatException("mode " + s);
    }
}
