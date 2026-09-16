extends SceneTree
##
## LE TILESET DE LA SURFACE — bâti sur le lot acheté, et sur BETTER TERRAIN plutôt que sur le système
## natif de Godot.
##
## ⚠ POURQUOI BETTER TERRAIN. Le natif exige un match EXACT et n'a que deux modes exclusifs : par coins
## OU par côtés. Un lot acheté n'a jamais toutes les pièces — le nôtre n'a aucun coin rentrant pour
## l'eau — et le natif retombe alors sur la tuile pleine : le rivage sort en marches, sans un mot
## d'erreur. Trois tentatives l'ont montré (charte §6). Better Terrain, lui :
##   • accepte les HUIT voisinages à la fois, côtés ET coins (pour des tuiles carrées : 0, 3, 4, 7, 8,
##     11, 12, 15 dans `TileSet.CellNeighbor`) ;
##   • choisit au MEILLEUR SCORE, avec pénalités, donc un lot incomplet dégrade au lieu de s'effondrer ;
##   • connaît les CATÉGORIES : un terrain peut en représenter plusieurs. L'eau borde ainsi « tout ce
##     qui est ferme » — herbe, terre, sable, gravier — au lieu de la seule herbe ;
##   • sait retourner et pivoter une tuile (symétries), et pondérer les variantes (probabilités).
##
## ⚠ IL S'UTILISE HORS ÉDITEUR, mais il faut l'INSTANCIER ET L'AJOUTER À L'ARBRE : ses caches appellent
## `add_child()`. Ses données vivent dans les métadonnées du TileSet et des TileData, et survivent à
## l'aller-retour sur disque (vérifié).
##
## ⚠ LES RÔLES RESTENT DES NOMS. La carte demande « herbe », « eau », « arbre » ; cette table est le seul
## endroit qui dise où ils se trouvent dans les planches du lot.
##
## LANCEMENT
##   godot --headless --path D:/UnderMend --script res://DEV_TOOLS/faire_surface.gd

const BETTER_TERRAIN := "res://addons/better-terrain/BetterTerrain.gd"
const PACK := "res://TILESOURCES/Top-Down 32x32 RPG Asset Pack/"
const SORTIE := "res://ART/surface.tres"
const PLANCHE := "res://ART/planche_surface.png"
const PLANCHE_TERRAINS := "res://ART/planche_terrains.png"
const DESSINEES := "res://ART/surface_dessinees.png"
const COTE := 32
const PAR_LIGNE := 8
const RIEN := -1  # BetterTerrain.TileCategory.EMPTY

## Les huit voisins d'une case carrée, tels que Better Terrain les attend.
const VOISINS := {
	"gauche": TileSet.CELL_NEIGHBOR_LEFT_SIDE,
	"droite": TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
	"haut": TileSet.CELL_NEIGHBOR_TOP_SIDE,
	"bas": TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
	"hg": TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	"hd": TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	"bg": TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	"bd": TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
}

const PLANCHES := {
	"sol": PACK + "FLOORS.png",
	"eau": PACK + "WATER TILES.png",
	"deco": PACK + "Decorations.png",
}

## Ce que nous dessinons nous-mêmes, faute de l'avoir dans un lot.
const DESSINS := ["entree", "vide"]
const OR := Color("#ebbb69")
const NOIR := Color("#0d0a12")

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
	# ⚠ Les cailloux BLOQUENT : un tas de pierres qu'on traverse n'est pas un décor, c'est un mensonge.
	["cailloux", "deco", Vector2i(3, 4), true, ""],
	["rocher", "deco", Vector2i(1, 6), true, ""],
	["fleurs", "deco", Vector2i(8, 9), false, ""],
	["herbe_haute", "deco", Vector2i(6, 9), false, ""],
	["champignons", "deco", Vector2i(2, 1), false, ""],
]

## Les objets sur PLUSIEURS cases : [nom, planche, coin, taille, rangées murées].
const BLOCS := [
	["arbre", "deco", Vector2i(6, 3), Vector2i(3, 4), [2, 3]],
	["arbre_roux", "deco", Vector2i(6, 17), Vector2i(3, 4), [2, 3]],
	["trou", "sol", Vector2i(29, 5), Vector2i(2, 2), []],
	["buisson", "deco", Vector2i(5, 0), Vector2i(2, 2), [1]],
]

## Des cases dont je ne suis pas sûr : affichées en bas de la planche, jamais déclarées.
const CANDIDATS := [
	["sol", Vector2i(24, 5)], ["sol", Vector2i(25, 5)], ["sol", Vector2i(26, 5)],
	["eau", Vector2i(5, 6)], ["eau", Vector2i(6, 6)], ["eau", Vector2i(5, 11)],
	["eau", Vector2i(4, 18)], ["eau", Vector2i(5, 18)], ["eau", Vector2i(4, 19)],
]

## LES TERRAINS, dans l'ordre : l'indice EST l'identité. ⚠ Une catégorie se déclare AVANT ceux qui en
## font partie, puisqu'ils la citent par son indice.
const TERRAINS := [
	{"nom": "sol", "couleur": "#8a7b5a", "categorie": true},
	{"nom": "herbe", "couleur": "#59842c", "dans": ["sol"]},
	{"nom": "herbe_claire", "couleur": "#7b9729", "dans": ["sol"]},
	{"nom": "terre", "couleur": "#81502f", "dans": ["sol"]},
	{"nom": "sable", "couleur": "#d7b876", "dans": ["sol"]},
	{"nom": "gravier", "couleur": "#a89a8b", "dans": ["sol"]},
	{"nom": "eau", "couleur": "#1d9488", "dans": []},
]

## Les tuiles PLEINES d'un terrain : [terrain, planche, case]. Tous leurs voisinages sont eux-mêmes.
const PLEINES := [
	["herbe", "sol", Vector2i(1, 21)],
	["herbe_claire", "sol", Vector2i(10, 6)],
	["terre", "sol", Vector2i(1, 15)],
	["sable", "sol", Vector2i(1, 27)],
	["gravier", "sol", Vector2i(24, 2)],
	["eau", "eau", Vector2i(9, 3)],
]

## LES ENSEMBLES DE TRANSITION. Toujours la même géométrie : un cadre de 4 × 4 dont l'intérieur est la
## matière, puis un bloc de 2 × 2 pour les coins RENTRANTS (rentrants = (-1,-1) quand la planche n'en a
## pas). ⚠ `nappe` inverse le rapport : la matière est DEHORS et le trou au centre — c'est le cas des
## trois ensembles d'herbe, qui découpent des clairières au lieu de poser des taches.
## `fond` est le nom du terrain (ou de la CATÉGORIE) qui entoure la matière ; "" veut dire « rien ».
const ENSEMBLES := [
	{"terrain": "terre", "fond": "herbe", "planche": "sol", "cadre": Vector2i(1, 1), "rentrants": Vector2i(3, 5)},
	{"terrain": "gravier", "fond": "", "planche": "sol", "cadre": Vector2i(23, 1), "rentrants": Vector2i(25, 5)},
	{"terrain": "sable", "fond": "", "planche": "sol", "cadre": Vector2i(27, 1), "rentrants": Vector2i(29, 5)},
	{"terrain": "herbe_claire", "fond": "", "planche": "sol", "cadre": Vector2i(10, 1), "rentrants": Vector2i(12, 5), "nappe": true},
	# ⚠ L'eau borde la CATÉGORIE « sol » : herbe, terre, sable ou gravier, indifféremment. C'est ce que
	# le natif ne savait pas dire, et c'est ce qui manquait au rivage.
	{"terrain": "eau", "fond": "sol", "planche": "eau", "cadre": Vector2i(0, 7), "rentrants": Vector2i(-1, -1)},
]

var _bt
var _jeu: TileSet
var _sources := {}
var _ordre: Array = []
var _indices := {}  # nom de terrain -> indice


func _initialize() -> void:
	_bt = load(BETTER_TERRAIN).new()
	root.add_child(_bt)  # ⚠ ses caches appellent add_child : il lui faut l'arbre

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
		_jeu.add_source(source, id)  # ⚠ avant de créer la moindre tuile
		_sources[cle] = {"id": id, "source": source, "texture": texture}

	for i in DESSINS.size():
		_declarer("dessinees", Vector2i(i, 0), DESSINS[i], false, "ENTREE" if DESSINS[i] == "entree" else "")
	for t in TUILES:
		_declarer(t[1], t[2], t[0], t[3], t[4])
	for b in BLOCS:
		var taille: Vector2i = b[3]
		var murs: Array = b[4]
		for y in taille.y:
			for x in taille.x:
				_declarer(b[1], b[2] + Vector2i(x, y), "%s_%d_%d" % [b[0], x, y], y in murs, "")
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
	_ecrire_planche_terrains()
	quit(0)


## Le marqueur d'entrée et l'aplat noir d'un trou : deux tuiles qu'aucun lot ne fournit.
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
	for n in 10:
		image.set_pixelv(Vector2i(COTE + hasard.randi_range(0, COTE - 1), hasard.randi_range(0, COTE - 1)), NOIR.lightened(0.07))
	var erreur := image.save_png(DESSINEES)
	print("tuiles dessinées : %s (%s)" % [DESSINEES, "écrite" if erreur == OK else "ÉCHEC"])


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


# ── les terrains, par Better Terrain ────────────────────────────────────────────────────────────────

func _declarer_terrains() -> void:
	for t in TERRAINS:
		var categories: Array = []
		for nom in t.get("dans", []):
			categories.append(_indices[nom])
		var type: int = _bt.TerrainType.CATEGORY if t.get("categorie", false) else _bt.TerrainType.MATCH_TILES
		if not _bt.add_terrain(_jeu, t["nom"], Color(t["couleur"]), type, categories):
			print("  ⚠ terrain « %s » refusé" % t["nom"])
			continue
		_indices[t["nom"]] = _bt.terrain_count(_jeu) - 1

	var posees := 0
	for p in PLEINES:
		var terrain: int = _indices[p[0]]
		var tous := {}
		for cle in VOISINS:
			tous[cle] = terrain
		if _poser(p[1], p[2], terrain, tous):
			posees += 1

	for e in ENSEMBLES:
		var dedans: int = _indices[e["terrain"]]
		var dehors: int = _indices[e["fond"]] if e["fond"] != "" else RIEN
		var nappe: bool = e.get("nappe", false)
		# ⚠ Une NAPPE a sa matière DEHORS : on échange simplement les deux rôles, la géométrie ne bouge pas.
		var interieur: int = dehors if nappe else dedans
		var exterieur: int = dedans if nappe else dehors
		var cadre: Vector2i = e["cadre"]
		for fy in 4:
			for fx in 4:
				var q := {
					"hg": interieur if fx >= 1 and fy >= 1 else exterieur,
					"hd": interieur if fx <= 2 and fy >= 1 else exterieur,
					"bg": interieur if fx >= 1 and fy <= 2 else exterieur,
					"bd": interieur if fx <= 2 and fy <= 2 else exterieur,
					"gauche": interieur if fx >= 1 else exterieur,
					"droite": interieur if fx <= 2 else exterieur,
					"haut": interieur if fy >= 1 else exterieur,
					"bas": interieur if fy <= 2 else exterieur,
				}
				if _poser(e["planche"], cadre + Vector2i(fx, fy), dedans, q):
					posees += 1
		var rentrants: Vector2i = e["rentrants"]
		if rentrants.x < 0:
			continue
		# Les COINS RENTRANTS : l'extérieur ne mord qu'un seul coin, celui tourné vers le centre du bloc ;
		# les quatre CÔTÉS, eux, restent de la matière — c'est ce qui fait un angle concave.
		for cy in 2:
			for cx in 2:
				var q := {
					"hg": exterieur if cx == 1 and cy == 1 else interieur,
					"hd": exterieur if cx == 0 and cy == 1 else interieur,
					"bg": exterieur if cx == 1 and cy == 0 else interieur,
					"bd": exterieur if cx == 0 and cy == 0 else interieur,
					"gauche": interieur, "droite": interieur, "haut": interieur, "bas": interieur,
				}
				if _poser(e["planche"], rentrants + Vector2i(cx, cy), dedans, q):
					posees += 1
	print("  terrains : %s" % str(_indices))
	print("  %d tuiles raccordables (Better Terrain, huit voisinages)" % posees)


## Déclare une tuile : son terrain, puis ce qu'elle attend de chacun de ses huit voisins.
## ⚠ Une case absente n'est pas une faute quand tous ses voisinages sont identiques : c'est le centre
## transparent d'un cadre, qu'une tuile PLEINE remplace déjà.
## ⚠ `symetrique` — ESSAYÉ, ET RETIRÉ. Better Terrain sait retourner et pivoter une tuile en recalculant
## ses voisinages, ce qui multiplierait la couverture sans dessiner une tuile de plus. Appliqué aux
## bordures de ce lot, le résultat est PIRE : leurs motifs ont un haut et un bas (la berge est éclairée
## par le dessus), donc les formes pivotées sortent des blocs de roche qui flottent dans l'herbe,
## détachés de l'eau. Le paramètre reste, avec sa leçon : il ne servira qu'à un motif sans orientation —
## un gravier, une mousse — jamais à une bordure dessinée.
func _poser(planche: String, case: Vector2i, terrain: int, quoi: Dictionary, symetrique: bool = false) -> bool:
	var source: TileSetAtlasSource = _sources[planche]["source"]
	if source.get_tile_at_coords(case) == Vector2i(-1, -1):
		var toutes_pareilles := true
		for cle in quoi:
			if quoi[cle] != quoi["hg"]:
				toutes_pareilles = false
		if not toutes_pareilles:
			print("  ⚠ terrain : la case %s de %s n'existe pas" % [case, planche])
		return false
	var donnees := source.get_tile_data(case, 0)
	_bt.set_tile_terrain_type(_jeu, donnees, terrain)
	if symetrique:
		_bt.set_tile_symmetry_type(_jeu, donnees, _bt.SymmetryType.ALL)
	for cle in VOISINS:
		if quoi[cle] != RIEN:
			_bt.add_tile_peering_type(_jeu, donnees, VOISINS[cle], quoi[cle])
	return true


# ── les planches de contrôle ────────────────────────────────────────────────────────────────────────

func _ecrire_planche() -> void:
	var lignes := ceili(float(_ordre.size()) / PAR_LIGNE) + _hauteur_des_blocs() + ceili(float(CANDIDATS.size()) / PAR_LIGNE)
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
		var coin := Vector2i(i % PAR_LIGNE, i / PAR_LIGNE) * (COTE + 2) + Vector2i(1, 1)
		image.blend_rect(atlas, Rect2i((entree["case"] as Vector2i) * COTE, Vector2i(COTE, COTE)), coin)
		if entree["mur"]:
			image.fill_rect(Rect2i(coin, Vector2i(COTE, 2)), Color(0.9, 0.2, 0.2))

	var y_bloc := ceili(float(_ordre.size()) / PAR_LIGNE) * (COTE + 2)
	var x_bloc := 1
	for b in BLOCS:
		var taille: Vector2i = b[3]
		var atlas: Image = (_sources[b[1]]["texture"] as Texture2D).get_image()
		for y in taille.y:
			for x in taille.x:
				image.blend_rect(atlas, Rect2i(((b[2] as Vector2i) + Vector2i(x, y)) * COTE, Vector2i(COTE, COTE)),
					Vector2i(x_bloc + x * COTE, y_bloc + y * COTE))
		x_bloc += taille.x * COTE + 8

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


func _hauteur_des_blocs() -> int:
	var maximum := 0
	for b in BLOCS:
		maximum = maxi(maximum, (b[3] as Vector2i).y)
	return maximum


## ⚠ LA PLANCHE DES TERRAINS — celle qui dit ce que j'ai DÉCLARÉ, pas ce que je crois avoir déclaré.
## Chaque tuile raccordable y paraît avec HUIT pastilles : quatre aux coins, quatre au milieu des bords,
## de la couleur du terrain attendu de ce côté-là. Une pastille qui contredit le dessin, c'est une règle
## fausse — et c'est la seule façon de le voir sans peindre une carte entière.
func _ecrire_planche_terrains() -> void:
	var places := {
		"hg": Vector2i(2, 2), "hd": Vector2i(COTE - 8, 2),
		"bg": Vector2i(2, COTE - 8), "bd": Vector2i(COTE - 8, COTE - 8),
		"gauche": Vector2i(2, COTE / 2 - 3), "droite": Vector2i(COTE - 8, COTE / 2 - 3),
		"haut": Vector2i(COTE / 2 - 3, 2), "bas": Vector2i(COTE / 2 - 3, COTE - 8),
	}
	var couleurs := [Color(0.45, 0.45, 0.5)]
	for i in _bt.terrain_count(_jeu):
		couleurs.append(_bt.get_terrain(_jeu, i).color)

	var cases: Array = []
	for cle in _sources:
		var source: TileSetAtlasSource = _sources[cle]["source"]
		for k in source.get_tiles_count():
			var case := source.get_tile_id(k)
			var donnees := source.get_tile_data(case, 0)
			if _bt.get_tile_terrain_type(donnees) >= 0:
				cases.append({"planche": cle, "case": case, "donnees": donnees})
	if cases.is_empty():
		return

	var lignes := ceili(float(cases.size()) / PAR_LIGNE)
	var image := Image.create_empty(PAR_LIGNE * (COTE + 2), lignes * (COTE + 2), false, Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			image.set_pixel(x, y, Color(0.1, 0.1, 0.12) if (x / 8 + y / 8) % 2 == 0 else Color(0.18, 0.18, 0.22))
	for i in cases.size():
		var e: Dictionary = cases[i]
		var donnees: TileData = e["donnees"]
		var atlas: Image = (_sources[e["planche"]]["texture"] as Texture2D).get_image()
		var coin := Vector2i(i % PAR_LIGNE, i / PAR_LIGNE) * (COTE + 2) + Vector2i(1, 1)
		image.blend_rect(atlas, Rect2i((e["case"] as Vector2i) * COTE, Vector2i(COTE, COTE)), coin)
		for cle in VOISINS:
			var types: Array = _bt.tile_peering_types(donnees, VOISINS[cle])
			var couleur: Color = couleurs[0] if types.is_empty() else couleurs[(types[0] as int) + 1]
			image.fill_rect(Rect2i(coin + (places[cle] as Vector2i), Vector2i(6, 6)), couleur)
	image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	image.save_png(PLANCHE_TERRAINS)
	print("planche des terrains : %s — %d tuiles raccordables" % [PLANCHE_TERRAINS, cases.size()])
