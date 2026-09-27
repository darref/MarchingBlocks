extends SceneTree

## SONDE — CE QUE COÛTE LA DERNIÈRE CLASSE EXTÉRIEURE.
##
## ⚠ Elle ne conçoit rien : elle dit ce qui EXISTE dans la grille **actuellement collée** dans
## `blocs_maitres.gd`, pour qu'on puisse la comparer à la sortie fraîche du finisseur **dans la même
## unité**. Écrite parce que j'allais opposer les « 18 arêtes ambiguës » de la charte aux « 44 contacts
## par arête » du vérificateur — deux nombres dont rien ne garantissait qu'ils comptaient la même chose.
## L'un porte sur l'OCCUPATION, l'autre sur le MAILLAGE AMINCI. La charte §6 le dit : avant d'énoncer un
## fait, vérifier que l'instrument mesure bien ce qu'on croit.
##
## ⚠ **LE CLASSEMENT EST RECOPIÉ DE `_contextes()` DU VÉRIFICATEUR, ET C'EST DÉLIBÉRÉ.** Il ne range une
## classe dans `int` que si elle n'est PAS dehors ; ma première version la comptait des deux côtés, et
## les totaux n'auraient pas été comparables entre les deux grilles — un écart invisible qui aurait fait
## dire n'importe quoi à la comparaison.

const MB := preload("res://addons/marching_blocks_plugin_godot/marching_blocks.gd")
const BlocsMaitres := preload("res://addons/marching_blocks_plugin_godot/blocs_maitres.gd")
const Topo := preload("res://DEV_TOOLS/topologie.gd")


func _initialize() -> void:
	var pleines: Dictionary = BlocsMaitres.cases(0)
	var cote: int = BlocsMaitres.COTE
	print("=== LA GRILLE COLLÉE DANS blocs_maitres.gd ===")
	print("   %d cases pleines" % pleines.size())
	# ⚠ Les DEUX populations sur lesquelles `test_blocs_maitres.gd` assertit élément par élément : une
	# vérification par cellule (« sort du cube ») et une par pièce (« le sommet n'est pas intérieur »).
	# C'est d'elles que dépend le total de la suite — un total qui bouge sans qu'aucune assertion n'ait
	# été touchée, et qu'il faut savoir expliquer plutôt que constater.
	print("   %d pièces (sommets intérieurs portant une surface)" % BlocsMaitres.pieces_de(0).size())

	# ── LA COUVERTURE, par les deux contextes ───────────────────────────────────────────────────────
	var plafond: int = MB.plafond_de(pleines)
	var nus := {}
	var variantes := {}
	for vx in range(cote - 1):
		for vy in range(cote - 1):
			for vz in range(cote - 1):
				var v := Vector3i(vx, vy, vz)
				var b: int = MB.bits(pleines, v)
				if not MB.porte_une_surface(b):
					continue
				var nom: String = MB.classer(b)["nom"]
				if MB.exterieur_possible(b) and MB.sous_le_ciel(pleines, v, plafond):
					variantes[nom] = true
				else:
					nus[nom] = true
	print("   INTÉRIEUR %d/%d   EXTÉRIEUR %d/%d   TOTAL %d/%d"
		% [nus.size(), MB.pieces_a_sculpter().size(),
			variantes.size(), MB.classes_exterieures().size(),
			nus.size() + variantes.size(),
			MB.pieces_a_sculpter().size() + MB.classes_exterieures().size()])

	var manque := []
	for nom in MB.classes_exterieures():
		if not variantes.has(nom):
			manque.append(nom)
	print("   manque en extérieur : %s" % str(manque))

	# ── LA TOPOLOGIE, exactement les compteurs du vérificateur ──────────────────────────────────────
	print("\n   contacts par arête dans l'OCCUPATION : %d" % MB.contacts_par_arete(pleines))
	for essai in [
		{"nom": "solide (retrait 0)", "retrait": 0.0},
		{"nom": "aminci (retrait 0,25)", "retrait": 0.25},
	]:
		var b2: Dictionary = Topo.bilan(Topo.coque_sous_voxels(pleines, essai["retrait"]), pleines)
		print("   %-22s %5d quads · bords %d, 3+faces %d"
			% [essai["nom"], b2["quads"], b2["q_bords"], b2["q_multiples"]])
	# ── CE QUE LE GREFFON LIVRE VRAIMENT ────────────────────────────────────────────────────────────
	# ⚠ **LA COUVERTURE N'EST PAS LA LIVRAISON.** « 90/90 » dit que le bloc PORTE les 90 tuiles ; il ne
	# dit pas que `librairie()` les rend. Les deux ont déjà divergé dans ce projet — la machine annonçait
	# 90/90 quand le greffon en livrait 73 — et c'est ce qui a valu au §9 de la charte sa mise en garde.
	# On ne réécrit donc pas « fait » dans la charte sur la foi d'un compteur de couverture.
	# ⚠ **ET ON COMPTE LE LOT, PAS LES CLÉS DU RÉSULTAT.** Première version de cette sonde : elle
	# annonçait « librairie() livre 5 items » — les cinq clés du dictionnaire rendu (`lot`, `manquantes`,
	# `variantes`, `erreurs`, `provenance`). Un effondrement de 89 à 5 qu'aucune des six suites vertes
	# n'aurait laissé passer : c'est ce qui a trahi l'instrument, pas le sujet.
	var lib: Dictionary = BlocsMaitres.librairie()
	var lot: MeshLibrary = lib["lot"]
	var items: Array = lot.get_item_list()
	var suffixees := 0
	for id in items:
		if lot.get_item_name(id).ends_with(MB.SUFFIXE_DEHORS):
			suffixees += 1
	print("\n   librairie() livre %d items · %d nus, %d en variante « dehors »"
		% [items.size(), items.size() - suffixees, suffixees])
	print("   déclaré par _assembler : %d variante(s), %d classe(s) manquante(s) %s"
		% [int(lib["variantes"]), (lib["manquantes"] as Array).size(),
			str((lib["manquantes"] as Array).slice(0, 6))])
	print("   erreurs de tranchage : %d" % (lib["erreurs"] as Array).size())
	quit(0)
