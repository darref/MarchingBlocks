@tool
extends RefCounted
## THE PLACEMENT RULE of the MarchingBlocks tileset format — implemented from the format itself.
##
## This file reads nothing but a tileset manifest (`tileset.json`): its `table`, `corners`, `classes`,
## `context` and `copies`. It deliberately does not use any MarchingBlocks internals: it is the rule as
## any engine would implement it, and `conformance.json` (shipped next to it) proves it matches the
## reference implementation, case by case.
##
## The rule, in short (the manifest's `rules_text` says it in full):
##   1. a full cell c touches the 8 vertices c - corners[t];
##   2. at vertex v, bit t is set when cell v + corners[t] is full;
##   3. table[bits] gives [class, quarter_turns]; class -1 places nothing;
##   4. an outdoor-capable class is OUTDOOR when no empty cell among the 8 has a full cell above it,
##      from v.y + 2 up to the highest full cell of the layer; outdoor tries "<id>_outdoor" first;
##   5. the copy is picked by a spatial hash of v, so the same world always looks the same;
##   6. a missing key is returned as null — show an error marker, never fill in.

const FORMAT := "marchingblocks-tileset"
const SUPPORTED_VERSION := 1


## Checks a manifest before use. Returns "" when usable, otherwise the reason.
## A manifest from a NEWER format is refused: its rule may mean something else, and placing anyway
## would be a silent lie.
static func check(manifest: Dictionary) -> String:
	if int(manifest.get("version", 0)) > SUPPORTED_VERSION:
		return "made by a newer MarchingBlocks (format %d, this plugin reads %d): update the plugin" \
			% [int(manifest.get("version", 0)), SUPPORTED_VERSION]
	for field in ["corners", "table", "classes", "context", "copies"]:
		if not manifest.has(field):
			return "not a MarchingBlocks tileset: '%s' is missing" % field
	if (manifest["table"] as Array).size() != 256:
		return "the table must have 256 entries"
	return ""


## Every placement for a layer: [x, y, z, tile name or null, quarter_turns], sorted by vertex.
## `cells`: {Vector3i: true}. `rule`: the manifest. `tiles`: {key: [tile names]} (the manifest's `tiles`).
static func placements(cells: Dictionary, rule: Dictionary, tiles: Dictionary) -> Array:
	var corners: Array = []
	for c in rule["corners"]:
		corners.append(Vector3i(int(c[0]), int(c[1]), int(c[2])))
	var table: Array = rule["table"]
	var classes: Array = rule["classes"]
	var band: int = int(rule["context"].get("band", 2))
	var suffix: String = str(rule["context"].get("outdoor_suffix", "_outdoor"))
	var primes: Array = rule["copies"]["hash"]
	var mask: int = int(rule["copies"]["mask"])

	var top := -2147483648
	for c in cells:
		top = maxi(top, (c as Vector3i).y)
	var vertices := {}
	for c in cells:
		for t in 8:
			vertices[(c as Vector3i) - corners[t]] = true

	var out: Array = []
	for key in vertices:
		var v: Vector3i = key
		var bits := 0
		for t in 8:
			if cells.has(v + corners[t]):
				bits |= 1 << t
		var entry: Array = table[bits]
		var cls: int = int(entry[0])
		if cls < 0:
			continue
		var id: String = classes[cls]["id"]
		var chosen := ""
		if bool(classes[cls]["outdoor_possible"]) and _outdoor(cells, v, corners, top, band):
			if (tiles.get(id + suffix, []) as Array).size() > 0:
				chosen = id + suffix
		if chosen == "" and (tiles.get(id, []) as Array).size() > 0:
			chosen = id
		var tile = null
		if chosen != "":
			var copies: Array = tiles[chosen]
			var h: int = (v.x * int(primes[0])) ^ (v.y * int(primes[1])) ^ (v.z * int(primes[2]))
			tile = copies[(h & mask) % copies.size()]
		out.append([v.x, v.y, v.z, tile, int(entry[1])])
	out.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] < b[0]
		if a[1] != b[1]:
			return a[1] < b[1]
		return a[2] < b[2])
	return out


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
