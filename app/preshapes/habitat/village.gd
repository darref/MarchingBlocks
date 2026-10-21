extends "res://app/preshapes/forme.gd"
## LE VILLAGE : des maisons autour d'une place pavée, tournées vers elle, reliées par des rues ; un puits au milieu.

const Maison := preload("res://app/preshapes/habitat/maison.gd")


func _init() -> void:
	id = "village"
	nom = "Village"
	famille = "habitat"
	aide = "Houses around a paved square, facing it, linked by streets; a well in the middle."


func facteurs() -> Array:
	return [
		f("maisons", "Houses", 2, 30, 10, "How many houses."),
		f("etendue", "Spread", 16, 128, 56, "The village's width."),
		f("place", "Square", 0, 24, 10, "The paved square's width; 0: none."),
		f("taille_min", "Smallest", 3, 16, 5, "The smallest house."),
		f("taille_max", "Largest", 3, 24, 9, "The largest house."),
		f("hauteur", "Wall height", 2, 8, 3, "Walls of every house."),
		f("etages_max", "Max floors", 1, 4, 2, "Some houses get up to this many floors."),
		coche("rues", "Streets", true, "Paved streets from each door to the square."),
		coche("puits", "Well", true, "A well in the middle of the square."),
	]


func packs() -> Array:
	return [
		["Hamlet", {"maisons": 5, "etendue": 36, "place": 6}],
		["Market town", {"maisons": 22, "etendue": 100, "place": 18, "etages_max": 3}],
		["Farmstead", {"maisons": 3, "etendue": 24, "place": 0, "rues": false, "puits": false, "taille_max": 12}],
	]


func construire(v: Dictionary, b: Bati, rng: RandomNumberGenerator) -> void:
	var E: float = v["etendue"] * 0.5
	var P := int(v["place"]) / 2
	var occupees: Array = []   # Rect2i
	if P > 0:
		b.boite(Vector3i(-P, -1, -P), Vector3i(P, -1, P), "chemin")
		occupees.append(Rect2i(-P - 1, -P - 1, 2 * P + 3, 2 * P + 3))
	var essais := 0
	var faites := 0
	while faites < int(v["maisons"]) and essais < 400:
		essais += 1
		var W := rng.randi_range(int(v["taille_min"]), maxi(int(v["taille_min"]), int(v["taille_max"])))
		var D := rng.randi_range(int(v["taille_min"]), maxi(int(v["taille_min"]), int(v["taille_max"])))
		var c := Vector2i(rng.randi_range(-int(E), int(E)), rng.randi_range(-int(E), int(E)))
		# La porte regarde la place : le quart de tour qui pointe le plus vers le centre.
		var quart := 0
		if absi(c.x) > absi(c.y):
			quart = 3 if c.x > 0 else 1
		else:
			quart = 2 if c.y > 0 else 0
		var w := W if quart % 2 == 0 else D
		var d := D if quart % 2 == 0 else W
		var r := Rect2i(c.x - w / 2 - 2, c.y - d / 2 - 2, w + 4, d + 4)
		var libre := true
		for o in occupees:
			if (o as Rect2i).intersects(r):
				libre = false
				break
		if not libre:
			continue
		occupees.append(r)
		var etages := rng.randi_range(1, int(v["etages_max"]))
		Maison.batir(b, c, {"largeur": W, "profondeur": D, "hauteur": v["hauteur"], "etages": etages,
			"toit": rng.randi_range(0, 1), "debord": 1, "creuse": true, "fenetres": true}, quart)
		faites += 1
		if v["rues"]:
			# Une rue d'une case de large, de la porte vers la place, posée dans le sol (au niveau −1).
			# Devant la porte (`Maison.batir` : x0 = c.x − w/2, x1 = x0 + w − 1, de même en z).
			var x0 := c.x - w / 2
			var z0 := c.y - d / 2
			var porte: Vector2i = [Vector2i(c.x, z0 + d), Vector2i(x0 + w, c.y), Vector2i(c.x, z0 - 1),
				Vector2i(x0 - 1, c.y)][quart]
			var p := porte
			var pas := 0
			while maxi(absi(p.x), absi(p.y)) > P and pas < 200:
				for k in range(-1, 1):
					var q := p + (Vector2i(k, 0) if absi(p.x) < absi(p.y) else Vector2i(0, k))
					if not b.cases.has(Vector3i(q.x, 0, q.y)):
						b.case(q.x, -1, q.y, "chemin")
				if absi(p.x) > absi(p.y):
					p.x -= signi(p.x)
				else:
					p.y -= signi(p.y)
				pas += 1
	if v["puits"] and P >= 2:
		b.cylindre(0, 0, 1.5, 0, 0, "pierre", 0.6)
