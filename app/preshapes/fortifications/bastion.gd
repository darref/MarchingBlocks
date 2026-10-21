extends "res://app/preshapes/forme.gd"
## LE FORT EN ÉTOILE (à la Vauban) : un rempart dont le tracé avance en pointes de bastions, son glacis en pente douce
## vers l'extérieur, le fossé CREUSÉ entre les deux.


func _init() -> void:
	id = "bastion"
	nom = "Star fort"
	famille = "fortifications"
	aide = "A rampart whose outline juts out in pointed bastions, a gentle glacis outside and a dry ditch dug between."


func facteurs() -> Array:
	return [
		f("pointes", "Bastions", 3, 10, 5, "How many points."),
		f("rayon", "Radius", 10, 64, 30, "To the tip of a bastion."),
		f("creux", "Point depth", 0.1, 0.6, 0.3, "How deep the notches between bastions go.", 0.01),
		f("hauteur", "Height", 2, 16, 6, "The rampart."),
		f("epaisseur", "Thickness", 2, 10, 4, "The rampart's thickness."),
		f("fosse", "Ditch", 0, 10, 4, "A dry ditch dug outside; 0: none."),
		f("glacis", "Glacis", 0, 16, 6, "A gentle slope of earth beyond the ditch."),
	]


func packs() -> Array:
	return [
		["Vauban fort", {"pointes": 5}],
		["Star citadel", {"pointes": 8, "rayon": 54, "hauteur": 9, "epaisseur": 6}],
		["Small redoubt", {"pointes": 4, "rayon": 16, "hauteur": 4, "epaisseur": 3, "glacis": 3}],
	]


func construire(v: Dictionary, b: Bati, _rng: RandomNumberGenerator) -> void:
	var n := int(v["pointes"])
	var R: float = v["rayon"]
	var ri: float = R * (1.0 - v["creux"])
	var poly := PackedVector2Array()
	for i in n * 2:
		var a := PI * i / n
		poly.append(Vector2(cos(a), sin(a)) * (R if i % 2 == 0 else ri))
	var H := int(v["hauteur"])
	var ep: float = v["epaisseur"]
	var F: float = v["fosse"]
	var G: float = v["glacis"]
	var ext := ceili(R + F + G + 2)
	for x in range(-ext, ext + 1):
		for z in range(-ext, ext + 1):
			var p := Vector2(x, z)
			var d := _distance(poly, p)
			var dedans := Geometry2D.is_point_in_polygon(p, poly)
			if dedans and d <= ep:
				b.colonne(x, z, 0, H - 1, "pierre", "pierre")
				# Un parapet sur le bord extérieur.
				if d <= 1.0:
					b.case(x, H, z, "pierre")
			elif not dedans and d <= F:
				b.vider_boite(Vector3i(x, -2, z), Vector3i(x, 0, z))
			elif not dedans and d <= F + G and G > 0.0:
				var hi := int(round((H * 0.6) * (1.0 - (d - F) / G)))
				if hi >= 1:
					b.colonne(x, z, 0, hi - 1, "sol", "sol")


## La distance de `p` au contour du polygone.
static func _distance(poly: PackedVector2Array, p: Vector2) -> float:
	var d := INF
	for i in poly.size():
		var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
		d = minf(d, p.distance_to(q))
	return d
