extends SceneTree
##
## LE TOUR DE L'INTERFACE — demandé par Jordan (5 octobre 2026) : « un autre [trailer] qui montre ce que contient toute
## l'UI et l'effet que ça a sur le soft en temps réel, avec les raccourcis intéressants utilisés autant que les boutons ».
##
## ⚠ TOUT PASSE PAR DE VRAIS ÉVÉNEMENTS (`Input.parse_input_event`) : la souris va sur le bouton et clique, la touche
## est frappée, le glissé peint — le chemin d'un utilisateur, pas un appel de fonction. Deux AIDES DE TOURNAGE sont
## dessinées par-dessus, et seulement elles : le CURSEUR (le Movie Maker ne filme pas celui de Windows) et la CARTE DE
## LA TOUCHE en bas de l'image (« Tab · Sculpt aim »). Elles ne font pas partie de l'appli et ne le prétendent pas.
##
## LANCEMENT — dans la COPIE de tournage, comme filmer_trailer.gd :
##   cp D:/MarchingBlocks/DEV_TOOLS/filmer_*.gd D:/MarchingBlocks_tournage/DEV_TOOLS/
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks_tournage --fixed-fps 30 \
##       --write-movie D:/SpannerGames/PROJETS/MarchingBlocks/02_rushes/ui.avi --script res://DEV_TOOLS/filmer_ui.gd
##   `-- --seulement=<partie>` ne tourne qu'une partie (camera, peindre, selection, formes, eau, geometrie, jeu, manuel).
## ⚠ Ne jamais l'interrompre : il rend les réglages à la fin.

const Exemple := preload("res://app/exemple.gd")
const Ile := preload("res://DEV_TOOLS/filmer_ile.gd")
const REGLAGES := "user://reglages.cfg"
const DOSSIER := "user://filmer_ui"
const SAUVEGARDE := "user://reglages.cfg.avant_filmer"
const FPS := 30.0
const POLICE := "D:/SpannerGames/BIBLIOTHEQUE/polices/Inter.ttf"
const PARTIES := ["camera", "peindre", "selection", "formes", "eau", "geometrie", "jeu", "manuel"]

var _ecran: Control
var _vue
var _ile
var _chemin := ""
var _image := 0
var _couche := {}
var _seulement := ""

# Les aides de tournage : le curseur et la carte de la touche.
var _calque: CanvasLayer
var _dessin: Control
var _police: FontFile
var _souris := Vector2(960, 540)
var _masque := 0
var _carte := ""
var _carte_detail := ""
var _carte_age := 99.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seulement="):
			_seulement = a.substr("--seulement=".length())
	if FileAccess.file_exists(SAUVEGARDE):
		DirAccess.copy_absolute(SAUVEGARDE, REGLAGES)
	if FileAccess.file_exists(REGLAGES):
		DirAccess.copy_absolute(REGLAGES, SAUVEGARDE)
	_vider(DOSSIER)
	var erreurs: Array = []
	_chemin = Exemple.installer(Exemple.ARCHIVE, DOSSIER, erreurs)
	if _chemin == "":
		print("⚠ l'exemple ne s'installe pas : %s" % [erreurs])
		_rendre_les_reglages()
		quit(1)
		return
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", _chemin)
	r.save(REGLAGES)
	load("res://app/editor.gd").racine_exemple = DOSSIER
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	Input.use_accumulated_input = false
	_derouler.call_deferred()


func _derouler() -> void:
	await _images(30)
	await _ecran._ouvrir(_chemin)
	_ecran._changer_d_atelier("monde")
	_ecran._legende_formes.basculer(false, false)
	_vue = _ecran._vue
	for i in _ecran._couches.size():
		_couche[str(_ecran._couches[i].get("nom", ""))] = i
	_ile = Ile.new(self, _ecran, _couche)
	await _ile.construire()
	_ecran._activer(_couche["Grass"])
	_aides()
	await _images(20)

	if _seulement == "boutons":
		_lister(_ecran)
	for partie in PARTIES:
		if _seulement != "" and _seulement != partie:
			continue
		_plan(partie)
		await Callable(self, "_" + partie).call()
		await _images(int(0.6 * FPS))
	_plan("fin")
	_rendre_les_reglages()
	quit(0)


# ── LES PARTIES ──────────────────────────────────────────────────────────────────────────────────────

## La caméra : F cadre tout, le clic du milieu tourne, Maj + milieu glisse, la molette zoome.
func _camera() -> void:
	_poser_camera(Vector3(0, 8, 0), 0.9, 0.55, 60.0)
	await _images(10)
	await _bouger(_sur(Vector3(0, 10, 0)), 0.6)
	await _touche(KEY_F, "F", "Frame the whole world")
	await _images(int(1.2 * FPS))
	await _glisser_milieu(Vector2(260, -40), 2.2, "Middle drag", "Orbit")
	await _glisser_milieu(Vector2(-160, 60), 1.4, "Shift + middle drag", "Pan", true)
	await _bouger(_sur(Vector3(Ile.LAC.x, Ile.PLATEAU, Ile.LAC.y)), 0.5)
	await _molette(MOUSE_BUTTON_WHEEL_UP, 7, "Mouse wheel", "Zoom")
	await _images(int(0.8 * FPS))


## Peindre : Tab (Sculpt), A (Add), ] (pinceau), un glissé ; D (Dig) ; Ctrl+Z, Ctrl+Y ; Cube.
func _peindre() -> void:
	var p := Vector2i(-2, 20)
	_poser_camera(_dessus_de(p) + Vector3(0, 2, 0), -2.5, 0.6, 30.0)
	await _images(10)
	await _bouger(_sur(_dessus_de(p)), 0.5)
	await _touche(KEY_TAB, "Tab", "Sculpt aim: paint ON the matter")
	await _touche(KEY_A, "A", "Add")
	await _touche(KEY_BRACKETRIGHT, "]", "Bigger brush")
	await _touche(KEY_BRACKETRIGHT, "]", "Bigger brush")
	await _peindre_ligne(p + Vector2i(-6, 0), p + Vector2i(6, 0), 2.0, "Left drag", "Paint")
	await _images(int(0.6 * FPS))
	await _touche(KEY_D, "D", "Dig")
	await _peindre_ligne(p + Vector2i(-6, 3), p + Vector2i(6, -3), 2.0, "Left drag", "Dig through the hill")
	await _images(int(0.5 * FPS))
	await _touche(KEY_Z, "Ctrl + Z", "Undo the whole stroke", true)
	await _images(int(0.6 * FPS))
	await _touche(KEY_Y, "Ctrl + Y", "Redo", true)
	await _images(int(0.6 * FPS))
	await _cliquer_bouton("Cube", "Brush: Cube")
	await _touche(KEY_A, "A", "Add")
	await _peindre_ligne(p + Vector2i(-4, -4), p + Vector2i(4, -4), 1.6, "Left drag", "Paint with a cube brush")
	await _cliquer_bouton("Fill", "Fix diagonal contacts: the red cubes are filled", "Two cells")
	await _images(int(0.8 * FPS))
	await _cliquer_bouton("Sphere", "Brush: Sphere")
	await _touche(KEY_BRACKETLEFT, "[", "Smaller brush")
	await _touche(KEY_BRACKETLEFT, "[", "Smaller brush")
	await _images(int(0.5 * FPS))


## La sélection : S, un glissé ; Maj + ↑ la monte ; Extrude up, Widen ; Ctrl+C, Ctrl+V ; Suppr.
func _selection() -> void:
	var p := Vector2i(6, 4)
	_poser_camera(_dessus_de(p) + Vector3(0, 3, 0), 0.6, 0.6, 34.0)
	await _images(10)
	await _touche(KEY_S, "S", "Select")
	await _peindre_ligne(p + Vector2i(-3, -3), p + Vector2i(3, 3), 1.4, "Left drag", "Select cells")
	await _images(int(0.4 * FPS))
	for i in 3:
		await _touche(KEY_UP, "Shift + ↑", "Lift the selection", false, true)
		await _images(8)
	await _cliquer_bouton("Extrude up", "Extrude up")
	await _cliquer_bouton("Extrude up", "Extrude up")
	await _cliquer_bouton("Widen", "Widen")
	await _images(int(0.5 * FPS))
	await _touche(KEY_C, "Ctrl + C", "Copy", true)
	await _touche(KEY_V, "Ctrl + V", "Paste: it follows the mouse", true)
	await _bouger(_sur(_dessus_de(p + Vector2i(-10, 6))), 1.2)
	await _clic(MOUSE_BUTTON_LEFT, "Click", "Drop the copy")
	await _images(int(0.6 * FPS))
	await _touche(KEY_ESCAPE, "Esc", "Clear the selection")
	# Un collage encore en main prend le premier Échap : le second vide la sélection (sinon Geometry refusait).
	_cle(KEY_ESCAPE, true)
	_cle(KEY_ESCAPE, false)
	await _images(int(0.4 * FPS))
	await _cliquer_bouton("Fill", "Fix diagonal contacts", "Two cells")
	await _images(int(0.5 * FPS))


## Les formes spéciales : Tunnel et Stairs, cliquées contre une paroi.
func _formes() -> void:
	# La falaise nord, sous le chenal : une vraie paroi.
	var mur := Vector3(Ile.CHENAL_X + 5, 9, 29)
	_poser_camera(mur + Vector3(0, 1, 0), 0.2, 0.25, 26.0)
	await _images(10)
	await _cliquer_bouton("Tunnel", "Special shape: Tunnel")
	await _bouger(_sur(mur + Vector3(0, 0, 1.0)), 0.8)
	await _clic(MOUSE_BUTTON_LEFT, "Click a wall", "Tunnel")
	await _images(int(1.0 * FPS))
	await _cliquer_bouton("Stairs", "Special shape: Stairs")
	await _bouger(_sur(mur + Vector3(-5, 0, 1.0)), 0.8)
	await _clic(MOUSE_BUTTON_LEFT, "Click a wall", "Stairs")
	await _images(int(1.2 * FPS))


## L'eau : l'atelier Fluids, une rivière d'un clic, puis son aspect (Lava, Glowing acid).
func _eau() -> void:
	var p := Vector2i(-4, -6)
	_poser_camera(_dessus_de(p) + Vector3(0, -2, 6), -0.4, 0.5, 40.0)
	await _images(10)
	await _cliquer_bouton("Fluids", "Fluids workshop")
	await _images(10)
	await _cliquer_bouton("New", "New water layer")
	await _bouger(_sur(_dessus_de(p) + Vector3(0, 0.6, 0)), 0.8)
	await _clic(MOUSE_BUTTON_LEFT, "Click a slope", "A river finds its way down")
	await _images(int(1.0 * FPS))
	_poser_camera(_dessus_de(p) + Vector3(0, -3, 5), -0.2, 0.55, 22.0)
	await _images(int(1.0 * FPS))
	for nom in ["Glowing acid", "Lava", "Stylized (RiverStones)"]:
		await _choisir_dans_la_liste(_ecran._preset_eau, nom, "Look: " + nom)
		await _images(int(1.4 * FPS))
	await _touche(KEY_ESCAPE, "Esc", "Back to World")
	await _images(10)


## Le modeleur : Geometry, Tab (édition), 3 (faces), un clic, E et la souris (extruder), les vues du pavé.
func _geometrie() -> void:
	await _cliquer_bouton("Geometry", "Geometry workshop")
	await _images(15)
	_poser_camera(Vector3(6, 6, 6), 0.5, 0.5, 27.0)
	await _images(10)
	await _touche(KEY_TAB, "Tab", "Edit the witness")
	await _touche(KEY_3, "3", "Face mode")
	var cible: Vector2 = _vue.size * 0.5 + Vector2(-100, -120)
	await _bouger(_vue.get_global_transform_with_canvas() * cible, 0.6)
	await _clic(MOUSE_BUTTON_LEFT, "Click", "Pick a face of one tile")
	await _touche(KEY_E, "E", "Extrude — every copy follows")
	await _bouger(_souris + Vector2(0, -110), 1.6)
	await _clic(MOUSE_BUTTON_LEFT, "Click", "Confirm")
	await _images(int(0.8 * FPS))
	await _touche(KEY_KP_7, "Numpad 7", "Top view")
	await _images(int(0.8 * FPS))
	await _touche(KEY_KP_1, "Numpad 1", "Front view")
	await _images(int(0.8 * FPS))
	await _touche(KEY_KP_5, "Numpad 5", "Orthographic")
	await _images(int(0.8 * FPS))
	await _touche(KEY_KP_5, "Numpad 5", "Perspective")
	await _touche(KEY_Z, "Ctrl + Z", "Undo", true)
	await _touche(KEY_TAB, "Tab", "Leave edit mode")
	await _cliquer_bouton("World", "Back to World")
	await _images(10)


## Le Play test : marcher, courir, sauter, voler, et Échap.
func _jeu() -> void:
	_vue._cible = Vector3(Ile.LAC.x + 7, Ile.PLATEAU + 3, Ile.LAC.y - 4)
	_vue._caler()
	await _cliquer_bouton("Play test", "Play test")
	await _images(int(1.0 * FPS))
	await _tenir(KEY_W, 2.0, "W A S D", "Walk (Z Q S D on AZERTY)")
	await _tenir_avec(KEY_W, KEY_SHIFT, 1.6, "Shift", "Run")
	await _touche(KEY_SPACE, "Space", "Jump")
	await _images(int(1.0 * FPS))
	await _touche(KEY_F, "F", "Fly")
	await _tenir_avec(KEY_W, KEY_SPACE, 1.6, "Space", "Fly up")
	await _touche(KEY_F, "F", "Land")
	await _images(int(1.2 * FPS))
	await _touche(KEY_ESCAPE, "Esc", "Back to World")
	await _images(10)


## Le manuel : F1, puis Échap.
func _manuel() -> void:
	await _touche(KEY_F1, "F1", "The manual, inside the app")
	await _images(int(2.0 * FPS))
	await _touche(KEY_ESCAPE, "Esc", "Close")
	await _images(10)


# ── LES GESTES (de vrais événements) ─────────────────────────────────────────────────────────────────

func _envoyer(e: InputEvent) -> void:
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _bouger(vers: Vector2, duree: float) -> void:
	var depuis := _souris
	var n := maxi(1, int(duree * FPS))
	for i in n:
		var t := _doux(float(i + 1) / float(n))
		var avant := _souris
		_souris = depuis.lerp(vers, t)
		var m := InputEventMouseMotion.new()
		m.position = _souris
		m.global_position = _souris
		m.relative = _souris - avant
		m.button_mask = _masque
		m.shift_pressed = Input.is_key_pressed(KEY_SHIFT)
		_envoyer(m)
		await _images(1)


func _presser(bouton: int, oui: bool, shift := false) -> void:
	var b := InputEventMouseButton.new()
	b.button_index = bouton
	b.pressed = oui
	b.position = _souris
	b.global_position = _souris
	b.shift_pressed = shift
	var bit := 1 << (bouton - 1)
	_masque = (_masque | bit) if oui else (_masque & ~bit)
	b.button_mask = _masque
	_envoyer(b)


func _clic(bouton: int, carte := "", detail := "") -> void:
	if carte != "":
		_montrer(carte, detail)
	_presser(bouton, true)
	await _images(3)
	_presser(bouton, false)
	await _images(int(0.5 * FPS))


func _cle(k: Key, oui: bool, ctrl := false, shift := false) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = oui
	e.ctrl_pressed = ctrl
	e.shift_pressed = shift
	_envoyer(e)


func _touche(k: Key, carte: String, detail: String, ctrl := false, shift := false) -> void:
	_montrer(carte, detail)
	await _images(int(0.35 * FPS))
	if ctrl:
		_cle(KEY_CTRL, true)
	if shift:
		_cle(KEY_SHIFT, true)
	_cle(k, true, ctrl, shift)
	await _images(2)
	_cle(k, false, ctrl, shift)
	if shift:
		_cle(KEY_SHIFT, false)
	if ctrl:
		_cle(KEY_CTRL, false)
	await _images(int(0.65 * FPS))


func _tenir(k: Key, duree: float, carte: String, detail: String) -> void:
	_montrer(carte, detail)
	_cle(k, true)
	await _images(int(duree * FPS))
	_cle(k, false)


func _tenir_avec(k: Key, k2: Key, duree: float, carte: String, detail: String) -> void:
	_montrer(carte, detail)
	_cle(k2, true)
	_cle(k, true)
	await _images(int(duree * FPS))
	_cle(k, false)
	_cle(k2, false)


func _molette(sens: int, crans: int, carte: String, detail: String) -> void:
	_montrer(carte, detail)
	for i in crans:
		_presser(sens, true)
		_presser(sens, false)
		await _images(4)


func _glisser_milieu(delta: Vector2, duree: float, carte: String, detail: String, shift := false) -> void:
	_montrer(carte, detail)
	if shift:
		_cle(KEY_SHIFT, true)
	_presser(MOUSE_BUTTON_MIDDLE, true, shift)
	await _bouger(_souris + delta, duree)
	_presser(MOUSE_BUTTON_MIDDLE, false, shift)
	if shift:
		_cle(KEY_SHIFT, false)
	await _images(6)


## Un glissé du clic gauche sur la matière, de la colonne `a` à la colonne `b`.
func _peindre_ligne(a: Vector2i, b: Vector2i, duree: float, carte: String, detail: String) -> void:
	await _bouger(_sur(_dessus_de(a)), 0.4)
	_montrer(carte, detail)
	_presser(MOUSE_BUTTON_LEFT, true)
	var n := int(duree * FPS)
	var depuis := _souris
	for i in n:
		var t := float(i + 1) / float(n)
		var c := Vector2(a).lerp(Vector2(b), t)
		var avant := _souris
		_souris = _sur(_dessus_de(Vector2i(roundi(c.x), roundi(c.y))))
		var m := InputEventMouseMotion.new()
		m.position = _souris
		m.global_position = _souris
		m.relative = _souris - avant
		m.button_mask = _masque
		_envoyer(m)
		await _images(1)
	_presser(MOUSE_BUTTON_LEFT, false)
	await _images(4)


## Le bouton visible dont le texte est `texte` : la souris y va et clique. ⚠ S'il est sous le bord de l'image (la
## section Selection pousse les autres vers le bas), la MOLETTE fait défiler son panneau, comme le ferait la main.
func _cliquer_bouton(texte: String, detail: String, infobulle := "") -> void:
	var b := _bouton(_ecran, texte, infobulle)
	if b == null:
		print("⚠ bouton introuvable : %s" % texte)
		return
	var ecran := Rect2(Vector2(0, 40), Vector2(root.size) - Vector2(0, 40))
	if not ecran.encloses(b.get_global_rect()):
		var defile := b.get_parent()
		while defile != null and not defile is ScrollContainer:
			defile = defile.get_parent()
		if defile != null:
			await _bouger((defile as Control).get_global_rect().get_center(), 0.4)
			var sens := MOUSE_BUTTON_WHEEL_DOWN if b.get_global_rect().end.y > ecran.end.y else MOUSE_BUTTON_WHEEL_UP
			for i in 40:
				if ecran.encloses(b.get_global_rect()):
					break
				_presser(sens, true)
				_presser(sens, false)
				await _images(2)
			# ⚠ LE DÉFILEMENT GLISSE ENCORE quelques images : on attend qu'il s'arrête avant de viser (sinon le clic
			# tombait sur le titre au-dessus du bouton, et « Fill » ne réparait rien).
			await _images(12)
	var r := b.get_global_rect()
	await _bouger(r.get_center(), 0.6)
	await _clic(MOUSE_BUTTON_LEFT, "Click", detail)


func _bouton(n: Node, texte: String, infobulle := "") -> BaseButton:
	if n is Button and (n as Button).is_visible_in_tree() and (n as Button).text.strip_edges() == texte 			and (infobulle == "" or (n as Button).tooltip_text.begins_with(infobulle)):
		return n
	for e in n.get_children():
		var t := _bouton(e, texte, infobulle)
		if t != null:
			return t
	return null


## Une liste déroulante : un clic l'ouvre, les flèches descendent jusqu'au nom, Entrée le prend.
func _choisir_dans_la_liste(liste: OptionButton, nom: String, detail: String) -> void:
	await _bouger(liste.get_global_rect().get_center(), 0.5)
	await _clic(MOUSE_BUTTON_LEFT, "Click", detail)
	var cible := -1
	for i in liste.item_count:
		if liste.get_item_text(i) == nom:
			cible = i
	var popup := liste.get_popup()
	if cible < 0 or not popup.visible:
		print("⚠ liste : %s introuvable ou fermée" % nom)
		return
	var r: Rect2 = popup.get_item_rect(cible) if popup.has_method("get_item_rect") else Rect2()
	if r.size != Vector2.ZERO:
		await _bouger(Vector2(popup.position) + r.get_center(), 0.4)
		await _clic(MOUSE_BUTTON_LEFT)
	else:
		popup.hide()
		liste.select(cible)
		liste.item_selected.emit(cible)


## `-- --seulement=boutons` : la liste des boutons visibles, leur texte et leur place (la mise au point).
func _lister(n: Node) -> void:
	if n is BaseButton and (n as Control).is_visible_in_tree():
		print("BOUTON %s « %s » %s tip=%s" % [n.get_class(), n.get("text"), (n as Control).get_global_rect(),
			str((n as Control).tooltip_text).left(40)])
	for e in n.get_children():
		_lister(e)


# ── LA CAMÉRA ET LES LIEUX ───────────────────────────────────────────────────────────────────────────

func _poser_camera(cible: Vector3, azimut: float, elevation: float, distance: float) -> void:
	_vue._cible = cible
	_vue._azimut = azimut
	_vue._elevation = elevation
	_vue._distance = distance
	_vue._caler()


## Le dessus de la colonne (x, z) de l'île : le centre de sa face haute.
func _dessus_de(p: Vector2i) -> Vector3:
	return Vector3(p.x + 0.5, _ile.hauteur(p.x, p.y) + 1.0, p.y + 0.5)


## Un point du monde, en pixels de la fenêtre.
func _sur(monde: Vector3) -> Vector2:
	var local: Vector2 = _vue._camera.unproject_position(monde)
	return _vue.get_global_transform_with_canvas() * local


# ── LES AIDES DE TOURNAGE : le curseur et la carte de la touche ─────────────────────────────────────

func _aides() -> void:
	_police = FontFile.new()
	_police.load_dynamic_font(POLICE)
	_calque = CanvasLayer.new()
	_calque.layer = 120
	root.add_child(_calque)
	_dessin = Control.new()
	_dessin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dessin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dessin.draw.connect(_dessiner)
	_calque.add_child(_dessin)


func _montrer(carte: String, detail: String) -> void:
	_carte = carte
	_carte_detail = detail
	_carte_age = 0.0


func _dessiner() -> void:
	# La carte : la touche dans un cadre, puis ce qu'elle fait. Elle s'efface après 2,2 s.
	if _carte != "" and _carte_age < 2.2:
		var a := clampf(minf(_carte_age / 0.12, (2.2 - _carte_age) / 0.3), 0.0, 1.0)
		var tc := 34
		var td := 30
		var lc := _police.get_string_size(_carte, HORIZONTAL_ALIGNMENT_LEFT, -1, tc).x
		var ld := _police.get_string_size(_carte_detail, HORIZONTAL_ALIGNMENT_LEFT, -1, td).x
		var largeur := lc + 40 + 24 + ld + 48
		var x0 := (_dessin.size.x - largeur) * 0.5
		var y0 := _dessin.size.y - 150
		var fond := StyleBoxFlat.new()
		fond.bg_color = Color(0.07, 0.06, 0.1, 0.86 * a)
		fond.set_corner_radius_all(14)
		_dessin.draw_style_box(fond, Rect2(x0, y0, largeur, 72))
		var cle := StyleBoxFlat.new()
		cle.bg_color = Color(1, 1, 1, 0.12 * a)
		cle.border_color = Color(0.79, 0.63, 0.27, a)
		cle.set_border_width_all(2)
		cle.set_corner_radius_all(8)
		_dessin.draw_style_box(cle, Rect2(x0 + 18, y0 + 12, lc + 40, 48))
		_dessin.draw_string(_police, Vector2(x0 + 38, y0 + 48), _carte, HORIZONTAL_ALIGNMENT_LEFT, -1, tc,
			Color(1, 1, 1, a))
		_dessin.draw_string(_police, Vector2(x0 + 18 + lc + 40 + 24, y0 + 47), _carte_detail,
			HORIZONTAL_ALIGNMENT_LEFT, -1, td, Color(0.85, 0.85, 0.9, a))
	# Le curseur : une flèche blanche cernée de noir.
	var p := _souris
	var fleche := PackedVector2Array([p, p + Vector2(0, 26), p + Vector2(7, 20), p + Vector2(12, 31),
		p + Vector2(16, 29), p + Vector2(11, 18), p + Vector2(19, 18)])
	_dessin.draw_colored_polygon(fleche, Color.WHITE)
	var bord := fleche.duplicate()
	bord.append(p)
	_dessin.draw_polyline(bord, Color.BLACK, 2.0, true)


# ── L'OUTILLAGE ──────────────────────────────────────────────────────────────────────────────────────

func _doux(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _plan(nom: String) -> void:
	print("PLAN %s image %d (%.2f s)" % [nom, _image, _image / FPS])


func _images(n: int) -> void:
	for i in n:
		await process_frame
		_image += 1
		_carte_age += 1.0 / FPS
		# ⚠ Au Play test, le bras de la caméra rentre contre le décor : on la tient haute et à distance.
		if _ecran != null and _ecran._atelier == "jeu" and _vue != null:
			_vue._distance = 7.5
			_vue._elevation = 0.5
		if _dessin != null:
			_dessin.queue_redraw()


func _vider(chemin: String) -> void:
	if not DirAccess.dir_exists_absolute(chemin):
		return
	for d in DirAccess.get_directories_at(chemin):
		_vider(chemin.path_join(d))
	for f in DirAccess.get_files_at(chemin):
		DirAccess.remove_absolute(chemin.path_join(f))
	DirAccess.remove_absolute(chemin)


func _rendre_les_reglages() -> void:
	if FileAccess.file_exists(SAUVEGARDE):
		DirAccess.copy_absolute(SAUVEGARDE, REGLAGES)
		DirAccess.remove_absolute(SAUVEGARDE)
