extends SceneTree
##
## LE TILESET DE LA SURFACE — bâti sur le lot acheté (TILESOURCES/Top-Down 32x32 RPG Asset Pack).
##
## ⚠ LES RÔLES SONT DES NOMS, PAS DES POSITIONS. La carte peinte demande « herbe », « eau », « falaise » ;
## la table ci-dessous est le SEUL endroit qui dise où ces rôles se trouvent dans les planches du lot.
## Changer de lot un jour, ce sera réécrire cette table — et rien d'autre (charte §6).
##
## ⚠ LES FONDS ONT ÉTÉ TROUVÉS PAR MESURE, PAS À L'ŒIL : une tuile de fond est opaque, peu contrastée,
## et se raccorde à elle-même bord à bord. Les décorations, elles, sont choisies à la main — donc l'outil
## écrit une PLANCHE DE CONTRÔLE (ART/planche_surface.png) où chaque rôle apparaît dans l'ordre de la
## table. On y vérifie d'un coup d'œil qu'aucun n'est décalé d'une case AVANT de peindre une zone entière.
##
## ⚠ La collision est déduite de `mur`, exactement comme pour le lot des grottes : `mur` arrête la
## lumière, la collision arrête les pieds, et les deux se posent ensemble ou pas du tout.
##
## LANCEMENT
##   godot --headless --path D:/UnderMend --script res://DEV_TOOLS/faire_surface.gd

const PACK := "res://TILESOURCES/Top-Down 32x32 RPG Asset Pack/"
const SORTIE := "res://ART/surface.tres"
const PLANCHE := "res://ART/planche_surface.png"
const COTE := 32
const PAR_LIGNE := 8  # la planche de contrôle

const PLANCHES := {
	"sol": PACK + "FLOORS.png",
	"eau": PACK + "WATER TILES.png",
	"deco": PACK + "Decorations.png",
}

## Les rôles d'UNE case : [nom, planche, case, mur, objet].
const TUILES := [
	["herbe", "sol", Vector2i(1, 9), false, ""],
	["herbe_sombre", "sol", Vector2i(1, 21), false, ""],
	["terre", "sol", Vector2i(1, 15), false, ""],
	["sable", "sol", Vector2i(1, 27), false, ""],
	["dalle", "sol", Vector2i(24, 2), false, ""],
	["falaise", "sol", Vector2i(25, 2), true, ""],
	["eau", "eau", Vector2i(9, 3), true, ""],
	["eau_profonde", "eau", Vector2i(13, 3), true, ""],
	["rive", "eau", Vector2i(17, 2), false, ""],
	# ⚠ « entree » ne vient PAS du lot : la case qu'il occupait appartient au bloc de coins rentrants du
	# gravier, et une tuile n'appartient qu'à un seul terrain. C'est un marqueur que nous dessinons, posé
	# sur le calque des objets ; le TROU, lui, reste le décor visible (bloc de 2 × 2, plus bas).
	# ⚠ « buisson » n'est plus ici : c'est un objet de 2 × 2, et n'en prendre qu'une case donnait son quart
	# sud-ouest tout seul. Il est déclaré en BLOC, plus bas — comme les arbres et le trou d'entrée.
	["rocher", "deco", Vector2i(1, 6), true, ""],
	# ⚠ Les cailloux BLOQUENT : un tas de pierres qu'on traverse n'est pas un décor, c'est un mensonge.
	# Ce qui reste traversable est ce qui arrive à la cheville — fleurs, hautes herbes, champignons.
	["cailloux", "deco", Vector2i(3, 4), true, ""],
	["fleurs", "deco", Vector2i(8, 9), false, ""],
	["herbe_haute", "deco", Vector2i(6, 9), false, ""],
	["champignons", "deco", Vector2i(2, 1), false, ""],
]

## Les objets qui tiennent sur PLUSIEURS cases : [nom, planche, coin, taille, rangées murées].
## ⚠ Chaque case du bloc devient une tuile nommée « nom_x_y » : le générateur de zone les pose ensemble,
## et la planche de contrôle montre le bloc reconstitué — un arbre décalé d'une case se voit tout de suite.
## ⚠ Les rangées MURÉES d'un bloc. Un arbre bloque ses DEUX rangées basses, pas seulement le tronc :
## avec la seule rangée du bas, on entrait dans l'arbre et on ne s'arrêtait qu'au pied — à l'usage, ça se
## voit comme une absence de collision. Les rangées hautes restent traversables, pour passer DERRIÈRE la
## cime, comme dans A Link to the Past.
const BLOCS := [
	["arbre", "deco", Vector2i(6, 3), Vector2i(3, 4), [2, 3]],
	["arbre_roux", "deco", Vector2i(6, 17), Vector2i(3, 4), [2, 3]],
	# ⚠ Le trou d'une entrée n'est pas une tuile : c'est un bloc de 2 × 2. C'est ce que la planche de
	# contrôle a montré — « entree » tombait sur son quart supérieur gauche, d'où la pierre à cailloux.
	# Ce quart reste le MARQUEUR posé sur le calque des objets ; ce bloc-ci est le décor, sur le sol.
	["trou", "sol", Vector2i(29, 5), Vector2i(2, 2), []],
	["buisson", "deco", Vector2i(5, 0), Vector2i(2, 2), [1]],
]

## ⚠ Des cases dont je ne suis pas sûr : elles ne sont PAS déclarées dans le tileset, elles ne font que
## s'afficher en bas de la planche, dans l'ordre, pour que le choix suivant soit informé plutôt que
## reparié. C'est ainsi qu'on a vu que « entree » tombait sur une pierre à cailloux et non sur un trou.
const CANDIDATS := [
	["sol", Vector2i(24, 5)], ["sol", Vector2i(25, 5)], ["sol", Vector2i(26, 5)],
	["sol", Vector2i(24, 6)], ["sol", Vector2i(25, 6)], ["sol", Vector2i(26, 6)],
	["sol", Vector2i(28, 5)], ["sol", Vector2i(29, 5)], ["sol", Vector2i(30, 5)],
	["sol", Vector2i(28, 6)], ["sol", Vector2i(29, 6)], ["sol", Vector2i(30, 6)],
	["eau", Vector2i(18, 4)], ["eau", Vector2i(19, 4)], ["eau", Vector2i(18, 5)],
	["deco", Vector2i(7, 9)], ["deco", Vector2i(9, 9)], ["deco", Vector2i(10, 9)],
]

## ⚠ L'AUTO-TUILAGE NATIF. Godot 4 n'a plus les bitmasks de Godot 3 : il a des TERRAINS. Chaque tuile
## déclare ce que valent ses quatre COINS, et `set_cells_terrain_connect()` choisit ensuite la tuile qui
## se raccorde. C'est ce qui supprime l'escalier entre deux matières et permet un chemin de terre qui
## n'est pas un rectangle.
##
## ⚠ ON NE TAPE PAS SEIZE CAS À LA MAIN, ON LES CALCULE. Le lot range toutes ses transitions de la même
## façon : un CADRE de 4 × 4 dont l'intérieur est plein, puis un bloc de 2 × 2 pour les coins RENTRANTS.
## Cette géométrie se déduit de la position de la case dans le cadre. Une table saisie à la main est
## exactement le genre d'endroit où l'on se trompe d'une case sans jamais s'en apercevoir.
const TERRAINS := ["herbe", "terre"]

## [fond, dessus, planche, coin haut-gauche du cadre 4×4, coin haut-gauche des coins rentrants 2×2]
const TRANSITIONS := [
	[0, 1, "sol", Vector2i(1, 1), Vector2i(3, 5)],
]

## ⚠ LE SECOND JEU : LES RECOUVREMENTS. Ces ensembles-là ont l'extérieur TRANSPARENT — ils ne remplacent
## pas l'herbe, ils se posent par-dessus, et c'est le calque du dessous qui se voit sur leurs bords. Leur
## fond n'est donc pas un terrain mais « rien » (-1), et ils vivent sur leur propre calque.
const TERRAINS_RECOUVREMENT := ["gravier", "sable", "herbe_claire"]
const RIEN := -1
## [terrain, planche, cadre 4×4, coins rentrants 2×2] — la matière est À L'INTÉRIEUR du cadre.
const RECOUVREMENTS := [
	[0, "sol", Vector2i(23, 1), Vector2i(25, 5)],
	[1, "sol", Vector2i(27, 1), Vector2i(29, 5)],
]

## ⚠ LES ENSEMBLES D'HERBE SONT DES DÉCOUPEURS DE TROUS : leur matière est à l'EXTÉRIEUR du cadre et le
## trou au centre — l'inverse du sable. On ne s'en sert donc pas pour poser des taches, mais pour peindre
## une NAPPE partout : ce qu'on ne peint pas devient une clairière, et c'est le calque du dessous qui s'y
## voit. Même géométrie calculée, fond et dessus échangés.
const NAPPES := [
	[2, "sol", Vector2i(10, 1), Vector2i(12, 5)],
]

## Ce que nous dessinons nous-mêmes, faute de l'avoir dans un lot.
const DESSINEES := "res://ART/surface_dessinees.png"
## ⚠ « vide » est le fond noir d'un trou d'entrée. Les tuiles de trou du lot ont le centre TRANSPARENT :
## posées sur du gravier, elles laissent voir le gravier, et le puits disparaît. Il faut du sombre
## dessous, et aucun lot ne fournit d'aplat noir — celui-ci est donc à nous, comme l'air des grottes.
const DESSINS := ["entree", "vide"]
const OR := Color("#ebbb69")
const NOIR := Color("#0d0a12")

## Les tuiles UNIES, qui n'ont qu'un seul terrain aux quatre coins : [nom du rôle, terrain].
const UNIES := [["herbe", 0], ["herbe_sombre", 0], ["terre", 1]]

## ⚠ UNE NAPPE A BESOIN DE SA TUILE PLEINE, et ces ensembles-là n'en contiennent pas : leurs seize cases
## sont toutes des bords ou des coins, puisque leur centre est le TROU. Sans une case unie à quatre coins
## de matière, Godot n'a rien à poser au milieu de la nappe et recycle des tuiles de bord — on voit alors
## des rectangles plus clairs alignés sur la grille. La case unie est juste sous l'ensemble.
## [terrain du jeu 1, planche, case]
const UNIES_RECOUVREMENT := [
	[2, "sol", Vector2i(10, 6)],
]

var _jeu: TileSet
var _sources := {}
var _ordre: Array = []  # les noms déclarés, dans l'ordre — c'est la légende de la planche


func _initialize() -> void:
	_dessiner_les_notres()
	_jeu = TileSet.new()
	_jeu.tile_size = Vector2i(COTE, COTE)
	for nom in ["nom", "mur", "objet"]:
		var indice := _jeu.get_custom_data_layers_count()
		_jeu.add_custom_data_layer()
		_jeu.set_custom_data_layer_name(indice, nom)
		_jeu.set_custom_data_layer_type(indice, TYPE_BOOL if nom == "mur" else TYPE_STRING)
	_jeu.add_physics_layer()
	_jeu.set_physics_layer_collision_layer(0, 1)

	var toutes := PLANCHES.duplicate()
	toutes["dessinees"] = DESSINEES
	for cle in toutes:
		var texture: Texture2D = load(toutes[cle]) if ResourceLoader.exists(toutes[cle]) else null
		if texture == null:
			print("ÉCHEC — planche introuvable ou non importée : %s" % toutes[cle])
			print("       lance « godot --headless --path D:/UnderMend --import » puis recommence.")
			quit(1)
			return
		var source := TileSetAtlasSource.new()
		source.texture = texture
		source.texture_region_size = Vector2i(COTE, COTE)
		var id := _jeu.get_next_source_id()
		_jeu.add_source(source, id)  # ⚠ avant de créer la moindre tuile : sinon les données sont refusées
		_sources[cle] = {"id": id, "source": source, "texture": texture}

	for i in DESSINS.size():
		# ⚠ Seul « entree » porte l'objet : « vide » n'est qu'un aplat noir, pas une porte.
		_declarer("dessinees", Vector2i(i, 0), DESSINS[i], false, "ENTREE" if DESSINS[i] == "entree" else "")
	for t in TUILES:
		_declarer(t[1], t[2], t[0], t[3], t[4])
	for b in BLOCS:
		var taille: Vector2i = b[3]
		var murs: Array = b[4]
		for y in taille.y:
			for x in taille.x:
				_declarer(b[1], b[2] + Vector2i(x, y), "%s_%d_%d" % [b[0], x, y], y in murs, "")

	# ⚠ TOUT LE LOT EST DÉCLARÉ, pas seulement les rôles : sinon on ne pourrait peindre que les quelques
	# tuiles nommées ici. ⚠ Ici, contrairement à la coupe, `mur` NE SE DÉDUIT PAS de l'opacité : l'herbe
	# est pleine et se traverse. Les cases anonymes arrivent donc traversables — à marquer dans l'éditeur
	# si elles doivent arrêter la lumière, sinon on aurait une falaise qu'on longe et que la lumière ignore.
	for cle in PLANCHES:
		_declarer_le_reste(cle)

	_declarer_terrains()

	var erreur := ResourceSaver.save(_jeu, SORTIE)
	if erreur != OK:
		print("ÉCHEC — écriture de %s (%d)" % [SORTIE, erreur])
		quit(1)
		return
	print("tileset de surface écrit : %s — %d tuiles nommées" % [SORTIE, _ordre.size()])
	_ecrire_planche_terrains()
	_ecrire_planche()
	quit(0)


func _declarer(planche: String, case: Vector2i, nom: String, mur: bool, objet: String) -> void:
	var source: TileSetAtlasSource = _sources[planche]["source"]
	var texture: Texture2D = _sources[planche]["texture"]
	var limite := Vector2i(texture.get_width() / COTE, texture.get_height() / COTE)
	if case.x < 0 or case.y < 0 or case.x >= limite.x or case.y >= limite.y:
		print("  ⚠ %s : la case %s sort de %s (%s cases)" % [nom, case, planche, limite])
		return
	if source.get_tile_at_coords(case) == Vector2i(-1, -1):
		source.create_tile(case)
	var donnees := source.get_tile_data(case, 0)
	donnees.set_custom_data("nom", nom)
	donnees.set_custom_data("mur", mur)
	donnees.set_custom_data("objet", objet)
	if mur and donnees.get_collision_polygons_count(0) == 0:
		var demi := COTE / 2.0
		donnees.add_collision_polygon(0)
		donnees.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-demi, -demi), Vector2(demi, -demi), Vector2(demi, demi), Vector2(-demi, demi)]))
	_ordre.append({"nom": nom, "planche": planche, "case": case, "mur": mur})


## La planche de contrôle : chaque rôle déclaré, dans l'ordre, sur un damier. Le fond en damier montre
## ce qui est transparent — une décoration posée sur la mauvaise case s'y voit immédiatement.
## Le marqueur d'entrée : un anneau d'or sur fond transparent. Discret, et surtout à NOUS — il ne prend
## la place d'aucune case d'un ensemble de transition.
func _dessiner_les_notres() -> void:
	var image := Image.create_empty(DESSINS.size() * COTE, COTE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for k in range(4, COTE - 4):
		for e in [4, 5, COTE - 6, COTE - 5]:
			image.set_pixelv(Vector2i(k, e), OR)
			image.set_pixelv(Vector2i(e, k), OR)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 20260916
	image.fill_rect(Rect2i(COTE, 0, COTE, COTE), NOIR)
	for n in 10:  # un grain à peine visible, pour que le noir ne soit pas plat
		image.set_pixelv(Vector2i(COTE + hasard.randi_range(0, COTE - 1), hasard.randi_range(0, COTE - 1)), NOIR.lightened(0.07))
	var erreur := image.save_png(DESSINEES)
	print("tuiles dessinées : %s (%s)" % [DESSINEES, "écrite" if erreur == OK else "ÉCHEC"])


## Les terrains, leurs tuiles unies et leurs transitions calculées. À appeler APRÈS que toutes les tuiles
## existent : on ne pose pas un coin sur une case qui n'est pas encore déclarée.
func _declarer_terrains() -> void:
	_jeu.add_terrain_set(0)
	_jeu.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	for i in TERRAINS.size():
		_jeu.add_terrain(0, i)
		_jeu.set_terrain_name(0, i, TERRAINS[i])
	_jeu.add_terrain_set(1)
	_jeu.set_terrain_set_mode(1, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	for i in TERRAINS_RECOUVREMENT.size():
		_jeu.add_terrain(1, i)
		_jeu.set_terrain_name(1, i, TERRAINS_RECOUVREMENT[i])

	var posees := 0
	for u in UNIES:
		var ou: Dictionary = _trouver(u[0])
		if ou.is_empty():
			print("  ⚠ terrain : le rôle « %s » est introuvable" % u[0])
			continue
		_poser_coins(ou["planche"], ou["case"], 0, u[1], u[1], u[1], u[1], u[1])
		posees += 1
	for u in UNIES_RECOUVREMENT:
		_poser_coins(u[1], u[2], 1, u[0], u[0], u[0], u[0], u[0])
		posees += 1

	# [jeu, terrain PROPRE des tuiles, fond, dessus, planche, cadre, coins rentrants]
	var travaux: Array = []
	for t in TRANSITIONS:
		travaux.append([0, t[1], t[0], t[1], t[2], t[3], t[4]])
	for r in RECOUVREMENTS:
		# ⚠ Le fond d'un recouvrement est RIEN : ses bords laissent voir le calque du dessous.
		travaux.append([1, r[0], RIEN, r[0], r[1], r[2], r[3]])
	for n in NAPPES:
		# ⚠ Une nappe est l'inverse : la matière est le FOND, et c'est le trou qui est au centre du cadre.
		# Son terrain propre reste la matière — sans quoi elle ne serait candidate à rien.
		travaux.append([1, n[0], n[0], RIEN, n[1], n[2], n[3]])

	for t in travaux:
		var jeu_terrain: int = t[0]
		var centre: int = t[1]
		var fond: int = t[2]
		var dessus: int = t[3]
		var planche: String = t[4]
		var cadre: Vector2i = t[5]
		var rentrants: Vector2i = t[6]
		# Le CADRE : une case du bord n'a « dessus » que du côté de l'intérieur.
		# ⚠ Le terrain PROPRE de chaque tuile est « dessus » — la matière à laquelle elle appartient — et
		# jamais la valeur d'un de ses coins. Quand on peint un terrain, Godot ne retient comme candidates
		# que les tuiles dont le terrain propre est celui qu'on peint : une tuile de bord déclarée « rien »
		# disparaît des candidates, la moitié des bords manque, et le raccord retombe sur des tuiles
		# approchantes en alternance. C'est exactement le peigne de dents carrées qu'on a vu sur la plage.
		for fy in 4:
			for fx in 4:
				_poser_coins(planche, cadre + Vector2i(fx, fy), jeu_terrain, centre,
					dessus if fx >= 1 and fy >= 1 else fond,
					dessus if fx <= 2 and fy >= 1 else fond,
					dessus if fx >= 1 and fy <= 2 else fond,
					dessus if fx <= 2 and fy <= 2 else fond)
				posees += 1
		# Les COINS RENTRANTS : le fond ne mord qu'un seul coin, celui tourné vers le centre du bloc.
		for cy in 2:
			for cx in 2:
				_poser_coins(planche, rentrants + Vector2i(cx, cy), jeu_terrain, centre,
					fond if cx == 1 and cy == 1 else dessus,
					fond if cx == 0 and cy == 1 else dessus,
					fond if cx == 1 and cy == 0 else dessus,
					fond if cx == 0 and cy == 0 else dessus)
				posees += 1
	print("  terrain « %s » : %d tuiles raccordables (mode coins)" % [" / ".join(PackedStringArray(TERRAINS)), posees])


## Les quatre coins d'une case, dans l'ordre haut-gauche, haut-droit, bas-gauche, bas-droit.
## `centre` est le terrain PROPRE de la tuile : la matière à laquelle elle appartient. C'est lui qui la
## rend candidate quand on peint cette matière ; les quatre coins disent ensuite comment elle se raccorde.
func _poser_coins(planche: String, case: Vector2i, jeu_terrain: int, centre: int, tl: int, tr: int, bl: int, br: int) -> void:
	# ⚠ Une tuile dont les QUATRE coins valent « rien » ne porte aucune information : c'est le trou d'une
	# nappe, entièrement transparent, donc une case qui n'existe pas dans l'atlas. On la saute sans bruit
	# — la réclamer reviendrait à exiger une tuile pour représenter l'absence de tuile.
	if tl == RIEN and tr == RIEN and bl == RIEN and br == RIEN:
		return
	var source: TileSetAtlasSource = _sources[planche]["source"]
	if source.get_tile_at_coords(case) == Vector2i(-1, -1):
		print("  ⚠ terrain : la case %s de %s n'existe pas" % [case, planche])
		return
	var donnees := source.get_tile_data(case, 0)
	donnees.set_terrain_set(jeu_terrain)
	donnees.set_terrain(centre)
	donnees.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, tl)
	donnees.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, tr)
	donnees.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, bl)
	donnees.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, br)


## ⚠ LA PLANCHE DES TERRAINS — celle qui dit ce que j'ai DÉCLARÉ, pas ce que je crois avoir déclaré.
## Chaque tuile raccordable y est dessinée avec quatre pastilles, une par coin, de la couleur du terrain
## que je lui ai donné. Si une pastille ne correspond pas à ce que montre le dessin de la tuile, la règle
## est fausse — et c'est la seule façon de le voir autrement qu'en peignant une carte entière.
func _ecrire_planche_terrains() -> void:
	var couleurs := [Color(0.45, 0.45, 0.5)]  # l'indice -1 (rien) tient la première place
	for i in TERRAINS.size():
		couleurs.append(_jeu.get_terrain_color(0, i))
	var couleurs_r := [Color(0.45, 0.45, 0.5)]
	for i in TERRAINS_RECOUVREMENT.size():
		couleurs_r.append(_jeu.get_terrain_color(1, i))

	var cases: Array = []
	for cle in _sources:
		var source: TileSetAtlasSource = _sources[cle]["source"]
		for k in source.get_tiles_count():
			var case := source.get_tile_id(k)
			var donnees := source.get_tile_data(case, 0)
			if donnees.get_terrain_set() >= 0:
				cases.append({"planche": cle, "case": case, "donnees": donnees})
	if cases.is_empty():
		return

	var lignes := ceili(float(cases.size()) / PAR_LIGNE)
	var image := Image.create_empty(PAR_LIGNE * (COTE + 2), lignes * (COTE + 2), false, Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			image.set_pixel(x, y, Color(0.1, 0.1, 0.12) if (x / 8 + y / 8) % 2 == 0 else Color(0.18, 0.18, 0.22))
	var coins := [
		[TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, Vector2i(2, 2)],
		[TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, Vector2i(COTE - 8, 2)],
		[TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, Vector2i(2, COTE - 8)],
		[TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, Vector2i(COTE - 8, COTE - 8)],
	]
	for i in cases.size():
		var e: Dictionary = cases[i]
		var donnees: TileData = e["donnees"]
		var atlas: Image = (_sources[e["planche"]]["texture"] as Texture2D).get_image()
		var coin := Vector2i(i % PAR_LIGNE, i / PAR_LIGNE) * (COTE + 2) + Vector2i(1, 1)
		image.blend_rect(atlas, Rect2i((e["case"] as Vector2i) * COTE, Vector2i(COTE, COTE)), coin)
		var palette: Array = couleurs if donnees.get_terrain_set() == 0 else couleurs_r
		for c in coins:
			var terrain: int = donnees.get_terrain_peering_bit(c[0])
			image.fill_rect(Rect2i(coin + (c[1] as Vector2i), Vector2i(6, 6)), palette[terrain + 1])
	image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	image.save_png("res://ART/planche_terrains.png")
	print("planche des terrains : res://ART/planche_terrains.png — %d tuiles raccordables, %d par ligne" % [cases.size(), PAR_LIGNE])
	print("    pastilles : gris = rien ; jeu 0 = %s ; jeu 1 = %s" % [
		" / ".join(PackedStringArray(TERRAINS)), " / ".join(PackedStringArray(TERRAINS_RECOUVREMENT))])


func _trouver(nom: String) -> Dictionary:
	for e in _ordre:
		if e["nom"] == nom:
			return e
	return {}


## Les cases du lot qu'aucun rôle n'a prises : déclarées sans nom et TRAVERSABLES, pour qu'on puisse les
## peindre. Une case entièrement transparente est ignorée — ce n'est pas une tuile, c'est un trou.
func _declarer_le_reste(planche: String) -> void:
	var texture: Texture2D = _sources[planche]["texture"]
	var source: TileSetAtlasSource = _sources[planche]["source"]
	var image := texture.get_image()
	var limite := Vector2i(texture.get_width() / COTE, texture.get_height() / COTE)
	var ajoutees := 0
	for y in limite.y:
		for x in limite.x:
			var case := Vector2i(x, y)
			if source.get_tile_at_coords(case) != Vector2i(-1, -1):
				continue
			var opaques := 0
			for py in range(case.y * COTE, case.y * COTE + COTE, 2):
				for px in range(case.x * COTE, case.x * COTE + COTE, 2):
					if image.get_pixel(px, py).a > 0.5:
						opaques += 1
			if opaques < 8:
				continue
			source.create_tile(case)
			var donnees := source.get_tile_data(case, 0)
			donnees.set_custom_data("nom", "")
			donnees.set_custom_data("mur", false)
			donnees.set_custom_data("objet", "")
			ajoutees += 1
	print("  %s : %d cases anonymes ajoutées (traversables)" % [planche, ajoutees])


func _ecrire_planche() -> void:
	var lignes := ceili(float(_ordre.size()) / PAR_LIGNE) + _hauteur_des_blocs() + ceili(float(CANDIDATS.size()) / PAR_LIGNE)
	# ⚠ La planche doit être assez large pour TOUS les blocs reconstitués : le buisson tombait hors de
	# l'image, et un outil de contrôle qui tronque sa sortie ment par omission.
	var largeur_blocs := 1
	for b in BLOCS:
		largeur_blocs += (b[3] as Vector2i).x * COTE + 8
	var image := Image.create_empty(maxi(PAR_LIGNE * (COTE + 2), largeur_blocs), lignes * (COTE + 2), false, Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			image.set_pixel(x, y, Color(0.1, 0.1, 0.12) if (x / 8 + y / 8) % 2 == 0 else Color(0.18, 0.18, 0.22))
	for i in _ordre.size():
		var entree: Dictionary = _ordre[i]
		var atlas: Image = (_sources[entree["planche"]]["texture"] as Texture2D).get_image()
		var source := Rect2i(entree["case"] * COTE, Vector2i(COTE, COTE))
		var coin := Vector2i(i % PAR_LIGNE, i / PAR_LIGNE) * (COTE + 2) + Vector2i(1, 1)
		image.blend_rect(atlas, source, coin)
		if entree["mur"]:  # un liseré rouge en haut : cette tuile arrête la lumière ET les pieds
			image.fill_rect(Rect2i(coin, Vector2i(COTE, 2)), Color(0.9, 0.2, 0.2))

	# ⚠ Les blocs RECONSTITUÉS, en dessous : une tuile par tuile ne dit pas si un arbre est bien cadré.
	var y_bloc := ceili(float(_ordre.size()) / PAR_LIGNE) * (COTE + 2)
	var x_bloc := 1
	for b in BLOCS:
		var taille: Vector2i = b[3]
		var atlas: Image = (_sources[b[1]]["texture"] as Texture2D).get_image()
		for y in taille.y:
			for x in taille.x:
				image.blend_rect(atlas, Rect2i((b[2] + Vector2i(x, y)) * COTE, Vector2i(COTE, COTE)),
					Vector2i(x_bloc + x * COTE, y_bloc + y * COTE))
		x_bloc += taille.x * COTE + 8

	# Puis les CANDIDATS, tout en bas, sur leur propre ligne.
	var y_candidat := y_bloc + _hauteur_des_blocs() * (COTE + 2)
	for i in CANDIDATS.size():
		var c: Array = CANDIDATS[i]
		var atlas: Image = (_sources[c[0]]["texture"] as Texture2D).get_image()
		var coin := Vector2i(i % PAR_LIGNE, i / PAR_LIGNE) * (COTE + 2) + Vector2i(1, y_candidat)
		image.blend_rect(atlas, Rect2i((c[1] as Vector2i) * COTE, Vector2i(COTE, COTE)), coin)

	image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	image.save_png(PLANCHE)
	print("planche de contrôle : %s — %d cases, %d par ligne, dans cet ordre :" % [PLANCHE, _ordre.size(), PAR_LIGNE])
	var ligne := ""
	for i in _ordre.size():
		ligne += "%s  " % _ordre[i]["nom"]
		if i % PAR_LIGNE == PAR_LIGNE - 1:
			print("    " + ligne)
			ligne = ""
	if ligne != "":
		print("    " + ligne)
	print("    puis, en bas, les blocs reconstitués : %s" % str(BLOCS.map(func(b): return b[0])))
	var candidats := ""
	for i in CANDIDATS.size():
		candidats += "%s%s  " % [CANDIDATS[i][0], CANDIDATS[i][1]]
		if i % PAR_LIGNE == PAR_LIGNE - 1:
			print("    candidats : " + candidats)
			candidats = ""
	if candidats != "":
		print("    candidats : " + candidats)


func _hauteur_des_blocs() -> int:
	var maximum := 0
	for b in BLOCS:
		maximum = maxi(maximum, (b[3] as Vector2i).y)
	return maximum
