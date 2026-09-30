extends ScrollContainer
## LA PLANCHE DES 52 — les tuiles qu'un monde emploie, une carte chacune (charte §3, Jordan, 30 septembre
## 2026 : « il faudrait montrer de manière significative les 52 qui seront utilisées dans un monde »).
##
## Une carte : la PHOTO de la tuile seule dans sa case, avec en fantôme les huit demi-cases qui la font
## naître (ce qu'aucune phrase ne dit aussi vite) ; son nom anglais, son contexte (air libre ou sous
## roche), ce qu'elle fait dans un monde, et combien de copies le témoin en montre. Survoler une carte
## allume TOUTES ses copies dans la vue ; un clic cadre la plus lisible, et la met en édition si l'on édite.
##
## ⚠ **LES PHOTOS SONT PRISES SUR LES TUILES DU MODÈLE, PAS DES PNG** (comme la légende des formes) : elles
## montrent ce qu'on a sculpté, et `rafraichir` les reprend après un geste.
## ⚠ Bâtie À LA DEMANDE (le premier passage sur l'onglet) : 52 prises de vue à l'ouverture de l'appli
## coûteraient pour un onglet qu'on n'ouvre peut-être pas.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const FN := preload("res://addons/marchingblocks_core/format_neutre.gd")
const Palette := preload("res://app/palette.gd")

## Survol : les « cases » à allumer (le centre de chaque copie moins ½ — `LegendeFormes.remplir_zone`
## ajoute ½) ; vide quand plus rien n'est survolé.
signal zone_survolee(cases: Array)
signal tuile_choisie(cle: String)

const PHOTO := Vector2i(150, 104)
## Les demi-cases fantômes : un gris NEUTRE — l'ambre est la couleur des zones allumées, et les deux se
## confondaient sur la photo (vu à l'image).
const TEINTE_CASE := Color(0.85, 0.88, 0.95, 0.16)

var cartes := {}        # clé → {"fond", "vue", "tuile" (MeshInstance3D), "copies": Array}
var _rangee: HBoxContainer
var temoin: RefCounted


func _init() -> void:
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_rangee = HBoxContainer.new()
	_rangee.add_theme_constant_override("separation", 8)
	add_child(_rangee)


func est_batie() -> bool:
	return not cartes.is_empty()


## Les cartes, dans l'ordre du modèle (`MB.classes()`), le nom nu avant l'air libre.
func batir(t: RefCounted) -> void:
	temoin = t
	for enfant in _rangee.get_children():
		enfant.queue_free()
	cartes = {}
	_rangee.add_child(_intro())
	for c in MB.classes():
		for cle in [c["nom"], MB.nom_en_contexte(c["nom"], true)]:
			if t.tuiles.has(cle) and not cartes.has(cle):
				_rangee.add_child(_carte(cle, c["bits"]))


## Les photos reprises sur les tuiles du modèle — après un geste, une annulation, un rechargement.
func rafraichir(t: RefCounted) -> void:
	if not est_batie():
		return
	temoin = t
	for cle in cartes:
		if not t.tuiles.has(cle):
			continue
		(cartes[cle]["tuile"] as MeshInstance3D).mesh = t.tuiles[cle].vers_array_mesh()
		(cartes[cle]["vue"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE


func _intro() -> Control:
	var boite := VBoxContainer.new()
	boite.custom_minimum_size = Vector2(150, 0)
	boite.add_theme_constant_override("separation", 6)
	var titre := Label.new()
	titre.text = "THE %d TILES" % temoin.tuiles.size()
	titre.add_theme_font_override("font", Palette.gras())
	titre.add_theme_font_size_override("font_size", 12)
	titre.add_theme_color_override("font_color", Palette.OLIVE)
	boite.add_child(titre)
	var texte := Label.new()
	texte.text = ("Every world is built from these tiles, and only these. The ghost cells show which of "
		+ "the eight half-cells around the corner are full.\n\nHover a tile to light up all its copies; "
		+ "click to go to one.")
	texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texte.custom_minimum_size = Vector2(150, 0)
	texte.add_theme_font_size_override("font_size", 11)
	texte.add_theme_color_override("font_color", Palette.GRIS)
	boite.add_child(texte)
	return boite


func _carte(cle: String, bits: int) -> Control:
	var copies: Array = []
	for i in temoin.occurrences_de(cle):
		copies.append(Vector3(temoin.occurrences[i]["sommet"] as Vector3i) + Vector3.ONE * 0.5)
	var dehors := cle.ends_with(MB.SUFFIXE_DEHORS)
	var fond := PanelContainer.new()
	fond.mouse_filter = Control.MOUSE_FILTER_STOP
	fond.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	fond.custom_minimum_size = Vector2(PHOTO.x + 10, 0)
	fond.tooltip_text = ("%s — %d copies in the witness.\nb%d h%d: full half-cells below / above the corner.\n"
		+ "Click to go to it (and edit it, in edit mode).") % [FN.id_de_cle(cle), copies.size(),
		_compte(bits, MB.BAS), _compte(bits, MB.HAUT)]
	var repos := Palette.fond(Palette.SOMBRE, 5, 6)
	var survol := Palette.fond(Palette.BOUTON_SURVOL, 5, 6)
	survol.border_color = Palette.AMBRE
	survol.set_border_width_all(1)
	fond.add_theme_stylebox_override("panel", repos)
	fond.set_meta("cle", cle)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 2)
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.add_child(colonne)

	var vue := _photographier(temoin.tuiles[cle].vers_array_mesh(), bits)
	fond.add_child(vue)
	var photo := TextureRect.new()
	photo.texture = vue.get_texture()
	photo.custom_minimum_size = Vector2(PHOTO)
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(photo)

	var nom := _etiquette(colonne, 11, Palette.AMBRE, true)
	nom.text = FN.id_de_classe(MB.nom_nu(cle)).replace("_", " ").to_upper()
	var ligne := HBoxContainer.new()
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(ligne)
	var contexte := _etiquette(ligne, 10, Palette.OLIVE if dehors else Palette.GRIS)
	contexte.text = "open air" if dehors else "under rock"
	contexte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contexte.autowrap_mode = TextServer.AUTOWRAP_OFF
	var compte := _etiquette(ligne, 10, Palette.GRIS)
	compte.text = "×%d" % copies.size()
	compte.autowrap_mode = TextServer.AUTOWRAP_OFF
	var role := _etiquette(colonne, 10, Palette.TEXTE)
	role.text = role_de(cle)
	role.custom_minimum_size = Vector2(PHOTO.x, 0)

	fond.mouse_entered.connect(func() -> void:
		fond.add_theme_stylebox_override("panel", survol)
		zone_survolee.emit(copies))
	fond.mouse_exited.connect(func() -> void:
		fond.add_theme_stylebox_override("panel", repos)
		zone_survolee.emit([]))
	fond.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			tuile_choisie.emit(cle)
			fond.accept_event())
	cartes[cle] = {"fond": fond, "vue": vue, "tuile": vue.get_meta("tuile"), "copies": copies}
	return fond


func _etiquette(parent: Control, taille: int, couleur: Color, gras := false) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	if gras:
		l.add_theme_font_override("font", Palette.gras())
	parent.add_child(l)
	return l


static func _compte(bits: int, couche: Array) -> int:
	var n := 0
	for t in couche:
		if bits & (1 << int(t)):
			n += 1
	return n


## CE QUE LA TUILE FAIT DANS UN MONDE, en une ligne. ⚠ Une phrase n'est écrite que pour les familles dont le
## sens est SÛR (dalles, arêtes, coins, équerres simples) ; les autres disent ce qu'elles sont — un passage
## tordu entre deux marches — sans inventer un paysage. La photo, elle, ne ment jamais.
static func role_de(cle: String) -> String:
	var classe := MB.nom_nu(cle)
	var sens := {
		"mb_plaque_b4h0": "Flat ground: every floor.",
		"mb_plaque_b0h4": "Flat ceiling: the underside of rock.",
		"mb_plaque_b2h2": "Flat wall: every straight cliff face.",
		"mb_arete_b2h0": "The rim where ground drops into a wall.",
		"mb_arete_b0h2": "The lip where a ceiling meets a wall.",
		"mb_arete_b1h1": "An outer vertical corner of a wall.",
		"mb_arete_creuse_b4h2": "The foot of a wall, where it meets the ground.",
		"mb_arete_creuse_b2h4": "The top of a wall, where it meets a ceiling.",
		"mb_arete_creuse_b3h3": "An inner vertical corner of a wall.",
		"mb_coin_b1h0": "The tip of an outer corner, on top.",
		"mb_coin_b0h1": "The tip of an outer corner, hanging below.",
		"mb_coin_creux_b4h3": "The inner corner where two walls meet the ground.",
		"mb_coin_creux_b3h4": "The inner corner where two walls meet a ceiling.",
		"mb_equerre_b3h0": "The rim of a ground that turns an inner corner.",
		"mb_equerre_b0h3": "The lip of a ceiling that turns an inner corner.",
		"mb_equerre_creuse_b4h1": "The foot of an outer wall corner, on the ground.",
		"mb_equerre_creuse_b1h4": "The top of an outer wall corner, under a ceiling.",
	}
	if sens.has(classe):
		return sens[classe]
	return "A rare twisted step where two levels cross: it links the others."


## LA PHOTO D'UNE TUILE : la tuile dans son repère de référence, la case en fil, et en fantôme les demi-cases
## pleines de sa configuration (les coins de `MB.COINS`, à ±¼ du sommet).
func _photographier(tuile: Mesh, bits: int) -> SubViewport:
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
	var mi := MeshInstance3D.new()
	mi.mesh = tuile
	vue.add_child(mi)
	vue.set_meta("tuile", mi)

	var fantome := StandardMaterial3D.new()
	fantome.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fantome.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fantome.albedo_color = TEINTE_CASE
	fantome.no_depth_test = true
	for t in 8:
		if bits & (1 << t) == 0:
			continue
		var b := MeshInstance3D.new()
		var boite := BoxMesh.new()
		boite.size = Vector3.ONE * 0.46
		boite.material = fantome
		b.mesh = boite
		b.position = (Vector3(MB.COINS[t]) - Vector3.ONE * 0.5) * 0.5
		vue.add_child(b)
	# La case de la tuile, en fil.
	var fil := MeshInstance3D.new()
	var lignes := PackedVector3Array()
	# Les 12 arêtes du cube : les paires de coins qui ne diffèrent que sur UN axe.
	for i in 8:
		for j in range(i + 1, 8):
			var a := Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1)
			var b := Vector3(j & 1, (j >> 1) & 1, (j >> 2) & 1)
			if absf(a.x - b.x) + absf(a.y - b.y) + absf(a.z - b.z) == 1.0:
				lignes.append(a - Vector3.ONE * 0.5)
				lignes.append(b - Vector3.ONE * 0.5)
	var am := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = lignes
	am.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var mf := StandardMaterial3D.new()
	mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mf.albedo_color = Color(Palette.GRIS, 0.6)
	mf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	am.surface_set_material(0, mf)
	fil.mesh = am
	vue.add_child(fil)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.55
	# ⚠ PAR EN DESSOUS quand le haut est plus plein que le bas : la surface d'un plafond regarde vers le bas,
	# et vue d'au-dessus elle était de dos, donc invisible (vu à l'image : SLAB B0H4, une case vide).
	var dessous: bool = _compte(bits, MB.HAUT) > _compte(bits, MB.BAS)
	var direction := Vector3(1.0, -0.85 if dessous else 0.85, 1.35).normalized()
	# ⚠ Pas `look_at_from_position` : la photo se prépare HORS de l'arbre.
	camera.transform = Transform3D(Basis.looking_at(-direction, Vector3.UP), direction * 4.0)
	vue.add_child(camera)
	return vue
