extends SceneTree
##
## TEST — le bloc maître unique : la planète paysage de 12³, 52 tuiles du monde sans diagonale.
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_blocs_maitres.gd
##
## ⚠ **CE QUE CE TEST GARDE, ET POURQUOI IL EXISTE.** `blocs_maitres.gd` mêle deux natures : neuf
## remplissages ÉCRITS à la main (en couches ASCII) et tous les décomptes DÉRIVÉS d'eux. Le risque n'est
## pas qu'un chiffre soit faux — il est calculé — c'est que **l'écrit cesse de produire le dérivé** : on
## retouche une couche pour embellir un bloc, et la couverture tombe de 68 à 66 sans qu'on le voie.
##
## C'est arrivé pendant la construction : la première « salle de grotte » était une coque creuse, elle ne
## livrait **aucun surplomb**, donc `mb_arete_b0h2` n'avait aucune source d'intérieur. Le décompte global
## disait pourtant 68/68. **Un compteur vert ne dit jamais qu'une tuile est à SA place** (charte §6) — il
## fallait un second contrôle pour le voir.
##
## ⚠ Ce second contrôle était `interieures_manquantes()`, qui consultait une liste `AMBIGUES` écrite à
## l'observation. La mesure a invalidé sa prémisse — elle annonçait « l'usage en exerce 5 », or les neuf
## blocs en exposent **10** et un seul monde d'essai **35**. Le contexte se DÉDUIT donc du modèle
## (`MB.exterieur_possible`). **La leçon survit, l'instrument non.**
##
## ── LES ATTENTES, DÉRIVÉES DU MODÈLE ET NON RELUES DU MODULE ─────────────────────────────────────────
##
##   • le nombre de cases d'un bloc est RECOMPTÉ ici, caractère par caractère, sans appeler `cases()` ;
##   • la couverture totale est comparée à `MB.pieces_a_sculpter().size()`, jamais à « 68 » écrit en dur ;
##   • un bloc ne lit que ses sommets INTÉRIEURS : au plus (COTE−1)³, et jamais un sommet hors bornes ;
##   • une salle creuse DOIT présenter un plafond (`mb_plaque_b0h4`) — c'est une conséquence du modèle,
##     pas une lecture du module : si l'on creuse une chambre, quelque chose la couvre ;
##   • un bloc PLEIN ne livrerait rien du tout (tous ses sommets voient huit cellules pleines), donc
##     chaque bloc doit livrer au moins une classe — un bloc muet est un bloc inutile ;
##   • le cumul est CROISSANT et se termine au total.
##
## ⚠ **CE QUE CE TEST NE GARDE PAS, ET IL FAUT LE DIRE.** Il ne juge pas si une forme est SCULPTABLE ni
## si son nom lui va : ça ne se voit qu'à l'image (`DEV_TOOLS/planche_blocs_maitres.gd`), avec Jordan.
## Les trois blocs « érosion » passeraient ce test en étant illisibles — c'est précisément pourquoi ils
## sont nommés « érosion » et pas « massif ».

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const BlocsMaitres := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const Tranchage := preload("res://addons/marchingblocks_core/tranchage.gd")
## ⚠ On EMPRUNTE le bilan topologique plutôt que d'en recopier le calcul : deux descriptions d'un même
## fait divergent toujours, et celle-ci porte déjà deux pièges payés cher (charte §6).
const Topo := preload("res://DEV_TOOLS/topologie.gd")
## Les trois teintes de base du témoin : tout le reste est une roche souterraine assombrie.
const RP := preload("res://addons/marchingblocks_core/repli_procedural.gd")

var _ok := 0
var _echecs := 0
var _premier := ""


func _initialize() -> void:
	print("=== TEST — le bloc maître unique ===\n")
	_le_module_ne_signale_aucune_anomalie()
	_les_cases_sont_celles_qu_on_a_ecrites()
	_chaque_bloc_livre_quelque_chose()
	_on_ne_lit_que_les_sommets_interieurs()
	_la_couverture_est_complete()
	_la_partition_des_contextes_est_derivee()
	_le_temoin_livre_exactement_le_monde()
	_le_temoin_revient_avec_ses_six_teintes()
	_le_temoin_part_soude()
	_les_uv_sont_canoniques()
	_la_pose_du_noeud_est_lue()
	_le_cumul_est_croissant()
	_les_maillages_existent_et_tiennent_dans_le_bloc()
	_la_geometrie_livree_est_saine()
	_la_legende_du_temoin_dit_le_contexte()
	_une_tuile_par_cle()
	_le_temoin_prouve_tous_les_raccords()
	_le_temoin_lie_fait_l_aller_retour()

	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	if _echecs > 0:
		print("PREMIER ÉCHEC — %s" % _premier)
	print("VERDICT : %s" % ("ÉCHEC" if _echecs > 0 else "OK"))
	quit(1 if _echecs > 0 else 0)


func _dire(condition: bool, quoi: String) -> void:
	if condition:
		_ok += 1
	else:
		_echecs += 1
		if _premier == "":
			_premier = quoi
		if _echecs <= 12:
			print("  ÉCHEC — %s" % quoi)


# ── les vérifications ───────────────────────────────────────────────────────────────────────────────

func _le_module_ne_signale_aucune_anomalie() -> void:
	var fautes: Array = BlocsMaitres.anomalies()
	_dire(fautes.is_empty(), "anomalies() rend %d faute(s) : %s"
		% [fautes.size(), str(fautes.slice(0, 4))])
	print("  anomalies() : %d" % fautes.size())


## ⚠ RECOMPTÉ ICI, caractère par caractère. Appeler `cases()` puis comparer à `cases()` ne prouverait
## rien — c'est la tautologie que Jordan a relevée sur la première planche du repli.
func _les_cases_sont_celles_qu_on_a_ecrites() -> void:
	for i in BlocsMaitres.nombre():
		var attendu := 0
		var couches: Array = BlocsMaitres.BLOCS[i]["couches"]
		for y in couches.size():
			for z in (couches[y] as Array).size():
				var rangee: String = couches[y][z]
				for x in rangee.length():
					if rangee[x] == "#":
						attendu += 1
		var obtenu: int = BlocsMaitres.cases(i).size()
		_dire(obtenu == attendu, "« %s » : cases() rend %d cellules, les couches en portent %d"
			% [BlocsMaitres.BLOCS[i]["nom"], obtenu, attendu])
		# Et aucune cellule hors du cube COTE³.
		for c in BlocsMaitres.cases(i):
			var p: Vector3i = c
			var dedans: bool = p.x >= 0 and p.y >= 0 and p.z >= 0 \
				and p.x < BlocsMaitres.COTE and p.y < BlocsMaitres.COTE and p.z < BlocsMaitres.COTE
			_dire(dedans, "« %s » : la cellule %s sort du cube" % [BlocsMaitres.BLOCS[i]["nom"], str(p)])


func _chaque_bloc_livre_quelque_chose() -> void:
	for i in BlocsMaitres.nombre():
		var n: int = BlocsMaitres.classes_de(i).size()
		_dire(n > 0, "« %s » ne livre AUCUNE classe — un bloc muet est un bloc inutile"
			% BlocsMaitres.BLOCS[i]["nom"])


## Un bloc de COTE cellules n'a que (COTE−1)³ sommets dont les huit cellules tombent dedans. Compter
## au-delà ferait croire à une couverture que le bloc ne livre pas, puisque les autres sommets dépendent
## de ce qu'il y a AUTOUR — et autour, il n'y a rien.
func _on_ne_lit_que_les_sommets_interieurs() -> void:
	var plafond: int = int(pow(BlocsMaitres.COTE - 1, 3))
	for i in BlocsMaitres.nombre():
		var pieces: Array = BlocsMaitres.pieces_de(i)
		_dire(pieces.size() <= plafond, "« %s » : %d pièces pour %d sommets intérieurs au plus"
			% [BlocsMaitres.BLOCS[i]["nom"], pieces.size(), plafond])
		for p in pieces:
			var v: Vector3i = p["sommet"]
			var dedans: bool = v.x >= 0 and v.y >= 0 and v.z >= 0 \
				and v.x < BlocsMaitres.COTE - 1 and v.y < BlocsMaitres.COTE - 1 \
				and v.z < BlocsMaitres.COTE - 1
			_dire(dedans, "« %s » : le sommet %s n'est pas intérieur"
				% [BlocsMaitres.BLOCS[i]["nom"], str(v)])


## ⚠ COMPARÉ AU MODÈLE, jamais à « 68 » écrit en dur : le jour où le groupe de pose change
## (`MB.GROUPE`), ce test doit suivre tout seul ou dire clairement que les blocs ne suffisent plus.
func _la_couverture_est_complete() -> void:
	var total: int = MB.pieces_a_sculpter().size()
	var absentes: Array = BlocsMaitres.manquantes()
	_dire(absentes.is_empty(), "%d classe(s) qu'aucun bloc ne livre : %s"
		% [absentes.size(), str(absentes.slice(0, 6))])
	var vus := {}
	for i in BlocsMaitres.nombre():
		for n in BlocsMaitres.classes_de(i):
			vus[n] = true
	_dire(vus.size() == total, "les blocs livrent %d classes, le modèle en demande %d"
		% [vus.size(), total])
	print("  couverture : %d / %d classes de surface" % [vus.size(), total])


## ⚠ **CE TEST REMPLACE `_les_ambigues_ont_une_source_d_interieur()`, ET C'EST UNE CORRECTION DE FOND.**
## L'ancien vérifiait qu'un bloc d'INTÉRIEUR livrait les cinq classes d'une liste dressée à
## l'observation. La mesure a invalidé sa prémisse : les neuf blocs exposent **10** classes dans les deux
## contextes, et un seul monde d'essai en expose **35**. On garde donc la DÉDUCTION, pas la liste.
func _la_partition_des_contextes_est_derivee() -> void:
	# ⚠ C'est le MODÈLE qu'on partitionne ici (68 = 22 + 46), pas le monde sans diagonale : les
	# pièces à sculpter (35) ne sont plus le bon total depuis le 27 septembre 2026.
	var total: int = MB.classes_de_surface().size()
	var dehors: Array = MB.classes_exterieures()
	_dire(dehors.size() == 22,
		"22 classes peuvent être à l'air libre, le modèle en rend %d" % dehors.size())
	_dire(total - dehors.size() == 46,
		"46 classes doivent être structurellement intérieures, il y en a %d" % (total - dehors.size()))

	# ⚠ **L'ASSERTION LISIBLE PAR UN HUMAIN, et celle qui rougit si le haut et le bas sont inversés.**
	# Un compte qui tombe juste ne dit pas que le critère regarde dans le bon sens ; ces deux noms-là le
	# disent, parce qu'un plafond sous le ciel n'a aucun sens pour personne.
	var noms := {}
	for n in dehors:
		noms[n] = true
	_dire(noms.has("mb_plaque_b4h0"), "un SOL plat (mb_plaque_b4h0) doit pouvoir être à l'air libre")
	_dire(not noms.has("mb_plaque_b0h4"),
		"un PLAFOND (mb_plaque_b0h4) ne peut PAS être à l'air libre : il a de la roche au-dessus")

	# ⚠ **L'INVARIANCE PAR ROTATION EST MESURÉE, PAS SUPPOSÉE.** Le verdict doit être le même pour une
	# configuration et pour le représentant de sa classe — sinon ce ne serait pas une propriété de la
	# CLASSE, et une partition « par classe » n'aurait aucun sens. J'ai raisonné que le groupe orienté ne
	# tourne qu'autour de Y, donc préserve le haut et le bas ; ce raisonnement se vérifie ici sur les 256.
	var divergents := 0
	for b in 256:
		if not MB.porte_une_surface(b):
			continue
		var r: Dictionary = MB.classer(b)
		var reference: int = MB.classes()[r["classe"]]["bits"]
		if MB.exterieur_possible(b) != MB.exterieur_possible(reference):
			divergents += 1
	_dire(divergents == 0,
		"%d configuration(s) ne s'accordent pas avec le représentant de leur classe" % divergents)
	print("  contexte du modèle : %d à l'air libre possible, %d intérieures seulement"
		% [dehors.size(), total - dehors.size()])


## ⚠ **LA COUVERTURE N'EST PAS LA LIVRAISON — et les deux ont déjà divergé ici** (charte §2 : la machine
## annonçait 90/90 quand le greffon en livrait 73). `_la_couverture_est_complete` compte des classes
## NUES ; ce contrôle-ci ouvre ce que `librairie()` rend vraiment, variantes d'air libre comprises, et
## le compare à une attente bâtie ICI depuis les bits — sans appeler `pieces_a_sculpter()` ni
## `exterieures_a_sculpter()`, qui décident déjà de ce que le module vise.
##
## ⚠ **ET LE TÉMOIN N'A AUCUN CONTACT DIAGONAL SUR SES SOMMETS INTÉRIEURS.** C'est la promesse du monde
## qu'il montre : un témoin qui en porterait livrerait une tuile que le monde ne pose jamais, et
## rouvrirait l'ambiguïté non-manifold que ce monde a fermée.
## ⚠ **LE TÉMOIN EXPORTÉ DOIT REVENIR AVEC SES SIX TEINTES.** Il part en six surfaces nommées
## (`par_teinte`) et sans normales ; relu, il passait par `normales_plates()`, qui fondait tout en UNE
## surface sous « Floor - open air » — un réimport direct revenait entièrement vert. Aucune suite ne
## relisait un export : c'est ce trou-là que ce contrôle bouche.
func _le_temoin_revient_avec_ses_six_teintes() -> void:
	var chemin: String = ProjectSettings.globalize_path("user://aller_retour_test.obj")
	var raison: String = BlocsMaitres.exporter_le_bloc(chemin)
	_dire(raison == "", "l'export du témoin échoue : %s" % raison)
	if raison != "":
		return
	var relu: ArrayMesh = BlocsMaitres._lire_glb(chemin, [])
	_dire(relu != null, "le témoin exporté ne se relit pas")
	if relu == null:
		return
	var noms := {}
	for s in relu.get_surface_count():
		var m: Material = relu.surface_get_material(s)
		if m != null:
			noms[m.resource_name] = true
	var manquent: Array = []
	for t in RP.TEINTES:
		if not noms.has(t["nom"]):
			manquent.append(t["nom"])
	_dire(relu.get_surface_count() == RP.TEINTES.size() and manquent.is_empty(),
		"le témoin revient en %d surface(s) ; teintes perdues : %s"
			% [relu.get_surface_count(), str(manquent)])
	DirAccess.remove_absolute(chemin)
	DirAccess.remove_absolute(chemin.get_basename() + ".mtl")
	print("  aller-retour : %d surfaces, %d teintes nommées" % [relu.get_surface_count(), noms.size()])


## ⚠ **LE TÉMOIN PART SOUDÉ, ET ÇA SE LIT DANS LE FICHIER.** Il a quitté le logiciel en soupe de
## triangles pendant une journée alors que la charte le disait soudé : aucun contrôle ne regardait le
## FICHIER. Celui-ci lit l'OBJ tel quel, sans le lecteur du module — l'attendu ne vient pas de la fonction
## éprouvée (charte §6) : une position n'est écrite qu'une fois, et chaque arête borde EXACTEMENT deux
## faces, par INDICE de sommet (ce que Blender verra). Mesuré dans Blender 5.1 : 15 546 sommets, 0 bord.
func _le_temoin_part_soude() -> void:
	var chemin: String = ProjectSettings.globalize_path("user://soudure_test.obj")
	var raison: String = BlocsMaitres.exporter_le_bloc(chemin)
	_dire(raison == "", "l'export OBJ échoue : %s" % raison)
	if raison != "":
		return
	var positions := {}
	var n_sommets := 0
	var aretes := {}
	var n_faces := 0
	for ligne in FileAccess.get_file_as_string(chemin).split("
"):
		if ligne.begins_with("v "):
			n_sommets += 1
			positions[ligne.substr(2)] = true
		elif ligne.begins_with("f "):
			n_faces += 1
			var ids: Array = []
			for j in ligne.substr(2).split(" ", false):
				ids.append(int(j.split("/")[0]))
			for k in ids.size():
				var a: int = ids[k]
				var b: int = ids[(k + 1) % ids.size()]
				var e := Vector2i(mini(a, b), maxi(a, b))
				aretes[e] = int(aretes.get(e, 0)) + 1
	var bords := 0
	var surchargees := 0
	for e in aretes:
		if aretes[e] == 1:
			bords += 1
		elif aretes[e] > 2:
			surchargees += 1
	_dire(n_sommets == positions.size(), "l'OBJ écrit %d sommets pour %d positions : des sommets en double"
		% [n_sommets, positions.size()])
	_dire(bords == 0, "l'OBJ a %d arête(s) de bord : des coutures chez l'artiste" % bords)
	_dire(surchargees == 0, "l'OBJ a %d arête(s) à trois faces ou plus" % surchargees)
	DirAccess.remove_absolute(chemin)
	DirAccess.remove_absolute(chemin.get_basename() + ".mtl")
	print("  soudure : %d sommets, %d faces, %d bord(s)" % [n_sommets, n_faces, bords])


## ⚠ **LA POSE DU NŒUD EST LUE.** L'importeur OBJ de Blender tourne l'OBJET de 90° au lieu de convertir
## les sommets, et le .glb qu'il réécrit garde cette rotation : lue sans elle, l'œuvre revenait couchée
## (41 erreurs de tranchage). Scénario CONSTRUIT : un cube unité posé par un nœud tourné de −90° en X et
## translaté de (5, 0, 0) — l'attendu est calculé à la main : x ∈ [5, 6], y ∈ [0, 1], z ∈ [−1, 0].
## §15 — LES UV CANONIQUES : toutes les copies d'une clé portent les mêmes UV, et deux clés jamais.
##
## ⚠ **L'AUTORITÉ EST LE TRANCHEUR, PAS LA FONCTION D'UV.** On exporte l'OBJ, on le RELIT et on le
## TRANCHE comme un travail revenu de Blender ; ce qui fait foi, ce sont les tuiles du lot. Aucune
## formule d'atlas n'est recalculée ici : l'attendu est une COHÉRENCE (« même point de référence, même
## UV »), que la fonction ne peut pas satisfaire en se trompant de repère.
## ⚠ Et ça garde du même coup l'aller-retour des UV : écrites en `vt`, relues, transportées par la découpe.
func _les_uv_sont_canoniques() -> void:
	var chemin: String = ProjectSettings.globalize_path("user://uv_test.obj")
	var raison: String = BlocsMaitres.exporter_le_bloc(chemin)
	_dire(raison == "", "l'export OBJ échoue : %s" % raison)
	if raison != "":
		return
	var faces_sans_uv := 0
	var n_vt := 0
	for ligne in FileAccess.get_file_as_string(chemin).split("\n"):
		if ligne.begins_with("vt "):
			n_vt += 1
		elif ligne.begins_with("f "):
			for j in ligne.substr(2).split(" ", false):
				if j.split("/").size() < 2 or j.split("/")[1] == "":
					faces_sans_uv += 1
					break
	_dire(n_vt > 0 and faces_sans_uv == 0,
		"l'OBJ du témoin porte %d vt, et %d face(s) sans UV" % [n_vt, faces_sans_uv])

	# ⚠ **UNE TUILE PAR CLÉ (charte §3, 30 septembre 2026) : le lot ne porte plus qu'UNE copie de chaque clé.**
	# La cohérence entre copies se juge donc sur l'OBJ lui-même, qui les porte TOUTES (549 sommets) : chaque
	# triangle est rendu à son sommet et à sa clé, ramené au repère de RÉFÉRENCE par la base du peintre — un
	# calcul de repère écrit ICI, sans la formule d'atlas —, et « même clé, même point, même sens, même UV ».
	var relu: ArrayMesh = BlocsMaitres._lire_obj(chemin)
	var pleines: Dictionary = BlocsMaitres.cases(0)
	var plafond: int = MB.plafond_de(pleines)
	var grille := GridMap.new()
	var par_cle := {}           # clé → {point de référence|sens : UV}
	var proprietaire := {}      # centre d'UV d'un triangle → clé
	var dans_l_occurrence := {} # sommet → {centre d'UV : centre de position}
	var incoherents := 0
	var partages := 0
	var recouvrements := 0
	var occurrences := {}
	for s_ in relu.get_surface_count():
		var arrays: Array = relu.surface_get_arrays(s_)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var idx = arrays[Mesh.ARRAY_INDEX]
		var ordre: PackedInt32Array = (idx as PackedInt32Array) if idx != null else PackedInt32Array(range(v.size()))
		for t in range(0, ordre.size() - 2, 3):
			var a3: Vector3 = v[ordre[t]]
			var b3: Vector3 = v[ordre[t + 1]]
			var c3: Vector3 = v[ordre[t + 2]]
			var centre: Vector3 = (a3 + b3 + c3) / 3.0
			var sommet := Vector3i(floori(centre.x - 0.5), floori(centre.y - 0.5), floori(centre.z - 0.5))
			var interieur: bool = sommet.x >= 0 and sommet.y >= 0 and sommet.z >= 0 \
				and sommet.x < BlocsMaitres.COTE - 1 and sommet.y < BlocsMaitres.COTE - 1 and sommet.z < BlocsMaitres.COTE - 1
			var r: Dictionary = Tranchage.cle_du_sommet(pleines, sommet, plafond) if interieur else {}
			if r.is_empty() or uv.is_empty():
				continue
			var cle: String = r["cle"]
			occurrences[sommet] = true
			var inverse: Basis = grille.get_basis_with_orthogonal_index(r["orientation"]).transposed()
			var geo: Vector3 = inverse * -(b3 - a3).cross(c3 - a3)
			if geo.length_squared() < 1e-10:
				continue
			var axe := 0
			for j in 3:
				if absf(geo[j]) > absf(geo[axe]):
					axe = j
			var sens: int = axe * 2 + (0 if geo[axe] > 0.0 else 1)
			if not par_cle.has(cle):
				par_cle[cle] = {}
			for k in 3:
				var q: Vector3 = inverse * (v[ordre[t + k]] - (Vector3(sommet) + Vector3.ONE))
				var point := "%d,%d,%d|%d" % [roundi(q.x * 1000.0), roundi(q.y * 1000.0), roundi(q.z * 1000.0), sens]
				var u: Vector2 = uv[ordre[t + k]]
				if par_cle[cle].has(point):
					if not (par_cle[cle][point] as Vector2).is_equal_approx(u):
						incoherents += 1
				else:
					par_cle[cle][point] = u
			var cu: Vector2 = (uv[ordre[t]] + uv[ordre[t + 1]] + uv[ordre[t + 2]]) / 3.0
			var cle_uv := Vector2i(roundi(cu.x * 100000.0), roundi(cu.y * 100000.0))
			if proprietaire.has(cle_uv) and proprietaire[cle_uv] != cle:
				partages += 1
			proprietaire[cle_uv] = cle
			if not dans_l_occurrence.has(sommet):
				dans_l_occurrence[sommet] = {}
			var cle_p := Vector3i(roundi(centre.x * 1000.0), roundi(centre.y * 1000.0), roundi(centre.z * 1000.0))
			if dans_l_occurrence[sommet].has(cle_uv) and dans_l_occurrence[sommet][cle_uv] != cle_p:
				recouvrements += 1
			dans_l_occurrence[sommet][cle_uv] = cle_p
	grille.free()
	_dire(occurrences.size() > par_cle.size() * 5,
		"l'OBJ ne montre que %d occurrences pour %d clés : la cohérence entre copies n'est pas éprouvée"
		% [occurrences.size(), par_cle.size()])
	_dire(incoherents == 0, "%d coin(s) où deux copies d'une clé n'ont pas la même UV" % incoherents)
	_dire(partages == 0, "%d triangle(s) dont l'UV tombe dans la région d'une AUTRE clé" % partages)
	_dire(recouvrements == 0, "%d triangle(s) qui se recouvrent en UV dans une même copie" % recouvrements)

	# ET LA TUILE DU LOT (tranchée depuis l'OBJ relu) PORTE CES UV-LÀ : l'aller-retour `vt` → découpe → lot.
	var resultat: Dictionary = BlocsMaitres.librairie_depuis_glb(chemin)
	DirAccess.remove_absolute(chemin)
	DirAccess.remove_absolute(chemin.get_basename() + ".mtl")
	_dire((resultat["erreurs"] as Array).is_empty(),
		"l'OBJ à UV se tranche avec %d erreur(s)" % (resultat["erreurs"] as Array).size())
	var lot: MeshLibrary = resultat["lot"]
	var items_sans_uv := 0
	var ecarts := 0
	var lus := 0
	for id in lot.get_item_list():
		var cle: String = lot.get_item_name(id)
		var mesh: Mesh = lot.get_item_mesh(id)
		for s_ in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(s_)
			if arrays[Mesh.ARRAY_TEX_UV] == null:
				items_sans_uv += 1
				continue
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var idx = arrays[Mesh.ARRAY_INDEX]
			var ordre: PackedInt32Array = (idx as PackedInt32Array) if idx != null else PackedInt32Array(range(v.size()))
			for t in range(0, ordre.size() - 2, 3):
				var geo: Vector3 = -(v[ordre[t + 1]] - v[ordre[t]]).cross(v[ordre[t + 2]] - v[ordre[t]])
				if geo.length_squared() < 1e-10:
					continue
				var axe := 0
				for j in 3:
					if absf(geo[j]) > absf(geo[axe]):
						axe = j
				var sens: int = axe * 2 + (0 if geo[axe] > 0.0 else 1)
				for k in 3:
					var q: Vector3 = v[ordre[t + k]]
					var point := "%d,%d,%d|%d" % [roundi(q.x * 1000.0), roundi(q.y * 1000.0), roundi(q.z * 1000.0), sens]
					if (par_cle.get(cle, {}) as Dictionary).has(point):
						lus += 1
						if not (par_cle[cle][point] as Vector2).is_equal_approx(uv[ordre[t + k]]):
							ecarts += 1
	_dire(items_sans_uv == 0, "%d surface(s) du lot sont revenues SANS UV" % items_sans_uv)
	_dire(lus > 1000 and ecarts == 0,
		"la tuile de chaque clé porte les UV de l'OBJ : %d coins comparés, %d écarts" % [lus, ecarts])
	print("  uv : %d vt, %d occurrences, %d clés, %d incohérent(s), %d partagé(s), %d recouvrement(s)"
		% [n_vt, occurrences.size(), par_cle.size(), incoherents, partages, recouvrements])


func _la_pose_du_noeud_est_lue() -> void:
	var boite := BoxMesh.new()
	var cube := ArrayMesh.new()
	cube.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, boite.get_mesh_arrays())
	var racine := Node3D.new()
	racine.name = "Racine"
	var porteur := MeshInstance3D.new()
	porteur.name = "Tourne"
	porteur.mesh = cube
	# Le cube de Godot est centré : on le pose d'abord sur [0, 1]³ par un parent, puis on tourne.
	var decale := Node3D.new()
	decale.name = "Decale"
	decale.position = Vector3(5, 0, 0)
	decale.rotation = Vector3(-PI / 2.0, 0, 0)
	porteur.position = Vector3(0.5, 0.5, 0.5)
	racine.add_child(decale)
	decale.add_child(porteur)
	var chemin: String = ProjectSettings.globalize_path("user://pose_test.glb")
	var doc := GLTFDocument.new()
	var etat := GLTFState.new()
	doc.append_from_scene(racine, etat)
	doc.write_to_filesystem(etat, chemin)
	racine.free()
	var relu: ArrayMesh = BlocsMaitres._lire_glb(chemin, [])
	DirAccess.remove_absolute(chemin)
	_dire(relu != null, "le cube tourné ne se relit pas")
	if relu == null:
		return
	var a := relu.get_aabb()
	var attendu := AABB(Vector3(5, 0, -1), Vector3.ONE)
	_dire(a.position.is_equal_approx(attendu.position) and a.size.is_equal_approx(attendu.size),
		"le nœud tourné est relu en %s, attendu %s — sa pose est ignorée" % [a, attendu])


func _le_temoin_livre_exactement_le_monde() -> void:
	var attendu := {}
	for c in MB.classes():
		var b: int = c["bits"]
		if not MB.porte_une_surface(b):
			continue
		var diagonal := false
		for f in MB.faces_de(b):
			if f["forme"] == "diagonale":
				diagonal = true
		if diagonal:
			continue
		attendu[c["nom"]] = true
		# Une variante d'air libre n'existe que si aucune case vide du bas n'est coiffée — recalculé
		# ici bit à bit, sans `exterieur_possible()`.
		var coiffee := false
		for t in MB.BAS:
			if (b & (1 << int(t))) == 0 and (b & (1 << (int(t) + 2))) != 0:
				coiffee = true
		if not coiffee:
			attendu[MB.nom_en_contexte(c["nom"], true)] = true
	_dire(attendu.size() == 52, "le monde sans diagonale demande %d tuiles, la charte en dit 52"
		% attendu.size())

	var resultat: Dictionary = BlocsMaitres.librairie()
	_dire((resultat["erreurs"] as Array).is_empty(), "librairie() rend %d erreur(s) de tranchage : %s"
		% [(resultat["erreurs"] as Array).size(), str((resultat["erreurs"] as Array).slice(0, 3))])
	_dire((resultat["manquantes"] as Array).is_empty(), "librairie() se déclare incomplète : %s"
		% str(resultat["manquantes"]))
	var lot: MeshLibrary = resultat["lot"]
	# ⚠ **UNE TUILE PAR CLÉ, DE NOM NU** (charte §3, 30 septembre 2026) : chaque item porte le nom d'une clé,
	# et aucune clé n'en porte deux. Du 27 au 30 septembre le lot portait des exemplaires « ~k ».
	var livre := {}
	var doublons: Array = []
	for id in lot.get_item_list():
		var nom: String = lot.get_item_name(id)
		if livre.has(nom):
			doublons.append(nom)
		livre[nom] = true
	var manque: Array = []
	for nom in attendu:
		if not livre.has(nom):
			manque.append(nom)
	var en_trop: Array = []
	for nom in livre:
		if not attendu.has(nom):
			en_trop.append(nom)
	_dire(manque.is_empty(), "%d tuile(s) du monde que librairie() ne livre pas : %s"
		% [manque.size(), str(manque.slice(0, 6))])
	_dire(doublons.is_empty() and lot.get_item_list().size() == attendu.size(),
		"une tuile par clé : %d item(s) pour %d clés, doublons %s" % [lot.get_item_list().size(), attendu.size(),
		str(doublons.slice(0, 4))])
	print("   %d clé(s), %d item(s)" % [livre.size(), lot.get_item_list().size()])

	_dire(en_trop.is_empty(), "%d tuile(s) livrées HORS du monde : %s"
		% [en_trop.size(), str(en_trop.slice(0, 6))])

	var diagonaux := 0
	var pleines: Dictionary = BlocsMaitres.cases(0)
	for x in BlocsMaitres.COTE - 1:
		for y in BlocsMaitres.COTE - 1:
			for z in BlocsMaitres.COTE - 1:
				var b: int = MB.bits(pleines, Vector3i(x, y, z))
				if MB.porte_une_surface(b) and not MB.sans_contact_diagonal(b):
					diagonaux += 1
	_dire(diagonaux == 0, "le témoin porte %d sommet(s) en contact diagonal" % diagonaux)
	print("  livraison : %d tuiles sur %d, %d contact(s) diagonal(aux)"
		% [livre.size() - en_trop.size(), attendu.size(), diagonaux])


func _le_cumul_est_croissant() -> void:
	var lignes: Array = BlocsMaitres.cumul()
	_dire(lignes.size() == BlocsMaitres.nombre(),
		"cumul() rend %d lignes pour %d blocs" % [lignes.size(), BlocsMaitres.nombre()])
	var avant := 0
	for l in lignes:
		_dire(l["cumul"] >= avant, "le cumul recule à « %s » : %d après %d"
			% [l["nom"], l["cumul"], avant])
		_dire(l["cumul"] == avant + l["neuves"],
			"« %s » : cumul %d ≠ %d + %d neuves" % [l["nom"], l["cumul"], avant, l["neuves"]])
		_dire(l["neuves"] <= l["classes"], "« %s » : %d neuves pour %d classes livrées"
			% [l["nom"], l["neuves"], l["classes"]])
		avant = l["cumul"]
	_dire(avant == MB.pieces_a_sculpter().size(),
		"le cumul final est %d, le modèle demande %d" % [avant, MB.pieces_a_sculpter().size()])


## ⚠ UNE CONSÉQUENCE DU MODÈLE, PAS UNE LECTURE DU MODULE : si l'on creuse une chambre dans un bloc,
## quelque chose la couvre, donc un sommet doit y voir un PLAFOND. Un bloc d'intérieur qui n'en
## présenterait aucun ne serait pas une grotte.
## ⚠ **`_une_salle_creuse_a_un_plafond()` A VÉCU ICI, ET SA LEÇON SURVIT À SA SUPPRESSION.** Il exigeait
## qu'un bloc déclaré INTÉRIEUR livre bien `mb_plaque_b0h4` — le plafond — et c'est lui qui avait trouvé
## que la première « salle de grotte », une coque creuse, n'en présentait aucun.
##
## ⚠ Il ne bouclait que sur les blocs de contexte INTÉRIEUR. Avec un témoin UNIQUE, son corps ne
## s'exécuterait plus jamais : il resterait **vert en ne gardant plus rien**, et un garde vide inspire
## une confiance qu'il ne mérite pas. Sa propriété est désormais couverte par
## `_la_couverture_est_complete`, qui exige les 68 classes — plafond compris.


## LES DEUX MAILLAGES, ET ILS N'ONT PAS LES MÊMES BORNES.
##
##   • le SOLIDE est la frontière des cellules pleines : il vit dans [0 ; COTE] ;
##   • la RÉCOLTE est faite de pièces qui s'étendent d'une demi-cellule autour de leur sommet, et les
##     sommets intérieurs siègent en sommet+(1,1,1) : elle vit dans [0,5 ; COTE−0,5].
##
## ⚠ **CES BORNES SONT LA RAISON D'ÊTRE DE CE CONTRÔLE.** Une orientation fausse ou une pièce non ramenée
## à sa référence déplace la matière sans changer son aire ni le nombre de pièces — aucun compteur ne le
## voit, une borne si.
## ⚠ Et la récolte est NORMALEMENT plus pauvre que le solide : un bloc ne livre que ce que ses sommets
## intérieurs voient. On vérifie donc qu'elle n'est pas vide, jamais qu'elle égale le solide.
func _les_maillages_existent_et_tiennent_dans_le_bloc() -> void:
	for i in BlocsMaitres.nombre():
		var nom: String = BlocsMaitres.BLOCS[i]["nom"]

		var solide: ArrayMesh = BlocsMaitres.maillage(i)
		_dire(solide.get_surface_count() > 0, "« %s » : le SOLIDE est vide" % nom)
		if solide.get_surface_count() > 0:
			_borne(solide.get_aabb(), 0.0, float(BlocsMaitres.COTE), "%s (solide)" % nom)

		var recolte: ArrayMesh = BlocsMaitres.maillage_des_pieces(i)
		_dire(recolte.get_surface_count() > 0, "« %s » : la RÉCOLTE est vide" % nom)
		if recolte.get_surface_count() > 0:
			_borne(recolte.get_aabb(), 0.5, float(BlocsMaitres.COTE) - 0.5, "%s (récolte)" % nom)


## LE CHANFREIN, QUI EST SUSPENDU — gardé quand même, parce qu'on y reviendra.
##
## ⚠ **IL N'EST PLUS LA GÉOMÉTRIE LIVRÉE.** Il l'a été une heure le 25 septembre 2026, puis Jordan l'a
## reposé : *« je voulais plus aucun angle et tu as fait des angles moins obtus. »* Ce contrôle ne garde
## donc plus ce qui part chez l'artiste — c'est `maillage_moitie` qui part — mais il garde que le
## lissage **reste juste** pendant sa mise en sommeil. Un code dormant que rien n'éprouve pourrit en
## silence, et on le retrouve cassé le jour où on en a besoin.
##
## ⚠ **CE QU'IL NE GARDE TOUJOURS PAS** : que `exporter_le_bloc()` appelle bien la géométrie voulue.
## Seul `essai_aller_retour.gd` le verrait, et il n'est pas dans les six suites.
func _la_geometrie_livree_est_saine() -> void:
	var cases: Dictionary = BlocsMaitres.cases(0)

	# ── le réglage reste dans le budget MESURÉ ──────────────────────────────────────────────────────
	# ⚠ Au-delà de 0,60 l'appariement en quads se dégrade (390 orphelins à 0,80, 528 à 1,00) et les
	# boucles d'arêtes que Jordan exige pour Blender avec. En deçà, le chanfrein ne coûte rien.
	var force: float = BlocsMaitres.FORCE_CHANFREIN
	_dire(force > 0.0 and force <= 0.6,
		"FORCE_CHANFREIN vaut %.2f — hors du budget mesuré ]0 ; 0,60]" % force)

	# ── le contrôle négatif du réglage ──────────────────────────────────────────────────────────────
	# ⚠ Le centre d'un cube dual tombe sur un coin du réseau, là où la coque à facettes pose ses
	# sommets : à force 0, le lissage DOIT rendre la coque à facettes, sans une seule pente. S'il en
	# rend, l'interpolation est fausse et TOUT ce qui est mesuré avec porte sur autre chose.
	var plat: ArrayMesh = BlocsMaitres.maillage_lisse(0, 0.5, 0.0)
	_dire(_obliques(plat) == 0,
		"à force 0 le lissage rend %d triangle(s) obliques — il devrait reproduire les facettes"
			% _obliques(plat))

	# ── et il chanfreine vraiment ───────────────────────────────────────────────────────────────────
	# ⚠ Sans cette assertion, remettre FORCE_CHANFREIN à 0 passerait tous les autres contrôles : une
	# géométrie qui ne chanfreine rien est parfaitement saine, elle ne fait simplement pas son travail.
	var livree: ArrayMesh = BlocsMaitres.maillage_lisse(0, 0.5, force)
	_dire(_obliques(livree) > 0, "la géométrie livrée n'a AUCUNE face oblique : elle ne chanfreine pas")

	# ── elle est fermée et soudée ───────────────────────────────────────────────────────────────────
	# ⚠ C'est la promesse du maillage dual — un quad par arête traversée, donc aucune place où un trou
	# puisse naître. Une promesse par construction se garde quand même : c'est la construction qu'on
	# peut casser.
	var soudee: ArrayMesh = BlocsMaitres.souder(livree)
	var bilan: Dictionary = Topo.bilan(soudee, cases)
	_dire(int(bilan["bords"]) == 0,
		"la géométrie livrée a %d arête(s) de BORD — donc des trous" % int(bilan["bords"]))
	_dire(int(bilan["doubles"]) == 0,
		"la géométrie livrée garde %d sommet(s) non soudés" % int(bilan["doubles"]))

	# ── et le trancheur y voit EXACTEMENT les mêmes classes que sur les facettes ────────────────────
	# ⚠ **C'EST LE CONTRAT DE COUTURE, et c'est le contrôle qui compte le plus ici.** Le chanfrein
	# déplace la surface près des plans de coupe ; s'il changeait ne serait-ce qu'une classe, les tuiles
	# ne se raccorderaient plus dans un monde peint — et aucun compteur de topologie ne le dirait.
	var avant: Array = _recolte(BlocsMaitres.maillage_moitie(0))
	var apres: Array = _recolte(livree)
	_dire(avant == apres,
		"la récolte change avec le chanfrein : %d classe(s) contre %d" % [apres.size(), avant.size()])


## Les triangles dont la normale géométrique n'est alignée sur aucun axe.
##
## ⚠ Normale GÉOMÉTRIQUE (produit vectoriel des sommets), jamais celle du tableau : souder impose une
## moyenne par sommet, et s'y fier a déjà coûté 23 erreurs d'octant dans ce projet.
func _obliques(mesh: ArrayMesh) -> int:
	if mesh == null or mesh.get_surface_count() == 0:
		return 0
	var arrays: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] \
		if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
	var combien := 0
	for t in range(0, idx.size() - 2, 3):
		var n: Vector3 = (v[idx[t + 1]] - v[idx[t]]).cross(v[idx[t + 2]] - v[idx[t]])
		if n.length_squared() < 0.000000001:
			continue
		n = n.normalized()
		var aligne := false
		for axe in 3:
			if absf(absf(n[axe]) - 1.0) < 0.001:
				aligne = true
		if not aligne:
			combien += 1
	return combien


## Les noms de classes que le trancheur tire d'un solide, triés — de quoi comparer deux géométries.
func _recolte(solide: ArrayMesh) -> Array:
	var fautes: Array = []
	var pieces: Dictionary = Tranchage.trancher(solide, Vector3i.ONE * BlocsMaitres.COTE, 1.0,
		BlocsMaitres.creuses(0), fautes, false)
	_dire(fautes.is_empty(), "le tranchage de la géométrie livrée rend %d faute(s)" % fautes.size())
	var noms: Array = pieces.keys()
	noms.sort()
	return noms


func _borne(boite: AABB, mini: float, maxi: float, quoi: String) -> void:
	var m := mini - 0.001
	var M := maxi + 0.001
	_dire(boite.position.x >= m and boite.position.y >= m and boite.position.z >= m,
		"%s : commence en %s, avant %.3f" % [quoi, str(boite.position), mini])
	var bout: Vector3 = boite.position + boite.size
	_dire(bout.x <= M and bout.y <= M and bout.z <= M,
		"%s : finit en %s, après %.3f" % [quoi, str(bout), maxi])


# ── la légende du témoin ────────────────────────────────────────────────────────────────────────────

## ⚠ **CE QUE CETTE VÉRIFICATION GARDE — LA LÉGENDE EST PAR FACE DEPUIS LE 27 SEPTEMBRE 2026.** Elle
## était par CASE (`case_sous_roche`) : une case de falaise ayant la falaise au-dessus d'elle était
## « souterraine », et le PBR espace monde a montré les falaises du monde peint RAYÉES. La règle est
## désormais `MB.face_sous_le_ciel()` : le VIDE que borde la face voit-il le ciel ? Trois propriétés :
##
##   1. **LA COULEUR DIT LE CRITÈRE, FACE PAR FACE.** ⚠ L'attendu est recalculé ICI, par un balayage
##      écrit à la main — appeler le module ferait bouger l'attendu ET le mesuré ensemble (charte §6).
##      Il est jugé sur la coque SANS retrait, où le vide bordé est exactement `case + direction` :
##      sur l'aminci, 12 % des faces bordent une autre case (`vide_borde`), et l'écrire ici en ferait
##      une seconde description.
##   2. **LA LÉGENDE SUIT LE BLOC.** Translater l'occupation translate le maillage et rien d'autre.
##      ⚠ La coque a déjà retrouvé ses cases par une DIVISION ENTIÈRE, qui tronque VERS ZÉRO en
##      GDScript : seul un bloc en coordonnées négatives pouvait le montrer.
##   3. **LES FALAISES NE SONT PLUS RAYÉES** — le symptôme lui-même, sur le vrai lot : la paroi à l'air
##      libre ne porte plus aucune couleur de grotte.
func _la_legende_du_temoin_dit_le_contexte() -> void:
	print("\n10. la légende du témoin : chaque FACE dit si le vide qu'elle borde voit le ciel")

	# Un relief écrit à la main :
	#
	#     y=3            #..        (0,3,0) seule : elle coiffe la colonne x = 0 par-dessus un trou
	#     y=2            ...        le trou
	#     y=1            ##.
	#     y=0            ###
	var pleines := {}
	for x in 3:
		pleines[Vector3i(x, 0, 0)] = true
	for x in 2:
		pleines[Vector3i(x, 1, 0)] = true
	pleines[Vector3i(0, 3, 0)] = true

	var nette: Dictionary = _verdicts_par_face(BlocsMaitres._coque_sous_voxels(pleines, 0.0), true)
	_dire(not nette.is_empty(), "la coque du relief d'essai ne rend aucun quad")
	var faux := 0
	for cle in nette:
		if nette[cle]["sombre"] != _souterraine_a_la_main(pleines, cle[0], cle[1]):
			faux += 1
	_dire(faux == 0, "%d face(s) peintes à l'envers de ce que le critère dit" % faux)
	# ⚠ LES ASSERTIONS QU'UN HUMAIN LIT — dont celle qui a changé avec la règle.
	var ouest := [Vector3i(0, 1, 0), Vector3i(-1, 0, 0)]
	var sol := [Vector3i(0, 1, 0), Vector3i(0, 1, 0)]
	_dire(nette.has(ouest) and not nette[ouest]["sombre"],
		"(0,1,0) est coiffée par (0,3,0), mais sa paroi OUEST borde un vide à ciel ouvert : FALAISE")
	_dire(nette.has(sol) and nette[sol]["sombre"],
		"le dessus de (0,1,0) donne sur le trou, coiffé par (0,3,0) : c'est un sol de GROTTE")
	var dessous := [Vector3i(0, 3, 0), Vector3i(0, -1, 0)]
	_dire(nette.has(dessous) and not nette[dessous]["sombre"],
		"le dessous de (0,3,0) n'a rien au-dessus de sa dalle : dessous de surplomb, à l'air libre")

	# ⚠ ET LE SCÉNARIO QUI A TROUVÉ LA DIVISION ENTIÈRE : le MÊME relief, aminci, en coordonnées négatives.
	var a_l_origine: Dictionary = _verdicts_par_face(BlocsMaitres._coque_sous_voxels(pleines, 0.25), false)
	var sombres := 0
	for cle in a_l_origine:
		sombres += a_l_origine[cle]["sombres"]
	_dire(sombres > 0, "aucun quad souterrain : la légende ne dit plus rien")
	for decalage in [Vector3i(-8, 0, 0), Vector3i(-3, 0, -5), Vector3i(0, -4, 0)]:
		var deplace := {}
		for c in pleines:
			deplace[Vector3i(c) + decalage] = true
		var la_bas: Dictionary = _verdicts_par_face(BlocsMaitres._coque_sous_voxels(deplace, 0.25), false)
		var divergentes := 0
		for cle in a_l_origine:
			var ailleurs = la_bas.get([Vector3i(cle[0]) + decalage, cle[1]], null)
			if ailleurs == null or ailleurs["sombres"] != a_l_origine[cle]["sombres"] \
					or ailleurs["quads"] != a_l_origine[cle]["quads"]:
				divergentes += 1
		_dire(la_bas.size() == a_l_origine.size() and divergentes == 0,
			"translaté de %s : %d face(s) changent de légende" % [str(decalage), divergentes])

	# ⚠ LE SYMPTÔME, sur le vrai lot : `mb_plaque_b2h2_dehors` portait 135 couleurs de falaise et 135
	# de grotte. Une paroi posée à l'air libre ne doit plus porter une seule couleur de grotte.
	var lot: MeshLibrary = BlocsMaitres.librairie()["lot"]
	var id: int = lot.find_item_by_name("mb_plaque_b2h2_dehors")
	_dire(id >= 0, "le lot ne livre plus mb_plaque_b2h2_dehors")
	if id >= 0:
		var grotte := 0
		var total := 0
		for c in lot.get_item_mesh(id).surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
			total += 1
			if Color(c).is_equal_approx(RP.COULEUR_PAROI_DEDANS):
				grotte += 1
		_dire(grotte == 0, ("la paroi À L'AIR LIBRE porte %d sommet(s) de paroi de GROTTE sur %d — "
			+ "les falaises du monde peint seront rayées") % [grotte, total])
	print("   → %d faces jugées une à une, la légende suit le bloc, et la falaise est d'une seule teinte"
		% nette.size())


## LE BALAYAGE, RÉÉCRIT ICI EXPRÈS — voir le ⚠ ci-dessus. Il ne borne rien par un plafond : il regarde
## toute la colonne, ce qui rend le même verdict et ne partage pas une ligne avec le module.
## Un PLAFOND demande si SA dalle est sous la roche ; une paroi ou un sol, si le VIDE d'en face l'est.
func _souterraine_a_la_main(pleines: Dictionary, case: Vector3i, direction: Vector3i) -> bool:
	var colonne: Vector3i = case if direction.y < 0 else case + direction
	var haut := colonne.y
	for c in pleines:
		haut = maxi(haut, Vector3i(c).y)
	for y in range(colonne.y + 1, haut + 1):
		if pleines.has(Vector3i(colonne.x, y, colonne.z)):
			return true
	return false


## Pour chaque FACE du relief — [case, direction] —, ce que la coque a peint :
## {[case, direction]: {sombre, sombres, quads}}.
##
## ⚠ **LA CASE D'UN QUAD EST RETROUVÉE PAR SA GÉOMÉTRIE, JAMAIS PAR LA DIVISION DU MODULE** : on recule
## d'un cheveu le long de la normale pour rentrer dans la matière, puis on prend le plancher.
## ⚠ `unique` exige qu'une face ne porte qu'une couleur — vrai sans retrait, où une face borde un seul
## vide ; FAUX sur l'aminci, où une bande de marche peut border une autre case que le reste de la face.
func _verdicts_par_face(mesh: ArrayMesh, unique: bool) -> Dictionary:
	var par_face := {}
	if mesh.get_surface_count() == 0:
		return par_face
	var tout: Array = mesh.surface_get_arrays(0)
	var sommets: PackedVector3Array = tout[Mesh.ARRAY_VERTEX]
	var normales: PackedVector3Array = tout[Mesh.ARRAY_NORMAL]
	var couleurs: PackedColorArray = tout[Mesh.ARRAY_COLOR]
	var claires := [RP.COULEUR_DESSUS, RP.COULEUR_PAROI, RP.COULEUR_PLAFOND]
	var partagees := {}
	var i := 0
	while i < sommets.size():
		var centre: Vector3 = (sommets[i] + sommets[i + 1] + sommets[i + 2]
			+ sommets[i + 3] + sommets[i + 4] + sommets[i + 5]) / 6.0
		var dedans: Vector3 = centre - normales[i] * 0.01
		var case := Vector3i(floori(dedans.x), floori(dedans.y), floori(dedans.z))
		var direction := Vector3i(roundi(normales[i].x), roundi(normales[i].y), roundi(normales[i].z))
		var sombre := true
		for base in claires:
			if couleurs[i].is_equal_approx(base):
				sombre = false
		var cle := [case, direction]
		if par_face.has(cle):
			if par_face[cle]["sombre"] != sombre:
				partagees[cle] = true
			par_face[cle]["quads"] += 1
			par_face[cle]["sombres"] += 1 if sombre else 0
		else:
			par_face[cle] = {"sombre": sombre, "sombres": 1 if sombre else 0, "quads": 1}
		i += 6
	# ⚠ UNE SEULE vérification, pas une par quad : un compteur que 8 000 quads gonflent ne dit plus
	# rien de ce qui est gardé.
	if unique:
		_dire(partagees.is_empty(),
			"%d face(s) portent DEUX légendes à la fois : %s" % [partagees.size(), str(partagees.keys())])
	return par_face


# ── 14. une tuile par clé : celle du sommet le plus PUR ──────────────────────────────────────────
#
# ⚠ **DÉCIDÉ (Jordan, 30 septembre 2026, charte §3)** : une clé livre UNE tuile. Du 27 au 30 septembre le
# trancheur gardait tous les sommets d'une clé comme « exemplaires », et le peintre en tirait un par
# position — une falaise droite devenait une mosaïque de 30 morceaux. Il ne garde plus que le sommet le
# plus PUR (celui dont les 64 cases voisines s'écartent le moins de sa configuration prolongée), à égalité
# le premier du balayage (x, puis y, puis z).
# ⚠ **L'ATTENDU EST RECALCULÉ ICI, SANS `MB.purete` NI LE TRANCHEUR** (charte §6) : la pureté y est écrite
# autrement — chaque case voisine comparée à la case du cœur qu'elle PROLONGE, trouvée par min/max.
# ⚠ Et la section vérifie qu'elle ÉPROUVE le choix : il faut des clés où le plus pur n'est PAS le premier
# du balayage, sinon « prendre le premier » passerait pour juste.

func _une_tuile_par_cle() -> void:
	print("\n14. une tuile par clé — celle du sommet le plus pur")
	var pleines: Dictionary = BlocsMaitres.cases(0)
	var attendu := {}          # clé → sommet attendu
	var meilleure := {}        # clé → pureté
	var premier := {}          # clé → premier sommet du balayage
	var sommets_par_cle := {}
	var plafond: int = MB.plafond_de(pleines)
	for vx in range(0, BlocsMaitres.COTE - 1):
		for vy in range(0, BlocsMaitres.COTE - 1):
			for vz in range(0, BlocsMaitres.COTE - 1):
				var v := Vector3i(vx, vy, vz)
				var r: Dictionary = Tranchage.cle_du_sommet(pleines, v, plafond)
				if r.is_empty():
					continue
				var cle: String = r["cle"]
				sommets_par_cle[cle] = int(sommets_par_cle.get(cle, 0)) + 1
				if not premier.has(cle):
					premier[cle] = v
				var p := _purete_a_la_main(pleines, v)
				if not meilleure.has(cle) or p < int(meilleure[cle]):
					meilleure[cle] = p
					attendu[cle] = v
	var lot: MeshLibrary = BlocsMaitres.librairie()["lot"]
	var sommets: Dictionary = lot.get_meta(BlocsMaitres.META_SOMMETS, {})
	var faux: Array = []
	for cle in attendu:
		if not sommets.has(cle) or sommets[cle] != attendu[cle]:
			faux.append("%s : %s au lieu de %s" % [cle, sommets.get(cle, "rien"), attendu[cle]])
	_dire(faux.is_empty() and sommets.size() == attendu.size(),
		"chaque tuile vient du sommet le plus pur de sa clé (%d / %d) : %s"
		% [attendu.size() - faux.size(), attendu.size(), str(faux.slice(0, 4))])
	var repetees := 0
	var pas_le_premier := 0
	for cle in attendu:
		if int(sommets_par_cle[cle]) > 1:
			repetees += 1
		if attendu[cle] != premier[cle]:
			pas_le_premier += 1
	_dire(repetees > 10 and pas_le_premier > 5,
		"le choix est éprouvé : %d clés répétées, %d où le plus pur n'est pas le premier du balayage"
		% [repetees, pas_le_premier])
	# Et la tuile du témoin lié est la même : `tuiles_du_temoin` rend ce que le trancheur a choisi.
	var tt: Dictionary = BlocsMaitres.tuiles_du_temoin()
	var memes := 0
	for cle in tt:
		if sommets.get(cle) == tt[cle]["sommet"]:
			memes += 1
	_dire(memes == attendu.size(), "tuiles_du_temoin rend les mêmes sommets que le lot (%d / %d)"
		% [memes, attendu.size()])
	print("   → %d clés, %d répétées, %d où le plus pur n'est pas le premier" % [attendu.size(), repetees,
		pas_le_premier])


## La pureté, écrite AUTREMENT que `MB.purete` : pour chaque case des 4³ autour du sommet, la case du cœur
## qu'elle prolonge est obtenue par min/max, et l'on compte les désaccords.
func _purete_a_la_main(pleines: Dictionary, v: Vector3i) -> int:
	var n := 0
	for x in range(v.x - 1, v.x + 3):
		for y in range(v.y - 1, v.y + 3):
			for z in range(v.z - 1, v.z + 3):
				var coeur := Vector3i(mini(maxi(x, v.x), v.x + 1), mini(maxi(y, v.y), v.y + 1),
					mini(maxi(z, v.z), v.z + 1))
				if pleines.has(Vector3i(x, y, z)) != pleines.has(coeur):
					n += 1
	return n


## §16 — LE TÉMOIN LIÉ PROUVE TOUS LES RACCORDS (charte §3, une tuile par clé, 30 septembre 2026).
##
## Chaque seau de `verifier_sections` doit être relié d'un seul tenant par les joints du témoin : alors
## un témoin étanche rend TOUT monde étanche.
## ⚠ **L'ATTENDU NÉGATIF VIENT D'AILLEURS** : le témoin d'avant les raccords (on ôte les cinq cases que
## `planete_paysage.gd` a posées) a été mesuré par `DEV_TOOLS/sonde_raccords_lies.gd`, écrite À PART du
## cœur — 36 seaux, 23 reliés, 14 morceaux en trop, sur sept clés rares. Le cœur doit le retrouver au
## chiffre près : une règle plus laxiste (un quart de tour transféré sans condition) ou plus stricte
## (aucun quart de tour) le déplace, et ce test rougit.
const _CASES_DES_RACCORDS := [Vector3i(1, 4, 5), Vector3i(2, 4, 5), Vector3i(1, 4, 6), Vector3i(1, 5, 6),
	Vector3i(6, 8, 3)]
const _CLES_A_PART_AVANT := ["mb_equerre_creuse_b3h2_a_dehors", "mb_pointe_creuse_b3h3", "mb_tetra_b1h3",
	"mb_tetra_b3h1", "mb_vrille_d_b3h1", "mb_vrille_d_b3h1_dehors", "mb_vrille_g_b1h3"]

func _le_temoin_prouve_tous_les_raccords() -> void:
	var t: Dictionary = BlocsMaitres.cases(0)
	var r: Dictionary = Tranchage.raccords_du_temoin(t)
	_dire(r["seaux"] == 36, "§16 le témoin porte 36 seaux de faces (rend %d)" % r["seaux"])
	_dire(r["en_trop"] == 0 and r["relies"] == r["seaux"],
		"§16 chaque seau est relié d'un seul tenant (%d sur %d, morceaux à part : %s)"
		% [r["relies"], r["seaux"], r["morceaux"]])

	var avant: Dictionary = t.duplicate()
	for c in _CASES_DES_RACCORDS:
		_dire(avant.has(c), "§16 la case de raccord %s est dans le témoin" % c)
		avant.erase(c)
	var ra: Dictionary = Tranchage.raccords_du_temoin(avant)
	_dire(ra["seaux"] == 36 and ra["relies"] == 23 and ra["en_trop"] == 14,
		"§16 sans les raccords : 36 seaux, 23 reliés, 14 en trop, comme la sonde (rend %d, %d, %d)"
		% [ra["seaux"], ra["relies"], ra["en_trop"]])
	var cles := {}
	for m in (ra["morceaux"] as Array):
		for n in (m["noeuds"] as Array):
			cles[String(n).split("|")[0]] = true
	var vues: Array = cles.keys()
	vues.sort()
	_dire(vues == _CLES_A_PART_AVANT, "§16 sans les raccords, les faces à part sont celles des sept clés rares (%s)" % [vues])

	# Une seule case ne relie aucun seau : chaque seau réunit des faces de clés qu'elle ne montre pas.
	var seule: Dictionary = Tranchage.raccords_du_temoin({Vector3i.ZERO: true})
	_dire(seule["relies"] == 0 and seule["seaux"] == 36, "§16 une case seule ne relie aucun seau (rend %d)" % seule["relies"])


## §17 — LE TÉMOIN LIÉ FAIT L'ALLER-RETOUR (charte §3, une tuile par clé, 30 septembre 2026).
##
## ⚠ **LES ATTENDUS NE PASSENT PAS PAR LES FONCTIONS ÉPROUVÉES** : le nombre d'occurrences est recompté
## sommet par sommet par `MB.porte_une_surface` (et non par `occurrences_du_temoin`) ; le nombre de tuiles
## vient des listes du MODÈLE (35 + 17) ; le partage se lit dans le JSON du fichier, la clé de chaque nœud
## étant redéduite de SA translation. Les fichiers fautifs sont bâtis ici, en retouchant l'état glTF.
func _le_temoin_lie_fait_l_aller_retour() -> void:
	var dossier := ProjectSettings.globalize_path("user://test_temoin_lie")
	DirAccess.make_dir_recursive_absolute(dossier)
	var chemin := dossier.path_join("temoin_lie.glb")
	var raison: String = BlocsMaitres.exporter_le_temoin_lie(chemin)
	_dire(raison == "", "§17 l'export du témoin lié réussit (« %s »)" % raison)

	var t: Dictionary = BlocsMaitres.cases(0)
	var sommets := {}
	for c in t:
		for s in MB.sommets_de(c):
			sommets[s] = true
	var a_surface := 0
	for s in sommets:
		if MB.porte_une_surface(MB.bits(t, s)):
			a_surface += 1
	var tuiles_du_monde: int = MB.pieces_a_sculpter().size() + MB.exterieures_a_sculpter().size()

	var json: Dictionary = _json_du_glb(chemin)
	var noeuds: Array = json.get("nodes", [])
	var plafond: int = MB.plafond_de(t)
	var maillage_de_cle := {}
	var porteurs := 0
	var partage_juste := true
	for nd in noeuds:
		if not nd.has("mesh"):
			continue
		porteurs += 1
		var tr: Array = nd.get("translation", [0, 0, 0])
		var sommet := Vector3i(roundi(tr[0]) - 1, roundi(tr[1]) - 1, roundi(tr[2]) - 1)
		var cle: String = Tranchage.cle_du_sommet(t, sommet, plafond).get("cle", "?")
		if maillage_de_cle.has(cle) and maillage_de_cle[cle] != int(nd["mesh"]):
			partage_juste = false
		maillage_de_cle[cle] = int(nd["mesh"])
	_dire(porteurs == a_surface, "§17 une occurrence par sommet à surface, bords compris (%d pour %d)" % [porteurs, a_surface])
	_dire((json.get("meshes", []) as Array).size() == tuiles_du_monde,
		"§17 un maillage par tuile du monde (%d pour %d)" % [(json.get("meshes", []) as Array).size(), tuiles_du_monde])
	var distincts := {}
	for cle in maillage_de_cle:
		distincts[maillage_de_cle[cle]] = true
	_dire(partage_juste and distincts.size() == maillage_de_cle.size() and not maillage_de_cle.has("?"),
		"§17 toutes les occurrences d'une clé (redéduite de leur place) partagent UN maillage, à elle seule")

	# ── Relu tel quel : les tuiles qui sont parties.
	var parties: Dictionary = BlocsMaitres.tuiles_du_temoin()
	var b: Dictionary = BlocsMaitres.librairie_depuis_glb(chemin)
	_dire(b.get("lie", false) and b["erreurs"].is_empty() and b["remarques"].is_empty(),
		"§17 relu comme témoin lié, sans erreur ni remarque (%s / %s)" % [b["erreurs"], b["remarques"]])
	var lot: MeshLibrary = b["lot"]
	var identiques := 0
	for id in lot.get_item_list():
		var nom: String = lot.get_item_name(id)
		if parties.has(nom) and BlocsMaitres._empreinte_de_forme(lot.get_item_mesh(id)) \
				== BlocsMaitres._empreinte_de_forme(parties[nom]["mesh"]):
			identiques += 1
	_dire(lot.get_item_list().size() == tuiles_du_monde and identiques == tuiles_du_monde,
		"§17 relu : %d tuiles, dont %d identiques à celles parties (attendu %d)" % [lot.get_item_list().size(), identiques, tuiles_du_monde])

	# ── Ce que l'écran AFFICHE (`travail_depuis_glb`) porte toutes les occurrences, triangle pour triangle.
	# ⚠ Vu en menant l'appli : une surface par objet dépassait le plafond de 256 surfaces de Godot, et
	# l'affichage perdait l'essentiel du témoin lié.
	var attendus := 0
	for nd in noeuds:
		if not nd.has("mesh"):
			continue
		var tr2: Array = nd.get("translation", [0, 0, 0])
		var s2 := Vector3i(roundi(tr2[0]) - 1, roundi(tr2[1]) - 1, roundi(tr2[2]) - 1)
		var id2: int = lot.find_item_by_name(Tranchage.cle_du_sommet(t, s2, plafond).get("cle", ""))
		if id2 >= 0:
			attendus += _triangles(lot.get_item_mesh(id2))
	var affiche: ArrayMesh = BlocsMaitres.travail_depuis_glb(chemin)
	_dire(affiche != null and affiche.get_surface_count() <= 256 and _triangles(affiche) == attendus,
		"§17 l'écran affiche toutes les occurrences : %d triangles pour %d" % [_triangles(affiche) if affiche else -1, attendus])

	# ── Des copies DÉLIÉES mais identiques (Make Single User) : une seule tuile, aucune erreur.
	var delie := dossier.path_join("delie.glb")
	_retoucher_le_glb(chemin, delie, func(etat: GLTFState) -> void:
		var anciens: Array = etat.get_meshes()
		var nouveaux: Array[GLTFMesh] = []
		for nd: GLTFNode in etat.get_nodes():
			if nd.mesh < 0:
				continue
			var copie := GLTFMesh.new()
			copie.mesh = (anciens[nd.mesh] as GLTFMesh).mesh
			nd.mesh = nouveaux.size()
			nouveaux.append(copie)
		etat.set_meshes(nouveaux))
	_dire((_json_du_glb(delie).get("meshes", []) as Array).size() == porteurs, "§17 le fichier délié porte un maillage par occurrence")
	var bd: Dictionary = BlocsMaitres.librairie_depuis_glb(delie)
	_dire(bd.get("lie", false) and bd["erreurs"].is_empty() and (bd["lot"] as MeshLibrary).get_item_list().size() == tuiles_du_monde,
		"§17 délié mais identique : %d tuiles, erreurs %s" % [(bd["lot"] as MeshLibrary).get_item_list().size(), bd["erreurs"]])

	# ── UNE copie sculptée seule : une erreur qui nomme la clé, et la tuile du plus grand nombre gardée.
	var cle_paroi := "mb_plaque_b2h2_dehors"
	var seule := dossier.path_join("sculptee_seule.glb")
	_retoucher_le_glb(chemin, seule, func(etat: GLTFState) -> void:
		var nd: GLTFNode = _premier_noeud_de(etat, t, cle_paroi)
		var source: ArrayMesh = BlocsMaitres._en_array_mesh((etat.get_meshes()[nd.mesh] as GLTFMesh).mesh)
		var im := ImporterMesh.new()
		for s in source.get_surface_count():
			var arrays: Array = source.surface_get_arrays(s)
			if s == 0:
				var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				v[0] += Vector3(0.0, 0.0, 0.2)
				arrays[Mesh.ARRAY_VERTEX] = v
			im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, source.surface_get_material(s))
		var gm := GLTFMesh.new()
		gm.mesh = im
		var liste: Array[GLTFMesh] = []
		liste.assign(etat.get_meshes())
		liste.append(gm)
		etat.set_meshes(liste)
		nd.mesh = liste.size() - 1)
	var bs: Dictionary = BlocsMaitres.librairie_depuis_glb(seule)
	var nomme := false
	for e in bs["erreurs"]:
		if String(e).contains(cle_paroi):
			nomme = true
	_dire(bs["erreurs"].size() == 1 and nomme, "§17 une copie sculptée seule est une erreur qui nomme sa clé (%s)" % [bs["erreurs"]])
	var gardee: int = (bs["lot"] as MeshLibrary).find_item_by_name(cle_paroi)
	_dire(gardee >= 0 and BlocsMaitres._empreinte_de_forme((bs["lot"] as MeshLibrary).get_item_mesh(gardee))
		== BlocsMaitres._empreinte_de_forme(parties[cle_paroi]["mesh"]), "§17 et la tuile gardée est celle du plus grand nombre")

	# ── UNE copie tournée d'un quart de tour : même verdict.
	var tournee := dossier.path_join("tournee.glb")
	_retoucher_le_glb(chemin, tournee, func(etat: GLTFState) -> void:
		var nd: GLTFNode = _premier_noeud_de(etat, t, cle_paroi)
		nd.xform = Transform3D(Basis(Vector3.UP, PI / 2.0) * nd.xform.basis, nd.xform.origin))
	var bt: Dictionary = BlocsMaitres.librairie_depuis_glb(tournee)
	_dire(bt["erreurs"].size() == 1 and String(bt["erreurs"][0]).contains(cle_paroi),
		"§17 une copie tournée est une erreur qui nomme sa clé (%s)" % [bt["erreurs"]])

	# ── Un objet hors de toute place : ignoré, et DIT.
	var hors := dossier.path_join("hors.glb")
	_retoucher_le_glb(chemin, hors, func(etat: GLTFState) -> void:
		var nd: GLTFNode = _premier_noeud_de(etat, t, cle_paroi)
		var rocher := GLTFNode.new()
		rocher.resource_name = "rock"
		rocher.mesh = nd.mesh
		rocher.parent = nd.parent
		rocher.xform = Transform3D(Basis(), Vector3(5.3, 9.1, 5.7))
		var liste: Array[GLTFNode] = []
		liste.assign(etat.get_nodes())
		liste.append(rocher)
		etat.set_nodes(liste)
		if rocher.parent >= 0:
			var parent: GLTFNode = liste[rocher.parent]
			var enfants: PackedInt32Array = parent.children
			enfants.append(liste.size() - 1)
			parent.children = enfants
		else:
			var racines: PackedInt32Array = etat.root_nodes
			racines.append(liste.size() - 1)
			etat.root_nodes = racines)
	var bh: Dictionary = BlocsMaitres.librairie_depuis_glb(hors)
	_dire(bh.get("lie", false) and bh["erreurs"].is_empty() and bh["remarques"].size() == 1
		and String(bh["remarques"][0]).begins_with("objets : 1 "),
		"§17 un objet hors place est ignoré et signalé (%s / %s)" % [bh["erreurs"], bh["remarques"]])

	# ── Un travail NON lié (un seul objet, le bloc à l'origine) n'est pas pris pour un témoin lié.
	var bloc := dossier.path_join("bloc.glb")
	BlocsMaitres.exporter_le_bloc(bloc)
	_dire(BlocsMaitres.tuiles_liees(bloc, [], []).is_empty(), "§17 un bloc d'un seul tenant n'est pas un témoin lié")


func _json_du_glb(chemin: String) -> Dictionary:
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		return {}
	f.seek(12)
	var longueur := f.get_32()
	f.get_32()
	return JSON.parse_string(f.get_buffer(longueur).get_string_from_utf8())


func _retoucher_le_glb(source: String, cible: String, retouche: Callable) -> void:
	var document := GLTFDocument.new()
	var etat := GLTFState.new()
	document.append_from_file(source, etat)
	retouche.call(etat)
	document.write_to_filesystem(etat, cible)


## Le premier nœud (dans l'ordre du fichier) posé sur un sommet de la clé `cle` — redéduite de sa place.
func _premier_noeud_de(etat: GLTFState, t: Dictionary, cle: String) -> GLTFNode:
	var plafond: int = MB.plafond_de(t)
	for nd: GLTFNode in etat.get_nodes():
		if nd.mesh < 0:
			continue
		var sommet := Vector3i((nd.xform.origin - Vector3.ONE).round())
		if Tranchage.cle_du_sommet(t, sommet, plafond).get("cle", "") == cle:
			return nd
	return null


func _triangles(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var a: Array = mesh.surface_get_arrays(s)
		n += ((a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() if a[Mesh.ARRAY_INDEX] != null
			else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n
