extends "res://app/preshapes/forme.gd"
## L'ÎLE FLOTTANTE : un plateau d'herbe bosselé, porté par un cône de roche renversé et déchiqueté, suspendu au-dessus du
## sol visé (rien ne l'ancre).


func _init() -> void:
	id = "ile_flottante"
	nom = "Floating island"
	famille = "jeu"
	aide = "A bumpy grass top carried by a jagged upside-down cone of rock, hanging above the ground you aim at."


func facteurs() -> Array:
	return [
		f("rayon", "Radius", 3, 40, 12, "The island's top."),
		f("altitude", "Altitude", 2, 60, 16, "How high it floats above the aimed ground."),
		f("epaisseur", "Rock depth", 2, 40, 12, "How far the rock hangs below the top."),
		f("bosses", "Hills", 0, 12, 3, "Small hills on the top."),
		f("dechire", "Jagged", 0.0, 1.0, 0.6, "A smooth cone (0) or ragged, dripping rock (1).", 0.01),
		f("satellites", "Satellites", 0, 8, 2, "Small islets floating around it."),
	]


func packs() -> Array:
	return [
		["Sky island", {}],
		["Floating rock", {"rayon": 5, "epaisseur": 8, "bosses": 0, "satellites": 0}],
		["Sky archipelago", {"rayon": 14, "satellites": 7, "altitude": 24}],
	]


func construire(v: Dictionary, b: Bati, rng: RandomNumberGenerator) -> void:
	_ile(b, rng, Vector2.ZERO, v["rayon"], int(v["altitude"]), int(v["epaisseur"]), int(v["bosses"]), v["dechire"])
	for i in int(v["satellites"]):
		var a := rng.randf() * TAU
		var d: float = v["rayon"] * rng.randf_range(1.5, 2.4)
		var r: float = maxf(2.0, v["rayon"] * rng.randf_range(0.15, 0.3))
		_ile(b, rng, Vector2(cos(a), sin(a)) * d, r, int(v["altitude"]) + rng.randi_range(-6, 8),
			maxi(2, int(r * 1.4)), 0, v["dechire"])


func _ile(b: Bati, rng: RandomNumberGenerator, c: Vector2, R: float, alt: int, ep: int, bosses: int, dechire: float) -> void:
	var n := bruit(rng, 0.15, 3)
	var collines: Array = []
	for i in bosses:
		collines.append([c + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)) * R, rng.randf_range(2.0, 4.0),
			R * rng.randf_range(0.2, 0.4)])
	for x in range(floori(c.x - R) - 1, ceili(c.x + R) + 2):
		for z in range(floori(c.y - R) - 1, ceili(c.y + R) + 2):
			var d := Vector2(x, z).distance_to(c) / R + dechire * 0.15 * n.get_noise_2d(x, z)
			if d >= 1.0:
				continue
			# Le dessous : un cône renversé, déchiqueté.
			var prof := ep * pow(1.0 - d, 0.7) * (1.0 + dechire * 0.6 * n.get_noise_2d(x * 2.3, z * 2.3))
			var dessus := alt
			for h in collines:
				var dh := Vector2(x, z).distance_to(h[0]) / float(h[2])
				if dh < 1.0:
					dessus = maxi(dessus, alt + int(round(float(h[1]) * cos(dh * PI * 0.5))))
			b.colonne(x, z, alt - maxi(1, int(round(prof))), dessus, "sol", "roche")
