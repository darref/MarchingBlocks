extends SceneTree
##
## SONDE — LE TÉMOIN MONTRE-T-IL TOUS LES RACCORDS POSSIBLES ?
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_germes.gd
##
## ── POURQUOI ELLE EXISTE ────────────────────────────────────────────────────────────────────────────
##
## Jordan, 25 septembre 2026, sur l'architecture du témoin : *« garder une ou plusieurs érosions pour
## les cas compliqués et rares, mais tout en redondant des tuiles du premier témoin pour que les
## raccords entre celui-ci et celui d'érosion soient des cas réels donc couverts »*.
##
## ⚠ **LA COUVERTURE DES RACCORDS NE SE COMPTE PAS EN PAIRES DE TUILES.** Il y en a des milliers, et
## aucun témoin ne les montrera toutes. Elle se compte en **GERMES** : l'interface entre deux pièces
## voisines est entièrement déterminée par les QUATRE cases qu'elles partagent, et le modèle orienté
## n'en admet que **28** (`nombre_de_germes()` : « doit valoir 28 en modèle orienté »).
##
## **Le critère est donc : un témoin qui exhibe les 28 germes sur ses faces internes rend TOUS les
## raccords possibles vérifiables par l'artiste**, quelles que soient les tuiles qui se retrouveront
## côte à côte ensuite.
##
##   • 28/28 → la redondance de Jordan n'a rien à réparer : il suffit d'enrichir le bloc sans le scinder.
##   • moins → les germes manquants SONT les raccords que l'artiste ne voit jamais et qui tomberont
##     faux. La liste des manquants dit exactement ce qu'un second bloc doit contenir.
##
## ── CE QU'ELLE MESURE, ET CE QU'ELLE NE PROUVE PAS ──────────────────────────────────────────────────
##
## ⚠ Elle dit qu'un germe EST PRÉSENT, jamais qu'il est bien sculpté. Voir un raccord ne garantit pas
## qu'on l'ait réussi — c'est `verifier_couture()` qui juge ça, et il ne juge que l'AIRE, pas la
## section (sa propre docstring le dit).
## ⚠ Elle n'invente aucun germe : elle appelle `Tranchage.germe_canonique()`, la même fonction que le
## contrôle de couture. Une seconde description du repliage aurait divergé (charte §6).

const MB := preload("res://addons/marching_blocks_plugin_godot/marching_blocks.gd")
const BM := preload("res://addons/marching_blocks_plugin_godot/blocs_maitres.gd")
const Tranchage := preload("res://addons/marching_blocks_plugin_godot/tranchage.gd")

## ⚠ **QUEL BLOC — ET C'EST DEVENU LA QUESTION CENTRALE DEPUIS QU'IL Y EN A DEUX (Jordan, 25 septembre
## 2026).** Avec un témoin unique, « 22/22 » suffisait. Avec deux, la règle est que **chaque germe doit
## apparaître À L'INTÉRIEUR d'au moins un des blocs** : un raccord qui n'existerait qu'à la jonction
## entre les deux n'existerait nulle part, et l'artiste ne le sculpterait jamais.
## Mesuré le jour même : le témoin paysage n'en exhibe que **18 sur 22**, les quatre manquants étant
## tous de forme « diagonale » — un paysage orthogonal n'en produit aucun. C'est donc au second bloc de
## les porter, et cette sonde doit pouvoir l'interroger lui aussi.
var _bloc := 0


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--bloc="):
			_bloc = int(option.substr("--bloc=".length()))
	if _bloc < 0 or _bloc >= BM.nombre():
		print("⚠ --bloc=%d : il y a %d bloc(s)" % [_bloc, BM.nombre()])
		quit(1)
		return
	print("=== LE TÉMOIN MONTRE-T-IL TOUS LES RACCORDS POSSIBLES ? ===")
	print("bloc %d — « %s »\n" % [_bloc, BM.BLOCS[_bloc]["nom"]])

	var attendus: int = Tranchage.nombre_de_germes()
	print("germes définis par le groupe : %d   (le modèle orienté en attend 28)\n" % attendus)

	# ── L'UNIVERS DES GERMES : toutes les faces × toutes les configurations de 4 cases ───────────────
	#
	# ⚠ ON L'ÉNUMÈRE PLUTÔT QUE DE LE DÉCLARER. Écrire « 28 » en dur ici, c'est se priver du jour où le
	# groupe change : la sonde annoncerait une couverture parfaite sur un univers périmé.
	var univers := {}
	for face in MB.FACES:
		for m in 16:
			var quatre: Array = []
			var pleins: Array = []
			for i in 4:
				var plein: bool = (m & (1 << i)) != 0
				quatre.append(plein)
				if plein:
					pleins.append(int(face["coins"][i]))
			var germe: String = Tranchage.germe_canonique(face["coins"], pleins)
			if not univers.has(germe):
				univers[germe] = {"forme": MB.forme_de_face(quatre), "faces": {}}
			(univers[germe]["faces"] as Dictionary)[face["nom"]] = true

	# ⚠ « rien » et « plein » ne cousent RIEN : aucune surface ne traverse ce plan, il n'y a donc pas de
	# raccord à voir. Les compter dans le dénominateur gonflerait la couverture d'une quantité qui ne
	# veut rien dire — exactement le genre de compteur vert qui rassure à tort.
	var a_coudre := {}
	for g in univers:
		var forme: String = univers[g]["forme"]
		if forme != "rien" and forme != "plein":
			a_coudre[g] = univers[g]
	print("germes énumérés : %d  ·  dont %d portent une couture (les autres sont « rien » ou « plein »)\n"
		% [univers.size(), a_coudre.size()])

	# ── CE QUE LE BLOC EXHIBE RÉELLEMENT ────────────────────────────────────────────────────────────
	var pleines: Dictionary = BM.cases(_bloc)
	var vus := {}
	var sommets_lus := 0
	for vx in range(0, BM.COTE - 1):
		for vy in range(0, BM.COTE - 1):
			for vz in range(0, BM.COTE - 1):
				var v := Vector3i(vx, vy, vz)
				var bits: int = MB.bits(pleines, v)
				var r: Dictionary = MB.classer(bits)
				if not r["surface"]:
					continue
				sommets_lus += 1
				for face in MB.FACES:
					var quatre: Array = []
					var pleins2: Array = []
					for t in face["coins"]:
						var plein: bool = (bits & (1 << int(t))) != 0
						quatre.append(plein)
						if plein:
							pleins2.append(int(t))
					var forme: String = MB.forme_de_face(quatre)
					if forme == "rien" or forme == "plein":
						continue
					var germe: String = Tranchage.germe_canonique(face["coins"], pleins2)
					vus[germe] = int(vus.get(germe, 0)) + 1

	print("── CE QUE LE BLOC DE %d³ EXHIBE ──" % BM.COTE)
	print("   %d sommet(s) portant une surface  ·  %d germe(s) distincts vus sur %d à coudre"
		% [sommets_lus, vus.size(), a_coudre.size()])

	var manquants: Array = []
	for g in a_coudre:
		if not vus.has(g):
			manquants.append(g)
	if manquants.is_empty():
		print("   → COUVERTURE COMPLÈTE : tout raccord possible est visible à l'intérieur du bloc.")
		print("     Un second bloc n'a donc aucun raccord NEUF à faire voir ; il n'aurait à redonder")
		print("     que pour offrir un meilleur exemplaire, pas pour couvrir un trou.")
	else:
		print("   ⚠ %d GERME(S) MANQUANT(S) — ce sont les raccords que l'artiste ne voit JAMAIS :"
			% manquants.size())
		for g in manquants:
			print("      %-34s forme « %s »  ·  faces concernées : %s"
				% [g, univers[g]["forme"],
					", ".join(PackedStringArray((univers[g]["faces"] as Dictionary).keys()))])

	# ── LES GERMES RARES : vus une ou deux fois seulement ────────────────────────────────────────────
	#
	# ⚠ Un germe vu UNE SEULE FOIS est presque aussi fragile qu'un germe absent : l'artiste n'a qu'un
	# endroit pour le voir, et `verifier_couture` ne peut RIEN en dire — il lui faut au moins deux
	# relevés pour comparer (« if releves.size() < 2: continue »). Un germe unique n'est donc gardé par
	# aucun contrôle.
	var rares: Array = []
	for g in vus:
		if int(vus[g]) < 2:
			rares.append(g)
	print("\n   ⚠ %d germe(s) vus UNE SEULE FOIS — ni comparables par verifier_couture, ni vérifiables"
		% rares.size())
	for g in rares:
		print("      %-34s forme « %s »" % [g, univers[g]["forme"]])

	var classement: Array = vus.keys()
	classement.sort_custom(func(a, b): return int(vus[a]) > int(vus[b]))
	print("\n   les cinq germes les plus fréquents : %s"
		% ", ".join(PackedStringArray(classement.slice(0, 5).map(
			func(g): return "%s ×%d" % [g, vus[g]]))))

	print("\n⚠ Cette sonde dit qu'un raccord est VISIBLE, jamais qu'il est bien sculpté.")
	quit(0)
