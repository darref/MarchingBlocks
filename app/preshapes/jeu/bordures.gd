extends "res://app/preshapes/forme.gd"
## LES BORDURES DE CHEMIN À LA ZELDA : deux massifs longs et infranchissables qui tiennent un couloir le long d'une
## courbe ; le joueur suit le chemin, il ne l'escalade pas.


func _init() -> void:
	id = "bordures"
	nom = "Path borders"
	famille = "jeu"
	aide = "Two long, unclimbable massifs that hold a corridor along a curve, like the paths of a Zelda overworld."


func facteurs() -> Array:
	return [
		f("longueur", "Length", 8, 128, 56, "Along the corridor."),
		f("pli", "Bend", -40, 40, 10, "How far the middle bows to the side."),
		f("couloir", "Corridor", 2, 24, 6, "The free width between the borders."),
		f("hauteur", "Height", 2, 24, 5, "The borders (2 or more cells: the player cannot jump them)."),
		f("epaisseur", "Thickness", 1, 16, 5, "Each border's width."),
		f("bosses", "Lumps", 0.0, 1.0, 0.5, "Even walls (0) or lumpy rock with uneven tops (1).", 0.01),
		coche("pave", "Paved path", false, "Pave the corridor's floor."),
		choix("dessus", "Top", ["Grass", "Rock", "Second ground"], 0, "The borders' top."),
	]


func packs() -> Array:
	return [
		["Overworld path", {}],
		["Narrow pass", {"couloir": 3, "hauteur": 10, "epaisseur": 8, "dessus": 1}],
		["Hedge lane", {"hauteur": 3, "epaisseur": 2, "bosses": 0.1, "dessus": 2, "pave": true}],
	]


func construire(v: Dictionary, b: Bati, rng: RandomNumberGenerator) -> void:
	var L: float = v["longueur"]
	var pli: float = v["pli"]
	var demi_c: float = v["couloir"] * 0.5
	var ep: float = v["epaisseur"]
	var H: float = v["hauteur"]
	var n := bruit(rng, 0.12, 2)
	var dessus: String = ["sol", "roche", "sol2"][int(v["dessus"])]
	var champ := {}
	var sol := {}
	var pas := int(ceil(L * 2.0))
	for i in pas + 1:
		var t := float(i) / pas
		var p := courbe(t, L, pli)
		var nrm := tangente(t, L, pli).orthogonal()
		for k in range(-ceili((demi_c + ep) * 2), ceili((demi_c + ep) * 2) + 1):
			var off := k * 0.5
			var q := p + nrm * off
			var c := Vector2i(roundi(q.x), roundi(q.y))
			if absf(off) <= demi_c:
				sol[c] = true
				continue
			var x := (absf(off) - demi_c) / ep
			if x > 1.0:
				continue
			var h: float = H * (1.0 + v["bosses"] * 0.5 * n.get_noise_2d(c.x, c.y)) * (1.0 - pow(x, 6.0) * 0.5)
			champ[c] = maxf(float(champ.get(c, 0.0)), h)
	for c in champ:
		if sol.has(c):
			continue
		var hi := maxi(2, int(round(float(champ[c]))))
		b.colonne(c.x, c.y, 0, hi - 1, dessus, "roche")
	if v["pave"]:
		for c in sol:
			if not champ.has(c) or sol.has(c):
				b.case(c.x, -1, c.y, "chemin")
