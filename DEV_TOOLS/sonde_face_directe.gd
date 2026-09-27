extends SceneTree

## SONDE — LA FACE DIRECTE EST-ELLE CONSTRUCTIBLE SANS TABLE ?
##
## ⚠ **LA DEMANDE EST DE JORDAN (25 septembre 2026)** : « trouve un moyen de supprimer l'angle et de
## faire une face directe ». Le témoin part aujourd'hui avec des escaliers, parce que sa géométrie est
## une COQUE DE SOUS-VOXELS : elle ne sait émettre que des faces perpendiculaires aux axes.
##
## ⚠ **LA MÉTHODE EST DÉJÀ ÉCRITE DANS LA CHARTE, et je ne l'avais pas vue** : « aucune opération locale
## ne peut remplacer une marche par une face directe sans franchir le plan de coupe… **il faudrait faire
## dériver la pente de la CLASSE, pas de la coque** ». On construit donc la tuile depuis ses 8 bits :
## la pièce est le cube [−0,5 ; +0,5]³ centré sur le sommet, ses huit coins SONT les centres des huit
## cases, et les sommets de la surface se posent au milieu des arêtes coupées — pile sur les plans de
## coupe, donc raccordables par construction.
##
## ⚠ **ET ON NE TAPE PAS DE TABLE DE 256 ENTRÉES.** C'est la construction habituelle, et ce projet a déjà
## payé « quatre représentants de classe tapés à la main et faux ». La triangulation doit être DÉRIVÉE.
##
## ⚠ **CE QUE CETTE SONDE TRANCHE, ET RIEN DE PLUS** : la dérivation est-elle possible ? Elle l'est si
## chaque face du cube ne porte qu'UN segment de coupe, car les segments se chaînent alors en boucles
## fermées qu'on triangule en éventail, sans aucun cas particulier. Une face porte 4 arêtes coupées
## quand son motif ALTERNE — c'est exactement la face `diagonale` que la règle de Jordan interdit.
## La sonde vérifie donc que les deux descriptions coïncident, par deux chemins indépendants :
## `MB.forme_de_face()` d'un côté, le comptage d'arêtes coupées de l'autre.

const MB := preload("res://addons/marching_blocks_plugin_godot/marching_blocks.gd")
const RP := preload("res://addons/marching_blocks_plugin_godot/repli_procedural.gd")
const BM := preload("res://addons/marching_blocks_plugin_godot/blocs_maitres.gd")


## La position d'un coin du cube de la pièce : le centre de sa case.
func _coin(t: int) -> Vector3:
	var c: Vector3i = MB.COINS[t]
	return Vector3(float(c.x) - 0.5, float(c.y) - 0.5, float(c.z) - 0.5) * (RP.OCTANT * 2.0)


## Les 12 arêtes du cube, DÉDUITES de `COINS` : les paires de coins qui diffèrent d'un seul axe.
## ⚠ Déduites, jamais tapées — c'est la règle du projet, et elle a été payée quatre fois.
func _aretes() -> Array:
	var sortie: Array = []
	for a in 8:
		for b in range(a + 1, 8):
			var d: Vector3i = MB.COINS[b] - MB.COINS[a]
			if absi(d.x) + absi(d.y) + absi(d.z) == 1:
				sortie.append([a, b])
	return sortie


## Les 6 faces du cube, chacune par ses 4 coins : un axe fixé à 0 ou à 1.
func _faces() -> Array:
	var sortie: Array = []
	for axe in 3:
		for cote in 2:
			var coins: Array = []
			for t in 8:
				if MB.COINS[t][axe] == cote:
					coins.append(t)
			sortie.append({"axe": axe, "cote": cote, "coins": coins})
	return sortie


func _initialize() -> void:
	print("=== LA FACE DIRECTE EST-ELLE CONSTRUCTIBLE SANS TABLE ? ===\n")
	var aretes: Array = _aretes()
	print("   %d arêtes déduites de COINS (il en faut 12)  ·  %d faces\n"
		% [aretes.size(), _faces().size()])

	var classes := 0
	var pire_boucles := 0
	var fautes := 0
	var faces_a_quatre := 0
	var desaccords := 0
	var total_triangles := 0

	for c in MB.classes():
		var bits: int = c["bits"]
		if not MB.porte_une_surface(bits):
			continue
		if not MB.sans_contact_diagonal(bits):
			continue
		classes += 1

		# ── combien de segments par face, et l'accord avec `forme_de_face` ──────────────────────────
		var segments := 0
		for f in _faces():
			var coupees := 0
			for paire in aretes:
				var a: int = paire[0]
				var b: int = paire[1]
				if not (a in f["coins"] and b in f["coins"]):
					continue
				if ((bits >> a) & 1) != ((bits >> b) & 1):
					coupees += 1
			if coupees == 4:
				faces_a_quatre += 1
			elif coupees == 2:
				segments += 1
			elif coupees != 0:
				fautes += 1
				print("   ⚠ %s : une face porte %d arête(s) coupée(s) — impossible"
					% [c["nom"], coupees])
			# ⚠ LE RECOUPEMENT : une face qui porte 4 coupes DOIT être celle que le modèle nomme
			# « diagonale ». Deux descriptions indépendantes du même fait ; si elles divergent, l'une
			# des deux est fausse et tout ce qui suit porte sur autre chose.
			var quatre: Array = []
			for t in f["coins"]:
				quatre.append(((bits >> t) & 1) != 0)
			var dit_diagonale: bool = MB.forme_de_face(_en_ordre_cyclique(quatre)) == "diagonale"
			if dit_diagonale != (coupees == 4):
				desaccords += 1

		# ── les segments se chaînent-ils en boucles fermées ? ───────────────────────────────────────
		# Chaque arête coupée appartient à exactement DEUX faces. Si toutes ont degré 2 dans le graphe
		# des segments, les segments forment des boucles fermées — donc triangulables en éventail.
		var degre := {}
		for paire in aretes:
			var a: int = paire[0]
			var b: int = paire[1]
			if ((bits >> a) & 1) != ((bits >> b) & 1):
				degre[str(paire)] = 0
		for f in _faces():
			var sur_cette_face: Array = []
			for paire in aretes:
				var a: int = paire[0]
				var b: int = paire[1]
				if a in f["coins"] and b in f["coins"] and ((bits >> a) & 1) != ((bits >> b) & 1):
					sur_cette_face.append(str(paire))
			if sur_cette_face.size() == 2:
				for cle in sur_cette_face:
					degre[cle] = int(degre[cle]) + 1
		var mauvais := 0
		for cle in degre:
			if int(degre[cle]) != 2:
				mauvais += 1
		if mauvais > 0:
			fautes += 1
			print("   ⚠ %s : %d arête(s) coupée(s) de degré ≠ 2 — les segments ne bouclent pas"
				% [c["nom"], mauvais])
		pire_boucles = maxi(pire_boucles, segments)
		# Un éventail sur une boucle de n sommets rend n−2 triangles ; les segments valent les sommets.
		total_triangles += maxi(0, degre.size() - 2)

	print("   %d classes atteignables examinées" % classes)
	print("   faces portant 4 arêtes coupées (ambiguës) : %d  %s"
		% [faces_a_quatre, "✓ aucune" if faces_a_quatre == 0 else "⚠"])
	print("   désaccords avec MB.forme_de_face()        : %d  %s"
		% [desaccords, "✓ les deux descriptions coïncident" if desaccords == 0 else "⚠ DIVERGENCE"])
	print("   classes dont les segments ne bouclent pas : %d  %s"
		% [fautes, "✓ toutes bouclent" if fautes == 0 else "⚠"])
	print("   au plus %d face(s) portant un segment sur une même classe" % pire_boucles)
	print("   ~%d triangles pour les %d tuiles (éventail)" % [total_triangles, classes])
	_ce_que_le_generateur_rend()
	_les_normales_pointent_elles_dehors()
	_la_peau_du_bloc_est_elle_emise()
	print("\n⚠ Elle dit que la construction est POSSIBLE, jamais que la surface est belle.")
	quit(0)


## ⚠ **LA CONSTRUCTION EST POSSIBLE ≠ LE GÉNÉRATEUR EST JUSTE.** Tout ce qui précède raisonne sur les
## bits ; ceci mesure le MAILLAGE réellement produit. Trois choses s'y vérifient, et aucune ne se voit
## sur un compteur de faisabilité :
##   • chaque classe rend une surface non vide — une classe muette serait un trou dans le monde ;
##   • aucune face perpendiculaire aux axes ne subsiste là où une pente est attendue : on compte les
##     triangles OBLIQUES, c'est-à-dire ceux qui n'existaient pas dans l'ancienne coque ;
##   • les normales sont unitaires et non dégénérées.
## ⚠ Ce qu'elle ne dit toujours pas : si la surface est BELLE. Seule une image le dira (charte §6).
func _ce_que_le_generateur_rend() -> void:
	print("\n── CE QUE LE GÉNÉRATEUR REND VRAIMENT ──")
	var vides: Array = []
	var triangles := 0
	var obliques := 0
	var degeneres := 0
	var classes := 0
	for c in MB.classes():
		var bits: int = c["bits"]
		if not MB.porte_une_surface(bits) or not MB.sans_contact_diagonal(bits):
			continue
		classes += 1
		var mesh: ArrayMesh = RP.maillage_direct(bits)
		if mesh.get_surface_count() == 0:
			vides.append(c["nom"])
			continue
		var tout: Array = mesh.surface_get_arrays(0)
		var v: PackedVector3Array = tout[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = tout[Mesh.ARRAY_NORMAL]
		for i in range(0, v.size(), 3):
			triangles += 1
			var g: Vector3 = (v[i + 1] - v[i]).cross(v[i + 2] - v[i])
			if g.length_squared() < 0.000000001:
				degeneres += 1
				continue
			var u: Vector3 = n[i]
			var aligne := false
			for axe in 3:
				if absf(absf(u[axe]) - 1.0) < 0.001:
					aligne = true
			if not aligne:
				obliques += 1
	print("   %d classe(s) · %d triangle(s) · %d OBLIQUE(S) (%.0f %%) · %d dégénéré(s)"
		% [classes, triangles, obliques,
			100.0 * float(obliques) / float(maxi(1, triangles)), degeneres])
	print("   classes rendant une surface vide : %d %s"
		% [vides.size(), str(vides.slice(0, 6)) if not vides.is_empty() else "✓"])


## ⚠ **L'IMAGE A DÉMENTI TOUS LES COMPTEURS — on cherche pourquoi, avec un instrument INDÉPENDANT.**
## La planche du témoin en faces directes rend des feuilles flottantes et des fragments, là où la coque
## en sous-voxels rend un massif plein. Hypothèse : les normales sont retournées sur une partie des
## tuiles, donc éliminées par le `cull_mode`, ce qui creuse des trous.
##
## ⚠ **LE JUGE NE DOIT RIEN PARTAGER AVEC L'ACCUSÉ.** Le générateur oriente ses faces avec le CENTRE DE
## LA MATIÈRE — une heuristique globale, et une surface en L ou en tunnel n'est pas étoilée autour de ce
## centre. On rejuge donc localement : un sommet de surface est le milieu d'une arête dont un bout est
## PLEIN et l'autre VIDE, et le dehors est la direction plein → vide. Rien d'autre.
##
## C'est exactement la mise en garde que `_ajouter_quad` porte dans sa propre note : « une convention de
## signe tenue à la main est le genre de faute qui donne un lot à moitié retourné, visible seulement à
## l'image ». Cette sonde la rend visible SANS image.
func _les_normales_pointent_elles_dehors() -> void:
	print("\n── LES NORMALES POINTENT-ELLES VERS LE VIDE ? ──")
	var aretes: Array = _aretes()
	var fautives := 0
	var total := 0
	var classes_fautives: Array = []
	for c in MB.classes():
		var bits: int = c["bits"]
		if not MB.porte_une_surface(bits) or not MB.sans_contact_diagonal(bits):
			continue
		# Le milieu de chaque arête coupée, et la direction PLEIN → VIDE qu'elle impose.
		var dehors := {}
		for paire in aretes:
			var a: int = paire[0]
			var b: int = paire[1]
			var pa: bool = ((bits >> a) & 1) != 0
			var pb: bool = ((bits >> b) & 1) != 0
			if pa == pb:
				continue
			var milieu: Vector3 = (_coin(a) + _coin(b)) * 0.5
			dehors[_cle(milieu)] = (_coin(b) - _coin(a)) if pa else (_coin(a) - _coin(b))
		var mesh: ArrayMesh = RP.maillage_direct(bits)
		if mesh.get_surface_count() == 0:
			continue
		var tout: Array = mesh.surface_get_arrays(0)
		var v: PackedVector3Array = tout[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = tout[Mesh.ARRAY_NORMAL]
		var mauvais := 0
		for i in range(0, v.size(), 3):
			total += 1
			var attendu := Vector3.ZERO
			for k in 3:
				var cle: String = _cle(v[i + k])
				if dehors.has(cle):
					attendu += (dehors[cle] as Vector3).normalized()
			if attendu.length_squared() < 0.000001:
				continue
			if n[i].dot(attendu) < 0.0:
				mauvais += 1
		if mauvais > 0:
			fautives += mauvais
			classes_fautives.append("%s(%d)" % [c["nom"], mauvais])
	print("   %d triangle(s) sur %d pointent vers la MATIÈRE  (%.0f %%)"
		% [fautives, total, 100.0 * float(fautives) / float(maxi(1, total))])
	if classes_fautives.is_empty():
		# ⚠ Ce message disait « l'orientation n'est PAS la cause — chercher ailleurs ». Il datait du
		# diagnostic, et il est devenu faux : l'orientation ÉTAIT l'une des deux causes (18 triangles
		# sur 94, sur `pointe` et les six `vrille`), et elle est corrigée. Ce contrôle est désormais un
		# GARDE contre son retour, pas une piste écartée.
		print("   ✓ aucune — le garde tient (il en comptait 18 avant la correction du 25 sept. 2026)")
	else:
		print("   classes touchées : %s" % str(classes_fautives.slice(0, 12)))


func _cle(p: Vector3) -> String:
	return "%.3f,%.3f,%.3f" % [p.x, p.y, p.z]


## ⚠ **LA SECONDE CAUSE SOUPÇONNÉE : LA PEAU EXTÉRIEURE DU BLOC N'EST JAMAIS ÉMISE.**
## 19 % de faces retournées ne peuvent pas expliquer une planche où il manque des pans entiers. La
## Convention (A) ne lit que les sommets INTÉRIEURS — ceux dont les huit cases tombent dans le bloc —
## donc la surface directe ne porte que les frontières roche/air INTERNES : la grotte, le tunnel, le
## dessous de l'arche. La coque en sous-voxels, elle, émettait aussi les faces de sciage, parce qu'elle
## construit des boîtes par cellule.
##
## ⚠ **SI C'EST ÇA, CE N'EST PAS UN BOGUE — c'est une incompatibilité de rôle.** La Convention (A) est
## juste pour RÉCOLTER des tuiles (un sommet de bord récolterait la face de sciage, pas de l'art) et
## fausse pour MONTRER le témoin, qui doit ressembler à un objet. Les deux usages veulent deux
## étendues, et c'est une décision, pas une correction.
func _la_peau_du_bloc_est_elle_emise() -> void:
	print("\n── LA PEAU EXTÉRIEURE DU BLOC EST-ELLE ÉMISE ? ──")
	var cases: Dictionary = BM.cases(0)
	var interieurs := 0
	var de_bord := 0
	for vx in range(-1, BM.COTE):
		for vy in range(-1, BM.COTE):
			for vz in range(-1, BM.COTE):
				var v := Vector3i(vx, vy, vz)
				if not MB.porte_une_surface(MB.bits(cases, v)):
					continue
				if vx >= 0 and vy >= 0 and vz >= 0 \
						and vx < BM.COTE - 1 and vy < BM.COTE - 1 and vz < BM.COTE - 1:
					interieurs += 1
				else:
					de_bord += 1
	var direct: ArrayMesh = BM.maillage_direct(0)
	var tri := 0
	if direct.get_surface_count() > 0:
		tri = (direct.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	# ⚠ « perdus » était juste pendant le diagnostic et ne l'est plus : le chemin d'AFFICHAGE émet
	# désormais les sommets de bord. Ce chiffre dit ce que la Convention (A) coûterait si on
	# l'appliquait aussi à l'affichage — c'est la mesure qui a justifié de l'en exclure, pas un manque.
	print("   sommets portant une surface : %d INTÉRIEURS, %d DE BORD"
		% [interieurs, de_bord])
	print("   (la Convention (A) seule en perdrait %.0f %% — c'est ce qui a justifié de l'étendre)"
		% [100.0 * float(de_bord) / float(maxi(1, interieurs + de_bord))])
	print("   le témoin direct rend %d triangle(s) ; la coque amincie rend %d quads"
		% [tri, 6164])


## Les quatre cellules d'une face EN ORDRE CYCLIQUE — ce que `forme_de_face()` attend.
## ⚠ `_faces()` les rend dans l'ordre des bits, où les coins 2 et 3 sont croisés par rapport au tour du
## carré. Passer l'ordre des bits ferait lire « mur » là où il y a une diagonale, et le recoupement
## n'aurait plus aucune valeur — il confirmerait une erreur au lieu d'une règle.
func _en_ordre_cyclique(quatre: Array) -> Array:
	return [quatre[0], quatre[1], quatre[3], quatre[2]]
