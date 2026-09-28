extends SceneTree
##
## TEST — les outils de peinture (`addons/marchingblocks_core/outils.gd`), et la portée des
## opérations d'étage (`etages.gd`) quand une sélection existe.
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_outils.gd
##
## ⚠ **TOUS LES ATTENDUS SONT CALCULÉS À LA MAIN**, case par case — jamais par la fonction éprouvée
## (charte §6). Le rayon diagonal est déroulé pas à pas dans son commentaire.

const Outils := preload("res://addons/marchingblocks_core/outils.gd")
const Etages := preload("res://addons/marchingblocks_core/etages.gd")

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

	# ── 7. Phase 3 : boîte, déplacer, copier, coller ─────────────────────────────────────────────
	var semis := {Vector3i(0, 0, 0): true, Vector3i(2, 1, 2): true, Vector3i(3, 0, 0): true, Vector3i(-1, 0, 0): true}
	_egal(Outils.dans_la_boite(semis, Vector3i(2, 1, 2), Vector3i(0, 0, 0)),
		{Vector3i(0, 0, 0): true, Vector3i(2, 1, 2): true}, "la boîte prend ses deux coins, dans n'importe quel ordre")

	# Une rangée de trois, décalée d'UNE case : elle recouvre sa source.
	var rangee := {Vector3i(0, 0, 0): true, Vector3i(1, 0, 0): true, Vector3i(2, 0, 0): true}
	var dep: Dictionary = Outils.deplacer(rangee, rangee, Vector3i(1, 0, 0))
	_egal(dep["effacer"], {Vector3i(0, 0, 0): true}, "déplacer d'une case n'efface que la queue")
	_egal(dep["poser"], {Vector3i(3, 0, 0): true}, "et ne pose que la tête")
	_egal(dep["selection"], {Vector3i(1, 0, 0): true, Vector3i(2, 0, 0): true, Vector3i(3, 0, 0): true},
		"la sélection suit le déplacement")
	var mur := {Vector3i(0, 0, 0): true, Vector3i(0, 1, 0): true}
	dep = Outils.deplacer(mur, {Vector3i(0, 1, 0): true}, Vector3i(0, -1, 0))
	_egal(dep["effacer"], {Vector3i(0, 1, 0): true}, "déplacer sur de la matière efface la source")
	_egal(dep["poser"], {}, "et ne repose pas la matière d'accueil — elle FUSIONNE")

	# Copier : ancrage au milieu de la face du dessous, en coordonnées NÉGATIVES (x de −3 à 0).
	var bloc_neg := {Vector3i(-3, 4, 0): true, Vector3i(0, 4, 0): true, Vector3i(0, 5, 0): true}
	# milieu x = floor(−1,5) = −2, y du bas = 4, z = 0.
	_egal(Outils.copier(bloc_neg, bloc_neg), [Vector3i(-1, 0, 0), Vector3i(2, 0, 0), Vector3i(2, 1, 0)],
		"copier ramène au milieu de la face du dessous — arrondi vers le bas, même en négatif")
	var col: Dictionary = Outils.coller({Vector3i(10, 0, 0): true}, [Vector3i(0, 0, 0), Vector3i(1, 0, 0)],
		Vector3i(9, 0, 0))
	_egal(col["poser"], {Vector3i(9, 0, 0): true}, "coller ne pose que dans le vide")
	_egal(col["selection"], {Vector3i(9, 0, 0): true, Vector3i(10, 0, 0): true}, "et sélectionne ce qu'il a collé")
	_egal(Outils.copier(semis, {Vector3i(7, 7, 7): true}), [], "copier du vide rend un presse-papiers vide")

	# ── LE VOLUME D'UNE BOÎTE, ET REMPLIR ──────────────────────────────────────
	#
	# ⚠ **CE QUI EST GARDÉ, ET POURQUOI.** `dans_la_boite` ne rendait que la MATIÈRE : un pavé vide
	# n'avait aucune existence, donc on ne pouvait pas désigner une pièce AVANT de la bâtir, et ni Fill
	# ni Extrude n'avaient de prise (Jordan, 28 septembre 2026). `volume_de_la_boite` rend les cases,
	# pleines ou vides ; `remplir` y pose la matière.
	# ⚠ **L'ATTENDU EST ÉCRIT À LA MAIN**, jamais recomposé par la fonction éprouvée (charte §6).
	print("\n── le volume d'une boîte, et remplir")
	_egal(Outils.volume_de_la_boite(Vector3i(0, 0, 0), Vector3i(1, 1, 1)).size(), 8,
		"un pavé de 2³ porte 8 cases, pleines ou vides")
	_egal(Outils.volume_de_la_boite(Vector3i(2, 5, -3), Vector3i(2, 5, -3)),
		{Vector3i(2, 5, -3): true}, "un pavé d'une seule case, en coordonnées négatives")
	_egal(Outils.volume_de_la_boite(Vector3i(3, 0, 0), Vector3i(0, 0, 0)).size(), 4,
		"les coins se donnent dans n'importe quel ordre")
	# ⚠ LE RECTANGLE PLAT : une seule épaisseur en y, donc 3×3 cases et pas 27.
	_egal(Outils.volume_de_la_boite(Vector3i(0, 4, 0), Vector3i(2, 4, 2)).size(), 9,
		"un rectangle à plat sur un étage rend ses 3×3 cases")

	var creux3: Dictionary = Outils.volume_de_la_boite(Vector3i(0, 0, 0), Vector3i(2, 2, 2), true)
	_egal(creux3.size(), 26, "une boîte creuse de 3³ rend 27 cases moins son cœur")
	_vrai(not creux3.has(Vector3i(1, 1, 1)), "et le cœur retiré est bien le centre")
	_egal(Outils.volume_de_la_boite(Vector3i(0, 0, 0), Vector3i(4, 4, 4), true).size(), 125 - 27,
		"une boîte creuse de 5³ retire son cube intérieur de 3³")
	# ⚠ **UNE BOÎTE SANS DEDANS RESTE PLEINE**, et c'est juste : la vider rendrait un geste sans effet
	# que rien n'expliquerait à l'écran.
	_egal(Outils.volume_de_la_boite(Vector3i(0, 4, 0), Vector3i(2, 4, 2), true).size(), 9,
		"un rectangle plat n'a pas d'intérieur : le creux le laisse entier")
	_egal(Outils.volume_de_la_boite(Vector3i(0, 0, 0), Vector3i(1, 1, 1), true).size(), 8,
		"un pavé de 2³ non plus")
	# ⚠ LA BORNE : deux coins éloignés par un rayon perdu ne doivent pas gêler l'écran.
	_egal(Outils.volume_de_la_boite(Vector3i(0, 0, 0), Vector3i(999, 999, 999)), {},
		"un volume déraisonnable rend vide plutôt que de ramer")

	var rangee2 := {Vector3i(0, 0, 0): true, Vector3i(1, 0, 0): true}
	var rangee3 := {Vector3i(0, 0, 0): true, Vector3i(1, 0, 0): true, Vector3i(2, 0, 0): true}
	var rempli: Dictionary = Outils.operer_selection(rangee2, rangee3, "remplir")
	_egal(rempli["poser"], {Vector3i(2, 0, 0): true},
		"remplir ne pose que dans les cases VIDES de la sélection")
	_egal(rempli["effacer"], {}, "remplir n'efface jamais rien")
	_egal(rempli["selection"], rangee3,
		"et la sélection ne bouge pas : remplir, extruder, remplir est le geste qui monte une pièce")
	_egal(Outils.operer_selection(rangee3, rangee3, "remplir")["poser"], {},
		"remplir une sélection déjà pleine ne pose rien")

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
