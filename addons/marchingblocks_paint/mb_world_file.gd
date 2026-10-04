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
##            same cell never appears twice. Optionally variant_weights (key -> array of INTEGERS) and
##            variant_choices (a flat array, x y z c per vertex, never the same vertex twice) — the
##            tileset rule, step 8. `read` returns the choices as [[x, y, z, c], …] sorted by vertex.
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
		var weights_in = layer.get("variant_weights", {})
		if not weights_in is Dictionary:
			return {"error": "layer '%s': variant_weights is not an object" % layer["name"]}
		var weights := {}
		for k in weights_in:
			var w = weights_in[k]
			if not w is Array or (w as Array).any(func(x): return not (x is float or x is int) or int(x) != x):
				return {"error": "layer '%s': the weights of '%s' are not integers" % [layer["name"], k]}
			weights[str(k)] = (w as Array).map(func(x): return int(x))
		var flat_choices = layer.get("variant_choices", [])
		if not flat_choices is Array or (flat_choices as Array).size() % 4 != 0:
			return {"error": "layer '%s': variant_choices is not a list of x y z c" % layer["name"]}
		var chosen := {}
		for i in range(0, flat_choices.size(), 4):
			for n in [flat_choices[i], flat_choices[i + 1], flat_choices[i + 2], flat_choices[i + 3]]:
				if not (n is float or n is int) or int(n) != n:
					return {"error": "layer '%s': a variant choice is not made of integers" % layer["name"]}
			var vtx := Vector3i(int(flat_choices[i]), int(flat_choices[i + 1]), int(flat_choices[i + 2]))
			if chosen.has(vtx):
				return {"error": "layer '%s': the vertex %s is chosen twice" % [layer["name"], vtx]}
			chosen[vtx] = int(flat_choices[i + 3])
		var vertices: Array = chosen.keys()
		vertices.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			return a.x < b.x or (a.x == b.x and (a.y < b.y or (a.y == b.y and a.z < b.z))))
		var choices: Array = []
		for vtx in vertices:
			choices.append([vtx.x, vtx.y, vtx.z, chosen[vtx]])
		out.append({"name": layer["name"], "visible": layer["visible"], "tileset": tileset, "cells": cells,
			"variant_weights": weights, "variant_choices": choices})
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
		# The cells exactly as the file gives them — NOT apply_cells, which would take them from the layers
		# already imported: a cell found in two layers belongs to the first (the tileset rule, step 7).
		node._build_children()
		var grid := node.get_node("Cells") as GridMap
		for c in layer["cells"]:
			grid.set_cell_item(Vector3i(int(c[0]), int(c[1]), int(c[2])), 0)
		node.variant_weights = layer["variant_weights"]
		var choices := {}
		for c in layer["variant_choices"]:
			choices[Vector3i(int(c[0]), int(c[1]), int(c[2]))] = int(c[3])
		node.variant_choices = choices
		nodes.append(node)
	# The layers are ONE world: each is rebuilt once every layer holds its cells.
	for node in nodes:
		node.rebuild()
	return {"nodes": nodes, "without_tiles": without}


## A node name Godot accepts: no . : @ / " %.
static func _node_name(s: String) -> String:
	var n := s.validate_node_name().strip_edges()
	return n if n != "" else "Layer"
