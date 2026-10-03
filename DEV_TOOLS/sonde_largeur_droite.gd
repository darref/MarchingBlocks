extends "res://DEV_TOOLS/capture_fluides.gd"
##
## SONDE AVEC FENÊTRE — « la barre de droite déborde à droite en World » (Jordan, 3 octobre 2026). Parcourt les outils,
## les formes spéciales, une sélection, et dit pour chaque état la largeur de la barre de droite (elle doit rester
## `LARGEUR_DROITE`) et le descendant visible dont la largeur minimale est la plus grande. Ne conçoit rien, mesure.
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_largeur_droite.gd


func _derouler() -> void:
	if _reglages_avant != "":
		var f := FileAccess.open("user://reglages.cfg.avant_capture", FileAccess.WRITE)
		f.store_string(_reglages_avant)
		f.close()
	await _images(30)
	_ecran._aller_a("monde")
	await _images(5)
	_mesurer("World, au départ")
	for o in ["ajouter", "creuser", "selectionner", "rect", "boite"]:
		_ecran._choisir_outil(o)
		await _images(3)
		_mesurer("outil " + o)
	_ecran._choisir_outil("selectionner")
	_ecran._vue.regler_selection({Vector3i(0, 0, 0): true})
	await _images(3)
	_mesurer("avec une sélection")
	_photo("barre_droite_selection")
	var pile: Control = _ecran._droite.get_meta("pile")
	var marge: Control = pile.get_parent()
	var defile := marge.get_parent() as ScrollContainer
	var place := defile.size.x - (defile.get_v_scroll_bar().size.x if defile.get_v_scroll_bar().visible else 0.0)
	print("CONTENU : il demande %.0f px, il a %.0f px (ascenseur %s) → %s" % [marge.get_combined_minimum_size().x, place,
		defile.get_v_scroll_bar().visible, "tient" if marge.get_combined_minimum_size().x <= place + 0.5 else "COUPÉ"])
	for b in _ecran._boutons_forme_speciale:
		(_ecran._boutons_forme_speciale[b] as Button).pressed.emit()
		await _images(3)
		_mesurer("forme " + str(b))
	_ecran._aller_a("fluides")
	await _images(3)
	_mesurer("Fluids")
	_rendre()
	DirAccess.remove_absolute("user://reglages.cfg.avant_capture")
	quit(0)


func _mesurer(quoi: String) -> void:
	var barre: Control = _ecran._droite if _ecran._atelier == "monde" else _ecran._droite_fluides
	var pire: Control = null
	var largeur := 0.0
	for n in barre.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree():
			continue
		var w := c.get_combined_minimum_size().x
		# le plus PROFOND des plus larges : celui qui impose sa largeur
		if w >= largeur - 0.5 and (pire == null or w > largeur + 0.5 or pire.is_ancestor_of(c)):
			largeur = w
			pire = c
	var feuilles: Array = []
	for n in barre.find_children("*", "Control", true, false):
		var c := n as Control
		if c.is_visible_in_tree() and not (c is Container):
			feuilles.append(c)
	feuilles.sort_custom(func(a, b): return a.get_combined_minimum_size().x > b.get_combined_minimum_size().x)
	for c in feuilles.slice(0, 3):
		var t := ""
		if c is Label:
			t = (c as Label).text.left(50)
		elif c is Button:
			t = (c as Button).text.left(50)
		print("      %4.0f px  %s « %s » dans %s" % [c.get_combined_minimum_size().x, c.get_class(), t, c.get_parent().get_class()])
	var rangs: Array = []
	for n in barre.find_children("*", "HBoxContainer", true, false):
		if (n as Control).is_visible_in_tree():
			rangs.append(n)
	rangs.sort_custom(func(a, b): return a.get_combined_minimum_size().x > b.get_combined_minimum_size().x)
	for r in rangs.slice(0, 2):
		var noms: Array = []
		for e in r.get_children():
			noms.append((e as Button).text if e is Button else e.get_class())
		print("      rangée %4.0f px : %s" % [r.get_combined_minimum_size().x, noms])
	for n in barre.find_children("*", "Container", true, false):
		var cc := n as Container
		if cc.is_visible_in_tree() and (cc is GridContainer or cc is HBoxContainer) and cc.get_combined_minimum_size().x > 270:
			var noms: Array = []
			for e in cc.get_children():
				noms.append((e as Button).text if e is Button else e.get_class())
			print("      LARGE %s %4.0f px : %s" % [cc.get_class(), cc.get_combined_minimum_size().x, noms])
	var texte := ""
	if pire is Label:
		texte = (pire as Label).text.left(60)
	elif pire is Button:
		texte = (pire as Button).text.left(60)
	print("%-28s barre %4.0f px (voulue %d), min %4.0f px — le plus large : %s « %s » (%s)" % [quoi, barre.size.x,
		_ecran.LARGEUR_DROITE, barre.get_combined_minimum_size().x, pire.get_class() if pire else "-", texte,
		str(pire.get_path()).get_slice("/", -1) if pire else ""])
