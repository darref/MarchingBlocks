@tool
extends RefCounted
## LOADS A MARCHINGBLOCKS TILESET — a `<name>.mbset/` folder: `tileset.json` + `tiles.glb`.
##
## Returns {"manifest": Dictionary, "library": MeshLibrary} — one library item per tile, named after the
## tile — or {"error": reason}. Every failure says WHICH one: a missing file, an unreadable manifest, a
## newer format, a tile the manifest lists but the .glb does not carry.

const Rule := preload("res://addons/marchingblocks_paint/mb_rule.gd")


static func load_tileset(manifest_path: String) -> Dictionary:
	if not FileAccess.file_exists(manifest_path):
		return {"error": "file not found: %s" % manifest_path}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(manifest_path)) != OK or not json.data is Dictionary:
		return {"error": "tileset.json is not valid JSON (line %d)" % json.get_error_line()}
	var manifest: Dictionary = json.data
	if manifest.get("format", "") != Rule.FORMAT:
		return {"error": "not a MarchingBlocks tileset"}
	var why := Rule.check(manifest)
	if why != "":
		return {"error": why}

	var glb := manifest_path.get_base_dir().path_join(str(manifest.get("tiles_file", "tiles.glb")))
	var meshes := _meshes_of(glb)
	if meshes.has("error"):
		return meshes
	var library := MeshLibrary.new()
	var missing: Array = []
	var next_id := 0
	for key in manifest.get("tiles", {}):
		var tile: String = manifest["tiles"][key]
		if not meshes.has(tile):
			missing.append(tile)
			continue
		library.create_item(next_id)
		library.set_item_name(next_id, tile)
		library.set_item_mesh(next_id, meshes[tile])
		next_id += 1
	if not missing.is_empty():
		return {"error": "%d tile(s) listed in tileset.json are not in %s: %s"
			% [missing.size(), glb.get_file(), str(missing.slice(0, 5))]}
	return {"manifest": manifest, "library": library}


## {node name: Mesh} for every mesh node of the .glb. An imported resource is used when the project has
## one (res://), otherwise the file is read at run time.
static func _meshes_of(glb: String) -> Dictionary:
	var scene: Node = null
	if glb.begins_with("res://") and ResourceLoader.exists(glb):
		var packed := load(glb) as PackedScene
		if packed != null:
			scene = packed.instantiate()
	if scene == null:
		if not FileAccess.file_exists(glb):
			return {"error": "file not found: %s" % glb}
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var err := doc.append_from_file(glb, state)
		if err != OK:
			return {"error": "%s could not be read (error %d)" % [glb.get_file(), err]}
		scene = doc.generate_scene(state)
		if scene == null:
			return {"error": "%s holds no scene" % glb.get_file()}
	var out := {}
	_collect(scene, out)
	scene.free()
	return out


## A node is recognised by what it CARRIES, not by its class: the editor import yields
## ImporterMeshInstance3D, which does not inherit MeshInstance3D.
static func _collect(node: Node, out: Dictionary) -> void:
	var m = node.get("mesh")
	if m is ImporterMesh:
		m = (m as ImporterMesh).get_mesh()
	if m is Mesh:
		out[str(node.name)] = m
	for child in node.get_children():
		_collect(child, out)
