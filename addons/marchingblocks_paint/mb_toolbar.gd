@tool
extends HBoxContainer
## THE TOOLBAR above the 3D viewport, while a MarchingBlocksWorld is selected.
##
## The MarchingBlocks tool's right panel, folded into one compact row: its icons (`mb_icons.gd`, generated
## from the tool's own), its groups — aim · tool · brush · floor · selection —, its olive accent, and ONLY
## what the current tool uses: the brush for Add · Dig · Select, Hollow for the Box, the selection's
## operations once something is selected, Paste once something is copied. Painting is all this plugin
## does, so everything else stays out of the way.
##
## It drives `mb_editor.gd` and redraws when it says `changed`. It asks nothing of the Godot editor, so it
## is built and checked without one (`plugin.gd` gives it the editor scale).

const Tools := preload("res://addons/marchingblocks_paint/mb_tools.gd")
const Shapes := preload("res://addons/marchingblocks_paint/mb_shapes.gd")
const Icons := preload("res://addons/marchingblocks_paint/mb_icons.gd")
const OLIVE := Color(0.706, 0.741, 0.522)
const RED := Color(0.878, 0.376, 0.235)

## The editor's display scale (Editor Settings > Interface > Display Scale). Set it before `editor`.
var ui_scale := 1.0
## The `mb_editor.gd` this bar drives. Setting it builds the bar.
var editor: Node:
	set(value):
		editor = value
		if get_child_count() == 0:
			_build()
		if not editor.changed.is_connected(refresh):
			editor.changed.connect(refresh)
		refresh()

var _aim_buttons := {}
var _navigate: Button
var _mode_buttons := {}
var _size: HSlider
var _size_value: Label
var _shape_buttons := {}
var _hollow: Button
var _special_buttons := {}
var _shape_bar: HBoxContainer
var _ends_buttons := {}
var _profile_bar: HBoxContainer
var _profile_buttons := {}
var _shape_size: SpinBox
var _shape_length: SpinBox
var _rail: Button
var _brush: HBoxContainer
var _selection_bar: HBoxContainer
var _selected: Label
var _paste: Button
var _floor: SpinBox
var _status: Label
var _counts: Label
var _refreshing := false


func _build() -> void:
	var bar := self
	bar.add_theme_constant_override("separation", 2)
	bar.add_child(VSeparator.new())
	var title := _label("MarchingBlocks")
	title.add_theme_color_override("font_color", OLIVE)
	bar.add_child(title)
	_gap(bar)
	for a in [["grid", "Grid (Tab)", "Aims at the floor plane — Page Up / Page Down move it."],
			["sculpt", "Sculpt (Tab)", "Aims at the matter itself: Add builds against the face you point at."]]:
		_aim_buttons[a[0]] = _toggle(bar, a[0], a[1], a[2], func() -> void: editor.set_aim(a[0]))
	_navigate = _toggle(bar, "navigate", "Navigate (Space)", "Fly as usual (right drag + W A S D, Q E); no "
		+ "click paints. Space again, or an aim, brings you back.", func() -> void:
			editor.set_navigating(not editor.navigating))
	_gap(bar)
	for m in [["add", "Add (A)", "Adds matter. Shift digs."], ["dig", "Dig (D)", "Removes matter. Shift adds."],
			["select", "Select (S)", "Paints the selection over the matter. Shift adds to it, Ctrl removes."],
			["rect", "Rect (G)", "A FLAT rectangle on the floor, whatever the aim, empty cells included: a room's floor."],
			["box", "Box (B)", "A 3D box: the whole volume, empty cells included. Shift adds, Ctrl removes."]]:
		_mode_buttons[m[0]] = _toggle(bar, m[0], m[1], m[2], func() -> void: editor.set_mode(m[0]))
	_hollow = _toggle(bar, "hollow", "Hollow box", "Keeps the skin of the box — a room. A box thinner than three "
		+ "cells stays solid.", func() -> void: editor.hollow = _hollow.button_pressed)
	# The special shapes: tools of their own, always aimed at the matter.
	_gap(bar)
	for m in [["tunnel", "Tunnel", "Digs into a WALL, square to it: one click goes through to the next cave (or Length "
			+ "deep); Connect joins two walls anywhere, slanted ones included."],
			["well", "Well", "Digs into a FLOOR or a CEILING, straight: one click stops in the cave below (or Length "
			+ "deep); Connect joins a floor and a ceiling."],
			["bridge", "Bridge", "Builds a deck out of a WALL across the air to the first wall in front; Connect "
			+ "joins two walls, and the deck bends."],
			["balcony", "Balcony", "A slab sticking out of a WALL at the height you click, with its rail."]]:
		_special_buttons[m[0]] = _toggle(bar, m[0], m[1], m[2], func() -> void: editor.set_special(m[0]))
	# Their settings: only while a shape is the tool, and only what that shape reads.
	_shape_bar = HBoxContainer.new()
	_shape_bar.add_theme_constant_override("separation", 2)
	bar.add_child(_shape_bar)
	_gap(_shape_bar)
	for e in [["straight", "Straight", "One click: straight out of the face, square to it.", false],
			["connect", "Connect", "Two clicks: a face, then another one; both ends stay open. Escape forgets the first.", true]]:
		var on: bool = e[3]
		_ends_buttons[e[0]] = _toggle(_shape_bar, e[0], e[1], e[2], func() -> void: editor.set_connect(on))
	_profile_bar = HBoxContainer.new()
	_profile_bar.add_theme_constant_override("separation", 2)
	_shape_bar.add_child(_profile_bar)
	for pr in [["round", "Round", "A round tube."], ["square", "Square", "A square duct."],
			["arch", "Arch", "A flat floor and a round vault: a corridor you can walk."]]:
		_profile_buttons[pr[0]] = _toggle(_profile_bar, pr[0], pr[1], pr[2], func() -> void:
			editor.profile = pr[0]
			refresh())
	_shape_size = _spin(_shape_bar, 1, 7, "Size ( [ and ] ): 1 is one cell across, 2 is three, 3 is five…",
		func(v: int) -> void: editor.shape_size = v)
	_shape_length = _spin(_shape_bar, 1, Shapes.LENGTH_MAX, "Length: how deep a straight tunnel or well goes when "
		+ "it finds no cave, how far a straight bridge looks for a wall, how far a balcony sticks out.",
		func(v: int) -> void: editor.shape_length = v)
	_rail = _toggle(_shape_bar, "rail", "Rail", "A one-cell rim along the open sides (bridge, balcony). Needs a size "
		+ "of 2 or more.", func() -> void: editor.rail = _rail.button_pressed)
	# The brush: only for Add, Dig and Select — Rect and Box have none.
	_brush = HBoxContainer.new()
	_brush.add_theme_constant_override("separation", 2)
	bar.add_child(_brush)
	_gap(_brush)
	_size = HSlider.new()
	_size.min_value = 1
	_size.max_value = 7
	_size.step = 1
	_size.custom_minimum_size = Vector2(64, 0) * _scale()
	_size.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_size.tooltip_text = "Brush size ( [ and ] ). 1 is a single cell."
	_size.value_changed.connect(func(v: float) -> void:
		_size_value.text = str(int(v))
		if not _refreshing:
			editor.brush_size = int(v))
	_brush.add_child(_size)
	_size_value = _label("1")
	_size_value.custom_minimum_size = Vector2(12, 0) * _scale()
	_size_value.add_theme_color_override("font_color", OLIVE)
	_brush.add_child(_size_value)
	var shape_tips := ["A ball of cells.", "A cube of cells.",
		"Flat, across the face you point at — fills or digs a wall without thickening it."]
	for i in Tools.SHAPES.size():
		var s: String = Tools.SHAPES[i]
		_shape_buttons[s] = _toggle(_brush, s, s.capitalize(), shape_tips[i], func() -> void:
			editor.shape = s
			refresh())
	_gap(bar)
	var floor_icon := TextureRect.new()
	floor_icon.texture = Icons.icon("floor", _icon_px())
	floor_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	floor_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	floor_icon.custom_minimum_size = Vector2(16, 16) * _scale()
	floor_icon.modulate = Color(1, 1, 1, 0.6)
	floor_icon.tooltip_text = "Floor — the plane the Grid aim and the Rect paint on."
	bar.add_child(floor_icon)
	_floor = SpinBox.new()
	_floor.min_value = -4096
	_floor.max_value = 4096
	_floor.select_all_on_focus = true
	_floor.tooltip_text = "Floor (Page Up / Page Down) — the plane the Grid aim and the Rect paint on."
	_floor.value_changed.connect(func(v: float) -> void:
		if not _refreshing and editor.world != null:
			editor.world.floor_y = int(v))
	bar.add_child(_floor)
	# The selection: its operations appear once there is something selected, as in the tool.
	_selection_bar = HBoxContainer.new()
	_selection_bar.add_theme_constant_override("separation", 2)
	bar.add_child(_selection_bar)
	_gap(_selection_bar)
	_selected = _label("")
	_selected.add_theme_color_override("font_color", OLIVE)
	_selection_bar.add_child(_selected)
	for o in [["fill", "fill", "Fill", "Fills every selected cell with matter. Draw a Rect or a Box, then Fill it."],
			["delete", "delete", "Delete (Del)", "Removes the selected matter."],
			["clear", "", "Clear (Esc)", "Forgets the selection. No cell changes."],
			["extrude_up", "extrude_up", "Extrude up", "Adds the layer above; the selection AND the floor follow it."],
			["extrude_down", "extrude_down", "Extrude down", "Adds the layer below; the selection and the floor follow it."],
			["grow", "grow", "Grow", "Selects the matter touching the selection by a face."],
			["shrink", "shrink", "Shrink", "Drops the selected cells that touch an unselected one."],
			["connected", "connected", "Connected", "Selects all the matter linked to the selection by faces."]]:
		var op: String = o[1]
		var b := _button(_selection_bar, o[0], o[2], o[3], func() -> void:
			if op == "":
				editor.clear_selection()
			else:
				editor.operate(op))
		if o[0] == "delete":
			b.add_theme_color_override("icon_normal_color", RED)
			b.add_theme_color_override("icon_hover_color", RED.lightened(0.2))
	var move := _menu(_selection_bar, "move", "Move — the arrow keys move the selection too (they follow the "
		+ "camera; Shift + up / down lift).")
	var moves := [["−X", Vector3i(-1, 0, 0)], ["+X", Vector3i(1, 0, 0)], ["−Y", Vector3i(0, -1, 0)],
		["+Y", Vector3i(0, 1, 0)], ["−Z", Vector3i(0, 0, -1)], ["+Z", Vector3i(0, 0, 1)]]
	for i in moves.size():
		move.get_popup().add_item("Move " + str(moves[i][0]), i)
	move.get_popup().id_pressed.connect(func(i: int) -> void: editor.move_selection(moves[i][1]))
	_button(_selection_bar, "copy", "Copy (Ctrl+C)", "Copies the selected matter.", func() -> void:
		editor.copy_selection())
	_button(_selection_bar, "cut", "Cut (Ctrl+X)", "Copies, then deletes.", func() -> void: editor.cut_selection())
	# Paste stays while the clipboard holds something, selection or not.
	_paste = _button(bar, "paste", "Paste (Ctrl+V)", "The copy follows the mouse; click to place it, Esc cancels.",
		func() -> void: editor.start_paste())
	_gap(bar)
	var monde := _menu(bar, "world", "The whole layer: rebuild its tiles, or clear its cells (Ctrl+Z brings "
		+ "them back).")
	monde.get_popup().add_item("Rebuild tiles", 0)
	monde.get_popup().add_item("Clear cells", 1)
	monde.get_popup().id_pressed.connect(func(id: int) -> void:
		if editor.world == null:
			return
		if id == 0:
			editor.world.rebuild()
			refresh()
		else:
			editor.clear_world())
	_counts = _label("")
	_counts.tooltip_text = "Cells painted · tiles placed · tiles the tileset lacks (red cubes)."
	bar.add_child(_counts)
	_status = _label("")
	_status.add_theme_color_override("font_color", OLIVE)
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.clip_text = true
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.custom_minimum_size = Vector2(140, 0) * _scale()
	bar.add_child(_status)


## An icon-only toggle, flat: the tooltip names it and gives its key. Pressed, its icon turns olive.
func _toggle(parent: Control, icon: String, title: String, tip: String, act: Callable) -> Button:
	var b := _button(parent, icon, title, tip, act)
	b.toggle_mode = true
	b.add_theme_color_override("icon_pressed_color", OLIVE)
	b.add_theme_color_override("icon_hover_pressed_color", OLIVE.lightened(0.2))
	b.add_theme_stylebox_override("pressed", _plate(Color(OLIVE, 0.22)))
	b.add_theme_stylebox_override("hover_pressed", _plate(Color(OLIVE, 0.3)))
	return b


func _button(parent: Control, icon: String, title: String, tip: String, act: Callable) -> Button:
	var b := Button.new()
	b.icon = Icons.icon(icon, _icon_px())
	b.tooltip_text = title + " — " + tip
	# ⚠ NOT `flat`: Godot draws NO style box on a flat button, and a pressed tool then only showed as an
	# olive tint — too faint to read (seen on ART/barre_greffon.png). The tool's plates instead: none at
	# rest, a faint one under the mouse, an olive one pressed.
	b.add_theme_stylebox_override("normal", _plate(Color(0, 0, 0, 0)))
	b.add_theme_stylebox_override("hover", _plate(Color(1, 1, 1, 0.07)))
	b.add_theme_stylebox_override("pressed", _plate(Color(1, 1, 1, 0.12)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_constant_override("icon_max_width", _icon_width())
	b.pressed.connect(act)
	parent.add_child(b)
	return b


func _plate(colour: Color) -> StyleBoxFlat:
	var plate := StyleBoxFlat.new()
	plate.bg_color = colour
	plate.set_corner_radius_all(int(round(3 * ui_scale)))
	plate.set_content_margin_all(4 * ui_scale)
	return plate


func _spin(parent: Control, low: int, high: int, tip: String, act: Callable) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = low
	sb.max_value = high
	sb.select_all_on_focus = true
	sb.tooltip_text = tip
	sb.value_changed.connect(func(v: float) -> void:
		if not _refreshing:
			act.call(int(v)))
	parent.add_child(sb)
	return sb


func _menu(parent: Control, icon: String, tip: String) -> MenuButton:
	var m := MenuButton.new()
	m.icon = Icons.icon(icon, _icon_px())
	m.flat = true
	m.tooltip_text = tip
	m.add_theme_constant_override("icon_max_width", _icon_width())
	parent.add_child(m)
	return m


## A faint line between groups, as the tool's panel separates its sections.
func _gap(parent: Control) -> void:
	var s := VSeparator.new()
	s.add_theme_constant_override("separation", 8)
	s.modulate = Color(1, 1, 1, 0.4)
	parent.add_child(s)


func _scale() -> float:
	return ui_scale


## Icons are drawn twice their display size, then bounded: sharp on a 200 % screen.
func _icon_width() -> int:
	return int(round(18 * _scale()))


func _icon_px() -> int:
	return _icon_width() * 2


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func refresh() -> void:
	if editor == null or get_child_count() == 0:
		return
	_refreshing = true
	for a in _aim_buttons:
		(_aim_buttons[a] as Button).set_pressed_no_signal(a == editor.aim)
	_navigate.set_pressed_no_signal(editor.navigating)
	for m in _mode_buttons:
		(_mode_buttons[m] as Button).set_pressed_no_signal(m == editor.mode)
	_hollow.set_pressed_no_signal(editor.hollow)
	# Only what the current tool uses, as in the tool: Hollow for the Box, the brush for Add · Dig · Select.
	_hollow.visible = editor.mode == "box"
	var shaping: bool = editor.mode == "shape"
	for sp in _special_buttons:
		(_special_buttons[sp] as Button).set_pressed_no_signal(shaping and sp == editor.special)
	_shape_bar.visible = shaping
	_ends_buttons["straight"].visible = editor.special != "balcony"
	_ends_buttons["connect"].visible = editor.special != "balcony"
	(_ends_buttons["straight"] as Button).set_pressed_no_signal(not editor.connect_ends)
	(_ends_buttons["connect"] as Button).set_pressed_no_signal(editor.connect_ends)
	_profile_bar.visible = editor.special in ["tunnel", "well"]
	for pr in _profile_buttons:
		(_profile_buttons[pr] as Button).set_pressed_no_signal(pr == editor.profile)
	_shape_size.set_value_no_signal(editor.shape_size)
	_shape_length.set_value_no_signal(editor.shape_length)
	_shape_length.visible = editor.special == "balcony" or not editor.connect_ends
	_rail.visible = editor.special in ["bridge", "balcony"]
	_rail.set_pressed_no_signal(editor.rail)
	_brush.visible = editor.mode in ["add", "dig", "select"]
	_size.set_value_no_signal(editor.brush_size)
	_size_value.text = str(editor.brush_size)
	for s in _shape_buttons:
		(_shape_buttons[s] as Button).set_pressed_no_signal(s == editor.shape)
	if editor.world != null:
		_floor.set_value_no_signal(editor.world.floor_y)
	var n: int = editor.selection.size()
	_selection_bar.visible = n > 0
	_selected.text = "%d selected" % n
	_paste.visible = not editor.clipboard.is_empty()
	_status.text = editor.status
	_status.tooltip_text = editor.status
	# Cells · tiles · missing, as in the Unity inspector and the Unreal mode panel.
	if editor.world != null:
		var r: Dictionary = editor.world.last_report()
		if str(r.get("error", "")) != "":
			_counts.text = "⚠ " + str(r["error"])
			_counts.add_theme_color_override("font_color", RED)
		else:
			var missing := int(r.get("missing", 0))
			_counts.text = "%d cells · %d tiles%s" % [editor.world.cells().size(), int(r.get("tiles", 0)),
				(" · %d missing" % missing) if missing > 0 else ""]
			if missing > 0:
				_counts.add_theme_color_override("font_color", RED)
			else:
				_counts.remove_theme_color_override("font_color")
	else:
		_counts.text = ""
	_refreshing = false
