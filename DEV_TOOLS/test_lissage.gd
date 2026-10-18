extends SceneTree
##
## TEST — le smooth shading des tuiles (`MaillageEdite.normales_des_coins`, la 1.0.0 : Jordan, 19 octobre 2026).
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_lissage.gd
##
## ⚠ **CE QUI EST GARDÉ, C'EST CE QUI SE VERRAIT** : une arête vive arrondie (un cube qui devient un savon), une surface
## courbe encore à facettes, et surtout une COUTURE D'OMBRE au bord de deux tuiles voisines du monde qui ne se sont pas
## lissées pareil. Les normales comparées sont celles que Godot dessine (`vers_array_mesh`), pas celles de la fonction.

const ME := preload("res://addons/marchingblocks_core/maillage_edite.gd")
const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")

var _ok := 0
var _echecs := 0


func _initialize() -> void:
	print("=== TEST — le smooth shading des tuiles ===\n")
	_le_plat_ne_change_pas()
	_l_arete_vive_reste_vive()
	_la_courbe_est_lisse()
	_le_bord_est_commun()
	_le_temoin_le_garde()
	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	print("VERDICT : %s" % ("OK" if _echecs == 0 else "ÉCHEC"))
	quit(0 if _echecs == 0 else 1)


func _vrai(v: bool, quoi: String) -> void:
	if v:
		_ok += 1
	else:
		_echecs += 1
		print("  ✗ " + quoi)


## Un maillage fait de quads posés sur une grille de hauteurs : x de x0 à x0 + n·pas, z de −0,5 à 0,5.
static func _nappe(x0: float, n: int, hauteur: Callable) -> RefCounted:
	var m: RefCounted = ME.new()
	var pas := 1.0 / float(n)
	var ids := {}
	for i in n + 1:
		for k in n + 1:
			var x := x0 + i * pas
			var z := -0.5 + k * pas
			ids[Vector2i(i, k)] = m.sommets.size()
			m.sommets.append(Vector3(x, hauteur.call(x, z), z))
	for i in n:
		for k in n:
			# Trigonométrique vu d'en haut (+Y) : la normale monte.
			m._ajouter(PackedInt32Array([ids[Vector2i(i, k)], ids[Vector2i(i, k + 1)], ids[Vector2i(i + 1, k + 1)],
				ids[Vector2i(i + 1, k)]]), Color.WHITE, -1)
	return m


## {position arrondie: [normales dessinées]} — lues dans le maillage que Godot dessine.
static func _normales_dessinees(m: RefCounted) -> Dictionary:
	var d := {}
	var mesh: ArrayMesh = m.vers_array_mesh()
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var nor: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		for i in pos.size():
			var k := (pos[i] * 1000.0).round()
			if not d.has(k):
				d[k] = []
			d[k].append(nor[i])
	return d


static func _cube() -> RefCounted:
	var m: RefCounted = ME.new()
	for i in 8:
		m.sommets.append(Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1) * 0.6 - Vector3(0.3, 0.3, 0.3))
	for f in [[0, 4, 6, 2], [1, 3, 7, 5], [0, 1, 5, 4], [2, 6, 7, 3], [0, 2, 3, 1], [4, 5, 7, 6]]:
		m._ajouter(PackedInt32Array(f), Color.WHITE, -1)
	return m


func _le_plat_ne_change_pas() -> void:
	print("— plat (0°)")
	var m := _cube()
	var mesh: ArrayMesh = m.vers_array_mesh()
	var a := mesh.surface_get_arrays(0)
	var faux := 0
	for i in (a[Mesh.ARRAY_NORMAL] as PackedVector3Array).size():
		var n: Vector3 = a[Mesh.ARRAY_NORMAL][i]
		if absf(absf(n.x) + absf(n.y) + absf(n.z) - 1.0) > 1e-4:
			faux += 1
	_vrai(faux == 0, "sans lissage, chaque coin porte la normale de sa face (%d coins de travers)" % faux)


func _l_arete_vive_reste_vive() -> void:
	print("— l'arête vive")
	var m := _cube()
	m.lissage = 40.0
	var faux := 0
	for k in _normales_dessinees(m).values():
		for n in k:
			if absf(absf(n.x) + absf(n.y) + absf(n.z) - 1.0) > 1e-4:
				faux += 1
	_vrai(faux == 0, "à 40°, les arêtes de 90° d'un cube restent vives (%d coins arrondis)" % faux)
	m.lissage = 120.0
	var ronds := 0
	for k in _normales_dessinees(m).values():
		for n in k:
			if absf(absf(n.x) + absf(n.y) + absf(n.z) - 1.0) > 1e-3:
				ronds += 1
	_vrai(ronds > 0, "à 120°, elles s'arrondissent (%d coins)" % ronds)


func _la_courbe_est_lisse() -> void:
	print("— la courbe")
	var m := _nappe(-0.4, 6, func(x: float, z: float) -> float: return 0.15 * sin(x * 6.0) * cos(z * 5.0))
	m.lissage = 60.0
	var ecarts := 0
	var sommets := 0
	for k in _normales_dessinees(m).values():
		sommets += 1
		for n in k:
			if (n as Vector3).distance_to(k[0]) > 1e-5:
				ecarts += 1
	_vrai(ecarts == 0, "à 60°, chaque sommet d'une nappe douce n'a qu'UNE normale (%d coins en désaccord sur %d sommets)"
		% [ecarts, sommets])
	m.lissage = 0.0
	var plats := 0
	for k in _normales_dessinees(m).values():
		for n in k:
			if (n as Vector3).distance_to(k[0]) > 1e-3:
				plats += 1
	_vrai(plats > 0, "à plat, la même nappe montre ses facettes (%d coins en désaccord)" % plats)


## DEUX TUILES VOISINES DU MONDE : A finit en x = +0,5, B commence en x = −0,5 de sa case (la case d'à côté). Leur coupe
## est la même (les bords partagés), leur relief différent de part et d'autre. Les normales du bord doivent être les
## mêmes, sinon le monde montre une ligne d'ombre à chaque joint.
func _le_bord_est_commun() -> void:
	print("— le bord commun")
	var coupe := func(z: float) -> float: return 0.12 * sin(z * 4.0 + 0.3)
	# A : la coupe en x = 0,5, une bosse au milieu. B : la même coupe en x = −0,5 (son repère), une pente forte.
	var a := _nappe(-0.5, 5, func(x: float, z: float) -> float:
		return coupe.call(z) + 0.2 * (0.25 - (x - 0.0) * (x - 0.0)) * (0.5 - x))
	var b := _nappe(-0.5, 5, func(x: float, z: float) -> float:
		return coupe.call(z) + 0.35 * (x + 0.5) * (x + 0.5))
	a.lissage = 60.0
	b.lissage = 60.0
	var na := _normales_dessinees(a)
	var nb := _normales_dessinees(b)
	var compares := 0
	var coutures := 0
	for k in na:
		var p: Vector3 = k / 1000.0
		if absf(p.x - 0.5) > 1e-3:
			continue
		var kb: Vector3 = ((p - Vector3(1, 0, 0)) * 1000.0).round()
		if not nb.has(kb):
			continue
		compares += 1
		if (na[k][0] as Vector3).distance_to(nb[kb][0]) > 1e-4:
			coutures += 1
	_vrai(compares >= 5, "des sommets du bord à comparer (%d)" % compares)
	_vrai(coutures == 0, "le bord de A et celui de B ont la même normale : pas de couture d'ombre (%d en désaccord)"
		% coutures)


func _le_temoin_le_garde() -> void:
	print("— le témoin")
	var nulles := 0
	for m in [_cube(), _nappe(-0.5, 4, func(x: float, z: float) -> float: return 0.1 * sin(x * 5.0 + z))]:
		m.lissage = 50.0
		for k in _normales_dessinees(m).values():
			for n in k:
				if absf((n as Vector3).length() - 1.0) > 1e-3:
					nulles += 1
	_vrai(nulles == 0, "toutes les normales dessinées sont unitaires (%d de travers)" % nulles)
	var t: RefCounted = TL.new()
	t.tuiles["essai"] = _cube()
	t.lissage = 45.0
	t._partager()
	_vrai(is_equal_approx(t.tuiles["essai"].lissage, 45.0), "le lissage du témoin est donné à ses tuiles")
	var relu: RefCounted = TL.depuis_dictionnaire(t.vers_dictionnaire())
	_vrai(relu != null and is_equal_approx(relu.lissage, 45.0) and is_equal_approx(relu.tuiles["essai"].lissage, 45.0),
		"il part dans le .mbtiles et revient, tuiles comprises")
	var copie: RefCounted = t.copie()
	_vrai(is_equal_approx(copie.lissage, 45.0) and is_equal_approx(copie.tuiles["essai"].lissage, 45.0),
		"une copie du témoin (l'annulation) le garde")
	t.lissage = 0.0
	var vieux: Dictionary = t.vers_dictionnaire()
	_vrai(not vieux.has("lissage"), "un témoin plat n'écrit rien (les fichiers d'avant restent identiques)")
