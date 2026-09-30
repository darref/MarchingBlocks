extends SceneTree
## SONDE — une tuile par clé, en copies liées au témoin : le témoin prouve-t-il TOUS les raccords ?
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_raccords_lies.gd
##
## Le témoin devient le monde peint de sa propre forme, chaque clé y montrant SA tuile. Un joint du
## témoin (deux sommets voisins) étanche prouve que deux faces de tuile ont la même section. Pour qu'un
## monde QUELCONQUE soit étanche, il faut que toutes les faces d'un même seau de `verifier_sections`
## (axe, motif vu du plan) aient la même section : donc que, dans chaque seau, les nœuds
## (clé, pose, face) soient RELIÉS par des joints du témoin (l'égalité est transitive).
##
## ⚠ Un joint vu au témoin vaut aussi pour ses quarts de tour, MAIS seulement si le peintre pose les
## deux tuiles tournées par la même rotation (base(Q·b) = Q·base(b)). Sinon — classe symétrique dont la
## tuile ne l'est pas —, le joint tourné est un autre fait, que le témoin ne montre pas.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const TR := preload("res://addons/marchingblocks_core/tranchage.gd")

var _parent := {}

func _trouver(n: String) -> String:
	while _parent[n] != n:
		_parent[n] = _parent[_parent[n]]
		n = _parent[n]
	return n

func _unir(a: String, b: String) -> void:
	_parent[_trouver(a)] = _trouver(b)


func _initialize() -> void:
	var t: Dictionary = BM.cases(0)
	var plafond: int = MB.plafond_de(t)
	var grille := GridMap.new()
	var base_de := {}   # bits → base du peintre
	for b in 256:
		var r: Dictionary = MB.classer(b)
		if r["surface"]:
			base_de[b] = grille.get_basis_with_orthogonal_index(r["orientation"])
	grille.free()

	# Les sommets du témoin peint et leur clé (bords compris : le témoin lié les montre aussi).
	var sommets := {}
	for c in t:
		for s in MB.sommets_de(c):
			sommets[s] = true
	var cle_de := {}
	var bits_de := {}
	for s in sommets:
		var r: Dictionary = TR.cle_du_sommet(t, s, plafond)
		if not r.is_empty():
			cle_de[s] = r["cle"]
			bits_de[s] = r["bits"]
	var cles := {}
	for s in cle_de:
		cles[cle_de[s]] = MB.classer(bits_de[s])["classe"]
	print("sommets à surface du témoin peint : %d, clés : %d" % [cle_de.size(), cles.size()])

	# Les nœuds possibles dans un monde : chaque clé, chaque pose, chaque face au motif ni vide ni plein.
	var seau_de := {}
	var noeuds_par_seau := {}
	for cle in cles:
		for pose in TR._poses_de(cles[cle]):
			var b: int = pose["bits"]
			for axe in 3:
				for cote in [0, 1]:
					var m: int = TR._motif_de_face(b, axe, cote)
					if m == 0 or m == 15:
						continue
					var n := "%s|%d|%d|%d" % [cle, b, axe, cote]
					_parent[n] = n
					var sk := "%d|%d" % [axe, m]
					seau_de[n] = sk
					if not noeuds_par_seau.has(sk):
						noeuds_par_seau[sk] = []
					noeuds_par_seau[sk].append(n)

	var quarts: Array = []
	for q in 4:
		quarts.append(Basis(Vector3.UP, q * PI / 2.0))
	var joints := 0
	var tournes_gardes := 0
	var tournes_refuses := 0
	var avec_rotations := "rotations" in OS.get_cmdline_user_args() or true
	for s in cle_de:
		for axe in 3:
			var e := Vector3i.ZERO
			e[axe] = 1
			var w: Vector3i = s + e
			if not cle_de.has(w):
				continue
			var m: int = TR._motif_de_face(bits_de[s], axe, 1)
			if m == 0 or m == 15:
				continue
			joints += 1
			for q in 4:
				var Q: Basis = quarts[q]
				var bs: int = _tourner(bits_de[s], Q)
				var bw: int = _tourner(bits_de[w], Q)
				var d: Vector3 = (Q * Vector3(e)).round()
				var axe2: int = 0 if absf(d.x) > 0.5 else (1 if absf(d.y) > 0.5 else 2)
				var cote_s: int = 1 if d[axe2] > 0 else 0
				if q > 0:
					if not (_egales(base_de[bs], Q * base_de[bits_de[s]]) and _egales(base_de[bw], Q * base_de[bits_de[w]])):
						tournes_refuses += 1
						continue
					tournes_gardes += 1
				var na := "%s|%d|%d|%d" % [cle_de[s], bs, axe2, cote_s]
				var nb := "%s|%d|%d|%d" % [cle_de[w], bw, axe2, 1 - cote_s]
				if not _parent.has(na) or not _parent.has(nb):
					push_error("nœud inconnu : %s / %s" % [na, nb])
					continue
				assert(seau_de[na] == seau_de[nb])
				_unir(na, nb)
	print("joints du témoin (motif ni vide ni plein) : %d ; quarts de tour transférés %d, refusés %d"
		% [joints, tournes_gardes, tournes_refuses])

	var seaux_ok := 0
	var total_noeuds := 0
	var isoles := 0
	var fautifs: Array = []
	for sk in noeuds_par_seau:
		var liste: Array = noeuds_par_seau[sk]
		total_noeuds += liste.size()
		var comps := {}
		for n in liste:
			comps[_trouver(n)] = int(comps.get(_trouver(n), 0)) + 1
		for c in comps:
			if comps[c] == 1:
				isoles += 1
		if comps.size() == 1:
			seaux_ok += 1
		else:
			var grand := ""
			for c in comps:
				if grand == "" or comps[c] > comps[grand]:
					grand = c
			for n in liste:
				if _trouver(n) != grand:
					var p: PackedStringArray = n.split("|")
					print("    hors du gros morceau, seau %s : %s  pose %s  face %s%s" % [sk, p[0], p[1], "xyz"[int(p[2])], "+" if p[3] == "1" else "-"])
			fautifs.append([sk, liste.size(), comps.size(), comps.values()])
	fautifs.sort_custom(func(a, b): return a[2] > b[2])
	print("seaux : %d, reliés d'un seul tenant : %d ; nœuds : %d, nœuds isolés : %d"
		% [noeuds_par_seau.size(), seaux_ok, total_noeuds, isoles])
	for f in fautifs:
		print("  seau %-6s  %3d nœuds en %2d morceaux  %s" % [f[0], f[1], f[2], f[3]])
	# Contre-mesure : la fonction du cœur, qui doit rendre la même chose.
	var coeur: Dictionary = TR.raccords_du_temoin(t)
	print("cœur : seaux %d, reliés %d, morceaux en trop %d, nœuds hors du gros morceau %d" % [coeur["seaux"],
		coeur["relies"], coeur["en_trop"], coeur["morceaux"].reduce(func(a, m): return a + m["noeuds"].size(), 0)])
	quit(0)


# Les bits d'une configuration tournée par Q autour du centre du sommet.
func _tourner(bits: int, Q: Basis) -> int:
	var sortie := 0
	for t in 8:
		if bits & (1 << t) == 0:
			continue
		var c: Vector3 = Q * (Vector3(MB.COINS[t]) - Vector3(0.5, 0.5, 0.5)) + Vector3(0.5, 0.5, 0.5)
		var ci := Vector3i(c.round())
		for u in 8:
			if MB.COINS[u] == ci:
				sortie |= 1 << u
	return sortie


func _egales(a: Basis, b: Basis) -> bool:
	return (a.x - b.x).length() < 1e-4 and (a.y - b.y).length() < 1e-4 and (a.z - b.z).length() < 1e-4
