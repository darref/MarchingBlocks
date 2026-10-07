extends SceneTree
##
## PHOTOGRAPHIE LA BARRE DU GREFFON GODOT (`mb_toolbar.gd`), hors de l'éditeur, sur quatre états : Add
## (pinceau), Box (Hollow), une sélection avec une copie (Extrude ↑ ↓ face, Widen), et l'outil Plant sur un monde
## qui a son feuillage (le modèle, les trois modes, le pinceau). Thème par défaut de Godot, pas celui de
## l'éditeur : ça juge les icônes, les groupes et ce qui s'affiche, pas les couleurs exactes de l'éditeur.
##
## LANCEMENT (AVEC fenêtre — le headless ne rend rien)
##   godot --path D:/MarchingBlocks --script res://DEV_TOOLS/capture_barre_greffon.gd
## Écrit `ART/barre_greffon.png`.

const Barre := preload("res://addons/marchingblocks_paint/mb_toolbar.gd")
const Editeur := preload("res://addons/marchingblocks_paint/mb_editor.gd")
const World := preload("res://addons/marchingblocks_paint/mb_world.gd")
const FoliageNode := preload("res://addons/marchingblocks_paint/mb_foliage_node.gd")


func _initialize() -> void:
	root.size = Vector2i(1700, 200)
	var fond := ColorRect.new()
	fond.color = Color("#202225")
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(fond)
	var pile := VBoxContainer.new()
	pile.position = Vector2(8, 8)
	pile.add_theme_constant_override("separation", 12)
	root.add_child(pile)
	var etats := [["add", false], ["box", false], ["select", true], ["plant", false]]
	for e in etats:
		var ed: Node = Editeur.new()
		root.add_child(ed)
		ed.mode = e[0]
		if e[1]:
			ed.selection = {Vector3i.ZERO: true, Vector3i.ONE: true, Vector3i.RIGHT: true}
			ed.clipboard = [Vector3i.ZERO] as Array[Vector3i]
			ed.status = "Copied 3 cell(s)."
		if e[0] == "plant":
			# Un monde qui a son feuillage : une couche et, à côté, le nœud des plants et un modèle.
			var tenant := Node3D.new()
			root.add_child(tenant)
			var couche := Node3D.new()
			couche.set_script(World)
			tenant.add_child(couche)
			var fo := Node3D.new()
			fo.set_script(FoliageNode)
			fo.models = [{"id": 1, "name": "Oak", "mesh": null}]
			tenant.add_child(fo)
			ed.world = couche
			ed.status = "Plant — planted (12 plant(s))."
		var b: HBoxContainer = Barre.new()
		pile.add_child(b)
		b.set("editor", ed)
	_photo.call_deferred()


func _photo() -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://ART/barre_greffon.png")
	print("ART/barre_greffon.png écrite")
	quit(0)
