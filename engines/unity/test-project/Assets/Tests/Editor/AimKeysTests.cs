// The aim keys THROUGH THE SCENE-VIEW EDITOR, not only through AimState: real Events are handed to
// MarchingBlocksWorldEditor.SceneGUI, the body of OnSceneGUI, as the Scene view would. Checks what AimCheck cannot see:
//   - Space and Tab are USED when they act, so Unity's other handlers never get them;
//   - they act only while "Paint the world" is on for the selected world, and are left alone otherwise;
//   - a held Space (Unity repeats KeyDown) toggles once; Shift + Space stays Unity's;
//   - while navigating, a click neither paints nor is taken from Unity.
// The editor's state is private and static: it is read and set through reflection.

using System.Reflection;
using NUnit.Framework;
using UnityEditor;
using UnityEngine;
using MarchingBlocks.Paint;
using MarchingBlocks.Paint.EditorTools;

public sealed class AimKeysTests
{
    const BindingFlags Static = BindingFlags.Static | BindingFlags.NonPublic;
    static readonly System.Type T = typeof(MarchingBlocksWorldEditor);

    static AimState Aim { get => (AimState)T.GetField("aim", Static).GetValue(null); set => T.GetField("aim", Static).SetValue(null, value); }
    static bool Editing { get => (bool)T.GetField("editing", Static).GetValue(null); set => T.GetField("editing", Static).SetValue(null, value); }
    static void ReleaseSpace() => T.GetField("spaceHeld", Static).SetValue(null, false);

    GameObject go;
    MarchingBlocksWorld world;
    Editor editor;
    bool wasEditing;
    AimState wasAim;

    [SetUp]
    public void SetUp()
    {
        wasEditing = Editing;
        wasAim = Aim;
        go = new GameObject("aim keys test");
        world = go.AddComponent<MarchingBlocksWorld>();
        world.ClearCells();
        editor = Editor.CreateEditor(world);
        Assert.IsInstanceOf<MarchingBlocksWorldEditor>(editor);
        ReleaseSpace();
    }

    [TearDown]
    public void TearDown()
    {
        Object.DestroyImmediate(editor);
        Object.DestroyImmediate(go);
        Editing = wasEditing;
        Aim = wasAim;
        ReleaseSpace();
    }

    // Hands one event to OnSceneGUI; returns whether the editor used it.
    bool Send(EventType type, KeyCode key = KeyCode.None, EventModifiers mods = EventModifiers.None)
    {
        var e = new Event { type = type, keyCode = key, modifiers = mods, button = 0, mousePosition = new Vector2(10, 10) };
        T.GetMethod("SceneGUI", BindingFlags.Instance | BindingFlags.NonPublic).Invoke(editor, new object[] { e });
        return e.type == EventType.Used;
    }

    bool Press(KeyCode key, EventModifiers mods = EventModifiers.None) => Send(EventType.KeyDown, key, mods);
    void Release(KeyCode key) => Send(EventType.KeyUp, key);

    static void AssertState(BrushAim aim, bool navigating, string what)
    {
        Assert.AreEqual(aim, Aim.Aim, what + ": the aim");
        Assert.AreEqual(navigating, Aim.Navigating, what + ": navigating");
    }

    [Test]
    public void SpaceTogglesNavigationKeepsTheAimAndIsUsed()
    {
        Editing = true;
        Aim = new AimState(BrushAim.Sculpt, false);
        Assert.IsTrue(Press(KeyCode.Space), "Space must be used when it toggles");
        AssertState(BrushAim.Sculpt, true, "Space");
        Assert.IsTrue(Press(KeyCode.Space), "a held Space's repeat is swallowed");
        AssertState(BrushAim.Sculpt, true, "a held Space toggles once");
        Release(KeyCode.Space);
        // Checked while navigating: otherwise the event goes on to the brush, which needs a real GUI pass.
        Assert.IsFalse(Press(KeyCode.Space, EventModifiers.Shift), "Shift + Space stays Unity's");
        AssertState(BrushAim.Sculpt, true, "Shift + Space");
        Assert.IsTrue(Press(KeyCode.Space));
        AssertState(BrushAim.Sculpt, false, "Space again comes back to the SAME aim");
    }

    [Test]
    public void TabAlternatesTwoAimsAndLeavesNavigation()
    {
        Editing = true;
        Aim = new AimState(BrushAim.Grid, false);
        Assert.IsTrue(Press(KeyCode.Tab));
        AssertState(BrushAim.Sculpt, false, "Tab from Grid");
        Assert.IsTrue(Press(KeyCode.Tab));
        AssertState(BrushAim.Grid, false, "Tab from Sculpt never navigates");
        Press(KeyCode.Space);
        Release(KeyCode.Space);
        AssertState(BrushAim.Grid, true, "Space");
        Assert.IsTrue(Press(KeyCode.Tab), "Tab is ours while navigating");
        AssertState(BrushAim.Sculpt, false, "Tab while navigating chooses the other aim and stops navigating");
    }

    [Test]
    public void OutsideTheToolsSpaceAndTabAreLeftAlone()
    {
        Editing = false;
        Aim = new AimState(BrushAim.Grid, false);
        Assert.IsFalse(Press(KeyCode.Space), "Space must reach Unity when the tools are off");
        Assert.IsFalse(Press(KeyCode.Tab), "Tab too");
        AssertState(BrushAim.Grid, false, "tools off");
    }

    [Test]
    public void WhileNavigatingAClickNeitherPaintsNorIsTaken()
    {
        Editing = true;
        Aim = new AimState(BrushAim.Grid, true);
        Assert.IsFalse(Send(EventType.MouseDown), "the click is Unity's while navigating");
        Assert.IsFalse(Send(EventType.MouseUp));
        Assert.IsFalse(Press(KeyCode.A), "the fly keys choose no tool");
        Assert.IsFalse(Press(KeyCode.D));
        Assert.AreEqual(0, world.CellCount, "no click paints while navigating");
    }
}
