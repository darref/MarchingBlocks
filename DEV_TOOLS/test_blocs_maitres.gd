extends SceneTree
##
## TEST — les neuf blocs maîtres (étape 7).
##
## LANCEMENT
##   godot --headless --path D:/UnderMend --script res://DEV_TOOLS/test_blocs_maitres.gd
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

const MB := preload("res://addons/undermend/marching_blocks.gd")
const BlocsMaitres := preload("res://addons/undermend/blocs_maitres.gd")
const Tranchage := preload("res://addons/undermend/tranchage.gd")
## ⚠ On EMPRUNTE le bilan topologique plutôt que d'en recopier le calcul : deux descriptions d'un même
## fait divergent toujours, et celle-ci porte déjà deux pièges payés cher (charte §6).
const Topo := preload("res://DEV_TOOLS/topologie.gd")

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
	_le_cumul_est_croissant()
	_les_maillages_existent_et_tiennent_dans_le_bloc()
	_la_geometrie_livree_est_saine()

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
	var total: int = MB.pieces_a_sculpter().size()
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
	print("  contexte : %d à l'air libre possible, %d intérieures seulement → %d tuiles à sculpter"
		% [dehors.size(), total - dehors.size(), total + dehors.size()])


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
