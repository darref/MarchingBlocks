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

## ── UNE TEINTE PAR ATELIER (Jordan, 2 octobre 2026 : « une palette vraiment différente et cohérente à chaque
## atelier : Fluids en bleu, World en rouge […] seule la barre de droite, qui est l'interne de l'atelier, doit changer
## de palette ; de cette manière le soft garde en global sa palette » — puis : « la barre de droite et le bouton de
## l'atelier lui-même »). L'olive reste la palette de tout le reste ; chaque atelier n'habille que SA barre de droite
## et SON bouton. ⚠ World n'est pas le rouge du DANGER (`ROUGE`, orangé) : un cramoisi, pour qu'un « Clear » s'y lise.
const TEINTES_ATELIER := {
	"projet": Color("#f2ca79"),     # ambre : le projet, l'aller-retour
	"monde": Color("#e5525e"),      # rouge (Jordan)
	"fluides": Color("#4fa8ee"),    # bleu (Jordan)
	"witness": Color("#a08cf5"),    # violet : la géométrie du témoin
	"texture": Color("#e77fc9"),    # rose : la peinture
	"jeu": Color("#6fcf8a"),        # vert : on joue
	"transitions": Color("#c3d94e"), # citron : là où deux couches se rencontrent (PROPOSÉ, 6 octobre 2026)
	"anim": Color("#f39a4b"),       # orange : les textures animées (PROPOSÉ, 6 octobre 2026)
	"feuillage": Color("#a6e03c"),  # vert tilleul : les arbres (PROPOSÉ, 6 octobre 2026)
	"jeu_edit": Color("#3fc9c0"),   # turquoise : on joue ET on bâtit (PROPOSÉ, 9 octobre 2026)
	"variantes": Color("#b4c3dc"),  # argent bleuté : des copies d'une même tuile, d'autres sculptures (PROPOSÉ, 13 octobre 2026)
	"generer": Color("#d9a5ff"),    # lilas : un monde entier d'un coup (PROPOSÉ, 19 octobre 2026)
}
static var _themes_atelier := {}


static func teinte(atelier: String) -> Color:
	return TEINTES_ATELIER.get(atelier, OLIVE)


## Le thème de la palette, dans la teinte d'un atelier (mis en mémoire : une barre le garde pour toujours).
static func theme_d_atelier(atelier: String) -> Theme:
	if not _themes_atelier.has(atelier):
		_themes_atelier[atelier] = theme(teinte(atelier))
	return _themes_atelier[atelier]


## Les bandes et filets, teintés d'un accent. ⚠ POUR L'OLIVE, LES CONSTANTES MÊMES : la palette globale ne bouge pas.
static func bande_de(accent: Color) -> Color:
	return BANDE if accent == OLIVE else PANNEAU.lerp(accent, 0.1)


static func bande_survol_de(accent: Color) -> Color:
	return BANDE_SURVOL if accent == OLIVE else PANNEAU.lerp(accent, 0.17)


## HABILLE la barre de droite d'un atelier, APRÈS sa construction : le thème de sa teinte (boutons, curseurs,
## champs, cases…), le fond légèrement teinté avec un filet de sa couleur, et ce que l'écran a peint en olive EN
## DUR dans ses descendants (valeurs, en-têtes de section, filets) passe à sa teinte.
static func habiller_barre(barre: Control, atelier: String) -> void:
	var a := teinte(atelier)
	barre.theme = theme_d_atelier(atelier)
	var fond_ := barre.get_theme_stylebox("panel") as StyleBoxFlat
	if fond_ != null:
		var s := fond_.duplicate() as StyleBoxFlat
		s.bg_color = PANNEAU.lerp(a, 0.05)
		s.border_color = Color(a, 0.75)
		s.border_width_left = maxi(s.border_width_left, 2)
		barre.add_theme_stylebox_override("panel", s)
	_teinter(barre, a)
	barre.set_meta(META_TEINTE, a)


const META_TEINTE := "teinte_d_atelier"


## CE QUI NAÎT PLUS TARD DANS UNE BARRE PREND SA TEINTE (3 octobre 2026) : une liste rebâtie (couches d'eau, matériaux…)
## crée des étiquettes olive après `habiller_barre` — elles gardaient l'olive. Chaque nœud ajouté sous une barre
## habillée est teinté à l'image suivante (ses surcharges sont posées après `add_child`, parfois).
static func teinter_ce_qui_arrive(arbre: SceneTree) -> void:
	if arbre.has_meta(META_TEINTE):   # une fois par arbre (la fumée bâtit l'écran plusieurs fois)
		return
	arbre.set_meta(META_TEINTE, true)
	arbre.node_added.connect(func(n: Node) -> void:
		if not (n is Control):
			return
		var p := n.get_parent()
		while p != null:
			if p.has_meta(META_TEINTE):
				var a: Color = p.get_meta(META_TEINTE)
				(func() -> void:
					if is_instance_valid(n):
						_teinter(n, a)).call_deferred()
				return
			p = p.get_parent())


## Le BOUTON de l'atelier, dans la barre de gauche : sa teinte, même au repos (icône et filet), pleine une fois choisi.
static func habiller_bouton_d_atelier(bouton: Button, atelier: String) -> void:
	var a := teinte(atelier)
	bouton.theme = theme_d_atelier(atelier)
	var repos := _boite(BOUTON)
	repos.border_color = Color(a, 0.8)
	repos.border_width_left = 3
	bouton.add_theme_stylebox_override("normal", repos)
	var survol := _boite(BOUTON_SURVOL)
	survol.border_color = a
	survol.border_width_left = 3
	bouton.add_theme_stylebox_override("hover", survol)
	var choisi := _boite(Color(a, 0.28), a)
	choisi.border_width_left = 3
	bouton.add_theme_stylebox_override("pressed", choisi)
	bouton.add_theme_stylebox_override("hover_pressed", choisi)
	for c in ["icon_normal_color", "icon_hover_color", "icon_focus_color"]:
		bouton.add_theme_color_override(c, a)
	for c in ["icon_pressed_color", "icon_hover_pressed_color", "font_pressed_color", "font_hover_pressed_color"]:
		bouton.add_theme_color_override(c, a.lightened(0.25))


## L'olive peint EN DUR (surcharges de couleur, bandes et filets des sections, rectangles) → la teinte.
static func _teinter(n: Node, a: Color) -> void:
	if n is Control:
		var c := n as Control
		for nom in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color",
				"icon_normal_color", "icon_pressed_color", "icon_hover_color", "icon_hover_pressed_color"]:
			if c.has_theme_color_override(nom) and c.get_theme_color(nom).is_equal_approx(OLIVE):
				c.add_theme_color_override(nom, a)
		for etat in ["normal", "pressed", "hover", "hover_pressed"]:
			if not c.has_theme_stylebox_override(etat):
				continue
			var s := c.get_theme_stylebox(etat) as StyleBoxFlat
			if s == null or not s.border_color.is_equal_approx(OLIVE):
				continue
			var t2 := s.duplicate() as StyleBoxFlat
			t2.border_color = a
			if t2.bg_color.is_equal_approx(BANDE):
				t2.bg_color = bande_de(a)
			elif t2.bg_color.is_equal_approx(BANDE_SURVOL):
				t2.bg_color = bande_survol_de(a)
			c.add_theme_stylebox_override(etat, t2)
	if n is ColorRect and (n as ColorRect).color.is_equal_approx(OLIVE):
		(n as ColorRect).color = a
	for enfant in n.get_children():
		_teinter(enfant, a)


## Une icône de case (carrée) ou de choix exclusif (ronde), 16 px, adoucie au bord : décochée, un contour gris clair ;
## cochée, la teinte pleine et un point (rond) ou une coche (carré) sombre.
static func _case(cochee: bool, ronde: bool, teinte: Color) -> ImageTexture:
	const N := 16
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bord := Color(0.78, 0.78, 0.74) if not cochee else teinte
	for y in N:
		for x in N:
			var p := Vector2(x + 0.5, y + 0.5) - Vector2(N, N) / 2.0
			# distance signée au bord de la forme (rayon 7)
			var d: float
			if ronde:
				d = p.length() - 7.0
			else:
				var q := p.abs() - Vector2(4.5, 4.5)
				d = Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - 2.5
			var c := Color(0, 0, 0, 0)
			if cochee:
				c = Color(teinte, clampf(0.5 - d, 0.0, 1.0))
			else:
				c = Color(bord, clampf(1.3 - absf(d + 1.0), 0.0, 1.0))
			if cochee:
				var marque := 0.0
				if ronde:
					marque = clampf(3.0 - p.length(), 0.0, 1.0)
				else:
					# la coche : deux segments, (−3.5, 0) → (−1, 2.5) → (3.5, −2.5)
					var dc := minf(_dist_segment(p, Vector2(-3.5, 0.0), Vector2(-1.0, 2.5)),
						_dist_segment(p, Vector2(-1.0, 2.5), Vector2(3.5, -2.5)))
					marque = clampf(1.6 - dc, 0.0, 1.0)
				if marque > 0.0 and c.a > 0.0:
					c = c.lerp(Color(SOMBRE, c.a), marque)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func _dist_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


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
	var focus := _boite(Color.TRANSPARENT, Color(_accent_en_cours, 0.55))
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


## ⚠ `accent` : l'OLIVE pour l'écran entier ; la teinte d'un atelier pour sa barre de droite (`theme_d_atelier`).
static var _accent_en_cours := OLIVE


static func theme(accent := OLIVE) -> Theme:
	_accent_en_cours = accent
	var t := Theme.new()
	t.default_font_size = 13

	# Le bouton ordinaire : sombre, arrondi ; ENFONCÉ, il prend l'olive — c'est l'état qu'on doit lire
	# de loin (quel outil, quelle visée).
	_habiller_bouton(t, "Button", BOUTON, BOUTON_SURVOL, Color(accent, 0.2), TEXTE, accent.lightened(0.2),
		Color(accent, 0.7))
	t.set_constant("icon_max_width", "Button", 18)
	t.set_constant("h_separation", "Button", 7)

	# PRINCIPAL : l'action qu'on vient chercher dans la section (trancher, exporter).
	t.set_type_variation(PRINCIPAL, "Button")
	_habiller_bouton(t, PRINCIPAL, Color(accent, 0.85), accent, accent.darkened(0.2), SOMBRE, SOMBRE)
	t.set_font(("font"), PRINCIPAL, gras())

	# DANGER : ce qui efface. Texte rouge, fond neutre : on le voit sans qu'il crie.
	t.set_type_variation(DANGER, "Button")
	_habiller_bouton(t, DANGER, BOUTON, Color(ROUGE, 0.22), Color(ROUGE, 0.35), ROUGE.lightened(0.1),
		ROUGE.lightened(0.3))

	# OUTIL : les grands boutons carrés de la barre (icône au-dessus du nom).
	t.set_type_variation(OUTIL, "Button")
	_habiller_bouton(t, OUTIL, BOUTON, BOUTON_SURVOL, Color(accent, 0.26), TEXTE, accent.lightened(0.3),
		accent)
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
		t.set_color("font_pressed_color", type, accent.lightened(0.2))
		t.set_color("font_hover_color", type, TEXTE)
		t.set_color("font_hover_pressed_color", type, accent.lightened(0.2))
	# ⚠ LES CASES DÉCOCHÉES ÉTAIENT INVISIBLES (vu à l'image, 3 octobre 2026) : les icônes par défaut de Godot sont gris
	# foncé sur un fond sombre — « Very simple example », « Select empty cells too » n'avaient pas de case. Dessinées
	# ici : un contour clair décoché, la teinte pleine cochée ; un rond pour les choix exclusifs (radio).
	t.set_icon("unchecked", "CheckBox", _case(false, false, accent))
	t.set_icon("checked", "CheckBox", _case(true, false, accent))
	t.set_icon("radio_unchecked", "CheckBox", _case(false, true, accent))
	t.set_icon("radio_checked", "CheckBox", _case(true, true, accent))
	t.set_icon("unchecked_disabled", "CheckBox", _case(false, false, Color(GRIS, 0.4)))
	t.set_icon("checked_disabled", "CheckBox", _case(true, false, Color(GRIS, 0.4)))
	t.set_icon("radio_unchecked_disabled", "CheckBox", _case(false, true, Color(GRIS, 0.4)))
	t.set_icon("radio_checked_disabled", "CheckBox", _case(true, true, Color(GRIS, 0.4)))

	# Les champs.
	for type in ["LineEdit", "SpinBox"]:
		t.set_stylebox("normal", type, _boite(CHAMP, FILET, 5, 8, 5))
		t.set_stylebox("focus", type, _boite(CHAMP, Color(accent, 0.8), 5, 8, 5))
		t.set_color("font_color", type, TEXTE)
		t.set_color("font_placeholder_color", type, Color(GRIS, 0.6))
		t.set_color("caret_color", type, accent)
		t.set_color("selection_color", type, Color(accent, 0.3))

	# Les listes déroulantes et leurs menus.
	t.set_stylebox("panel", "PopupMenu", _boite(SOMBRE, FILET, 5, 6, 6))
	t.set_stylebox("hover", "PopupMenu", _boite(Color(accent, 0.2), Color.TRANSPARENT, 4, 6, 4))
	t.set_color("font_color", "PopupMenu", TEXTE)
	t.set_color("font_hover_color", "PopupMenu", accent.lightened(0.2))

	# Le curseur de taille.
	var rail := _boite(CHAMP, FILET, 3, 0, 3)
	t.set_stylebox("slider", "HSlider", rail)
	var rempli := _boite(Color(accent, 0.55), Color.TRANSPARENT, 3, 0, 3)
	t.set_stylebox("grabber_area", "HSlider", rempli)
	t.set_stylebox("grabber_area_highlight", "HSlider", _boite(Color(accent, 0.75), Color.TRANSPARENT, 3, 0, 3))

	# Les barres de défilement : fines, discrètes.
	for type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", type, _boite(Color.TRANSPARENT, Color.TRANSPARENT, 3, 3, 3))
		t.set_stylebox("grabber", type, _boite(Color(GRIS, 0.25), Color.TRANSPARENT, 3, 3, 3))
		t.set_stylebox("grabber_highlight", type, _boite(Color(GRIS, 0.45), Color.TRANSPARENT, 3, 3, 3))
		t.set_stylebox("grabber_pressed", type, _boite(Color(accent, 0.6), Color.TRANSPARENT, 3, 3, 3))

	# Les infobulles : on les lit souvent, elles doivent être nettes.
	t.set_stylebox("panel", "TooltipPanel", _boite(SOMBRE, FILET, 5, 10, 7))
	t.set_color("font_color", "TooltipLabel", TEXTE)
	t.set_font_size("font_size", "TooltipLabel", 12)

	# Les onglets du manuel.
	t.set_stylebox("panel", "TabContainer", _boite(PANNEAU, FILET, 5, 0, 0))
	t.set_stylebox("tab_selected", "TabContainer", _boite(bande_de(accent), Color(accent, 0.6), 5, 14, 7))
	t.set_stylebox("tab_unselected", "TabContainer", _boite(Color.TRANSPARENT, Color.TRANSPARENT, 5, 14, 7))
	t.set_stylebox("tab_hovered", "TabContainer", _boite(BOUTON_SURVOL, Color.TRANSPARENT, 5, 14, 7))
	t.set_color("font_selected_color", "TabContainer", accent.lightened(0.2))
	t.set_color("font_unselected_color", "TabContainer", GRIS)
	t.set_color("font_hovered_color", "TabContainer", TEXTE)
	return t
