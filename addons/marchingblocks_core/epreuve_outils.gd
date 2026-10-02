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

const Outils := preload("res://addons/marchingblocks_core/outils.gd")

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

	cas.append_array(_cas_des_formes())
	# ⚠ LES MONDES DES FORMES SONT ÉCRITS UNE FOIS, et chaque cas les NOMME (`input.world`) : recopiés dans
	# chaque cas, ils portaient le fichier à 1 Mo, livré avec chaque greffon.
	var mondes_formes := {}
	var mf := _mondes_des_formes()
	for nom in mf:
		mondes_formes[nom] = _cases(mf[nom])

	return {"format": FORMAT, "version": VERSION, "rules_text": REGLES + REGLES_FORMES,
		"limits": {"box_volume_max": Outils.VOLUME_MAXI, "shape_length_max": FS.LONGUEUR_MAXI,
			"shape_span_max": FS.ECART_MAXI, "shape_step_max": FS.PAS_MAXI}, "world": _cases(m), "shape_worlds": mondes_formes, "cases": cas}


# ── LES FORMES SPÉCIALES (1er octobre 2026) — `formes_speciales.gd`, mêmes parades ────────────────────

const FS := preload("res://addons/marchingblocks_core/formes_speciales.gd")

const FORMES_SPECIALES_EN := {"tunnel": "tunnel", "puits": "well", "pont": "bridge", "balcon": "balcony",
	"escalier": "stairs"}
const PROFILS_EN := {"rond": "round", "carre": "square", "arche": "arch"}
const ERREURS_EN := {"": "", "pas_de_paroi": "needs_a_wall", "pas_un_sol": "needs_floor_or_ceiling",
	"meme_case": "same_cell", "trop_long": "too_far", "rien_en_face": "nothing_in_front", "trop_grand": "too_large",
	"forme_inconnue": "unknown_shape", "pas_un_dessus": "needs_a_floor", "trop_raide": "too_steep"}

const REGLES_FORMES := [
	"SPECIAL SHAPES — their cases name their world in input.world, a key of shape_worlds. Tunnel and well DIG (clear full cells), bridge, balcony and stairs ADD (set empty cells). Everything is integer: cell centres are the points, every test compares squared integers (64-bit), never a square root.",
	"wall_normal(cells, c, face): sum the HORIZONTAL faces F (+-x, +-z) of every full cell q in the 3x3x3 window around c whose neighbour q + F is empty, all of them (back faces included). m = max(|sx|, |sz|); if m = 0 return face. n = (sign(sx) if 2|sx| >= m else 0, 0, sign(sz) if 2|sz| >= m else 0). If n . face <= 0 return face, else n.",
	"normal for a shape: well — the face must be (0, +-1, 0) and IS the normal (else error needs_floor_or_ceiling); stairs with connect true — the face must be (0, 1, 0), a floor, and IS the normal (else needs_a_floor); tunnel, bridge, balcony, one-click stairs — the face must be horizontal and non-zero (else needs_a_wall), and the normal is wall_normal. connect is ignored for the balcony.",
	"special_shape(cells, shape, a, face_a, connect, b, face_b, profile, size, length, rail, step): h = clamp(size, 1, 7) - 1; length = clamp(length, 1, shape_length_max); step = clamp(step, 1, shape_step_max). Unknown shape or profile: unknown_shape. The bridge's profile is always its deck. Errors change nothing.",
	"stairs, one click (connect false): n = normal of a, N = n.n, m = (-n.z, 0, n.x). Every d = (x, 0, z) with |x|, |z| <= length + h + 1, along = d.n > 0 and side = d.m with side^2 <= h^2 N belongs to row j = the smallest j >= 1 with along^2 <= j^2 N (rows beyond length are dropped). For j = 1, 2, ... length: top = a.y - (j - 1) / step (integer division); if every cell (a.x + d.x, top, a.z + d.z) of row j is already full, stop (the stairs met the ground); else each of them is a column with that top, an edge when rail, h >= 1 and side^2 > (h-1)^2 N.",
	"stairs, connect true: b must pass the normal test (needs_a_floor), b = a: same_cell, |b - a|^2 > shape_span_max^2: too_far. L = the end with the lower y (a when equal), H = the other; D = (H.x - L.x, 0, H.z - L.z), R = H.y - L.y; R^2 > D.D: error too_steep. u = (-D.z, 0, D.x). Columns: every (x, 0, z) with x in [min(L.x, H.x) - h - 1, max(L.x, H.x) + h + 1] (same for z), d = (x - L.x, 0, z - L.z), t = d.D in [0, D.D] and (d.u)^2 <= h^2 D.D; plus the axis walk from (L.x, 0, L.z) to (H.x, 0, H.z). Each is a column with top L.y + t' R / D.D (integer division, t' = t clamped to [0, D.D]), an edge when rail, h >= 1 and (d.u)^2 > (h-1)^2 D.D.",
	"stairs column with top T: if T is full, nothing. Else T, and walking down k = 1..shape_length_max the empty cells T - (0, k, 0) until the first full one; all of them if a full one was met, else only T - (0, 1, 0). An edge also takes T + (0, 1, 0). The shape is the union of its columns.",
	"balcony: n = normal of a, N = n.n, m = (-n.z, 0, n.x). For every d = (x, 0, z) with |x|, |z| <= length + h + 1: along = d.n, side = d.m; keep a + d when along > 0, along^2 <= length^2 N and side^2 <= h^2 N. With rail (h >= 1 and length >= 2), also a + d + (0,1,0) unless along^2 <= (length-1)^2 N and side^2 <= (h-1)^2 N.",
	"one click (connect false): the direction s is -n to dig, +n to add. Walk k = 1..length, q = a + s k: dig stops at the first EMPTY q, and ends at q - s (the far wall cell) when k > 1, at q when k = 1 — opened = true; no empty cell: the end is a + s length, opened = false. A bridge stops at the first FULL q and ends there; none: error nothing_in_front. Points = [a, end].",
	"connect (connect true): nb = normal of b (same errors). b = a: same_cell. |b - a|^2 > shape_span_max^2: too_far. Directions da, db: -normal to dig, +normal to add. Leg of each end P toward the other O: k = smallest k >= 0 with k^2 (d.d) >= (h+1)^2; w = d.(O - P); while k > 0 and w > 0 and 3 k w > |O - P|^2: k -= 1. Points = [a, a + da ka, b + db kb, b], consecutive duplicates removed.",
	"sweep: for each segment P0 -> P1 (D = P1 - P0) the cells of its axis walk (below) belong to the shape; then every cell q in the box of P0 and P1 grown by h + 2 + max(e0, e1) (more than box_volume_max cells: error too_large), with d = q - P0 and t = d.D, inside when (t >= 0 or (e0 > 0 and t^2 <= e0^2 D.D)) and (t <= D.D or (e1 > 0 and (t - D.D)^2 <= e1^2 D.D)), where e0 = h unless P0 is the first point (then 0) and e1 = h unless P1 is the last (then 0). Frame: u = (-D.z, 0, D.x), v = (-D.x D.y, D.x^2 + D.z^2, -D.y D.z); if D.x = D.z = 0, u = (1,0,0), v = (0,0,1). A = d.u, B = d.v, UU = u.u, VV = v.v, H = h^2.",
	"profiles: round A^2 VV + B^2 UU <= H UU VV; square A^2 <= H UU and B^2 <= H VV; arch: round when B >= 0, else square. Deck: A^2 <= H UU and 4 B^2 <= VV; with rail and h >= 1, a cell that is not deck with B > 0, 4 B^2 <= 9 VV and A^2 <= H UU is a rail when A^2 > (h-1)^2 UU, else a walkway; rails of every segment minus walkways of every segment join the shape.",
	"axis walk from P0 to P1: one axis per step; after k_i steps on axis i the next crossing is at (2 k_i + 1) / (2 |D_i|); take the smallest, compared as (2 k_i + 1) |D_j| < (2 k_j + 1) |D_i|; on a tie the lowest axis (x, then y, then z).",
	"then: dig clears the shape's full cells, add sets its empty cells. REPAIR, by rounds: the front is every changed cell; for each front cell c and each plane (xy, xz, yz), the four 2x2 squares containing c; in the world AFTER the change, a square whose diagonal cells are equal and the other diagonal opposite is a checkerboard: dig clears its FULL pair, add sets its EMPTY pair. Collect all of a round, apply them at once, they are the next front; repaired counts them.",
]


static func _cas_des_formes() -> Array:
	var cas: Array = []
	var mondes := _mondes_des_formes()
	# ── wall_normal
	for n in [["flat wall", "plat", Vector3i(0, 2, 0), Vector3i(1, 0, 0)],
			["flat wall, other side", "plat", Vector3i(-3, 2, 0), Vector3i(-1, 0, 0)],
			["45 degree staircase, clicked on +x", "escalier", Vector3i(0, 2, 0), Vector3i(1, 0, 0)],
			["45 degree staircase, clicked on +z", "escalier", Vector3i(0, 2, 0), Vector3i(0, 0, 1)],
			["thin slanted wall: back faces count", "mince", Vector3i(0, 2, 0), Vector3i(1, 0, 0)],
			["a lone cell: the sum is zero", "seule", Vector3i(0, 0, 0), Vector3i(0, 0, -1)]]:
		cas.append({"name": "wall_normal: " + n[0], "kind": "wall_normal",
			"input": {"world": n[1], "cell": _v(n[2]), "face": _v(n[3])},
			"expected": {"normal": _v(FS.normale_estimee(mondes[n[1]], n[2], n[3]))}})
	# ── special_shape
	var essais := [
		["tunnel straight, round", "mur", {"quoi": "tunnel", "a": Vector3i(0, 3, 0), "face_a": Vector3i(-1, 0, 0), "profil": "rond", "taille": 2, "longueur": 8}],
		["tunnel straight, square", "mur", {"quoi": "tunnel", "a": Vector3i(0, 3, 0), "face_a": Vector3i(-1, 0, 0), "profil": "carre", "taille": 2, "longueur": 8}],
		["tunnel straight, arch", "mur", {"quoi": "tunnel", "a": Vector3i(0, 3, 0), "face_a": Vector3i(-1, 0, 0), "profil": "arche", "taille": 3, "longueur": 8}],
		["tunnel straight, blind", "epais", {"quoi": "tunnel", "a": Vector3i(0, 3, 0), "face_a": Vector3i(-1, 0, 0), "profil": "rond", "taille": 1, "longueur": 4}],
		["tunnel straight, ends on the far wall (not in the room's floor)", "sol", {"quoi": "tunnel", "a": Vector3i(0, 1, 0), "face_a": Vector3i(-1, 0, 0), "profil": "carre", "taille": 2, "longueur": 8}],
		["tunnel straight, a wall one cell thick", "fin", {"quoi": "tunnel", "a": Vector3i(0, 2, 0), "face_a": Vector3i(-1, 0, 0), "profil": "rond", "taille": 1, "longueur": 8}],
		["tunnel connect, face to face (legs capped)", "sol", {"quoi": "tunnel", "a": Vector3i(0, 1, 0), "face_a": Vector3i(-1, 0, 0), "relier": true, "b": Vector3i(2, 1, 0), "face_b": Vector3i(1, 0, 0), "profil": "carre", "taille": 2}],
		["tunnel connect, an elbow between two caves", "coude", {"quoi": "tunnel", "a": Vector3i(4, 2, 3), "face_a": Vector3i(-1, 0, 0), "relier": true, "b": Vector3i(10, 3, 9), "face_b": Vector3i(0, 0, 1), "profil": "arche", "taille": 2}],
		["tunnel connect, square elbow (joints extended)", "coude", {"quoi": "tunnel", "a": Vector3i(4, 2, 3), "face_a": Vector3i(-1, 0, 0), "relier": true, "b": Vector3i(10, 3, 9), "face_b": Vector3i(0, 0, 1), "profil": "carre", "taille": 2}],
		["tunnel connect, thin and oblique (axis walk, repair)", "massif", {"quoi": "tunnel", "a": Vector3i(0, 2, 0), "face_a": Vector3i(-1, 0, 0), "relier": true, "b": Vector3i(8, 7, 3), "face_b": Vector3i(1, 0, 0), "profil": "rond", "taille": 1}],
		["tunnel straight into a 45 degree wall", "dalle", {"quoi": "tunnel", "a": Vector3i(0, 3, 0), "face_a": Vector3i(1, 0, 0), "profil": "rond", "taille": 2, "longueur": 12}],
		["tunnel straight, a pocket makes a checkerboard: repaired", "poche", {"quoi": "tunnel", "a": Vector3i(0, 3, 0), "face_a": Vector3i(-1, 0, 0), "profil": "rond", "taille": 1, "longueur": 8}],
		["well straight, blind", "socle", {"quoi": "puits", "a": Vector3i(0, 9, 0), "face_a": Vector3i(0, 1, 0), "profil": "rond", "taille": 1, "longueur": 4}],
		["well straight into a cave, size 3", "grotte", {"quoi": "puits", "a": Vector3i(0, 9, 0), "face_a": Vector3i(0, 1, 0), "profil": "rond", "taille": 3, "longueur": 20}],
		["well up from a cave ceiling", "grotte", {"quoi": "puits", "a": Vector3i(0, 4, 0), "face_a": Vector3i(0, -1, 0), "profil": "carre", "taille": 1, "longueur": 20}],
		["bridge straight", "gorge", {"quoi": "pont", "a": Vector3i(0, 3, 0), "face_a": Vector3i(1, 0, 0), "taille": 2, "longueur": 10}],
		["bridge straight, with rail", "gorge", {"quoi": "pont", "a": Vector3i(0, 3, 0), "face_a": Vector3i(1, 0, 0), "taille": 2, "longueur": 10, "garde_corps": true}],
		["bridge connect, sloped", "gorge", {"quoi": "pont", "a": Vector3i(0, 1, 0), "face_a": Vector3i(1, 0, 0), "relier": true, "b": Vector3i(6, 4, 2), "face_b": Vector3i(-1, 0, 0), "taille": 2}],
		["bridge connect, an elbow with rails", "equerre", {"quoi": "pont", "a": Vector3i(0, 3, 0), "face_a": Vector3i(1, 0, 0), "relier": true, "b": Vector3i(9, 3, 11), "face_b": Vector3i(0, 0, -1), "taille": 3, "garde_corps": true}],
		["balcony", "plat", {"quoi": "balcon", "a": Vector3i(0, 3, 0), "face_a": Vector3i(1, 0, 0), "taille": 2, "longueur": 3}],
		["balcony with rail", "plat", {"quoi": "balcon", "a": Vector3i(0, 3, 0), "face_a": Vector3i(1, 0, 0), "taille": 2, "longueur": 3, "garde_corps": true}],
		["balcony on a 45 degree wall, with rail", "escalier", {"quoi": "balcon", "a": Vector3i(0, 3, 0), "face_a": Vector3i(1, 0, 0), "taille": 2, "longueur": 3, "garde_corps": true}],
		["error: a well on a wall", "mur", {"quoi": "puits", "a": Vector3i(0, 3, 0), "face_a": Vector3i(-1, 0, 0)}],
		["error: a tunnel on a floor", "socle", {"quoi": "tunnel", "a": Vector3i(0, 9, 0), "face_a": Vector3i(0, 1, 0)}],
		["error: connect a cell to itself", "mur", {"quoi": "tunnel", "a": Vector3i(0, 3, 0), "face_a": Vector3i(-1, 0, 0), "relier": true, "b": Vector3i(0, 3, 0), "face_b": Vector3i(-1, 0, 0)}],
		["error: the two ends too far apart", "mur", {"quoi": "tunnel", "a": Vector3i(0, 3, 0), "face_a": Vector3i(-1, 0, 0), "relier": true, "b": Vector3i(200, 3, 0), "face_b": Vector3i(1, 0, 0)}],
		["error: a bridge with nothing in reach", "gorge", {"quoi": "pont", "a": Vector3i(0, 3, 0), "face_a": Vector3i(1, 0, 0), "taille": 2, "longueur": 4}],
		["stairs, step 1, down to the ground", "falaise", {"quoi": "escalier", "a": Vector3i(0, 4, 0), "face_a": Vector3i(1, 0, 0), "taille": 1, "longueur": 8, "pas": 1}],
		["stairs, step 2, three wide with rail", "falaise", {"quoi": "escalier", "a": Vector3i(0, 4, 0), "face_a": Vector3i(1, 0, 0), "taille": 2, "longueur": 8, "pas": 2, "garde_corps": true}],
		["stairs, length caps the run", "falaise", {"quoi": "escalier", "a": Vector3i(0, 4, 0), "face_a": Vector3i(1, 0, 0), "taille": 1, "longueur": 5, "pas": 2}],
		["stairs over the void: two cells thick", "plat", {"quoi": "escalier", "a": Vector3i(0, 3, 0), "face_a": Vector3i(1, 0, 0), "taille": 1, "longueur": 3, "pas": 1}],
		["stairs clicked at the foot: nothing to add", "falaise", {"quoi": "escalier", "a": Vector3i(0, 0, 0), "face_a": Vector3i(1, 0, 0), "taille": 1, "longueur": 8, "pas": 1}],
		["stairs on a 45 degree wall, with rail", "pente", {"quoi": "escalier", "a": Vector3i(0, 4, 0), "face_a": Vector3i(1, 0, 0), "taille": 2, "longueur": 6, "pas": 1, "garde_corps": true}],
		["stairs connect, floor to floor", "plateau", {"quoi": "escalier", "relier": true, "a": Vector3i(1, 0, 0), "face_a": Vector3i(0, 1, 0), "b": Vector3i(7, 3, 0), "face_b": Vector3i(0, 1, 0), "taille": 1}],
		["stairs connect, clicked top first, three wide with rail", "plateau", {"quoi": "escalier", "relier": true, "a": Vector3i(7, 3, 0), "face_a": Vector3i(0, 1, 0), "b": Vector3i(1, 0, -1), "face_b": Vector3i(0, 1, 0), "taille": 2, "garde_corps": true}],
		["stairs connect, thin and oblique (axis walk)", "butte", {"quoi": "escalier", "relier": true, "a": Vector3i(0, 0, 0), "face_a": Vector3i(0, 1, 0), "b": Vector3i(9, 4, 5), "face_b": Vector3i(0, 1, 0), "taille": 1}],
		["error: stairs too steep", "plateau", {"quoi": "escalier", "relier": true, "a": Vector3i(5, 0, 0), "face_a": Vector3i(0, 1, 0), "b": Vector3i(7, 3, 0), "face_b": Vector3i(0, 1, 0), "taille": 1}],
		["error: connected stairs on a wall", "plateau", {"quoi": "escalier", "relier": true, "a": Vector3i(7, 2, 0), "face_a": Vector3i(-1, 0, 0), "b": Vector3i(1, 0, 0), "face_b": Vector3i(0, 1, 0), "taille": 1}],
		["error: one-click stairs on a floor", "falaise", {"quoi": "escalier", "a": Vector3i(3, 0, 0), "face_a": Vector3i(0, 1, 0), "taille": 1}],
		["error: unknown shape", "mur", {"quoi": "toboggan", "a": Vector3i(0, 3, 0), "face_a": Vector3i(-1, 0, 0)}],
	]
	for e in essais:
		var monde: Dictionary = mondes[e[1]]
		var r: Dictionary = e[2]
		var res: Dictionary = FS.forme(monde, r)
		var entree := {"world": e[1], "shape": FORMES_SPECIALES_EN.get(r["quoi"], r["quoi"]),
			"a": _v(r["a"]), "face_a": _v(r["face_a"]), "connect": bool(r.get("relier", false)),
			"profile": PROFILS_EN[r.get("profil", "rond")], "size": int(r.get("taille", 1)),
			"length": int(r.get("longueur", 8)), "rail": bool(r.get("garde_corps", false)),
			"step": int(r.get("pas", 2))}
		if entree["connect"]:
			entree["b"] = _v(r["b"])
			entree["face_b"] = _v(r["face_b"])
		cas.append({"name": "special_shape: " + e[0], "kind": "special_shape", "input": entree,
			"expected": {"set": _cases(res["poser"]), "clear": _cases(res["effacer"]),
				"error": ERREURS_EN[res["erreur"]], "opened": res["ouvert"], "repaired": res["reparees"]}})
	return cas


## Les mondes des formes, petits : ils sont écrits en entier dans chaque cas.
static func _mondes_des_formes() -> Dictionary:
	var m := {}
	var boite := func(d: Dictionary, a: Vector3i, b: Vector3i, plein: bool) -> void:
		for x in range(a.x, b.x + 1):
			for y in range(a.y, b.y + 1):
				for z in range(a.z, b.z + 1):
					if plein:
						d[Vector3i(x, y, z)] = true
					else:
						d.erase(Vector3i(x, y, z))
	var d := {}
	boite.call(d, Vector3i(-3, 0, -4), Vector3i(0, 6, 4), true)
	m["plat"] = d
	d = {}
	boite.call(d, Vector3i(0, 0, -4), Vector3i(2, 6, 4), true)
	m["mur"] = d
	var poche: Dictionary = d.duplicate()
	poche.erase(Vector3i(1, 4, 1))
	m["poche"] = poche
	var sol: Dictionary = d.duplicate()
	boite.call(sol, Vector3i(-4, 0, -4), Vector3i(6, 0, 4), true)
	m["sol"] = sol
	d = {}
	boite.call(d, Vector3i(0, 0, -2), Vector3i(0, 4, 2), true)
	m["fin"] = d
	d = {}
	boite.call(d, Vector3i(0, 0, -2), Vector3i(12, 6, 2), true)
	m["epais"] = d
	d = {}
	boite.call(d, Vector3i(-3, 0, -3), Vector3i(3, 9, 3), true)
	m["socle"] = d
	var grotte: Dictionary = d.duplicate()
	boite.call(grotte, Vector3i(-2, 1, -2), Vector3i(2, 3, 2), false)
	m["grotte"] = grotte
	d = {}
	boite.call(d, Vector3i(-3, 0, -3), Vector3i(0, 5, 3), true)
	boite.call(d, Vector3i(6, 0, -3), Vector3i(8, 5, 3), true)
	m["gorge"] = d
	d = {}
	boite.call(d, Vector3i(-3, 0, -3), Vector3i(0, 5, 10), true)
	boite.call(d, Vector3i(-3, 0, 11), Vector3i(12, 5, 13), true)
	m["equerre"] = d
	d = {}
	boite.call(d, Vector3i(0, 0, 0), Vector3i(13, 6, 13), true)
	boite.call(d, Vector3i(1, 1, 1), Vector3i(3, 4, 5), false)
	boite.call(d, Vector3i(8, 2, 10), Vector3i(12, 5, 12), false)
	m["coude"] = d
	d = {}
	boite.call(d, Vector3i(0, 0, -4), Vector3i(8, 8, 4), true)
	m["massif"] = d
	var escalier := {}
	var mince := {}
	var dalle := {}
	for x in range(-6, 7):
		for z in range(-6, 7):
			if x + z <= 0:
				boite.call(escalier, Vector3i(x, 0, z), Vector3i(x, 4, z), true)
			if x + z <= 0 and x + z >= -1:
				boite.call(mince, Vector3i(x, 0, z), Vector3i(x, 4, z), true)
			if x + z <= 0 and x + z >= -5:
				boite.call(dalle, Vector3i(x, 0, z), Vector3i(x, 6, z), true)
	m["escalier"] = escalier
	m["mince"] = mince
	m["dalle"] = dalle
	m["seule"] = {Vector3i(0, 0, 0): true}
	# Les escaliers : une falaise sur un sol, un sol et un plateau, une paroi à 45° sur un sol, une butte.
	d = {}
	boite.call(d, Vector3i(-3, 0, -4), Vector3i(0, 6, 4), true)
	boite.call(d, Vector3i(1, 0, -4), Vector3i(10, 0, 4), true)
	m["falaise"] = d
	d = {}
	boite.call(d, Vector3i(-2, 0, -3), Vector3i(10, 0, 3), true)
	boite.call(d, Vector3i(7, 1, -3), Vector3i(10, 3, 3), true)
	m["plateau"] = d
	d = {}
	for x in range(-4, 9):
		for z in range(-4, 9):
			boite.call(d, Vector3i(x, 0, z), Vector3i(x, 6 if x + z <= 0 else 0, z), true)
	m["pente"] = d
	d = {}
	boite.call(d, Vector3i(-2, 0, -2), Vector3i(12, 0, 8), true)
	boite.call(d, Vector3i(9, 1, 5), Vector3i(9, 4, 5), true)
	m["butte"] = d
	return m
