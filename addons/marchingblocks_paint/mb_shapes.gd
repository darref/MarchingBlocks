@tool
extends RefCounted
## THE SPECIAL SHAPES of MarchingBlocks — tunnel, well, bridge and balcony, from one or two clicks.
##
## A tunnel digs into a wall and a well into a floor or a ceiling, square to it; in one click they go
## through to the next cave (or `length` cells deep), and Connect joins two faces anywhere — slanted walls
## included — with both ends open. A bridge builds a deck across the air from a wall; a balcony puts a
## slab with its rail against a wall.
##
## Like `mb_tools.gd`, this file uses nothing from the MarchingBlocks tool: `tools_conformance.json`
## proves it gives exactly the tool's cells, case by case, and its `rules_text` says every rule in full.
## Everything is INTEGER (cell centres, squared distances): no two languages can round it differently.
##
## Cell c covers [c, c+1] on each axis. Sets are Dictionaries {Vector3i: true}.

const SHAPES := ["tunnel", "well", "bridge", "balcony"]
const PROFILES := ["round", "square", "arch"]
const LENGTH_MAX := 64
const SPAN_MAX := 128
const VOLUME_MAX := 262144

const PLANES := [
	[Vector3i(1, 0, 0), Vector3i(0, 1, 0)],
	[Vector3i(1, 0, 0), Vector3i(0, 0, 1)],
	[Vector3i(0, 1, 0), Vector3i(0, 0, 1)],
]
const HORIZONTAL := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]


## 64-bit dot product (multiplying two Vector3i would stay 32-bit).
static func _dot(a: Vector3i, b: Vector3i) -> int:
	return int(a.x) * int(b.x) + int(a.y) * int(b.y) + int(a.z) * int(b.z)


static func _sign(x: int) -> int:
	return 1 if x > 0 else (-1 if x < 0 else 0)


## The normal of a wall, ESTIMATED: a 45° wall is a staircase of cells, whose faces say ±X or ±Z, never
## the slant. Sum the exposed horizontal faces of the 3×3×3 window, snap to one of the eight directions.
static func wall_normal(cells: Dictionary, c: Vector3i, face: Vector3i) -> Vector3i:
	var sx := 0
	var sz := 0
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				var q: Vector3i = c + Vector3i(x, y, z)
				if not cells.has(q):
					continue
				for f in HORIZONTAL:
					if not cells.has(q + f):
						sx += f.x
						sz += f.z
	var m: int = maxi(absi(sx), absi(sz))
	if m == 0:
		return face
	var n := Vector3i(_sign(sx) if 2 * absi(sx) >= m else 0, 0, _sign(sz) if 2 * absi(sz) >= m else 0)
	if _dot(n, face) <= 0:
		return face
	return n


## The normal a shape keeps for a clicked face, or ZERO when that face does not suit it.
static func normal_for(shape: String, cells: Dictionary, c: Vector3i, face: Vector3i) -> Vector3i:
	if shape == "well":
		return face if face.x == 0 and face.z == 0 and face.y != 0 else Vector3i.ZERO
	if face.y != 0 or (face.x == 0 and face.z == 0):
		return Vector3i.ZERO
	return wall_normal(cells, c, face)


static func digs(shape: String) -> bool:
	return shape == "tunnel" or shape == "well"


## THE SHAPE. `p` holds: shape, a, face_a, connect, b, face_b, profile, size, length, rail.
## Returns {"set", "clear", "error", "opened", "repaired"}; error is "" or one of needs_a_wall,
## needs_floor_or_ceiling, same_cell, too_far, nothing_in_front, too_large, unknown_shape.
static func shape(cells: Dictionary, p: Dictionary) -> Dictionary:
	var what: String = p.get("shape", "")
	var out := {"set": {}, "clear": {}, "error": "", "opened": false, "repaired": 0}
	if not what in SHAPES:
		out["error"] = "unknown_shape"
		return out
	var profile: String = "deck" if what == "bridge" else String(p.get("profile", "round"))
	if not profile in PROFILES and profile != "deck":
		out["error"] = "unknown_shape"
		return out
	var h: int = clampi(int(p.get("size", 1)), 1, 7) - 1
	var length: int = clampi(int(p.get("length", 8)), 1, LENGTH_MAX)
	var rail: bool = bool(p.get("rail", false))
	var a: Vector3i = p["a"]
	var na := normal_for(what, cells, a, p["face_a"])
	if na == Vector3i.ZERO:
		out["error"] = "needs_floor_or_ceiling" if what == "well" else "needs_a_wall"
		return out
	var dig := digs(what)
	var chosen := {}
	if what == "balcony":
		chosen = _balcony(a, na, length, h, rail)
	else:
		var points: Array[Vector3i] = []
		if bool(p.get("connect", false)):
			var b: Vector3i = p["b"]
			var nb := normal_for(what, cells, b, p["face_b"])
			if nb == Vector3i.ZERO:
				out["error"] = "needs_floor_or_ceiling" if what == "well" else "needs_a_wall"
				return out
			if b == a:
				out["error"] = "same_cell"
				return out
			if _dot(b - a, b - a) > SPAN_MAX * SPAN_MAX:
				out["error"] = "too_far"
				return out
			var da: Vector3i = -na if dig else na
			var db: Vector3i = -nb if dig else nb
			var ea: Vector3i = a + da * _leg(a, da, b, h)
			var eb: Vector3i = b + db * _leg(b, db, a, h)
			for q in [a, ea, eb, b]:
				if points.is_empty() or points[points.size() - 1] != q:
					points.append(q)
		else:
			# One click: dig to the far wall cell before the first empty cell (or `length` deep); a bridge
			# runs to the first full cell in front.
			var s: Vector3i = -na if dig else na
			var end := Vector3i.ZERO
			var found := false
			for k in range(1, length + 1):
				var q: Vector3i = a + s * k
				if cells.has(q) != dig:
					end = q - s if dig and k > 1 else q
					found = true
					break
			if not found:
				if not dig:
					out["error"] = "nothing_in_front"
					return out
				end = a + s * length
			out["opened"] = found
			points = [a, end]
		chosen = _sweep(points, h, profile, rail)
	if chosen.has("error"):
		out["error"] = chosen["error"]
		return out
	var to_set := {}
	var to_clear := {}
	for q in chosen:
		if dig and cells.has(q):
			to_clear[q] = true
		elif not dig and not cells.has(q):
			to_set[q] = true
	out["repaired"] = _repair(cells, to_set, to_clear, dig)
	out["set"] = to_set
	out["clear"] = to_clear
	return out


## A leg leaves its face square to it over h + 1 cells, never beyond a third of the way to the other end.
static func _leg(start: Vector3i, dir: Vector3i, other: Vector3i, h: int) -> int:
	var want: int = h + 1
	var nn: int = _dot(dir, dir)
	var k := 0
	while k * k * nn < want * want:
		k += 1
	var w: int = _dot(dir, other - start)
	var dd: int = _dot(other - start, other - start)
	while k > 0 and w > 0 and 3 * k * w > dd:
		k -= 1
	return k


## The cells crossed by the axis from p0 to p1, one axis per step; a tie goes to the lowest axis.
static func axis_walk(p0: Vector3i, p1: Vector3i) -> Array[Vector3i]:
	var d: Vector3i = p1 - p0
	var ad := [absi(d.x), absi(d.y), absi(d.z)]
	var s := [_sign(d.x), _sign(d.y), _sign(d.z)]
	var k := [0, 0, 0]
	var c: Vector3i = p0
	var out: Array[Vector3i] = [c]
	for _step in int(ad[0]) + int(ad[1]) + int(ad[2]):
		var best := -1
		for i in 3:
			if k[i] >= ad[i]:
				continue
			if best < 0 or (2 * k[i] + 1) * ad[best] < (2 * k[best] + 1) * ad[i]:
				best = i
		c[best] += s[best]
		k[best] += 1
		out.append(c)
	return out


## The union, segment by segment, of the cells whose centre lies in the profile's prism (see rules_text).
static func _sweep(points: Array[Vector3i], h: int, profile: String, rail: bool) -> Dictionary:
	var body := {}
	var rails := {}
	var walkway := {}
	var with_rail: bool = profile == "deck" and rail and h >= 1
	var last: int = points.size() - 1
	if last < 1:
		return {"error": "same_cell"}
	for i in last:
		var p0: Vector3i = points[i]
		var p1: Vector3i = points[i + 1]
		var e0: int = h if i > 0 else 0
		var e1: int = h if i + 1 < last else 0
		var margin: int = h + 2 + maxi(e0, e1)
		var lo := Vector3i(mini(p0.x, p1.x), mini(p0.y, p1.y), mini(p0.z, p1.z)) - Vector3i.ONE * margin
		var hi := Vector3i(maxi(p0.x, p1.x), maxi(p0.y, p1.y), maxi(p0.z, p1.z)) + Vector3i.ONE * margin
		var ext: Vector3i = hi - lo + Vector3i.ONE
		if int(ext.x) * int(ext.y) * int(ext.z) > VOLUME_MAX:
			return {"error": "too_large"}
		var dv: Vector3i = p1 - p0
		var ddv: int = _dot(dv, dv)
		var u := Vector3i(1, 0, 0)
		var v := Vector3i(0, 0, 1)
		if dv.x != 0 or dv.z != 0:
			u = Vector3i(-dv.z, 0, dv.x)
			v = Vector3i(-dv.x * dv.y, dv.x * dv.x + dv.z * dv.z, -dv.y * dv.z)
		var uu: int = _dot(u, u)
		var vv: int = _dot(v, v)
		var h2: int = h * h
		for q in axis_walk(p0, p1):
			body[q] = true
		for x in range(lo.x, hi.x + 1):
			for y in range(lo.y, hi.y + 1):
				for z in range(lo.z, hi.z + 1):
					var q := Vector3i(x, y, z)
					var d: Vector3i = q - p0
					var t: int = _dot(d, dv)
					if t < 0 and (e0 == 0 or t * t > e0 * e0 * ddv):
						continue
					if t > ddv and (e1 == 0 or (t - ddv) * (t - ddv) > e1 * e1 * ddv):
						continue
					var ca: int = _dot(d, u)
					var cb: int = _dot(d, v)
					var a2: int = ca * ca
					var b2: int = cb * cb
					match profile:
						"round":
							if a2 * vv + b2 * uu <= h2 * uu * vv:
								body[q] = true
						"square":
							if a2 <= h2 * uu and b2 <= h2 * vv:
								body[q] = true
						"arch":
							if cb >= 0:
								if a2 * vv + b2 * uu <= h2 * uu * vv:
									body[q] = true
							elif a2 <= h2 * uu and b2 <= h2 * vv:
								body[q] = true
						"deck":
							if a2 <= h2 * uu and 4 * b2 <= vv:
								body[q] = true
							elif with_rail and cb > 0 and 4 * b2 <= 9 * vv and a2 <= h2 * uu:
								if a2 > (h - 1) * (h - 1) * uu:
									rails[q] = true
								else:
									walkway[q] = true
	for q in rails:
		if not walkway.has(q):
			body[q] = true
	return body


static func _balcony(a: Vector3i, n: Vector3i, depth: int, h: int, rail: bool) -> Dictionary:
	var body := {}
	var nn: int = _dot(n, n)
	var m := Vector3i(-n.z, 0, n.x)
	var with_rail: bool = rail and h >= 1 and depth >= 2
	var reach: int = depth + h + 1
	for x in range(-reach, reach + 1):
		for z in range(-reach, reach + 1):
			var d := Vector3i(x, 0, z)
			var along: int = _dot(d, n)
			var side: int = _dot(d, m)
			if along <= 0 or along * along > depth * depth * nn or side * side > h * h * nn:
				continue
			body[a + d] = true
			if with_rail:
				var inner: bool = along * along <= (depth - 1) * (depth - 1) * nn \
					and side * side <= (h - 1) * (h - 1) * nn
				if not inner:
					body[a + d + Vector3i.UP] = true
	return body


## No two cells may touch by an edge only. By rounds, order-free: every 2×2 checkerboard around a cell
## changed in the previous round; dig clears its full pair, add sets its empty pair.
static func _repair(cells: Dictionary, to_set: Dictionary, to_clear: Dictionary, dig: bool) -> int:
	var full := func(c: Vector3i) -> bool:
		return to_set.has(c) or (cells.has(c) and not to_clear.has(c))
	var front: Array = (to_clear if dig else to_set).keys()
	var added := 0
	while not front.is_empty():
		var change := {}
		for c in front:
			for plane in PLANES:
				var e1: Vector3i = plane[0]
				var e2: Vector3i = plane[1]
				for o in [c, c - e1, c - e2, c - e1 - e2]:
					var p00: Vector3i = o
					var p10: Vector3i = o + e1
					var p01: Vector3i = o + e2
					var p11: Vector3i = o + e1 + e2
					var f00: bool = full.call(p00)
					var f10: bool = full.call(p10)
					var f01: bool = full.call(p01)
					var f11: bool = full.call(p11)
					if f00 == f11 and f10 == f01 and f00 != f10:
						for q in ([p00, p11] if f00 == dig else [p10, p01]):
							change[q] = true
		front = []
		for q in change:
			if dig:
				to_clear[q] = true
			else:
				to_set[q] = true
			front.append(q)
			added += 1
		if added > VOLUME_MAX:
			break
	return added
