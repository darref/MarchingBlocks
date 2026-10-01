extends Control
## LA LÉGENDE DES FORMES — un bandeau en haut de la vue, dans l'atelier Witness.
##
## **DEMANDÉ PAR JORDAN (29 septembre 2026)** : « on ne reconnaît pas encore du premier coup d'œil ce
## qu'il faut altérer au witness pour retrouver quoi et où dans le monde ». Une carte par forme : une
## PHOTO du vrai témoin cadrée sur elle, un renvoi qui pointe la zone, son nom, et ce qu'elle devient dans
## le monde. Le bandeau se replie d'un clic sur la flèche qui le longe.
##
## ⚠ **ET LA CARTE MONTRE AUSSI DANS LA VUE** : survoler une carte allume la même zone dans le témoin
## qu'on regarde, un clic y cadre la vue, sous le même angle que la photo. Une photo dit « c'est là » ;
## la zone allumée dans le bloc qu'on va sculpter le dit sans avoir à comparer deux images.
##
## ⚠ **LES PHOTOS SONT PRISES À L'OUVERTURE, SUR LE VRAI TÉMOIN — PAS DES PNG LIVRÉS.** Des images
## rangées dans le dépôt mentiraient le jour où l'on recolle un autre témoin (charte §6, on déduit). Une
## `SubViewport` par carte, rendue UNE fois (`UPDATE_ONCE`), sans rien attendre : attendre une image
## (`frame_post_draw`) pend en headless, la fumée l'a déjà payé.
##
## ⚠ **UNE FORME DE GROTTE EST ENFERMÉE DANS LA ROCHE** : photographiée de dehors, on ne verrait qu'un
## flanc de massif. L'angle est choisi parmi seize pour traverser le moins de matière possible, et s'il
## en reste, le plan proche de la caméra la COUPE (un écorché) : ce qui est devant la forme disparaît.
## ⚠ Le flanc coupé est ouvert, et c'est ce qui fait marcher l'écorché : vues de dedans, les faces de la
## roche sont de dos, donc écartées, et l'on voit à travers jusqu'à la salle.

const FT := preload("res://addons/marchingblocks_core/formes_du_temoin.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const Palette := preload("res://app/palette.gd")
const Panneau := preload("res://app/panneau.gd")
const PlancheTuiles := preload("res://app/planche_tuiles.gd")

## Survol d'une carte : ses cases (vide = plus rien de survolé).
signal zone_survolee(cases: Array)
## Clic sur une carte : cadrer la vue sur ses cases, depuis l'angle de sa photo.
signal zone_choisie(cases: Array, azimut: float, elevation: float)
## World : « Show in the witness » — le sommet d'où vient la tuile, et la carte qui le contient.
signal voir_dans_le_temoin(sommet: Vector3i, carte: Dictionary, azimut: float, elevation: float)
## La planche des tuiles : un clic sur une tuile (l'écran y cadre, et la met en édition si l'on édite).
signal tuile_choisie(cle: String)
## La planche des tuiles : les copies de la tuile survolée (allumées en petits cubes).
signal copies_survolees(cases: Array)

const PHOTO := Vector2i(224, 126)
const HAUTEUR := 238.0
## La poignée : la flèche qui longe le bord bas du bandeau, et reste là quand il est replié.
const POIGNEE := 18.0
const LARGEUR_ONGLET := 176.0
const TEINTE_ZONE := Color(0.949, 0.792, 0.475, 0.34)

var ouvert := true
var cartes: Array = []
var _ouverture := 1.0
var _panneau: Panneau
var _poignee: Control
var _rangee: HBoxContainer
var _anime: Tween
## "witness" : les cartes des formes. "monde" : D'OÙ VIENT la tuile qu'on survole — le sens inverse.
var atelier := "witness"
var _defile: ScrollContainer
## ── LES DEUX ONGLETS DE WITNESS (charte §3, 30 septembre 2026) : les FORMES du témoin, et la PLANCHE des
## tuiles qu'un monde emploie. `fournir_temoin` rend le témoin lié à montrer (celui qu'on édite s'il est
## chargé) : la planche est bâtie au premier passage sur son onglet.
var onglet_courant := "formes"
var fournir_temoin: Callable
var planche: ScrollContainer
var _contenu: HBoxContainer
var _bouton_formes: Button
var _bouton_tuiles: Button
## Par identifiant de carte : {"texture", "camera", "angle"} — la provenance réutilise les photos.
var _photos := {}
var _provenance: Control
var _p_photo: TextureRect
var _p_renvoi: Control
var _p_titre: Label
var _p_nom: Label
var _p_monde: Label
var _p_detail: Label
var _p_aussi: Label
var _p_voir: Button
## Ce que la provenance montre : {"sommet": Vector3i (du témoin), "carte": Dictionary} ou {}.
var provenance := {}
## Le témoin en cases, lu une fois : seize angles par carte le consultent.
static var _pleines := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panneau = Panneau.new()
	var style := Palette.fond(Palette.PANNEAU, 0, 8)
	style.border_color = Palette.FILET
	style.border_width_bottom = 1
	_panneau.add_theme_stylebox_override("panel", style)
	_panneau.clip_contents = true
	_panneau.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_panneau.offset_left = 0.0
	_panneau.offset_right = 0.0
	add_child(_panneau)
	_contenu = HBoxContainer.new()
	_contenu.add_theme_constant_override("separation", 10)
	_panneau.add_child(_contenu)
	_contenu.add_child(_onglets())
	var defile := ScrollContainer.new()
	# ⚠ SHOW_NEVER ET NON DISABLED : un défilement désactivé prend la hauteur de son contenu pour taille
	# minimale, et le bandeau ne pourrait plus se replier.
	defile.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	defile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenu.add_child(defile)
	_defile = defile
	planche = PlancheTuiles.new()
	planche.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	planche.visible = false
	_contenu.add_child(planche)
	planche.zone_survolee.connect(func(c: Array) -> void: copies_survolees.emit(c))
	planche.tuile_choisie.connect(func(cle: String) -> void: tuile_choisie.emit(cle))
	_rangee = HBoxContainer.new()
	_rangee.add_theme_constant_override("separation", 10)
	defile.add_child(_rangee)
	_rangee.add_child(_intro())

	var temoin: Mesh = BM.maillage_moitie(0)
	for carte in FT.legende():
		cartes.append(carte)
		_rangee.add_child(_carte(carte, temoin))
	_batir_provenance()

	_poignee = Control.new()
	_poignee.mouse_filter = Control.MOUSE_FILTER_STOP
	_poignee.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_poignee.tooltip_text = "Show or hide this strip"
	_poignee.draw.connect(_dessiner_poignee)
	_poignee.gui_input.connect(_clic_poignee)
	_poignee.mouse_entered.connect(_poignee.queue_redraw)
	_poignee.mouse_exited.connect(_poignee.queue_redraw)
	add_child(_poignee)
	_placer()


## Ouvre ou replie le bandeau, en glissant.
func basculer(oui: bool, anime := true) -> void:
	ouvert = oui
	if _anime != null:
		_anime.kill()
	if not anime or not is_inside_tree():
		_ouverture = 1.0 if oui else 0.0
		_placer()
		return
	_anime = create_tween()
	_anime.tween_method(_regler_ouverture, _ouverture, 1.0 if oui else 0.0, 0.22)
	_anime.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _regler_ouverture(t: float) -> void:
	_ouverture = t
	_placer()


## La hauteur que le bandeau occupe réellement, poignée comprise.
func hauteur() -> float:
	return HAUTEUR * _ouverture + POIGNEE


func _placer() -> void:
	var h := HAUTEUR * _ouverture
	_panneau.visible = h > 0.5
	_panneau.offset_top = 0.0
	_panneau.offset_bottom = h
	_poignee.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_poignee.offset_left = 0.0
	_poignee.offset_right = 0.0
	_poignee.offset_top = h - 1.0
	_poignee.offset_bottom = h - 1.0 + POIGNEE
	offset_bottom = offset_top + hauteur()
	_poignee.queue_redraw()


## LA POIGNÉE — un filet qui longe TOUT le bord du bandeau, et au milieu un onglet avec son chevron.
## ⚠ Le filet reste quand le bandeau est replié : on voit qu'il y a quelque chose là-haut, et où cliquer.
func _dessiner_poignee() -> void:
	var l := _poignee.size.x
	var survol := _poignee.get_global_rect().has_point(_poignee.get_global_mouse_position())
	var accent := Palette.AMBRE if survol else Palette.OLIVE
	_poignee.draw_line(Vector2(0, 1), Vector2(l, 1), Color(accent, 0.55), 2.0)
	var x0 := (l - LARGEUR_ONGLET) * 0.5
	var onglet := PackedVector2Array([Vector2(x0 - 8, 0), Vector2(x0 + LARGEUR_ONGLET + 8, 0),
		Vector2(x0 + LARGEUR_ONGLET, POIGNEE - 1), Vector2(x0, POIGNEE - 1)])
	_poignee.draw_colored_polygon(onglet, Palette.BANDE_SURVOL if survol else Palette.BANDE)
	var bord := onglet.duplicate()
	bord.append(onglet[0])
	_poignee.draw_polyline(bord, Color(accent, 0.8), 1.0, true)
	# Le chevron : vers le haut quand le bandeau est ouvert (le replier), vers le bas sinon.
	var cx := x0 + 16.0
	var cy := POIGNEE * 0.5
	var s := 4.0 if ouvert else -4.0
	_poignee.draw_polyline(PackedVector2Array([Vector2(cx - 5, cy + s * 0.5), Vector2(cx, cy - s * 0.5),
		Vector2(cx + 5, cy + s * 0.5)]), accent, 2.0, true)
	var police: Font = Palette.gras()
	_poignee.draw_string(police, Vector2(cx + 12, cy + 4),
		"WHERE IS IT FROM?" if atelier == "monde" else ("THE TILES" if onglet_courant == "tuiles" else "WITNESS SHAPES"),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1, 10, accent)


func _clic_poignee(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		basculer(not ouvert)
		_poignee.accept_event()


## Les deux onglets, à gauche du bandeau : les formes, ou les tuiles.
func _onglets() -> Control:
	var boite := VBoxContainer.new()
	boite.add_theme_constant_override("separation", 4)
	boite.custom_minimum_size = Vector2(92, 0)
	_bouton_formes = _bouton_d_onglet("Shapes", "The shapes of the witness, and what each becomes in a world.")
	_bouton_formes.pressed.connect(func() -> void: montrer_onglet("formes"))
	boite.add_child(_bouton_formes)
	_bouton_tuiles = _bouton_d_onglet("The tiles", "Every tile a world is built from, one per class, and "
		+ "all its copies in the witness.")
	_bouton_tuiles.pressed.connect(func() -> void: montrer_onglet("tuiles"))
	boite.add_child(_bouton_tuiles)
	_bouton_formes.set_pressed_no_signal(true)
	return boite


func _bouton_d_onglet(texte: String, aide: String) -> Button:
	var b := Button.new()
	b.text = texte
	b.tooltip_text = aide
	b.toggle_mode = true
	b.add_theme_font_size_override("font_size", 11)
	b.custom_minimum_size = Vector2(92, 26)
	return b


## Montre les formes ou la planche des tuiles. La planche se bâtit au premier passage.
func montrer_onglet(nom: String) -> void:
	onglet_courant = nom
	if nom == "tuiles" and not planche.est_batie() and fournir_temoin.is_valid():
		planche.batir(fournir_temoin.call())
	_bouton_formes.set_pressed_no_signal(nom == "formes")
	_bouton_tuiles.set_pressed_no_signal(nom == "tuiles")
	regler_atelier(atelier)


## La planche rebâtie sur le témoin d'une AUTRE couche (la couche active a changé), si elle l'était déjà.
func reconstruire_tuiles() -> void:
	if planche.est_batie() and fournir_temoin.is_valid():
		planche.batir(fournir_temoin.call())


## Les photos de la planche reprises sur les tuiles du témoin (après un geste du modeleur).
func rafraichir_tuiles() -> void:
	if planche.est_batie() and fournir_temoin.is_valid():
		planche.rafraichir(fournir_temoin.call())


func _intro() -> Control:
	var boite := VBoxContainer.new()
	boite.custom_minimum_size = Vector2(150, 0)
	boite.add_theme_constant_override("separation", 6)
	var titre := Label.new()
	titre.text = "WHAT BECOMES WHAT"
	titre.add_theme_font_override("font", Palette.gras())
	titre.add_theme_font_size_override("font_size", 12)
	titre.add_theme_color_override("font_color", Palette.OLIVE)
	boite.add_child(titre)
	var texte := Label.new()
	texte.text = ("Each shape of the witness becomes these places in your world. Sculpt it here, "
		+ "find it there.\n\nHover a shape to light it up in the witness; click to look at it.")
	texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texte.custom_minimum_size = Vector2(150, 0)
	texte.add_theme_font_size_override("font_size", 11)
	texte.add_theme_color_override("font_color", Palette.GRIS)
	boite.add_child(texte)
	return boite


func _carte(carte: Dictionary, temoin: Mesh) -> Control:
	var cases: Array = carte["cases"]
	var angle := angle_de_vue(cases)
	var fond := PanelContainer.new()
	fond.mouse_filter = Control.MOUSE_FILTER_STOP
	fond.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	fond.custom_minimum_size = Vector2(PHOTO.x + 12, 0)
	fond.tooltip_text = "%s — %d tiles are cut here: sculpting it changes them.\nClick to look at it in the witness." \
		% [carte["nom"], (carte["cles"] as Array).size()]
	var repos := Palette.fond(Palette.SOMBRE, 5, 6)
	var survol := Palette.fond(Palette.BOUTON_SURVOL, 5, 6)
	survol.border_color = Palette.AMBRE
	survol.set_border_width_all(1)
	fond.add_theme_stylebox_override("panel", repos)
	fond.set_meta("carte", carte)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 3)
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.add_child(colonne)

	var vue := _photographier(cases, angle, temoin)
	fond.add_child(vue)
	_photos[carte["id"]] = {"texture": vue.get_texture(), "camera": vue.get_meta("camera"), "angle": angle}
	var photo := TextureRect.new()
	photo.texture = vue.get_texture()
	photo.custom_minimum_size = Vector2(PHOTO)
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(photo)

	var nom := Label.new()
	nom.text = String(carte["nom"]).to_upper()
	nom.add_theme_font_override("font", Palette.gras())
	nom.add_theme_font_size_override("font_size", 12)
	nom.add_theme_color_override("font_color", Palette.AMBRE)
	nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# La place du renvoi qui descend de la photo jusqu'au nom ; le compte à droite, sur la même ligne.
	var marge := MarginContainer.new()
	marge.add_theme_constant_override("margin_left", 14)
	marge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ligne := HBoxContainer.new()
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marge.add_child(ligne)
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne.add_child(nom)
	var compte := Label.new()
	compte.text = "%d tiles" % (carte["cles"] as Array).size()
	compte.add_theme_font_size_override("font_size", 10)
	compte.add_theme_color_override("font_color", Palette.GRIS)
	compte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(compte)
	colonne.add_child(marge)
	var monde := Label.new()
	monde.text = carte["monde"]
	monde.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	monde.custom_minimum_size = Vector2(PHOTO.x, 0)
	monde.add_theme_font_size_override("font_size", 11)
	monde.add_theme_color_override("font_color", Palette.TEXTE)
	monde.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(monde)

	# LE TRAIT : du nom, il monte dans la photo puis va à la zone — un renvoi de dessin technique.
	var renvoi := Control.new()
	renvoi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	renvoi.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.add_child(renvoi)
	var camera: Camera3D = vue.get_meta("camera")
	var centre: Vector3 = centre_de(cases)
	renvoi.draw.connect(func() -> void:
		if not camera.is_inside_tree():
			return
		var p: Vector2 = camera.unproject_position(centre)
		var echelle: float = photo.size.x / float(PHOTO.x)
		var cible: Vector2 = photo.position + p * echelle
		var depart := Vector2(marge.position.x + 7, marge.position.y + marge.size.y * 0.5)
		var coude := Vector2(depart.x, cible.y)
		var c := Palette.AMBRE
		var ombre := Color(0, 0, 0, 0.7)
		var trace := PackedVector2Array([depart + Vector2(4, 0), depart, coude, cible])
		# ⚠ UN LISERÉ SOMBRE SOUS LE TRAIT : la zone est ambrée elle aussi, et le rond s'y perdait (vu à l'image).
		renvoi.draw_polyline(trace, ombre, 4.0, true)
		renvoi.draw_arc(cible, 6.0, 0.0, TAU, 24, ombre, 4.0, true)
		renvoi.draw_polyline(trace, c, 1.5, true)
		renvoi.draw_arc(cible, 6.0, 0.0, TAU, 24, Color.WHITE, 1.5, true)
		renvoi.draw_circle(cible, 2.2, Color.WHITE))
	renvoi.resized.connect(renvoi.queue_redraw)
	fond.resized.connect(renvoi.queue_redraw)

	fond.set_meta("styles", [repos, survol])
	fond.mouse_entered.connect(func() -> void:
		mettre_en_avant("")
		fond.add_theme_stylebox_override("panel", survol)
		zone_survolee.emit(cases))
	fond.mouse_exited.connect(func() -> void:
		fond.add_theme_stylebox_override("panel", repos)
		zone_survolee.emit([]))
	fond.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			zone_choisie.emit(cases, angle.x, angle.y)
			fond.accept_event())
	return fond


## ── LE SENS INVERSE : D'OÙ VIENT CETTE TUILE ? (atelier World, Jordan, 29 septembre 2026) ─────────────
##
## Dans World, le bandeau ne montre plus toutes les formes : il dit, pour la tuile sous la souris, DE
## QUELLE FORME du témoin elle a été découpée — la photo de la forme, un renvoi qui pointe l'endroit
## EXACT (le sommet d'où vient la tuile), et un bouton qui va l'y voir.
## ⚠ **L'ENDROIT EXACT, PAS SEULEMENT LA FORME** : le lot sait d'où vient chaque tuile
## (`BlocsMaitres.META_SOMMETS`). Depuis le 30 septembre 2026 une clé porte UNE tuile (charte §3) : avec le
## témoin lié, la sculpter à n'importe laquelle de ses copies la change partout ; avec un travail non lié,
## seul ce coin-là est lu.

func regler_atelier(a: String) -> void:
	atelier = a
	_contenu.visible = a != "monde"
	_defile.visible = a != "monde" and onglet_courant == "formes"
	planche.visible = a != "monde" and onglet_courant == "tuiles"
	_provenance.visible = a == "monde"
	if a == "monde":
		montrer_provenance({})
	_poignee.queue_redraw()


func _batir_provenance() -> void:
	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", 14)
	_panneau.add_child(rangee)
	_provenance = rangee
	_provenance.visible = false
	var cadre := Control.new()
	cadre.custom_minimum_size = Vector2(PHOTO)
	cadre.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rangee.add_child(cadre)
	_p_photo = TextureRect.new()
	_p_photo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_p_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_p_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cadre.add_child(_p_photo)
	_p_renvoi = Control.new()
	_p_renvoi.set_anchors_preset(Control.PRESET_FULL_RECT)
	_p_renvoi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p_renvoi.draw.connect(_dessiner_renvoi_de_provenance)
	cadre.add_child(_p_renvoi)
	var texte := VBoxContainer.new()
	texte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texte.add_theme_constant_override("separation", 4)
	rangee.add_child(texte)
	_p_titre = _etiquette(texte, 11, Palette.GRIS, true)
	_p_nom = _etiquette(texte, 16, Palette.AMBRE, true)
	_p_monde = _etiquette(texte, 12, Palette.TEXTE)
	_p_detail = _etiquette(texte, 11, Palette.GRIS)
	_p_aussi = _etiquette(texte, 11, Palette.GRIS)
	_p_voir = Button.new()
	_p_voir.text = "Show it in the witness"
	_p_voir.focus_mode = Control.FOCUS_NONE
	_p_voir.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_p_voir.tooltip_text = "Go to the Witness workshop and look at the exact spot this tile was cut from."
	_p_voir.pressed.connect(voir)
	texte.add_child(_p_voir)


## Encadre une carte et la fait défiler jusqu'à l'écran ("" : n'en encadre aucune). C'est la forme d'où
## vient la tuile qu'on est venu voir depuis World.
func mettre_en_avant(id: String) -> void:
	for enfant in _rangee.get_children():
		if not enfant.has_meta("carte"):
			continue
		var styles: Array = enfant.get_meta("styles")
		var elle: bool = enfant.get_meta("carte")["id"] == id
		(enfant as Control).add_theme_stylebox_override("panel", styles[1] if elle else styles[0])
		if elle:
			_defile.ensure_control_visible(enfant)


## « Show it in the witness » — le bouton, et ce que la fumée appelle.
func voir() -> void:
	if provenance.is_empty():
		return
	var angle: Vector2 = _photos[provenance["carte"]["id"]]["angle"]
	voir_dans_le_temoin.emit(provenance["sommet"], provenance["carte"], angle.x, angle.y)


func _etiquette(parent: Control, taille: int, couleur: Color, gras := false) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	if gras:
		l.add_theme_font_override("font", Palette.gras())
	parent.add_child(l)
	return l


## `info` : ce que `vue.tuile_sous` rend — {"sommet" (du MONDE), "nom", "faute", "lot"}, ou {}.
func montrer_provenance(info: Dictionary) -> void:
	provenance = {}
	_p_photo.texture = null
	_p_voir.visible = false
	_p_aussi.text = ""
	_p_detail.text = ""
	if info.is_empty():
		_p_titre.text = "WHERE IS IT FROM?"
		_p_nom.text = "Hover a tile"
		_p_monde.text = ("Point at a tile of the active layer: this strip names the shape of the witness it "
			+ "was cut from, and the exact spot to sculpt to change it.")
	elif bool(info["faute"]):
		_p_titre.text = "RED CUBE"
		_p_nom.text = "No tile here"
		_p_monde.text = ("This layer's library has no tile for this spot, so nothing was cut for it. "
			+ "Nothing is ever filled in for you.")
	elif String(info["nom"]) == "":
		_p_titre.text = "WHERE IS IT FROM?"
		_p_nom.text = "No tile at this corner"
		_p_monde.text = "Nothing is placed right here: move along the surface."
	else:
		var nom: String = info["nom"]
		var source: Variant = FT.sommet_source(info["lot"], nom)
		if source == null:
			_p_titre.text = "BUILT-IN TILES"
			_p_nom.text = "Not from a witness"
			_p_monde.text = ("This layer shows the built-in fallback tiles. Slice the witness or your "
				+ "artist's work into it (Project, step 3) to see where each tile comes from.")
		else:
			_dire_la_provenance(info, nom, source)
	_p_renvoi.queue_redraw()


func _dire_la_provenance(info: Dictionary, nom: String, source: Vector3i) -> void:
	var MB := FT.MB
	var candidates: Array = FT.cartes_du_sommet(cartes, source)
	var contexte := " (open-air version)" if nom.ends_with(MB.SUFFIXE_DEHORS) else ""
	# ⚠ UNE TUILE PAR CLÉ (charte §3) : plus de « copy k of N » — la tuile est la même partout où elle revient.
	_p_detail.text = "This tile%s was cut at the witness corner (%d, %d, %d); it is the same wherever it appears." \
		% [contexte, source.x, source.y, source.z]
	_p_titre.text = "THIS TILE WAS CUT FROM"
	if candidates.is_empty():
		_p_nom.text = "The witness"
		_p_monde.text = "This corner belongs to no named shape."
		return
	var carte: Dictionary = candidates[0]
	provenance = {"sommet": source, "carte": carte}
	_p_nom.text = String(carte["nom"]).to_upper()
	_p_monde.text = carte["monde"]
	var noms: Array = []
	for autre in candidates.slice(1):
		noms.append(autre["nom"])
	if not noms.is_empty():
		_p_aussi.text = "Also inside: " + ", ".join(PackedStringArray(noms))
	_p_photo.texture = _photos[carte["id"]]["texture"]
	_p_voir.visible = true


## Le renvoi de la provenance : il part du bord droit de la photo et pointe le SOMMET exact.
func _dessiner_renvoi_de_provenance() -> void:
	if provenance.is_empty():
		return
	var camera: Camera3D = _photos[provenance["carte"]["id"]]["camera"]
	if not camera.is_inside_tree():
		return
	var p: Vector2 = camera.unproject_position(Vector3(provenance["sommet"] as Vector3i) + Vector3.ONE)
	var echelle: float = _p_photo.size.x / float(PHOTO.x)
	var cible: Vector2 = p * echelle
	var depart := Vector2(_p_renvoi.size.x + 8, 14)
	var coude := Vector2(cible.x, depart.y)
	var trace := PackedVector2Array([depart, coude, cible])
	var ombre := Color(0, 0, 0, 0.7)
	_p_renvoi.draw_polyline(trace, ombre, 4.0, true)
	_p_renvoi.draw_arc(cible, 6.0, 0.0, TAU, 24, ombre, 4.0, true)
	_p_renvoi.draw_polyline(trace, Palette.AMBRE, 1.5, true)
	_p_renvoi.draw_arc(cible, 6.0, 0.0, TAU, 24, Color.WHITE, 1.5, true)
	_p_renvoi.draw_circle(cible, 2.2, Color.WHITE)


## UNE PHOTO : le témoin, la zone allumée par-dessus, une caméra posée sous l'angle choisi.
func _photographier(cases: Array, angle: Vector2, temoin: Mesh) -> SubViewport:
	var vue := SubViewport.new()
	vue.size = PHOTO
	vue.own_world_3d = true
	vue.msaa_3d = Viewport.MSAA_4X
	vue.render_target_update_mode = SubViewport.UPDATE_ONCE
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.FOND_VUE
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8892a4")
	env.ambient_light_energy = 0.8
	var monde_env := WorldEnvironment.new()
	monde_env.environment = env
	vue.add_child(monde_env)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-48, -34, 0)
	soleil.light_energy = 1.15
	vue.add_child(soleil)
	var bloc := MeshInstance3D.new()
	bloc.mesh = temoin
	vue.add_child(bloc)
	vue.add_child(nuage_de_zone(cases, TEINTE_ZONE))

	var centre := centre_de(cases)
	var rayon := rayon_de(cases, centre)
	var distance := rayon * 2.2 + 4.5
	var direction := direction_de(angle)
	var camera := Camera3D.new()
	camera.fov = 40
	# ⚠ Pas `look_at_from_position` : la photo se prépare HORS de l'arbre, où il refuse de tourner.
	camera.transform = Transform3D(Basis.looking_at(-direction, Vector3.UP), centre + direction * distance)
	vue.add_child(camera)
	# L'écorché : si la roche cache la forme, le plan proche la coupe juste avant elle.
	if a_ecorcher(cases, angle):
		camera.near = maxf(0.05, distance - rayon - 1.0)
	vue.set_meta("camera", camera)
	return vue


## Un nuage de cubes translucides qui se voit À TRAVERS la roche : la zone d'une grotte est dedans.
static func nuage_de_zone(cases: Array, teinte: Color) -> MultiMeshInstance3D:
	var boite := BoxMesh.new()
	boite.size = Vector3.ONE * 1.02
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.albedo_color = teinte
	boite.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = boite
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	remplir_zone(instance, cases)
	return instance


## `taille` : la fraction de case de chaque cube — la planche des tuiles allume des cubes PLUS PETITS que la
## case, sinon les 244 copies d'une paroi ne font qu'une masse (vu à l'image).
static func remplir_zone(instance: MultiMeshInstance3D, cases: Array, taille := 1.0) -> void:
	var mm := instance.multimesh
	mm.instance_count = cases.size()
	for i in cases.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * taille),
			Vector3(cases[i]) + Vector3.ONE * 0.5))
	instance.visible = not cases.is_empty()


static func centre_de(cases: Array) -> Vector3:
	var s := Vector3.ZERO
	for c in cases:
		s += Vector3(c) + Vector3.ONE * 0.5
	return s / float(maxi(1, cases.size()))


static func rayon_de(cases: Array, centre: Vector3) -> float:
	var r := 0.5
	for c in cases:
		r = maxf(r, (Vector3(c) + Vector3.ONE * 0.5).distance_to(centre) + 0.5)
	return r


## L'ANGLE DE LA PHOTO — (azimut, élévation), les mêmes que l'orbite de la vue. Parmi seize angles, celui
## qui laisse voir le plus de cases de la forme ; à égalité, le plus proche de l'angle par défaut de la
## vue (0,7 ; 0,55), pour que les photos se ressemblent.
static func angle_de_vue(cases: Array) -> Vector2:
	var centre := centre_de(cases)
	var distance := rayon_de(cases, centre) * 2.2 + 4.5
	var meilleur := Vector2(0.7, 0.55)
	var moins := 1 << 30
	var ecart_mini := INF
	for elevation in [0.55, 1.0]:
		for k in 8:
			var azimut := 0.7 + float(k) * TAU / 8.0
			var n := cases_cachees(cases, centre, direction_de(Vector2(azimut, elevation)), distance)
			var ecart := absf(elevation - 0.55) + minf(float(k), float(8 - k)) * 0.1
			if n < moins or (n == moins and ecart < ecart_mini):
				moins = n
				ecart_mini = ecart
				meilleur = Vector2(fmod(azimut, TAU), elevation)
	return meilleur


## COMBIEN DE CASES DE LA ZONE SONT CACHÉES à l'œil posé en `centre + direction · distance` : un regard
## par case, de son centre à l'œil, arrêté par la première case PLEINE du témoin hors de la zone.
## ⚠ **UN SEUL REGARD, TIRÉ DU CENTRE, MENTAIT** : celui de la salle passait par la bouche de grotte et la
## déclarait visible, alors que la photo n'aurait montré qu'un flanc de massif percé d'un trou (vu par
## `test_formes_du_temoin`). Chaque case compte.
static func cases_cachees(cases: Array, centre: Vector3, direction: Vector3, distance: float) -> int:
	var zone := {}
	for c in cases:
		zone[c] = true
	if _pleines.is_empty():
		_pleines = BM.cases(0)
	var oeil := centre + direction * distance
	var cachees := 0
	for c in cases:
		var depart := Vector3(c) + Vector3.ONE * 0.5
		var vers := oeil - depart
		var longueur := vers.length()
		vers /= longueur
		var l := 0.25
		while l < longueur:
			var p := depart + vers * l
			# Sorti du bloc : plus rien ne peut cacher.
			if p.x < 0.0 or p.y < 0.0 or p.z < 0.0 or p.x > BM.COTE or p.y > BM.COTE or p.z > BM.COTE:
				break
			var q := Vector3i(floori(p.x), floori(p.y), floori(p.z))
			if _pleines.has(q) and not zone.has(q):
				cachees += 1
				break
			l += 0.25
	return cachees


## L'écorché se fait quand plus d'un quart de la zone est caché.
static func a_ecorcher(cases: Array, angle: Vector2) -> bool:
	var centre := centre_de(cases)
	var distance := rayon_de(cases, centre) * 2.2 + 4.5
	return cases_cachees(cases, centre, direction_de(angle), distance) * 4 > cases.size()


static func direction_de(angle: Vector2) -> Vector3:
	return Vector3(cos(angle.y) * sin(angle.x), sin(angle.y), cos(angle.y) * cos(angle.x))
