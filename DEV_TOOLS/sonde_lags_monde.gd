extends SceneTree
## SONDE AVEC FENÊTRE — « la sauvegarde de tout le monde à chaque opération fait lagger pour une toute petite
## opération » (Jordan, 1er octobre 2026). Mène l'appli sur un projet JETABLE qui porte les cases de
## `test.mbproj` (habillées par le témoin calculé), et découpe UN geste d'une case en ses parties :
## enregistrement, reconstruction de la couche, eau, images qui suivent. Ne conçoit rien, mesure.
##   godot --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_lags_monde.gd

const Projet := preload("res://app/projet.gd")
const REGLAGES := "user://reglages.cfg"
const JETABLE := "user://sonde_lags_monde/sonde.mbproj"
var _reglages_avant := ""
var _ecran: Control


func _initialize() -> void:
	if FileAccess.file_exists(REGLAGES):
		_reglages_avant = FileAccess.get_file_as_string(REGLAGES)
	var dossier := ProjectSettings.globalize_path("user://sonde_lags_monde")
	DirAccess.make_dir_recursive_absolute(dossier)
	for nom in DirAccess.get_files_at(dossier):
		DirAccess.remove_absolute(dossier.path_join(nom))
	var erreurs: Array = []
	var vrai: Dictionary = Projet.depuis_texte(FileAccess.get_file_as_string("res://test.mbproj"), erreurs)
	var c: Dictionary = Projet.couche("Rock")
	c["cases"] = vrai["couches"][0]["cases"]
	var f := FileAccess.open(JETABLE, FileAccess.WRITE)
	f.store_string(Projet.vers_texte([c], 0))
	f.close()
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", JETABLE)
	r.save(REGLAGES)
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	_derouler()


func _derouler() -> void:
	await _images(60)
	_ecran._aller_a("monde")
	await _images(30)
	var cases: Dictionary = _ecran._occupees()
	print("cases : %d" % cases.size())
	# Une case libre au-dessus de la plus haute case de la première colonne.
	var haut := Vector3i(0, -999, 0)
	for p in cases:
		if p.y > haut.y:
			haut = p
	var neuve := haut + Vector3i.UP
	for essai in 3:
		await _mesurer("poser UNE case (_appliquer, tout compris)", func():
			_ecran._appliquer({"poser": {neuve: true}}, "Add"))
		await _mesurer("Ctrl+Z", func(): _ecran._histoire.undo())
	print("— les parties, appelées à part —")
	var massif: Node = _ecran._vue.monde()
	for essai in 3:
		var t0 := Time.get_ticks_usec()
		_ecran._enregistrer()
		_trace("  _enregistrer (le .mbproj)", t0)
		t0 = Time.get_ticks_usec()
		massif.reconstruire()
		_trace("  massif.reconstruire()", t0)
		await _mesurer("  … les images qui suivent la reconstruction", func(): pass)
		t0 = Time.get_ticks_usec()
		_ecran._vue.rafraichir()
		_trace("  _vue.rafraichir()", t0)
		t0 = Time.get_ticks_usec()
		_ecran._recalculer_eau()
		_trace("  _recalculer_eau() (sans eau)", t0)
	if _reglages_avant != "":
		var f := FileAccess.open(REGLAGES, FileAccess.WRITE)
		f.store_string(_reglages_avant)
		f.close()
	quit(0)


func _mesurer(nom: String, geste: Callable) -> void:
	await process_frame
	var t0 := Time.get_ticks_usec()
	geste.call()
	var t_geste := (Time.get_ticks_usec() - t0) / 1000.0
	var pire := 0.0
	var somme := 0.0
	var avant := Time.get_ticks_usec()
	for k in 30:
		await process_frame
		var maintenant := Time.get_ticks_usec()
		var d := (maintenant - avant) / 1000.0
		avant = maintenant
		pire = maxf(pire, d)
		somme += maxf(0.0, d - 16.7)
	print("%-50s geste %7.1f ms · pire image %7.1f ms · retard cumulé %7.1f ms" % [nom, t_geste, pire, somme])


func _trace(nom: String, t0: int) -> void:
	print("%-50s %7.1f ms" % [nom, (Time.get_ticks_usec() - t0) / 1000.0])


func _images(n: int) -> void:
	for k in n:
		await process_frame
