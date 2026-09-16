extends SceneTree
##
## LE TILESET DES GROTTES — la vue de côté, bâtie sur le lot acheté (Village Props) pour la roche, et
## sur deux tuiles que nous dessinons nous-mêmes.
##
## ⚠ POURQUOI DEUX TUILES GÉNÉRÉES. Le lot n'a pas de case « vide » : ses cases vides sont transparentes.
## Or dans une carte peinte, une case non peinte est un MUR (charte §6) — l'air d'une grotte doit donc
## être une vraie tuile. Et l'obscurité d'une grotte, comme le puits de lumière qui la perce, sont NOTRE
## choix, pas celui du lot. On les dessine, et on prend la roche chez lui.
##
## ⚠ LES RÔLES SONT DES NOMS. La carte demande « roche_pleine », « air », « sol_grotte » ; cette table
## est le seul endroit qui dise où ils se trouvent. Changer de lot, ce sera la réécrire — rien d'autre.
##
## ⚠ PLANCHE DE CONTRÔLE. `ART/planche_coupe.png` montre chaque rôle, les blocs reconstitués, puis une
## rangée de CANDIDATS : des cases qu'on hésite à prendre, affichées avec leurs coordonnées. On regarde,
## on tranche, on réécrit la table. Personne ne peint une zone entière sur un pari.
##
## LANCEMENT
##   godot --headless --path D:/UnderMend --script res://DEV_TOOLS/faire_coupe.gd

const PACK := "res://TILESOURCES/Pixel Art Platformer - Village Props v2.3.1/Textures/"
const SORTIE := "res://ART/coupe.tres"
const PLANCHE := "res://ART/planche_coupe.png"
const DESSINEES := "res://ART/coupe_dessinees.png"
const COTE := 32
const PAR_LIGNE := 8

const PLANCHES := {
	"roche": PACK + "TX Tileset Ground.png",
	"props": PACK + "TX Village Props.png",
}

## Ce que nous dessinons : l'obscurité d'une grotte, et le puits de lumière. Une par case de l'atlas
## « dessinees », dans cet ordre.
const NUIT := Color("#140f1e")
const OR := Color("#ebbb69")
const DESSINS := ["air", "puits"]

## Les rôles d'une case : [nom, planche, case, mur].
## ⚠ Les cases de roche PLEINE ont été trouvées par mesure (opaques, sans couture, sans contraste) ;
## les bords sont des paris, et c'est pour eux que la planche de contrôle existe.
const TUILES := [
	["roche_pleine", "roche", Vector2i(6, 12), true],
	["roche_sombre", "roche", Vector2i(1, 1), true],
	# ⚠ Ces deux-là visaient des bords de terrain, et le lot n'en a que des COIFFÉS D'HERBE : c'est un lot
	# de plateforme en extérieur. De l'herbe sous terre serait un contresens, donc sol et plafond sont de
	# la roche pleine — mesurée, pas choisie à l'œil. Les vrais bords viendront quand Jordan peindra.
	["sol_grotte", "roche", Vector2i(7, 11), true],
	["plafond", "roche", Vector2i(7, 13), true],
	["paroi_gauche", "roche", Vector2i(4, 12), true],
	["paroi_droite", "roche", Vector2i(8, 12), true],
]

## Des cases dont je ne suis pas sûr : elles ne sont PAS déclarées dans le tileset, elles ne font que
## s'afficher sur la planche, avec leurs coordonnées, pour que le choix suivant soit informé.
const CANDIDATS := [
	Vector2i(9, 4), Vector2i(10, 5), Vector2i(11, 5), Vector2i(9, 6), Vector2i(10, 6), Vector2i(12, 6),
	Vector2i(5, 9), Vector2i(6, 9), Vector2i(7, 9), Vector2i(5, 13), Vector2i(6, 15), Vector2i(7, 15),
	Vector2i(13, 4), Vector2i(14, 4), Vector2i(13, 8), Vector2i(14, 8), Vector2i(4, 4), Vector2i(4, 8),
]

var _jeu: TileSet
var _sources := {}
var _ordre: Array = []


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
		if not ResourceLoader.exists(toutes[cle]):
			print("ÉCHEC — planche absente ou non importée : %s" % toutes[cle])
			print("       lance « godot --headless --path D:/UnderMend --import » puis recommence.")
			quit(1)
			return
		var texture: Texture2D = load(toutes[cle])
		var source := TileSetAtlasSource.new()
		source.texture = texture
		source.texture_region_size = Vector2i(COTE, COTE)
		var id := _jeu.get_next_source_id()
		_jeu.add_source(source, id)  # ⚠ avant de créer la moindre tuile
		_sources[cle] = {"id": id, "source": source, "texture": texture}

	for i in DESSINS.size():
		_declarer("dessinees", Vector2i(i, 0), DESSINS[i], false, "")
	for t in TUILES:
		_declarer(t[1], t[2], t[0], t[3], "")

	# ⚠ TOUT LE LOT EST DÉCLARÉ, pas seulement les rôles. Sinon on ne pourrait peindre que les quelques
	# tuiles nommées ici, sur des planches qui en comptent des centaines. Les autres arrivent sans nom.
	# Ici, `mur` se déduit de l'OPACITÉ : dans un lot de roche, une case pleine est de la roche pleine.
	for cle in PLANCHES:
		_declarer_le_reste(cle)

	var erreur := ResourceSaver.save(_jeu, SORTIE)
	if erreur != OK:
		print("ÉCHEC — écriture de %s (%d)" % [SORTIE, erreur])
		quit(1)
		return
	print("tileset de coupe écrit : %s — %d tuiles nommées" % [SORTIE, _ordre.size()])
	_ecrire_planche()
	quit(0)


## L'air et le puits : deux cases de 32, écrites dans ART/coupe_dessinees.png.
func _dessiner_les_notres() -> void:
	var image := Image.create_empty(DESSINS.size() * COTE, COTE, false, Image.FORMAT_RGBA8)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 20260916
	image.fill_rect(Rect2i(0, 0, COTE, COTE), NUIT)
	for n in 12:  # un grain à peine visible, pour que le noir ne soit pas plat
		image.set_pixelv(Vector2i(hasard.randi_range(0, COTE - 1), hasard.randi_range(0, COTE - 1)), NUIT.lightened(0.08))
	for y in COTE:  # le puits : l'or s'éteint vers le bas
		var force := 1.0 - float(y) / COTE
		image.fill_rect(Rect2i(COTE + 8, y, 16, 1), NUIT.lerp(OR, force * 0.85))
		image.fill_rect(Rect2i(COTE, y, 8, 1), NUIT)
		image.fill_rect(Rect2i(COTE + 24, y, 8, 1), NUIT)
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


## Les cases du lot qu'aucun rôle n'a prises : déclarées sans nom, pour qu'on puisse les peindre.
## ⚠ Une case entièrement transparente est ignorée : ce n'est pas une tuile, c'est un trou dans la planche.
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
			var opacite := _opacite(image, case)
			if opacite < 0.02:
				continue
			source.create_tile(case)
			var donnees := source.get_tile_data(case, 0)
			donnees.set_custom_data("nom", "")
			donnees.set_custom_data("mur", opacite > 0.98)
			donnees.set_custom_data("objet", "")
			if opacite > 0.98:
				var demi := COTE / 2.0
				donnees.add_collision_polygon(0)
				donnees.set_collision_polygon_points(0, 0, PackedVector2Array([
					Vector2(-demi, -demi), Vector2(demi, -demi), Vector2(demi, demi), Vector2(-demi, demi)]))
			ajoutees += 1
	print("  %s : %d cases anonymes ajoutées (murées si pleines)" % [planche, ajoutees])


func _opacite(image: Image, case: Vector2i) -> float:
	var n := 0
	for y in range(case.y * COTE, case.y * COTE + COTE, 2):
		for x in range(case.x * COTE, case.x * COTE + COTE, 2):
			if image.get_pixel(x, y).a > 0.5:
				n += 1
	return float(n) / ((COTE / 2) * (COTE / 2))


func _ecrire_planche() -> void:
	var lignes_roles := ceili(float(_ordre.size()) / PAR_LIGNE)
	var lignes_candidats := ceili(float(CANDIDATS.size()) / PAR_LIGNE)
	var image := Image.create_empty(PAR_LIGNE * (COTE + 2), (lignes_roles + lignes_candidats + 1) * (COTE + 2), false, Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			image.set_pixel(x, y, Color(0.1, 0.1, 0.12) if (x / 8 + y / 8) % 2 == 0 else Color(0.18, 0.18, 0.22))
	for i in _ordre.size():
		var entree: Dictionary = _ordre[i]
		var atlas: Image = (_sources[entree["planche"]]["texture"] as Texture2D).get_image()
		var coin := Vector2i(i % PAR_LIGNE, i / PAR_LIGNE) * (COTE + 2) + Vector2i(1, 1)
		image.blend_rect(atlas, Rect2i(entree["case"] * COTE, Vector2i(COTE, COTE)), coin)
		if entree["mur"]:
			image.fill_rect(Rect2i(coin, Vector2i(COTE, 2)), Color(0.9, 0.2, 0.2))
	var atlas_roche: Image = (_sources["roche"]["texture"] as Texture2D).get_image()
	for i in CANDIDATS.size():
		var coin := Vector2i(i % PAR_LIGNE, lignes_roles + 1 + i / PAR_LIGNE) * (COTE + 2) + Vector2i(1, 1)
		image.blend_rect(atlas_roche, Rect2i(CANDIDATS[i] * COTE, Vector2i(COTE, COTE)), coin)
	image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	image.save_png(PLANCHE)

	print("planche de contrôle : %s — %d rôles puis %d candidats, %d par ligne" % [
		PLANCHE, _ordre.size(), CANDIDATS.size(), PAR_LIGNE])
	var ligne := ""
	for i in _ordre.size():
		ligne += "%s  " % _ordre[i]["nom"]
		if i % PAR_LIGNE == PAR_LIGNE - 1:
			print("    " + ligne)
			ligne = ""
	if ligne != "":
		print("    " + ligne)
	print("    (une ligne vide, puis les candidats :)")
	ligne = ""
	for i in CANDIDATS.size():
		ligne += "%s  " % CANDIDATS[i]
		if i % PAR_LIGNE == PAR_LIGNE - 1:
			print("    " + ligne)
			ligne = ""
	if ligne != "":
		print("    " + ligne)
