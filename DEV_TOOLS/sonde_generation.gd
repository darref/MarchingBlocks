extends SceneTree
## LA SONDE DU GÉNÉRATEUR (19 octobre 2026, la 1.0.0) — la preuve À L'IMAGE que la fumée ne donne pas : un projet aux
## couches texturées ouvert pour de vrai, l'atelier Generate mené par l'écran, puis le monde généré photographié de haut,
## de biais, et au Play test.
##
## LANCEMENT — ⚠ AVEC FENÊTRE, sur une COPIE du projet (le monde généré remplace le sien, et l'appli s'enregistre) :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_generation.gd -- \
##       --projet=<copie>.mbproj --dossier=<photos> [--champs=<json>]
## ⚠ Ne pas l'interrompre : il rend `reglages.cfg` à la fin.

const G := preload("res://app/generateur.gd")
const REGLAGES := "user://reglages.cfg"
var _projet := ""
var _dossier := ""
var _champs := {}
var _reglages_avant := ""
var _ecran: Control


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--projet="):
			_projet = option.substr("--projet=".length())
		elif option.begins_with("--dossier="):
			_dossier = option.substr("--dossier=".length())
		elif option.begins_with("--champs="):
			_champs = JSON.parse_string(option.substr("--champs=".length()))
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
	await _ecran._changer_d_atelier("generer")
	var ag: RefCounted = _ecran._generation
	ag.champs = G.champs(_champs)
	ag.apercu()
	await _images(5)
	(ag._image.texture as ImageTexture).get_image().save_png(_dossier.path_join("0_apercu.png"))
	_photo("1_atelier")
	var cible: Dictionary = ag.couches_par_role()
	var noms := {}
	for r in cible:
		noms[r] = _ecran._couches[cible[r]]["nom"] if int(cible[r]) >= 0 else "-"
	print("GÉNÉRATION : rôles → couches ", noms)
	var t0 := Time.get_ticks_msec()
	await ag.generer()
	print("GÉNÉRATION : posée en %d ms — %s" % [Time.get_ticks_msec() - t0, ag._bilan.text])
	await _ecran._changer_d_atelier("monde")
	await _images(60)
	var vue = _ecran._vue
	vue.cadrer_toute_la_matiere()
	await _images(20)
	_photo("2_monde_entier")
	var w: float = float(ag.champs["largeur"])
	for k in 3:
		vue._azimut = 0.7 + k * 2.1
		vue._elevation = 0.45
		vue._cible = Vector3(0, float(ag.champs["mer"]) + 4.0, 0)
		vue._distance = w * 0.75
		vue._caler()
		await _images(15)
		_photo("3_biais_%d" % k)
	# Le Play test, sur la première place.
	var m := G.generer(ag.champs, true)
	if not (m["lieux"] as Array).is_empty():
		var l: Vector3i = m["lieux"][0]
		vue._cible = Vector3(l.x, l.y + 1, l.z)
		vue._caler()
		await _ecran._changer_d_atelier("jeu")
		await _images(150)
		_photo("4_play_test")
		await _ecran._changer_d_atelier("monde")
	_finir(0)


func _photo(nom: String) -> void:
	_ecran.get_viewport().get_texture().get_image().save_png(_dossier.path_join(nom + ".png"))


func _images(n: int) -> void:
	for i in n:
		await process_frame


func _finir(code: int) -> void:
	_ecran._enregistrer()
	_ecran._attendre_l_ecriture()
	if _reglages_avant != "":
		var f := FileAccess.open(REGLAGES, FileAccess.WRITE)
		f.store_string(_reglages_avant)
		f.close()
	quit(code)
