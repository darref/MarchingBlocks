extends "res://app/preshapes/forme.gd"
## L'ÎLOT ET L'ARCHIPEL : des îles posées sur le fond (à viser sous l'eau, ou à noyer ensuite dans Fluids), leurs plages,
## leur cœur vert, un rocher au sommet.


func _init() -> void:
	id = "archipel"
	nom = "Islets, archipelago"
	famille = "reliefs"
	aide = "Islands with beaches and green hearts, set on the sea floor; one islet or a scattered archipelago."


func facteurs() -> Array:
	return [
		f("nombre", "Islands", 1, 16, 5, "How many islands."),
		f("etendue", "Spread", 0, 120, 60, "How far apart they scatter."),
		f("taille", "Size", 4, 48, 18, "The width of the largest island."),
		f("hauteur", "Height", 2, 32, 8, "The highest point, counted from the floor you aim at."),
		f("eau", "Sea level", 0, 24, 4, "Below this height the island is beach: aim at the sea floor, set the sea in Fluids."),
		f("plage", "Beach", 0, 8, 2, "How high the sand climbs above the sea level."),
		f("decoupe", "Ragged coast", 0.0, 1.0, 0.5, "Round (0) or jagged (1) coasts.", 0.01),
	]


func packs() -> Array:
	return [
		["Lone islet", {"nombre": 1, "taille": 14, "hauteur": 7}],
		["Archipelago", {"nombre": 9, "etendue": 100, "taille": 22}],
		["Rocky skerries", {"nombre": 12, "taille": 6, "hauteur": 6, "plage": 0, "decoupe": 0.9}],
	]


func construire(v: Dictionary, b: Bati, rng: RandomNumberGenerator) -> void:
	var n_cote := bruit(rng, 0.12, 3)
	var mer := int(v["eau"])
	var bandes := [[0, "sable"], [mer + int(v["plage"]) + 1, "sol"], [int(round(v["hauteur"] * 0.8)), "roche"]]
	b.bandes = bandes
	var champ := {}
	for i in int(v["nombre"]):
		var c := Vector2.ZERO if i == 0 else Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)) * float(v["etendue"])
		var t := 1.0 if i == 0 else rng.randf_range(0.35, 0.9)
		var R: float = v["taille"] * 0.5 * t
		var H: float = v["hauteur"] * (0.6 + 0.4 * t)
		for x in range(floori(c.x - R * 1.3), ceili(c.x + R * 1.3) + 1):
			for z in range(floori(c.y - R * 1.3), ceili(c.y + R * 1.3) + 1):
				var d: float = Vector2(x - c.x, z - c.y).length() / R + v["decoupe"] * 0.35 * n_cote.get_noise_2d(x, z)
				if d >= 1.0:
					continue
				var h := H * pow(1.0 - d, 0.8)
				var k := Vector2i(x, z)
				champ[k] = maxf(float(champ.get(k, 0.0)), h)
	for k in champ:
		var hi := int(round(float(champ[k])))
		if hi >= 1:
			b.colonne(k.x, k.y, 0, hi - 1, Bati.par_hauteur(hi, bandes), "sable" if hi <= mer + 1 else "roche")
