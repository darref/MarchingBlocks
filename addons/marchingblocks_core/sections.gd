extends RefCounted
## LES SECTIONS PARTAGÉES — un bord de tuile est UNE donnée, partagée par toutes les faces qui peuvent se
## trouver face à face dans un monde (charte §3, demandé par Jordan le 30 septembre 2026 : « la seule
## manière d'avoir un witness monolithique sans trous »).
##
## Le vocabulaire :
##   • un NŒUD est une face de RÉFÉRENCE d'une tuile : « clé|axe|signe » (la face x+ de la paroi…) ;
##   • sous chaque pose que le peintre donne à sa clé, un nœud tombe dans un seau de `verifier_sections`
##     (axe du monde, motif des quatre cases vu du plan) ; toutes les faces d'un seau se font face ;
##   • les CLASSES sont les composantes que les seaux relient ; chaque nœud porte une CARTE 2D (permutation
##     signée) de son repère de face vers celui de la racine de sa classe ; deux chemins qui ne s'accordent
##     pas imposent une SYMÉTRIE à la section (son GROUPE) ;
##   • le repère 2D d'une face d'axe a : les deux AUTRES axes, dans l'ordre croissant (`Tranchage._section`).
##
## ⚠ **LES CLASSES NE DÉPENDENT QUE DU MODÈLE** (les clés, leurs poses) : elles se calculent UNE fois. Les
## POINTS, eux, sont la géométrie des tuiles : l'index se rebâtit quand elle change (`indexer`).
## ⚠ **MESURÉ AVANT D'ÊTRE ÉCRIT** (`DEV_TOOLS/sonde_sections_partagees.gd`, une implémentation À PART qui
## sert d'autorité aux tests) : 246 nœuds, 10 classes, 2 symétriques ; 1 230 sommets de bord, chacun
## présent dans chaque face de sa classe.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const TR := preload("res://addons/marchingblocks_core/tranchage.gd")

## Un sommet est SUR un plan de coupe à cette distance près (en cases).
const EPS := 0.0005
## Les points s'indexent au dix-millième de case.
const QUANTUM := 10000.0
const IDENTITE := [[1, 0], [0, 1]]

static var _classe_de := {}    # nœud → indice de classe
static var _carte_de := {}     # nœud → carte vers la racine
static var _groupes: Array = []   # indice → [cartes] (le groupe de symétries, identité comprise)
static var _noeuds_de_classe: Array = []

var temoin: RefCounted
## classe → {point canonique (Vector2i) → [{cle, i, noeud, g}]}, g ramenant le point du sommet au canonique.
var points: Array = []
## clé → {i → [{noeud, classe, canon, g, axe}]} : les faces (une, ou deux sur une arête) où le sommet est posé.
var bords := {}
## Les sommets atteints par deux chemins qui ne s'accordent pas, au dernier `propager` (0 attendu).
var conflits := 0


# ── LES CLASSES, UNE FOIS ─────────────────────────────────────────────────────────────────────────

static func classes() -> Dictionary:
	_preparer()
	return {"classe_de": _classe_de, "carte_de": _carte_de, "groupes": _groupes, "noeuds": _noeuds_de_classe}


static func _preparer() -> void:
	if not _classe_de.is_empty():
		return
	var membres := {}   # seau → [{noeud, carte}]
	var noeuds := {}
	for c in MB.classes():
		var bits: int = c["bits"]
		if not MB.porte_une_surface(bits) or not MB.sans_contact_diagonal(bits):
			continue
		var cles: Array = [c["nom"]]
		if MB.exterieur_possible(bits):
			cles.append(MB.nom_en_contexte(c["nom"], true))
		for cle in cles:
			for pose in TR._poses_de(MB.classer(bits)["classe"]):
				var base: Basis = pose["base"]
				for axe_r in 3:
					for signe in [-1, 1]:
						var e := Vector3.ZERO
						e[axe_r] = float(signe)
						var d: Vector3 = (base * e).round()
						var axe_w: int = 0 if absf(d.x) > 0.5 else (1 if absf(d.y) > 0.5 else 2)
						var motif: int = TR._motif_de_face(pose["bits"], axe_w, 1 if d[axe_w] > 0 else 0)
						if motif == 0 or motif == 15:
							continue
						var n := noeud(cle, axe_r, signe)
						noeuds[n] = true
						var sk := "%d|%d" % [axe_w, motif]
						if not membres.has(sk):
							membres[sk] = []
						membres[sk].append({"noeud": n, "carte": _carte(base, axe_r, axe_w)})
	var adj := {}
	for sk in membres:
		var liste: Array = membres[sk]
		var ref: Dictionary = liste[0]
		for m in liste:
			var vers_ref: Array = compose(inverse(ref["carte"]), m["carte"])
			_lier(adj, m["noeud"], ref["noeud"], vers_ref)
			_lier(adj, ref["noeud"], m["noeud"], inverse(vers_ref))
	var ordre: Array = noeuds.keys()
	ordre.sort()
	for n in ordre:
		if _classe_de.has(n):
			continue
		var k := _groupes.size()
		var generateurs := {}
		_classe_de[n] = k
		_carte_de[n] = IDENTITE
		var liste_k: Array = [n]
		var file: Array = [n]
		while not file.is_empty():
			var x: String = file.pop_front()
			for arc in adj.get(x, []):
				var y: String = arc[0]
				var c_y: Array = compose(_carte_de[x], inverse(arc[1]))
				if not _classe_de.has(y):
					_classe_de[y] = k
					_carte_de[y] = c_y
					liste_k.append(y)
					file.append(y)
				else:
					var s: Array = compose(c_y, inverse(_carte_de[y]))
					generateurs[cle_de_carte(s)] = s
		_groupes.append(_engendrer(generateurs.values()))
		_noeuds_de_classe.append(liste_k)


static func noeud(cle: String, axe: int, signe: int) -> String:
	return "%s|%d|%d" % [cle, axe, signe]


# ── LES POINTS : l'index de la géométrie ──────────────────────────────────────────────────────────

func _init(t: RefCounted = null) -> void:
	_preparer()
	if t != null:
		temoin = t
		indexer()


## Rebâtit l'index des sommets de bord (après un changement de géométrie).
func indexer() -> void:
	points = []
	for k in _groupes.size():
		points.append({})
	bords = {}
	for cle in temoin.tuiles:
		var m: RefCounted = temoin.tuiles[cle]
		var par_sommet := {}
		for i in m.sommets.size():
			var faces: Array = _faces_de(cle, m.sommets[i])
			if faces.is_empty():
				continue
			par_sommet[i] = faces
			for f in faces:
				var liste: Dictionary = points[f["classe"]]
				if not liste.has(f["canon"]):
					liste[f["canon"]] = []
				liste[f["canon"]].append({"cle": cle, "i": i, "noeud": f["noeud"], "g": f["g"], "axe": f["axe"],
					"rt": f["rt"]})
		bords[cle] = par_sommet


## Les faces de classe sur lesquelles un point de la tuile `cle` est posé : [{noeud, classe, canon, g, axe}].
func _faces_de(cle: String, p: Vector3) -> Array:
	var sortie: Array = []
	for axe in 3:
		for signe in [-1, 1]:
			if absf(p[axe] - 0.5 * signe) >= EPS:
				continue
			var n := noeud(MB.cle_de_tuile(cle), axe, signe)
			if not _classe_de.has(n):
				continue
			var k: int = _classe_de[n]
			var q: Vector2i = _quantifier(appliquer(_carte_de[n], _dans_la_face(p, axe)))
			var canon := q
			var g: Array = IDENTITE
			for h in _groupes[k]:
				var r: Vector2i = appliquer_i(h, q)
				if r.x < canon.x or (r.x == canon.x and r.y < canon.y):
					canon = r
					g = h
			# ⚠ LES CARTES DU SOMMET SONT CALCULÉES ICI, UNE FOIS : la propagation les appliquait en les
			# recomposant à chaque visite — 86 ms pour 328 sommets, un G qui suivait la souris à 10 images/s.
			var vc: Array = compose(g, _carte_de[n])
			sortie.append({"noeud": n, "classe": k, "canon": canon, "g": g, "axe": axe, "vc": vc, "rt": inverse(vc),
				"q": q})
	return sortie


## ── LA COMPLÉTION (point 3) : une coupe qui ajoute un sommet sur un bord l'ajoute PARTOUT ─────────────
##
## Après une coupe (loop cut, couteau…) sur une tuile, sa section peut porter un point que les autres faces de
## sa classe n'ont pas. La règle est générale, et c'est pourquoi elle ne suit aucun outil en particulier :
## **dans une classe, toute face porte TOUS les points de la classe, et toute leur ORBITE sous son groupe de
## symétries.** Un point absent d'une face est posé en FENDANT l'arête de bord de cette face qui le contient.
## ⚠ IDEMPOTENTE : sur un témoin complet, elle ne fait rien. Un point qui ne tombe sur aucune arête (la section
## de cette face ne passe pas par là) est un ÉCHEC compté, jamais inventé.
## `sauver` est appelé UNE fois par tuile, AVANT sa première modification (l'annulation en garde la copie).
## Rend {"touchees": [clés], "coupes": n, "echecs": n}.
func completer(sauver := Callable()) -> Dictionary:
	indexer()
	var racines := _racines()
	var touchees := {}
	var coupes := 0
	var echecs := 0
	for k in points.size():
		var orbite := _orbite(k)
		for n in _noeuds_de_classe[k]:
			var p: PackedStringArray = String(n).split("|")
			var axe := int(p[1])
			var signe := int(p[2])
			for cle in _tuiles_de(p[0]):
				var presents: Dictionary = racines.get(cle + "#" + n, {})
				for r in orbite:
					if presents.has(r):
						continue
					var q3: Vector3 = _point_de_la_face(n, axe, signe, r)
					var e: Vector2i = _arete_de_bord_qui_contient(temoin.tuiles[cle], axe, signe, q3)
					if e.x < 0:
						echecs += 1
						continue
					if not touchees.has(cle):
						touchees[cle] = true
						if sauver.is_valid():
							sauver.call(cle)
					if temoin.tuiles[cle]._inserer_sur_arete(e, q3) >= 0:
						coupes += 1
						presents[r] = true
					else:
						echecs += 1
	indexer()
	return {"touchees": touchees.keys(), "coupes": coupes, "echecs": echecs}


## LES POINTS QUI MANQUENT À UNE TUILE (Jordan, 3 octobre 2026, « Fill holes ») : sur chaque face de classe de `cle`, les
## points de sa classe (orbite comprise) qu'elle ne porte pas — dans le repère de la tuile, {Vector2i(axe, signe):
## [Vector3]}. Ce sont ceux qu'un trou qui touche ce plan a emportés, et que le bouchage doit recréer pour que la section
## rejoigne celle des tuiles d'en face. La même règle que `completer`, sans rien insérer.
func manquants(cle: String) -> Dictionary:
	indexer()
	var racines := _racines()
	var modele: String = MB.cle_de_tuile(cle)
	var sortie := {}
	for k in points.size():
		var orbite := _orbite(k)
		for n in _noeuds_de_classe[k]:
			var p: PackedStringArray = String(n).split("|")
			if p[0] != modele:
				continue
			var axe := int(p[1])
			var signe := int(p[2])
			var presents: Dictionary = racines.get(cle + "#" + n, {})
			for r in orbite:
				if presents.has(r):
					continue
				var plan := Vector2i(axe, signe)
				if not sortie.has(plan):
					sortie[plan] = []
				sortie[plan].append(_point_de_la_face(n, axe, signe, r))
	return sortie


## ── LES VARIANTES (4 octobre 2026) : une tuile de plus pour un même nœud ─────────────────────────────────────────
## Un nœud nomme une face de la CLÉ ; chaque tuile de cette clé (la base, ses variantes `_var<k>`) en porte une copie,
## qui doit avoir tous les points de la classe. Les points présents se comptent donc par (tuile, nœud).
func _tuiles_de(modele: String) -> Array:
	var sortie: Array = []
	for cle in temoin.tuiles:
		if MB.cle_de_tuile(cle) == modele:
			sortie.append(cle)
	return sortie


## {« tuile#nœud » : {point racine: true}} — ce que chaque face de chaque tuile porte.
func _racines() -> Dictionary:
	var racines := {}
	for cle in bords:
		for i in bords[cle]:
			for f in bords[cle][i]:
				var r: String = cle + "#" + f["noeud"]
				if not racines.has(r):
					racines[r] = {}
				racines[r][f["q"]] = true
	return racines


func _orbite(k: int) -> Dictionary:
	var orbite := {}
	for canon in points[k]:
		for h in _groupes[k]:
			orbite[appliquer_i(h, canon)] = true
	return orbite


## Le point racine `r` de la classe, ramené sur la face (axe, signe) du nœud `n`, dans le repère de la tuile.
func _point_de_la_face(n: String, axe: int, signe: int, r: Vector2i) -> Vector3:
	var q2: Vector2 = appliquer(inverse(_carte_de[n]), Vector2(r) / QUANTUM)
	var q3: Vector3 = _hors_de_la_face(Vector3.ZERO, axe, q2)
	q3[axe] = 0.5 * signe
	return q3


## Une arête dont les deux bouts sont sur le plan (axe, signe) et qui contient `p` STRICTEMENT entre eux.
func _arete_de_bord_qui_contient(m: RefCounted, axe: int, signe: int, p: Vector3) -> Vector2i:
	var plan := 0.5 * signe
	for face in m.faces:
		for k in (face as PackedInt32Array).size():
			var a: int = face[k]
			var b: int = face[(k + 1) % (face as PackedInt32Array).size()]
			var pa: Vector3 = m.sommets[a]
			var pb: Vector3 = m.sommets[b]
			if absf(pa[axe] - plan) >= EPS or absf(pb[axe] - plan) >= EPS:
				continue
			var ab := pb - pa
			var l2 := ab.length_squared()
			if l2 < 1e-12:
				continue
			var t := (p - pa).dot(ab) / l2
			if t <= 1e-4 or t >= 1.0 - 1e-4:
				continue
			if (pa + ab * t).distance_to(p) < 1e-4:
				return Vector2i(mini(a, b), maxi(a, b))
	return Vector2i(-1, -1)


## Combien de points manquent aux faces de leur classe (orbite comprise) — 0 sur un témoin complet.
func absences() -> int:
	indexer()
	var racines := _racines()
	var n_abs := 0
	for k in points.size():
		var orbite := _orbite(k)
		for n in _noeuds_de_classe[k]:
			for cle in _tuiles_de(String(n).split("|")[0]):
				var presents: Dictionary = racines.get(cle + "#" + n, {})
				for r in orbite:
					if not presents.has(r):
						n_abs += 1
	return n_abs


## Le sommet `i` de la tuile `cle` est-il un sommet de bord (posé sur une face qui a une classe) ?
func est_de_bord(cle: String, i: int) -> bool:
	return (bords.get(cle, {}) as Dictionary).has(i)


## Les CORRESPONDANTS d'un sommet de bord : [{cle, i}] (lui compris), par ses faces.
func correspondants(cle: String, i: int) -> Array:
	var vus := {}
	for f in (bords.get(cle, {}) as Dictionary).get(i, []):
		for e in (points[f["classe"]] as Dictionary).get(f["canon"], []):
			vus["%s|%d" % [e["cle"], e["i"]]] = {"cle": e["cle"], "i": e["i"]}
	return vus.values()


## CE QU'UN SOMMET DE BORD A LE DROIT DE FAIRE : glisser DANS son plan (le long de l'arête s'il en touche
## deux), et, si sa classe impose une symétrie qui le FIXE, de façon symétrique (la moyenne sur le
## stabilisateur de son point). Un sommet qui n'est pas de bord garde `d` tel quel.
func projeter(cle: String, i: int, d: Vector3) -> Vector3:
	var faces: Array = (bords.get(cle, {}) as Dictionary).get(i, [])
	for f in faces:
		d[f["axe"]] = 0.0
	for f in faces:
		var stab: Array = []
		for h in _groupes[f["classe"]]:
			if appliquer_i(h, f["canon"]) == f["canon"]:
				stab.append(h)
		if stab.size() <= 1:
			continue
		var dc: Vector2 = appliquer(f["vc"], _dans_la_face(d, f["axe"]))
		var somme := Vector2.ZERO
		for h in stab:
			somme += appliquer(h, dc)
		d = _hors_de_la_face(d, f["axe"], appliquer(f["rt"], somme / float(stab.size())))
	return d


## UN GROUPE, UN MOUVEMENT (3 octobre 2026) : des sommets de `cle` RELIÉS par les sections (les faces x+ et x− d'une
## paroi, et de proche en proche par les sommets d'arête, qui sont de deux classes) doivent bouger ensemble. Un geste
## rigide (G) leur donne le même déplacement ; un PINCEAU de sculpt, ou l'édition proportionnelle, leur en donne de
## différents — et `propager_plusieurs` les posait tous d'abord, puis gardait le premier venu : les copies voisines
## divergeaient (mesuré : 4 742 sommets de joint sans partenaire après un trait ; une moyenne par point n'en laissait
## que 1 572, deux classes se contredisant sur leurs arêtes communes). Ici, les sources passent UNE PAR UNE, du plus
## grand déplacement au plus petit, et chacune ne part que si la propagation des précédentes ne l'a pas atteinte :
## chaque groupe relié reçoit le mouvement de son membre le plus déplacé (le plus près du centre du pinceau).
func propager_par_groupe(cle: String, deltas: Dictionary) -> Dictionary:
	conflits = 0
	var sources: Array = deltas.keys()
	sources.sort_custom(func(a: int, b: int) -> bool:
		var la: float = (deltas[a] as Vector3).length_squared()
		var lb: float = (deltas[b] as Vector3).length_squared()
		return la > lb or (la == lb and a < b))
	var sortie := {}
	var faits := {}
	for i in sources:
		if sortie.has(cle) and (sortie[cle] as Dictionary).has(i):
			continue
		var file: Array = []
		_poser(sortie, cle, i, deltas[i], file)
		_etendre(sortie, file, faits)
	return sortie


## LA PROPAGATION : `deltas` = {i: déplacement} sur la tuile `cle` (DÉJÀ projetés). Rend {clé: {i: déplacement}}
## pour TOUS les sommets touchés, de proche en proche (un sommet d'arête passe d'une classe à l'autre), les
## sommets de départ compris.
func propager(cle: String, deltas: Dictionary) -> Dictionary:
	return propager_plusieurs({cle: deltas})


func propager_plusieurs(depart: Dictionary) -> Dictionary:
	conflits = 0
	var sortie := {}
	var file: Array = []
	for cle in depart:
		for i in depart[cle]:
			_poser(sortie, cle, i, depart[cle][i], file)
	# ⚠ UN POINT CANONIQUE SE TRAITE UNE FOIS : tous ses membres reçoivent le même mouvement, et le relire depuis
	# chacun d'eux (une trentaine) faisait O(sommets × membres) — encore 40 ms après avoir précalculé les cartes.
	_etendre(sortie, file, {})
	return sortie


## La propagation de proche en proche depuis `file` ; `faits` : les points canoniques déjà traités.
func _etendre(sortie: Dictionary, file: Array, faits: Dictionary) -> void:
	while not file.is_empty():
		var x: Array = file.pop_front()
		var c: String = x[0]
		var i: int = x[1]
		var d: Vector3 = sortie[c][i]
		for f in (bords.get(c, {}) as Dictionary).get(i, []):
			var cle_point: Vector3i = Vector3i(f["classe"], (f["canon"] as Vector2i).x, (f["canon"] as Vector2i).y)
			if faits.has(cle_point):
				continue
			faits[cle_point] = true
			var dc: Vector2 = appliquer(f["vc"], _dans_la_face(d, f["axe"]))
			for e in (points[f["classe"]] as Dictionary).get(f["canon"], []):
				if e["i"] == i and e["cle"] == c:
					continue
				var de: Vector3 = _hors_de_la_face(Vector3.ZERO, e["axe"], appliquer(e["rt"], dc))
				_poser(sortie, e["cle"], e["i"], de, file)


## APPLIQUE une propagation : chaque sommet touché prend sa position de DÉPART plus son déplacement.
## `depart` = {clé: PackedVector3Array} (les positions d'avant le geste) ; une clé absente part de l'actuelle.
## ⚠ Depuis le départ, jamais cumulé : un geste qui suit la souris rejoue à chaque mouvement.
func deplacer(deltas: Dictionary, depart: Dictionary = {}) -> void:
	for cle in deltas:
		var m: RefCounted = temoin.tuiles[cle]
		var base: PackedVector3Array = depart.get(cle, m.sommets)
		for i in deltas[cle]:
			m.sommets[i] = base[i] + (deltas[cle][i] as Vector3)


## Les positions de toutes les tuiles, pour `deplacer` (le départ d'un geste).
func photo() -> Dictionary:
	var sortie := {}
	for cle in temoin.tuiles:
		sortie[cle] = (temoin.tuiles[cle].sommets as PackedVector3Array).duplicate()
	return sortie


## ⚠ Un sommet d'ARÊTE est atteint par ses deux faces : chacune ne connaît que les composantes de SON plan.
## On FUSIONNE composante par composante ; seules deux valeurs non nulles différentes sont un conflit.
func _poser(sortie: Dictionary, cle: String, i: int, d: Vector3, file: Array) -> void:
	if not sortie.has(cle):
		sortie[cle] = {}
	if not sortie[cle].has(i):
		sortie[cle][i] = d
		file.append([cle, i])
		return
	var avant: Vector3 = sortie[cle][i]
	var fusion := avant
	var change := false
	for a in 3:
		if absf(d[a]) <= 1e-9:
			continue
		if absf(avant[a]) <= 1e-9:
			fusion[a] = d[a]
			change = true
		elif absf(avant[a] - d[a]) > 1e-6:
			conflits += 1
	if change:
		sortie[cle][i] = fusion
		file.append([cle, i])


# ── L'ALGÈBRE DES CARTES (permutations signées 2×2) ────────────────────────────────────────────────

static func _autres(a: int) -> Array:
	return [1, 2] if a == 0 else ([0, 2] if a == 1 else [0, 1])


static func _dans_la_face(p: Vector3, axe: int) -> Vector2:
	var u := _autres(axe)
	return Vector2(p[u[0]], p[u[1]])


static func _hors_de_la_face(base: Vector3, axe: int, q: Vector2) -> Vector3:
	var u := _autres(axe)
	var p := base
	p[u[0]] = q.x
	p[u[1]] = q.y
	return p


static func _carte(base: Basis, axe_r: int, axe_w: int) -> Array:
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


static func compose(a: Array, b: Array) -> Array:   # a ∘ b
	return [[a[0][0] * b[0][0] + a[0][1] * b[1][0], a[0][0] * b[0][1] + a[0][1] * b[1][1]],
		[a[1][0] * b[0][0] + a[1][1] * b[1][0], a[1][0] * b[0][1] + a[1][1] * b[1][1]]]


static func inverse(a: Array) -> Array:   # une permutation signée : l'inverse est la transposée
	return [[a[0][0], a[1][0]], [a[0][1], a[1][1]]]


static func cle_de_carte(a: Array) -> String:
	return "%d,%d,%d,%d" % [a[0][0], a[0][1], a[1][0], a[1][1]]


static func appliquer(m: Array, q: Vector2) -> Vector2:
	return Vector2(m[0][0] * q.x + m[0][1] * q.y, m[1][0] * q.x + m[1][1] * q.y)


## Sur des points DÉJÀ quantifiés (entiers) : une permutation signée reste exacte.
static func appliquer_i(m: Array, q: Vector2i) -> Vector2i:
	return Vector2i(m[0][0] * q.x + m[0][1] * q.y, m[1][0] * q.x + m[1][1] * q.y)


static func _quantifier(q: Vector2) -> Vector2i:
	return Vector2i(roundi(q.x * QUANTUM), roundi(q.y * QUANTUM))


static func _engendrer(generateurs: Array) -> Array:
	var vus := {cle_de_carte(IDENTITE): IDENTITE}
	var file: Array = [IDENTITE]
	while not file.is_empty():
		var x: Array = file.pop_front()
		for g in generateurs:
			var y := compose(g, x)
			if not vus.has(cle_de_carte(y)):
				vus[cle_de_carte(y)] = y
				file.append(y)
	return vus.values()


static func _lier(adj: Dictionary, a: String, b: String, carte: Array) -> void:
	if not adj.has(a):
		adj[a] = []
	adj[a].append([b, carte])
