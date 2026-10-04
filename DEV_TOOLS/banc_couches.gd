extends SceneTree
## BANC (headless) — cacher / montrer une couche sur l'EXEMPLE (4 octobre 2026 : 7,3 s sur le PC). Ouvre l'exemple
## dans l'appli (installé dans un dossier jetable, réglages rendus), puis chronomètre : la reconstruction complète de
## chaque couche, la reconstruction « autour » des cases d'une autre couche, et le geste entier. Ne conçoit rien.
##   godot --headless --path . --script res://DEV_TOOLS/banc_couches.gd

const Exemple := preload("res://app/exemple.gd")
const REGLAGES := "user://reglages.cfg"
const DOSSIER := "user://banc_couches"
var _reglages_avant := ""
var _ecran: Control
var _chemin := ""


func _initialize() -> void:
	if FileAccess.file_exists(REGLAGES):
		_reglages_avant = FileAccess.get_file_as_string(REGLAGES)
	var erreurs: Array = []
	_chemin = Exemple.installer(Exemple.ARCHIVE, DOSSIER, erreurs)
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", _chemin)
	r.save(REGLAGES)
	load("res://app/editor.gd").racine_exemple = DOSSIER
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	_derouler.call_deferred()


func _derouler() -> void:
	for i in 10:
		await process_frame
	await _ecran._ouvrir(_chemin)
	_ecran._aller_a("monde")
	for i in 5:
		await process_frame
	var vue = _ecran._vue
	for i in vue.nombre_de_couches():
		var n: int = (vue.couche(i).get_node("Cases") as GridMap).get_used_cells().size()
		print("couche %d « %s » : %d cases, rang %d" % [i, _ecran._couches[i]["nom"], n, vue.couche(i).rang])
	for i in vue.nombre_de_couches():
		var t := Time.get_ticks_usec()
		vue.couche(i).reconstruire()
		print("reconstruire() complet, couche %d : %d ms" % [i, _ms(t)])
	var autre := 1
	var siennes: Array = (vue.couche(autre).get_node("Cases") as GridMap).get_used_cells()
	for i in vue.nombre_de_couches():
		if i == autre:
			continue
		var t := Time.get_ticks_usec()
		var sommets := {}
		for c in siennes:
			var p: Vector3i = c
			for sx in [p.x - 1, p.x]:
				for sz in [p.z - 1, p.z]:
					for y in range(vue.couche(i)._y_bas - 1, p.y + 1):
						sommets[Vector3i(sx, y, sz)] = true
		print("couche %d, autour des %d cases de la couche %d : %d sommets énumérés en %d ms" % [i, siennes.size(),
			autre, sommets.size(), _ms(t)])
	for essai in 2:
		var t := Time.get_ticks_usec()
		_ecran._montrer_couche(autre, false)
		print("cacher la couche %d : %d ms" % [autre, _ms(t)])
		t = Time.get_ticks_usec()
		_ecran._montrer_couche(autre, true)
		print("montrer la couche %d : %d ms" % [autre, _ms(t)])
	_ecran.queue_free()
	await process_frame
	if _reglages_avant != "":
		var f := FileAccess.open(REGLAGES, FileAccess.WRITE)
		f.store_string(_reglages_avant)
		f.close()
	quit()


func _ms(t: int) -> int:
	return (Time.get_ticks_usec() - t) / 1000
