extends "res://app/preshapes/forme.gd"
## LE PONT À ARCHES : un tablier pavé qui enjambe une rivière ou un ravin, ses arches, ses parapets, ses rampes d'accès
## en marches d'une case. À viser sur une rive : il part vers l'autre.


func _init() -> void:
	id = "pont"
	nom = "Arch bridge"
	famille = "antique"
	aide = "A paved deck on arches over a river or a gorge, with parapets and stepped ramps; aim at one bank."


func facteurs() -> Array:
	return [
		f("longueur", "Length", 6, 96, 30, "From end to end."),
		f("hauteur", "Height", 2, 32, 6, "The deck above the ground you aim at."),
		f("arches", "Arches", 1, 9, 3, "How many arches."),
		f("pile", "Pier width", 1, 5, 2, "The piers between the arches."),
		f("largeur", "Width", 2, 9, 4, "Across the deck, parapets included."),
		f("fondation", "Foundations", 0, 32, 8, "How far the piers go down (into a river bed)."),
		coche("parapets", "Parapets", true, "A low wall along both edges."),
		coche("rampes", "Ramps", true, "Stepped ramps down to the ground at both ends."),
		coche("bosse", "Humped", false, "The deck rises to the middle (a humpback bridge)."),
	]


func packs() -> Array:
	return [
		["Roman bridge", {"longueur": 40, "hauteur": 8, "arches": 4, "largeur": 5}],
		["Humpback bridge", {"longueur": 14, "hauteur": 3, "arches": 1, "bosse": true, "largeur": 3}],
		["Viaduct", {"longueur": 90, "hauteur": 22, "arches": 7, "pile": 3, "fondation": 16}],
	]


func construire(v: Dictionary, b: Bati, _rng: RandomNumberGenerator) -> void:
	var L := int(v["longueur"])
	var H := int(v["hauteur"])
	var n := int(v["arches"])
	var pile := int(v["pile"])
	var W := int(v["largeur"])
	var F := int(v["fondation"])
	var x0 := -L / 2
	var span := float(L - (n + 1) * pile) / n
	var z0 := -W / 2
	for i in L:
		var x := x0 + i
		var t := float(i) / maxf(L - 1, 1)
		var hdeck := H + (int(round(sin(t * PI) * H * 0.4)) if v["bosse"] else 0)
		# Pile ou arche ? Position dans la travée.
		var u := float(i)
		var dans_arche := false
		var hauteur_intrados := 0.0
		var a := 0
		while a < n:
			var debut := pile + a * (span + pile)
			if u >= debut and u < debut + span:
				dans_arche = true
				var r := span * 0.5
				var dx := u + 0.5 - (debut + r)
				var montant := maxf(0.0, hdeck - 1 - r)
				hauteur_intrados = montant + sqrt(maxf(0.0, r * r - dx * dx))
				break
			a += 1
		for z in range(z0, z0 + W):
			if dans_arche:
				for y in range(int(ceil(hauteur_intrados)), hdeck):
					b.case(x, y, z, "pierre")
			else:
				for y in range(-F, hdeck):
					b.case(x, y, z, "pierre")
			b.case(x, hdeck, z, "chemin" if not (v["parapets"] and (z == z0 or z == z0 + W - 1)) else "pierre")
			if v["parapets"] and (z == z0 or z == z0 + W - 1):
				b.case(x, hdeck + 1, z, "pierre")
	if v["rampes"]:
		for s in [-1, 1]:
			var bout: int = x0 - 1 if s < 0 else x0 + L
			var h0 := H
			for k in range(0, H + 1):
				var x: int = bout + s * k
				var y := h0 - k
				if y < 0:
					break
				for z in range(z0, z0 + W):
					for yy in range(0, y + 1):
						b.case(x, yy, z, "pierre")
