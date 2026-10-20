@tool
extends Node3D
## THE CROSSINGS OF A WORLD — its stairs and slopes, each drawn from its model's mesh AND given a COLLISION (the mesh's
## triangles, a StaticBody3D per crossing): a character walks up them. The import puts this node next to the layers,
## scaled by their cell size: its own space is FORMAT space (one unit, one cell). Rebuilt from `models` and `placements`
## when it enters the tree, and when either changes.

const Crossings := preload("res://addons/marchingblocks_paint/mb_crossings.gd")

## The models: [{id, name, kind, width, height, depth, mesh (a .glb path, or null)}].
@export var models: Array = []:
	set(value):
		models = value
		_dirty()
## The crossings, 5 integers each: model id, x, y, z of the foot cell, quarter turn.
@export var placements: PackedInt32Array = PackedInt32Array():
	set(value):
		placements = value
		_dirty()
## The physics layer of their collision (the layers' tiles get theirs from the game).
@export_flags_3d_physics var collision_layer := 1

static var _meshes := {}


func _ready() -> void:
	rebuild()


func _dirty() -> void:
	if is_inside_tree():
		rebuild.call_deferred()


func rebuild() -> void:
	for c in get_children(true):
		if c.has_meta("mb_crossing"):
			remove_child(c)
			c.queue_free()
	var by_id := {}
	for m in models:
		by_id[int(m["id"])] = m
	for k in range(0, placements.size() - 4, 5):
		var m = by_id.get(placements[k])
		if m == null:
			continue
		var mesh := mesh_of(m)
		if mesh == null:
			continue
		var t := Crossings.transform_of(m, Vector3i(placements[k + 1], placements[k + 2], placements[k + 3]),
			placements[k + 4])
		var body := StaticBody3D.new()
		body.set_meta("mb_crossing", true)
		body.collision_layer = collision_layer
		body.transform = t
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		body.add_child(mi)
		var shape := CollisionShape3D.new()
		shape.shape = mesh.create_trimesh_shape()
		body.add_child(shape)
		add_child(body, false, Node.INTERNAL_MODE_BACK)


## A model's mesh, read once per path (an imported resource when the project has one, else the .glb at run time).
static func mesh_of(m: Dictionary) -> Mesh:
	var path = m.get("mesh")
	if not path is String:
		return null
	if _meshes.has(path):
		return _meshes[path]
	var scene: Node = null
	if (path as String).begins_with("res://") and ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed != null:
			scene = packed.instantiate()
	if scene == null and FileAccess.file_exists(path):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(path, state) == OK:
			scene = doc.generate_scene(state)
	var found: Mesh = null
	if scene != null:
		for n in [scene] + scene.find_children("*", "", true, false):
			var mm = n.get("mesh")
			if mm is ImporterMesh:
				mm = (mm as ImporterMesh).get_mesh()
			if mm is Mesh:
				found = mm
				break
		scene.free()
	if found == null:
		push_warning("MarchingBlocks crossings: no mesh in %s" % path)
	_meshes[path] = found
	return found
