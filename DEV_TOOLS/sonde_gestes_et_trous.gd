extends SceneTree
## SONDE — QUELS GESTES DE GEOMETRY FONT DES TROUS ? (Jordan, 4 octobre 2026 : « identifie les gestes dans la geometry
## qui peuvent faire des trous, et s'il y a un moyen gratuit de les éviter, pour utiliser très peu Fill holes »)
##   godot --headless --path . --script res://DEV_TOOLS/sonde_gestes_et_trous.gd
## Chaque geste est rejoué comme le modeleur le fait (le cœur, puis `Sections.completer` pour ceux qui y passent), sur
## un témoin NEUF, dans la paroi, loin des plans de coupe puis au contact. On compte : `trous()` (arêtes ouvertes HORS
## des plans) dans la tuile, et les sommets de joint sans partenaire dans le monde (les fentes).

const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const SE := preload("res://addons/marchingblocks_core/sections.gd")
const ME := preload("res://addons/marchingblocks_core/maillage_edite.gd")

const CLE := "mb_plaque_b2h2_dehors"
var _modele: RefCounted


func _initialize() -> void:
	_modele = TL.depuis_le_temoin_calcule()
	var ops := [
		["X face loin", false, func(m, r): m.supprimer_faces([r.f_loin])],
		["X face au bord", false, func(m, r): m.supprimer_faces([r.f_bord])],
		["X arête intérieure", false, func(m, r): m.supprimer_aretes([r.e_int])],
		["X sommet de bord", false, func(m, r): m.supprimer_sommets([r.v_bord])],
		["E faces loin (+0,1)", true, func(m, r): _extruder(m, [r.f_loin], 0.1)],
		["E face au bord (+0,1)", true, func(m, r): _extruder(m, [r.f_bord], 0.1)],
		["E face au bord (0 : E puis Échap-déplacement)", true, func(m, r): _extruder(m, [r.f_bord], 0.0)],
		["E arête intérieure (+0,1)", true, func(m, r): _extruder_aretes(m, [r.e_int], 0.1)],
		["E arête sur le bord (+0,1)", true, func(m, r): _extruder_aretes(m, [r.e_bord], 0.1)],
		["I face loin", true, func(m, r): m.inserer([r.f_loin], 0.03)],
		["I face au bord", true, func(m, r): m.inserer([r.f_bord], 0.03)],
		["Ctrl+B arête intérieure", true, func(m, r): m.biseauter([r.e_int], 0.03)],
		["Ctrl+B arête qui touche le bord", true, func(m, r): m.biseauter([r.e_touche], 0.03)],
		["Ctrl+B arête posée sur le bord", true, func(m, r): m.biseauter([r.e_bord], 0.03)],
		["M deux sommets intérieurs voisins", true, func(m, r): m.fusionner(r.deux_int)],
		["M deux sommets de bord voisins", true, func(m, r): m.fusionner(r.deux_bord)],
		["M sommet de bord + intérieur", true, func(m, r): m.fusionner([r.v_bord, r.v_int_voisin])],
		["F sur les sommets d'une face ôtée", true, func(m, r):
			var vs: Array = Array(m.faces[r.f_loin])
			m.supprimer_faces([r.f_loin])
			# supprimer renumérote : on retrouve les sommets par leur position
			var ps: Array = r.pos_f_loin
			var ids: Array = []
			for p in ps:
				ids.append(_par_position(m, p))
			m.remplir(ids)],
		["Subdiviser face au bord", true, func(m, r): m.subdiviser([r.f_bord])],
		["Ctrl+R qui traverse le bord", true, func(m, r): m.couper_en_boucle(r.e_touche, 0.5)],
		["VARIANTE M bord + intérieur, AU SOMMET DE BORD", true, func(m, r):
			m.sommets[r.v_int_voisin] = m.sommets[r.v_bord]
			m.fusionner([r.v_bord, r.v_int_voisin])],
		["VARIANTE E face au bord (+0,1), BORD ÉPINGLÉ", true, func(m, r): _extruder_epingle(m, [r.f_bord], 0.1)],
		["VARIANTE E faces au bord (3 voisines, +0,1), ÉPINGLÉ", true, func(m, r):
			var fs: Array = [r.f_bord]
			for k in 2:
				var v := _voisine(m, fs[-1], fs)
				if v >= 0:
					fs.append(v)
			_extruder_epingle(m, fs, 0.1)],
		["APRÈS E face au bord (+0,1), épinglé par le cœur", true, func(m, r):
			var x: Dictionary = m.extruder_faces([r.f_bord], true)
			m.transformer(x["sommets"], Transform3D(Basis(), x["normale"] * 0.1), m.sommets.duplicate())],
		["APRÈS M bord + intérieur (point_de_fusion)", true, func(m, r):
			var ch: Array = [r.v_bord, r.v_int_voisin]
			m.fusionner(ch, m.point_de_fusion(ch)["point"])],
		["APRÈS M deux sommets de bord : refusé ?", false, func(m, r):
			print("   refus : ", m.point_de_fusion(r.deux_bord)["refus"])],
		["APRÈS E arête : extrudables (int, bord)", false, func(m, r):
			print("   ", m.arete_extrudable(r.e_int), " ", m.arete_extrudable(r.e_bord))],
		["APRÈS Dissoudre face au bord", true, func(m, r): print("   ", m.dissoudre_faces([r.f_bord]))],
		["APRÈS Dissoudre face au bord + 2 voisines", true, func(m, r):
			var fs: Array = [r.f_bord]
			for k in 2:
				var v := _voisine(m, fs[-1], fs)
				if v >= 0:
					fs.append(v)
			print("   ", m.dissoudre_faces(fs))],
		["APRÈS Dissoudre les faces d'un sommet de bord", true, func(m, r):
			var fs: Array = []
			for f in m.faces.size():
				if Array(m.faces[f]).has(r.v_bord):
					fs.append(f)
			print("   ", fs, " ", m.dissoudre_faces(fs))],
	]
	for op in ops:
		var t: RefCounted = _modele.copie()
		var s: RefCounted = SE.new(t)
		var m: RefCounted = t.tuiles[CLE]
		var r := _reperes(m, s)
		(op[2] as Callable).call(m, r)
		var c := {"echecs": 0}
		if op[1]:
			s.indexer()
			c = s.completer()
		var lu: Dictionary = m._boucles_ouvertes()
		var hors := 0
		for e: Vector2i in m._aretes_ouvertes():
			if not m._sur_une_coupe(e.x, e.y):
				hors += 1
		var fpa: Dictionary = m.faces_par_arete()
		var triples := 0
		for e in fpa:
			if (fpa[e] as Array).size() > 2:
				triples += 1
		print("%-52s trous %d ; arêtes ouvertes hors plan %d ; à 3 faces %d ; sans partenaire %d ; échecs du report %d"
			% [op[0], m.trous(), hors, triples, _sans_partenaire(t), int(c["echecs"])])
	quit(0)


func _extruder(m: RefCounted, fs: Array, d: float) -> void:
	var r: Dictionary = m.extruder_faces(fs)
	m.transformer(r["sommets"], Transform3D(Basis(), r["normale"] * d), m.sommets.duplicate())


func _extruder_aretes(m: RefCounted, es: Array, d: float) -> void:
	var ids: Array = m.extruder_aretes(es)
	m.transformer(ids, Transform3D(Basis(), Vector3(0, 0, 0.1) if d > 0 else Vector3.ZERO), m.sommets.duplicate())


## L'extrusion « bord épinglé » : les sommets posés sur un plan de coupe ne sont pas dédoublés ni déplacés.
func _extruder_epingle(m: RefCounted, fs: Array, d: float) -> void:
	var r: Dictionary = m.extruder_faces(fs)
	var bouger: Array = []
	var paires: Array = []
	for i in r["sommets"]:
		if ME.plans_de(m.sommets[i]).is_empty():
			bouger.append(i)
		else:
			paires.append(m.sommets[i])
	m.transformer(bouger, Transform3D(Basis(), r["normale"] * d), m.sommets.duplicate())
	for p in paires:
		var ids: Array = []
		for i in m.sommets.size():
			if m.sommets[i].distance_to(p) < 1e-6:
				ids.append(i)
		if ids.size() >= 2:
			m.fusionner(ids)


func _voisine(m: RefCounted, f: int, deja: Array) -> int:
	var a := {}
	for i in m.faces[f]:
		a[i] = true
	for g in m.faces.size():
		if deja.has(g):
			continue
		var n := 0
		for i in m.faces[g]:
			if a.has(i):
				n += 1
		if n >= 2:
			return g
	return -1


func _par_position(m: RefCounted, p: Vector3) -> int:
	for i in m.sommets.size():
		if m.sommets[i].distance_to(p) < 1e-6:
			return i
	return -1


func _reperes(m: RefCounted, s: RefCounted) -> Dictionary:
	var bord := func(i: int) -> bool: return not ME.plans_de(m.sommets[i]).is_empty()
	var r := {"f_loin": -1, "f_bord": -1, "e_bord": Vector2i(-1, -1), "e_touche": Vector2i(-1, -1),
		"e_int": Vector2i(-1, -1), "v_bord": -1, "deux_bord": [], "deux_int": [], "v_int_voisin": -1}
	var fpa: Dictionary = m.faces_par_arete()
	for f in m.faces.size():
		var face: PackedInt32Array = m.faces[f]
		var touche := false
		for i in face:
			if bord.call(i):
				touche = true
		if touche and r.f_bord < 0:
			r.f_bord = f
		if not touche and r.f_loin < 0:
			r.f_loin = f
		for k in face.size():
			var a := face[k]
			var b := face[(k + 1) % face.size()]
			var e := ME.arete(a, b)
			var ba: bool = bord.call(a)
			var bb: bool = bord.call(b)
			if ba and bb and r.e_bord.x < 0 and (fpa[e] as Array).size() == 1:
				r.e_bord = e
				r.deux_bord = [a, b]
				r.v_bord = a
			elif ba != bb and r.e_touche.x < 0:
				r.e_touche = e
				r.v_int_voisin = b if ba else a
			elif not ba and not bb and r.e_int.x < 0 and (fpa[e] as Array).size() == 2:
				r.e_int = e
				r.deux_int = [a, b]
	# le sommet de bord de `e_touche` pour la fusion bord + intérieur
	r.v_bord = r.e_touche.x if bord.call(r.e_touche.x) else r.e_touche.y
	r.pos_f_loin = []
	for i in m.faces[r.f_loin]:
		r.pos_f_loin.append(m.sommets[i])
	return r


func _sans_partenaire(t: RefCounted) -> int:
	var occ := {}
	for o in t.occurrences:
		occ[o["sommet"]] = o
	var index := {}
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
				if not index.has(s + e):
					var tb: RefCounted = t.tuiles[ob["cle"]]
					var ib := {}
					for j in tb.sommets.size():
						ib[Vector3i(((ob["pose"] as Transform3D) * tb.sommets[j] * 10000.0).round())] = true
					index[s + e] = ib
				var ta: RefCounted = t.tuiles[oa["cle"]]
				var plan: float = float(s[axe]) + 1.0 + 0.5 * sens
				for i in ta.sommets.size():
					var pw: Vector3 = (oa["pose"] as Transform3D) * ta.sommets[i]
					if absf(pw[axe] - plan) <= 0.0005 and not index[s + e].has(Vector3i((pw * 10000.0).round())):
						n += 1
	return n
