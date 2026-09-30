extends SceneTree
## LE TÉMOIN LIÉ DANS L'APPLI, PHOTOGRAPHIÉ — l'étape 1 (Export), l'étape 2 (Import d'un travail revenu
## de Blender), l'étape 3 (Slice), puis le monde peint à la forme du témoin avec ces tuiles.
##
## LANCEMENT — ⚠ AVEC FENÊTRE (le panneau d'attente guette `frame_post_draw`, qui ne vient pas en headless) :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/capture_temoin_lie.gd -- --dossier=C:/captures --travail=C:/…/temoin_lie_blender.glb
##
## `--travail` : un témoin lié revenu de Blender (`sonde_copies_liees`). Sans lui, on réimporte l'export.
## ⚠ Comme `capture_app.gd` : un projet jetable, et `reglages.cfg` rendu tel quel à la fin.

const Projet := preload("res://app/projet.gd")
const REGLAGES := "user://reglages.cfg"
const JETABLE := "user://capture/capture.mbproj"

var _dossier := "D:/MarchingBlocks/ART/app"
var _travail := ""
var _ecran: Control
var _reglages_avant := ""


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--dossier="):
			_dossier = option.substr("--dossier=".length())
		if option.begins_with("--travail="):
			_travail = option.substr("--travail=".length())
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


func _derouler() -> void:
	await _images(20)
	_ecran._aller_a("projet")
	var export := ProjectSettings.globalize_path("user://capture/temoin_lie.glb")
	await _ecran._exporter(export)
	await _images(5)
	print("RAPPORT export :\n", _ecran._rapport.text)
	_photo("lie_1_export")

	var travail: String = _travail if _travail != "" else export
	await _ecran._importer(travail)
	await _images(10)
	print("RAPPORT import :\n", _ecran._rapport.text)
	_photo("lie_2_import")

	await _ecran._trancher_travail()
	await _images(5)
	print("RAPPORT slice :\n", _ecran._rapport.text)
	_ecran._peindre_la_forme_du_temoin()
	var v = _ecran._vue
	v._cible = Vector3(6.0, 5.0, 6.0)
	v._azimut = 0.8
	v._elevation = 0.55
	v._distance = 24.0
	v._caler()
	await _images(10)
	_photo("lie_3_monde")

	if _reglages_avant != "":
		var g := FileAccess.open(REGLAGES, FileAccess.WRITE)
		g.store_string(_reglages_avant)
		g.close()
	quit(0)


func _images(n: int) -> void:
	for i in n:
		await process_frame


func _photo(nom: String) -> void:
	var img := root.get_texture().get_image()
	var chemin := _dossier.path_join(nom + ".png")
	var err := img.save_png(chemin)
	print("%s → %s" % [nom, chemin if err == OK else "ÉCHEC %d" % err])
