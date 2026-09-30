extends SceneTree
## LE MODELEUR DU TÉMOIN LIÉ, PHOTOGRAPHIÉ — une face de la paroi à l'air libre tirée d'une demi-case :
## toutes les copies de la tuile suivent. Et le coût d'un mouvement de souris pendant le geste.
##
## LANCEMENT — ⚠ AVEC FENÊTRE :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/capture_modeleur_lie.gd -- --dossier=C:/captures
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
	for reste in ["user://capture/capture_witness.glb", "user://capture/capture_witness.mbtiles"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(reste))
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
	var t0 := Time.get_ticks_msec()
	_ecran._regler_edition(true)
	print("entrée en édition : %d ms" % (Time.get_ticks_msec() - t0))
	var v = _ecran._vue
	v._cible = Vector3(6.0, 5.0, 6.0)
	v._azimut = 0.75
	v._elevation = 0.45
	v._distance = 22.0
	v._caler()
	await _images(10)
	_photo("modeleur_lie_1_edition")

	var mo = _ecran._modeleur
	# La paroi à l'air libre : l'occurrence en édition au départ ; on choisit ses faces tournées vers +Z local.
	mo.choisir_mode("face")
	mo.tout_choisir(false)
	for g in mo.maillage.faces.size():
		if mo.maillage.normale(g).dot(Vector3(0, 0, 1)) > 0.9 or mo.maillage.normale(g).dot(Vector3(0, 0, -1)) > 0.9:
			mo.sel_f[g] = true
	mo._dessiner_selection()
	mo.souris = v.size * 0.5
	mo.commencer("G")
	var pires := 0
	var total := 0
	for k in 10:
		mo.souris = v.size * 0.5 + Vector2(0, -8.0 * k)
		var t1 := Time.get_ticks_usec()
		mo._mettre_a_jour()
		var dt := Time.get_ticks_usec() - t1
		total += dt
		pires = maxi(pires, dt)
	print("G sur « %s » (%d faces, %d copies) : %.1f ms par mouvement en moyenne, %.1f au pire"
		% [mo.cle, mo.maillage.faces.size(), mo.temoin.occurrences_de(mo.cle).size(), total / 10000.0, pires / 1000.0])
	mo._saisie = "0.5"
	mo._axe = "y"
	mo._mettre_a_jour()
	mo.confirmer()
	await _images(10)
	_photo("modeleur_lie_2_paroi_tiree")

	# LA PLANCHE DES TUILES : l'onglet ouvert, puis la paroi survolée (ses copies allumées dans la vue).
	_ecran._regler_edition(false)
	var leg = _ecran._legende_formes
	leg.montrer_onglet("tuiles")
	await _images(10)
	_photo("planche_1_ouverte")
	(leg.planche.cartes["mb_plaque_b2h2_dehors"]["fond"] as Control).mouse_entered.emit()
	await _images(5)
	_photo("planche_2_paroi_survolee")
	(leg.planche.cartes["mb_plaque_b2h2_dehors"]["fond"] as Control).mouse_exited.emit()
	leg.planche.scroll_horizontal = 100000
	await _images(5)
	_photo("planche_3_fin")

	if _reglages_avant != "":
		var g2 := FileAccess.open(REGLAGES, FileAccess.WRITE)
		g2.store_string(_reglages_avant)
		g2.close()
	_ecran._minuterie_temoin.stop()
	quit(0)


func _images(n: int) -> void:
	for i in n:
		await process_frame


func _photo(nom: String) -> void:
	var img := root.get_texture().get_image()
	var chemin := _dossier.path_join(nom + ".png")
	var err := img.save_png(chemin)
	print("%s → %s" % [nom, chemin if err == OK else "ÉCHEC %d" % err])
