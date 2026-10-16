extends SceneTree
## SONDE — le tunnel de verre du monde client (`batir_monde_client.gd`), sans l'appli : le relief seul, puis
## (1) le tube est-il ÉTANCHE — la mer, remplie depuis l'horizon (six voisins, sous le niveau), n'entre jamais dans le
## creux ; (2) aucun contact par une arête (recompté ici, sans `_sans_contact_autour`) ; (3) l'axe, la sortie, la salle.
##   godot --headless --path . --script res://DEV_TOOLS/sonde_tunnel_client.gd

func _initialize() -> void:
	var B: Script = load("res://DEV_TOOLS/batir_monde_client.gd")
	var b = B.new()
	b._dossier_mc = OS.get_user_data_dir().path_join("sonde_tunnel")
	DirAccess.make_dir_recursive_absolute(b._dossier_mc)
	b._relief_monde()
	var plein := func(c: Vector3i) -> bool: return b._plein(c)
	# (1) la mer depuis le bord de la bande du tunnel, sous le niveau, dans une boîte autour du tube
	var lo := Vector3i(B.TUNNEL_X - 20, B.BAS_PROFOND - 1, 30)
	var hi := Vector3i(B.TUNNEL_X + 20, B.MER, 120)
	var mer := {}
	var pile: Array = []
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			pile.append(Vector3i(x, y, hi.z))
	while not pile.is_empty():
		var c: Vector3i = pile.pop_back()
		if mer.has(c) or c.x < lo.x or c.x > hi.x or c.y < lo.y or c.y > hi.y or c.z < lo.z or c.z > hi.z:
			continue
		if plein.call(c):
			continue
		mer[c] = true
		for d in [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,1,0), Vector3i(0,-1,0), Vector3i(0,0,1), Vector3i(0,0,-1)]:
			pile.append(c + d)
	var noyees := 0
	for c in b._air:
		if mer.has(c):
			noyees += 1
	print("mer : %d cases ; cases du creux noyées : %d (sur %d)" % [mer.size(), noyees, b._air.size()])
	# (2) contacts par une arête autour du tunnel
	var contacts := 0
	var plo := Vector3i(B.TUNNEL_X - 10, -12, -25)
	var phi := Vector3i(B.TUNNEL_X + 12, 20, 120)
	for x in range(plo.x, phi.x):
		for y in range(plo.y, phi.y):
			for z in range(plo.z, phi.z):
				var a := Vector3i(x, y, z)
				for pl in [[Vector3i(1,0,0), Vector3i(0,1,0)], [Vector3i(1,0,0), Vector3i(0,0,1)], [Vector3i(0,1,0), Vector3i(0,0,1)]]:
					var pa: bool = plein.call(a)
					var pb: bool = plein.call(a + pl[0])
					var pd: bool = plein.call(a + pl[1])
					var pe: bool = plein.call(a + pl[0] + pl[1])
					if pa == pe and pb == pd and pa != pb:
						contacts += 1
	print("contacts par une arête autour du tunnel : %d" % contacts)
	# (3) l'axe : chaque point du chemin échantillonné tous les 0,25 est dans le creux
	var hors := 0
	var ch: Array = b._axe_tunnel
	for i in ch.size() - 1:
		var n := int((ch[i + 1] - ch[i]).length() * 4)
		for k in n:
			var p: Vector3 = ch[i].lerp(ch[i + 1], float(k) / n)
			var c := Vector3i(floori(p.x), floori(p.y), floori(p.z))
			if not b._air.has(c):
				hors += 1
	print("axe : %s ; points hors du creux : %d" % [ch, hors])
	# une coupe à z = 90 (sous la mer), x autour du tube
	for y in range(8, -10, -1):
		var l := "%3d " % y
		for x in range(B.TUNNEL_X - 6, B.TUNNEL_X + 7):
			var c := Vector3i(x, y, 90)
			l += "#" if b._verre.has(c) else ("o" if b._air.has(c) else ("s" if plein.call(c) else ("~" if mer.has(c) else ".")))
		print(l)
	quit(0)
