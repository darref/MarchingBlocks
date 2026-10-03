extends SceneTree
##
## SONDE — LES TROUS DU TÉMOIN (3 octobre 2026, « Fill holes »). Mesure, sur le témoin calculé : (1) qu'aucune tuile saine
## n'a de trou ; (2) pour des faces arrachées — loin des bords, puis touchant un plan de coupe — combien de trous, et ce
## que le bouchage rend : plus de trou, et les sommets de joint qui retrouvent leur partenaire dans le monde.

const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const Sections := preload("res://addons/marchingblocks_core/sections.gd")
const ME := preload("res://addons/marchingblocks_core/maillage_edite.gd")


func _initialize() -> void:
	var t: RefCounted = TL.depuis_le_temoin_calcule()
	var total := 0
	for c in t.tuiles:
		var n: int = t.tuiles[c].trous()
		if n > 0:
			print("⚠ trou dans une tuile saine : ", c, " ", n)
		total += n
	print("tuiles saines : %d tuile(s), %d trou(s)" % [t.tuiles.size(), total])
	var s := Sections.new(t)
	print("sans partenaire au départ : ", _sans_partenaire(t))
	var cle := "mb_plaque_b2h2_dehors"
	var m: RefCounted = t.tuiles[cle]
	# Les faces : loin de tout plan, et touchant un plan.
	var loin := -1
	var bord := -1
	for f in m.faces.size():
		var touche := false
		for i in m.faces[f]:
			if not ME.plans_de(m.sommets[i]).is_empty():
				touche = true
		if touche and bord < 0:
			bord = f
		if not touche and loin < 0:
			loin = f
	print("faces : %d ; loin des plans : %d ; touchant un plan : %d" % [m.faces.size(), loin, bord])
	var coin := -1
	var bande: Array = []
	for f in m.faces.size():
		var touche := false
		for i in m.faces[f]:
			if ME.plans_de(m.sommets[i]).size() >= 2 and coin < 0:
				coin = f
			if Vector2i(0, 1) in ME.plans_de(m.sommets[i]):
				touche = true
		if touche:
			bande.append(f)
	print("coin : %d ; bande du plan x+ : %s" % [coin, bande])
	for essai in [["loin", [loin]], ["bord", [bord]], ["bord + voisine", [bord, _voisine(m, bord)]], ["coin", [coin]],
			["bande x+", bande]]:
		var sauve: RefCounted = m.copie()
		var fs: Array = essai[1]
		m.supprimer_faces(fs)
		print("— %s : supprimé %s ; trous %d ; sans partenaire %d" % [essai[0], fs, m.trous(), _sans_partenaire(t)])
		var manq: Dictionary = s.manquants(cle)
		var nm := 0
		for k in manq:
			nm += (manq[k] as Array).size()
		var r: Dictionary = m.boucher_les_trous(manq)
		var c2: Dictionary = s.completer()
		print("   bouché : %s ; points attendus %d ; trous après %d ; complétion %s ; sans partenaire %d ; absences %d"
			% [r, nm, m.trous(), c2, _sans_partenaire(t), s.absences()])
		t.tuiles[cle] = sauve
		m = sauve
		s.temoin = t
		s.indexer()
	# AU HASARD : dans chaque tuile, trois essais d'une à trois faces voisines arrachées (graine fixe).
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261003
	var essais := 0
	var reussis := 0
	var restes: Array = []
	for c in t.tuiles.keys():
		for k in 3:
			var mt: RefCounted = t.tuiles[c]
			var sv: RefCounted = mt.copie()
			var f0 := rng.randi_range(0, mt.faces.size() - 1)
			var fs: Array = [f0]
			for j in rng.randi_range(0, 2):
				var v := _voisine(mt, fs[-1])
				if v >= 0 and not fs.has(v):
					fs.append(v)
			mt.supprimer_faces(fs)
			essais += 1
			var r: Dictionary = mt.boucher_les_trous(s.manquants(c))
			s.completer()
			var sp := _sans_partenaire(t)
			var tr: int = mt.trous()
			if sp == 0 and tr == 0 and int(r["echecs"]) == 0:
				reussis += 1
			else:
				restes.append([c, fs, r, tr, sp])
			t.tuiles[c] = sv
			s.indexer()
	print("AU HASARD : %d / %d bouchés sans trou ni sommet sans partenaire" % [reussis, essais])
	for x in restes.slice(0, 8):
		print("   reste : ", x)
	quit(0)


func _voisine(m: RefCounted, f: int) -> int:
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
