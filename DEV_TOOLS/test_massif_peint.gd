extends SceneTree
##
## TEST — la partie PEINTURE : on peint des cases, le greffon pose les pièces.
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_massif_peint.gd
##
## ⚠ CE QUE CE TEST GARDE, ET POURQUOI :
##
##   • **l'invariant du greffon** — peindre n'importe quelle forme ne produit JAMAIS une faute. Ce n'est
##     plus une promesse : le classificateur répond aux 256 configurations, et le repli procédural
##     fournit les 68 classes de surface. Zéro faute, sur toutes les formes, y compris les tordues ;
##   • **le décalage d'une demi-case sur les TROIS axes**, et son SIGNE. L'ancien modèle portait
##     `(-0,5 ; 0 ; -0,5)` ; le nouveau vaut `+0,5` partout. Un signe tenu de mémoire aurait déporté
##     tout le rendu d'une case entière — invisible sur un sol plat, catastrophique sur une falaise ;
##   • **une case touche HUIT sommets**, pas quatre. La moitié du voisinage manquait dans l'ancien
##     modèle, par construction ;
##   • **la règle du ventre creux** : les sommets entourés de huit cellules pleines ne posent rien, et
##     c'est compté à part des fautes — une économie ne doit pas se lire comme une panne.
##
## ⚠ `_ready()` N'A PAS TOURNÉ pendant `_initialize()` d'un test lancé par `--script` : la boucle
## principale n'a pas commencé. On appelle donc `preparer()` et `reconstruire()` à la main, ce que
## l'API rend possible exprès.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const RP := preload("res://addons/marchingblocks_core/repli_procedural.gd")
## ⚠ CHARGÉ PAR CHEMIN, jamais par `class_name` : un nom de classe tout neuf n'entre dans le cache
## global de l'éditeur qu'après régénération, et un test en `--script` tourne avant.
const Peint := preload("res://addons/marchingblocks_core/massif_peint.gd")

var _ok := 0
var _echecs := 0
var _premier := ""


func _initialize() -> void:
	print("=== TEST — la partie peinture ===\n")
	_les_trois_grilles_existent()
	_le_decalage_est_d_une_demi_case_partout()
	_une_case_seule_pose_huit_pieces()
	_aucune_forme_ne_produit_de_faute()
	_le_ventre_est_creux()
	_ce_qui_est_pose_est_ce_que_les_regles_disent()
	_effacer_efface()
	_l_empreinte_suit_les_cases()
	_le_contexte_choisit_la_variante()
	_le_peintre_tire_un_exemplaire_par_position()

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


# ── 9. LE CONTEXTE CHOISIT LA VARIANTE ──────────────────────────────────────────────────────────────

## ⚠ **SANS CE CONTRÔLE, LA RÉCOLTE À DEUX CONTEXTES EST NON GARDÉE.** Les huit contrôles ci-dessus
## passent tous par le repli procédural, qui ne porte AUCUNE variante : ils n'éprouvent donc que le
## chemin de repli, et resteraient verts même si le choix du contexte était entièrement cassé. Un vert
## qui ne garde rien est pire qu'une absence de test, parce qu'il rassure (charte §6).
##
## ⚠ **ET IL ÉPROUVE LA MÊME CLASSE DANS LES DEUX CONTEXTES.** Montrer qu'une variante est posée quelque
## part ne prouverait rien : il faut que `mb_plaque_b4h0` sorte en VARIANTE sous le ciel et en NOM NU
## sous un couvercle — même classe, même orientation, deux tuiles différentes. C'est exactement la
## distinction pour laquelle le modèle orienté a été choisi.
func _le_contexte_choisit_la_variante() -> void:
	print("\n9. le contexte choisit la variante d'air libre")

	# Un lot qui PORTE une variante : le repli, plus « mb_plaque_b4h0_dehors ».
	# ⚠ On réemploie le mesh du repli : ce contrôle porte sur le CHOIX du nom, pas sur la géométrie.
	var lot: MeshLibrary = RP.librairie()
	var id_sol: int = lot.find_item_by_name("mb_plaque_b4h0")
	_dire(id_sol >= 0, "le repli devrait contenir « mb_plaque_b4h0 »")
	if id_sol < 0:
		return
	var neuf: int = 1000
	lot.create_item(neuf)
	lot.set_item_name(neuf, MB.nom_en_contexte("mb_plaque_b4h0", true))
	lot.set_item_mesh(neuf, lot.get_item_mesh(id_sol))

	# Un plateau 4×1×4 en y = 0, et un COUVERCLE au-dessus de sa moitié z ≤ 1, trois étages plus haut.
	# ⚠ Le couvercle est LOIN (y = 3) exprès : il ne doit pas changer les huit cellules du sommet, donc
	# pas la CLASSE — seulement le contexte. Un couvercle collé changerait les bits et prouverait autre
	# chose que ce qu'on cherche.
	var m := _massif()
	m.lot = lot
	var cellules: Array = _pave(0, 5, 0, 0, 0, 5) + _pave(0, 5, 3, 3, 0, 2)
	_peindre(m, cellules)
	var bilan: Dictionary = m.reconstruire()
	_dire(bilan["fautes"] == 0, "ce monde ne doit produire aucune faute, il en produit %d"
		% bilan["fautes"])
	_dire(int(bilan.get("dehors", -1)) > 0,
		"des variantes devraient être posées, le bilan en compte %s" % str(bilan.get("dehors", "absent")))

	var pleines := {}
	for c in cellules:
		pleines[c] = true
	var rendu: GridMap = m.get_node("Rendu")

	# ⚠ **L'ATTENDU EST CALCULÉ À LA MAIN, SANS APPELER `MB.sous_le_ciel` — ET C'EST TOUTE LA
	# CORRECTION.** La première version de ce contrôle employait la fonction qu'elle prétendait
	# éprouver : muter cette fonction déplaçait l'attendu ET le mesuré ensemble, et la mutation restait
	# MUETTE. Un test dont l'attendu vient de la fonction testée se compare à lui-même et ne garde rien.
	var haut := -999
	for c in cellules:
		haut = maxi(haut, (c as Vector3i).y)

	var sous_ciel_nu := 0
	var sous_roche_suffixe := 0
	var vus_dehors := 0
	var vus_dedans := 0
	for c in rendu.get_used_cells():
		var sommet: Vector3i = c
		var nom: String = rendu.mesh_library.get_item_name(rendu.get_cell_item(sommet))
		if MB.nom_nu(nom) != "mb_plaque_b4h0":
			continue
		# La règle, réécrite ici : le sommet est sous le ciel si AUCUNE de ses huit cellules n'a de
		# roche au-dessus d'elle, jusqu'au plus haut y peint.
		var attendu_dehors := true
		for t in 8:
			var base: Vector3i = sommet + MB.COINS[t]
			for y in range(base.y + 1, haut + 1):
				if pleines.has(Vector3i(base.x, y, base.z)):
					attendu_dehors = false
					break
			if not attendu_dehors:
				break
		var suffixee: bool = nom.ends_with(MB.SUFFIXE_DEHORS)
		if attendu_dehors:
			vus_dehors += 1
			if not suffixee:
				sous_ciel_nu += 1
		else:
			vus_dedans += 1
			if suffixee:
				sous_roche_suffixe += 1

	# ⚠ LES DEUX SENS, ET C'EST LE CŒUR DU CONTRÔLE. « Jamais de variante » passerait le second ;
	# « toujours la variante » passerait le premier. Il faut les deux pour que le choix soit gardé.
	_dire(sous_ciel_nu == 0,
		"%d sommet(s) à l'air libre portent le nom NU alors que la variante existe" % sous_ciel_nu)
	_dire(sous_roche_suffixe == 0,
		"%d sommet(s) sous roche portent la VARIANTE" % sous_roche_suffixe)
	# ⚠ ET LES CONTRÔLES QUI INVALIDENT L'INSTRUMENT, UN PAR CÔTÉ. Un total suffisant laisserait passer
	# « zéro sous roche » : les deux lignes ci-dessus porteraient alors sur zéro relevé d'un côté et ne
	# garderaient que la moitié du choix — ce qui est exactement ce qui s'est produit la première fois.
	_dire(vus_dehors > 4, "trop peu de sols à l'AIR LIBRE (%d) : ce côté n'est pas éprouvé" % vus_dehors)
	_dire(vus_dedans > 4, "trop peu de sols SOUS ROCHE (%d) : ce côté n'est pas éprouvé" % vus_dedans)
	m.free()
	print("   → %d sol(s) à l'air libre et %d sous roche, chacun avec le bon nom"
		% [vus_dehors, vus_dedans])


## Un massif prêt à peindre, hors éditeur.
func _massif() -> Node3D:
	var noeud: Node3D = Peint.new()
	root.add_child(noeud)
	noeud.preparer()
	return noeud


func _peindre(noeud: Node3D, cellules: Array) -> void:
	var cases: GridMap = noeud.get_node("Cases")
	var id: int = cases.mesh_library.find_item_by_name("case")
	for c in cellules:
		cases.set_cell_item(c, id)


func _pave(x0: int, x1: int, y0: int, y1: int, z0: int, z1: int) -> Array:
	var sortie: Array = []
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			for z in range(z0, z1 + 1):
				sortie.append(Vector3i(x, y, z))
	return sortie


# ── 1. les trois grilles ────────────────────────────────────────────────────────────────────────────

func _les_trois_grilles_existent() -> void:
	print("1. les trois grilles sont bâties par preparer()")
	var m := _massif()
	for nom in ["Cases", "Rendu", "Fautes"]:
		var g := m.get_node_or_null(nom)
		_dire(g != null and g is GridMap, "la grille « %s » manque" % nom)
	_dire(m.get_node("Cases").mesh_library != null, "« Cases » doit avoir une palette pour peindre")
	_dire(m.get_node("Cases").mesh_library.find_item_by_name("case") >= 0,
		"la palette doit contenir la tuile « case »")
	var lot_rendu: MeshLibrary = m.get_node("Rendu").mesh_library
	_dire(lot_rendu != null, "« Rendu » doit avoir un lot")
	# ⚠ Sans lot sculpté, le REPLI prend la main : 68 pièces, aucune ne peut manquer.
	#
	# ⚠ ET ON SE GARDE DU NULL, PARCE QUE LE BANC DE MUTATIONS L'A MONTRÉ. Sous « lot par défaut
	# retiré », cette ligne appelait `get_item_list()` sur `null` : le test PLANTAIT au lieu d'échouer.
	# Il rougissait quand même, mais une assertion qui plante interrompt le fichier et masque tout ce
	# qui suit — un test qui s'arrête en route ne garde que ce qu'il a eu le temps de lire.
	var combien: int = lot_rendu.get_item_list().size() if lot_rendu != null else -1
	_dire(combien == 68,
		"le lot par défaut devrait être le repli procédural (68 pièces), on en trouve %d" % combien)
	m.free()
	print("   → Cases, Rendu, Fautes, et le repli procédural par défaut")


# ── 2. LE DÉCALAGE ──────────────────────────────────────────────────────────────────────────────────

## ⚠ MESURÉ (`sonde_gridmap_centrage.gd`) : `cell_center_x/y/z` valent tous trois `true`, une case
## occupe [0,1]³, et le sommet lu par `bits(p, v)` siège en `v + (1,1,1)`. La grille de rendu doit donc
## être décalée de **+0,5 sur les trois axes** — signe positif, et le y compris.
func _le_decalage_est_d_une_demi_case_partout() -> void:
	print("\n2. le décalage d'une demi-case, sur les trois axes")
	var m := _massif()
	for nom in ["Rendu", "Fautes"]:
		var p: Vector3 = m.get_node(nom).position
		_dire(p.is_equal_approx(Vector3.ONE * 0.5),
			"« %s » devrait être décalée de (0.5, 0.5, 0.5), elle est en %s" % [nom, str(p)])
	_dire(m.get_node("Cases").position.is_equal_approx(Vector3.ZERO),
		"« Cases » ne doit PAS être décalée : c'est la vérité")
	# Le décalage suit la taille de case.
	m.taille_de_case = 2.0
	for nom in ["Rendu", "Fautes"]:
		_dire(m.get_node(nom).position.is_equal_approx(Vector3.ONE),
			"à 2,0 par case, « %s » devrait être décalée de (1,1,1)" % nom)
		_dire(m.get_node(nom).cell_size.is_equal_approx(Vector3.ONE * 2.0),
			"« %s » devrait avoir des cases de 2,0" % nom)
	m.free()
	print("   → +0,5 par case sur x, y ET z ; « Cases » reste à l'origine")


# ── 3. une case seule ───────────────────────────────────────────────────────────────────────────────

func _une_case_seule_pose_huit_pieces() -> void:
	print("\n3. une case seule pose huit pièces")
	var m := _massif()
	_peindre(m, [Vector3i(4, 2, -3)])
	var bilan: Dictionary = m.reconstruire()
	# ⚠ HUIT, pas quatre : une cellule influe sur les huit sommets qui l'entourent.
	_dire(bilan["pieces"] == 8, "une case seule devrait poser 8 pièces, elle en pose %d" % bilan["pieces"])
	_dire(bilan["fautes"] == 0, "une case seule ne devrait produire aucune faute, il y en a %d"
		% bilan["fautes"])
	_dire(bilan["muets"] == 0, "une case seule n'a aucun sommet muet, il y en a %d" % bilan["muets"])
	# Les huit pièces sont toutes des coins, dans huit orientations… ou moins : `mb_coin_b1h0` et
	# `mb_coin_b0h1` sont DEUX classes distinctes en modèle orienté (le coin du dessus et celui du
	# dessous ne sont pas la même chose). C'est précisément ce que le modèle orienté a acheté.
	var rendu: GridMap = m.get_node("Rendu")
	var noms := {}
	for c in rendu.get_used_cells():
					# ⚠ **SUFFIXE RETIRÉ, ET CE N'EST PAS UN DESSERRAGE.** Depuis la récolte à deux contextes, une
			# tuile posée sous le ciel peut s'appeler « mb_coin_b1h0_dehors ». Ce contrôle porte sur la
			# CLASSE — le coin du dessus contre celui du dessous — pas sur le contexte, qui a son propre
			# contrôle plus bas. Comparer le nom brut le ferait rougir sur un comportement CORRECT.
			noms[MB.nom_nu(rendu.mesh_library.get_item_name(rendu.get_cell_item(c)))] = true
	_dire(noms.size() == 2, "une case seule devrait employer 2 classes (le coin haut et le coin bas), "
		+ "on en trouve %d : %s" % [noms.size(), str(noms.keys())])
	_dire(noms.has("mb_coin_b1h0") and noms.has("mb_coin_b0h1"),
		"les deux classes devraient être mb_coin_b1h0 et mb_coin_b0h1, on a %s" % str(noms.keys()))
	m.free()
	print("   → 8 pièces, 2 classes distinctes (le coin du dessus et celui du dessous)")


# ── 4. L'INVARIANT : AUCUNE FAUTE, JAMAIS ───────────────────────────────────────────────────────────

## ⚠ C'EST LA PROMESSE DU GREFFON, ET ELLE SE VÉRIFIE SUR LES FORMES QUI FONT MAL. La charte a appris
## trois fois en 2D qu'un disque ne prouve rien : sa frontière est convexe. On prend donc l'encoche, le
## trou, le contact en diagonale, le surplomb et la case isolée.
func _aucune_forme_ne_produit_de_faute() -> void:
	print("\n4. aucune forme peinte ne produit de faute")
	for essai in [
		{"nom": "un plateau 4×1×4", "cellules": _pave(0, 3, 0, 0, 0, 3)},
		{"nom": "un bloc 3×3×3", "cellules": _pave(0, 2, 0, 2, 0, 2)},
		{"nom": "une colonne 1×5×1", "cellules": _pave(0, 0, 0, 4, 0, 0)},
		{"nom": "un L", "cellules": _pave(0, 2, 0, 0, 0, 0) + _pave(0, 0, 0, 0, 1, 2)},
		{"nom": "un plateau ENCOCHÉ",
			"cellules": _pave(0, 3, 0, 0, 0, 3).filter(func(c): return c != Vector3i(3, 0, 3))},
		{"nom": "une dalle TROUÉE",
			"cellules": _pave(0, 2, 0, 0, 0, 2).filter(func(c): return c != Vector3i(1, 0, 1))},
		{"nom": "contact en DIAGONALE",
			"cellules": [Vector3i(0, 0, 0), Vector3i(1, 0, 1)]},
		{"nom": "diagonale de CORPS",
			"cellules": [Vector3i(0, 0, 0), Vector3i(1, 1, 1)]},
		{"nom": "un SURPLOMB (matière en l'air)",
			"cellules": _pave(0, 2, 0, 0, 0, 2) + _pave(0, 2, 2, 2, 0, 2)},
		{"nom": "deux îles séparées",
			"cellules": _pave(0, 1, 0, 0, 0, 1) + _pave(5, 6, 0, 0, 5, 6)},
	]:
		var m := _massif()
		_peindre(m, essai["cellules"])
		var bilan: Dictionary = m.reconstruire()
		_dire(bilan["fautes"] == 0, "%s : %d faute(s) — l'invariant est cassé"
			% [essai["nom"], bilan["fautes"]])
		_dire(m.get_node("Fautes").get_used_cells().is_empty(),
			"%s : des cubes rouges sont posés" % essai["nom"])
		_dire(bilan["pieces"] > 0, "%s : aucune pièce posée" % essai["nom"])
		print("   %-32s %3d cases → %4d pièces, %d faute(s), %d muet(s)"
			% [essai["nom"], essai["cellules"].size(), bilan["pieces"], bilan["fautes"], bilan["muets"]])
		m.free()


# ── 5. le ventre creux ──────────────────────────────────────────────────────────────────────────────

## ⚠ UN MASSIF COÛTE SA SURFACE, PAS SON VOLUME. Un sommet entouré de huit cellules pleines est à
## l'intérieur de la matière : personne ne le voit, on n'y pose rien. C'est compté comme « muet », et
## surtout PAS comme une faute — une économie ne doit pas se lire comme une panne.
func _le_ventre_est_creux() -> void:
	print("\n5. le ventre d'un massif est creux")
	var m := _massif()
	_peindre(m, _pave(0, 2, 0, 2, 0, 2))   # 27 cellules
	var bilan: Dictionary = m.reconstruire()
	# ⚠ COMPTÉ À LA MAIN, PAS DEMANDÉ AU MODULE. Les cellules vont de 0 à 2 sur chaque axe. Un sommet
	# `v` lit les cellules `v` … `v+1` : il est donc muet quand `v` ET `v+1` tiennent dans 0..2, soit
	# `v ∈ {0,1}` sur chaque axe → 2³ = **8 sommets muets**. Les sommets touchés vont de −1 à 2, soit
	# 4³ = 64. Il reste donc 56 pièces.
	#
	# ⚠ J'AVAIS ÉCRIT « 1 MUET, 63 PIÈCES », ET DEUX DE MES PROPRES FICHIERS SE CONTREDISAIENT : le test
	# du repli imprimait déjà « un cube 3×3×3 — 27 cellules, 56 pièces ». Un chiffre attendu qu'on pose
	# de tête sans le recompter est exactement ce qui pousse à « arranger » le code pour lui plaire.
	_dire(bilan["muets"] == 8, "un bloc 3×3×3 a exactement 8 sommets muets, on en compte %d"
		% bilan["muets"])
	_dire(bilan["pieces"] == 56, "un bloc 3×3×3 devrait poser 56 pièces, il en pose %d"
		% bilan["pieces"])
	_dire(bilan["fautes"] == 0, "le ventre creux n'est pas une faute")
	# Et aucun des huit sommets du ventre ne porte quoi que ce soit.
	var rendu: GridMap = m.get_node("Rendu")
	for v in [Vector3i(0, 0, 0), Vector3i(1, 1, 1), Vector3i(0, 1, 0), Vector3i(1, 0, 1)]:
		_dire(rendu.get_cell_item(v) == GridMap.INVALID_CELL_ITEM,
			"le sommet %s est dans le ventre plein : il ne doit rien porter" % str(v))
	# ⚠ Et le contrôle inverse : un sommet du BORD, lui, doit porter une pièce. Sans lui, « rien n'est
	# posé nulle part » passerait ce test au vert.
	_dire(rendu.get_cell_item(Vector3i(-1, -1, -1)) != GridMap.INVALID_CELL_ITEM,
		"le sommet du coin extérieur devrait porter une pièce")
	m.free()
	print("   → 64 sommets, 56 pièces, 8 muets : le ventre ne coûte rien")


# ── 6. le nœud ne réinvente aucune règle ────────────────────────────────────────────────────────────

## ⚠ UNE SEULE AUTORITÉ SUR LA FORME DU MONDE. Si le nœud déduisait la pièce à sa façon, on aurait deux
## descriptions du même fait — et la charte est formelle : elles divergent au premier réglage. On
## vérifie donc case par case que ce qui est POSÉ est exactement ce que `MB.classer` dit.
func _ce_qui_est_pose_est_ce_que_les_regles_disent() -> void:
	print("\n6. ce qui est posé est exactement ce que les règles disent")
	var m := _massif()
	var cellules: Array = _pave(0, 3, 0, 1, 0, 3).filter(func(c): return c != Vector3i(3, 1, 3))
	_peindre(m, cellules)
	m.reconstruire()

	var pleines := {}
	for c in cellules:
		pleines[c] = true
	var rendu: GridMap = m.get_node("Rendu")
	var verifies := 0
	var faux := 0
	for c in rendu.get_used_cells():
		var sommet: Vector3i = c
		var attendu: Dictionary = MB.classer(MB.bits(pleines, sommet))
		var nom: String = rendu.mesh_library.get_item_name(rendu.get_cell_item(sommet))
		var orientation: int = rendu.get_cell_item_orientation(sommet)
		# ⚠ **ON COMPARE LA CLASSE, SUFFIXE RETIRÉ — et le contexte est vérifié à part, jamais ignoré.**
		# Une tuile d'air libre s'appelle « <classe>_dehors » ; exiger l'égalité du nom BRUT ferait
		# rougir ce contrôle sur un comportement correct. Mais retirer le suffixe sans rien mettre à la
		# place reviendrait à ne plus rien garder du contexte : d'où l'assertion qui suit, et le contrôle
		# dédié `_le_contexte_choisit_la_variante`.
		if MB.nom_nu(nom) != attendu["nom"] or orientation != attendu["orientation"]:
			faux += 1
			if faux <= 3:
				_dire(false, "sommet %s : posé « %s »/%d, attendu « %s »/%d"
					% [str(sommet), nom, orientation, attendu["nom"], attendu["orientation"]])
		verifies += 1
	_dire(faux == 0, "%d sommet(s) posés autrement que ce que les règles disent" % faux)
	_dire(verifies > 50, "trop peu de sommets vérifiés (%d)" % verifies)
	# ⚠ **ET UNE VARIANTE NE PEUT PAS APPARAÎTRE N'IMPORTE OÙ.** Ce lot est le repli procédural, qui n'en
	# porte aucune : il ne doit donc y en avoir zéro. Sans cette ligne, retirer le suffixe ci-dessus
	# aurait rendu le contrôle aveugle à une variante posée à tort.
	var suffixees := 0
	for c in rendu.get_used_cells():
		if (rendu.mesh_library.get_item_name(rendu.get_cell_item(c)) as String) \
				.ends_with(MB.SUFFIXE_DEHORS):
			suffixees += 1
	_dire(suffixees == 0,
		"le repli procédural n'a aucune variante : %d tuile(s) suffixée(s) posées" % suffixees)
	m.free()
	print("   → %d sommets vérifiés un par un, pièce ET orientation" % verifies)


# ── 7. effacer ──────────────────────────────────────────────────────────────────────────────────────

func _effacer_efface() -> void:
	print("\n7. effacer des cases efface le rendu")
	var m := _massif()
	_peindre(m, _pave(0, 2, 0, 0, 0, 2))
	var avant: Dictionary = m.reconstruire()
	_dire(avant["pieces"] > 0, "rien n'a été posé avant l'effacement")
	var cases: GridMap = m.get_node("Cases")
	for c in cases.get_used_cells():
		cases.set_cell_item(c, GridMap.INVALID_CELL_ITEM)
	var apres: Dictionary = m.reconstruire()
	_dire(apres["pieces"] == 0, "après effacement il reste %d pièce(s)" % apres["pieces"])
	_dire(m.get_node("Rendu").get_used_cells().is_empty(), "« Rendu » n'est pas vide")
	_dire(m.get_node("Fautes").get_used_cells().is_empty(), "« Fautes » n'est pas vide")
	m.free()
	print("   → effacé est effacé, des deux côtés")


# ── 8. l'empreinte ──────────────────────────────────────────────────────────────────────────────────

## ⚠ UN GRIDMAP N'ÉMET AUCUN SIGNAL quand on y peint : il n'y a rien à écouter. `_process()` compare
## donc une EMPREINTE à chaque image de l'éditeur, et ne reconstruit que si elle a changé. Aplatie,
## cette empreinte fige le rendu **en silence** dès qu'on déplace une case.
##
## ⚠ CE TEST APPELLE L'EMPREINTE DIRECTEMENT, ET C'EST UNE CORRECTION. La version précédente passait par
## `reconstruire()` — qui recalcule de toute façon — donc elle ne consultait JAMAIS l'empreinte, tout en
## s'intitulant « l'empreinte suit le déplacement ». Le banc de mutations l'a prouvé : aplatir
## l'empreinte ne faisait rougir personne. Une étiquette qui promet plus que ce qu'elle vérifie est pire
## qu'une absence de test, parce qu'elle rassure.
##
## ⚠ CE QU'ON NE PEUT PAS TESTER ICI, ET IL FAUT LE DIRE : la boucle `_process` elle-même. Elle est
## gardée par `Engine.is_editor_hint()`, faux en `--script`. On teste donc l'empreinte comme FONCTION
## PURE ; que l'éditeur la consulte à chaque image se juge dans l'éditeur, avec Jordan.
func _l_empreinte_suit_les_cases() -> void:
	print("\n8. l'empreinte distingue deux peintures différentes")
	var m := _massif()
	var cases: GridMap = m.get_node("Cases")
	var vide: int = m._empreinte_des_cases()

	_peindre(m, [Vector3i(0, 0, 0)])
	var une: int = m._empreinte_des_cases()
	_dire(une != vide, "peindre une case devrait changer l'empreinte (%d puis %d)" % [vide, une])

	_peindre(m, [Vector3i(1, 0, 0)])
	var deux: int = m._empreinte_des_cases()
	_dire(deux != une, "ajouter une seconde case devrait changer l'empreinte")

	# ⚠ LE CAS QUI PIÈGE, ET C'EST CELUI QUE LA MUTATION EXPLOITAIT : DÉPLACER une case sans changer
	# leur NOMBRE. Une empreinte qui ne compterait que les cases resterait identique, et le rendu se
	# figerait sans que rien ne le dise.
	cases.set_cell_item(Vector3i(1, 0, 0), GridMap.INVALID_CELL_ITEM)
	_peindre(m, [Vector3i(9, 4, 9)])
	var deplacee: int = m._empreinte_des_cases()
	_dire(cases.get_used_cells().size() == 2, "le déplacement doit garder DEUX cases")
	_dire(deplacee != deux,
		"déplacer une case sans changer leur nombre doit changer l'empreinte (%d des deux côtés)" % deux)

	# Un second déplacement, pour ne pas conclure sur un seul couple.
	cases.set_cell_item(Vector3i(9, 4, 9), GridMap.INVALID_CELL_ITEM)
	_peindre(m, [Vector3i(-7, 1, 2)])
	_dire(m._empreinte_des_cases() != deplacee, "un second déplacement doit aussi changer l'empreinte")

	# Et l'empreinte est une FONCTION de l'état : revenir au même dessin rend la même valeur.
	for c in cases.get_used_cells():
		cases.set_cell_item(c, GridMap.INVALID_CELL_ITEM)
	_dire(m._empreinte_des_cases() == vide, "tout effacer doit rendre l'empreinte du vide")
	_peindre(m, [Vector3i(0, 0, 0)])
	_dire(m._empreinte_des_cases() == une, "repeindre le même dessin doit rendre la même empreinte")

	m.free()
	print("   → l'empreinte distingue l'ajout, le retrait ET le déplacement à nombre constant")


# ── 10. le peintre tire un exemplaire par position ───────────────────────────────────
#
# ⚠ **LE DÉFAUT QUE CETTE SECTION GARDE A COÛTÉ 489 MORCEAUX SCULPTÉS.** Le trancheur s'arrêtait au
# PREMIER sommet de chaque clé (`if pieces.has(cle): continue`) : sur la planète paysage, 541 sommets
# récoltables pour 52 clés, donc 489 morceaux jetés sans un mot — et le survivant n'était pas le
# meilleur, seulement le plus petit `vx` de la boucle.
#
# TROIS PROPRIÉTÉS, ET LA PREMIÈRE EST LA PLUS IMPORTANTE :
#
#   1. **un lot SANS exemplaires peint exactement comme avant** (charte §9.4). Le repli procédural et
#      tout lot d'avant cette version passent par le même chemin, sans branche séparée ;
#   2. **un lot AVEC exemplaires les pose réellement**, et pas un seul d'entre eux ;
#   3. **le tirage se répète à l'identique** — le massif se reconstruit à chaque case peinte et à
#      chaque Ctrl+Z ; un tirage aléatoire redessinerait un autre monde à chaque fois, et l'artiste ne
#      pourrait ni juger ce qu'il voit ni le retrouver demain.

## Le lot du repli, augmenté de `combien` exemplaires pour CHAQUE tuile qu'il porte.
## ⚠ Les maillages sont ceux de la tuile d'origine : ce qu'on éprouve ici est le TIRAGE, pas la forme.
func _lot_a_exemplaires(combien: int) -> MeshLibrary:
	var source: MeshLibrary = RP.librairie()
	var lot := MeshLibrary.new()
	var id := 0
	for vieux in source.get_item_list():
		var nom: String = source.get_item_name(vieux)
		for k in range(0, combien + 1):
			lot.create_item(id)
			lot.set_item_name(id, MB.nom_d_exemplaire(nom, k))
			lot.set_item_mesh(id, source.get_item_mesh(vieux))
			lot.set_item_shapes(id, source.get_item_shapes(vieux))
			id += 1
	return lot


func _le_peintre_tire_un_exemplaire_par_position() -> void:
	print("\n10. le peintre tire un exemplaire par position, et un lot sans exemplaires marche encore")
	var cellules: Array = _pave(0, 5, 0, 3, 0, 5)

	# — 1. LE LOT SANS EXEMPLAIRES : rien ne change, et rien ne rougit
	var nu := _massif()
	_peindre(nu, cellules)
	var b_nu: Dictionary = nu.reconstruire()
	_dire(int(b_nu["fautes"]) == 0,
		"un lot SANS exemplaires doit peindre sans faute, il en produit %d" % int(b_nu["fautes"]))
	_dire(int(b_nu.get("exemplaires", -1)) == 0,
		"un lot SANS exemplaires ne doit poser aucun exemplaire, il en pose %d"
		% int(b_nu.get("exemplaires", -1)))
	_dire(int(b_nu["pieces"]) > 0, "le témoin nu doit poser des pièces, il en pose %d" % int(b_nu["pieces"]))
	var poses_nu: int = int(b_nu["pieces"])
	nu.free()

	# — 2. LE LOT AVEC EXEMPLAIRES : autant de pièces, aucune faute, et des exemplaires vraiment posés
	var m := _massif()
	m.lot = _lot_a_exemplaires(3)
	_peindre(m, cellules)
	var b: Dictionary = m.reconstruire()
	_dire(int(b["fautes"]) == 0,
		"un lot AVEC exemplaires ne doit produire aucune faute, il en produit %d" % int(b["fautes"]))
	_dire(int(b["pieces"]) == poses_nu,
		"le même monde doit poser le même nombre de pièces : %d sans exemplaires, %d avec"
		% [poses_nu, int(b["pieces"])])
	_dire(int(b.get("exemplaires", 0)) > 0,
		"avec 4 exemplaires par tuile, le peintre doit en poser autre chose que le premier — il en pose %d"
		% int(b.get("exemplaires", 0)))

	# ⚠ — LE TIRAGE N'EST PAS DÉGÉNÉRÉ : les quatre indices doivent tous apparaître. Un hachage qui
	#   rendrait toujours 0 passerait les trois contrôles précédents sauf celui-ci.
	var rendu: GridMap = m.get_node("Rendu")
	var indices := {}
	for c in rendu.get_used_cells():
		indices[MB.indice_d_exemplaire(m.lot.get_item_name(rendu.get_cell_item(c)))] = true
	_dire(indices.size() == 4,
		"les 4 exemplaires doivent tous être posés quelque part, %d le sont : %s"
		% [indices.size(), str(indices.keys())])

	# ⚠ — ET LE TIRAGE SE RÉPÈTE. On reconstruit à l'identique et on compare case par case.
	var avant := {}
	for c in rendu.get_used_cells():
		avant[c] = rendu.get_cell_item(c)
	m.forcer_reconstruction() if m.has_method("forcer_reconstruction") else null
	for c in rendu.get_used_cells():
		rendu.set_cell_item(c, -1)
	m.reconstruire()
	var bouges := 0
	for c in avant:
		if rendu.get_cell_item(c) != avant[c]:
			bouges += 1
	_dire(bouges == 0,
		"%d case(s) changent d'exemplaire d'une reconstruction à l'autre — le tirage doit être déterminé "
		% bouges + "par la POSITION, jamais aléatoire")
	m.free()

	print("   → %d pièces, %d exemplaire(s) autres que le premier, 4 indices tous posés, 0 case instable"
		% [int(b["pieces"]), int(b.get("exemplaires", 0))])
