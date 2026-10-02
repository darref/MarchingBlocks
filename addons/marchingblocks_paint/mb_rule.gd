@tool
extends RefCounted
## THE PLACEMENT RULE of the MarchingBlocks tileset format — implemented from the format itself.
##
## This file reads nothing but a tileset manifest (`tileset.json`): its `table`, `corners`, `classes`
## and `context`. It deliberately does not use any MarchingBlocks internals: it is the rule as
## any engine would implement it, and `conformance.json` (shipped next to it) proves it matches the
## reference implementation, case by case.
##
## The rule, in short (the manifest's `rules_text` says it in full):
##   1. a full cell c touches the 8 vertices c - corners[t];
##   2. at vertex v, bit t is set when cell v + corners[t] is full;
##   3. table[bits] gives [class, quarter_turns]; class -1 places nothing;
##   4. an outdoor-capable class is OUTDOOR when no empty cell among the 8 has a full cell above it,
##      from v.y + 2 up to the highest full cell of the layer; outdoor tries "<id>_outdoor" first;
##   5. each key has exactly one tile, tiles[key];
##   6. a missing key is returned as null — show an error marker, never fill in;
##   7. layers: steps 1-4 read the UNION of every visible layer of a world (a cell in two layers belongs
##      to the first); a vertex is placed by the first layer, in priority order, owning one of its 8 cells,
##      with that layer's tiles.

const FORMAT := "marchingblocks-tileset"
const SUPPORTED_VERSION := 1


## Checks a manifest before use. Returns "" when usable, otherwise the reason.
## A manifest from a NEWER format is refused: its rule may mean something else, and placing anyway
## would be a silent lie.
static func check(manifest: Dictionary) -> String:
	if int(manifest.get("version", 0)) > SUPPORTED_VERSION:
		return "made by a newer MarchingBlocks (format %d, this plugin reads %d): update the plugin" \
			% [int(manifest.get("version", 0)), SUPPORTED_VERSION]
	for field in ["corners", "table", "classes", "context"]:
		if not manifest.has(field):
			return "not a MarchingBlocks tileset: '%s' is missing" % field
	if (manifest["table"] as Array).size() != 256:
		return "the table must have 256 entries"
	for key in manifest.get("tiles", {}):
		if not manifest["tiles"][key] is String:
			return "tile '%s' must be one tile name (one tile per key)" % key
	return ""


## Every placement for a layer alone: [x, y, z, tile name or null, quarter_turns], sorted by vertex.
## `cells`: {Vector3i: true}. `rule`: the manifest. `tiles`: {key: tile name} (the manifest's `tiles`).
static func placements(cells: Dictionary, rule: Dictionary, tiles: Dictionary) -> Array:
	return placements_layered([{"cells": cells, "tiles": tiles, "visible": true}], rule)[0]


## Every placement of a world of LAYERS (step 7), one list per layer, in the same order. `layers`, in
## priority order (the first is the highest): [{"cells": {Vector3i: true}, "tiles": {key: name},
## "visible": bool}]. Every layer must use a tileset made with the same rule (`rule`).
static func placements_layered(layers: Array, rule: Dictionary) -> Array:
	var union := {}   # cell -> index of the layer that owns it
	for i in layers.size():
		if layers[i].get("visible", true):
			for c in layers[i]["cells"]:
				if not union.has(c):
					union[c] = i
	var outs: Array = []
	for i in layers.size():
		outs.append([])
	var corners: Array = []
	for c in rule["corners"]:
		corners.append(Vector3i(int(c[0]), int(c[1]), int(c[2])))
	var table: Array = rule["table"]
	var classes: Array = rule["classes"]
	var band: int = int(rule["context"].get("band", 2))
	var suffix: String = str(rule["context"].get("outdoor_suffix", "_outdoor"))

	var top := -2147483648
	for c in union:
		top = maxi(top, (c as Vector3i).y)
	var vertices := {}
	for c in union:
		for t in 8:
			vertices[(c as Vector3i) - corners[t]] = true

	for key in vertices:
		var v: Vector3i = key
		var bits := 0
		var owner := -1
		for t in 8:
			if union.has(v + corners[t]):
				bits |= 1 << t
				var l: int = union[v + corners[t]]
				if owner < 0 or l < owner:
					owner = l
		var tiles: Dictionary = layers[owner]["tiles"]
		var entry: Array = table[bits]
		var cls: int = int(entry[0])
		if cls < 0:
			continue
		var id: String = classes[cls]["id"]
		var chosen := ""
		if bool(classes[cls]["outdoor_possible"]) and _outdoor(union, v, corners, top, band):
			if str(tiles.get(id + suffix, "")) != "":
				chosen = id + suffix
		if chosen == "" and str(tiles.get(id, "")) != "":
			chosen = id
		var tile = null
		if chosen != "":
			tile = str(tiles[chosen])
		outs[owner].append([v.x, v.y, v.z, tile, int(entry[1])])
	for out in outs:
		(out as Array).sort_custom(func(a: Array, b: Array) -> bool:
			if a[0] != b[0]:
				return a[0] < b[0]
			if a[1] != b[1]:
				return a[1] < b[1]
			return a[2] < b[2])
	return outs


## Outdoor: every EMPTY cell among the 8 around v has nothing full above the vertex's two-cell band.
static func _outdoor(cells: Dictionary, v: Vector3i, corners: Array, top: int, band: int) -> bool:
	for t in 8:
		var e: Vector3i = v + corners[t]
		if cells.has(e):
			continue
		for y in range(v.y + band, top + 1):
			if cells.has(Vector3i(e.x, y, e.z)):
				return false
	return true
