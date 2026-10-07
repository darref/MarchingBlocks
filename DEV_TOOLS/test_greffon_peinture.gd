extends SceneTree
##
## TEST — le format neutre et le greffon Godot gratuit qui le lit (`addons/marchingblocks_paint/`).
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_greffon_peinture.gd
##
## ⚠ **DEUX IMPLÉMENTATIONS, UN ATTENDU.** La référence est `MB.poses()` — la règle que le peintre de
## l'appli applique. Le greffon, lui, ne charge RIEN du cœur : il réimplémente la règle depuis le TEXTE
## du format (`mb_rule.gd`). Les cas d'épreuve les confrontent ; c'est ce qui rendra visible la moindre
## divergence, et ce que les greffons Unity et Unreal devront passer à leur tour.
## ⚠ **UN CAS QUI N'EXERCE RIEN NE GARDE RIEN** (charte §6) : on vérifie aussi que les cas posent
## vraiment des tuiles d'air libre et des marqueurs d'erreur.

const FN := preload("res://addons/marchingblocks_core/format_neutre.gd")
const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const Rule := preload("res://addons/marchingblocks_paint/mb_rule.gd")
const Tileset := preload("res://addons/marchingblocks_paint/mb_tileset.gd")
const Tools := preload("res://addons/marchingblocks_paint/mb_tools.gd")
const Shapes := preload("res://addons/marchingblocks_paint/mb_shapes.gd")
const Editeur := preload("res://addons/marchingblocks_paint/mb_editor.gd")
const World := preload("res://addons/marchingblocks_paint/mb_world.gd")
const CAS := "res://addons/marchingblocks_paint/conformance.json"
const GENERATEUR := preload("res://DEV_TOOLS/generer_cas_d_epreuve.gd")
const EO := preload("res://addons/marchingblocks_core/epreuve_outils.gd")
const FS := preload("res://addons/marchingblocks_core/formes_speciales.gd")
const FM := preload("res://addons/marchingblocks_core/format_monde.gd")
const WorldFile := preload("res://addons/marchingblocks_paint/mb_world_file.gd")
const GENERATEUR_ICONES := preload("res://DEV_TOOLS/generer_icones_greffons.gd")
const GENERATEUR_SHADERS := preload("res://DEV_TOOLS/generer_shaders_greffon.gd")
const FL := preload("res://addons/marchingblocks_core/fluides.gd")
const EM := preload("res://addons/marchingblocks_core/eau_maillage.gd")
const TR := preload("res://addons/marchingblocks_core/transitions.gd")
const FE := preload("res://addons/marchingblocks_core/feuillage.gd")
const Shaders := preload("res://addons/marchingblocks_paint/mb_shaders.gd")
const Anim := preload("res://addons/marchingblocks_paint/mb_animation.gd")
const Trans := preload("res://addons/marchingblocks_paint/mb_transitions.gd")
const Foliage := preload("res://addons/marchingblocks_paint/mb_foliage.gd")
const Water := preload("res://addons/marchingblocks_paint/mb_water.gd")
const WaterMesh := preload("res://addons/marchingblocks_paint/mb_water_mesh.gd")
const Sac := preload("res://DEV_TOOLS/eau_sac.gd")
const WaterNode := preload("res://addons/marchingblocks_paint/mb_water_node.gd")

var _ok := 0
var _echecs := 0
## La barre est allée jusqu'au bout : lu dans `_de_bout_en_bout`, qui tourne APRÈS elle.
var _barre_finie := false


func _initialize() -> void:
	print("=== TEST — le format neutre et le greffon de peinture Godot ===\n")
	_les_noms()
	_les_quarts_de_tour()
	var cas: Dictionary = _les_cas_livres_sont_a_jour()
	if not cas.is_empty():
		_le_greffon_passe_les_cas(cas)
		_le_greffon_passe_les_cas_en_couches(cas)
		_le_greffon_passe_les_cas_a_variantes(cas)
	_un_format_plus_recent_est_refuse()
	_les_cas_d_outils()
	_le_greffon_passe_les_cas_d_outils()
	_le_greffon_passe_les_cas_de_parite()
	_le_sac_est_eprouve()
	_la_reprise_egale_le_calcul_entier()
	_deux_rivieres_au_meme_endroit()
	_les_shaders_livres_sont_a_jour()
	_les_cas_de_monde()
	_les_icones_livrees_sont_a_jour()
	_la_barre_ne_montre_que_l_utile()
	_de_bout_en_bout.call_deferred()


# ── 1. Les noms qui sortent ─────────────────────────────────────────────────────────────────────────
func _les_noms() -> void:
	var vus := {}
	var mauvais: Array = []
	var regex := RegEx.create_from_string("^[a-z0-9_]+$")
	for c in MB.classes():
		for cle in [c["nom"], MB.nom_en_contexte(c["nom"], true)]:
			var id: String = FN.id_de_cle(cle)
			if regex.search(id) == null:
				mauvais.append(id)
			if vus.has(id) and vus[id] != cle:
				mauvais.append("%s (porté par %s ET %s)" % [id, vus[id], cle])
			vus[id] = cle
	_vrai(mauvais.is_empty(), "des ids sortent hors de [a-z0-9_] ou en double : %s" % str(mauvais.slice(0, 5)))
	_egal(FN.id_de_cle("mb_arete_creuse_b2h2_dehors"), "edge_inner_b2h2_outdoor", "la traduction, écrite à la main")
	_egal(FN.nom_de_tuile("mb_coin_b1h0"), "corner_b1h0", "une tuile par clé : son nom est l'id de la clé")
	# ⚠ UNE TUILE PAR CLÉ (charte §3, 30 septembre 2026) : ni champ `copies`, ni étape « Copy » dans la règle.
	var regle: Dictionary = FN.regle_du_format()
	_vrai(not regle.has("copies"), "le format ne porte plus de champ « copies »")
	# ⚠ LE HACHAGE N'EST PLUS QUE CELUI DES VARIANTES VOULUES (l'étape 8, 5 octobre 2026) : jamais avant elle.
	var copie := false
	var etape_8 := false
	for ligne in FN.regle():
		etape_8 = etape_8 or ligne.begins_with("8. Variants")
		if ligne.contains("Copy") or (ligne.contains("73856093") and not etape_8):
			copie = true
	_vrai(not copie, "la règle écrite ne tire plus de copie par hachage (le hachage n'est que celui de l'étape 8)")


# ── 2. Les quarts de tour — mesurés contre la base, pas recopiés ─────────────────────────────────────
func _les_quarts_de_tour() -> void:
	# Mesuré le 27 septembre 2026 : index 0, 16, 10, 22 → 0, 1, 2, 3. Et le sens se vérifie sur un vecteur :
	# un quart de tour, main droite autour de +Y, envoie +Z sur +X.
	var g := GridMap.new()
	var b: Basis = g.get_basis_with_orthogonal_index(16)
	g.free()
	_vrai((b * Vector3(0, 0, 1)).is_equal_approx(Vector3(1, 0, 0)), "l'index 16 n'envoie pas +Z sur +X")
	_egal([FN.quarts_de_tour(0), FN.quarts_de_tour(16), FN.quarts_de_tour(10), FN.quarts_de_tour(22)],
		[0, 1, 2, 3], "les quarts de tour des quatre rotations du groupe")
	var hors := 0
	for e in FN.table():
		if e[0] >= 0 and (e[1] < 0 or e[1] > 3):
			hors += 1
	_egal(hors, 0, "entrées de la table sans quart de tour valable")


# ── 3. Le fichier livré avec le greffon est celui que la référence produit AUJOURD'HUI ──────────────
func _les_cas_livres_sont_a_jour() -> Dictionary:
	if not FileAccess.file_exists(CAS):
		_vrai(false, "conformance.json n'est pas livré avec le greffon")
		return {}
	var frais = JSON.parse_string(JSON.stringify(FN.cas_d_epreuve()))
	# ⚠ CHAQUE GREFFON reçoit sa copie : une copie oubliée ferait passer un greffon sur de vieux cas.
	for cible in GENERATEUR.CIBLES:
		var ici = JSON.parse_string(FileAccess.get_file_as_string(cible)) if FileAccess.file_exists(cible) else null
		_vrai(ici != null and JSON.stringify(ici) == JSON.stringify(frais),
			"%s est absent ou PÉRIMÉ : relancer DEV_TOOLS/generer_cas_d_epreuve.gd" % cible)
	return JSON.parse_string(FileAccess.get_file_as_string(CAS))


# ── 3 bis. Les icônes des trois greffons sont celles de l'appli, AUJOURD'HUI ──────────────────────────
# ⚠ Même parade que pour les cas : une icône retouchée dans `app/icones.gd` sans relancer le générateur
# laisserait trois greffons dessiner autre chose que le logiciel.
func _les_icones_livrees_sont_a_jour() -> void:
	var frais: Dictionary = GENERATEUR_ICONES.sorties()
	_vrai(not frais.has("erreur"), "générateur d'icônes : %s" % str(frais.get("erreur", "")))
	if frais.has("erreur"):
		return
	var perimes: Array = []
	for chemin in frais:
		var ici := FileAccess.get_file_as_bytes(chemin) if FileAccess.file_exists(chemin) else PackedByteArray()
		if ici != frais[chemin]:
			perimes.append(chemin)
	_vrai(perimes.is_empty(), "icônes absentes ou PÉRIMÉES : relancer DEV_TOOLS/generer_icones_greffons.gd — %s"
		% str(perimes.slice(0, 3)))
	# ⚠ ET CHAQUE ICÔNE DEMANDÉE PAR UN GREFFON EXISTE : un nom mal tapé rendrait un bouton vide, sans erreur
	# à la compilation. Lu dans le TEXTE des sources, pas supposé.
	var Icons: GDScript = load("res://addons/marchingblocks_paint/mb_icons.gd")
	var connues: Dictionary = Icons.STROKES
	var inconnues: Array = []
	var motifs := {
		"res://addons/marchingblocks_paint/mb_toolbar.gd": [r'(?:_toggle|_button|_menu)\([^,]+, "([a-z_]+)"',
			r'Icons\.icon\("([a-z_]+)"'],
		"res://engines/unity/com.marchingblocks.paint/Editor/MarchingBlocksWorldEditor.cs": [r'Icon\("([a-z_]+)"'],
		"res://engines/unreal/MarchingBlocksPaint/Source/MarchingBlocksPaintEditor/Private/MarchingBlocksModeToolkit.cpp":
			[r'(?:Toggle|Button|Op|Icon)\("([a-z_]+)"'],
	}
	var vus := 0
	for f in motifs:
		var texte := FileAccess.get_file_as_string(f)
		_vrai(texte != "", "%s est illisible" % f)
		for m in motifs[f]:
			for r in RegEx.create_from_string(m).search_all(texte):
				vus += 1
				if not connues.has(r.get_string(1)):
					inconnues.append("%s : %s" % [f.get_file(), r.get_string(1)])
	_vrai(inconnues.is_empty(), "des greffons demandent des icônes qui n'existent pas : %s" % str(inconnues))
	# LES BOUTONS NEUFS DE LA PARITÉ ONT LEUR ICÔNE DANS LES TROIS BARRES (finitions, 7 octobre 2026) : Facing, Widen,
	# Plant — plus de bouton en texte. Lu dans le texte : chaque source demande les trois noms, et aucune ne garde le
	# bouton texte d'avant.
	var demandes := {
		"res://addons/marchingblocks_paint/mb_toolbar.gd": [r'\["facing", "facing"', r'\["widen", "widen"',
			r'\["plant", "Plant"', r'_menu\(_plant_bar, "plant"'],
		"res://engines/unity/com.marchingblocks.paint/Editor/MarchingBlocksWorldEditor.cs": [r'Icon\("facing"',
			r'Icon\("widen"', r'Icon\("plant"'],
		"res://engines/unreal/MarchingBlocksPaint/Source/MarchingBlocksPaintEditor/Private/MarchingBlocksModeToolkit.cpp":
			[r'ExtrudeOp\("facing"', r'Op\("widen"', r'ToolToggle\("plant"'],
	}
	var texte_avant := [r'GUIContent\("(Facing|Widen|Plant)"', r'TextButton\(', r'\["move", "facing"']
	for f in demandes:
		var texte := FileAccess.get_file_as_string(f)
		for m in demandes[f]:
			_vrai(RegEx.create_from_string(m).search(texte) != null, "%s ne demande pas l'icône : %s" % [f.get_file(), m])
		for m in texte_avant:
			_vrai(RegEx.create_from_string(m).search(texte) == null, "%s garde un bouton en texte : %s" % [f.get_file(), m])
	# Un motif qui ne trouve rien ne garde rien : les trois sources doivent en demander.
	_vrai(vus >= 60, "les icônes demandées n'ont pas été trouvées dans les sources (%d)" % vus)
	for nom in connues:
		_vrai(Icons.icon(nom) != null, "l'icône « %s » ne se rend pas dans Godot" % nom)


# ── 3 ter. La barre de Godot ne montre que ce que l'outil courant utilise ────────────────────────────
# Comme la barre de droite de l'appli (`_contexte()`) : le pinceau pour Add · Dig · Select, Hollow pour la
# Box, la sélection quand il y en a une, Paste quand le presse-papiers est plein. ⚠ `EditorPlugin` ne
# s'instancie pas hors de l'éditeur : c'est pourquoi la barre vit dans son propre script, `mb_toolbar.gd`,
# qui ne demande rien à l'éditeur.
func _la_barre_ne_montre_que_l_utile() -> void:
	var Barre: GDScript = load("res://addons/marchingblocks_paint/mb_toolbar.gd")
	# ⚠ UNE ERREUR D'EXÉCUTION ABANDONNE LA FONCTION EN SILENCE (charte §6) : chaque étape qui peut rendre
	# nul est vérifiée, et la dernière ligne pose une SENTINELLE.
	if Barre == null or not Barre.can_instantiate():
		_vrai(false, "mb_toolbar.gd ne compile pas")
		return
	var ed: Node = Editeur.new()
	var barre: HBoxContainer = Barre.new()
	barre.set("editor", ed)
	var vus := func(nom: String) -> bool: return (barre.get(nom) as Control).visible
	var etat := func(mode: String) -> String:
		ed.mode = mode
		ed.changed.emit()
		return "%s %s" % [vus.call("_brush"), vus.call("_hollow")]
	_egal(etat.call("add"), "true false", "Add : le pinceau, pas Hollow")
	_egal(etat.call("select"), "true false", "Select : le pinceau, pas Hollow")
	_egal(etat.call("rect"), "false false", "Rect : ni pinceau ni Hollow")
	_egal(etat.call("box"), "false true", "Box : Hollow, pas de pinceau")
	_vrai(not vus.call("_selection_bar") and not vus.call("_paste"), "rien de sélectionné ni copié : ni sélection ni Paste")
	# LA PARITÉ (7 octobre 2026) : « Select empty cells too » sous Select seulement ; Extrude ↑ ↓ face avec un outil de
	# sélection, ou dès qu'il y a une sélection (sans elle, il agit sur la matière de l'étage).
	ed.mode = "select"
	ed.changed.emit()
	_vrai(vus.call("_select_empty") and vus.call("_extrude_bar"), "Select : la case des cases vides, et Extrude")
	ed.mode = "add"
	ed.changed.emit()
	_vrai(not vus.call("_select_empty") and not vus.call("_extrude_bar"), "Add sans sélection : ni l'une ni l'autre")
	(barre.get("_select_empty") as Button).set_pressed_no_signal(true)
	(barre.get("_select_empty") as Button).pressed.emit()
	_vrai(ed.select_empty, "la case coche « Select empty cells too » dans l'éditeur")
	ed.selection = {Vector3i.ZERO: true, Vector3i.ONE: true}
	ed.clipboard = [Vector3i.ZERO] as Array[Vector3i]
	ed.changed.emit()
	_vrai(vus.call("_selection_bar") and vus.call("_paste"), "une sélection et une copie : la sélection et Paste apparaissent")
	_egal((barre.get("_selected") as Label).text, "2 selected", "le compte de la sélection")
	# L'état se lit dans les boutons : la visée, l'outil, la forme, la taille.
	ed.aim = "sculpt"
	ed.shape = "disc"
	ed.brush_size = 5
	ed.mode = "dig"
	ed.changed.emit()
	_vrai((barre.get("_aim_buttons")["sculpt"] as Button).button_pressed
		and not (barre.get("_aim_buttons")["grid"] as Button).button_pressed, "la visée enfoncée est Sculpt")
	_vrai((barre.get("_mode_buttons")["dig"] as Button).button_pressed
		and not (barre.get("_mode_buttons")["box"] as Button).button_pressed, "l'outil enfoncé est Dig")
	_vrai((barre.get("_shape_buttons")["disc"] as Button).button_pressed, "la forme enfoncée est Disc")
	_egal((barre.get("_size_value") as Label).text, "5", "la taille du pinceau")
	# Et la barre MÈNE l'éditeur : un clic sur un bouton change l'outil.
	(barre.get("_mode_buttons")["rect"] as Button).pressed.emit()
	_egal(ed.mode, "rect", "un clic sur Rect choisit Rect")
	# LES FORMES SPÉCIALES (1er octobre 2026) : un bouton les choisit, et la barre ne montre que ce que la forme
	# lit — le profil pour tunnel et puits, le rebord pour pont et balcon, la longueur hors d'un Connect.
	_vrai(not vus.call("_shape_bar"), "Rect : pas de réglages de forme")
	(barre.get("_special_buttons")["bridge"] as Button).pressed.emit()
	_vrai(ed.mode == "shape" and ed.special == "bridge", "un clic sur Bridge choisit la forme")
	_vrai((barre.get("_special_buttons")["bridge"] as Button).button_pressed
		and not (barre.get("_mode_buttons")["rect"] as Button).button_pressed, "Bridge enfoncé, Rect relâché")
	_vrai(vus.call("_shape_bar") and not vus.call("_profile_bar") and vus.call("_rail") and not vus.call("_brush"),
		"Bridge : ses réglages et le rebord, sans profil ni pinceau")
	(barre.get("_special_buttons")["tunnel"] as Button).pressed.emit()
	_vrai(vus.call("_profile_bar") and not vus.call("_rail"), "Tunnel : le profil, sans rebord")
	(barre.get("_profile_buttons")["arch"] as Button).pressed.emit()
	_egal(ed.profile, "arch", "un clic sur Arch choisit le profil")
	(barre.get("_ends_buttons")["connect"] as Button).pressed.emit()
	_vrai(ed.connect_ends and not vus.call("_shape_length"), "Connect : deux clics, plus de longueur")
	(barre.get("_special_buttons")["balcony"] as Button).pressed.emit()
	_vrai(not (barre.get("_ends_buttons")["connect"] as Button).visible and vus.call("_shape_length"),
		"Balcony : un clic seulement, une profondeur")
	ed.set_mode("add")
	var sans_icone := 0
	var boutons := 0
	for b in barre.find_children("*", "Button", true, false):
		boutons += 1
		if (b as Button).icon == null:
			sans_icone += 1
	_egal(sans_icone, 0, "boutons de la barre sans icône")
	_vrai(boutons >= 25, "la barre porte %d boutons, on en attend au moins 25" % boutons)
	barre.free()
	ed.free()
	_barre_finie = true


## Ce qu'une grille Tiles pose : {sommet: [nom, quarts]}.
func _poses_de(monde: Node3D) -> Dictionary:
	var tuiles := monde.get_node("Tiles") as GridMap
	var lib: MeshLibrary = tuiles.mesh_library
	var d := {}
	for v in tuiles.get_used_cells():
		var q := -1
		for k in 4:
			if tuiles.get_orthogonal_index_from_basis(Basis(Vector3.UP, k * PI / 2.0)) == tuiles.get_cell_item_orientation(v):
				q = k
		d[v] = [lib.get_item_name(tuiles.get_cell_item(v)), q]
	return d


func _attendues(liste: Array) -> Dictionary:
	var d := {}
	for e in liste:
		if e[3] != null:
			d[Vector3i(e[0], e[1], e[2])] = [e[3], e[4]]
	return d


## DEUX MarchingBlocksWorld FRÈRES = DEUX COUCHES D'UN MONDE (couches exclusives, 2 octobre 2026). L'attendu vient du
## CŒUR (`FormatNeutre.attendu_en_couches`, sur `MB.poses_en_couches`), jamais du greffon.
func _deux_couches(jeu: String, comptes: Dictionary) -> void:
	var tenant := Node3D.new()
	root.add_child(tenant)
	var a: Node3D = World.new()
	var b: Node3D = World.new()
	tenant.add_child(a)
	tenant.add_child(b)
	var cases_a := {}
	var cases_b := {}
	for x in range(0, 6):
		for y in 2:
			for z in 6:
				cases_a[Vector3i(x, y, z)] = true
	for x in range(6, 10):
		for y in 3:
			for z in 6:
				cases_b[Vector3i(x, y, z)] = true
	a.apply_cells(cases_a.keys(), [])
	b.apply_cells(cases_b.keys(), [])
	a.tileset = jeu
	b.tileset = jeu
	var attendu: Array = FN.attendu_en_couches([{"cells": cases_a.keys(), "cles": comptes, "visible": true},
		{"cells": cases_b.keys(), "cles": comptes, "visible": true}])
	_egal(_poses_de(a), _attendues(attendu[0]), "deux couches : la première pose ce que pose MarchingBlocks")
	_egal(_poses_de(b), _attendues(attendu[1]), "… et la seconde aussi")
	var seule: Array = FN.attendu(cases_a, comptes)
	_vrai(_attendues(seule) != _attendues(attendu[0]), "contrôle : seule, la première poserait autre chose (sa paroi à la frontière)")
	# UNE CASE N'APPARTIENT QU'À UNE COUCHE : un geste de l'éditeur dans B prend la case à A ; Ctrl+Z la rend.
	var ed: Node = Editeur.new()
	root.add_child(ed)
	var annul := UndoRedo.new()
	ed.undo = annul
	ed.world = b
	var prise := Vector3i(5, 0, 0)
	ed._commit("prise", {prise: true}, {})
	_vrai(not a.cells().has(prise) and b.cells().has(prise), "peindre dans B une case de A la prend à A")
	attendu = FN.attendu_en_couches([{"cells": a.cells().keys(), "cles": comptes, "visible": true},
		{"cells": b.cells().keys(), "cles": comptes, "visible": true}])
	_egal(_poses_de(a), _attendues(attendu[0]), "… et A se refait avec (la frontière a bougé)")
	annul.undo()
	_vrai(a.cells().has(prise) and not b.cells().has(prise), "Ctrl+Z rend la case à A")
	_egal(_poses_de(a), _attendues(FN.attendu_en_couches([{"cells": cases_a.keys(), "cles": comptes, "visible": true},
		{"cells": cases_b.keys(), "cles": comptes, "visible": true}])[0]), "… et A se refait comme avant")
	annul.redo()
	_vrai(not a.cells().has(prise), "Ctrl+Y la reprend")
	annul.undo()
	# Le COUP de pinceau : déjà appliqué, enregistré sans être rejoué — ce qu'il a pris doit revenir aussi.
	var pris: Dictionary = b.apply_cells([prise], [])
	_vrai(pris.has(a) and (pris[a] as Array) == [prise], "apply_cells rend ce qu'il a pris, couche par couche")
	ed._record("coup", {prise: true}, {}, false, 0, {a: {prise: true}})
	annul.undo()
	_vrai(a.cells().has(prise) and not b.cells().has(prise), "Ctrl+Z d'un coup rend aussi la case prise")
	# UNE COUCHE CACHÉE sort du monde : B se referme sans elle, et A ne pose plus rien.
	a.visible = false
	a.rebuild()
	b.rebuild()
	_egal(_poses_de(b), _attendues(FN.attendu(cases_b, comptes)), "A cachée : B pose ce qu'elle poserait seule")
	_egal((a.get_node("Tiles") as GridMap).get_used_cells().size(), 0, "A cachée ne pose rien")
	ed.queue_free()
	tenant.queue_free()


# ── 4 bis. Les mondes de PLUSIEURS COUCHES (couches exclusives, 2 octobre 2026) ──────────────────────────
## ⚠ L'attendu vient de `MB.poses_en_couches` (le cœur) ; le greffon le réimplémente depuis le texte du format.
## Les cas doivent EXERCER ce qu'ils nomment : chaque couche seule (l'ancienne règle) rendrait autre chose, une couche
## cachée ne pose rien, et inverser la priorité change les poses.
func _le_greffon_passe_les_cas_en_couches(cas: Dictionary) -> void:
	var lc: Array = cas.get("layered_cases", [])
	_vrai(lc.size() >= 5, "conformance.json porte les cas multicouches (%d)" % lc.size())
	var differe_seule := 0
	var cachee_vide := false
	var poses_par_cas := []
	for c in lc:
		var couches: Array = []
		for l in c["layers"]:
			var cells := {}
			for p in l["cells"]:
				cells[Vector3i(int(p[0]), int(p[1]), int(p[2]))] = true
			var choix := {}
			for q in range(0, (l.get("variant_choices", []) as Array).size(), 4):
				choix[Vector3i(int(l["variant_choices"][q]), int(l["variant_choices"][q + 1]),
					int(l["variant_choices"][q + 2]))] = int(l["variant_choices"][q + 3])
			couches.append({"cells": cells, "tiles": cas["tilesets"][l["tileset"]], "visible": l["visible"],
				"variants": cas.get("tileset_variants", {}).get(l["tileset"], {}),
				"weights": l.get("variant_weights", {}), "choices": choix})
		var obtenu: Array = Rule.placements_layered(couches, cas)
		var attendu: Array = []
		for e in c["expected"]:
			var une: Array = []
			for q in e:
				une.append([int(q[0]), int(q[1]), int(q[2]), q[3], int(q[4])])
			attendu.append(une)
		_vrai(obtenu == attendu, "« %s » : le greffon pose, couche par couche, ce que pose MarchingBlocks" % c["name"])
		poses_par_cas.append(attendu)
		for i in couches.size():
			if not couches[i]["visible"]:
				cachee_vide = cachee_vide or (attendu[i] as Array).is_empty()
			elif Rule.placements(couches[i]["cells"], cas, couches[i]["tiles"], couches[i]["variants"],
					couches[i]["weights"], couches[i]["choices"]) != attendu[i]:
				differe_seule += 1
	_vrai(differe_seule >= 4, "les cas exercent l'union : %d couche(s) posent autre chose que seules" % differe_seule)
	_vrai(cachee_vide, "un cas a une couche cachée, et elle ne pose rien")
	_vrai(poses_par_cas.size() >= 2 and poses_par_cas[0] != [poses_par_cas[1][1], poses_par_cas[1][0]],
		"inverser la priorité change les poses (la frontière change de couche)")


# ── 4 bis. Les variantes (étape 8, portées dans les greffons le 5 octobre 2026) ─────────────────────────
# ⚠ LES CAS EXERCENT L'ÉTAPE 8 : des variantes posées par le tirage, la base aussi, un choix suivi, des poids qui
# changent les poses — et sans les variantes, le greffon poserait AUTRE CHOSE (sinon ces cas ne garderaient rien).
func _le_greffon_passe_les_cas_a_variantes(cas: Dictionary) -> void:
	var vc: Array = cas.get("variant_cases", [])
	var variants: Dictionary = cas.get("tileset_variants", {}).get("varied", {})
	_vrai(vc.size() >= 6 and variants.size() >= 3, "conformance.json porte les cas à variantes (%d cas, %d clés)"
		% [vc.size(), variants.size()])
	var en_variante := 0
	var sans_compte := 0
	var poses := 0
	for c in vc:
		var cells := {}
		for p in c["cells"]:
			cells[Vector3i(int(p[0]), int(p[1]), int(p[2]))] = true
		var choix := {}
		var plat: Array = c["variant_choices"]
		for q in range(0, plat.size(), 4):
			choix[Vector3i(int(plat[q]), int(plat[q + 1]), int(plat[q + 2]))] = int(plat[q + 3])
		var tiles: Dictionary = cas["tilesets"]["varied"]
		var obtenu: Array = Rule.placements(cells, cas, tiles, variants, c["variant_weights"], choix)
		var attendu: Array = []
		for e in c["expected"]:
			attendu.append([int(e[0]), int(e[1]), int(e[2]), e[3], int(e[4])])
			poses += 1
			if e[3] != null and str(e[3]).contains("_var"):
				en_variante += 1
		_vrai(obtenu == attendu, "« %s » : le greffon pose les variantes que pose MarchingBlocks" % c["name"])
		if Rule.placements(cells, cas, tiles) != attendu:
			sans_compte += 1
	print("  cas à variantes : %d cas, %d poses, %d en variante" % [vc.size(), poses, en_variante])
	_vrai(en_variante > 0 and en_variante < poses, "les cas posent des variantes ET des bases")
	_vrai(sans_compte == vc.size(), "sans l'étape 8, chaque cas poserait autre chose (%d sur %d)" % [sans_compte, vc.size()])


# ── 4. Le greffon reproduit chaque cas, à 100 % ─────────────────────────────────────────────────────
func _le_greffon_passe_les_cas(cas: Dictionary) -> void:
	var dehors := 0
	var marqueurs := 0
	var hors_du_jeu := 0
	var total := 0
	for c in cas["cases"]:
		var cells := {}
		for p in c["cells"]:
			cells[Vector3i(int(p[0]), int(p[1]), int(p[2]))] = true
		var obtenu: Array = Rule.placements(cells, cas, cas["tilesets"][c["tileset"]])
		var attendu: Array = []
		for e in c["expected"]:
			attendu.append([int(e[0]), int(e[1]), int(e[2]), e[3], int(e[4])])
		total += attendu.size()
		var premier := ""
		for i in maxi(attendu.size(), obtenu.size()):
			var a = attendu[i] if i < attendu.size() else null
			var o = obtenu[i] if i < obtenu.size() else null
			if a != o:
				premier = "au rang %d : attendu %s, le greffon rend %s" % [i, str(a), str(o)]
				break
		_vrai(premier == "", "« %s » — %s" % [c["name"], premier])
		# Chaque tuile attendue est LA tuile d'une clé du jeu (une par clé) : aucun autre nom ne peut sortir.
		var noms := {}
		for k in cas["tilesets"][c["tileset"]]:
			noms[cas["tilesets"][c["tileset"]][k]] = true
		for e in attendu:
			if e[3] == null:
				marqueurs += 1
			else:
				if not noms.has(e[3]):
					hors_du_jeu += 1
				if str(e[3]).contains("_outdoor"):
					dehors += 1
	print("  cas d'épreuve : %d cas, %d poses — %d d'air libre, %d marqueurs"
		% [(cas["cases"] as Array).size(), total, dehors, marqueurs])
	_vrai(dehors > 0, "aucun cas ne pose de tuile d'air libre : le contexte n'est pas éprouvé")
	_egal(hors_du_jeu, 0, "tuiles attendues qui ne sont LA tuile d'aucune clé du jeu")
	_vrai(marqueurs > 0, "aucun cas ne demande de tuile absente : le marqueur n'est pas éprouvé")


func _un_format_plus_recent_est_refuse() -> void:
	var regle := FN.regle_du_format()
	regle["version"] = FN.VERSION + 1
	_vrai(Rule.check(regle) != "", "un manifeste d'un format PLUS RÉCENT est accepté")
	regle["version"] = FN.VERSION
	_egal(Rule.check(regle), "", "un manifeste du format courant est refusé")
	# ⚠ UNE TUILE PAR CLÉ (charte §3) : un manifeste qui porte encore une LISTE de copies par clé (le brouillon
	# du 27 au 30 septembre 2026) est refusé en le disant, jamais lu de travers.
	regle["tiles"] = {"corner_b1h0": ["corner_b1h0", "corner_b1h0_2"]}
	_vrai(Rule.check(regle).contains("one tile per key"), "un manifeste à listes de copies est accepté")
	regle["tiles"] = {"corner_b1h0": "corner_b1h0"}
	_egal(Rule.check(regle), "", "un manifeste à une tuile par clé est refusé")


# ── 4 bis. Les cas d'OUTILS livrés aux greffons Unity et Unreal : frais, et qui exercent quelque chose ─
#
# ⚠ **LA RÉFÉRENCE EST `outils.gd`**, que l'appli appelle : les cas sont calculés par elle. Les greffons
# les passent chacun dans leur langue (banc .NET, banc g++) ; ici on garde qu'ils ne sont pas PÉRIMÉS,
# et qu'ils éprouvent ce qu'ils nomment (charte §6 : un cas qui n'exerce rien ne garde rien).
func _les_cas_d_outils() -> void:
	var frais: Dictionary = EO.cas_d_epreuve()
	_vrai(not frais.has("erreur"), "les cas d'outils sont refusés : %s" % frais.get("erreur", ""))
	if frais.has("erreur"):
		return
	var texte := JSON.stringify(JSON.parse_string(JSON.stringify(frais)))
	for cible in GENERATEUR.CIBLES_OUTILS:
		var ici = JSON.parse_string(FileAccess.get_file_as_string(cible)) if FileAccess.file_exists(cible) else null
		_vrai(ici != null and JSON.stringify(ici) == texte,
			"%s est absent ou PÉRIMÉ : relancer DEV_TOOLS/generer_cas_d_epreuve.gd" % cible)
	var sortes := {}
	var touches := 0
	var manques := 0
	var egalite := false
	var boite_vide := false
	var creuse := false
	var operations := {}
	var biais := false
	var formes := {}
	var profils := {}
	var erreurs := {}
	var ouverts := {}
	var repares := false
	var salles := {}
	for c in frais["cases"]:
		sortes[c["kind"]] = true
		match c["kind"]:
			"ray":
				if c["expected"]["hit"]:
					touches += 1
				else:
					manques += 1
				egalite = egalite or str(c["name"]).contains("exact tie")
			"box":
				boite_vide = boite_vide or int(c["expected"]["count"]) == 0
				if c["input"]["hollow"]:
					var a: Array = c["input"]["a"]
					var b: Array = c["input"]["b"]
					var plein := 1
					for i in 3:
						plein *= absi(int(a[i]) - int(b[i])) + 1
					creuse = creuse or (int(c["expected"]["count"]) > 0 and int(c["expected"]["count"]) < plein)
			"selection":
				operations[c["input"]["op"]] = true
			"wall_normal":
				var n: Array = c["expected"]["normal"]
				biais = biais or (int(n[0]) != 0 and int(n[2]) != 0)
			"room":
				var er: Dictionary = c["expected"]
				salles[er["error"] if er["error"] != "" else ("up" if c["input"]["up"] else "down")] = true
				salles["dug"] = salles.get("dug", false) or (er["clear"] as Array).size() > 0
				salles["repaired"] = salles.get("repaired", false) or int(er["repaired"]) > 0
				salles["clamped"] = salles.get("clamped", false) or int(c["input"]["floors"]) > int(frais["limits"]["room_floors_max"])
			"special_shape":
				var e: Dictionary = c["expected"]
				formes[c["input"]["shape"] + ("+connect" if c["input"]["connect"] else "")] = true
				profils[c["input"]["profile"]] = true
				erreurs[e["error"]] = true
				ouverts[e["opened"]] = true
				repares = repares or int(e["repaired"]) > 0
	# ⚠ LES FORMES SPÉCIALES (1er octobre 2026) : les cas doivent exercer ce qu'ils nomment — chaque forme,
	# droite et reliée, chaque profil, chaque refus, une marche qui débouche et une aveugle, une paroi en
	# biais, une réparation. Sans ça, un greffon qui ignore l'un d'eux passerait.
	_egal(sortes.size(), 13, "les cas d'outils couvrent les treize sortes de fonctions")
	# LA SALLE (2 octobre 2026) : montée et descendue, creusée dans la roche, réparée, bornée, et ses deux refus.
	for s in ["up", "down", "dug", "repaired", "clamped", "too_small", "too_large"]:
		_vrai(salles.get(s, false), "aucun cas de salle « %s »" % s)
	_vrai(biais, "aucun cas de normale ne rend une diagonale : les parois en biais ne sont pas éprouvées")
	for f in ["tunnel", "tunnel+connect", "well", "bridge", "bridge+connect", "balcony", "stairs", "stairs+connect"]:
		_vrai(formes.has(f), "aucun cas de forme « %s »" % f)
	_egal(profils.size(), 3, "les trois profils ont leurs cas")
	_egal(erreurs.size(), EO.ERREURS_EN.size() - 2, "chaque refus de forme a son cas (sauf « trop grand », qu'aucun petit monde n'atteint, et « trop petit », qui est à la salle), et un cas sans refus")
	_vrai(ouverts.has(true) and ouverts.has(false), "une marche qui débouche ET une aveugle")
	_vrai(repares, "aucun cas ne répare un damier : la réparation n'est pas éprouvée")
	_vrai(touches >= 3 and manques >= 2, "les rayons doivent toucher ET manquer (%d / %d)" % [touches, manques])
	_vrai(egalite, "aucun rayon n'éprouve une égalité exacte : départager à l'envers resterait muet")
	_vrai(boite_vide, "aucune boîte ne dépasse la borne : la borne n'est pas éprouvée")
	_vrai(creuse, "aucune boîte creuse n'est réellement évidée")
	_egal(operations.size(), EO.OPERATIONS_EN.size(), "chaque opération de sélection a ses cas")
	print("  cas d'outils : %d cas, %d rayons qui touchent, %d qui manquent" % [(frais["cases"] as Array).size(),
		touches, manques])


# ── 4 ter. Le greffon Godot reproduit chaque cas d'OUTILS, à 100 % ──────────────────────────────────
#
# ⚠ **L'ATTENDU VIENT DE `outils.gd`, LE MESURÉ DE `mb_tools.gd`** : deux implémentations, jamais la même
# fonction des deux côtés (charte §6). Le greffon ne charge rien du cœur.
func _le_greffon_passe_les_cas_d_outils() -> void:
	var chemin := "res://addons/marchingblocks_paint/tools_conformance.json"
	var cas = JSON.parse_string(FileAccess.get_file_as_string(chemin)) if FileAccess.file_exists(chemin) else null
	_vrai(cas != null, "tools_conformance.json n'est pas livré avec le greffon Godot")
	if cas == null:
		return
	_egal(int(cas["limits"]["box_volume_max"]), Tools.BOX_VOLUME_MAX, "la borne des boîtes du greffon")
	var monde := _ensemble(cas["world"])
	_mondes_des_formes = {}
	for nom in cas["shape_worlds"]:
		_mondes_des_formes[nom] = _ensemble(cas["shape_worlds"][nom])
	var rouges := 0
	for c in cas["cases"]:
		var pourquoi := _cas_d_outil(c, monde)
		if pourquoi != "":
			rouges += 1
			_vrai(false, "outil « %s » — %s" % [c["name"], pourquoi])
	_egal(rouges, 0, "cas d'outils où le greffon Godot diverge de l'appli")
	print("  outils du greffon Godot : %d cas, %d divergence(s)" % [(cas["cases"] as Array).size(), rouges])


var _mondes_des_formes := {}


func _cas_d_outil(c: Dictionary, monde: Dictionary) -> String:
	var i: Dictionary = c["input"]
	var e: Dictionary = c["expected"]
	var ici: Dictionary = monde if i.get("cells", null) is String else _ensemble(i.get("cells", []))
	if i.has("world"):
		ici = _mondes_des_formes[i["world"]]
	var plein := func(v: Vector3i) -> bool: return ici.has(v)
	match c["kind"]:
		"ray":
			var r: Dictionary = Tools.ray(plein, _v3(i["origin"]), _v3(i["direction"]), float(i["reach"]),
				_ensemble(i["ignore"]))
			var obtenu := [r["hit"], r["cell"], r["normal"]]
			var voulu := [e["hit"], _vi(e["cell"]), _vi(e["normal"])]
			return "" if obtenu == voulu else "attendu %s, rendu %s" % [voulu, obtenu]
		"tile_vertex":
			var t := Tools.tile_vertex(_v3(i["origin"]), _v3(i["direction"]), _vi(i["cell"]), _vi(i["normal"]))
			return "" if t == _vi(e["vertex"]) else "attendu %s, rendu %s" % [_vi(e["vertex"]), t]
		"anchor":
			var a := Tools.anchor(i["tool"], {"hit": i["hit"], "cell": _vi(i["cell"]), "normal": _vi(i["normal"])})
			return "" if a == _vi(e["anchor"]) else "attendu %s, rendu %s" % [_vi(e["anchor"]), a]
		"brush":
			var b: Array = Tools.brush(_vi(i["anchor"]), _vi(i["normal"]), int(i["size"]), i["shape"])
			return _meme_liste(b, e["cells"])
		"change":
			var m: Dictionary = Tools.modify(i["tool"], _liste(i["targets"]), plein)
			return _meme_ensemble("set", m["set"], e["set"]) + _meme_ensemble("clear", m["clear"], e["clear"])
		"selection":
			return _meme_changement(Tools.operate(ici, _ensemble(i["selection"]), i["op"]), e)
		"box":
			var bx: Dictionary = Tools.box(_vi(i["a"]), _vi(i["b"]), i["hollow"])
			if bx.size() != int(e["count"]):
				return "attendu %d cases, rendu %d" % [int(e["count"]), bx.size()]
			return _meme_ensemble("cells", bx, e["cells"]) if e.has("cells") else ""
		"move":
			return _meme_changement(Tools.move(ici, _ensemble(i["selection"]), _vi(i["offset"])), e)
		"copy":
			return _meme_liste(Tools.copy(ici, _ensemble(i["selection"])), e["clipboard"])
		"paste":
			return _meme_changement(Tools.paste(ici, _liste(i["clipboard"]), _vi(i["anchor"])), e)
		"wall_normal":
			var n := Shapes.wall_normal(ici, _vi(i["cell"]), _vi(i["face"]))
			return "" if n == _vi(e["normal"]) else "attendu %s, rendu %s" % [_vi(e["normal"]), n]
		"room":
			var rr: Dictionary = Shapes.room(ici, _vi(i["a"]), _vi(i["b"]), int(i["floors"]), bool(i["up"]))
			var ec := _meme_ensemble("set", rr["set"], e["set"]) + _meme_ensemble("clear", rr["clear"], e["clear"])
			if rr["error"] != e["error"] or int(rr["repaired"]) != int(e["repaired"]):
				ec += "erreur/réparées %s/%s au lieu de %s/%s" % [rr["error"], rr["repaired"], e["error"], e["repaired"]]
			return ec
		"special_shape":
			var p := {"shape": i["shape"], "a": _vi(i["a"]), "face_a": _vi(i["face_a"]), "connect": i["connect"],
				"profile": i["profile"], "size": i["size"], "length": i["length"], "rail": i["rail"],
				"step": i.get("step", 2)}
			if i["connect"]:
				p["b"] = _vi(i["b"])
				p["face_b"] = _vi(i["face_b"])
			var r: Dictionary = Shapes.shape(ici, p)
			var ecart := _meme_ensemble("set", r["set"], e["set"]) + _meme_ensemble("clear", r["clear"], e["clear"])
			if r["error"] != e["error"]:
				ecart += "erreur %s au lieu de %s ; " % [r["error"], e["error"]]
			if r["opened"] != e["opened"] or int(r["repaired"]) != int(e["repaired"]):
				ecart += "opened/repaired %s/%s au lieu de %s/%s" % [r["opened"], r["repaired"], e["opened"], e["repaired"]]
			return ecart
	return "sorte inconnue " + str(c["kind"])


# ── 4 ter. LA PARITÉ (7 octobre 2026) : les cinq fichiers de cas communs, passés par le greffon ──────
# ⚠ **UN BANC QUI RENCONTRE UNE SORTE INCONNUE ROUGIT** (PARITE.md §11) : rien n'est sauté en silence. Et le nombre de
# cas de chaque fichier est vérifié : un fichier tronqué ne passerait pas pour vert.
const PARITE := {"transitions": 93, "animation": 44, "foliage": 59, "water": 25, "editing": 63, "water_mesh": 14}
## ⚠ LIVRÉS, PAS ENCORE REJOUÉS PAR LE GREFFON GODOT : un fichier livré et jamais rejoué ne doit pas passer pour vert.
## `water_mesh` en est sorti le 7 octobre 2026 (branche `eau-godot`) : `mb_water_mesh.gd` maille la nappe, ses 14 cas
## sont rejoués en SAC DE TRIANGLES (`eau_sac.gd`, écrit depuis `rules_text`).
const PARITE_A_VENIR := {}


func _le_greffon_passe_les_cas_de_parite() -> void:
	var total := 0
	for nom in PARITE:
		var chemin := "res://addons/marchingblocks_paint/%s_conformance.json" % nom
		var f = JSON.parse_string(FileAccess.get_file_as_string(chemin)) if FileAccess.file_exists(chemin) else null
		_vrai(f is Dictionary, "%s n'est pas livré avec le greffon Godot" % chemin)
		if not f is Dictionary:
			continue
		_egal((f["cases"] as Array).size(), PARITE[nom], "le nombre de cas de %s_conformance.json" % nom)
		var rouges := 0
		var sortes := {}
		for c in f["cases"]:
			sortes[c["kind"]] = int(sortes.get(c["kind"], 0)) + 1
			var pourquoi := _cas_de_parite(nom, f, c)
			if pourquoi != "":
				rouges += 1
				if rouges <= 6:
					_vrai(false, "%s « %s » — %s" % [nom, c["name"], pourquoi])
		_egal(rouges, 0, "cas de %s où le greffon Godot diverge de l'appli" % nom)
		total += (f["cases"] as Array).size()
		print("  parité %s : %d cas %s, %d divergence(s)" % [nom, (f["cases"] as Array).size(), str(sortes), rouges])
	print("  parité : %d cas en tout" % total)
	for nom in PARITE_A_VENIR:
		var chemin := "res://addons/marchingblocks_paint/%s_conformance.json" % nom
		var f = JSON.parse_string(FileAccess.get_file_as_string(chemin)) if FileAccess.file_exists(chemin) else null
		_vrai(f is Dictionary and (f["cases"] as Array).size() == PARITE_A_VENIR[nom],
			"%s est livré avec le greffon Godot, %d cas" % [chemin, PARITE_A_VENIR[nom]])
		_vrai(not PARITE.has(nom), "%s n'est pas compté deux fois" % nom)
		print("  parité %s : livré, PAS ENCORE REJOUÉ par le greffon Godot (la nappe recalculée)" % nom)
	# ⚠ UNE MUTATION MUETTE DES CAS COMMUNS (7 octobre 2026) : lire l'eau au point même au lieu de p + 0,1 ne change aucun
	# cas `check` (leurs plants sont à y = 1, où floor(y + 0,2) et floor(y + 0,3) coïncident). Gardé ICI, contre la
	# référence du cœur : un sol à y = 0,75 au-dessus d'une case d'eau en y = 1 — seul le + 0,1 y voit l'eau.
	var FEc: GDScript = load("res://addons/marchingblocks_core/feuillage.gd")
	var eau_ici := {Vector3i(0, 1, 0): true}
	var m_fr: Dictionary = FEc.modele(1, "M", "")
	var m_en := {"id": 1, "ground_offset": 0.0, "scale": 1.0, "scale_random": 0.2, "footprint": 0.5, "height": 1.0, "wind": 0.5}
	var monde_fr := {"plein": func(_c: Vector3i) -> bool: return false, "sol": func(_x, _z, _y): return null,
		"eau": func(q: Vector3) -> bool: return eau_ici.has(FEc.case_d_eau(q))}
	var monde_en := {"full": func(_c: Vector3i) -> bool: return false, "ground": func(_x, _z, _y): return null,
		"water": func(q: Vector3) -> bool: return eau_ici.has(Foliage.water_cell(q))}
	var p := Vector3(0.5, 0.75, 0.5)
	var ref: String = FEc.verifier(m_fr, FEc.plant(1, 1, p, 0.0, 1.0, "sol"), Vector3.UP, "sol_debord", monde_fr,
		FEc.index([], {}), {})
	var lu := Foliage.check(m_en, Foliage.plant(1, p, 0.0, 1.0, "ground"), Vector3.UP, "overflow", monde_en,
		Foliage.index([], {}), {})
	_vrai(ref == "dans_l_eau" and lu == "in_water", "l'eau sous un plant se lit en p + 0,1 (cœur « %s », greffon « %s »)" % [ref, lu])


## Compare deux valeurs JSON (et ce que le greffon rend) : entiers exacts, réels à `tol` près, tableaux dans l'ordre,
## dictionnaires clé à clé. Rend "" ou l'écart.
func _proche(obtenu: Variant, voulu: Variant, tol: float, ou := "") -> String:
	if (voulu is float or voulu is int) and (obtenu is float or obtenu is int):
		return "" if absf(float(obtenu) - float(voulu)) <= tol else "%s : %s au lieu de %s" % [ou, obtenu, voulu]
	if voulu is Array:
		if not (obtenu is Array) or (obtenu as Array).size() != (voulu as Array).size():
			return "%s : %s au lieu de %s" % [ou, str(obtenu).left(200), str(voulu).left(200)]
		for k in (voulu as Array).size():
			var e := _proche(obtenu[k], voulu[k], tol, "%s[%d]" % [ou, k])
			if e != "":
				return e
		return ""
	if voulu is Dictionary:
		if not (obtenu is Dictionary) or (obtenu as Dictionary).size() != (voulu as Dictionary).size():
			return "%s : %s au lieu de %s" % [ou, str(obtenu).left(200), str(voulu).left(200)]
		for k in voulu:
			if not (obtenu as Dictionary).has(k):
				return "%s : il manque « %s »" % [ou, k]
			var e := _proche(obtenu[k], voulu[k], tol, "%s.%s" % [ou, k])
			if e != "":
				return e
		return ""
	return "" if typeof(obtenu) == typeof(voulu) and obtenu == voulu else "%s : %s au lieu de %s" % [ou, obtenu, voulu]


## Un ensemble de cases (Dictionary ou Array de Vector3i) trié x, y, z, en triplets — comme les cas.
func _trie(cases_: Variant) -> Array:
	var l: Array = (cases_ as Dictionary).keys() if cases_ is Dictionary else Array(cases_).duplicate()
	l.sort()
	return l.map(func(c: Vector3i) -> Array: return [c.x, c.y, c.z])


func _vf(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func _cas_de_parite(fichier: String, f: Dictionary, c: Dictionary) -> String:
	var i: Variant = c["input"]
	var e: Variant = c["expected"]
	var k: String = c["kind"]
	var tol := 1e-5 if k in ["pulse", "place", "sway"] else 1e-6
	match fichier + "/" + k:
		# ── transitions
		"transitions/blend":
			var h := {}
			for r in i["h"]:
				h[int(r)] = float(i["h"][r])
			var ch: Array = (i["choices"] as Array).map(func(x): return int(x))
			var rg: Array = (i["ranks"] as Array).map(func(x): return int(x))
			return _proche(Trans.blend(rg, _v3(i["f"]), ch, i["table"], h, float(i["n"])), e, tol)
		"transitions/settings":
			return _proche(Trans.settings(i), e, tol)
		"transitions/table":
			return _proche(Trans.table(i["pairs"], int(i["layers"])), e, tol)
		"transitions/cell_texture":
			var cells := {}
			for q in i["cells"]:
				cells[_vi(q)] = int(q[3])
			var choices := {}
			for q in i["choices"]:
				choices[_vi(q)] = int(q[3])
			var d := Trans.cell_texture(cells, choices)
			var n: Vector3i = d["size"]
			var octets: Array = []
			for z in n.z:
				for y in n.y:
					for x in n.x:
						var b: int = (d["bytes"] as PackedByteArray)[(z * n.y + y) * n.x + x]
						if b != 0:
							octets.append([x, y, z, b])
			var o: Vector3i = d["origin"]
			return _proche({"origin": [o.x, o.y, o.z], "size": [n.x, n.y, n.z], "bytes": octets}, e, tol)
		"transitions/read":
			var r := Trans.read(i)
			return _proche({"error": true} if r.has("error") else r["transitions"], e, tol)
		# ── animation
		"animation/frame":
			return _proche(Anim.frame_at(int(i["count"]), float(i["fps"]), bool(i["ping_pong"]), float(i["t"]),
				float(i["phase"])), e, tol)
		"animation/pulse":
			return _proche(Anim.pulse_at(float(i["frequency"]), float(i["minimum"]), float(i["t"]), float(i["phase"])),
				e, tol)
		"animation/phase":
			return _proche(Anim.phase_of(_v3(i["origin"])), e, tol)
		"animation/scroll":
			var s := Anim.scroll_at(float(i["u"]), float(i["v"]), float(i["t"]), bool(i["synced"]), float(i["phase"]))
			return _proche([s.x, s.y], e, tol)
		"animation/read":
			return _proche(Anim.read(i), e, tol)
		# ── feuillage
		"foliage/place", "foliage/wind_data", "foliage/check", "foliage/brush":
			var models := {}
			for id in f["models"]:
				models[int(id)] = f["models"][id]
			var m: Dictionary = models[int(i["model"])]
			if k == "place":
				var pl := Foliage.plant(int(i["model"]), _v3(i["point"]), float(i["yaw"]), float(i["scale"]), "ground")
				var t := Foliage.transform(m, pl)
				return _proche({"basis": [_vf(t.basis.x), _vf(t.basis.y), _vf(t.basis.z)], "origin": _vf(t.origin),
					"height_above_ground": Foliage.height_above_ground(m, pl)}, e, tol)
			if k == "wind_data":
				var pl := Foliage.plant(int(i["model"]), _v3(i["point"]), 0.0, float(i["scale"]), "ground")
				var wd := Foliage.wind_of(m, pl)
				return _proche([wd.r, wd.g, wd.b, wd.a], e, tol)
			var monde := _ensemble(f["world_cells"])
			var eau := _ensemble(f["water_cells"])
			var plein := func(v: Vector3i) -> bool: return monde.has(v)
			var w := {"full": plein,
				"ground": func(x: float, z: float, y: float) -> Variant: return Foliage.ground_of_cells(plein, x, z, y),
				"water": func(q: Vector3) -> bool: return eau.has(Foliage.water_cell(q))}
			var deja: Array = (i["plants"] as Array).map(func(row: Array) -> Dictionary: return Foliage.plant_of(row))
			var ix := Foliage.index(deja, models)
			if k == "check":
				var pl := Foliage.plant(int(i["model"]), _v3(i["point"]), float(i["yaw"]), float(i["scale"]),
					"air" if i["mode"] == "air" else "ground")
				return _proche(Foliage.check(m, pl, _v3(i["normal"]), i["mode"], w, ix, models, float(i["spacing"]),
					float(i["max_slope"])), e, tol)
			var r := Foliage.brush(m, float(i["y_top"]), i["candidates"], i["mode"], w, ix, models, float(i["spacing"]),
				float(i["max_slope"]))
			var acceptes: Array = (r["plants"] as Array).map(func(pl: Dictionary) -> Array:
				var p: Vector3 = pl["p"]
				return [p.x, p.y, p.z, pl["yaw"], pl["scale"]])
			return _proche({"plants": acceptes, "refused": r["refused"]}, e, tol)
		"foliage/sway":
			var wv: Array = i["wind"]
			var v := Foliage.sway(_v3(i["vertex"]), _v3(i["normal"]), Color(wv[0], wv[1], wv[2], wv[3]), float(i["t"]),
				Vector2(i["direction"][0], i["direction"][1]))
			return _proche(_vf(v), e, tol)
		"foliage/ground_of_cells":
			var monde := _ensemble(f["world_cells"])
			var g: Variant = Foliage.ground_of_cells(func(v: Vector3i) -> bool: return monde.has(v), float(i["x"]),
				float(i["z"]), float(i["y_top"]))
			return _proche(null if g == null else g["y"], e, tol)
		"foliage/read":
			var r := Foliage.read(i)
			return _proche({"error": true} if r.has("error") else r["foliage"], e, tol)
		# ── l'eau
		"water/water_world":
			var w := Water.world(_ensemble(f["worlds"][i["world"]]), _liste(i["sources"]))
			var corps: Array = (w["bodies"] as Array).map(func(r: Dictionary) -> Dictionary:
				return {"kind": r["kind"], "error": r["error"], "level": r["level"], "end": r["end"],
					"water": _trie(r["water"]),
					"lakes": (r["lakes"] as Array).map(func(l: Dictionary) -> Dictionary:
						return {"level": l["level"], "cells": _trie(l["cells"])}),
					"course": (r["course"] as Array).map(func(q: Dictionary) -> Array:
						var v: Vector3i = q["cell"]
						return [v.x, v.y, v.z, q["kind"], int(q.get("lake", -1))])})
			return _proche({"bodies": corps, "sea": _trie(w["sea"])}, e, tol)
		"water/river_width":
			var s := Water.river_width(_ensemble(f["worlds"][i["world"]]), _vi(i["source"]), int(i["width"]))
			return _proche(s.map(func(v: Vector3i) -> Array: return [v.x, v.y, v.z]), e, tol)
		"water/surface_depth":
			var cells := _ensemble(f["worlds"][i["world"]])
			var eau := _ensemble(i["water"])
			var prof: Array = (i["cells"] as Array).map(func(q: Array) -> Array:
				return [int(q[0]), int(q[1]), int(q[2]), Water.depth(eau, cells, _vi(q))])
			return _proche({"surface": _trie(Water.surface(eau, cells)), "depth": prof}, e, tol)
		"water/read":
			var r := Water.read(i)
			return _proche({"error": true} if r.has("error") else r["water"], e, tol)
		# ── l'édition
		"editing/extrude":
			var cells := _ensemble(f["world_cells"]) if i["cells"] is String else _ensemble(i["cells"])
			var r := Tools.extrude(cells, int(i["floor"]), i["direction"], _ensemble(i["selection"]), i["mode"])
			var st: Vector3i = r["step"]
			return _proche({"set": _trie(r["set"]), "clear": _trie(r["clear"]), "selection": _trie(r["selection"]),
				"step": [st.x, st.y, st.z]}, e, tol)
		"editing/shrink_edge":
			return _proche(_trie(Tools.shrink_edge(_ensemble(i["selection"]))), e, tol)
		"editing/widen_flat":
			return _proche(_trie(Tools.widen_flat(_ensemble(i["selection"]))), e, tol)
		"editing/select_brush":
			var cells := _ensemble(f["world_cells"]) if i["cells"] is String else _ensemble(i["cells"])
			var sel := Tools.select_brush(_ensemble(i["selection"]), _liste(i["targets"]),
				func(v: Vector3i) -> bool: return cells.has(v), bool(i["include_empty"]), bool(i["deselect"]))
			return _proche(_trie(sel), e, tol)
		"editing/room_from_selection":
			var cells := _ensemble(f["world_cells"]) if i["cells"] is String else _ensemble(i["cells"])
			var r := Shapes.room_from_selection(cells, _ensemble(i["selection"]), int(i["floors"]), bool(i["up"]))
			var bx: Array = (r["box"] as Array).map(func(v: Vector3i) -> Array: return [v.x, v.y, v.z])
			return _proche({"error": r["error"], "set": _trie(r["set"]), "clear": _trie(r["clear"]),
				"repaired": r["repaired"], "box": bx}, e, tol)
		# ── la nappe recalculée (PARITE.md §12) : un sac de triangles, sans ordre, rotations permises, réflexion refusée
		"water_mesh/water_mesh":
			var bodies: Array = (i["bodies"] as Array).map(_corps_du_cas)
			var a := WaterMesh.arrays(bodies, _ensemble(f["worlds"][i["world"]]))
			var obtenu := Sac.triangles(a)
			var voulu := Sac.deplier(e)
			var ecart := Sac.meme_sac(voulu, obtenu)
			return "" if ecart == "" else "%s (résumé rendu %s, attendu %s)" % [ecart, Sac.resume(obtenu), e["summary"]]
	return "sorte inconnue « %s » dans %s_conformance.json" % [k, fichier]


## LA REPRISE = LE CALCUL ENTIER (PARITE.md §12, « incrémental == entier ») : des gestes AU HASARD (graine fixe) sur
## les mondes des cas de l'eau — des cases posées ou retirées près de l'eau, ou n'importe où —, et à chaque geste le
## calcul du nœud AVEC la reprise (la règle reprend les corps hors de l'emprise, une couche dont tous les corps sont
## repris garde sa nappe, les cascades et les sources gardent leurs grilles) rend EXACTEMENT ce que rend le calcul
## entier : les mêmes corps, et le même sac de triangles par couche. Et la reprise sert : des corps et des couches repris.
func _la_reprise_egale_le_calcul_entier() -> void:
	var f = JSON.parse_string(FileAccess.get_file_as_string("res://addons/marchingblocks_paint/water_conformance.json"))
	var mondes: Dictionary = f["worlds"]
	var decale := func(nom: String, d: Vector3i) -> Dictionary:
		var r := {}
		for c in mondes[nom]:
			r[_vi(c) + d] = true
		return r
	var compose: Dictionary = decale.call("crater near the edge", Vector3i.ZERO)
	compose.merge(decale.call("stairs", Vector3i(20, 0, 0)))
	# [nom, cases, sources par couche d'eau]
	var essais: Array = [
		["l'île : la mer, une rivière (deux couches)", _ensemble(mondes["island"]), [[Vector3i(-1, 2, -1)], [Vector3i(4, 4, 4)]]],
		["le cratère qui déborde", _ensemble(mondes["crater near the edge"]), [[Vector3i(2, 2, 6)]]],
		["le cratère calme", _ensemble(mondes["crater in a plain"]), [[Vector3i(6, 3, 6)]]],
		["l'escalier, trois rivières", _ensemble(mondes["stairs"]), [[Vector3i(0, 3, 0), Vector3i(0, 3, 1)], [Vector3i(0, 3, 2)]]],
		["la grotte close", _ensemble(mondes["closed cave"]), [[Vector3i(2, 2, 2)]]],
		["le cratère et l'escalier côte à côte", compose, [[Vector3i(2, 2, 6)], [Vector3i(20, 3, 1), Vector3i(20, 3, 2)]]],
		# GESTES IMPOSÉS (chacun a d'abord laissé passer une mutation, 7 octobre 2026) :
		#  - une couche, un lac et une rivière loin l'un de l'autre ; une case sur la rivière : le lac est repris, la
		#    couche NE l'est PAS (« une couche gardée si UN corps est repris » passait muette) ;
		#  - une case posée très haut puis retirée : la boîte remonte puis redescend (« une case retirée au bord ne
		#    rebalaye pas la boîte » passait muette — la boîte est aussi comparée à chaque geste) ;
		["un lac et une rivière dans UNE couche", compose, [[Vector3i(2, 2, 6), Vector3i(20, 3, 1)]],
			[func(b: Dictionary) -> Array: return [_milieu_du_cours(b["world"]["bodies"][1]) + Vector3i.UP],
			func(_b: Dictionary) -> Array: return [Vector3i(3, 40, 3)],
			func(_b: Dictionary) -> Array: return [Vector3i(3, 40, 3)]]],
		#  - une rivière qui sort d'un enclos par l'AUTRE côté, et revient : son chemin à plat sort de la boîte entre la
		#    source et sa chute ; une case posée sur ce chemin (« l'emprise oublie la coulée à plat » passait muette).
		["une rivière qui fait un détour", _enclos(), [[Vector3i(5, 2, 15)]],
			[func(b: Dictionary) -> Array: return [_le_plus_a_l_est(b["world"]["bodies"][0])]]],
	]
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 2026
	var gestes := 0
	var ecarts := 0
	var corps_repris := 0
	var couches_reprises := 0
	for e in essais:
		var cells: Dictionary = (e[1] as Dictionary).duplicate()
		var sources: Array = []
		var counts: Array = []
		for l in e[2]:
			sources.append_array(l)
			counts.append((l as Array).size())
		var job := {"layers": _en_deux_couches(cells), "sources": sources, "counts": counts, "base": {}}
		WaterNode._compute(job)
		var base: Dictionary = job["out"]
		var imposes: Array = e[3] if e.size() > 3 else []
		for g in imposes.size() + 8:
			var bx := Water.box(cells)
			var eau: Array = []
			for r in base["world"]["bodies"]:
				eau.append_array((r["water"] as Dictionary).keys().slice(0, 400))
			for c: Vector3i in ((imposes[g] as Callable).call(base) if g < imposes.size() else []):
				if cells.has(c):
					cells.erase(c)
				else:
					cells[c] = true
			for _k in (hasard.randi_range(1, 3) if g >= imposes.size() else 0):
				var c: Vector3i
				if not eau.is_empty() and hasard.randf() < 0.6:
					c = eau[hasard.randi_range(0, eau.size() - 1)] + Vector3i(hasard.randi_range(-2, 2),
						hasard.randi_range(-1, 1), hasard.randi_range(-2, 2))
				else:
					var lo: Vector3i = bx["lo"]
					var hi: Vector3i = bx["hi"]
					c = Vector3i(hasard.randi_range(lo.x - 1, hi.x + 1), hasard.randi_range(lo.y, hi.y + 1),
						hasard.randi_range(lo.z - 1, hi.z + 1))
				if cells.has(c):
					cells.erase(c)
				else:
					cells[c] = true
			var inc := {"layers": _en_deux_couches(cells), "sources": sources, "counts": counts, "base": base}
			WaterNode._compute(inc)
			var entier := {"layers": _en_deux_couches(cells), "sources": sources, "counts": counts, "base": {}}
			WaterNode._compute(entier)
			gestes += 1
			var pourquoi := ""
			if inc["out"]["box"] != Water.box(cells):
				pourquoi += "la boîte suivie %s au lieu de %s ; " % [inc["out"]["box"], Water.box(cells)]
			if inc["out"]["fingerprint"] != WaterNode.fingerprint(cells):
				pourquoi += "l'empreinte suivie n'est pas celle des cases ; "
			var bi: Array = inc["out"]["world"]["bodies"]
			var be: Array = entier["out"]["world"]["bodies"]
			for j in be.size():
				if _corps_canon(bi[j]) != _corps_canon(be[j]):
					pourquoi = "le corps %d diffère" % j
				if is_same(bi[j], base["world"]["bodies"][j]):
					corps_repris += 1
			for i in counts.size():
				if is_same(inc["out"]["arrays"][i], base["arrays"][i]):
					couches_reprises += 1
				var s := Sac.meme_sac(Sac.triangles(entier["out"]["arrays"][i]), Sac.triangles(inc["out"]["arrays"][i]))
				if s != "":
					pourquoi += " ; la nappe de la couche %d : %s" % [i, s]
			if pourquoi != "":
				ecarts += 1
				if ecarts <= 4:
					_vrai(false, "reprise ≠ entier, %s, geste %d : %s" % [e[0], g, pourquoi])
			base = inc["out"]
	_egal(ecarts, 0, "gestes au hasard où la reprise ne rend pas le calcul entier (sur %d)" % gestes)
	_vrai(corps_repris > 0 and couches_reprises > 0,
		"la reprise sert : %d corps repris, %d nappes de couche gardées sur %d gestes" % [corps_repris, couches_reprises, gestes])
	print("  reprise : %d gestes au hasard, %d corps repris, %d nappes gardées, %d écart(s)" % [gestes, corps_repris,
		couches_reprises, ecarts])


## ⚠ DEUX MUTATIONS QUE LES 14 CAS COMMUNS NE VOIENT PAS (7 octobre 2026, mesuré ici ET dans le cœur : la même mutation
## dans `eau_maillage.gd`, `test_parite` reste vert, le fichier livré ne change pas) : « deux cascades jointes gardent la
## lèvre la plus BASSE » et « deux bandes sur une même case ». Aucun cas n'a deux rivières qui tombent au même endroit
## de hauteurs différentes, ni deux rivières qui coulent sur une même case. Gardé ICI, contre la référence du cœur (comme
## le + 0,1 du feuillage) : une falaise percée d'une galerie — une rivière tombe du haut, une autre sort de la galerie
## sur la même face, à la même place ; au pied, elles coulent sur les mêmes cases. À AJOUTER aux cas communs
## (`epreuve_parite.gd`, OUVERT : régénérer touche les trois greffons).
func _deux_rivieres_au_meme_endroit() -> void:
	var d := {}
	for x in 5:
		for y in 6:
			for z in 3:
				d[Vector3i(x, y, z)] = true
	for x in range(5, 11):
		for z in 3:
			d[Vector3i(x, 0, z)] = true
	d.erase(Vector3i(3, 2, 1))
	d.erase(Vector3i(4, 2, 1))
	var sources := [Vector3i(4, 6, 1), Vector3i(3, 2, 1)]
	var w := Water.world(d, sources)
	var bodies: Array = w["bodies"]
	# Ce que le monde exerce, lu sur les corps : deux chutes de la même face (x = 5, z = 1), de lèvres différentes ;
	# des cases de rivière communes, posées sur la matière.
	var levres := {}
	var bandes := {}
	var communes := 0
	for r in bodies:
		var course: Array = r["course"]
		for i in course.size():
			var c: Vector3i = course[i]["cell"]
			if course[i]["kind"] == "fall" and i > 0 and course[i - 1]["kind"] != "fall":
				levres[(course[i - 1]["cell"] as Vector3i).y] = (course[i - 1]["cell"] as Vector3i).x
			if course[i]["kind"] == "flow" and d.has(c + Vector3i.DOWN):
				if bandes.has(c) and bandes[c] != r:
					communes += 1
				bandes[c] = r
	_vrai(bodies.size() == 2 and bodies[0]["kind"] == "river" and bodies[1]["kind"] == "river"
		and levres.size() >= 2 and levres.values().all(func(x: int) -> bool: return x == 5) and communes > 0,
		"deux rivières au même endroit : deux lèvres sur la face x = 5 (%s), %d case(s) de rivière communes" % [levres, communes])
	var coeur := EM.tableaux_du_maillage(FL.monde(d, sources)["corps"], d)
	var greffon := WaterMesh.arrays(bodies, d)
	_egal(Sac.meme_sac(Sac.triangles(coeur), Sac.triangles(greffon)), "",
		"deux rivières au même endroit : la nappe du greffon est celle du cœur (une cascade, de la plus haute lèvre ; une bande par case)")


## La case du milieu du cours d'une rivière.
func _milieu_du_cours(r: Dictionary) -> Vector3i:
	return r["course"][(r["course"] as Array).size() / 2]["cell"]


## La case la plus à l'est (x le plus grand) du cours d'une rivière.
func _le_plus_a_l_est(r: Dictionary) -> Vector3i:
	var m: Vector3i = r["course"][0]["cell"]
	for e in r["course"]:
		if (e["cell"] as Vector3i).x > m.x:
			m = e["cell"]
	return m


## Un plateau (x 0..20, y 0..1, z 0..30) et, dessus, un enclos ouvert vers +x autour de la case (5, 2, 15) : l'eau en
## sort vers l'est, puis contourne l'enclos jusqu'au bord ouest — son chemin à plat passe hors de la boîte qui va de la
## source à sa chute.
func _enclos() -> Dictionary:
	var d := {}
	for x in 21:
		for z in 31:
			for y in 2:
				d[Vector3i(x, y, z)] = true
	for c in [Vector3i(4, 2, 14), Vector3i(4, 2, 15), Vector3i(4, 2, 16), Vector3i(5, 2, 14), Vector3i(6, 2, 14),
			Vector3i(5, 2, 16), Vector3i(6, 2, 16)]:
		d[c] = true
	return d


## Les cases en DEUX couches de tuiles (x + z pair, impair), dans un ordre fixe : un geste n'en change souvent qu'une,
## l'autre est relue telle quelle (le même tableau, comme `get_used_cells` d'une couche qu'on n'a pas touchée).
func _en_deux_couches(cells: Dictionary) -> Array:
	var l: Array = cells.keys()
	l.sort()
	return [l.filter(func(c: Vector3i) -> bool: return (c.x + c.z) % 2 == 0),
		l.filter(func(c: Vector3i) -> bool: return (c.x + c.z) % 2 != 0)]


## Un corps d'eau sous une forme comparable (les ensembles triés).
func _corps_canon(r: Dictionary) -> Array:
	return [r["kind"], r["error"], r["level"], r["end"], _trie(r["water"]),
		(r["lakes"] as Array).map(func(l: Dictionary) -> Array: return [l["level"], _trie(l["cells"])]),
		(r["course"] as Array).map(func(q: Dictionary) -> Array: return [q["cell"], q["kind"], int(q.get("lake", -1))])]


## Un corps d'eau d'un cas `water_mesh` (le format de sortie des `water_world`, en listes) au format de `Water.world`.
func _corps_du_cas(b: Dictionary) -> Dictionary:
	var course: Array = (b["course"] as Array).map(func(q: Array) -> Dictionary:
		var d := {"cell": Vector3i(int(q[0]), int(q[1]), int(q[2])), "kind": q[3]}
		if q[3] == "lake":
			d["lake"] = int(q[4])
		return d)
	var lakes: Array = (b["lakes"] as Array).map(func(l: Dictionary) -> Dictionary:
		return {"level": int(l["level"]), "cells": _ensemble(l["cells"])})
	return {"kind": b["kind"], "error": b["error"], "level": int(b["level"]), "end": b["end"],
		"water": _ensemble(b["water"]), "lakes": lakes, "course": course}


## L'APPARIEMENT EN SAC, ÉPROUVÉ AVANT D'ÊTRE CRU (PARITE.md §12, « la comparaison est elle-même éprouvée ») : sur la
## plus grande nappe des cas (le bassin), vrai mélangé, tourné, bruité sous la tolérance ; faux sur un coin déplacé de
## 2e-4, un triangle retourné, un triangle doublé à la place d'un autre, des couleurs rangées sur 8 bits.
func _le_sac_est_eprouve() -> void:
	var f = JSON.parse_string(FileAccess.get_file_as_string("res://addons/marchingblocks_paint/water_mesh_conformance.json"))
	var bassin: Array = []
	for c in f["cases"]:
		var t := Sac.deplier(c["expected"])
		if t.size() > bassin.size():
			bassin = t
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 7
	var melange: Array = []
	for t: Array in bassin:
		var r := hasard.randi_range(0, 2)
		var tourne: Array = t.slice(12 * r) + t.slice(0, 12 * r)
		melange.append(tourne.map(func(x: float) -> float: return x + hasard.randf_range(-4e-5, 4e-5)))
	for k in range(melange.size() - 1, 0, -1):
		var j := hasard.randi_range(0, k)
		var x = melange[k]
		melange[k] = melange[j]
		melange[j] = x
	_vrai(bassin.size() > 1000 and Sac.meme_sac(bassin, melange) == "",
		"le sac : %d triangles mélangés, tournés, bruités sous la tolérance — égal (%s)" % [bassin.size(),
		Sac.meme_sac(bassin, melange)])
	var deplace := melange.duplicate(true)
	deplace[17][1] += 2e-4
	_vrai(Sac.meme_sac(bassin, deplace) != "", "le sac : un coin déplacé de 2e-4 — différent")
	var retourne := melange.duplicate(true)
	retourne[5] = (retourne[5] as Array).slice(0, 12) + (retourne[5] as Array).slice(24, 36) + (retourne[5] as Array).slice(12, 24)
	_vrai(Sac.meme_sac(bassin, retourne) != "", "le sac : un triangle retourné (le sens fait partie du contrat) — différent")
	var double := melange.duplicate(true)
	double[3] = (double[4] as Array).duplicate()
	_vrai(Sac.meme_sac(bassin, double) != "", "le sac : un triangle doublé à la place d'un autre — différent")
	var huit_bits := melange.duplicate(true)
	for t: Array in huit_bits:
		for k in 3:
			for j in range(6, 10):
				t[12 * k + j] = roundf(float(t[12 * k + j]) * 255.0) / 255.0
	_vrai(Sac.meme_sac(bassin, huit_bits) != "", "le sac : les couleurs rangées sur 8 bits (l'ArrayMesh de Godot) — différent")


# ── 3 ter. Les shaders du greffon sont ceux de l'appli, AUJOURD'HUI (comme les icônes) ──────────────
func _les_shaders_livres_sont_a_jour() -> void:
	var frais: Dictionary = GENERATEUR_SHADERS.sorties()
	_vrai(not frais.has("erreur"), "générateur de shaders : %s" % str(frais.get("erreur", "")))
	if frais.has("erreur"):
		return
	for chemin in frais:
		var ici := FileAccess.get_file_as_bytes(chemin) if FileAccess.file_exists(chemin) else PackedByteArray()
		_vrai(ici == frais[chemin], "%s absent ou PÉRIMÉ : relancer DEV_TOOLS/generer_shaders_greffon.gd" % chemin)
	var Shaders: GDScript = load("res://addons/marchingblocks_paint/mb_shaders.gd")
	for nom in ["ANIMATION", "TRANSITIONS"]:
		var code: String = Shaders.get_script_constant_map()[nom]
		_vrai(code.contains("uniform mat4 mb_world_to_format") and not code.contains("global uniform"),
			"le shader %s du greffon n'est pas en espace du format, ou garde une globale" % nom)


func _meme_changement(r: Dictionary, e: Dictionary) -> String:
	return _meme_ensemble("set", r["set"], e["set"]) + _meme_ensemble("clear", r["clear"], e["clear"]) \
		+ _meme_ensemble("selection", r["selection"], e["selection"])


func _meme_ensemble(quoi: String, obtenu: Dictionary, voulu: Array) -> String:
	return "" if obtenu == _ensemble(voulu) else "%s : attendu %d cases, rendu %d ; " % [quoi, voulu.size(), obtenu.size()]


## ⚠ Une LISTE (pinceau, presse-papiers) doit sortir dans le même ORDRE, pas seulement les mêmes cases.
func _meme_liste(obtenu: Array, voulu: Array) -> String:
	return "" if obtenu == _liste(voulu) else "attendu %s, rendu %s" % [_liste(voulu), obtenu]


func _vi(a: Array) -> Vector3i:
	return Vector3i(int(a[0]), int(a[1]), int(a[2]))


func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _liste(a: Array) -> Array[Vector3i]:
	var l: Array[Vector3i] = []
	for p in a:
		l.append(_vi(p))
	return l


func _ensemble(a: Array) -> Dictionary:
	var d := {}
	for p in a:
		d[_vi(p)] = true
	return d


# ── 4 quater. Les outils DANS LA VUE : des clics réels, une caméra réelle, une annulation réelle ─────
#
# ⚠ **CE QUI N'EST PAS ÉPROUVÉ ICI** : le greffon d'éditeur lui-même (`plugin.gd`, sa barre, le relais
# de `_forward_3d_gui_input`) — un greffon d'éditeur ne se teste pas en headless (charte §6). Ce qui
# l'est : tout ce qu'il relaie, `mb_editor.gd`, mené par les mêmes événements que l'éditeur lui passe.
func _les_outils_dans_la_vue() -> void:
	# ⚠ **UN SCRIPT QUI NE COMPILE PAS FAISAIT SAUTER CETTE SECTION EN SILENCE, ET LA SUITE FINISSAIT
	# « OK »** — mesuré le 28 septembre 2026 : `Editeur.new()` a levé une erreur d'exécution, Godot a
	# abandonné la fonction, et le reste a continué. On exige d'abord que chaque script se charge.
	var tous_charges := true
	for nom in ["mb_tools.gd", "mb_editor.gd", "mb_world.gd", "mb_rule.gd", "mb_tileset.gd", "mb_icons.gd", "mb_toolbar.gd", "plugin.gd"]:
		var script := load("res://addons/marchingblocks_paint/" + nom) as GDScript
		var charge := script != null and script.can_instantiate()
		_vrai(charge, "addons/marchingblocks_paint/%s ne compile pas" % nom)
		tous_charges = tous_charges and charge
	if not tous_charges:
		return
	# ⚠ CHAQUE MONDE D'ESSAI A SON PROPRE PARENT : des MarchingBlocksWorld frères sont les couches d'UN monde
	# (couches exclusives, 2 octobre 2026) — deux essais posés sous la racine se mêleraient.
	var tenant_gestes := Node3D.new()
	root.add_child(tenant_gestes)
	var monde: Node3D = World.new()
	tenant_gestes.add_child(monde)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.look_at_from_position(Vector3(2.5, 12, 2.5), Vector3(2.5, 0, 2.5), Vector3.FORWARD)
	var ed: Node = Editeur.new()
	root.add_child(ed)
	var annul := UndoRedo.new()
	ed.undo = annul
	ed.world = monde
	var ecran := func(case_: Vector3i) -> Vector2:
		return cam.unproject_position(Vector3(case_) + Vector3(0.5, 0.0, 0.5))
	var clic := func(pos: Vector2, appuye: bool, maj := false) -> bool:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = appuye
		b.position = pos
		b.shift_pressed = maj
		return ed.input(cam, b)
	var bouge := func(pos: Vector2) -> bool:
		var m := InputEventMouseMotion.new()
		m.position = pos
		return ed.input(cam, m)
	var nb := func() -> int: return (monde.cells() as Dictionary).size()

	# Grid : un clic pose la case du sol, et Ctrl+Z la reprend.
	_vrai(clic.call(ecran.call(Vector3i(2, 0, 2)), true), "un clic d'outil est PRIS : l'éditeur ne doit pas sélectionner")
	clic.call(ecran.call(Vector3i(2, 0, 2)), false)
	_egal(monde.cells(), {Vector3i(2, 0, 2): true}, "Grid + Add : un clic pose la case visée sur le sol")
	annul.undo()
	_egal(nb.call(), 0, "Ctrl+Z reprend le coup entier")
	annul.redo()
	_egal(nb.call(), 1, "Ctrl+Y le rend")

	# Sculpt : contre la face visée ; et le VERROU DE COUP — glisser sur place ne bâtit pas une tour.
	ed.set_aim("sculpt")
	var centre: Vector2 = ecran.call(Vector3i(2, 0, 2))
	clic.call(centre, true)
	bouge.call(centre + Vector2(0.4, 0))
	bouge.call(centre + Vector2(0.8, 0))
	clic.call(centre, false)
	_egal(monde.cells(), {Vector3i(2, 0, 2): true, Vector3i(2, 1, 2): true},
		"Sculpt + Add pose CONTRE la face du dessus, et glisser sur place n'empile rien (verrou de coup)")
	annul.undo()
	_egal(nb.call(), 1, "le coup de sculpture s'annule d'un bloc")

	# Rect → Fill → Extrude : l'étage suit, et Ctrl+Z le rend.
	ed.set_aim("grid")
	ed.set_mode("rect")
	clic.call(ecran.call(Vector3i(1, 0, 1)), true)
	bouge.call(ecran.call(Vector3i(3, 0, 2)))
	clic.call(ecran.call(Vector3i(3, 0, 2)), false)
	_egal(ed.selection.size(), 6, "le Rect prend ses 3 × 2 cases, vides comprises")
	ed.operate("fill")
	_egal(nb.call(), 6, "Fill remplit le rectangle (la case déjà pleine reste)")
	ed.operate("extrude_up")
	_egal(nb.call(), 12, "Extrude pose l'étage du dessus")
	_egal(monde.floor_y, 1, "et le plan de visée MONTE avec lui")
	annul.undo()
	_egal(monde.floor_y, 0, "Ctrl+Z rend l'étage avec les cases")
	_egal(nb.call(), 6, "et reprend l'extrusion")

	# NAVIGATE EST UN INTERRUPTEUR (Espace), plus une visée (Jordan, 29 septembre 2026) — aligné sur l'appli.
	ed.set_aim("sculpt")
	ed.set_mode("add")
	var espace := InputEventKey.new()
	espace.keycode = KEY_SPACE
	espace.pressed = true
	_vrai(ed.input(cam, espace), "Espace est pris")
	_vrai(ed.navigating and ed.aim == "sculpt", "Espace allume Navigate SANS toucher à la visée")
	_vrai(not clic.call(ecran.call(Vector3i(0, 0, 0)), true), "en Navigate, le clic est LAISSÉ à l'éditeur")
	clic.call(ecran.call(Vector3i(0, 0, 0)), false)
	_egal(nb.call(), 6, "en Navigate, un clic ne peint rien")
	_vrai(ed.input(cam, espace) and not ed.navigating and ed.aim == "sculpt", "Espace éteint Navigate : la visée revient telle quelle")
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	var visees: Array = [ed.aim]
	for i in 2:
		ed.input(cam, tab)
		visees.append(ed.aim)
	_egal(visees, ["sculpt", "grid", "sculpt"], "Tab alterne Grid et Sculpt, et SEULEMENT eux")
	ed.input(cam, espace)
	_vrai(ed.input(cam, tab) and not ed.navigating and ed.aim == "grid", "Tab en vol choisit la visée suivante et sort du vol")
	ed.set_aim("grid")

	# World → Clear cells (parité avec Unity et Unreal) : tout part en UNE action, et Ctrl+Z rend tout.
	ed.clear_world()
	_egal(nb.call(), 0, "Clear cells vide le monde")
	annul.undo()
	_egal(nb.call(), 6, "et un seul Ctrl+Z rend toutes les cases")
	# Move ±X par le menu : les cases sélectionnées se déplacent sur l'axe du monde, pas de la caméra.
	ed.set_mode("select")
	ed.clear_selection()
	ed._set_selection({Vector3i(1, 0, 1): true})
	ed.move_selection(Vector3i(1, 0, 0))
	# (2,0,1) était déjà pleine : la case arrive sur de la matière et FUSIONNE, la source se vide.
	_vrai(not monde.cells().has(Vector3i(1, 0, 1)) and monde.cells().has(Vector3i(2, 0, 1)),
		"Move +X déplace la sélection d'une case sur X")
	_egal(ed.selection, {Vector3i(2, 0, 1): true}, "et la sélection suit")

	# LES FORMES SPÉCIALES, par la vraie caméra (1er octobre 2026). Un mur de 3 (x = 10..12), vu de −X.
	# Attendu déroulé à la main : un tunnel droit, rond, de taille 2, en (10,2,2) face −X — une croix de 5
	# cases sur les tranches x = 10..12 (la case (13,2,2) est vide : la marche s'arrête à la paroi d'en face).
	var mur: Array = []
	for x in range(10, 13):
		for y in 5:
			for z in 5:
				mur.append(Vector3i(x, y, z))
	monde.apply_cells(mur, [])
	var plein: int = nb.call()
	ed.set_special("tunnel")
	ed.profile = "round"
	ed.shape_size = 2
	cam.look_at_from_position(Vector3(4, 2.5, 2.5), Vector3(10, 2.5, 2.5), Vector3.UP)
	var face_ouest: Vector2 = cam.unproject_position(Vector3(10.0, 2.5, 2.5))
	bouge.call(face_ouest)
	_vrai(clic.call(face_ouest, true), "forme : le clic est PRIS")
	clic.call(face_ouest, false)
	_egal(nb.call(), plein - 15, "Tunnel droit : la croix de 15 cases, de part en part")
	_vrai(not monde.cells().has(Vector3i(12, 2, 2)) and not monde.cells().has(Vector3i(11, 3, 2))
		and monde.cells().has(Vector3i(11, 3, 3)), "… la croix exacte")
	annul.undo()
	_egal(nb.call(), plein, "UN Ctrl+Z rend le mur")
	# Connect : l'ancre, Échap qui l'oublie, puis l'ouest et l'est.
	ed.set_connect(true)
	clic.call(face_ouest, true)
	clic.call(face_ouest, false)
	_vrai(not ed.shape_anchor.is_empty() and nb.call() == plein, "Connect : le premier clic pose une ancre, rien d'autre")
	var echap := InputEventKey.new()
	echap.keycode = KEY_ESCAPE
	echap.pressed = true
	ed.input(cam, echap)
	_vrai(ed.shape_anchor.is_empty(), "Échap oublie l'ancre")
	clic.call(face_ouest, true)
	clic.call(face_ouest, false)
	cam.look_at_from_position(Vector3(19, 2.5, 2.5), Vector3(13, 2.5, 2.5), Vector3.UP)
	var face_est: Vector2 = cam.unproject_position(Vector3(13.0, 2.5, 2.5))
	clic.call(face_est, true)
	clic.call(face_est, false)
	_egal(nb.call(), plein - 15, "Connect : le second clic relie les deux faces, la même croix")
	_vrai(ed.shape_anchor.is_empty(), "… et l'ancre est consommée")
	annul.undo()
	# Le puits refuse une paroi, et le dit.
	ed.set_special("well")
	ed.set_connect(false)
	clic.call(face_est, true)
	clic.call(face_est, false)
	_vrai(nb.call() == plein and ed.status.contains("FLOOR"), "un puits sur une paroi est refusé, et le dit")
	ed.set_connect(true)
	ed.status = ""
	clic.call(face_est, true)
	clic.call(face_est, false)
	_vrai(ed.shape_anchor.is_empty() and ed.status.contains("FLOOR"),
		"Connect : une paroi n'est pas une première ancre de puits, et le greffon le dit")
	ed.set_connect(false)
	# LA SALLE (2 octobre 2026) : un rectangle tracé à plat sur la grille, par un vrai glissé — l'attendu vient du
	# CŒUR (`FS.salle`), jamais du greffon. Un Ctrl+Z la reprend ; trop étroite, elle est refusée et dite.
	var avant_salle: Dictionary = monde.cells()
	var y_sol: int = monde.floor_y
	# ⚠ EN VISÉE SCULPT : la salle se trace À PLAT sur la grille quelle que soit la visée — en Grid, viser la
	# matière tomberait aussi sur le sol, et l'oubli resterait muet.
	ed.set_aim("sculpt")
	ed.set_special("room")
	ed.room_floors = 2
	ed.room_up = true
	var coin_a := Vector3i(0, y_sol, 0)
	var coin_b := Vector3i(4, y_sol, 3)
	_vrai(clic.call(ecran.call(coin_a), true), "salle : le clic est PRIS")
	bouge.call(ecran.call(coin_b))
	clic.call(ecran.call(coin_b), false)
	var voulu: Dictionary = FS.salle(avant_salle, coin_a, coin_b, 2, true)
	var apres_salle: Dictionary = avant_salle.duplicate()
	apres_salle.merge(voulu["poser"])
	for c in voulu["effacer"]:
		apres_salle.erase(c)
	_vrai(not (voulu["poser"] as Dictionary).is_empty() and monde.cells() == apres_salle,
		"un glissé sur la grille pose la salle que pose MarchingBlocks (%d cases de coque)" % (voulu["poser"] as Dictionary).size())
	annul.undo()
	_egal(monde.cells(), avant_salle, "UN Ctrl+Z reprend la salle")
	# Down, DANS LA ROCHE : un bloc sous la grille, que la salle doit creuser (sans lui, oublier le creux resterait muet).
	var roche := {}
	for x in range(0, 5):
		for y in range(y_sol - 5, y_sol):
			for z in range(0, 4):
				if not avant_salle.has(Vector3i(x, y, z)):
					roche[Vector3i(x, y, z)] = true
	monde.apply_cells(roche.keys(), [])
	var avant_bas: Dictionary = monde.cells()
	ed.room_up = false
	clic.call(ecran.call(coin_a), true)
	bouge.call(ecran.call(coin_b))
	clic.call(ecran.call(coin_b), false)
	voulu = FS.salle(avant_bas, coin_a, coin_b, 2, false)
	apres_salle = avant_bas.duplicate()
	apres_salle.merge(voulu["poser"])
	for c in voulu["effacer"]:
		apres_salle.erase(c)
	_vrai(not (voulu["effacer"] as Dictionary).is_empty() and monde.cells() == apres_salle,
		"Down : la salle descend sous la grille et CREUSE la roche, comme dans MarchingBlocks (%d cases creusées)"
		% (voulu["effacer"] as Dictionary).size())
	annul.undo()
	monde.apply_cells([], roche.keys())
	clic.call(ecran.call(coin_a), true)
	bouge.call(ecran.call(Vector3i(1, y_sol, 3)))
	clic.call(ecran.call(Vector3i(1, y_sol, 3)), false)
	_vrai(monde.cells() == avant_salle and ed.status.contains("3 x 3"), "une salle trop étroite est refusée, et le greffon le dit")
	ed.set_mode("add")

	ed.world = null
	for n in [ed, cam, monde]:
		n.queue_free()
	annul.free()


# ── 5. De bout en bout : l'appli exporte, le greffon charge, pose, et redonne ce que l'appli pose ────
func _de_bout_en_bout() -> void:
	_vrai(_barre_finie, "SENTINELLE : l'épreuve de la barre s'est arrêtée en route (erreur d'exécution ?)")
	_les_outils_dans_la_vue()
	_l_edition_de_parite_dans_la_vue()
	_vrai(_edition_finie, "SENTINELLE : l'édition de la parité dans la vue s'est arrêtée en route (erreur d'exécution ?)")

	var bilan: Dictionary = BM.librairie()
	var lot: MeshLibrary = bilan["lot"]
	var dossier := ProjectSettings.globalize_path("user://test_format")
	var sortie: Dictionary = FN.exporter(lot, dossier, "Witness Rock", "MarchingBlocks test")
	_vrai(not sortie.has("erreur"), "l'export échoue : %s" % sortie.get("erreur", ""))
	if sortie.has("erreur"):
		_fin()
		return
	_egal(sortie["dossier"], dossier.path_join("witness_rock.mbset"), "le nom du dossier est assaini")
	_egal(sortie["tuiles"], lot.get_item_list().size(), "chaque item du lot part en tuile")
	_egal(sortie["manquantes"], [], "le témoin ne déclare aucune tuile manquante")
	var charge: Dictionary = Tileset.load_tileset(dossier.path_join("witness_rock.mbset/tileset.json"))
	_vrai(not charge.has("erreur") and not charge.has("error"), "le greffon ne charge pas l'export : %s"
		% charge.get("error", ""))
	if charge.has("error"):
		_fin()
		return
	_egal((charge["library"] as MeshLibrary).get_item_list().size(), lot.get_item_list().size(),
		"le greffon relit autant de tuiles que l'appli en a exporté")
	# ⚠ LES MAILLAGES PORTENT LE NOM DE LEUR NŒUD — lu dans le JSON du .glb, SANS le lecteur de Godot,
	# qui ne dirait que les nœuds. C'est ce que l'importeur d'Unreal nomme (un StaticMesh par maillage).
	var glb := FileAccess.get_file_as_bytes(dossier.path_join("witness_rock.mbset/tiles.glb"))
	var long_json := glb.decode_u32(12)
	var gltf = JSON.parse_string(glb.slice(20, 20 + long_json).get_string_from_utf8())
	var anonymes := 0
	var mal_nommes: Array = []
	for noeud in gltf["nodes"]:
		if not noeud.has("mesh"):
			continue
		var nom_maillage = gltf["meshes"][int(noeud["mesh"])].get("name", null)
		if nom_maillage == null:
			anonymes += 1
		elif nom_maillage != noeud["name"]:
			mal_nommes.append("%s ≠ %s" % [nom_maillage, noeud["name"]])
	_egal(anonymes, 0, "maillages anonymes dans tiles.glb (Unreal les importerait indiscernables)")
	_vrai(mal_nommes.is_empty(), "maillages nommés autrement que leur nœud : %s" % str(mal_nommes.slice(0, 3)))
	# Le repère témoin : présent, et lu par Godot sans conversion — ses quatre points exacts.
	var maillages: Dictionary = Tileset._meshes_of(dossier.path_join("witness_rock.mbset/tiles.glb"))
	var repere: Mesh = maillages.get(FN.MARQUEUR, null)
	_vrai(repere != null, "tiles.glb ne porte pas le repère témoin « %s »" % FN.MARQUEUR)
	if repere != null:
		var lus := {}
		for p in repere.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			lus[Vector3i(roundi(p.x), roundi(p.y), roundi(p.z))] = true
		_egal(lus, {Vector3i(0, 0, 0): true, Vector3i(1, 0, 0): true, Vector3i(0, 2, 0): true,
			Vector3i(0, 0, 3): true}, "les quatre points du repère témoin, relus dans Godot")

	var tenant_temoin := Node3D.new()
	root.add_child(tenant_temoin)
	var monde: Node3D = World.new()
	tenant_temoin.add_child(monde)
	var cells := monde.get_node("Cells") as GridMap
	var pleines: Dictionary = BM.cases(0)
	for c in pleines:
		cells.set_cell_item(c, 0)
	monde.tileset = dossier.path_join("witness_rock.mbset/tileset.json")
	var rapport: Dictionary = monde.last_report()
	_egal(rapport["error"], "", "le monde se bâtit sans erreur")
	_egal(rapport["missing"], 0, "aucun cube rouge sur le témoin")
	# L'attendu : ce que le PEINTRE DE L'APPLI pose, via la référence.
	var comptes: Dictionary = FN.tuiles_du_lot(lot)
	var attendu: Array = FN.attendu(pleines, comptes)
	var tuiles := monde.get_node("Tiles") as GridMap
	var lib: MeshLibrary = tuiles.mesh_library
	var ecarts := 0
	var premier := ""
	for e in attendu:
		var v := Vector3i(e[0], e[1], e[2])
		var id: int = tuiles.get_cell_item(v)
		var nom: String = lib.get_item_name(id) if id >= 0 else "∅"
		var q: int = -1
		var o: int = tuiles.get_cell_item_orientation(v)
		for k in 4:
			if tuiles.get_orthogonal_index_from_basis(Basis(Vector3.UP, k * PI / 2.0)) == o:
				q = k
		if nom != e[3] or q != e[4]:
			ecarts += 1
			if premier == "":
				premier = "%s : attendu %s / %d, posé %s / %d" % [v, e[3], e[4], nom, q]
	_egal(ecarts, 0, "sommets où le greffon ne pose pas ce que l'appli pose — %s" % premier)
	_egal(tuiles.get_used_cells().size(), attendu.size(), "le greffon ne pose rien de plus")
	# La position réelle : la pièce du sommet v se centre en (v + piece_offset) × taille de case.
	var v0 := Vector3i(attendu[0][0], attendu[0][1], attendu[0][2])
	var centre: Vector3 = tuiles.to_global(tuiles.map_to_local(v0))
	_vrai(centre.is_equal_approx(Vector3(v0) + Vector3.ONE), "la pièce de %s est centrée en %s, pas en v + (1,1,1)"
		% [v0, centre])
	print("  de bout en bout : %d tuiles exportées, %d posées par le greffon, %d écart(s)"
		% [sortie["tuiles"], tuiles.get_used_cells().size(), ecarts])
	_deux_couches(dossier.path_join("witness_rock.mbset/tileset.json"), comptes)
	monde.queue_free()
	_les_variantes_de_bout_en_bout(lot, dossier)
	_le_monde_de_bout_en_bout(lot, pleines, attendu)
	_le_monde_complet_de_bout_en_bout(lot)
	_vrai(_monde_complet_fini, "SENTINELLE : le monde complet s'est arrêté en route (erreur d'exécution ?)")
	_l_eau_recalculee_de_bout_en_bout(lot)
	_vrai(_eau_recalculee_finie, "SENTINELLE : l'eau recalculée s'est arrêtée en route (erreur d'exécution ?)")
	_le_pinceau_de_plantation()
	_vrai(_plantation_finie, "SENTINELLE : le pinceau de plantation s'est arrêté en route (erreur d'exécution ?)")
	_fin()


# ── LES VARIANTES DE BOUT EN BOUT (5 octobre 2026) ──────────────────────────────────────────────────
# L'appli exporte un lot dont la clé du sol a deux variantes ; le greffon le charge et pose sur un sol 6 × 6, avec
# des poids, exactement ce que pose la référence (`FN.attendu` avec poids) ; puis l'OUTIL VARIANT, mené par de vrais
# clics à travers une caméra : la suivante, la suivante, Ctrl+Z, Ctrl+Y, Maj + clic (retour au tirage).
func _les_variantes_de_bout_en_bout(lot: MeshLibrary, dossier: String) -> void:
	var sol := {}
	for x in 6:
		for z in 6:
			sol[Vector3i(x, 0, z)] = true
	var cles := FN.tuiles_du_lot(lot)
	var vise := Vector3i(2, 0, 2)
	var cle_sol := ""
	for d in MB.poses(sol, cles):
		if d["sommet"] == vise:
			cle_sol = d["cle"]
	var varie := MeshLibrary.new()
	var id := 0
	for i in lot.get_item_list():
		varie.create_item(id)
		varie.set_item_name(id, lot.get_item_name(i))
		varie.set_item_mesh(id, lot.get_item_mesh(i))
		id += 1
	for k in [1, 2]:
		varie.create_item(id)
		varie.set_item_name(id, MB.nom_de_variante(cle_sol, k))
		varie.set_item_mesh(id, lot.get_item_mesh(cles[cle_sol]))
		id += 1
	var sortie: Dictionary = FN.exporter(varie, dossier, "Varied Rock", "MarchingBlocks test")
	_vrai(not sortie.has("erreur") and cle_sol != "", "l'export à variantes échoue : %s (clé du sol %s)"
		% [sortie.get("erreur", ""), cle_sol])
	if sortie.has("erreur"):
		return
	var chemin: String = dossier.path_join("varied_rock.mbset/tileset.json")
	var tenant := Node3D.new()
	root.add_child(tenant)
	var monde: Node3D = World.new()
	tenant.add_child(monde)
	var grille := monde.get_node("Cells") as GridMap
	for c in sol:
		grille.set_cell_item(c, 0)
	monde.tileset = chemin
	var poids := {cle_sol: [1, 2, 1]}
	monde.variant_weights = {FN.id_de_cle(cle_sol): [1, 2, 1]}
	var tuiles := monde.get_node("Tiles") as GridMap
	var nom_pose := func(v: Vector3i) -> String:
		var it: int = tuiles.get_cell_item(v)
		return tuiles.mesh_library.get_item_name(it) if it >= 0 else "∅"
	var comptes_varies := FN.tuiles_du_lot(varie)
	var attendu: Array = FN.attendu(sol, comptes_varies, poids, {})
	var ecarts := 0
	var variantes_posees := 0
	for e in attendu:
		var v := Vector3i(e[0], e[1], e[2])
		if nom_pose.call(v) != e[3]:
			ecarts += 1
		if str(e[3]).contains("_var"):
			variantes_posees += 1
	_egal(monde.last_report()["error"], "", "le monde à variantes se bâtit sans erreur")
	_egal(ecarts, 0, "le greffon pose, poids compris, les variantes que l'appli pose")
	_vrai(variantes_posees > 0 and variantes_posees < attendu.size(), "… des variantes ET des bases (%d sur %d)"
		% [variantes_posees, attendu.size()])
	# L'OUTIL VARIANT, par de vrais clics : la caméra au-dessus de la case (2, 0, 2), le dessus touché en (2,5 ; 1 ; 2,5).
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.look_at_from_position(Vector3(2.5, 12, 2.5), Vector3(2.5, 0, 2.5), Vector3.FORWARD)
	var ed: Node = Editeur.new()
	root.add_child(ed)
	var annul := UndoRedo.new()
	ed.undo = annul
	ed.world = monde
	ed.set_mode("variant")
	var ou: Vector2 = cam.unproject_position(Vector3(2.5, 1.0, 2.5))
	var clic := func(maj: bool) -> void:
		for appuye in [true, false]:
			var b := InputEventMouseButton.new()
			b.button_index = MOUSE_BUTTON_LEFT
			b.pressed = appuye
			b.position = ou
			b.shift_pressed = maj
			ed.input(cam, b)
	var base: String = FN.nom_de_tuile(cle_sol)
	var noms := [base, FN.nom_de_tuile(MB.nom_de_variante(cle_sol, 1)), FN.nom_de_tuile(MB.nom_de_variante(cle_sol, 2))]
	var avant: String = nom_pose.call(vise)
	var rang: int = noms.find(avant)
	clic.call(false)
	_egal(monde.variant_choices.get(vise, -1), (rang + 1) % 3, "Variant : un clic choisit la variante suivante à ce sommet")
	_egal(nom_pose.call(vise), noms[(rang + 1) % 3], "… et le monde la pose (%s → %s)" % [avant, nom_pose.call(vise)])
	clic.call(false)
	_egal(nom_pose.call(vise), noms[(rang + 2) % 3], "… un second clic, la suivante")
	annul.undo()
	_egal(nom_pose.call(vise), noms[(rang + 1) % 3], "Ctrl+Z rend la précédente")
	annul.redo()
	_egal(nom_pose.call(vise), noms[(rang + 2) % 3], "Ctrl+Y la refait")
	clic.call(true)
	_vrai(not monde.variant_choices.has(vise) and nom_pose.call(vise) == avant,
		"Maj + clic : le sommet revient au tirage (%s)" % nom_pose.call(vise))
	_egal(_poses_hors(tuiles, vise, attendu), 0, "aucun autre sommet n'a changé")
	ed.queue_free()
	cam.queue_free()
	tenant.queue_free()


## Les sommets autres que `sauf` dont la tuile posée n'est plus celle de `attendu`.
func _poses_hors(tuiles: GridMap, sauf: Vector3i, attendu: Array) -> int:
	var n := 0
	for e in attendu:
		var v := Vector3i(e[0], e[1], e[2])
		if v == sauf:
			continue
		var it: int = tuiles.get_cell_item(v)
		if (tuiles.mesh_library.get_item_name(it) if it >= 0 else "∅") != e[3]:
			n += 1
	return n


# ── LE MONDE PEINT (29 septembre 2026) ──────────────────────────────────────────────────────────────
#
# Trois greffons liront `world.json` : les cas sont calculés par la lecture de RÉFÉRENCE du cœur
# (`FormatMonde.lire`) et livrés à chacun ; le greffon Godot les passe ici avec SA lecture, écrite à part
# (sa source part chez l'acheteur, elle ne charge rien du cœur).
func _les_cas_de_monde() -> void:
	var frais = JSON.parse_string(JSON.stringify(FM.cas_d_epreuve()))
	for cible in GENERATEUR.CIBLES_MONDE:
		var ici = JSON.parse_string(FileAccess.get_file_as_string(cible)) if FileAccess.file_exists(cible) else null
		_vrai(ici != null and JSON.stringify(ici) == JSON.stringify(frais),
			"%s est absent ou PÉRIMÉ : relancer DEV_TOOLS/generer_cas_d_epreuve.gd" % cible)
	var cas: Array = frais["cases"]
	var refus := 0
	for c in cas:
		var lu := WorldFile.read(c["world"])
		if c["expected"].has("error"):
			refus += 1
			_vrai(lu.has("error"), "monde « %s » : le greffon devait REFUSER, il a lu %s" % [c["name"], lu])
		else:
			# Les deux côtés repassent par JSON, clés triées : l'ordre des clés et 2 contre 2.0 ne sont pas la question.
			_vrai(not lu.has("error") and _json_norme(lu) == _json_norme(c["expected"]),
				"monde « %s » : le greffon lit %s, attendu %s" % [c["name"], lu, c["expected"]])
	# ⚠ LES CAS EXERCENT CE QU'ILS NOMMENT : un cas bon, des refus, et dans le bon une cellule négative, une
	# couche cachée, une couche sans tuiles, une couche vide.
	_vrai(refus >= 6 and refus == cas.size() - 1, "les cas de monde : un bon, et au moins six refus")
	var bon: Array = cas[0]["expected"]["layers"]
	var negatif := false
	for l in bon:
		for p in l["cells"]:
			negatif = negatif or p[0] < 0 or p[1] < 0 or p[2] < 0
	_vrai(negatif and bon.any(func(l): return not l["visible"]) and bon.any(func(l): return l["tileset"] == null)
		and bon.any(func(l): return (l["cells"] as Array).is_empty()),
		"le cas bon porte une case négative, une couche cachée, une couche sans tuiles, une couche vide")


# ── 4 quinquies. L'ÉDITION DE LA PARITÉ DANS LA VUE (7 octobre 2026) : Extrude, Select des cases vides, la molette,
# Room from selection — par de vrais événements, une vraie caméra, une vraie annulation.
var _edition_finie := false
# ── 6 ter. L'EAU RECALCULÉE DE BOUT EN BOUT (7 octobre 2026, PARITE.md §12) : l'appli exporte l'île, sa mer et une
# rivière, en DEUX couches d'eau, avec leurs nappes CUITES (ce que fait l'écran : `FL.monde`, puis `EM.maillage` couche
# par couche) ; le greffon l'importe et REFAIT les nappes. Attendus :
#   - la nappe recalculée de chaque couche EST la nappe cuite relue du .glb (le sac, couleurs à 1/255 près) ;
#   - le branchement : pendant un geste rien ne part (la nappe se dit périmée), 0,5 s de calme puis un fil à part, la
#     nappe échangée, à jour ; la reprise sert ; une reprise plus lente que `auto_limit` COUPE le suivi (la nappe reste
#     périmée, l'inspecteur le dit) ; le bouton refait tout et rétablit le suivi.
var _eau_recalculee_finie := false


func _l_eau_recalculee_de_bout_en_bout(base: MeshLibrary) -> void:
	var dossier := ProjectSettings.globalize_path("user://test_eau_recalculee")
	_vider(dossier)
	DirAccess.make_dir_recursive_absolute(dossier)
	var f = JSON.parse_string(FileAccess.get_file_as_string("res://addons/marchingblocks_paint/water_conformance.json"))
	var ile := _ensemble(f["worlds"]["island"])
	var mer := Vector3i(-1, 2, -1)
	var source := Vector3i(4, 4, 4)
	var w := FL.monde(ile, [mer, source])
	var r := FM.exporter([{"nom": "Rock", "visible": true, "source": "a", "lot": base, "cases": ile.keys()}], dossier,
		"eau", "test", [
			{"nom": "Sea", "visible": true, "preset": "transparent", "sources": [mer],
				"maillage": EM.maillage([w["corps"][0]], ile)},
			{"nom": "River", "visible": true, "preset": "stylise", "sources": [source],
				"maillage": EM.maillage([w["corps"][1]], ile)}])
	_vrai(not r.has("erreur"), "l'appli exporte l'île et ses deux couches d'eau (%s)" % str(r.get("erreur", "")))
	var tenant := Node3D.new()
	root.add_child(tenant)
	var b := WorldFile.build(dossier.path_join("eau.mbworld/world.json"), tenant)
	_vrai(not b.has("error"), "le greffon importe l'île (%s)" % str(b.get("error", "")))
	if b.has("error"):
		tenant.free()
		_eau_recalculee_finie = true
		return
	var eaux: Array = (b["extras"] as Array).filter(func(x: Node) -> bool: return x.get_script() == WaterNode)
	_egal(eaux.map(func(x: Node) -> String: return str(x.name)), ["Water Sea", "Water River"], "deux couches d'eau posées")
	if eaux.size() != 2:
		tenant.free()
		_eau_recalculee_finie = true
		return
	var mene: Node = eaux[0]
	_vrai(eaux[1].leader() == mene, "la première couche d'eau mène le calcul de toutes")
	_vrai(not mene.stale(), "importée, la nappe cuite est à jour")
	# 1. LA NAPPE RECALCULÉE = LA NAPPE CUITE (le .glb relu ; couleurs à 1/255 : le .glb les range sur 8 bits).
	var dt: float = eaux[1].rebuild_water_now()
	var tol := Sac.TOL.duplicate()
	tol["color"] = 1.0 / 255.0 + 1e-6
	for i in 2:
		var cuite := _arrays_du_glb(eaux[i].mesh_path)
		var refaite: Dictionary = mene._base["arrays"][i]
		var s := Sac.meme_sac(Sac.triangles(cuite), Sac.triangles(refaite), tol) if not cuite.is_empty() else "illisible"
		_vrai(s == "", "%s : la nappe recalculée est la nappe cuite (%d triangles) %s" % [
			eaux[i].name, (refaite["i"] as PackedInt32Array).size() / 3, s])
		_vrai(eaux[i].sheet_mesh() == eaux[i]._rebuilt and eaux[i]._rebuilt.get_surface_count() == 1,
			"%s : elle est montrée à la place de la cuite" % eaux[i].name)
		_vrai(not eaux[i].stale(), "%s : à jour" % eaux[i].name)
	print("  eau recalculée : l'île, deux couches, %.3f s (entier)" % dt)
	# 2. LE BRANCHEMENT. Un geste : une case posée sur le cours de la rivière.
	var couche: Node = b["nodes"][0]
	var cours: Array = w["corps"][1]["cours"]
	var pres: Vector3i = cours[1]["case"] + Vector3i(0, 1, 0)
	couche.apply_cells([pres], [])
	_vrai(eaux[0].stale() and eaux[1].stale(), "une case peinte : les deux nappes se disent périmées")
	mene.tick(10000)
	_vrai(mene._pending and mene._task == -1, "le geste vu : rien ne part encore")
	_vrai(not eaux[1]._get_configuration_warnings().is_empty(), "l'inspecteur dit la nappe périmée")
	mene.tick(10400)
	_vrai(mene._task == -1, "moins de 0,5 s de calme : rien ne part")
	mene.tick(10700, true)
	_vrai(mene._task == -1, "un bouton de souris tenu (un geste en cours) : rien ne part")
	var prise_avant: Mesh = eaux[1].sheet_mesh()
	mene.tick(10800)
	_vrai(mene._task != -1, "0,5 s de calme, plus de geste : le calcul part sur un fil à part")
	_vrai(eaux[1].sheet_mesh() == prise_avant, "pendant le calcul, la nappe montrée ne change pas")
	_attendre(mene)
	mene.tick(10900)
	_vrai(mene._task == -1 and not mene._pending, "le calcul fini : rien d'autre à faire")
	_vrai(not eaux[0].stale() and not eaux[1].stale(), "les deux nappes sont à jour des cases")
	_vrai(eaux[1].sheet_mesh() != prise_avant, "la nappe de la rivière est échangée")
	_vrai(eaux[1]._get_configuration_warnings().is_empty(), "l'inspecteur ne dit plus rien")
	var entier := {"layers": [mene.world_cells().keys()], "sources": [mer, source], "counts": [1, 1], "base": {}}
	WaterNode._compute(entier)
	for i in 2:
		_egal(Sac.meme_sac(Sac.triangles(entier["out"]["arrays"][i]), Sac.triangles(mene._base["arrays"][i])), "",
			"après le geste, la couche %d est le calcul entier" % i)
	print("  eau recalculée : un geste, %.3f s (reprise : %s)" % [mene.last_seconds, mene.last_reused])
	_vrai(mene.last_reused.begins_with("1 of 2 sources, 1 of 2 layers"),
		"la reprise sert : la mer (loin du geste) reprise, sa nappe gardée (%s)" % mene.last_reused)
	# 3. LA COUPURE : une reprise plus lente que `auto_limit` coupe le suivi automatique.
	mene.auto_limit = 0.0
	couche.apply_cells([], [pres])
	mene.tick(20000)
	mene.tick(20600)
	_attendre(mene)
	mene.tick(20700)
	_vrai(mene.paused, "une reprise plus lente que la limite : le suivi se coupe")
	couche.apply_cells([pres], [])
	mene.tick(21000)
	mene.tick(22000)
	_vrai(mene._task == -1 and eaux[1].stale(), "coupé : un geste ne relance rien, la nappe reste périmée")
	var dit: PackedStringArray = eaux[1]._get_configuration_warnings()
	_vrai(not dit.is_empty() and dit[0].contains("Rebuild water"), "l'inspecteur dit d'appuyer sur « Rebuild water » (%s)" % [dit])
	mene.auto_limit = 1.0
	eaux[1].rebuild_water_now()
	_vrai(not mene.paused and not eaux[1].stale(), "le bouton refait l'eau, et rétablit le suivi")
	# Le bouton est un vrai bouton de l'inspecteur.
	var bouton := false
	for p in eaux[1].get_property_list():
		if p["name"] == "rebuild_water_button" and p["hint"] == PROPERTY_HINT_TOOL_BUTTON:
			bouton = true
	_vrai(bouton, "« Rebuild water » est un bouton de l'inspecteur")
	tenant.free()
	_eau_recalculee_finie = true


## Attend la fin du calcul d'eau d'un nœud (le fil à part).
func _attendre(mene: Node) -> void:
	var t := Time.get_ticks_msec()
	while mene._task != -1 and not WorkerThreadPool.is_task_completed(mene._task) and Time.get_ticks_msec() - t < 60000:
		OS.delay_msec(5)


## Les tableaux de la nappe d'un .glb (relue par l'importeur de Godot, sans passer par l'ArrayMesh) : {v, n, c, uv, i}.
func _arrays_du_glb(chemin: String) -> Dictionary:
	var doc := GLTFDocument.new()
	var etat := GLTFState.new()
	if doc.append_from_file(chemin, etat) != OK or etat.get_meshes().is_empty():
		return {}
	var a: Array = ((etat.get_meshes()[0] as GLTFMesh).mesh as ImporterMesh).get_surface_arrays(0)
	return {"v": a[Mesh.ARRAY_VERTEX], "n": a[Mesh.ARRAY_NORMAL], "c": a[Mesh.ARRAY_COLOR], "uv": a[Mesh.ARRAY_TEX_UV],
		"i": a[Mesh.ARRAY_INDEX]}


var _monde_complet_fini := false


func _l_edition_de_parite_dans_la_vue() -> void:
	var tenant := Node3D.new()
	root.add_child(tenant)
	var monde: Node3D = World.new()
	tenant.add_child(monde)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.look_at_from_position(Vector3(2.5, 14, 2.5), Vector3(2.5, 0, 2.5), Vector3.FORWARD)
	var ed: Node = Editeur.new()
	root.add_child(ed)
	var annul := UndoRedo.new()
	ed.undo = annul
	ed.world = monde
	var ecran := func(case_: Vector3i) -> Vector2:
		return cam.unproject_position(Vector3(case_) + Vector3(0.5, 0.0, 0.5))
	var clic := func(pos: Vector2, appuye: bool) -> bool:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = appuye
		b.position = pos
		return ed.input(cam, b)
	var bouge := func(pos: Vector2) -> bool:
		var m := InputEventMouseMotion.new()
		m.position = pos
		return ed.input(cam, m)
	var molette := func(haut: bool, alt := false, maj := false, ctrl := false) -> bool:
		var pris := false
		for appuye in [true, false]:
			var b := InputEventMouseButton.new()
			b.button_index = MOUSE_BUTTON_WHEEL_UP if haut else MOUSE_BUTTON_WHEEL_DOWN
			b.pressed = appuye
			b.alt_pressed = alt
			b.shift_pressed = maj
			b.ctrl_pressed = ctrl
			b.position = Vector2(100, 100)
			pris = ed.input(cam, b) if appuye else pris and ed.input(cam, b)
		return pris
	var sol: Array = []
	for x in 3:
		for z in 3:
			sol.append(Vector3i(x, 0, z))
	monde.apply_cells(sol, [])
	# EXTRUDE sans sélection : la matière de l'étage monte d'un cran, l'étage suit, un Ctrl+Z rend tout.
	ed.extrude("up", "place")
	_egal(monde.cells().size(), 18, "Extrude up sans sélection pose l'étage du dessus de la matière de l'étage")
	_egal(monde.floor_y, 1, "et l'étage suit")
	annul.undo()
	_vrai(monde.cells().size() == 9 and monde.floor_y == 0, "un Ctrl+Z reprend les cases ET l'étage")
	# FACING : rien n'est sous le sol (pas de matière derrière vers le haut) ; ses bords +X regardent l'air, adossés à la
	# matière — le premier des sens à égalité (+X avant −X, +Z, −Z) : trois cases en x = 3, l'étage ne bouge pas.
	ed.extrude("facing", "place")
	_vrai(monde.cells().size() == 12 and monde.cells().has(Vector3i(3, 0, 1)) and monde.floor_y == 0,
		"Extrude facing : le sol plat s'étend vers +X (le premier sens à égalité), l'étage reste")
	annul.undo()
	# SELECT DES CASES VIDES : le pinceau prend l'air seulement avec la case cochée.
	ed.set_mode("select")
	clic.call(ecran.call(Vector3i(6, 0, 6)), true)
	clic.call(ecran.call(Vector3i(6, 0, 6)), false)
	_vrai(ed.selection.is_empty(), "Select sur une case vide : rien, sans « Select empty cells too »")
	ed.select_empty = true
	clic.call(ecran.call(Vector3i(6, 0, 6)), true)
	clic.call(ecran.call(Vector3i(6, 0, 6)), false)
	_egal(ed.selection, {Vector3i(6, 0, 6): true}, "avec la case cochée, le pinceau prend la case VIDE")
	# LA MOLETTE : seule et sans geste, elle est laissée au zoom de l'éditeur.
	ed.set_mode("add")
	_vrai(not molette.call(true), "la molette seule, sans geste : laissée à l'éditeur (zoom)")
	_vrai(molette.call(true, false, false, true) and monde.floor_y == 1, "Ctrl + molette : l'étage")
	annul.undo()
	_egal(monde.floor_y, 0, "l'étage changé à la molette s'annule")
	_vrai(molette.call(true, true) and ed.brush_size == 2, "Add : Alt + molette, la taille du pinceau")
	var forme_avant: String = ed.shape
	_vrai(molette.call(true, false, true) and ed.shape != forme_avant, "Add : Maj + molette, la forme suivante")
	ed.shape = "sphere"
	ed.brush_size = 1
	# Avec une sélection et un outil de sélection : Alt ↑ élargit à plat, Alt ↓ rogne le bord, Maj étend.
	ed.set_mode("select")
	ed._set_selection({Vector3i(1, 0, 1): true})
	_vrai(molette.call(true, true) and ed.selection.size() == 5, "Alt + molette ↑ : Widen, une couronne à plat")
	_vrai(molette.call(false, true) and ed.selection.keys() == [Vector3i(1, 0, 1)], "Alt + molette ↓ : Shrink, le bord part")
	var cases_avant: int = monde.cells().size()
	_vrai(molette.call(true, false, true) and ed.selection.size() == 2 and monde.cells().size() == cases_avant,
		"Maj + molette ↑ : Extend selection, rien n'est posé")
	_egal(monde.floor_y, 1, "et l'étage suit l'extension")
	annul.undo()
	ed.clear_selection()
	# Pendant un geste : la hauteur d'un Rect qui devient une boîte.
	ed.set_mode("rect")
	clic.call(ecran.call(Vector3i(0, 0, 0)), true)
	bouge.call(ecran.call(Vector3i(2, 0, 2)))
	_vrai(molette.call(true) and molette.call(true), "pendant un Rect, la molette seule est PRISE")
	clic.call(ecran.call(Vector3i(2, 0, 2)), false)
	_egal(ed.selection.size(), 27, "un Rect de 3 × 3 haussé de deux crans : une boîte de 3 × 3 × 3")
	# En Navigate, jamais.
	ed.set_navigating(true)
	_vrai(not molette.call(true, true), "en Navigate, la molette n'est jamais prise")
	ed.set_navigating(false)
	# ROOM FROM SELECTION : une empreinte de 3 × 3 peinte dans le vide, montée d'un étage — 26 cases de coque.
	var empreinte := {}
	for x in range(10, 13):
		for z in range(10, 13):
			empreinte[Vector3i(x, 0, z)] = true
	ed._set_selection(empreinte)
	ed.room_floors = 1
	ed.room_up = true
	var n0: int = monde.cells().size()
	ed.room_from_selection()
	_egal(monde.cells().size() - n0, 26, "Room from selection : sol, plafond et murs autour d'une case de vide")
	annul.undo()
	_egal(monde.cells().size(), n0, "et un Ctrl+Z la reprend")
	ed._set_selection({Vector3i(20, 0, 20): true})
	ed.room_from_selection()
	_vrai(ed.status.contains("too thin"), "une empreinte sans dedans est refusée, et c'est dit")
	ed.world = null
	ed.queue_free()
	cam.queue_free()
	tenant.queue_free()
	annul.free()
	_edition_finie = true


# ── 6 bis. UN MONDE COMPLET DE BOUT EN BOUT (7 octobre 2026) : l'appli exporte (FM.exporter) deux couches dont une
# ANIMÉE, un lac, un fondu actif et deux plants ; le greffon l'importe (WorldFile.build). Ce qui se VOIT se juge à
# l'image (capture, avec fenêtre) ; ici, ce que le greffon a POSÉ : la nappe et son preset, le passage par-dessus les
# matériaux, les plants, le matériau animé et son espace du format, la nappe qui se dit périmée.
func _le_monde_complet_de_bout_en_bout(base: MeshLibrary) -> void:
	var dossier := ProjectSettings.globalize_path("user://test_monde_complet")
	_vider(dossier)
	DirAccess.make_dir_recursive_absolute(dossier.path_join("images"))
	var images: Array = []
	for k in 3:
		var img := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
		img.fill([Color.RED, Color.GREEN, Color.BLUE][k])
		var chemin := dossier.path_join("images/frame_%d.png" % k)
		img.save_png(chemin)
		images.append(chemin)
	var roche := StandardMaterial3D.new()
	roche.resource_name = "rock"
	var anime := StandardMaterial3D.new()
	anime.resource_name = "glow"
	anime.set_meta("extras", {"mb_animation": {"albedo": {"images": {"images": images, "ips": 4.0}}}})
	var lots: Array = []
	for mat in [roche, anime]:
		var lot := MeshLibrary.new()
		for id in base.get_item_list():
			var m: Mesh = base.get_item_mesh(id).duplicate()
			for s in m.get_surface_count():
				m.surface_set_material(s, mat)
			lot.create_item(id)
			lot.set_item_name(id, base.get_item_name(id))
			lot.set_item_mesh(id, m)
		lots.append(lot)
	var c_roche: Array = []
	var c_anime: Array = []
	for x in 8:
		for z in 7:
			for y in 2:
				if y == 1 and x == 3 and z == 3:
					continue
				(c_anime if x >= 6 and y == 1 else c_roche).append(Vector3i(x, y, z))
	var toutes := {}
	for c in c_roche + c_anime:
		toutes[c] = true
	var sources := [Vector3i(3, 3, 3)]
	var nappe := EM.maillage(FL.monde(toutes, sources)["corps"], toutes)
	var glb := dossier.path_join("box.glb")
	var racine := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.name = "box"
	mi.mesh = BoxMesh.new()
	racine.add_child(mi)
	var doc := GLTFDocument.new()
	var etat := GLTFState.new()
	doc.append_from_scene(racine, etat)
	doc.write_to_filesystem(etat, glb)
	racine.free()
	var feuillage := FE.vers_donnees([FE.modele(4, "Box", glb)], [FE.plant(1, 4, Vector3(1.5, 2.0, 1.5), 0.5, 1.0, "sol"),
		FE.plant(2, 4, Vector3(5.5, 2.0, 5.5), 0.0, 1.2, "sol")])
	var r := FM.exporter([{"nom": "Rock", "visible": true, "source": "a", "lot": lots[0], "cases": c_roche},
		{"nom": "Glow", "visible": true, "source": "b", "lot": lots[1], "cases": c_anime}], dossier, "complet", "test",
		[{"nom": "Lake", "visible": true, "maillage": nappe, "preset": "lave", "sources": sources}],
		{"etat": {"paires": {"1|2": {"actif": true, "couvre": {"1": TR.reglages({}), "2": TR.reglages({})}}}, "choix": {}},
		"ids": ["1", "2"], "representants": [{"image": null, "couleur": Color.GRAY, "echelle": 1.0, "rugosite": 0.9},
		{"image": null, "couleur": Color.YELLOW, "echelle": 1.0, "rugosite": 1.0}]}, feuillage)
	_vrai(not r.has("erreur"), "l'appli exporte le monde complet (%s)" % str(r.get("erreur", "")))
	var tenant := Node3D.new()
	root.add_child(tenant)
	var b := WorldFile.build(dossier.path_join("complet.mbworld/world.json"), tenant)
	_vrai(not b.has("error"), "le greffon importe le monde complet (%s)" % str(b.get("error", "")))
	if b.has("error"):
		tenant.queue_free()
		_monde_complet_fini = true
		return
	var par_nom := {}
	for x in b["extras"]:
		par_nom[str(x.name)] = x
	_egal(par_nom.keys(), ["Water Lake", "Transitions", "Foliage"], "à côté des couches : l'eau, les transitions, le feuillage")
	# L'EAU : la nappe cuite, sous le preset de son aspect (« lava »), et l'artiste peut mettre le sien.
	var eau: Node3D = par_nom.get("Water Lake")
	var feuille: MeshInstance3D = eau.get_child(0, true) if eau != null else null
	_vrai(feuille != null and feuille.mesh != null and feuille.mesh.get_surface_count() > 0, "la nappe cuite est posée")
	if feuille != null:
		var sm := feuille.material_override as ShaderMaterial
		_vrai(sm != null and sm.shader.code == Shaders.WATER["lava"], "sous le preset de son aspect (lava)")
		var a_moi := StandardMaterial3D.new()
		eau.material = a_moi
		eau.rebuild()
		_vrai(feuille.material_override == a_moi, "le matériau de l'artiste remplace le preset")
	_vrai(eau != null and not eau.stale(), "la nappe est à jour des cases importées")
	var couches: Array = b["nodes"]
	couches[0].apply_cells([Vector3i(3, 1, 3)], [])
	_vrai(eau != null and eau.stale(), "une case peinte : la nappe se dit périmée")
	_vrai(eau != null and eau.water_cells().is_empty(), "et l'eau recalculée (le cratère comblé) n'a plus de case")
	couches[0].apply_cells([], [Vector3i(3, 1, 3)])
	_vrai(eau != null and not eau.stale() and eau.water_cells().size() == 1, "le cratère rendu : la nappe redevient juste")
	# LES TRANSITIONS : la table des deux directions, le passage posé sur les matériaux des tuiles des deux couches.
	var tr: Node = par_nom.get("Transitions")
	if tr != null:
		tr.refresh()
		_egal(tr.table().keys(), ["0|1", "1|0"], "la paire active, ses deux directions")
		var portes := 0
		var tous := 0
		for l in couches:
			for m in l.tile_materials():
				tous += 1
				if (m as Material).next_pass == tr.material():
					portes += 1
		_vrai(tous > 0 and portes == tous, "le passage est posé par-dessus TOUS les matériaux des tuiles (%d sur %d)" % [portes, tous])
		var origine: Vector3i = tr.material().get_shader_parameter("origine")
		_egal(origine, Vector3i(-6, -6, -6), "la texture des cases : la boîte des cases élargie de 6")
		tr.enabled = false
		tr.refresh()
		_vrai(couches[0].tile_materials().all(func(m): return (m as Material).next_pass == null), "éteint, il est retiré")
	# LE FEUILLAGE : deux plants, posés comme la règle le dit.
	var fo: Node3D = par_nom.get("Foliage")
	if fo != null:
		_egal(fo.drawn(4), 2, "les deux plants sont dessinés")
		# ⚠ SANS RENDU (headless), une MultiMesh ne rend pas ce qu'on lui a donné : on éprouve ce que le nœud lui DONNE.
		var m: Dictionary = fo.models_by_id()[4]
		var inst: Array = fo.instances(m, fo.plant_list(), Transform3D.IDENTITY)
		_vrai((inst[0][0] as Transform3D).is_equal_approx(Foliage.transform(m, fo.plant_list()[0])),
			"le premier plant est à sa pose (%s)" % inst[0][0])
		var vent: Color = inst[1][1]
		_vrai(is_equal_approx(vent.r, 2.0) and is_equal_approx(vent.a, 0.5) and is_equal_approx(vent.g, 1.2),
			"ses données de vent : le sol, la hauteur (× 1,2), l'amplitude (%s)" % vent)
		fo.position = Vector3(0, 10, 0)
		fo.scale = Vector3.ONE * 2.0
		vent = fo.instances(m, fo.plant_list(), Transform3D.IDENTITY)[1][1]
		_vrai(is_equal_approx(vent.r, 14.0) and is_equal_approx(vent.g, 2.4),
			"le monde déplacé et à case de 2 : le sol et la hauteur en monde de Godot (%s)" % vent)
	# LA TEXTURE ANIMÉE : le matériau de la seconde couche est animé, ses trois images dans un tableau, et il sait où
	# la couche se tient.
	var anim_mat: ShaderMaterial = null
	var lib: MeshLibrary = couches[1].get_node("Tiles").mesh_library
	for id in lib.get_item_list():
		var mt := lib.get_item_mesh(id).surface_get_material(0)
		if mt is ShaderMaterial and mt.has_meta("mb_animation"):
			anim_mat = mt
	_vrai(anim_mat != null, "la couche animée porte le matériau animé")
	if anim_mat != null:
		var tab = anim_mat.get_shader_parameter("albedo_images")
		_vrai(tab is Texture2DArray and (tab as Texture2DArray).get_layers() == 3, "ses trois images, en tableau")
		couches[1].cell_size = 2.0
		couches[1].position = Vector3(5, 0, 0)
		# La notification de pose est différée à l'image suivante : on la rend ici comme le moteur la rendra.
		couches[1].notification(Node3D.NOTIFICATION_TRANSFORM_CHANGED)
		var f: Projection = anim_mat.get_shader_parameter("mb_world_to_format")
		var attendu: Transform3D = couches[1].format_space()
		_vrai(f.x.is_equal_approx(Vector4(attendu.basis.x.x, attendu.basis.x.y, attendu.basis.x.z, 0.0))
			and is_equal_approx(f.w.x, attendu.origin.x) and is_equal_approx(attendu.origin.x, -2.5),
			"mb_world_to_format suit la pose et la case du nœud (%s)" % f)
	_vrai(not (couches[0].tile_materials()[0] as Material).has_meta("mb_animation"), "la roche, elle, n'est pas animée")
	# ⚠ LIBÉRÉ TOUT DE SUITE : des nœuds déplacés attendent leur notification de pose ; libérés au moment où le test
	# quitte, ils laissaient une erreur de liste à la sortie.
	tenant.free()
	_monde_complet_fini = true


# ── 6 ter. LE PINCEAU DE PLANTATION DANS LA VUE (finitions, 7 octobre 2026) ────────────────────────────────────────
# Le monde complet exporté par l'appli au-dessus (deux couches du témoin, un lac dans un cratère, deux plants), réimporté ;
# l'outil Plant mené par de VRAIS clics à travers une caméra, une vraie annulation. Les attendus viennent d'ailleurs que
# du code éprouvé : la surface du témoin à 1,75 (un quart de case sous le dessus des cases, charte §5), le bord des
# cases à x = 8, le lac du cratère en (3, 1, 3), des distances recalculées ici.
var _plantation_finie := false
const Planting := preload("res://addons/marchingblocks_paint/mb_planting.gd")
const Barre := preload("res://addons/marchingblocks_paint/mb_toolbar.gd")


func _le_pinceau_de_plantation() -> void:
	var chemin := ProjectSettings.globalize_path("user://test_monde_complet").path_join("complet.mbworld/world.json")
	var tenant := Node3D.new()
	root.add_child(tenant)
	var b := WorldFile.build(chemin, tenant)
	_vrai(not b.has("error"), "le monde complet se réimporte (%s)" % str(b.get("error", "")))
	if b.has("error"):
		tenant.free()
		_plantation_finie = true
		return
	var couches: Array = b["nodes"]
	var fo: Node3D = tenant.get_node_or_null("Foliage")
	_vrai(fo != null, "le monde a son feuillage")
	if fo == null:
		tenant.free()
		_plantation_finie = true
		return
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.look_at_from_position(Vector3(4, 40, 3.5), Vector3(4, 0, 3.5), Vector3.FORWARD)
	var ed: Node = Editeur.new()
	root.add_child(ed)
	var annul := UndoRedo.new()
	ed.undo = annul
	ed.world = couches[0]
	ed.plant_draw.seed = 7
	var ecran := func(p: Vector3) -> Vector2: return cam.unproject_position(p)
	var clic := func(p: Vector3, ctrl := false, maj := false) -> bool:
		var pris := true
		for appuye in [true, false]:
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.pressed = appuye
			e.ctrl_pressed = ctrl
			e.shift_pressed = maj
			e.position = ecran.call(p)
			pris = ed.input(cam, e) and pris
		return pris
	var plants := func() -> Array: return fo.plant_list()
	ed.set_mode("plant")
	_egal(ed.current_plant_model(), 4, "sans choix, l'outil plante le premier modèle du feuillage")
	# UN CLIC, « Planted · free », au milieu du plateau : un plant, sur la surface VUE des tuiles (1,75), pas sur le
	# dessus des cases (2).
	# ⚠ HORS DU CENTRE D'UNE CASE : un point visé arrondi au centre de sa case passait muet quand tous les clics étaient
	# en x,5 (mutation vue).
	_vrai(clic.call(Vector3(1.3, 2, 4.7)), "le clic de l'outil Plant est pris")
	_egal(plants.call().size(), 3, "un clic plante un plant (%s)" % ed.status)
	if plants.call().size() == 3:
		var p: Vector3 = plants.call()[2]["p"]
		_vrai(absf(p.y - 1.75) < 0.02, "il est sur la surface des tuiles, à 1,75 (y = %.3f)" % p.y)
		_vrai(Vector2(p.x, p.z).distance_to(Vector2(1.3, 4.7)) < 0.02, "là où l'on a cliqué (%s)" % p)
		_egal(int(plants.call()[2]["model"]), 4, "du modèle choisi")
		_egal(plants.call()[2]["mode"], "ground", "planté")
	annul.undo()
	_egal(plants.call().size(), 2, "Ctrl+Z reprend le plant")
	annul.redo()
	_egal(plants.call().size(), 3, "Ctrl+Y le rend")
	# AU BORD (x = 8 est le bord des cases) : « free » refuse, et le dit ; « overflow » accepte.
	clic.call(Vector3(7.8, 2, 2.5))
	_egal(plants.call().size(), 3, "au bord, « free » refuse")
	_vrai(ed.status.contains("edge"), "et le dit (%s)" % ed.status)
	ed.plant_mode = "overflow"
	clic.call(Vector3(7.8, 2, 2.5))
	_egal(plants.call().size(), 4, "au bord, « overflow » plante (%s)" % ed.status)
	# DANS LE LAC du cratère (3, 1, 3) : refusé, même en « overflow ».
	clic.call(Vector3(3.5, 2, 3.5))
	_egal(plants.call().size(), 4, "dans l'eau du cratère, refusé")
	_vrai(ed.status.contains("water"), "et le dit (%s)" % ed.status)
	# SUR UN PLANT : refusé (le doublon).
	clic.call(Vector3(1.5, 2, 1.5))
	_egal(plants.call().size(), 4, "sur un plant existant, refusé")
	_vrai(ed.status.contains("already there") or ed.status.contains("too close"), "et le dit (%s)" % ed.status)
	# DANS L'AIR, sur le plan de l'étage (0) : au-dessus du vide, accepté à y = 0 ; dans la matière, refusé.
	ed.plant_mode = "air"
	clic.call(Vector3(11.5, 0, 3.5))
	_egal(plants.call().size(), 5, "dans l'air, au-dessus du vide : planté (%s)" % ed.status)
	if plants.call().size() == 5:
		var a: Dictionary = plants.call()[4]
		_vrai(absf((a["p"] as Vector3).y) < 1e-4 and a["mode"] == "air", "sur le plan de l'étage, en mode air (%s)" % a)
	clic.call(Vector3(5.5, 0, 1.5))
	_egal(plants.call().size(), 5, "dans l'air mais dans la matière : refusé")
	_vrai(ed.status.contains("inside the matter"), "et le dit (%s)" % ed.status)
	# LE MODÈLE CHOISI : un second modèle, plus large ; l'outil plante celui qu'on lui donne.
	var modeles: Array = fo.models.duplicate(true)
	var second: Dictionary = (modeles[0] as Dictionary).duplicate()
	second["id"] = 9
	second["name"] = "Wide"
	second["footprint"] = 1.0
	modeles.append(second)
	fo.models = modeles
	ed.plant_model = 9
	ed.plant_mode = "free"
	clic.call(Vector3(4.5, 2, 1.5))
	_egal(int(plants.call()[-1]["model"]), 9, "le modèle choisi est celui qui est planté (%s)" % ed.status)
	# LE PINCEAU (Ctrl) : un coup, puis la souris traînée plus loin que 0,4 rayon : un second coup ; UN Ctrl+Z pour le
	# trait entier. Les acceptés se respectent (« free » : jamais deux empreintes qui empiètent), tous sur le plateau.
	ed.plant_model = 4
	ed.plant_radius = 1.5
	ed.plant_tries = 20
	var avant: int = plants.call().size()
	var appui := InputEventMouseButton.new()
	appui.button_index = MOUSE_BUTTON_LEFT
	appui.pressed = true
	appui.ctrl_pressed = true
	appui.position = ecran.call(Vector3(2.0, 2, 1.5))
	ed.input(cam, appui)
	var apres_un: int = plants.call().size()
	var glisse := InputEventMouseMotion.new()
	glisse.position = ecran.call(Vector3(5.0, 2, 2.5))
	_vrai(ed.input(cam, glisse), "pendant un trait de pinceau, le glissé est pris")
	var apres_deux: int = plants.call().size()
	var lache: InputEventMouseButton = appui.duplicate()
	lache.pressed = false
	ed.input(cam, lache)
	_vrai(apres_un > avant, "un coup de pinceau plante (%d)" % (apres_un - avant))
	_vrai(apres_deux > apres_un, "le glissé plus loin donne un second coup (%d)" % (apres_deux - apres_un))
	var tous: Array = plants.call()
	var empietent := 0
	var hors := 0
	var par_id: Dictionary = Planting.models_of(fo)
	for i in range(avant, tous.size()):
		var p: Vector3 = tous[i]["p"]
		if p.x < 0.0 or p.x > 8.0 or p.z < 0.0 or p.z > 7.0 or absf(p.y - 1.75) > 0.05:
			hors += 1
		for j in tous.size():
			if j == i or tous[j]["mode"] == "air":
				continue
			var q: Vector3 = tous[j]["p"]
			var r_i: float = float(par_id[int(tous[i]["model"])]["footprint"]) * float(tous[i]["scale"])
			var r_j: float = float(par_id[int(tous[j]["model"])]["footprint"]) * float(tous[j]["scale"])
			if Vector2(p.x - q.x, p.z - q.z).length() < r_i + r_j - 1e-4:
				empietent += 1
	_egal(hors, 0, "tous les plants du pinceau sont sur le plateau, à la surface")
	_egal(empietent, 0, "aucun plant du pinceau n'empiète sur une autre empreinte (« free »)")
	annul.undo()
	_egal(plants.call().size(), avant, "UN Ctrl+Z reprend le trait entier (les deux coups)")
	annul.redo()
	_egal(plants.call().size(), apres_deux, "et Ctrl+Y le rend")
	# EFFACER (Maj) : les plants à moins d'un rayon de (2, 1,5) partent, les autres restent ; Ctrl+Z les rend.
	var centre := Vector3(2.0, 1.75, 1.5)
	var dedans := 0
	for pl in plants.call():
		var q: Vector3 = pl["p"]
		if Vector2(q.x - centre.x, q.z - centre.z).length() <= ed.plant_radius \
				and q.distance_to(centre) <= ed.plant_radius + 0.5:
			dedans += 1
	var n0: int = plants.call().size()
	clic.call(Vector3(2.0, 2, 1.5), false, true)
	_vrai(dedans > 0 and plants.call().size() == n0 - dedans, "Maj + clic efface les %d plants du pinceau, pas plus (%s)"
		% [dedans, ed.status])
	annul.undo()
	_egal(plants.call().size(), n0, "Ctrl+Z les rend")
	# LA MOLETTE de l'outil : Alt la taille du pinceau, Maj sa densité.
	var molette := func(alt: bool, maj: bool) -> bool:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_WHEEL_UP
		e.pressed = true
		e.alt_pressed = alt
		e.shift_pressed = maj
		return ed.input(cam, e)
	_vrai(molette.call(true, false) and is_equal_approx(ed.plant_radius, 2.0), "Alt + molette : le pinceau grandit")
	_vrai(molette.call(false, true) and ed.plant_tries == 21, "Maj + molette : la densité")
	# LA BARRE : les réglages de l'outil ne paraissent qu'avec lui ; le menu des modèles les nomme, coche le courant, et
	# en choisit un autre.
	var barre: HBoxContainer = Barre.new()
	barre.set("editor", ed)
	var plant_bar: Control = barre.get("_plant_bar")
	_vrai(plant_bar.visible, "l'outil Plant : sa barre paraît")
	(barre.get("_plant_modes")["overflow"] as Button).pressed.emit()
	_egal(ed.plant_mode, "overflow", "un clic sur « Planted · overflow » choisit le mode")
	var menu: MenuButton = barre.get("_plant_model")
	barre.call("_fill_plant_models")
	var popup := menu.get_popup()
	var noms: Array = []
	for i in popup.item_count:
		noms.append(popup.get_item_text(i))
	_vrai(noms.has("Box") and noms.has("Wide") and noms.has("Random rotation"), "le menu nomme les modèles (%s)" % str(noms))
	_vrai(popup.is_item_checked(popup.get_item_index(4)) and not popup.is_item_checked(popup.get_item_index(9)),
		"et coche le courant")
	popup.id_pressed.emit(9)
	_egal(ed.plant_model, 9, "le menu choisit un autre modèle")
	_egal(menu.text, "Wide", "la barre nomme le modèle courant")
	popup.id_pressed.emit(-2)
	_vrai(not ed.plant_random_yaw, "« Random rotation » se décoche")
	ed.set_mode("add")
	_vrai(not plant_bar.visible, "un autre outil : la barre de plantation disparaît")
	barre.free()
	# SANS FEUILLAGE : l'outil le dit, rien ne casse.
	tenant.remove_child(fo)
	ed.set_mode("plant")
	clic.call(Vector3(1.5, 2, 4.5))
	_vrai(ed.status.contains("no MarchingBlocksFoliage"), "un monde sans feuillage : c'est dit (%s)" % ed.status)
	fo.free()
	ed.world = null
	ed.free()
	cam.free()
	annul.free()
	tenant.free()
	_plantation_finie = true


func _vider(d: String) -> void:
	if not DirAccess.dir_exists_absolute(d):
		return
	for f in DirAccess.get_files_at(d):
		DirAccess.remove_absolute(d.path_join(f))
	for sd in DirAccess.get_directories_at(d):
		_vider(d.path_join(sd))
	DirAccess.remove_absolute(d)


func _json_norme(v: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(v)), "", true)


## L'appli exporte un monde de trois couches, le greffon le rebâtit : mêmes cases, même visibilité, mêmes
## poses que l'appli, et la couche sans tuiles arrive sans tuiles, et le DIT.
func _le_monde_de_bout_en_bout(lot: MeshLibrary, pleines: Dictionary, attendu: Array) -> void:
	var glace: Array = [Vector3i(40, 0, 40), Vector3i(41, 0, 40), Vector3i(-3, -1, 2)]
	var brouillon: Array = [Vector3i(0, 5, 0)]
	var couches: Array = [
		{"nom": "Rock", "visible": true, "source": "temoin", "lot": lot, "cases": pleines.keys()},
		{"nom": "Ice", "visible": false, "source": "temoin", "lot": lot, "cases": glace},
		{"nom": "Draft", "visible": true, "source": "", "lot": null, "cases": brouillon},
	]
	var dossier := ProjectSettings.globalize_path("user://test_monde")
	# Un dossier propre : les restes d'un passage précédent fausseraient le compte des jeux écrits.
	_vider(dossier.path_join("my_world.mbworld"))
	var r: Dictionary = FM.exporter(couches, dossier, "My World", "MarchingBlocks test")
	_vrai(not r.has("erreur"), "l'export du monde échoue : %s" % r.get("erreur", ""))
	if r.has("erreur"):
		return
	# ⚠ COMPTÉ SUR LE DISQUE, pas dans le bilan : le bilan compte par source et restait à 1 même quand
	# chaque couche réécrivait son propre dossier (mutation muette, vue).
	var jeux_ecrits := Array(DirAccess.get_directories_at(str(r["dossier"]))).filter(
		func(d: String) -> bool: return d.ends_with(".mbset"))
	_egal(jeux_ecrits.size(), 1, "deux couches de même source partagent UN dossier de tuiles (%s)" % str(jeux_ecrits))
	_egal(r["sans_tuiles"], ["Draft"], "la couche sans tuiles est nommée")
	var chemin: String = str(r["dossier"]).path_join("world.json")
	var tenant := Node3D.new()
	root.add_child(tenant)
	var b := WorldFile.build(chemin, tenant)
	_vrai(not b.has("error"), "le greffon ne rebâtit pas le monde : %s" % b.get("error", ""))
	if b.has("error"):
		tenant.queue_free()
		return
	var noeuds: Array = b["nodes"]
	_egal(noeuds.size(), 3, "une couche, un nœud, dans l'ordre")
	_egal(b["without_tiles"], ["Draft"], "le greffon DIT quelle couche arrive sans tuiles")
	for i in noeuds.size():
		var n: Node3D = noeuds[i]
		var voulu := {}
		for c in couches[i]["cases"]:
			voulu[c] = true
		_egal(n.cells(), voulu, "couche %s : les cases reviennent à l'identique" % couches[i]["nom"])
		_egal(n.visible, couches[i]["visible"], "couche %s : la visibilité revient" % couches[i]["nom"])
	_egal(noeuds[2].last_report()["error"], "no tileset chosen", "la couche sans tuiles n'en invente aucune")
	# Les poses de la couche Rock : exactement celles du peintre de l'appli (la même référence qu'au-dessus).
	var tuiles := (noeuds[0] as Node3D).get_node("Tiles") as GridMap
	var lib: MeshLibrary = tuiles.mesh_library
	var ecarts := 0
	for e in attendu:
		var id: int = tuiles.get_cell_item(Vector3i(e[0], e[1], e[2]))
		if id < 0 or lib.get_item_name(id) != e[3]:
			ecarts += 1
	_egal(ecarts, 0, "couche Rock rebâtie : sommets où le greffon ne pose pas ce que l'appli pose")
	_egal(tuiles.get_used_cells().size(), attendu.size(), "couche Rock rebâtie : rien de plus")
	_egal((noeuds[1] as Node3D).last_report()["error"], "", "la couche Ice (cachée) charge le jeu partagé")
	tenant.queue_free()


func _fin() -> void:
	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	print("VERDICT : %s" % ("OK" if _echecs == 0 else "ÉCHEC"))
	quit(0 if _echecs == 0 else 1)


func _vrai(v: bool, quoi: String) -> void:
	if v:
		_ok += 1
	else:
		_echecs += 1
		print("  ✗ " + quoi)


func _egal(a, b, quoi: String) -> void:
	if a == b:
		_ok += 1
	else:
		_echecs += 1
		print("  ✗ %s — rendu %s, attendu %s" % [quoi, a, b])
