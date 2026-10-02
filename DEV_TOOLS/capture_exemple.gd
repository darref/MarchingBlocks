extends "res://DEV_TOOLS/capture_fluides.gd"
##
## LA CAPTURE DE L'EXEMPLE — AVEC FENÊTRE : l'exemple livré, ouvert par l'appli, vu dans World et dans Witness.
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks --script res://DEV_TOOLS/capture_exemple.gd \
##       -- --dossier=C:/chemin/des/captures
## ⚠ Il ouvre l'EXEMPLE (une copie installée dans les données de l'appli), jamais le projet d'où il vient.


func _derouler() -> void:
	await _images(20)
	await _ecran._ouvrir_l_exemple()
	await _images(10)
	_ecran._aller_a("monde")
	await _images(30)
	_photo("1_monde")
	_cadrer(Vector3(0, 6, 10), deg_to_rad(20.0), deg_to_rad(30.0), 22.0)
	await _images(20)
	_photo("2_monde_pres")
	_ecran._aller_a("witness")
	await _images(30)
	_photo("3_temoin")
	_rendre()
	quit(0)
