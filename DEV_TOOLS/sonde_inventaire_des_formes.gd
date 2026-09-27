extends SceneTree

## SONDE — L'INVENTAIRE DES FORMES : lesquelles sont intuitives, lesquelles sont communes ?
##
## ⚠ **LA DEMANDE EST DE JORDAN (26 septembre 2026)** : *« nomme-moi toutes les formes qu'on retrouve
## dans un monde de marching blocks, les plus simples et plus communes, et je les rajoute à la main
## jusqu'à ce qu'on soit d'accord, et le témoin érosion contiendra tout le reste. »*
##
## ⚠ **« COMMUN » EST COMPTÉ, PAS DEVINÉ.** Ce projet a déjà payé une liste écrite à l'observation —
## la liste `AMBIGUES`, qui annonçait « 5 classes ambiguës » quand le calcul en donnait 10 sur les
## blocs et 35 dans un monde d'essai (charte §2). On ne classe donc pas les formes par intuition : on
## les compte sur le monde que JORDAN a peint (`NIVEAUX/OverWorld/Overworld.tscn`), c'est-à-dire sur
## le seul échantillon de ce qu'il pose réellement.
##
## ⚠ **ET « INTUITIF » N'EST PAS « FRÉQUENT » — les deux colonnes sont séparées exprès.** Une forme
## peut être facile à modeler et rare (un coin rentrant de plafond), ou fréquente et difficile (un
## contact diagonal, qui n'a pas de matière continue à sculpter). La sonde donne les deux et ne tranche
## pas : c'est Jordan qui décide ce qu'il met dans le témoin intuitif.
##
## ⚠ **LE CONTACT DIAGONAL EST LA VRAIE LIGNE DE PARTAGE, et elle est structurelle.** 33 des 68 classes
## SONT des contacts diagonaux — deux cellules qui ne se touchent que par une arête, où quatre faces se
## rejoignent. Aucune n'est « intuitive à modeler » : la matière y est pincée en un point. C'est
## exactement ce que le témoin d'érosion aura à porter, et c'est mesurable — pas une impression.
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_inventaire_des_formes.gd

const MB := preload("res://addons/marching_blocks_plugin_godot/marching_blocks.gd")
const BM := preload("res://addons/marching_blocks_plugin_godot/blocs_maitres.gd")

const SCENE := "res://NIVEAUX/OverWorld/Overworld.tscn"

## ⚠ **LES DESCRIPTIONS SONT ÉCRITES À LA MAIN, ET C'EST ASSUMÉ.** Ce sont des mots pour un humain,
## pas une mesure : le nombre de cellules, leur disposition et la présence d'un contact diagonal sont
## DÉDUITS des bits juste en dessous. Si une description et une mesure se contredisent, c'est la
## mesure qui a raison.
const DITS := {
	"mb_coin": "UN cube isolé dans le coin — la pointe saillante d'un rocher",
	"mb_arete": "DEUX cubes côte à côte — l'arête droite d'une falaise",
	"mb_diagonale": "deux cubes en diagonale DANS UNE FACE — ils ne se touchent que par une arête",
	"mb_equerre": "TROIS cubes en L — un coin de plateau",
	"mb_plaque": "QUATRE cubes coplanaires — LE SOL PLAT, LE MUR PLAT, LE PLAFOND PLAT",
	"mb_trepied": "trois cubes deux à deux en diagonale — trois pointes qui s'effleurent",
	"mb_tetra": "quatre cubes : un coin et ses trois voisins — un angle plein",
	"mb_pointe": "deux cubes en diagonale DU CORPS — ils ne se touchent que par un POINT",
	"mb_biais": "trois cubes, dont deux en diagonale — une marche de biais",
	"mb_vrille_g": "quatre cubes en hélice à gauche — la matière tourne sur elle-même",
	"mb_vrille_d": "quatre cubes en hélice à droite — le miroir de la précédente",
	"mb_crochet": "quatre cubes en crochet",
	"mb_equerre_creuse": "cinq cubes — le creux en L, l'intérieur d'un coin de salle",
	"mb_chicane": "deux barres croisées — elles ne se touchent que par des arêtes",
	"mb_biais_creux": "cinq cubes — le biais vu de l'intérieur",
	"mb_arete_creuse": "six cubes — l'arête rentrante, le coin intérieur d'un mur",
	"mb_damier": "quatre cubes en damier — SIX faces ambiguës, le cas le plus dur du modèle",
	"mb_trepied_creux": "cinq cubes — le trépied vu de l'intérieur",
	"mb_diagonale_creuse": "six cubes — la diagonale vue de l'intérieur",
	"mb_pointe_creuse": "six cubes — deux vides qui ne se touchent que par un point",
	"mb_coin_creux": "sept cubes — UN SEUL vide, la niche creusée dans la roche",
}


func _initialize() -> void:
	print("=== L'INVENTAIRE DES FORMES ===\n")

	var frequence: Dictionary = _compter_le_monde()
	var dans_bloc: Dictionary = _qui_livre_quoi()

	# ── CHAQUE TUILE, AVEC CE QU'ON SAIT D'ELLE ─────────────────────────────────────────────────────
	var lignes: Array = []
	for c in MB.classes():
		if not MB.porte_une_surface(c["bits"]):
			continue
		var bits: int = c["bits"]
		var contextes: Array = [false]
		if MB.exterieur_possible(bits):
			contextes.append(true)
		for dehors in contextes:
			var nom: String = MB.nom_en_contexte(c["nom"], dehors)
			lignes.append({
				"nom": nom,
				"famille": _famille(c["nom"]),
				"cubes": _compter_bits(bits),
				"bas": _compter_couche(bits, MB.BAS),
				"haut": _compter_couche(bits, MB.HAUT),
				"dehors": dehors,
				"diagonal": not MB.sans_contact_diagonal(bits),
				"vus": int(frequence.get(nom, 0)),
				"bloc": dans_bloc.get(nom, -1),
			})

	lignes.sort_custom(func(a, b):
		if a["vus"] != b["vus"]:
			return a["vus"] > b["vus"]
		if a["cubes"] != b["cubes"]:
			return a["cubes"] < b["cubes"]
		return a["nom"] < b["nom"])

	_imprimer("LES FORMES SANS CONTACT DIAGONAL — celles qui ont de la matière continue à sculpter",
		lignes.filter(func(l): return not l["diagonal"]))
	_imprimer("LES FORMES À CONTACT DIAGONAL — la matière y est pincée sur une arête ou un point",
		lignes.filter(func(l): return l["diagonal"]))

	# ── LE BILAN ────────────────────────────────────────────────────────────────────────────────────
	var simples: Array = lignes.filter(func(l): return not l["diagonal"])
	var manquantes: Array = simples.filter(func(l): return int(l["bloc"]) != 0)
	print("── CE QU'IL RESTE À AJOUTER AU TÉMOIN INTUITIF ──")
	print("   %d tuiles sans contact diagonal, dont le bloc 0 en livre %d"
		% [simples.size(), simples.size() - manquantes.size()])
	print("   il en manque %d :" % manquantes.size())
	for l in manquantes:
		print("      %-34s %s" % [l["nom"], _forme(l)])
	print("")
	print("   et %d tuiles à CONTACT DIAGONAL, qui restent pour le témoin d'érosion."
		% lignes.filter(func(l): return l["diagonal"]).size())
	print("\n⚠ Cette sonde compte et décrit ; elle ne dit pas ce qui est facile à modeler.")
	quit(0)


func _imprimer(titre: String, lignes: Array) -> void:
	print("── %s ── (%d)" % [titre, lignes.size()])
	print("   %-34s %5s  %-9s %s" % ["tuile", "posée", "bloc", "la forme"])
	for l in lignes:
		var ou: String = "—" if int(l["bloc"]) < 0 else ("bloc %d" % l["bloc"])
		print("   %-34s %5d  %-9s %s" % [l["nom"], l["vus"], ou, _forme(l)])
	print("")


## La forme en mots : la description de famille, plus la répartition bas/haut, qui est ce qui distingue
## un SOL d'un MUR d'un PLAFOND dans le modèle ORIENTÉ.
func _forme(l: Dictionary) -> String:
	var dit: String = DITS.get(l["famille"], "?")
	var couche: String = "%d en bas, %d en haut" % [l["bas"], l["haut"]]
	var air: String = "  ·  À L'AIR LIBRE" if l["dehors"] else ""
	return "%s  (%s)%s" % [dit, couche, air]


## ⚠ **LA COUPE SE FAIT AU `_b` SUIVI D'UN CHIFFRE, ET LE `rfind` NAÏF S'EST TROMPÉ.** Un nom comme
## `mb_equerre_b1h2_b` porte DEUX `_b` : celui du compte de couche et celui qui distingue deux
## représentants d'une même famille. Chercher le DERNIER rendait la famille « mb_equerre_b1h2 »,
## absente du vocabulaire, et la sonde imprimait « ? » sur six formes bien nommées.
func _famille(nom: String) -> String:
	for i in nom.length() - 2:
		if nom[i] == "_" and nom[i + 1] == "b" and nom[i + 2] >= "0" and nom[i + 2] <= "9":
			return nom.substr(0, i)
	return nom


func _compter_bits(bits: int) -> int:
	var n := 0
	for t in 8:
		if bits & (1 << t):
			n += 1
	return n


func _compter_couche(bits: int, couche: Array) -> int:
	var n := 0
	for t in couche:
		if bits & (1 << t):
			n += 1
	return n


## COMBIEN DE FOIS CHAQUE TUILE EST POSÉE DANS LE MONDE PEINT DE JORDAN.
##
## ⚠ **ON LIT LE MONDE, PAS UNE GÉNÉRATION.** Un paysage fabriqué pour la mesure dirait ce que son
## générateur aime, pas ce que Jordan peint. Si la scène manque, on le DIT et on rend zéro partout —
## un tableau de fréquences inventées serait pire qu'un tableau vide.
func _compter_le_monde() -> Dictionary:
	var frequence := {}
	var paquet: PackedScene = load(SCENE)
	if paquet == null:
		print("⚠ %s introuvable — la colonne « posée » sera vide.\n" % SCENE)
		return frequence
	var racine: Node = paquet.instantiate()
	var grilles: Array = []
	_trouver(racine, grilles)
	var pleines := {}
	for g in grilles:
		for c in (g as GridMap).get_used_cells():
			pleines[c as Vector3i] = true
	if pleines.is_empty():
		print("⚠ le monde est vide — la colonne « posée » sera vide.\n")
		racine.free()
		return frequence

	var mini := Vector3i(2147483647, 2147483647, 2147483647)
	var maxi := Vector3i(-2147483648, -2147483648, -2147483648)
	for c in pleines:
		var p: Vector3i = c
		mini = Vector3i(mini(mini.x, p.x), mini(mini.y, p.y), mini(mini.z, p.z))
		maxi = Vector3i(maxi(maxi.x, p.x), maxi(maxi.y, p.y), maxi(maxi.z, p.z))
	var plafond: int = MB.plafond_de(pleines)
	# ⚠ On balaie UNE case au-delà de la matière : un sommet du bord porte le sol vu du dessus, qui est
	# précisément la tuile la plus posée. S'arrêter à la matière l'effacerait du décompte.
	for x in range(mini.x - 1, maxi.x + 1):
		for y in range(mini.y - 1, maxi.y + 1):
			for z in range(mini.z - 1, maxi.z + 1):
				var v := Vector3i(x, y, z)
				var bits: int = MB.bits(pleines, v)
				if not MB.porte_une_surface(bits):
					continue
				var r: Dictionary = MB.classer(bits)
				var dehors: bool = MB.exterieur_possible(bits) \
					and MB.sous_le_ciel(pleines, v, plafond)
				var nom: String = MB.nom_en_contexte(r["nom"], dehors)
				frequence[nom] = int(frequence.get(nom, 0)) + 1
	print("monde peint : %d cases, %d pièces posées\n"
		% [pleines.size(), _somme(frequence)])
	racine.free()
	return frequence


## QUEL BLOC MAÎTRE LIVRE QUELLE TUILE — par le vrai trancheur, jamais par une règle recopiée.
func _qui_livre_quoi() -> Dictionary:
	var Tranchage := load("res://addons/marching_blocks_plugin_godot/tranchage.gd")
	var ou := {}
	for i in BM.nombre():
		var fautes: Array = []
		var r: Dictionary = Tranchage.trancher(BM.maillage_moitie(i), Vector3i.ONE * BM.COTE, 1.0,
			BM.creuses(i), fautes, false)
		for nom in r:
			if not ou.has(nom):
				ou[nom] = i
	return ou


func _trouver(n: Node, sortie: Array) -> void:
	if n is GridMap and n.name == "Cases":
		sortie.append(n)
	for e in n.get_children():
		_trouver(e, sortie)


func _somme(d: Dictionary) -> int:
	var n := 0
	for k in d:
		n += int(d[k])
	return n
