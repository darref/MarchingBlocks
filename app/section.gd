extends VBoxContainer
## UNE SECTION REPLIABLE — un en-tête qui se replie, et ce qu'il contient.
##
## ⚠ REPRISE DE SOLUTILES (`ui/tool_section.gd`), mais bâtie en CODE : là-bas elle attendait ses
## enfants `Header` et `Content` posés dans l'éditeur de scènes ; ici tout l'écran se construit en code,
## donc la section fabrique les siens. Le comportement est le même, marque ▾ / ▸ comprise.

const Theme_ := preload("res://app/palette.gd")

const OUVERT := "▾  "
const FERME := "▸  "

var titre := ""
var contenu: VBoxContainer
var _entete: Button


func _init(p_titre: String, ouvert := true) -> void:
	titre = p_titre
	add_theme_constant_override("separation", 6)
	_entete = Button.new()
	_entete.toggle_mode = true
	_entete.flat = true
	_entete.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_entete.add_theme_font_size_override("font_size", 11)
	_entete.add_theme_color_override("font_color", Theme_.GRIS)
	_entete.add_theme_color_override("font_pressed_color", Theme_.GRIS)
	_entete.add_theme_color_override("font_hover_color", Theme_.OLIVE)
	_entete.add_theme_color_override("font_hover_pressed_color", Theme_.OLIVE)
	_entete.toggled.connect(func(v: bool) -> void: _appliquer(v))
	add_child(_entete)
	contenu = VBoxContainer.new()
	contenu.add_theme_constant_override("separation", 6)
	add_child(contenu)
	_entete.button_pressed = ouvert
	_appliquer(ouvert)


func _appliquer(ouvert: bool) -> void:
	_entete.text = (OUVERT if ouvert else FERME) + titre.to_upper()
	contenu.visible = ouvert

