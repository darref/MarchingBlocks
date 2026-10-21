extends "res://app/preshapes/forme.gd"
## LE CROMLECH : un cercle de pierres levées, des linteaux posés d'une pierre à l'autre (Stonehenge), un autel au milieu,
## un second cercle intérieur.


func _init() -> void:
	id = "cromlech"
	nom = "Stone circle"
	famille = "antique"
	aide = "A ring of standing stones, lintels laid from stone to stone, an inner ring, an altar in the middle."


func facteurs() -> Array:
	return [
		f("rayon", "Radius", 3, 40, 12, "The ring, in cells."),
		f("pierres", "Stones", 3, 40, 16, "How many stones in the ring."),
		f("hauteur", "Stone height", 2, 16, 5, "How tall each stone stands."),
		f("largeur", "Stone width", 1, 3, 2, "How wide each stone is."),
		coche("linteaux", "Lintels", true, "Stones laid across the tops, linking them."),
		coche("interieur", "Inner ring", false, "A second, taller ring of trilithons inside."),
		coche("autel", "Altar", true, "A flat stone in the middle."),
		f("usure", "Missing stones", 0.0, 1.0, 0.0, "Fallen and missing stones.", 0.01),
	]


func packs() -> Array:
	return [
		["Stonehenge", {"rayon": 15, "pierres": 30, "hauteur": 5, "linteaux": true, "interieur": true, "usure": 0.25}],
		["Druid ring", {"rayon": 9, "pierres": 12, "hauteur": 3, "largeur": 1, "linteaux": false}],
		["Ruined circle", {"usure": 0.55, "linteaux": true}],
	]


func construire(v: Dictionary, b: Bati, rng: RandomNumberGenerator) -> void:
	var R: float = v["rayon"]
	var n := int(v["pierres"])
	var H := int(v["hauteur"])
	var w := int(v["largeur"])
	_anneau(b, rng, R, n, H, w, v["linteaux"], v["usure"])
	if v["interieur"] and R >= 7:
		_anneau(b, rng, R * 0.55, maxi(3, n / 3), H + 2, w, true, v["usure"] * 0.5)
	if v["autel"]:
		b.boite(Vector3i(-1, 0, -2), Vector3i(1, 0, 1), "pierre")


func _anneau(b: Bati, rng: RandomNumberGenerator, R: float, n: int, H: int, w: int, linteaux: bool, usure: float) -> void:
	var debout: Array = []
	for i in n:
		var a := TAU * i / n
		var p := Vector2(cos(a), sin(a)) * R
		var c := Vector2i(roundi(p.x), roundi(p.y))
		var tombe := rng.randf() < usure
		debout.append(not tombe)
		if tombe:
			if rng.randf() < 0.5:
				b.boite(Vector3i(c.x, 0, c.y), Vector3i(c.x + w - 1, 0, c.y + w - 1), "pierre")
			continue
		b.boite(Vector3i(c.x, 0, c.y), Vector3i(c.x + w - 1, H - 1, c.y + w - 1), "pierre")
	if not linteaux:
		return
	# Un linteau d'une pierre debout à la suivante, posé sur leurs têtes : des cases le long de la corde.
	for i in n:
		var j := (i + 1) % n
		if not (debout[i] and debout[j]):
			continue
		var a := Vector2(cos(TAU * i / n), sin(TAU * i / n)) * R
		var c := Vector2(cos(TAU * j / n), sin(TAU * j / n)) * R
		var pas := maxi(1, ceili(a.distance_to(c) * 2.0))
		var vu := {}
		for s in pas + 1:
			var q := a.lerp(c, float(s) / pas)
			var k := Vector2i(roundi(q.x), roundi(q.y))
			if not vu.has(k):
				vu[k] = true
				b.boite(Vector3i(k.x, H, k.y), Vector3i(k.x + w - 1, H, k.y + w - 1), "pierre")
