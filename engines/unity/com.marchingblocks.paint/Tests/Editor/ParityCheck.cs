// MarchingBlocks Paint for Unity — what the five parity checks share (editing, animation, transitions, foliage,
// water): reading a conformance file, comparing as the files say (integers exact; reals to 1e-6, 1e-5 after a sine
// or a cosine; sets of cells sorted x, then y, then z), and refusing a kind it does not know — a bench that skipped
// an unknown kind in silence would guard nothing.
//
// No Unity dependency: compiled by the Test Runner and by the .NET conformance-runner.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace MarchingBlocks.Paint.Tests
{
    public static class ParityCheck
    {
        public delegate string CaseRunner(string kind, Dictionary<string, object> input, object expected);

        /// <summary>Runs every case of a conformance file through <paramref name="run"/> (null = passed, else why).
        /// An unknown kind FAILS. <paramref name="kinds"/> counts the cases per kind.</summary>
        public static List<string> Run(Dictionary<string, object> conf, string format, ICollection<string> knownKinds,
            CaseRunner run, out int cases, out Dictionary<string, int> kinds)
        {
            var failures = new List<string>();
            cases = 0;
            kinds = new Dictionary<string, int>();
            if (!(conf.TryGetValue("format", out var f) && f as string == format)
                || !conf.TryGetValue("version", out var v) || MBJson.AsLong(v) > 1)
            {
                failures.Add($"not a {format} file this plugin reads");
                return failures;
            }
            foreach (Dictionary<string, object> c in (List<object>)conf["cases"])
            {
                cases++;
                string kind = c["kind"] as string ?? "";
                kinds[kind] = kinds.TryGetValue(kind, out var n) ? n + 1 : 1;
                string why;
                if (!knownKinds.Contains(kind)) why = $"unknown kind '{kind}': this bench must learn it";
                else
                {
                    try { why = run(kind, (Dictionary<string, object>)c["input"], c["expected"]); }
                    catch (Exception e) { why = e.GetType().Name + ": " + e.Message; }
                }
                if (why != null) failures.Add($"{c["name"]} — {why}");
            }
            return failures;
        }

        // ---- reading ----

        public static Int3 Vec(object o)
        {
            var l = (List<object>)o;
            return new Int3((int)MBJson.AsLong(l[0]), (int)MBJson.AsLong(l[1]), (int)MBJson.AsLong(l[2]));
        }

        public static HashSet<Int3> Cells(object o)
        {
            var s = new HashSet<Int3>();
            foreach (var p in (List<object>)o) s.Add(Vec(p));
            return s;
        }

        public static double[] Doubles(object o)
        {
            var l = (List<object>)o;
            var d = new double[l.Count];
            for (int k = 0; k < l.Count; k++) d[k] = MBJson.AsDouble(l[k]);
            return d;
        }

        public static double D(object o) => MBJson.AsDouble(o);
        public static int I(object o) => (int)MBJson.AsLong(o);

        // ---- comparing ----

        public static string ShowCells(IEnumerable<Int3> cells)
        {
            var sb = new StringBuilder("[");
            foreach (var c in MBTools.Sorted(cells)) { if (sb.Length > 1) sb.Append(' '); sb.Append(c); }
            return sb.Append(']').ToString();
        }

        /// <summary>A set of cells against an expected sorted list: null when equal.</summary>
        public static string SameCells(string what, IEnumerable<Int3> got, object expected)
        {
            var want = new List<Int3>();
            foreach (var p in (List<object>)expected) want.Add(Vec(p));
            // The expected side must itself be sorted x, y, z: the files promise it.
            for (int k = 1; k < want.Count; k++)
                if (MBTools.Compare(want[k - 1], want[k]) >= 0) return $"{what}: the expected list is not sorted";
            var g = MBTools.Sorted(got);
            if (g.Count != want.Count) return $"{what}: {g.Count} cells, expected {want.Count} — got {ShowCells(g)}, expected {ShowCells(want)}";
            for (int k = 0; k < g.Count; k++)
                if (!g[k].Equals(want[k])) return $"{what}: cell {k} is {g[k]}, expected {want[k]}";
            return null;
        }

        public static bool Near(double a, double b, double tolerance) => Math.Abs(a - b) <= tolerance;

        public static string SameNumber(string what, double got, object expected, double tolerance = 1e-6)
        {
            double e = MBJson.AsDouble(expected);
            return Near(got, e, tolerance) ? null : $"{what}: {F(got)}, expected {F(e)}";
        }

        public static string SameNumbers(string what, double[] got, object expected, double tolerance = 1e-6)
        {
            var e = Doubles(expected);
            if (e.Length != got.Length) return $"{what}: {got.Length} numbers, expected {e.Length}";
            for (int k = 0; k < e.Length; k++)
                if (!Near(got[k], e[k], tolerance)) return $"{what}[{k}]: {F(got[k])}, expected {F(e[k])}";
            return null;
        }

        public static string F(double d) => d.ToString("R", CultureInfo.InvariantCulture);

        /// <summary>Deep equality of two decoded JSON values: numbers to <paramref name="tolerance"/>, objects by key
        /// (same keys), arrays in order. Null when equal, else where they differ.</summary>
        public static string SameJson(string where, object got, object expected, double tolerance = 1e-6)
        {
            if (expected == null || got == null)
                return expected == null && got == null ? null : $"{where}: {Show(got)}, expected {Show(expected)}";
            if (IsNumber(expected))
                return IsNumber(got) && Near(MBJson.AsDouble(got), MBJson.AsDouble(expected), tolerance) ? null
                    : $"{where}: {Show(got)}, expected {Show(expected)}";
            if (expected is string || expected is bool)
                return expected.Equals(got) ? null : $"{where}: {Show(got)}, expected {Show(expected)}";
            if (expected is List<object> el)
            {
                if (!(got is List<object> gl)) return $"{where}: {Show(got)}, expected an array";
                if (gl.Count != el.Count) return $"{where}: {gl.Count} items, expected {el.Count}";
                for (int k = 0; k < el.Count; k++)
                {
                    var why = SameJson($"{where}[{k}]", gl[k], el[k], tolerance);
                    if (why != null) return why;
                }
                return null;
            }
            if (expected is Dictionary<string, object> ed)
            {
                if (!(got is Dictionary<string, object> gd)) return $"{where}: {Show(got)}, expected an object";
                foreach (var k in gd.Keys) if (!ed.ContainsKey(k)) return $"{where}: unexpected key '{k}'";
                foreach (var kv in ed)
                {
                    if (!gd.TryGetValue(kv.Key, out var gv)) return $"{where}: missing key '{kv.Key}'";
                    var why = SameJson($"{where}.{kv.Key}", gv, kv.Value, tolerance);
                    if (why != null) return why;
                }
                return null;
            }
            return $"{where}: cannot compare {expected.GetType().Name}";
        }

        static bool IsNumber(object o) => o is long || o is double || o is int || o is float;

        static string Show(object o) => o == null ? "null" : o is double d ? F(d) : o.ToString();
    }
}
