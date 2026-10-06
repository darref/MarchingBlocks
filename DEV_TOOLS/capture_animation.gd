extends SceneTree
## CAPTURE — le shader des textures animées, AVEC FENÊTRE (le headless ne compile pas les shaders) : 6 octobre 2026.
##
## LANCEMENT (avec fenêtre)
##   godot --path D:/MarchingBlocks --script res://DEV_TOOLS/capture_animation.gd
##
## Un plan face à la caméra, éclairé à plat, porte un matériau dont la couleur de base est animée par quatre images
## UNIES (rouge, vert, bleu, jaune). On FORCE l'image (`mb_image`) et on lit le pixel du centre : il doit prendre la
## couleur de l'image ; puis on joue (temps qui avance) et l'image doit changer ; puis le défilement d'une image à deux
## moitiés doit déplacer la frontière. Toute ligne « SHADER ERROR » dans la sortie est un échec (la lire).
## Les photos vont dans user://capture_animation/.

const Anim := preload("res://addons/marchingblocks_core/animation_materiau.gd")

var _ok := 0
var _echecs := 0
var _cam: Camera3D
var _plan: MeshInstance3D
var _dossier := ""


func _initialize() -> void:
	_dossier = ProjectSettings.globalize_path("user://capture_animation")
	DirAccess.make_dir_recursive_absolute(_dossier)
	Anim.oublier()
	root.size = Vector2i(320, 320)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.BLACK
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 1.0
	env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	root.add_child(env)
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 0, 2)
	root.add_child(_cam)
	_plan = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(3, 3)
	_plan.mesh = q
	root.add_child(_plan)
	_derouler.call_deferred()


func _derouler() -> void:
	# CONTRÔLE DE L'INSTRUMENT : un matériau ordinaire rouge doit se lire rouge, sinon la capture ne mesure rien.
	var temoin := StandardMaterial3D.new()
	temoin.albedo_color = Color.RED
	_plan.material_override = temoin
	var ct := await _centre("controle")
	_dire(_teinte(ct) == "r", "contrôle : un matériau ordinaire rouge se lit rouge (lu %s)" % ct)
	var images: Array = Anim.images_neuves(1, Vector2i(16, 16), Color.RED, _dossier, "rouge")["images"]
	for c in [Color.GREEN, Color.BLUE, Color.YELLOW]:
		images.append_array(Anim.images_neuves(1, Vector2i(16, 16), c, _dossier, "img")["images"])
	var repli := StandardMaterial3D.new()
	repli.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	repli.roughness = 1.0
	var a := Anim.ajouter({}, "albedo", "images", {"images": images, "ips": 2.0, "synchro": true})
	var sm := Anim.materiau(repli, a)
	_plan.material_override = sm
	# Image forcée : chaque couleur à son tour.
	var attendues := [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW]
	for k in 4:
		Anim.image_forcee = k
		var c := await _centre("force_%d" % k)
		_dire(_teinte(c) == _teinte(attendues[k]), "image forcée %d : le centre est %s (lu %s)" % [k, attendues[k], c])
	# Lecture : le temps avance de 0,5 s (une image à 2 images/s).
	Anim.image_forcee = -1
	Anim.temps = 0.0
	var c0 := await _centre("joue_0")
	Anim.temps = 0.5
	var c1 := await _centre("joue_1")
	_dire(_teinte(c0) == "r" and _teinte(c1) == "v", "en jouant, l'image 0 puis l'image 1 (%s, %s)" % [c0, c1])
	# Le défilement : une image à deux moitiés (gauche rouge, droite bleue), décalée d'une demi-largeur.
	var moitie := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	moitie.fill(Color.RED)
	moitie.fill_rect(Rect2i(8, 0, 8, 16), Color.BLUE)
	moitie.save_png(_dossier.path_join("moitie.png"))
	var tex := ImageTexture.create_from_image(moitie)
	var repli2 := StandardMaterial3D.new()
	repli2.albedo_texture = tex
	var sm2 := Anim.materiau(repli2, Anim.ajouter({}, "albedo", "defilement", {"u": 0.5, "v": 0.0}))
	_plan.material_override = sm2
	Anim.temps = 0.0
	var g0 := await _pixel(Vector2(0.42, 0.5), "defile_0")
	Anim.temps = 1.0   # un demi-tour d'image : la moitié gauche montre ce qu'était la droite
	var g1 := await _pixel(Vector2(0.42, 0.5), "defile_1")
	_dire(_teinte(g0) != _teinte(g1), "le défilement déplace l'image (%s puis %s)" % [g0, g1])
	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	print("VERDICT : %s" % ("ÉCHEC" if _echecs > 0 else "OK"))
	quit(1 if _echecs > 0 else 0)


func _centre(nom: String) -> Color:
	return await _pixel(Vector2(0.5, 0.5), nom)


## `p` : la place dans l'image, de 0 à 1 (la fenêtre s'ouvre à la taille que le projet lui donne).
func _pixel(p: Vector2, nom: String) -> Color:
	for i in 4:
		Anim.fige = false
		Anim.en_pause = true   # le temps posé à la main ne bouge pas
		Anim.avancer(0.0)
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(_dossier.path_join(nom + ".png"))
	return img.get_pixelv(Vector2i(Vector2(img.get_size()) * p))


## La teinte dominante : « r », « v », « b », « j » (jaune) ou « ? ».
func _teinte(c: Color) -> String:
	if c.r > 0.5 and c.g > 0.5 and c.b < 0.3:
		return "j"
	if c.r > 0.5 and c.g < 0.3 and c.b < 0.3:
		return "r"
	if c.g > 0.5 and c.r < 0.3 and c.b < 0.3:
		return "v"
	if c.b > 0.5 and c.r < 0.3 and c.g < 0.3:
		return "b"
	return "?"


func _dire(condition: bool, quoi: String) -> void:
	if condition:
		_ok += 1
		print("  ok — %s" % quoi)
	else:
		_echecs += 1
		print("  ÉCHEC — %s" % quoi)
