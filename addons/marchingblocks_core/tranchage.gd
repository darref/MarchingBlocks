@tool
extends RefCounted
## LE TRANCHAGE D'UN BLOC MAÎTRE — étape 6. D'un mesh sculpté vers les classes de Marching Blocks.
##
## ⚠ **C'EST L'ACTIF DU GREFFON, ET PERSONNE NE LE VEND.** Les concurrents demandent à l'artiste de
## fournir les permutations une par une — *« créer manuellement les 47 permutations de base »*, écrivent
## leurs acheteurs. Ici l'artiste sculpte UN bloc, et l'outil en tire les classes. Le repli procédural
## garantit qu'aucune ne manque ; le tranchage les remplace par de l'art, une à une.
##
## ── LE PLAN DE COUPE, ET IL A CHANGÉ DE NATURE ──────────────────────────────────────────────────────
##
## L'ancien trancheur coupait sur une grille duale en PLAN : décalée d'une demi-case en x et z, centrée
## sur la cellule en y. Le modèle orienté est dual **dans les trois axes** : une pièce est centrée sur un
## SOMMET du réseau, le coin commun à huit cellules. Les plans de coupe passent donc au milieu des
## cellules sur les trois axes.
##
## ⚠ MESURÉ (`DEV_TOOLS/sonde_gridmap_centrage.gd`) : la cellule `p` occupe [p ; p+1], et le sommet lu
## par `MB.bits(pleines, v)` siège en `v + (1,1,1)`. La boîte de coupe du sommet `v` est donc le cube
## d'une cellule centré là.
##
## ── CE QU'ON EXIGE DU BLOC, ET RIEN DE PLUS ─────────────────────────────────────────────────────────
##
##   • ses dimensions sont DÉCLARÉES en cases, jamais déduites de sa boîte englobante ;
##   • son origine se prend au CENTRE de cette boîte, jamais à un coin ;
##   • le relief, le biseau, la texture : ce qu'on veut, tant que la BANDE DE COUTURE tient.
##
## ⚠ **LES DIMENSIONS SONT DÉCLARÉES, ET C'EST UN TEST QUI L'A APPRIS À L'ANCIEN TRANCHEUR.** Un bloc
## qui porte du relief DÉBORDE toujours sa boîte : une bosse de 0,22 sur trois cases donne une boîte de
## 3,22, donc trois cases « mesurées » mais tous les plans de coupe décalés de 0,22. Rien ne le signale,
## et le lot sort de travers. ⚠ Et l'origine se prend au CENTRE parce que le relief déborde des deux
## côtés à peu près également : le centre reste stable quand le sculpteur ajoute une crête, son coin
## inférieur bouge du montant du débord.
##
## ── CE QUE LE TRANCHEUR VÉRIFIE, ET CE QU'IL REFUSE ─────────────────────────────────────────────────
##
## ⚠ **L'ANCIEN TRANCHEUR NE VÉRIFIAIT RIEN DE GÉOMÉTRIQUE, ET TROIS MUTATIONS RESTAIENT MUETTES**
## (origine au coin, pièce non ramenée à sa référence, rotation de normalisation inversée). Il comptait
## les pièces, les aires et les boîtes — jamais OÙ la matière tombait. Deux contrôles le remplacent :
##
##   1. **LES OCTANTS VIDES SONT VIDES.** Une classe dit quelles de ses huit cellules sont pleines. La
##      matière d'un morceau ne doit donc RIEN occuper dans les octants vides. C'est une condition
##      nécessaire, elle se mesure par une aire, et elle attrape toute la famille « la matière est au
##      mauvais endroit » — y compris une rotation de normalisation à l'envers.
##   2. **LA BANDE DE COUTURE EST COHÉRENTE.** Deux morceaux dont une face porte la MÊME configuration
##      de quatre cellules doivent présenter le même germe. ⚠ On compare des AIRES dans une bande mince,
##      ce qui est une condition NÉCESSAIRE et non suffisante : deux germes différents peuvent avoir la
##      même aire. On le dit plutôt que de laisser croire à une preuve.
##
## ⚠ **UN BLOC QUI NE TIENT PAS EST REFUSÉ, ET L'OUTIL DIT OÙ.** Un outil qui ne sait pas produire une
## sortie valide n'a pas à l'enregistrer (charte §6) — et un lot qui craque à la peinture coûte bien
## plus cher qu'un refus au tranchage.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const Decoupe := preload("res://addons/marchingblocks_core/decoupe.gd")

## En deçà de cette aire, on considère qu'un octant est vide. ⚠ Pas zéro : la découpe interpole, et un
## triangle rasant le plan de coupe laisse une écaille d'aire négligeable.
const AIRE_NEGLIGEABLE := 0.0005

## ⚠ **UNE CONSTANTE `MARGE_D_OCTANT` A VÉCU ICI, ET LE BANC DE MUTATIONS L'A DÉCLARÉE MORTE.** Elle
## servait à rétrécir la boîte d'octant pour chercher la matière « strictement dedans ». La mesure a
## montré que cette approche lisait 0,0000 en permanence — toute la géométrie d'une pièce vit SUR des
## plans, donc la rétrécir la supprime entièrement. `verifier_octants` attribue désormais chaque
## triangle par son centroïde et sa normale, et la constante n'était plus lue par personne. La porter à
## 0,30 ne faisait rougir aucun test : le signe qu'il fallait la SUPPRIMER, pas l'expliquer.

## La tolérance relative sur la comparaison des germes de couture.
## **PROPOSÉ, PAS MESURÉ** — à recaler sur un vrai bloc sculpté.
const ECART_DE_COUTURE := 0.08


## L'occupation déclarée d'un bloc de `cases` cellules, moins les `creuses`.
##
## ⚠ CE QU'UN BLOC PLEIN NE PEUT PAS DONNER : les classes concaves. Il n'a aucun coin rentrant, donc
## aucun sommet n'y voit cinq, six ou sept cellules pleines entourant un creux. Pour les obtenir il faut
## MANGER des cellules — d'où `creuses`, et c'est au sculpteur de choisir lesquelles.
static func occupation(cases: Vector3i, creuses: Array) -> Dictionary:
	var absentes := {}
	for c in creuses:
		absentes[Vector3i(c)] = true
	var pleines := {}
	for x in cases.x:
		for y in cases.y:
			for z in cases.z:
				var c := Vector3i(x, y, z)
				if not absentes.has(c):
					pleines[c] = true
	return pleines


## La boîte de coupe du sommet `v`, dans le repère du bloc normalisé (la cellule `p` occupe [p ; p+1]).
## ⚠ Le sommet siège en `v + (1,1,1)` : la boîte est le cube d'une cellule centré là.
static func boite_du_sommet(v: Vector3i, cellule: float) -> AABB:
	var centre := (Vector3(v) + Vector3.ONE) * cellule
	return AABB(centre - Vector3.ONE * 0.5 * cellule, Vector3.ONE * cellule)


## La boîte d'un octant, dans le repère d'une PIÈCE (cube unité centré sur l'origine).
static func boite_d_octant(t: int) -> AABB:
	var coin: Vector3i = MB.COINS[t]
	var mini := Vector3(
		-0.5 if coin.x == 0 else 0.0,
		-0.5 if coin.y == 0 else 0.0,
		-0.5 if coin.z == 0 else 0.0)
	return AABB(mini, Vector3.ONE * 0.5)


## LE TRANCHAGE. Rend {nom de classe: ArrayMesh} — une pièce par classe TROUVÉE dans le bloc.
##
## `cases`   les dimensions DÉCLARÉES du bloc, en cellules ;
## `cellule` la taille d'une cellule dans les unités du mesh ;
## `creuses` les cellules absentes, qui fabriquent les formes concaves ;
## `erreurs` ce qui ne va pas — vide si tout tient.
##
## ⚠ LES PIÈCES SORTENT À L'ÉCHELLE UNITÉ, centrées sur l'origine, comme celles du repli : le lot
## tranché est donc un remplacement direct, classe par classe, sans rien réajuster ailleurs.
## `peau` : faut-il récolter aussi les sommets de BORDURE, dont une partie des huit cellules tombe hors
## du bloc ? Voir le pavé ci-dessous — c'est la décision la plus lourde de cette fonction.
## `remarques` : ce qui mérite d'être DIT sans rien refuser. ⚠ **LA COUTURE Y VA, ET PLUS DANS
## `erreurs` — DÉCIDÉ (Jordan, 24 septembre 2026).**
##
## Le partage des responsabilités a été posé ainsi : **l'artiste a toute liberté DANS chaque case, et la
## connectivité globale est SA responsabilité.** Le trancheur, lui, ne doit vérifier que son propre
## travail — ai-je coupé droit et net.
##
## Or `verifier_couture` ne vérifie rien de la coupe : il compare des pièces ENTRE ELLES et exige que
## deux faces de même configuration portent la même aire. C'est un jugement sur l'ART, pas sur le
## découpage. Un fichier parfaitement tranché — 9 blocs relus, 68 classes, aucune manquante — se
## retrouvait noyé sous treize « erreurs » qui ne parlaient pas du trancheur.
##
## ⚠ **ET LA CORRECTION QUE J'AVAIS PROPOSÉE ÉTAIT PIRE** : normaliser les germes aurait MODIFIÉ l'art de
## l'artiste pour satisfaire un contrôle qui n'avait pas lieu d'être. `verifier_octants`, lui, reste dans
## `erreurs` : un octant plein qui borde le vide et ne porte aucune surface, c'est bien la COUPE qui a
## déplacé la matière.
## `sources` — panier de SORTIE, {clé: {mesh, sommet, copies}} : la tuile de chaque clé (UNE, le sommet le
## plus pur), le sommet d'où elle vient, et combien de sommets du bloc portaient cette clé.
## `origine` — où siège la case (0, 0, 0) dans le repère du maillage, quand elle est CONNUE. Sinon (null),
## elle est déduite de la boîte du maillage. ⚠ **LE BLOC MAÎTRE EST À L'ORIGINE PAR CONTRAT (§4), ET LA
## DÉDUIRE ÉTAIT UN DÉFAUT RÉEL (29 septembre 2026)** : un relief qui déborde légalement (règle (A)) d'un
## côté du bloc et pas de l'autre grossit la boîte d'un seul côté, et la déduction DÉCALAIT TOUS LES PLANS
## DE COUPE. Mesuré sur le faux travail d'artiste : un liseré d'herbe qui surplombe les falaises du bord
## rendait « le bloc mesure 1,000 de trop » et 579 remarques de couture.
static func trancher(mesh: Mesh, cases: Vector3i, cellule: float, creuses: Array,
		erreurs: Array, peau := true, remarques: Array = [],
		sources: Dictionary = {}, origine: Variant = null) -> Dictionary:
	# `sources` (sortie) — {clé: {"mesh", "sommet", "copies"}} : d'où vient la tuile de chaque clé, et combien
	# de sommets du bloc portaient cette clé (un travail NON LIÉ peut en avoir sculpté autant de versions).
	var pieces := {}
	if mesh == null:
		erreurs.append("aucun bloc fourni")
		return pieces
	if cellule <= 0.0:
		erreurs.append("taille de cellule nulle ou négative")
		return pieces
	if cases.x < 1 or cases.y < 1 or cases.z < 1:
		erreurs.append("dimensions déclarées invalides : %d × %d × %d cases"
			% [cases.x, cases.y, cases.z])
		return pieces

	var pleines: Dictionary = occupation(cases, creuses)
	if pleines.is_empty():
		erreurs.append("toutes les cellules sont creusées : il ne reste rien à trancher")
		return pieces

	# ⚠ **L'ÉTENDUE ATTENDUE EST CELLE DES CELLULES OCCUPÉES, PAS CELLE DU CUBE DÉCLARÉ — ET C'EST UNE
	# CORRECTION DE BOGUE VIVANT.** L'ancienne version comparait la boîte du mesh à `cases × cellule` et
	# prenait l'origine au centre de ce cube. Or un bloc dont une couche de bord est VIDE a légitimement
	# un mesh plus petit : « massif et plateau » (couche y = 3 vide) mesurait 4 × 3 × 4 pour 4 × 4 × 4
	# déclarés. Deux conséquences, et la seconde est la grave :
	#   • un faux refus « le bloc mesure −1,000 de trop » (47 erreurs sur un bloc parfaitement sain) ;
	#   • surtout, le centre du mesh n'étant PAS celui du cube, l'origine glissait d'une demi-case et
	#     TOUS les plans de coupe avec elle. Le lot serait sorti de travers sans que rien ne le dise.
	# ⚠ Presque tous les blocs réels ont des cellules de bord vides : ce défaut les touchait tous.
	var mini := Vector3.INF
	var maxi := -Vector3.INF
	for c in pleines:
		var p: Vector3i = c
		mini = mini.min(Vector3(p))
		maxi = maxi.max(Vector3(p) + Vector3.ONE)
	var attendue: Vector3 = (maxi - mini) * cellule
	var centre_attendu: Vector3 = (mini + maxi) * 0.5 * cellule

	var boite: AABB = mesh.get_aabb()
	var connue: bool = origine != null
	var decalage: Vector3 = (origine as Vector3) if connue else boite.get_center() - centre_attendu
	var normalise: ArrayMesh = Decoupe.poser(mesh, Transform3D(Basis(), -decalage))

	# On ne REFUSE pas un débord — c'est du relief, c'est voulu — mais on le DIT quand il devient trop
	# gros pour en être. ⚠ En valeur absolue : un bloc plus PETIT que son étendue occupée est aussi faux
	# qu'un bloc plus grand, et ne rien dire dans ce sens-là laisserait passer une case entière de moins.
	# ⚠ **LA TOLÉRANCE EST À TROIS QUARTS DE CASE, ET C'ÉTAIT UN FAUX REFUS À UNE DEMIE.** Ce contrôle
	# existe pour attraper une déclaration fausse d'une CASE ENTIÈRE — « trois cases déclarées pour
	# quatre ». Mais le set part désormais aminci : chaque face exposée rentre d'un quart, donc l'étendue
	# d'un bloc rétrécit de 0,5 sur chaque axe, c'est-à-dire **pile sur l'ancien seuil**. Un flottant au
	# bord suffisait alors à déclencher un refus sur un bloc parfaitement sain — mesuré sur « massif et
	# plateau » et « encoche en L », dont l'étendue occupée vaut 3,0 pour un maillage de 2,5.
	# ⚠ Trois quarts attrape toujours l'erreur d'une case entière (1,0), tout en laissant passer
	# l'amincissement et le relief, qui sont légaux (règle (A) : le relief peut déborder d'une cellule).
	# ⚠ Ce contrôle attrape une déclaration fausse ; une origine CONNUE n'a rien à déclarer, et son relief
	# déborde légalement. Il ne juge donc que le cas déduit.
	var debord: Vector3 = boite.size - attendue
	for axe in (range(0) if connue else range(3)):
		if absf(debord[axe]) > cellule * 0.75:
			erreurs.append("le bloc mesure %.3f de trop (ou de moins) sur l'axe %d pour une étendue "
				% [debord[axe], axe]
				+ "occupée de %.2f — relief, ou dimensions fausses ?" % attendue[axe])

	var grille := GridMap.new()   # ⚠ seulement pour lire les bases d'orientation
	var vues := {}
	# ⚠ LE PLAFOND EST DÉRIVÉ DE L'OCCUPATION, jamais pris à `cases.y` : une couche de bord vide ferait
	# chercher de la roche là où le bloc s'arrête, et tous les sommets du haut passeraient pour coiffés.
	# C'est la même faute que prendre le cube DÉCLARÉ pour l'étendue réelle, corrigée plus haut.
	var plafond: int = MB.plafond_de(pleines)

	# ⚠ **QUELS SOMMETS ON RÉCOLTE — DÉCIDÉ (Jordan, 24 septembre 2026) : LES INTÉRIEURS SEULEMENT.**
	#
	# Un sommet lit huit cellules. Au BORD du bloc, une partie d'entre elles tombe dehors, et le
	# trancheur les tient pour vides — il invente donc du vide qu'il n'a pas vu. Il en conclut « roche
	# d'un côté, vide de l'autre : c'est un mur », et découpe comme mur **la tranche de scie du bloc**,
	# là où l'artiste a simplement arrêté de modéliser.
	#
	# ⚠ MESURÉ (`DEV_TOOLS/sonde_accord_blocs.gd`, 9 blocs sur 9) : les classes récoltées en plus au bord
	# sont EXACTEMENT la peau d'un cube vu de dehors — `mb_plaque_b2h2`, `mb_arete_b2h0`, `mb_coin_b1h0`.
	# Or `mb_plaque_b2h2` est la tuile la plus posée d'un monde réel (30 % des pièces), et **le tranché
	# REMPLACE** : cette dalle lisse écraserait une version meilleure, sans qu'aucune erreur ne le dise.
	#
	# `peau = false` ne garde donc que les sommets dont les huit cellules sont DANS le bloc. Un bloc de
	# n cases n'en a que (n−1)³ — d'où neuf blocs maîtres et non cinq.
	# ⚠ `peau = true` reste le défaut pour ne rien changer aux appelants existants et à leurs tests ; il
	# a un sens pour un rocher isolé dont toute la peau est sculptée.
	# ⚠ **UNE TUILE PAR CLÉ — DÉCIDÉ (Jordan, 30 septembre 2026, charte §3).** Du 27 au 30 septembre, le
	# trancheur gardait TOUS les sommets d'une clé comme autant d'« exemplaires » tirés par position : une
	# falaise droite devenait une mosaïque de 30 morceaux découpés à 30 endroits (mesuré). Il ne garde plus
	# qu'UN sommet par clé : le plus PUR (`MB.purete` — celui dont les voisins ont laissé le moins de traces),
	# à égalité le premier du balayage (x, puis y, puis z). ⚠ Le choix se fait sur les CASES, AVANT de
	# découper : on ne découpe que les sommets retenus (52 découpes, pas 549).
	# ⚠ Un travail LIÉ ne passe pas par ici (`BlocsMaitres.tuiles_liees`). Un travail NON LIÉ ne livre donc
	# que la copie la plus lisible de chaque tuile — `sources[clé]["copies"]` permet à l'appelant de le DIRE.
	var premier := -1 if peau else 0
	var choisi := {}
	var purete_de := {}
	var copies := {}
	var cle_de := {}
	for vx in range(premier, cases.x if peau else cases.x - 1):
		for vy in range(premier, cases.y if peau else cases.y - 1):
			for vz in range(premier, cases.z if peau else cases.z - 1):
				var v := Vector3i(vx, vy, vz)
				var r: Dictionary = cle_du_sommet(pleines, v, plafond)
				if r.is_empty():
					continue
				var cle: String = r["cle"]
				copies[cle] = int(copies.get(cle, 0)) + 1
				var p: int = MB.purete(pleines, v)
				if not choisi.has(cle) or p < int(purete_de[cle]):
					choisi[cle] = v
					purete_de[cle] = p
					cle_de[cle] = r

	for cle in choisi:
		var v: Vector3i = choisi[cle]
		var r: Dictionary = cle_de[cle]
		var morceau: ArrayMesh = Decoupe.trancher(normalise, boite_du_sommet(v, cellule))
		if morceau.get_surface_count() == 0:
			continue

		# Recentré sur l'origine, puis ramené à l'ÉCHELLE UNITÉ.
		var centre := (Vector3(v) + Vector3.ONE) * cellule
		var recentre: ArrayMesh = Decoupe.poser(morceau,
			Transform3D(Basis().scaled(Vector3.ONE / cellule), Vector3.ZERO)
				* Transform3D(Basis(), -centre))

		# ⚠ ET RAMENÉ À SA RÉFÉRENCE. La pièce trouvée est la classe posée avec l'orientation
		# `r["orientation"]` ; pour obtenir le mesh de RÉFÉRENCE il faut lui appliquer la
		# rotation INVERSE. Une rotation étant orthogonale, son inverse est sa transposée.
		# L'ancien trancheur se trompait de sens ici, et le test ne le voyait pas.
		var base: Basis = grille.get_basis_with_orthogonal_index(r["orientation"])
		var reference: ArrayMesh = Decoupe.poser(recentre,
			Transform3D(base.transposed(), Vector3.ZERO))
		pieces[cle] = reference
		sources[cle] = {"mesh": reference, "sommet": v, "copies": int(copies[cle])}
		vues[cle] = MB.classes()[r["classe"]]["bits"]

	grille.free()

	# ⚠ L'UN REFUSE, L'AUTRE SIGNALE. Les octants vérifient la COUPE ; la couture juge l'ART, et l'art
	# appartient à l'artiste. Les contrôles portent sur les tuiles LIVRÉES, une par clé : ce sont elles que
	# le monde met face à face.
	verifier_octants(pieces, vues, erreurs)
	verifier_couture(pieces, vues, remarques)
	verifier_sections(pieces, vues, remarques)
	verifier_couture_texture(pieces, remarques)
	return pieces


## De combien deux couleurs de coupe peuvent différer (par canal, sur [0 ; 1]) avant qu'on le DISE.
const ECART_DE_TEXTURE := 0.08

## CONTRÔLE 3 — LA TEXTURE LE LONG DES COUPES : une REMARQUE, jamais une erreur (charte §3).
##
## ⚠ **LA RÈGLE QUE L'ARTISTE A REÇUE** (Jordan, 28 septembre 2026) : *le long de chaque plan de coupe, la
## texture doit être la MÊME pour toutes les tuiles — sur les quatre bords, dans les deux sens.* Dans le
## monde, une tuile rencontre à sa coupe une voisine que le témoin ne lui a jamais montrée (une autre
## clé, un autre quart de tour) : seule une texture qui ne dépend que de la PLACE
## sur le plan raccorde partout.
## On échantillonne donc la texture de chaque tuile sur ses arêtes posées SUR un plan de coupe, et l'on
## compare toutes les tuiles au même point du plan. ⚠ Le point est REPLIÉ par les symétries que la pose
## peut appliquer — quarts de tour autour de +Y, et les deux côtés d'un plan — : sur un plan horizontal,
## (x, z) ne compte qu'à permutation et signe près ; sur un plan vertical, seul le haut garde son signe.
## ⚠ Une tuile sans texture lisible (pas d'`albedo_texture`, pas d'UV) n'est pas jugée : le témoin
## calculé n'en porte pas, et le contrôle ne doit rien dire de lui.
static func verifier_couture_texture(pieces: Dictionary, remarques: Array) -> void:
	var releves := {}   # point replié → [couleur, nom de la première tuile]
	var ecarts := 0
	var pire := 0.0
	var pire_de := ""
	for nom in pieces:
		var mesh: Mesh = pieces[nom]
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s) as StandardMaterial3D
			if m == null or m.albedo_texture == null:
				continue
			var image: Image = m.albedo_texture.get_image()
			if image == null or image.is_empty():
				continue
			if image.is_compressed():
				image = image.duplicate()
				image.decompress()
			var arrays: Array = mesh.surface_get_arrays(s)
			if arrays[Mesh.ARRAY_TEX_UV] == null:
				continue
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var idx = arrays[Mesh.ARRAY_INDEX]
			var ordre: PackedInt32Array = (idx as PackedInt32Array) if idx != null \
				else PackedInt32Array(range(v.size()))
			for t in range(0, ordre.size() - 2, 3):
				for k in 3:
					var ia: int = ordre[t + k]
					var ib: int = ordre[t + (k + 1) % 3]
					var axe: int = _plan_commun(v[ia], v[ib])
					if axe < 0:
						continue
					for f in [0.25, 0.5, 0.75]:
						var p: Vector3 = v[ia].lerp(v[ib], f)
						var u: Vector2 = uv[ia].lerp(uv[ib], f)
						var couleur: Color = image.get_pixel(
							clampi(int(u.x * image.get_width()), 0, image.get_width() - 1),
							clampi(int(u.y * image.get_height()), 0, image.get_height() - 1))
						var cle: String = _point_replie(p, axe)
						if not releves.has(cle):
							releves[cle] = [couleur, nom]
							continue
						var autre: Color = releves[cle][0]
						var e: float = maxf(maxf(absf(autre.r - couleur.r), absf(autre.g - couleur.g)),
							absf(autre.b - couleur.b))
						if e > ECART_DE_TEXTURE:
							ecarts += 1
							if e > pire:
								pire = e
								pire_de = "%s / %s" % [releves[cle][1], nom]
	if ecarts > 0:
		remarques.append("texture : %d point(s) de coupe où deux tuiles n'ont pas la même couleur "
			% ecarts + "(pire écart %.2f, entre %s) — le long d'une coupe, la texture doit être la même "
			% [pire, pire_de] + "pour toutes les tuiles")


## L'axe du plan de coupe (face de la boîte unité) qui porte l'arête [a, b], ou −1.
static func _plan_commun(a: Vector3, b: Vector3) -> int:
	for axe in 3:
		if absf(absf(a[axe]) - 0.5) < 0.0005 and absf(absf(b[axe]) - 0.5) < 0.0005 \
				and signf(a[axe]) == signf(b[axe]):
			return axe
	return -1


## Un point d'un plan de coupe, replié par les symétries de la pose, au 1/64 de case.
static func _point_replie(p: Vector3, axe: int) -> String:
	var q := func(x: float) -> int: return roundi(x * 64.0)
	if axe == 1:
		var a: float = absf(p.x)
		var b: float = absf(p.z)
		return "h|%d|%d" % [q.call(maxf(a, b)), q.call(minf(a, b))]
	var h: float = absf(p.z) if axe == 0 else absf(p.x)
	return "v|%d|%d" % [q.call(h), q.call(p.y)]


## LA CLÉ D'UN SOMMET, et la rotation qui ramène sa pièce à la référence. `{}` s'il ne porte aucune surface.
## Rend {"cle", "classe", "bits", "orientation"} — `orientation` est l'index de GridMap de `MB.classer`.
##
## ⚠ **EXTRAITE DE `trancher()` POUR QUE L'EXPORT LISE LA MÊME RÈGLE (28 septembre 2026).** Les UV du
## témoin (`BlocsMaitres._uv_du_temoin`) doivent tomber sur la clé que le trancheur donnera au morceau ;
## une seconde description du contexte aurait fini par diverger (charte §6). Sortie inchangée.
## ⚠ **ON RÉCOLTE PAR (CLASSE, CONTEXTE), PLUS PAR CLASSE SEULE.** Le module annonçait 90 tuiles — les 68
## classes plus les 22 qui peuvent AUSSI être à l'air libre — et n'en livrait que 68 : « sol de grotte »
## et « sol de massif » étaient la MÊME tuile, alors que c'est exactement la distinction pour laquelle le
## modèle ORIENTÉ a été choisi. ⚠ Une variante n'existe que si la classe PEUT être dehors ET que ce
## sommet-ci l'EST.
static func cle_du_sommet(pleines: Dictionary, v: Vector3i, plafond: int) -> Dictionary:
	var bits: int = MB.bits(pleines, v)
	var r: Dictionary = MB.classer(bits)
	if not r["surface"]:
		return {}
	var dehors: bool = MB.exterieur_possible(bits) and MB.sous_le_ciel(pleines, v, plafond)
	return {"cle": MB.nom_en_contexte(r["nom"], dehors), "classe": r["classe"], "bits": bits,
		"orientation": r["orientation"]}


## CONTRÔLE 1 — LES OCTANTS VIDES SONT VIDES.
##
## ⚠ C'EST LE CONTRÔLE QUE L'ANCIEN TRANCHEUR N'AVAIT PAS, ET IL LAISSAIT PASSER TROIS DÉFAUTS : origine
## prise au coin, pièce non ramenée à sa référence, rotation de normalisation inversée. Les trois
## déplacent la matière SANS changer son aire totale ni sa boîte englobante — donc aucun compteur ne les
## voit. Regarder OÙ elle tombe les attrape tous les trois.
## ⚠ **L'AIRE DANS UNE BOÎTE EST LE MAUVAIS INSTRUMENT, ET IL M'A FALLU DEUX ESSAIS POUR LE VOIR.**
##
##   • Boîte PLEINE : la surface d'une pièce est posée SUR les plans centraux — c'est la frontière entre
##     un octant plein et son voisin vide — et la découpe garde ce qui repose sur le plan de coupe. Tout
##     quad de frontière était donc compté des deux côtés, et le contrôle condamnait jusqu'au repli
##     procédural, qui est la référence.
##   • Boîte RÉTRÉCIE : pire. Toute la géométrie d'une pièce vit sur des plans (les centraux et les
##     faces extérieures) ; la rétrécir de 0,02 les supprime TOUTES. La mesure lisait 0,0000 en
##     permanence, plein comme vide — six mutations sur huit sont restées muettes, dont le retrait pur
##     et simple de ce contrôle. **Un contrôle incapable de rougir ment en silence.**
##
## LE BON INSTRUMENT ATTRIBUE CHAQUE TRIANGLE À SON OCTANT, par le signe de son centroïde et par sa
## NORMALE — la normale pointant vers le vide, donc à l'opposé de la matière. C'est exactement la
## technique de `test_repli_procedural._ou_la_matiere_se_trouve`, et elle, on l'a VUE rougir.
## **DÉCIDÉ (Jordan, 20 septembre 2026) — LE DÉBORDEMENT EST LÉGAL, SEULE LA COUTURE FAIT FOI.**
##
## ⚠ La règle précédente — *la matière ne vit que dans ses octants pleins* — REFUSAIT le relief, donc le
## « cube avec un relief moche et un bevel » que le greffon existe pour trancher. Et rien ne cassait
## vraiment : deux pièces voisines dessinent alors de la matière dans la même région. C'est un
## DÉBORDEMENT, pas un trou, et c'est à ça que ressemble du relief.
##
## Mais le contrôle attrapait de vrais défauts — rotation de normalisation inversée, pièce non ramenée à
## sa référence — et ceux-là ne font pas déborder la matière : ils la DÉPLACENT ENTIÈREMENT. D'où la
## règle retournée :
##
##   ⚠ **TOUT OCTANT PLEIN QUI A UN VOISIN VIDE DOIT PORTER DE LA SURFACE.**
##
## Le relief n'enlève jamais la matière d'un octant plein ; une rotation fausse, si.
##
## ⚠ ET LE RAFFINEMENT SANS LEQUEL CE CONTRÔLE SERAIT FAUX : « tout octant plein doit porter de la
## surface » ne tient pas. Un octant plein dont les trois voisins sont pleins est INTÉRIEUR — il n'a
## aucune surface, personne ne le voit. Sur `mb_coin_creux` (sept pleins, un creux), l'octant opposé au
## creux en est exactement un. La condition porte donc sur les octants qui BORDENT le vide.
## ⚠ **LE NOM EST LU SUFFIXE RETIRÉ PAR DÉFENSE, PAS POUR RÉPARER UN DÉFAUT — ET J'AI D'ABORD ÉCRIT
## L'INVERSE ICI.** J'avais affirmé que ce contrôle était devenu MUET sur les tuiles d'extérieur depuis
## la récolte à deux contextes, parce que `bits_par_nom.get(nom, 0)` rendrait 0 sur une clé suffixée.
## **Mesuré sur les quatre combinaisons clé × table : c'est faux.** Le trancheur écrit `vues[cle]` puis
## passe `vues` — la table est donc indexée par la MÊME clé que les pièces, et la lecture trouvait
## toujours les bons bits. Le contrôle n'a jamais cessé de voir.
##
## Les deux seuls montages aveugles demandent une clé et une table DÉSACCORDÉES, ce qu'aucun appelant
## ne produit. Le repli sur `nom_nu` reste comme garde pour un appelant futur qui fournirait une table
## par nom de classe ; il ne change rien aujourd'hui.
static func verifier_octants(pieces: Dictionary, bits_par_nom: Dictionary, erreurs: Array) -> void:
	for nom in pieces:
		var bits: int = bits_par_nom.get(MB.nom_nu(nom), bits_par_nom.get(nom, 0))

		# Les octants qui doivent porter de la surface : pleins, et bordant au moins un vide.
		var attendus := {}
		for t in 8:
			if not (bits & (1 << t)):
				continue
			for axe in 3:
				if not (bits & (1 << (t ^ (1 << axe)))):
					attendus[t] = true
					break

		# Ce que la géométrie occupe réellement.
		var trouves := {}
		var mesh: ArrayMesh = pieces[nom]
		for s in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(s)
			if arrays.is_empty():
				continue
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] \
				if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			for i in range(0, v.size() - 2, 3):
				var centre: Vector3 = (v[i] + v[i + 1] + v[i + 2]) / 3.0
				# ⚠ **LA NORMALE EST CALCULÉE DES SOMMETS, PAS LUE DU TABLEAU — DÉCIDÉ (Jordan,
				# 24 septembre 2026) APRÈS UN ALLER-RETOUR QUI A ROUGI.** Exporter les blocs SOUDÉS
				# (sommets fusionnés, comme Blender les rendra) remplace les normales franches par des
				# MOYENNES obliques aux arêtes. Un triangle posé sur un plan central devenait alors
				# inattribuable, et un octant plein se déclarait sans surface : 23 erreurs au retour,
				# toutes sur les classes creuses et biaises — celles dont le plus de sommets se soudent.
				#
				# La normale GÉOMÉTRIQUE se déduit des positions, c'est-à-dire de ce que le trancheur
				# découpe réellement : elle vaut exactement ±1 sur un axe pour un triangle couché dans un
				# plan, quel que soit le lissage. ⚠ C'est ce qui rend ce contrôle utilisable sur de l'art
				# venu de Blender, qui aura TOUJOURS des normales lissées — sans quoi le pipeline aurait
				# refusé le travail de l'artiste à la première réimportation.
				#
				# ⚠ LE SIGNE VIENT DE L'ENROULEMENT : Godot enroule ses faces avant dans le sens HORAIRE,
				# donc le produit vectoriel pointe à l'OPPOSÉ de la sortante. On le retourne.
				var geo: Vector3 = -(v[i + 1] - v[i]).cross(v[i + 2] - v[i])
				# Un triangle dégénéré n'a pas de normale géométrique : on retombe sur celle du tableau
				# plutôt que de perdre l'attribution.
				var normale: Vector3 = geo.normalized() if geo.length_squared() > 0.000000001 \
					else (n[i] if n.size() > i else Vector3.ZERO)
				var t: int = octant_du_triangle(centre, normale)
				if t >= 0:
					trouves[t] = true

		var muets: Array = []
		for t in attendus:
			if not trouves.has(t):
				muets.append(t)
		if not muets.is_empty():
			erreurs.append("« %s » : l'octant %s est plein et borde le vide, mais ne porte AUCUNE "
				% [nom, str(muets)] + "surface — la matière a été déplacée")


## À quel octant appartient un triangle, d'après son centroïde et sa normale ? −1 si indécidable.
##
## ⚠ SUR UN AXE OÙ LE CENTROÏDE EST À ZÉRO, le triangle est posé sur le plan central : c'est la NORMALE
## qui tranche, puisqu'elle regarde vers le vide et donc à l'opposé de la matière.
static func octant_du_triangle(centre: Vector3, normale: Vector3) -> int:
	var t := 0
	for axe in 3:
		var bit := -1
		if centre[axe] > 0.001:
			bit = 1
		elif centre[axe] < -0.001:
			bit = 0
		elif absf(normale[axe]) > 0.5:
			bit = 0 if normale[axe] > 0.0 else 1
		if bit < 0:
			return -1
		t += bit << axe
	return t


## LA TABLE DES GERMES CANONIQUES — la clé brute d'une face vers le représentant de son orbite.
## ⚠ Elle ne dépend que du GROUPE, jamais des pièces : bâtie une fois, puis mise en cache.
static var _germes: Dictionary = {}


## LE GERME CANONIQUE D'UNE FACE — sa configuration de quatre cellules, repliée par les rotations
## ACTIVES du groupe.
##
## ⚠ **C'EST LA CORRECTION D'UN DÉFAUT QUI ACCUSAIT L'ARTISTE À TORT, ET IL FAUT L'ÉCRIRE.** La version
## précédente rangeait les relevés par `MB.forme_de_face()` — les SIX formes du modèle LIBRE. Or le
## modèle est ORIENTÉ et compte VINGT-HUIT germes : une face `y+` de forme « mur » (c'est un SOL) et une
## face `x+` de la même forme (c'est un MUR) y sont deux objets DISTINCTS, et le modèle dit
## expressément qu'ils n'ont aucune raison de se ressembler (`marching_blocks.gd` : « en modèle orienté
## il y en a 28, car un germe de SOL et un germe de MUR ne sont plus le même objet »).
##
## Le contrôle les rangeait pourtant dans le même seau et exigeait la même aire. Il refusait donc de
## l'art parfaitement légal — et c'est très probablement ce qui l'a fait rétrograder en `remarques`
## après avoir noyé un fichier sain sous treize « erreurs ».
##
## ⚠ **AUCUNE ROTATION DE GÉOMÉTRIE N'EST NÉCESSAIRE ICI**, et c'est ce qui rend cette passe petite :
## l'aire est invariante par rotation, donc replier les CLÉS suffit. Comparer des SECTIONS demandera,
## lui, de ramener chaque instance dans le repère de son représentant — c'est le cran suivant, et il ne
## se mêle pas à celui-ci, sinon une mutation muette deviendrait impossible à attribuer.
static func germe_canonique(coins_face: Array, pleins: Array) -> String:
	_batir_les_germes()
	return _germes.get(MB._cle_de_germe(coins_face, pleins), "?")


## Combien de germes distincts le groupe courant définit. ⚠ Doit valoir 28 en modèle orienté.
static func nombre_de_germes() -> int:
	_batir_les_germes()
	var vus := {}
	for cle in _germes:
		vus[_germes[cle]] = true
	return vus.size()


static func _batir_les_germes() -> void:
	if not _germes.is_empty():
		return
	for face in MB.FACES:
		for m in 16:
			var pleins: Array = []
			for i in 4:
				if (m & (1 << i)) != 0:
					pleins.append(int(face["coins"][i]))
			var cle: String = MB._cle_de_germe(face["coins"], pleins)
			if _germes.has(cle):
				continue
			# Nouvelle orbite : cette clé en devient le représentant, et toute son orbite y renvoie.
			_germes[cle] = cle
			for r in MB.rotations_actives():
				var f2: Array = []
				for t in face["coins"]:
					f2.append(int(r["coins"][int(t)]))
				var p2: Array = []
				for t in pleins:
					p2.append(int(r["coins"][int(t)]))
				var autre: String = MB._cle_de_germe(f2, p2)
				if not _germes.has(autre):
					_germes[autre] = cle


## CONTRÔLE 2 — LA BANDE DE COUTURE EST COHÉRENTE.
##
## Deux faces portant le MÊME GERME doivent présenter la même matière dans leur bande de couture. On
## mesure l'aire dans une bande mince contre chaque face, et on l'exige égale à germe donné.
##
## ⚠ **DEUX RÉSERVES, DITES PLUTÔT QUE TUES.**
##
##   1. **L'AIRE EST UNE CONDITION NÉCESSAIRE, PAS SUFFISANTE.** Deux germes de formes différentes
##      peuvent avoir la même aire. Ce contrôle attrape les violations franches — un mur qui s'arrête
##      avant le plan, un biseau d'un seul côté — pas les subtiles. Comparer les SECTIONS est le cran
##      suivant.
##   2. **LA RÉFÉRENCE EST LA MOYENNE DU SEAU, ce qui est fragile.** Si deux relevés sur dix sont faux,
##      ils tirent la moyenne vers eux et peuvent passer sous la tolérance. La MÉDIANE serait plus
##      robuste. ⚠ Ce n'est pas corrigé ici exprès : changer la clé ET la statistique dans la même passe
##      rendrait toute mutation impossible à attribuer.
static func verifier_couture(pieces: Dictionary, bits_par_nom: Dictionary, erreurs: Array) -> void:
	var par_germe := {}
	for nom in pieces:
		# ⚠ SUFFIXE RETIRÉ PAR DÉFENSE, comme pour les octants — et pour la même raison corrigée : j'avais
		# cru ce contrôle aveugle sur les tuiles d'extérieur, la mesure dit que non. La table que le
		# trancheur passe est indexée par la même clé que les pièces. Ce repli ne sert qu'à un appelant
		# futur qui fournirait une table par nom de classe.
		var bits: int = bits_par_nom.get(MB.nom_nu(nom), bits_par_nom.get(nom, 0))
		for face in MB.FACES:
			# La configuration de la face : sa FORME sert à savoir s'il y a quelque chose à coudre et à
			# nommer la faute ; c'est le GERME, lui, qui décide de ce qu'on compare à quoi.
			var quatre: Array = []
			var pleins: Array = []
			for t in face["coins"]:
				var plein: bool = (bits & (1 << int(t))) != 0
				quatre.append(plein)
				if plein:
					pleins.append(int(t))
			var forme: String = MB.forme_de_face(quatre)
			if forme == "rien" or forme == "plein":
				continue   # rien à coudre : pas de surface qui traverse ce plan
			var germe: String = germe_canonique(face["coins"], pleins)
			var bande := _bande_de_face(face["nom"])
			var aire: float = Decoupe.aire(Decoupe.trancher(pieces[nom], bande))
			if not par_germe.has(germe):
				par_germe[germe] = []
			par_germe[germe].append({
				"nom": nom, "face": face["nom"], "forme": forme, "aire": aire,
			})

	for germe in par_germe:
		var releves: Array = par_germe[germe]
		if releves.size() < 2:
			continue
		var somme := 0.0
		for r in releves:
			somme += r["aire"]
		var moyenne: float = somme / releves.size()
		if moyenne <= AIRE_NEGLIGEABLE:
			continue
		for r in releves:
			if absf(r["aire"] - moyenne) / moyenne > ECART_DE_COUTURE:
				erreurs.append(("couture « %s » : la face %s de « %s » porte une aire de %.4f, les "
					+ "autres faces du MÊME GERME en moyenne %.4f — le germe ne dépend pas que de la "
					+ "configuration") % [r["forme"], r["face"], r["nom"], r["aire"], moyenne])


## La bande mince contre une face, dans le repère d'une pièce unité.
static func _bande_de_face(nom: String) -> AABB:
	var e: float = MB.EPAISSEUR_DE_COUTURE
	match nom:
		"x-": return AABB(Vector3(-0.5, -0.5, -0.5), Vector3(e, 1.0, 1.0))
		"x+": return AABB(Vector3(0.5 - e, -0.5, -0.5), Vector3(e, 1.0, 1.0))
		"y-": return AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1.0, e, 1.0))
		"y+": return AABB(Vector3(-0.5, 0.5 - e, -0.5), Vector3(1.0, e, 1.0))
		"z-": return AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1.0, 1.0, e))
		_: return AABB(Vector3(-0.5, -0.5, 0.5 - e), Vector3(1.0, 1.0, e))


## De combien, en fraction de case, deux sections qui doivent se raccorder peuvent s'écarter avant qu'on
## le DISE. **PROPOSÉ** : au-dessus du bruit des coupes (10⁻⁶), sous les fentes mesurées sur le travail
## texturé par Tripo (médiane 0,0026 case, 90 % sous 0,008 — des fentes VUES à l'écran).
const ECART_DE_SECTION := 0.001

## Au-delà, l'écart n'est plus mesuré : la section d'en face n'a rien à moins d'un cran de grille.
const _CRAN_DE_SECTION := 0.0625

## Les poses que le peintre emploie réellement, par classe : [{bits (du monde), base}].
static var _poses_par_classe: Dictionary = {}


## CONTRÔLE 4 — LES SECTIONS SE RACCORDENT : une REMARQUE, jamais une erreur (charte §3).
##
## La SECTION d'une tuile sur un plan de coupe, c'est le bord de sa matière posé sur ce plan : les arêtes
## que la découpe y a laissées. Deux tuiles voisines dans le monde se touchent par cette section ; si la
## leur ne tombe pas au même endroit, il reste une FENTE — le fond se voit à travers le monde peint.
## C'est le « cran suivant » que `verifier_couture` annonçait : comparer les SECTIONS, pas les aires.
##
## ⚠ **POURQUOI UN AUTRE CONTRÔLE ET PAS `verifier_couture` REFAIT — MESURÉ (29 septembre 2026).** Sur le
## travail d'un textureur automatique (le témoin passé dans Tripo), le monde peint montrait des fentes
## fines et régulières à chaque joint : 39 097 arêtes ouvertes, larges de 0,0026 case en médiane
## (`DEV_TOOLS/sonde_fentes.gd`). `verifier_couture` n'en a dit qu'UNE : une aire dans une bande de 0,08
## case ne voit pas un bord décalé de trois millièmes. Et ses seaux ne réunissent même pas les faces qui
## se RENCONTRENT : la face x+ d'une tuile et la face x− de sa voisine lisent les mêmes quatre cases, mais
## pour le groupe orienté ce sont deux germes distincts dès que le motif n'est pas symétrique.
##
## ⚠ **LE SEAU EST CE QUE LE MONDE MET FACE À FACE** : l'axe du plan et le motif de ses quatre cases VU DU
## PLAN, le côté oublié. Et chaque tuile y entre sous CHACUNE des orientations que le peintre lui donne
## réellement (`MB.classer` sur toute l'orbite de sa classe) : c'est la pose, pas une supposition de
## symétrie. Toutes les tuiles d'un seau peuvent se rencontrer — n'importe quelle clé, sous
## n'importe quelle pose —, donc toutes leurs sections doivent être la même. On compare chacune à la première, dans
## les deux sens : si toutes égalent la première, toutes s'égalent entre elles.
## ⚠ Un triangle d'aire nulle n'a pas de section : il ne compte pas.
## `tableaux_de` (facultatif) : nom → les tableaux de surface de sa pièce, déjà en mémoire — relire un maillage
## qu'on vient de fabriquer le redescend du GPU.
static func verifier_sections(pieces: Dictionary, bits_par_nom: Dictionary, remarques: Array,
		tableaux_de: Dictionary = {}) -> void:
	var seaux := {}   # "axe|motif" → [{nom, segments: PackedVector2Array (paires)}]
	var orphelines := 0
	var orpheline_de := ""
	for nom in pieces:
		var bits: int = bits_par_nom.get(MB.nom_nu(nom), bits_par_nom.get(nom, -1))
		if bits < 0:
			continue
		var segments: PackedVector3Array = _segments_sur_les_plans(pieces[nom], tableaux_de.get(nom, []))
		for pose in _poses_de(MB.classer(bits)["classe"]):
			var base: Basis = pose["base"]
			var tournes := PackedVector3Array()
			for p in segments:
				tournes.append(base * p)
			for axe in 3:
				for cote in [0, 1]:
					var motif: int = _motif_de_face(pose["bits"], axe, cote)
					var section: PackedVector2Array = _section(tournes, axe, 0.5 if cote == 1 else -0.5)
					# ⚠ **UNE FACE VIDE OU PLEINE DOIT AVOIR UNE SECTION VIDE.** En face, le sommet est
					# souvent MUET — le vide, le ventre plein — : aucune tuile n'y bouchera ce qui sort.
					if motif == 0 or motif == 15:
						if not section.is_empty():
							orphelines += 1
							if orphelines == 1:
								orpheline_de = "%s, plan %s" % [nom, "xyz"[axe]]
						continue
					var cle := "%d|%d" % [axe, motif]
					if not seaux.has(cle):
						seaux[cle] = []
					seaux[cle].append({"nom": nom, "segments": section})

	var fautes := 0
	var pire := 0.0
	var pire_de := ""
	for cle in seaux:
		var entrees: Array = seaux[cle]
		var reference: Dictionary = entrees[0]
		var grille_ref: Dictionary = _grille_de_segments(reference["segments"])
		for i in range(1, entrees.size()):
			var autre: Dictionary = entrees[i]
			var ecart: float = maxf(_ecart_vers(autre["segments"], reference["segments"], grille_ref),
				_ecart_vers(reference["segments"], autre["segments"],
					_grille_de_segments(autre["segments"])))
			if ecart > ECART_DE_SECTION:
				fautes += 1
				if ecart > pire:
					pire = ecart
					pire_de = "%s / %s, plan %s" % [reference["nom"], autre["nom"], "xyz"[int(cle.split("|")[0])]]
	if fautes > 0:
		remarques.append(("couture : %d face(s) de tuile dont la section ne tombe pas sur celle d'une voisine "
			+ "possible (écart jusqu'à %s case, entre %s) — le monde peint aura des fentes à ces joints ; "
			+ "ce qui franchit une coupe ne doit dépendre que des quatre cases de cette face")
			% [fautes, ("≥ %.4f" % _CRAN_DE_SECTION) if pire >= _CRAN_DE_SECTION else "%.4f" % pire, pire_de])
	if orphelines > 0:
		remarques.append(("couture : %d face(s) de tuile laissent de la matière sur un plan dont les quatre "
			+ "cases sont toutes vides ou toutes pleines (la première : %s) — en face il n'y a souvent AUCUNE "
			+ "tuile, et ce bord restera ouvert dans le monde peint") % [orphelines, orpheline_de])


## Les poses d'une classe : chaque configuration de son orbite et la base que le peintre lui applique.
static func _poses_de(classe: int) -> Array:
	if _poses_par_classe.is_empty():
		var grille := GridMap.new()   # ⚠ seulement pour lire les bases d'orientation, comme `trancher()`
		for b in 256:
			var r: Dictionary = MB.classer(b)
			if not r["surface"]:
				continue
			if not _poses_par_classe.has(r["classe"]):
				_poses_par_classe[r["classe"]] = []
			_poses_par_classe[r["classe"]].append({"bits": b,
				"base": grille.get_basis_with_orthogonal_index(r["orientation"])})
		grille.free()
	return _poses_par_classe.get(classe, [])


## LES RACCORDS QUE LE TÉMOIN PROUVE — une tuile par clé, en copies liées (charte §3, 30 septembre 2026).
##
## Le témoin lié est le monde peint de sa propre forme : chaque sommet à surface y montre LA tuile de sa
## clé. Un joint étanche entre deux sommets voisins prouve que deux faces de tuile ont la même section.
## Pour qu'un monde QUELCONQUE soit étanche, il faut que toutes les faces d'un même seau de
## `verifier_sections` (axe, motif vu du plan) aient la même section — donc que, dans chaque seau, les
## nœuds (clé, pose, axe, côté) soient RELIÉS par des joints du témoin : l'égalité est transitive.
##
## ⚠ **LES NŒUDS SONT CEUX DU MONDE, PAS CEUX DU TÉMOIN** : chaque clé du monde sans contact diagonal,
## sous chaque pose de son orbite. Une clé que le témoin ne montre jamais laisse donc ses nœuds isolés.
## ⚠ **UN JOINT VAUT POUR SES QUARTS DE TOUR SEULEMENT SI LE PEINTRE TOURNE LES DEUX TUILES AVEC LUI**
## (base(Q·b) = Q·base(b) aux deux bouts). Sinon — une classe symétrique dont la tuile ne l'est pas —,
## le joint tourné est un autre fait, que le témoin ne montre pas.
## ⚠ C'est une condition SUFFISANTE : un morceau que le contexte empêcherait de rencontrer les autres
## n'aurait pas besoin d'être relié. On ne raffine pas tant qu'elle se laisse tenir.
##
## Rend {"seaux", "relies", "en_trop" (morceaux au-delà d'un par seau), "morceaux": [{"seau", "noeuds"}]}
## — `morceaux` liste les nœuds HORS du plus gros morceau de chaque seau, écrits « clé|bits|axe|côté ».
static func raccords_du_temoin(pleines: Dictionary) -> Dictionary:
	_preparer_les_raccords()
	var plafond: int = MB.plafond_de(pleines)
	var cle_de := {}
	var bits_de := {}
	for c in pleines:
		for s in MB.sommets_de(c):
			if cle_de.has(s):
				continue
			var r: Dictionary = cle_du_sommet(pleines, s, plafond)
			cle_de[s] = r.get("cle", "")
			bits_de[s] = r.get("bits", 0)
	var parent := {}
	for n in _seau_du_noeud:
		parent[n] = n
	for s in cle_de:
		if cle_de[s] == "":
			continue
		for axe in 3:
			var e := Vector3i.ZERO
			e[axe] = 1
			var w: Vector3i = s + e
			if cle_de.get(w, "") == "":
				continue
			var motif: int = _motif_de_face(bits_de[s], axe, 1)
			if motif == 0 or motif == 15:
				continue
			for q in 4:
				var bs: int = _bits_tournes[q][bits_de[s]]
				var bw: int = _bits_tournes[q][bits_de[w]]
				if q > 0 and not (_tourne_avec[q][bits_de[s]] and _tourne_avec[q][bits_de[w]]):
					continue
				var d: Vector3i = _axe_tourne(q, axe)
				var axe2: int = 0 if d.x != 0 else (1 if d.y != 0 else 2)
				var cote_s: int = 1 if d[axe2] > 0 else 0
				var na := "%s|%d|%d|%d" % [cle_de[s], bs, axe2, cote_s]
				var nb := "%s|%d|%d|%d" % [cle_de[w], bw, axe2, 1 - cote_s]
				if parent.has(na) and parent.has(nb):
					parent[_racine(parent, na)] = _racine(parent, nb)
	var par_seau := {}
	for n in _seau_du_noeud:
		var sk: String = _seau_du_noeud[n]
		if not par_seau.has(sk):
			par_seau[sk] = {}
		var r: String = _racine(parent, n)
		if not par_seau[sk].has(r):
			par_seau[sk][r] = []
		par_seau[sk][r].append(n)
	var relies := 0
	var en_trop := 0
	var morceaux: Array = []
	var seaux: Array = par_seau.keys()
	seaux.sort()
	for sk in seaux:
		var comps: Dictionary = par_seau[sk]
		if comps.size() == 1:
			relies += 1
			continue
		en_trop += comps.size() - 1
		var gros := ""
		for r in comps:
			if gros == "" or (comps[r] as Array).size() > (comps[gros] as Array).size():
				gros = r
		var hors: Array = []
		for r in comps:
			if r != gros:
				hors.append_array(comps[r])
		hors.sort()
		morceaux.append({"seau": sk, "noeuds": hors})
	return {"seaux": par_seau.size(), "relies": relies, "en_trop": en_trop, "morceaux": morceaux}


static var _seau_du_noeud: Dictionary = {}
static var _bits_tournes: Array = []   # [q][bits] → bits tournés de q quarts de tour autour de +Y
static var _tourne_avec: Array = []    # [q][bits] → base(Q·b) == Q·base(b)
static var _quarts: Array = []


static func _preparer_les_raccords() -> void:
	if not _seau_du_noeud.is_empty():
		return
	var grille := GridMap.new()   # ⚠ seulement pour lire les bases d'orientation, comme `_poses_de`
	var base_de := {}
	for b in 256:
		var r: Dictionary = MB.classer(b)
		if r["surface"]:
			base_de[b] = grille.get_basis_with_orthogonal_index(r["orientation"])
	grille.free()
	for q in 4:
		_quarts.append(Basis(Vector3.UP, q * PI / 2.0))
	for q in 4:
		var tournes: Array = []
		var avec: Array = []
		for b in 256:
			var bt := 0
			for t in 8:
				if b & (1 << t) == 0:
					continue
				var c: Vector3 = _quarts[q] * (Vector3(MB.COINS[t]) - Vector3(0.5, 0.5, 0.5)) + Vector3(0.5, 0.5, 0.5)
				var ci := Vector3i(c.round())
				for u in 8:
					if MB.COINS[u] == ci:
						bt |= 1 << u
			tournes.append(bt)
			var ok := false
			if base_de.has(b) and base_de.has(bt):
				var attendu: Basis = _quarts[q] * base_de[b]
				var vu: Basis = base_de[bt]
				ok = (attendu.x - vu.x).length() < 1e-4 and (attendu.y - vu.y).length() < 1e-4 \
					and (attendu.z - vu.z).length() < 1e-4
			avec.append(ok)
		_bits_tournes.append(tournes)
		_tourne_avec.append(avec)
	for c in MB.classes():
		var bits: int = c["bits"]
		if not MB.porte_une_surface(bits) or not MB.sans_contact_diagonal(bits):
			continue
		var cles: Array = [c["nom"]]
		if MB.exterieur_possible(bits):
			cles.append(MB.nom_en_contexte(c["nom"], true))
		for cle in cles:
			for pose in _poses_de(MB.classer(bits)["classe"]):
				var b: int = pose["bits"]
				for axe in 3:
					for cote in [0, 1]:
						var motif: int = _motif_de_face(b, axe, cote)
						if motif == 0 or motif == 15:
							continue
						_seau_du_noeud["%s|%d|%d|%d" % [cle, b, axe, cote]] = "%d|%d" % [axe, motif]


static func _axe_tourne(q: int, axe: int) -> Vector3i:
	var e := Vector3.ZERO
	e[axe] = 1.0
	return Vector3i((_quarts[q] * e).round())


static func _racine(parent: Dictionary, n: String) -> String:
	while parent[n] != n:
		parent[n] = parent[parent[n]]
		n = parent[n]
	return n


## Le motif (4 bits) des cases d'une face, VU DU PLAN : le côté (`cote`, 0 ou 1 sur `axe`) est oublié,
## c'est ce qui réunit la face x+ d'une tuile et la face x− de sa voisine. Bit u + 2v, (u, v) sur les deux
## autres axes dans l'ordre croissant.
static func _motif_de_face(bits: int, axe: int, cote: int) -> int:
	var u_axe: int = 1 if axe == 0 else 0
	var v_axe: int = 1 if axe == 2 else 2
	var motif := 0
	for t in 8:
		var c: Vector3i = MB.COINS[t]
		if c[axe] == cote and (bits & (1 << t)) != 0:
			motif |= 1 << (c[u_axe] + 2 * c[v_axe])
	return motif


## Les arêtes d'un maillage (repère de pièce) posées sur une face de la boîte unité, par paires de points.
## ⚠ Une arête de la boîte est sur DEUX faces : elle est gardée une fois, et `_section` la lira sur chacune.
static func _segments_sur_les_plans(mesh: Mesh, tableaux: Array = []) -> PackedVector3Array:
	var sortie := PackedVector3Array()
	var liste: Array = tableaux
	if liste.is_empty():
		liste = []
		for s in mesh.get_surface_count():
			liste.append(mesh.surface_get_arrays(s))
	for arrays in liste:
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx = arrays[Mesh.ARRAY_INDEX]
		var ordre: PackedInt32Array = (idx as PackedInt32Array) if idx != null \
			else PackedInt32Array(range(v.size()))
		for t in range(0, ordre.size() - 2, 3):
			var a: Vector3 = v[ordre[t]]
			var b: Vector3 = v[ordre[t + 1]]
			var c: Vector3 = v[ordre[t + 2]]
			if (b - a).cross(c - a).length_squared() < 1e-18:
				continue   # d'aire nulle : pas de section
			for pa in [[a, b], [b, c], [c, a]]:
				for axe in 3:
					if absf(absf(pa[0][axe]) - 0.5) < 0.0005 and absf(pa[1][axe] - pa[0][axe]) < 0.0005:
						sortie.append(pa[0])
						sortie.append(pa[1])
						break
	return sortie


## Les segments posés sur le plan `axe = valeur`, projetés sur les deux autres axes.
static func _section(segments: PackedVector3Array, axe: int, valeur: float) -> PackedVector2Array:
	var u_axe: int = 1 if axe == 0 else 0
	var v_axe: int = 1 if axe == 2 else 2
	var sortie := PackedVector2Array()
	for i in range(0, segments.size(), 2):
		var a: Vector3 = segments[i]
		var b: Vector3 = segments[i + 1]
		if absf(a[axe] - valeur) < 0.0005 and absf(b[axe] - valeur) < 0.0005:
			sortie.append(Vector2(a[u_axe], a[v_axe]))
			sortie.append(Vector2(b[u_axe], b[v_axe]))
	return sortie


## Les segments rangés par cran de grille, pour qu'une recherche de voisin ne balaie pas tout.
static func _grille_de_segments(segments: PackedVector2Array) -> Dictionary:
	var grille := {}
	for i in range(0, segments.size(), 2):
		var lo := Vector2i(((segments[i].min(segments[i + 1])) / _CRAN_DE_SECTION).floor())
		var hi := Vector2i(((segments[i].max(segments[i + 1])) / _CRAN_DE_SECTION).floor())
		for x in range(lo.x, hi.x + 1):
			for y in range(lo.y, hi.y + 1):
				var k := Vector2i(x, y)
				if not grille.has(k):
					grille[k] = []
				grille[k].append(i)
	return grille


## Le plus grand écart d'un point de `de` (extrémités et milieux) à la section `vers`, plafonné au cran.
static func _ecart_vers(de: PackedVector2Array, vers: PackedVector2Array, grille: Dictionary) -> float:
	var pire := 0.0
	for i in range(0, de.size(), 2):
		for q in [de[i], de[i + 1], (de[i] + de[i + 1]) * 0.5]:
			var meilleur := _CRAN_DE_SECTION
			var c := Vector2i((q / _CRAN_DE_SECTION).floor())
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					for j in grille.get(c + Vector2i(dx, dy), []):
						var p: Vector2 = Geometry2D.get_closest_point_to_segment(q, vers[j], vers[j + 1])
						meilleur = minf(meilleur, q.distance_to(p))
			pire = maxf(pire, meilleur)
			if pire >= _CRAN_DE_SECTION:
				return pire
	return pire


## LA `MeshLibrary` D'UN BLOC TRANCHÉ, COMPLÉTÉE PAR LE REPLI.
##
## ⚠ **UN BLOC NE LIVRE JAMAIS LES 68 CLASSES, ET C'EST NORMAL.** Un bloc plein n'en donne que huit ;
## il faut creuser des cellules pour atteindre les concaves, et aucun bloc raisonnable ne les présente
## toutes. Si le lot ne contenait QUE les classes tranchées, il serait **moins complet que pas de lot
## du tout** — le peintre retomberait sur des cubes rouges là où le repli procédural savait rendre.
##
## D'où la règle : **le tranché remplace, le repli complète.** Chaque classe sculptée prend la place de
## sa version calculée, une à une, et l'invariant tient à chaque étape du travail d'art.
static func librairie(pieces: Dictionary) -> MeshLibrary:
	var Repli := load("res://addons/marchingblocks_core/repli_procedural.gd")
	var lot := MeshLibrary.new()
	var id := 0
	for c in MB.classes():
		if not MB.porte_une_surface(c["bits"]):
			continue
		# ⚠ **ON CHERCHE AUSSI LA VARIANTE, ET SON OUBLI SUBSTITUAIT EN SILENCE.** Une classe récoltée
		# uniquement à l'air libre n'existe que sous « <classe>_dehors » : cette fonction ne la trouvait
		# pas et posait le REPLI PROCÉDURAL à sa place. L'art de l'artiste était remplacé par de la
		# géométrie calculée, sans une seule erreur — exactement la panne muette que ce projet traque.
		var mesh: ArrayMesh = pieces.get(c["nom"], null)
		if mesh == null or mesh.get_surface_count() == 0:
			mesh = pieces.get(MB.nom_en_contexte(c["nom"], true), null)
		if mesh == null or mesh.get_surface_count() == 0:
			mesh = Repli.maillage(c["bits"])
		lot.create_item(id)
		lot.set_item_name(id, c["nom"])
		lot.set_item_mesh(id, mesh)
		lot.set_item_shapes(id, Repli.collision(c["bits"]))
		id += 1
	return lot


## Ce que le bloc N'A PAS donné : les classes de surface qu'aucun de ses sommets ne présente.
## ⚠ Ce n'est pas une faute — un bloc plein ne peut pas produire les formes concaves — c'est une
## INFORMATION : elle dit au sculpteur quelles cellules creuser pour compléter son lot, et elle dit au
## greffon lesquelles garderont leur repli procédural.
static func manquantes(pieces: Dictionary) -> Array:
	# ⚠ **UNE CLASSE RÉCOLTÉE EN VARIANTE N'EST PAS MANQUANTE.** Cette fonction comparait des noms NUS à
	# des clés qui peuvent porter « _dehors » : elle déclarait absentes 63 classes parfaitement livrées.
	# Elle est employée par le greffon ET par les tests, donc le défaut rendait aussi des assertions
	# vertes pour une mauvaise raison — « il reste des manquantes » était vrai quoi qu'il arrive.
	var recoltees := {}
	for cle in pieces:
		recoltees[MB.nom_nu(cle)] = true
	var absentes: Array = []
	for nom in MB.pieces_a_sculpter():
		if not recoltees.has(nom):
			absentes.append(nom)
	return absentes
