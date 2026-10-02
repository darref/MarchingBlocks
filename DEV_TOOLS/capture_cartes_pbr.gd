extends SceneTree
## CAPTURE — les cartes PBR déduites, à l'image (2 octobre 2026). AVEC FENÊTRE (le headless ne rend rien).
##
## LANCEMENT
##   godot --path D:/MarchingBlocks --script res://DEV_TOOLS/capture_cartes_pbr.gd
##
## Deux tuiles du témoin calculé côte à côte, la même toile (des bosses CLAIRES sur un fond moyen) en projection boîte :
## à gauche sans cartes, à droite avec. Le soleil vient d'en haut à GAUCHE. Si la normale et les tangentes sont justes,
## chaque bosse claire (haute) est éclairée sur son flanc gauche et ombrée sur son flanc droit, sur le dessus comme sur
## les parois — un signe faux l'inverserait (des creux), et aucun compteur ne le dirait.
## Écrit `user://captures/cartes_pbr.png`, et une troisième vue : la base cuite depuis le relief (atlas).

const Peinture := preload("res://addons/marchingblocks_core/peinture.gd")
const Cartes := preload("res://addons/marchingblocks_core/cartes_pbr.gd")
const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const ME := preload("res://addons/marchingblocks_core/maillage_edite.gd")


func _initialize() -> void:
	_faire.call_deferred()


func _faire() -> void:
	var dossier := ProjectSettings.globalize_path("user://captures")
	DirAccess.make_dir_recursive_absolute(dossier)
	var toile := dossier.path_join("bosses.png")
	Peinture.oublier()
	Peinture.nouvelle_toile(toile, Color(0.45, 0.4, 0.35), 256)
	for y in 4:
		for x in 4:
			Peinture.tamponner(Peinture.calque_actif(toile), Vector2(32 + x * 64, 32 + y * 64), 18.0, Color(0.85, 0.8, 0.72), 0.3, 1.0)
	Peinture.composer(toile)
	var monde := Node3D.new()
	root.add_child(monde)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.12, 0.14)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.25, 0.25, 0.28)
	monde.add_child(env)
	var soleil := DirectionalLight3D.new()
	# D'en haut à gauche : la lumière va vers +x, vers le bas, un peu vers −z.
	soleil.look_at_from_position(Vector3.ZERO, Vector3(1.0, -1.2, -0.4), Vector3.UP)
	soleil.light_energy = 1.4
	monde.add_child(soleil)
	var cube := _cube()
	for i in 2:
		var m: RefCounted = cube.copie()
		var d := {"nom": "rock", "couleur": Color.WHITE, "rugosite": 0.7, "metal": 0.0, "texture": toile, "echelle": 1.0}
		if i == 1:
			d["pbr"] = Cartes.reglages({"normale": 6.0})
		m.materiaux.append(d)
		m.assigner(range(m.faces.size()), 0)
		var mi := MeshInstance3D.new()
		mi.mesh = m.vers_array_mesh()
		mi.position = Vector3(-1.4 + i * 2.8, 0, 0)
		mi.scale = Vector3(2, 2, 2)
		monde.add_child(mi)
	Peinture.suivre_les_cartes(true)
	var cam := Camera3D.new()
	cam.look_at_from_position(Vector3(0, 3.4, 4.6), Vector3(0, -0.3, 0), Vector3.UP)
	cam.fov = 50
	monde.add_child(cam)
	cam.current = true
	for k in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(dossier.path_join("cartes_pbr.png"))
	print("écrit : ", dossier.path_join("cartes_pbr.png"))
	Peinture.oublier()
	quit(0)


func _cube() -> RefCounted:
	var m: RefCounted = ME.new()
	var s := 0.5
	for p in [Vector3(-s, -s, -s), Vector3(s, -s, -s), Vector3(s, s, -s), Vector3(-s, s, -s),
			Vector3(-s, -s, s), Vector3(s, -s, s), Vector3(s, s, s), Vector3(-s, s, s)]:
		m.sommets.append(p)
	for f in [[0, 3, 2, 1], [4, 5, 6, 7], [0, 4, 7, 3], [1, 2, 6, 5], [3, 7, 6, 2], [0, 1, 5, 4]]:
		m._ajouter(PackedInt32Array(f), Color.WHITE, -1, PackedVector2Array())
	return m
