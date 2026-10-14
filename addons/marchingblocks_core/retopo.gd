extends RefCounted
## LA RETOPO DU TÉMOIN — DEMANDÉE PAR JORDAN (13 octobre 2026), niveaux 1 et 2 de ce qui lui a été proposé :
##   1. SIMPLIFIER une tuile (décimer), BORD VERROUILLÉ ;
##   2. DÉTENDRE (relax) : régulariser l'espacement des sommets intérieurs sans changer la forme, bord verrouillé.
##
## Ce fichier ne dessine rien : il prend un `MaillageEdite` (une tuile, dans le repère de sa clé) et le change EN PLACE.
## L'écran (`app/modeleur.gd`) en fait UN geste, une annulation pour toutes les tuiles touchées.
##
## ⚠ **LE CODE DE BLENDER NE SE RECOPIE PAS (GPL, charte §5)** : le « Decimate » et le « Smooth Vertices / Relax » de
## Blender ne sont imités que dans leur résultat. Les algorithmes sont ceux de la littérature, écrits ici :
##   - la décimation par EFFONDREMENT D'ARÊTES guidé par les QUADRIQUES d'erreur (Garland et Heckbert, 1997), dans sa
##     forme « demi-arête » : le sommet u disparaît, il rejoint son voisin v qui ne bouge pas. Aucune position neuve n'est
##     inventée — le maillage simplifié est fait de sommets d'origine ;
##   - la détente par un laplacien TANGENT (le déplacement vers la moyenne des voisins, privé de sa composante normale),
##     puis reprojeté sur la surface D'ORIGINE (les triangles d'origine autour du sommet).
##
## ── CE QUI NE BOUGE JAMAIS : LES VERROUS ─────────────────────────────────────────────────────────────────────────────
##
## ⚠ **LE BORD D'UNE TUILE EST UNE DONNÉE PARTAGÉE** (charte §3, « les sections partagées ») : un sommet posé sur un plan
## de coupe (x, y ou z = ±0,5 dans le repère de la tuile) a des correspondants dans toutes les tuiles d'en face. Le
## déplacer ou l'ôter ouvrirait une fente à chaque joint du monde. Il est VERROUILLÉ. Le sont aussi :
##   - les sommets d'une arête ouverte ou non orientée (le rebord d'un trou, une arête à trois faces) : la décimation
##     suppose une surface fermée autour du sommet qui disparaît ;
##   - les sommets d'une COUTURE (deux faces voisines de teintes ou de matériaux différents) : la limite entre deux
##     matériaux est un dessin de l'artiste, pas une erreur à lisser ;
##   - les sommets d'une face DÉPLIÉE (des UV stockés par coin) : on ne devine pas l'UV d'un point déplacé, et la face
##     perdrait sa peinture. Ses faces restent telles quelles, UV compris (« ne traiter que les faces sans UV ») ; une
##     projection boîte ou plane, elle, se recalcule depuis la position et survit à tout.
## La détente verrouille en plus les sommets d'une ARÊTE VIVE (deux faces autour de lui à plus de 20° l'une de l'autre) :
## glisser le long de la surface les ferait sortir de l'arête et l'arrondirait.

const ME := preload("res://addons/marchingblocks_core/maillage_edite.gd")

## Une arête vive : deux faces d'un même sommet à plus de 20° (cos 20° ≈ 0,9397).
const COS_ARETE_VIVE := 0.9396926


## Les sommets qui ne bougent pas : {"verrous": {sommet: raison}, "faces_uv": n}. Raisons : « plan », « ouvert »,
## « couture », « uv ».
static func verrous(m: RefCounted) -> Dictionary:
	var v := {}
	for i in m.sommets.size():
		if not ME.plans_de(m.sommets[i]).is_empty():
			v[i] = "plan"
	var orientees := {}
	for f in m.faces.size():
		var face: PackedInt32Array = m.faces[f]
		for k in face.size():
			var e := Vector2i(face[k], face[(k + 1) % face.size()])
			orientees[e] = int(orientees.get(e, 0)) + 1
	for e: Vector2i in orientees:
		if int(orientees[e]) != 1 or int(orientees.get(Vector2i(e.y, e.x), 0)) != 1:
			for i in [e.x, e.y]:
				if not v.has(i):
					v[i] = "ouvert"
	var cle_de := {}
	var faces_uv := 0
	for f in m.faces.size():
		var face: PackedInt32Array = m.faces[f]
		var k := [m.teintes[f] if f < m.teintes.size() else Color.WHITE, m.mat(f)]
		var depliee: bool = not (m.uv(f) as PackedVector2Array).is_empty()
		if depliee:
			faces_uv += 1
		for i in face:
			if depliee:
				v[i] = "uv"
			if not cle_de.has(i):
				cle_de[i] = k
			elif cle_de[i] != k and not v.has(i):
				v[i] = "couture"
	return {"verrous": v, "faces_uv": faces_uv}


# ── 1. SIMPLIFIER ────────────────────────────────────────────────────────────────────────────────────────────────────
#
## Décime la tuile EN PLACE. On s'arrête quand le prochain effondrement coûterait plus que `tolerance` (en cases : la
## distance du sommet qui reste aux plans des triangles qu'il remplace, bornée par la racine de la quadrique — une somme
## de carrés majore chacun d'eux), ou quand il ne reste que `ratio` des triangles de départ (0 : la tolérance seule).
## `quads` : regrouper ensuite en quads les paires de triangles coplanaires (la règle de `MaillageEdite._recoller`, celle
## de la lecture d'un maillage).
## ⚠ UNE FACE QUE RIEN N'A TOUCHÉE EST RENDUE TELLE QUELLE (sommets, teinte, matériau, UV) : on ne retriangule que ce qui
## a changé.
## Rend {"faces_avant", "faces_apres", "triangles_avant", "triangles_apres", "effondrements", "faces_uv", "verrous",
## "erreur": la plus grande borne d'erreur acceptée}.
static func simplifier(m: RefCounted, tolerance := 0.01, ratio := 0.0, quads := true) -> Dictionary:
	var d := _Decimation.new()
	return d.lancer(m, verrous(m), tolerance, ratio, quads)


class _Decimation:
	const MEi := preload("res://addons/marchingblocks_core/maillage_edite.gd")
	## Un triangle est sain si son aire orientée (le produit vectoriel lu sur la normale) dépasse ce seuil — la même
	## borne que les gardes de repli du modeleur (`MaillageEdite.SEUIL_DE_REPLI`).
	const SEUIL_I := 1e-7
	## Un effondrement ne tourne pas un triangle de plus de 60° (cos 60° = 0,5) : au-delà, la surface se plie.
	const COS_PLI_I := 0.5
	var m: RefCounted
	var s: PackedVector3Array
	var verrou := {}
	var tris: Array = []                  # PackedInt32Array de 3 sommets, trigonométrique (le sens du modèle)
	var tri_face := PackedInt32Array()     # la face d'origine de chaque triangle
	var normale_face: Array = []          # la normale d'origine de cette face (Newell)
	var vivant := PackedByteArray()
	var de: Array = []                    # par sommet : {triangle: true}
	var q := PackedFloat64Array()          # 10 réels par sommet : la quadrique symétrique 4 × 4
	var tampon := PackedInt32Array()       # par sommet : change quand son voisinage change (les entrées du tas périment)
	var mort := PackedByteArray()
	var tas: Array = []                   # [coût, u, v, tampon u, tampon v]
	var face_touchee := PackedByteArray()

	func lancer(m_: RefCounted, lu: Dictionary, tolerance: float, ratio: float, quads: bool) -> Dictionary:
		m = m_
		s = m.sommets
		verrou = lu["verrous"]
		var faces_avant: int = m.faces.size()
		face_touchee.resize(faces_avant)
		for f in faces_avant:
			var face: PackedInt32Array = m.faces[f]
			var nf: Vector3 = m.normale(f)
			for t in m.trianguler(f):
				tris.append(PackedInt32Array([face[t[0]], face[t[1]], face[t[2]]]))
				tri_face.append(f)
				normale_face.append(nf)
				vivant.append(1)
		var n0 := tris.size()
		de.resize(s.size())
		for i in s.size():
			de[i] = {}
		q.resize(s.size() * 10)
		q.fill(0.0)
		tampon.resize(s.size())
		tampon.fill(0)
		mort.resize(s.size())
		mort.fill(0)
		for t in n0:
			var tr: PackedInt32Array = tris[t]
			for i in tr:
				de[i][t] = true
			var c := (s[tr[1]] - s[tr[0]]).cross(s[tr[2]] - s[tr[0]])
			if c.length_squared() < 1e-24:
				continue
			var n := c.normalized()
			var dd := -n.dot(s[tr[0]])
			for i in tr:
				_ajouter_plan(i, n, dd)
		for u in s.size():
			if not verrou.has(u) and not (de[u] as Dictionary).is_empty():
				_candidats(u)
		var cible := int(ceil(ratio * n0)) if ratio > 0.0 else 0
		var vivants := n0
		var effondrements := 0
		var erreur := 0.0
		var seuil := tolerance * tolerance
		while not tas.is_empty() and vivants > cible:
			var e: Array = _extraire()
			var u: int = e[1]
			var v: int = e[2]
			if mort[u] or mort[v] or tampon[u] != e[3] or tampon[v] != e[4]:
				continue
			if float(e[0]) > seuil:
				break
			var retires := _effondrer(u, v)
			if retires == 0:
				continue
			vivants -= retires
			effondrements += 1
			erreur = maxf(erreur, sqrt(maxf(float(e[0]), 0.0)))
		_reconstruire(quads)
		return {"faces_avant": faces_avant, "faces_apres": m.faces.size(), "triangles_avant": n0, "triangles_apres": vivants,
			"effondrements": effondrements, "faces_uv": lu["faces_uv"], "verrous": verrou.size(), "erreur": erreur}

	func _ajouter_plan(i: int, n: Vector3, dd: float) -> void:
		var b := i * 10
		q[b] += n.x * n.x
		q[b + 1] += n.x * n.y
		q[b + 2] += n.x * n.z
		q[b + 3] += n.x * dd
		q[b + 4] += n.y * n.y
		q[b + 5] += n.y * n.z
		q[b + 6] += n.y * dd
		q[b + 7] += n.z * n.z
		q[b + 8] += n.z * dd
		q[b + 9] += dd * dd

	## La quadrique de u PLUS celle de v, lue au point p : la somme des carrés des distances de p aux plans accumulés.
	func _cout(u: int, v: int, p: Vector3) -> float:
		var a := u * 10
		var b := v * 10
		var x := p.x
		var y := p.y
		var z := p.z
		return ((q[a] + q[b]) * x * x + 2.0 * (q[a + 1] + q[b + 1]) * x * y + 2.0 * (q[a + 2] + q[b + 2]) * x * z
			+ 2.0 * (q[a + 3] + q[b + 3]) * x + (q[a + 4] + q[b + 4]) * y * y + 2.0 * (q[a + 5] + q[b + 5]) * y * z
			+ 2.0 * (q[a + 6] + q[b + 6]) * y + (q[a + 7] + q[b + 7]) * z * z + 2.0 * (q[a + 8] + q[b + 8]) * z
			+ (q[a + 9] + q[b + 9]))

	func _voisins(u: int) -> Dictionary:
		var n := {}
		for t in de[u]:
			for i in tris[t]:
				if i != u:
					n[i] = true
		return n

	func _candidats(u: int) -> void:
		for v in _voisins(u):
			_pousser([maxf(_cout(u, v, s[v]), 0.0), u, v, tampon[u], tampon[v]])

	## u rejoint v. Rend le nombre de triangles retirés (0 : refusé, rien n'a changé).
	func _effondrer(u: int, v: int) -> int:
		if verrou.has(u):
			return 0
		var partages: Array = []
		for t in de[u]:
			if v in (tris[t] as PackedInt32Array):
				partages.append(t)
		if partages.size() != 2:
			return 0
		# LA CONDITION DE LIEN : les seuls voisins communs de u et v sont les deux sommets opposés à leur arête — sinon
		# l'effondrement pincerait la surface (une arête à trois faces, un tétraèdre aplati en deux faces dos à dos).
		var nv := _voisins(v)
		var communs := 0
		for x in _voisins(u):
			if nv.has(x):
				communs += 1
		if communs != 2:
			return 0
		var deja := {}
		for t in de[v]:
			if not partages.has(t):
				deja[_cle_tri(tris[t])] = true
		var pv: Vector3 = s[v]
		var refaits: Array = []
		for t in de[u]:
			if partages.has(t):
				continue
			var tr: PackedInt32Array = (tris[t] as PackedInt32Array).duplicate()
			var a: Vector3 = s[tr[0]]
			var nc := (s[tr[1]] - a).cross(s[tr[2]] - a)
			for k in 3:
				if tr[k] == u:
					tr[k] = v
			var a2: Vector3 = s[tr[0]]
			var n2 := (s[tr[1]] - a2).cross(s[tr[2]] - a2)
			if nc.length_squared() < 1e-24 or n2.length_squared() < 1e-24:
				return 0
			var ncu := nc.normalized()
			# Ni écrasé ni retourné (l'aire orientée, la règle des gardes de repli) ; ni plié de plus de 60° ; ni retourné
			# par rapport à la face d'ORIGINE (une suite de petits plis ne doit pas en faire un grand).
			if n2.dot(ncu) <= SEUIL_I or n2.normalized().dot(ncu) < COS_PLI_I or n2.dot(normale_face[t]) <= 0.0:
				return 0
			# Pas de triangle en double, et aucun triangle posé tout entier SUR un plan de coupe (il se mêlerait à la
			# section, que la découpe et les tuiles d'en face lisent) — u n'étant sur aucun plan, l'ancien ne l'était pas.
			if deja.has(_cle_tri(tr)):
				return 0
			var plans: Array = MEi.plans_de(s[tr[0]])
			for p in plans:
				if p in MEi.plans_de(s[tr[1]]) and p in MEi.plans_de(s[tr[2]]):
					return 0
			refaits.append([t, tr])
		# On applique.
		for t in partages:
			vivant[t] = 0
			face_touchee[tri_face[t]] = 1
			for i in tris[t]:
				(de[i] as Dictionary).erase(t)
		for r in refaits:
			tris[r[0]] = r[1]
			face_touchee[tri_face[r[0]]] = 1
			de[v][r[0]] = true
		de[u] = {}
		mort[u] = 1
		for k in 10:
			q[v * 10 + k] += q[u * 10 + k]
		var autour := _voisins(v)
		autour[v] = true
		for x in autour:
			tampon[x] += 1
		for x in autour:
			if not verrou.has(x) and not mort[x]:
				_candidats(x)
		return partages.size()

	static func _cle_tri(tr: PackedInt32Array) -> Vector3i:
		var l := [tr[0], tr[1], tr[2]]
		l.sort()
		return Vector3i(l[0], l[1], l[2])

	## Les faces neuves : les faces intactes telles quelles, puis les triangles des faces touchées, regroupés en quads.
	func _reconstruire(quads: bool) -> void:
		var faces: Array = []
		var teintes := PackedColorArray()
		var mats := PackedInt32Array()
		var uvs: Array = []
		for f in m.faces.size():
			if face_touchee[f]:
				continue
			faces.append(m.faces[f])
			teintes.append(m.teintes[f] if f < m.teintes.size() else Color.WHITE)
			mats.append(m.mat(f))
			uvs.append(m.uv(f))
		var reste: Array = []
		for t in tris.size():
			if vivant[t] and face_touchee[tri_face[t]]:
				reste.append(t)
		var pris := {}
		var par_arete := {}
		for t in reste:
			var tr: PackedInt32Array = tris[t]
			for k in 3:
				var e := MEi.arete(tr[k], tr[(k + 1) % 3])
				if not par_arete.has(e):
					par_arete[e] = []
				par_arete[e].append(t)
		for t in reste:
			if pris.has(t):
				continue
			pris[t] = true
			var f: int = tri_face[t]
			var teinte: Color = m.teintes[f] if f < m.teintes.size() else Color.WHITE
			var face: PackedInt32Array = tris[t]
			if quads:
				var tr: PackedInt32Array = tris[t]
				for k in 3:
					var trouve := false
					for o in par_arete[MEi.arete(tr[k], tr[(k + 1) % 3])]:
						if pris.has(o):
							continue
						var g: int = tri_face[o]
						if (m.teintes[g] if g < m.teintes.size() else Color.WHITE) != teinte or m.mat(g) != m.mat(f):
							continue
						var qd: PackedInt32Array = MEi._recoller(s, tr, tris[o])
						if not qd.is_empty():
							pris[o] = true
							face = qd
							trouve = true
							break
					if trouve:
						break
			faces.append(face)
			teintes.append(teinte)
			mats.append(m.mat(f))
			uvs.append(PackedVector2Array())
		m.faces = faces
		m.teintes = teintes
		m.mats = mats
		m.uvs = uvs
		m.nettoyer()

	# Le tas binaire (le plus petit coût en tête).
	func _pousser(e: Array) -> void:
		tas.append(e)
		var i := tas.size() - 1
		while i > 0:
			var p := (i - 1) >> 1
			if float(tas[p][0]) <= float(e[0]):
				break
			tas[i] = tas[p]
			i = p
		tas[i] = e

	func _extraire() -> Array:
		var tete: Array = tas[0]
		var dernier: Array = tas.pop_back()
		if tas.is_empty():
			return tete
		var n := tas.size()
		var i := 0
		while true:
			var g := 2 * i + 1
			if g >= n:
				break
			var dr := g + 1
			var c := dr if dr < n and float(tas[dr][0]) < float(tas[g][0]) else g
			if float(tas[c][0]) >= float(dernier[0]):
				break
			tas[i] = tas[c]
			i = c
		tas[i] = dernier
		return tete


# ── 2. DÉTENDRE ──────────────────────────────────────────────────────────────────────────────────────────────────────
#
## Régularise l'espacement des sommets libres EN PLACE : à chaque passe, chacun va de `force` vers la moyenne de ses
## voisins (par les arêtes de ses faces), privé de la composante normale, puis il est reprojeté sur les triangles
## D'ORIGINE autour de lui — il reste donc sur la surface de départ. Une passe qui replierait une face (les gardes de
## repli du modeleur) est défaite, et la force divisée par deux.
## Rend {"libres", "deplaces", "ecart": le plus grand déplacement, "passes", "faces_uv", "verrous"}.
static func detendre(m: RefCounted, passes := 10, force := 0.5) -> Dictionary:
	var lu := verrous(m)
	var verrou: Dictionary = (lu["verrous"] as Dictionary).duplicate()
	var normales_de := {}
	var faces_de := {}
	var voisins := {}
	for f in m.faces.size():
		var face: PackedInt32Array = m.faces[f]
		var nf: Vector3 = m.normale(f)
		for k in face.size():
			var i := face[k]
			if not normales_de.has(i):
				normales_de[i] = []
				faces_de[i] = []
				voisins[i] = {}
			normales_de[i].append(nf)
			faces_de[i].append(f)
			voisins[i][face[(k + 1) % face.size()]] = true
			voisins[i][face[(k - 1 + face.size()) % face.size()]] = true
	# Les arêtes vives, et la normale de chaque sommet.
	var normale := {}
	for i in normales_de:
		var l: Array = normales_de[i]
		var n := Vector3.ZERO
		for a in l:
			n += a
			for b in l:
				if (a as Vector3).dot(b) < COS_ARETE_VIVE and not verrou.has(i):
					verrou[i] = "vive"
		normale[i] = n.normalized()
	var libres: Array = []
	for i in normales_de:
		if not verrou.has(i):
			libres.append(i)
	var depart: PackedVector3Array = m.sommets.duplicate()
	if libres.is_empty():
		return {"libres": 0, "deplaces": 0, "ecart": 0.0, "passes": 0, "faces_uv": lu["faces_uv"], "verrous": verrou.size()}
	# La surface d'origine autour de chaque sommet libre : les triangles de ses faces, en positions de départ.
	var anneau := {}
	var gardees := {}
	for i in libres:
		var t: Array = []
		for f in faces_de[i]:
			gardees[f] = true
			var face: PackedInt32Array = m.faces[f]
			for tri in m.trianguler(f):
				t.append([depart[face[tri[0]]], depart[face[tri[1]]], depart[face[tri[2]]]])
		anneau[i] = t
	var gardes: Array = m.gardes_de_repli(gardees.keys())
	var faites := 0
	var w := force
	while faites < passes and w >= 0.05:
		var avant: PackedVector3Array = m.sommets.duplicate()
		var neufs := {}
		for i in libres:
			var p: Vector3 = avant[i]
			var moy := Vector3.ZERO
			for j in voisins[i]:
				moy += avant[j]
			moy /= float((voisins[i] as Dictionary).size())
			var dlt := moy - p
			var n: Vector3 = normale[i]
			dlt -= n * dlt.dot(n)
			neufs[i] = _sur_l_anneau(p + dlt * w, anneau[i])
		for i in neufs:
			m.sommets[i] = neufs[i]
		if m.replie(gardes):
			m.sommets = avant
			w *= 0.5
			continue
		faites += 1
	var deplaces := 0
	var ecart := 0.0
	for i in libres:
		var dd: float = (m.sommets[i] as Vector3).distance_to(depart[i])
		if dd > 1e-6:
			deplaces += 1
		ecart = maxf(ecart, dd)
	return {"libres": libres.size(), "deplaces": deplaces, "ecart": ecart, "passes": faites, "faces_uv": lu["faces_uv"],
		"verrous": verrou.size()}


## Le point le plus proche de p sur une liste de triangles.
static func _sur_l_anneau(p: Vector3, triangles: Array) -> Vector3:
	var meilleur := p
	var d := INF
	for t in triangles:
		var c := point_le_plus_proche(p, t[0], t[1], t[2])
		var dd := c.distance_squared_to(p)
		if dd < d:
			d = dd
			meilleur = c
	return meilleur


## Le point d'un triangle le plus proche de p — par régions de Voronoï du triangle (sommets, arêtes, intérieur), la
## méthode classique des manuels de détection de collisions.
static func point_le_plus_proche(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var den := 1.0 / (va + vb + vc)
	return a + ab * (vb * den) + ac * (vc * den)
