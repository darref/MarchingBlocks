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
	_page("4 · Modelling the witness", _modeleur())
	_page("5 · The artist round trip", _aller_retour())
	_page("6 · The same look in your engine", _rendu())
	_page("7 · Shortcuts", _raccourcis())


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
	l.append("[b]Export the witness…[/b] writes one .glb for Blender, every tile a linked copy. Sculpt it, export it as .glb, then "
		+ "[b]Import the work…[/b] to see it as the slicer will read it, and [b]Slice the work[/b] to "
		+ "paint with your own tiles. The painted world stays: only its tiles change.")
	l.append("Then open [b]Play test[/b] and walk it: " + _touche("Z Q S D") + " to move, "
		+ _touche("Space") + " to jump, " + _touche("Shift") + " to run, left drag to orbit the camera (right drag turns it level), "
		+ "the wheel to come closer, " + _touche("F") + " to fly over it (you still bump into the rock). The right-hand bar sets the "
		+ "lighting and the [b]weather[/b] (rain, blizzard, hurricane, snow, floating particles, heat, fog) — only "
		+ "to judge your world: the weather is never saved nor exported. In water you swim: " + _touche("Space") + " to rise, " + _touche("A") + " to dive ("
		+ _touche("Q") + " on QWERTY); swim into a bank to climb out. You walk on the tiles you see — a step too high or a tunnel too "
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
		+ "(" + _touche("PgUp") + " " + _touche("PgDn") + ", or " + _touche("Ctrl") + "+click on some "
		+ "matter to put the grid at its height). Good for laying out a map.")
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
	l.append("[b]Extend up / down[/b], [b]Widen[/b], [b]Hollow[/b], [b]Extend facing[/b] act on the "
		+ "selection if there is one, otherwise on the whole floor y.")
	l.append("[b]Extend facing[/b] extends away from the matter: it picks the direction most cells face "
		+ "(air in front, matter behind) and copies them one cell that way. The selection follows, so "
		+ "click again to keep going. Select a wall to thicken it, a cave ceiling to lower it.")
	l.append(_titre("Special shapes"))
	l.append("[b]Tunnel[/b] digs into a wall, [b]Well[/b] into a floor or a ceiling, [b]Bridge[/b] builds a "
		+ "deck across the air from a wall, [b]Balcony[/b] puts a slab with its rail against a wall, "
		+ "[b]Stairs[/b] climb a wall. Pick one, then click on the matter: the preview shows the exact cells, "
		+ "red to dig, green to add.")
	l.append("[b]Stairs[/b] — click a wall where the stairs should arrive: the top step is level with the "
		+ "cell you click, and they come down towards you, [b]Step[/b] cells deep per step, until they meet "
		+ "the ground (or [b]Length[/b] cells out). Each step is solid down to the ground; over the void, the "
		+ "flight is two cells thick. [b]Connect[/b]: click a floor, then another floor higher up — the stairs "
		+ "share the climb evenly between them, one cell up per cell across at most. Stairs only add matter: "
		+ "dig the headroom with a tunnel if they run into rock.")
	l.append("[b]Room[/b] — drag a rectangle on the floor grid (at least 3 × 3 cells): a room rises from it, "
		+ "[b]Floors[/b] cells high inside, with its walls, floor and ceiling, hollow within ([b]Down[/b]: the "
		+ "rectangle is the ceiling and the room sinks below it). Inside rock, the inside is dug. "
		+ _touche("[") + " " + _touche("]") + " set the floors. It has no door: open one with a tunnel.")
	l.append("[b]Straight[/b] — one click: the shape leaves the face square to it. A tunnel or a well goes "
		+ "through to the next cave (or [b]Depth[/b] cells deep, a dead end); a bridge runs to the first wall "
		+ "in front, within [b]Reach[/b].")
	l.append("[b]Connect[/b] — two clicks, two faces anywhere: two caves, two cliffs. The shape leaves "
		+ "each face square to it, then joins the two ends with a straight run, and both ends stay open. "
		+ _touche("Esc") + " or a right click forgets the first end.")
	l.append("Profiles: [b]Round[/b], [b]Square[/b], [b]Arch[/b] (a flat floor and a round vault — a "
		+ "corridor you can walk). " + _touche("[") + " " + _touche("]") + " set the size.")
	l.append(_note("Slanted walls work: a staircase wall at 45° is read as one slanted face, and the shape "
		+ "leaves it at 45°. Where a slanted shape would make two cells touch by an edge only — which the "
		+ "tiles forbid — it adds the missing cells itself, and says how many."))
	l.append(_titre("Fluids"))
	l.append("Pick [b]Water[/b] and click once: the world decides what the water becomes. In a hollow, of any "
		+ "size, a [b]lake[/b] fills it to its brim. On a slope or a ledge, a [b]river[/b] runs down the "
		+ "shortest way, falls as a waterfall, fills the hollows it meets and overflows them. In the open air, "
		+ "over nothing, a [b]sea[/b] at that height surrounds the matter as far as you can see. A cave fills "
		+ "only if a passage leads to it under the water.")
	l.append("Water follows the world: dig a channel, raise a dam, and it flows again — "
		+ _touche("Ctrl") + _touche("Z") + " included. It sees the cells of every layer, hidden ones too. "
		+ "A right click on water removes it. Water layers are its own: show, hide or pick each one.")
	l.append("[b]Look[/b] sets how a water layer is drawn: [b]Stylized[/b] (flat toon colours that darken with "
		+ "depth, a white line on the shore), [b]Clear[/b] (you see the bottom through it, bent by the waves; its "
		+ "colour deepens with depth), [b]Reflective[/b] (dark and smooth, a mirror at grazing angles: the sky, "
		+ "and the relief that is on screen), [b]Lava[/b] (a dark crust split by glowing cracks), [b]Swamp water[/b] "
		+ "(murky, with drifting duckweed), [b]Glowing acid[/b] (luminous green, bubbling). Lava, swamp and acid "
		+ "flow and fill hollows exactly like water; in the Play test you swim in them too, and the colour you "
		+ "see from under the surface is theirs.")
	l.append(_note("The looks are examples, not a requirement. In your engine you can assign your own water "
		+ "shader from the plugin: it receives the same data — the flow, the kind of water (still, river, "
		+ "waterfall) and the depth."))
	return "\n".join(l)


func _couches() -> String:
	var l := PackedStringArray()
	l.append(_titre("Layers"))
	l.append("A layer is [b]a witness and a painted world[/b]: its own witness — the tiles you sculpt in "
		+ "[b]Witness[/b] — and its own cells, painted in [b]World[/b].")
	l.append("[b]A cell belongs to one layer only[/b]: painting it in the active layer takes it from the others "
		+ "(one " + _touche("Ctrl") + _touche("Z") + " gives it back). Where two layers meet, the tiles are chosen "
		+ "as if the world were one piece — no wall, no groove at the border — and each corner is drawn with the "
		+ "tiles of the [b]highest layer in the list[/b] among its eight cells: the top layer "
		+ "wins. [b]Up[/b] and [b]Down[/b] move the active layer in the list. A hidden layer leaves the world, which "
		+ "closes without it.")
	l.append("The layer list is in both workshops. Pick a layer and [b]both follow[/b]: Witness edits its "
		+ "witness, World paints its cells. Each row shows a thumbnail of its witness, where the witness "
		+ "comes from (computed, modelled, from Blender, or an unlinked work) and whether its tiles are up to "
		+ "date (« slice again » when the witness changed since it was sliced).")
	l.append("[b]New layer[/b] starts from the computed witness. [b]Copy witness[/b] starts from a copy of "
		+ "the active layer's: sculpt ice from rock without touching the rock. Editing one layer's witness "
		+ "never changes another layer.")
	l.append("[b]The world follows its witness[/b]: a second after you stop sculpting, the layer takes the "
		+ "new tiles by itself — no button. [b]Slice this layer's witness[/b] (Project, step 3) does the same "
		+ "on demand. A layer dressed by an unlinked work keeps it.")
	l.append("A linked .glb back from Blender, sliced into a layer, [b]becomes its witness[/b] — "
		+ "editable here, textures and UVs included; the previous one is kept next to it (.previous). "
		+ "Slicing a new work into a layer [b]keeps its painting[/b] — only the tiles change.")
	l.append(_titre("Projects"))
	l.append("A project ([b].mbproj[/b]) holds the layers, their cells and where their tiles come from. "
		+ "It [b]saves itself after every change[/b] and reopens when you come back — there is no need for "
		+ _touche("Ctrl+S") + " (pressing it only confirms). The title bar says so: [b]✓ Saved[/b], or "
		+ "[b]● Saving…[/b] for the second a witness edit waits to be written. "
		+ "On first launch, MarchingBlocks gives its files their icons in Windows (.mbproj, .mbtiles, and the "
		+ ".mbset / .mbworld folders it exports) and a [b]double-click on a .mbproj opens it[/b] — for your "
		+ "Windows account only. Untick [b]File icons & double-click[/b] (Project) to remove it. "
		+ "[b]Save as…[/b] puts it where you want; it keeps saving itself there.")
	l.append("[b]Open the example[/b] (Project) opens a finished world made with MarchingBlocks: walk it in "
		+ "Play test, open its witnesses, change anything. It lives in its own folder and keeps your changes.")
	l.append("The sliced tiles are cached. If the artist saved the .glb again, the layer is sliced "
		+ "again on opening; if the .glb is gone, you see the last tiles sliced from it, and the report "
		+ "says so.")
	l.append(_titre("Export the painted world"))
	l.append("In [b]World[/b], [b]Painted world → Export the world…[/b] writes a [b].mbworld[/b] folder: "
		+ "every layer, in order, with its cells, whether it is shown, and its tiles (one .mbset per tile "
		+ "source, inside the folder). In your engine: [b]Import MarchingBlocks world[/b] — Godot "
		+ "(Project → Tools), Unity (Tools → MarchingBlocks) or Unreal (the MarchingBlocks World Import "
		+ "actor). A layer without tiles still travels with its cells, and the engine says it has none.")
	return "\n".join(l)


func _modeleur() -> String:
	var l := PackedStringArray()
	l.append("[i]The witness has two workspaces, on the same block: [b]Geometry[/b] is a modeller — shape the "
		+ "witness with Blender's gestures and shortcuts, instead of sending it away — and [b]Texturing[/b] gives "
		+ "its faces their materials, projections and UVs. In Texturing you select faces, but the geometry "
		+ "keys (G, E, X…) do nothing: the screen sends you to Geometry. What you make is saved next to the "
		+ "project.[/i]")
	l.append(_titre("One tile per class, linked copies"))
	l.append("The witness is made of the [b]52 tiles[/b] a world uses, and every place it shows a tile is a "
		+ "[b]linked copy[/b] of it. Click any copy: you edit [b]that tile[/b], and every copy follows as you "
		+ "move the mouse — what you see is exactly what a painted world will show, joints included. Clicking a "
		+ "copy of another tile switches to that tile (the selection belongs to a tile). Axes stay the "
		+ "world's: " + _touche("G") + " " + _touche("Z") + " moves up, whichever way the copy is turned.")
	l.append("[b]Border vertices are shared.[/b] A vertex lying on a cell's cutting plane is the border every "
		+ "neighbouring tile must match. With " + _touche("G") + " " + _touche("R") + " " + _touche("S") + " it "
		+ "slides only within its plane (along the edge if it sits on two), and every matching vertex of every "
		+ "other tile follows: the witness cannot open a crack. One " + _touche("Ctrl+Z") + " undoes it everywhere. "
		+ "A move, rotation or scale also [b]stops before any face folds[/b], in this tile or in any other: past "
		+ "that point the report says where it stopped.")
	l.append("[b]The tiles[/b] tab of the strip above the view shows all of them: a photo of each tile in its "
		+ "cell (the ghost cubes are the full half-cells around the corner), open air or under rock, what it "
		+ "does in a world and how many copies the witness shows. Hover a tile to light up its copies; click "
		+ "it to go to the clearest one — in edit mode, it becomes the tile you edit.")
	l.append(_titre("Editing  " + _touche("Tab")))
	l.append(_touche("Tab") + " enters and leaves edit mode. " + _touche("1") + " " + _touche("2") + " "
		+ _touche("3") + " select vertices, edges or faces. A click selects what you [b]see[/b]; "
		+ _touche("Shift") + "-click adds or removes; " + _touche("Alt") + "-click selects a loop (a ring of "
		+ "faces in face mode). " + _touche("A") + " all, " + _touche("Alt+A") + " none, " + _touche("B")
		+ " a box — only what you see, unless X-ray is on (" + _touche("Alt+Z") + "). " + _touche("Ctrl")
		+ " + right drag draws a [b]lasso[/b] (" + _touche("Shift+Ctrl") + " removes). " + _touche("C") + " is the "
		+ "[b]circle[/b]: paint the selection with the left button, " + _touche("Shift") + " or the middle button "
		+ "removes, the wheel sizes it, right click or " + _touche("Esc") + " ends.")
	l.append(_titre("Transform"))
	l.append(_touche("G") + " move, " + _touche("R") + " rotate, " + _touche("S") + " scale. Move the "
		+ "mouse, then click or " + _touche("Enter") + " to confirm, " + _touche("Esc") + " or right click to "
		+ "cancel. " + _touche("X") + " " + _touche("Y") + " " + _touche("Z") + " lock an axis — [b]Z is up[/b], "
		+ "as in Blender. Type a number for an exact value (degrees for R). " + _touche("O")
		+ " turns proportional editing on: nearby vertices follow part of the way; the wheel sets the radius.")
	l.append(_titre("Mesh"))
	l.append(_touche("E") + " extrude (faces follow their normal) · " + _touche("I") + " inset · "
		+ _touche("Ctrl+B") + " bevel the selected edges · " + _touche("Ctrl+R") + " loop cut · "
		+ _touche("K") + " knife: click points on edges, face by face, " + _touche("Enter") + " cuts · "
		+ _touche("X") + " delete · " + _touche("M") + " merge at center · " + _touche("F")
		+ " fill a hole · Subdivide (button). Every gesture is one " + _touche("Ctrl+Z") + ".")
	l.append(_note("Deleting opens a hole: you see it, and F closes it. Nothing is filled for you."))
	l.append(_titre("Materials — in Witness texturing"))
	l.append("[b]New material[/b], select faces, [b]Assign[/b]. A material has a colour, roughness, "
		+ "metallic, an optional image, and how many cells one copy of the image covers. Images are "
		+ "[b]projected from the position[/b] — Box (each face takes the side it faces), or flat from the "
		+ "Top, Front or Side. Nothing to unwrap: new faces are textured too.")
	l.append(_note("Use tileable images whose repeat divides one cell (1, 0.5, 0.25…): the texture then "
		+ "joins from one tile to the next in the painted world. Along the cut planes, the texture must be "
		+ "the same for every tile — an automatic texturing tool that paints the block as one object will "
		+ "look perfect here and break at every seam of the world."))
	l.append(_titre("Paint — in Witness texturing"))
	l.append(_touche("P") + " turns the brush on: [b]left drag paints[/b] the image of the material under the "
		+ "mouse, right on the witness — every copy of the tile follows. " + _touche("Alt") + "+click picks a "
		+ "colour. Size (in pixels of the image), hardness and opacity are in the Paint section. A material "
		+ "without an image gets a canvas filled with its colour (" + str(1024) + " × " + str(1024) + "), and its "
		+ "colour turns white so the paint is not darkened. Every stroke is one " + _touche("Ctrl+Z") + ".")
	l.append(_note("Box projection repeats the image, so what you paint repeats too: good for a tileable "
		+ "material, and it keeps the seams right. For paint that does not repeat, use [b]Unwrap all tiles "
		+ "(atlas)[/b]: every face of the material, in every tile, unwrapped together into one image — each tile "
		+ "gets its own place (U alone unwraps one tile into the whole square, on top of the others). A tile's "
		+ "copies still share its paint: they are the same tile. Faces with the legend colour cannot be painted: "
		+ "assign a material first."))
	l.append(_touche("E") + " switches the brush to the [b]eraser[/b]: it makes the active layer transparent. On "
		+ "the bottom layer, the canvas comes back as it was before any paint.")
	l.append("[b]Paint layers[/b] — the Paint section lists the layers of the current material's canvas, top first. "
		+ "Click a layer to paint on it, the eye hides it; [b]New[/b] adds a transparent layer above the active one, "
		+ "[b]Up[/b] / [b]Down[/b] move it, [b]Delete[/b] removes it; its name and opacity are set below the list. "
		+ "Each change is one " + _touche("Ctrl+Z") + ".")
	l.append(_note("Engines only ever see the flattened image: the layers stay in MarchingBlocks, saved next to the "
		+ "image (a [i].layers[/i] folder). If you change the image in another program, its old layers are set "
		+ "aside and the image becomes a single layer — MarchingBlocks says so."))
	l.append("Under the mouse, the [b]brush outline[/b] shows exactly where a dab stops on that face: white for "
		+ "its edge, the brush colour for its hardness (full strength inside). It is drawn in the image's pixels, "
		+ "so it is an ellipse where the unwrap stretches the face, and it grows with the material's repeat. A "
		+ "small red ring means the face has no material.")
	l.append(_note("[b]Seam bands[/b] — while painting, pink striped bands mark the cut planes, where one tile "
		+ "meets the next in the painted world. Paint them the same on every tile (a tileable material, or "
		+ "nothing), and keep the free drawing in the middle of the tiles. The bands only show where to be "
		+ "careful; the slicer still checks the texture seams. Untick [b]Seam bands[/b] in the Paint section to "
		+ "hide them."))
	l.append(_titre("View"))
	l.append("Middle drag turns, " + _touche("Shift") + " + middle drag slides, the wheel zooms. Numpad "
		+ _touche("1") + " front, " + _touche("3") + " right, " + _touche("7") + " top (" + _touche("Ctrl")
		+ ": the opposite), " + _touche("5") + " orthographic, " + _touche(".") + " frames the selection.")
	return "\n".join(l)


func _aller_retour() -> String:
	var l := PackedStringArray()
	l.append(_titre("What the artist receives"))
	l.append("[b]One .glb[/b]: the whole witness at the origin, built from the tiles the world will use — "
		+ "[b]one tile per class[/b], and every place the witness uses it is a [b]linked copy[/b] of it "
		+ "(Blender's linked duplicates: all the copies share one mesh). Sculpt any copy and every copy "
		+ "follows, live. What the witness shows is exactly what a painted world will show, joints "
		+ "included. Tiles are already shrunk to half their cell to show the margin, the six families "
		+ "are six named materials, and the UVs are canonical: paint one copy, you painted the tile.")
	l.append("[b]Bring it back as .glb[/b] (File → Export → glTF 2.0): it carries your textures, UVs "
		+ "and materials. It is read tile by tile — nothing is sliced — so relief that spills onto a "
		+ "neighbouring tile stays with the tile you sculpted it on.")
	l.append(_note("Import it with « Merge Vertices » ticked: in glTF every material is a separate "
		+ "primitive, so inside a tile the colour borders arrive cut. The copies stay linked either way."))
	l.append(_titre("The contract"))
	l.append("[b]Total freedom inside each cell.[/b] Relief may spill half a cell into the neighbours.")
	l.append("[b]Do not move, rotate or Join the objects[/b]: each tile is identified by its position "
		+ "when it comes back, not its name. A copy sculpted on its own, moved or rotated no longer "
		+ "agrees with its siblings: the report names it, and the most common version is kept.")
	l.append("[b]Do not change which cells are full[/b]: the filling fixes the tile classes.")
	l.append("[b]The seams are the artist's responsibility.[/b] The slicer cuts straight through the "
		+ "cell centres and judges nothing else — the report lists the seam remarks.")
	l.append(_titre("Proving the round trip"))
	l.append("[b]Paint the witness shape[/b] fills a layer with the witness's own cells. Slice your work "
		+ "into it: the result must give your block back.")
	l.append(_note("A class has ONE tile, the same everywhere it appears. With the linked witness, the "
		+ "rebuilt block is exactly the witness. A single-mesh work (everything joined, or an .obj) only "
		+ "gives the clearest copy of each tile — the report says so: anything sculpted on the other copies "
		+ "does not reach the world. An atlas carries no unique detail."))
	return "\n".join(l)


## « POUR OBTENIR LE MÊME RENDU » (Jordan, 1er octobre 2026 : « au fur et à mesure qu'on paramètre l'ambiance
## lumineuse, il faudra tenir à jour le mode d'emploi […] fais la liste »). ⚠ LES VALEURS SONT LUES DANS LA VUE
## (`Vue.SOLEIL_ENERGIE`…), jamais recopiées : retoucher un réglage là-bas met cette page à jour.
func _rendu() -> String:
	const Vue := preload("res://app/vue.gd")
	var l := PackedStringArray()
	l.append("The tiles carry their geometry, normals, UVs and materials. The [b]light[/b] is your engine's: "
		+ "to see in your game what you see here, set up the same scene. Every value below is the one this "
		+ "app uses right now.")
	l.append(_titre("Shading"))
	l.append("[b]Flat, one normal per face[/b] — no smoothing. The tiles leave with the normals the modeller "
		+ "shows: [b]import the normals from the file[/b]; do not let the engine recompute or smooth them "
		+ "(Unity: Normals → Import; Unreal: Import Normals; Godot keeps them by default).")
	l.append("Materials are standard PBR (base colour, roughness, metallic, texture). The legend colours of "
		+ "the witness are [b]vertex colours[/b] on one material: enable « vertex colour as albedo » for it.")
	l.append(_titre("Sun — a directional light"))
	l.append("Rotation [b]%s°[/b] (pitch, yaw, roll), energy [b]%.2f[/b], [b]shadows on[/b]." % [
		Vue.SOLEIL_ROTATION, Vue.SOLEIL_ENERGIE])
	l.append(_titre("Ambient light"))
	l.append("A flat [b]colour[/b] %s at energy [b]%.2f[/b] — not the sky: a world lit by its sky changes tone "
		% [_couleur(Vue.AMBIANTE_COULEUR), Vue.AMBIANTE_ENERGIE] + "with it.")
	l.append(_titre("Ambient occlusion — SSAO"))
	l.append("On, intensity [b]%.1f[/b], and applied to the [b]direct light too[/b] (Godot: « Light Affect » "
		% Vue.SSAO_INTENSITE + "[b]%.1f[/b]). Left at its default, SSAO only darkens the ambient light and " \
		% Vue.SSAO_SUR_LE_SOLEIL + "vanishes in the sun.")
	l.append(_titre("Bounced light — SSIL"))
	l.append("On (screen-space indirect light, default settings): the colour of a floor bleeds into the walls "
		+ "of a pit. Unity and Unreal have their own screen-space GI; any of them gives the same idea.")
	l.append(_titre("Reflections"))
	l.append("Metals [b]reflect[/b] their surroundings instead of being lit: give them something to reflect. "
		+ "Here, a neutral procedural sky — top %s, horizon %s, ground %s — used for reflections only." % [
		_couleur(Vue.REFLETS_HAUT), _couleur(Vue.REFLETS_HORIZON), _couleur(Vue.REFLETS_SOL)])
	l.append(_note("Without it, a metallic wall in shadow turns black."))
	l.append(_titre("Sky of the Play test"))
	l.append("A procedural sky: top %s, horizon %s, ground %s, ground curve [b]%.1f[/b] (the dark ground "
		% [_couleur(Vue.CIEL_HAUT), _couleur(Vue.CIEL_HORIZON), _couleur(Vue.CIEL_SOL), Vue.CIEL_COURBE_DU_SOL]
		+ "only shows far below the horizon). It is the background and the reflections in the Play test.")
	l.append(_titre("Anti-aliasing"))
	l.append("MSAA [b]4×[/b].")
	l.append(_note("Not used, on purpose: global illumination that is baked or voxel-based (Godot's SDFGI, "
		+ "lightmaps). It does not follow geometry that changes while you sculpt."))
	return "\n".join(l)


func _couleur(c: Color) -> String:
	return "[color=#%s]■[/color] [b]#%s[/b]" % [c.to_html(false), c.to_html(false)]


func _raccourcis() -> String:
	var l := PackedStringArray()
	l.append(_titre("World"))
	l.append(_table(_raccourcis_monde()))
	l.append(_titre("Witness (modeller)"))
	l.append(_table([
		["Tab", "Edit mode on / off"], ["1 · 2 · 3", "Vertex · edge · face"], ["Click · Shift · Alt", "Select · add · loop"],
		["A · Alt+A · B", "All · none · box"], ["Ctrl+right drag · C", "Lasso · circle"],
		["Alt+Z", "X-ray (box, lasso and circle take what is hidden)"],
		["G · R · S", "Move · rotate · scale"], ["X Y Z · numbers", "Lock an axis · exact value"],
		["E · I", "Extrude · inset"], ["Ctrl+B · Ctrl+R · K", "Bevel · loop cut · knife"],
		["X · M · F", "Delete · merge · fill"], ["O", "Proportional editing"],
		["Numpad 1 3 7 · 5 · .", "Views · ortho · frame"],
	]))
	l.append(_titre("Play test"))
	l.append(_table([
		["Z Q S D", "Move (W A S D on QWERTY)"], ["Space · Shift", "Jump · run"],
		["F", "Fly on · off"], ["Space or E · A", "Fly up · down (E · Q on QWERTY)"],
		["Left drag · right drag", "Orbit the camera · turn it level"], ["Wheel", "Closer · farther"],
		["Backspace · Esc", "Back to start · back to World"],
	]))
	return "\n".join(l)


func _table(lignes: Array) -> String:
	var l := PackedStringArray()
	l.append("[table=2]")
	for r in lignes:
		l.append("[cell]%s   [/cell][cell]%s[/cell]" % [_touche(r[0]), r[1]])
	l.append("[/table]")
	return "\n".join(l)


func _raccourcis_monde() -> Array:
	return [
		["Tab", "Grid ↔ Sculpt"], ["Space", "Navigate on / off"], ["A Z E Q S D", "Fly (Navigate)"],
		["Right drag", "Look around (Navigate)"], ["A · D · S · R · B", "Add · Dig · Select · Rect · Box"],
		["[  ]", "Brush size"], ["PgUp · PgDn", "Floor y"],
		["Ctrl+click", "Put the grid at the height of the matter clicked"],
		["Arrows", "Move the selection (follows the camera)"], ["Shift + ↑ ↓", "Lift / lower the selection"],
		["Del", "Delete the selection"], ["Esc", "Clear the selection · cancel a paste"],
		["Ctrl+C · X · V", "Copy · cut · paste"], ["Ctrl+Z · Ctrl+Y", "Undo · redo"],
		["Middle drag", "Turn the view"], ["Shift + middle drag", "Slide the view"], ["Wheel", "Zoom"],
		["F1", "This guide"],
	]
