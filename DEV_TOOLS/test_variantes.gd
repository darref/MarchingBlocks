extends SceneTree
## TEST — les VARIANTES VOULUES (Jordan, 4 octobre 2026 : « des tuiles alternatives pour les parties qui se répètent
## beaucoup […] un mode choix en monde et un mode choix aléatoire »).
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_variantes.gd
##
## ⚠ LES ATTENDUS VIENNENT D'AILLEURS (charte §6) : le hachage, de valeurs calculées en PYTHON (une implémentation à
## part, comme le seront C# et C++) ; les tirages, comptés sur une grille et comparés aux poids écrits ici ; le peintre,
## comparé à `MB.poses` (la règle des CLÉS, qui ignore les variantes) plus le tirage recalculé dans le test ; les joints
## du témoin, par les positions des sommets de deux occurrences voisines posées dans le monde.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const RP := preload("res://addons/marchingblocks_core/repli_procedural.gd")
const SE := preload("res://addons/marchingblocks_core/sections.gd")
const FN := preload("res://addons/marchingblocks_core/format_neutre.gd")
const Peint := preload("res://addons/marchingblocks_core/massif_peint.gd")

var _ok := 0
var _echecs := 0
var _premier := ""


func _initialize() -> void:
	print("=== TEST — les variantes voulues ===\n")
	_les_noms()
	_le_hachage()
	_le_tirage()
	_le_peintre()
	var t: RefCounted = TL.depuis_le_temoin_calcule()
	_le_temoin(t)
	_les_formats(t)
	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	if _echecs > 0:
		print("PREMIER ÉCHEC — %s" % _premier)
	print("VERDICT : %s" % ("ÉCHEC" if _echecs > 0 else "OK"))
	quit(1 if _echecs > 0 else 0)


func _dire(condition: bool, quoi: String) -> void:
	if condition:
		_ok += 1
	else:
		_echecs += 1
		if _premier == "":
			_premier = quoi
		if _echecs <= 12:
			print("  ÉCHEC — %s" % quoi)


# ── 1. LES NOMS ──────────────────────────────────────────────────────────────────────────────────────

func _les_noms() -> void:
	print("1. les noms")
	_dire(MB.nom_de_variante("mb_plaque_b2h2_dehors", 2) == "mb_plaque_b2h2_dehors_var2", "le nom d'une variante")
	_dire(MB.nom_de_variante("mb_plaque_b2h2", 0) == "mb_plaque_b2h2", "le rang 0 est la base")
	_dire(MB.cle_de_tuile("mb_plaque_b2h2_dehors_var2") == "mb_plaque_b2h2_dehors", "la clé d'une variante")
	_dire(MB.rang_de_variante("mb_plaque_b2h2_dehors_var2") == 2, "le rang d'une variante")
	_dire(MB.rang_de_variante("mb_plaque_b2h2_dehors") == 0 and MB.rang_de_variante("mb_x_var0") == 0
		and MB.rang_de_variante("mb_x_var12") == 0 and MB.rang_de_variante("mb_x_varz") == 0,
		"un nom qui n'est pas une variante a le rang 0")
	_dire(MB.nom_nu("mb_plaque_b2h2_dehors_var3") == "mb_plaque_b2h2", "le nom nu d'une variante est sa classe")
	_dire(FN.nom_de_tuile("mb_plaque_b2h2_dehors_var1") == "slab_b2h2_outdoor_var1", "son nom anglais")
	var cles := {"a": 1, "a_var1": 1, "a_var2": 1, "a_var4": 1}
	_dire(MB.nombre_de_variantes("a", cles) == 2, "un trou arrête le compte des variantes (var4 sans var3)")


# ── 2. LE HACHAGE — valeurs calculées en Python, à part ──────────────────────────────────────────────

func _le_hachage() -> void:
	print("2. le hachage")
	var attendus := {Vector3i(0, 0, 0): 0, Vector3i(1, 2, 3): 552131862, Vector3i(-5, 7, -11): 1917165250,
		Vector3i(100, -3, 42): 1160223666, Vector3i(-1, -1, -1): 2007722147}
	for s in attendus:
		_dire(MB.hachage_du_sommet(s) == attendus[s], "hachage de %s = %d (lu %d)" % [s, attendus[s],
			MB.hachage_du_sommet(s)])


# ── 3. LE TIRAGE ─────────────────────────────────────────────────────────────────────────────────────

func _le_tirage() -> void:
	print("3. le tirage")
	var cles := {"k": 1, "k_var1": 1, "k_var2": 1}
	_dire(MB.tuile_du_sommet(Vector3i(3, 0, 4), "k", {"k": 1}) == "k", "sans variante, la clé")
	_dire(MB.tuile_du_sommet(Vector3i(3, 0, 4), "", cles) == "", "sans clé, rien")
	# Des poids 2 : 1 : 1 sur une grille de 80 × 80 : la part de chaque tuile, à 3 points près.
	var compte := {"k": 0, "k_var1": 0, "k_var2": 0}
	var memes_voisins := 0
	var paires := 0
	for x in 80:
		for z in 80:
			var t: String = MB.tuile_du_sommet(Vector3i(x, 5, z), "k", cles, {"k": [2, 1, 1]})
			compte[t] += 1
			if x > 0:
				paires += 1
				if t == MB.tuile_du_sommet(Vector3i(x - 1, 5, z), "k", cles, {"k": [2, 1, 1]}):
					memes_voisins += 1
	var n := 6400.0
	_dire(absf(compte["k"] / n - 0.5) < 0.03 and absf(compte["k_var1"] / n - 0.25) < 0.03
		and absf(compte["k_var2"] / n - 0.25) < 0.03, "poids 2 : 1 : 1 → %s" % compte)
	# Sans bandes : deux voisins tirent la même tuile à peu près aussi souvent que deux tirages indépendants
	# (0,5² + 0,25² + 0,25² = 0,375). Des bandes le pousseraient vers 1.
	var part := memes_voisins / float(paires)
	_dire(absf(part - 0.375) < 0.04, "deux voisins identiques %.3f du temps (indépendant : 0,375)" % part)
	# Poids nuls, négatifs, absents.
	var seul := true
	for x in 30:
		if MB.tuile_du_sommet(Vector3i(x, 0, 7), "k", cles, {"k": [0, 5, -3]}) != "k_var1":
			seul = false
	_dire(seul, "poids [0, 5, −3] : toujours la variante 1")
	var defaut := {"k": 0, "k_var1": 0, "k_var2": 0}
	for x in 3000:
		defaut[MB.tuile_du_sommet(Vector3i(x, 1, -x), "k", cles, {})] += 1
	_dire(defaut["k"] > 850 and defaut["k_var1"] > 850 and defaut["k_var2"] > 850, "sans poids, 1 chacune : %s" % defaut)
	_dire(MB.tuile_du_sommet(Vector3i(1, 1, 1), "k", cles, {"k": [0, 0, 0]}) == "k", "tous nuls : la base")
	# Le choix l'emporte ; un choix vers une variante absente retombe sur le tirage.
	var s := Vector3i(9, 2, 9)
	var tire: String = MB.tuile_du_sommet(s, "k", cles, {"k": [0, 0, 1]})
	_dire(tire == "k_var2", "tirage forcé vers la variante 2")
	_dire(MB.tuile_du_sommet(s, "k", cles, {"k": [0, 0, 1]}, {s: 0}) == "k", "un choix 0 pose la base")
	_dire(MB.tuile_du_sommet(s, "k", cles, {"k": [0, 0, 1]}, {s: 1}) == "k_var1", "un choix 1 pose la variante 1")
	_dire(MB.tuile_du_sommet(s, "k", cles, {"k": [0, 0, 1]}, {s: 7}) == "k_var2",
		"un choix vers une variante absente retombe sur le tirage")
	_dire(MB.tuile_du_sommet(s, "k", cles, {"k": [0, 0, 1]}, {Vector3i(9, 2, 8): 0}) == "k_var2",
		"le choix d'un autre sommet ne compte pas")


# ── 4. LE PEINTRE ────────────────────────────────────────────────────────────────────────────────────

func _le_peintre() -> void:
	print("4. le peintre")
	var lot := RP.librairie()
	var base_id := lot.find_item_by_name("mb_plaque_b4h0")
	_dire(base_id >= 0, "le repli porte le sol plat")
	var id := 1000
	for k in [1, 2]:
		lot.create_item(id)
		lot.set_item_name(id, "mb_plaque_b4h0_var%d" % k)
		lot.set_item_mesh(id, lot.get_item_mesh(base_id))
		id += 1
	var m: Node3D = Peint.new()
	root.add_child(m)
	m.preparer()
	m.lot = lot
	m.poids = {"mb_plaque_b4h0": [1, 1, 1]}
	var cases: GridMap = m.get_node("Cases")
	var c_id: int = cases.mesh_library.find_item_by_name("case")
	var pleines := {}
	for x in 20:
		for z in 20:
			cases.set_cell_item(Vector3i(x, 0, z), c_id)
			pleines[Vector3i(x, 0, z)] = true
	m.reconstruire()
	var rendu: GridMap = m.get_node("Rendu")
	# L'attendu : les poses de la règle des CLÉS (`MB.poses`), puis la tuile tirée recalculée ici (hachage, poids).
	var cles := {}
	for i in lot.get_item_list():
		cles[lot.get_item_name(i)] = i
	var justes := 0
	var total := 0
	var vues := {}
	for d in MB.poses(pleines, cles):
		if d["cle"] == "":
			continue
		total += 1
		var attendu: String = d["cle"]
		if d["cle"] == "mb_plaque_b4h0":
			var r: int = MB.hachage_du_sommet(d["sommet"]) % 3
			attendu = ["mb_plaque_b4h0", "mb_plaque_b4h0_var1", "mb_plaque_b4h0_var2"][r]
		var item: int = rendu.get_cell_item(d["sommet"])
		var pose: String = lot.get_item_name(item) if item >= 0 else ""
		vues[pose] = true
		if pose == attendu:
			justes += 1
	_dire(total > 300 and justes == total, "chaque sommet porte la tuile tirée (%d / %d)" % [justes, total])
	_dire(vues.has("mb_plaque_b4h0_var1") and vues.has("mb_plaque_b4h0_var2") and vues.has("mb_plaque_b4h0"),
		"les trois tuiles du sol apparaissent")
	# Un CHOIX, refait par `reconstruire_sommets` : le sommet change, ses voisins non.
	# Un sommet du milieu dont le TIRAGE est la variante 1 : le choix 2, puis le choix 0, s'en distinguent.
	var s := Vector3i(8, 0, 8)
	while MB.hachage_du_sommet(s) % 3 != 1:
		s.z += 1
	_dire(lot.get_item_name(rendu.get_cell_item(s)) == "mb_plaque_b4h0_var1", "sans choix, le tirage (variante 1)")
	var avant_voisin: int = rendu.get_cell_item(s + Vector3i(1, 0, 0))
	m.choix = {s: 2}
	m.reconstruire_sommets([s])
	_dire(lot.get_item_name(rendu.get_cell_item(s)) == "mb_plaque_b4h0_var2", "un choix pose sa variante")
	_dire(rendu.get_cell_item(s + Vector3i(1, 0, 0)) == avant_voisin, "le voisin n'a pas bougé")
	_dire(m.tuile_posee(s) == "mb_plaque_b4h0_var2" and m.cle_posee(s) == "mb_plaque_b4h0",
		"l'état dit la tuile posée et sa clé")
	var completes: int = m.reconstructions_completes
	m.choix = {s: 0}
	m.reconstruire_sommets([s])
	_dire(m.reconstructions_completes == completes, "un choix ne reconstruit pas tout")
	_dire(lot.get_item_name(rendu.get_cell_item(s)) == "mb_plaque_b4h0", "un choix 0 pose la base")
	# Local = complet : refaire en entier rend la même grille.
	var photo := {}
	for c in rendu.get_used_cells():
		photo[c] = rendu.get_cell_item(c)
	m.reconstruire()
	var pareil := rendu.get_used_cells().size() == photo.size()
	for c in photo:
		if rendu.get_cell_item(c) != photo[c]:
			pareil = false
	_dire(pareil, "après un choix, la reconstruction complète rend la même grille")
	# Une case posée ensuite : la route locale garde le tirage.
	cases.set_cell_item(Vector3i(5, 1, 5), c_id)
	m.reconstruire_autour([Vector3i(5, 1, 5)])
	var local := {}
	for c in rendu.get_used_cells():
		local[c] = rendu.get_cell_item(c)
	m.reconstruire()
	pareil = rendu.get_used_cells().size() == local.size()
	for c in local:
		if rendu.get_cell_item(c) != local[c]:
			pareil = false
	_dire(pareil, "reconstruction locale = complète, avec variantes")
	m.free()


# ── 5. LE TÉMOIN ─────────────────────────────────────────────────────────────────────────────────────

func _le_temoin(t: RefCounted) -> void:
	print("5. le témoin")
	var cle := "mb_plaque_b2h2_dehors"
	var occ: Array = t.occurrences_de(cle)
	_dire(occ.size() > 100, "la paroi a beaucoup de copies (%d)" % occ.size())
	var n_tuiles: int = t.tuiles.size()
	var etat0: Dictionary = t.etat_des_variantes()
	var i0: int = occ[occ.size() / 2]
	var nom: String = t.creer_variante(i0)
	_dire(nom == cle + "_var1" and t.tuiles.size() == n_tuiles + 1, "créer une variante ajoute une tuile (%s)" % nom)
	_dire(t.occurrences[i0]["cle"] == nom and t.occurrences[i0]["modele"] == cle, "l'occurrence montre la variante")
	_dire(t.occurrences_de(cle).size() == occ.size() - 1, "les autres copies restent à la base")
	_dire(t.tuiles[nom].materiaux == t.materiaux, "la variante partage les matériaux du témoin")
	# Une seconde occurrence, affectée.
	var i1: int = occ[3]
	_dire(t.affecter(i1, 1) and t.occurrences_de(nom).size() == 2, "affecter une seconde copie à la variante")
	_dire(not t.affecter(i1, 5), "affecter une variante absente est refusé")
	var sec: RefCounted = SE.new(t)
	_dire(sec.absences() == 0, "une variante copie de la base : aucune absence de section")
	# SCULPTER LE CŒUR DE LA VARIANTE ne touche pas la base ; un BORD de la variante entraîne la base.
	var v: RefCounted = t.tuiles[nom]
	var interieur := -1
	var bord := -1
	for i in v.sommets.size():
		var p: Vector3 = v.sommets[i]
		var dedans := absf(p.x) < 0.49 and absf(p.y) < 0.49 and absf(p.z) < 0.49
		if dedans and interieur < 0:
			interieur = i
		if not dedans and sec.est_de_bord(nom, i) and bord < 0:
			bord = i
	_dire(interieur >= 0 and bord >= 0, "la variante a un sommet intérieur et un sommet de bord")
	var base_avant: PackedVector3Array = (t.tuiles[cle].sommets as PackedVector3Array).duplicate()
	v.sommets[interieur] = v.sommets[interieur] + Vector3(0.0, 0.05, 0.0)
	_dire(t.tuiles[cle].sommets == base_avant, "sculpter le cœur de la variante ne touche pas la base")
	var corr: Array = sec.correspondants(nom, bord)
	var vers_base := false
	for e in corr:
		if e["cle"] == cle:
			vers_base = true
	_dire(vers_base, "un sommet de bord de la variante a un correspondant dans la base")
	var d: Vector3 = sec.projeter(nom, bord, Vector3(0.03, 0.03, 0.03))
	var dep: Dictionary = sec.propager(nom, {bord: d})
	sec.deplacer(dep)
	_dire(_joints_ouverts(t) == 0, "après un bord de variante déplacé et propagé, aucun joint ouvert (base et variante)")
	_dire(t.tuiles[cle].sommets != base_avant, "la base a suivi le bord")
	# L'ENREGISTREMENT.
	var dico: Dictionary = t.vers_dictionnaire()
	var relu: RefCounted = TL.depuis_dictionnaire(JSON.parse_string(JSON.stringify(dico)))
	_dire(relu != null and relu.tuiles.has(nom) and relu.occurrences_de(nom).size() == 2
		and relu.affectation.size() == 2, "le .mbtiles relu garde la variante et ses copies")
	var abime: Dictionary = JSON.parse_string(JSON.stringify(dico))
	abime["affectation"] = [1, 2, 3]
	_dire(TL.depuis_dictionnaire(abime) == null, "une affectation malformée refuse le fichier")
	# LE .glb LIÉ : la variante y voyage, relue par la route du monde.
	var chemin := ProjectSettings.globalize_path("user://test_variantes.glb")
	_dire(t.vers_glb(chemin) == "", "le .glb lié s'écrit")
	var erreurs: Array = []
	var lu: Dictionary = BM.tuiles_liees(chemin, erreurs, [])
	_dire(erreurs.is_empty(), "relu sans erreur (%s)" % [erreurs])
	_dire((lu.get("pieces", {}) as Dictionary).has(nom) and (lu.get("affectation", {}) as Dictionary).size() == 2,
		"relu : la variante et ses deux copies")
	var aff_lue: Dictionary = lu.get("affectation", {})
	_dire(aff_lue.get(t.occurrences[i0]["sommet"], 0) == 1 and aff_lue.get(t.occurrences[i1]["sommet"], 0) == 1,
		"relu : les bonnes places")
	var lot: Dictionary = BM.librairie_depuis_glb(chemin)
	var lib: MeshLibrary = lot["lot"]
	_dire(lib.find_item_by_name(nom) >= 0 and lib.find_item_by_name(cle) >= 0, "le lot du monde porte la base et la variante")
	var sections_remarques := 0
	for r in lot.get("remarques", []):
		if str(r).begins_with("couture"):
			sections_remarques += 1
	_dire(sections_remarques == 0, "aucune remarque de couture (sections de la variante vérifiées avec sa clé)")
	var t2: RefCounted = TL.depuis_glb(chemin, ProjectSettings.globalize_path("user://test_variantes_images"))
	_dire(t2 != null and t2.tuiles.has(nom) and t2.occurrences_de(nom).size() == 2, "le témoin relu de Blender garde la variante")
	DirAccess.remove_absolute(chemin)
	# SUPPRIMER renumérote.
	var i2: int = occ[7]
	var nom2: String = t.creer_variante(i2)
	_dire(nom2 == cle + "_var2", "une seconde variante")
	_dire(t.supprimer_variante(nom), "supprimer la première")
	_dire(t.tuiles.has(cle + "_var1") and not t.tuiles.has(cle + "_var2"), "la seconde descend au rang 1")
	_dire(t.occurrences[i2]["cle"] == cle + "_var1" and t.occurrences[i0]["cle"] == cle and t.occurrences[i1]["cle"] == cle,
		"ses copies la suivent ; celles de la supprimée reviennent à la base")
	# L'ANNULATION : l'état d'avant rendu.
	t.poser_etat_des_variantes(etat0)
	_dire(t.tuiles.size() == n_tuiles and t.affectation.is_empty() and t.occurrences_de(cle).size() == occ.size(),
		"l'état d'avant rendu : plus aucune variante")


## Les sommets de joint sans partenaire : deux occurrences voisines du témoin, posées dans le monde, partagent leur plan
## de coupe ; chaque sommet de l'une SUR ce plan doit exister dans l'autre. Recalculé ici, sans `Sections`.
func _joints_ouverts(t: RefCounted) -> int:
	var par_sommet := {}
	for o in t.occurrences:
		par_sommet[o["sommet"]] = o
	var ouverts := 0
	for o in t.occurrences:
		for axe in 3:
			var dv := Vector3i.ZERO
			dv[axe] = 1
			var voisin = par_sommet.get(o["sommet"] + dv, null)
			if voisin == null:
				continue
			var plan: float = float((o["sommet"] as Vector3i)[axe]) + 1.5
			var a := _sur_le_plan(t, o, axe, plan)
			var b := _sur_le_plan(t, voisin, axe, plan)
			for k in a:
				if not b.has(k):
					ouverts += 1
			for k in b:
				if not a.has(k):
					ouverts += 1
	return ouverts


func _sur_le_plan(t: RefCounted, o: Dictionary, axe: int, plan: float) -> Dictionary:
	var sortie := {}
	var pose: Transform3D = o["pose"]
	for p in t.tuiles[o["cle"]].sommets:
		var w: Vector3 = pose * (p as Vector3)
		if absf(w[axe] - plan) < 0.0005:
			sortie[Vector3i((w * 1000.0).round())] = true
	return sortie


# ── 6. LES FORMATS ───────────────────────────────────────────────────────────────────────────────────

func _les_formats(t: RefCounted) -> void:
	print("6. les formats")
	var FM := load("res://addons/marchingblocks_core/format_monde.gd")
	var cle := "mb_plaque_b2h2_dehors"
	var occ: Array = t.occurrences_de(cle)
	t.creer_variante(occ[5])
	t.creer_variante(occ[9])
	var chemin := ProjectSettings.globalize_path("user://test_variantes_formats.glb")
	t.vers_glb(chemin)
	var lot: MeshLibrary = BM.librairie_depuis_glb(chemin)["lot"]
	var dossier := ProjectSettings.globalize_path("user://test_variantes_formats")
	var r: Dictionary = FM.exporter([{"nom": "Rock", "visible": true, "source": chemin, "lot": lot,
		"cases": [Vector3i(0, 0, 0)], "poids": {cle: [3, 1, 0]}, "choix": {Vector3i(4, 5, 6): 2, Vector3i(-1, 0, 0): 0}}],
		dossier, "Variant world", "test")
	_dire(not r.has("erreur"), "le monde s'exporte (%s)" % r.get("erreur", ""))
	var jeu = JSON.parse_string(FileAccess.get_file_as_string(dossier.path_join("variant_world.mbworld/rock.mbset/tileset.json")))
	_dire(jeu is Dictionary, "tileset.json relu")
	if not jeu is Dictionary:
		return
	# Écrit à la main : la clé anglaise, et ses deux variantes dans l'ordre.
	_dire(jeu.get("variants", {}) == {"slab_b2h2_outdoor": ["slab_b2h2_outdoor_var1", "slab_b2h2_outdoor_var2"]},
		"tileset.json : variants = %s" % [jeu.get("variants", {})])
	# ⚠ ATTENDU : autant d'entrées que de tuiles de BASE dans le lot (compté ici par le nom), et aucune clé en « var ».
	var bases := 0
	for i in lot.get_item_list():
		if not lot.get_item_name(i).contains("_var"):
			bases += 1
	var tiles: Dictionary = jeu["tiles"]
	_dire(tiles.size() == bases and tiles.keys().all(func(k): return not str(k).contains("var"))
		and tiles["slab_b2h2_outdoor"] == "slab_b2h2_outdoor",
		"tiles ne garde que les %d bases (%d entrées) : un greffon qui ignore les variantes pose la base" % [bases, tiles.size()])
	_dire((jeu.get("rules_text", []) as Array).any(func(l): return str(l).begins_with("8. Variants")),
		"la règle des variantes est l'étape 8 de rules_text")
	# Le glTF porte les trois tuiles, nommées.
	var gltf := GLTFDocument.new()
	var etat := GLTFState.new()
	gltf.append_from_file(dossier.path_join("variant_world.mbworld/rock.mbset/tiles.glb"), etat)
	var noms := {}
	for nd: GLTFNode in etat.get_nodes():
		noms[nd.resource_name] = true
	_dire(noms.has("slab_b2h2_outdoor") and noms.has("slab_b2h2_outdoor_var1") and noms.has("slab_b2h2_outdoor_var2"),
		"tiles.glb porte la base et les deux variantes")
	# world.json : poids et choix, relus par la règle de lecture.
	var monde = JSON.parse_string(FileAccess.get_file_as_string(dossier.path_join("variant_world.mbworld/world.json")))
	var couche: Dictionary = monde["layers"][0]
	_dire(couche.get("variant_weights", {}) == {"slab_b2h2_outdoor": [3.0, 1.0, 0.0]}, "world.json : les poids, sous la clé anglaise")
	_dire(couche.get("variant_choices", []) == [-1.0, 0.0, 0.0, 0.0, 4.0, 5.0, 6.0, 2.0], "world.json : les choix, triés")
	var lu: Dictionary = FM.lire_variantes(couche)
	_dire(not lu.has("error") and lu["choices"] == {Vector3i(4, 5, 6): 2, Vector3i(-1, 0, 0): 0}, "relus par la règle de lecture")
	_dire(not FM.lire(monde).has("error"), "la lecture de base l'accepte (les clés en plus sont ignorées)")
	var abime := couche.duplicate(true)
	abime["variant_choices"] = [1, 2, 3, 0, 1, 2, 3, 1]
	_dire(FM.lire_variantes(abime).has("error"), "un sommet choisi deux fois est refusé")
	abime["variant_choices"] = [1, 2, 3]
	_dire(FM.lire_variantes(abime).has("error"), "des choix qui ne vont pas par quatre sont refusés")
	abime["variant_choices"] = []
	abime["variant_weights"] = {"x": [1, 0.5]}
	_dire(FM.lire_variantes(abime).has("error"), "un poids non entier est refusé")
	DirAccess.remove_absolute(chemin)
