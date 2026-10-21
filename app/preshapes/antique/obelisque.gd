extends "res://app/preshapes/forme.gd"
## L'OBÉLISQUE ET LE MENHIR : un fût qui s'effile sur son socle à marches, coiffé d'un pyramidion ; ou une pierre levée,
## brute.


func _init() -> void:
	id = "obelisque"
	nom = "Obelisk, monolith"
	famille = "antique"
	aide = "A tapering shaft on a stepped base with a pyramid cap; or a rough standing stone."


func facteurs() -> Array:
	return [
		f("hauteur", "Height", 4, 64, 20, "The shaft, in cells."),
		f("base", "Shaft width", 1, 9, 3, "At the foot of the shaft."),
		f("effile", "Taper", 0.0, 1.0, 0.4, "How much thinner it gets at the top.", 0.01),
		f("socle", "Plinth", 0, 6, 2, "Steps under the shaft."),
		f("pointe", "Cap", 0, 8, 2, "The pyramid cap on top."),
		f("brut", "Rough", 0.0, 1.0, 0.0, "A cut stone (0) or a raw standing stone (1).", 0.01),
	]


func packs() -> Array:
	return [
		["Egyptian obelisk", {"hauteur": 26, "base": 3, "effile": 0.35, "socle": 2, "pointe": 2}],
		["Standing stone", {"hauteur": 8, "base": 2, "socle": 0, "pointe": 0, "brut": 0.8, "effile": 0.2}],
		["Monument", {"hauteur": 36, "base": 5, "socle": 4, "pointe": 3}],
	]


func construire(v: Dictionary, b: Bati, rng: RandomNumberGenerator) -> void:
	var S := int(v["socle"])
	var r0 := int(v["base"])
	for i in S:
		var r: int = r0 / 2 + 1 + (S - i)
		b.boite(Vector3i(-r, i, -r), Vector3i(r, i, r), "pierre")
	var role := "roche" if v["brut"] > 0.5 else "pierre"
	var n := bruit(rng, 0.3, 2)
	var H := int(v["hauteur"])
	# Le fût, centré sur la case 0 : une demi-largeur entière (les largeurs paires s'arrondissent à l'impaire).
	var rt := 0
	for y in H:
		var r := int(round(maxf(0.0, (r0 - 1) * 0.5 * (1.0 - v["effile"] * float(y) / H))))
		rt = r
		for x in range(-r, r + 1):
			for z in range(-r, r + 1):
				if v["brut"] > 0.0 and r > 0 and (absi(x) == r or absi(z) == r) and n.get_noise_3d(x, y, z) > 1.0 - v["brut"]:
					continue
				b.case(x, S + y, z, role)
	for k in int(v["pointe"]):
		var r := maxi(0, rt - k)
		b.boite(Vector3i(-r, S + H + k, -r), Vector3i(r, S + H + k, r), role)
		if r == 0:
			break
