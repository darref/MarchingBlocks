extends "res://DEV_TOOLS/capture_fluides.gd"
##
## LA CAPTURE DES COUCHES EXCLUSIVES — AVEC FENÊTRE (une fente à la frontière de deux couches ne se juge qu'à l'image).
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks --script res://DEV_TOOLS/capture_couches_exclusives.gd \
##       -- --dossier=C:/chemin/des/captures
##
## Deux couches tranchées sur le témoin, la seconde peinte PAR-DESSUS la moitié de la première. Photo 1 : la règle
## en couches (l'union choisit les tuiles). Photo 2 : le contraste — chaque couche SEULE, l'ancienne règle, qui ferme
## sa surface à la frontière.


func _derouler() -> void:
	await _images(20)
	_ecran._aller_a("monde")
	await _ecran._trancher_temoin()
	var a := {}
	_boite(a, Vector3i(0, 0, 0), Vector3i(11, 2, 11))
	_boite(a, Vector3i(2, 3, 2), Vector3i(7, 4, 9))
	_ecran._appliquer({"poser": a, "effacer": {}}, "A")
	_ecran._nouvelle_couche()
	await _ecran._trancher_temoin()
	var b := {}
	_boite(b, Vector3i(6, 0, 0), Vector3i(17, 3, 11))
	_ecran._appliquer({"poser": b, "effacer": {}}, "B")
	var ga: GridMap = _ecran._vue.couche(0).get_node("Cases")
	print("COUCHES : A %d cases, B %d cases" % [ga.get_used_cells().size(), _ecran._vue.cases().get_used_cells().size()])
	_cadrer(Vector3(9, 3, 6), deg_to_rad(35.0), deg_to_rad(35.0), 26.0)
	await _images(20)
	_photo("1_en_couches")
	# ↑ : la couche B (active, en bas de la liste) passe au-dessus — les coins de la frontière prennent ses tuiles.
	_ecran._deplacer_couche(-1)
	await _images(20)
	_photo("1b_B_au_dessus")
	_ecran._histoire.undo()
	await _images(5)
	for i in 2:
		_ecran._vue.couche(i).rang = -1
		_ecran._vue.couche(i).reconstruire()
	await _images(20)
	_photo("2_chacune_seule")
	_rendre()
	quit(0)
