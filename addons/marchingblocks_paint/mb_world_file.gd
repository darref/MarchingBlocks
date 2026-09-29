@tool
extends RefCounted
## READS A MARCHINGBLOCKS WORLD — a `<name>.mbworld/` folder made by MarchingBlocks: `world.json`, and one
## `.mbset` tileset folder per tile source, inside it.
##
## `read(world)` checks a decoded world.json against the rule below and returns
## {"layers": [{name, visible, tileset, cells: [[x, y, z], …]}]} or {"error": reason}.
## `build(world_json_path, parent)` makes one MarchingBlocksWorld node per layer, in order, under `parent`.
##
## THE RULE (the README of every .mbworld says the same, and world_conformance.json holds the cases every
## plugin must pass):
##   format   "marchingblocks-world"; version: refuse anything newer than 1.
##   layers   in order; each has a name, visible (true/false), tileset (a tileset.json path RELATIVE to
##            world.json, or null: a layer without tiles — its cells still travel), and cells: a flat
##            array of integers, x y z per cell, in FORMAT space (cell c covers [c, c+1], +Y up). The
##            same cell never appears twice.
##   Refuse the whole file, and say why, if any of these does not hold.

const World := preload("res://addons/marchingblocks_paint/mb_world.gd")

const FORMAT := "marchingblocks-world"
const VERSION := 1


static func read(world: Variant) -> Dictionary:
	if not world is Dictionary or str((world as Dictionary).get("format", "")) != FORMAT:
		return {"error": "not a MarchingBlocks world"}
	var v = world.get("version")
	if not (v is float or v is int) or int(v) != v or int(v) < 1:
		return {"error": "no valid version"}
	if int(v) > VERSION:
		return {"error": "this world is format version %d, newer than this plugin (%d): update the plugin"
			% [int(v), VERSION]}
	var layers = world.get("layers")
	if not layers is Array:
		return {"error": "layers is not an array"}
	var out: Array = []
	for layer in layers:
		if not layer is Dictionary or not layer.get("name") is String or not layer.get("visible") is bool:
			return {"error": "a layer has no name or no visibility"}
		var tileset = layer.get("tileset")
		if tileset != null and not tileset is String:
			return {"error": "layer '%s': tileset is neither a path nor null" % layer["name"]}
		var flat = layer.get("cells")
		if not flat is Array or (flat as Array).size() % 3 != 0:
			return {"error": "layer '%s': cells is not a list of x y z triples" % layer["name"]}
		var cells: Array = []
		var seen := {}
		for i in range(0, flat.size(), 3):
			var t: Array = [flat[i], flat[i + 1], flat[i + 2]]
			for n in t:
				if not (n is float or n is int) or int(n) != n:
					return {"error": "layer '%s': a cell coordinate is not an integer" % layer["name"]}
			var key := Vector3i(int(t[0]), int(t[1]), int(t[2]))
			if seen.has(key):
				return {"error": "layer '%s': the cell %s appears twice" % [layer["name"], key]}
			seen[key] = true
			cells.append([key.x, key.y, key.z])
		out.append({"name": layer["name"], "visible": layer["visible"], "tileset": tileset, "cells": cells})
	return {"layers": out}


## Reads world.json from disk. Returns what `read` returns.
static func load_world(world_json_path: String) -> Dictionary:
	if not FileAccess.file_exists(world_json_path):
		return {"error": "file not found: %s" % world_json_path}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(world_json_path)) != OK:
		return {"error": "world.json is not valid JSON (line %d)" % json.get_error_line()}
	return read(json.data)


## Builds the world under `parent`: one MarchingBlocksWorld node per layer, in order, named after it, its
## tileset set and its cells painted. Returns {"nodes": [Node3D…], "without_tiles": [names]} or {"error"}.
## ⚠ The nodes are NOT given an owner here: the caller does, so that it can wrap the whole import in ONE
## undo action.
static func build(world_json_path: String, parent: Node) -> Dictionary:
	var w := load_world(world_json_path)
	if w.has("error"):
		return w
	var base := world_json_path.get_base_dir()
	var nodes: Array = []
	var without: Array = []
	for layer in w["layers"]:
		var node := Node3D.new()
		node.set_script(World)
		node.name = _node_name(str(layer["name"]))
		parent.add_child(node, true)
		node.visible = layer["visible"]
		if layer["tileset"] == null:
			without.append(layer["name"])
		else:
			node.tileset = base.path_join(str(layer["tileset"])).simplify_path()
		var cells: Array = []
		for c in layer["cells"]:
			cells.append(Vector3i(int(c[0]), int(c[1]), int(c[2])))
		node.apply_cells(cells, [])
		nodes.append(node)
	return {"nodes": nodes, "without_tiles": without}


## A node name Godot accepts: no . : @ / " %.
static func _node_name(s: String) -> String:
	var n := s.validate_node_name().strip_edges()
	return n if n != "" else "Layer"
