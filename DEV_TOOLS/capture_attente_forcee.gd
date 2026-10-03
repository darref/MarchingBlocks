extends "res://DEV_TOOLS/capture_fluides.gd"
##
## LA BARRE POUR UN GESTE QUI DURE — AVEC FENÊTRE (3 octobre 2026). Un geste connu pour être long (ici F9, appris à
## 2 s) est RETENU : le panneau s'affiche, puis le geste est rejoué. On photographie l'écran pendant l'attente : le
## panneau doit porter le NOM DU GESTE (le dessin forcé, écarté, montrait le texte d'une attente d'avant).
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks --script res://DEV_TOOLS/capture_attente_forcee.gd \
##       -- --dossier=C:/chemin/des/captures


func _derouler() -> void:
	# ⚠ LES RÉGLAGES DE L'UTILISATEUR, COPIÉS SUR LE DISQUE avant tout (une sonde interrompue les perdait, §6).
	if _reglages_avant != "":
		var f := FileAccess.open("user://reglages.cfg.avant_capture", FileAccess.WRITE)
		f.store_string(_reglages_avant)
		f.close()
	await _images(30)
	_ecran._aller_a("monde")
	await _images(10)
	_ecran._durees_gestes.par_unite["touche:monde:F9"] = 2.0 / 1000.0
	var k := InputEventKey.new()
	k.keycode = KEY_F9
	k.physical_keycode = KEY_F9
	k.pressed = true
	Input.parse_input_event(k)
	var vu := false
	var titre := ""
	for i in 6:
		await process_frame
		if _ecran._attente.visible and not vu:
			vu = true
			titre = _ecran._attente_titre.text
			await RenderingServer.frame_post_draw
			_photo("attente_du_geste")
	for i in 10:
		await process_frame
	print("GESTE LONG : panneau vu = %s, titre « %s », caché ensuite = %s, rejoué et chronométré = %s"
		% [vu, titre, not _ecran._attente.visible, _ecran._geste == ""])
	print("VERDICT : %s" % ("OK" if vu and titre == "F9" and not _ecran._attente.visible else "ÉCHEC"))
	_rendre()
	DirAccess.remove_absolute("user://reglages.cfg.avant_capture")
	quit(0)
