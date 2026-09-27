# MarchingBlocks Paint — Godot

Free, open plugin that paints worlds with **MarchingBlocks tilesets** (the `.mbset` folders made by the
MarchingBlocks tool): you paint cells, the non-cubic 3D tiles follow.

1. Copy `addons/marchingblocks_paint` into your project and enable **MarchingBlocks Paint**.
2. Add a **MarchingBlocksWorld** node, and set its **Tileset** to the `tileset.json` of a `.mbset` folder.
3. Select its **Cells** child and paint with the GridMap editor. The tiles follow.

A red cube is a tile your tileset does not have. Nothing is ever filled in for you.

One node is one layer. The placement rule is written in `tileset.json` (`rules_text`), and
`conformance.json` proves this plugin follows it exactly.
