extends SceneTree
##
## PRÉPARE L'EAU RECALCULÉE DU GREFFON UNITY (7 octobre 2026, PARITE.md §12, 3 et 5) — écrit par la référence :
##
##   engines/unity/test-project/Assets/water_world.mbworld/   un monde EXPORTÉ (`FormatMonde.exporter`) dont les nappes sont
##       CUITES par l'appli : une mer et son large, une dalle posée au-dessus de la mer, un massif percé d'un tunnel dont la
##       rivière sort SOUS la cascade d'une autre (deux cascades d'un même lieu qui FUSIONNENT, deux rivières sur les MÊMES
##       cases : une case, une bande — ce que les 14 cas n'exercent pas), un lac profond dans un bloc, trois rivières côte à
##       côte qui descendent un escalier. Trois couches d'eau. Le contrôle de bout en bout du greffon recalcule ces nappes
##       depuis les sources et les compare à ces .glb, tels que glTFast les a lus (couleurs à 1/255).
##   engines/unity/test-project/Assets/water_world_expected.json   les cases, les sources par couche, et les TRIANGLES
##       canoniques de chaque nappe (`EM.tableaux_du_maillage`, avant le stockage) : le banc .NET les compare sans Unity.
##   <MB_EXEMPLE_DUMP, sinon user://exemple_eau.json>   les cases et les sources de l'EXEMPLE livré (739 481 cases, la mer
##       de 354 159 cases) : le banc .NET y mesure les temps du C# (`--water-timing`).
##
## LANCEMENT
##   godot --headless --path <dépôt> --script res://DEV_TOOLS/preparer_eau_unity.gd
##   (MB_EXEMPLE=<chemin de exemple.zip> si l'archive n'est pas dans ce dépôt — elle est hors git.)
##
## ⚠ Hors git, comme le reste de l'essai Unity (`engines/unity/test-project/.gitignore`). Le dossier du monde est VIDÉ d'abord.

const FM := preload("res://addons/marchingblocks_core/format_monde.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const FL := preload("res://addons/marchingblocks_core/fluides.gd")
const EM := preload("res://addons/marchingblocks_core/eau_maillage.gd")
const EP := preload("res://addons/marchingblocks_core/epreuve_parite.gd")
const Exemple := preload("res://app/exemple.gd")
const Projet := preload("res://app/projet.gd")

var CIBLE: String = ProjectSettings.globalize_path("res://engines/unity/test-project/Assets")


func _initialize() -> void:
	_preparer.call_deferred()


func _preparer() -> void:
	var dossier := ProjectSettings.globalize_path("user://essai_unity_eau")
	DirAccess.make_dir_recursive_absolute(dossier)
	var toile := _image(dossier.path_join("rock.png"), Color(0.62, 0.6, 0.58), Color(0.3, 0.29, 0.28), 8)
	var lot := _lot(dossier, "rock", {"nom": "rock", "couleur": Color.WHITE, "rugosite": 0.8, "metal": 0.0, "texture": toile,
		"echelle": 1.0, "projection": "uv"})
	if lot == null:
		quit(1)
		return
	var roc := _monde()
	var occupees := {}
	for c in roc:
		occupees[c] = true
	# Les couches d'eau : [nom, aspect, sources].
	var couches_eau := [
		["Sea", "transparent", [Vector3i(-1, 2, 8), Vector3i(9, 9, 9), Vector3i(10, 4, 9)]],
		["Lake", "stylise", [Vector3i(20, 5, 17)]],
		["Rivers", "reflechissant", [Vector3i(27, 6, 1), Vector3i(27, 6, 2), Vector3i(27, 6, 3)]],
	]
	var toutes: Array = []
	for e in couches_eau:
		toutes.append_array(e[2])
	var w: Dictionary = FL.monde(occupees, toutes)
	var eaux: Array = []
	var attendu_couches: Array = []
	var k := 0
	for e in couches_eau:
		var n: int = (e[2] as Array).size()
		var corps: Array = (w["corps"] as Array).slice(k, k + n)
		k += n
		var genres: Array = corps.map(func(r): return "%s%s" % [r["genre"], ("/" + r["erreur"]) if r["erreur"] != "" else ""])
		var a := EM.tableaux_du_maillage(corps, occupees, w["boite"])
		var tris := EP.triangles_canoniques(a)
		var ix := EP.triangles_indexes(tris)
		print("couche %s : %s · %d triangles · %s" % [e[0], genres, tris.size(), EP.resume_des_triangles(tris)])
		eaux.append({"nom": e[0], "visible": true, "preset": e[1], "sources": e[2],
			"maillage": EM.maillage(corps, occupees, w["boite"])})
		attendu_couches.append({"name": e[0], "sources": (e[2] as Array).map(func(s: Vector3i): return [s.x, s.y, s.z]),
			"bodies": genres, "vertices": ix["vertices"], "triangles": ix["triangles"]})
	# Ce que les 14 cas n'exercent pas, dit ici (et gardé par le banc qui relit ces triangles).
	_dire_les_fusions(occupees, w, couches_eau)
	var couches: Array = [{"nom": "Rock", "visible": true, "source": "rock", "lot": lot, "cases": roc}]
	_vider(CIBLE.path_join("water_world.mbworld"))
	var r: Dictionary = FM.exporter(couches, CIBLE, "water world", "MarchingBlocks (test)", eaux)
	if r.has("erreur"):
		print("✗ " + str(r["erreur"]))
		quit(1)
		return
	print("%s — %s" % [r["dossier"], str(r)])
	var attendu := {"format": "marchingblocks-water-world-expected", "cells": roc.map(func(c: Vector3i): return [c.x, c.y, c.z]),
		"layers": attendu_couches}
	var f := FileAccess.open(CIBLE.path_join("water_world_expected.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(attendu))
	f.close()
	if not _exemple():
		quit(1)
		return
	quit(0)


## LE MONDE : un plateau plein jusqu'à y = 2 (x 4..36, z 0..23), une baie à l'ouest (x 0..3, le fond seul) où la mer monte
## à 2 ; une dalle sur un pilier au-dessus de la baie ; le massif H (x 8..11, z 8..11, jusqu'à y = 8) percé d'un tunnel
## aveugle en y = 4 qui débouche à l'ouest SOUS la lèvre de la rivière du sommet ; un bloc (x 14..26, z 12..23, jusqu'à
## y = 5) creusé d'un lac de deux cases de profondeur ; l'escalier des cas, posé sur le plateau en (27, 3, 1).
func _monde() -> Array:
	var m := {}
	for x in range(0, 37):
		for z in range(0, 24):
			m[Vector3i(x, 0, z)] = true
			if x >= 4:
				m[Vector3i(x, 1, z)] = true
				m[Vector3i(x, 2, z)] = true
	for x in range(0, 3):
		for z in range(18, 21):
			m[Vector3i(x, 3, z)] = true
	m[Vector3i(1, 1, 19)] = true
	m[Vector3i(1, 2, 19)] = true
	for x in range(8, 12):
		for z in range(8, 12):
			for y in range(3, 9):
				m[Vector3i(x, y, z)] = true
	for x in range(8, 11):
		m.erase(Vector3i(x, 4, 9))
	for x in range(14, 27):
		for z in range(12, 24):
			for y in range(3, 6):
				m[Vector3i(x, y, z)] = true
	for x in range(19, 22):
		for z in range(17, 19):
			for y in range(4, 6):
				m.erase(Vector3i(x, y, z))
	# L'escalier des cas (`_mondes_eau`, « stairs »), décalé.
	var esc: Dictionary = EP._mondes_maillage()["stairs"]
	for c in esc:
		m[c + Vector3i(27, 3, 1)] = true
	var l: Array = m.keys()
	l.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return [a.x, a.y, a.z] < [b.x, b.y, b.z])
	return l


## Les fusions de cascades et les cases vues deux fois, comptées sur la règle (ce que les cas n'exercent pas).
func _dire_les_fusions(occupees: Dictionary, w: Dictionary, couches_eau: Array) -> void:
	var k := 0
	for e in couches_eau:
		var n: int = (e[2] as Array).size()
		var corps: Array = (w["corps"] as Array).slice(k, k + n)
		k += n
		var cases := {}
		var doubles := 0
		var levres := {}
		var fusions := 0
		for r in corps:
			if r["erreur"] != "" or r["genre"] != "riviere":
				continue
			var cours: Array = r["cours"]
			for i in cours.size():
				var c: Vector3i = cours[i]["case"]
				if cours[i]["genre"] != "lac" and occupees.has(c + Vector3i.DOWN):
					if cases.has(c):
						doubles += 1
					cases[c] = true
				if cours[i]["genre"] == "chute" and (i == 0 or cours[i - 1]["genre"] != "chute"):
					var levre: Vector3i = cours[i - 1]["case"] if i > 0 else c + Vector3i.UP
					var cle := Vector2i(levre.x, levre.z)
					if levres.has(cle) and levres[cle] != levre.y:
						fusions += 1
					levres[cle] = levre.y
		print("couche %s : %d case(s) de bande vue(s) deux fois, %d lèvre(s) à une autre hauteur au même endroit" % [e[0],
			doubles, fusions])


## L'EXEMPLE LIVRÉ, vidé en JSON pour le banc .NET : ses cases (à plat) et ses couches d'eau.
func _exemple() -> bool:
	var archive := OS.get_environment("MB_EXEMPLE")
	if archive == "":
		archive = Exemple.ARCHIVE
	var erreurs: Array = []
	var chemin := Exemple.installer(archive, "user://essai_unity_eau_exemple", erreurs)
	if chemin == "":
		print("✗ l'exemple ne s'installe pas (%s) : %s" % [archive, erreurs])
		return false
	var p := Projet.depuis_texte(FileAccess.get_file_as_string(chemin), erreurs)
	var cases := PackedInt32Array()
	var vus := {}
	for c in p["couches"]:
		for v: Vector3i in c["cases"]:
			if vus.has(v):
				continue
			vus[v] = true
			cases.append_array([v.x, v.y, v.z])
	var couches: Array = []
	for e in p["eaux"]:
		var s: Array = []
		for v: Vector3i in e["sources"]:
			s.append_array([v.x, v.y, v.z])
		couches.append({"name": e["nom"], "sources": s})
	var sortie := OS.get_environment("MB_EXEMPLE_DUMP")
	if sortie == "":
		sortie = ProjectSettings.globalize_path("user://exemple_eau.json")
	var f := FileAccess.open(sortie, FileAccess.WRITE)
	f.store_string(JSON.stringify({"format": "marchingblocks-water-timing", "cells": Array(cases), "layers": couches}))
	f.close()
	print("l'exemple : %d cases, %d couches d'eau → %s" % [vus.size(), couches.size(), sortie])
	return true


## Un témoin lié à un seul matériau, toutes faces, écrit en .glb puis relu en lot (comme l'appli).
func _lot(dossier: String, nom: String, materiau: Dictionary) -> MeshLibrary:
	var t: RefCounted = TL.depuis_le_temoin_calcule()
	t.materiaux.append(materiau)
	for c in t.tuiles:
		t.tuiles[c].assigner(range(t.tuiles[c].faces.size()), 0)
	var glb := dossier.path_join(nom + "_witness.glb")
	var err: String = t.vers_glb(glb)
	var bilan: Dictionary = BM.librairie_depuis_glb(glb) if err == "" else {}
	if bilan.is_empty() or not (bilan["erreurs"] as Array).is_empty():
		print("✗ le témoin %s ne se relit pas : %s" % [nom, str(err if bilan.is_empty() else bilan["erreurs"])])
		return null
	return bilan["lot"]


## Une image de 128² : des taches sombres (`taille` px) sur un fond, tirées d'un générateur fixe. Rend son chemin.
func _image(chemin: String, fond: Color, tache: Color, taille: int) -> String:
	var img := Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(fond)
	var rng := RandomNumberGenerator.new()
	rng.seed = taille * 7 + 1
	for i in 120:
		var cx := rng.randi_range(0, 127)
		var cy := rng.randi_range(0, 127)
		var r := rng.randi_range(1, taille)
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if x * x + y * y <= r * r:
					img.set_pixel((cx + x + 128) % 128, (cy + y + 128) % 128, tache)
	img.save_png(chemin)
	return chemin


func _vider(d: String) -> void:
	if not DirAccess.dir_exists_absolute(d):
		return
	for f in DirAccess.get_files_at(d):
		DirAccess.remove_absolute(d.path_join(f))
	for s in DirAccess.get_directories_at(d):
		_vider(d.path_join(s))
		DirAccess.remove_absolute(d.path_join(s))
