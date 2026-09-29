extends RefCounted
## LE FORMAT DU MONDE PEINT v1 — ce que l'atelier World livre aux trois greffons.
##
## **DÉCIDÉ (Jordan, 29 septembre 2026)** : « dans WORLD, une section pour gérer le monde peint — déjà
## l'exporter vers les trois addons ». La charte le tenait OUVERT depuis le format des tuiles (§4 :
## « l'export des MONDES peints, `world.json` : couches, jeu de tuiles, cases »).
##
##   <nom>.mbworld/
##     world.json          les couches, dans l'ordre : nom, visibilité, jeu de tuiles, CASES
##     <jeu>.mbset/        un dossier de tuiles (format neutre, §4) par SOURCE distincte
##     README.txt
##
## ⚠ **LE MONDE SE SUFFIT À LUI-MÊME** : ses jeux de tuiles voyagent DANS son dossier, et `world.json`
## les désigne par un chemin RELATIF. Un monde qui pointerait vers un `.mbset` ailleurs sur le disque
## arriverait chez l'acheteur sans ses tuiles.
## ⚠ **UNE SOURCE, UN DOSSIER** : deux couches tranchées du même travail partagent le même `.mbset`.
## ⚠ **UNE COUCHE SANS TUILES VOYAGE QUAND MÊME** — ses cases sont du travail — avec `"tileset": null`.
## Le greffon la montre sans tuiles, et le DIT (charte §3 : l'absence se voit).
## ⚠ **LES CASES SONT EN ESPACE DU FORMAT** (la case `c` occupe `[c, c+1]`, +Y en haut), à plat par
## triplets — `[x0, y0, z0, x1, y1, z1, …]` — TRIÉES, pour qu'un même monde s'écrive toujours pareil.
## Un greffon d'un autre repère les convertit par le repère MESURÉ de leur jeu de tuiles (§4), comme les
## cases qu'on y peint.

const FN := preload("res://addons/marchingblocks_core/format_neutre.gd")

const FORMAT := "marchingblocks-world"
const FORMAT_EPREUVE := "marchingblocks-world-conformance"
const VERSION := 1


## LA RÈGLE DE LECTURE — écrite dans le README, et c'est elle que les trois greffons implémentent.
static func regle() -> PackedStringArray:
	return PackedStringArray([
		"MARCHINGBLOCKS WORLD v1 — world.json",
		"",
		"format   must be \"marchingblocks-world\". version: refuse anything newer than 1.",
		"layers   an array, in order. Each layer:",
		"  name      a string",
		"  visible   true or false",
		"  tileset   the path of a tileset.json RELATIVE to world.json, or null (a layer without tiles:",
		"            its cells still travel; show that it has no tiles, never invent some)",
		"  cells     a flat array of integers, x y z per cell, in FORMAT space: cell c covers [c, c+1],",
		"            +Y is up. Its length is a multiple of 3. The same cell never appears twice.",
		"Refuse the whole file, and say why, if any of these does not hold.",
	])


## Écrit le monde. `couches` : [{nom, visible, source, lot (MeshLibrary ou null), cases (Array de
## Vector3i)}], dans l'ordre. Rend {"dossier", "couches", "jeux", "sans_tuiles": [noms]} ou {"erreur"}.
static func exporter(couches: Array, dossier: String, nom: String, generateur: String) -> Dictionary:
	if couches.is_empty():
		return {"erreur": "this world has no layer"}
	var cible := dossier.path_join(_propre(nom, "world") + ".mbworld")
	DirAccess.make_dir_recursive_absolute(cible)
	var jeux := {}          # source → chemin relatif de son tileset.json
	var noms_pris := {}
	var sorties: Array = []
	var sans_tuiles: Array = []
	for c in couches:
		var source: String = str(c.get("source", ""))
		var lot = c.get("lot")
		var jeu: Variant = null
		if source != "" and lot is MeshLibrary and not (lot as MeshLibrary).get_item_list().is_empty():
			if not jeux.has(source):
				# Un nom de dossier par source : celui de la première couche qui l'emploie, rendu unique.
				var base := _propre(str(c["nom"]), "tileset")
				var n := base
				var i := 2
				while noms_pris.has(n):
					n = "%s_%d" % [base, i]
					i += 1
				noms_pris[n] = true
				var r: Dictionary = FN.exporter(lot, cible, n, generateur)
				if r.has("erreur"):
					return {"erreur": "layer « %s »: %s" % [c["nom"], r["erreur"]]}
				jeux[source] = (r["dossier"] as String).get_file().path_join("tileset.json")
			jeu = jeux[source]
		else:
			sans_tuiles.append(str(c["nom"]))
		sorties.append({"name": str(c["nom"]), "visible": bool(c.get("visible", true)), "tileset": jeu,
			"cells": cases_a_plat(c.get("cases", []))})
	var monde := {"format": FORMAT, "version": VERSION, "generator": generateur, "name": _propre(nom, "world"),
		"layers": sorties}
	var f := FileAccess.open(cible.path_join("world.json"), FileAccess.WRITE)
	if f == null:
		return {"erreur": "world.json could not be written (error %d)" % FileAccess.get_open_error()}
	f.store_string(JSON.stringify(monde, "  "))
	f.close()
	var r2 := FileAccess.open(cible.path_join("README.txt"), FileAccess.WRITE)
	if r2 != null:
		r2.store_string("\n".join(regle()) + "\n\nMade with %s. Open it with the free MarchingBlocks Paint "
			% generateur + "plugin for Godot, Unity or Unreal: Import MarchingBlocks world.\n")
		r2.close()
	return {"dossier": cible, "couches": sorties.size(), "jeux": jeux.size(), "sans_tuiles": sans_tuiles}


## Les cases, triées (y, puis z, puis x), à plat par triplets.
static func cases_a_plat(cases: Array) -> Array:
	var triees := cases.duplicate()
	triees.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		if a.z != b.z:
			return a.z < b.z
		return a.x < b.x)
	var plat: Array = []
	var vues := {}
	for c in triees:
		if vues.has(c):
			continue
		vues[c] = true
		plat.append_array([c.x, c.y, c.z])
	return plat


static func _propre(nom: String, defaut: String) -> String:
	var n := ""
	for ch in nom.to_lower().strip_edges():
		n += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-" else "_"
	return n if n != "" else defaut


# ── LA LECTURE DE RÉFÉRENCE ET SES CAS D'ÉPREUVE ─────────────────────────────────────────────────────
#
# ⚠ Trois greffons liront `world.json` : la règle ci-dessus est exécutée ICI une fois, et ses réponses
# partent en `world_conformance.json` avec chacun (même parade que pour la pose et les outils, §4). Les
# cas exercent ce qu'ils nomment : coordonnées négatives, couche sans tuiles, couche cachée, et chaque
# refus.

## Lit un monde déjà décodé du JSON. Rend {"layers": [{name, visible, tileset, cells: [[x,y,z]…]}]} ou
## {"error": raison}.
static func lire(monde: Variant) -> Dictionary:
	if not monde is Dictionary or str((monde as Dictionary).get("format", "")) != FORMAT:
		return {"error": "not a MarchingBlocks world"}
	var v = monde.get("version")
	if not (v is float or v is int) or int(v) != v or int(v) < 1:
		return {"error": "no valid version"}
	if int(v) > VERSION:
		return {"error": "world format version %d is newer than this plugin (%d)" % [int(v), VERSION]}
	var couches = monde.get("layers")
	if not couches is Array:
		return {"error": "layers is not an array"}
	var sortie: Array = []
	for c in couches:
		if not c is Dictionary or not c.get("name") is String or not c.get("visible") is bool:
			return {"error": "a layer has no name or no visibility"}
		var jeu = c.get("tileset")
		if jeu != null and not jeu is String:
			return {"error": "layer « %s »: tileset is neither a path nor null" % c["name"]}
		var plat = c.get("cells")
		if not plat is Array or (plat as Array).size() % 3 != 0:
			return {"error": "layer « %s »: cells is not a list of x y z triples" % c["name"]}
		var cases: Array = []
		var vues := {}
		for i in range(0, plat.size(), 3):
			var t: Array = [plat[i], plat[i + 1], plat[i + 2]]
			for n in t:
				if not (n is float or n is int) or int(n) != n:
					return {"error": "layer « %s »: a cell coordinate is not an integer" % c["name"]}
			var cle := Vector3i(int(t[0]), int(t[1]), int(t[2]))
			if vues.has(cle):
				return {"error": "layer « %s »: the cell %s appears twice" % [c["name"], cle]}
			vues[cle] = true
			cases.append([cle.x, cle.y, cle.z])
		sortie.append({"name": c["name"], "visible": c["visible"], "tileset": jeu, "cells": cases})
	return {"layers": sortie}


static func cas_d_epreuve() -> Dictionary:
	var bon := {"format": FORMAT, "version": VERSION, "generator": "conformance", "name": "sample",
		"layers": [
			{"name": "Rock", "visible": true, "tileset": "rock.mbset/tileset.json",
				"cells": cases_a_plat([Vector3i(0, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, -3),
					Vector3i(-7, -2, 5)])},
			{"name": "Ice", "visible": false, "tileset": null, "cells": cases_a_plat([Vector3i(2, 0, 2)])},
			{"name": "Empty", "visible": true, "tileset": "rock.mbset/tileset.json", "cells": []},
		]}
	var cas: Array = [{"name": "two layers, negative cells, a hidden layer without tiles, an empty layer",
		"world": bon}]
	var mauvais := {
		"newer version": {"version": VERSION + 1},
		"wrong format": {"format": "marchingblocks-tileset"},
		"no version": {"version": null},
		"cells not in triples": {"layers": [{"name": "A", "visible": true, "tileset": null, "cells": [0, 0]}]},
		"a cell twice": {"layers": [{"name": "A", "visible": true, "tileset": null, "cells": [1, 2, 3, 1, 2, 3]}]},
		"a fractional cell": {"layers": [{"name": "A", "visible": true, "tileset": null, "cells": [0, 0.5, 0]}]},
		"tileset neither path nor null": {"layers": [{"name": "A", "visible": true, "tileset": 3, "cells": []}]},
		"layer without visibility": {"layers": [{"name": "A", "tileset": null, "cells": []}]},
	}
	for nom in mauvais:
		var m: Dictionary = bon.duplicate(true)
		m.merge(mauvais[nom], true)
		cas.append({"name": nom, "world": m})
	# L'attendu de chaque cas est la lecture de référence ; un refus s'écrit {"error": true} — la RAISON
	# n'est pas imposée aux greffons, seulement le refus.
	var ecrits: Array = []
	for c in cas:
		var lu := lire(JSON.parse_string(JSON.stringify(c["world"])))
		ecrits.append({"name": c["name"], "world": c["world"],
			"expected": {"error": true} if lu.has("error") else lu})
	return {"format": FORMAT_EPREUVE, "version": VERSION, "rule": Array(regle()), "cases": ecrits}
