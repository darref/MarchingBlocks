// The special shapes THROUGH THE SCENE-VIEW EDITOR: MarchingBlocksWorldEditor.ClickShape is what a click on
// the matter calls, with the Hit the Scene view's ray found. Driven here with the Hit a click on a wall would
// give, it proves the wiring the conformance cases cannot see: the cells reach the world, ONE Undo brings
// them back, a Connect keeps its first end until the second, Escape forgets it, and a refused face changes
// nothing. The expected cells are worked out by hand (the same as tools_conformance.json's straight tunnel):
// a round tunnel of size 2 through a wall three cells thick is a cross of 5 cells on each of 3 slices.
// The editor's state is private and static: it is read and set through reflection.

using System;
using System.Collections.Generic;
using System.Reflection;
using NUnit.Framework;
using UnityEditor;
using UnityEngine;
using MarchingBlocks.Paint;
using MarchingBlocks.Paint.EditorTools;

public sealed class ShapeEditorTests
{
    const BindingFlags Static = BindingFlags.Static | BindingFlags.NonPublic;
    static readonly Type T = typeof(MarchingBlocksWorldEditor);

    static void Set(string field, object value) => T.GetField(field, Static).SetValue(null, value);
    static object Get(string field) => T.GetField(field, Static).GetValue(null);
    static object ModeShape => Enum.Parse(T.GetNestedType("Mode", BindingFlags.NonPublic), "Shape");

    GameObject go;
    MarchingBlocksWorld world;
    Editor editor;
    readonly Dictionary<string, object> saved = new Dictionary<string, object>();
    static readonly string[] Fields = { "mode", "special", "connectEnds", "profile", "shapeSize", "shapeLength", "rail", "shapeAnchor", "editing" };

    [SetUp]
    public void SetUp()
    {
        foreach (var f in Fields) saved[f] = Get(f);
        go = new GameObject("shape test");
        world = go.AddComponent<MarchingBlocksWorld>();
        // The wall: x = 0..2, y = 0..6, z = -4..4, air on both sides.
        var cells = new List<Vector3Int>();
        for (int x = 0; x <= 2; x++)
            for (int y = 0; y <= 6; y++)
                for (int z = -4; z <= 4; z++)
                    cells.Add(new Vector3Int(x, y, z));
        world.SetCells(cells);
        editor = Editor.CreateEditor(world);
        Set("editing", true);
        Set("mode", ModeShape);
        Set("special", SpecialShape.Tunnel);
        Set("connectEnds", false);
        Set("profile", ShapeProfile.Round);
        Set("shapeSize", 2);
        Set("shapeLength", 8);
        Set("shapeAnchor", null);
        Undo.ClearAll();
    }

    [TearDown]
    public void TearDown()
    {
        UnityEngine.Object.DestroyImmediate(editor);
        UnityEngine.Object.DestroyImmediate(go);
        foreach (var f in Fields) Set(f, saved[f]);
    }

    void Click(Int3 cell, Int3 normal) =>
        T.GetMethod("ClickShape", BindingFlags.Instance | BindingFlags.NonPublic)
            .Invoke(editor, new object[] { new Hit { Touched = true, Cell = cell, Normal = normal } });

    static readonly Int3 West = new Int3(-1, 0, 0);
    static readonly Int3 East = new Int3(1, 0, 0);

    [Test]
    public void AStraightTunnelDigsTheCrossAndOneUndoBringsTheWallBack()
    {
        int full = world.CellCount;
        Click(new Int3(0, 3, 0), West);
        Assert.AreEqual(full - 15, world.CellCount, "a round tunnel of size 2 through 3 cells: 5 × 3");
        Assert.IsFalse(world.Cells.Contains(new Int3(2, 3, 0)), "it goes right through");
        Assert.IsFalse(world.Cells.Contains(new Int3(1, 4, 0)), "the cross, up");
        Assert.IsTrue(world.Cells.Contains(new Int3(1, 4, 1)), "not the corners");
        Undo.PerformUndo();
        Assert.AreEqual(full, world.CellCount, "ONE Undo brings the whole wall back");
    }

    [Test]
    public void ConnectKeepsItsFirstEndAndJoinsTheTwoFaces()
    {
        int full = world.CellCount;
        Set("connectEnds", true);
        Click(new Int3(0, 3, 0), West);
        Assert.IsNotNull(Get("shapeAnchor"), "the first click sets the first end");
        Assert.AreEqual(full, world.CellCount, "and changes nothing");
        Click(new Int3(2, 3, 0), East);
        Assert.IsNull(Get("shapeAnchor"), "the second click uses it up");
        Assert.AreEqual(full - 15, world.CellCount, "two faces face to face: the same cross");
    }

    [Test]
    public void EscapeForgetsTheFirstEnd()
    {
        Set("connectEnds", true);
        Click(new Int3(0, 3, 0), West);
        Assert.IsNotNull(Get("shapeAnchor"));
        var e = new Event { type = EventType.KeyDown, keyCode = KeyCode.Escape, mousePosition = new Vector2(10, 10) };
        // HandleKeys, the keys SceneGUI hands on: SceneGUI itself asks for a control id, which only a GUI pass allows.
        var used = (bool)T.GetMethod("HandleKeys", BindingFlags.Instance | BindingFlags.NonPublic).Invoke(editor, new object[] { e });
        Assert.IsTrue(used, "Escape is taken");
        Assert.IsNull(Get("shapeAnchor"), "Escape forgets the first end");
    }

    [Test]
    public void AWellOnAWallIsRefusedAndChangesNothing()
    {
        int full = world.CellCount;
        Set("special", SpecialShape.Well);
        Click(new Int3(0, 3, 0), West);
        Assert.AreEqual(full, world.CellCount, "straight: refused");
        Set("connectEnds", true);
        Click(new Int3(0, 3, 0), West);
        Assert.IsNull(Get("shapeAnchor"), "Connect: a wall is not a first end for a well");
    }
}
