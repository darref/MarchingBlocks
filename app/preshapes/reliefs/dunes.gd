extends "res://app/preshapes/forme.gd"
## LE CHAMP DE DUNES : des vagues de sable, douces au vent, raides sous le vent, qui ondulent et s'effacent au bord.


func _init() -> void:
	id = "dunes"
	nom = "Dune field"
	famille = "reliefs"
	aide = "Waves of sand, gentle on the windward side and steep on the lee, fading at the edge."


func facteurs() -> Array:
	return [
		f("largeur", "Width", 8, 128, 60, "Across x."),
		f("profondeur", "Depth", 8, 128, 60, "Across z."),
		f("hauteur", "Height", 1, 16, 5, "The highest crest."),
		f("longueur_onde", "Spacing", 4, 40, 14, "From one crest to the next, in cells."),
		f("vent", "Wind", 0, 7, 0, "The direction the crests face (eighths of a turn)."),
		f("ondulation", "Wobble", 0.0, 1.0, 0.5, "Straight ridges (0) or winding, broken crests (1).", 0.01),
		f("raideur", "Lee slope", 0.0, 1.0, 0.7, "How sharp the lee side drops.", 0.01),
		f("bord", "Soft edge", 0.0, 1.0, 0.5, "How wide the edge where the dunes fade.", 0.01),
	]


func packs() -> Array:
	return [
		["Sand sea", {"largeur": 110, "profondeur": 110, "hauteur": 7, "longueur_onde": 18}],
		["Ripples", {"hauteur": 2, "longueur_onde": 6, "ondulation": 0.3}],
		["Barchan", {"largeur": 30, "profondeur": 30, "hauteur": 8, "longueur_onde": 30, "bord": 0.9}],
	]


func construire(v: Dictionary, b: Bati, rng: RandomNumberGenerator) -> void:
	var rx: float = v["largeur"] * 0.5
	var rz: float = v["profondeur"] * 0.5
	var a: float = v["vent"] * TAU / 8.0
	var dir := Vector2(cos(a), sin(a))
	var n_ond := bruit(rng, 0.04, 2)
	var n_h := bruit(rng, 0.05, 2)
	var lambda: float = v["longueur_onde"]
	for x in range(-ceili(rx), ceili(rx) + 1):
		for z in range(-ceili(rz), ceili(rz) + 1):
			var q := Vector2(x / rx, z / rz).length()
			if q >= 1.0:
				continue
			var bord := smoothstep(1.0, 1.0 - maxf(v["bord"], 0.05), q)
			var u: float = Vector2(x, z).dot(dir) / lambda + v["ondulation"] * 1.5 * n_ond.get_noise_2d(x, z)
			var w := u - floorf(u)
			# Une dent de scie adoucie : la montée douce (au vent), la chute raide (sous le vent).
			var sommet := lerpf(0.5, 0.92, v["raideur"])
			var profil := smoothstep(0.0, sommet, w) if w < sommet else 1.0 - smoothstep(sommet, 1.0, w)
			var h: float = v["hauteur"] * profil * bord * (0.7 + 0.3 * n_h.get_noise_2d(x, z))
			var hi := int(round(h))
			if hi >= 1:
				b.colonne(x, z, 0, hi - 1, "sable", "sable")
