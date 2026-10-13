extends SceneTree
##
## LES INFOS DE LA VUE, L'ÉTAGE DU GUIDE, LE REPÈRE DE TAILLE, LA GRILLE — À L'IMAGE (Jordan, 13 octobre 2026).
## AVEC FENÊTRE, jamais en headless :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks --script res://DEV_TOOLS/capture_infos_vue.gd -- --dossier=…
## Le projet de l'utilisateur n'est jamais touché : un projet jetable, `reglages.cfg` rendu tel quel à la fin.

const Projet := preload("res://app/projet.gd")
const REGLAGES := "user://reglages.cfg"
const JETABLE := "user://capture/infos.mbproj"
var _dossier := "user://capture"
var _ecran: Control
var _reglages_avant := ""


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--dossier="):
			_dossier = option.substr("--dossier=".length())
	DirAccess.make_dir_recursive_absolute(_dossier)
	if FileAccess.file_exists(REGLAGES):
		_reglages_avant = FileAccess.get_file_as_string(REGLAGES)
	DirAccess.make_dir_recursive_absolute("user://capture")
	var f := FileAccess.open(JETABLE, FileAccess.WRITE)
	f.store_string(Projet.vers_texte([Projet.couche("Rock")], 0))
	f.close()
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", JETABLE)
	r.save(REGLAGES)
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	_derouler()


static func _boite(d: Dictionary, a: Vector3i, b: Vector3i, plein := true) -> void:
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			for z in range(a.z, b.z + 1):
				if plein:
					d[Vector3i(x, y, z)] = true
				else:
					d.erase(Vector3i(x, y, z))


## Un plateau à falaise de 6 cases, une marche d'une case, et une salle ouverte vers le haut.
func _paysage() -> Dictionary:
	var d := {}
	_boite(d, Vector3i(-8, 0, -8), Vector3i(8, 5, -2))
	_boite(d, Vector3i(-8, 0, -1), Vector3i(8, 0, 1))
	_boite(d, Vector3i(-6, 1, -7), Vector3i(-1, 5, -4), false)
	return d


func _survol(ou_monde: Vector3) -> void:
	var vue = _ecran._vue
	var ecran: Vector2 = (vue as Control).get_global_rect().position + vue._camera.unproject_position(ou_monde)
	var m := InputEventMouseMotion.new()
	m.position = ecran
	m.global_position = ecran
	root.push_input(m)


func _regarder(cible: Vector3, azimut: float, elevation: float, distance: float) -> void:
	var vue = _ecran._vue
	vue._cible = cible
	vue._azimut = azimut
	vue._elevation = elevation
	vue._distance = distance
	vue._caler()


func _derouler() -> void:
	await _images(20)
	_ecran._aller_a("monde")
	_ecran._appliquer({"poser": _paysage(), "effacer": {}}, "Landscape")
	_ecran._choisir_outil("ajouter")
	_ecran._choisir_visee("grille")
	_ecran._compteur_etage.value = 1
	await _images(5)
	# 1. Le fantôme au pied de la falaise, sur la marche (étage 1), le guide et les infos.
	_regarder(Vector3(0, 2, 0), 0.5, 0.45, 18.0)
	await _images(5)
	_survol(Vector3(1.5, 1.0, 0.5))
	await _images(8)
	_photo("infos_1_pied_de_falaise")
	# 2. Une sélection et un Rect en cours de glissé.
	_ecran._choisir_outil("selectionner")
	var sel := {}
	_boite(sel, Vector3i(-6, 1, -7), Vector3i(-1, 3, -4))
	_ecran._vue.regler_selection(sel)
	_ecran._choisir_outil("rect")
	var vue = _ecran._vue
	vue._commencer_coup(MOUSE_BUTTON_LEFT, vue._camera.unproject_position(Vector3(2.5, 1.0, 2.5)), false)
	vue._survoler(vue._camera.unproject_position(Vector3(7.5, 1.0, 5.5)))
	vue.hausser_le_glisse(1)
	await _images(8)
	_photo("infos_2_selection_et_glisse")
	vue._coup = -1
	vue._coin_boite = null
	vue._coin_fin = null
	vue._boite_vue.visible = false
	vue.vider_selection()
	# 3. De loin, la grille et ses lignes majeures ; le fantôme dans la salle.
	_ecran._choisir_outil("ajouter")
	_ecran._compteur_etage.value = 0
	_regarder(Vector3(0, 0, 0), 0.3, 1.0, 40.0)
	await _images(5)
	_survol(Vector3(10.5, 0.0, 6.5))
	await _images(8)
	_photo("infos_3_grille_de_loin")
	# 4. La grille locale, hors de la grille centrale.
	_regarder(Vector3(40, 0, 10), 0.2, 0.9, 22.0)
	await _images(5)
	_survol(Vector3(40.5, 0.0, 10.5))
	await _images(8)
	_photo("infos_4_grille_locale")
	if _reglages_avant == "":
		DirAccess.remove_absolute(REGLAGES)
	else:
		var g := FileAccess.open(REGLAGES, FileAccess.WRITE)
		g.store_string(_reglages_avant)
		g.close()
	quit(0)


func _images(n: int) -> void:
	for i in n:
		await process_frame


func _photo(nom: String) -> void:
	var img: Image = root.get_texture().get_image()
	var chemin: String = _dossier.path_join(nom + ".png")
	print("%s → %s (%s)" % [nom, chemin, "écrite" if img.save_png(chemin) == OK else "ERREUR"])
