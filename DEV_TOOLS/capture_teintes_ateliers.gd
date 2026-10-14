extends "res://DEV_TOOLS/capture_fluides.gd"
##
## LA TEINTE DE CHAQUE ATELIER — AVEC FENÊTRE (Jordan, 2 octobre 2026 : sa barre de droite et son bouton prennent sa
## couleur, le reste garde l'olive). Une photo par atelier.
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks --script res://DEV_TOOLS/capture_teintes_ateliers.gd \
##       -- --dossier=C:/chemin/des/captures


func _derouler() -> void:
	await _images(20)
	_ecran._aller_a("monde")
	_ecran._appliquer({"poser": _paysage(), "effacer": {}}, "Landscape")
	await _images(5)
	for a in ["projet", "monde", "fluides", "witness", "texture", "jeu", "variantes"]:
		_ecran._aller_a(a)
		await _images(25)
		_photo("atelier_" + a)
	_ecran._aller_a("monde")
	_rendre()
	quit(0)
