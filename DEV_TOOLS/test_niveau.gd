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
	var image := Image.create_empty(4 * 16, 16, false, Image.FORMAT_RGBA8)
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


func _contient(erreurs: Array, morceau: String) -> bool:
	for e in erreurs:
		if morceau in e:
			return true
	return false
