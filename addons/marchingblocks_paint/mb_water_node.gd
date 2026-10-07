@tool
extends Node3D
## A WATER LAYER OF A WORLD — the water sheet MarchingBlocks baked (`water/<name>.glb`, in FORMAT space: the import
## scales this node by the layers' cell size), drawn with a material: YOURS if you set one, otherwise the example look
## the world suggests. The six looks shipped with the plugin are EXAMPLES, not an obligation — any water shader gets
## the data: COLOR_0 r, g the flow along x and z ([-1, 1] mapped to [0, 1]); b the kind (0 still, 0.5 river, 0.75
## foam, 1 waterfall); a the depth / 8 (still water and rivers) or the amount of foam (waterfalls, foam); NORMAL the
## shape (a waterfall is a curved, closed sheet); TEXCOORD_0.
##
## THE WATER FOLLOWS THE CELLS: `water_cells()` deduces, from the sources of every water layer and the cells of every
## tile layer of the world (hidden ones too), which cells hold water now (`mb_water.gd`, the rule of the tool). Once the
## cells are no longer those the sheet was baked for, the editor says the sheet is stale; with `follow_cells` on, it
## also SHOWS the water of the new cells (translucent blue) in place of the sheet — off by default: a big sea is
## millions of cells, deduced in GDScript. Rebuilding the SHEET itself needs the tool's mesher (re-export the world
## from MarchingBlocks).

const Water := preload("res://addons/marchingblocks_paint/mb_water.gd")
const Shaders := preload("res://addons/marchingblocks_paint/mb_shaders.gd")
const World := preload("res://addons/marchingblocks_paint/mb_world.gd")

## The baked sheet: a .glb path (res://…), or "" (nothing to draw).
@export_file("*.glb") var mesh_path := "":
	set(value):
		mesh_path = value
		_dirty()
## The look the world suggests: stylized, clear, reflective, lava, swamp or acid (an unknown one: stylized).
@export var look := "stylized":
	set(value):
		look = value
		_dirty()
## Your own water material. Empty: the example look above.
@export var material: Material:
	set(value):
		material = value
		_dirty()
## Where the water was placed: [x, y, z] per source, FORMAT space.
@export var sources: Array = []
## The tile cells the sheet was baked for (a fingerprint, set at import); 0: unknown.
@export var baked_for := 0
## In the editor, once the cells changed: show the water cells deduced now, in place of the stale sheet.
@export var follow_cells := false:
	set(value):
		follow_cells = value
		_checked = -1

var _sheet: MeshInstance3D
var _preview: MultiMeshInstance3D
var _checked := -1
static var _looks := {}


func _ready() -> void:
	rebuild()


func _dirty() -> void:
	if is_inside_tree():
		rebuild.call_deferred()


## The example material of a look (one shader per look, shared).
static func look_material(name: String) -> ShaderMaterial:
	var key: String = name if name in Shaders.WATER_LOOKS else "stylized"
	if not _looks.has(key):
		var s := Shader.new()
		s.code = Shaders.WATER[key]
		_looks[key] = s
	var m := ShaderMaterial.new()
	m.shader = _looks[key]
	return m


func rebuild() -> void:
	if _sheet == null or not is_instance_valid(_sheet):
		_sheet = MeshInstance3D.new()
		_sheet.name = "Sheet"
		add_child(_sheet, false, Node.INTERNAL_MODE_BACK)
	_sheet.mesh = _mesh_of(mesh_path) if mesh_path != "" else null
	_sheet.material_override = material if material != null else look_material(look)


## The first mesh of the .glb (the sheet is one node, one mesh).
static func _mesh_of(path: String) -> Mesh:
	var scene: Node = null
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed != null:
			scene = packed.instantiate()
	if scene == null and FileAccess.file_exists(path):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(path, state) == OK:
			scene = doc.generate_scene(state)
	if scene == null:
		push_warning("MarchingBlocks water: cannot read %s" % path)
		return null
	var found: Mesh = null
	var stack: Array = [scene]
	while not stack.is_empty() and found == null:
		var n: Node = stack.pop_front()
		var m = n.get("mesh")
		if m is ImporterMesh:
			m = (m as ImporterMesh).get_mesh()
		if m is Mesh:
			found = m
		stack.append_array(n.get_children())
	scene.free()
	return found


## The tile layers of this water's world: the MarchingBlocksWorld siblings.
func layers() -> Array:
	var parent := get_parent()
	if parent == null:
		return []
	return parent.get_children().filter(func(n: Node) -> bool: return n.get_script() == World)


## Every water layer of this world, in order (the sea is the FIRST source in the void among all of them).
func water_layers() -> Array:
	var parent := get_parent()
	if parent == null:
		return [self]
	return parent.get_children().filter(func(n: Node) -> bool: return n.get_script() == get_script())


## The cells of every tile layer, hidden ones too.
func world_cells() -> Dictionary:
	var all := {}
	for l in layers():
		all.merge(l.cells())
	return all


## The water cells of THIS layer now, deduced from the cells: {cell: true}.
func water_cells() -> Dictionary:
	var all_sources: Array = []
	var mine: Array = []
	for w in water_layers():
		for s in w.sources:
			var v := Vector3i(int(s[0]), int(s[1]), int(s[2]))
			if w == self:
				mine.append(all_sources.size())
			all_sources.append(v)
	var r := Water.world(world_cells(), all_sources)
	var out := {}
	for i in mine:
		out.merge(r["bodies"][i]["water"])
	return out


static func fingerprint(cells: Dictionary) -> int:
	var keys := cells.keys()
	keys.sort()
	var h := keys.size()
	for c: Vector3i in keys:
		h = (h * 31 + c.x * 73856093 + c.y * 19349663 + c.z * 83492791) & 0x7FFFFFFF
	return h


## Is the baked sheet stale — were the tile cells changed since?
func stale() -> bool:
	return baked_for != 0 and fingerprint(world_cells()) != baked_for


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() or baked_for == 0:
		return
	var h := 1 if follow_cells else 0
	for l in layers():
		h = (h * 131 + l._cells_fingerprint()) & 0x7FFFFFFF
	if h == _checked:
		return
	var first := _checked == -1
	_checked = h
	if not stale():
		_show_preview({})
		return
	_show_preview(water_cells() if follow_cells else {})
	if not first or follow_cells:
		push_warning("MarchingBlocks water '%s': the cells changed since its sheet was baked. %s Re-export the world "
			% [name, "The blue cells show the water now." if follow_cells else "Turn on Follow Cells to see the water now."]
			+ "from MarchingBlocks to rebuild the sheet.")


func _show_preview(cells: Dictionary) -> void:
	if _preview == null or not is_instance_valid(_preview):
		_preview = MultiMeshInstance3D.new()
		var box := BoxMesh.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.2, 0.55, 1.0, 0.25)
		box.material = m
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = box
		_preview.multimesh = mm
		add_child(_preview, false, Node.INTERNAL_MODE_BACK)
	var list: Array = cells.keys()
	var n: int = mini(list.size(), 20000)
	_preview.multimesh.instance_count = n
	for i in n:
		_preview.multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(list[i]) + Vector3.ONE * 0.5))
	_preview.visible = n > 0
	_sheet.visible = n == 0
