// MarchingBlocks Paint for Unity — checks the aim and the navigation switch (AimState, MBTools.cs).
//
// Grid and Sculpt are the only aims; Tab alternates them. Navigating is a switch (Space) that keeps the
// aim and gives it back unchanged; choosing an aim — Tab or its button — stops navigating. The expected
// states are WRITTEN BY HAND here, never computed with AimState.
//
// No Unity dependency: compiled by the Test Runner (AimTests.cs) and by the .NET conformance-runner.
// Returns one line per failing check, empty when all pass.

using System;
using System.Collections.Generic;

namespace MarchingBlocks.Paint.Tests
{
    public static class AimCheck
    {
        public static List<string> Run(out int checks)
        {
            var failures = new List<string>();
            int n = 0;
            void Expect(string what, AimState got, BrushAim aim, bool navigating)
            {
                n++;
                if (got.Aim != aim || got.Navigating != navigating)
                    failures.Add($"{what}: expected {aim}{(navigating ? " + navigating" : "")}, got {got}");
            }
            var grid = new AimState(BrushAim.Grid, false);
            var sculpt = new AimState(BrushAim.Sculpt, false);
            var gridNav = new AimState(BrushAim.Grid, true);
            var sculptNav = new AimState(BrushAim.Sculpt, true);

            Expect("start", AimState.Start, BrushAim.Grid, false);

            // Tab alternates Grid and Sculpt, and nothing else.
            Expect("Tab from Grid", grid.Tab(), BrushAim.Sculpt, false);
            Expect("Tab from Sculpt", sculpt.Tab(), BrushAim.Grid, false);
            Expect("Tab twice", grid.Tab().Tab(), BrushAim.Grid, false);
            var s = AimState.Start;
            for (int i = 1; i <= 7; i++)
            {
                s = s.Tab();
                Expect($"Tab x{i} never navigates", s, i % 2 == 1 ? BrushAim.Sculpt : BrushAim.Grid, false);
            }

            // Space toggles navigation and keeps the aim.
            Expect("Space from Grid", grid.Space(), BrushAim.Grid, true);
            Expect("Space from Sculpt", sculpt.Space(), BrushAim.Sculpt, true);
            Expect("Space while navigating (Grid)", gridNav.Space(), BrushAim.Grid, false);
            Expect("Space while navigating (Sculpt)", sculptNav.Space(), BrushAim.Sculpt, false);
            Expect("Sculpt, Space, Space", sculpt.Space().Space(), BrushAim.Sculpt, false);
            Expect("Sculpt, Space x3", sculpt.Space().Space().Space(), BrushAim.Sculpt, true);

            // Choosing an aim — Tab or its button — stops navigating.
            Expect("Tab while navigating (Grid)", gridNav.Tab(), BrushAim.Sculpt, false);
            Expect("Tab while navigating (Sculpt)", sculptNav.Tab(), BrushAim.Grid, false);
            Expect("choose Grid while navigating from Sculpt", sculptNav.Choose(BrushAim.Grid), BrushAim.Grid, false);
            Expect("choose the kept aim while navigating", sculptNav.Choose(BrushAim.Sculpt), BrushAim.Sculpt, false);
            Expect("choose Sculpt from Grid", grid.Choose(BrushAim.Sculpt), BrushAim.Sculpt, false);
            Expect("choose Grid from Grid", grid.Choose(BrushAim.Grid), BrushAim.Grid, false);

            // No click paints while navigating.
            n++;
            if (!grid.Paints || !sculpt.Paints || gridNav.Paints || sculptNav.Paints)
                failures.Add("a click must paint exactly when not navigating");

            checks = n;
            return failures;
        }
    }
}
