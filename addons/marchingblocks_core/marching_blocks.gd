@tool
extends RefCounted
## MARCHING BLOCKS — le classificateur. Huit cellules → une classe et une orientation.
##
## **LE NOM** — *Marching Cubes* (Lorensen & Cline, 1987) marche sur une grille et FABRIQUE une
## isosurface lisse. *Marching Blocks* marche sur la même grille et va chercher la matière DANS UN BLOC
## SCULPTÉ. Même classification, géométrie opposée : l'une est générée, l'autre est taillée.
##
## ⚠ CE FICHIER NE CONNAÎT NI MESH, NI GRIDMAP, NI NŒUD. Il ne fait que classer des entiers. C'est ce
## qui le rend testable sans écran (charte §6) et portable tel quel vers un autre moteur.
##
## ── LE MODÈLE ───────────────────────────────────────────────────────────────────────────────────────
##
## Une pièce est centrée sur un SOMMET du réseau, au coin de huit cellules. Ces huit cellules, pleines
## ou vides, font 2⁸ = 256 configurations. On les replie par ROTATION : deux configurations qui ne
## diffèrent que par une rotation partagent le même mesh, que le GridMap tourne à la pose.
##
## ⚠ MESURÉ (`DEV_TOOLS/sonde_orientations_gridmap.gd`, 105 vérifications, 0 échec) : les 24 index
## orthogonaux d'un GridMap SONT les 24 rotations propres du cube — distinctes, de déterminant +1,
## fidèles à l'aller-retour. Sans cette mesure, tout ce fichier serait un pari.
##
## ── LE GROUPE EST UN RÉGLAGE, ET C'EST LA DÉCISION LA PLUS LOURDE DU GREFFON ─────────────────────────
##
## **DÉCIDÉ (Jordan, 19 septembre 2026) — on prend `oriente`.** Sa raison, mot pour mot : *« c'est une
## liberté trop importante à l'artiste de différencier le haut, le milieu et le bas de son art. »*
##
## Replier par les 24 rotations donne le lot le plus petit — mais il est AVEUGLE À LA GRAVITÉ : le même
## sculpt sert de sol, de mur ET de plafond, puisque rien n'empêche le GridMap de le coucher. Plus
## d'herbe sur le dessus, plus de lèvre de falaise, plus de strates qui coulent. C'est exactement ce que
## les trois bandes `pied / milieu / dessus` du modèle 2D portaient, et que le repli complet niait.
##
##   groupe       |G|  classes  à sculpter  ce qu'il permet
##   ------------ ---  -------  ----------  ------------------------------------------------------
##   "libre"       24    23         21      rien d'orienté : sol = mur = plafond
##   "vertical"     8    43         41      le mur se distingue, mais le plafond est le sol retourné
##   "oriente"      4    70         68      sol ≠ mur ≠ plafond — le haut existe   ← DÉFAUT
##
## ⚠ MESURÉ, ET C'EST UNE JOLIE BOUCLE : le filtre « garde le haut » rend exactement les index
## [0, 10, 16, 22] — les QUARTS que le modèle 2D employait déjà, du temps où le projet portait un jeu en
## deux dimensions. Le modèle orienté EST la grille duale 2D, remontée en 3D : rien n'a été renié, tout
## a été généralisé.
##
## ⚠ MESURÉ AUSSI (Burnside, vérifié sur les trois groupes) : 23, 43 et 70 orbites. Et pour le groupe
## retenu, orbite × stabilisateur = 4 sur les 70 sans exception.

## ── LE CONTRAT DE BITS, ET C'EST UN CONTRAT ─────────────────────────────────────────────────────────
##
## Le bit `t` désigne la cellule décalée de `COINS[t]` par rapport au sommet, avec t = x + 2y + 4z.
## ⚠ **Y EST LE HAUT** — et depuis qu'on est en modèle orienté, ce n'est plus une convention indifférente :
## c'est l'axe autour duquel le groupe tourne, et celui qui sépare le `bas` du `haut` d'une classe.
const COINS := [
	Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0),
	Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 1, 1), Vector3i(1, 1, 1),
]

## Les quatre cellules du BAS (y = 0) et celles du HAUT (y = 1).
## ⚠ Invariantes sous le groupe orienté — c'est ce qui permet de nommer une classe par son couple
## (bas, haut), et ce qui donne un sens au mot « bande ».
const BAS := [0, 1, 4, 5]
const HAUT := [2, 3, 6, 7]

## Les 24 rotations du cube : permutation des huit coins, et index d'orientation du GridMap.
## ⚠ TABLE MESURÉE, PAS RECOPIÉE — `test_marching_blocks.gd` la REMESURE contre un vrai GridMap.
const ROTATIONS := [
	{"coins": [0, 1, 2, 3, 4, 5, 6, 7], "index": 0},
	{"coins": [1, 3, 0, 2, 5, 7, 4, 6], "index": 1},
	{"coins": [3, 2, 1, 0, 7, 6, 5, 4], "index": 2},
	{"coins": [2, 0, 3, 1, 6, 4, 7, 5], "index": 3},
	{"coins": [2, 3, 6, 7, 0, 1, 4, 5], "index": 4},
	{"coins": [0, 2, 4, 6, 1, 3, 5, 7], "index": 5},
	{"coins": [1, 0, 5, 4, 3, 2, 7, 6], "index": 6},
	{"coins": [3, 1, 7, 5, 2, 0, 6, 4], "index": 7},
	{"coins": [6, 7, 4, 5, 2, 3, 0, 1], "index": 8},
	{"coins": [4, 6, 5, 7, 0, 2, 1, 3], "index": 9},
	{"coins": [5, 4, 7, 6, 1, 0, 3, 2], "index": 10},
	{"coins": [7, 5, 6, 4, 3, 1, 2, 0], "index": 11},
	{"coins": [4, 5, 0, 1, 6, 7, 2, 3], "index": 12},
	{"coins": [5, 7, 1, 3, 4, 6, 0, 2], "index": 13},
	{"coins": [7, 6, 3, 2, 5, 4, 1, 0], "index": 14},
	{"coins": [6, 4, 2, 0, 7, 5, 3, 1], "index": 15},
	{"coins": [4, 0, 6, 2, 5, 1, 7, 3], "index": 16},
	{"coins": [5, 1, 4, 0, 7, 3, 6, 2], "index": 17},
	{"coins": [7, 3, 5, 1, 6, 2, 4, 0], "index": 18},
	{"coins": [6, 2, 7, 3, 4, 0, 5, 1], "index": 19},
	{"coins": [2, 6, 0, 4, 3, 7, 1, 5], "index": 20},
	{"coins": [0, 4, 1, 5, 2, 6, 3, 7], "index": 21},
	{"coins": [1, 5, 3, 7, 0, 4, 2, 6], "index": 22},
	{"coins": [3, 7, 2, 6, 1, 5, 0, 4], "index": 23},
]

## Le MIROIR : on échange x et son opposé. ⚠ C'est une réflexion, donc précisément ce qu'un GridMap NE
## SAIT PAS poser. Sert à DÉDUIRE la chiralité, jamais à poser.
const MIROIR := [1, 0, 3, 2, 5, 4, 7, 6]

## Le groupe employé à la pose. Voir le tableau en tête de fichier.
const GROUPE := "oriente"

## ── LES NOMS DES 23 FAMILLES ────────────────────────────────────────────────────────────────────────
##
## Une FAMILLE est une classe du repli complet (les 24 rotations) : c'est la SILHOUETTE, indépendamment
## de son orientation dans le monde. En modèle orienté, chaque famille éclate en plusieurs classes —
## 3,0 en moyenne, jusqu'à 6 pour les familles biaisées.
##
## La clé est le représentant canonique de la famille : la configuration de plus petit numéro de son
## orbite sous les 24 rotations. ⚠ C'est la SEULE chose encore écrite à la main dans ce fichier, et
## `anomalies()` rend bruyante toute faute — une famille sans nom, un nom qui ne désigne rien.
##
## ⚠ CES VINGT-TROIS CLÉS ONT ÉTÉ VÉRIFIÉES PAR LE CALCUL (représentants dérivés, aucun manquant, aucun
## orphelin). La version précédente de ce fichier en déclarait quatre de faux — 42 configurations sans
## réponse — pour la seule raison que je les avais tapées.
const NOMS := {
	0: "mb_vide",                 # n=0 — aucune surface
	1: "mb_coin",                 # n=1 — un coin extérieur
	3: "mb_arete",                # n=2 voisines — l'arête droite
	6: "mb_diagonale",            # n=2 en diagonale de face
	7: "mb_equerre",              # n=3 en L
	15: "mb_plaque",              # n=4 coplanaires — le SOL PLAT et le MUR PLAT
	22: "mb_trepied",             # n=3 deux à deux en diagonale
	23: "mb_tetra",               # n=4 — un coin et ses trois voisines
	24: "mb_pointe",              # n=2 en diagonale de CORPS
	25: "mb_biais",               # n=3
	27: "mb_vrille_g",            # n=4 — la vrille gauche
	29: "mb_vrille_d",            # n=4 — la vrille droite, miroir de la précédente
	30: "mb_crochet",             # n=4
	31: "mb_equerre_creuse",      # n=5
	60: "mb_chicane",             # n=4 — deux barres qui se croisent
	61: "mb_biais_creux",         # n=5
	63: "mb_arete_creuse",        # n=6
	105: "mb_damier",             # n=4 — six faces ambiguës, le cas le plus dur
	107: "mb_trepied_creux",      # n=5
	111: "mb_diagonale_creuse",   # n=6
	126: "mb_pointe_creuse",      # n=6
	127: "mb_coin_creux",         # n=7
	255: "mb_plein",              # n=8 — le ventre plein, aucune surface
}

## ── LE VOCABULAIRE DES FACES — le contrat de couture ─────────────────────────────────────────────────
##
## **LA CONDITION DE COUTURE (Jordan, 19 septembre 2026) :** deux pièces voisines partagent une face,
## portée par EXACTEMENT les quatre cellules communes aux deux. Donc —
##
##   ⚠ LE PROFIL DE MATIÈRE SUR UNE FACE NE DÉPEND QUE DE LA CONFIGURATION DE SES QUATRE CELLULES.
##     Ni de la classe d'où la pièce vient, ni de l'endroit du bloc où elle a été taillée, ni de
##     l'orientation qu'on lui a donnée.
##
## ⚠ MESURÉ EXHAUSTIVEMENT : sur les 3 × 4096 façons de remplir les douze cellules que deux pièces
## voisines se partagent, la face que l'une présente est TOUJOURS celle que l'autre présente.
##
## ⚠ ET LA CONDITION PORTE SUR UNE BANDE, PAS SUR UN PLAN — corrigé par Jordan. J'avais écrit « le
## relief s'aplatit en approchant du plan de coupe » : trop DUR (un biseau peut traverser, il doit
## seulement ne pas CHANGER en traversant) et trop FAIBLE (une condition sur le seul plan garantit
## l'absence de TROU, pas celle de PLI). La bonne formulation :
##
##   ⚠ DANS UNE BANDE MINCE DE PART ET D'AUTRE DE CHAQUE PLAN DE COUPE, LA MATIÈRE EST LA MÊME DES
##     DEUX CÔTÉS — et ce germe ne dépend que de la configuration des quatre cellules.
##
## Pourquoi la symétrie est obligatoire : une même face sert tantôt de côté MOINS, tantôt de côté PLUS.
## La pièce en `v` présente sa face `+x`, sa voisine en `v + x` présente sa face `−x`, et les deux lisent
## les MÊMES quatre cellules. Le germe doit marcher dans les deux sens. Un plan plat vérifie cela
## trivialement — ce qui masquait la vraie condition. Une bosse SYMÉTRIQUE la vérifie aussi.
##
## D'où : **PSEUDO-CUBIQUE = LIBRE au cœur des cellules, SYMÉTRIQUE ET CANONIQUE dans la bande de couture.**
##
## ⚠ COMBIEN DE GERMES À DESSINER ? En modèle libre, 6 (les six formes ci-dessous). **En modèle orienté,
## 28** — car un germe de SOL et un germe de MUR ne sont plus la même chose : 12 sur les faces
## horizontales, 16 sur les verticales. C'est le prix de l'orientation sur la bordure, et il reste
## raisonnable : le sculpteur dessine 28 bordures, pas 70.
const FORMES_DE_FACE := ["rien", "coin", "mur", "diagonale", "rentrant", "plein"]

## Les quatre coins d'une face, EN ORDRE CYCLIQUE — c'est ce qui distingue deux cellules voisines
## (`mur`) de deux cellules opposées (`diagonale`). Un ordre non cyclique les confondrait.
const FACES := [
	{"nom": "x-", "coins": [0, 2, 6, 4]},
	{"nom": "x+", "coins": [1, 3, 7, 5]},
	{"nom": "y-", "coins": [0, 1, 5, 4]},
	{"nom": "y+", "coins": [2, 3, 7, 6]},
	{"nom": "z-", "coins": [0, 1, 3, 2]},
	{"nom": "z+", "coins": [4, 5, 7, 6]},
]

## L'épaisseur de la BANDE DE COUTURE, en fraction de cellule, de part et d'autre du plan de coupe.
## **PROPOSÉ, PAS MESURÉ.** Le relief d'un bloc pseudo-cubique a une échelle de 0,1 à 0,3 cellule ; une
## bande de 0,08 tient à l'intérieur du plus petit accident. ⚠ À recaler sur un vrai bloc sculpté :
## trop mince, on laisse passer un pli ; trop épaisse, on refuse des blocs valides.
const EPAISSEUR_DE_COUTURE := 0.08

## ── LES TUILES DE RUN (Jordan, 19 septembre 2026) ───────────────────────────────────────────────────
##
## Une tuile de run se raccorde à ELLE-MÊME : la pièce en `v` présente sa face `z+`, sa copie en `v + z`
## présente sa face `z−`, et ces deux faces lisent les mêmes quatre cellules. D'où :
##
##   ⚠ LE RELIEF D'UNE TUILE DE RUN EST PÉRIODIQUE, DE PÉRIODE UNE CELLULE, DANS LA DIRECTION DU RUN.
##     Ce qui sort par une face rentre par la face opposée, AU MÊME ENDROIT.
##
## ⚠ ET CE N'EST PAS UNE RÈGLE DE PLUS : c'est le STABILISATEUR de la classe (`stabilisateur()`). La
## tuile de sol plat a ses faces latérales identifiées ; « elle se répète avec elle-même » EST cette
## symétrie. En modèle orienté, le sol plat et le mur plat sont deux classes DISTINCTES — c'est tout
## l'intérêt — et chacune a son propre stabilisateur.

## ⚠ LA SEULE DÉCISION D'AMBIGUÏTÉ DU GREFFON, ISOLÉE DANS UNE FONCTION D'UNE LIGNE.
##
## Une face `diagonale` se lit de deux façons : deux coins SÉPARÉS, ou un PONT. Le marching cubes
## classique attrape sa maladie ici — deux cubes voisins qui tranchent différemment laissent un TROU,
## et c'est toute la raison d'être de MC33. ⚠ MESURÉ : « face ambiguë » et « face de forme diagonale »
## sont la MÊME chose, les deux comptes coïncidant sur les 23 familles.
##
## DÉFAUT : jamais de pont — déjà la décision du modèle 2D, et elle y est mesurée bonne : deux massifs
## qui se touchent par un coin laissent le passage OUVERT, au rendu comme à la collision.
##
## ⚠ LA DÉCISION EST UNE CONSTANTE NOMMÉE, ET PAS UN `return false` PERDU DANS UNE FONCTION. Deux
## raisons, et la seconde est pratique : elle se lit d'un coup d'œil dans le fichier, et elle offre au
## banc de mutations un point d'ancrage UNIQUE. Noyée parmi les autres `return false` du fichier, la
## mutation ne s'appliquait plus — et une mutation qui ne s'applique pas se lit « le test ne l'attrape
## pas », le pire des faux négatifs.
const PONT_SUR_FACE_AMBIGUE := false


static func pont_sur_face_ambigue() -> bool:
	return PONT_SUR_FACE_AMBIGUE


# ── LA CONSTRUCTION — TOUT EST DÉRIVÉ, RIEN N'EST DÉCLARÉ ───────────────────────────────────────────

static var _table: Array = []
static var _classes: Array = []
static var _familles: Array = []
static var _actives: Array = []


## Une rotation garde-t-elle le HAUT ? (l'axe Y va sur +Y)
static func _garde_le_haut(coins: Array) -> bool:
	for t in 8:
		if ((int(coins[t]) >> 1) & 1) != ((t >> 1) & 1):
			return false
	return true


## Une rotation garde-t-elle l'axe Y VERTICAL ? (sens libre : le plafond est le sol retourné)
static func _garde_la_verticale(coins: Array) -> bool:
	if _garde_le_haut(coins):
		return true
	for t in 8:
		if ((int(coins[t]) >> 1) & 1) == ((t >> 1) & 1):
			return false
	return true


## Les rotations que le groupe courant autorise à la pose.
## ⚠ MESURÉ : pour « oriente », ce filtre rend exactement les index [0, 10, 16, 22] — les QUARTS que le
## modèle 2D employait déjà. Le modèle orienté EST la grille duale 2D remontée en 3D.
static func rotations_actives() -> Array:
	if not _actives.is_empty():
		return _actives
	var sortie: Array = []
	for r in ROTATIONS:
		match GROUPE:
			"oriente":
				if _garde_le_haut(r["coins"]):
					sortie.append(r)
			"vertical":
				if _garde_la_verticale(r["coins"]):
					sortie.append(r)
			_:
				sortie.append(r)
	_actives = sortie
	return _actives


## Construit les familles (repli complet), les classes (repli du groupe courant) et la table des 256.
##
## ⚠ LE PREMIER NON ATTRIBUÉ EST LE MINIMUM DE SON ORBITE, par construction : on parcourt les
## configurations dans l'ordre croissant, donc quand on en rencontre une sans classe, aucune plus petite
## n'est dans son orbite. C'est ce qui rend les représentants EXACTS sans qu'on les écrive — et c'est la
## correction d'une faute réelle, quatre représentants sur vingt-trois étaient faux quand je les ai
## saisis à la main.
static func _batir() -> void:
	if not _table.is_empty():
		return

	# 1. LES FAMILLES — repli par les 24 rotations. C'est la silhouette, sans orientation.
	var familles_de: Array = []
	familles_de.resize(256)
	var familles: Array = []
	for b in 256:
		if familles_de[b] != null:
			continue
		var f: int = familles.size()
		var orbite := 0
		for r in ROTATIONS:
			var t: int = _tourner(b, r["coins"])
			if familles_de[t] == null:
				familles_de[t] = f
				orbite += 1
		familles.append({
			"bits": b, "nom": NOMS.get(b, ""), "pleines": _compte(b),
			"orbite": orbite, "chirale": false,
		})
	for f in familles.size():
		familles[f]["chirale"] = familles_de[_tourner(familles[f]["bits"], MIROIR)] != f

	# 2. LES CLASSES — repli par le groupe courant, et la table des 256.
	var actives: Array = rotations_actives()
	var table: Array = []
	table.resize(256)
	var classes: Array = []
	for b in 256:
		if table[b] != null:
			continue
		var c: int = classes.size()
		var orbite := 0
		for r in actives:
			var t: int = _tourner(b, r["coins"])
			# ⚠ LE PREMIER ARRIVÉ GAGNE : c'est ce qui rend la table DÉTERMINISTE. Une configuration
			# symétrique est atteinte par plusieurs rotations ; sans cette règle, l'orientation
			# dépendrait de l'ordre de parcours, donc de rien.
			if table[t] == null:
				table[t] = {"classe": c, "orientation": r["index"]}
				orbite += 1
		var bas := 0
		for t in BAS:
			if b & (1 << t):
				bas += 1
		var haut := 0
		for t in HAUT:
			if b & (1 << t):
				haut += 1
		classes.append({
			"bits": b, "famille": familles_de[b], "pleines": _compte(b),
			"bas": bas, "haut": haut, "orbite": orbite, "nom": "", "chirale": false,
		})
	for c in classes.size():
		classes[c]["chirale"] = table[_tourner(classes[c]["bits"], MIROIR)]["classe"] != c

	# 3. LES NOMS — DÉRIVÉS. `mb_<famille>_b<bas>h<haut>`, plus un suffixe `_a`, `_b`… quand plusieurs
	#    classes d'une même famille partagent le même couple (bas, haut).
	#
	# ⚠ MESURÉ : 70 classes pour 52 couples, donc 12 collisions — toutes dans les familles biaisées
	# (`equerre`, `biais`, `crochet`, `chicane` et leurs creux). Le suffixe est attribué par bits
	# croissants, donc STABLE : le nom d'une classe ne changera jamais d'une exécution à l'autre.
	var par_base := {}
	for c in classes.size():
		var base: String = "%s_b%dh%d" % [familles[classes[c]["famille"]]["nom"],
			classes[c]["bas"], classes[c]["haut"]]
		if not par_base.has(base):
			par_base[base] = []
		par_base[base].append(c)
	for base in par_base:
		var liste: Array = par_base[base]
		if liste.size() == 1:
			classes[liste[0]]["nom"] = base
			continue
		for i in liste.size():
			classes[liste[i]]["nom"] = "%s_%s" % [base, String.chr("a".unicode_at(0) + i)]

	_familles = familles
	_table = table
	_classes = classes


## Applique une permutation de coins à une configuration.
## ⚠ LE SENS COMPTE : la cellule qui était en `t` se retrouve en `coins[t]`. C'est le sens qui fait que
## poser le mesh de référence avec l'orientation rendue REPRODUIT la configuration demandée.
static func _tourner(bits_config: int, coins: Array) -> int:
	var sortie := 0
	for t in 8:
		if bits_config & (1 << t):
			sortie |= 1 << int(coins[t])
	return sortie


static func _compte(bits_config: int) -> int:
	var n := 0
	for t in 8:
		if bits_config & (1 << t):
			n += 1
	return n


## Les 23 FAMILLES (repli complet) : [{bits, nom, pleines, orbite, chirale}].
static func familles() -> Array:
	_batir()
	return _familles


## Les CLASSES du groupe courant : [{bits, nom, famille, pleines, bas, haut, orbite, chirale}].
static func classes() -> Array:
	_batir()
	return _classes


## Une configuration porte-t-elle une surface ? ⚠ Le vide et le ventre plein n'en portent aucune —
## c'est la règle du VENTRE CREUX, qui fait qu'un massif coûte sa SURFACE et non son volume.
static func porte_une_surface(bits_config: int) -> bool:
	return bits_config != 0 and bits_config != 255


## LA FONCTION CENTRALE — huit cellules en huit bits, et ce qu'il faut poser.
##
## ⚠ ELLE NE REFUSE JAMAIS. Les 256 entrées ont une réponse : pas de configuration « illégale », pas de
## cube rouge géométrique, pas de zone irreprésentable. C'est l'invariant que le greffon vend — *peindre
## une case n'importe où produit toujours un résultat déterminé, complet et correct* — et il est vrai
## PAR CONSTRUCTION, pas par vigilance.
static func classer(bits_config: int) -> Dictionary:
	_batir()
	var b: int = bits_config & 0xFF
	var entree: Dictionary = _table[b]
	var classe: Dictionary = _classes[entree["classe"]]
	return {
		"classe": entree["classe"],
		"nom": classe["nom"],
		"famille": _familles[classe["famille"]]["nom"],
		"orientation": entree["orientation"],
		"surface": porte_une_surface(b),
	}


## Les huit cellules autour d'un sommet du réseau, en huit bits.
static func bits(pleines: Dictionary, sommet: Vector3i) -> int:
	var sortie := 0
	for t in 8:
		if pleines.has(sommet + COINS[t]):
			sortie |= 1 << t
	return sortie


## Les sommets touchés par une cellule peinte : ses huit coins.
## ⚠ Une cellule influe sur HUIT pièces, pas une. Oublier ce voisinage laisse des trous sur les bords.
static func sommets_de(cellule: Vector3i) -> Array:
	var sortie: Array = []
	for t in 8:
		sortie.append(cellule - COINS[t])
	return sortie


# ── LES SYMÉTRIES — ce que l'éditeur de blocs doit IMPOSER ──────────────────────────────────────────

## Le STABILISATEUR d'une classe : les index d'orientation des rotations ACTIVES qui laissent sa
## configuration inchangée. Rend toujours au moins `[0]`.
##
## ⚠ C'EST LA LISTE DES SYMÉTRIES QUE LE SCULPT DOIT RESPECTER. Si une rotation laisse la configuration
## inchangée mais change le mesh, deux faces portant la MÊME configuration présenteraient des germes
## DIFFÉRENTS — et le contrat de couture tombe.
static func stabilisateur(classe: int) -> Array:
	_batir()
	if classe < 0 or classe >= _classes.size():
		return []
	var reference: int = _classes[classe]["bits"]
	var sortie: Array = []
	for r in rotations_actives():
		if _tourner(reference, r["coins"]) == reference:
			sortie.append(r["index"])
	return sortie


## Les faces qu'un stabilisateur IDENTIFIE : les groupes de faces qui doivent porter le même germe.
##
## ⚠ C'est la liste que l'éditeur de blocs doit LIER : bouger un sommet d'une face doit bouger le sommet
## correspondant de toutes les faces de son groupe. C'est ainsi que la symétrie devient impossible à
## casser, au lieu d'être vérifiée après coup.
static func faces_identifiees(classe: int) -> Array:
	_batir()
	if classe < 0 or classe >= _classes.size():
		return []
	var reference: int = _classes[classe]["bits"]
	var groupes: Array = []
	var vues := {}
	for face in FACES:
		if vues.has(face["nom"]):
			continue
		var groupe := {}
		for r in rotations_actives():
			if _tourner(reference, r["coins"]) != reference:
				continue
			var image := {}
			for t in face["coins"]:
				image[int(r["coins"][int(t)])] = true
			for autre in FACES:
				var meme := true
				for t in autre["coins"]:
					if not image.has(int(t)):
						meme = false
						break
				if meme:
					groupe[autre["nom"]] = true
					break
		var liste: Array = groupe.keys()
		liste.sort()
		for nom in liste:
			vues[nom] = true
		groupes.append(liste)
	return groupes


## LES GERMES DE BORDURE à dessiner : les couples (face, configuration de ses quatre cellules), repliés
## par le groupe courant. Rend [{faces, forme, horizontal}].
##
## ⚠ EN MODÈLE LIBRE il y en a 6 — les six formes. EN MODÈLE ORIENTÉ il y en a 28, car un germe de SOL
## et un germe de MUR ne sont plus le même objet : 12 horizontaux, 16 verticaux. C'est le vrai cahier
## des charges de bordure du sculpteur, et il est bien plus petit que le nombre de pièces.
static func germes() -> Array:
	_batir()
	var vus := {}
	var sortie: Array = []
	for face in FACES:
		for m in 16:
			var pleins: Array = []
			var quatre: Array = []
			for i in 4:
				var plein: bool = (m & (1 << i)) != 0
				quatre.append(plein)
				if plein:
					pleins.append(int(face["coins"][i]))
			var cle := _cle_de_germe(face["coins"], pleins)
			if vus.has(cle):
				continue
			var combien := 0
			for r in rotations_actives():
				var f2: Array = []
				for t in face["coins"]:
					f2.append(int(r["coins"][int(t)]))
				var p2: Array = []
				for t in pleins:
					p2.append(int(r["coins"][t]))
				var autre := _cle_de_germe(f2, p2)
				if not vus.has(autre):
					vus[autre] = true
					combien += 1
			sortie.append({
				"faces": combien,
				"forme": forme_de_face(quatre),
				"horizontal": face["nom"] == "y-" or face["nom"] == "y+",
			})
	return sortie


static func _cle_de_germe(coins_face: Array, pleins: Array) -> String:
	var a: Array = coins_face.duplicate()
	a.sort()
	var b: Array = pleins.duplicate()
	b.sort()
	return "%s|%s" % [str(a), str(b)]


# ── LE CONTRAT DE COUTURE ───────────────────────────────────────────────────────────────────────────

## La forme 2D d'une face, d'après ses quatre cellules EN ORDRE CYCLIQUE.
static func forme_de_face(quatre: Array) -> String:
	var n := 0
	for q in quatre:
		if q:
			n += 1
	if n == 0:
		return "rien"
	if n == 1:
		return "coin"
	if n == 3:
		return "rentrant"
	if n == 4:
		return "plein"
	for i in 4:
		if quatre[i] and quatre[(i + 1) % 4]:
			return "mur"
	return "diagonale"


## Ce que chacune des six faces d'une configuration doit présenter. Rend [{nom, forme}, …].
## ⚠ C'EST LE CAHIER DES CHARGES DU SCULPTEUR, et la matière du vérificateur de bloc.
static func faces_de(bits_config: int) -> Array:
	var sortie: Array = []
	for face in FACES:
		var quatre: Array = []
		for t in face["coins"]:
			quatre.append((bits_config & (1 << int(t))) != 0)
		sortie.append({"nom": face["nom"], "forme": forme_de_face(quatre)})
	return sortie


## Le complément d'une configuration : matière et vide échangés.
## ⚠ Sert aux TESTS, jamais au rendu — échanger la matière et le vide n'est pas une transformation de
## mesh, et c'est pourquoi on ne peut pas descendre en dessous du nombre de classes.
static func complement(bits_config: int) -> int:
	return (~bits_config) & 0xFF


## Le nom d'une classe, par son numéro.
static func nom_de(classe: int) -> String:
	_batir()
	if classe < 0 or classe >= _classes.size():
		return ""
	return _classes[classe]["nom"]


## Toutes les classes qui portent une surface — le MODÈLE : 68 en groupe orienté.
static func classes_de_surface() -> Array:
	var sortie: Array = []
	for c in classes():
		if porte_une_surface(c["bits"]):
			sortie.append(c["nom"])
	return sortie


## Les pièces que l'artiste sculpte — les classes du MONDE, c'est-à-dire de surface ET sans contact
## diagonal : 35 en groupe orienté.
##
## ⚠ **ELLE RENDAIT LES 68 CLASSES DU MODÈLE JUSQU'AU 27 SEPTEMBRE 2026.** Le monde sans contact
## diagonal était DÉCIDÉ depuis deux jours (plus bas), mais cette fonction — que le témoin, le trancheur,
## l'écran et `anomalies()` lisent tous — parlait encore de l'ancien. Tant qu'elle disait 68, un témoin
## juste pour ce monde passait pour incomplet de 33 classes, et c'est ce qui obligeait à traîner un
## second bloc bourré de contacts diagonaux pour les fournir.
## ⚠ **UN MOT, UNE CHOSE (charte §6)** : « à sculpter » veut dire ce que l'artiste reçoit. Le modèle
## garde son nom à lui, `classes_de_surface()`.
static func pieces_a_sculpter() -> Array:
	var sortie: Array = []
	for c in classes():
		if porte_une_surface(c["bits"]) and sans_contact_diagonal(c["bits"]):
			sortie.append(c["nom"])
	return sortie


## Parmi les pièces à sculpter, celles qui ont AUSSI une variante d'air libre — 17. Le jeu complet que
## l'artiste reçoit compte donc `pieces_a_sculpter() + exterieures_a_sculpter()` = 35 + 17 = 52 tuiles.
static func exterieures_a_sculpter() -> Array:
	var sortie: Array = []
	for c in classes():
		if porte_une_surface(c["bits"]) and sans_contact_diagonal(c["bits"]) \
				and exterieur_possible(c["bits"]):
			sortie.append(c["nom"])
	return sortie


# ── LE CONTEXTE : UNE CLASSE PEUT-ELLE ÊTRE À L'AIR LIBRE ? ─────────────────────────────────────────
#
# ⚠ **LE CRITÈRE EST « Y A-T-IL DE LA ROCHE AU-DESSUS », ET IL A ÉTÉ CHOISI PAR MESURE, PAS PAR GOÛT.**
# Deux autres ont été essayés et écartés, et c'est écrit ici pour que personne ne les rouvre :
#
#   • **LE VIDE ENCLOS** (le vide communique-t-il avec le dehors ?) — sur un massif percé d'un tunnel
#     débouchant aux deux bouts, il déclare **0 case de tunnel sur 48** comme intérieure. On remettrait
#     de la paroi de falaise au fond d'une galerie : DISQUALIFIÉ.
#   • **L'OCCLUSION DU CIEL** (quelle fraction de ciel voit-on ?) — elle sépare bien un tunnel (3,5 %)
#     d'un surplomb (19,9 %), mais elle **n'est pas STABLE À L'ÉCHELLE** : 11 % des sommets changent de
#     contexte entre un bloc de 7³ et le même volume enrobé de roche. L'artiste sculpterait alors des
#     tuiles de grotte que le pinceau ne poserait jamais dans une grotte, **sans qu'aucune erreur ne le
#     signale** — la panne silencieuse exacte que ce projet paie en boucle. DISQUALIFIÉ.
#
# « Roche au-dessus » ne bouge **pas d'un sommet** (0 % mesuré) parce qu'il ne demande pas COMBIEN de
# roche il y a, seulement s'il y en a. Son défaut connu — le dessous d'un surplomb en plein air compte
# comme intérieur — est un choix d'art défendable (une roche à l'ombre, jamais lessivée), pas une panne.

## UNE CLASSE PEUT-ELLE APPARAÎTRE À L'AIR LIBRE ?
##
## ⚠ **L'INTÉRIEUR EST TOUJOURS POSSIBLE, donc il n'existe pas de fonction pour lui.** Il suffit
## d'ajouter de la roche plus haut, HORS du voisinage de huit : toute classe de surface peut vivre sous
## un toit. L'extérieur, lui, est contraint — et la contrainte est dans les bits eux-mêmes.
##
## Une case vide du BAS est *coiffée* si la case du HAUT juste au-dessus d'elle est pleine. Cette
## matière est DANS la configuration : on ne peut pas l'ôter, donc la classe ne peut pas être au ciel.
## ⚠ Les cases vides du HAUT, elles, ne contraignent rien : ce qui les couvre est hors du voisinage.
##
## ⚠ **INVARIANT PAR ROTATION, ET C'EST VÉRIFIÉ PLUTÔT QUE SUPPOSÉ** (`test_blocs_maitres.gd` le
## contrôle sur les 256 configurations) : le groupe orienté ne tourne qu'autour de Y, donc il envoie
## `BAS` sur `BAS` et préserve la relation « au-dessus ». Le verdict est donc une propriété de la
## CLASSE, et pas seulement de la configuration.
static func exterieur_possible(bits_config: int) -> bool:
	for t in BAS:
		var vide: bool = (bits_config & (1 << int(t))) == 0
		var coiffee: bool = (bits_config & (1 << (int(t) + 2))) != 0
		if vide and coiffee:
			return false
	return true


## Les classes de surface qui peuvent apparaître à l'air libre. Les autres n'existent qu'avec de la
## roche au-dessus : un plafond, un surplomb, une vrille ne se voient jamais sous le ciel.
##
## ⚠ L'ordre suit celui de `classes()`, donc il est stable d'un lancement à l'autre — une liste dont
## l'ordre changerait ferait bouger les identifiants du lot d'un lancement à l'autre.
##
## ⚠ MESURÉ : **22 sur les 68**, donc 46 sont structurellement intérieures. Un jeu à deux contextes
## demande **68 + 22 = 90 tuiles**, et non 2 × 68 = 136 comme je l'avais d'abord estimé. C'est aussi ce
## qui dit à l'artiste où va son travail : l'essentiel est du volume INTÉRIEUR, pas de la falaise.
static func classes_exterieures() -> Array:
	var sortie: Array = []
	for c in classes():
		if porte_une_surface(c["bits"]) and exterieur_possible(c["bits"]):
			sortie.append(c["nom"])
	return sortie


## ── LE CONTEXTE D'UN LIEU, ET LE NOM QUI EN DÉCOULE ────────────────────────────────────────────────
##
## ⚠ **`exterieur_possible()` PARLE D'UNE CLASSE, PAS D'UN ENDROIT.** Il dit qu'un plafond ne peut
## jamais être sous le ciel ; il ne dit pas si CE sommet-ci l'est. Il fallait donc le pendant côté
## lieu — et il vit ici, dans le module du modèle, parce que le TRANCHEUR et le PEINTRE s'en servent
## tous les deux. Deux copies de ce critère divergeraient, et ce projet a déjà payé cette faute trois
## fois (charte §6).
##
## ⚠ **UNE VARIANTE N'EXISTE QUE SI LES DEUX CONDITIONS TIENNENT** : la classe doit POUVOIR être
## dehors, et le lieu doit l'ÊTRE. Les 46 classes structurellement intérieures n'ont donc jamais de
## variante — d'où 68 + 22 = 90, et non 136.

## Ce qui distingue la tuile d'air libre de celle d'intérieur.
##
## ⚠ **C'EST LA VARIANTE QUI PORTE LE SUFFIXE, JAMAIS LE NOM NU** — et ce n'est pas une préférence
## d'écriture. Six appelants cherchent encore leur pièce par le nom de classe, et `test_massif_peint`
## compare sommet par sommet le nom posé au nom de la classe. Le nom nu reste donc l'item par défaut :
## un lot sans variantes — le repli procédural, un lot d'avant cette version — continue de fonctionner
## mot pour mot.
const SUFFIXE_DEHORS := "_dehors"


## Le nom de la tuile d'une classe dans un contexte donné.
# ── LE MONDE SANS CONTACT DIAGONAL — DÉCIDÉ (Jordan, 25 septembre 2026) ─────────────────────────────
#
# ⚠ **LA RÈGLE VIT ICI ET NULLE PART AILLEURS.** Trois appelants en dépendent — le vérificateur de bloc,
# les sondes, et le PINCEAU qui devra l'appliquer à chaque clic. La laisser dans une sonde l'aurait fait
# recopier trois fois, et « une seconde description d'un même fait diverge toujours » (charte §6).
#
# ⚠ **CE QU'ELLE ACHÈTE, MESURÉ** : 35 classes d'intérieur et 17 variantes au lieu de 68 et 22, soit
# **52 tuiles au lieu de 90** (−42 %) ; **18 germes à coudre au lieu de 22** ; et un témoin **manifold
# par construction** — les 33 classes en contact diagonal étaient la seule source d'arêtes à quatre
# faces, donc `PONT_SUR_FACE_AMBIGUE` n'a plus d'objet.
#
# ⚠ **CE QU'ELLE COÛTE AU MONDE, et c'est assumé** : plus aucun éperon qui se touche par une pointe,
# plus d'arête fine en diagonale, plus d'érosion en damier. Le vocabulaire du paysage s'appauvrit
# VOLONTAIREMENT — c'est le prix d'un témoin que l'artiste comprend.

## Une configuration est-elle atteignable dans un monde sans contact diagonal ?
##
## ⚠ Le critère est « aucune des six faces ne montre la forme `diagonale` », et il emploie
## `faces_de()` — la MÊME fonction qui définit les germes et le contrat de couture. Réécrire ici ce
## qu'est une diagonale ferait diverger la règle du pinceau et celle de la couture.
static func sans_contact_diagonal(bits_config: int) -> bool:
	for f in faces_de(bits_config):
		if f["forme"] == "diagonale":
			return false
	return true


## Les classes de surface qu'un tel monde peut produire. ⚠ DÉDUITES, jamais listées : le jour où le
## groupe de pose change, ce compte suit tout seul.
## ⚠ Depuis le 27 septembre 2026 ce sont exactement les pièces à sculpter : elle y renvoie plutôt que
## d'en garder une seconde description.
static func classes_sans_diagonale() -> Array:
	return pieces_a_sculpter()


## Les trois plans d'un carré 2×2, chacun donné par ses deux vecteurs de bord.
const PLANS_2X2 := [
	[Vector3i(1, 0, 0), Vector3i(0, 1, 0)],
	[Vector3i(1, 0, 0), Vector3i(0, 0, 1)],
	[Vector3i(0, 1, 0), Vector3i(0, 0, 1)],
]


## COMPLÈTE LES TROUS EN CARRÉS jusqu'à ce qu'aucun contact diagonal ne subsiste. Modifie `pleines` et
## rend le nombre de cases retirées EN PLUS du geste demandé.
##
## ⚠ **C'EST LA RÉPONSE DE JORDAN AU « TOUT ROUGE »** : « au lieu de mettre dans un état rouge quand un
## creusement n'est pas carré, on complète le trou pour qu'il soit carré ». Le pinceau ne refuse donc
## pas — il termine le geste.
## ⚠ **RETIRÉE LE 27 SEPTEMBRE 2026 (Jordan) : ON LAISSE LE ROUGE.** Le pinceau n'appelle PAS cette
## fonction ; une diagonale peinte pose un cube rouge. Elle reste pour les outils qui bâtissent un
## témoin (`verifier_bloc_unique.gd`), où compléter est un geste de l'outil et non une retouche de la
## peinture de quelqu'un.
##
## ⚠ **LE DÉCLENCHEUR EST LA DIAGONALE, PAS L'ADJACENCE.** Deux trous solo en (0,0) et (1,1) ne sont pas
## adjacents et produisent pourtant un contact diagonal ; une règle fondée sur l'adjacence les laisserait
## passer.
##
## ⚠ **ON NE FAIT QUE RETIRER, jamais ajouter — et c'est ce qui garantit la terminaison** : la matière
## est strictement décroissante et minorée. Boucher au lieu de creuser selon le cas rendrait la boucle
## non monotone, donc potentiellement sans fin.
##
## ⚠ **COÛT MESURÉ (25 septembre 2026)** : ×1,00 sur un puits, un tunnel 1×1, un tunnel 2×2 et une
## grotte 3×3×2 — la complétion ne se déclenche JAMAIS sur un geste contigu. Elle ne coûte que sur
## l'escalier délibérément diagonal (×2,67, 3 cases au pire clic), c'est-à-dire sur le geste que le monde
## interdit. Un chiffre de ×1,70 mesuré sur des creusements AU HASARD ne décrit aucun geste humain.
## ⚠ **`cote` REND LA BORNE EXPLICITE, ET CE N'EST PAS UN DÉTAIL — CE SONT DEUX QUESTIONS DIFFÉRENTES
## QUE J'AVAIS CONFONDUES (mesuré le 25 septembre 2026).** Sans borne, la règle lit l'absence de case
## comme du vide, y compris HORS de la grille, et répare donc des diagonales de BORDURE.
##
##   • `cote = 0` — le MONDE PEINT : l'extérieur est réellement de l'air, la bordure compte. C'est la
##     règle du pinceau.
##   • `cote = n` — un BLOC de n³ : ses faces extérieures sont des faces de SCIAGE, et la Convention (A)
##     ne récolte jamais ses sommets de bord. Y réparer une diagonale éroderait la silhouette de
##     l'artiste pour des sommets que le greffon ne lit pas.
##
## ⚠ La confusion s'est trahie d'elle-même : en déménageant la règle ici, la sonde est passée de 92 à
## 94 cases retirées sur le même tirage. Deux cases d'écart, et c'est ce qui a révélé que la fonction
## extraite ne répondait plus à la même question que l'originale.
static func completer_les_carres(pleines: Dictionary, cote: int = 0) -> int:
	var retirees := 0
	var encore := true
	while encore:
		encore = false
		var a_vider := {}
		for cle in pleines:
			var p: Vector3i = cle
			for plan in PLANS_2X2:
				for du in [0, -1]:
					for dv in [0, -1]:
						var o: Vector3i = p + plan[0] * du + plan[1] * dv
						var a: Vector3i = o
						var b: Vector3i = o + plan[0]
						var c: Vector3i = o + plan[1]
						var d: Vector3i = o + plan[0] + plan[1]
						# ⚠ **LES QUATRE COINS, PAS LES TROIS AXES** — même défaut, même correction que
						# dans `contacts_par_arete()` : le carré s'étend sur deux axes, le troisième est
						# fixe, et le borner excluait des carrés parfaitement intérieurs. Les deux
						# fonctions DOIVENT partager cette convention, sinon la réparation et le
						# compteur ne parlent pas du même monde.
						if cote > 0 and (a.x < 0 or a.y < 0 or a.z < 0
								or d.x > cote - 1 or d.y > cote - 1 or d.z > cote - 1):
							continue
						if not pleines.has(a) and not pleines.has(d) \
								and pleines.has(b) and pleines.has(c):
							a_vider[b] = true
							a_vider[c] = true
						elif not pleines.has(b) and not pleines.has(c) \
								and pleines.has(a) and pleines.has(d):
							a_vider[a] = true
							a_vider[d] = true
		for q in a_vider:
			pleines.erase(q)
			retirees += 1
			encore = true
	return retirees


static func nom_en_contexte(nom: String, dehors: bool) -> String:
	return (nom + SUFFIXE_DEHORS) if dehors else nom


## ── UNE TUILE PAR CLÉ (charte §3, Jordan, 30 septembre 2026) ─────────────────────────────────────
##
## ⚠ **LES « EXEMPLAIRES » ONT VÉCU ICI DU 27 AU 30 SEPTEMBRE 2026** : N morceaux par clé, nommés
## `<clé>~k`, tirés par un hachage de la position. Une falaise droite devenait une mosaïque de 30 morceaux
## découpés à 30 endroits du témoin — mesuré, et rien ne le justifiait. Une clé porte désormais UNE tuile,
## de nom nu, et le témoin lié en montre toutes les occurrences. La variété, si elle revient, reviendra en
## variantes VOULUES dont l'appli fige les sections.

## LA PURETÉ d'un sommet : combien des 64 cases qui l'entourent (décalages −1..2) diffèrent de sa propre
## configuration PROLONGÉE (chaque case copie la case de ses huit la plus proche). 0 = le milieu d'une
## forme sans rien autour ; plus c'est haut, plus un voisin a laissé sa trace dans la tuile.
## ⚠ **ELLE VIT DANS LE MODÈLE** — elle ne lit que les cases — parce que le trancheur (quel sommet livre la
## tuile d'une clé), le témoin lié (d'où vient une tuile) et l'écran (quelle copie montrer) la lisent tous.
static func purete(pleines: Dictionary, v: Vector3i) -> int:
	var n := 0
	for dx in range(-1, 3):
		for dy in range(-1, 3):
			for dz in range(-1, 3):
				var proche: Vector3i = v + Vector3i(clampi(dx, 0, 1), clampi(dy, 0, 1), clampi(dz, 0, 1))
				if pleines.has(v + Vector3i(dx, dy, dz)) != pleines.has(proche):
					n += 1
	return n


## ── LA RÈGLE DE POSE, EN UNE FONCTION PURE ────────────────────────────────────────────────────────
##
## **CE QUE LE PEINTRE POSE, POUR UNE COUCHE** : une entrée par sommet qui porte une surface —
## {"sommet", "nom" (la classe), "cle" (la clé choisie, "" si le lot ne l'a pas), "orientation" (index de
## GridMap), "dehors" (la variante d'air libre a été prise)}.
##
## ⚠ **ELLE EST LA RÉFÉRENCE DU FORMAT NEUTRE (charte §4, 27 septembre 2026).** Le peintre de l'appli
## l'appelle, et les CAS D'ÉPREUVE que les greffons Godot, Unity et Unreal doivent reproduire à
## l'identique sont calculés par elle. Elle vivait dans `massif_peint.gd`, mêlée aux `GridMap` : une
## référence qu'on ne peut pas appeler sans grille n'en est pas une.
##
## `cles` — {clé: …} : les clés que le lot porte (seule la PRÉSENCE compte). C'est TOUT ce qu'elle a
## besoin de savoir du lot.
## ⚠ La variante d'air libre d'abord, le nom nu ensuite (charte §9.4) ; une clé absente rend `cle = ""`,
## et c'est au peintre de poser son cube rouge.
static func poses(pleines: Dictionary, cles: Dictionary) -> Array:
	var sommets := {}
	for c in pleines:
		for s in sommets_de(c):
			sommets[s] = true
	var plafond: int = plafond_de(pleines)
	var sortie: Array = []
	for k in sommets:
		var sommet: Vector3i = k
		var b: int = bits(pleines, sommet)
		var r: Dictionary = classer(b)
		if not r["surface"]:
			continue
		var cle := ""
		var dehors := false
		if exterieur_possible(b) and sous_le_ciel(pleines, sommet, plafond):
			var variante: String = nom_en_contexte(r["nom"], true)
			if cles.has(variante):
				cle = variante
				dehors = true
		if cle == "" and cles.has(r["nom"]):
			cle = r["nom"]
		sortie.append({"sommet": sommet, "nom": r["nom"], "cle": cle,
			"orientation": r["orientation"], "dehors": dehors})
	return sortie


## Le nom de CLASSE d'une tuile, le suffixe d'air libre retiré. ⚠ C'est par là que les contrôles existants
## comparent ce qui est POSÉ à ce que les règles DISENT, sans être desserrés pour autant.
static func nom_nu(nom: String) -> String:
	return nom.trim_suffix(SUFFIXE_DEHORS)


## Ce sommet est-il sous le ciel ? `plafond` borne le balayage vers le haut.
##
## ⚠ **LA BORNE EST OBLIGATOIRE, ET CE N'EST PAS UN DÉTAIL.** Dans un BLOC, le volume s'arrête à `COTE`
## et la question a une réponse finie. Dans un MONDE PEINT, rien ne borne le ciel : l'appelant doit donc
## dire jusqu'où regarder, et le seul choix qui ne mente pas est **le plus haut sommet occupé** —
## au-dessus, il n'y a par définition aucune roche.
##
## ⚠ **ON SONDE LES HUIT COLONNES, MAIS TOUTES À PARTIR DU MÊME ÉTAGE — et c'est une correction.** La
## première version partait de `case.y + 1` pour chacune des huit cases. Or les cases du HAUT sont
## exactement « au-dessus » de celles du BAS : une classe dont la couche haute porte de la matière se
## déclarait donc **coiffée par sa propre configuration**. Elle s'auto-excluait.
##
## ⚠ **MESURÉ, ET C'EST CE QUI A COÛTÉ QUATRE TOURS DE RECHERCHE DANS LA MAUVAISE DIRECTION** : dans le
## voisinage le plus favorable qui soit — rien du tout au-dessus des huit cases — seules **5 des
## 22 classes extérieures** passaient. Les 17 autres, tous les `b2h2`, `b3h1`, `b2h1`, étaient hors
## d'atteinte quelle que soit la silhouette. J'ai cherché le défaut dans le dessin du témoin, puis dans
## le score du finisseur ; il était ici.
##
## ⚠ **LA RÈGLE JUSTE EST CELLE QUE `exterieur_possible()` APPLIQUE DÉJÀ** : *« les cases vides du HAUT
## ne contraignent rien : ce qui les couvre est HORS du voisinage »*. Le balayage commence donc à
## `sommet.y + 2` — au-dessus des deux étages de la pièce — pour les huit colonnes. Les deux fonctions
## parlent enfin du même monde : l'une contraint par les bits, l'autre par ce qui surplombe.
##
## Les huit colonnes restent sondées, et non la seule verticale du sommet : un surplomb décalé d'une
## case coiffe bien la pièce, et ne regarder qu'au centre le laisserait passer.
## ⚠ **ON NE SONDE QUE LES COLONNES VIDES — CORRIGÉ LE 26 SEPTEMBRE 2026, ET C'ÉTAIT UN DÉFAUT GRAVE.**
## La version précédente sondait les HUIT colonnes. Or quatre d'entre elles portent la matière de la
## pièce elle-même, et sur une falaise cette matière CONTINUE vers le haut : le sommet se déclarait
## donc « pas sous le ciel » parce que la falaise qu'il borde existe. Autrement dit, **le flanc de
## toute montagne recevait des tuiles de GROTTE, partout sauf à son sommet.**
##
## ⚠ **MESURÉ** (`DEV_TOOLS/sonde_sous_le_ciel.gd`) : sur une mesa de six cases de haut posée dans le
## vide, **73 sommets sur 218** passaient sous le ciel ; avec la règle juste, 169. Et sur le monde
## peint de Jordan, `mb_plaque_b2h2` — le mur d'INTÉRIEUR — était posé **1 605 fois** contre 282 pour
## sa variante d'air libre : 85 % des murs d'un paysage étaient des murs de grotte.
##
## ⚠ **ET VOILÀ POURQUOI IL A SURVÉCU SI LONGTEMPS : sur un relief d'UNE case, les deux règles donnent
## exactement le même résultat** (49 sommets sur 98, à l'identique). Le témoin livré a un relief d'une
## à deux cases — le défaut y était rigoureusement invisible. Il n'est apparu qu'en bâtissant un vrai
## paysage, et seulement à l'image.
##
## La question juste est : **le VIDE que borde cette pièce voit-il le ciel ?** Une colonne pleine ne
## dit rien du ciel ; seules les colonnes vides répondent.
##
## ⚠ **ELLE RESTE UN OUI-OU-NON, et c'est ce qui la sépare de l'occlusion** que la charte §2 a écartée :
## on ne demande toujours pas COMBIEN, donc aucun seuil, donc aucune dérive d'échelle. Seule la LISTE
## des colonnes a changé.
##
## ⚠ **CONTRÔLE QUI DEVAIT POUVOIR ROUGIR** : dans une salle entièrement close, la règle refuse
## **82 sommets sur 82**, comme l'ancienne. Une règle simplement plus laxiste aurait laissé fuir des
## sommets de grotte ; celle-ci n'en laisse aucun.
static func sous_le_ciel(pleines: Dictionary, sommet: Vector3i, plafond: int) -> bool:
	for t in 8:
		var base: Vector3i = sommet + COINS[t]
		if pleines.has(base):
			continue
		for y in range(sommet.y + 2, plafond + 1):
			if pleines.has(Vector3i(base.x, y, base.z)):
				return false
	return true


## Cette CASE est-elle sous de la roche ? `plafond` borne le balayage, comme pour `sous_le_ciel`.
##
## ⚠ **VOISINE DE `sous_le_ciel()`, MAIS DISTINCTE — ET IL FAUT LE DIRE, sinon on les confondra.**
## `sous_le_ciel` qualifie un **lieu de pose** : le sommet du réseau où une pièce ira. Celle-ci qualifie
## un **morceau de matière** : une case pleine, pour savoir de quelle couleur la peindre dans le témoin.
## L'une répond « quelle tuile poser ici », l'autre « à quoi ressemble cette roche ».
##
## ⚠ **ELLE VIT ICI ET NULLE PART AILLEURS.** Le mailleur en a besoin pour la légende du témoin, et
## l'écrire là-bas en ferait une SECONDE description du critère de contexte. Ce projet a déjà payé cette
## faute : le vérificateur du bloc calculait sa propre couverture, elle avait dérivé de celle du
## pinceau, et il a fallu quatre tours pour s'en apercevoir.
static func case_sous_roche(pleines: Dictionary, case: Vector3i, plafond: int) -> bool:
	for y in range(case.y + 1, plafond + 1):
		if pleines.has(Vector3i(case.x, y, case.z)):
			return true
	return false


## Cette FACE est-elle à l'air libre ? `case` est la case pleine qui la porte, `direction` le côté vers
## lequel elle regarde (un vecteur unitaire d'axe).
##
## ⚠ **C'EST LA LÉGENDE DU TÉMOIN, CORRIGÉE LE 27 SEPTEMBRE 2026 (Jordan : « oui »).** Elle colorait par
## CASE avec `case_sous_roche()` : toute case ayant de la roche au-dessus d'elle était souterraine. Sur
## une falaise, cette roche est la falaise elle-même — c'est exactement le défaut que `sous_le_ciel()`
## portait jusqu'au 26, resté dans la légende. Il ne s'y voyait pas ; le PBR espace monde l'a rendu
## flagrant : la paroi À L'AIR LIBRE (`mb_plaque_b2h2_dehors`) portait 135 couleurs de falaise et 135
## de grotte, et les falaises du monde peint sortaient RAYÉES toutes les deux cases.
##
## La question juste est la même que pour le lieu de pose : **le VIDE que borde cette face voit-il le
## ciel ?** Donc :
##   • une PAROI ou un SOL : le vide est `case + direction` ; à l'air libre si rien de plein n'est
##     au-dessus de lui dans sa colonne ;
##   • un PLAFOND : le vide est dessous, et au-dessus de lui il y a… la face elle-même. La question qui
##     reste est « la dalle est-elle sous le ciel ? » — dessous de surplomb contre plafond de grotte —,
##     c'est-à-dire `case_sous_roche()`, qui y répond déjà.
## ⚠ Un oui-ou-non, comme `sous_le_ciel()` : on ne demande pas COMBIEN de ciel (charte §2).
## ⚠ `vide` est la case vide bordée. C'est `case + direction` sur un solide brut ; sur l'aminci, une
## face sur huit borde en fait une autre case (`BlocsMaitres.vide_borde()`), d'où le paramètre.
static func face_sous_le_ciel(pleines: Dictionary, case: Vector3i, direction: Vector3i,
		vide: Vector3i, plafond: int) -> bool:
	if direction.y < 0:
		return not case_sous_roche(pleines, case, plafond)
	for y in range(vide.y + 1, plafond + 1):
		if pleines.has(Vector3i(vide.x, y, vide.z)):
			return false
	return true


## Le plus haut `y` occupé. ⚠ DÉRIVÉ de l'occupation, jamais déclaré : un plafond écrit en dur rendrait
## le contexte faux dès qu'on peint plus haut que prévu.
static func plafond_de(pleines: Dictionary) -> int:
	var haut := -2147483648
	for c in pleines:
		haut = maxi(haut, (c as Vector3i).y)
	return haut


## LES CONTACTS PAR ARÊTE SEULE d'une occupation : deux cellules DIAGONALES dans un plan, les deux
## complémentaires vides. Quatre faces se rejoignent alors sur l'arête commune, qui est donc
## **NON-MANIFOLD**.
##
## ⚠ **LE MODÈLE CONNAÎT DÉJÀ CE CAS SOUS UN AUTRE NOM** : c'est la face de forme `diagonale`, celle
## que `PONT_SUR_FACE_AMBIGUE` tranche — deux massifs qui ne se touchent que par un coin, et dont le
## projet a DÉCIDÉ qu'ils laissent le passage ouvert. Il est donc **parfaitement légal**, et il
## apparaîtra aussi dans les blocs que l'artiste sculptera. Ce n'est pas une faute à corriger en
## douce : c'est une propriété à CONNAÎTRE, et à éviter dans nos témoins.
##
## ⚠ **MESURÉ SUR LES NEUF BLOCS MAÎTRES, ET C'EST UNE IDENTITÉ — PAS UNE CORRÉLATION** : le nombre
## d'arêtes non-manifold du solide ÉGALE exactement ce compte. 19/19 sur « erosion 1 », 13/13 sur
## « erosion 2 », 13/13 sur « erosion 3 », et 0/0 sur les six blocs propres. La non-manifoldness est
## donc dans l'OCCUPATION, et **aucun mailleur ne la corrigera**.
##
## ⚠ Elle vit ICI et non dans une sonde : j'en avais deux copies en préparation dans deux outils, ce
## qui est exactement la divergence qui a frappé les deux règles de falaise de ce projet.
## ⚠ **`cote` PORTE LA MÊME CONVENTION QUE `completer_les_carres()`, et elle DOIT être la même.** Ce
## compteur était non borné : il lisait l'absence de case comme du vide, y compris hors du bloc, donc il
## comptait les contacts de BORDURE. Nettoyer un témoin en mode borné tout en testant avec ce compteur
## exigerait zéro contact que la réparation ne retire jamais — la recherche éroderait la silhouette ou
## ne convergerait pas. `cote = 0` garde le comportement d'origine (le monde peint), `cote = n` se
## restreint à l'intérieur d'un bloc de n³.
static func contacts_par_arete(pleines: Dictionary, cote: int = 0) -> int:
	var paires := [[0, 1], [0, 2], [1, 2]]
	var vus := {}
	var combien := 0
	for c in pleines:
		var cc: Vector3i = c
		for k in 3:
			var paire: Array = paires[k]
			var e1 := Vector3i.ZERO
			e1[int(paire[0])] = 1
			var e2 := Vector3i.ZERO
			e2[int(paire[1])] = 1
			# Les quatre carrés 2×2 de ce plan dont `cc` est l'un des coins. ⚠ Dédoublonnés : sans ça
			# chaque carré serait compté une fois par cellule pleine qu'il contient.
			for coin in [Vector3i.ZERO, -e1, -e2, -e1 - e2]:
				var p: Vector3i = cc + coin
				# ⚠ **ON BORNE LES QUATRE COINS DU CARRÉ, PAS LES TROIS AXES.** Un carré 2×2 vit dans un
				# PLAN : il s'étend sur deux axes, le troisième est fixe. Appliquer `< cote-1` aux trois
				# excluait tous les carrés de la dernière couche de l'axe fixe, donc des diagonales
				# parfaitement intérieures n'étaient pas comptées. Le finisseur a alors atteint **53
				# tuiles dans un monde qui n'en contient que 52** — un score au-dessus du maximum
				# théorique, qui a dénoncé la borne au lieu de passer inaperçu.
				var q: Vector3i = p + e1 + e2
				if cote > 0 and (p.x < 0 or p.y < 0 or p.z < 0
						or q.x > cote - 1 or q.y > cote - 1 or q.z > cote - 1):
					continue
				var cle := "%d,%d,%d,%d" % [p.x, p.y, p.z, k]
				if vus.has(cle):
					continue
				vus[cle] = true
				var a: bool = pleines.has(p)
				var b: bool = pleines.has(p + e1)
				var d: bool = pleines.has(p + e2)
				var e: bool = pleines.has(p + e1 + e2)
				if (a and e and not b and not d) or (b and d and not a and not e):
					combien += 1
	return combien


## ⚠ CE QUI NE VA PAS, DIT À VOIX HAUTE. La seule chose encore écrite à la main est la table des NOMS de
## famille : cette fonction rend bruyant ce qui, sinon, serait silencieux.
static func anomalies() -> Array:
	_batir()
	var erreurs: Array = []
	if _familles.size() != 23:
		erreurs.append("%d familles dérivées, il en faut 23" % _familles.size())
	for b in 256:
		if _table[b] == null:
			erreurs.append("la configuration %d n'a pas de réponse" % b)
	var canoniques := {}
	for f in _familles:
		canoniques[f["bits"]] = true
		if f["nom"] == "":
			erreurs.append("la famille de référence %d (%d cellules pleines) n'a pas de nom"
				% [f["bits"], f["pleines"]])
	for b in NOMS:
		if not canoniques.has(b):
			erreurs.append("« %s » nomme %d, qui n'est le représentant d'aucune famille" % [NOMS[b], b])
	var vus := {}
	for c in _classes:
		if c["nom"] == "":
			erreurs.append("la classe de référence %d n'a pas de nom" % c["bits"])
		elif vus.has(c["nom"]):
			erreurs.append("le nom « %s » est porté par deux classes" % c["nom"])
		vus[c["nom"]] = true
	return erreurs
