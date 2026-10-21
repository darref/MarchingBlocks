extends "res://app/preshapes/forme.gd"
## LA MAISON : des murs, une porte, des fenêtres, un toit à deux pentes, à quatre pentes ou plat, un débord ; pleine ou
## creuse (on y entre). Le village la réutilise (`batir`).


func _init() -> void:
	id = "maison"
	nom = "House"
	famille = "habitat"
	aide = "Walls, a door, windows and a gable, hip or flat roof with overhang; hollow so you can walk in."


func facteurs() -> Array:
	return [
		f("largeur", "Width", 3, 32, 9, "Across x."),
		f("profondeur", "Depth", 3, 32, 7, "Across z."),
		f("hauteur", "Wall height", 2, 16, 4, "Up to the roof."),
		f("etages", "Floors", 1, 4, 1, "Floors (each wall height again)."),
		choix("toit", "Roof", ["Gable", "Hip", "Flat"], 0, "The roof's shape."),
		f("debord", "Overhang", 0, 2, 1, "How far the roof runs past the walls."),
		coche("creuse", "Hollow", true, "A room inside, a door to walk in."),
		coche("fenetres", "Windows", true, "Window holes in the walls."),
	]


func packs() -> Array:
	return [
		["Cottage", {"largeur": 7, "profondeur": 6, "hauteur": 3}],
		["Town house", {"largeur": 8, "profondeur": 10, "etages": 3, "hauteur": 4, "debord": 0}],
		["Long hall", {"largeur": 22, "profondeur": 9, "hauteur": 4, "toit": 1}],
		["Flat-roof house", {"toit": 2, "debord": 0, "largeur": 8, "profondeur": 8}],
	]


func construire(v: Dictionary, b: Bati, _rng: RandomNumberGenerator) -> void:
	batir(b, Vector2i.ZERO, v, 0)


## Une maison centrée en `c`, tournée de `quart` quarts de tour (pour le village).
static func batir(b: Bati, c: Vector2i, v: Dictionary, quart: int) -> void:
	var W := int(v["largeur"])
	var D := int(v["profondeur"])
	if quart % 2 == 1:
		var t := W
		W = D
		D = t
	var x0 := c.x - W / 2
	var z0 := c.y - D / 2
	var x1 := x0 + W - 1
	var z1 := z0 + D - 1
	var H := int(v["hauteur"]) * int(v["etages"])
	var creuse: bool = v["creuse"] and W >= 3 and D >= 3
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			var mur := x == x0 or x == x1 or z == z0 or z == z1
			if mur or not creuse:
				b.boite(Vector3i(x, 0, z), Vector3i(x, H - 1, z), "pierre")
	if creuse:
		# Les planchers des étages.
		for e in range(1, int(v["etages"])):
			b.boite(Vector3i(x0, e * int(v["hauteur"]) - 1, z0), Vector3i(x1, e * int(v["hauteur"]) - 1, z1), "pierre")
		# La porte, au milieu d'une façade (selon le quart de tour).
		var porte: Vector2i = [Vector2i(c.x, z1), Vector2i(x1, c.y), Vector2i(c.x, z0), Vector2i(x0, c.y)][quart % 4]
		b.vider_boite(Vector3i(porte.x, 0, porte.y), Vector3i(porte.x, mini(1, H - 2), porte.y))
	if v["fenetres"] and int(v["hauteur"]) >= 3:
		for e in int(v["etages"]):
			var y := e * int(v["hauteur"]) + 1
			for x in range(x0 + 2, x1 - 1, 3):
				b.vider(x, y, z0)
				b.vider(x, y, z1)
			for z in range(z0 + 2, z1 - 1, 3):
				b.vider(x0, y, z)
				b.vider(x1, y, z)
	var o := int(v["debord"])
	match int(v["toit"]):
		0:
			# Deux pentes, le faîte le long du côté le plus long.
			var long_x := W >= D
			var demi := (D if long_x else W) / 2 + o
			for k in demi + 1:
				if long_x:
					b.boite(Vector3i(x0 - o, H + k, z0 - o + k), Vector3i(x1 + o, H + k, z1 + o - k), "toit")
				else:
					b.boite(Vector3i(x0 - o + k, H + k, z0 - o), Vector3i(x1 + o - k, H + k, z1 + o), "toit")
				if (z1 + o - k) - (z0 - o + k) <= 0 and long_x or (x1 + o - k) - (x0 - o + k) <= 0 and not long_x:
					break
		1:
			for k in maxi(W, D):
				var a := Vector3i(x0 - o + k, H + k, z0 - o + k)
				var bb := Vector3i(x1 + o - k, H + k, z1 + o - k)
				if a.x > bb.x or a.z > bb.z:
					break
				b.boite(a, bb, "toit")
		2:
			b.boite(Vector3i(x0 - o, H, z0 - o), Vector3i(x1 + o, H, z1 + o), "toit")
