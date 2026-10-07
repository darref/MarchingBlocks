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
3. Click **Paint the world** in the inspector, then work in the Scene view. Ctrl+Z undoes every change.
   The inspector is the MarchingBlocks tool's panel, compact — aim, tool, brush, floor, selection — and
   only shows what the current tool uses; hover an icon for its name and key.

| Aim (Tab alternates) | |
|---|---|
| Grid | aims at the floor plane — Page Up / Page Down move it |
| Sculpt | aims at the matter itself — Add builds against the face you point at |

**Navigate · Space** is a switch, not an aim: Space (or its button, next to the aims) hands the mouse and
keys back to Unity — fly as usual (right drag + W A S D, Q E) — and no click paints. Space again comes
back to the aim you had; choosing an aim, by its button or by Tab, stops navigating too. Space and Tab are
only taken while **Paint the world** is on; Shift + Space stays Unity's.

| Keys | |
|---|---|
| A · D · S · G · B | Add · Dig · Select · Rect (flat, on the floor) · Box (3D volume, can be Hollow) |
| Shift | the opposite (Add ↔ Dig; adds to the selection) · Ctrl removes from it |
| [ ] | brush size 1–7 — sphere, cube or disc in the inspector |
| Delete · Esc | delete the selection · clear it or cancel a paste |
| Arrows | move the selection; they follow the camera. Shift + ↑ ↓ lift and lower |
| Ctrl + C · X · V | copy · cut · paste (then click to place) |
| F | frames all the matter of the visible layers |

The selection buttons — **Fill, Delete, Grow, Shrink, Widen, Connected, Move, Copy, Cut, Paste, Room from
selection** — are in the inspector, with **Extrude ↑ ↓ Facing** (on the selection, or on the floor's matter
without one). A click places a cell in front of every full cell; **Shift + click** is *Extend selection* (nothing
is placed, the selection grows a step), **Alt + click** shifts the selection a step. The floor follows, so
*Rect, Fill, Extrude, Fill…* raises a room. **Shrink** takes the selection's edge away (a rectangle loses its rim,
a line its ends); **Widen** adds a ring in its plane, empty cells included. **Room from selection** raises a room
from the selection's footprint (or sinks it under), with the Room shape's floors. The Select brush takes the matter
only, or every cell with **Select empty cells too**.

| Mouse wheel (while painting) | |
|---|---|
| alone | Unity's zoom — except during a gesture: the height of a Rect / Box being dragged, the floors of a Room being traced, the height of a paste |
| Ctrl | the floor · with Shift and the Stairs shape: the step |
| Shift / Alt, a selection and Select, Rect or Box | Extend selection ↑ ↓ / Widen (up) · Shrink (down) |
| Alt / Shift, Room shape | its floors / rises or sinks |
| Alt / Shift, another shape | its size / its length |
| Alt / Shift, Add, Dig, Select | brush size / next brush shape |

Each notch says its value in the Scene view. Navigate (Space) gives the wheel back to Unity.

A red cube is a tile your tileset does not have. Nothing is ever filled in for you.
One component is one layer, with its own tileset. **Sibling GameObjects** (children of one parent) are the
layers of one world, and their order is their priority: where two layers meet there is no wall, and each
corner takes the tiles of the higher layer. A cell belongs to one layer — painting it in one layer removes it
from the others, in the same undo step. An inactive layer leaves the world.

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

## What else a world carries

A world exported by MarchingBlocks 0.9 may also carry — and Import World sets them up:

- **Transitions between layers**: where two layers of an active pair meet, the OTHER layer's look (its
  *representative*: an image projected in a box, times a colour) is drawn over the tiles, in a soft, irregular band
  (**MarchingBlocks Transitions** on the world's root; its settings per direction: softness, reach, irregularity,
  grain, fills hollows). The geometry never changes. Unity has no pass drawn over a material: the tiles along the
  border get a second renderer with the overlay (`MarchingBlocks/Transition Overlay`).
- **Animated textures**: a material of `tiles.glb` may scroll, play frames (its images travel in
  `<set>.mbset/animation/`) or pulse its emission. Import World makes `MarchingBlocks/Lit` copies of those materials
  (in `<set>.mbset/MarchingBlocks generated/`, with an **MBAnimatedSet**); every tile gets its own phase. One clock
  for every material: Unity's time (in the Scene view, turn on *Always Refresh* to see it move).
- **Plants**: their models (`foliage/<model>.glb`) placed on the ground (**MarchingBlocks Foliage**), and swaying in
  the wind (`MarchingBlocks/Lit` copies of their materials, with the wind on). Their own skeleton animation is not
  played.
- **Water**: the sheet MarchingBlocks baked for each water layer (`water/<name>.glb`), with one of six looks
  (`MarchingBlocks/Water`: stylized, clear, reflective, lava, swamp, acid) — EXAMPLES, not an obligation: every vertex
  of the sheet carries the data (flow, kind, depth or foam in its colour), any water shader of yours can read it.
  When you paint, the water is deduced again and its SHEET REBUILT — the same triangles MarchingBlocks bakes: never
  during a stroke (the inspector says the sheet is stale), half a second after the gesture, on a worker thread, and
  only what the gesture reached is computed again. **Rebuild water** (the inspector) is always there; the automatic
  follow turns itself off when a rebuild takes more than a second, until the button is fast again.

**Render pipelines**: the shaders have a URP and a Built-in version. HDRP is not supported.

## Why it works with any importer

Unity is left-handed, glTF is right-handed, and every importer converts in its own way. `tiles.glb`
carries a small frame marker; the package measures where your importer put it and converts the cell
grid with exactly the same mapping. Nothing is assumed.

## The rule

The placement rule is written in `tileset.json` (`rules_text`), the tools in `Tests/tools_conformance.json`
(`rules_text`), the world file in `Tests/world_conformance.json` (`rule`); the editing tools, animated textures,
transitions, foliage, water and its sheet in `Tests/editing_`, `animation_`, `transitions_`, `foliage_`, `water_`
and `water_mesh_conformance.json`. All of them hold reference cases computed by the MarchingBlocks tool itself and shared with
the other plugins; `Tests/Editor/` runs them in the Test Runner (list `com.marchingblocks.paint` under
`testables` in your project manifest).
