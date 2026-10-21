extends "res://app/preshapes/forme.gd"
## L'AMPHITHÉÂTRE ET L'ARÈNE : une piste de sable, des gradins en anneaux qui montent, un mur extérieur percé de portes ;
## ovale (arène) ou en demi-cercle (théâtre).


func _init() -> void:
	id = "amphitheatre"
	nom = "Arena, theatre"
	famille = "antique"
	aide = "A sand floor, rings of seats rising around it, an outer wall with gates; an oval arena or a half-round theatre."


func facteurs() -> Array:
	return [
		f("largeur", "Floor width", 6, 64, 28, "The sand floor, across x."),
		f("profondeur", "Floor depth", 6, 64, 20, "The sand floor, across z."),
		f("gradins", "Rows", 1, 12, 6, "Rows of seats."),
		f("hauteur_rang", "Row height", 1, 3, 1, "Each row's rise."),
		f("largeur_rang", "Row depth", 1, 4, 2, "Each row's depth."),
		f("mur", "Outer wall", 0, 12, 3, "The wall above the top row."),
		f("portes", "Gates", 0, 8, 4, "Openings through the seats onto the floor."),
		choix("plan", "Plan", ["Oval arena", "Half-round theatre"], 0, "All around, or a half ring facing a stage."),
		f("fosse", "Sunken floor", 0, 6, 1, "How far the floor sinks below the ground."),
	]


func packs() -> Array:
	return [
		["Colosseum", {"largeur": 50, "profondeur": 34, "gradins": 12, "mur": 6, "portes": 4}],
		["Greek theatre", {"plan": 1, "largeur": 20, "profondeur": 20, "gradins": 12, "mur": 0, "portes": 2}],
		["Fighting pit", {"largeur": 14, "profondeur": 14, "gradins": 3, "fosse": 3, "portes": 1}],
	]


func construire(v: Dictionary, b: Bati, _rng: RandomNumberGenerator) -> void:
	var ax: float = v["largeur"] * 0.5
	var az: float = v["profondeur"] * 0.5
	var n := int(v["gradins"])
	var hr := int(v["hauteur_rang"])
	var lr := int(v["largeur_rang"])
	var F := int(v["fosse"])
	var demi := int(v["plan"]) == 1
	var ext := float(n * lr + 2)
	var caps: Array = []
	for i in int(v["portes"]):
		# Les portes, régulières : tout autour pour l'arène, sur le demi-anneau (z < 0) pour le théâtre.
		caps.append(-PI * (i + 0.5) / float(v["portes"]) if demi else TAU * (i + 0.5) / float(v["portes"]))
	var Hmax := n * hr
	for x in range(-ceili(ax + ext), ceili(ax + ext) + 1):
		for z in range(-ceili(az + ext), ceili(az + ext) + 1):
			if demi and z > 0:
				# Le théâtre : la scène, un plat de pierre devant les gradins.
				if absf(x) <= ax and z <= az * 0.5:
					b.colonne(x, z, -F, -F, "pierre", "pierre")
				continue
			# La distance au bord de la piste, en cases, le long de l'ellipse.
			var q := Vector2(x / ax, z / az).length()
			var dist := (q - 1.0) * minf(ax, az)
			if q <= 1.0:
				b.vider_boite(Vector3i(x, -F, z), Vector3i(x, Hmax + 2, z))
				b.case(x, -F - 1, z, "sable")
				continue
			if dist > ext:
				continue
			var ang := atan2(z, x)
			var porte := false
			for c in caps:
				if absf(wrapf(ang - float(c), -PI, PI)) * (minf(ax, az) + dist) < 1.6:
					porte = true
			var rang := int(dist) / lr
			if porte:
				b.vider_boite(Vector3i(x, -F, z), Vector3i(x, 2, z))
				if rang >= n:
					b.colonne(x, z, 3, Hmax + int(v["mur"]) - 1, "pierre", "pierre")
				continue
			if rang >= n:
				b.colonne(x, z, -F, Hmax + int(v["mur"]) - 1, "pierre", "pierre")
			else:
				b.colonne(x, z, -F, -F + (rang + 1) * hr - 1, "pierre", "pierre")
				b.vider_boite(Vector3i(x, -F + (rang + 1) * hr, z), Vector3i(x, Hmax + 2, z))
