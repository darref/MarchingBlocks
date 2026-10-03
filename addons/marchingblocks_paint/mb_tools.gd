@tool
extends RefCounted
## THE WORLD EDITING TOOLS of MarchingBlocks, as pure functions.
##
## Aim at the matter, a brush with a size and a shape, a selection (paint, rectangle or box — hollow or
## not), and what you do with it: fill, delete, extrude, grow, shrink, connected, move, copy, paste.
##
## Every function reads cells and RETURNS what changes; nothing is applied here — the editor applies the
## result with Godot's undo. Like `mb_rule.gd`, this file uses nothing from the MarchingBlocks tool:
## `tools_conformance.json` (shipped next to it, computed by the tool itself) proves it behaves exactly
## like the tool, case by case. Its `rules_text` says every rule in full.
##
## Cell c covers [c, c+1] on each axis. Sets are Dictionaries {Vector3i: true}.

const FACES: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

## A box of more cells returns empty: two corners far apart by accident (a ray lost on the horizon)
## would otherwise freeze the editor.
const BOX_VOLUME_MAX := 1048576

const TOOLS := ["add", "dig", "select"]
const SHAPES := ["sphere", "cube", "disc"]
const OPERATIONS := ["delete", "extrude_up", "extrude_down", "grow", "shrink", "connected", "fill"]


## THE RAY AGAINST THE MATTER — cell by cell (Amanatides & Woo). `is_full(c: Vector3i) -> bool`.
## Returns {"hit": bool, "cell": Vector3i, "normal": Vector3i}; the normal is the face it entered by.
## Aim at the CELLS, never the rendered tiles: those are sculpted and overflow their cell. The start cell
## is skipped; on a tie, the lowest axis goes first. `ignore` is walked through as empty — what the
## current Add stroke placed, or dragging would build a tower towards the camera.
static func ray(is_full: Callable, origin: Vector3, direction: Vector3, reach: float,
		ignore: Dictionary = {}) -> Dictionary:
	var none := {"hit": false, "cell": Vector3i.ZERO, "normal": Vector3i.ZERO}
	if direction.length_squared() < 1e-12:
		return none
	direction = direction.normalized()
	var c := Vector3i(floori(origin.x), floori(origin.y), floori(origin.z))
	var step := Vector3i.ZERO
	var t_max := Vector3(INF, INF, INF)
	var t_delta := Vector3(INF, INF, INF)
	for axis in 3:
		if absf(direction[axis]) < 1e-12:
			continue
		step[axis] = 1 if direction[axis] > 0.0 else -1
		var edge: float = float(c[axis] + 1) if direction[axis] > 0.0 else float(c[axis])
		t_max[axis] = (edge - origin[axis]) / direction[axis]
		t_delta[axis] = absf(1.0 / direction[axis])
	while true:
		var axis := 0
		if t_max.y < t_max[axis]:
			axis = 1
		if t_max.z < t_max[axis]:
			axis = 2
		if t_max[axis] > reach:
			return none
		c[axis] += step[axis]
		t_max[axis] += t_delta[axis]
		if not ignore.has(c) and is_full.call(c):
			var n := Vector3i.ZERO
			n[axis] = -step[axis]
			return {"hit": true, "cell": c, "normal": n}
	return none


## Where the brush stands. "add" places AGAINST the face it aims at; the other tools act ON the cell.
static func anchor(tool: String, hit: Dictionary) -> Vector3i:
	var c: Vector3i = hit["cell"]
	if tool == "add" and hit["hit"]:
		return c + (hit["normal"] as Vector3i)
	return c


## The cells of a brush, sorted. Size 1 is one cell; the radius is size - 1. "disc" is the sphere cut by
## the plane across the normal — it dresses or digs a wall without thickening it; horizontal without one.
static func brush(centre: Vector3i, normal: Vector3i, size: int, shape: String) -> Array[Vector3i]:
	var r: int = maxi(0, size - 1)
	var n: Vector3i = normal if normal != Vector3i.ZERO else Vector3i.UP
	var cells: Array[Vector3i] = []
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			for z in range(-r, r + 1):
				var d := Vector3i(x, y, z)
				var inside := true
				if shape == "sphere":
					inside = d.length_squared() <= r * r
				elif shape == "disc":
					inside = d.length_squared() <= r * r and d.x * n.x + d.y * n.y + d.z * n.z == 0
				if inside:
					cells.append(centre + d)
	cells.sort()
	return cells


## What a brush stroke changes: "add" only sets empty cells, "dig" only clears full ones, "select"
## changes no cell. Returns {"set", "clear"}.
static func modify(tool: String, targets: Array, is_full: Callable) -> Dictionary:
	var set_ := {}
	var clear := {}
	for c in targets:
		var full: bool = is_full.call(c)
		if tool == "add" and not full:
			set_[c] = true
		elif tool == "dig" and full:
			clear[c] = true
	return {"set": set_, "clear": clear}


## The operations on a selection. Returns {"set", "clear", "selection"} — the selection AFTER.
## A selection may hold EMPTY cells: a box drawn in the air is a room not built yet. Operations that
## need matter filter it.
static func operate(cells: Dictionary, selection: Dictionary, op: String) -> Dictionary:
	var set_ := {}
	var clear := {}
	var after := {}
	match op:
		"delete":
			for c in selection:
				if cells.has(c):
					clear[c] = true
		"extrude_up", "extrude_down":
			var step := Vector3i.UP if op == "extrude_up" else Vector3i.DOWN
			for c in selection:
				var p: Vector3i = c + step
				if not cells.has(p):
					set_[p] = true
				after[p] = true
		"grow":
			for c in selection:
				if cells.has(c):
					after[c] = true
				for f in FACES:
					if cells.has(c + f):
						after[c + f] = true
		"shrink":
			for c in selection:
				if not cells.has(c):
					continue
				var inner := true
				for f in FACES:
					if not selection.has(c + f):
						inner = false
						break
				if inner:
					after[c] = true
		"fill":
			# The selection stays: fill, extrude, fill is how a room goes up.
			for c in selection:
				after[c] = true
				if not cells.has(c):
					set_[c] = true
		"connected":
			var stack: Array[Vector3i] = []
			for c in selection:
				if cells.has(c) and not after.has(c):
					after[c] = true
					stack.append(c)
			while not stack.is_empty():
				var c: Vector3i = stack.pop_back()
				for f in FACES:
					var v: Vector3i = c + f
					if cells.has(v) and not after.has(v):
						after[v] = true
						stack.append(v)
	return {"set": set_, "clear": clear, "selection": after}


## Every cell between two corners, bounds included, full or empty. `hollow` keeps the skin only (a room);
## a box thinner than three cells on an axis has no inside and stays solid. More than BOX_VOLUME_MAX
## cells: empty — say so to the user.
static func box(a: Vector3i, b: Vector3i, hollow := false) -> Dictionary:
	var lo := Vector3i(mini(a.x, b.x), mini(a.y, b.y), mini(a.z, b.z))
	var hi := Vector3i(maxi(a.x, b.x), maxi(a.y, b.y), maxi(a.z, b.z))
	var extent: Vector3i = hi - lo + Vector3i.ONE
	var cells := {}
	if extent.x * extent.y * extent.z > BOX_VOLUME_MAX:
		return cells
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				if hollow and x > lo.x and x < hi.x and y > lo.y and y < hi.y and z > lo.z and z < hi.z:
					continue
				cells[Vector3i(x, y, z)] = true
	return cells


## Moves the selected matter. A move that overlaps itself neither clears what it just set nor sets what
## stays; matter already at the destination stays (a move merges, never overwrites).
static func move(cells: Dictionary, selection: Dictionary, offset: Vector3i) -> Dictionary:
	var source := {}
	for c in selection:
		if cells.has(c):
			source[c] = true
	var destination := {}
	for c in source:
		destination[(c as Vector3i) + offset] = true
	var clear := {}
	for c in source:
		if not destination.has(c):
			clear[c] = true
	var set_ := {}
	for c in destination:
		if not cells.has(c) or clear.has(c):
			set_[c] = true
	return {"set": set_, "clear": clear, "selection": destination}


## The selected matter, relative to the middle of its bottom face, sorted — where it lands when pasted
## against the face you aim at. FLOOR of the half-sum: integer division truncates towards zero and would
## shift a paste by one cell in negative coordinates.
static func copy(cells: Dictionary, selection: Dictionary) -> Array[Vector3i]:
	var full: Array[Vector3i] = []
	for c in selection:
		if cells.has(c):
			full.append(c)
	if full.is_empty():
		return full
	var lo: Vector3i = full[0]
	var hi: Vector3i = full[0]
	for c in full:
		lo = Vector3i(mini(lo.x, c.x), mini(lo.y, c.y), mini(lo.z, c.z))
		hi = Vector3i(maxi(hi.x, c.x), maxi(hi.y, c.y), maxi(hi.z, c.z))
	var origin := Vector3i(floori((lo.x + hi.x) / 2.0), lo.y, floori((lo.z + hi.z) / 2.0))
	var relative: Array[Vector3i] = []
	for c in full:
		relative.append(c - origin)
	relative.sort()
	return relative


## Pastes a clipboard at an anchor. Only empty cells are set; the selection becomes the pasted cells.
static func paste(cells: Dictionary, clipboard: Array, at: Vector3i) -> Dictionary:
	var set_ := {}
	var after := {}
	for d in clipboard:
		var c: Vector3i = at + (d as Vector3i)
		after[c] = true
		if not cells.has(c):
			set_[c] = true
	return {"set": set_, "clear": {}, "selection": after}
