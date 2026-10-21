extends "res://app/preshapes/forme.gd"
## LES COLLINES : une colline ronde, un drumlin allongé, ou un groupe de collines qui se fondent.


func _init() -> void:
	id = "collines"
	nom = "Hills"
	famille = "reliefs"
	aide = "One round hill, a long drumlin, or a group of hills merging into rolling land."


func facteurs() -> Array:
	return [
		f("nombre", "Count", 1, 12, 1, "How many hills."),
		f("etendue", "Spread", 0, 96, 30, "How far apart a group of hills spreads, in cells."),
		f("largeur", "Width", 4, 64, 26, "One hill, across x."),
		f("profondeur", "Depth", 4, 64, 26, "One hill, across z."),
		f("hauteur", "Height", 1, 32, 8, "The tallest hill."),
		f("rondeur", "Roundness", 0.3, 3.0, 1.0, "Pointed (low) to flat-topped dome (high).", 0.01),
		f("variete", "Variety", 0.0, 1.0, 0.4, "How much the hills of a group differ in size.", 0.01),
		f("bosses", "Bumps", 0.0, 1.0, 0.2, "Small bumps on the slopes.", 0.01),
		choix("dessus", "Cover", ["Grass", "Second ground", "Sand"], 0, "The material of the hills."),
	]


func packs() -> Array:
	return [
		["Round hill", {}],
		["Drumlin", {"largeur": 40, "profondeur": 14, "hauteur": 6, "rondeur": 1.6}],
		["Rolling hills", {"nombre": 7, "etendue": 70, "largeur": 22, "profondeur": 22, "hauteur": 6, "variete": 0.6}],
		["Knoll", {"largeur": 10, "profondeur": 10, "hauteur": 4, "rondeur": 0.6}],
	]


func construire(v: Dictionary, b: Bati, rng: RandomNumberGenerator) -> void:
	var dessus: String = ["sol", "sol2", "sable"][int(v["dessus"])]
	var n_bosses := bruit(rng, 0.15, 2)
	var champ := {}
	for i in int(v["nombre"]):
		var c := Vector2.ZERO if i == 0 else Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)) * float(v["etendue"])
		var t: float = 1.0 - v["variete"] * rng.randf()
		var rx: float = v["largeur"] * 0.5 * t
		var rz: float = v["profondeur"] * 0.5 * t
		var H: float = v["hauteur"] * t
		for x in range(floori(c.x - rx), ceili(c.x + rx) + 1):
			for z in range(floori(c.y - rz), ceili(c.y + rz) + 1):
				var d := Vector2((x - c.x) / rx, (z - c.y) / rz).length()
				if d >= 1.0:
					continue
				var h := H * pow(cos(d * PI * 0.5), 1.0 / v["rondeur"])
				var k := Vector2i(x, z)
				champ[k] = maxf(float(champ.get(k, 0.0)), h)
	for k in champ:
		var hi := int(round(float(champ[k]) + v["bosses"] * 2.0 * n_bosses.get_noise_2d(k.x, k.y)))
		if hi >= 1:
			b.colonne(k.x, k.y, 0, hi - 1, dessus, dessus)
