extends "res://app/preshapes/forme.gd"
## LA CHAÎNE DE MONTAGNES le long d'une courbe : des sommets semés sur le tracé, des cols entre eux, le versant qui
## retombe des deux côtés.


func _init() -> void:
	id = "chaine"
	nom = "Mountain range"
	famille = "reliefs"
	aide = "Summits and passes along a curved line; a wall of mountains that splits a map."


func facteurs() -> Array:
	return [
		f("longueur", "Length", 16, 128, 80, "Along the line, in cells."),
		f("pli", "Bend", -40, 40, 12, "How far the middle of the line bows to the side, in cells."),
		f("largeur", "Width", 6, 48, 24, "Across the line, at the foot."),
		f("hauteur", "Height", 4, 56, 24, "The highest summit."),
		f("sommets", "Summits", 1, 12, 5, "How many summits along the line."),
		f("cols", "Passes", 0.0, 1.0, 0.45, "How deep the passes between summits drop (share of the height).", 0.01),
		f("pente", "Steepness", 0.4, 3.0, 1.2, "Concave (high) or bulging (low) flanks.", 0.01),
		f("erosion", "Erosion", 0.0, 1.0, 0.3, "Gullies cut into the flanks.", 0.01),
		f("roche", "Rock line", 0.0, 1.0, 0.4, "Where grass gives way to rock.", 0.01),
		f("neige", "Snow line", 0.0, 1.0, 0.8, "Where rock gives way to snow; 1: no snow.", 0.01),
	]


func packs() -> Array:
	return [
		["Alpine ridge", {"hauteur": 40, "sommets": 7, "neige": 0.7, "largeur": 30}],
		["Low hills line", {"hauteur": 10, "cols": 0.2, "roche": 0.9, "neige": 1.0, "pente": 0.8}],
		["Crescent", {"pli": 36, "longueur": 100, "sommets": 6}],
		["Sawtooth", {"cols": 0.85, "sommets": 10, "pente": 2.0, "erosion": 0.6}],
	]


func construire(v: Dictionary, b: Bati, rng: RandomNumberGenerator) -> void:
	var L: float = v["longueur"]
	var pli: float = v["pli"]
	var demi: float = v["largeur"] * 0.5
	var H: float = v["hauteur"]
	var n := int(v["sommets"])
	var n_ero := bruit(rng, 0.09, 4)
	var hauteurs: Array = []
	for i in n:
		hauteurs.append(rng.randf_range(0.7, 1.0))
	hauteurs[rng.randi() % n] = 1.0
	var bandes := [[0, "sol"], [int(round(H * v["roche"])), "roche"], [int(round(H * v["neige"])) + (0 if v["neige"] < 1.0 else 999), "neige"]]
	b.bandes = bandes
	var champ := {}   # Vector2i → hauteur
	# Un échantillon tous les ~tiers de demi-largeur : assez serré pour un versant lisse, pas un par case.
	var pas := int(ceil(L * 1.2 / maxf(1.0, demi * 0.3)))
	for s in pas + 1:
		var t := float(s) / pas
		# Le long du tracé : un sommet à chaque 1/n, des cols entre eux.
		var u := t * n - 0.5
		var i0 := clampi(floori(u), 0, n - 1)
		var i1 := clampi(i0 + 1, 0, n - 1)
		var w := u - floorf(u)
		var crete: float = lerpf(hauteurs[i0], hauteurs[i1], smoothstep(0.0, 1.0, w))
		crete *= 1.0 - v["cols"] * sin(PI * clampf(w, 0.0, 1.0))
		crete *= smoothstep(0.0, 0.08, t) * smoothstep(1.0, 0.92, t)
		var p := courbe(t, L, pli)
		var r := demi * (0.6 + 0.4 * crete)
		for x in range(floori(p.x - r), ceili(p.x + r) + 1):
			for z in range(floori(p.y - r), ceili(p.y + r) + 1):
				var d := Vector2(x, z).distance_to(p) / r
				if d >= 1.0:
					continue
				var h := pow(1.0 - d, v["pente"]) * crete * H
				var k := Vector2i(x, z)
				if h > float(champ.get(k, 0.0)):
					champ[k] = h
	for k in champ:
		var h: float = champ[k]
		champ[k] = h - v["erosion"] * (0.5 + 0.5 * n_ero.get_noise_2d(k.x, k.y)) * minf(h, H * 0.3)
	b.relief(Bati.lisser(champ, 1), bandes)
