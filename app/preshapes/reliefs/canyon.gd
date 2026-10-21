extends "res://app/preshapes/forme.gd"
## LE CANYON, LA GORGE, LE LIT DE RIVIÈRE : un sillon CREUSÉ dans le monde le long d'une courbe qui serpente, ses parois
## en gradins ; un fond de sable si on veut (l'eau vient de Fluids).


func _init() -> void:
	id = "canyon"
	nom = "Canyon, gorge"
	famille = "reliefs"
	aide = "Digs a winding trench into the world: a canyon with stepped walls, a gorge, or a river bed."


func facteurs() -> Array:
	return [
		f("longueur", "Length", 8, 128, 64, "Along the trench, in cells."),
		f("largeur", "Width", 2, 40, 12, "At the top, in cells."),
		f("profondeur", "Depth", 1, 40, 10, "Below the ground you aim at."),
		f("degage", "Clear above", 0, 40, 6, "Also cut what stands above the ground (a hill it crosses)."),
		f("pli", "Bend", -40, 40, 0, "How far the middle bows to the side."),
		f("meandres", "Meanders", 0, 8, 2, "How many times it winds left and right."),
		f("amplitude", "Meander size", 0, 24, 6, "How far each meander swings, in cells."),
		f("gradins", "Wall steps", 1, 6, 2, "Walls in steps: each step narrows the trench."),
		coche("fond", "Sandy floor", true, "A floor of sand at the bottom (a river bed)."),
	]


func packs() -> Array:
	return [
		["Grand canyon", {"longueur": 110, "largeur": 30, "profondeur": 22, "gradins": 4, "meandres": 2, "amplitude": 10}],
		["Slot gorge", {"largeur": 4, "profondeur": 16, "gradins": 1, "meandres": 4, "amplitude": 4}],
		["River bed", {"largeur": 6, "profondeur": 2, "gradins": 1, "meandres": 4, "amplitude": 8, "degage": 0}],
		["Moat trench", {"largeur": 5, "profondeur": 4, "meandres": 0, "fond": false}],
	]


func construire(v: Dictionary, b: Bati, _rng: RandomNumberGenerator) -> void:
	var L: float = v["longueur"]
	var demi: float = v["largeur"] * 0.5
	var P := int(v["profondeur"])
	var etapes := int(v["gradins"])
	var pas := int(ceil(L * 2.0))
	var fond := {}
	for s in pas + 1:
		var t := float(s) / pas
		var p := courbe(t, L, v["pli"])
		var n := tangente(t, L, v["pli"]).orthogonal()
		p += n * v["amplitude"] * sin(t * PI * 2.0 * v["meandres"]) if v["meandres"] > 0 else Vector2.ZERO
		for x in range(floori(p.x - demi) - 1, ceili(p.x + demi) + 2):
			for z in range(floori(p.y - demi) - 1, ceili(p.y + demi) + 2):
				var d := Vector2(x, z).distance_to(p)
				if d > demi:
					continue
				# Les gradins : plus on s'éloigne de l'axe, moins on descend.
				var palier := clampi(int((d / maxf(demi, 0.5)) * etapes), 0, etapes - 1)
				var bas := -P + int(round(float(P) * palier / etapes))
				var k := Vector2i(x, z)
				if not fond.has(k) or bas < int(fond[k]):
					fond[k] = bas
	# Un creusement par colonne, une fois le fond le plus bas connu (les échantillons se recouvrent : creuser à chacun
	# coûtait 1,5 s pour le grand canyon).
	for k in fond:
		for y in range(int(fond[k]), int(v["degage"]) + 1):
			b.vider(k.x, y, k.y)
	if v["fond"]:
		for k in fond:
			if int(fond[k]) == -P:
				b.case(k.x, -P - 1, k.y, "sable")
