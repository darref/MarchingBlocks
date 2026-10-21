extends "res://app/preshapes/forme.gd"
## LE CYLINDRE, LE CÔNE, LE TRONC DE CÔNE, LE PRISME : un rayon en bas, un rayon en haut, plein ou creux, rond ou à
## pans.


func _init() -> void:
	id = "cylindre"
	nom = "Cylinder, cone"
	famille = "pures"
	aide = "A radius at the foot and one at the top: a cylinder, a cone, a funnel, a prism; solid or hollow."


func facteurs() -> Array:
	return [
		f("bas", "Bottom radius", 0, 48, 6, "At the foot."),
		f("haut", "Top radius", 0, 48, 6, "At the top (0: a point)."),
		f("hauteur", "Height", 1, 64, 12, "In cells."),
		f("pans", "Sides", 0, 12, 0, "0: round. Otherwise a prism with this many sides (3 to 12)."),
		f("paroi", "Shell", 0, 12, 0, "0: solid. Otherwise hollow, with walls this thick."),
		coche("fond", "Closed ends", true, "Hollow: close the bottom and the top."),
		choix("matiere", "Material", ["Rock", "Masonry", "Ground"], 0, "Which part it is painted as."),
	]


func packs() -> Array:
	return [
		["Pillar", {"bas": 2, "haut": 2, "hauteur": 14, "matiere": 1}],
		["Cone", {"bas": 10, "haut": 0, "hauteur": 14}],
		["Silo", {"bas": 5, "haut": 5, "hauteur": 16, "paroi": 1, "fond": false, "matiere": 1}],
		["Hex column", {"bas": 4, "haut": 4, "pans": 6, "hauteur": 10}],
	]


func construire(v: Dictionary, b: Bati, _rng: RandomNumberGenerator) -> void:
	var H := int(v["hauteur"])
	var role: String = ["roche", "pierre", "sol"][int(v["matiere"])]
	var n := int(v["pans"])
	var p := int(v["paroi"])
	var R := maxf(v["bas"], v["haut"])
	for y in H:
		var r: float = lerpf(v["bas"], v["haut"], float(y) / maxf(H - 1, 1))
		for x in range(-ceili(R) - 1, ceili(R) + 2):
			for z in range(-ceili(R) - 1, ceili(R) + 2):
				var d := _dist(Vector2(x, z), n)
				if d > r + 0.01 and not (r < 0.5 and x == 0 and z == 0):
					continue
				var bout: bool = v["fond"] and (y == 0 or y == H - 1)
				if p > 0 and not bout and d <= r - p:
					continue
				b.case(x, y, z, role)


## La « distance » au centre : euclidienne (rond), ou celle d'un polygone régulier à `n` pans (son apothème).
static func _dist(q: Vector2, n: int) -> float:
	if n < 3:
		return q.length()
	var a := atan2(q.y, q.x)
	var secteur := TAU / n
	var local := fposmod(a, secteur) - secteur * 0.5
	return q.length() * cos(local) / cos(secteur * 0.5)
