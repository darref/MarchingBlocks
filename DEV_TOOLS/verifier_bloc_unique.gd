extends SceneTree
##
## LE BLOC MAÎTRE UNIQUE — la silhouette écrite à la main, la couverture finie mécaniquement.
##
## ⚠ **IL N'ENGENDRE PLUS LE TÉMOIN LIVRÉ DEPUIS LE 27 SEPTEMBRE 2026.** Le greffon porte désormais la
## planète paysage de 12³, produite par `planete_paysage.gd --couches`. Cet outil reste parce qu'il porte
## le finisseur et son élagage (charte §2), mais sa silhouette de 8³ est celle de l'ancien monde. Ses
## cibles lisent les pièces à sculpter du monde sans diagonale (35 + 17), et `--residu`, qui supposait
## deux témoins, refuse de tourner.
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/verifier_bloc_unique.gd
##
## ── LE CONTRAT (DÉCIDÉ, Jordan, 24 septembre 2026) ──────────────────────────────────────────────────
##
##   • UN SEUL bloc de 8³ remplace les neuf de 4³ ;
##   • il livre **68 classes en contexte INTÉRIEUR** et **22 en EXTÉRIEUR**, soit 90 tuiles ;
##   • sa matière est d'UN SEUL MORCEAU — c'est un objet sculptable ;
##   • et il se LIT comme un paysage : le témoin montre à l'artiste ce qu'on attend de lui.
##
## ── POURQUOI UN FINISSEUR, ET POURQUOI SOUS CONTRAINTE ──────────────────────────────────────────────
##
## ⚠ **CINQ VERSIONS ÉCRITES À LA MAIN ONT PLAFONNÉ À 43/90** (44 → 30 → 37 → 38 → 43). Le diagnostic
## « irrégularité dans les trois axes » a payé sur l'intérieur (27 → 32), mais l'extérieur est resté
## bloqué à 11/22, et il manquait 47 classes quand la meilleure retouche disponible en valait 7. La main
## seule ne converge pas ; une recherche seule rend de la roche chaotique. D'où le partage :
##
##   **la main tient la SILHOUETTE, la recherche complète la COUVERTURE là où l'œil ne voit rien.**
##
## ⚠ **ET LA TAILLE EST PASSÉE DE 7³ À 8³ SUR UNE MESURE, pas sur un goût** : à 7³ la couverture
## complète n'a été trouvée que par une recherche profonde (8 essais, 2 000 pas) ; à 8³ elle tombe
## immédiatement. 7³ était au BORD du faisable — le pire terrain pour une écriture à la main.
##
## ── UNE SEULE GRILLE, QUATRE CARACTÈRES ─────────────────────────────────────────────────────────────
##
##   `#`  plein, VERROUILLÉ — la silhouette : socle, ligne de falaise, contour du plateau
##   `.`  vide,  VERROUILLÉ — le ciel et l'air libre à l'est
##   `+`  plein, LIBRE      — le finisseur peut creuser ici
##   `-`  vide,  LIBRE      — le finisseur peut remplir ici
##
## ⚠ **UNE grille et non deux.** Une grille de forme plus une grille de permissions seraient DEUX
## DESCRIPTIONS DU MÊME LIEU, et elles divergeraient à la première retouche — la faute que ce projet a
## déjà payée deux fois.
##
## ⚠ **LE CIEL EST VERROUILLÉ VIDE, et ce n'est pas un détail** : sans ce verrou le finisseur remplirait
## l'air libre à l'est et supprimerait la falaise, qui est précisément ce qui produit les classes
## EXTÉRIEURES. Une contrainte absente se paie toujours du côté qu'on ne surveillait pas.
##
## ── LES CONVENTIONS, REPRISES DU GREFFON ET NON RÉINVENTÉES ─────────────────────────────────────────
##
## ⚠ Le critère de contexte est « ROCHE AU-DESSUS », celui du modèle (`MB.exterieur_possible`). En
## employer un autre ici validerait le bloc contre une règle que le pinceau n'appliquera pas.
## ⚠ On ne récolte que les sommets INTÉRIEURS — (8−1)³ = 343.

const MB := preload("res://addons/marching_blocks_plugin_godot/marching_blocks.gd")
## ⚠ La coque en sous-voxels et le bilan topologique vivent dans un module PARTAGÉ avec
## `sonde_topologie_export.gd` : deux copies d'un même calcul divergent, et ce projet l'a déjà payé.
const Topo := preload("res://DEV_TOOLS/topologie.gd")
## ⚠ Pour le MODE RÉSIDU seulement : lire ce que le PREMIER témoin couvre déjà, afin de ne pas le
## refabriquer. Le vérificateur ne dépend pas des blocs livrés en dehors de ce mode.
const BM := preload("res://addons/marching_blocks_plugin_godot/blocs_maitres.gd")

const COTE := 8

const VOISINS := [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

## ⚠ `COUCHES[y][z]` est une rangée de 8 caractères indexée par x. y = 0 est le BAS.
##
## Le paysage, d'en bas vers le haut :
##   y=0  LE SOCLE — bord verrouillé, cœur libre (le finisseur peut y creuser des cuvettes)
##   y=1..2  LA GROTTE — parois verrouillées, volume entièrement libre
##   y=3  LE PLAFOND — libre, pour que le finisseur choisisse son épaisseur et ses percements
##   y=4  LE CORPS, et LA FALAISE QUI SERPENTE (verrouillée : c'est elle qui fait l'extérieur)
##   y=5  LE PLATEAU qui recule, avec un SURPLOMB en z = 5 (verrouillé)
##   y=6..7  LE BORD et les ÉPERONS — libres, c'est là que l'œil ne distingue pas deux solutions
const COUCHES := [
	[   # y = 0 — le socle
		"########",
		"########",
		"##++++##",
		"##++++##",
		"##++++##",
		"##++++##",
		"########",
		"########",
	],
	[   # y = 1 — la grotte, volume libre entre des parois verrouillées
		"######..",
		"#----#..",
		"#----#..",
		"#----#..",
		"#----#..",
		"#----#..",
		"#----#..",
		"######..",
	],
	[   # y = 2 — la grotte se poursuit
		"######..",
		"#----#..",
		"#----#..",
		"#----#..",
		"#----#..",
		"#----#..",
		"#----#..",
		"######..",
	],
	[   # y = 3 — le plafond : plein au départ, mais libre
		"######..",
		"#++++#..",
		"#++++#..",
		"#++++#..",
		"#++++#..",
		"#++++#..",
		"#++++#..",
		"######..",
	],
	[   # y = 4 — le corps. ⚠ SEULES la première et la DERNIÈRE colonne pleine restent verrouillées :
		#     c'est la LIGNE DE FALAISE QUI SERPENTE, donc la silhouette. Tout l'intérieur passe au
		#     finisseur — mesuré, c'est son uniformité qui privait les sommets de y=3/y=4 des formes
		#     tordues (vrille, crochet, damier), et non la contrainte de connexité (contrôle négatif).
		"#++++#..",
		"#+++#...",
		"#++++#..",
		"#+++++#.",
		"#++++#..",
		"#+++#...",
		"#++++#..",
		"#++++#..",
	],
	[   # y = 5 — le plateau recule ; le SURPLOMB de z = 5 tient à sa dernière colonne, verrouillée
		"#+++#...",
		"#++#....",
		"#+++#...",
		"#++++#..",
		"#+++#...",
		"#++++#..",
		"#+++#...",
		"#+++#...",
	],
	[   # y = 6 — le bord, libre
		"+++++...",
		"++++....",
		"+++++...",
		"++++....",
		"+++++...",
		"++++....",
		"+++++...",
		"++++....",
	],
	[   # y = 7 — les éperons, libres
		"+++.....",
		"++......",
		"+++.....",
		"++......",
		"+++.....",
		"++......",
		"+++.....",
		"++......",
	],
]

var _libres: Array = []       # les cases que le finisseur a le droit de changer

## ⚠ **INTERRUPTEUR PUREMENT DIAGNOSTIQUE — `--sans-connexite`.** Il n'existe pas pour livrer un bloc :
## Jordan veut un objet sculptable d'un seul tenant, et une poussière de morceaux ne serait pas un bloc
## maître. Il existe comme **CONTRÔLE NÉGATIF**, pour attribuer une cause au lieu de la supposer.
##
## Les six classes qui manquaient à 84/90 — `damier`, `vrille`, `crochet`, `biais creux`,
## `pointe creuse` — sont toutes des configurations en DIAGONALE, où la matière d'un voisinage 2×2×2 ne
## se touche que par des arêtes ou des coins. Or c'est exactement ce qu'une règle « rester d'un seul
## morceau à chaque coup » rend difficile à atteindre. Deux lancements sur la MÊME grille tranchent :
##   • 90 sans la contrainte, 84 avec  ⇒ c'est la CONNEXITÉ qui bloque, il faut de l'ÉPAISSEUR ;
##   • 84 dans les deux cas            ⇒ c'est la ZONE LIBRE qui est trop petite ou mal placée.
var _imposer_connexite := true

## ── LE MODE RÉSIDU : finir le SECOND témoin, pas le premier ─────────────────────────────────────────
##
## ⚠ **DEUX TÉMOINS DEPUIS LE 25 septembre 2026 (Jordan)** : le premier montre ce qu'on rencontre le
## plus — massifs, grotte, tunnel, arche, puits — et ne couvre que 27 des 90 tuiles ; le second
## « récolte tout le reste qui n'a pas été utilisé ».
##
## ⚠ **SANS CE MODE, LE FINISSEUR REDONDE LE PREMIER TÉMOIN.** Il vise les 90 classes, donc il dépense
## sa matière à refabriquer les 27 que le paysage montre déjà — alors que ces 27 sont précisément
## celles qu'il ne doit PAS porter, puisque « le premier bloc gagne » dans `librairie()`.
##
## ⚠ **ET LE RÉSIDU EST DÉDUIT, JAMAIS RECOPIÉ** : il s'obtient en appliquant `_contextes()` — la MÊME
## fonction qui juge le bloc en cours — aux cases du bloc 0. Écrire ici la liste des 63 classes serait
## une seconde description qui se périmerait au premier retouchage du paysage.
var _mode_residu := false
var _residu_int := {}
var _residu_ext := {}

## ── LE MONDE SANS CONTACT DIAGONAL — DÉCIDÉ (Jordan, 25 septembre 2026) ─────────────────────────────
##
## ⚠ **CE MODE RÉPOND À LA SEULE QUESTION QUI RESTAIT AVANT DE BASCULER** : un témoin sans contact
## diagonal peut-il réellement EXHIBER les 52 tuiles de ce monde ? La charte affirmait « 52/90, trois
## essais sur trois » — trois fois exactement le maximum théorique — mais elle le rangeait comme un
## ÉCHEC, et c'est un chiffre CITÉ. Cette charte m'en a déjà servi trois de faux : on le reproduit.
##
## ⚠ **LA BORNE EST `COTE`, PAS LE MONDE.** Les faces extérieures d'un bloc sont des faces de SCIAGE et
## la Convention (A) ne récolte jamais ses sommets de bord : y réparer une diagonale éroderait la
## silhouette pour des sommets que le greffon ne lit pas. Le pinceau, lui, emploiera la version non
## bornée — dans un monde peint, l'extérieur est réellement du vide.
var _sans_diagonale := false


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option == "--sans-connexite":
			_imposer_connexite = false
		if option == "--residu":
			_mode_residu = true
		if option == "--sans-diagonale":
			_sans_diagonale = true
	if _mode_residu:
		print("⚠ --residu supposait DEUX témoins, et le greffon n'en porte plus qu'un (27 septembre 2026).")
		quit(1)
		return
	print("=== LE BLOC MAÎTRE UNIQUE (8³) ===")
	print("    connexité imposée : %s\n" % ("oui" if _imposer_connexite else "NON (diagnostic)"))
	var pleines: Dictionary = _lire()
	if pleines.is_empty():
		quit(1)
		return
	if _sans_diagonale:
		# ⚠ **LA SILHOUETTE DOIT OBÉIR AU MONDE AVANT QUE LA RECHERCHE COMMENCE.** Elle porte 2 contacts
		# diagonaux ; sans ce nettoyage, `ok` refuserait tous les coups et la recherche ne dirait rien.
		# On emploie la règle de Jordan elle-même — on COMPLÈTE le trou, on ne refuse pas.
		var coupees: int = MB.completer_les_carres(pleines, COTE)
		print("── LE MONDE SANS CONTACT DIAGONAL ──")
		print("   cible : %d tuiles (%d classes atteignables + leurs variantes d'air libre)"
			% [_cible_sans_diagonale(), MB.classes_sans_diagonale().size()])
		print("   la silhouette a perdu %d case(s) en se conformant au monde\n" % coupees)
	print("── LA SILHOUETTE ÉCRITE À LA MAIN ──")
	_mesurer(pleines, "départ")
	var fini: Dictionary = _finir(pleines)
	print("\n── APRÈS LE FINISSEUR ──")
	_mesurer(fini, "fini")
	_dire_les_manquantes(fini)
	_topologie(fini)
	_rendre(fini)
	quit(0)


## ⚠ **CE QUE L'ARTISTE OUVRIRAIT VRAIMENT.** La couverture ne dit rien de la topologie : un bloc peut
## livrer ses 90 tuiles et arriver dans Blender avec des arêtes que nulle boucle ne traverse. On mesure
## donc la **coque en sous-voxels amincie** — la version qui partirait à l'export — et non l'occupation.
##
## ⚠ **ET ON SAIT DÉJÀ QUE LE ZÉRO EST IMPOSSIBLE** : 33 des 68 classes SONT des contacts diagonaux
## (`diagonale`, `damier`, `chicane`, `biais`, `crochet`…), donc un témoin complet contient
## nécessairement des arêtes non-manifold. Interdire ces contacts fait tomber la couverture à 52/90 —
## mesuré. La question n'est donc pas « comment atteindre zéro » mais **« combien en reste-t-il, et
## est-ce acceptable »**.
func _topologie(pleines: Dictionary) -> void:
	print("\n── LA TOPOLOGIE DE CE QUI PARTIRAIT À L'EXPORT ──")
	print("   contacts par arête dans l'occupation : %d" % MB.contacts_par_arete(pleines))
	for essai in [
		{"nom": "solide (retrait 0)", "retrait": 0.0},
		{"nom": "aminci (retrait 0,25)", "retrait": 0.25},
	]:
		var b: Dictionary = Topo.bilan(
			Topo.coque_sous_voxels(pleines, essai["retrait"]), pleines)
		var q4: int = int((b["q_val"] as Dictionary).get(4, 0))
		print("   %-22s %5d quads, %d orphelin(s) · bords %d, 3+faces %d · valence 4 : %.0f %%  %s"
			% [essai["nom"], b["quads"], b["orphelins"], b["q_bords"], b["q_multiples"],
				100.0 * float(q4) / float(maxi(1, b["q_sommets"])),
				"✓ manifold" if b["q_bords"] == 0 and b["q_multiples"] == 0 else "⚠"])


## Lit la grille. ⚠ Refuse une couche mal formée plutôt que de la deviner.
func _lire() -> Dictionary:
	var pleines := {}
	_libres = []
	if COUCHES.size() != COTE:
		print("⚠ %d couches au lieu de %d" % [COUCHES.size(), COTE])
		return {}
	for y in COUCHES.size():
		var rangees: Array = COUCHES[y]
		if rangees.size() != COTE:
			print("⚠ couche y=%d : %d rangées au lieu de %d" % [y, rangees.size(), COTE])
			return {}
		for z in rangees.size():
			var rangee: String = rangees[z]
			if rangee.length() != COTE:
				print("⚠ couche y=%d rangée z=%d : %d caractères au lieu de %d"
					% [y, z, rangee.length(), COTE])
				return {}
			for x in rangee.length():
				var c: String = rangee[x]
				var p := Vector3i(x, y, z)
				match c:
					"#": pleines[p] = true
					".": pass
					"+":
						pleines[p] = true
						_libres.append(p)
					"-": _libres.append(p)
					_:
						print("⚠ y=%d z=%d : caractère « %s » interdit" % [y, z, c])
						return {}
	return pleines


## ⚠ **UNE CARTE DES VIDES COIFFÉS A VÉCU ICI, ET ELLE AVAIT DIVERGÉ DU GREFFON.** Elle sondait la
## COLONNE ENTIÈRE de chaque cellule VIDE ; `MB.sous_le_ciel()` sonde les huit cellules du sommet,
## PLEINES COMPRISES, jusqu'au plus haut `y` occupé. Deux descriptions du même critère, donc deux
## réponses — et c'est le module du modèle qui fait foi, puisque c'est lui que le pinceau applique.


func _morceaux(pleines: Dictionary) -> int:
	var vus := {}
	var combien := 0
	for c in pleines:
		if vus.has(c):
			continue
		combien += 1
		var pile: Array = [c]
		vus[c] = true
		while not pile.is_empty():
			var p: Vector3i = pile.pop_back()
			for d in VOISINS:
				var q: Vector3i = p + d
				if pleines.has(q) and not vus.has(q):
					vus[q] = true
					pile.append(q)
	return combien


## ⚠ **LA COMPACITÉ, EN UN CHIFFRE : le nombre de faces roche/vide.** Sans elle je jugerais « lisible »
## à l'œil, ce qui m'a trompé trois fois sur ce bloc. Du grain expose beaucoup de faces pour peu de
## matière ; une masse en expose peu.
## ⚠ On ne compte que les voisins DANS la grille : la silhouette extérieure est verrouillée, donc sa
## contribution serait constante et ne dirait rien de ce que le finisseur a fait.
func _expose(pleines: Dictionary) -> int:
	var faces := 0
	for c in pleines:
		var p: Vector3i = c
		for d in VOISINS:
			var q: Vector3i = p + d
			if q.x < 0 or q.y < 0 or q.z < 0 or q.x >= COTE or q.y >= COTE or q.z >= COTE:
				continue
			if not pleines.has(q):
				faces += 1
	return faces


## Ce que le bloc livre — EXACTEMENT ce que `librairie()` en tirera.
##
## ⚠ **CETTE FONCTION CALCULAIT SON PROPRE CRITÈRE, ET IL AVAIT DIVERGÉ.** Elle rangeait les sommets en
## TROIS camps — dedans, dehors, et « mixtes » qu'elle ÉCARTAIT des deux. Le pinceau n'en connaît que
## deux : un sommet dont **une seule** cellule est coiffée est INTÉRIEUR, point. Mesuré sur la
## silhouette en place : la machine annonçait **90/90** là où le greffon livrait **73**, et les
## **35 sommets « mixtes »** étaient exactement l'écart. Le finisseur optimisait donc contre une
## définition plus permissive que la réalité, et personne ne pouvait le voir tant que rien en aval ne
## comptait les contextes.
##
## ⚠ **ELLE COMPOSE DÉSORMAIS LA MÊME CLÉ QUE LE TRANCHEUR** : nom nu, ou nom suffixé quand la classe
## PEUT être dehors **et** que le lieu l'EST. Brancher `sous_le_ciel` sans reprendre
## `exterieur_possible` aurait laissé la moitié du critère de côté et fait reparaître la divergence
## sous un autre nom.
func _contextes(pleines: Dictionary) -> Dictionary:
	var plafond: int = MB.plafond_de(pleines)
	var nus := {}
	var variantes := {}
	var n_int := 0    # ⚠ le nombre de SOMMETS, pas de classes : c'est lui qui dit la marge
	var n_ext := 0
	for vx in range(COTE - 1):
		for vy in range(COTE - 1):
			for vz in range(COTE - 1):
				var v := Vector3i(vx, vy, vz)
				var b: int = MB.bits(pleines, v)
				if not MB.porte_une_surface(b):
					continue
				var nom: String = MB.classer(b)["nom"]
				var dehors: bool = MB.exterieur_possible(b) and MB.sous_le_ciel(pleines, v, plafond)
				if dehors:
					variantes[nom] = true
					n_ext += 1
				else:
					nus[nom] = true
					n_int += 1
	return {"int": nus, "ext": variantes, "n_int": n_int, "n_ext": n_ext}


## Le score : le nombre de TUILES que `librairie()` livrerait — noms nus plus variantes.
##
## ⚠ **LE FILTRE « classes autorisées à l'air libre » A DISPARU D'ICI, ET CE N'EST PAS UN OUBLI.** Il
## existait parce que l'ancien critère pouvait ranger dehors une classe que le modèle interdit à l'air
## libre. `_contextes()` appliquant maintenant `exterieur_possible()` lui-même, un tel nom ne peut plus
## entrer dans `ext` : refiltrer ici serait une seconde description de la même règle.
## ⚠ **ET CE SCORE EST AVEUGLE AU CONTEXTE — MESURÉ, ET C'EST LE PROCHAIN CHANTIER.** Une classe
## d'INTÉRIEUR gagnée y vaut exactement une classe d'EXTÉRIEUR perdue. Or la marge n'est pas la même des
## deux côtés : ×4,53 dedans contre ×0,95 dehors. Le grimpeur trouve donc toujours plus facile de gagner
## à l'intérieur, et il **rebouche le ciel** pour y arriver.
##
## ⚠ **MESURÉ SUR UNE ÉBAUCHE QUI PARTAIT AVEC 49 SOMMETS DE CIEL — le plafond structurel d'un bloc
## 8³ — : le finisseur l'a ramenée à 21**, et il a rendu exactement les mêmes 73/90 et les mêmes 17
## classes extérieures manquantes que la silhouette d'origine. **Redessiner les couches ne servait donc
## à rien tant que la recherche pouvait dépenser le ciel.**
##
## ⚠ **LE REMÈDE EST POSÉ DANS `_finir` ET `_elaguer`, PAS ICI** : un PLANCHER de sommets sous le ciel,
## dérivé de la silhouette écrite à la main et imposé à chaque coup. Ce score reste donc aveugle au
## contexte — c'est assumé : le plancher l'empêche de nuire, et un score pondéré aurait demandé de
## choisir un poids arbitraire là où le plancher ne demande qu'à respecter le dessin de l'artiste.
## Le nombre de tuiles d'un monde sans contact diagonal : les classes atteignables, plus celles d'entre
## elles qui peuvent être à l'air libre. ⚠ DÉDUIT du modèle, jamais écrit en dur — mesuré à 52.
func _cible_sans_diagonale() -> int:
	var n := 0
	var e := 0
	for c in MB.classes():
		if not MB.porte_une_surface(c["bits"]) or not MB.sans_contact_diagonal(c["bits"]):
			continue
		n += 1
		if MB.exterieur_possible(c["bits"]):
			e += 1
	return n + e


func _score(pleines: Dictionary) -> int:
	return _compte(_contextes(pleines))


## Ce que vaut un relevé de contextes — TOUTES les classes, ou seulement celles du résidu.
##
## ⚠ **UN SEUL ENDROIT, parce que le grimpeur ne passe PAS par `_score()`.** Il rappelait
## `c2["int"].size() + c2["ext"].size()` en ligne pour éviter un second parcours du volume. Filtrer le
## résidu dans `_score` seul aurait donc laissé la boucle de recherche compter les 90 : elle aurait
## optimisé une cible et le rapport en aurait affiché une autre, sans qu'aucune erreur ne le dise.
func _compte(c: Dictionary) -> int:
	if not _mode_residu:
		return (c["int"] as Dictionary).size() + (c["ext"] as Dictionary).size()
	var n := 0
	for nom in c["int"]:
		if _residu_int.has(nom):
			n += 1
	for nom in c["ext"]:
		if _residu_ext.has(nom):
			n += 1
	return n


# ── LE FINISSEUR ────────────────────────────────────────────────────────────────────────────────────

## ⚠ **LA CONTRAINTE EST IMPOSÉE À CHAQUE COUP, PAS VÉRIFIÉE À LA FIN.** Le banc précédent l'a appris :
## une contrainte constatée après coup n'en est pas une — la recherche avait atteint sa cible avec une
## poussière de morceaux, et je ne m'en apercevais qu'au rapport.
func _finir(depart: Dictionary) -> Dictionary:
	var cible: int = _cible_sans_diagonale() if _sans_diagonale \
		else ((_residu_int.size() + _residu_ext.size()) if _mode_residu \
		else (MB.pieces_a_sculpter().size() + MB.exterieures_a_sculpter().size()))
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var meilleur: Dictionary = depart.duplicate()
	var meilleur_score: int = _score(depart)
	# ⚠ **LE PLANCHER DE CIEL — DÉRIVÉ DE LA SILHOUETTE, JAMAIS DÉCRÉTÉ.** Mesuré : le grimpeur
	# REBOUCHE le ciel, parce que son score compte une classe d'intérieur et une classe d'extérieur à
	# égalité alors que la marge est de ×4,53 dedans contre ×0,95 dehors. Un essai parti avec 49
	# sommets de ciel — le plafond structurel d'un bloc 8³ — a été ramené à 21, et il a rendu
	# exactement les mêmes 17 classes extérieures manquantes.
	# **La main décide de la quantité de ciel, la recherche n'a pas le droit de la dépenser.**
	var ciel_plancher: int = int(_contextes(depart)["n_ext"])
	print("\n   le finisseur ne touche qu'aux %d cases LIBRES sur %d — la silhouette est verrouillée"
		% [_libres.size(), COTE * COTE * COTE])

	var meilleur_expose: int = _expose(depart)
	for essai in 3:
		var pleines: Dictionary = depart.duplicate()
		var score: int = _score(pleines)
		for pas in 2200:
			var p: Vector3i = _libres[rng.randi_range(0, _libres.size() - 1)]
			var avait: bool = pleines.has(p)
			if avait:
				pleines.erase(p)
			else:
				pleines[p] = true
			# ⚠ **UN FILTRE « AUCUN CONTACT PAR ARÊTE » A VÉCU ICI, ET IL ÉTAIT AUTO-DESTRUCTEUR.**
			# L'idée : le nombre d'arêtes non-manifold du solide ÉGALE exactement le nombre de contacts
			# par arête (mesuré, 19/19, 13/13, 13/13 sur les blocs maîtres), donc les interdire rendrait
			# le témoin manifold à la source.
			#
			# ⚠ **MESURÉ : la couverture s'effondre de 90/90 à 52/90, et les trois essais tombent
			# exactement sur 52.** La raison est une contradiction de définition, pas un réglage : les
			# 33 classes manquantes sont `diagonale`, `damier`, `chicane`, `biais`, `crochet`,
			# `diagonale_creuse`… **et un « contact par arête » EST une de ces classes.**
			# `mb_diagonale_b1h1_a` vaut littéralement deux cellules qui ne se touchent que par une
			# arête. Interdire le contact, c'est interdire la classe.
			#
			# **CONCLUSION, ET ELLE EST DURE : un témoin qui couvre les 68 classes contient
			# NÉCESSAIREMENT des arêtes non-manifold.** C'est la même ambiguïté que le modèle nomme
			# `PONT_SUR_FACE_AMBIGUE`. On mesure donc le résidu et on le DIT à l'artiste, au lieu de
			# prétendre le supprimer.
			var ok: bool = not pleines.is_empty() \
				and (not _imposer_connexite or _morceaux(pleines) == 1) \
				and (not _sans_diagonale or MB.contacts_par_arete(pleines, COTE) == 0)
			# ⚠ **UN SEUL APPEL À `_contextes()` PAR PAS.** `_score()` le rappelait, et le plancher
			# l'aurait rappelé une seconde fois : trois parcours du volume là où un suffit.
			var c2: Dictionary = _contextes(pleines) if ok else {}
			# ⚠ **LE PLANCHER EST IMPOSÉ ICI, À CHAQUE COUP — PAS VÉRIFIÉ À LA FIN.** C'est la leçon déjà
			# écrite pour la connexité : une contrainte constatée après coup n'en est pas une. Reboucher
			# le ciel devient un coup REFUSÉ, au même titre que fragmenter la matière.
			if ok and int(c2["n_ext"]) < ciel_plancher:
				ok = false
			var s2: int = _compte(c2) if ok else -1
			# ⚠ **LE GRIMPEUR NE JUGE QUE LA COUVERTURE — appris en cassant les deux critères à la fois.**
			# J'avais mis la compacité en second critère ICI : la couverture est tombée à 88/90 et
			# l'exposition a MONTÉ, de 218 à 342. La cause est structurelle et pas un réglage : un gain de
			# couverture est accepté sans regarder l'exposition, donc la montée gonfle le grain
			# librement ; arrivée au plateau, elle est coincée dans un bassin d'où aucun basculement
			# isolé ne sort sans perdre une classe. **Le chemin décide du résultat.**
			# Le métier du grimpeur est de TROUVER une solution complète. La rendre lisible est celui de
			# l'élagage, qui revient vers la grille écrite à la main — et lui, mesuré, y arrive.
			if ok and s2 >= score:
				score = s2
			else:
				if avait:
					pleines[p] = true
				else:
					pleines.erase(p)
			if score >= cible:
				break
		var expose: int = _expose(pleines)
		if score > meilleur_score or (score == meilleur_score and expose < meilleur_expose):
			meilleur_score = score
			meilleur_expose = expose
			meilleur = pleines.duplicate()
		print("   essai %d → %d / %d, %d faces exposées" % [essai + 1, score, cible, expose])
		if meilleur_score >= cible:
			break
	if meilleur_score < cible:
		return meilleur
	# ⚠ LE PLANCHER EST PASSÉ, PAS RECALCULÉ : le recalculer dans `_elaguer` en ferait une SECONDE
	# DESCRIPTION du même nombre, qui dériverait le jour où le point de départ changerait.
	return _elaguer(meilleur, depart, cible, ciel_plancher)


## ⚠ **L'ÉLAGAGE — SANS LUI LE FINISSEUR REND DU BRUIT, ET C'EST MESURÉ.** Sa première version atteignait
## 90/90 en rééchantillonnant tout le volume libre : 249 cases sur 512, le socle perforé, le plateau en
## dentelle, 49 sommets « mixtes » contre 18 au départ. **Le témoin fonctionnait parfaitement et ne
## montrait plus rien à l'artiste** — or la demande avait deux moitiés : *montrer ce qui est grossièrement
## attendu* ET *être un cas qui fonctionne complètement*.
##
## ⚠ **LA CONTRAINTE ÉTAIT MAL POSÉE : j'avais verrouillé la SILHOUETTE et laissé libre la MASSE.** La
## lisibilité ne vit pas que dans le profil. Verrouiller le contour n'empêche pas de vider l'intérieur.
##
## On cherche donc le plus PETIT ensemble de retouches : on annule chaque changement l'un après l'autre,
## et l'on garde l'annulation dès que le score ne baisse pas. Ce qui survit est chirurgical.
func _elaguer(pleines: Dictionary, depart: Dictionary, cible: int,
		ciel_plancher: int) -> Dictionary:
	var sortie: Dictionary = pleines.duplicate()
	var avant := 0
	for p in _libres:
		if sortie.has(p) != depart.has(p):
			avant += 1

	# ⚠ **PLUSIEURS PASSES, ET TRIÉES.** Une passe unique dans l'ordre arbitraire de la grille
	# n'annulait que 64 retouches sur 83 : annuler une retouche en rend d'AUTRES annulables, et
	# parcourir les cases dans l'ordre où elles tombent gaspille les occasions. On boucle donc jusqu'à
	# ce que plus rien ne cède, en tentant d'abord les annulations qui retirent le plus de GRAIN.
	var encore := true
	var passes := 0
	while encore and passes < 8:
		encore = false
		passes += 1
		var candidates: Array = []
		var e_courant: int = _expose(sortie)
		for p in _libres:
			if sortie.has(p) == depart.has(p):
				continue
			var etait: bool = sortie.has(p)
			if depart.has(p):
				sortie[p] = true
			else:
				sortie.erase(p)
			candidates.append({"case": p, "gain": e_courant - _expose(sortie)})
			if etait:
				sortie[p] = true
			else:
				sortie.erase(p)
		candidates.sort_custom(func(a, b): return a["gain"] > b["gain"])
		for c in candidates:
			var q: Vector3i = c["case"]
			if sortie.has(q) == depart.has(q):
				continue   # déjà annulée dans cette passe
			var etait2: bool = sortie.has(q)
			if depart.has(q):
				sortie[q] = true
			else:
				sortie.erase(q)
			# ⚠ **LE PLANCHER VAUT ICI AUSSI, et son absence serait le même défaut par une autre porte.**
			# L'élagage annule des retouches ; sans contrainte, il peut parfaitement annuler celles qui
			# tenaient le ciel ouvert et reboucher ce que le grimpeur avait préservé.
			# ⚠ **LA CONTRAINTE VAUT ICI AUSSI, et son absence serait le même défaut par une autre porte.**
			# L'élagage ANNULE des retouches : sans ce test, il peut parfaitement annuler celles qui
			# avaient supprimé un contact diagonal, et réintroduire dans le témoin livré une forme que
			# le monde interdit — sans qu'aucun compteur ne le dise, puisque le score, lui, ne baisse
			# pas. Ma première édition de cette ligne a échoué silencieusement (mauvaise indentation),
			# et c'est exactement le genre de trou qu'on ne découvre qu'au rendu.
			var ok: bool = not sortie.is_empty() \
				and (not _imposer_connexite or _morceaux(sortie) == 1) \
				and int(_contextes(sortie)["n_ext"]) >= ciel_plancher \
				and (not _sans_diagonale or MB.contacts_par_arete(sortie, COTE) == 0)
			if not ok or _score(sortie) < cible:
				if etait2:
					sortie[q] = true
				else:
					sortie.erase(q)
			else:
				encore = true

	var reste := 0
	for p in _libres:
		if sortie.has(p) != depart.has(p):
			reste += 1
	print("   élagage : %d retouches → %d conservées sur %d cases libres, en %d passe(s)"
		% [avant, reste, _libres.size(), passes])
	return sortie


func _mesurer(pleines: Dictionary, quoi: String) -> void:
	var c: Dictionary = _contextes(pleines)
	var possibles := {}
	for n in MB.exterieures_a_sculpter():
		possibles[n] = true
	var dehors: int = (c["ext"] as Dictionary).size()
	var total: int = MB.pieces_a_sculpter().size()
	# ⚠ « SOMMETS MIXTES » A DISPARU DE CETTE LIGNE avec la catégorie qui le portait : le pinceau ne
	# connaît que deux états. On imprime donc ce qui EXISTE dans les deux mondes — combien de sommets
	# tombent de chaque côté — au lieu d'un troisième camp que seul cet outil voyait.
	print("   [%s] %d cases pleines, %d morceau(x), %d sommets sous roche / %d sous le ciel"
		% [quoi, pleines.size(), _morceaux(pleines), c["n_int"], c["n_ext"]])
	print("   [%s] INTÉRIEUR %d/%d   EXTÉRIEUR %d/%d   TOTAL %d/%d"
		% [quoi, (c["int"] as Dictionary).size(), total, dehors, possibles.size(),
			(c["int"] as Dictionary).size() + dehors, total + possibles.size()])
	# ⚠ **LE BUDGET EN SOMMETS — le rapport qui dit si le bruit est FORCÉ ou s'il est un défaut de la
	# recherche.** Il faut que 68 configurations DISTINCTES existent physiquement en contexte intérieur.
	# Si le volume n'offre qu'une septantaine de sommets de ce contexte, presque chacun doit porter une
	# classe différente : l'irrégularité maximale devient OBLIGATOIRE, et aucun élagage ne rendra la
	# grotte lisible. Une marge de ×3 ou ×4, au contraire, laisse de la place pour des formes reconnaissables
	# entre les accidents.
	print("   [%s] budget : %d sommets d'intérieur pour %d classes (marge ×%.2f) · %d d'extérieur pour %d (×%.2f)"
		% [quoi, c["n_int"], total, float(c["n_int"]) / float(maxi(1, total)),
			c["n_ext"], possibles.size(), float(c["n_ext"]) / float(maxi(1, possibles.size()))])
	print("   [%s] compacité : %d faces exposées · contacts par arête : %d (chacun = une arête NON-MANIFOLD)"
		% [quoi, _expose(pleines), MB.contacts_par_arete(pleines)])


## ⚠ **ON DESSINE LES MANQUANTES, ON NE LES NOMME PAS.** Un nom de classe ne dit pas quelle forme
## creuser : il faudrait le décoder de mémoire, c'est-à-dire deviner. Le motif de huit cellules se lit
## d'un coup d'œil — et c'est lui qui avait montré que « le sol de grotte n'existe pas » dans v1.
## ⚠ Je l'avais perdu en réécrivant l'outil pour le 8³ ; sans lui, je choisirais au hasard les cases à
## déverrouiller.
func _dire_les_manquantes(pleines: Dictionary) -> void:
	var c: Dictionary = _contextes(pleines)
	var possibles := {}
	for n in MB.exterieures_a_sculpter():
		possibles[n] = true
	var bits_par_nom := {}
	for cl in MB.classes():
		bits_par_nom[cl["nom"]] = int(cl["bits"])

	var manque_dedans: Array = []
	for n in MB.pieces_a_sculpter():
		if not (c["int"] as Dictionary).has(n):
			manque_dedans.append(n)
	var manque_dehors: Array = []
	for n in MB.exterieures_a_sculpter():
		if not (c["ext"] as Dictionary).has(n):
			manque_dehors.append(n)

	if not manque_dedans.is_empty():
		print("\n   ⚠ MANQUENT EN INTÉRIEUR (%d) :" % manque_dedans.size())
		_dessiner_formes(manque_dedans, bits_par_nom)
	if not manque_dehors.is_empty():
		print("\n   ⚠ MANQUENT EN EXTÉRIEUR (%d) :" % manque_dehors.size())
		_dessiner_formes(manque_dehors, bits_par_nom)
	if manque_dedans.is_empty() and manque_dehors.is_empty():
		print("\n   ✅ COUVERTURE COMPLÈTE — toutes les tuiles du monde.")


## Chaque classe en deux carrés 2×2 : la couche du BAS (bits 0,1,4,5) et celle du HAUT (2,3,6,7),
## x en colonnes et z en rangées, comme les couches du bloc.
func _dessiner_formes(noms: Array, bits_par_nom: Dictionary) -> void:
	var paquet: Array = []
	for n in noms:
		paquet.append(n)
		if paquet.size() == 3:
			_trois_formes(paquet, bits_par_nom)
			paquet = []
	if not paquet.is_empty():
		_trois_formes(paquet, bits_par_nom)


func _trois_formes(noms: Array, bits_par_nom: Dictionary) -> void:
	var entete := "     "
	for n in noms:
		entete += "%-30s" % n
	print(entete)
	for z in 2:
		var ligne := "     "
		for n in noms:
			var b: int = int(bits_par_nom.get(n, 0))
			var bas := ""
			var haut := ""
			for x in 2:
				bas += "#" if (b & (1 << (x + 4 * z))) != 0 else "."
				haut += "#" if (b & (1 << (x + 2 + 4 * z))) != 0 else "."
			ligne += "%-30s" % ("  bas %s   haut %s" % [bas, haut] if z == 0
				else "      %s        %s" % [bas, haut])
		print(ligne)
	print("")


## ⚠ **ON REND LA GRILLE DANS LA MÊME NOTATION**, pour que la sortie du finisseur soit RELISIBLE et
## réauteurable. Un finisseur dont on ne peut pas inspecter le résultat serait un générateur, pas un
## assistant — et la forme du bloc doit rester une décision humaine.
func _rendre(pleines: Dictionary) -> void:
	var libres := {}
	for p in _libres:
		libres[p] = true
	# ⚠ **EN NOTATION DU GREFFON D'ABORD — pour qu'il n'y ait AUCUNE transcription à la main.**
	# `blocs_maitres.gd` ne lit que « # » et « . » ; recopier 64 rangées en traduisant `+`→`#` et
	# `-`→`.` à la main, c'est un caractère qui glisse et un bloc changé sans que rien ne le signale.
	print("\n── LA GRILLE FINIE, PRÊTE À COLLER DANS `blocs_maitres.gd` ──")
	for y in COTE:
		print("\t\t[   # y = %d" % y)
		for z in COTE:
			var ligne := ""
			for x in COTE:
				ligne += "#" if pleines.has(Vector3i(x, y, z)) else "."
			print("\t\t\t\"%s\"," % ligne)
		print("\t\t],")

	print("\n── LA MÊME, AVEC LE MASQUE (# . + −) pour retoucher la silhouette ──")
	for y in COTE:
		print("\t[   # y = %d" % y)
		for z in COTE:
			var ligne := ""
			for x in COTE:
				var p := Vector3i(x, y, z)
				var plein: bool = pleines.has(p)
				if libres.has(p):
					ligne += "+" if plein else "-"
				else:
					ligne += "#" if plein else "."
			print("\t\t\"%s\"," % ligne)
		print("\t],")
