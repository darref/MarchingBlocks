extends "res://app/preshapes/forme.gd"
## LA SPHÈRE, L'ELLIPSOÏDE, LE DÔME : pleine ou creuse, coupée à la hauteur qu'on veut (une demi-sphère : un dôme).


func _init() -> void:
	id = "sphere"
	nom = "Sphere, dome"
	famille = "pures"
	aide = "A ball or an ellipsoid, solid or hollow, cut at any height: half of it is a dome."


func facteurs() -> Array:
	return [
		f("rx", "Radius x", 1, 48, 8, "Half-width across x."),
		f("ry", "Radius y", 1, 48, 8, "Half-height."),
		f("rz", "Radius z", 1, 48, 8, "Half-width across z."),
		f("coupe", "Cut", 0.0, 1.0, 0.0, "The share of the bottom cut off (0.5: a dome).", 0.01),
		f("paroi", "Shell", 0, 12, 0, "0: solid. Otherwise hollow, with walls this thick."),
		choix("matiere", "Material", ["Rock", "Masonry", "Ground"], 0, "Which part it is painted as."),
	]


func packs() -> Array:
	return [
		["Ball", {}],
		["Dome", {"rx": 10, "ry": 10, "rz": 10, "coupe": 0.5, "paroi": 1, "matiere": 1}],
		["Boulder", {"rx": 4, "ry": 3, "rz": 5, "coupe": 0.2}],
		["Egg", {"rx": 6, "ry": 9, "rz": 6}],
	]


func construire(v: Dictionary, b: Bati, _rng: RandomNumberGenerator) -> void:
	var r := Vector3(v["rx"], v["ry"], v["rz"])
	var role: String = ["roche", "pierre", "sol"][int(v["matiere"])]
	var bas: float = -r.y + 2.0 * r.y * v["coupe"]
	var p := int(v["paroi"])
	for x in range(-ceili(r.x), ceili(r.x) + 1):
		for y in range(-ceili(r.y), ceili(r.y) + 1):
			if y < bas - 0.01:
				continue
			for z in range(-ceili(r.z), ceili(r.z) + 1):
				var q := Vector3(x / r.x, y / r.y, z / r.z).length()
				if q > 1.0:
					continue
				if p > 0:
					var ri := r - Vector3.ONE * p
					if ri.x > 0 and ri.y > 0 and ri.z > 0 and Vector3(x / ri.x, y / ri.y, z / ri.z).length() < 1.0:
						continue
				# Posée sur le sol : le bas de la coupe est en y = 0.
				b.case(x, y - ceili(bas), z, role)
