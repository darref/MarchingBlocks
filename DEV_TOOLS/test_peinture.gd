extends SceneTree
## TEST — la peinture du témoin (`peinture.gd`, `MaillageEdite.uv_au_point`) : Jordan, 1er octobre 2026.
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_peinture.gd
##
## ⚠ LES ATTENDUS VIENNENT D'AILLEURS (charte §6) : les pixels d'un tampon, comptés à la main sur un disque ;
## l'UV d'un point, lu dans les tableaux que le RENDU écrit (`vers_array_mesh`), jamais recalculé par
## `uv_au_point` — c'est elle qu'on éprouve : « on peint là où le rendu lit ».

const ME := preload("res://addons/marchingblocks_core/maillage_edite.gd")
const Peinture := preload("res://addons/marchingblocks_core/peinture.gd")
const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")

var _ok := 0
var _echecs := 0
var _premier := ""
var _dossier := ""


func _initialize() -> void:
	print("=== TEST — la peinture du témoin ===\n")
	_dossier = ProjectSettings.globalize_path("user://test_peinture")
	DirAccess.make_dir_recursive_absolute(_dossier)
	Peinture.oublier()
	_le_tampon()
	_le_tampon_se_replie()
	_le_trait_est_continu()
	_l_uv_est_celle_du_rendu()
	_la_toile_est_partagee()
	_l_annulation_et_l_ecriture()
	_l_atlas_du_temoin()
	Peinture.oublier()
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


func _noire(n := 64) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	return img


## Un tampon dur, plein, de rayon 4 au centre d'un texel : exactement les texels dont le CENTRE est à moins de 4.
func _le_tampon() -> void:
	var img := _noire()
	var zone: Rect2i = Peinture.tamponner(img, Vector2(20.5, 20.5), 4.0, Color.RED, 1.0, 1.0)
	var attendus := 0
	var rouges := 0
	var faux := 0
	for y in 64:
		for x in 64:
			var dedans := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(20.5, 20.5)) < 4.0
			var rouge := img.get_pixel(x, y).r > 0.99
			attendus += int(dedans)
			rouges += int(rouge)
			faux += int(dedans != rouge)
			if rouge and not zone.has_point(Vector2i(x, y)):
				faux += 1
	_dire(faux == 0 and rouges == attendus and attendus == 45, "un tampon dur de rayon 4 : les 45 texels du disque, rien d'autre (%d rouges, %d faux)" % [rouges, faux])
	# À mi-opacité, le centre est à mi-chemin.
	var img2 := _noire()
	Peinture.tamponner(img2, Vector2(20.5, 20.5), 4.0, Color.WHITE, 1.0, 0.5)
	_dire(absf(img2.get_pixel(20, 20).r - 0.5) < 0.01, "à mi-opacité, le centre est à mi-chemin (%.3f)" % img2.get_pixel(20, 20).r)
	# Doux : plein jusqu'à la dureté, puis décroissant jusqu'au bord.
	var img3 := _noire()
	Peinture.tamponner(img3, Vector2(20.5, 20.5), 8.0, Color.WHITE, 0.25, 1.0)
	var c0: float = img3.get_pixel(20, 20).r
	var c1: float = img3.get_pixel(20 + 4, 20).r
	var c2: float = img3.get_pixel(20 + 6, 20).r
	var c3: float = img3.get_pixel(20 + 9, 20).r
	_dire(c0 > 0.99 and c1 < c0 and c2 < c1 and c2 > 0.0 and c3 == 0.0, "un tampon doux décroît du centre au bord (%.2f %.2f %.2f %.2f)" % [c0, c1, c2, c3])


## Comme la texture se répète, un tampon qui dépasse un bord reparaît de l'autre côté.
func _le_tampon_se_replie() -> void:
	var img := _noire()
	var zone: Rect2i = Peinture.tamponner(img, Vector2(1.0, 1.0), 3.0, Color.RED, 1.0, 1.0)
	_dire(img.get_pixel(63, 63).r > 0.99 and img.get_pixel(0, 0).r > 0.99 and img.get_pixel(62, 0).r > 0.99,
		"un tampon au coin reparaît aux trois autres coins")
	_dire(zone == Rect2i(0, 0, 64, 64), "et sa zone couvre l'image entière sur les deux axes (%s)" % zone)
	# Le même UV à une période près tombe sur le même texel.
	_dire(Peinture.vers_pixel(img, Vector2(0.25, 0.75)) == Peinture.vers_pixel(img, Vector2(3.25, -1.25)),
		"un UV et le même à une période près tombent sur le même texel")


## Un trait sans trou : chaque texel de la ligne est peint, même tiré vite (deux points éloignés).
func _le_trait_est_continu() -> void:
	var img := _noire()
	Peinture.trait_(img, Vector2(8.5, 30.5), Vector2(56.5, 30.5), 2.0, Color.RED, 1.0, 1.0)
	var trous := 0
	for x in range(8, 57):
		if img.get_pixel(x, 30).r < 0.99:
			trous += 1
	_dire(trous == 0, "un trait de 48 texels n'a aucun trou (%d)" % trous)
	_dire(img.get_pixel(30, 35).r < 0.01, "et rien hors de sa largeur")


## L'UV d'un point est celle que le RENDU écrit : à chaque coin de chaque triangle des tableaux de
## `vers_array_mesh`, et au centre d'un triangle (la moyenne de ses trois coins) — en Boîte, en projection plane,
## et en UV dépliés.
func _l_uv_est_celle_du_rendu() -> void:
	for mode in ["boite", "dessus", "uv"]:
		var m: RefCounted = _cube()
		m.materiaux.append({"nom": "Rock", "couleur": Color.WHITE, "rugosite": 1.0, "metal": 0.0, "texture": "",
			"echelle": 0.5, "projection": mode})
		m.assigner(range(m.faces.size()), 0)
		if mode == "uv":
			m.deplier()
		var a: Array = m.vers_array_mesh().surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
		var ecarts := 0
		var vus := 0
		for i in range(0, v.size(), 3):
			var c: Vector3 = (v[i] + v[i + 1] + v[i + 2]) / 3.0
			var uc: Vector2 = (uvs[i] + uvs[i + 1] + uvs[i + 2]) / 3.0
			var f := _face_qui_porte(m, c)
			if f < 0:
				continue
			vus += 1
			if m.uv_au_point(f, c).distance_to(uc) > 1e-4:
				ecarts += 1
		_dire(vus == v.size() / 3 and ecarts == 0, "projection %s : au centre de chaque triangle, l'UV est celle du rendu (%d écarts sur %d)" % [mode, ecarts, vus])
	var nue: RefCounted = _cube()
	_dire(nue.uv_au_point(0, Vector3(0, 0.5, 0.5)) == Vector2.INF, "une face sans matériau n'a pas d'UV (la légende ne se peint pas)")


func _face_qui_porte(m: RefCounted, p: Vector3) -> int:
	for f in m.faces.size():
		var face: PackedInt32Array = m.faces[f]
		var n: Vector3 = m.normale(f)
		if absf(n.dot(p - m.sommets[face[0]])) < 1e-5:
			return f
	return -1


## Deux tuiles qui portent le même matériau lisent la MÊME texture : un tampon la change pour les deux.
func _la_toile_est_partagee() -> void:
	var chemin := _dossier.path_join("partagee.png")
	Peinture.nouvelle_toile(chemin, Color(0.2, 0.4, 0.6), 64)
	var mats: Array = [{"nom": "Paint", "couleur": Color.WHITE, "rugosite": 1.0, "metal": 0.0, "texture": chemin,
		"echelle": 1.0}]
	var a: RefCounted = _cube()
	var b: RefCounted = _cube()
	a.materiaux = mats
	b.materiaux = mats
	var ta: Texture2D = a.materiau_godot(0).albedo_texture
	var tb: Texture2D = b.materiau_godot(0).albedo_texture
	_dire(ta != null and is_same(ta, tb), "deux tuiles du même matériau partagent UNE texture")
	var t: Dictionary = Peinture.toile(chemin)
	Peinture.tamponner(t["image"], Vector2(10, 10), 3.0, Color.RED, 1.0, 1.0)
	Peinture.montrer(chemin)
	# ⚠ En headless, le rendu factice ne garde pas `ImageTexture.update` (mesuré : avec fenêtre, si). On vérifie
	# donc que la texture des matériaux EST celle de la toile peinte — l'affichage se juge à l'image.
	_dire(is_same(ta, t["texture"]) and (t["image"] as Image).get_pixel(10, 10).r > 0.99,
		"la texture des matériaux est celle de la toile qu'on peint (un tampon y va, sans rien redessiner)")


## Un trait se défait par sa région ; une toile peinte s'écrit, et se relit telle quelle.
func _l_annulation_et_l_ecriture() -> void:
	var chemin := _dossier.path_join("annule.png")
	var t: Dictionary = Peinture.nouvelle_toile(chemin, Color.BLACK, 64)
	var img: Image = t["image"]
	var avant := img.duplicate()
	var zone: Rect2i = Peinture.trait_(img, Vector2(10, 10), Vector2(40, 20), 3.0, Color.GREEN, 0.5, 1.0)
	var apres_region := img.get_region(zone)
	Peinture.poser_region(chemin, (avant as Image).get_region(zone), zone.position)
	_dire(img.get_data() == (avant as Image).get_data(), "remettre la région d'avant défait le trait, au bit près")
	Peinture.poser_region(chemin, apres_region, zone.position)
	_dire(img.get_pixel(25, 15).g > 0.9, "remettre celle d'après le refait")
	_dire(Peinture.a_ecrire(), "la toile peinte est à écrire")
	var ecrits: Array = Peinture.enregistrer()
	_dire(ecrits.has(chemin) and not Peinture.a_ecrire(), "elle s'écrit, et plus rien n'attend")
	var relue := Image.load_from_file(chemin)
	relue.convert(Image.FORMAT_RGBA8)
	_dire(relue.get_data() == img.get_data(), "relue du disque, c'est la même image")


## L'ATLAS : les tuiles du témoin dépliées ENSEMBLE ne se recouvrent pas — attendu pixellisé à part (chaque triangle
## d'UV rasterisé sur une grille de 512, un pixel revendiqué par deux tuiles différentes est un recouvrement) ; tout
## est dans [0,1] ; une seule densité (aire UV / aire 3D égale d'une face à l'autre). Et le contrôle : déplier tuile
## par tuile (l'ancienne route) les fait se recouvrir — sinon cette garde ne garderait rien.
func _l_atlas_du_temoin() -> void:
	var t: RefCounted = TL.depuis_le_temoin_calcule()
	var temoin_seul: RefCounted = t.copie()
	for c in temoin_seul.tuiles:
		temoin_seul.tuiles[c].deplier()
	var recouvert_seul := _recouvrements(temoin_seul)
	var r: Dictionary = t.deplier_en_atlas()
	_dire((r["tuiles"] as Array).size() == t.tuiles.size() and int(r["ilots"]) > t.tuiles.size(),
		"l'atlas prend les %d tuiles (%d îlots)" % [(r["tuiles"] as Array).size(), int(r["ilots"])])
	var hors := 0
	var densites: Array = []
	for c in t.tuiles:
		var m: RefCounted = t.tuiles[c]
		for f in m.faces.size():
			var u: PackedVector2Array = m.uv(f)
			for q in u:
				if q.x < -1e-6 or q.y < -1e-6 or q.x > 1.0 + 1e-6 or q.y > 1.0 + 1e-6:
					hors += 1
			var a3 := 0.0
			var a2 := 0.0
			for tri in m.trianguler(f):
				var p0: Vector3 = m.sommets[m.faces[f][tri[0]]]
				a3 += (m.sommets[m.faces[f][tri[1]]] - p0).cross(m.sommets[m.faces[f][tri[2]]] - p0).length() * 0.5
				a2 += absf((u[tri[1]] - u[tri[0]]).cross(u[tri[2]] - u[tri[0]])) * 0.5
			if a3 > 1e-4:
				densites.append(a2 / a3)
	densites.sort()
	_dire(hors == 0, "tout l'atlas est dans [0,1] (%d coins dehors)" % hors)
	_dire(densites[-1] / densites[0] < 1.02, "une seule densité de texels (rapport %.3f entre la plus forte et la plus faible)" % (densites[-1] / densites[0]))
	var recouvert := _recouvrements(t)
	_dire(recouvert == 0, "aucun texel n'appartient à deux tuiles (%d)" % recouvert)
	_dire(recouvert_seul > 1000, "contrôle : dépliées tuile par tuile, elles se recouvrent (%d texels)" % recouvert_seul)


func _recouvrements(t: RefCounted) -> int:
	const N := 512
	var proprio := {}
	var doubles := 0
	for c in t.tuiles:
		var m: RefCounted = t.tuiles[c]
		for f in m.faces.size():
			var u: PackedVector2Array = m.uv(f)
			if u.is_empty():
				continue
			for tri in m.trianguler(f):
				var a: Vector2 = u[tri[0]] * N
				var b: Vector2 = u[tri[1]] * N
				var d: Vector2 = u[tri[2]] * N
				var lo := a.min(b).min(d).floor()
				var hi := a.max(b).max(d).ceil()
				for y in range(int(lo.y), int(hi.y)):
					for x in range(int(lo.x), int(hi.x)):
						var p := Vector2(x + 0.5, y + 0.5)
						if not Geometry2D.point_is_inside_triangle(p, a, b, d):
							continue
						var k := Vector2i(x, y)
						if proprio.has(k) and proprio[k] != c:
							doubles += 1
						proprio[k] = c
	return doubles


func _cube() -> RefCounted:
	var m: RefCounted = ME.new()
	for i in 8:
		m.sommets.append(Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1))
	for f in [[0, 4, 6, 2], [1, 3, 7, 5], [0, 1, 5, 4], [2, 6, 7, 3], [0, 2, 3, 1], [4, 5, 7, 6]]:
		m.faces.append(PackedInt32Array(f))
		m.teintes.append(Color.WHITE)
	return m
