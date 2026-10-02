# MarchingBlocks Paint — Godot

Free, open plugin that paints worlds with **MarchingBlocks tilesets** (the `.mbset` folders made by the
MarchingBlocks tool): you paint cells, the non-cubic 3D tiles follow.

1. Copy `addons/marchingblocks_paint` into your project and enable **MarchingBlocks Paint**.
2. Add a **MarchingBlocksWorld** node, and set its **Tileset** to the `tileset.json` of a `.mbset` folder.
3. Select the node: a MarchingBlocks toolbar appears above the 3D viewport. Paint in the viewport.
   The toolbar is the MarchingBlocks tool's panel in one row — aim, tool, brush, floor, selection — and
   only shows what the current tool uses; hover an icon for its name and key.
   Every change is one Ctrl+Z. (Selecting its **Cells** child gives Godot's own GridMap editor instead —
   both paint the same cells.)

**A whole painted world** (every layer, its cells and its tiles) comes as a `.mbworld` folder: copy it into
your project, then **Project → Tools → Import MarchingBlocks world...** and pick its `world.json`. One
MarchingBlocksWorld node per layer is built, in order, under a new node — one Ctrl+Z. Sibling
MarchingBlocksWorld nodes are the layers of ONE world, and their order is their priority: where two layers meet
there is no wall, and each corner takes the tiles of the higher layer. A cell belongs to one layer — painting it
in one layer removes it from the others, in the same Ctrl+Z. A hidden layer leaves the world. A layer exported
without tiles arrives with its cells and no tiles, and the Output panel says so. `world_conformance.json`
holds the reading rule's reference cases.

| Aim (Tab switches) | |
|---|---|
| Grid | aims at the floor plane — Page Up / Page Down move it |
| Sculpt | aims at the matter itself — Add builds against the face you point at |
| **Navigate (Space)** | a switch, not an aim: fly as usual (right drag + W A S D, Q E), no click paints. Space again — or an aim — brings you back, the aim unchanged |

| Keys | |
|---|---|
| A · D · S · G · B | Add · Dig · Select · Rect (flat, on the floor) · Box (3D volume, can be Hollow) |
| Shift | the opposite (Add ↔ Dig; adds to the selection) · Ctrl removes from it |
| [ ] | brush size 1–7 — sphere, cube or disc in the toolbar |
| Delete · Escape | delete the selection · clear it or cancel a paste |
| Arrows | move the selection; they follow the camera. Shift + ↑ ↓ lift and lower |
| Ctrl + C · X · V | copy · cut · paste (then click to place) |

The **Selection** menu holds Fill, Delete, Extrude ↑ ↓, Grow, Shrink, Connected, Copy, Cut, Paste.
Extruding moves the floor with the selection, so *Rect, Fill, Extrude, Fill…* raises a room.

A red cube is a tile your tileset does not have. Nothing is ever filled in for you. One node is one
layer. The placement rule is written in `tileset.json` (`rules_text`), the tools in
`tools_conformance.json` (`rules_text`); `conformance.json` and `tools_conformance.json` prove this plugin
follows both exactly — the same reference cases as the Unity and Unreal plugins.
