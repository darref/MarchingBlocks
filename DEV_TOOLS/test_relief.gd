extends SceneTree
## TEST — LE RELIEF (POM) QUI PART VERS LES JEUX (30 octobre 2026 ; Jordan, depuis Satyron : « je ne constate pas de POM
## dans les textures des tuiles, pourtant MB était censé avoir généré le full PBR et activé le POM »).
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_relief.gd
##   … -- --rougir : l'export ne reçoit aucune hauteur (les contrôles du relief doivent échouer).
##
## Un lot d'une tuile, un matériau à normale (« rock ») et un sans (« plain ») ; une hauteur donnée pour les DEUX.
## Attendus écrits ici : le JSON du FICHIER (pas l'importeur), l'image relue pixel à pixel, puis le greffon gratuit qui
## charge le .mbset et pose le monde : triplanaire → le matériau du relief (ShaderMaterial, `mb_still`), sans
## triplanaire → le relief de Godot sur les UV, coupé dans le projet → rien. ⚠ Le headless ne compile pas les shaders :
## le rendu se juge avec fenêtre, dans un jeu (Satyron, `DEV_TOOLS/photo_relief.gd`).

const FN := preload("res://addons/marchingblocks_core/format_neutre.gd")
const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const Tileset := preload("res://addons/marchingblocks_paint/mb_tileset.gd")
const Relief := preload("res://addons/marchingblocks_paint/mb_relief.gd")
const World := preload("res://addons/marchingblocks_paint/mb_world.gd")

var _ok := 0
var _echecs := 0
var _premier := ""
var _dossier := ""


func _initialize() -> void:
	print("=== TEST — le relief (POM) vers les jeux ===\n")
	_dossier = ProjectSettings.globalize_path("user://test_relief")
	_vider(_dossier)
	DirAccess.make_dir_recursive_absolute(_dossier)
	_derouler()


## Le dossier d'essai repart vide : une image d'une passe précédente ne doit rien prouver.
func _vider(dossier: String) -> void:
	if not DirAccess.dir_exists_absolute(dossier):
		return
	for f in DirAccess.get_files_at(dossier):
		DirAccess.remove_absolute(dossier.path_join(f))
	for d in DirAccess.get_directories_at(dossier):
		_vider(dossier.path_join(d))
		DirAccess.remove_absolute(dossier.path_join(d))


func _dire(condition: bool, quoi: String) -> void:
	if condition:
		_ok += 1
	else:
		_echecs += 1
		if _premier == "":
			_premier = quoi
		print("  ÉCHEC — %s" % quoi)


func _image(w: int, couleur: Callable) -> ImageTexture:
	var img := Image.create(w, w, false, Image.FORMAT_RGBA8)
	for y in w:
		for x in w:
			img.set_pixel(x, y, couleur.call(x, y))
	return ImageTexture.create_from_image(img)


func _lot() -> MeshLibrary:
	var rock := StandardMaterial3D.new()
	rock.resource_name = "rock"
	rock.albedo_texture = _image(8, func(x: int, y: int) -> Color: return Color(0.5, 0.4, 0.3))
	rock.normal_enabled = true
	rock.normal_texture = _image(8, func(x: int, y: int) -> Color: return Color(0.5, 0.5, 1.0))
	var plain := StandardMaterial3D.new()
	plain.resource_name = "plain"
	var box := BoxMesh.new()
	var arrays := box.get_mesh_arrays()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, rock)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(1, plain)
	var lot := MeshLibrary.new()
	var cle: String = MB.pieces_a_sculpter()[0]
	lot.create_item(0)
	lot.set_item_name(0, cle)
	lot.set_item_mesh(0, mesh)
	return lot


func _derouler() -> void:
	var rougir := "--rougir" in OS.get_cmdline_user_args()
	# Une rampe connue : le pixel (x, y) vaut x / 15.
	var hauteur := _image(16, func(x: int, y: int) -> Color: return Color(x / 15.0, x / 15.0, x / 15.0))
	var hauteurs := {} if rougir else {"rock": hauteur, "plain": hauteur}
	var r := FN.exporter(_lot(), _dossier, "essai", "test", hauteurs)
	_dire(not r.has("erreur"), "l'export passe (%s)" % r.get("erreur", ""))
	var mbset := _dossier.path_join("essai.mbset")
	# 1. LE FICHIER : le JSON du .glb, lu ici.
	var js := _json_du_glb(mbset.path_join("tiles.glb"))
	var par_nom := {}
	for m in js.get("materials", []):
		par_nom[str(m.get("name", ""))] = m
	var ex: Dictionary = (par_nom.get("rock", {}) as Dictionary).get("extras", {})
	var rel: Dictionary = ex.get("mb_relief", {})
	_dire(str(rel.get("format", "")) == "marchingblocks-relief" and int(rel.get("version", 0)) == 1,
		"le matériau à normale cite son relief dans ses extras (%s)" % JSON.stringify(ex).left(160))
	_dire(str(rel.get("height", "")) == "relief/rock_height.png" and is_equal_approx(float(rel.get("depth", 0)), 0.04),
		"le chemin relatif et la profondeur conseillée (%s, %s)" % [rel.get("height"), rel.get("depth")])
	var ex_plain: Dictionary = (par_nom.get("plain", {}) as Dictionary).get("extras", {})
	_dire(par_nom.has("plain") and not ex_plain.has("mb_relief"), "un matériau SANS normale ne porte pas de relief")
	# 2. L'IMAGE, relue.
	var img := Image.load_from_file(mbset.path_join("relief/rock_height.png"))
	_dire(img != null and not img.is_empty() and img.get_width() == 16 and absf(img.get_pixel(15, 3).r - 1.0) < 0.02
		and absf(img.get_pixel(0, 3).r) < 0.02 and absf(img.get_pixel(5, 9).r - 5.0 / 15.0) < 0.02,
		"la carte de hauteur part à côté du .glb, ses pixels intacts")
	_dire(not FileAccess.file_exists(mbset.path_join("relief/plain_height.png")), "pas de carte pour le matériau sans normale")
	var readme := FileAccess.get_file_as_string(mbset.path_join("README.txt"))
	_dire(readme.contains("extras.mb_relief"), "le README dit le relief")
	# 3. LE GREFFON : il lit le relief et le pose.
	var lu := Tileset.load_tileset(mbset.path_join("tileset.json"))
	_dire(int(lu.get("relief", 0)) == 1, "le greffon lit 1 matériau à relief (%s)" % lu.get("relief", lu.get("error")))
	for cas in [["triplanaire", true, true], ["sans triplanaire", false, true], ["coupé dans le projet", true, false]]:
		ProjectSettings.set_setting(Relief.SETTING, cas[2])
		var w := World.new()
		w.tileset = mbset.path_join("tileset.json")
		w.triplanar = cas[1]
		root.add_child(w)
		await process_frame
		# Une case peinte : une couche vide ne charge pas son jeu de tuiles.
		(w.get_node("Cells") as GridMap).set_cell_item(Vector3i.ZERO, 0)
		w.rebuild_world()
		await process_frame
		var lib: MeshLibrary = (w.get("_loaded") as Dictionary).get("library")
		var portes := []
		if lib != null:
			for id in lib.get_item_list():
				var mesh := lib.get_item_mesh(id)
				for s in mesh.get_surface_count():
					portes.append(mesh.surface_get_material(s))
		var rock_m: Material = null
		for m in portes:
			if m != null and m.resource_name == "rock":
				rock_m = m
		match cas[0]:
			"triplanaire":
				_dire(rock_m is ShaderMaterial and rock_m.has_meta("mb_still")
					and (rock_m as ShaderMaterial).get_shader_parameter("texture_height") != null,
					"triplanaire : le matériau du relief, sa hauteur (%s)" % rock_m)
			"sans triplanaire":
				_dire(rock_m is StandardMaterial3D and (rock_m as StandardMaterial3D).heightmap_enabled
					and (rock_m as StandardMaterial3D).heightmap_deep_parallax
					and is_equal_approx((rock_m as StandardMaterial3D).heightmap_scale, 4.0),
					"sans triplanaire : le relief de Godot sur les UV, profondeur 4 (%s)" % rock_m)
			"coupé dans le projet":
				_dire(rock_m is StandardMaterial3D and not (rock_m as StandardMaterial3D).heightmap_enabled,
					"coupé dans le projet : pas de relief (%s)" % rock_m)
		w.queue_free()
		await process_frame
	ProjectSettings.set_setting(Relief.SETTING, true)
	# 4. UNE VERSION PLUS RÉCENTE est ignorée, sans erreur.
	_dire(Relief.read({"format": "marchingblocks-relief", "version": 2, "height": "x.png"}).is_empty()
		and not Relief.read({"format": "marchingblocks-relief", "version": 1, "height": "x.png"}).is_empty(),
		"une version plus récente du relief est ignorée")
	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	if _echecs > 0:
		print("PREMIER ÉCHEC — %s" % _premier)
	print("VERDICT : %s" % ("ÉCHEC" if _echecs > 0 else "OK"))
	quit(1 if _echecs > 0 else 0)


func _json_du_glb(chemin: String) -> Dictionary:
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		return {}
	f.seek(12)
	var longueur := f.get_32()
	f.get_32()
	var lu: Variant = JSON.parse_string(f.get_buffer(longueur).get_string_from_utf8())
	return lu if lu is Dictionary else {}
