extends RefCounted
## LA DÉCOUPE D'UN MESH PAR UNE BOÎTE — ce qui est dedans est gardé, et rien n'est refermé.
##
## ⚠ POURQUOI ELLE EXISTE. Passer du lot centré CASE à la grille DUALE, c'est recouper le même massif
## sur des plans décalés d'une demi-case (charte du greffon). On assemble donc les pièces existantes à
## leur place, et on retranche sur la nouvelle grille. Chaque pièce duale est ce qui reste dans sa
## boîte.
##
## ⚠ ON NE REFERME PAS LA COUPE, ET C'EST VOULU. La face de coupe d'une pièce est exactement celle de
## sa voisine : posées côte à côte, elles font une surface continue. La boucher, ce serait payer sur
## chaque case une géométrie que personne ne voit — c'est aussi ce que fait le découpeur acheté, qui
## tranche avec un PLAN et laisse la coupe ouverte.
##
## ⚠ ET C'EST UNE VRAIE DÉCOUPE, PAS UN TRI. Le trancheur de Spirit3D affectait des triangles ENTIERS
## au centre de pièce le plus proche (marge 0,35, 2 % d'orphelins tolérés) : deux pièces voisines n'y
## partagent jamais une frontière exacte. Ici un triangle à cheval est COUPÉ, et les deux morceaux
## tombent de part et d'autre du même plan.
##
## Pur, sans `Node`, préchargé par chemin : le greffon, la génération et les tests l'appellent chacun à
## leur façon.

const EPS := 0.000001


## Ce qui reste de `mesh` dans `boite`. Rend un `ArrayMesh` — vide si rien ne reste.
## Les normales, les UV et les COULEURS DE SOMMET sont interpolés aux coupes ; les matériaux de surface
## sont conservés.
##
## ⚠ **LES COULEURS ONT ÉTÉ OUBLIÉES ICI PENDANT TOUT LE DÉVELOPPEMENT, ET SEULE UNE IMAGE L'A MONTRÉ.**
## Cette fonction lisait VERTEX, NORMAL, TEX_UV et INDEX, jamais COLOR — tandis que `poser()`, dans le
## même fichier, reprend le tableau entier et les préserve. Deux fonctions du même module ne traitaient
## donc pas les mêmes données.
##
## Le symptôme était trompeur : le MATÉRIAU, lui, était bien conservé. Les pièces portaient donc
## `repli_procedural.matiere()`, qui lit la couleur de sommet comme albédo — sur un maillage qui n'en
## avait plus. Godot rend alors du BLANC. La planche du monde d'essai est sortie entièrement blanche,
## et le codage vert/bleu/brun (ciel, plafond, paroi) avait disparu.
##
## ⚠ **CE QUE ÇA COÛTAIT N'EST PAS ESTHÉTIQUE.** Ce codage est le seul contrôle visuel capable de
## montrer un plafond posé là où il faut un sol, ou une pièce retournée. Sans lui, la planche ne pouvait
## plus rougir sur une faute d'orientation : **un contrôle incapable d'échouer ne garde rien** (charte §6).
static func trancher(mesh: Mesh, boite: AABB) -> ArrayMesh:
	var sortie := ArrayMesh.new()
	if mesh == null:
		return sortie
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		if arrays.is_empty():
			continue
		var sommets: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if sommets.is_empty():
			continue
		var normales: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var couleurs: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			indices = PackedInt32Array(range(sommets.size()))

		var v_out := PackedVector3Array()
		var n_out := PackedVector3Array()
		var uv_out := PackedVector2Array()
		var c_out := PackedColorArray()

		for t in range(0, indices.size() - 2, 3):
			# ⚠ **REJET PAR BOÎTE AVANT DE CONSTRUIRE QUOI QUE CE SOIT — ET C'EST 99 % DU COÛT.** La boucle
			# bâtissait TROIS dictionnaires par triangle, puis découvrait dans Sutherland-Hodgman que le
			# triangle était à dix cases de la boîte. Mesuré : trancher la planète paysage en ses 541
			# morceaux demandait 203 s, soit ~50 millions de dictionnaires dont presque aucun ne servait.
			# ⚠ Le test est CONSERVATEUR (boîte contre boîte, marge `EPS`) : il ne peut écarter un triangle
			# qui contribuerait, donc la sortie est identique — c'est une accélération, pas une règle.
			if not _peut_toucher(sommets[indices[t]], sommets[indices[t + 1]], sommets[indices[t + 2]],
					boite):
				continue
			var triangle: Array = []
			for k in 3:
				var i: int = indices[t + k]
				triangle.append({
					"p": sommets[i],
					"n": normales[i] if normales.size() > i else Vector3.UP,
					"uv": uvs[i] if uvs.size() > i else Vector2.ZERO,
					"c": couleurs[i] if couleurs.size() > i else Color.WHITE,
				})
			var polygone: Array = _couper_polygone(triangle, boite)
			# Un polygone convexe se retriangule en éventail : il l'est toujours, puisqu'on coupe un
			# triangle (convexe) par des demi-espaces (convexes).
			for k in range(1, polygone.size() - 1):
				if _plat(polygone[0]["p"], polygone[k]["p"], polygone[k + 1]["p"]):
					continue
				for sommet in [polygone[0], polygone[k], polygone[k + 1]]:
					v_out.append(sommet["p"])
					n_out.append(sommet["n"])
					uv_out.append(sommet["uv"])
					c_out.append(sommet["c"])

		if v_out.is_empty():
			continue
		var res: Array = []
		res.resize(Mesh.ARRAY_MAX)
		res[Mesh.ARRAY_VERTEX] = v_out
		if not normales.is_empty():
			res[Mesh.ARRAY_NORMAL] = n_out
		if not uvs.is_empty():
			res[Mesh.ARRAY_TEX_UV] = uv_out
		# ⚠ On ne pose le tableau que si la SOURCE en avait un : fabriquer un tableau de blancs
		# forcerait un `vertex_color_use_as_albedo` à blanchir un mesh qui n'a jamais eu de couleurs.
		if not couleurs.is_empty():
			res[Mesh.ARRAY_COLOR] = c_out
		sortie.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, res)
		var matiere: Material = mesh.surface_get_material(s)
		if matiere != null:
			sortie.surface_set_material(sortie.get_surface_count() - 1, matiere)
	return sortie


## Ce triangle est-il PLAT — ses trois sommets alignés, à 10⁻⁶ près de sa taille ?
##
## ⚠ **LA DÉCOUPE EN FABRIQUAIT PAR MILLIERS — MESURÉ (29 septembre 2026).** Un sommet posé SUR un plan de
## coupe est gardé des deux côtés (`>= -EPS`) : le triangle d'une case voisine qui touche la boîte par une
## arête ou un sommet laisse donc un polygone réduit à un segment, que l'éventail triangulait quand même.
## Sur le témoin : 0 triangle plat en entrée, **32 190 sur 49 802 en sortie** (65 %), tous couchés sur les
## plans de coupe — donc exactement sur les joints. Ils ne portent aucune aire, mais leurs arêtes laissaient
## des bords sans partenaire, et c'est ce qu'un compteur d'arêtes ouvertes lisait comme des fentes.
## ⚠ Le seuil est RELATIF : un fil de largeur 10⁻⁶ × sa longueur ne se voit à aucune échelle.
static func _plat(a: Vector3, b: Vector3, c: Vector3) -> bool:
	var plus_long: float = maxf((b - a).length_squared(), maxf((c - b).length_squared(),
		(a - c).length_squared()))
	return (b - a).cross(c - a).length() <= 1e-6 * plus_long


## Ce triangle peut-il toucher la boîte ? Réponse CONSERVATRICE : « non » est certain, « oui » ne
## promet rien. C'est tout ce qu'un rejet précoce demande.
static func _peut_toucher(a: Vector3, b: Vector3, c: Vector3, boite: AABB) -> bool:
	var fin: Vector3 = boite.position + boite.size
	for axe in 3:
		if minf(a[axe], minf(b[axe], c[axe])) > fin[axe] + EPS:
			return false
		if maxf(a[axe], maxf(b[axe], c[axe])) < boite.position[axe] - EPS:
			return false
	return true


## Le polygone qui reste après passage par les six demi-espaces de la boîte (Sutherland-Hodgman).
## ⚠ Un polygone vidé reste vide : on sort tôt, sinon on interpolerait sur une liste vide.
static func _couper_polygone(polygone: Array, boite: AABB) -> Array:
	var reste: Array = polygone
	var fin: Vector3 = boite.position + boite.size
	for axe in 3:
		reste = _couper_par_plan(reste, axe, boite.position[axe], true)
		if reste.is_empty():
			return reste
		reste = _couper_par_plan(reste, axe, fin[axe], false)
		if reste.is_empty():
			return reste
	return reste


## Coupe par un plan perpendiculaire à `axe`. `garder_au_dessus` : on garde ce qui est ≥ `seuil`.
## ⚠ L'interpolation porte sur TOUT — position, normale, UV, COULEUR. Oublier la normale ferait une
## arête d'éclairage pile sur chaque plan de coupe, c'est-à-dire sur chaque frontière de pièce ; oublier
## la couleur ferait la même chose en teinte.
static func _couper_par_plan(polygone: Array, axe: int, seuil: float, garder_au_dessus: bool) -> Array:
	var sortie: Array = []
	var n: int = polygone.size()
	for i in n:
		var a: Dictionary = polygone[i]
		var b: Dictionary = polygone[(i + 1) % n]
		var da: float = (a["p"][axe] - seuil) if garder_au_dessus else (seuil - a["p"][axe])
		var db: float = (b["p"][axe] - seuil) if garder_au_dessus else (seuil - b["p"][axe])
		var a_dedans: bool = da >= -EPS
		var b_dedans: bool = db >= -EPS
		if a_dedans:
			sortie.append(a)
		if a_dedans != b_dedans and absf(da - db) > EPS:
			sortie.append(_entre(a, b, da / (da - db)))
	return sortie


static func _entre(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var f := clampf(t, 0.0, 1.0)
	return {
		"p": (a["p"] as Vector3).lerp(b["p"], f),
		"n": ((a["n"] as Vector3).lerp(b["n"], f)).normalized(),
		"uv": (a["uv"] as Vector2).lerp(b["uv"], f),
		"c": (a["c"] as Color).lerp(b["c"], f),
	}


## L'aire totale d'un mesh. ⚠ Sert au TEST : découper par une boîte et par son complément doit rendre
## exactement l'aire de départ. C'est l'invariant qui attrape à la fois un triangle perdu et un
## triangle compté deux fois — deux pannes qu'un simple « ça rend des triangles » laisse passer.
static func aire(mesh: Mesh) -> float:
	var totale := 0.0
	if mesh == null:
		return totale
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		if arrays.is_empty():
			continue
		var sommets: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			indices = PackedInt32Array(range(sommets.size()))
		for t in range(0, indices.size() - 2, 3):
			var a: Vector3 = sommets[indices[t]]
			var b: Vector3 = sommets[indices[t + 1]]
			var c: Vector3 = sommets[indices[t + 2]]
			totale += (b - a).cross(c - a).length() * 0.5
	return totale


## Tous les sommets d'un mesh sont-ils dans `boite`, à `marge` près ?
static func tient_dans(mesh: Mesh, boite: AABB, marge: float = 0.0001) -> bool:
	if mesh == null:
		return true
	var large := boite.grow(marge)
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		if arrays.is_empty():
			continue
		for p in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if not large.has_point(p):
				return false
	return true


## Décale et tourne un mesh, sans rien couper. ⚠ Les normales suivent la ROTATION seule : les décaler
## comme des points les enverrait à l'autre bout du monde.
static func poser(mesh: Mesh, transformation: Transform3D) -> ArrayMesh:
	var sortie := ArrayMesh.new()
	if mesh == null:
		return sortie
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		if arrays.is_empty():
			continue
		var sommets: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bouges := PackedVector3Array()
		for p in sommets:
			bouges.append(transformation * p)
		arrays[Mesh.ARRAY_VERTEX] = bouges
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var normales: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var tournees := PackedVector3Array()
			for n in normales:
				tournees.append((transformation.basis * n).normalized())
			arrays[Mesh.ARRAY_NORMAL] = tournees
		sortie.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var matiere: Material = mesh.surface_get_material(s)
		if matiere != null:
			sortie.surface_set_material(sortie.get_surface_count() - 1, matiere)
	return sortie


## Fusionne plusieurs meshes en un seul. Le matériau du premier qui en a un est conservé.
## ⚠ Les COULEURS DE SOMMET suivent, pour la même raison que dans `trancher()` : ce module ne doit pas
## perdre en silence une donnée qu'une de ses fonctions préserve déjà (`poser()`).
static func fusionner(morceaux: Array) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var c := PackedColorArray()
	var matiere: Material = null
	var avec_normales := true
	var avec_uv := true
	var avec_couleurs := true
	for morceau in morceaux:
		var mesh: Mesh = morceau
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(s)
			if arrays.is_empty():
				continue
			var sommets: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				indices = PackedInt32Array(range(sommets.size()))
			var normales: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var couleurs: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			avec_normales = avec_normales and not normales.is_empty()
			avec_uv = avec_uv and not uvs.is_empty()
			avec_couleurs = avec_couleurs and not couleurs.is_empty()
			for i in indices:
				v.append(sommets[i])
				n.append(normales[i] if normales.size() > i else Vector3.UP)
				uv.append(uvs[i] if uvs.size() > i else Vector2.ZERO)
				c.append(couleurs[i] if couleurs.size() > i else Color.WHITE)
			if matiere == null:
				matiere = mesh.surface_get_material(s)
	var sortie := ArrayMesh.new()
	if v.is_empty():
		return sortie
	var res: Array = []
	res.resize(Mesh.ARRAY_MAX)
	res[Mesh.ARRAY_VERTEX] = v
	if avec_normales:
		res[Mesh.ARRAY_NORMAL] = n
	if avec_uv:
		res[Mesh.ARRAY_TEX_UV] = uv
	if avec_couleurs:
		res[Mesh.ARRAY_COLOR] = c
	sortie.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, res)
	if matiere != null:
		sortie.surface_set_material(0, matiere)
	return sortie
