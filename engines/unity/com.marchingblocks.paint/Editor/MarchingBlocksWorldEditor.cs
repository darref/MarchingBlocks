// MarchingBlocks Paint for Unity — THE WORLD EDITING TOOLS, in the Scene view.
//
// The same tools as the MarchingBlocks tool. Unity has no GridMap, so everything here is ours: a click
// is a ray, converted through the tileset's measured frame. The rules live in MBTools.cs (pure, and
// proven by Tests/tools_conformance.json); this file only aims, previews and applies with Undo.
//
//   AIM      Grid — on the floor plane (Page Up / Page Down move it)
//            Sculpt — on the matter itself; falls back to the floor when the ray meets nothing
//            Navigate — aims at nothing: the mouse is Unity's again (right drag + W A S D Q E flies)
//            Tab cycles the three
//   TOOLS    Add (A) · Dig (D) · Select (S) · Rect (G) · Box (B)      Shift does the opposite
//   BRUSH    size 1–7 ([ and ]), sphere / cube / disc
//   SELECT   Fill, Delete, Extrude ↑ ↓ (the floor follows), Grow, Shrink, Connected,
//            Move (arrow keys follow the camera; Shift + ↑ ↓ raise and lower), Copy / Cut / Paste
//
// Unity's right mouse button flies the camera, so the opposite of a tool is SHIFT, not the right click.
// The selection is editor state: it is not saved and not undoable, like a selection in any editor.

using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

namespace MarchingBlocks.Paint.EditorTools
{
    [CustomEditor(typeof(MarchingBlocksWorld))]
    public sealed class MarchingBlocksWorldEditor : Editor
    {
        enum Aim { Grid, Sculpt, Navigate }
        enum Mode { Add, Dig, Select, Rect, Box }

        static bool editing;
        static Aim aim = Aim.Grid;
        static Mode mode = Mode.Add;
        static int brushSize = 1;
        static BrushShape shape = BrushShape.Sphere;
        static bool hollow;

        static readonly HashSet<Int3> selection = new HashSet<Int3>();
        static List<Int3> clipboard = new List<Int3>();
        static bool pasting;
        static MarchingBlocksWorld selectionOwner;

        // The current stroke.
        bool stroking;
        bool strokeInverse;
        int strokeGroup;
        string lastKey;
        readonly HashSet<Int3> placedThisStroke = new HashSet<Int3>();
        Int3? boxStart;
        Int3 boxEnd;
        string status = "";

        const int MaxDrawn = 3000;
        static readonly Color AddColour = new Color(0.55f, 0.82f, 0.45f);
        static readonly Color DigColour = new Color(0.9f, 0.35f, 0.25f);
        static readonly Color SelectColour = new Color(0.95f, 0.8f, 0.3f);
        static readonly Color SelectionColour = new Color(0.35f, 0.7f, 1f);

        MarchingBlocksWorld World => (MarchingBlocksWorld)target;

        void OnEnable()
        {
            Undo.undoRedoPerformed += RebuildAfterUndo;
            if (selectionOwner != target) { selection.Clear(); selectionOwner = World; }
        }

        void OnDisable() => Undo.undoRedoPerformed -= RebuildAfterUndo;

        void RebuildAfterUndo()
        {
            if (target != null) World.Rebuild();
        }

        // ── The inspector ──────────────────────────────────────────────────────────────────────────

        public override void OnInspectorGUI()
        {
            var world = World;
            DrawDefaultInspector();
            EditorGUILayout.Space();

            var big = new GUIStyle(GUI.skin.button) { fontStyle = FontStyle.Bold, fixedHeight = 30 };
            bool now = GUILayout.Toggle(editing, editing ? "Editing the world — click here to stop" : "Edit the world", big);
            if (now != editing) { editing = now; CancelAll(); SceneView.RepaintAll(); }

            using (new EditorGUI.DisabledScope(!editing))
            {
                aim = (Aim)GUILayout.Toolbar((int)aim, new[] { "Grid", "Sculpt", "Navigate" });
                EditorGUILayout.HelpBox(aim == Aim.Grid
                    ? "Grid: aims at the floor plane. Page Up / Page Down move it."
                    : aim == Aim.Sculpt
                    ? "Sculpt: aims at the matter itself — Add builds against the face you point at."
                    : "Navigate: aims at nothing. Fly with the right mouse button and W A S D (Q E up and down), " +
                      "as usual in Unity; no click paints. Tab comes back to Grid.",
                    MessageType.None);
                var newMode = (Mode)GUILayout.Toolbar((int)mode, new[] { "Add  A", "Dig  D", "Select  S", "Rect  G", "Box  B" });
                if (newMode != mode) { mode = newMode; CancelAll(); }
                EditorGUILayout.HelpBox(ModeHelp(), MessageType.None);

                if (mode == Mode.Box)
                    hollow = EditorGUILayout.ToggleLeft(new GUIContent("Hollow box",
                        "Keeps only the skin of the box — walls, floor and ceiling: a room. A box thinner " +
                        "than three cells on an axis has no inside, so it stays solid."), hollow);
                if (mode == Mode.Add || mode == Mode.Dig || mode == Mode.Select)
                {
                    brushSize = EditorGUILayout.IntSlider("Brush size  [ ]", brushSize, 1, 7);
                    shape = (BrushShape)GUILayout.Toolbar((int)shape, new[] { "Sphere", "Cube", "Disc" });
                }
                EditorGUILayout.LabelField("Floor", world.floor.ToString());

                EditorGUILayout.Space();
                EditorGUILayout.LabelField($"Selection — {selection.Count} cell(s)", EditorStyles.boldLabel);
                using (new EditorGUI.DisabledScope(selection.Count == 0))
                {
                    Row(("Fill", () => Operate(SelectionOp.Fill)), ("Delete", () => Operate(SelectionOp.Delete)),
                        ("Clear", ClearSelection));
                    Row(("Extrude ↑", () => Operate(SelectionOp.ExtrudeUp)), ("Extrude ↓", () => Operate(SelectionOp.ExtrudeDown)));
                    Row(("Grow", () => Operate(SelectionOp.Grow)), ("Shrink", () => Operate(SelectionOp.Shrink)),
                        ("Connected", () => Operate(SelectionOp.Connected)));
                    Row(("−X", () => Move(new Int3(-1, 0, 0))), ("+X", () => Move(new Int3(1, 0, 0))),
                        ("−Y", () => Move(new Int3(0, -1, 0))), ("+Y", () => Move(new Int3(0, 1, 0))),
                        ("−Z", () => Move(new Int3(0, 0, -1))), ("+Z", () => Move(new Int3(0, 0, 1))));
                    Row(("Copy", Copy), ("Cut", Cut));
                }
                using (new EditorGUI.DisabledScope(clipboard.Count == 0))
                    if (GUILayout.Button(pasting ? "Pasting — click in the Scene view (Esc cancels)" : $"Paste ({clipboard.Count} cells)"))
                        StartPaste();
            }

            EditorGUILayout.Space();
            if (!string.IsNullOrEmpty(world.LastError))
                EditorGUILayout.HelpBox(world.LastError, MessageType.Error);
            else
                EditorGUILayout.LabelField($"{world.CellCount} cell(s) · {world.LastPlaced} tile(s)" +
                                           (world.LastMissing > 0 ? $" · {world.LastMissing} missing (red)" : ""));
            if (!string.IsNullOrEmpty(status)) EditorGUILayout.HelpBox(status, MessageType.Info);

            using (new EditorGUILayout.HorizontalScope())
            {
                if (GUILayout.Button("Rebuild")) world.Rebuild();
                if (GUILayout.Button("Clear cells"))
                {
                    Undo.RecordObject(world, "Clear cells");
                    world.ClearCells();
                    world.Rebuild();
                    ClearSelection();
                }
            }
        }

        static string ModeHelp()
        {
            switch (mode)
            {
                case Mode.Add: return "Click or drag to add matter. Shift digs instead.";
                case Mode.Dig: return "Click or drag to remove matter. Shift adds instead.";
                case Mode.Select: return "Paint over the matter to select it. Shift adds to the selection; Ctrl deselects.";
                case Mode.Rect: return "Drag a FLAT rectangle on the floor, whatever the aim. Empty cells included: " +
                                       "draw a room's floor, then Fill and Extrude it. Shift adds, Ctrl removes.";
                default: return "Drag a 3D box: the whole volume, empty cells included. In Sculpt its corners sit on the " +
                                "matter, in Grid on the floor. Shift adds, Ctrl removes.";
            }
        }

        static void Row(params (string label, System.Action act)[] buttons)
        {
            using (new EditorGUILayout.HorizontalScope())
                foreach (var b in buttons)
                    if (GUILayout.Button(b.label)) b.act();
        }

        // ── The Scene view ─────────────────────────────────────────────────────────────────────────

        void OnSceneGUI()
        {
            DrawSelection();
            if (!editing) return;
            var e = Event.current;
            // Navigate takes NO control: the mouse and keys are Unity's own, only Tab is ours.
            if (aim == Aim.Navigate)
            {
                if (e.type == EventType.KeyDown && e.keyCode == KeyCode.Tab && !e.alt && !e.control)
                {
                    aim = Aim.Grid;
                    e.Use();
                    Repaint();
                }
                return;
            }
            int id = GUIUtility.GetControlID(FocusType.Passive);
            if (e.type == EventType.Layout) HandleUtility.AddDefaultControl(id);

            if (HandleCommands(e) || HandleKeys(e)) return;

            var ray = HandleUtility.GUIPointToWorldRay(e.mousePosition);
            if (pasting) { ScenePaste(e, ray); return; }
            if (mode == Mode.Rect || mode == Mode.Box) { SceneBox(e, ray, id); return; }
            SceneBrush(e, ray, id);
        }

        // A point under the mouse for a gesture: the matter in Sculpt (when the ray meets it), the floor
        // otherwise. Returns false when neither is under the mouse.
        bool Aimed(Ray ray, bool add, out Hit hit)
        {
            hit = default;
            if (aim == Aim.Sculpt)
            {
                hit = World.RayAgainstCells(ray, add ? placedThisStroke : null);
                if (hit.Touched) return true;
            }
            if (!World.CellUnderRay(ray, out var c)) return false;
            hit = new Hit { Touched = false, Cell = new Int3(c.x, c.y, c.z), Normal = default };
            return true;
        }

        BrushTool Gesture(bool inverse)
        {
            if (mode == Mode.Add) return inverse ? BrushTool.Dig : BrushTool.Add;
            if (mode == Mode.Dig) return inverse ? BrushTool.Add : BrushTool.Dig;
            return BrushTool.Select;
        }

        void SceneBrush(Event e, Ray ray, int id)
        {
            bool inverse = stroking ? strokeInverse : e.shift;
            var gesture = Gesture(inverse);
            if (!Aimed(ray, gesture == BrushTool.Add, out var hit)) return;
            var anchor = MBTools.Anchor(gesture, hit);
            var cells = MBTools.Brush(anchor, hit.Normal, brushSize, shape);
            DrawCells(cells, gesture == BrushTool.Add ? AddColour : gesture == BrushTool.Dig ? DigColour : SelectColour, 0.04f);

            if (e.type == EventType.MouseDown && e.button == 0 && !e.alt)
            {
                stroking = true;
                strokeInverse = e.shift;
                lastKey = null;
                placedThisStroke.Clear();
                Undo.IncrementCurrentGroup();
                strokeGroup = Undo.GetCurrentGroup();
                GUIUtility.hotControl = id;
                if (mode == Mode.Select && !e.shift && !e.control) selection.Clear();
                Touch(Gesture(strokeInverse), anchor, hit, cells, e.control);
                e.Use();
            }
            else if (e.type == EventType.MouseDrag && stroking && e.button == 0)
            {
                Touch(Gesture(strokeInverse), anchor, hit, cells, e.control);
                e.Use();
            }
            else if (e.type == EventType.MouseUp && stroking && e.button == 0)
            {
                stroking = false;
                GUIUtility.hotControl = 0;
                Undo.CollapseUndoOperations(strokeGroup);
                e.Use();
            }
            if (e.type == EventType.MouseMove || e.type == EventType.MouseDrag) SceneView.RepaintAll();
        }

        void Touch(BrushTool gesture, Int3 anchor, Hit hit, List<Int3> cells, bool deselect)
        {
            // The same cell under the same face twice in a row is nothing new: skip it.
            string key = $"{anchor}|{hit.Normal}";
            if (key == lastKey) return;
            lastKey = key;
            if (gesture == BrushTool.Select)
            {
                foreach (var c in cells)
                    if (deselect) selection.Remove(c);
                    else if (World.Cells.Contains(c)) selection.Add(c);
                Repaint();
                return;
            }
            var change = MBTools.Modify(gesture, cells, World.Cells.Contains);
            if (change.IsEmpty) return;
            // The stroke lock: what this stroke placed is transparent to its own ray, or dragging would
            // build a tower towards the camera instead of a skin on the surface.
            foreach (var c in change.Set) placedThisStroke.Add(c);
            Undo.RecordObject(World, gesture == BrushTool.Add ? "Add matter" : "Dig matter");
            World.Apply(change);
        }

        // The Rect ignores the aim: it always lies flat on the floor, the gesture that draws a room's floor.
        bool BoxCorner(Ray ray, out Int3 corner)
        {
            corner = default;
            if (mode == Mode.Rect)
            {
                if (!World.CellUnderRay(ray, out var c)) return false;
                corner = new Int3(c.x, c.y, c.z);
                return true;
            }
            if (!Aimed(ray, false, out var hit)) return false;
            corner = hit.Cell;
            return true;
        }

        void SceneBox(Event e, Ray ray, int id)
        {
            bool has = BoxCorner(ray, out var corner);
            if (boxStart == null)
            {
                if (has) DrawCells(new[] { corner }, SelectColour, 0.04f);
                if (e.type == EventType.MouseDown && e.button == 0 && !e.alt && has)
                {
                    boxStart = corner;
                    boxEnd = corner;
                    GUIUtility.hotControl = id;
                    e.Use();
                }
            }
            else
            {
                if (has) boxEnd = corner;
                var volume = MBTools.Box(boxStart.Value, boxEnd, hollow && mode == Mode.Box);
                DrawCells(volume, e.control ? DigColour : SelectColour, 0.02f);
                if (e.type == EventType.MouseDrag) e.Use();
                if (e.type == EventType.MouseUp && e.button == 0)
                {
                    if (volume.Count == 0)
                        status = $"Box too large — more than {MBTools.BoxVolumeMax} cells. Draw a smaller one.";
                    else
                    {
                        if (!e.shift && !e.control) selection.Clear();
                        foreach (var c in volume)
                            if (e.control) selection.Remove(c); else selection.Add(c);
                        status = "";
                    }
                    boxStart = null;
                    GUIUtility.hotControl = 0;
                    e.Use();
                    Repaint();
                }
            }
            if (e.type == EventType.MouseMove || e.type == EventType.MouseDrag) SceneView.RepaintAll();
        }

        void ScenePaste(Event e, Ray ray)
        {
            if (!Aimed(ray, true, out var hit)) return;
            var anchor = MBTools.Anchor(BrushTool.Add, hit);
            var cells = new List<Int3>();
            foreach (var d in clipboard) cells.Add(anchor + d);
            DrawCells(cells, AddColour, 0.04f);
            if (e.type == EventType.MouseDown && e.button == 0 && !e.alt)
            {
                var change = MBTools.Paste(World.Cells, clipboard, anchor);
                Undo.RecordObject(World, "Paste");
                int n = World.Apply(change);
                SetSelection(change.Selection);
                pasting = false;
                status = $"Pasted — {n} cell(s) set.";
                e.Use();
                Repaint();
            }
            if (e.type == EventType.MouseMove) SceneView.RepaintAll();
        }

        bool HandleCommands(Event e)
        {
            if (e.type != EventType.ValidateCommand && e.type != EventType.ExecuteCommand) return false;
            string c = e.commandName;
            bool ours = c == "Copy" || c == "Cut" || c == "Paste" || c == "Delete" || c == "SoftDelete";
            if (!ours) return false;
            if ((c == "Copy" || c == "Cut" || c == "Delete" || c == "SoftDelete") && selection.Count == 0) return false;
            if (c == "Paste" && clipboard.Count == 0) return false;
            if (e.type == EventType.ExecuteCommand)
            {
                if (c == "Copy") Copy();
                else if (c == "Cut") Cut();
                else if (c == "Paste") StartPaste();
                else Operate(SelectionOp.Delete);
            }
            e.Use();
            return true;
        }

        bool HandleKeys(Event e)
        {
            if (e.type != EventType.KeyDown || e.alt || e.control || e.command) return false;
            switch (e.keyCode)
            {
                case KeyCode.A: SetMode(Mode.Add); break;
                case KeyCode.D: SetMode(Mode.Dig); break;
                case KeyCode.S: SetMode(Mode.Select); break;
                case KeyCode.G: SetMode(Mode.Rect); break;
                case KeyCode.B: SetMode(Mode.Box); break;
                case KeyCode.Tab: aim = (Aim)(((int)aim + 1) % 3); break;
                case KeyCode.LeftBracket: brushSize = Mathf.Max(1, brushSize - 1); break;
                case KeyCode.RightBracket: brushSize = Mathf.Min(7, brushSize + 1); break;
                case KeyCode.PageUp: ChangeFloor(1); break;
                case KeyCode.PageDown: ChangeFloor(-1); break;
                case KeyCode.Escape:
                    if (pasting || boxStart != null) CancelAll(); else ClearSelection();
                    break;
                case KeyCode.UpArrow: case KeyCode.DownArrow: case KeyCode.LeftArrow: case KeyCode.RightArrow:
                    if (selection.Count == 0) return false;
                    Move(ArrowOffset(e.keyCode, e.shift));
                    break;
                default: return false;
            }
            e.Use();
            Repaint();
            SceneView.RepaintAll();
            return true;
        }

        void SetMode(Mode m) { mode = m; CancelAll(); }

        // The arrows FOLLOW THE CAMERA: "up" moves away from you along the format axis (X or Z) closest to
        // where the camera looks; Shift + up / down raise and lower.
        Int3 ArrowOffset(KeyCode key, bool shift)
        {
            if (shift && (key == KeyCode.UpArrow || key == KeyCode.DownArrow))
                return new Int3(0, key == KeyCode.UpArrow ? 1 : -1, 0);
            var cam = SceneView.lastActiveSceneView != null ? SceneView.lastActiveSceneView.camera.transform : null;
            Vector3 fwd = cam != null ? World.WorldDirectionToFormat(cam.forward) : Vector3.forward;
            Vector3 right = cam != null ? World.WorldDirectionToFormat(cam.right) : Vector3.right;
            Int3 Axis(Vector3 v) => Mathf.Abs(v.x) >= Mathf.Abs(v.z)
                ? new Int3(v.x >= 0 ? 1 : -1, 0, 0) : new Int3(0, 0, v.z >= 0 ? 1 : -1);
            var f = Axis(fwd);
            var r = Axis(right);
            switch (key)
            {
                case KeyCode.UpArrow: return f;
                case KeyCode.DownArrow: return new Int3(-f.x, 0, -f.z);
                case KeyCode.RightArrow: return r;
                default: return new Int3(-r.x, 0, -r.z);
            }
        }

        void ChangeFloor(int step)
        {
            Undo.RecordObject(World, "Change floor");
            World.floor += step;
        }

        // ── Operations ─────────────────────────────────────────────────────────────────────────────

        void Operate(SelectionOp op)
        {
            if (selection.Count == 0) { status = "Nothing selected. Drag a Rect (G) on the floor, a Box (B), or paint with Select (S)."; return; }
            var change = MBTools.Operate(World.Cells, selection, op);
            Undo.RecordObject(World, op.ToString());
            int n = World.Apply(change);
            SetSelection(change.Selection);
            // The floor FOLLOWS the extrusion, so fill, extrude, fill… keeps going without Page Up.
            if (op == SelectionOp.ExtrudeUp) World.floor += 1;
            if (op == SelectionOp.ExtrudeDown) World.floor -= 1;
            status = $"{op} — {n} cell(s) changed, {selection.Count} selected. Ctrl+Z undoes the cells.";
            SceneView.RepaintAll();
        }

        void Move(Int3 offset)
        {
            if (selection.Count == 0) return;
            var change = MBTools.Move(World.Cells, selection, offset);
            Undo.RecordObject(World, "Move");
            World.Apply(change);
            SetSelection(change.Selection);
            SceneView.RepaintAll();
        }

        void Copy()
        {
            clipboard = MBTools.Copy(World.Cells, selection);
            status = clipboard.Count == 0 ? "Nothing to copy: the selection holds no matter." : $"Copied {clipboard.Count} cell(s).";
        }

        void Cut()
        {
            Copy();
            if (clipboard.Count > 0) Operate(SelectionOp.Delete);
        }

        void StartPaste()
        {
            if (clipboard.Count == 0) return;
            pasting = true;
            editing = true;
            SceneView.RepaintAll();
        }

        static void SetSelection(IEnumerable<Int3> cells)
        {
            selection.Clear();
            foreach (var c in cells) selection.Add(c);
        }

        void ClearSelection()
        {
            selection.Clear();
            SceneView.RepaintAll();
            Repaint();
        }

        void CancelAll()
        {
            pasting = false;
            boxStart = null;
            stroking = false;
        }

        // ── Drawing ────────────────────────────────────────────────────────────────────────────────

        void DrawSelection()
        {
            if (selection.Count == 0 || selectionOwner != World) return;
            DrawCells(selection, SelectionColour, 0.08f);
        }

        // Wire cubes, shrunk a little so neighbouring cells stay readable. Capped: past a few thousand the
        // Scene view would crawl, and the count is in the inspector anyway.
        void DrawCells(IEnumerable<Int3> cells, Color colour, float inset)
        {
            var previous = Handles.matrix;
            Handles.color = colour;
            int n = 0;
            foreach (var c in cells)
            {
                if (++n > MaxDrawn) break;
                Handles.matrix = World.CellMatrix(c);
                Handles.DrawWireCube(Vector3.zero, Vector3.one * (1f - inset));
            }
            Handles.matrix = previous;
        }
    }
}
