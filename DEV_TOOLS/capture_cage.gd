extends SceneTree
##
## LA CAGE DE LA TUILE, À L'IMAGE (Jordan, 10 octobre 2026). AVEC FENÊTRE, jamais en headless :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks --script res://DEV_TOOLS/capture_cage.gd -- --dossier=…
## Le projet de l'utilisateur n'est jamais touché : un projet jetable, `reglages.cfg` rendu tel quel à la fin.

const Projet := preload("res://app/projet.gd")
const REGLAGES := "user://reglages.cfg"
const JETABLE := "user://capture/cage.mbproj"
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


func _derouler() -> void:
	await _images(20)
	_ecran._aller_a("witness")
	_ecran._regler_edition(false)
	for nom in ["neutre", "epais", "aminci"]:
		(_ecran._boutons_cran[nom] as Button).pressed.emit()
		await _images(5)
		_ecran._vue._distance = 16.0
		_ecran._vue.cadrer(Vector3(5.5, 8.0, 5.5))
		await _images(3)
		var ecran: Vector2 = (_ecran._vue as Control).get_global_rect().get_center() + Vector2(40, 30)
		var survol := InputEventMouseMotion.new()
		survol.position = ecran
		survol.global_position = ecran
		root.push_input(survol)
		await _images(6)
		_photo("cage_" + nom)
	(_ecran._boutons_cran["neutre"] as Button).pressed.emit()
	_ecran._regler_edition(true)
	await _images(10)
	_photo("cage_edition")
	_ecran._regler_edition(false)
	await _images(3)
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
