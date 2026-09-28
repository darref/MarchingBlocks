extends SceneTree
##
## SONDE — DE QUELLE TAILLE SONT LES « PETITS ESCALIERS » ?
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_escaliers.gd
##
## ── POURQUOI ELLE EXISTE ────────────────────────────────────────────────────────────────────────────
##
## Jordan, 25 septembre 2026, capture à l'appui : *« il faudrait que les deux arêtes soient reliées par
## des faces directes plutôt que par deux faces formant un escalier, mais comme les formes sont
## complexes il faut une méthode pour le faire. »*
##
## ⚠ **LA MÉTHODE DÉPEND DE LA TAILLE DES MARCHES, ET JE ME SUIS DÉJÀ TROMPÉ D'UN FACTEUR TROIS
## DESSUS** — un schéma dessiné de tête au lieu d'être dérivé de la géométrie. Deux tailles, deux
## remèdes incompatibles :
##
##   • contremarche de 1 sous-voxel  → c'est la LÈVRE créée par l'amincissement, un chanfrein local
##     de 0,25 case la supprime, et la mesure dit qu'il ne touche pas au contrat de couture ;
##   • contremarche de 4 sous-voxels → c'est une marche d'une CELLULE entière ; aucune opération locale
##     ne peut la remplacer par une face directe sans franchir le plan de coupe, donc sans changer le
##     germe de bordure. Il faudrait faire dériver la pente de la CLASSE, pas de la coque.
##
## ── L'INSTRUMENT, ET CE QU'IL NE VOIT PAS ───────────────────────────────────────────────────────────
##
## Elle réduit le bloc à son CHAMP DE HAUTEURS : pour chaque colonne (x, z), le sous-voxel plein le plus
## haut. L'escalier est alors le profil de ce champ, et ses marches se comptent exactement.
##
## ⚠ **ELLE NE VOIT QUE LA SURFACE DU DESSUS.** Les surplombs, les plafonds de grotte et les parois
## verticales lui échappent par construction — un champ de hauteurs ne peut pas les représenter. C'est
## assumé : les croix de Jordan sont sur des surfaces vues de dessus. Dire le contraire ferait passer
## une mesure partielle pour une mesure complète (charte §6).
## ⚠ Elle lit `BlocsMaitres.sous_voxels()`, la même fonction que le mailleur — jamais une recopie de la
## règle du retrait.

const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")


func _initialize() -> void:
	var cote_sous: int = BM.COTE * BM.SOUS
	print("=== DE QUELLE TAILLE SONT LES MARCHES ? ===\n")
	print("PRÉDICTION, écrite AVANT la mesure pour qu'elle puisse être démentie :")
	print("   l'amincissement rentre d'UN sous-voxel et les cellules font QUATRE sous-voxels ;")
	print("   les contremarches devraient donc tomber sur des multiples de 4, à ±1 près.")
	print("   Si beaucoup valent 1, ce sont des lèvres d'amincissement et un chanfrein suffit.\n")
	print("1 cellule = %d sous-voxels  ·  retrait de l'amincissement = 1 sous-voxel\n" % BM.SOUS)

	var cases: Dictionary = BM.cases(0)
	_examiner("le SOLIDE (retrait 0)", BM.sous_voxels(cases, 0.0), cote_sous)
	_examiner("l'AMINCI — CE QUI PART CHEZ L'ARTISTE", BM.sous_voxels(cases, 0.25), cote_sous)

	print("\n⚠ Cette sonde ne voit que la surface du DESSUS : ni surplombs, ni parois, ni plafonds.")
	quit(0)


func _examiner(quoi: String, pleins: Dictionary, cote_sous: int) -> void:
	print("── %s ──" % quoi)

	# ── LE CHAMP DE HAUTEURS ────────────────────────────────────────────────────────────────────────
	var hauteur := {}
	for x in cote_sous:
		for z in cote_sous:
			var h := -1
			for y in range(cote_sous - 1, -1, -1):
				if pleins.has(Vector3i(x, y, z)):
					h = y
					break
			if h >= 0:
				hauteur[Vector2i(x, z)] = h

	# ── LES CONTREMARCHES : l'écart de hauteur entre deux colonnes VOISINES ──────────────────────────
	#
	# ⚠ Deux colonnes dont l'une est vide ne forment pas une marche mais un BORD de bloc : les compter
	# gonflerait le tableau de faux escaliers, tous au même endroit, et ferait conclure à un défaut là
	# où il n'y a qu'une limite de volume.
	var marches := {}
	var total := 0
	for cle in hauteur:
		var p: Vector2i = cle
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var q: Vector2i = p + d
			if not hauteur.has(q):
				continue
			var ecart: int = absi(int(hauteur[q]) - int(hauteur[p]))
			if ecart == 0:
				continue
			marches[ecart] = int(marches.get(ecart, 0)) + 1
			total += 1

	var cles: Array = marches.keys()
	cles.sort()
	print("   %d contremarche(s) entre colonnes voisines :" % total)
	var en_levre := 0
	var en_cellule := 0
	for h in cles:
		var combien: int = marches[h]
		var quoi_cest := ""
		if h == 1:
			quoi_cest = "  ← LÈVRE d'amincissement (un chanfrein local la supprime)"
			en_levre += combien
		elif h % BM.SOUS == 0:
			quoi_cest = "  ← marche de %d CELLULE(S) entière(s)" % (h / BM.SOUS)
			en_cellule += combien
		print("      %3d sous-voxel(s)  ×%-5d  (%.2f case)%s"
			% [h, combien, float(h) / float(BM.SOUS), quoi_cest])

	print("   RÉPARTITION : %d lèvre(s) d'un sous-voxel (%.1f %%)  ·  %d marche(s) pleine(s) de cellule (%.1f %%)"
		% [en_levre, 100.0 * float(en_levre) / maxf(1.0, float(total)),
			en_cellule, 100.0 * float(en_cellule) / maxf(1.0, float(total))])

	# ── LES TERRASSES : la largeur des paliers, en sous-voxels ──────────────────────────────────────
	#
	# ⚠ C'est l'autre moitié de la question : une marche haute mais LARGE se lit comme un étage, une
	# marche basse et ÉTROITE se lit comme un escalier. La contremarche seule ne le dit pas.
	var terrasses := {}
	var combien_t := 0
	for z in cote_sous:
		var debut := -1
		var h_courante := -999
		for x in range(cote_sous + 1):
			var ici: int = int(hauteur.get(Vector2i(x, z), -999)) if x < cote_sous else -999
			if ici != h_courante:
				if debut >= 0 and h_courante != -999:
					var largeur: int = x - debut
					terrasses[largeur] = int(terrasses.get(largeur, 0)) + 1
					combien_t += 1
				debut = x
				h_courante = ici
	var ct: Array = terrasses.keys()
	ct.sort()
	var etroites := 0
	for l in ct:
		if int(l) <= 2:
			etroites += int(terrasses[l])
	print("   %d palier(s) balayés sur x, dont %d de 2 sous-voxels ou moins (%.1f %%)"
		% [combien_t, etroites, 100.0 * float(etroites) / maxf(1.0, float(combien_t))])
	var apercu: Array = []
	for l in ct.slice(0, 10):
		apercu.append("%d:×%d" % [l, terrasses[l]])
	print("   largeurs de palier : %s" % ", ".join(PackedStringArray(apercu)))
	print("")
