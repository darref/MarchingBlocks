@tool
extends RefCounted
## LE FORMAT NEUTRE — ce que MarchingBlocks livre aux greffons de peinture Godot, Unity et Unreal.
##
## **DÉCIDÉ (Jordan, 27 septembre 2026)** : format OUVERT, greffons GRATUITS ; la valeur vendue est le
## logiciel qui FABRIQUE les tuiles (charte §0, §4). Un jeu de tuiles est un dossier `<nom>.mbset/` :
##   tileset.json  le manifeste — la table des 256 configurations, la règle écrite, la liste des tuiles ;
##   tiles.glb     un nœud par tuile, maillage centré sur l'origine, matériaux de l'artiste ;
##   README.txt    la règle en clair.
##
## ⚠ **LE FICHIER PORTE LA RÈGLE, PAS SEULEMENT LES TUILES.** Trois greffons qui réécriraient chacun la
## classification, c'est la seconde description qui diverge (charte §6). Tout ce qui se PRÉ-CALCULE
## (la table) est écrit ; ce qui doit se recalculer en jeu (le contexte) est décrit, et gardé
## par des CAS D'ÉPREUVE (`cas_d_epreuve()`) que chaque greffon doit reproduire à 100 %.
## ⚠ **LA RÉFÉRENCE EST `MB.poses()`**, celle-là même que le peintre de l'appli appelle.
## ⚠ **LES NOMS SORTENT EN ANGLAIS, EN `[a-z0-9_]`** — un acheteur les lit dans son moteur (charte §7),
## et certains moteurs refusent des caractères comme `~` ou `.` dans un nom d'asset. La traduction vit
## ICI et nulle part ailleurs ; les greffons ne décodent jamais un nom, ils lisent la liste `tiles`.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")

const FORMAT := "marchingblocks-tileset"
const FORMAT_EPREUVE := "marchingblocks-conformance"
const VERSION := 1
const SUFFIXE_DEHORS := "_outdoor"

## LE REPÈRE TÉMOIN — un tétraèdre aux sommets (0,0,0), (1,0,0), (0,2,0), (0,0,3), livré dans `tiles.glb`.
## ⚠ **ON MESURE LA CONVERSION DE L'IMPORTEUR AU LIEU DE LA SUPPOSER.** Unity est gaucher, Unreal gaucher
## en +Z et en centimètres, et chaque importeur glTF (glTFast, UnityGLTF, Interchange…) convertit à sa
## façon — dans les sommets ou dans la pose du nœud. Le greffon lit où l'importeur a posé ces quatre
## points : les LONGUEURS 1, 2, 3 disent quel axe est lequel, le signe dit le miroir, la plus courte
## l'échelle. Il convertit ensuite la grille des cases par cette même application (règle, ligne « Frame »).
const MARQUEUR := "mb_frame"
const POINTS_DU_MARQUEUR := [[0, 0, 0], [1, 0, 0], [0, 2, 0], [0, 0, 3]]

## Mot à mot, les mots des noms de classes. ⚠ Un mot absent d'ici passe tel quel : `id_anglais` vérifie
## que le résultat n'est fait que de `[a-z0-9_]`, et `table_des_ids` qu'aucun id n'est porté deux fois.
const MOTS := {
	"vide": "empty", "coin": "corner", "arete": "edge", "diagonale": "diagonal", "equerre": "ell",
	"plaque": "slab", "trepied": "tripod", "tetra": "tetra", "pointe": "spike", "biais": "slant",
	"vrille": "twist", "g": "left", "d": "right", "crochet": "hook", "creuse": "inner", "creux": "inner",
	"chicane": "chicane", "damier": "checker", "plein": "full",
}


## L'id anglais d'une CLASSE (« mb_arete_creuse_b2h2 » → « edge_inner_b2h2 »).
static func id_de_classe(nom: String) -> String:
	var mots := PackedStringArray()
	for m in nom.trim_prefix("mb_").split("_", false):
		mots.append(MOTS.get(m, m))
	return "_".join(mots)


## L'id anglais d'une CLÉ (classe + contexte) : « …_dehors » → « …_outdoor ».
static func id_de_cle(cle: String) -> String:
	if cle.ends_with(MB.SUFFIXE_DEHORS):
		return id_de_classe(cle.trim_suffix(MB.SUFFIXE_DEHORS)) + SUFFIXE_DEHORS
	return id_de_classe(cle)


## Le nom de la tuile d'une clé, en sortie. ⚠ UNE tuile par clé (charte §3, 30 septembre 2026) : son nom
## EST l'id de la clé — les « _2 », « _3 » des exemplaires ont vécu du 27 au 30 septembre.
static func nom_de_tuile(cle: String) -> String:
	return id_de_cle(cle)


## LES QUARTS DE TOUR d'un index d'orientation de GridMap : k tel que la base est une rotation de
## k × 90° autour de +Y, main droite (un quart de tour envoie +Z sur +X).
## ⚠ DÉRIVÉ DE LA BASE, JAMAIS ÉCRIT EN DUR : mesuré le 27 septembre 2026, les index 0, 16, 10, 22
## donnent 0, 1, 2, 3 — une table recopiée mentirait le jour où Godot renumérote. −1 si ce n'est pas
## une rotation autour de Y (le groupe « oriente » n'en produit pas).
static func quarts_de_tour(orientation: int) -> int:
	var g := GridMap.new()
	var cherche: int = -1
	for k in 4:
		if g.get_orthogonal_index_from_basis(Basis(Vector3.UP, k * PI / 2.0)) == orientation:
			cherche = k
			break
	g.free()
	return cherche


## LA TABLE : pour chaque configuration de 8 bits, [indice de classe, quarts de tour], ou [−1, 0] sans
## surface. Les indices renvoient à `classes_du_format()`.
static func table() -> Array:
	var quarts := {}
	var sortie: Array = []
	for b in 256:
		var r: Dictionary = MB.classer(b)
		if not r["surface"]:
			sortie.append([-1, 0])
			continue
		var o: int = r["orientation"]
		if not quarts.has(o):
			quarts[o] = quarts_de_tour(o)
		sortie.append([r["classe"], quarts[o]])
	return sortie


## Les classes, dans l'ordre de `MB.classes()` : {id, outdoor_possible, in_world}.
## `in_world` est faux pour les contacts diagonaux, hors du monde (charte §2) : un greffon pose un cube
## rouge là, comme partout où une tuile manque.
static func classes_du_format() -> Array:
	var sortie: Array = []
	for c in MB.classes():
		var b: int = c["bits"]
		sortie.append({"id": id_de_classe(c["nom"]),
			"outdoor_possible": MB.porte_une_surface(b) and MB.exterieur_possible(b),
			"in_world": MB.porte_une_surface(b) and MB.sans_contact_diagonal(b)})
	return sortie


## LA RÈGLE EN CLAIR — ligne à ligne, ce qu'un greffon doit faire. Elle part dans le manifeste
## (`rules_text`), le README, et les cas d'épreuve.
static func regle() -> PackedStringArray:
	return PackedStringArray([
		"MarchingBlocks tileset, format %d. The tiles are placed by the rule below; nothing else." % VERSION,
		"Frame: right-handed, +Y up (glTF). 1 unit = 1 cell. Cell c covers [c, c+1] on each axis.",
		"A layer is a set of full cells. Layers are independent: a layer only ever reads its own cells.",
		"1. Vertices. A full cell c touches the 8 vertices c - corners[t], t = 0..7.",
		"2. Bits. At vertex v, bit t is 1 when cell v + corners[t] is full (t = x + 2y + 4z).",
		"3. Class. table[bits] = [class, quarter_turns]. class = -1: nothing is placed at v.",
		"4. Context. Only if classes[class].outdoor_possible. Let top = the highest y of any full cell of",
		"   the layer. v is OUTDOOR when, for EVERY EMPTY cell e among its 8, no cell (e.x, y, e.z) is full",
		"   for y from v.y + 2 to top inclusive. Outdoor: use key '<class id>_outdoor' if the tileset has it,",
		"   otherwise fall back on the bare key '<class id>'. Indoor: the bare key.",
		"5. Tile. Each key has exactly one tile, tiles[key]. If the key is absent, place a clearly visible",
		"   error marker instead. Never fill in.",
		"6. Pose. The tile mesh is centred on the origin. Place it at (v + piece_offset) * cell_size,",
		"   rotated by quarter_turns * 90 degrees about +Y, right-hand rule (+Z turns towards +X).",
		"Rebuilding after cell (x, y, z) changes: only the vertices of columns x-1..x, z-1..z at heights",
		"   up to y can change (their bits, or their context).",
		"Engines with another frame must convert the cell grid with the SAME mapping their glTF importer",
		"   applies to meshes. A mirroring conversion reverses the direction of the quarter turns.",
		"Frame: tiles.glb carries a marker node, frame_marker.node, whose mesh has exactly the vertices",
		"   frame_marker.points = (0,0,0), (1,0,0), (0,2,0), (0,0,3). Read where your importer put them",
		"   (node pose included): the lengths 1, 2, 3 tell each axis apart, the shortest gives the scale.",
		"   That linear map F is the conversion. Place a piece at F(v + piece_offset) * cell_size,",
		"   rotated by F * R * F^-1 where R is the quarter-turn rotation. The marker is not a tile.",
	])


## Les champs COMMUNS au manifeste et aux cas d'épreuve : tout ce qui fait la règle, sans les tuiles.
static func regle_du_format() -> Dictionary:
	var coins: Array = []
	for c in MB.COINS:
		coins.append([c.x, c.y, c.z])
	return {
		"corners": coins,
		"piece_offset": [1, 1, 1],
		"table": table(),
		"classes": classes_du_format(),
		"context": {"rule": "open-sky-above-empty-cells", "band": 2, "outdoor_suffix": SUFFIXE_DEHORS},
		"rules_text": Array(regle()),
		"frame_marker": {"node": MARQUEUR, "points": POINTS_DU_MARQUEUR},
	}


## {nom interne de clé: id d'item du lot}. ⚠ Une tuile par clé, de nom nu (charte §3).
static func tuiles_du_lot(lot: MeshLibrary) -> Dictionary:
	var tuiles := {}
	for id in lot.get_item_list():
		tuiles[lot.get_item_name(id)] = id
	return tuiles


## EXPORTE UN LOT dans `<dossier>/<nom>.mbset/`. Rend {"dossier": chemin, "tuiles": n, "manquantes": [...]}
## ou {"erreur": raison}.
## ⚠ **UN SHADER DE GODOT NE VOYAGE PAS.** Une tuile qui porte un `ShaderMaterial` (ou aucun matériau)
## part avec un matériau standard lisant ses couleurs de sommet — la légende du témoin.
## Le travail de l'artiste, lui, part avec SES matériaux.
static func exporter(lot: MeshLibrary, dossier: String, nom: String, generateur: String) -> Dictionary:
	if lot == null or lot.get_item_list().is_empty():
		return {"erreur": "this layer has no tiles — slice something into it first"}
	var propre := nom.to_lower().strip_edges()
	var n := ""
	for ch in propre:
		n += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-" else "_"
	if n == "":
		n = "tileset"
	var cible := dossier.path_join(n + ".mbset")
	DirAccess.make_dir_recursive_absolute(cible)

	var du_lot := tuiles_du_lot(lot)
	var tuiles := {}
	var racine := Node3D.new()
	racine.name = "Tiles"
	var vus := {}
	for cle in du_lot:
		var tuile := nom_de_tuile(cle)
		if vus.has(tuile):
			racine.free()
			return {"erreur": "two tiles would share the name « %s »" % tuile}
		vus[tuile] = true
		var inst := MeshInstance3D.new()
		inst.name = tuile
		inst.mesh = _maillage_exportable(lot.get_item_mesh(du_lot[cle]), lot.get_item_mesh_transform(du_lot[cle]))
		racine.add_child(inst)
		tuiles[id_de_cle(cle)] = tuile

	var marqueur := MeshInstance3D.new()
	marqueur.name = MARQUEUR
	marqueur.mesh = maillage_du_marqueur()
	racine.add_child(marqueur)

	var doc := GLTFDocument.new()
	var etat := GLTFState.new()
	var err: int = doc.append_from_scene(racine, etat)
	# ⚠ **LE MAILLAGE PORTE AUSSI LE NOM DE SA TUILE, pas seulement le nœud.** Godot et Unity lisent les
	# nœuds ; l'importeur glTF d'Unreal fait un `StaticMesh` PAR MAILLAGE et le nomme d'après lui : des
	# maillages anonymes y arrivaient indiscernables (mesuré sur le .glb le 28 septembre 2026 : aucun
	# `meshes[*].name`). ⚠ On le pose ICI, APRÈS `append_from_scene`, en recopiant le nom DÉFINITIF du
	# nœud : l'export tient un seul espace de noms pour nœuds et maillages, et nommer le maillage dans la
	# scène renommait le NŒUD en « …_22 » — 14 tuiles introuvables, vu rougir.
	if err == OK:
		var maillages: Array = etat.get_meshes()
		for noeud: GLTFNode in etat.get_nodes():
			if noeud.mesh >= 0 and noeud.mesh < maillages.size():
				var gm := maillages[noeud.mesh] as GLTFMesh
				gm.resource_name = noeud.resource_name
		etat.set_meshes(maillages)
	if err == OK:
		err = doc.write_to_filesystem(etat, cible.path_join("tiles.glb"))
	racine.free()
	if err != OK:
		return {"erreur": "tiles.glb could not be written (error %d)" % err}

	var manquantes: Array = []
	for c in MB.pieces_a_sculpter():
		if not du_lot.has(c):
			manquantes.append(id_de_cle(c))
	for c in MB.exterieures_a_sculpter():
		var cle: String = MB.nom_en_contexte(c, true)
		if not du_lot.has(cle):
			manquantes.append(id_de_cle(cle))

	var manifeste := regle_du_format()
	manifeste.merge({"format": FORMAT, "version": VERSION, "generator": generateur, "name": n,
		"tiles_file": "tiles.glb", "tiles": tuiles, "missing": manquantes}, true)
	var f := FileAccess.open(cible.path_join("tileset.json"), FileAccess.WRITE)
	if f == null:
		return {"erreur": "tileset.json could not be written (error %d)" % FileAccess.get_open_error()}
	f.store_string(JSON.stringify(manifeste, "  "))
	f.close()
	var r := FileAccess.open(cible.path_join("README.txt"), FileAccess.WRITE)
	if r != null:
		r.store_string("\n".join(regle()) + "\n\nOpen format — free plugins for Godot, Unity and Unreal "
			+ "read it. Made with %s.\n" % generateur)
		r.close()
	return {"dossier": cible, "tuiles": vus.size(), "cles": tuiles.size(), "manquantes": manquantes}


## Le tétraèdre du repère témoin : quatre sommets, quatre faces, et rien d'autre — un importeur qui
## soude ou réordonne garde les mêmes positions, et c'est tout ce que le greffon lit.
static func maillage_du_marqueur() -> ArrayMesh:
	var p := PackedVector3Array()
	for q in POINTS_DU_MARQUEUR:
		p.append(Vector3(q[0], q[1], q[2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = p
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 1, 3, 0, 3, 2, 1, 2, 3])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


static func _maillage_exportable(mesh: Mesh, pose: Transform3D) -> ArrayMesh:
	var sortie := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		if not pose.is_equal_approx(Transform3D.IDENTITY):
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in v.size():
				v[i] = pose * v[i]
			arrays[Mesh.ARRAY_VERTEX] = v
			if arrays[Mesh.ARRAY_NORMAL] != null:
				var nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for i in nrm.size():
					nrm[i] = (pose.basis * nrm[i]).normalized()
				arrays[Mesh.ARRAY_NORMAL] = nrm
			arrays[Mesh.ARRAY_TANGENT] = null
		sortie.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var m: Material = mesh.surface_get_material(s)
		if m is ShaderMaterial or m == null:
			var standard := StandardMaterial3D.new()
			standard.vertex_color_use_as_albedo = true
			standard.resource_name = "vertex_colour"
			m = standard
		sortie.surface_set_material(sortie.get_surface_count() - 1, m)
	return sortie


# ── LES CAS D'ÉPREUVE ──────────────────────────────────────────────────────────────────────────────
#
# ⚠ **CE QUE CHAQUE GREFFON DOIT REPRODUIRE À 100 %.** Des mondes construits pour exercer chaque ligne de
# la règle — contexte, repli, coordonnées négatives, diagonales —, et pour chacun la liste
# ATTENDUE [x, y, z, tuile ou null, quarts de tour], triée. L'attendu vient de `MB.poses()`, la règle
# que le peintre de l'appli applique réellement ; les greffons l'implémentent, eux, depuis le TEXTE du
# format. Deux implémentations, un attendu : c'est ce qui rend la divergence visible.

## Deux jeux de tuiles fictifs — les cas n'ont besoin que des NOMS, pas des maillages.
##   riche : toutes les clés du monde, variante d'air libre comprise ;
##   nu    : les classes du monde, nom nu seul — le repli doit poser partout le nom nu.
static func jeux_d_epreuve() -> Dictionary:
	var riche := {}
	var nu := {}
	for c in MB.pieces_a_sculpter():
		riche[c] = true
		nu[c] = true
	for c in MB.exterieures_a_sculpter():
		riche[MB.nom_en_contexte(c, true)] = true
	return {"rich": riche, "bare": nu}


static func mondes_d_epreuve() -> Array:
	var mondes: Array = []
	mondes.append({"name": "single cell", "cells": [Vector3i.ZERO]})
	var sol: Array = []
	for x in 4:
		for z in 4:
			sol.append(Vector3i(x, 0, z))
	mondes.append({"name": "flat floor 4x4", "cells": sol})
	var falaise: Array = sol.duplicate()
	for x in 4:
		for y in range(1, 4):
			falaise.append(Vector3i(x, y, 0))
	mondes.append({"name": "cliff 3 high", "cells": falaise})
	var surplomb: Array = sol.duplicate()
	for x in 4:
		surplomb.append(Vector3i(x, 1, 0))
		surplomb.append(Vector3i(x, 2, 0))
		surplomb.append(Vector3i(x, 2, 1))
		surplomb.append(Vector3i(x, 2, 2))
	mondes.append({"name": "overhang", "cells": surplomb})
	var tunnel: Array = []
	for x in 5:
		for y in 3:
			for z in 3:
				if not (y == 1 and z == 1):
					tunnel.append(Vector3i(x, y, z))
	mondes.append({"name": "tunnel", "cells": tunnel})
	var grotte: Array = []
	for x in 5:
		for y in 5:
			for z in 5:
				if not (x in [1, 2, 3] and y in [1, 2, 3] and z in [1, 2, 3]):
					grotte.append(Vector3i(x, y, z))
	mondes.append({"name": "closed cave", "cells": grotte})
	mondes.append({"name": "diagonal contact (out of the world)",
		"cells": [Vector3i(0, 0, 0), Vector3i(1, 0, 1)]})
	var negatif: Array = []
	for x in range(-7, -3):
		for z in range(-9, -5):
			negatif.append(Vector3i(x, -3, z))
			if (x + z) % 3 == 0:
				negatif.append(Vector3i(x, -2, z))
	mondes.append({"name": "negative coordinates", "cells": negatif})
	# Un relief irrégulier, FIGÉ : écrit case par case par une suite déterministe, pas par un aléa.
	var relief: Array = []
	for x in 6:
		for z in 6:
			var h: int = 1 + ((x * 7 + z * 13 + x * z) % 4)
			for y in h:
				relief.append(Vector3i(x, y, z))
	mondes.append({"name": "rough terrain 6x6", "cells": relief})
	return mondes


## Les cas d'épreuve complets : la règle, les jeux, et pour chaque (monde, jeu) la liste attendue.
static func cas_d_epreuve() -> Dictionary:
	var jeux := jeux_d_epreuve()
	var tiles_json := {}
	for nom_jeu in jeux:
		var t := {}
		for cle in jeux[nom_jeu]:
			t[id_de_cle(cle)] = nom_de_tuile(cle)
		tiles_json[nom_jeu] = t
	var cas: Array = []
	for monde in mondes_d_epreuve():
		var pleines := {}
		var cellules: Array = []
		for c in monde["cells"]:
			pleines[c] = true
			cellules.append([c.x, c.y, c.z])
		for nom_jeu in jeux:
			cas.append({"name": "%s — %s tileset" % [monde["name"], nom_jeu], "tileset": nom_jeu,
				"cells": cellules, "expected": attendu(pleines, jeux[nom_jeu])})
	var sortie := regle_du_format()
	sortie.merge({"format": FORMAT_EPREUVE, "version": VERSION, "tilesets": tiles_json, "cases": cas}, true)
	return sortie


## La liste attendue pour un monde et un jeu : [x, y, z, tuile ou null, quarts], triée par sommet.
static func attendu(pleines: Dictionary, cles: Dictionary) -> Array:
	var quarts := {}
	var sortie: Array = []
	for d in MB.poses(pleines, cles):
		var s: Vector3i = d["sommet"]
		var o: int = d["orientation"]
		if not quarts.has(o):
			quarts[o] = quarts_de_tour(o)
		sortie.append([s.x, s.y, s.z, nom_de_tuile(d["cle"]) if d["cle"] != "" else null, quarts[o]])
	sortie.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] < b[0]
		if a[1] != b[1]:
			return a[1] < b[1]
		return a[2] < b[2])
	return sortie
