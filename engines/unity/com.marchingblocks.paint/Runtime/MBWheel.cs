// MarchingBlocks Paint for Unity — THE MOUSE WHEEL: what one notch does in the Scene view while painting.
//
// The same rule as the MarchingBlocks tool (editing_conformance.json, rules_text, "THE MOUSE WHEEL"), as a pure
// function, so that the routing itself is tested (Tests/Editor/WheelCheck.cs); what each action then does to the cells
// has its cases (extrude extend, widen_flat, shrink_edge). The wheel is OURS only when our mode paints and a modifier
// or a gesture asks for it: otherwise Unity keeps it (zoom). Unity's own panels are not ours either: the rule's
// "a slider never takes the wheel" applies to the plugin's bars only.

namespace MarchingBlocks.Paint
{
    public enum WheelTool { Add, Dig, Select, Rect, Box, Shape, Other }

    public enum WheelAction
    {
        /// <summary>Not ours: Unity zooms.</summary>
        None,
        GestureHeight, RoomFloors, PasteHeight, StairsStep, Floor,
        ExtendSelection, WidenFlat, ShrinkEdge, RoomRiseSink, ShapeSize, ShapeLength, BrushSize, NextBrushShape,
    }

    public struct WheelState
    {
        public bool Navigating;
        /// <summary>A Rect or a Box being dragged.</summary>
        public bool DraggingBox;
        /// <summary>A Room being traced.</summary>
        public bool TracingRoom;
        /// <summary>A paste following the mouse.</summary>
        public bool PastePreview;
        public bool Ctrl, Shift, Alt;
        /// <summary>+1 a notch up (away from you), −1 down.</summary>
        public int Notch;
        public WheelTool Tool;
        /// <summary>The special shape, when Tool is Shape.</summary>
        public SpecialShape Shape;
        public bool HasSelection;
    }

    public static class MBWheel
    {
        public static WheelAction Route(WheelState s)
        {
            if (s.Navigating || s.Notch == 0) return WheelAction.None;
            bool none = !s.Ctrl && !s.Shift && !s.Alt;
            if (none)
            {
                if (s.DraggingBox) return WheelAction.GestureHeight;
                if (s.TracingRoom) return WheelAction.RoomFloors;
                if (s.PastePreview) return WheelAction.PasteHeight;
                return WheelAction.None;
            }
            if (s.Ctrl && s.Shift && !s.Alt && s.Tool == WheelTool.Shape && s.Shape == SpecialShape.Stairs) return WheelAction.StairsStep;
            if (s.Ctrl && !s.Shift && !s.Alt) return WheelAction.Floor;
            if (s.Ctrl) return WheelAction.None;
            bool selectionTool = s.Tool == WheelTool.Select || s.Tool == WheelTool.Rect || s.Tool == WheelTool.Box;
            if (s.HasSelection && selectionTool)
            {
                if (s.Shift && !s.Alt) return WheelAction.ExtendSelection;
                if (s.Alt && !s.Shift) return s.Notch > 0 ? WheelAction.WidenFlat : WheelAction.ShrinkEdge;
                return WheelAction.None;
            }
            if (s.Tool == WheelTool.Shape)
            {
                if (s.Shape == SpecialShape.Room)
                    return s.Alt && !s.Shift ? WheelAction.RoomFloors : s.Shift && !s.Alt ? WheelAction.RoomRiseSink : WheelAction.None;
                return s.Alt && !s.Shift ? WheelAction.ShapeSize : s.Shift && !s.Alt ? WheelAction.ShapeLength : WheelAction.None;
            }
            if (s.Tool == WheelTool.Add || s.Tool == WheelTool.Dig || s.Tool == WheelTool.Select)
                return s.Alt && !s.Shift ? WheelAction.BrushSize : s.Shift && !s.Alt ? WheelAction.NextBrushShape : WheelAction.None;
            return WheelAction.None;
        }
    }
}
