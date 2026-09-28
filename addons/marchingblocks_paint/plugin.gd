@tool
extends EditorPlugin
## Registers the MarchingBlocksWorld node, and gives it the MarchingBlocks editing tools.
##
## Select a MarchingBlocksWorld: a toolbar appears above the 3D viewport, and the viewport paints with it
## (`mb_editor.gd` does the work, `mb_tools.gd` holds the rules). Selecting its "Cells" child instead
## gives Godot's own GridMap editor, as before — both paint the same cells.

const World := preload("res://addons/marchingblocks_paint/mb_world.gd")
const Editor := preload("res://addons/marchingblocks_paint/mb_editor.gd")
const Tools := preload("res://addons/marchingblocks_paint/mb_tools.gd")

var _editor: Node
var _bar: HBoxContainer
var _aim_buttons := {}
var _mode_buttons := {}
var _size: SpinBox
var _shape: OptionButton
var _hollow: CheckBox
var _floor: SpinBox
var _status: Label
var _counts: Label
var _refreshing := false


func _enter_tree() -> void:
	add_custom_type("MarchingBlocksWorld", "Node3D", World, null)
	_editor = Editor.new()
	_editor.undo = get_undo_redo()
	_editor.changed.connect(_refresh)
	add_child(_editor)
	_bar = _build_bar()
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _bar)
	_bar.visible = false


func _exit_tree() -> void:
	remove_custom_type("MarchingBlocksWorld")
	if _bar != null:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _bar)
		_bar.queue_free()
	if _editor != null:
		_editor.world = null
		_editor.queue_free()


func _handles(object: Object) -> bool:
	return object is Node3D and (object as Node3D).get_script() == World


func _edit(object: Object) -> void:
	_editor.world = object as Node3D if _handles(object) else null
	_refresh()


func _make_visible(visible: bool) -> void:
	_bar.visible = visible
	if not visible:
		_editor.world = null


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if _editor.input(camera, event):
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS


# ── The toolbar ─────────────────────────────────────────────────────────────────────────────────────

func _build_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_child(VSeparator.new())
	bar.add_child(_label("MarchingBlocks"))
	for a in [["grid", "Grid", "Aims at the floor plane (Page Up / Page Down move it). Tab cycles the aims."],
			["sculpt", "Sculpt", "Aims at the matter itself: Add builds against the face you point at."],
			["navigate", "Navigate", "Aims at nothing: fly as usual (right drag + W A S D, Q E). No click paints."]]:
		_aim_buttons[a[0]] = _toggle(bar, a[1], a[2], func() -> void: _editor.set_aim(a[0]))
	bar.add_child(VSeparator.new())
	for m in [["add", "Add", "A — adds matter. Shift digs."], ["dig", "Dig", "D — removes matter. Shift adds."],
			["select", "Select", "S — paints the selection over the matter. Shift adds to it, Ctrl removes."],
			["rect", "Rect", "G — a FLAT rectangle on the floor, whatever the aim, empty cells included: a room's floor."],
			["box", "Box", "B — a 3D box: the whole volume, empty cells included. Shift adds, Ctrl removes."]]:
		_mode_buttons[m[0]] = _toggle(bar, m[1], m[2], func() -> void: _editor.set_mode(m[0]))
	_hollow = CheckBox.new()
	_hollow.text = "Hollow"
	_hollow.tooltip_text = "Box only: keeps the skin — a room. A box thinner than three cells stays solid."
	_hollow.toggled.connect(func(v: bool) -> void: _editor.hollow = v)
	bar.add_child(_hollow)
	bar.add_child(VSeparator.new())
	bar.add_child(_label("Brush"))
	_size = SpinBox.new()
	_size.min_value = 1
	_size.max_value = 7
	_size.tooltip_text = "[ and ] — brush size."
	_size.value_changed.connect(func(v: float) -> void:
		if not _refreshing:
			_editor.brush_size = int(v))
	bar.add_child(_size)
	_shape = OptionButton.new()
	for s in ["Sphere", "Cube", "Disc"]:
		_shape.add_item(s)
	_shape.item_selected.connect(func(i: int) -> void: _editor.shape = Tools.SHAPES[i])
	bar.add_child(_shape)
	bar.add_child(_label("Floor"))
	_floor = SpinBox.new()
	_floor.min_value = -4096
	_floor.max_value = 4096
	_floor.tooltip_text = "Page Up / Page Down — the plane the Grid aim and the Rect paint on."
	_floor.value_changed.connect(func(v: float) -> void:
		if not _refreshing and _editor.world != null:
			_editor.world.floor_y = int(v))
	bar.add_child(_floor)
	bar.add_child(VSeparator.new())
	var menu := MenuButton.new()
	menu.text = "Selection"
	menu.tooltip_text = "What to do with the selection. Delete, Escape, the arrows and Ctrl+C / X / V work too."
	var ops := [["Fill", "fill"], ["Delete", "delete"], ["Extrude up", "extrude_up"], ["Extrude down", "extrude_down"],
		["Grow", "grow"], ["Shrink", "shrink"], ["Connected", "connected"]]
	var popup := menu.get_popup()
	for i in ops.size():
		popup.add_item(ops[i][0], i)
	popup.add_separator()
	# The same moves as the arrow keys, on fixed axes — the arrows follow the camera, these do not.
	var moves := [["Move −X", Vector3i(-1, 0, 0)], ["Move +X", Vector3i(1, 0, 0)], ["Move −Y", Vector3i(0, -1, 0)],
		["Move +Y", Vector3i(0, 1, 0)], ["Move −Z", Vector3i(0, 0, -1)], ["Move +Z", Vector3i(0, 0, 1)]]
	for i in moves.size():
		popup.add_item(moves[i][0], 110 + i)
	popup.set_meta("moves", moves)
	popup.add_separator()
	popup.add_item("Copy", 100)
	popup.add_item("Cut", 101)
	popup.add_item("Paste", 102)
	popup.add_item("Clear selection", 103)
	popup.id_pressed.connect(_selection_menu.bind(ops, moves))
	bar.add_child(menu)
	var monde := MenuButton.new()
	monde.text = "World"
	monde.tooltip_text = "The whole layer: rebuild its tiles, or clear its cells (Ctrl+Z brings them back)."
	monde.get_popup().add_item("Rebuild tiles", 0)
	monde.get_popup().add_item("Clear cells", 1)
	monde.get_popup().id_pressed.connect(func(id: int) -> void:
		if _editor.world == null:
			return
		if id == 0:
			_editor.world.rebuild()
			_refresh()
		else:
			_editor.clear_world())
	bar.add_child(monde)
	bar.add_child(VSeparator.new())
	_counts = _label("")
	_counts.tooltip_text = "Cells painted · tiles placed · tiles the tileset lacks (red cubes)."
	bar.add_child(_counts)
	_status = _label("")
	_status.add_theme_color_override("font_color", Color(0.75, 0.8, 0.6))
	bar.add_child(_status)
	return bar


func _selection_menu(id: int, ops: Array, moves: Array) -> void:
	if id >= 110 and id < 110 + moves.size():
		_editor.move_selection(moves[id - 110][1])
		return
	match id:
		100:
			_editor.copy_selection()
		101:
			_editor.cut_selection()
		102:
			_editor.start_paste()
		103:
			_editor.clear_selection()
		_:
			_editor.operate(ops[id][1])


func _toggle(bar: HBoxContainer, text: String, tip: String, act: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.toggle_mode = true
	b.flat = true
	b.pressed.connect(act)
	bar.add_child(b)
	return b


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _refresh() -> void:
	if _bar == null:
		return
	_refreshing = true
	for a in _aim_buttons:
		(_aim_buttons[a] as Button).set_pressed_no_signal(a == _editor.aim)
	for m in _mode_buttons:
		(_mode_buttons[m] as Button).set_pressed_no_signal(m == _editor.mode)
	_hollow.set_pressed_no_signal(_editor.hollow)
	_size.set_value_no_signal(_editor.brush_size)
	_shape.select(Tools.SHAPES.find(_editor.shape))
	if _editor.world != null:
		_floor.set_value_no_signal(_editor.world.floor_y)
	var n: int = _editor.selection.size()
	_status.text = ("%d selected · " % n if n > 0 else "") + _editor.status
	# Cells · tiles · missing, as in the Unity inspector and the Unreal Details panel.
	if _editor.world != null:
		var r: Dictionary = _editor.world.last_report()
		if str(r.get("error", "")) != "":
			_counts.text = "⚠ " + str(r["error"])
			_counts.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
		else:
			_counts.text = "%d cells · %d tiles%s" % [_editor.world.cells().size(), int(r.get("tiles", 0)),
				(" · %d missing (red)" % int(r["missing"])) if int(r.get("missing", 0)) > 0 else ""]
			_counts.remove_theme_color_override("font_color")
	else:
		_counts.text = ""
	_refreshing = false
