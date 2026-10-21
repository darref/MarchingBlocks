extends "res://app/preshapes/forme.gd"
## LA MESA ET LA BUTTE EN GRADINS : des falaises droites, des paliers qui rentrent l'un dans l'autre, un contour
## irrégulier ; le dessus d'une matière (sable, herbe, roche), les flancs en roche.


func _init() -> void:
	id = "mesa"
	nom = "Mesa, butte"
	famille = "reliefs"
	aide = "Sheer cliffs and flat tiers stepping inward: a desert butte or a green plateau."


func facteurs() -> Array:
	return [
		f("largeur", "Width", 6, 96, 36, "Across x, at the foot."),
		f("profondeur", "Depth", 6, 96, 28, "Across z, at the foot."),
		f("hauteur", "Height", 2, 48, 18, "The top tier, in cells."),
		f("gradins", "Tiers", 1, 8, 3, "How many flat steps from the foot to the top."),
		f("retrait", "Inset", 1, 12, 4, "How far each tier steps back, in cells."),
		f("contour", "Ragged edge", 0.0, 1.0, 0.45, "A clean oval (0) or a torn, eroded outline (1).", 0.01),
		f("carre", "Squareness", 0.0, 1.0, 0.3, "Oval (0) to boxy (1).", 0.01),
		choix("dessus", "Top", ["Sand", "Grass", "Rock"], 0, "The material of each flat tier."),
	]


func packs() -> Array:
	return [
		["Desert butte", {"largeur": 24, "profondeur": 20, "hauteur": 22, "gradins": 2, "retrait": 3}],
		["Tiered mesa", {"largeur": 70, "profondeur": 50, "gradins": 5, "retrait": 5, "hauteur": 26}],
		["Green plateau", {"dessus": 1, "gradins": 1, "largeur": 60, "profondeur": 60, "hauteur": 10}],
		["Rock table", {"dessus": 2, "carre": 0.9, "contour": 0.15, "gradins": 1}],
	]


func construire(v: Dictionary, b: Bati, rng: RandomNumberGenerator) -> void:
	var rx: float = v["largeur"] * 0.5
	var rz: float = v["profondeur"] * 0.5
	var n := int(v["gradins"])
	var H: float = v["hauteur"]
	var bruit_ := bruit(rng, 0.08, 3)
	var dessus: String = ["sable", "sol", "roche"][int(v["dessus"])]
	var p: float = 2.0 + 8.0 * v["carre"]
	for x in range(-ceili(rx), ceili(rx) + 1):
		for z in range(-ceili(rz), ceili(rz) + 1):
			# La « distance » au bord, en cases, dans la norme de Minkowski qui va de l'ovale au carré.
			var q := pow(pow(absf(x) / rx, p) + pow(absf(z) / rz, p), 1.0 / p)
			var marge: float = (1.0 - q) * minf(rx, rz) + v["contour"] * bruit_.get_noise_2d(x, z) * 5.0
			if marge < 0.0:
				continue
			var palier := mini(n, int(marge / float(v["retrait"])) + 1)
			var hi := int(round(H * palier / n))
			if hi >= 1:
				b.colonne(x, z, 0, hi - 1, dessus, "roche")
