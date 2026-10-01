extends SceneTree
##
## LA CAPTURE DES FORMES SPÉCIALES — l'appli ouverte, un paysage d'essai, et ce que chaque forme y fait.
##
## LANCEMENT — ⚠ AVEC FENÊTRE (le headless ne rend rien) :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/capture_formes_speciales.gd -- --dossier=C:/chemin/des/captures
##
## Le paysage : un massif percé de deux salles décalées, une gorge à côté (deux parois face à face), et
## une paroi en ESCALIER à 45°. On y pose, par les fonctions des boutons et de VRAIS clics de caméra :
## un tunnel en coude (Connect) entre les deux salles, un tunnel droit dans la paroi diagonale, un pont
## sur la gorge, un balcon, un puits. Puis l'aperçu d'un tunnel survolé.

const Projet := preload("res://app/projet.gd")
const REGLAGES := "user://reglages.cfg"
const JETABLE := "user://capture/formes.mbproj"

var _dossier := "D:/MarchingBlocks/ART/formes_speciales"
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
	# Le massif et ses deux salles (ouvertes vers le haut pour qu'on les voie).
	_boite(d, Vector3i(0, 0, 0), Vector3i(16, 7, 16))
	_boite(d, Vector3i(1, 1, 1), Vector3i(4, 7, 6), false)
	_boite(d, Vector3i(10, 3, 11), Vector3i(15, 7, 15), false)
	# La gorge : deux parois face à face, x = 20..22 et x = 29..31.
	_boite(d, Vector3i(20, 0, 0), Vector3i(22, 7, 10))
	_boite(d, Vector3i(29, 0, 0), Vector3i(31, 7, 10))
	_boite(d, Vector3i(20, 0, 0), Vector3i(31, 0, 10))
	# La paroi diagonale : un escalier, 4 cases d'épaisseur.
	for x in range(0, 16):
		for z in range(20, 36):
			var s: int = (x - 0) + (z - 20)
			if s >= 8 and s <= 11:
				_boite(d, Vector3i(x, 0, z), Vector3i(x, 6, z))
	return d


func _clic(ou_monde: Vector3, cible: Vector3, azimut: float, elevation: float, distance: float) -> void:
	var vue = _ecran._vue
	vue._cible = cible
	vue._azimut = azimut
	vue._elevation = elevation
	vue._distance = distance
	vue._caler()
	var c := InputEventMouseButton.new()
	c.button_index = MOUSE_BUTTON_LEFT
	c.position = vue._camera.unproject_position(ou_monde)
	c.pressed = true
	vue._gui_input(c)
	c.pressed = false
	vue._gui_input(c)


func _derouler() -> void:
	await _images(20)
	_ecran._aller_a("monde")
	_ecran._appliquer({"poser": _paysage(), "effacer": {}}, "Landscape")
	await _images(5)

	# Un tunnel en coude, en arche, entre les deux salles.
	_ecran._choisir_forme_speciale("tunnel")
	_ecran._choisir_le_profil("arche")
	_ecran._choisir_les_bouts("relier")
	_clic(Vector3(5.0, 2.5, 3.5), Vector3(5, 3, 3.5), -PI / 2, 0.3, 3.0)
	_clic(Vector3(12.5, 4.5, 11.0), Vector3(12.5, 4.5, 12.5), 0.0, 0.2, 2.0)
	print(_ecran._rapport.text)
	# Un tunnel droit dans la paroi diagonale.
	_ecran._choisir_les_bouts("droit")
	_ecran._choisir_le_profil("rond")
	_ecran._taille_forme.value = 3
	_clic(Vector3(4.5, 3.5, 24.0), Vector3(4.5, 3.5, 24.0), -3.0 * PI / 4, 0.1, 6.0)
	print(_ecran._rapport.text)
	_ecran._taille_forme.value = 2
	# Un pont sur la gorge, et un balcon sur la paroi d'en face.
	_ecran._choisir_forme_speciale("pont")
	_clic(Vector3(23.0, 4.5, 5.5), Vector3(25.5, 4.5, 5.5), PI / 2, 0.0, 2.0)
	print(_ecran._rapport.text)
	_ecran._choisir_forme_speciale("balcon")
	_ecran._longueur_forme.value = 3
	_clic(Vector3(29.0, 5.5, 2.5), Vector3(26.5, 5.5, 2.5), -PI / 2, 0.0, 2.0)
	print(_ecran._rapport.text)
	# Un puits dans le dessus du massif : aveugle, il traverse jusqu'au dessous.
	_ecran._choisir_forme_speciale("puits")
	_clic(Vector3(8.5, 8.0, 8.5), Vector3(8.5, 8.0, 8.5), 0.7, 1.2, 6.0)
	print(_ecran._rapport.text)
	await _images(10)

	var vue = _ecran._vue
	vue._cible = Vector3(14, 3, 14)
	vue._azimut = 0.75
	vue._elevation = 0.75
	vue._distance = 52.0
	vue._caler()
	await _images(10)
	_photo("1_ensemble")
	vue._cible = Vector3(8, 4, 8)
	vue._azimut = 0.6
	vue._elevation = 1.2
	vue._distance = 26.0
	vue._caler()
	await _images(10)
	_photo("2_salles_et_coude")
	vue._cible = Vector3(26, 3, 5)
	vue._azimut = 0.3
	vue._elevation = 0.35
	vue._distance = 22.0
	vue._caler()
	await _images(10)
	_photo("3_pont_et_balcon")
	vue._cible = Vector3(6, 3, 25)
	vue._azimut = -2.35
	vue._elevation = 0.3
	vue._distance = 16.0
	vue._caler()
	await _images(10)
	_photo("4_paroi_diagonale")
	# L'aperçu : un pont survolé (Connect, ancre posée sur la face est du massif), avant le second clic,
	# vers la paroi ouest de la gorge — décalée : le tablier fait un coude.
	_ecran._choisir_forme_speciale("pont")
	_ecran._choisir_les_bouts("relier")
	_clic(Vector3(17.0, 3.5, 2.5), Vector3(18, 3.5, 2.5), PI / 2, 0.3, 1.5)
	vue._cible = Vector3(18.5, 3, 5)
	vue._azimut = 0.0
	vue._elevation = 0.6
	vue._distance = 20.0
	vue._caler()
	await _images(3)
	vue._survoler(vue._camera.unproject_position(Vector3(20.0, 4.5, 8.5)))
	await _images(10)
	_photo("5_apercu_connect")
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
