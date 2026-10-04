extends SceneTree
## BANC (headless) — le monde qui suit son témoin, sur l'EXEMPLE (4 octobre 2026 : `vers_glb` 5,4 s puis
## `_suivre_son_temoin` 7,1 s sur le PC, à chaque passage de Geometry à World après une retouche). Ouvre l'exemple
## dans l'appli (dossier jetable, réglages rendus) et chronomètre chaque morceau, sur la couche active. Ne conçoit rien.
##   godot --headless --path . --script res://DEV_TOOLS/banc_temoin_suit.gd

const Exemple := preload("res://app/exemple.gd")
const Projet := preload("res://app/projet.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const REGLAGES := "user://reglages.cfg"
const DOSSIER := "user://banc_temoin_suit"
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
	var i: int = _ecran._active
	var c: Dictionary = _ecran._couches[i]
	var t := Time.get_ticks_usec()
	var temoin = _ecran._temoin_de(c)
	_trace("charger le témoin de « %s »" % c["nom"], t)
	var glb: String = _ecran._glb_du_temoin(c)
	print("glb : %s, %d Mo" % [glb.get_file(), FileAccess.open(glb, FileAccess.READ).get_length() / 1000000])
	# vers_glb, découpé
	t = Time.get_ticks_usec()
	var maillages := {}
	for cle in temoin.tuiles:
		maillages[cle] = temoin.tuiles[cle].vers_array_mesh(true)
	_trace("vers_glb · les maillages (%d tuiles)" % maillages.size(), t)
	t = Time.get_ticks_usec()
	load("res://addons/marchingblocks_core/peinture.gd").suivre_les_cartes(true)
	_trace("vers_glb · les cartes PBR à jour", t)
	t = Time.get_ticks_usec()
	BM.ecrire_le_temoin_lie(glb, maillages, temoin.affectation)
	_trace("vers_glb · ecrire_le_temoin_lie", t)
	t = Time.get_ticks_usec()
	temoin.vers_glb(glb)
	_trace("vers_glb entier", t)
	# _suivre_son_temoin, découpé
	t = Time.get_ticks_usec()
	var bilan: Dictionary = BM.librairie_depuis_glb(glb)
	_trace("_suivre · librairie_depuis_glb", t)
	t = Time.get_ticks_usec()
	Projet.mettre_en_cache(bilan["lot"], glb)
	_trace("_suivre · mettre_en_cache", t)
	t = Time.get_ticks_usec()
	_ecran._vue.couche(i).lot = bilan["lot"]
	_trace("_suivre · poser le lot (reconstruction de la couche)", t)
	_ecran.queue_free()
	await process_frame
	if _reglages_avant != "":
		var f := FileAccess.open(REGLAGES, FileAccess.WRITE)
		f.store_string(_reglages_avant)
		f.close()
	quit()


func _trace(nom: String, t0: int) -> void:
	print("%-60s %8.1f ms" % [nom, (Time.get_ticks_usec() - t0) / 1000.0])
