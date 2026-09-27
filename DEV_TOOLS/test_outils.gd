extends SceneTree
##
## TEST — les outils de peinture (`addons/marching_blocks_plugin_godot/outils.gd`), et la portée des
## opérations d'étage (`etages.gd`) quand une sélection existe.
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_outils.gd
##
## ⚠ **TOUS LES ATTENDUS SONT CALCULÉS À LA MAIN**, case par case — jamais par la fonction éprouvée
## (charte §6). Le rayon diagonal est déroulé pas à pas dans son commentaire.

const Outils := preload("res://addons/marching_blocks_plugin_godot/outils.gd")
const Etages := preload("res://addons/marching_blocks_plugin_godot/etages.gd")

var _ok := 0
var _echecs := 0


func _initialize() -> void:
	print("=== TEST — les outils de peinture ===\n")

	# ── 1. Le rayon ───────────────────────────────────────────────────────────────────────────────
	var une := func(cible: Vector3i) -> Callable:
		return func(c: Vector3i) -> bool: return c == cible
	var sol := func(c: Vector3i) -> bool: return c.y <= 0
	var tout := func(_c: Vector3i) -> bool: return true

	var r: Dictionary = Outils.rayon(une.call(Vector3i(5, 0, 0)), Vector3(0.5, 0.5, 0.5), Vector3.RIGHT, 50.0)
	_point(r, Vector3i(5, 0, 0), Vector3i(-1, 0, 0), "un rayon le long de +x touche (5,0,0) par sa face −x")

	r = Outils.rayon(une.call(Vector3i(-3, 2, -7)), Vector3(0.5, 2.5, -6.5), Vector3.LEFT, 50.0)
	_point(r, Vector3i(-3, 2, -7), Vector3i(1, 0, 0), "en coordonnées négatives, la case et la face +x")

	r = Outils.rayon(sol, Vector3(2.3, 10.5, -4.2), Vector3.DOWN, 50.0)
	_point(r, Vector3i(2, 0, -5), Vector3i(0, 1, 0), "un rayon vertical touche le sol par le dessus (floor, pas arrondi)")

	# Diagonal (1,−1,0) depuis (0,2 ; 3,5 ; 0,5), pas à pas — t en unités de √2/2 :
	#   (0,3,0) → y d'abord (0,5 < 0,8) → (0,2,0) → x (0,8 < 1,5) → (1,2,0) → y (1,5 < 1,8) → (1,1,0)
	#   → x (1,8 < 2,5) → (2,1,0) → y (2,5 < 2,8) → (2,0,0) : le sol, entré par le DESSUS.
	r = Outils.rayon(sol, Vector3(0.2, 3.5, 0.5), Vector3(1, -1, 0), 50.0)
	_point(r, Vector3i(2, 0, 0), Vector3i(0, 1, 0), "un rayon diagonal touche le sol en (2,0,0), face du dessus")

	r = Outils.rayon(une.call(Vector3i(5, 0, 0)), Vector3(0.5, 0.5, 0.5), Vector3.RIGHT, 3.0)
	_vrai(not r["touche"], "au-delà de la portée, rien n'est touché")

	r = Outils.rayon(tout, Vector3(0.5, 0.5, 0.5), Vector3.RIGHT, 50.0)
	_point(r, Vector3i(1, 0, 0), Vector3i(-1, 0, 0), "depuis l'intérieur de la matière, la case de départ est sautée")

	var deux := func(c: Vector3i) -> bool: return c == Vector3i(5, 0, 0) or c == Vector3i(8, 0, 0)
	r = Outils.rayon(deux, Vector3(0.5, 0.5, 0.5), Vector3.RIGHT, 50.0, {Vector3i(5, 0, 0): true})
	_point(r, Vector3i(8, 0, 0), Vector3i(-1, 0, 0), "le verrou de coup : une case ignorée est traversée")

	_vrai(not Outils.rayon(tout, Vector3.ZERO, Vector3.ZERO, 50.0)["touche"], "un rayon sans direction ne touche rien")

	# ── 2. L'ancrage ──────────────────────────────────────────────────────────────────────────────
	var touche := {"touche": true, "case": Vector3i(2, 0, 0), "normale": Vector3i(0, 1, 0)}
	_egal(Outils.ancre("ajouter", touche), Vector3i(2, 1, 0), "ajouter pose CONTRE la face visée")
	_egal(Outils.ancre("creuser", touche), Vector3i(2, 0, 0), "creuser agit SUR la case touchée")
	_egal(Outils.ancre("selectionner", touche), Vector3i(2, 0, 0), "sélectionner agit sur la case touchée")
	var plan := {"touche": false, "case": Vector3i(4, 0, 4), "normale": Vector3i.ZERO}
	_egal(Outils.ancre("ajouter", plan), Vector3i(4, 0, 4), "sur le plan d'étage, ajouter pose dans la case du plan")

	# ── 3. Les pinceaux ───────────────────────────────────────────────────────────────────────────
	_egal(Outils.pinceau(Vector3i(3, 3, 3), Vector3i.UP, 1, "sphere"), [Vector3i(3, 3, 3)], "taille 1 = une case")
	_egal(Outils.pinceau(Vector3i.ZERO, Vector3i.UP, 2, "sphere").size(), 7, "sphère de taille 2 : 7 cases")
	# |d|² ≤ 4 dans le cube de rayon 2 : 1 + 6 (|d|²=1) + 12 (=2) + 8 (=3) + 6 (=4) = 33.
	_egal(Outils.pinceau(Vector3i.ZERO, Vector3i.UP, 3, "sphere").size(), 33, "sphère de taille 3 : 33 cases")
	_egal(Outils.pinceau(Vector3i.ZERO, Vector3i.UP, 2, "cube").size(), 27, "cube de taille 2 : 27 cases")
	var disque := Outils.pinceau(Vector3i(0, 5, 0), Vector3i.UP, 2, "disque")
	_egal(disque, [Vector3i(-1, 5, 0), Vector3i(0, 5, -1), Vector3i(0, 5, 0), Vector3i(0, 5, 1), Vector3i(1, 5, 0)],
		"disque de normale y : la croix de 5 cases, à l'étage de l'ancre")
	var facade := Outils.pinceau(Vector3i(7, 0, 0), Vector3i(-1, 0, 0), 2, "disque")
	_vrai(facade.size() == 5 and facade.all(func(c: Vector3i) -> bool: return c.x == 7),
		"disque de normale x : 5 cases dans le plan de la façade, aucune en profondeur")
	_egal(Outils.pinceau(Vector3i.ZERO, Vector3i.ZERO, 2, "disque"), Outils.pinceau(Vector3i.ZERO, Vector3i.UP, 2, "disque"),
		"sans normale (la grille), le disque est horizontal")

	# ── 4. Ce que change un outil ─────────────────────────────────────────────────────────────────
	var plein := func(c: Vector3i) -> bool: return c == Vector3i(0, 0, 0)
	var cibles := [Vector3i(0, 0, 0), Vector3i(1, 0, 0)]
	_egal(Outils.modification("ajouter", cibles, plein), {"poser": {Vector3i(1, 0, 0): true}, "effacer": {}},
		"ajouter ne pose que dans le vide")
	_egal(Outils.modification("creuser", cibles, plein), {"poser": {}, "effacer": {Vector3i(0, 0, 0): true}},
		"creuser n'efface que la matière")
	_egal(Outils.modification("selectionner", cibles, plein), {"poser": {}, "effacer": {}},
		"sélectionner ne change aucune case")

	# ── 5. Les opérations sur la sélection ────────────────────────────────────────────────────────
	# Une colonne de deux en (0,·,0), une case en (1,0,0), une case isolée en (5,0,0).
	var occ := {Vector3i(0, 0, 0): true, Vector3i(0, 1, 0): true, Vector3i(1, 0, 0): true, Vector3i(5, 0, 0): true}
	var op: Dictionary = Outils.operer_selection(occ, {Vector3i(0, 0, 0): true, Vector3i(9, 9, 9): true}, "supprimer")
	_egal(op["effacer"], {Vector3i(0, 0, 0): true}, "supprimer n'efface que la matière sélectionnée")
	_egal(op["selection"], {}, "après suppression, la sélection est vide")

	op = Outils.operer_selection(occ, {Vector3i(0, 0, 0): true, Vector3i(1, 0, 0): true}, "extruder_haut")
	_egal(op["poser"], {Vector3i(1, 1, 0): true}, "extruder vers le haut ne pose que là où c'est vide")
	_egal(op["selection"], {Vector3i(0, 1, 0): true, Vector3i(1, 1, 0): true}, "la sélection SUIT l'extrusion")
	op = Outils.operer_selection(occ, {Vector3i(1, 0, 0): true}, "extruder_bas")
	_egal(op["poser"], {Vector3i(1, -1, 0): true}, "extruder vers le bas pose dessous")

	op = Outils.operer_selection(occ, {Vector3i(0, 0, 0): true}, "grandir")
	_egal(op["selection"], {Vector3i(0, 0, 0): true, Vector3i(0, 1, 0): true, Vector3i(1, 0, 0): true},
		"grandir prend la matière voisine par une face, pas la case isolée")
	op = Outils.operer_selection(occ, {Vector3i(0, 1, 0): true}, "connexe")
	_egal(op["selection"], {Vector3i(0, 0, 0): true, Vector3i(0, 1, 0): true, Vector3i(1, 0, 0): true},
		"connexe prend toute la matière reliée, pas la case isolée")
	_vrai(op["poser"].is_empty() and op["effacer"].is_empty(), "grandir / connexe ne touchent aucune case")

	var bloc := {}
	for x in 3:
		for y in 3:
			for z in 3:
				bloc[Vector3i(x, y, z)] = true
	op = Outils.operer_selection(bloc, bloc, "retrecir")
	_egal(op["selection"], {Vector3i(1, 1, 1): true}, "rétrécir un cube de 3 ne garde que son centre")

	# ── 6. Les opérations d'étage, sur la sélection ───────────────────────────────────────────────
	var etage: Dictionary = Etages.operer(occ, 0, "haut", {Vector3i(1, 0, 0): true})
	_egal(etage["poser"], {Vector3i(1, 1, 0): true}, "avec une sélection, étendre ne porte QUE sur elle")
	etage = Etages.operer(occ, 0, "haut")
	_egal(etage["poser"], {Vector3i(1, 1, 0): true, Vector3i(5, 1, 0): true},
		"sans sélection, étendre porte sur tout l'étage (la colonne est déjà pleine au-dessus)")

	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	print("VERDICT : %s" % ("OK" if _echecs == 0 else "ÉCHEC"))
	quit(0 if _echecs == 0 else 1)


func _point(r: Dictionary, c: Vector3i, n: Vector3i, quoi: String) -> void:
	_vrai(r["touche"] and r["case"] == c and r["normale"] == n,
		"%s — rendu %s / %s" % [quoi, r["case"], r["normale"]] if not (r["touche"] and r["case"] == c
		and r["normale"] == n) else quoi)


func _vrai(v: bool, quoi: String) -> void:
	if v:
		_ok += 1
	else:
		_echecs += 1
		print("  ✗ " + quoi)


func _egal(a, b, quoi: String) -> void:
	if a == b:
		_ok += 1
	else:
		_echecs += 1
		print("  ✗ %s — rendu %s, attendu %s" % [quoi, a, b])
