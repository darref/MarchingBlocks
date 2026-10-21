extends "res://app/preshapes/forme.gd"
## L'ESCALIER HÉLICOÏDAL ET LA RAMPE EN SPIRALE : des marches d'une case qui tournent autour d'un fût, sur la hauteur
## qu'on veut ; avec ou sans paroi autour (une tour d'escalier).


func _init() -> void:
	id = "spirale"
	nom = "Spiral stair"
	famille = "pures"
	aide = "One-cell steps winding around a core, as high as you want; with an outer wall, a stair tower."


func facteurs() -> Array:
	return [
		f("hauteur", "Height", 2, 64, 16, "From the first to the last step."),
		f("rayon", "Radius", 2, 16, 4, "From the center to the outer edge of the steps."),
		f("largeur", "Step width", 1, 6, 2, "How wide the steps are (from the outer edge inward)."),
		f("fut", "Core", 0, 6, 1, "The central column's radius; 0: open center."),
		coche("paroi", "Outer wall", false, "A cylinder wall around the stair (a stair tower)."),
		coche("sens", "Clockwise", false, "Which way it turns."),
		choix("matiere", "Material", ["Masonry", "Rock"], 0, "Which part it is painted as."),
	]


func packs() -> Array:
	return [
		["Stair tower", {"paroi": true, "rayon": 4, "hauteur": 20}],
		["Spiral ramp", {"rayon": 9, "largeur": 4, "fut": 4, "hauteur": 12}],
		["Open helix", {"fut": 0, "rayon": 5, "largeur": 2, "hauteur": 24}],
	]


func construire(v: Dictionary, b: Bati, _rng: RandomNumberGenerator) -> void:
	var H := int(v["hauteur"])
	var R: float = v["rayon"]
	var w: float = v["largeur"]
	var role: String = ["pierre", "roche"][int(v["matiere"])]
	var sens := -1.0 if v["sens"] else 1.0
	# Le pas angulaire : une case de montée par case parcourue sur le cercle du milieu des marches.
	var rm := maxf(1.0, R - w * 0.5)
	for x in range(-ceili(R) - 1, ceili(R) + 2):
		for z in range(-ceili(R) - 1, ceili(R) + 2):
			var d := Vector2(x, z).length()
			if d > R + 0.01 or d < R - w - 0.01:
				continue
			var a := fposmod(sens * atan2(z, x), TAU)
			# La hauteur de la marche sur cette colonne : chaque tour monte de TAU·rm cases. Plusieurs tours : plusieurs
			# marches sur la même colonne, l'une au-dessus de l'autre.
			var tour := TAU * rm
			var y0 := int(floor(a * rm))
			var y := y0
			while y < H:
				# La marche, et la case dessous (sans elle, deux marches voisines ne se toucheraient que par une arête).
				b.case(x, y, z, role)
				if y > 0:
					b.case(x, y - 1, z, role)
				y += int(round(tour))
	var fut: float = v["fut"]
	if fut > 0.0:
		b.cylindre(0, 0, fut, 0, H, role)
	if v["paroi"]:
		b.cylindre(0, 0, R + 1.0, 0, H + 2, role, R + 0.01)
		b.vider_boite(Vector3i(roundi(R), 0, -1), Vector3i(roundi(R) + 1, 2, 0))
