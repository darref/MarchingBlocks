extends "res://app/preshapes/forme.gd"
## L'ATOLL ET LE LAGON : un anneau de sable et de verdure, des passes qui l'ouvrent, et le lagon CREUSÉ au milieu (l'eau
## de Fluids le remplit).


func _init() -> void:
	id = "atoll"
	nom = "Atoll, lagoon"
	famille = "eau"
	aide = "A ring of sand and green with passes through it, around a lagoon dug in the middle; fill it in Fluids."


func facteurs() -> Array:
	return [
		f("largeur", "Width", 12, 128, 60, "Across the whole ring."),
		f("anneau", "Ring width", 2, 24, 7, "How wide the land ring is."),
		f("hauteur", "Height", 1, 8, 2, "The ring above the ground you aim at."),
		f("lagon", "Lagoon depth", 0, 16, 4, "How deep the lagoon is dug."),
		f("passes", "Passes", 0, 6, 2, "Gaps in the ring where the sea gets in."),
		f("ilot", "Center islet", 0, 16, 0, "An islet in the middle of the lagoon (its width)."),
		f("decoupe", "Ragged", 0.0, 1.0, 0.5, "A round ring (0) or a broken, uneven one (1).", 0.01),
	]


func packs() -> Array:
	return [
		["Coral atoll", {"largeur": 80, "anneau": 8, "passes": 3}],
		["Lagoon pool", {"largeur": 24, "anneau": 4, "lagon": 3, "passes": 0}],
		["Islet in a lagoon", {"largeur": 50, "ilot": 10, "passes": 1}],
	]


func construire(v: Dictionary, b: Bati, rng: RandomNumberGenerator) -> void:
	var R: float = v["largeur"] * 0.5
	var A: float = v["anneau"]
	var n := bruit(rng, 0.1, 2)
	var caps: Array = []
	for i in int(v["passes"]):
		caps.append(rng.randf() * TAU)
	var H := int(v["hauteur"])
	for x in range(-ceili(R), ceili(R) + 1):
		for z in range(-ceili(R), ceili(R) + 1):
			var d: float = Vector2(x, z).length() + v["decoupe"] * 3.0 * n.get_noise_2d(x, z)
			if d > R:
				continue
			var ang := atan2(z, x)
			var passe := false
			for c in caps:
				if absf(wrapf(ang - float(c), -PI, PI)) * d < 2.0:
					passe = true
			if d >= R - A and not passe:
				var milieu := 1.0 - absf((d - (R - A * 0.5)) / (A * 0.5))
				var hi := maxi(1, int(round(H * (0.4 + 0.6 * milieu))))
				b.colonne(x, z, 0, hi - 1, "sol" if hi >= H and H >= 2 else "sable", "sable")
			elif d < float(v["ilot"]) * 0.5:
				b.colonne(x, z, 0, H - 1, "sol" if H >= 2 else "sable", "sable")
			else:
				var fond := -int(round(v["lagon"] * smoothstep(R - A, R - A - 4.0, d)))
				for y in range(fond, H + 2):
					b.vider(x, y, z)
