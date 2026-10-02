extends "res://DEV_TOOLS/capture_fluides.gd"
##
## LA CAPTURE DES TROIS LIQUIDES ET DE LA MÉTÉO — AVEC FENÊTRE (le compilateur de shaders ne tourne pas sans).
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks --script res://DEV_TOOLS/capture_meteo.gd \
##       -- --dossier=C:/chemin/des/captures
##
## Le paysage de `capture_fluides.gd`, trois couches d'eau : le lac du plateau en LAVE, la rivière en ACIDE, la mer
## en MARAIS. Des photos dans World, puis au Play test sous chaque temps. ⚠ Une ligne « SHADER ERROR » dans la sortie
## est un échec.


func _derouler() -> void:
	await _images(20)
	_ecran._aller_a("monde")
	_ecran._appliquer({"poser": _paysage(), "effacer": {}}, "Landscape")
	await _ecran._trancher_temoin()
	_ecran._aller_a("monde")
	_ecran._choisir_eau()
	var presets := ["lave", "acide", "marais"]
	var sources := [Vector3i(6, 6, 6), Vector3i(12, 8, 6), Vector3i(40, 1, 40)]
	for i in 3:
		if i > 0:
			_ecran._ajouter_eau(_ecran.Projet.couche_d_eau(presets[i]))
		_ecran._eaux[i]["preset"] = presets[i]
		_ecran._eau_active = i
		_ecran._eau_cliquee(sources[i], MOUSE_BUTTON_LEFT)
	_ecran._recalculer_eau(false)
	await _images(30)
	_cadrer(Vector3(12, 3, 11), 0.75, 0.62, 44.0)
	await _images(20)
	_photo("liquides_1_ensemble")
	_cadrer(Vector3(6.5, 6.5, 6.5), 0.5, 0.9, 13.0)
	await _images(20)
	_photo("liquides_2_lave")
	_cadrer(Vector3(15, 5, 6), 1.3, 0.35, 13.0)
	await _images(20)
	_photo("liquides_3_acide")
	_cadrer(Vector3(22, 2, 6), 1.6, 0.3, 14.0)
	await _images(20)
	_photo("liquides_4_marais")

	# LE PLAY TEST, sous chaque temps : le personnage sur le plateau, la caméra derrière lui.
	_ecran._vue._cible = Vector3(10, 8, 10)
	await _ecran._changer_d_atelier("jeu")
	await _images(60)
	for i in _ecran._choix_meteo.item_count:
		_ecran._choix_meteo.select(i)
		_ecran._choix_meteo.item_selected.emit(i)
		await _images(90)
		_photo("meteo_%d_%s" % [i, _ecran._vue.METEOS[i][0]])
	_ecran._remettre_le_rendu()
	_rendre()
	quit(0)
