extends SceneTree
##
## PRÉPARE LE MONDE DE LA PARITÉ POUR LE PROJET D'ESSAI UNITY — tout ce que le logiciel exporte depuis le 7 octobre 2026,
## dans UN monde, écrit par la référence (`FormatMonde.exporter`) pour être lu par le vrai glTFast et rendu par le greffon :
##
##   parity_world.mbworld/   trois couches — Rock et Sand (le témoin aux cartes PBR, une même source) qui se MÊLENT
##                           (une paire active, des représentants : une image pour Rock, une couleur pour Sand), Lava
##                           (un témoin au matériau ANIMÉ : quatre images, un défilement — ses images voyagent dans
##                           `<jeu>.mbset/animation/`) ; une couche d'EAU (un lac dans un creux de Rock, sa nappe cuite) ;
##                           du FEUILLAGE (un arbre fait ici, cinq plants).
##
## LANCEMENT
##   godot --headless --path <dépôt> --script res://DEV_TOOLS/preparer_parite_unity.gd
##
## ⚠ Hors git, comme le reste de l'essai Unity (`engines/unity/test-project/.gitignore`). Le dossier est VIDÉ d'abord.

const FM := preload("res://addons/marchingblocks_core/format_monde.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const TR := preload("res://addons/marchingblocks_core/transitions.gd")
const FE := preload("res://addons/marchingblocks_core/feuillage.gd")
const FL := preload("res://addons/marchingblocks_core/fluides.gd")
const EM := preload("res://addons/marchingblocks_core/eau_maillage.gd")

var CIBLE: String = ProjectSettings.globalize_path("res://engines/unity/test-project/Assets")


func _initialize() -> void:
	_preparer.call_deferred()


func _preparer() -> void:
	var dossier := ProjectSettings.globalize_path("user://essai_unity_parite")
	DirAccess.make_dir_recursive_absolute(dossier)
	# ── Deux témoins texturés : Rock (des pavés gris) et Sand (un grain jaune) — deux sources, deux jeux de tuiles, pour
	# que le fondu se JUGE à l'image (chaque couche montre son propre aspect, et l'autre par-dessus).
	var toile := _image(dossier.path_join("rock.png"), Color(0.62, 0.6, 0.58), Color(0.3, 0.29, 0.28), 8)
	var toile_sable := _image(dossier.path_join("sand.png"), Color(0.93, 0.82, 0.5), Color(0.75, 0.6, 0.3), 3)
	var lot := _lot(dossier, "rock", {"nom": "rock", "couleur": Color.WHITE, "rugosite": 0.8, "metal": 0.0, "texture": toile,
		"echelle": 1.0, "projection": "uv"})
	var lot_sable := _lot(dossier, "sand", {"nom": "sand", "couleur": Color.WHITE, "rugosite": 0.9, "metal": 0.0,
		"texture": toile_sable, "echelle": 1.0, "projection": "uv"})
	# ── Le témoin ANIMÉ (Lava) : quatre images à bandes, quatre images par seconde, et un défilement vertical.
	var images: Array = []
	for k in 4:
		var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var bande := ((y + k * 16) / 16) % 2 == 0
				img.set_pixel(x, y, Color(1.0, 0.35 + 0.15 * k, 0.05) if bande else Color(0.35, 0.05, 0.02))
		var chemin := dossier.path_join("lava_%d.png" % k)
		img.save_png(chemin)
		images.append(chemin)
	var anime := _lot(dossier, "lava", {"nom": "lava", "couleur": Color.WHITE, "rugosite": 0.6, "metal": 0.0,
		"texture": images[0], "echelle": 1.0, "projection": "uv", "animation": {
			"albedo": {"images": {"images": images, "ips": 4.0, "aller_retour": false, "synchro": false},
				"defilement": {"u": 0.0, "v": -0.25, "synchro": true}}}})
	if lot == null or lot_sable == null or anime == null:
		quit(1)
		return
	# ── Les cases : une dalle 16 × 16 de deux cases d'épaisseur, Rock à l'ouest (x < 8), Sand à l'est ; un creux 3 × 3 dans
	# Rock (le lac) ; un bloc de Lava posé sur Sand.
	var roc: Array = []
	var sable: Array = []
	var lave: Array = []
	for x in 16:
		for z in 16:
			for y in 2:
				var c := Vector3i(x, y, z)
				if y == 1 and x >= 2 and x <= 4 and z >= 9 and z <= 11:
					continue
				(roc if x < 8 else sable).append(c)
	for x in range(11, 14):
		for z in range(11, 14):
			for y in range(2, 4):
				lave.append(Vector3i(x, y, z))
	var couches: Array = [
		{"nom": "Rock", "visible": true, "source": "rock", "lot": lot, "cases": roc},
		{"nom": "Sand", "visible": true, "source": "sand", "lot": lot_sable, "cases": sable},
		{"nom": "Lava", "visible": true, "source": "lava", "lot": anime, "cases": lave},
	]
	# ── L'eau : un lac dans le creux, sa nappe cuite par la référence.
	var occupees := {}
	for c in roc + sable + lave:
		occupees[c] = true
	var sources: Array = [Vector3i(3, 3, 10)]
	var m: Dictionary = FL.monde(occupees, sources)
	var nappe: ArrayMesh = EM.maillage(m["corps"], occupees)
	var eaux: Array = [{"nom": "Lake", "visible": true, "preset": "transparent", "sources": sources, "maillage": nappe}]
	# ── Les transitions : Rock (id 1) et Sand (id 2) se mêlent, les réglages par défaut dans les deux sens.
	var rep_roc := Image.load_from_file(toile)
	var rep_sable := Image.load_from_file(toile_sable)
	var etat := {"paires": {"1|2": {"actif": true, "couvre": {"1": TR.reglages({}), "2": TR.reglages({"avance": 0.3})}}},
		"choix": {}}
	var reps := [{"image": rep_roc, "couleur": Color.WHITE, "echelle": 2.0, "rugosite": 0.8},
		{"image": rep_sable, "couleur": Color.WHITE, "echelle": 1.0, "rugosite": 0.9},
		{"image": null, "couleur": Color(0.9, 0.3, 0.1), "echelle": 1.0, "rugosite": 0.6}]
	# ── Le feuillage : un arbre (un tronc, une couronne), cinq plants sur la dalle — le sol du témoin aminci est un quart
	# de case sous le haut des cases.
	var arbre := dossier.path_join("tree.glb")
	_arbre(arbre)
	var modele := FE.modele(1, "Tree", arbre)
	modele["hauteur"] = 1.6
	modele["vent"] = 0.8
	var plants: Array = []
	var points := [Vector3(1.5, 1.75, 2.5), Vector3(5.5, 1.75, 4.5), Vector3(9.5, 1.75, 3.5), Vector3(13.5, 1.75, 6.5),
		Vector3(6.5, 1.75, 13.5)]
	for i in points.size():
		plants.append(FE.plant(i + 1, 1, points[i], 0.7 * i, 0.9 + 0.1 * i, "sol"))
	_vider(CIBLE.path_join("parity_world.mbworld"))
	var r: Dictionary = FM.exporter(couches, CIBLE, "parity world", "MarchingBlocks (test)", eaux,
		{"etat": etat, "ids": ["1", "2", "3"], "representants": reps}, FE.vers_donnees([modele], plants))
	if r.has("erreur"):
		print("✗ " + str(r["erreur"]))
		quit(1)
		return
	print("%s — %s" % [r["dossier"], str(r)])
	quit(0)


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


## UN ARBRE : un tronc (boîte) et une couronne (sphère), l'origine au pied.
func _arbre(chemin: String) -> void:
	var racine := Node3D.new()
	racine.name = "tree"
	var tronc := MeshInstance3D.new()
	tronc.name = "trunk"
	var b := BoxMesh.new()
	b.size = Vector3(0.18, 0.9, 0.18)
	var mt := StandardMaterial3D.new()
	mt.resource_name = "bark"
	mt.albedo_color = Color(0.4, 0.26, 0.15)
	b.material = mt
	tronc.mesh = b
	tronc.position = Vector3(0, 0.45, 0)
	racine.add_child(tronc)
	var couronne := MeshInstance3D.new()
	couronne.name = "crown"
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 0.9
	var mc := StandardMaterial3D.new()
	mc.resource_name = "leaves"
	mc.albedo_color = Color(0.25, 0.55, 0.2)
	s.material = mc
	couronne.mesh = s
	couronne.position = Vector3(0, 1.15, 0)
	racine.add_child(couronne)
	var doc := GLTFDocument.new()
	var etat := GLTFState.new()
	doc.append_from_scene(racine, etat)
	doc.write_to_filesystem(etat, chemin)
	racine.free()


func _vider(d: String) -> void:
	if not DirAccess.dir_exists_absolute(d):
		return
	for f in DirAccess.get_files_at(d):
		DirAccess.remove_absolute(d.path_join(f))
	for s in DirAccess.get_directories_at(d):
		_vider(d.path_join(s))
		DirAccess.remove_absolute(d.path_join(s))
