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
## vraiment des tuiles d'air libre, des exemplaires au-delà du premier, et des marqueurs d'erreur.

const FN := preload("res://addons/marching_blocks_plugin_godot/format_neutre.gd")
const MB := preload("res://addons/marching_blocks_plugin_godot/marching_blocks.gd")
const BM := preload("res://addons/marching_blocks_plugin_godot/blocs_maitres.gd")
const Rule := preload("res://addons/marchingblocks_paint/mb_rule.gd")
const Tileset := preload("res://addons/marchingblocks_paint/mb_tileset.gd")
const World := preload("res://addons/marchingblocks_paint/mb_world.gd")
const CAS := "res://addons/marchingblocks_paint/conformance.json"
const GENERATEUR := preload("res://DEV_TOOLS/generer_cas_d_epreuve.gd")
const EO := preload("res://addons/marching_blocks_plugin_godot/epreuve_outils.gd")

var _ok := 0
var _echecs := 0


func _initialize() -> void:
	print("=== TEST — le format neutre et le greffon de peinture Godot ===\n")
	_les_noms()
	_les_quarts_de_tour()
	var cas: Dictionary = _les_cas_livres_sont_a_jour()
	if not cas.is_empty():
		_le_greffon_passe_les_cas(cas)
	_un_format_plus_recent_est_refuse()
	_les_cas_d_outils()
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
	_egal(FN.nom_de_tuile("mb_coin_b1h0", 0), "corner_b1h0", "l'exemplaire 0 porte le nom nu")
	_egal(FN.nom_de_tuile("mb_coin_b1h0", 2), "corner_b1h0_3", "l'exemplaire 2 porte « _3 »")


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


# ── 4. Le greffon reproduit chaque cas, à 100 % ─────────────────────────────────────────────────────
func _le_greffon_passe_les_cas(cas: Dictionary) -> void:
	var dehors := 0
	var exemplaires := 0
	var marqueurs := 0
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
		for e in attendu:
			if e[3] == null:
				marqueurs += 1
			elif str(e[3]).contains("_outdoor"):
				dehors += 1
			elif RegEx.create_from_string("_[0-9]+$").search(str(e[3])) != null:
				exemplaires += 1
	print("  cas d'épreuve : %d cas, %d poses — %d d'air libre, %d exemplaires au-delà du premier, %d marqueurs"
		% [(cas["cases"] as Array).size(), total, dehors, exemplaires, marqueurs])
	_vrai(dehors > 0, "aucun cas ne pose de tuile d'air libre : le contexte n'est pas éprouvé")
	_vrai(exemplaires > 0, "aucun cas ne tire d'exemplaire au-delà du premier : le hachage n'est pas éprouvé")
	_vrai(marqueurs > 0, "aucun cas ne demande de tuile absente : le marqueur n'est pas éprouvé")


func _un_format_plus_recent_est_refuse() -> void:
	var regle := FN.regle_du_format()
	regle["version"] = FN.VERSION + 1
	_vrai(Rule.check(regle) != "", "un manifeste d'un format PLUS RÉCENT est accepté")
	regle["version"] = FN.VERSION
	_egal(Rule.check(regle), "", "un manifeste du format courant est refusé")


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
	_egal(sortes.size(), 9, "les cas d'outils couvrent les neuf sortes de fonctions")
	_vrai(touches >= 3 and manques >= 2, "les rayons doivent toucher ET manquer (%d / %d)" % [touches, manques])
	_vrai(egalite, "aucun rayon n'éprouve une égalité exacte : départager à l'envers resterait muet")
	_vrai(boite_vide, "aucune boîte ne dépasse la borne : la borne n'est pas éprouvée")
	_vrai(creuse, "aucune boîte creuse n'est réellement évidée")
	_egal(operations.size(), EO.OPERATIONS_EN.size(), "chaque opération de sélection a ses cas")
	print("  cas d'outils : %d cas, %d rayons qui touchent, %d qui manquent" % [(frais["cases"] as Array).size(),
		touches, manques])


# ── 5. De bout en bout : l'appli exporte, le greffon charge, pose, et redonne ce que l'appli pose ────
func _de_bout_en_bout() -> void:
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

	var monde: Node3D = World.new()
	root.add_child(monde)
	var cells := monde.get_node("Cells") as GridMap
	var pleines: Dictionary = BM.cases(0)
	for c in pleines:
		cells.set_cell_item(c, 0)
	monde.tileset = dossier.path_join("witness_rock.mbset/tileset.json")
	var rapport: Dictionary = monde.last_report()
	_egal(rapport["error"], "", "le monde se bâtit sans erreur")
	_egal(rapport["missing"], 0, "aucun cube rouge sur le témoin")
	# L'attendu : ce que le PEINTRE DE L'APPLI pose, via la référence.
	var comptes := {}
	var familles: Dictionary = FN.familles_du_lot(lot)
	for cle in familles:
		comptes[cle] = (familles[cle] as Array).size()
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
	monde.queue_free()
	_fin()


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
