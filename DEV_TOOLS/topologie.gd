extends RefCounted
##
## TOPOLOGIE — la coque en SOUS-VOXELS et le BILAN d'un maillage, partagés par les sondes.
##
## ⚠ **CE MODULE EXISTE POUR QU'IL N'Y AIT QU'UNE SEULE DESCRIPTION DE CES DEUX RÈGLES.** Elles étaient
## sur le point d'être recopiées dans une seconde sonde, pour mesurer le bloc unique de 8³ alors
## qu'elles vivaient dans celle des neuf blocs de 4³. Deux copies d'un même calcul divergent — c'est
## arrivé aux deux règles de falaise de ce projet, à une heure d'intervalle.
##
## ⚠ Le contrôle qui va avec : après l'extraction, la sonde d'origine doit réimprimer **exactement** les
## mêmes chiffres. *Une extraction qui change sa sortie n'est pas une extraction.*

## Quatre sous-voxels par cellule : le retrait de l'amincissement vaut un QUART de cellule, donc cette
## subdivision représente les boîtes rentrées sans le moindre arrondi.
const SOUS := 4


## LA COQUE EN SOUS-VOXELS — la frontière de l'union des boîtes, subdivisée.
##
## `retrait` : de combien chaque face donnant sur du VIDE rentre (0 pour le solide plein).
##
## ⚠ **POURQUOI CETTE VOIE PLUTÔT QU'UN CULL.** Culler les faces internes d'un maillage aminci ouvre
## des TROUS là où deux cellules voisines n'ont pas le même retrait — mesuré : 16 arêtes de bord. Il
## faudrait alors émettre à la main l'anneau de raccord, une différence de rectangles à réussir du
## premier coup. Une frontière d'union de voxels est **fermée par construction** : il n'y a rien à
## réussir.
##
## ⚠ **MAIS ELLE N'EST PAS MANIFOLD POUR AUTANT**, et je l'ai cru à tort : là où deux cellules ne se
## touchent que par une ARÊTE, quatre faces s'y rejoignent. Mesuré sur les neuf blocs maîtres, les
## sous-voxels réparent l'essentiel de ces cas (19→3, 13→0, 13→3) parce que le retrait sépare les deux
## cellules — mais pas tous.
static func coque_sous_voxels(cases: Dictionary, retrait: float) -> ArrayMesh:
	var pleins := {}
	for c in cases:
		var p: Vector3i = c
		var mini := Vector3(p)
		var maxi := Vector3(p) + Vector3.ONE
		if retrait > 0.0:
			for axe in 3:
				var avant := Vector3i.ZERO
				avant[axe] = -1
				if not cases.has(p + avant):
					mini[axe] += retrait
				var apres := Vector3i.ZERO
				apres[axe] = 1
				if not cases.has(p + apres):
					maxi[axe] -= retrait
		var a := Vector3i(roundi(mini.x * SOUS), roundi(mini.y * SOUS), roundi(mini.z * SOUS))
		var b := Vector3i(roundi(maxi.x * SOUS), roundi(maxi.y * SOUS), roundi(maxi.z * SOUS))
		for x in range(a.x, b.x):
			for y in range(a.y, b.y):
				for z in range(a.z, b.z):
					pleins[Vector3i(x, y, z)] = true

	var sommets := PackedVector3Array()
	var pas: float = 1.0 / float(SOUS)
	for c in pleins:
		var s: Vector3i = c
		for axe in 3:
			for signe in [-1, 1]:
				var d := Vector3i.ZERO
				d[axe] = signe
				if pleins.has(s + d):
					continue
				quad(sommets, Vector3(s) * pas, (Vector3(s) + Vector3.ONE) * pas, axe, signe)
	return en_mesh(sommets)


static func quad(sommets: PackedVector3Array, mini: Vector3, maxi: Vector3,
		axe: int, signe: int) -> void:
	var autres: Array = []
	for k in 3:
		if k != axe:
			autres.append(k)
	var coins: Array = []
	for pas in [[0, 0], [0, 1], [1, 1], [1, 0]]:
		var q := Vector3.ZERO
		q[axe] = maxi[axe] if signe > 0 else mini[axe]
		q[autres[0]] = mini[autres[0]] if pas[0] == 0 else maxi[autres[0]]
		q[autres[1]] = mini[autres[1]] if pas[1] == 0 else maxi[autres[1]]
		coins.append(q)
	for k in [0, 1, 2, 0, 2, 3]:
		sommets.append(coins[k])


static func en_mesh(sommets: PackedVector3Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if sommets.is_empty():
		return mesh
	var res: Array = []
	res.resize(Mesh.ARRAY_MAX)
	res[Mesh.ARRAY_VERTEX] = sommets
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, res)
	return mesh


## LE GRAPHE DES QUADS — les arêtes du maillage une fois les DIAGONALES retirées, et les valences qui
## en découlent. C'est ce graphe-là que Blender montre après « Tris to Quads », donc celui sur lequel
## se juge la continuité des boucles d'arêtes.
##
## ⚠ **IL PREND SES DIAGONALES EN ARGUMENT, et c'est tout l'intérêt** : appelé avec les diagonales
## coplanaires il rend la mesure historique, appelé avec les tolérantes il rend celle qui vaut pour un
## maillage aux quads non plans. Une seule description, deux lectures.
static func _graphe_quads(idx: PackedInt32Array, cle_de: Dictionary, diagonales: Dictionary,
		cases: Dictionary) -> Dictionary:
	var q_aretes := {}
	var q_voisins := {}
	for t in range(0, idx.size() - 2, 3):
		var trio2: Array = [cle_de[idx[t]], cle_de[idx[t + 1]], cle_de[idx[t + 2]]]
		for i in 3:
			var a2: String = trio2[i]
			var b2: String = trio2[(i + 1) % 3]
			var e2: String = (a2 + "|" + b2) if a2 < b2 else (b2 + "|" + a2)
			if diagonales.has(e2):
				continue
			q_aretes[e2] = int(q_aretes.get(e2, 0)) + 1
			if not q_voisins.has(a2):
				q_voisins[a2] = {}
			if not q_voisins.has(b2):
				q_voisins[b2] = {}
			(q_voisins[a2] as Dictionary)[b2] = true
			(q_voisins[b2] as Dictionary)[a2] = true
	var q_bords := 0
	var q_mult := 0
	for e2 in q_aretes:
		var n3: int = int(q_aretes[e2])
		if n3 == 1:
			q_bords += 1
		elif n3 > 2:
			q_mult += 1
	var q_val := {}
	var poles: Array = []
	for s in q_voisins:
		var d2: int = (q_voisins[s] as Dictionary).size()
		q_val[d2] = int(q_val.get(d2, 0)) + 1
		if d2 == 4:
			continue
		var bouts: PackedStringArray = (s as String).split(",")
		var pos := Vector3(bouts[0].to_float(), bouts[1].to_float(), bouts[2].to_float())
		var autour := 0
		for dx in [-1, 0]:
			for dy in [-1, 0]:
				for dz in [-1, 0]:
					if cases.has(Vector3i(floori(pos.x) + dx, floori(pos.y) + dy, floori(pos.z) + dz)):
						autour += 1
		poles.append({"valence": d2, "autour": autour})
	return {"q_aretes": q_aretes.size(), "q_bords": q_bords, "q_multiples": q_mult,
		"q_val": q_val, "q_sommets": q_voisins.size(), "poles": poles}


## LE BILAN TOPOLOGIQUE d'un maillage. `cases` sert à classer les pôles (combien de cellules pleines
## entourent le point) ; il peut être vide.
##
## ⚠ **DEUX PIÈGES QUI ONT MENTI AVANT D'ÊTRE RÉPARÉS, ET QUI SONT DOCUMENTÉS ICI POUR QU'ON NE LES
## REFASSE PAS :**
##
## 1. **Les valences sur TRIANGLES ne veulent rien dire.** Chaque quad porte sa diagonale, qui ajoute
##    une arête à ses deux bouts : un sommet de valence 4 en quads apparaît en valence 6 en triangles.
##    Un premier rapport annonçait « 8 % de valence 4 » sur un solide parfait. C'est aussi pourquoi
##    « Tris to Quads » rétablit les boucles : il supprime exactement ces diagonales.
## 2. **L'appariement en quads doit se faire par la PLUS LONGUE ARÊTE, mutuelle.** Un appariement
##    glouton sur l'ordre du dictionnaire marie deux quads VOISINS coplanaires, les consomme, et laisse
##    leurs vrais partenaires orphelins — 26 à 36 triangles seuls sur des maillages faits uniquement de
##    rectangles, ce qui est géométriquement impossible.
##
## ⚠ Les arêtes sont comptées sur les POSITIONS et non sur les indices : deux sommets distincts à la
## même place font une arête géométriquement unique, et c'est ce que Blender verra.
static func bilan(mesh: ArrayMesh, cases: Dictionary = {}) -> Dictionary:
	var vide := {"sommets": 0, "triangles": 0, "doubles": 0, "aretes": 0, "bords": 0, "multiples": 0,
		"val": {}, "quads": 0, "orphelins": 0, "q_aretes": 0, "q_bords": 0, "q_multiples": 0,
		"q_val": {}, "q_sommets": 0, "poles": []}
	if mesh == null or mesh.get_surface_count() == 0:
		return vide
	var arrays: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] \
		if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if idx.is_empty():
		idx = PackedInt32Array(range(v.size()))

	var cle_de := {}
	var positions := {}
	for k in v.size():
		var c := "%.4f,%.4f,%.4f" % [v[k].x, v[k].y, v[k].z]
		cle_de[k] = c
		positions[c] = true

	var aretes := {}
	var voisins := {}
	var par_arete := {}
	var normale_de := {}
	var plus_longue := {}
	for t in range(0, idx.size() - 2, 3):
		var trio: Array = [cle_de[idx[t]], cle_de[idx[t + 1]], cle_de[idx[t + 2]]]
		var n: Vector3 = (v[idx[t + 1]] - v[idx[t]]).cross(v[idx[t + 2]] - v[idx[t]])
		normale_de[t] = n.normalized() if n.length_squared() > 0.000000001 else Vector3.ZERO
		var meilleure := ""
		var longueur := -1.0
		for i in 3:
			var a: String = trio[i]
			var b: String = trio[(i + 1) % 3]
			var e: String = (a + "|" + b) if a < b else (b + "|" + a)
			aretes[e] = int(aretes.get(e, 0)) + 1
			if not voisins.has(a):
				voisins[a] = {}
			if not voisins.has(b):
				voisins[b] = {}
			(voisins[a] as Dictionary)[b] = true
			(voisins[b] as Dictionary)[a] = true
			if not par_arete.has(e):
				par_arete[e] = []
			(par_arete[e] as Array).append(t)
			var l: float = v[idx[t + i]].distance_squared_to(v[idx[t + (i + 1) % 3]])
			if l > longueur:
				longueur = l
				meilleure = e
		plus_longue[t] = meilleure

	var bords := 0
	var multiples := 0
	for e in aretes:
		var n2: int = int(aretes[e])
		if n2 == 1:
			bords += 1
		elif n2 > 2:
			multiples += 1

	# ⚠ **DEUX COMPTAGES, ET LE SECOND EXISTE PARCE QUE LE PREMIER NE SAIT PAS TOUT VOIR.**
	# `apparies` exige que les deux triangles soient COPLANAIRES (0,9999) : c'est juste pour une coque
	# faite de rectangles, où un quad est plan par construction. Mais un quad de maillage DUAL ne l'est
	# pas — ses quatre sommets ne sont pas dans un plan — et le compteur le déclarerait « orphelin »
	# alors que Blender l'apparierait sans hésiter. Conclure « le lissage casse les boucles d'arêtes »
	# sur ce chiffre-là, ce serait accuser le sujet d'un défaut de l'instrument (charte §6).
	# `apparies_tol` apparie sur la seule règle qui compte — l'arête la plus longue, MUTUELLE — et
	# `plat_mini` dit à quel point les paires s'écartent du plan.
	# ⚠ CONTRÔLE NÉGATIF : sur une coque de rectangles, les deux comptages DOIVENT être égaux.
	var diagonales := {}
	var apparies := {}
	var apparies_tol := {}
	var diagonales_tol := {}
	var plat_mini := 1.0
	for e in par_arete:
		var ts: Array = par_arete[e]
		if ts.size() != 2:
			continue
		if plus_longue[ts[0]] != e or plus_longue[ts[1]] != e:
			continue
		var produit: float = (normale_de[ts[0]] as Vector3).dot(normale_de[ts[1]])
		if not apparies_tol.has(ts[0]) and not apparies_tol.has(ts[1]):
			apparies_tol[ts[0]] = true
			apparies_tol[ts[1]] = true
			diagonales_tol[e] = true
			plat_mini = minf(plat_mini, produit)
		if apparies.has(ts[0]) or apparies.has(ts[1]):
			continue
		if produit > 0.9999:
			apparies[ts[0]] = true
			apparies[ts[1]] = true
			diagonales[e] = true

	# ⚠ **DEUX GRAPHES, UNE SEULE DESCRIPTION.** Le même calcul, appliqué d'abord aux diagonales
	# COPLANAIRES (la règle historique) puis aux TOLÉRANTES. Le recopier pour la seconde aurait donné
	# deux descriptions d'un même fait, qui divergent toujours — c'est arrivé aux deux règles de falaise
	# de ce projet, à une heure d'intervalle (charte §6).
	var g: Dictionary = _graphe_quads(idx, cle_de, diagonales, cases)
	var g_tol: Dictionary = _graphe_quads(idx, cle_de, diagonales_tol, cases)

	var val := {}
	for s in voisins:
		var d1: int = (voisins[s] as Dictionary).size()
		val[d1] = int(val.get(d1, 0)) + 1

	return {
		"sommets": v.size(), "triangles": idx.size() / 3,
		"doubles": v.size() - positions.size(),
		"aretes": aretes.size(), "bords": bords, "multiples": multiples, "val": val,
		"quads": apparies.size() / 2, "orphelins": (idx.size() / 3) - apparies.size(),
		"quads_tolerants": apparies_tol.size() / 2,
		"orphelins_tolerants": (idx.size() / 3) - apparies_tol.size(),
		"plat_mini": plat_mini,
		"q_aretes": g["q_aretes"], "q_bords": g["q_bords"], "q_multiples": g["q_multiples"],
		"q_val": g["q_val"], "q_sommets": g["q_sommets"], "poles": g["poles"],
		"q_val_tolerant": g_tol["q_val"], "q_sommets_tolerant": g_tol["q_sommets"],
		"q_bords_tolerant": g_tol["q_bords"], "q_multiples_tolerant": g_tol["q_multiples"],
	}
