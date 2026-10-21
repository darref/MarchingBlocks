extends "res://app/preshapes/forme.gd"
## L'AQUEDUC le long d'une courbe : des piles, des arches en plein cintre, un à trois étages d'arcades, et le canal
## CREUSÉ dans le tablier (l'eau de Fluids y coule).


func _init() -> void:
	id = "aqueduc"
	nom = "Aqueduct"
	famille = "antique"
	aide = "Piers and round arches along a curve, up to three tiers of arcades, a water channel along the top."


func facteurs() -> Array:
	return [
		f("longueur", "Length", 8, 128, 60, "Along the line, in cells."),
		f("pli", "Bend", -40, 40, 0, "How far the middle bows to the side."),
		f("etages", "Tiers", 1, 3, 2, "Tiers of arcades, one over the other."),
		f("hauteur", "Tier height", 4, 24, 9, "Each tier, in cells."),
		f("portee", "Arch span", 2, 16, 6, "The opening of each arch."),
		f("pile", "Pier width", 1, 4, 2, "The width of each pier."),
		f("largeur", "Width", 2, 6, 3, "The thickness of the arcade."),
		coche("canal", "Channel", true, "A one-cell trough along the top."),
	]


func packs() -> Array:
	return [
		["Pont du Gard", {"longueur": 100, "etages": 3, "hauteur": 10, "portee": 8, "pile": 2}],
		["Roman aqueduct", {"etages": 1, "hauteur": 12, "portee": 5, "pile": 2, "longueur": 80, "pli": 20}],
		["Low arcade", {"etages": 1, "hauteur": 5, "portee": 3, "pile": 1, "largeur": 2}],
	]


func construire(v: Dictionary, b: Bati, _rng: RandomNumberGenerator) -> void:
	var L: float = v["longueur"]
	var pli: float = v["pli"]
	var n := int(v["etages"])
	var Ht := int(v["hauteur"])
	var span := float(v["portee"])
	var pile := float(v["pile"])
	var periode := span + pile
	var demi_l: float = v["largeur"] * 0.5
	# Le profil, le long de l'abscisse curviligne s : plein ou vide à la hauteur y.
	var plein := func(s: float, y: int) -> bool:
		var etage := mini(y / Ht, n - 1)
		var yl := y - etage * Ht
		# Les étages du haut ont des arches plus petites (deux par arche du bas, au troisième étage).
		var p := periode / (2.0 if etage == 2 else 1.0)
		var sp := span / (2.0 if etage == 2 else 1.0)
		var u := fposmod(s, p) - pile * 0.5
		if u < 0.0 or u > sp:
			return true
		var ouverture := Ht - 2
		var r := sp * 0.5
		var montant := maxf(0.0, ouverture - r)
		if yl < montant:
			return false
		var dy := yl - montant
		return Vector2(u - r, dy).length() > r
	var total := n * Ht
	var pas := int(ceil(L * 2.0))
	var vus := {}
	for i in pas + 1:
		var t := float(i) / pas
		var p := courbe(t, L, pli)
		var nrm := tangente(t, L, pli).orthogonal()
		var s := t * L
		for k in range(-ceili(demi_l * 2), ceili(demi_l * 2) + 1):
			var q := p + nrm * (k * 0.5)
			if absf(k * 0.5) > demi_l:
				continue
			var c := Vector2i(roundi(q.x), roundi(q.y))
			if vus.has(c):
				continue
			vus[c] = true
			for y in total + 1:
				if y == total or plein.call(s, y):
					b.case(c.x, y, c.y, "pierre")
			# Le canal : les bords du tablier montent d'une case, le milieu reste en creux.
			if v["canal"] and absf(k * 0.5) >= demi_l - 0.5:
				b.case(c.x, total + 1, c.y, "pierre")
