extends SceneTree
## SONDE — ce que le peintre pose sur un monde peint : classes, contexte, exemplaires.
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_tuiles_falaise.gd -- <projet.mbproj>
const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const TR := preload("res://addons/marchingblocks_core/tranchage.gd")

func _initialize() -> void:
	var chemin: String = OS.get_cmdline_user_args()[0]
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	var couche: Dictionary = d["couches"][int(d.get("active", 0))]
	var pleines := {}
	var c: Array = couche["cases"]
	for e in c:
		if e is Array:
			pleines[Vector3i(int(e[0]), int(e[1]), int(e[2]))] = true
	if pleines.is_empty():
		for i in range(0, c.size(), 3):
			pleines[Vector3i(int(c[i]), int(c[i+1]), int(c[i+2]))] = true
	print("cases : ", pleines.size())
	# Comptes d'exemplaires : les sommets récoltables du témoin (huit cases DANS le bloc).
	var t: Dictionary = BM.cases(0)
	var lo := Vector3i(1 << 30, 1 << 30, 1 << 30)
	var hi := -lo
	for k in t:
		lo = lo.min(k); hi = hi.max(k)
	var plafond_t: int = MB.plafond_de(t)
	var comptes := {}
	var origines := {}
	for x in range(lo.x, hi.x):
		for y in range(lo.y, hi.y):
			for z in range(lo.z, hi.z):
				var v := Vector3i(x, y, z)
				var r: Dictionary = TR.cle_du_sommet(t, v, plafond_t)
				if r.is_empty():
					continue
				comptes[r["cle"]] = int(comptes.get(r["cle"], 0)) + 1
	var poses: Array = MB.poses(pleines, comptes)
	var par_classe := {}
	for p in poses:
		var k: String = "%s%s" % [p["nom"], " [dehors]" if p["dehors"] else ""]
		if not par_classe.has(k):
			par_classe[k] = {"n": 0, "ex": {}}
		par_classe[k]["n"] += 1
		par_classe[k]["ex"][p["k"]] = true
	var cles := par_classe.keys()
	cles.sort_custom(func(a, b): return par_classe[a]["n"] > par_classe[b]["n"])
	print("poses : ", poses.size())
	for k in cles:
		print("  %6d  %-40s exemplaires distincts %d / %d" % [par_classe[k]["n"], k, par_classe[k]["ex"].size(),
			int(comptes.get(k.replace(" [dehors]", MB.SUFFIXE_DEHORS if k.ends_with("]") else ""), 0))])
	# Deux parois droites : la falaise du fond (v.z = -18) et le bloc de devant (v.z = 14).
	var par_sommet := {}
	for p in poses:
		par_sommet[p["sommet"]] = p
	for zz in [-18, 14]:
		print("  --- paroi v.z = %d (classe, * = air libre, ~k = exemplaire)" % zz)
		for y in range(22, -7, -1):
			var ligne := "  y=%3d " % y
			for x in range(-4, 5):
				var p = par_sommet.get(Vector3i(x, y, zz))
				ligne += ("%-18s" % ("%s%s~%d" % [String(p["nom"]).trim_prefix("mb_"), "*" if p["dehors"] else "", p["k"]])) if p else "        .         "
			print(ligne)
	# ── PISTE : choisir l'exemplaire par le voisinage ÉLARGI (4³ cases autour du sommet).
	# Les exemplaires de chaque clé, dans l'ordre du balayage du trancheur (vx, vy, vz croissants).
	var ex_de := {}
	for x in range(lo.x, hi.x):
		for y in range(lo.y, hi.y):
			for z in range(lo.z, hi.z):
				var v := Vector3i(x, y, z)
				var r: Dictionary = TR.cle_du_sommet(t, v, plafond_t)
				if r.is_empty():
					continue
				if not ex_de.has(r["cle"]):
					ex_de[r["cle"]] = []
				ex_de[r["cle"]].append(_voisinage(t, v))
	for cle in ["mb_plaque_b2h2_dehors", "mb_plaque_b2h2"]:
		var parfaits := 0
		for vois in ex_de[cle]:
			if _distance(vois, _extrusion(vois)) == 0:
				parfaits += 1
		print("%s : %d exemplaires, dont %d au milieu d'une paroi DROITE (4³ = la paroi prolongée)" % [cle, ex_de[cle].size(), parfaits])
	for zz in [-18, 14]:
		var choisis := {}
		var dist := {}
		for p in poses:
			var s: Vector3i = p["sommet"]
			if s.z != zz or p["cle"] == "" or not String(p["nom"]).begins_with("mb_plaque_b2h2"):
				continue
			var w: Array = _voisinage(pleines, s)
			var meilleur := 999
			var lesquels: Array = []
			var liste: Array = ex_de[p["cle"]]
			for k in liste.size():
				var dd := _distance(w, liste[k])
				if dd < meilleur:
					meilleur = dd
					lesquels = [k]
				elif dd == meilleur:
					lesquels.append(k)
			dist[meilleur] = int(dist.get(meilleur, 0)) + 1
			for k in lesquels:
				choisis[k] = true
		print("paroi v.z = %d : distance au meilleur exemplaire %s ; exemplaires ex aequo retenus : %s" % [zz, dist, choisis.keys()])
	quit(0)


# 64 cases autour du sommet v (décalages -1..2), en tableau de booléens.
func _voisinage(pleines: Dictionary, v: Vector3i) -> Array:
	var a: Array = []
	for dx in range(-1, 3):
		for dy in range(-1, 3):
			for dz in range(-1, 3):
				a.append(pleines.has(v + Vector3i(dx, dy, dz)))
	return a


func _idx(dx: int, dy: int, dz: int) -> int:
	return ((dx + 1) * 4 + (dy + 1)) * 4 + (dz + 1)


# Le voisinage « prolongé » : chaque case extérieure copie la case du cœur 2³ la plus proche.
func _extrusion(a: Array) -> Array:
	var b: Array = []
	for dx in range(-1, 3):
		for dy in range(-1, 3):
			for dz in range(-1, 3):
				b.append(a[_idx(clampi(dx, 0, 1), clampi(dy, 0, 1), clampi(dz, 0, 1))])
	return b


# Distance de Hamming, minimum sur les quarts de tour autour de Y qui gardent le cœur identique.
func _distance(a: Array, b: Array) -> int:
	var meilleur := 999
	var r: Array = b
	for q in 4:
		var coeur_ok := true
		for dx in 2:
			for dy in 2:
				for dz in 2:
					if a[_idx(dx, dy, dz)] != r[_idx(dx, dy, dz)]:
						coeur_ok = false
		if coeur_ok:
			var n := 0
			for i in 64:
				if a[i] != r[i]:
					n += 1
			meilleur = mini(meilleur, n)
		# quart de tour autour de l'axe vertical du sommet : (dx, dz) -> (1 - dz, dx)
		var t2: Array = []
		t2.resize(64)
		for dx in range(-1, 3):
			for dy in range(-1, 3):
				for dz in range(-1, 3):
					t2[_idx(1 - dz, dy, dx)] = r[_idx(dx, dy, dz)]
		r = t2
	return meilleur
