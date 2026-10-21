extends "res://app/preshapes/forme.gd"
## LA ZIGGOURAT : des terrasses rectangulaires empilées, un grand escalier frontal qui monte d'un trait au sommet, deux
## escaliers latéraux qui le rejoignent, un sanctuaire en haut.


func _init() -> void:
	id = "ziggourat"
	nom = "Ziggurat"
	famille = "antique"
	aide = "Stacked rectangular terraces, a great front stair straight to the top, side stairs, a shrine."


func facteurs() -> Array:
	return [
		f("largeur", "Width", 9, 96, 41, "Across x, at the base."),
		f("profondeur", "Depth", 9, 96, 33, "Across z, at the base."),
		f("etages", "Terraces", 1, 8, 3, "How many terraces."),
		f("hauteur_etage", "Terrace height", 2, 12, 5, "Each terrace's height."),
		f("retrait", "Inset", 1, 10, 4, "How far each terrace steps back."),
		f("escalier", "Stair width", 1, 11, 5, "The great front stair."),
		coche("lateraux", "Side stairs", true, "Two stairs along the front face, joining the great stair."),
		coche("sanctuaire", "Shrine", true, "A roofed shrine on the top terrace."),
	]


func packs() -> Array:
	return [
		["Ur ziggurat", {"largeur": 61, "profondeur": 45, "etages": 3, "hauteur_etage": 6, "retrait": 6}],
		["Tall ziggurat", {"etages": 6, "hauteur_etage": 4, "retrait": 3, "largeur": 45, "profondeur": 45}],
		["Altar mound", {"etages": 1, "largeur": 17, "profondeur": 13, "hauteur_etage": 3, "lateraux": false}],
	]


func construire(v: Dictionary, b: Bati, _rng: RandomNumberGenerator) -> void:
	var rx := int(v["largeur"]) / 2
	var rz := int(v["profondeur"]) / 2
	var he := int(v["hauteur_etage"])
	var re := int(v["retrait"])
	var n := 0
	for i in int(v["etages"]):
		var ax := rx - i * re
		var az := rz - i * re
		if ax < 2 or az < 2:
			break
		b.boite(Vector3i(-ax, i * he, -az), Vector3i(ax, (i + 1) * he - 1, az), "pierre")
		n = i + 1
	var H := n * he
	# Le grand escalier : de face (z+), une marche par case, jusqu'au sommet.
	var w := int(v["escalier"]) / 2
	var az_haut := rz - (n - 1) * re
	for d in range(az_haut + 1, az_haut + H + 1):
		var y := H + az_haut - d
		for x in range(-w, w + 1):
			for yy in range(0, y + 1):
				b.case(x, yy, d, "pierre")
			for yy in range(y + 1, H + 1):
				b.vider(x, yy, d)
	if v["lateraux"] and n >= 1:
		# Deux escaliers le long de la face avant du premier étage, qui montent vers le centre.
		for s in [-1, 1]:
			for k in range(0, he):
				var x: int = s * (w + 1 + he - k)
				for yy in range(0, k + 1):
					b.case(x, yy, rz + 1, "pierre")
					b.case(x, yy, rz + 2, "pierre")
	if v["sanctuaire"] and n >= 1:
		var ax := mini(rx - (n - 1) * re - 2, 5)
		var azs := mini(az_haut - 2, 4)
		if ax >= 2 and azs >= 2:
			for x in range(-ax, ax + 1):
				for z in range(-azs, azs + 1):
					if absi(x) == ax or absi(z) == azs:
						b.boite(Vector3i(x, H, z), Vector3i(x, H + 2, z), "pierre")
			b.boite(Vector3i(-ax, H + 3, -azs), Vector3i(ax, H + 3, azs), "toit")
			b.vider_boite(Vector3i(-1, H, azs), Vector3i(1, H + 1, azs))
