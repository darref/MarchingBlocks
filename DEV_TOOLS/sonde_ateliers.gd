extends SceneTree
## SONDE AVEC FENÊTRE — changer d'atelier sur l'EXEMPLE (4 octobre 2026) : entrer dans le Play test (le décor foulé est
## bâti à l'entrée), en sortir, y revenir ; Geometry, Texturing, Fluids. Chaque passage : le geste et la pire image des
## 30 suivantes. Exemple installé dans un dossier jetable, réglages rendus. Ne conçoit rien, mesure.
##   godot --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_ateliers.gd

const Exemple := preload("res://app/exemple.gd")
const REGLAGES := "user://reglages.cfg"
const DOSSIER := "user://sonde_ateliers"
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
	for i in 60:
		await process_frame   # l'eau différée, les vignettes
	for atelier in ["jeu", "monde", "jeu", "monde", "witness", "texture", "monde", "fluides", "monde"]:
		await _mesurer("vers %s" % atelier, func(): await _ecran._changer_d_atelier(atelier))
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
	print("%-30s geste %8.1f ms · pire image %7.1f ms" % [nom, t_geste, pire])
