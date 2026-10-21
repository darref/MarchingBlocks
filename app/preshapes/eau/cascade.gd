extends "res://app/preshapes/forme.gd"
## LES BASSINS EN CASCADE : des vasques creusées dans des paliers qui descendent ; posez une source dans la plus haute
## (Fluids), l'eau déborde de l'une dans l'autre.


func _init() -> void:
	id = "cascade"
	nom = "Cascade pools"
	famille = "eau"
	aide = "Basins carved into descending steps; set a water source in the top one (Fluids) and it spills down."


func facteurs() -> Array:
	return [
		f("bassins", "Pools", 2, 10, 5, "How many basins."),
		f("largeur", "Pool width", 3, 24, 8, "Each basin, across."),
		f("chute", "Drop", 1, 8, 2, "From one basin to the next, in cells."),
		f("creux", "Pool depth", 1, 4, 1, "How deep each basin is carved."),
		f("bord", "Rim", 1, 4, 1, "The rock rim around each basin."),
		f("tourne", "Turn", 0.0, 1.0, 0.3, "Straight down (0) or turning as it descends (1).", 0.01),
		choix("dessus", "Terraces", ["Rock", "Grass", "Sand"], 0, "The material of the rims."),
	]


func packs() -> Array:
	return [
		["Travertine pools", {"bassins": 7, "largeur": 9, "chute": 1, "tourne": 0.5, "dessus": 0}],
		["Jungle falls", {"bassins": 4, "largeur": 10, "chute": 4, "dessus": 1}],
		["Spiral springs", {"bassins": 8, "largeur": 6, "chute": 1, "tourne": 1.0}],
	]


func construire(v: Dictionary, b: Bati, rng: RandomNumberGenerator) -> void:
	var n := int(v["bassins"])
	var r: float = v["largeur"] * 0.5
	var bord := int(v["bord"])
	var dessus: String = ["roche", "sol", "sable"][int(v["dessus"])]
	var c := Vector2.ZERO
	var cap := rng.randf() * TAU
	var centres: Array = []
	for i in n:
		centres.append(c)
		cap += v["tourne"] * rng.randf_range(-1.2, 1.2)
		c += Vector2(cos(cap), sin(cap)) * (r * 1.4 + bord)
	var milieu := Vector2.ZERO
	for p in centres:
		milieu += p
	milieu /= n
	for i in n:
		var p: Vector2 = centres[i] - milieu
		var haut_ := (n - 1 - i) * int(v["chute"]) + int(v["creux"])
		var R := r + bord
		for x in range(floori(p.x - R), ceili(p.x + R) + 1):
			for z in range(floori(p.y - R), ceili(p.y + R) + 1):
				var d := Vector2(x, z).distance_to(p)
				if d > R:
					continue
				b.colonne(x, z, 0, haut_, dessus, "roche")
		b.vider_cylindre(p.x, p.y, r - 0.5, haut_ - int(v["creux"]) + 1, haut_)
		# Le déversoir : une encoche dans le bord, vers le bassin suivant.
		if i < n - 1:
			var vers: Vector2 = (centres[i + 1] - centres[i]).normalized()
			for s in range(int(r - 1), int(R) + 2):
				var q := p + vers * s
				b.vider(roundi(q.x), haut_, roundi(q.y))
