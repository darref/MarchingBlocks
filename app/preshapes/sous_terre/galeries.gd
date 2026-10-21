extends "res://app/preshapes/forme.gd"
## LE RÉSEAU DE GALERIES ET LE DONJON DE SALLES : des salles CREUSÉES sous terre, reliées par des galeries de trois cases
## de haut (le personnage y passe), en arbre ou en boucles ; une entrée qui remonte au jour.


func _init() -> void:
	id = "galeries"
	nom = "Tunnels, dungeon"
	famille = "sous_terre"
	aide = "Rooms dug underground, linked by galleries three cells high; round caves or a square-roomed dungeon."


func facteurs() -> Array:
	return [
		choix("style", "Style", ["Caves", "Dungeon"], 0, "Round rooms and winding tunnels, or square rooms and straight corridors."),
		f("salles", "Rooms", 2, 16, 6, "How many rooms."),
		f("etendue", "Spread", 12, 120, 48, "The width of the network."),
		f("taille", "Room size", 3, 20, 8, "The width of a room."),
		f("largeur", "Gallery width", 1, 5, 2, "The width of a gallery (three cells high)."),
		f("enfouie", "Depth", 4, 40, 8, "How far under the ground you aim at."),
		f("boucles", "Loops", 0.0, 1.0, 0.3, "A tree of galleries (0), or extra links that loop (1).", 0.01),
		coche("entree", "Entrance", true, "A stair ramp from the first room up to the surface."),
	]


func packs() -> Array:
	return [
		["Cave network", {"salles": 8, "etendue": 70}],
		["Dungeon", {"style": 1, "salles": 9, "taille": 7, "largeur": 2, "boucles": 0.4}],
		["Mine", {"salles": 5, "taille": 4, "largeur": 1, "boucles": 0.0, "enfouie": 14}],
	]


func construire(v: Dictionary, b: Bati, rng: RandomNumberGenerator) -> void:
	var donjon := int(v["style"]) == 1
	var E: float = v["etendue"] * 0.5
	var sol := -int(v["enfouie"]) - 3
	var T: float = v["taille"]
	var salles: Array = []
	for i in int(v["salles"]):
		var p := Vector2.ZERO if i == 0 else Vector2(rng.randf_range(-E, E), rng.randf_range(-E, E))
		salles.append(Vector2i(roundi(p.x), roundi(p.y)))
	for s in salles:
		var t := T * rng.randf_range(0.7, 1.2)
		var h := 3 + int(t * 0.3)
		if donjon:
			b.vider_boite(Vector3i(s.x - int(t / 2), sol, s.y - int(t / 2)), Vector3i(s.x + int(t / 2), sol + h, s.y + int(t / 2)))
		else:
			b.ellipsoide(Vector3(s.x, sol, s.y), Vector3(t * 0.5, h, t * 0.5), "", false)
			b.vider_boite(Vector3i(s.x - int(t * 0.35), sol, s.y - int(t * 0.35)), Vector3i(s.x + int(t * 0.35), sol + 2, s.y + int(t * 0.35)))
	# L'arbre couvrant le plus court (Prim), puis des boucles.
	var liens: Array = []
	var dans := {0: true}
	while dans.size() < salles.size():
		var meilleur := []
		var dmin := INF
		for i in dans:
			for j in salles.size():
				if dans.has(j):
					continue
				var d := Vector2(salles[i]).distance_to(Vector2(salles[j]))
				if d < dmin:
					dmin = d
					meilleur = [i, j]
		dans[meilleur[1]] = true
		liens.append(meilleur)
	for i in salles.size():
		if rng.randf() < v["boucles"] * 0.6:
			var j := rng.randi() % salles.size()
			if j != i:
				liens.append([i, j])
	var w := int(v["largeur"])
	for l in liens:
		var a: Vector2i = salles[l[0]]
		var c: Vector2i = salles[l[1]]
		# En L : d'abord x, puis z (le donjon droit, la grotte avec un coude aléatoire).
		var coude := Vector2i(c.x, a.y) if donjon or rng.randf() < 0.5 else Vector2i(a.x, c.y)
		for seg in [[a, coude], [coude, c]]:
			var p: Vector2i = seg[0]
			var q: Vector2i = seg[1]
			b.vider_boite(Vector3i(mini(p.x, q.x) - w / 2, sol, mini(p.y, q.y) - w / 2),
				Vector3i(maxi(p.x, q.x) + (w - 1) / 2, sol + 2, maxi(p.y, q.y) + (w - 1) / 2))
	if v["entree"]:
		var s0: Vector2i = salles[0]
		var x := s0.x
		var y := sol
		while y < 1:
			b.vider_boite(Vector3i(x, y, s0.y - 1), Vector3i(x, y + 2, s0.y))
			x -= 1
			y += 1
