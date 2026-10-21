extends "res://app/preshapes/forme.gd"
## LA MONTAGNE : un ou plusieurs pics, des contreforts qui rayonnent, des crêtes, l'érosion ; la roche à mi-hauteur, la
## neige au sommet (par la hauteur seule : deux plats de même hauteur ont la même matière).


func _init() -> void:
	id = "montagne"
	nom = "Mountain"
	famille = "reliefs"
	aide = "A peak with spurs and ridges, eroded; grass at the foot, rock, snow on top."


func facteurs() -> Array:
	return [
		f("largeur", "Width", 8, 96, 44, "The base, in cells."),
		f("hauteur", "Height", 4, 64, 30, "The highest peak, in cells."),
		f("pics", "Peaks", 1, 5, 1, "How many summits share the massif."),
		f("contreforts", "Spurs", 0, 9, 5, "Ridges that run down from the summit, like the arms of a star."),
		f("aretes", "Sharpness", 0.0, 1.0, 0.55, "Round shoulders (0) to knife-edge ridges (1).", 0.01),
		f("pente", "Steepness", 0.4, 3.0, 1.3, "Concave slopes that rise late (high) or a bulging dome (low).", 0.01),
		f("erosion", "Erosion", 0.0, 1.0, 0.35, "Gullies and broken rock cut into the slopes.", 0.01),
		f("etirement", "Stretch", 0.4, 1.0, 0.85, "1: round base. Lower: a long massif.", 0.01),
		f("roche", "Rock line", 0.0, 1.0, 0.45, "Where grass gives way to rock (share of the height).", 0.01),
		f("neige", "Snow line", 0.0, 1.0, 0.78, "Where rock gives way to snow (share of the height); 1: no snow.", 0.01),
	]


func packs() -> Array:
	return [
		["Snowy peak", {"hauteur": 40, "largeur": 48, "contreforts": 6, "aretes": 0.7, "neige": 0.7}],
		["Twin peaks", {"pics": 2, "largeur": 60, "hauteur": 34, "etirement": 0.6}],
		["Eroded crag", {"erosion": 0.9, "aretes": 0.85, "pente": 1.8, "hauteur": 26, "neige": 1.0}],
		["Gentle mount", {"pente": 0.7, "aretes": 0.15, "erosion": 0.15, "hauteur": 16, "roche": 0.85, "neige": 1.0}],
		["Sierra", {"pics": 5, "largeur": 90, "etirement": 0.45, "hauteur": 36, "erosion": 0.5}],
	]


func construire(v: Dictionary, b: Bati, rng: RandomNumberGenerator) -> void:
	var rayon: float = v["largeur"] * 0.5
	var H: float = v["hauteur"]
	var et: float = v["etirement"]
	var n_ero := bruit(rng, 0.06, 3)
	var n_ang := bruit(rng, 0.6, 1)
	# Les pics : le premier au centre, les autres sur l'axe long, plus bas.
	var pics: Array = []
	for i in int(v["pics"]):
		var x := 0.0 if i == 0 else rng.randf_range(-0.55, 0.55) * rayon
		var z := 0.0 if i == 0 else rng.randf_range(-0.2, 0.2) * rayon * et
		pics.append([Vector2(x, z), 1.0 if i == 0 else rng.randf_range(0.6, 0.9), rng.randf() * TAU])
	var bandes := [[0, "sol"], [int(round(H * v["roche"])), "roche"], [int(round(H * v["neige"])) + (0 if v["neige"] < 1.0 else 999), "neige"]]
	b.bandes = bandes
	var champ := {}
	for x in range(-ceili(rayon), ceili(rayon) + 1):
		for z in range(-ceili(rayon * et), ceili(rayon * et) + 1):
			var h := 0.0
			var tremble := n_ang.get_noise_2d(x, z) * 0.6
			for p in pics:
				var d := Vector2(x, z / et) - (p[0] as Vector2)
				var r := d.length() / rayon
				if r >= 1.0:
					continue
				var base := pow(1.0 - r, v["pente"])
				# Les contreforts : le profil gonfle le long de rayons qui partent du pic.
				var ang := atan2(d.y, d.x) + float(p[2]) + tremble
				var k: float = v["contreforts"]
				var bras := pow(absf(cos(ang * k * 0.5)), 1.0 + 6.0 * v["aretes"]) if k > 0 else 0.5
				var forme := base * (0.62 + 0.38 * bras) if k > 0 else base
				h = maxf(h, forme * H * float(p[1]))
			if h <= 0.0:
				continue
			h -= v["erosion"] * (0.5 + 0.5 * n_ero.get_noise_2d(x, z)) * minf(h, H * 0.35)
			champ[Vector2i(x, z)] = h
	# Lissé avant d'être arrondi en cases : des versants, pas des piliers.
	b.relief(Bati.lisser(champ, 2), bandes)
