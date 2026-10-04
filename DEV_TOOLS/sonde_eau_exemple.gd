extends SceneTree
## SONDE AVEC FENÊTRE — les gestes de l'eau sur l'EXEMPLE (4 octobre 2026 : 3 couches d'eau, 106 sources, une mer de
## 2,4 millions de cases) : poser une rivière en haut d'une colonne, Ctrl+Z, Ctrl+Y, la retirer au clic droit, Ctrl+Z.
## Chaque geste : son temps et la pire image des 30 suivantes (le recalcul est différé à l'image suivante). Exemple
## installé dans un dossier jetable, réglages rendus. Ne conçoit rien, mesure.
##   godot --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_eau_exemple.gd

const Exemple := preload("res://app/exemple.gd")
const REGLAGES := "user://reglages.cfg"
const DOSSIER := "user://sonde_eau_exemple"
var _reglages_avant := ""
var _ecran: Control
var _chemin := ""


func _initialize() -> void:
	if FileAccess.file_exists(REGLAGES):
		_reglages_avant = FileAccess.get_file_as_string(REGLAGES)
	var erreurs: Array = []
	_chemin = Exemple.installer(Exemple.ARCHIVE, DOSSIER, erreurs)
	var r := ConfigFile.new()
	r.save(REGLAGES)
	load("res://app/editor.gd").racine_exemple = DOSSIER
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	_derouler.call_deferred()


func _derouler() -> void:
	for i in 10:
		await process_frame
	await _ecran._ouvrir(_chemin)
	await _ecran._changer_d_atelier("fluides")
	for i in 60:
		await process_frame
	# La plus haute colonne : une rivière qui y naît coule jusqu'en bas.
	var haut := Vector3i(0, -999, 0)
	for c in _ecran._occupees_du_monde():
		if c.y > haut.y:
			haut = c
	var s := haut + Vector3i.UP
	_ecran._eau_active = 0
	var n_avant: int = (_ecran._eaux[0]["sources"] as Array).size()
	await _mesurer("poser une rivière en %s" % s, func(): _ecran._eau_cliquee(s, MOUSE_BUTTON_LEFT))
	var r: Dictionary = _ecran._corps_eau[0][n_avant] if (_ecran._corps_eau[0] as Array).size() > n_avant else {}
	print("   → %s, %d cases de cours" % [r.get("genre", "?"), (r.get("cours", []) as Array).size()])
	await _mesurer("Ctrl+Z", func(): _ecran._histoire.undo())
	await _mesurer("Ctrl+Y", func(): _ecran._histoire.redo())
	await _mesurer("la retirer (clic droit)", func(): _ecran._eau_cliquee(s, MOUSE_BUTTON_RIGHT))
	await _mesurer("Ctrl+Z", func(): _ecran._histoire.undo())
	await _mesurer("Ctrl+Z (la pose)", func(): _ecran._histoire.undo())
	_ecran.queue_free()
	await process_frame
	var f := FileAccess.open(REGLAGES, FileAccess.WRITE)
	f.store_string(_reglages_avant)
	f.close()
	quit()


func _mesurer(nom: String, geste: Callable) -> void:
	await process_frame
	var t0 := Time.get_ticks_usec()
	await geste.call()
	var t_geste := (Time.get_ticks_usec() - t0) / 1000.0
	var pire := 0.0
	var avant := Time.get_ticks_usec()
	for k in 30:
		await process_frame
		var maintenant := Time.get_ticks_usec()
		pire = maxf(pire, (maintenant - avant) / 1000.0)
		avant = maintenant
	print("%-40s geste %8.1f ms · pire image %7.1f ms" % [nom, t_geste, pire])
