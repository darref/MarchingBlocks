extends SceneTree
## BANC (headless) — l'aperçu d'une forme spéciale et d'une salle sur l'EXEMPLE (4 octobre 2026). Ouvre l'exemple dans
## l'appli (installé dans un dossier jetable, réglages rendus), puis chronomètre ce que coûte une case survolée : le
## dictionnaire des cases de la couche active (`_occupees_actives`), et le calcul de la forme. Ne conçoit rien.
##   godot --headless --path . --script res://DEV_TOOLS/banc_apercu_forme.gd
## ⚠ RÉÉCRIT `user://reglages.cfg` (et le rend) : à lancer dans une copie à dossier de données isolé si l'appli tourne.

const Exemple := preload("res://app/exemple.gd")
const FS := preload("res://addons/marchingblocks_core/formes_speciales.gd")
const REGLAGES := "user://reglages.cfg"
const DOSSIER := "user://banc_apercu_forme"
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
	var g: GridMap = vue.cases()
	print("couche active : %d cases" % g.get_used_cells().size())
	for essai in 3:
		var t := Time.get_ticks_usec()
		var occ: Dictionary = vue._occupees_actives()
		print("_occupees_actives : %d cases, %d ms (l'état de la couche : %s)" % [occ.size(), _ms(t),
			is_same(occ, vue.monde()._miennes)])
	for essai in 2:
		var t := Time.get_ticks_usec()
		var relues := {}
		for c in g.get_used_cells():
			relues[c] = true
		print("relire la grille : %d ms" % _ms(t))
	# CE QUI SUIT CHAQUE GESTE : l'étiquette d'étage, la liste des couches.
	for essai in 2:
		var t := Time.get_ticks_usec()
		_ecran._dire_l_etage()
		print("_dire_l_etage : %d ms" % _ms(t))
		t = Time.get_ticks_usec()
		for i in vue.nombre_de_couches():
			_ecran._etat_de(i)
		print("_etat_de × %d : %d ms" % [vue.nombre_de_couches(), _ms(t)])
		t = Time.get_ticks_usec()
		_ecran._rafraichir_couches()
		print("_rafraichir_couches : %d ms" % _ms(t))
	# Une case de surface quelconque, et sa face du dessus.
	var occ: Dictionary = vue._occupees_actives()
	var haut := {}
	for c in occ:
		var k := Vector2i(c.x, c.z)
		if not haut.has(k) or c.y > haut[k]:
			haut[k] = c.y
	var cles := haut.keys()
	cles.sort()
	var k0: Vector2i = cles[cles.size() / 2]
	var dessus := Vector3i(k0.x, haut[k0], k0.y)
	for quoi in ["tunnel", "puits", "escalier"]:
		var demande: Dictionary = vue.forme_speciale.duplicate()
		demande["quoi"] = quoi
		demande["relier"] = false
		demande["a"] = dessus
		demande["face_a"] = Vector3i.UP
		var t := Time.get_ticks_usec()
		var f: Dictionary = FS.forme(occ, demande)
		print("FS.forme %s : %d ms (erreur « %s », %d posées, %d creusées)" % [quoi, _ms(t), f["erreur"],
			f["poser"].size(), f["effacer"].size()])
	var t2 := Time.get_ticks_usec()
	var s: Dictionary = FS.salle(occ, dessus + Vector3i.UP, dessus + Vector3i(6, 1, 6), 3, true)
	print("FS.salle : %d ms (erreur « %s »)" % [_ms(t2), s["erreur"]])
	_finir()


func _ms(t: int) -> int:
	return (Time.get_ticks_usec() - t) / 1000


func _finir() -> void:
	if _reglages_avant != "":
		var f := FileAccess.open(REGLAGES, FileAccess.WRITE)
		f.store_string(_reglages_avant)
		f.close()
	_ecran.queue_free()
	quit(0)
