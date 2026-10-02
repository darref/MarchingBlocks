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
	_l_empreinte_est_le_bord_du_tampon()
	_la_gomme_et_les_calques()
	_les_calques_s_ecrivent()
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
	var calque: Image = Peinture.calque_actif(chemin)
	var avant := img.duplicate()
	var avant_calque := calque.duplicate()
	var zone: Rect2i = Peinture.trait_(calque, Vector2(10, 10), Vector2(40, 20), 3.0, Color.GREEN, 0.5, 1.0)
	Peinture.composer(chemin, zone)
	var apres_region := calque.get_region(zone)
	Peinture.poser_region(chemin, (avant_calque as Image).get_region(zone), zone.position, calque)
	_dire(img.get_data() == (avant as Image).get_data(), "remettre la région d'avant défait le trait, au bit près")
	Peinture.poser_region(chemin, apres_region, zone.position, calque)
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


## LE CURSEUR (Jordan, 1er octobre 2026 : « la taille du pinceau ») : l'empreinte que montre le curseur est le BORD
## de ce que le tampon peint. Attendus d'ailleurs : des rayons calculés à la main depuis des UV posés à la main
## (un îlot étiré 3 : 1) et depuis la formule de la Boîte ; puis ce que `tamponner` peint VRAIMENT — juste en
## dedans de chaque point de l'empreinte, le texel est peint ; juste au-dehors, il ne l'est pas.
func _l_empreinte_est_le_bord_du_tampon() -> void:
	var m: RefCounted = _cube()
	m.materiaux.append({"nom": "Rock", "couleur": Color.WHITE, "rugosite": 1.0, "metal": 0.0, "texture": "",
		"echelle": 1.0, "projection": "uv"})
	m.assigner(range(m.faces.size()), 0)
	# La face du dessus (y = 1), sommets 2 6 7 3 : u = 0,1 + 0,75·x, v = 0,1 + 0,25·z — étirée 3 : 1.
	while m.uvs.size() < m.faces.size():
		m.uvs.append(PackedVector2Array())
	m.uvs[3] = PackedVector2Array([Vector2(0.1, 0.1), Vector2(0.1, 0.35), Vector2(0.85, 0.35), Vector2(0.85, 0.1)])
	var p := Vector3(0.5, 1.0, 0.5)
	var taille := Vector2(256, 256)
	var pts: PackedVector3Array = Peinture.empreinte(m, 3, p, 20.0, taille)
	var ex := 0.0
	var ez := 0.0
	var hors_plan := 0
	for q in pts:
		ex = maxf(ex, absf(q.x - p.x))
		ez = maxf(ez, absf(q.z - p.z))
		if absf(q.y - 1.0) > 1e-5:
			hors_plan += 1
	# À la main : 1 case = 0,75 × 256 = 192 texels en x, 0,25 × 256 = 64 en z ; 20 texels = 0,1042 et 0,3125.
	_dire(pts.size() == 48 and hors_plan == 0, "l'empreinte : 48 points, tous dans le plan de la face (%d hors)" % hors_plan)
	_dire(absf(ex - 20.0 / 192.0) < 0.002 and absf(ez - 20.0 / 64.0) < 0.002,
		"îlot étiré 3 : 1 — l'empreinte est une ELLIPSE de demi-axes 0,104 × 0,3125 (lu %.4f × %.4f)" % [ex, ez])
	# Ce que le tampon peint : dur, plein, au point visé.
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	var uvp: Vector2 = Vector2(0.1 + 0.75 * p.x, 0.1 + 0.25 * p.z)
	Peinture.tamponner(img, uvp * taille, 20.0, Color.WHITE, 1.0, 1.0)
	var mal := 0
	for q in pts:
		for f in [[0.9, true], [1.1, false]]:
			var r: Vector3 = p + (q - p) * float(f[0])
			var px := Vector2(0.1 + 0.75 * r.x, 0.1 + 0.25 * r.z) * taille
			if (img.get_pixelv(Vector2i(px.floor())).r > 0.5) != bool(f[1]):
				mal += 1
	_dire(mal == 0, "à 90 %% de l'empreinte le tampon a peint, à 110 %% il n'a rien peint (%d points faux sur %d)" % [mal, pts.size() * 2])
	# La Boîte, sur une paroi (x = 0), répétition 0,5 case : 2 répétitions par case, 512 texels ; 20 texels = 0,039.
	m.materiaux[0]["projection"] = "boite"
	m.materiaux[0]["echelle"] = 0.5
	var pb: PackedVector3Array = Peinture.empreinte(m, 0, Vector3(0.0, 0.5, 0.5), 20.0, taille)
	var rmin := INF
	var rmax := 0.0
	for q in pb:
		var d: float = q.distance_to(Vector3(0.0, 0.5, 0.5))
		rmin = minf(rmin, d)
		rmax = maxf(rmax, d)
	_dire(absf(rmin - 20.0 / 512.0) < 0.0005 and absf(rmax - 20.0 / 512.0) < 0.0005,
		"Boîte, répétition 0,5 : un CERCLE de 20 / 512 case (lu %.4f … %.4f)" % [rmin, rmax])
	var nue: RefCounted = _cube()
	_dire(Peinture.empreinte(nue, 3, p, 20.0, taille).is_empty(), "une face de la légende n'a pas d'empreinte")


## LA GOMME ET LES CALQUES (Jordan, 2 octobre 2026). Attendus calculés À LA MAIN : un tampon DUR et PLEIN pose la
## couleur pure ; la composition d'un calque à opacité o par-dessus un fond opaque est lerp(fond, couleur, o).
func _la_gomme_et_les_calques() -> void:
	var chemin := _dossier.path_join("calques.png")
	var bleu := Color(0.0, 0.0, 1.0)
	Peinture.nouvelle_toile(chemin, bleu, 32)
	var compo: Image = Peinture.toile(chemin)["image"]
	var p := Vector2(16, 16)
	var px := func() -> Color: return compo.get_pixel(16, 16)
	# Un calque neuf est TRANSPARENT, posé au-dessus, et devient l'actif.
	var r: int = Peinture.nouveau_calque(chemin, "Red")
	var haut: Image = Peinture.calque_actif(chemin)
	_dire(r == 1 and int(Peinture.toile(chemin)["actif"]) == 1 and haut.get_pixel(16, 16).a == 0.0
		and _egal(px.call(), bleu), "un calque neuf est transparent, au-dessus, actif — la toile ne change pas")
	# Peindre sur un calque transparent pose la couleur PURE (pas assombrie par le noir transparent).
	Peinture.composer(chemin, Peinture.tamponner(haut, p, 3.0, Color.RED, 1.0, 1.0))
	_dire(_egal(haut.get_pixel(16, 16), Color.RED) and _egal(px.call(), Color.RED),
		"peint sur le calque du haut : le pixel est rouge pur, la toile aussi")
	var mi := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	mi.fill(Color(0, 0, 0, 0))
	Peinture.tamponner(mi, Vector2(2, 2), 3.0, Color.RED, 1.0, 0.5)
	_dire(_egal(mi.get_pixel(2, 2), Color(1, 0, 0, 0.5)), "à mi-opacité sur du transparent : rouge pur, alpha 0,5 (%s)" % mi.get_pixel(2, 2))
	# L'opacité du calque : lerp(bleu, rouge, 0,5).
	Peinture.regler_calque(chemin, 1, "opacite", 0.5)
	_dire(_egal(px.call(), Color(0.5, 0.0, 0.5)), "calque à 50 %% : la toile est le mélange (%s)" % px.call())
	Peinture.regler_calque(chemin, 1, "opacite", 1.0)
	Peinture.regler_calque(chemin, 1, "visible", false)
	_dire(_egal(px.call(), bleu), "calque caché : la toile redevient bleue")
	Peinture.regler_calque(chemin, 1, "visible", true)
	# La gomme sur le calque du haut : il redevient transparent, le bleu revient.
	Peinture.composer(chemin, Peinture.tamponner(haut, p, 3.0, Color.WHITE, 1.0, 1.0, true))
	_dire(haut.get_pixel(16, 16).a == 0.0 and _egal(px.call(), bleu), "la gomme sur le calque du haut fait revenir le bleu")
	# Sur le calque du BAS, la gomme fait revenir le FOND (la toile d'avant la peinture), pas du transparent.
	Peinture.choisir_calque(chemin, 0)
	var bas: Image = Peinture.calque_actif(chemin)
	Peinture.composer(chemin, Peinture.tamponner(bas, p, 3.0, Color.GREEN, 1.0, 1.0))
	_dire(_egal(px.call(), Color.GREEN), "peint en vert sur le calque du bas")
	Peinture.composer(chemin, Peinture.tamponner(bas, p, 3.0, Color.WHITE, 1.0, 1.0, true))
	_dire(_egal(px.call(), bleu) and compo.get_pixel(16, 16).a == 1.0,
		"la gomme sur le calque du bas rend le fond bleu, opaque (%s)" % px.call())
	# L'ordre : vert sur un calque, rouge sur l'autre — le plus HAUT l'emporte, et déplacer l'inverse.
	Peinture.composer(chemin, Peinture.tamponner(haut, p, 3.0, Color.RED, 1.0, 1.0))
	var vert: int = Peinture.nouveau_calque(chemin, "Green")
	Peinture.composer(chemin, Peinture.tamponner(Peinture.calque_actif(chemin), p, 3.0, Color.GREEN, 1.0, 1.0))
	_dire(vert == 1 and _egal(px.call(), Color.RED), "le calque neuf s'insère au-dessus de l'actif (le bas), donc SOUS Red : %d" % vert)
	var noms := func() -> Array:
		var n: Array = []
		for c in Peinture.toile(chemin)["calques"]:
			n.append(c["nom"])
		return n
	_dire(noms.call() == ["Base", "Green", "Red"] and _egal(px.call(), Color.RED), "Base, Green, Red : le rouge, en haut, l'emporte")
	Peinture.deplacer_calque(chemin, 1, 1)
	_dire(noms.call() == ["Base", "Red", "Green"] and _egal(px.call(), Color.GREEN)
		and int(Peinture.toile(chemin)["actif"]) == 2, "Green monté : il l'emporte, et reste l'actif")
	# L'état de la pile, pour l'annulation : supprimer puis rendre — le MÊME calque revient.
	var avant: Dictionary = Peinture.etat(chemin)
	var green: Image = Peinture.calque_actif(chemin)
	_dire(Peinture.supprimer_calque(chemin, 2) and noms.call() == ["Base", "Red"] and _egal(px.call(), Color.RED),
		"supprimer Green : le rouge revient")
	Peinture.poser_etat(chemin, avant)
	_dire(noms.call() == ["Base", "Red", "Green"] and is_same(Peinture.calque_actif(chemin), green)
		and _egal(px.call(), Color.GREEN), "l'état d'avant rend le même calque, au même rang, actif")
	Peinture.supprimer_calque(chemin, 2)
	Peinture.supprimer_calque(chemin, 1)
	_dire(not Peinture.supprimer_calque(chemin, 0) and noms.call() == ["Base"], "le dernier calque ne se supprime pas")


## La pile s'écrit à côté de l'image et se relit telle quelle ; une image retouchée AILLEURS met la pile de côté.
func _les_calques_s_ecrivent() -> void:
	var chemin := _dossier.path_join("pile.png")
	# ⚠ Le dossier de test SURVIT d'un lancement à l'autre : une pile écrite la fois d'avant serait relue, et
	# « la pile n'est pas écrite » passerait pour juste (mutation d'abord muette).
	var vieux := Peinture.dossier_des_calques(chemin)
	for nom in DirAccess.get_files_at(vieux):
		DirAccess.remove_absolute(vieux.path_join(nom))
	DirAccess.remove_absolute(vieux)
	Peinture.nouvelle_toile(chemin, Color.BLUE, 16)
	Peinture.nouveau_calque(chemin, "Red")
	Peinture.composer(chemin, Peinture.tamponner(Peinture.calque_actif(chemin), Vector2(8, 8), 2.0, Color.RED, 1.0, 1.0))
	Peinture.regler_calque(chemin, 1, "opacite", 0.5)
	Peinture.choisir_calque(chemin, 0)
	var ecrits: Array = Peinture.enregistrer()
	var relue := Image.load_from_file(chemin)
	relue.convert(Image.FORMAT_RGBA8)
	_dire(ecrits.has(chemin) and _egal(relue.get_pixel(8, 8), Color(0.5, 0, 0.5)),
		"l'image écrite est la COMPOSITION (%s)" % relue.get_pixel(8, 8))
	Peinture.oublier()
	var t: Dictionary = Peinture.toile(chemin)
	var cal: Array = t.get("calques", [])
	_dire(cal.size() == 2 and cal[1]["nom"] == "Red" and absf(float(cal[1]["opacite"]) - 0.5) < 1e-6 and int(t["actif"]) == 0
		and _egal((cal[1]["image"] as Image).get_pixel(8, 8), Color.RED) and not t["calques_ecartes"],
		"relue : deux calques, Red à 50 %, le bas actif, ses pixels")
	# Le fond survit : la gomme sur le bas, après relecture, rend le bleu.
	Peinture.composer(chemin, Peinture.tamponner(Peinture.calque_actif(chemin), Vector2(2, 2), 1.5, Color.WHITE, 1.0, 1.0, true))
	_dire(_egal((t["image"] as Image).get_pixel(2, 2), Color.BLUE), "le fond est relu : la gomme du bas rend le bleu")
	Peinture.enregistrer()
	# Une retouche AILLEURS (un autre logiciel réécrit l'image) : la pile ne correspond plus.
	var autre := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	autre.fill(Color.YELLOW)
	autre.save_png(chemin)
	Peinture.oublier()
	t = Peinture.toile(chemin)
	_dire(t["calques_ecartes"] and (t["calques"] as Array).size() == 1 and _egal((t["image"] as Image).get_pixel(8, 8), Color.YELLOW),
		"image retouchée ailleurs : ses calques sont mis de côté, elle devient l'unique calque, et c'est dit")
	# Une image sans pile (d'avant les calques) : un seul calque, « Base ».
	var nue := _dossier.path_join("nue.png")
	autre.save_png(nue)
	t = Peinture.toile(nue)
	_dire((t["calques"] as Array).size() == 1 and t["calques"][0]["nom"] == "Base" and not t["calques_ecartes"],
		"une image sans pile : un calque « Base », rien de mis de côté")


func _egal(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01 and absf(a.a - b.a) < 0.01


func _cube() -> RefCounted:
	var m: RefCounted = ME.new()
	for i in 8:
		m.sommets.append(Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1))
	for f in [[0, 4, 6, 2], [1, 3, 7, 5], [0, 1, 5, 4], [2, 6, 7, 3], [0, 2, 3, 1], [4, 5, 7, 6]]:
		m.faces.append(PackedInt32Array(f))
		m.teintes.append(Color.WHITE)
	return m
