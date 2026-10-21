extends "res://app/preshapes/forme.gd"
## LE CHÂTEAU : une enceinte (carrée ou ronde), ses tours d'angle, la porte et son châtelet, le donjon au milieu, des
## douves CREUSÉES autour.

const Fort := preload("res://app/preshapes/fortifications/commun.gd")


func _init() -> void:
	id = "chateau"
	nom = "Castle"
	famille = "fortifications"
	aide = "A curtain wall with corner towers, a gatehouse, a keep in the middle and a moat dug around."


func facteurs() -> Array:
	return [
		choix("plan", "Plan", ["Square", "Round", "Hexagon"], 0, "The curtain wall's outline."),
		f("largeur", "Width", 16, 120, 48, "Across x."),
		f("profondeur", "Depth", 16, 120, 40, "Across z (square plan)."),
		f("hauteur", "Wall height", 3, 20, 8, "The curtain wall."),
		f("epaisseur", "Wall thickness", 1, 5, 3, "3 or more: a wall-walk."),
		f("rayon_tour", "Tower radius", 2, 9, 4, "Each corner tower."),
		f("donjon", "Keep size", 0, 30, 12, "The keep's width; 0: none."),
		f("hauteur_donjon", "Keep height", 6, 48, 20, "The keep."),
		choix("toits", "Tower tops", ["Battlements", "Cone roofs"], 0, "How the towers end."),
		f("douves", "Moat", 0, 10, 3, "The width of a moat dug around; 0: none."),
	]


func packs() -> Array:
	return [
		["Stone castle", {}],
		["Fairy-tale castle", {"plan": 1, "toits": 1, "hauteur_donjon": 34, "donjon": 10}],
		["Fortress", {"largeur": 90, "profondeur": 90, "hauteur": 12, "epaisseur": 5, "rayon_tour": 6, "donjon": 22}],
		["Hill fort", {"plan": 2, "largeur": 40, "hauteur": 5, "donjon": 0, "douves": 0}],
	]


func construire(v: Dictionary, b: Bati, _rng: RandomNumberGenerator) -> void:
	var plan := int(v["plan"])
	var rx: float = v["largeur"] * 0.5
	var rz: float = v["profondeur"] * 0.5 if plan == 0 else rx
	var H := int(v["hauteur"])
	var ep := int(v["epaisseur"])
	var rt: float = v["rayon_tour"]
	var cones := int(v["toits"]) == 1
	var coins: Array = []
	match plan:
		0:
			coins = [Vector2(-rx, -rz), Vector2(rx, -rz), Vector2(rx, rz), Vector2(-rx, rz)]
		1:
			for i in 12:
				coins.append(Vector2(cos(TAU * i / 12), sin(TAU * i / 12)) * rx)
		2:
			for i in 6:
				coins.append(Vector2(cos(TAU * i / 6), sin(TAU * i / 6)) * rx)
	for i in coins.size():
		var a: Vector2 = coins[i]
		var c: Vector2 = coins[(i + 1) % coins.size()]
		Fort.mur(b, a, c, H, ep, true, "pierre", (a + c) * 0.5)
	var pas_tour := 1 if plan != 1 else 3
	for i in range(0, coins.size(), pas_tour):
		var p: Vector2 = coins[i]
		Fort.tour(b, p.x, p.y, rt, H + 4, true, not cones, cones)
	# Le châtelet : deux tours de part et d'autre de la porte, au milieu du mur avant (z+).
	var avant := Vector2(0, rz if plan == 0 else rx * cos(PI / coins.size()))
	for s in [-1, 1]:
		Fort.tour(b, s * (rt + 2.0), avant.y, maxf(2.0, rt - 1.0), H + 2, plan != 1, not cones, cones)
	b.vider_boite(Vector3i(-1, 0, roundi(avant.y) - ep - 1), Vector3i(1, mini(3, H - 2), roundi(avant.y) + ep + 1))
	var D := int(v["donjon"])
	if D > 0:
		var r := D * 0.5
		Fort.tour(b, 0, 0, r, int(v["hauteur_donjon"]), plan == 1, not cones, cones, 1)
	var M := int(v["douves"])
	if M > 0:
		# Les douves : une bande creusée tout autour, à 2 cases du mur, deux cases de profondeur ; un pont devant la porte.
		var marge := rt + 2.0
		for x in range(-ceili(rx + marge + M), ceili(rx + marge + M) + 1):
			for z in range(-ceili(rz + marge + M), ceili(rz + marge + M) + 1):
				var d: float
				if plan == 0:
					d = maxf(absf(x) - rx, absf(z) - rz)
				else:
					d = Vector2(x, z).length() - rx
				if d > marge and d <= marge + M and not (absi(x) <= 1 and z > 0):
					b.vider_boite(Vector3i(x, -2, z), Vector3i(x, 0, z))
