extends SceneTree
##
## LA CAPTURE DU LOGICIEL — MarchingBlocks ouvert pour de vrai, photographié à trois moments.
##
## LANCEMENT — ⚠ AVEC FENÊTRE, jamais en headless (le headless ne rend RIEN) :
##   Godot_v4.7-stable_win64_console.exe --path D:/UnderMend \
##       --script res://DEV_TOOLS/capture_app.gd -- --dossier=C:/chemin/des/captures
##
## ⚠ **UN LOGICIEL NE SE JUGE PAS SUR SES TESTS** (charte §6 : « un greffon d'éditeur ne se teste pas en
## headless ») : que l'écran s'ouvre, que les panneaux tiennent, que le monde de test se peigne, ça se
## VOIT. Ce harnais ne clique pas à la place de Jordan : il appelle les mêmes fonctions que les boutons,
## et photographie ce qui en sort.

var _dossier := "D:/UnderMend/ART/app"
var _ecran: Control


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--dossier="):
			_dossier = option.substr("--dossier=".length())
	DirAccess.make_dir_recursive_absolute(_dossier)
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	_derouler()


func _derouler() -> void:
	await _images(20)
	_photo("1_temoin")

	await _ecran._trancher_temoin()
	# Un petit monde peint à la main : un plateau, une marche, un trou.
	var cases: GridMap = _ecran._vue.cases()
	var id: int = _ecran._id_case()
	for x in range(0, 8):
		for z in range(0, 6):
			cases.set_cell_item(Vector3i(x, 0, z), id)
	for x in range(2, 6):
		for z in range(1, 4):
			cases.set_cell_item(Vector3i(x, 1, z), id)
	cases.set_cell_item(Vector3i(3, 1, 2), -1)
	cases.set_cell_item(Vector3i(3, 0, 2), -1)
	_ecran._reconstruire()
	await _images(20)
	_photo("2_monde")

	_ecran._pbr.button_pressed = true
	await _ecran._trancher_temoin()
	for x in range(0, 8):
		for z in range(0, 6):
			cases.set_cell_item(Vector3i(x, 0, z), id)
	_ecran._reconstruire()
	await _images(30)
	_photo("3_monde_pbr")
	quit(0)


func _images(n: int) -> void:
	for i in n:
		await process_frame


func _photo(nom: String) -> void:
	var img: Image = root.get_texture().get_image()
	var chemin: String = _dossier.path_join(nom + ".png")
	var err := img.save_png(chemin)
	print("%s → %s (%dx%d, %s)" % [nom, chemin, img.get_width(), img.get_height(),
		"écrite" if err == OK else "ERREUR %d" % err])
