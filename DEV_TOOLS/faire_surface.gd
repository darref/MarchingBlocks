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
	["entree", "sol", Vector2i(25, 5), false, "ENTREE"],
	["buisson", "deco", Vector2i(5, 1), true, ""],
	["rocher", "deco", Vector2i(1, 6), true, ""],
	["cailloux", "deco", Vector2i(3, 4), false, ""],
	["fleurs", "deco", Vector2i(8, 9), false, ""],
	["herbe_haute", "deco", Vector2i(6, 9), false, ""],
	["champignons", "deco", Vector2i(2, 1), false, ""],
]

## Les objets qui tiennent sur PLUSIEURS cases : [nom, planche, coin, taille, rangées murées].
## ⚠ Chaque case du bloc devient une tuile nommée « nom_x_y » : le générateur de zone les pose ensemble,
## et la planche de contrôle montre le bloc reconstitué — un arbre décalé d'une case se voit tout de suite.
const BLOCS := [
	["arbre", "deco", Vector2i(6, 3), Vector2i(3, 4), [3]],
	["arbre_roux", "deco", Vector2i(6, 17), Vector2i(3, 4), [3]],
	# ⚠ Le trou d'une entrée n'est pas une tuile : c'est un bloc de 2 × 2. C'est ce que la planche de
	# contrôle a montré — « entree » tombait sur son quart supérieur gauche, d'où la pierre à cailloux.
	# Ce quart reste le MARQUEUR posé sur le calque des objets ; ce bloc-ci est le décor, sur le sol.
	["trou", "sol", Vector2i(29, 5), Vector2i(2, 2), []],
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

## [fond, dessus, coin haut-gauche du cadre 4×4, coin haut-gauche des coins rentrants 2×2]
const TRANSITIONS := [
	[0, 1, "sol", Vector2i(1, 1), Vector2i(3, 5)],
]

## Les tuiles UNIES, qui n'ont qu'un seul terrain aux quatre coins : [nom du rôle, terrain].
const UNIES := [["herbe", 0], ["herbe_sombre", 0], ["terre", 1]]

var _jeu: TileSet
var _sources := {}
var _ordre: Array = []  # les noms déclarés, dans l'ordre — c'est la légende de la planche


func _initialize() -> void:
	_jeu = TileSet.new()
	_jeu.tile_size = Vector2i(COTE, COTE)
	for nom in ["nom", "mur", "objet"]:
		var indice := _jeu.get_custom_data_layers_count()
		_jeu.add_custom_data_layer()
		_jeu.set_custom_data_layer_name(indice, nom)
		_jeu.set_custom_data_layer_type(indice, TYPE_BOOL if nom == "mur" else TYPE_STRING)
	_jeu.add_physics_layer()
	_jeu.set_physics_layer_collision_layer(0, 1)

	for cle in PLANCHES:
		var texture: Texture2D = load(PLANCHES[cle]) if ResourceLoader.exists(PLANCHES[cle]) else null
		if texture == null:
			print("ÉCHEC — planche introuvable ou non importée : %s" % PLANCHES[cle])
			print("       lance « godot --headless --path D:/UnderMend --import » puis recommence.")
			quit(1)
			return
		var source := TileSetAtlasSource.new()
		source.texture = texture
		source.texture_region_size = Vector2i(COTE, COTE)
		var id := _jeu.get_next_source_id()
		_jeu.add_source(source, id)  # ⚠ avant de créer la moindre tuile : sinon les données sont refusées
		_sources[cle] = {"id": id, "source": source, "texture": texture}

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
## Le terrain, ses tuiles unies, et ses transitions calculées. À appeler APRÈS que toutes les tuiles
## existent : on ne pose pas un coin sur une case qui n'est pas encore déclarée.
func _declarer_terrains() -> void:
	_jeu.add_terrain_set(0)
	_jeu.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	for i in TERRAINS.size():
		_jeu.add_terrain(0, i)
		_jeu.set_terrain_name(0, i, TERRAINS[i])

	var posees := 0
	for u in UNIES:
		var ou: Dictionary = _trouver(u[0])
		if ou.is_empty():
			print("  ⚠ terrain : le rôle « %s » est introuvable" % u[0])
			continue
		_poser_coins(ou["planche"], ou["case"], u[1], u[1], u[1], u[1])
		posees += 1

	for t in TRANSITIONS:
		var fond: int = t[0]
		var dessus: int = t[1]
		var planche: String = t[2]
		var cadre: Vector2i = t[3]
		var rentrants: Vector2i = t[4]
		# Le CADRE : une case du bord n'a « dessus » que du côté de l'intérieur.
		for fy in 4:
			for fx in 4:
				_poser_coins(planche, cadre + Vector2i(fx, fy),
					dessus if fx >= 1 and fy >= 1 else fond,
					dessus if fx <= 2 and fy >= 1 else fond,
					dessus if fx >= 1 and fy <= 2 else fond,
					dessus if fx <= 2 and fy <= 2 else fond)
				posees += 1
		# Les COINS RENTRANTS : le fond ne mord qu'un seul coin, celui tourné vers le centre du bloc.
		for cy in 2:
			for cx in 2:
				_poser_coins(planche, rentrants + Vector2i(cx, cy),
					fond if cx == 1 and cy == 1 else dessus,
					fond if cx == 0 and cy == 1 else dessus,
					fond if cx == 1 and cy == 0 else dessus,
					fond if cx == 0 and cy == 0 else dessus)
				posees += 1
	print("  terrain « %s » : %d tuiles raccordables (mode coins)" % [" / ".join(PackedStringArray(TERRAINS)), posees])


## Les quatre coins d'une case, dans l'ordre haut-gauche, haut-droit, bas-gauche, bas-droit.
func _poser_coins(planche: String, case: Vector2i, tl: int, tr: int, bl: int, br: int) -> void:
	var source: TileSetAtlasSource = _sources[planche]["source"]
	if source.get_tile_at_coords(case) == Vector2i(-1, -1):
		print("  ⚠ terrain : la case %s de %s n'existe pas" % [case, planche])
		return
	var donnees := source.get_tile_data(case, 0)
	donnees.set_terrain_set(0)
	donnees.set_terrain(br)  # en mode coins, c'est le raccord qui décide ; le terrain reste indicatif
	donnees.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, tl)
	donnees.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, tr)
	donnees.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, bl)
	donnees.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, br)


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
	var image := Image.create_empty(PAR_LIGNE * (COTE + 2), lignes * (COTE + 2), false, Image.FORMAT_RGBA8)
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
