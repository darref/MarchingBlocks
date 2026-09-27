// Runs every case of conformance.json through the Unity plugin's Rule, and exits 1 on the first
// divergence of each case. LangVersion 9: the same language level Unity compiles the package with.
using System;
using System.Collections.Generic;
using System.IO;
using MarchingBlocks.Paint;

static class Program
{
    static int Main(string[] args)
    {
        string path = args.Length > 0 ? args[0] : "../com.marchingblocks.paint/Tests/conformance.json";
        var conf = (Dictionary<string, object>)MBJson.Parse(File.ReadAllText(path));
        var tilesets = (Dictionary<string, object>)conf["tilesets"];
        int cases = 0, failed = 0, placements = 0;
        foreach (Dictionary<string, object> c in (List<object>)conf["cases"])
        {
            cases++;
            var rule = new Rule(conf, (Dictionary<string, object>)tilesets[(string)c["tileset"]]);
            var cells = new HashSet<Int3>();
            foreach (List<object> p in (List<object>)c["cells"])
                cells.Add(new Int3((int)MBJson.AsLong(p[0]), (int)MBJson.AsLong(p[1]), (int)MBJson.AsLong(p[2])));
            var got = rule.Placements(cells);
            var expected = (List<object>)c["expected"];
            placements += expected.Count;
            string first = null;
            for (int i = 0; i < Math.Max(got.Count, expected.Count) && first == null; i++)
            {
                string e = i < expected.Count ? Show((List<object>)expected[i]) : "nothing";
                string g = i < got.Count ? Show(got[i]) : "nothing";
                if (e != g) first = $"at {i}: expected {e}, got {g}";
            }
            if (first != null)
            {
                failed++;
                Console.WriteLine($"  FAIL {c["name"]} — {first}");
            }
        }
        // A newer format must be refused.
        conf["version"] = (long)Rule.SupportedVersion + 1;
        bool refused = Rule.Check(conf) != "";
        if (!refused) { failed++; Console.WriteLine("  FAIL a newer format is accepted"); }
        Console.WriteLine($"{cases} cases, {placements} placements, {failed} failure(s)");
        Console.WriteLine(failed == 0 ? "VERDICT: OK" : "VERDICT: FAILED");
        return failed == 0 ? 0 : 1;
    }

    static string Show(List<object> e) =>
        $"[{MBJson.AsLong(e[0])},{MBJson.AsLong(e[1])},{MBJson.AsLong(e[2])},{(e[3] == null ? "null" : (string)e[3])},{MBJson.AsLong(e[4])}]";

    static string Show(Placement p) =>
        $"[{p.Vertex.x},{p.Vertex.y},{p.Vertex.z},{p.Tile ?? "null"},{p.QuarterTurns}]";
}
