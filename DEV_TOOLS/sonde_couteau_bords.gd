extends SceneTree
## SONDE — le couteau sur les arêtes de BORD des tuiles (Jordan, 2 octobre 2026 : « regarde ce qui se passe quand on
## utilise le knife sur une edge fusionnée de bord de tuile répétée, j'en ai besoin pour créer des motifs qui traversent
## les bords »). Sur le témoin calculé, pour chaque tuile et quelques faces qui touchent un plan de coupe, elle essaie
## chaque façon de couper un bord — la route du modeleur : `MaillageEdite.couper`, puis `Sections.completer` — et dit
## ce qui casse : une erreur, une face abîmée (moins de 3 sommets, un sommet répété, un indice hors du tableau), un
## sommet de joint sans partenaire, ou « rien coupé ». Ne conçoit rien.
##   godot --headless --path <copie> --script res://DEV_TOOLS/sonde_couteau_bords.gd

const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const ME := preload("res://addons/marchingblocks_core/maillage_edite.gd")
const Sections := preload("res://addons/marchingblocks_core/sections.gd")

var _bilan := {}


func _initialize() -> void:
	var t: RefCounted = TL.depuis_le_temoin_calcule()
	var s = Sections.new(t)
	print("témoin : %d tuiles, %d sans partenaire au départ" % [t.tuiles.size(), _sans_partenaire(t)])
	for cle in t.tuiles:
		var essais := 0
		var nb_faces: int = t.tuiles[cle].faces.size()
		for f in nb_faces:
			if essais >= 3:
				break
			# ⚠ LA TUILE RELUE À CHAQUE FACE : chaque essai la coupe puis la REMPLACE par sa photo ; garder l'objet
			# d'avant faisait bâtir les essais suivants sur une tuile déjà coupée (des sommets qui n'existent plus).
			var m: RefCounted = t.tuiles[cle]
			var face: PackedInt32Array = m.faces[f]
			var bords := _aretes_de_bord(m, face)
			if bords.is_empty():
				continue
			essais += 1
			for scenario in _scenarios(m, f, face, bords):
				_essayer(t, s, cle, scenario)
	print("")
	for k in _bilan:
		print("%-48s %s" % [k, _bilan[k]])
	quit(0)


## Les arêtes d'une face dont les deux bouts sont sur un même plan de coupe : [{"k": indice dans la face, "axe"}].
func _aretes_de_bord(m: RefCounted, face: PackedInt32Array) -> Array:
	var r: Array = []
	for k in face.size():
		var pa: Vector3 = m.sommets[face[k]]
		var pb: Vector3 = m.sommets[face[(k + 1) % face.size()]]
		for axe in 3:
			if absf(absf(pa[axe]) - 0.5) < 0.0005 and absf(pa[axe] - pb[axe]) < 0.0005:
				r.append({"k": k, "axe": axe})
				break
	return r


func _pt(m: RefCounted, a: int, b: int, t: float) -> Dictionary:
	return {"arete": ME.arete(a, b), "t": t if a < b else 1.0 - t,
		"point": (m.sommets[a] as Vector3).lerp(m.sommets[b], t)}


func _scenarios(m: RefCounted, f: int, face: PackedInt32Array, bords: Array) -> Array:
	var n := face.size()
	var k: int = bords[0]["k"]
	var a := face[k]
	var b := face[(k + 1) % n]
	var sc: Array = []
	# 1. Du milieu du bord au milieu de l'arête d'en face (le cas déjà gardé par la fumée).
	var c := face[(k + 2) % n]
	var d := face[(k + 3) % n]
	sc.append({"nom": "bord -> en face", "points": [_pt(m, a, b, 0.5), _pt(m, c, d, 0.5)]})
	# 2. Deux points sur la MÊME arête de bord.
	sc.append({"nom": "deux points sur le même bord", "points": [_pt(m, a, b, 0.3), _pt(m, a, b, 0.7)]})
	# 3. Du coin du bord (un sommet du plan) au milieu de l'arête d'en face.
	sc.append({"nom": "coin du bord -> en face", "points": [_pt(m, a, b, 0.0), _pt(m, c, d, 0.5)]})
	# 4. D'un bord à un autre bord de la même face.
	if bords.size() >= 2:
		var k2: int = bords[1]["k"]
		sc.append({"nom": "bord -> autre bord", "points": [_pt(m, a, b, 0.5),
			_pt(m, face[k2], face[(k2 + 1) % n], 0.5)]})
	# 5. En chaîne : le bord, l'arête d'en face, puis l'arête d'en face de la face voisine (deux faces traversées).
	var voisine := _face_voisine(m, f, c, d)
	if voisine >= 0:
		var fv: PackedInt32Array = m.faces[voisine]
		var j := Array(fv).find(c)
		if j >= 0 and fv.size() == 4:
			var e1 := fv[(j + 2) % 4]
			var e2 := fv[(j + 3) % 4]
			sc.append({"nom": "chaîne sur deux faces", "points": [_pt(m, a, b, 0.5), _pt(m, c, d, 0.5),
				_pt(m, e1, e2, 0.5)]})
	# 6. Couper deux fois le même bord : la seconde coupe part du sommet que la première y a posé.
	sc.append({"nom": "deux coupes sur le même bord", "deux_fois": true,
		"points": [_pt(m, a, b, 0.5), _pt(m, c, d, 0.5)]})
	return sc


func _face_voisine(m: RefCounted, f: int, a: int, b: int) -> int:
	for g in m.faces.size():
		if g == f:
			continue
		var fg: PackedInt32Array = m.faces[g]
		for k in fg.size():
			var x := fg[k]
			var y := fg[(k + 1) % fg.size()]
			if (x == a and y == b) or (x == b and y == a):
				return g
	return -1


func _essayer(t: RefCounted, s, cle: String, sc: Dictionary) -> void:
	var photo := {}
	for c in t.tuiles:
		photo[c] = t.tuiles[c].copie()
	var m: RefCounted = t.tuiles[cle]
	var nom: String = sc["nom"]
	var faces_avant: int = m.faces.size()
	var neufs: Array = m.couper(sc["points"])
	var coupe: bool = not neufs.is_empty() or m.faces.size() != faces_avant
	var r: Dictionary = s.completer()
	if sc.get("deux_fois", false) and coupe and not neufs.is_empty():
		# La seconde : du sommet neuf, sur le bord, vers le milieu de sa nouvelle arête de bord.
		var i: int = neufs[0]
		var face2 := -1
		for g in m.faces.size():
			if Array(m.faces[g]).has(i):
				face2 = g
				break
		if face2 >= 0:
			var fg: PackedInt32Array = m.faces[face2]
			var j := Array(fg).find(i)
			var x := fg[(j + 1) % fg.size()]
			var y := fg[(j + 2) % fg.size()]
			var avant2: int = m.faces.size()
			var n2: Array = m.couper([{"arete": ME.arete(i, x), "t": 0.0 if i < x else 1.0, "point": m.sommets[i]},
				_pt(m, x, y, 0.5)])
			coupe = coupe and (not n2.is_empty() or m.faces.size() != avant2)
			var r2: Dictionary = s.completer()
			r["echecs"] = int(r["echecs"]) + int(r2["echecs"])
	var abimees := 0
	for c in t.tuiles:
		abimees += _faces_abimees(t.tuiles[c])
	var orphelins := _sans_partenaire(t)
	var verdict := "ok"
	if not coupe:
		verdict = "RIEN COUPÉ"
	elif abimees > 0:
		verdict = "FACES ABÎMÉES (%d)" % abimees
	elif orphelins > 0 or int(r["echecs"]) > 0:
		verdict = "JOINTS OUVERTS (%d sans partenaire, %d échecs)" % [orphelins, int(r["echecs"])]
	var cle_bilan := "%s : %s" % [nom, verdict]
	_bilan[cle_bilan] = int(_bilan.get(cle_bilan, 0)) + 1
	if verdict != "ok" and int(_bilan[cle_bilan]) <= 2:
		print("  %s — %s (%s)" % [cle, cle_bilan, sc["points"].map(func(p): return [p["arete"], snappedf(p["t"], 0.01)])])
	for c in photo:
		t.tuiles[c] = photo[c]
	s.indexer()


func _faces_abimees(m: RefCounted) -> int:
	var n := 0
	for face: PackedInt32Array in m.faces:
		var vus := {}
		var mauvaise := face.size() < 3
		for i in face:
			if i < 0 or i >= m.sommets.size() or vus.has(i):
				mauvaise = true
			vus[i] = true
		if mauvaise:
			n += 1
	return n


## Recopié de `test_sections` : un sommet sur un joint du monde sans le sommet de la tuile d'en face.
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
