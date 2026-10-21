extends "res://app/preshapes/forme.gd"
## LA TOUR ET LE DONJON : ronde ou carrée, pleine ou creuse (une salle), crénelée ou coiffée d'un toit conique ; un
## donjon carré, une tour de guet fine, une tour de magicien.

const Fort := preload("res://app/preshapes/fortifications/commun.gd")


func _init() -> void:
	id = "tour"
	nom = "Tower, keep"
	famille = "fortifications"
	aide = "Round or square, solid or with a room, battlements or a cone roof: a keep, a watchtower, a wizard's tower."


func facteurs() -> Array:
	return [
		choix("plan", "Plan", ["Round", "Square"], 0, "The tower's plan."),
		f("rayon", "Radius", 1, 16, 4, "Half its width."),
		f("hauteur", "Height", 3, 64, 18, "Up to the top."),
		f("paroi", "Wall", 0, 4, 1, "0: solid. Otherwise a room at the foot, with walls this thick."),
		choix("toit", "Top", ["Battlements", "Cone roof", "Flat"], 0, "How it ends."),
		f("contreforts", "Buttresses", 0, 8, 0, "Buttresses around the foot."),
		f("assise", "Splayed base", 0, 6, 0, "A sloping base, wider than the tower."),
	]


func packs() -> Array:
	return [
		["Keep", {"plan": 1, "rayon": 7, "hauteur": 20, "contreforts": 4}],
		["Watchtower", {"rayon": 2, "hauteur": 16, "paroi": 0}],
		["Wizard's tower", {"rayon": 4, "hauteur": 34, "toit": 1, "assise": 3}],
		["Round tower", {}],
	]


func construire(v: Dictionary, b: Bati, _rng: RandomNumberGenerator) -> void:
	var ronde := int(v["plan"]) == 0
	var r: float = v["rayon"]
	var H := int(v["hauteur"])
	Fort.tour(b, 0, 0, r, H, ronde, int(v["toit"]) == 0, int(v["toit"]) == 1, int(v["paroi"]))
	var A := int(v["assise"])
	for k in A:
		var rr := r + A - k
		if ronde:
			b.cylindre(0, 0, rr, k, k, "pierre")
		else:
			b.boite(Vector3i(-roundi(rr), k, -roundi(rr)), Vector3i(roundi(rr), k, roundi(rr)), "pierre")
	var nc := int(v["contreforts"])
	for i in nc:
		var a := TAU * i / nc + (PI / 4.0 if not ronde else 0.0)
		var d := Vector2(cos(a), sin(a))
		for s in range(0, 4):
			var q := d * (r + s)
			var hh := maxi(1, H / 2 - s * H / 10)
			b.boite(Vector3i(roundi(q.x), 0, roundi(q.y)), Vector3i(roundi(q.x), hh - 1, roundi(q.y)), "pierre")
	if int(v["paroi"]) > 0:
		# La porte.
		b.vider_boite(Vector3i(-1 if r >= 2 else 0, 0, roundi(r)), Vector3i(1 if r >= 2 else 0, 2, roundi(r)))
