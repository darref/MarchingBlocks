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
const FS := preload("res://addons/marchingblocks_core/formes_speciales.gd")
const FormatNeutre := preload("res://addons/marchingblocks_core/format_neutre.gd")
const FormatMonde := preload("res://addons/marchingblocks_core/format_monde.gd")
const Palette := preload("res://app/palette.gd")
const Section := preload("res://app/section.gd")
const Variantes := preload("res://app/variantes.gd")
const AtelierTransitions := preload("res://app/transitions.gd")
const AtelierAnimation := preload("res://app/animation.gd")
const AtelierFeuillage := preload("res://app/atelier_feuillage.gd")
const Panneau := preload("res://app/panneau.gd")
const Vue := preload("res://app/vue.gd")
const Projet := preload("res://app/projet.gd")
const Icones := preload("res://app/icones.gd")
const Manuel := preload("res://app/manuel.gd")
const Associations := preload("res://app/associations.gd")
const Exemple := preload("res://app/exemple.gd")
const Dossiers := preload("res://app/dossiers.gd")
const Modeleur := preload("res://app/modeleur.gd")
const LegendeFormes := preload("res://app/legende_formes.gd")
const ME := preload("res://addons/marchingblocks_core/maillage_edite.gd")
const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const Cartes := preload("res://addons/marchingblocks_core/cartes_pbr.gd")
const Peinture := preload("res://addons/marchingblocks_core/peinture.gd")
const FL := preload("res://addons/marchingblocks_core/fluides.gd")
const EauMaillage := preload("res://addons/marchingblocks_core/eau_maillage.gd")
const EauPresets := preload("res://addons/marchingblocks_core/eau_presets.gd")
const Anim := preload("res://addons/marchingblocks_core/animation_materiau.gd")

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
	"A, D, S, R, B pick Add, Dig, Select, Rect, Box. [ and ] change the brush size.",
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
var _droite_texture: Panneau
## Les boutons qui existent dans les DEUX barres du témoin (Geometry, Texturing) : ils se suivent.
var _boutons_edition: Array = []
var _etiquettes_temoin_couche: Array = []
var _boutons_selmode_tex := {}
## LA LÉGENDE DES FORMES du témoin — le bandeau repliable en haut de la vue, dans l'atelier Witness.
var _legende_formes: LegendeFormes
var _modeleur: Node3D
var _bouton_edition: Button
var _boutons_selmode := {}
var _bouton_prop: Button
## L'enregistrement du témoin modélisé attend une seconde de calme : un geste = un fichier réécrit, pas dix.
var _minuterie_temoin: Timer
## L'enregistrement du PROJET attend lui aussi une seconde de calme (`_enregistrer_plus_tard`).
var _minuterie_projet: Timer
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
var _attente_barre: ProgressBar
## LA PILE DES ATTENTES : [titre, note, étapes (0 = barre défilante), étapes faites]. Une attente peut en contenir
## une autre (un tranchage pendant l'ouverture d'un projet) : la plus récente se montre, la précédente revient.
var _pile_attente: Array = []
## Ce qu'a duré la dernière fois chaque opération variable, pour ne montrer la barre que si elle dépasse le seuil.
const SEUIL_ATTENTE := 0.4
const Durees := preload("res://app/durees.gd")
var _durees := {}
var _bandeau: Button
var _manuel: Control
var _conseil := 0
var _ecoule := 0.0

var _boutons_atelier := {}
var _atelier := "witness"
## LES MORCEAUX DE L'ÉCRAN QUI DÉPENDENT DU CONTEXTE — tous montrés ou cachés par `_contexte()`, et
## nulle part ailleurs (charte §6 : une règle vit à UN endroit).
var _section_jeu: Control
var _taille_personnage: HSlider
var _titre_projet: Control
var _section_projet: Control
var _choix_monde: VBoxContainer
var _section_choix_monde: Section
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
var _bouton_monter_couche: Button
var _bouton_descendre_couche: Button
var _bouton_naviguer: Button
var _titre_pinceau: Control
var _ligne_taille: Control
var _ligne_forme: Control
var _case_vides: CheckBox
var _largeur_eau: HSlider

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
var _recents: VBoxContainer
const RECENTS_MAXI := 6
## Vrai pendant qu'on rebâtit un projet : rien ne s'enregistre d'un monde à moitié relu.
var _ouverture := false
## Les couches supprimées, gardées vivantes tant qu'un Ctrl+Z peut les rendre.
var _detachees: Array = []

var _histoire := UndoRedo.new()
## LES VARIANTES VOULUES (4 octobre 2026) : leurs deux sections et leurs gestes vivent dans `variantes.gd`.
var _variantes: RefCounted = Variantes.new(self)
## L'ATELIER TRANSITIONS (Jordan, 6 octobre 2026) : l'état est dans le projet, la règle et le rendu dans le cœur.
var _transitions: RefCounted = AtelierTransitions.new(self)
## L'ATELIER ANIMATION (6 octobre 2026) : les textures animées (`app/animation.gd`).
var _animation: RefCounted = AtelierAnimation.new(self)
## L'atelier Foliage (6 octobre 2026) : tout vit dans `atelier_feuillage.gd`, ici les branchements.
var _feuillage: RefCounted = AtelierFeuillage.new(self)
var _droite_feuillage: Panneau
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
var _boutons_forme_speciale := {}
var _boutons_bouts := {}
var _boutons_profil := {}
var _ligne_bouts: Control
var _ligne_profil: Control
var _ligne_longueur: Control
var _etiquette_longueur: Label
var _longueur_forme: SpinBox
var _ligne_pas: Control
var _pas_forme: SpinBox
var _taille_forme: HSlider
var _valeur_taille_forme: Label
var _garde_corps: CheckButton
var _ligne_taille_forme: Control
var _ligne_salle: VBoxContainer
var _etages_forme: SpinBox
var _etages_selection: SpinBox
var _sens_selection := {}
var _boutons_sens_salle := {}
var _reglages_forme: Control
var _aide_forme: Label
## Le PRESSE-PAPIERS : des décalages relatifs (`Outils.copier`). Il n'appartient à aucune couche — on
## copie dans la roche et on colle dans la glace.
var _presse_papiers: Array = []

## LES FLUIDES : les couches d'eau (`Projet.couche_d_eau` : nom, visible, preset, SOURCES) et ce qui s'en déduit.
var _eaux: Array = []
var _eau_active := 0
var _corps_eau: Array = []      # par couche d'eau, un résultat de `FL.source` par source
var _ocean_eau := {}
var _occ_eau := {}               # les cases du monde entier au dernier calcul
var _monde_eau := {}             # le dernier rendu de `FL.monde`, pour en REPRENDRE ce qu'un geste n'a pas touché
var _maillages_eau: Array = []   # par couche d'eau : [ses corps, son maillage] — repris si ses corps le sont tous
var _eau_a_refaire := false
var _eau_vide := false            # aucune source au dernier calcul : les nappes sont vidées
var _index_eau := {}              # case de lac ou de rivière → [couche, source]
var _eau_apres_le_coup := false   # l'eau attend la fin du coup de pinceau (monde lent)
var _materiaux_eau := {}
var _cle_apercu_eau := ""
## La boîte du monde (`FL.boite`) pour `_occ_eau` : un balayage de toutes les cases (57 ms sur l'exemple) qu'appelaient
## à chaque case survolée `dans_le_vide` et `source`. Gardée tant que `_occ_eau` est le même dictionnaire, de même taille.
var _boite_eau_cache := {}
var _boite_eau_de: Dictionary = {}
var _boite_eau_taille := -1
## LA HAUTEUR DE LA MER EN CHOIX (Jordan, 4 octobre 2026 : « un preview pour pouvoir choisir la hauteur de l'océan
## avant de valider, et que le calcul ne se lance qu'après ») : null, ou la hauteur montrée par le plan d'aperçu.
var _mer_choisie: Variant = null
var _mer_case := Vector3i.ZERO   # la case cliquée : sa colonne porte la source, si elle reste dans le vide
var _eau_barre_forcee := false   # le prochain recalcul de l'eau montre l'attente (la mer posée : tout est refait)
var _droite_fluides: Panneau
var _droite_transitions: Panneau
var _droite_animation: Panneau
## L'outil de World qu'on avait en entrant dans Fluids (`_vue.outil`, et la forme si c'en était une) : rendu en sortant.
var _outil_avant_fluides := "ajouter"
var _aide_eau: Label
var _liste_eaux: VBoxContainer
var _bouton_supprimer_eau: Button
var _preset_eau: OptionButton

## La barre de droite du Play test : les réglages de rendu (`Vue.REGLAGES_RENDU`), un contrôle par clé.
var _droite_jeu: Panneau
var _controles_rendu := {}
var _choix_meteo: OptionButton


## ⚠ `UndoRedo` N'EST PAS COMPTÉ PAR RÉFÉRENCE : il fuit si on ne le libère pas, avec les couches
## supprimées qu'il garde en vie.
func _notification(quoi: int) -> void:
	# ⚠ LA FERMETURE ÉCRIT CE QUI ATTENDAIT : la seconde d'attente après le dernier geste, et le `.glb` du monde.
	# Sans elle, fermer juste après un geste le perdait.
	if quoi == NOTIFICATION_WM_CLOSE_REQUEST and _minuterie_temoin != null:
		_retenir_les_durees()
		_toujours_ecrire()
		if _dev != null:
			_attendre_l_ecriture()
			_dev.a_la_fermeture(_projet)
	if quoi == NOTIFICATION_PREDELETE:
		_attendre_l_ecriture()
		# Les cartes PBR en route sur un autre fil : on ne démonte pas le moteur sous elles.
		Peinture.attendre_les_cartes()
		for m in _detachees:
			m.free()
		_histoire.free()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_brancher_le_dev()
	_regler_fenetre()
	_batir()
	_montrer_temoin()
	_aller_a("witness")
	_dire("[i]Look at the witness, open Project to exchange it with your artist, or open the World "
		+ "and paint.[/i]")
	_histoire.version_changed.connect(_enregistrer_plus_tard)
	_lire_les_durees()
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
	_suivre_le_geste()
	_dire_les_trous()
	_dire_les_ecarts()
	_transitions.suivre()
	_animation.suivre(delta)
	if _atelier == "witness":
		_variantes.dire_temoin()
	# Les cartes PBR suivent leur albedo, sur un autre fil, quand la main s'est posée (`peinture.gd`).
	Peinture.suivre_les_cartes()
	_dire_l_etat_pbr()
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
	colonne.add_child(_bande_du_bas())

	_vue = Vue.new()
	_vue.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vue.coup_commence.connect(_coup_commence)
	_vue.touche.connect(_touche)
	_vue.selection_changee.connect(_selection_changee)
	_vue.colle.connect(_colle)
	_vue.forme_posee.connect(_forme_posee)
	_vue.forme_dite.connect(_forme_dite)
	_vue.eau_survolee.connect(_eau_survolee)
	_vue.eau_cliquee.connect(_eau_cliquee)
	_vue.feuillage_survole.connect(_feuillage.survoler)
	_vue.feuillage_coup.connect(_feuillage.coup)
	_vue.variante_cliquee.connect(_variantes.cliquer)
	_vue.transition_peinte.connect(_transitions.peindre)
	_vue.etage_sur_la_matiere.connect(_etage_sur_la_matiere)
	_vue.molette_contextuelle = _molette
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
	_modeleur.peint.connect(_trait_peint)
	_modeleur.couleur_lue.connect(func(c: Color) -> void:
		if _couleur_pinceau != null:
			_couleur_pinceau.color = c)
	_modeleur.dit.connect(_dire)
	_droite_temoin = _panneau(corps, false, LARGEUR_DROITE)
	_batir_droite_temoin(_droite_temoin.get_meta("pile"))
	_droite_texture = _panneau(corps, false, LARGEUR_DROITE)
	_batir_droite_texture(_droite_texture.get_meta("pile"))
	_droite_jeu = _panneau(corps, false, LARGEUR_DROITE)
	_batir_droite_jeu(_droite_jeu.get_meta("pile"))
	_droite_fluides = _panneau(corps, false, LARGEUR_DROITE)
	_batir_fluides(_droite_fluides.get_meta("pile"))
	_droite_transitions = _panneau(corps, false, LARGEUR_DROITE)
	_transitions.batir(_droite_transitions.get_meta("pile"))
	_droite_animation = _panneau(corps, false, LARGEUR_DROITE)
	_animation.batir(_droite_animation.get_meta("pile"))
	_feuillage.brancher(_vue.feuillage)
	_droite_feuillage = _panneau(corps, false, LARGEUR_DROITE)
	_feuillage.batir(_droite_feuillage.get_meta("pile"))
	# CHAQUE BARRE DE DROITE DANS LA TEINTE DE SON ATELIER (Jordan, 2 octobre 2026) — le reste garde l'olive.
	for b in [[_droite, "monde"], [_droite_temoin, "witness"], [_droite_texture, "texture"], [_droite_jeu, "jeu"],
			[_droite_fluides, "fluides"], [_droite_transitions, "transitions"], [_droite_animation, "anim"],
			[_droite_feuillage, "feuillage"]]:
		Palette.habiller_barre(b[0], b[1])
	if is_inside_tree():
		Palette.teinter_ce_qui_arrive(get_tree())
		get_tree().node_added.connect(_sans_molette)
	_sans_molette_partout(self)
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
	_vue.tuile_survolee.connect(_variantes.survoler)
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
	_minuterie_projet = Timer.new()
	_minuterie_projet.one_shot = true
	_minuterie_projet.wait_time = 1.0
	_minuterie_projet.timeout.connect(_enregistrer.bind(true))
	add_child(_minuterie_projet)
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


## LA BANDE DU BAS (Jordan, 1er octobre 2026) : « une petite démarcation, afin qu'on ne confonde pas les
## défilements qui filent sous leur limite avec un logiciel qui dépasse de l'écran ». Une bande fine, de la teinte
## de la barre de titre, filet en haut : l'écran a un bord en bas comme en haut, et ce qui est coupé au-dessus
## d'elle l'est par un défilement, pas par l'écran.
func _bande_du_bas() -> Control:
	_bande_bas = Panel.new()
	_bande_bas.name = "BandeDuBas"
	_bande_bas.custom_minimum_size = Vector2(0, HAUTEUR_BANDE_BAS)
	_bande_bas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := Palette.fond(Palette.BARRE_TITRE, 0, 0)
	style.border_color = Palette.FILET
	style.border_width_top = 1
	_bande_bas.add_theme_stylebox_override("panel", style)
	return _bande_bas


const HAUTEUR_BANDE_BAS := 8
var _bande_bas: Panel


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
	editeur.text = "SpannerGames"
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
	# ⚠ SI UN CONTENU LA FORÇAIT À S'ÉLARGIR, LA BARRE DE DROITE GRANDIRAIT VERS LA DROITE, HORS DE L'ÉCRAN (vu par Jordan,
	# 3 octobre 2026) : elle grandit vers la gauche, sur la vue. La garde de la fumée exige qu'elle ne grandisse pas.
	if not a_gauche:
		p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	parent.add_child(p)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 10)
	p.add_child(colonne)
	var defile := ScrollContainer.new()
	# ⚠ À DROITE, LE CONTENU NE PEUT PLUS ÉLARGIR LA BARRE (3 octobre 2026 : « la barre de droite déborde à droite en
	# World », mesuré par `DEV_TOOLS/sonde_largeur_droite.gd`) : dès qu'une sélection allongeait la barre, l'ascenseur
	# vertical apparaissait et ajoutait sa largeur — 311 px au lieu de 308, et 358 avec les deux « Extend selection »
	# côte à côte. « Jamais montré » au lieu de « désactivé » : la largeur minimale du contenu ne remonte plus, et la
	# marge passe de 8 à 4 pour que le plus large (Shape operations, 275 px) tienne à côté de l'ascenseur.
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if a_gauche else ScrollContainer.SCROLL_MODE_SHOW_NEVER
	defile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colonne.add_child(defile)
	var marge := MarginContainer.new()
	marge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marge.add_theme_constant_override("margin_right", 8 if a_gauche else 4)
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
		["jeu", "Play test", "jouer", "Walk and jump through your world, at the height of a player."],
		["monde", "World", "monde", "Paint worlds with the sliced tiles."],
		["fluides", "Fluids", "eau", "Place water in the painted world: lakes, rivers, seas. Esc goes back to World."],
		["witness", "Geometry", "cube", "Witness geometry — sculpt the block's tiles: every copy follows."],
		["texture", "Texturing", "texture", "Witness texturing — materials, projections and UV unwrapping "
			+ "of the witness tiles."],
		["transitions", "Transitions", "couches", "Where two layers meet, blend the look of one over the other. Esc "
			+ "goes back to World."],
		["anim", "Animation", "film", "Animated textures on the witness materials: scroll, frames (a texture video), "
			+ "pulse — on any map, emission included."],
		["feuillage", "Foliage", "arbre", "Plant trees and bushes (.glb models) in the painted world. Esc goes back to "
			+ "World."],
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
		b.pressed.connect(_changer_d_atelier.bind(a[0]))
		_boutons_atelier[a[0]] = b
		Palette.habiller_bouton_d_atelier(b, a[0])   # chaque atelier se reconnaît à sa teinte (Jordan, 2 octobre 2026)
		ateliers.append(b)
	# ⚠ SIX ATELIERS (1er octobre 2026 : Witness coupé en Geometry et Texturing ; 2 octobre : Fluids sorti de World,
	# Jordan) : en grille de deux, une rangée ne tient pas dans 300 px. Les paires vont ensemble : Project · Play test,
	# World · Fluids (le même monde), Geometry · Texturing (le même témoin).
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
			["F", "Fly on · off"], ["Space · E / A", "Fly up / down (E / Q on QWERTY)"],
			["Left drag", "Orbit the camera"], ["Right drag", "Turn (level)"], ["Wheel", "Closer · farther"], ["Backspace", "Back to start"],
			["Esc", "Back to World"]]:
		commandes.add_child(_touche_clavier(r[0]))
		commandes.add_child(_texte(r[1], 11, Palette.GRIS))
	_section_jeu.contenu.add_child(commandes)
	_section_jeu.contenu.add_child(_rangee([
		_bouton("Fly", "Fly on or off (F). In flight you still bump into the world.",
			_basculer_vol, "visee_naviguer"),
		_bouton("Back to start", "Puts the character back where it started (Backspace).",
			func() -> void: _vue.reapparaitre(), "haut"),
		_bouton("Leave", "Back to World (Esc).", _changer_d_atelier.bind("monde"), "croix"),
	], 4))
	# LA TAILLE DU PERSONNAGE (Jordan, 6 octobre 2026) : ×0,65 par défaut, pour que le monde paraisse plus grand.
	_taille_personnage = _curseur_libre(_section_jeu.contenu, "Character size", Vue.Personnage.TAILLE_MINI,
		Vue.Personnage.TAILLE_MAXI, 0.05, "Scales the character, its speed and the camera behind it. Smaller makes the "
		+ "world feel bigger. The jump still clears one and a half cells. Kept for this session only.")
	_taille_personnage.value = _vue.taille_personnage
	_taille_personnage.value_changed.connect(func(v: float) -> void: _vue.regler_taille_personnage(v))

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
	# LES PROJETS RÉCENTS (3 octobre 2026) : reprendre un monde sans passer par la boîte de fichiers.
	_recents = VBoxContainer.new()
	_recents.add_theme_constant_override("separation", 2)
	projet.contenu.add_child(_recents)
	# L'EXEMPLE LIVRÉ s'ouvre dans World (« Which world » : My world / The example) — plus de bouton à part ici
	# (Jordan, 2 octobre 2026 : « on a l'exemple dans exemple, plus besoin de l'exemple en projet séparé »).
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
	# L'EXEMPLE OU TON MONDE (Jordan, 2 octobre 2026 : « un bouton exemple et un bouton world dans World, le soft ne
	# doit pas forcer l'exemple à l'arrivée »). ⚠ UN CHOIX SOUS SA SECTION, PAS DEUX BOUTONS (Jordan, le même jour :
	# collés sous les ateliers, « c'est pas clair » — ils se lisaient comme deux ateliers de plus).
	_section_choix_monde = Section.new("Which world", true, Icones.icone("monde"))
	pile.add_child(_section_choix_monde)
	_choix_monde = VBoxContainer.new()
	_choix_monde.add_theme_constant_override("separation", 2)
	var groupe_monde := ButtonGroup.new()
	for b in [["My world", "Your own world: the last project you opened that is not the example.",
				_ouvrir_mon_monde],
			["Very simple example", "A very simple example world that comes with MarchingBlocks, in its own folder. Your changes "
				+ "to it are kept there.", _ouvrir_l_exemple]]:
		var choix := CheckBox.new()
		choix.text = b[0]
		choix.tooltip_text = b[1]
		choix.button_group = groupe_monde
		choix.pressed.connect(b[2])
		_choix_monde.add_child(choix)
	_section_choix_monde.contenu.add_child(_choix_monde)
	if _dev != null:
		pile.add_child(_dev.panneau(Section, _bouton, _texte))
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
	# L'ORDRE EST LA PRIORITÉ (couches exclusives) : là où deux couches se touchent, chaque coin prend les tuiles de
	# la plus haute. Ces deux boutons la choisissent.
	_bouton_monter_couche = _bouton("Up", "Moves the active layer up: where layers meet, the upper one's tiles "
		+ "draw the corners (Ctrl+Z puts it back).", _deplacer_couche.bind(-1), "haut")
	_bouton_descendre_couche = _bouton("Down", "Moves the active layer down: where layers meet, the upper one's "
		+ "tiles draw the corners (Ctrl+Z puts it back).", _deplacer_couche.bind(1), "bas")
	couches.contenu.add_child(_rangee([_bouton_monter_couche, _bouton_descendre_couche]))
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
			["PgUp PgDn", "Floor y"], ["Ctrl+click", "Floor y to matter"], ["²", "Jump to matter"], ["Arrows", "Move selection"], ["Del · Esc", "Delete · clear"],
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
	# PEINDRE UNE SÉLECTION DANS LE VIDE (Jordan, 3 octobre 2026 : « peindre une sélection pour en faire ce qu'on
	# veut, comme une room quelconque ») : le pinceau Select ne prenait que la matière.
	_case_vides = CheckBox.new()
	_case_vides.text = "Select empty cells too"
	_case_vides.focus_mode = Control.FOCUS_NONE
	_case_vides.tooltip_text = ("The Select brush also takes the air: paint the outline of a room on the floor grid "
		+ "(Disc brush), then Extend selection ↑ and Fill — or anything else the Selection section does.")
	_case_vides.toggled.connect(func(v: bool) -> void: _vue.selection_vide = v)
	outils.contenu.add_child(_case_vides)

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
	_compteur_etage.tooltip_text = "PgUp / PgDn, or Ctrl+click some matter to jump to its height. The Grid aims at this plane; Sculpt falls back on it."
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
		_bouton("Grow", "Selects the matter touching the selection by a face.",
			_operer_selection.bind("grandir"), "grandir"),
		_bouton("Shrink", "Drops the edge of the selection: a rectangle loses its rim, a line its ends, a block its skin.",
			_operer_selection.bind("retrecir_bord"), "retrecir"),
		_bouton("Connected", "Selects all the matter linked to the selection by faces.",
			_operer_selection.bind("connexe"), "connexe"),
	]))
	# ⚠ UN PAR LIGNE (3 octobre 2026 : « la barre de droite déborde à droite en World ») : côte à côte dans la grille,
	# les deux « Extend selection » (158 px chacun) élargissaient la barre de 308 à 358 px dès qu'une sélection existait.
	sel.contenu.add_child(VBoxContainer.new())
	for b in [
		# ÉTENDRE EN HAUTEUR, D'UN BOUTON (Jordan, 3 octobre 2026 : « depuis qu'on a fusionné Extrude, seulement des
		# raccourcis ») : le mode « étendre » d'Extrude (Maj + clic), sans rien poser. ⚠ « SELECTION » DANS LE NOM : l'ancien
		# « Extend up » posait de la matière comme Extrude, et c'est cette ambiguïté qui l'avait fait retirer (2 octobre).
		_bouton("Extend selection ↑", "Adds the cells one level above the selection, empty ones too — no matter added. "
			+ "Then Fill, or keep extending: a room's walls rise this way.", _extruder.bind("haut", "etendre"),
			"extruder_haut"),
		_bouton("Extend selection ↓", "Adds the cells one level below the selection, empty ones too — no matter added.",
			_extruder.bind("bas", "etendre"), "extruder_bas"),
	]:
		sel.contenu.get_child(sel.contenu.get_child_count() - 1).add_child(b)
	# LA SALLE D'UNE SÉLECTION (Jordan, 3 octobre 2026 : « dessiner une sélection quelconque à plat, et l'extruder en
	# room verticalement ») — `FS.salle_depuis`. Les étages et le sens sont ceux de la forme Room (synchronisés).
	sel.contenu.add_child(_petit_titre("ROOM FROM THE SELECTION"))
	var ligne_salle := HBoxContainer.new()
	ligne_salle.add_theme_constant_override("separation", 8)
	ligne_salle.add_child(_texte("Floors", 12))
	_etages_selection = SpinBox.new()
	_etages_selection.min_value = 1
	_etages_selection.max_value = FS.ETAGES_MAXI
	_etages_selection.value = int(_vue.forme_speciale["etages"])
	_etages_selection.tooltip_text = "How high the room is inside, in cells (the same setting as the Room shape)."
	_etages_selection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_etages_selection.value_changed.connect(func(v: float) -> void:
		_vue.forme_speciale["etages"] = int(v)
		if _etages_forme != null:
			_etages_forme.set_value_no_signal(v))
	ligne_salle.add_child(_etages_selection)
	sel.contenu.add_child(ligne_salle)
	sel.contenu.add_child(_rangee_de_choix(_sens_selection, [
		["haut", "Up", "extruder_haut", "The selection is the floor: the room rises from it."],
		["bas", "Down", "extruder_bas", "The selection is the ceiling: the room sinks below it."],
	], func(v: String) -> void: _regler_le_sens_de_salle(v)))
	(_sens_selection["haut"] as Button).set_pressed_no_signal(true)
	sel.contenu.add_child(_bouton("Room from selection", "Turns the selection, seen from above, into a room: its outline "
		+ "becomes the walls, the whole footprint the floor and the ceiling, and the inside is hollowed out. Paint the "
		+ "footprint flat with the Select brush (« Select empty cells too », Disc brush), then press this.",
		_salle_de_la_selection, "salle", Palette.PRINCIPAL))
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
	# EXTRUDE, UNE SEULE FOIS (Jordan, 2 octobre 2026) : Extend up / down et Extrude ↑ ↓ de la sélection faisaient la
	# même chose sous deux noms ; ils ne font plus qu'un, et Maj / Alt étendent ou décalent la sélection
	# (`Etages.extruder`).
	var modes := ("
Click: adds matter, the selection and the floor plane follow — click again to keep going."
		+ "
Shift+click: extends the selection one cell that way, without adding matter."
		+ "
Alt+click: moves the selection one cell that way, without adding matter."
		+ "
Acts on the selection if there is one, otherwise on the matter of floor y.")
	var ops: Array = []
	for op in [
		["Extrude up", "haut", "extruder_haut", "One cell higher."],
		["Extrude down", "bas", "extruder_bas", "One cell lower."],
		["Widen", "elargir", "elargir", "Adds a ring around the cells, in their plane — the selection if there is "
			+ "one, otherwise floor y."],
		["Hollow", "creuser", "evider", "Removes the cells whose four horizontal neighbours are full — the "
			+ "selection if there is one, otherwise floor y."],
		["Extrude facing", "face", "extruder_face", "One cell away from the matter behind the cells — a wall "
			+ "thickens toward the air, a cave ceiling comes down."],
	]:
		if op[1] in ["haut", "bas", "face"]:
			ops.append(_bouton(op[0], op[3] + modes, _extruder_au_clic.bind(op[1]), op[2]))
		else:
			ops.append(_bouton(op[0], op[3], _operer.bind(op[1]), op[2]))
	etage.contenu.add_child(_grille(ops))
	# RÉPARER LES CONTACTS DIAGONAUX (Jordan, 3 octobre 2026 : « un bouton fix diagonals errors dans World ») — un
	# geste voulu, sur tout le monde visible ; le pinceau, lui, ne répare toujours rien de lui-même (§2).
	etage.contenu.add_child(_petit_titre("FIX DIAGONAL CONTACTS"))
	_boutons_diagonales = [
		_bouton("Fill", "Two cells that touch only by an edge make red cubes. Fill adds the two missing cells of each "
			+ "such square, in the active layer, everywhere in the visible world. One Ctrl+Z.",
			_reparer_les_diagonales.bind(false), "remplir"),
		_bouton("Dig", "Two cells that touch only by an edge make red cubes. Dig removes the two touching cells of each "
			+ "such square when both belong to the active layer (otherwise it fills), everywhere in the visible world. "
			+ "One Ctrl+Z.", _reparer_les_diagonales.bind(true), "creuser"),
	]
	etage.contenu.add_child(_rangee(_boutons_diagonales))
	etage.contenu.add_child(_bouton("Clear the layer", "Erases every cell of this layer (Ctrl+Z "
		+ "brings them back).", _effacer_tout, "gomme", Palette.DANGER))
	_batir_formes_speciales(pile)
	_variantes.batir_monde(pile)


## ── 4. LES FORMES SPÉCIALES (Jordan, 1er octobre 2026) — la règle vit dans `formes_speciales.gd`.
## Quatre boutons, comme des OUTILS : on en choisit un, on clique dans la vue. Les réglages ne montrent que
## ce que la forme choisie lit (le profil pour tunnel et puits, le garde-corps pour pont et balcon…).
func _batir_formes_speciales(pile: VBoxContainer) -> void:
	var sec := Section.new("Special shapes", true, Icones.icone("tunnel"))
	pile.add_child(sec)
	var choix := _rangee_de_choix(_boutons_forme_speciale, [
		["tunnel", "Tunnel", "tunnel", "Digs a tunnel into a WALL, straight in from it. Click a wall: it goes "
			+ "through to the next cave, or Depth cells deep.\nConnect: click a wall in one room, then a wall "
			+ "in another — even a slanted one."],
		["puits", "Well", "puits", "Digs a shaft into a FLOOR (or up into a ceiling), straight down. It stops "
			+ "in the first cave below, or Depth cells deep.\nConnect: a floor, then a ceiling of the room "
			+ "below."],
		["pont", "Bridge", "pont", "Builds a deck out of a WALL, across the air, to the first wall in front.\n"
			+ "Connect: two walls, even not facing each other — the deck bends."],
		["balcon", "Balcony", "balcon", "A slab sticking out of a WALL at the height you click, with its rail."],
		["escalier", "Stairs", "escalier", "Builds stairs against a WALL: click the wall where they should "
			+ "arrive; they come down towards you, Step cells per step, to the ground.\nConnect: click a floor, "
			+ "then another floor higher up — the stairs climb from one to the other."],
		["salle", "Room", "salle", "Drag a rectangle on the floor grid: a room rises from it (or sinks below it) "
			+ "Floors cells high inside — walls, floor and ceiling, hollow within. Inside rock, the inside is dug."],
	], _choisir_forme_speciale, Palette.OUTIL, 3)
	sec.contenu.add_child(choix)
	for b in _boutons_forme_speciale.values():
		(b as Button).set_pressed_no_signal(false)
	_reglages_forme = VBoxContainer.new()
	_reglages_forme.add_theme_constant_override("separation", 6)
	sec.contenu.add_child(_reglages_forme)
	_ligne_bouts = _rangee_de_choix(_boutons_bouts, [
		["droit", "Straight", "droit", "One click: straight out of the face you click, perpendicular to it."],
		["relier", "Connect", "relier", "Two clicks: a face, then another one. The shape leaves each face "
			+ "square to it and joins them; both ends stay open.\nRight click or Esc forgets the first end."],
	], _choisir_les_bouts)
	_reglages_forme.add_child(_ligne_bouts)
	_ligne_profil = _rangee_de_choix(_boutons_profil, [
		["rond", "Round", "profil_rond", "A round tube."],
		["carre", "Square", "profil_carre", "A square duct."],
		["arche", "Arch", "profil_arche", "A flat floor and a round vault: a corridor you can walk."],
	], _choisir_le_profil)
	_reglages_forme.add_child(_ligne_profil)
	var taille := HBoxContainer.new()
	taille.add_theme_constant_override("separation", 10)
	taille.add_child(_texte("Size", 12))
	_taille_forme = HSlider.new()
	_taille_forme.min_value = 1
	_taille_forme.max_value = 7
	_taille_forme.step = 1
	_taille_forme.tick_count = 7
	_taille_forme.ticks_on_borders = true
	_taille_forme.value = 2
	_taille_forme.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_taille_forme.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_taille_forme.tooltip_text = "[ and ] — the width: 1 is one cell, 2 is three cells across, 3 is five…"
	_valeur_taille_forme = _texte("2", 12, Palette.OLIVE)
	_valeur_taille_forme.add_theme_font_override("font", Palette.gras())
	_valeur_taille_forme.custom_minimum_size = Vector2(18, 0)
	_taille_forme.value_changed.connect(func(v: float) -> void:
		_vue.forme_speciale["taille"] = int(v)
		_valeur_taille_forme.text = str(int(v))
		_vue.rafraichir())
	taille.add_child(_taille_forme)
	taille.add_child(_valeur_taille_forme)
	_reglages_forme.add_child(taille)
	_ligne_taille_forme = taille
	# LA SALLE : sa hauteur libre, et le sens où elle s'étend depuis le rectangle tracé.
	# ⚠ DEUX LIGNES : les étages et Up / Down sur une seule débordaient à droite de la barre (vu à l'image).
	_ligne_salle = VBoxContainer.new()
	_ligne_salle.add_theme_constant_override("separation", 6)
	var ligne_etages := HBoxContainer.new()
	ligne_etages.add_theme_constant_override("separation", 8)
	ligne_etages.add_child(_texte("Floors", 12))
	_ligne_salle.add_child(ligne_etages)
	_etages_forme = SpinBox.new()
	_etages_forme.min_value = 1
	_etages_forme.max_value = FS.ETAGES_MAXI
	_etages_forme.value = int(_vue.forme_speciale["etages"])
	_etages_forme.tooltip_text = "[ and ] — how high the room is inside, in cells. Walls, floor and ceiling add one each."
	_etages_forme.value_changed.connect(func(v: float) -> void:
		_vue.forme_speciale["etages"] = int(v)
		if _etages_selection != null:
			_etages_selection.set_value_no_signal(v)
		_vue.rafraichir())
	_etages_forme.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne_etages.add_child(_etages_forme)
	_ligne_salle.add_child(_rangee_de_choix(_boutons_sens_salle, [
		["haut", "Up", "extruder_haut", "The rectangle is the floor: the room rises from it."],
		["bas", "Down", "extruder_bas", "The rectangle is the ceiling: the room sinks below it."],
	], func(v: String) -> void: _regler_le_sens_de_salle(v)))
	(_boutons_sens_salle["haut"] as Button).set_pressed_no_signal(true)
	_reglages_forme.add_child(_ligne_salle)
	var longueur := HBoxContainer.new()
	_ligne_longueur = longueur
	longueur.add_theme_constant_override("separation", 8)
	_etiquette_longueur = _texte("Depth", 12)
	longueur.add_child(_etiquette_longueur)
	_longueur_forme = SpinBox.new()
	_longueur_forme.min_value = 1
	_longueur_forme.max_value = FS.LONGUEUR_MAXI
	_longueur_forme.value = 8
	_longueur_forme.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_longueur_forme.value_changed.connect(func(v: float) -> void:
		_vue.forme_speciale["longueur"] = int(v)
		_vue.rafraichir())
	longueur.add_child(_longueur_forme)
	_reglages_forme.add_child(longueur)
	var pas := HBoxContainer.new()
	_ligne_pas = pas
	pas.add_theme_constant_override("separation", 8)
	pas.add_child(_texte("Step", 12))
	_pas_forme = SpinBox.new()
	_pas_forme.min_value = 1
	_pas_forme.max_value = FS.PAS_MAXI
	_pas_forme.value = 2
	_pas_forme.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pas_forme.tooltip_text = "How deep each step is, in cells: 1 is steep, %d is gentle." % FS.PAS_MAXI
	_pas_forme.value_changed.connect(func(v: float) -> void:
		_vue.forme_speciale["pas"] = int(v)
		_vue.rafraichir())
	pas.add_child(_pas_forme)
	_reglages_forme.add_child(pas)
	_garde_corps = CheckButton.new()
	_garde_corps.text = "Rail"
	_garde_corps.button_pressed = true
	_garde_corps.tooltip_text = "A one-cell rim along the open sides. Needs a size of 2 or more."
	_garde_corps.toggled.connect(func(v: bool) -> void:
		_vue.forme_speciale["garde_corps"] = v
		_vue.rafraichir())
	_reglages_forme.add_child(_garde_corps)
	_aide_forme = _texte("", 11, Palette.GRIS)
	_aide_forme.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sec.contenu.add_child(_aide_forme)


## ── 5. LES FLUIDES (Jordan, 1er octobre 2026 ; charte §5, « le mode Fluids ») — la règle vit dans `fluides.gd`.
##
## ⚠ **ON N'ENREGISTRE QUE LES SOURCES** : un clic en pose une dans la couche d'eau ACTIVE ; lacs, rivières et
## océans s'en REDÉDUISENT à chaque changement de cases (`_eau_perimee`) — c'est ce qui fait suivre la coulée en
## temps réel quand on modifie le monde.
## ⚠ **L'EAU APPARTIENT AU MONDE ENTIER** (DÉCIDÉ) : ses couches sont les siennes, indépendantes des couches de
## tuiles, et elle se calcule contre les cases de TOUTES les couches de tuiles, cachées comprises (PROPOSÉ) —
## cacher une couche pour travailler ne doit pas inonder le monde.
##
## ⚠ **UN ATELIER, PLUS UNE SECTION DE WORLD (Jordan, 2 octobre 2026 : « le mode Fluids aurait dû être un mode
## plutôt qu'une section, et devrait se désactiver proprement quand on le demande »)**. Le bouton Water, enfoncé,
## ne se relâchait plus (son clic le ré-enfonçait) : on restait à poser de l'eau. Désormais entrer dans Fluids
## prend l'outil Water ; en sortir (Échap, « Leave », un autre atelier) rend l'outil de World d'avant.
func _batir_fluides(pile: VBoxContainer) -> void:
	var sec := Section.new("Fluids", true, Icones.icone("eau"))
	pile.add_child(sec)
	_aide_eau = _texte("", 11, Palette.GRIS)
	_aide_eau.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aide_eau.text = ("One click places water, and the world decides what it becomes: in a hollow, a LAKE filled "
		+ "to its brim; on a slope or a ledge, a RIVER that runs down, falls, and fills the hollows on its way; in "
		+ "the open air, over nothing, a SEA: a plane shows its height, a first click pins it, the mouse wheel or "
		+ "PgUp / PgDn moves it, and a second click (or Enter) places it — nothing is computed before. Right click "
		+ "on water removes it.\n"
		+ "Lakes, rivers and seas follow the world: dig a channel, raise a dam — the water flows again.")
	sec.contenu.add_child(_aide_eau)
	sec.contenu.add_child(_bouton("Leave", "Back to World and its painting tools (Esc).",
		_changer_d_atelier.bind("monde"), "croix"))
	# LA LARGEUR D'UNE RIVIÈRE À LA POSE (Jordan, 3 octobre 2026) : plusieurs sources côte à côte, en travers du courant.
	var ligne_largeur := HBoxContainer.new()
	ligne_largeur.add_theme_constant_override("separation", 8)
	var lib := _texte("River width", 12)
	lib.tooltip_text = ("A river (and its waterfalls) this many cells wide: as many sources side by side, across the "
		+ "flow. Lakes and the sea are not affected.")
	lib.mouse_filter = Control.MOUSE_FILTER_PASS
	ligne_largeur.add_child(lib)
	_largeur_eau = HSlider.new()
	_largeur_eau.min_value = 1
	_largeur_eau.max_value = 9
	_largeur_eau.step = 1
	_largeur_eau.value = 1
	_largeur_eau.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_largeur_eau.focus_mode = Control.FOCUS_NONE
	var val := _texte("1", 12)
	_largeur_eau.value_changed.connect(func(v: float) -> void:
		val.text = str(int(v))
		_cle_apercu_eau = "")
	ligne_largeur.add_child(_largeur_eau)
	ligne_largeur.add_child(val)
	sec.contenu.add_child(ligne_largeur)
	sec.contenu.add_child(_petit_titre("WATER LAYERS"))
	_liste_eaux = VBoxContainer.new()
	_liste_eaux.add_theme_constant_override("separation", 4)
	sec.contenu.add_child(_liste_eaux)
	_bouton_supprimer_eau = _bouton("Delete", "Deletes the active water layer and its water (Ctrl+Z brings it back).",
		_supprimer_eau, "poubelle", Palette.DANGER)
	sec.contenu.add_child(_rangee([
		_bouton("New", "A new water layer: its own lakes, rivers and seas, shown or hidden together.",
			_nouvelle_eau, "plus"),
		_bouton_supprimer_eau,
	], 4))
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 8)
	ligne.add_child(_texte("Look", 12))
	_preset_eau = OptionButton.new()
	_preset_eau.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for p in EauPresets.PRESETS:
		_preset_eau.add_item(EauPresets.NOMS[p])
	_preset_eau.item_selected.connect(func(i: int) -> void:
		if not _eaux.is_empty():
			_eaux[_eau_active]["preset"] = EauPresets.PRESETS[i]
			_eau_perimee()
			_enregistrer_plus_tard())
	ligne.add_child(_preset_eau)
	sec.contenu.add_child(ligne)
	var note := _texte("These looks are examples, not a requirement: in your engine you can assign your own "
		+ "water shader from the plugin. It receives the same data — flow, kind of water, depth.", 11, Palette.GRIS)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sec.contenu.add_child(note)
	_rafraichir_eaux()


## En entrant dans Fluids : l'outil devient l'eau, l'outil de World est retenu.
func _entrer_dans_les_fluides() -> void:
	if _vue.outil != "eau":
		_outil_avant_fluides = _vue.outil
	_vue.outil = "eau"
	_vue.oublier_ancre()
	if not _vue.collage.is_empty():
		_vue.annuler_collage()
	_basculer_navigation(false)
	# Il faut une couche d'eau où poser la source.
	if _eaux.is_empty():
		_ajouter_eau(Projet.couche_d_eau("Water 1"))
	_vue.rafraichir()
	_dire("[b]Fluids[/b] — click in a hollow (lake), on a slope or a ledge (river), or in the open air over "
		+ "nothing (sea: choose its height, then click again). [i]Right click on water removes it. Esc to go back "
		+ "to World.[/i]")


## L'ATELIER TRANSITIONS (6 octobre 2026) : l'outil « transition » (le pinceau de la vue), la barre redite.
var _outil_avant_transitions := "ajouter"


func _entrer_dans_les_transitions() -> void:
	if _vue.outil != "transition":
		_outil_avant_transitions = _vue.outil
	_vue.outil = "transition"
	_vue.oublier_ancre()
	if not _vue.collage.is_empty():
		_vue.annuler_collage()
	_basculer_navigation(false)
	_transitions.dire(true)
	_vue.rafraichir()
	_dire("[b]Transitions[/b] — tick a pair of layers to blend their border; click near a border to choose which "
		+ "covers there, right click for the priority. [i]Esc goes back to World.[/i]")


func _sortir_des_transitions() -> void:
	if _vue.outil != "transition":
		return
	_vue.outil = _outil_avant_transitions if _outil_avant_transitions != "transition" else "ajouter"
	_vue.oublier_ancre()
	if _vue.outil == "forme":
		(_boutons_forme_speciale[_vue.forme_speciale["quoi"]] as Button).set_pressed_no_signal(true)
	elif _boutons_outil.has(_vue.outil):
		(_boutons_outil[_vue.outil] as Button).set_pressed_no_signal(true)
	_contexte_des_outils()
	_vue.rafraichir()


## En sortant de Fluids : l'outil de World d'avant revient, et plus rien ne pose d'eau.
func _sortir_des_fluides() -> void:
	if _vue.outil != "eau":
		return
	_vue.outil = _outil_avant_fluides if _outil_avant_fluides != "eau" else "ajouter"
	_vue.oublier_ancre()
	_annuler_la_mer(false)
	_vue.montrer_plan_mer(null)
	_cle_apercu_eau = ""
	_eau_survolee(null)
	if _vue.outil == "forme":
		(_boutons_forme_speciale[_vue.forme_speciale["quoi"]] as Button).set_pressed_no_signal(true)
	elif _boutons_outil.has(_vue.outil):
		(_boutons_outil[_vue.outil] as Button).set_pressed_no_signal(true)
	_contexte_des_outils()
	_vue.rafraichir()


## L'EAU OÙ L'ON NAGE (Play test) : l'eau DORMANTE des couches d'eau VISIBLES — lacs, lacs des rivières, océans —
## et les niveaux des océans pour le large. Une rivière n'en est pas : sa bande est une lame, on y marche.
func _eau_pour_le_jeu() -> Dictionary:
	if _eau_a_refaire or _corps_eau.size() != _eaux.size():
		_recalculer_eau(false)
	# Chaque case porte le PRESET de sa couche d'eau : le voile sous la surface dépend du liquide (lave, marais…).
	var cases := {}
	var courants := {}
	var oceans: Array = []
	var preset_ocean := ""
	var plus_haut := -2147483647
	for i in mini(_eaux.size(), _corps_eau.size()):
		if not bool(_eaux[i]["visible"]):
			continue
		var preset: String = _eaux[i]["preset"]
		for r in _corps_eau[i]:
			if r["erreur"] != "":
				continue
			var a_poser: Array = []
			if r["genre"] == "ocean":
				oceans.append(int(r["niveau"]))
				if int(r["niveau"]) > plus_haut:
					plus_haut = int(r["niveau"])
					preset_ocean = preset
			if r["genre"] in ["ocean", "lac"]:
				a_poser.append(r["eau"])
			else:
				for lac in r["lacs"]:
					a_poser.append(lac["cases"])
				# LE COURANT (3 octobre 2026) : sur la bande d'une rivière, il pousse le personnage.
				courants.merge(EauMaillage.courants(r["cours"], _occ_eau))
			for d in a_poser:
				for c in d:
					cases[c] = preset
	if cases.is_empty() and oceans.is_empty() and courants.is_empty():
		return {}
	return {"cases": cases, "oceans": oceans, "preset_ocean": preset_ocean, "boite": _boite_eau(),
		"courants": courants}


## La boîte du monde pour `_occ_eau`, recalculée seulement si `_occ_eau` a changé (voir `_boite_eau_cache`).
## ⚠ `_occ_eau` est retouché EN PLACE par `_recalculer_eau`, qui remet le cache : la taille ne garde que le reste.
func _boite_eau() -> Dictionary:
	if not is_same(_boite_eau_de, _occ_eau) or _boite_eau_taille != _occ_eau.size():
		_boite_eau_cache = FL.boite(_occ_eau)
		_boite_eau_de = _occ_eau
		_boite_eau_taille = _occ_eau.size()
	return _boite_eau_cache


func _dans_le_vide(s: Vector3i) -> bool:
	return not _occ_eau.has(s) and FL.dans_le_vide(_occ_eau, s, _boite_eau())


## Les cases de toutes les couches de tuiles : l'eau appartient au monde entier.
func _occupees_du_monde() -> Dictionary:
	var occ := {}
	for i in _vue.nombre_de_couches():
		for c in (_vue.couche(i).get_node("Cases") as GridMap).get_used_cells():
			occ[c] = true
	return occ


## Les cases pleines qui ont changé depuis le dernier calcul de l'eau. ⚠ CHAQUE GESTE LES CONNAÎT (2 octobre 2026) :
## relire les ~196 000 cases de l'exemple dans les grilles puis les comparer à l'état d'avant coûtait ~150 ms à CHAQUE
## geste, pour en retrouver une. `_eau_cases_inconnues` : un changement dont on ne sait pas les cases (une couche
## détachée ou rendue) — on relit tout.
var _eau_changees := {}
var _eau_cases_inconnues := false


func _noter_pour_l_eau(cases_: Array) -> void:
	for c in cases_:
		_eau_changees[c] = true


## LES CASES DU MONDE À JOUR POUR L'EAU, SANS RECALCULER L'EAU (4 octobre 2026). ⚠ UN CLIC SE CLASSAIT CONTRE DES CASES
## EN RETARD : `_occ_eau` ne suivait les gestes qu'au recalcul différé, et un clic sur une colonne posée dans la même
## image la voyait vide — la source se croyait « dans le vide » (une mer), et ne devenait la rivière voulue qu'au
## recalcul. Le survol et le clic l'appellent ; ce qu'il applique reste noté pour la reprise (`_eau_changees_vues`).
var _eau_changees_vues := {}
var _eau_tout_refaire := false


## LA BOÎTE DANS LES COMPTES PAR AXE (4 octobre 2026) : une case retirée au bord de la boîte (retirer le sommet du
## monde, l'annulation d'un ajout là) la faisait rebalayer — `FL.boite` sur les 739 483 cases de l'exemple : ~240 ms à
## chaque fois. `_eau_par_axe` = [{x: combien}, {y: …}, {z: …}] des cases de `_occ_eau`, bâti à la PREMIÈRE case retirée
## au bord (un balayage, comme avant), puis tenu case par case ; la boîte en est les clés extrêmes, élargies d'une case
## (la règle de `FL.boite`). Il ne vaut que pour le dictionnaire d'où il vient (`_eau_par_axe_de`).
var _eau_par_axe: Array = []
var _eau_par_axe_de: Dictionary = {}


func _compter_sur_les_axes(c: Vector3i, sens: int) -> void:
	if not is_same(_eau_par_axe_de, _occ_eau) or _eau_par_axe.is_empty():
		return
	for k in 3:
		var d: Dictionary = _eau_par_axe[k]
		var n: int = int(d.get(c[k], 0)) + sens
		if n > 0:
			d[c[k]] = n
		else:
			d.erase(c[k])


## Rend vrai et pose la boîte si elle a pu être relue dans les comptes (bâtis s'il le faut).
func _boite_par_les_axes() -> bool:
	if _occ_eau.is_empty():
		return false
	if not is_same(_eau_par_axe_de, _occ_eau) or _eau_par_axe.is_empty():
		_eau_par_axe = _axes_des_couches()
		if _eau_par_axe.is_empty():
			_eau_par_axe = [{}, {}, {}]
			for c: Vector3i in _occ_eau:
				for k in 3:
					_eau_par_axe[k][c[k]] = int(_eau_par_axe[k].get(c[k], 0)) + 1
		_eau_par_axe_de = _occ_eau
	var lo := Vector3i.ZERO
	var hi := Vector3i.ZERO
	for k in 3:
		var cles: Array = (_eau_par_axe[k] as Dictionary).keys()
		lo[k] = cles.min() - 1
		hi[k] = cles.max() + 1
	_boite_eau_cache = {"lo": lo, "hi": hi}
	_boite_eau_de = _occ_eau
	_boite_eau_taille = _occ_eau.size()
	return true


## Les comptes par axe bâtis depuis ce que CHAQUE COUCHE tient déjà (par étage, par colonne — `MassifPeint`) : quelques
## dizaines de milliers d'entrées au lieu des 739 483 cases (bâtis case par case : ~600 ms). [] si une couche ne peut pas
## le garantir (pas encore bâtie, en attente d'être refaite) ou si le total n'est pas celui de `_occ_eau`.
func _axes_des_couches() -> Array:
	var axes: Array = [{}, {}, {}]
	var total := 0
	for i in _vue.nombre_de_couches():
		var tenus = _vue.couche(i).comptes_tenus()
		if tenus == null:
			return []
		var etages: Dictionary = tenus[0]
		var colonnes: Dictionary = tenus[1]
		for y in etages:
			axes[1][y] = int(axes[1].get(y, 0)) + int(etages[y])
			total += int(etages[y])
		for k2: Vector2i in colonnes:
			var n: int = colonnes[k2]
			axes[0][k2.x] = int(axes[0].get(k2.x, 0)) + n
			axes[2][k2.y] = int(axes[2].get(k2.y, 0)) + n
	return axes if total == _occ_eau.size() else []


func _tenir_occ_eau() -> void:
	if _occ_eau.is_empty() or _eau_cases_inconnues:
		var occ_avant := _occ_eau
		_occ_eau = _occupees_du_monde()
		if occ_avant.is_empty():
			_eau_tout_refaire = true
		else:
			_eau_changees_vues.merge(FL.changees_entre(occ_avant, _occ_eau))
		_eau_cases_inconnues = false
	elif not _eau_changees.is_empty():
		# ⚠ LA BOÎTE SUIT LES GESTES (4 octobre 2026) : la recalculer balaie toutes les cases (~70 ms sur l'exemple, à
		# chaque geste). Une case posée l'élargit ; une case retirée ne la change que si elle touchait son bord — alors
		# seulement elle est refaite. Une boîte NEUVE (jamais retouchée en place : les corps d'eau gardent la leur).
		var tenue := is_same(_boite_eau_de, _occ_eau) and _boite_eau_taille == _occ_eau.size() \
			and not _boite_eau_cache.is_empty()
		var lo: Vector3i = _boite_eau_cache["lo"] if tenue else Vector3i.ZERO
		var hi: Vector3i = _boite_eau_cache["hi"] if tenue else Vector3i.ZERO
		for c in _eau_changees:
			_eau_changees_vues[c] = true
			var plein := false
			for i in _vue.nombre_de_couches():
				if (_vue.couche(i).get_node("Cases") as GridMap).get_cell_item(c) != GridMap.INVALID_CELL_ITEM:
					plein = true
					break
			if plein:
				if not _occ_eau.has(c):
					_occ_eau[c] = true
					_compter_sur_les_axes(c, 1)
				lo = Vector3i(mini(lo.x, c.x - 1), mini(lo.y, c.y - 1), mini(lo.z, c.z - 1))
				hi = Vector3i(maxi(hi.x, c.x + 1), maxi(hi.y, c.y + 1), maxi(hi.z, c.z + 1))
			elif _occ_eau.has(c):
				_occ_eau.erase(c)
				_compter_sur_les_axes(c, -1)
				if c.x <= lo.x + 1 or c.y <= lo.y + 1 or c.z <= lo.z + 1 \
						or c.x >= hi.x - 1 or c.y >= hi.y - 1 or c.z >= hi.z - 1:
					tenue = false
		if tenue and not _occ_eau.is_empty():
			_boite_eau_cache = {"lo": lo, "hi": hi}
			_boite_eau_taille = _occ_eau.size()
		elif _boite_par_les_axes():
			pass   # une case retirée au bord : la boîte relue dans les comptes par axe, sans rebalayer le monde
		else:
			_boite_eau_taille = -1   # retouché en place : la boîte est à refaire
	_eau_changees = {}


## L'eau est à redéduire. ⚠ UNE FOIS PAR IMAGE au plus : un coup de pinceau touche des dizaines de cases.
func _eau_perimee() -> void:
	if _eau_a_refaire:
		return
	_eau_a_refaire = true
	_recalculer_eau.call_deferred()


## `avec_barre` : sur un grand monde (la dernière fois plus de `SEUIL_ATTENTE`), hors d'un coup de pinceau, le panneau
## d'attente le dit. ⚠ FAUX pour qui lit le résultat juste après (le Play test, l'export) : il doit rester synchrone.
func _recalculer_eau(avec_barre := true) -> void:
	_eau_a_refaire = false
	if _vue == null:
		return
	var toutes: Array = []
	for e in _eaux:
		toutes.append_array(e["sources"])
	# ⚠ SANS SOURCE, RIEN À DÉDUIRE (audit, 1er octobre 2026) : chaque coup de pinceau relisait le monde entier et
	# reposait des nappes vides. Une fois vidées, on ne refait rien tant qu'aucune source n'apparaît.
	if toutes.is_empty() and _eau_vide and _corps_eau.size() == _eaux.size():
		return
	var montrer := avec_barre and _ecran_vivant() and _coup.is_empty() \
		and (float(_durees.get("eau", 0.0)) >= SEUIL_ATTENTE or _eau_barre_forcee)
	_eau_barre_forcee = false
	if montrer:
		await _attendre("Water", "lakes, rivers and seas follow the world")
	var debut := Time.get_ticks_msec()
	# ⚠ LA REPRISE (2 octobre 2026) : seules les sources dont un geste a touché l'emprise sont recalculées. Les cases
	# du monde sont tenues à jour par les gestes eux-mêmes (`_noter_pour_l_eau`) ; relues en entier seulement au
	# premier calcul, ou quand on ne sait pas ce qui a changé.
	var changees: Variant = null
	if toutes.is_empty():
		_occ_eau = {}
	else:
		_tenir_occ_eau()
		changees = null if _eau_tout_refaire else _eau_changees_vues
	_eau_changees = {}
	_eau_changees_vues = {}
	_eau_tout_refaire = false
	_eau_cases_inconnues = false
	var w: Dictionary = FL.monde(_occ_eau, toutes, FL.VOLUME_MAXI, _monde_eau, changees, _boite_eau())
	_monde_eau = w
	_boite_eau_cache = w["boite"]
	_boite_eau_de = _occ_eau
	_boite_eau_taille = _occ_eau.size()
	_ocean_eau = w["ocean"]
	_corps_eau.clear()
	_index_eau.clear()
	var nappes: Array = []
	var maillages: Array = []
	var k := 0
	for i in _eaux.size():
		var e: Dictionary = _eaux[i]
		var n: int = (e["sources"] as Array).size()
		var corps: Array = (w["corps"] as Array).slice(k, k + n)
		k += n
		_corps_eau.append(corps)
		# L'INDEX DE `_eau_sous` : chaque case de lac et de rivière → [couche, source] (l'océan, immense, se
		# consulte à part).
		for j in corps.size():
			var r: Dictionary = corps[j]
			if r["erreur"] != "" or r["genre"] == "ocean":
				continue
			for c in r["eau"]:
				_index_eau[c] = [i, j]
			for ec in r["cours"]:
				_index_eau[ec["case"]] = [i, j]
		var preset: String = e["preset"]
		if not _materiaux_eau.has(preset):
			_materiaux_eau[preset] = EauPresets.materiau(preset)
		# Le maillage d'une couche dont tous les corps sont repris est repris aussi : il ne lit que leurs emprises.
		# ⚠ UN CORPS EN ERREUR N'EST JAMAIS REPRIS PAR `FL.monde` (il est refait à chaque geste), mais il ne dessine rien :
		# deux corps tous deux en erreur se valent. Sans cela, une seule source refusée (une seconde mer, une rivière
		# sans issue) faisait remailler TOUTE sa couche après chaque geste — ~0,9 s sur l'exemple (4 octobre 2026).
		var m: ArrayMesh = null
		if i < _maillages_eau.size() and (_maillages_eau[i][0] as Array).size() == corps.size() \
				and range(corps.size()).all(func(j): return _meme_corps_dessine(_maillages_eau[i][0][j], corps[j])):
			m = _maillages_eau[i][1]
		else:
			while _nappes_memoire.size() <= i:
				_nappes_memoire.append({})
			m = EauMaillage.maillage(corps, _occ_eau, w["boite"], _nappes_memoire[i])
		maillages.append([corps, m])
		nappes.append([m, _materiaux_eau[preset], bool(e["visible"])])
	_maillages_eau = maillages
	_vue.poser_eaux(nappes)
	_eau_vide = toutes.is_empty()
	_durees["eau"] = (Time.get_ticks_msec() - debut) / 1000.0
	_cle_apercu_eau = ""
	_rafraichir_eaux()
	if montrer:
		_fin_attente()


## Les rectangles de nappe de chaque corps, par couche d'eau (`EauMaillage.maillage`, `memoire`).
var _nappes_memoire: Array = []


## Deux corps d'eau dessinent-ils la même chose ? Le même objet (repris par `FL.monde`), ou deux erreurs (rien).
static func _meme_corps_dessine(a: Variant, b: Variant) -> bool:
	if is_same(a, b):
		return true
	return a != null and b != null and str(a["erreur"]) != "" and str(b["erreur"]) != ""


## Le corps d'eau qui contient la case `s`, ou une case sous elle jusqu'au sol : [couche, source], ou [].
func _eau_sous(s: Vector3i) -> Array:
	var c := s
	for _pas in 64:
		# ⚠ PAR L'INDEX (bâti à chaque recalcul) : parcourir chaque corps, chaque cours, à chaque case de la descente
		# et à chaque mouvement de souris coûtait ce que coûtent tous les cours réunis (audit).
		if _index_eau.has(c):
			return _index_eau[c]
		for i in _corps_eau.size():
			for j in (_corps_eau[i] as Array).size():
				var r: Dictionary = _corps_eau[i][j]
				if r["erreur"] == "" and r["genre"] == "ocean" and (r["eau"] as Dictionary).has(c):
					return [i, j]
		if _occ_eau.has(c + Vector3i.DOWN):
			break
		c += Vector3i.DOWN
	return []


## L'APERÇU : ce qu'un clic poserait — ou, sur de l'eau, l'eau qu'un clic droit retirerait.
## ⚠ **LA MER NE SE CALCULE PAS AU SURVOL (Jordan, 4 octobre 2026 : « les opérations d'eau coûtent trop cher, surtout
## pour l'océan »)** : survoler le vide remplissait l'océan entier à chaque case visée. Le vide montre désormais un PLAN
## à la hauteur de la mer qu'un clic poserait — rien n'est calculé —, et une mer déjà là, son plan en rouge.
func _eau_survolee(s: Variant) -> void:
	if _mer_choisie != null:
		return   # le plan est épinglé : la souris ne le déplace plus (la molette, PgUp / PgDn)
	if s == null:
		_vue.montrer_apercu([], Vue.TEINTE_EAU)
		_vue.montrer_plan_mer(null)
		return
	var cle := str(s)
	if cle == _cle_apercu_eau:
		return
	_cle_apercu_eau = cle
	_tenir_occ_eau()
	var deja := _eau_sous(s)
	if not deja.is_empty():
		var corps: Dictionary = _corps_eau[deja[0]][deja[1]]
		if corps["genre"] == "ocean":
			_vue.montrer_apercu([], Vue.TEINTE_EAU)
			_vue.montrer_plan_mer(int(corps["niveau"]), _boite_eau(), Vue.TEINTE_CREUSER)
		else:
			_vue.montrer_plan_mer(null)
			_vue.montrer_apercu(_cases_d_un_corps(corps), Vue.TEINTE_CREUSER)
		return
	if _dans_le_vide(s):
		_vue.montrer_apercu([], Vue.TEINTE_EAU)
		_vue.montrer_plan_mer((s as Vector3i).y, _boite_eau(), Vue.TEINTE_EAU)
		return
	_vue.montrer_plan_mer(null)
	var r: Dictionary = FL.source(_occ_eau, s, _ocean_eau, FL.VOLUME_MAXI, _boite_eau())
	if r["erreur"] != "":
		_vue.montrer_apercu([s], Vue.TEINTE_CREUSER)
		return
	var montrees := _cases_d_un_corps(r)
	for c in _sources_a_poser(s).slice(1):
		montrees.append_array(_cases_d_un_corps(FL.source(_occ_eau, c, _ocean_eau, FL.VOLUME_MAXI, _boite_eau())))
	_vue.montrer_apercu(montrees, Vue.TEINTE_EAU)


## LA LARGEUR À LA POSE (Jordan, 3 octobre 2026) : les sources d'une rivière de `River width` cases
## (`FL.sources_en_largeur`), sans celles qui tombent dans une eau déjà là.
func _sources_a_poser(s: Vector3i) -> Array:
	var largeur := int(_largeur_eau.value) if _largeur_eau != null else 1
	return FL.sources_en_largeur(_occ_eau, s, largeur, _ocean_eau, _boite_eau()).filter(
		func(c: Vector3i) -> bool: return c == s or _eau_sous(c).is_empty())


## Ce qu'on montre d'un corps : sa surface (un océan n'a pas à montrer tout son volume) et son cours.
func _cases_d_un_corps(r: Dictionary) -> Array:
	var montrees: Array = FL.surface(r["eau"], _occ_eau)
	for e in r["cours"]:
		if e["genre"] != "lac":
			montrees.append(e["case"])
	return montrees


func _eau_cliquee(s: Variant, bouton: int) -> void:
	# LA MER EN CHOIX : un clic gauche la pose (le calcul ne part qu'ici), un clic droit l'abandonne.
	if _mer_choisie != null:
		if bouton == MOUSE_BUTTON_LEFT:
			_valider_la_mer()
		else:
			_annuler_la_mer()
		return
	if s == null:
		return
	_tenir_occ_eau()
	if bouton == MOUSE_BUTTON_RIGHT:
		var deja := _eau_sous(s)
		if deja.is_empty():
			_dire("[i]No water here to remove.[/i]")
			return
		var e: Dictionary = _eaux[deja[0]]
		var source: Vector3i = e["sources"][deja[1]]
		_histoire.create_action("Water: remove")
		_histoire.add_do_method(_oter_source.bind(e, deja[1]))
		_histoire.add_undo_method(_remettre_source.bind(e, deja[1], source))
		_histoire.commit_action()
		_dire("[b]Water removed[/b] from « %s ». [i]Ctrl+Z brings it back.[/i]" % e["nom"])
		return
	if _eaux.is_empty():
		_ajouter_eau(Projet.couche_d_eau("Water 1"))
	# ⚠ UN SEUL OCÉAN, À UN SEUL NIVEAU (Jordan, 3 octobre 2026) : un clic dans le vide CHOISIT la hauteur de la mer
	# (4 octobre 2026) — le plan s'épingle, la molette et PgUp / PgDn le montent ou le descendent, et seul le second clic
	# (ou Entrée) la pose et lance le calcul.
	if _dans_le_vide(s):
		_choisir_la_mer(s)
		return
	if not _eau_sous(s).is_empty():
		_dire("[i]There is water here already.[/i] Right click removes it.")
		return
	var r: Dictionary = FL.source(_occ_eau, s, _ocean_eau, FL.VOLUME_MAXI, _boite_eau())
	if r["erreur"] != "":
		_dire("[color=#e0603c]Water[/color] — %s" % {
			"dans_la_matiere": "this cell is inside the matter.",
			"dans_l_eau": "there is sea here already. Right click removes it.",
			"trop_grand": "too large to fill (more than %d cells)." % FL.VOLUME_MAXI,
			"trop_long": "this river is too long to follow.",
		}.get(r["erreur"], r["erreur"]))
		return
	var e: Dictionary = _eaux[_eau_active]
	var sources := _sources_a_poser(s)
	_histoire.create_action("Water: " + {"ocean": "sea", "lac": "lake", "riviere": "river"}[r["genre"]])
	_histoire.add_do_method(_poser_sources.bind(e, sources))
	_histoire.add_undo_method(_oter_sources.bind(e, (e["sources"] as Array).size(), sources.size()))
	_histoire.commit_action()
	_dire(_dire_un_corps(r) + (" [b]%d cells wide[/b] (%d sources side by side)." % [sources.size(), sources.size()]
		if sources.size() > 1 else "") + " [i]Ctrl+Z undoes it.[/i]")


## Les sources de mer de toutes les couches d'eau : [[couche, indice, source]], dans l'ordre.
func _sources_de_mer() -> Array:
	var sortie: Array = []
	for e in _eaux:
		for i in (e["sources"] as Array).size():
			var src: Vector3i = e["sources"][i]
			if _dans_le_vide(src):
				sortie.append([e, i, src])
	return sortie


## LE CHOIX DE LA HAUTEUR DE LA MER : le plan s'épingle à la hauteur cliquée, rien n'est calculé.
func _choisir_la_mer(s: Vector3i) -> void:
	_mer_case = s
	_mer_choisie = s.y
	_vue.montrer_apercu([], Vue.TEINTE_EAU)
	_montrer_la_mer_choisie()


func _montrer_la_mer_choisie() -> void:
	var h: int = _mer_choisie
	_vue.montrer_plan_mer(h, _boite_eau(), Vue.TEINTE_EAU)
	var anciennes := _sources_de_mer()
	var ici := ""
	if anciennes.size() == 1 and (anciennes[0][2] as Vector3i).y == h:
		ici = " [i]The sea is already at this height.[/i]"
	elif not anciennes.is_empty():
		ici = " (the sea is now at height %d)" % (anciennes[0][2] as Vector3i).y
	_dire(("[b]Sea at height %d[/b]%s — [b]mouse wheel[/b] or [b]PgUp / PgDn[/b] raises or lowers it. [b]Click[/b] or "
		+ "[b]Enter[/b] places it (the water is computed only then); right click or Esc cancels.") % [h, ici])


## Un cran de hauteur pendant le choix (molette, PgUp / PgDn).
func _hausser_la_mer(sens: int) -> void:
	_mer_choisie = clampi(int(_mer_choisie) + sens, -64, 192)
	_vue.montrer_valeur("Sea height %d" % _mer_choisie)
	_montrer_la_mer_choisie()


func _annuler_la_mer(dire := true) -> void:
	if _mer_choisie == null:
		return
	_mer_choisie = null
	_cle_apercu_eau = ""
	_vue.montrer_plan_mer(null)
	if dire:
		_dire("[i]Sea cancelled: nothing was placed.[/i]")


## La mer à la hauteur choisie. Sa source est la colonne cliquée si elle reste dans le vide à cette hauteur (un surplomb
## au-dessus d'elle ne le serait plus), sinon une colonne juste hors de la boîte du monde — vide par construction.
func _valider_la_mer() -> void:
	var h: int = _mer_choisie
	_mer_choisie = null
	_cle_apercu_eau = ""
	_vue.montrer_plan_mer(null)
	var s := Vector3i(_mer_case.x, h, _mer_case.z)
	if not _dans_le_vide(s):
		var b := _boite_eau()
		if not b.is_empty():
			s = Vector3i((b["lo"] as Vector3i).x - 1, h, (b["lo"] as Vector3i).z - 1)
	_poser_la_mer(s)


## La mer à la hauteur de `s` : la seule. Les autres sources de mer partent dans la même action.
## ⚠ Rien n'est calculé ici : la mer posée, `_eau_perimee` refait l'eau UNE fois, avec la barre d'attente.
func _poser_la_mer(s: Vector3i) -> void:
	var anciennes := _sources_de_mer()
	if anciennes.size() == 1 and (anciennes[0][2] as Vector3i).y == s.y:
		_dire("[i]The sea is already at height %d.[/i] Click higher or lower in the open air to move it; right click "
			% s.y + "on it removes it.")
		return
	var e: Dictionary = _eaux[_eau_active]
	_eau_barre_forcee = true
	_histoire.create_action("Water: sea at height %d" % s.y)
	_histoire.add_do_method(_changer_la_mer.bind(anciennes, e, s))
	_histoire.add_undo_method(_rendre_la_mer.bind(anciennes, e))
	_histoire.commit_action()
	var partie := ""
	if not anciennes.is_empty():
		partie = " The sea that was at height %d is gone: [i]there is only one sea.[/i]" % (anciennes[0][2] as Vector3i).y
	_dire(_dire_un_corps({"genre": "ocean", "niveau": s.y}) + partie + " [i]Ctrl+Z undoes it.[/i]")


func _changer_la_mer(anciennes: Array, e: Dictionary, s: Vector3i) -> void:
	for k in range(anciennes.size() - 1, -1, -1):
		(anciennes[k][0]["sources"] as Array).remove_at(anciennes[k][1])
	(e["sources"] as Array).append(s)
	_eau_perimee()


func _rendre_la_mer(anciennes: Array, e: Dictionary) -> void:
	(e["sources"] as Array).remove_at((e["sources"] as Array).size() - 1)
	for k in anciennes.size():
		(anciennes[k][0]["sources"] as Array).insert(anciennes[k][1], anciennes[k][2])
	_eau_perimee()


func _dire_un_corps(r: Dictionary) -> String:
	match r["genre"]:
		"ocean":
			return "[b]Sea[/b] at height %d — it surrounds the matter as far as you can see." % r["niveau"]
		"lac":
			return "[b]Lake[/b] — %d cell(s), filled to its brim (height %d).%s" % [(r["eau"] as Dictionary).size(),
				r["niveau"], " A closed cave: it fills up to where you clicked." if r["fin"] == "ferme" else ""]
	var coule := 0
	var chutes := 0
	for i in (r["cours"] as Array).size():
		var e: Dictionary = r["cours"][i]
		if e["genre"] == "coule":
			coule += 1
		elif e["genre"] == "chute" and (i == 0 or r["cours"][i - 1]["genre"] != "chute"):
			chutes += 1
	var lacs: int = (r["lacs"] as Array).size()
	return "[b]River[/b] — runs %d cell(s), %d waterfall(s)%s, then %s." % [coule, chutes,
		", fills %d lake(s) on its way" % lacs if lacs > 0 else "",
		{"sort": "leaves the world", "rejoint": "joins the water below",
			"ferme": "ends in a closed hollow"}.get(r["fin"], "stops")]


func _poser_sources(e: Dictionary, sources: Array) -> void:
	(e["sources"] as Array).append_array(sources)
	_eau_perimee()


func _oter_sources(e: Dictionary, debut: int, n: int) -> void:
	for i in n:
		(e["sources"] as Array).remove_at(debut)
	_eau_perimee()


func _poser_source(e: Dictionary, s: Vector3i) -> void:
	(e["sources"] as Array).append(s)
	_eau_perimee()


func _oter_source(e: Dictionary, i: int) -> void:
	(e["sources"] as Array).remove_at(i)
	_eau_perimee()


func _remettre_source(e: Dictionary, i: int, s: Vector3i) -> void:
	(e["sources"] as Array).insert(i, s)
	_eau_perimee()


func _ajouter_eau(etat: Dictionary) -> int:
	var n := 0
	for e in _eaux:
		n = maxi(n, int(str(e.get("id", "0"))))
	etat["id"] = str(etat["id"]) if str(etat.get("id", "")) != "" else str(n + 1)
	_eaux.append(etat)
	_eau_active = _eaux.size() - 1
	_eau_perimee()
	return _eau_active


func _nouvelle_eau() -> void:
	var etat := Projet.couche_d_eau("Water %d" % (_eaux.size() + 1))
	_histoire.create_action("New water layer")
	_histoire.add_do_method(_inserer_eau.bind(etat, _eaux.size()))
	_histoire.add_undo_method(_retirer_eau.bind(etat))
	_histoire.commit_action()
	_dire("[b]New water layer[/b] — the water you place now goes into it.")


func _supprimer_eau() -> void:
	if _eaux.is_empty():
		return
	var etat: Dictionary = _eaux[_eau_active]
	_histoire.create_action("Delete water layer « %s »" % etat["nom"])
	_histoire.add_do_method(_retirer_eau.bind(etat))
	_histoire.add_undo_method(_inserer_eau.bind(etat, _eau_active))
	_histoire.commit_action()


func _inserer_eau(etat: Dictionary, i: int) -> void:
	if str(etat.get("id", "")) == "":
		var n := 0
		for e in _eaux:
			n = maxi(n, int(str(e.get("id", "0"))))
		etat["id"] = str(n + 1)
	_eaux.insert(clampi(i, 0, _eaux.size()), etat)
	_eau_active = _eaux.find(etat)
	_eau_perimee()


func _retirer_eau(etat: Dictionary) -> void:
	_eaux.erase(etat)
	_eau_active = clampi(_eau_active, 0, maxi(_eaux.size() - 1, 0))
	_eau_perimee()


func _activer_eau(i: int) -> void:
	_eau_active = i
	_rafraichir_eaux()
	_enregistrer_plus_tard()


func _montrer_eau(i: int, oui: bool) -> void:
	_eaux[i]["visible"] = oui
	var nappes: Array = _vue.nappes()
	if i < nappes.size():
		(nappes[i] as Node3D).visible = oui
	_enregistrer_plus_tard()


## Une ligne par couche d'eau : l'œil, puis la couche (nom et ce qu'elle porte), qu'on choisit d'un clic.
func _rafraichir_eaux() -> void:
	if _liste_eaux == null:
		return
	for enfant in _liste_eaux.get_children():
		_liste_eaux.remove_child(enfant)
		enfant.queue_free()
	_bouton_supprimer_eau.disabled = _eaux.is_empty()
	if _eaux.is_empty():
		_liste_eaux.add_child(_texte("No water yet — pick Water and click in the world.", 11, Palette.GRIS))
	var groupe := ButtonGroup.new()
	for i in _eaux.size():
		var e: Dictionary = _eaux[i]
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 4)
		var oeil := Button.new()
		oeil.theme_type_variation = Palette.DISCRET
		oeil.toggle_mode = true
		oeil.button_pressed = e["visible"]
		oeil.icon = Icones.icone("oeil" if e["visible"] else "oeil_ferme")
		oeil.tooltip_text = "Show or hide this water layer"
		oeil.focus_mode = Control.FOCUS_NONE
		oeil.toggled.connect(func(v: bool) -> void:
			oeil.icon = Icones.icone("oeil" if v else "oeil_ferme")
			_montrer_eau(i, v))
		ligne.add_child(oeil)
		var choix := Button.new()
		choix.toggle_mode = true
		choix.button_group = groupe
		choix.button_pressed = i == _eau_active
		choix.focus_mode = Control.FOCUS_NONE
		choix.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choix.clip_text = true
		choix.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choix.add_theme_font_size_override("font_size", 11)
		choix.text = "%s\n%s" % [e["nom"], _bilan_d_eau(i)]
		choix.tooltip_text = "Make this water layer active: the water you place goes into it."
		choix.pressed.connect(_activer_eau.bind(i))
		ligne.add_child(choix)
		_liste_eaux.add_child(ligne)
	if _preset_eau != null and not _eaux.is_empty():
		_preset_eau.select(maxi(EauPresets.PRESETS.find(_eaux[_eau_active]["preset"]), 0))


func _bilan_d_eau(i: int) -> String:
	if i >= _corps_eau.size():
		return "%d source(s)" % (_eaux[i]["sources"] as Array).size()
	var n := {"ocean": 0, "lac": 0, "riviere": 0, "": 0}
	for r in _corps_eau[i]:
		n[r["genre"]] += 1
	var morceaux: Array = []
	for g in [["ocean", "sea"], ["lac", "lake"], ["riviere", "river"]]:
		if n[g[0]] > 0:
			morceaux.append("%d %s%s" % [n[g[0]], g[1], "s" if n[g[0]] > 1 else ""])
	var de_trop := (_corps_eau[i] as Array).filter(func(r): return r["erreur"] == "un_seul_ocean").size()
	if n[""] - de_trop > 0:
		morceaux.append("%d without water" % (n[""] - de_trop))
	if de_trop > 0:
		morceaux.append("%d other sea ignored — one sea only" % de_trop)
	return ", ".join(PackedStringArray(morceaux)) if not morceaux.is_empty() else "empty"


## ── LA BARRE DE DROITE DU PLAY TEST (Jordan, 1er octobre 2026) : les effets de rendu, à essayer en marchant.
## Bâtie depuis `Vue.REGLAGES_RENDU` : la liste décide, l'écran ne fait que la montrer.
func _batir_droite_jeu(pile: VBoxContainer) -> void:
	var note := _texte("Try looks while you walk. These settings only change the Play test; Reset brings back "
		+ "the app's own lighting.", 11, Palette.GRIS)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pile.add_child(note)
	pile.add_child(_bouton("Reset", "Back to the app's own lighting, and no weather.", _remettre_le_rendu, "croix"))
	# LA MÉTÉO (Jordan, 2 octobre 2026) — ⚠ elle n'est pas exportable, et l'écran le dit.
	var meteo := Section.new("Weather", true, Icones.icone("monde"))
	pile.add_child(meteo)
	_choix_meteo = OptionButton.new()
	for m in Vue.METEOS:
		_choix_meteo.add_item(m[1])
	_choix_meteo.focus_mode = Control.FOCUS_NONE
	_choix_meteo.item_selected.connect(func(i: int) -> void: _vue.regler_meteo(Vue.METEOS[i][0]))
	meteo.contenu.add_child(_choix_meteo)
	var pas_exportee := _texte("Only for the Play test, to judge your world in other weathers: it is not saved "
		+ "with the project, not exported to the .mbworld, and the engine plugins do not have it.", 11, Palette.GRIS)
	pas_exportee.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meteo.contenu.add_child(pas_exportee)
	var sections := {}
	for r in Vue.REGLAGES_RENDU:
		var groupe: String = r["groupe"]
		if not sections.has(groupe):
			var sec := Section.new(groupe, true, Icones.icone({"Light": "ampoule", "Sky": "monde", "Effects": "texture",
				"Camera": "oeil"}.get(groupe, "outils")))
			pile.add_child(sec)
			sections[groupe] = sec
		(sections[groupe] as Section).contenu.add_child(_ligne_de_rendu(r))


func _ligne_de_rendu(r: Dictionary) -> Control:
	var cle: String = r["cle"]
	var valeur: Variant = _vue.rendu.get(cle, r["defaut"])
	if r["genre"] == "case":
		var c := CheckButton.new()
		c.text = r["nom"]
		c.button_pressed = valeur
		c.focus_mode = Control.FOCUS_NONE
		c.toggled.connect(func(v: bool) -> void: _vue.regler_rendu(cle, v))
		_controles_rendu[cle] = c
		return c
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 8)
	var nom := _texte(r["nom"], 12)
	nom.custom_minimum_size = Vector2(110, 0)
	nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ligne.add_child(nom)
	match r["genre"]:
		"curseur":
			var s := HSlider.new()
			s.min_value = r["min"]
			s.max_value = r["max"]
			s.step = r["pas"]
			s.value = valeur
			s.focus_mode = Control.FOCUS_NONE
			s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var lu := _texte(str(snappedf(valeur, r["pas"])), 11, Palette.OLIVE)
			lu.custom_minimum_size = Vector2(40, 0)
			s.value_changed.connect(func(v: float) -> void:
				lu.text = str(snappedf(v, r["pas"]))
				_vue.regler_rendu(cle, v))
			s.set_meta("lu", lu)
			ligne.add_child(s)
			ligne.add_child(lu)
			_controles_rendu[cle] = s
		"couleur":
			var b := ColorPickerButton.new()
			b.color = valeur
			b.edit_alpha = false
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(0, 26)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.color_changed.connect(func(v: Color) -> void: _vue.regler_rendu(cle, v))
			ligne.add_child(b)
			_controles_rendu[cle] = b
		"choix":
			var o := OptionButton.new()
			for nom_choix in r["choix"]:
				o.add_item(nom_choix)
			o.select(int(valeur))
			o.focus_mode = Control.FOCUS_NONE
			o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			o.item_selected.connect(func(i: int) -> void: _vue.regler_rendu(cle, i))
			ligne.add_child(o)
			_controles_rendu[cle] = o
	return ligne


## « Reset » : les valeurs décidées, et chaque contrôle les montre (sans renvoyer de signal).
func _remettre_le_rendu() -> void:
	_vue.rendu_par_defaut()
	_vue.regler_meteo("aucune")
	_choix_meteo.select(0)
	for cle in _controles_rendu:
		var c: Control = _controles_rendu[cle]
		var v: Variant = _vue.rendu[cle]
		if c is CheckButton:
			(c as CheckButton).set_pressed_no_signal(v)
		elif c is HSlider:
			(c as HSlider).set_value_no_signal(v)
			((c as HSlider).get_meta("lu") as Label).text = str(v)
		elif c is ColorPickerButton:
			(c as ColorPickerButton).color = v
		elif c is OptionButton:
			(c as OptionButton).select(int(v))
	_dire("[i]Play test lighting back to the app's own.[/i]")


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
	barre.show_percentage = false
	# ⚠ UNE PISTE ET UN REMPLISSAGE FRANCS : avec le thème seul, la barre défilante n'était qu'un trait de quelques
	# pixels, invisible à l'image.
	barre.custom_minimum_size = Vector2(0, 10)
	var piste := StyleBoxFlat.new()
	piste.bg_color = Palette.FILET
	piste.set_corner_radius_all(5)
	var plein := StyleBoxFlat.new()
	plein.bg_color = Palette.OLIVE
	plein.set_corner_radius_all(5)
	barre.add_theme_stylebox_override("background", piste)
	barre.add_theme_stylebox_override("fill", plein)
	pile.add_child(barre)
	_attente_barre = barre
	_attente_note = _texte("", 11, Palette.GRIS)
	pile.add_child(_attente_note)
	# ⚠ IL NE PREND PAS LA SOURIS : un geste long retenu est rejoué panneau ENCORE À L'ÉCRAN (il s'en va deux images plus
	# tard) ; un clic qui tombait sous lui — au centre de la vue — était avalé sans un mot (le second clic d'eau perdu,
	# signalé par la session vidéos le 6 octobre 2026).
	_sans_souris(_attente)
	parent.add_child(_attente)


## ⚠ IL FAUT RENDRE LA MAIN À L'ÉCRAN POUR QU'IL PEIGNE, ET `process_frame` NE SUFFIT PAS (leçon de
## SoluTiles) : on reprend la main AVANT le dessin de l'image. Seul `frame_post_draw` prouve que le
## panneau est réellement à l'écran avant qu'un travail long ne bloque le fil.
## LA BARRE DE PROGRESSION (Jordan, 1er octobre 2026 : « dans tout processus qui dépasse 0,4 s »).
##   - `etapes` > 0 : une barre qui avance d'une étape à chaque `_avancer` — l'écran est repeint entre deux ;
##   - `etapes` = 0 : une barre qui DÉFILE, pour un travail d'un seul tenant fait sur un autre fil (`_en_fond`).
## ⚠ UN TRAVAIL D'UN SEUL TENANT SUR LE FIL PRINCIPAL GÈLE TOUT, BARRE COMPRISE : le panneau dit alors ce qui se
## passe, mais ne bouge plus jusqu'à la fin. D'où `_en_fond` pour ce qui est long et pur (le tranchage).
func _sans_souris(c: Control) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for e in c.get_children():
		if e is Control:
			_sans_souris(e)


func _attendre(titre: String, note: String, etapes := 0) -> void:
	_pile_attente.push_back([titre, note, etapes, 0])
	_montrer_attente()
	await _laisser_peindre()


## L'étape suivante d'une attente à étapes ; `note` dit ce qu'on fait maintenant.
func _avancer(note := "") -> void:
	if _pile_attente.is_empty():
		return
	var e: Array = _pile_attente[-1]
	e[3] = int(e[3]) + 1
	if note != "":
		e[1] = note
	_montrer_attente()
	await _laisser_peindre()


func _fin_attente() -> void:
	if not _pile_attente.is_empty():
		_pile_attente.pop_back()
	if _pile_attente.is_empty():
		_attente.visible = false
	else:
		_montrer_attente()


func _montrer_attente() -> void:
	var e: Array = _pile_attente[-1]
	_attente_titre.text = e[0]
	_attente_note.text = e[1]
	_attente_barre.indeterminate = int(e[2]) <= 0
	_attente_barre.max_value = maxi(int(e[2]), 1)
	_attente_barre.value = int(e[3])
	_attente.visible = true


## ── LA BARRE POUR TOUT GESTE QUI DURE (Jordan, 3 octobre 2026 : « la majorité des moments où quelque chose se fait en
## durant sans qu'une barre de progression se montre ») ────────────────────────────────────────────────────────────
## Chaque geste — une touche, un bouton, un clic dans la vue — est repéré dans `_input`, AVANT que l'interface ne le
## traite, et chronométré jusqu'à l'image qui suit son image (le travail, puis le dessin). `Durees` apprend ce qu'il
## coûte, rapporté à la taille du monde, et s'en souvient d'une session à l'autre (`reglages.cfg`, section « durees »).
## Un geste connu pour dépasser 0,4 s est RETENU : le panneau d'attente s'affiche, on attend qu'il soit réellement
## dessiné (`_laisser_peindre`), puis le MÊME événement est rejoué (`Input.parse_input_event`, marqué pour passer) — le
## travail bloque alors un écran qui dit ce qui se passe. Deux images de délai, pour les seuls gestes longs.
## ⚠ PAS DE DESSIN FORCÉ (`RenderingServer.force_draw`), ESSAYÉ ET ÉCARTÉ — VU À L'IMAGE : le panneau apparaissait,
## mais avec le texte d'une attente d'avant (« Opening the project ») — Godot ne redessine un texte changé qu'en fin
## d'image (`capture_attente_forcee.gd`). ⚠ La première fois qu'un geste est long, il n'a pas de barre : il n'était
## pas connu.
## ⚠ Sans fenêtre (les suites) rien n'est appris ni montré, sauf si `_gestes_suivis` est forcé.
var _durees_gestes := Durees.new()
var _gestes_suivis := false
var _geste := ""
var _geste_debut := 0
var _geste_vu_en_process := false
var _geste_taille := 0
var _geste_attente: Array = []
const CLE_DUREES := "gestes"
const NOMS_DES_TOUCHES := {"Ctrl+Z": "Undo", "Ctrl+Y": "Redo", "Ctrl+Shift+Z": "Redo", "Ctrl+S": "Saving",
	"Ctrl+V": "Paste", "Ctrl+X": "Cut", "Ctrl+C": "Copy", "Delete": "Delete", "Tab": "Edit mode"}


## La clé d'un geste et ce qu'on en dit à l'écran : [clé, libellé], ou [] si ce n'est pas un geste qui compte.
func _cle_du_geste(event: InputEvent) -> Array:
	var k := event as InputEventKey
	if k != null:
		if not k.pressed or k.echo or k.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK]:
			return []
		var texte := k.as_text_keycode()
		return ["touche:%s:%s" % [_atelier, texte], NOMS_DES_TOUCHES.get(texte, texte)]
	var m := event as InputEventMouseButton
	if m == null or not m.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return []
	var sous: Control = get_viewport().gui_get_hovered_control() if is_inside_tree() else null
	if sous == null:
		return []
	# Un bouton agit au RELÂCHER ; la vue, à l'appui.
	if sous is BaseButton and not (sous is OptionButton):
		if m.pressed or m.button_index != MOUSE_BUTTON_LEFT:
			return []
		var nom := ""
		if sous is Button and (sous as Button).text != "":
			nom = (sous as Button).text
		else:
			nom = sous.tooltip_text.get_slice("\n", 0).left(40)
		if nom == "":
			nom = str(sous.name)
		return ["bouton:" + nom, nom]
	if _vue != null and (sous == _vue or _vue.is_ancestor_of(sous)) and m.pressed:
		var outil: String = str(_vue.outil) if _atelier in ["monde", "fluides", "transitions"] else ("edition" if _modeleur.maillage != null else "vue")
		return ["vue:%s:%s:%s" % [_atelier, outil, "droit" if m.button_index == MOUSE_BUTTON_RIGHT else "gauche"],
			{"monde": "Painting", "fluides": "Water", "witness": "Geometry", "texture": "Texturing", "jeu": "Play test",
				"projet": "Project", "transitions": "Transitions"}.get(_atelier, "Working")]
	return []


## Rend vrai si l'événement est RETENU (il sera rejoué une fois le panneau à l'écran) : `_input` s'arrête là.
func _noter_le_geste(event: InputEvent) -> bool:
	if not (_ecran_vivant() or _gestes_suivis):
		return false
	if event.has_meta(META_REJEU):
		event.remove_meta(META_REJEU)
		return false   # le geste rejoué : il est déjà chronométré
	# ⚠ PENDANT QU'UN GESTE ATTEND SON PANNEAU, TOUT CE QUI ARRIVE ATTEND AVEC LUI, DANS L'ORDRE : le relâcher d'un clic
	# retenu arriverait sinon AVANT son appui.
	if _retenus_en_route:
		_retenus.append(event)
		if is_inside_tree():
			get_viewport().set_input_as_handled()
		return true
	if _geste != "":
		return false
	var g := _cle_du_geste(event)
	if g.is_empty():
		return false
	var taille := _union.size()
	if _pile_attente.is_empty() and _durees_gestes.doit_montrer(g[0], taille):
		if is_inside_tree():
			get_viewport().set_input_as_handled()
		_rejouer_apres_le_panneau(event, g, taille)
		return true
	_commencer_le_geste(g[0], taille)
	return false


const META_REJEU := "mb_rejeu"


func _commencer_le_geste(cle: String, taille: int) -> void:
	_geste = cle
	_geste_debut = Time.get_ticks_usec()
	_geste_vu_en_process = false
	_geste_taille = taille


var _retenus: Array = []
var _retenus_en_route := false


func _rejouer_apres_le_panneau(event: InputEvent, g: Array, taille: int) -> void:
	_retenus_en_route = true
	_retenus = [event]
	_geste_attente = _occupe(g[1], "Working… (%.1f s last time)" % _durees_gestes.prevoir(g[0], taille))
	await _laisser_peindre()
	_retenus_en_route = false
	_commencer_le_geste(g[0], taille)
	for e in _retenus:
		(e as InputEvent).set_meta(META_REJEU, true)
		Input.parse_input_event(e)
	_retenus = []


## À la DEUXIÈME image après le geste : son image (le travail, le dessin) est passée — on note ce qu'il a coûté, et le
## panneau montré pour lui s'en va.
func _suivre_le_geste() -> void:
	if _geste == "":
		return
	if not _geste_vu_en_process:
		_geste_vu_en_process = true
		return
	var secondes := (Time.get_ticks_usec() - _geste_debut) / 1000000.0
	var etait_connu: bool = _durees_gestes.par_unite.has(_geste)
	_durees_gestes.apprendre(_geste, secondes, _geste_taille)
	if not _geste_attente.is_empty():
		_fin_occupe(_geste_attente)
		_geste_attente = []
	if not etait_connu and _durees_gestes.par_unite.has(_geste):
		_retenir_les_durees()
	_geste = ""


## Montre le panneau d'attente (une entrée à part dans la pile, rendue par `_fin_occupe`).
func _occupe(titre: String, note := "") -> Array:
	var e := [titre, note, 0, 0, "auto"]
	_pile_attente.push_back(e)
	_montrer_attente()
	return e


func _fin_occupe(e: Array) -> void:
	for i in range(_pile_attente.size() - 1, -1, -1):
		if is_same(_pile_attente[i], e):
			_pile_attente.remove_at(i)
			break
	if _pile_attente.is_empty():
		_attente.visible = false
	else:
		_montrer_attente()


func _lire_les_durees() -> void:
	var r := ConfigFile.new()
	r.load(REGLAGES)
	_durees_gestes.depuis_dictionnaire(r.get_value("durees", CLE_DUREES, {}))


func _retenir_les_durees() -> void:
	if not _ecran_vivant():
		return
	var r := ConfigFile.new()
	r.load(REGLAGES)
	r.set_value("durees", CLE_DUREES, _durees_gestes.vers_dictionnaire())
	r.save(REGLAGES)


## ⚠ SANS FENÊTRE, `frame_post_draw` NE VIENT JAMAIS (la fumée pendait sur tout ce qui attendait) : on n'attend
## alors que l'image suivante.
func _laisser_peindre() -> void:
	await get_tree().process_frame
	if _ecran_vivant():
		await RenderingServer.frame_post_draw


func _ecran_vivant() -> bool:
	return DisplayServer.get_name() != "headless"


## LE TRAVAIL LONG SUR UN AUTRE FIL : l'écran reste vivant et la barre défile. ⚠ `travail` ne touche à AUCUN nœud
## de la scène (le cœur est pur : fichiers, tableaux, ressources). Sans fenêtre, il tourne sur place.
func _en_fond(travail: Callable) -> Variant:
	if not _ecran_vivant():
		return travail.call()
	var boite: Array = [null]
	var id := WorkerThreadPool.add_task(func() -> void: boite[0] = travail.call())
	while not WorkerThreadPool.is_task_completed(id):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(id)
	return boite[0]


## LES GESTES QUI CHANGENT D'ATELIER (boutons, « Leave ») passent par ici : avant World ou le Play test, le monde
## suit son témoin couche par couche, et la barre avance d'une couche à l'autre. `_aller_a` reste synchrone — on
## l'appelle d'endroits qui enchaînent juste après.
func _changer_d_atelier(atelier: String) -> void:
	if atelier in ["monde", "jeu", "fluides", "transitions", "feuillage"]:
		await _rhabiller_avec_attente(atelier == "jeu")
	var debut := Time.get_ticks_msec()
	if atelier == "jeu" and _atelier != "jeu" and _ecran_vivant() and float(_durees.get("jeu", 0.0)) >= SEUIL_ATTENTE:
		await _attendre("Starting the Play test", "the ground you walk on, from the tiles", 0)
		_aller_a(atelier)
		_fin_attente()
	else:
		_aller_a(atelier)
	if atelier == "jeu":
		_durees["jeu"] = (Time.get_ticks_msec() - debut) / 1000.0


## Le monde suit son témoin, une couche périmée à la fois, la barre avançant de l'une à l'autre.
func _rhabiller_avec_attente(pour_jouer := false) -> void:
	if _minuterie_temoin != null and not _minuterie_temoin.is_stopped():
		_minuterie_temoin.stop()
		_enregistrer_le_temoin_modele()
	var perimees: Array = _couches.filter(func(c): return c.get("_glb_perime", false))
	if perimees.is_empty() or not _ecran_vivant():
		_rhabiller_les_mondes()
		return
	await _attendre("Starting the Play test" if pour_jouer else "Updating the painted world",
		"layer « %s »" % perimees[0]["nom"], perimees.size())
	for c in perimees:
		_rhabiller(c)
		await _avancer("layer « %s »" % c["nom"])
	_rafraichir_couches()
	_fin_attente()


## Entrer en édition par un geste (Tab, le bouton) : charger le témoin d'une couche coûte ~2 s la première fois.
func _basculer_edition(oui: bool) -> void:
	if oui and not _vue.edition and _ecran_vivant() and _modeleur.temoin != _couches[_active].get("_temoin", null):
		await _attendre("Opening the witness editor", "%s — its tiles and their linked copies" % _couches[_active]["nom"])
		_regler_edition(true)
		_fin_attente()
		return
	_regler_edition(oui)


# ── LES ATELIERS ─────────────────────────────────────────────────────────────────────────────────────

func _aller_a(atelier: String) -> void:
	if atelier in ["monde", "jeu", "fluides", "transitions", "feuillage"]:
		_rhabiller_les_mondes()   # on va regarder le monde (ou le fouler) : il suit son témoin
	if atelier == "jeu" and _atelier != "jeu":
		_vue.eau_du_jeu = _eau_pour_le_jeu()
		var refus: String = _vue.commencer_partie()
		if refus != "":
			_dire("[color=#e0603c]%s[/color]" % refus)
			atelier = "monde"
	elif atelier != "jeu" and _atelier == "jeu":
		_vue.finir_partie()
		# Le rapport disait encore les touches du jeu : on dit où l'on revient.
		_dire("[i]Back from the Play test.[/i]")
	# FLUIDS SE DÉSACTIVE EN SORTANT : l'outil Water ne survit pas à l'atelier (Jordan, 2 octobre 2026).
	if atelier != "fluides":
		_sortir_des_fluides()
	if atelier != "transitions":
		_sortir_des_transitions()
	if atelier != "feuillage":
		_feuillage.sortir()
	_atelier = atelier
	(_boutons_atelier[atelier] as Button).button_pressed = true
	_contexte()
	# Project et Witness montrent tous deux le témoin (ou le travail qu'on regarde) ; Fluids, le monde.
	_vue.montrer({"monde": "monde", "jeu": "jeu", "fluides": "monde", "transitions": "monde", "feuillage": "monde"}.get(atelier, "temoin"))
	if atelier == "fluides":
		_entrer_dans_les_fluides()
	if atelier == "transitions":
		_entrer_dans_les_transitions()
	if atelier == "anim":
		_animation.entrer()
	if atelier == "feuillage":
		_feuillage.entrer()
	if atelier == "jeu":
		# ⚠ Le bouton « Play test » garde sinon le clavier, et Espace le re-cliquerait au lieu de sauter.
		get_viewport().gui_release_focus()
		_vue.grab_focus()
		_dire("[b]Play test[/b] — Z Q S D to move, Space to jump, Shift to run, right drag to turn, "
			+ "F to fly. In water you swim: Space to rise, A to dive (Q on QWERTY), swim into a bank to climb out. "
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
	# DEUX ATELIERS DU TÉMOIN (Jordan, 1er octobre 2026) : Geometry (le maillage) et Texturing (matériaux,
	# projections, dépliage — et la peinture à venir). Ils montrent le même témoin ; seule la main change.
	var geometrie := _atelier == "witness"
	var texturing := _atelier == "texture"
	var animation := _atelier == "anim"
	var temoin := geometrie or texturing or animation
	var monde := _atelier == "monde"
	var fluides := _atelier == "fluides"
	var transitions := _atelier == "transitions"
	var jeu := _atelier == "jeu"
	_section_jeu.visible = jeu
	_titre_projet.visible = projet
	_section_projet.visible = projet
	# La liste des couches dans Transitions aussi : son ORDRE dit qui couvre par défaut.
	_section_couches.visible = monde or temoin or transitions
	_section_monde_peint.visible = monde
	_section_choix_monde.visible = monde and Exemple.disponible()
	_titre_aller_retour.visible = projet
	for e in _etapes_artiste:
		e.visible = projet
	for e in _etapes_monde:
		e.visible = projet
	_section_temoin.visible = temoin or projet
	_section_raccourcis.visible = monde
	_zone_reference.visible = temoin or monde or projet
	_droite.visible = monde
	_droite_temoin.visible = geometrie
	_droite_texture.visible = texturing
	_droite_jeu.visible = jeu
	_droite_fluides.visible = fluides
	_droite_transitions.visible = transitions
	_droite_animation.visible = animation
	_droite_feuillage.visible = _atelier == "feuillage"
	_modeleur.geometrie = not (texturing or animation)
	if not texturing and _modeleur.pinceau:
		_modeleur.regler_pinceau(false)
	if not geometrie and _modeleur.sculpt:
		_modeleur.regler_sculpt(false)
	if _bouton_pinceau != null:
		_bouton_pinceau.set_pressed_no_signal(_modeleur.pinceau)
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
## LE VOL DU PLAY TEST (Jordan, 1er octobre 2026). Le bouton rend le clavier à la vue : sinon Espace, qui
## fait monter, re-cliquerait le bouton.
func _basculer_vol() -> void:
	if _atelier != "jeu":
		return
	var vole := _vue.basculer_vol()
	get_viewport().gui_release_focus()
	_vue.grab_focus()
	_dire("[b]Flying[/b] — Space or E to go up, A to go down (Q on QWERTY), Shift to go faster. F to land."
		if vole else "[i]Walking again — gravity is back.[/i]")


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
	_case_vides.visible = _vue.outil == "selectionner"
	_creux.visible = _vue.outil == "boite"
	if _reglages_forme == null:
		return
	var f: Dictionary = _vue.forme_speciale
	var quoi: String = f["quoi"]
	var active: bool = _vue.outil == "forme"
	var salle: bool = quoi == "salle"
	var relier: bool = bool(f["relier"]) and quoi != "balcon" and not salle
	_reglages_forme.visible = active
	# LA SALLE NE LIT QUE SES ÉTAGES ET SON SENS : le reste des réglages disparaît.
	_ligne_salle.visible = salle
	_ligne_taille_forme.visible = not salle
	_ligne_bouts.visible = quoi != "balcon" and not salle
	_ligne_profil.visible = quoi in ["tunnel", "puits"]
	_ligne_longueur.visible = not relier and not salle
	_etiquette_longueur.text = {"pont": "Reach", "escalier": "Length"}.get(quoi, "Depth")
	_longueur_forme.tooltip_text = {
		"tunnel": "How deep a straight tunnel goes when it finds no cave behind the wall.",
		"puits": "How deep a straight well goes when it finds no cave below.",
		"pont": "How far a straight bridge looks for a wall in front.",
		"balcon": "How far the balcony sticks out of the wall.",
		"escalier": "How far the stairs may run from the wall when they do not reach the ground first.",
	}.get(quoi, "")
	_ligne_pas.visible = quoi == "escalier" and not relier
	_garde_corps.visible = quoi in ["pont", "balcon", "escalier"]
	var surface: String = {"puits": "floor or ceiling", "escalier": "floor"}.get(quoi, "wall")
	if not active:
		_aide_forme.text = "Pick a shape, then click in the world."
	elif salle:
		_aide_forme.text = ("Drag a rectangle on the floor grid (PgUp / PgDn for the floor). The room %s from it: "
			+ "walls, floor and ceiling, hollow within.") % ("rises" if bool(f["vers_le_haut"]) else "sinks")
	elif quoi == "balcon":
		_aide_forme.text = "Click a wall where the balcony floor goes."
	elif quoi == "escalier" and not relier:
		_aide_forme.text = "Click a wall where the stairs should arrive: they come down from there to the ground."
	elif relier:
		_aide_forme.text = "Click the first %s, then the second. Right click or Esc forgets the first." % surface
	else:
		_aide_forme.text = "Click a %s: the shape goes straight out of it." % surface


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
	_bouton_edition = _sections_d_edition(pile, "Witness geometry", _boutons_selmode)

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

	_batir_sculpt(pile)

	var mesh := Section.new("Mesh", true, Icones.icone("couteau"))
	pile.add_child(mesh)
	mesh.contenu.add_child(_grille([
		_bouton("Extrude  ·  E", "E — pull the selected faces out (their tile-border vertices stay put), or the rim of a hole; they follow the mouse.",
			func() -> void: _geste_modeleur("E"), "extruder_haut"),
		_bouton("Inset  ·  I", "I — a smaller copy of the selected faces inside them.",
			func() -> void: _geste_modeleur("I"), "evider"),
		_bouton("Loop cut  ·  Ctrl+R", "Ctrl+R — point an edge: its ring lights up; click to cut it in the middle.",
			func() -> void: _geste_modeleur("loop"), "couteau"),
		_bouton("Subdivide", "Splits each selected face into quads. Neighbours get the new points too: no gap.",
			func() -> void: _geste_modeleur("subdiviser"), "grandir"),
		_bouton("Merge  ·  M", "M — merge the selected vertices at their center (on the tile-border vertex, if one of them is on a border).",
			func() -> void: _geste_modeleur("fusionner"), "retrecir"),
		_bouton("Fill  ·  F", "F — make a face on the selected vertices (a hole's rim).",
			func() -> void: _geste_modeleur("remplir"), "remplir"),
		_bouton("Bevel  ·  Ctrl+B", "Ctrl+B — chamfer the selected edges (or the edges of the selected "
			+ "faces); the width follows the mouse or is typed.", func() -> void: _geste_modeleur("bevel"), "evider"),
		_bouton("Knife  ·  K", "K — click points on the surface: the cut follows it across faces and tile borders; Enter cuts.",
			func() -> void: _geste_modeleur("knife"), "couper"),
		_bouton("Dissolve  ·  Ctrl+X", "Ctrl+X — removes the selected faces (the faces of the selected edges or vertices) "
			+ "and closes their outline with one face: never a hole, and a tile border stays where it is.",
			func() -> void: _geste_modeleur("dissoudre"), "poubelle"),
		_bouton("Delete  ·  X", "X — delete the selected faces, edges or vertices. It opens a hole: Dissolve (Ctrl+X) "
			+ "does not.", func() -> void: _geste_modeleur("supprimer"), "poubelle", Palette.DANGER),
	], 2))
	# FILL HOLES (Jordan, 3 octobre 2026) : boucher les trous de la tuile, ou de toutes ; la section arrachée d'un bord est
	# recréée avec les points que les tuiles d'en face partagent. Le compteur dit s'il y en a, avant que le monde le montre.
	_trous_texte = _texte("", 11, Palette.GRIS)
	mesh.contenu.add_child(_trous_texte)
	mesh.contenu.add_child(_grille([
		_bouton("Fill holes", "Closes every hole of this tile. A hole that reaches a cut plane gets its border back: the "
			+ "points the next tiles share are rebuilt on the plane, then joined to the rim — no gap in the world.",
			func() -> void: _boucher_les_trous(false), "remplir"),
		_bouton("Fill holes · all tiles", "The same in every tile of the witness. One Ctrl+Z.",
			func() -> void: _boucher_les_trous(true), "remplir"),
	], 2))
	# LES BORDS ENTRE COUCHES (Jordan, 6 octobre 2026 : « il y a des fentes, je les ai vues ») : deux couches se touchent
	# dans le monde ; leurs témoins doivent avoir les mêmes bords. Les gestes les tiennent ensemble ; ce bouton rattrape ce
	# qui diverge déjà (un projet d'avant, un témoin revenu de Blender, une couche neuve sur le témoin calculé).
	_ecarts_texte = _texte("", 11, Palette.GRIS)
	mesh.contenu.add_child(_ecarts_texte)
	_bouton_caler = _bouton("Match other layers to this one", "The borders of the other layers' witnesses are moved onto "
		+ "this witness's borders, so that where two layers meet in the world their tiles join without a gap. Only the "
		+ "border vertices of the other layers move (their sculpture inside the tile stays). One Ctrl+Z.",
		_caler_les_autres_couches, "relier")
	mesh.contenu.add_child(_bouton_caler)

	_variantes.batir_temoin(pile)

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

	var tem := Section.new("The modelled witness", true, Icones.icone("enregistrer"))
	pile.add_child(tem)
	tem.contenu.add_child(_texte("It saves itself next to the project, and joins the works of step 2 "
		+ "(Project): slice it there, like an imported work.", 11, Palette.GRIS))
	tem.contenu.add_child(_bouton("Reset to the computed witness",
		"Starts again from the computed witness (Ctrl+Z brings your model back).", _remettre_le_temoin,
		"gomme", Palette.DANGER))


## Ce que les deux barres du témoin ont en commun : quel témoin on édite, Tab, les modes de sélection et la
## sélection. Rend le bouton d'édition ; les deux barres se suivent (`_boutons_edition`).
func _sections_d_edition(pile: VBoxContainer, titre: String, selmode: Dictionary) -> Button:
	var mode := Section.new(titre, true, Icones.icone("cube" if selmode == _boutons_selmode else "texture"))
	pile.add_child(mode)
	# QUEL TÉMOIN ON ÉDITE : celui de la couche active (un témoin par couche, 30 septembre 2026).
	var etiquette := _texte("", 11, Palette.OLIVE)
	_etiquettes_temoin_couche.append(etiquette)
	_etiquette_temoin_couche = etiquette
	mode.contenu.add_child(etiquette)
	var edition := Button.new()
	edition.text = "Edit the witness  ·  Tab"
	edition.icon = Icones.icone("outils")
	edition.toggle_mode = true
	edition.focus_mode = Control.FOCUS_NONE
	edition.custom_minimum_size = Vector2(0, 34)
	edition.tooltip_text = ("Tab — edit the witness mesh, the way you would in Blender.\nTab again "
		+ "looks at it without editing.")
	edition.toggled.connect(func(v: bool) -> void: _basculer_edition(v))
	_boutons_edition.append(edition)
	mode.contenu.add_child(edition)
	mode.contenu.add_child(_petit_titre("SELECT  ·  1 2 3"))
	mode.contenu.add_child(_rangee_de_choix(selmode, [
		["sommet", "Vertex", "ajouter", "1 — select vertices."],
		["arete", "Edge", "rect", "2 — select edges."],
		["face", "Face", "boite", "3 — select faces."],
	], func(m: String) -> void:
		_regler_edition(true)
		_modeleur.choisir_mode(m)
		_suivre_le_mode_de_selection(), Palette.OUTIL))
	(selmode["face"] as Button).button_pressed = true

	var sel := Section.new("Select", true, Icones.icone("selectionner"))
	pile.add_child(sel)
	sel.contenu.add_child(_texte("Click selects what you SEE · Shift+click adds or removes · Alt+click "
		+ "selects a loop (a ring of faces in Face mode) · Ctrl + right drag: lasso · C: circle.", 11, Palette.GRIS))
	sel.contenu.add_child(_grille([
		_bouton("All  ·  A", "A — select everything.", func() -> void: _geste_modeleur("tout"), "grandir"),
		_bouton("None  ·  Alt+A", "Alt+A — select nothing.", func() -> void: _geste_modeleur("rien"), "croix"),
		_bouton("Box  ·  B", "B, then drag a rectangle. It takes what you see — with X-ray (Alt+Z), what is hidden behind too.",
			func() -> void: _geste_modeleur("B"), "boite"),
		_bouton("Lasso", "Ctrl + right drag (Shift + Ctrl removes), as in Blender — or click here, then drag with "
			+ "the left button (Ctrl or Shift removes). It takes what you see; Alt+Z for X-ray.",
			func() -> void: _geste_modeleur("lasso"), "relier"),
		_bouton("Circle  ·  C", "C — paint the selection with a circle: left button adds, Shift or the middle button "
			+ "removes, the wheel sizes it; right click, Esc or Enter ends.",
			func() -> void: _geste_modeleur("cercle"), "sphere"),
	], 2))
	return edition


func _suivre_le_mode_de_selection() -> void:
	for d in [_boutons_selmode, _boutons_selmode_tex]:
		for m in d:
			(d[m] as Button).set_pressed_no_signal(m == _modeleur.mode_sel)


## LA BARRE DU TEXTURING (Jordan, 1er octobre 2026 : « faire sortir du mode Witness, renommé Witness geometry, un
## second mode Witness texturing, vu que je compte y ajouter de quoi dessiner la texture ou dessiner sur l'UV »).
## Choisir les faces, leur matière, la projection, le dépliage et son patron. La peinture viendra ici.
func _batir_droite_texture(pile: VBoxContainer) -> void:
	_sections_d_edition(pile, "Witness texturing", _boutons_selmode_tex)
	pile.get_child(0).contenu.add_child(_texte("Geometry tools (move, extrude, cut…) are in Witness geometry. "
		+ "Here: pick faces, give them a material, project or unwrap it.", 11, Palette.GRIS))
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
	_edition_materiau.add_child(_bouton("Unwrap all tiles (atlas)", "Every face of this material, in EVERY tile, "
		+ "unwrapped together into one image: each tile gets its own place, so painting one tile never paints "
		+ "another. Its copies still share their paint (they are the same tile). Switches the material to UV.",
		func() -> void:
			_regler_edition(true)
			_modeleur.deplier_en_atlas(), "grille", Palette.PRINCIPAL))
	_etat_uv = _texte("", 11, Palette.AMBRE)
	_edition_materiau.add_child(_etat_uv)
	_edition_materiau.add_child(_texture_materiau)
	_edition_materiau.add_child(_grille([
		_bouton("Image…", "A tileable image (.png, .jpg) projected on the faces.",
			func() -> void: _demander("texture"), "texture"),
		_bouton("No image", "Colour only.", func() -> void: _retoucher("texture", ""), "croix"),
	], 2))
	_batir_pbr(pile)
	_redire_les_materiaux()
	_batir_peinture(pile)


# ── LES CARTES PBR — DÉCIDÉ (Jordan, 2 octobre 2026) ──────────────────────────────────────────────────────
#
# Les cartes (normale, rugosité, occlusion) se DÉDUISENT de l'image du matériau courant (`cartes_pbr.gd`), suivent
# chaque retouche toutes seules, et partent dans le .glb ; seuls des RÉGLAGES s'enregistrent. Et la couleur de base
# peut se CUIRE depuis le relief géométrique (projection UV).

const REGLAGES_PBR := [
	["Fine detail", "fin", 0.0, 2.0, 0.01, "Weight of the smallest bumps read in the image."],
	["Medium", "moyen", 0.0, 2.0, 0.01, "Weight of the middle-sized shapes."],
	["Large", "large", 0.0, 2.0, 0.01, "Weight of the broad shapes."],
	["Contrast", "contraste", 0.0, 4.0, 0.01, "How tall the height read in the image is."],
	["Normal", "normale", 0.0, 16.0, 0.1, "Strength of the normal map (how steep the bumps look)."],
	["Occlusion", "occlusion", 0.0, 3.0, 0.01, "How dark the hollows get."],
	["Roughness", "rugosite", 0.0, 1.0, 0.01, "Base roughness of the material."],
	["Variation", "variation", -1.0, 1.0, 0.01, "Hollows rougher than bumps (or smoother, below 0)."],
]
const REGLAGES_RELIEF := [
	["Edge wear", "usure", 0.0, 1.0, 0.01, "How much the convex edges take the wear colour."],
	["Hollows", "cavite", 0.0, 1.0, 0.01, "How dark the concave edges get."],
	["Width", "largeur", 0.01, 0.25, 0.005, "How far from an edge the wear and the shade reach, in cells."],
]

var _section_pbr: Control
var _case_ensemble: CheckBox
var _etat_ensemble: Label
var _ligne_emission: Control
var _force_emission: HSlider
var _bouton_cuire: Button
var _case_pbr: CheckBox
var _reglages_pbr: VBoxContainer
var _curseurs_pbr := {}
var _case_inverser: CheckBox
var _etat_pbr: Label
var _couleurs_relief := {}
var _curseurs_relief := {}


func _batir_pbr(pile: VBoxContainer) -> void:
	var sec := Section.new("PBR maps", true, Icones.icone("texture"))
	pile.add_child(sec)
	_section_pbr = sec
	sec.contenu.add_child(_texte("Normal, roughness and occlusion are DERIVED from the material's image and follow "
		+ "every brush stroke on their own; only these settings are saved. Metal is never guessed: the Metallic "
		+ "slider stays in charge. The maps travel in the .glb to Godot, Unity and Unreal.", 11, Palette.GRIS))
	# L'ENSEMBLE PBR (3 octobre 2026) : les cartes trouvées à côté de l'image, par leur nom.
	_case_ensemble = CheckBox.new()
	_case_ensemble.text = "Use the maps found next to the image"
	_case_ensemble.focus_mode = Control.FOCUS_NONE
	_case_ensemble.tooltip_text = ("A texture set (rock_color.png, rock_normal_gl.png, rock_roughness.png, "
		+ "rock_ambient_occlusion.png…) brings maps made from the real relief: they are used as they are, and win "
		+ "over the derived ones.")
	_case_ensemble.toggled.connect(func(v: bool) -> void: _retoucher("ensemble", v))
	sec.contenu.add_child(_case_ensemble)
	_etat_ensemble = _texte("", 11, Palette.GRIS)
	_etat_ensemble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sec.contenu.add_child(_etat_ensemble)
	# L'ÉMISSION (Jordan, 6 octobre 2026) : une carte « _emission » (ou « _emissive ») à côté de l'image la fait luire ;
	# sa force est un réglage du matériau, qui part dans le .glb. Au-delà de 1, le halo du Play test la fait rayonner.
	_force_emission = _curseur(sec.contenu, "Emission", 0.0, 20.0, 0.1, "emission")
	_force_emission.tooltip_text = ("Strength of the emission map found next to the image (rock_emission.png). "
		+ "Above 1, the Glow of the Play test makes it shine.")
	_ligne_emission = _force_emission.get_parent()
	_case_pbr = CheckBox.new()
	_case_pbr.text = "Derive PBR maps from the image"
	_case_pbr.focus_mode = Control.FOCUS_NONE
	_case_pbr.toggled.connect(_basculer_pbr)
	sec.contenu.add_child(_case_pbr)
	_reglages_pbr = VBoxContainer.new()
	sec.contenu.add_child(_reglages_pbr)
	for r in REGLAGES_PBR:
		var cle_pbr: String = r[1]
		var c := _curseur_libre(_reglages_pbr, r[0], r[2], r[3], r[4], r[5])
		c.value_changed.connect(func(v: float) -> void: _retoucher_pbr(cle_pbr, v))
		_curseurs_pbr[cle_pbr] = c
	_case_inverser = CheckBox.new()
	_case_inverser.text = "Dark is high"
	_case_inverser.focus_mode = Control.FOCUS_NONE
	_case_inverser.tooltip_text = "By default the bright parts of the image are the high ones; tick it for the opposite."
	_case_inverser.toggled.connect(func(v: bool) -> void: _retoucher_pbr("inverser", v))
	_reglages_pbr.add_child(_case_inverser)
	_reglages_pbr.add_child(_bouton("Reset settings", "Back to the default settings.", func() -> void:
		if _modeleur.materiau_courant >= 0:
			_retoucher("pbr", Cartes.DEFAUTS.duplicate())
			_redire_les_materiaux(), "croix"))
	_etat_pbr = _texte("", 11, Palette.AMBRE)
	sec.contenu.add_child(_etat_pbr)

	sec.contenu.add_child(_petit_titre("BASE COLOUR FROM THE GEOMETRY"))
	sec.contenu.add_child(_texte("Bakes the base of the canvas from the shape itself: floors, walls and ceilings by "
		+ "their colour, worn convex edges, shaded hollows — quiet along the cut planes, where any tile may meet any "
		+ "other. Needs the UV projection (Unwrap all tiles). Your paint layers stay on top.", 11, Palette.GRIS))
	var couleurs := GridContainer.new()
	couleurs.columns = 2
	for e in [["Floors", "sol"], ["Walls", "paroi"], ["Ceilings", "plafond"], ["Wear", "arete"]]:
		var b := ColorPickerButton.new()
		b.text = e[0]
		b.edit_alpha = false
		b.custom_minimum_size = Vector2(0, 28)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cle_relief: String = e[1]
		b.color_changed.connect(func(c: Color) -> void: _retoucher_relief(cle_relief, [c.r, c.g, c.b]))
		couleurs.add_child(b)
		_couleurs_relief[cle_relief] = b
	sec.contenu.add_child(couleurs)
	for r in REGLAGES_RELIEF:
		var cle_relief: String = r[1]
		var c := _curseur_libre(sec.contenu, r[0], r[2], r[3], r[4], r[5])
		c.value_changed.connect(func(v: float) -> void: _retoucher_relief(cle_relief, v))
		_curseurs_relief[cle_relief] = c
	_bouton_cuire = _bouton("Bake base colour", "Replaces the BASE of this material's canvas (under the paint "
		+ "layers) with the colour read from the geometry. Ctrl+Z undoes it.", func() -> void:
			_regler_edition(true)
			_modeleur.cuire_le_relief()
			_redire_les_materiaux(), "remplir", Palette.PRINCIPAL)
	sec.contenu.add_child(_bouton_cuire)


## LE SCULPT (Jordan, 3 octobre 2026) — `Modeleur.sculpt` : un interrupteur, cinq pinceaux, rayon, force, dureté.
func _batir_sculpt(pile: VBoxContainer) -> void:
	var sec := Section.new("Sculpt", true, Icones.icone("grandir"))
	pile.add_child(sec)
	sec.contenu.add_child(_texte("Brushes push the shape under the mouse, like Blender's sculpt mode. Every copy of "
		+ "the tile follows; border points slide in their cut plane and the tiles around follow; a stroke stops "
		+ "before folding a face. Ctrl digs instead, Shift smooths. One Ctrl+Z per stroke.", 11, Palette.GRIS))
	_bouton_sculpt = Button.new()
	_bouton_sculpt.text = "Sculpt"
	_bouton_sculpt.icon = Icones.icone("grandir")
	_bouton_sculpt.toggle_mode = true
	_bouton_sculpt.focus_mode = Control.FOCUS_NONE
	_bouton_sculpt.custom_minimum_size = Vector2(0, 34)
	_bouton_sculpt.tooltip_text = "Left drag sculpts; Ctrl digs, Shift smooths. Click again to select and move again."
	_bouton_sculpt.toggled.connect(func(v: bool) -> void:
		if v:
			_regler_edition(true)
		_modeleur.regler_sculpt(v))
	_modeleur.sculpt_change.connect(func(v: bool) -> void: _bouton_sculpt.set_pressed_no_signal(v))
	sec.contenu.add_child(_bouton_sculpt)
	var groupe := ButtonGroup.new()
	var pinceaux: Array = []
	for g in [["Draw", "draw", "Pushes out along the surface (Ctrl: digs in)."],
			["Inflate", "inflate", "Swells each point along its own normal (Ctrl: shrinks)."],
			["Smooth", "smooth", "Evens out bumps (also Shift with any brush)."],
			["Flatten", "flatten", "Pulls the points onto their average plane."],
			["Grab", "grab", "Drags the shape under the brush with the mouse."]]:
		var b := Button.new()
		b.text = g[0]
		b.tooltip_text = g[2]
		b.toggle_mode = true
		b.button_group = groupe
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = g[1] == _modeleur.sculpt_genre
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var genre: String = g[1]
		b.pressed.connect(func() -> void: _modeleur.sculpt_genre = genre)
		pinceaux.append(b)
		_boutons_sculpt[genre] = b
	sec.contenu.add_child(_grille(pinceaux, 3))
	for r in [["Radius", 0.03, 1.0, 0.01, "sculpt_rayon", "The brush radius, in cells."],
			["Strength", 0.05, 1.0, 0.01, "sculpt_force", "How far one dab moves the shape."],
			["Hardness", 0.0, 1.0, 0.01, "sculpt_durete", "Full strength up to this part of the radius, then softer."]]:
		var c := _curseur_libre(sec.contenu, r[0], r[1], r[2], r[3], r[5])
		c.value = _modeleur.get(r[4])
		var prop: String = r[4]
		c.value_changed.connect(func(v: float) -> void: _modeleur.set(prop, v))
		_curseurs_sculpt[prop] = c


var _bouton_sculpt: Button
var _boutons_sculpt := {}
var _curseurs_sculpt := {}


## Un curseur nommé, sans branchement (l'appelant le branche).
func _curseur_libre(parent: Control, nom: String, mini: float, maxi: float, pas: float, aide: String) -> HSlider:
	var ligne := HBoxContainer.new()
	var l := _texte(nom, 11, Palette.GRIS)
	l.custom_minimum_size = Vector2(80, 0)
	ligne.add_child(l)
	var c := HSlider.new()
	c.min_value = mini
	c.max_value = maxi
	c.step = pas
	c.tooltip_text = aide
	c.focus_mode = Control.FOCUS_NONE
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(c)
	parent.add_child(ligne)
	return c


## Allume ou éteint les cartes du matériau courant. Allumer sans image lui donne une toile (de sa couleur) : les cartes
## se déduisent d'une image.
func _basculer_pbr(oui: bool) -> void:
	if _remplit_materiau or _modeleur.maillage == null or _modeleur.materiau_courant < 0:
		return
	_regler_edition(true)
	var k: int = _modeleur.materiau_courant
	if oui and str(_modeleur.maillage.materiaux[k].get("texture", "")) == "":
		_modeleur._preparer_la_toile(k)
	_retoucher("pbr", Cartes.DEFAUTS.duplicate() if oui else null)
	_redire_les_materiaux()


func _retoucher_pbr(cle_pbr: String, valeur: Variant) -> void:
	if _remplit_materiau or _modeleur.maillage == null or _modeleur.materiau_courant < 0:
		return
	var actuel: Variant = _modeleur.maillage.materiaux[_modeleur.materiau_courant].get("pbr")
	if not actuel is Dictionary:
		return
	var g: Dictionary = Cartes.reglages(actuel)
	g[cle_pbr] = valeur
	_retoucher("pbr", g)


func _retoucher_relief(cle_relief: String, valeur: Variant) -> void:
	if _remplit_materiau or _modeleur.maillage == null or _modeleur.materiau_courant < 0:
		return
	var g: Dictionary = TL.reglages_du_relief(_modeleur.maillage.materiaux[_modeleur.materiau_courant].get("relief"))
	g[cle_relief] = valeur
	_retoucher("relief", g)


## Remplit la section PBR depuis le matériau courant (appelée par `_redire_les_materiaux`, `_remplit_materiau` tenu).
func _redire_le_pbr(d: Dictionary) -> void:
	if _case_pbr == null:
		return
	var actif: bool = d.get("pbr") is Dictionary
	var fichiers: Dictionary = Peinture.fichiers_de_l_ensemble(str(d.get("texture", "")))
	var a_un_ensemble := fichiers.has("normale") or fichiers.has("rugosite") or fichiers.has("occlusion") 		or fichiers.has("orm") or fichiers.has("emission")
	var relief_pris := bool(d.get("ensemble", true)) and (fichiers.has("normale") or fichiers.has("rugosite") 		or fichiers.has("occlusion") or fichiers.has("orm"))
	var ensemble_pris := a_un_ensemble and bool(d.get("ensemble", true))
	_case_ensemble.visible = a_un_ensemble
	_case_ensemble.button_pressed = ensemble_pris
	var noms := {"normale": "normal", "rugosite": "roughness", "occlusion": "occlusion", "metal": "metal",
		"orm": "packed AO-rough-metal", "hauteur": "height (not used)", "emission": "emission"}
	var lus: Array = []
	for carte in noms:
		if fichiers.has(carte):
			lus.append("%s (%s)" % [noms[carte], (fichiers[carte] as String).get_file()])
	_etat_ensemble.visible = a_un_ensemble
	_etat_ensemble.text = ("Texture set found: " + ", ".join(PackedStringArray(lus)) + "."
		+ ("" if ensemble_pris else " Not used: the maps below are derived instead.")) if a_un_ensemble else ""
	_ligne_emission.visible = ensemble_pris and fichiers.has("emission")
	_force_emission.value = float(d.get("emission", 1.0))
	# Une émission SEULE ne porte pas de relief : les cartes déduites restent possibles à côté d'elle.
	_case_pbr.disabled = relief_pris
	_case_pbr.button_pressed = actif
	_reglages_pbr.visible = actif and not relief_pris
	var g: Dictionary = Cartes.reglages(d.get("pbr"))
	for cle_pbr in _curseurs_pbr:
		(_curseurs_pbr[cle_pbr] as HSlider).value = float(g[cle_pbr])
	_case_inverser.button_pressed = bool(g["inverser"])
	var r: Dictionary = TL.reglages_du_relief(d.get("relief"))
	for cle_relief in _couleurs_relief:
		var a: Array = r[cle_relief]
		(_couleurs_relief[cle_relief] as ColorPickerButton).color = Color(float(a[0]), float(a[1]), float(a[2]))
	for cle_relief in _curseurs_relief:
		(_curseurs_relief[cle_relief] as HSlider).value = float(r[cle_relief])


## L'état des cartes, une fois par image : « updating… » tant qu'une toile attend les siennes.
func _dire_l_etat_pbr() -> void:
	if _etat_pbr == null or not _etat_pbr.is_visible_in_tree():
		return
	var texte := "PBR maps: updating…" if Peinture.cartes_en_retard() > 0 else ""
	if _etat_pbr.text != texte:
		_etat_pbr.text = texte



## LE PINCEAU (Jordan, 1er octobre 2026 : « dessiner la texture […] avec les outils de peinture classiques »).
func _batir_peinture(pile: VBoxContainer) -> void:
	var sec := Section.new("Paint", true, Icones.icone("texture"))
	pile.add_child(sec)
	sec.contenu.add_child(_texte("Paint the image of a face's material, right on the witness: every copy of "
		+ "the tile follows. A material without an image gets a canvas filled with its colour. Box projection "
		+ "repeats the image, so the paint repeats; for unique paint, Unwrap (U) and choose the UV projection.",
		11, Palette.GRIS))
	_bouton_pinceau = Button.new()
	_bouton_pinceau.text = "Paint  ·  P"
	_bouton_pinceau.icon = Icones.icone("remplir")
	_bouton_pinceau.toggle_mode = true
	_bouton_pinceau.focus_mode = Control.FOCUS_NONE
	_bouton_pinceau.custom_minimum_size = Vector2(0, 34)
	_bouton_pinceau.tooltip_text = "P — left drag paints, Alt+click picks a colour. P again selects faces."
	_bouton_pinceau.toggled.connect(func(v: bool) -> void:
		if v:
			_regler_edition(true)
		_modeleur.regler_pinceau(v))
	sec.contenu.add_child(_bouton_pinceau)
	# LA GOMME (Jordan, 2 octobre 2026) : E, tant que le pinceau est allumé.
	_bouton_gomme = Button.new()
	_bouton_gomme.text = "Eraser  ·  E"
	_bouton_gomme.icon = Icones.icone("gomme")
	_bouton_gomme.toggle_mode = true
	_bouton_gomme.focus_mode = Control.FOCUS_NONE
	_bouton_gomme.tooltip_text = ("E — the brush makes the ACTIVE layer transparent. On the bottom layer, the canvas "
		+ "comes back as it was before any paint.")
	_bouton_gomme.toggled.connect(func(v: bool) -> void:
		if v and not _modeleur.pinceau:
			_bouton_pinceau.button_pressed = true
		if v != _modeleur.gomme:
			_modeleur.regler_gomme(v))
	_modeleur.gomme_changee.connect(func(v: bool) -> void: _bouton_gomme.set_pressed_no_signal(v))
	sec.contenu.add_child(_bouton_gomme)
	_couleur_pinceau = ColorPickerButton.new()
	_couleur_pinceau.text = "Colour"
	_couleur_pinceau.color = _modeleur.pinceau_couleur
	_couleur_pinceau.edit_alpha = false
	_couleur_pinceau.custom_minimum_size = Vector2(0, 30)
	_couleur_pinceau.color_changed.connect(func(c: Color) -> void: _modeleur.pinceau_couleur = c)
	sec.contenu.add_child(_couleur_pinceau)
	for r in [["Size (px)", 1.0, 200.0, 1.0, "pinceau_taille"], ["Hardness", 0.0, 1.0, 0.01, "pinceau_durete"],
			["Opacity", 0.02, 1.0, 0.01, "pinceau_opacite"]]:
		var ligne := HBoxContainer.new()
		var t := _texte(r[0], 11, Palette.GRIS)
		t.custom_minimum_size = Vector2(76, 0)
		ligne.add_child(t)
		var c := HSlider.new()
		c.min_value = r[1]
		c.max_value = r[2]
		c.step = r[3]
		c.value = _modeleur.get(r[4])
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.focus_mode = Control.FOCUS_NONE
		var prop: String = r[4]
		c.value_changed.connect(func(v: float) -> void: _modeleur.set(prop, v))
		ligne.add_child(c)
		sec.contenu.add_child(ligne)
		_curseurs_pinceau[prop] = c
	# Les bandes de couture (Jordan, 1er octobre 2026) : elles se montrent pendant qu'on peint.
	_case_bandes = CheckBox.new()
	_case_bandes.text = "Seam bands"
	_case_bandes.button_pressed = _modeleur.bandes_de_couture
	_case_bandes.focus_mode = Control.FOCUS_NONE
	_case_bandes.tooltip_text = ("While painting, striped bands mark the cut planes. Along them every tile must "
		+ "carry the same texture, or the painted world shows a seam at each joint.")
	_case_bandes.toggled.connect(func(v: bool) -> void:
		_modeleur.bandes_de_couture = v
		_modeleur.regler_les_bandes())
	sec.contenu.add_child(_case_bandes)
	# Un albedo animé par images : le pinceau peint UNE image (`app/animation.gd`).
	sec.contenu.add_child(_animation.rangee_peinture())
	_batir_calques(sec.contenu)


# ── LES CALQUES (Jordan, 2 octobre 2026) ───────────────────────────────────────────────────────────────
#
# La pile de la toile du MATÉRIAU COURANT (`Peinture`, « LES CALQUES ») : du haut vers le bas comme partout ; un clic
# rend un calque actif (le pinceau et la gomme y écrivent), l'œil le montre ou le cache. New, Up, Down, Delete, le
# nom et l'opacité de l'actif. Chaque geste est UNE annulation (l'état de la pile avant et après).

func _batir_calques(contenu: Control) -> void:
	var titre := HBoxContainer.new()
	var ic := TextureRect.new()
	ic.texture = Icones.icone("couches")
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	titre.add_child(ic)
	titre.add_child(_texte("Paint layers", 12, Palette.TEXTE))
	contenu.add_child(titre)
	_etat_calques = _texte("", 11, Palette.GRIS)
	contenu.add_child(_etat_calques)
	_liste_calques = VBoxContainer.new()
	contenu.add_child(_liste_calques)
	_reglages_calque = VBoxContainer.new()
	contenu.add_child(_reglages_calque)
	_nom_calque = LineEdit.new()
	_nom_calque.placeholder_text = "Layer name"
	_nom_calque.text_submitted.connect(func(t: String) -> void:
		var r: int = _toile_courante().get("actif", -1)
		_geste_calques("Paint: rename layer", func(c: String) -> void: Peinture.regler_calque(c, r, "nom", t)))
	_reglages_calque.add_child(_nom_calque)
	var ligne := HBoxContainer.new()
	var t := _texte("Opacity", 11, Palette.GRIS)
	t.custom_minimum_size = Vector2(76, 0)
	ligne.add_child(t)
	_opacite_calque = HSlider.new()
	_opacite_calque.min_value = 0.0
	_opacite_calque.max_value = 1.0
	_opacite_calque.step = 0.01
	_opacite_calque.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opacite_calque.focus_mode = Control.FOCUS_NONE
	# ⚠ Recomposer une toile de 1024² à chaque cran du glissé coûterait trop : l'opacité s'applique au lâcher (ou
	# tout de suite quand on clique sans glisser).
	_opacite_calque.drag_started.connect(func() -> void: _opacite_glisse = true)
	_opacite_calque.drag_ended.connect(func(_change: bool) -> void:
		_opacite_glisse = false
		_regler_l_opacite_du_calque(_opacite_calque.value))
	_opacite_calque.value_changed.connect(func(v: float) -> void:
		if not _opacite_glisse and not _remplit_calques:
			_regler_l_opacite_du_calque(v))
	ligne.add_child(_opacite_calque)
	_reglages_calque.add_child(ligne)
	var boutons := HBoxContainer.new()
	for b in [["New", "plus", "A new transparent layer above the active one.", func(c: String) -> void:
				Peinture.nouveau_calque(c)],
			["Up", "haut", "Move the active layer up.", func(c: String) -> void:
				Peinture.deplacer_calque(c, int(Peinture.toile(c)["actif"]), 1)],
			["Down", "bas", "Move the active layer down.", func(c: String) -> void:
				Peinture.deplacer_calque(c, int(Peinture.toile(c)["actif"]), -1)],
			["Delete", "poubelle", "Delete the active layer (the last one stays).", func(c: String) -> void:
				Peinture.supprimer_calque(c, int(Peinture.toile(c)["actif"]))]]:
		var nom: String = b[0]
		var action: Callable = b[3]
		var bouton := _bouton(nom, b[2], func() -> void: _geste_calques("Paint: %s layer" % nom.to_lower(), action), b[1])
		bouton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boutons.add_child(bouton)
		_boutons_calques[nom] = bouton
	_reglages_calque.add_child(boutons)
	# FUSIONNER VERS LE BAS (3 octobre 2026) : l'image ne change pas, la pile perd un calque. Un Ctrl+Z.
	var fusion := _bouton("Merge down", "Merges the active layer into the one below it — the image does not change. "
		+ "Both must be visible.", func() -> void: _geste_calques("Paint: merge layer down", func(c: String) -> void:
			Peinture.fusionner_vers_le_bas(c, int(Peinture.toile(c)["actif"]))), "bas")
	_reglages_calque.add_child(fusion)
	_boutons_calques["Merge down"] = fusion
	_redire_les_calques()


var _etat_calques: Label
var _liste_calques: VBoxContainer
var _reglages_calque: VBoxContainer
var _nom_calque: LineEdit
var _opacite_calque: HSlider
var _opacite_glisse := false
var _remplit_calques := false
var _boutons_calques := {}


## Le chemin de la toile du matériau courant ("" s'il n'en a pas encore).
func _chemin_toile_courante() -> String:
	var k: int = _modeleur.materiau_courant
	if _modeleur.maillage == null or k < 0 or k >= _modeleur.maillage.materiaux.size():
		return ""
	# Un albedo animé par images : la toile de l'image qu'on peint (`Modeleur.chemin_peint`).
	return _modeleur.chemin_peint(_modeleur.maillage.materiaux[k])


func _toile_courante() -> Dictionary:
	var c := _chemin_toile_courante()
	return Peinture.toile(c) if c != "" else {}


## UN geste sur la pile de la toile courante : `action(chemin)`, entre deux états, une annulation.
func _geste_calques(nom: String, action: Callable) -> void:
	var c := _chemin_toile_courante()
	if c == "" or Peinture.toile(c).is_empty():
		return
	var avant: Dictionary = Peinture.etat(c)
	action.call(c)
	var apres: Dictionary = Peinture.etat(c)
	_histoire.create_action(nom)
	_histoire.add_do_method(func() -> void:
		Peinture.poser_etat(c, apres)
		_redire_les_calques())
	_histoire.add_undo_method(func() -> void:
		Peinture.poser_etat(c, avant)
		_redire_les_calques())
	_histoire.commit_action(false)
	_temoin_modifie(_modeleur.temoin)
	_redire_les_calques()


func _regler_l_opacite_du_calque(v: float) -> void:
	var r: int = _toile_courante().get("actif", -1)
	if r < 0 or is_equal_approx(float(_toile_courante()["calques"][r]["opacite"]), v):
		return
	_geste_calques("Paint: layer opacity", func(c: String) -> void: Peinture.regler_calque(c, r, "opacite", v))


## Redessine la liste (du HAUT vers le bas) et les réglages de l'actif.
func _redire_les_calques() -> void:
	if _liste_calques == null:
		return
	for enfant in _liste_calques.get_children():
		_liste_calques.remove_child(enfant)
		enfant.queue_free()
	var c := _chemin_toile_courante()
	var t := _toile_courante()
	_reglages_calque.visible = not t.is_empty()
	if _modeleur.materiau_courant < 0:
		_etat_calques.text = "Pick a material: its canvas's layers show here."
		return
	if t.is_empty():
		_etat_calques.text = "This material has no canvas yet: paint on one of its faces to make it."
		return
	_etat_calques.text = "Layers of « %s »%s" % [c.get_file(), "" if not t["calques_ecartes"] else
		"\nThe image was changed outside MarchingBlocks: its old layers were set aside, it is now one layer."]
	var groupe := ButtonGroup.new()
	var cal: Array = t["calques"]
	for i in range(cal.size() - 1, -1, -1):
		var d: Dictionary = cal[i]
		var ligne := HBoxContainer.new()
		var oeil := Button.new()
		oeil.icon = Icones.icone("oeil" if d["visible"] else "oeil_ferme")
		oeil.flat = true
		oeil.focus_mode = Control.FOCUS_NONE
		oeil.tooltip_text = "Show or hide this layer."
		var rang := i
		oeil.pressed.connect(func() -> void:
			_geste_calques("Paint: layer visibility", func(ch: String) -> void:
				Peinture.regler_calque(ch, rang, "visible", not bool(Peinture.toile(ch)["calques"][rang]["visible"]))))
		ligne.add_child(oeil)
		var b := Button.new()
		b.text = str(d["nom"]) + ("" if float(d["opacite"]) >= 1.0 else "  (%d%%)" % roundi(float(d["opacite"]) * 100))
		b.toggle_mode = true
		b.button_group = groupe
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = i == int(t["actif"])
		b.pressed.connect(func() -> void:
			Peinture.choisir_calque(c, rang)
			_redire_les_calques())
		ligne.add_child(b)
		_liste_calques.add_child(ligne)
	var actif: Dictionary = cal[int(t["actif"])]
	_remplit_calques = true
	_nom_calque.text = str(actif["nom"])
	_opacite_calque.value = float(actif["opacite"])
	_remplit_calques = false
	_boutons_calques["Delete"].disabled = cal.size() <= 1
	_boutons_calques["Up"].disabled = int(t["actif"]) >= cal.size() - 1
	_boutons_calques["Down"].disabled = int(t["actif"]) <= 0
	_boutons_calques["Merge down"].disabled = (int(t["actif"]) <= 0 or not bool(actif["visible"])
		or not bool(cal[int(t["actif"]) - 1]["visible"]))


var _bouton_gomme: Button
var _case_bandes: CheckBox
var _bouton_pinceau: Button
var _couleur_pinceau: ColorPickerButton
var _curseurs_pinceau := {}


## Un trait fini : UNE annulation, qui remet la région de la toile d'avant (ou d'après).
func _trait_peint(chemin: String, avant: Image, apres: Image, position: Vector2i, calque: Image) -> void:
	_histoire.create_action("Witness: Paint")
	_histoire.add_do_method(Peinture.poser_region.bind(chemin, apres, position, calque))
	_histoire.add_undo_method(Peinture.poser_region.bind(chemin, avant, position, calque))
	_histoire.commit_action(false)
	_temoin_modifie(_modeleur.temoin)
	# Le premier trait crée la toile : la liste des calques apparaît.
	_redire_les_calques()


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
		_modeleur.dossier_toiles = _chemin_temoin_de(_couches[_active]).get_basename() + "_images"
		_donner_les_autres_temoins()
		if _modeleur.temoin != t:
			_modeleur.charger_temoin(t, _occurrence_de_depart(t))
			_redire_les_materiaux()
			_legende_formes.rafraichir_tuiles()
		var ancien := _projet.get_basename() + "_witness.mbmesh"
		if _origine_du_temoin(_couches[_active]) == "computed witness" and FileAccess.file_exists(ancien):
			dit_ancien = ("\n[color=#f2ca79]An older single-mesh model was found[/color] (%s): it is kept on "
				+ "disk but not used — the linked editor starts from the computed witness.") % ancien.get_file()
	_vue.regler_edition(oui)
	for b in _boutons_edition:
		(b as Button).set_pressed_no_signal(oui)
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


var _trous_texte: Label
var _trous_lus_a := 0


var _ecarts_texte: Label
var _bouton_caler: Button
## Le compte des bords entre couches est périmé. ⚠ MESURÉ (6 octobre 2026) : ~55 ms par couche (il réindexe tous les
## témoins), 166 ms avec trois — trop pour le relire après chaque geste. Les gestes gardent les bords ensemble : il n'est
## relu qu'à l'entrée en édition et au changement de couche (`_donner_les_autres_temoins`), après « Match », et après une
## annulation qui a touché d'autres couches.
var _ecarts_perimes := true
var _ecarts_lus_a := -100000


func _caler_les_autres_couches() -> void:
	_regler_edition(true)
	var r: Dictionary = _modeleur.caler_les_autres_couches()
	_ecarts_perimes = true
	if r.is_empty():
		return
	var touchees: Array = r.get("touchees", [])
	if touchees.is_empty():
		_dire("[i]The other layers already have the same borders as this one.[/i]")
		return
	var couches := {}
	for c in touchees:
		couches[str(c).get_slice("/", 0) if str(c).begins_with("@") else "ici"] = true
	var reste := int(r["restants"]) + int(r["sur_arete"]) + int(r["non_inseres"])
	_dire(("[b]Borders matched[/b] — %d vertex(es) moved, %d added, in %d tile(s) of %d other layer(s). %s[i]Ctrl+Z "
		+ "undoes it. The world follows when you open World.[/i]") % [int(r["deplaces"]),
		int(r["inseres"]) + int(r["coupes"]), touchees.size(), couches.size() - (1 if couches.has("ici") else 0),
		("" if reste == 0 else "[color=#e0603c]%d border point(s) could not be matched: a gap stays there.[/color] " % reste)
		+ ("" if int(r["replies"]) == 0 else "[color=#e0a03c]%d tile(s) got a folded face: check them.[/color] " % int(r["replies"]))])


## Sous le bouton : les couches se raccordent-elles ? Relu après un changement, au plus une fois par seconde.
func _dire_les_ecarts() -> void:
	if _ecarts_texte == null or _atelier != "witness" or not _vue.edition:
		return
	var maintenant := Time.get_ticks_msec()
	if not _ecarts_perimes or maintenant - _ecarts_lus_a < 1000 or _modeleur.modal != "":
		return
	_ecarts_perimes = false
	_ecarts_lus_a = maintenant
	var n: int = _modeleur.ecarts_entre_couches()
	_ecarts_texte.visible = n >= 0
	_bouton_caler.visible = n >= 0
	if n < 0:
		return
	_ecarts_texte.text = "Borders: the same as the other layers." if n == 0 else 		"Borders: %d point(s) differ from the other layers — a gap where they meet in the world." % n
	_ecarts_texte.add_theme_color_override("font_color", Palette.GRIS if n == 0 else Color("#e0603c"))


func _boucher_les_trous(toutes: bool) -> void:
	_regler_edition(true)
	_modeleur.boucher_les_trous(toutes)
	_dire_les_trous(true)


## Le compteur de trous, sous les boutons : relu au plus quatre fois par seconde, dans Geometry, en édition.
func _dire_les_trous(tout_de_suite := false) -> void:
	if _trous_texte == null or _atelier != "witness" or not _vue.edition:
		return
	var maintenant := Time.get_ticks_msec()
	if not tout_de_suite and maintenant - _trous_lus_a < 250:
		return
	_trous_lus_a = maintenant
	var n: int = _modeleur.trous_de_la_tuile()
	_trous_texte.text = "No hole in this tile." if n == 0 else "%d hole(s) in this tile." % n
	_trous_texte.add_theme_color_override("font_color", Palette.GRIS if n == 0 else Color("#e0603c"))


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
		"lasso":
			_modeleur.commencer_lasso()
		"cercle":
			_modeleur.commencer_cercle()
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
	if apres is TL.Lot:
		for t2 in (apres as TL.Lot).ailleurs:
			_temoin_modifie(t2)


func _remplacer_temoin(t: RefCounted, m: RefCounted) -> void:
	if t == _modeleur.temoin:
		_modeleur.remplacer(m)
	elif m is TL.Lot:
		for c in (m as TL.Lot).tuiles:
			t.poser_tuile(c, (m as TL.Lot).tuiles[c])
	elif m.has_meta("cle"):
		t.poser_tuile(m.get_meta("cle"), m)
	_temoin_modifie(t)
	# LES TUILES DES AUTRES COUCHES que le geste a entraînées (les bords partagés, 6 octobre 2026) : chacune dans SON
	# témoin — celui qu'on édite peut être l'un d'eux, si l'on a changé de couche depuis le geste.
	if m is TL.Lot:
		if not (m as TL.Lot).ailleurs.is_empty():
			_ecarts_perimes = true
		for t2 in (m as TL.Lot).ailleurs:
			var tuiles: Dictionary = (m as TL.Lot).ailleurs[t2]
			if t2 == _modeleur.temoin:
				var l2 := TL.Lot.new()
				l2.tuiles = tuiles
				_modeleur.remplacer(l2)
			else:
				for nom in tuiles:
					t2.poser_tuile(nom, tuiles[nom])
			_temoin_modifie(t2)


## LES BORDS SONT PARTAGÉS ENTRE COUCHES (Jordan, 6 octobre 2026 : « il y a des fentes, je les ai vues ») : deux couches
## se touchent dans le monde, donc les sections de leurs témoins doivent être les mêmes. Le modeleur reçoit les témoins
## des AUTRES couches qui suivent leur témoin ; une couche habillée par un travail externe non lié n'en est pas — ses
## tuiles ne viennent pas de son témoin.
func _donner_les_autres_temoins() -> void:
	_ecarts_perimes = true
	var liste: Array = []
	for c in _couches:
		if _couches.find(c) == _active or not _suit_son_temoin(c):
			continue
		liste.append(_temoin_de(c))
	_modeleur.regler_les_autres_temoins(liste)


func _suit_son_temoin(c: Dictionary) -> bool:
	var s := str(c.get("source", ""))
	return s == "" or s == Projet.TEMOIN or s == _glb_du_temoin(c)


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
		_redire_le_pbr(d)
		_remplit_materiau = false
	if _section_pbr != null:
		_section_pbr.visible = k >= 0
	_redire_les_calques()


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
## `complet` : écrit AUSSI le `.glb` et rhabille le monde tout de suite (Ctrl+S, la fermeture, le tranchage).
func _enregistrer_le_temoin_modele(complet := false) -> String:
	if _modeleur.temoin != null:
		_temoins_sales[_modeleur.temoin] = true
	var raison := ""
	# LES TOILES PEINTES d'abord : le .mbtiles cite leurs chemins, et le .glb les embarque.
	for e in Peinture.enregistrer():
		if str(e).begins_with("!"):
			raison = "a paint canvas could not be written: " + str(e).substr(1)
	# Les cartes : un enregistrement COMPLET (Ctrl+S, la fermeture, le tranchage) les finit d'abord ; l'enregistrement
	# différé (une seconde après un geste) n'écrit que celles qui sont déjà à jour — il ne doit pas geler l'écran.
	if complet:
		Peinture.suivre_les_cartes(true)
	for e in Peinture.enregistrer_les_cartes():
		if str(e).begins_with("!"):
			raison = "the PBR maps could not be written: " + str(e).substr(1)
	for t in _temoins_sales.keys():
		var c: Dictionary = _couche_du_temoin(t)
		if c.is_empty():
			continue   # la couche a été supprimée : son témoin revient avec elle (Ctrl+Z)
		var r := _enregistrer_temoin(c, complet)
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


## Écrit le témoin d'une couche : son `.mbtiles` (ce qui fait foi) TOUT DE SUITE ; son `.glb` lié et le monde
## qu'il habille, À LA DEMANDE (`_rhabiller`) — ou tout de suite avec `complet`. Rend "" ou la raison.
## ⚠ **LE .glb ET LE MONDE ATTENDENT QU'ON LES REGARDE (mesuré le 1er octobre 2026)** : l'enregistrement part
## une seconde après le dernier geste, et réécrire le `.glb` puis le relire pour reposer le monde gelait l'appli
## 3,6 s avec fenêtre (0,5 s après les corrections de relecture) — Jordan : « des lags d'environ une seconde à
## des moments différents ». Pendant qu'on modélise, le monde n'est pas affiché ; le `.mbtiles` s'écrit en 10 ms.
## Le monde suit son témoin quand on passe dans World ou Play test, avant un export, un tranchage, à Ctrl+S,
## au changement de projet et à la fermeture.
func _enregistrer_temoin(c: Dictionary, complet := false) -> String:
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
	c["_glb_perime"] = true
	var raison := _rhabiller(c) if complet else ""
	_oublier_la_vignette(c)
	_enregistrer()
	return raison


## Le `.glb` lié d'une couche réécrit depuis son témoin, et son monde rhabillé — s'il était en retard.
func _rhabiller(c: Dictionary) -> String:
	if not c.get("_glb_perime", false) or c.get("_temoin", null) == null:
		return ""
	# Le `.glb` de CETTE couche va être réécrit : l'étiquette de la liste relira son empreinte (les autres, non — tout
	# oublier faisait relire le MD5 de chaque `.glb` après chaque Ctrl+S, ~70 ms sur l'exemple).
	_empreintes_vues.erase(_glb_du_temoin(c))
	var raison: String = c["_temoin"].vers_glb(_glb_du_temoin(c))
	if raison != "":
		_dire("[color=#e0603c]The witness of « %s » could not be saved:[/color] %s" % [c["nom"], raison])
		return raison
	c.erase("_glb_perime")
	_suivre_son_temoin(c)
	return ""


## Toutes les couches en retard sur leur témoin rattrapées (la seconde d'attente comprise).
func _rhabiller_les_mondes() -> void:
	if _minuterie_temoin != null and not _minuterie_temoin.is_stopped():
		_minuterie_temoin.stop()
		_enregistrer_le_temoin_modele()
	var a_faire := false
	for c in _couches:
		a_faire = a_faire or c.get("_glb_perime", false)
	if not a_faire:
		return
	for c in _couches:
		_rhabiller(c)
	_rafraichir_couches()


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
	# ⚠ LE CACHE S'ÉCRIT PLUS TARD (`_ecrire_les_caches` : Ctrl+S, la fermeture, le changement de projet). MESURÉ (4 octobre
	# 2026, l'exemple) : l'écrire coûtait ~270 ms à chaque passage dans World après une retouche, pour ne servir qu'à la
	# prochaine ouverture. Le lot est marqué tout de suite de l'empreinte du `.glb` qu'il vient de lire ; un cache resté
	# en retard (l'appli coupée) porte l'empreinte d'avant, se voit périmé et la couche se relit de son `.glb`.
	# ⚠ PAS SUR UN AUTRE FIL : écrire un `ArrayMesh` relit ses surfaces au RenderingServer, qui ne répond qu'au fil
	# principal — l'attendre à la fermeture serait un interblocage.
	Projet.marquer(lot, Projet.empreinte(propre))
	c["_cache_a_ecrire"] = {"lot": lot, "source": propre}
	c["source"] = propre
	_vue.couche(i).lot = lot


## Les lots que le monde a pris de son témoin, écrits dans le cache (voir `_suivre_son_temoin`).
func _ecrire_les_caches() -> void:
	for c in _couches:
		var a_ecrire = c.get("_cache_a_ecrire", null)
		if a_ecrire == null:
			continue
		c.erase("_cache_a_ecrire")
		var lot: MeshLibrary = a_ecrire["lot"]
		Projet.mettre_en_cache(lot, a_ecrire["source"], str(lot.get_meta("empreinte", "")))


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
	_enregistrer_le_temoin_modele(true)
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
	_enregistrer_temoin(c, true)
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
	# ⚠ LA VIGNETTE GARDÉE SUR DISQUE (4 octobre 2026) : la fabriquer demande le témoin ENTIER (son `.mbtiles`, ses images,
	# son assemblage) — à l'ouverture de l'exemple, ~1,2 s pour trois vignettes de 84 × 56. Un témoin pas encore chargé
	# dont le `.mbtiles` a déjà été photographié tel quel (même empreinte) se montre sans être chargé.
	var cle_disque := _cle_de_vignette(c)
	if c.get("_temoin", null) == null:
		var gardee := _vignette_en_cache(cle_disque)
		if gardee != null:
			c["_vignette"] = gardee
			return gardee
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
	if cle_disque != "" and _ecran_vivant() and not _temoins_sales.has(c.get("_temoin")):
		_garder_la_vignette.call_deferred(vue, cle_disque)
	return c["_vignette"]


## La clé d'une vignette sur disque : l'empreinte du `.mbtiles` du témoin, "" s'il n'en a pas (témoin calculé, ou relu
## d'un `.glb` jamais enregistré).
func _cle_de_vignette(c: Dictionary) -> String:
	var chemin := str(c.get("temoin", ""))
	if chemin == "" or not FileAccess.file_exists(chemin):
		return ""
	return FileAccess.get_md5(chemin)


const DOSSIER_VIGNETTES := "user://cache/vignettes"


static func _chemin_de_vignette(cle: String) -> String:
	return DOSSIER_VIGNETTES.path_join(cle + ".png")


## La vignette gardée sous cette clé, ou null.
static func _vignette_en_cache(cle: String) -> Texture2D:
	if cle == "" or not FileAccess.file_exists(_chemin_de_vignette(cle)):
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(_chemin_de_vignette(cle)))
	return ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null


## Une fois la vignette DESSINÉE (l'image suivante), on la garde sur disque. ⚠ Avec fenêtre seulement : sans rendu,
## `frame_post_draw` ne vient jamais (charte, la barre de progression).
func _garder_la_vignette(vue: SubViewport, cle: String) -> void:
	await RenderingServer.frame_post_draw
	if not is_instance_valid(vue):
		return
	var image := vue.get_texture().get_image()
	if image == null or image.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(DOSSIER_VIGNETTES)
	image.save_png(_chemin_de_vignette(cle))


func _oublier_la_vignette(c: Dictionary) -> void:
	var vue = c.get("_vue_vignette", null)
	if vue != null and is_instance_valid(vue):
		vue.queue_free()
	c["_vue_vignette"] = null
	c["_vignette"] = null


## L'état d'une couche, en une ligne : ses cases, et si ses tuiles viennent de son témoin tel qu'il est.
## L'EMPREINTE D'UN `.glb`, POUR L'ÉTIQUETTE DE LA LISTE SEULEMENT — gardée tant que sa date et sa taille ne bougent pas.
## ⚠ MESURÉ (4 octobre 2026, l'exemple, PC) : la liste se rafraîchit après chaque geste (elle recompte les cases), et
## relisait le MD5 de chaque `.glb` (24 Mo) — ~110 ms par geste. ⚠ Le CACHE DE TRANCHAGE garde le MD5 complet
## (`Projet.empreinte`) : une date n'est précise qu'à la seconde (§5). Ici, au pire, une étiquette en retard ; et toute
## écriture du `.glb` par l'appli (`_rhabiller`) vide cette mémoire.
var _empreintes_vues := {}


func _empreinte_pour_la_liste(chemin: String) -> String:
	if not FileAccess.file_exists(chemin):
		return Projet.empreinte(chemin)
	var f := FileAccess.open(chemin, FileAccess.READ)
	var signe := [FileAccess.get_modified_time(chemin), f.get_length() if f != null else -1]
	var vu: Variant = _empreintes_vues.get(chemin, null)
	if vu != null and vu[0] == signe:
		return vu[1]
	var e := Projet.empreinte(chemin)
	_empreintes_vues[chemin] = [signe, e]
	return e


func _etat_de(i: int) -> String:
	var c: Dictionary = _couches[i]
	var n: int = _vue.couche(i).nombre_de_cases()
	var s := str(c.get("source", ""))
	var etat := ""
	if s == "":
		etat = "not sliced"
	elif s == _glb_du_temoin(c):
		# L'empreinte du lot POSÉ contre celle du fichier — sans relire le cache du disque à chaque rafraîchissement.
		var lot: MeshLibrary = _vue.couche(i).lot
		var a_jour: bool = lot != null and str(lot.get_meta("empreinte", "")) == _empreinte_pour_la_liste(s) \
			and not _temoins_sales.has(c.get("_temoin"))
		etat = "sliced" if a_jour else "witness changed · slice again"
		if c.get("_glb_perime", false):
			etat = "sliced · follows its witness when you open World"
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
	# Un travail rouvert avec le projet n'est relu qu'ici, la première fois qu'on le regarde.
	if _travaux[_travail_actif]["maillage"] == null:
		_travaux[_travail_actif]["maillage"] = BM.travail_depuis_glb(_travail_chemin(), [])
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
	_aller_a(_atelier if _atelier in ["projet", "witness", "texture", "anim"] else "projet")


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
	elif quoi == "feuillage":
		_dialogue.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialogue.add_filter("*.glb", "glTF binary (a tree, a bush…)")
		_dialogue.title = "Import a foliage model"
		_dialogue.current_file = ""
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
			# ⚠ LA COULEUR MULTIPLIE L'IMAGE : une couleur sombre laissée d'avant (un gris à 0,39) assombrissait la texture
			# de moitié et plus — un rendu « vraiment pauvre » (Jordan, 3 octobre 2026). Une image choisie part en blanc,
			# comme dans Blender ; la couleur reste là pour la teinter.
			_retoucher("couleur", Color.WHITE)
			# ⚠ L'IMAGE EST COPIÉE DANS LE PROJET (Jordan, 3 octobre 2026), avec son ensemble PBR : peindre dessus
			# écrivait sinon hors du projet, et un projet déplacé perdait ses textures.
			var erreurs: Array = []
			var dossier: String = _modeleur.dossier_toiles if _modeleur.dossier_toiles != "" \
				else _projet.get_basename() + "_images"
			var copie := Peinture.copier_dans_le_projet(fichier, dossier, erreurs)
			if copie == "":
				_dire("[color=#e0603c]The image could not be copied into the project[/color] — %s. It is used where it "
					% ", ".join(PackedStringArray(erreurs)) + "is.")
				copie = fichier
			elif copie != fichier:
				_dire("[b]Image copied into the project[/b] → %s [i](its PBR maps with it, if any). Painting on it "
					% copie.get_base_dir().get_file() + "never touches the original.[/i]")
			_retoucher("texture", copie)
			_inscrire_les_retouches()
		"patron":
			_exporter_le_patron(fichier)
		"feuillage":
			_feuillage.importer(fichier)


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
		else _temoin_de(c_export).vers_glb(fichier, true)   # pour Blender : soudé, sans normales
	_empreintes_vues.clear()   # le fichier choisi peut être le `.glb` d'une couche
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
		+ "will read it: whatever leaves the block's box is gone.\n[i]« Slice the selected work » re-reads the "
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
		# CE QUE LE glTF NE PORTE PAS revient du témoin d'avant, par le nom du matériau (3 octobre 2026).
		var repris: int = lu.reprendre_les_reglages(_temoin_de(c))
		Peinture.oublier_les_ensembles()   # ses cartes viennent d'être réécrites sous les mêmes noms
		c["_temoin"] = lu
		c.erase("_lie")
		_temoins_sales[lu] = true
		_enregistrer_le_temoin_modele(true)
		if _modeleur.temoin != null:
			_donner_les_autres_temoins()
			_modeleur.charger_temoin(lu, _occurrence_de_depart(lu))
		var propre := _glb_du_temoin(c)
		var bilan_lie: Dictionary = await _trancher_source(propre)
		_poser_lot(bilan_lie, "work", propre, ("[b]%s became the witness of « %s »[/b] — edit it in Witness, "
			+ "slice it again in step 3.\n%s") % [chemin.get_file(), c["nom"],
			("%d material(s) kept their PBR settings (matched by name).\n" % repris) if repris > 0 else ""])
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
	# ⚠ SUR UN AUTRE FIL (`_en_fond`) : 2 s pour le témoin, ~17 s pour un travail non lié — la barre défile et
	# l'écran reste vivant au lieu de geler. Le cœur ne touche à aucun nœud de la scène.
	if source == Projet.TEMOIN:
		await _attendre("Slicing the witness", "52 tiles, one per key")
		bilan = await _en_fond(func() -> Dictionary: return BM.librairie())
	else:
		await _attendre("Slicing your work", source.get_file())
		bilan = await _en_fond(func() -> Dictionary: return BM.librairie_depuis_glb(source))
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
	_coup_autres = {}
	_coup_nom = ""


## Un morceau de coup : les cases sont posées TOUT DE SUITE, pour qu'on voie ce qu'on peint.
func _touche(modif: Dictionary, nom: String) -> void:
	var cases: GridMap = _vue.cases()
	var id: int = _id_case()
	if id < 0:
		return
	_coup_nom = nom if _coup_nom == "" or _coup_nom == nom else "Stroke"
	var changements := _changements(modif, cases, id)
	var posees: Array = []
	for c in changements:
		if not _coup.has(c):
			_coup[c] = changements[c].duplicate()
		else:
			_coup[c][1] = changements[c][1]
		cases.set_cell_item(c, changements[c][1])
		if changements[c][1] != GridMap.INVALID_CELL_ITEM:
			posees.append(c)
	# LES CASES SONT EXCLUSIVES : ce que le coup pose, les autres couches le perdent — dans le même Ctrl+Z.
	var changees: Array = changements.keys()
	var vols := _vols(posees)
	for g in vols:
		if not _coup_autres.has(g):
			_coup_autres[g] = {}
		for c in vols[g]:
			if not _coup_autres[g].has(c):
				_coup_autres[g][c] = (vols[g][c] as Array).duplicate()
			else:
				_coup_autres[g][c][1] = vols[g][c][1]
			(g as GridMap).set_cell_item(c, GridMap.INVALID_CELL_ITEM)
			changees.append(c)
	_suivre_les_cases(changees, true)   # le coup sait ce qu'il a changé : pas de garde de compte à chaque touche
	_vue.rafraichir()
	_noter_pour_l_eau(changees)
	# ⚠ L'EAU SUIT EN DIRECT TANT QU'ELLE EST RAPIDE ; sur un monde où elle coûte (audit : un recalcul complet par
	# image pendant tout le coup), elle attend la fin du coup — une fois.
	if float(_durees.get("eau", 0.0)) < 0.05:
		_eau_perimee()
	else:
		_eau_apres_le_coup = true


## ⚠ UN COUP ENTIER S'ANNULE D'UN SEUL Ctrl+Z — c'est ce qu'on attend d'un pinceau. Les cases sont déjà
## posées pendant le glissé ; l'action est donc enregistrée SANS être rejouée.
func _coup_fini() -> void:
	var fait := {}
	for c in _coup:
		if _coup[c][0] != _coup[c][1]:
			fait[c] = _coup[c]
	var fait_autres := {}
	for g in _coup_autres:
		for c in _coup_autres[g]:
			if _coup_autres[g][c][0] != _coup_autres[g][c][1]:
				if not fait_autres.has(g):
					fait_autres[g] = {}
				fait_autres[g][c] = _coup_autres[g][c]
	_coup = {}
	_coup_autres = {}
	if not fait.is_empty():
		_enregistrer_action(fait, _coup_nom if _coup_nom != "" else "Stroke", true, fait_autres)
		_compter_les_cases_plus_tard()
	if _eau_apres_le_coup:
		_eau_apres_le_coup = false
		_eau_perimee()
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
		var posees: Array = []
		for c in ch:
			if ch[c][1] != GridMap.INVALID_CELL_ITEM:
				posees.append(c)
		_enregistrer_action(ch, nom, false, _vols(posees))
	return ch.size()


## ⚠ L'ACTION NOMME SA GRILLE ET SON MASSIF, jamais « la couche active » : un Ctrl+Z après avoir changé
## de couche doit reconstruire la couche qu'il touche, pas celle qu'on regarde.
## `autres` : {grille d'une autre couche: {case: [avant, après]}} — ce que l'exclusivité leur retire, dans la même action.
func _enregistrer_action(ch: Dictionary, nom: String, deja_fait: bool, autres: Dictionary = {}) -> void:
	var cases: GridMap = _vue.cases()
	var massif: Node = _vue.monde()
	_histoire.create_action(nom)
	for c in ch:
		_histoire.add_do_method(cases.set_cell_item.bind(c, ch[c][1]))
		_histoire.add_undo_method(cases.set_cell_item.bind(c, ch[c][0]))
	for g in autres:
		for c in autres[g]:
			_histoire.add_do_method((g as GridMap).set_cell_item.bind(c, autres[g][c][1]))
			_histoire.add_undo_method((g as GridMap).set_cell_item.bind(c, autres[g][c][0]))
	# ⚠ SEULES LES CASES DE L'ACTION sont reconstruites (`reconstruire_autour`), dans les deux sens.
	var touchees: Array = ch.keys()
	for g in autres:
		touchees.append_array((autres[g] as Dictionary).keys())
	_histoire.add_do_method(_reconstruire.bind(massif, touchees))
	_histoire.add_undo_method(_reconstruire.bind(massif, touchees))
	_histoire.commit_action(not deja_fait)


## ── LES COUCHES EXCLUSIVES (DÉCIDÉ, Jordan, 2 octobre 2026 : « cases exclusives avec priorité par l'ordre ») ──────
## Une case n'appartient qu'à UNE couche : la poser dans la couche active la retire des autres (`_vols`). `_union`
## ({case: rang}) est PARTAGÉE avec chaque couche (`MassifPeint.union`) : le choix des tuiles la lit, et un sommet
## est posé par la couche de plus petit rang parmi ses huit cases (`MB.couche_du_sommet`). Seules les couches VISIBLES
## y entrent : cacher une couche rend au monde une surface fermée sans elle.
var _union := {}
var _coup_autres := {}
## LE MONDE DU CŒUR (étape 3 b, 6 octobre 2026) : partagé par toutes les couches de l'écran, il suit `_union` et pose
## leurs tuiles (`MassifPeint.monde`). Null sans le natif : chaque couche décide alors elle-même, en GDScript.
var _monde_coeur = null


func _le_monde_du_coeur() -> Variant:
	if _monde_coeur == null:
		_monde_coeur = MB.monde_natif()
	return _monde_coeur


## Ce que poser `posees` dans la couche active retire aux autres : {grille: {case: [avant, vide]}}.
func _vols(posees: Array) -> Dictionary:
	var active: GridMap = _vue.cases()
	var vols := {}
	if posees.is_empty():
		return vols
	for i in _vue.nombre_de_couches():
		var g := _vue.couche(i).get_node("Cases") as GridMap
		if g == active:
			continue
		for c in posees:
			var avant: int = g.get_cell_item(c)
			if avant != GridMap.INVALID_CELL_ITEM:
				if not vols.has(g):
					vols[g] = {}
				vols[g][c] = [avant, GridMap.INVALID_CELL_ITEM]
	return vols


## ⚠ LA LISTE DES COUCHES NE RECOMPTAIT JAMAIS SES CASES après un geste (« 0 cells » sur une couche peinte, vu à
## l'image le 2 octobre 2026) — et depuis l'exclusivité, un geste change le compte d'une AUTRE couche. Une fois par
## image au plus : un geste en rafale ne rebâtit pas la liste à chaque action.
var _comptage_prevu := false


func _compter_les_cases_plus_tard() -> void:
	if _comptage_prevu:
		return
	_comptage_prevu = true
	(func() -> void:
		_comptage_prevu = false
		_rafraichir_couches()).call_deferred()


## L'union, relue pour ces cases (la couche visible qui la porte — une seule, puisqu'elles sont exclusives), puis
## chaque couche autour d'elles.
## `sur` : `cases_` est tout ce qui a changé depuis le dernier passage (un coup de pinceau) — `MassifPeint.reconstruire_autour`
## saute sa garde de compte.
func _suivre_les_cases(cases_: Array, sur := false) -> void:
	for c in cases_:
		_union.erase(c)
		for i in _vue.nombre_de_couches():
			var m := _vue.couche(i) as Node3D
			if m.visible and (m.get_node("Cases") as GridMap).get_cell_item(c) != GridMap.INVALID_CELL_ITEM:
				_union[c] = i
				break
	_transitions.cases_changees(cases_)
	for i in _vue.nombre_de_couches():
		var m: Node = _vue.couche(i)
		# ⚠ UNE COUCHE CACHÉE N'EST PAS REFAITE (on ne la voit pas) : ces cases l'attendent, elle s'en refera en
		# reparaissant (`_montrer_couche`).
		if not (m as Node3D).visible:
			var attente: Dictionary = m.get_meta("_a_refaire", {})
			for c in cases_:
				attente[c] = true
			m.set_meta("_a_refaire", attente)
			continue
		m.reconstruire_autour(cases_, sur)


## L'union entière et le rang de chaque couche — quand une couche apparaît, disparaît, se cache, se montre, ou à
## l'ouverture. ⚠ LE DICTIONNAIRE EST VIDÉ ET REMPLI, JAMAIS REMPLACÉ : chaque couche en garde la référence.
func _refaire_l_union() -> void:
	_union.clear()
	_transitions.union_refaite()
	for i in range(_vue.nombre_de_couches() - 1, -1, -1):
		var m := _vue.couche(i)
		m.union = _union
		m.monde = _le_monde_du_coeur()
		m.rang = i
		if (m as Node3D).visible:
			for c in (m.get_node("Cases") as GridMap).get_used_cells():
				_union[c] = i
	for i in _vue.nombre_de_couches():
		var m: Node = _vue.couche(i)
		m.remove_meta("_a_refaire")
		# Une couche cachée n'est pas refaite (l'union ne porte pas ses cases) : elle le sera EN ENTIER en reparaissant.
		if not (m as Node3D).visible:
			m.set_meta("_tout_refaire", true)
			continue
		m.remove_meta("_tout_refaire")
		m.reconstruire()


## UN PROJET D'AVANT (2 octobre 2026) peut porter une case dans plusieurs couches : la plus haute la garde. Rend
## combien de cases ont été retirées.
func _rendre_exclusives() -> int:
	var prises := {}
	var retirees := 0
	for i in _vue.nombre_de_couches():
		var g := _vue.couche(i).get_node("Cases") as GridMap
		for c in g.get_used_cells():
			if prises.has(c):
				g.set_cell_item(c, GridMap.INVALID_CELL_ITEM)
				retirees += 1
			else:
				prises[c] = i
	return retirees


func _reconstruire(_massif: Node, touchees: Array) -> void:
	# EN COUCHES : l'union suit ces cases, et CHAQUE couche se refait autour d'elles — une case de la roche change
	# aussi les sommets de frontière de la glace.
	_suivre_les_cases(touchees)
	_compter_les_cases_plus_tard()
	_vue.rafraichir()
	_dire_l_etage()
	_noter_pour_l_eau(touchees)
	_eau_perimee()   # la coulée suit le monde, dans les deux sens de l'historique


## ⚠ L'ÉTAT TENU PAR LA COUCHE (`MassifPeint.cases_tenues`), À LIRE SEULEMENT — sur l'exemple, le rebâtir coûtait
## ~150 ms à chaque opération de sélection (4 octobre 2026). Une opération qui le garde ou le passe à un autre fil le
## copie (`_reparer_les_diagonales`).
func _occupees() -> Dictionary:
	return _vue._occupees_actives()


## Remplace toutes les cases de la couche, en UNE action annulable.
func _remplacer_le_monde(nouvelles: Dictionary, nom: String) -> void:
	var effacer := {}
	for c in _occupees():
		if not nouvelles.has(c):
			effacer[c] = true
	_appliquer({"poser": nouvelles, "effacer": effacer}, nom)


var _boutons_diagonales: Array = []


## Répare les contacts diagonaux du monde VISIBLE (`FS.reparer_les_diagonales`) : on pose dans la couche active, on ne
## creuse que ses cases, on ne remplit jamais une case d'une couche cachée. UNE action.
func _reparer_les_diagonales(creuse: bool) -> void:
	if not (_vue.monde() as Node3D).visible:
		_dire("[i]The active layer is hidden.[/i] Show it first: the fix adds or removes ITS cells.")
		return
	var pleines := _union.duplicate()
	var modifiables := _occupees().duplicate()   # ⚠ lue sur un autre fil : pas l'état vivant de la couche
	var figees := {}
	for i in _vue.nombre_de_couches():
		var m := _vue.couche(i) as Node3D
		if not m.visible:
			for c in (m.get_node("Cases") as GridMap).get_used_cells():
				figees[c] = true
	await _attendre("Fixing diagonal contacts", "%d cells" % pleines.size())
	var r: Dictionary = await _en_fond(func() -> Dictionary:
		return FS.reparer_les_diagonales(pleines, creuse, modifiables, figees))
	_fin_attente()
	var poses: int = (r["poser"] as Dictionary).size()
	var creusees: int = (r["effacer"] as Dictionary).size()
	if poses + creusees == 0:
		_dire("[b]No diagonal contact to fix[/b]%s" % ("." if int(r["restantes"]) == 0 else
			(" — %d remain that only touch hidden layers' cells: show them, or fix them by hand." % int(r["restantes"]))))
		return
	_appliquer({"poser": r["poser"], "effacer": r["effacer"]}, "Fix diagonal contacts")
	_dire(("[b]Diagonal contacts fixed[/b] — %d cell(s) added, %d removed, in « %s ». [i]Ctrl+Z undoes it.[/i]%s")
		% [poses, creusees, _couches[_active]["nom"], "" if int(r["restantes"]) == 0 else
		"\n[color=#f2ca79]%d contact(s) remain[/color]: they involve a hidden layer's cells." % int(r["restantes"])])


func _effacer_tout() -> void:
	_remplacer_le_monde({}, "Clear the layer")


## ⚠ PLUS DE BOUTON (Jordan, 2 octobre 2026 : « paint the witness shape est nul, il faut le retirer ») : la fonction
## reste pour les captures de `DEV_TOOLS/`, qui peignent la forme du témoin pour la photographier.
func _peindre_la_forme_du_temoin() -> void:
	_remplacer_le_monde(BM.cases(0), "Paint the witness shape")
	_aller_a("monde")


## LES OPÉRATIONS D'ÉTAGE — la règle vit dans `etages.gd`, partagée avec le greffon. Elles portent sur
## la SÉLECTION s'il y en a une, sinon sur l'étage : la même opération, sur un autre ensemble.
func _operer(quoi: String) -> void:
	var sur: String = ("the selection (%d cells)" % _vue.selection.size()) if not _vue.selection.is_empty() \
		else "floor y = %d" % _vue.etage
	var op: Dictionary = Etages.operer(_occupees(), _vue.etage, quoi, _vue.selection)
	var nom: String = NOMS_OPERATIONS.get(quoi, quoi)
	var n := _appliquer(op, nom)
	if n == 0:
		_dire("[i]Nothing to do on %s.[/i] It is empty, or the operation found nothing to change." % sur)
		return
	_dire("[b]%s[/b] on %s — %d cell(s) changed. [i]Ctrl+Z undoes it.[/i]" % [nom, sur, n])


## LES NOMS À L'ÉCRAN des opérations (le rapport et « Undone: … ») — elles étaient dites par leur nom de code,
## en français (« elargir », « retrecir_bord »…), vu par un audit le 3 octobre 2026.
const NOMS_OPERATIONS := {"elargir": "Widen", "creuser": "Hollow", "evider": "Hollow", "remplir": "Fill",
	"supprimer": "Delete", "grandir": "Grow", "retrecir_bord": "Shrink", "retrecir": "Shrink", "connexe": "Connected"}


## Un clic sur Extrude up / down / facing : Maj étend la sélection, Alt la décale (Jordan, 2 octobre 2026).
func _extruder_au_clic(quoi: String) -> void:
	var mode := "poser"
	if Input.is_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_SHIFT):
		mode = "etendre"
	elif Input.is_key_pressed(KEY_ALT) or Input.is_physical_key_pressed(KEY_ALT):
		mode = "decaler"
	_extruder(quoi, mode)


## EXTRUDE (`Etages.extruder`) : pose ou non, la sélection suit (étendue, décalée), l'étage suit le sens vertical.
func _extruder(quoi: String, mode := "poser") -> void:
	var avait_une_selection := not _vue.selection.is_empty()
	var sur: String = ("the selection (%d cells)" % _vue.selection.size()) if avait_une_selection 		else "floor y = %d" % _vue.etage
	var op: Dictionary = Etages.extruder(_occupees(), _vue.etage, quoi, _vue.selection, mode)
	var sens: Vector3i = op["sens"]
	if sens == Vector3i.ZERO:
		_dire("[i]Nothing to extrude on %s.[/i] %s" % [sur, "No cell has matter behind it and air in front."
			if quoi == "face" else "It holds no matter."])
		return
	var n := 0
	if mode == "poser":
		n = _appliquer(op, "Extrude %s" % _nom_du_sens(sens))
	if mode != "poser" or avait_une_selection:
		_vue.regler_selection(op["selection"])
	if sens.y != 0:
		_compteur_etage.value = _vue.etage + sens.y
	match mode:
		"etendre":
			_dire("[b]Selection extended[/b] %s — %d cell(s) selected. [i]No matter added.[/i]"
				% [_nom_du_sens(sens), _vue.selection.size()])
		"decaler":
			_dire("[b]Selection moved[/b] %s — %d cell(s). [i]No matter added.[/i]"
				% [_nom_du_sens(sens), _vue.selection.size()])
		_:
			_dire(("[b]Extrude[/b] %s on %s — %d cell(s) added. [i]Click again to keep going; Shift+click extends "
				+ "the selection, Alt+click moves it; Ctrl+Z undoes the cells.[/i]") % [_nom_du_sens(sens), sur, n])


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
	var nom: String = NOMS_OPERATIONS.get(quoi, quoi)
	var n := _appliquer(op, nom)
	_vue.regler_selection(op["selection"])
	# (Extrude ↑ ↓ et l'étage qui le suit vivent désormais dans `_extruder`, Shape operations.)
	_dire("[b]%s[/b] — %d cell(s) changed, %d selected. [i]Ctrl+Z undoes the cells.[/i]"
		% [nom, n, _vue.selection.size()])


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
	await _rhabiller_avec_attente()
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
	await _rhabiller_avec_attente()
	var couches: Array = []
	for i in _couches.size():
		var massif: Node = _vue.couche(i)
		couches.append({"nom": _couches[i]["nom"], "visible": _couches[i]["visible"],
			"source": _couches[i]["source"], "lot": massif.lot,
			"cases": (massif.get_node("Cases") as GridMap).get_used_cells(), "poids": massif.poids, "choix": massif.choix})
	await _attendre("Exporting the world", "%d layer(s)" % couches.size())
	var version := "MarchingBlocks %s" % ProjectSettings.get_setting("application/config/version", "")
	var nom: String = _projet.get_file().get_basename() if _projet != "" else "world"
	# L'EAU PART CUITE : la nappe de chaque couche d'eau, telle que la vue la montre, avec ses sources.
	_recalculer_eau(false)
	var eaux: Array = []
	var nappes: Array = _vue.nappes()
	for i in _eaux.size():
		eaux.append({"nom": _eaux[i]["nom"], "visible": _eaux[i]["visible"], "preset": _eaux[i]["preset"],
			"sources": _eaux[i]["sources"], "maillage": (nappes[i] as MeshInstance3D).mesh if i < nappes.size() else null})
	var r: Dictionary = FormatMonde.exporter(couches, dossier, nom, version, eaux)
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
	if int(r.get("eaux", 0)) > 0:
		texte += ("
%d water layer(s), baked with their flow, kind and depth (%d mesh(es)). The plugins do not "
			+ "show water yet.") % [r["eaux"], r["nappes"]]
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
## `colonnes` > 0 : en GRILLE de tant de colonnes — six formes spéciales en une rangée élargissaient toute la barre
## de droite, qui débordait de l'écran (vu à l'image).
func _rangee_de_choix(boutons: Dictionary, choix: Array, action: Callable, variante := "", colonnes := 0) -> Control:
	var ligne: Container
	if colonnes > 0:
		var grille := GridContainer.new()
		grille.columns = colonnes
		grille.add_theme_constant_override("h_separation", 5)
		grille.add_theme_constant_override("v_separation", 5)
		ligne = grille
	else:
		var rangee := HBoxContainer.new()
		rangee.add_theme_constant_override("separation", 5)
		ligne = rangee
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


## DANS LES PANNEAUX, LA MOLETTE SEULE NE FAIT QUE DÉFILER — DÉCIDÉ (Jordan, 3 octobre 2026 : « les ScrollContainer
## défilent si on est dessus et qu'on molette simple, et uniquement eux »). MESURÉ (sonde, Godot 4.7) : un curseur
## (`Slider`) survolé changeait de valeur ET laissait défiler — en descendant la barre, on déréglait ce qui passait sous
## la souris ; un compteur (`SpinBox`) qui a le focus (on vient d'y taper) prenait le cran et bloquait le défilement.
## Le curseur perd sa molette (`scrollable`) ; le compteur lâche le focus au premier cran, qui part alors au défilement.
func _sans_molette(n: Node) -> void:
	if n is Slider:
		(n as Slider).scrollable = false
	elif n is SpinBox and not n.has_meta("mb_sans_molette"):
		var sb := n as SpinBox
		sb.set_meta("mb_sans_molette", true)
		sb.gui_input.connect(func(e: InputEvent) -> void:
			var m := e as InputEventMouseButton
			if m != null and m.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				sb.get_line_edit().release_focus())


func _sans_molette_partout(n: Node) -> void:
	_sans_molette(n)
	for c in n.get_children():
		_sans_molette_partout(c)


## LA MOLETTE DU CONTEXTE — DÉCIDÉ (Jordan, 3 octobre 2026), une seule règle partout :
##   - la molette SEULE reste le zoom, sauf PENDANT UN GESTE, dont elle règle la dimension (la hauteur d'un glissé de
##     Rect ou de boîte, les étages d'une salle qu'on trace, la hauteur d'un collage) ;
##   - ALT + molette : la grandeur PRINCIPALE de l'outil actif ; MAJ + molette : sa grandeur SECONDE ;
##   - CTRL + molette : l'étage de la grille (PgUp / PgDn), là où il y a une grille.
## Avec une SÉLECTION et un outil de sélection (Select, Rect, Box), la molette FAÇONNE la sélection : Maj l'étend en
## hauteur (Extend selection ↑ ↓, cases vides comprises, rien n'est posé), Alt l'élargit d'une couronne à plat (cases
## vides comprises) ou retire son bord (Shrink).
## Chaque cran est dit près de la souris (`Vue.montrer_valeur`). Rend vrai si le cran est pris (sinon : zoom).
func _molette(sens: int, b: InputEventMouseButton) -> bool:
	var alt := b.alt_pressed
	var maj := b.shift_pressed
	var ctrl := b.ctrl_pressed or b.meta_pressed
	if _atelier in ["monde", "fluides"]:
		return _molette_du_monde(sens, alt, maj, ctrl)
	if _atelier == "transitions" and alt and not ctrl and not _vue.naviguer:
		return _cran(_transitions.curseur_rayon, sens, "Brush radius")
	if _atelier == "feuillage" and not _vue.naviguer:
		if ctrl:
			return _cran(_compteur_etage, sens, "Floor")
		return _feuillage.molette(sens, alt, maj)
	if _atelier in ["witness", "texture"] and _vue.edition and (alt or maj) and not ctrl:
		if _modeleur.sculpt and _atelier == "witness":
			return _cran(_curseurs_sculpt.get("sculpt_rayon" if alt else "sculpt_force"), sens,
				"Sculpt radius" if alt else "Sculpt strength", 1.15 if alt else 0.0)
		if _modeleur.pinceau and _atelier == "texture":
			return _cran(_curseurs_pinceau.get("pinceau_taille" if alt else "pinceau_durete"), sens,
				"Brush size" if alt else "Brush hardness", 1.15 if alt else 0.0)
	return false


func _molette_du_monde(sens: int, alt: bool, maj: bool, ctrl: bool) -> bool:
	if _vue.naviguer:
		return false
	var outil: String = _vue.outil
	# Pendant un geste : la molette seule. Choisir la hauteur de la mer en est un.
	if not (alt or maj or ctrl):
		if outil == "eau" and _mer_choisie != null:
			_hausser_la_mer(sens)
			return true
		if not _vue.collage.is_empty():
			_vue.montrer_valeur("Paste height %+d" % _vue.hausser_le_collage(sens))
			return true
		match _vue.glisse_en_cours():
			"boite", "rect":
				var h: int = _vue.hausser_le_glisse(sens)
				_vue.montrer_valeur("Height %+d" % h if h != 0 else "Flat")
				return true
			"salle":
				return _cran(_etages_forme, sens, "Floors")
		return false
	if ctrl and maj and outil == "forme" and _vue.forme_speciale["quoi"] == "escalier":
		return _cran(_pas_forme, sens, "Step")
	if ctrl:
		return _cran(_compteur_etage, sens, "Floor")
	if outil == "eau":
		return _cran(_largeur_eau, sens, "River width") if alt else false
	if outil == "forme":
		if _vue.forme_speciale["quoi"] == "salle":
			if alt:
				return _cran(_etages_forme, sens, "Floors")
			_regler_le_sens_de_salle("haut" if sens > 0 else "bas")
			_vue.montrer_valeur("Rises" if sens > 0 else "Sinks")
			return true
		if alt:
			return _cran(_taille_forme, sens, "Size")
		if _ligne_longueur.visible:
			return _cran(_longueur_forme, sens, _etiquette_longueur.text)
		return true
	if not _vue.selection.is_empty() and outil in ["selectionner", "rect", "boite"]:
		var avant: int = _vue.selection.size()
		if maj:
			_extruder("haut" if sens > 0 else "bas", "etendre")
		elif sens > 0:
			# ÉLARGIR D'UNE COURONNE, À PLAT, CASES VIDES COMPRISES — comme « Extend selection », rien n'est posé. ⚠ PAS
			# « Grow », qui ne garde que la matière : une sélection de volume (un Rect dans l'air) disparaissait.
			var large := {}
			for c: Vector3i in _vue.selection:
				large[c] = true
				for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
					large[c + d] = true
			_vue.regler_selection(large)
		else:
			_vue.regler_selection(Outils.operer_selection(_occupees(), _vue.selection, "retrecir_bord")["selection"])
		_vue.montrer_valeur("%s — %d cells" % [("Extend ↑" if sens > 0 else "Extend ↓") if maj
			else ("Widen" if sens > 0 else "Shrink"), _vue.selection.size()] if _vue.selection.size() != avant
			else "Selection unchanged")
		return true
	if outil in ["ajouter", "creuser", "selectionner"]:
		if alt:
			return _cran(_taille, sens, "Brush size")
		var formes: Array = _boutons_forme.keys()
		var f: String = formes[posmod(formes.find(_vue.forme) + sens, formes.size())]
		_choisir_forme(f)
		_vue.montrer_valeur((_boutons_forme[f] as Button).text)
		return true
	return false


## F (Jordan, 3 octobre 2026 : « pour recentrer le monde sur voir toute la matière », « c'était F ») : la vue cadre toute
## la matière des couches visibles, dans World et Fluids. ⚠ F est le vol au Play test, et Fill dans Geometry : ailleurs.
func _cadrer_tout_le_monde() -> void:
	if not _vue.cadrer_toute_la_matiere():
		_dire("[i]Nothing to frame:[/i] the visible layers hold no cell.")


## ² (Jordan, 4 octobre 2026) : la vue saute sur la matière sous la souris, l'œil à une distance raisonnable (`Vue.
## teleporter_vers`), dans World et Fluids. Lue par sa PLACE (`physical_keycode`, la touche sous Échap) : ² sur un
## AZERTY, ` sur un QWERTY.
func _teleporter() -> void:
	if not _vue.teleporter_vers(_vue.get_local_mouse_position()):
		_dire("[i]²: no matter under the cursor — the view stays where it is.[/i]")


## Un cran de molette sur un réglage (`Range` : curseur ou compteur) : son pas s'il est entier, un vingtième de sa
## course s'il est continu — ou, avec `facteur`, la valeur MULTIPLIÉE (une taille de pinceau, de 1 à 200 pixels : un
## pixel par cran serait trop lent, comme le rayon du cercle C). La valeur est dite près de la souris ; le réglage fait
## le reste (son signal, comme à la main).
func _cran(r: Range, sens: int, nom: String, facteur := 0.0) -> bool:
	if r == null:
		return false
	if facteur > 0.0:
		r.value = clampf(r.value * pow(facteur, sens), r.min_value, r.max_value)
	else:
		var pas: float = r.step if r.step >= 1.0 else (r.max_value - r.min_value) / 20.0
		r.value = clampf(r.value + sens * pas, r.min_value, r.max_value)
	_vue.montrer_valeur("%s %s" % [nom, str(int(r.value)) if r.step >= 1.0 else "%.2f" % r.value])
	return true


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
	_variantes.outil_change()
	for b in _boutons_forme_speciale.values():
		(b as Button).set_pressed_no_signal(false)
	_vue.oublier_ancre()
	_contexte_des_outils()
	_vue.rafraichir()


func _choisir_forme_speciale(quoi: String) -> void:
	_vue.outil = "forme"
	_vue.forme_speciale["quoi"] = quoi
	_vue.oublier_ancre()
	for b in _boutons_outil.values():
		(b as Button).set_pressed_no_signal(false)
	(_boutons_forme_speciale[quoi] as Button).button_pressed = true
	_variantes.outil_change()
	_basculer_navigation(false)
	_contexte_des_outils()
	_vue.rafraichir()


func _choisir_les_bouts(v: String) -> void:
	_vue.forme_speciale["relier"] = v == "relier"
	(_boutons_bouts[v] as Button).button_pressed = true
	_vue.oublier_ancre()
	_contexte_des_outils()
	_vue.rafraichir()


func _choisir_le_profil(v: String) -> void:
	_vue.forme_speciale["profil"] = v
	(_boutons_profil[v] as Button).button_pressed = true
	_vue.rafraichir()


const NOMS_DE_FORME := {"tunnel": "Tunnel", "puits": "Well", "pont": "Bridge", "balcon": "Balcony",
	"escalier": "Stairs", "salle": "Room"}


## Une forme posée : UNE action, donc UN Ctrl+Z, par la seule entrée de tout ce qui change des cases.
## Le sens de la salle (Up / Down), partagé par la forme Room et « Room from selection ».
func _regler_le_sens_de_salle(v: String) -> void:
	_vue.forme_speciale["vers_le_haut"] = v == "haut"
	for rangee in [_boutons_sens_salle, _sens_selection]:
		if (rangee as Dictionary).has(v):
			(rangee[v] as Button).set_pressed_no_signal(true)
			for autre in rangee:
				if autre != v:
					(rangee[autre] as Button).set_pressed_no_signal(false)
	_contexte_des_outils()   # l'aide dit « rises » ou « sinks »
	_vue.rafraichir()


## « Room from selection » : `FS.salle_depuis`, posée comme une forme (une annulation, les réparations dites).
func _salle_de_la_selection() -> void:
	var r: Dictionary = FS.salle_depuis(_occupees(), _vue.selection, int(_vue.forme_speciale["etages"]),
		bool(_vue.forme_speciale["vers_le_haut"]))
	match r["erreur"]:
		"vide":
			_dire("[i]Nothing selected.[/i] Paint the footprint first: Select brush, « Select empty cells too ».")
			return
		"trop_petit":
			_dire("[color=#e0603c]Room from selection[/color] — the footprint is too thin: a room needs at least one "
				+ "cell whose four neighbours are in the selection.")
			return
		"trop_grand":
			_dire("[color=#e0603c]Room from selection[/color] — too large (more than %d cells)." % Outils.VOLUME_MAXI)
			return
	_forme_posee({"poser": r["poser"], "effacer": r["effacer"]}, "salle", r)


func _forme_posee(modif: Dictionary, quoi: String, info: Dictionary) -> void:
	var nom: String = NOMS_DE_FORME.get(quoi, quoi)
	var n := _appliquer(modif, nom)
	if n == 0:
		_dire("[i]%s: nothing to change here.[/i]" % nom)
		return
	var fin := ""
	if quoi in ["tunnel", "puits"] and not bool(_vue.forme_speciale["relier"]):
		fin = " It opens into the cave behind." if info.get("ouvert", false) \
			else " It found no cave within %d cells: a dead end." % int(_vue.forme_speciale["longueur"])
	var reparees: int = info.get("reparees", 0)
	if reparees > 0:
		fin += " %d more cell(s) so that no two cells touch by an edge only." % reparees
	_dire("[b]%s[/b] — %d cell(s) changed.%s [i]Ctrl+Z undoes it.[/i]" % [nom, n, fin])


func _forme_dite(code: String, info: Dictionary) -> void:
	var quoi: String = _vue.forme_speciale["quoi"]
	var nom: String = NOMS_DE_FORME.get(quoi, "")
	var surface: String = {"puits": "floor or ceiling", "escalier": "floor"}.get(quoi, "wall")
	match code:
		"ancre":
			var n: Vector3i = info["normale"]
			_dire("[b]%s[/b] — first end set%s. Now click the second %s. [i]Right click or Esc forgets it.[/i]"
				% [nom, " (a slanted wall: the shape leaves it at 45°)" if n.x != 0 and n.z != 0 else "", surface])
		"ancre_oubliee":
			_dire("[i]First end forgotten.[/i]")
		"pas_de_paroi":
			_dire("[color=#e0603c]%s[/color] — click a WALL, a side face of the matter." % nom)
		"pas_un_sol":
			_dire("[color=#e0603c]Well[/color] — click a FLOOR or a CEILING, a top or bottom face.")
		"pas_un_dessus":
			_dire("[color=#e0603c]Stairs[/color] — in Connect, click two FLOORS, the top face of the matter.")
		"trop_raide":
			_dire("[color=#e0603c]Stairs[/color] — too steep: one cell up for each cell across at most. "
				+ "Pick two floors further apart.")
		"meme_case":
			_dire("[color=#e0603c]%s[/color] — the second end must be another cell." % nom)
		"trop_long":
			_dire("[color=#e0603c]%s[/color] — the two ends are more than %d cells apart." % [nom, FS.ECART_MAXI])
		"rien_en_face":
			_dire("[color=#e0603c]Bridge[/color] — no wall within %d cells in front. Raise Reach, or Connect two walls."
				% int(_vue.forme_speciale["longueur"]))
		"trop_grand":
			_dire("[color=#e0603c]%s[/color] — too large. Make it smaller or shorter." % nom)
		"trop_petit":
			_dire("[color=#e0603c]Room[/color] — draw at least 3 × 3 cells: the walls need an inside between them.")
		_:
			_dire("[color=#e0603c]%s[/color] — %s" % [nom, code])


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


## CTRL+CLIC : la grille passe à l'étage de la case de matière touchée, et on le DIT — l'étage change
## hors de la vue de celui qui regarde la barre.
func _etage_sur_la_matiere(c: Variant) -> void:
	if c == null:
		_dire("[i]Ctrl+click: no matter under the cursor — floor unchanged (y = %d).[/i]" % _vue.etage)
		return
	var y: int = (c as Vector3i).y
	if y < int(_compteur_etage.min_value) or y > int(_compteur_etage.max_value):
		_dire("[color=#e0603c]Floor y = %d is out of range[/color] (%d to %d) — floor unchanged." \
			% [y, int(_compteur_etage.min_value), int(_compteur_etage.max_value)])
		return
	_compteur_etage.value = y
	_dire("[b]Grid moved to floor y = %d[/b] — the height of the matter you Ctrl+clicked." % y)


func _dire_l_etage() -> void:
	if _etiquette_etage == null or _vue == null or _vue.cases() == null:
		return
	var combien := 0
	var bas := 1 << 20
	var haut := -(1 << 20)
	# ⚠ LE COMPTE PAR ÉTAGE TENU PAR LA COUCHE (4 octobre 2026) : parcourir ses cases coûtait ~75 ms après chaque geste
	# sur l'exemple. La grille n'est relue que si la couche ne peut pas le garantir.
	var par_etage = _vue.monde().cases_par_etage()
	if par_etage != null:
		combien = int((par_etage as Dictionary).get(_vue.etage, 0))
		for y in par_etage:
			bas = mini(bas, y)
			haut = maxi(haut, y)
	else:
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
	# Les variantes de son monde (4 octobre 2026) : le peintre les tient, l'enregistrement les relit.
	massif.poids = (etat.get("poids", {}) as Dictionary).duplicate(true)
	massif.choix = (etat.get("choix", {}) as Dictionary).duplicate()
	# La dernière de la liste : la moins prioritaire. Vide, elle ne change rien à l'union.
	massif.union = _union
	massif.monde = _le_monde_du_coeur()
	massif.rang = _couches.size() - 1
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
	_variantes.dire_poids()
	_suivre_le_temoin_de_la_couche()
	_rafraichir_couches()
	_dire_l_etage()
	_enregistrer_plus_tard()


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
			_donner_les_autres_temoins()
			_modeleur.charger_temoin(t, _occurrence_de_depart(t))
			_redire_les_materiaux()
	_legende_formes.reconstruire_tuiles()


func _nouvelle_couche() -> void:
	_activer(_ajouter_couche(Projet.couche("Layer %d" % (_couches.size() + 1))))
	# ⚠ ON RESTE OÙ L'ON EST (3 octobre 2026) : créée depuis Witness pour en sculpter le témoin, ou depuis Fluids, la
	# couche renvoyait dans World. Seuls Project et Play test, qui ne montrent pas les couches, mènent à World.
	if not _atelier in ["monde", "witness", "texture", "fluides"]:
		_aller_a("monde")
	_dire("[b]New layer[/b] — empty and active: paint its cells in World, sculpt its witness in Witness.\n"
		+ "[i]Slice the witness or your work into it to give it tiles.[/i]")


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
	_refaire_l_union()   # les rangs ont glissé
	_activer(mini(i, _couches.size() - 1))
	_eau_cases_inconnues = true
	_eau_perimee()


func _rattacher_couche(massif: Node, etat: Dictionary, i: int) -> void:
	_detachees.erase(massif)
	_vue.inserer_couche(massif, i)
	_couches.insert(i, etat)
	_refaire_l_union()
	_activer(i)
	_eau_cases_inconnues = true
	_eau_perimee()


## ↑ ↓ (Jordan, 2 octobre 2026) : la couche active change de place d'un cran — UNE action, un Ctrl+Z. Ses cases
## et son témoin ne bougent pas ; seule la priorité change, donc les coins des frontières.
func _deplacer_couche(sens: int) -> void:
	var de := _active
	var vers := de + sens
	if vers < 0 or vers >= _couches.size():
		return
	_histoire.create_action("Move layer « %s » %s" % [_couches[de]["nom"], "up" if sens < 0 else "down"])
	_histoire.add_do_method(_echanger_couches.bind(de, vers))
	_histoire.add_undo_method(_echanger_couches.bind(vers, de))
	_histoire.commit_action()


func _echanger_couches(de: int, vers: int) -> void:
	var au_monde := _toutes_au_monde(de, vers)
	if au_monde:
		_monde_coeur.deplacer_couche(de, vers)   # chaque inscrit suit sa couche ; le diff : les frontières seules
	_vue.deplacer_couche(de, vers)
	var etat: Dictionary = _couches[de]
	_couches.remove_at(de)
	_couches.insert(vers, etat)
	if au_monde:
		_renumeroter_l_union(mini(de, vers), maxi(de, vers))
	else:
		_refaire_l_union()   # les rangs ont changé : les sommets des frontières changent de propriétaire
	_activer(vers)


## UP / DOWN BRANCHÉ (Jordan, 6 octobre 2026 : « Up/Down est lent, optimise-le ») : refaire l'union reconstruisait
## chaque couche — le monde refaisait TOUT (`assign`), puis deux couches se remplissaient : 854 ms sur 120 821 cases.
## Or seul l'ordre change : le monde déplace la couche (`World::move_layer` ne redécide que les sommets où elle touche
## une couche qu'elle passe), ses inscrits la suivent, et ici l'union ne renumérote que les couches entre les deux rangs.
## Seulement si chaque couche VISIBLE est inscrite au monde à son rang — une couche cachée peut ne l'être pas encore
## (cachée dès l'ouverture : elle s'inscrira en reparaissant) —, sinon la route d'avant, qui reconstruit.
func _toutes_au_monde(de: int, vers: int) -> bool:
	if _monde_coeur == null or MB.natif() == null:
		return false
	var n: int = _monde_coeur.nombre_de_couches()
	if n > _vue.nombre_de_couches() or maxi(de, vers) >= n:
		return false
	for i in _vue.nombre_de_couches():
		var m: Node = _vue.couche(i)
		if m.monde != _monde_coeur or m.rang != i:
			return false
		var qui: int = _monde_coeur.proprio(i)
		if qui != m.get_instance_id() and not (qui == 0 and not (m as Node3D).visible):
			return false
	return true


var glissements_au_monde := 0   # les Up / Down passés par cette route (`fumee_appli` exige qu'elle serve)


func _renumeroter_l_union(lo: int, hi: int) -> void:
	glissements_au_monde += 1
	for i in range(lo, hi + 1):
		var m: Node = _vue.couche(i)
		m.rang = i
		# Une couche cachée n'est pas dans l'union (ni dans le monde) : elle dort, et se réveillera à son nouveau rang.
		if (m as Node3D).visible:
			for c in (m.get_node("Cases") as GridMap).get_used_cells():
				_union[c] = i
	_monde_coeur.vider_attente()
	for i in _vue.nombre_de_couches():
		_vue.couche(i)._bilan()


func _renommer_couche() -> void:
	var nom := _nom_couche.text.strip_edges()
	if _couches.is_empty() or nom == "" or nom == _couches[_active]["nom"]:
		return
	_couches[_active]["nom"] = nom
	_rafraichir_couches()
	_enregistrer_plus_tard()


## ⚠ PLUS DE RECONSTRUCTION COMPLÈTE (2 octobre 2026 : 4,5 s pour cacher une couche de l'exemple) : l'union ne change
## qu'aux cases de cette couche (exclusives : elle seule les porte), donc les AUTRES couches ne se refont qu'autour
## d'elles ; la couche cachée garde son état, et en reparaissant ne se refait qu'autour de ce qui a changé pendant
## qu'elle était cachée (`_suivre_les_cases`).
func _montrer_couche(i: int, oui: bool) -> void:
	_couches[i]["visible"] = oui
	var m: Node = _vue.couche(i)
	(m as Node3D).visible = oui
	var siennes: Array = (m.get_node("Cases") as GridMap).get_used_cells()
	for c in siennes:
		if oui:
			_union[c] = i
		elif _union.get(c, -1) == i:
			_union.erase(c)
	for j in _vue.nombre_de_couches():
		if j == i:
			continue
		if (_vue.couche(j) as Node3D).visible:
			_vue.couche(j).reconstruire_autour(siennes)
		else:
			# ⚠ UNE AUTRE COUCHE CACHÉE DOIT L'APPRENDRE AUSSI (6 octobre 2026, trouvé par `test_natif` §11) : ses sommets
			# de frontière lisent l'union, qui change ici. Sans ça, montrée plus tard, elle se refaisait autour de ses
			# seules attentes et gardait une tuile périmée (une variante d'air libre au lieu de l'intérieur).
			var attente_j: Dictionary = _vue.couche(j).get_meta("_a_refaire", {})
			for c in siennes:
				attente_j[c] = true
			_vue.couche(j).set_meta("_a_refaire", attente_j)
	if oui:
		var attente: Dictionary = m.get_meta("_a_refaire", {})
		m.remove_meta("_a_refaire")
		if m.get_meta("_tout_refaire", false):
			m.remove_meta("_tout_refaire")
			m.reconstruire()
		else:
			m.reconstruire_autour(attente.keys())
	_enregistrer_plus_tard()


## Une ligne par couche : l'œil (montrer / cacher), puis la couche elle-même, qu'on choisit d'un clic.
## La couche ACTIVE se voit à son fond olive — c'est elle que le pinceau touche.
func _rafraichir_couches() -> void:
	if _liste_couches == null:
		return
	_transitions.dire()   # une couche ajoutée, renommée, déplacée : les paires suivent
	# ⚠ Un projet garde au moins une couche : le bouton se grise au lieu de refuser après le clic.
	_bouton_supprimer_couche.disabled = _couches.size() <= 1
	if _bouton_monter_couche != null:
		_bouton_monter_couche.disabled = _active <= 0
		_bouton_descendre_couche.disabled = _active >= _couches.size() - 1
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
	for e in _etiquettes_temoin_couche:
		if _couches.is_empty():
			break
		e.text = "Witness of layer « %s » — %s" % [_couches[_active]["nom"],
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

## ÉDITER L'EXEMPLE PENDANT LE DÉVELOPPEMENT (Jordan, 3 octobre 2026) — `DEV_TOOLS/dev_exemple.gd`, exclu de l'export,
## chargé seulement sans modèle d'export ET avec `--dev-example` (`DEV_TOOLS/editer_l_exemple.cmd`). Les tests ne le
## voient jamais.
var _dev: RefCounted = null


func _brancher_le_dev() -> void:
	const CHEMIN := "res://DEV_TOOLS/dev_exemple.gd"
	if OS.has_feature("template") or not ResourceLoader.exists(CHEMIN):
		return
	var D: GDScript = load(CHEMIN)
	if not D.demande():
		return
	_dev = D.new(self)
	dev_suivre_la_source()


func dev_suivre_la_source() -> void:
	source_dev_exemple = ProjectSettings.globalize_path(_dev.source()).replace("\\", "/")
	_dire_le_projet()


func dev_projet_ouvert() -> String:
	return _projet


func dev_dire(texte: String) -> void:
	_dire(texte)


func dev_tout_ecrire() -> void:
	_toujours_ecrire()
	_attendre_l_ecriture()


func dev_ouvrir_la_source() -> void:
	if not FileAccess.file_exists(_dev.source()):
		_dire("[color=#e0603c]The example source does not exist:[/color] " + _dev.source())
		return
	await _ouvrir(_dev.source())


## ⚠ UN PROJET QUI NE S'OUVRE PAS N'EST JAMAIS ÉCRASÉ : on en commence un autre, à côté. L'enregistrement
## automatique réécrirait sinon, au premier coup de pinceau, le seul exemplaire d'un monde abîmé.
func _ouvrir_au_lancement() -> void:
	# ⚠ UN DOUBLE-CLIC SUR UN .mbproj LANCE L'APPLI AVEC SON CHEMIN (`Associations`) : il l'emporte sur le dernier
	# projet ouvert.
	# `--open-example` : l'exemple livré, directement (une démo, et l'épreuve de l'exe sans clic).
	if OS.get_cmdline_args().has("--open-example") or OS.get_cmdline_user_args().has("--open-example"):
		var erreurs: Array = []
		var exemple := Exemple.installer(Exemple.ARCHIVE, racine_exemple, erreurs)
		if exemple != "" and await _ouvrir(exemple):
			return
	var passe: String = Associations.projet_en_argument(OS.get_cmdline_args())
	if passe != "" and await _ouvrir(passe):
		return
	# LE MODE DEV DE L'EXEMPLE (`DEV_TOOLS/dev_exemple.gd`) : on ouvre la SOURCE de l'exemple, pour l'éditer.
	if _dev != null and FileAccess.file_exists(_dev.source()) and await _ouvrir(_dev.source()):
		return
	# ⚠ L'EXEMPLE N'EST JAMAIS ROUVERT AU LANCEMENT (Jordan, 2 octobre 2026) : on rouvre TON monde, le dernier projet
	# qui n'est pas l'exemple (`monde`). Un réglage d'avant n'a que `dernier`, qui peut être l'exemple : écarté.
	var mien := _mon_dernier_monde()
	if mien != "" and await _ouvrir(mien):
		return
	_nouveau_projet()


## Le dernier projet ouvert qui n'est PAS l'exemple, s'il existe encore ; "" sinon.
func _mon_dernier_monde() -> String:
	var reglages := ConfigFile.new()
	reglages.load(REGLAGES)
	for cle in ["monde", "dernier"]:
		var chemin: String = reglages.get_value("projet", cle, "")
		if chemin != "" and FileAccess.file_exists(chemin) and not est_l_exemple(chemin):
			return chemin
	return ""


## Où l'exemple s'installe : `Documents/MarchingBlocks/Example` dans l'exe, `Exemple.RACINE` ailleurs (`Dossiers`). ⚠ La fumée la détourne vers son propre dossier : elle ouvrait la copie
## INSTALLÉE de l'utilisateur — avec ses retouches — et l'appli la réenregistrait en fermant (2 octobre 2026).
static var racine_exemple: String = Dossiers.exemple()


## La source de l'exemple, en mode dev seulement (`DEV_TOOLS/dev_exemple.gd`) : elle compte comme l'exemple.
static var source_dev_exemple := ""


## Ce projet est-il l'exemple installé (dans `racine_exemple`) — ou, en mode dev, sa source ?
static func est_l_exemple(chemin: String) -> bool:
	if source_dev_exemple != "" and chemin != "":
		var a := ProjectSettings.globalize_path(chemin).replace("\\", "/").simplify_path().to_lower()
		if a == source_dev_exemple.simplify_path().to_lower():
			return true
	if chemin == "":
		return false
	# ⚠ ET L'ANCIENNE PLACE (`Exemple.RACINE`, dans les données de l'appli) : un exemple installé par un exe d'avant le
	# 4 octobre 2026 reste l'exemple — sinon il serait retenu comme « ton monde » et rouvert au lancement.
	var a := ProjectSettings.globalize_path(chemin).simplify_path()
	for racine in [racine_exemple, Exemple.RACINE]:
		# avec la barre : `…/Example` ne doit pas prendre un `…/Examples/` à soi
		if a.begins_with(ProjectSettings.globalize_path(racine).simplify_path().trim_suffix("/") + "/"):
			return true
	return false


## « My world » : ton dernier monde (pas l'exemple), ou un projet neuf s'il n'y en a pas.
func _ouvrir_mon_monde() -> void:
	if not est_l_exemple(_projet):
		_dire_le_projet()
		return
	var mien := _mon_dernier_monde()
	if mien != "" and await _ouvrir(mien):
		return
	_toujours_ecrire()
	_nouveau_projet()


## L'exemple, installé une fois par version dans les données de l'appli (`Exemple.installer`), puis ouvert comme
## n'importe quel projet.
func _ouvrir_l_exemple() -> void:
	if _dev != null:   # en mode dev, « The example » est sa SOURCE, qu'on édite
		await dev_ouvrir_la_source()
		return
	var erreurs: Array = []
	var chemin := Exemple.installer(Exemple.ARCHIVE, racine_exemple, erreurs)
	if chemin == "":
		_dire("[color=#e0603c]Cannot open the example[/color] — %s" % ", ".join(PackedStringArray(erreurs)))
		_dire_le_projet()
		return
	if not await _ouvrir(chemin):
		_dire_le_projet()


func _nouveau_projet() -> void:
	_vider_le_projet()
	_projet = _chemin_libre()
	_ajouter_couche(Projet.couche("Layer 1"))
	_activer(0)
	_retenir_le_projet()
	_enregistrer()


## Un projet neuf libre, DANS SON DOSSIER, sous `Documents/MarchingBlocks` dans l'exe (`Dossiers`) : `untitled/untitled.mbproj`,
## puis `untitled 2/…` — ses témoins s'écrivent à côté de lui, pas en vrac. Si ce dossier ne peut pas être écrit (Documents
## en lecture seule), les données de l'appli, comme avant.
func _chemin_libre() -> String:
	var chemin := Dossiers.projet_libre(Projet.EXTENSION)
	if chemin == "":
		chemin = Dossiers.projet_libre(Projet.EXTENSION, "user://")
	return chemin


func _vider_le_projet() -> void:
	# ⚠ Le projet qu'on quitte garde son dernier geste, même s'il attendait encore sa seconde.
	if _attend(_minuterie_projet):
		_enregistrer()
	_histoire.clear_history()
	_temoins_sales.clear()
	_modeleur.temoin = null
	_modeleur.maillage = null
	for m in _detachees:
		m.free()
	_detachees.clear()
	_vue.vider_couches()
	_couches.clear()
	_union.clear()
	_monde_coeur = null   # un projet neuf, un monde neuf : les couches d'avant n'y sont plus inscrites
	_active = 0
	_eaux.clear()
	_eau_active = 0
	_travaux.clear()
	_travail_actif = -1
	_transitions.vider()
	_corps_eau.clear()
	_ocean_eau = {}
	_occ_eau = {}
	_eau_changees = {}
	_eau_changees_vues = {}
	_eau_tout_refaire = false
	_eau_cases_inconnues = false
	_mer_choisie = null
	_monde_eau = {}
	_maillages_eau = []
	_nappes_memoire = []
	_index_eau.clear()
	_eau_vide = false
	if _vue != null:
		_vue.poser_eaux([])
		_feuillage.vider()


## Rend vrai si le projet est ouvert. ⚠ Chaque couche est habillée de son lot EN CACHE s'il est à jour,
## sinon RETRANCHÉE depuis sa source : c'est ce qui suit un `.glb` réenregistré dans Blender entre deux
## sessions.
func _ouvrir(chemin: String) -> bool:
	if not _couches.is_empty() and not _ouverture:
		_toujours_ecrire()   # le projet qu'on quitte garde son dernier geste et son monde
	var erreurs: Array = []
	var etat: Dictionary = Projet.depuis_texte(FileAccess.get_file_as_string(chemin), erreurs)
	if etat.is_empty():
		_dire("[color=#e0603c]Cannot open[/color] %s\n  %s" % [chemin, "\n  ".join(PackedStringArray(erreurs))])
		return false
	_ouverture = true
	_vider_le_projet()
	_projet = chemin
	var notes: Array = []
	# LA BARRE AVANCE D'UNE COUCHE À L'AUTRE (chaque couche : ses cases, son lot, parfois un tranchage).
	var avec_barre := _ecran_vivant()
	if avec_barre:
		await _attendre("Opening the project", chemin.get_file(), (etat["couches"] as Array).size())
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
		if avec_barre:
			await _avancer("layer « %s »" % c["nom"])
	if avec_barre:
		_fin_attente()
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
	var retirees := _rendre_exclusives()
	if retirees > 0:
		notes.append(("%d cell(s) belonged to several layers: each now belongs to the upper one (layers are exclusive "
			+ "since 0.9.0).") % retirees)
	_refaire_l_union()
	for e in etat.get("eaux", []):
		_ajouter_eau(e)
	_transitions.poser_etat(etat.get("transitions", {}))
	_feuillage.charger(etat.get("feuillage", {}))
	# LES TRAVAUX IMPORTÉS reviennent dans la liste de l'étape 2 (3 octobre 2026) ; leur maillage se relit quand on
	# en choisit un. Un fichier disparu depuis n'y revient pas.
	for t in etat.get("travaux", []):
		if FileAccess.file_exists(t):
			_travaux.append({"chemin": t, "maillage": null})
	_travail_actif = _travaux.size() - 1
	_redire_les_travaux()
	_eau_active = 0
	_ouverture = false
	_activer(etat["active"])
	_retenir_le_projet()
	# LES ENSEMBLES PBR (3 octobre 2026) : un monde tranché avant qu'on lise les cartes posées à côté des images porte
	# encore l'albedo seul (ou des cartes déduites) — son `.glb` est réécrit une fois, et on le dit.
	for c in _couches:
		if _ensembles_en_retard(c):
			_temoin_de(c)
			c["_glb_perime"] = true
			notes.append("« %s » now uses the PBR maps found next to its images (normal, roughness, occlusion)." % c["nom"])
	_rhabiller_les_mondes()
	_aller_a("monde")
	if _dev != null:
		_dev.noter_ouverture(chemin)
	_dire("[color=#b4bd85][b]Project opened[/b][/color] ← %s\n%d layer(s). [i]Every change is saved as you "
		% [chemin, _couches.size()] + "go — no need for Ctrl+S.[/i]%s"
		% ("" if notes.is_empty() else "\n\n" + "\n".join(PackedStringArray(notes))))
	return true


## Le monde posé d'une couche (son lot) porte-t-il les cartes des ENSEMBLES PBR de son témoin ? Vrai s'il est en
## retard : un matériau du témoin dont l'image a un ensemble avec une normale, et le matériau du même nom, dans le lot,
## sans cette normale (absente, ou une autre — les cartes déduites d'avant). Lit le `.mbtiles` sans charger le témoin.
##
## ⚠ SON VERDICT « À JOUR » EST GARDÉ (4 octobre 2026) : elle charge les images des ensembles et redescend du GPU une
## texture par matériau, pour 16 pixels — ~1,4 s à CHAQUE ouverture de l'exemple, pour une migration faite une fois.
## Sous une clé de tout ce qui pourrait la faire changer d'avis : l'empreinte du lot posé, celle du `.mbtiles`, et les
## cartes trouvées à côté de chaque image (chemins et dates).
func _ensembles_en_retard(c: Dictionary) -> bool:
	var cle := _cle_des_ensembles(c)
	var gardes := ConfigFile.new()
	gardes.load(ENSEMBLES_A_JOUR)
	if cle != "" and str(gardes.get_value("a_jour", str(c.get("temoin", "")).md5_text(), "")) == cle:
		return false
	var en_retard := _ensembles_en_retard_(c)
	if not en_retard and cle != "":
		gardes.set_value("a_jour", str(c.get("temoin", "")).md5_text(), cle)
		DirAccess.make_dir_recursive_absolute(ENSEMBLES_A_JOUR.get_base_dir())
		gardes.save(ENSEMBLES_A_JOUR)
	return en_retard


const ENSEMBLES_A_JOUR := "user://cache/ensembles_a_jour.cfg"


## La clé de `_ensembles_en_retard` : "" si la couche n'a pas de témoin enregistré ou pas de lot posé.
func _cle_des_ensembles(c: Dictionary) -> String:
	var chemin := str(c.get("temoin", ""))
	var i := _couches.find(c)
	if chemin == "" or not FileAccess.file_exists(chemin) or i < 0:
		return ""
	var lot: MeshLibrary = _vue.couche(i).lot
	if lot == null:
		return ""
	var morceaux: Array = [str(lot.get_meta("empreinte", "")), FileAccess.get_md5(chemin)]
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	if d is Dictionary:
		for m in (d as Dictionary).get("materiaux", []):
			if not m is Dictionary:
				continue
			var image := str(m.get("texture", ""))
			morceaux.append("%s|%s|%s" % [m.get("nom", ""), image, m.get("ensemble", true)])
			if image == "":
				continue
			var f: Dictionary = Peinture.fichiers_de_l_ensemble(image)
			for carte in f.keys():
				var fichier := str(f[carte])
				morceaux.append("%s=%s@%d" % [carte, fichier,
					FileAccess.get_modified_time(fichier) if FileAccess.file_exists(fichier) else -1])
	return "|".join(PackedStringArray(morceaux.map(func(x): return str(x)))).md5_text()


func _ensembles_en_retard_(c: Dictionary) -> bool:
	var chemin := str(c.get("temoin", ""))
	if chemin == "" or not FileAccess.file_exists(chemin) or not _source_liee(c):
		return false
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	if not d is Dictionary:
		return false
	# nom du matériau → {"normale": image de la normale de son ensemble, "emission": celle de son émission} (celles
	# qu'il a). L'émission (6 octobre 2026) : un monde tranché avant elle n'en porte pas.
	var voulues := {}
	for m in (d as Dictionary).get("materiaux", []):
		if not m is Dictionary or not bool(m.get("ensemble", true)):
			continue
		var e: Dictionary = Peinture.ensemble_de(str(m.get("texture", "")))
		var cartes := {}
		for carte in ["normale", "emission"]:
			if not e.is_empty() and e.get(carte) != null:
				cartes[carte] = (e[carte] as ImageTexture).get_image()
		if not cartes.is_empty():
			voulues[str(m.get("nom", ""))] = cartes
	if voulues.is_empty():
		return false
	var lot: MeshLibrary = _vue.couche(_couches.find(c)).lot
	if lot == null:
		return false
	for id in lot.get_item_list():
		var mesh: Mesh = lot.get_item_mesh(id)
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var sm := Anim.statique(mesh.surface_get_material(s)) as BaseMaterial3D
			if sm == null or not voulues.has(sm.resource_name):
				continue
			var cartes: Dictionary = voulues[sm.resource_name]
			for carte in cartes:
				var tex: Texture2D = sm.normal_texture if carte == "normale" else (sm.emission_texture
					if sm.emission_enabled else null)
				var lue: Image = tex.get_image() if tex != null else null
				if lue == null or not _memes_pixels(lue, cartes[carte]):
					return true
			voulues.erase(sm.resource_name)
			if voulues.is_empty():
				return false
	return false


## Deux images à peu près égales (même taille, seize pixels à 3/255 près) — une normale relue d'un .glb (PNG) contre
## celle de l'ensemble.
static func _memes_pixels(a: Image, b: Image) -> bool:
	if a.get_size() != b.get_size():
		return false
	var ia := a.duplicate() as Image
	var ib := b.duplicate() as Image
	for i in [ia, ib]:
		if i.is_compressed():
			i.decompress()
	for k in 16:
		var x: int = (k * 37 + 3) % a.get_width()
		var y: int = (k * 53 + 7) % a.get_height()
		var pa := ia.get_pixel(x, y)
		var pb := ib.get_pixel(x, y)
		if absf(pa.r - pb.r) > 0.012 or absf(pa.g - pb.g) > 0.012 or absf(pa.b - pb.b) > 0.012:
			return false
	return true


## Pose le lot d'une couche relue. Rend une ligne de rapport, vide si tout va bien.
## ⚠ UNE SOURCE ABSENTE SE VOIT (charte §3) : l'ancien lot s'il en reste un, en le DISANT ; sinon un lot
## vide, donc des cubes rouges partout — jamais le repli procédural, qui ferait croire la couche saine.
func _habiller_couche(i: int) -> String:
	var massif: Node = _vue.couche(i)
	# ⚠ PENDANT L'OUVERTURE, LE LOT EST POSÉ SANS RECONSTRUIRE : `_refaire_l_union` reconstruit chaque couche visible
	# juste après, sur l'union (et marque les cachées « à refaire en entier »). Chaque couche se reconstruisait deux fois.
	if _ouverture:
		massif.reconstruire_au_lot = false
		var note: String = await _habiller_couche_(i)
		massif.reconstruire_au_lot = true
		return note
	return await _habiller_couche_(i)


func _habiller_couche_(i: int) -> String:
	var c: Dictionary = _couches[i]
	var massif: Node = _vue.couche(i)
	if c["source"] == "":
		if _ouverture:
			return ""   # `_refaire_l_union` la reconstruira
		# ⚠ Ses cases viennent d'être posées : sans lot à donner, rien d'autre ne la reconstruirait (le prochain
		# geste ne reconstruit plus que ses alentours).
		massif.reconstruire()
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
## `en_fond` : l'enregistrement DIFFÉRÉ (la seconde de calme après un geste) met le texte en forme et l'écrit sur un
## AUTRE FIL (2 octobre 2026 : sur l'exemple, ~0,3 s à chaque geste, une image gelée). Ici, sur le fil principal, on
## ne fait que relever les cases (`get_used_cells`, quelques ms). Toute autre écriture (fermeture, Ctrl+S, changement
## de projet, une opération d'écran) reste SYNCHRONE — et attend d'abord celle qui serait en cours : deux écritures
## du même fichier ne se croisent jamais.
func _enregistrer(en_fond := false) -> void:
	if _ouverture or _projet == "" or _couches.is_empty():
		return
	if _minuterie_projet != null:
		_minuterie_projet.stop()   # ce qui attendait est écrit maintenant
	_attendre_l_ecriture()
	_dire_le_projet()
	var sorties: Array = []
	for i in _couches.size():
		var c: Dictionary = _couches[i]
		sorties.append({"nom": c["nom"], "source": c["source"], "visible": c["visible"], "temoin": c.get("temoin", ""),
			"id": c.get("id", ""), "cases": (_vue.couche(i).get_node("Cases") as GridMap).get_used_cells(),
			"poids": (_vue.couche(i).poids as Dictionary).duplicate(true), "choix": (_vue.couche(i).choix as Dictionary).duplicate()})
	var eaux: Array = _eaux.duplicate(true)
	var travaux := _chemins_des_travaux()
	var transitions: Dictionary = (_transitions.etat as Dictionary).duplicate(true)
	var feuillage: Dictionary = _feuillage.vers_donnees()
	if en_fond:
		_dire_enregistre("en_cours")
		# ⚠ HAUTE PRIORITÉ (4 octobre 2026) : en basse priorité, elle attendait jusqu'à 3,4 s derrière les cartes PBR de
		# l'ouverture — et un Ctrl+S, une fermeture l'attendaient avec elle.
		_tache_ecriture = WorkerThreadPool.add_task(_ecrire_le_projet.bind(_projet, sorties, _active, eaux, travaux, true, transitions, feuillage),
			true, "Saving the project")
		return
	_ecrire_le_projet(_projet, sorties, _active, eaux, travaux, false, transitions, feuillage)


## Les chemins des travaux importés, dans l'ordre (la liste de l'étape 2 survit à la session).
func _chemins_des_travaux() -> Array:
	return _travaux.map(func(t): return str(t["chemin"]))


var _tache_ecriture := -1


## Attend l'écriture en cours sur l'autre fil, s'il y en a une.
func _attendre_l_ecriture() -> void:
	if _tache_ecriture >= 0:
		WorkerThreadPool.wait_for_task_completion(_tache_ecriture)
		_tache_ecriture = -1


## Le texte et le fichier — sur un autre fil quand `en_fond` (rien n'y touche à l'écran : le résultat revient par
## `_ecriture_finie`, sur le fil principal).
func _ecrire_le_projet(chemin: String, sorties: Array, active: int, eaux: Array, travaux: Array, en_fond: bool,
		transitions: Dictionary = {}, feuillage: Dictionary = {}) -> void:
	var raison := ""
	var provisoire := chemin + ".tmp"
	var f := FileAccess.open(provisoire, FileAccess.WRITE)
	if f == null:
		raison = "%s cannot be written (error %d)." % [chemin, FileAccess.get_open_error()]
	else:
		f.store_string(Projet.vers_texte(sorties, active, eaux, travaux, transitions, feuillage))
		f.close()
		var e: int = DirAccess.rename_absolute(provisoire, chemin)
		if e != OK:
			raison = "%s could not replace the old file (error %d)." % [chemin, e]
	if en_fond:
		_ecriture_finie.call_deferred(raison)
	else:
		_ecriture_finie(raison)


func _ecriture_finie(raison: String) -> void:
	_attendre_l_ecriture()   # la tâche est finie (ou finit) : on la rend au moteur
	if raison != "":
		_dire("[color=#e0603c]Project NOT saved[/color] — %s" % raison)
		_dire_enregistre("echec")
		return
	# Un témoin modifié attend encore sa seconde : l'état reste « Saving… » jusqu'à ce qu'il soit écrit.
	_dire_enregistre("enregistre")


## ⚠ L'HISTORIQUE N'ÉCRIT PLUS À CHAQUE GESTE (Jordan, 1er octobre 2026 : « une toute petite opération fait
## lagger »). Chaque coup, chaque opération, chaque Ctrl+Z relançait l'écriture du projet ENTIER (~18 ms sur 12 474
## cases, mesuré) : une rafale de vingt Ctrl+Z en écrivait vingt. Il attend désormais une seconde de calme, comme
## le témoin ; la fermeture, Ctrl+S, le changement de projet et chaque passage par `_toujours_ecrire` l'écrivent
## tout de suite. La barre de titre dit « ● Saving… » pendant la seconde.
## ⚠ LES RÉGLAGES D'ÉCRAN AUSSI (2 octobre 2026) : activer, montrer, renommer une couche, régler l'eau écrivaient le
## projet sur-le-champ — ~0,3 s chacun sur l'exemple. Ils attendent la même seconde, et s'écrivent sur l'autre fil.
func _enregistrer_plus_tard() -> void:
	# ⚠ À LA FERMETURE, L'ÉCRAN EST DÉJÀ HORS DE L'ARBRE quand on libère l'historique, qui émet `version_changed`
	# (mesuré, 2 octobre 2026) : la minuterie relancée là donnait « Unable to start the timer because it's not
	# inside the scene tree » à CHAQUE fermeture. La fermeture a déjà tout écrit (`_toujours_ecrire`).
	if not is_inside_tree() or _ouverture or _projet == "" or _couches.is_empty():
		return
	_minuterie_projet.start()
	_dire_enregistre("en_cours")


static func _attend(minuterie: Timer) -> bool:
	return minuterie != null and not minuterie.is_stopped()


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


## Ce qui attendait, écrit en entier : la seconde d'attente, les témoins, leurs `.glb`, le projet.
func _toujours_ecrire() -> void:
	if _minuterie_temoin != null:
		_minuterie_temoin.stop()
	_enregistrer_le_temoin_modele(true)
	for c in _couches:
		_rhabiller(c)
	_ecrire_les_caches()
	_enregistrer()


## Ctrl+S : écrit TOUT DE SUITE ce qui attendait (les témoins modifiés, le projet), et dit que c'était inutile.
func _enregistrer_tout() -> void:
	_toujours_ecrire()
	_dire(("[color=#b4bd85][b]Everything is saved[/b][/color] — MarchingBlocks saves after every change, so "
		+ "there is no need for Ctrl+S.\n[i]« Save as » (Project) puts the project where you want: %s[/i]")
		% _projet)


## Le témoin d'enregistrement de la barre de titre : "enregistre", "en_cours" ou "echec".
func _dire_enregistre(etat: String) -> void:
	if _etat_enregistre == null:
		return
	# Tant qu'une écriture attend sa seconde (le projet ou un témoin), ou s'écrit sur l'autre fil, rien n'est « Saved ».
	if etat == "enregistre" and (_attend(_minuterie_projet) or _attend(_minuterie_temoin)
			or (_tache_ecriture >= 0 and not WorkerThreadPool.is_task_completed(_tache_ecriture))):
		etat = "en_cours"
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
	if not est_l_exemple(_projet):
		reglages.set_value("projet", "monde", _projet)
		var recents: Array = reglages.get_value("projet", "recents", [])
		recents.erase(_projet)
		recents.push_front(_projet)
		reglages.set_value("projet", "recents", recents.slice(0, RECENTS_MAXI))
	reglages.save(REGLAGES)
	_dire_le_projet()
	_redire_les_recents()


## Les projets récents (pas l'exemple, pas celui qui est ouvert, seulement ceux qui existent encore) : un bouton chacun.
func _redire_les_recents() -> void:
	if _recents == null:
		return
	for b in _recents.get_children():
		_recents.remove_child(b)
		b.queue_free()
	var reglages := ConfigFile.new()
	reglages.load(REGLAGES)
	var liste: Array = []
	for chemin in reglages.get_value("projet", "recents", []):
		if str(chemin) != _projet and FileAccess.file_exists(str(chemin)) and not est_l_exemple(str(chemin)):
			liste.append(str(chemin))
	if liste.is_empty():
		return
	_recents.add_child(_texte("Recent", 11, Palette.GRIS))
	for chemin in liste:
		var b := _bouton(chemin.get_file().get_basename(), "Open " + chemin, func() -> void: await _ouvrir(chemin), "ouvrir")
		b.clip_text = true
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
		b.custom_minimum_size = Vector2(0, 26)
		_recents.add_child(b)


func _dire_le_projet() -> void:
	# ⚠ LES DEUX, EXPLICITEMENT : `set_pressed_no_signal` ignore le ButtonGroup — n'enfoncer que l'un laissait
	# l'autre enfoncé aussi (vu par Jordan, 2 octobre 2026).
	if _choix_monde != null:
		var exemple := est_l_exemple(_projet)
		(_choix_monde.get_child(0) as Button).set_pressed_no_signal(not exemple)
		(_choix_monde.get_child(1) as Button).set_pressed_no_signal(exemple)
	if _etiquette_projet == null:
		return
	_etiquette_projet.text = _projet.get_file().get_basename()
	_etiquette_projet_chemin.text = ("Autosaved in the app data — « Save as » to keep it elsewhere."
		if _projet.begins_with("user://") else "Autosaved · " + _projet.get_base_dir().replace("\\", "/"))
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
			KEY_F:
				_basculer_vol()
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if _atelier == "transitions":
		if k.physical_keycode == KEY_QUOTELEFT:
			_teleporter()
			get_viewport().set_input_as_handled()
			return
		match k.keycode:
			KEY_ESCAPE:
				_changer_d_atelier("monde")
			KEY_F:
				_cadrer_tout_le_monde()
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if _atelier == "feuillage":
		if k.physical_keycode == KEY_QUOTELEFT:
			_teleporter()
		else:
			match k.keycode:
				KEY_ESCAPE:
					_changer_d_atelier("monde")
				KEY_PAGEUP:
					_compteur_etage.value += 1
				KEY_PAGEDOWN:
					_compteur_etage.value -= 1
				KEY_F:
					_cadrer_tout_le_monde()
				_:
					return
		get_viewport().set_input_as_handled()
		return
	if _atelier == "fluides":
		# LA MER EN CHOIX : PgUp / PgDn la montent ou la descendent, Entrée la pose, Échap l'abandonne.
		if _mer_choisie != null:
			match k.keycode:
				KEY_PAGEUP, KEY_UP:
					_hausser_la_mer(1)
				KEY_PAGEDOWN, KEY_DOWN:
					_hausser_la_mer(-1)
				KEY_ENTER, KEY_KP_ENTER:
					_valider_la_mer()
				KEY_ESCAPE:
					_annuler_la_mer()
				_:
					return
			get_viewport().set_input_as_handled()
			return
		if k.physical_keycode == KEY_QUOTELEFT:
			_teleporter()
			get_viewport().set_input_as_handled()
			return
		match k.keycode:
			KEY_ESCAPE:
				_changer_d_atelier("monde")
			KEY_PAGEUP:
				_compteur_etage.value += 1
			KEY_PAGEDOWN:
				_compteur_etage.value -= 1
			KEY_F:
				_cadrer_tout_le_monde()
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
	if k.physical_keycode == KEY_QUOTELEFT:
		_teleporter()
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
			if _vue.outil == "forme" and _vue.forme_speciale["quoi"] == "salle":
				_etages_forme.value -= 1
			elif _vue.outil == "forme":
				_taille_forme.value -= 1
			else:
				_taille.value -= 1
		KEY_BRACKETRIGHT:
			if _vue.outil == "forme" and _vue.forme_speciale["quoi"] == "salle":
				_etages_forme.value += 1
			elif _vue.outil == "forme":
				_taille_forme.value += 1
			else:
				_taille.value += 1
		KEY_PAGEUP:
			_compteur_etage.value += 1
		KEY_PAGEDOWN:
			_compteur_etage.value -= 1
		KEY_F:
			_cadrer_tout_le_monde()
		KEY_DELETE:
			_operer_selection("supprimer")
		KEY_ESCAPE:
			if not _vue.collage.is_empty():
				_vue.annuler_collage()
				_dire("[i]Paste cancelled.[/i]")
			elif not _vue.ancre_forme.is_empty():
				_vue.oublier_ancre()
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
	if _noter_le_geste(event):
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_F1 and not _manuel.visible:
		_manuel.ouvrir()
		get_viewport().set_input_as_handled()
		return
	if _manuel != null and _manuel.visible:
		return
	if k != null and k.pressed and _atelier in ["witness", "texture"] and _touche_du_temoin(k):
		get_viewport().set_input_as_handled()
		return
	if k == null or not k.pressed or not _atelier in ["monde", "fluides", "transitions", "feuillage"] or k.ctrl_pressed or k.alt_pressed:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	# DANS FLUIDS, TRANSITIONS ET FOLIAGE, SEUL ESPACE (Navigate) : la visée, les flèches de la sélection sont des gestes de World.
	if _atelier in ["fluides", "transitions", "feuillage"] and k.keycode != KEY_SPACE:
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
		_basculer_edition(not _vue.edition)
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
		_suivre_le_mode_de_selection()
	return pris


func _dire(texte: String) -> void:
	if _rapport != null:
		_rapport.text = texte
