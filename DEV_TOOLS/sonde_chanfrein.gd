extends SceneTree
##
## SONDE — UN CHANFREIN TIENT-IL SANS TOUCHER AU CONTRAT DE COUTURE ?
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/UnderMend \
##       --script res://DEV_TOOLS/sonde_chanfrein.gd
##
## ── LA QUESTION, ET POURQUOI ELLE SE MESURE ─────────────────────────────────────────────────────────
##
## Jordan, 25 septembre 2026 : *« pour les chanfreins j'ai l'impression qu'il suffirait de garder les
## rebords qu'on a actuellement et de supprimer leur arête qui fait l'angle droit, et relier
## intelligemment avec des faces. »*
##
## Le geste est juste. ⚠ Mais « supprimer l'arête » seul ne suffit pas : deux faces qui partagent une
## arête, si l'on retire l'arête, se rejoignent toujours — il n'y a aucun vide à relier. Un chanfrein,
## c'est **reculer les deux faces PUIS relier**. Dans notre coque en sous-voxels, reculer d'UN sous-voxel
## revient exactement à **retirer le cube de coin et fermer par une diagonale** : le geste de Jordan est
## donc réalisable tel quel, à la granularité qui existe déjà.
##
## ⚠ **LE RISQUE N'EST PAS GÉOMÉTRIQUE, IL EST DANS LA COUTURE.** La cellule `p` occupe `[p, p+1]`, les
## plans de coupe passent par les CENTRES (`p+0,5`), et la peau amincie siège à `p+0,25`. Un chanfrein
## d'un sous-voxel s'étend de 0,25 depuis l'arête : il atterrirait donc PILE sur le plan de coupe. Une
## coïncidence aussi exacte ne se suppose pas — si le chanfrein franchit le plan, il change le germe de
## bordure, donc les raccords entre tuiles voisines, donc le contrat des 90 tuiles.
##
## ⚠ **CETTE SONDE NE CHANFREINE RIEN.** Elle mesure ce qui EXISTE, pour dire si le geste est gratuit,
## payant, ou impossible. Elle ne modifie pas `blocs_maitres.gd`.
##
## ── L'INSTRUMENT, ET CE QU'IL POURRAIT AVOIR DE FAUX ────────────────────────────────────────────────
##
## ⚠ Elle lit le maillage **réellement émis** par `BlocsMaitres`, jamais une seconde description de la
## règle : une copie du mailleur ici divergerait de celui qui part chez l'artiste, et la mesure porterait
## alors sur un objet que personne n'exporte (charte §6).
## ⚠ Les normales sont **GÉOMÉTRIQUES** (produit vectoriel des sommets), jamais celles du tableau :
## souder force une normale MOYENNE par sommet, et s'y fier a déjà coûté 23 erreurs d'octant.

const BM := preload("res://addons/undermend/blocs_maitres.gd")

## La largeur naturelle d'un chanfrein : UN sous-voxel. ⚠ DÉRIVÉE de `SOUS`, jamais écrite en dur —
## changer la subdivision sans changer ce nombre ferait mesurer un chanfrein qui n'existe pas.
var _largeur: float = 1.0 / float(BM.SOUS)


func _initialize() -> void:
	print("=== SONDE — LE CHANFREIN TOUCHE-T-IL LES PLANS DE COUPE ? ===\n")
	print("PRÉDICTION, écrite AVANT la mesure pour qu'elle puisse être démentie :")
	print("   la peau amincie siège à 0,25 du bord de cellule, le plan de coupe à 0,50 ;")
	print("   un chanfrein d'UN sous-voxel (%.2f) devrait donc ATTEINDRE le plan sans le franchir," % _largeur)
	print("   c'est-à-dire une distance minimale mesurée EXACTEMENT égale à %.2f.\n" % _largeur)
	print("largeur d'un sous-voxel : %.4f   ·   plans de coupe aux demi-entiers\n" % _largeur)

	_examiner("le SOLIDE (retrait 0)", BM.maillage(0))
	_examiner("l'AMINCI (retrait 0,25) — celui qui part chez l'artiste", BM.maillage_moitie(0))

	print("\n⚠ Cette sonde ne chanfreine rien. Elle dit si le geste est gratuit, payant, ou impossible.")
	quit(0)


## Recense les arêtes du maillage et classe celles où deux faces se rencontrent à angle droit.
func _examiner(quoi: String, mesh: ArrayMesh) -> void:
	print("── %s ──" % quoi)
	var soude: ArrayMesh = BM.souder(mesh)
	if soude.get_surface_count() == 0:
		print("   ⚠ maillage vide\n")
		return

	var arrays: Array = soude.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	# arête → les faces qui la portent, chacune avec sa normale GÉOMÉTRIQUE et son centre.
	var aretes := {}
	var t := 0
	while t + 2 < idx.size():
		var a: int = idx[t]
		var b: int = idx[t + 1]
		var c: int = idx[t + 2]
		var normale: Vector3 = (v[b] - v[a]).cross(v[c] - v[a])
		if normale.length_squared() > 0.000001:
			normale = normale.normalized()
			# ⚠ L'ENROULEMENT DE GODOT EST HORAIRE : la normale sortante est l'OPPOSÉ du produit
			# vectoriel de l'ordre stocké. S'en dispenser inverserait convexe et concave — c'est-à-dire
			# la mesure entière, et sans qu'aucun compteur ne s'en plaigne.
			normale = -normale
			var centre: Vector3 = (v[a] + v[b] + v[c]) / 3.0
			for paire in [[a, b], [b, c], [c, a]]:
				var i: int = paire[0]
				var j: int = paire[1]
				var cle: String = "%d-%d" % [mini(i, j), maxi(i, j)]
				if not aretes.has(cle):
					aretes[cle] = []
				aretes[cle].append({"n": normale, "centre": centre, "i": mini(i, j), "j": maxi(i, j)})
		t += 3

	var convexes: Array = []
	var concaves := 0
	var coplanaires := 0
	var ambigues := 0
	for cle in aretes:
		var faces: Array = aretes[cle]
		if faces.size() != 2:
			ambigues += 1
			continue
		var n1: Vector3 = faces[0]["n"]
		var n2: Vector3 = faces[1]["n"]
		if absf(n1.dot(n2)) > 0.9:
			coplanaires += 1   # les deux triangles d'un même quad, ou deux quads alignés
			continue
		# ⚠ CONVEXE OU CONCAVE : la matière est-elle DEDANS ou DEHORS du dièdre ? Si le centre de la
		# seconde face est DU CÔTÉ OPPOSÉ à la normale de la première, le coin est saillant.
		var vers: Vector3 = faces[1]["centre"] - faces[0]["centre"]
		if n1.dot(vers) < 0.0:
			convexes.append(faces[0])
		else:
			concaves += 1

	print("   arêtes : %d au total  ·  %d coplanaires  ·  %d CONVEXES  ·  %d concaves  ·  %d ambiguës"
		% [aretes.size(), coplanaires, convexes.size(), concaves, ambigues])

	if convexes.is_empty():
		print("")
		return

	# ── CE QUE LE CHANFREIN COÛTERAIT À LA COUTURE ──────────────────────────────────────────────────
	#
	# Une arête convexe court le long d'UN axe ; les deux autres coordonnées sont fixes, et ce sont
	# celles que le chanfrein fait reculer. On mesure la distance de chacune au plan de coupe le plus
	# proche : si elle est INFÉRIEURE à la largeur, le chanfrein FRANCHIT le plan.
	var distances := {}
	var mini_vu := 999.0
	for f in convexes:
		var p: Vector3 = _sommet(soude, f["i"])
		var n1: Vector3 = f["n"]
		# l'axe le long duquel l'arête court est celui où les deux sommets diffèrent
		var q: Vector3 = _sommet(soude, f["j"])
		var le_long := 0
		for axe in 3:
			if absf(q[axe] - p[axe]) > 0.0001:
				le_long = axe
		var d_mini := 999.0
		for axe in 3:
			if axe == le_long:
				continue
			var d: float = _au_plan_de_coupe(p[axe])
			d_mini = minf(d_mini, d)
		mini_vu = minf(mini_vu, d_mini)
		var cle := "%.3f" % d_mini
		distances[cle] = int(distances.get(cle, 0)) + 1

	var cles: Array = distances.keys()
	cles.sort()
	print("   distance de l'arête convexe au plan de coupe le plus proche :")
	for cle in cles:
		var d: float = float(cle)
		var verdict := "FRANCHIT le plan" if d < _largeur - 0.0001 \
			else ("l'ATTEINT pile" if d < _largeur + 0.0001 else "reste en deçà")
		print("      %6s   ×%-6d  → un chanfrein de %.2f %s" % [cle, distances[cle], _largeur, verdict])

	var franchissent := 0
	for cle in cles:
		if float(cle) < _largeur - 0.0001:
			franchissent += int(distances[cle])
	print("   VERDICT : %d arête(s) convexe(s) sur %d verraient le chanfrein FRANCHIR un plan de coupe"
		% [franchissent, convexes.size()])
	if franchissent == 0:
		print("            → le chanfrein reste DANS la tuile : la couture ne change pas.")
	else:
		print("            → ⚠ le germe de bordure CHANGE : les raccords entre tuiles sont à revoir.")
	print("")


func _sommet(mesh: ArrayMesh, k: int) -> Vector3:
	var arrays: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	return v[k]


## Distance d'une coordonnée au plan de coupe le plus proche. ⚠ Les plans passent par les CENTRES des
## cellules, donc aux DEMI-ENTIERS — les prendre aux entiers décalerait toute la mesure d'une demi-case.
func _au_plan_de_coupe(x: float) -> float:
	var r: float = x - 0.5
	return absf(r - roundf(r))
