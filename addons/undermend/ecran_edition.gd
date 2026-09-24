@tool
extends Control
## L'ÉCRAN DU GREFFON — une case à cocher, trois boutons.
##
## ⚠ **IL EN CONTENAIT BEAUCOUP PLUS, ET C'ÉTAIT LE DÉFAUT** (Jordan, 24 septembre 2026) : deux onglets,
## une vue 3D orbitale avec son gizmo, un catalogue de neuf blocs, un panneau d'import et de tranchage.
## Chaque pièce se justifiait seule ; ensemble elles noyaient ce qu'on veut faire. Ce qui reste est la
## BOUCLE COMPLÈTE, et rien d'autre :
##
##   1. PEINDRE       les neuf blocs du catalogue → tranchage → MeshLibrary → un MassifPeint posé ;
##   2. EXPORTER      le MasterBlockSet entier vers un dossier quelconque du disque, pour Blender ;
##   3. IMPORTER      un set sculpté depuis ce dossier, le repasser au pipeline, et peindre avec.
##
## Le troisième est le seul essai qui prouve quelque chose : si le monde peint avec l'art réimporté reste
## exact, toute la chaîne tient — export, modélisation, réimport, tranchage, classification, assemblage.
##
## ⚠ UN GREFFON D'ÉDITEUR NE SE TESTE PAS EN HEADLESS (charte §6). On vérifie qu'il COMPILE et que les
## règles qu'il appelle sont justes ; qu'il apparaisse et que les boutons agissent se juge dans l'éditeur.

const MB := preload("res://addons/undermend/marching_blocks.gd")
const BlocsMaitres := preload("res://addons/undermend/blocs_maitres.gd")

## ⚠ Deux chemins distincts : confondre le lot de production et le lot d'essai ferait peindre un monde
## de test en croyant peindre le vrai.
const LOT_PLEIN := "res://ART/marching_blocks_9.tres"
const LOT_MOITIE := "res://ART/marching_blocks_moitie.tres"

const OR := Color("#ebbb69")

var _moitie := false
var _rapport: RichTextLabel
var _dialogue: EditorFileDialog
## Ce que le dialogue de dossier doit faire au retour : "exporter" ou "importer".
var _action := ""

## L'étage sur lequel portent les opérations. ⚠ Un étage, et pas une sélection : `GridMap` n'expose
## aucune notion de sélection au script (mesuré, `DEV_TOOLS/sonde_api_editeur.gd`).
var _etage := 0
var _etiquette_etage: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if get_child_count() > 0:
		return  # déjà bâti (le greffon peut nous ré-ajouter à l'arbre)
	_batir()


func _batir() -> void:
	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	for cote in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		marge.add_theme_constant_override(cote, 12)
	add_child(marge)

	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 10)
	marge.add_child(colonne)

	var titre := Label.new()
	titre.text = "Undermend — tuiles 3D"
	titre.add_theme_font_size_override("font_size", 18)
	titre.add_theme_color_override("font_color", OR)
	colonne.add_child(titre)

	var bascule := CheckBox.new()
	bascule.text = "tuiles ramenées à la moitié de la case"
	bascule.tooltip_text = ("Les faces qui donnent sur du VIDE rentrent d'un quart de case, avant le "
		+ "tranchage.\nUne face partagée entre deux cases pleines reste intacte : le massif garde ses "
		+ "formes.")
	bascule.toggled.connect(func(oui): _moitie = oui)
	colonne.add_child(bascule)

	var peindre := Button.new()
	peindre.text = "Peindre un massif"
	peindre.tooltip_text = "Les neuf blocs du catalogue, passés par tout le pipeline."
	peindre.custom_minimum_size = Vector2(260, 36)
	peindre.pressed.connect(func(): _peindre_avec(BlocsMaitres.librairie(_moitie),
		LOT_MOITIE if _moitie else LOT_PLEIN, "catalogue"))
	colonne.add_child(peindre)

	colonne.add_child(HSeparator.new())

	var exporter := Button.new()
	exporter.text = "Exporter le MasterBlockSet…"
	exporter.tooltip_text = ("Écrit les neuf blocs dans UN SEUL .glb, alignés sur une bande, pour les "
		+ "modéliser et texturer dans Blender.\n"
		+ "⚠ Ne DÉPLACE aucun bloc : c'est sa position qui l'identifie au retour, pas son nom.\n"
		+ "Tuiles déjà ramenées à la moitié de leur case, pour montrer la marge disponible.")
	exporter.custom_minimum_size = Vector2(300, 36)
	exporter.pressed.connect(func(): _demander_un_fichier("exporter"))
	colonne.add_child(exporter)

	var importer := Button.new()
	importer.text = "Importer un MasterBlockSet et peindre…"
	importer.tooltip_text = ("Relit le .glb sculpté, redécoupe chaque bloc par sa position, le repasse "
		+ "au pipeline, et pose un massif peint avec.\n⚠ Un bloc dont la boîte ressort vide garde sa "
		+ "version calculée, et c'est DIT — jamais en silence.")
	importer.custom_minimum_size = Vector2(300, 36)
	importer.pressed.connect(func(): _demander_un_fichier("importer"))
	colonne.add_child(importer)

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
	_rapport.size_flags_vertical = Control.SIZE_EXPAND_FILL
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

	var dehors: int = MB.classes_exterieures().size()
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
	# ⚠ ON LE DIT PLUTÔT QUE DE LE CACHER : 33 des 68 classes SONT des contacts diagonaux, donc un
	# témoin complet contient nécessairement quelques arêtes non-manifold. Mesuré : 18 sur 8 364 quads.
	texte += ("\n[i]Passe-le en quads (Alt+J) : les boucles d'arêtes deviennent continues. Quelques "
		+ "arêtes restent ambiguës, là où deux cases ne se touchent que par un coin — c'est le modèle, "
		+ "pas un défaut du fichier.[/i]")
	_dire(texte)


# ── 2. IMPORTER ET PEINDRE ──────────────────────────────────────────────────────────────────────────

func _importer(fichier: String) -> void:
	var bilan: Dictionary = BlocsMaitres.librairie_depuis_glb(fichier, _moitie)
	var entete := "[b]Set importé depuis[/b] %s\n" % fichier
	var sculptes: Array = bilan["sculptes"]
	var absents: Array = bilan["absents"]
	entete += "[color=#6f9e4a]%d bloc(s) SCULPTÉ(S) relu(s)[/color]" % sculptes.size()
	if not sculptes.is_empty():
		entete += " : %s" % ", ".join(PackedStringArray(sculptes))
	entete += "\n"
	if not absents.is_empty():
		# ⚠ ON LE DIT. Sans ça, on croirait peindre avec son art alors qu'on peint avec le témoin.
		entete += "[color=#e0b84a]⚠ %d bloc(s) ABSENT(S) du dossier, version calculée gardée :[/color] %s\n" \
			% [absents.size(), ", ".join(PackedStringArray(absents))]
	_peindre_avec(bilan, "", "import", entete)


# ── le tronc commun ─────────────────────────────────────────────────────────────────────────────────

## Pose un `MassifPeint` câblé sur `bilan["lot"]`, et DIT tout ce que le bilan contient.
##
## ⚠ PARTAGÉ par les deux chemins de peinture : deux copies de cette pose auraient divergé, et l'une des
## deux aurait fini par oublier l'historique d'annulation ou le `preparer()`.
func _peindre_avec(bilan: Dictionary, chemin_du_lot: String, quoi: String, entete := "") -> void:
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

	# ⚠ PAR L'HISTORIQUE : un bouton qui ajoute un nœud sans que Ctrl+Z le reprenne laisse traîner des
	# massifs qu'on n'a pas demandés (charte §6, même règle que le bouton « Falaises »).
	var histoire := EditorInterface.get_editor_undo_redo()
	histoire.create_action("Poser un massif à peindre")
	histoire.add_do_method(racine, "add_child", noeud, true)
	# ⚠ L'ORDRE COMPTE : le parent prend son propriétaire d'abord, les enfants ensuite.
	histoire.add_do_method(noeud, "set_owner", racine)
	for enfant in noeud.get_children():
		histoire.add_do_method(enfant, "set_owner", racine)
	histoire.add_do_reference(noeud)
	histoire.add_undo_method(racine, "remove_child", noeud)
	histoire.commit_action()

	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(noeud)

	var texte := entete
	texte += "[color=#6f9e4a][b]Massif posé[/b][/color] (%s) — %d item(s) sur %d classes%s\n" \
		% [quoi, lot.get_item_list().size(), MB.pieces_a_sculpter().size(),
			"  ·  tuiles à la MOITIÉ" if _moitie else ""]
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
