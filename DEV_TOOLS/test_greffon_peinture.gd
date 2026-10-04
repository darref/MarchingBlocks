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
