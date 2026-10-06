extends SceneTree
##
## TEST — la règle du FEUILLAGE (`addons/marchingblocks_core/feuillage.gd`, l'atelier Foliage, 6 octobre 2026).
##
## LANCEMENT
##   godot --headless --path . --script res://DEV_TOOLS/test_feuillage.gd
##
## Le monde est écrit à la main : un plateau de 10 × 10 cases (x, z ∈ [0, 9], y = 0, son dessus à y = 1), une DALLE
## au-dessus de son coin (x, z ∈ [0, 2], y = 3 : un plafond deux cases au-dessus du sol), et de l'EAU sur x, z ∈ [6, 8[.
## ⚠ LES ATTENDUS SONT ÉCRITS À LA MAIN OU JUGÉS SANS LA RÈGLE (distances, régions du monde) : jamais par `verifier`.

const FE := preload("res://addons/marchingblocks_core/feuillage.gd")
const FeuillageVue := preload("res://app/feuillage_vue.gd")
const Arbre := preload("res://DEV_TOOLS/arbre_d_essai.gd")

var _ok := 0
var _echecs := 0
var _plein := {}


func _initialize() -> void:
	print("=== TEST — la règle du feuillage ===\n")
	for x in 10:
		for z in 10:
			_plein[Vector3i(x, 0, z)] = true
	for x in 3:
		for z in 3:
			_plein[Vector3i(x, 3, z)] = true
	var plein := func(c: Vector3i) -> bool: return _plein.has(c)
	var monde := {
		"plein": plein,
		"sol": func(x: float, z: float, y: float) -> Variant: return FE.sol_des_cases(plein, x, z, y),
		"eau": func(p: Vector3) -> bool: return p.x >= 6.0 and p.x < 8.0 and p.z >= 6.0 and p.z < 8.0,
	}
	var m := FE.modele(1, "Tree", "")
	m["rayon"] = 1.0
	m["hauteur"] = 3.0
	m["echelle_alea"] = 0.0
	var modeles := {1: m}

	# ── 1. le sol des cases
	print("── 1. le sol des cases")
	_vrai(FE.sol_des_cases(plein, 5.5, 5.5, 10.0)["y"] == 1.0, "au milieu du plateau, le sol est à y = 1")
	_vrai(FE.sol_des_cases(plein, 1.5, 1.5, 10.0)["y"] == 4.0, "sous la dalle, vu d'en haut : le dessus de la dalle (4)")
	_vrai(FE.sol_des_cases(plein, 1.5, 1.5, 3.0)["y"] == 1.0, "sous la dalle, cherché depuis y = 3 : le plateau (1)")
	_vrai(FE.sol_des_cases(plein, 12.5, 5.5, 10.0) == null, "hors du plateau : pas de sol")
	# Une colonne de trois cases hors du plateau (x = 12, y ∈ [0, 2]) : cherché DEPUIS L'INTÉRIEUR, pas de sol (le dessus
	# d'une case couverte n'en est pas un) ; d'au-dessus, son sommet.
	for y in 3:
		_plein[Vector3i(12, y, 12)] = true
	_vrai(FE.sol_des_cases(plein, 12.5, 12.5, 2.5) == null, "depuis l'intérieur d'une colonne : pas de sol")
	_vrai(FE.sol_des_cases(plein, 12.5, 12.5, 6.0)["y"] == 3.0, "d'au-dessus : son sommet (3)")

	# ── 2. les modes, un clic à la fois
	print("── 2. les modes")
	var vide := FE.index([], modeles)
	_raison(m, Vector3(20, 5, 20), Vector3.UP, "air", monde, vide, modeles, 0.0, "", "dans le vide : n'importe où")
	_raison(m, Vector3(5.5, 0.5, 5.5), Vector3.UP, "air", monde, vide, modeles, 0.0, "dans_la_matiere",
		"dans le vide mais DANS la matière : refusé")
	_raison(m, Vector3(5.5, 1, 5.5), Vector3.UP, "sol_libre", monde, vide, modeles, 0.0, "",
		"voisinage libre au milieu du plateau")
	_raison(m, Vector3(9.5, 1, 5.5), Vector3.UP, "sol_libre", monde, vide, modeles, 0.0, "au_bord",
		"voisinage libre au bord : l'empreinte (rayon 1) déborde dans le vide")
	_raison(m, Vector3(9.5, 1, 5.5), Vector3.UP, "sol_debord", monde, vide, modeles, 0.0, "",
		"débordement au même bord : accepté")
	_raison(m, Vector3(1.5, 1, 1.5), Vector3.UP, "sol_libre", monde, vide, modeles, 0.0, "sous_la_matiere",
		"voisinage libre sous la dalle (3 cases de haut, plafond à 2) : refusé")
	_raison(m, Vector3(1.5, 1, 1.5), Vector3.UP, "sol_debord", monde, vide, modeles, 0.0, "",
		"débordement sous la dalle : accepté")
	_raison(m, Vector3(6.5, 1, 6.5), Vector3.UP, "sol_debord", monde, vide, modeles, 0.0, "dans_l_eau",
		"planté dans l'eau : refusé, même en débordement")
	_raison(m, Vector3(6.5, 5, 6.5), Vector3.UP, "air", monde, vide, modeles, 0.0, "",
		"dans le vide au-dessus de l'eau : l'eau ne compte pas")
	var pente_45 := Vector3(1, 1, 0).normalized()
	var pente_30 := Vector3(sin(deg_to_rad(30.0)), cos(deg_to_rad(30.0)), 0)
	_raison(m, Vector3(5.5, 1, 5.5), pente_45, "sol_debord", monde, vide, modeles, 0.0, "trop_pentu",
		"un sol à 45° (maxi 40°) : trop pentu")
	_raison(m, Vector3(5.5, 1, 5.5), pente_30, "sol_debord", monde, vide, modeles, 0.0, "",
		"un sol à 30° : accepté")
	_raison(m, Vector3(5.5, 1, 5.5), pente_45, "air", monde, vide, modeles, 0.0, "",
		"dans le vide, la pente n'est pas regardée")
	# L'échelle porte l'empreinte : au demi, le bord du plateau la porte encore.
	var demi := m.duplicate()
	demi["echelle"] = 0.5
	_raison(demi, Vector3(9.4, 1, 5.5), Vector3.UP, "sol_libre", monde, vide, {1: demi}, 0.0, "",
		"à l'échelle ½ (rayon 0,5) à 0,6 du bord : porté")
	_raison(m, Vector3(9.4, 1, 5.5), Vector3.UP, "sol_libre", monde, vide, modeles, 0.0, "au_bord",
		"à l'échelle 1 (rayon 1) au même point : au bord")

	# ── 3. les voisins
	print("── 3. les voisins")
	var a := FE.plant(1, 1, Vector3(5.5, 1, 5.5), 0.0, 1.0, "sol")
	var ix := FE.index([a], modeles)
	_raison(m, Vector3(6.5, 1, 5.5), Vector3.UP, "sol_libre", monde, ix, modeles, 0.0, "trop_pres",
		"voisinage libre à 1 case d'un plant (rayons 1 + 1) : trop près")
	_raison(m, Vector3(7.6, 1, 5.5), Vector3.UP, "sol_libre", monde, ix, modeles, 0.0, "",
		"voisinage libre à 2,1 cases : libre")
	_raison(m, Vector3(6.5, 1, 5.5), Vector3.UP, "sol_debord", monde, ix, modeles, 0.0, "",
		"débordement à 1 case, sans espacement : accepté (les feuillages se chevauchent)")
	_raison(m, Vector3(6.5, 1, 5.5), Vector3.UP, "sol_debord", monde, ix, modeles, 1.5, "trop_pres",
		"débordement à 1 case avec un espacement de 1,5 : trop près")
	for mode in FE.MODES:
		_raison(m, Vector3(5.5, 1, 5.5), Vector3.UP, mode, monde, ix, modeles, 0.0, "deja_la",
			"« %s » au point exact d'un plant : déjà là" % mode)
	_vrai(FE.a_effacer(ix, Vector3(5.9, 1, 5.5), 0.5) == [a], "effacer à 0,4 du plant le prend")
	_vrai(FE.a_effacer(ix, Vector3(7.5, 1, 5.5), 0.5).is_empty(), "effacer à 2 cases ne le prend pas")
	FE.desindexer(ix, a)
	_raison(m, Vector3(6.5, 1, 5.5), Vector3.UP, "sol_libre", monde, ix, modeles, 0.0, "",
		"le plant retiré de l'index : la place est libre")

	# ── 4. où le modèle est posé
	print("── 4. la transformation")
	var t_m := FE.modele(2, "T", "")
	t_m["decalage"] = -0.4
	t_m["echelle"] = 2.0
	var t := FE.transformation(t_m, FE.plant(1, 2, Vector3(1, 2, 3), PI / 2.0, 1.5, "sol"))
	_vrai(t.origin.is_equal_approx(Vector3(1, 2 - 0.4 * 3.0, 3)), "l'origine : le sol, levée du décalage × 3 (%s)" % t.origin)
	_vrai((t.basis * Vector3(1, 0, 0)).is_equal_approx(Vector3(0, 0, -3)), "un quart de tour : +X va vers −Z, échelle 3")
	_vrai((t.basis * Vector3(0, 1, 0)).is_equal_approx(Vector3(0, 3, 0)), "le haut reste le haut")

	# ── 5. le pinceau
	print("── 5. le pinceau")
	var m2 := m.duplicate()
	m2["rayon"] = 0.5
	var ms2 := {1: m2}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ix2 := FE.index([], ms2)
	var r: Dictionary = FE.semer(m2, Vector3(5, 2, 5), 6.0, 400, "sol_libre", monde, ix2, ms2, rng)
	var plants: Array = r["plants"]
	_vrai(plants.size() > 20, "voisinage libre : le pinceau plante (%d plants)" % plants.size())
	_vrai((r["refus"] as Dictionary).get("trop_pres", 0) > 0, "… et en refuse pour leurs voisins (%s)" % r["refus"])
	_vrai((r["refus"] as Dictionary).get("au_bord", 0) > 0 or (r["refus"] as Dictionary).get("pas_de_sol", 0) > 0,
		"… et au bord du plateau")
	var proches_ := 0
	var mal_poses := 0
	for i in plants.size():
		var p: Vector3 = plants[i]["p"]
		if p.y != 1.0 or p.x + 0.5 > 10.0 or p.z + 0.5 > 10.0 or p.x - 0.5 < 0.0 or p.z - 0.5 < 0.0:
			mal_poses += 1
		if p.x < 3.25 and p.z < 3.25:
			mal_poses += 1   # sous la dalle, à mi-rayon
		if p.x >= 6.0 and p.x < 8.0 and p.z >= 6.0 and p.z < 8.0:
			mal_poses += 1   # dans l'eau
		for j in range(i + 1, plants.size()):
			var q: Vector3 = plants[j]["p"]
			if Vector2(p.x - q.x, p.z - q.z).length() < 1.0:
				proches_ += 1
	_vrai(proches_ == 0, "aucune paire à moins de 1 case (rayons 0,5 + 0,5) — %d" % proches_)
	_vrai(mal_poses == 0, "tous au sol (y = 1), empreinte sur le plateau, ni sous la dalle ni dans l'eau — %d" % mal_poses)
	_vrai(ix2["seaux"].values().reduce(func(n, s): return n + (s as Array).size(), 0) == plants.size(),
		"les plants du coup sont dans l'index")
	# Le même tirage rend le même coup.
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 7
	var r_b: Dictionary = FE.semer(m2, Vector3(5, 2, 5), 6.0, 400, "sol_libre", monde, FE.index([], ms2), ms2, rng_b)
	var memes := (r_b["plants"] as Array).all(func(pl): return plants.any(func(q): return q["p"] == pl["p"]))
	_vrai((r_b["plants"] as Array).size() == plants.size() and memes, "la même graine, le même coup")
	# Débordement, espacement 0,8 : plus serré, et sous la dalle aussi.
	rng.seed = 7
	var r2: Dictionary = FE.semer(m2, Vector3(5, 2, 5), 6.0, 400, "sol_debord", monde, FE.index([], ms2), ms2, rng, 0.8)
	var p2: Array = r2["plants"]
	var serres := 0
	var sous_dalle := 0
	for i in p2.size():
		var p: Vector3 = p2[i]["p"]
		if p.x < 3.0 and p.z < 3.0:
			sous_dalle += 1
		for j in range(i + 1, p2.size()):
			var q: Vector3 = p2[j]["p"]
			if Vector2(p.x - q.x, p.z - q.z).length() < 0.8:
				serres += 1
	_vrai(serres == 0, "débordement : l'espacement de 0,8 est tenu (%d paires plus proches)" % serres)
	_vrai(p2.size() > plants.size(), "débordement plante plus serré (%d contre %d)" % [p2.size(), plants.size()])
	_vrai(sous_dalle > 0, "débordement plante sous la dalle (%d)" % sous_dalle)
	# Dans le vide : sur le plan.
	rng.seed = 3
	var r3: Dictionary = FE.semer(m2, Vector3(30, 7, 30), 3.0, 50, "air", monde, FE.index([], ms2), ms2, rng, 0.5)
	var sur_le_plan := (r3["plants"] as Array).all(func(pl): return (pl["p"] as Vector3).y == 7.0 and pl["mode"] == "air")
	_vrai((r3["plants"] as Array).size() > 5 and sur_le_plan, "dans le vide : tous sur le plan y = 7, mode « air »")

	# ── 6. le fichier
	print("── 6. le fichier")
	var d := FE.vers_donnees([m, t_m], [a, FE.plant(2, 2, Vector3(-3.25, 7, 0.5), 1.0, 0.9, "air")])
	var err: Array = []
	var relu := FE.depuis_donnees(JSON.parse_string(JSON.stringify(d)), err)
	_vrai(err.is_empty() and (relu["modeles"] as Array).size() == 2 and (relu["plants"] as Array).size() == 2,
		"relu : deux modèles, deux plants")
	_vrai(float(relu["modeles"][1]["decalage"]) == -0.4 and float(relu["modeles"][1]["echelle"]) == 2.0,
		"le décalage et l'échelle du modèle reviennent")
	_vrai(relu["plants"][1]["p"] == Vector3(-3.25, 7, 0.5) and relu["plants"][1]["mode"] == "air"
		and is_equal_approx(relu["plants"][1]["lacet"], 1.0) and is_equal_approx(relu["plants"][1]["echelle"], 0.9),
		"le plant dans le vide revient (point, mode, lacet, échelle)")
	_vrai(FE.depuis_donnees(null, err)["plants"].is_empty(), "un projet d'avant (sans feuillage) : rien")
	for mal in [{"modeles": [], "plants": [1, 2, 3]}, {"modeles": [{"id": 1}], "plants": [2, 0, 0, 0, 0, 1, 1]},
			{"modeles": [{"id": 1}, {"id": 1}], "plants": []}, {"modeles": [{"id": 1, "echelle": "x"}], "plants": []},
			{"modeles": [{"id": 1}], "plants": [1, 0, 0, "a", 0, 1, 1]}, "abc"]:
		var e2: Array = []
		_vrai(FE.depuis_donnees(mal, e2).is_empty() and not e2.is_empty(), "refusé : %s (%s)" % [str(mal).left(60),
			"" if e2.is_empty() else e2[0]])

	# ── 7. le décalage compte dans la hauteur à dégager
	print("── 7. le décalage et la hauteur")
	var enfonce := m.duplicate()
	enfonce["decalage"] = -2.0   # haut 3, enfoncé de 2 : il dépasse d'une case
	_raison(enfonce, Vector3(1.5, 1, 1.5), Vector3.UP, "sol_libre", monde, vide, {1: enfonce}, 0.0, "",
		"enfoncé de 2 (il ne dépasse que d'une case) : il tient sous la dalle")
	_vrai(is_equal_approx(FE.hauteur_au_dessus_du_sol(enfonce, FE.plant(1, 1, Vector3.ZERO, 0.0, 2.0, "sol")), 2.0),
		"hauteur au-dessus du sol = (3 − 2) × 2 = 2")

	# ── 8. le rendu : le .glb, ses réglages déduits, le vent, les MultiMesh
	print("── 8. le rendu")
	var chemin := "user://test_feuillage/arbre.glb"
	_vrai(Arbre.ecrire(chemin) == "", "l'arbre d'essai s'écrit en .glb")
	var dg := FeuillageVue.charger(chemin)
	_vrai(dg["erreur"] == "" and (dg["parties"] as Array).size() == 2, "relu : deux parties (%s)" % dg["erreur"])
	var b: AABB = dg["aabb"]
	# ⚠ LA SPHÈRE EST FACETTÉE : sa largeur est celle de son polygone (à 0,002 près de 1,4).
	_vrai(absf(b.position.y - Arbre.BAS) < 1e-3 and absf(b.end.y - Arbre.HAUT) < 1e-3
		and absf(b.size.x - Arbre.LARGEUR) < 0.005, "sa boîte : de −0,3 à 2,3, large de 1,4 (%s)" % b)
	var defauts := FeuillageVue.reglages_par_defaut(dg)
	_vrai(absf(defauts["decalage"] - 0.3) < 1e-3 and absf(defauts["hauteur"] - 2.3) < 1e-3
		and absf(defauts["rayon"] - 0.35 * 1.4) < 0.002, "par défaut : posé sur sa base (0,3), haut 2,3, empreinte 0,49")
	var feuilles: Material = null
	var ecorce: Material = null
	var tronc := -1
	for k in (dg["parties"] as Array).size():
		var mat: BaseMaterial3D = dg["parties"][k][2][0]
		if mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
			feuilles = FeuillageVue.materiau_du_vent(mat)
		else:
			ecorce = FeuillageVue.materiau_du_vent(mat)
			tronc = k
	_vrai(feuilles is ShaderMaterial and (feuilles as ShaderMaterial).shader.code.contains("ALPHA_SCISSOR_THRESHOLD")
		and (feuilles as ShaderMaterial).shader.code.contains("cull_disabled"),
		"les feuilles : le shader du vent, en découpe alpha, double face")
	_vrai(ecorce is ShaderMaterial and not (ecorce as ShaderMaterial).shader.code.contains("ALPHA =")
		and (ecorce as ShaderMaterial).shader.code.contains("cull_back"), "l'écorce : opaque, une face")
	_vrai((ecorce as ShaderMaterial).shader.code.contains("INSTANCE_CUSTOM.y")
		and (ecorce as ShaderMaterial).get_shader_parameter("albedo") == Color("#6b4a2f"),
		"le vent lit le sol et la hauteur du plant ; la couleur du fichier est gardée")
	var mod := FE.modele(5, "Arbre", chemin)
	mod.merge(defauts, true)
	mod["vent"] = 0.7
	var vf := FeuillageVue.new()
	root.add_child(vf)
	var pl0 := FE.plant(1, 5, Vector3(1, 2, 3), 0.0, 1.0, "sol")
	vf.poser([mod], [pl0, FE.plant(2, 5, Vector3(4, 2, 3), 1.0, 1.2, "sol"), FE.plant(3, 5, Vector3(7, 2, 3), 2.0, 0.8, "sol")])
	_vrai(vf.nombre_dessine(5) == 3 and vf.multimeshes(5).size() == 2, "trois plants, une MultiMesh par partie")
	var mmt: MultiMeshInstance3D = vf.multimeshes(5)[tronc]
	var inst := FeuillageVue.instances(mod, [pl0], dg["parties"][tronc][1])
	var o: Vector3 = (inst[0][0] as Transform3D).origin
	_vrai(o.is_equal_approx(Vector3(1, 2 + 0.3 + Arbre.TRONC_Y, 3)), "le tronc du premier : sol 2 + décalage 0,3 + 0,45 (%s)" % o)
	var cd: Color = inst[1][0]
	_vrai(is_equal_approx(cd.r, 2.0) and is_equal_approx(cd.g, 2.6) and is_equal_approx(cd.a, 0.7),
		"ce que le vent reçoit : le sol 2, la hauteur 2,6 (2,3 + 0,3), l'amplitude 0,7 (%s)" % cd)
	var tourne := FeuillageVue.instances(mod, [FE.plant(2, 5, Vector3(4, 2, 3), PI / 2.0, 2.0, "sol")], Transform3D.IDENTITY)
	_vrai(((tourne[0][0] as Transform3D).basis * Vector3(1, 0, 0)).is_equal_approx(Vector3(0, 0, -2))
		and is_equal_approx((tourne[1][0] as Color).g, 5.2), "tourné d'un quart et doublé : +X vers −Z, hauteur 5,2")
	vf.poser([mod], [pl0])
	_vrai(vf.nombre_dessine(5) == 1, "reposé avec un plant : un seul")
	vf.poser([], [])
	_vrai(vf.nombre_dessine(5) == 0, "sans modèle : plus rien")
	vf.queue_free()
	_vrai(FeuillageVue.charger("user://test_feuillage/absent.glb")["erreur"] != "", "un fichier absent est DIT")

	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	print("VERDICT : %s" % ("ÉCHEC" if _echecs > 0 else "OK"))
	quit(1 if _echecs > 0 else 0)


func _raison(m: Dictionary, p: Vector3, n: Vector3, mode: String, monde: Dictionary, ix: Dictionary,
		modeles: Dictionary, espacement: float, attendu: String, quoi: String) -> void:
	var pl := FE.plant(-1, int(m["id"]), p, 0.0, 1.0, mode)
	var r := FE.verifier(m, pl, n, mode, monde, ix, modeles, espacement)
	_vrai(r == attendu, "%s (« %s »)" % [quoi, r])


func _vrai(v: bool, quoi: String) -> void:
	if v:
		_ok += 1
		print("  ✓ %s" % quoi)
	else:
		_echecs += 1
		print("  ÉCHEC — %s" % quoi)
