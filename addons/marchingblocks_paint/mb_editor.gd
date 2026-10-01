@tool
extends Node
## THE WORLD EDITING TOOLS in the 3D viewport — aiming, strokes, boxes, paste, keys and preview.
##
## The rules live in `mb_tools.gd` (pure, proven by `tools_conformance.json`); this node only aims,
## previews and applies. It knows nothing of the editor: `plugin.gd` hands it the edited world, the
## camera's events and an undo object — Godot's EditorUndoRedoManager in the editor, a plain UndoRedo in
## tests (both have create_action / add_do_method / add_undo_method / commit_action).
##
##   AIM      grid — the floor plane (Page Up / Page Down move it) · sculpt — the matter itself
##            Tab switches the two
##   NAVIGATE a switch, not an aim — Space turns it on and off: the viewport flies as usual (right drag +
##            W A S D, Q E) and no click paints. The aim is kept, and comes back as it was.
##   TOOLS    add (A) · dig (D) · select (S) · rect (G) · box (B)      Shift does the opposite
##   BRUSH    size 1–7 ([ and ]), sphere / cube / disc
##   SHAPES   tunnel · well · bridge · balcony (`mb_shapes.gd`), always aimed at the matter: Straight is one
##            click square out of a face; Connect is two clicks, two faces anywhere (Escape forgets the first)
##   KEYS     Delete · Escape · arrows move the selection (they follow the camera; Shift + up / down
##            lift) · Ctrl+C / Ctrl+X / Ctrl+V
##
## The right mouse button is never taken: Godot's free look works in every aim.

signal changed

const Tools := preload("res://addons/marchingblocks_paint/mb_tools.gd")
const Shapes := preload("res://addons/marchingblocks_paint/mb_shapes.gd")

const AIMS := ["grid", "sculpt"]
const MODES := ["add", "dig", "select", "rect", "box", "shape"]
const REACH := 2000.0
const MAX_DRAWN := 4000
const ADD_COLOUR := Color(0.55, 0.82, 0.45, 0.35)
const DIG_COLOUR := Color(0.9, 0.35, 0.25, 0.35)
const SELECT_COLOUR := Color(0.95, 0.8, 0.3, 0.3)
const SELECTION_COLOUR := Color(0.35, 0.7, 1.0, 0.22)

var world: Node3D:
	set(value):
		if world == value:
			return
		_forget_drawing()
		world = value
		selection = {}
		_cancel()
var undo: Object
var aim := "grid"
## Space — flying through the world; nothing is aimed, nothing paints. Choosing an aim turns it off.
var navigating := false
var mode := "add"
var brush_size := 1
var shape := "sphere"
var hollow := false
## The special shape (mode "shape"): which one, one click or two, and its settings.
var special := "tunnel"
var connect_ends := false
var profile := "round"
var shape_size := 2
var shape_length := 8
var rail := true
## The first end of a Connect: {"cell", "face"}, empty otherwise.
var shape_anchor := {}
var selection := {}
var clipboard: Array[Vector3i] = []
var pasting := false
## What the last operation did, for the toolbar.
var status := ""

var _stroking := false
var _stroke_inverse := false
var _stroke_control := false
var _last_key := ""
var _placed := {}
var _stroke_set := {}
var _stroke_clear := {}
var _box_start: Variant = null
var _box_end := Vector3i.ZERO
var _preview: MultiMeshInstance3D
var _selection_view: MultiMeshInstance3D
var _last_mouse := Vector2(-1, -1)


## Feeds one viewport event. Returns true when the event is taken (the editor must not act on it).
func input(camera: Camera3D, event: InputEvent) -> bool:
	if world == null or not is_instance_valid(world):
		return false
	var key := event as InputEventKey
	if navigating:
		# Navigating takes nothing but Space (to stop) and Tab (to pick an aim): the mouse and the other keys
		# fly the viewport, as usual. Not while the right button flies — Space is not ours then.
		if key != null and key.pressed and not key.echo and key.keycode in [KEY_SPACE, KEY_TAB] \
				and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			if key.keycode == KEY_TAB:
				set_aim(AIMS[(AIMS.find(aim) + 1) % AIMS.size()])
			else:
				set_navigating(false)
			return true
		_show_preview([], ADD_COLOUR)
		return false
	if key != null:
		return _key(camera, key)
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		return _left_button(camera, button)
	var motion := event as InputEventMouseMotion
	if motion != null:
		_last_mouse = motion.position
		hover(camera, motion.position, motion.shift_pressed)
		return _stroking or _box_start != null
	return false


## Choosing an aim also stops navigating: you pick an aim to aim.
func set_aim(value: String) -> void:
	aim = value
	navigating = false
	_cancel()
	changed.emit()


func set_navigating(on: bool) -> void:
	navigating = on
	_cancel()
	if on:
		_show_preview([], ADD_COLOUR)
	changed.emit()


func set_mode(value: String) -> void:
	mode = value
	_cancel()
	changed.emit()


## Picks a special shape: the mode becomes "shape".
func set_special(value: String) -> void:
	special = value
	mode = "shape"
	_cancel()
	changed.emit()


func set_connect(on: bool) -> void:
	connect_ends = on
	_cancel()
	changed.emit()


# ── Aiming ──────────────────────────────────────────────────────────────────────────────────────────

## {"hit", "cell", "normal"}: the matter in sculpt (when the ray meets it), the floor otherwise; {} when
## neither is under the mouse.
func aimed(camera: Camera3D, position: Vector2, for_add: bool) -> Dictionary:
	var origin := camera.project_ray_origin(position)
	var direction := camera.project_ray_normal(position)
	if aim == "sculpt":
		var cells: Dictionary = world.cells()
		var r: Dictionary = Tools.ray(func(c: Vector3i) -> bool: return cells.has(c),
			world.world_to_cells(origin), world.world_direction_to_cells(direction), REACH,
			_placed if for_add else {})
		if r["hit"]:
			return r
	var c = world.cell_under_ray(origin, direction)
	if c == null:
		return {}
	return {"hit": false, "cell": c, "normal": Vector3i.ZERO}


## The rect ignores the aim: it always lies flat on the floor — the gesture that draws a room's floor.
func _corner(camera: Camera3D, position: Vector2) -> Variant:
	if mode == "rect":
		return world.cell_under_ray(camera.project_ray_origin(position), camera.project_ray_normal(position))
	var p := aimed(camera, position, false)
	return null if p.is_empty() else p["cell"]


func _gesture(inverse: bool) -> String:
	match mode:
		"add":
			return "dig" if inverse else "add"
		"dig":
			return "add" if inverse else "dig"
	return "select"


# ── Hover and strokes ───────────────────────────────────────────────────────────────────────────────

func hover(camera: Camera3D, position: Vector2, shift := false) -> void:
	if mode == "shape":
		_hover_shape(camera, position)
		return
	if pasting:
		var p := aimed(camera, position, true)
		var cells: Array = []
		if not p.is_empty():
			var at := Tools.anchor("add", p)
			for d in clipboard:
				cells.append(at + d)
		_show_preview(cells, ADD_COLOUR)
		return
	if mode == "rect" or mode == "box":
		var corner = _corner(camera, position)
		if _box_start != null:
			if corner != null:
				_box_end = corner
			_show_preview(Tools.box(_box_start, _box_end, hollow and mode == "box").keys(),
				DIG_COLOUR if _stroke_control else SELECT_COLOUR)
		else:
			_show_preview([] if corner == null else [corner], SELECT_COLOUR)
		return
	var g := _gesture(_stroke_inverse if _stroking else shift)
	var p := aimed(camera, position, g == "add")
	if p.is_empty():
		_show_preview([], ADD_COLOUR)
		return
	var at := Tools.anchor(g, p)
	var cells := Tools.brush(at, p["normal"], brush_size, shape)
	_show_preview(cells, {"add": ADD_COLOUR, "dig": DIG_COLOUR}.get(g, SELECT_COLOUR))
	if _stroking:
		_touch(g, at, p["normal"], cells)


func _touch(g: String, at: Vector3i, normal: Vector3i, cells: Array) -> void:
	# The same cell under the same face twice in a row is nothing new.
	var key := "%s|%s" % [at, normal]
	if key == _last_key:
		return
	_last_key = key
	if g == "select":
		var full: Dictionary = world.cells()
		for c in cells:
			if _stroke_control:
				selection.erase(c)
			elif full.has(c):
				selection[c] = true
		_draw_selection()
		return
	var full: Dictionary = world.cells()
	var change: Dictionary = Tools.modify(g, cells, func(c: Vector3i) -> bool: return full.has(c))
	if change["set"].is_empty() and change["clear"].is_empty():
		return
	# The stroke lock: what this stroke placed is transparent to its own ray, or dragging would build a
	# tower towards the camera instead of a skin on the surface.
	_placed.merge(change["set"])
	_stroke_set.merge(change["set"])
	_stroke_clear.merge(change["clear"])
	world.apply_cells(change["set"].keys(), change["clear"].keys())


func _left_button(camera: Camera3D, b: InputEventMouseButton) -> bool:
	if b.alt_pressed:
		return false
	if mode == "shape":
		if b.pressed:
			click_shape(camera, b.position)
		return true
	if b.pressed:
		if pasting:
			var p := aimed(camera, b.position, true)
			if not p.is_empty():
				var change: Dictionary = Tools.paste(world.cells(), clipboard, Tools.anchor("add", p))
				_commit("Paste", change["set"], {})
				_set_selection(change["selection"])
				pasting = false
			return true
		if mode == "rect" or mode == "box":
			var corner = _corner(camera, b.position)
			if corner != null:
				_box_start = corner
				_box_end = corner
				_stroke_control = b.ctrl_pressed
				_stroke_inverse = b.shift_pressed
			return true
		_stroking = true
		_stroke_inverse = b.shift_pressed
		_stroke_control = b.ctrl_pressed
		_last_key = ""
		_placed = {}
		_stroke_set = {}
		_stroke_clear = {}
		if mode == "select" and not b.shift_pressed and not b.ctrl_pressed:
			selection = {}
		hover(camera, b.position, b.shift_pressed)
		return true
	# Released.
	if _box_start != null:
		var volume: Dictionary = Tools.box(_box_start, _box_end, hollow and mode == "box")
		if volume.is_empty():
			status = "Box too large — more than %d cells. Draw a smaller one." % Tools.BOX_VOLUME_MAX
		else:
			if not _stroke_inverse and not _stroke_control:
				selection = {}
			for c in volume:
				if _stroke_control:
					selection.erase(c)
				else:
					selection[c] = true
		_box_start = null
		_draw_selection()
		changed.emit()
		return true
	if _stroking:
		_stroking = false
		# The stroke is already on screen: the action is recorded WITHOUT running it again.
		if not _stroke_set.is_empty() or not _stroke_clear.is_empty():
			_record("MarchingBlocks stroke", _stroke_set, _stroke_clear, false)
		changed.emit()
		return true
	return false


# ── Special shapes ──────────────────────────────────────────────────────────────────────────────────
#
# A shape starts from a FACE, so it always aims at the matter, whatever the aim (the grid has no face).

const SHAPE_NAMES := {"tunnel": "Tunnel", "well": "Well", "bridge": "Bridge", "balcony": "Balcony"}
const SHAPE_ERRORS := {
	"needs_a_wall": "click a WALL, a side face of the matter.",
	"needs_floor_or_ceiling": "click a FLOOR or a CEILING, a top or bottom face.",
	"same_cell": "the second end must be another cell.",
	"too_far": "the two ends are too far apart.",
	"nothing_in_front": "no wall in front within reach. Raise the length, or Connect two walls.",
	"too_large": "too large. Make it smaller or shorter.",
	"unknown_shape": "unknown shape.",
}


func _matter_hit(camera: Camera3D, position: Vector2) -> Dictionary:
	var cells: Dictionary = world.cells()
	var r: Dictionary = Tools.ray(func(c: Vector3i) -> bool: return cells.has(c),
		world.world_to_cells(camera.project_ray_origin(position)),
		world.world_direction_to_cells(camera.project_ray_normal(position)), REACH)
	return r if r["hit"] else {}


func _waiting_for_first_end() -> bool:
	return connect_ends and shape_anchor.is_empty() and special != "balcony"


## What the shape would do with this face: the first end of a Connect is already set, or it is one click.
func shape_request(hit: Dictionary) -> Dictionary:
	var p := {"shape": special, "profile": profile, "size": shape_size, "length": shape_length, "rail": rail,
		"connect": false, "a": hit["cell"], "face_a": hit["normal"]}
	if connect_ends and not shape_anchor.is_empty() and special != "balcony":
		p["connect"] = true
		p["a"] = shape_anchor["cell"]
		p["face_a"] = shape_anchor["face"]
		p["b"] = hit["cell"]
		p["face_b"] = hit["normal"]
	return p


func _hover_shape(camera: Camera3D, position: Vector2) -> void:
	var hit := _matter_hit(camera, position)
	var anchor_cells: Array = [] if shape_anchor.is_empty() else [shape_anchor["cell"]]
	if hit.is_empty():
		_show_preview(anchor_cells, SELECT_COLOUR)
		return
	if _waiting_for_first_end():
		_show_preview([hit["cell"]], SELECT_COLOUR)
		return
	var r: Dictionary = Shapes.shape(world.cells(), shape_request(hit))
	if r["error"] != "":
		_show_preview([hit["cell"]], DIG_COLOUR)
	elif not r["clear"].is_empty():
		_show_preview(r["clear"].keys() + anchor_cells, DIG_COLOUR)
	else:
		_show_preview(r["set"].keys() + anchor_cells, ADD_COLOUR)


## A click: the first end of a Connect, or the shape itself — ONE undo step.
func click_shape(camera: Camera3D, position: Vector2) -> void:
	var hit := _matter_hit(camera, position)
	if hit.is_empty():
		return
	var name: String = SHAPE_NAMES.get(special, special)
	if _waiting_for_first_end():
		if Shapes.normal_for(special, world.cells(), hit["cell"], hit["normal"]) == Vector3i.ZERO:
			var why: String = "needs_floor_or_ceiling" if special == "well" else "needs_a_wall"
			status = "%s — %s" % [name, SHAPE_ERRORS[why]]
		else:
			shape_anchor = {"cell": hit["cell"], "face": hit["normal"]}
			status = "%s — first end set. Click the second one (Escape forgets it)." % name
		changed.emit()
		hover(camera, position)
		return
	var r: Dictionary = Shapes.shape(world.cells(), shape_request(hit))
	if r["error"] != "":
		status = "%s — %s" % [name, SHAPE_ERRORS.get(r["error"], r["error"])]
		changed.emit()
		return
	shape_anchor = {}
	_commit("MarchingBlocks " + name, r["set"], r["clear"])
	var n: int = r["set"].size() + r["clear"].size()
	var more: String = (", %d more so that no two cells touch by an edge only" % r["repaired"]) if r["repaired"] > 0 else ""
	status = "%s — %d cell(s) changed%s. Ctrl+Z undoes it." % [name, n, more]
	changed.emit()
	hover(camera, position)


# ── Operations (the toolbar calls these too) ────────────────────────────────────────────────────────

func operate(op: String) -> int:
	if selection.is_empty():
		status = "Nothing selected. Drag a Rect (G) on the floor, a Box (B), or paint with Select (S)."
		changed.emit()
		return 0
	var r: Dictionary = Tools.operate(world.cells(), selection, op)
	var step := 1 if op == "extrude_up" else (-1 if op == "extrude_down" else 0)
	_commit(op.capitalize(), r["set"], r["clear"], step)
	_set_selection(r["selection"])
	status = "%s — %d cell(s) changed, %d selected. Ctrl+Z undoes the cells." % [op.capitalize(),
		r["set"].size() + r["clear"].size(), selection.size()]
	changed.emit()
	return r["set"].size() + r["clear"].size()


func move_selection(offset: Vector3i) -> void:
	if selection.is_empty():
		return
	var r: Dictionary = Tools.move(world.cells(), selection, offset)
	_commit("Move", r["set"], r["clear"])
	_set_selection(r["selection"])


func copy_selection() -> void:
	clipboard = Tools.copy(world.cells(), selection)
	status = "Nothing to copy: the selection holds no matter." if clipboard.is_empty() \
		else "Copied %d cell(s)." % clipboard.size()
	changed.emit()


func cut_selection() -> void:
	copy_selection()
	if not clipboard.is_empty():
		operate("delete")


func start_paste() -> void:
	pasting = not clipboard.is_empty()
	status = "Pasting — click in the viewport (Escape cancels)." if pasting else "The clipboard is empty."
	changed.emit()


## Erases every cell of the world, in ONE undoable action.
func clear_world() -> void:
	if world == null or world.cells().is_empty():
		status = "The world is already empty."
		changed.emit()
		return
	var n: int = world.cells().size()
	_commit("Clear cells", {}, world.cells())
	status = "%d cell(s) cleared. Ctrl+Z brings them back." % n
	changed.emit()


func clear_selection() -> void:
	_set_selection({})
	pasting = false
	changed.emit()


## One undo step that RUNS the change. `floor_step` moves the floor with an extrusion, in the same step:
## so rect, fill, extrude, fill… keeps going without Page Up, and Ctrl+Z brings the floor back too.
func _commit(name: String, set_cells: Dictionary, clear_cells: Dictionary, floor_step := 0) -> void:
	_record(name, set_cells, clear_cells, true, floor_step)


func _record(name: String, set_cells: Dictionary, clear_cells: Dictionary, execute: bool, floor_step := 0) -> void:
	var s: Array = set_cells.keys()
	var c: Array = clear_cells.keys()
	if s.is_empty() and c.is_empty() and floor_step == 0:
		return
	if undo == null:
		if execute:
			world.apply_cells(s, c)
			world.floor_y += floor_step
		return
	undo.create_action(name)
	# Undoing apply(set, clear) is apply(clear, set): the set cells were empty, the cleared ones full.
	_call_in_undo(true, s, c)
	_call_in_undo(false, c, s)
	if floor_step != 0:
		undo.add_do_property(world, "floor_y", world.floor_y + floor_step)
		undo.add_undo_property(world, "floor_y", world.floor_y)
	undo.commit_action(execute)


## ⚠ THE TWO UNDO SYSTEMS DO NOT SPEAK ALIKE: a plain UndoRedo takes a Callable, the editor's
## EditorUndoRedoManager takes (object, method, arguments…) — so that it can tell which scene it belongs to.
func _call_in_undo(doing: bool, set_cells: Array, clear_cells: Array) -> void:
	if undo is UndoRedo:
		var call: Callable = Callable(world, "apply_cells").bind(set_cells, clear_cells)
		if doing:
			undo.add_do_method(call)
		else:
			undo.add_undo_method(call)
	elif doing:
		undo.add_do_method(world, "apply_cells", set_cells, clear_cells)
	else:
		undo.add_undo_method(world, "apply_cells", set_cells, clear_cells)


# ── Keys ────────────────────────────────────────────────────────────────────────────────────────────

func _key(camera: Camera3D, k: InputEventKey) -> bool:
	if not k.pressed:
		return false
	# Never while flying: right drag + W A S D is Godot's free look.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return false
	if k.ctrl_pressed or k.meta_pressed:
		match k.keycode:
			KEY_C:
				copy_selection()
			KEY_X:
				cut_selection()
			KEY_V:
				start_paste()
			_:
				return false
		return true
	if k.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		if selection.is_empty():
			return false
		move_selection(arrow_offset(camera, k.keycode, k.shift_pressed))
		return true
	if k.echo:
		return false
	match k.keycode:
		KEY_A:
			set_mode("add")
		KEY_D:
			set_mode("dig")
		KEY_S:
			set_mode("select")
		KEY_G:
			set_mode("rect")
		KEY_B:
			set_mode("box")
		KEY_TAB:
			set_aim(AIMS[(AIMS.find(aim) + 1) % AIMS.size()])
		KEY_SPACE:
			set_navigating(true)
		KEY_BRACKETLEFT:
			if mode == "shape":
				shape_size = maxi(1, shape_size - 1)
			else:
				brush_size = maxi(1, brush_size - 1)
			changed.emit()
		KEY_BRACKETRIGHT:
			if mode == "shape":
				shape_size = mini(7, shape_size + 1)
			else:
				brush_size = mini(7, brush_size + 1)
			changed.emit()
		KEY_PAGEUP, KEY_PAGEDOWN:
			var step := 1 if k.keycode == KEY_PAGEUP else -1
			if undo != null:
				undo.create_action("Change floor")
				undo.add_do_property(world, "floor_y", world.floor_y + step)
				undo.add_undo_property(world, "floor_y", world.floor_y)
				undo.commit_action()
			else:
				world.floor_y += step
			changed.emit()
		KEY_DELETE:
			operate("delete")
		KEY_ESCAPE:
			if pasting or _box_start != null or not shape_anchor.is_empty():
				_cancel()
			else:
				clear_selection()
		_:
			return false
	if _last_mouse.x >= 0.0:
		hover(camera, _last_mouse, k.shift_pressed)
	return true


## The arrows FOLLOW THE CAMERA: "up" moves away from you along the cell axis (X or Z) closest to where
## the camera looks; Shift + up / down lift and lower.
func arrow_offset(camera: Camera3D, keycode: int, shift: bool) -> Vector3i:
	if shift and keycode in [KEY_UP, KEY_DOWN]:
		return Vector3i(0, 1 if keycode == KEY_UP else -1, 0)
	var forward: Vector3 = world.world_direction_to_cells(-camera.global_transform.basis.z)
	var right: Vector3 = world.world_direction_to_cells(camera.global_transform.basis.x)
	var axis := func(v: Vector3) -> Vector3i:
		return Vector3i(1 if v.x >= 0.0 else -1, 0, 0) if absf(v.x) >= absf(v.z) \
			else Vector3i(0, 0, 1 if v.z >= 0.0 else -1)
	var f: Vector3i = axis.call(forward)
	var r: Vector3i = axis.call(right)
	match keycode:
		KEY_UP:
			return f
		KEY_DOWN:
			return -f
		KEY_RIGHT:
			return r
	return -r


# ── Drawing ─────────────────────────────────────────────────────────────────────────────────────────

func _set_selection(cells: Dictionary) -> void:
	selection = cells.duplicate()
	_draw_selection()


func _cancel() -> void:
	pasting = false
	shape_anchor = {}
	_box_start = null
	_stroking = false
	if _preview != null and is_instance_valid(_preview):
		_preview.visible = false


func _draw_selection() -> void:
	if world == null:
		return
	if _selection_view == null or not is_instance_valid(_selection_view):
		_selection_view = _cloud(0.98)
	_fill(_selection_view, selection.keys(), SELECTION_COLOUR)


func _show_preview(cells: Array, colour: Color) -> void:
	if world == null:
		return
	if _preview == null or not is_instance_valid(_preview):
		_preview = _cloud(1.02)
	_fill(_preview, cells, colour)


## Translucent cubes, ONE draw call however many. An INTERNAL child of the world: never saved, never
## shown in the Scene dock.
func _cloud(side: float) -> MultiMeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3.ONE * side
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	box.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = box
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	world.add_child(inst, false, Node.INTERNAL_MODE_BACK)
	return inst


func _fill(cloud: MultiMeshInstance3D, cells: Array, colour: Color) -> void:
	var n: int = mini(cells.size(), MAX_DRAWN)
	var size: float = world.cell_size
	cloud.multimesh.instance_count = n
	for i in n:
		var c: Vector3i = cells[i]
		cloud.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * size),
			(Vector3(c) + Vector3.ONE * 0.5) * size))
		cloud.multimesh.set_instance_color(i, colour)
	cloud.visible = n > 0


func _forget_drawing() -> void:
	for view in [_preview, _selection_view]:
		if view != null and is_instance_valid(view):
			view.queue_free()
	_preview = null
	_selection_view = null
