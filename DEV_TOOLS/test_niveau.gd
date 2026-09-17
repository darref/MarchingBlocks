extends SceneTree
##
## LES TESTS DU NIVEAU PEINT — la carte est la vérité, le monde en est déduit.
##
## ⚠ Aucun de ces tests n'ouvre une scène : ils PEIGNENT des cartes en code, avec un jeu de tuiles bâti
## en mémoire, et vérifient ce que `CLIENT/niveau.gd` en déduit. C'est ce qui permet de les lancer en
## headless, et de construire exprès les cartes fautives qu'un peintre finira par produire.
##
## LANCEMENT
##   godot --headless --path D:/UnderMend --script res://DEV_TOOLS/test_niveau.gd
## Code de sortie 0 si tout passe, 1 sinon.

const Niveau := preload("res://CLIENT/niveau.gd")
const Couleur := preload("res://CORE/couleur.gd")

## Les tuiles du jeu d'essai, dans l'ordre de l'atlas.
const SOL := 0
const MUR := 1
const ENTREE := 2
const OEIL := 3
const MASSIF := 4
const ESCALIER := 5

var echecs: int = 0
var verifs: int = 0
var _jeu: TileSet


func _initialize() -> void:
	print("TESTS — Undermend, le niveau peint\n")
	_jeu = _jeu_de_tuiles()

	test_carte_simple()
	test_le_vide_est_plein()
	test_entree_deduit_sa_grotte()
	test_entree_hors_chemin_refusee()
	test_coupe_de_mauvaise_longueur()
	test_deux_grottes_sous_la_meme_case()
	test_segment_diagonal_refuse()
	test_ordre_de_peinture_indifferent()
	test_projection_le_long_du_chemin()
	test_les_murs_ont_leur_collision()
	test_marqueur_pose_ses_proprietes()
	test_dependances_par_noms()
	test_dependance_vers_un_nom_inconnu()
	test_deux_marqueurs_de_meme_nom()
	test_marqueur_type_inconnu()
	test_marqueur_propriete_inconnue()
	test_marqueur_sur_un_mur()
	test_ordre_des_marqueurs_indifferent()
	test_dependance_entre_deux_vues()
	test_depend_de_mal_forme()
	test_plateau_est_une_grille()
	test_escalier_relie_les_altitudes()
	test_escalier_qui_ne_relie_rien()

	print("")
	if echecs == 0:
		print("TOUT PASSE — %d vérifications." % verifs)
	else:
		print("%d ÉCHEC(S) sur %d vérifications." % [echecs, verifs])
	quit(1 if echecs > 0 else 0)


# --- outillage ---------------------------------------------------------------------------------------

func _verifier(condition: bool, quoi: String) -> void:
	verifs += 1
	if not condition:
		echecs += 1
		print("  ÉCHEC — " + quoi)


func _titre(texte: String) -> void:
	print("• " + texte)


func _jeu_de_tuiles() -> TileSet:
	# ⚠ SIX CASES, PAS QUATRE : ajouter une entrée à `tuiles` sans élargir l'image ferait échouer
	# `create_tile` hors de l'atlas — la source serait là, la tuile pas, et le test vérifierait du vide.
	var image := Image.create_empty(6 * 16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var jeu := TileSet.new()
	jeu.tile_size = Vector2i(16, 16)
	for nom in ["nom", "mur", "objet"]:
		var indice := jeu.get_custom_data_layers_count()
		jeu.add_custom_data_layer()
		jeu.set_custom_data_layer_name(indice, nom)
		jeu.set_custom_data_layer_type(indice, TYPE_BOOL if nom == "mur" else TYPE_STRING)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(16, 16)
	# ⚠ La source rejoint le TileSet AVANT qu'on crée les tuiles : une TileData ne connaît ses données
	# personnalisées que par le TileSet auquel elle appartient. Attachée après, elle les refuse EN
	# SILENCE — et le jeu d'essai vérifiait alors du vide sans le dire.
	jeu.add_source(source, 0)
	var tuiles := [
		{"nom": "sol", "mur": false, "objet": ""},
		{"nom": "mur", "mur": true, "objet": ""},
		{"nom": "entree", "mur": false, "objet": "ENTREE"},
		{"nom": "oeil", "mur": false, "objet": "OEIL_SACRE"},
		# Le dessus d'un plateau, et ce qui y monte. ⚠ Un escalier se reconnaît à son NOM, jamais à sa
		# position dans l'atlas : le jour où un autre lot arrive, seules les positions changent.
		{"nom": "massif_herbe", "mur": false, "objet": ""},
		{"nom": "massif_herbe_escalier_haut_0_0", "mur": false, "objet": ""},
	]
	for i in tuiles.size():
		var coords := Vector2i(i, 0)
		source.create_tile(coords)
		var donnees := source.get_tile_data(coords, 0)
		for cle in tuiles[i]:
			donnees.set_custom_data(cle, tuiles[i][cle])
	return jeu


func _calque() -> TileMapLayer:
	var calque := TileMapLayer.new()
	calque.tile_set = _jeu
	root.add_child(calque)
	return calque


func _remplir(calque: TileMapLayer, rect: Rect2i, tuile: int) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			calque.set_cell(Vector2i(x, y), 0, Vector2i(tuile, 0))


## Une grotte d'essai : un plafond muré, de l'air en dessous, et un puits ouvert à `colonne_puits`.
func _grotte(longueur: int, hauteur: int, colonne_puits: int = -1) -> TileMapLayer:
	var coupe := _calque()
	_remplir(coupe, Rect2i(0, 0, longueur, hauteur), SOL)
	_remplir(coupe, Rect2i(0, 0, longueur, 2), MUR)  # le plafond
	_remplir(coupe, Rect2i(0, hauteur - 1, longueur, 1), MUR)  # le sol
	if colonne_puits >= 0:
		_remplir(coupe, Rect2i(colonne_puits, 0, 1, 2), SOL)  # on creuse le puits
	return coupe


## Une grotte entièrement murée : pas un pouce d'air, donc aucune bouche possible nulle part.
func _grotte_pleine(longueur: int, hauteur: int) -> TileMapLayer:
	var coupe := _calque()
	_remplir(coupe, Rect2i(0, 0, longueur, hauteur), MUR)
	return coupe


func _surface(largeur: int, hauteur: int) -> TileMapLayer:
	var sol := _calque()
	_remplir(sol, Rect2i(0, 0, largeur, hauteur), SOL)
	return sol


# --- les tests ---------------------------------------------------------------------------------------

func test_carte_simple() -> void:
	_titre("une carte peinte donne ses grilles et ses murs")
	var sol := _surface(6, 4)
	sol.set_cell(Vector2i(2, 1), 0, Vector2i(MUR, 0))
	var resultat := Niveau.construire(sol, null, [])
	var monde = resultat["monde"]
	_verifier(resultat["erreurs"].is_empty(), "une carte saine ne doit rien signaler : %s" % str(resultat["erreurs"]))
	_verifier(monde.grilles[0]["largeur"] == 6 and monde.grilles[0]["hauteur"] == 4, "la grille doit faire 6×4")
	_verifier(monde.est_mur(0, Vector2i(2, 1)), "la tuile « mur » doit murer sa case")
	_verifier(not monde.est_mur(0, Vector2i(3, 1)), "la tuile « sol » ne doit pas murer")


## Vu échouer : une case non peinte laissée libre.
func test_le_vide_est_plein() -> void:
	_titre("une case non peinte est un mur — le vide est plein")
	var sol := _surface(5, 3)
	sol.erase_cell(Vector2i(1, 1))
	var monde = Niveau.construire(sol, null, [])["monde"]
	_verifier(monde.est_mur(0, Vector2i(1, 1)), "le trou dans la carte doit être un mur")


## Vu échouer : lien d'entrée écrit à la main au lieu d'être déduit du chemin.
func test_entree_deduit_sa_grotte() -> void:
	_titre("une entrée trouve sa grotte, sa colonne et sa bouche toute seule")
	var sol := _surface(12, 8)
	var objets := _calque()
	objets.set_cell(Vector2i(5, 2), 0, Vector2i(ENTREE, 0))
	# la grotte part de (3,2), court vers l'est sur 6 cases : la colonne 2 tombe sous (5,2)
	var grottes := [{"depart": Vector2i(3, 2), "segments": [Vector2i(6, 0)], "coupe": _grotte(7, 6, 2), "objets": null}]
	var resultat := Niveau.construire(sol, objets, grottes)
	_verifier(resultat["erreurs"].is_empty(), "rien à signaler : %s" % str(resultat["erreurs"]))
	_verifier(resultat["entrees"].size() == 1, "une entrée attendue, %d trouvée(s)" % resultat["entrees"].size())
	var entree: Dictionary = resultat["entrees"][0] if not resultat["entrees"].is_empty() else {}
	_verifier(entree.get("grotte", 0) == 1 and entree.get("colonne", -1) == 2, "grotte 1, colonne 2 attendues : %s" % str(entree))
	_verifier(entree.get("bouche", Vector2i(-1, -1)) == Vector2i(2, 0), "la bouche est la première case non murée du puits : %s" % str(entree))
	var monde = resultat["monde"]
	var id: int = monde.objet_en(0, Vector2i(5, 2))
	_verifier(id != -1 and monde.objets[id]["type"] == "ENTREE", "l'entrée doit être posée dans le monde")
	_verifier(monde.objets[id]["vers_grille"] == 1 and monde.objets[id]["vers_case"] == Vector2i(2, 0),
		"l'entrée doit viser la grotte 1 en (2, 0) : %s" % str(monde.objets[id]))


func test_entree_hors_chemin_refusee() -> void:
	_titre("une entrée peinte là où aucune grotte ne passe est signalée")
	var sol := _surface(12, 8)
	var objets := _calque()
	objets.set_cell(Vector2i(9, 6), 0, Vector2i(ENTREE, 0))
	var grottes := [{"depart": Vector2i(3, 2), "segments": [Vector2i(6, 0)], "coupe": _grotte(7, 6, 2), "objets": null}]
	var erreurs: Array = Niveau.construire(sol, objets, grottes)["erreurs"]
	_verifier(_contient(erreurs, "aucune grotte ne passe"), "erreur attendue, obtenu %s" % str(erreurs))

	_titre("une colonne entièrement murée n'a pas de bouche, et le dit")
	var objets2 := _calque()
	objets2.set_cell(Vector2i(5, 2), 0, Vector2i(ENTREE, 0))
	var bouchee := [{"depart": Vector2i(3, 2), "segments": [Vector2i(6, 0)], "coupe": _grotte_pleine(7, 6), "objets": null}]
	var erreurs2: Array = Niveau.construire(_surface(12, 8), objets2, bouchee)["erreurs"]
	_verifier(_contient(erreurs2, "pas de puits"), "erreur attendue, obtenu %s" % str(erreurs2))


## Vu échouer : longueur de la coupe non vérifiée contre la table.
func test_coupe_de_mauvaise_longueur() -> void:
	_titre("une coupe qui ne fait pas la longueur de son chemin est signalée")
	var grottes := [{"depart": Vector2i(3, 2), "segments": [Vector2i(6, 0)], "coupe": _grotte(5, 6, 2), "objets": null}]
	var erreurs: Array = Niveau.construire(_surface(12, 8), null, grottes)["erreurs"]
	_verifier(_contient(erreurs, "la coupe fait 5 colonnes"), "erreur attendue, obtenu %s" % str(erreurs))


func test_deux_grottes_sous_la_meme_case() -> void:
	_titre("deux grottes sous la même case rendraient une entrée ambiguë")
	var grottes := [
		{"depart": Vector2i(3, 2), "segments": [Vector2i(6, 0)], "coupe": _grotte(7, 6, 2), "objets": null},
		{"depart": Vector2i(5, 0), "segments": [Vector2i(0, 4)], "coupe": _grotte(5, 6, 2), "objets": null},
	]
	var erreurs: Array = Niveau.construire(_surface(12, 8), null, grottes)["erreurs"]
	_verifier(_contient(erreurs, "ambiguë"), "erreur attendue, obtenu %s" % str(erreurs))


func test_segment_diagonal_refuse() -> void:
	_titre("un segment en diagonale est refusé plutôt qu'interprété (charte §2, OUVERT)")
	var grottes := [{"depart": Vector2i(1, 1), "segments": [Vector2i(3, 3)], "coupe": _grotte(1, 6, 0), "objets": null}]
	var erreurs: Array = Niveau.construire(_surface(12, 8), null, grottes)["erreurs"]
	_verifier(_contient(erreurs, "diagonale"), "erreur attendue, obtenu %s" % str(erreurs))


## La règle du §6 de River Stones : une propriété d'indépendance à l'ordre se garde par un scénario qui
## CONSTRUIT les deux ordres.
func test_ordre_de_peinture_indifferent() -> void:
	_titre("deux cartes peintes dans un ordre différent donnent le même monde")
	var grottes_a := [{"depart": Vector2i(3, 2), "segments": [Vector2i(6, 0)], "coupe": _grotte(7, 6, 2), "objets": null}]
	var objets_a := _calque()
	objets_a.set_cell(Vector2i(5, 2), 0, Vector2i(ENTREE, 0))
	objets_a.set_cell(Vector2i(8, 5), 0, Vector2i(OEIL, 0))
	var a := Niveau.construire(_surface(12, 8), objets_a, grottes_a)

	var grottes_b := [{"depart": Vector2i(3, 2), "segments": [Vector2i(6, 0)], "coupe": _grotte(7, 6, 2), "objets": null}]
	var objets_b := _calque()
	objets_b.set_cell(Vector2i(8, 5), 0, Vector2i(OEIL, 0))
	objets_b.set_cell(Vector2i(5, 2), 0, Vector2i(ENTREE, 0))
	var b := Niveau.construire(_surface(12, 8), objets_b, grottes_b)

	_verifier(a["erreurs"].is_empty() and b["erreurs"].is_empty(), "les deux cartes doivent être saines : %s / %s" % [str(a["erreurs"]), str(b["erreurs"])])
	_verifier(a["monde"].empreinte() == b["monde"].empreinte(), "les deux mondes doivent être identiques")


func test_projection_le_long_du_chemin() -> void:
	_titre("la projection d'une colonne de grotte suit la table, coude compris")
	var chemins := {1: Niveau.chemin(Vector2i(3, 2), [Vector2i(2, 0), Vector2i(0, 2)])}
	# la table : (3,2) (4,2) (5,2) (5,3) (5,4)
	_verifier((chemins[1] as Array).size() == 5, "la table doit faire 5 cases : %s" % str(chemins[1]))
	_verifier(Niveau.case_de_surface(chemins, 1, 0.5) == Vector2(3.5, 2.5), "colonne 0 → (3.5, 2.5)")
	_verifier(Niveau.case_de_surface(chemins, 1, 2.5) == Vector2(5.5, 2.5), "colonne 2 → (5.5, 2.5)")
	_verifier(Niveau.case_de_surface(chemins, 1, 4.5) == Vector2(5.5, 4.5), "colonne 4 → (5.5, 4.5), après le coude")
	var milieu := Niveau.case_de_surface(chemins, 1, 3.0)
	_verifier(milieu.x == 5.5 and absf(milieu.y - 3.0) < 0.01, "entre deux colonnes, la caméra glisse : %s" % str(milieu))


## ⚠ CE TEST LIE LES DEUX DESCRIPTIONS D'UN MÊME FAIT. `mur` dit ce qui arrête la lumière, la collision
## dit ce qui arrête les pieds : si les deux se séparent, une tuile laisse passer l'un et pas l'autre, et
## ça ne se voit qu'en jouant. Elles sont donc générées ensemble, et vérifiées ensemble ici — sur le lot
## RÉELLEMENT livré, pas sur un jeu d'essai.
##
## Vu échouer : lot généré avant que la collision soit déduite de `mur` (aucun polygone nulle part).
func test_les_murs_ont_leur_collision() -> void:
	_titre("dans le lot livré, toute tuile « mur » porte sa collision — et aucune autre")
	var jeu: TileSet = load("res://ART/tuiles.tres")
	_verifier(jeu != null and jeu.get_physics_layers_count() >= 1, "le lot doit porter une couche physique")
	if jeu == null or jeu.get_physics_layers_count() < 1:
		return
	var source := jeu.get_source(0) as TileSetAtlasSource
	var murs := 0
	for i in source.get_tiles_count():
		var donnees := source.get_tile_data(source.get_tile_id(i), 0)
		var mur: bool = donnees.get_custom_data("mur")
		var polygones: int = donnees.get_collision_polygons_count(0)
		if mur:
			murs += 1
		_verifier(polygones == (1 if mur else 0), "« %s » : mur=%s, mais %d polygone(s) de collision" % [
			donnees.get_custom_data("nom"), mur, polygones])
	_verifier(murs >= 5, "le lot doit contenir des murs — %d trouvé(s)" % murs)


# --- les marqueurs : les objets du catalogue posés à la main ------------------------------------------
#
# ⚠ Ces tests ne construisent AUCUN nœud : ils passent à `construire()` les dictionnaires que
# `CLIENT/marqueur.gd` produit. C'est la même frontière que pour les calques — le chargeur reste testable
# sans scène, et un marqueur n'est qu'un nom, un type, une case et des propriétés.

func _marqueur(nom: String, type: String, ou: Vector2i, proprietes: Dictionary = {}) -> Dictionary:
	return {"nom": nom, "type": type, "case": ou, "proprietes": proprietes}


func test_marqueur_pose_ses_proprietes() -> void:
	_titre("un marqueur pose son objet AVEC ses propriétés")
	var marqueurs := [_marqueur("MiroirA", "MIROIR", Vector2i(3, 2), {"orientation": 5})]
	var resultat := Niveau.construire(_surface(8, 6), null, [], null, marqueurs)
	_verifier(resultat["erreurs"].is_empty(), "rien à signaler : %s" % str(resultat["erreurs"]))
	var monde = resultat["monde"]
	var id: int = monde.objet_en(0, Vector2i(3, 2))
	_verifier(id != -1, "le miroir doit être posé sur sa case")
	if id == -1:
		return
	_verifier(monde.objets[id]["type"] == "MIROIR", "type MIROIR attendu : %s" % str(monde.objets[id]))
	_verifier(monde.objets[id]["orientation"] == 5,
		"l'orientation réglée dans l'éditeur doit arriver dans le monde : %s" % str(monde.objets[id]))


## ⚠ LE TEST QUI JUSTIFIE TOUTE LA FORME « MARQUEUR ». Les identifiants de `CORE/monde.gd` sont distribués
## à la pose : le peintre ne peut pas les écrire. Il cite des NOMS, et c'est ici qu'on vérifie qu'ils
## deviennent les bons identifiants — y compris vers un marqueur posé APRÈS celui qui le cite.
func test_dependances_par_noms() -> void:
	_titre("une porte antique cite ses yeux par leurs NOMS, jamais par des identifiants")
	var marqueurs := [
		_marqueur("Porte", "PORTE_ANTIQUE", Vector2i(4, 2), {"depend_de": ["OeilNord", "OeilSud"], "mode": "tous"}),
		_marqueur("OeilNord", "OEIL_SACRE", Vector2i(1, 1), {"couleur": Couleur.JAUNE}),
		_marqueur("OeilSud", "OEIL_SACRE", Vector2i(1, 4), {"couleur": Couleur.JAUNE}),
	]
	var resultat := Niveau.construire(_surface(8, 6), null, [], null, marqueurs)
	_verifier(resultat["erreurs"].is_empty(), "rien à signaler : %s" % str(resultat["erreurs"]))
	var monde = resultat["monde"]
	var porte: int = monde.objet_en(0, Vector2i(4, 2))
	var nord: int = monde.objet_en(0, Vector2i(1, 1))
	var sud: int = monde.objet_en(0, Vector2i(1, 4))
	_verifier(porte != -1 and nord != -1 and sud != -1, "les trois marqueurs doivent être posés")
	if porte == -1 or nord == -1 or sud == -1:
		return
	var liste: Array = monde.objets[porte]["depend_de"]
	_verifier(liste.size() == 2 and nord in liste and sud in liste,
		"depend_de doit porter les identifiants des deux yeux : %s (nord=%d, sud=%d)" % [str(liste), nord, sud])


func test_dependance_vers_un_nom_inconnu() -> void:
	_titre("une dépendance vers un nom qui n'existe pas est signalée")
	var marqueurs := [
		_marqueur("Porte", "PORTE_ANTIQUE", Vector2i(4, 2), {"depend_de": ["OeilFantome"], "mode": "tous"}),
	]
	var erreurs: Array = Niveau.construire(_surface(8, 6), null, [], null, marqueurs)["erreurs"]
	_verifier(_contient(erreurs, "OeilFantome"), "erreur attendue, obtenu %s" % str(erreurs))


func test_deux_marqueurs_de_meme_nom() -> void:
	_titre("deux marqueurs de même nom : une dépendance ne saurait lequel désigner")
	var marqueurs := [
		_marqueur("Oeil", "OEIL_SACRE", Vector2i(1, 1), {"couleur": Couleur.JAUNE}),
		_marqueur("Oeil", "OEIL_SACRE", Vector2i(1, 4), {"couleur": Couleur.JAUNE}),
	]
	var erreurs: Array = Niveau.construire(_surface(8, 6), null, [], null, marqueurs)["erreurs"]
	_verifier(_contient(erreurs, "ce nom sert déjà"), "erreur attendue, obtenu %s" % str(erreurs))


func test_marqueur_type_inconnu() -> void:
	_titre("un marqueur d'un type que le catalogue ne connaît pas est signalé")
	var marqueurs := [_marqueur("Chose", "MIROITE", Vector2i(3, 2), {})]
	var erreurs: Array = Niveau.construire(_surface(8, 6), null, [], null, marqueurs)["erreurs"]
	_verifier(_contient(erreurs, "type inconnu"), "erreur attendue, obtenu %s" % str(erreurs))


## ⚠ C'est `CORE/monde.gd` qui refuse — une seule autorité sur ce qu'est une propriété. Ici on vérifie
## seulement que le refus REMONTE avec le nom du marqueur, au lieu d'être avalé.
func test_marqueur_propriete_inconnue() -> void:
	_titre("une propriété mal orthographiée est refusée, jamais posée en silence")
	var marqueurs := [_marqueur("MiroirA", "MIROIR", Vector2i(3, 2), {"orientaton": 5})]
	var resultat := Niveau.construire(_surface(8, 6), null, [], null, marqueurs)
	_verifier(_contient(resultat["erreurs"], "MiroirA"), "erreur nommant le marqueur attendue, obtenu %s" % str(resultat["erreurs"]))
	_verifier(resultat["monde"].objet_en(0, Vector2i(3, 2)) == -1, "rien ne doit avoir été posé")


func test_marqueur_sur_un_mur() -> void:
	_titre("un marqueur posé sur une case murée est signalé")
	var sol := _surface(8, 6)
	sol.set_cell(Vector2i(3, 2), 0, Vector2i(MUR, 0))
	var marqueurs := [_marqueur("MiroirA", "MIROIR", Vector2i(3, 2), {"orientation": 0})]
	var erreurs: Array = Niveau.construire(sol, null, [], null, marqueurs)["erreurs"]
	_verifier(_contient(erreurs, "MiroirA"), "erreur attendue, obtenu %s" % str(erreurs))


## ⚠ LA MÊME RÈGLE QUE POUR LES TUILES (§6 de River Stones) : une propriété d'indépendance à l'ordre se
## garde par un scénario qui CONSTRUIT les deux ordres. Les identifiants sont distribués à la pose ; sans
## le tri par case de `_poser_marqueurs`, glisser un nœud dans l'arbre changerait le monde en silence.
func test_ordre_des_marqueurs_indifferent() -> void:
	_titre("l'ordre des marqueurs dans l'arbre ne change pas le monde")
	var porte := _marqueur("Porte", "PORTE_ANTIQUE", Vector2i(4, 2), {"depend_de": ["OeilNord"], "mode": "tous"})
	var oeil := _marqueur("OeilNord", "OEIL_SACRE", Vector2i(1, 1), {"couleur": Couleur.JAUNE})
	var miroir := _marqueur("MiroirA", "MIROIR", Vector2i(6, 4), {"orientation": 3})

	var a := Niveau.construire(_surface(8, 6), null, [], null, [porte, oeil, miroir])
	var b := Niveau.construire(_surface(8, 6), null, [], null, [miroir, oeil, porte])
	_verifier(a["erreurs"].is_empty() and b["erreurs"].is_empty(),
		"les deux cartes doivent être saines : %s / %s" % [str(a["erreurs"]), str(b["erreurs"])])
	_verifier(a["monde"].empreinte() == b["monde"].empreinte(),
		"les deux mondes doivent être identiques quel que soit l'ordre de l'arbre")


## ⚠ CE TEST EST NÉ D'UNE MUTATION QUI N'A PAS ROUGI, et c'est pour ça qu'il est écrit ici plutôt que
## deviné. Résoudre les dépendances trop tôt — après la surface, avant les grottes — passait inaperçu
## tant qu'aucune dépendance ne traversait les deux vues. Or c'est exactement ce que le jeu raconte
## (charte §2) : on descend pour réparer ce qu'on voit d'en haut. Un œil au fond d'une grotte qui ouvre
## une porte en surface est la première énigme plausible, et rien ne la gardait.
func test_dependance_entre_deux_vues() -> void:
	_titre("une porte de SURFACE dépend d'un œil posé dans une GROTTE")
	var grottes := [{
		"depart": Vector2i(3, 2), "segments": [Vector2i(6, 0)],
		"coupe": _grotte(7, 6, 2), "objets": null,
		"marqueurs": [_marqueur("OeilProfond", "OEIL_SACRE", Vector2i(5, 3), {"couleur": Couleur.JAUNE})],
	}]
	var marqueurs := [
		_marqueur("PorteHaute", "PORTE_ANTIQUE", Vector2i(9, 6), {"depend_de": ["OeilProfond"], "mode": "tous"}),
	]
	var resultat := Niveau.construire(_surface(12, 8), null, grottes, null, marqueurs)
	_verifier(resultat["erreurs"].is_empty(), "rien à signaler : %s" % str(resultat["erreurs"]))
	var monde = resultat["monde"]
	var porte: int = monde.objet_en(0, Vector2i(9, 6))
	var oeil: int = monde.objet_en(1, Vector2i(5, 3))
	_verifier(porte != -1, "la porte doit être posée en surface")
	_verifier(oeil != -1, "l'œil doit être posé dans la grotte")
	if porte == -1 or oeil == -1:
		return
	_verifier(monde.objets[porte]["depend_de"] == [oeil],
		"la porte doit citer l'œil de la grotte : %s (œil = %d)" % [str(monde.objets[porte]["depend_de"]), oeil])


## ⚠ CE TEST GARDE UN GARDE-FOU QUE J'AVAIS RETIRÉ EN LE CROYANT MORT. Vider `depend_de` avant la pose
## ne change rien sur une carte saine — l'étape 5 écrase de toute façon, donc la mutation ne rougissait
## pas. Mais sur une valeur mal formée il n'y a rien à écraser, et `Monde.valider()` plantait en lisant
## une chaîne là où il attend un tableau. Un garde-fou qui semble mort peut n'être qu'un garde-fou dont
## les tests ne voient jamais le cas : ici, une carte FAUTIVE, qui est précisément ce qu'on peint à la main.
func test_depend_de_mal_forme() -> void:
	_titre("un « depend_de » qui n'est pas une liste est signalé, et ne fait pas planter le chargeur")
	var marqueurs := [
		_marqueur("Porte", "PORTE_ANTIQUE", Vector2i(4, 2), {"depend_de": "OeilNord", "mode": "tous"}),
	]
	var resultat := Niveau.construire(_surface(8, 6), null, [], null, marqueurs)
	_verifier(_contient(resultat["erreurs"], "doit être une liste"),
		"erreur attendue, obtenu %s" % str(resultat["erreurs"]))
	var monde = resultat["monde"]
	var porte: int = monde.objet_en(0, Vector2i(4, 2))
	_verifier(porte != -1, "la porte doit tout de même être posée, pour que le reste de la carte se lise")
	if porte == -1:
		return
	_verifier(monde.objets[porte]["depend_de"] is Array,
		"depend_de doit rester un TABLEAU quoi qu'on ait peint : %s" % str(monde.objets[porte]["depend_de"]))


# --- l'élévation : un plateau est une GRILLE, un escalier est un PORTAIL -----------------------------

## ⚠ Le dessus d'un plateau obéit à la même règle que la surface : ce qui n'est pas peint est un MUR.
## À l'altitude 1 le vide n'est pas du sol, c'est du vide — sans quoi on marcherait dans les airs
## partout où aucun massif n'a été posé.
func test_plateau_est_une_grille() -> void:
	_titre("un massif peint devient une grille où l'on ne marche que sur lui")
	var massifs := _calque()
	_remplir(massifs, Rect2i(3, 3, 3, 3), MASSIF)
	var resultat := Niveau.construire(_surface(10, 10), null, [], null, null, massifs)
	_verifier(resultat["erreurs"].is_empty(), "rien à signaler : %s" % str(resultat["erreurs"]))
	var monde = resultat["monde"]
	_verifier(monde.grilles.has(Niveau.PLATEAU), "la grille du plateau doit exister")
	if not monde.grilles.has(Niveau.PLATEAU):
		return
	_verifier(not monde.est_mur(Niveau.PLATEAU, Vector2i(4, 4)), "on marche sur le massif peint")
	_verifier(monde.est_mur(Niveau.PLATEAU, Vector2i(8, 8)), "hors du massif, l'altitude 1 est pleine")
	_verifier(not monde.est_mur(0, Vector2i(8, 8)), "le SOL, lui, reste libre sous le vide du plateau")


func test_escalier_relie_les_altitudes() -> void:
	_titre("un escalier pose deux portails, un par sens, et le peintre n'écrit aucune liaison")
	var massifs := _calque()
	_remplir(massifs, Rect2i(3, 3, 3, 3), MASSIF)
	# l'escalier juste SOUS le massif : dessus = plateau, dessous = sol
	massifs.set_cell(Vector2i(4, 6), 0, Vector2i(ESCALIER, 0))
	var resultat := Niveau.construire(_surface(10, 10), null, [], null, null, massifs)
	_verifier(resultat["erreurs"].is_empty(), "rien à signaler : %s" % str(resultat["erreurs"]))
	_verifier(resultat["escaliers"].size() == 1, "un escalier attendu, %d trouvé(s)" % resultat["escaliers"].size())
	var monde = resultat["monde"]
	var montee: int = monde.objet_en(0, Vector2i(4, 6))
	var descente: int = monde.objet_en(Niveau.PLATEAU, Vector2i(4, 6))
	_verifier(montee != -1 and descente != -1, "deux portails attendus à la même case, un par altitude")
	if montee == -1 or descente == -1:
		return
	_verifier(monde.objets[montee]["vers_grille"] == Niveau.PLATEAU
			and monde.objets[montee]["vers_case"] == Vector2i(4, 5),
		"depuis le sol, on monte sur le plateau : %s" % str(monde.objets[montee]))
	_verifier(monde.objets[descente]["vers_grille"] == 0
			and monde.objets[descente]["vers_case"] == Vector2i(4, 7),
		"depuis le plateau, on redescend au sol : %s" % str(monde.objets[descente]))


## ⚠ CE TEST GARDE LE SENS DE LA RÈGLE. Un escalier peint au milieu d'un plateau ne relie rien : il ne
## doit poser AUCUN portail — sinon la carte se remplirait de passages vers nulle part — et ne doit PAS
## être une faute, sinon on ne pourrait plus s'en servir comme décor.
func test_escalier_qui_ne_relie_rien() -> void:
	_titre("un escalier qui ne relie rien ne pose aucun portail, et n'est pas une faute")
	var massifs := _calque()
	_remplir(massifs, Rect2i(3, 3, 4, 4), MASSIF)
	massifs.set_cell(Vector2i(4, 4), 0, Vector2i(ESCALIER, 0))  # en plein milieu du plateau
	var resultat := Niveau.construire(_surface(10, 10), null, [], null, null, massifs)
	_verifier(resultat["erreurs"].is_empty(), "un décor ne doit rien signaler : %s" % str(resultat["erreurs"]))
	_verifier(resultat["escaliers"].is_empty(), "aucun passage attendu, %d trouvé(s)" % resultat["escaliers"].size())
	var monde = resultat["monde"]
	_verifier(monde.objet_en(0, Vector2i(4, 4)) == -1, "aucun portail au sol")
	_verifier(monde.objet_en(Niveau.PLATEAU, Vector2i(4, 4)) == -1, "aucun portail sur le plateau")


func _contient(erreurs: Array, morceau: String) -> bool:
	for e in erreurs:
		if morceau in e:
			return true
	return false
