extends "res://app/preshapes/forme.gd"
## LE REMPART le long d'une courbe : un mur épais, son chemin de ronde entre créneaux et garde-corps, des tours à
## intervalles, une porte au milieu.

const Fort := preload("res://app/preshapes/fortifications/commun.gd")


func _init() -> void:
	id = "rempart"
	nom = "Rampart wall"
	famille = "fortifications"
	aide = "A thick wall along a curve: wall-walk between battlements and parapet, towers at intervals, a gate."


func facteurs() -> Array:
	return [
		f("longueur", "Length", 6, 128, 50, "Along the line."),
		f("pli", "Bend", -40, 40, 8, "How far the middle bows outward."),
		f("hauteur", "Height", 2, 24, 7, "The wall, up to the wall-walk."),
		f("epaisseur", "Thickness", 1, 6, 3, "The wall's thickness (3 or more: a wall-walk)."),
		coche("creneaux", "Battlements", true, "Merlons along the outer edge."),
		f("tours", "Towers", 0, 9, 3, "Towers along the wall (ends included when 2 or more)."),
		f("rayon_tour", "Tower radius", 2, 8, 3, "Each tower."),
		f("surplomb", "Tower rise", 0, 12, 3, "How much higher the towers stand."),
		coche("porte", "Gate", true, "A gateway through the middle."),
	]


func packs() -> Array:
	return [
		["City wall", {"longueur": 90, "tours": 5, "hauteur": 9, "epaisseur": 4}],
		["Great wall", {"longueur": 128, "pli": 30, "hauteur": 6, "epaisseur": 4, "tours": 6, "rayon_tour": 3, "porte": false}],
		["Palisade", {"hauteur": 4, "epaisseur": 1, "creneaux": false, "tours": 0}],
	]


func construire(v: Dictionary, b: Bati, _rng: RandomNumberGenerator) -> void:
	var L: float = v["longueur"]
	var pli: float = v["pli"]
	var H := int(v["hauteur"])
	var ep := int(v["epaisseur"])
	var n := 24
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		Fort.mur(b, courbe(t0, L, pli), courbe(t1, L, pli), H, ep, v["creneaux"], "pierre", Vector2(0, -1))
	var nt := int(v["tours"])
	for i in nt:
		var t := 0.5 if nt == 1 else float(i) / (nt - 1)
		var p := courbe(t, L, pli)
		if v["porte"] and absf(t - 0.5) < 0.01 and nt % 2 == 1:
			continue
		Fort.tour(b, p.x, p.y, v["rayon_tour"], H + int(v["surplomb"]), true, true, false)
	if v["porte"]:
		var p := courbe(0.5, L, pli)
		var tg := tangente(0.5, L, pli)
		# Deux tours qui encadrent la porte, et le passage voûté.
		for s in [-1, 1]:
			var q: Vector2 = p + tg * s * (float(v["rayon_tour"]) + 2.5)
			Fort.tour(b, q.x, q.y, v["rayon_tour"], H + int(v["surplomb"]), true, true, false)
		var nrm := tg.orthogonal()
		for k in range(-ep - 1, ep + 2):
			for w in range(-1, 2):
				var c := p + nrm * k + tg * w
				b.vider_boite(Vector3i(roundi(c.x), 0, roundi(c.y)), Vector3i(roundi(c.x), mini(3, H - 2), roundi(c.y)))
