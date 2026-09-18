@tool
extends EditorPlugin
## LE BOUTON « FALAISES » — dériver les parois sous les massifs peints, sans quitter l'éditeur.
##
## ⚠ CE PLUGIN EST LE NÔTRE, PAS UNE MODIFICATION DE BETTER TERRAIN. On se sert de cet addon comme d'une
## bibliothèque et on n'y touche jamais : un fork, c'est un conflit à chaque mise à jour amont. Le bouton
## vit donc ici, chez nous.
##
## ⚠ IL NE CONTIENT PAS LA RÈGLE. Le calcul vit dans `DEV_TOOLS/falaises.gd`, partagé avec le générateur
## de zone et l'outil en ligne de commande. Trois appelants, une seule description — c'est ce qui évite
## qu'elles divergent, ce qui était DÉJÀ arrivé entre les deux premières.
##
## ⚠ IL PASSE PAR L'HISTORIQUE D'ANNULATION. Un bouton qui réécrit des cases sans que Ctrl+Z les
## rattrape, c'est une peinture qu'un clic malheureux abîme sans retour.
##
## CE QU'IL FAIT, sur le calque « Surface/Massifs » de la scène ouverte :
##   tuile nommée « …_falaise_… »                 une paroi déjà dérivée — effacée, puis refaite
##   tuile nommée « …_escalier_… » / « …_rampe_… »  posée par le peintre — jamais touchée
##   tuile anonyme portant un terrain               le PLATEAU, d'où la paroi se déduit

const Falaises := preload("res://DEV_TOOLS/falaises.gd")
const TILESET := "res://ART/surface.tres"
const BETTER_TERRAIN := "res://addons/better-terrain/BetterTerrain.gd"

var _bouton: Button
var _hauteur: SpinBox


func _enter_tree() -> void:
	# ⚠ La hauteur est le nombre de rangées de MILIEU ; le pied s'ajoute toujours dessous. 1 donne la
	# falaise de deux rangées. Le milieu s'empile proprement sur lui-même — mesuré, joint vertical de
	# 0,043 contre 0,45 pour un empilement impossible.
	_hauteur = SpinBox.new()
	_hauteur.min_value = 1
	_hauteur.max_value = 8
	_hauteur.value = 1
	_hauteur.prefix = "étages "
	_hauteur.tooltip_text = "Rangées de milieu sous le bord sud ; le pied s'ajoute dessous"
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, _hauteur)

	_bouton = Button.new()
	_bouton.text = "Falaises"
	_bouton.tooltip_text = "Dériver les parois sous le bord sud des massifs peints (Surface/Massifs)"
	_bouton.pressed.connect(_deriver)
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, _bouton)


func _exit_tree() -> void:
	if _bouton != null:
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, _bouton)
		_bouton.queue_free()
		_bouton = null
	if _hauteur != null:
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, _hauteur)
		_hauteur.queue_free()
		_hauteur = null


func _deriver() -> void:
	var racine := get_editor_interface().get_edited_scene_root()
	if racine == null:
		_dire("Aucune scène ouverte.")
		return
	var massifs := racine.get_node_or_null("Surface/Massifs") as TileMapLayer
	if massifs == null:
		_dire("Cette scène n'a pas de calque « Surface/Massifs ».\n\n"
			+ "Ajoute un TileMapLayer nommé exactement Massifs, avec " + TILESET + ",\n"
			+ "entre Recouvrement et Props, et peins-y un massif.")
		return
	if massifs.tile_set == null:
		_dire("Le calque « Massifs » n'a pas de TileSet.")
		return

	var bt = load(BETTER_TERRAIN).new()
	add_child(bt)
	var noms := _nommer(massifs.tile_set)

	# 1. Trier ce qui est déjà là, par le NOM de la tuile.
	var plateau := {}
	var marches := {}
	var anciennes: Array = []
	for pos in massifs.get_used_cells():
		var d := massifs.get_cell_tile_data(pos)
		if d == null:
			continue
		var nom: String = d.get_custom_data("nom")
		if "falaise" in nom:
			anciennes.append(pos)
		elif "escalier" in nom or "rampe" in nom:
			marches[pos] = true
		else:
			var t: int = bt.get_cell(massifs, pos)
			if t >= 0:
				plateau[pos] = bt.get_terrain(massifs.tile_set, t)["name"]
	bt.queue_free()

	if plateau.is_empty():
		_dire("Aucun massif peint sur « Massifs » : rien à dériver.")
		return

	var poses: Array = Falaises.calculer(plateau, marches, int(_hauteur.value))
	var manquantes := {}
	var retenues: Array = []
	for p in poses:
		if noms.has(p["nom"]):
			retenues.append(p)
		else:
			manquantes[p["nom"]] = true

	# 2. Appliquer, en passant par l'historique : un seul « Dériver les falaises » à annuler.
	var histoire := get_undo_redo()
	histoire.create_action("Dériver les falaises")
	for pos in anciennes:
		histoire.add_do_method(massifs, "erase_cell", pos)
		histoire.add_undo_method(massifs, "set_cell", pos,
			massifs.get_cell_source_id(pos), massifs.get_cell_atlas_coords(pos),
			massifs.get_cell_alternative_tile(pos))
	for p in retenues:
		var pos: Vector2i = p["case"]
		histoire.add_do_method(massifs, "set_cell", pos, noms[p["nom"]]["source"], noms[p["nom"]]["case"], 0)
		if massifs.get_cell_source_id(pos) == -1:
			histoire.add_undo_method(massifs, "erase_cell", pos)
		else:
			histoire.add_undo_method(massifs, "set_cell", pos,
				massifs.get_cell_source_id(pos), massifs.get_cell_atlas_coords(pos),
				massifs.get_cell_alternative_tile(pos))
	histoire.commit_action()

	var message := "Plateau : %d case(s)\nEscaliers épargnés : %d\nParois refaites : %d → %d" % [
		plateau.size(), marches.size(), anciennes.size(), retenues.size()]
	if not manquantes.is_empty():
		message += "\n\n⚠ Tuiles absentes du TileSet :\n  " + "\n  ".join(manquantes.keys())
	_dire(message)


## nom -> {source, case}. ⚠ La MÊME table que `faire_zone.gd` et `deriver_falaises.gd` : une seule
## autorité sur « où vit ce rôle » dans les planches.
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


func _dire(texte: String) -> void:
	var boite := AcceptDialog.new()
	boite.title = "Falaises"
	boite.dialog_text = texte
	get_editor_interface().get_base_control().add_child(boite)
	boite.popup_centered()
	boite.confirmed.connect(boite.queue_free)
	boite.canceled.connect(boite.queue_free)
