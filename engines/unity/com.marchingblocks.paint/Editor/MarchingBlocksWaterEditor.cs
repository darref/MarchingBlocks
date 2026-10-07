// MarchingBlocks Paint for Unity — the inspector of MarchingBlocks Water: the layers, whether the sheet is up to date
// (rebuilt after each gesture, stale during one, stale when the automatic follow cut itself), and REBUILD WATER, always there.

using UnityEditor;
using UnityEngine;

namespace MarchingBlocks.Paint.EditorTools
{
    [CustomEditor(typeof(MarchingBlocksWater))]
    public sealed class MarchingBlocksWaterEditor : Editor
    {
        public override void OnInspectorGUI()
        {
            DrawDefaultInspector();
            var w = (MarchingBlocksWater)target;
            var f = w.Follow;
            EditorGUILayout.Space();
            string state;
            var type = MessageType.Info;
            if (w.Rebuilding) state = "Rebuilding the water…";
            else if (f.Stale && f.CutOff)
            {
                state = $"The water sheet is STALE. The last rebuild took {f.LastSeconds:F1} s: the automatic follow is off " +
                    "until Rebuild water is fast again.";
                type = MessageType.Warning;
            }
            else if (f.Stale && !f.Enabled) { state = "The water sheet is STALE (automatic follow off)."; type = MessageType.Warning; }
            else if (f.Stale) state = "The water sheet is STALE: it is rebuilt half a second after the gesture.";
            else if (f.LastSeconds < 0) state = "The baked sheet is shown (as exported by MarchingBlocks).";
            else state = "The water sheet is up to date. " + w.LastRebuildReport;
            EditorGUILayout.HelpBox(state, type);
            if (GUILayout.Button(new GUIContent("Rebuild water", "Deduce the water again and rebuild every sheet now.")))
            {
                w.RebuildWater();
                SceneView.RepaintAll();
            }
            if (w.Rebuilding || f.Stale) Repaint();
        }
    }
}
