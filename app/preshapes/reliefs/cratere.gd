extends "res://app/preshapes/forme.gd"
## LE CRATÈRE, LE CIRQUE, LA DOLINE : une cuvette CREUSÉE dans le monde, son bourrelet autour ; ronde (cratère), ouverte
## d'un côté (cirque), ou un entonnoir à parois raides (doline).


func _init() -> void:
	id = "cratere"
	nom = "Crater, basin"
	famille = "reliefs"
	aide = "Digs a bowl into the world with a raised rim: an impact crater, a cirque open on one side, a sinkhole."


func facteurs() -> Array:
	return [
		f("largeur", "Width", 4, 96, 30, "Across the bowl, rim included."),
		f("profondeur", "Depth", 1, 40, 8, "Below the ground you aim at."),
		f("bourrelet", "Rim height", 0, 16, 3, "How high the rim rises above the ground."),
		f("epaisseur", "Rim width", 1, 24, 5, "How wide the rim is."),
		f("forme", "Bowl shape", 0.3, 4.0, 1.6, "Steep funnel (low) to flat-floored (high).", 0.01),
		f("ouverture", "Open side", 0.0, 1.0, 0.0, "A cirque: one side of the rim is gone, the bowl opens onto the land.", 0.01),
		choix("dessus", "Rim", ["Rock", "Grass", "Sand"], 0, "The material of the rim."),
	]


func packs() -> Array:
	return [
		["Impact crater", {"largeur": 50, "profondeur": 10, "bourrelet": 5, "epaisseur": 8}],
		["Sinkhole", {"largeur": 14, "profondeur": 20, "bourrelet": 0, "forme": 0.6}],
		["Glacial cirque", {"largeur": 44, "profondeur": 12, "ouverture": 0.6, "bourrelet": 10, "epaisseur": 10}],
		["Pond hollow", {"largeur": 16, "profondeur": 3, "bourrelet": 1, "dessus": 1, "forme": 2.5}],
	]


func construire(v: Dictionary, b: Bati, rng: RandomNumberGenerator) -> void:
	var R: float = v["largeur"] * 0.5
	var ep: float = v["epaisseur"]
	var ri := maxf(R - ep, 1.0)
	var P: float = v["profondeur"]
	var B: float = v["bourrelet"]
	var dessus: String = ["roche", "sol", "sable"][int(v["dessus"])]
	var cap := rng.randf() * TAU
	for x in range(-ceili(R), ceili(R) + 1):
		for z in range(-ceili(R), ceili(R) + 1):
			var d := Vector2(x, z).length()
			if d > R:
				continue
			var ouvert: bool = v["ouverture"] > 0.0 and cos(atan2(z, x) - cap) > 1.0 - 2.0 * v["ouverture"]
			if d <= ri:
				var bas := -int(round(P * (1.0 - pow(d / ri, v["forme"]))))
				for y in range(bas, int(B) + 5):
					b.vider(x, y, z)
			elif not ouvert and B >= 1.0:
				var h := B * sin(PI * (d - ri) / ep)
				var hi := int(round(h))
				if hi >= 1:
					b.colonne(x, z, 0, hi - 1, dessus, "roche")
	# Le cirque : une rampe qui remonte du fond jusqu'au sol, du côté ouvert.
	if v["ouverture"] > 0.0:
		var dir := Vector2(cos(cap), sin(cap))
		var w: float = ri * (0.3 + 0.5 * v["ouverture"])
		for s in range(0, int(R) + 2):
			var c := dir * s
			for x in range(floori(c.x - w), ceili(c.x + w) + 1):
				for z in range(floori(c.y - w), ceili(c.y + w) + 1):
					if Vector2(x, z).distance_to(c) <= w:
						var bas := -int(round(P * maxf(0.0, 1.0 - s / (R + 1.0))))
						for y in range(bas, int(B) + 5):
							b.vider(x, y, z)
