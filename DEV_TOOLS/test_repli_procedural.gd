extends SceneTree
##
## TEST — le repli procédural : les 68 surfaces fabriquées par le calcul.
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_repli_procedural.gd
##
## ⚠ L'INVARIANT CENTRAL, ET IL EST EXACT À LA VIRGULE :
##
##   Σ DES AIRES DES PIÈCES POSÉES = NOMBRE DE FACES DE CELLULES EXPOSÉES.
##
## Il attrape les deux pannes opposées d'un seul coup — une face oubliée fait TOMBER l'aire, une face de
## coupe rebouchée la fait MONTER. Un test qui compterait seulement « ça rend des triangles » laisserait
## passer les deux.
##
## ⚠ ET IL EST VÉRIFIÉ SUR DES FORMES CONSTRUITES, PAS ESPÉRÉES. La charte a appris trois fois en 2D
## qu'un disque ne prouve rien : sa frontière est convexe. On prend donc la cellule seule, la paire, le
## cube plein, le L, la plaque TROUÉE, le contact en DIAGONALE et la diagonale de corps — exactement les
## formes qui ont fait tomber le lot 2D.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const RP := preload("res://addons/marchingblocks_core/repli_procedural.gd")
const Decoupe := preload("res://addons/marchingblocks_core/decoupe.gd")

## Une face d'octant : 0,5 × 0,5.
const AIRE_DE_FACE := 0.25
const A_SCULPTER := 68

var _ok := 0
var _echecs := 0
var _premier := ""


func _initialize() -> void:
	print("=== TEST — le repli procédural ===\n")
	_chaque_piece_expose_ce_qu_il_faut()
	_le_vide_et_le_plein_ne_rendent_rien()
	_aucune_piece_ne_deborde_de_son_cube()
	_aucune_face_sur_un_plan_de_coupe()
	_les_normales_sont_saines()
	_l_invariant_d_aire_sur_des_formes_construites()
	_la_collision_suit_les_octants()
	_la_librairie_est_complete()
	_les_couleurs_disent_la_bande()
	_ou_la_matiere_se_trouve()

	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	if _echecs > 0:
		print("PREMIER ÉCHEC — %s" % _premier)
	print("VERDICT : %s" % ("ÉCHEC" if _echecs > 0 else "OK"))
	quit(1 if _echecs > 0 else 0)


func _dire(condition: bool, quoi: String) -> void:
	if condition:
		_ok += 1
	else:
		_echecs += 1
		if _premier == "":
			_premier = quoi
		if _echecs <= 12:
			print("  ÉCHEC — %s" % quoi)


# ── 1. chaque pièce expose exactement les faces attendues ───────────────────────────────────────────

## ⚠ DEUX CHEMINS INDÉPENDANTS VERS LE MÊME NOMBRE. Le compte de faces est recalculé ICI, à la main,
## sans passer par `faces_attendues()` du module — puis comparé à l'aire du maillage RÉELLEMENT produit.
## Un module qui se jugerait lui-même ne prouverait rien.
func _chaque_piece_expose_ce_qu_il_faut() -> void:
	print("1. chaque pièce expose exactement les faces qu'il faut")
	for b in 256:
		var attendu := 0
		for t in 8:
			if not (b & (1 << t)):
				continue
			for axe in 3:
				if not (b & (1 << (t ^ (1 << axe)))):
					attendu += 1
		_dire(RP.faces_attendues(b) == attendu,
			"configuration %d : le module annonce %d faces, on en compte %d"
				% [b, RP.faces_attendues(b), attendu])
		var aire: float = Decoupe.aire(RP.maillage(b))
		_dire(absf(aire - attendu * AIRE_DE_FACE) < 0.0001,
			"configuration %d : aire %.4f, attendue %.4f (%d faces)"
				% [b, aire, attendu * AIRE_DE_FACE, attendu])

	# ⚠ LE CAS QUI ANCRE TOUT LE RESTE : une cellule seule expose ses trois faces intérieures.
	var coin: int = 1
	_dire(absf(Decoupe.aire(RP.maillage(coin)) - 0.75) < 0.0001,
		"une cellule seule devrait exposer 0,75 d'aire, pas %.4f" % Decoupe.aire(RP.maillage(coin)))
	print("   → 256 configurations, aire = 0,25 × faces exposées, la cellule seule vaut 0,75")


# ── 2. le vide et le ventre plein ───────────────────────────────────────────────────────────────────

func _le_vide_et_le_plein_ne_rendent_rien() -> void:
	print("\n2. le vide et le ventre plein ne rendent rien")
	# ⚠ C'est la règle du VENTRE CREUX : un sommet entouré de huit cellules pleines est à l'intérieur de
	# la matière. Ne rien y poser est ce qui fait qu'un massif coûte sa SURFACE et non son volume.
	_dire(RP.maillage(0).get_surface_count() == 0, "le vide devrait rendre un maillage vide")
	_dire(RP.maillage(255).get_surface_count() == 0, "le ventre plein devrait rendre un maillage vide")
	_dire(RP.faces_attendues(255) == 0, "le ventre plein ne devrait exposer aucune face")
	var avec_surface := 0
	for c in MB.classes():
		if MB.porte_une_surface(c["bits"]):
			avec_surface += 1
			_dire(RP.maillage(c["bits"]).get_surface_count() > 0,
				"« %s » porte une surface mais rend un maillage vide" % c["nom"])
	_dire(avec_surface == A_SCULPTER,
		"%d classes à surface, il en faut %d" % [avec_surface, A_SCULPTER])
	print("   → %d pièces non vides, et exactement deux classes muettes" % avec_surface)


# ── 3. rien ne déborde ──────────────────────────────────────────────────────────────────────────────

func _aucune_piece_ne_deborde_de_son_cube() -> void:
	print("\n3. aucune pièce ne déborde de son cube")
	var cube := AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	for c in MB.classes():
		if not MB.porte_une_surface(c["bits"]):
			continue
		_dire(Decoupe.tient_dans(RP.maillage(c["bits"]), cube, 0.0001),
			"« %s » sort de son cube" % c["nom"])
	print("   → les %d pièces tiennent dans [-0,5 ; 0,5]³" % A_SCULPTER)


# ── 4. AUCUNE FACE SUR UN PLAN DE COUPE ─────────────────────────────────────────────────────────────

## ⚠ LA VÉRIFICATION QUI GARDE « ON NE REFERME JAMAIS LA COUPE ». Un plan de coupe sépare toujours deux
## octants de la MÊME cellule : y poser une face dresserait un mur en pleine roche, invisible de
## l'extérieur et catastrophique en coupe. L'invariant d'aire l'attraperait aussi, mais celui-ci DIT
## lequel des deux défauts s'est produit.
func _aucune_face_sur_un_plan_de_coupe() -> void:
	print("\n4. aucune face ne repose sur un plan de coupe")
	for c in MB.classes():
		if not MB.porte_une_surface(c["bits"]):
			continue
		var mesh: ArrayMesh = RP.maillage(c["bits"])
		var arrays: Array = mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var fautives := 0
		for i in range(0, v.size(), 3):
			for axe in 3:
				if absf(absf(v[i][axe]) - 0.5) < 0.0001 \
						and absf(absf(v[i + 1][axe]) - 0.5) < 0.0001 \
						and absf(absf(v[i + 2][axe]) - 0.5) < 0.0001:
					fautives += 1
		_dire(fautives == 0, "« %s » pose %d triangle(s) sur un plan de coupe" % [c["nom"], fautives])
	print("   → aucune pièce ne rebouche sa coupe")


# ── 5. les normales ─────────────────────────────────────────────────────────────────────────────────

## ⚠ LE SIGNE D'UNE NORMALE NE SE TIENT PAS À LA MAIN. Ce projet a déjà payé deux fois pour un signe
## tenu de tête — celui d'une rotation, puis celui d'un enroulement — et les deux fois seule une planche
## l'a montré.
##
## ⚠ **GODOT ENROULE SES FACES AVANT DANS LE SENS HORAIRE** : le produit vectoriel de l'ordre stocké
## pointe donc À L'OPPOSÉ de la normale déclarée. Ce test l'exigeait dans le MÊME sens — il passait donc
## au vert sur un lot dont toutes les faces étaient des faces arrière, invisibles à l'écran. Un test
## peut être parfaitement cohérent et garder la mauvaise convention : c'est ce qui rend la planche
## irremplaçable.
func _les_normales_sont_saines() -> void:
	print("\n5. les normales suivent l'enroulement (face avant HORAIRE, convention Godot)")
	for c in MB.classes():
		if not MB.porte_une_surface(c["bits"]):
			continue
		var arrays: Array = RP.maillage(c["bits"]).surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var retournes := 0
		for i in range(0, v.size(), 3):
			var croix: Vector3 = (v[i + 1] - v[i]).cross(v[i + 2] - v[i])
			if croix.length() < 0.000001 or croix.normalized().dot(n[i]) > -0.99:
				retournes += 1
			# Une normale d'octant est toujours un axe, et de longueur 1.
			_dire(absf(n[i].length() - 1.0) < 0.0001, "« %s » : normale non unitaire" % c["nom"])
		_dire(retournes == 0, "« %s » : %d triangle(s) dont la normale contredit l'enroulement"
			% [c["nom"], retournes])
	print("   → toutes les normales sont unitaires et d'accord avec leur triangle")


# ── 6. L'INVARIANT D'AIRE, SUR DES FORMES CONSTRUITES ───────────────────────────────────────────────

func _l_invariant_d_aire_sur_des_formes_construites() -> void:
	print("\n6. Σ des aires posées = faces de cellules exposées")
	for essai in [
		{"nom": "une cellule seule", "cellules": [Vector3i(0, 0, 0)]},
		{"nom": "deux cellules côte à côte", "cellules": [Vector3i(0, 0, 0), Vector3i(1, 0, 0)]},
		{"nom": "deux cellules en diagonale de face",
			"cellules": [Vector3i(0, 0, 0), Vector3i(1, 1, 0)]},
		{"nom": "deux cellules en diagonale de CORPS",
			"cellules": [Vector3i(0, 0, 0), Vector3i(1, 1, 1)]},
		{"nom": "un cube 2×2×2", "cellules": _pave(0, 1, 0, 1, 0, 1)},
		{"nom": "un cube 3×3×3 (avec un ventre)", "cellules": _pave(0, 2, 0, 2, 0, 2)},
		{"nom": "une dalle 4×1×4", "cellules": _pave(0, 3, 0, 0, 0, 3)},
		{"nom": "un L", "cellules": _pave(0, 2, 0, 0, 0, 0) + _pave(0, 0, 0, 0, 1, 2)},
		{"nom": "une dalle TROUÉE", "cellules": _trouee()},
		{"nom": "une colonne 1×4×1", "cellules": _pave(0, 0, 0, 3, 0, 0)},
	]:
		var pleines := {}
		for c in essai["cellules"]:
			pleines[c] = true

		# Le compte de référence : une face de cellule est exposée si exactement un de ses deux côtés
		# est plein. ⚠ Calculé ici, sans rien demander au module.
		var exposees := 0
		for c in pleines:
			for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
					Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				if not pleines.has((c as Vector3i) + d):
					exposees += 1

		# Ce que le greffon pose réellement : une pièce par sommet touché.
		var sommets := {}
		for c in pleines:
			for s in MB.sommets_de(c):
				sommets[s] = true
		var aire := 0.0
		var poses := 0
		for s in sommets:
			var bits: int = MB.bits(pleines, s)
			# ⚠ L'aire ne dépend pas de l'orientation : une rotation ne change pas une aire. On somme
			# donc les aires des pièces de RÉFÉRENCE, ce qui vérifie en prime que la classe rendue est
			# bien celle qui a la bonne surface.
			var r: Dictionary = MB.classer(bits)
			var reference: int = MB.classes()[r["classe"]]["bits"]
			aire += Decoupe.aire(RP.maillage(reference))
			if r["surface"]:
				poses += 1
		_dire(absf(aire - exposees) < 0.0001,
			"%s : aire posée %.4f, faces exposées %d" % [essai["nom"], aire, exposees])
		print("   %-32s %3d cellules, %3d pièces, aire %7.3f = %d faces"
			% [essai["nom"], pleines.size(), poses, aire, exposees])


func _pave(x0: int, x1: int, y0: int, y1: int, z0: int, z1: int) -> Array:
	var sortie: Array = []
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			for z in range(z0, z1 + 1):
				sortie.append(Vector3i(x, y, z))
	return sortie


## Une dalle 3×1×3 dont on retire le centre : elle fabrique quatre angles RENTRANTS, la forme qui a fait
## tomber le lot 2D.
func _trouee() -> Array:
	var sortie: Array = []
	for c in _pave(0, 2, 0, 0, 0, 2):
		if c != Vector3i(1, 0, 1):
			sortie.append(c)
	return sortie


# ── 7. la collision ─────────────────────────────────────────────────────────────────────────────────

func _la_collision_suit_les_octants() -> void:
	print("\n7. une boîte de collision par octant plein")
	for c in MB.classes():
		var formes: Array = RP.collision(c["bits"])
		# `set_item_shapes` attend une liste plate [forme, transform, forme, transform, …].
		_dire(formes.size() == c["pleines"] * 2,
			"« %s » : %d entrées de collision pour %d octants pleins"
				% [c["nom"], formes.size(), c["pleines"]])
		for i in range(0, formes.size(), 2):
			var boite: BoxShape3D = formes[i]
			_dire(boite.size.is_equal_approx(Vector3.ONE * RP.OCTANT),
				"« %s » : boîte de taille %s au lieu d'un octant" % [c["nom"], str(boite.size)])
			var t: Transform3D = formes[i + 1]
			for axe in 3:
				_dire(absf(absf(t.origin[axe]) - RP.OCTANT * 0.5) < 0.0001,
					"« %s » : boîte mal centrée (%s)" % [c["nom"], str(t.origin)])
	# ⚠ LE CAS QUI COMPTE : la diagonale de corps laisse le passage OUVERT. Deux octants opposés, et
	# rien entre eux — c'est la décision « jamais de pont », vue par les pieds du joueur.
	var pointe: int = 0b00011000
	_dire(RP.collision(pointe).size() == 4, "la pointe devrait avoir deux boîtes, donc quatre entrées")
	print("   → collision dérivée des octants, jamais d'une boîte englobante")


# ── 8. la librairie ─────────────────────────────────────────────────────────────────────────────────

func _la_librairie_est_complete() -> void:
	print("\n8. la MeshLibrary du repli")
	var lot: MeshLibrary = RP.librairie()
	var ids: Array = lot.get_item_list()
	_dire(ids.size() == A_SCULPTER, "%d items dans la librairie, il en faut %d" % [ids.size(), A_SCULPTER])
	# ⚠ TOUTE CLASSE QUE LES RÈGLES SAVENT POSER DOIT EXISTER DANS LE LOT, et réciproquement — c'est le
	# contrat croisé. Sans lui, on fabrique une pièce que rien ne pose, ou l'on pose une pièce que
	# personne ne fabrique, et la case reste vide EN SILENCE.
	var dans_le_lot := {}
	for id in ids:
		dans_le_lot[lot.get_item_name(id)] = true
		_dire(lot.get_item_mesh(id) != null, "l'item %d n'a pas de maillage" % id)
		_dire(lot.get_item_shapes(id).size() > 0, "l'item %d n'a pas de collision" % id)
	for c in MB.classes():
		if MB.porte_une_surface(c["bits"]):
			_dire(dans_le_lot.has(c["nom"]), "« %s » manque à la librairie" % c["nom"])
		else:
			_dire(not dans_le_lot.has(c["nom"]), "« %s » ne devrait pas être dans la librairie" % c["nom"])
	# La recherche se fait par le NOM, jamais par la position (charte §6).
	_dire(lot.find_item_by_name("mb_plaque_b4h0") >= 0, "le sol plat devrait se trouver par son nom")
	_dire(lot.find_item_by_name("mb_plaque_b2h2") >= 0, "le mur plat devrait se trouver par son nom")
	print("   → %d items, tous nommés, maillés et collisionnés" % ids.size())


# ── 9. les couleurs disent la bande ─────────────────────────────────────────────────────────────────

## ⚠ CE N'EST PAS DE LA DÉCORATION : c'est la preuve visible que le modèle ORIENTÉ sert à quelque chose.
## Le sol plat doit être entièrement vert (il ne regarde que le ciel), le mur plat entièrement brun (il
## ne regarde que de côté), et le plafond d'une grotte bleu. En modèle aveugle, c'était la même pièce.
func _les_couleurs_disent_la_bande() -> void:
	print("\n9. les couleurs distinguent dessus, paroi et plafond")
	for essai in [
		{"nom": "mb_plaque_b4h0", "attendue": RP.COULEUR_DESSUS, "quoi": "le sol plat regarde le ciel"},
		{"nom": "mb_plaque_b0h4", "attendue": RP.COULEUR_PLAFOND, "quoi": "le plafond regarde le sol"},
		{"nom": "mb_plaque_b2h2", "attendue": RP.COULEUR_PAROI, "quoi": "le mur plat ne regarde que de côté"},
	]:
		var bits := -1
		for c in MB.classes():
			if c["nom"] == essai["nom"]:
				bits = c["bits"]
		_dire(bits >= 0, "la classe « %s » est introuvable" % essai["nom"])
		if bits < 0:
			continue
		var arrays: Array = RP.maillage(bits).surface_get_arrays(0)
		var couleurs: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var toutes := true
		for k in couleurs:
			if not k.is_equal_approx(essai["attendue"]):
				toutes = false
		_dire(toutes, "« %s » : %s, donc une seule couleur attendue" % [essai["nom"], essai["quoi"]])
		print("   %-18s %s" % [essai["nom"], essai["quoi"]])

	# Et le compte global : 46 classes sur 70 portent une surface vers le haut (mesuré hors moteur).
	var avec_dessus := 0
	for c in MB.classes():
		if not MB.porte_une_surface(c["bits"]):
			continue
		var arrays: Array = RP.maillage(c["bits"]).surface_get_arrays(0)
		var couleurs: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for k in couleurs:
			if k.is_equal_approx(RP.COULEUR_DESSUS):
				avec_dessus += 1
				break
	_dire(avec_dessus == 46,
		"%d classes portent une surface vers le haut, on en a mesuré 46" % avec_dessus)
	print("   → %d des 70 classes portent une surface vers le haut" % avec_dessus)


# ── 10. OÙ LA MATIÈRE SE TROUVE ─────────────────────────────────────────────────────────────────────

## ⚠ CE TEST EXISTE PARCE QU'UNE MUTATION EST RESTÉE MUETTE, ET C'EST LA DEUXIÈME FOIS DANS CE PROJET.
##
## Le défaut : dessiner chaque quart de carré du MAUVAIS CÔTÉ de son plan — la face se retrouve dans le
## quadrant opposé à son octant. Géométriquement c'est franc et visible. Et les 3030 vérifications
## précédentes n'y voyaient rien, parce qu'elles mesurent toutes des AGRÉGATS : l'aire ne bouge pas (le
## quad garde sa taille), le cube n'est pas débordé, aucun triangle n'a ses TROIS sommets sur un plan de
## coupe, les normales restent d'accord avec leur enroulement.
##
## ⚠ Le test du tranchage par blocs (disparu avec la branche lot3d) avait rendu le même verdict quelques
## heures plus tôt — trois mutations
## muettes, et le même diagnostic : *le test vérifiait les comptes, les aires et les boîtes, jamais OÙ
## la matière se trouve*. Une mutation muette a deux lectures — le code est inutile, ou le test est trop
## étroit — et on ne choisit pas la première parce qu'elle est plus commode (charte §6).
##
## LA VÉRIFICATION : on reconstruit DEPUIS LA GÉOMÉTRIE l'ensemble des couples (octant, axe) réellement
## émis, et on exige l'égalité stricte avec l'ensemble attendu — chaque face faite de deux triangles,
## aucune face en trop, aucun triangle égaré hors de son octant.
func _ou_la_matiere_se_trouve() -> void:
	print("\n10. OÙ chaque face se trouve, et pas seulement combien il y en a")
	for c in MB.classes():
		var bits: int = c["bits"]
		if not MB.porte_une_surface(bits):
			continue

		# L'ensemble ATTENDU, recalculé ici sans rien demander au module.
		var attendu := {}
		for t in 8:
			if not (bits & (1 << t)):
				continue
			for axe in 3:
				if not (bits & (1 << (t ^ (1 << axe)))):
					attendu["octant %d, axe %d" % [t, axe]] = true

		# L'ensemble OBTENU, relu dans les sommets eux-mêmes.
		var arrays: Array = RP.maillage(bits).surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var obtenu := {}
		var egares := 0
		for i in range(0, v.size(), 3):
			# L'axe de la face est celui que la normale désigne.
			var axe := -1
			for k in 3:
				if absf(n[i][k]) > 0.5:
					axe = k
			if axe < 0:
				egares += 1
				continue
			var t := 0
			var sain := true
			for k in 3:
				var lo: float = minf(minf(v[i][k], v[i + 1][k]), v[i + 2][k])
				var hi: float = maxf(maxf(v[i][k], v[i + 1][k]), v[i + 2][k])
				if k == axe:
					# Sur son propre axe, la face est PLATE et posée sur le plan central.
					if absf(lo) > 0.0001 or absf(hi) > 0.0001:
						sain = false
					# ⚠ Et c'est la normale qui dit de quel côté vit l'octant : elle pointe vers le
					# voisin VIDE, donc à l'opposé de la matière.
					t += (0 if n[i][k] > 0.0 else 1) << k
				elif hi <= 0.0001 and lo >= -0.5 - 0.0001:
					t += 0 << k   # l'octant tient tout entier du côté négatif
				elif lo >= -0.0001 and hi <= 0.5 + 0.0001:
					t += 1 << k   # ...ou tout entier du côté positif
				else:
					sain = false  # à cheval sur le plan central : il n'est dans aucun octant
			if not sain:
				egares += 1
				continue
			var cle := "octant %d, axe %d" % [t, axe]
			obtenu[cle] = obtenu.get(cle, 0) + 1

		_dire(egares == 0, "« %s » : %d triangle(s) hors de tout octant" % [c["nom"], egares])
		for cle in attendu:
			_dire(obtenu.get(cle, 0) == 2,
				"« %s » : %s devrait porter 2 triangles, on en trouve %d"
					% [c["nom"], cle, obtenu.get(cle, 0)])
		for cle in obtenu:
			_dire(attendu.has(cle), "« %s » : %s ne devrait pas exister" % [c["nom"], cle])

	print("   → chaque face est sur le bord de SON octant, et nulle part ailleurs")
