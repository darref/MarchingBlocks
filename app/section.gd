extends VBoxContainer
## UNE CATÉGORIE REPLIABLE — une bande d'en-tête (icône, titre, chevron) et ce qu'elle contient.
##
## ⚠ REPRISE DE SOLUTILES (`ui/tool_section.gd`), mais bâtie en CODE : là-bas elle attendait ses
## enfants `Header` et `Content` posés dans l'éditeur de scènes ; ici tout l'écran se construit en code,
## donc la section fabrique les siens.
## ⚠ **L'EN-TÊTE EST UNE BANDE, PAS UN LIBELLÉ GRIS** (Jordan, 27 septembre 2026 : « des catégories dans
## une couleur légèrement différente […] que le tout soit bien lisible et évident »). Un fond teinté, un
## filet d'accent à gauche, une icône et un titre gras : on voit où commence chaque famille d'outils
## sans lire un mot.

const Palette := preload("res://app/palette.gd")

var titre := ""
var contenu: VBoxContainer
var _entete: Button
var _chevron: Label


func _init(p_titre: String, ouvert := true, icone: Texture2D = null) -> void:
	titre = p_titre
	add_theme_constant_override("separation", 8)
	_entete = Button.new()
	_entete.toggle_mode = true
	_entete.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_entete.icon = icone
	_entete.text = titre.to_upper()
	_entete.custom_minimum_size = Vector2(0, 30)
	_entete.focus_mode = Control.FOCUS_NONE
	_entete.add_theme_font_override("font", Palette.gras())
	_entete.add_theme_font_size_override("font_size", 11)
	_entete.add_theme_constant_override("icon_max_width", 15)
	for etat in ["normal", "pressed"]:
		_entete.add_theme_stylebox_override(etat, _bande(Palette.BANDE))
	for etat in ["hover", "hover_pressed"]:
		_entete.add_theme_stylebox_override(etat, _bande(Palette.BANDE_SURVOL))
	for c in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color",
			"icon_normal_color", "icon_pressed_color", "icon_hover_color", "icon_hover_pressed_color"]:
		_entete.add_theme_color_override(c, Palette.OLIVE)
	_entete.toggled.connect(func(v: bool) -> void: _appliquer(v))
	add_child(_entete)

	_chevron = Label.new()
	_chevron.add_theme_color_override("font_color", Palette.GRIS)
	_chevron.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_chevron.offset_left = -22
	_chevron.offset_right = -8
	_chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entete.add_child(_chevron)

	var marge := MarginContainer.new()
	marge.add_theme_constant_override("margin_left", 4)
	marge.add_theme_constant_override("margin_right", 2)
	marge.add_theme_constant_override("margin_bottom", 4)
	add_child(marge)
	contenu = VBoxContainer.new()
	contenu.add_theme_constant_override("separation", 7)
	marge.add_child(contenu)
	_entete.button_pressed = ouvert
	_appliquer(ouvert)


func _bande(couleur: Color) -> StyleBoxFlat:
	var s := Palette.fond(couleur, 4, 8)
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	s.border_color = Palette.OLIVE
	s.border_width_left = 3
	s.corner_radius_top_left = 2
	s.corner_radius_bottom_left = 2
	return s


func _appliquer(ouvert: bool) -> void:
	_chevron.text = "▾" if ouvert else "▸"
	(contenu.get_parent() as Control).visible = ouvert


func ouvrir(oui: bool) -> void:
	_entete.button_pressed = oui
