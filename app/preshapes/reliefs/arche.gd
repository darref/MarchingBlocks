extends "res://app/preshapes/forme.gd"
## L'ARCHE NATURELLE ET LE PONT NATUREL : une voûte de roche qui enjambe le vide, ses piles enracinées, rongée par le
## vent.


func _init() -> void:
	id = "arche"
	nom = "Natural arch"
	famille = "reliefs"
	aide = "A wind-worn rock arch standing on two feet; low and wide, it becomes a natural bridge."


func facteurs() -> Array:
	return [
		f("portee", "Span", 4, 64, 20, "The opening, from foot to foot."),
		f("hauteur", "Height", 3, 48, 14, "Under the arch."),
		f("epaisseur", "Thickness", 1, 12, 4, "The rock band of the arch."),
		f("profondeur", "Depth", 1, 24, 5, "How thick the arch is, front to back."),
		f("pieds", "Feet", 0, 16, 5, "How much the feet widen into the ground."),
		f("usure", "Wear", 0.0, 1.0, 0.4, "Pitted, uneven rock.", 0.01),
	]


func packs() -> Array:
	return [
		["Delicate arch", {"portee": 14, "hauteur": 18, "epaisseur": 3, "profondeur": 3, "pieds": 4}],
		["Natural bridge", {"portee": 40, "hauteur": 10, "epaisseur": 6, "profondeur": 10, "pieds": 8}],
		["Sea arch", {"portee": 10, "hauteur": 12, "epaisseur": 5, "profondeur": 8, "usure": 0.7}],
	]


func construire(v: Dictionary, b: Bati, rng: RandomNumberGenerator) -> void:
	var a: float = v["portee"] * 0.5
	var h: float = v["hauteur"]
	var ep: float = v["epaisseur"]
	var pr := int(v["profondeur"])
	var pieds: float = v["pieds"]
	var n := bruit(rng, 0.2, 2)
	var ae := a + ep
	var he := h + ep
	for x in range(-ceili(ae + pieds), ceili(ae + pieds) + 1):
		for y in range(0, ceili(he) + 1):
			# Dans la bande entre l'ellipse intérieure (le vide) et l'extérieure ; les pieds s'évasent vers le sol.
			var evase := pieds * pow(maxf(0.0, 1.0 - float(y) / (h * 0.6)), 2.0)
			var dedans := pow(x / maxf(a - 0.01, 0.5), 2.0) + pow(y / h, 2.0) < 1.0
			var lx := absf(x) - evase
			var dehors := pow(maxf(lx, 0.0) / ae, 2.0) + pow(y / he, 2.0) > 1.0
			if dedans or dehors:
				continue
			for z in range(-pr / 2, pr - pr / 2):
				if v["usure"] > 0.0 and n.get_noise_3d(x, y, z) > 1.0 - v["usure"] * 0.6 and y > 1:
					continue
				b.case(x, y, z, "roche")
