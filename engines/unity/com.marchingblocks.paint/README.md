# MarchingBlocks Paint — Unity

Free, open package that paints worlds with **MarchingBlocks tilesets** (the `.mbset` folders made by the
MarchingBlocks tool): you paint cells, the non-cubic 3D tiles follow.

## Install

1. A glTF importer: **glTFast** (`com.unity.cloud.gltfast`, Package Manager → Unity Registry) or UnityGLTF.
2. This package: Package Manager → **+** → *Add package from disk…* → `package.json`
   (or copy the folder into your project's `Packages/`).

## Use

1. Drop a `.mbset` folder into `Assets/`. `tiles.glb` is imported by your glTF importer.
2. Create an empty GameObject, add **MarchingBlocks World**, and assign **Tileset** (`tileset.json`)
   and **Tiles** (the imported `tiles.glb`).
3. Click **Paint cells** in the inspector, then paint in the Scene view: left click paints on the
   floor, Shift + left click erases, Page Up / Page Down change the floor. Ctrl+Z undoes.

A red cube is a tile your tileset does not have. Nothing is ever filled in for you.
One component is one layer: stack several GameObjects for several tilesets.

## Why it works with any importer

Unity is left-handed, glTF is right-handed, and every importer converts in its own way. `tiles.glb`
carries a small frame marker; the package measures where your importer put it and converts the cell
grid with exactly the same mapping. Nothing is assumed.

## The rule

The placement rule is written in `tileset.json` (`rules_text`). `Tests/conformance.json` holds the
reference cases shared by the Godot, Unity and Unreal plugins; `Tests/Editor/ConformanceTests.cs` runs
them in the Test Runner (list `com.marchingblocks.paint` under `testables` in your project manifest).
