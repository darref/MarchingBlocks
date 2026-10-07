// MarchingBlocks Paint for Unity — the rule of WHEN the water sheet is rebuilt (MBWaterFollow), checked from its text:
// never during a gesture, after the calm, never twice at once, an obsolete result not shown, the cut beyond a second and
// the button that re-arms it. No Unity dependency.

using System.Collections.Generic;

namespace MarchingBlocks.Paint.Tests
{
    public static class WaterFollowCheck
    {
        public static List<string> Run(out int checks)
        {
            var f = new List<string>();
            int n = 0;
            void Is(bool ok, string what) { n++; if (!ok) f.Add(what); }
            var w = new MBWaterFollow();
            Is(!w.Stale && !w.Due(10, false), "nothing changed: nothing due");
            w.Changed(1.0);
            Is(w.Stale, "a change makes the sheet stale");
            Is(!w.Due(1.2, false), "not before the calm (0.2 s)");
            Is(!w.Due(1.6, true), "never while a gesture is held");
            Is(w.Due(1.5, false), "due after 0.5 s of calm");
            w.Changed(1.55);
            Is(!w.Due(1.9, false), "a new change restarts the calm");
            Is(w.Due(2.06, false), "due again after the new calm");
            int t = w.Start();
            Is(w.Busy && !w.Due(9, false), "never twice at once");
            w.Changed(2.2);
            Is(!w.Finished(t, 0.3), "a change during the rebuild makes its result obsolete");
            Is(w.Stale && !w.Busy, "still stale after an obsolete rebuild");
            Is(w.Due(2.7, false), "another rebuild follows the calm");
            t = w.Start();
            Is(w.Finished(t, 0.3) && !w.Stale, "a rebuild that ends without change: shown, up to date");
            w.Changed(3.0);
            t = w.Start();
            Is(w.Finished(t, 1.4) && w.CutOff, "a rebuild beyond a second cuts the follow");
            w.Changed(5.0);
            Is(w.Stale && !w.Due(9, false), "cut: the sheet stays stale, nothing automatic");
            t = w.Start();
            Is(w.Finished(t, 0.2) && !w.CutOff && !w.Stale, "the button, fast again, re-arms the follow");
            w.Enabled = false;
            w.Changed(10);
            Is(!w.Due(20, false), "the follow turned off by the user: nothing automatic");
            checks = n;
            return f;
        }
    }
}
