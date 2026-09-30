// MarchingBlocks Paint for Unity — THE WORLD EDITING TOOLS, in the Scene view.
//
// The same tools as the MarchingBlocks tool. Unity has no GridMap, so everything here is ours: a click
// is a ray, converted through the tileset's measured frame. The rules live in MBTools.cs (pure, and
// proven by Tests/tools_conformance.json); this file only aims, previews and applies with Undo.
//
//   AIM      Grid — on the floor plane (Page Up / Page Down move it)
//            Sculpt — on the matter itself; falls back to the floor when the ray meets nothing
//            Tab alternates the two
//   NAVIGATE a switch, not an aim (Space, or its button): the mouse and keys are Unity's again (right
//            drag + W A S D Q E flies) and no click paints. Space again comes back to the SAME aim;
//            choosing an aim (its button or Tab) stops navigating too. Rules: AimState in MBTools.cs.
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
        enum Mode { Add, Dig, Select, Rect, Box }

        static bool editing;
        static AimState aim = AimState.Start;
        // Unity repeats KeyDown while a key is held: without this, holding Space would flicker navigation.
        static bool spaceHeld;
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
        //
        // The MarchingBlocks tool's right panel, compact: its icons (MBIcons, generated from the tool's own),
        // its groups — aim, tool, brush, floor, selection — and its olive accent. It only shows what the
        // current tool uses: the brush for Add · Dig · Select, Hollow for the Box, the selection when there
        // is one, Paste when something is copied. Painting is all this does.

        static readonly Color Olive = new Color(0.706f, 0.741f, 0.522f);
        static readonly Color OliveOnLight = new Color(0.40f, 0.45f, 0.18f);
        static readonly Color Red = new Color(0.878f, 0.376f, 0.235f);
        static GUIStyle sectionStyle;

        static Color Accent => EditorGUIUtility.isProSkin ? Olive : OliveOnLight;
        // The icons are white: on the light skin they are drawn dark.
        static Color Ink => EditorGUIUtility.isProSkin ? new Color(0.85f, 0.85f, 0.82f) : new Color(0.22f, 0.22f, 0.22f);

        static GUIContent Icon(string name, string tip) => new GUIContent(MBIcons.Get(name), tip);

        public override void OnInspectorGUI()
        {
            var world = World;
            if (sectionStyle == null)
                sectionStyle = new GUIStyle(EditorStyles.miniBoldLabel) { normal = { textColor = new Color(0.55f, 0.57f, 0.55f) } };

            serializedObject.Update();
            DrawPropertiesExcluding(serializedObject, "m_Script", "floor");
            serializedObject.ApplyModifiedProperties();
            EditorGUILayout.Space(4);

            var big = new GUIStyle(GUI.skin.button) { fontStyle = FontStyle.Bold, fixedHeight = 26 };
            var background = GUI.backgroundColor;
            if (editing) GUI.backgroundColor = Accent;
            bool now = GUILayout.Toggle(editing, editing ? "Painting — click to stop" : "Paint the world", big);
            GUI.backgroundColor = background;
            if (now != editing) { editing = now; CancelAll(); SceneView.RepaintAll(); }

            if (editing)
            {
                EditorGUIUtility.SetIconSize(new Vector2(18, 18));
                try { ToolsPanel(world); }
                finally { EditorGUIUtility.SetIconSize(Vector2.zero); }
            }

            EditorGUILayout.Space(2);
            var content = GUI.contentColor;
            if (!string.IsNullOrEmpty(world.LastError))
                EditorGUILayout.HelpBox(world.LastError, MessageType.Error);
            else
            {
                if (world.LastMissing > 0) GUI.contentColor = Red;
                EditorGUILayout.LabelField($"{world.CellCount} cells · {world.LastPlaced} tiles" +
                                           (world.LastMissing > 0 ? $" · {world.LastMissing} missing" : ""), EditorStyles.miniLabel);
                GUI.contentColor = content;
            }
            if (!string.IsNullOrEmpty(status))
            {
                GUI.contentColor = Accent;
                EditorGUILayout.LabelField(status, EditorStyles.wordWrappedMiniLabel);
                GUI.contentColor = content;
            }
        }

        void ToolsPanel(MarchingBlocksWorld world)
        {
            Section("AIM · Tab          NAVIGATE · Space");
            using (new EditorGUILayout.HorizontalScope())
            {
                // While navigating no aim button is down, so clicking either one — even the kept aim — is a
                // choice, and a choice stops navigating.
                int shown = aim.Navigating ? -1 : (int)aim.Aim;
                int picked = Segmented(shown,
                    Icon("grid", "Grid (Tab) — aims at the floor plane. Page Up / Page Down move it."),
                    Icon("sculpt", "Sculpt (Tab) — aims at the matter itself: Add builds against the face you point at."));
                if (picked != shown && picked >= 0) aim = aim.Choose((BrushAim)picked);
                GUILayout.Space(8);
                bool navigate = IconToggle(aim.Navigating, Icon("navigate", "Navigate (Space) — fly as usual in Unity " +
                    "(right drag + W A S D, Q E); no click paints. Space again comes back to the same aim."));
                if (navigate != aim.Navigating) { aim = aim.Space(); StopGesture(); }
                GUILayout.FlexibleSpace();
            }

            Section("TOOL");
            using (new EditorGUILayout.HorizontalScope())
            {
                var newMode = (Mode)Segmented((int)mode,
                    Icon("add", "Add (A) — adds matter. Shift digs."),
                    Icon("dig", "Dig (D) — removes matter. Shift adds."),
                    Icon("select", "Select (S) — paints the selection over the matter. Shift adds, Ctrl removes."),
                    Icon("rect", "Rect (G) — a FLAT rectangle on the floor, whatever the aim, empty cells included: a room's floor."),
                    Icon("box", "Box (B) — a 3D box: the whole volume, empty cells included. Shift adds, Ctrl removes."));
                if (newMode != mode) { mode = newMode; CancelAll(); }
                if (mode == Mode.Box)
                {
                    GUILayout.Space(8);
                    hollow = IconToggle(hollow, Icon("hollow", "Hollow box — keeps the skin: a room. A box thinner " +
                        "than three cells stays solid."));
                }
                GUILayout.FlexibleSpace();
            }

            if (mode == Mode.Add || mode == Mode.Dig || mode == Mode.Select)
            {
                Section("BRUSH · [ ]");
                using (new EditorGUILayout.HorizontalScope())
                {
                    shape = (BrushShape)Segmented((int)shape,
                        Icon("sphere", "Sphere — a ball of cells."),
                        Icon("cube", "Cube — a cube of cells."),
                        Icon("disc", "Disc — flat, across the face you point at: fills or digs a wall without thickening it."));
                    GUILayout.Space(8);
                    brushSize = EditorGUILayout.IntSlider(brushSize, 1, 7);
                }
            }

            Section("FLOOR · PgUp PgDn");
            using (new EditorGUILayout.HorizontalScope())
            {
                GUILayout.Label(Icon("floor", "The plane the Grid aim and the Rect paint on."), GUILayout.Width(22), GUILayout.Height(22));
                int f = EditorGUILayout.DelayedIntField(world.floor, GUILayout.Width(60));
                if (IconButton(Icon("down", "Page Down — one floor lower."))) f--;
                if (IconButton(Icon("up", "Page Up — one floor higher."))) f++;
                if (f != world.floor) { Undo.RecordObject(world, "Change floor"); world.floor = f; SceneView.RepaintAll(); }
                GUILayout.FlexibleSpace();
            }

            if (selection.Count > 0)
            {
                Section($"SELECTION · {selection.Count} cells");
                using (new EditorGUILayout.HorizontalScope())
                {
                    if (IconButton(Icon("fill", "Fill — fills every selected cell with matter. Draw a Rect or a Box, then Fill it."))) Operate(SelectionOp.Fill);
                    if (IconButton(Icon("delete", "Delete (Del) — removes the selected matter."), Red)) Operate(SelectionOp.Delete);
                    if (IconButton(Icon("clear", "Clear (Esc) — forgets the selection. No cell changes."))) ClearSelection();
                    GUILayout.Space(8);
                    if (IconButton(Icon("extrude_up", "Extrude up — adds the layer above; the selection AND the floor follow it."))) Operate(SelectionOp.ExtrudeUp);
                    if (IconButton(Icon("extrude_down", "Extrude down — adds the layer below; the selection and the floor follow it."))) Operate(SelectionOp.ExtrudeDown);
                    GUILayout.Space(8);
                    if (IconButton(Icon("grow", "Grow — selects the matter touching the selection by a face."))) Operate(SelectionOp.Grow);
                    if (IconButton(Icon("shrink", "Shrink — drops the selected cells that touch an unselected one."))) Operate(SelectionOp.Shrink);
                    if (IconButton(Icon("connected", "Connected — selects all the matter linked to the selection by faces."))) Operate(SelectionOp.Connected);
                    GUILayout.FlexibleSpace();
                }
                using (new EditorGUILayout.HorizontalScope())
                {
                    // The same moves as the arrow keys, on fixed axes — the arrows follow the camera, these do not.
                    GUILayout.Label(Icon("move", "Move — the arrow keys move it too (they follow the camera; Shift + up / down lift)."),
                        GUILayout.Width(22), GUILayout.Height(22));
                    foreach (var (label, offset) in new[] { ("−X", new Int3(-1, 0, 0)), ("+X", new Int3(1, 0, 0)),
                                 ("−Y", new Int3(0, -1, 0)), ("+Y", new Int3(0, 1, 0)), ("−Z", new Int3(0, 0, -1)), ("+Z", new Int3(0, 0, 1)) })
                        if (GUILayout.Button(new GUIContent(label, $"Moves the selected matter one cell ({label})."),
                                EditorStyles.miniButton, GUILayout.Width(30), GUILayout.Height(24)))
                            Move(offset);
                    GUILayout.Space(8);
                    if (IconButton(Icon("copy", "Copy (Ctrl+C) — copies the selected matter."))) Copy();
                    if (IconButton(Icon("cut", "Cut (Ctrl+X) — copies, then deletes."))) Cut();
                    GUILayout.FlexibleSpace();
                }
            }
            if (clipboard.Count > 0)
            {
                Section("CLIPBOARD · Ctrl V");
                using (new EditorGUILayout.HorizontalScope())
                {
                    bool on = IconToggle(pasting, Icon("paste", "Paste (Ctrl+V) — the copy follows the mouse; click in " +
                        "the Scene view to place it, Esc cancels."));
                    if (on && !pasting) StartPaste();
                    else if (!on && pasting) CancelAll();
                    GUILayout.Label(pasting ? "Click in the Scene view — Esc cancels" : $"{clipboard.Count} cells copied",
                        EditorStyles.miniLabel, GUILayout.Height(24));
                    GUILayout.FlexibleSpace();
                }
            }

            Section("LAYER");
            using (new EditorGUILayout.HorizontalScope())
            {
                if (IconButton(Icon("world", "Rebuild — lays the tiles again from the cells."))) world.Rebuild();
                if (IconButton(Icon("erase", "Clear cells — erases every cell of this layer (Ctrl+Z brings them back)."), Red))
                {
                    Undo.RecordObject(world, "Clear cells");
                    world.ClearCells();
                    world.Rebuild();
                    ClearSelection();
                }
                GUILayout.FlexibleSpace();
            }
        }

        static void Section(string title)
        {
            EditorGUILayout.Space(3);
            GUILayout.Label(title, sectionStyle);
        }

        // Icon buttons side by side, one of them down: the tool's choice rows. Returns the one picked.
        static int Segmented(int current, params GUIContent[] items)
        {
            int picked = current;
            for (int i = 0; i < items.Length; i++)
            {
                var style = i == 0 ? EditorStyles.miniButtonLeft
                    : i == items.Length - 1 ? EditorStyles.miniButtonRight : EditorStyles.miniButtonMid;
                if (IconToggle(i == current, items[i], style) && i != current) picked = i;
            }
            return picked;
        }

        // Down, its icon turns olive — the tool's accent.
        static bool IconToggle(bool on, GUIContent content, GUIStyle style = null)
        {
            var c = GUI.contentColor;
            GUI.contentColor = on ? Accent : Ink;
            bool now = GUILayout.Toggle(on, content, style ?? EditorStyles.miniButton, GUILayout.Width(30), GUILayout.Height(24));
            GUI.contentColor = c;
            return now;
        }

        static bool IconButton(GUIContent content, Color? tint = null)
        {
            var c = GUI.contentColor;
            GUI.contentColor = tint ?? Ink;
            bool pressed = GUILayout.Button(content, EditorStyles.miniButton, GUILayout.Width(30), GUILayout.Height(24));
            GUI.contentColor = c;
            return pressed;
        }


        // ── The Scene view ─────────────────────────────────────────────────────────────────────────

        void OnSceneGUI() => SceneGUI(Event.current);

        // The event is a parameter so that the tests can hand it real events: Event.current cannot be set
        // outside a GUI pass.
        void SceneGUI(Event e)
        {
            DrawSelection();
            if (!editing) return;
            if (HandleAimKeys(e))
            {
                StopGesture();
                Repaint();
                SceneView.RepaintAll();
                return;
            }
            // Navigating takes NO control: the mouse and keys are Unity's own, only Tab and Space are ours.
            if (!aim.Paints) return;
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
            if (aim.Aim == BrushAim.Sculpt)
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

        // Tab and Space, the keys that work whether navigating or not. Returns true when the event was
        // ours, and then USES it: Space must not reach Unity's other handlers when it toggles. Only called
        // while editing the selected world, so outside the tools Space and Tab are left alone.
        // Shift + Space stays Unity's (maximise the view).
        static bool HandleAimKeys(Event e)
        {
            if (e.type == EventType.KeyUp && e.keyCode == KeyCode.Space) { spaceHeld = false; return false; }
            if (e.type != EventType.KeyDown || e.alt || e.control || e.command) return false;
            if (e.keyCode == KeyCode.Tab) aim = aim.Tab();
            else if (e.keyCode == KeyCode.Space && !e.shift)
            {
                if (!spaceHeld) aim = aim.Space();   // a held key's repeats are swallowed, not toggled
                spaceHeld = true;
            }
            else return false;
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

        // A stroke or a box begun before navigating does not survive it: its mouse-up goes to Unity. A
        // paste does, like it survives Tab.
        void StopGesture()
        {
            if (!aim.Navigating) return;
            stroking = false;
            boxStart = null;
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
