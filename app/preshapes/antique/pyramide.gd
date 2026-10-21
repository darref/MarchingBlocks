extends "res://app/preshapes/forme.gd"
## LA PYRAMIDE : à degrés, lisse, ou en ruine ; une plateforme au sommet, des escaliers sur une ou quatre faces (des
## marches d'une case : on y monte à pied).


func _init() -> void:
	id = "pyramide"
	nom = "Pyramid"
	famille = "antique"
	aide = "Stepped, smooth or ruined; a flat top, and stairs you can walk up on one or four faces."


func facteurs() -> Array:
	return [
		f("base", "Base", 5, 96, 33, "The side of the square base, in cells."),
		f("hauteur_degre", "Step height", 1, 8, 1, "Each step's height (1: a smooth slope of one-cell steps)."),
		f("retrait", "Step inset", 1, 6, 1, "How far each step steps back, in cells."),
		f("sommet", "Top platform", 1, 24, 3, "The width of the top."),
		choix("escaliers", "Stairs", ["None", "One face", "Four faces"], 1, "Stairs up the middle of the faces."),
		f("largeur_escalier", "Stair width", 1, 9, 3, "Across the stairs."),
		f("ruine", "Ruin", 0.0, 1.0, 0.0, "Crumbled edges, missing blocks.", 0.01),
		coche("temple", "Temple on top", false, "A small walled shrine on the platform."),
	]


func packs() -> Array:
	return [
		["Great pyramid", {"base": 61, "hauteur_degre": 1, "retrait": 1, "sommet": 1, "escaliers": 0}],
		["Step pyramid", {"base": 41, "hauteur_degre": 4, "retrait": 3, "sommet": 7, "escaliers": 1}],
		["Mesoamerican", {"base": 35, "hauteur_degre": 3, "retrait": 2, "sommet": 9, "escaliers": 2, "temple": true}],
		["Ruined pyramid", {"base": 33, "ruine": 0.7, "escaliers": 1}],
	]


func construire(v: Dictionary, b: Bati, rng: RandomNumberGenerator) -> void:
	var demi := int(v["base"]) / 2
	var hd := int(v["hauteur_degre"])
	var re := int(v["retrait"])
	var s := int(v["sommet"]) / 2
	var n := maxi(1, (demi - s) / re)
	var bruit_ := bruit(rng, 0.25, 2)
	var haut_ := 0
	for i in n + 1:
		var r := demi - i * re
		if r < s and i > 0:
			break
		var y0 := i * hd
		for y in range(y0, y0 + hd):
			for x in range(-r, r + 1):
				for z in range(-r, r + 1):
					var bord := maxi(absi(x), absi(z)) >= r - 1
					if v["ruine"] > 0.0 and bord and bruit_.get_noise_3d(x, y, z) > 1.0 - v["ruine"] * 1.2:
						continue
					b.case(x, y, z, "pierre")
		haut_ = y0 + hd
	var w := int(v["largeur_escalier"]) / 2
	var faces: Array = [] if int(v["escaliers"]) == 0 else ([Vector2i(0, 1)] if int(v["escaliers"]) == 1 else
		[Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)])
	# L'escalier : une marche d'une case de haut par case d'avancée, du sommet (à fleur de la plateforme) jusqu'au sol.
	# Plus raide que la face, il en sort ; plus doux, il s'y TAILLE (le vide au-dessus de chaque marche).
	for f_ in faces:
		var travers := Vector2i(absi(f_.y), absi(f_.x))
		for d in range(s + 1, s + haut_ + 1):
			var y := haut_ + s - d
			for k in range(-w, w + 1):
				var p: Vector2i = f_ * d + travers * k
				for yy in range(0, y + 1):
					b.case(p.x, yy, p.y, "pierre")
				for yy in range(y + 1, haut_ + 1):
					b.vider(p.x, yy, p.y)
	if v["temple"]:
		var t := maxi(1, s - 1)
		for x in range(-t, t + 1):
			for z in range(-t, t + 1):
				if maxi(absi(x), absi(z)) == t:
					for y in range(haut_, haut_ + 3):
						b.case(x, y, z, "pierre")
		for x in range(-t, t + 1):
			for z in range(-t, t + 1):
				b.case(x, haut_ + 3, z, "toit")
		b.vider(0, haut_, t)
		b.vider(0, haut_ + 1, t)
