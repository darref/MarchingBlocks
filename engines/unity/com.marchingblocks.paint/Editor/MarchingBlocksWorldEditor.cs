// MarchingBlocks Paint for Unity — THE BRUSH, in the Scene view.
//
// Unity has no GridMap, so the brush is ours: a click is a ray, cut against the current floor plane
// (converted through the tileset's measured frame, like everything else). Every stroke is undoable.
//   Left click / drag      paint cells on the floor
//   Shift + left click     erase
//   Page Up / Page Down    change the floor
// Alt + drag and the right mouse button keep orbiting and flying, as usual.

using UnityEditor;
using UnityEngine;

namespace MarchingBlocks.Paint.EditorTools
{
    [CustomEditor(typeof(MarchingBlocksWorld))]
    public sealed class MarchingBlocksWorldEditor : Editor
    {
        static bool painting;

        void OnEnable() => Undo.undoRedoPerformed += RebuildAfterUndo;
        void OnDisable() => Undo.undoRedoPerformed -= RebuildAfterUndo;

        void RebuildAfterUndo()
        {
            if (target != null) ((MarchingBlocksWorld)target).Rebuild();
        }

        public override void OnInspectorGUI()
        {
            var world = (MarchingBlocksWorld)target;
            DrawDefaultInspector();
            EditorGUILayout.Space();

            var style = new GUIStyle(GUI.skin.button) { fontStyle = FontStyle.Bold, fixedHeight = 30 };
            bool now = GUILayout.Toggle(painting, painting ? "Painting — click here to stop" : "Paint cells", style);
            if (now != painting) { painting = now; SceneView.RepaintAll(); }
            EditorGUILayout.HelpBox("Left click paints on the floor, Shift + left click erases.\n" +
                                    "Page Up / Page Down change the floor. Ctrl+Z undoes a stroke.", MessageType.None);

            if (!string.IsNullOrEmpty(world.LastError))
                EditorGUILayout.HelpBox(world.LastError, MessageType.Error);
            else
                EditorGUILayout.LabelField($"{world.CellCount} cell(s) · {world.LastPlaced} tile(s)" +
                                           (world.LastMissing > 0 ? $" · {world.LastMissing} missing (red)" : ""));

            using (new EditorGUILayout.HorizontalScope())
            {
                if (GUILayout.Button("Rebuild")) world.Rebuild();
                if (GUILayout.Button("Clear cells"))
                {
                    Undo.RecordObject(world, "Clear cells");
                    world.ClearCells();
                    world.Rebuild();
                }
            }
        }

        void OnSceneGUI()
        {
            if (!painting) return;
            var world = (MarchingBlocksWorld)target;
            var e = Event.current;
            int id = GUIUtility.GetControlID(FocusType.Passive);
            if (e.type == EventType.Layout) HandleUtility.AddDefaultControl(id);

            if (e.type == EventType.KeyDown && (e.keyCode == KeyCode.PageUp || e.keyCode == KeyCode.PageDown))
            {
                Undo.RecordObject(world, "Change floor");
                world.floor += e.keyCode == KeyCode.PageUp ? 1 : -1;
                e.Use();
                Repaint();
            }

            if (!world.CellUnderRay(HandleUtility.GUIPointToWorldRay(e.mousePosition), out var cell)) return;

            bool erase = e.shift;
            var previous = Handles.matrix;
            Handles.matrix = world.CellMatrix(cell);
            Handles.color = erase ? new Color(0.9f, 0.35f, 0.25f) : new Color(0.55f, 0.82f, 0.45f);
            Handles.DrawWireCube(Vector3.zero, Vector3.one);
            Handles.matrix = previous;

            if ((e.type == EventType.MouseDown || e.type == EventType.MouseDrag) && e.button == 0 && !e.alt)
            {
                if (world.HasCell(cell) == erase)
                {
                    Undo.RecordObject(world, erase ? "Erase cell" : "Paint cell");
                    world.SetCell(cell, !erase);
                    world.Rebuild();
                }
                e.Use();
            }
            if (e.type == EventType.MouseMove) SceneView.RepaintAll();
        }
    }
}
