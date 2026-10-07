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
//   SHAPES   Tunnel · Well · Bridge · Balcony · Stairs (MBShapes.cs), always aimed at the matter: Straight
//            is one click square out of a face, Connect is two clicks on two faces anywhere (two floors for
//            Stairs; Esc forgets the first)
//   PLANT    the models of the world's MarchingBlocks Foliage (MBPlanting.cs, the rule MBFoliage): a click plants one,
//            Ctrl + click (and drag) a dab of the brush, Shift + click (and drag) erases within it — one undo step a stroke
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
        enum Mode { Add, Dig, Select, Rect, Box, Shape, Variant, Plant }

        static bool editing;
        static AimState aim = AimState.Start;
        // Unity repeats KeyDown while a key is held: without this, holding Space would flicker navigation.
        static bool spaceHeld;
        static Mode mode = Mode.Add;
        static int brushSize = 1;
        static BrushShape shape = BrushShape.Sphere;
        static bool hollow;
        // The special shape (Mode.Shape): which one, one click or two, and its settings.
        static SpecialShape special = SpecialShape.Tunnel;
        static bool connectEnds;
        static ShapeProfile profile = ShapeProfile.Round;
        static int shapeSize = 2;
        static int shapeLength = 8;
        static bool rail = true;
        static int stairsStep = 2;
        // The room: drawn flat on the floor, then raised (up) or sunk (down) by this many free floors.
        static int roomFloors = 3;
        static bool roomUp = true;
        // The first end of a Connect, or null.
        static Hit? shapeAnchor;

        // "Select empty cells too" (the Select brush takes the empty cells of its brush as well).
        static bool selectEmpty;
        // The wheel during a gesture: the height of a Rect / Box being dragged, of a paste preview.
        static int gestureHeight;
        static int pasteHeight;

        // THE PLANT TOOL: the model, the placing mode, the brush, the spacing, the slope, the random yaw; its draws.
        static readonly PlantSettings plant = new PlantSettings();
        static System.Random plantDraw = new System.Random();
        // A plant stroke: its gesture (one, sow, erase), the world asked once, where it last dabbed.
        string plantGesture;
        MBPlanting.Asked plantAsk;
        MarchingBlocksFoliage plantFoliage;
        Vector3? plantLast;
        const float PlantStep = 0.4f;

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
            if (target == null) return;
            World.Rebuild();
            // The plants undone come back drawn.
            var f = MBPlanting.FoliageOf(World);
            if (f != null) f.Rebuild();
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
                // The row of tools: Add … Box, then Variant (index 5 of the row, not Mode.Shape), then Plant (6).
                int shownTool = mode <= Mode.Box ? (int)mode : mode == Mode.Variant ? 5 : mode == Mode.Plant ? 6 : -1;
                int pickedTool = Segmented(shownTool,
                    Icon("add", "Add (A) — adds matter. Shift digs."),
                    Icon("dig", "Dig (D) — removes matter. Shift adds."),
                    Icon("select", "Select (S) — paints the selection over the matter. Shift adds, Ctrl removes."),
                    Icon("rect", "Rect (G) — a FLAT rectangle on the floor, whatever the aim, empty cells included: a room's floor."),
                    Icon("box", "Box (B) — a 3D box: the whole volume, empty cells included. Shift adds, Ctrl removes."),
                    Icon("variant", "Variant (V) — click a tile: its next variant (base, 1, 2…). Shift + click gives it back " +
                        "to the random draw. Only for a tileset whose tiles have variants."),
                    Icon("plant", "Plant — plants the models of this world's MarchingBlocks Foliage: a click plants one, " +
                        "Ctrl + click (and drag) a dab of the brush, Shift + click (and drag) erases within it. Ctrl+Z undoes a stroke."));
                if (pickedTool != shownTool && pickedTool >= 0)
                {
                    mode = pickedTool == 5 ? Mode.Variant : pickedTool == 6 ? Mode.Plant : (Mode)pickedTool;
                    CancelAll();
                }
                if (mode == Mode.Box)
                {
                    GUILayout.Space(8);
                    hollow = IconToggle(hollow, Icon("hollow", "Hollow box — keeps the skin: a room. A box thinner " +
                        "than three cells stays solid."));
                }
                GUILayout.FlexibleSpace();
            }

            Section("SPECIAL SHAPES");
            using (new EditorGUILayout.HorizontalScope())
            {
                int shown = mode == Mode.Shape ? (int)special : -1;
                int picked = Segmented(shown,
                    Icon("tunnel", "Tunnel — digs into a WALL, square to it: one click goes through to the next cave (or " +
                        "Length deep); Connect joins two walls anywhere, slanted ones included."),
                    Icon("well", "Well — digs into a FLOOR or a CEILING, straight: one click stops in the cave below (or " +
                        "Length deep); Connect joins a floor and a ceiling."),
                    Icon("bridge", "Bridge — a deck out of a WALL across the air to the first wall in front; Connect " +
                        "joins two walls, and the deck bends."),
                    Icon("balcony", "Balcony — a slab sticking out of a WALL at the height you click, with its rail."),
                    Icon("stairs", "Stairs — click a WALL where they should arrive: they come down to the ground, Step " +
                        "cells per step; Connect climbs from one floor to another, higher up."),
                    Icon("room", "Room — draw a rectangle flat on the floor: a hollow room rises from it (Up) or sinks " +
                        "under it (Down), Floors high, its walls one cell thick. At least 3 × 3."));
                if (picked != shown && picked >= 0) { special = (SpecialShape)picked; mode = Mode.Shape; CancelAll(); }
                GUILayout.FlexibleSpace();
            }
            if (mode == Mode.Shape && special == SpecialShape.Room)
            {
                using (new EditorGUILayout.HorizontalScope())
                {
                    int sense = Segmented(roomUp ? 0 : 1,
                        Icon("up", "Up — the rectangle is the room's FLOOR: it rises from the grid."),
                        Icon("down", "Down — the rectangle is the room's CEILING: it sinks under the grid."));
                    roomUp = sense == 0;
                    GUILayout.FlexibleSpace();
                }
                roomFloors = EditorGUILayout.IntSlider(new GUIContent("Floors", "[ and ] — the room's free height, in cells."),
                    roomFloors, 1, MBShapes.RoomFloorsMax);
            }
            else if (mode == Mode.Shape)
            {
                using (new EditorGUILayout.HorizontalScope())
                {
                    if (special != SpecialShape.Balcony)
                    {
                        int ends = Segmented(connectEnds ? 1 : 0,
                            Icon("straight", "Straight — one click: straight out of the face, square to it."),
                            Icon("connect", "Connect — two clicks: a face, then another one; both ends stay open. Esc forgets the first."));
                        if ((ends == 1) != connectEnds) { connectEnds = ends == 1; CancelAll(); }
                        GUILayout.Space(8);
                    }
                    if (special == SpecialShape.Tunnel || special == SpecialShape.Well)
                        profile = (ShapeProfile)Segmented((int)profile,
                            Icon("round", "Round — a round tube."),
                            Icon("square", "Square — a square duct."),
                            Icon("arch", "Arch — a flat floor and a round vault: a corridor you can walk."));
                    if (special == SpecialShape.Bridge || special == SpecialShape.Balcony || special == SpecialShape.Stairs)
                        rail = IconToggle(rail, Icon("rail", "Rail — a one-cell rim along the open sides. Needs a size of 2 or more."));
                    GUILayout.FlexibleSpace();
                }
                shapeSize = EditorGUILayout.IntSlider(new GUIContent("Size", "[ and ] — 1 is one cell across, 2 is three, 3 is five…"), shapeSize, 1, 7);
                if (special == SpecialShape.Balcony || !connectEnds)
                    shapeLength = EditorGUILayout.IntSlider(new GUIContent(special == SpecialShape.Bridge ? "Reach"
                        : special == SpecialShape.Stairs ? "Length" : "Depth",
                        "How deep a straight tunnel or well goes when it finds no cave, how far a straight bridge looks for " +
                        "a wall, how far a balcony sticks out, how far stairs may run before they reach the ground."),
                        shapeLength, 1, MBShapes.LengthMax);
                if (special == SpecialShape.Stairs && !connectEnds)
                    stairsStep = EditorGUILayout.IntSlider(new GUIContent("Step", "How deep each stair is, in cells (1 is steep)."),
                        stairsStep, 1, MBShapes.StepMax);
            }

            if (mode == Mode.Plant) PlantPanel(world);

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
                if (mode == Mode.Select)
                    selectEmpty = EditorGUILayout.ToggleLeft(new GUIContent("Select empty cells too",
                        "The brush selects every cell it covers, empty ones included (a volume to build in). Off: the matter only."),
                        selectEmpty);
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

            Section(selection.Count > 0 ? "EXTRUDE · the selection" : "EXTRUDE · the floor's matter");
            using (new EditorGUILayout.HorizontalScope())
            {
                const string how = " Shift + click: Extend selection (nothing is set, the selection grows a step). " +
                    "Alt + click: shifts the selection a step. The floor follows.";
                if (IconButton(Icon("extrude_up", "Extrude up — a cell above every full cell of the selection (or of the floor)." + how)))
                    Extrude(ExtrudeDirection.Up, Event.current);
                if (IconButton(Icon("extrude_down", "Extrude down — a cell below every full cell." + how)))
                    Extrude(ExtrudeDirection.Down, Event.current);
                if (IconButton(Icon("facing", "Extrude facing — one cell away from the matter behind: a wall " +
                        "thickens towards the air, a cave ceiling comes down." + how)))
                    Extrude(ExtrudeDirection.Facing, Event.current);
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
                    if (IconButton(Icon("grow", "Grow — selects the matter touching the selection by a face."))) Operate(SelectionOp.Grow);
                    if (IconButton(Icon("shrink", "Shrink (Alt + wheel down) — the selection loses its edge: a rectangle its rim, " +
                        "a line its ends, a cube its skin; a single cell stays. Full or empty cells alike."))) Operate(SelectionOp.ShrinkEdge);
                    if (IconButton(Icon("widen", "Widen (Alt + wheel up) — adds the four neighbours in the plane of " +
                        "every selected cell, empty ones included. Nothing is set.")))
                        Widen();
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
                using (new EditorGUILayout.HorizontalScope())
                {
                    if (IconButton(Icon("room", $"Room from selection — the selection seen from above is the room's footprint: " +
                        $"it rises from its lowest cells (Up) or sinks under its highest (Down), {roomFloors} floor(s) high " +
                        "(the Room shape's settings), walls one cell thick.")))
                        RoomFromSelection();
                    int sense = Segmented(roomUp ? 0 : 1,
                        Icon("up", "Up — the room rises from the selection."),
                        Icon("down", "Down — the room sinks under the selection."));
                    roomUp = sense == 0;
                    roomFloors = EditorGUILayout.IntSlider(roomFloors, 1, MBShapes.RoomFloorsMax);
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

        // THE PLANT TOOL's settings: the model (the world's foliage models), the placing mode, the brush, the spacing, the
        // steepest ground, a random yaw.
        void PlantPanel(MarchingBlocksWorld world)
        {
            Section("PLANT · Ctrl brush · Shift erase");
            var f = MBPlanting.FoliageOf(world);
            if (f == null || f.models.Count == 0)
            {
                EditorGUILayout.HelpBox(f == null ? "This world has no MarchingBlocks Foliage: import a world exported with " +
                    "foliage, or add one under the world's root and give it models." : "The foliage of this world has no model.",
                    MessageType.Info);
                return;
            }
            var names = new string[f.models.Count];
            int current = 0, chosen = MBPlanting.CurrentModel(f, plant.Model);
            for (int i = 0; i < names.Length; i++)
            {
                names[i] = string.IsNullOrEmpty(f.models[i].name) ? $"model {f.models[i].id}" : f.models[i].name;
                if (f.models[i].id == chosen) current = i;
            }
            using (new EditorGUILayout.HorizontalScope())
            {
                GUILayout.Label(Icon("plant", "The model a click or the brush plants."), GUILayout.Width(22), GUILayout.Height(22));
                int picked = EditorGUILayout.Popup(current, names);
                if (picked != current || plant.Model != f.models[picked].id) plant.Model = f.models[picked].id;
                GUILayout.Space(8);
                plant.Mode = (FoliageMode)Segmented((int)plant.Mode,
                    Icon("up", "In the air — anywhere: on the plane of the floor (Page Up / Page Down), even over nothing."),
                    Icon("plant", "Planted · free — on the ground you see, with room around it: refused on a slope, in the " +
                        "water, at an edge, under an overhang, or on another plant's footprint."),
                    Icon("widen", "Planted · overflow — on the ground you see, overflowing edges, walls and other plants as " +
                        "it likes. Only the spacing keeps plants apart."));
                GUILayout.FlexibleSpace();
            }
            plant.Radius = EditorGUILayout.Slider(new GUIContent("Brush size", "The radius of a dab and of the eraser, in cells (Alt + wheel)."),
                plant.Radius, 0.5f, 32f);
            plant.Tries = EditorGUILayout.IntSlider(new GUIContent("Density", "How many spots each dab tries (Shift + wheel)."), plant.Tries, 1, 200);
            plant.Spacing = EditorGUILayout.Slider(new GUIContent("Spacing", "No two plants closer than this, in cells — in every mode."),
                plant.Spacing, 0f, 20f);
            plant.MaxSlope = EditorGUILayout.Slider(new GUIContent("Max slope", "The planted modes refuse a ground steeper than this, in degrees."),
                plant.MaxSlope, 0f, 90f);
            plant.RandomYaw = EditorGUILayout.ToggleLeft(new GUIContent("Random rotation", "Each plant turned at random around its up axis."),
                plant.RandomYaw);
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

            if (HandleCommands(e) || HandleKeys(e) || HandleWheel(e)) return;

            var ray = HandleUtility.GUIPointToWorldRay(e.mousePosition);
            if (pasting) { ScenePaste(e, ray); return; }
            if (mode == Mode.Shape && special == SpecialShape.Room) { SceneRoom(e, ray, id); return; }
            if (mode == Mode.Shape) { SceneShape(e, ray, id); return; }
            if (mode == Mode.Rect || mode == Mode.Box) { SceneBox(e, ray, id); return; }
            if (mode == Mode.Variant) { SceneVariant(e, ray, id); return; }
            if (mode == Mode.Plant) { ScenePlant(e, ray, id); return; }
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

        // ── The Plant tool ─────────────────────────────────────────────────────────────────────────
        //
        // The rule is MBFoliage's (foliage_conformance.json); MBPlanting gives it this world (cells, water, the ground of the
        // placed tiles) and makes the gestures. Here: the strokes and the undo — ONE step a stroke.

        void ScenePlant(Event e, Ray ray, int id)
        {
            var f = plantFoliage != null ? plantFoliage : MBPlanting.FoliageOf(World);
            var asked = plantAsk;
            var full = asked != null ? (System.Func<Int3, bool>)asked.Full.Contains : AllCells().Contains;
            bool aimed = MBPlanting.AimedPoint(World, f, full, ray, plant.Mode, out var at);
            if (aimed && e.type == EventType.Repaint)
            {
                bool erasing = plantGesture != null ? plantGesture == "erase" : e.shift;
                DrawCells(new[] { new Int3(Mathf.FloorToInt(at.x), Mathf.FloorToInt(at.y - (plant.Mode == FoliageMode.Air ? 0f : 0.5f)),
                    Mathf.FloorToInt(at.z)) }, erasing ? DigColour : AddColour, 0.04f);
            }
            if (e.type == EventType.MouseDown && e.button == 0 && !e.alt)
            {
                StartPlant(ray, e.control || e.command, e.shift);
                GUIUtility.hotControl = id;
                e.Use();
            }
            else if (e.type == EventType.MouseDrag && e.button == 0 && plantGesture != null)
            {
                PlantDrag(ray);
                e.Use();
            }
            else if (e.type == EventType.MouseUp && e.button == 0)
            {
                EndPlant();
                if (GUIUtility.hotControl == id) GUIUtility.hotControl = 0;
                e.Use();
            }
            if (e.type == EventType.MouseMove || e.type == EventType.MouseDrag) SceneView.RepaintAll();
        }

        HashSet<Int3> AllCells()
        {
            var all = new HashSet<Int3>();
            foreach (var l in World.Layers()) if (l.isActiveAndEnabled) all.UnionWith(l.Cells);
            return all;
        }

        // A press: one plant, a dab of the brush (Ctrl), or erase (Shift); the stroke ends on release.
        void StartPlant(Ray ray, bool brush, bool erase)
        {
            EndPlant();
            var f = MBPlanting.FoliageOf(World);
            if (f == null)
            {
                status = "Plant — this world has no MarchingBlocks Foliage: import a world exported with foliage, or add one " +
                    "under the world's root and give it models.";
                Repaint();
                return;
            }
            plantFoliage = f;
            plantAsk = MBPlanting.Ask(World, f);
            plantGesture = erase ? "erase" : brush ? "sow" : "one";
            plantLast = null;
            Undo.IncrementCurrentGroup();
            strokeGroup = Undo.GetCurrentGroup();
            PlantDab(ray);
            if (plantGesture == "one") EndPlant();
        }

        // A drag of a brush or erase stroke dabs again once the mouse has gone PlantStep of the radius.
        void PlantDrag(Ray ray)
        {
            if ((plantGesture != "sow" && plantGesture != "erase") || plantLast == null) return;
            if (MBPlanting.AimedPoint(World, plantFoliage, plantAsk.World.Full, ray, plant.Mode, out var at)
                && Vector3.Distance(at, plantLast.Value) >= plant.Radius * PlantStep)
                PlantDab(ray);
        }

        void PlantDab(Ray ray)
        {
            var f = plantFoliage;
            PlantResult r = plantGesture == "erase" ? MBPlanting.EraseAt(World, f, ray, plant, plantAsk)
                : plantGesture == "sow" ? MBPlanting.SowAt(World, f, ray, plant, plantDraw, plantAsk)
                : MBPlanting.PlantAt(World, f, ray, plant, plantDraw, plantAsk);
            plantLast = MBPlanting.AimedPoint(World, f, plantAsk.World.Full, ray, plant.Mode, out var at) ? at : (Vector3?)null;
            if (r.Plants != null)
            {
                Undo.RecordObject(f, plantGesture == "erase" ? "Erase plants" : "Plant");
                f.plants = r.Plants;
                f.Rebuild();
            }
            status = r.Status;
            Repaint();
        }

        // The end of a stroke: everything it planted or erased is ONE undo step.
        void EndPlant()
        {
            if (plantGesture == null) return;
            plantGesture = null;
            plantAsk = null;
            plantFoliage = null;
            plantLast = null;
            Undo.CollapseUndoOperations(strokeGroup);
        }

        void Touch(BrushTool gesture, Int3 anchor, Hit hit, List<Int3> cells, bool deselect)
        {
            // The same cell under the same face twice in a row is nothing new: skip it.
            string key = $"{anchor}|{hit.Normal}";
            if (key == lastKey) return;
            lastKey = key;
            if (gesture == BrushTool.Select)
            {
                MBTools.SelectBrush(selection, cells, World.Cells.Contains, selectEmpty, deselect);
                Repaint();
                return;
            }
            var change = MBTools.Modify(gesture, cells, World.Cells.Contains);
            if (change.IsEmpty) return;
            // The stroke lock: what this stroke placed is transparent to its own ray, or dragging would
            // build a tower towards the camera instead of a skin on the surface.
            foreach (var c in change.Set) placedThisStroke.Add(c);
            Undo.RecordObjects(World.LayerObjects(), gesture == BrushTool.Add ? "Add matter" : "Dig matter");
            World.Apply(change);
        }

        // ── Special shapes ─────────────────────────────────────────────────────────────────────────
        //
        // A shape starts from a FACE, so it always aims at the matter, whatever the aim (the grid has none).

        static readonly Dictionary<string, string> ShapeErrors = new Dictionary<string, string>
        {
            { "needs_a_wall", "click a WALL, a side face of the matter." },
            { "needs_floor_or_ceiling", "click a FLOOR or a CEILING, a top or bottom face." },
            { "needs_a_floor", "click two FLOORS, the top face of the matter." },
            { "too_steep", "too steep: one cell up for each cell across at most. Pick two floors further apart." },
            { "same_cell", "the second end must be another cell." },
            { "too_far", "the two ends are too far apart." },
            { "nothing_in_front", "no wall in front within reach. Raise Reach, or Connect two walls." },
            { "too_large", "too large. Make it smaller or shorter." },
        };

        static bool WaitingForFirstEnd => connectEnds && shapeAnchor == null && special != SpecialShape.Balcony;

        static ShapeRequest RequestFor(Hit hit)
        {
            var r = new ShapeRequest { Shape = special, Profile = profile, Size = shapeSize, Length = shapeLength, Rail = rail,
                Step = stairsStep, A = hit.Cell, FaceA = hit.Normal };
            if (connectEnds && shapeAnchor != null && special != SpecialShape.Balcony)
            {
                r.Connect = true;
                r.A = shapeAnchor.Value.Cell;
                r.FaceA = shapeAnchor.Value.Normal;
                r.B = hit.Cell;
                r.FaceB = hit.Normal;
            }
            return r;
        }

        void SceneShape(Event e, Ray ray, int id)
        {
            var hit = World.RayAgainstCells(ray);
            if (shapeAnchor != null) DrawCells(new[] { shapeAnchor.Value.Cell }, SelectColour, 0.0f);
            if (hit.Touched)
            {
                if (WaitingForFirstEnd) DrawCells(new[] { hit.Cell }, SelectColour, 0.04f);
                else
                {
                    var r = MBShapes.Build(World.Cells, RequestFor(hit));
                    if (r.Error != "") DrawCells(new[] { hit.Cell }, DigColour, 0.04f);
                    else if (r.Clear.Count > 0) DrawCells(r.Clear, DigColour, 0.04f);
                    else DrawCells(r.Set, AddColour, 0.04f);
                }
            }
            if (e.type == EventType.MouseDown && e.button == 0 && !e.alt)
            {
                if (hit.Touched) ClickShape(hit);
                GUIUtility.hotControl = id;
                e.Use();
            }
            else if (e.type == EventType.MouseUp && e.button == 0 && GUIUtility.hotControl == id)
            {
                GUIUtility.hotControl = 0;
                e.Use();
            }
            if (e.type == EventType.MouseMove || e.type == EventType.MouseDrag) SceneView.RepaintAll();
        }

        // A click on the matter: the first end of a Connect, or the shape itself — ONE undo step.
        void ClickShape(Hit hit)
        {
            string name = special.ToString();
            if (WaitingForFirstEnd)
            {
                if (MBShapes.NormalFor(special, World.Cells, hit.Cell, hit.Normal, true).Equals(new Int3(0, 0, 0)))
                    status = $"{name} — {ShapeErrors[MBShapes.EndError(special, true)]}";
                else
                {
                    shapeAnchor = hit;
                    status = $"{name} — first end set. Click the second one (Esc forgets it).";
                }
                Repaint();
                return;
            }
            var r = MBShapes.Build(World.Cells, RequestFor(hit));
            if (r.Error != "")
            {
                status = $"{name} — {(ShapeErrors.TryGetValue(r.Error, out var why) ? why : r.Error)}";
                Repaint();
                return;
            }
            shapeAnchor = null;
            var change = new Change();
            foreach (var c in r.Set) change.Set.Add(c);
            foreach (var c in r.Clear) change.Clear.Add(c);
            Undo.RecordObjects(World.LayerObjects(), name);
            int n = World.Apply(change);
            status = $"{name} — {n} cell(s) changed" + (r.Repaired > 0 ? $", {r.Repaired} more so that no two cells touch by an edge only" : "") +
                ". Ctrl+Z undoes it.";
            Repaint();
            SceneView.RepaintAll();
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

        // The room is DRAWN like the rect, always flat on the floor whatever the aim: press a corner, drag,
        // release — then it rises (or sinks), ONE undo step.
        void SceneRoom(Event e, Ray ray, int id)
        {
            bool has = World.CellUnderRay(ray, out var c);
            var corner = new Int3(c.x, c.y, c.z);
            if (boxStart == null)
            {
                if (has) DrawCells(new[] { corner }, AddColour, 0.04f);
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
                var r = MBShapes.Room(World.Cells, boxStart.Value, boxEnd, roomFloors, roomUp);
                DrawCells(r.Set, AddColour, 0.04f);
                if (r.Clear.Count > 0) DrawCells(r.Clear, DigColour, 0.04f);
                if (e.type == EventType.MouseDrag) e.Use();
                if (e.type == EventType.MouseUp && e.button == 0)
                {
                    ApplyRoom(boxStart.Value, boxEnd);
                    boxStart = null;
                    GUIUtility.hotControl = 0;
                    e.Use();
                    Repaint();
                }
            }
            if (e.type == EventType.MouseMove || e.type == EventType.MouseDrag) SceneView.RepaintAll();
        }

        // The room between two corners of the floor: refused and said, or applied as ONE undo step.
        void ApplyRoom(Int3 a, Int3 b)
        {
            var r = MBShapes.Room(World.Cells, a, b, roomFloors, roomUp);
            if (r.Error != "")
            {
                status = r.Error == "too_small" ? "Room — at least 3 × 3 cells: draw a bigger rectangle."
                    : $"Room — too large: more than {MBShapes.VolumeMax} cells.";
                return;
            }
            var change = new Change();
            foreach (var c in r.Set) change.Set.Add(c);
            foreach (var c in r.Clear) change.Clear.Add(c);
            Undo.RecordObjects(World.LayerObjects(), "Room");
            World.Apply(change);
            status = $"Room — {r.Set.Count} cell(s) of shell, {r.Clear.Count} dug out" +
                (r.Repaired > 0 ? $", {r.Repaired} added where it touched the world by an edge." : ".");
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
                    gestureHeight = 0;
                    GUIUtility.hotControl = id;
                    e.Use();
                }
            }
            else
            {
                if (has) boxEnd = corner;
                var volume = MBTools.Box(boxStart.Value, boxEnd + new Int3(0, gestureHeight, 0), hollow && mode == Mode.Box);
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
            var anchor = MBTools.Anchor(BrushTool.Add, hit) + new Int3(0, pasteHeight, 0);
            var cells = new List<Int3>();
            foreach (var d in clipboard) cells.Add(anchor + d);
            DrawCells(cells, AddColour, 0.04f);
            if (e.type == EventType.MouseDown && e.button == 0 && !e.alt)
            {
                var change = MBTools.Paste(World.Cells, clipboard, anchor);
                Undo.RecordObjects(World.LayerObjects(), "Paste");
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
                case KeyCode.V: SetMode(Mode.Variant); break;
                case KeyCode.LeftBracket:
                    if (mode == Mode.Shape && special == SpecialShape.Room) roomFloors = Mathf.Max(1, roomFloors - 1);
                    else if (mode == Mode.Shape) shapeSize = Mathf.Max(1, shapeSize - 1); else brushSize = Mathf.Max(1, brushSize - 1);
                    break;
                case KeyCode.RightBracket:
                    if (mode == Mode.Shape && special == SpecialShape.Room) roomFloors = Mathf.Min(MBShapes.RoomFloorsMax, roomFloors + 1);
                    else if (mode == Mode.Shape) shapeSize = Mathf.Min(7, shapeSize + 1); else brushSize = Mathf.Min(7, brushSize + 1);
                    break;
                case KeyCode.F: FrameMatter(); break;
                case KeyCode.PageUp: ChangeFloor(1); break;
                case KeyCode.PageDown: ChangeFloor(-1); break;
                case KeyCode.Escape:
                    if (pasting || boxStart != null || shapeAnchor != null) CancelAll(); else ClearSelection();
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

        // THE MOUSE WHEEL (MBWheel, the rule of MarchingBlocks): ours only when a gesture or a modifier asks for it;
        // otherwise Unity zooms. Each notch says its value in the Scene view.
        bool HandleWheel(Event e)
        {
            if (e.type != EventType.ScrollWheel) return false;
            // Windows turns Shift + wheel into a horizontal scroll: read either axis. Unity's delta is + towards you.
            float d = Mathf.Abs(e.delta.y) >= Mathf.Abs(e.delta.x) ? e.delta.y : e.delta.x;
            // The Plant tool's own (the tool's foliage workshop): Alt the brush size, Shift its density. Ctrl stays the floor.
            if (mode == Mode.Plant && !aim.Navigating && !(e.control || e.command) && e.alt != e.shift && d != 0f)
            {
                int n = d < 0 ? 1 : -1;
                string said;
                if (e.alt) { plant.Radius = Mathf.Clamp(plant.Radius + 0.5f * n, 0.5f, 32f); said = $"Brush {plant.Radius:0.0}"; }
                else { plant.Tries = Mathf.Clamp(plant.Tries + n, 1, 200); said = $"Density {plant.Tries}"; }
                status = said;
                if (SceneView.lastActiveSceneView != null) SceneView.lastActiveSceneView.ShowNotification(new GUIContent(said), 0.6);
                e.Use();
                Repaint();
                return true;
            }
            var state = new WheelState
            {
                Navigating = aim.Navigating,
                DraggingBox = boxStart != null && (mode == Mode.Rect || mode == Mode.Box),
                TracingRoom = boxStart != null && mode == Mode.Shape && special == SpecialShape.Room,
                PastePreview = pasting,
                Ctrl = e.control || e.command, Shift = e.shift, Alt = e.alt,
                Notch = d < 0 ? 1 : d > 0 ? -1 : 0,
                Tool = mode == Mode.Add ? WheelTool.Add : mode == Mode.Dig ? WheelTool.Dig : mode == Mode.Select ? WheelTool.Select
                    : mode == Mode.Rect ? WheelTool.Rect : mode == Mode.Box ? WheelTool.Box : mode == Mode.Shape ? WheelTool.Shape
                    : WheelTool.Other,
                Shape = special,
                HasSelection = selection.Count > 0,
            };
            var action = MBWheel.Route(state);
            if (action == WheelAction.None) return false;
            WheelDo(action, state.Notch);
            e.Use();
            Repaint();
            SceneView.RepaintAll();
            return true;
        }

        void WheelDo(WheelAction action, int notch)
        {
            string said = "";
            switch (action)
            {
                case WheelAction.GestureHeight: gestureHeight += notch; said = $"Height {gestureHeight + 1}"; break;
                case WheelAction.PasteHeight: pasteHeight += notch; said = $"Paste height {pasteHeight:+0;-0;0}"; break;
                case WheelAction.RoomFloors:
                    roomFloors = Mathf.Clamp(roomFloors + notch, 1, MBShapes.RoomFloorsMax); said = $"Floors {roomFloors}"; break;
                case WheelAction.RoomRiseSink: roomUp = notch > 0; said = roomUp ? "Room rises" : "Room sinks"; break;
                case WheelAction.StairsStep: stairsStep = Mathf.Clamp(stairsStep + notch, 1, MBShapes.StepMax); said = $"Step {stairsStep}"; break;
                case WheelAction.Floor: ChangeFloor(notch); said = $"Floor {World.floor}"; break;
                case WheelAction.ExtendSelection:
                    Extrude(notch > 0 ? ExtrudeDirection.Up : ExtrudeDirection.Down, ExtrudeMode.Extend);
                    said = notch > 0 ? "Extend selection ↑" : "Extend selection ↓"; break;
                case WheelAction.WidenFlat: Widen(); said = $"Widen — {selection.Count} selected"; break;
                case WheelAction.ShrinkEdge: Operate(SelectionOp.ShrinkEdge); said = $"Shrink — {selection.Count} selected"; break;
                case WheelAction.ShapeSize: shapeSize = Mathf.Clamp(shapeSize + notch, 1, 7); said = $"Size {shapeSize}"; break;
                case WheelAction.ShapeLength:
                    shapeLength = Mathf.Clamp(shapeLength + notch, 1, MBShapes.LengthMax); said = $"Length {shapeLength}"; break;
                case WheelAction.BrushSize: brushSize = Mathf.Clamp(brushSize + notch, 1, 7); said = $"Brush {brushSize}"; break;
                case WheelAction.NextBrushShape:
                    shape = (BrushShape)(((int)shape + (notch > 0 ? 1 : 2)) % 3); said = shape.ToString(); break;
            }
            status = said;
            if (SceneView.lastActiveSceneView != null) SceneView.lastActiveSceneView.ShowNotification(new GUIContent(said), 0.6);
        }

        // F — frames all the matter of the visible layers (Unity's own F frames the selected object).
        void FrameMatter()
        {
            var b = new Bounds();
            bool any = false;
            foreach (var l in World.Layers())
            {
                if (!l.isActiveAndEnabled) continue;
                var m = l.FormatToWorld;
                foreach (var c in l.Cells)
                {
                    var p = m.MultiplyPoint3x4(new Vector3(c.x + 0.5f, c.y + 0.5f, c.z + 0.5f));
                    if (!any) { b = new Bounds(p, Vector3.zero); any = true; } else b.Encapsulate(p);
                }
            }
            if (any && SceneView.lastActiveSceneView != null) SceneView.lastActiveSceneView.Frame(b, false);
        }

        // THE VARIANT TOOL (the tileset rule, step 8): a click on a tile shows its next variant (base → 1 → … →
        // base); Shift + click gives it back to the random draw. The tile is found by MBTools.TileVertex, on the
        // face the ray meets in this layer's cells. One Undo step.
        void SceneVariant(Event e, Ray ray, int id)
        {
            var hit = World.RayAgainstCells(ray);
            if (hit.Touched) DrawCells(new[] { hit.Cell }, SelectColour, 0.04f);
            if (e.type == EventType.MouseDown && e.button == 0 && !e.alt)
            {
                var vertex = World.TileUnderRay(ray);
                if (vertex.HasValue) ClickVariant(vertex.Value, e.shift);
                else status = "Variant — point at a tile of this layer.";
                e.Use();
                Repaint();
            }
            else if (e.type == EventType.MouseMove) SceneView.RepaintAll();
        }

        void ClickVariant(Int3 vertex, bool backToDraw)
        {
            if (!World.VariantAt(vertex, out var key, out int count, out int current))
            { status = "Variant — no tile of this layer there."; return; }
            if (count == 0) { status = $"Variant — '{key}' has no variant."; return; }
            if (backToDraw)
            {
                if (!World.VariantChoices.ContainsKey(vertex)) { status = "Variant — this tile already follows the random draw."; return; }
                Undo.IncrementCurrentGroup();
                Undo.RecordObject(World, "Variant");
                World.SetVariantChoice(vertex, null);
                status = $"Variant — '{key}' is back to the random draw.";
                return;
            }
            int next = (current + 1) % (count + 1);
            // ONE click, ONE undo step — even two clicks within one frame (Unity groups by event otherwise).
            Undo.IncrementCurrentGroup();
            Undo.RecordObject(World, "Variant");
            World.SetVariantChoice(vertex, next);
            status = $"Variant — '{key}': {(next == 0 ? "the base tile" : "variant " + next)}. Shift + click gives it back to the draw.";
        }

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
            Undo.RecordObjects(World.LayerObjects(), op.ToString());
            int n = World.Apply(change);
            SetSelection(change.Selection);
            // The floor FOLLOWS the extrusion, so fill, extrude, fill… keeps going without Page Up.
            if (op == SelectionOp.ExtrudeUp) World.floor += 1;
            if (op == SelectionOp.ExtrudeDown) World.floor -= 1;
            status = $"{op} — {n} cell(s) changed, {selection.Count} selected. Ctrl+Z undoes the cells.";
            SceneView.RepaintAll();
        }

        // EXTRUDE (MBTools.Extrude): the selection, or the floor's matter without one. Shift + click extends the
        // selection, Alt + click shifts it; the floor follows the step.
        void Extrude(ExtrudeDirection direction, Event e)
        {
            var m = e != null && e.shift ? ExtrudeMode.Extend : e != null && e.alt ? ExtrudeMode.Shift : ExtrudeMode.Place;
            Extrude(direction, m);
        }

        void Extrude(ExtrudeDirection direction, ExtrudeMode m)
        {
            var change = MBTools.Extrude(World.Cells, World.floor, direction, selection, m);
            if (change.Step.Equals(default(Int3)))
            {
                status = direction == ExtrudeDirection.Facing
                    ? "Extrude facing — no cell looks at the air with matter behind it."
                    : "Extrude — nothing to extrude: select cells, or set the floor on some matter.";
                return;
            }
            // ONE undo step per click: the cells and the floor together.
            Undo.IncrementCurrentGroup();
            Undo.RecordObjects(World.LayerObjects(), "Extrude");
            int n = World.Apply(change);
            if (selection.Count > 0 || m != ExtrudeMode.Place) SetSelection(change.Selection);
            selectionOwner = World;
            World.floor += change.Step.y;
            status = $"Extrude {direction} ({m}) — {n} cell(s) set, {selection.Count} selected.";
            SceneView.RepaintAll();
        }

        // WIDEN (MBTools.WidenFlat): the selection grows a ring in its plane, empty cells included.
        void Widen()
        {
            if (selection.Count == 0) return;
            SetSelection(MBTools.WidenFlat(selection));
            SceneView.RepaintAll();
        }

        // ROOM FROM SELECTION (MBShapes.RoomFromSelection): refused and said, or applied as ONE undo step.
        void RoomFromSelection()
        {
            var r = MBShapes.RoomFromSelection(World.Cells, selection, roomFloors, roomUp, out _, out _);
            if (r.Error != "")
            {
                status = r.Error == "empty" ? "Room from selection — select the room's footprint first."
                    : r.Error == "too_small" ? "Room from selection — the footprint needs an inside: at least 3 × 3."
                    : $"Room from selection — too large: more than {MBShapes.VolumeMax} cells.";
                return;
            }
            var change = new Change();
            foreach (var c in r.Set) change.Set.Add(c);
            foreach (var c in r.Clear) change.Clear.Add(c);
            Undo.RecordObjects(World.LayerObjects(), "Room from selection");
            World.Apply(change);
            status = $"Room — {r.Set.Count} cell(s) of shell, {r.Clear.Count} dug out" +
                (r.Repaired > 0 ? $", {r.Repaired} added where it touched the world by an edge." : ".");
            SceneView.RepaintAll();
        }

        void Move(Int3 offset)
        {
            if (selection.Count == 0) return;
            var change = MBTools.Move(World.Cells, selection, offset);
            Undo.RecordObjects(World.LayerObjects(), "Move");
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
            gestureHeight = 0;
            pasteHeight = 0;
            pasting = false;
            shapeAnchor = null;
            boxStart = null;
            stroking = false;
            EndPlant();
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
