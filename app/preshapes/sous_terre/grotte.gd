extends "res://app/preshapes/forme.gd"
## LA GROTTE : une salle CREUSÉE sous le sol visé, voûtée et irrégulière, ses piliers, et son entrée (une rampe en
## marches d'une case, ou un puits).


func _init() -> void:
	id = "grotte"
	nom = "Cave room"
	famille = "sous_terre"
	aide = "Digs a vaulted, irregular hall under the ground you aim at, with pillars and an entrance."


func facteurs() -> Array:
	return [
		f("largeur", "Width", 4, 64, 22, "Across x."),
		f("profondeur", "Depth", 4, 64, 18, "Across z."),
		f("hauteur", "Height", 3, 32, 8, "Floor to vault."),
		f("enfouie", "Buried", 1, 48, 6, "Rock between the vault and the ground above."),
		f("irregularite", "Rough walls", 0.0, 1.0, 0.5, "Smooth dome (0) or broken, lumpy walls (1).", 0.01),
		f("piliers", "Pillars", 0, 12, 2, "Rock pillars from floor to vault."),
		choix("entree", "Entrance", ["None", "Stair ramp", "Shaft"], 1, "How you get in from the surface."),
	]


func packs() -> Array:
	return [
		["Cavern hall", {"largeur": 40, "profondeur": 32, "hauteur": 12, "piliers": 4}],
		["Grotto", {"largeur": 12, "profondeur": 10, "hauteur": 5, "enfouie": 3}],
		["Hidden chamber", {"entree": 2, "enfouie": 12}],
	]


func construire(v: Dictionary, b: Bati, rng: RandomNumberGenerator) -> void:
	var rx: float = v["largeur"] * 0.5
	var rz: float = v["profondeur"] * 0.5
	var H: float = v["hauteur"]
	var sol := -int(v["enfouie"]) - int(H)
	var n := bruit(rng, 0.14, 3)
	for x in range(-ceili(rx) - 2, ceili(rx) + 3):
		for z in range(-ceili(rz) - 2, ceili(rz) + 3):
			var d: float = Vector2(x / rx, z / rz).length() + v["irregularite"] * 0.25 * n.get_noise_2d(x, z)
			if d >= 1.0:
				continue
			# Un sol plat, une voûte en dôme.
			var h := int(round(H * sqrt(1.0 - d * d) + v["irregularite"] * 1.5 * n.get_noise_3d(x, 0, z)))
			for y in range(sol, sol + maxi(h, 3)):
				b.vider(x, y, z)
	for i in int(v["piliers"]):
		var p := Vector2(rng.randf_range(-0.55, 0.55) * rx, rng.randf_range(-0.55, 0.55) * rz)
		b.cylindre(p.x, p.y, rng.randf_range(1.0, 2.2), sol, sol + int(H) + 1, "roche")
	match int(v["entree"]):
		1:
			# Une rampe en marches d'une case, trois cases de haut, du bord de la salle jusqu'au jour.
			var x0 := int(rx) - 1
			var y := sol
			var x := x0
			while y < 1:
				for z in range(-1, 1):
					for dy in 3:
						b.vider(x, y + dy, z)
				x += 1
				y += 1
		2:
			b.vider_cylindre(0, 0, 1.6, sol, 2)
