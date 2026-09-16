extends SceneTree
##
## LA ZONE DE DÉPART — une première passe GÉNÉRÉE, faite pour être repeinte à la main.
##
## ⚠ CET OUTIL NE FAIT PAS LE NIVEAU, IL LE COMMENCE. Il pose une zone cohérente — un bord infranchissable,
## des routes, un lac à trois profondeurs, des bosquets, trois entrées et leurs trois grottes — pour que
## Jordan ait quelque chose à corriger plutôt qu'une page blanche. Dès qu'il aura repeint, cet outil n'a
## plus à tourner : il REFUSE d'écraser une zone existante sans `--ecraser`.
##
## ⚠ IL VALIDE SA PROPRE SORTIE. Avant d'écrire, il charge la zone par `CLIENT/niveau.gd` : si la carte
## est fautive (une entrée sans grotte dessous, une coupe trop courte), rien n'est enregistré.
##
## ⚠ IL NE CONNAÎT AUCUNE POSITION D'ATLAS, RIEN QUE DES NOMS : « herbe », « eau_profonde », « arbre ».
## Les deux tables qui disent où ces rôles se trouvent sont `faire_surface.gd` et `faire_coupe.gd`.
## Changer de lot de tuiles ne touchera pas ce fichier.
##
## ⚠ LE HASARD EST SEMÉ : deux exécutions donnent la même zone, au pixel près.
##
## LANCEMENT
##   godot --headless --path D:/UnderMend --script res://DEV_TOOLS/faire_zone.gd [-- --ecraser]

const Niveau := preload("res://CLIENT/niveau.gd")

const TILESET_SURFACE := "res://ART/surface.tres"
const TILESET_COUPE := "res://ART/coupe.tres"
const DOSSIER := "res://NIVEAUX"
const CHEMIN := DOSSIER + "/zone_depart.tscn"
const GRAINE := 20260916

const LARGEUR := 64
const HAUTEUR := 40
const HAUTEUR_GROTTE := 10  # dix cases : exactement la hauteur d'une vue (charte §3)

## ⚠ CE QUE LA CAMÉRA VOIT AU-DELÀ DU JEU, en cases — donc ce qu'il faut remplir pour qu'on ne voie
## jamais le vide. Une vue de grotte fait au plus 480 px de large (sous terre), soit 15 cases, et le
## joueur y est centré : elle porte à 7,5 cases de lui. La surface va jusqu'à 640 px, soit 20 cases.
const MARGE_GROTTE := Vector2i(8, 2)
const MARGE_SURFACE := Vector2i(10, 6)

const ROUTES := [
	Rect2i(1, 20, 62, 2),
	Rect2i(12, 4, 2, 32),
	Rect2i(44, 12, 2, 24),
	Rect2i(12, 8, 19, 2),
]
const LAC := Rect2i(47, 4, 12, 11)
const BOSQUETS := [Vector2i(18, 25), Vector2i(33, 14), Vector2i(6, 31), Vector2i(52, 24), Vector2i(26, 33), Vector2i(38, 5)]
## Les taches d'herbe sombre : des ÉTENDUES, pas un tirage par case. Un grain aléatoire case par case
## donne des carrés isolés qu'on prend pour un défaut d'affichage — vu sur la première capture.
const TACHES := [
	[Vector2i(20, 30), 5.0], [Vector2i(55, 20), 4.0], [Vector2i(8, 9), 4.5],
	[Vector2i(35, 25), 6.0], [Vector2i(50, 34), 4.0], [Vector2i(30, 3), 3.5], [Vector2i(3, 24), 3.0],
]
const ROCHERS := [Rect2i(20, 15, 3, 2), Rect2i(54, 33, 3, 2), Rect2i(4, 12, 2, 2)]

## Chaque grotte : son chemin sur la grille de surface (charte §2) et la case où l'on peint son entrée.
## ⚠ L'entrée ne dit pas où elle mène — `CLIENT/niveau.gd` le DÉDUIT en la cherchant dans les chemins.
const GROTTES := [
	{"depart": Vector2i(8, 20), "segments": [Vector2i(16, 0)], "entree": Vector2i(12, 20)},
	{"depart": Vector2i(44, 24), "segments": [Vector2i(0, 8)], "entree": Vector2i(44, 28)},
	{"depart": Vector2i(20, 8), "segments": [Vector2i(8, 0), Vector2i(0, 6)], "entree": Vector2i(24, 8)},
]

var _surface: TileSet
var _coupe: TileSet
var _noms_surface := {}
var _noms_coupe := {}
var _hasard := RandomNumberGenerator.new()
var _pris := {}  # les cases de surface déjà occupées par un décor : on n'empile pas deux arbres


func _initialize() -> void:
	if FileAccess.file_exists(CHEMIN) and not "--ecraser" in OS.get_cmdline_user_args():
		print("%s existe déjà — je n'écrase pas une zone peinte." % CHEMIN)
		print("Relance avec « -- --ecraser » si c'est vraiment ce que tu veux.")
		quit(0)
		return
	for chemin in [TILESET_SURFACE, TILESET_COUPE]:
		if not ResourceLoader.exists(chemin):
			print("%s manque — lance DEV_TOOLS/faire_surface.gd et faire_coupe.gd d'abord." % chemin)
			quit(1)
			return
	_surface = load(TILESET_SURFACE)
	_coupe = load(TILESET_COUPE)
	_noms_surface = _nommer(_surface)
	_noms_coupe = _nommer(_coupe)
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


## nom -> {source, case}. ⚠ On parcourt TOUTES les sources : un tileset bâti sur trois planches en a trois.
func _nommer(jeu: TileSet) -> Dictionary:
	var noms := {}
	for i in jeu.get_source_count():
		var id := jeu.get_source_id(i)
		var source := jeu.get_source(id) as TileSetAtlasSource
		if source == null:
			continue
		for k in source.get_tiles_count():
			var case := source.get_tile_id(k)
			var nom: String = source.get_tile_data(case, 0).get_custom_data("nom")
			if nom != "":
				noms[nom] = {"source": id, "case": case}
	return noms


# ── bâtir l'arbre ───────────────────────────────────────────────────────────────────────────────────

func _batir() -> Node2D:
	var racine := Node2D.new()
	racine.name = "Zone"
	racine.set_script(load("res://CLIENT/zone.gd"))

	var surface := Node2D.new()
	surface.name = "Surface"
	racine.add_child(surface)
	var decor := _calque("Decor", surface, _surface)  # d'abord : il se dessine sous le reste
	var sol := _calque("Sol", surface, _surface)
	var props := _calque("Props", surface, _surface)
	var objets := _calque("Objets", surface, _surface)
	_peindre_surface(sol, props, objets, decor)

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
		var decor_grotte := _calque("Decor", noeud, _coupe)
		var coupe := _calque("Coupe", noeud, _coupe)
		_calque("Props", noeud, _coupe)
		_calque("Objets", noeud, _coupe)
		_peindre_grotte(coupe, decor_grotte, table.size(), table.find(description["entree"]))

	_adopter(racine, racine)
	return racine


func _calque(nom: String, parent: Node, jeu: TileSet) -> TileMapLayer:
	var calque := TileMapLayer.new()
	calque.name = nom
	calque.tile_set = jeu
	parent.add_child(calque)
	return calque


## ⚠ Sans propriétaire, un nœud n'est pas enregistré dans la scène : il disparaîtrait du fichier.
func _adopter(noeud: Node, racine: Node) -> void:
	for enfant in noeud.get_children():
		enfant.owner = racine
		_adopter(enfant, racine)


# ── peindre ─────────────────────────────────────────────────────────────────────────────────────────

func _poser(calque: TileMapLayer, pos: Vector2i, nom: String, noms: Dictionary) -> void:
	if not noms.has(nom):
		print("  ⚠ tuile inconnue : « %s »" % nom)
		return
	calque.set_cell(pos, noms[nom]["source"], noms[nom]["case"])


## Un objet qui tient sur plusieurs cases : ses tuiles s'appellent « nom_x_y » (voir faire_surface.gd).
func _poser_bloc(calque: TileMapLayer, coin: Vector2i, nom: String, taille: Vector2i, noms: Dictionary) -> void:
	for y in taille.y:
		for x in taille.x:
			_poser(calque, coin + Vector2i(x, y), "%s_%d_%d" % [nom, x, y], noms)


## ⚠ LE POURTOUR N'EST PAS LE MONDE : ce calque « Decor » n'est jamais lu par `CLIENT/niveau.gd`. Il
## remplit l'œil et arrête les pieds ; la grille, elle, s'arrête où elle s'arrête, et hors grille vaut
## déjà plein pour le moteur (`CORE/monde.gd`).
func _peindre_pourtour(decor: TileMapLayer, jeu: Rect2i, marge: Vector2i, nom: String, noms: Dictionary) -> void:
	var dehors := Rect2i(jeu.position - marge, jeu.size + marge * 2)
	for y in range(dehors.position.y, dehors.end.y):
		for x in range(dehors.position.x, dehors.end.x):
			if not jeu.has_point(Vector2i(x, y)):
				_poser(decor, Vector2i(x, y), nom, noms)


func _peindre_surface(sol: TileMapLayer, props: TileMapLayer, objets: TileMapLayer, decor: TileMapLayer) -> void:
	_peindre_pourtour(decor, Rect2i(0, 0, LARGEUR, HAUTEUR), MARGE_SURFACE, "falaise", _noms_surface)
	for y in HAUTEUR:
		for x in LARGEUR:
			_poser(sol, Vector2i(x, y), _terrain(x, y), _noms_surface)

	# ⚠ LES CHEMINS SONT RACCORDÉS, PAS POSÉS CASE PAR CASE. `set_cells_terrain_connect()` choisit, pour
	# chaque case, la tuile dont les quatre coins s'accordent au voisinage : une route cesse d'être un
	# rectangle à escaliers et prend des bords organiques. Le terrain 1 est « terre » (faire_surface.gd).
	var chemin_cases: Array[Vector2i] = []
	for y in HAUTEUR:
		for x in LARGEUR:
			if _terrain(x, y) == "terre":
				chemin_cases.append(Vector2i(x, y))
	sol.set_cells_terrain_connect(chemin_cases, 0, 1, false)
	print("  chemins raccordés : %d cases" % chemin_cases.size())

	for rocher in ROCHERS:
		for y in range(rocher.position.y, rocher.end.y):
			for x in range(rocher.position.x, rocher.end.x):
				_poser(props, Vector2i(x, y), "rocher", _noms_surface)
				_pris[Vector2i(x, y)] = true

	# Les entrées : le trou de 2 × 2 sur le sol, le marqueur sur le calque des objets.
	for grotte in GROTTES:
		var case: Vector2i = grotte["entree"]
		for dy in range(-1, 2):
			for dx in range(-2, 3):
				_poser(sol, case + Vector2i(dx, dy), "dalle", _noms_surface)
				_pris[case + Vector2i(dx, dy)] = true
		_poser_bloc(sol, case + Vector2i(0, -1), "trou", Vector2i(2, 2), _noms_surface)
		_poser(objets, case, "entree", _noms_surface)

	for bosquet in BOSQUETS:
		_planter(props, bosquet)
	_semer(props)


## Un bosquet : trois ou quatre arbres serrés, jamais sur une route ni sur un décor déjà posé.
func _planter(props: TileMapLayer, centre: Vector2i) -> void:
	for n in _hasard.randi_range(3, 4):
		var coin := centre + Vector2i(_hasard.randi_range(-3, 3), _hasard.randi_range(-2, 2))
		var espece := "arbre" if _hasard.randf() < 0.7 else "arbre_roux"
		if _libre(coin, Vector2i(3, 4)):
			_poser_bloc(props, coin, espece, Vector2i(3, 4), _noms_surface)
			for y in 4:
				for x in 3:
					_pris[coin + Vector2i(x, y)] = true


## Les petites choses : buissons, cailloux, fleurs, hautes herbes, champignons.
func _semer(props: TileMapLayer) -> void:
	var petites := ["buisson", "cailloux", "fleurs", "herbe_haute", "herbe_haute", "champignons"]
	for n in 260:
		var pos := Vector2i(_hasard.randi_range(1, LARGEUR - 2), _hasard.randi_range(1, HAUTEUR - 2))
		if not _libre(pos, Vector2i.ONE):
			continue
		_poser(props, pos, petites[_hasard.randi_range(0, petites.size() - 1)], _noms_surface)
		_pris[pos] = true


## Libre = dans la carte, sur de l'herbe, et rien d'autre par-dessus.
func _libre(coin: Vector2i, taille: Vector2i) -> bool:
	for y in taille.y:
		for x in taille.x:
			var pos := coin + Vector2i(x, y)
			if pos.x < 1 or pos.y < 1 or pos.x >= LARGEUR - 1 or pos.y >= HAUTEUR - 1:
				return false
			if _pris.has(pos) or not _terrain(pos.x, pos.y).begins_with("herbe"):
				return false
	return true


## Le terrain d'une case : le bord du monde, le lac et ses rives, les routes, puis l'herbe et ses variantes.
func _terrain(x: int, y: int) -> String:
	if x == 0 or y == 0 or x == LARGEUR - 1 or y == HAUTEUR - 1:
		return "falaise"  # le bord du monde est plein : la lumière s'y arrête, le joueur aussi
	var pos := Vector2i(x, y)
	if LAC.grow(-2).has_point(pos):
		return "eau_profonde"
	if LAC.has_point(pos):
		return "eau"
	if LAC.grow(1).has_point(pos):
		return "rive"
	if LAC.grow(2).has_point(pos):
		return "sable"
	for route in ROUTES:
		if route.has_point(pos):
			return "terre"
	for tache in TACHES:
		var centre: Vector2i = tache[0]
		var rayon: float = tache[1]
		# ⚠ Le bord est adouci par le grain de la case, pas par un tirage : une tache doit avoir la même
		# forme à chaque exécution, et un contour irrégulier plutôt qu'un disque parfait.
		if Vector2(pos - centre).length() < rayon + _grain(x, y) * 1.5:
			return "herbe_sombre"
	return "herbe"


## ⚠ LE GRAIN EST UNE FONCTION DE LA CASE, PAS UN TIRAGE. `_libre()` interroge `_terrain()` longtemps
## après que la carte a été peinte : un tirage au hasard lui répondrait autre chose qu'à la peinture, et
## des arbres pousseraient dans l'eau. Une case doit donner la même réponse chaque fois qu'on la pose.
func _grain(x: int, y: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ GRAINE
	return float(absi(h) % 1000) / 1000.0


## Une coupe simple : de la roche en haut, l'air au milieu, le sol en bas, et un puits sous l'entrée.
func _peindre_grotte(coupe: TileMapLayer, decor: TileMapLayer, longueur: int, colonne_puits: int) -> void:
	_peindre_pourtour(decor, Rect2i(0, 0, longueur, HAUTEUR_GROTTE), MARGE_GROTTE, "roche_pleine", _noms_coupe)
	for x in longueur:
		# ⚠ Les deux extrémités sont CREUSÉES dans la roche : sans elles, la galerie est un rectangle noir
		# découpé dans du brun plat — ce que la première capture montrait. Les parois du lot portent leur
		# texture d'un seul côté, on les tourne donc vers l'intérieur. Jamais sur la colonne du puits :
		# c'est par là qu'on descend.
		var bord := (x == 0 or x == longueur - 1) and x != colonne_puits
		_poser(coupe, Vector2i(x, 0), "roche_pleine", _noms_coupe)
		_poser(coupe, Vector2i(x, 1), "plafond", _noms_coupe)
		for y in range(2, HAUTEUR_GROTTE - 1):
			var nom := "air"
			if bord:
				nom = "paroi_droite" if x == 0 else "paroi_gauche"
			_poser(coupe, Vector2i(x, y), nom, _noms_coupe)
		_poser(coupe, Vector2i(x, HAUTEUR_GROTTE - 1), "sol_grotte", _noms_coupe)
	if colonne_puits >= 0:
		_poser(coupe, Vector2i(colonne_puits, 0), "puits", _noms_coupe)
		_poser(coupe, Vector2i(colonne_puits, 1), "puits", _noms_coupe)
