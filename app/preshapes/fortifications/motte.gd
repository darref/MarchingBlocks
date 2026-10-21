extends "res://app/preshapes/forme.gd"
## LA MOTTE CASTRALE : une butte de terre ronde, sa tour en haut, une palissade autour de la basse-cour, un fossé CREUSÉ.

const Fort := preload("res://app/preshapes/fortifications/commun.gd")


func _init() -> void:
	id = "motte"
	nom = "Motte and bailey"
	famille = "fortifications"
	aide = "A round earth mound with a tower on top, a palisaded bailey beside it, a ditch dug around."


func facteurs() -> Array:
	return [
		f("rayon", "Mound radius", 4, 32, 12, "At the foot."),
		f("hauteur", "Mound height", 2, 24, 8, "The mound."),
		f("tour", "Tower radius", 1, 8, 3, "The tower on top."),
		f("hauteur_tour", "Tower height", 3, 32, 9, "The tower."),
		f("cour", "Bailey", 0, 48, 22, "The bailey's width beside the mound; 0: none."),
		f("palissade", "Palisade", 2, 6, 3, "The palisade's height."),
		f("fosse", "Ditch", 0, 6, 2, "A ditch around the mound; 0: none."),
	]


func packs() -> Array:
	return [
		["Norman motte", {}],
		["Lone mound", {"cour": 0, "rayon": 14, "hauteur": 10}],
	]


func construire(v: Dictionary, b: Bati, _rng: RandomNumberGenerator) -> void:
	var R: float = v["rayon"]
	var H: float = v["hauteur"]
	var top := R * 0.4
	for x in range(-ceili(R), ceili(R) + 1):
		for z in range(-ceili(R), ceili(R) + 1):
			var d := Vector2(x, z).length()
			if d > R:
				continue
			var hi := int(round(H if d <= top else H * (1.0 - (d - top) / (R - top))))
			if hi >= 1:
				b.colonne(x, z, 0, hi - 1, "sol", "sol")
	# La tour, posée sur le haut de la butte : on la bâtit dans un chantier à part, puis on la remonte.
	var t := Bati.new()
	Fort.tour(t, 0, 0, v["tour"], int(v["hauteur_tour"]), false, true, false)
	var hb := int(round(H))
	for c in t.cases:
		b.case(c.x, c.y + hb, c.z, t.cases[c])
	var F := int(v["fosse"])
	if F > 0:
		for x in range(-ceili(R + F), ceili(R + F) + 1):
			for z in range(-ceili(R + F), ceili(R + F) + 1):
				var d := Vector2(x, z).length()
				if d > R and d <= R + F:
					b.vider_boite(Vector3i(x, -2, z), Vector3i(x, 0, z))
	var C: float = v["cour"]
	if C > 0.0:
		var cx := R + F + C * 0.5 + 1.0
		var hp := int(v["palissade"])
		var coins := [Vector2(cx - C * 0.5, -C * 0.4), Vector2(cx + C * 0.5, -C * 0.4), Vector2(cx + C * 0.5, C * 0.4),
			Vector2(cx - C * 0.5, C * 0.4)]
		for i in 4:
			var a: Vector2 = coins[i]
			var c: Vector2 = coins[(i + 1) % 4]
			Fort.mur(b, a, c, hp, 1, true, "sol2")
		b.vider_boite(Vector3i(roundi(cx + C * 0.5) - 1, 0, -1), Vector3i(roundi(cx + C * 0.5) + 1, hp, 1))
