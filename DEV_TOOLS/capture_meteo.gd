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
	_ecran._aller_a("fluides")
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
	# LE DISQUE SOLAIRE (Jordan, 3 octobre 2026) : sans météo, le soleil bas, DROIT DEVANT la caméra (le disque est du
	# côté du +Z de la lumière : azimut = celui du regard), d'abord au réglage par défaut puis gros et brillant.
	_ecran._choix_meteo.select(0)
	_ecran._choix_meteo.item_selected.emit(0)
	var f: Vector3 = -_ecran._vue._camera.global_transform.basis.z
	(_ecran._controles_rendu["soleil_azimut"] as HSlider).value = rad_to_deg(atan2(f.x, f.z))
	(_ecran._controles_rendu["soleil_hauteur"] as HSlider).value = 6.0
	await _images(60)
	_photo("soleil_1_defaut")
	(_ecran._controles_rendu["soleil_disque_taille"] as HSlider).value = 7.0
	(_ecran._controles_rendu["soleil_disque_eclat"] as HSlider).value = 12.0
	await _images(30)
	_photo("soleil_2_gros")
	_ecran._remettre_le_rendu()
	_rendre()
	quit(0)
