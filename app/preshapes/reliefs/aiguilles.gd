extends "res://app/preshapes/forme.gd"
## LES AIGUILLES, LES CHEMINÉES DE FÉE, LES ORGUES DE BASALTE : un groupe de colonnes de roche. Les cheminées portent un
## chapeau d'une autre matière ; les orgues se serrent en prismes à hauteurs en marches.


func _init() -> void:
	id = "aiguilles"
	nom = "Spires, hoodoos"
	famille = "reliefs"
	aide = "A cluster of rock columns: needles, fairy chimneys with a cap, or tight basalt organs."


func facteurs() -> Array:
	return [
		choix("style", "Style", ["Needles", "Fairy chimneys", "Basalt organs"], 0, "The kind of column."),
		f("nombre", "Count", 1, 40, 9, "How many columns."),
		f("etendue", "Spread", 2, 80, 24, "The width of the cluster, in cells."),
		f("hauteur_min", "Min height", 2, 48, 8, "The shortest column."),
		f("hauteur_max", "Max height", 2, 64, 22, "The tallest column."),
		f("epaisseur", "Thickness", 1, 8, 2, "The radius at the foot, in cells."),
		f("effile", "Taper", 0.0, 1.0, 0.6, "Straight (0) or thinning to a point (1).", 0.01),
		f("socle", "Base mound", 0, 8, 2, "A rocky mound at the foot of the cluster."),
	]


func packs() -> Array:
	return [
		["Needle cluster", {"nombre": 12, "hauteur_max": 30, "effile": 0.85}],
		["Fairy chimneys", {"style": 1, "nombre": 7, "hauteur_min": 6, "hauteur_max": 14, "epaisseur": 2, "effile": 0.3}],
		["Basalt organs", {"style": 2, "nombre": 30, "etendue": 16, "hauteur_min": 6, "hauteur_max": 16}],
		["Lone spire", {"nombre": 1, "hauteur_min": 30, "hauteur_max": 30, "epaisseur": 3, "socle": 4}],
	]


func construire(v: Dictionary, b: Bati, rng: RandomNumberGenerator) -> void:
	var style := int(v["style"])
	var E: float = v["etendue"] * 0.5
	var hmin := int(v["hauteur_min"])
	var hmax := maxi(hmin, int(v["hauteur_max"]))
	if style == 2:
		# Les orgues : une grille serrée de prismes 1×1 dans un disque, la hauteur en marches depuis le centre.
		var marche := maxi(1, (hmax - hmin) / 4)
		for x in range(-ceili(E), ceili(E) + 1):
			for z in range(-ceili(E), ceili(E) + 1):
				var d := Vector2(x, z).length() / maxf(E, 1.0)
				if d > 1.0 or rng.randf() > float(v["nombre"]) / 40.0 + 0.4:
					continue
				var h := hmin + int(round(float(hmax - hmin) * (1.0 - d) * rng.randf_range(0.6, 1.0) / marche)) * marche
				b.colonne(x, z, 0, h - 1, "roche", "roche")
	else:
		for i in int(v["nombre"]):
			var c := Vector2.ZERO if i == 0 else Vector2(rng.randf_range(-E, E), rng.randf_range(-E, E))
			var h := rng.randi_range(hmin, hmax)
			var r0: float = v["epaisseur"] * rng.randf_range(0.8, 1.2)
			for y in h:
				var r := maxf(0.5, r0 * (1.0 - v["effile"] * float(y) / h))
				if style == 1:
					r = maxf(0.8, r0 * (1.0 - v["effile"] * 0.5 * float(y) / h))
				b.cylindre(c.x, c.y, r, y, y, "roche")
			if style == 1:
				b.cylindre(c.x, c.y, r0 * 1.2 + 0.6, h, h + 1, "sol2")
	var socle := int(v["socle"])
	if socle > 0:
		for x in range(-ceili(E) - socle * 2, ceili(E) + socle * 2 + 1):
			for z in range(-ceili(E) - socle * 2, ceili(E) + socle * 2 + 1):
				var d := Vector2(x, z).length() / (E + socle * 2.0)
				if d < 1.0:
					var hi := int(round(socle * (1.0 - d * d)))
					if hi >= 1:
						b.colonne(x, z, 0, hi - 1, "roche", "roche")
