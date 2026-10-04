@tool
extends RefCounted
## LE BLOC MAÎTRE UNIQUE — ce que l'artiste sculpte, et rien de plus.
##
## ⚠ **DEPUIS LE 27 SEPTEMBRE 2026 (Jordan), C'EST LA PLANÈTE PAYSAGE DE 12³** : un témoin fait de
## formes qu'on reconnaît, pour le MONDE SANS CONTACT DIAGONAL — **35 classes en intérieur et 17 en
## extérieur, 52 tuiles**, 0 contact diagonal, donc manifold. Il est produit par
## `DEV_TOOLS/planete_paysage.gd --couches` et collé tel quel dans `BLOCS`.
##
## ⚠ **SON HISTOIRE, parce que les leçons plus bas en viennent** : neuf blocs de 4³ jusqu'au
## 25 septembre 2026, qui ne pouvaient pas livrer les deux CONTEXTES ; puis un bloc unique de 8³ fini
## par un finisseur, 90 tuiles du monde AVEC diagonales ; puis deux jours à deux témoins — un paysage
## lisible (27 tuiles) et un résidu (63), ce dernier fait presque entièrement de contacts diagonaux que
## le monde avait déjà interdits.
##
## ── LE FAIT QUI COMMANDE TOUT LE RESTE ──────────────────────────────────────────────────────────────
##
## ⚠ **UN PAYSAGE LISIBLE EST LOCALEMENT RÉPÉTITIF.** Un mur est un mur sur toute sa longueur. Agrandir
## un bloc n'y change presque rien : les mêmes cinq paysages donnaient 18 classes en 4³, 19 en 5³, 19 en
## 6³ — passer de 27 à 125 sommets intérieurs achetait **une** classe. La variété vient de
## l'IRRÉGULARITÉ, pas du volume.
##
## ⚠ **ET ÇA S'EST RETOURNÉ CONTRE MOI EN ÉCRIVANT CE BLOC.** Cinq versions à la main ont plafonné à
## 43/90 (44 → 30 → 37 → 38 → 43) : en remplaçant un boyau tordu par une grande salle lisse, j'ai gagné
## du volume et perdu dix-huit classes. La leçon était écrite ici, sous mes yeux, et je l'ai violée.
##
## **L'érosion n'est donc pas un pis-aller : c'est le seul sujet d'art qui produise les configurations
## où la matière ne tient que par une arête ou un coin.** Et ce n'est pas une conséquence du groupe
## `oriente` : mesuré dans les trois, les mêmes paysages font 12/21 en `libre`, 14/41 en `vertical`,
## 18/68 en `oriente`.
##
## ── COMMENT CE BLOC A ÉTÉ FAIT : LA MAIN TIENT LA FORME, LA RECHERCHE COMPLÈTE LA COUVERTURE ────────
##
## La SILHOUETTE est écrite à la main — socle, grotte, plafond, corps, falaise qui serpente, plateau,
## surplomb, bord échancré. La COUVERTURE est finie par une recherche contrainte qui ne touche qu'aux
## cases déclarées libres, jamais à la silhouette, puis ÉLAGUÉE : on annule chaque retouche qui n'est pas
## indispensable, pour revenir au dessin. 23/90 à la main → 90/90 après, en un seul morceau.
##
## ⚠ **UNE PREMIÈRE VERSION DU FINISSEUR RENDAIT DU BRUIT — 90/90 et un socle en dentelle.** J'avais
## verrouillé la SILHOUETTE et laissé libre la MASSE : verrouiller le contour n'empêche pas de vider
## l'intérieur. **Un compteur vert ne dit jamais qu'une tuile est à SA place.**
##
## ── LE CONTEXTE : SOL DE GROTTE ≠ SOL DE MASSIF (Jordan, 23 septembre 2026) ──────────────────────────
##
## ⚠ **CETTE DISTINCTION N'EST PAS DANS LE MODÈLE, ET AUCUN GROUPE DE ROTATION NE PEUT L'Y METTRE.** Le
## sol d'une grotte et le dessus d'un massif sont la MÊME configuration — `plaque_b4h0`. Le classificateur
## ne lit que huit cellules ; « suis-je sous un plafond » est à plusieurs cases de là. Il faut une
## SECONDE dimension, et elle se DÉDUIT : `MB.exterieur_possible()`.
##
## **MESURÉ — le critère a été choisi par élimination, pas par goût.** Trois candidats :
##   • le VIDE ENCLOS (connexité) — sur un massif percé d'un tunnel débouchant aux deux bouts, il déclare
##     **0 case de tunnel sur 48** comme intérieure. DISQUALIFIÉ ;
##   • l'OCCLUSION DU CIEL — sépare bien tunnel (3,5 %) et surplomb (19,9 %), mais **11 % des sommets
##     changent d'avis** entre un bloc de 7³ et le même volume enrobé de roche. L'artiste sculpterait des
##     tuiles que le pinceau ne poserait jamais là. DISQUALIFIÉ ;
##   • **ROCHE AU-DESSUS — 0 % de dérive**, parce qu'il ne demande pas COMBIEN de roche il y a.
##
## ⚠ **ET UNE LISTE `AMBIGUES` ÉCRITE À L'OBSERVATION A VÉCU ICI.** Elle annonçait « 5 classes ambiguës,
## 73 items au lieu de 68 ». Sa prémisse était fausse : mesuré, **10** sur les blocs eux-mêmes et **35**
## dans un seul monde d'essai. Le compte exact se CALCULE : **22 classes peuvent être à l'air libre, 46
## ne le peuvent jamais** (un plafond n'est pas sous le ciel) — donc **90 tuiles**, et non 68 ni 136.
##
## ── CE QUE LE TÉMOIN NE PEUT PAS ÊTRE ───────────────────────────────────────────────────────────────
##
## ⚠ **UN TÉMOIN COMPLET CONTIENT NÉCESSAIREMENT DES ARÊTES NON-MANIFOLD, et c'est une contradiction de
## définition, pas un défaut à corriger.** 33 des 68 classes SONT des contacts diagonaux (`diagonale`,
## `damier`, `chicane`, `biais`, `crochet`…) : deux cellules qui ne se touchent que par une arête, là où
## quatre faces se rejoignent. Interdire ces contacts fait tomber la couverture à **52/90** — mesuré,
## trois essais sur trois. C'est l'ambiguïté que le modèle nomme `PONT_SUR_FACE_AMBIGUE`.
##
## ⚠ **CE PARAGRAPHE DÉCRIT LE MONDE D'AVANT.** Le jour même, Jordan a tranché dans l'autre sens :
## **le monde n'a pas de contact diagonal** (voir `marching_blocks.gd`). Les 33 classes en contact
## diagonal ne sont plus à sculpter, et « 52/90 », rangé ici comme un échec, est devenu la cible —
## 52/52. Le témoin n'a donc plus d'arête ambiguë du tout.
##
## ── CE QUI EST DÉRIVÉ ET CE QUI EST ÉCRIT ───────────────────────────────────────────────────────────
##
## ÉCRIT À LA MAIN : le remplissage du bloc (en couches ASCII, donc VISIBLE dans le source) et son nom.
## DÉRIVÉ : tout le reste — les classes, ce qui manque, les contextes possibles, la géométrie.
## ⚠ Aucun décompte n'est recopié : ce projet a déjà payé quatre représentants de classe tapés à la main
## et faux (42 configurations sans réponse, 5 faussement chirales), puis une liste `AMBIGUES` dont la
## prémisse ne tenait pas.
##
## `anomalies()` REFUSE de laisser diverger l'écrit et le dérivé, et `DEV_TOOLS/test_blocs_maitres.gd`
## l'appelle.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const RP := preload("res://addons/marchingblocks_core/repli_procedural.gd")
const ImagesRelues := preload("res://addons/marchingblocks_core/images_relues.gd")

## Le côté du bloc, en cellules. ⚠ 12 et non 8 : des formes qu'on RECONNAÎT — une arche visible comme
## une arche, un pont, une cheminée — coûtent de la place ; en tenir moins, c'est l'optimisation que
## Jordan a refusée (« il ne s'agit pas de produire le nombre de gestes minimum »).
const COTE := 12

## ⚠ La subdivision de la coque : le retrait de l'amincissement vaut un QUART de cellule, donc quatre
## sous-voxels par cellule représentent exactement les boîtes rentrées, sans le moindre arrondi.
const SOUS := 4

## Les deux contextes. Un bloc d'INTÉRIEUR fournit les variantes de grotte des classes ambiguës.
const EXTERIEUR := "exterieur"
const INTERIEUR := "interieur"

# ⚠ **UNE LISTE `AMBIGUES` A VÉCU ICI, ET LA MESURE L'A INVALIDÉE — PAS PAR SON CONTENU, PAR SA
# PRÉMISSE.** Elle nommait cinq classes vues dans les deux contextes, et se justifiait ainsi :
# « MESURÉES, PAS DÉDUITES… la structure en autorise 63 ; l'usage en exerce 5, on dimensionne sur
# l'usage ». Le choix était délibéré et défendable. Mais l'usage n'en exerce PAS cinq — mesuré : **10**
# sur les neuf blocs eux-mêmes, et **35** dans un seul monde d'essai de 20³, sans plafond en vue sous 68.
# Aucun contenu n'aurait sauvé cette liste, puisque c'est son fondement qui ne tenait pas.
#
# ⚠ Le contexte se DÉDUIT désormais du modèle : `MB.exterieur_possible(bits)` dit quelles classes
# peuvent apparaître à l'air libre — **22 sur 68** — et les 46 autres n'existent qu'avec de la roche
# au-dessus. Le « 63 » annoncé ci-dessus n'est pas en contradiction : il répondait à un autre critère,
# et seul celui du toit a été mesuré STABLE entre l'échelle du bloc et celle du monde peint.

## LE BLOC. `couches[y][z]` est une rangée de `COTE` caractères indexée par x — « # » plein, « . » vide.
## ⚠ y = 0 est le BAS (marching_blocks.gd : « Y EST LE HAUT »).
const BLOCS := [
	# ── LA PLANÈTE PAYSAGE — le témoin UNIQUE (Jordan, 27 septembre 2026) ─────────────────────────────
	#
	# ⚠ **IL Y A EU DEUX TÉMOINS DU 25 AU 27 SEPTEMBRE 2026, ET LE SECOND N'EXISTAIT QUE POUR LE MONDE
	# D'AVANT.** Le paysage lisible couvrait 27 tuiles sur 90 ; un « résidu » sorti du finisseur portait
	# les 63 autres — presque toutes des CONTACTS DIAGONAUX. Or le monde sans contact diagonal était
	# DÉCIDÉ depuis le 25 : ces 38 tuiles-là ne seront jamais posées. Le second témoin fabriquait donc,
	# à grands frais d'arêtes non-manifold, des tuiles que personne n'emploiera.
	#
	# ⚠ **ENGENDRÉ PAR `DEV_TOOLS/planete_paysage.gd --couches`, COLLÉ TEL QUEL.** On n'écrit pas ce
	# bloc ici à la main : on retouche les FORMES là-bas — le canyon, l'arche, le pont, la bouche de
	# grotte, la cheminée, l'auvent… — et l'on recolle. Mesuré à la sortie : **820 cases, 0 contact
	# diagonal, 52 tuiles sur 52** (35 d'intérieur, 17 d'air libre).
	#
	# ⚠ **12³ ET NON 8³** : un paysage fait de formes qu'on reconnaît coûte de la place. Le placeur
	# minimal de la même journée tenait en moins, et rendait un cube blanc dont toute la substance était
	# enfermée dans une cavité invisible — « tu as encore trop optimisé, il faut que l'arche soit
	# visible comme une arche » (Jordan).
	{
		"nom": "la planète paysage — canyon, arche, pont, grotte, cheminée, auvent",
		"contexte": EXTERIEUR,
		"quoi": "le témoin unique : les 52 tuiles d'un monde sans contact diagonal, par des formes",
		"couches": [
			[   # y = 0
				"############",
				"############",
				"############",
				"############",
				"############",
				"############",
				"############",
				"############",
				"############",
				"############",
				"############",
				"############",
			],
			[   # y = 1
				"############",
				"############",
				"############",
				"############",
				"############",
				"############",
				"############",
				"############",
				"############",
				"############",
				"############",
				"############",
			],
			[   # y = 2
				"######...###",
				"######...###",
				"######...###",
				"#######.####",
				"#######.####",
				"######...###",
				"######...###",
				"######...###",
				"######...###",
				"######...#..",
				"######...#..",
				"######...###",
			],
			[   # y = 3
				"######...###",
				"######...###",
				"######......",
				"#....##.#...",
				"#.#..##.####",
				"#........###",
				"##..#....###",
				"##.......###",
				"####.#...###",
				"#..###...#..",
				"######...#..",
				"######...###",
			],
			[   # y = 4
				"#######..###",
				"#######..###",
				"#######.....",
				"#....##.#...",
				"#.#..##.####",
				"###..##..###",
				"##..##...###",
				"#........###",
				"#....#...###",
				"#..###...#..",
				"######...#..",
				"######...###",
			],
			[   # y = 5
				"######...###",
				"######...###",
				"######...###",
				"#....##.####",
				"#.#..##.####",
				"#....#...###",
				"##.......###",
				"#..#.....###",
				"#....#######",
				"#..#######..",
				"######...#..",
				"######...###",
			],
			[   # y = 6
				"######......",
				"######......",
				"######......",
				"#######.#...",
				"#######.#..#",
				"######.....#",
				"######...#..",
				"##.###......",
				"##..##.....#",
				"######.....#",
				"######.....#",
				"######.....#",
			],
			[   # y = 7
				"######......",
				"######......",
				"#######.....",
				"####..###...",
				"####.####..#",
				"######.....#",
				"#######..#..",
				"##..###.....",
				"##..###....#",
				"#######....#",
				"######.....#",
				"######.....#",
			],
			[   # y = 8
				"............",
				".###........",
				".#..........",
				".#....#.....",
				"............",
				"............",
				".........#..",
				"............",
				".....#......",
				"..##........",
				"..##........",
				"............",
			],
			[   # y = 9
				"............",
				".#..........",
				"............",
				"............",
				"............",
				"............",
				"............",
				"............",
				"............",
				"............",
				"............",
				"............",
			],
			[   # y = 10
				"............",
				"............",
				"............",
				"............",
				"............",
				"............",
				"............",
				"............",
				"............",
				"............",
				"............",
				"............",
			],
			[   # y = 11
				"............",
				"............",
				"............",
				"............",
				"............",
				"............",
				"............",
				"............",
				"............",
				"............",
				"............",
				"............",
			],
		],
	},
]


## Combien de blocs maîtres.
static func nombre() -> int:
	return BLOCS.size()


## Les cellules pleines du bloc `i`, au format que `MB.bits()` attend : {Vector3i: true}.
static func cases(i: int) -> Dictionary:
	var pleines := {}
	if i < 0 or i >= BLOCS.size():
		return pleines
	var couches: Array = BLOCS[i]["couches"]
	for y in couches.size():
		var rangees: Array = couches[y]
		for z in rangees.size():
			var rangee: String = rangees[z]
			for x in rangee.length():
				if rangee[x] == "#":
					pleines[Vector3i(x, y, z)] = true
	return pleines


## Les sommets du bloc `i` qui portent une pièce, et la classe de chacun.
## Rend [{sommet, nom, orientation, classe}].
##
## ⚠ ON NE LIT QUE LES SOMMETS INTÉRIEURS — ceux dont les huit cellules tombent dans le bloc. Les autres
## dépendent de ce qu'il y a AUTOUR du bloc, qui n'existe pas : les compter ferait croire à une
## couverture que le bloc ne livre pas.
static func pieces_de(i: int) -> Array:
	var pleines: Dictionary = cases(i)
	var sortie: Array = []
	for vx in range(COTE - 1):
		for vy in range(COTE - 1):
			for vz in range(COTE - 1):
				var v := Vector3i(vx, vy, vz)
				var r: Dictionary = MB.classer(MB.bits(pleines, v))
				if not r["surface"]:
					continue
				sortie.append({
					"sommet": v,
					"nom": r["nom"],
					"orientation": r["orientation"],
					"classe": r["classe"],
				})
	return sortie


## Les noms de classes que le bloc `i` livre, sans doublon et triés.
static func classes_de(i: int) -> Array:
	var vus := {}
	for p in pieces_de(i):
		vus[p["nom"]] = true
	var noms: Array = vus.keys()
	noms.sort()
	return noms


## Le cumul de couverture, bloc par bloc : [{nom, classes, neuves, cumul}].
## ⚠ C'est ce que la vue affiche, et c'est DÉRIVÉ — jamais un chiffre écrit à côté.
static func cumul() -> Array:
	var vus := {}
	var sortie: Array = []
	for i in BLOCS.size():
		var propres: Array = classes_de(i)
		var neuves := 0
		for n in propres:
			if not vus.has(n):
				vus[n] = true
				neuves += 1
		sortie.append({
			"nom": BLOCS[i]["nom"],
			"contexte": BLOCS[i]["contexte"],
			"classes": propres.size(),
			"neuves": neuves,
			"cumul": vus.size(),
		})
	return sortie


## Les classes de surface qu'AUCUN bloc ne livre. Vide si la couverture est complète.
static func manquantes() -> Array:
	var vus := {}
	for i in BLOCS.size():
		for n in classes_de(i):
			vus[n] = true
	var absentes: Array = []
	for n in MB.pieces_a_sculpter():
		if not vus.has(n):
			absentes.append(n)
	return absentes


# ⚠ **`interieures_manquantes()` A VÉCU ICI, ET SA LEÇON SURVIT À SA SUPPRESSION.** Elle vérifiait qu'un
# bloc d'INTÉRIEUR livrait bien chaque classe de la liste `AMBIGUES`. C'est ce contrôle qui avait trouvé
# un vrai trou : la première « salle de grotte » était une coque creuse, donc sans aucun surplomb, et
# `mb_arete_b0h2` n'avait aucune source d'intérieur — pendant que le décompte global affichait 68/68.
# **Un compteur vert ne dit jamais qu'une tuile est à SA place.**
#
# Elle disparaît parce que la liste qu'elle consultait a été invalidée par la mesure (voir plus haut), et
# parce qu'elle juge le JEU DE NEUF BLOCS, qu'un bloc maître unique doit remplacer. Ce qu'il faut garder
# est la forme du défaut, pas l'instrument : **une couverture complète en NOMBRE peut être incomplète en
# CONTEXTE**, et c'est `MB.exterieur_possible()` qui porte désormais cette distinction.


## LE SOLIDE DU BLOC — la frontière de l'union de ses cellules, c'est-à-dire CE QUE L'ARTISTE SCULPTE.
##
## ⚠ **UNE IMAGE A CORRIGÉ CE CHOIX, ET IL FAUT L'ÉCRIRE PLUTÔT QUE DE LE RÉPARER EN SILENCE.** La
## première version dessinait la RÉCOLTE du trancheur — une pièce par sommet intérieur — au motif que
## « la vue doit montrer ce que le trancheur verra ». Le raisonnement était joli et le résultat faux :
## dans un bloc presque plein, les 27 sommets intérieurs voient surtout « plein » et ne portent aucune
## surface, tandis que la coque extérieure siège sur des sommets qui ne sont PAS intérieurs. Le « tunnel
## percé » (48 cases sur 64) rendait donc deux plans et aucun tunnel, et la « salle de grotte » une
## boîte. **On a failli accuser les noms sur la foi d'une image fausse** — ils étaient justes.
##
## Le SOLIDE est ce que l'artiste doit reconnaître ; la récolte est ce que le greffon en tire, et elle a
## sa propre fonction (`maillage_des_pieces`). Les deux servent, elles ne se remplacent pas.
## ⚠ **IL EST BÂTI EN SOUS-VOXELS DEPUIS LE 25 SEPTEMBRE 2026 — DÉCIDÉ (Jordan), ET MESURÉ.**
## L'ancienne version émettait une face par face de cellule. Mesuré sur les neuf blocs : le maillage
## AMINCI en sortait **non-manifold** (139 arêtes à 3 faces ou plus sur un seul bloc), parce qu'il
## émettait les SIX faces de chaque cellule — 144 faces enterrées sur 216. Et le culler naïvement
## ouvrait **16 trous**, là où deux cellules voisines n'ont pas le même retrait.
##
## La coque en sous-voxels ferme la surface **par construction** : 0 arête de bord, et la valence 4
## passe de 26-87 % à 83-98 % — donc de vraies boucles d'arêtes, ce que Jordan a exigé du témoin.
## ⚠ Coût mesuré : ×5 en triangles, et la RÉCOLTE est identique (mêmes classes, 0 erreur d'octant).
static func maillage(i: int) -> ArrayMesh:
	return _coque_sous_voxels(cases(i), 0.0)


## LA COQUE EN SOUS-VOXELS — la frontière de l'union des boîtes, subdivisée en `SOUS` par cellule.
## `retrait` : de combien chaque face donnant sur du VIDE rentre (0 pour le solide plein).
##
## ⚠ **CE QU'ELLE NE GARANTIT PAS, ET IL FAUT LE DIRE** : elle n'est pas manifold partout. Là où deux
## cellules ne se touchent que par une ARÊTE, quatre faces s'y rejoignent. Mesuré : le nombre d'arêtes
## non-manifold du solide ÉGALE exactement le nombre de ces contacts (19/19, 13/13, 13/13 sur les blocs
## d'érosion, 0/0 sur les six autres). ⚠ **C'est dans l'OCCUPATION, pas dans le mailleur** — et c'est
## le cas que le modèle nomme `PONT_SUR_FACE_AMBIGUE`, donc parfaitement légal. Le retrait en répare
## l'essentiel (240 → 18 sur le bloc unique) parce qu'il sépare les deux cellules.
## L'OCCUPATION EN SOUS-VOXELS dont la coque est exactement la frontière — `SOUS` par cellule.
##
## ⚠ **EXTRAITE DE `_coque_sous_voxels` POUR ÊTRE L'AUTORITÉ UNIQUE (25 septembre 2026).** Une sonde
## avait besoin de cette occupation pour imprimer le profil réel d'un rebord ; la recopier lui aurait
## donné une SECONDE description du retrait, et une seconde description d'un même fait finit toujours
## par diverger (charte §6). Le mailleur la lit comme tout le monde.
## ⚠ Et l'extraction ne doit RIEN changer à ce qui sort : une extraction qui modifie sa sortie n'est pas
## une extraction. Vérifié — mêmes maillages, mêmes comptes d'arêtes, mêmes suites vertes.
static func sous_voxels(pleines: Dictionary, retrait: float) -> Dictionary:
	var pleins := {}
	for c in pleines:
		var p: Vector3i = c
		var mini := Vector3(p)
		var maxi := Vector3(p) + Vector3.ONE
		if retrait > 0.0:
			for axe in 3:
				var avant := Vector3i.ZERO
				avant[axe] = -1
				if not pleines.has(p + avant):
					mini[axe] += retrait
				var apres := Vector3i.ZERO
				apres[axe] = 1
				if not pleines.has(p + apres):
					maxi[axe] -= retrait
		var a := Vector3i(roundi(mini.x * SOUS), roundi(mini.y * SOUS), roundi(mini.z * SOUS))
		var b := Vector3i(roundi(maxi.x * SOUS), roundi(maxi.y * SOUS), roundi(maxi.z * SOUS))
		for x in range(a.x, b.x):
			for y in range(a.y, b.y):
				for z in range(a.z, b.z):
					# ⚠ **LA VALEUR EST LA CASE PROPRIÉTAIRE, ET CE N'EST PAS DÉCORATIF.** Ici, `p`
					# est connu exactement ; le retrouver plus tard par une division serait une
					# SECONDE description du découpage (charte §6). Les clés ne changent pas, et
					# tous les lecteurs actuels n'interrogent que `has()`.
					pleins[Vector3i(x, y, z)] = p
	return pleins


## LA CASE VIDE QUE BORDE un sous-voxel vide `sv` — celle dont la face de coque regarde le vide.
##
## ⚠ **CE N'EST PAS TOUJOURS LA CASE QUI CONTIENT `sv`, ET C'EST MESURÉ** : sur l'aminci, 1 819 faces
## sur 15 560 (12 %) regardent un sous-voxel vide qui appartient à une case PLEINE — la bande que
## l'amincissement a retirée à cette case, parce qu'une de SES voisines est vide. Le vide bordé est
## alors cette voisine-là, et c'est elle qu'on rend.
## ⚠ `sv` est VIDE, donc aucune case propriétaire n'a été notée pour lui (`sous_voxels`) : on la retrouve
## par division — **par `floori`**, jamais par la division entière, qui tronque vers zéro et a déjà
## décalé la légende d'un bloc translaté en x négatif (charte §9).
static func vide_borde(pleines: Dictionary, sv: Vector3i, retrait: float) -> Vector3i:
	var cas := Vector3i(floori(float(sv.x) / SOUS), floori(float(sv.y) / SOUS),
		floori(float(sv.z) / SOUS))
	if not pleines.has(cas):
		return cas
	var largeur: int = roundi(retrait * SOUS)
	var local: Vector3i = sv - cas * SOUS
	for axe in 3:
		var d := Vector3i.ZERO
		d[axe] = 1
		if local[axe] < largeur and not pleines.has(cas - d):
			return cas - d
		if local[axe] >= SOUS - largeur and not pleines.has(cas + d):
			return cas + d
	return cas


static func _coque_sous_voxels(pleines: Dictionary, retrait: float) -> ArrayMesh:
	var pleins: Dictionary = sous_voxels(pleines, retrait)
	var plafond: int = MB.plafond_de(pleines)

	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var couleurs := PackedColorArray()
	var pas: float = 1.0 / float(SOUS)
	for c in pleins:
		var s: Vector3i = c
		for axe in 3:
			for signe in [-1, 1]:
				var d := Vector3i.ZERO
				d[axe] = signe
				if pleins.has(s + d):
					continue
				var normale := Vector3.ZERO
				normale[axe] = float(signe)
				var autres: Array = []
				for k in 3:
					if k != axe:
						autres.append(k)
				var mini2: Vector3 = Vector3(s) * pas
				var maxi2: Vector3 = (Vector3(s) + Vector3.ONE) * pas
				var quad: Array = []
				for pas2 in [[0, 0], [0, 1], [1, 1], [1, 0]]:
					var q := Vector3.ZERO
					q[axe] = maxi2[axe] if signe > 0 else mini2[axe]
					q[autres[0]] = mini2[autres[0]] if pas2[0] == 0 else maxi2[autres[0]]
					q[autres[1]] = mini2[autres[1]] if pas2[1] == 0 else maxi2[autres[1]]
					quad.append(q)
				# ⚠ LA LÉGENDE EST PAR FACE, PLUS PAR CASE (27 septembre 2026) : une case de falaise
				# porte une paroi à l'air libre ET, s'il y a lieu, un sol de grotte. Voir
				# `MB.face_sous_le_ciel()` pour la règle, et pourquoi la version par case rayait les
				# falaises du monde peint.
				var vide: Vector3i = vide_borde(pleines, s + d, retrait)
				var dehors: bool = MB.face_sous_le_ciel(pleines, pleins[s], d, vide, plafond)
				# ⚠ On passe par `_quad` et non par une émission directe : c'est lui qui porte
				# l'enroulement HORAIRE de Godot et le codage couleur par normale.
				_quad(sommets, normales, couleurs, quad, normale, not dehors)

	var mesh := ArrayMesh.new()
	if sommets.is_empty():
		return mesh
	var tout: Array = []
	tout.resize(Mesh.ARRAY_MAX)
	tout[Mesh.ARRAY_VERTEX] = sommets
	tout[Mesh.ARRAY_NORMAL] = normales
	tout[Mesh.ARRAY_COLOR] = couleurs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tout)
	mesh.surface_set_material(0, RP.matiere())
	return mesh


## Pose un quadrilatère en deux triangles, orienté vers `normale`.
##
## ⚠ **GODOT ENROULE SES FACES AVANT DANS LE SENS HORAIRE** : le produit vectoriel de l'ordre stocké doit
## pointer À L'OPPOSÉ de la normale. Même règle et même piège que `repli_procedural._ajouter_quad`, où
## l'erreur inverse avait coûté une planche entière — le maillage restait cohérent avec lui-même, seul le
## moteur divergeait, et toutes les faces étaient éliminées par le `cull_mode`.
## ⚠ **`dedans` PORTE LA LÉGENDE DU TÉMOIN, ET IL A UNE VALEUR PAR DÉFAUT EXPRÈS.** `_coque_lissee` —
## le chanfrein mis en sommeil — appelle aussi cette fonction et ne connaît pas le contexte : sans
## défaut, j'aurais changé son rendu sans m'en apercevoir.
##
## ⚠ **ON MODULE LES TROIS TEINTES, ON N'EN AJOUTE PAS TROIS.** L'orientation reste lisible — vert pour
## ce qui regarde le ciel, brun pour les parois, bleu pour les plafonds — et le contexte se lit à la
## MATIÈRE : la roche souterraine est plus sombre et désaturée, comme une pierre jamais lessivée. Six
## teintes franches auraient rendu bariolé un témoin dont l'illisibilité est précisément le défaut qu'on
## corrige : 76 % du bloc est souterrain, et rien ne le disait à l'artiste — c'est ce qui lui a fait
## extruder le haut en croyant tenir le massif de base.
static func _quad(sommets: PackedVector3Array, normales: PackedVector3Array,
		couleurs: PackedColorArray, quad: Array, normale: Vector3, dedans := false) -> void:
	var a: Vector3 = quad[0]
	var b: Vector3 = quad[1]
	var c: Vector3 = quad[2]
	var ordre: Array = quad
	if (b - a).cross(c - a).dot(normale) > 0.0:
		ordre = [quad[3], quad[2], quad[1], quad[0]]
	# ⚠ **SIX TEINTES, PAS TROIS MODULÉES.** La modulation assombrissait la roche souterraine ; la lumière
	# directionnelle assombrit déjà les faces à l'ombre du même ordre, et les deux se confondaient. Les
	# six couleurs vivent dans `repli_procedural.gd`, qui est le vocabulaire des teintes de ce projet :
	# les inventer ici en ferait une seconde description, et elles divergeraient au premier réglage.
	var couleur: Color
	if normale.y > 0.5:
		couleur = RP.COULEUR_DESSUS_DEDANS if dedans else RP.COULEUR_DESSUS
	elif normale.y < -0.5:
		couleur = RP.COULEUR_PLAFOND_DEDANS if dedans else RP.COULEUR_PLAFOND
	else:
		couleur = RP.COULEUR_PAROI_DEDANS if dedans else RP.COULEUR_PAROI
	for triangle in [[0, 1, 2], [0, 2, 3]]:
		for k in triangle:
			sommets.append(ordre[k])
			normales.append(normale)
			couleurs.append(couleur)


## Le CENTRE d'un sous-voxel. ⚠ Le réseau dual siège sur les centres, pas sur les coins : c'est ce
## décalage d'un demi-sous-voxel qui fait qu'un sommet dual tombe AU MILIEU d'une marche, donc qu'une
## marche devient une pente au lieu de deux faces.
static func _centre(s: Vector3i, pas: float) -> Vector3:
	return (Vector3(s) + Vector3.ONE * 0.5) * pas


## LA COQUE LISSÉE — le maillage DUAL du champ de sous-voxels (« surface nets »).
##
## ⚠ **POURQUOI CETTE MÉTHODE PLUTÔT QUE LE GESTE LITTÉRAL (Jordan, 25 septembre 2026).** Jordan
## proposait de supprimer l'arête à angle droit d'une marche et de relier les deux arêtes restantes par
## une face directe, tout en prévoyant que *« là où trois contremarches se rencontrent, le triangle
## qu'on créera rendra beaucoup d'endroits non-manifold »*. Les deux moitiés de sa phrase sont justes,
## et il y a pire : **un palier large d'UN sous-voxel n'a qu'une face, réclamée par les chanfreins de
## ses DEUX côtés** — l'opération n'y est pas définie. Or c'est le cas majoritaire, mesuré :
## 91 paliers de largeur 1 sur 261.
##
## ⚠ **CETTE VOIE-CI REND SA PRÉDICTION STRUCTURELLEMENT IMPOSSIBLE, elle ne la contourne pas.** Un
## sommet par cube DUAL traversé, un quad par ARÊTE PRIMALE traversée. Une arête du maillage rendu
## sépare exactement deux quads duaux voisins : aucune troisième face ne peut s'y attacher. La
## non-manifoldité n'est donc pas évitée au cas par cas, elle n'a pas de place où naître.
##
## ⚠ **ET ELLE A UN COÛT QU'IL FAUT DIRE** : la surface se déplace d'un demi-sous-voxel au plus, PARTOUT
## — y compris sur les grandes faces plates. Le contrat de couture s'en juge par la mesure, pas par ce
## commentaire ; `sonde_lissage.gd` compare les classes récoltées avant et après.
##
## ⚠ `_coque_sous_voxels` RESTE INTACTE et reste ce qui part chez l'artiste. Ce qui marche ne doit pas
## dépendre d'une expérience en cours.
static func _coque_lissee(pleines: Dictionary, retrait: float, force := 1.0) -> ArrayMesh:
	var pleins: Dictionary = sous_voxels(pleines, retrait)
	var pas: float = 1.0 / float(SOUS)

	# ── 1. UN SOMMET PAR CUBE DUAL TRAVERSÉ ─────────────────────────────────────────────────────────
	#
	# Le cube dual `g` a pour coins les huit sous-voxels `g + (0..1)³`. S'ils ne sont pas tous du même
	# côté, la surface le traverse : on y pose UN sommet, à la moyenne des milieux d'arêtes traversées.
	# ⚠ Ne sont candidats que les cubes touchant un sous-voxel plein — les autres ne peuvent pas être
	# traversés, et les parcourir tous coûterait le volume entier pour rien.
	var candidats := {}
	for c in pleins:
		var s: Vector3i = c
		for dx in [-1, 0]:
			for dy in [-1, 0]:
				for dz in [-1, 0]:
					candidats[s + Vector3i(dx, dy, dz)] = true

	var sommet_de := {}
	for c in candidats:
		var g: Vector3i = c
		var somme := Vector3.ZERO
		var combien := 0
		for dx in 2:
			for dy in 2:
				for dz in 2:
					var d := Vector3i(dx, dy, dz)
					for axe in 3:
						if d[axe] != 0:
							continue
						var e := Vector3i.ZERO
						e[axe] = 1
						var a: Vector3i = g + d
						var b: Vector3i = a + e
						if pleins.has(a) == pleins.has(b):
							continue
						somme += (_centre(a, pas) + _centre(b, pas)) * 0.5
						combien += 1
		if combien > 0:
			# ⚠ **LE RÉGLAGE, ET IL PORTE SON PROPRE CONTRÔLE NÉGATIF.** Le centre du cube dual `g`
			# tombe exactement sur un COIN du réseau de sous-voxels — donc là où la coque à facettes
			# place ses sommets. À `force = 0` le lissage doit donc REPRODUIRE la coque à facettes,
			# pente pour pente ; s'il en reste une seule, le réglage ne fait pas ce qu'il dit et aucune
			# mesure prise avec lui ne porte sur ce qu'on croit. À `force = 1`, maillage dual complet.
			# ⚠ Il existe parce que l'image a tranché ce qu'aucun compteur ne disait : à pleine force,
			# la surface FOND au lieu de se chanfreiner — les contours droits deviennent ondulants.
			var coin: Vector3 = (Vector3(g) + Vector3.ONE) * pas
			sommet_de[g] = coin.lerp(somme / float(combien), clampf(force, 0.0, 1.0))

	# ── 2. UN QUAD PAR ARÊTE PRIMALE TRAVERSÉE ──────────────────────────────────────────────────────
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var couleurs := PackedColorArray()
	for c in pleins:
		var s: Vector3i = c
		for axe in 3:
			var e := Vector3i.ZERO
			e[axe] = 1
			for signe in [-1, 1]:
				var voisin: Vector3i = s + (e if signe > 0 else -e)
				if pleins.has(voisin):
					continue
				# le plus PETIT des deux bouts de l'arête primale, pour indexer les cubes duaux
				var base: Vector3i = s if signe > 0 else voisin
				var autres: Array = []
				for k in 3:
					if k != axe:
						autres.append(k)
				var coins: Array = []
				for uv in [[0, 0], [1, 0], [1, 1], [0, 1]]:
					var g: Vector3i = base
					g[autres[0]] = base[autres[0]] - 1 + int(uv[0])
					g[autres[1]] = base[autres[1]] - 1 + int(uv[1])
					if not sommet_de.has(g):
						coins = []
						break
					coins.append(sommet_de[g])
				# ⚠ Les quatre cubes duaux d'une arête traversée sont traversés eux aussi, par
				# construction : ce `continue` ne devrait JAMAIS servir. S'il servait, il ouvrirait un
				# trou — et `sonde_lissage.gd` le verrait en arêtes de BORD, jamais en silence.
				if coins.size() != 4:
					continue
				var normale := Vector3.ZERO
				normale[axe] = float(signe)
				_quad(sommets, normales, couleurs, coins, normale)

	var mesh := ArrayMesh.new()
	if sommets.is_empty():
		return mesh
	var tout: Array = []
	tout.resize(Mesh.ARRAY_MAX)
	tout[Mesh.ARRAY_VERTEX] = sommets
	tout[Mesh.ARRAY_NORMAL] = normales
	tout[Mesh.ARRAY_COLOR] = couleurs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tout)
	mesh.surface_set_material(0, RP.matiere())
	return mesh


## LE BLOC LISSÉ — même amincissement que `maillage_moitie`, mais les marches deviennent des pentes.
##
## `force` : 0 rend la coque à facettes à l'identique, 1 le maillage dual complet. ⚠ Entre les deux,
## c'est un CHANFREIN plutôt qu'un fondu — et c'est l'image, pas un compteur, qui a montré qu'il en
## fallait un réglage : à pleine force les contours droits deviennent ondulants et le trou rectangulaire
## d'une dalle devient un ovale.
##
## ⚠ **SUSPENDU — ESSAYÉ ET REPOSÉ LE 25 SEPTEMBRE 2026 (Jordan).** Il a été branché sur l'export une
## heure, puis débranché : *« je voulais plus aucun angle et tu as fait des angles moins obtus. »* Une
## marche remplacée par une pente reste une ARÊTE ; ce qui était demandé, c'est que les deux arêtes
## d'une marche FUSIONNENT en une face. Le maillage dual ne sait pas faire ça — il adoucit, il ne
## supprime pas. ⚠ **Le code reste, et les mesures avec** : elles sont justes, c'est l'objectif qu'elles
## n'atteignent pas. Jugé par `sonde_lissage.gd` pour les chiffres et `planche_lissage.gd` pour le reste.
static func maillage_lisse(i: int, cote := 0.5, force := 1.0) -> ArrayMesh:
	return _coque_lissee(cases(i), clampf(cote, 0.05, 1.0) * 0.5, force)


## DE COMBIEN LE TÉMOIN SERAIT CHANFREINÉ — ⚠ **RÉGLAGE SUSPENDU, plus branché sur rien** (voir
## `maillage_lisse`). Les mesures ci-dessous restent valides et sont gardées pour qui reprendra.
##
## ⚠ **CE NOMBRE EST MESURÉ, PAS CHOISI AU GOÛT.** Jordan voulait que les deux arêtes d'une marche
## soient reliées par une face DIRECTE, et prévoyait que les triangles aux coins à trois contremarches
## rendraient le maillage non-manifold. Il avait raison pour le geste littéral — et il y avait pire :
## un palier large d'UN sous-voxel n'a qu'une face, réclamée par les chanfreins de ses deux côtés, et
## c'est le cas majoritaire (91 paliers sur 261). D'où le maillage dual, où le cas n'existe pas.
##
## ⚠ **LE PLAFOND TECHNIQUE EST 0,60, ET IL A ÉTÉ MESURÉ EN BALAYANT** — jusqu'à 0,60 le lissé est
## strictement identique à la coque à facettes sur tout ce qui compte (8 364 quads, 0 orphelin, 89,3 %
## de valence 4, 18 arêtes ambiguës, 68 classes récoltées) ; à 0,80 les orphelins apparaissent (390),
## à 1,00 ils sont 528. **Le chanfrein ne coûte donc RIEN en deçà de 0,60.**
##
## ⚠ **ET LE PLAFOND ESTHÉTIQUE EST PLUS BAS QUE LE TECHNIQUE — seule l'image l'a dit.** À 1,00 la
## surface FOND : les contours droits ondulent, le trou rectangulaire d'une dalle devient un ovale, on
## ne lit plus des cases. À 0,60 l'ondulation commence. À 0,20 le chanfrein chuchote et ne montre plus
## rien à l'artiste. **0,35 est la seule valeur vue où les arêtes sont abattues ET le bloc reste
## lisible comme des cases.** ⚠ Aucun compteur ne pouvait trancher ça : celui des pentes SATURE — il
## dit SI une face penche, jamais DE COMBIEN — et rend 63,0 % à 0,35 comme 63,2 % à 1,00.
const FORCE_CHANFREIN := 0.35


## CE QUE LE TRANCHEUR RÉCOLTE : une pièce Marching Blocks par sommet intérieur, posée par sa classe et
## son orientation, exactement comme le monde le fera.
##
## ⚠ Ce maillage est NORMALEMENT PLUS PAUVRE que le solide, et ce n'est pas un défaut : un bloc ne livre
## que ce que ses sommets INTÉRIEURS voient. C'est précisément la mesure qui dit combien de classes un
## bloc rapporte — et le montrer à côté du solide dit à l'artiste quelle part de son sculpt est moissonnée.
static func maillage_des_pieces(i: int) -> ArrayMesh:
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var couleurs := PackedColorArray()
	var grille := GridMap.new()   # ⚠ seulement pour lire les bases d'orientation, jamais pour poser
	for p in pieces_de(i):
		var bits: int = MB.classes()[p["classe"]]["bits"]
		var morceau: ArrayMesh = RP.maillage(bits)
		if morceau.get_surface_count() == 0:
			continue
		var pose := Transform3D(
			grille.get_basis_with_orthogonal_index(p["orientation"]),
			Vector3(p["sommet"]) + Vector3.ONE)
		var arrays: Array = morceau.surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var c: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for k in v.size():
			sommets.append(pose * v[k])
			normales.append(pose.basis * n[k])
			couleurs.append(c[k])
	grille.free()

	var mesh := ArrayMesh.new()
	if sommets.is_empty():
		return mesh
	var tout: Array = []
	tout.resize(Mesh.ARRAY_MAX)
	tout[Mesh.ARRAY_VERTEX] = sommets
	tout[Mesh.ARRAY_NORMAL] = normales
	tout[Mesh.ARRAY_COLOR] = couleurs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tout)
	mesh.surface_set_material(0, RP.matiere())
	return mesh


## SOUDE UN MAILLAGE : les sommets de même position deviennent UN seul sommet, et la surface sort
## INDEXÉE. C'est ce qui en fait un objet modélisable — déplacer un sommet déplace toutes ses faces.
##
## ⚠ **UN MAILLAGE NON SOUDÉ SE DÉCHIRE AU PREMIER GESTE.** Les maillages du greffon sont bâtis face par
## face, chaque quad avec ses propres sommets : ouvert dans Blender, c'est une soupe de quads disjoints,
## et bouger un sommet ne bouge qu'un coin d'une seule face.
##
## ⚠ **CE QUE SOUDER COÛTE, ET C'EST INÉVITABLE : L'OMBRAGE PLAT.** Aux trois faces qui se rejoignent au
## coin d'un cube, la position est la même et la normale diffère. Un maillage indexé n'a qu'une normale
## par sommet : souder force donc une moyenne, donc un ombrage lissé. On choisit la TOPOLOGIE, parce
## qu'elle ne se récupère pas après coup, là où l'ombrage se corrige d'un « Shade Flat » dans Blender.
##
## ⚠ **ON GARDE LES NORMALES malgré ça**, au lieu de les omettre : le pipeline de RÉIMPORT s'en sert pour
## attribuer chaque triangle à son octant (`Tranchage.octant_du_triangle`). Un `.glb` sans normales
## casserait le contrôle des octants au retour — le tour complet ne passerait plus.
static func souder(mesh: ArrayMesh, epsilon := 0.00001) -> ArrayMesh:
	var positions := PackedVector3Array()
	var cumul_normales := PackedVector3Array()
	var couleurs := PackedColorArray()
	var indices := PackedInt32Array()
	var connus := {}
	var avait_des_couleurs := false

	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		if arrays.is_empty():
			continue
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if v.is_empty():
			continue
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] \
			if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var c: PackedColorArray = arrays[Mesh.ARRAY_COLOR] \
			if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		if not c.is_empty():
			avait_des_couleurs = true
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] \
			if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx = PackedInt32Array(range(v.size()))

		for k in idx:
			var p: Vector3 = v[k]
			# ⚠ LA CLÉ EST QUANTIFIÉE : comparer des flottants à l'identique ne fusionnerait rien, le
			# bruit de calcul suffisant à séparer deux sommets qu'on voit confondus.
			var cle := "%d,%d,%d" % [roundi(p.x / epsilon), roundi(p.y / epsilon), roundi(p.z / epsilon)]
			if not connus.has(cle):
				connus[cle] = positions.size()
				positions.append(p)
				cumul_normales.append(Vector3.ZERO)
				couleurs.append(c[k] if c.size() > k else Color.WHITE)
			var ou: int = connus[cle]
			indices.append(ou)
			if n.size() > k:
				cumul_normales[ou] = cumul_normales[ou] + n[k]

	if positions.is_empty():
		return ArrayMesh.new()

	var normales := PackedVector3Array()
	for k in cumul_normales.size():
		var somme: Vector3 = cumul_normales[k]
		normales.append(somme.normalized() if somme.length_squared() > 0.000001 else Vector3.UP)

	var sortie := ArrayMesh.new()
	var res: Array = []
	res.resize(Mesh.ARRAY_MAX)
	res[Mesh.ARRAY_VERTEX] = positions
	res[Mesh.ARRAY_NORMAL] = normales
	if avait_des_couleurs:
		res[Mesh.ARRAY_COLOR] = couleurs
	res[Mesh.ARRAY_INDEX] = indices
	sortie.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, res)
	var matiere: Material = mesh.surface_get_material(0) if mesh.get_surface_count() > 0 else null
	if matiere != null:
		sortie.surface_set_material(0, matiere)
	return sortie


## L'ÉTENDUE RÉELLEMENT OCCUPÉE par le bloc `i`, en cellules — DÉRIVÉE, jamais déclarée.
##
## ⚠ Elle diffère du cube `COTE³` dès qu'une couche de bord est vide : « massif et plateau » n'occupe
## que 4 × 3 × 4. C'est cette étendue-là que le trancheur compare au mesh réimporté, et c'est elle que
## le panneau doit afficher — annoncer 4 × 4 × 4 ferait croire à l'artiste qu'il doit remplir le haut.
static func dimensions(i: int) -> Vector3i:
	var pleines: Dictionary = cases(i)
	if pleines.is_empty():
		return Vector3i.ZERO
	var mini := Vector3i.ONE * COTE
	var maxi := Vector3i.ZERO
	for c in pleines:
		var p: Vector3i = c
		mini = Vector3i(mini_de(mini.x, p.x), mini_de(mini.y, p.y), mini_de(mini.z, p.z))
		maxi = Vector3i(maxi_de(maxi.x, p.x + 1), maxi_de(maxi.y, p.y + 1), maxi_de(maxi.z, p.z + 1))
	return maxi - mini


static func mini_de(a: int, b: int) -> int:
	return a if a < b else b


static func maxi_de(a: int, b: int) -> int:
	return a if a > b else b


## Les cellules VIDES du bloc `i`, au format que `Tranchage.trancher()` attend.
static func creuses(i: int) -> Array:
	var pleines: Dictionary = cases(i)
	var vides: Array = []
	for x in COTE:
		for y in COTE:
			for z in COTE:
				if not pleines.has(Vector3i(x, y, z)):
					vides.append(Vector3i(x, y, z))
	return vides


## LE BLOC AUX CELLULES RAMENÉES À LA MOITIÉ — chaque case pleine devient un cube de côté 0,5, centré
## dans sa case. Tranché ensuite, il donne un monde où l'on VOIT chaque morceau.
##
## ⚠ **C'EST L'ORDRE QUI FAIT QUE ÇA MARCHE, et mes deux tentatives précédentes le prenaient à l'envers.**
## On rétrécit AVANT le tranchage : chaque cube reste fermé, le trancheur coupe dedans, et les pièces
## voisines se rebouchent mutuellement comme d'habitude. Rétrécir les pièces APRÈS le tranchage les
## crevait, puisqu'elles sont ouvertes sur leurs faces de coupe (mesuré : aire 3,0 au lieu de 4,0).
## ⚠ **ON NE RENTRE QUE LES CÔTÉS QUI DONNENT SUR DU VIDE — c'est le paramètre `retrait` de la coque, et
## c'était toute la correction d'une version antérieure.** Elle rétrécissait les SIX côtés de chaque
## case sans regarder les voisins : deux cases pleines côte à côte se retrouvaient séparées par du vide,
## et le massif tombait en poussière de cases indépendantes. Une face partagée entre deux pleines reste
## intacte : seule la PEAU du massif rentre.
##
## ⚠ **ET UNE SECONDE VERSION ÉMETTAIT LES SIX FACES sans culler les internes**, au motif que culler
## ouvrirait des trous entre deux cases de retraits différents. C'était vrai — mesuré, 16 arêtes de
## bord — mais le remède était pire que le mal : 144 faces enterrées sur 216, et un maillage
## **non-manifold** que Blender transporte sans que personne ne les voie. La coque en sous-voxels ferme
## la surface sans culler ni boucher : il n'y a plus de choix à faire.
## LE TÉMOIN EN FACES DIRECTES — la version sans une seule marche.
##
## ⚠ **ELLE DÉLÈGUE À `RP.maillage_direct_du_bloc()` et ne recalcule RIEN.** La géométrie dérivée des
## bits vit dans `repli_procedural.gd` (c'est déjà « la tuile depuis ses 8 bits »), et `blocs_maitres`
## la précharge déjà — l'inverse ferait un cycle. Ce point d'entrée existe pour que les planches et
## l'export atteignent la face directe sans préchargement neuf.
static func maillage_direct(i: int) -> ArrayMesh:
	return RP.maillage_direct_du_bloc(cases(i), COTE)


## LE TÉMOIN CHANFREINÉ — le geste que Jordan a MODELÉ, reproduit à 1,5 % près.
##
## ⚠ **LA CIBLE N'EST PAS UNE INTENTION, C'EST UN MAILLAGE MESURÉ (26 septembre 2026).** Plutôt que de
## décrire ce qu'il appelait « les contremarches », Jordan a repris le témoin tel qu'il part et les a
## retirées lui-même dans Blender. Son résultat, relevé par `sonde_spectre_des_angles` :
##
## ```
##                       0° (plat)     45°       90° (mur)    aire
##   le témoin parti      158,25        —         227,00      385,3
##   LE SCULPT            138,75      27,31       203,53      370,1   ← la cible
##   cette fonction       136,94      29,32       201,11      368,4
## ```
##
## ⚠ **ET LA LARGEUR DU CHANFREIN N'EST PAS UN RÉGLAGE : C'EST LE PAS DE LA GRILLE.** La surface des
## faces directes passe par les MILIEUX des arêtes du réseau, donc couper un coin lui coûte exactement
## un pas de chaque côté. Au pas d'un sous-voxel (1/4 de case), le chanfrein sort DEUX FOIS trop large
## — 55,24 case² à 45° au lieu de 27,31 ; à `finesse = 2`, soit 1/8 de case, il tombe sur la cible. Il
## n'y a donc aucun nombre à choisir au goût, seulement une résolution à mesurer.
##
## ⚠ **AUCUNE CHIRURGIE DE MAILLAGE, ET C'EST TOUT L'INTÉRÊT.** Biseauter des arêtes à la main demande
## de recoudre les coins, et la charte §4 dit ce que ça coûte : non-manifold là où trois contremarches
## se rencontrent, et un palier d'un sous-voxel réclamé par les chanfreins de ses deux côtés. Ici on ne
## coupe rien — on remaille un champ plus fin avec le générateur qui existe déjà.
##
## ⚠ **TROIS CRAINTES, TOUTES LEVÉES PAR LA MESURE** (`sonde_chanfrein_sous_voxel.gd`) :
##   • les TROUS — `_direct_dans` n'émet rien sur un contact diagonal : **0 sommet muet sur 6 162** ;
##   • le RÉTRÉCISSEMENT — la boîte reste **(0,250 … 7,750)**, identique à l'aminci ;
##   • la COUTURE — **27 classes récoltées, 0 faute**, exactement comme l'aminci.
##
## ⚠ **CE QU'IL EN COÛTE, ET IL FAUT LE DIRE** : **×4 en triangles** (49 316 contre 12 328).
##
## ⚠ **ET CE QU'IL LUI MANQUE ENCORE** : la LÉGENDE. `maillage_direct_du_bloc` colorie par la seule
## NORMALE, donc trois teintes au lieu des six décidées le 25 septembre 2026 — la roche souterraine ne
## s'y distingue pas. C'est le même trou que `_coque_lissee`, et il se voit à l'image.
static func maillage_chanfreine(i: int, finesse := 2) -> ArrayMesh:
	var pas: int = SOUS * maxi(1, finesse)
	var champ: Dictionary = _affiner(sous_voxels(cases(i), 0.25), maxi(1, finesse))
	var brut: ArrayMesh = RP.maillage_direct_du_bloc(champ, COTE * pas)
	return _a_l_echelle(brut, 1.0 / float(pas))


## AFFINE un champ de voxels : chaque voxel devient `facteur³` voxels, exactement le même volume.
##
## ⚠ **ON SUBDIVISE PLUTÔT QUE DE RAPPELER `sous_voxels()` AVEC UN AUTRE `SOUS`.** Cette constante est
## lue par le mailleur, le trancheur et l'export : la faire varier changerait ce qui part chez
## l'artiste pour régler un chanfrein. La subdivision ne touche à rien d'autre.
static func _affiner(champ: Dictionary, facteur: int) -> Dictionary:
	if facteur <= 1:
		return champ
	var sortie := {}
	for c in champ:
		var p: Vector3i = c
		for i in facteur:
			for j in facteur:
				for k in facteur:
					sortie[Vector3i(p.x * facteur + i, p.y * facteur + j, p.z * facteur + k)] = true
	return sortie


## ⚠ **ON MET À L'ÉCHELLE LES SOMMETS, PAS LE NŒUD.** Une `Transform3D` sur un `MeshInstance3D`
## laisserait le maillage en unités de sous-voxel : le trancheur, qui reçoit le MAILLAGE et pas le
## nœud, travaillerait huit fois trop grand sans qu'aucune erreur ne le dise.
static func _a_l_echelle(mesh: ArrayMesh, facteur: float) -> ArrayMesh:
	if mesh.get_surface_count() == 0:
		return mesh
	var arrays: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var mis := PackedVector3Array()
	mis.resize(v.size())
	for i in v.size():
		mis[i] = v[i] * facteur
	arrays[Mesh.ARRAY_VERTEX] = mis
	var sortie := ArrayMesh.new()
	sortie.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	sortie.surface_set_material(0, RP.matiere())
	return sortie


static func maillage_moitie(i: int, cote := 0.5) -> ArrayMesh:
	return _coque_sous_voxels(cases(i), clampf(cote, 0.05, 1.0) * 0.5)


## LA BIBLIOTHÈQUE DU BLOC TÉMOIN — une `MeshLibrary` prête pour un `MassifPeint`.
##
## Rend {"lot": MeshLibrary, "erreurs": Array, "provenance": {classe: nom du bloc}, "manquantes": Array}.
##
## ⚠ **UN SEUL MODE, L'AMINCI (Jordan, 25 septembre 2026).** Un paramètre `moitie` laissait choisir entre
## le solide brut et les tuiles ramenées à la moitié de leur case. Le choix n'avait pas de second terme
## utile : l'aminci est ce qu'on exporte, ce qu'on peint, et ce sur quoi on se replie.
##
## ⚠ **ET CE PARAMÈTRE PORTAIT UN DÉFAUT RÉEL, pas seulement une option de trop** : l'export amincissait
## par défaut (`moitie := true`) tandis que le repli de `librairie_depuis_glb()` rendait le solide PLEIN
## (`moitie := false`). Un bloc absent du `.glb` revenait donc dans une géométrie DIFFÉRENTE de celle qui
## était partie, et la récolte changeait sans que rien ne le dise. Deux défauts qu'il fallait penser à
## garder d'accord ; un mode unique les rend identiques par construction.
##
## ⚠ **LA BOUCLE ET « LE PREMIER BLOC GAGNE » SURVIVENT À UN SEUL BLOC, ET C'EST VOULU.** Avec un unique
## bloc il n'y a plus de collision ; la garde reste parce que `BLOCS` peut regrossir, et qu'une règle
## d'arbitrage écrite vaut mieux qu'un ordre de parcours qui tranche en silence le jour où elle manque.
##
## ⚠ **AUCUN REPLI (Jordan, 23 septembre 2026).** Une classe qu'aucun bloc ne livre n'est PAS comblée
## par le calcul : elle est SIGNALÉE, et le peintre verra un cube rouge à cet endroit. Combler en
## silence rendrait le trou invisible jusqu'à ce qu'un joueur tombe dessus.
##
## ⚠ **ET CE BLOC EST FAIT DE CUBES : aucun réglage ne lui donnera des formes.** C'est un TÉMOIN, qui
## montre où sont les tuiles ; ce qui donnera des formes, c'est le relief sculpté par l'artiste, d'où
## l'aller-retour `.glb` (`exporter_le_bloc` / `librairie_depuis_glb`).
static func librairie() -> Dictionary:
	var Tranchage := load("res://addons/marchingblocks_core/tranchage.gd")
	var pieces := {}
	var provenance := {}
	var erreurs: Array = []
	# ⚠ **LES REMARQUES REMONTENT, ET ELLES ÉCRIVAIENT DANS LE VIDE.** Les deux appels ne passaient pas ce
	# paramètre : `verifier_couture` calculait ses relevés dans le tableau par DÉFAUT, neuf à chaque appel
	# et lu par personne. Le seul contrôle qui juge l'accord des coutures tournait donc pour rien.
	var remarques: Array = []
	var sources := {}

	for i in BLOCS.size():
		# ⚠ LA MÊME GÉOMÉTRIE QUE L'EXPORT : le catalogue avec lequel on peint doit être celui que
		# l'artiste va sculpter, sinon le témoin ment sur ce qu'on attend de lui. Les trois chemins —
		# export, catalogue, repli — lisent donc le même appel, et changer de géométrie veut dire les
		# changer tous les trois. Voir `maillage_lisse` pour le chanfrein, suspendu.
		var solide: ArrayMesh = maillage_moitie(i)
		var fautes: Array = []
		# ⚠ `peau = false` : on ne récolte que les sommets dont les huit cellules sont DANS le bloc.
		var du_bloc := {}
		var recolte: Dictionary = Tranchage.trancher(solide, Vector3i.ONE * COTE, 1.0,
			creuses(i), fautes, false, remarques, du_bloc, Vector3.ZERO)
		for f in fautes:
			erreurs.append("« %s » : %s" % [BLOCS[i]["nom"], f])
		for nom in recolte:
			if pieces.has(nom):
				continue   # le premier bloc gagne
			pieces[nom] = recolte[nom]
			sources[nom] = du_bloc[nom]
			provenance[nom] = BLOCS[i]["nom"]

	var resultat: Dictionary = _assembler(pieces, sources)
	resultat["erreurs"] = erreurs
	resultat["remarques"] = remarques
	resultat["provenance"] = provenance
	return resultat


## La méta d'un lot tranché : {nom de tuile: sommet du témoin d'où elle vient}.
const META_SOMMETS := "sommets_du_temoin"


## Monte la `MeshLibrary` à partir des pièces récoltées. ⚠ PARTAGÉ par `librairie()` et
## `librairie_depuis_glb()` (tranché ou lié) : deux montages séparés auraient divergé, et l'un des deux
## aurait fini par remettre un repli que l'autre refuse.
## `sources` — {clé: {"mesh", "sommet", …}} : d'où vient chaque tuile (le trancheur ou la relecture liée).
## ⚠ **UNE TUILE PAR CLÉ, DE NOM NU** (charte §3, 30 septembre 2026) : plus d'« exemplaires » `~k`.
static func _assembler(pieces: Dictionary, sources: Dictionary = {}) -> Dictionary:
	var lot := MeshLibrary.new()
	var manquantes: Array = []
	var variantes := 0
	var id := 0
	for c in MB.classes():
		# ⚠ **UNE CLASSE EN CONTACT DIAGONAL N'EST PAS « MANQUANTE » : ELLE EST HORS DU MONDE.** Le
		# témoin ne la porte pas, et c'est voulu (DÉCIDÉ, 25 septembre 2026). Le peintre qui en rencontre
		# une pose quand même un cube rouge — l'absence se voit toujours là où elle arrive.
		if not MB.porte_une_surface(c["bits"]) or not MB.sans_contact_diagonal(c["bits"]):
			continue
		var mesh: ArrayMesh = pieces.get(c["nom"], null)
		if mesh == null or mesh.get_surface_count() == 0:
			manquantes.append(c["nom"])   # ⚠ PAS de repli : l'absence doit se voir
		else:
			id = _poser_la_tuile(lot, id, c["nom"], mesh, c["bits"])
			id = _poser_les_variantes(lot, id, c["nom"], pieces, c["bits"])

		# ── LA VARIANTE D'AIR LIBRE ─────────────────────────────────────────────────────────────────
		#
		# ⚠ **UNE VARIANTE ABSENTE N'EST PAS UNE CLASSE MANQUANTE.** Le peintre cherche la variante puis
		# retombe sur le nom nu : un bloc qui ne montre jamais telle classe sous le ciel produit donc un
		# monde CORRECT, simplement sans distinction à cet endroit. La compter dans `manquantes` ferait
		# poser des cubes rouges pour une tuile que personne ne réclame — et une absence doit se voir,
		# mais seulement quand c'en est une.
		if not MB.exterieur_possible(c["bits"]):
			continue
		var dehors: ArrayMesh = pieces.get(MB.nom_en_contexte(c["nom"], true), null)
		if dehors == null or dehors.get_surface_count() == 0:
			continue
		id = _poser_la_tuile(lot, id, MB.nom_en_contexte(c["nom"], true), dehors, c["bits"])
		id = _poser_les_variantes(lot, id, MB.nom_en_contexte(c["nom"], true), pieces, c["bits"])
		variantes += 1

	# LA PROVENANCE : pour chaque tuile du lot (par son NOM), le sommet du témoin d'où elle vient. La légende
	# de l'atelier World la lit (« d'où vient cette tuile ? »). Elle voyage dans le cache avec le lot.
	var sommets := {}
	for item in lot.get_item_list():
		var nom: String = lot.get_item_name(item)
		if (sources.get(nom, {}) as Dictionary).has("sommet"):
			sommets[nom] = sources[nom]["sommet"]
	lot.set_meta(META_SOMMETS, sommets)
	return {"lot": lot, "manquantes": manquantes, "variantes": variantes}


## LES VARIANTES VOULUES d'une clé (4 octobre 2026) : `<clé>_var1`, `_var2`… tant qu'elles se suivent sans trou
## (`MB.nombre_de_variantes`, la règle du peintre). Rend l'`id` suivant.
static func _poser_les_variantes(lot: MeshLibrary, id: int, cle: String, pieces: Dictionary, bits: int) -> int:
	var n: int = MB.nombre_de_variantes(cle, pieces)
	for k in range(1, n + 1):
		var m: ArrayMesh = pieces[MB.nom_de_variante(cle, k)]
		if m == null or m.get_surface_count() == 0:
			break
		id = _poser_la_tuile(lot, id, MB.nom_de_variante(cle, k), m, bits)
	return id


## Pose la tuile d'une clé, de nom nu. Rend l'`id` suivant.
static func _poser_la_tuile(lot: MeshLibrary, id: int, cle: String, mesh: ArrayMesh, bits: int) -> int:
	lot.create_item(id)
	lot.set_item_name(id, cle)
	lot.set_item_mesh(id, mesh)
	lot.set_item_shapes(id, RP.collision(bits))
	return id + 1


## ── L'ALLER-RETOUR : UN SEUL `.glb` ─────────────────────────────────────────────────────────────────
##
## ⚠ **UNE BANDE A VÉCU ICI, ET ELLE N'A PLUS D'OBJET.** `PAS_DE_BANDE`, `origine_sur_la_bande`,
## `boite_sur_la_bande` et `maillage_de_la_bande` alignaient les NEUF blocs côte à côte, au pas de six
## cases, pour qu'un seul fichier les transporte tous. Avec un bloc unique il n'y a rien à aligner : le
## bloc est à l'origine, et la bande entière disparaît.
##
## ⚠ **CE QUI SURVIT DE SA LEÇON : le bloc est retrouvé par sa POSITION, jamais par son nom.** Dans un
## logiciel de modélisation on renomme, on joint, on fusionne sans y penser — un nom ne survit pas à une
## séance de travail, une place fixée si. C'est la doctrine du projet : on DÉDUIT plutôt qu'on déclare.
##
## ⚠ **ET « LE PREMIER BLOC GAGNE » DISPARAÎT AVEC ELLE.** Cette règle d'arbitrage existait parce qu'une
## même classe sortait de plusieurs blocs ; avec un seul, il n'y a plus de collision. **C'est une
## décision silencieuse de moins** — on l'écrit plutôt que de la laisser s'évaporer.

## De combien on élargit la boîte d'extraction, en cellules. ⚠ Le relief DÉBORDE légalement (règle (A)) :
## découper pile sur `COTE³` raboterait le travail de l'artiste au ras des bords.
const DEBORD_TOLERE := 0.5


## La boîte qui contient le bloc, débord compris. ⚠ Le bloc est à l'ORIGINE : c'est ce qui permet de le
## retrouver sans lire son nom.
static func boite_du_bloc() -> AABB:
	return AABB(-Vector3.ONE * DEBORD_TOLERE,
		Vector3.ONE * (float(COTE) + 2.0 * DEBORD_TOLERE))


## EXPORTE LE BLOC dans UN `.glb`. Rend "" si tout va bien, sinon la raison.
##
## ⚠ SANS PARENT VIDE : la racine de la scène est le `MeshInstance3D` lui-même, pas un `Node3D` qui
## arriverait dans Blender comme un Empty dont personne ne veut.
## ⚠ **IL PART TOUJOURS AMINCI (Jordan, 24 puis 25 septembre 2026)** : le bloc part avec ses tuiles de
## bordure ramenées à la moitié de leur case. L'artiste voit ainsi d'emblée la liberté qu'il a — la
## matière ne remplit pas sa case, il peut donc pousser, creuser, chanfreiner. Exporter des cubes pleins
## lui laisserait croire que la case est la limite.
## ⚠ **CE FUT D'ABORD UN DÉFAUT DE PARAMÈTRE, C'EST DÉSORMAIS LE SEUL MODE.** Un export capable de partir
## plein était une façon de mentir à l'artiste sur sa marge, pas une option qu'on avait envie d'offrir.
## SÉPARE UN MAILLAGE EN UNE SURFACE PAR TEINTE, chacune portant un matériau NOMMÉ.
##
## ⚠ **PARCE QU'UNE COULEUR DE SOMMET N'ARRIVE PAS CHEZ L'ARTISTE, ET C'EST MESURÉ.** Le témoin partait
## avec ses six teintes dans `COLOR_0` et ressortait **blanc** : le glTF n'avait aucun matériau, donc
## rien ne disait à quoi rattacher ces couleurs. Un matériau par teinte survit à tout importeur —
## et il fait mieux que porter la couleur : **il porte son NOM**. L'artiste lit
## « Wall - underground » dans sa liste de matériaux au lieu de deviner ce que le mauve veut dire.
##
## ⚠ **ON RETIRE `ARRAY_COLOR` EN CHEMIN, et ce n'est pas une économie.** La spécification glTF
## MULTIPLIE `COLOR_0` par la couleur de base du matériau : garder les deux donnerait la teinte au
## CARRÉ chez un lecteur conforme, donc un témoin plus sombre que celui qu'on a jugé à l'écran. Une
## seule source de couleur, et c'est le matériau.
##
## ⚠ **ET LES SIX NOMS VIVENT DANS `repli_procedural.gd`**, avec les six couleurs. Les réécrire ici en
## ferait une seconde description de la légende, et ce projet a déjà payé trois fois cette faute.
static func par_teinte(mesh: ArrayMesh) -> ArrayMesh:
	var paquets := {}
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		if arrays.is_empty():
			continue
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var c: PackedColorArray = arrays[Mesh.ARRAY_COLOR] 			if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var idx = arrays[Mesh.ARRAY_INDEX]
		var ordre: PackedInt32Array = (idx as PackedInt32Array) if idx != null 			else PackedInt32Array(range(v.size()))
		# ⚠ **PAR TRIANGLE, D'APRÈS SON PREMIER SOMMET.** Un triangle dont les trois sommets auraient
		# deux teintes différentes devrait être coupé ; ça n'arrive pas ici — le mailleur pose une
		# couleur par FACE — mais le dire évite qu'on croie la fonction plus générale qu'elle n'est.
		for t in range(0, ordre.size() - 2, 3):
			var teinte: Dictionary = RP.teinte_de(c[ordre[t]] if c.size() > ordre[t] else Color.WHITE)
			var nom: String = teinte["nom"]
			if not paquets.has(nom):
				# ⚠ **UN `Array` ET NON UN `PackedVector3Array`, ET CE N'EST PAS UN DÉTAIL DE GOÛT.**
				# Les tableaux compacts de GDScript sont des types VALEUR : relire
				# `paquets[nom]["sommets"]` en rend une COPIE, et tout ce qu'on y ajoute est perdu à la
				# ligne suivante. Mesuré à mes dépens — l'export sortait un `.glb` de 272 octets, six
				# surfaces vides, sans qu'aucune erreur ne parle de copie. `Array` est une référence.
				paquets[nom] = {"couleur": teinte["couleur"], "sommets": [], "indices": [], "connus": {}}
			# ⚠ **ON GARDE LA SOUDURE : un sommet par POSITION, et des INDICES.** Recopier les trois
			# sommets de chaque triangle défaisait `souder()` juste avant : le `.glb` partait en soupe de
			# triangles — 93 360 sommets pour 15 546 positions, chaque arête une couture dans Blender
			# (`sonde_soudure_glb.gd`, mesuré sur les OCTETS du fichier, 27 septembre 2026). La charte
			# disait « le .glb part soudé » ; c'était faux depuis l'ajout des teintes.
			var paquet: Dictionary = paquets[nom]
			for k in 3:
				var i_source: int = ordre[t + k]
				if not paquet["connus"].has(i_source):
					paquet["connus"][i_source] = paquet["sommets"].size()
					paquet["sommets"].append(v[i_source])
				paquet["indices"].append(paquet["connus"][i_source])

	var sortie := ArrayMesh.new()
	# ⚠ L'ordre des surfaces suit `RP.TEINTES`, pas celui du dictionnaire : deux exports du même bloc
	# doivent rendre le même fichier, sinon un `diff` de `.glb` ne veut plus rien dire.
	for teinte in RP.TEINTES:
		var nom: String = teinte["nom"]
		if not paquets.has(nom):
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(paquets[nom]["sommets"])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(paquets[nom]["indices"])
		sortie.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var matiere := StandardMaterial3D.new()
		matiere.resource_name = nom
		matiere.albedo_color = paquets[nom]["couleur"]
		sortie.surface_set_material(sortie.get_surface_count() - 1, matiere)
	return sortie


##
## ⚠ **LE TÉMOIN PART EN OBJ (Jordan, 27 septembre 2026), ET LE RETOUR RESTE EN .glb.** Mesuré dans
## Blender 5.1 : en glTF, un matériau est une primitive et Blender ne partage aucun sommet entre
## primitives — 6 610 coutures aux bords de couleur, même quand les six primitives lisent le MÊME tampon
## de sommets. Un sommet glTF porte une seule valeur par attribut ; tout ce qui change d'une face à
## l'autre (matériau, UV, couleur) coupe le maillage. L'OBJ, lui, fait référencer par ses faces une
## liste de sommets COMMUNE, matériau par face : 15 546 sommets, 0 couture, six matériaux nommés.
## Le témoin n'est qu'une ébauche — de la géométrie et six teintes — donc l'OBJ ne lui coûte rien.
## Le TRAVAIL revient en .glb, avec tout ce que le glTF porte (textures, UV, normales, matériaux).
## ⚠ `.glb` reste accepté ici pour les outils de `DEV_TOOLS/` qui relisent leur propre export : même
## maillage, même appel — seule l'écriture change.
static func exporter_le_bloc(chemin: String) -> String:
	var brut: ArrayMesh = maillage_moitie(0)
	var mesh: ArrayMesh = par_teinte(sans_normales(souder(brut)))
	if mesh.get_surface_count() == 0:
		return "le bloc est vide"
	if chemin.get_extension().to_lower() == "obj":
		return _ecrire_obj(mesh, chemin, _uv_du_temoin(0))
	var instance := MeshInstance3D.new()
	instance.name = "MasterBlock"
	instance.mesh = mesh
	var document := GLTFDocument.new()
	var etat := GLTFState.new()
	var err: int = document.append_from_scene(instance, etat)
	if err != OK:
		instance.free()
		return "append_from_scene a rendu %d" % err
	err = document.write_to_filesystem(etat, chemin)
	instance.free()
	if err != OK:
		return "write_to_filesystem a rendu %d pour « %s »" % [err, chemin]
	return ""


## ── LE TÉMOIN LIÉ — une tuile par clé, en copies liées (Jordan, 30 septembre 2026) ─────────────────
##
## Le témoin devient le MONDE PEINT DE SA PROPRE FORME : chaque sommet à surface (bords compris) porte
## une OCCURRENCE de la tuile de sa clé, et toutes les occurrences d'une clé partagent UN maillage. Dans
## Blender ce sont des copies liées (mesuré, charte §3) : on en sculpte une, toutes suivent.
##
## ⚠ **IL SE RELIT TUILE PAR TUILE, SANS TRANCHER.** Assembler les occurrences pour retrancher le tout
## couperait un relief qui déborde d'une tuile sur sa voisine et l'attribuerait à la voisine : ses copies
## ne seraient plus identiques, et le monde ne montrerait plus ce que montre le témoin — la promesse même
## des copies liées. Le tranchage reste pour un travail NON lié (tout joint en un objet).
## ⚠ **LA CLÉ D'UN NŒUD SE DÉDUIT DE SA POSITION, JAMAIS DE SON NOM** (§4) : le nœud est posé au centre de
## son sommet, tourné comme le peintre tourne la tuile. Les noms sont là pour l'artiste.


## Les occurrences du témoin `i` : [{sommet, cle, orientation}], dans l'ordre des sommets (x, y, z).
## ⚠ TOUS les sommets à surface, ceux du bord compris : le témoin lié les montre, et un joint de bord
## prouve un raccord comme un autre (`Tranchage.raccords_du_temoin` les compte aussi).
static func occurrences_du_temoin(i := 0) -> Array:
	var Tranchage := load("res://addons/marchingblocks_core/tranchage.gd")
	var pleines: Dictionary = cases(i)
	var plafond: int = MB.plafond_de(pleines)
	var vus := {}
	for c in pleines:
		for s in MB.sommets_de(c):
			vus[s] = true
	var sommets: Array = vus.keys()
	sommets.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return a.x < b.x or (a.x == b.x and (a.y < b.y or (a.y == b.y and a.z < b.z))))
	var sortie: Array = []
	for s in sommets:
		var r: Dictionary = Tranchage.cle_du_sommet(pleines, s, plafond)
		if not r.is_empty():
			sortie.append({"sommet": s, "cle": r["cle"], "orientation": r["orientation"]})
	return sortie


## LA TUILE DE CHAQUE CLÉ dans le témoin calculé : {clé: {"mesh" (repère de référence), "sommet"}}.
##
## ⚠ **C'EST LE TRANCHEUR QUI CHOISIT** (une tuile par clé, le sommet le plus PUR — `MB.purete`, charte §3) :
## cette fonction n'écrit aucune règle, elle rend ce que `Tranchage.trancher` a découpé. Une seconde règle
## de choix, ici, finirait par livrer d'autres tuiles que le lot du témoin (charte §6).
## ⚠ Pourquoi le plus pur : dans le témoin aminci, une tuile porte les marches que ses VOISINS y ont
## taillées ; celle d'un pied de pilier montrerait ce pilier absent à chacune de ses 244 occurrences.
static func tuiles_du_temoin() -> Dictionary:
	var Tranchage := load("res://addons/marchingblocks_core/tranchage.gd")
	var fautes: Array = []
	var remarques: Array = []
	var sources := {}
	Tranchage.trancher(maillage_moitie(0), Vector3i.ONE * COTE, 1.0, creuses(0), fautes, false, remarques,
		sources, Vector3.ZERO)
	return sources


## EXPORTE LE TÉMOIN LIÉ dans un `.glb`. Rend "" si tout va bien, sinon la raison.
##
## Une racine `MarchingBlocksWitness` à l'origine ; un enfant par occurrence, posé au centre de son
## sommet (`v + (1,1,1)`) et tourné comme le peintre ; un maillage PARTAGÉ par clé, nommé en anglais
## (`FormatNeutre.nom_de_tuile`), aux UV canoniques et aux six matériaux de la légende.
## ⚠ **L'EXPORT DE GODOT NE PARTAGE RIEN** — mesuré : 1 048 maillages pour 1 048 nœuds, même quand les
## `MeshInstance3D` portent le même `Mesh`. On relie dans le `GLTFState`, après `append_from_scene`.
## ⚠ **COUTURES AUX BORDS DE COULEUR, DANS UNE TUILE** : en glTF un matériau est une primitive (charte §4).
## Entre deux tuiles il n'y a de toute façon rien à souder — ce sont des objets. L'import de Blender
## « Merge Vertices » les recoud.
static func exporter_le_temoin_lie(chemin: String) -> String:
	var tuiles: Dictionary = tuiles_du_temoin()
	var atlas: Dictionary = atlas_du_temoin(0)
	var rang := {}
	for k in (atlas["cles"] as Array).size():
		rang[atlas["cles"][k]] = k
	var maillages := {}
	for cle in tuiles:
		maillages[cle] = _tuile_pour_l_artiste(tuiles[cle]["mesh"], int(rang.get(cle, atlas["cles"].size())),
			int(atlas["n"]))
	return ecrire_le_temoin_lie(chemin, maillages)


## ÉCRIT UN TÉMOIN LIÉ : `maillages` = {clé: ArrayMesh dans le repère de référence, matériaux compris}.
## ⚠ UNE SEULE ÉCRITURE pour l'export du témoin calculé et pour le témoin modélisé dans l'appli
## (`TemoinLie.vers_glb`) : deux écritures finiraient par poser les nœuds différemment.
## `affectation` = {sommet: k} : les occurrences qui montrent la VARIANTE k de leur clé (4 octobre 2026) — leur nœud
## reçoit le maillage `<clé>_var<k>`, nommé « …_var<k> » : c'est ce nom que la relecture lit (`tuiles_liees`).
static func ecrire_le_temoin_lie(chemin: String, maillages: Dictionary, affectation: Dictionary = {}) -> String:
	var FormatNeutre := load("res://addons/marchingblocks_core/format_neutre.gd")
	for cle in maillages:
		(maillages[cle] as ArrayMesh).resource_name = FormatNeutre.nom_de_tuile(cle)
	var grille := GridMap.new()
	var racine := Node3D.new()
	racine.name = "MarchingBlocksWitness"
	var cle_du_noeud := {}
	var n := 0
	# ⚠ SEULE LA PREMIÈRE OCCURRENCE D'UNE CLÉ PORTE SON MAILLAGE DANS LA SCÈNE (mesuré le 1er octobre 2026) :
	# `append_from_scene` convertit le maillage de CHAQUE nœud — 1 056 relectures depuis le GPU pour 52 maillages,
	# 1,1 s avec fenêtre. Les autres sont des `Node3D` qui reçoivent le maillage de leur clé dans l'état glTF,
	# plus bas : même fichier.
	var deja := {}
	for o in occurrences_du_temoin(0):
		if not maillages.has(o["cle"]):
			continue   # une clé que le témoin calculé ne livre pas : `librairie()` l'a déjà signalée
		var tuile: String = o["cle"]
		if affectation.has(o["sommet"]):
			var v: String = MB.nom_de_variante(o["cle"], int(affectation[o["sommet"]]))
			if maillages.has(v):
				tuile = v
		# ⚠ UN NŒUD CRÉÉ PUIS REMPLACÉ FUYAIT (mesuré le 2 octobre 2026 : 52 `Node3D` orphelins à chaque écriture, un
		# par clé, vus à la fermeture de l'appli) : on crée le bon nœud tout de suite.
		var mi: Node3D
		if not deja.has(tuile):
			deja[tuile] = true
			mi = MeshInstance3D.new()
			(mi as MeshInstance3D).mesh = maillages[tuile]
		else:
			mi = Node3D.new()
		mi.name = "%s_%d" % [maillages[tuile].resource_name, n]
		mi.transform = Transform3D(grille.get_basis_with_orthogonal_index(o["orientation"]),
			Vector3(o["sommet"]) + Vector3.ONE)
		racine.add_child(mi)
		mi.owner = racine
		cle_du_noeud[String(mi.name)] = tuile
		n += 1
	grille.free()
	var document := GLTFDocument.new()
	var etat := GLTFState.new()
	# Les PNG des textures, gardés d'une écriture à l'autre (`png_en_memoire.gd`) : même fichier, ~3 s de moins.
	var PngEnMemoire := load("res://addons/marchingblocks_core/png_en_memoire.gd")
	var ext: GLTFDocumentExtension = PngEnMemoire.brancher(document)
	var err: int = document.append_from_scene(racine, etat)
	if err != OK:
		PngEnMemoire.debrancher(ext)
		racine.free()
		return "append_from_scene a rendu %d" % err
	var anciens: Array = etat.get_meshes()
	var nouveaux: Array[GLTFMesh] = []
	var indice_de_cle := {}
	for nd: GLTFNode in etat.get_nodes():
		if nd.mesh < 0:
			continue
		var cle: String = cle_du_noeud.get(nd.resource_name, "")
		if cle == "":
			PngEnMemoire.debrancher(ext)
			racine.free()
			return "nœud inattendu dans l'état glTF : « %s »" % nd.resource_name
		if not indice_de_cle.has(cle):
			indice_de_cle[cle] = nouveaux.size()
			var gm: GLTFMesh = anciens[nd.mesh]
			gm.resource_name = maillages[cle].resource_name
			gm.original_name = maillages[cle].resource_name
			nouveaux.append(gm)
		nd.mesh = indice_de_cle[cle]
	for nd: GLTFNode in etat.get_nodes():
		if nd.mesh < 0 and cle_du_noeud.has(nd.resource_name):
			nd.mesh = indice_de_cle[cle_du_noeud[nd.resource_name]]
	etat.set_meshes(nouveaux)
	err = document.write_to_filesystem(etat, chemin)
	PngEnMemoire.debrancher(ext)
	racine.free()
	if err != OK:
		return "write_to_filesystem a rendu %d pour « %s »" % [err, chemin]
	return ""


## Une tuile telle qu'elle part chez l'artiste : une surface par TEINTE de la légende (matériau nommé,
## sans couleur de sommet — le glTF la multiplierait par celle du matériau), les UV canoniques, pas de
## normales (ombrage plat). Un sommet par (position, UV) : deux faces d'une même teinte qui ne partagent
## pas leur UV au coin gardent chacune le sien.
static func _tuile_pour_l_artiste(mesh: ArrayMesh, k: int, n: int) -> ArrayMesh:
	var paquets := {}
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var c: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null \
			else PackedColorArray()
		var idx = arrays[Mesh.ARRAY_INDEX]
		var ordre: PackedInt32Array = (idx as PackedInt32Array) if idx != null \
			else PackedInt32Array(range(v.size()))
		for t in range(0, ordre.size() - 2, 3):
			var a: Vector3 = v[ordre[t]]
			var b: Vector3 = v[ordre[t + 1]]
			var d: Vector3 = v[ordre[t + 2]]
			var teinte: Dictionary = RP.teinte_de(c[ordre[t]] if c.size() > ordre[t] else Color.WHITE)
			var nom: String = teinte["nom"]
			if not paquets.has(nom):
				paquets[nom] = {"couleur": teinte["couleur"], "sommets": [], "uv": [], "indices": [],
					"connus": {}}
			var paquet: Dictionary = paquets[nom]
			var uv: PackedVector2Array = _uv_de_la_piece(k, n, a, b, d)
			var trois: Array = [a, b, d]
			for j in 3:
				var p: Vector3 = trois[j]
				var cle := "%d|%d|%d|%d|%d" % [roundi(p.x * 100000.0), roundi(p.y * 100000.0),
					roundi(p.z * 100000.0), roundi(uv[j].x * 1000000.0), roundi(uv[j].y * 1000000.0)]
				if not paquet["connus"].has(cle):
					paquet["connus"][cle] = paquet["sommets"].size()
					paquet["sommets"].append(p)
					paquet["uv"].append(uv[j])
				paquet["indices"].append(paquet["connus"][cle])
	var sortie := ArrayMesh.new()
	for teinte in RP.TEINTES:
		var nom: String = teinte["nom"]
		if not paquets.has(nom):
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(paquets[nom]["sommets"])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(paquets[nom]["uv"])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(paquets[nom]["indices"])
		sortie.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var matiere := StandardMaterial3D.new()
		matiere.resource_name = nom
		matiere.albedo_color = paquets[nom]["couleur"]
		sortie.surface_set_material(sortie.get_surface_count() - 1, matiere)
	return sortie


## LE TÉMOIN LIÉ RELU : {} si le fichier n'en est pas un (le travail se tranche alors comme avant), sinon
## {"pieces": {clé: mesh}, "sources": {clé: {mesh, sommet}}, "occurrences", "hors"}.
##
## ⚠ **C'EN EST UN SI LA MAJORITÉ DE SES OBJETS TOMBE SUR LES PLACES DU TÉMOIN** (le centre d'un sommet à
## surface) : déduit, pas déclaré. Un objet ailleurs — un rocher, un reste — est compté dans `hors`, et
## la remarque le dit ; les props entiers (§9 bis) ne sont pas encore écrits.
## ⚠ **LA TUILE D'UNE CLÉ EST CE QUE MONTRENT SES OCCURRENCES, RAMENÉ À LA RÉFÉRENCE** : pour chaque nœud,
## (pose attendue)⁻¹ × (pose lue) × maillage. Des copies encore liées donnent la même chose par
## construction ; des copies DÉLIÉES (Join, Apply, Make Single User) aussi, tant qu'elles n'ont pas
## divergé. Une occurrence qui diffère — sculptée seule, déplacée, tournée — est une ERREUR : on garde ce
## que montre le plus grand nombre, et on le dit. Jamais départagées en silence.
static func tuiles_liees(chemin: String, erreurs: Array, remarques: Array) -> Dictionary:
	if chemin.get_extension().to_lower() != "glb" and chemin.get_extension().to_lower() != "gltf":
		return {}
	var document := GLTFDocument.new()
	var etat := GLTFState.new()
	# Les images déjà décodées sont reprises (`images_relues.gd` : ~300 ms de PNG à chaque passage dans World).
	var images := ImagesRelues.brancher()
	var lu := document.append_from_file(chemin, etat)
	ImagesRelues.debrancher(images)
	if lu != OK:
		return {}
	var noeuds: Array = etat.get_nodes()
	var maillages: Array = etat.get_meshes()
	var poses: Array = []
	poses.resize(noeuds.size())
	for i in noeuds.size():
		poses[i] = _pose_gltf(noeuds, i, poses)

	var occurrence_de := {}
	for o in occurrences_du_temoin(0):
		occurrence_de[o["sommet"]] = o
	var grille := GridMap.new()
	var par_cle := {}
	var affectation := {}
	var porteurs := 0
	var hors := 0
	for i in noeuds.size():
		var nd: GLTFNode = noeuds[i]
		if nd.mesh < 0:
			continue
		porteurs += 1
		var pose: Transform3D = poses[i]
		var sommet := Vector3i((pose.origin - Vector3.ONE).round())
		if pose.origin.distance_to(Vector3(sommet) + Vector3.ONE) > 0.01 or not occurrence_de.has(sommet):
			hors += 1
			continue
		var o: Dictionary = occurrence_de[sommet]
		var attendue := Transform3D(grille.get_basis_with_orthogonal_index(o["orientation"]),
			Vector3(sommet) + Vector3.ONE)
		# ⚠ UNE VARIANTE SE RECONNAÎT AU NOM DE SON MAILLAGE (4 octobre 2026) — « <tuile de la clé>_var<k> », un
		# « .001 » de Blender toléré. C'est la seule chose qui se DÉCLARE ici : la clé, elle, vient toujours de la
		# position. Un nom perdu (Join, Make Single User renommé) ramène la copie à sa clé, où elle diverge : c'est
		# l'erreur « ne montrent plus la même tuile », jamais un départage en silence.
		var tuile: String = o["cle"]
		var k: int = _variante_du_maillage(maillages[nd.mesh] as GLTFMesh, o["cle"])
		if k > 0:
			tuile = MB.nom_de_variante(o["cle"], k)
			affectation[sommet] = k
		if not par_cle.has(tuile):
			par_cle[tuile] = []
		par_cle[tuile].append({"sommet": sommet, "mesh": nd.mesh,
			"vers_reference": attendue.affine_inverse() * pose})
	grille.free()
	# ⚠ **LA MOITIÉ DES PLACES DU TÉMOIN, PAS SEULEMENT LA MOITIÉ DES OBJETS** : un bloc d'un seul tenant
	# posé à l'origine tombe pile sur la place du sommet (−1,−1,−1), qui porte une surface — vu rougir
	# (`test_blocs_maitres` §17). Un seul objet bien placé ne fait pas un témoin lié.
	if porteurs == 0 or hors * 2 >= porteurs or (porteurs - hors) * 2 < occurrence_de.size():
		return {}

	var pieces := {}
	var sources := {}
	var tableaux := {}   # clé → les tableaux de surface de sa tuile, quand ils sont ceux du maillage
	var pleines: Dictionary = cases(0)
	var cles: Array = par_cle.keys()
	cles.sort()
	for cle in cles:
		var liste: Array = par_cle[cle]
		# Même maillage et même passage à la référence : même tuile, sans rien recalculer.
		var familles := {}
		for e in liste:
			var t: Transform3D = e["vers_reference"]
			var pas := Vector3.ONE * 0.0001
			var cle_pose := "%d|%s|%s|%s|%s" % [e["mesh"], t.basis.x.snapped(pas), t.basis.y.snapped(pas),
				t.basis.z.snapped(pas), t.origin.snapped(pas)]
			if not familles.has(cle_pose):
				familles[cle_pose] = {"exemple": e, "nombre": 0}
			familles[cle_pose]["nombre"] += 1
		# Puis par la GÉOMÉTRIE : des copies déliées mais identiques restent une seule tuile.
		# ⚠ SUR LES TABLEAUX, PAS SUR DES `ArrayMesh` (mesuré le 1er octobre 2026) : relire un maillage qu'on vient
		# de fabriquer le redescend du GPU — trois fois par tuile (forme, normales, sections), 0,9 s avec fenêtre
		# à chaque enregistrement. Le maillage se fabrique une fois, à la fin, depuis les mêmes tableaux.
		var par_forme := {}
		for fp in familles:
			var e: Dictionary = familles[fp]["exemple"]
			var surfaces: Array = []
			for sf in _surfaces_lues((maillages[e["mesh"]] as GLTFMesh).mesh):
				surfaces.append([_tableaux_poses(sf[0], e["vers_reference"]), sf[1]])
			var empreinte: String = _empreinte_de_tableaux(surfaces.map(func(sf): return sf[0]))
			if not par_forme.has(empreinte):
				par_forme[empreinte] = {"surfaces": surfaces, "nombre": 0, "sommet": e["sommet"]}
			par_forme[empreinte]["nombre"] += int(familles[fp]["nombre"])
		var gagnante := ""
		for f in par_forme:
			if gagnante == "" or int(par_forme[f]["nombre"]) > int(par_forme[gagnante]["nombre"]):
				gagnante = f
		if par_forme.size() > 1:
			erreurs.append(("« %s » : ses %d occurrences ne montrent plus la même tuile (%d formes) — une copie "
				+ "sculptée seule, déplacée ou tournée ; on garde celle du plus grand nombre (%d)")
				% [cle, liste.size(), par_forme.size(), par_forme[gagnante]["nombre"]])
		var surfaces_gagnantes: Array = par_forme[gagnante]["surfaces"]
		var tuile: ArrayMesh = _mesh_de_surfaces(surfaces_gagnantes)
		if not surfaces_gagnantes.is_empty() and surfaces_gagnantes[0][0][Mesh.ARRAY_NORMAL] == null:
			tuile = normales_plates(tuile)
		else:
			tableaux[cle] = surfaces_gagnantes.map(func(sf): return sf[0])
		_rendre_la_legende(tuile)
		# La provenance : l'occurrence la plus pure, pour que « d'où vient cette tuile ? » montre un coin
		# lisible du témoin.
		var sommet: Vector3i = liste[0]["sommet"]
		for e in liste:
			if MB.purete(pleines, e["sommet"]) < MB.purete(pleines, sommet):
				sommet = e["sommet"]
		pieces[cle] = tuile
		sources[cle] = {"mesh": tuile, "sommet": sommet}
	if hors > 0:
		remarques.append(("objets : %d objet(s) ne sont sur aucune place du témoin et sont ignorés — un prop "
			+ "entier (rocher, décor) n'est pas encore pris en charge") % hors)
	return {"pieces": pieces, "sources": sources, "occurrences": porteurs - hors, "hors": hors, "tableaux": tableaux,
		"affectation": affectation}


## Le rang de variante qu'un maillage glTF porte pour la clé `cle` (0 : la tuile de base, ou un nom qui n'en est pas une).
static func _variante_du_maillage(gm: GLTFMesh, cle: String) -> int:
	var FormatNeutre := load("res://addons/marchingblocks_core/format_neutre.gd")
	var nom: String = gm.original_name if gm.original_name != "" else gm.resource_name
	var point := nom.rfind(".")
	if point > 0 and nom.substr(point + 1).is_valid_int():
		nom = nom.substr(0, point)
	var base: String = FormatNeutre.nom_de_tuile(cle) + MB.SUFFIXE_VARIANTE
	if not nom.begins_with(base):
		return 0
	var reste := nom.substr(base.length())
	if reste.length() != 1 or not reste.is_valid_int():
		return 0
	var k := int(reste)
	return k if k >= 1 and k <= MB.VARIANTES_MAXI else 0


## Les surfaces d'un maillage importé, [[tableaux, matériau]…] — un `ImporterMesh` se lit sans GPU.
static func _surfaces_lues(brut: Variant) -> Array:
	var sortie: Array = []
	if brut is ImporterMesh:
		var im := brut as ImporterMesh
		for s in im.get_surface_count():
			var arrays: Array = im.get_surface_arrays(s)
			if not arrays.is_empty():
				sortie.append([arrays, im.get_surface_material(s)])
		return sortie
	var m: ArrayMesh = _en_array_mesh(brut)
	if m != null:
		for s in m.get_surface_count():
			sortie.append([m.surface_get_arrays(s), m.surface_get_material(s)])
	return sortie


static func _mesh_de_surfaces(surfaces: Array) -> ArrayMesh:
	var sortie := ArrayMesh.new()
	for sf in surfaces:
		sortie.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sf[0])
		if sf[1] != null:
			sortie.surface_set_material(sortie.get_surface_count() - 1, sf[1])
	return sortie


## LA LÉGENDE DU MODELEUR RETROUVE SA COULEUR DE SOMMET. Il l'écrit en UN matériau (« legend »), les teintes dans
## la couleur des sommets ; mesuré le 1er octobre 2026 : relu par l'import glTF de Godot, ce matériau revenait SANS
## `vertex_color_use_as_albedo` — blanc dans le monde, teinté dans le modeleur. C'est notre matériau, on le sait.
static func _rendre_la_legende(tuile: ArrayMesh) -> void:
	var ME := load("res://addons/marchingblocks_core/maillage_edite.gd")
	var nom: String = ME.materiau_de_legende().resource_name
	for s in tuile.get_surface_count():
		var m := tuile.surface_get_material(s) as BaseMaterial3D
		# ⚠ ET LES AUTRES SANS : l'import met ce drapeau sur TOUS les matériaux ; un fichier revenu de Blender qui
		# porte des couleurs de sommet aurait alors multiplié les matériaux de l'artiste par elles. Dans le
		# modeleur, seule la légende lit la couleur de sommet : le monde fait pareil.
		if m != null:
			m.vertex_color_use_as_albedo = m.resource_name == nom


## La pose d'un nœud glTF dans la scène, parents compris. `poses` sert de mémoire (les parents d'abord).
static func _pose_gltf(noeuds: Array, i: int, poses: Array) -> Transform3D:
	if poses[i] != null:
		return poses[i]
	var nd: GLTFNode = noeuds[i]
	var pose: Transform3D = nd.xform
	if nd.parent >= 0:
		pose = _pose_gltf(noeuds, nd.parent, poses) * pose
	poses[i] = pose
	return pose


## L'empreinte d'une forme : ses triangles (au dix-millième), triés — indépendante de l'ordre des sommets,
## des surfaces et des indices. Deux copies déliées d'une même tuile ont la même.
static func _empreinte_de_forme(mesh: ArrayMesh) -> String:
	var liste: Array = []
	for s in mesh.get_surface_count():
		liste.append(mesh.surface_get_arrays(s))
	return _empreinte_de_tableaux(liste)


static func _empreinte_de_tableaux(liste: Array) -> String:
	var tris: Array = []
	for arrays in liste:
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx = arrays[Mesh.ARRAY_INDEX]
		var ordre: PackedInt32Array = (idx as PackedInt32Array) if idx != null \
			else PackedInt32Array(range(v.size()))
		for t in range(0, ordre.size() - 2, 3):
			var coins: Array = []
			for j in 3:
				var p: Vector3 = v[ordre[t + j]]
				coins.append("%d,%d,%d" % [roundi(p.x * 10000.0), roundi(p.y * 10000.0), roundi(p.z * 10000.0)])
			# le triangle commence par son plus petit coin, sans changer son sens
			var m: int = 0
			for j in 3:
				if coins[j] < coins[m]:
					m = j
			tris.append("%s;%s;%s" % [coins[m], coins[(m + 1) % 3], coins[(m + 2) % 3]])
	tris.sort()
	return ";".join(PackedStringArray(tris)).md5_text()


## ── LES UV CANONIQUES DU TÉMOIN — PROPOSÉ (28 septembre 2026) ──────────────────────────────────────
##
## ⚠ **TOUS LES EXEMPLAIRES D'UNE CLÉ PARTAGENT LES MÊMES UV.** L'UV d'un point ne dépend que de sa clé,
## de sa position ramenée à la RÉFÉRENCE de la pièce (la rotation inverse que le trancheur applique) et du
## sens de sa face. Peindre une copie peint donc les 541 — c'est le « mode canonique » de la charte §3,
## sans rien griser : 52 tuiles à peindre, et chacune identique partout où elle revient.
## ⚠ **CE QUE ÇA NE FAIT PAS : SUPPRIMER LES RACCORDS.** La région d'une clé touche celles de TOUTES ses
## voisines possibles ; le long des coupes, la texture doit rester la même pour toutes (charte §3, la
## discipline de l'artiste). Ce qui disparaît, c'est la texture qui doit se répéter PARTOUT.
##
## L'atlas : un carré de `n × n` tuiles, six par clé (une par sens de face : +X, −X, +Y, −Y, +Z, −Z),
## rangées clé après clé ; la DERNIÈRE clé est réservée aux sommets de bord, que le trancheur ne récolte
## pas (`peau = false`) — ils ont besoin d'une UV, pas d'une place qui en volerait une à une vraie tuile.
## ⚠ La coque amincie est faite de faces ALIGNÉES sur les axes, en sous-voxels : une face n'a qu'un sens, et
## dans une pièce, une colonne n'a qu'une transition de chaque signe — les six projections ne se
## recouvrent pas. Gardé par `test_blocs_maitres`, pas par ce commentaire.

## La marge intérieure de chaque tuile d'atlas, en fraction de tuile : le filtrage ne bave pas sur la voisine.
const UV_MARGE := 1.0 / 16.0

## Les clés du bloc `i`, dans l'ordre de l'atlas : ordre de `MB.classes()`, le nom nu avant l'air libre.
## ⚠ DÉRIVÉ du trancheur (`cle_du_sommet`), jamais écrit : deux listes de clés finiraient par diverger.
static func cles_de_l_atlas(i: int) -> Array:
	var Tranchage := load("res://addons/marchingblocks_core/tranchage.gd")
	var pleines: Dictionary = cases(i)
	var plafond: int = MB.plafond_de(pleines)
	var vues := {}
	for vx in COTE - 1:
		for vy in COTE - 1:
			for vz in COTE - 1:
				var r: Dictionary = Tranchage.cle_du_sommet(pleines, Vector3i(vx, vy, vz), plafond)
				if not r.is_empty():
					vues[r["cle"]] = true
	var ordre: Array = []
	for c in MB.classes():
		for cle in [c["nom"], MB.nom_en_contexte(c["nom"], true)]:
			if vues.has(cle) and not ordre.has(cle):
				ordre.append(cle)
	return ordre


## LA DISPOSITION DE L'ATLAS du bloc `i` : {"cles": [...], "n": côté de la grille, en tuiles}.
## ⚠ UNE SEULE description : `_uv_du_temoin` la lit, et quiconque veut peindre l'atlas aussi.
static func atlas_du_temoin(i: int) -> Dictionary:
	var cles: Array = cles_de_l_atlas(i)
	var n: int = ceili(sqrt(float((cles.size() + 1) * 6)))
	n += (6 - n % 6) % 6   # les six sens d'une clé sur une même ligne
	return {"cles": cles, "n": n}


## La fonction qui donne ses trois UV à un triangle du témoin `i` (sommets dans l'ordre HORAIRE de Godot).
## ⚠ **LE BLOC EST À L'ORIGINE** (§4) : la case `p` occupe [p ; p+1], et le sommet `v` a pour boîte le
## cube d'une case centré en `v + (1,1,1)` — les mêmes conventions que `Tranchage.boite_du_sommet`.
static func _uv_du_temoin(i: int) -> Callable:
	var Tranchage := load("res://addons/marchingblocks_core/tranchage.gd")
	var pleines: Dictionary = cases(i)
	var plafond: int = MB.plafond_de(pleines)
	var atlas: Dictionary = atlas_du_temoin(i)
	var cles: Array = atlas["cles"]
	var rang := {}
	for k in cles.size():
		rang[cles[k]] = k
	var reservee: int = cles.size()
	var n: int = atlas["n"]
	var grille := GridMap.new()
	var bases := {}
	for o in 24:
		bases[o] = grille.get_basis_with_orthogonal_index(o)
	grille.free()
	return func(a: Vector3, b: Vector3, c: Vector3) -> PackedVector2Array:
		var centre: Vector3 = (a + b + c) / 3.0
		var v := Vector3i(floori(centre.x - 0.5), floori(centre.y - 0.5), floori(centre.z - 0.5))
		var interieur: bool = v.x >= 0 and v.y >= 0 and v.z >= 0 \
			and v.x < COTE - 1 and v.y < COTE - 1 and v.z < COTE - 1
		var r: Dictionary = Tranchage.cle_du_sommet(pleines, v, plafond) if interieur else {}
		var k: int = rang.get(r.get("cle", ""), reservee)
		var inverse: Basis = (bases[r["orientation"]] as Basis).transposed() if not r.is_empty() \
			else Basis()
		var centre_du_sommet: Vector3 = Vector3(v) + Vector3.ONE
		return _uv_de_la_piece(k, n, inverse * (a - centre_du_sommet), inverse * (b - centre_du_sommet),
			inverse * (c - centre_du_sommet))


## LES UV D'UN TRIANGLE DE PIÈCE, dans le repère de RÉFÉRENCE de sa clé (centré sur le sommet), sommets
## dans l'ordre HORAIRE de Godot. `k` est le rang de la clé dans l'atlas, `n` son côté en tuiles.
## ⚠ **UNE SEULE RÈGLE POUR L'OBJ ET POUR LE TÉMOIN LIÉ** : `_uv_du_temoin` y ramène un triangle du bloc,
## `exporter_le_temoin_lie` un triangle de tuile, déjà dans ce repère. Deux copies divergeraient.
## ⚠ Une rotation garde le produit vectoriel : la normale se calcule aussi bien après qu'avant.
static func _uv_de_la_piece(k: int, n: int, qa: Vector3, qb: Vector3, qc: Vector3) -> PackedVector2Array:
	# Godot enroule en HORAIRE : la normale sortante est l'OPPOSÉ du produit vectoriel.
	var normale: Vector3 = -(qb - qa).cross(qc - qa)
	var axe: int = 0
	for j in 3:
		if absf(normale[j]) > absf(normale[axe]):
			axe = j
	var sens: int = axe * 2 + (0 if normale[axe] > 0.0 else 1)
	var tuile: int = k * 6 + sens
	var coin := Vector2(tuile % n, tuile / n)
	var sortie := PackedVector2Array()
	for q in [qa, qb, qc]:
		var st: Vector2
		match sens:
			0: st = Vector2(-q.z, q.y)
			1: st = Vector2(q.z, q.y)
			2: st = Vector2(q.x, -q.z)
			3: st = Vector2(q.x, q.z)
			4: st = Vector2(q.x, q.y)
			_: st = Vector2(-q.x, q.y)
		var dans: Vector2 = (st + Vector2.ONE * 0.5).clamp(Vector2.ZERO, Vector2.ONE)
		sortie.append((coin + Vector2.ONE * UV_MARGE + dans * (1.0 - 2.0 * UV_MARGE)) / float(n))
	return sortie


## L'OBJ DU TÉMOIN : une liste de sommets COMMUNE, puis les faces de chaque teinte sous son `usemtl`.
## Le `.mtl` voisin porte les six teintes, NOMMÉES comme la légende (« Wall - underground »).
##
## ⚠ **SOUDÉ PAR CONSTRUCTION** : un sommet par POSITION (clé quantifiée, comme `souder()`), sur tout le
## fichier et pas surface par surface — c'est tout l'intérêt du format.
## ⚠ **L'ENROULEMENT EST RETOURNÉ** : Godot tient ses faces avant dans le sens HORAIRE, l'OBJ et Blender
## dans le sens trigonométrique. Le glTF de Godot le retournait sans le dire ; ici on le fait.
## ⚠ **AUCUNE NORMALE** (`vn`) : sans elles, Blender importe en ombrage PLAT — mesuré, comme le .glb.
## ⚠ Des TRIANGLES, comme le .glb d'avant : « Tris to Quads » (Alt+J) rend les boucles d'arêtes.
## ⚠ **`uv_de` DONNE LES UV D'UN TRIANGLE** (`_uv_du_temoin`) : elles s'écrivent en `vt`, par COIN de face.
## C'est ce qui garde la soudure — un sommet sur un plan de coupe porte deux UV, une par pièce, sans être
## dédoublé. Le glTF, lui, l'aurait coupé en deux (charte §4).
static func _ecrire_obj(mesh: ArrayMesh, chemin: String, uv_de := Callable()) -> String:
	var mtl_chemin: String = chemin.get_basename() + ".mtl"
	var lignes := PackedStringArray()
	lignes.append("# MarchingBlocks — the witness block. Sculpt it, keep it at the origin.")
	lignes.append("mtllib " + mtl_chemin.get_file())
	lignes.append("o MasterBlock")
	var index_de := {}
	var sommets := PackedStringArray()
	var index_uv := {}
	var coords := PackedStringArray()
	var faces := PackedStringArray()
	var matieres := PackedStringArray()
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx = arrays[Mesh.ARRAY_INDEX]
		var ordre: PackedInt32Array = (idx as PackedInt32Array) if idx != null \
			else PackedInt32Array(range(v.size()))
		var m: Material = mesh.surface_get_material(s)
		var nom: String = m.resource_name if m != null and m.resource_name != "" else "surface_%d" % s
		var couleur: Color = (m as StandardMaterial3D).albedo_color if m is StandardMaterial3D else Color.WHITE
		matieres.append("newmtl %s\nKd %.4f %.4f %.4f\nKa 0 0 0\nKs 0 0 0\nd 1\nillum 1\n"
			% [nom, couleur.r, couleur.g, couleur.b])
		faces.append("usemtl " + nom)
		for t in range(0, ordre.size() - 2, 3):
			var n := PackedInt32Array()
			for k in 3:
				var p: Vector3 = v[ordre[t + k]]
				var cle := "%d,%d,%d" % [roundi(p.x * 100000.0), roundi(p.y * 100000.0), roundi(p.z * 100000.0)]
				if not index_de.has(cle):
					index_de[cle] = index_de.size() + 1
					sommets.append("v %.6f %.6f %.6f" % [p.x, p.y, p.z])
				n.append(index_de[cle])
			if not uv_de.is_valid():
				faces.append("f %d %d %d" % [n[0], n[2], n[1]])
				continue
			var uv: PackedVector2Array = uv_de.call(v[ordre[t]], v[ordre[t + 1]], v[ordre[t + 2]])
			var m_uv := PackedInt32Array()
			for k in 3:
				# ⚠ **L'OBJ COMPTE `v` DEPUIS LE BAS, Godot et le glTF depuis le HAUT.** Écrire l'UV telle
				# quelle retournait la texture : peinte dans Blender sur l'OBJ, elle revenait à l'envers
				# par le .glb. On écrit donc 1 − v, et `_lire_obj` le défait.
				var cle_uv := "%.6f %.6f" % [uv[k].x, 1.0 - uv[k].y]
				if not index_uv.has(cle_uv):
					index_uv[cle_uv] = index_uv.size() + 1
					coords.append("vt " + cle_uv)
				m_uv.append(index_uv[cle_uv])
			faces.append("f %d/%d %d/%d %d/%d" % [n[0], m_uv[0], n[2], m_uv[2], n[1], m_uv[1]])
	lignes.append_array(sommets)
	lignes.append_array(coords)
	lignes.append_array(faces)
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	if f == null:
		return "« %s » ne s'écrit pas (erreur %d)" % [chemin, FileAccess.get_open_error()]
	f.store_string("\n".join(lignes) + "\n")
	f.close()
	var g := FileAccess.open(mtl_chemin, FileAccess.WRITE)
	if g == null:
		return "« %s » ne s'écrit pas (erreur %d)" % [mtl_chemin, FileAccess.get_open_error()]
	g.store_string("# MarchingBlocks — the six tile families of the witness.\n" + "\n".join(matieres))
	g.close()
	return ""


## LIRE UN OBJ — celui qu'on a écrit, ou celui qu'un artiste renverrait. Une surface par `usemtl`,
## sa couleur lue dans le `.mtl` voisin s'il existe ; des normales PLATES reconstruites (`normales_plates`).
## ⚠ Les faces à plus de trois sommets sont découpées en éventail. Des références `v/vt/vn`, on garde la
## position et l'UV — le trancheur les transporte (`decoupe.gd`), et une UV perdue au retour, c'est une
## texture perdue sans un mot. Une surface dont une face n'a pas d'UV sort SANS UV. ⚠ Les indices NÉGATIFS (relatifs à la fin)
## sont permis par le format, donc lus. ⚠ L'enroulement est retourné vers la convention HORAIRE de Godot.
static func _lire_obj(chemin: String, journal: Array = []) -> ArrayMesh:
	var texte := FileAccess.get_file_as_string(chemin)
	if texte == "":
		journal.append("le fichier OBJ est vide ou illisible : %s" % chemin)
		return null
	var positions := PackedVector3Array()
	var coords := PackedVector2Array()
	var couleurs := {}
	var par_matiere := {}
	var uv_par_matiere := {}
	var sans_uv := {}
	var ordre_matieres: Array = []
	var courante := ""
	for ligne in texte.split("\n"):
		var l := ligne.strip_edges()
		if l.begins_with("mtllib "):
			couleurs.merge(_lire_mtl(chemin.get_base_dir().path_join(l.substr(7).strip_edges())))
		elif l.begins_with("v "):
			var c := l.substr(2).split(" ", false)
			if c.size() >= 3:
				positions.append(Vector3(float(c[0]), float(c[1]), float(c[2])))
		elif l.begins_with("vt "):
			var c := l.substr(3).split(" ", false)
			if c.size() >= 2:
				coords.append(Vector2(float(c[0]), 1.0 - float(c[1])))   # `v` depuis le bas, voir l'écriture
		elif l.begins_with("usemtl "):
			courante = l.substr(7).strip_edges()
		elif l.begins_with("f "):
			var ids := PackedInt32Array()
			var ids_uv := PackedInt32Array()
			for jeton in l.substr(2).split(" ", false):
				var morceaux := jeton.split("/")
				var i := int(morceaux[0])
				ids.append(i - 1 if i > 0 else positions.size() + i)
				var j := int(morceaux[1]) if morceaux.size() > 1 and morceaux[1] != "" else 0
				ids_uv.append(j - 1 if j > 0 else (coords.size() + j if j < 0 else -1))
			if not par_matiere.has(courante):
				par_matiere[courante] = PackedVector3Array()
				uv_par_matiere[courante] = PackedVector2Array()
				ordre_matieres.append(courante)
			var sac: PackedVector3Array = par_matiere[courante]
			var sac_uv: PackedVector2Array = uv_par_matiere[courante]
			for k in range(1, ids.size() - 1):
				for c in [0, k + 1, k]:
					var i: int = ids[c]
					if i < 0 or i >= positions.size():
						journal.append("une face de l'OBJ cite un sommet qui n'existe pas (%d)" % (i + 1))
						return null
					sac.append(positions[i])
					var j: int = ids_uv[c]
					if j < 0 or j >= coords.size():
						sans_uv[courante] = true
						sac_uv.append(Vector2.ZERO)
					else:
						sac_uv.append(coords[j])
			par_matiere[courante] = sac
			uv_par_matiere[courante] = sac_uv
	if ordre_matieres.is_empty():
		journal.append("l'OBJ ne contient aucune face : %s" % chemin)
		return null
	var mesh := ArrayMesh.new()
	for nom in ordre_matieres:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = par_matiere[nom]
		if not sans_uv.has(nom):
			arrays[Mesh.ARRAY_TEX_UV] = uv_par_matiere[nom]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var m := StandardMaterial3D.new()
		m.resource_name = nom
		m.albedo_color = couleurs.get(nom, Color.WHITE)
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	return normales_plates(mesh)


static func _lire_mtl(chemin: String) -> Dictionary:
	var couleurs := {}
	if not FileAccess.file_exists(chemin):
		return couleurs
	var courante := ""
	for ligne in FileAccess.get_file_as_string(chemin).split("\n"):
		var l := ligne.strip_edges()
		if l.begins_with("newmtl "):
			courante = l.substr(7).strip_edges()
		elif l.begins_with("Kd ") and courante != "":
			var c := l.substr(3).split(" ", false)
			if c.size() >= 3:
				couleurs[courante] = Color(float(c[0]), float(c[1]), float(c[2]))
	return couleurs


## LA BIBLIOTHÈQUE BÂTIE DEPUIS LE BLOC SCULPTÉ — le retour de Blender.
##
## Rend {"lot", "erreurs", "provenance", "manquantes", "sculptes", "absents"}.
##
## ⚠ **UN BLOC DONT LA BOÎTE RESSORT VIDE EST SIGNALÉ, pas remplacé en silence.** C'est le piège de
## toute cette boucle : si l'artiste déplace le bloc dans Blender, sa boîte se vide, le greffon retombe
## sur la version calculée, et tout semble marcher alors que son travail n'est pas dans le lot.
static func librairie_depuis_glb(chemin: String) -> Dictionary:
	var Tranchage := load("res://addons/marchingblocks_core/tranchage.gd")
	var journal: Array = []
	var pieces := {}
	var provenance := {}
	var erreurs: Array = []
	var sculptes: Array = []
	var absents: Array = []

	# ⚠ LE TÉMOIN LIÉ D'ABORD (charte §3, 30 septembre 2026) : il se relit tuile par tuile, sans trancher.
	var remarques_liees: Array = []
	var lie: Dictionary = tuiles_liees(chemin, erreurs, remarques_liees)
	if not lie.is_empty():
		var bits_par_nom := {}
		for c in MB.classes():
			bits_par_nom[c["nom"]] = c["bits"]
		Tranchage.verifier_sections(lie["pieces"], bits_par_nom, remarques_liees, lie.get("tableaux", {}))
		Tranchage.verifier_couture_texture(lie["pieces"], remarques_liees, lie.get("tableaux", {}))
		var assemble: Dictionary = _assembler(lie["pieces"], lie["sources"])
		assemble["erreurs"] = erreurs
		assemble["remarques"] = remarques_liees
		var prov := {}
		for cle in lie["pieces"]:
			prov[cle] = BLOCS[0]["nom"]
		assemble["provenance"] = prov
		assemble["sculptes"] = [BLOCS[0]["nom"]]
		assemble["absents"] = []
		assemble["lie"] = true
		assemble["occurrences"] = lie["occurrences"]
		return assemble

	var solide: ArrayMesh = travail_depuis_glb(chemin, journal)
	# ⚠ ON REMONTE LE MOTIF PRÉCIS, jamais « illisible » : les trois échecs possibles n'ont ni la même
	# cause ni le même remède, et l'appelant doit pouvoir le dire à l'artiste.
	for j in journal:
		erreurs.append("lecture de « %s » : %s" % [chemin.get_file(), j])
	if solide != null:
		sculptes.append(BLOCS[0]["nom"])
	if solide == null:
		absents.append(BLOCS[0]["nom"])
		# ⚠ **LE MÊME AMINCI QUE L'EXPORT, ET C'EST UNE CORRECTION.** Ce repli rendait le solide PLEIN
		# alors que le bloc était parti aminci : le témoin de secours n'avait donc pas la géométrie du
		# témoin exporté, et la récolte pouvait différer sans qu'aucun compteur ne le signale. Les deux
		# chemins sont maintenant le même appel, donc d'accord par construction et non par vigilance.
		solide = maillage_moitie(0)

	var fautes: Array = []
	var remarques: Array = []
	var sources := {}
	# ⚠ LE BLOC EST À L'ORIGINE (§4) : on le dit au trancheur, au lieu de le lui faire déduire d'une boîte
	# que le relief de l'artiste a le droit de déformer.
	var recolte: Dictionary = Tranchage.trancher(solide, Vector3i.ONE * COTE, 1.0,
		creuses(0), fautes, false, remarques, sources, Vector3.ZERO)
	# ⚠ **UN TRAVAIL NON LIÉ NE LIVRE QU'UNE COPIE PAR TUILE, ET ON LE DIT** (charte §3) : un bloc d'un seul
	# tenant (tout joint, ou un .obj) montre chaque tuile à plusieurs endroits ; le trancheur n'en lit que la
	# plus lisible. Ce que l'artiste a sculpté ailleurs n'arrive pas dans le monde — l'absence doit se voir.
	var cles_a_plusieurs := 0
	for cle in sources:
		if int(sources[cle].get("copies", 1)) > 1:
			cles_a_plusieurs += 1
	if not sculptes.is_empty() and cles_a_plusieurs > 0:
		remarques.append(("non lié : ce travail est d'un seul tenant, et %d tuile(s) y apparaissent à plusieurs "
			+ "endroits ; seule la copie la plus lisible de chacune est lue. Exporte le témoin LIÉ pour que "
			+ "chaque copie soit la même tuile") % cles_a_plusieurs)
	for f in fautes:
		erreurs.append("« %s » : %s" % [BLOCS[0]["nom"], f])
	# ⚠ ON LE DIT : plusieurs objets sont tous du terrain tant que les props entiers (§9 bis) n'existent
	# pas — un rocher rangé à part sera tranché, et c'est une demi-coque qui reviendra.
	var objets: int = solide.get_meta("objets", 1)
	if objets > 1:
		remarques.append("objets : le fichier en porte %d, tous tranchés comme du terrain — " % objets
			+ "un prop entier (rocher, décor) n'est pas encore pris en charge")
	for nom in recolte:
		pieces[nom] = recolte[nom]
		provenance[nom] = BLOCS[0]["nom"]

	var resultat: Dictionary = _assembler(pieces, sources)
	resultat["erreurs"] = erreurs
	resultat["remarques"] = remarques
	resultat["provenance"] = provenance
	resultat["sculptes"] = sculptes
	resultat["absents"] = absents
	return resultat


## DE COMBIEN LE TRAVAIL S'ÉCARTE DU TÉMOIN : les positions de sommets (au millième) qu'il porte et
## que le témoin exporté n'a pas. 0 veut dire « aucun sommet n'a bougé » — le tranchage rendra alors
## les tuiles du témoin, et c'est normal.
##
## ⚠ **ELLE EXISTE PARCE QU'UN « ÇA FAIT LA MÊME CHOSE » N'A PAS PU ÊTRE TRANCHÉ À L'ŒIL** (27 septembre
## 2026) : le fichier importé avait d'abord une géométrie IDENTIQUE au témoin (0 position nouvelle),
## puis, réexporté sept minutes plus tard avec un bevel, 7 123 positions nouvelles et 47 tuiles sur 52
## différentes. Sans ce chiffre à l'écran, rien ne distinguait les deux cas.
static func ecart_au_temoin(travail: ArrayMesh) -> int:
	var temoin := {}
	var ref: ArrayMesh = maillage_moitie(0)
	for s in ref.get_surface_count():
		for p in (ref.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			temoin[Vector3i(roundi(p.x * 1000.0), roundi(p.y * 1000.0), roundi(p.z * 1000.0))] = true
	var nouvelles := {}
	for s in travail.get_surface_count():
		for p in (travail.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			var k := Vector3i(roundi(p.x * 1000.0), roundi(p.y * 1000.0), roundi(p.z * 1000.0))
			if not temoin.has(k):
				nouvelles[k] = true
	return nouvelles.size()


## LE TRAVAIL DE L'ARTISTE tel que le trancheur le lira : le `.glb` relu, découpé dans la boîte
## tolérante du bloc. `null` si le fichier est illisible — le motif va alors dans `journal` — ou si la
## boîte ressort VIDE, et `journal` reste alors vide : un bloc absent n'est pas une erreur de lecture,
## `librairie_depuis_glb()` le range dans `absents`, comme avant cette extraction.
##
## ⚠ **UNE SEULE LECTURE POUR L'ÉCRAN ET POUR LE TRANCHEUR.** Le bouton « Importer le travail » l'affiche,
## « Trancher, générer et peindre » le tranche : si l'un lisait autrement que l'autre, l'artiste verrait
## une chose et en peindrait une autre, sans qu'aucune erreur ne le dise (charte §6).
static func travail_depuis_glb(chemin: String, journal: Array = []) -> ArrayMesh:
	var Decoupe := load("res://addons/marchingblocks_core/decoupe.gd")
	var relu: ArrayMesh = _lire_glb(chemin, journal)
	if relu == null:
		return null
	# ⚠ On découpe quand même dans une boîte tolérante : le relief déborde légalement, et un `.glb`
	# revenu de Blender peut traîner des restes hors du bloc.
	var extrait: ArrayMesh = Decoupe.trancher(relu, boite_du_bloc())
	if extrait.get_surface_count() == 0:
		return null
	extrait.set_meta("objets", relu.get_meta("objets", 1))
	return extrait


## RETIRE LES NORMALES d'un maillage — ce qui, en glTF, veut dire « ombrage PLAT ».
##
## ⚠ **C'EST CE QUI DONNE À LA FOIS LA TOPOLOGIE SOUDÉE ET LES ARÊTES FRANCHES**, et je m'étais trompé
## en annonçant qu'il fallait choisir. Souder impose une normale moyenne par sommet, donc un ombrage
## lissé : les blocs arrivaient dans Blender avec des arêtes molles. Mais la spécification glTF dit
## qu'un maillage SANS normales se rend en ombrage plat, calculé par face. On ne choisit donc plus.
##
## ⚠ **CE N'ÉTAIT PAS POSSIBLE CE MATIN.** `verifier_octants` lisait alors les normales du tableau pour
## attribuer un triangle posé sur un plan de coupe ; un fichier sans normales aurait cassé le retour.
## Depuis la correction (B), il les CALCULE à partir des sommets — le pipeline ne dépend plus du fichier.
## ⚠ **ET LES TANGENTES AVEC, CE QUE J'AVAIS OUBLIÉ.** Retirer les normales seules laissait Godot écrire
## un attribut `TANGENT` dans le glTF — mesuré en lisant le JSON du fichier. Une tangente sans normale
## n'a aucun sens, et un logiciel de modélisation peut s'en servir pour reconstruire un repère : c'est
## une seconde source d'ombrage tordu, là où l'on voulait justement n'en laisser aucune.
static func sans_normales(mesh: ArrayMesh) -> ArrayMesh:
	var sortie := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		if arrays.is_empty():
			continue
		arrays[Mesh.ARRAY_NORMAL] = null
		arrays[Mesh.ARRAY_TANGENT] = null
		sortie.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		# ⚠ **LE MATÉRIAU SE REPORTE, ET L'OUBLIER A COÛTÉ LA LÉGENDE ENTIÈRE.** Reconstruire une
		# surface par `add_surface_from_arrays` ne transporte QUE les tableaux : le matériau reste sur
		# la source. Le témoin partait donc sans matériau, le glTF sortait avec `materials: []`, et les
		# six teintes décidées le 25 septembre n'arrivaient jamais chez l'artiste — sans qu'aucune
		# erreur ne le dise, puisque `COLOR_0` était bien là.
		var matiere: Material = mesh.surface_get_material(s)
		if matiere != null:
			sortie.surface_set_material(sortie.get_surface_count() - 1, matiere)
	return sortie


## RECONSTRUIT DES NORMALES PLATES : chaque triangle reçoit sa normale géométrique sur ses trois sommets.
##
## ⚠ **SANS ÇA, RETIRER LES NORMALES À L'EXPORT CASSERAIT LE RETOUR.** Un `.glb` sans normales relu tel
## quel donnerait des pièces sans normales, donc un rendu faux dans le jeu. Blender, lui, en écrit
## toujours — mais on ne va pas faire dépendre la justesse du lot de ce que l'outil d'en face a bien
## voulu écrire.
##
## ⚠ Le maillage sort DÉ-INDEXÉ, et c'est nécessaire : l'ombrage plat demande une normale par FACE, ce
## qu'un sommet partagé entre trois faces ne peut pas porter.
##
## ⚠ **UNE SURFACE EN SORTIE PAR SURFACE EN ENTRÉE, CHACUNE AVEC SON MATÉRIAU — CORRIGÉ LE 27 SEPTEMBRE
## 2026.** Elle fondait tout en UNE surface sous le matériau de la première. Or le témoin exporté porte
## SIX surfaces, une par teinte nommée (`par_teinte`) : relu sans passer par Blender, il revenait
## entièrement « Floor - open air », vert. Mesuré : 6 primitives dans le fichier, 1 surface relue.
## Un `.glb` revenu de Blender, lui, porte ses normales et ne passe pas ici — c'est pourquoi le défaut
## ne se voyait que sur nos propres exports.
static func normales_plates(mesh: ArrayMesh) -> ArrayMesh:
	var sortie := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		if arrays.is_empty():
			continue
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if v.is_empty():
			continue
		var c: PackedColorArray = arrays[Mesh.ARRAY_COLOR] \
			if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var avait_des_couleurs: bool = not c.is_empty()
		# ⚠ LES UV SUIVENT, comme les couleurs : cette fonction est sur le chemin du RETOUR, et une UV
		# perdue ici, c'est la peinture de l'artiste perdue sans un mot.
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] \
			if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var avait_des_uv: bool = not uv.is_empty()
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] \
			if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx = PackedInt32Array(range(v.size()))

		var sommets := PackedVector3Array()
		var normales := PackedVector3Array()
		var couleurs := PackedColorArray()
		var coords := PackedVector2Array()
		for t in range(0, idx.size() - 2, 3):
			var a: Vector3 = v[idx[t]]
			var b: Vector3 = v[idx[t + 1]]
			var d: Vector3 = v[idx[t + 2]]
			# ⚠ MÊME CONVENTION QUE PARTOUT : Godot enroule ses faces avant dans le sens HORAIRE, donc
			# la sortante est l'OPPOSÉ du produit vectoriel de l'ordre stocké.
			var geo: Vector3 = -(b - a).cross(d - a)
			var normale: Vector3 = geo.normalized() if geo.length_squared() > 0.000000001 \
				else Vector3.UP
			for k in 3:
				sommets.append(v[idx[t + k]])
				normales.append(normale)
				if avait_des_couleurs:
					couleurs.append(c[idx[t + k]] if c.size() > idx[t + k] else Color.WHITE)
				if avait_des_uv:
					coords.append(uv[idx[t + k]] if uv.size() > idx[t + k] else Vector2.ZERO)
		if sommets.is_empty():
			continue
		var res: Array = []
		res.resize(Mesh.ARRAY_MAX)
		res[Mesh.ARRAY_VERTEX] = sommets
		res[Mesh.ARRAY_NORMAL] = normales
		if avait_des_couleurs:
			res[Mesh.ARRAY_COLOR] = couleurs
		if avait_des_uv:
			res[Mesh.ARRAY_TEX_UV] = coords
		sortie.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, res)
		# ⚠ **LE MATÉRIAU SUIT, ET SON OUBLI S'EST VU À L'IMAGE.** Sans lui, la planche est sortie
		# entièrement GRISE : les couleurs de sommet étaient bien là, mais aucun matériau en
		# `vertex_color_use_as_albedo` ne les lisait. ⚠ Et ce n'était pas qu'esthétique — cette fonction
		# est appelée à la LECTURE d'un `.glb`, donc les pièces d'un réimport auraient perdu leur matière.
		var matiere: Material = mesh.surface_get_material(s)
		sortie.surface_set_material(sortie.get_surface_count() - 1,
			matiere if matiere != null else RP.matiere())
	return sortie


## Le premier maillage d'un `.glb` quelconque du disque, ou `null`.
##
## ⚠ **ON RECONSTRUIT LES NORMALES SI LE FICHIER N'EN PORTE PAS.** C'est le cas de nos propres exports,
## volontairement dépouillés pour obtenir un ombrage plat dans Blender.
## ⚠ **`journal` DIT LEQUEL DES TROIS ÉCHECS, ET SON ABSENCE M'A COÛTÉ UN DIAGNOSTIC.** Cette fonction
## confondait « le fichier ne se lit pas », « la scène ne se construit pas » et « la scène n'a aucun
## maillage » dans un seul `null`, que l'appelant traduisait par « illisible ou ne contient aucun
## maillage ». Or ces trois-là n'ont ni la même cause ni le même remède — et le même fichier passait en
## ligne de commande tout en échouant dans l'éditeur, ce qui rendait la distinction indispensable.
static func _lire_glb(chemin: String, journal: Array = []) -> ArrayMesh:
	if not FileAccess.file_exists(chemin):
		journal.append("le fichier n'existe pas : %s" % chemin)
		return null
	# ⚠ UN OBJ EST ACCEPTÉ AU RETOUR, en plus du .glb : c'est le format dans lequel le témoin part, et un
	# artiste peut le renvoyer tel quel. Le .glb reste le retour normal — il porte textures et UV.
	if chemin.get_extension().to_lower() == "obj":
		return _lire_obj(chemin, journal)
	var document := GLTFDocument.new()
	var etat := GLTFState.new()
	var err: int = document.append_from_file(chemin, etat)
	if err != OK:
		journal.append("append_from_file a rendu %d (le fichier n'est pas lisible comme glTF)" % err)
		return null
	var scene: Node = document.generate_scene(etat)
	if scene == null:
		journal.append("generate_scene rend null (la scène n'a pas pu être construite — "
			+ "matériaux ou textures ?)")
		return null
	var trouve: ArrayMesh = _tous_les_maillages(scene)
	# ⚠ ON COMPTE CE QUI PORTE UN MAILLAGE, pas ce qui est d'une classe donnée — c'est la distinction qui
	# manquait, et qui a fait dire « 0 » alors que la scène était pleine d'`ImporterMeshInstance3D`.
	var porteurs := 0
	var types: Array = []
	for n in _tous_les_noeuds(scene):
		if n.get("mesh") != null:
			porteurs += 1
			if not types.has(n.get_class()):
				types.append(n.get_class())
	scene.queue_free()
	if trouve == null:
		journal.append("la scène est construite mais aucun maillage exploitable : "
			+ "%d nœud(s) porteur(s), de type(s) %s" % [porteurs, str(types)])
		return null
	# ⚠ ON LE DIT À VOIX HAUTE. Ce chemin ne s'exerce que sur un fichier sans normales — nos propres
	# exports. Sans cette trace, une suite verte pourrait ne jamais l'avoir emprunté, et je l'ai déjà
	# annoncé « vérifié » à tort une fois aujourd'hui.
	if trouve.get_surface_count() > 0 \
			and trouve.surface_get_arrays(0)[Mesh.ARRAY_NORMAL] == null:
		print("   (lecture : le fichier ne porte pas de normales — reconstruction en ombrage PLAT)")
		var objets: int = trouve.get_meta("objets", 1)
		trouve = normales_plates(trouve)
		trouve.set_meta("objets", objets)
	return trouve


## Tous les nœuds d'une scène, pour compter ce qu'on y a trouvé quand on n'y trouve pas ce qu'on cherche.
static func _tous_les_noeuds(racine: Node) -> Array:
	var liste: Array = [racine]
	for enfant in racine.get_children():
		liste.append_array(_tous_les_noeuds(enfant))
	return liste


## LE PREMIER MAILLAGE D'UNE SCÈNE IMPORTÉE, quel que soit le type de nœud qui le porte.
##
## ⚠ **NE CHERCHER QUE `MeshInstance3D` FAISAIT ÉCHOUER L'IMPORT DANS L'ÉDITEUR — ET NULLE PART
## AILLEURS.** Mesuré (Jordan, 24 septembre 2026) : le même `.glb`, lu par le même code, rendait
## 9 blocs et 68 classes en ligne de commande, et « aucun maillage » dans le greffon. La sonde a compté
## **zéro `MeshInstance3D`** dans la scène construite par l'éditeur.
##
## La raison : dans l'éditeur, `GLTFDocument.generate_scene` produit des **`ImporterMeshInstance3D`**
## portant des `ImporterMesh` — un type intermédiaire qui permet de générer LOD, lightmaps et collisions
## à l'import. `ImporterMeshInstance3D` **n'hérite pas** de `MeshInstance3D` : le test `is` échouait,
## et le cast `as ArrayMesh` rendait `null` **sans un mot**.
##
## ⚠ **ON NE TESTE PAS LA CLASSE PAR SON NOM.** Écrire `is ImporterMeshInstance3D` réintroduirait le même
## échec silencieux le jour où ce type n'est pas exposé, ou change. On cherche donc n'importe quel nœud
## portant une propriété `mesh`, et on convertit ce qu'on y trouve — c'est la propriété qui compte, pas
## la classe qui la porte.
##
## ⚠ **LA TRANSFORMATION DU NŒUD EST CUITE DANS LES SOMMETS — CORRIGÉ LE 27 SEPTEMBRE 2026.** On rendait
## le maillage BRUT, en ignorant où son nœud le pose. Or l'importeur OBJ de Blender convertit les axes
## par une ROTATION D'OBJET (+90° en X) et non dans les sommets ; le .glb qu'il réécrit garde cette
## rotation sur le nœud. Relu sans elle, le travail revenait couché : 41 erreurs de tranchage, 2 393
## sommets déplacés (mesuré, aller-retour OBJ → Blender → .glb). Le même piège attendait tout artiste
## qui tourne ou déplace son objet sans « Apply ». On lit désormais ce qu'il VOIT dans sa vue.
## ⚠ **TOUS LES MAILLAGES, PLUS LE PREMIER — CORRIGÉ LE 29 SEPTEMBRE 2026.** Cette fonction s'appelait
## `_premier_maillage` et s'arrêtait au premier nœud porteur. Un artiste qui range son herbe dans un
## second objet perdait l'un des deux SANS UN MOT — et si l'herbe venait d'abord, c'était le TERRAIN :
## mesuré sur le faux travail d'artiste, 2 676 triangles relus sur 33 428 écrits. Chaque objet garde sa
## pose et ses surfaces (donc ses matériaux) ; le nombre d'objets lus est noté en méta (`objets`).
## ⚠ Ils sont tous tranchés comme du TERRAIN : un prop entier (charte §9 bis) n'est pas encore écrit.
## ⚠ **UNE SURFACE PAR MATÉRIAU, PLUS PAR OBJET — CORRIGÉ LE 30 SEPTEMBRE 2026.** Godot plafonne un maillage
## à 256 surfaces ; le témoin lié en demandait ~3 000 (1 056 objets × leurs teintes) et l'affichage perdait
## tout ce qui dépassait, avec une erreur du moteur par surface refusée — vu en menant l'appli, aucun test
## ne lisait assez d'objets pour le voir. Les surfaces de même matériau sont fusionnées.
static func _tous_les_maillages(racine: Node) -> ArrayMesh:
	var paquets := {}   # matériau (ou null) → [tableaux de surface déjà posés]
	var ordre: Array = []
	var objets := 0
	# ⚠ UNE RELECTURE PAR MAILLAGE DISTINCT, ET LA POSE SUR LES TABLEAUX (mesuré le 1er octobre 2026) : avec une
	# carte graphique, `surface_get_arrays` redescend les tableaux du GPU et un `ArrayMesh` neuf les y renvoie.
	# Le témoin lié porte 52 maillages pour 1 056 nœuds : relire, refabriquer et relire encore à CHAQUE nœud
	# prenait 4,6 s avec fenêtre (40 ms en headless, où tout reste en mémoire) — l'appli gelait à chaque
	# enregistrement. Sortie identique : mêmes tableaux, mêmes paquets, même ordre.
	var lus := {}   # maillage → [[tableaux, matériau] par surface]
	for noeud in _tous_les_noeuds(racine):
		var brut: Variant = noeud.get("mesh")
		if brut == null:
			continue
		if not lus.has(brut):
			var converti: ArrayMesh = _en_array_mesh(brut)
			var surfaces: Array = []
			if converti != null:
				for s in converti.get_surface_count():
					surfaces.append([converti.surface_get_arrays(s), converti.surface_get_material(s)])
			lus[brut] = surfaces
		if (lus[brut] as Array).is_empty():
			continue
		var pose_du_noeud := _pose_dans_la_scene(noeud, racine)
		for surface in lus[brut]:
			var m: Material = surface[1]
			if not paquets.has(m):
				paquets[m] = []
				ordre.append(m)
			paquets[m].append(_tableaux_poses(surface[0], pose_du_noeud))
		objets += 1
	if objets == 0:
		return null
	var sortie := ArrayMesh.new()
	for m in ordre:
		sortie.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _fusionner_les_surfaces(paquets[m]))
		sortie.surface_set_material(sortie.get_surface_count() - 1, m)
	sortie.set_meta("objets", objets)
	return sortie


## Fusionne des tableaux de surface en un seul, indices décalés. Un attribut n'est gardé que si TOUTES les
## surfaces le portent (sinon il ne saurait pas quoi valoir sur les autres) ; les tangentes sont retirées,
## comme dans `_transformer`.
static func _fusionner_les_surfaces(liste: Array) -> Array:
	if liste.size() == 1:
		return liste[0]
	var garder := {}
	for attribut in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_COLOR]:
		var partout := true
		for a in liste:
			if a[attribut] == null:
				partout = false
		garder[attribut] = partout
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	for a in liste:
		var base: int = v.size()
		var sv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		v.append_array(sv)
		if garder[Mesh.ARRAY_NORMAL]:
			n.append_array(a[Mesh.ARRAY_NORMAL])
		if garder[Mesh.ARRAY_TEX_UV]:
			uv.append_array(a[Mesh.ARRAY_TEX_UV])
		if garder[Mesh.ARRAY_TEX_UV2]:
			uv2.append_array(a[Mesh.ARRAY_TEX_UV2])
		if garder[Mesh.ARRAY_COLOR]:
			c.append_array(a[Mesh.ARRAY_COLOR])
		var si = a[Mesh.ARRAY_INDEX]
		var ordre: PackedInt32Array = (si as PackedInt32Array) if si != null else PackedInt32Array(range(sv.size()))
		for i in ordre:
			idx.append(base + i)
	var sortie: Array = []
	sortie.resize(Mesh.ARRAY_MAX)
	sortie[Mesh.ARRAY_VERTEX] = v
	sortie[Mesh.ARRAY_INDEX] = idx
	if garder[Mesh.ARRAY_NORMAL]:
		sortie[Mesh.ARRAY_NORMAL] = n
	if garder[Mesh.ARRAY_TEX_UV]:
		sortie[Mesh.ARRAY_TEX_UV] = uv
	if garder[Mesh.ARRAY_TEX_UV2]:
		sortie[Mesh.ARRAY_TEX_UV2] = uv2
	if garder[Mesh.ARRAY_COLOR]:
		sortie[Mesh.ARRAY_COLOR] = c
	return sortie


## La pose d'un nœud dans sa scène, de proche en proche jusqu'à la racine INCLUSE. ⚠ Pas de
## `global_transform` : la scène importée n'est pas dans l'arbre, il rendrait l'identité en se plaignant.
static func _pose_dans_la_scene(noeud: Node, racine: Node) -> Transform3D:
	var pose := Transform3D.IDENTITY
	var n: Node = noeud
	while n != null:
		if n is Node3D:
			pose = (n as Node3D).transform * pose
		if n == racine:
			break
		n = n.get_parent()
	return pose


## Cuit une transformation dans les sommets et les normales, surface par surface, matériau compris.
## ⚠ Une transformation MIROIR (déterminant négatif) retourne les faces : on inverse alors l'enroulement,
## sinon le trancheur verrait toutes les normales à l'envers.
static func _transformer(mesh: ArrayMesh, pose: Transform3D) -> ArrayMesh:
	if pose.is_equal_approx(Transform3D.IDENTITY):
		return mesh
	var sortie := ArrayMesh.new()
	for s in mesh.get_surface_count():
		sortie.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _tableaux_poses(mesh.surface_get_arrays(s), pose))
		var matiere: Material = mesh.surface_get_material(s)
		if matiere != null:
			sortie.surface_set_material(sortie.get_surface_count() - 1, matiere)
	return sortie


## Des tableaux de surface posés par `pose` (une COPIE : les tableaux reçus ne changent pas). Les normales par
## la transposée de l'inverse ; un miroir retourne l'ordre des triangles.
static func _tableaux_poses(source: Array, pose: Transform3D) -> Array:
	var arrays: Array = source.duplicate()
	if pose.is_equal_approx(Transform3D.IDENTITY):
		return arrays
	var miroir: bool = pose.basis.determinant() < 0.0
	var normale: Basis = pose.basis.inverse().transposed()
	# ⚠ DES COPIES : un Packed*Array se passe PAR RÉFÉRENCE, et ces tableaux sont relus pour chaque nœud.
	var v: PackedVector3Array = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	for i in v.size():
		v[i] = pose * v[i]
	arrays[Mesh.ARRAY_VERTEX] = v
	if arrays[Mesh.ARRAY_NORMAL] != null:
		var n: PackedVector3Array = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
		for i in n.size():
			n[i] = (normale * n[i]).normalized()
		arrays[Mesh.ARRAY_NORMAL] = n
	# Les tangentes suivraient la même règle ; on les retire plutôt que de les laisser fausses, et on les RECALCULE
	# en fin de pose si la source en portait (une carte de normales les lit — `cartes_pbr.gd`). ⚠ « Godot les
	# recalcule » était écrit ici : FAUX à l'affichage — un maillage sans tangentes rend une carte de normales de
	# travers ; seul l'export glTF les recalcule.
	var tangentes: bool = arrays[Mesh.ARRAY_TANGENT] != null
	arrays[Mesh.ARRAY_TANGENT] = null
	if miroir:
		var idx = arrays[Mesh.ARRAY_INDEX]
		var ordre: PackedInt32Array = (idx as PackedInt32Array).duplicate() if idx != null 				else PackedInt32Array(range(v.size()))
		for t in range(0, ordre.size() - 2, 3):
			var tmp: int = ordre[t + 1]
			ordre[t + 1] = ordre[t + 2]
			ordre[t + 2] = tmp
		arrays[Mesh.ARRAY_INDEX] = ordre
	if tangentes:
		arrays = load("res://addons/marchingblocks_core/maillage_edite.gd").avec_tangentes(arrays)
	return arrays


## Ramène à un `ArrayMesh` ce qu'un nœud importé porte comme maillage.
## ⚠ Trois formes possibles, et les trois se rencontrent selon le contexte :
##   • `ArrayMesh`     — la ligne de commande ;
##   • `ImporterMesh`  — l'éditeur, qui passe par le type d'import ;
##   • un autre `Mesh` — on recopie ses surfaces plutôt que de rendre `null`.
static func _en_array_mesh(brut: Variant) -> ArrayMesh:
	if brut is ArrayMesh:
		return brut
	# ⚠ PAS `ImporterMesh.get_mesh()` (mesuré le 1er octobre 2026) : sa conversion FAUSSE des normales — une normale
	# (0,008 ; 1 ; 0,008), juste dans le fichier ET dans les tableaux de l'ImporterMesh, en ressortait
	# (0,008 ; 0,97 ; 0,241), 14° de travers : le monde s'éclairait autrement que le modeleur sur des faces
	# sculptées. On bâtit le maillage nous-mêmes, depuis ces tableaux, surface par surface, matériau compris.
	if brut is ImporterMesh:
		var im := brut as ImporterMesh
		var sortie_im := ArrayMesh.new()
		for s in im.get_surface_count():
			var arrays: Array = im.get_surface_arrays(s)
			if arrays.is_empty():
				continue
			sortie_im.add_surface_from_arrays(im.get_surface_primitive_type(s), arrays)
			var mat: Material = im.get_surface_material(s)
			if mat != null:
				sortie_im.surface_set_material(sortie_im.get_surface_count() - 1, mat)
		return sortie_im
	if brut is Mesh:
		var source: Mesh = brut
		var sortie := ArrayMesh.new()
		for s in source.get_surface_count():
			var arrays: Array = source.surface_get_arrays(s)
			if arrays.is_empty():
				continue
			sortie.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var matiere: Material = source.surface_get_material(s)
			if matiere != null:
				sortie.surface_set_material(sortie.get_surface_count() - 1, matiere)
		return sortie
	return null


## CE QUE LE MODULE REFUSE DE LAISSER PASSER. Vide quand tout tient.
##
## ⚠ Les décomptes de cette liste sont DÉRIVÉS ; les remplissages sont ÉCRITS. `anomalies()` est le seul
## endroit où les deux se rencontrent, et il rougit si l'écrit cesse de produire le dérivé.
static func anomalies() -> Array:
	var fautes: Array = []

	# 1. Les couches sont bien COTE × COTE × COTE, et ne contiennent que « # » et « . ».
	for i in BLOCS.size():
		var couches: Array = BLOCS[i]["couches"]
		if couches.size() != COTE:
			fautes.append("« %s » a %d couches au lieu de %d" % [BLOCS[i]["nom"], couches.size(), COTE])
			continue
		for y in couches.size():
			var rangees: Array = couches[y]
			if rangees.size() != COTE:
				fautes.append("« %s » couche y=%d : %d rangées au lieu de %d"
					% [BLOCS[i]["nom"], y, rangees.size(), COTE])
				continue
			for z in rangees.size():
				var rangee: String = rangees[z]
				if rangee.length() != COTE:
					fautes.append("« %s » couche y=%d rangée z=%d : %d caractères au lieu de %d"
						% [BLOCS[i]["nom"], y, z, rangee.length(), COTE])
					continue
				for x in rangee.length():
					if rangee[x] != "#" and rangee[x] != ".":
						fautes.append("« %s » couche y=%d rangée z=%d : caractère « %s » interdit"
							% [BLOCS[i]["nom"], y, z, rangee[x]])

	# 2. Les noms sont uniques — deux blocs de même nom rendraient une vue impossible à désigner.
	var noms := {}
	for b in BLOCS:
		if noms.has(b["nom"]):
			fautes.append("deux blocs portent le nom « %s »" % b["nom"])
		noms[b["nom"]] = true

	# 3. Les contextes sont l'un des deux connus.
	for b in BLOCS:
		if b["contexte"] != EXTERIEUR and b["contexte"] != INTERIEUR:
			fautes.append("« %s » a un contexte inconnu : « %s »" % [b["nom"], b["contexte"]])

	# 4. LA COUVERTURE EST COMPLÈTE. ⚠ C'est la promesse du « pas de repli » : si elle tombe, un peintre
	#    rencontre un trou, et le greffon n'a plus rien pour le combler.
	var absentes: Array = manquantes()
	if not absentes.is_empty():
		fautes.append("%d classe(s) qu'aucun bloc ne livre : %s"
			% [absentes.size(), ", ".join(PackedStringArray(absentes.slice(0, 8)))])

	# ⚠ **UN CONTRÔLE « AU MOINS UN BLOC DE CHAQUE CONTEXTE » A VÉCU ICI, ET IL EST DEVENU
	# INSATISFIABLE.** Il avait un sens tant que le set comptait neuf blocs étiquetés extérieur ou
	# intérieur ; avec un bloc UNIQUE, aucune valeur ne peut satisfaire les deux. Or `anomalies()` est
	# ce que le greffon consulte pour REFUSER un export ou une peinture : le laisser aurait rendu
	# l'outil inutilisable, sur une faute qui n'en est pas une.
	#
	# ⚠ Le contexte ne se déclare d'ailleurs plus par bloc : il se DÉDUIT, sommet par sommet, du toit
	# au-dessus du vide (`MB.exterieur_possible`). Le témoin unique porte les DEUX à la fois.

	return fautes
