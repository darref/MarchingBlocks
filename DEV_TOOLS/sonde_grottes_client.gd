extends SceneTree
## SONDE — les grottes sous l'île du monde client (`batir_monde_client.gd`, `_les_grottes`), sans l'appli : le relief seul,
## puis, recompté ICI (pas par les fonctions du bâtisseur) :
## (1) ÉTANCHE — la mer, remplie depuis les bords et le fond d'une boîte autour de l'île (six voisins, sous le niveau),
##     n'entre dans aucune case de grotte ;
## (2) aucun contact par une arête dans la boîte des grottes ;
## (3) RELIÉ — depuis le ciel au-dessus du gouffre, à travers le vide (six voisins), on atteint chaque salle, la rampe
##     et la salle du tunnel ;
## (4) le toit : aucune case de grotte à moins de trois du dessus, hors du gouffre et de la rampe.
##   godot --headless --path . --script res://DEV_TOOLS/sonde_grottes_client.gd

const SIX := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

func _initialize() -> void:
	var B: Script = load("res://DEV_TOOLS/batir_monde_client.gd")
	var b = B.new()
	b._dossier_mc = OS.get_user_data_dir().path_join("sonde_grottes")
	DirAccess.make_dir_recursive_absolute(b._dossier_mc)
	var t0 := Time.get_ticks_msec()
	b._relief_monde()
	print("relief et grottes : %d ms, %d cases de grotte" % [Time.get_ticks_msec() - t0, b._grotte.size()])
	var echecs := 0
	var lo := Vector3i(1 << 20, 1 << 20, 1 << 20)
	var hi := -lo
	for c in b._grotte:
		lo = lo.min(c)
		hi = hi.max(c)
	# (1) la mer
	var blo := Vector3i(-92, mini(lo.y, -10) - 6, -92)
	var bhi := Vector3i(92, B.MER, 125)
	var mer := {}
	var pile: Array = []
	for x in range(blo.x, bhi.x + 1):
		for y in range(blo.y, bhi.y + 1):
			pile.append(Vector3i(x, y, blo.z))
			pile.append(Vector3i(x, y, bhi.z))
	for z in range(blo.z, bhi.z + 1):
		for y in range(blo.y, bhi.y + 1):
			pile.append(Vector3i(blo.x, y, z))
			pile.append(Vector3i(bhi.x, y, z))
	while not pile.is_empty():
		var c: Vector3i = pile.pop_back()
		if mer.has(c) or c.x < blo.x or c.x > bhi.x or c.y < blo.y or c.y > bhi.y or c.z < blo.z or c.z > bhi.z:
			continue
		if b._plein(c):
			continue
		mer[c] = true
		for d in SIX:
			pile.append(c + d)
	var noyees := 0
	for c in b._grotte:
		if mer.has(c):
			noyees += 1
	print("(1) mer : %d cases ; cases de grotte noyées : %d sur %d" % [mer.size(), noyees, b._grotte.size()])
	if noyees > 0:
		echecs += 1
	# (2) contacts par une arête
	var contacts := 0
	for x in range(lo.x - 3, hi.x + 3):
		for y in range(lo.y - 3, hi.y + 4):
			for z in range(lo.z - 3, hi.z + 3):
				var a := Vector3i(x, y, z)
				for pl in [[Vector3i(1,0,0), Vector3i(0,1,0)], [Vector3i(1,0,0), Vector3i(0,0,1)], [Vector3i(0,1,0), Vector3i(0,0,1)]]:
					var pa: bool = b._plein(a)
					if pa == b._plein(a + pl[0] + pl[1]) and b._plein(a + pl[0]) == b._plein(a + pl[1]) and pa != b._plein(a + pl[0]):
						contacts += 1
	print("(2) contacts par une arête dans la boîte des grottes : %d" % contacts)
	if contacts > 0:
		echecs += 1
	# (3) relié : depuis le ciel au-dessus du gouffre
	var g: Vector3 = B.GROTTE_GOUFFRE
	var depart := Vector3i(int(g.x), 40, int(g.y))
	var vu := {}
	pile = [depart]
	while not pile.is_empty():
		var c: Vector3i = pile.pop_back()
		if vu.has(c) or c.y > 40 or c.y < lo.y - 2 or c.x < -95 or c.x > 95 or c.z < -95 or c.z > 130:
			continue
		if b._plein(c) or mer.has(c):
			continue
		vu[c] = true
		for d in SIX:
			pile.append(c + d)
	var non_atteintes := 0
	for c in b._grotte:
		if not vu.has(c):
			non_atteintes += 1
	print("(3) cases de grotte non atteintes depuis le ciel du gouffre : %d" % non_atteintes)
	for sa in B.GROTTE_SALLES:
		var n := 0
		for c in b._grotte:
			if Vector3(c).distance_to(sa[2]) < 4.0 and vu.has(c):
				n += 1
		print("    %s : %d cases atteintes près du centre" % [sa[0], n])
	var salle_tunnel := vu.has(Vector3i(14, -3, 44))
	print("    salle du tunnel atteinte : %s" % salle_tunnel)
	if non_atteintes > 0 or not salle_tunnel:
		echecs += 1
	# (4) le toit
	var minces := 0
	for c in b._grotte:
		var k := Vector2i(c.x, c.z)
		if b._trou_ciel.has(k):
			continue
		if c.y > int(b._h[k]) - 3:
			minces += 1
	print("(4) cases de grotte à moins de trois du dessus (rampe comprise) : %d" % minces)
	var par := {}
	for c in b._grotte:
		par[b._grotte[c]] = int(par.get(b._grotte[c], 0)) + 1
	print("thèmes du creux : ", par)
	var paroi := {}
	for c in b._theme_case:
		paroi[b._theme_case[c]] = int(paroi.get(b._theme_case[c], 0)) + 1
	print("thèmes de la paroi : ", paroi)
	var total := 0
	for k in b._h:
		for y in range(int(b._bas.get(k, 0)), int(b._h[k]) + 1):
			if not b._air.has(Vector3i(k.x, y, k.y)):
				total += 1
	print("cases pleines du monde (hors verre) : %d ; boîte des grottes %s → %s" % [total, lo, hi])
	print("VERDICT : %s" % ("OK" if echecs == 0 else "ÉCHEC (%d)" % echecs))
	quit(1 if echecs > 0 else 0)
