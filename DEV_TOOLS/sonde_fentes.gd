extends SceneTree
## LANCEMENT (avec fenêtre, sur la vraie carte graphique) :
##   godot --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_fentes.gd -- rendu
##   ⚠ « -- faux » : le faux travail d'artiste ; « -- chemin.glb » : un travail importé.
## SONDE — les fentes entre tuiles posées : le trancheur, la pose, ou le rendu ?
## Assemble le monde peint (forme du témoin) en espace monde, par le VRAI peintre, et compte les arêtes
## de bord : soudure exacte (bit à bit) contre soudure tolérante. Mesure l'écart des sommets orphelins.

const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const MP := preload("res://addons/marchingblocks_core/massif_peint.gd")

func _initialize() -> void:
	var chemin := ""
	for a in OS.get_cmdline_user_args():
		if a != "rendu":
			chemin = a
	if chemin == "faux":
		chemin = ProjectSettings.globalize_path("user://sonde_fentes_faux.glb")
		var FA := load("res://DEV_TOOLS/faux_artiste.gd")
		print("faux travail : ", FA.fabriquer(chemin).get("erreur", ""))
	var bilan: Dictionary = BM.librairie() if chemin == "" else BM.librairie_depuis_glb(chemin)
	var lot: MeshLibrary = bilan["lot"]
	print("lot : %d items, source %s" % [lot.get_item_list().size(), "témoin" if chemin == "" else chemin])
	var massif = MP.new()
	root.add_child(massif)
	massif.preparer()
	var cases: GridMap = massif.get_node("Cases")
	for c in BM.cases(0):
		cases.set_cell_item(c, 0)
	massif.lot = lot
	print("bilan : ", massif.reconstruire())
	var rendu: GridMap = massif.get_node("Rendu")

	var tris := PackedVector3Array()
	var tuile_de := PackedInt32Array()
	var n_tuile := 0
	for cell in rendu.get_used_cells():
		var id := rendu.get_cell_item(cell)
		var t := Transform3D(rendu.get_basis_with_orthogonal_index(rendu.get_cell_item_orientation(cell)),
			rendu.map_to_local(cell)) * lot.get_item_mesh_transform(id)
		t = Transform3D(Basis(), rendu.position) * t
		var mesh: Mesh = lot.get_item_mesh(id)
		for s in mesh.get_surface_count():
			var ar: Array = mesh.surface_get_arrays(s)
			var v: PackedVector3Array = ar[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = ar[Mesh.ARRAY_INDEX] if ar[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
			for i in idx:
				tris.append(t * v[i])
			for i in idx.size() / 3:
				tuile_de.append(n_tuile)
		n_tuile += 1
	print("tuiles posées : %d, triangles : %d" % [n_tuile, tris.size() / 3])
	if OS.get_cmdline_user_args().has("rendu"):
		await _rendre(massif, tris)
		quit(0)
		return

	tuile_de_tri = tuile_de
	var ouvertes: Array = _bords(tris, 0.0)
	# Index spatial des arêtes ouvertes par cellule de 0,25 : la recherche naïve était quadratique.
	var seaux := {}
	for i in ouvertes.size():
		var e: Array = ouvertes[i]
		var lo: Vector3i = Vector3i(((e[0] as Vector3).min(e[1]) / 0.25).floor())
		var hi: Vector3i = Vector3i(((e[0] as Vector3).max(e[1]) / 0.25).floor())
		for x in range(lo.x, hi.x + 1):
			for y in range(lo.y, hi.y + 1):
				for z in range(lo.z, hi.z + 1):
					var k := Vector3i(x, y, z)
					if not seaux.has(k):
						seaux[k] = []
					seaux[k].append(i)
	var largeurs: Array = []
	for e in ouvertes:
		var pire_e := 0.0
		for f in [0.0, 0.25, 0.5, 0.75, 1.0]:
			var q: Vector3 = (e[0] as Vector3).lerp(e[1], f)
			var meilleur := 0.25   # plafond : « au moins un quart de case »
			var c: Vector3i = Vector3i((q / 0.25).floor())
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					for dz in range(-1, 2):
						for j in seaux.get(c + Vector3i(dx, dy, dz), []):
							var o: Array = ouvertes[j]
							if o[2] == e[2]:
								continue
							var sp := Geometry3D.get_closest_point_to_segment(q, o[0], o[1])
							meilleur = minf(meilleur, q.distance_to(sp))
			pire_e = maxf(pire_e, meilleur)
		largeurs.append(pire_e)
	largeurs.sort()
	if not largeurs.is_empty():
		print("largeur de fente par arête ouverte (distance au bord d'une AUTRE tuile, plafonnée à 0,25) :")
		for q in [0.1, 0.5, 0.9]:
			print("  quantile %.1f : %s" % [q, str(largeurs[int(q * (largeurs.size() - 1))])])
		var classes := {"< 1e-5 (jonction en T)": 0, "< 0,001": 0, "< 0,01": 0, "< 0,05": 0, ">= 0,05": 0}
		for l in largeurs:
			if l < 1e-5: classes["< 1e-5 (jonction en T)"] += 1
			elif l < 0.001: classes["< 0,001"] += 1
			elif l < 0.01: classes["< 0,01"] += 1
			elif l < 0.05: classes["< 0,05"] += 1
			else: classes[">= 0,05"] += 1
		print("  ", classes, " sur ", largeurs.size())
	print("remarques de couture du trancheur : %d" % (bilan.get("remarques", []) as Array).size())
	for pas in [0.0, 1e-6, 1e-5, 1e-4, 1e-3, 1e-2]:
		var bords := _bords(tris, pas)
		var sur_coupe := 0
		for e in bords:
			if _sur_plan_de_coupe(e[0], e[1]):
				sur_coupe += 1
		print("soudure %-7s : %6d arêtes de bord, dont %6d sur un plan de coupe"
			% [str(pas), bords.size(), sur_coupe])

	# Écart des sommets posés sur un plan de coupe au plan lui-même
	var pire := 0.0
	var hors := 0
	for p in tris:
		for axe in 3:
			var f: float = p[axe] - 0.5
			var d: float = absf(f - roundf(f))
			if d < 0.01 and d > 0.0:
				hors += 1
				pire = maxf(pire, d)
	print("sommets à moins de 0,01 d'un plan de coupe SANS être dessus : %d, pire écart %s" % [hors, str(pire)])
	quit(0)


func _cle(p: Vector3, pas: float) -> Vector3:
	if pas == 0.0:
		return p
	return (p / pas).round()


var tuile_de_tri := PackedInt32Array()

func _bords(tris: PackedVector3Array, pas: float) -> Array:
	var compte := {}
	var exemple := {}
	for t in tris.size() / 3:
		for k in 3:
			var a: Vector3 = tris[3 * t + k]
			var b: Vector3 = tris[3 * t + (k + 1) % 3]
			var ka := _cle(a, pas)
			var kb := _cle(b, pas)
			if ka == kb:
				continue
			var cle: Array = [ka, kb] if str(ka) < str(kb) else [kb, ka]
			var h := str(cle)
			compte[h] = compte.get(h, 0) + 1
			exemple[h] = [a, b, tuile_de_tri[t]]
	var sortie: Array = []
	for h in compte:
		if compte[h] == 1:
			sortie.append(exemple[h])
	return sortie


func _sur_plan_de_coupe(a: Vector3, b: Vector3) -> bool:
	for axe in 3:
		var fa: float = a[axe] - 0.5
		var fb: float = b[axe] - 0.5
		if absf(fa - roundf(fa)) < 0.001 and absf(fb - roundf(fb)) < 0.001:
			return true
	return false


## Rend le GridMap puis le même monde FUSIONNÉ en un seul maillage, sur fond magenta, même caméra.
## Les pixels magenta à l'intérieur de la silhouette sont des fentes.
func _rendre(massif: Node3D, tris: PackedVector3Array) -> void:
	(massif.get_node("Cases") as Node3D).visible = false
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(1, 0, 1)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	root.add_child(env)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-48, -34, 0)
	soleil.shadow_enabled = true
	root.add_child(soleil)
	var cam := Camera3D.new()
	root.add_child(cam)
	var fusion := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in tris:
		st.add_vertex(p)
	st.generate_normals()
	fusion.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.7, 0.6)
	fusion.material_override = mat
	root.add_child(fusion)
	root.size = Vector2i(1600, 1200)
	root.msaa_3d = Viewport.MSAA_4X   # comme la vue de l'appli (`app/vue.gd`)
	var vues := [[Vector3(22, 18, 26), Vector3(6, 4, 6)], [Vector3(-10, 14, 3), Vector3(6, 4, 6)],
		[Vector3(40, 30, 40), Vector3(6, 4, 6)], [Vector3(9, 8, 14), Vector3(5, 5, 5)]]
	for i in vues.size():
		cam.look_at_from_position(vues[i][0], vues[i][1])
		for mode in ["grille", "fusion"]:
			massif.visible = mode == "grille"
			fusion.visible = mode == "fusion"
			for _k in 4:
				await process_frame
			var img := root.get_texture().get_image()
			img.save_png("user://fentes_%d_%s.png" % [i, mode])
			print("vue %d %-6s : %d pixels magenta" % [i, mode, _magenta(img)])
	print("images dans ", ProjectSettings.globalize_path("user://"))


func _magenta(img: Image) -> int:
	# Magenta ENTOURÉ de matière à gauche et à droite sur la même ligne (à 6 px) : une fente, pas le fond.
	var n := 0
	for y in img.get_height():
		for x in range(6, img.get_width() - 6):
			if _est_m(img.get_pixel(x, y)) and not _est_m(img.get_pixel(x - 6, y)) \
					and not _est_m(img.get_pixel(x + 6, y)) and not _est_m(img.get_pixel(x, maxi(y - 6, 0))) \
					and not _est_m(img.get_pixel(x, mini(y + 6, img.get_height() - 1))):
				n += 1
	return n


func _est_m(c: Color) -> bool:
	return c.r > 0.9 and c.g < 0.1 and c.b > 0.9
