extends SceneTree
##
## TEST — le cœur du modeleur (`maillage_edite.gd`) : chaque opération sur un cube, jugée par des
## INVARIANTS qui ne passent pas par elle.
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_maillage_edite.gd
##
## ⚠ **UN TEST NE CALCULE JAMAIS SON ATTENDU AVEC LA FONCTION QU'IL ÉPROUVE** (charte §6). Les attendus
## viennent d'ailleurs :
##   - ÉTANCHE : chaque arête est bordée par exactement deux faces ;
##   - ORIENTÉ : chaque arête orientée a→b n'apparaît qu'une fois (sa voisine porte b→a) — une face
##     retournée le casse ;
##   - EULER : V − E + F = 2 pour une coque fermée de genre 0 ;
##   - LE VOLUME, par le théorème de la divergence (somme des tétraèdres depuis l'origine) — positif
##     seulement si les faces regardent DEHORS, et égal au volume attendu, calculé à la main ;
##   - des POSITIONS écrites à la main.

const ME := preload("res://addons/marchingblocks_core/maillage_edite.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")

var _ok := 0
var _echecs := 0


func _initialize() -> void:
	print("=== TEST — le maillage qu'on édite ===\n")
	_le_cube_de_reference()
	_la_lecture_recolle_les_quads()
	_la_sortie_pour_godot()
	_extruder_des_faces()
	_extruder_des_aretes()
	_l_inset()
	_supprimer_puis_remplir()
	_fusionner()
	_subdiviser()
	_le_loop_cut()
	_la_boucle_d_aretes()
	_transformer_et_proportionnel()
	_le_rayon()
	_le_biseau()
	_le_couteau()
	_le_temoin()
	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	print("VERDICT : %s" % ("OK" if _echecs == 0 else "ÉCHEC"))
	quit(0 if _echecs == 0 else 1)


# ── Le cube unitaire, écrit à la main ───────────────────────────────────────────────────────────────
#
# Sommets 0..7 : bit 1 = x, bit 2 = y, bit 4 = z. Faces trigonométriques vues de DEHORS.
func _cube() -> RefCounted:
	var m: RefCounted = ME.new()
	for i in 8:
		m.sommets.append(Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1))
	for f in [[0, 4, 6, 2], [1, 3, 7, 5], [0, 1, 5, 4], [2, 6, 7, 3], [0, 2, 3, 1], [4, 5, 7, 6]]:
		m.faces.append(PackedInt32Array(f))
		m.teintes.append(Color.WHITE)
	return m


## Le volume signé, par tétraèdres depuis l'origine (éventail sur chaque face).
func _volume(m: RefCounted) -> float:
	var v := 0.0
	for f in m.faces:
		var p0: Vector3 = m.sommets[f[0]]
		for i in range(1, f.size() - 1):
			v += p0.dot((m.sommets[f[i]] as Vector3).cross(m.sommets[f[i + 1]])) / 6.0
	return v


## « » si la coque est fermée ET orientée, sinon ce qui cloche.
func _etanche(m: RefCounted) -> String:
	var orientees := {}
	var usage := {}
	for f in m.faces:
		for i in f.size():
			var a: int = f[i]
			var b: int = f[(i + 1) % f.size()]
			if orientees.has(Vector2i(a, b)):
				return "l'arête %d→%d est parcourue deux fois dans le même sens (une face retournée)" % [a, b]
			orientees[Vector2i(a, b)] = true
			var e := Vector2i(mini(a, b), maxi(a, b))
			usage[e] = usage.get(e, 0) + 1
	for e in usage:
		if usage[e] != 2:
			return "l'arête %s est bordée par %d face(s)" % [e, usage[e]]
	return ""


func _euler(m: RefCounted) -> int:
	var e := {}
	for f in m.faces:
		for i in f.size():
			var a: int = f[i]
			var b: int = f[(i + 1) % f.size()]
			e[Vector2i(mini(a, b), maxi(a, b))] = true
	return m.sommets.size() - e.size() + m.faces.size()


func _bords(m: RefCounted) -> int:
	var usage := {}
	for f in m.faces:
		for i in f.size():
			var a: int = f[i]
			var b: int = f[(i + 1) % f.size()]
			var e := Vector2i(mini(a, b), maxi(a, b))
			usage[e] = usage.get(e, 0) + 1
	return usage.values().filter(func(n): return n == 1).size()


func _face_du_haut(m: RefCounted) -> int:
	for f in m.faces.size():
		var tous := true
		for i in m.faces[f]:
			tous = tous and is_equal_approx(m.sommets[i].y, 1.0)
		if tous:
			return f
	return -1


# ── 1 ───────────────────────────────────────────────────────────────────────────────────────────────
func _le_cube_de_reference() -> void:
	var c := _cube()
	_egal(_etanche(c), "", "le cube de référence est étanche et orienté")
	_vrai(is_equal_approx(_volume(c), 1.0), "le cube de référence a un volume de +1 (faces vers DEHORS)")
	_egal(_euler(c), 2, "Euler du cube")
	for f in c.faces.size():
		var n: Vector3 = c.normale(f)
		var ctr: Vector3 = c.centre(f)
		_vrai(n.dot(ctr - Vector3.ONE * 0.5) > 0.4, "la normale de Newell de la face %d regarde dehors" % f)


# ── 2 ───────────────────────────────────────────────────────────────────────────────────────────────
func _la_lecture_recolle_les_quads() -> void:
	var m := ME.depuis(_cube().vers_array_mesh())
	_egal(m.sommets.size(), 8, "relu : les sommets soudés par position")
	_egal(m.faces.size(), 6, "relu : les 12 triangles redeviennent 6 QUADS")
	_vrai(m.faces.all(func(f): return (f as PackedInt32Array).size() == 4), "relu : que des quads")
	_egal(_etanche(m), "", "relu : étanche et orienté")
	_vrai(is_equal_approx(_volume(m), 1.0), "relu : volume +1 — le sens de Godot est bien retourné À LA LECTURE")


# ── 3 ───────────────────────────────────────────────────────────────────────────────────────────────
func _la_sortie_pour_godot() -> void:
	var c := _cube()
	var mesh: ArrayMesh = c.vers_array_mesh()
	var a: Array = mesh.surface_get_arrays(0)
	var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	_egal(pos.size(), 36, "6 quads = 12 triangles = 36 sommets")
	# ⚠ GODOT DESSINE EN HORAIRE : le produit vectoriel de l'ordre stocké pointe À L'OPPOSÉ de la normale
	# sortante (charte §4). Jugé contre le centre du cube, pas contre `normale()`.
	var retournes := 0
	for t in range(0, pos.size(), 3):
		var n: Vector3 = (pos[t + 1] - pos[t]).cross(pos[t + 2] - pos[t])
		var ctr: Vector3 = (pos[t] + pos[t + 1] + pos[t + 2]) / 3.0 - Vector3.ONE * 0.5
		if n.dot(ctr) >= 0.0:
			retournes += 1
	_egal(retournes, 0, "triangles écrits dans le sens trigonométrique (Godot les montrerait de dos)")


# ── 4 ───────────────────────────────────────────────────────────────────────────────────────────────
func _extruder_des_faces() -> void:
	var c := _cube()
	var r: Dictionary = c.extruder_faces([_face_du_haut(c)])
	_egal(c.sommets.size(), 12, "extruder le dessus : 4 sommets de plus")
	_egal(c.faces.size(), 10, "extruder le dessus : 4 quads de côté de plus")
	_egal(_etanche(c), "", "extruder : toujours étanche et orienté")
	_egal(_euler(c), 2, "extruder : Euler")
	_vrai(is_equal_approx(_volume(c), 1.0), "extruder SANS déplacer ne change pas le volume")
	_vrai(r["normale"].is_equal_approx(Vector3.UP), "la normale de la région est +Y")
	var depart: PackedVector3Array = c.sommets.duplicate()
	c.transformer(r["sommets"], Transform3D(Basis(), Vector3.UP), depart)
	_vrai(is_equal_approx(_volume(c), 2.0), "extruder puis monter d'une case : volume 2 (%.3f)" % _volume(c))
	var hauts := 0
	for p in c.sommets:
		if is_equal_approx(p.y, 2.0):
			hauts += 1
	_egal(hauts, 4, "les quatre sommets extrudés sont à y = 2")
	# Deux faces voisines ensemble : UNE région, donc pas de mur entre elles.
	var d := _cube()
	var cote := -1
	for f in d.faces.size():
		if d.faces[f] == PackedInt32Array([1, 3, 7, 5]):
			cote = f
	d.extruder_faces([_face_du_haut(d), cote])
	_egal(d.faces.size(), 6 + 6, "deux faces voisines : 6 quads de bord, pas de mur entre elles")
	_egal(_etanche(d), "", "région de deux faces : étanche")


func _extruder_des_aretes() -> void:
	var c := _cube()
	c.supprimer_faces([_face_du_haut(c)])
	_egal(_bords(c), 4, "un trou : quatre arêtes de bord")
	var r: Array = c.extruder_aretes([Vector2i(2, 3)])
	_egal(r.size(), 2, "extruder une arête : deux sommets neufs")
	_egal(c.faces.size(), 6, "extruder une arête : une face neuve")
	var orientees := {}
	var double := false
	for f in c.faces:
		for i in f.size():
			var k := Vector2i(f[i], f[(i + 1) % f.size()])
			double = double or orientees.has(k)
			orientees[k] = true
	_vrai(not double, "la face neuve est orientée contre sa voisine")


# ── 5 ───────────────────────────────────────────────────────────────────────────────────────────────
func _l_inset() -> void:
	var c := _cube()
	c.inserer([_face_du_haut(c)], 0.25)
	_egal(_etanche(c), "", "inset : étanche et orienté")
	_egal(c.faces.size(), 10, "inset : la face et ses 4 bandes")
	_vrai(is_equal_approx(_volume(c), 1.0), "inset : le volume ne change pas (tout reste dans le plan)")
	var dedans := {}
	for p in c.sommets:
		if is_equal_approx(p.y, 1.0) and p.x > 0.1 and p.x < 0.9:
			dedans[Vector3i(roundi(p.x * 100), 100, roundi(p.z * 100))] = true
	_egal(dedans, {Vector3i(25, 100, 25): true, Vector3i(75, 100, 25): true, Vector3i(25, 100, 75): true,
		Vector3i(75, 100, 75): true}, "inset de 0,25 : les coins rentrent de 0,25 sur CHAQUE axe (bissectrice)")


# ── 6 ───────────────────────────────────────────────────────────────────────────────────────────────
func _supprimer_puis_remplir() -> void:
	var c := _cube()
	c.supprimer_faces([_face_du_haut(c)])
	_egal(c.faces.size(), 5, "supprimer le dessus : 5 faces")
	_egal(_bords(c), 4, "et un trou de 4 arêtes")
	var ids: Array = []
	for i in c.sommets.size():
		if is_equal_approx(c.sommets[i].y, 1.0):
			ids.append(i)
	# L'ordre donné est DÉLIBÉRÉMENT en croix : F doit le remettre en ordre.
	ids = [ids[0], ids[3], ids[1], ids[2]]
	# ⚠ LES DEUX ORDRES : avec un seul, le rangement par angle tombait par chance dans le bon sens et la
	# correction d'orientation restait sans garde (mutation muette, vue).
	for ordre in [ids, [ids[3], ids[2], ids[1], ids[0]]]:
		var t: RefCounted = c.copie()
		var f: int = t.remplir(ordre)
		_vrai(f >= 0, "F rend une face")
		_egal(_etanche(t), "", "F rebouche : étanche et ORIENTÉ comme ses voisines (ordre %s)" % str(ordre))
		_vrai(is_equal_approx(_volume(t), 1.0), "F rebouche : volume +1 (ordre %s)" % str(ordre))
	var s := _cube()
	s.supprimer_sommets([7])
	_egal(s.faces.size(), 3, "supprimer un sommet emporte ses trois faces")
	var a := _cube()
	a.supprimer_aretes([Vector2i(6, 7)])
	_egal(a.faces.size(), 4, "supprimer une arête emporte ses deux faces")


# ── 7 ───────────────────────────────────────────────────────────────────────────────────────────────
func _fusionner() -> void:
	var c := _cube()
	var i: int = c.fusionner([6, 7])
	_egal(c.sommets.size(), 7, "fusionner deux sommets : 7")
	_egal(_etanche(c), "", "fusionner une arête : toujours étanche")
	_egal(_euler(c), 2, "fusionner : Euler")
	_vrai(c.sommets[i].is_equal_approx(Vector3(0.5, 1, 1)), "le sommet restant est au MILIEU")


# ── 8 ───────────────────────────────────────────────────────────────────────────────────────────────
func _subdiviser() -> void:
	var c := _cube()
	var neuves: Array = c.subdiviser([_face_du_haut(c)])
	_egal(neuves.size(), 4, "subdiviser un quad : 4 quads")
	_egal(c.sommets.size(), 8 + 4 + 1, "4 milieux et un centre")
	_egal(_etanche(c), "", "subdiviser : étanche — les voisines ont reçu les milieux (pas de fente en T)")
	_egal(_euler(c), 2, "subdiviser : Euler")
	_vrai(is_equal_approx(_volume(c), 1.0), "subdiviser : volume inchangé")


# ── 9 ───────────────────────────────────────────────────────────────────────────────────────────────
func _le_loop_cut() -> void:
	var c := _cube()
	# L'arête verticale 0-2 : l'anneau passe par les quatre arêtes verticales.
	var ring: Array = c.anneau(Vector2i(0, 2))
	var verticales := {}
	for e in ring:
		verticales[Vector2i(mini(e[0], e[1]), maxi(e[0], e[1]))] = true
	_egal(verticales, {Vector2i(0, 2): true, Vector2i(1, 3): true, Vector2i(4, 6): true, Vector2i(5, 7): true},
		"l'anneau d'une arête verticale : les quatre verticales, et elles seules")
	var neufs: Array = c.couper_en_boucle(Vector2i(0, 2))
	_egal(neufs.size(), 4, "loop cut : 4 sommets neufs")
	_egal(c.faces.size(), 10, "loop cut : les 4 côtés fendus en deux")
	_egal(_etanche(c), "", "loop cut : étanche et orienté")
	_vrai(neufs.all(func(i): return is_equal_approx(c.sommets[i].y, 0.5)),
		"loop cut : les sommets neufs sont À MI-HAUTEUR (la coupe ne zigzague pas)")
	# Un t de 0,25 : ORIENTÉ — tous du même côté.
	var d := _cube()
	var q: Array = d.couper_en_boucle(Vector2i(0, 2), 0.25)
	var ys := {}
	for i in q:
		ys[snappedf(d.sommets[i].y, 0.001)] = true
	_egal(ys.size(), 1, "loop cut à t = 0,25 : les quatre coupes à la MÊME hauteur")
	# ⚠ UN ANNEAU OUVERT, QUI PART DES DEUX CÔTÉS : sur le cube l'anneau se referme dans le premier sens, et
	# le second n'était jamais exercé (mutation muette, vue). Grille 3×3 ; l'arête (5, 9) va de z = 1 à
	# z = 2 en x = 1 ; son anneau traverse la rangée jusqu'aux deux bords.
	var g: RefCounted = ME.new()
	for z in 4:
		for x in 4:
			g.sommets.append(Vector3(x, 0, z))
	for z in 3:
		for x in 3:
			var a := z * 4 + x
			g.faces.append(PackedInt32Array([a, a + 4, a + 5, a + 1]))
			g.teintes.append(Color.WHITE)
	var coupes: Array = g.couper_en_boucle(Vector2i(5, 9), 0.25)
	_egal(coupes.size(), 4, "anneau ouvert : quatre arêtes coupées (x = 0 à 3)")
	var zs := {}
	for i in coupes:
		zs[snappedf(g.sommets[i].z, 0.001)] = true
	_egal(zs, {1.25: true}, "anneau ouvert à t = 0,25 : toutes les coupes à z = 1,25, des DEUX côtés du départ")
	_egal(g.faces.size(), 12, "anneau ouvert : les trois quads de la rangée fendus")


# ── 10 ──────────────────────────────────────────────────────────────────────────────────────────────
func _la_boucle_d_aretes() -> void:
	# Une grille 3×3 de quads (sommets de valence 4 au milieu) : la boucle d'une arête intérieure
	# horizontale traverse toute la rangée.
	var m: RefCounted = ME.new()
	for z in 4:
		for x in 4:
			m.sommets.append(Vector3(x, 0, z))
	for z in 3:
		for x in 3:
			var a := z * 4 + x
			m.faces.append(PackedInt32Array([a, a + 4, a + 5, a + 1]))
			m.teintes.append(Color.WHITE)
	# L'arête (5, 6) est sur la rangée z = 1, entre x = 1 et x = 2.
	var b: Array = m.boucle(Vector2i(5, 6))
	var vues := {}
	for e in b:
		vues[e] = true
	# ⚠ L'ATTENDU ÉCRIT D'ABORD ICI ÉTAIT FAUX ({(5,6)} seule) : 5 et 6 sont INTÉRIEURS, de valence 4 ; la
	# boucle traverse la rangée et ne s'arrête qu'aux bords (4 et 7, de valence 3) — ce que fait Blender.
	_egal(vues, {Vector2i(4, 5): true, Vector2i(5, 6): true, Vector2i(6, 7): true},
		"la boucle d'une arête de la rangée intérieure traverse la rangée, et s'arrête aux BORDS")
	# Sur un tore-grille, la boucle fait le tour : on referme la grille en cylindre (x = 3 soudé à x = 0).
	var cyl: RefCounted = ME.new()
	for z in 4:
		for x in 4:
			cyl.sommets.append(Vector3(cos(x * TAU / 4.0), z, sin(x * TAU / 4.0)))
	for z in 3:
		for x in 4:
			var a := z * 4 + x
			var bx := z * 4 + (x + 1) % 4
			cyl.faces.append(PackedInt32Array([a, bx, bx + 4, a + 4]))
			cyl.teintes.append(Color.WHITE)
	var anneau_h: Array = cyl.boucle(Vector2i(4, 5))
	_egal(anneau_h.size(), 4, "sur un cylindre, la boucle d'une arête horizontale intérieure fait le tour (4 arêtes)")


# ── 11 ──────────────────────────────────────────────────────────────────────────────────────────────
func _transformer_et_proportionnel() -> void:
	var c := _cube()
	var depart: PackedVector3Array = c.sommets.duplicate()
	var pivot := Vector3(0.5, 1, 0.5)
	var rot := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3.ZERO)
	var t := Transform3D(Basis(), pivot) * rot * Transform3D(Basis(), -pivot)
	c.transformer([2, 3, 6, 7], t, depart)
	var dessus := {}
	for i in [2, 3, 6, 7]:
		dessus[Vector3i(roundi(c.sommets[i].x), roundi(c.sommets[i].y), roundi(c.sommets[i].z))] = true
	_egal(dessus.size(), 4, "un quart de tour du dessus autour de son centre garde ses quatre coins distincts")
	_vrai(c.sommets[2].is_equal_approx(Vector3(0, 1, 1)), "R 90 : le coin (0,1,0) va en (0,1,1) — sens de la main droite")
	# Proportionnel : on monte le sommet 3 ; le 7 (à distance 1) suit à moitié ou moins, le 4 (loin) pas.
	var p := _cube()
	var d2: PackedVector3Array = p.sommets.duplicate()
	p.transformer([3], Transform3D(Basis(), Vector3.UP), d2, 1.5)
	_vrai(p.sommets[3].y > 1.99, "proportionnel : le sommet choisi monte d'une case")
	_vrai(p.sommets[7].y > 1.0 and p.sommets[7].y < 2.0, "proportionnel : un voisin proche suit EN PARTIE")
	_vrai(is_equal_approx(p.sommets[4].y, 0.0), "proportionnel : un sommet hors du rayon ne bouge pas")
	var sans := _cube()
	var d3: PackedVector3Array = sans.sommets.duplicate()
	sans.transformer([3], Transform3D(Basis(), Vector3.UP), d3, 0.0)
	_vrai(is_equal_approx(sans.sommets[7].y, 1.0), "sans proportionnel, le voisin ne bouge pas")


# ── 12 ──────────────────────────────────────────────────────────────────────────────────────────────
func _le_rayon() -> void:
	var c := _cube()
	var r: Dictionary = c.lancer_rayon(Vector3(0.5, 5, 0.5), Vector3.DOWN)
	_vrai(not r.is_empty() and r["face"] == _face_du_haut(c), "un rayon tombé d'en haut touche le DESSUS")
	_vrai(not r.is_empty() and is_equal_approx(r["distance"], 4.0), "à 4 cases")
	_vrai(c.lancer_rayon(Vector3(5, 5, 5), Vector3.UP).is_empty(), "un rayon qui s'éloigne ne touche rien")


# ── 12 bis — le biseau, jugé par des VOLUMES calculés à la main ─────────────────────────────────────
func _le_biseau() -> void:
	var c := _cube()
	var q: Array = c.biseauter([Vector2i(6, 7)], 0.25)
	_egal(q.size(), 1, "biseau d'une arête : un quad")
	_egal(_etanche(c), "", "biseau d'une arête : étanche et orienté (les bouts rebouchés)")
	_egal(_euler(c), 2, "biseau d'une arête : Euler")
	# Un prisme triangulaire de côté 0,25 et de longueur 1 part : 1 − 0,25² / 2.
	_vrai(is_equal_approx(_volume(c), 1.0 - 0.03125), "biseau d'une arête de 0,25 : volume 0,96875 (%.5f)" % _volume(c))
	var t := _cube()
	t.biseauter([Vector2i(2, 6), Vector2i(6, 7), Vector2i(3, 7), Vector2i(2, 3)], 0.25)
	_egal(_etanche(t), "", "biseau des quatre arêtes du dessus : étanche et orienté")
	_egal(_euler(t), 2, "biseau du dessus : Euler")
	# Un bloc de 0,75 et, dessus, un tronc de pyramide de 1×1 à 0,5×0,5 sur 0,25 : h/3 (A1 + A2 + √(A1 A2)).
	var attendu := 0.75 + 0.25 / 3.0 * (1.0 + 0.25 + 0.5)
	_vrai(absf(_volume(t) - attendu) < 1e-5, "biseau du dessus : volume %.5f (attendu %.5f) — les ONGLETS aux coins"
		% [_volume(t), attendu])
	var dessus := 0
	for p in t.sommets:
		if is_equal_approx(p.y, 1.0):
			dessus += 1
	_egal(dessus, 4, "biseau du dessus : il reste un carré de quatre sommets en haut")
	var r := _cube()
	_egal(r.biseauter([Vector2i(6, 7)], 0.0), [], "biseau de largeur nulle : rien")


# ── 12 ter — le couteau ─────────────────────────────────────────────────────────────────────────────
func _le_couteau() -> void:
	var c := _cube()
	var neufs: Array = c.couper([{"arete": Vector2i(2, 3), "t": 0.5}, {"arete": Vector2i(6, 7), "t": 0.5}])
	_egal(neufs.size(), 2, "couteau à travers le dessus : deux sommets neufs")
	_egal(c.faces.size(), 7, "le dessus est fendu en deux")
	_egal(_etanche(c), "", "couteau : étanche — les faces voisines ont reçu les points")
	_vrai(is_equal_approx(_volume(c), 1.0), "couteau : volume inchangé")
	var d := _cube()
	d.couper([{"arete": Vector2i(2, 3), "t": 0.5}, {"arete": Vector2i(6, 7), "t": 0.5}, {"arete": Vector2i(4, 5), "t": 0.5}])
	_egal(d.faces.size(), 8, "couteau sur deux faces (le dessus, puis l'avant) : 8 faces")
	_egal(_etanche(d), "", "couteau sur deux faces : étanche")
	var e := _cube()
	var avant: int = e.faces.size()
	var s0: int = e.sommets.size()
	_egal(e.couper([{"arete": Vector2i(0, 1), "t": 0.5}, {"arete": Vector2i(6, 7), "t": 0.5}]), [],
		"deux points sans face commune : refusé")
	_vrai(e.faces.size() == avant and e.sommets.size() == s0, "et rien n'a été coupé à moitié")


# ── 13 ──────────────────────────────────────────────────────────────────────────────────────────────
func _le_temoin() -> void:
	var original: ArrayMesh = BM.maillage_moitie(0)
	var m := ME.depuis(original)
	var tris := 0
	for s in original.get_surface_count():
		var a: Array = original.surface_get_arrays(s)
		tris += ((a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() if a[Mesh.ARRAY_INDEX] != null
			else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	var quads: int = m.faces.filter(func(f): return (f as PackedInt32Array).size() == 4).size()
	_egal(quads * 2, tris, "le témoin relu : TOUS ses triangles recollés en quads (%d quads)" % quads)
	_egal(_etanche(m), "", "le témoin relu : étanche et orienté")
	_vrai(_volume(m) > 0.0, "le témoin relu : volume positif (%.2f) — faces vers dehors" % _volume(m))
	# L'aller-retour : les triangles que Godot recevra couvrent la même surface — somme des aires égale.
	var aire_avant := _aire(original)
	var aire_apres := _aire(m.vers_array_mesh())
	_vrai(absf(aire_avant - aire_apres) < 1e-3, "le témoin relu puis réécrit : même aire (%.3f / %.3f)"
		% [aire_avant, aire_apres])


func _aire(mesh: ArrayMesh) -> float:
	var total := 0.0
	for s in mesh.get_surface_count():
		var a: Array = mesh.surface_get_arrays(s)
		var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var ind = a[Mesh.ARRAY_INDEX]
		var n: int = (ind as PackedInt32Array).size() if ind != null else pos.size()
		for t in range(0, n, 3):
			var p0: Vector3 = pos[ind[t] if ind != null else t]
			var p1: Vector3 = pos[ind[t + 1] if ind != null else t + 1]
			var p2: Vector3 = pos[ind[t + 2] if ind != null else t + 2]
			total += (p1 - p0).cross(p2 - p0).length() * 0.5
	return total


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
