extends Control
## LE MODE D'EMPLOI — posé PAR-DESSUS le travail, ouvert d'un clic sur le bandeau des conseils (F1).
##
## ⚠ **REPRIS DE SOLUTILES (`ui/manual.gd`)**, et ses leçons avec lui :
##   • `set_anchors_and_offsets_preset`, pas `set_anchors_preset` : le second garde la taille courante,
##     qui vaut zéro à `_ready` — le panneau restait collé en haut à gauche, sans un mot ;
##   • pas tout l'écran : voir le monde dépasser derrière rappelle qu'on est posé dessus ;
##   • Échap ferme, parce que c'est le geste qu'on fait sans y penser.
## ⚠ **LES NOMBRES SE LISENT, ILS NE S'ÉCRIVENT PAS** : le compte de tuiles vient du modèle
## (`pieces_a_sculpter`, `exterieures_a_sculpter`), comme dans le reste de l'écran. Un manuel qui écrit
## « 52 » en dur mentira le jour où le monde change.
## ⚠ En ANGLAIS : un acheteur le lit (charte §7).

const Palette := preload("res://app/palette.gd")
const Icones := preload("res://app/icones.gd")
const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")

const PART := 0.84

var _onglets: TabContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# ⚠ SANS FOCUS, `grab_focus()` ne fait rien et Échap n'arrive jamais jusqu'ici.
	focus_mode = Control.FOCUS_ALL
	visible = false
	_batir()


func _batir() -> void:
	var voile := ColorRect.new()
	voile.color = Color(0.04, 0.045, 0.05, 0.78)
	voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	voile.mouse_filter = Control.MOUSE_FILTER_STOP
	voile.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			fermer())
	add_child(voile)

	var cadre := PanelContainer.new()
	cadre.anchor_left = 0.5 - PART * 0.5
	cadre.anchor_right = 0.5 + PART * 0.5
	cadre.anchor_top = 0.5 - PART * 0.5
	cadre.anchor_bottom = 0.5 + PART * 0.5
	var peau := Palette.fond(Palette.PANNEAU, 8, 20)
	peau.border_color = Palette.FILET
	peau.set_border_width_all(1)
	cadre.add_theme_stylebox_override("panel", peau)
	add_child(cadre)

	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 12)
	cadre.add_child(colonne)
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", 10)
	colonne.add_child(tete)
	var icone := TextureRect.new()
	icone.texture = Icones.icone("livre")
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.custom_minimum_size = Vector2(24, 24)
	icone.modulate = Palette.OLIVE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tete.add_child(icone)
	var titre := Label.new()
	titre.text = "MarchingBlocks — user guide"
	titre.add_theme_font_override("font", Palette.gras())
	titre.add_theme_font_size_override("font_size", 20)
	titre.add_theme_color_override("font_color", Palette.OLIVE)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tete.add_child(titre)
	var fermer_ := Button.new()
	fermer_.icon = Icones.icone("croix")
	fermer_.theme_type_variation = Palette.DISCRET
	fermer_.tooltip_text = "Close (Esc)"
	fermer_.pressed.connect(fermer)
	tete.add_child(fermer_)

	_onglets = TabContainer.new()
	_onglets.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colonne.add_child(_onglets)
	_page("1 · Getting started", _demarrer())
	_page("2 · Painting tools", _outils())
	_page("3 · Layers & projects", _couches())
	_page("4 · The artist round trip", _aller_retour())
	_page("5 · Shortcuts", _raccourcis())


func _page(nom: String, corps: String) -> void:
	var defile := ScrollContainer.new()
	defile.name = nom
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_onglets.add_child(defile)
	var marge := MarginContainer.new()
	for c in ["margin_left", "margin_right"]:
		marge.add_theme_constant_override(c, 22)
	for c in ["margin_top", "margin_bottom"]:
		marge.add_theme_constant_override(c, 16)
	marge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defile.add_child(marge)
	var texte := RichTextLabel.new()
	texte.bbcode_enabled = true
	texte.fit_content = true
	texte.selection_enabled = true
	texte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texte.add_theme_color_override("default_color", Palette.TEXTE)
	texte.add_theme_font_size_override("normal_font_size", 14)
	texte.add_theme_font_override("bold_font", Palette.gras())
	texte.add_theme_constant_override("line_separation", 4)
	texte.text = corps
	marge.add_child(texte)


func ouvrir(onglet := -1) -> void:
	if onglet >= 0:
		_onglets.current_tab = onglet
	visible = true
	move_to_front()
	grab_focus()


func fermer() -> void:
	visible = false


func _gui_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and (k.keycode == KEY_ESCAPE or k.keycode == KEY_F1):
		fermer()
		accept_event()


func _titre(texte: String) -> String:
	return "\n[font_size=17][color=#bbca83][b]%s[/b][/color][/font_size]\n" % texte


func _note(texte: String) -> String:
	return "[color=#96a096]%s[/color]" % texte


func _touche(k: String) -> String:
	return "[bgcolor=#2a2e32][color=#e0e0d9] %s [/color][/bgcolor]" % k


func _demarrer() -> String:
	var l := PackedStringArray()
	var dedans: int = MB.pieces_a_sculpter().size()
	var dehors: int = MB.exterieures_a_sculpter().size()
	l.append("[i]You sculpt one block. The software cuts every tile out of it, and paints worlds "
		+ "with them — no tile to place by hand.[/i]")
	l.append(_titre("1. Look at the witness"))
	l.append("The [b]Witness[/b] workspace shows the block your artist will sculpt. Its six colours are "
		+ "six families of tiles — floor, wall and ceiling, in open air or underground — and the legend "
		+ "on the left names them.")
	l.append(("It carries [b]%d tiles[/b]: %d classes, and %d of them again for the open air. That is "
		+ "a count, not a promise: the tests prove not one is missing.") % [dedans + dehors, dedans, dehors])
	l.append(_titre("2. Paint a test world"))
	l.append("Open [b]World[/b], and in [b]Slice into the active layer[/b] press "
		+ "[b]Slice the witness[/b]. The first time takes a few seconds; after that it is cached.")
	l.append("Then paint: [b]left click[/b] applies the tool, [b]right click[/b] does the opposite. "
		+ "Every stroke is undone by one " + _touche("Ctrl+Z") + ".")
	l.append(_titre("3. Bring your own art"))
	l.append("[b]Export the witness…[/b] writes one .obj for Blender. Sculpt it, export it as .glb, then "
		+ "[b]Import the work…[/b] to see it as the slicer will read it, and [b]Slice the work[/b] to "
		+ "paint with your own tiles. The painted world stays: only its tiles change.")
	l.append("Then open [b]Play test[/b] and walk it: " + _touche("Z Q S D") + " to move, "
		+ _touche("Space") + " to jump, " + _touche("Shift") + " to run, left drag to orbit the camera (right drag turns it level), "
		+ "the wheel to come closer. You walk on the tiles you see — a step too high or a tunnel too "
		+ "low shows here first. " + _touche("Esc") + " brings you back.")
	l.append(_note("A red cube is a tile your library does not have. Nothing is ever filled in for you: "
		+ "a hole must be seen where it happens."))
	l.append(_titre("4. Take it to your engine"))
	l.append("[b]Export the tileset…[/b] writes the active layer's tiles as a [b].mbset[/b] folder. The "
		+ "free [b]MarchingBlocks Paint[/b] plugins for Godot, Unity and Unreal read it: you paint cells "
		+ "in your engine, the tiles follow — exactly as here.")
	l.append(_note("The format is open, and the placement rule is written inside it. The tiles you make "
		+ "are yours."))
	return "\n".join(l)


func _outils() -> String:
	var l := PackedStringArray()
	l.append("[i]Two aims, the same tools. The aim only decides WHERE you point; the tool "
		+ "decides what happens there.[/i]")
	l.append(_titre("Aim — Grid or Sculpt  " + _touche("Tab")))
	l.append("[b]Grid[/b] aims at the floor plane, at height [b]floor y[/b] "
		+ "(" + _touche("PgUp") + " " + _touche("PgDn") + "). Good for laying out a map.")
	l.append("[b]Sculpt[/b] aims at the matter already there. [b]Add[/b] builds on the face you point "
		+ "at; [b]Dig[/b] and [b]Select[/b] act on the cell you point at. Where the ray meets nothing, "
		+ "it falls back on the floor plane — that is how the first cell of an empty world is placed.")
	l.append(_titre("Navigate  " + _touche("Space")))
	l.append("[b]Navigate[/b] is a switch, not an aim: " + _touche("Space") + " turns it on, "
		+ _touche("Space") + " again brings you back to your aim, untouched. You fly around your "
		+ "world: " + _touche("Z") + " " + _touche("S") + " forward and back, " + _touche("Q") + " "
		+ _touche("D") + " sideways, " + _touche("A") + " down, " + _touche("E") + " up (" + _touche("W")
		+ " " + _touche("S") + " " + _touche("A") + " " + _touche("D") + " " + _touche("Q") + " "
		+ _touche("E") + " on a QWERTY keyboard — the keys are read by their place), a right drag looks "
		+ "around. No click paints.")
	l.append(_note("The ray aims at the cells, not at the rendered tiles: a sculpted tile may spill "
		+ "half a cell out of its cell, the cell itself does not."))
	l.append(_titre("Tools"))
	l.append(_touche("A") + " [b]Add[/b] — adds matter. Add sees every visible layer, so you can build "
		+ "grass on another layer's rock.")
	l.append(_touche("D") + " [b]Dig[/b] — removes matter from the active layer.")
	l.append(_touche("S") + " [b]Select[/b] — paints a selection; " + _touche("Shift")
		+ " adds to it, right click removes.")
	l.append(_touche("B") + " [b]Box[/b] — drag a box: the matter inside becomes the selection. In "
		+ "Sculpt the corners sit on the matter, so the box is 3D.")
	l.append(_titre("Brush"))
	l.append("Size 1 to 7 (" + _touche("[") + " " + _touche("]") + "), and a shape: [b]sphere[/b], "
		+ "[b]cube[/b], or [b]disc[/b] — flat, across the face you point at, to fill or dig a wall "
		+ "without thickening it. The preview shows the exact cells the click will change: green adds, "
		+ "red digs, blue selects.")
	l.append(_note("While you drag Add, the cells you just placed are transparent to the ray: the "
		+ "stroke lays a skin on the surface instead of a tower towards you."))
	l.append(_titre("Selection"))
	l.append("[b]Delete[/b], [b]Extrude ↑ / ↓[/b] (the selection follows, repeat to raise a wall), "
		+ "[b]Grow[/b], [b]Shrink[/b], [b]Connected[/b]. The arrow keys move it, following the camera; "
		+ _touche("Shift") + " + up / down lifts it.")
	l.append(_touche("Ctrl+C") + " " + _touche("Ctrl+X") + " " + _touche("Ctrl+V") + " copy, cut and "
		+ "paste — into this layer or any other. The paste follows the mouse; click to place it.")
	l.append(_note("Moving or pasting onto matter merges with it; it never erases it."))
	l.append(_titre("Shape operations"))
	l.append("[b]Extend up / down[/b], [b]Widen[/b], [b]Hollow[/b] act on the selection if there is "
		+ "one, otherwise on the whole floor y.")
	return "\n".join(l)


func _couches() -> String:
	var l := PackedStringArray()
	l.append(_titre("Layers"))
	l.append("A layer is [b]one source of tiles[/b] — the computed witness, or one of your .glb works "
		+ "— and [b]its own painted cells[/b]. Its tiles only look at its own cells: a rock layer and an "
		+ "ice layer never bend each other.")
	l.append("You paint on the [b]active[/b] layer; the others stay visible (the eye hides one). "
		+ "Slicing a new work into a layer [b]keeps its painting[/b] — only the tiles change.")
	l.append(_titre("Projects"))
	l.append("A project ([b].mbproj[/b]) holds the layers, their cells and where their tiles come from. "
		+ "It [b]saves itself after every change[/b] and reopens when you come back. "
		+ "[b]Save as…[/b] puts it where you want; it keeps saving itself there.")
	l.append("The sliced tiles are cached. If the artist saved the .glb again, the layer is sliced "
		+ "again on opening; if the .glb is gone, you see the last tiles sliced from it, and the report "
		+ "says so.")
	return "\n".join(l)


func _aller_retour() -> String:
	var l := PackedStringArray()
	l.append(_titre("What the artist receives"))
	l.append("[b]One .obj[/b] (and its .mtl): the whole witness, at the origin, tiles already shrunk to "
		+ "half their cell to show the margin. [b]Fully welded[/b] — one vertex per position, the six "
		+ "families as six named materials — and flat-shaded in Blender. " + _touche("Alt+J")
		+ " (Tris to Quads) brings back the edge loops.")
	l.append("[b]Bring it back as .glb[/b] (File → Export → glTF 2.0): it carries your textures, UVs "
		+ "and materials. An .obj is accepted too. Moving or rotating the OBJECT is fine — what counts "
		+ "is where the block sits in the viewport.")
	l.append(_note("Why an .obj on the way out: in glTF every material is a separate primitive, and "
		+ "Blender shares no vertex between primitives — the witness would arrive cut along every "
		+ "colour border. OBJ faces share one vertex list, whatever their material."))
	l.append(_titre("The contract"))
	l.append("[b]Total freedom inside each cell.[/b] Relief may spill half a cell around the block.")
	l.append("[b]Do not move the block[/b]: its position identifies it when it comes back, not its name. "
		+ "(Blender's own axis conversion is taken into account: the block is read where you see it.)")
	l.append("[b]Do not change which cells are full[/b]: the filling fixes the tile classes.")
	l.append("[b]The seams are the artist's responsibility.[/b] The slicer cuts straight through the "
		+ "cell centres and judges nothing else — the report lists the seam remarks.")
	l.append(_titre("Proving the round trip"))
	l.append("[b]Paint the witness shape[/b] fills a layer with the witness's own cells. Slice your work "
		+ "into it: the result must give your block back.")
	l.append(_note("Every sculpted copy of a tile is kept, and the painter draws one by position. So the "
		+ "rebuilt block has the same shape and the same tiles, but a corner sculpted here may appear "
		+ "there: an atlas carries no unique detail."))
	return "\n".join(l)


func _raccourcis() -> String:
	var lignes := [
		["Tab", "Grid ↔ Sculpt"], ["Space", "Navigate on / off"], ["A Z E Q S D", "Fly (Navigate)"],
		["Right drag", "Look around (Navigate)"], ["A · D · S · R · B", "Add · Dig · Select · Rect · Box"],
		["[  ]", "Brush size"], ["PgUp · PgDn", "Floor y"],
		["Arrows", "Move the selection (follows the camera)"], ["Shift + ↑ ↓", "Lift / lower the selection"],
		["Del", "Delete the selection"], ["Esc", "Clear the selection · cancel a paste"],
		["Ctrl+C · X · V", "Copy · cut · paste"], ["Ctrl+Z · Ctrl+Y", "Undo · redo"],
		["Middle drag", "Turn the view"], ["Shift + middle drag", "Slide the view"], ["Wheel", "Zoom"],
		["F1", "This guide"],
	]
	var l := PackedStringArray()
	l.append("[table=2]")
	for r in lignes:
		l.append("[cell]%s   [/cell][cell]%s[/cell]" % [_touche(r[0]), r[1]])
	l.append("[/table]")
	return "\n".join(l)
