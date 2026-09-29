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

const FN := preload("res://addons/marchingblocks_core/format_neutre.gd")
const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const Rule := preload("res://addons/marchingblocks_paint/mb_rule.gd")
const Tileset := preload("res://addons/marchingblocks_paint/mb_tileset.gd")
const Tools := preload("res://addons/marchingblocks_paint/mb_tools.gd")
const Editeur := preload("res://addons/marchingblocks_paint/mb_editor.gd")
const World := preload("res://addons/marchingblocks_paint/mb_world.gd")
const CAS := "res://addons/marchingblocks_paint/conformance.json"
const GENERATEUR := preload("res://DEV_TOOLS/generer_cas_d_epreuve.gd")
const EO := preload("res://addons/marchingblocks_core/epreuve_outils.gd")
const FM := preload("res://addons/marchingblocks_core/format_monde.gd")
const WorldFile := preload("res://addons/marchingblocks_paint/mb_world_file.gd")

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
	_le_greffon_passe_les_cas_d_outils()
	_les_cas_de_monde()
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
	var rouges := 0
	for c in cas["cases"]:
		var pourquoi := _cas_d_outil(c, monde)
		if pourquoi != "":
			rouges += 1
			_vrai(false, "outil « %s » — %s" % [c["name"], pourquoi])
	_egal(rouges, 0, "cas d'outils où le greffon Godot diverge de l'appli")
	print("  outils du greffon Godot : %d cas, %d divergence(s)" % [(cas["cases"] as Array).size(), rouges])


func _cas_d_outil(c: Dictionary, monde: Dictionary) -> String:
	var i: Dictionary = c["input"]
	var e: Dictionary = c["expected"]
	var ici: Dictionary = monde if i.get("cells", null) is String else _ensemble(i.get("cells", []))
	var plein := func(v: Vector3i) -> bool: return ici.has(v)
	match c["kind"]:
		"ray":
			var r: Dictionary = Tools.ray(plein, _v3(i["origin"]), _v3(i["direction"]), float(i["reach"]),
				_ensemble(i["ignore"]))
			var obtenu := [r["hit"], r["cell"], r["normal"]]
			var voulu := [e["hit"], _vi(e["cell"]), _vi(e["normal"])]
			return "" if obtenu == voulu else "attendu %s, rendu %s" % [voulu, obtenu]
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
	for nom in ["mb_tools.gd", "mb_editor.gd", "mb_world.gd", "mb_rule.gd", "mb_tileset.gd", "plugin.gd"]:
		var script := load("res://addons/marchingblocks_paint/" + nom) as GDScript
		var charge := script != null and script.can_instantiate()
		_vrai(charge, "addons/marchingblocks_paint/%s ne compile pas" % nom)
		tous_charges = tous_charges and charge
	if not tous_charges:
		return
	var monde: Node3D = World.new()
	root.add_child(monde)
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

	# Navigate : aucun clic ne peint, Tab revient à Grid.
	ed.set_aim("navigate")
	ed.set_mode("add")
	_vrai(not clic.call(ecran.call(Vector3i(0, 0, 0)), true), "en Navigate, le clic est LAISSÉ à l'éditeur")
	clic.call(ecran.call(Vector3i(0, 0, 0)), false)
	_egal(nb.call(), 6, "en Navigate, un clic ne peint rien")
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	_vrai(ed.input(cam, tab), "Tab est pris en Navigate")
	_egal(ed.aim, "grid", "et revient à Grid")

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

	ed.world = null
	for n in [ed, cam, monde]:
		n.queue_free()
	annul.free()


# ── 5. De bout en bout : l'appli exporte, le greffon charge, pose, et redonne ce que l'appli pose ────
func _de_bout_en_bout() -> void:
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
	_le_monde_de_bout_en_bout(lot, pleines, attendu)
	_fin()


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
