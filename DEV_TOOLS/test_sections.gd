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


func _ouvertes(t: RefCounted, paires: Array) -> int:
	var n := 0
	for p in paires:
		var a: Vector3 = (p["pa"] as Transform3D) * (t.tuiles[p["a"][0]].sommets[p["a"][1]] as Vector3)
		var b: Vector3 = (p["pb"] as Transform3D) * (t.tuiles[p["b"][0]].sommets[p["b"][1]] as Vector3)
		if a.distance_to(b) > 1e-4:
			n += 1
	return n
