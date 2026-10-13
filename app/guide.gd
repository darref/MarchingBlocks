extends RefCounted
## LE GUIDE DES RACCOURCIS — DEMANDÉ PAR JORDAN (13 octobre 2026) : « les touches Ctrl, Alt et Maj devraient être les
## modificateurs contextuels […] faire un état des lieux de tous les raccourcis, laisser les moins importants dans la section
## Shortcuts, mais afficher le petit nombre des plus courants en texte flottant en haut à gauche de la vue 3D, qui se
## confirme au modificateur pressé, comme une proposition pour la suite », puis « guider en arbre l'utilisateur en montrant
## des propositions de shortcuts selon le contexte ».
##
## UN SENS PAR MODIFICATEUR, PARTOUT (validé par Jordan, 13 octobre 2026) :
##   - ALT  = la TAILLE (pinceau, forme, rayon ; avec une sélection : grandir / rétrécir à plat) ;
##   - MAJ  = la HAUTEUR, ou « en plus » (étendre ↑ ↓, étages, profondeur ; au clic : ajouter ; au jeu : courir) ;
##   - CTRL = DÉPLACER ce qui est en jeu, ou l'INVERSE (la sélection, sinon la grille ; au sculpt : creuser).
##
## ⚠ UNE SEULE DESCRIPTION (charte §6) : cette table nourrit le guide flottant (`essentiel`) ET la section Shortcuts (tout).
## Ce qu'elle dit doit être ce que fait le code : la fumée mène les gestes qu'elle annonce.
##
## PUR : `contexte` est un dictionnaire bâti par l'écran — atelier, outil, quoi (la forme spéciale), selection (bool),
## naviguer, collage, glisse, mer (bool), edition, modal, sculpt, pinceau.

## Les modificateurs, dans l'ordre où le guide les propose, et leur sens général (la ligne de la racine).
const MODIFS := ["ctrl", "alt", "shift"]
const NOMS := {"ctrl": "Ctrl", "alt": "Alt", "shift": "Shift"}


## Toutes les entrées du contexte : [modificateur ("" ou "ctrl" / "alt" / "shift"), geste, ce qu'il fait, essentiel].
static func entrees(c: Dictionary) -> Array:
	var l: Array = []
	var atelier := str(c.get("atelier", ""))
	var outil := str(c.get("outil", ""))
	var sel := bool(c.get("selection", false))
	if bool(c.get("naviguer", false)) and atelier in ["monde", "fluides", "transitions", "feuillage", "variantes"]:
		l.append(["", "Z Q S D · A E", "fly (W A S D · Q E on QWERTY)", true])
		l.append(["", "Right drag", "look around", true])
		l.append(["", "Space", "stop flying", true])
		return l
	match atelier:
		"monde", "jeu_edit":
			_monde(l, c, outil, sel, atelier == "jeu_edit")
		"fluides":
			if bool(c.get("mer", false)):
				l.append(["", "Wheel · PgUp PgDn", "sea level", true])
				l.append(["", "Click · Enter", "lay the sea", true])
				l.append(["", "Right click · Esc", "forget it", true])
				return l
			l.append(["", "Click", "a source: lake, river, or the sea in the void", true])
			l.append(["", "Right click", "remove the water clicked", true])
			l.append(["alt", "Wheel", "river width", true])
			l.append(["ctrl", "Wheel", "move the grid (floor y)", true])
			_vue_monde(l)
			l.append(["", "Esc", "back to World", false])
		"transitions":
			l.append(["", "Drag", "paint which layer covers", true])
			l.append(["", "Right drag", "back to the layer order", true])
			l.append(["alt", "Wheel", "brush radius", true])
			_vue_monde(l)
			l.append(["", "Esc", "back to World", false])
		"variantes":
			l.append(["", "Click", "the next variant of the tile", true])
			l.append(["", "Right click", "back to the random draw", true])
			l.append(["", "Space", "Navigate (fly)", false])
			l.append(["", "F · ²", "frame all the matter · jump to the matter", false])
			l.append(["", "Middle drag · Shift+middle", "turn · slide the view", false])
			l.append(["", "Esc", "back to World", false])
		"feuillage":
			l.append(["", "Drag", "plant", true])
			l.append(["alt", "Wheel", "brush size", true])
			l.append(["shift", "Wheel", "density", true])
			l.append(["ctrl", "Wheel", "move the grid (floor y)", true])
			_vue_monde(l)
			l.append(["", "Esc", "back to World", false])
		"witness", "texture":
			_temoin(l, c, atelier == "texture")
		"jeu":
			l.append(["", "Z Q S D · Space", "walk (W A S D on QWERTY) · jump", true])
			l.append(["shift", "Z Q S D", "run", true])
			l.append(["", "F", "fly on · off", true])
			l.append(["", "Left drag · right drag", "orbit · turn level", false])
			l.append(["", "Wheel", "closer · farther", false])
			l.append(["", "Backspace · Esc", "back to start · back to World", false])
	if atelier != "projet":
		l.append(["ctrl", "Z · Y", "undo · redo", false])
		l.append(["", "F1", "the user guide", false])
	return l


static func _vue_monde(l: Array) -> void:
	l.append(["", "Space", "Navigate (fly)", false])
	l.append(["", "F · ²", "frame all the matter · jump to the matter", false])
	l.append(["", "Middle drag · Shift+middle", "turn · slide the view", false])
	l.append(["", "PgUp PgDn", "floor y", false])


static func _monde(l: Array, c: Dictionary, outil: String, sel: bool, jeu: bool) -> void:
	var outil_de_selection := outil in ["selectionner", "rect", "boite"]
	if not (c.get("collage", []) as Array).is_empty():
		l.append(["", "Click", "paste here", true])
		l.append(["", "Wheel", "paste higher · lower", true])
		l.append(["", "Esc", "cancel the paste", true])
		return
	match str(c.get("glisse", "")):
		"boite", "rect":
			l.append(["", "Wheel", "raise the far corner: a flat Rect becomes a box", true])
			l.append(["", "Release", "select", true])
			return
		"salle":
			l.append(["", "Wheel", "floors", true])
			l.append(["", "Release", "build the room", true])
			return
	match outil:
		"ajouter", "creuser":
			l.append(["", "Click · drag", "add matter" if outil == "ajouter" else "dig", true])
			l.append(["", "Right click", "dig" if outil == "ajouter" else "add matter", true])
			l.append(["alt", "Wheel", "brush size", true])
		"selectionner":
			l.append(["", "Drag", "paint a selection", true])
			l.append(["", "Right drag", "remove from it", true])
			if not sel:
				l.append(["alt", "Wheel", "brush size", true])
		"rect", "boite":
			l.append(["", "Drag", "flat rectangle on the grid" if outil == "rect" else "box between two corners", true])
			l.append(["shift", "Drag", "add to the selection", true])
			l.append(["", "Right drag", "remove from it", false])
		"forme":
			var quoi := str(c.get("quoi", ""))
			if quoi == "salle":
				l.append(["", "Drag", "draw the room on the grid", true])
				l.append(["shift", "Wheel", "floors", true])
			else:
				l.append(["", "Click", "on a wall: the shape", true])
				l.append(["", "Right click · Esc", "forget the first anchor", false])
				l.append(["alt", "Wheel", "size", true])
				l.append(["shift", "Wheel", "step length" if quoi == "escalier" else "depth · reach · length", true])
		"eau":
			l.append(["", "Click", "a water source", true])
	if sel and outil_de_selection:
		l.append(["ctrl", "Wheel", "move the selection up · down", true])
		l.append(["alt", "Wheel", "widen · shrink it (flat)", true])
		l.append(["shift", "Wheel", "extend it up · down", true])
		l.append(["", "Arrows", "move the selection (follows the camera)", true])
		l.append(["shift", "↑ ↓", "lift · lower the selection", false])
		l.append(["", "Del · Esc", "delete it · clear it", true])
		l.append(["ctrl", "Click Extrude", "offset the selection, nothing added", false])
		l.append(["shift", "Click Extrude", "extend the selection, nothing added", false])
		l.append(["ctrl", "C · X · V", "copy · cut · paste", false])
	else:
		l.append(["ctrl", "Wheel", "move the grid (floor y)", true])
	l.append(["ctrl", "Click", "put the grid at the matter clicked", true])
	if jeu:
		l.append(["", "Z Q S D · Space", "walk · jump", true])
		l.append(["", "R · B", "Rect · Box", false])
		l.append(["", "Esc", "back to World", false])
	else:
		l.append(["", "A · D · S · R · B", "Add · Dig · Select · Rect · Box", true])
		l.append(["", "Tab", "aim at the grid ↔ at the matter", false])
		_vue_monde(l)
	l.append(["", "[ ]", "size", false])


static func _temoin(l: Array, c: Dictionary, texturing: bool) -> void:
	if not bool(c.get("edition", false)):
		l.append(["", "Tab", "edit the tile clicked", true])
		l.append(["", "Numpad 1 3 7 · 5", "views · ortho", false])
		return
	var modal := str(c.get("modal", ""))
	if modal in ["G", "R", "S", "I", "bevel"]:
		l.append(["", "X · Y · Z", "lock an axis", true])
		l.append(["", "Numbers", "exact value", true])
		l.append(["", "Enter · click", "confirm", true])
		l.append(["", "Esc · right click", "cancel", true])
		l.append(["", "Wheel", "proportional radius", false])
		return
	if modal == "knife":
		l.append(["", "Click", "cut point (across copies)", true])
		l.append(["", "Enter · Esc", "cut · cancel", true])
		return
	if modal == "cercle":
		l.append(["", "Click", "paint the selection", true])
		l.append(["shift", "Click", "erase from it", true])
		l.append(["", "Wheel", "radius", true])
		l.append(["", "Right click · Esc", "done", true])
		return
	if texturing and bool(c.get("pinceau", false)):
		l.append(["", "Drag", "paint", true])
		l.append(["alt", "Click", "pick a colour", true])
		l.append(["alt", "Wheel", "brush size", true])
		l.append(["shift", "Wheel", "hardness", true])
		l.append(["", "E · P", "eraser · brush off", true])
		return
	if not texturing and bool(c.get("sculpt", false)):
		l.append(["", "Drag", "sculpt", true])
		l.append(["ctrl", "Drag", "the inverse (dig)", true])
		l.append(["shift", "Drag", "smooth", true])
		l.append(["alt", "Wheel", "radius", true])
		l.append(["shift", "Wheel", "strength", true])
		return
	l.append(["", "Click", "select", true])
	l.append(["shift", "Click", "add to the selection", true])
	l.append(["alt", "Click", "a loop", true])
	l.append(["", "1 · 2 · 3", "vertex · edge · face", true])
	l.append(["", "A · B · C", "all · box · circle", true])
	l.append(["alt", "A · Z", "select none · X-ray", false])
	l.append(["ctrl", "Right drag", "lasso", false])
	if texturing:
		l.append(["", "U · P", "unwrap · paint brush", true])
	else:
		l.append(["", "G · R · S", "move · rotate · scale", true])
		l.append(["", "E · I · K", "extrude · inset · knife", true])
		l.append(["ctrl", "B · R · X", "bevel · loop cut · dissolve", true])
		l.append(["", "X · M · F · O", "delete · merge · fill · proportional", false])
	l.append(["", "Tab", "leave the tile", false])
	l.append(["", "Numpad 1 3 7 · 5 · .", "views · ortho · frame", false])


## Ce que le guide flottant montre : `modif` est le modificateur tenu ("" au repos).
## { titre, lignes: [[geste, ce qu'il fait]], branches: [[modificateur, son résumé]] }.
## Au repos : les gestes essentiels sans modificateur, puis une BRANCHE par modificateur qui a quelque chose ici
## (« Ctrl ▸ move the selection · … »). Modificateur tenu : ses gestes essentiels, les autres de cette branche ensuite.
static func propositions(c: Dictionary, modif := "") -> Dictionary:
	var toutes := entrees(c)
	var lignes: Array = []
	var branches: Array = []
	if modif == "":
		for e in toutes:
			if e[0] == "" and e[3]:
				lignes.append([e[1], e[2]])
		for m in MODIFS:
			var actions: Array = []
			for e in toutes:
				if e[0] == m and e[3] and e[2] not in actions:
					actions.append(e[2])
			if not actions.is_empty():
				branches.append([m, " · ".join(actions.slice(0, 2))])
	else:
		for passe in [true, false]:
			for e in toutes:
				if e[0] == modif and e[3] == passe:
					lignes.append([e[1], e[2]])
	return {"lignes": lignes, "branches": branches}


## La section Shortcuts : tout ce qui n'est PAS au guide flottant (le guide montre déjà le reste).
static func le_reste(c: Dictionary) -> Array:
	var l: Array = []
	for e in entrees(c):
		if not e[3]:
			l.append([(NOMS[e[0]] + " + " if e[0] != "" else "") + str(e[1]), e[2]])
	return l


## TOUT RACCOURCI A SON BOUTON (Jordan, 13 octobre 2026 : « rien qui est faisable en shortcut ne doit être pas faisable en
## bouton dans le soft ») — pour chaque raccourci CLAVIER de la table, le(s) bouton(s) qui font la même chose (le début de
## leur texte à l'écran). La fumée exige que chacun existe. Clé : « modificateur|geste ».
const BOUTONS := {
	"|A · D · S · R · B": ["Add", "Dig", "Select", "Rect", "Box"],
	"|R · B": ["Rect", "Box"],
	"|Tab": ["Grid", "Sculpt", "Edit the witness"],
	"|Space": ["Navigate"],
	"|F · ²": ["Frame all", "Jump to matter"],
	"|PgUp PgDn": ["Floor ↑", "Floor ↓"],
	"|Arrows": ["X +", "Z +"],
	"shift|↑ ↓": ["Y +", "Y −"],
	"|Del · Esc": ["Delete", "Clear"],
	"ctrl|C · X · V": ["Copy", "Cut", "Paste"],
	"ctrl|Z · Y": ["Undo", "Redo"],
	"|F1": ["Open the user guide"],
	"|Esc": ["Leave", "Cancel paste"],
	"|Backspace · Esc": ["Back to start", "Leave"],
	"|F": ["Fly"],
	"|Wheel · PgUp PgDn": ["Sea ↑", "Sea ↓"],
	"|Click · Enter": ["Lay the sea"],
	"|Right click · Esc": ["Cancel the sea", "Forget the anchor"],
	"|Numpad 1 3 7 · 5": ["Front", "Right", "Top", "Ortho"],
	"|Numpad 1 3 7 · 5 · .": ["Front", "Right", "Top", "Ortho", "Frame  ·  ."],
	"|1 · 2 · 3": ["Vertex", "Edge", "Face"],
	"|A · B · C": ["All", "Box", "Circle"],
	"alt|A · Z": ["None", "X-ray"],
	"alt|Click": ["Loop select", "Pick colour"],
	"|U · P": ["Unwrap", "Paint"],
	"|G · R · S": ["Move", "Rotate", "Scale"],
	"|E · I · K": ["Extrude", "Inset", "Knife"],
	"ctrl|B · R · X": ["Bevel", "Loop cut", "Dissolve"],
	"|X · M · F · O": ["Delete  ·  X", "Merge", "Fill  ·  F", "Proportional"],
	"|E · P": ["Eraser", "Paint"],
	"ctrl|Drag": ["Invert"],
	"shift|Drag": ["Smooth"],
	"ctrl|Click": ["Grid to matter"],
	"|Right click": ["Forget the anchor"],
}
## Ce qui n'a pas de bouton, et pourquoi : les touches PENDANT un geste (X Y Z, nombres, Entrée, Échap — la souris qui
## irait chercher un bouton déplacerait le geste), les touches de MOUVEMENT tenues (marcher, voler, courir), et [ ] (le
## curseur de taille est là).
const SANS_BOUTON := ["X · Y · Z", "Numbers", "Enter · click", "Esc · right click", "Enter · Esc", "Z Q S D · A E",
	"Z Q S D", "Z Q S D · Space", "[ ]", "Space"]


## Le raccourci `e` est-il au CLAVIER (une touche, pas seulement la souris) ?
static func est_au_clavier(e: Array) -> bool:
	var g := str(e[1])
	if BOUTONS.has(str(e[0]) + "|" + g):
		return true
	for souris in ["Click", "Drag", "drag", "Wheel", "Release", "click", "Right", "Left", "Middle"]:
		if g.begins_with(souris):
			return false
	return true


## Les boutons d'un raccourci au clavier ([] s'il en est exempté).
static func boutons_de(e: Array) -> Array:
	var cle := str(e[0]) + "|" + str(e[1])
	if BOUTONS.has(cle):
		return BOUTONS[cle]
	return []


## Le modificateur tenu, lu au clavier : Ctrl (ou Cmd), puis Alt, puis Maj — le premier l'emporte.
static func modificateur_tenu() -> String:
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META):
		return "ctrl"
	if Input.is_key_pressed(KEY_ALT):
		return "alt"
	if Input.is_key_pressed(KEY_SHIFT):
		return "shift"
	return ""
