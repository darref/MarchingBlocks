extends "res://app/preshapes/forme.gd"
## LE TEMPLE À COLONNADE : un podium à marches, une rangée de colonnes tout autour (ou en façade), la cella fermée au
## milieu, un toit plat ou à deux pentes.


func _init() -> void:
	id = "temple"
	nom = "Colonnade temple"
	famille = "antique"
	aide = "A stepped podium, columns all around or at the front, a closed inner room, a flat or pitched roof."


func facteurs() -> Array:
	return [
		f("largeur", "Width", 7, 64, 21, "Across x."),
		f("profondeur", "Depth", 7, 80, 31, "Across z."),
		f("podium", "Podium", 0, 6, 2, "The stepped base, in cells high."),
		f("colonnes", "Column height", 3, 20, 7, "From the floor to the beam."),
		f("espacement", "Spacing", 2, 6, 3, "From one column to the next."),
		f("epaisseur", "Column width", 1, 2, 1, "One or two cells."),
		choix("colonnade", "Colonnade", ["All around", "Front only", "Front and back"], 0, "Where the columns stand."),
		coche("cella", "Inner room", true, "A walled room inside the colonnade."),
		choix("toit", "Roof", ["Pitched", "Flat", "None (ruin)"], 0, "The roof."),
	]


func packs() -> Array:
	return [
		["Parthenon", {"largeur": 31, "profondeur": 61, "podium": 3, "colonnes": 9, "espacement": 3, "epaisseur": 2}],
		["Shrine", {"largeur": 11, "profondeur": 13, "colonnade": 1, "colonnes": 5}],
		["Ruined temple", {"toit": 2, "cella": false}],
	]


func construire(v: Dictionary, b: Bati, _rng: RandomNumberGenerator) -> void:
	var rx := int(v["largeur"]) / 2
	var rz := int(v["profondeur"]) / 2
	var P := int(v["podium"])
	# Le podium : chaque marche rentre d'une case.
	for i in P:
		b.boite(Vector3i(-rx - P + i, i, -rz - P + i), Vector3i(rx + P - i, i, rz + P - i), "pierre")
	var y0 := P
	var C := int(v["colonnes"])
	var e := int(v["epaisseur"])
	var pas := int(v["espacement"]) + e - 1
	var mode := int(v["colonnade"])
	var points: Array = []
	for x in range(-rx, rx + 1 - (e - 1), pas):
		points.append(Vector2i(x, rz - e + 1))
		if mode != 1:
			points.append(Vector2i(x, -rz))
	if mode == 0:
		for z in range(-rz, rz + 1 - (e - 1), pas):
			points.append(Vector2i(-rx, z))
			points.append(Vector2i(rx - e + 1, z))
	for p in points:
		b.boite(Vector3i(p.x, y0, p.y), Vector3i(p.x + e - 1, y0 + C - 1, p.y + e - 1), "pierre")
	if v["cella"]:
		var cx := maxi(1, rx - 3)
		var cz := maxi(1, rz - 4)
		for x in range(-cx, cx + 1):
			for z in range(-cz, cz + 1):
				if absi(x) == cx or absi(z) == cz:
					b.boite(Vector3i(x, y0, z), Vector3i(x, y0 + C - 1, z), "pierre")
		b.vider_boite(Vector3i(-1, y0, cz), Vector3i(1, y0 + mini(3, C - 1), cz))
	var toit := int(v["toit"])
	if toit == 2:
		return
	# L'entablement : une poutre qui fait le tour, puis le toit.
	var yt := y0 + C
	b.boite(Vector3i(-rx, yt, -rz), Vector3i(rx, yt, rz), "pierre")
	if toit == 0:
		for k in range(1, rx + 2):
			var r := rx + 1 - k
			if r < 0:
				break
			b.boite(Vector3i(-r, yt + k, -rz), Vector3i(r, yt + k, rz), "toit")
	else:
		b.boite(Vector3i(-rx, yt + 1, -rz), Vector3i(rx, yt + 1, rz), "toit")
