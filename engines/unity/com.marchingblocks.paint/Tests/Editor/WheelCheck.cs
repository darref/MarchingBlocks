// MarchingBlocks Paint for Unity — THE WHEEL'S ROUTING (MBWheel), against the rule as written in
// editing_conformance.json ("THE MOUSE WHEEL"). The expectations are written HERE, by hand, from the text — never
// computed by the function under test. No Unity dependency: run by the Test Runner and the .NET conformance-runner.

using System.Collections.Generic;

namespace MarchingBlocks.Paint.Tests
{
    public static class WheelCheck
    {
        public static List<string> Run(out int checks)
        {
            var failures = new List<string>();
            int n = 0;
            void Expect(string what, WheelState s, WheelAction want)
            {
                n++;
                var got = MBWheel.Route(s);
                if (got != want) failures.Add($"{what}: {got}, expected {want}");
            }
            WheelState S(WheelTool tool, bool ctrl = false, bool shift = false, bool alt = false, int notch = 1) =>
                new WheelState { Tool = tool, Ctrl = ctrl, Shift = shift, Alt = alt, Notch = notch };

            Expect("no modifier: zoom", S(WheelTool.Add), WheelAction.None);
            Expect("navigating: never ours", new WheelState { Navigating = true, Ctrl = true, Notch = 1, Tool = WheelTool.Add }, WheelAction.None);
            var drag = S(WheelTool.Rect); drag.DraggingBox = true;
            Expect("a Rect being dragged: its height", drag, WheelAction.GestureHeight);
            var room = S(WheelTool.Shape); room.Shape = SpecialShape.Room; room.TracingRoom = true;
            Expect("a Room being traced: its floors", room, WheelAction.RoomFloors);
            var paste = S(WheelTool.Add); paste.PastePreview = true;
            Expect("a paste preview: its height", paste, WheelAction.PasteHeight);
            var stairs = S(WheelTool.Shape, ctrl: true, shift: true); stairs.Shape = SpecialShape.Stairs;
            Expect("Ctrl + Shift with Stairs: the step", stairs, WheelAction.StairsStep);
            Expect("Ctrl: the floor", S(WheelTool.Dig, ctrl: true), WheelAction.Floor);
            Expect("Ctrl, even with a selection: the floor", Sel(S(WheelTool.Select, ctrl: true)), WheelAction.Floor);
            Expect("selection + Select + Shift: Extend selection", Sel(S(WheelTool.Select, shift: true)), WheelAction.ExtendSelection);
            Expect("selection + Box + Shift: Extend selection", Sel(S(WheelTool.Box, shift: true)), WheelAction.ExtendSelection);
            Expect("selection + Rect + Alt up: widen", Sel(S(WheelTool.Rect, alt: true)), WheelAction.WidenFlat);
            Expect("selection + Rect + Alt down: shrink the edge", Sel(S(WheelTool.Rect, alt: true, notch: -1)), WheelAction.ShrinkEdge);
            Expect("selection but Add: the brush size", Sel(S(WheelTool.Add, alt: true)), WheelAction.BrushSize);
            var roomAlt = S(WheelTool.Shape, alt: true); roomAlt.Shape = SpecialShape.Room;
            Expect("Room + Alt: floors", roomAlt, WheelAction.RoomFloors);
            var roomShift = S(WheelTool.Shape, shift: true); roomShift.Shape = SpecialShape.Room;
            Expect("Room + Shift: rises / sinks", roomShift, WheelAction.RoomRiseSink);
            var tunnelAlt = S(WheelTool.Shape, alt: true); tunnelAlt.Shape = SpecialShape.Tunnel;
            Expect("another shape + Alt: size", tunnelAlt, WheelAction.ShapeSize);
            var tunnelShift = S(WheelTool.Shape, shift: true); tunnelShift.Shape = SpecialShape.Tunnel;
            Expect("another shape + Shift: length", tunnelShift, WheelAction.ShapeLength);
            Expect("Add + Alt: brush size", S(WheelTool.Add, alt: true), WheelAction.BrushSize);
            Expect("Dig + Shift: next brush shape", S(WheelTool.Dig, shift: true), WheelAction.NextBrushShape);
            Expect("Select without a selection + Shift: next brush shape", S(WheelTool.Select, shift: true), WheelAction.NextBrushShape);
            Expect("Box without a selection + Alt: nothing", S(WheelTool.Box, alt: true), WheelAction.None);
            Expect("a notch of 0: nothing", S(WheelTool.Add, ctrl: true, notch: 0), WheelAction.None);
            checks = n;
            return failures;
        }

        static WheelState Sel(WheelState s) { s.HasSelection = true; return s; }
    }
}
