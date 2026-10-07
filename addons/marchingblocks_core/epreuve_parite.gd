@tool
extends RefCounted
## LES CAS D'ÉPREUVE DE LA PARITÉ DES GREFFONS — DÉCIDÉ (Jordan, 7 octobre 2026 : « parité complète des greffons à la
## 0.9.0 », toute la LISTE DES GREFFONS À FAIRE, charte §0). Ce fichier est la PREMIÈRE étape, celle dont dépendent les
## trois moteurs : ce que chaque règle répond, calculé ICI par le GDScript qui fait foi, écrit en anglais dans cinq
## fichiers livrés avec chaque greffon (à côté de `conformance.json`, `world_conformance.json`, `tools_conformance.json`) :
##
##   transitions_conformance.json   `Transitions.melange` (le fondu), les réglages, la table, la texture des cases, la
##                                  lecture de la clé `transitions` de `world.json`
##   animation_conformance.json     `image_au_temps`, `pulsation_au_temps`, `phase_de`, `defilement_au_temps`, la lecture de
##                                  `mb_animation` (les extras d'un matériau de `tiles.glb`)
##   foliage_conformance.json       `Feuillage.verifier` (les trois modes), le pinceau sans hasard (`semer_candidats`), la
##                                  pose, le vent par plant et le balancement, le sol des cases, la lecture de `foliage`
##   water_conformance.json         `Fluides.monde` (la règle de l'eau), `sources_en_largeur`, la surface et la profondeur,
##                                  la lecture de `water`
##   water_mesh_conformance.json    `EauMaillage.maillage` (la NAPPE recalculée, 7 octobre 2026) : des corps d'eau donnés
##                                  (au format des `water_world`), le maillage en ENSEMBLE CANONIQUE de triangles
##   editing_conformance.json       `Etages.extruder` (poser / étendre / décaler × haut / bas / face), `retrecir_bord`,
##                                  `elargir_a_plat`, le pinceau Select (cases vides), `FS.salle_depuis`
##
## ⚠ **UNE RÈGLE, UN ENDROIT (charte §6)** : rien ici n'est écrit à la main — chaque attendu sort de la fonction du cœur
## que l'appli appelle. Les ENTRÉES, elles, sont construites pour exercer ce qu'elles nomment, et `test_parite` le vérifie
## (chaque raison de refus, chaque mode, chaque bout de la règle), et rougit si un fichier livré est PÉRIMÉ.
## ⚠ **LES NOMS SORTENT EN ANGLAIS** (charte §7) ; les traductions propres aux cas vivent ICI ET NULLE PART AILLEURS
## (celles des formats vivent dans leur module : `TR.NOMS_EN`, `Anim.vers_format`, `FM.lire_feuillage`).
## ⚠ **PAS DE HASARD DANS LES ENTRÉES** : un générateur pseudo-aléatoire ÉCRIT (`_Lcg`, entiers) fabrique les cas en
## nombre ; les greffons n'ont pas à le reproduire, ils lisent les entrées dans le fichier.

const TR := preload("res://addons/marchingblocks_core/transitions.gd")
const Anim := preload("res://addons/marchingblocks_core/animation_materiau.gd")
const FE := preload("res://addons/marchingblocks_core/feuillage.gd")
const FL := preload("res://addons/marchingblocks_core/fluides.gd")
const FM := preload("res://addons/marchingblocks_core/format_monde.gd")
const Outils := preload("res://addons/marchingblocks_core/outils.gd")
const Etages := preload("res://addons/marchingblocks_core/etages.gd")
const FS := preload("res://addons/marchingblocks_core/formes_speciales.gd")
const EO := preload("res://addons/marchingblocks_core/epreuve_outils.gd")
const EM := preload("res://addons/marchingblocks_core/eau_maillage.gd")

const VERSION := 1
## Le nom de chaque fichier, par sujet.
const FICHIERS := {"transitions": "transitions_conformance.json", "animation": "animation_conformance.json",
	"foliage": "foliage_conformance.json", "water": "water_conformance.json", "editing": "editing_conformance.json",
	"water_mesh": "water_mesh_conformance.json"}

const COMMUN := [
	"Every case: {name, kind, input, expected}. Integers are exact. Floats: compare with an absolute tolerance of 1e-6",
	"(1e-5 for anything that went through a sine or a cosine). Cells and vertices are integer [x, y, z] in FORMAT space",
	"(right-handed, +Y up, cell c covers [c, c + 1]); a set of cells is sorted by x, then y, then z.",
]


static func cas_d_epreuve() -> Dictionary:
	var sortie := {}
	sortie["transitions"] = _transitions()
	sortie["animation"] = _animation()
	sortie["foliage"] = _feuillage()
	sortie["water"] = _eau()
	sortie["editing"] = _edition()
	sortie["water_mesh"] = _maillage_eau()
	for k in sortie:
		if (sortie[k] as Dictionary).has("erreur"):
			return {"erreur": "%s : %s" % [k, sortie[k]["erreur"]]}
	return sortie


# ── OUTILS COMMUNS ───────────────────────────────────────────────────────────────────────────────────

static func _v(v: Vector3i) -> Array:
	return [v.x, v.y, v.z]


static func _f(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


## Un ensemble de cases (Dictionary ou Array de Vector3i), trié x puis y puis z, en triplets.
static func _cases(cases_: Variant) -> Array:
	var liste: Array = (cases_ as Dictionary).keys() if cases_ is Dictionary else Array(cases_).duplicate()
	liste.sort()
	return liste.map(func(c: Vector3i) -> Array: return [c.x, c.y, c.z])


static func _ensemble(cases_: Array) -> Dictionary:
	var d := {}
	for c in cases_:
		d[c] = true
	return d


static func _boite(a: Vector3i, b: Vector3i) -> Array:
	var sortie: Array = []
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			for z in range(a.z, b.z + 1):
				sortie.append(Vector3i(x, y, z))
	return sortie


## Un générateur d'entiers ÉCRIT (congruentiel, 31 bits) : des entrées en nombre, toujours les mêmes. Les greffons ne le
## reproduisent pas — ils lisent les entrées.
class _Lcg:
	var etat: int
	func _init(graine: int) -> void:
		etat = graine & 0x7FFFFFFF
	func entier(n: int) -> int:
		etat = (etat * 1103515245 + 12345) & 0x7FFFFFFF
		return (etat >> 8) % n
	## Un réel DYADIQUE dans [0, 1] (k / 64) : exact en 32 comme en 64 bits.
	func dyadique() -> float:
		return float(entier(65)) / 64.0


# ══ TRANSITIONS ══════════════════════════════════════════════════════════════════════════════════════

## Un réglage d'une direction, en anglais (complet).
static func _rg(largeur := 0.45, avance := 0.2, bruit := 0.35, grain := 1.5, creux := 0.5) -> Dictionary:
	return TR.reglages_en({"largeur": largeur, "avance": avance, "bruit": bruit, "grain": grain, "creux": creux})


## La table anglaise {"C|D": réglages} → celle du cœur.
static func _table_fr(table_en: Dictionary) -> Dictionary:
	var t := {}
	for k in table_en:
		t[k] = TR.reglages_depuis_en(table_en[k])
	return t


static func _cas_melange(nom: String, rangs: Array, f: Vector3, choix: Array, table_en: Dictionary, h: Dictionary,
		n: float) -> Dictionary:
	var h_fr := {}
	var h_en := {}
	for r in h:
		h_fr[int(r)] = float(h[r])
		h_en[str(r)] = float(h[r])
	var res := TR.melange(rangs, f, choix, _table_fr(table_en), h_fr, n)
	var attendu := {}
	if not res.is_empty():
		attendu = {"owner": res["proprio"], "other": res["autre"], "s": res["s"], "vote": res["vote"],
			"alpha": res["alpha"]}
	return {"name": "blend: " + nom, "kind": "blend", "input": {"ranks": rangs, "f": _f(f), "choices": choix,
		"table": table_en, "h": h_en, "n": n}, "expected": attendu}


static func _transitions() -> Dictionary:
	var cas: Array = []
	var actif := {"0|1": _rg(), "1|0": _rg()}
	var vide := [-1, -1, -1, -1, -1, -1, -1, -1]
	var aucun := vide.duplicate()
	# Les coins : k = dx + 2 dy + 4 dz. Une moitié (dx = 0) de la couche 0, l'autre (dx = 1) de la couche 1.
	var moitie := [0, 1, 0, 1, 0, 1, 0, 1]
	cas.append(_cas_melange("a single layer: nothing blends", [2, 2, 2, 2, 2, 2, 2, 2], Vector3(0.5, 0.5, 0.5), aucun,
		actif, {}, 0.5))
	cas.append(_cas_melange("two layers, half and half, the middle", moitie, Vector3(0.5, 0.5, 0.5), aucun, actif, {},
		0.5))
	cas.append(_cas_melange("the pair is off (no direction in the table)", moitie, Vector3(0.5, 0.5, 0.5), aucun, {},
		{}, 0.5))
	cas.append(_cas_melange("half a table (one direction only): nothing", moitie, Vector3(0.5, 0.5, 0.5), aucun,
		{"1|0": _rg()}, {}, 0.5))
	cas.append(_cas_melange("the owner is the SMALLEST rank", [3, 1, 3, 1, 3, 1, 3, 1], Vector3(0.3, 0.5, 0.5), aucun,
		{"1|3": _rg(), "3|1": _rg()}, {}, 0.5))
	cas.append(_cas_melange("reach pushes the cover forward", moitie, Vector3(0.4, 0.5, 0.5), aucun,
		{"0|1": _rg(0.45, 0.5), "1|0": _rg(0.45, -0.5)}, {}, 0.5))
	cas.append(_cas_melange("the two directions differ (a desert on rock is not rock on a desert)", moitie,
		Vector3(0.625, 0.25, 0.75), aucun, {"0|1": _rg(0.2, 0.4, 0.0, 1.5, 0.0), "1|0": _rg(0.9, -0.3, 0.0, 1.5, 0.0)},
		{}, 0.5))
	cas.append(_cas_melange("the brush: every corner chose layer 1 to cover", moitie, Vector3(0.5, 0.5, 0.5),
		[1, 1, 1, 1, 1, 1, 1, 1], {"0|1": _rg(0.3, 0.3), "1|0": _rg(0.3, -0.2)}, {}, 0.5))
	cas.append(_cas_melange("the brush on half the corners: the votes weigh", moitie, Vector3(0.375, 0.625, 0.25),
		[1, -1, 1, -1, 1, 1, -1, -1], {"0|1": _rg(0.3, 0.3), "1|0": _rg(0.3, -0.2)}, {}, 0.5))
	cas.append(_cas_melange("a choice of a THIRD layer counts as no choice", moitie, Vector3(0.5, 0.5, 0.5),
		[2, 2, 2, 2, 2, 2, 2, 2], {"0|1": _rg(0.3, 0.3), "1|0": _rg(0.3, -0.2)}, {}, 0.5))
	cas.append(_cas_melange("at the owner's end, settings at their maximum: nothing shows", moitie,
		Vector3(0.0, 0.5, 0.5), aucun, {"0|1": _rg(1.0, 0.5, 1.0, 6.0, 1.0), "1|0": _rg(1.0, 0.5, 1.0, 6.0, 1.0)},
		{0: 0.0, 1: 1.0}, 1.0))
	cas.append(_cas_melange("at the other's end, settings at their maximum: fully the other", moitie,
		Vector3(1.0, 0.5, 0.5), aucun, {"0|1": _rg(1.0, 0.5, 1.0, 6.0, 1.0), "1|0": _rg(1.0, 0.5, 1.0, 6.0, 1.0)},
		{0: 0.0, 1: 1.0}, 1.0))
	cas.append(_cas_melange("fills hollows: a dark owner surface is covered first", moitie, Vector3(0.375, 0.5, 0.5),
		[1, 1, 1, 1, 1, 1, 1, 1], {"0|1": _rg(0.3, 0.0, 0.0, 1.5, 1.0), "1|0": _rg(0.3, 0.0, 0.0, 1.5, 1.0)},
		{0: 0.05, 1: 0.9}, 0.5))
	cas.append(_cas_melange("fills hollows: a bright owner surface resists", moitie, Vector3(0.375, 0.5, 0.5),
		[1, 1, 1, 1, 1, 1, 1, 1], {"0|1": _rg(0.3, 0.0, 0.0, 1.5, 1.0), "1|0": _rg(0.3, 0.0, 0.0, 1.5, 1.0)},
		{0: 0.95, 1: 0.9}, 0.5))
	cas.append(_cas_melange("empty corners are ignored", [0, -1, 0, 1, -1, 1, -1, -1], Vector3(0.5, 0.5, 0.5), aucun,
		actif, {}, 0.5))
	cas.append(_cas_melange("irregularity: the noise moves the line", moitie, Vector3(0.4375, 0.5, 0.5), aucun,
		{"0|1": _rg(0.2, 0.0, 1.0), "1|0": _rg(0.2, 0.0, 1.0)}, {}, 0.875))
	cas.append(_cas_melange("a tie between two other layers: the first corner wins", [0, 2, 1, 0, 0, 2, 1, 0],
		Vector3(0.5, 0.5, 0.5), aucun, {"0|1": _rg(), "1|0": _rg(), "0|2": _rg(0.8, -0.4), "2|0": _rg(0.8, 0.4)}, {},
		0.5))
	# En nombre : des huit coins, des points, des choix, des tables et des bruits tirés par le générateur écrit.
	var g := _Lcg.new(20261007)
	for i in 48:
		var rangs: Array = []
		var choix: Array = []
		for k in 8:
			rangs.append(g.entier(5) - 1)
			choix.append(g.entier(5) - 1 if g.entier(3) == 0 else -1)
		var table := {}
		for a in 4:
			for b in 4:
				if a < b and g.entier(4) != 0:
					table["%d|%d" % [a, b]] = _rg(0.05 + 0.95 * g.dyadique(), g.dyadique() - 0.5, g.dyadique(),
						0.25 + 5.75 * g.dyadique(), g.dyadique())
					table["%d|%d" % [b, a]] = _rg(0.05 + 0.95 * g.dyadique(), g.dyadique() - 0.5, g.dyadique(),
						0.25 + 5.75 * g.dyadique(), g.dyadique())
		var h := {}
		for r in 4:
			h[r] = g.dyadique()
		cas.append(_cas_melange("generated %d" % i, rangs, Vector3(g.dyadique(), g.dyadique(), g.dyadique()), choix,
			table, h, g.dyadique()))

	# ── settings : la lecture d'un réglage (absent → défaut, hors bornes → borné)
	for e in [["empty: every default", {}], ["out of range: clamped", {"softness": 3.0, "reach": -2.0,
			"irregularity": -1.0, "grain": 100.0, "fills_hollows": 7.5}], ["partial", {"reach": 0.125, "grain": 0.25}],
			["exact bounds", {"softness": 0.05, "reach": 0.5, "irregularity": 1.0, "grain": 6.0, "fills_hollows": 0.0}]]:
		cas.append({"name": "settings: " + e[0], "kind": "settings", "input": e[1],
			"expected": TR.reglages_en(TR.reglages_depuis_en(e[1]))})

	# ── table : de `world.json` (paires par indices) aux directions actives, « C|D » = C couvre D
	var paires_tables := [
		["an active pair", 3, [{"a": 0, "b": 2, "active": true, "a_covers_b": _rg(0.3), "b_covers_a": _rg(0.7)}]],
		["an inactive pair gives nothing", 3, [{"a": 0, "b": 1, "active": false, "a_covers_b": _rg(),
			"b_covers_a": _rg()}]],
		["two pairs, one off", 4, [{"a": 0, "b": 1, "active": true, "a_covers_b": _rg(0.2), "b_covers_a": _rg(0.4)},
			{"a": 2, "b": 3, "active": false, "a_covers_b": _rg(), "b_covers_a": _rg()},
			{"a": 1, "b": 3, "active": true, "a_covers_b": _rg(0.6, -0.1), "b_covers_a": _rg(0.8, 0.1)}]],
		["a layer beyond the 15th blends nothing", 17, [{"a": 2, "b": 15, "active": true, "a_covers_b": _rg(),
			"b_covers_a": _rg()}, {"a": 13, "b": 14, "active": true, "a_covers_b": _rg(0.5), "b_covers_a": _rg(0.6)}]],
	]
	for e in paires_tables:
		var p_fr := {}
		var rang_de := {}
		for i in int(e[1]):
			rang_de[str(i)] = i
		for p in e[2]:
			p_fr["%d|%d" % [p["a"], p["b"]]] = {"actif": p["active"], "couvre": {str(p["a"]): TR.reglages_depuis_en(
				p["a_covers_b"]), str(p["b"]): TR.reglages_depuis_en(p["b_covers_a"])}}
		var t := TR.table(p_fr, rang_de)
		var t_en := {}
		for k in t:
			t_en[k] = TR.reglages_en(t[k])
		cas.append({"name": "table: " + e[0], "kind": "table", "input": {"layers": e[1], "pairs": e[2]},
			"expected": t_en})

	# ── cell_texture : l'empaquetage RECOMMANDÉ (un octet par case : rang + 1 en bas, choix + 1 en haut)
	var union := {Vector3i(0, 0, 0): 0, Vector3i(1, 0, 0): 1, Vector3i(-3, 2, 5): 14, Vector3i(2, -1, 0): 15}
	# ⚠ UN CHOIX AU-DELÀ DE LA 15e AUSSI (greffon Unity, 7 octobre 2026) : sans lui, un quartet haut non borné passait muet.
	var choix_t := {Vector3i(0, 0, 0): 1, Vector3i(1, 0, 0): 0, Vector3i(40, 40, 40): 1, Vector3i(-3, 2, 5): 16}
	var d := TR.construire(union, choix_t)
	var octets: Array = []
	var o: PackedByteArray = d["octets"]
	var n: Vector3i = d["taille"]
	for z in n.z:
		for y in n.y:
			for x in n.x:
				var b := o[(z * n.y + y) * n.x + x]
				if b != 0:
					octets.append([x, y, z, b])
	var u_en: Array = []
	for c in union:
		u_en.append([c.x, c.y, c.z, union[c]])
	var c_en: Array = []
	for c in choix_t:
		c_en.append([c.x, c.y, c.z, choix_t[c]])
	cas.append({"name": "cell_texture: ranks, a layer beyond the 15th, a choice outside the box, a choice beyond the 15th",
		"kind": "cell_texture",
		"input": {"cells": u_en, "choices": c_en}, "expected": {"origin": _v(d["origine"]), "size": _v(n),
		"bytes": octets}})

	# ── read : la clé `transitions` de world.json
	cas.append_array(_lectures_transitions())
	return {"format": "marchingblocks-transitions-conformance", "version": VERSION,
		"rules_text": COMMUN + Array(FM.regle_transitions()) + [
			"CASES — blend: input ranks[8], f, choices[8] (k = dx + 2 dy + 4 dz), table {\"C|D\": settings when C covers D},",
			"h {rank: luminance of its representative at p, 0.5 when absent}, n; expected {} (nothing drawn) or {owner,",
			"other, s, vote, alpha}. settings: read one direction's settings. table: from world.json pairs to the active",
			"directions. cell_texture: the RECOMMENDED packing (what the app's shader reads; an engine may store the same",
			"facts otherwise): one byte per cell over the box of the cells grown by %d, low nibble rank + 1 (0 empty or" % TR.MARGE,
			"rank >= 15), high nibble chosen rank + 1 at that vertex (0 none); a choice outside the box is dropped; only",
			"non-zero bytes are listed, at texel (x, y, z) = cell - origin. read: world.json in, the normalized transitions",
			"out, or {\"error\": true} (the reason is free)."],
		"limits": {"layers_max": TR.MAXI, "margin": TR.MARGE},
		"settings": {"defaults": TR.reglages_en({}), "bounds": _bornes_en()},
		"cases": cas}


static func _bornes_en() -> Dictionary:
	var b := {}
	for k in TR.NOMS_EN:
		b[TR.NOMS_EN[k]] = TR.BORNES[k]
	return b


static func _lectures_transitions() -> Array:
	var couches := [{"name": "Rock", "visible": true, "tileset": null, "cells": []},
		{"name": "Sand", "visible": true, "tileset": null, "cells": []},
		{"name": "Snow", "visible": false, "tileset": null, "cells": []}]
	var rep := {"image": "transitions/representative_0.png", "color": [1, 0.5, 0.25, 1], "scale": 2, "roughness": 0.7}
	var reps := [rep, {"image": null, "color": [0.8, 0.7, 0.4, 1], "scale": 0.001, "roughness": 3}, rep]
	var bon := {"format": FM.FORMAT, "version": FM.VERSION, "layers": couches, "transitions": {
		"pairs": [{"a": 0, "b": 1, "active": true, "a_covers_b": {"softness": 0.3, "reach": 9},
			"b_covers_a": {"grain": 2}}, {"a": 1, "b": 2, "active": false, "a_covers_b": {}, "b_covers_a": {}}],
		"representatives": reps, "choices": [3, 0, -2, 1, -1, 4, 0, 0]}}
	var cas_: Array = [["a good world: settings completed and clamped, scale at least 0.01", bon],
		["a world without transitions: nothing", {"format": FM.FORMAT, "version": FM.VERSION, "layers": couches}]]
	var mauvais := {
		"transitions not an object": [],
		"pairs not an array": {"pairs": {}},
		"a pair without active": {"pairs": [{"a": 0, "b": 1, "a_covers_b": {}, "b_covers_a": {}}]},
		"a pair a = b": {"pairs": [{"a": 1, "b": 1, "active": true, "a_covers_b": {}, "b_covers_a": {}}]},
		"a pair a > b": {"pairs": [{"a": 2, "b": 1, "active": true, "a_covers_b": {}, "b_covers_a": {}}]},
		"a pair beyond the layers": {"pairs": [{"a": 0, "b": 3, "active": true, "a_covers_b": {}, "b_covers_a": {}}]},
		"a pair twice": {"pairs": [{"a": 0, "b": 1, "active": true, "a_covers_b": {}, "b_covers_a": {}},
			{"a": 0, "b": 1, "active": false, "a_covers_b": {}, "b_covers_a": {}}]},
		"a direction missing": {"pairs": [{"a": 0, "b": 1, "active": true, "a_covers_b": {}}]},
		"a setting not a number": {"pairs": [{"a": 0, "b": 1, "active": true, "a_covers_b": {"reach": "far"},
			"b_covers_a": {}}]},
		"a fractional layer index": {"pairs": [{"a": 0.5, "b": 1, "active": true, "a_covers_b": {}, "b_covers_a": {}}]},
		"representatives not one per layer": {"representatives": [rep, rep]},
		"a representative's color of three numbers": {"representatives": [rep, rep, {"image": null,
			"color": [1, 1, 1], "scale": 1, "roughness": 0.5}]},
		"a representative's image not a path": {"representatives": [rep, rep, {"image": 4, "color": [1, 1, 1, 1],
			"scale": 1, "roughness": 0.5}]},
		"choices not in fours": {"choices": [0, 0, 0]},
		"a vertex chosen twice": {"choices": [0, 0, 0, 1, 0, 0, 0, 0]},
		"a choice of a layer that does not exist": {"choices": [0, 0, 0, 3]},
		"a fractional choice": {"choices": [0, 0.5, 0, 1]},
	}
	for nom in mauvais:
		var m: Dictionary = bon.duplicate(true)
		if mauvais[nom] is Dictionary:
			(m["transitions"] as Dictionary).merge(mauvais[nom], true)
		else:
			m["transitions"] = mauvais[nom]
		cas_.append([nom, m])
	var sortie: Array = []
	for c in cas_:
		var lu := FM.lire_transitions(JSON.parse_string(JSON.stringify(c[1])))
		sortie.append({"name": "read: " + c[0], "kind": "read", "input": c[1],
			"expected": {"error": true} if lu.has("error") else lu["transitions"]})
	return sortie


# ══ ANIMATION ════════════════════════════════════════════════════════════════════════════════════════

static func _animation() -> Dictionary:
	var cas: Array = []
	# ── frame : n, ips, aller-retour, t, phase
	var images := [[4, 12.0, false, 0.0, 0.0], [4, 12.0, false, 0.25, 0.0], [4, 12.0, false, 1.0, 0.0],
		[4, 2.0, true, 2.75, 0.0], [4, 2.0, true, 3.0, 0.0], [4, 2.0, true, 4.5, 0.0], [1, 8.0, true, 3.3, 0.0],
		[0, 8.0, false, 3.3, 0.0], [5, 6.0, false, 0.5, 0.75], [5, 6.0, true, 0.5, 0.75], [3, 0.5, false, 100.25, 0.0],
		[7, 60.0, true, 12.375, 0.3125], [2, 12.0, true, 0.1, 0.0], [256, 60.0, false, 9.5, 0.5]]
	for e in images:
		cas.append({"name": "frame: %d frames, %s fps%s, t %s, phase %s" % [e[0], e[1], ", ping-pong" if e[2] else "",
			e[3], e[4]], "kind": "frame", "input": {"count": e[0], "fps": e[1], "ping_pong": e[2], "t": e[3],
			"phase": e[4]}, "expected": Anim.image_au_temps(e[0], e[1], e[2], e[3], e[4])})
	# ── pulse : fréquence, mini, t, phase
	for e in [[0.5, 0.2, 0.0, 0.0], [0.5, 0.2, 1.0, 0.0], [0.5, 0.2, 0.5, 0.0], [2.0, 0.3, 0.125, 0.0],
			[0.0, 0.3, 7.0, 0.0], [1.0, 0.0, 0.25, 0.25], [3.0, 1.0, 1.7, 0.6], [20.0, 0.5, 0.0125, 0.0]]:
		cas.append({"name": "pulse: %s Hz, minimum %s, t %s, phase %s" % e, "kind": "pulse",
			"input": {"frequency": e[0], "minimum": e[1], "t": e[2], "phase": e[3]},
			"expected": Anim.pulsation_au_temps(e[0], e[1], e[2], e[3])})
	# ── phase : l'origine de la tuile en espace du format (v + piece_offset)
	# ⚠ DES ORIGINES NON ENTIÈRES AUSSI (greffon Unity, 7 octobre 2026) : sur des entiers, floor(o) et floor(o + 0,5) sont
	# égaux — « la phase sans le demi » passait muette.
	for o in [Vector3(1, 1, 1), Vector3(0, 0, 0), Vector3(5, 2, -3), Vector3(-7, -2, 5), Vector3(12, 0, 12),
			Vector3(-40, 3, 17), Vector3(130, 64, -90), Vector3(2.5, 0.75, -1.5)]:
		cas.append({"name": "phase: origin %s" % o, "kind": "phase", "input": {"origin": _f(o)},
			"expected": Anim.phase_de(o)})
	# ── scroll : u, v, t, synchro, phase
	for e in [[0.0, -0.25, 2.0, true, 0.0], [0.25, -0.5, 1.5, false, 0.375], [1.0, 0.0, 0.0, false, 0.5],
			[-3.0, 2.0, 10.0, true, 0.9]]:
		var dv := Anim.defilement_au_temps(e[0], e[1], e[2], e[3], e[4])
		cas.append({"name": "scroll: u %s v %s, t %s, %s, phase %s" % [e[0], e[1], e[2], "synced" if e[3] else "offset",
			e[4]], "kind": "scroll", "input": {"u": e[0], "v": e[1], "t": e[2], "synced": e[3], "phase": e[4]},
			"expected": [dv.x, dv.y]})
	# ── read : mb_animation (au format qui part) → normalisée, ou rien
	var bon := Anim.vers_format({"albedo": {"images": {"images": ["animation/a_0000.png", "animation/a_0001.png"],
		"ips": 8.0, "aller_retour": true, "synchro": false}, "defilement": {"u": 0.25, "v": -0.5, "synchro": true}},
		"emission": {"pulsation": {"frequence": 2.0, "mini": 0.3, "synchro": false}},
		"orm": {"defilement": {"u": 0.0, "v": 0.1, "synchro": false}}})
	var lectures := {"a full animation": bon,
		"missing values take their defaults": {"format": Anim.FORMAT_ANIMATION, "version": 1,
			"normal": {"scroll": {}}, "emission": {"pulse": {}, "frames": {"images": ["animation/e.png"]}}},
		"values of the wrong type are ignored": {"format": Anim.FORMAT_ANIMATION, "version": 1,
			"albedo": {"scroll": {"u": "fast", "v": 0.5, "synced": 1}, "frames": {"images": ["animation/x.png", 4, ""],
			"fps": true, "ping_pong": "yes"}}},
		"out of range: clamped": {"format": Anim.FORMAT_ANIMATION, "version": 1, "albedo": {"scroll": {"u": 50,
			"v": -50}, "frames": {"images": ["animation/x.png"], "fps": 500}}, "emission": {"pulse": {"frequency": 99,
			"minimum": -2}}},
		"a pulse outside the emission is dropped": {"format": Anim.FORMAT_ANIMATION, "version": 1,
			"albedo": {"pulse": {"frequency": 1}}},
		"frames without a frame are dropped": {"format": Anim.FORMAT_ANIMATION, "version": 1,
			"albedo": {"frames": {"images": []}, "scroll": {"u": 1}}},
		"unknown channel and track are ignored": {"format": Anim.FORMAT_ANIMATION, "version": 1,
			"height": {"scroll": {"u": 1}}, "albedo": {"wobble": {"u": 1}}},
		"a newer version: no animation": {"format": Anim.FORMAT_ANIMATION, "version": 2, "albedo": {"scroll": {}}},
		"not an animation": {"format": "something-else", "version": 1, "albedo": {"scroll": {}}},
		"no version": {"format": Anim.FORMAT_ANIMATION, "albedo": {"scroll": {}}},
	}
	for nom in lectures:
		cas.append({"name": "read: " + nom, "kind": "read", "input": lectures[nom],
			"expected": Anim.vers_format(Anim.depuis_format(JSON.parse_string(JSON.stringify(lectures[nom]))))})
	return {"format": "marchingblocks-animation-conformance", "version": VERSION,
		"rules_text": COMMUN + Array(Anim.regle_animation()) + [
			"CASES — frame {count, fps, ping_pong, t, phase} → the frame index; pulse {frequency, minimum, t, phase} → the",
			"emission factor; phase {origin} → the phase, with this EXACT mixed precision (the reference keeps its vectors",
			"in 32-bit floats): p = floor(origin + 0.5); a_i = fract(p_i * 0.3183099 + k_i) in double (k = 0.71, 0.113,",
			"0.419); f_i = (float32) a_i; q_i = (float32)(f_i * 17); phase = fract(q.x * q.y * q.z * (q.x + q.y + q.z)) in",
			"double. A full 32-bit shader gives another phase for the same tile — compare on the CPU, or accept the",
			"difference on the GPU); scroll {u, v, t, synced,",
			"phase} → the UV offset [du, dv]; read: mb_animation in, the normalized animation out ({} = no animation)."],
		"limits": {"frames_max": Anim.IMAGES_MAXI, "pixels_max": Anim.PIXELS_MAXI, "fps_max": Anim.IPS_MAXI,
			"scroll_max": Anim.VITESSE_MAXI},
		"cases": cas}


# ══ FEUILLAGE ════════════════════════════════════════════════════════════════════════════════════════

const MODES_EN := {"air": "air", "sol_libre": "free", "sol_debord": "overflow"}
const RAISONS_EN := {"": "", "dans_la_matiere": "in_matter", "trop_pentu": "too_steep", "dans_l_eau": "in_water",
	"au_bord": "at_edge", "sous_la_matiere": "under_matter", "trop_pres": "too_close", "deja_la": "already_there",
	"pas_de_sol": "no_ground"}


## Les mondes du feuillage : un plateau de 8 × 8 (son dessus à y = 1), une dalle en surplomb à y = 2 au-dessus de x 0..1,
## une colonne de trois cases en (10, 0..2, 0) ; et deux cases d'eau posées sur le plateau.
static func _monde_feuillage() -> Dictionary:
	var cases_ := {}
	for x in 8:
		for z in 8:
			cases_[Vector3i(x, 0, z)] = true
	for x in 2:
		for z in 8:
			cases_[Vector3i(x, 2, z)] = true
	for y in 3:
		cases_[Vector3i(10, y, 0)] = true
	return cases_


const EAU_FEUILLAGE := [Vector3i(6, 1, 6), Vector3i(7, 1, 6)]


static func _modeles_feuillage() -> Dictionary:
	var m1 := FE.modele(1, "Oak", "")
	m1.merge({"decalage": 0.2, "echelle": 1.5, "echelle_alea": 0.2, "rayon": 0.4, "hauteur": 1.0, "vent": 0.5}, true)
	var m2 := FE.modele(2, "Bush", "")
	m2.merge({"decalage": -0.1, "echelle": 1.0, "echelle_alea": 0.0, "rayon": 0.3, "hauteur": 0.5, "vent": 0.8}, true)
	return {1: m1, 2: m2}


static func _modele_en(m: Dictionary) -> Dictionary:
	return {"id": int(m["id"]), "name": str(m["nom"]), "ground_offset": m["decalage"], "scale": m["echelle"],
		"scale_random": m["echelle_alea"], "footprint": m["rayon"], "height": m["hauteur"], "wind": m["vent"]}


static func _monde_fe(cases_: Dictionary) -> Dictionary:
	var eau := _ensemble(EAU_FEUILLAGE)
	var plein := func(c: Vector3i) -> bool: return cases_.has(c)
	return {"plein": plein, "sol": func(x: float, z: float, y: float) -> Variant: return FE.sol_des_cases(plein, x, z, y),
		"eau": func(q: Vector3) -> bool: return eau.has(FE.case_d_eau(q))}


static func _feuillage() -> Dictionary:
	var cases_ := _monde_feuillage()
	var monde := _monde_fe(cases_)
	var modeles := _modeles_feuillage()
	var cas: Array = []
	# Des plants déjà là : un chêne au milieu du plateau, un buisson près du bord de l'eau.
	var existants := [FE.plant(1, 1, Vector3(4.0, 1.0, 4.0), 0.0, 1.0, "sol"),
		FE.plant(2, 2, Vector3(5.5, 1.0, 2.0), 1.0, 1.0, "sol")]
	var existants_en: Array = existants.map(func(pl: Dictionary) -> Array:
		var p: Vector3 = pl["p"]
		return [pl["modele"], p.x, p.y, p.z, pl["lacet"], pl["echelle"], 0 if pl["mode"] == "air" else 1])
	var pente_50 := Vector3(sin(deg_to_rad(50.0)), cos(deg_to_rad(50.0)), 0.0)
	var pente_30 := Vector3(sin(deg_to_rad(30.0)), cos(deg_to_rad(30.0)), 0.0)
	# [nom, modèle, point, normale, mode, espacement, pente maxi, échelle du plant]
	var essais := [
		["in the air, in the void", 1, Vector3(3.5, 6.0, 3.5), Vector3.UP, "air", 0.0, 40.0, 1.0],
		["in the air, inside matter", 1, Vector3(3.5, 0.5, 3.5), Vector3.UP, "air", 0.0, 40.0, 1.0],
		["in the air ignores neighbours' footprints", 1, Vector3(4.3, 1.0, 4.0), Vector3.UP, "air", 0.0, 40.0, 1.0],
		["the same point twice", 1, Vector3(4.02, 1.0, 4.0), Vector3.UP, "overflow", 0.0, 40.0, 1.0],
		["free, on open ground", 1, Vector3(3.0, 1.0, 6.5), Vector3.UP, "free", 0.0, 40.0, 1.0],
		["free, too steep (50 degrees)", 1, Vector3(3.0, 1.0, 6.5), pente_50, "free", 0.0, 40.0, 1.0],
		["free, 30 degrees is fine", 1, Vector3(3.0, 1.0, 6.5), pente_30, "free", 0.0, 40.0, 1.0],
		["free, 30 degrees with a max slope of 25", 1, Vector3(3.0, 1.0, 6.5), pente_30, "free", 0.0, 25.0, 1.0],
		["free, in the water", 2, Vector3(6.5, 1.0, 6.5), Vector3.UP, "free", 0.0, 40.0, 1.0],
		["overflow, in the water too", 2, Vector3(6.5, 1.0, 6.5), Vector3.UP, "overflow", 0.0, 40.0, 1.0],
		["free, at the edge of the plateau", 1, Vector3(7.8, 1.0, 3.5), Vector3.UP, "free", 0.0, 40.0, 1.0],
		["overflow, at the edge of the plateau", 1, Vector3(7.8, 1.0, 3.5), Vector3.UP, "overflow", 0.0, 40.0, 1.0],
		["free, under the overhanging slab", 1, Vector3(1.5, 1.0, 4.0), Vector3.UP, "free", 0.0, 40.0, 1.0],
		["free, a small bush fits under the slab", 2, Vector3(1.5, 1.0, 4.0), Vector3.UP, "free", 0.0, 40.0, 0.5],
		["overflow, under the slab", 1, Vector3(1.5, 1.0, 4.0), Vector3.UP, "overflow", 0.0, 40.0, 1.0],
		["free, footprints overlap", 1, Vector3(4.8, 1.0, 4.0), Vector3.UP, "free", 0.0, 40.0, 1.0],
		["free, footprints just apart", 1, Vector3(5.4, 1.0, 4.0), Vector3.UP, "free", 0.0, 40.0, 1.0],
		["overflow ignores footprints", 1, Vector3(4.8, 1.0, 4.0), Vector3.UP, "overflow", 0.0, 40.0, 1.0],
		["overflow, closer than the spacing", 1, Vector3(4.8, 1.0, 4.0), Vector3.UP, "overflow", 1.0, 40.0, 1.0],
		["air, closer than the spacing", 1, Vector3(4.8, 2.0, 4.0), Vector3.UP, "air", 1.0, 40.0, 1.0],
		["air, a neighbour far below is not near", 1, Vector3(4.8, 6.0, 4.0), Vector3.UP, "air", 1.0, 40.0, 1.0],
		["free, at scale 1 it clears the bush", 1, Vector3(4.55, 1.0, 2.0), Vector3.UP, "free", 0.0, 40.0, 1.0],
		["free, at scale 1.15 its footprint reaches the bush", 1, Vector3(4.55, 1.0, 2.0), Vector3.UP, "free", 0.0, 40.0,
			1.15],
	]
	var sens_fr := {"air": "air", "free": "sol_libre", "overflow": "sol_debord"}
	for e in essais:
		var m: Dictionary = modeles[e[1]]
		var pl := FE.plant(-1, e[1], e[2], 0.5, e[7], "air" if e[4] == "air" else "sol")
		var ix := FE.index(existants, modeles)
		var raison := FE.verifier(m, pl, e[3], sens_fr[e[4]], monde, ix, modeles, e[5], e[6])
		cas.append({"name": "check: " + e[0], "kind": "check", "input": {"model": e[1], "point": _f(e[2]), "yaw": 0.5,
			"scale": e[7], "normal": _f(e[3]), "mode": e[4], "spacing": e[5], "max_slope": e[6], "plants": existants_en},
			"expected": RAISONS_EN[raison]})
	# ── brush : le pinceau, ses candidats donnés (x, z, lacet, échelle), dans l'ordre
	var g := _Lcg.new(611)
	for e in [["free", 1, 0.0, 6.0, 40], ["overflow", 2, 0.7, 6.0, 40], ["air", 1, 0.5, 4.0, 20], ["free", 2, 0.0, 2.5, 60]]:
		var candidats: Array = []
		for i in int(e[4]):
			candidats.append([-1.0 + 10.0 * g.dyadique(), -1.0 + 10.0 * g.dyadique(), 6.28 * g.dyadique(),
				0.8 + 0.4 * g.dyadique()])
		var ix := FE.index(existants, modeles)
		var r := FE.semer_candidats(modeles[e[1]], e[3], candidats, sens_fr[e[0]], monde, ix, modeles, e[2])
		var acceptes: Array = (r["plants"] as Array).map(func(pl: Dictionary) -> Array:
			var p: Vector3 = pl["p"]
			return [p.x, p.y, p.z, pl["lacet"], pl["echelle"]])
		var refus := {}
		for k in r["refus"]:
			refus[RAISONS_EN[k]] = r["refus"][k]
		cas.append({"name": "brush: %s, model %d, spacing %s, %d candidates" % [e[0], e[1], e[2], e[4]], "kind": "brush",
			"input": {"model": e[1], "mode": e[0], "spacing": e[2], "y_top": e[3], "max_slope": 40.0,
			"candidates": candidats, "plants": existants_en}, "expected": {"plants": acceptes, "refused": refus}})
	# ── place : la pose du modèle (base en colonnes, puis l'origine) et sa hauteur au-dessus du sol
	for e in [[1, Vector3(2.5, 1.0, 3.25), 0.0, 1.0], [1, Vector3(-4.0, 7.5, 2.0), 1.25, 0.8], [2, Vector3(0, 0, 0), 3.0, 1.2]]:
		var m: Dictionary = modeles[e[0]]
		var pl := FE.plant(1, e[0], e[1], e[2], e[3], "sol")
		var t := FE.transformation(m, pl)
		cas.append({"name": "place: model %d at %s, yaw %s, scale %s" % e, "kind": "place",
			"input": {"model": e[0], "point": _f(e[1]), "yaw": e[2], "scale": e[3]},
			"expected": {"basis": [_f(t.basis.x), _f(t.basis.y), _f(t.basis.z)], "origin": _f(t.origin),
			"height_above_ground": FE.hauteur_au_dessus_du_sol(m, pl)}})
	# ── wind : les données par plant, et le balancement d'un sommet
	for e in [[1, Vector3(2.5, 1.0, 3.25), 1.0], [2, Vector3(-30.0, 4.0, 17.5), 0.9]]:
		var m: Dictionary = modeles[e[0]]
		var pl := FE.plant(1, e[0], e[1], 0.0, e[2], "sol")
		var w := FE.vent_du_plant(m, pl)
		cas.append({"name": "wind data: model %d at %s, scale %s" % e, "kind": "wind_data",
			"input": {"model": e[0], "point": _f(e[1]), "scale": e[2]}, "expected": [w.r, w.g, w.b, w.a]})
		# Des sommets AUTOUR DU PLANT : à son pied (immobile), à mi-hauteur, au sommet, sous le sol (immobile).
		for s in [[Vector3(0.0, 0.0, 0.0), Vector3.UP, 0.0], [Vector3(0.2, 1.2, -0.15), Vector3(0, 0, 1), 1.5],
				[Vector3(-0.1, 2.6, 0.05), Vector3(0.6, 0.8, 0), 4.25], [Vector3(-0.1, -0.5, 0.05), Vector3.UP, 2.0]]:
			s[0] = (s[0] as Vector3) + (e[1] as Vector3)
			var v := FE.balancement(s[0], s[1], w, s[2])
			cas.append({"name": "sway: model %d, vertex %s at t %s" % [e[0], s[0], s[2]], "kind": "sway",
				"input": {"wind": [w.r, w.g, w.b, w.a], "vertex": _f(s[0]), "normal": _f(s[1]), "t": s[2],
				"direction": [FE.SENS_DU_VENT.x, FE.SENS_DU_VENT.y]}, "expected": _f(v)})
	var immobile := FE.balancement(Vector3(1, 2, 3), Vector3.UP, Color(1.0, 0.0, 0.5, 1.0), 3.0)
	cas.append({"name": "sway: a height of 0 does not move", "kind": "sway", "input": {"wind": [1.0, 0.0, 0.5, 1.0],
		"vertex": [1, 2, 3], "normal": [0, 1, 0], "t": 3.0, "direction": [FE.SENS_DU_VENT.x, FE.SENS_DU_VENT.y]},
		"expected": _f(immobile)})
	# ── ground_of_cells : le sol quand on n'a pas de tuiles (celui de ces cas)
	var plein := func(c: Vector3i) -> bool: return cases_.has(c)
	for e in [[3.5, 3.5, 10.0], [0.5, 4.0, 10.0], [0.5, 4.0, 2.0], [10.5, 0.5, 9.0], [10.5, 0.5, 2.5], [20.0, 20.0, 9.0]]:
		var gs: Variant = FE.sol_des_cases(plein, e[0], e[1], e[2])
		cas.append({"name": "ground_of_cells: x %s z %s below %s" % e, "kind": "ground_of_cells",
			"input": {"x": e[0], "z": e[1], "y_top": e[2]}, "expected": null if gs == null else gs["y"]})
	cas.append_array(_lectures_feuillage())
	var modeles_en := {}
	for id in modeles:
		modeles_en[str(id)] = _modele_en(modeles[id])
	return {"format": "marchingblocks-foliage-conformance", "version": VERSION,
		"rules_text": COMMUN + Array(FM.regle_feuillage()) + _regle_du_placement() + [
			"CASES — the world is world_cells (its ground is the ground of cells, below); water_cells hold water; models",
			"by id; plants: the plants already there, 7 numbers each as in world.json. check → the refusal (\"\" = planted);",
			"brush → the accepted plants [x, y, z, yaw, scale] in order and the refusals counted by reason; place → the",
			"basis columns and origin of T, and the height above the ground; wind_data → [ground, height, phase, amplitude];",
			"sway → the moved vertex; ground_of_cells → y or null; read: world.json in, foliage out or {\"error\": true}."],
		"constants": {"max_slope_deg": FE.PENTE_MAXI, "ground_tolerance": FE.TOLERANCE_SOL, "edge_samples": FE.ECHANTILLONS,
			"duplicate": FE.DOUBLON, "water_offset": FE.ECART_EAU, "wind_direction": [FE.SENS_DU_VENT.x, FE.SENS_DU_VENT.y],
			"ground_search_floor": -64},
		"world_cells": _cases(cases_), "water_cells": _cases(EAU_FEUILLAGE), "models": modeles_en, "cases": cas}


## LA RÈGLE DE PLACEMENT, écrite (`FE.verifier`, `_semer_un`, `sol_des_cases`), pour les greffons.
static func _regle_du_placement() -> Array:
	return [
		"PLACING (feuillage.gd). r = footprint * s (s = model scale * plant scale). Modes: air, free, overflow.",
		"  1. Neighbours, in EVERY mode: reach = max(spacing, %s), or max(that, r + the largest r of the plants already" % FE.DOUBLON,
		"     there) in free. For each plant q within reach in the plane (and |q.y - p.y| <= reach + 2): planar distance d <",
		"     %s → already_there; d < spacing → too_close; free and d < r + r_q → too_close." % FE.DOUBLON,
		"  2. air: the cell floor(p) full → in_matter; else planted. (Only the plane of the grid is asked.)",
		"  3. Planted (free, overflow): normal.y (normalized) < cos(max_slope) - 1e-6 → too_steep; water at p + (0, 0.1, 0)",
		"     → in_water, where water at q = the cell (floor(q.x), floor(q.y + %s), floor(q.z)) holds water. overflow:" % FE.ECART_EAU,
		"     planted.",
		"  4. free: for the %d points of the footprint circle (angle 2 pi k / %d, radius r), the ground below p.y + 1 must" % [
			FE.ECHANTILLONS, FE.ECHANTILLONS],
		"     exist and be within %s of p.y → else at_edge. Then for the centre and those points at HALF the radius," % FE.TOLERANCE_SOL,
		"     every cell from floor(p.y + 0.3) to floor(p.y + max(height above ground, 0.3)) must be empty → else",
		"     under_matter. Planted.",
		"  The BRUSH: for each candidate (x, z) in order: planted modes look for the ground below y_top (none → no_ground;",
		"  else p.y = ground, normal = its normal); air puts p.y = y_top and normal = up. Then the draw (yaw, scale — given",
		"  in the cases; in the app a random generator draws a, d then yaw, scale), then the check; an accepted plant joins",
		"  the plants AT ONCE (two candidates of one stroke respect each other).",
		"  GROUND OF CELLS (no tiles: these cases): in column (floor(x), floor(z)), from y = floor(y_top) - 1 down to -64,",
		"  the first FULL cell whose cell above is empty: ground y + 1, normal up; none → null. On real tiles the app",
		"  casts a vertical ray against the placed tiles' triangles instead (a quarter cell below the cells' top on the",
		"  thinned witness) — an engine does the same against its own tile meshes.",
	]


static func _lectures_feuillage() -> Array:
	var bon := {"format": FM.FORMAT, "version": FM.VERSION, "layers": [], "foliage": {
		"models": [{"id": 3, "name": "Oak", "mesh": "foliage/oak.glb", "ground_offset": -0.2, "scale": 1.5,
			"scale_random": 0.1, "footprint": 0.6, "height": 3.2, "wind": 0.7},
			{"id": 9, "mesh": null}],
		"plants": [3, 1.5, 2.0, -4.25, 0.5, 1.1, 1, 9, 0.0, 6.0, 0.0, 0.0, 1.0, 0]}}
	var cas_: Array = [["two models (one with every default), two plants", bon],
		["a world without foliage", {"format": FM.FORMAT, "version": FM.VERSION, "layers": []}]]
	var mauvais := {
		"foliage not an object": [],
		"models not an array": {"models": {}},
		"a model without id": {"models": [{"name": "Oak"}], "plants": []},
		"a fractional id": {"models": [{"id": 1.5}], "plants": []},
		"two models with the same id": {"models": [{"id": 3}, {"id": 3}], "plants": []},
		"a number of another type": {"models": [{"id": 3, "scale": "big"}], "plants": []},
		"a mesh that is not a path": {"models": [{"id": 3, "mesh": 12}], "plants": []},
		"plants not in sevens": {"plants": [3, 1, 2, 3, 0, 1]},
		"a plant of an unknown model": {"plants": [4, 0, 0, 0, 0, 1, 1]},
		"a plant not made of numbers": {"plants": [3, 0, "up", 0, 0, 1, 1]},
	}
	for nom in mauvais:
		var m: Dictionary = bon.duplicate(true)
		if mauvais[nom] is Dictionary:
			(m["foliage"] as Dictionary).merge(mauvais[nom], true)
		else:
			m["foliage"] = mauvais[nom]
		cas_.append([nom, m])
	var sortie: Array = []
	for c in cas_:
		var lu := FM.lire_feuillage(JSON.parse_string(JSON.stringify(c[1])))
		sortie.append({"name": "read: " + c[0], "kind": "read", "input": c[1],
			"expected": {"error": true} if lu.has("error") else lu["foliage"]})
	return sortie


# ══ L'EAU ════════════════════════════════════════════════════════════════════════════════════════════

const GENRES_EAU_EN := {"": "", "ocean": "sea", "lac": "lake", "riviere": "river"}
const FINS_EN := {"": "", "sort": "leaves", "rejoint": "joins", "ferme": "closed"}
const COURS_EN := {"coule": "flow", "chute": "fall", "lac": "lake"}
const ERREURS_EAU_EN := {"": "", "dans_la_matiere": "in_matter", "dans_l_eau": "in_water", "trop_grand": "too_large",
	"trop_long": "too_long", "un_seul_ocean": "one_sea_only"}


## Les mondes de l'eau, petits (la mer s'écrit case par case).
static func _mondes_eau() -> Dictionary:
	var m := {}
	# Une plaine de 13 × 13 (y 0..1), un cratère de 3 × 3 au milieu (y = 1 creusé) : loin du bord, un lac CALME.
	var plaine := {}
	for c in _boite(Vector3i(0, 0, 0), Vector3i(12, 1, 12)):
		plaine[c] = true
	for c in _boite(Vector3i(5, 1, 5), Vector3i(7, 1, 7)):
		plaine.erase(c)
	m["crater in a plain"] = plaine
	# Le même cratère près du bord (x 1..3) : une chute à moins de 4 cases du seuil → il DÉBORDE, une rivière.
	var bord := {}
	for c in _boite(Vector3i(0, 0, 0), Vector3i(12, 1, 12)):
		bord[c] = true
	for c in _boite(Vector3i(1, 1, 5), Vector3i(3, 1, 7)):
		bord.erase(c)
	m["crater near the edge"] = bord
	# Un escalier de trois marches de 3 cases (hauteurs 3, 2, 1), 3 de large.
	var escalier := {}
	for x in 9:
		var h := 3 - x / 3
		for z in 3:
			for y in h:
				escalier[Vector3i(x, y, z)] = true
	m["stairs"] = escalier
	# Une île de 3 × 3 sur un fond : la mer l'entoure.
	var ile := {}
	for c in _boite(Vector3i(0, 0, 0), Vector3i(8, 0, 8)):
		ile[c] = true
	for c in _boite(Vector3i(3, 1, 3), Vector3i(5, 3, 5)):
		ile[c] = true
	m["island"] = ile
	# Une grotte close : une cavité de 3 × 2 × 3 dans un bloc, une source au plafond de la cavité.
	var grotte := {}
	for c in _boite(Vector3i(0, 0, 0), Vector3i(4, 4, 4)):
		grotte[c] = true
	for c in _boite(Vector3i(1, 1, 1), Vector3i(3, 2, 3)):
		grotte.erase(c)
	m["closed cave"] = grotte
	return m


static func _corps_en(r: Dictionary) -> Dictionary:
	var lacs: Array = (r["lacs"] as Array).map(func(l: Dictionary) -> Dictionary:
		return {"level": l["niveau"], "cells": _cases(l["cases"])})
	var cours: Array = (r["cours"] as Array).map(func(c: Dictionary) -> Array:
		var v: Vector3i = c["case"]
		return [v.x, v.y, v.z, COURS_EN[c["genre"]], int(c.get("lac", -1))])
	return {"kind": GENRES_EAU_EN[r["genre"]], "error": ERREURS_EAU_EN[r["erreur"]], "level": r["niveau"],
		"end": FINS_EN[r["fin"]], "water": _cases(r["eau"]), "lakes": lacs, "course": cours}


static func _eau() -> Dictionary:
	var mondes := _mondes_eau()
	var cas: Array = []
	var essais := [
		["a calm lake in a crater", "crater in a plain", [Vector3i(6, 3, 6)]],
		["a crater near a fall overflows into a river", "crater near the edge", [Vector3i(2, 2, 6)]],
		["a river down the stairs, it leaves the world", "stairs", [Vector3i(0, 3, 1)]],
		["a sea around an island", "island", [Vector3i(-1, 2, -1)]],
		["one sea only: the second is refused", "island", [Vector3i(-1, 2, -1), Vector3i(9, 1, 9)]],
		["a river from the island top joins the sea", "island", [Vector3i(-1, 2, -1), Vector3i(4, 4, 4)]],
		["the order of the sources does not matter (the sea first anyway)", "island",
			[Vector3i(4, 4, 4), Vector3i(-1, 2, -1)]],
		["a source inside matter", "stairs", [Vector3i(0, 1, 1)]],
		["a source in the sea's water", "island", [Vector3i(-1, 2, -1), Vector3i(0, 1, 0)]],
		["a lake in a closed cave", "closed cave", [Vector3i(2, 2, 2)]],
		["two rivers side by side", "stairs", [Vector3i(0, 3, 0), Vector3i(0, 3, 2)]],
	]
	for e in essais:
		var occ: Dictionary = mondes[e[1]]
		var w := FL.monde(occ, e[2])
		cas.append({"name": "world: " + e[0], "kind": "water_world", "input": {"world": e[1],
			"sources": (e[2] as Array).map(func(s: Vector3i) -> Array: return _v(s))},
			"expected": {"bodies": (w["corps"] as Array).map(func(r: Dictionary) -> Dictionary: return _corps_en(r)),
			"sea": _cases(w["ocean"])}})
	# ── river_width : les sources côte à côte, en travers du premier pas
	for e in [["3 wide on the stairs", "stairs", Vector3i(0, 3, 1), 3], ["2 wide (one more on the + side)", "stairs",
			Vector3i(0, 3, 1), 2], ["5 wide: only the rivers stay", "stairs", Vector3i(0, 3, 1), 5],
			["a lake does not widen", "crater in a plain", Vector3i(6, 3, 6), 3], ["width 1", "stairs", Vector3i(0, 3, 1), 1]]:
		var sources := FL.sources_en_largeur(mondes[e[1]], e[2], e[3])
		cas.append({"name": "river_width: " + e[0], "kind": "river_width", "input": {"world": e[1], "source": _v(e[2]),
			"width": e[3]}, "expected": sources.map(func(s: Vector3i) -> Array: return _v(s))})
	# ── surface et profondeur (le contrat de la nappe : COLOR_0 a = profondeur / 8)
	var lac := FL.monde(mondes["crater in a plain"], [Vector3i(6, 3, 6)])
	var eau_lac: Dictionary = lac["corps"][0]["eau"]
	var mer := FL.monde(mondes["island"], [Vector3i(-1, 2, -1)])
	for e in [["the crater lake", mondes["crater in a plain"], eau_lac, [Vector3i(6, 1, 6), Vector3i(5, 1, 7)]],
			["the sea", mondes["island"], mer["ocean"], [Vector3i(0, 1, 0), Vector3i(-1, 1, -1), Vector3i(-1, 0, 4),
				Vector3i(2, 2, 4)]]]:
		var prof: Array = (e[3] as Array).map(func(c: Vector3i) -> Array: return [c.x, c.y, c.z, FL.profondeur(e[2], e[1], c)])
		cas.append({"name": "surface and depth: " + e[0], "kind": "surface_depth", "input": {"world": e[0],
			"water": _cases(e[2]), "cells": (e[3] as Array).map(func(c: Vector3i) -> Array: return _v(c))},
			"expected": {"surface": _cases(FL.surface(e[2], e[1])), "depth": prof}})
	cas.append_array(_lectures_eau())
	var mondes_en := {}
	for k in mondes:
		mondes_en[k] = _cases(mondes[k])
	# Les mondes d'eau de surface_depth sont nommés par leur ensemble d'eau : on y joint leurs cases.
	mondes_en["the crater lake"] = mondes_en["crater in a plain"]
	mondes_en["the sea"] = mondes_en["island"]
	return {"format": "marchingblocks-water-conformance", "version": VERSION,
		"rules_text": COMMUN + Array(FM.regle_eau()) + _regle_de_l_eau() + [
			"CASES — water_world {world (a key of worlds), sources} → bodies, one per source in order: {kind (sea, lake,",
			"river, or \"\" when refused), error, level, end, water (a sea's or a lake's cells, a river's LAKES' cells),",
			"lakes [{level, cells}], course [[x, y, z, flow | fall | lake, the lake's index or -1]]}, and sea (the sea's",
			"cells). river_width {world, source, width} → the sources. surface_depth {world, water, cells} → the surface",
			"cells and [x, y, z, depth] (-1: no floor). read: world.json in, water out or {\"error\": true}."],
		"limits": {"volume_max": FL.VOLUME_MAXI, "steps_max": FL.ETAPES_MAXI, "overflow_reach": FL.PORTEE_DE_DEBORD},
		"worlds": mondes_en, "cases": cas}


## LA RÈGLE DE L'EAU, résumée (la référence est `fluides.gd`, ligne à ligne ; les cas tranchent).
static func _regle_de_l_eau() -> Array:
	return [
		"THE WATER RULE (fluides.gd is the reference, read it line by line; these cases are the arbiter). Water never",
		"  changes cells; it is DEDUCED from the sources and the cells of EVERY tile layer (hidden ones too), and again",
		"  after every change. Neighbours are always visited in this order: +x, -x, +z, -z, down, up; heaps are tied by",
		"  insertion order (never by a hash table). The BOX is the box of the full cells grown by 1; its sides and its",
		"  bottom (not its top) are the HORIZON.",
		"  A source in a full cell: in_matter; in water already: in_water. A source with nothing full below it in its",
		"  column is a SEA at its y: every empty cell joined to the horizon without going above that level (a cavity",
		"  fills only through a duct open below the level). ONE sea: the first source in the void, in source order.",
		"  Other sources run against the sea only (their order does not matter). The water falls to the ground, then:",
		"  a HOLLOW (no cell to fall from at its floor, flat-reachable) fills by PRIORITY FLOOD up to its threshold —",
		"  the first cell out of the heap touching the horizon or other water fixes P, the lake is all cells out below",
		"  P, level P - 1; a lake whose threshold has, flat, a fall or other water within %d cells OVERFLOWS: it is the" % FL.PORTEE_DE_DEBORD,
		"  first lake of a RIVER leaving from the threshold; else it stays calm (closed if it never reached the",
		"  horizon). A RIVER takes the shortest flat path to a cell it can fall from, falls (fall cells) to the ground or",
		"  to water (joins) or out of the bottom of the box (leaves), and starts again; a hollow met on the way fills",
		"  and overflows (lake on the river). More than %d cells for a lake: too_large; more than %d steps: too_long." % [
			FL.VOLUME_MAXI, FL.ETAPES_MAXI],
		"  RIVER WIDTH: width sources side by side ACROSS the first horizontal step of the river placed at s, centred",
		"  (one more on the + side when even), s first; only neighbours that are rivers stay; a lake or a sea never",
		"  widens. SURFACE: water cells whose cell above is neither water nor full. DEPTH: water cells down to the floor",
		"  (the cell included), -1 when the water reaches the bottom without a floor.",
	]


static func _lectures_eau() -> Array:
	var bon := {"format": FM.FORMAT, "version": FM.VERSION, "layers": [], "water": [
		{"name": "Sea", "visible": true, "look": "reflective", "mesh": "water/sea.glb", "sources": [-3, 2, -3]},
		{"name": "Lava", "visible": false, "look": "lava", "mesh": null, "sources": [4, 4, 4, 0, 3, 1]},
		{"name": "Odd", "visible": true, "look": "something new", "mesh": null, "sources": []}]}
	var cas_: Array = [["three water layers (an unknown look is accepted)", bon],
		["a world without water", {"format": FM.FORMAT, "version": FM.VERSION, "layers": []}]]
	var mauvais := {
		"water not an array": {"water": {}},
		"a water layer without look": {"water": [{"name": "Sea", "visible": true, "mesh": null, "sources": []}]},
		"a mesh that is not a path": {"water": [{"name": "Sea", "visible": true, "look": "clear", "mesh": 3,
			"sources": []}]},
		"sources not in triples": {"water": [{"name": "Sea", "visible": true, "look": "clear", "mesh": null,
			"sources": [1, 2]}]},
		"a fractional source": {"water": [{"name": "Sea", "visible": true, "look": "clear", "mesh": null,
			"sources": [1, 2.5, 3]}]},
	}
	for nom in mauvais:
		var m: Dictionary = bon.duplicate(true)
		m.merge(mauvais[nom], true)
		cas_.append([nom, m])
	var sortie: Array = []
	for c in cas_:
		var lu := FM.lire_eau(JSON.parse_string(JSON.stringify(c[1])))
		sortie.append({"name": "read: " + c[0], "kind": "read", "input": c[1],
			"expected": {"error": true} if lu.has("error") else lu["water"]})
	return sortie


# ══ LE MAILLAGE DE L'EAU — la nappe recalculée (7 octobre 2026) ══════════════════════════════════════════
# Ce que `EauMaillage.maillage` rend pour des corps d'eau DONNÉS (au format des `water_world`, relus par JSON comme un
# greffon les lit) : un ENSEMBLE CANONIQUE de triangles — chacun dans le sens du format (glTF : anti-horaire vu de
# l'avant), ses trois coins tournés pour que le plus petit soit le premier, la liste triée. Un greffon compare SANS
# l'ordre des triangles ni celui des sommets, et à une tolérance près (les flottants 32 bits de Godot ; voir
# `_regle_du_maillage`). Pourquoi un ensemble de triangles et pas des invariants : PARITE.md §12 et la charte.

const GENRES_MAILLAGE_EN := {0.0: "still", 0.5: "river", 0.75: "foam", 1.0: "fall"}
const TOLERANCES_MAILLAGE := {"position": 1e-4, "normal": 1e-3, "color": 1e-4, "uv": 1e-4, "area": 1e-3}


## Les mondes du maillage : ceux de la règle, plus une dalle sur un pilier (l'étage flottant), une falaise au-dessus
## d'un bassin (une cascade de quatre cases qui le remplit) et le monde vide.
static func _mondes_maillage() -> Dictionary:
	var m := _mondes_eau()
	var dalle := {}
	for c in _boite(Vector3i(0, 3, 0), Vector3i(4, 3, 4)) + _boite(Vector3i(2, 0, 2), Vector3i(2, 2, 2)):
		dalle[c] = true
	m["a slab on a pillar"] = dalle
	# La falaise (x ≤ 2, dessus en y = 4), au pied un bassin d'une case de profondeur (x 3..5, z 0..2, en y = 1), cerné
	# d'un rebord : la rivière part de (2, 5, 1) — le bassin de `test_fluides`.
	var bassin := {}
	for c in _boite(Vector3i(-4, 0, -3), Vector3i(7, 0, 5)) + _boite(Vector3i(-4, 1, -3), Vector3i(2, 4, 5)) \
			+ _boite(Vector3i(3, 1, -1), Vector3i(6, 1, 3)):
		bassin[c] = true
	for c in _boite(Vector3i(3, 1, 0), Vector3i(5, 1, 2)):
		bassin.erase(c)
	m["a cliff above a basin"] = bassin
	m["an empty world"] = {}
	# DEUX RIVIÈRES AU MÊME ENDROIT (7 octobre 2026 — le trou que les trois greffons ont mesuré : deux mutations du
	# mailleur, « la lèvre la plus BASSE gardée » et « deux bandes sur une même case », ne rougissaient sur AUCUN cas) :
	# une falaise (x 0..4, y 0..5, z 0..2) percée d'une galerie en y = 2, z = 1 (x 3..4), au pied une plaine (x 5..10,
	# y = 0). Une rivière tombe du haut, l'autre sort de la galerie : deux cascades sur la MÊME face (x = 5), à la même
	# place (z = 1), de lèvres différentes — une seule nappe, de la plus haute ; au pied, elles coulent sur les MÊMES
	# cases — une bande par case. Le monde de la garde que le greffon Godot avait écrite (`test_greffon_peinture`).
	var galerie := {}
	for c in _boite(Vector3i(0, 0, 0), Vector3i(4, 5, 2)) + _boite(Vector3i(5, 0, 0), Vector3i(10, 0, 2)):
		galerie[c] = true
	galerie.erase(Vector3i(3, 2, 1))
	galerie.erase(Vector3i(4, 2, 1))
	m["a cliff pierced by a gallery"] = galerie
	return m


## Un corps relu depuis l'anglais (`_corps_en`) : ce qu'un greffon a en main. Ni `colonnes` ni `emprise` — le maillage
## relit alors la surface de la mer dans son eau (`surface_dessinee`), ce que `test_parite` vérifie égal.
static func corps_depuis_en(b: Dictionary) -> Dictionary:
	var en_cases := func(l: Array) -> Dictionary:
		var d := {}
		for c in l:
			d[Vector3i(int(c[0]), int(c[1]), int(c[2]))] = true
		return d
	var lacs: Array = []
	for l in b["lakes"]:
		lacs.append({"niveau": int(l["level"]), "cases": en_cases.call(l["cells"])})
	var cours: Array = []
	for e in b["course"]:
		var g: String = _inverse(COURS_EN, e[3])
		var d := {"case": Vector3i(int(e[0]), int(e[1]), int(e[2])), "genre": g}
		if g == "lac":
			d["lac"] = int(e[4])
		cours.append(d)
	return {"genre": _inverse(GENRES_EAU_EN, b["kind"]), "erreur": _inverse(ERREURS_EAU_EN, b["error"]),
		"niveau": int(b["level"]), "eau": en_cases.call(b["water"]), "lacs": lacs, "cours": cours,
		"fin": _inverse(FINS_EN, b["end"])}


static func _inverse(d: Dictionary, v: String) -> String:
	for k in d:
		if d[k] == v:
			return k
	return ""


## Arrondi au millionième (le bruit des flottants 32 bits de Godot disparaît : 0,699999988 → 0,7), sans −0.
static func _r6(x: float) -> float:
	return roundf(x * 1e6) / 1e6 + 0.0


## L'ENSEMBLE CANONIQUE des triangles d'un maillage d'eau (null : aucun). Chaque triangle : 36 nombres, trois coins de
## [px, py, pz, nx, ny, nz, r, g, b, a, u, v], dans le sens du FORMAT (anti-horaire vu de l'avant, comme le `.glb` :
## (B − A) × (C − A) du côté de la normale) — l'ordre de Godot (horaire) est retourné ; le coin le plus petit
## (lexicographique) d'abord, sans changer le sens ; les triangles triés.
## ⚠ DEPUIS LES TABLEAUX (`EM.tableaux_du_maillage`), PAS DEPUIS L'ArrayMesh : celui-ci range les couleurs sur 8 bits et
## les normales en octaèdre (mesuré : 0,5 relu 0,498039, une normale (0, 1, 0) relue avec z = −1,5e−5).
static func triangles_canoniques(a: Dictionary) -> Array:
	var v: PackedVector3Array = a["v"]
	var n: PackedVector3Array = a["n"]
	var c: PackedColorArray = a["c"]
	var uv: PackedVector2Array = a["uv"]
	var idx: PackedInt32Array = a["i"]
	var coins: Array = []
	for k in v.size():
		coins.append([_r6(v[k].x), _r6(v[k].y), _r6(v[k].z), _r6(n[k].x), _r6(n[k].y), _r6(n[k].z), _r6(c[k].r),
			_r6(c[k].g), _r6(c[k].b), _r6(c[k].a), _r6(uv[k].x), _r6(uv[k].y)])
	var tris: Array = []
	for t in range(0, idx.size(), 3):
		var tri: Array = [coins[idx[t]], coins[idx[t + 2]], coins[idx[t + 1]]]
		var premier := 0
		for r in [1, 2]:
			if _avant(tri[r], tri[premier]):
				premier = r
		tris.append(tri[premier] + tri[(premier + 1) % 3] + tri[(premier + 2) % 3])
	tris.sort_custom(_avant)
	return tris


## LE MÊME ENSEMBLE, RANGÉ SANS REDITE (le fichier passait 1,6 Mo en triangles à 36 nombres) : les coins distincts triés,
## et chaque triangle en trois indices, le plus petit d'abord sans changer le sens, triés. Déplié — vertices[i] pour
## chaque indice —, c'est exactement la liste de `triangles_canoniques`, à l'ordre près.
static func triangles_indexes(tris: Array) -> Dictionary:
	var coins := {}
	for t: Array in tris:
		for k in 3:
			coins[t.slice(12 * k, 12 * k + 12)] = true
	var liste: Array = coins.keys()
	liste.sort_custom(_avant)
	var rang := {}
	for i in liste.size():
		rang[liste[i]] = i
	var tri_i: Array = []
	for t: Array in tris:
		var r: Array = [rang[t.slice(0, 12)], rang[t.slice(12, 24)], rang[t.slice(24, 36)]]
		var p := 0
		for k in [1, 2]:
			if int(r[k]) < int(r[p]):
				p = k
		tri_i.append([r[p], r[(p + 1) % 3], r[(p + 2) % 3]])
	tri_i.sort_custom(_avant)
	return {"vertices": liste, "triangles": tri_i}


static func _avant(a: Array, b: Array) -> bool:
	for k in mini(a.size(), b.size()):
		if a[k] != b[k]:
			return a[k] < b[k]
	return a.size() < b.size()


## Le résumé par genre (b du premier coin) : nombre de triangles et aire — un diagnostic avant l'appariement.
static func resume_des_triangles(tris: Array) -> Dictionary:
	var r := {}
	for g in GENRES_MAILLAGE_EN.values():
		r[g] = {"triangles": 0, "area": 0.0}
	for t: Array in tris:
		var g: String = GENRES_MAILLAGE_EN.get(float(t[8]), "?")
		if not r.has(g):
			r[g] = {"triangles": 0, "area": 0.0}
		var a := Vector3(t[0], t[1], t[2])
		var x := (Vector3(t[12], t[13], t[14]) - a).cross(Vector3(t[24], t[25], t[26]) - a)
		r[g]["triangles"] += 1
		r[g]["area"] += 0.5 * x.length()
	for g in r:
		r[g]["area"] = roundf(float(r[g]["area"]) * 1000.0) / 1000.0
	return r


static func _maillage_eau() -> Dictionary:
	var mondes := _mondes_maillage()
	var esc: Dictionary = mondes["stairs"]
	# [nom, monde, sources (toutes les couches), les corps de LA couche maillée (indices) ou null : tous]
	var essais := [
		["a calm lake in a crater", "crater in a plain", [Vector3i(6, 3, 6)], null],
		["a lake that overflows into a river", "crater near the edge", [Vector3i(2, 2, 6)], null],
		["a river down the stairs: bands, three waterfalls, a spring", "stairs", [Vector3i(0, 3, 1)], null],
		["a river three cells wide down the stairs (river_width 3)", "stairs",
			FL.sources_en_largeur(esc, Vector3i(0, 3, 1), 3), null],
		["a sea around an island", "island", [Vector3i(-1, 2, -1)], null],
		["one sea only: the second source draws nothing", "island", [Vector3i(-1, 2, -1), Vector3i(9, 1, 9)], null],
		["a river joins the sea, in the sea's layer", "island", [Vector3i(-1, 2, -1), Vector3i(4, 4, 4)], null],
		["the same river in a layer of its own", "island", [Vector3i(-1, 2, -1), Vector3i(4, 4, 4)], [1]],
		["the sea under a floating slab", "a slab on a pillar", [Vector3i(10, 2, 10)], null],
		["a lake under the ceiling of a closed cave", "closed cave", [Vector3i(2, 2, 2)], null],
		["a waterfall into a basin it fills", "a cliff above a basin", [Vector3i(2, 5, 1)], null],
		["a sea above the whole world", "island", [Vector3i(-1, 6, -1)], null],
		["a sea in an empty world: one plane", "an empty world", [Vector3i(0, 0, 0)], null],
		["a refused source draws nothing", "stairs", [Vector3i(0, 1, 1)], null],
		["two rivers in one place: one falls from the top, one leaves a gallery below, on the same cells",
			"a cliff pierced by a gallery", [Vector3i(4, 6, 1), Vector3i(3, 2, 1)], null],
	]
	var cas: Array = []
	for e in essais:
		var occ: Dictionary = mondes[e[1]]
		var w := FL.monde(occ, e[2])
		var corps: Array = w["corps"]
		if e[3] != null:
			corps = (e[3] as Array).map(func(i: int) -> Dictionary: return corps[i])
		# Les corps passent par l'anglais et le JSON, comme chez un greffon ; le maillage part de CE qu'il lit.
		var en: Array = JSON.parse_string(JSON.stringify(corps.map(func(r: Dictionary) -> Dictionary: return _corps_en(r))))
		var relus: Array = en.map(func(b: Dictionary) -> Dictionary: return corps_depuis_en(b))
		var tris := triangles_canoniques(EM.tableaux_du_maillage(relus, occ, FL.boite(occ)))
		var ix := triangles_indexes(tris)
		cas.append({"name": "mesh: " + e[0], "kind": "water_mesh", "input": {"world": e[1], "bodies": en},
			"expected": {"summary": resume_des_triangles(tris), "vertices": ix["vertices"], "triangles": ix["triangles"]}})
	var mondes_en := {}
	for k in mondes:
		mondes_en[k] = _cases(mondes[k])
	return {"format": "marchingblocks-water-mesh-conformance", "version": VERSION,
		"rules_text": COMMUN + _regle_du_maillage() + [
			"CASES — water_mesh {world (a key of worlds), bodies (ONE water layer: water_world bodies, in order)} →",
			"{summary {still | river | foam | fall: {triangles, area}}, vertices, triangles}. vertices: distinct corners",
			"[px, py, pz, nx, ny, nz, r, g, b, a, u, v] (COLOR_0 is r g b a, TEXCOORD_0 is u v); triangles: [i, j, k]",
			"into vertices — only a compact storage: unfold each into its three corners and compare TRIANGLES, listed",
			"COUNTER-CLOCKWISE seen from the front (glTF; (B - A) x (C - A) is on the side of the normals) — Godot's",
			"ArrayMesh lists them clockwise: reverse. The expected values are rounded to 1e-6.",
			"COMPARE AS A BAG, NOT AS A LIST: same number of triangles; every expected triangle matched to a DISTINCT",
			"triangle of yours equal under one of its three ROTATIONS (A B C, B C A, C A B — never a reflection: the",
			"winding is part of the contract), corner by corner within tolerances: position and uv 1e-4, normal 1e-3,",
			"color 1e-4 (bucket your triangles by their centroid rounded to 0.01 and search the 27 neighbouring",
			"buckets). The summary (kind = b of the first corner; area within 1e-3 + 1e-6 x area) is a diagnosis: when",
			"it differs, the bag will too. Compare the arrays you COMPUTE, before the engine stores them: nothing is",
			"quantized here (Godot's ArrayMesh keeps colours in 8 bits and normals octahedral; the .glb colours are in",
			"1/255)."],
		"constants": {"surface": EM.NAPPE, "river": EM.RIVIERE, "overlap": EM.DEBORD, "sheet": EM.LAME, "arc": EM.ARC,
			"flare": EM.EVASE, "flare_max": EM.EVASE_MAXI, "into_rock": EM.DANS_LA_ROCHE, "rounding": EM.ARRONDI,
			"overhang": EM.DEPASSE, "churn": EM.REMOUS, "spray": EM.EMBRUN, "foam_rise": EM.MONTEE_D_ECUME,
			"horizon": EM.LARGE, "spring": EM.SOURCE, "spring_dome": EM.SOURCE_DOME},
		"tolerances": TOLERANCES_MAILLAGE, "worlds": mondes_en, "cases": cas}


## LE MAILLEUR, résumé ligne à ligne (la référence est `eau_maillage.gd` ; les cas tranchent).
static func _regle_du_maillage() -> Array:
	return [
		"THE WATER MESH (eau_maillage.gd is the reference, read it line by line; these cases are the arbiter). One mesh",
		"  per WATER LAYER, from its bodies (water_world, in order) and the full cells of EVERY tile layer; BOX = the box",
		"  of the full cells grown by 1 (empty world: no box). A body with an error draws nothing; no triangle at all is",
		"  an empty mesh. Floats: computed in DOUBLE, vertices stored in 32-bit floats (Godot's Vector3, Color).",
		"  color(flow f, kind k, a) = (f.x * 0.5 + 0.5, f.z * 0.5 + 0.5, k, clamp(a, 0, 1)); kinds: still 0, river 0.5,",
		"  foam 0.75, fall 1. Constants: see constants (surface 0.7, river -0.15, overlap 0.45, ...).",
		"DORMANT waters: the sea's cells, a lake's cells, each lake of each river (cells), in body order.",
		"FLAT RECTANGLES {x0, x1, z0, z1, h, color}, body by body:",
		"  sea: SHEET(water, level, h forced to level + 0.7 when the box exists and level > box.hi.y), then the HORIZON",
		"    at level + 0.7, color(0, still, 1): no box → [-2000, 2000] x [-2000, 2000]; else with the box lo..hi:",
		"    x [-2000, 2000] z [-2000, lo.z]; x [-2000, 2000] z [hi.z + 1, 2000]; x [-2000, lo.x] z [lo.z, hi.z + 1];",
		"    x [hi.x + 1, 2000] z [lo.z, hi.z + 1].   lake: SHEET(water, level).   river: SHEET(cells, level) of each of",
		"    its lakes, then its BANDS and WATERFALLS (below).",
		"  SHEET(W, L): the drawn surface S = cells of W whose cell above is neither in W nor full, PLUS cells of W at",
		"    y = L whose cell above is full (water under a floating storey or a ceiling). depth p = cells of W from the",
		"    cell down to the floor (included), -1 without a floor; color(0, still, p < 0 ? 1 : p / 8). Overlaps: xm =",
		"    0.45 if (x-1, y, z) is full else 0; xp, zm, zp likewise for x+1, z-1, z+1. Sort S by (y, z, x). ROWS: a cell",
		"    extends the current row if same y and z, row end == x, row xp == 0 and cell xm == 0, same zm, zp, color",
		"    (then row end = x + 1, row xp = cell xp); else it starts a row {y, z, start x, end x + 1, xm, xp, zm, zp,",
		"    color}. RECTANGLES, rows in order: x0 = start - xm, x1 = end + xp; if an OPEN rectangle has the key (y, z,",
		"    x0, x1, color), it is closed and grows z1 = z + 1 + zp; else a new one {x0, x1, z - zm, z + 1 + zp, h = y +",
		"    0.7 or the forced h, color}. If the row's zp == 0, the rectangle is open under the key (y, z + 1, x0, x1,",
		"    color).",
		"  RIVER (rivers of the layer share one SEEN set and one SPRINGS list): SPRING at course[0]'s cell if it is a",
		"    flow cell on a full cell, not already a spring. BAND for each course cell c that is not a lake entry, has a",
		"    full cell below and is not SEEN (then it is): flow d = (next cell - c) if next is a horizontal neighbour,",
		"    else (c - previous) if horizontal, else 0; rectangle [c.x - xm, c.x + 1 + xp] x [c.z - zm, c.z + 1 + zp],",
		"    overlaps as in SHEET at c's row, h = c.y - 0.15, color(d, river, 0.05). WATERFALL for each run of fall",
		"    entries i..j-1: lip = course[i-1] (c + up if i = 0); d = lip - course[i-2] if i >= 2 and horizontal, else",
		"    the first f of +x, -x, +z, -z with (course[i] - f) full, else 0; bottom = course[j-1]. top = lip.y - 0.15;",
		"    foot = bottom.y - 0.3; ground = bottom.y - 0.15 if bottom + down is full else foot; the FIRST dormant water",
		"    holding bottom: h = its highest cell above bottom (contiguous), ground = h.y + 0.7, foot = min(foot, ground",
		"    - 0.15). PLANE: axis x if d.x != 0 else z; sense = d.x or d.z; along = lip.z (axis x) or lip.x; d = 0:",
		"    axis z, sense 1, along = lip.x, plane = lip.z + 0.5; else plane = lip.x (axis x) or lip.z, + 1 when sense",
		"    < 0. Waterfalls with the same (axis, round(plane * 20), along) are ONE: top = max, foot = min, ground = min.",
		"  WATERFALL SHEET (after all rivers): straight = (d = 0); free0 = not straight and no waterfall at along - 1 on",
		"    the same plane; free1 likewise at along + 1. u0 = along - (0.1 if free0), u1 = along + 1 + (0.1 if free1).",
		"    ACROSS: u0 + f if free0 and u1 - f if free1 for f in 0, 0.05, 0.1, 0.2, 0.3, 0.35, plus along, along + 0.5,",
		"    along + 1; sorted; kept within [u0 - 0.001, u1 + 0.001]; one within 0.005 of the previous kept is dropped.",
		"    DROPS (total = top - foot): 0, 0.02, 0.06, 0.12, 0.2, 0.3, 0.42, 0.55, 0.7 those < total - 0.01; then 1.2,",
		"    1.7, ... while < total - 0.2; then total. out(h) = 0.35 sqrt(clamp(h / 0.7, 0, 1)) + min(0.04 max(h - 0.7,",
		"    0), 0.2). profile(u) = 1, and if free0 and u < u0 + 0.35: t = clamp((u - u0) / 0.35, 0, 1), min with",
		"    sqrt(1 - (1 - t)^2); free1 likewise with (u1 - u). POINT(u, h): r = straight ? 0 : profile(u); s = plane +",
		"    (straight ? 0 : lerp(-0.4 clamp(h / 0.15, 0, 1), out(h), r)) * sense; y = top - h; axis x: (s, y, u),",
		"    axis z: (u, y, s). NORMAL(u, h): tu = POINT(u + 0.01, h) - POINT(u - 0.01, h), th = POINT(u, h + 0.01) -",
		"    POINT(u, max(h - 0.01, 0)) (points as 32-bit vectors), n = (th x tu) * (axis x ? -sense : sense);",
		"    |n| < 1e-9 → (sense, 0, 0) axis x or (0, 0, sense) axis z; else normalized. GRID rows = drops, columns =",
		"    across: POINT, NORMAL, color(d, fall, e^2) with e = clamp(1 - (y - ground) / 1.3, 0, 1), uv (u, y). The top",
		"    row's points are T-JUNCTION POINTS for the flats (below).",
		"  FOAM of a waterfall: hg = clamp(top - ground, 0, total); per column u: p = POINT(u, hg), n = NORMAL(u, hg),",
		"    dir = (n.x, 0, n.z), if |dir| < 0.2 → (sense, 0, 0) or (0, 0, sense); dir normalized; foot = (p.x, ground,",
		"    p.z). CROWN(offsets, rises, foams, flat, weights): row k, column i: foot + dir * offset_k + (0, rise_k +",
		"    (flat ? 0.02 : 0), 0); normal flat ? up : dir; color(d, foam, foam_k * weight_i); uv flat ? (u, ground -",
		"    1.5 offset_k) : (u, y). RING = CROWN(0 0.25 0.55 0.85, 0 0 0 0, 1 0.85 0.45 0, flat, 1). SPRAY = CROWN(0.06",
		"    0.16 0.22 0.2, 0 0.3 0.6 0.9, 0.95 0.7 0.35 0, standing, straight ? 1 : profile(u)^3).",
		"  SPRING at cell c: centre (c.x + 0.5, c.y - 0.15, c.z + 0.5), 17 columns i = 0..16, angle = 2 pi (i mod 16) /",
		"    16, dir (cos, 0, sin). DISC rows radius 0 0.2 0.42 0.7, lift 0.08 0.056 0.024 0.02, foam 1 0.95 0.6 0:",
		"    centre + dir r + (0, lift, 0), normal up, color(0, foam, f), uv (angle * 0.6, centre.y - 1.5 r). VEIL rows",
		"    radius 0.12 0.2 0.24, lift 0.02 0.18 0.34, foam 0.8 0.45 0: normal dir, uv (angle * 0.6, centre.y + lift).",
		"  GRID → TRIANGLES: each quad (i, j): k0 (i, j), k1 (i, j+1), k2 (i+1, j+1), k3 (i+1, j); triangles (k0, k1, k2)",
		"    and (k0, k2, k3); x = (B - A) x (C - A); dropped if |x| < 1e-7; else listed so that its cross product is on",
		"    the side of the normal of its FIRST corner (k0): (A, B, C) if x . n(k0) > 0, else (A, C, B).",
		"  FLATS → TRIANGLES (no T-junction): coordinates compared in TWENTIETHS (round(v * 20)). Every rectangle's four",
		"    corners and every T-junction point are registered on their lines (h, z) → x and (h, x) → z. For each",
		"    rectangle, its OUTLINE: (x0, z0), the registered x strictly between x0 and x1 on (h, z0) ascending, (x1,",
		"    z0), the z strictly between on (h, x1) ascending, (x1, z1), on (h, z1) descending, (x0, z1), on (h, x0)",
		"    descending. 4 points: triangles (P0, P2, P1) and (P0, P3, P2). More: a FAN from the centre C: (C, P(k+1),",
		"    P(k)) for every k (cyclic). Normal up, uv (x, z), the rectangle's color. Draw order (not compared, it",
		"    matters for transparency): waterfall sheets, flats, then the foam (rings, sprays, springs) LAST.",
	]

# ══ ÉDITION — les demandes du 3 octobre, Extrude / Shrink, la molette ════════════════════════════════════

const QUOI_EN := {"haut": "up", "bas": "down", "face": "facing"}
const MODES_EXTRUDE_EN := {"poser": "place", "etendre": "extend", "decaler": "shift"}


## Le monde de l'édition : un sol de 6 × 6 à y = 0, un mur ÉPAIS (z 0..1) de deux cases de haut le long de x, un pilier.
static func _monde_edition() -> Dictionary:
	var m := {}
	for c in _boite(Vector3i(0, 0, 0), Vector3i(5, 0, 5)):
		m[c] = true
	for c in _boite(Vector3i(0, 1, 0), Vector3i(5, 2, 1)):
		m[c] = true
	for y in range(1, 4):
		m[Vector3i(4, y, 4)] = true
	return m


static func _edition() -> Dictionary:
	var m := _monde_edition()
	var cas: Array = []
	# ── extrude : poser / étendre / décaler × haut / bas / face, sur une sélection ou sur l'étage
	var selections := {
		"no selection (the floor's matter at y = 0)": [],
		"a selection on the floor, empty cells included": [Vector3i(2, 0, 3), Vector3i(3, 0, 3), Vector3i(2, 1, 3)],
		"the front of the wall": [Vector3i(1, 1, 1), Vector3i(2, 1, 1), Vector3i(3, 1, 1), Vector3i(1, 2, 1)],
		"a selection in the air": [Vector3i(1, 5, 1), Vector3i(2, 5, 1)],
	}
	for quoi in QUOI_EN:
		for mode in MODES_EXTRUDE_EN:
			for nom in selections:
				var sel := _ensemble(selections[nom])
				var r := Etages.extruder(m, 0, quoi, sel, mode)
				cas.append({"name": "extrude %s, %s, on %s" % [QUOI_EN[quoi], MODES_EXTRUDE_EN[mode], nom], "kind": "extrude",
					"input": {"cells": "world", "floor": 0, "direction": QUOI_EN[quoi], "mode": MODES_EXTRUDE_EN[mode],
					"selection": _cases(sel)}, "expected": {"set": _cases(r["poser"]), "clear": _cases(r["effacer"]),
					"selection": _cases(r["selection"]), "step": _v(r["sens"])}})
	# L'étage 2 sans sélection : la matière du mur à y = 2 ; « face » y trouve son sens.
	for quoi in QUOI_EN:
		var r := Etages.extruder(m, 2, quoi, {}, "poser")
		cas.append({"name": "extrude %s, place, on floor 2 (no selection)" % QUOI_EN[quoi], "kind": "extrude",
			"input": {"cells": "world", "floor": 2, "direction": QUOI_EN[quoi], "mode": "place", "selection": []},
			"expected": {"set": _cases(r["poser"]), "clear": _cases(r["effacer"]), "selection": _cases(r["selection"]),
			"step": _v(r["sens"])}})
	# ⚠ UNE ÉGALITÉ DE « FACE » (greffon Unity, 7 octobre 2026) : le haut du pilier regarde vers le haut, le devant du mur vers
	# +z, une case chacun — l'ordre des sens départage (le haut d'abord). Sans ce cas, « le dernier sens l'emporte » passait muet.
	var egalite := _ensemble([Vector3i(4, 3, 4), Vector3i(2, 1, 1)])
	var re := Etages.extruder(m, 0, "face", egalite, "poser")
	cas.append({"name": "extrude facing, place, on a tie (up comes before +z)", "kind": "extrude",
		"input": {"cells": "world", "floor": 0, "direction": "facing", "mode": "place", "selection": _cases(egalite)},
		"expected": {"set": _cases(re["poser"]), "clear": _cases(re["effacer"]), "selection": _cases(re["selection"]),
		"step": _v(re["sens"])}})
	# ── shrink_edge : `retrecir_bord` (remplace l'ancien `shrink` de tools_conformance.json)
	var formes := {
		"a flat 4x4 rectangle": _boite(Vector3i(0, 5, 0), Vector3i(3, 5, 3)),
		"a line of 5": _boite(Vector3i(0, 5, 0), Vector3i(4, 5, 0)),
		"a full 3x3x3 cube": _boite(Vector3i(0, 0, 0), Vector3i(2, 2, 2)),
		"a single cell": [Vector3i(7, 7, 7)],
		"an L of matter and air": [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(2, 1, 0),
			Vector3i(2, 2, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(2, 0, 1)],
		"a 5x5 square, negative": _boite(Vector3i(-6, -1, -6), Vector3i(-2, -1, -2)),
	}
	for nom in formes:
		var sel := _ensemble(formes[nom])
		var r := Outils.operer_selection(m, sel, "retrecir_bord")
		cas.append({"name": "shrink_edge: " + nom, "kind": "shrink_edge", "input": {"selection": _cases(sel)},
			"expected": _cases(r["selection"])})
	# ── widen_flat : Alt + molette vers le haut sur une sélection
	for nom in ["a single cell", "a line of 5", "an L of matter and air"]:
		var sel := _ensemble(formes[nom])
		cas.append({"name": "widen_flat: " + nom, "kind": "widen_flat", "input": {"selection": _cases(sel)},
			"expected": _cases(Outils.elargir_a_plat(sel))})
	# ── select_brush : le pinceau Select, « Select empty cells too », et le geste inverse
	var occupe := func(c: Vector3i) -> bool: return m.has(c)
	var cibles := Outils.pinceau(Vector3i(2, 0, 3), Vector3i(0, 1, 0), 2, "cube")
	for e in [["matter only", false, false, []], ["empty cells too", true, false, []],
			["onto an existing selection", false, false, [Vector3i(0, 4, 0), Vector3i(2, 0, 3)]],
			["the inverse gesture removes, full or empty", false, true, [Vector3i(2, 1, 3), Vector3i(2, 0, 3),
				Vector3i(5, 5, 5)]]]:
		var avant := _ensemble(e[3])
		var apres := Outils.selectionner_au_pinceau(avant.duplicate(), cibles, occupe, e[1], e[2])
		cas.append({"name": "select_brush: " + e[0], "kind": "select_brush", "input": {"cells": "world",
			"selection": _cases(avant), "targets": _cases(cibles), "include_empty": e[1], "deselect": e[2]},
			"expected": _cases(apres)})
	# ── room_from_selection : `FS.salle_depuis`
	var roc := {}
	for c in _boite(Vector3i(20, -6, 0), Vector3i(26, 0, 6)):
		roc[c] = true
	var l_forme: Array = []
	for x in 5:
		for z in 3:
			l_forme.append(Vector3i(x, 0, z))
	for x in 3:
		for z in range(3, 5):
			l_forme.append(Vector3i(x, 0, z))
	var deux_carres: Array = _boite(Vector3i(0, 0, 0), Vector3i(2, 0, 2)) + _boite(Vector3i(3, 0, 3), Vector3i(5, 0, 5))
	var salles := [
		["a 3x3 footprint, rising 1 floor", {}, _boite(Vector3i(0, 0, 0), Vector3i(2, 0, 2)), 1, true],
		["a 3x3 footprint, sinking 2 floors", {}, _boite(Vector3i(0, 0, 0), Vector3i(2, 0, 2)), 2, false],
		["an L footprint", {}, l_forme, 2, true],
		["in rock: the inside is dug", roc, _boite(Vector3i(21, 0, 1), Vector3i(25, 0, 5)), 2, false],
		["a line: too small", {}, _boite(Vector3i(0, 0, 0), Vector3i(4, 0, 0)), 1, true],
		["the base on two heights (rising: the lowest)", {}, _boite(Vector3i(0, 0, 0), Vector3i(2, 0, 2))
			+ [Vector3i(1, 3, 1)], 1, true],
		["the base on two heights (sinking: the highest)", {}, _boite(Vector3i(0, 0, 0), Vector3i(2, 0, 2))
			+ [Vector3i(1, 3, 1)], 1, false],
		["two squares touching by a corner: repaired", {}, deux_carres, 1, true],
		["floors clamped", {}, _boite(Vector3i(0, 0, 0), Vector3i(2, 0, 2)), 99, true],
		["an empty selection", {}, [], 1, true],
	]
	for e in salles:
		var r := FS.salle_depuis(e[1], _ensemble(e[2]), e[3], e[4])
		var err := str(r["erreur"])
		var boite: Array = (r.get("boite", []) as Array).map(func(v: Vector3i) -> Array: return _v(v))
		cas.append({"name": "room_from_selection: " + e[0], "kind": "room_from_selection",
			"input": {"cells": _cases(e[1]), "selection": _cases(e[2]), "floors": e[3], "up": e[4]},
			"expected": {"error": "empty" if err == "vide" else EO.ERREURS_EN.get(err, err), "set": _cases(r["poser"]),
			"clear": _cases(r["effacer"]), "repaired": r["reparees"], "box": boite}})
	return {"format": "marchingblocks-editing-conformance", "version": VERSION,
		"rules_text": COMMUN + _regle_de_l_edition() + [
			"CASES — input.cells \"world\" means world_cells. extrude → {set, clear, selection, step}; shrink_edge and",
			"widen_flat → the selection; select_brush → the selection after; room_from_selection → {error, set, clear,",
			"repaired, box [lo, hi] ([] on an error)}."],
		"limits": {"box_volume_max": Outils.VOLUME_MAXI, "room_floors_max": FS.ETAGES_MAXI},
		"world_cells": _cases(m), "cases": cas}


static func _regle_de_l_edition() -> Array:
	return [
		"EXTRUDE (etages.gd, extruder) replaces Extrude up / down of the selection operations. direction up, down or facing;",
		"  the BASE is the selection, or (none) the full cells at y = floor. Step: up (0,1,0), down (0,-1,0), facing = the",
		"  direction d among up, down, +x, -x, +z, -z (that order breaks ties) where the most base cells p (full cells",
		"  only, when there is no selection: those at y = floor; with one: the full cells of the selection) have p + d",
		"  empty and p - d full; none: step 0 and nothing changes. shifted = base + step.",
		"  place (click): set p + step for every FULL base cell p where p + step is empty; the selection becomes shifted",
		"  (stays empty when there was none). extend (Shift + click, \"Extend selection\"): nothing set; the selection becomes",
		"  base + shifted. shift (Alt + click): nothing set; the selection becomes shifted. The floor follows step.y.",
		"SHRINK (shrink_edge, replaces the old shrink): a cell of the selection is on the EDGE when, on some axis, the",
		"  selection goes on on one side and stops on the other (c - f selected, c + f not, for any of the six faces f).",
		"  The edge leaves; full or empty cells alike. A rectangle loses its rim, a line its ends, a cube its skin, a",
		"  single cell stays.",
		"WIDEN (widen_flat): the selection plus the four horizontal neighbours of every cell. Nothing is set.",
		"SELECT BRUSH: the brush's cells join the selection — only the full ones, or all of them with \"Select empty cells",
		"  too\"; the inverse gesture (Shift in the plugins) removes them, full or empty.",
		"ROOM FROM SELECTION (formes_speciales.gd, salle_depuis): the FOOTPRINT is the selection seen from above (x, z);",
		"  the base is its lowest y when rising, its highest when sinking. Inside = footprint cells whose four horizontal",
		"  neighbours are in the footprint; none: too_small; an empty selection: empty. e = clamp(floors, 1,",
		"  room_floors_max); y0 = base (rising) or base - e - 1 (sinking); y1 = y0 + e + 1; footprint size * (e + 2) >",
		"  box_volume_max: too_large. For every footprint cell and y in [y0, y1]: y = y0, y = y1 or not inside → SET if",
		"  empty (floor, ceiling, walls); else CLEAR if full. Then REPAIR as an add shape (tools_conformance.json, the",
		"  special shapes: checkerboard 2x2 squares, by rounds). box = [(min x, y0, min z), (max x, y1, max z)].",
		"THE MOUSE WHEEL (app/editor.gd, _molette_du_monde) — a UI rule, not in the cases; the same in the three editors:",
		"  in Navigate: never ours. No modifier: zoom, EXCEPT during a gesture — a Rect / Box drag: its height (one cell",
		"  per notch, a flat Rect becomes a box); a Room being traced: its floors; a paste preview: its height.",
		"  Ctrl + Shift with the Stairs shape: its step. Ctrl: the grid floor. With a SELECTION and a selection tool",
		"  (Select, Rect, Box): Shift = Extend selection up / down (extrude extend), Alt up = widen_flat, Alt down =",
		"  shrink_edge — nothing is set. Room shape: Alt = floors, Shift = rises / sinks. Other shapes: Alt = size, Shift",
		"  = length. Add / Dig / Select: Alt = brush size, Shift = the next brush shape. Each notch says its value near",
		"  the mouse. Panels: a slider or a number field never takes the wheel; only a scrolling panel scrolls.",
		"  Water (if a plugin places water one day): Alt = river width. F frames all the matter of the visible layers.",
	]
