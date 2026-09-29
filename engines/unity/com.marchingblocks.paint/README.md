# MarchingBlocks Paint — Unity

Free, open package that paints worlds with **MarchingBlocks tilesets** (the `.mbset` folders made by the
MarchingBlocks tool): you paint cells, the non-cubic 3D tiles follow.

## Install

1. A glTF importer: **glTFast** (`com.unity.cloud.gltfast`, Package Manager → Unity Registry) or UnityGLTF.
   Textured tiles also need Unity's built-in *Image Conversion* and *Unity Web Request Texture*
   modules: this package declares them, so they are enabled when you install it.
2. This package: Package Manager → **+** → *Add package from disk…* → `package.json`
   (or copy the folder into your project's `Packages/`).

## Use

1. Drop a `.mbset` folder into `Assets/`. `tiles.glb` is imported by your glTF importer.
2. Create an empty GameObject, add **MarchingBlocks World**, and assign **Tileset** (`tileset.json`)
   and **Tiles** (the imported `tiles.glb`).
3. Click **Edit the world** in the inspector, then work in the Scene view. Ctrl+Z undoes every change.

| Aim (Tab) | |
|---|---|
| Grid | aims at the floor plane — Page Up / Page Down move it |
| Sculpt | aims at the matter itself — Add builds against the face you point at |
| Navigate | aims at nothing: fly as usual in Unity (right drag + W A S D, Q E). No click paints |

| Keys | |
|---|---|
| A · D · S · G · B | Add · Dig · Select · Rect (flat, on the floor) · Box (3D volume, can be Hollow) |
| Shift | the opposite (Add ↔ Dig; adds to the selection) · Ctrl removes from it |
| [ ] | brush size 1–7 — sphere, cube or disc in the inspector |
| Delete · Esc | delete the selection · clear it or cancel a paste |
| Arrows | move the selection; they follow the camera. Shift + ↑ ↓ lift and lower |
| Ctrl + C · X · V | copy · cut · paste (then click to place) |

The selection buttons — **Fill, Delete, Extrude ↑ ↓, Grow, Shrink, Connected, Move, Copy, Cut, Paste** —
are in the inspector. Extruding moves the floor with the selection, so *Rect, Fill, Extrude, Fill…*
raises a room.

A red cube is a tile your tileset does not have. Nothing is ever filled in for you.
One component is one layer: stack several GameObjects for several tilesets.

## Import a painted world

MarchingBlocks exports a whole painted world as a `<name>.mbworld/` folder: `world.json` (the layers, in
order, with their visibility and cells) and one `.mbset` tileset folder per tile source, inside it.

1. Copy the whole `.mbworld` folder into `Assets/`. Every `tiles.glb` inside is imported by your glTF
   importer.
2. **Tools > MarchingBlocks > Import World...** and pick its `world.json`.

You get one GameObject named after the world, with one child per layer, in order, each with a
**MarchingBlocks World** component already set up. A hidden layer arrives inactive. A layer without
tiles arrives with its cells and no tiles, and the Console names it. The whole import is one Ctrl+Z.
A world made by a newer MarchingBlocks is refused: update the package.

## Why it works with any importer

Unity is left-handed, glTF is right-handed, and every importer converts in its own way. `tiles.glb`
carries a small frame marker; the package measures where your importer put it and converts the cell
grid with exactly the same mapping. Nothing is assumed.

## The rule

The placement rule is written in `tileset.json` (`rules_text`), the tools in `Tests/tools_conformance.json`
(`rules_text`), the world file in `Tests/world_conformance.json` (`rule`). All three hold reference cases computed by the MarchingBlocks tool itself and shared with the
other plugins; `Tests/Editor/` runs them in the Test Runner (list `com.marchingblocks.paint` under
`testables` in your project manifest).
