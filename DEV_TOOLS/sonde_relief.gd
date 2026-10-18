extends SceneTree
## LA SONDE DU RELIEF (POM) — Jordan, 18 octobre 2026 : « on met du parallax ou du POM ? », puis « oui » au POM.
## La preuve POSITIVE que la fumée ne peut pas donner (son monde n'a que la légende) : un projet TEXTURÉ ouvert pour de
## vrai, le Play test, le compte des matériaux à hauteur, puis la MÊME vue photographiée sans et avec le relief.
##
## LANCEMENT — ⚠ AVEC FENÊTRE (le headless ne rend rien), sur une COPIE du projet (l'appli s'enregistre à chaque geste) :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_relief.gd -- \
##       --projet=<copie>.mbproj --dossier=<photos> [--oeil=x,y,z] [--profondeur=4]
## ⚠ Ne pas l'interrompre : il rend `reglages.cfg` à la fin.

const REGLAGES := "user://reglages.cfg"
var _projet := ""
var _dossier := ""
var _oeil := Vector3.INF
var _profondeur := 4.0
var _reglages_avant := ""
var _ecran: Control


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--projet="):
			_projet = option.substr("--projet=".length())
		elif option.begins_with("--dossier="):
			_dossier = option.substr("--dossier=".length())
		elif option.begins_with("--oeil="):
			var p := option.substr("--oeil=".length()).split(",")
			_oeil = Vector3(float(p[0]), float(p[1]), float(p[2]))
		elif option.begins_with("--profondeur="):
			_profondeur = float(option.substr("--profondeur=".length()))
	if _projet == "" or _dossier == "":
		push_error("--projet= et --dossier= sont requis")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_dossier)
	if FileAccess.file_exists(REGLAGES):
		_reglages_avant = FileAccess.get_file_as_string(REGLAGES)
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", _projet)
	r.save(REGLAGES)
	root.size = Vector2i(1600, 900)
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	_derouler.call_deferred()


func _derouler() -> void:
	await _images(30)
	await _ecran._ouvrir(_projet)
	var vue = _ecran._vue
	await _ecran._changer_d_atelier("monde")
	await _ecran._changer_d_atelier("jeu")
	await _images(120)
	if vue.personnage == null:
		print("RELIEF : pas de Play test")
		_finir(1)
		return
	if _oeil != Vector3.INF:
		vue.personnage.global_position = _oeil
		vue.personnage.velocity = Vector3.ZERO
	await _images(90)
	var n: int = vue._appliquer_relief(false)
	print("RELIEF : %d matériaux à hauteur" % n)
	vue._vue.get_texture().get_image().save_png(_dossier.path_join("relief_0_sans.png"))
	(_ecran._controles_rendu["relief_profondeur"] as HSlider).value = _profondeur
	(_ecran._controles_rendu["relief"] as CheckButton).button_pressed = true
	var allumes := 0
	var vus := {}
	for i in vue._couches.get_child_count():
		var g := vue._couches.get_child(i).get_node_or_null("Rendu") as GridMap
		if g == null or g.mesh_library == null:
			continue
		for id in g.mesh_library.get_item_list():
			var mesh := g.mesh_library.get_item_mesh(id)
			for s in (mesh.get_surface_count() if mesh != null else 0):
				var sm := mesh.surface_get_material(s) as StandardMaterial3D
				if sm != null and not vus.has(sm):
					vus[sm] = true
					if sm.heightmap_enabled:
						allumes += 1
						print("RELIEF : allumé sur « %s »" % sm.resource_name)
	print("RELIEF : %d allumés sur %d matériaux" % [allumes, vus.size()])
	await _images(30)
	vue._vue.get_texture().get_image().save_png(_dossier.path_join("relief_1_avec.png"))
	print("RELIEF : photos dans %s" % _dossier)
	_finir(0 if allumes > 0 else 1)


func _finir(code: int) -> void:
	_ecran._aller_a("monde")
	await _images(5)
	if _reglages_avant != "":
		var f := FileAccess.open(REGLAGES, FileAccess.WRITE)
		f.store_string(_reglages_avant)
		f.close()
	quit(code)


func _images(n: int) -> void:
	for k in n:
		await process_frame
