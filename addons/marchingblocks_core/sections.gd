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
				liste[f["canon"]].append({"cle": cle, "i": i, "noeud": f["noeud"], "g": f["g"], "axe": f["axe"]})
		bords[cle] = par_sommet


## Les faces de classe sur lesquelles un point de la tuile `cle` est posé : [{noeud, classe, canon, g, axe}].
func _faces_de(cle: String, p: Vector3) -> Array:
	var sortie: Array = []
	for axe in 3:
		for signe in [-1, 1]:
			if absf(p[axe] - 0.5 * signe) >= EPS:
				continue
			var n := noeud(cle, axe, signe)
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
			sortie.append({"noeud": n, "classe": k, "canon": canon, "g": g, "axe": axe})
	return sortie


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
		var vers_canon: Array = compose(f["g"], _carte_de[f["noeud"]])
		var dc: Vector2 = appliquer(vers_canon, _dans_la_face(d, f["axe"]))
		var somme := Vector2.ZERO
		for h in stab:
			somme += appliquer(h, dc)
		d = _hors_de_la_face(d, f["axe"], appliquer(inverse(vers_canon), somme / float(stab.size())))
	return d


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
	while not file.is_empty():
		var x: Array = file.pop_front()
		var c: String = x[0]
		var i: int = x[1]
		var d: Vector3 = sortie[c][i]
		for f in (bords.get(c, {}) as Dictionary).get(i, []):
			var vers_canon: Array = compose(f["g"], _carte_de[f["noeud"]])
			var dc: Vector2 = appliquer(vers_canon, _dans_la_face(d, f["axe"]))
			for e in (points[f["classe"]] as Dictionary).get(f["canon"], []):
				if e["cle"] == c and e["i"] == i and e["noeud"] == f["noeud"]:
					continue
				var retour: Array = inverse(compose(e["g"], _carte_de[e["noeud"]]))
				var de: Vector3 = _hors_de_la_face(Vector3.ZERO, e["axe"], appliquer(retour, dc))
				_poser(sortie, e["cle"], e["i"], de, file)
	return sortie


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
