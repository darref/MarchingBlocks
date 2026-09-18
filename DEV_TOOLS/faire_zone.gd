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
## ⚠ LA RÈGLE DE LA FALAISE, PARTAGÉE. Une seule description, trois appelants : ce générateur, l'outil
## `deriver_falaises.gd`, et le bouton de l'éditeur.
const Falaises := preload("res://DEV_TOOLS/falaises.gd")
## ⚠ Better Terrain remplace le système natif (voir faire_surface.gd). Il s'utilise hors éditeur, mais
## il faut l'instancier ET l'ajouter à l'arbre : ses caches appellent add_child().
const BETTER_TERRAIN := "res://addons/better-terrain/BetterTerrain.gd"

const TILESET_SURFACE := "res://ART/surface.tres"
const TILESET_COUPE := "res://ART/coupe.tres"
const DOSSIER := "res://NIVEAUX"
const CHEMIN := DOSSIER + "/zone_depart.tscn"
const GRAINE := 20260916

const LARGEUR := 64
const HAUTEUR := 40
const HAUTEUR_GROTTE := 10  # dix cases : exactement la hauteur d'une vue (charte §3)
## ⚠ VINGT ÉTAGES DE MASSIF, livrés vides et nommés `Massif00`…`Massif19` (Jordan, 18 septembre). Le
## nombre n'est pas une limite du moteur — `CLIENT/zone.gd` prend tout ce qui commence par « Massif »,
## et le vérificateur en balaie 64. C'est le nombre qu'on livre pour peindre sans avoir à en créer.
const ETAGES := 20

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
## ⚠ LE LAC EST FAIT DE DISQUES QUI SE RECOUVRENT, PAS D'UN RECTANGLE. Avec un rectangle, les meilleures
## tuiles de rive du monde donnent une piscine : ce sont les bords dessinés qui suivent la forme, jamais
## l'inverse. [centre, rayon]
const LAC_FORMES := [
	[Vector2i(52, 9), 5.2], [Vector2i(56, 7), 3.6], [Vector2i(48, 11), 3.2], [Vector2i(55, 12), 3.4],
]
const BOSQUETS := [Vector2i(18, 25), Vector2i(33, 14), Vector2i(6, 31), Vector2i(52, 24), Vector2i(26, 33), Vector2i(38, 5)]
## Les taches d'herbe sombre : des ÉTENDUES, pas un tirage par case. Un grain aléatoire case par case
## donne des carrés isolés qu'on prend pour un défaut d'affichage — vu sur la première capture.
const TACHES := [
	[Vector2i(20, 30), 5.0], [Vector2i(55, 20), 4.0], [Vector2i(8, 9), 4.5],
	[Vector2i(35, 25), 6.0], [Vector2i(50, 34), 4.0], [Vector2i(30, 3), 3.5], [Vector2i(3, 24), 3.0],
]
const ROCHERS := [Rect2i(20, 15, 3, 2), Rect2i(54, 33, 3, 2), Rect2i(4, 12, 2, 2)]

## UN PLATEAU, et son escalier. ⚠ Posé à l'écart de tout : le lac vit vers x48-56, les quatre routes
## passent en y20-21, x12-13, x44-45 et y8-9, et les trois entrées sont ailleurs encore. Un massif qui
## chevaucherait une route ou une entrée rendrait la carte fautive, et c'est le générateur qui le
## signalerait — mais autant ne pas le provoquer.
const PLATEAU := Rect2i(26, 25, 8, 7)
## ⚠ L'ESCALIER VA SOUS LE BORD BAS, et c'est sa rangée du BAS qui reliera : pour la rangée du haut, le
## dessous est encore de l'escalier, donc encore du plateau — et la règle de `CLIENT/niveau.gd` exige que
## le dessous SORTE du plateau. C'est voulu : on relie au pied de l'escalier, pas à mi-hauteur.
const PLATEAU_ESCALIER := Vector2i(29, 32)
## Les rangées de la falaise, de haut en bas — le milieu se répète, le pied touche le sol.
const FALAISE_RANGEES := ["milieu", "pied"]

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
var _bt
var _terrains := {}  # nom -> indice, relu du TileSet : une seule vérité, celle de faire_surface.gd
var _hasard := RandomNumberGenerator.new()
var _pris := {}  # les cases de surface déjà occupées par un décor : on n'empile pas deux arbres


## ⚠ `--sortie=` — écrire AILLEURS que sur la zone de départ. Sert à se fabriquer une carte d'essai
## (un plateau, un escalier) sans toucher à celle que Jordan est en train de repeindre. Le refus
## d'écraser continue de s'appliquer, à la destination demandée.
var _chemin := CHEMIN


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--sortie="):
			_chemin = option.substr("--sortie=".length())
	if FileAccess.file_exists(_chemin) and not "--ecraser" in OS.get_cmdline_user_args():
		print("%s existe déjà — je n'écrase pas une zone peinte." % _chemin)
		print("Relance avec « -- --ecraser » si c'est vraiment ce que tu veux.")
		quit(0)
		return
	for chemin in [TILESET_SURFACE, TILESET_COUPE]:
		if not ResourceLoader.exists(chemin):
			print("%s manque — lance DEV_TOOLS/faire_surface.gd et faire_coupe.gd d'abord." % chemin)
			quit(1)
			return
	_bt = load(BETTER_TERRAIN).new()
	root.add_child(_bt)
	_surface = load(TILESET_SURFACE)
	_coupe = load(TILESET_COUPE)
	_noms_surface = _nommer(_surface)
	_noms_coupe = _nommer(_coupe)
	for i in _bt.terrain_count(_surface):
		_terrains[_bt.get_terrain(_surface, i).name] = i
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
	var erreur := ResourceSaver.save(scene, _chemin)
	print("zone écrite : %s" % _chemin if erreur == OK else "ÉCHEC — écriture de %s (%d)" % [_chemin, erreur])
	quit(0 if erreur == OK else 1)


## Peindre un terrain par Better Terrain : on POSE les cases, puis on lance le solveur. ⚠ Les deux temps
## sont séparés exprès (comme en Godot 3) : poser ne raccorde rien, et raccorder sans avoir posé ne voit
## rien. `update_terrain_cells` recalcule aussi les cases ALENTOUR, pour que la couture se ferme.
func _raccorder(calque: TileMapLayer, cases: Array, terrain: String) -> void:
	if not _terrains.has(terrain):
		print("  ⚠ terrain inconnu : « %s »" % terrain)
		return
	_bt.set_cells(calque, cases, _terrains[terrain])
	_bt.update_terrain_cells(calque, cases)
	print("  %s : %d cases raccordées" % [terrain, cases.size()])


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
	# ⚠ LES MASSIFS D'ABORD, ET C'EST TOUTE LA DÉCISION (Jordan, 18 septembre). « Le monde est les
	# massifs » : ce ne sont pas des reliefs posés sur un fond, ce sont EUX le terrain. Placés en tête de
	# l'arbre, ils sont dessinés DERRIÈRE, et chaque étage révèle par ses bords ajourés celui du dessous —
	# `Massif07` laisse voir `Massif06`. C'est la PILE qui fait le relief, pas une tuile d'ombre.
	#
	# ⚠ CECI REMPLACE UNE DÉCISION MESURÉE, ET IL FAUT SAVOIR LAQUELLE. Les massifs vivaient au-dessus du
	# recouvrement parce que leurs bords sont ajourés et devaient révéler l'herbe. Ce n'est plus l'herbe
	# qu'ils révèlent, c'est l'étage inférieur — la mesure n'est pas fausse, son sujet a changé.
	#
	# ⚠ VINGT CALQUES CRÉÉS VIDES, comme le nœud « Marqueurs » plus bas et pour la même raison : un calque
	# d'étage qu'il faudrait créer à la main serait un calque nommé de travers un jour sur deux, et
	# `CLIENT/zone.gd` les reconnaît par leur PRÉFIXE. Un calque vierge ne crée aucune grille — mesuré.
	var etages: Array = []
	for n in ETAGES:
		etages.append(_calque("Massif%02d" % n, surface, _surface))
	# ⚠ `Decor` passe APRÈS les massifs, et ça ne change rien : il ne peint QUE hors du rectangle de jeu
	# (voir `_peindre_pourtour`), là où aucun massif ne va. Son rang n'a aucun effet sur l'aire jouable.
	var decor := _calque("Decor", surface, _surface)
	# ⚠ LA RÈGLE DES CALQUES (charte §6) : même calque quand l'art de transition est OPAQUE, calque séparé
	# quand il est AJOURÉ. Le sol porte donc ce dont les bordures sont dessinées en entier — herbe sombre,
	# terre, eau, falaise — et l'herbe claire, dont les bordures sont ajourées, vient au-dessus.
	var sol := _calque("Sol", surface, _surface)
	var nappe := _calque("Nappe", surface, _surface)
	# ⚠ Le RECOUVREMENT se pose entre le sol et les décors : ses ensembles ont l'extérieur transparent,
	# donc leurs bords laissent voir l'herbe du dessous. Le chargeur ne le lit pas — on marche dessus.
	var recouvrement := _calque("Recouvrement", surface, _surface)
	var props := _calque("Props", surface, _surface)
	var objets := _calque("Objets", surface, _surface)
	# ⚠ LE NŒUD DES MARQUEURS EST CRÉÉ VIDE, ET C'EST EXPRÈS. Les objets du catalogue sont des nœuds et
	# non des tuiles (charte §6) ; `CLIENT/zone.gd` cherche ce nom EXACT et rend une liste vide s'il ne le
	# trouve pas — sans erreur. Une zone livrée sans ce nœud obligerait donc à le créer à la main, et une
	# faute de frappe y serait silencieuse.
	var marqueurs := Node2D.new()
	marqueurs.name = "Marqueurs"
	surface.add_child(marqueurs)
	_peindre_surface(sol, nappe, recouvrement, etages[0], props, objets, decor)

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
		# ⚠ Même raison qu'en surface : une grotte peut porter ses propres miroirs et ses propres yeux.
		var marqueurs_grotte := Node2D.new()
		marqueurs_grotte.name = "Marqueurs"
		noeud.add_child(marqueurs_grotte)
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


## LA FALAISE SE DÉRIVE, ELLE NE SE RACCORDE PAS. Sous chaque bord SUD d'un plateau, on fait descendre la
## colonne qui convient : cap gauche là où l'ouest n'est pas aussi un bord sud, cap droit là où l'est ne
## l'est pas, milieu ailleurs. C'est la même forme de règle que `_est_plage()`, qui déduit la plage du lac.
##
## ⚠ J'avais mis la paroi DANS le terrain du massif et laissé Better Terrain la choisir : elle se peignait
## alors SUR la dernière rangée du plateau au lieu de PENDRE en dessous. Une falaise n'est pas décidée par
## son voisinage, elle est décidée par le bord qu'elle prolonge.
##
## ⚠ DEUX RANGÉES FIXES — milieu puis pied — faute de quoi que ce soit, dans la carte, qui dise la hauteur
## d'un plateau. Le lot sait répéter le milieu ; le jour où une hauteur se peint, c'est ici que ça se lit.
##
## ⚠ ON SAUTE LES MARCHES : la falaise descend exactement là où l'escalier se tient, et la murer
## boucherait le passage qu'on vient de construire.
##
## ⚠ Les deux milieux sont interchangeables — MESURÉ (joints de 0,013 à 0,069) — et se tirent au GRAIN,
## pas au hasard : deux exécutions doivent rendre la même carte.
## ⚠ LA RÈGLE N'EST PLUS ICI. Elle vit dans `DEV_TOOLS/falaises.gd`, partagée avec l'outil en ligne de
## commande et le bouton de l'éditeur. Elle était écrite deux fois et les deux avaient DÉJÀ divergé —
## l'une sautait une case occupée par une marche, l'autre sautait aussi le plateau. Ce générateur ne fait
## plus que l'APPLIQUER : le calcul d'un côté, la pose de l'autre.
func _descendre_la_falaise(massifs: TileMapLayer, dessus: Array, marches: Dictionary, famille: String) -> int:
	var plateau := {}
	for c in dessus:
		plateau[c] = famille
	var posees := 0
	for p in Falaises.calculer(plateau, marches):
		_poser(massifs, p["case"], p["nom"], _noms_surface)
		# ⚠ RÉSERVER LA PAROI. Les bosquets sont semés APRÈS le plateau et ne consultent que `_pris` :
		# sans cette ligne, un arbre pousse sur la falaise. Rien ne planterait — les deux sont des murs —
		# mais ça se verrait, et c'est le genre de défaut qu'aucun compteur ne signale.
		_pris[p["case"]] = true
		posees += 1
	return posees


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


func _peindre_surface(sol: TileMapLayer, nappe: TileMapLayer, recouvrement: TileMapLayer,
		massifs: TileMapLayer, props: TileMapLayer, objets: TileMapLayer, decor: TileMapLayer) -> void:
	_peindre_pourtour(decor, Rect2i(0, 0, LARGEUR, HAUTEUR), MARGE_SURFACE, "falaise", _noms_surface)
	for y in HAUTEUR:
		for x in LARGEUR:
			_poser(sol, Vector2i(x, y), _terrain(x, y), _noms_surface)

	# ⚠ LE LAC EST RACCORDÉ, LUI AUSSI. Ses bords viennent de la planche de l'eau : des cadres OPAQUES,
	# de la terre herbue percée d'un trou d'eau. Le terrain 2 du jeu 0, c'est « eau » (faire_surface.gd).
	var lac: Array[Vector2i] = []
	for y in HAUTEUR:
		for x in LARGEUR:
			var t := _terrain(x, y)
			if t == "eau" or t == "eau_profonde":
				lac.append(Vector2i(x, y))
	_raccorder(sol, lac, "eau")
	# ⚠ ON NE REPEINT PLUS LE FOND DU LAC. Reposer « eau_profonde » par-dessus le raccord remplaçait 58
	# tuiles par une tuile SANS terrain : autant de trous dans le voisinage, et Better Terrain ne savait
	# plus raccorder autour. Mesuré, pas supposé. La profondeur reviendra quand la planche aura livré ses
	# tuiles de transition eau / eau profonde — une matière de plus, pas un repeint par-dessus.

	# ⚠ LA NAPPE D'HERBE CLAIRE, partout SAUF dans les taches : ce qu'on ne peint pas devient une clairière
	# sombre, et c'est le SOL qu'on y voit. Ses bordures étant ajourées, elle ne peut pas vivre sur le même
	# calque que ce qu'elle révèle — essayé, et la capture a rendu des escaliers et des trous.
	var claire: Array[Vector2i] = []
	for y in HAUTEUR:
		for x in LARGEUR:
			if _terrain(x, y) == "herbe_sombre" and not _est_tache(x, y):
				claire.append(Vector2i(x, y))
	_raccorder(nappe, claire, "herbe")

	# ⚠ LES CHEMINS SONT RACCORDÉS, PAS POSÉS CASE PAR CASE. `set_cells_terrain_connect()` choisit, pour
	# chaque case, la tuile dont les quatre coins s'accordent au voisinage : une route cesse d'être un
	# rectangle à escaliers et prend des bords organiques. Le terrain 1 est « terre » (faire_surface.gd).
	var chemin_cases: Array[Vector2i] = []
	for y in HAUTEUR:
		for x in LARGEUR:
			if _terrain(x, y) == "terre":
				chemin_cases.append(Vector2i(x, y))
	_raccorder(sol, chemin_cases, "terre")
	print("  chemins raccordés : %d cases" % chemin_cases.size())

	for rocher in ROCHERS:
		for y in range(rocher.position.y, rocher.end.y):
			for x in range(rocher.position.x, rocher.end.x):
				_poser(props, Vector2i(x, y), "rocher", _noms_surface)
				_pris[Vector2i(x, y)] = true

	# La plage : du sable RACCORDÉ autour du lac, sur le recouvrement — l'herbe reste dessous et se voit
	# sur ses bords. Le terrain 1 du jeu 1, c'est « sable » (faire_surface.gd).
	var sable: Array[Vector2i] = []
	for y in HAUTEUR:
		for x in LARGEUR:
			if _est_plage(x, y):
				sable.append(Vector2i(x, y))
				_pris[Vector2i(x, y)] = true
	_raccorder(recouvrement, sable, "sable")

	# Les entrées : une plaque de gravier ARRONDIE et raccordée, le trou par-dessus, puis le marqueur.
	# ⚠ Le trou passe sur les props, au-dessus du gravier : posé dessous, il disparaîtrait.
	# ⚠ Les quatre cases du trou sont EXCLUES de la plaque : y poser du gravier puis le recouvrir de noir
	# faisait douze tuiles sans terrain au milieu du raccord. Une case simplement VIDE, elle, ne gêne pas —
	# Better Terrain sait ce qu'est le vide ; il ne sait pas quoi faire d'une tuile qui n'est rien.
	var trous := {}
	for grotte in GROTTES:
		for dy in 2:
			for dx in 2:
				trous[(grotte["entree"] as Vector2i) + Vector2i(dx, dy - 1)] = true
	var gravier: Array[Vector2i] = []
	for grotte in GROTTES:
		var case: Vector2i = grotte["entree"]
		for dy in range(-2, 3):
			for dx in range(-3, 4):
				var ou: Vector2i = case + Vector2i(dx, dy)
				_pris[ou] = true
				if absi(dx) + absi(dy) * 2 <= 5 and not trous.has(ou):
					gravier.append(ou)
	_raccorder(recouvrement, gravier, "gravier")

	# LE PLATEAU. ⚠ Le calque `Massifs` existait depuis plusieurs jours et RIEN N'Y PEIGNAIT : une zone
	# générée en sortait avec un calque vide, donc sans altitude à jouer. Un calque sans peintre n'est pas
	# une fonctionnalité, c'est une intention.
	var dessus: Array[Vector2i] = []
	for y in range(PLATEAU.position.y, PLATEAU.end.y):
		for x in range(PLATEAU.position.x, PLATEAU.end.x):
			dessus.append(Vector2i(x, y))
			_pris[Vector2i(x, y)] = true
	_raccorder(massifs, dessus, "massif_herbe")
	_poser_bloc(massifs, PLATEAU_ESCALIER, "massif_herbe_escalier_haut", Vector2i(3, 2), _noms_surface)
	var marches := {}
	for dy in 2:
		for dx in 3:
			var m: Vector2i = PLATEAU_ESCALIER + Vector2i(dx, dy)
			marches[m] = true
			_pris[m] = true
	var parois := _descendre_la_falaise(massifs, dessus, marches, "massif_herbe")
	print("  plateau : %d cases, escalier en %s, falaise : %d case(s)"
		% [dessus.size(), PLATEAU_ESCALIER, parois])
	# ⚠ LE SOL S'EFFACE SOUS LE MASSIF, sinon le relief ne se voit pas. MESURÉ, avant ce bloc : les massifs
	# étant passés en tête de l'arbre (donc dessinés DERRIÈRE) et `Sol` étant peint sur les 2560 cases,
	# 72 cases de massif sur 72 étaient entièrement recouvertes. Le plateau existait dans les données et
	# nulle part à l'écran — le défaut exact que ce fichier dénonce trois blocs plus haut.
	# « Le sol est les tuiles qu'on utilise À L'INTÉRIEUR des cadres » (Jordan, 18 septembre) : là où un
	# massif est peint, c'est le massif qu'on voit.
	# ⚠ ET LA CONSÉQUENCE DE JEU EST VOULUE, PAS SUBIE : une case non peinte sur `Sol` est un MUR à
	# l'altitude 0 (charte §6). L'empreinte d'un plateau cesse donc d'être praticable au niveau du sol —
	# on ne marche plus DANS le massif, on marche DESSUS, à son étage, et on y monte par l'escalier.
	# ⚠ SAUF SOUS LES MARCHES, et c'est le générateur qui me l'a appris en REFUSANT d'écrire : effacer le
	# sol sous l'escalier a rendu les trois portails invalides (« la case n'est pas libre dans les deux
	# altitudes »). Un escalier est le seul endroit du jeu où le sol ET le plateau doivent être praticables
	# sur la MÊME case — c'est la définition d'un passage. La règle des falaises saute déjà ces cases-là.
	# ⚠ Ces six cases restent donc recouvertes par le sol, donc INVISIBLES. C'est le cas que Jordan a
	# explicitement remis à plus tard : les jonctions entre étages iront sur un calque PAR-DESSUS.
	var efface := 0
	for pos in massifs.get_used_cells():
		if marches.has(pos):
			continue
		if sol.get_cell_source_id(pos) != -1:
			sol.erase_cell(pos)
			efface += 1
	print("  sol effacé sous le massif : %d case(s)" % efface)
	for grotte in GROTTES:
		var case: Vector2i = grotte["entree"]
		# ⚠ Le noir va SOUS tout, sur le sol : les tuiles de trou ont le centre transparent, et le gravier
		# s'écarte de ces quatre cases (voir plus haut). On voit donc le puits, et aucun raccord n'est crevé.
		for dy in 2:
			for dx in 2:
				_poser(sol, case + Vector2i(dx, dy - 1), "vide", _noms_surface)
		_poser_bloc(props, case + Vector2i(0, -1), "trou", Vector2i(2, 2), _noms_surface)
		_poser(objets, case, "entree", _noms_surface)
	print("  recouvrements raccordés : %d cases de sable, %d de gravier" % [sable.size(), gravier.size()])

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
		var quoi: String = petites[_hasard.randi_range(0, petites.size() - 1)]
		# ⚠ Un buisson occupe 2 × 2 cases. Posé comme une case unique, il ne montrait que son quart
		# sud-ouest — le même piège que le trou d'entrée, et la raison pour laquelle les blocs existent.
		var taille := Vector2i(2, 2) if quoi == "buisson" else Vector2i.ONE
		if not _libre(pos, taille):
			continue
		if taille == Vector2i.ONE:
			_poser(props, pos, quoi, _noms_surface)
		else:
			_poser_bloc(props, pos, quoi, taille, _noms_surface)
		for y in taille.y:
			for x in taille.x:
				_pris[pos + Vector2i(x, y)] = true


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
	if _dans_lac(x, y, -1.8):
		return "eau_profonde"
	if _dans_lac(x, y, 0.0):
		return "eau"
	# ⚠ La plage n'est PLUS du terrain : c'est un recouvrement de sable posé par-dessus l'herbe, qui
	# reste donc de l'herbe ici. Sans ça, ses bords seraient des marches au lieu d'un rivage.
	var pos := Vector2i(x, y)
	for route in ROUTES:
		if route.has_point(pos):
			return "terre"
	# ⚠ Le SOL est en herbe sombre : c'est la nappe d'herbe claire, posée au-dessus, qui décide de ce qu'on
	# voit. Les taches ne sont pas peintes ici — elles sont les trous de cette nappe (voir `_peindre_surface`).
	return "herbe_sombre"


## Une tache d'herbe sombre : un trou dans la nappe claire. ⚠ Son bord est adouci par le grain de la
## case, pas par un tirage — une tache doit avoir la même forme à chaque exécution.
func _est_tache(x: int, y: int) -> bool:
	var pos := Vector2i(x, y)
	for tache in TACHES:
		if Vector2(pos - (tache[0] as Vector2i)).length() < float(tache[1]) + _grain(x, y) * 1.5:
			return true
	return false




## ⚠ LE GRAIN EST UNE FONCTION DE LA CASE, PAS UN TIRAGE. `_libre()` interroge `_terrain()` longtemps
## après que la carte a été peinte : un tirage au hasard lui répondrait autre chose qu'à la peinture, et
## des arbres pousseraient dans l'eau. Une case doit donner la même réponse chaque fois qu'on la pose.
## Dans le lac, à `marge` cases près (négative pour l'eau profonde, positive pour la plage).
##
## ⚠ PAS DE GRAIN SUR LE CONTOUR DE L'EAU, contrairement aux clairières. Un bord bruité case par case
## fabrique des saillies d'UNE case, et un cadre de seize tuiles ne sait pas border ça : il n'a aucune
## tuile pour « terre à gauche, en haut ET à droite ». Le rivage repartait alors en marches, avec des
## fragments de bord isolés. La forme vient des disques qui se recouvrent ; le détail vient des tuiles.
func _dans_lac(x: int, y: int, marge: float) -> bool:
	var pos := Vector2i(x, y)
	for forme in LAC_FORMES:
		if Vector2(pos - (forme[0] as Vector2i)).length() < float(forme[1]) + marge:
			return true
	return false


## La bande de sable autour du lac : le pourtour, mais pas l'eau.
## ⚠ QUATRE cases d'épaisseur, pas deux. Une bande de deux n'a aucune case INTÉRIEURE : chacune est un
## cas limite, et le raccord n'a plus que des tuiles de bord à poser — d'où le peigne de dents carrées
## qu'on a vu sur la première plage.
func _est_plage(x: int, y: int) -> bool:
	return _dans_lac(x, y, 4.0) and not _dans_lac(x, y, 0.0)


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
