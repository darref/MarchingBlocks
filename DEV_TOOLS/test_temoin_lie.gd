extends SceneTree
## TEST — le témoin lié ÉDITABLE (`temoin_lie.gd`) : une tuile par clé, en copies liées (charte §3).
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_temoin_lie.gd
##
## ⚠ LES ATTENDUS VIENNENT D'AILLEURS (charte §6) : le nombre de tuiles, des listes du MODÈLE (35 + 17) ;
## le nombre d'occurrences, recompté sommet par sommet par `MB.porte_une_surface` ; le rayon, comparé à une
## recherche BRUTE sur chaque triangle du témoin assemblé ; les tuiles, par leurs POSITIONS et leur AIRE
## (le maillage éditable recolle les triangles en quads, donc la triangulation peut changer, pas la forme).

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const ME := preload("res://addons/marchingblocks_core/maillage_edite.gd")

var _ok := 0
var _echecs := 0
var _premier := ""


func _initialize() -> void:
	print("=== TEST — le témoin lié éditable ===\n")
	var t: RefCounted = TL.depuis_le_temoin_calcule()
	_ce_qu_il_porte(t)
	_les_materiaux_sont_partages(t)
	_il_s_enregistre(t)
	_il_part_en_glb_lie(t)
	_il_revient_avec_sa_peinture(t)
	_le_rayon_trouve_l_occurrence(t)
	_sculpter_une_tuile_les_change_toutes(t)
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


func _ce_qu_il_porte(t: RefCounted) -> void:
	var tuiles_du_monde: int = MB.pieces_a_sculpter().size() + MB.exterieures_a_sculpter().size()
	_dire(t.tuiles.size() == tuiles_du_monde, "une tuile par clé du monde (%d pour %d)" % [t.tuiles.size(), tuiles_du_monde])
	var c: Dictionary = BM.cases(0)
	var sommets := {}
	for cell in c:
		for s in MB.sommets_de(cell):
			sommets[s] = true
	var a_surface := 0
	for s in sommets:
		if MB.porte_une_surface(MB.bits(c, s)):
			a_surface += 1
	_dire(t.occurrences.size() == a_surface, "une occurrence par sommet à surface (%d pour %d)" % [t.occurrences.size(), a_surface])
	var calc: Dictionary = BM.tuiles_du_temoin()
	var memes := 0
	for cle in calc:
		if t.tuiles.has(cle) and _forme(t.tuiles[cle].vers_array_mesh(false)) == _forme(calc[cle]["mesh"]):
			memes += 1
	_dire(memes == calc.size(), "chaque tuile éditable a la forme de celle du témoin calculé (%d / %d)" % [memes, calc.size()])


func _les_materiaux_sont_partages(t: RefCounted) -> void:
	var cles: Array = t.tuiles.keys()
	var a: RefCounted = t.tuiles[cles[0]]
	var b: RefCounted = t.tuiles[cles[1]]
	t.materiaux.append({"nom": "Moss", "couleur": Color(0.2, 0.6, 0.3), "rugosite": 0.9, "metal": 0.0,
		"texture": "", "echelle": 1.0})
	_dire(a.materiaux.size() == 1 and b.materiaux.size() == 1, "un matériau neuf existe dans toutes les tuiles")
	var c: RefCounted = t.copie()
	c.materiaux.append({"nom": "Sand", "couleur": Color.YELLOW})
	_dire(t.materiaux.size() == 1 and c.tuiles[cles[0]].materiaux.size() == 2,
		"une copie a ses propres matériaux, partagés entre SES tuiles")
	# ⚠ On rend l'état avec une COPIE prise avant, comme l'annulation : l'objet vivant `a` partage le tableau
	# du témoin, il porterait déjà le matériau ajouté.
	var origine: RefCounted = a.copie()
	var seule: RefCounted = a.copie()
	seule.materiaux.append({"nom": "Ash", "couleur": Color.GRAY})
	t.poser_tuile(cles[0], seule)
	_dire(t.materiaux.size() == 2 and t.tuiles[cles[1]].materiaux.size() == 2 and t.tuiles[cles[0]].materiaux.size() == 2,
		"poser une tuile re-partage ses matériaux avec toutes les autres")
	# ⚠ LE MÊME TABLEAU, PAS UNE COPIE DE MÊME TAILLE : compter ne le voyait pas (mutation muette).
	_dire(is_same(t.tuiles[cles[0]].materiaux, t.materiaux) and is_same(t.tuiles[cles[1]].materiaux, t.materiaux),
		"la tuile posée pointe le MÊME tableau de matériaux que tout le témoin")
	t.poser_tuile(cles[0], origine)
	_dire(t.materiaux.size() == 1 and t.tuiles[cles[1]].materiaux.size() == 1, "et poser la copie d'avant les rend")


func _il_s_enregistre(t: RefCounted) -> void:
	var texte := JSON.stringify(t.vers_dictionnaire())
	var r: RefCounted = TL.depuis_dictionnaire(JSON.parse_string(texte))
	_dire(r != null, "le témoin lié se relit")
	if r == null:
		return
	var memes := 0
	for cle in t.tuiles:
		if r.tuiles.has(cle) and _forme(r.tuiles[cle].vers_array_mesh(false)) == _forme(t.tuiles[cle].vers_array_mesh(false)):
			memes += 1
	_dire(memes == t.tuiles.size() and r.occurrences.size() == t.occurrences.size(),
		"relu : les mêmes tuiles (%d / %d), les mêmes occurrences" % [memes, t.tuiles.size()])
	_dire(r.materiaux.size() == t.materiaux.size() and r.materiaux[0]["couleur"] is Color
		and (r.materiaux[0]["couleur"] as Color).is_equal_approx(t.materiaux[0]["couleur"]),
		"relu : les matériaux, couleur comprise")
	_dire(TL.depuis_dictionnaire({"format": "marchingblocks-mesh", "version": 1}) == null,
		"un maillage d'un seul tenant (l'ancien .mbmesh) n'est pas un témoin lié")
	var futur: Dictionary = t.vers_dictionnaire()
	futur["version"] = TL.VERSION + 1
	_dire(TL.depuis_dictionnaire(futur) == null, "une version plus récente est refusée")


func _il_part_en_glb_lie(t: RefCounted) -> void:
	var chemin := ProjectSettings.globalize_path("user://test_temoin_lie/modele.glb")
	DirAccess.make_dir_recursive_absolute(chemin.get_base_dir())
	_dire(t.vers_glb(chemin) == "", "le témoin lié s'écrit en .glb")
	var b: Dictionary = BM.librairie_depuis_glb(chemin)
	_dire(b.get("lie", false) and b["erreurs"].is_empty(), "et se relit comme témoin lié (%s)" % [b["erreurs"]])
	var lot: MeshLibrary = b["lot"]
	var memes := 0
	for cle in t.tuiles:
		var id: int = lot.find_item_by_name(cle)
		if id >= 0 and _forme(lot.get_item_mesh(id)) == _forme(t.tuiles[cle].vers_array_mesh(false)):
			memes += 1
	_dire(memes == t.tuiles.size(), "le lot relu porte les tuiles du modèle (%d / %d)" % [memes, t.tuiles.size()])


## RELU D'UN .glb, LE TÉMOIN GARDE SA PEINTURE (30 septembre 2026 : un travail revenu de Blender devient le
## témoin de sa couche, éditable). Un matériau à TEXTURE posé sur des faces DÉPLIÉES d'une tuile revient :
## la même image (écrite en PNG), les mêmes faces, leurs UV ; la légende reste des teintes.
func _il_revient_avec_sa_peinture(t0: RefCounted) -> void:
	var t: RefCounted = t0.copie()
	var dossier := ProjectSettings.globalize_path("user://test_temoin_lie/peinture")
	DirAccess.make_dir_recursive_absolute(dossier)
	var img := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.2, 0.1))
	img.set_pixel(0, 0, Color.WHITE)
	var png := dossier.path_join("source.png")
	img.save_png(png)
	# ⚠ L'INDICE DU MATÉRIAU AJOUTÉ, PAS 0 : le témoin reçu porte déjà un matériau (laissé par un test plus
	# haut) — assigner 0 peignait les faces de ce vieux matériau, sans texture ni projection « uv ».
	var k_mat: int = t.materiaux.size()
	t.materiaux.append({"nom": "Moss", "couleur": Color(0.5, 0.9, 0.5), "rugosite": 0.6, "metal": 0.1,
		"texture": png, "echelle": 1.0, "projection": "uv"})
	var cle := "mb_plaque_b2h2_dehors"
	var tuile: RefCounted = t.tuiles[cle]
	var peintes: Array = [0, 1]
	tuile.assigner(peintes, k_mat)
	tuile.deplier(peintes)
	var uv_avant: Array = peintes.map(func(f): return tuile.uv(f))
	var chemin := dossier.path_join("peint.glb")
	_dire(t.vers_glb(chemin) == "", "le témoin peint s'écrit")
	var r: RefCounted = TL.depuis_glb(chemin, dossier.path_join("images"))
	_dire(r != null and r.tuiles.size() == t.tuiles.size(), "relu d'un .glb lié : toutes ses tuiles")
	if r == null:
		return
	# Seul le matériau PORTÉ par des faces voyage (un matériau sans face n'a pas de primitive dans le glTF).
	_dire(r.materiaux.size() == 1 and str(r.materiaux[0]["projection"]) == "uv",
		"un seul matériau revient (celui que des faces portent), en projection « uv » (%d)" % r.materiaux.size())
	var relue: RefCounted = r.tuiles[cle]
	var avec_mat: Array = []
	for f in relue.faces.size():
		if relue.mat(f) == 0:
			avec_mat.append(f)
	var uv_apres: Array = avec_mat.map(func(f): return relue.uv(f))
	var memes_uv := avec_mat.size() == peintes.size()
	for u in uv_apres:
		var trouve := false
		for v in uv_avant:
			var ens_u := {}
			for p in (u as PackedVector2Array):
				ens_u[Vector2i((p * 10000.0).round())] = true
			var egal := (v as PackedVector2Array).size() == (u as PackedVector2Array).size()
			for p in (v as PackedVector2Array):
				egal = egal and ens_u.has(Vector2i((p * 10000.0).round()))
			trouve = trouve or egal
		memes_uv = memes_uv and trouve
	_dire(memes_uv, "les faces peintes reviennent peintes, avec LEURS UV (%d faces)" % avec_mat.size())
	var tex: String = str(r.materiaux[0]["texture"])
	var relu_img := Image.load_from_file(tex) if FileAccess.file_exists(tex) else null
	_dire(relu_img != null and relu_img.get_size() == img.get_size() and relu_img.get_pixel(0, 0).is_equal_approx(Color.WHITE),
		"son image revient, écrite en PNG (%s)" % tex.get_file())
	var teintes_avant := {}
	var teintes_apres := {}
	for f in tuile.faces.size():
		if tuile.mat(f) < 0:
			teintes_avant[tuile.teintes[f].to_html()] = true
	for f in relue.faces.size():
		if relue.mat(f) < 0:
			teintes_apres[relue.teintes[f].to_html()] = true
	_dire(teintes_apres == teintes_avant, "les faces de la légende gardent leurs teintes (%s)" % [teintes_apres.keys()])
	_dire(_forme(relue.vers_array_mesh(false)) == _forme(tuile.vers_array_mesh(false)), "et la tuile garde sa forme")


## Le rayon contre une recherche BRUTE sur le témoin assemblé (chaque triangle, `Geometry3D`).
func _le_rayon_trouve_l_occurrence(t: RefCounted) -> void:
	var assemble: ArrayMesh = t.assemble()
	var tris := PackedVector3Array()
	for s in assemble.get_surface_count():
		var a: Array = assemble.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		for i in (a[Mesh.ARRAY_INDEX] as PackedInt32Array):
			tris.append(v[i])
	var rng := RandomNumberGenerator.new()
	rng.seed = 30092026
	var accords := 0
	var touches := 0
	var essais := 150
	for k in essais:
		var cible := Vector3(rng.randf_range(0.5, 11.5), rng.randf_range(0.5, 11.5), rng.randf_range(0.5, 11.5))
		var o := cible + Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 1), rng.randf_range(-1, 1)).normalized() * 30.0
		var d := (cible - o).normalized()
		var brut := INF
		for i in range(0, tris.size(), 3):
			var p = Geometry3D.ray_intersects_triangle(o, d, tris[i], tris[i + 1], tris[i + 2])
			if p != null:
				brut = minf(brut, o.distance_to(p))
		var h: Dictionary = t.rayon(o, d)
		var vu: float = INF if h.is_empty() else float(h["distance"])
		if (brut == INF and vu == INF) or absf(brut - vu) < 1e-3:
			accords += 1
		if brut != INF:
			touches += 1
	_dire(accords == essais and touches > essais / 2,
		"le rayon rend le premier impact de la recherche brute (%d / %d, dont %d touchent)" % [accords, essais, touches])


## Déplacer un sommet d'UNE tuile le déplace à TOUTES ses occurrences, et à aucune autre.
func _sculpter_une_tuile_les_change_toutes(t: RefCounted) -> void:
	var cle := "mb_plaque_b2h2_dehors"
	var tuile: RefCounted = t.tuiles[cle]
	var avant: Vector3 = tuile.sommets[0]
	var apres: Vector3 = avant + Vector3(0.0, 0.0, 0.125)
	tuile.sommets[0] = apres
	var positions := {}
	var assemble: ArrayMesh = t.assemble()
	for s in assemble.get_surface_count():
		for p in (assemble.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			positions[Vector3i((p * 1000.0).round())] = true
	var partout := 0
	var occ: Array = t.occurrences_de(cle)
	for i in occ:
		var pose: Transform3D = t.occurrences[i]["pose"]
		if positions.has(Vector3i(((pose * apres) * 1000.0).round())):
			partout += 1
	_dire(occ.size() > 100 and partout == occ.size(),
		"le sommet sculpté est à sa place dans les %d occurrences de la tuile (%d)" % [occ.size(), partout])
	tuile.sommets[0] = avant


## La FORME d'un maillage : ses positions (au millième) et son aire, indépendantes de la triangulation.
func _forme(mesh: Mesh) -> String:
	var pos := {}
	var aire := 0.0
	for s in mesh.get_surface_count():
		var a: Array = mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx = a[Mesh.ARRAY_INDEX]
		var ordre: PackedInt32Array = (idx as PackedInt32Array) if idx != null else PackedInt32Array(range(v.size()))
		for i in range(0, ordre.size() - 2, 3):
			aire += (v[ordre[i + 1]] - v[ordre[i]]).cross(v[ordre[i + 2]] - v[ordre[i]]).length() * 0.5
		for p in v:
			pos["%d,%d,%d" % [roundi(p.x * 1000.0), roundi(p.y * 1000.0), roundi(p.z * 1000.0)]] = true
	var l: Array = pos.keys()
	l.sort()
	return "%s|%.4f" % [";".join(PackedStringArray(l)).md5_text(), aire]
