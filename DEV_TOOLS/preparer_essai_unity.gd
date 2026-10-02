extends SceneTree
##
## PRÉPARE LE PROJET D'ESSAI UNITY — le vrai témoin, exporté par l'appli, pour être lu par le vrai glTFast.
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/preparer_essai_unity.gd
##
## Écrit dans `engines/unity/test-project/Assets/` :
##   witness.mbset/          le jeu de tuiles du témoin, tel que « Export to engines » l'écrit ;
##   witness_cells.json      ses cases, en espace du FORMAT ;
##   witness_expected.json   ce que MarchingBlocks pose dessus — l'attendu, calculé par `MB.poses()` ;
##   faux.mbset/             le FAUX TRAVAIL D'ARTISTE (`faux_artiste.gd`) tranché : la texture et les UV
##                           de l'artiste doivent arriver sur chaque tuile, lues par glTFast ;
##   witness_world.mbworld/  un MONDE PEINT de trois couches, écrit par `FormatMonde.exporter` : Rock (la
##                           forme du témoin), Ice (CACHÉE, même source, donc même dossier de tuiles),
##                           Draft (sans tuiles) — le même monde que `test_greffon_peinture` ;
##   pbr.mbset/              le témoin lié, un matériau aux CARTES PBR DÉDUITES sur toutes ses tuiles : la normale,
##                           l'occlusion, le métal-rugosité et les tangentes doivent arriver (`cartes_pbr.gd`) ;
##   witness_world_expected.json  par couche : nom, visibilité, cases, et les poses que l'appli y fait
##                           (`FN.attendu`, null pour la couche sans tuiles).
## ⚠ L'attendu vient de la RÉFÉRENCE, pas du greffon Unity : `WitnessTests.cs` compare le greffon à lui.

const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const FN := preload("res://addons/marchingblocks_core/format_neutre.gd")
const FM := preload("res://addons/marchingblocks_core/format_monde.gd")
const World := preload("res://addons/marchingblocks_paint/mb_world.gd")
const Faux := preload("res://DEV_TOOLS/faux_artiste.gd")
## ⚠ DÉRIVÉ DU PROJET OUVERT, PAS ÉCRIT EN DUR : un chemin « D:/MarchingBlocks/… » écrivait dans le dépôt
## principal même lancé depuis un autre checkout (un worktree, la machine Linux) — et l'essai Unity aurait
## alors éprouvé l'ANCIEN paquet (vu le 30 septembre 2026).
var CIBLE: String = ProjectSettings.globalize_path("res://engines/unity/test-project/Assets")


## ⚠ DIFFÉRÉ : pendant `_initialize`, le `_ready()` du monde n'a pas encore tourné — sa grille `Cells`
## n'existe pas, le script plante, et un script planté n'appelle jamais `quit()` : il PEND (charte §6).
func _initialize() -> void:
	_preparer.call_deferred()


func _preparer() -> void:
	var lot: MeshLibrary = BM.librairie()["lot"]
	var r: Dictionary = FN.exporter(lot, CIBLE, "witness", "MarchingBlocks (test)")
	if r.has("erreur"):
		print("✗ " + r["erreur"])
		quit(1)
		return
	var pleines: Dictionary = BM.cases(0)
	var cellules: Array = []
	for c in pleines:
		cellules.append([c.x, c.y, c.z])
	# Une tuile par clé (charte §3) : l'attendu ne lit que la PRÉSENCE des clés.
	var comptes: Dictionary = FN.tuiles_du_lot(lot)
	_ecrire(CIBLE.path_join("witness_cells.json"), cellules)
	_ecrire(CIBLE.path_join("witness_expected.json"), FN.attendu(pleines, comptes))
	_ecrire(CIBLE.path_join("witness_geometry.json"), _coutures(pleines))
	print("%s — %d tuiles, %d cases" % [r["dossier"], r["tuiles"], cellules.size()])
	if not _monde(lot, pleines, comptes):
		quit(1)
		return
	var faux := ProjectSettings.globalize_path("user://faux_unity.glb")
	var m: Dictionary = Faux.fabriquer(faux)
	var bilan: Dictionary = BM.librairie_depuis_glb(faux) if m["erreur"] == "" else {}
	if bilan.is_empty() or not (bilan["erreurs"] as Array).is_empty():
		print("✗ le faux travail ne se tranche pas : %s" % str(m["erreur"] if bilan.is_empty() else bilan["erreurs"]))
		quit(1)
		return
	var rf: Dictionary = FN.exporter(bilan["lot"], CIBLE, "faux", "MarchingBlocks (test)")
	if rf.has("erreur"):
		print("✗ " + rf["erreur"])
		quit(1)
		return
	print("%s — %d tuiles texturées" % [rf["dossier"], rf["tuiles"]])
	if not _pbr():
		quit(1)
		return
	quit(0)


## LES CARTES PBR DÉDUITES (2 octobre 2026) : le témoin lié, un matériau peint qui dérive ses cartes sur toutes ses
## tuiles, écrit, relu lié, exporté — `pbr.mbset/`. Unity doit y lire la normale, l'occlusion, le métal-rugosité, et
## des tangentes sur chaque tuile.
func _pbr() -> bool:
	const Peinture := preload("res://addons/marchingblocks_core/peinture.gd")
	const Cartes := preload("res://addons/marchingblocks_core/cartes_pbr.gd")
	const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
	var dossier := ProjectSettings.globalize_path("user://essai_unity_pbr")
	DirAccess.make_dir_recursive_absolute(dossier)
	var toile := dossier.path_join("rock.png")
	Peinture.nouvelle_toile(toile, Color(0.5, 0.42, 0.33), 256)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 60:
		Peinture.tamponner(Peinture.calque_actif(toile), Vector2(rng.randf() * 256, rng.randf() * 256), rng.randf_range(4, 16),
			Color(0.8, 0.75, 0.7) if i % 2 == 0 else Color(0.2, 0.18, 0.15), 0.5, 1.0)
	Peinture.composer(toile)
	var t: RefCounted = TL.depuis_le_temoin_calcule()
	t.materiaux.append({"nom": "rock", "couleur": Color.WHITE, "rugosite": 0.8, "metal": 0.0, "texture": toile,
		"echelle": 1.0, "pbr": Cartes.DEFAUTS.duplicate()})
	for c in t.tuiles:
		t.tuiles[c].assigner(range(t.tuiles[c].faces.size()), 0)
	var glb := dossier.path_join("pbr_witness.glb")
	var err: String = t.vers_glb(glb)
	var bilan: Dictionary = BM.librairie_depuis_glb(glb) if err == "" else {}
	if bilan.is_empty() or not (bilan["erreurs"] as Array).is_empty():
		print("✗ le témoin PBR ne se relit pas : %s" % str(err if bilan.is_empty() else bilan["erreurs"]))
		return false
	_vider(CIBLE.path_join("pbr.mbset"))
	var r: Dictionary = FN.exporter(bilan["lot"], CIBLE, "pbr", "MarchingBlocks (test)")
	if r.has("erreur"):
		print("✗ " + r["erreur"])
		return false
	print("%s — %d tuiles aux cartes PBR" % [r["dossier"], r["tuiles"]])
	Peinture.oublier()
	return true


## LE MONDE PEINT : exporté par la référence, et son attendu calculé par la référence, couche par couche.
## ⚠ Le dossier est VIDÉ d'abord : un reste d'un passage précédent (un second .mbset) fausserait l'essai.
func _monde(lot: MeshLibrary, pleines: Dictionary, comptes: Dictionary) -> bool:
	var couches: Array = [
		{"nom": "Rock", "visible": true, "source": "temoin", "lot": lot, "cases": pleines.keys()},
		{"nom": "Ice", "visible": false, "source": "temoin", "lot": lot,
			"cases": [Vector3i(40, 0, 40), Vector3i(41, 0, 40), Vector3i(-3, -1, 2)]},
		{"nom": "Draft", "visible": true, "source": "", "lot": null, "cases": [Vector3i(0, 5, 0)]},
	]
	_vider(CIBLE.path_join("witness_world.mbworld"))
	var r: Dictionary = FM.exporter(couches, CIBLE, "witness world", "MarchingBlocks (test)")
	if r.has("erreur"):
		print("✗ monde : " + r["erreur"])
		return false
	# ⚠ LES COUCHES FONT UN MONDE (couches exclusives, 2 octobre 2026) : l'attendu vient de la référence
	# multicouche — une couche cachée ne pose rien, une couche sans tuiles compte dans l'union.
	var entrees: Array = []
	for c in couches:
		entrees.append({"cells": c["cases"], "cles": comptes if c["lot"] != null else {}, "visible": c["visible"]})
	var par_couche: Array = FN.attendu_en_couches(entrees)
	var attendu: Array = []
	for i in couches.size():
		var c: Dictionary = couches[i]
		var plat: Array = []
		for v in c["cases"]:
			plat.append([v.x, v.y, v.z])
		attendu.append({"name": c["nom"], "visible": c["visible"], "cells": plat,
			"expected": par_couche[i] if c["lot"] != null else null})
	_ecrire(CIBLE.path_join("witness_world_expected.json"), attendu)
	print("%s — %d couches, %d jeu(x) de tuiles, sans tuiles : %s" % [r["dossier"], r["couches"], r["jeux"],
		str(r["sans_tuiles"])])
	return true


func _vider(d: String) -> void:
	if not DirAccess.dir_exists_absolute(d):
		return
	for f in DirAccess.get_files_at(d):
		DirAccess.remove_absolute(d.path_join(f))
	for sd in DirAccess.get_directories_at(d):
		_vider(d.path_join(sd))
	DirAccess.remove_absolute(d)


func _ecrire(chemin: String, donnees) -> void:
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string(JSON.stringify(donnees))
	f.close()


## L'EMPREINTE DE LA GÉOMÉTRIE POSÉE par le greffon Godot : le centre de chaque triangle placé, en espace
## du FORMAT, × 1 200 (les coordonnées du témoin sont des multiples de 1/12 : des entiers EXACTS, donc
## aucun arrondi ne bascule d'un moteur à l'autre), triés, puis un MD5. Une tuile tournée ou reflétée à
## tort change l'empreinte.
## ⚠ **ELLE REMPLACE UN CONTRÔLE D'ÉTANCHÉITÉ QUI ÉTAIT AVEUGLE** : les tuiles du témoin aminci sont des
## boîtes CLOSES et DISJOINTES (sa matière est rentrée d'un quart de case, elle ne traverse jamais un plan
## de coupe) — 0 arête ouverte quelles que soient les rotations, mesuré en les annulant toutes. Un
## contrôle qui ne peut pas échouer ne garde rien (charte §6).
func _coutures(pleines: Dictionary) -> Dictionary:
	var w: Node3D = World.new()
	root.add_child(w)
	for c in pleines:
		(w.get_node("Cells") as GridMap).set_cell_item(c, 0)
	w.tileset = CIBLE.path_join("witness.mbset/tileset.json")
	var g := w.get_node("Tiles") as GridMap
	var centres := PackedStringArray()
	for v in g.get_used_cells():
		var xf: Transform3D = g.transform * Transform3D(g.get_basis_with_orthogonal_index(
			g.get_cell_item_orientation(v)), g.map_to_local(v))
		var m: Mesh = g.mesh_library.get_item_mesh(g.get_cell_item(v))
		for s in m.get_surface_count():
			var a: Array = m.surface_get_arrays(s)
			var p: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var o: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null 				else PackedInt32Array(range(p.size()))
			for t in range(0, o.size(), 3):
				var c: Vector3 = (xf * p[o[t]] + xf * p[o[t + 1]] + xf * p[o[t + 2]]) * 400.0
				centres.append("%d,%d,%d" % [roundi(c.x), roundi(c.y), roundi(c.z)])
	w.free()
	centres.sort()
	var empreinte := "\n".join(centres).md5_text()
	print("géométrie : %d triangles, empreinte %s" % [centres.size(), empreinte])
	return {"triangles": centres.size(), "centroids_md5": empreinte}
