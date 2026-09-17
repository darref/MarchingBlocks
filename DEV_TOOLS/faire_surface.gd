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
	# ⚠ UN MOT, UNE CHOSE. Le rôle « herbe » désigne la tuile d'herbe CLAIRE ; le terrain porte donc le
	# même nom pour la même matière. Avoir appelé « herbe » la claire côté tuiles et la sombre côté
	# terrains, c'était préparer une carte peinte à l'envers sans qu'aucune erreur ne le signale.
	{"nom": "herbe", "couleur": "#7b9729", "dans": ["sol"]},
	{"nom": "herbe_sombre", "couleur": "#59842c", "dans": ["sol"]},
	{"nom": "terre", "couleur": "#81502f", "dans": ["sol"]},
	{"nom": "sable", "couleur": "#d7b876", "dans": ["sol"]},
	{"nom": "gravier", "couleur": "#a89a8b", "dans": ["sol"]},
	{"nom": "eau", "couleur": "#1d9488", "dans": []},
]

## Les tuiles PLEINES d'un terrain : [terrain, planche, [cases…]]. Tous leurs voisinages sont eux-mêmes.
##
## ⚠ PLUSIEURS CASES PAR MATIÈRE, et c'est encore une chose que le natif ne sait pas faire : Better
## Terrain tire au sort parmi les tuiles équivalentes, pondéré par `TileData.probability`. Un sol fait
## d'une seule tuile répétée se voit à l'œil dès qu'on recule — le damier saute aux yeux. La variation le
## casse sans qu'on dessine quoi que ce soit. La PREMIÈRE case reste dominante, les autres l'assaisonnent.
##
## ⚠ Ces cases ont été trouvées par MESURE (opaques, sans couture, sans contraste), pas choisies à l'œil.
const PLEINES := [
	["herbe", "sol", [Vector2i(10, 6), Vector2i(1, 9), Vector2i(2, 9), Vector2i(1, 10), Vector2i(2, 10)]],
	["herbe_sombre", "sol", [Vector2i(1, 21), Vector2i(2, 21), Vector2i(1, 22), Vector2i(2, 22)]],
	["terre", "sol", [Vector2i(1, 15), Vector2i(2, 15), Vector2i(1, 16), Vector2i(2, 16)]],
	["sable", "sol", [Vector2i(1, 27), Vector2i(2, 27), Vector2i(1, 28), Vector2i(2, 28)]],
	# ⚠ Le gravier n'a qu'une case : sa voisine (25, 2) est la « falaise », un MUR. Une variante doit
	# partager le `mur` de sa référence, sinon on sèmerait des murs invisibles dans une allée.
	["gravier", "sol", [Vector2i(24, 2)]],
	["eau", "eau", [Vector2i(9, 3), Vector2i(10, 3), Vector2i(9, 4), Vector2i(10, 4)]],
]
## Le poids d'une variante face à la case de référence, qui vaut 1.
const POIDS_VARIANTE := 0.4

## LES ENSEMBLES DE TRANSITION. Toujours la même géométrie : un cadre de 4 × 4, puis un bloc de 2 × 2
## pour les coins RENTRANTS (rentrants = (-1,-1) quand la planche n'en a pas).
##
## `terrain` est la matière de la tuile, `fond` ce qu'elle rencontre — le nom d'un terrain, d'une
## CATÉGORIE, ou "" pour « rien » (une bordure transparente, qui se pose donc sur un autre calque).
##
## ⚠ `matiere_dehors` dit que la matière est à l'EXTÉRIEUR du cadre et le fond au centre. C'est le cas
## des trois ensembles d'herbe : je les avais pris pour des découpeurs de trous, et j'inventais un calque
## de nappe pour les employer. Leur « trou » n'est pas « rien », c'est L'AUTRE HERBE — déclarés comme une
## transition herbe claire ↔ herbe sombre sur UN SEUL calque, ils redeviennent ce qu'ils sont.
const ENSEMBLES := [
	# ⚠ DEUX ensembles de terre, un par herbe. Le lot en range un qui borde l'herbe claire et un qui borde
	# la sombre ; n'avoir déclaré que le premier laissait 24 cases de frontière sur 36 sans tuile dès
	# qu'une route traversait une clairière — mesuré par DEV_TOOLS, pas deviné. Une matière ne se borde
	# pas « en général » : elle se borde CONTRE quelque chose, et le lot le sait avant nous.
	{"terrain": "terre", "fond": "herbe", "planche": "sol", "cadre": Vector2i(1, 1), "rentrants": Vector2i(3, 5)},
	{"terrain": "terre", "fond": "herbe_sombre", "planche": "sol", "cadre": Vector2i(5, 1), "rentrants": Vector2i(7, 5)},
	{"terrain": "gravier", "fond": "", "planche": "sol", "cadre": Vector2i(23, 1), "rentrants": Vector2i(25, 5)},
	{"terrain": "sable", "fond": "", "planche": "sol", "cadre": Vector2i(27, 1), "rentrants": Vector2i(29, 5)},
	# ⚠ Son fond est « rien », et ce n'est pas un aveu d'ignorance : ses bordures sont AJOURÉES, donc ce
	# qu'on voit par leurs trous est le calque du DESSOUS. Essayé de la déclarer contre « herbe_sombre »
	# sur un seul calque : clairières en escalier et blocs sombres au bord du lac (charte §6).
	{"terrain": "herbe", "fond": "", "planche": "sol", "cadre": Vector2i(10, 1), "rentrants": Vector2i(12, 5), "matiere_dehors": true},
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
	# ⚠ AVANT de bâtir les sources : cette planche-là est FABRIQUÉE, et il faut qu'elle existe sur disque
	# pour être chargée comme texture. Au tout premier lancement elle n'est pas encore importée — le
	# message ci-dessous le dira, il suffit de relancer après un « --import ».
	_fabriquer_le_sable()
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
	toutes["massif_sable"] = MASSIF_SABLE_PNG
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
	# ⚠ SUR « toutes », PAS SUR « PLANCHES ». La planche fabriquée du sable est une source comme les
	# autres, et c'est ici que les tuiles d'une source sont CRÉÉES. Bouclée sur PLANCHES, elle restait une
	# source sans une seule tuile : `get_tile_at_coords()` rendait −1, tout était sauté, et le massif de
	# sable sortait à zéro tuile SANS UNE ERREUR.
	for cle in toutes:
		_declarer_le_reste(cle)

	_declarer_terrains()
	_declarer_massifs()

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


## ⚠ `dans_la_planche` — la planche de contrôle existe pour retrouver une tuile PAR SON RÔLE. Y verser les
## quatre-vingt-douze cases d'escalier y enterrait l'herbe, l'eau et les arbres sous des fragments. Les
## escaliers gardent leur nom (le chargeur en aura besoin pour reconnaître un passage) mais sortent de la
## grille des rôles, comme les cases d'un arbre, qui ont leur bande à part.
func _declarer(planche: String, case: Vector2i, nom: String, mur: bool, objet: String,
		dans_la_planche: bool = true) -> void:
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
	# ⚠ `objet` va dans la légende : c'est la donnée qui décide si une tuile peinte devient un objet du
	# jeu (aujourd'hui l'entrée, et elle seule). L'oublier ici rendait la colonne vide pour TOUT le lot,
	# y compris pour « entree » — une légende qui ment par omission sur la seule tuile qui compte.
	if dans_la_planche:
		_ordre.append({"nom": nom, "planche": planche, "case": case, "mur": mur, "objet": objet})


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

## LES MASSIFS — les plateaux et leurs falaises. Une famille par matière, six lignes chacune.
## ⚠ MESURÉ, et c'est ce qui a décidé de tout : les trois familles sont le MÊME jeu à un décalage près
## (114 cases chacune, zéro case en propre, 405 px d'écart de forme sur 116 736). On dérive donc les
## signatures UNE SEULE FOIS sur l'herbe claire — où le vert et le brun se séparent proprement — et on
## les réutilise telles quelles pour la terre et l'herbe sombre. Classer la famille brune serait
## impossible : sa matière EST brune, comme sa roche.
## ⚠ LE SABLE N'EST PAS ICI. Il n'a aucune bande de falaise (65 cases contre 114) : une dune n'a pas de
## paroi verticale. Il reste un recouvrement à plat, qui marche déjà à 0 % de repli.
const MASSIFS := [
	{"nom": "massif_herbe", "planche": "sol", "y": 8, "couleur": "#7b9729"},
	{"nom": "massif_terre", "planche": "sol", "y": 14, "couleur": "#81502f"},
	{"nom": "massif_herbe_sombre", "planche": "sol", "y": 20, "couleur": "#59842c"},
	# ⚠ LE SABLE EST UNE PLANCHE FABRIQUÉE, PAS UNE PLANCHE DU LOT. Le lot n'en livre que 65 cases, sans
	# aucune bande de falaise : on le REPORTE depuis l'herbe claire par table de substitution (voir
	# `_fabriquer_le_sable`). Il vit donc à y = 0 de sa propre feuille, et non à y = 26 de FLOORS.
	{"nom": "massif_sable", "planche": "massif_sable", "y": 0, "couleur": "#d7b876"},
]

## LA TABLE DU REPORT. ⚠ La roche est COMMUNE aux quatre familles (onze bruns partagés, mesuré) : elle
## va à l'identité, pas un pixel touché. Seuls les verts se traduisent.
## ⚠ `#dfc57d` est FABRIQUÉ, en prolongeant la rampe du sable (#d7b876 → #cfab6f) d'un pas vers le haut :
## le sable n'a pas de rehaut. Importer le RAPPORT de l'herbe saturait le canal rouge à 255 et donnait un
## liseré criard — le contraste d'une matière ne se transpose pas à une autre, c'est sa rampe qui le dit.
## ⚠ `#22463d` est un vert-bleu d'ombre, ni herbe ni roche : il est versé vers une ombre sableuse.
const REPORT_SABLE := {
	"#7b9729": "#d7b876",  # le plat épinglé contre le plat, sans quoi tout glisse d'un cran
	"#95a631": "#dfc57d",  # le rehaut, fabriqué
	"#59842c": "#cfab6f",
	"#406a25": "#c59c5f",
	"#22463d": "#7d5336",
}
## La rampe du sable, du plus clair au plus sombre, et ses luminosités de coupure. ⚠ Elle sert de FILET :
## les teintes rares passent sous le seuil d'un relevé de palette et n'entrent jamais dans une table
## écrite à la main — mesuré, vingt pixels verts y échappaient. Tout vert survivant y est reversé.
const RAMPE_SABLE := ["#dfc57d", "#d7b876", "#cfab6f", "#c59c5f", "#7d5336"]
const RAMPE_BORNES := [0.70, 0.62, 0.52, 0.40]
const MASSIF_SABLE_PNG := "res://ART/massif_sable.png"

## LES ESCALIERS — ce qui relie deux altitudes. ⚠ CE NE SONT PAS DES TERRAINS : un escalier n'est pas
## décidé par son voisinage mais par l'endroit où l'on veut monter. C'est une intention de niveau, donc un
## BLOC, posé à la main comme un arbre. Déclarés comme terrain, ils se faisaient choisir comme arêtes
## ordinaires et semaient des marches rayées au bord des plateaux (mesuré).
## [nom, colonne, ligne relative, taille] — MESURÉ par les joints : l'art est continu à l'intérieur d'une
## pièce (écart < 0,17) et franc entre deux (0,56).
const ESCALIERS := [
	["escalier_haut", 9, 4, Vector2i(3, 2)],   # monte de deux cases
	["escalier_bas", 12, 4, Vector2i(3, 1)],   # monte d'une seule
	["escalier_haut_b", 22, 4, Vector2i(3, 2)],
	["escalier_bas_b", 25, 4, Vector2i(3, 1)],
	["rampe_etroite", 7, 4, Vector2i(1, 2)],
	["rampe_etroite_b", 20, 4, Vector2i(1, 2)],
]
const MASSIF_REFERENCE := 8   # l'herbe claire : la seule famille qu'on classe
const MASSIF_LIGNES := 6
const MASSIF_ECHANTILLON := 8  # côté du carré lu à chaque coin
## Les teintes de MATIÈRE de la famille de référence ; tout le reste est de la roche.
const MASSIF_MATIERE := ["#7b9729", "#95a631", "#59842c", "#406a25", "#626c1e"]
## ⚠ Au-delà de cette colonne, les lignes +4 et +5 sont des ESCALIERS, pas du terrain. MESURÉ : déclarés
## comme terrain, Better Terrain les choisissait comme arêtes ordinaires — la couverture restait à 0 % de
## repli et le rendu aurait montré des marches rayées au bord d'un plateau. Une pièce posée « avec
## succès » peut n'avoir rien à faire là. Les escaliers se posent à la main, comme un arbre.
const MASSIF_DERNIERE_COLONNE_FALAISE := 3

## ⚠ CE QUE LES COINS NE VOIENT PAS. Une tuile dont les quatre coins sont de la matière peut avoir un
## centre TEXTURÉ — une marche d'escalier, une bande rayée. `MATCH_VERTICES` ne les distingue pas d'un
## aplat, et les sème alors au milieu des plateaux, où rien ne les attend.
##
## ⚠ IL N'Y A PAS DE SEUIL À CALIBRER : UNE SEULE TEINTE, OU PLUSIEURS. J'avais d'abord gardé les
## « presque-aplats » (90 à 94 % de couleur dominante) comme variantes pondérées, au nom du damier qu'une
## tuile unique répétée fabrique. La capture a répondu : ce ne sont pas des variations d'herbe, ce sont
## des MARQUES — 6 à 9 % de pixels étrangers chacune — et semées au hasard sous un plateau elles se
## lisent comme des saletés. C'est la réserve que la charte portait déjà : une variante ne CRÉE pas de la
## variété, elle la RÉVÈLE si le lot en a.
##
## ⚠ Et le seuil n'aurait de toute façon pas pu être commun : à formes identiques, les TEXTURES diffèrent
## (61,5 % des pixels entre herbe et terre). Mesuré, la coupure tombe à 90 % pour les herbes et à 87 %
## pour la terre — un seuil calibré sur l'une et appliqué à l'autre, c'est la faute des deux jeux de
## terre refaite. « Une seule couleur » ne se calibre pas.
##
## ⚠ Corollaire : des aplats d'une même et unique couleur sont interchangeables, donc les variantes
## pondérées n'ont aucun sens pour un intérieur de massif. Le damier qu'elles évitent n'existe pas ici.

## Les quatre coins d'une case, dans l'ordre hg, hd, bg, bd.
const MASSIF_COINS := ["hg", "hd", "bg", "bd"]


## Déclare les trois massifs en MATCH_VERTICES, avec un peering DÉRIVÉ DES PIXELS.
## ⚠ Aucune table de géométrie écrite à la main. Ce gabarit ne suit pas la convention « cadre 4×4 +
## rentrants 2×2 » des ensembles de sol — ses rentrants sont dispersés — et une table de seize lignes
## saisie à la main est exactement l'endroit où l'on se trompe d'une case sans jamais s'en apercevoir.
## MESURÉ : 0 % de repli sur six formes, dont l'anneau, le L, la croix et la bande d'une seule case —
## toutes celles qui avaient tué la rive du lac.
## Fabrique la planche du sable : les six lignes de l'herbe claire, recolorées par table.
## ⚠ CETTE IMAGE EST DÉRIVÉE, JAMAIS RETOUCHÉE À LA MAIN. La retoucher ferait deux descriptions du même
## dessin, et elles divergeraient au premier réglage de la table.
func _fabriquer_le_sable() -> void:
	var chemin: String = PLANCHES["sol"]
	var img := Image.load_from_file(chemin)
	if img == null:
		print("ÉCHEC — planche du sol illisible pour le report du sable : %s" % chemin)
		return
	img.convert(Image.FORMAT_RGBA8)
	var largeur := img.get_width() / COTE
	var feuille := Image.create_empty(largeur * COTE, MASSIF_LIGNES * COTE, false, Image.FORMAT_RGBA8)
	feuille.fill(Color(0, 0, 0, 0))
	var traduits := 0
	var rattrapes := 0
	for dy in MASSIF_LIGNES:
		for cx in largeur:
			for y in COTE:
				for x in COTE:
					var p := img.get_pixel(cx * COTE + x, (MASSIF_REFERENCE + dy) * COTE + y)
					if p.a < 0.02:
						continue
					var h := "#%02x%02x%02x" % [int(p.r * 255), int(p.g * 255), int(p.b * 255)]
					if REPORT_SABLE.has(h):
						feuille.set_pixel(cx * COTE + x, dy * COTE + y, Color(REPORT_SABLE[h]))
						traduits += 1
					elif p.g > p.r:
						feuille.set_pixel(cx * COTE + x, dy * COTE + y, Color(_dans_rampe_sable(p)))
						rattrapes += 1
					else:
						feuille.set_pixel(cx * COTE + x, dy * COTE + y, p)  # la roche, intacte
	var erreur := feuille.save_png(MASSIF_SABLE_PNG)
	print("report du sable : %s (%s) — %d px traduits, %d rattrapés par la rampe"
		% [MASSIF_SABLE_PNG, "écrite" if erreur == OK else "ÉCHEC", traduits, rattrapes])


func _dans_rampe_sable(p: Color) -> String:
	var l := 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b
	for i in RAMPE_BORNES.size():
		if l >= RAMPE_BORNES[i]:
			return RAMPE_SABLE[i]
	return RAMPE_SABLE[RAMPE_SABLE.size() - 1]


func _declarer_massifs() -> void:
	# ⚠ LES SIGNATURES SE DÉRIVENT SUR LA RÉFÉRENCE, LES TUILES VIENNENT DE CHAQUE FAMILLE. Les formes
	# coïncident (405 px d'écart sur 116 736), donc un seul relevé sert aux quatre ; mais chacune a sa
	# planche et son décalage, et le sable a même une feuille à lui. Coder « sol » en dur ici déclarerait
	# le sable sur le haut de FLOORS — les bonnes signatures sur les mauvaises tuiles, sans une erreur.
	var source: TileSetAtlasSource = _sources["sol"]["source"]
	var image: Image = (_sources["sol"]["texture"] as Texture2D).get_image()
	# ⚠ Une texture importée rend souvent une image COMPRESSÉE, sur laquelle `get_pixel` ne dit pas la
	# vérité. Les scripts de mesure lisaient le PNG en direct et ne rencontraient pas le cas ; ici on lit
	# la texture du TileSet, donc on remet l'image à plat avant de la croire.
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var largeur := image.get_width() / COTE

	var signatures := {}  # colonne, ligne relative -> "MMRR"
	for dy in MASSIF_LIGNES:
		for cx in largeur:
			# ⚠ LES RANGÉES +4 ET +5 NE SONT PAS DU TERRAIN. Ce sont la FALAISE (x0..3) et les escaliers
			# (au-delà), et ni l'une ni les autres ne se choisissent par voisinage. J'avais mis la paroi
			# DANS le terrain du massif et laissé Better Terrain la placer : elle se peignait alors sur la
			# dernière rangée du plateau au lieu de PENDRE en dessous. La falaise se dérive (comme la
			# plage se dérive du lac), elle ne se raccorde pas.
			if dy >= 4:
				continue
			var s := _signature_massif(image, cx, MASSIF_REFERENCE + dy)
			if s == "" or s.contains("V"):
				continue  # bordure ajourée ou case vide : pas une tuile de terrain
			signatures[Vector2i(cx, dy)] = s

	for famille in MASSIFS:
		var planche: String = famille["planche"]
		if not _sources.has(planche):
			print("  ⚠ massif « %s » : planche « %s » absente — le report du sable a-t-il été importé ?"
				% [famille["nom"], planche])
			continue
		var src: TileSetAtlasSource = _sources[planche]["source"]
		var img: Image = (_sources[planche]["texture"] as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		_declarer_escaliers(planche, src, famille)
		_declarer_falaises(planche, src, famille)
		if not _bt.add_terrain(_jeu, famille["nom"], Color(famille["couleur"]),
				_bt.TerrainType.MATCH_VERTICES, []):
			print("  ⚠ massif « %s » refusé" % famille["nom"])
			continue
		var terrain: int = _bt.terrain_count(_jeu) - 1
		_indices[famille["nom"]] = terrain
		var posees := 0
		var murs := 0
		var ecartees := 0
		for cle in signatures:
			var case := Vector2i(cle.x, famille["y"] + cle.y)
			if src.get_tile_at_coords(case) == Vector2i(-1, -1):
				continue
			var s: String = signatures[cle]
			# ⚠ Les quatre CÔTÉS restent à RIEN : c'est ce qui fait du MATCH_VERTICES et non du
			# MATCH_TILES. `_poser` saute les voisins à RIEN, donc rien d'autre à changer.
			# ⚠ MATCH_VERTICES NE REGARDE QUE LES COINS, et c'est un piège que mes mesures ne voyaient pas :
			# une marche d'escalier dont les quatre coins sont de l'herbe est, pour lui, un aplat d'herbe.
			# Déclarées telles quelles, ces tuiles se faisaient tirer au sort pour l'INTÉRIEUR des plateaux
			# et le semaient de fragments rayés. « 0 % de repli » restait vrai et ne disait rien — ces
			# cases SONT des pleines, simplement hideuses. Il faut donc mesurer ce que les coins ignorent :
			# l'uniformité du centre. MESURÉ, et la frontière est un SAUT du lot, pas un seuil choisi :
			# cinq cases à 100 %, quatre entre 90 et 94 %, puis plus rien avant 80 %.
			# Une tuile d'intérieur doit être UNIE. Tout le reste appartient aux bords.
			if s == "MMMM" and _uniformite(img, case) < 100.0:
				ecartees += 1
				continue
			var quoi := {"gauche": RIEN, "droite": RIEN, "haut": RIEN, "bas": RIEN}
			for i in 4:
				quoi[MASSIF_COINS[i]] = terrain if s[i] == "M" else RIEN
			if not _poser(planche, case, terrain, quoi):
				continue
			posees += 1
			# ⚠ AUCUN MUR DANS LE TERRAIN DU PLATEAU : ON MARCHE SUR TOUT LE 4 × 4 (Jordan, 17 septembre).
			# La roche ne vient plus d'ici mais de la falaise dérivée, qui pend SOUS le bord sud et bloque
			# le SOL. Le liseré du plateau est une lisière, pas une paroi.
		print("  massif « %-20s » : %d tuiles, %d de paroi (murs), %d écartée(s) car non unies"
			% [famille["nom"], posees, murs, ecartees])


## La signature des quatre coins d'une case, LUE DANS L'IMAGE : M matière, R roche, V vide.
## Rend "" si la case est entièrement transparente.
func _signature_massif(image: Image, cx: int, cy: int) -> String:
	var vue := false
	var s := ""
	for coin in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var ox: int = cx * COTE + (0 if coin.x == 0 else COTE - MASSIF_ECHANTILLON)
		var oy: int = cy * COTE + (0 if coin.y == 0 else COTE - MASSIF_ECHANTILLON)
		var matiere := 0
		var roche := 0
		var vide := 0
		for y in MASSIF_ECHANTILLON:
			for x in MASSIF_ECHANTILLON:
				var p := image.get_pixel(ox + x, oy + y)
				if p.a < 0.02:
					vide += 1
				elif "#%02x%02x%02x" % [int(p.r * 255), int(p.g * 255), int(p.b * 255)] in MASSIF_MATIERE:
					matiere += 1
					vue = true
				else:
					roche += 1
					vue = true
		if vide > matiere and vide > roche:
			s += "V"
		else:
			s += "M" if matiere >= roche else "R"
	return s if vue else ""


## LA FALAISE — ce qui PEND sous le bord sud d'un plateau. ⚠ CE N'EST PAS UN TERRAIN : elle ne se choisit
## pas par voisinage, elle se DÉRIVE, comme la plage se dérive du lac. `DEV_TOOLS/faire_zone.gd` la
## descend colonne par colonne sous chaque bord sud.
##
## ⚠ TROIS RÔLES, PAS QUATRE COLONNES : gauche, milieu, droite — et le lot livre DEUX milieux, que la
## mesure dit interchangeables dans les deux ordres et avec eux-mêmes (joints de 0,013 à 0,069, là où un
## joint franc entre deux pièces vaut 0,56). De quoi éviter une paroi qui se répète visiblement.
##
## ⚠ DEUX RANGÉES : le MILIEU se répète autant que la falaise est haute, le PIED se pose en bas — c'est
## lui qui porte le bord érodé et le liseré sombre au contact du sol.
##
## ⚠ `mur = true` : une paroi arrête les pieds ET la lumière, une seule donnée pour les deux (charte §6).
const FALAISES := [
	["gauche", 0], ["milieu_a", 1], ["milieu_b", 2], ["droite", 3],
]
const FALAISE_RANGEES := [["milieu", 4], ["pied", 5]]


func _declarer_falaises(planche: String, src: TileSetAtlasSource, famille: Dictionary) -> void:
	var poses := 0
	for rangee in FALAISE_RANGEES:
		for role in FALAISES:
			var case := Vector2i(role[1], famille["y"] + rangee[1])
			if src.get_tile_at_coords(case) == Vector2i(-1, -1):
				continue
			_declarer(planche, case, "%s_falaise_%s_%s" % [famille["nom"], role[0], rangee[0]], true, "", false)
			poses += 1
	if poses > 0:
		print("    falaise de « %s » : %d tuile(s) nommée(s), murées" % [famille["nom"], poses])


## Les escaliers d'une famille, nommés case par case. ⚠ `mur = false` : un escalier est un PASSAGE, c'est
## tout son objet. C'est par lui qu'on changera d'altitude, donc `CLIENT/niveau.gd` doit pouvoir le
## trouver par son NOM — d'où la déclaration, alors que ces cases sont déjà peignables comme anonymes.
func _declarer_escaliers(planche: String, src: TileSetAtlasSource, famille: Dictionary) -> void:
	var poses := 0
	for e in ESCALIERS:
		var taille: Vector2i = e[3]
		for y in taille.y:
			for x in taille.x:
				var case := Vector2i(e[1] + x, famille["y"] + e[2] + y)
				if src.get_tile_at_coords(case) == Vector2i(-1, -1):
					continue
				_declarer(planche, case, "%s_%s_%d_%d" % [famille["nom"], e[0], x, y], false, "", false)
				poses += 1
	if poses > 0:
		print("    escaliers de « %s » : %d cases nommées" % [famille["nom"], poses])


## La part de la couleur DOMINANTE dans une case, en pourcentage des pixels opaques. Un vrai aplat rend
## 100 ; une tuile texturée descend vite. ⚠ C'est la mesure que les coins ne savent pas faire, et la
## seule qui distingue un champ d'herbe d'une marche d'escalier posée dans un champ d'herbe.
func _uniformite(image: Image, case: Vector2i) -> float:
	var couleurs := {}
	var opaques := 0
	for y in COTE:
		for x in COTE:
			var p := image.get_pixel(case.x * COTE + x, case.y * COTE + y)
			if p.a < 0.02:
				continue
			opaques += 1
			var h := "#%02x%02x%02x" % [int(p.r * 255), int(p.g * 255), int(p.b * 255)]
			couleurs[h] = couleurs.get(h, 0) + 1
	if opaques == 0:
		return 0.0
	var dominante := 0
	for h in couleurs:
		dominante = maxi(dominante, couleurs[h])
	return 100.0 * dominante / opaques


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
	var variantes := 0
	for p in PLEINES:
		var terrain: int = _indices[p[0]]
		var tous := {}
		for cle in VOISINS:
			tous[cle] = terrain
		var cases: Array = p[2]
		var mur_de_reference := false
		for i in cases.size():
			if not _poser(p[1], cases[i], terrain, tous):
				continue
			posees += 1
			var donnees := (_sources[p[1]]["source"] as TileSetAtlasSource).get_tile_data(cases[i], 0)
			if i == 0:
				mur_de_reference = donnees.get_custom_data("mur")
				continue
			# ⚠ Une variante partage le `mur` de sa référence — sinon on sèmerait de l'eau où l'on marche,
			# ou des murs invisibles dans une allée — et pèse moins qu'elle, pour rester un assaisonnement.
			donnees.set_custom_data("mur", mur_de_reference)
			if mur_de_reference and donnees.get_collision_polygons_count(0) == 0:
				var demi := COTE / 2.0
				donnees.add_collision_polygon(0)
				donnees.set_collision_polygon_points(0, 0, PackedVector2Array([
					Vector2(-demi, -demi), Vector2(demi, -demi), Vector2(demi, demi), Vector2(-demi, demi)]))
			donnees.probability = POIDS_VARIANTE
			variantes += 1
	print("  variantes pondérées : %d (poids %.1f contre 1 pour la référence)" % [variantes, POIDS_VARIANTE])

	for e in ENSEMBLES:
		var dedans: int = _indices[e["terrain"]]
		var dehors: int = _indices[e["fond"]] if e["fond"] != "" else RIEN
		var matiere_dehors: bool = e.get("matiere_dehors", false)
		# ⚠ Matière à l'extérieur : on échange les deux rôles, la géométrie calculée ne bouge pas d'un iota.
		var interieur: int = dehors if matiere_dehors else dedans
		var exterieur: int = dedans if matiere_dehors else dehors
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
	_ecrire_legende()


## ⚠ LA LÉGENDE EST UN FICHIER TEXTE, ET CE N'EST PAS UN PIS-ALLER. On ne peut pas écrire les noms DANS
## l'image : `Image` ne sait pas dessiner du texte, et aucune police ne se rend en headless. Or une
## planche qui montre trente-quatre cases sans dire laquelle s'appelle comment oblige à les compter à la
## main — c'est exactement l'endroit où l'on se trompe d'une case sans s'en apercevoir. Le texte porte en
## plus ce que l'image ne peut pas : la case d'atlas et sa planche, pour retrouver la tuile dans l'éditeur.
func _ecrire_legende() -> void:
	var lignes: Array = []
	lignes.append("LÉGENDE DE %s" % PLANCHE)
	lignes.append("Ligne et colonne dans l'image ; « mur » porte un liseré rouge et arrête le joueur.")
	lignes.append("")
	lignes.append("%-4s %-18s %-8s %-10s %-5s %s" % ["#", "nom", "planche", "case", "mur", "objet"])
	for i in _ordre.size():
		var e: Dictionary = _ordre[i]
		lignes.append("%-4s %-18s %-8s %-10s %-5s %s" % [
			"%d,%d" % [i / PAR_LIGNE, i % PAR_LIGNE],
			e["nom"], e["planche"], str(e["case"]),
			"MUR" if e["mur"] else "", e.get("objet", "")])
	lignes.append("")
	lignes.append("BLOCS RECONSTITUÉS (sous la grille, de gauche à droite) — se peignent case par case :")
	for b in BLOCS:
		lignes.append("  %-18s %-8s coin %-10s taille %s   rangées murées : %s"
			% [b[0], b[1], str(b[2]), str(b[3]), str(b[4])])
	lignes.append("")
	lignes.append("CANDIDATS (dernière grille) — des cases dont je ne suis pas sûr, JAMAIS déclarées :")
	for c in CANDIDATS:
		lignes.append("  %-8s %s" % [c[0], str(c[1])])

	var chemin := PLANCHE.get_basename() + ".txt"
	var fichier := FileAccess.open(chemin, FileAccess.WRITE)
	if fichier == null:
		print("  ⚠ légende non écrite : %s" % chemin)
		return
	fichier.store_string("\n".join(lignes) + "\n")
	fichier.close()
	print("  légende : %s" % chemin)


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
