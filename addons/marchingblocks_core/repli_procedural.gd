@tool
extends RefCounted
## LE REPLI PROCÉDURAL — les 68 surfaces fabriquées par le calcul, sans un gramme d'art.
##
## ⚠ **C'EST L'ÉTAPE QUI REND L'INVARIANT VRAI.** Tant qu'elle n'existe pas, « peindre n'importe où
## produit toujours un résultat déterminé, complet et correct » est une promesse sur le papier : le
## classificateur sait DIRE quelle pièce poser, mais personne ne sait la FABRIQUER. À partir d'ici, on
## peint le monde entier avant d'avoir sculpté quoi que ce soit — et chaque classe sculptée remplace
## ensuite son repli, une à une, sans jamais interrompre la peinture.
##
## ── LA GÉOMÉTRIE : L'UNION DES OCTANTS ──────────────────────────────────────────────────────────────
##
## Le choix est dicté par le mot « pseudo-cubique », et par rien d'autre. Une pièce est un cube de côté
## 1 centré sur un sommet du réseau ; chacune des huit cellules qui l'entourent remplit **son octant**,
## le huitième de cube le plus proche du sommet. La surface est le bord de cette union.
##
##   ⚠ ON N'ÉMET QUE LES FACES INTÉRIEURES DONT LE VOISIN EST VIDE, JAMAIS LES FACES DE BORD.
##
## Et cette fois la vieille règle « on ne referme jamais la coupe » (`decoupe.gd`) est DÉMONTRÉE au lieu
## d'être postulée : un plan de coupe sépare toujours **deux octants de la MÊME cellule** — la pièce
## voisine reprend exactement où celle-ci s'arrête. Une cellule pleine l'est des deux côtés du plan, une
## cellule vide l'est des deux côtés. Il n'y a donc jamais de surface à mettre sur un plan de coupe, et
## y en mettre une dresserait un mur en pleine roche.
##
## ── CE QUE ÇA DONNE, ET C'EST VÉRIFIABLE À LA VIRGULE ───────────────────────────────────────────────
##
## Une face d'octant vaut 0,5 × 0,5 = 0,25. Une cellule seule (`mb_coin`) expose ses trois faces
## intérieures : **0,75**. Elle est vue par huit sommets, donc 8 × 0,75 = **6,0** — la surface exacte
## d'un cube unité. D'où l'invariant que le test vérifie sur des formes construites :
##
##   ⚠ Σ DES AIRES DES PIÈCES POSÉES = NOMBRE DE FACES DE CELLULES EXPOSÉES.
##
## Il attrape les deux pannes opposées d'un seul coup : une face oubliée (l'aire tombe) et une face de
## coupe rebouchée (l'aire monte). C'est le même esprit que l'invariant d'aire de `decoupe.gd`.
##
## ── LE CONTRAT DE COUTURE, SATISFAIT PAR CONSTRUCTION ───────────────────────────────────────────────
##
## Le germe d'une face n'est ici que le motif des quarts de carré présents sur ce plan — donc une
## fonction des quatre cellules de la face, et de rien d'autre. Et il est plat, donc trivialement le
## même des deux côtés. ⚠ Le repli procédural est ainsi le **témoin** du contrat : s'il craque, c'est le
## modèle qui est faux, pas l'art.
##
## ⚠ ET L'AMBIGUÏTÉ EST TRANCHÉE GÉOMÉTRIQUEMENT : sur une face `diagonale`, deux quarts de carré
## opposés ne se touchent qu'en un point. Aucun pont ne se forme — `MB.pont_sur_face_ambigue()` vaut
## `false`, et cette géométrie EST cette décision.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const Decoupe := preload("res://addons/marchingblocks_core/decoupe.gd")

## Le côté d'un octant, en fraction de cellule.
const OCTANT := 0.5

## ⚠ LES COULEURS DISENT LA BANDE, ET C'EST VOULU. Un placeholder doit se VOIR, et celui-ci doit en plus
## montrer d'un coup d'œil ce que le modèle orienté a acheté : le dessus, le plafond et la paroi ne sont
## plus la même chose. 46 des 70 classes portent une surface vers le haut — on doit le constater à
## l'image, pas seulement dans un tableau.
const COULEUR_DESSUS := Color("#6f9e4a")   # ce qui regarde le ciel
const COULEUR_PLAFOND := Color("#4e7ba8")  # ce qui regarde le sol : une grotte
const COULEUR_PAROI := Color("#8a7a68")    # les flancs

## ── LES SIX TEINTES DU TÉMOIN : trois orientations × deux contextes ─────────────────────────────────
##
## ⚠ **SIX TEINTES FRANCHES, ET C'EST UN CHOIX DE JORDAN CONTRE LE MIEN (25 septembre 2026).** J'avais
## MODULÉ les trois couleurs ci-dessus — la roche souterraine simplement assombrie — en craignant qu'un
## témoin à six couleurs devienne bariolé, donc moins lisible que le défaut qu'on corrigeait. Jordan a
## tranché pour le contraste, avec une légende écrite sous la vue : c'est elle qui lève mon objection,
## puisque chaque teinte y porte son nom au lieu de devoir être devinée.
##
## ⚠ **ET L'ASSOMBRISSEMENT SEUL NE POUVAIT PAS SUFFIRE**, c'est ce qui rend le choix de Jordan juste :
## la lumière directionnelle assombrit déjà les faces à l'ombre du même ordre. Une paroi de grotte et une
## paroi extérieure dans l'ombre se confondaient. Des TEINTES distinctes ne se confondent pas.
##
## ⚠ Les trois « dehors » restent les couleurs historiques : le repli procédural, qui n'a aucune notion
## de contexte, continue de les employer telles quelles.
const COULEUR_DESSUS_DEDANS := Color("#c9913f")   # un sol de GROTTE : ocre, jamais d'herbe
const COULEUR_PAROI_DEDANS := Color("#8a6f9e")    # une paroi de GROTTE : mauve, franchement autre
const COULEUR_PLAFOND_DEDANS := Color("#2f4f6f")  # un plafond de GROTTE : bleu profond

## ── LA LÉGENDE QUI VOYAGE DANS LE `.glb` ───────────────────────────────────────────────────────────
##
## ⚠ **UNE COULEUR DE SOMMET NE SUFFIT PAS À PORTER UNE LÉGENDE, ET C'EST MESURÉ (26 septembre 2026).**
## Le témoin exporté contenait bien ses six teintes (`COLOR_0` présent dans le fichier) et ressortait
## pourtant **entièrement blanc** — dans Godot comme dans un modeleur : le glTF sortait avec
## `materials: []` et une primitive sans matériau, et rien ne disait à quoi rattacher ces couleurs.
## La légende décidée le 25 septembre ne parvenait donc **pas** à l'artiste.
##
## ⚠ **LE REMÈDE EST UN MATÉRIAU NOMMÉ PAR TEINTE, et il vaut mieux que la couleur de sommet.** Le
## maillage exporté est séparé en six surfaces, chacune portant un matériau de sa couleur ET DE SON
## NOM. L'artiste ne voit plus seulement six couleurs à deviner : il lit « Wall — underground » dans sa
## liste de matériaux. C'est exactement ce que la légende devait faire, et ça survit à tout importeur.
##
## ⚠ **EN ANGLAIS, parce que c'est l'artiste qui les lit** (charte §7). Le reste du projet parle
## français ; ces six chaînes-là sortent du greffon et arrivent chez quelqu'un qui l'a acheté.
const TEINTES := [
	{"couleur": COULEUR_DESSUS, "nom": "Floor - open air"},
	{"couleur": COULEUR_PAROI, "nom": "Wall - open air"},
	{"couleur": COULEUR_PLAFOND, "nom": "Overhang - open air"},
	{"couleur": COULEUR_DESSUS_DEDANS, "nom": "Floor - underground"},
	{"couleur": COULEUR_PAROI_DEDANS, "nom": "Wall - underground"},
	{"couleur": COULEUR_PLAFOND_DEDANS, "nom": "Ceiling - underground"},
]


## Le nom de la teinte la plus proche d'une couleur. ⚠ **ON CHERCHE LA PLUS PROCHE, ON NE COMPARE PAS
## À L'IDENTIQUE** : une couleur ayant transité par un tableau de flottants ne revient pas toujours
## bit pour bit, et un test d'égalité rendrait alors une surface sans nom sans que rien ne le dise.
static func teinte_de(couleur: Color) -> Dictionary:
	var meilleure: Dictionary = TEINTES[0]
	var ecart := 1000.0
	for t in TEINTES:
		var c: Color = t["couleur"]
		var d: float = absf(c.r - couleur.r) + absf(c.g - couleur.g) + absf(c.b - couleur.b)
		if d < ecart:
			ecart = d
			meilleure = t
	return meilleure


## La surface d'une configuration. Rend un `ArrayMesh` — VIDE pour le vide et le ventre plein.
##
## ⚠ Le maillage est en coordonnées de PIÈCE : un cube de côté 1 centré sur l'origine. La cellule du
## bit `t` occupe l'octant du côté négatif ou positif de chaque axe selon `MB.COINS[t]` — 0 pour le
## côté négatif, 1 pour le positif. C'est le même repère ± que celui des rotations, donc tourner la
## configuration et tourner le maillage sont la même opération.
static func maillage(bits: int) -> ArrayMesh:
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var couleurs := PackedColorArray()

	for t in 8:
		if not (bits & (1 << t)):
			continue
		var coin: Vector3i = MB.COINS[t]
		for axe in 3:
			# ⚠ LE VOISIN DANS LA PIÈCE EST LE BIT OÙ L'ON A BASCULÉ CET AXE. Le bit `axe` de `t` EST la
			# coordonnée de cet axe (t = x + 2y + 4z), donc le voisin est `t` ou-exclusif (1 << axe).
			if bits & (1 << (t ^ (1 << axe))):
				continue  # voisin plein : la face est à l'intérieur de la matière, personne ne la voit
			var normale := Vector3.ZERO
			normale[axe] = 1.0 if coin[axe] == 0 else -1.0
			var autres: Array = []
			for k in 3:
				if k != axe:
					autres.append(k)
			var quad: Array = []
			for pas in [[0, 0], [0, 1], [1, 1], [1, 0]]:
				var p := Vector3.ZERO
				p[axe] = 0.0
				p[autres[0]] = _borne(coin[autres[0]], pas[0])
				p[autres[1]] = _borne(coin[autres[1]], pas[1])
				quad.append(p)
			_ajouter_quad(sommets, normales, couleurs, quad, normale)

	var mesh := ArrayMesh.new()
	if sommets.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = sommets
	arrays[Mesh.ARRAY_NORMAL] = normales
	arrays[Mesh.ARRAY_COLOR] = couleurs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, matiere())
	return mesh


## Une borne de l'octant sur un axe : `coord` dit de quel côté (0 négatif, 1 positif), `i` dit laquelle
## des deux bornes.
static func _borne(coord: int, i: int) -> float:
	if coord == 0:
		return -OCTANT if i == 0 else 0.0
	return 0.0 if i == 0 else OCTANT


## Pose un quadrilatère, en DEUX triangles, orienté vers `normale`.
##
## ⚠ ON NE FAIT PAS CONFIANCE À L'ORDRE DES COINS : on calcule la normale que l'enroulement produit et
## l'on retourne le quad s'il regarde du mauvais côté. Une convention de signe tenue à la main est
## exactement le genre de faute qui donne un lot à moitié retourné, visible seulement à l'image.
##
## ⚠ **GODOT ENROULE SES FACES AVANT DANS LE SENS HORAIRE**, et c'est l'inverse de la convention
## d'OpenGL. Le produit vectoriel de l'ordre stocké doit donc pointer **À L'OPPOSÉ** de la normale.
##
## ⚠ CE DÉFAUT A COÛTÉ UNE PLANCHE, ET AUCUN TEST NE POUVAIT L'ATTRAPER. Écrit dans l'autre sens, le
## maillage restait parfaitement COHÉRENT AVEC LUI-MÊME : l'aire juste, les positions justes, la normale
## d'accord avec son enroulement — les 3922 vérifications passaient et les huit mutations rougissaient.
## Seule la convention du MOTEUR divergeait, donc toutes les faces étaient des faces arrière, éliminées
## par le `cull_mode`. Sur l'image, le plateau apparaissait BLEU : on voyait à travers son dessus, et
## l'on apercevait les faces de plafond des pièces du dessous. C'est la quatrième fois que ce projet le
## vit — *seule une image l'a montré* (charte §6).
##
## ⚠ ET ON NE CORRIGE PAS EN DÉSACTIVANT LE CULLING : ce serait masquer le défaut et doubler le
## remplissage sur chaque pièce du monde.
static func _ajouter_quad(sommets: PackedVector3Array, normales: PackedVector3Array,
		couleurs: PackedColorArray, quad: Array, normale: Vector3) -> void:
	var a: Vector3 = quad[0]
	var b: Vector3 = quad[1]
	var c: Vector3 = quad[2]
	var obtenue: Vector3 = (b - a).cross(c - a)
	var ordre: Array = quad
	if obtenue.dot(normale) > 0.0:
		ordre = [quad[3], quad[2], quad[1], quad[0]]
	var couleur := _couleur(normale)
	for triangle in [[0, 1, 2], [0, 2, 3]]:
		for k in triangle:
			sommets.append(ordre[k])
			normales.append(normale)
			couleurs.append(couleur)


## ── LA TUILE EN FACES DIRECTES — la pente dérivée de la CLASSE, pas de la coque ─────────────────────
##
## ⚠ **C'EST LA DEMANDE DE JORDAN (25 septembre 2026)** : « trouve un moyen de supprimer l'angle et de
## faire une face directe ». Le témoin partait avec des escaliers parce que sa géométrie est une COQUE
## DE SOUS-VOXELS, qui ne sait émettre que des faces perpendiculaires aux axes.
##
## ⚠ **LA MÉTHODE ÉTAIT DÉJÀ ÉCRITE DANS LA CHARTE, et je ne l'avais pas vue** : « aucune opération
## locale ne peut remplacer une marche par une face directe sans franchir le plan de coupe… il faudrait
## faire dériver la pente de la CLASSE, pas de la coque ». La voici.
##
## La pièce est le cube [−OCTANT ; +OCTANT]³ centré sur le sommet ; **ses huit coins SONT les centres
## des huit cases**, puisque les plans de coupe passent par les centres. On pose un sommet au MILIEU de
## chaque arête dont les deux bouts diffèrent, on chaîne ces sommets en boucles fermées, et l'on
## triangule en éventail.
##
## ⚠ **AUCUNE TABLE DE 256 ENTRÉES.** C'est la construction habituelle, et ce projet a déjà payé quatre
## tables tapées à la main et fausses. Arêtes et faces sont DÉDUITES de `MB.COINS`.
##
## ⚠ **ET LA RÈGLE DE JORDAN EST CE QUI REND LA DÉRIVATION POSSIBLE.** Une face porte 4 arêtes coupées
## quand son motif ALTERNE — c'est exactement la face `diagonale`. En les interdisant, on garantit au
## plus UN segment par face, donc des boucles fermées et aucun cas particulier. Mesuré sur les
## 35 classes atteignables : 0 face ambiguë, 0 boucle ouverte, et le comptage d'arêtes coupées s'accorde
## avec `MB.forme_de_face()` sans un seul désaccord.
##
## ⚠ **ON NE REFERME PAS LA COUPE**, comme partout ailleurs ici : on n'émet que la surface oblique,
## jamais de face sur les plans de coupe. Les sommets tombent au milieu des arêtes, donc PILE sur ces
## plans — la pièce voisine reprend exactement où celle-ci s'arrête, et le raccord est géométrique.
static func maillage_direct(bits: int) -> ArrayMesh:
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var couleurs := PackedColorArray()
	_direct_dans(bits, Vector3.ZERO, sommets, normales, couleurs)
	return _en_mesh(sommets, normales, couleurs)


## LE MÊME GÉNÉRATEUR, SUR UN BLOC ENTIER — une passe par sommet intérieur.
##
## ⚠ **CE N'EST PAS UN SECOND GÉNÉRATEUR, et c'est ce qui compte.** La surface en faces directes est
## LOCALE à chaque sommet : les 295 cases d'un témoin se traitent en appelant la même fonction 343 fois,
## décalée. Écrire ici une variante « pour les blocs » ferait deux descriptions d'une même géométrie, et
## elles divergeraient au premier réglage — la faute que ce projet a payée trois fois ce soir.
##
## ⚠ **ON LIT AUSSI LES SOMMETS DE BORD ICI, ET C'EST L'INVERSE DE LA CONVENTION (A) — délibérément.**
## Première version : sommets intérieurs seulement, comme pour la récolte. Mesuré sur le témoin :
## **165 sommets intérieurs portent une surface, mais 247 sommets DE BORD aussi — 60 % de la peau
## n'était jamais émise.** La planche rendait donc les seules frontières INTERNES (la grotte, le tunnel,
## le dessous de l'arche) : des feuilles éparses au lieu d'un massif.
##
## ⚠ **CE N'EST PAS UN BOGUE, C'EST UN CONFLIT DE RÔLE.** La Convention (A) est JUSTE pour RÉCOLTER —
## un sommet de bord récolterait la face de sciage plate du bloc, pas de l'art — et FAUSSE pour MONTRER,
## puisqu'un témoin doit ressembler à un objet fermé qu'on peut sculpter. Les deux usages veulent deux
## étendues. **Seul le chemin d'AFFICHAGE est étendu ; `trancher()` et la récolte ne bougent pas.**
## Aux sommets de bord, les cases hors du bloc comptent pour VIDES : c'est ce qui referme la face de
## sciage, et c'est déjà ce que faisait la coque en sous-voxels sans le dire.
##
## ⚠ Le sommet `v` est en `v + (1,1,1)` : la case `p` occupe `[p, p+1]`, donc les huit coins du cube de
## la pièce tombent sur les centres des cases `v` et `v+1`. C'est ce qui pose la surface PILE sur les
## plans de coupe.
static func maillage_direct_du_bloc(pleines: Dictionary, cote: int) -> ArrayMesh:
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var couleurs := PackedColorArray()
	for vx in range(-1, cote):
		for vy in range(-1, cote):
			for vz in range(-1, cote):
				var v := Vector3i(vx, vy, vz)
				var bits: int = MB.bits(pleines, v)
				if not MB.porte_une_surface(bits):
					continue
				_direct_dans(bits, Vector3(v) + Vector3.ONE, sommets, normales, couleurs)
	return _en_mesh(sommets, normales, couleurs)


static func _en_mesh(sommets: PackedVector3Array, normales: PackedVector3Array,
		couleurs: PackedColorArray) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if sommets.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = sommets
	arrays[Mesh.ARRAY_NORMAL] = normales
	arrays[Mesh.ARRAY_COLOR] = couleurs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, matiere())
	return mesh


## Émet la surface d'UNE configuration dans des tableaux partagés, décalée de `decalage`.
static func _direct_dans(bits: int, decalage: Vector3, sommets: PackedVector3Array,
		normales: PackedVector3Array, couleurs: PackedColorArray) -> void:
	# ⚠ Une classe ambiguë n'existe pas dans ce monde : on n'émet rien plutôt que de deviner.
	if not MB.sans_contact_diagonal(bits):
		return

	var aretes: Array = _aretes_du_cube()
	# ⚠ **`dehors` EST LA CORRECTION D'UN DÉFAUT QUE SEULE UNE IMAGE A MONTRÉ (25 septembre 2026).**
	# La première version orientait ses faces avec le CENTRE DE LA MATIÈRE — une heuristique globale.
	# Mesuré : **18 triangles sur 94 pointaient vers la matière**, sur `pointe` et les six `vrille`,
	# c'est-à-dire les configurations qui s'ENROULENT et ne sont donc pas étoilées autour de ce centre.
	# Retournées, elles passaient en faces arrière et disparaissaient au `cull_mode`.
	# Le dehors se DÉDUIT localement : un sommet de surface est le milieu d'une arête dont un bout est
	# plein et l'autre vide, et le dehors est la direction plein → vide. Aucun centroïde.
	var point := {}
	var dehors := {}
	for i in aretes.size():
		var a: int = aretes[i][0]
		var b: int = aretes[i][1]
		var pa: bool = ((bits >> a) & 1) != 0
		var pb: bool = ((bits >> b) & 1) != 0
		if pa == pb:
			continue
		point[i] = (_coin_du_cube(a) + _coin_du_cube(b)) * 0.5 + decalage
		dehors[i] = ((_coin_du_cube(b) - _coin_du_cube(a)) if pa
			else (_coin_du_cube(a) - _coin_du_cube(b))).normalized()
	if point.is_empty():
		return

	# Les segments : une face qui porte exactement deux arêtes coupées les relie.
	var voisins := {}
	for i in point:
		voisins[i] = []
	for f in _faces_du_cube():
		var sur: Array = []
		for i in point:
			if aretes[i][0] in f and aretes[i][1] in f:
				sur.append(i)
		if sur.size() == 2:
			(voisins[sur[0]] as Array).append(sur[1])
			(voisins[sur[1]] as Array).append(sur[0])

	# ⚠ LE CENTRE DE LA MATIÈRE donne le DEHORS. Une normale tirée du seul enroulement serait un choix
	# de signe tenu à la main — la faute qui a déjà livré une planche entière en faces arrière.
	var vus := {}
	for depart in point:
		if vus.has(depart):
			continue
		# ⚠ La boucle porte les INDEX d'arêtes, pas les positions : c'est d'eux qu'on tire le dehors.
		var boucle: Array = []
		var courant: int = int(depart)
		var precedent := -1
		while not vus.has(courant):
			vus[courant] = true
			boucle.append(courant)
			var suivant := -1
			for n in voisins[courant]:
				if int(n) != precedent:
					suivant = int(n)
					break
			if suivant == -1:
				break
			precedent = courant
			courant = suivant
		if boucle.size() < 3:
			continue
		# ⚠ **UNE SEULE ORIENTATION POUR TOUTE LA BOUCLE**, somme des directions plein → vide de ses
		# arêtes. Orienter triangle par triangle rouvrirait la porte au signe local instable sur les
		# configurations enroulées — celles-là mêmes qui ont produit les 18 faces retournées.
		var vers_le_vide := Vector3.ZERO
		for i in boucle:
			vers_le_vide += dehors[i]
		for k in range(1, boucle.size() - 1):
			var a: Vector3 = point[boucle[0]]
			var b: Vector3 = point[boucle[k]]
			var c: Vector3 = point[boucle[k + 1]]
			var n: Vector3 = (b - a).cross(c - a)
			if n.length_squared() < 0.000000001:
				continue
			n = n.normalized()
			if vers_le_vide.length_squared() > 0.000001 and n.dot(vers_le_vide) < 0.0:
				n = -n
			_ajouter_triangle(sommets, normales, couleurs, a, b, c, n)


## Le centre de la case que porte le coin `t` — donc un coin du cube de la pièce.
static func _coin_du_cube(t: int) -> Vector3:
	var c: Vector3i = MB.COINS[t]
	return Vector3(float(c.x) - 0.5, float(c.y) - 0.5, float(c.z) - 0.5) * (OCTANT * 2.0)


## Les 12 arêtes du cube, DÉDUITES de `COINS` : les paires de coins qui diffèrent d'un seul axe.
static func _aretes_du_cube() -> Array:
	var sortie: Array = []
	for a in 8:
		for b in range(a + 1, 8):
			var d: Vector3i = MB.COINS[b] - MB.COINS[a]
			if absi(d.x) + absi(d.y) + absi(d.z) == 1:
				sortie.append([a, b])
	return sortie


## Les 6 faces du cube, chacune par ses quatre coins : un axe fixé à 0 ou à 1.
static func _faces_du_cube() -> Array:
	var sortie: Array = []
	for axe in 3:
		for cote in 2:
			var coins: Array = []
			for t in 8:
				if MB.COINS[t][axe] == cote:
					coins.append(t)
			sortie.append(coins)
	return sortie


## Pose un TRIANGLE, orienté vers `normale`. Le frère de `_ajouter_quad` pour les faces obliques.
##
## ⚠ **IL EXISTE PARCE QU'UNE FACE DIRECTE N'EST PAS UN QUAD PLAT.** `_ajouter_quad` pose quatre coins
## coplanaires avec une normale alignée sur un axe ; une face à 45° qui remplace une marche est un
## triangle, et sa normale ne l'est sur aucun axe.
##
## ⚠ **ET IL REPREND MOT POUR MOT LA DISCIPLINE D'ENROULEMENT DE SON FRÈRE, sans la re-dériver.** Godot
## enroule ses faces avant dans le sens HORAIRE : le produit vectoriel de l'ordre stocké doit pointer À
## L'OPPOSÉ de la normale. On ne fait donc pas confiance à l'ordre reçu — on mesure ce que l'enroulement
## produit et l'on retourne si besoin. La note de `_ajouter_quad` dit ce que l'erreur inverse a coûté :
## une planche entière, cohérente avec elle-même, que 3 922 vérifications ont laissée passer et que
## seule une image a démentie. Écrire ici une seconde convention de signe rejouerait exactement ça.
static func _ajouter_triangle(sommets: PackedVector3Array, normales: PackedVector3Array,
		couleurs: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, normale: Vector3) -> void:
	var ordre: Array = [a, b, c]
	if (b - a).cross(c - a).dot(normale) > 0.0:
		ordre = [c, b, a]
	var couleur := _couleur(normale)
	for p in ordre:
		sommets.append(p)
		normales.append(normale)
		couleurs.append(couleur)


## La couleur d'une face, d'après ce qu'elle regarde. ⚠ Y est le haut (`marching_blocks.gd`).
static func _couleur(normale: Vector3) -> Color:
	if normale.y > 0.5:
		return COULEUR_DESSUS
	if normale.y < -0.5:
		return COULEUR_PLAFOND
	return COULEUR_PAROI


## Le matériau du repli : les couleurs viennent des SOMMETS, donc une seule surface et un seul appel de
## rendu par pièce, quelles que soient les trois teintes.
static func matiere() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	return m


## La collision d'une pièce : UNE BOÎTE PAR OCTANT PLEIN.
##
## ⚠ Dérivée, jamais posée à la main : « ce qui arrête la lumière et ce qui arrête les pieds sont deux
## descriptions d'un même fait » (charte §6). Une boîte englobante refermerait les passages que la
## diagonale laisse ouverts — le défaut que Jordan avait repéré sur le modèle 2D.
static func collision(bits: int) -> Array:
	var formes: Array = []
	for t in 8:
		if not (bits & (1 << t)):
			continue
		var coin: Vector3i = MB.COINS[t]
		var forme := BoxShape3D.new()
		forme.size = Vector3.ONE * OCTANT
		var centre := Vector3(
			(-OCTANT if coin.x == 0 else OCTANT) * 0.5,
			(-OCTANT if coin.y == 0 else OCTANT) * 0.5,
			(-OCTANT if coin.z == 0 else OCTANT) * 0.5)
		formes.append(forme)
		formes.append(Transform3D(Basis(), centre))
	return formes


## Toutes les pièces du repli : {nom de classe: ArrayMesh}. Les classes sans surface sont absentes.
static func maillages() -> Dictionary:
	var pieces := {}
	for c in MB.classes():
		if not MB.porte_une_surface(c["bits"]):
			continue
		pieces[c["nom"]] = maillage(c["bits"])
	return pieces


## La `MeshLibrary` complète du repli, prête pour un GridMap : un item par classe de surface, nommé
## comme la classe, avec sa collision dérivée.
##
## ⚠ L'ORDRE DES ITEMS SUIT L'ORDRE DES CLASSES, et le nom reste la seule clé de recherche (charte §6 :
## « jamais une tuile par sa position, toujours par son nom »).
static func librairie() -> MeshLibrary:
	var lot := MeshLibrary.new()
	var id := 0
	for c in MB.classes():
		if not MB.porte_une_surface(c["bits"]):
			continue
		var mesh: ArrayMesh = maillage(c["bits"])
		if mesh.get_surface_count() == 0:
			continue
		lot.create_item(id)
		lot.set_item_name(id, c["nom"])
		lot.set_item_mesh(id, mesh)
		lot.set_item_shapes(id, collision(c["bits"]))
		id += 1
	return lot


## Le nombre de faces d'octant qu'une configuration doit exposer — calculé SANS fabriquer le maillage.
## ⚠ Sert de contrôle indépendant au test : deux chemins vers le même nombre, et s'ils divergent, c'est
## que l'un des deux ment.
static func faces_attendues(bits: int) -> int:
	var n := 0
	for t in 8:
		if not (bits & (1 << t)):
			continue
		for axe in 3:
			if not (bits & (1 << (t ^ (1 << axe)))):
				n += 1
	return n


## Le recensement du repli — ce qu'on regarde AVANT de le croire.
## ⚠ Une pièce vide ou qui déborde de son cube ne se voit pas dans un compteur d'items : elle se voit
## ici, ou à l'image.
static func recenser() -> Array:
	var lignes: Array = []
	for c in MB.classes():
		if not MB.porte_une_surface(c["bits"]):
			continue
		var mesh: ArrayMesh = maillage(c["bits"])
		lignes.append({
			"nom": c["nom"],
			"bas": c["bas"],
			"haut": c["haut"],
			"faces": faces_attendues(c["bits"]),
			"aire": Decoupe.aire(mesh),
			"dans_son_cube": Decoupe.tient_dans(mesh,
				AABB(Vector3(-OCTANT, -OCTANT, -OCTANT), Vector3.ONE), 0.0001),
		})
	return lignes
