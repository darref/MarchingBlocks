@tool
extends RefCounted
## LE BLOC MAÎTRE UNIQUE — ce que l'artiste sculpte, et rien de plus.
##
## ⚠ **IL Y EN A EU NEUF, DE 4³, JUSQU'AU 25 SEPTEMBRE 2026 (DÉCIDÉ, Jordan).** Un seul bloc de 8³ les
## remplace, et ce n'est pas une simplification cosmétique : les neuf ne pouvaient pas livrer les deux
## CONTEXTES (mesuré, 10 classes à double contexte sur les 90 nécessaires), et leur alignement sur une
## bande n'existait que pour les transporter ensemble. Le bloc unique couvre **68 classes en intérieur
## et 22 en extérieur — 90 tuiles**, en un seul morceau.
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
## **DÉCIDÉ (Jordan, 25 septembre 2026) — on livre le témoin COMPLET et on le DIT.** Mesuré sur ce qui
## part réellement : **18 arêtes ambiguës sur 8 364 quads (0,2 %), 0 trou, 100 % soudé, valence 4 à
## 89 %.** Le nombre d'arêtes non-manifold du solide ÉGALE exactement le nombre de contacts d'arête de
## l'occupation — la faute est dans la forme voulue, jamais dans le mailleur.
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

const MB := preload("res://addons/undermend/marching_blocks.gd")
const RP := preload("res://addons/undermend/repli_procedural.gd")

## Le côté d'un bloc maître, en cellules. ⚠ 4 et pas 3 : un 3³ n'a que 2×2×2 = 8 sommets intérieurs,
## donc 8 classes au maximum, ce qui demanderait douze blocs. Un 4³ en a 27.
const COTE := 8

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

## LES NEUF BLOCS. `couches[y][z]` est une rangée de `COTE` caractères indexée par x — « # » plein,
## « . » vide. ⚠ y = 0 est le BAS (marching_blocks.gd : « Y EST LE HAUT »).
const BLOCS := [
	{
		"nom": "le massif, sa falaise et sa grotte",
		"contexte": EXTERIEUR,
		"quoi": "le témoin unique : 68 classes en intérieur, 22 en extérieur, soit 90 tuiles",
		"couches": [
			[   # y = 0 — le socle, creusé par-dessous
				"########",
				"########",
				"##....##",
				"###...##",
				"#####.##",
				"###...##",
				"########",
				"########",
			],
			[   # y = 1 — la grotte
				"######..",
				"##...#..",
				"#.#.##..",
				"##...#..",
				"###..#..",
				"#.#..#..",
				"#..#.#..",
				"######..",
			],
			[   # y = 2 — la grotte se poursuit
				"######..",
				"#...##..",
				"#.##.#..",
				"##...#..",
				"#..#.#..",
				"#....#..",
				"#....#..",
				"######..",
			],
			[   # y = 3 — le plafond, percé
				"######..",
				"##.#.#..",
				"###.##..",
				"#...##..",
				"#.##.#..",
				"###..#..",
				"######..",
				"######..",
			],
			[   # y = 4 — le corps, et la falaise qui serpente à l'est
				"#...##..",
				"###.#...",
				"#.#..#..",
				"#.#####.",
				"####.#..",
				"#####...",
				"#...##..",
				"#..#.#..",
			],
			[   # y = 5 — le plateau recule ; surplomb en z = 5
				"#.###...",
				"##.#....",
				"#..##...",
				"######..",
				"#####...",
				"######..",
				"#.###...",
				"##.##...",
			],
			[   # y = 6 — le bord échancré
				"##.##...",
				"####....",
				"#####...",
				"####....",
				"###.#...",
				"##.#....",
				".####...",
				"#.##....",
			],
			[   # y = 7 — les éperons
				"###.....",
				"##......",
				"###.....",
				"##......",
				"###.....",
				"#.......",
				".##.....",
				"#.......",
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
					pleins[Vector3i(x, y, z)] = true
	return pleins


static func _coque_sous_voxels(pleines: Dictionary, retrait: float) -> ArrayMesh:
	var pleins: Dictionary = sous_voxels(pleines, retrait)

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
				# ⚠ On passe par `_quad` et non par une émission directe : c'est lui qui porte
				# l'enroulement HORAIRE de Godot et le codage couleur par normale.
				_quad(sommets, normales, couleurs, quad, normale)

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
static func _quad(sommets: PackedVector3Array, normales: PackedVector3Array,
		couleurs: PackedColorArray, quad: Array, normale: Vector3) -> void:
	var a: Vector3 = quad[0]
	var b: Vector3 = quad[1]
	var c: Vector3 = quad[2]
	var ordre: Array = quad
	if (b - a).cross(c - a).dot(normale) > 0.0:
		ordre = [quad[3], quad[2], quad[1], quad[0]]
	var couleur: Color = RP.COULEUR_DESSUS if normale.y > 0.5 \
		else (RP.COULEUR_PLAFOND if normale.y < -0.5 else RP.COULEUR_PAROI)
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
## ⚠ **C'EST LA GÉOMÉTRIE LIVRÉE DEPUIS LE 25 SEPTEMBRE 2026 (DÉCIDÉ, Jordan), à `FORCE_CHANFREIN`.**
## Elle est jugée par `sonde_lissage.gd` pour les chiffres et par `planche_lissage.gd` pour ce
## qu'aucun chiffre ne dit.
static func maillage_lisse(i: int, cote := 0.5, force := 1.0) -> ArrayMesh:
	return _coque_lissee(cases(i), clampf(cote, 0.05, 1.0) * 0.5, force)


## DE COMBIEN LE TÉMOIN EST CHANFREINÉ — DÉCIDÉ (Jordan, 25 septembre 2026).
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
	var Tranchage := load("res://addons/undermend/tranchage.gd")
	var pieces := {}
	var provenance := {}
	var erreurs: Array = []

	for i in BLOCS.size():
		# ⚠ LA MÊME GÉOMÉTRIE QUE L'EXPORT, chanfrein compris : le catalogue avec lequel on peint doit
		# être celui que l'artiste va sculpter, sinon le témoin ment sur ce qu'on attend de lui.
		var solide: ArrayMesh = maillage_lisse(i, 0.5, FORCE_CHANFREIN)
		var fautes: Array = []
		# ⚠ `peau = false` : on ne récolte que les sommets dont les huit cellules sont DANS le bloc.
		var recolte: Dictionary = Tranchage.trancher(solide, Vector3i.ONE * COTE, 1.0,
			creuses(i), fautes, false)
		for f in fautes:
			erreurs.append("« %s » : %s" % [BLOCS[i]["nom"], f])
		for nom in recolte:
			if pieces.has(nom):
				continue   # le premier bloc gagne
			pieces[nom] = recolte[nom]
			provenance[nom] = BLOCS[i]["nom"]

	var resultat: Dictionary = _assembler(pieces)
	resultat["erreurs"] = erreurs
	resultat["provenance"] = provenance
	return resultat


## Monte la `MeshLibrary` à partir des pièces récoltées. ⚠ PARTAGÉ par `librairie()` et
## `librairie_depuis_glb()` : deux montages séparés auraient divergé, et l'un des deux aurait fini
## par remettre un repli que l'autre refuse.
static func _assembler(pieces: Dictionary) -> Dictionary:
	var lot := MeshLibrary.new()
	var manquantes: Array = []
	var id := 0
	for c in MB.classes():
		if not MB.porte_une_surface(c["bits"]):
			continue
		var mesh: ArrayMesh = pieces.get(c["nom"], null)
		if mesh == null or mesh.get_surface_count() == 0:
			manquantes.append(c["nom"])
			continue   # ⚠ PAS de repli : l'absence doit se voir
		lot.create_item(id)
		lot.set_item_name(id, c["nom"])
		lot.set_item_mesh(id, mesh)
		lot.set_item_shapes(id, RP.collision(c["bits"]))
		id += 1
	return {"lot": lot, "manquantes": manquantes}


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
static func exporter_le_bloc(chemin: String) -> String:
	var brut: ArrayMesh = maillage_lisse(0, 0.5, FORCE_CHANFREIN)
	var mesh: ArrayMesh = sans_normales(souder(brut))
	if mesh.get_surface_count() == 0:
		return "le bloc est vide"
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


## LA BIBLIOTHÈQUE BÂTIE DEPUIS LE BLOC SCULPTÉ — le retour de Blender.
##
## Rend {"lot", "erreurs", "provenance", "manquantes", "sculptes", "absents"}.
##
## ⚠ **UN BLOC DONT LA BOÎTE RESSORT VIDE EST SIGNALÉ, pas remplacé en silence.** C'est le piège de
## toute cette boucle : si l'artiste déplace le bloc dans Blender, sa boîte se vide, le greffon retombe
## sur la version calculée, et tout semble marcher alors que son travail n'est pas dans le lot.
static func librairie_depuis_glb(chemin: String) -> Dictionary:
	var Tranchage := load("res://addons/undermend/tranchage.gd")
	var Decoupe := load("res://addons/undermend/decoupe.gd")
	var journal: Array = []
	var relu: ArrayMesh = _lire_glb(chemin, journal)
	var pieces := {}
	var provenance := {}
	var erreurs: Array = []
	var sculptes: Array = []
	var absents: Array = []

	if relu == null:
		# ⚠ ON REMONTE LE MOTIF PRÉCIS, jamais « illisible » : les trois échecs possibles n'ont ni la
		# même cause ni le même remède, et l'appelant doit pouvoir le dire à l'artiste.
		for j in journal:
			erreurs.append("lecture de « %s » : %s" % [chemin.get_file(), j])

	var solide: ArrayMesh = null
	if relu != null:
		# ⚠ On découpe quand même dans une boîte tolérante : le relief déborde légalement, et un `.glb`
		# revenu de Blender peut traîner des restes hors du bloc.
		var extrait: ArrayMesh = Decoupe.trancher(relu, boite_du_bloc())
		if extrait.get_surface_count() > 0:
			solide = extrait
			sculptes.append(BLOCS[0]["nom"])
	if solide == null:
		absents.append(BLOCS[0]["nom"])
		# ⚠ **LE MÊME AMINCI QUE L'EXPORT, ET C'EST UNE CORRECTION.** Ce repli rendait le solide PLEIN
		# alors que le bloc était parti aminci : le témoin de secours n'avait donc pas la géométrie du
		# témoin exporté, et la récolte pouvait différer sans qu'aucun compteur ne le signale. Les deux
		# chemins sont maintenant le même appel, donc d'accord par construction et non par vigilance.
		solide = maillage_lisse(0, 0.5, FORCE_CHANFREIN)

	var fautes: Array = []
	var recolte: Dictionary = Tranchage.trancher(solide, Vector3i.ONE * COTE, 1.0,
		creuses(0), fautes, false)
	for f in fautes:
		erreurs.append("« %s » : %s" % [BLOCS[0]["nom"], f])
	for nom in recolte:
		pieces[nom] = recolte[nom]
		provenance[nom] = BLOCS[0]["nom"]

	var resultat: Dictionary = _assembler(pieces)
	resultat["erreurs"] = erreurs
	resultat["provenance"] = provenance
	resultat["sculptes"] = sculptes
	resultat["absents"] = absents
	return resultat


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
static func normales_plates(mesh: ArrayMesh) -> ArrayMesh:
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var couleurs := PackedColorArray()
	var avait_des_couleurs := false

	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		if arrays.is_empty():
			continue
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if v.is_empty():
			continue
		var c: PackedColorArray = arrays[Mesh.ARRAY_COLOR] \
			if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		if not c.is_empty():
			avait_des_couleurs = true
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] \
			if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx = PackedInt32Array(range(v.size()))

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

	var sortie := ArrayMesh.new()
	if sommets.is_empty():
		return sortie
	var res: Array = []
	res.resize(Mesh.ARRAY_MAX)
	res[Mesh.ARRAY_VERTEX] = sommets
	res[Mesh.ARRAY_NORMAL] = normales
	if avait_des_couleurs:
		res[Mesh.ARRAY_COLOR] = couleurs
	sortie.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, res)
	# ⚠ **LE MATÉRIAU SUIT, ET SON OUBLI S'EST VU À L'IMAGE.** Sans lui, la planche est sortie
	# entièrement GRISE : les couleurs de sommet étaient bien là, mais aucun matériau en
	# `vertex_color_use_as_albedo` ne les lisait. ⚠ Et ce n'était pas qu'esthétique — cette fonction est
	# aussi appelée à la LECTURE d'un `.glb`, donc les pièces d'un réimport auraient perdu leur matière.
	var matiere: Material = mesh.surface_get_material(0) if mesh.get_surface_count() > 0 else null
	sortie.surface_set_material(0, matiere if matiere != null else RP.matiere())
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
	var trouve: ArrayMesh = _premier_maillage(scene)
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
		trouve = normales_plates(trouve)
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
static func _premier_maillage(noeud: Node) -> ArrayMesh:
	var brut: Variant = noeud.get("mesh")
	if brut != null:
		var converti: ArrayMesh = _en_array_mesh(brut)
		if converti != null and converti.get_surface_count() > 0:
			return converti
	for enfant in noeud.get_children():
		var trouve: ArrayMesh = _premier_maillage(enfant)
		if trouve != null:
			return trouve
	return null


## Ramène à un `ArrayMesh` ce qu'un nœud importé porte comme maillage.
## ⚠ Trois formes possibles, et les trois se rencontrent selon le contexte :
##   • `ArrayMesh`     — la ligne de commande ;
##   • `ImporterMesh`  — l'éditeur, qui passe par le type d'import ;
##   • un autre `Mesh` — on recopie ses surfaces plutôt que de rendre `null`.
static func _en_array_mesh(brut: Variant) -> ArrayMesh:
	if brut is ArrayMesh:
		return brut
	if brut is ImporterMesh:
		return (brut as ImporterMesh).get_mesh()
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
