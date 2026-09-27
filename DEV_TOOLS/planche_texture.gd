extends SceneTree
##
## LA PLANCHE DE LA TEXTURE — l'éclair vert vient-il du PLACAGE ou de la GÉOMÉTRIE ?
##
## LANCEMENT — ⚠ AVEC FENÊTRE (elle rend une image ; le headless ne rend RIEN) :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/planche_texture.gd \
##       -- --fichier=C:/chemin/vers/le.glb --sortie=D:/MarchingBlocks/ART/texture.png
##
## ── POURQUOI ELLE EXISTE ────────────────────────────────────────────────────────────────────────────
##
## `planche_motifs` a montré un plateau 6×6 couvert de **trente-six éclairs verts identiques** sur du
## noir, là où le témoin rend une dalle uniforme. J'en ai tiré que l'éclair était la **géométrie** de la
## tuile et non un motif de la texture — parce qu'un fragment UV de 0,008 ne peut pas contenir une forme
## dessinée.
##
## ⚠ **C'EST UNE DÉDUCTION, PAS UNE MESURE, et j'en ai servi trois fausses cette nuit.** Cette planche
## l'éprouve par le seul contrôle qui tranche : **la même tuile rendue en BLANC UNI, sans texture**.
##
##   • l'éclair SUBSISTE  → c'est la géométrie sculptée, le pipeline la reproduit fidèlement ;
##   • l'éclair DISPARAÎT → c'est la texture, et ma déduction était fausse.
##
## ── ET LES CHIFFRES QUI DÉCIDENT DU REMÈDE ──────────────────────────────────────────────────────────
##
## ⚠ **« 0,008 de l'atlas » ne veut rien dire sans la taille de l'atlas.** Sur 4096² c'est 32 pixels de
## côté — la tuile a de la matière. Sur 512² c'est 4 pixels, et aucun placage ne sauvera ça. On imprime
## donc la taille réelle, le nombre de pixels lus par chaque tuile, et l'ÉCART de couleur dans ce
## carré : un écart nul veut dire que la tuile lit un aplat, quelle que soit sa taille.
##
## ⚠ **ON NE MODIFIE PAS LE MATÉRIAU DES MAILLAGES** : il est partagé par tout le lot. On surcharge sur
## l'instance, ce qui laisse la tuile intacte.

const BM := preload("res://addons/marching_blocks_plugin_godot/blocs_maitres.gd")

const CASE := Vector2i(340, 340)
const FOND := Color("#101216")
const OR := Color("#ebbb69")

const TUILES := [
	{"nom": "mb_plaque_b4h0", "quoi": "le SOL"},
	{"nom": "mb_plaque_b2h2", "quoi": "le MUR"},
]

var _fichier := ""
var _sortie := "texture.png"
var _vues: Array = []
var _images := 0
var _colonnes: Array = []


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--fichier="):
			_fichier = option.substr("--fichier=".length())
		if option.begins_with("--sortie="):
			_sortie = option.substr("--sortie=".length())
	if _fichier == "" or not FileAccess.file_exists(_fichier):
		print("il faut --fichier=<un .glb sculpté existant>")
		quit(1)
		return

	var temoin: MeshLibrary = (BM.librairie()["lot"] as MeshLibrary)
	var bilan: Dictionary = BM.librairie_depuis_glb(_fichier)
	if not (bilan["absents"] as Array).is_empty():
		print("⚠⚠ le bloc n'a PAS été relu du disque — cette planche ne mesurerait rien.")
		quit(1)
		return
	var sculpte: MeshLibrary = bilan["lot"]

	_dire_la_texture(sculpte)

	_colonnes = [
		{"quoi": "TÉMOIN", "lot": temoin, "blanc": false},
		{"quoi": "SCULPT, sa matière", "lot": sculpte, "blanc": false},
		{"quoi": "SCULPT, BLANC UNI", "lot": sculpte, "blanc": true},
	]
	for t in TUILES:
		for c in _colonnes:
			_vues.append(_faire_vue(c["lot"], t["nom"], bool(c["blanc"])))
	process_frame.connect(_image)


## Ce que la texture contient vraiment, là où chaque tuile la lit.
func _dire_la_texture(lot: MeshLibrary) -> void:
	print("=== CE QUE LA TEXTURE CONTIENT, LÀ OÙ CHAQUE TUILE LA LIT ===\n")
	var id0: int = lot.find_item_by_name("mb_plaque_b4h0")
	var m: Material = (lot.get_item_mesh(id0) as ArrayMesh).surface_get_material(0) if id0 >= 0 else null
	var std := m as StandardMaterial3D
	if std == null or std.albedo_texture == null:
		print("   ⚠ aucune texture d'albédo : rien à mesurer ici.\n")
		return
	var image: Image = std.albedo_texture.get_image()
	if image == null:
		# ⚠ ON LE DIT PLUTÔT QUE DE RENDRE ZÉRO : une texture compressée sur le GPU ne se relit pas
		# toujours côté CPU, et un « 0 pixel » serait lu comme un défaut de l'artiste.
		print("   ⚠ la texture existe mais son image n'est pas lisible côté CPU (compressée ?)")
		print("      taille déclarée : %d × %d\n"
			% [std.albedo_texture.get_width(), std.albedo_texture.get_height()])
		return
	var l: int = image.get_width()
	var h: int = image.get_height()
	print("   atlas : %d × %d pixels, format %d\n" % [l, h, image.get_format()])

	for t in TUILES:
		var id: int = lot.find_item_by_name(t["nom"])
		if id < 0:
			continue
		var mesh: ArrayMesh = lot.get_item_mesh(id) as ArrayMesh
		var arrays: Array = mesh.surface_get_arrays(0)
		if arrays[Mesh.ARRAY_TEX_UV] == null:
			continue
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var mini := uv[0]
		var maxi := uv[0]
		for p in uv:
			mini = Vector2(minf(mini.x, p.x), minf(mini.y, p.y))
			maxi = Vector2(maxf(maxi.x, p.x), maxf(maxi.y, p.y))
		var x0: int = clampi(int(mini.x * l), 0, l - 1)
		var y0: int = clampi(int(mini.y * h), 0, h - 1)
		var x1: int = clampi(int(ceilf(maxi.x * float(l))), x0 + 1, l)
		var y1: int = clampi(int(ceilf(maxi.y * float(h))), y0 + 1, h)

		var somme := Color(0, 0, 0, 0)
		var le_plus_clair := 0.0
		var le_plus_sombre := 2.0
		var n := 0
		for x in range(x0, x1):
			for y in range(y0, y1):
				var c: Color = image.get_pixel(x, y)
				somme += c
				var lum: float = (c.r + c.g + c.b) / 3.0
				le_plus_clair = maxf(le_plus_clair, lum)
				le_plus_sombre = minf(le_plus_sombre, lum)
				n += 1
		var moy: Color = somme / float(maxi_de(n, 1))
		print("   %-22s lit %d × %d = %d pixel(s)" % [t["nom"], x1 - x0, y1 - y0, n])
		print("      couleur moyenne %s  ·  écart de luminosité %.3f %s"
			% [str(moy).left(34), le_plus_clair - le_plus_sombre,
				"⚠ APLAT : la tuile lit une couleur unie" if le_plus_clair - le_plus_sombre < 0.05
					else ""])
	print("")


func maxi_de(a: int, b: int) -> int:
	return a if a > b else b


func _image() -> void:
	_images += 1
	if _images < 5:
		return
	var n: int = _colonnes.size()
	var premiere: Image = _vues[0].get_texture().get_image()
	var planche := Image.create(CASE.x * n, CASE.y * TUILES.size(), false, premiere.get_format())
	planche.fill(FOND)
	for i in _vues.size():
		var img: Image = _vues[i].get_texture().get_image()
		planche.blit_rect(img, Rect2i(Vector2i.ZERO, CASE),
			Vector2i((i % n) * CASE.x, (i / n) * CASE.y))
	for y in planche.get_height():
		planche.set_pixel(CASE.x, y, OR)
		planche.set_pixel(CASE.x - 1, y, OR)

	var err := planche.save_png(_sortie)
	print("planche %d×%d → %s (%s)"
		% [planche.get_width(), planche.get_height(), _sortie,
			"écrite" if err == OK else "ERREUR %d" % err])
	print("   colonnes : %s" % ", ".join(PackedStringArray(_colonnes.map(func(c): return c["quoi"]))))
	print("   lignes   : %s" % ", ".join(PackedStringArray(TUILES.map(func(t): return t["quoi"]))))
	print("\n⚠ Colonne 3 : si la forme d'éclair SUBSISTE en blanc uni, c'est la GÉOMÉTRIE.")
	print("   Si elle disparaît et qu'il reste une dalle pleine, c'est la TEXTURE.")
	quit(0 if err == OK else 1)


func _faire_vue(lot: MeshLibrary, nom: String, blanc: bool) -> SubViewport:
	var vue := SubViewport.new()
	vue.size = CASE
	vue.own_world_3d = true
	vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vue)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = FOND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8892a4")
	env.ambient_light_energy = 0.8
	var monde := WorldEnvironment.new()
	monde.environment = env
	vue.add_child(monde)

	var lumiere := DirectionalLight3D.new()
	lumiere.rotation_degrees = Vector3(-42, -38, 0)
	lumiere.light_energy = 1.2
	vue.add_child(lumiere)

	var id: int = lot.find_item_by_name(nom)
	if id >= 0:
		var mesh: Mesh = lot.get_item_mesh(id)
		if mesh != null:
			var instance := MeshInstance3D.new()
			instance.mesh = mesh
			if blanc:
				# ⚠ BLANC, ÉCLAIRÉ, SANS TEXTURE NI COULEUR DE SOMMET : il ne doit RESTER que la forme.
				var uni := StandardMaterial3D.new()
				uni.albedo_color = Color(0.85, 0.85, 0.85)
				uni.vertex_color_use_as_albedo = false
				uni.cull_mode = BaseMaterial3D.CULL_BACK
				instance.set_surface_override_material(0, uni)
			vue.add_child(instance)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.9
	camera.position = Vector3(1.0, 0.75, 1.0).normalized() * 10.0
	vue.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3.ZERO, Vector3.UP)
	return vue
