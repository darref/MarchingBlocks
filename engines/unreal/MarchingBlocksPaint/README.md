# MarchingBlocks Paint — Unreal

Free, open plugin that paints worlds with **MarchingBlocks tilesets** (the `.mbset` folders made by the
MarchingBlocks tool): you paint cells, the non-cubic 3D tiles follow.

> **Status: beta.** Built with Unreal 5.8.3 (Win64, editor and game modules). Older versions are not
> verified. The placement rule, the editing tools and the frame maths (`Source/MarchingBlocksPaint/.../MBCore`)
> are standard C++, proven outside Unreal against the same reference cases as the Godot and Unity plugins
> (`../core-runner`). The editor mode compiles but has not yet been driven by hand in the level viewport.

## Install

1. Copy this `MarchingBlocksPaint` folder into your project's `Plugins/` and restart the editor
   (it compiles on first launch). Built with Unreal 5.8; older versions are not verified.
2. Import `tiles.glb` from your `.mbset` folder into a content folder, **one Static Mesh per mesh**
   (Combine Meshes OFF). Keep `tileset.json` next to it on disk.

## Use

1. Place a **MarchingBlocks World** actor. In its Details panel, set **Tileset** (`tileset.json`) and
   **Tiles Folder** (where `tiles.glb` was imported).
2. Select the actor, open the **Modes** menu and pick **MarchingBlocks**. Then paint in the viewport.

| Aim (Tab) | |
|---|---|
| Grid | aims at the floor plane — Page Up / Page Down move it |
| Sculpt | aims at the matter itself — Add builds against the face you point at |
| Navigate | aims at nothing: fly as usual (right drag + W A S D, Q E). No click paints |

| Keys | |
|---|---|
| A · D · S · G · B | Add · Dig · Select · Rect (flat, on the floor) · Box (3D volume) |
| Shift | the opposite (Add ↔ Dig; adds to the selection) · Ctrl removes from it |
| [ ] | brush size 1–7 (shape and Hollow box are in the Details panel) |
| Delete · Esc | delete the selection · clear it or cancel a paste |
| Arrows | move the selection; they follow the camera. Shift + ↑ ↓ lift and lower |
| Ctrl + C · X · V | copy · cut · paste (then click to place) |

The selection operations — **Fill, Delete, Extrude ↑ ↓, Grow, Shrink, Connected, Copy, Cut, Paste** —
are buttons in the Details panel. Extruding moves the floor with the selection, so *Rect, Fill, Extrude,
Fill…* raises a room. Every change is one Ctrl+Z.

A red cube is a tile your tileset does not have. Nothing is ever filled in for you. One actor is one
layer: place several for several tilesets.

## Why it works with any importer

Unreal is left-handed, +Z up and in centimetres; glTF is right-handed, +Y up and in metres. `tiles.glb`
carries a small frame marker (`mb_frame`); the plugin measures where the importer put it and converts the
cell grid with exactly the same map. Nothing is assumed.

## The rule and the tools

The placement rule is written in `tileset.json` (`rules_text`), the tools in `Tests/tools_conformance.json`
(`rules_text`). Both files hold reference cases computed by the MarchingBlocks tool itself and shared by
the Godot, Unity and Unreal plugins.
