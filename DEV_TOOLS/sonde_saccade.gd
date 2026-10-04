extends SceneTree
## SONDE AVEC FENÊTRE — la saccade d'une seconde après CHAQUE geste (4 octobre 2026 : `sonde_lags_edition` mesure
## ~1 050 ms de pire image après poser une case, Ctrl+Z, un coup de pinceau…). Horodate chaque image après un geste,
## dit quand la minuterie d'enregistrement part, et chronomètre à part chaque morceau de l'enregistrement.
## Ne conçoit rien, mesure. Même installation jetable que `sonde_lags_edition.gd`.
##   godot --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_saccade.gd

const Exemple := preload("res://app/exemple.gd")
const Projet := preload("res://app/projet.gd")
const REGLAGES := "user://reglages.cfg"
const DOSSIER := "user://sonde_saccade"
const SAUVEGARDE := "user://reglages.cfg.avant_sonde"
var _reglages_avant := ""
var _ecran: Control
var _chemin := ""
var _t_geste := 0


func _initialize() -> void:
	if FileAccess.file_exists(SAUVEGARDE):
		DirAccess.copy_absolute(SAUVEGARDE, REGLAGES)
	if FileAccess.file_exists(REGLAGES):
		_reglages_avant = FileAccess.get_file_as_string(REGLAGES)
		DirAccess.copy_absolute(REGLAGES, SAUVEGARDE)
	var erreurs: Array = []
	_chemin = Exemple.installer(Exemple.ARCHIVE, DOSSIER, erreurs)
	if _chemin == "":
		print("⚠ l'exemple ne s'installe pas : %s" % [erreurs])
		_rendre()
		quit(1)
		return
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", _chemin)
	r.save(REGLAGES)
	load("res://app/editor.gd").racine_exemple = DOSSIER
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	_derouler.call_deferred()


func _derouler() -> void:
	for i in 30:
		await process_frame
	await _ecran._ouvrir(_chemin)
	_ecran._changer_d_atelier("monde")
	for i in 60:
		await process_frame
	_ecran._minuterie_projet.timeout.connect(func() -> void:
		print("    [minuterie du projet à +%d ms]" % (Time.get_ticks_msec() - _t_geste)))
	var occ: Dictionary = _ecran._occupees()
	var haut := Vector3i(0, -999, 0)
	for p in occ:
		if p.y > haut.y:
			haut = p
	var neuve := haut + Vector3i.UP
	for essai in 2:
		print("── poser une case (essai %d)" % essai)
		_t_geste = Time.get_ticks_msec()
		_ecran._appliquer({"poser": {neuve: true}, "effacer": {}}, "Add")
		await _horodater(110)
		_ecran._histoire.undo()
		await _horodater(110)

	print("── le recalcul de l'eau, étape par étape (les étapes de `_recalculer_eau`, rejouées)")
	var FL = load("res://addons/marchingblocks_core/fluides.gd")
	var EM = load("res://addons/marchingblocks_core/eau_maillage.gd")
	for essai in 2:
		_ecran._appliquer({"poser": {neuve: true}, "effacer": {}}, "Add")
		var toutes: Array = []
		for e in _ecran._eaux:
			toutes.append_array(e["sources"])
		var t0 := Time.get_ticks_usec()
		_ecran._tenir_occ_eau()
		print("  _tenir_occ_eau : %d ms" % ((Time.get_ticks_usec() - t0) / 1000))
		var changees: Variant = null if _ecran._eau_tout_refaire else _ecran._eau_changees_vues
		print("  changées vues : %s, tout refaire : %s" % [str((changees as Dictionary).size()) if changees != null else "null", _ecran._eau_tout_refaire])
		t0 = Time.get_ticks_usec()
		var w: Dictionary = FL.monde(_ecran._occ_eau, toutes, FL.VOLUME_MAXI, _ecran._monde_eau, changees)
		print("  FL.monde : %d ms" % ((Time.get_ticks_usec() - t0) / 1000))
		var repris := 0
		var avant: Dictionary = _ecran._monde_eau
		if avant.has("corps"):
			for j in (w["corps"] as Array).size():
				if j < (avant["corps"] as Array).size() and is_same(w["corps"][j], avant["corps"][j]):
					repris += 1
		print("  corps repris tels quels : %d / %d" % [repris, (w["corps"] as Array).size()])
		var k := 0
		for i in _ecran._eaux.size():
			var n: int = (_ecran._eaux[i]["sources"] as Array).size()
			var corps: Array = (w["corps"] as Array).slice(k, k + n)
			k += n
			t0 = Time.get_ticks_usec()
			EM.maillage(corps, _ecran._occ_eau)
			print("  maillage couche d'eau %d (%d sources) : %d ms" % [i, n, (Time.get_ticks_usec() - t0) / 1000])
		t0 = Time.get_ticks_usec()
		await _ecran._recalculer_eau(false)
		print("  _recalculer_eau entier : %d ms" % ((Time.get_ticks_usec() - t0) / 1000))
		t0 = Time.get_ticks_usec()
		_ecran._rafraichir_eaux()
		print("  _rafraichir_eaux seul : %d ms" % ((Time.get_ticks_usec() - t0) / 1000))
		for i in 5:
			await process_frame
		_ecran._histoire.undo()
		for i in 5:
			await process_frame
	print("── chacun des deux travaux différés, chronométré seul")
	for essai in 2:
		_ecran._appliquer({"poser": {neuve: true}, "effacer": {}}, "Add")
		var t0 := Time.get_ticks_usec()
		_ecran._rafraichir_couches()
		print("  _rafraichir_couches : %d ms" % ((Time.get_ticks_usec() - t0) / 1000))
		t0 = Time.get_ticks_usec()
		await _ecran._recalculer_eau(false)
		print("  _recalculer_eau : %d ms (couches d'eau %d, sources %d)" % [(Time.get_ticks_usec() - t0) / 1000,
			_ecran._eaux.size(), _ecran._eaux.reduce(func(n, e): return n + (e["sources"] as Array).size(), 0)])
		for i in 5:
			await process_frame
		_ecran._histoire.undo()
		for i in 5:
			await process_frame
	_ecran.queue_free()
	await process_frame
	_rendre()
	quit()
	return
	print("── les morceaux de l'enregistrement, chronométrés à part")
	var t := Time.get_ticks_usec()
	var sorties: Array = []
	for i in _ecran._couches.size():
		var t1 := Time.get_ticks_usec()
		var cases: Array = (_ecran._vue.couche(i).get_node("Cases") as GridMap).get_used_cells()
		print("  get_used_cells couche %d : %d cases, %d ms" % [i, cases.size(), (Time.get_ticks_usec() - t1) / 1000])
		var c: Dictionary = _ecran._couches[i]
		t1 = Time.get_ticks_usec()
		var poids: Dictionary = (_ecran._vue.couche(i).poids as Dictionary).duplicate(true)
		var choix: Dictionary = (_ecran._vue.couche(i).choix as Dictionary).duplicate()
		print("  poids / choix couche %d : %d / %d, %d ms" % [i, poids.size(), choix.size(), (Time.get_ticks_usec() - t1) / 1000])
		sorties.append({"nom": c["nom"], "source": c["source"], "visible": c["visible"], "temoin": c.get("temoin", ""),
			"id": c.get("id", ""), "cases": cases, "poids": poids, "choix": choix})
	t = Time.get_ticks_usec()
	var eaux: Array = _ecran._eaux.duplicate(true)
	print("  eaux dupliquées : %d ms" % ((Time.get_ticks_usec() - t) / 1000))
	t = Time.get_ticks_usec()
	var texte := Projet.vers_texte(sorties, _ecran._active, eaux, [])
	print("  vers_texte : %d octets, %d ms" % [texte.length(), (Time.get_ticks_usec() - t) / 1000])
	t = Time.get_ticks_usec()
	_ecran._enregistrer(true)
	print("  _enregistrer(true), part du fil principal : %d ms" % ((Time.get_ticks_usec() - t) / 1000))
	t = Time.get_ticks_usec()
	_ecran._attendre_l_ecriture()
	print("  … puis attente de l'autre fil : %d ms" % ((Time.get_ticks_usec() - t) / 1000))
	t = Time.get_ticks_usec()
	_ecran._enregistrer(false)
	print("  _enregistrer(false), tout sur le fil principal : %d ms" % ((Time.get_ticks_usec() - t) / 1000))
	_ecran.queue_free()
	await process_frame
	_rendre()
	quit()


## Chaque image de plus de 50 ms après le geste, avec son instant.
func _horodater(images: int) -> void:
	var avant := Time.get_ticks_usec()
	for i in images:
		await process_frame
		var maintenant := Time.get_ticks_usec()
		var d := (maintenant - avant) / 1000.0
		if d > 50.0:
			print("    image %3d à +%5d ms : %6.1f ms · process %.0f · physique %.0f · rendu cpu %.1f · objets %d" % [i,
				Time.get_ticks_msec() - _t_geste, d, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				RenderingServer.get_frame_setup_time_cpu(), Performance.get_monitor(Performance.OBJECT_COUNT)])
		avant = maintenant


func _rendre() -> void:
	if _reglages_avant != "":
		var f := FileAccess.open(REGLAGES, FileAccess.WRITE)
		f.store_string(_reglages_avant)
		f.close()
	if FileAccess.file_exists(SAUVEGARDE):
		DirAccess.remove_absolute(SAUVEGARDE)
