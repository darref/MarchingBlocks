extends RefCounted
## LA PALETTE ET LE THÈME DE L'ÉCRAN — la palette de SoluTiles, relevée dans son `ui/editor.tscn`,
## et un `Theme` bâti en code qui la porte partout.
##
## ⚠ UN SEUL ENDROIT : SoluTiles répétait ses couleurs en surcharges nœud par nœud dans sa scène.
## Ici l'écran est bâti en code, donc chaque couleur est nommée une fois et lue partout.
## ⚠ **LE THÈME EST POSÉ SUR LA RACINE, PAS SUR CHAQUE BOUTON** (Jordan, 27 septembre 2026 : « que le
## tout soit bien lisible et évident »). Un bouton qui porterait ses propres surcharges échapperait au
## thème le jour où on le retouche, et l'écran redeviendrait un patchwork.

const BARRE_TITRE := Color(0.113, 0.124, 0.131)
const PANNEAU := Color(0.106, 0.118, 0.125)
const TEXTE := Color(0.878, 0.878, 0.851)
const GRIS := Color(0.588, 0.612, 0.588)
const OLIVE := Color(0.706, 0.741, 0.522)
const AMBRE := Color(0.949, 0.792, 0.475)
const ATTENTE := Color(0.075, 0.082, 0.09, 0.95)
const FOND_VUE := Color("#101216")
const ROUGE := Color("#e0603c")

## LES CATÉGORIES : une bande légèrement plus claire et teintée d'olive, pour qu'on voie d'un coup
## d'œil où commence chaque famille d'outils.
const BANDE := Color(0.157, 0.173, 0.15)
const BANDE_SURVOL := Color(0.19, 0.208, 0.176)
const BOUTON := Color(0.16, 0.172, 0.18)
const BOUTON_SURVOL := Color(0.212, 0.227, 0.235)
const BOUTON_ENFONCE := Color(0.706, 0.741, 0.522, 0.2)
const CHAMP := Color(0.078, 0.086, 0.094)
const FILET := Color(0.24, 0.26, 0.232)
const SOMBRE := Color(0.085, 0.094, 0.1)

## Les variantes de bouton — `theme_type_variation`.
const PRINCIPAL := "BoutonPrincipal"
const DANGER := "BoutonDanger"
const OUTIL := "BoutonOutil"
const DISCRET := "BoutonDiscret"

static var _gras: FontVariation


static func fond(couleur: Color, rayon := 0, marge := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = couleur
	s.set_corner_radius_all(rayon)
	s.content_margin_left = marge
	s.content_margin_right = marge
	s.content_margin_top = marge
	s.content_margin_bottom = marge
	return s


## La police GRASSE des titres : la police par défaut, épaissie. ⚠ Pas un second fichier de police : un
## `.ttf` de plus dans l'exécutable pour des en-têtes, c'est du poids pour rien.
static func gras() -> Font:
	if _gras == null:
		_gras = FontVariation.new()
		_gras.base_font = ThemeDB.fallback_font
		_gras.variation_embolden = 0.55
	return _gras


static func _boite(couleur: Color, bord := Color.TRANSPARENT, rayon := 5, h := 10, v := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = couleur
	s.set_corner_radius_all(rayon)
	s.content_margin_left = h
	s.content_margin_right = h
	s.content_margin_top = v
	s.content_margin_bottom = v
	if bord.a > 0.0:
		s.border_color = bord
		s.set_border_width_all(1)
	return s


static func _habiller_bouton(t: Theme, type: String, normal: Color, survol: Color, enfonce: Color,
		texte: Color, texte_enfonce: Color, bord_enfonce := Color.TRANSPARENT) -> void:
	t.set_stylebox("normal", type, _boite(normal))
	t.set_stylebox("hover", type, _boite(survol))
	t.set_stylebox("pressed", type, _boite(enfonce, bord_enfonce))
	t.set_stylebox("hover_pressed", type, _boite(enfonce.lightened(0.08), bord_enfonce))
	t.set_stylebox("disabled", type, _boite(normal.darkened(0.3)))
	var focus := _boite(Color.TRANSPARENT, Color(OLIVE, 0.55))
	focus.draw_center = false
	t.set_stylebox("focus", type, focus)
	for etat in ["font_color", "font_focus_color"]:
		t.set_color(etat, type, texte)
	t.set_color("font_hover_color", type, texte.lightened(0.15))
	t.set_color("font_pressed_color", type, texte_enfonce)
	t.set_color("font_hover_pressed_color", type, texte_enfonce)
	t.set_color("font_disabled_color", type, Color(texte, 0.35))
	t.set_color("icon_normal_color", type, texte)
	t.set_color("icon_focus_color", type, texte)
	t.set_color("icon_hover_color", type, texte.lightened(0.15))
	t.set_color("icon_pressed_color", type, texte_enfonce)
	t.set_color("icon_hover_pressed_color", type, texte_enfonce)
	t.set_color("icon_disabled_color", type, Color(texte, 0.35))


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 13

	# Le bouton ordinaire : sombre, arrondi ; ENFONCÉ, il prend l'olive — c'est l'état qu'on doit lire
	# de loin (quel outil, quelle visée).
	_habiller_bouton(t, "Button", BOUTON, BOUTON_SURVOL, BOUTON_ENFONCE, TEXTE, OLIVE.lightened(0.2),
		Color(OLIVE, 0.7))
	t.set_constant("icon_max_width", "Button", 18)
	t.set_constant("h_separation", "Button", 7)

	# PRINCIPAL : l'action qu'on vient chercher dans la section (trancher, exporter).
	t.set_type_variation(PRINCIPAL, "Button")
	_habiller_bouton(t, PRINCIPAL, Color(OLIVE, 0.85), OLIVE, OLIVE.darkened(0.2), SOMBRE, SOMBRE)
	t.set_font(("font"), PRINCIPAL, gras())

	# DANGER : ce qui efface. Texte rouge, fond neutre : on le voit sans qu'il crie.
	t.set_type_variation(DANGER, "Button")
	_habiller_bouton(t, DANGER, BOUTON, Color(ROUGE, 0.22), Color(ROUGE, 0.35), ROUGE.lightened(0.1),
		ROUGE.lightened(0.3))

	# OUTIL : les grands boutons carrés de la barre (icône au-dessus du nom).
	t.set_type_variation(OUTIL, "Button")
	_habiller_bouton(t, OUTIL, BOUTON, BOUTON_SURVOL, Color(OLIVE, 0.26), TEXTE, OLIVE.lightened(0.3),
		OLIVE)
	t.set_constant("icon_max_width", OUTIL, 22)
	t.set_font_size("font_size", OUTIL, 11)

	# DISCRET : les petites actions d'une ligne (œil d'une couche, fermer).
	t.set_type_variation(DISCRET, "Button")
	_habiller_bouton(t, DISCRET, Color.TRANSPARENT, BOUTON_SURVOL, Color.TRANSPARENT, GRIS, TEXTE)
	t.set_constant("icon_max_width", DISCRET, 16)

	# Les cases à cocher et interrupteurs.
	for type in ["CheckBox", "CheckButton"]:
		t.set_stylebox("normal", type, _boite(Color.TRANSPARENT, Color.TRANSPARENT, 5, 4, 4))
		t.set_stylebox("hover", type, _boite(BOUTON_SURVOL, Color.TRANSPARENT, 5, 4, 4))
		t.set_stylebox("pressed", type, _boite(Color.TRANSPARENT, Color.TRANSPARENT, 5, 4, 4))
		t.set_stylebox("hover_pressed", type, _boite(BOUTON_SURVOL, Color.TRANSPARENT, 5, 4, 4))
		t.set_color("font_color", type, TEXTE)
		t.set_color("font_pressed_color", type, OLIVE.lightened(0.2))
		t.set_color("font_hover_color", type, TEXTE)
		t.set_color("font_hover_pressed_color", type, OLIVE.lightened(0.2))

	# Les champs.
	for type in ["LineEdit", "SpinBox"]:
		t.set_stylebox("normal", type, _boite(CHAMP, FILET, 5, 8, 5))
		t.set_stylebox("focus", type, _boite(CHAMP, Color(OLIVE, 0.8), 5, 8, 5))
		t.set_color("font_color", type, TEXTE)
		t.set_color("font_placeholder_color", type, Color(GRIS, 0.6))
		t.set_color("caret_color", type, OLIVE)
		t.set_color("selection_color", type, Color(OLIVE, 0.3))

	# Les listes déroulantes et leurs menus.
	t.set_stylebox("panel", "PopupMenu", _boite(SOMBRE, FILET, 5, 6, 6))
	t.set_stylebox("hover", "PopupMenu", _boite(BOUTON_ENFONCE, Color.TRANSPARENT, 4, 6, 4))
	t.set_color("font_color", "PopupMenu", TEXTE)
	t.set_color("font_hover_color", "PopupMenu", OLIVE.lightened(0.2))

	# Le curseur de taille.
	var rail := _boite(CHAMP, FILET, 3, 0, 3)
	t.set_stylebox("slider", "HSlider", rail)
	var rempli := _boite(Color(OLIVE, 0.55), Color.TRANSPARENT, 3, 0, 3)
	t.set_stylebox("grabber_area", "HSlider", rempli)
	t.set_stylebox("grabber_area_highlight", "HSlider", _boite(Color(OLIVE, 0.75), Color.TRANSPARENT, 3, 0, 3))

	# Les barres de défilement : fines, discrètes.
	for type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", type, _boite(Color.TRANSPARENT, Color.TRANSPARENT, 3, 3, 3))
		t.set_stylebox("grabber", type, _boite(Color(GRIS, 0.25), Color.TRANSPARENT, 3, 3, 3))
		t.set_stylebox("grabber_highlight", type, _boite(Color(GRIS, 0.45), Color.TRANSPARENT, 3, 3, 3))
		t.set_stylebox("grabber_pressed", type, _boite(Color(OLIVE, 0.6), Color.TRANSPARENT, 3, 3, 3))

	# Les infobulles : on les lit souvent, elles doivent être nettes.
	t.set_stylebox("panel", "TooltipPanel", _boite(SOMBRE, FILET, 5, 10, 7))
	t.set_color("font_color", "TooltipLabel", TEXTE)
	t.set_font_size("font_size", "TooltipLabel", 12)

	# Les onglets du manuel.
	t.set_stylebox("panel", "TabContainer", _boite(PANNEAU, FILET, 5, 0, 0))
	t.set_stylebox("tab_selected", "TabContainer", _boite(BANDE, Color(OLIVE, 0.6), 5, 14, 7))
	t.set_stylebox("tab_unselected", "TabContainer", _boite(Color.TRANSPARENT, Color.TRANSPARENT, 5, 14, 7))
	t.set_stylebox("tab_hovered", "TabContainer", _boite(BOUTON_SURVOL, Color.TRANSPARENT, 5, 14, 7))
	t.set_color("font_selected_color", "TabContainer", OLIVE.lightened(0.2))
	t.set_color("font_unselected_color", "TabContainer", GRIS)
	t.set_color("font_hovered_color", "TabContainer", TEXTE)
	return t
