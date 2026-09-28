@tool
extends Node3D
## A MARCHINGBLOCKS WORLD LAYER — you paint CELLS, the tiles follow.
##
##   Cells   the GridMap you paint, with Godot's own GridMap editor: one palette item, "cell".
##   Tiles   what the rule places, half a cell further — never edit it, it is rebuilt from Cells.
##   Errors  red cubes where the tileset lacks the tile the rule asks for. Nothing is ever filled in:
##           a hole must be seen where it happens.
##
## One node is one layer: its tiles only ever look at its own cells. Stack several nodes for several
## layers (rock, ice…), each with its own tileset.

const Rule := preload("res://addons/marchingblocks_paint/mb_rule.gd")
const Tileset := preload("res://addons/marchingblocks_paint/mb_tileset.gd")

## The tileset: the `tileset.json` inside a `.mbset` folder made by MarchingBlocks.
@export_file("*.json") var tileset := "":
	set(value):
		tileset = value
		_loaded = {}
		rebuild()

@export var cell_size := 1.0:
	set(value):
		cell_size = maxf(0.01, value)
		_place_grids()
		rebuild()

## Rebuild while painting in the editor. Turn off for huge maps and call rebuild() yourself.
@export var live_update := true

## The floor the Grid aim paints on, in cells (Page Up / Page Down with the MarchingBlocks toolbar).
@export var floor_y := 0

var _loaded := {}
var _fingerprint := -1
var _last := {"tiles": 0, "missing": 0, "error": ""}


func _ready() -> void:
	_build_children()
	rebuild()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and live_update and _cells_fingerprint() != _fingerprint:
		rebuild()


## What the last rebuild did: {"tiles", "missing", "error"}.
func last_report() -> Dictionary:
	return _last


func rebuild() -> Dictionary:
	if not is_inside_tree() and get_node_or_null("Cells") == null:
		return _last
	_build_children()
	var tiles_grid := get_node("Tiles") as GridMap
	var errors := get_node("Errors") as GridMap
	tiles_grid.clear()
	errors.clear()
	_fingerprint = _cells_fingerprint()
	if tileset == "":
		_last = {"tiles": 0, "missing": 0, "error": "no tileset chosen"}
		return _last
	if _loaded.is_empty():
		_loaded = Tileset.load_tileset(tileset)
	if _loaded.has("error"):
		_last = {"tiles": 0, "missing": 0, "error": _loaded["error"]}
		push_warning("MarchingBlocks: " + _loaded["error"])
		return _last
	var library: MeshLibrary = _loaded["library"]
	tiles_grid.mesh_library = library
	var ids := {}
	for id in library.get_item_list():
		ids[library.get_item_name(id)] = id
	var cells := {}
	for c in (get_node("Cells") as GridMap).get_used_cells():
		cells[c] = true
	var orientation := []
	for q in 4:
		orientation.append(tiles_grid.get_orthogonal_index_from_basis(Basis(Vector3.UP, q * PI / 2.0)))
	var placed := 0
	var missing := 0
	for p in Rule.placements(cells, _loaded["manifest"], _loaded["manifest"].get("tiles", {})):
		var v := Vector3i(p[0], p[1], p[2])
		if p[3] == null or not ids.has(p[3]):
			errors.set_cell_item(v, 0)
			missing += 1
			continue
		tiles_grid.set_cell_item(v, ids[p[3]], orientation[int(p[4]) % 4])
		placed += 1
	_last = {"tiles": placed, "missing": missing, "error": ""}
	return _last


## The painted cells, {Vector3i: true} — read from the Cells grid, the only truth.
func cells() -> Dictionary:
	var d := {}
	var grid := get_node_or_null("Cells") as GridMap
	if grid != null:
		for c in grid.get_used_cells():
			d[c] = true
	return d


## Applies what a tool returned: clears, then sets, then rebuilds once. Arrays or Dictionaries of
## Vector3i. The editor calls it from its undo actions — undoing is apply_cells(clear, set).
func apply_cells(set_cells: Variant, clear_cells: Variant) -> void:
	_build_children()
	var grid := get_node("Cells") as GridMap
	for c in clear_cells:
		grid.set_cell_item(c, GridMap.INVALID_CELL_ITEM)
	for c in set_cells:
		grid.set_cell_item(c, 0)
	rebuild()


## A world-space point or direction in CELL space (cell c covers [c, c+1]).
func world_to_cells(p: Vector3) -> Vector3:
	return (global_transform.affine_inverse() * p) / cell_size


func world_direction_to_cells(d: Vector3) -> Vector3:
	return (global_transform.affine_inverse().basis * d) / cell_size


## The cell of the floor plane under a world ray, or null.
func cell_under_ray(origin: Vector3, direction: Vector3) -> Variant:
	var o := world_to_cells(origin)
	var d := world_direction_to_cells(direction)
	if absf(d.y) < 1e-6:
		return null
	var t := (floor_y - o.y) / d.y
	if t <= 0.0:
		return null
	var hit := o + d * t
	# Cell c covers [c, c+1]: the FLOOR of the hit, never a rounding.
	return Vector3i(floori(hit.x), floor_y, floori(hit.z))


func _build_children() -> void:
	for n in ["Cells", "Tiles", "Errors"]:
		if get_node_or_null(n) == null:
			var g := GridMap.new()
			g.name = n
			add_child(g)
			if Engine.is_editor_hint() and is_inside_tree() and get_tree().edited_scene_root != null:
				g.owner = get_tree().edited_scene_root
	var cells := get_node("Cells") as GridMap
	if cells.mesh_library == null:
		cells.mesh_library = _palette("cell", Color(0.45, 0.62, 0.95, 0.22))
	var errors := get_node("Errors") as GridMap
	if errors.mesh_library == null:
		errors.mesh_library = _palette("missing", Color(0.9, 0.2, 0.15, 0.7))
	_place_grids()


## The piece of vertex v sits at (v + piece_offset) * cell_size. A GridMap centres item v at
## (v + 0.5) * cell_size, so the Tiles and Errors grids are shifted by (piece_offset - 0.5) cells.
func _place_grids() -> void:
	var offset := Vector3.ONE
	if not _loaded.is_empty() and _loaded.has("manifest"):
		var o: Array = _loaded["manifest"].get("piece_offset", [1, 1, 1])
		offset = Vector3(float(o[0]), float(o[1]), float(o[2]))
	for n in ["Cells", "Tiles", "Errors"]:
		var g := get_node_or_null(n) as GridMap
		if g != null:
			g.cell_size = Vector3.ONE * cell_size
			g.position = Vector3.ZERO if n == "Cells" else (offset - Vector3.ONE * 0.5) * cell_size


static func _palette(item_name: String, colour: Color) -> MeshLibrary:
	var lib := MeshLibrary.new()
	var box := BoxMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = colour
	box.material = m
	lib.create_item(0)
	lib.set_item_name(0, item_name)
	lib.set_item_mesh(0, box)
	return lib


func _cells_fingerprint() -> int:
	var cells := get_node_or_null("Cells") as GridMap
	if cells == null:
		return -1
	var h := 0
	for c in cells.get_used_cells():
		h = (h * 31 + c.x * 73856093 + c.y * 19349663 + c.z * 83492791) & 0x7FFFFFFF
	return h * 31 + cells.get_used_cells().size()
