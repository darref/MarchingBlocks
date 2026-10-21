extends "res://app/preshapes/forme.gd"
## LE VOLCAN : un cône, son cratère, une brèche dans le bord, des coulées qui descendent. Le cratère se creuse dans le
## cône (sa lave, ou son lac, vient de Fluids).


func _init() -> void:
	id = "volcan"
	nom = "Volcano"
	famille = "reliefs"
	aide = "A cone with a crater, a breach in its rim and ridges of old lava; fill the crater in Fluids."


func facteurs() -> Array:
	return [
		f("largeur", "Width", 10, 96, 50, "The base, in cells."),
		f("hauteur", "Height", 4, 56, 26, "The rim, in cells."),
		f("cratere", "Crater", 0.05, 0.6, 0.28, "The crater's width, as a share of the base.", 0.01),
		f("profondeur", "Crater depth", 0, 40, 9, "How deep the crater sinks below the rim."),
		f("breche", "Breach", 0.0, 1.0, 0.0, "A notch in the rim, down to this share of its height.", 0.01),
		f("coulees", "Lava ridges", 0, 10, 4, "Old flows: ridges running down the flanks."),
		f("pente", "Profile", 0.4, 2.5, 1.5, "Concave like a stratovolcano (high) or a shield (low).", 0.01),
		f("rugosite", "Roughness", 0.0, 1.0, 0.3, "Broken, uneven flanks.", 0.01),
		f("verdure", "Green foot", 0.0, 1.0, 0.3, "How high grass climbs, as a share of the height.", 0.01),
	]


func packs() -> Array:
	return [
		["Stratovolcano", {"hauteur": 40, "pente": 1.8, "cratere": 0.18, "profondeur": 8}],
		["Caldera", {"largeur": 80, "hauteur": 18, "cratere": 0.55, "profondeur": 10, "pente": 0.9}],
		["Breached cone", {"breche": 0.85, "coulees": 6}],
		["Shield volcano", {"largeur": 90, "hauteur": 14, "pente": 0.5, "cratere": 0.1, "profondeur": 3}],
		["Crater lake", {"cratere": 0.4, "profondeur": 14, "verdure": 0.7}],
	]


func construire(v: Dictionary, b: Bati, rng: RandomNumberGenerator) -> void:
	var R: float = v["largeur"] * 0.5
	var H: float = v["hauteur"]
	var rc: float = R * v["cratere"]
	var prof: float = v["profondeur"]
	var n_rug := bruit(rng, 0.11, 3)
	var cap_breche := rng.randf() * TAU
	var caps: Array = []
	for i in int(v["coulees"]):
		caps.append(rng.randf() * TAU)
	var bandes := [[0, "sol"], [maxi(1, int(round(H * v["verdure"]))), "roche"]]
	b.bandes = bandes
	var champ := {}
	for x in range(-ceili(R), ceili(R) + 1):
		for z in range(-ceili(R), ceili(R) + 1):
			var d := Vector2(x, z).length()
			if d >= R:
				continue
			var ang := atan2(z, x)
			var h: float
			if d <= rc:
				# Le cratère : une cuvette sous le bord.
				h = H - prof * (1.0 - pow(d / rc, 2.0))
			else:
				h = H * pow(1.0 - (d - rc) / (R - rc), v["pente"])
				for c in caps:
					var ecart := absf(wrapf(ang - float(c), -PI, PI))
					h += H * 0.12 * maxf(0.0, 1.0 - ecart * d * 0.35) * (1.0 - d / R)
			# La brèche : une entaille dans le bord, vers un cap.
			var eb := absf(wrapf(ang - cap_breche, -PI, PI))
			if v["breche"] > 0.0 and eb * maxf(d, 1.0) < 3.5 and d < rc * 2.2:
				h = minf(h, H * (1.0 - v["breche"]) + (d / rc) * 0.5)
			h += v["rugosite"] * n_rug.get_noise_2d(x, z) * 2.0
			champ[Vector2i(x, z)] = h
	b.relief(champ, bandes)
