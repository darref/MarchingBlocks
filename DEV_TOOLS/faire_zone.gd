extends SceneTree
##
## LA ZONE DE DÉPART — une première passe GÉNÉRÉE, faite pour être repeinte à la main.
##
## ⚠ CET OUTIL NE FAIT PAS LE NIVEAU, IL LE COMMENCE. Il pose une zone cohérente — un bord infranchissable,
## des routes, un lac, trois entrées et leurs trois grottes — pour que Jordan ait quelque chose à corriger
## plutôt qu'une page blanche. Dès qu'il aura repeint, cet outil n'a plus à tourner : il REFUSE d'écraser
## une zone existante sans `--ecraser`.
##
## ⚠ IL VALIDE SA PROPRE SORTIE. Avant d'écrire, il charge la zone par `CLIENT/niveau.gd` : si la carte
## est fautive (une entrée sans grotte dessous, une coupe trop courte), rien n'est enregistré. Un outil
## qui ne sait pas produire une carte valide n'a pas à la sauvegarder.
##
## ⚠ LE HASARD EST SEMÉ. Deux exécutions donnent la même zone, au pixel près : régénérer ne fait pas
## bouger le fichier dans git sans raison.
##
## LANCEMENT
##   godot --headless --path D:/UnderMend --script res://DEV_TOOLS/faire_zone.gd [-- --ecraser]

const Niveau := preload("res://CLIENT/niveau.gd")

const TILESET := "res://ART/tuiles.tres"
const DOSSIER := "res://NIVEAUX"
const CHEMIN := DOSSIER + "/zone_depart.tscn"
const GRAINE := 20260916

const LARGEUR := 64
const HAUTEUR := 40
const HAUTEUR_GROTTE := 10  # dix cases : exactement la hauteur d'une vue (charte §3)

## ⚠ CE QUE LA CAMÉRA VOIT AU-DELÀ DU JEU, en cases — donc ce qu'il faut remplir pour qu'on ne voie
## jamais le vide. Une vue de grotte fait au plus 240 px de large (sous terre), soit 15 cases, et le
## joueur y est centré : elle porte à 7,5 cases de lui, d'où huit colonnes de roche de chaque côté. La
## surface peut aller jusqu'à 320 px, soit 20 cases de large et 10 de haut.
const MARGE_GROTTE := Vector2i(8, 2)
const MARGE_SURFACE := Vector2i(10, 6)

## Les routes de terre, en rectangles de cases.
const ROUTES := [
	Rect2i(1, 20, 62, 1),
	Rect2i(12, 4, 1, 32),
	Rect2i(44, 12, 1, 24),
	Rect2i(12, 8, 19, 1),
]
const LAC := Rect2i(47, 4, 12, 11)
const ROCHERS := [Rect2i(18, 24, 4, 3), Rect2i(33, 14, 3, 4), Rect2i(6, 30, 5, 2), Rect2i(52, 22, 4, 4)]

## Chaque grotte : son chemin sur la grille de surface (charte §2) et la case où l'on peint son entrée.
## ⚠ L'entrée ne dit pas où elle mène — `CLIENT/niveau.gd` le DÉDUIT en la cherchant dans les chemins.
## Elle n'est ici que l'endroit où le peintre pose la tuile.
const GROTTES := [
	{"depart": Vector2i(8, 20), "segments": [Vector2i(16, 0)], "entree": Vector2i(12, 20)},
	{"depart": Vector2i(44, 24), "segments": [Vector2i(0, 8)], "entree": Vector2i(44, 28)},
	{"depart": Vector2i(20, 8), "segments": [Vector2i(8, 0), Vector2i(0, 6)], "entree": Vector2i(24, 8)},
]

var _jeu: TileSet
var _tuiles := {}  # nom -> coordonnées dans l'atlas
var _hasard := RandomNumberGenerator.new()


func _initialize() -> void:
	if FileAccess.file_exists(CHEMIN) and not "--ecraser" in OS.get_cmdline_user_args():
		print("%s existe déjà — je n'écrase pas une zone peinte." % CHEMIN)
		print("Relance avec « -- --ecraser » si c'est vraiment ce que tu veux.")
		quit(0)
		return
	if not ResourceLoader.exists(TILESET):
		print("%s manque — lance d'abord DEV_TOOLS/faire_tuiles.gd (et --import entre les deux)." % TILESET)
		quit(1)
		return

	_jeu = load(TILESET)
	_tuiles = _nommer_les_tuiles(_jeu)
	_hasard.seed = GRAINE

	var racine := _batir()
	root.add_child(racine)

	var resultat: Dictionary = racine.construire()
	for erreur in resultat["erreurs"]:
		print("  CARTE FAUTIVE — " + erreur)
	if not resultat["erreurs"].is_empty():
		print("rien n'est enregistré.")
		quit(1)
		return

	var monde = resultat["monde"]
	print("zone bâtie : %d×%d cases, %d grotte(s), %d entrée(s)" % [
		monde.grilles[0]["largeur"], monde.grilles[0]["hauteur"], resultat["chemins"].size(), resultat["entrees"].size()])
	for entree in resultat["entrees"]:
		print("  entrée %s → grotte %d, colonne %d, bouche %s" % [entree["case"], entree["grotte"], entree["colonne"], entree["bouche"]])

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOSSIER))
	var scene := PackedScene.new()
	if scene.pack(racine) != OK:
		print("ÉCHEC — impossible d'empaqueter la scène")
		quit(1)
		return
	var erreur := ResourceSaver.save(scene, CHEMIN)
	print("zone écrite : %s" % CHEMIN if erreur == OK else "ÉCHEC — écriture de %s (%d)" % [CHEMIN, erreur])
	quit(0 if erreur == OK else 1)


## ⚠ On retrouve une tuile par son NOM, jamais par sa position dans l'atlas : le jour où Jordan achète
## un lot, seules les positions changent.
func _nommer_les_tuiles(jeu: TileSet) -> Dictionary:
	var noms := {}
	var source := jeu.get_source(0) as TileSetAtlasSource
	for i in source.get_tiles_count():
		var coords := source.get_tile_id(i)
		var donnees := source.get_tile_data(coords, 0)
		noms[donnees.get_custom_data("nom")] = coords
	return noms


# ── bâtir l'arbre ───────────────────────────────────────────────────────────────────────────────────

func _batir() -> Node2D:
	var racine := Node2D.new()
	racine.name = "Zone"
	racine.set_script(load("res://CLIENT/zone.gd"))

	var surface := Node2D.new()
	surface.name = "Surface"
	racine.add_child(surface)
	var decor := _calque("Decor", surface)  # d'abord : il se dessine sous le reste
	var sol := _calque("Sol", surface)
	var objets := _calque("Objets", surface)
	_peindre_surface(sol, objets, decor)

	var grottes := Node2D.new()
	grottes.name = "Grottes"
	racine.add_child(grottes)
	for i in GROTTES.size():
		var description: Dictionary = GROTTES[i]
		var noeud := Node2D.new()
		noeud.name = "Grotte%d" % (i + 1)
		noeud.set_script(load("res://CLIENT/grotte.gd"))
		noeud.set("depart", description["depart"])
		var segments: Array[Vector2i] = []
		for s in description["segments"]:
			segments.append(s)
		noeud.set("segments", segments)
		grottes.add_child(noeud)
		var table: Array = Niveau.chemin(description["depart"], description["segments"])
		var decor_grotte := _calque("Decor", noeud)
		var coupe := _calque("Coupe", noeud)
		_calque("Objets", noeud)
		_peindre_grotte(coupe, decor_grotte, table.size(), table.find(description["entree"]))

	_adopter(racine, racine)
	return racine


func _calque(nom: String, parent: Node) -> TileMapLayer:
	var calque := TileMapLayer.new()
	calque.name = nom
	calque.tile_set = _jeu
	parent.add_child(calque)
	return calque


## ⚠ Sans propriétaire, un nœud n'est pas enregistré dans la scène : il disparaîtrait du fichier.
func _adopter(noeud: Node, racine: Node) -> void:
	for enfant in noeud.get_children():
		enfant.owner = racine
		_adopter(enfant, racine)


# ── peindre ─────────────────────────────────────────────────────────────────────────────────────────

func _poser(calque: TileMapLayer, pos: Vector2i, nom: String) -> void:
	calque.set_cell(pos, 0, _tuiles[nom])


func _peindre_surface(sol: TileMapLayer, objets: TileMapLayer, decor: TileMapLayer) -> void:
	_peindre_pourtour(decor, Rect2i(0, 0, LARGEUR, HAUTEUR), MARGE_SURFACE, "falaise")
	for y in HAUTEUR:
		for x in LARGEUR:
			_poser(sol, Vector2i(x, y), _terrain(x, y))
	for rocher in ROCHERS:
		for y in range(rocher.position.y, rocher.end.y):
			for x in range(rocher.position.x, rocher.end.x):
				_poser(sol, Vector2i(x, y), "rocher")
	for grotte in GROTTES:
		var case: Vector2i = grotte["entree"]
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				_poser(sol, case + Vector2i(dx, dy), "dalle")
		_poser(objets, case, "entree")


func _terrain(x: int, y: int) -> String:
	if x == 0 or y == 0 or x == LARGEUR - 1 or y == HAUTEUR - 1:
		return "falaise"  # le bord du monde est plein : la lumière s'y arrête, le joueur aussi
	if LAC.has_point(Vector2i(x, y)):
		return "eau"
	for route in ROUTES:
		if route.has_point(Vector2i(x, y)):
			return "terre"
	var tirage := _hasard.randf()
	if tirage < 0.06:
		return "herbe_haute"
	if tirage < 0.10:
		return "fleurs"
	if tirage < 0.12:
		return "buisson"
	return "herbe"


## Une coupe simple : de la roche en haut, l'air au milieu, le sol en bas, et un puits sous l'entrée.
## ⚠ LE POURTOUR N'EST PAS LE MONDE. Ce que peint `_peindre_pourtour` va dans un calque « Decor » que
## `CLIENT/niveau.gd` ne lit JAMAIS : il remplit l'œil et arrête les pieds, rien de plus. La grille,
## elle, s'arrête à la longueur du chemin — et pour le moteur, hors grille vaut déjà plein
## (`CORE/monde.gd`, `est_mur`). Remplir la grille elle-même casserait la règle « une colonne par case
## de surface » (charte §2).
func _peindre_pourtour(decor: TileMapLayer, jeu: Rect2i, marge: Vector2i, nom: String) -> void:
	var dehors := Rect2i(jeu.position - marge, jeu.size + marge * 2)
	for y in range(dehors.position.y, dehors.end.y):
		for x in range(dehors.position.x, dehors.end.x):
			if not jeu.has_point(Vector2i(x, y)):
				_poser(decor, Vector2i(x, y), nom)


func _peindre_grotte(coupe: TileMapLayer, decor: TileMapLayer, longueur: int, colonne_puits: int) -> void:
	_peindre_pourtour(decor, Rect2i(0, 0, longueur, HAUTEUR_GROTTE), MARGE_GROTTE, "roche_pleine")
	for x in longueur:
		_poser(coupe, Vector2i(x, 0), "roche_pleine")
		_poser(coupe, Vector2i(x, 1), "plafond")
		for y in range(2, HAUTEUR_GROTTE - 1):
			_poser(coupe, Vector2i(x, y), "air")
		_poser(coupe, Vector2i(x, HAUTEUR_GROTTE - 1), "sol_grotte")
		if _hasard.randf() < 0.18:
			_poser(coupe, Vector2i(x, HAUTEUR_GROTTE - 2), "gravats")
	if colonne_puits >= 0:
		_poser(coupe, Vector2i(colonne_puits, 0), "puits")
		_poser(coupe, Vector2i(colonne_puits, 1), "puits")
