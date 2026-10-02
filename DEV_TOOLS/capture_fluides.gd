extends SceneTree
##
## LA CAPTURE DES FLUIDES — l'appli ouverte, un paysage d'essai tranché sur le témoin, et son eau.
##
## LANCEMENT — ⚠ AVEC FENÊTRE (le headless ne rend rien, et le shader ne se juge qu'à l'image) :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/capture_fluides.gd -- --dossier=C:/chemin/des/captures
##
## Le paysage : une île (x, z = 0..23, y = 0..3), un plateau (2..12, 4..7, 2..12) creusé d'une cuvette
## (4..8, 6..7, 4..8), un escalier vers l'est (x = 13..15, une marche par case) et une fosse dans le dessus de
## l'île (18..20, 3, 5..7). Trois sources : la cuvette (un LAC), le bord du plateau (une RIVIÈRE qui descend
## l'escalier, remplit la fosse, déborde et tombe dans la mer), et le large (une MER au niveau 1).

const Projet := preload("res://app/projet.gd")
const REGLAGES := "user://reglages.cfg"
const JETABLE := "user://capture/fluides.mbproj"

var _dossier := "D:/MarchingBlocks/ART/fluides"
var _ecran: Control
var _reglages_avant := ""


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--dossier="):
			_dossier = option.substr("--dossier=".length())
	DirAccess.make_dir_recursive_absolute(_dossier)
	if FileAccess.file_exists(REGLAGES):
		_reglages_avant = FileAccess.get_file_as_string(REGLAGES)
	DirAccess.make_dir_recursive_absolute("user://capture")
	var f := FileAccess.open(JETABLE, FileAccess.WRITE)
	f.store_string(Projet.vers_texte([Projet.couche("Rock")], 0))
	f.close()
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", JETABLE)
	r.save(REGLAGES)
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	_derouler()


static func _boite(d: Dictionary, a: Vector3i, b: Vector3i, plein := true) -> void:
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			for z in range(a.z, b.z + 1):
				if plein:
					d[Vector3i(x, y, z)] = true
				else:
					d.erase(Vector3i(x, y, z))


func _paysage() -> Dictionary:
	var d := {}
	_boite(d, Vector3i(0, 0, 0), Vector3i(23, 3, 23))
	_boite(d, Vector3i(2, 4, 2), Vector3i(12, 7, 12))
	_boite(d, Vector3i(4, 6, 4), Vector3i(8, 7, 8), false)
	_boite(d, Vector3i(13, 4, 3), Vector3i(13, 6, 9))
	_boite(d, Vector3i(14, 4, 3), Vector3i(14, 5, 9))
	_boite(d, Vector3i(15, 4, 3), Vector3i(15, 4, 9))
	_boite(d, Vector3i(18, 3, 5), Vector3i(20, 3, 7), false)
	return d


func _cadrer(cible: Vector3, azimut: float, elevation: float, distance: float) -> void:
	var vue = _ecran._vue
	vue._cible = cible
	vue._azimut = azimut
	vue._elevation = elevation
	vue._distance = distance
	vue._caler()


func _derouler() -> void:
	await _images(20)
	_ecran._aller_a("monde")
	_ecran._appliquer({"poser": _paysage(), "effacer": {}}, "Landscape")
	await _ecran._trancher_temoin()
	_ecran._aller_a("monde")
	await _images(5)
	_ecran._aller_a("fluides")
	for s in [Vector3i(6, 6, 6), Vector3i(12, 8, 6), Vector3i(40, 1, 40)]:
		_ecran._eau_cliquee(s, MOUSE_BUTTON_LEFT)
		await _images(2)
		print(_ecran._rapport.text)
	await _images(30)

	_cadrer(Vector3(12, 3, 11), 0.75, 0.62, 44.0)
	await _images(20)
	_photo("1_ensemble")
	_cadrer(Vector3(6.5, 6.5, 6.5), 0.5, 0.9, 13.0)
	await _images(20)
	_photo("2_lac")
	_cadrer(Vector3(15, 5, 6), 1.3, 0.35, 13.0)
	await _images(20)
	_photo("3_escalier_et_cascades")
	_cadrer(Vector3(22, 2, 6), 1.6, 0.3, 14.0)
	await _images(20)
	_photo("4_fosse_et_mer")
	# L'aperçu : la souris au-dessus d'un coin du plateau, avant le clic.
	_cadrer(Vector3(9, 6, 10), 0.4, 0.8, 20.0)
	await _images(5)
	_ecran._vue._survoler(_ecran._vue._camera.unproject_position(Vector3(10.5, 8.0, 11.5)))
	await _images(10)
	_photo("5_apercu")
	# L'EXPORT DU MONDE PAR LE BOUTON (étape 4) — il passe par le panneau d'attente, qui pend sans fenêtre : il
	# n'est mené qu'ici. On relit ce qu'il a écrit.
	await _ecran._exporter_le_monde(_dossier)
	var w = JSON.parse_string(FileAccess.get_file_as_string(_dossier.path_join("fluides.mbworld/world.json")))
	var eau: Array = w.get("water", []) if w is Dictionary else []
	print("EXPORT : %d couche(s) d'eau ; nappe %s (%s) ; %d source(s) ; aspect %s" % [eau.size(),
		eau[0]["mesh"] if eau.size() > 0 else "—",
		"présente" if eau.size() > 0 and FileAccess.file_exists(_dossier.path_join("fluides.mbworld").path_join(str(eau[0]["mesh"]))) else "ABSENTE",
		(eau[0]["sources"] as Array).size() / 3 if eau.size() > 0 else 0, eau[0]["look"] if eau.size() > 0 else "—"])
	print(_ecran._rapport.text)
	# LES AUTRES PRESETS, mêmes vues (étape 3).
	_ecran._vue._apercu.visible = false
	for preset in ["transparent", "reflechissant"]:
		_ecran._eaux[0]["preset"] = preset
		_ecran._recalculer_eau()
		for v in [["1_ensemble", Vector3(12, 3, 11), 0.75, 0.62, 44.0], ["2_lac", Vector3(6.5, 6.5, 6.5), 0.5, 0.9, 13.0],
				["3_escalier_et_cascades", Vector3(15, 5, 6), 1.3, 0.35, 13.0],
				["4_fosse_et_mer", Vector3(22, 2, 6), 1.6, 0.3, 14.0], ["6_mer_rasante", Vector3(30, 1.5, 12), 1.9, 0.08, 18.0]]:
			_cadrer(v[1], v[2], v[3], v[4])
			await _images(20)
			_photo("%s_%s" % [preset, v[0]])
	_rendre()
	quit(0)


func _images(n: int) -> void:
	for i in n:
		await process_frame


func _photo(nom: String) -> void:
	var img: Image = root.get_texture().get_image()
	var chemin := _dossier.path_join(nom + ".png")
	img.save_png(chemin)
	print("→ ", chemin)


func _rendre() -> void:
	if _reglages_avant != "":
		var f := FileAccess.open(REGLAGES, FileAccess.WRITE)
		f.store_string(_reglages_avant)
		f.close()
