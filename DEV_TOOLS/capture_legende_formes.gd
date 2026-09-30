extends SceneTree
## LA LÉGENDE DES FORMES, PHOTOGRAPHIÉE — l'atelier Witness avec son bandeau ouvert, une carte survolée,
## une carte cliquée, puis le bandeau replié.
##
## LANCEMENT — ⚠ AVEC FENÊTRE (le headless ne rend rien) :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/capture_legende_formes.gd -- --dossier=C:/chemin/des/captures
##
## ⚠ Comme `capture_app.gd` : un projet jetable, et `reglages.cfg` rendu tel quel à la fin.

const Projet := preload("res://app/projet.gd")
const REGLAGES := "user://reglages.cfg"
const JETABLE := "user://capture/capture.mbproj"

var _dossier := "D:/MarchingBlocks/ART/app"
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture/capture_witness.glb"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture/capture_witness.mbmesh"))
	var f := FileAccess.open(JETABLE, FileAccess.WRITE)
	f.store_string(Projet.vers_texte([Projet.couche("Rock")], 0))
	f.close()
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", JETABLE)
	r.save(REGLAGES)
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	_derouler()


func _derouler() -> void:
	await _images(20)
	_ecran._aller_a("witness")
	await _images(15)
	_photo("legende_1_ouverte")
	var leg = _ecran._legende_formes
	var cartes: Dictionary = {}
	for enfant in leg._rangee.get_children():
		if enfant.has_meta("carte"):
			cartes[enfant.get_meta("carte")["id"]] = enfant
	(cartes["arche"] as Control).mouse_entered.emit()
	await _images(5)
	_photo("legende_2_arche_survolee")
	(cartes["arche"] as Control).mouse_exited.emit()
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	(cartes["salle"] as Control).gui_input.emit(clic)
	(cartes["salle"] as Control).mouse_entered.emit()
	await _images(5)
	_photo("legende_3_salle_cadree")
	(cartes["salle"] as Control).mouse_exited.emit()
	# Les cartes de droite : on fait défiler le bandeau jusqu'au bout.
	(leg._rangee.get_parent() as ScrollContainer).scroll_horizontal = 100000
	await _images(5)
	_photo("legende_4_fin_du_bandeau")
	leg.basculer(false)
	await _images(30)
	_photo("legende_5_repliee")
	leg.basculer(true, false)

	# LE SENS INVERSE : un monde peint à la forme du témoin, habillé du témoin tranché.
	_ecran._aller_a("monde")
	_ecran._vue.monde().lot = load("res://addons/marchingblocks_core/blocs_maitres.gd").librairie()["lot"]
	_ecran._peindre_la_forme_du_temoin()
	var v = _ecran._vue
	v._cible = Vector3(7.3, 5.0, 3.6)
	v._azimut = 0.9
	v._elevation = 0.5
	v._distance = 18.0
	v._caler()
	await _images(10)
	_photo("provenance_0_rien")
	v._survoler(v.size * 0.5 + Vector2(0, 40))
	await _images(10)
	_photo("provenance_1_tuile_survolee")
	leg.voir()
	await _images(10)
	_photo("provenance_2_dans_le_temoin")
	if _reglages_avant != "":
		var f := FileAccess.open(REGLAGES, FileAccess.WRITE)
		f.store_string(_reglages_avant)
		f.close()
	quit(0)


func _images(n: int) -> void:
	for i in n:
		await process_frame


func _photo(nom: String) -> void:
	var img := root.get_texture().get_image()
	var chemin := _dossier.path_join(nom + ".png")
	var err := img.save_png(chemin)
	print("%s → %s" % [nom, chemin if err == OK else "ÉCHEC %d" % err])
