extends "res://app/preshapes/forme.gd"
## LA VOÛTE, LE TUNNEL, LA GALERIE COUVERTE : une voûte en berceau qu'on extrude sur une longueur ; posée sur le sol (un
## passage couvert) ou CREUSÉE dans une colline (un tunnel, sa voûte en pierre).


func _init() -> void:
	id = "voute"
	nom = "Vault, tunnel"
	famille = "pures"
	aide = "A barrel vault drawn out along a length: a covered passage on the ground, or a stone-lined tunnel dug into a hill."


func facteurs() -> Array:
	return [
		f("longueur", "Length", 2, 96, 20, "Along z."),
		f("portee", "Span", 2, 24, 6, "The free width inside."),
		f("hauteur", "Height", 2, 24, 5, "The free height inside, at the crown."),
		f("epaisseur", "Thickness", 1, 4, 1, "The vault's shell."),
		choix("profil", "Profile", ["Round", "Pointed", "Flat"], 0, "The shape of the vault."),
		coche("creuser", "Dig through", true, "Also dig the inside through the world (a tunnel)."),
		f("pente", "Slope", -1.0, 1.0, 0.0, "Rises (or falls) along its length, in cells per cell — at most 1.", 0.05),
	]


func packs() -> Array:
	return [
		["Tunnel", {"longueur": 30, "portee": 4, "hauteur": 4}],
		["Cloister walk", {"longueur": 40, "portee": 4, "hauteur": 5, "creuser": false, "profil": 1}],
		["Sloped mine shaft", {"longueur": 24, "portee": 3, "hauteur": 3, "pente": -1.0, "profil": 2}],
	]


func construire(v: Dictionary, b: Bati, _rng: RandomNumberGenerator) -> void:
	var L := int(v["longueur"])
	var a: float = v["portee"] * 0.5
	var h: float = v["hauteur"]
	var ep: int = v["epaisseur"]
	var profil := int(v["profil"])
	# Le profil intérieur : la hauteur libre à l'écart x de l'axe.
	var interieur := func(x: float, aa: float, hh: float) -> float:
		if absf(x) > aa:
			return -1.0
		match profil:
			1:
				return hh * (1.0 - pow(absf(x) / aa, 1.6))
			2:
				return hh
		return hh * sqrt(maxf(0.0, 1.0 - pow(absf(x) / aa, 2.0)))
	for k in L:
		var z := k - L / 2
		var dy := int(round(v["pente"] * k))
		for xi in range(-ceili(a) - ep, ceili(a) + ep + 1):
			var x := float(xi)
			var hi: float = interieur.call(x, a, h)
			var he: float = interieur.call(x, a + ep, h + ep)
			for y in range(0, ceili(h) + ep + 1):
				var dedans := hi >= 0.0 and y < hi + 0.01
				var coque := he >= 0.0 and y < he + 0.01 and not dedans
				if coque:
					b.case(xi, y + dy, z, "pierre")
				elif dedans and v["creuser"]:
					b.vider(xi, y + dy, z)
		# Le sol du tunnel suit la pente : la case sous le premier niveau est pavée.
		for xi in range(-ceili(a), ceili(a) + 1):
			b.case(xi, dy - 1, z, "chemin" if v["creuser"] else "pierre")
