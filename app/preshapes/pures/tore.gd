extends "res://app/preshapes/forme.gd"
## LE TORE ET L'ANNEAU : un anneau couché (une bouée, un cratère en relief) ou dressé (un portail circulaire).


func _init() -> void:
	id = "tore"
	nom = "Torus, ring"
	famille = "pures"
	aide = "A ring lying flat (a donut, a raised rim) or standing up (a round portal)."


func facteurs() -> Array:
	return [
		f("grand", "Ring radius", 2, 48, 10, "From the center to the middle of the tube."),
		f("petit", "Tube radius", 1, 16, 3, "The tube's thickness."),
		coche("debout", "Standing", false, "Standing up like a portal (on x), instead of lying flat."),
		f("arc", "Arc", 0.1, 1.0, 1.0, "The share of the full circle (0.5: a half ring, an arch).", 0.01),
		choix("matiere", "Material", ["Rock", "Masonry", "Ground"], 1, "Which part it is painted as."),
	]


func packs() -> Array:
	return [
		["Donut", {}],
		["Portal", {"debout": true, "grand": 8, "petit": 2}],
		["Rainbow arch", {"debout": true, "arc": 0.5, "grand": 14, "petit": 2}],
	]


func construire(v: Dictionary, b: Bati, _rng: RandomNumberGenerator) -> void:
	var R: float = v["grand"]
	var r: float = v["petit"]
	var debout: bool = v["debout"]
	var role: String = ["roche", "pierre", "sol"][int(v["matiere"])]
	var e := ceili(R + r)
	var arc: float = v["arc"]
	var ez := ceili(r) if debout else e
	for x in range(-e, e + 1):
		for y in range(-e, e + 1):
			for z in range(-ez, ez + 1):
				var q := Vector3(x, y, z)
				var plan := Vector2(q.x, q.y) if debout else Vector2(q.x, q.z)
				var hors := q.z if debout else q.y
				if not debout and absf(hors) > r:
					continue
				var d := Vector2(plan.length() - R, hors).length()
				if d > r:
					continue
				# L'arc : la part du cercle, comptée depuis le haut (debout) ou depuis +x (couché), symétrique.
				var ang := absf(atan2(plan.x, plan.y)) if debout else absf(atan2(plan.y, plan.x))
				if ang > PI * arc + 0.001:
					continue
				var y_pose := y + (ceili(r) if not debout else (e if arc >= 0.999 else 0))
				b.case(x, y_pose, z, role)
