extends SceneTree

## SONDE — RESTE-T-IL DES CONTREMARCHES DANS LA FACE DIRECTE ?
##
## ⚠ **JORDAN, 26 septembre 2026 : « je vois toujours des contremarches. »** Sur la planche du témoin en
## faces directes. Deux explications possibles, aux remèdes OPPOSÉS — et on ne choisit pas à l'œil :
##
##   1. sa silhouette porte de VRAIES terrasses (plat large, chute d'une cellule, plat large), et le
##      générateur les rend fidèlement : ce qu'il voit est dans l'occupation, pas dans le maillage ;
##   2. le générateur INTERCALE des plats là où une pente continue est attendue : c'est un défaut.
##
## ⚠ **LA PRÉDICTION EST ÉCRITE AVANT LA MESURE, pour qu'elle puisse me démentir** (charte §6) :
##
##   • sur une RAMPE descendant d'exactement une cellule par cellule, tout sommet du réseau voit la
##     même configuration « marche », donc la surface doit être **un seul plan à 45°, sans AUCUNE face
##     horizontale** ;
##   • sur une TERRASSE (plat large + une chute), les faces horizontales sont attendues et LÉGITIMES —
##     c'est le contrôle négatif, sans lequel « il reste des plats » ne voudrait rien dire.
##
## ⚠ **ON EXCLUT LE BORD DU BLOC.** Le mailleur d'affichage émet aussi les faces de SCIAGE, qui sont des
## parois verticales parfaitement normales ; les compter ferait passer un bloc parfait pour un escalier.
##
## ── LA PREMIÈRE PRÉDICTION SUR LE TÉMOIN ÉTAIT INVÉRIFIABLE, ET C'EST UN DÉFAUT D'INSTRUMENT ────────
##
## ⚠ **ELLE ANNONÇAIT « ~140 cellules de paroi » ET LA SONDE RENDAIT « 71 triangles ».** Deux nombres
## qui ne se comparent pas : le premier venait de `sonde_escaliers`, qui relève les contremarches du
## bloc ENTIER sur son champ de hauteurs ; le second compte des triangles, HORS BORD. Ni la même unité,
## ni la même région, ni la même surface — et j'ai failli lire un écart de SUJET comme un écart de FAIT.
## La charte §6 le dit déjà deux fois (« deux instruments différents, une conclusion fausse » ; « avant
## d'énoncer un fait, vérifier que l'instrument mesure bien ce qu'on croit »).
##
## ⚠ **LE REMÈDE N'EST PAS DE CONVERTIR LES UNITÉS APRÈS COUP, c'est de poser la question autrement.**
## Un total prédit puis comparé à un total mesuré ne dit JAMAIS où l'écart est né. On interroge donc
## chaque face verticale SÉPARÉMENT : de quelle CHUTE fait-elle partie dans l'occupation ?
##
##   loi attendue, et les terrasses construites la vérifient : **une chute de N cellules laisse N−1
##   cellules de paroi verticale** (1 → 0, 2 → 1, 3 → 2).
##
## Si le générateur est fidèle, **AUCUNE aire verticale ne doit se trouver sur une chute de 1**. C'est
## une prédiction qui porte sur CHAQUE face, pas sur une somme : une seule face verticale posée sur une
## chute de 1 suffit à la démentir, et aucun effet de bord ne peut la sauver.

const MB := preload("res://addons/undermend/marching_blocks.gd")
const RP := preload("res://addons/undermend/repli_procedural.gd")
## ⚠ Pour confronter la loi au TÉMOIN RÉEL — avec le même `_examiner()` que les cas construits, jamais
## une seconde mesure faite autrement : c'est la comparaison qui doit être valide, pas chaque moitié.
const BM := preload("res://addons/undermend/blocs_maitres.gd")
const Topologie := preload("res://DEV_TOOLS/topologie.gd")

const COTE := 8
## La marge de bord, en cases. ⚠ **UN SEUL ENDROIT**, parce que c'est la région que les deux
## instruments doivent partager.
const MARGE := 1.1


func _initialize() -> void:
	print("=== RESTE-T-IL DES CONTREMARCHES ? ===\n")
	print("PRÉDICTION (écrite avant la mesure) :")
	print("   rampe 1:1  → 100 % d'obliques, 0 face horizontale sur la pente")
	print("   terrasse   → des horizontales, et c'est NORMAL : elles sont dans l'occupation")
	print("   PARTOUT    → 0 aire verticale sur une chute d'UNE cellule\n")

	_examiner("RAMPE 1:1 (une cellule de chute par cellule)", _rampe())
	_examiner("TERRASSE à UNE cellule de chute", _terrasse(1))
	_examiner("TERRASSE à DEUX cellules de chute", _terrasse(2))
	_examiner("TERRASSE à TROIS cellules de chute", _terrasse(3))
	# ⚠ **LE SUJET DE LA PLAINTE.** Aucun total n'est prédit ici, et c'est délibéré : le témoin porte
	# une grotte, un tunnel et une arche, dont un champ de hauteurs ne sait rien dire. C'est la loi
	# « chute de N → N−1 de paroi » qui est mise à l'épreuve, face par face.
	_examiner("LE TÉMOIN LUI-MÊME (bloc 0)", BM.cases(0))

	# ── LE CONTRÔLE QUI DOIT ROUGIR ─────────────────────────────────────────────────────────────────
	#
	# ⚠ **SANS LUI, « 0 sur une chute de 1 » NE VAUT RIEN** (charte §6 — « un test qu'on n'a pas vu
	# rougir ne garde rien »). Un zéro a deux lectures : le mailleur est fidèle, **ou l'instrument ne
	# sait pas voir**. On départage en donnant la MÊME lecture à un mailleur dont on sait qu'il pose
	# une contremarche sur une chute d'une cellule — la coque en sous-voxels, celle qui part
	# aujourd'hui chez l'artiste. Si elle rend zéro elle aussi, c'est l'instrument qui est aveugle et
	# tout ce qui précède tombe.
	print("══ CONTRÔLE NÉGATIF — la MÊME lecture sur l'ANCIENNE coque en sous-voxels ══")
	print("   attendu : de l'aire verticale SUR UNE CHUTE DE 1, donc « ⚠ DÉFAUT DU MAILLEUR ».")
	print("   Un zéro ici voudrait dire que la sonde est aveugle, pas que la coque est lisse.\n")
	_examiner("COQUE AMINCIE — TERRASSE à UNE cellule de chute", _terrasse(1),
		BM._coque_sous_voxels(_terrasse(1), 0.25))

	print("⚠ Cette sonde dit d'où viennent les plats, jamais s'ils sont jolis.")
	quit(0)


## Une rampe qui descend d'UNE cellule par cellule en x. Tout sommet y voit la même marche.
func _rampe() -> Dictionary:
	var pleines := {}
	for x in COTE:
		for z in COTE:
			for y in range(0, COTE - x):
				pleines[Vector3i(x, y, z)] = true
	return pleines


## Deux plateaux larges séparés par une chute de `chute` cellules — la forme que porte le témoin.
##
## ⚠ **LE PARAMÈTRE EST LA CORRECTION D'UN CONTRÔLE MAL POSÉ.** La première version chutait de DEUX
## cellules (5 → 3) tout en s'appelant « une chute » : elle ne pouvait donc pas distinguer « toute
## terrasse garde une contremarche » de « seules les chutes de 2+ en gardent ». Un contrôle qui ne
## sépare pas les deux hypothèses qu'il est censé départager ne vaut rien (charte §6).
func _terrasse(chute: int) -> Dictionary:
	var pleines := {}
	for x in COTE:
		for z in COTE:
			var haut: int = 6 if x < 4 else 6 - chute
			for y in haut:
				pleines[Vector3i(x, y, z)] = true
	return pleines


## ⚠ **LA RÉGION, POUR TOUT CE QUI SE COMPTE ICI.** Un seul prédicat, appelé par le filtre des
## triangles comme par le relevé des chutes : deux écritures auraient divergé (charte §6 — « une
## seconde description d'un même fait diverge toujours »).
func _dans_la_region(centre: Vector3) -> bool:
	return centre.x > MARGE and centre.z > MARGE \
		and centre.x < float(COTE) - MARGE and centre.z < float(COTE) - MARGE


## ⚠ **`autre_mesh` EXISTE POUR LE CONTRÔLE NÉGATIF, ET C'EST TOUT.** Par défaut la sonde maille en
## faces directes ; le contrôle lui passe la coque en sous-voxels de la MÊME occupation. Les deux
## maillages vivent dans le même repère (la case `p` occupe `[p, p+1]`), donc le filtre de région et la
## lecture des chutes s'y appliquent mot pour mot — c'est ce qui rend la comparaison valide.
func _examiner(quoi: String, pleines: Dictionary, autre_mesh: ArrayMesh = null) -> void:
	var mesh: ArrayMesh = autre_mesh if autre_mesh != null \
		else RP.maillage_direct_du_bloc(pleines, COTE)
	print("── %s ──" % quoi)
	print("   %d cases" % pleines.size())
	if mesh.get_surface_count() == 0:
		print("   ⚠ aucune surface\n")
		return
	var tout: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = tout[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = tout[Mesh.ARRAY_NORMAL]
	var plafond: int = MB.plafond_de(pleines)

	var dessus := 0
	var dessous := 0
	var paroi := 0
	var paroi_dedans := 0
	var paroi_ciel := 0
	var oblique := 0
	var autres := 0
	# ⚠ **L'AIRE, PAS LE NOMBRE DE TRIANGLES.** Une face directe se triangule en éventail : compter les
	# triangles pèse une grande face comme une petite, et c'est précisément ce qui rendait la première
	# prédiction incomparable. L'aire est en CASES², la même unité que « N−1 cellules de paroi ».
	var aire_par_chute := {}
	var aire_ciel_par_chute := {}
	var aire_verticale := 0.0
	var sans_chute := 0
	# ⚠ **LES PAROIS EN BIAIS SE COMPTENT À PART**, parce qu'elles ont fait mentir l'instrument une
	# fois : une falaise oblique en plan est verticale sans être perpendiculaire à un axe.
	var paroi_en_biais := 0
	for i in range(0, v.size(), 3):
		var centre: Vector3 = (v[i] + v[i + 1] + v[i + 2]) / 3.0
		# ⚠ On exclut la peau du bloc : ses faces de sciage sont des parois verticales normales.
		if not _dans_la_region(centre):
			continue
		var u: Vector3 = n[i]
		if u.y > 0.9:
			dessus += 1
		elif u.y < -0.9:
			dessous += 1
		elif absf(u.y) < 0.1:
			paroi += 1
			# ⚠ **TOUTES LES FACES VERTICALES NE SONT PAS DES CONTREMARCHES.** Le témoin porte un
			# tunnel, une grotte et un puits, dont les parois sont verticales PAR NATURE — du relief
			# voulu, qu'il ne faut surtout pas chanfreiner. Compter les verticales en bloc mélangeait
			# donc le défaut et l'intention. On regarde la case située JUSTE DEHORS de la face : si
			# elle est coiffée de roche, c'est une paroi de vide intérieur ; sinon, c'est une falaise
			# ou une contremarche à l'air libre. Le critère est `case_sous_roche()`, celui du modèle —
			# pas un second inventé ici.
			var dehors: Vector3 = centre + u * 0.3
			var case := Vector3i(floori(dehors.x), floori(dehors.y), floori(dehors.z))
			var sous_roche: bool = MB.case_sous_roche(pleines, case, plafond)
			if sous_roche:
				paroi_dedans += 1
			else:
				paroi_ciel += 1
			if absf(u.x) > 0.1 and absf(u.z) > 0.1:
				paroi_en_biais += 1
			var aire: float = 0.5 * (v[i + 1] - v[i]).cross(v[i + 2] - v[i]).length()
			aire_verticale += aire
			# ⚠ On passe `COTE` bien que la marge de bord exclue déjà la peau : c'est la MÊME règle que
			# la planche `--chutes`, et une règle partagée qui se lit pareil des deux côtés ne peut
			# pas diverger. Contrôle : les chiffres doivent être INCHANGÉS.
			var hauteur: int = Topologie.chute_de(pleines, centre, u, COTE)
			if hauteur == 0:
				sans_chute += 1
			else:
				aire_par_chute[hauteur] = float(aire_par_chute.get(hauteur, 0.0)) + aire
				if not sous_roche:
					aire_ciel_par_chute[hauteur] = \
						float(aire_ciel_par_chute.get(hauteur, 0.0)) + aire
		elif absf(u.y) > 0.35 and absf(u.y) < 0.85:
			oblique += 1
		else:
			autres += 1
	var total: int = dessus + dessous + paroi + oblique + autres
	print("   hors bord : %d triangle(s)" % total)
	print("      dessus PLAT   : %3d   ← une contremarche en produit un de chaque côté" % dessus)
	print("      dessous plat  : %3d" % dessous)
	print("      paroi verticale: %3d   dont %d À L'AIR LIBRE (falaise ou contremarche)"
		% [paroi, paroi_ciel])
	print("                             et %d SOUS ROCHE (grotte, tunnel, puits — voulues)"
		% paroi_dedans)
	print("                             et %d EN BIAIS (verticales, mais pas face à un axe)"
		% paroi_en_biais)
	print("      OBLIQUE (45°) : %3d   ← la face directe" % oblique)
	print("      autres        : %3d" % autres)
	print("      → %.0f %% d'obliques" % (100.0 * float(oblique) / float(maxi(1, total))))

	# ── LA LOI, FACE PAR FACE ───────────────────────────────────────────────────────────────────────
	print("      aire verticale : %.2f case(s)² — et voici DE QUELLE CHUTE elle vient :"
		% aire_verticale)
	var chutes: Array = aire_par_chute.keys()
	chutes.sort()
	for h in chutes:
		var alerte: String = "   ⚠ DÉMENT LA LOI" if int(h) < 2 else ""
		print("         chute de %d cellule(s) : %6.2f case(s)²  (dont %.2f à l'air libre)%s"
			% [h, aire_par_chute[h], aire_ciel_par_chute.get(h, 0.0), alerte])
	if sans_chute > 0:
		# ⚠ Un triangle vertical dont on ne retrouve pas la chute n'est pas « rien » : c'est
		# l'instrument qui n'a pas su lire, et le taire ferait passer un trou pour un zéro.
		# ⚠ **IL EN RESTE SUR LE CONTRÔLE NÉGATIF, ET IL FAUT DIRE POURQUOI ÇA NE L'INVALIDE PAS** :
		# les faces d'un palier large d'UN sous-voxel ont leurs deux échantillons dans la MÊME case,
		# et l'on préfère rendre 0 que deviner. Un illisible de plus ne pourrait que rendre le
		# contrôle PLUS rouge, jamais moins. Sur le témoin — le sujet — il n'y en a aucun.
		print("         ⚠ %d triangle(s) vertical(aux) dont la chute n'a pas pu être lue" % sans_chute)
	var faute: float = float(aire_par_chute.get(1, 0.0))
	print("      → aire verticale sur une chute de 1 : %.2f case(s)²   %s\n"
		% [faute, "⚠ DÉFAUT DU MAILLEUR" if faute > 0.001 else "✓ la loi tient"])


## ⚠ **LA LECTURE DES CHUTES A DÉMÉNAGÉ DANS `topologie.gd`** : la planche `--chutes` la PEINT tandis
## que cette sonde la COMPTE, et deux écritures de la même règle auraient fini par peindre autre chose
## que ce qui est compté. Le module existe pour ça.
