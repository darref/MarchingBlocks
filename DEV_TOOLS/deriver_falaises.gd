extends SceneTree
## DÉRIVER LES FALAISES D'UN CALQUE « Massifs » DÉJÀ PEINT.
##
## ⚠ UNE FALAISE N'EST PAS UN TERRAIN. Elle ne se choisit pas par voisinage, elle se DÉDUIT du bord qu'elle
## prolonge — comme la plage se déduit du lac (`_est_plage`). Better Terrain n'écrit jamais dans une case
## qu'on ne lui a pas donnée : peindre un plateau ne peut donc pas créer sa paroi. C'est à cet outil de le
## faire, après coup, sur ce que le peintre a posé.
##
## LANCEMENT
##   godot --headless --path D:/UnderMend --script res://DEV_TOOLS/deriver_falaises.gd -- --zone=res://NIVEAUX/ma_zone.tscn
##   … puis la même chose avec « --ecrire » pour enregistrer.
##
## ⚠ IL NE TOUCHE RIEN SANS « --ecrire ». Par défaut il dit ce qu'il ferait. C'est le fichier de quelqu'un.
## ⚠ IL N'A PAS DE ZONE PAR DÉFAUT : le chemin est obligatoire, pour qu'on ne modifie jamais une carte
## par simple distraction.
##
## TROIS NATURES SUR LE MÊME CALQUE, et c'est ce qui rend l'outil RELANÇABLE :
##   tuile nommée « …_falaise_… »              une paroi DÉRIVÉE — on l'efface et on la refait
##   tuile nommée « …_escalier_… » / « …_rampe_… »  posée par le peintre — on n'y touche JAMAIS
##   tuile anonyme portant un terrain            le PLATEAU
## Sans cette distinction, un second passage prendrait ses propres parois pour du plateau et en dériverait
## d'autres en dessous, indéfiniment.

const TILESET := "res://ART/surface.tres"
const BETTER_TERRAIN := "res://addons/better-terrain/BetterTerrain.gd"
## ⚠ LA RÈGLE, PARTAGÉE. Cet outil ne la contient pas : il l'applique. Une seule description, trois
## appelants — le générateur de zone, cette commande, et le bouton de l'éditeur.
const Falaises := preload("res://DEV_TOOLS/falaises.gd")

var _bt
var _noms := {}


func _initialize() -> void:
	var chemin := ""
	var ecrire := false
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--zone="):
			chemin = option.substr("--zone=".length())
		elif option == "--ecrire":
			ecrire = true
	if chemin == "":
		print("Usage : --zone=res://NIVEAUX/ma_zone.tscn [--ecrire]")
		print("  Sans --ecrire, rien n'est enregistré : l'outil dit seulement ce qu'il ferait.")
		quit(1)
		return
	if not ResourceLoader.exists(chemin):
		print("ZONE INTROUVABLE : %s" % chemin)
		quit(1)
		return

	_bt = load(BETTER_TERRAIN).new()
	root.add_child(_bt)
	var jeu: TileSet = load(TILESET)
	_noms = _nommer(jeu)

	var paquet := load(chemin) as PackedScene
	var zone := paquet.instantiate()
	root.add_child(zone)
	var massifs := zone.get_node_or_null("Surface/Massifs") as TileMapLayer
	if massifs == null:
		print("« %s » n'a pas de calque « Surface/Massifs »." % chemin)
		print("  Ajoute un TileMapLayer nommé exactement Massifs, avec %s," % TILESET)
		print("  entre Recouvrement et Props, et peins-y un massif.")
		quit(1)
		return

	# 1. Trier ce qui est déjà là.
	var plateau := {}   # case -> nom du terrain (la famille)
	var marches := {}
	var anciennes: Array = []
	var sans_terrain := 0
	for pos in massifs.get_used_cells():
		var d := massifs.get_cell_tile_data(pos)
		if d == null:
			continue
		var nom: String = d.get_custom_data("nom")
		if "falaise" in nom:
			anciennes.append(pos)
			continue
		if "escalier" in nom or "rampe" in nom:
			marches[pos] = true
			continue
		# ⚠ TYPE EXPLICITE : `_bt` est chargé par `load()`, donc ses retours n'ont pas de type et `:=` n'a
		# rien à inférer. Faute consignée le matin dans `CLIENT/niveau.gd`, refaite trois fois dans le
		# greybox, et encore ici : appeler une méthode d'un objet chargé dynamiquement puis affecter avec
		# `:=` est une forme à ne plus écrire.
		var t: int = _bt.get_cell(massifs, pos)
		if t < 0:
			sans_terrain += 1
			continue
		plateau[pos] = _bt.get_terrain(jeu, t)["name"]

	print("CALQUE « Massifs » de %s" % chemin)
	print("  plateau        : %d case(s)" % plateau.size())
	print("  escaliers      : %d case(s) — jamais touchées" % marches.size())
	print("  parois déjà là : %d case(s) — à refaire" % anciennes.size())
	if sans_terrain > 0:
		print("  ⚠ %d case(s) peintes sans terrain : ni plateau, ni paroi, ni escalier — ignorées" % sans_terrain)
	if plateau.is_empty():
		print("  rien à dériver.")
		quit(0)
		return

	# 2. Effacer les anciennes parois AVANT de dériver : sinon elles compteraient comme du décor à garder.
	for pos in anciennes:
		massifs.erase_cell(pos)

	# 3. Dériver, bord sud par bord sud. ⚠ LE CALCUL N'EST PLUS ICI : il vit dans `falaises.gd`, partagé
	# avec le générateur de zone et le bouton de l'éditeur. Cet outil ne fait que POSER ce qu'il rend.
	var posees := 0
	var manquantes := {}
	for p in Falaises.calculer(plateau, marches):
		var nom: String = p["nom"]
		if not _noms.has(nom):
			manquantes[nom] = manquantes.get(nom, 0) + 1
			continue
		massifs.set_cell(p["case"], _noms[nom]["source"], _noms[nom]["case"])
		posees += 1

	print("")
	print("  paroi dérivée : %d case(s)" % posees)
	for nom in manquantes:
		print("  ⚠ tuile absente du tileset : « %s » (%d fois)" % [nom, manquantes[nom]])

	if not ecrire:
		print("")
		print("RIEN N'A ÉTÉ ENREGISTRÉ. Relance avec « --ecrire » si c'est ce que tu veux.")
		quit(0)
		return

	var scene := PackedScene.new()
	if scene.pack(zone) != OK:
		print("ÉCHEC — impossible d'empaqueter la scène")
		quit(1)
		return
	var erreur := ResourceSaver.save(scene, chemin)
	print("")
	print("%s" % ("zone enregistrée : %s" % chemin if erreur == OK else "ÉCHEC — écriture (%d)" % erreur))
	quit(0 if erreur == OK else 1)


## nom -> {source, case}. ⚠ La MÊME table que `faire_zone.gd` : une seule autorité sur « où vit ce rôle ».
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
