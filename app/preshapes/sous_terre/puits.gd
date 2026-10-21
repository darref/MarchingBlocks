extends "res://app/preshapes/forme.gd"
## LE PUITS, LE GOUFFRE : un trou CREUSÉ droit dans le monde, évasé ou non, avec un escalier en colimaçon taillé dans sa
## paroi (des marches d'une case), et sa margelle.


func _init() -> void:
	id = "puits"
	nom = "Shaft, chasm"
	famille = "sous_terre"
	aide = "Digs a vertical hole into the world, with a spiral stair along its wall and a rim around the top."


func facteurs() -> Array:
	return [
		f("rayon", "Radius", 1, 24, 4, "At the bottom, in cells."),
		f("profondeur", "Depth", 2, 64, 16, "How deep it goes."),
		f("evasement", "Flare", 0.0, 2.0, 0.3, "Straight (0) or wider at the top (2).", 0.01),
		coche("escalier", "Spiral stair", true, "Steps of one cell along the wall, all the way down."),
		f("margelle", "Rim", 0, 4, 1, "A wall around the top, in cells high."),
		choix("matiere", "Rim material", ["Masonry", "Rock"], 0, "The rim and the stair."),
	]


func packs() -> Array:
	return [
		["Village well", {"rayon": 1, "profondeur": 8, "escalier": false, "margelle": 1, "evasement": 0.0}],
		["Chasm", {"rayon": 10, "profondeur": 40, "evasement": 1.2, "margelle": 0, "matiere": 1}],
		["Stepwell", {"rayon": 5, "profondeur": 14, "escalier": true, "margelle": 1}],
	]


func construire(v: Dictionary, b: Bati, _rng: RandomNumberGenerator) -> void:
	var r0: float = v["rayon"]
	var P := int(v["profondeur"])
	var mat: String = ["pierre", "roche"][int(v["matiere"])]
	var rayon_a := func(y: int) -> float: return r0 * (1.0 + v["evasement"] * float(y + P) / P)
	for y in range(-P, 1):
		b.vider_cylindre(0, 0, rayon_a.call(y) + 0.4, y, y)
	if v["escalier"] and r0 >= 2:
		# Une marche par case de hauteur, qui tourne le long de la paroi.
		for y in range(-P, 0):
			var r: float = rayon_a.call(y)
			var a := float(y + P) / maxf(r * 0.9, 1.0)
			for k in 2:
				var q := Vector2(cos(a), sin(a)) * (r - 0.5 - k)
				b.case(roundi(q.x), y, roundi(q.y), mat)
				b.case(roundi(q.x), y - 1, roundi(q.y), mat)
	var m := int(v["margelle"])
	if m > 0:
		var r: float = rayon_a.call(0)
		b.cylindre(0, 0, r + 1.5, 0, m - 1, mat, r + 0.4)
