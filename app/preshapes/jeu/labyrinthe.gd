extends "res://app/preshapes/forme.gd"
## LE LABYRINTHE : un labyrinthe parfait (un seul chemin entre deux points, tiré par la graine), ses murs de pierre ou de
## haie, une entrée et une sortie ; des boucles en option.


func _init() -> void:
	id = "labyrinthe"
	nom = "Maze"
	famille = "jeu"
	aide = "A perfect maze drawn by the seed, stone or hedge walls, an entrance and an exit; extra loops if you want."


func facteurs() -> Array:
	return [
		f("colonnes", "Columns", 3, 30, 10, "Cells of the maze across x."),
		f("rangees", "Rows", 3, 30, 10, "Cells of the maze across z."),
		f("couloir", "Corridor", 1, 5, 2, "The width of a corridor."),
		f("mur", "Wall", 1, 3, 1, "The thickness of a wall."),
		f("hauteur", "Height", 2, 12, 3, "The walls."),
		f("boucles", "Loops", 0.0, 1.0, 0.0, "A perfect maze (0) or walls knocked down for loops (1).", 0.01),
		choix("matiere", "Walls", ["Hedge", "Stone"], 0, "Second ground (a hedge) or masonry."),
	]


func packs() -> Array:
	return [
		["Hedge maze", {}],
		["Stone labyrinth", {"matiere": 1, "hauteur": 5, "colonnes": 14, "rangees": 14}],
		["Arena maze", {"boucles": 0.35, "couloir": 3, "colonnes": 8, "rangees": 8}],
	]


func construire(v: Dictionary, b: Bati, rng: RandomNumberGenerator) -> void:
	var nx := int(v["colonnes"])
	var nz := int(v["rangees"])
	var c := int(v["couloir"])
	var m := int(v["mur"])
	var H := int(v["hauteur"])
	var role: String = ["sol2", "pierre"][int(v["matiere"])]
	var pas := c + m
	var W := nx * pas + m
	var D := nz * pas + m
	var x0 := -W / 2
	var z0 := -D / 2
	# Tout plein, puis on creuse les cellules et les passages (le retour sur trace).
	var plein := {}
	for x in W:
		for z in D:
			plein[Vector2i(x, z)] = true
	var vues := {}
	var pile: Array = [Vector2i(0, 0)]
	vues[Vector2i(0, 0)] = true
	var ouvrir := func(cel: Vector2i) -> void:
		for dx in c:
			for dz in c:
				plein.erase(Vector2i(m + cel.x * pas + dx, m + cel.y * pas + dz))
	var percer := func(a: Vector2i, d: Vector2i) -> void:
		for k in c:
			for e in m:
				if d.x != 0:
					plein.erase(Vector2i(m + a.x * pas + (c if d.x > 0 else -m) + e, m + a.y * pas + k))
				else:
					plein.erase(Vector2i(m + a.x * pas + k, m + a.y * pas + (c if d.y > 0 else -m) + e))
	ouvrir.call(Vector2i(0, 0))
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not pile.is_empty():
		var a: Vector2i = pile.back()
		var libres: Array = []
		for d in dirs:
			var n_: Vector2i = a + d
			if n_.x >= 0 and n_.y >= 0 and n_.x < nx and n_.y < nz and not vues.has(n_):
				libres.append(d)
		if libres.is_empty():
			pile.pop_back()
			continue
		var d: Vector2i = libres[rng.randi() % libres.size()]
		percer.call(a, d)
		vues[a + d] = true
		ouvrir.call(a + d)
		pile.append(a + d)
	# Des boucles : des murs intérieurs abattus au hasard.
	var n_boucles := int(v["boucles"] * nx * nz * 0.3)
	for i in n_boucles:
		var a := Vector2i(rng.randi_range(0, nx - 2), rng.randi_range(0, nz - 2))
		percer.call(a, dirs[rng.randi() % 2 * 2])
	# L'entrée (en bas) et la sortie (en haut).
	percer.call(Vector2i(0, 0), Vector2i(0, -1))
	percer.call(Vector2i(nx - 1, nz - 1), Vector2i(0, 1))
	for k in plein:
		b.boite(Vector3i(x0 + k.x, 0, z0 + k.y), Vector3i(x0 + k.x, H - 1, z0 + k.y), role)
