extends SceneTree
##
## SONDE — LE BALAYAGE CHOISIT-IL LE BON EXEMPLAIRE DE CHAQUE TUILE ?
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_arbitrage.gd [-- --fichier=C:/chemin/vers/le.glb]
##
## ── POURQUOI ELLE EXISTE ────────────────────────────────────────────────────────────────────────────
##
## Jordan, 25 septembre 2026 : *« depuis le master bloc unique, peindre ne dessine plus les formes les
## plus simples en priorité, ce qui était le cas avec les 9 MB »*, et *« le plus simple mais pas
## n'importe lequel, aussi le bon en fonction du motif qu'on a peint »*.
##
## ⚠ **ET C'EST UNE RÉGRESSION ÉCRITE DE MA MAIN.** Avec neuf blocs, l'arbitrage était DÉLIBÉRÉ : « le
## premier bloc gagne, dans l'ordre du catalogue — les cinq paysages, puis la salle, puis les érosions ».
## En fondant les neuf en un, j'ai consigné dans la charte que cet arbitrage « disparaissait avec la
## bande », au motif qu'un seul bloc ne peut pas entrer en collision avec lui-même. **C'est faux** : la
## collision s'est déplacée À L'INTÉRIEUR du bloc. `tranchage.gd` fait `if pieces.has(nom): continue` et
## balaie depuis (0,0,0) en ordre lexicographique — donc chaque classe est prise au premier sommet du
## coin bas qui la produit. Une règle voulue a été remplacée par un accident d'ordre de parcours.
##
## ── CE QU'ELLE MESURE, ET CE QU'ELLE NE PEUT PAS DÉCIDER ────────────────────────────────────────────
##
## Pour chaque classe : TOUS les sommets qui la produisent, et pour chacun la pièce qu'il donnerait.
## Trois mesures concurrentes de « simple », parce qu'elles ne désignent pas les mêmes tuiles :
##
##   • TRIANGLES — le moins de géométrie ;
##   • AIRE — la moins de surface exposée ;
##   • ÉCART CANONIQUE — la plus proche de la forme que le repli procédural donnerait à cette classe.
##
## ⚠ **CE SONT DES APPROXIMATIONS DE « SIMPLE », PAS SA DÉFINITION.** Aucune n'est la bonne réponse :
## c'est Jordan qui tranchera, comme il a tranché l'ordre des neuf blocs. Une sonde ne conçoit rien.
##
## Et le CONTEXTE de chaque candidat (`MB.exterieur_possible`), pour la seconde exigence : une classe
## ambiguë livrée depuis une grotte alors que le monde la veut à l'air libre est une tuile fausse même
## si sa forme est propre.
##
## ── LE GARDE-FOU SANS LEQUEL CE TABLEAU EST À JETER ─────────────────────────────────────────────────
##
## ⚠ Pour sonder des sommets que le trancheur abandonne, je dois REFAIRE sa normalisation et sa découpe
## — donc en écrire une SECONDE DESCRIPTION, ce que la charte §6 interdit. Je la rends sûre par un
## contrôle : **la pièce que je recalcule au sommet effectivement choisi doit avoir exactement le même
## nombre de triangles que l'item du lot.** Si les deux diffèrent, ma duplication ne décrit pas le vrai
## trancheur, et je le dis au lieu de continuer.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const RP := preload("res://addons/marchingblocks_core/repli_procedural.gd")
const Decoupe := preload("res://addons/marchingblocks_core/decoupe.gd")
const Tranchage := preload("res://addons/marchingblocks_core/tranchage.gd")

var _fichier := ""


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--fichier="):
			_fichier = option.substr("--fichier=".length())

	print("=== LE BALAYAGE CHOISIT-IL LE BON EXEMPLAIRE ? ===\n")

	_etudier("LE TÉMOIN (bloc calculé)", BM.maillage_moitie(0), BM.librairie())

	if _fichier != "":
		if not FileAccess.file_exists(_fichier):
			print("⚠ INTROUVABLE : %s" % _fichier)
			quit(1)
			return
		var brut: ArrayMesh = _lire(_fichier)
		if brut == null:
			print("⚠ illisible comme glTF : %s" % _fichier)
			quit(1)
			return
		# ⚠ La même boîte tolérante que `librairie_depuis_glb` : le relief déborde légalement, et un
		# fichier revenu de Blender peut traîner des restes hors du bloc.
		var extrait: ArrayMesh = Decoupe.trancher(brut, BM.boite_du_bloc())
		_etudier("LE SCULPT de Jordan", extrait, BM.librairie_depuis_glb(_fichier))

	print("⚠ Cette sonde ne décide rien. Les trois mesures de « simple » ne désignent pas les mêmes")
	print("   tuiles, et laquelle compte n'est pas une question de mesure.")
	quit(0)


func _etudier(quoi: String, solide: ArrayMesh, bilan: Dictionary) -> void:
	print("── %s ──" % quoi)
	var pleines: Dictionary = BM.cases(0)
	var cellule := 1.0

	# ── la normalisation, recopiée de `trancher` et vérifiée plus bas ────────────────────────────────
	var mini := Vector3.INF
	var maxi := -Vector3.INF
	for c in pleines:
		var p: Vector3i = c
		mini = mini.min(Vector3(p))
		maxi = maxi.max(Vector3(p) + Vector3.ONE)
	var centre_attendu: Vector3 = (mini + maxi) * 0.5 * cellule
	var boite: AABB = solide.get_aabb()
	var origine: Vector3 = boite.get_center() - centre_attendu
	var normalise: ArrayMesh = Decoupe.poser(solide, Transform3D(Basis(), -origine))

	var grille := GridMap.new()
	var candidats := {}     # nom de classe → [ {v, triangles, aire, dehors} ]
	var ordre: Array = []   # les noms dans l'ordre où le balayage les rencontre

	for vx in range(0, BM.COTE - 1):
		for vy in range(0, BM.COTE - 1):
			for vz in range(0, BM.COTE - 1):
				var v := Vector3i(vx, vy, vz)
				var bits: int = MB.bits(pleines, v)
				var r: Dictionary = MB.classer(bits)
				if not r["surface"]:
					continue
				var morceau: ArrayMesh = Decoupe.trancher(normalise,
					Tranchage.boite_du_sommet(v, cellule))
				if morceau.get_surface_count() == 0:
					continue
				var centre := (Vector3(v) + Vector3.ONE) * cellule
				var recentre: ArrayMesh = Decoupe.poser(morceau,
					Transform3D(Basis().scaled(Vector3.ONE / cellule), Vector3.ZERO)
						* Transform3D(Basis(), -centre))
				var base: Basis = grille.get_basis_with_orthogonal_index(r["orientation"])
				var reference: ArrayMesh = Decoupe.poser(recentre,
					Transform3D(base.transposed(), Vector3.ZERO))
				var nom: String = r["nom"]
				if not candidats.has(nom):
					candidats[nom] = []
					ordre.append(nom)
				(candidats[nom] as Array).append({
					"v": v,
					"triangles": _triangles(reference),
					"aire": Decoupe.aire(reference),
					"dehors": MB.exterieur_possible(bits),
					"bits": bits,
				})
	grille.free()

	# ── LE CONTRÔLE DE FIDÉLITÉ ─────────────────────────────────────────────────────────────────────
	var lot: MeshLibrary = bilan["lot"]
	var ecarts := 0
	var compares := 0
	for nom in candidats:
		var id: int = lot.find_item_by_name(nom)
		if id < 0:
			continue
		var m: ArrayMesh = lot.get_item_mesh(id) as ArrayMesh
		if m == null:
			continue
		compares += 1
		# le premier candidat dans l'ordre du balayage est celui que le trancheur garde
		var choisi: Dictionary = (candidats[nom] as Array)[0]
		if _triangles(m) != int(choisi["triangles"]):
			ecarts += 1
	print("   fidélité : %d classe(s) comparées, %d écart(s) avec le lot réel" % [compares, ecarts])
	if ecarts > 0:
		print("   ⚠⚠ MA DÉCOUPE NE REPRODUIT PAS CELLE DU TRANCHEUR — le tableau ci-dessous est à jeter.\n")
		return
	print("   ✓ ma découpe reproduit celle du trancheur : le tableau qui suit est exploitable")

	# ── COMBIEN DE CHOIX Y AVAIT-IL, ET LE CHOISI EST-IL LE PLUS SIMPLE ? ────────────────────────────
	var pas_le_plus_simple: Array = []
	var somme_choix := 0
	var desaccords := {"triangles": 0, "aire": 0, "canonique": 0}
	for nom in ordre:
		var liste: Array = candidats[nom]
		somme_choix += liste.size()
		if liste.size() < 2:
			continue
		var choisi: Dictionary = liste[0]
		var aire_ref: float = Decoupe.aire(RP.maillage(int(choisi["bits"])))

		var meilleur_tri: Dictionary = liste[0]
		var meilleur_aire: Dictionary = liste[0]
		var meilleur_can: Dictionary = liste[0]
		for c in liste:
			if int(c["triangles"]) < int(meilleur_tri["triangles"]):
				meilleur_tri = c
			if float(c["aire"]) < float(meilleur_aire["aire"]):
				meilleur_aire = c
			if absf(float(c["aire"]) - aire_ref) < absf(float(meilleur_can["aire"]) - aire_ref):
				meilleur_can = c
		if meilleur_tri["v"] != choisi["v"]:
			desaccords["triangles"] += 1
		if meilleur_aire["v"] != choisi["v"]:
			desaccords["aire"] += 1
		if meilleur_can["v"] != choisi["v"]:
			desaccords["canonique"] += 1
		if meilleur_tri["v"] != choisi["v"]:
			pas_le_plus_simple.append({
				"nom": nom, "choix": liste.size(),
				"choisi": choisi, "simple": meilleur_tri, "canon": meilleur_can,
				"aire_ref": aire_ref,
			})

	print("   %d classe(s)  ·  %d candidat(s) au total  ·  %.1f candidat(s) par classe en moyenne"
		% [ordre.size(), somme_choix, float(somme_choix) / maxf(1.0, float(ordre.size()))])
	print("   ⚠ le sommet choisi N'EST PAS le meilleur pour :")
	print("        %d classe(s) selon les TRIANGLES" % int(desaccords["triangles"]))
	print("        %d classe(s) selon l'AIRE" % int(desaccords["aire"]))
	print("        %d classe(s) selon l'ÉCART CANONIQUE" % int(desaccords["canonique"]))

	pas_le_plus_simple.sort_custom(func(a, b):
		return int(a["choisi"]["triangles"]) - int(a["simple"]["triangles"]) \
			> int(b["choisi"]["triangles"]) - int(b["simple"]["triangles"]))
	print("\n   LES DIX PIRES ÉCARTS (choisi contre le plus simple disponible) :")
	print("      %-24s %6s %22s %22s" % ["classe", "choix", "CHOISI par le balayage", "le PLUS SIMPLE"])
	for e in pas_le_plus_simple.slice(0, 10):
		var c: Dictionary = e["choisi"]
		var s: Dictionary = e["simple"]
		print("      %-24s %6d   %3d tri, aire %5.2f %s   %3d tri, aire %5.2f %s  au %s"
			% [e["nom"], int(e["choix"]),
				int(c["triangles"]), float(c["aire"]), "dehors" if c["dehors"] else "dedans",
				int(s["triangles"]), float(s["aire"]), "dehors" if s["dehors"] else "dedans",
				str(s["v"])])

	# ── LE CONTEXTE : une classe ambiguë est-elle livrée du mauvais côté ? ───────────────────────────
	#
	# ⚠ C'est la seconde exigence de Jordan, et elle ne se réduit pas à la simplicité : une tuile de
	# forme propre prise dans une grotte reste fausse pour un sol de massif.
	var ambigues: Array = []
	for nom in ordre:
		var liste: Array = candidats[nom]
		var dehors := 0
		var dedans := 0
		for c in liste:
			if c["dehors"]:
				dehors += 1
			else:
				dedans += 1
		if dehors > 0 and dedans > 0:
			ambigues.append({"nom": nom, "dehors": dehors, "dedans": dedans,
				"choisi_dehors": (liste[0] as Dictionary)["dehors"]})
	print("\n   CONTEXTE — %d classe(s) disponibles dans les DEUX contextes dans ce bloc :" % ambigues.size())
	for a in ambigues.slice(0, 12):
		print("      %-24s %2d dehors / %2d dedans   → le balayage a pris : %s"
			% [a["nom"], int(a["dehors"]), int(a["dedans"]),
				"DEHORS" if a["choisi_dehors"] else "DEDANS"])
	print("")


func _triangles(mesh: ArrayMesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		if arrays.is_empty():
			continue
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] \
			if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		n += (idx.size() if not idx.is_empty()
			else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n


## Lit le premier ArrayMesh d'un `.glb` hors du projet.
## ⚠ ON RECONNAÎT UN NŒUD À CE QU'IL SAIT FAIRE : le chemin glTF de l'éditeur rend des
## `ImporterMeshInstance3D`, qui N'HÉRITENT PAS de `MeshInstance3D` — un `is MeshInstance3D` a déjà
## déclaré « aucun ArrayMesh » sur un fichier parfaitement valide.
func _lire(chemin: String) -> ArrayMesh:
	var document := GLTFDocument.new()
	var etat := GLTFState.new()
	if document.append_from_file(chemin, etat) != OK:
		return null
	var scene: Node = document.generate_scene(etat)
	if scene == null:
		return null
	var trouve: ArrayMesh = _chercher(scene)
	scene.queue_free()
	return trouve


func _chercher(noeud: Node) -> ArrayMesh:
	if noeud.has_method("get_mesh"):
		var m = noeud.call("get_mesh")
		if m is ArrayMesh:
			return m
	for enfant in noeud.get_children():
		var t: ArrayMesh = _chercher(enfant)
		if t != null:
			return t
	return null
