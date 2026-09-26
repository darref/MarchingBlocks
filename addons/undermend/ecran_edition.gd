@tool
extends Control
## L'ÉCRAN DU GREFFON — trois boutons, et plus aucun réglage.
##
## ⚠ **IL EN CONTENAIT BEAUCOUP PLUS, ET C'ÉTAIT LE DÉFAUT** (Jordan, 24 septembre 2026) : deux onglets,
## une vue 3D orbitale avec son gizmo, un catalogue de neuf blocs, un panneau d'import et de tranchage.
## Chaque pièce se justifiait seule ; ensemble elles noyaient ce qu'on veut faire. Ce qui reste est la
## BOUCLE COMPLÈTE, et rien d'autre :
##
##   1. GÉNÉRER LES NŒUDS   le témoin calculé → tranchage → MeshLibrary → un MassifPeint vide, à peindre ;
##   2. EXPORTER LE TÉMOIN  en UN .glb, n'importe où sur le disque, pour Blender ;
##   3. IMPORTER LE TRAVAIL relit le .glb sculpté et l'AFFICHE dans la vue — rien n'est encore tranché ;
##   4. TRANCHER, GÉNÉRER ET PEINDRE  tranche ce travail, pose les nœuds, et peint les cases du témoin.
##
## Le quatrième est le seul essai qui prouve quelque chose : le témoin repeint avec l'art réimporté doit
## redonner le témoin — toute la chaîne tient alors, export, modélisation, réimport, tranchage,
## classification, assemblage. (Noms des boutons : Jordan, 27 septembre 2026.)
##
## ⚠ **TOUT EST DANS UNE BARRE DE DÉFILEMENT (Jordan, 27 septembre 2026)** : la vue carrée, la légende,
## les boutons et les opérations d'étage dépassaient la hauteur de la bande, et le bas devenait
## inatteignable. Le défilement est VERTICAL seulement — la vue tire sa hauteur de sa largeur, et une
## largeur qui défile la laisserait grandir sans fin.
##
## ⚠ UN GREFFON D'ÉDITEUR NE SE TESTE PAS EN HEADLESS (charte §6). On vérifie qu'il COMPILE et que les
## règles qu'il appelle sont justes ; qu'il apparaisse et que les boutons agissent se juge dans l'éditeur.

const MB := preload("res://addons/undermend/marching_blocks.gd")
const BlocsMaitres := preload("res://addons/undermend/blocs_maitres.gd")
# ⚠ Pour la LÉGENDE sous la vue, qui lit les six teintes à leur source au lieu de les recopier.
const RP := preload("res://addons/undermend/repli_procedural.gd")

## ⚠ **UN SEUL LOT, PARCE QU'IL N'Y A PLUS QU'UN MODE (Jordan, 25 septembre 2026).** Il y en avait deux,
## `marching_blocks_9.tres` et `marching_blocks_moitie.tres`, que la case à cocher départageait. Le « 9 »
## comptait des blocs qui n'existent plus, et la « moitié » ne distinguait plus rien une fois l'aminci
## devenu la règle : deux noms qui désignaient des choix disparus (charte §6, « un mot, une chose »).
const LOT := "res://ART/marching_blocks.tres"

const OR := Color("#ebbb69")

var _rapport: RichTextLabel
var _dialogue: EditorFileDialog
## Ce que le dialogue de dossier doit faire au retour : "exporter" ou "importer".
var _action := ""

## L'étage sur lequel portent les opérations. ⚠ Un étage, et pas une sélection : `GridMap` n'expose
## aucune notion de sélection au script (mesuré, `DEV_TOOLS/sonde_api_editeur.gd`).
var _etage := 0
var _etiquette_etage: Label

## ── LA VUE DU TÉMOIN ────────────────────────────────────────────────────────────────────────────────
##
## ⚠ **UNE VUE 3D A DÉJÀ ÉTÉ RETIRÉE D'ICI (Jordan, 24 septembre 2026)**, avec deux onglets, un
## catalogue et un panneau de tranchage : *« chaque pièce se justifiait seule, ensemble elles noyaient
## ce qu'on veut faire »*. Celle-ci revient pour une raison qui n'existait pas alors : **le témoin
## unique n'a plus de légende**. Mesuré — 76 % de son volume est sous roche et rien ne le disait, ce qui
## a coûté à Jordan une soirée de modélisation passée à extruder le haut en croyant tenir un massif.
##
## Elle montre **le solide aminci tel qu'il part chez l'artiste** (Jordan, 25 septembre 2026) — donc
## avec sa légende — et non le résultat tranché : on regarde ce qu'il y a à sculpter, pas une pose.
var _vue: SubViewport
var _camera: Camera3D
## Le maillage montré : le témoin calculé, puis le travail importé.
var _instance: MeshInstance3D
## Ce que la vue montre, écrit sous elle — sinon on ne sait pas si l'on regarde le témoin ou son art.
var _etiquette_vue: Label
## Le `.glb` importé, que « Trancher, générer et peindre » relira. ⚠ RELU au moment du clic, pas gardé
## en mémoire : l'artiste a pu réenregistrer entre les deux, et c'est son dernier état qu'on tranche.
var _travail := ""
var _azimut := 0.7
var _elevation := 0.6


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if get_child_count() > 0:
		return  # déjà bâti (le greffon peut nous ré-ajouter à l'arbre)
	_batir()


func _batir() -> void:
	var defile := ScrollContainer.new()
	defile.set_anchors_preset(Control.PRESET_FULL_RECT)
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(defile)

	var marge := MarginContainer.new()
	marge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for cote in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		marge.add_theme_constant_override(cote, 12)
	defile.add_child(marge)

	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 10)
	marge.add_child(colonne)

	var titre := Label.new()
	titre.text = "Undermend — tuiles 3D"
	titre.add_theme_font_size_override("font_size", 18)
	titre.add_theme_color_override("font_color", OR)
	colonne.add_child(titre)

	_batir_la_vue(colonne)

	# ⚠ **UNE CASE À COCHER A VÉCU ICI (retirée par Jordan, 25 septembre 2026).** Elle offrait le solide
	# brut à la place de l'aminci. Ce n'était pas un réglage mais une manière de se tromper : l'aminci est
	# ce qui part chez l'artiste, donc le seul mode qui décrive la réalité de ce qu'il va sculpter.
	var generer := Button.new()
	generer.text = "Générer les nœuds"
	generer.tooltip_text = ("Le témoin calculé, passé par tout le pipeline, et un MassifPeint vide à "
		+ "peindre.\nTuiles ramenées à la moitié de leur case : les faces qui donnent sur du VIDE "
		+ "rentrent d'un quart.\nUne face partagée entre deux cases pleines reste intacte.")
	generer.custom_minimum_size = Vector2(0, 36)
	generer.pressed.connect(func(): _peindre_avec(BlocsMaitres.librairie(), LOT, "catalogue"))
	colonne.add_child(generer)

	colonne.add_child(HSeparator.new())

	var exporter := Button.new()
	exporter.text = "Exporter le témoin…"
	exporter.tooltip_text = ("Écrit le témoin dans UN .glb, pour le modéliser et le texturer dans "
		+ "Blender.\n"
		+ "⚠ Ne le DÉPLACE pas : c'est sa position qui l'identifie au retour, pas son nom.\n"
		+ "Tuiles déjà ramenées à la moitié de leur case, pour montrer la marge disponible.")
	exporter.custom_minimum_size = Vector2(0, 36)
	exporter.pressed.connect(func(): _demander_un_fichier("exporter"))
	colonne.add_child(exporter)

	var importer := Button.new()
	importer.text = "Importer le travail…"
	importer.tooltip_text = ("Relit le .glb sculpté et l'AFFICHE dans la vue, tel que le trancheur le "
		+ "lira.\nRien n'est tranché ni posé : c'est le bouton suivant.")
	importer.custom_minimum_size = Vector2(0, 36)
	importer.pressed.connect(func(): _demander_un_fichier("importer"))
	colonne.add_child(importer)

	var trancher := Button.new()
	trancher.text = "Trancher, générer et peindre"
	trancher.tooltip_text = ("Relit le travail importé, le tranche, pose un MassifPeint avec ses tuiles, "
		+ "et y peint les cases du témoin.\nLe résultat doit redonner le témoin : c'est la preuve que "
		+ "l'aller-retour tient.\n⚠ Un bloc dont la boîte ressort vide garde sa version calculée, et "
		+ "c'est DIT — jamais en silence.")
	trancher.custom_minimum_size = Vector2(0, 36)
	trancher.pressed.connect(_trancher_generer_et_peindre)
	colonne.add_child(trancher)

	colonne.add_child(HSeparator.new())

	# ── LES OPÉRATIONS D'ÉTAGE ───────────────────────────────────────────────────────────────────────
	#
	# ⚠ **ELLES PORTENT SUR UN ÉTAGE, ET PAS SUR UNE SÉLECTION — MESURÉ, PAS CHOISI PAR PARESSE.**
	# `DEV_TOOLS/sonde_api_editeur.gd` a listé les treize méthodes de cases de `GridMap` :
	# `get_used_cells`, `set_cell_item`, `get_cell_item`… et **aucune notion de sélection**. La sélection
	# en boîte qu'on voit en peignant appartient à l'éditeur C++ du GridMap et n'est pas exposée au
	# script. Opérer sur « les cases sélectionnées » est donc impossible sans écrire notre propre
	# sélection (`_forward_3d_gui_input`) — un autre chantier. L'étage est le compromis retenu par
	# Jordan : c'est le geste qu'on fait le plus souvent en montant un massif.
	var titre_etage := Label.new()
	titre_etage.text = "Opérations sur un étage"
	titre_etage.add_theme_color_override("font_color", OR)
	colonne.add_child(titre_etage)

	var ligne_etage := HBoxContainer.new()
	colonne.add_child(ligne_etage)
	var dit := Label.new()
	dit.text = "étage y ="
	ligne_etage.add_child(dit)
	var compteur := SpinBox.new()
	compteur.min_value = -64
	compteur.max_value = 64
	compteur.value = 0
	compteur.value_changed.connect(func(v): _etage = int(v); _dire_l_etage())
	ligne_etage.add_child(compteur)
	_etiquette_etage = Label.new()
	_etiquette_etage.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	ligne_etage.add_child(_etiquette_etage)

	# ⚠ Chaque opération dit ce qu'elle FAIT, pas seulement son nom : « creuser » n'efface pas l'étage
	# (la gomme existe déjà), il évide l'intérieur en gardant le pourtour.
	for op in [
		["Étendre vers le haut", "haut", "recopie l'étage une case plus haut"],
		["Étendre vers le bas", "bas", "recopie l'étage une case plus bas"],
		["Élargir (extruder)", "elargir", "ajoute une couronne autour de l'empreinte, au même étage"],
		["Creuser", "creuser", "retire les cases dont les quatre voisines horizontales sont pleines"],
	]:
		var bouton := Button.new()
		bouton.text = op[0]
		bouton.tooltip_text = op[2]
		bouton.pressed.connect(_operer.bind(op[1]))
		colonne.add_child(bouton)

	_rapport = RichTextLabel.new()
	_rapport.bbcode_enabled = true
	_rapport.custom_minimum_size = Vector2(0, 180)
	_rapport.text = "[i]Ouvre une scène 3D, puis clique.[/i]"
	# ⚠ DANS UNE BARRE DE DÉFILEMENT, « S'ÉTENDRE » N'A PLUS DE SENS : il n'y a pas de hauteur à remplir.
	# Le rapport grandit donc avec son texte, et c'est la barre qui défile.
	_rapport.fit_content = true
	colonne.add_child(_rapport)

	# ⚠ ACCÈS AU SYSTÈME DE FICHIERS ENTIER, pas au seul `res://` : tout l'objet de l'export est de
	# poser le set là où Blender ira le chercher, donc hors du projet.
	# ⚠ **UN FICHIER, PLUS UN DOSSIER (Jordan, 24 septembre 2026).** Neuf `.glb` à ouvrir un par un puis
	# à réexporter un par un n'était pas tenable. Le set part et revient en UN fichier.
	_dialogue = EditorFileDialog.new()
	_dialogue.access = EditorFileDialog.ACCESS_FILESYSTEM
	_dialogue.add_filter("*.glb", "MasterBlockSet")
	_dialogue.file_selected.connect(_fichier_choisi)
	add_child(_dialogue)


## Bâtit la vue orbitale du témoin, carrée, en tête de la bande.
##
## ⚠ **SA HAUTEUR EST PILOTÉE PAR SA LARGEUR** — c'est ce qui la rend carrée quelle que soit la largeur
## que Jordan donne à la bande, qui est redimensionnable à la souris. Dans la barre de défilement, il n'y
## a de toute façon plus de hauteur à se disputer.
func _batir_la_vue(colonne: VBoxContainer) -> void:
	var boite := SubViewportContainer.new()
	boite.stretch = true
	boite.tooltip_text = ("Le témoin tel qu'il part chez toi, ou ton travail une fois importé — glisse "
		+ "pour le tourner.\nLes six teintes sont nommées dessous : sol, paroi et plafond, chacun à l'air "
		+ "libre ou en GROTTE.")
	boite.gui_input.connect(_tourner_la_vue)
	# ⚠ LA GARDE CONTRE LA BOUCLE : écrire une taille minimale depuis un gestionnaire de
	# redimensionnement redéclenche ce même gestionnaire. On ne l'écrit que si elle change vraiment.
	boite.resized.connect(func():
		if not is_equal_approx(boite.custom_minimum_size.y, boite.size.x):
			boite.custom_minimum_size = Vector2(0, boite.size.x))
	colonne.add_child(boite)

	_vue = SubViewport.new()
	_vue.own_world_3d = true
	# ⚠ `WHEN_VISIBLE` et non `ALWAYS` : la vue ne se redessine que quand on la regarde. `ALWAYS` ferait
	# tourner un rendu 3D en permanence dans l'éditeur, pendant qu'on peint.
	_vue.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	boite.add_child(_vue)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#101216")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8892a4")
	env.ambient_light_energy = 0.85
	var monde := WorldEnvironment.new()
	monde.environment = env
	_vue.add_child(monde)

	var lumiere := DirectionalLight3D.new()
	lumiere.rotation_degrees = Vector3(-48, -34, 0)
	lumiere.light_energy = 1.1
	_vue.add_child(lumiere)

	# ⚠ **LE MAILLAGE EST BÂTI UNE SEULE FOIS** (15 560 quads) ; le reconstruire à chaque image ferait
	# ramer l'éditeur pendant qu'on peint. Tourner ne change que la CAMÉRA, et seul l'import le remplace.
	_instance = MeshInstance3D.new()
	_instance.mesh = BlocsMaitres.maillage_moitie(0)
	_vue.add_child(_instance)

	_camera = Camera3D.new()
	# ⚠ ORTHOGONALE, comme les planches : un bloc ne doit pas paraître plus gros parce qu'on l'a tourné.
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = BlocsMaitres.COTE * 1.6
	_vue.add_child(_camera)
	_caler_la_camera()

	_etiquette_vue = Label.new()
	_etiquette_vue.text = "le témoin calculé"
	_etiquette_vue.add_theme_font_size_override("font_size", 11)
	_etiquette_vue.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	colonne.add_child(_etiquette_vue)

	_batir_la_legende(colonne)


## LA LÉGENDE ÉCRITE, sous la vue — une pastille de couleur et son nom.
##
## ⚠ **C'EST ELLE QUI LÈVE MON OBJECTION AUX SIX TEINTES.** Je craignais qu'un témoin à six couleurs
## devienne bariolé donc illisible ; une couleur qui porte son nom écrit juste en dessous ne se devine
## plus, elle se lit. Sans cette légende, six teintes seraient pires que trois.
##
## ⚠ **ET ELLE EST DÉRIVÉE DES CONSTANTES, jamais recopiée.** Écrire ici les codes hexadécimaux ferait
## une seconde description des couleurs : le jour où l'une change dans `repli_procedural.gd`, la légende
## mentirait sans qu'aucune erreur ne le dise — et une légende fausse est pire qu'une absence de légende.
func _batir_la_legende(colonne: VBoxContainer) -> void:
	var grille := GridContainer.new()
	grille.columns = 2
	grille.add_theme_constant_override("h_separation", 10)
	colonne.add_child(grille)

	for entree in [
		[RP.COULEUR_DESSUS, "sol à l'air libre"],
		[RP.COULEUR_DESSUS_DEDANS, "sol de GROTTE"],
		[RP.COULEUR_PAROI, "falaise"],
		[RP.COULEUR_PAROI_DEDANS, "paroi de GROTTE"],
		[RP.COULEUR_PLAFOND, "dessous de surplomb"],
		[RP.COULEUR_PLAFOND_DEDANS, "plafond de GROTTE"],
	]:
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 6)
		var pastille := ColorRect.new()
		pastille.color = entree[0]
		pastille.custom_minimum_size = Vector2(14, 14)
		# ⚠ La pastille ne doit pas s'étirer avec la colonne, sinon elle mange le texte sur une bande
		# large : c'est un repère de couleur, pas un aplat.
		pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(pastille)
		var nom := Label.new()
		nom.text = entree[1]
		nom.add_theme_font_size_override("font_size", 11)
		ligne.add_child(nom)
		grille.add_child(ligne)


## Fait tourner la vue au glissé. ⚠ **L'ÉLÉVATION EST BORNÉE À ±80°, ET CE N'EST PAS UN DÉTAIL** : sans
## butée, la caméra franchit la verticale, `look_at` bascule d'un coup et l'image se retourne. Ça se lit
## comme un bogue, alors que c'est la dégénérescence attendue du repère au pôle.
func _tourner_la_vue(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion):
		return
	var bouge := event as InputEventMouseMotion
	if (bouge.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		return
	# ⚠ **LES DEUX SIGNES ONT ÉTÉ INVERSÉS (Jordan, 25 septembre 2026) : le glissé partait à l'envers.**
	# Je les avais choisis au jugé, faute de pouvoir juger un glissé en headless — c'est exactement le
	# genre de réglage que la charte §6 réserve à l'éditeur, avec Jordan. Le bloc suit maintenant la
	# souris au lieu de la fuir.
	_azimut += bouge.relative.x * 0.01
	_elevation = clampf(_elevation + bouge.relative.y * 0.01, -1.4, 1.4)
	_caler_la_camera()


## Place la caméra sur sa sphère, centrée sur le bloc.
func _caler_la_camera() -> void:
	if _camera == null:
		return
	var cible := Vector3.ONE * (BlocsMaitres.COTE * 0.5)
	var direction := Vector3(
		cos(_elevation) * sin(_azimut), sin(_elevation), cos(_elevation) * cos(_azimut))
	_camera.position = cible + direction * 40.0
	_camera.look_at_from_position(_camera.position, cible, Vector3.UP)


func _demander_un_fichier(quoi: String) -> void:
	_action = quoi
	_dialogue.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE if quoi == "exporter" \
		else EditorFileDialog.FILE_MODE_OPEN_FILE
	_dialogue.current_file = "masterblockset.glb"
	_dialogue.popup_centered_ratio(0.6)


func _fichier_choisi(fichier: String) -> void:
	match _action:
		"exporter":
			_exporter(fichier)
		"importer":
			_importer(fichier)


# ── 1. EXPORTER ─────────────────────────────────────────────────────────────────────────────────────

## ⚠ IL REFUSE si le jeu de blocs est en faute : sculpter des jours sur une base fausse coûte bien plus
## qu'un refus (charte §6).
func _exporter(fichier: String) -> void:
	var fautes: Array = BlocsMaitres.anomalies()
	if not fautes.is_empty():
		_dire("[color=#e0603c]REFUSÉ — %d anomalie(s) dans les blocs maîtres :[/color]\n  %s"
			% [fautes.size(), "\n  ".join(PackedStringArray(fautes.slice(0, 6)))])
		return

	var raison: String = BlocsMaitres.exporter_le_bloc(fichier)
	if raison != "":
		_dire("[color=#e0603c]Échec de l'export :[/color] %s" % raison)
		return

	var dehors: int = MB.exterieures_a_sculpter().size()
	var total: int = MB.pieces_a_sculpter().size()
	var texte := "[color=#6f9e4a][b]MasterBlock écrit[/b][/color] → %s\n" % fichier
	texte += "  « %s » — un seul bloc de %d × %d × %d\n" \
		% [BlocsMaitres.BLOCS[0]["nom"], BlocsMaitres.COTE, BlocsMaitres.COTE, BlocsMaitres.COTE]
	texte += "  %d tuiles à sculpter : %d classes en INTÉRIEUR, %d aussi à l'air libre\n" \
		% [total + dehors, total, dehors]
	texte += "  tuiles déjà ramenées à la MOITIÉ de leur case\n"
	texte += "  ni normales ni tangentes : Blender l'ouvrira en ombrage PLAT, soudé\n\n"
	texte += ("⚠ NE DÉPLACE PAS LE BLOC : c'est sa POSITION qui l'identifie au retour. Un nom ne "
		+ "survit pas à une séance de modélisation, une place fixée si.\n")
	texte += ("⚠ Le relief peut déborder d'une demi-case autour du bloc ; au-delà il sera perdu.\n")
	texte += "⚠ Ne change pas QUELLES cases sont pleines — c'est le remplissage qui fixe les classes.\n"
	# ⚠ « QUELQUES ARÊTES RESTENT AMBIGUËS » A ÉTÉ DIT ICI jusqu'au 27 septembre 2026 : c'était vrai du
	# monde avec diagonales. Le témoin sans contact diagonal est manifold — mesuré, 0 arête à 3 faces.
	texte += ("\n[i]Passe-le en quads (Alt+J) : les boucles d'arêtes deviennent continues. Aucune "
		+ "arête n'est partagée par plus de deux faces.[/i]")
	_dire(texte)


# ── 2. IMPORTER LE TRAVAIL : on l'AFFICHE, rien de plus ─────────────────────────────────────────────

## ⚠ **ON MONTRE CE QUE LE TRANCHEUR LIRA, PAS LE FICHIER BRUT** : `travail_depuis_glb()` est l'appel même
## qu'emploie le tranchage. Un relief perdu hors de la boîte tolérante disparaît donc ICI, sous les yeux
## de l'artiste, et non plus tard, en silence, dans le lot.
func _importer(fichier: String) -> void:
	var journal: Array = []
	var travail: ArrayMesh = BlocsMaitres.travail_depuis_glb(fichier, journal)
	if travail == null:
		_travail = ""
		var motif: String = "\n  ".join(PackedStringArray(journal)) if not journal.is_empty() \
			else "aucune géométrie dans la boîte du bloc — l'a-t-on déplacé ?"
		_dire("[color=#e0603c]Rien à afficher depuis[/color] %s\n  %s" % [fichier, motif])
		return
	_travail = fichier
	_instance.mesh = travail
	_etiquette_vue.text = "le travail importé — %s" % fichier.get_file()
	_dire(("[color=#6f9e4a][b]Travail importé[/b][/color] ← %s\n\n"
		+ "La vue le montre tel que le trancheur le lira : ce qui dépasse la boîte du bloc n'y est plus.\n\n"
		+ "[i]« Trancher, générer et peindre » le relira au moment du clic — réenregistrer dans Blender "
		+ "entre-temps suffit.[/i]") % fichier)


# ── 3. TRANCHER, GÉNÉRER ET PEINDRE ─────────────────────────────────────────────────────────────────

func _trancher_generer_et_peindre() -> void:
	if _travail == "":
		_dire("Aucun travail importé.\n\n[i]« Importer le travail… » d'abord : on tranche ce qu'on a vu.[/i]")
		return
	var bilan: Dictionary = BlocsMaitres.librairie_depuis_glb(_travail)
	var entete := "[b]Travail tranché depuis[/b] %s\n" % _travail
	var absents: Array = bilan["absents"]
	if not absents.is_empty():
		# ⚠ ON LE DIT. Sans ça, on croirait peindre avec son art alors qu'on peint avec le témoin.
		entete += "[color=#e0b84a]⚠ bloc ABSENT du fichier, version calculée gardée :[/color] %s\n" \
			% ", ".join(PackedStringArray(absents))
	_peindre_avec(bilan, "", "travail", entete, BlocsMaitres.cases(0))


# ── le tronc commun ─────────────────────────────────────────────────────────────────────────────────

## Pose un `MassifPeint` câblé sur `bilan["lot"]`, et DIT tout ce que le bilan contient.
##
## ⚠ PARTAGÉ par les deux chemins de peinture : deux copies de cette pose auraient divergé, et l'une des
## deux aurait fini par oublier l'historique d'annulation ou le `preparer()`.
## `a_peindre` — {Vector3i: true} — remplit la grille « Cases » DANS la même action : un seul Ctrl+Z
## retire le massif et sa peinture, jamais l'un sans l'autre.
func _peindre_avec(bilan: Dictionary, chemin_du_lot: String, quoi: String, entete := "",
		a_peindre := {}) -> void:
	var racine := EditorInterface.get_edited_scene_root()
	if racine == null:
		_dire("Aucune scène ouverte.\n\nOuvre ou crée une scène 3D, puis réessaie.")
		return

	var fautes: Array = BlocsMaitres.anomalies()
	if not fautes.is_empty():
		_dire("[color=#e0603c]REFUSÉ — %d anomalie(s) dans les blocs maîtres :[/color]\n  %s"
			% [fautes.size(), "\n  ".join(PackedStringArray(fautes.slice(0, 6)))])
		return

	var lot: MeshLibrary = bilan["lot"]
	if chemin_du_lot != "":
		var err := ResourceSaver.save(lot, chemin_du_lot)
		if err != OK:
			_dire("Échec de l'enregistrement du lot (%d) : %s" % [err, chemin_du_lot])
			return
		if Engine.is_editor_hint():
			EditorInterface.get_resource_filesystem().scan()

	var noeud: Node3D = load("res://addons/undermend/massif_peint.gd").new()
	noeud.name = "MassifPeint"
	noeud.lot = lot
	# ⚠ LES TROIS GRILLES SONT BÂTIES AVANT LA POSE. Laissées au `_ready()`, elles naissent sans `owner` :
	# elles existent dans l'arbre mais N'APPARAISSENT PAS dans le dock, donc rien à peindre.
	noeud.preparer()

	# ⚠ LA TUILE À PEINDRE EST CHERCHÉE AVANT D'OUVRIR L'ACTION : un refus au milieu d'une action ouverte
	# la laisserait pendante dans l'historique de l'éditeur.
	var grille: GridMap = noeud.get_node_or_null("Cases")
	var id := -1
	if not a_peindre.is_empty():
		if grille != null and grille.mesh_library != null:
			id = grille.mesh_library.find_item_by_name("case")
		if id < 0:
			noeud.free()
			_dire("[color=#e0603c]La palette du massif n'a pas de tuile « case » : rien n'est posé.[/color]")
			return

	# ⚠ PAR L'HISTORIQUE : un bouton qui ajoute un nœud sans que Ctrl+Z le reprenne laisse traîner des
	# massifs qu'on n'a pas demandés (charte §6, même règle que le bouton « Falaises »).
	var histoire := EditorInterface.get_editor_undo_redo()
	histoire.create_action("Poser un massif à peindre")
	histoire.add_do_method(racine, "add_child", noeud, true)
	# ⚠ L'ORDRE COMPTE : le parent prend son propriétaire d'abord, les enfants ensuite.
	histoire.add_do_method(noeud, "set_owner", racine)
	for enfant in noeud.get_children():
		histoire.add_do_method(enfant, "set_owner", racine)
	var peintes := 0
	if not a_peindre.is_empty():
		for c in a_peindre:
			histoire.add_do_method(grille, "set_cell_item", c, id)
			peintes += 1
		histoire.add_do_method(noeud, "reconstruire")
	histoire.add_do_reference(noeud)
	histoire.add_undo_method(racine, "remove_child", noeud)
	histoire.commit_action()

	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(noeud)

	var texte := entete
	texte += "[color=#6f9e4a][b]Massif posé[/b][/color] (%s) — %d item(s) sur %d classes" \
		% [quoi, lot.get_item_list().size(), MB.pieces_a_sculpter().size()]
	texte += "  ·  tuiles à la MOITIÉ\n"
	if peintes > 0:
		texte += "%d case(s) du témoin peintes : le massif doit redonner le témoin, avec ton art.\n" % peintes
	if chemin_du_lot != "":
		texte += "lot écrit → %s\n" % chemin_du_lot

	var manquantes: Array = bilan["manquantes"]
	if not manquantes.is_empty():
		texte += "\n[color=#e0603c]⚠ %d classe(s) MANQUANTE(S) — cubes rouges garantis :[/color] %s\n" \
			% [manquantes.size(), ", ".join(PackedStringArray(manquantes.slice(0, 8)))]
	var erreurs: Array = bilan["erreurs"]
	if not erreurs.is_empty():
		texte += "\n[color=#e0603c]%d erreur(s) de tranchage :[/color]\n  %s\n" \
			% [erreurs.size(), "\n  ".join(PackedStringArray(erreurs.slice(0, 5)))]
	if manquantes.is_empty() and erreurs.is_empty():
		texte += "[i]Aucune classe manquante, aucune erreur de tranchage.[/i]\n"
	texte += "\n[i]Sélectionne « Cases » dans l'arbre et peins avec l'éditeur GridMap.[/i]"
	_dire(texte)


# ── LES OPÉRATIONS D'ÉTAGE ──────────────────────────────────────────────────────────────────────────

## Le `MassifPeint` sur lequel opérer : celui de la sélection, sinon le premier de la scène.
##
## ⚠ **ON LE RECONNAÎT À CE QU'IL SAIT FAIRE, PAS À SA CLASSE.** Tester un type par son nom échoue en
## SILENCE le jour où le type change — c'est exactement ce qui a fait croire pendant une heure que le
## `.glb` de Jordan était illisible, alors que l'éditeur rendait des `ImporterMeshInstance3D` que
## `is MeshInstance3D` ne reconnaissait pas.
func _massif_courant() -> Node:
	for n in EditorInterface.get_selection().get_selected_nodes():
		var p: Node = n
		while p != null:
			if p.has_method("reconstruire") and p.has_method("preparer"):
				return p
			p = p.get_parent()
	var racine := EditorInterface.get_edited_scene_root()
	return _chercher_massif(racine) if racine != null else null


func _chercher_massif(noeud: Node) -> Node:
	if noeud.has_method("reconstruire") and noeud.has_method("preparer"):
		return noeud
	for enfant in noeud.get_children():
		var trouve := _chercher_massif(enfant)
		if trouve != null:
			return trouve
	return null


## Dit ce que l'étage courant contient. ⚠ Sans ça, on opère à l'aveugle sur un étage peut-être vide, et
## un bouton qui ne fait rien passe pour un bouton cassé.
func _dire_l_etage() -> void:
	if _etiquette_etage == null:
		return
	var massif := _massif_courant()
	var cases: GridMap = massif.get_node_or_null("Cases") if massif != null else null
	if cases == null:
		_etiquette_etage.text = "  (aucun massif)"
		return
	var combien := 0
	var bas := 64
	var haut := -64
	for c in cases.get_used_cells():
		var p: Vector3i = c
		if p.y == _etage:
			combien += 1
		bas = mini(bas, p.y)
		haut = maxi(haut, p.y)
	_etiquette_etage.text = "  %d case(s) ici · peint de y=%d à y=%d" % [combien, bas, haut] \
		if combien > 0 or bas <= haut else "  (rien de peint)"


## LES QUATRE OPÉRATIONS. Toutes partent des cases occupées de l'étage `_etage`.
##
## ⚠ **ELLES PASSENT PAR L'HISTORIQUE D'ANNULATION**, comme le bouton « Falaises » : une opération qui
## réécrit des cases sans que Ctrl+Z les rattrape abîme une peinture sans retour (charte §6).
func _operer(quoi: String) -> void:
	var massif := _massif_courant()
	if massif == null:
		_dire("Aucun massif dans la scène.\n\nPose-en un, ou sélectionne-le dans l'arbre.")
		return
	var cases: GridMap = massif.get_node_or_null("Cases")
	if cases == null or cases.mesh_library == null:
		_dire("Le massif n'a pas de grille « Cases » utilisable.")
		return
	var id: int = cases.mesh_library.find_item_by_name("case")
	if id < 0:
		_dire("La palette n'a pas de tuile « case ».")
		return

	var occupees := {}
	for c in cases.get_used_cells():
		occupees[c] = true
	var a_poser := {}
	var a_effacer := {}

	match quoi:
		"haut", "bas":
			var pas := Vector3i.UP if quoi == "haut" else Vector3i.DOWN
			for c in occupees:
				var p: Vector3i = c
				if p.y == _etage and not occupees.has(p + pas):
					a_poser[p + pas] = true
		"elargir":
			# ⚠ Une couronne dans le PLAN, pas en hauteur : extruder vers le haut, c'est « étendre ».
			for c in occupees:
				var p: Vector3i = c
				if p.y != _etage:
					continue
				for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
					if not occupees.has(p + d):
						a_poser[p + d] = true
		"creuser":
			# ⚠ Évider, pas effacer : on ne retire que ce qui est entouré, donc le pourtour reste. La
			# gomme du GridMap fait déjà « effacer », ce bouton n'aurait aucune raison d'être sinon.
			for c in occupees:
				var p: Vector3i = c
				if p.y != _etage:
					continue
				var entoure := true
				for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
					if not occupees.has(p + d):
						entoure = false
						break
				if entoure:
					a_effacer[p] = true

	if a_poser.is_empty() and a_effacer.is_empty():
		_dire("[i]Rien à faire à l'étage y = %d.[/i]\n\n%s" % [_etage,
			"L'étage est vide, ou l'opération n'a rien trouvé à changer."])
		return

	var histoire := EditorInterface.get_editor_undo_redo()
	histoire.create_action("Undermend — %s (étage %d)" % [quoi, _etage])
	for c in a_poser:
		histoire.add_do_method(cases, "set_cell_item", c, id)
		histoire.add_undo_method(cases, "set_cell_item", c, -1)
	for c in a_effacer:
		histoire.add_do_method(cases, "set_cell_item", c, -1)
		histoire.add_undo_method(cases, "set_cell_item", c, id)
	# ⚠ ET ON RECONSTRUIT DANS LES DEUX SENS : sans ça, annuler laisserait le rendu d'avant l'annulation,
	# c'est-à-dire un monde qui ne correspond plus à ses cases.
	histoire.add_do_method(massif, "reconstruire")
	histoire.add_undo_method(massif, "reconstruire")
	histoire.commit_action()

	_dire("[color=#6f9e4a][b]%s[/b][/color] à l'étage y = %d\n  %d case(s) posée(s), %d effacée(s)\n\n"
		% [quoi, _etage, a_poser.size(), a_effacer.size()]
		+ "[i]Ctrl+Z annule l'opération et le rendu avec.[/i]")
	_dire_l_etage()


func _dire(texte: String) -> void:
	if _rapport != null:
		_rapport.text = texte
