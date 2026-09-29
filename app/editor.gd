extends Control
## MARCHINGBLOCKS — le logiciel. Tout ce que faisait le greffon Godot, dans un exécutable autonome.
##
## ⚠ **DÉCIDÉ (Jordan, 27 septembre 2026)** : le projet devient un LOGICIEL, MarchingBlocks, vendu 60 €
## en un seul exécutable chiffré. Il exportera plus tard vers trois greffons de peinture — Godot, Unity,
## Unreal — écrits APRÈS lui. Son écran reprend celui de SoluTiles (`D:/AbsoluTiles`), « le même genre
## de projet, mais 3D au lieu de 2D ».
##
## ── LA DISPOSITION, REPRISE DE SOLUTILES ─────────────────────────────────────────────────────────────
##
##   • une BARRE DE TITRE : le nom, la version (lue dans `project.godot`, jamais recopiée), et un bandeau
##     qui fait défiler des conseils et porte les annonces ;
##   • la VUE en plein cadre — ici en 3D ;
##   • deux panneaux POSÉS SUR la vue, translucides au repos : à GAUCHE ce qu'on regarde et ce qu'on
##     échange avec l'artiste, à DROITE ce que fait la main ;
##   • un panneau d'ATTENTE nommé pour toute opération longue — un tranchage prend quelques secondes.
##
## ── LES TROIS ATELIERS (« rooms » de SoluTiles) ──────────────────────────────────────────────────────
##
##   • WITNESS — le témoin, ou le travail importé, qu'on fait tourner. L'aller-retour avec l'artiste.
##   • WORLD — un monde qu'on peint case par case avec les tuiles tranchées. C'est ce que faisait
##     le GridMap de l'éditeur Godot ; ici il faut notre propre pinceau (`vue.gd`). Il s'appelait
##     « Test world » jusqu'au 29 septembre 2026 (Jordan).
##   • PLAY TEST — le même monde, sans pinceau : on y marche et on y saute avec un personnage
##     (`personnage.gd`), pour juger à hauteur de joueur. Aucune case n'y change.
##
## ⚠ **LE CŒUR N'EST PAS RECOPIÉ.** Tout passe par `addons/marchingblocks_core/` — le modèle, le témoin, le
## trancheur, les opérations d'étage — exactement comme le greffon. Deux écrans, une seule
## vérité : c'est ce qui garantit que le logiciel fait CE QUE FAIT le greffon, et pas une imitation.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const RP := preload("res://addons/marchingblocks_core/repli_procedural.gd")
const Etages := preload("res://addons/marchingblocks_core/etages.gd")
const Outils := preload("res://addons/marchingblocks_core/outils.gd")
const FormatNeutre := preload("res://addons/marchingblocks_core/format_neutre.gd")
const Palette := preload("res://app/palette.gd")
const Section := preload("res://app/section.gd")
const Panneau := preload("res://app/panneau.gd")
const Vue := preload("res://app/vue.gd")
const Projet := preload("res://app/projet.gd")
const Icones := preload("res://app/icones.gd")
const Manuel := preload("res://app/manuel.gd")

## Ce qui survit au projet lui-même : le dernier ouvert.
const REGLAGES := "user://reglages.cfg"

const LARGEUR_GAUCHE := 300
const LARGEUR_DROITE := 308
const SECONDES_CONSEIL := 7.0

## Les conseils du bandeau. ⚠ Chacun dit un GESTE ou une PROMESSE vérifiable, jamais un slogan.
const CONSEILS: Array[String] = [
	"One witness block carries every tile. Sculpt it, bring it back, paint with it.",
	"The witness is proven complete: not one tile missing, not one extra.",
	"World: left click applies the tool, right click does the opposite. Ctrl+Z undoes a whole stroke.",
	"Play test: walk your world. Z Q S D to move, Space to jump, Shift to run, right drag to turn the camera.",
	"Tab switches Grid (paint on the floor plane) and Sculpt (paint against the matter).",
	"Space turns Navigate on and off: A Z E Q S D to fly (Q W E A S D on QWERTY), right drag to look.",
	"A, D, S, B pick Add, Dig, Select, Box. [ and ] change the brush size.",
	"Arrow keys move the selection, Shift + Up / Down lifts it. Ctrl+C, Ctrl+X, Ctrl+V work across layers.",
	"Middle mouse turns the view, Shift + middle slides it, the wheel zooms.",
	"A red cube is a tile your library does not have. Nothing is ever filled in for you.",
	"Keep your relief inside its cell: the slicer cuts straight through the cell centres.",
	"Import your work to SEE what the slicer will read, before slicing anything.",
	"The six colours of the witness are six tile families: open air or underground, floor, wall, ceiling.",
	"Each layer has its own tiles and its own cells. Slicing a new work into a layer keeps its painting.",
	"Your project saves itself after every change, and reopens when you come back.",
]

var _vue: Vue
var _gauche: Panneau
var _droite: Panneau
var _attente: PanelContainer
var _attente_titre: Label
var _attente_note: Label
var _bandeau: Button
var _manuel: Control
var _conseil := 0
var _ecoule := 0.0

var _boutons_atelier := {}
var _atelier := "witness"
## LES MORCEAUX DE L'ÉCRAN QUI DÉPENDENT DU CONTEXTE — tous montrés ou cachés par `_contexte()`, et
## nulle part ailleurs (charte §6 : une règle vit à UN endroit).
var _section_jeu: Control
var _titre_projet: Control
var _section_projet: Control
var _section_couches: Control
var _titre_aller_retour: Control
var _etapes_artiste: Array[Control] = []
var _etapes_monde: Array[Control] = []
var _section_temoin: Control
var _section_raccourcis: Control
var _zone_reference: Control
var _bouton_revoir_temoin: Button
var _bouton_trancher_travail: Button
var _bouton_supprimer_couche: Button
var _bouton_naviguer: Button
var _titre_pinceau: Control
var _ligne_taille: Control
var _ligne_forme: Control

var _plans: CheckButton
var _etiquette_vue: Label
var _etiquette_etage: Label
var _rapport: RichTextLabel
var _dialogue: FileDialog
var _action_fichier := ""

## Le `.glb` importé, RELU au moment de trancher : l'artiste a pu réenregistrer entre-temps.
## ⚠ **UNE GRILLE DE TRAVAUX, PAS UN SEUL — DEMANDÉ PAR JORDAN (28 septembre 2026).** Un seul travail
## tenait dans `_travail` : réimporter en écrasait la mémoire, et comparer deux sculptures demandait
## de réimporter à chaque fois. Chaque import s'ajoute désormais à la liste ; on en choisit un, on le
## voit, puis on le tranche.
## ⚠ **LA LISTE NE SURVIT PAS À LA SESSION** — `projet.gd` porte les couches et leurs cases, pas les
## fichiers sources. C'est OUVERT : les y mettre demanderait de traiter un chemin devenu invalide.
var _travaux: Array = []
var _travail_actif := -1
var _liste_travaux: VBoxContainer
var _vide_travaux: Label
var _etiquette_cible: Label

## LES COUCHES (`projet.gd`), dans l'ordre des massifs de la vue : {nom, source, visible}.
## ⚠ LEURS CASES N'Y SONT PAS : elles vivent dans la grille `Cases` de chaque massif, seule autorité ;
## on ne les recopie qu'au moment d'écrire le fichier.
var _couches: Array = []
var _active := 0
var _liste_couches: VBoxContainer
var _nom_couche: LineEdit
## Le fichier du projet, réécrit après chaque changement.
var _projet := ""
var _etiquette_projet: Label
var _etiquette_projet_chemin: Label
## Vrai pendant qu'on rebâtit un projet : rien ne s'enregistre d'un monde à moitié relu.
var _ouverture := false
## Les couches supprimées, gardées vivantes tant qu'un Ctrl+Z peut les rendre.
var _detachees: Array = []

var _histoire := UndoRedo.new()
## Le coup en cours : {case: [avant, après]}.
var _coup := {}
var _coup_nom := ""

var _boutons_visee := {}
var _boutons_outil := {}
var _taille: HSlider
var _valeur_taille: Label
var _boutons_forme := {}
var _creux: CheckButton
var _bouton_coller: Button
var _compteur_etage: SpinBox
var _section_selection: Control
var _etiquette_selection: Label
var _etiquette_portee: Label
## Le PRESSE-PAPIERS : des décalages relatifs (`Outils.copier`). Il n'appartient à aucune couche — on
## copie dans la roche et on colle dans la glace.
var _presse_papiers: Array = []


## ⚠ `UndoRedo` N'EST PAS COMPTÉ PAR RÉFÉRENCE : il fuit si on ne le libère pas, avec les couches
## supprimées qu'il garde en vie.
func _notification(quoi: int) -> void:
	if quoi == NOTIFICATION_PREDELETE:
		for m in _detachees:
			m.free()
		_histoire.free()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_regler_fenetre()
	_batir()
	_montrer_temoin()
	_aller_a("witness")
	_dire("[i]Look at the witness, open Project to exchange it with your artist, or open the World "
		+ "and paint.[/i]")
	_histoire.version_changed.connect(_enregistrer)
	await get_tree().process_frame
	_regler_fenetre()
	await _ouvrir_au_lancement()


## ⚠ LA FENÊTRE S'OUVRE MAXIMISÉE (Jordan, 27 septembre 2026 : « on a besoin de place ») — fenêtrée,
## donc la barre des tâches et les autres fenêtres restent accessibles, mais toute la surface utile.
## Reposée après la première image : selon la façon de lancer, le mode demandé dans `_ready` peut être
## écrasé par celui du projet.
## ⚠ Et l'échelle de contenu est COUPÉE : le projet hérite d'un réglage de jeu en pixel art (viewport
## 640×320 étiré au multiple entier), qui rendrait une interface floue et énorme.
func _regler_fenetre() -> void:
	var fenetre: Window = get_window()
	if fenetre == null:
		return
	fenetre.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	fenetre.min_size = Vector2i(1100, 680)
	if fenetre.mode != Window.MODE_MAXIMIZED and fenetre.mode != Window.MODE_FULLSCREEN:
		fenetre.mode = Window.MODE_MAXIMIZED


func _process(delta: float) -> void:
	_ecoule += delta
	if _ecoule < SECONDES_CONSEIL:
		return
	_ecoule = 0.0
	_montrer_conseil(_conseil)
	_conseil = (_conseil + 1) % CONSEILS.size()


func _montrer_conseil(i: int) -> void:
	_bandeau.text = CONSEILS[i] + "     ·  click for the manual"


# ── LA CONSTRUCTION DE L'ÉCRAN ───────────────────────────────────────────────────────────────────────
#
# ⚠ **LA HIÉRARCHIE EST VOULUE (Jordan, 27 septembre 2026 : « une hiérarchisation des fonctionnalités
# les plus importantes aux moindres »).** De haut en bas, dans chaque barre, ce qu'on touche le plus
# souvent d'abord :
#   GAUCHE — ce qu'on REGARDE et ce qu'on échange : l'atelier, le projet, le témoin, l'aller-retour
#            avec l'artiste, les raccourcis (repliés) ; le RAPPORT est épinglé en bas, toujours visible.
#   DROITE — ce que fait la MAIN : les outils, la sélection (seulement quand elle existe), les couches,
#            le tranchage, puis les opérations de forme (repliées : on s'en sert moins).

func _batir() -> void:
	theme = Palette.theme()
	var fond := Panel.new()
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.add_theme_stylebox_override("panel", Palette.fond(Palette.FOND_VUE, 0, 0))
	add_child(fond)

	var colonne := VBoxContainer.new()
	colonne.set_anchors_preset(Control.PRESET_FULL_RECT)
	colonne.add_theme_constant_override("separation", 0)
	add_child(colonne)
	colonne.add_child(_barre_titre())

	var corps := Control.new()
	corps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corps.clip_contents = true
	colonne.add_child(corps)

	_vue = Vue.new()
	_vue.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vue.coup_commence.connect(_coup_commence)
	_vue.touche.connect(_touche)
	_vue.selection_changee.connect(_selection_changee)
	_vue.colle.connect(_colle)
	_vue.boite_trop_grande.connect(func() -> void:
		_dire("[color=#e0603c]Box too large[/color] — more than %d cells. Draw a smaller one." \
			% Outils.VOLUME_MAXI))
	corps.add_child(_vue)

	_gauche = _panneau(corps, true, LARGEUR_GAUCHE)
	_batir_gauche(_gauche.get_meta("tete"), _gauche.get_meta("pile"), _gauche.get_meta("reference"))
	_batir_rapport(_gauche.get_meta("pied"))
	_droite = _panneau(corps, false, LARGEUR_DROITE)
	_batir_droite(_droite.get_meta("pile"))
	_batir_attente(corps)

	_manuel = Manuel.new()
	add_child(_manuel)

	_dialogue = FileDialog.new()
	_dialogue.access = FileDialog.ACCESS_FILESYSTEM
	_dialogue.use_native_dialog = true
	_dialogue.file_selected.connect(_fichier_choisi)
	_dialogue.dir_selected.connect(_fichier_choisi)
	add_child(_dialogue)


func _barre_titre() -> Control:
	var barre := PanelContainer.new()
	barre.custom_minimum_size = Vector2(0, 40)
	var style := Palette.fond(Palette.BARRE_TITRE, 0, 0)
	style.content_margin_left = 14
	style.content_margin_right = 10
	style.border_color = Palette.FILET
	style.border_width_bottom = 1
	barre.add_theme_stylebox_override("panel", style)
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 10)
	barre.add_child(ligne)

	if ResourceLoader.exists("res://MARQUE/icone.png"):
		var embleme := TextureRect.new()
		embleme.texture = load("res://MARQUE/icone.png")
		embleme.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		embleme.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		embleme.custom_minimum_size = Vector2(24, 24)
		ligne.add_child(embleme)
	var marque := Label.new()
	marque.text = "MarchingBlocks"
	marque.add_theme_font_override("font", Palette.gras())
	marque.add_theme_font_size_override("font_size", 17)
	marque.add_theme_color_override("font_color", Palette.OLIVE)
	ligne.add_child(marque)
	var version := Label.new()
	# ⚠ LA VERSION VIT DANS `project.godot` ET NULLE PART AILLEURS (leçon de SoluTiles).
	version.text = "v" + str(ProjectSettings.get_setting("application/config/version", "0.1.0"))
	version.add_theme_color_override("font_color", Palette.GRIS)
	version.add_theme_font_size_override("font_size", 12)
	ligne.add_child(version)
	var devise := Label.new()
	devise.text = "Sculpt one block. Paint a world."
	devise.add_theme_color_override("font_color", Palette.GRIS)
	devise.add_theme_font_size_override("font_size", 12)
	ligne.add_child(devise)

	# ⚠ LE BANDEAU EST UN BOUTON : il ouvre le manuel (Jordan). Il le DIT dans son texte — un bandeau
	# cliquable qui ne se présente pas comme tel ne serait jamais cliqué.
	_bandeau = Button.new()
	_bandeau.theme_type_variation = Palette.DISCRET
	_bandeau.icon = Icones.icone("ampoule")
	# ⚠ ALIGNÉ À GAUCHE : aligné à droite, le texte partait au bout de la barre et laissait l'ampoule
	# seule au milieu, sans rien à éclairer.
	_bandeau.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_bandeau.clip_text = true
	_bandeau.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bandeau.focus_mode = Control.FOCUS_NONE
	_bandeau.tooltip_text = "Open the user guide (F1)"
	_bandeau.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for c in ["font_color", "font_focus_color", "icon_normal_color", "icon_focus_color"]:
		_bandeau.add_theme_color_override(c, Palette.AMBRE)
	for c in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color", "icon_hover_color",
			"icon_pressed_color", "icon_hover_pressed_color"]:
		_bandeau.add_theme_color_override(c, Palette.AMBRE.lightened(0.25))
	_bandeau.add_theme_font_size_override("font_size", 12)
	_bandeau.pressed.connect(func() -> void: _manuel.ouvrir())
	_montrer_conseil(0)
	_conseil = 1
	ligne.add_child(_bandeau)

	var manuel := Button.new()
	manuel.text = "Manual"
	manuel.icon = Icones.icone("livre")
	manuel.tooltip_text = "The user guide (F1)"
	manuel.focus_mode = Control.FOCUS_NONE
	manuel.pressed.connect(func() -> void: _manuel.ouvrir())
	ligne.add_child(manuel)
	return barre


## Un panneau posé sur la vue, ancré à gauche ou à droite sur TOUTE la hauteur. `pile` défile ; `pied`
## est ÉPINGLÉ sous elle et ne défile jamais (le rapport).
## ⚠ LES QUATRE ANCRES, pas deux (leçon de SoluTiles) : ancrer seulement le haut laisse le panneau à sa
## taille minimale et coupe ce qui dépasse.
func _panneau(parent: Control, a_gauche: bool, largeur: int) -> Panneau:
	var p := Panneau.new()
	var style := Palette.fond(Palette.PANNEAU, 0, 10)
	style.content_margin_right = 6
	style.border_color = Palette.FILET
	if a_gauche:
		style.border_width_right = 1
	else:
		style.border_width_left = 1
	p.add_theme_stylebox_override("panel", style)
	p.anchor_top = 0.0
	p.anchor_bottom = 1.0
	p.anchor_left = 0.0 if a_gauche else 1.0
	p.anchor_right = 0.0 if a_gauche else 1.0
	p.offset_left = 0.0 if a_gauche else -largeur
	p.offset_right = largeur if a_gauche else 0.0
	parent.add_child(p)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 10)
	p.add_child(colonne)
	var defile := ScrollContainer.new()
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colonne.add_child(defile)
	var marge := MarginContainer.new()
	marge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marge.add_theme_constant_override("margin_right", 8)
	defile.add_child(marge)
	var pile := VBoxContainer.new()
	pile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pile.add_theme_constant_override("separation", 14)
	marge.add_child(pile)
	var pied := VBoxContainer.new()
	pied.add_theme_constant_override("separation", 6)
	colonne.add_child(pied)
	p.set_meta("pile", pile)
	p.set_meta("pied", pied)
	if a_gauche:
		p.set_meta("reference", _zone_de_reference(p, colonne, defile, pied))
	return p


## LA ZONE DE RÉFÉRENCE — DEMANDÉE PAR JORDAN (29 septembre 2026) : la barre de gauche se coupe en
## deux, ce qui COMPTE en haut (75 % de la hauteur, avec le rapport épinglé dessous) et ce qu'on
## consulte en bas (25 % : le témoin, les raccourcis), chacune dans SON défilement. Déplier les
## raccourcis ne pousse donc plus les étapes hors de l'écran.
## ⚠ **LE 75 % EST UN RAPPORT D'ÉTIREMENT (3 contre 1), PAS UNE HAUTEUR** : la fenêtre change de taille,
## le rapport reste. Et quand le bas n'a rien à montrer (Play test), `_contexte()` le cache : le haut
## prend tout.
## ⚠ **L'ATELIER EST ÉPINGLÉ EN HAUT (Jordan, 29 septembre 2026)** : `tete` ne défile pas. C'est la
## décision la plus haute de l'écran ; la voir partir avec le défilement obligeait à remonter pour changer
## d'atelier.
func _zone_de_reference(p: Control, colonne: VBoxContainer, defile: ScrollContainer,
		pied: VBoxContainer) -> VBoxContainer:
	var haut := VBoxContainer.new()
	haut.add_theme_constant_override("separation", 10)
	haut.size_flags_vertical = Control.SIZE_EXPAND_FILL
	haut.size_flags_stretch_ratio = 3.0
	colonne.remove_child(defile)
	colonne.remove_child(pied)
	var tete := VBoxContainer.new()
	tete.add_theme_constant_override("separation", 8)
	var marge_tete := MarginContainer.new()
	marge_tete.add_theme_constant_override("margin_right", 8)
	marge_tete.add_child(tete)
	haut.add_child(marge_tete)
	p.set_meta("tete", tete)
	haut.add_child(defile)
	haut.add_child(pied)
	colonne.add_child(haut)
	var bas := VBoxContainer.new()
	bas.add_theme_constant_override("separation", 6)
	bas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bas.size_flags_stretch_ratio = 1.0
	bas.add_child(_grand_titre("REFERENCE"))
	var defile_bas := ScrollContainer.new()
	defile_bas.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile_bas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bas.add_child(defile_bas)
	var marge := MarginContainer.new()
	marge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marge.add_theme_constant_override("margin_right", 8)
	defile_bas.add_child(marge)
	var pile := VBoxContainer.new()
	pile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pile.add_theme_constant_override("separation", 14)
	marge.add_child(pile)
	colonne.add_child(bas)
	_zone_reference = bas
	return pile


## UN GROS SÉPARATEUR — DEMANDÉ PAR JORDAN (29 septembre 2026). Entre les GROUPES de sections (l'atelier,
## le projet, l'aller-retour, la référence), pas entre les sections : un titre net sur un filet épais,
## qui se voit d'un coup d'œil là où le petit titre gris se lisait.
func _grand_titre(texte: String) -> Control:
	var bloc := VBoxContainer.new()
	bloc.add_theme_constant_override("separation", 4)
	var l := Label.new()
	l.text = texte
	l.add_theme_font_override("font", Palette.gras())
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Palette.OLIVE)
	bloc.add_child(l)
	var filet := ColorRect.new()
	filet.color = Palette.OLIVE
	filet.custom_minimum_size = Vector2(0, 3)
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloc.add_child(filet)
	return bloc


func _petit_titre(texte: String) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Palette.GRIS)
	return l


## Un texte qui se REPLIE. ⚠ Un libellé qui grandit impose sa largeur à toute la barre (leçon de
## SoluTiles, et du greffon : 647 px pour l'étiquette d'étage allongée, 16 une fois repliable).
func _texte(texte: String, taille := 12, couleur := Palette.TEXTE) -> Label:
	var l := Label.new()
	l.text = texte
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	return l


func _bouton(texte: String, infobulle: String, action: Callable, icone := "", variante := "") -> Button:
	var b := Button.new()
	b.text = texte
	b.tooltip_text = infobulle
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 32)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT if icone != "" else HORIZONTAL_ALIGNMENT_CENTER
	if icone != "":
		b.icon = Icones.icone(icone)
	if variante != "":
		b.theme_type_variation = variante
	b.pressed.connect(action)
	return b


## Des boutons côte à côte, de même largeur.
func _rangee(boutons: Array, separation := 6) -> HBoxContainer:
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", separation)
	for b in boutons:
		(b as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# ⚠ UNE LIGNE PAR BOUTON dans une rangée : replié, « Save as » passait sur deux lignes et la rangée
		# doublait de hauteur pour un seul mot.
		(b as Button).autowrap_mode = TextServer.AUTOWRAP_OFF
		ligne.add_child(b)
	return ligne


## Des boutons en grille de `colonnes`.
func _grille(boutons: Array, colonnes := 2) -> GridContainer:
	var g := GridContainer.new()
	g.columns = colonnes
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	for b in boutons:
		(b as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(b as Button).autowrap_mode = TextServer.AUTOWRAP_OFF
		g.add_child(b)
	return g


func _batir_gauche(tete: VBoxContainer, pile: VBoxContainer, reference: VBoxContainer) -> void:
	# L'ATELIER : la décision la plus haute de l'écran, donc tout en haut, en grand — et ÉPINGLÉ.
	tete.add_child(_grand_titre("WORKSPACE"))
	var groupe := ButtonGroup.new()
	var ateliers: Array = []
	for a in [
		["projet", "Project", "enregistrer", "Save, open, and the round trip with your artist: export, "
			+ "import, slice, export to engines."],
		["witness", "Witness", "cube", "The block your artist sculpts: look at it, export it, bring it back."],
		["monde", "World", "monde", "Paint worlds with the sliced tiles."],
		["jeu", "Play test", "jouer", "Walk and jump through your world, at the height of a player."],
	]:
		var b := Button.new()
		b.text = a[1]
		b.icon = Icones.icone(a[2])
		b.tooltip_text = a[3]
		b.toggle_mode = true
		b.button_group = groupe
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_override("font", Palette.gras())
		b.add_theme_constant_override("icon_max_width", 20)
		b.pressed.connect(_aller_a.bind(a[0]))
		_boutons_atelier[a[0]] = b
		ateliers.append(b)
	# Quatre ateliers : en grille de deux, une rangée de quatre ne tient pas dans 300 px.
	tete.add_child(_grille(ateliers, 2))

	# LE PLAY TEST : ses commandes, visibles dans cet atelier seulement.
	_section_jeu = Section.new("Play test", true, Icones.icone("jouer"))
	pile.add_child(_section_jeu)
	_section_jeu.contenu.add_child(_texte("You walk on the tiles you SEE — your art, not the cells. "
		+ "Nothing you do here changes the world.", 11, Palette.GRIS))
	var commandes := GridContainer.new()
	commandes.columns = 2
	commandes.add_theme_constant_override("h_separation", 10)
	commandes.add_theme_constant_override("v_separation", 4)
	for r in [["ZQSD", "Move (WASD on QWERTY)"], ["Space", "Jump"], ["Shift", "Run"],
			["Right drag", "Turn the camera"], ["Wheel", "Closer · farther"], ["Backspace", "Back to start"],
			["Esc", "Back to World"]]:
		commandes.add_child(_touche_clavier(r[0]))
		commandes.add_child(_texte(r[1], 11, Palette.GRIS))
	_section_jeu.contenu.add_child(commandes)
	_section_jeu.contenu.add_child(_rangee([
		_bouton("Back to start", "Puts the character back where it started (Backspace).",
			func() -> void: _vue.reapparaitre(), "haut"),
		_bouton("Leave", "Back to World (Esc).", _aller_a.bind("monde"), "croix"),
	], 4))

	_titre_projet = _grand_titre("PROJECT")
	pile.add_child(_titre_projet)
	# ⚠ « SAVE · OPEN » ET NON « PROJECT » : sous le gros titre PROJECT, le même mot en bande se lisait
	# deux fois de suite (vu à l'image).
	var projet := Section.new("Save · open", true, Icones.icone("enregistrer"))
	_section_projet = projet
	pile.add_child(projet)
	_etiquette_projet = Label.new()
	_etiquette_projet.add_theme_font_override("font", Palette.gras())
	_etiquette_projet.add_theme_font_size_override("font_size", 14)
	_etiquette_projet.clip_text = true
	projet.contenu.add_child(_etiquette_projet)
	_etiquette_projet_chemin = _texte("", 11, Palette.GRIS)
	projet.contenu.add_child(_etiquette_projet_chemin)
	projet.contenu.add_child(_rangee([
		_bouton("New", "Starts an empty project with one layer. The current one is already saved.",
			_nouveau_projet, "nouveau"),
		_bouton("Open", "Opens a MarchingBlocks project (.mbproj).", func() -> void: _demander("ouvrir"),
			"ouvrir"),
		_bouton("Save as", "Writes the project where you want it. It keeps saving itself there.",
			func() -> void: _demander("enregistrer"), "enregistrer"),
	], 4))

	# ── LE TÉMOIN — en RÉFÉRENCE (Jordan) : on le consulte, on n'y travaille pas.
	var temoin := Section.new("Witness", true, Icones.icone("cube"))
	_section_temoin = temoin
	reference.add_child(temoin)
	_etiquette_vue = _texte("showing: the computed witness", 11, Palette.GRIS)
	temoin.contenu.add_child(_etiquette_vue)
	# Jordan (27 septembre 2026) : voir OÙ le trancheur coupe, sur le témoin comme sur le travail importé.
	_plans = CheckButton.new()
	_plans.text = "Show the cells"
	_plans.icon = Icones.icone("grille")
	_plans.add_theme_constant_override("icon_max_width", 16)
	_plans.tooltip_text = ("Shows the cutting planes: the slicer cuts through the cell CENTRES, on all "
		+ "three axes.
Each piece between them becomes one tile — keep your relief inside its cell.")
	_plans.toggled.connect(func(v: bool) -> void: _vue.montrer_plans_de_coupe(v))
	temoin.contenu.add_child(_plans)
	temoin.contenu.add_child(_legende())
	# ⚠ SEULEMENT QUAND ON REGARDE UN TRAVAIL : sur le témoin, « montrer le témoin » ne fait rien.
	_bouton_revoir_temoin = _bouton("Show the witness", "Back to the computed witness.",
		func() -> void: _travail_vu(false), "cube")
	_bouton_revoir_temoin.visible = false
	temoin.contenu.add_child(_bouton_revoir_temoin)

	# ── LES COUCHES — où tout atterrit, donc AVANT les étapes qui y déposent.
	var couches := Section.new("Layers", true, Icones.icone("couches"))
	pile.add_child(couches)
	_section_couches = couches
	couches.contenu.add_child(_texte("A layer holds its own cells AND its own tiles. Slicing dresses "
		+ "the ACTIVE one.", 11, Palette.GRIS))
	_liste_couches = VBoxContainer.new()
	_liste_couches.add_theme_constant_override("separation", 4)
	couches.contenu.add_child(_liste_couches)
	_nom_couche = LineEdit.new()
	_nom_couche.placeholder_text = "rename the active layer"
	_nom_couche.text_submitted.connect(func(_t: String) -> void: _renommer_couche())
	_nom_couche.focus_exited.connect(_renommer_couche)
	couches.contenu.add_child(_nom_couche)
	couches.contenu.add_child(_rangee([
		_bouton("New layer", "Adds an empty layer and makes it the one you paint on.", _nouvelle_couche,
			"plus"),
		_bouton("Delete", "Deletes the active layer (Ctrl+Z brings it back).", _supprimer_couche,
			"poubelle", Palette.DANGER),
	]))
	_bouton_supprimer_couche = (couches.contenu.get_child(couches.contenu.get_child_count() - 1)
		.get_child(1) as Button)

	# ── LES QUATRE ÉTAPES — DEMANDÉ PAR JORDAN (28 septembre 2026).
	#
	# ⚠ **L'ORDRE EST LE MODE D'EMPLOI.** Les mêmes boutons étaient là, mais répartis entre « Artist
	# round trip » à gauche et « Slice » / « Export to engines » à droite, au milieu des outils : rien
	# ne disait qu'ils formaient UNE chaîne, ni dans quel sens la parcourir. Numérotés et mis bout à
	# bout, ils se lisent sans manuel — et la barre de droite ne garde que ce qui édite.
	_titre_aller_retour = _grand_titre("THE ROUND TRIP")
	pile.add_child(_titre_aller_retour)

	var etape1 := Section.new("1 · Export the witness", true, Icones.icone("exporter"))
	pile.add_child(etape1)
	_etapes_artiste.append(etape1)
	etape1.contenu.add_child(_texte("Send the block to Blender as one welded .obj.", 11, Palette.GRIS))
	etape1.contenu.add_child(_bouton("Export the witness…",
		"Writes the witness as ONE .obj (+ its .mtl) for Blender — fully welded, six named materials.\n"
		+ "Do not MOVE it: its position identifies it "
		+ "when it comes back, not its name.\nTiles are already shrunk to half their cell, to show "
		+ "the margin you have.", func() -> void: _demander("exporter"), "exporter", Palette.PRINCIPAL))

	var etape2 := Section.new("2 · Import your work", true, Icones.icone("importer"))
	pile.add_child(etape2)
	_etapes_artiste.append(etape2)
	etape2.contenu.add_child(_texte("Bring the sculpted .glb back. Each import is kept here — pick "
		+ "the one you want to slice.", 11, Palette.GRIS))
	etape2.contenu.add_child(_bouton("Import the work…",
		"Reads the sculpted .glb (or .obj) and SHOWS it, as the slicer will read it.\nNothing is "
		+ "sliced yet.", func() -> void: _demander("importer"), "importer"))
	_liste_travaux = VBoxContainer.new()
	_liste_travaux.add_theme_constant_override("separation", 4)
	etape2.contenu.add_child(_liste_travaux)
	_vide_travaux = _texte("No work imported yet.", 11, Palette.GRIS)
	etape2.contenu.add_child(_vide_travaux)

	var etape3 := Section.new("3 · Slice into the active layer", true, Icones.icone("couteau"))
	pile.add_child(etape3)
	_etapes_monde.append(etape3)
	_etiquette_cible = _texte("", 11, Palette.OLIVE)
	etape3.contenu.add_child(_etiquette_cible)
	etape3.contenu.add_child(_texte("Gives the ACTIVE layer its tiles. Its painted cells never move.",
		11, Palette.GRIS))
	_bouton_trancher_travail = _bouton("Slice the selected work",
		"Re-reads the work you picked above, slices it, and dresses the ACTIVE layer with YOUR tiles.\n"
		+ "Its painted cells stay as they are.", _trancher_travail, "couteau", Palette.PRINCIPAL)
	_bouton_trancher_travail.disabled = true
	etape3.contenu.add_child(_bouton_trancher_travail)
	etape3.contenu.add_child(_bouton("Slice the witness",
		"Slices the computed witness into its tiles and dresses the ACTIVE layer with them.\n"
		+ "Its painted cells stay as they are.", _trancher_temoin, "cube"))

	var etape4 := Section.new("4 · Export to engines", true, Icones.icone("exporter"))
	pile.add_child(etape4)
	_etapes_monde.append(etape4)
	etape4.contenu.add_child(_texte("Writes the ACTIVE layer's tiles as a .mbset folder — read by the "
		+ "free MarchingBlocks Paint plugins for Godot, Unity and Unreal.", 11, Palette.GRIS))
	etape4.contenu.add_child(_bouton("Export the tileset…",
		"Writes <layer>.mbset/ : tileset.json (the placement rule and the tile list), tiles.glb (every "
		+ "tile, with its materials) and README.txt.\nOpen format: the tiles you make are yours.",
		func() -> void: _demander("tileset"), "exporter", Palette.PRINCIPAL))

	var aide := Section.new("Shortcuts", true, Icones.icone("clavier"))
	_section_raccourcis = aide
	reference.add_child(aide)
	var raccourcis := GridContainer.new()
	raccourcis.columns = 2
	raccourcis.add_theme_constant_override("h_separation", 10)
	raccourcis.add_theme_constant_override("v_separation", 4)
	for r in [["Tab", "Grid ↔ Sculpt"], ["Space", "Navigate on / off"], ["AZEQSD", "Fly (Navigate)"],
			["Right drag", "Look (Navigate)"], ["A D S", "Add Dig Select"], ["R  B", "Rect  Box"], ["[  ]", "Brush size"],
			["PgUp PgDn", "Floor y"], ["Arrows", "Move selection"], ["Del · Esc", "Delete · clear"],
			["Ctrl C X V", "Copy cut paste"], ["Ctrl Z · Y", "Undo · redo"], ["Middle drag", "Turn"],
			["Shift+middle", "Slide"], ["Wheel", "Zoom"], ["F1", "User guide"]]:
		raccourcis.add_child(_touche_clavier(r[0]))
		raccourcis.add_child(_texte(r[1], 11, Palette.GRIS))
	aide.contenu.add_child(raccourcis)
	aide.contenu.add_child(_bouton("Open the user guide", "Everything, explained (F1).",
		func() -> void: _manuel.ouvrir(), "livre", Palette.DISCRET))


## Une touche de clavier, dessinée comme une touche.
func _touche_clavier(texte: String) -> Control:
	var cadre := PanelContainer.new()
	var s := Palette.fond(Palette.BOUTON, 4, 0)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	s.border_color = Palette.FILET
	s.border_width_bottom = 2
	cadre.add_theme_stylebox_override("panel", s)
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", 11)
	cadre.add_child(l)
	cadre.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return cadre


## LE RAPPORT — épinglé en bas de la barre de gauche : ce qu'une action vient de faire doit se lire
## SANS défiler. Il était au fond de la barre de droite, sous tous les outils : on ne le voyait jamais.
func _batir_rapport(pied: VBoxContainer) -> void:
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", 6)
	var icone := TextureRect.new()
	icone.texture = Icones.icone("rapport")
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.custom_minimum_size = Vector2(14, 14)
	icone.modulate = Palette.GRIS
	tete.add_child(icone)
	tete.add_child(_petit_titre("REPORT"))
	pied.add_child(tete)
	var cadre := PanelContainer.new()
	var s := Palette.fond(Palette.SOMBRE, 6, 10)
	s.border_color = Palette.FILET
	s.set_border_width_all(1)
	cadre.add_theme_stylebox_override("panel", s)
	pied.add_child(cadre)
	var defile := ScrollContainer.new()
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.custom_minimum_size = Vector2(0, 150)
	cadre.add_child(defile)
	_rapport = RichTextLabel.new()
	_rapport.bbcode_enabled = true
	_rapport.fit_content = true
	_rapport.selection_enabled = true
	_rapport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rapport.add_theme_font_size_override("normal_font_size", 12)
	_rapport.add_theme_font_size_override("bold_font_size", 12)
	_rapport.add_theme_font_size_override("italics_font_size", 12)
	_rapport.add_theme_font_override("bold_font", Palette.gras())
	defile.add_child(_rapport)


## LA LÉGENDE — dérivée des six teintes de `RP.TEINTES`, jamais recopiée : une légende fausse est pire
## qu'une absence de légende. Sur deux colonnes : six lignes pleines prenaient la moitié du panneau.
func _legende() -> Control:
	var grille := GridContainer.new()
	grille.columns = 2
	grille.add_theme_constant_override("h_separation", 10)
	grille.add_theme_constant_override("v_separation", 4)
	for t in RP.TEINTES:
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 6)
		ligne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pastille := Panel.new()
		pastille.add_theme_stylebox_override("panel", Palette.fond(t["couleur"], 3, 0))
		pastille.custom_minimum_size = Vector2(11, 11)
		pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(pastille)
		ligne.add_child(_texte(str(t["nom"]).replace(" - ", " · "), 11, Palette.GRIS))
		grille.add_child(ligne)
	return grille


func _batir_droite(pile: VBoxContainer) -> void:
	# ── 1. LES OUTILS — ce qu'on touche à chaque geste.
	var outils := Section.new("Tools", true, Icones.icone("outils"))
	pile.add_child(outils)
	outils.contenu.add_child(_petit_titre("AIM  ·  Tab"))
	outils.contenu.add_child(_rangee_de_choix(_boutons_visee, [
		["grille", "Grid", "visee_grille", "Aims at the floor plane y — the grid. Good for laying out "
			+ "a map."],
		["sculpt", "Sculpt", "visee_sculpt", "Aims at the matter already there: Add builds on the face "
			+ "you point at, Dig and Select act on the cell you point at.\nWhere the ray meets no "
			+ "matter, it falls back on the floor plane."],
	], _choisir_visee))
	# LA NAVIGATION : un interrupteur à part, plus une visée (Jordan, 29 septembre 2026).
	_bouton_naviguer = Button.new()
	_bouton_naviguer.text = "Navigate  ·  Space"
	_bouton_naviguer.icon = Icones.icone("visee_naviguer")
	_bouton_naviguer.toggle_mode = true
	_bouton_naviguer.focus_mode = Control.FOCUS_NONE
	_bouton_naviguer.custom_minimum_size = Vector2(0, 32)
	_bouton_naviguer.tooltip_text = ("Space — fly around your world, then Space again to come back to "
		+ "your aim.\nA Z E Q S D (Q W E A S D on a QWERTY keyboard): Z S forward and back, Q D sideways, "
		+ "A down, E up.\nRight drag looks around. No click paints.")
	_bouton_naviguer.toggled.connect(_basculer_navigation)
	outils.contenu.add_child(_bouton_naviguer)
	outils.contenu.add_child(_petit_titre("TOOL"))
	outils.contenu.add_child(_rangee_de_choix(_boutons_outil, [
		["ajouter", "Add", "ajouter", "A — adds matter. Right click digs."],
		["creuser", "Dig", "creuser", "D — removes matter. Right click adds."],
		["selectionner", "Select", "selectionner", "S — selects matter (Shift adds to the selection). "
			+ "Right click deselects."],
		["rect", "Rect", "rect", "R — drag a FLAT rectangle on the floor plane y, whatever the aim.\n"
			+ "It takes the whole area, empty cells included: draw a room's floor, then Fill it and "
			+ "Extrude it.\nShift adds to the selection, right drag removes."],
		["boite", "Box", "boite", "B — drag a 3D box: the whole VOLUME becomes the selection, empty "
			+ "cells included.\nIn Sculpt the two corners sit on the matter; in Grid they sit on the "
			+ "floor plane.\nShift adds, right drag removes. Tick Hollow for a room with walls only."],
	], _choisir_outil, Palette.OUTIL))
	_creux = CheckButton.new()
	_creux.text = "Hollow box"
	_creux.icon = Icones.icone("evider")
	_creux.add_theme_constant_override("icon_max_width", 16)
	_creux.tooltip_text = ("Box only: keeps just the SKIN of the box — walls, floor and ceiling, nothing "
		+ "inside. That is a room.\nA box thinner than three cells on any axis has no inside, so it "
		+ "stays solid.")
	_creux.toggled.connect(func(v: bool) -> void:
		_vue.creux = v
		_vue.rafraichir())
	outils.contenu.add_child(_creux)

	_titre_pinceau = _petit_titre("BRUSH  ·  [ ]")
	outils.contenu.add_child(_titre_pinceau)
	var taille := HBoxContainer.new()
	_ligne_taille = taille
	taille.add_theme_constant_override("separation", 10)
	_taille = HSlider.new()
	_taille.min_value = 1
	_taille.max_value = 7
	_taille.step = 1
	_taille.tick_count = 7
	_taille.ticks_on_borders = true
	_taille.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_taille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_taille.tooltip_text = "[ and ] — brush size. 1 is a single cell."
	_valeur_taille = Label.new()
	_valeur_taille.text = "1"
	_valeur_taille.custom_minimum_size = Vector2(18, 0)
	_valeur_taille.add_theme_font_override("font", Palette.gras())
	_valeur_taille.add_theme_color_override("font_color", Palette.OLIVE)
	_taille.value_changed.connect(func(v: float) -> void:
		_vue.taille = int(v)
		_valeur_taille.text = str(int(v))
		_vue.rafraichir())
	taille.add_child(_taille)
	taille.add_child(_valeur_taille)
	outils.contenu.add_child(taille)
	_ligne_forme = _rangee_de_choix(_boutons_forme, [
		["sphere", "Sphere", "sphere", "A ball of cells."],
		["cube", "Cube", "cube", "A cube of cells."],
		["disque", "Disc", "disque", "Flat, across the face you point at — fills or digs a wall without "
			+ "thickening it."],
	], _choisir_forme)
	outils.contenu.add_child(_ligne_forme)

	outils.contenu.add_child(_petit_titre("FLOOR  ·  PgUp PgDn"))
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 8)
	var icone_etage := TextureRect.new()
	icone_etage.texture = Icones.icone("etage")
	icone_etage.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone_etage.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone_etage.custom_minimum_size = Vector2(18, 18)
	icone_etage.modulate = Palette.GRIS
	ligne.add_child(icone_etage)
	ligne.add_child(_texte("y =", 12))
	_compteur_etage = SpinBox.new()
	_compteur_etage.min_value = -64
	_compteur_etage.max_value = 64
	_compteur_etage.tooltip_text = "PgUp / PgDn. The Grid aims at this plane; Sculpt falls back on it."
	_compteur_etage.value_changed.connect(func(v: float) -> void:
		_vue.regler_etage(int(v))
		_dire_l_etage())
	ligne.add_child(_compteur_etage)
	outils.contenu.add_child(ligne)
	_etiquette_etage = _texte("", 11, Palette.GRIS)
	outils.contenu.add_child(_etiquette_etage)

	# ── 2. LA SÉLECTION — seulement quand il y a quelque chose à sélectionner ou à coller.
	var sel := Section.new("Selection", true, Icones.icone("boite"))
	pile.add_child(sel)
	_section_selection = sel
	_etiquette_selection = _texte("", 12, Palette.OLIVE)
	sel.contenu.add_child(_etiquette_selection)
	sel.contenu.add_child(_grille([
		_bouton("Fill", "Fills every selected cell with matter. Draw a Rect or a Box, then Fill it.",
			_operer_selection.bind("remplir"), "remplir", Palette.PRINCIPAL),
		_bouton("Delete", "Del — removes the selected matter.", _operer_selection.bind("supprimer"),
			"poubelle", Palette.DANGER),
		_bouton("Clear", "Esc — forgets the selection. No cell changes.", _operer_selection.bind(""),
			"croix"),
		_bouton("Extrude ↑", "Adds the layer above, the selection follows it, AND the floor plane y "
			+ "goes up with it — so you can keep drawing at the new level without touching PgUp.",
			_operer_selection.bind("extruder_haut"), "extruder_haut"),
		_bouton("Extrude ↓", "Adds the layer below, the selection follows it, and the floor plane y "
			+ "goes down with it.",
			_operer_selection.bind("extruder_bas"), "extruder_bas"),
		_bouton("Grow", "Selects the matter touching the selection by a face.",
			_operer_selection.bind("grandir"), "grandir"),
		_bouton("Shrink", "Drops the selected cells that touch an unselected one.",
			_operer_selection.bind("retrecir"), "retrecir"),
		_bouton("Connected", "Selects all the matter linked to the selection by faces.",
			_operer_selection.bind("connexe"), "connexe"),
	]))
	sel.contenu.add_child(_petit_titre("MOVE  ·  arrows, Shift + ↑ ↓"))
	var bouger: Array = []
	for m in [["X −", Vector3i(-1, 0, 0)], ["Y +", Vector3i(0, 1, 0)], ["X +", Vector3i(1, 0, 0)],
			["Z −", Vector3i(0, 0, -1)], ["Y −", Vector3i(0, -1, 0)], ["Z +", Vector3i(0, 0, 1)]]:
		bouger.append(_bouton(m[0], "Moves the selected matter one cell. It merges with the matter it "
			+ "lands on, never erases it.", _deplacer.bind(m[1])))
	sel.contenu.add_child(_grille(bouger, 3))
	sel.contenu.add_child(_petit_titre("CLIPBOARD  ·  Ctrl C X V"))
	_bouton_coller = _bouton("Paste", "Ctrl+V — the copy follows the mouse; click to place it against "
		+ "the face you point at, right click or Esc to cancel.", _coller, "coller")
	sel.contenu.add_child(_rangee([
		_bouton("Copy", "Ctrl+C — copies the selected matter. Paste it into any layer.",
			func() -> void: _copier(), "copier"),
		_bouton("Cut", "Ctrl+X — copies, then deletes.", _couper, "couper"),
		_bouton_coller,
	], 4))

	# ── 3. LES OPÉRATIONS DE FORME — repliées : on s'en sert moins que du pinceau.
	# ⚠ OUVERTE AU DÉPART, comme toute la barre de droite (Jordan, 29 septembre 2026).
	var etage := Section.new("Shape operations", true, Icones.icone("etage"))
	pile.add_child(etage)
	_etiquette_portee = _texte("", 11, Palette.GRIS)
	etage.contenu.add_child(_etiquette_portee)
	var ops: Array = []
	for op in [
		["Extend up", "haut", "extruder_haut", "copies the cells one cell higher"],
		["Extend down", "bas", "extruder_bas", "copies the cells one cell lower"],
		["Widen", "elargir", "elargir", "adds a ring around the cells, in their plane"],
		["Hollow", "creuser", "evider", "removes the cells whose four horizontal neighbours are full"],
	]:
		ops.append(_bouton(op[0], op[3] + " — the selection if there is one, otherwise floor y.",
			_operer.bind(op[1]), op[2]))
	etage.contenu.add_child(_grille(ops))
	etage.contenu.add_child(_bouton("Paint the witness shape",
		"Replaces this layer's cells with the witness's own cells (Ctrl+Z brings yours back).\n"
		+ "Sliced from your work, the result must give your block back: that is the proof that "
		+ "the round trip holds.", _peindre_la_forme_du_temoin, "cube"))
	etage.contenu.add_child(_bouton("Clear the layer", "Erases every cell of this layer (Ctrl+Z "
		+ "brings them back).", _effacer_tout, "gomme", Palette.DANGER))


func _batir_attente(parent: Control) -> void:
	_attente = PanelContainer.new()
	var s := Palette.fond(Palette.ATTENTE, 8, 18)
	s.border_color = Palette.FILET
	s.set_border_width_all(1)
	_attente.add_theme_stylebox_override("panel", s)
	_attente.set_anchors_preset(Control.PRESET_CENTER)
	_attente.custom_minimum_size = Vector2(360, 96)
	_attente.offset_left = -180
	_attente.offset_right = 180
	_attente.offset_top = -48
	_attente.offset_bottom = 48
	_attente.visible = false
	var pile := VBoxContainer.new()
	pile.add_theme_constant_override("separation", 8)
	_attente.add_child(pile)
	_attente_titre = _texte("", 15, Palette.OLIVE)
	_attente_titre.add_theme_font_override("font", Palette.gras())
	pile.add_child(_attente_titre)
	var barre := ProgressBar.new()
	barre.value = 100
	barre.show_percentage = false
	pile.add_child(barre)
	_attente_note = _texte("", 11, Palette.GRIS)
	pile.add_child(_attente_note)
	parent.add_child(_attente)


## ⚠ IL FAUT RENDRE LA MAIN À L'ÉCRAN POUR QU'IL PEIGNE, ET `process_frame` NE SUFFIT PAS (leçon de
## SoluTiles) : on reprend la main AVANT le dessin de l'image. Seul `frame_post_draw` prouve que le
## panneau est réellement à l'écran avant qu'un travail long ne bloque le fil.
func _attendre(titre: String, note: String) -> void:
	_attente_titre.text = titre
	_attente_note.text = note
	_attente.visible = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _fin_attente() -> void:
	_attente.visible = false


# ── LES ATELIERS ─────────────────────────────────────────────────────────────────────────────────────

func _aller_a(atelier: String) -> void:
	if atelier == "jeu" and _atelier != "jeu":
		var refus: String = _vue.commencer_partie()
		if refus != "":
			_dire("[color=#e0603c]%s[/color]" % refus)
			atelier = "monde"
	elif atelier != "jeu" and _atelier == "jeu":
		_vue.finir_partie()
		# Le rapport disait encore les touches du jeu : on dit où l'on revient.
		_dire("[i]Back from the Play test.[/i]")
	_atelier = atelier
	(_boutons_atelier[atelier] as Button).button_pressed = true
	_contexte()
	# Project et Witness montrent tous deux le témoin (ou le travail qu'on regarde).
	_vue.montrer({"monde": "monde", "jeu": "jeu"}.get(atelier, "temoin"))
	if atelier == "jeu":
		# ⚠ Le bouton « Play test » garde sinon le clavier, et Espace le re-cliquerait au lieu de sauter.
		get_viewport().gui_release_focus()
		_vue.grab_focus()
		_dire("[b]Play test[/b] — Z Q S D to move, Space to jump, Shift to run, right drag to turn. "
			+ "Esc to go back.")
	_selection_changee()
	_dire_l_etage()


## CE QUE L'ÉCRAN MONTRE, SELON L'ATELIER — la passe de Jordan (29 septembre 2026) : « certaines sections
## s'affichent alors qu'elles ne le devraient pas vu le contexte ».
##
## **L'ATELIER PROJECT — DÉCIDÉ PAR JORDAN (29 septembre 2026)** : il est le SEUL à montrer
## l'enregistrement et l'aller-retour. Ailleurs, on travaille ; ici, on range et on échange.
##
##                      Project  Witness   World   Play test
##   Save · open           ✓
##   Round trip 1 → 4      ✓                          (3 et 4 visent la couche ACTIVE, choisie dans World)
##   Layers                                  ✓
##   Play test                                         ✓
##   Witness (réf.)        ✓        ✓                  (sa légende nomme les teintes du TÉMOIN)
##   Shortcuts (réf.)                        ✓         (ce ne sont que des gestes de peinture)
##   barre de droite                         ✓         (elle ne porte que des outils de peinture)
##
## ⚠ LA BARRE DE DROITE ÉTAIT UN CADRE VIDE DANS LE TÉMOIN : ses sections se cachaient, le panneau
## restait, et mangeait un quart de la vue sur le bloc qu'on veut justement regarder.
func _contexte() -> void:
	var projet := _atelier == "projet"
	var temoin := _atelier == "witness"
	var monde := _atelier == "monde"
	var jeu := _atelier == "jeu"
	_section_jeu.visible = jeu
	_titre_projet.visible = projet
	_section_projet.visible = projet
	_section_couches.visible = monde
	_titre_aller_retour.visible = projet
	for e in _etapes_artiste:
		e.visible = projet
	for e in _etapes_monde:
		e.visible = projet
	_section_temoin.visible = temoin or projet
	_section_raccourcis.visible = monde
	_zone_reference.visible = temoin or monde or projet
	_droite.visible = monde
	_contexte_des_outils()


## DANS LA BARRE D'OUTILS : ce qui ne s'applique pas à l'outil choisi disparaît. Le pinceau (taille,
## forme) ne sert ni au Rect ni à la Box, qui se tracent coin à coin ; « Hollow » ne sert qu'à la Box.
func _contexte_des_outils() -> void:
	if _creux == null:
		return
	var pinceau: bool = _vue.outil in ["ajouter", "creuser", "selectionner"]
	_titre_pinceau.visible = pinceau
	_ligne_taille.visible = pinceau
	_ligne_forme.visible = pinceau
	_creux.visible = _vue.outil == "boite"


# ── LE TÉMOIN ET LE TRAVAIL ──────────────────────────────────────────────────────────────────────────

func _montrer_temoin() -> void:
	_vue.montrer_maillage(BM.maillage_moitie(0), null)


## ⚠ **LE CHEMIN ET LE MAILLAGE SE LISENT DANS LA LISTE, ILS NE SONT PLUS GARDÉS À CÔTÉ.** Deux copies
## d'un même fait divergent (charte §6) : c'est la liste qui fait autorité, et − 1 veut dire « aucun ».
func _travail_chemin() -> String:
	if _travail_actif < 0 or _travail_actif >= _travaux.size():
		return ""
	return String(_travaux[_travail_actif]["chemin"])


func _travail_maillage() -> ArrayMesh:
	if _travail_actif < 0 or _travail_actif >= _travaux.size():
		return null
	return _travaux[_travail_actif]["maillage"] as ArrayMesh


func _travail_vu(oui: bool) -> void:
	var maillage := _travail_maillage()
	if oui and maillage != null:
		_vue.montrer_maillage(maillage, null)
		_etiquette_vue.text = "showing: your work — %s" % _travail_chemin().get_file()
		_bouton_revoir_temoin.visible = true
	else:
		_montrer_temoin()
		_etiquette_vue.text = "showing: the computed witness"
		_bouton_revoir_temoin.visible = false
	# ⚠ ON RESTE DANS PROJECT : c'est là qu'on importe, et la liste des travaux n'existe que là.
	_aller_a(_atelier if _atelier in ["projet", "witness"] else "projet")


## LA GRILLE DES TRAVAUX — un bouton par import, celui qu'on tranchera est enfoncé.
func _redire_les_travaux() -> void:
	if _liste_travaux == null:
		return
	for enfant in _liste_travaux.get_children():
		enfant.queue_free()
		_liste_travaux.remove_child(enfant)
	var groupe := ButtonGroup.new()
	for i in _travaux.size():
		var t: Dictionary = _travaux[i]
		var b := Button.new()
		b.text = String(t["chemin"]).get_file()
		b.icon = Icones.icone("cube")
		b.toggle_mode = true
		b.button_group = groupe
		b.button_pressed = i == _travail_actif
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.add_theme_constant_override("icon_max_width", 16)
		b.tooltip_text = "%s\nClick to show it; « Slice the selected work » slices THIS one." % t["chemin"]
		b.pressed.connect(_choisir_travail.bind(i))
		_liste_travaux.add_child(b)
	_vide_travaux.visible = _travaux.is_empty()
	# ⚠ Rien à trancher tant que rien n'est importé : le bouton le DIT plutôt que de répondre après coup.
	_bouton_trancher_travail.disabled = _travaux.is_empty()
	_bouton_trancher_travail.tooltip_text = ("Import a work first (step 2)." if _travaux.is_empty() else
		"Re-reads the work you picked above, slices it, and dresses the ACTIVE layer with YOUR tiles.\n"
		+ "Its painted cells stay as they are.")
	_dire_la_cible()


func _choisir_travail(i: int) -> void:
	_travail_actif = i
	_travail_vu(true)
	_redire_les_travaux()


## Ce que l'étape 3 tranchera, et où ça ira — écrit, parce que les deux se choisissent ailleurs.
func _dire_la_cible() -> void:
	if _etiquette_cible == null:
		return
	var quoi := _travail_chemin().get_file() if _travail_chemin() != "" else "no work selected"
	var ou := "no layer"
	if _active >= 0 and _active < _couches.size():
		ou = String(_couches[_active].get("nom", "layer"))
	_etiquette_cible.text = "%s  →  %s" % [quoi, ou]


func _demander(quoi: String) -> void:
	_action_fichier = quoi
	var ecrire: bool = quoi in ["exporter", "enregistrer"]
	_dialogue.file_mode = FileDialog.FILE_MODE_SAVE_FILE if ecrire else FileDialog.FILE_MODE_OPEN_FILE
	_dialogue.clear_filters()
	if quoi == "tileset":
		_dialogue.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_dialogue.title = "Export the tileset into…"
		_dialogue.current_file = ""
	elif quoi in ["ouvrir", "enregistrer"]:
		_dialogue.add_filter("*." + Projet.EXTENSION, "MarchingBlocks project")
		_dialogue.title = "Open a project" if quoi == "ouvrir" else "Save the project as"
		_dialogue.current_file = _projet.get_file() if quoi == "enregistrer" else ""
	else:
		# ⚠ LE TÉMOIN PART EN .obj (soudé), LE TRAVAIL REVIENT EN .glb — ou en .obj (charte §4).
		if quoi == "exporter":
			_dialogue.add_filter("*.obj", "Wavefront OBJ")
		else:
			_dialogue.add_filter("*.glb, *.obj", "Sculpted work")
		_dialogue.title = "Export the witness" if quoi == "exporter" else "Import the work"
		_dialogue.current_file = "marchingblocks_witness.obj" if quoi == "exporter" else ""
	_dialogue.popup_centered_ratio(0.6)


func _fichier_choisi(fichier: String) -> void:
	match _action_fichier:
		"exporter":
			_exporter(fichier)
		"importer":
			_importer(fichier)
		"ouvrir":
			_ouvrir(fichier)
		"enregistrer":
			_enregistrer_sous(fichier)
		"tileset":
			_exporter_le_jeu(fichier)


## ⚠ IL REFUSE si le témoin est en faute : sculpter des jours sur une base fausse coûte bien plus qu'un
## refus.
func _exporter(fichier: String) -> void:
	var fautes: Array = BM.anomalies()
	if not fautes.is_empty():
		_dire("[color=#e0603c]REFUSED — %d problem(s) in the witness:[/color]\n  %s"
			% [fautes.size(), "\n  ".join(PackedStringArray(fautes.slice(0, 6)))])
		return
	await _attendre("Exporting the witness", fichier.get_file())
	var raison: String = BM.exporter_le_bloc(fichier)
	_fin_attente()
	if raison != "":
		_dire("[color=#e0603c]Export failed:[/color] %s" % raison)
		return
	var total: int = MB.pieces_a_sculpter().size()
	var dehors: int = MB.exterieures_a_sculpter().size()
	_dire(("[color=#b4bd85][b]Witness written[/b][/color] → %s\n"
		+ "One block of %d × %d × %d · %d tiles to sculpt: %d classes underground, %d also in open air.\n"
		+ "Tiles already shrunk to HALF their cell. No normals: Blender opens it FLAT-shaded, welded.\n\n"
		+ "[color=#f2ca79]Do not MOVE the block[/color] — its POSITION identifies it when it comes back.\n"
		+ "Relief may spill half a cell around the block; beyond that it is lost.\n"
		+ "Do not change WHICH cells are full: the filling fixes the tile classes.")
		% [fichier, BM.COTE, BM.COTE, BM.COTE, total + dehors, total, dehors])


## On AFFICHE le travail, tel que le trancheur le lira — rien n'est tranché.
func _importer(fichier: String) -> void:
	var journal: Array = []
	await _attendre("Reading your work", fichier.get_file())
	var travail: ArrayMesh = BM.travail_depuis_glb(fichier, journal)
	_fin_attente()
	if travail == null:
		var motif: String = "\n  ".join(PackedStringArray(journal)) if not journal.is_empty() \
			else "no geometry inside the block's box — was the block moved?"
		_dire("[color=#e0603c]Nothing to show from[/color] %s\n  %s" % [fichier, motif])
		return
	# ⚠ **RÉIMPORTER LE MÊME FICHIER LE REMPLACE, IL NE LE DOUBLE PAS.** C'est le geste le plus
	# fréquent — on resculpte dans Blender, on réimporte — et une liste qui grossit à chaque
	# enregistrement deviendrait illisible en dix minutes.
	var deja := -1
	for i in _travaux.size():
		if String(_travaux[i]["chemin"]) == fichier:
			deja = i
	if deja >= 0:
		_travaux[deja]["maillage"] = travail
		_travail_actif = deja
	else:
		_travaux.append({"chemin": fichier, "maillage": travail})
		_travail_actif = _travaux.size() - 1
	_redire_les_travaux()
	_travail_vu(true)
	var ecart: int = BM.ecart_au_temoin(travail)
	var ecart_dit: String = ("[color=#f2ca79]No vertex moved compared to the witness: slicing will give "
		+ "the witness tiles back.[/color]") if ecart == 0 \
		else "%d new vertex position(s) compared to the witness." % ecart
	_dire(("[color=#b4bd85][b]Work imported[/b][/color] ← %s\n%s\n\nThe view shows it as the slicer "
		+ "will read it: whatever leaves the block's box is gone.\n[i]« Slice the work » re-reads the "
		+ "file when clicked — saving again in Blender meanwhile is enough.[/i]") % [fichier, ecart_dit])


# ── TRANCHER ─────────────────────────────────────────────────────────────────────────────────────────

## ⚠ ON TRANCHE DANS LA COUCHE ACTIVE, ET SES CASES NE BOUGENT PAS (Jordan, 27 septembre 2026) : le
## monde peint est indépendant du travail qui l'habille. Retrancher, c'est changer de tuiles.
func _trancher_temoin() -> void:
	if _vue.monde() == null:
		return
	var bilan: Dictionary = await _trancher_source(Projet.TEMOIN)
	_poser_lot(bilan, "witness", Projet.TEMOIN)


func _trancher_travail() -> void:
	if _vue.monde() == null:
		return
	var chemin := _travail_chemin()
	if chemin == "":
		_dire("No work selected.\n\n[i]Step 2: « Import the work… », then pick one in the list. "
			+ "You slice what you have seen.[/i]")
		return
	var bilan: Dictionary = await _trancher_source(chemin)
	var entete := "[b]Sliced from[/b] %s\n" % chemin
	var absents: Array = bilan.get("absents", [])
	if not absents.is_empty():
		entete += "[color=#f2ca79]Block MISSING from the file, computed witness kept.[/color]\n"
	_poser_lot(bilan, "work", chemin, entete)


## Tranche une source et met le lot en cache. ⚠ UNE SEULE ROUTE pour le bouton et pour la réouverture
## d'un projet dont la source a changé : deux routes finiraient par trancher différemment.
func _trancher_source(source: String) -> Dictionary:
	var bilan: Dictionary
	if source == Projet.TEMOIN:
		await _attendre("Slicing the witness", "52 tiles, every sculpted copy kept")
		bilan = BM.librairie()
	else:
		await _attendre("Slicing your work", source.get_file())
		bilan = BM.librairie_depuis_glb(source)
	_fin_attente()
	var lot: MeshLibrary = bilan.get("lot", null)
	if lot != null and BM.anomalies().is_empty():
		bilan["cache"] = Projet.mettre_en_cache(lot, source)
	return bilan


## Habille la couche active du lot, et DIT tout ce que le bilan contient.
func _poser_lot(bilan: Dictionary, quoi: String, source: String, entete := "") -> void:
	var fautes: Array = BM.anomalies()
	if not fautes.is_empty():
		_dire("[color=#e0603c]REFUSED — %d problem(s) in the witness:[/color]\n  %s"
			% [fautes.size(), "\n  ".join(PackedStringArray(fautes.slice(0, 6)))])
		return
	var lot: MeshLibrary = bilan["lot"]
	_vue.monde().lot = lot
	_couches[_active]["source"] = source
	_rafraichir_couches()
	_enregistrer()
	_aller_a("monde")

	var en_plus: int = int(bilan.get("exemplaires_en_plus", 0))
	var texte := entete
	texte += "[color=#b4bd85][b]Library ready[/b][/color] (%s → layer « %s ») — %d tile(s) for %d classes" \
		% [quoi, _couches[_active]["nom"], lot.get_item_list().size() - en_plus,
		MB.pieces_a_sculpter().size()]
	if en_plus > 0:
		texte += ", + %d sculpted copy(ies)" % en_plus
	texte += "\n"
	var manquantes: Array = bilan.get("manquantes", [])
	if not manquantes.is_empty():
		texte += "\n[color=#e0603c]%d class(es) MISSING — red cubes guaranteed:[/color] %s\n" \
			% [manquantes.size(), ", ".join(PackedStringArray(manquantes.slice(0, 8)))]
	var erreurs: Array = bilan.get("erreurs", [])
	if not erreurs.is_empty():
		texte += "\n[color=#e0603c]%d slicing error(s):[/color]\n  %s\n" \
			% [erreurs.size(), "\n  ".join(PackedStringArray(erreurs.slice(0, 5)))]
	var remarques: Array = bilan.get("remarques", [])
	if not remarques.is_empty():
		texte += ("\n[color=#c8a13a]%d seam remark(s)[/color] — two tiles of the same seed do not carry "
			+ "the same matter at their cutting plane. Nothing is blocked, but that is what makes "
			+ "cracks between neighbours:\n  %s\n") \
			% [remarques.size(), "\n  ".join(PackedStringArray(remarques.slice(0, 4)))]
	if manquantes.is_empty() and erreurs.is_empty():
		texte += "[i]No missing class, no slicing error.[/i]\n"
	if str(bilan.get("cache", "")) != "":
		texte += "\n[color=#f2ca79]%s[/color] — the layer will be sliced again next time.\n" % bilan["cache"]
	texte += "\n[i]Pick a tool on the right: left click applies it, right click does the opposite.[/i]"
	_dire(texte)


# ── PEINDRE ──────────────────────────────────────────────────────────────────────────────────────────

func _id_case() -> int:
	var cases: GridMap = _vue.cases()
	if cases == null or cases.mesh_library == null:
		return -1
	return cases.mesh_library.find_item_by_name("case")


func _coup_commence() -> void:
	_coup = {}
	_coup_nom = ""


## Un morceau de coup : les cases sont posées TOUT DE SUITE, pour qu'on voie ce qu'on peint.
func _touche(modif: Dictionary, nom: String) -> void:
	var cases: GridMap = _vue.cases()
	var id: int = _id_case()
	if id < 0:
		return
	_coup_nom = nom if _coup_nom == "" or _coup_nom == nom else "Stroke"
	var changements := _changements(modif, cases, id)
	for c in changements:
		if not _coup.has(c):
			_coup[c] = changements[c].duplicate()
		else:
			_coup[c][1] = changements[c][1]
		cases.set_cell_item(c, changements[c][1])
	_vue.monde().reconstruire()
	_vue.rafraichir()


## ⚠ UN COUP ENTIER S'ANNULE D'UN SEUL Ctrl+Z — c'est ce qu'on attend d'un pinceau. Les cases sont déjà
## posées pendant le glissé ; l'action est donc enregistrée SANS être rejouée.
func _coup_fini() -> void:
	var fait := {}
	for c in _coup:
		if _coup[c][0] != _coup[c][1]:
			fait[c] = _coup[c]
	_coup = {}
	if not fait.is_empty():
		_enregistrer_action(fait, _coup_nom if _coup_nom != "" else "Stroke", true)
	_dire_l_etage()


## {case: [avant, après]} pour une modification {poser, effacer} sur cette grille. Rien pour ce qui ne
## change pas.
func _changements(modif: Dictionary, cases: GridMap, id: int) -> Dictionary:
	var ch := {}
	for c in modif.get("effacer", {}):
		var avant: int = cases.get_cell_item(c)
		if avant != -1:
			ch[c] = [avant, -1]
	for c in modif.get("poser", {}):
		var avant: int = cases.get_cell_item(c)
		if avant != id:
			ch[c] = [avant, id]
	return ch


## ⚠ LA SEULE ENTRÉE DE TOUT CE QUI CHANGE DES CASES (plan de la barre d'outils) : pinceau, opérations
## d'étage et de sélection, remplacement du monde. Elles passaient par trois routes, qui écrivaient
## chacune leur annulation — une seconde description d'un même fait diverge toujours (charte §6).
## Rend le nombre de cases changées.
func _appliquer(modif: Dictionary, nom: String) -> int:
	var cases: GridMap = _vue.cases()
	var id: int = _id_case()
	if id < 0:
		return 0
	var ch := _changements(modif, cases, id)
	if not ch.is_empty():
		_enregistrer_action(ch, nom, false)
	return ch.size()


## ⚠ L'ACTION NOMME SA GRILLE ET SON MASSIF, jamais « la couche active » : un Ctrl+Z après avoir changé
## de couche doit reconstruire la couche qu'il touche, pas celle qu'on regarde.
func _enregistrer_action(ch: Dictionary, nom: String, deja_fait: bool) -> void:
	var cases: GridMap = _vue.cases()
	var massif: Node = _vue.monde()
	_histoire.create_action(nom)
	for c in ch:
		_histoire.add_do_method(cases.set_cell_item.bind(c, ch[c][1]))
		_histoire.add_undo_method(cases.set_cell_item.bind(c, ch[c][0]))
	_histoire.add_do_method(_reconstruire.bind(massif))
	_histoire.add_undo_method(_reconstruire.bind(massif))
	_histoire.commit_action(not deja_fait)


func _reconstruire(massif: Node) -> void:
	massif.reconstruire()
	_vue.rafraichir()
	_dire_l_etage()


func _occupees() -> Dictionary:
	var occupees := {}
	var cases: GridMap = _vue.cases()
	if cases != null:
		for c in cases.get_used_cells():
			occupees[c] = true
	return occupees


## Remplace toutes les cases de la couche, en UNE action annulable.
func _remplacer_le_monde(nouvelles: Dictionary, nom: String) -> void:
	var effacer := {}
	for c in _occupees():
		if not nouvelles.has(c):
			effacer[c] = true
	_appliquer({"poser": nouvelles, "effacer": effacer}, nom)


func _effacer_tout() -> void:
	_remplacer_le_monde({}, "Clear the layer")


func _peindre_la_forme_du_temoin() -> void:
	_remplacer_le_monde(BM.cases(0), "Paint the witness shape")
	_aller_a("monde")


## LES OPÉRATIONS D'ÉTAGE — la règle vit dans `etages.gd`, partagée avec le greffon. Elles portent sur
## la SÉLECTION s'il y en a une, sinon sur l'étage : la même opération, sur un autre ensemble.
func _operer(quoi: String) -> void:
	var sur: String = ("the selection (%d cells)" % _vue.selection.size()) if not _vue.selection.is_empty() \
		else "floor y = %d" % _vue.etage
	var n := _appliquer(Etages.operer(_occupees(), _vue.etage, quoi, _vue.selection), quoi)
	if n == 0:
		_dire("[i]Nothing to do on %s.[/i] It is empty, or the operation found nothing to change." % sur)
		return
	_dire("[b]%s[/b] on %s — %d cell(s) changed. [i]Ctrl+Z undoes it.[/i]" % [quoi, sur, n])


func _operer_selection(quoi: String) -> void:
	if quoi == "":
		_vue.vider_selection()
		return
	if _vue.selection.is_empty():
		_dire("[i]Nothing selected.[/i] Drag a Rect (R) on the floor, a Box (B) in the air, or paint "
			+ "over the matter with Select (S).")
		return
	var op: Dictionary = Outils.operer_selection(_occupees(), _vue.selection, quoi)
	var n := _appliquer(op, quoi)
	_vue.regler_selection(op["selection"])
	# ⚠ **L'ÉTAGE SUIT L'EXTRUSION — DEMANDÉ PAR JORDAN (28 septembre 2026).** Extruder puis continuer
	# à dessiner obligeait à monter l'étage à la main (PgUp) : deux gestes pour un, et un rectangle
	# tracé au mauvais niveau sans qu'on le voie venir. Le plan de visée accompagne désormais la
	# sélection, donc le geste se répète tout seul : Fill, Extrude, Fill, Extrude.
	if quoi == "extruder_haut" or quoi == "extruder_bas":
		_compteur_etage.value = _vue.etage + (1 if quoi == "extruder_haut" else -1)
	_dire("[b]%s[/b] — %d cell(s) changed, %d selected. [i]Ctrl+Z undoes the cells.[/i]"
		% [quoi, n, _vue.selection.size()])


func _deplacer(decalage: Vector3i) -> void:
	if _vue.selection.is_empty():
		_dire("[i]Nothing selected to move.[/i]")
		return
	var op: Dictionary = Outils.deplacer(_occupees(), _vue.selection, decalage)
	_appliquer(op, "Move")
	_vue.regler_selection(op["selection"])


## ⚠ LES FLÈCHES SUIVENT LA CAMÉRA : « haut » éloigne de soi, quel que soit le côté d'où l'on regarde.
## On arrondit à l'axe dominant — un déplacement en diagonale n'existe pas sur une grille.
func _deplacer_a_l_ecran(ecran: Vector2i) -> void:
	var base: Basis = _vue._camera.global_transform.basis
	var devant := _axe_horizontal(-base.z)
	var droite := _axe_horizontal(base.x)
	_deplacer(droite * ecran.x + devant * -ecran.y)


static func _axe_horizontal(v: Vector3) -> Vector3i:
	if absf(v.x) >= absf(v.z):
		return Vector3i(int(signf(v.x)), 0, 0)
	return Vector3i(0, 0, int(signf(v.z)))


## L'EXPORT DU JEU DE TUILES de la couche active, au format neutre (`format_neutre.gd`).
## ⚠ UNE COUCHE SANS TUILES EST REFUSÉE, et on le dit : exporter le repli procédural livrerait des
## tuiles que personne n'a sculptées, sous le nom de l'artiste.
func _exporter_le_jeu(dossier: String) -> void:
	var massif: Node = _vue.monde()
	if massif == null or _couches[_active]["source"] == "" or massif.lot == null:
		_dire("[color=#e0603c]Nothing to export.[/color] This layer has no tiles yet — slice the witness "
			+ "or your work into it first.")
		return
	await _attendre("Exporting the tileset", _couches[_active]["nom"])
	var version := "MarchingBlocks %s" % ProjectSettings.get_setting("application/config/version", "")
	var r: Dictionary = FormatNeutre.exporter(massif.lot, dossier, _couches[_active]["nom"], version)
	_fin_attente()
	if r.has("erreur"):
		_dire("[color=#e0603c]Export failed:[/color] %s" % r["erreur"])
		return
	var texte := ("[color=#b4bd85][b]Tileset written[/b][/color] → %s\n%d tile(s) for %d keys. Open it with "
		+ "the free MarchingBlocks Paint plugin for your engine.") % [r["dossier"], r["tuiles"], r["cles"]]
	if not (r["manquantes"] as Array).is_empty():
		texte += ("\n\n[color=#f2ca79]%d tile(s) of the world are missing[/color] — the engine will show red "
			+ "cubes there: %s") % [(r["manquantes"] as Array).size(),
			", ".join(PackedStringArray((r["manquantes"] as Array).slice(0, 8)))]
	_dire(texte)


func _copier() -> bool:
	var pp: Array = Outils.copier(_occupees(), _vue.selection)
	if pp.is_empty():
		_dire("[i]Nothing selected to copy.[/i] Select some matter first (S or B).")
		return false
	_presse_papiers = pp
	_selection_changee()
	_dire("[b]Copied[/b] — %d cell(s). [i]Ctrl+V pastes, into this layer or any other.[/i]" % pp.size())
	return true


func _couper() -> void:
	if _copier():
		var op: Dictionary = Outils.operer_selection(_occupees(), _vue.selection, "supprimer")
		_appliquer(op, "Cut")
		_vue.regler_selection(op["selection"])
		_dire("[b]Cut[/b] — %d cell(s). [i]Ctrl+V pastes them back, anywhere.[/i]" % _presse_papiers.size())


func _coller() -> void:
	if _presse_papiers.is_empty():
		_dire("[i]Nothing to paste.[/i] Copy a selection first (Ctrl+C).")
		return
	_aller_a("monde")
	_vue.commencer_collage(_presse_papiers)
	_dire(("[b]Pasting[/b] %d cell(s) — click to place against the face you point at. [i]Right click or "
		+ "Esc cancels.[/i]") % _presse_papiers.size())


func _colle(ancre: Vector3i) -> void:
	var op: Dictionary = Outils.coller(_occupees(), _presse_papiers, ancre)
	var n := _appliquer(op, "Paste")
	_vue.regler_selection(op["selection"])
	_dire(("[b]Pasted[/b] — %d cell(s) added, the rest merged with the matter there. [i]Ctrl+Z undoes "
		+ "it.[/i]") % n)


# ── LA BARRE D'OUTILS ────────────────────────────────────────────────────────────────────────────────

## Une rangée de boutons exclusifs. `choix` : [clé, libellé, icône, infobulle]. Avec la variante OUTIL,
## l'icône est AU-DESSUS du nom : de grands boutons carrés qu'on trouve sans lire.
func _rangee_de_choix(boutons: Dictionary, choix: Array, action: Callable, variante := "") -> Control:
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 5)
	var groupe := ButtonGroup.new()
	for c in choix:
		var b := Button.new()
		b.text = c[1]
		b.icon = Icones.icone(c[2])
		b.tooltip_text = c[3]
		b.toggle_mode = true
		b.button_group = groupe
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 34)
		if variante != "":
			b.theme_type_variation = variante
		if variante == Palette.OUTIL:
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.custom_minimum_size = Vector2(0, 58)
		b.pressed.connect(action.bind(c[0]))
		ligne.add_child(b)
		boutons[c[0]] = b
	(boutons[choix[0][0]] as Button).button_pressed = true
	return ligne


func _choisir_forme(f: String) -> void:
	_vue.forme = f
	(_boutons_forme[f] as Button).button_pressed = true
	_vue.rafraichir()


## ⚠ CHOISIR UNE VISÉE SORT DE LA NAVIGATION : on clique Grid ou Sculpt pour viser, pas pour voler.
func _choisir_visee(v: String) -> void:
	_vue.visee = v
	(_boutons_visee[v] as Button).button_pressed = true
	_basculer_navigation(false)
	_vue.rafraichir()


func _choisir_outil(o: String) -> void:
	_vue.outil = o
	(_boutons_outil[o] as Button).button_pressed = true
	_contexte_des_outils()
	_vue.rafraichir()


func _basculer_navigation(oui: bool) -> void:
	if _vue.naviguer == oui:
		return
	_vue.naviguer = oui
	_bouton_naviguer.set_pressed_no_signal(oui)
	_vue.rafraichir()
	_dire("[b]Navigate[/b] — A Z E Q S D to fly, right drag to look. [i]Space to paint again.[/i]" if oui
		else "[i]Back to painting (%s).[/i]" % ("Grid" if _vue.visee == "grille" else "Sculpt"))


func _selection_changee() -> void:
	if _section_selection == null:
		return
	var n: int = _vue.selection.size()
	# ⚠ VISIBLE AUSSI QUAND SEUL LE PRESSE-PAPIERS EST PLEIN : on colle souvent sans rien sélectionner.
	_section_selection.visible = _atelier == "monde" and (n > 0 or not _presse_papiers.is_empty())
	_etiquette_selection.text = ("%d cell(s) selected" % n) if n > 0 else "nothing selected"
	_bouton_coller.disabled = _presse_papiers.is_empty()
	_etiquette_portee.text = ("acts on the selection (%d cells)" % n) if n > 0 \
		else "acts on floor y = %d" % _vue.etage


func _dire_l_etage() -> void:
	if _etiquette_etage == null or _vue == null or _vue.cases() == null:
		return
	var combien := 0
	var bas := 1 << 20
	var haut := -(1 << 20)
	for c in _vue.cases().get_used_cells():
		var p: Vector3i = c
		if p.y == _vue.etage:
			combien += 1
		bas = mini(bas, p.y)
		haut = maxi(haut, p.y)
	_etiquette_etage.text = ("%d cell(s) here · painted from y=%d to y=%d" % [combien, bas, haut]) \
		if bas <= haut else "nothing painted yet"
	_selection_changee()


# ── LES COUCHES ──────────────────────────────────────────────────────────────────────────────────────

## Une couche neuve au bout de la pile, sans source ni case. Rend son indice.
func _ajouter_couche(etat: Dictionary) -> int:
	var massif: Node = _vue.ajouter_couche()
	massif.visible = etat["visible"]
	_couches.append({"nom": etat["nom"], "source": etat["source"],
		"visible": etat["visible"]})
	return _couches.size() - 1


func _activer(i: int) -> void:
	_active = clampi(i, 0, _couches.size() - 1)
	_vue.activer(_active)
	_rafraichir_couches()
	_dire_l_etage()
	_enregistrer()


func _nouvelle_couche() -> void:
	_activer(_ajouter_couche(Projet.couche("Layer %d" % (_couches.size() + 1))))
	_aller_a("monde")
	_dire("[b]New layer[/b] — empty, and the one you paint on now.\n[i]Slice the witness or your "
		+ "work into it to give it tiles.[/i]")


## ⚠ SUPPRIMER S'ANNULE, COMME TOUT LE RESTE (charte §5) : la couche est DÉTACHÉE, pas détruite — ses
## cases sont dans sa grille, et l'historique garde des appels sur cette grille. La détruire rendrait
## chaque Ctrl+Z antérieur fatal.
func _supprimer_couche() -> void:
	if _couches.size() <= 1:
		_dire("[i]A project keeps at least one layer.[/i] Clear it instead.")
		return
	var massif: Node = _vue.monde()
	var etat: Dictionary = _couches[_active]
	_histoire.create_action("Delete layer « %s »" % etat["nom"])
	_histoire.add_do_method(_detacher_couche.bind(massif))
	_histoire.add_undo_method(_rattacher_couche.bind(massif, etat, _active))
	_histoire.commit_action()


func _detacher_couche(massif: Node) -> void:
	var i: int = massif.get_index()
	_vue.detacher_couche(massif)
	_couches.remove_at(i)
	_detachees.append(massif)
	_activer(mini(i, _couches.size() - 1))


func _rattacher_couche(massif: Node, etat: Dictionary, i: int) -> void:
	_detachees.erase(massif)
	_vue.inserer_couche(massif, i)
	_couches.insert(i, etat)
	_activer(i)


func _renommer_couche() -> void:
	var nom := _nom_couche.text.strip_edges()
	if _couches.is_empty() or nom == "" or nom == _couches[_active]["nom"]:
		return
	_couches[_active]["nom"] = nom
	_rafraichir_couches()
	_enregistrer()


func _montrer_couche(i: int, oui: bool) -> void:
	_couches[i]["visible"] = oui
	_vue.couche(i).visible = oui
	_enregistrer()


## Une ligne par couche : l'œil (montrer / cacher), puis la couche elle-même, qu'on choisit d'un clic.
## La couche ACTIVE se voit à son fond olive — c'est elle que le pinceau touche.
func _rafraichir_couches() -> void:
	if _liste_couches == null:
		return
	# ⚠ Un projet garde au moins une couche : le bouton se grise au lieu de refuser après le clic.
	_bouton_supprimer_couche.disabled = _couches.size() <= 1
	for enfant in _liste_couches.get_children():
		_liste_couches.remove_child(enfant)
		enfant.queue_free()
	var groupe := ButtonGroup.new()
	for i in _couches.size():
		var c: Dictionary = _couches[i]
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 4)
		var oeil := Button.new()
		oeil.theme_type_variation = Palette.DISCRET
		oeil.toggle_mode = true
		oeil.button_pressed = c["visible"]
		oeil.icon = Icones.icone("oeil" if c["visible"] else "oeil_ferme")
		oeil.tooltip_text = "Show or hide this layer"
		oeil.focus_mode = Control.FOCUS_NONE
		oeil.toggled.connect(func(v: bool) -> void:
			oeil.icon = Icones.icone("oeil" if v else "oeil_ferme")
			_montrer_couche(i, v))
		ligne.add_child(oeil)
		var choix := Button.new()
		choix.toggle_mode = true
		choix.button_group = groupe
		choix.button_pressed = i == _active
		choix.focus_mode = Control.FOCUS_NONE
		choix.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choix.clip_text = true
		choix.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choix.custom_minimum_size = Vector2(0, 40)
		choix.text = "%s\n%s" % [c["nom"], _dire_la_source(c)]
		choix.add_theme_font_size_override("font_size", 12)
		choix.tooltip_text = "Paint on this layer.\nTiles: %s" % (c["source"] if c["source"] != "" else "none yet")
		choix.pressed.connect(_activer.bind(i))
		ligne.add_child(choix)
		_liste_couches.add_child(ligne)
	if _nom_couche != null and not _couches.is_empty():
		_nom_couche.text = _couches[_active]["nom"]
	_dire_la_cible()


func _dire_la_source(c: Dictionary) -> String:
	match c["source"]:
		"":
			return "no tiles yet"
		Projet.TEMOIN:
			return "computed witness"
	return str(c["source"]).get_file()


# ── LE PROJET ────────────────────────────────────────────────────────────────────────────────────────

## ⚠ UN PROJET QUI NE S'OUVRE PAS N'EST JAMAIS ÉCRASÉ : on en commence un autre, à côté. L'enregistrement
## automatique réécrirait sinon, au premier coup de pinceau, le seul exemplaire d'un monde abîmé.
func _ouvrir_au_lancement() -> void:
	var reglages := ConfigFile.new()
	reglages.load(REGLAGES)
	var dernier: String = reglages.get_value("projet", "dernier", "")
	if dernier != "" and FileAccess.file_exists(dernier) and await _ouvrir(dernier):
		return
	_nouveau_projet()


func _nouveau_projet() -> void:
	_vider_le_projet()
	_projet = _chemin_libre()
	_ajouter_couche(Projet.couche("Layer 1"))
	_activer(0)
	_retenir_le_projet()
	_enregistrer()


## Un nom de projet libre dans les données de l'appli : `untitled.mbproj`, puis `untitled 2`…
func _chemin_libre() -> String:
	var n := 1
	while true:
		var chemin := "user://untitled%s.%s" % ["" if n == 1 else " %d" % n, Projet.EXTENSION]
		if not FileAccess.file_exists(chemin):
			return chemin
		n += 1
	return ""


func _vider_le_projet() -> void:
	_histoire.clear_history()
	for m in _detachees:
		m.free()
	_detachees.clear()
	_vue.vider_couches()
	_couches.clear()
	_active = 0


## Rend vrai si le projet est ouvert. ⚠ Chaque couche est habillée de son lot EN CACHE s'il est à jour,
## sinon RETRANCHÉE depuis sa source : c'est ce qui suit un `.glb` réenregistré dans Blender entre deux
## sessions.
func _ouvrir(chemin: String) -> bool:
	var erreurs: Array = []
	var etat: Dictionary = Projet.depuis_texte(FileAccess.get_file_as_string(chemin), erreurs)
	if etat.is_empty():
		_dire("[color=#e0603c]Cannot open[/color] %s\n  %s" % [chemin, "\n  ".join(PackedStringArray(erreurs))])
		return false
	_ouverture = true
	_vider_le_projet()
	_projet = chemin
	var notes: Array = []
	for c in etat["couches"]:
		var i := _ajouter_couche(c)
		_vue.activer(i)
		var cases: GridMap = _vue.cases()
		var id: int = _id_case()
		for p in c["cases"]:
			cases.set_cell_item(p, id)
		var note: String = await _habiller_couche(i)
		if note != "":
			notes.append(note)
	_ouverture = false
	_activer(etat["active"])
	_retenir_le_projet()
	_aller_a("monde")
	_dire("[color=#b4bd85][b]Project opened[/b][/color] ← %s\n%d layer(s).%s" % [chemin, _couches.size(),
		"" if notes.is_empty() else "\n\n" + "\n".join(PackedStringArray(notes))])
	return true


## Pose le lot d'une couche relue. Rend une ligne de rapport, vide si tout va bien.
## ⚠ UNE SOURCE ABSENTE SE VOIT (charte §3) : l'ancien lot s'il en reste un, en le DISANT ; sinon un lot
## vide, donc des cubes rouges partout — jamais le repli procédural, qui ferait croire la couche saine.
func _habiller_couche(i: int) -> String:
	var c: Dictionary = _couches[i]
	var massif: Node = _vue.couche(i)
	if c["source"] == "":
		return ""
	var cache: Dictionary = Projet.lire_cache(c["source"])
	if cache["a_jour"]:
		massif.lot = cache["lot"]
		return ""
	var presente: bool = c["source"] == Projet.TEMOIN or FileAccess.file_exists(c["source"])
	if presente:
		var bilan: Dictionary = await _trancher_source(c["source"])
		if bilan.get("lot", null) != null:
			massif.lot = bilan["lot"]
			return "« %s » sliced again: its source changed since last time." % c["nom"]
	if cache["lot"] != null:
		massif.lot = cache["lot"]
		return ("[color=#f2ca79]« %s »: %s is missing[/color] — showing the tiles last sliced from it."
			% [c["nom"], c["source"]])
	massif.lot = MeshLibrary.new()
	return ("[color=#e0603c]« %s »: %s is missing and was never cached[/color] — every tile is a red cube."
		% [c["nom"], c["source"]])


## ⚠ L'ENREGISTREMENT EST AUTOMATIQUE, APRÈS CHAQUE CHANGEMENT — branché sur l'historique, donc sur
## chaque coup, chaque opération, chaque Ctrl+Z. On écrit À CÔTÉ puis on remplace : un logiciel coupé
## en pleine écriture ne doit pas laisser un projet à moitié écrit.
func _enregistrer() -> void:
	if _ouverture or _projet == "" or _couches.is_empty():
		return
	_dire_le_projet()
	var sorties: Array = []
	for i in _couches.size():
		var etat: Dictionary = _couches[i].duplicate()
		var cases := {}
		for p in (_vue.couche(i).get_node("Cases") as GridMap).get_used_cells():
			cases[p] = true
		etat["cases"] = cases
		sorties.append(etat)
	var provisoire := _projet + ".tmp"
	var f := FileAccess.open(provisoire, FileAccess.WRITE)
	if f == null:
		_dire("[color=#e0603c]Project NOT saved[/color] — %s cannot be written (error %d)."
			% [_projet, FileAccess.get_open_error()])
		return
	f.store_string(Projet.vers_texte(sorties, _active))
	f.close()
	var e: int = DirAccess.rename_absolute(provisoire, _projet)
	if e != OK:
		_dire("[color=#e0603c]Project NOT saved[/color] — %s could not replace the old file (error %d)."
			% [_projet, e])


func _enregistrer_sous(chemin: String) -> void:
	if chemin.get_extension() != Projet.EXTENSION:
		chemin += "." + Projet.EXTENSION
	_projet = chemin
	_enregistrer()
	_retenir_le_projet()
	_dire("[color=#b4bd85][b]Project saved[/b][/color] → %s\n[i]It saves itself there from now on.[/i]"
		% chemin)


func _retenir_le_projet() -> void:
	var reglages := ConfigFile.new()
	reglages.load(REGLAGES)
	reglages.set_value("projet", "dernier", _projet)
	reglages.save(REGLAGES)
	_dire_le_projet()


func _dire_le_projet() -> void:
	if _etiquette_projet == null:
		return
	_etiquette_projet.text = _projet.get_file().get_basename()
	_etiquette_projet_chemin.text = ("Autosaved in the app data — « Save as » to keep it elsewhere."
		if _projet.begins_with("user://") else "Autosaved · " + _projet.get_base_dir())
	# ⚠ PAS DE FENÊTRE HORS DE L'ARBRE : le dernier enregistrement, à la fermeture, arrive quand l'écran
	# en est déjà sorti — `get_window()` rend alors `null`, et c'était l'erreur du journal.
	if is_inside_tree():
		get_window().title = "MarchingBlocks — " + _projet.get_file().get_basename()


# ── LES RACCOURCIS ───────────────────────────────────────────────────────────────────────────────────

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or (_manuel != null and _manuel.visible):
		return
	if k.ctrl_pressed:
		if k.keycode == KEY_Z and not k.shift_pressed:
			if _histoire.undo():
				_dire("[i]Undone: %s[/i]" % _histoire.get_current_action_name())
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_Y or (k.keycode == KEY_Z and k.shift_pressed):
			if _histoire.redo():
				_dire("[i]Redone: %s[/i]" % _histoire.get_current_action_name())
			get_viewport().set_input_as_handled()
		elif _atelier == "monde" and k.keycode in [KEY_C, KEY_X, KEY_V]:
			match k.keycode:
				KEY_C:
					_copier()
				KEY_X:
					_couper()
				KEY_V:
					_coller()
			get_viewport().set_input_as_handled()
		return
	if _atelier == "jeu":
		match k.keycode:
			KEY_ESCAPE:
				_aller_a("monde")
			KEY_BACKSPACE:
				_vue.reapparaitre()
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if _atelier != "monde":
		return
	# ⚠ **EN NAVIGATE, LES TOUCHES DE VOL NE CHOISISSENT PAS D'OUTIL.** S et D sont aussi Select et Dig :
	# voler vers l'arrière aurait changé d'outil en silence. On les lit par leur PLACE (`vue.gd`).
	if _vue.naviguer and k.physical_keycode in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E]:
		get_viewport().set_input_as_handled()
		return
	var fait := true
	match k.keycode:
		KEY_A:
			_choisir_outil("ajouter")
		KEY_D:
			_choisir_outil("creuser")
		KEY_S:
			_choisir_outil("selectionner")
		KEY_B:
			_choisir_outil("boite")
		KEY_R:
			_choisir_outil("rect")
		KEY_BRACKETLEFT:
			_taille.value -= 1
		KEY_BRACKETRIGHT:
			_taille.value += 1
		KEY_PAGEUP:
			_compteur_etage.value += 1
		KEY_PAGEDOWN:
			_compteur_etage.value -= 1
		KEY_DELETE:
			_operer_selection("supprimer")
		KEY_ESCAPE:
			if not _vue.collage.is_empty():
				_vue.annuler_collage()
				_dire("[i]Paste cancelled.[/i]")
			else:
				_vue.vider_selection()
		_:
			fait = false
	if fait:
		get_viewport().set_input_as_handled()


## ⚠ TAB PASSE PAR `_input`, PAS PAR `_unhandled_key_input` : l'interface le consomme d'abord pour
## déplacer le focus d'un bouton à l'autre, et le raccourci ne serait jamais arrivé. On ne le prend que
## si aucun champ de texte n'a la main — le nom d'une couche se tape au clavier.
## ⚠ LES FLÈCHES AUSSI, et pour la même raison : elles déplacent le focus entre les boutons. Elles
## répètent quand on les tient (`echo`), comme on l'attend d'un déplacement.
func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_F1 and not _manuel.visible:
		_manuel.ouvrir()
		get_viewport().set_input_as_handled()
		return
	if _manuel != null and _manuel.visible:
		return
	if k == null or not k.pressed or _atelier != "monde" or k.ctrl_pressed or k.alt_pressed:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	if k.keycode == KEY_TAB and not k.echo:
		var i: int = _vue.VISEES.find(_vue.visee)
		_choisir_visee(_vue.VISEES[(i + 1) % _vue.VISEES.size()])
	# ⚠ ESPACE PASSE AUSSI PAR `_input` : un bouton qui a le clavier le prendrait pour un clic.
	elif k.keycode == KEY_SPACE and not k.echo:
		_basculer_navigation(not _vue.naviguer)
	elif k.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT] and not _vue.selection.is_empty():
		var haut: int = 1 if k.keycode == KEY_UP else (-1 if k.keycode == KEY_DOWN else 0)
		if k.shift_pressed:
			if haut != 0:
				_deplacer(Vector3i(0, haut, 0))
		else:
			var cote: int = 1 if k.keycode == KEY_RIGHT else (-1 if k.keycode == KEY_LEFT else 0)
			_deplacer_a_l_ecran(Vector2i(cote, -haut))
	else:
		return
	get_viewport().set_input_as_handled()


func _dire(texte: String) -> void:
	if _rapport != null:
		_rapport.text = texte
