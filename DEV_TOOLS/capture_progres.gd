extends "res://DEV_TOOLS/capture_fluides.gd"
##
## LA CAPTURE DE LA BARRE DE PROGRESSION — AVEC FENÊTRE (le tranchage sur un autre fil ne se juge qu'à l'écran).
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks --script res://DEV_TOOLS/capture_progres.gd \
##       -- --dossier=C:/chemin/des/captures
##
## Lance le tranchage du témoin SANS l'attendre, photographie le panneau en plein travail, et COMPTE les images
## dessinées pendant le tranchage : si le travail gelait le fil principal, il n'y en aurait presque aucune.


func _derouler() -> void:
	await _images(20)
	_ecran._aller_a("monde")
	_ecran._appliquer({"poser": _paysage(), "effacer": {}}, "Landscape")
	await _images(5)
	var debut := Time.get_ticks_msec()
	var images_avant := Engine.get_frames_drawn()
	_ecran._trancher_temoin()   # ⚠ pas attendu : on regarde l'écran PENDANT
	await _images(15)
	var pendant: bool = _ecran._attente.visible
	var defile: bool = _ecran._attente_barre.indeterminate
	_photo("tranchage_en_cours")
	while _ecran._attente.visible:
		await process_frame
	var duree := (Time.get_ticks_msec() - debut) / 1000.0
	var images := Engine.get_frames_drawn() - images_avant
	print("PROGRES : panneau pendant le tranchage = %s, barre défilante = %s, durée %.2f s, %d images dessinées (%.0f par s)"
		% [pendant, defile, duree, images, images / maxf(duree, 0.001)])
	print("LOT : %d tuiles" % (_ecran._vue.monde().lot.get_item_list().size() if _ecran._vue.monde().lot != null else -1))
	await _images(10)
	_photo("tranchage_fini")
	_rendre()
	quit(0)
