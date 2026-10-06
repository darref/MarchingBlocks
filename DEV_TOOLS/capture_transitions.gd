extends "res://DEV_TOOLS/capture_fluides.gd"
##
## LA CAPTURE DES TRANSITIONS — AVEC FENÊTRE (le shader ne se compile qu'avec un rendu, et un fondu se juge à l'image).
##   Godot_v4.7-stable_win64_console.exe --path <copie> --script res://DEV_TOOLS/capture_transitions.gd \
##       -- --dossier=C:/chemin/des/captures
##
## Deux couches côte à côte sur un plateau à deux niveaux. A garde la légende du témoin calculé ; le témoin de B reçoit un
## matériau BLEU en damier sur toutes ses faces — son représentant par défaut est donc ce qu'il montre déjà, comme dans un
## vrai projet. Photos : sans transition ; la paire allumée (A, plus haute, couvre) ; A qui avance de 0,4 ; B peinte pour
## couvrir sur une partie de la frontière ; de près, un joint de tuiles dans la bande (une marche s'y verrait).


func _derouler() -> void:
	await _images(20)
	_ecran._aller_a("monde")
	await _ecran._trancher_temoin()
	var a := {}
	_boite(a, Vector3i(0, 0, 0), Vector3i(9, 2, 15))
	_boite(a, Vector3i(2, 3, 3), Vector3i(8, 4, 10))
	_ecran._appliquer({"poser": a, "effacer": {}}, "A")
	_ecran._nouvelle_couche()
	var b := {}
	_boite(b, Vector3i(10, 0, 0), Vector3i(19, 2, 15))
	_boite(b, Vector3i(9, 3, 3), Vector3i(14, 4, 10))
	_ecran._appliquer({"poser": b, "effacer": {}}, "B")
	_habiller_en_bleu(_ecran._couches[1])
	_ecran._activer(0)
	_ecran._aller_a("monde")
	_cadrer(Vector3(10, 3, 8), deg_to_rad(20.0), deg_to_rad(40.0), 24.0)
	await _images(20)
	_photo("1_sans_transition")
	_ecran._aller_a("transitions")
	var tr: RefCounted = _ecran._transitions
	var ida := str(_ecran._couches[0]["id"])
	var idb := str(_ecran._couches[1]["id"])
	var cle: String = tr.TR.cle_de_paire(ida, idb)
	tr.paire_choisie = cle
	tr.allumer(cle, true)
	tr.suivre()
	await _images(20)
	_photo("2_allumee_A_couvre")
	tr.regler(ida, "avance", 0.4)
	tr.suivre()
	await _images(10)
	_photo("3_A_avance")
	tr.couvrant_peint = idb
	# Sur le dessus du sol, là où la frontière se VOIT (z 11 à 15 : devant le bloc du haut) — le sommet du dessus est en y = 2.
	tr.rayon = 2
	tr.peindre(Vector3i(9, 2, 12), MOUSE_BUTTON_LEFT, "debut")
	tr.peindre(Vector3i(9, 2, 14), MOUSE_BUTTON_LEFT, "suite")
	tr.peindre(null, MOUSE_BUTTON_LEFT, "fin")
	tr.suivre()
	print("CHOIX PEINTS : %d" % (tr.etat["choix"] as Dictionary).size())
	await _images(10)
	_photo("4_B_peinte")
	_cadrer(Vector3(10, 3, 12), deg_to_rad(10.0), deg_to_rad(45.0), 9.0)
	await _images(10)
	_photo("5_de_pres")
	_ecran._aller_a("monde")
	await _images(10)
	_photo("6_dans_World")
	_rendre()
	quit(0)


## Le témoin de B porte un matériau bleu en damier sur toutes ses faces ; écrit, son monde le suit.
func _habiller_en_bleu(c: Dictionary) -> void:
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var v := 0.7 + 0.3 * float(((x / 16) + (y / 16)) % 2)
			img.set_pixel(x, y, Color(v, v, v))
	var chemin := ProjectSettings.globalize_path("user://capture/bleu.png")
	img.save_png(chemin)
	var t: RefCounted = _ecran._temoin_de(c)
	t.materiaux.append({"nom": "Blue", "couleur": Color(0.25, 0.45, 1.0), "rugosite": 0.8, "metal": 0.0,
		"texture": chemin, "echelle": 1.0})
	var k: int = t.materiaux.size() - 1
	for nom in t.tuiles:
		var m: RefCounted = t.tuiles[nom]
		for f in m.mats.size():
			m.mats[f] = k
	t._partager()
	_ecran._temoins_sales[t] = true
	_ecran._enregistrer_le_temoin_modele(true)
