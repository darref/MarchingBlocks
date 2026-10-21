extends "res://app/preshapes/forme.gd"
## LES TERRASSES DE CULTURE : une colline taillée en paliers plats qui suivent ses courbes de niveau, chaque palier
## bordé d'un muret (pour retenir l'eau des rizières : Fluids la pose).


func _init() -> void:
	id = "terrasses"
	nom = "Farm terraces"
	famille = "reliefs"
	aide = "A hill cut into flat steps that follow its contours, each rimmed by a low wall: rice paddies, vineyards."


func facteurs() -> Array:
	return [
		f("largeur", "Width", 8, 96, 44, "Across x."),
		f("profondeur", "Depth", 8, 96, 36, "Across z."),
		f("hauteur", "Height", 2, 40, 14, "The top terrace."),
		f("marche", "Step", 1, 6, 2, "The height of each terrace, in cells."),
		f("sinuosite", "Winding", 0.0, 1.0, 0.5, "Straight terraces (0) or winding contours (1).", 0.01),
		coche("murets", "Rims", true, "A one-cell rim at the edge of each terrace, to hold water."),
		choix("dessus", "Fields", ["Second ground", "Grass", "Sand"], 0, "The material of the flat fields."),
	]


func packs() -> Array:
	return [
		["Rice terraces", {"marche": 1, "hauteur": 12, "sinuosite": 0.8}],
		["Vineyard slope", {"murets": false, "dessus": 1, "marche": 2, "sinuosite": 0.3}],
		["Stepped hill", {"murets": false, "marche": 3, "hauteur": 18, "sinuosite": 0.1}],
	]


func construire(v: Dictionary, b: Bati, rng: RandomNumberGenerator) -> void:
	var rx: float = v["largeur"] * 0.5
	var rz: float = v["profondeur"] * 0.5
	var H: float = v["hauteur"]
	var m := int(v["marche"])
	var n := bruit(rng, 0.06, 2)
	var dessus: String = ["sol2", "sol", "sable"][int(v["dessus"])]
	var paliers := {}
	for x in range(-ceili(rx), ceili(rx) + 1):
		for z in range(-ceili(rz), ceili(rz) + 1):
			var d: float = Vector2(x / rx, z / rz).length() + v["sinuosite"] * 0.25 * n.get_noise_2d(x, z)
			if d >= 1.0:
				continue
			var h := H * (1.0 - d)
			var hi := int(floor(h / m)) * m
			if hi >= 1:
				paliers[Vector2i(x, z)] = hi
	for k in paliers:
		var hi: int = paliers[k]
		b.colonne(k.x, k.y, 0, hi - 1, dessus, "sol")
	if v["murets"]:
		# Le muret : le bord extérieur de chaque palier (une voisine plus basse) monte d'une case.
		for k in paliers:
			var hi: int = paliers[k]
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if int(paliers.get(k + d, 0)) < hi:
					b.case(k.x, hi, k.y, "sol")
					break
