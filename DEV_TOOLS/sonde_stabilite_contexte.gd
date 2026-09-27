extends SceneTree
##
## SONDE — le contexte d'un sommet est-il le MÊME dans le bloc maître et dans le monde peint ?
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_stabilite_contexte.gd
##
## ⚠ ELLE NE MODIFIE RIEN.
##
## ── POURQUOI ELLE DÉCIDE DE TOUT LE PLAN À DEUX CONTEXTES ───────────────────────────────────────────
##
## Le contexte est calculé DEUX FOIS, à deux échelles :
##   • à la RÉCOLTE, sur le bloc maître de 7³ — pour savoir quelle tuile est « grotte » ;
##   • à la PEINTURE, sur le monde — pour savoir laquelle poser.
##
## ⚠ Un bloc de 7³ ne porte que ~3 cases de roche au-dessus d'une galerie ; le monde peint en aura
## vingt. **Si les deux calculs ne classent pas pareil, l'artiste sculpte une tuile de grotte que le
## pinceau ne posera jamais dans une grotte** — et rien ne le signalerait : la couverture resterait
## « complète », le rendu serait faux. C'est la forme exacte du défaut n°2, déplacée d'un cran.
##
## ── CE QU'ELLE FAIT ─────────────────────────────────────────────────────────────────────────────────
##
## Une même forme, classée deux fois : seule dans sa boîte de 7³, puis ENROBÉE de roche au centre d'un
## monde de 21³. On compte les sommets qui changent d'avis, pour deux critères :
##   (B) ROCHE AU-DESSUS — binaire, donc a priori stable à l'échelle ;
##   (C) CIEL VU > seuil — continu, donc a priori SENSIBLE à l'épaisseur de roche disponible.

const MB := preload("res://addons/marching_blocks_plugin_godot/marching_blocks.gd")

const COTE := 7
const MARGE := 7               # l'épaisseur de roche ajoutée autour, dans le grand monde
const SEUIL_CIEL := 0.10       # au-dessus, on est dehors

var _directions: Array = []


func _initialize() -> void:
	print("=== SONDE — LA STABILITÉ DU CONTEXTE ENTRE LES DEUX ÉCHELLES ===\n")
	for dx in range(-2, 3):
		for dy in range(1, 3):
			for dz in range(-2, 3):
				_directions.append(Vector3(dx, dy, dz).normalized())

	# ── LA FORME : un massif de 7³ avec une galerie horizontale et un plateau irrégulier ────────────
	var petit := {}
	for x in COTE:
		for z in COTE:
			var h: int = 4 if (x + z) % 3 != 0 else 5
			for y in range(0, h):
				petit[Vector3i(x, y, z)] = true
	# la galerie : elle traverse en z, à y = 1-2, en x = 3
	for z in COTE:
		for y in [1, 2]:
			petit.erase(Vector3i(3, y, z))

	print("   forme d'essai : %d cases pleines sur %d" % [petit.size(), COTE * COTE * COTE])

	# ── LE MÊME BLOC, ENROBÉ DE ROCHE AU CENTRE D'UN GRAND MONDE ───────────────────────────────────
	var grand_n: int = COTE + 2 * MARGE
	var grand := {}
	for x in grand_n:
		for z in grand_n:
			for y in range(0, MARGE + COTE):
				grand[Vector3i(x, y, z)] = true
	# on remplace le cube central par la forme d'essai
	for x in COTE:
		for y in COTE:
			for z in COTE:
				var c := Vector3i(x + MARGE, y + MARGE, z + MARGE)
				if petit.has(Vector3i(x, y, z)):
					grand[c] = true
				else:
					grand.erase(c)

	print("   monde d'enrobage : %d³, la forme est au centre avec %d cases de roche autour\n"
		% [grand_n, MARGE])

	for critere in ["roche au-dessus", "ciel > seuil"]:
		var change := 0
		var compares := 0
		var petit_int := 0
		var grand_int := 0
		for vx in range(COTE - 1):
			for vy in range(COTE - 1):
				for vz in range(COTE - 1):
					var v := Vector3i(vx, vy, vz)
					var b: int = MB.bits(petit, v)
					if not MB.porte_une_surface(b):
						continue
					var a: String = _contexte(petit, v, COTE, critere)
					var g: String = _contexte(grand, v + Vector3i(MARGE, MARGE, MARGE),
						grand_n, critere)
					compares += 1
					if a == "int":
						petit_int += 1
					if g == "int":
						grand_int += 1
					if a != g:
						change += 1
		print("   critère « %s »" % critere)
		print("     %d sommets comparés — %d classés INTÉRIEUR seuls, %d une fois enrobés"
			% [compares, petit_int, grand_int])
		print("     ⚠ %d sommet(s) CHANGENT d'avis entre les deux échelles (%.0f %%)"
			% [change, 100.0 * float(change) / maxf(1.0, float(compares))])
	print("\n   ⚠ Un critère qui change d'avis fait sculpter des tuiles que le pinceau ne posera pas")
	print("     là où l'artiste les croyait destinées. Le critère retenu doit être celui qui bouge le")
	print("     moins — ou bien le contexte doit être DÉCLARÉ sur le bloc plutôt que déduit de lui.")
	quit(0)


## "int", "ext" ou "mixte".
func _contexte(pleines: Dictionary, v: Vector3i, n: int, critere: String) -> String:
	var dedans := 0
	var dehors := 0
	for t in 8:
		var q: Vector3i = v + MB.COINS[t]
		if pleines.has(q):
			continue
		var interieur: bool
		if critere == "roche au-dessus":
			interieur = _roche_dessus(pleines, q, n)
		else:
			interieur = _ciel(q, pleines, n) <= SEUIL_CIEL
		if interieur:
			dedans += 1
		else:
			dehors += 1
	if dedans > 0 and dehors == 0:
		return "int"
	if dehors > 0 and dedans == 0:
		return "ext"
	return "mixte"


func _roche_dessus(pleines: Dictionary, c: Vector3i, n: int) -> bool:
	for y in range(c.y + 1, n):
		if pleines.has(Vector3i(c.x, y, c.z)):
			return true
	return false


func _ciel(depart: Vector3i, pleines: Dictionary, n: int) -> float:
	var libres := 0
	for d in _directions:
		var dir: Vector3 = d
		var p := Vector3(depart) + Vector3(0.5, 0.5, 0.5)
		var echappe := true
		for pas in n * 3:
			p += dir * 0.5
			var c := Vector3i(floori(p.x), floori(p.y), floori(p.z))
			if c.x < 0 or c.y < 0 or c.z < 0 or c.x >= n or c.y >= n or c.z >= n:
				break
			if pleines.has(c):
				echappe = false
				break
		if echappe:
			libres += 1
	return float(libres) / float(_directions.size())
