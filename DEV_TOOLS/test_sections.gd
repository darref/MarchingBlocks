extends SceneTree
## TEST — les SECTIONS PARTAGÉES (`sections.gd`) : un bord de tuile est une donnée partagée.
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_sections.gd
##
## ⚠ LES ATTENDUS NE PASSENT PAS PAR `sections.gd` (charte §6) :
##   • les classes : les chiffres de `sonde_sections_partagees.gd`, une implémentation écrite À PART ;
##   • les correspondants et l'étanchéité : les VRAIS JOINTS du témoin — deux occurrences voisines posées
##     dans le monde, et les sommets qui y coïncident (au dix-millième). Après un déplacement propagé, ces
##     paires doivent coïncider encore ; sans propagation (contrôle négatif), elles s'ouvrent.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const TR := preload("res://addons/marchingblocks_core/tranchage.gd")
const Sections := preload("res://addons/marchingblocks_core/sections.gd")

var _ok := 0
var _echecs := 0
var _premier := ""


func _initialize() -> void:
	print("=== TEST — les sections partagées ===\n")
	_les_classes()
	var t: RefCounted = TL.depuis_le_temoin_calcule()
	var paires: Array = _paires_des_joints(t)
	_les_correspondants(t, paires)
	_la_projection(t)
	_la_propagation_garde_les_joints(t, paires)
	_plusieurs_sources_un_mouvement(t, paires)
	_la_completion(t)
	var t2: RefCounted = TL.depuis_le_temoin_calcule()
	_boucher_les_trous(t2, Sections.new(t2))
	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	if _echecs > 0:
		print("PREMIER ÉCHEC — %s" % _premier)
	print("VERDICT : %s" % ("ÉCHEC" if _echecs > 0 else "OK"))
	quit(1 if _echecs > 0 else 0)


func _dire(condition: bool, quoi: String) -> void:
	if "dit" in OS.get_cmdline_user_args():
		print("  %s %s" % ["ok" if condition else "ÉCHEC", quoi])
	if condition:
		_ok += 1
	else:
		_echecs += 1
		if _premier == "":
			_premier = quoi
		if _echecs <= 12:
			print("  ÉCHEC — %s" % quoi)


## Les chiffres de la sonde (écrite à part, 30 septembre 2026).
func _les_classes() -> void:
	var c: Dictionary = Sections.classes()
	_dire((c["classe_de"] as Dictionary).size() == 246, "246 faces de référence portent un bord (rend %d)" % (c["classe_de"] as Dictionary).size())
	var tailles: Array = (c["noeuds"] as Array).map(func(l): return (l as Array).size())
	tailles.sort()
	_dire(tailles == [12, 18, 18, 24, 26, 27, 27, 30, 32, 32], "10 classes, de la taille mesurée par la sonde (%s)" % [tailles])
	var groupes := {}
	for g in c["groupes"]:
		groupes[(g as Array).size()] = int(groupes.get((g as Array).size(), 0)) + 1
	_dire(groupes == {1: 8, 2: 2}, "8 classes sans contrainte, 2 d'une symétrie d'ordre 2 (%s)" % [groupes])


## LES VRAIS JOINTS : pour chaque paire d'occurrences voisines, les sommets des deux tuiles qui coïncident
## DANS LE MONDE sur leur plan commun. [{a: [clé, i], b: [clé, i], pa: pose, pb: pose}].
func _paires_des_joints(t: RefCounted) -> Array:
	var occ := {}
	for o in t.occurrences:
		occ[o["sommet"]] = o
	var paires: Array = []
	var sans_partenaire := 0
	for s in occ:
		var oa: Dictionary = occ[s]
		for axe in 3:
			var e := Vector3i.ZERO
			e[axe] = 1
			if not occ.has(s + e):
				continue
			var ob: Dictionary = occ[s + e]
			var plan: float = float(s[axe]) + 1.5
			var ta: RefCounted = t.tuiles[oa["cle"]]
			var tb: RefCounted = t.tuiles[ob["cle"]]
			var index_b := {}
			for j in tb.sommets.size():
				index_b[Vector3i(((ob["pose"] as Transform3D) * tb.sommets[j] * 10000.0).round())] = j
			for i in ta.sommets.size():
				var pw: Vector3 = (oa["pose"] as Transform3D) * ta.sommets[i]
				if absf(pw[axe] - plan) > 0.0005:
					continue
				var k := Vector3i((pw * 10000.0).round())
				if index_b.has(k):
					paires.append({"a": [oa["cle"], i], "b": [ob["cle"], index_b[k]], "pa": oa["pose"], "pb": ob["pose"]})
				else:
					sans_partenaire += 1
	_dire(paires.size() > 1000 and sans_partenaire == 0,
		"le témoin calculé : %d paires de sommets aux joints, %d sans partenaire" % [paires.size(), sans_partenaire])
	return paires


func _les_correspondants(t: RefCounted, paires: Array) -> void:
	var s = Sections.new(t)
	var justes := 0
	for p in paires:
		var liste: Array = s.correspondants(p["a"][0], p["a"][1])
		for c in liste:
			if c["cle"] == p["b"][0] and c["i"] == p["b"][1]:
				justes += 1
				break
	_dire(justes == paires.size(), "chaque sommet d'un joint compte son partenaire parmi ses correspondants (%d / %d)" % [justes, paires.size()])


func _la_projection(t: RefCounted) -> void:
	var s = Sections.new(t)
	var face_seule := 0
	var arete := 0
	for cle in s.bords:
		for i in s.bords[cle]:
			var faces: Array = s.bords[cle][i]
			var d: Vector3 = s.projeter(cle, i, Vector3(0.11, 0.07, -0.05))
			var libres := 0
			for a in 3:
				if absf(d[a]) > 1e-9:
					libres += 1
			var plans := {}
			for f in faces:
				plans[f["axe"]] = true
			var normales_nulles := true
			for a in plans:
				normales_nulles = normales_nulles and absf(d[a]) < 1e-9
			if plans.size() == 1 and normales_nulles:
				face_seule += 1
			elif plans.size() == 2 and normales_nulles and libres <= 1:
				arete += 1
	var total := 0
	for cle in s.bords:
		total += (s.bords[cle] as Dictionary).size()
	_dire(face_seule + arete == total and arete > 0,
		"projeté, un sommet de bord reste dans son plan, et sur son arête s'il en touche deux (%d + %d / %d)" % [face_seule, arete, total])


## Chaque classe reçoit un déplacement (un sommet d'arête, un point fixé par une symétrie, et un point
## quelconque) ; propagé, TOUS les joints du témoin coïncident encore, sans conflit. Et sans propagation,
## le même déplacement les ouvre.
func _la_propagation_garde_les_joints(t0: RefCounted, paires: Array) -> void:
	var t: RefCounted = t0.copie()
	var s = Sections.new(t)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3009
	var choisis: Array = []
	var fixe_trouve := false
	var arete_trouvee := false
	for k in s.points.size():
		var canons: Array = (s.points[k] as Dictionary).keys()
		canons.sort()
		var e: Dictionary = (s.points[k][canons[canons.size() / 2]] as Array)[0]
		choisis.append(e)
		# Un point FIXÉ par une symétrie non triviale, s'il y en a un.
		for canon in canons:
			for h in Sections.classes()["groupes"][k]:
				if Sections.cle_de_carte(h) != Sections.cle_de_carte(Sections.IDENTITE) \
						and Sections.appliquer_i(h, canon) == canon:
					choisis.append((s.points[k][canon] as Array)[0])
					fixe_trouve = true
					break
	for cle in s.bords:
		for i in s.bords[cle]:
			if (s.bords[cle][i] as Array).size() >= 2 and not arete_trouvee:
				choisis.append({"cle": cle, "i": i})
				arete_trouvee = true
	_dire(fixe_trouve and arete_trouvee, "les cas difficiles sont exercés : un point fixé par une symétrie, un sommet d'arête")
	var conflits := 0
	var touches := 0
	for e in choisis:
		s.indexer()
		var d: Vector3 = s.projeter(e["cle"], e["i"], Vector3(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.1, 0.1), rng.randf_range(-0.1, 0.1)))
		var r: Dictionary = s.propager(e["cle"], {e["i"]: d})
		conflits += s.conflits
		for c in r:
			touches += (r[c] as Dictionary).size()
		s.deplacer(r)
	_dire(conflits == 0, "aucun conflit de propagation (%d)" % conflits)
	_dire(touches > choisis.size() * 5, "un déplacement en entraîne d'autres, dans d'autres tuiles (%d sommets pour %d déplacés)" % [touches, choisis.size()])
	_dire(_ouvertes(t, paires) == 0, "après %d déplacements propagés, tous les joints du témoin coïncident encore (%d ouverts)" % [choisis.size(), _ouvertes(t, paires)])
	var bits_par_nom := {}
	for c in MB.classes():
		bits_par_nom[c["nom"]] = c["bits"]
	var pieces := {}
	for cle in t.tuiles:
		pieces[cle] = t.tuiles[cle].vers_array_mesh(false)
	var remarques: Array = []
	TR.verifier_sections(pieces, bits_par_nom, remarques)
	_dire(remarques.is_empty(), "et `verifier_sections` ne trouve aucune fente (%s)" % [remarques])

	# CONTRÔLE NÉGATIF : le même genre de déplacement, SANS propagation, ouvre des joints.
	var t2: RefCounted = t0.copie()
	var s2 = Sections.new(t2)
	var e2: Dictionary = choisis[0]
	var d2: Vector3 = s2.projeter(e2["cle"], e2["i"], Vector3(0.05, 0.05, 0.05))
	s2.deplacer({e2["cle"]: {e2["i"]: d2}})
	_dire(_ouvertes(t2, paires) > 0, "contrôle : sans propagation, le même déplacement ouvre %d joint(s)" % _ouvertes(t2, paires))


## UN GROUPE, UN MOUVEMENT (3 octobre 2026 : le sculpt ouvrait 4 742 joints) — TOUS les sommets de bord de la paroi
## reçoivent chacun un déplacement DIFFÉRENT (au hasard, graine fixe), comme sous un pinceau. L'autorité reste les VRAIS
## joints du témoin. Contrôle : les mêmes sources propagées ensemble (`propager`) en ouvrent, avec des conflits.
func _plusieurs_sources_un_mouvement(t0: RefCounted, paires: Array) -> void:
	var cle := "mb_plaque_b2h2_dehors"
	var rng := RandomNumberGenerator.new()
	rng.seed = 310
	var t: RefCounted = t0.copie()
	var s = Sections.new(t)
	s.indexer()
	var deltas := {}
	for i in s.bords[cle]:
		deltas[i] = s.projeter(cle, i, Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05),
			rng.randf_range(-0.05, 0.05)))
	var r: Dictionary = s.propager_par_groupe(cle, deltas)
	var conflits: int = s.conflits
	var plus_fort := -1
	for i in deltas:
		if plus_fort < 0 or (deltas[i] as Vector3).length() > (deltas[plus_fort] as Vector3).length():
			plus_fort = i
	_dire((r[cle][plus_fort] as Vector3).distance_to(deltas[plus_fort]) < 1e-9,
		"le sommet le plus déplacé garde SON mouvement : c'est lui qui mène son groupe")
	s.deplacer(r)
	_dire(deltas.size() > 10 and conflits == 0 and _ouvertes(t, paires) == 0,
		"%d sources différentes sur la paroi, propagées PAR GROUPE : 0 conflit, tous les joints coïncident (%d ouverts)"
		% [deltas.size(), _ouvertes(t, paires)])
	var t2: RefCounted = t0.copie()
	var s2 = Sections.new(t2)
	s2.indexer()
	var r2: Dictionary = s2.propager(cle, deltas)
	var conflits2: int = s2.conflits
	s2.deplacer(r2)
	_dire(conflits2 > 0 and _ouvertes(t2, paires) > 0,
		"contrôle : propagées ensemble, %d conflit(s) et %d joint(s) ouvert(s)" % [conflits2, _ouvertes(t2, paires)])


## LA COMPLÉTION (point 3) : une coupe qui pose un sommet sur un bord doit le poser sur chaque face de sa
## classe. L'autorité est la même : les VRAIS JOINTS — tout sommet posé sur le plan d'un joint doit y trouver un
## partenaire dans la tuile d'en face (`_sans_partenaire`, calculé sans `sections.gd`).
func _la_completion(t0: RefCounted) -> void:
	var s0 = Sections.new(t0)
	_dire(s0.absences() == 0 and _sans_partenaire(t0) == 0, "le témoin calculé est complet : aucune absence, aucun sommet de joint sans partenaire")
	var r0: Dictionary = s0.completer()
	_dire(r0["coupes"] == 0 and r0["echecs"] == 0, "sur un témoin complet, la complétion ne fait rien (%s)" % [r0])
	# Une coupe simulée : un sommet neuf au milieu d'une arête de bord — d'abord de la paroi, puis d'une classe
	# SYMÉTRIQUE (son orbite doit suivre).
	for cas in ["paroi", "symetrique"]:
		var t: RefCounted = t0.copie()
		var s = Sections.new(t)
		var e := _arete_de_bord(s, t, cas)
		_dire(not e.is_empty(), "une arête de bord à couper existe (%s)" % cas)
		if e.is_empty():
			continue
		var m: RefCounted = t.tuiles[e["cle"]]
		var milieu: Vector3 = (m.sommets[e["a"]] + m.sommets[e["b"]]) * 0.5
		m._inserer_sur_arete(Vector2i(mini(e["a"], e["b"]), maxi(e["a"], e["b"])), milieu)
		var ouverts: int = _sans_partenaire(t)
		_dire(ouverts > 0 and s.absences() > 0, "contrôle (%s) : la coupe seule laisse %d sommet(s) de joint sans partenaire" % [cas, ouverts])
		var sauvees: Array = []
		var r: Dictionary = s.completer(func(c): sauvees.append(c))
		_dire(r["echecs"] == 0 and r["coupes"] > 0 and (r["touchees"] as Array).size() > 1,
			"complétée (%s) : %d coupe(s) reportée(s) dans %d tuiles, 0 échec" % [cas, r["coupes"], (r["touchees"] as Array).size()])
		_dire(sauvees.size() == (r["touchees"] as Array).size(), "chaque tuile touchée est sauvée UNE fois, avant sa modification")
		_dire(s.absences() == 0 and _sans_partenaire(t) == 0,
			"et tout sommet de joint retrouve son partenaire (%d sans, %d absences)" % [_sans_partenaire(t), s.absences()])
		# Le sommet neuf est désormais PARTAGÉ : le déplacer ne rouvre rien — et ne REPLIE aucune face.
		# ⚠ VU À L'IMAGE (capture_modeleur_lie) : un point reporté seulement INSÉRÉ dans le contour d'une face en
		# fait un pentagone qui, tiré, devient gauche ou concave ; sa triangulation se replie et ouvre des trous.
		s.indexer()
		var neuf: int = m.sommets.size() - 1
		var d: Vector3 = s.projeter(e["cle"], neuf, Vector3(0.16, 0.2, -0.12))
		s.deplacer(s.propager(e["cle"], {neuf: d}))
		_dire(d.length() > 0.0 and _sans_partenaire(t) == 0, "le sommet neuf, déplacé et propagé, ne rouvre aucun joint (%s)" % cas)
		_dire(_retournes(t) == 0, "et aucune face ne se replie : %d triangle(s) retourné(s) (%s)" % [_retournes(t), cas])
	# Un VRAI loop cut du maillage éditable, dont l'anneau traverse un bord.
	var t3: RefCounted = t0.copie()
	var s3 = Sections.new(t3)
	var fait := false
	for cle in t3.tuiles:
		if fait:
			break
		var m3: RefCounted = t3.tuiles[cle]
		for ar in m3.aretes():
			var anneau: Array = m3.anneau(ar)
			var traverse := false
			for r in anneau:
				var pa: Vector3 = m3.sommets[r[0]]
				var pb: Vector3 = m3.sommets[r[1]]
				for axe in 3:
					if absf(absf(pa[axe]) - 0.5) < 0.0005 and absf(pa[axe] - pb[axe]) < 0.0005:
						traverse = true
			if traverse and not anneau.is_empty():
				m3.couper_en_boucle(ar, 0.5)
				fait = true
				break
	_dire(fait, "un anneau qui traverse un bord existe, et il est coupé")
	var r3: Dictionary = s3.completer()
	_dire(r3["echecs"] == 0 and _sans_partenaire(t3) == 0 and s3.absences() == 0,
		"un vrai loop cut sur un bord, complété : %d coupe(s) reportée(s), tout joint a son partenaire" % r3["coupes"])


## Les triangles dont la normale s'oppose à celle de leur face (Newell) : une face repliée, donc un trou.
func _retournes(t: RefCounted) -> int:
	var n := 0
	for cle in t.tuiles:
		var m: RefCounted = t.tuiles[cle]
		for f in m.faces.size():
			var face: PackedInt32Array = m.faces[f]
			if face.size() <= 3:
				continue
			var nrm: Vector3 = m.normale(f)
			for tri in m.trianguler(f):
				var a: Vector3 = m.sommets[face[tri[0]]]
				var b: Vector3 = m.sommets[face[tri[1]]]
				var c: Vector3 = m.sommets[face[tri[2]]]
				if (b - a).cross(c - a).dot(nrm) < -1e-9:
					n += 1
	return n


## Une arête de bord (ses deux bouts sur le même plan) dans la paroi, ou dans une tuile d'une classe symétrique.
func _arete_de_bord(s, t: RefCounted, cas: String) -> Dictionary:
	var groupes: Array = Sections.classes()["groupes"]
	for cle in t.tuiles:
		if cas == "paroi" and cle != "mb_plaque_b2h2_dehors":
			continue
		var m: RefCounted = t.tuiles[cle]
		for face in m.faces:
			for k in (face as PackedInt32Array).size():
				var a: int = face[k]
				var b: int = face[(k + 1) % (face as PackedInt32Array).size()]
				if not (s.est_de_bord(cle, a) and s.est_de_bord(cle, b)):
					continue
				for fa in s.bords[cle][a]:
					for fb in s.bords[cle][b]:
						if fa["noeud"] != fb["noeud"] or (m.sommets[a] as Vector3).distance_to(m.sommets[b]) < 0.05:
							continue
						if cas == "symetrique" and (groupes[fa["classe"]] as Array).size() < 2:
							continue
						return {"cle": cle, "a": a, "b": b}
	return {}


## Les sommets posés sur le plan d'un joint du témoin qui n'ont PAS de partenaire exact dans la tuile d'en face.
## FILL HOLES SUR LE VRAI TÉMOIN (3 octobre 2026). L'attendu ne passe ni par `boucher_les_trous` ni par `Sections` : ce
## sont les VRAIS joints du témoin (`_sans_partenaire`), qui doivent se refermer. Des faces de la paroi arrachées — loin
## des plans, au bord, au bord avec sa voisine, au coin, toute la bande du plan x+ —, puis 156 arrachages au hasard
## (graine fixe) dans les 52 tuiles.
func _boucher_les_trous(t: RefCounted, s: RefCounted) -> void:
	var total := 0
	for c in t.tuiles:
		total += t.tuiles[c].trous()
	_dire(total == 0, "trous : aucune des 52 tuiles saines n'en a (leurs bords ouverts sont tous sur les plans de coupe)")
	var cle := "mb_plaque_b2h2_dehors"
	var m: RefCounted = t.tuiles[cle]
	var loin := -1
	var bord := -1
	var coin := -1
	var bande: Array = []
	for f in m.faces.size():
		var plans := 0
		var x_plus := false
		for i in m.faces[f]:
			var p: Vector3 = m.sommets[i]
			var n := 0
			for axe in 3:
				if absf(absf(p[axe]) - 0.5) < 0.0005:
					n += 1
			plans = maxi(plans, n)
			x_plus = x_plus or absf(p.x - 0.5) < 0.0005
		if plans == 0 and loin < 0:
			loin = f
		if plans >= 1 and bord < 0:
			bord = f
		if plans >= 2 and coin < 0:
			coin = f
		if x_plus:
			bande.append(f)
	for essai in [["loin des plans", [loin]], ["au bord", [bord]], ["au coin", [coin]], ["la bande du plan x+", bande]]:
		var sauve: RefCounted = m.copie()
		m.supprimer_faces(essai[1])
		var ouverts := _sans_partenaire(t)
		var r: Dictionary = m.boucher_les_trous(s.manquants(cle))
		s.completer()
		_dire(m.trous() == 0 and _sans_partenaire(t) == 0 and (essai[0] == "loin des plans" or ouverts > 0),
			"Fill holes, %s (%s) : plus de trou, et les vrais joints se referment (%d sommets sans partenaire → %d)"
			% [essai[0], essai[1], ouverts, _sans_partenaire(t)])
		t.tuiles[cle] = sauve
		m = sauve
		s.indexer()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261003
	var reussis := 0
	var essais := 0
	for c in t.tuiles.keys():
		for k in 3:
			var mt: RefCounted = t.tuiles[c]
			var sv: RefCounted = mt.copie()
			var fs: Array = [rng.randi_range(0, mt.faces.size() - 1)]
			for j in rng.randi_range(0, 2):
				var v := _une_voisine(mt, fs[-1])
				if v >= 0 and not fs.has(v):
					fs.append(v)
			mt.supprimer_faces(fs)
			essais += 1
			var r: Dictionary = mt.boucher_les_trous(s.manquants(c))
			s.completer()
			if mt.trous() == 0 and _sans_partenaire(t) == 0 and int(r["echecs"]) == 0:
				reussis += 1
			t.tuiles[c] = sv
			s.indexer()
	# ⚠ MESURÉ, PAS PARFAIT : 153 sur 156 (deux trous d'une tuile qui se disputent des points ; un rebord tombé pile sur
	# un plan). L'écran dit ce qui reste ; ce seuil garde qu'on ne recule pas.
	_dire(reussis >= 153, "Fill holes au hasard : %d / %d arrachages refermés jusque dans les joints du monde" % [reussis, essais])


func _une_voisine(m: RefCounted, f: int) -> int:
	var a := {}
	for i in m.faces[f]:
		a[i] = true
	for g in m.faces.size():
		if g == f:
			continue
		var n := 0
		for i in m.faces[g]:
			if a.has(i):
				n += 1
		if n >= 2:
			return g
	return -1


func _sans_partenaire(t: RefCounted) -> int:
	var occ := {}
	for o in t.occurrences:
		occ[o["sommet"]] = o
	var n := 0
	for s in occ:
		var oa: Dictionary = occ[s]
		for axe in 3:
			for sens in [-1, 1]:
				var e := Vector3i.ZERO
				e[axe] = sens
				if not occ.has(s + e):
					continue
				var ob: Dictionary = occ[s + e]
				var tb: RefCounted = t.tuiles[ob["cle"]]
				var index_b := {}
				for j in tb.sommets.size():
					index_b[Vector3i(((ob["pose"] as Transform3D) * tb.sommets[j] * 10000.0).round())] = true
				var ta: RefCounted = t.tuiles[oa["cle"]]
				var plan: float = float(s[axe]) + 1.0 + 0.5 * sens
				for i in ta.sommets.size():
					var pw: Vector3 = (oa["pose"] as Transform3D) * ta.sommets[i]
					if absf(pw[axe] - plan) <= 0.0005 and not index_b.has(Vector3i((pw * 10000.0).round())):
						n += 1
	return n


func _ouvertes(t: RefCounted, paires: Array) -> int:
	var n := 0
	for p in paires:
		var a: Vector3 = (p["pa"] as Transform3D) * (t.tuiles[p["a"][0]].sommets[p["a"][1]] as Vector3)
		var b: Vector3 = (p["pb"] as Transform3D) * (t.tuiles[p["b"][0]].sommets[p["b"][1]] as Vector3)
		if a.distance_to(b) > 1e-4:
			n += 1
	return n
