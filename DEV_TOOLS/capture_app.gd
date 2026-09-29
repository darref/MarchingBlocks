extends SceneTree
##
## LA CAPTURE DU LOGICIEL — MarchingBlocks ouvert pour de vrai, photographié à trois moments.
##
## LANCEMENT — ⚠ AVEC FENÊTRE, jamais en headless (le headless ne rend RIEN) :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/capture_app.gd -- --dossier=C:/chemin/des/captures
##
## ⚠ **UN LOGICIEL NE SE JUGE PAS SUR SES TESTS** (charte §6 : « un greffon d'éditeur ne se teste pas en
## headless ») : que l'écran s'ouvre, que les panneaux tiennent, que le monde de test se peigne, ça se
## VOIT. Ce harnais ne clique pas à la place de Jordan : il appelle les mêmes fonctions que les boutons,
## et photographie ce qui en sort.

var _dossier := "D:/MarchingBlocks/ART/app"
var _ecran: Control


const Projet := preload("res://app/projet.gd")
const REGLAGES := "user://reglages.cfg"
const JETABLE := "user://capture/capture.mbproj"
var _reglages_avant := ""


## ⚠ LE PROJET DE L'UTILISATEUR N'EST JAMAIS TOUCHÉ : l'appli rouvre le dernier projet et s'enregistre
## à chaque geste. On la pointe sur un projet jetable, et on rend `reglages.cfg` tel quel à la fin.
func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--dossier="):
			_dossier = option.substr("--dossier=".length())
	DirAccess.make_dir_recursive_absolute(_dossier)
	if FileAccess.file_exists(REGLAGES):
		_reglages_avant = FileAccess.get_file_as_string(REGLAGES)
	DirAccess.make_dir_recursive_absolute("user://capture")
	# Un témoin modélisé laissé par une capture précédente serait rechargé : on part du témoin calculé.
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
	# ⚠ Rouvrir le projet mène au monde de test : on revient au témoin pour le photographier.
	_ecran._aller_a("projet")
	await _images(10)
	_photo("0_projet")
	_ecran._aller_a("witness")
	await _images(10)
	_photo("1_temoin")
	_ecran._plans.button_pressed = true
	await _images(10)
	_photo("1b_plans_de_coupe")
	_ecran._plans.button_pressed = false

	# LE MODELEUR : édition, une face choisie au centre, extrudée d'une case.
	var t0 := Time.get_ticks_msec()
	_ecran._regler_edition(true)
	print("entrée en édition : %d ms" % (Time.get_ticks_msec() - t0))
	_ecran._vue._distance = 14.0
	_ecran._vue.cadrer(Vector3(6, 8, 6))
	await _images(5)
	var mo = _ecran._modeleur
	var centre_vue: Vector2 = _ecran._vue.size * 0.5
	mo.cliquer(centre_vue, false)
	await _images(5)
	_photo("1c_modeleur_selection")
	t0 = Time.get_ticks_msec()
	mo.souris = centre_vue
	mo.commencer("E")
	mo._saisie = "1"
	mo._mettre_a_jour()
	mo.confirmer()
	print("extruder et redessiner : %d ms" % (Time.get_ticks_msec() - t0))
	await _images(5)
	_photo("1d_modeleur_extrude")
	# LE COÛT D'UN MOUVEMENT DE SOURIS PENDANT G : dix mises à jour.
	mo.cliquer(centre_vue, false)
	mo.commencer("G")
	t0 = Time.get_ticks_msec()
	for i in 10:
		mo.souris = centre_vue + Vector2(i * 3, 0)
		mo._mettre_a_jour()
	print("G : %.1f ms par mouvement de souris" % ((Time.get_ticks_msec() - t0) / 10.0))
	mo.annuler()
	for geste in ["I", "bevel"]:
		mo.cliquer(centre_vue, false)
		if geste == "bevel":
			mo.choisir_mode("arete")
		mo.commencer(geste)
		t0 = Time.get_ticks_msec()
		for i in 5:
			mo.souris = centre_vue + Vector2(10 + i * 4, 0)
			mo._mettre_a_jour()
		print("%s : %.1f ms par mouvement de souris" % [geste, (Time.get_ticks_msec() - t0) / 5.0])
		mo.annuler()
		mo.choisir_mode("face")
	mo.choisir_mode("arete")
	await _images(5)
	_photo("1e_modeleur_aretes")
	# UN MATÉRIAU TEXTURÉ, projeté sur toutes les faces du dessus.
	var image := ProjectSettings.globalize_path("res://HEART_WORLD/3D_TILESETS_FULL/SIMPLE_GROUND/TILES_3D_FACTORY/WALL_CORNER_SAMPLE/TILES3D_stone+well+3d+model_basecolor.jpg")
	var k: int = mo.nouveau_materiau()
	mo.regler_materiau(k, "texture", image)
	mo.regler_materiau(k, "couleur", Color.WHITE)
	mo.regler_materiau(k, "echelle", 0.5)
	mo.choisir_mode("face")
	mo.tout_choisir(false)
	for f in mo.maillage.faces.size():
		if mo.maillage.normale(f).y > 0.9:
			mo.sel_f[f] = true
	mo.assigner_courant()
	mo.tout_choisir(false)
	await _images(10)
	_photo("1f_modeleur_materiau")
	_ecran._regler_edition(false)

	await _ecran._trancher_temoin()
	_ecran._aller_a("monde")
	# Un petit monde : un plateau, une marche, un trou — posé par la seule entrée, `_appliquer`.
	var poser := {}
	for x in range(0, 8):
		for z in range(0, 6):
			poser[Vector3i(x, 0, z)] = true
	for x in range(2, 6):
		for z in range(1, 4):
			poser[Vector3i(x, 1, z)] = true
	poser.erase(Vector3i(3, 1, 2))
	poser.erase(Vector3i(3, 0, 2))
	_ecran._appliquer({"poser": poser, "effacer": {}}, "Capture")
	await _images(20)
	_photo("2_monde")

	# LE PLAY TEST : le personnage posé sur le plateau, puis en marche, puis de près.
	_ecran._vue._cible = Vector3(1.5, 1.0, 4.5)
	_ecran._aller_a("jeu")
	await _images(60)
	_photo("2b_play_test")
	_touche(KEY_W, true)
	await _images(14)
	_photo("2c_play_test_marche")
	_touche(KEY_W, false)
	_touche(KEY_SPACE, true)
	await _images(10)
	_touche(KEY_SPACE, false)
	_photo("2d_play_test_saut")
	await _images(60)
	_ecran._vue._distance = 1.6
	await _images(20)
	_photo("2e_play_test_pres")
	# DE FACE : les yeux violets ne se voient que de là — la caméra passe devant lui.
	_ecran._vue._azimut += PI
	await _images(20)
	_photo("2f_play_test_face")
	_ecran._aller_a("monde")
	await _images(5)

	# La barre d'outils : visée Sculpt, une sélection, et l'aperçu d'un pinceau sous une souris posée.
	_ecran._choisir_visee("sculpt")
	_ecran._vue.regler_selection({Vector3i(2, 1, 1): true, Vector3i(3, 1, 1): true, Vector3i(4, 1, 1): true})
	_ecran._taille.value = 2
	var cam: Camera3D = _ecran._vue._camera
	_ecran._vue._survoler(cam.unproject_position(Vector3(6.5, 0.9, 3.5)))
	await _images(20)
	_photo("3_sculpt_selection")

	_ecran._choisir_outil("creuser")
	_ecran._vue._survoler(cam.unproject_position(Vector3(4.5, 1.9, 2.5)))
	await _images(20)
	_photo("4_sculpt_creuser")

	_ecran._choisir_visee("grille")
	_ecran._choisir_outil("ajouter")
	_ecran._taille.value = 1
	# ⚠ On RECULE la caméra : à la distance par défaut, x = 30 tombe hors du cadre.
	_ecran._vue._distance = 75.0
	_ecran._vue._caler()
	var hors: Vector2 = cam.unproject_position(Vector3(30.5, 0.0, 4.5))
	_ecran._vue._survoler(hors)
	print("grille locale visible : %s, sous %s" % [_ecran._vue._grille_locale.visible, hors])
	await _images(20)
	_photo("5_grille_locale")

	# Phase 3 : une boîte en cours de tracé, puis un collage qui suit la souris.
	_ecran._vue._distance = 26.0
	_ecran._vue._caler()
	_ecran._choisir_visee("sculpt")
	_ecran._choisir_outil("boite")
	_ecran._vue.vider_selection()
	_ecran._vue._coin_boite = Vector3i(1, 0, 0)
	_ecran._vue._coin_fin = Vector3i(5, 1, 3)
	_ecran._vue._survoler_boite(cam.unproject_position(Vector3(5.5, 2.0, 3.5)))
	await _images(20)
	_photo("6_boite")
	_ecran._vue._finir_boite(MOUSE_BUTTON_LEFT)
	_ecran._copier()
	_ecran._coller()
	_ecran._vue._survoler(cam.unproject_position(Vector3(-3.5, 0.0, 2.5)))
	await _images(20)
	_photo("7_collage")

	_ecran._vue.annuler_collage()
	_ecran._manuel.ouvrir(1)
	await _images(10)
	_photo("8_manuel")
	_ecran._manuel.ouvrir(3)
	await _images(10)
	_photo("8b_manuel_modeleur")
	_ecran._manuel.ouvrir(5)
	await _images(10)
	_photo("8c_manuel_raccourcis")

	_ecran.queue_free()
	await process_frame
	if _reglages_avant == "":
		DirAccess.remove_absolute(REGLAGES)
	else:
		var g := FileAccess.open(REGLAGES, FileAccess.WRITE)
		g.store_string(_reglages_avant)
		g.close()
	DirAccess.remove_absolute(JETABLE)
	quit(0)


func _touche(touche: Key, appuyee: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = touche
	e.keycode = touche
	e.pressed = appuyee
	Input.parse_input_event(e)


func _images(n: int) -> void:
	for i in n:
		await process_frame


func _photo(nom: String) -> void:
	var img: Image = root.get_texture().get_image()
	var chemin: String = _dossier.path_join(nom + ".png")
	var err := img.save_png(chemin)
	print("%s → %s (%dx%d, %s)" % [nom, chemin, img.get_width(), img.get_height(),
		"écrite" if err == OK else "ERREUR %d" % err])
