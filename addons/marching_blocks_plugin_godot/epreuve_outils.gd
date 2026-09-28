@tool
extends RefCounted
## LES CAS D'ÉPREUVE DES OUTILS D'ÉDITION DE MONDE — ce que les greffons Unity et Unreal doivent reproduire.
##
## **DEMANDÉ PAR JORDAN (28 septembre 2026)** : les greffons gratuits reçoivent les outils de l'appli
## (viser, pinceau, sélection, boîte, remplir, extruder, déplacer, copier, coller). Chacun les
## réimplémente dans SA langue — C#, C++ — parce qu'aucun ne peut charger du GDScript.
##
## ⚠ **TROIS IMPLÉMENTATIONS, UNE RÉFÉRENCE : `outils.gd`.** C'est exactement le piège de la seconde
## description qui diverge (charte §6), et la parade est celle de la règle de pose : chaque cas est
## CALCULÉ ICI par `outils.gd`, jamais écrit à la main, et le fichier est livré avec chaque greffon.
## `test_greffon_peinture` rougit s'il est périmé.
##
## ⚠ **LES NOMS SORTENT EN ANGLAIS** (charte §7 : la source des greffons part chez l'acheteur), et la
## traduction vit ICI ET NULLE PART AILLEURS — comme `id_de_cle` pour les tuiles.
##
## ⚠ **LES RAYONS ÉVITENT LES ÉGALITÉS.** `rayon()` travaille en `Vector3`, donc en flottants 32 bits ;
## un greffon en double précision peut départager autrement deux plans franchis au MÊME instant. Les
## directions obliques sont choisies génériques, et les égalités qu'on garde exprès (un rayon parallèle
## à un axe : deux composantes à l'infini) se départagent par la règle écrite — le plus petit axe.

const Outils := preload("res://addons/marching_blocks_plugin_godot/outils.gd")

const FORMAT := "marchingblocks-tools-conformance"
const VERSION := 1

const OUTILS_EN := {"ajouter": "add", "creuser": "dig", "selectionner": "select"}
const FORMES_EN := {"sphere": "sphere", "cube": "cube", "disque": "disc"}
const OPERATIONS_EN := {"supprimer": "delete", "extruder_haut": "extrude_up", "extruder_bas": "extrude_down",
	"grandir": "grow", "retrecir": "shrink", "connexe": "connected", "remplir": "fill"}

const REGLES := [
	"Every function is pure: it reads cells and returns what changes. Apply the result with your engine's own undo.",
	"cells are integer [x, y, z]; cell c covers [c, c+1] on each axis. Sets are returned sorted by x, then y, then z.",
	"ray(cells, origin, direction, reach, ignore): walk the grid cell by cell (Amanatides & Woo) along the NORMALISED direction. The start cell is skipped. At each step cross the nearest cell boundary; on a tie, the lowest axis (x, then y, then z) goes first. Stop when that boundary is beyond reach. The first cell that is full and not in ignore is the hit; normal is the face it was entered by (minus the step on that axis). A zero direction never hits.",
	"anchor(tool, hit): 'add' on a hit is hit.cell + hit.normal; everything else is hit.cell.",
	"brush(anchor, normal, size, shape): r = max(0, size - 1); every offset d in [-r, r]^3 kept by the shape — sphere: |d|^2 <= r^2; cube: all; disc: |d|^2 <= r^2 and d . n == 0, with n = (0, 1, 0) when the normal is zero.",
	"change(tool, targets, cells): 'add' sets the targets that are empty, 'dig' clears the targets that are full, 'select' changes nothing.",
	"selection(cells, selection, op) returns set, clear and the selection AFTER: delete clears the selected full cells (selection empty after); extrude_up / extrude_down set every empty cell one step up / down and the selection moves there; grow adds every full cell touching the selection by a face (plus the selected full cells); shrink keeps the selected full cells whose six neighbours are all selected; connected is every full cell joined to the selected full cells by faces; fill sets the selected empty cells and keeps the selection. A selection may hold empty cells.",
	"box(a, b, hollow): every cell between the two corners, bounds included, in any order. hollow keeps only the skin: a cell strictly inside on all three axes is dropped (a box thinner than 3 on an axis stays solid). A box of more than box_volume_max cells returns EMPTY, never a partial box.",
	"move(cells, selection, offset): the selected full cells move by offset. Clear the source cells that are not destinations; set the destinations that are empty or were part of the source. Matter already there stays (a move merges, never overwrites). The selection becomes the destinations.",
	"copy(cells, selection): the selected full cells, relative to the anchor (floor((min.x + max.x) / 2), min.y, floor((min.z + max.z) / 2)) of their bounding box, sorted. floor, not integer division: in negative coordinates they differ.",
	"paste(cells, clipboard, anchor): every anchor + d; set the empty ones; the selection becomes all of them.",
]


static func _cases(cases_: Variant) -> Array:
	var sortie: Array = []
	var liste: Array = []
	if cases_ is Dictionary:
		liste = (cases_ as Dictionary).keys()
	else:
		liste = Array(cases_)
	liste.sort()
	for c in liste:
		var v: Vector3i = c
		sortie.append([v.x, v.y, v.z])
	return sortie


static func _v(v: Vector3i) -> Array:
	return [v.x, v.y, v.z]


static func _f(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


## Un rayon parallèle à un axe est une égalité VOULUE (deux composantes à l'infini), départagée par
## la règle écrite : le perturber le rendrait oblique, donc on ne l'éprouve pas ainsi.
static func _parallele(d: Vector3) -> bool:
	var nuls := 0
	for i in 3:
		if d[i] == 0.0:
			nuls += 1
	return nuls >= 2


static func _ensemble(cases_: Array) -> Dictionary:
	var d := {}
	for c in cases_:
		d[c] = true
	return d


## LE MONDE DES ESSAIS : un sol de 5 × 5 à y = 0, un pilier de 3 en (2, 1..3, 2), un îlot négatif.
static func monde() -> Dictionary:
	var d := {}
	for x in 5:
		for z in 5:
			d[Vector3i(x, 0, z)] = true
	for y in range(1, 4):
		d[Vector3i(2, y, 2)] = true
	for c in [Vector3i(-4, -2, -4), Vector3i(-3, -2, -4), Vector3i(-4, -2, -3)]:
		d[c] = true
	return d


static func cas_d_epreuve() -> Dictionary:
	var m := monde()
	var occupe := func(c: Vector3i) -> bool: return m.has(c)
	var cas: Array = []

	# ── ray
	var rayons := [
		["straight down onto the floor", Vector3(0.5, 6.5, 0.5), Vector3(0, -1, 0), 50.0, []],
		["down onto the pillar top", Vector3(2.5, 9.5, 2.5), Vector3(0, -1, 0), 50.0, []],
		["oblique onto the floor", Vector3(-2.3125, 4.1875, -1.6875), Vector3(0.609375, -0.46875, 0.53125), 50.0, []],
		["oblique into the pillar side", Vector3(6.3125, 2.375, 2.34375), Vector3(-0.9375, 0.0625, 0.109375), 50.0, []],
		["upwards, into nothing", Vector3(1.5, 1.5, 1.5), Vector3(0.125, 1.0, 0.0625), 50.0, []],
		["reach too short", Vector3(0.5, 6.5, 0.5), Vector3(0, -1, 0), 3.0, []],
		["the pillar ignored (the stroke lock)", Vector3(2.5, 9.5, 2.5), Vector3(0, -1, 0), 50.0,
			[Vector3i(2, 3, 2), Vector3i(2, 2, 2), Vector3i(2, 1, 2)]],
		["the start cell is skipped", Vector3(1.5, 0.5, 1.5), Vector3(1, 0, 0), 50.0, []],
		["negative coordinates", Vector3(-3.40625, 1.8125, -3.59375), Vector3(-0.109375, -0.953125, -0.0625), 50.0, []],
		["zero direction", Vector3(0.5, 6.5, 0.5), Vector3(0, 0, 0), 50.0, []],
		# ⚠ UNE ÉGALITÉ EXACTE, VOULUE : |dx| = |dy|, donc les deux plans sont franchis au même instant,
		# en 32 comme en 64 bits. x passe d'abord → (3, 1, 0) vide puis (3, 0, 0) ; y d'abord toucherait
		# (4, 0, 0). Sans ce cas, départager à l'envers restait MUET (mesuré sur le greffon Unity).
		["an exact tie: the lowest axis goes first", Vector3(4.5, 1.5, 0.5), Vector3(-1, -1, 0), 50.0, [], true],
	]
	for r in rayons:
		var ignorer := _ensemble(r[4])
		var res: Dictionary = Outils.rayon(occupe, r[1], r[2], r[3], ignorer)
		# ⚠ UN CAS FRAGILE N'EST PAS ÉCRIT : si une perturbation minime de la direction change la
		# réponse, un greffon en double précision pourrait légitimement répondre autre chose.
		for e in [Vector3(1e-3, 0, 0), Vector3(0, 1e-3, 0), Vector3(0, 0, 1e-3), Vector3(-1e-3, -1e-3, -1e-3)]:
			if (r[2] as Vector3).is_zero_approx() or _parallele(r[2]) or r.size() > 5:
				break
			var autre: Dictionary = Outils.rayon(occupe, r[1], (r[2] as Vector3) + e, r[3], ignorer)
			if autre != res:
				return {"erreur": "le rayon « %s » est fragile : %s contre %s" % [r[0], res, autre]}
		cas.append({"name": "ray: " + r[0], "kind": "ray",
			"input": {"cells": "world", "origin": _f(r[1]), "direction": _f(r[2]), "reach": r[3],
				"ignore": _cases(r[4])},
			"expected": {"hit": res["touche"], "cell": _v(res["case"]), "normal": _v(res["normale"])}})

	# ── anchor
	for a in [["add", "ajouter", true], ["add", "ajouter", false], ["dig", "creuser", true],
			["select", "selectionner", true]]:
		var point := {"touche": a[2], "case": Vector3i(3, 0, 1), "normale": Vector3i(0, 1, 0)}
		cas.append({"name": "anchor: %s, %s" % [a[0], "hit" if a[2] else "floor plane"], "kind": "anchor",
			"input": {"tool": a[0], "hit": a[2], "cell": [3, 0, 1], "normal": [0, 1, 0]},
			"expected": {"anchor": _v(Outils.ancre(a[1], point))}})

	# ── brush
	for forme in ["sphere", "cube", "disque"]:
		for taille in [1, 2, 3]:
			for n in [Vector3i.ZERO, Vector3i(1, 0, 0)]:
				if forme != "disque" and n != Vector3i.ZERO:
					continue
				var anc := Vector3i(1, -2, 3)
				cas.append({"name": "brush: %s size %d normal %s" % [FORMES_EN[forme], taille, str(n)],
					"kind": "brush",
					"input": {"anchor": _v(anc), "normal": _v(n), "size": taille, "shape": FORMES_EN[forme]},
					"expected": {"cells": _cases(Outils.pinceau(anc, n, taille, forme))}})

	# ── change
	var cibles := [Vector3i(0, 0, 0), Vector3i(0, 1, 0), Vector3i(2, 3, 2), Vector3i(2, 4, 2)]
	for o in ["ajouter", "creuser", "selectionner"]:
		var mod: Dictionary = Outils.modification(o, cibles, occupe)
		cas.append({"name": "change: " + OUTILS_EN[o], "kind": "change",
			"input": {"cells": "world", "tool": OUTILS_EN[o], "targets": _cases(cibles)},
			"expected": {"set": _cases(mod["poser"]), "clear": _cases(mod["effacer"])}})

	# ── selection — une sélection MÊLÉE : de la matière, du vide au-dessus, un bord.
	var selections := {
		"mixed": [Vector3i(1, 0, 1), Vector3i(2, 0, 1), Vector3i(1, 1, 1), Vector3i(2, 1, 2)],
		"floor block": [Vector3i(1, 0, 1), Vector3i(2, 0, 1), Vector3i(3, 0, 1), Vector3i(1, 0, 2),
			Vector3i(2, 0, 2), Vector3i(3, 0, 2), Vector3i(1, 0, 3), Vector3i(2, 0, 3), Vector3i(3, 0, 3)],
		"pillar top": [Vector3i(2, 3, 2)],
	}
	# « shrink » a besoin d'un cœur entouré sur SIX faces : un cube de 3³ plein, sélectionné en entier.
	var cube3 := {}
	for x in 3:
		for y in 3:
			for z in 3:
				cube3[Vector3i(10 + x, y, z)] = true
	for op in OPERATIONS_EN:
		for nom in selections:
			var sel := _ensemble(selections[nom])
			var r: Dictionary = Outils.operer_selection(m, sel, op)
			cas.append({"name": "selection: %s on %s" % [OPERATIONS_EN[op], nom], "kind": "selection",
				"input": {"cells": "world", "selection": _cases(sel), "op": OPERATIONS_EN[op]},
				"expected": {"set": _cases(r["poser"]), "clear": _cases(r["effacer"]),
					"selection": _cases(r["selection"])}})
	var r3: Dictionary = Outils.operer_selection(cube3, cube3, "retrecir")
	cas.append({"name": "selection: shrink on a full 3x3x3 cube", "kind": "selection",
		"input": {"cells": _cases(cube3), "selection": _cases(cube3), "op": "shrink"},
		"expected": {"set": _cases(r3["poser"]), "clear": _cases(r3["effacer"]),
			"selection": _cases(r3["selection"])}})

	# ── box
	var boites := [
		["2x2x2", Vector3i(0, 0, 0), Vector3i(1, 1, 1), false],
		["corners in any order", Vector3i(3, 0, 0), Vector3i(0, 0, 0), false],
		["one cell, negative", Vector3i(2, 5, -3), Vector3i(2, 5, -3), false],
		["flat rectangle", Vector3i(0, 4, 0), Vector3i(2, 4, 2), false],
		["hollow 3x3x3", Vector3i(0, 0, 0), Vector3i(2, 2, 2), true],
		["hollow 4x3x5, negative", Vector3i(-2, -1, -2), Vector3i(1, 1, 2), true],
		["hollow but flat: stays solid", Vector3i(0, 4, 0), Vector3i(2, 4, 2), true],
		["too large: empty", Vector3i(0, 0, 0), Vector3i(64, 63, 63), false],
		["exactly the limit: 64^3, solid", Vector3i(0, 0, 0), Vector3i(63, 63, 63), false],
	]
	for b in boites:
		var vol: Dictionary = Outils.volume_de_la_boite(b[1], b[2], b[3])
		var attendu := {"count": vol.size()}
		# ⚠ La boîte à la limite fait 262 144 cases : on n'en écrit que le compte.
		if vol.size() <= 200:
			attendu["cells"] = _cases(vol)
		cas.append({"name": "box: " + b[0], "kind": "box",
			"input": {"a": _v(b[1]), "b": _v(b[2]), "hollow": b[3]}, "expected": attendu})

	# ── move
	var rangee := {Vector3i(0, 0, 0): true, Vector3i(1, 0, 0): true, Vector3i(2, 0, 0): true}
	var mur := rangee.duplicate()
	mur[Vector3i(1, 1, 0)] = true
	var deplacements := [
		["overlapping itself", rangee, rangee, Vector3i(1, 0, 0)],
		["onto matter: merges", mur, {Vector3i(0, 0, 0): true, Vector3i(1, 0, 0): true}, Vector3i(0, 1, 0)],
		["empty cells in the selection are not moved", rangee, {Vector3i(2, 0, 0): true, Vector3i(5, 5, 5): true},
			Vector3i(0, 0, -2)],
	]
	for d in deplacements:
		var r: Dictionary = Outils.deplacer(d[1], d[2], d[3])
		cas.append({"name": "move: " + d[0], "kind": "move",
			"input": {"cells": _cases(d[1]), "selection": _cases(d[2]), "offset": _v(d[3])},
			"expected": {"set": _cases(r["poser"]), "clear": _cases(r["effacer"]),
				"selection": _cases(r["selection"])}})

	# ── copy
	var copies := [
		["a row", rangee, rangee],
		["negative coordinates: floor, not truncation", {Vector3i(-3, 2, -1): true, Vector3i(0, 2, -4): true,
			Vector3i(-1, 3, -2): true}, {Vector3i(-3, 2, -1): true, Vector3i(0, 2, -4): true,
			Vector3i(-1, 3, -2): true}],
		["nothing full selected", rangee, {Vector3i(7, 7, 7): true}],
	]
	for c in copies:
		cas.append({"name": "copy: " + c[0], "kind": "copy",
			"input": {"cells": _cases(c[1]), "selection": _cases(c[2])},
			"expected": {"clipboard": _cases(Outils.copier(c[1], c[2]))}})

	# ── paste
	var pp: Array[Vector3i] = [Vector3i(-1, 0, 0), Vector3i(0, 0, 0), Vector3i(1, 0, 0)]
	for p in [["onto the floor, partly full", Vector3i(0, 0, 0)], ["in the air", Vector3i(1, 5, 1)]]:
		var r: Dictionary = Outils.coller(m, pp, p[1])
		cas.append({"name": "paste: " + p[0], "kind": "paste",
			"input": {"cells": "world", "clipboard": _cases(pp), "anchor": _v(p[1])},
			"expected": {"set": _cases(r["poser"]), "clear": _cases(r["effacer"]),
				"selection": _cases(r["selection"])}})

	return {"format": FORMAT, "version": VERSION, "rules_text": REGLES,
		"limits": {"box_volume_max": Outils.VOLUME_MAXI}, "world": _cases(m), "cases": cas}
