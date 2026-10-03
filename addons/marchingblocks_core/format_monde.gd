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
##     water/<nom>.glb     la nappe CUITE d'une couche d'eau (charte §5, « le mode Fluids »), une par couche
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

## ⚠ L'EAU VOYAGE DANS LE MONDE, PAS DANS UN JEU DE TUILES : un `.mbset` appartient à une couche de tuiles, l'eau au
## monde entier (DÉCIDÉ, Jordan, 1er octobre 2026). Ses noms d'aspect, en anglais pour les greffons.
const ASPECTS := {"stylise": "stylized", "transparent": "clear", "reflechissant": "reflective",
	"lave": "lava", "marais": "swamp", "acide": "acid"}

const FORMAT := "marchingblocks-world"
const FORMAT_EPREUVE := "marchingblocks-world-conformance"
const VERSION := 1


## LA RÈGLE DE LECTURE — écrite dans le README, et c'est elle que les trois greffons implémentent.
static func regle() -> PackedStringArray:
	return PackedStringArray([
		"MARCHINGBLOCKS WORLD v1 — world.json",
		"",
		"format   must be \"marchingblocks-world\". version: refuse anything newer than 1.",
		"layers   an array, in PRIORITY order (the first is the highest: where layers meet, its tiles are",
		"         placed — the tileset rule, step 7). Each layer:",
		"  name      a string",
		"  visible   true or false",
		"  tileset   the path of a tileset.json RELATIVE to world.json, or null (a layer without tiles:",
		"            its cells still travel; show that it has no tiles, never invent some)",
		"  cells     a flat array of integers, x y z per cell, in FORMAT space: cell c covers [c, c+1],",
		"            +Y is up. Its length is a multiple of 3. The same cell never appears twice.",
		"Refuse the whole file, and say why, if any of these does not hold.",
	])


## LA RÈGLE DE L'EAU — écrite dans le README. ⚠ PAS ENCORE DANS `regle()` NI DANS LES CAS D'ÉPREUVE des greffons
## (étape 5 du mode Fluids) : la clé `water` est en plus, et les lecteurs actuels ne lisent que `layers`.
static func regle_eau() -> PackedStringArray:
	return PackedStringArray([
		"water    (optional) an array of water layers, in order. Each water layer:",
		"  name      a string",
		"  visible   true or false",
		"  look      a string: \"stylized\", \"clear\", \"reflective\", \"lava\", \"swamp\" or \"acid\" — a",
		"            SUGGESTION only (lava, swamp and acid flow and fill hollows exactly like water). The looks shipped",
		"            with the plugins are examples: assign any water shader you like, it gets the data below.",
		"  mesh      the path of a .glb RELATIVE to world.json, or null (nothing to draw). Its vertices are in",
		"            FORMAT space, like the cells. Every vertex carries the water data:",
		"              COLOR_0 r, g   the flow along x and z, mapped from [-1, 1] to [0, 1]; 0.5 0.5 is still water",
		"              COLOR_0 b      the kind of water: 0 still (lake, sea), 0.5 river, 0.75 foam (the churning",
		"                             water at the foot of a waterfall, its spray, a spring), 1 waterfall",
		"              COLOR_0 a      on still water and rivers, the depth below, in cells / 8, capped at 1 (1 too",
		"                             for a bottomless sea); on a waterfall and on foam, the amount of foam, 0 to 1",
		"              NORMAL         the shape of the water (a waterfall is a curved, closed sheet)",
		"              TEXCOORD_0     x, z on still water and rivers; across, height on a waterfall",
		"            Colours are quantized to 1/255.",
		"  sources   a flat array of integers, x y z per source cell: where the water was placed. The mesh",
		"            is deduced from them and from the cells of EVERY layer; a plugin may deduce it again.",
	])


## Écrit le monde. `couches` : [{nom, visible, source, lot (MeshLibrary ou null), cases (Array de
## Vector3i)}], dans l'ordre. Rend {"dossier", "couches", "jeux", "sans_tuiles": [noms]} ou {"erreur"}.
## `eaux` : [{nom, visible, preset, sources (Array de Vector3i), maillage (ArrayMesh ou null)}], dans l'ordre.
static func exporter(couches: Array, dossier: String, nom: String, generateur: String, eaux: Array = []) -> Dictionary:
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
	var sorties_eau: Array = []
	var noms_eau := {}
	for e in eaux:
		var maillage: Variant = null
		if e.get("maillage") is ArrayMesh:
			var base := _propre(str(e["nom"]), "water")
			var n := base
			var i := 2
			while noms_eau.has(n):
				n = "%s_%d" % [base, i]
				i += 1
			noms_eau[n] = true
			DirAccess.make_dir_recursive_absolute(cible.path_join("water"))
			var aspect: String = ASPECTS.get(str(e.get("preset", "")), "stylized")
			var raison := _ecrire_la_nappe(e["maillage"], cible.path_join("water").path_join(n + ".glb"), n, aspect)
			if raison != "":
				return {"erreur": "water « %s »: %s" % [e["nom"], raison]}
			maillage = "water/%s.glb" % n
		sorties_eau.append({"name": str(e["nom"]), "visible": bool(e.get("visible", true)),
			"look": ASPECTS.get(str(e.get("preset", "")), "stylized"), "mesh": maillage,
			"sources": _sources_a_plat(e.get("sources", []))})
	var monde := {"format": FORMAT, "version": VERSION, "generator": generateur, "name": _propre(nom, "world"),
		"layers": sorties, "water": sorties_eau}
	var f := FileAccess.open(cible.path_join("world.json"), FileAccess.WRITE)
	if f == null:
		return {"erreur": "world.json could not be written (error %d)" % FileAccess.get_open_error()}
	f.store_string(JSON.stringify(monde, "  "))
	f.close()
	var r2 := FileAccess.open(cible.path_join("README.txt"), FileAccess.WRITE)
	if r2 != null:
		r2.store_string("\n".join(regle()) + "\n\n" + "\n".join(regle_eau()) + "\n\nMade with %s. Open it with the free MarchingBlocks Paint "
			% generateur + "plugin for Godot, Unity or Unreal: Import MarchingBlocks world.\n")
		r2.close()
	return {"dossier": cible, "couches": sorties.size(), "jeux": jeux.size(), "sans_tuiles": sans_tuiles,
		"eaux": sorties_eau.size(), "nappes": noms_eau.size()}


## Les sources d'une couche d'eau, à plat, DANS L'ORDRE (une source n'est pas une case : l'ordre est celui où
## elles ont été posées, et il dit quelle rivière est laquelle).
static func _sources_a_plat(sources: Array) -> Array:
	var plat: Array = []
	for s in sources:
		var v: Vector3i = s
		plat.append_array([v.x, v.y, v.z])
	return plat


## Écrit une nappe en .glb : UN nœud, UN maillage nommés `nom` (⚠ l'importeur d'Unreal fait un StaticMesh par
## MAILLAGE : sans nom, il arriverait anonyme — charte §4), un matériau nommé `mb_water_<aspect>` que le greffon
## remplace. ⚠ On écrit une COPIE du maillage : celui de la vue garde son shader.
static func _ecrire_la_nappe(maillage: ArrayMesh, chemin: String, nom: String, aspect: String) -> String:
	var copie := maillage.duplicate() as ArrayMesh
	var mat := StandardMaterial3D.new()
	mat.resource_name = "mb_water_" + aspect
	mat.albedo_color = Color(0.2, 0.5, 0.75, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	copie.surface_set_material(0, mat)
	var racine := Node3D.new()
	racine.name = "world_water"
	var mi := MeshInstance3D.new()
	mi.name = nom
	mi.mesh = copie
	racine.add_child(mi)
	var doc := GLTFDocument.new()
	var etat := GLTFState.new()
	var e := doc.append_from_scene(racine, etat)
	if e == OK:
		for m in etat.get_meshes():
			(m as GLTFMesh).resource_name = nom
		e = doc.write_to_filesystem(etat, chemin)
	racine.free()
	return "" if e == OK else "the water mesh could not be written (error %d)" % e


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


## LA LECTURE DE L'EAU, selon `regle_eau()`. Rend {"water": [{name, visible, look, mesh, sources: [[x,y,z]…]}]}
## ou {"error"}. Un monde sans clé `water` n'a pas d'eau. ⚠ Un aspect inconnu est ACCEPTÉ : c'est une suggestion.
static func lire_eau(monde: Variant) -> Dictionary:
	if not monde is Dictionary:
		return {"error": "not a MarchingBlocks world"}
	var liste = (monde as Dictionary).get("water", [])
	if not liste is Array:
		return {"error": "water is not an array"}
	var sortie: Array = []
	for e in liste:
		if not e is Dictionary or not e.get("name") is String or not e.get("visible") is bool \
				or not e.get("look") is String:
			return {"error": "a water layer has no name, visibility or look"}
		var m = e.get("mesh")
		if m != null and not m is String:
			return {"error": "water « %s »: mesh is neither a path nor null" % e["name"]}
		var plat = e.get("sources")
		if not plat is Array or (plat as Array).size() % 3 != 0:
			return {"error": "water « %s »: sources is not a list of x y z triples" % e["name"]}
		var sources: Array = []
		for i in range(0, plat.size(), 3):
			for n in [plat[i], plat[i + 1], plat[i + 2]]:
				if not (n is float or n is int) or int(n) != n:
					return {"error": "water « %s »: a source coordinate is not an integer" % e["name"]}
			sources.append([int(plat[i]), int(plat[i + 1]), int(plat[i + 2])])
		sortie.append({"name": e["name"], "visible": e["visible"], "look": e["look"], "mesh": m, "sources": sources})
	return {"water": sortie}


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
