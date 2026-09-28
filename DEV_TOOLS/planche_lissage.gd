extends SceneTree
##
## LA PLANCHE DU LISSAGE — la coque actuelle et la coque lissée, côte à côte.
##
## LANCEMENT — ⚠ AVEC FENÊTRE, jamais en headless (le headless ne rend RIEN) :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/planche_lissage.gd -- --sortie=D:/MarchingBlocks/ART/planche_lissage.png
##
## ── CE QU'ELLE RÉPOND, ET CE QU'ELLE NE PROUVE PAS ──────────────────────────────────────────────────
##
## Elle répond à UNE question, celle qu'aucun compteur ne sait traiter : **est-ce que ça a l'air juste ?**
## Trois fois dans ce projet la couverture était parfaite et le rendu faux ; seule une image l'a montré.
##
## ⚠ **ELLE NE PROUVE NI LA TOPOLOGIE NI LA COUTURE.** Un maillage non-manifold se rend exactement comme
## un maillage sain — c'est tout le problème des arêtes ambiguës, que personne ne voit avant Blender.
## Ces deux-là se mesurent dans `sonde_lissage.gd`, et regarder l'image pour conclure sur un compte
## serait la tautologie que Jordan avait déjà relevée sur la première planche du repli (charte §6).
##
## ── LE CADRAGE ──────────────────────────────────────────────────────────────────────────────────────
##
## ⚠ **MÊME CAMÉRA, MÊME LUMIÈRE, MÊME FOND POUR LES DEUX.** Un rendu de contrôle jugé dans un cadre
## différent de son témoin a déjà menti dans ce projet : une pièce rendue sur un fond qu'elle n'aurait
## jamais en place. Ici la seule chose qui change d'une case à l'autre est le MAILLAGE.

const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")

const CASE := Vector2i(620, 620)
const FOND := Color("#101216")
const OR := Color("#ebbb69")

var _vues: Array = []
var _sortie := "planche_lissage.png"
var _images := 0
## Le cadrage : de face et de haut, ou serré sur un coin pour VOIR les marches.
var _serre := false
## De combien on lisse : 0 reproduit la coque à facettes, 1 fond complètement.
var _force := 1.0


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--sortie="):
			_sortie = option.substr("--sortie=".length())
		if option == "--serre":
			_serre = true
		if option.begins_with("--force="):
			_force = option.substr("--force=".length()).to_float()

	var fautes: Array = BM.anomalies()
	if fautes.is_empty():
		print("anomalies() : aucune\n")
	else:
		print("⚠ anomalies() : %d — l'image montrera un jeu de blocs EN FAUTE\n" % fautes.size())
		for f in fautes:
			print("   • %s" % f)

	print("cadrage : %s   ·   force du lissage : %.2f\n"
		% [("SERRÉ sur un coin" if _serre else "le bloc entier"), _force])
	# ⚠ LA GAUCHE RESTE TOUJOURS LA COQUE ACTUELLE, quelle que soit la force : un témoin qui changerait
	# d'une image à l'autre ne permettrait de comparer que des souvenirs.
	_vues.append(_faire_vue(BM.maillage_moitie(0)))
	_vues.append(_faire_vue(BM.maillage_lisse(0, 0.5, _force)))
	process_frame.connect(_image)


func _image() -> void:
	_images += 1
	if _images < 4:   # ⚠ laisser les SubViewport rendre avant de capturer
		return
	var premiere: Image = _vues[0].get_texture().get_image()
	var planche := Image.create(CASE.x * 2, CASE.y, false, premiere.get_format())
	planche.fill(FOND)
	for i in _vues.size():
		var img: Image = _vues[i].get_texture().get_image()
		planche.blit_rect(img, Rect2i(Vector2i.ZERO, CASE), Vector2i(i * CASE.x, 0))
	# un trait vertical pour séparer les deux moitiés, sinon on ne sait pas où l'une finit
	for y in CASE.y:
		planche.set_pixel(CASE.x, y, OR)
		planche.set_pixel(CASE.x - 1, y, OR)

	var err := planche.save_png(_sortie)
	print("planche %d×%d → %s (%s)"
		% [planche.get_width(), planche.get_height(), _sortie,
			"écrite" if err == OK else "ERREUR %d" % err])
	print("\n   GAUCHE : la coque ACTUELLE (sous-voxels, faces alignées sur les axes)")
	print("   DROITE : la coque LISSÉE (maillage dual, les marches deviennent des pentes)")
	print("\n⚠ Cette image ne dit RIEN de la topologie ni de la couture : voir sonde_lissage.gd.")
	quit(0 if err == OK else 1)


func _faire_vue(mesh: ArrayMesh) -> SubViewport:
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
	env.ambient_light_energy = 0.75
	var monde := WorldEnvironment.new()
	monde.environment = env
	vue.add_child(monde)

	var lumiere := DirectionalLight3D.new()
	lumiere.rotation_degrees = Vector3(-48, -34, 0)
	lumiere.light_energy = 1.15
	vue.add_child(lumiere)

	var cible := Vector3.ONE * (BM.COTE * 0.5)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	if _serre:
		# ⚠ Serré sur un coin HAUT : les marches vivent sur les surfaces vues de dessus, et un cadrage
		# large les rend trop petites pour être jugées — l'image conclurait « pareil » par manque de
		# pixels, pas par ressemblance.
		cible = Vector3(BM.COTE * 0.25, BM.COTE * 0.75, BM.COTE * 0.25)
		camera.size = BM.COTE * 0.6
	else:
		camera.size = BM.COTE * 1.65
	camera.position = cible + Vector3(1.0, 0.82, 1.0).normalized() * 40.0
	vue.add_child(camera)
	camera.look_at_from_position(camera.position, cible, Vector3.UP)

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	vue.add_child(instance)
	return vue
