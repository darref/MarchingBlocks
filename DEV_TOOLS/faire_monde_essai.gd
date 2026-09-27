extends SceneTree
##
## LE MONDE D'ESSAI — peindre pour de vrai, avec le lot des NEUF BLOCS et sans aucun repli.
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/faire_monde_essai.gd -- --relief
##
##   --relief   applique le relief d'essai périodique aux neuf blocs (matière strictement entre le min
##              et le max de chaque case) au lieu de leur solide plat.
##
## ── POURQUOI CET OUTIL, ET CE QU'IL CHERCHE ─────────────────────────────────────────────────────────
##
## Tout ce qui précède a été mesuré pièce par pièce : la couverture, la couture, les octants, les
## bornes. ⚠ **Rien de tout ça ne dit qu'un monde PEINT tient debout.** C'est la leçon la plus chère de
## ce projet, répétée trois fois en une journée (charte §6) : *une mesure de couverture répond à « a-t-on
## posé quelque chose », jamais à « est-ce la bonne chose »*.
##
## Cet outil fait donc le seul essai qui reste : il bâtit le lot du bloc témoin, peint un monde qui
## contient exprès les situations difficiles, et regarde ce qui manque.
##
## ⚠ **AUCUN REPLI.** Une classe qu'aucun bloc ne livre n'est pas comblée : elle est signalée ici, et le
## peintre verra un cube rouge à cet endroit. C'est la décision de Jordan du 23 septembre, et c'est ce
## qui rend cet essai falsifiable — avec le repli, il ne pourrait jamais échouer.
##
## ── CE QU'IL ÉCRIT ──────────────────────────────────────────────────────────────────────────────────
##
##   ART/marching_blocks.tres     la MeshLibrary tirée du bloc témoin
##   NIVEAUX/monde_essai_3d.tscn  une scène ouvrable, déjà peinte, et qu'on peut CONTINUER à peindre

const MB := preload("res://addons/marching_blocks_plugin_godot/marching_blocks.gd")
const BlocsMaitres := preload("res://addons/marching_blocks_plugin_godot/blocs_maitres.gd")

## ⚠ **LE DRAPEAU `--moitie` A DISPARU AVEC LE MODE (Jordan, 25 septembre 2026).** Les tuiles sont
## DÉSORMAIS TOUJOURS ramenées à la moitié de leur case avant le tranchage. C'est l'ordre qui compte —
## les cubes restent fermés, le trancheur coupe dedans, et les pièces voisines se rebouchent comme
## d'habitude. Deux mécanismes essayés avant celui-ci sont mesurés faux : amincir les CASES dessine la
## grille décalée d'une demi-case par rapport au pavage, et rétrécir les pièces APRÈS le tranchage les
## crève (une pièce est ouverte sur ses faces de coupe — aire 3,0 au lieu de 4,0).
var _lot := "res://ART/marching_blocks.tres"
var _scene := "res://NIVEAUX/monde_essai_3d.tscn"


func _initialize() -> void:
	print("=== LE MONDE D'ESSAI — lot du bloc témoin, sans repli ===\n")
	print("tuiles ramenées à la moitié de leur case : toujours (mode unique)\n")

	# ── 1. le jeu de blocs doit être sain AVANT qu'on en tire quoi que ce soit ───────────────────────
	var fautes: Array = BlocsMaitres.anomalies()
	if not fautes.is_empty():
		print("REFUSÉ — %d anomalie(s) dans le jeu de blocs :" % fautes.size())
		for f in fautes:
			print("   • %s" % f)
		quit(1)
		return

	# ── 2. la bibliothèque ──────────────────────────────────────────────────────────────────────────
	var bilan: Dictionary = BlocsMaitres.librairie()
	var lot: MeshLibrary = bilan["lot"]
	var manquantes: Array = bilan["manquantes"]
	var erreurs: Array = bilan["erreurs"]
	var provenance: Dictionary = bilan["provenance"]

	print("── LA BIBLIOTHÈQUE ──")
	print("   %d item(s) sur %d classes de surface" % [lot.get_item_list().size(),
		MB.pieces_a_sculpter().size()])
	var par_bloc := {}
	for nom in provenance:
		par_bloc[provenance[nom]] = par_bloc.get(provenance[nom], 0) + 1
	for b in BlocsMaitres.BLOCS:
		print("      %-20s %2d classe(s) retenue(s)" % [b["nom"], par_bloc.get(b["nom"], 0)])
	if not manquantes.is_empty():
		print("   ⚠ %d CLASSE(S) MANQUANTE(S) — cubes rouges garantis : %s"
			% [manquantes.size(), ", ".join(PackedStringArray(manquantes.slice(0, 10)))])
	if not erreurs.is_empty():
		print("   ⚠ %d erreur(s) de tranchage :" % erreurs.size())
		for e in erreurs.slice(0, 10):
			print("      • %s" % String(e).left(160))
	print("")

	# ── 3. LE MONDE, et ce qu'il réclame ────────────────────────────────────────────────────────────
	var pleines: Dictionary = _monde()
	var reclamees := {}
	var muets := 0
	var sommets := {}
	for c in pleines:
		for s in MB.sommets_de(c):
			sommets[s] = true
	for s in sommets:
		var r: Dictionary = MB.classer(MB.bits(pleines, s))
		if not r["surface"]:
			muets += 1
			continue
		reclamees[r["nom"]] = reclamees.get(r["nom"], 0) + 1

	var absentes: Array = []
	for nom in reclamees:
		if lot.find_item_by_name(nom) < 0:
			absentes.append(nom)
	absentes.sort()

	print("── LE MONDE PEINT ──")
	print("   %d cellules, %d sommets, %d pièces à poser, %d sommets muets (ventre plein ou vide)"
		% [pleines.size(), sommets.size(), sommets.size() - muets, muets])
	print("   %d classe(s) DISTINCTE(S) réclamée(s) par ce monde" % reclamees.size())
	var tri: Array = reclamees.keys()
	tri.sort_custom(func(a, b): return reclamees[a] > reclamees[b])
	for nom in tri.slice(0, 12):
		print("      %-26s %5d fois   (de « %s »)"
			% [nom, reclamees[nom], provenance.get(nom, "— ABSENTE —")])
	if absentes.is_empty():
		print("   → le lot répond à TOUTES les classes de ce monde.")
	else:
		print("   ⚠ %d classe(s) réclamée(s) et ABSENTE(S) du lot : %s"
			% [absentes.size(), ", ".join(PackedStringArray(absentes))])
	print("")

	# ── 4. on écrit ─────────────────────────────────────────────────────────────────────────────────
	var err := ResourceSaver.save(lot, _lot)
	if err != OK:
		print("échec de l'enregistrement du lot (%d) : %s" % [err, _lot])
		quit(1)
		return
	print("lot   → %s" % _lot)

	var raison: String = _ecrire_la_scene(lot, pleines)
	if raison != "":
		print("échec de la scène : %s" % raison)
		quit(1)
		return
	print("scène → %s" % _scene)

	print("\nOuvre la scène, sélectionne « Cases » dans l'arbre, et peins avec l'éditeur GridMap.")
	print("Le rendu suit tout seul. ⚠ Un cube ROUGE = une classe que le lot ne sait pas rendre.")
	quit(1 if (not manquantes.is_empty() or not absentes.is_empty() or not erreurs.is_empty()) else 0)


## LE MONDE D'ESSAI — les situations qui font mal, pas un joli paysage.
##
## ⚠ On met exprès ce que les mesures ont désigné comme difficile : un angle RENTRANT (la jonction
## plateau/plaine), un TUNNEL (plafond de grotte), une ARCHE (matière au-dessus du vide), un contact en
## DIAGONALE et une case ISOLÉE. Un monde rectangulaire bien élevé ne prouverait rien — c'est le disque
## convexe qui avait fait lire 36/36 pendant que la carte réelle était pleine de carrés bruts.
func _monde() -> Dictionary:
	var pleines := {}
	# la plaine : deux couches, 16 × 16
	for x in range(0, 16):
		for z in range(0, 16):
			for y in range(0, 2):
				pleines[Vector3i(x, y, z)] = true
	# un plateau en L, posé dessus : son pied contre la plaine est un angle RENTRANT
	for x in range(2, 10):
		for z in range(2, 10):
			if x >= 6 and z >= 6:
				continue
			for y in range(2, 5):
				pleines[Vector3i(x, y, z)] = true
	# un TUNNEL percé dans le plateau, ouvert aux deux bouts
	for x in range(2, 10):
		for z in range(3, 5):
			for y in range(2, 4):
				pleines.erase(Vector3i(x, y, z))
	# une ARCHE : deux piles et une portée, à côté du plateau
	for z in range(12, 15):
		for y in range(2, 5):
			pleines[Vector3i(3, y, z)] = true
			pleines[Vector3i(8, y, z)] = true
		for x in range(3, 9):
			pleines[Vector3i(x, 5, z)] = true
	# un contact en DIAGONALE et une case ISOLÉE, sur la plaine
	pleines[Vector3i(13, 2, 2)] = true
	pleines[Vector3i(14, 2, 3)] = true
	pleines[Vector3i(13, 2, 6)] = true
	return pleines


## La scène : un `MassifPeint` câblé sur le lot, sa grille « Cases » DÉJÀ peinte.
##
## ⚠ LES TROIS GRILLES SONT BÂTIES AVANT LA POSE, et chaque nœud reçoit son `owner` : un enfant dont le
## parent n'est pas encore possédé n'est pas retenu à l'enregistrement de la scène. C'est la même
## correction que le bouton « Peindre un massif » avait dû apprendre.
func _ecrire_la_scene(lot: MeshLibrary, pleines: Dictionary) -> String:
	var racine := Node3D.new()
	racine.name = "MondeEssai3D"

	var massif: Node3D = load("res://addons/marching_blocks_plugin_godot/massif_peint.gd").new()
	massif.name = "MassifPeint"
	massif.preparer()
	massif.lot = lot
	racine.add_child(massif)
	massif.owner = racine
	for enfant in massif.get_children():
		enfant.owner = racine

	var cases: GridMap = massif.get_node_or_null("Cases")
	if cases == null:
		racine.free()
		return "le MassifPeint n'a pas de grille « Cases »"
	var id: int = cases.mesh_library.find_item_by_name("case") if cases.mesh_library != null else -1
	if id < 0:
		racine.free()
		return "la palette n'a pas de tuile « case »"
	for c in pleines:
		cases.set_cell_item(c, id)

	# ⚠ ON RECONSTRUIT AVANT DE SAUVER : sans ça la scène s'ouvre vide et l'on croit l'outil raté.
	var bilan: Dictionary = massif.reconstruire()
	print("   rendu : %d pièce(s) posée(s), %d faute(s), %d sommet(s) muet(s)"
		% [bilan.get("pieces", 0), bilan.get("fautes", 0), bilan.get("muets", 0)])

	var paquet := PackedScene.new()
	var err := paquet.pack(racine)
	if err != OK:
		racine.free()
		return "pack() a rendu %d" % err
	err = ResourceSaver.save(paquet, _scene)
	racine.free()
	if err != OK:
		return "save() a rendu %d" % err
	return ""
