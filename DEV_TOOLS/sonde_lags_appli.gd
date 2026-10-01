extends SceneTree
## SONDE AVEC FENÊTRE — les « lags d'environ une seconde à des moments différents » du modeleur (Jordan,
## 1er octobre 2026). Mène l'appli sur un projet JETABLE (le vrai dernier projet n'est pas rouvert, les
## réglages sont rendus à la fin) et relève la durée de CHAQUE image après chaque geste : le pire, et la somme.
##   godot --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_lags_appli.gd
## ⚠ Avec fenêtre : le coût de rendu (photos de la planche, vignettes, compilation de shaders) n'existe pas en
## headless.

const Projet := preload("res://app/projet.gd")
const REGLAGES := "user://reglages.cfg"
const JETABLE := "user://sonde_lags_appli/sonde.mbproj"
var _reglages_avant := ""
var _ecran: Control


func _initialize() -> void:
	if FileAccess.file_exists(REGLAGES):
		_reglages_avant = FileAccess.get_file_as_string(REGLAGES)
	var dossier := ProjectSettings.globalize_path("user://sonde_lags_appli")
	DirAccess.make_dir_recursive_absolute(dossier)
	for nom in DirAccess.get_files_at(dossier):
		DirAccess.remove_absolute(dossier.path_join(nom))
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
	await _images(30)
	_ecran._aller_a("witness")
	await _images(20)
	await _mesurer("entrer en édition", func(): _ecran._regler_edition(true))
	_ecran._vue._distance = 14.0
	_ecran._vue.cadrer(Vector3(6, 8, 6))
	await _images(10)
	var mo = _ecran._modeleur
	var centre: Vector2 = _ecran._vue.size * 0.5
	mo.mode_sel = "face"
	await _mesurer("clic : choisir une face", func(): mo.cliquer(centre, false))
	await _mesurer("clic : une autre face, ailleurs", func(): mo.cliquer(centre + Vector2(120, 40), false))
	await _mesurer("Maj+clic : en ajouter une", func(): mo.cliquer(centre + Vector2(-90, 30), true))
	await _mesurer("A : tout choisir", func(): mo.tout_choisir(true))
	await _mesurer("Alt+A : ne rien choisir", func(): mo.tout_choisir(false))
	mo.cliquer(centre, false)
	await _images(5)
	await _mesurer("nouveau matériau", func(): mo.nouveau_materiau())
	await _mesurer("assigner le matériau", func(): mo.assigner_courant())
	await _mesurer("subdiviser", func():
		mo.cliquer(centre, false)
		mo.operer("subdiviser"))
	await _mesurer("extruder de 0,1", func():
		mo.cliquer(centre, false)
		if mo.commencer("E"):
			mo._saisie = "0.1"
			mo._mettre_a_jour()
			mo.confirmer())
	# L'enregistrement différé : la minuterie d'une seconde, puis ce qu'il déclenche.
	print("— l'enregistrement différé, appelé à part —")
	var t0 := Time.get_ticks_usec()
	var c: Dictionary = _ecran._couches[_ecran._active]
	var tt = c.get("_temoin")
	var texte := JSON.stringify(tt.vers_dictionnaire())
	_trace("  vers_dictionnaire + JSON", t0)
	t0 = Time.get_ticks_usec()
	tt.vers_glb(_ecran._glb_du_temoin(c))
	_trace("  vers_glb", t0)
	t0 = Time.get_ticks_usec()
	_ecran._suivre_son_temoin(c)
	_trace("  _suivre_son_temoin (relire + le monde reposé)", t0)
	await _mesurer("  … les images qui suivent", func(): pass)
	t0 = Time.get_ticks_usec()
	_ecran._legende_formes.rafraichir_tuiles()
	_trace("  rafraichir_tuiles (planche)", t0)
	await _mesurer("  … les images qui suivent", func(): pass)
	t0 = Time.get_ticks_usec()
	_ecran._oublier_la_vignette(c)
	_ecran._rafraichir_couches()
	_trace("  vignette + _rafraichir_couches", t0)
	await _mesurer("  … les images qui suivent", func(): pass)
	t0 = Time.get_ticks_usec()
	_ecran._enregistrer()
	_trace("  _enregistrer (le .mbproj)", t0)
	await _mesurer("ENREGISTREMENT COMPLET (_enregistrer_le_temoin_modele)", func(): _ecran._enregistrer_le_temoin_modele())
	if not texte.is_empty():
		pass
	var r := ConfigFile.new()
	if _reglages_avant != "":
		var f := FileAccess.open(REGLAGES, FileAccess.WRITE)
		f.store_string(_reglages_avant)
		f.close()
	quit(0)


## Lance `geste`, puis relève les 30 images suivantes : le temps du geste lui-même, la pire image, la somme.
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
	print("%-58s geste %7.1f ms · pire image %7.1f ms · retard cumulé %7.1f ms" % [nom, t_geste, pire, somme])


func _trace(nom: String, t0: int) -> void:
	print("%-58s %7.1f ms" % [nom, (Time.get_ticks_usec() - t0) / 1000.0])


func _images(n: int) -> void:
	for k in n:
		await process_frame
