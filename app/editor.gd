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
const FormatMonde := preload("res://addons/marchingblocks_core/format_monde.gd")
const Palette := preload("res://app/palette.gd")
const Section := preload("res://app/section.gd")
const Panneau := preload("res://app/panneau.gd")
const Vue := preload("res://app/vue.gd")
const Projet := preload("res://app/projet.gd")
const Icones := preload("res://app/icones.gd")
const Manuel := preload("res://app/manuel.gd")
const Associations := preload("res://app/associations.gd")
const Modeleur := preload("res://app/modeleur.gd")
const LegendeFormes := preload("res://app/legende_formes.gd")
const ME := preload("res://addons/marchingblocks_core/maillage_edite.gd")
const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")

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
	"Play test: walk your world. Z Q S D to move, Space to jump, Shift to run, left drag to orbit the camera.",
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
## LA BARRE DU MODELEUR — la barre de droite de l'atelier Witness (Jordan, 29 septembre 2026).
var _droite_temoin: Panneau
## LA LÉGENDE DES FORMES du témoin — le bandeau repliable en haut de la vue, dans l'atelier Witness.
var _legende_formes: LegendeFormes
var _modeleur: Node3D
var _bouton_edition: Button
var _boutons_selmode := {}
var _bouton_prop: Button
## L'enregistrement du témoin modélisé attend une seconde de calme : un geste = un fichier réécrit, pas dix.
var _minuterie_temoin: Timer
## LES MATÉRIAUX DU MODELEUR : la liste, et l'éditeur du matériau courant.
var _liste_materiaux: VBoxContainer
var _edition_materiau: VBoxContainer
var _nom_materiau: LineEdit
var _couleur_materiau: ColorPickerButton
var _rugosite_materiau: HSlider
var _metal_materiau: HSlider
var _echelle_materiau: SpinBox
var _projection_materiau: OptionButton
var _etat_uv: Label
var _texture_materiau: Label
var _remplit_materiau := false
## ⚠ UNE RAFALE DE RETOUCHES = UNE ANNULATION : glisser la rugosité émet cent valeurs ; on garde le
## maillage d'avant la première, et on inscrit le geste quand les retouches se calment.
var _materiau_avant: RefCounted
var _minuterie_materiau: Timer
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
var _etat_enregistre: Label
var _case_associations: CheckButton
var _etiquette_temoin_couche: Label
var _section_monde_peint: Control
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
	_inscrire_les_fichiers()


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
	_modeleur = Modeleur.new()
	_vue.brancher_modeleur(_modeleur)
	_modeleur.change.connect(_geste_du_modeleur)
	_modeleur.dit.connect(_dire)
	_droite_temoin = _panneau(corps, false, LARGEUR_DROITE)
	_batir_droite_temoin(_droite_temoin.get_meta("pile"))
	# LA LÉGENDE DES FORMES, en haut de la vue ENTRE les deux barres (Jordan, 29 septembre 2026).
	_legende_formes = LegendeFormes.new()
	_legende_formes.anchor_left = 0.0
	_legende_formes.anchor_right = 1.0
	_legende_formes.offset_left = LARGEUR_GAUCHE
	_legende_formes.offset_right = -LARGEUR_DROITE
	corps.add_child(_legende_formes)
	_legende_formes.zone_survolee.connect(_vue.montrer_zone)
	_legende_formes.zone_choisie.connect(_vue.cadrer_zone)
	# LE SENS INVERSE, dans World : la tuile survolée dit de quelle forme du témoin elle vient.
	_vue.tuile_survolee.connect(_legende_formes.montrer_provenance)
	_legende_formes.voir_dans_le_temoin.connect(_voir_dans_le_temoin)
	# LA PLANCHE DES TUILES (charte §3) : le témoin qu'on édite s'il est chargé, sinon le témoin calculé.
	_legende_formes.fournir_temoin = _temoin_pour_la_planche
	_legende_formes.tuile_choisie.connect(_aller_a_la_tuile)
	_legende_formes.copies_survolees.connect(func(c: Array) -> void: _vue.montrer_zone(c, 0.45))
	_minuterie_temoin = Timer.new()
	_minuterie_temoin.one_shot = true
	_minuterie_temoin.wait_time = 1.0
	_minuterie_temoin.timeout.connect(_enregistrer_le_temoin_modele)
	add_child(_minuterie_temoin)
	_minuterie_materiau = Timer.new()
	_minuterie_materiau.one_shot = true
	_minuterie_materiau.wait_time = 0.8
	_minuterie_materiau.timeout.connect(_inscrire_les_retouches)
	add_child(_minuterie_materiau)
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
	# ⚠ L'ENREGISTREMENT EST AUTOMATIQUE, ET IL SE VOIT (Jordan, 30 septembre 2026 : « il faut le dire au
	# client ») : un client qui cherche Ctrl+S doit lire, sans chercher, que tout est déjà enregistré.
	_etat_enregistre = Label.new()
	_etat_enregistre.add_theme_font_size_override("font_size", 12)
	_etat_enregistre.mouse_filter = Control.MOUSE_FILTER_PASS
	_etat_enregistre.tooltip_text = ("MarchingBlocks saves every change by itself — no need for Ctrl+S.\n"
		+ "« Save as » (Project) puts the project where you want; it keeps saving itself there.")
	ligne.add_child(_etat_enregistre)
	_dire_enregistre("enregistre")

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

	# L'éditeur, tout à droite. ⚠ LE LOGO DÉTOURÉ, pas `spannergames.png` : son fond violet opaque
	# ferait un carré sur la barre.
	if ResourceLoader.exists("res://MARQUE/spannergames_detoure.png"):
		var logo := TextureRect.new()
		logo.texture = load("res://MARQUE/spannergames_detoure.png")
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.custom_minimum_size = Vector2(20, 20)
		ligne.add_child(logo)
	var editeur := Label.new()
	editeur.text = "SpannerGames Inc."
	editeur.add_theme_color_override("font_color", Palette.GRIS)
	editeur.add_theme_font_size_override("font_size", 12)
	ligne.add_child(editeur)
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
			["Left drag", "Orbit the camera"], ["Right drag", "Turn (level)"], ["Wheel", "Closer · farther"], ["Backspace", "Back to start"],
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
	# LES FICHIERS DANS WINDOWS (Jordan, 30 septembre 2026) : inscrits au premier lancement ; la case les retire
	# — et le refus tient d'un lancement à l'autre.
	_case_associations = CheckButton.new()
	_case_associations.text = "File icons & double-click"
	_case_associations.add_theme_font_size_override("font_size", 11)
	_case_associations.tooltip_text = ("Gives .mbproj, .mbtiles, .mbset and .mbworld their MarchingBlocks icons, "
		+ "and opens a project on double-click.\nOnly for your Windows account; untick to remove it.")
	_case_associations.focus_mode = Control.FOCUS_NONE
	_case_associations.toggled.connect(_regler_les_associations)
	projet.contenu.add_child(_case_associations)

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
	# ⚠ UNE COUCHE EST UN TÉMOIN ET UN MONDE PEINT (Jordan, 30 septembre 2026) : ses tuiles à sculpter
	# (Witness) et ses cases à peindre (World). La même liste dans les deux ateliers : on choisit l'une, les
	# deux suivent.
	couches.contenu.add_child(_texte("A layer is a witness AND a painted world: its own tiles to sculpt "
		+ "(Witness) and its own cells to paint (World). Pick one: both workshops follow.", 11, Palette.GRIS))
	_liste_couches = VBoxContainer.new()
	_liste_couches.add_theme_constant_override("separation", 4)
	couches.contenu.add_child(_liste_couches)
	_nom_couche = LineEdit.new()
	_nom_couche.placeholder_text = "rename the active layer"
	_nom_couche.text_submitted.connect(func(_t: String) -> void: _renommer_couche())
	_nom_couche.focus_exited.connect(_renommer_couche)
	couches.contenu.add_child(_nom_couche)
	couches.contenu.add_child(_rangee([
		_bouton("New layer", "Adds an empty layer, with the computed witness, and makes it active.",
			_nouvelle_couche, "plus"),
		_bouton("Copy witness", "Adds a layer whose witness is a COPY of the active layer's (no cells): "
			+ "sculpt it into a variant — ice from rock — without touching the original.", _copier_le_temoin,
			"copier"),
	]))
	_bouton_supprimer_couche = _bouton("Delete layer", "Deletes the active layer (Ctrl+Z brings it back).",
		_supprimer_couche, "poubelle", Palette.DANGER)
	couches.contenu.add_child(_bouton_supprimer_couche)

	# ── LE MONDE PEINT — DEMANDÉ PAR JORDAN (29 septembre 2026) : « dans WORLD, une section pour gérer le
	# monde peint, déjà l'exporter vers les trois addons ». Toutes les couches partent ENSEMBLE, avec
	# leurs tuiles, dans un seul dossier (`format_monde.gd`).
	var monde_peint := Section.new("Painted world", true, Icones.icone("monde"))
	pile.add_child(monde_peint)
	_section_monde_peint = monde_peint
	monde_peint.contenu.add_child(_texte("Sends the WHOLE world — every layer, its cells and its tiles — "
		+ "to Godot, Unity or Unreal, through the free MarchingBlocks Paint plugins.", 11, Palette.GRIS))
	monde_peint.contenu.add_child(_bouton("Export the world…",
		"Writes <project>.mbworld/ : world.json (the layers and their cells, in order) and one .mbset "
		+ "folder per tile source.\nIn your engine: Import MarchingBlocks world. A layer without tiles "
		+ "still travels, and shows it has none.", func() -> void: _demander("monde"), "exporter",
		Palette.PRINCIPAL))

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
	etape1.contenu.add_child(_texte("Send the block to Blender as linked copies: one tile per class, "
		+ "sculpt one copy and every copy follows.", 11, Palette.GRIS))
	etape1.contenu.add_child(_bouton("Export the witness…",
		"Writes the witness as ONE .glb for Blender: every tile of the world is an object, and all the "
		+ "copies of a tile share ONE mesh (linked duplicates).\nSculpt any copy: they all follow, and "
		+ "the witness shows exactly what the painted world will show.\nDo not MOVE the objects, do not "
		+ "Join them: their POSITION identifies each tile when it comes back, not its name.",
		func() -> void: _demander("exporter"), "exporter", Palette.PRINCIPAL))

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
	etape3.contenu.add_child(_bouton("Slice this layer's witness",
		"Dresses the ACTIVE layer with the tiles of its own witness — the one you sculpt in Witness.\n"
		+ "It happens by itself a second after each witness edit; this button does it on demand.\n"
		+ "Its painted cells stay as they are.", _trancher_temoin_de_la_couche, "cube"))

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
		["Extend facing", "face", "extruder_face", "copies the cells one cell away from the matter "
			+ "behind them — a wall thickens toward the air, a cave ceiling comes down"],
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
##   Painted world                           ✓         (exporter le monde entier vers les greffons)
##   Play test                                         ✓
##   Witness (réf.)        ✓        ✓                  (sa légende nomme les teintes du TÉMOIN)
##   Shortcuts (réf.)                        ✓         (ce ne sont que des gestes de peinture)
##   barre de droite                         ✓         (elle ne porte que des outils de peinture)
##   barre du modeleur            ✓                    (les outils de modélisation du témoin)
##   légende des formes           ✓        ✓           (Witness : quelle forme devient quoi ;
##                                                      World : d'où vient la tuile survolée)
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
	_section_couches.visible = monde or temoin
	_section_monde_peint.visible = monde
	_titre_aller_retour.visible = projet
	for e in _etapes_artiste:
		e.visible = projet
	for e in _etapes_monde:
		e.visible = projet
	_section_temoin.visible = temoin or projet
	_section_raccourcis.visible = monde
	_zone_reference.visible = temoin or monde or projet
	_droite.visible = monde
	_droite_temoin.visible = temoin
	_legende_formes.visible = temoin or monde
	_legende_formes.regler_atelier(_atelier)
	_contexte_des_outils()


## « Show it in the witness » (World) : on va dans Witness, la forme allumée, la place EXACTE de la tuile
## marquée, la vue cadrée dessus sous l'angle de la photo de la forme.
## Le témoin calculé en tuiles, gardé tant que le modeleur ne l'a pas pris (la planche peut le demander avant).
var _temoin_calcule: RefCounted


func _temoin_pour_la_planche() -> RefCounted:
	return _temoin_de(_couches[_active])


## Un clic sur une tuile de la planche : la vue cadre sa copie la plus LISIBLE (la plus pure, celle dont les
## voisins ont laissé le moins de traces), une boîte blanche la montre, et en édition elle passe en édition.
func _aller_a_la_tuile(cle: String) -> void:
	var t: RefCounted = _temoin_pour_la_planche()
	var liste: Array = t.occurrences_de(cle)
	if liste.is_empty():
		return
	var pleines: Dictionary = BM.cases(0)
	var meilleure: int = liste[0]
	for i in liste:
		if MB.purete(pleines, t.occurrences[i]["sommet"]) < MB.purete(pleines, t.occurrences[meilleure]["sommet"]):
			meilleure = i
	var sommet: Vector3i = t.occurrences[meilleure]["sommet"]
	var huit: Array = []
	for k in 8:
		huit.append(sommet + MB.COINS[k])
	_vue.cadrer_zone(huit, _vue._azimut, _vue._elevation, 9.0)
	_vue.montrer_tuile(sommet)
	if _vue.edition and _modeleur.temoin == t:
		_modeleur.activer(meilleure)
	_dire(("[b]%s[/b] — %d copies in the witness; the white box is the clearest one. %s")
		% [FormatNeutre.id_de_cle(cle), liste.size(), "It is now the tile you edit." if _vue.edition
		else "Press Tab to edit it: every copy follows."])


func _voir_dans_le_temoin(sommet: Vector3i, carte: Dictionary, azimut: float, elevation: float) -> void:
	_aller_a("witness")
	var huit: Array = []
	for t in 8:
		huit.append(sommet + MB.COINS[t])
	# ⚠ LA TUILE SEULE, PAS TOUTE LA FORME : la zone du plateau couvre la moitié du bloc, et son ambre
	# noyait la boîte blanche qu'on venait montrer (vu à l'image). La forme, c'est la carte du bandeau.
	_vue.cadrer_zone(huit, azimut, elevation, 13.0)
	_vue.montrer_tuile(sommet)
	_legende_formes.mettre_en_avant(carte["id"])
	_dire("[b]%s[/b] — the white box is the exact spot this tile was cut from, witness corner (%d, %d, %d). "
		% [carte["nom"], sommet.x, sommet.y, sommet.z]
		+ "Sculpt there to change it.")


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


# ── LE MODELEUR DU TÉMOIN ────────────────────────────────────────────────────────────────────────────
#
# **DÉCIDÉ (Jordan, 29 septembre 2026)** : le modeleur remplace Blender. Palier 1, l'édition de maillage :
# les gestes et les raccourcis de Blender (`modeleur.gd`), sur un maillage de polygones
# (`maillage_edite.gd`). Tab entre et sort de l'édition, comme dans Blender.
#
# ⚠ **LE TÉMOIN MODÉLISÉ PREND LA ROUTE DES TRAVAUX, ET AUCUNE AUTRE** : il s'enregistre en `.glb` à côté du
# projet et entre dans la liste de l'étape 2, où l'on le tranche comme un travail importé. Une seconde
# route de tranchage finirait par trancher autrement (charte §6).

func _batir_droite_temoin(pile: VBoxContainer) -> void:
	var mode := Section.new("Edit mode", true, Icones.icone("cube"))
	pile.add_child(mode)
	# QUEL TÉMOIN ON ÉDITE : celui de la couche active (un témoin par couche, 30 septembre 2026).
	_etiquette_temoin_couche = _texte("", 11, Palette.OLIVE)
	mode.contenu.add_child(_etiquette_temoin_couche)
	_bouton_edition = Button.new()
	_bouton_edition.text = "Edit the witness  ·  Tab"
	_bouton_edition.icon = Icones.icone("outils")
	_bouton_edition.toggle_mode = true
	_bouton_edition.focus_mode = Control.FOCUS_NONE
	_bouton_edition.custom_minimum_size = Vector2(0, 34)
	_bouton_edition.tooltip_text = ("Tab — edit the witness mesh, the way you would in Blender.\nTab again "
		+ "looks at it without editing.")
	_bouton_edition.toggled.connect(func(v: bool) -> void: _regler_edition(v))
	mode.contenu.add_child(_bouton_edition)
	mode.contenu.add_child(_petit_titre("SELECT  ·  1 2 3"))
	mode.contenu.add_child(_rangee_de_choix(_boutons_selmode, [
		["sommet", "Vertex", "ajouter", "1 — select vertices."],
		["arete", "Edge", "rect", "2 — select edges."],
		["face", "Face", "boite", "3 — select faces."],
	], func(m: String) -> void:
		_regler_edition(true)
		_modeleur.choisir_mode(m), Palette.OUTIL))
	(_boutons_selmode["face"] as Button).button_pressed = true

	var sel := Section.new("Select", true, Icones.icone("selectionner"))
	pile.add_child(sel)
	sel.contenu.add_child(_texte("Click selects what you SEE · Shift+click adds or removes · Alt+click "
		+ "selects a loop (a ring of faces in Face mode).", 11, Palette.GRIS))
	sel.contenu.add_child(_grille([
		_bouton("All  ·  A", "A — select everything.", func() -> void: _geste_modeleur("tout"), "grandir"),
		_bouton("None  ·  Alt+A", "Alt+A — select nothing.", func() -> void: _geste_modeleur("rien"), "croix"),
		_bouton("Box  ·  B", "B, then drag a rectangle. It also takes what is hidden behind.",
			func() -> void: _geste_modeleur("B"), "boite"),
	], 2))

	var tr := Section.new("Transform", true, Icones.icone("deplacer"))
	pile.add_child(tr)
	tr.contenu.add_child(_texte("Move the mouse, then click or Enter to confirm, Esc or right click to cancel. "
		+ "X Y Z lock an axis (Z is UP, as in Blender). Type a number for an exact value.", 11, Palette.GRIS))
	tr.contenu.add_child(_grille([
		_bouton("Move  ·  G", "G — move the selection.", func() -> void: _geste_modeleur("G"), "deplacer"),
		_bouton("Rotate  ·  R", "R — rotate it around its center. Typed values are degrees.",
			func() -> void: _geste_modeleur("R"), "connexe"),
		_bouton("Scale  ·  S", "S — scale it from its center.", func() -> void: _geste_modeleur("S"), "grandir"),
	], 2))
	_bouton_prop = Button.new()
	_bouton_prop.text = "Proportional editing  ·  O"
	_bouton_prop.toggle_mode = true
	_bouton_prop.focus_mode = Control.FOCUS_NONE
	_bouton_prop.tooltip_text = ("O — nearby vertices follow part of the way, softly. The wheel changes the "
		+ "radius during a move.")
	_bouton_prop.toggled.connect(func(v: bool) -> void: _modeleur.proportionnel = v)
	tr.contenu.add_child(_bouton_prop)

	var mesh := Section.new("Mesh", true, Icones.icone("couteau"))
	pile.add_child(mesh)
	mesh.contenu.add_child(_grille([
		_bouton("Extrude  ·  E", "E — pull the selected faces (or edges) out; they follow the mouse.",
			func() -> void: _geste_modeleur("E"), "extruder_haut"),
		_bouton("Inset  ·  I", "I — a smaller copy of the selected faces inside them.",
			func() -> void: _geste_modeleur("I"), "evider"),
		_bouton("Loop cut  ·  Ctrl+R", "Ctrl+R — point an edge: its ring lights up; click to cut it in the middle.",
			func() -> void: _geste_modeleur("loop"), "couteau"),
		_bouton("Subdivide", "Splits each selected face into quads. Neighbours get the new points too: no gap.",
			func() -> void: _geste_modeleur("subdiviser"), "grandir"),
		_bouton("Merge  ·  M", "M — merge the selected vertices at their center.",
			func() -> void: _geste_modeleur("fusionner"), "retrecir"),
		_bouton("Fill  ·  F", "F — make a face on the selected vertices (a hole's rim).",
			func() -> void: _geste_modeleur("remplir"), "remplir"),
		_bouton("Bevel  ·  Ctrl+B", "Ctrl+B — chamfer the selected edges (or the edges of the selected "
			+ "faces); the width follows the mouse or is typed.", func() -> void: _geste_modeleur("bevel"), "evider"),
		_bouton("Knife  ·  K", "K — click points on edges, face by face; Enter cuts.",
			func() -> void: _geste_modeleur("knife"), "couper"),
		_bouton("Delete  ·  X", "X — delete the selected faces, edges or vertices. It opens a hole: F closes it.",
			func() -> void: _geste_modeleur("supprimer"), "poubelle", Palette.DANGER),
	], 2))

	var vue := Section.new("View", true, Icones.icone("oeil"))
	pile.add_child(vue)
	vue.contenu.add_child(_texte("Middle drag turns, Shift + middle slides, the wheel zooms.", 11, Palette.GRIS))
	vue.contenu.add_child(_grille([
		_bouton("Front  ·  1", "Numpad 1 (Ctrl: back).", func() -> void: _vue.vue_de("face")),
		_bouton("Right  ·  3", "Numpad 3 (Ctrl: left).", func() -> void: _vue.vue_de("droite")),
		_bouton("Top  ·  7", "Numpad 7 (Ctrl: bottom).", func() -> void: _vue.vue_de("dessus")),
		_bouton("Frame  ·  .", "Numpad . — center the view on the selection.", _cadrer_la_selection),
		_bouton("Ortho  ·  5", "Numpad 5 — perspective or orthographic.",
			func() -> void: _dire("[i]%s view.[/i]" % ("Orthographic" if _vue.basculer_ortho() else "Perspective"))),
	], 2))

	# ── LES MATÉRIAUX — DÉCIDÉ (Jordan, 29 septembre 2026) : matériaux + projections.
	var mats := Section.new("Materials", true, Icones.icone("texture"))
	pile.add_child(mats)
	mats.contenu.add_child(_texte("Pick a material, select faces, Assign. Textures are PROJECTED from the "
		+ "position (box mapping): new faces are textured too. Tileable images whose repeat divides one "
		+ "cell join from tile to tile.", 11, Palette.GRIS))
	_liste_materiaux = VBoxContainer.new()
	_liste_materiaux.add_theme_constant_override("separation", 4)
	mats.contenu.add_child(_liste_materiaux)
	mats.contenu.add_child(_grille([
		_bouton("New material", "Adds a material and makes it the one you assign.", _nouveau_materiau, "plus"),
		_bouton("Assign", "Gives the chosen material to the selected faces.", _assigner_materiau, "remplir",
			Palette.PRINCIPAL),
	], 2))
	_edition_materiau = VBoxContainer.new()
	_edition_materiau.add_theme_constant_override("separation", 6)
	mats.contenu.add_child(_edition_materiau)
	_nom_materiau = LineEdit.new()
	_nom_materiau.placeholder_text = "material name"
	_nom_materiau.text_submitted.connect(func(t: String) -> void: _retoucher("nom", t))
	_nom_materiau.focus_exited.connect(func() -> void: _retoucher("nom", _nom_materiau.text))
	_edition_materiau.add_child(_nom_materiau)
	_couleur_materiau = ColorPickerButton.new()
	_couleur_materiau.text = "Colour"
	_couleur_materiau.custom_minimum_size = Vector2(0, 30)
	_couleur_materiau.color_changed.connect(func(c: Color) -> void: _retoucher("couleur", c))
	_edition_materiau.add_child(_couleur_materiau)
	_rugosite_materiau = _curseur(_edition_materiau, "Roughness", 0.0, 1.0, 0.01, "rugosite")
	_metal_materiau = _curseur(_edition_materiau, "Metallic", 0.0, 1.0, 0.01, "metal")
	var ligne_echelle := HBoxContainer.new()
	ligne_echelle.add_child(_texte("Repeat every", 11, Palette.GRIS))
	_echelle_materiau = SpinBox.new()
	_echelle_materiau.min_value = 0.05
	_echelle_materiau.max_value = 16.0
	_echelle_materiau.step = 0.05
	_echelle_materiau.suffix = "cell"
	_echelle_materiau.tooltip_text = ("How many cells one copy of the image covers. 1, 0.5, 0.25… divide a cell: "
		+ "the texture then joins from one tile to the next.")
	_echelle_materiau.value_changed.connect(func(v: float) -> void: _retoucher("echelle", v))
	ligne_echelle.add_child(_echelle_materiau)
	_edition_materiau.add_child(ligne_echelle)
	var ligne_proj := HBoxContainer.new()
	ligne_proj.add_child(_texte("Projection", 11, Palette.GRIS))
	_projection_materiau = OptionButton.new()
	for e in [["Box", "boite"], ["Top", "dessus"], ["Front", "face"], ["Side", "cote"], ["UV (unwrapped)", "uv"]]:
		_projection_materiau.add_item(e[0])
		_projection_materiau.set_item_metadata(_projection_materiau.item_count - 1, e[1])
	_projection_materiau.tooltip_text = ("Box: each face takes the side of the box it faces — walls, floors and "
		+ "ceilings all look right.\nTop / Front / Side: one flat projection for every face (the faces across it "
		+ "are stretched).\nUV: the unwrapped layout (U) — for images painted on the exported UV layout; faces "
		+ "without UVs fall back to Box.")
	_projection_materiau.item_selected.connect(func(i: int) -> void:
		_retoucher("projection", _projection_materiau.get_item_metadata(i)))
	ligne_proj.add_child(_projection_materiau)
	_edition_materiau.add_child(ligne_proj)
	_texture_materiau = _texte("no image", 11, Palette.GRIS)
	_edition_materiau.add_child(_grille([
		_bouton("Unwrap  ·  U", "U — unwrap the selected faces (all of them if none is selected): islands of "
			+ "faces that face the same way, laid flat in the 0–1 square at one scale.",
			func() -> void:
				_regler_edition(true)
				_modeleur.deplier_selection(), "grille"),
		_bouton("Export UV layout…", "Writes a PNG of the unwrapped edges, to paint on in your image editor.",
			func() -> void: _demander("patron"), "exporter"),
	], 2))
	_etat_uv = _texte("", 11, Palette.AMBRE)
	_edition_materiau.add_child(_etat_uv)
	_edition_materiau.add_child(_texture_materiau)
	_edition_materiau.add_child(_grille([
		_bouton("Image…", "A tileable image (.png, .jpg) projected on the faces.",
			func() -> void: _demander("texture"), "texture"),
		_bouton("No image", "Colour only.", func() -> void: _retoucher("texture", ""), "croix"),
	], 2))
	_redire_les_materiaux()

	var tem := Section.new("The modelled witness", true, Icones.icone("enregistrer"))
	pile.add_child(tem)
	tem.contenu.add_child(_texte("It saves itself next to the project, and joins the works of step 2 "
		+ "(Project): slice it there, like an imported work.", 11, Palette.GRIS))
	tem.contenu.add_child(_bouton("Reset to the computed witness",
		"Starts again from the computed witness (Ctrl+Z brings your model back).", _remettre_le_temoin,
		"gomme", Palette.DANGER))


## Entre ou sort de l'édition. La première fois, le maillage se charge : le témoin modélisé enregistré
## s'il existe, sinon le témoin calculé.
## ⚠ **LE TÉMOIN LIÉ (charte §3, 30 septembre 2026)** : on édite UNE TUILE PAR CLÉ, et toutes ses copies
## suivent. Le `.mbtiles` fait foi (tuiles, matériaux) ; à défaut, le témoin calculé en tuiles (~2 s, sans
## panneau d'attente : il guette une image, qui ne vient pas en headless).
## ⚠ Un ancien `.mbmesh` (le témoin d'un seul tenant d'avant les copies liées) n'est PAS converti : on ne
## sait pas quelle copie d'une clé il faudrait garder. Il reste sur le disque, et on le DIT.
func _regler_edition(oui: bool) -> void:
	var dit_ancien := ""
	if oui:
		# ⚠ LE TÉMOIN DE LA COUCHE ACTIVE (Jordan, 30 septembre 2026) : chaque couche a le sien.
		var t: RefCounted = _temoin_de(_couches[_active])
		if _modeleur.temoin != t:
			_modeleur.charger_temoin(t, _occurrence_de_depart(t))
			_redire_les_materiaux()
			_legende_formes.rafraichir_tuiles()
		var ancien := _projet.get_basename() + "_witness.mbmesh"
		if _origine_du_temoin(_couches[_active]) == "computed witness" and FileAccess.file_exists(ancien):
			dit_ancien = ("\n[color=#f2ca79]An older single-mesh model was found[/color] (%s): it is kept on "
				+ "disk but not used — the linked editor starts from the computed witness.") % ancien.get_file()
	_vue.regler_edition(oui)
	_bouton_edition.set_pressed_no_signal(oui)
	if oui:
		_dire(("[b]Edit mode — the witness of layer « %s »[/b] — %d tiles, shown as %d linked copies. Click "
			+ "any copy: you edit its tile, and every copy follows. 1 2 3 pick vertices, edges or faces; G R S E I, "
			+ "Ctrl+R, X M F work as in Blender. [i]Tab to stop editing.[/i]%s")
			% [_couches[_active]["nom"], _modeleur.temoin.tuiles.size(), _modeleur.temoin.occurrences.size(), dit_ancien])


## L'occurrence en édition au départ : la première de la tuile la plus partagée (la paroi à l'air libre),
## celle qu'on sculpte d'abord.
func _occurrence_de_depart(t: RefCounted) -> int:
	var meilleure := ""
	for c in t.tuiles:
		if meilleure == "" or t.occurrences_de(c).size() > t.occurrences_de(meilleure).size():
			meilleure = c
	var liste: Array = t.occurrences_de(meilleure)
	return int(liste[0]) if not liste.is_empty() else 0


func _geste_modeleur(nom: String) -> void:
	_regler_edition(true)
	match nom:
		"tout":
			_modeleur.tout_choisir(true)
		"rien":
			_modeleur.tout_choisir(false)
		"B":
			_modeleur.modal = "B"
			_dire("[b]Box select[/b] — drag a rectangle. Esc cancels.")
		"loop":
			_modeleur.commencer_boucle()
		"G", "R", "S", "E", "I", "bevel":
			_modeleur.commencer(nom)
		"knife":
			_modeleur.commencer_couteau()
		_:
			_modeleur.operer(nom)


func _cadrer_la_selection() -> void:
	var c = _modeleur.centre_de_la_selection() if _modeleur.maillage != null else null
	if c == null:
		_dire("[i]Nothing selected to frame.[/i]")
		return
	_vue.cadrer(c)


## Chaque geste fini du modeleur : UNE action d'annulation, et le fichier réécrit une seconde plus tard.
## ⚠ **L'ANNULATION VISE LE TÉMOIN D'OÙ VIENT LE GESTE, PAS CELUI QU'ON ÉDITE** (un témoin par couche,
## 30 septembre 2026) : un Ctrl+Z après avoir changé de couche défait le geste dans SON témoin, et
## l'enregistre — jamais dans celui de la couche devenue active.
func _geste_du_modeleur(avant: RefCounted, apres: RefCounted, nom: String) -> void:
	var t: RefCounted = _modeleur.temoin
	_histoire.create_action("Witness: " + nom)
	_histoire.add_do_method(_remplacer_temoin.bind(t, apres))
	_histoire.add_undo_method(_remplacer_temoin.bind(t, avant))
	_histoire.commit_action(false)
	_temoin_modifie(t)


func _remplacer_temoin(t: RefCounted, m: RefCounted) -> void:
	if t == _modeleur.temoin:
		_modeleur.remplacer(m)
	elif m is TL.Lot:
		for c in (m as TL.Lot).tuiles:
			t.poser_tuile(c, (m as TL.Lot).tuiles[c])
	elif m.has_meta("cle"):
		t.poser_tuile(m.get_meta("cle"), m)
	_temoin_modifie(t)


## Les témoins modifiés depuis le dernier enregistrement (un par couche touchée).
var _temoins_sales := {}


func _temoin_modifie(t: RefCounted = null) -> void:
	if t == null:
		t = _modeleur.temoin
	if t != null:
		_temoins_sales[t] = true
	_minuterie_temoin.start()
	_dire_enregistre("en_cours")
	_redire_les_materiaux()


# ── LES MATÉRIAUX DU MODELEUR ──

func _curseur(parent: Control, nom: String, mini: float, maxi: float, pas: float, cle: String) -> HSlider:
	var ligne := HBoxContainer.new()
	var l := _texte(nom, 11, Palette.GRIS)
	l.custom_minimum_size = Vector2(80, 0)
	l.size_flags_horizontal = Control.SIZE_FILL
	ligne.add_child(l)
	var c := HSlider.new()
	c.min_value = mini
	c.max_value = maxi
	c.step = pas
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.value_changed.connect(func(v: float) -> void: _retoucher(cle, v))
	ligne.add_child(c)
	parent.add_child(ligne)
	return c


## La liste : la légende, puis chaque matériau ; le courant est enfoncé. Et l'éditeur du courant.
func _redire_les_materiaux() -> void:
	if _liste_materiaux == null:
		return
	for enfant in _liste_materiaux.get_children():
		_liste_materiaux.remove_child(enfant)
		enfant.queue_free()
	var groupe := ButtonGroup.new()
	var liste: Array = [[-1, "Legend colour (no material)", Palette.GRIS]]
	if _modeleur.maillage != null:
		for k in _modeleur.maillage.materiaux.size():
			var d: Dictionary = _modeleur.maillage.materiaux[k]
			liste.append([k, str(d.get("nom", "Material")), d.get("couleur", Color.WHITE)])
	if _modeleur.materiau_courant >= liste.size() - 1:
		_modeleur.materiau_courant = -1
	for e in liste:
		var b := Button.new()
		b.text = e[1]
		b.toggle_mode = true
		b.button_group = groupe
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.button_pressed = e[0] == _modeleur.materiau_courant
		var pastille := Panel.new()
		pastille.add_theme_stylebox_override("panel", Palette.fond(e[2], 3, 0))
		pastille.custom_minimum_size = Vector2(12, 12)
		pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(pastille)
		pastille.position = Vector2(-18, 9)
		var marge := MarginContainer.new()
		marge.add_theme_constant_override("margin_left", 20)
		marge.add_child(b)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			_modeleur.materiau_courant = e[0]
			_redire_les_materiaux())
		_liste_materiaux.add_child(marge)
	var k: int = _modeleur.materiau_courant
	_edition_materiau.visible = k >= 0
	if k >= 0:
		var d: Dictionary = _modeleur.maillage.materiaux[k]
		_remplit_materiau = true
		_nom_materiau.text = str(d.get("nom", ""))
		_couleur_materiau.color = d.get("couleur", Color.WHITE)
		_rugosite_materiau.value = float(d.get("rugosite", 0.8))
		_metal_materiau.value = float(d.get("metal", 0.0))
		_echelle_materiau.value = float(d.get("echelle", 1.0))
		var proj: String = str(d.get("projection", "boite"))
		for i in _projection_materiau.item_count:
			if _projection_materiau.get_item_metadata(i) == proj:
				_projection_materiau.select(i)
		var a_deplier: int = _modeleur.maillage.faces_a_deplier()
		_etat_uv.text = ("%d face(s) with the UV projection have no UVs (new or reshaped): press U again."
			% a_deplier) if a_deplier > 0 else ""
		_etat_uv.visible = a_deplier > 0
		var tex: String = str(d.get("texture", ""))
		_texture_materiau.text = tex.get_file() if tex != "" else "no image"
		_remplit_materiau = false


## LE PATRON DES UV — à peindre dans un logiciel de dessin, puis à rendre comme image d'un matériau « UV ».
func _exporter_le_patron(fichier: String) -> String:
	if _modeleur.maillage == null:
		return "nothing to export"
	var err: int = _modeleur.maillage.dessiner_patron(2048).save_png(fichier)
	if err != OK:
		_dire("[color=#e0603c]The UV layout could not be written[/color] (error %d)." % err)
		return "error %d" % err
	_dire("[b]UV layout written[/b] → %s\n[i]Paint on it (2048 × 2048), then give the image to a material with the "
		% fichier + "« UV » projection.[/i]")
	return ""


func _nouveau_materiau() -> void:
	_regler_edition(true)
	_modeleur.nouveau_materiau()
	_redire_les_materiaux()


func _assigner_materiau() -> void:
	_regler_edition(true)
	_modeleur.assigner_courant()


## Une retouche du matériau courant, À VIF ; l'annulation est inscrite quand les retouches se calment.
func _retoucher(cle: String, valeur: Variant) -> void:
	if _remplit_materiau or _modeleur.maillage == null or _modeleur.materiau_courant < 0:
		return
	if _materiau_avant == null:
		_materiau_avant = _modeleur.instantane()
	_modeleur.regler_materiau(_modeleur.materiau_courant, cle, valeur)
	if cle in ["nom", "texture"]:
		_redire_les_materiaux()
	_minuterie_materiau.start()


func _inscrire_les_retouches() -> void:
	if _materiau_avant == null:
		return
	var avant := _materiau_avant
	_materiau_avant = null
	_geste_du_modeleur(avant, _modeleur.instantane(), "Material")


## Repart du témoin calculé : TOUTES les tuiles, en UNE annulation (une par tuile, dans la même action).
func _remettre_le_temoin() -> void:
	_regler_edition(true)
	var neuf: RefCounted = TL.depuis_le_temoin_calcule()
	_histoire.create_action("Witness: Reset")
	for c in _modeleur.temoin.tuiles:
		if not neuf.tuiles.has(c):
			continue
		var avant: RefCounted = _modeleur.temoin.tuiles[c].copie()
		avant.set_meta("cle", c)
		var apres: RefCounted = neuf.tuiles[c].copie()
		apres.set_meta("cle", c)
		_histoire.add_do_method(_remplacer_temoin.bind(_modeleur.temoin, apres))
		_histoire.add_undo_method(_remplacer_temoin.bind(_modeleur.temoin, avant))
	_histoire.commit_action()


## Le témoin de la COUCHE ACTIVE : son `.mbtiles` (ce qui fait foi) et son `.glb` lié (ce qu'on tranche).
## ⚠ `.mbtiles` ET NON `.mbmesh` : l'ancien fichier (le témoin d'un seul tenant) n'est jamais écrasé.
func _chemin_modele_natif() -> String:
	return _chemin_temoin_de(_couches[_active])


func _chemin_temoin_modele() -> String:
	return _glb_du_temoin(_couches[_active])


## Écrit chaque témoin modifié — celui qu'on édite, et ceux qu'un Ctrl+Z a touchés dans d'autres couches.
## ⚠ Il n'entre PLUS dans la liste des travaux : la couche tranche son propre témoin (étape 3).
func _enregistrer_le_temoin_modele() -> String:
	if _modeleur.temoin != null:
		_temoins_sales[_modeleur.temoin] = true
	var raison := ""
	for t in _temoins_sales.keys():
		var c: Dictionary = _couche_du_temoin(t)
		if c.is_empty():
			continue   # la couche a été supprimée : son témoin revient avec elle (Ctrl+Z)
		var r := _enregistrer_temoin(c)
		if r != "":
			raison = r
	_temoins_sales.clear()
	_legende_formes.rafraichir_tuiles()   # les photos de la planche montrent ce qu'on a sculpté
	_rafraichir_couches()
	# ⚠ L'ÉTAT CONCLUT TOUJOURS : sans témoin à écrire, `_enregistrer` n'aurait pas été appelé, et la barre
	# serait restée sur « Saving… ».
	_dire_enregistre("enregistre" if raison == "" else "echec")
	return raison


# ── LE TÉMOIN DE CHAQUE COUCHE — DÉCIDÉ (Jordan, 30 septembre 2026) ─────────────────────────────────────
#
# Une couche POSSÈDE son témoin lié : on le retrouve, on le remodifie, et le remodeler ne touche aucune
# autre couche. ⚠ Avant, le témoin modélisé était UN par projet (`<projet>_witness.glb`) : le remodeler pour
# une couche changeait la source d'une autre, qui était retranchée en silence au chargement suivant.
# Le témoin se charge À LA DEMANDE et reste en mémoire (`_temoin`) : son `.mbtiles` s'il en a un ; sinon le
# `.glb` lié qu'on lui a tranché (revenu de Blender) ; sinon le témoin calculé.

## Le `.mbtiles` d'une couche : le sien, sinon celui qu'elle aura — `<projet>_layer<id>.mbtiles`.
func _chemin_temoin_de(c: Dictionary) -> String:
	if str(c.get("temoin", "")) != "":
		return str(c["temoin"])
	var base := _projet.get_basename() if _projet != "" else "user://witness"
	return "%s_layer%s.mbtiles" % [base, str(c.get("id", "0"))]


func _glb_du_temoin(c: Dictionary) -> String:
	return _chemin_temoin_de(c).get_basename() + ".glb"


func _temoin_de(c: Dictionary) -> RefCounted:
	var deja = c.get("_temoin", null)
	if deja != null:
		return deja
	var t: RefCounted = null
	var chemin := str(c.get("temoin", ""))
	if chemin != "" and FileAccess.file_exists(chemin):
		var d = JSON.parse_string(FileAccess.get_file_as_string(chemin))
		if d is Dictionary:
			t = TL.depuis_dictionnaire(d)
	if t == null and _source_liee(c):
		t = TL.depuis_glb(str(c["source"]), _chemin_temoin_de(c).get_basename() + "_images")
	if t == null:
		if _temoin_calcule == null:
			_temoin_calcule = TL.depuis_le_temoin_calcule()
		t = _temoin_calcule.copie()
	c["_temoin"] = t
	return t


## La couche qui possède ce témoin, {} si aucune (supprimée). ⚠ PAS DE MÉTA « couche » SUR LE TÉMOIN : la
## couche garde son témoin, et le témoin qui garderait sa couche ferait un CYCLE — ni l'un ni l'autre ne
## serait jamais libéré, matériaux et textures compris (vu en fuite à la sortie de la fumée).
func _couche_du_temoin(t: RefCounted) -> Dictionary:
	for c in _couches:
		if c.get("_temoin", null) == t:
			return c
	return {}


## La source de la couche est-elle un `.glb` LIÉ (un témoin revenu de Blender) ? Retenu : 0,2 s de lecture.
func _source_liee(c: Dictionary) -> bool:
	if c.has("_lie"):
		return bool(c["_lie"])
	var s := str(c.get("source", ""))
	var lie: bool = s != "" and s != Projet.TEMOIN and s.get_extension().to_lower() in ["glb", "gltf"] \
		and FileAccess.file_exists(s) and not BM.tuiles_liees(s, [], []).is_empty()
	c["_lie"] = lie
	return lie


## D'où vient le témoin de la couche — ce que la liste en dit.
func _origine_du_temoin(c: Dictionary) -> String:
	if (str(c.get("temoin", "")) != "" and FileAccess.file_exists(str(c["temoin"]))) or _temoins_sales.has(c.get("_temoin")):
		return "modelled"
	if _source_liee(c):
		return "from Blender (linked)"
	var s := str(c.get("source", ""))
	if s != "" and s != Projet.TEMOIN:
		return "unlinked work"
	return "computed witness"


## Écrit le témoin d'une couche : son `.mbtiles` et son `.glb` lié. Rend "" ou la raison.
func _enregistrer_temoin(c: Dictionary) -> String:
	var t = c.get("_temoin", null)
	if t == null:
		return ""
	if str(c.get("temoin", "")) == "":
		c["temoin"] = _chemin_temoin_de(c)
	var f := FileAccess.open(str(c["temoin"]), FileAccess.WRITE)
	if f == null:
		return "cannot write %s" % c["temoin"]
	f.store_string(JSON.stringify(t.vers_dictionnaire()))
	f.close()
	var raison: String = t.vers_glb(_glb_du_temoin(c))
	if raison != "":
		_dire("[color=#e0603c]The witness of « %s » could not be saved:[/color] %s" % [c["nom"], raison])
	else:
		_suivre_son_temoin(c)
	_oublier_la_vignette(c)
	_enregistrer()
	return raison


## LE MONDE SUIT SON TÉMOIN (Jordan, 1er octobre 2026 : « le monde ne se met pas à jour avec les changements de
## son witness ») : chaque fois que le témoin d'une couche est écrit, la couche reprend ses tuiles — sans
## bouton. ⚠ C'EST LA MÊME ROUTE QUE LE TRANCHAGE (`librairie_depuis_glb` sur son `.glb` lié), et elle ne coûte
## que la relecture : un témoin lié se relit tuile par tuile, sans trancher.
## ⚠ Une couche habillée par un travail EXTERNE non lié (un .glb d'un seul tenant) le garde : son témoin n'est
## pas sa source. Une couche sans tuiles, ou sur le témoin calculé, passe à son propre témoin.
func _suivre_son_temoin(c: Dictionary) -> void:
	var i: int = _couches.find(c)
	var propre := _glb_du_temoin(c)
	var s := str(c.get("source", ""))
	if i < 0 or (s != "" and s != Projet.TEMOIN and s != propre):
		return
	var bilan: Dictionary = BM.librairie_depuis_glb(propre)
	var lot: MeshLibrary = bilan.get("lot", null)
	if lot == null or not bilan.get("lie", false):
		return
	Projet.mettre_en_cache(lot, propre)
	c["source"] = propre
	_vue.couche(i).lot = lot


## Étape 3 : la couche active prend les tuiles de SON témoin. ⚠ Un témoin jamais modelé est le témoin
## calculé : il se tranche comme tel (son lot est en cache, commun à toutes les couches qui l'ont).
func _trancher_temoin_de_la_couche() -> void:
	if _vue.monde() == null:
		return
	var c: Dictionary = _couches[_active]
	if _origine_du_temoin(c) == "computed witness":
		await _trancher_temoin()
		return
	_temoin_de(c)
	_temoins_sales[c["_temoin"]] = true
	_enregistrer_le_temoin_modele()
	var glb := _glb_du_temoin(c)
	var bilan: Dictionary = await _trancher_source(glb)
	_poser_lot(bilan, "the layer's witness", glb, "[b]Sliced from the witness of « %s »[/b]\n" % c["nom"])


## « Copy witness » : une couche neuve dont le témoin est une COPIE de celui de la couche active.
func _copier_le_temoin() -> void:
	var origine: Dictionary = _couches[_active]
	var t: RefCounted = _temoin_de(origine).copie()
	var i := _ajouter_couche(Projet.couche("%s (copy)" % origine["nom"]))
	var c: Dictionary = _couches[i]
	c["_temoin"] = t
	_enregistrer_temoin(c)
	_activer(i)
	_dire(("[b]New layer « %s »[/b] — its witness is a copy of « %s »'s: sculpt it (Witness) without touching "
		+ "the original, then slice it (step 3).") % [c["nom"], origine["nom"]])


## La vignette d'une couche : son témoin, photographié une fois, reprise quand il change.
var _vignettes: Node
## ⚠ PAS `static` : un maillage statique survit à la fermeture avec son matériau — vu en fuite dans la fumée.
var _maillage_calcule: Mesh


func _vignette_de(c: Dictionary) -> Texture2D:
	var deja = c.get("_vignette", null)
	if deja != null:
		return deja
	if _vignettes == null:
		_vignettes = Node.new()
		_vignettes.name = "Vignettes"
		add_child(_vignettes)
	var mesh: Mesh
	if _origine_du_temoin(c) == "computed witness" and c.get("_temoin", null) == null:
		if _maillage_calcule == null:
			_maillage_calcule = BM.maillage_moitie(0)
		mesh = _maillage_calcule
	else:
		mesh = _temoin_de(c).assemble()
	var vue := SubViewport.new()
	vue.size = Vector2i(84, 56)
	vue.own_world_3d = true
	vue.render_target_update_mode = SubViewport.UPDATE_ONCE
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.FOND_VUE
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8892a4")
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	vue.add_child(we)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-48, -34, 0)
	vue.add_child(soleil)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	vue.add_child(mi)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 17.0
	var direction := Vector3(1.0, 0.8, 1.3).normalized()
	var centre := Vector3.ONE * float(BM.COTE) * 0.5
	cam.transform = Transform3D(Basis.looking_at(-direction, Vector3.UP), centre + direction * 30.0)
	vue.add_child(cam)
	_vignettes.add_child(vue)
	c["_vue_vignette"] = vue
	c["_vignette"] = vue.get_texture()
	return c["_vignette"]


func _oublier_la_vignette(c: Dictionary) -> void:
	var vue = c.get("_vue_vignette", null)
	if vue != null and is_instance_valid(vue):
		vue.queue_free()
	c["_vue_vignette"] = null
	c["_vignette"] = null


## L'état d'une couche, en une ligne : ses cases, et si ses tuiles viennent de son témoin tel qu'il est.
func _etat_de(i: int) -> String:
	var c: Dictionary = _couches[i]
	var n: int = (_vue.couche(i).get_node("Cases") as GridMap).get_used_cells().size()
	var s := str(c.get("source", ""))
	var etat := ""
	if s == "":
		etat = "not sliced"
	elif s == _glb_du_temoin(c):
		# L'empreinte du lot POSÉ contre celle du fichier — sans relire le cache du disque à chaque rafraîchissement.
		var lot: MeshLibrary = _vue.couche(i).lot
		var a_jour: bool = lot != null and str(lot.get_meta("empreinte", "")) == Projet.empreinte(s) \
			and not _temoins_sales.has(c.get("_temoin"))
		etat = "sliced" if a_jour else "witness changed · slice again"
	elif s == Projet.TEMOIN:
		etat = "witness changed · slice again" if _origine_du_temoin(c) == "modelled" else "sliced"
	else:
		etat = "tiles from " + s.get_file()
	return "%d cells · %s" % [n, etat]


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
	if quoi == "tileset" or quoi == "monde":
		_dialogue.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_dialogue.title = "Export the tileset into…" if quoi == "tileset" else "Export the world into…"
		_dialogue.current_file = ""
	elif quoi == "patron":
		_dialogue.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_dialogue.add_filter("*.png", "PNG image")
		_dialogue.title = "Export the UV layout"
		_dialogue.current_file = "uv_layout.png"
	elif quoi == "texture":
		_dialogue.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialogue.add_filter("*.png, *.jpg, *.jpeg, *.webp", "Image")
		_dialogue.title = "A tileable image for the material"
		_dialogue.current_file = ""
	elif quoi in ["ouvrir", "enregistrer"]:
		_dialogue.add_filter("*." + Projet.EXTENSION, "MarchingBlocks project")
		_dialogue.title = "Open a project" if quoi == "ouvrir" else "Save the project as"
		_dialogue.current_file = _projet.get_file() if quoi == "enregistrer" else ""
	else:
		# ⚠ LE TÉMOIN PART EN .glb LIÉ (charte §3, 30 septembre 2026) : l'OBJ n'a pas de copies liées.
		# Le travail revient en .glb — ou en .obj, qui se tranche alors comme avant.
		if quoi == "exporter":
			_dialogue.add_filter("*.glb", "glTF binary (linked witness)")
		else:
			_dialogue.add_filter("*.glb, *.obj", "Sculpted work")
		_dialogue.title = "Export the witness" if quoi == "exporter" else "Import the work"
		_dialogue.current_file = "marchingblocks_witness.glb" if quoi == "exporter" else ""
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
		"monde":
			_exporter_le_monde(fichier)
		"texture":
			_retoucher("texture", fichier)
			_inscrire_les_retouches()
		"patron":
			_exporter_le_patron(fichier)


## ⚠ IL REFUSE si le témoin est en faute : sculpter des jours sur une base fausse coûte bien plus qu'un
## refus.
func _exporter(fichier: String) -> void:
	var fautes: Array = BM.anomalies()
	if not fautes.is_empty():
		_dire("[color=#e0603c]REFUSED — %d problem(s) in the witness:[/color]\n  %s"
			% [fautes.size(), "\n  ".join(PackedStringArray(fautes.slice(0, 6)))])
		return
	if fichier.get_extension().to_lower() != "glb":
		fichier = fichier.get_basename() + ".glb"
	await _attendre("Exporting the witness", fichier.get_file())
	# ⚠ LE TÉMOIN DE LA COUCHE ACTIVE : jamais modelé, c'est le témoin calculé (légende, UV canoniques) ;
	# sinon le sien, tel qu'on l'a sculpté.
	var c_export: Dictionary = _couches[_active]
	var raison: String = BM.exporter_le_temoin_lie(fichier) if _origine_du_temoin(c_export) == "computed witness" \
		else _temoin_de(c_export).vers_glb(fichier)
	_fin_attente()
	if raison != "":
		_dire("[color=#e0603c]Export failed:[/color] %s" % raison)
		return
	var total: int = MB.pieces_a_sculpter().size()
	var dehors: int = MB.exterieures_a_sculpter().size()
	_dire(("[color=#b4bd85][b]Witness written[/b][/color] → %s\n"
		+ "One block of %d × %d × %d · %d tiles to sculpt (%d classes, %d also in open air), shown as "
		+ "%d linked copies.\n"
		+ "Sculpt ANY copy of a tile: every copy follows. What you see is what the world will show.\n"
		+ "No normals: Blender opens it FLAT-shaded. Import with « Merge Vertices » to weld the colour "
		+ "borders inside a tile.\n\n"
		+ "[color=#f2ca79]Do not MOVE, rotate or Join the objects[/color] — each tile is identified by "
		+ "its POSITION when it comes back. A copy sculpted on its own is reported.\n"
		+ "Do not change WHICH cells are full: the filling fixes the tile classes.")
		% [fichier, BM.COTE, BM.COTE, BM.COTE, total + dehors, total, dehors,
		BM.occurrences_du_temoin(0).size()])


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
	# ⚠ UN TÉMOIN LIÉ SE DIT AUTREMENT (charte §3) : ses copies montrent la tuile choisie partout, donc il
	# n'est pas identique au témoin continu, et compter ses sommets « déplacés » mentirait dès l'export.
	# Ce qui compte, c'est combien de copies ont été lues, et lesquelles divergent.
	var erreurs_liees: Array = []
	var lie: Dictionary = BM.tuiles_liees(fichier, erreurs_liees, [])
	var ecart_dit: String
	if not lie.is_empty():
		ecart_dit = "Linked witness: %d copies of %d tiles, read tile by tile." \
			% [int(lie["occurrences"]), (lie["pieces"] as Dictionary).size()]
		if not erreurs_liees.is_empty():
			ecart_dit += ("\n[color=#e0603c]%d tile(s) whose copies no longer agree[/color] (a copy sculpted "
				+ "on its own, moved or rotated — the most common one will be kept):\n  %s") \
				% [erreurs_liees.size(), "\n  ".join(PackedStringArray(erreurs_liees.slice(0, 5)))]
	else:
		var ecart: int = BM.ecart_au_temoin(travail)
		ecart_dit = ("[color=#f2ca79]No vertex moved compared to the witness: slicing will give "
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
	# ⚠ UN TRAVAIL LIÉ (revenu de Blender) DEVIENT LE TÉMOIN DE LA COUCHE (Jordan, 30 septembre 2026) : éditable
	# ensuite dans l'appli, avec sa peinture. L'ancien témoin de la couche est gardé à côté (« .previous »).
	var c: Dictionary = _couches[_active]
	var images := _chemin_temoin_de(c).get_basename() + "_images"
	var lu: RefCounted = TL.depuis_glb(chemin, images) if chemin.get_extension().to_lower() in ["glb", "gltf"] else null
	if lu != null:
		var ancien := _chemin_temoin_de(c)
		if FileAccess.file_exists(ancien):
			DirAccess.copy_absolute(ancien, ancien.get_basename() + ".previous.mbtiles")
		c["_temoin"] = lu
		c.erase("_lie")
		_temoins_sales[lu] = true
		_enregistrer_le_temoin_modele()
		if _modeleur.temoin != null:
			_modeleur.charger_temoin(lu, _occurrence_de_depart(lu))
		var propre := _glb_du_temoin(c)
		var bilan_lie: Dictionary = await _trancher_source(propre)
		_poser_lot(bilan_lie, "work", propre, ("[b]%s became the witness of « %s »[/b] — edit it in Witness, "
			+ "slice it again in step 3.\n") % [chemin.get_file(), c["nom"]])
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

	var texte := entete
	texte += "[color=#b4bd85][b]Library ready[/b][/color] (%s → layer « %s ») — %d tile(s) for %d classes" \
		% [quoi, _couches[_active]["nom"], lot.get_item_list().size(), MB.pieces_a_sculpter().size()]
	if bilan.get("lie", false):
		texte += " — read tile by tile from %d linked copies, nothing sliced" % int(bilan.get("occurrences", 0))
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
	var op: Dictionary = Etages.operer(_occupees(), _vue.etage, quoi, _vue.selection)
	var n := _appliquer(op, quoi)
	if n == 0:
		if quoi == "face":
			_dire("[i]Nothing to extend on %s.[/i] No cell has matter behind it and air in front." % sur)
		else:
			_dire("[i]Nothing to do on %s.[/i] It is empty, or the operation found nothing to change." % sur)
		return
	if quoi == "face":
		# La sélection suit, et l'étage aussi quand on monte ou descend : cliquer encore recommence.
		var sens: Vector3i = op["sens"]
		if not _vue.selection.is_empty():
			_vue.regler_selection(op["selection"])
		if sens.y != 0:
			_compteur_etage.value = _vue.etage + sens.y
		_dire(("[b]Extend facing[/b] %s on %s — %d cell(s) changed. [i]Click again to keep going; "
			+ "Ctrl+Z undoes the cells.[/i]") % [_nom_du_sens(sens), sur, n])
		return
	_dire("[b]%s[/b] on %s — %d cell(s) changed. [i]Ctrl+Z undoes it.[/i]" % [quoi, sur, n])


func _nom_du_sens(d: Vector3i) -> String:
	return {Vector3i.UP: "up", Vector3i.DOWN: "down", Vector3i(1, 0, 0): "toward X +",
		Vector3i(-1, 0, 0): "toward X −", Vector3i(0, 0, 1): "toward Z +",
		Vector3i(0, 0, -1): "toward Z −"}.get(d, "")


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
	if r.has("dossier"):
		Associations.marquer_dossier(str(r["dossier"]))
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


## LE MONDE ENTIER, toutes couches, vers les greffons (`format_monde.gd`).
func _exporter_le_monde(dossier: String) -> void:
	var couches: Array = []
	for i in _couches.size():
		var massif: Node = _vue.couche(i)
		couches.append({"nom": _couches[i]["nom"], "visible": _couches[i]["visible"],
			"source": _couches[i]["source"], "lot": massif.lot,
			"cases": (massif.get_node("Cases") as GridMap).get_used_cells()})
	await _attendre("Exporting the world", "%d layer(s)" % couches.size())
	var version := "MarchingBlocks %s" % ProjectSettings.get_setting("application/config/version", "")
	var nom: String = _projet.get_file().get_basename() if _projet != "" else "world"
	var r: Dictionary = FormatMonde.exporter(couches, dossier, nom, version)
	if r.has("dossier"):
		Associations.marquer_dossier(str(r["dossier"]))
		for sous in DirAccess.get_directories_at(str(r["dossier"])):
			Associations.marquer_dossier(str(r["dossier"]).path_join(sous))
	_fin_attente()
	if r.has("erreur"):
		_dire("[color=#e0603c]Export failed:[/color] %s" % r["erreur"])
		return
	var texte := ("[color=#b4bd85][b]World written[/b][/color] → %s\n%d layer(s), %d tileset(s). In your "
		+ "engine: [b]Import MarchingBlocks world[/b].") % [r["dossier"], r["couches"], r["jeux"]]
	if not (r["sans_tuiles"] as Array).is_empty():
		texte += ("\n\n[color=#f2ca79]%d layer(s) have no tiles yet[/color] — their cells travel, the engine "
			+ "shows them without tiles: %s") % [(r["sans_tuiles"] as Array).size(),
			", ".join(PackedStringArray(r["sans_tuiles"]))]
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
	var id := str(etat.get("id", ""))
	for autre in _couches:
		if str(autre.get("id", "")) == id:
			id = ""
	_couches.append({"nom": etat["nom"], "source": etat["source"], "visible": etat["visible"],
		"temoin": str(etat.get("temoin", "")), "id": id if id != "" else _nouvel_id()})
	return _couches.size() - 1


## Un identifiant de couche libre : le plus grand, plus un. ⚠ Il nomme les fichiers de son témoin : il ne
## change jamais, même si la couche change de nom.
func _nouvel_id() -> String:
	var n := 0
	for c in _couches:
		n = maxi(n, int(str(c.get("id", "0"))))
	return str(n + 1)


func _activer(i: int) -> void:
	_active = clampi(i, 0, _couches.size() - 1)
	_vue.activer(_active)
	_suivre_le_temoin_de_la_couche()
	_rafraichir_couches()
	_dire_l_etage()
	_enregistrer()


## LE TÉMOIN SUIT LA COUCHE ACTIVE : si le modeleur en tient un, il prend celui de la nouvelle couche (le
## geste en cours est abandonné, les témoins modifiés sont écrits d'abord). La planche suit aussi.
func _suivre_le_temoin_de_la_couche() -> void:
	if _ouverture or _couches.is_empty():
		return
	if _modeleur.temoin != null:
		var t: RefCounted = _temoin_de(_couches[_active])
		if t != _modeleur.temoin:
			if _modeleur.modal != "":
				_modeleur.annuler()
			_enregistrer_le_temoin_modele()
			_modeleur.charger_temoin(t, _occurrence_de_depart(t))
			_redire_les_materiaux()
	_legende_formes.reconstruire_tuiles()


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
		# ⚠ UNE COUCHE = UN TÉMOIN + UN MONDE PEINT (Jordan, 30 septembre 2026) : la vignette de SON témoin, d'où
		# il vient, et l'état de ses tuiles (tranchées depuis ce témoin tel qu'il est, ou à retrancher).
		var vignette := TextureRect.new()
		vignette.texture = _vignette_de(c)
		vignette.custom_minimum_size = Vector2(56, 38)
		vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		vignette.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ligne.add_child(vignette)
		var choix := Button.new()
		choix.toggle_mode = true
		choix.button_group = groupe
		choix.button_pressed = i == _active
		choix.focus_mode = Control.FOCUS_NONE
		choix.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choix.clip_text = true
		choix.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choix.custom_minimum_size = Vector2(0, 52)
		choix.text = "%s\n%s\n%s" % [c["nom"], _origine_du_temoin(c), _etat_de(i)]
		choix.add_theme_font_size_override("font_size", 11)
		choix.tooltip_text = ("Make this layer active: Witness edits ITS witness, World paints ITS cells.\n"
			+ "Witness: %s\nTiles: %s") % [_origine_du_temoin(c), c["source"] if c["source"] != "" else "none yet"]
		choix.pressed.connect(_activer.bind(i))
		ligne.add_child(choix)
		_liste_couches.add_child(ligne)
	if _nom_couche != null and not _couches.is_empty():
		_nom_couche.text = _couches[_active]["nom"]
	if _etiquette_temoin_couche != null and not _couches.is_empty():
		_etiquette_temoin_couche.text = "Witness of layer « %s » — %s" % [_couches[_active]["nom"],
			_origine_du_temoin(_couches[_active])]
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
	# ⚠ UN DOUBLE-CLIC SUR UN .mbproj LANCE L'APPLI AVEC SON CHEMIN (`Associations`) : il l'emporte sur le dernier
	# projet ouvert.
	var passe: String = Associations.projet_en_argument(OS.get_cmdline_args())
	if passe != "" and await _ouvrir(passe):
		return
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
	_temoins_sales.clear()
	_modeleur.temoin = null
	_modeleur.maillage = null
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
	# ⚠ UN PROJET D'AVANT LE 30 SEPTEMBRE 2026 a UN témoin modélisé (`<projet>_witness.mbtiles`) : il est confié à
	# la couche qui le tranchait (sa source est `<projet>_witness.glb`), sinon à la couche active. Rien n'est
	# copié ni écrasé : la couche le désigne.
	var ancien := _projet.get_basename() + "_witness.mbtiles"
	if FileAccess.file_exists(ancien) and not _couches.any(func(c): return str(c.get("temoin", "")) != ""):
		var cible: int = etat["active"]
		for k in _couches.size():
			if str(_couches[k]["source"]) == _projet.get_basename() + "_witness.glb":
				cible = k
		_couches[cible]["temoin"] = ancien
		notes.append("The modelled witness of this project now belongs to layer « %s »." % _couches[cible]["nom"])
	_ouverture = false
	_activer(etat["active"])
	_retenir_le_projet()
	_aller_a("monde")
	_dire("[color=#b4bd85][b]Project opened[/b][/color] ← %s\n%d layer(s). [i]Every change is saved as you "
		% [chemin, _couches.size()] + "go — no need for Ctrl+S.[/i]%s"
		% ("" if notes.is_empty() else "\n\n" + "\n".join(PackedStringArray(notes))))
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
		_dire_enregistre("echec")
		return
	f.store_string(Projet.vers_texte(sorties, _active))
	f.close()
	var e: int = DirAccess.rename_absolute(provisoire, _projet)
	if e != OK:
		_dire("[color=#e0603c]Project NOT saved[/color] — %s could not replace the old file (error %d)."
			% [_projet, e])
		_dire_enregistre("echec")
		return
	# Un témoin modifié attend encore sa seconde : l'état reste « Saving… » jusqu'à ce qu'il soit écrit.
	_dire_enregistre("en_cours" if _minuterie_temoin != null and not _minuterie_temoin.is_stopped() else "enregistre")


## LES FICHIERS DANS WINDOWS : au premier lancement (et quand l'exécutable a changé de place ou de version),
## l'appli inscrit ses icônes et le double-clic (`Associations`). ⚠ JAMAIS DEPUIS L'ÉDITEUR NI LES TESTS : c'est
## l'exécutable de Godot qui ouvrirait alors les projets — seul l'exécutable exporté (`template`) s'inscrit.
func _inscrire_les_fichiers() -> void:
	var reglages := ConfigFile.new()
	reglages.load(REGLAGES)
	var livre: bool = OS.get_name() == "Windows" and OS.has_feature("template")
	if _case_associations != null:
		_case_associations.disabled = not livre
		_case_associations.set_pressed_no_signal(livre and not bool(reglages.get_value("associations", "refus", false)))
		if not livre:
			_case_associations.tooltip_text += "\n(Only in the installed app, not from the Godot editor.)"
	if not livre:
		return
	var exe := OS.get_executable_path()
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	if not Associations.a_inscrire(reglages, exe, version):
		return
	var raison: String = Associations.inscrire(exe)
	if raison != "":
		push_warning("MarchingBlocks: file icons not registered — %s" % raison)
		return
	reglages.set_value("associations", "exe", exe)
	reglages.set_value("associations", "version", version)
	reglages.save(REGLAGES)


## La case de Project : retirer (et s'en souvenir), ou remettre.
func _regler_les_associations(oui: bool) -> void:
	if not (OS.get_name() == "Windows" and OS.has_feature("template")):
		return
	var reglages := ConfigFile.new()
	reglages.load(REGLAGES)
	var raison: String = Associations.inscrire(OS.get_executable_path()) if oui else Associations.desinscrire()
	reglages.set_value("associations", "refus", not oui)
	reglages.set_value("associations", "exe", OS.get_executable_path() if oui else "")
	reglages.set_value("associations", "version", str(ProjectSettings.get_setting("application/config/version", "")) if oui else "")
	reglages.save(REGLAGES)
	_dire(("[color=#e0603c]File icons could not be changed:[/color] %s" % raison) if raison != ""
		else ("[b]File icons & double-click on[/b] — .mbproj opens in MarchingBlocks." if oui
		else "[b]File icons & double-click removed[/b] from your Windows account. Tick the box to bring them back."))


## Ctrl+S : écrit TOUT DE SUITE ce qui attendait (les témoins modifiés, le projet), et dit que c'était inutile.
func _enregistrer_tout() -> void:
	if _minuterie_temoin != null:
		_minuterie_temoin.stop()
	_enregistrer_le_temoin_modele()
	_enregistrer()
	_dire(("[color=#b4bd85][b]Everything is saved[/b][/color] — MarchingBlocks saves after every change, so "
		+ "there is no need for Ctrl+S.\n[i]« Save as » (Project) puts the project where you want: %s[/i]")
		% _projet)


## Le témoin d'enregistrement de la barre de titre : "enregistre", "en_cours" ou "echec".
func _dire_enregistre(etat: String) -> void:
	if _etat_enregistre == null:
		return
	match etat:
		"en_cours":
			_etat_enregistre.text = "● Saving…"
			_etat_enregistre.add_theme_color_override("font_color", Palette.AMBRE)
		"echec":
			_etat_enregistre.text = "⚠ Not saved"
			_etat_enregistre.add_theme_color_override("font_color", Color("#e0603c"))
		_:
			_etat_enregistre.text = "✓ Saved"
			_etat_enregistre.add_theme_color_override("font_color", Palette.OLIVE)


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
		# ⚠ CTRL+S RÉPOND (30 septembre 2026) : il ne sert à rien, mais un client le tape par réflexe, et un
		# raccourci muet lui ferait croire qu'il n'a rien enregistré. On écrit ce qui attendait, et on le DIT.
		if k.keycode == KEY_S and not k.shift_pressed:
			_enregistrer_tout()
			get_viewport().set_input_as_handled()
			return
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
	if k != null and k.pressed and _atelier == "witness" and _touche_du_temoin(k):
		get_viewport().set_input_as_handled()
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


## LES TOUCHES DE L'ATELIER WITNESS — lues dans `_input`, AVANT l'interface : Tab, Entrée, Espace et les
## chiffres y sont des gestes, pas du déplacement de focus. ⚠ Ctrl+Z / Ctrl+Y n'y sont PAS pris : ils
## descendent à `_unhandled_key_input`, qui tient l'historique de toute l'appli.
func _touche_du_temoin(k: InputEventKey) -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return false
	if k.keycode == KEY_TAB and not k.echo and _modeleur.modal == "":
		_regler_edition(not _vue.edition)
		return true
	# Les vues du pavé numérique, en édition comme hors édition (sauf pendant un geste : on tape un nombre).
	if _modeleur.modal == "":
		match k.keycode:
			KEY_KP_1:
				_vue.vue_de("face", k.ctrl_pressed)
				return true
			KEY_KP_3:
				_vue.vue_de("droite", k.ctrl_pressed)
				return true
			KEY_KP_7:
				_vue.vue_de("dessus", k.ctrl_pressed)
				return true
			KEY_KP_5:
				_vue.basculer_ortho()
				return true
			KEY_KP_PERIOD:
				_cadrer_la_selection()
				return true
	if not _vue.edition:
		return false
	if k.ctrl_pressed and k.keycode in [KEY_Z, KEY_Y]:
		return false
	var pris: bool = _modeleur.touche(k)
	if pris:
		_bouton_prop.set_pressed_no_signal(_modeleur.proportionnel)
		for m in _boutons_selmode:
			(_boutons_selmode[m] as Button).set_pressed_no_signal(m == _modeleur.mode_sel)
	return pris


func _dire(texte: String) -> void:
	if _rapport != null:
		_rapport.text = texte
