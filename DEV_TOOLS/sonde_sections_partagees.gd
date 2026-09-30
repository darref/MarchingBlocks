extends SceneTree
## SONDE — les SECTIONS PARTAGÉES : peut-on lier les sommets de bord des tuiles entre elles ?
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_sections_partagees.gd
##
## Jordan (30 septembre 2026) : les sommets du bord d'une paroi doivent être partagés avec ceux du bord
## correspondant d'un coin, d'une lèvre de plateau… — la seule manière d'avoir un témoin étanche PAR
## CONSTRUCTION. Avant d'écrire quoi que ce soit, on mesure :
##
##   1. LES CLASSES. Un nœud = une face de RÉFÉRENCE d'une tuile (clé, axe, signe). Sous chaque pose que le
##      peintre donne à la clé, cette face tombe dans un seau de `verifier_sections` (axe du monde, motif des
##      quatre cases vu du plan) : toutes les faces d'un seau se font face dans un monde, donc partagent LA
##      section. Chaque appartenance porte une carte 2D (repère de la face de référence → repère du seau),
##      une permutation signée. Les classes = composantes ; un cycle dont la carte composée n'est pas
##      l'identité impose une SYMÉTRIE à la section de la classe.
##   2. LES SOMMETS. Dans chaque classe, les sommets de bord de chaque face, ramenés dans le repère de la
##      racine : chaque point doit exister dans TOUTES les faces de la classe (sinon il faudra fendre une
##      arête), et l'ensemble doit être invariant par les symétries de la classe.
##   3. LES SOMMETS D'ARÊTE DE CASE : sur deux plans à la fois, ils ne pourront glisser que le long de l'arête.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const TR := preload("res://addons/marchingblocks_core/tranchage.gd")
const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")

const EPS := 0.0005


func _initialize() -> void:
	var t: RefCounted = TL.depuis_le_temoin_calcule()
	# CONTRÔLE NÉGATIF (« -- controle ») : un seul sommet de bord de la paroi décalé d'un centième DANS son
	# plan. L'instrument doit le voir — sinon ses « 0 absence » ne prouveraient rien.
	if "controle" in OS.get_cmdline_user_args():
		var m: RefCounted = t.tuiles["mb_plaque_b2h2_dehors"]
		for i in m.sommets.size():
			if absf(absf(m.sommets[i].x) - 0.5) < EPS and absf(absf(m.sommets[i].y) - 0.5) > EPS:
				m.sommets[i] += Vector3(0, 0.01, 0)
				print("CONTRÔLE : sommet %d de la paroi décalé de 0,01 dans son plan (x = %.2f)" % [i, m.sommets[i].x])
				break
	var bits_de := {}
	for c in MB.classes():
		bits_de[c["nom"]] = c["bits"]

	# ── 1. Les nœuds et leurs appartenances aux seaux ─────────────────────────────────────────────────
	var membres_du_seau := {}   # "axe|motif" → [{noeud, carte: [[a,b],[c,d]]}]
	var noeuds := {}            # "clé|axe|signe" → true (faces au motif ni vide ni plein, sous une pose au moins)
	var vides_non_vides := 0
	for cle in t.tuiles:
		var classe: int = MB.classer(bits_de[MB.nom_nu(cle)])["classe"]
		for pose in TR._poses_de(classe):
			var b: int = pose["bits"]
			var base: Basis = pose["base"]
			for axe_r in 3:
				for signe in [-1, 1]:
					var e := Vector3.ZERO
					e[axe_r] = float(signe)
					var d: Vector3 = (base * e).round()
					var axe_w: int = 0 if absf(d.x) > 0.5 else (1 if absf(d.y) > 0.5 else 2)
					var cote_w: int = 1 if d[axe_w] > 0 else 0
					var motif: int = TR._motif_de_face(b, axe_w, cote_w)
					var n := "%s|%d|%d" % [cle, axe_r, signe]
					if motif == 0 or motif == 15:
						continue
					noeuds[n] = true
					var sk := "%d|%d" % [axe_w, motif]
					if not membres_du_seau.has(sk):
						membres_du_seau[sk] = []
					membres_du_seau[sk].append({"noeud": n, "carte": _carte(base, axe_r, axe_w)})

	# Union : chaque seau relie ses membres. Transformation de chaque nœud vers la racine de sa classe.
	# Un nœud peut appartenir à plusieurs seaux (une pose par seau) : c'est là que les classes s'élargissent.
	var adj := {}   # nœud → [[voisin, carte nœud→voisin]]
	for sk in membres_du_seau:
		var liste: Array = membres_du_seau[sk]
		var ref: Dictionary = liste[0]
		for m in liste:
			# nœud → seau : m.carte ; seau → ref : inverse(ref.carte)
			var vers_ref: Array = _compose(_inverse(ref["carte"]), m["carte"])
			_lier(adj, m["noeud"], ref["noeud"], vers_ref)
			_lier(adj, ref["noeud"], m["noeud"], _inverse(vers_ref))
	var classe_de := {}
	var carte_de := {}     # nœud → carte vers la racine
	var classes: Array = []
	for n in noeuds:
		if classe_de.has(n):
			continue
		var k := classes.size()
		var info := {"racine": n, "noeuds": [n], "symetries": {"1,0,0,1": [[1, 0], [0, 1]]}}
		classes.append(info)
		classe_de[n] = k
		carte_de[n] = [[1, 0], [0, 1]]
		var file: Array = [n]
		while not file.is_empty():
			var x: String = file.pop_front()
			for arc in adj.get(x, []):
				var y: String = arc[0]
				# carte y→racine = carte x→racine ∘ carte y→x ; arc porte x→y, donc y→x = inverse
				var c_y: Array = _compose(carte_de[x], _inverse(arc[1]))
				if not classe_de.has(y):
					classe_de[y] = k
					carte_de[y] = c_y
					info["noeuds"].append(y)
					file.append(y)
				else:
					# Deux chemins : la symétrie imposée = c_y ∘ inverse(carte_de[y]) (dans le repère de la racine)
					var s: Array = _compose(c_y, _inverse(carte_de[y]))
					info["symetries"][_cle_carte(s)] = s
	var tailles: Array = classes.map(func(c): return (c["noeuds"] as Array).size())
	tailles.sort()
	var par_symetrie := {}
	for c in classes:
		var g: int = _groupe(c["symetries"].values()).size()
		par_symetrie[g] = int(par_symetrie.get(g, 0)) + 1
	print("── 1. LES CLASSES ──")
	print("   faces de référence à motif ni vide ni plein : %d ; seaux : %d ; classes : %d" % [noeuds.size(), membres_du_seau.size(), classes.size()])
	print("   tailles des classes : %s" % [tailles])
	print("   classes par taille du groupe de symétries imposé : %s (1 = aucune contrainte)" % [par_symetrie])

	# ── 2. Les sommets de bord ────────────────────────────────────────────────────────────────────────
	print("── 2. LES SOMMETS DE BORD ──")
	var classes_justes := 0
	var orphelins_total := 0
	var asym_total := 0
	var sommets_total := 0
	var distincts_total := 0
	var detail: Array = []
	for k in classes.size():
		var c: Dictionary = classes[k]
		var points_par_face := {}
		var tous := {}
		for n in c["noeuds"]:
			var p: PackedStringArray = String(n).split("|")
			var tuile: RefCounted = t.tuiles[p[0]]
			var axe_r := int(p[1])
			var signe := int(p[2])
			var ens := {}
			for s in tuile.sommets:
				if absf(s[axe_r] - 0.5 * signe) < EPS:
					var q := _dans_la_racine(s, axe_r, carte_de[n])
					ens[q] = true
					tous[q] = true
			points_par_face[n] = ens
			sommets_total += ens.size()
		var orphelins := 0
		for q in tous:
			for n in c["noeuds"]:
				if not (points_par_face[n] as Dictionary).has(q):
					orphelins += 1
		var asym := 0
		for s in _groupe(c["symetries"].values()):
			for q in tous:
				var r := _appliquer(s, q)
				if not tous.has(r):
					asym += 1
		orphelins_total += orphelins
		asym_total += asym
		distincts_total += tous.size()
		var cles_de_la_classe := {}
		for n in c["noeuds"]:
			cles_de_la_classe[String(n).split("|")[0]] = true
		detail.append("%d faces · %d tuiles · %d points · symétries %d" % [(c["noeuds"] as Array).size(),
			cles_de_la_classe.size(), tous.size(), _groupe(c["symetries"].values()).size()])
		if orphelins == 0 and asym == 0:
			classes_justes += 1
		elif k < 60:
			print("   classe %d (%d faces, %d points, groupe %d) : %d absences, %d points hors symétrie — ex. %s"
				% [k, (c["noeuds"] as Array).size(), tous.size(), _groupe(c["symetries"].values()).size(), orphelins, asym,
				(c["noeuds"] as Array).slice(0, 3)])
	print("   sommets de bord (par face) : %d ; classes où chaque point est dans chaque face et symétrique : %d / %d"
		% [sommets_total, classes_justes, classes.size()])
	print("   absences au total : %d ; points hors symétrie : %d" % [orphelins_total, asym_total])
	print("   POINTS DISTINCTS de tous les bords partagés : %d, répartis ainsi :" % distincts_total)
	for d in detail:
		print("      " + d)

	# ── 3. Les sommets d'arête de case, et les faces vides qui porteraient un bord ─────────────────────
	var sur_deux := 0
	var sur_trois := 0
	var bord_sur_face_morte := 0
	for cle in t.tuiles:
		for s in t.tuiles[cle].sommets:
			var n := 0
			for a in 3:
				if absf(absf(s[a]) - 0.5) < EPS:
					n += 1
			if n == 2:
				sur_deux += 1
			elif n == 3:
				sur_trois += 1
			for a in 3:
				for signe in [-1, 1]:
					if absf(s[a] - 0.5 * signe) < EPS and not noeuds.has("%s|%d|%d" % [cle, a, signe]):
						bord_sur_face_morte += 1
	print("── 3. ARÊTES ET COINS DE CASE ──")
	print("   sommets sur deux plans (arête de case) : %d ; sur trois (coin de case) : %d" % [sur_deux, sur_trois])
	print("   sommets posés sur une face de motif vide ou plein (qui devrait n'avoir aucun bord) : %d" % bord_sur_face_morte)
	quit(0)


## La carte 2D d'une face de référence (axe `axe_r`) vers le repère du seau (axe du monde `axe_w`).
## Repère 2D d'une face d'axe a : les deux AUTRES axes, dans l'ordre croissant (comme `Tranchage._section`).
func _carte(base: Basis, axe_r: int, axe_w: int) -> Array:
	var ur := _autres(axe_r)
	var uw := _autres(axe_w)
	var m := [[0, 0], [0, 0]]
	for j in 2:
		var e := Vector3.ZERO
		e[ur[j]] = 1.0
		var w: Vector3 = (base * e).round()
		for i in 2:
			m[i][j] = int(w[uw[i]])
	return m


func _autres(a: int) -> Array:
	return [1, 2] if a == 0 else ([0, 2] if a == 1 else [0, 1])


func _compose(a: Array, b: Array) -> Array:   # a ∘ b
	return [[a[0][0] * b[0][0] + a[0][1] * b[1][0], a[0][0] * b[0][1] + a[0][1] * b[1][1]],
		[a[1][0] * b[0][0] + a[1][1] * b[1][0], a[1][0] * b[0][1] + a[1][1] * b[1][1]]]


func _inverse(a: Array) -> Array:   # permutation signée : l'inverse est la transposée
	return [[a[0][0], a[1][0]], [a[0][1], a[1][1]]]


func _cle_carte(a: Array) -> String:
	return "%d,%d,%d,%d" % [a[0][0], a[0][1], a[1][0], a[1][1]]


func _groupe(generateurs: Array) -> Array:
	var vus := {"1,0,0,1": [[1, 0], [0, 1]]}
	var file: Array = [[[1, 0], [0, 1]]]
	while not file.is_empty():
		var x: Array = file.pop_front()
		for g in generateurs:
			var y := _compose(g, x)
			if not vus.has(_cle_carte(y)):
				vus[_cle_carte(y)] = y
				file.append(y)
	return vus.values()


func _lier(adj: Dictionary, a: String, b: String, carte: Array) -> void:
	if not adj.has(a):
		adj[a] = []
	adj[a].append([b, carte])


func _dans_la_racine(s: Vector3, axe_r: int, carte: Array) -> Vector2i:
	var u := _autres(axe_r)
	var p := Vector2(s[u[0]], s[u[1]])
	return _appliquer(carte, Vector2i((p * 10000.0).round()))


func _appliquer(m: Array, q: Vector2i) -> Vector2i:
	return Vector2i(m[0][0] * q.x + m[0][1] * q.y, m[1][0] * q.x + m[1][1] * q.y)
