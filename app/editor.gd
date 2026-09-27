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
## ── LES DEUX ATELIERS (« rooms » de SoluTiles) ───────────────────────────────────────────────────────
##
##   • WITNESS — le témoin, ou le travail importé, qu'on fait tourner. L'aller-retour avec l'artiste.
##   • TEST WORLD — un monde qu'on peint case par case avec les tuiles tranchées. C'est ce que faisait
##     le GridMap de l'éditeur Godot ; ici il faut notre propre pinceau (`vue.gd`).
##
## ⚠ **LE CŒUR N'EST PAS RECOPIÉ.** Tout passe par `addons/undermend/` — le modèle, le témoin, le
## trancheur, le PBR, les opérations d'étage — exactement comme le greffon. Deux écrans, une seule
## vérité : c'est ce qui garantit que le logiciel fait CE QUE FAIT le greffon, et pas une imitation.

const MB := preload("res://addons/undermend/marching_blocks.gd")
const BM := preload("res://addons/undermend/blocs_maitres.gd")
const RP := preload("res://addons/undermend/repli_procedural.gd")
const PBR := preload("res://addons/undermend/pbr_monde.gd")
const Etages := preload("res://addons/undermend/etages.gd")
const Palette := preload("res://app/palette.gd")
const Section := preload("res://app/section.gd")
const Panneau := preload("res://app/panneau.gd")
const Vue := preload("res://app/vue.gd")

const PART_ECRAN := 0.95
const LARGEUR_GAUCHE := 272
const LARGEUR_DROITE := 272
const SECONDES_CONSEIL := 7.0

## Les conseils du bandeau. ⚠ Chacun dit un GESTE ou une PROMESSE vérifiable, jamais un slogan.
const CONSEILS: Array[String] = [
	"One witness block carries every tile. Sculpt it, bring it back, paint with it.",
	"The witness is proven complete: 52 tiles, not one missing, not one extra.",
	"Test world: left click paints a cell, right click erases it. Ctrl+Z undoes a whole stroke.",
	"Middle mouse turns the view, Shift + middle slides it, the wheel zooms.",
	"A red cube is a tile your library does not have. Nothing is ever filled in for you.",
	"Keep your relief inside its cell: the slicer cuts straight through the cell centres.",
	"Import your work to SEE what the slicer will read, before slicing anything.",
	"The six colours of the witness are six tile families: open air or underground, floor, wall, ceiling.",
	"World-space PBR follows the tiles: no seam where the slicer cut.",
]

var _vue: Vue
var _gauche: Panneau
var _droite: Panneau
var _attente: PanelContainer
var _attente_titre: Label
var _attente_note: Label
var _bandeau: Label
var _conseil := 0
var _ecoule := 0.0

var _boutons_atelier := {}
var _atelier := "witness"
var _sections_monde: Array[Control] = []

var _pbr: CheckBox
var _matiere_pbr: ShaderMaterial
var _etiquette_vue: Label
var _etiquette_etage: Label
var _rapport: RichTextLabel
var _dialogue: FileDialog
var _action_fichier := ""

## Le `.glb` importé, RELU au moment de trancher : l'artiste a pu réenregistrer entre-temps.
var _travail := ""
var _travail_maillage: ArrayMesh

var _histoire := UndoRedo.new()
## Le coup en cours : {case: [avant, après]}.
var _coup := {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_regler_fenetre()
	_batir()
	_montrer_temoin()
	_aller_a("witness")
	_dire("[i]Look at the witness, export it for your artist, or open the Test world and paint.[/i]")
	await get_tree().process_frame
	_regler_fenetre()


## ⚠ LA FENÊTRE OCCUPE 95 % DE L'ÉCRAN, CENTRÉE — comme SoluTiles, et reposée après la première image :
## selon la façon de lancer, la taille demandée dans `_ready` peut être écrasée par celle du projet.
## ⚠ Et l'échelle de contenu est COUPÉE : le projet hérite d'un réglage de jeu en pixel art (viewport
## 640×320 étiré au multiple entier), qui rendrait une interface floue et énorme.
func _regler_fenetre() -> void:
	var fenetre: Window = get_window()
	if fenetre == null:
		return
	fenetre.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	if fenetre.mode != Window.MODE_WINDOWED:
		fenetre.mode = Window.MODE_WINDOWED
	var utile: Rect2i = DisplayServer.screen_get_usable_rect(fenetre.current_screen)
	var cible := Vector2i(int(utile.size.x * PART_ECRAN), int(utile.size.y * PART_ECRAN))
	fenetre.size = cible
	fenetre.position = utile.position + (utile.size - cible) / 2
	fenetre.title = "MarchingBlocks"


func _process(delta: float) -> void:
	_ecoule += delta
	if _ecoule < SECONDES_CONSEIL:
		return
	_ecoule = 0.0
	_bandeau.text = CONSEILS[_conseil]
	_conseil = (_conseil + 1) % CONSEILS.size()


# ── LA CONSTRUCTION DE L'ÉCRAN ───────────────────────────────────────────────────────────────────────

func _batir() -> void:
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
	_vue.case_touchee.connect(_case_touchee)
	_vue.coup_fini.connect(_coup_fini)
	corps.add_child(_vue)

	_gauche = _panneau(corps, true, LARGEUR_GAUCHE)
	_batir_gauche(_gauche.get_meta("pile"))
	_droite = _panneau(corps, false, LARGEUR_DROITE)
	_batir_droite(_droite.get_meta("pile"))
	_batir_attente(corps)

	_dialogue = FileDialog.new()
	_dialogue.access = FileDialog.ACCESS_FILESYSTEM
	_dialogue.use_native_dialog = true
	_dialogue.add_filter("*.glb", "glTF binary")
	_dialogue.file_selected.connect(_fichier_choisi)
	add_child(_dialogue)


func _barre_titre() -> Control:
	var barre := PanelContainer.new()
	barre.custom_minimum_size = Vector2(0, 34)
	var style := Palette.fond(Palette.BARRE_TITRE, 0, 0)
	style.content_margin_left = 14
	style.content_margin_right = 14
	barre.add_theme_stylebox_override("panel", style)
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 12)
	barre.add_child(ligne)

	var marque := Label.new()
	marque.text = "MarchingBlocks"
	marque.add_theme_font_size_override("font_size", 16)
	marque.add_theme_color_override("font_color", Palette.OLIVE)
	ligne.add_child(marque)
	var version := Label.new()
	# ⚠ LA VERSION VIT DANS `project.godot` ET NULLE PART AILLEURS (leçon de SoluTiles).
	version.text = "v" + str(ProjectSettings.get_setting("application/config/version", "0.1.0"))
	version.add_theme_color_override("font_color", Palette.GRIS)
	version.add_theme_font_size_override("font_size", 12)
	ligne.add_child(version)
	var devise := Label.new()
	devise.text = "Sculpt one block. Get every tile."
	devise.add_theme_color_override("font_color", Palette.GRIS)
	devise.add_theme_font_size_override("font_size", 12)
	ligne.add_child(devise)

	_bandeau = Label.new()
	_bandeau.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bandeau.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bandeau.clip_text = true
	_bandeau.add_theme_color_override("font_color", Palette.AMBRE)
	_bandeau.add_theme_font_size_override("font_size", 12)
	_bandeau.text = CONSEILS[0]
	_conseil = 1
	ligne.add_child(_bandeau)
	return barre


## Un panneau posé sur la vue, ancré à gauche ou à droite sur TOUTE la hauteur.
## ⚠ LES QUATRE ANCRES, pas deux (leçon de SoluTiles) : ancrer seulement le haut laisse le panneau à sa
## taille minimale et coupe ce qui dépasse.
func _panneau(parent: Control, a_gauche: bool, largeur: int) -> Panneau:
	var p := Panneau.new()
	p.add_theme_stylebox_override("panel", Palette.fond(Palette.PANNEAU, 0, 12))
	p.anchor_top = 0.0
	p.anchor_bottom = 1.0
	p.anchor_left = 0.0 if a_gauche else 1.0
	p.anchor_right = 0.0 if a_gauche else 1.0
	p.offset_left = 0.0 if a_gauche else -largeur
	p.offset_right = largeur if a_gauche else 0.0
	parent.add_child(p)
	var defile := ScrollContainer.new()
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(defile)
	var pile := VBoxContainer.new()
	pile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pile.add_theme_constant_override("separation", 14)
	defile.add_child(pile)
	p.set_meta("pile", pile)
	return p


func _petit_titre(texte: String) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", 11)
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


func _bouton(texte: String, infobulle: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.tooltip_text = infobulle
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 32)
	b.pressed.connect(action)
	return b


func _batir_gauche(pile: VBoxContainer) -> void:
	pile.add_child(_petit_titre("WORKSPACE"))
	var ateliers := HBoxContainer.new()
	var groupe := ButtonGroup.new()
	for a in [["witness", "Witness"], ["monde", "Test world"]]:
		var b := Button.new()
		b.text = a[1]
		b.toggle_mode = true
		b.button_group = groupe
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_aller_a.bind(a[0]))
		ateliers.add_child(b)
		_boutons_atelier[a[0]] = b
	pile.add_child(ateliers)

	var temoin := Section.new("Witness")
	pile.add_child(temoin)
	_pbr = CheckBox.new()
	_pbr.text = "World-space PBR textures"
	_pbr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if PBR.disponible():
		_pbr.tooltip_text = ("One full PBR set per colour — albedo, normal, AO, roughness, height (POM) — "
			+ "projected in WORLD space, so the tiles meet without seams.\nApplies to the witness and "
			+ "to the tiles sliced from it. Your imported work keeps its own materials.")
	else:
		_pbr.disabled = true
		_pbr.tooltip_text = "The PBR textures are not installed."
	_pbr.toggled.connect(func(_v: bool) -> void: _habiller())
	temoin.contenu.add_child(_pbr)
	_etiquette_vue = _texte("showing: the computed witness", 11, Palette.GRIS)
	temoin.contenu.add_child(_etiquette_vue)
	temoin.contenu.add_child(_legende())
	temoin.contenu.add_child(_bouton("Show the witness", "Back to the computed witness.",
		func() -> void: _travail_vu(false)))

	var echange := Section.new("Artist round trip")
	pile.add_child(echange)
	echange.contenu.add_child(_bouton("Export the witness…",
		"Writes the witness as ONE .glb for Blender.\nDo not MOVE it: its position identifies it "
		+ "when it comes back, not its name.\nTiles are already shrunk to half their cell, to show "
		+ "the margin you have.", func() -> void: _demander("exporter")))
	echange.contenu.add_child(_bouton("Import the work…",
		"Reads the sculpted .glb and SHOWS it, as the slicer will read it.\nNothing is sliced yet.",
		func() -> void: _demander("importer")))

	var aide := Section.new("Controls", false)
	pile.add_child(aide)
	aide.contenu.add_child(_texte("Wheel — zoom\nMiddle drag — turn\nShift + middle drag — slide\n"
		+ "Witness: left drag also turns\nTest world: left paints, right erases\nCtrl+Z / Ctrl+Y — undo / "
		+ "redo", 11, Palette.GRIS))


## LA LÉGENDE — dérivée des six teintes de `RP.TEINTES`, jamais recopiée : une légende fausse est pire
## qu'une absence de légende.
func _legende() -> Control:
	var grille := VBoxContainer.new()
	grille.add_theme_constant_override("separation", 3)
	for t in RP.TEINTES:
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 6)
		var pastille := ColorRect.new()
		pastille.color = t["couleur"]
		pastille.custom_minimum_size = Vector2(12, 12)
		pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(pastille)
		ligne.add_child(_texte(t["nom"], 11))
		grille.add_child(ligne)
	return grille


func _batir_droite(pile: VBoxContainer) -> void:
	var trancher := Section.new("Slice")
	pile.add_child(trancher)
	trancher.contenu.add_child(_bouton("Slice the witness (test)",
		"Slices the computed witness into its 52 tiles and paints the Test world with them.",
		_trancher_temoin))
	trancher.contenu.add_child(_bouton("Slice the work",
		"Re-reads the imported work, slices it, and paints the witness cells with YOUR tiles.\nThe "
		+ "result must give the witness back: that is the proof that the round trip holds.",
		_trancher_travail))

	var etage := Section.new("Floor")
	pile.add_child(etage)
	_sections_monde.append(etage)
	var ligne := HBoxContainer.new()
	ligne.add_child(_texte("floor y =", 12))
	var compteur := SpinBox.new()
	compteur.min_value = -64
	compteur.max_value = 64
	compteur.value_changed.connect(func(v: float) -> void:
		_vue.regler_etage(int(v))
		_dire_l_etage())
	ligne.add_child(compteur)
	etage.contenu.add_child(ligne)
	_etiquette_etage = _texte("", 11, Palette.GRIS)
	etage.contenu.add_child(_etiquette_etage)
	for op in [
		["Extend up", "haut", "copies this floor one cell higher"],
		["Extend down", "bas", "copies this floor one cell lower"],
		["Widen", "elargir", "adds a ring around this floor's footprint"],
		["Hollow", "creuser", "removes the cells whose four horizontal neighbours are full"],
	]:
		etage.contenu.add_child(_bouton(op[0], op[2], _operer.bind(op[1])))
	etage.contenu.add_child(_bouton("Clear the world", "Erases every cell (Ctrl+Z brings them back).",
		_effacer_tout))

	var rapport := Section.new("Report")
	pile.add_child(rapport)
	_rapport = RichTextLabel.new()
	_rapport.bbcode_enabled = true
	_rapport.fit_content = true
	_rapport.selection_enabled = true
	_rapport.custom_minimum_size = Vector2(0, 60)
	_rapport.add_theme_font_size_override("normal_font_size", 12)
	rapport.contenu.add_child(_rapport)


func _batir_attente(parent: Control) -> void:
	_attente = PanelContainer.new()
	_attente.add_theme_stylebox_override("panel", Palette.fond(Palette.ATTENTE, 6, 16))
	_attente.set_anchors_preset(Control.PRESET_CENTER)
	_attente.custom_minimum_size = Vector2(340, 88)
	_attente.offset_left = -170
	_attente.offset_right = 170
	_attente.offset_top = -44
	_attente.offset_bottom = 44
	_attente.visible = false
	var pile := VBoxContainer.new()
	_attente.add_child(pile)
	_attente_titre = _texte("", 14, Palette.OLIVE)
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
	_atelier = atelier
	(_boutons_atelier[atelier] as Button).button_pressed = true
	for s in _sections_monde:
		s.visible = atelier == "monde"
	_vue.montrer("monde" if atelier == "monde" else "temoin")
	_dire_l_etage()


# ── LE TÉMOIN ET LE TRAVAIL ──────────────────────────────────────────────────────────────────────────

func _matiere_voulue() -> Material:
	if _pbr == null or not _pbr.button_pressed:
		return null
	if _matiere_pbr == null:
		_matiere_pbr = PBR.matiere()
	return _matiere_pbr


func _montrer_temoin() -> void:
	_vue.montrer_maillage(BM.maillage_moitie(0), _matiere_voulue())


## ⚠ LE TRAVAIL IMPORTÉ N'EST JAMAIS RECOUVERT DU PBR : c'est l'art de l'artiste (charte §3).
func _habiller() -> void:
	if _travail_maillage != null and _etiquette_vue.text.begins_with("showing: your work"):
		return
	_montrer_temoin()


func _travail_vu(oui: bool) -> void:
	if oui and _travail_maillage != null:
		_vue.montrer_maillage(_travail_maillage, null)
		_etiquette_vue.text = "showing: your work — %s" % _travail.get_file()
	else:
		_montrer_temoin()
		_etiquette_vue.text = "showing: the computed witness"
	_aller_a("witness")


func _demander(quoi: String) -> void:
	_action_fichier = quoi
	_dialogue.file_mode = FileDialog.FILE_MODE_SAVE_FILE if quoi == "exporter" \
		else FileDialog.FILE_MODE_OPEN_FILE
	_dialogue.title = "Export the witness" if quoi == "exporter" else "Import the work"
	_dialogue.current_file = "marchingblocks_witness.glb"
	_dialogue.popup_centered_ratio(0.6)


func _fichier_choisi(fichier: String) -> void:
	match _action_fichier:
		"exporter":
			_exporter(fichier)
		"importer":
			_importer(fichier)


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
		_travail = ""
		_travail_maillage = null
		var motif: String = "\n  ".join(PackedStringArray(journal)) if not journal.is_empty() \
			else "no geometry inside the block's box — was the block moved?"
		_dire("[color=#e0603c]Nothing to show from[/color] %s\n  %s" % [fichier, motif])
		return
	_travail = fichier
	_travail_maillage = travail
	_travail_vu(true)
	var ecart: int = BM.ecart_au_temoin(travail)
	var ecart_dit: String = ("[color=#f2ca79]No vertex moved compared to the witness: slicing will give "
		+ "the witness tiles back.[/color]") if ecart == 0 \
		else "%d new vertex position(s) compared to the witness." % ecart
	_dire(("[color=#b4bd85][b]Work imported[/b][/color] ← %s\n%s\n\nThe view shows it as the slicer "
		+ "will read it: whatever leaves the block's box is gone.\n[i]« Slice the work » re-reads the "
		+ "file when clicked — saving again in Blender meanwhile is enough.[/i]") % [fichier, ecart_dit])


# ── TRANCHER ─────────────────────────────────────────────────────────────────────────────────────────

func _trancher_temoin() -> void:
	await _attendre("Slicing the witness", "52 tiles, every sculpted copy kept")
	var bilan: Dictionary = BM.librairie(_matiere_voulue())
	_fin_attente()
	_poser_lot(bilan, "witness", {})


func _trancher_travail() -> void:
	if _travail == "":
		_dire("No work imported.\n\n[i]« Import the work… » first: you slice what you have seen.[/i]")
		return
	await _attendre("Slicing your work", _travail.get_file())
	var bilan: Dictionary = BM.librairie_depuis_glb(_travail)
	_fin_attente()
	var entete := "[b]Sliced from[/b] %s\n" % _travail
	var absents: Array = bilan.get("absents", [])
	if not absents.is_empty():
		entete += "[color=#f2ca79]Block MISSING from the file, computed witness kept.[/color]\n"
	_poser_lot(bilan, "work", BM.cases(0), entete)


## Câble le lot sur le monde de test, et DIT tout ce que le bilan contient.
func _poser_lot(bilan: Dictionary, quoi: String, a_peindre: Dictionary, entete := "") -> void:
	var fautes: Array = BM.anomalies()
	if not fautes.is_empty():
		_dire("[color=#e0603c]REFUSED — %d problem(s) in the witness:[/color]\n  %s"
			% [fautes.size(), "\n  ".join(PackedStringArray(fautes.slice(0, 6)))])
		return
	var lot: MeshLibrary = bilan["lot"]
	_vue.monde().lot = lot
	if not a_peindre.is_empty():
		_remplacer_le_monde(a_peindre, "Paint the witness cells")
	_aller_a("monde")

	var en_plus: int = int(bilan.get("exemplaires_en_plus", 0))
	var texte := entete
	texte += "[color=#b4bd85][b]Library ready[/b][/color] (%s) — %d tile(s) for %d classes" \
		% [quoi, lot.get_item_list().size() - en_plus, MB.pieces_a_sculpter().size()]
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
	texte += "\n[i]Paint on the grid: left click adds, right click erases.[/i]"
	_dire(texte)


# ── PEINDRE ──────────────────────────────────────────────────────────────────────────────────────────

func _id_case() -> int:
	var cases: GridMap = _vue.cases()
	return cases.mesh_library.find_item_by_name("case") if cases.mesh_library != null else -1


func _coup_commence() -> void:
	_coup = {}


func _case_touchee(c: Vector3i, poser: bool) -> void:
	var cases: GridMap = _vue.cases()
	var id: int = _id_case()
	if id < 0:
		return
	var avant: int = cases.get_cell_item(c)
	var apres: int = id if poser else -1
	if avant == apres:
		return
	if not _coup.has(c):
		_coup[c] = [avant, apres]
	else:
		_coup[c][1] = apres
	cases.set_cell_item(c, apres)
	_vue.monde().reconstruire()


## ⚠ UN COUP ENTIER S'ANNULE D'UN SEUL Ctrl+Z — c'est ce qu'on attend d'un pinceau. Les cases sont déjà
## posées pendant le glissé ; l'action est donc enregistrée SANS être rejouée (`commit_action(false)`).
func _coup_fini() -> void:
	if _coup.is_empty():
		return
	var cases: GridMap = _vue.cases()
	_histoire.create_action("Stroke")
	for c in _coup:
		_histoire.add_do_method(cases.set_cell_item.bind(c, _coup[c][1]))
		_histoire.add_undo_method(cases.set_cell_item.bind(c, _coup[c][0]))
	_histoire.add_do_method(_reconstruire)
	_histoire.add_undo_method(_reconstruire)
	_histoire.commit_action(false)
	_coup = {}
	_dire_l_etage()


func _reconstruire() -> void:
	_vue.monde().reconstruire()
	_dire_l_etage()


## Remplace toutes les cases du monde, en UNE action annulable.
func _remplacer_le_monde(nouvelles: Dictionary, nom: String) -> void:
	var cases: GridMap = _vue.cases()
	var id: int = _id_case()
	if id < 0:
		return
	var anciennes: Array = cases.get_used_cells()
	_histoire.create_action(nom)
	for c in anciennes:
		_histoire.add_do_method(cases.set_cell_item.bind(c, -1))
		_histoire.add_undo_method(cases.set_cell_item.bind(c, id))
	for c in nouvelles:
		_histoire.add_do_method(cases.set_cell_item.bind(c, id))
	# ⚠ L'annulation doit effacer ce que le « faire » a posé AVANT de reposer l'ancien monde : sinon
	# les cases nouvelles qui n'existaient pas avant resteraient.
	for c in nouvelles:
		_histoire.add_undo_method(cases.set_cell_item.bind(c, -1))
	for c in anciennes:
		_histoire.add_undo_method(cases.set_cell_item.bind(c, id))
	_histoire.add_do_method(_reconstruire)
	_histoire.add_undo_method(_reconstruire)
	_histoire.commit_action()


func _effacer_tout() -> void:
	_remplacer_le_monde({}, "Clear the world")


## LES OPÉRATIONS D'ÉTAGE — la règle vit dans `etages.gd`, partagée avec le greffon.
func _operer(quoi: String) -> void:
	var cases: GridMap = _vue.cases()
	var id: int = _id_case()
	if id < 0:
		return
	var occupees := {}
	for c in cases.get_used_cells():
		occupees[c] = true
	var ops: Dictionary = Etages.operer(occupees, _vue.etage, quoi)
	var a_poser: Dictionary = ops["poser"]
	var a_effacer: Dictionary = ops["effacer"]
	if a_poser.is_empty() and a_effacer.is_empty():
		_dire("[i]Nothing to do on floor y = %d.[/i] The floor is empty, or the operation found nothing "
			% _vue.etage + "to change.")
		return
	_histoire.create_action(quoi)
	for c in a_poser:
		_histoire.add_do_method(cases.set_cell_item.bind(c, id))
		_histoire.add_undo_method(cases.set_cell_item.bind(c, -1))
	for c in a_effacer:
		_histoire.add_do_method(cases.set_cell_item.bind(c, -1))
		_histoire.add_undo_method(cases.set_cell_item.bind(c, id))
	_histoire.add_do_method(_reconstruire)
	_histoire.add_undo_method(_reconstruire)
	_histoire.commit_action()
	_dire("[b]%s[/b] on floor y = %d — %d cell(s) added, %d removed. [i]Ctrl+Z undoes it.[/i]"
		% [quoi, _vue.etage, a_poser.size(), a_effacer.size()])


func _dire_l_etage() -> void:
	if _etiquette_etage == null or _vue == null:
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


# ── LES RACCOURCIS ───────────────────────────────────────────────────────────────────────────────────

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or not k.ctrl_pressed:
		return
	if k.keycode == KEY_Z and not k.shift_pressed:
		if _histoire.undo():
			_dire("[i]Undone: %s[/i]" % _histoire.get_current_action_name())
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_Y or (k.keycode == KEY_Z and k.shift_pressed):
		if _histoire.redo():
			_dire("[i]Redone: %s[/i]" % _histoire.get_current_action_name())
		get_viewport().set_input_as_handled()


func _dire(texte: String) -> void:
	if _rapport != null:
		_rapport.text = texte
