extends PanelContainer
## LES INFOS DE LA VUE — DEMANDÉ PAR JORDAN (13 octobre 2026 : « rendre plus évident le scaling du monde aussi, et
## l'étage en cours » ; à la question posée : « un affichage des infos principales en haut à droite de la vue 3D »).
##
## En haut à DROITE de la vue (à gauche de la barre de droite quand elle est là), dans le style du guide des raccourcis
## (`guide.gd`, en haut à gauche) : translucide, sans souris. Ce qu'il dit — PROPOSÉ :
##   - la couche active et son nombre de cases ;
##   - l'étage de la grille (y) ;
##   - l'outil, et sa taille quand il en a une ;
##   - la sélection : ses cases, et ses dimensions x × y × z (la boîte qui la contient) ;
##   - pendant un glissé de Rect, de Box ou de Room : les dimensions du glissé.
## Il porte aussi le REPÈRE DE TAILLE (`silhouette.gd`) : le personnage du Play test en fantôme, sous le curseur.
##
## ⚠ BRANCHÉ PAR DEUX LIGNES DE `editor.gd` (`brancher`) : il lit l'écran sans rien y écrire, une fois par image, et ne
## se réécrit que quand ce qu'il dit change. Les deux cases (« Info panel in the view », « Size reference ») vont dans la
## section Shortcuts, sous celle du guide, et sont retenues dans `reglages.cfg` (section « infos »).

const Silhouette := preload("res://app/silhouette.gd")
const Outils := preload("res://addons/marchingblocks_core/outils.gd")
const Palette := preload("res://app/palette.gd")

## Les ateliers où la vue montre le monde qu'on peint.
const ATELIERS := ["monde", "fluides", "transitions", "feuillage", "jeu_edit"]
## Le fantôme : pas en Play edit, où le vrai personnage est déjà là.
const ATELIERS_SILHOUETTE := ["monde", "fluides", "transitions", "feuillage"]
const NOMS_OUTILS := {"ajouter": "Add", "creuser": "Dig", "selectionner": "Select", "rect": "Rect", "boite": "Box",
	"forme": "Special shape", "eau": "Water", "variante": "Variant", "transition": "Transitions",
	"feuillage": "Foliage"}
const NOMS_FORMES := {"sphere": "sphere", "cube": "cube", "disque": "disc"}
const NOMS_SPECIALES := {"tunnel": "Tunnel", "puits": "Well", "pont": "Bridge", "balcon": "Balcony",
	"escalier": "Stairs", "salle": "Room"}
## Au-delà, la sélection n'est pas mesurée à chaque image (un balayage de ses cases) : elle l'est à son changement.
const MARGE := 12.0

var _ed: Control
var _texte: RichTextLabel
var case_infos: CheckBox
var case_silhouette: CheckBox
var silhouette: Node3D
var _signature := ""
var _sig_silhouette := ""
## La sélection mesurée : on ne la rebalaye que si elle a changé (même objet, même taille).
var _sel_mesuree: Dictionary = {}
var _sel_taille := -1
var _sel_dims := Vector3i.ZERO


## Pose le panneau dans `parent` (le corps de l'écran, sur la vue), ses deux cases sous `apres` (la case du guide) et le
## fantôme dans le monde 3D de la vue.
func brancher(ed: Control, parent: Control, apres: Control) -> void:
	_ed = ed
	name = "InfosVue"
	var st := Palette.fond(Color(Palette.PANNEAU, 0.78), 6, 8)
	st.border_color = Color(Palette.FILET, 0.8)
	st.set_border_width_all(1)
	add_theme_stylebox_override("panel", st)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(190, 0)
	_texte = RichTextLabel.new()
	_texte.bbcode_enabled = true
	_texte.fit_content = true
	_texte.scroll_active = false
	_texte.autowrap_mode = TextServer.AUTOWRAP_OFF
	_texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texte.add_theme_font_size_override("normal_font_size", 12)
	_texte.add_theme_font_size_override("bold_font_size", 12)
	add_child(_texte)
	visible = false
	parent.add_child(self)

	case_infos = _case("Info panel in the view", "infos", "visible",
		"Layer, floor, tool, selection size and drag size, at the top right of the view.")
	case_silhouette = _case("Size reference (the character)", "infos", "silhouette",
		"The Play test character, as a grey ghost under the cursor: judge the height of a cliff or a room at the "
		+ "scale of the player. It follows « Character size » of the Play test.")
	if apres != null and apres.get_parent() != null:
		var boite := apres.get_parent()
		boite.add_child(case_infos)
		boite.move_child(case_infos, apres.get_index() + 1)
		boite.add_child(case_silhouette)
		boite.move_child(case_silhouette, case_infos.get_index() + 1)

	silhouette = Silhouette.new()
	silhouette.visible = false
	ed._vue._vue.add_child(silhouette)


func _case(texte: String, section: String, cle: String, infobulle: String) -> CheckBox:
	var c := CheckBox.new()
	c.text = texte
	c.tooltip_text = infobulle
	c.button_pressed = bool(_ed._lire_reglage(section, cle, true))
	c.toggled.connect(func(oui: bool) -> void:
		_ed._ecrire_reglage(section, cle, oui)
		_signature = ""
		_sig_silhouette = "")
	return c


func _process(_dt: float) -> void:
	if _ed == null or _ed._vue == null:
		return
	_suivre_le_panneau()
	_suivre_la_silhouette()


# ── LE PANNEAU ───────────────────────────────────────────────────────────────────────────────────────

## Ce que l'écran sait, ramené à ce que dit le panneau.
func infos() -> Dictionary:
	var vue = _ed._vue
	var i := {"etage": int(vue.etage), "outil": libelle_outil()}
	if _ed._active >= 0 and _ed._active < _ed._couches.size():
		i["couche"] = str(_ed._couches[_ed._active].get("nom", ""))
		i["cases"] = int(vue.monde().nombre_de_cases()) if vue.monde() != null else 0
	var sel: Dictionary = vue.selection
	if not sel.is_empty():
		if not is_same(sel, _sel_mesuree) or sel.size() != _sel_taille:
			_sel_mesuree = sel
			_sel_taille = sel.size()
			_sel_dims = dimensions(sel)
		i["selection"] = sel.size()
		i["selection_dims"] = _sel_dims
	var g: Vector3i = vue.dimensions_du_glisse()
	if g != Vector3i.ZERO:
		i["glisse"] = g
	return i


## L'outil, et sa taille quand il en a une.
func libelle_outil() -> String:
	var vue = _ed._vue
	var outil := str(vue.outil)
	var nom: String = NOMS_OUTILS.get(outil, outil.capitalize())
	match outil:
		"ajouter", "creuser", "selectionner":
			return "%s · %s %d" % [nom, NOMS_FORMES.get(str(vue.forme), str(vue.forme)), int(vue.taille)]
		"boite":
			return "Box · hollow" if vue.creux else "Box"
		"forme":
			var q := str(vue.forme_speciale.get("quoi", ""))
			if q == "salle":
				return "Room · %d floor(s)" % int(vue.forme_speciale.get("etages", 1))
			return "%s · size %d" % [NOMS_SPECIALES.get(q, q.capitalize()), int(vue.forme_speciale.get("taille", 1))]
		"eau":
			if _ed.get("_largeur_eau") != null:
				return "Water · river width %d" % int(_ed._largeur_eau.value)
	return nom


## La boîte qui contient des cases, en cases : x × y × z. PUR.
static func dimensions(cases: Dictionary) -> Vector3i:
	if cases.is_empty():
		return Vector3i.ZERO
	var bas := Vector3i(1 << 30, 1 << 30, 1 << 30)
	var haut := -bas
	for c in cases:
		var p: Vector3i = c
		bas = Vector3i(mini(bas.x, p.x), mini(bas.y, p.y), mini(bas.z, p.z))
		haut = Vector3i(maxi(haut.x, p.x), maxi(haut.y, p.y), maxi(haut.z, p.z))
	return haut - bas + Vector3i.ONE


static func ecrire_dims(d: Vector3i) -> String:
	return "%d × %d × %d" % [d.x, d.y, d.z]


## Les lignes du panneau. PUR : `i` comme le rend `infos()`.
static func lignes(i: Dictionary) -> PackedStringArray:
	var l := PackedStringArray()
	var gris := Palette.GRIS.to_html(false)
	var olive := Palette.OLIVE.to_html(false)
	if i.has("couche"):
		l.append("[color=#%s]Layer[/color]  [b]%s[/b]  [color=#%s]· %d cells[/color]" % [gris, i["couche"], gris,
			int(i.get("cases", 0))])
	l.append("[color=#%s]Floor[/color]  [b]y = %d[/b]" % [gris, int(i.get("etage", 0))])
	l.append("[color=#%s]Tool[/color]  %s" % [gris, i.get("outil", "")])
	if i.has("selection"):
		l.append("[color=#%s]Selection[/color]  [b]%d cells[/b]  · %s" % [gris, int(i["selection"]),
			ecrire_dims(i["selection_dims"])])
	if i.has("glisse"):
		l.append("[color=#%s][b]Drag  %s[/b][/color]" % [olive, ecrire_dims(i["glisse"])])
	l.append("[color=#%s]x × y × z, in cells[/color]" % gris)
	return l


func _montrer() -> bool:
	return case_infos != null and case_infos.button_pressed and _ed._atelier in ATELIERS \
		and not (_ed._manuel != null and _ed._manuel.visible)


func _suivre_le_panneau() -> void:
	var montrer := _montrer()
	var i := infos() if montrer else {}
	var sig := "%s|%s" % [montrer, str(i)]
	if sig != _signature:
		_signature = sig
		visible = montrer
		if montrer:
			_texte.text = "\n".join(lignes(i))
			reset_size()
	if visible:
		_placer()


## En haut à droite de la VUE : à gauche de la barre de droite visible, sous le bandeau des formes s'il est ouvert.
func _placer() -> void:
	var parent := get_parent() as Control
	if parent == null:
		return
	var bord := parent.size.x
	for n in parent.get_children():
		var p := n as PanelContainer
		if p != null and p != self and p.visible and p.anchor_left == 1.0:
			bord = minf(bord, p.position.x)
	var haut := 10.0
	var legende = _ed.get("_legende_formes")
	if legende != null and (legende as Control).visible:
		haut += (legende as Control).size.y
	position = Vector2(bord - size.x - MARGE, haut)


# ── LE REPÈRE DE TAILLE ──────────────────────────────────────────────────────────────────────────────

## PROPOSÉ : le fantôme se tient dans la case qu'un clic d'AJOUT remplirait (la case de la grille en visée Grid, la case
## devant la face visée en Sculpt), debout sur son plancher, tourné vers la caméra — on le compare à la case visée et à ce
## qui l'entoure. Caché en Navigate, quand rien n'est visé, hors des ateliers du monde.
func _suivre_la_silhouette() -> void:
	var vue = _ed._vue
	var souris: Vector2 = vue._derniere_souris
	var montrer: bool = case_silhouette != null and case_silhouette.button_pressed \
		and _ed._atelier in ATELIERS_SILHOUETTE and vue.mode == "monde" and not vue.naviguer \
		and souris.x >= 0.0 and not (_ed._manuel != null and _ed._manuel.visible)
	var cam: Camera3D = vue._camera
	var sig := "%s|%s|%s|%s|%s|%s" % [montrer, souris, str(cam.global_transform) if montrer else "", vue.etage, vue.visee,
		vue.taille_personnage]
	if sig == _sig_silhouette:
		return
	_sig_silhouette = sig
	if not montrer:
		silhouette.visible = false
		return
	var point: Dictionary = vue.point_vise(souris, "ajouter")
	if point.is_empty():
		silhouette.visible = false
		return
	var c := Outils.ancre("ajouter", point)
	silhouette.regler_taille(vue.taille_personnage)
	silhouette.poser(Vector3(c.x + 0.5, c.y, c.z + 0.5), cam.global_position)
	silhouette.visible = true
