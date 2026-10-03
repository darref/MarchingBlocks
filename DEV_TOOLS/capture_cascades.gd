extends SceneTree
##
## LA CAPTURE DES CASCADES — l'appli ouverte, une falaise de sept cases tranchée sur le témoin, deux rivières qui en
## tombent (une de trois de large, une d'une case), une plaine, et la mer plus bas.
##
## LANCEMENT — ⚠ AVEC FENÊTRE (le headless ne rend rien) :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/capture_cascades.gd -- --dossier=C:/chemin/des/captures [--presets=stylise,transparent]
##
## Le paysage : un plateau (x −6..10, y 0..9, z 0..23) dont la falaise est en x = 11 ; une plaine (x 11..20, y 0..2) ;
## la mer au niveau 1 tout autour. Une rivière de trois de large dans un chenal (x 4..10, z 8..10), qui tombe dans un
## bassin au pied ; une d'une case en (8, 10, 18) : toutes deux tombent de la falaise, puis de la plaine dans la mer.

const Projet := preload("res://app/projet.gd")
const REGLAGES := "user://reglages.cfg"
const JETABLE := "user://capture/cascades.mbproj"

var _dossier := "D:/MarchingBlocks/ART/cascades"
var _presets := ["stylise", "transparent", "reflechissant"]
var _ecran: Control
var _reglages_avant := ""


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--dossier="):
			_dossier = option.substr("--dossier=".length())
		elif option.begins_with("--presets="):
			_presets = Array(option.substr("--presets=".length()).split(","))
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
	_boite(d, Vector3i(-6, 0, 0), Vector3i(10, 9, 23))
	_boite(d, Vector3i(11, 0, 0), Vector3i(20, 2, 23))
	_boite(d, Vector3i(4, 9, 8), Vector3i(10, 9, 10), false)    # un chenal de trois, au bord de la falaise
	_boite(d, Vector3i(11, 2, 7), Vector3i(14, 2, 11), false)   # un bassin au pied de la grande cascade
	return d


func _cadrer(cible: Vector3, azimut: float, elevation: float, distance: float) -> void:
	var vue = _ecran._vue
	vue._cible = cible
	vue._azimut = azimut
	vue._elevation = elevation
	vue._distance = distance
	vue._caler()


const VUES := [
	["1_ensemble", Vector3(12, 5, 12), 1.1, 0.45, 40.0],
	["2_face", Vector3(11.5, 6, 9.5), 1.57, 0.12, 14.0],
	["3_trois_quarts", Vector3(11.5, 6, 9.5), 0.85, 0.25, 12.0],
	["4_profil", Vector3(11.5, 6, 9.5), 3.1, 0.1, 8.0],
	["5_pied", Vector3(12.5, 3.5, 9.5), 1.2, 0.35, 6.0],
	["6_haut", Vector3(10.5, 9.5, 9.5), 1.0, 0.6, 6.0],
	["7_etroite", Vector3(11.5, 6, 18.5), 1.3, 0.2, 9.0],
	["8_mer", Vector3(21, 1.5, 9.5), 1.4, 0.3, 10.0],
	["9_source", Vector3(8.5, 10, 18.5), 0.6, 0.55, 5.0],
]


func _derouler() -> void:
	await _images(20)
	_ecran._aller_a("monde")
	_ecran._appliquer({"poser": _paysage(), "effacer": {}}, "Landscape")
	await _ecran._trancher_temoin()
	_ecran._aller_a("monde")
	await _images(5)
	_ecran._aller_a("fluides")
	_ecran._eau_cliquee(Vector3i(40, 1, 40), MOUSE_BUTTON_LEFT)
	await _images(2)
	_ecran._largeur_eau.value = 3
	_ecran._eau_cliquee(Vector3i(6, 9, 9), MOUSE_BUTTON_LEFT)
	await _images(2)
	_ecran._largeur_eau.value = 1
	_ecran._eau_cliquee(Vector3i(8, 10, 18), MOUSE_BUTTON_LEFT)
	await _images(2)
	print(_ecran._rapport.text)
	_ecran._vue._apercu.visible = false
	for preset in _presets:
		_ecran._eaux[0]["preset"] = preset
		_ecran._recalculer_eau()
		for v in VUES:
			_cadrer(v[1], v[2], v[3], v[4])
			_ecran._vue._apercu.visible = false   # la souris de la fenêtre survole la vue : son aperçu n'est pas de l'eau
			await _images(25)
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
