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
## ⚠ Une VARIANTE VOULUE (4 octobre 2026) garde le nom de sa clé, suivi de « _var<k> » : « slab_b2h2_outdoor_var1 ».
static func nom_de_tuile(cle: String) -> String:
	var k: int = MB.rang_de_variante(cle)
	if k > 0:
		return id_de_cle(MB.cle_de_tuile(cle)) + MB.SUFFIXE_VARIANTE + str(k)
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
		"A layer is a set of full cells, with its own tiles. A world may stack several layers, in PRIORITY",
		"   order (the first is the highest); see 7. One layer alone is the same rule.",
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
		"7. Layers. Steps 1-4 read the UNION of the cells of every VISIBLE layer (a cell found in two layers",
		"   belongs to the first), and top is the highest y of that union. Vertex v is placed by ONE layer:",
		"   among the layers owning its 8 cells, the first in priority order, with ITS tiles (step 5). A",
		"   hidden layer is not in the union and places nothing. Painting a cell in one layer removes it from",
		"   the others of the same world.",
		"8. Variants (optional). variants[key] lists other tiles of that key, in order: variant 1, 2, ... They",
		"   have the same borders as tiles[key] and are placed exactly like it (step 6). After step 4 chose key",
		"   K at vertex v (n = the number of variants of K; n = 0 places tiles[K]):",
		"   a. If the layer that places v gives a CHOICE at v (the world's variant_choices) and 0 <= choice <= n,",
		"      place tile number choice (0 is tiles[K], i the i-th variant).",
		"   b. Otherwise DRAW: weights w[0..n] are that layer's variant_weights[K] (a missing entry is 1, a",
		"      negative one 0). If they sum to 0, place tiles[K]. Else h = hash(v) mod sum, and the tile is the",
		"      first i whose running sum of weights exceeds h.",
		"   hash(v), on 64-bit integers, & = bitwise and, ^ = xor, >> = logical shift:",
		"      h = ((v.x * 73856093) ^ (v.y * 19349663) ^ (v.z * 83492791)) & 0x7FFFFFFF",
		"      h = ((h ^ (h >> 16)) * 0x45D9F3B) & 0x7FFFFFFF;  h = ((h ^ (h >> 16)) * 0x45D9F3B) & 0x7FFFFFFF",
		"      hash = h ^ (h >> 16)",
		"   Never draw at random at run time: the same world must give the same tiles at every rebuild.",
		"Rebuilding after cell (x, y, z) changes: only the vertices of columns x-1..x, z-1..z at heights",
		"   up to y can change (their bits, their context, or the layer that places them) — in every layer.",
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
	var variantes := {}
	var racine := Node3D.new()
	racine.name = "Tiles"
	var vus := {}
	# Les images des textures animées qui partent avec le jeu : {chemin source: chemin relatif au .mbset}.
	var emportees := {}
	for cle in du_lot:
		var tuile := nom_de_tuile(cle)
		if vus.has(tuile):
			racine.free()
			return {"erreur": "two tiles would share the name « %s »" % tuile}
		vus[tuile] = true
		var inst := MeshInstance3D.new()
		inst.name = tuile
		inst.mesh = _maillage_exportable(lot.get_item_mesh(du_lot[cle]), lot.get_item_mesh_transform(du_lot[cle]),
			emportees)
		racine.add_child(inst)
		# ⚠ UNE VARIANTE N'EST PAS UNE CLÉ (4 octobre 2026) : `tiles` reste {clé: SA tuile de base} — un greffon qui ne
		# lit pas les variantes pose la base, et le monde reste juste. Elles vont dans `variants`, dans l'ordre.
		if MB.rang_de_variante(cle) == 0:
			tuiles[id_de_cle(cle)] = tuile
	for cle in du_lot:
		var base: String = MB.cle_de_tuile(cle)
		if MB.rang_de_variante(cle) == 0 or MB.rang_de_variante(cle) > MB.nombre_de_variantes(base, du_lot):
			continue
		var liste: Array = []
		for k in range(1, MB.nombre_de_variantes(base, du_lot) + 1):
			liste.append(nom_de_tuile(MB.nom_de_variante(base, k)))
		variantes[id_de_cle(base)] = liste

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
	# ⚠ LES IMAGES DES TEXTURES ANIMÉES PARTENT AVEC LE JEU (parité des greffons, 7 octobre 2026) : recopiées sous le
	# chemin relatif que les extras nomment. Une image introuvable chez l'auteur est DITE (et le greffon la montrera
	# magenta, charte §3) — jamais remplacée en silence.
	var images_manquantes: Array = []
	if not emportees.is_empty():
		DirAccess.make_dir_recursive_absolute(cible.path_join(
			load("res://addons/marchingblocks_core/animation_materiau.gd").DOSSIER_EMPORTE))
		for source in emportees:
			if not FileAccess.file_exists(source) or DirAccess.copy_absolute(source, cible.path_join(emportees[source])) != OK:
				images_manquantes.append(str(source).get_file())

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
	# Les variantes (4 octobre 2026) : leur règle est l'étape 8 de `rules_text` (portée dans les greffons le 5 octobre).
	if not variantes.is_empty():
		manifeste["variants"] = variantes
	var f := FileAccess.open(cible.path_join("tileset.json"), FileAccess.WRITE)
	if f == null:
		return {"erreur": "tileset.json could not be written (error %d)" % FileAccess.get_open_error()}
	f.store_string(JSON.stringify(manifeste, "  "))
	f.close()
	var r := FileAccess.open(cible.path_join("README.txt"), FileAccess.WRITE)
	if r != null:
		r.store_string("\n".join(regle()) + "\n\n"
			+ "\n".join(load("res://addons/marchingblocks_core/animation_materiau.gd").regle_animation())
			+ "\n\nOpen format — free plugins for Godot, Unity and Unreal read it. Made with %s.\n" % generateur)
		r.close()
	return {"dossier": cible, "tuiles": vus.size(), "cles": tuiles.size(), "manquantes": manquantes,
		"images": emportees.size(), "images_manquantes": images_manquantes}


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


static func _maillage_exportable(mesh: Mesh, pose: Transform3D, emportees: Dictionary = {}) -> ArrayMesh:
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
		# Un matériau ANIMÉ part par son statique : l'image 0, ses réglages dans les extras (« mb_animation », au format qui
		# part : `Anim.vers_format`), ses images nommées relativement au .mbset (`emportees`, recopiées par `exporter`).
		var m: Material = load("res://addons/marchingblocks_core/animation_materiau.gd").statique_pour_l_export(
			mesh.surface_get_material(s), emportees)
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
	var en_couches: Array = []
	for monde in mondes_en_couches():
		var couches: Array = []
		var ecrites: Array = []
		for l in monde["layers"]:
			couches.append({"cells": l["cells"], "cles": jeux[l["tileset"]], "visible": l["visible"]})
			var cellules: Array = []
			for c in l["cells"]:
				cellules.append([c.x, c.y, c.z])
			ecrites.append({"tileset": l["tileset"], "visible": l["visible"], "cells": cellules})
		en_couches.append({"name": monde["name"], "layers": ecrites, "expected": attendu_en_couches(couches)})
	# LES VARIANTES (étape 8, portées dans les greffons le 5 octobre 2026) : un jeu « varied » = « rich » + des variantes
	# sur trois clés fréquentes ; des mondes tirés, pesés, choisis ; et un monde de deux couches aux poids différents.
	var varie := variantes_d_epreuve(jeux["rich"])
	tiles_json["varied"] = (tiles_json["rich"] as Dictionary).duplicate()
	var cas_varies: Array = []
	for v in cas_a_variantes(varie):
		var pleines := {}
		var cellules: Array = []
		for c in v["cells"]:
			pleines[c] = true
			cellules.append([c.x, c.y, c.z])
		cas_varies.append({"name": v["name"], "tileset": "varied", "cells": cellules,
			"variant_weights": _poids_ecrits(v["poids"]), "variant_choices": _choix_ecrits(v["choix"]),
			"expected": attendu(pleines, varie["cles"], v["poids"], v["choix"])})
	var deux := couches_a_variantes(varie)
	var ecrites_v: Array = []
	var couches_v: Array = []
	for l in deux["layers"]:
		var cellules: Array = []
		for c in l["cells"]:
			cellules.append([c.x, c.y, c.z])
		ecrites_v.append({"tileset": "varied", "visible": true, "cells": cellules,
			"variant_weights": _poids_ecrits(l["poids"]), "variant_choices": _choix_ecrits(l["choix"])})
		couches_v.append({"cells": l["cells"], "cles": varie["cles"], "visible": true, "poids": l["poids"],
			"choix": l["choix"]})
	en_couches.append({"name": deux["name"], "layers": ecrites_v, "expected": attendu_en_couches(couches_v)})
	var sortie := regle_du_format()
	sortie.merge({"format": FORMAT_EPREUVE, "version": VERSION, "tilesets": tiles_json,
		"tileset_variants": {"varied": varie["variants"]}, "cases": cas, "layered_cases": en_couches,
		"variant_cases": cas_varies}, true)
	return sortie


## Le jeu « varied » des cas d'épreuve : les clés de `riche`, plus des variantes sur les trois clés les plus posées des
## mondes d'épreuve (dans l'ordre : 2, 1 et 3 variantes). Rend {"cles": {nom interne: true}, "variants": {id de clé:
## [noms de tuile]}, "ordre": [les trois clés internes]}.
static func variantes_d_epreuve(riche: Dictionary) -> Dictionary:
	var compte := {}
	for monde in mondes_d_epreuve():
		var pleines := {}
		for c in monde["cells"]:
			pleines[c] = true
		for d in MB.poses(pleines, riche):
			if d["cle"] != "":
				compte[d["cle"]] = int(compte.get(d["cle"], 0)) + 1
	var cles_triees: Array = compte.keys()
	cles_triees.sort_custom(func(a, b): return compte[a] > compte[b] or (compte[a] == compte[b] and a < b))
	var cles := riche.duplicate()
	var variants := {}
	var ordre: Array = cles_triees.slice(0, 3)
	for i in ordre.size():
		var n: int = [2, 1, 3][i]
		var liste: Array = []
		for k in range(1, n + 1):
			cles[MB.nom_de_variante(ordre[i], k)] = true
			liste.append(nom_de_tuile(MB.nom_de_variante(ordre[i], k)))
		variants[id_de_cle(ordre[i])] = liste
	return {"cles": cles, "variants": variants, "ordre": ordre}


## Les mondes à variantes : {name, cells, poids {clé interne: [w]}, choix {sommet: c}}.
static func cas_a_variantes(varie: Dictionary) -> Array:
	var par_nom := {}
	for m in mondes_d_epreuve():
		par_nom[m["name"]] = m["cells"]
	var ordre: Array = varie["ordre"]
	var sortie: Array = []
	for nom in ["flat floor 4x4", "cliff 3 high", "rough terrain 6x6", "negative coordinates"]:
		sortie.append({"name": "%s — varied tileset, default weights" % nom, "cells": par_nom[nom], "poids": {},
			"choix": {}})
	# Des poids : 2:1:1 ; une base NÉGATIVE à côté d'une variante (elle compte 0 : la variante partout — une valeur absolue
	# y mêlerait la base) ; des poids tous ≤ 0 (la base).
	var relief: Array = par_nom["rough terrain 6x6"]
	sortie.append({"name": "rough terrain 6x6 — weights 2:1:1, a negative base, all weights <= 0", "cells": relief,
		"poids": {ordre[0]: [2, 1, 1], ordre[1]: [-2, 1], ordre[2]: [0, 0, -1, 0]}, "choix": {}})
	# Des choix : 0, 1, 2 sur des sommets de la première clé, un choix hors de portée (le tirage), un choix sur une clé
	# sans variante (la base), un choix sur un sommet qui ne pose rien (ignoré) — et des poids en plus.
	var pleines := {}
	for c in relief:
		pleines[c] = true
	var de_la_cle: Array = []
	var de_la_seconde: Array = []
	var sans_variante: Array = []
	for d in MB.poses(pleines, varie["cles"]):
		if d["cle"] == ordre[0]:
			de_la_cle.append(d["sommet"])
		elif d["cle"] == ordre[1]:
			de_la_seconde.append(d["sommet"])
		elif d["cle"] != "" and not ordre.has(d["cle"]):
			sans_variante.append(d["sommet"])
	var trier := func(a: Vector3i, b: Vector3i) -> bool:
		return a.x < b.x or (a.x == b.x and (a.y < b.y or (a.y == b.y and a.z < b.z)))
	de_la_cle.sort_custom(trier)
	de_la_seconde.sort_custom(trier)
	sans_variante.sort_custom(trier)
	var choix := {}
	for i in mini(3, de_la_cle.size()):
		choix[de_la_cle[i]] = [1, 2, 0][i]
	if not de_la_seconde.is_empty():
		choix[de_la_seconde[0]] = 9
	if not sans_variante.is_empty():
		choix[sans_variante[0]] = 1
	choix[Vector3i(100, 100, 100)] = 1
	sortie.append({"name": "rough terrain 6x6 — choices (in range, out of range, on a key without variants, on "
		+ "an empty vertex) and weights", "cells": relief, "poids": {ordre[0]: [0, 0, 5]}, "choix": choix})
	return sortie


## Deux couches à variantes, chacune ses poids et ses choix : la couche qui POSE un sommet décide (étape 8).
static func couches_a_variantes(varie: Dictionary) -> Dictionary:
	var ordre: Array = varie["ordre"]
	var bas: Array = []
	var haut: Array = []
	for x in 6:
		for z in 6:
			bas.append(Vector3i(x, 0, z))
			if x >= 2 and z >= 2:
				haut.append(Vector3i(x, 1, z))
	return {"name": "two layers with their own variant weights and choices",
		"layers": [{"cells": haut, "poids": {ordre[0]: [0, 1, 0], ordre[2]: [1, 0, 0, 7]}, "choix": {Vector3i(3, 0, 3): 0}},
			{"cells": bas, "poids": {ordre[0]: [0, 0, 1]}, "choix": {Vector3i(0, -1, 0): 1}}]}


static func _poids_ecrits(poids: Dictionary) -> Dictionary:
	var p := {}
	for cle in poids:
		p[id_de_cle(cle)] = poids[cle]
	return p


## Les choix à plat, x y z c, triés par sommet (la forme de `world.json`).
static func _choix_ecrits(choix: Dictionary) -> Array:
	var sommets: Array = choix.keys()
	sommets.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return a.x < b.x or (a.x == b.x and (a.y < b.y or (a.y == b.y and a.z < b.z))))
	var plat: Array = []
	for s in sommets:
		plat.append_array([s.x, s.y, s.z, int(choix[s])])
	return plat


## LES CAS MULTICOUCHES (couches exclusives, Jordan, 2 octobre 2026) : des mondes de plusieurs couches, chacune avec
## son jeu, dans l'ordre de PRIORITÉ ; l'attendu, par couche, vient de `MB.poses_en_couches` (la référence).
static func mondes_en_couches() -> Array:
	var bloc := func(x0: int, x1: int, y0: int, y1: int, z0: int, z1: int) -> Array:
		var a: Array = []
		for x in range(x0, x1 + 1):
			for y in range(y0, y1 + 1):
				for z in range(z0, z1 + 1):
					a.append(Vector3i(x, y, z))
		return a
	var roche: Array = bloc.call(0, 3, 0, 1, 0, 3)
	var glace: Array = bloc.call(4, 6, 0, 2, 0, 3)
	var dalle: Array = bloc.call(0, 3, 2, 2, 0, 1)
	var a_cheval: Array = bloc.call(2, 5, 0, 1, 0, 3)   # chevauche la roche sur x = 2..3
	return [
		{"name": "two layers side by side, different tilesets",
			"layers": [{"tileset": "rich", "visible": true, "cells": roche}, {"tileset": "bare", "visible": true, "cells": glace}]},
		{"name": "the same two, priority reversed",
			"layers": [{"tileset": "bare", "visible": true, "cells": glace}, {"tileset": "rich", "visible": true, "cells": roche}]},
		{"name": "a slab of another layer on top (the floor below is no longer under the sky)",
			"layers": [{"tileset": "rich", "visible": true, "cells": roche}, {"tileset": "rich", "visible": true, "cells": dalle}]},
		{"name": "a hidden layer is not in the union",
			"layers": [{"tileset": "rich", "visible": true, "cells": roche}, {"tileset": "rich", "visible": false, "cells": glace}]},
		{"name": "a cell in two layers belongs to the first",
			"layers": [{"tileset": "bare", "visible": true, "cells": a_cheval}, {"tileset": "rich", "visible": true, "cells": roche}]},
	]


## Par couche, la liste attendue : [x, y, z, tuile ou null, quarts], triée par sommet. `couches` : [{cells, cles,
## visible}] dans l'ordre de priorité.
static func attendu_en_couches(couches: Array) -> Array:
	var union := {}
	var cles_par_couche: Array = []
	for i in couches.size():
		cles_par_couche.append(couches[i]["cles"])
		if couches[i]["visible"]:
			for c in couches[i]["cells"]:
				if not union.has(c):
					union[c] = i
	var sorties: Array = []
	for i in couches.size():
		sorties.append([])
	var quarts := {}
	for d in MB.poses_en_couches(union, cles_par_couche):
		var s: Vector3i = d["sommet"]
		var o: int = d["orientation"]
		if not quarts.has(o):
			quarts[o] = quarts_de_tour(o)
		var couche: Dictionary = couches[int(d["couche"])]
		var tuile = null
		if d["cle"] != "":
			tuile = nom_de_tuile(MB.tuile_du_sommet(s, d["cle"], couche["cles"], couche.get("poids", {}),
				couche.get("choix", {})))
		sorties[int(d["couche"])].append([s.x, s.y, s.z, tuile, quarts[o]])
	for l in sorties:
		(l as Array).sort_custom(func(a: Array, b: Array) -> bool:
			if a[0] != b[0]:
				return a[0] < b[0]
			if a[1] != b[1]:
				return a[1] < b[1]
			return a[2] < b[2])
	return sorties


## La liste attendue pour un monde et un jeu : [x, y, z, tuile ou null, quarts], triée par sommet. `poids`, `choix` : les
## variantes de la couche (étape 8), par `MB.tuile_du_sommet` — la règle que le peintre de l'appli applique.
static func attendu(pleines: Dictionary, cles: Dictionary, poids: Dictionary = {}, choix: Dictionary = {}) -> Array:
	var quarts := {}
	var sortie: Array = []
	for d in MB.poses(pleines, cles):
		var s: Vector3i = d["sommet"]
		var o: int = d["orientation"]
		if not quarts.has(o):
			quarts[o] = quarts_de_tour(o)
		var tuile = null
		if d["cle"] != "":
			tuile = nom_de_tuile(MB.tuile_du_sommet(s, d["cle"], cles, poids, choix))
		sortie.append([s.x, s.y, s.z, tuile, quarts[o]])
	sortie.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] < b[0]
		if a[1] != b[1]:
			return a[1] < b[1]
		return a[2] < b[2])
	return sortie
