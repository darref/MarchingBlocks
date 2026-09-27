extends SceneTree
##
## LA PLANCHE DU BLOC ENTIER — le témoin et un sculpt, côte à côte, sous quatre angles.
##
## LANCEMENT — ⚠ AVEC FENÊTRE, jamais en headless (le headless ne rend RIEN) :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/planche_bloc_entier.gd \
##       -- --fichier=C:/chemin/vers/le.glb --sortie=D:/MarchingBlocks/ART/bloc_entier.png
##
## ── POURQUOI ELLE EXISTE ────────────────────────────────────────────────────────────────────────────
##
## Jordan, 25 septembre 2026 : *« je pense que j'ai fait une erreur en faisant un chapeau de champignon
## en extrudant toutes les faces les plus hautes du témoin en pensant qu'elles représentaient le massif
## de base, comme le faisait le premier MB des 9. »*
##
## ⚠ **C'EST SA QUESTION, PAS LA MIENNE, ET ELLE MÉRITE UNE IMAGE PLUTÔT QU'UN AVIS.** Toutes les sondes
## ont regardé les TUILES ; aucune n'a regardé le bloc entier qu'il a sculpté. On ne peut pas dire à
## quelqu'un « oui, tu t'es trompé de forme » sans avoir regardé la forme.
##
## ⚠ **ET ELLE ÉCLAIRE UN DÉFAUT QUI EST LE NÔTRE.** Les neuf blocs portaient chacun un nom et un rôle
## — « massif et plateau », « salle de grotte », « érosion ». Le bloc unique a gagné les raccords
## visibles et perdu la LÉGENDE : rien ne dit plus à l'artiste quelle région est un massif, laquelle est
## une falaise, laquelle est une grotte. Il a dû deviner.
##
## ⚠ Quatre angles, parce qu'un chapeau ne se voit pas de dessus. Même cadrage, même lumière, même fond
## pour les deux : un rendu de contrôle jugé dans un cadre différent de son témoin a déjà menti ici.

const BM := preload("res://addons/marching_blocks_plugin_godot/blocs_maitres.gd")

const CASE := Vector2i(380, 380)
const FOND := Color("#101216")
const OR := Color("#ebbb69")

## Les quatre points de vue, en degrés autour du bloc. ⚠ Dont un RASANT : un surplomb ou un chapeau est
## invisible vu de dessus, et c'est précisément ce qu'on cherche.
const ANGLES := [
	{"quoi": "trois quarts haut", "dir": Vector3(1.0, 0.8, 1.0)},
	{"quoi": "trois quarts bas", "dir": Vector3(1.0, 0.18, 1.0)},
	{"quoi": "de face", "dir": Vector3(0.0, 0.15, 1.0)},
	{"quoi": "de dessous", "dir": Vector3(1.0, -0.5, 1.0)},
]

## ⚠ **`--zoom=` ET `--cible=` PARCE QU'UN CHANFREIN DE 0,2 CASE NE SE VOIT PAS SUR UN BLOC DE 8.**
## Le cadrage large répond à « quelle FORME a-t-il sculptée » ; il ne répond pas à « quel GESTE a-t-il
## fait sur une arête ». Deux questions, un seul cadrage réglable — jamais deux planches (charte §6).
## ⚠ **`--chanfrein` MET LA PISTE EN HAUT À LA PLACE DE L'AMINCI.** La ligne du haut est le RÉFÉRENT :
## tant qu'on cherchait ce que Jordan voyait, c'était le témoin qui part ; maintenant qu'on cherche à
## reproduire son geste, c'est le candidat. Une seule planche, un seul cadrage — sinon on compare deux
## images qui ne se comparent pas (charte §6).
## ⚠ **`--ouest` REGARDE DE L'AUTRE CÔTÉ, et il a fallu s'en apercevoir à l'image.** Les quatre angles
## tournent tous autour de +x/+z : un relief creusé du côté −x reste invisible sur les quatre vues, et
## l'on conclut « le bloc ne montre rien » alors qu'on ne l'a simplement jamais regardé.
var _ouest := false
var _chanfrein := false
var _zoom := 0.0
var _cible := Vector3.INF
var _fichier := ""
var _sortie := "bloc_entier.png"
var _vues: Array = []
var _images := 0


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--fichier="):
			_fichier = option.substr("--fichier=".length())
		if option.begins_with("--sortie="):
			_sortie = option.substr("--sortie=".length())
		if option == "--ouest":
			_ouest = true
		if option == "--chanfrein":
			_chanfrein = true
		if option.begins_with("--zoom="):
			_zoom = float(option.substr("--zoom=".length()))
		if option.begins_with("--cible="):
			var m: PackedStringArray = option.substr("--cible=".length()).split(",")
			if m.size() == 3:
				_cible = Vector3(float(m[0]), float(m[1]), float(m[2]))
	if _fichier == "":
		print("il faut --fichier=<le .glb sculpté>")
		quit(1)
		return
	if not FileAccess.file_exists(_fichier):
		print("⚠ INTROUVABLE : %s" % _fichier)
		quit(1)
		return

	var sculpte: ArrayMesh = _lire(_fichier)
	if sculpte == null:
		print("⚠ illisible comme glTF")
		quit(1)
		return
	var referent: ArrayMesh = BM.maillage_chanfreine(0) if _chanfrein else BM.maillage_moitie(0)
	print("%s : %d sommet(s)" % ["piste " if _chanfrein else "témoin", _sommets(referent)])
	print("sculpt  : %d sommet(s)\n" % _sommets(sculpte))

	for mesh in [referent, sculpte]:
		for a in ANGLES:
			_vues.append(_faire_vue(mesh, a["dir"]))
	process_frame.connect(_image)


func _image() -> void:
	_images += 1
	if _images < 5:
		return
	var premiere: Image = _vues[0].get_texture().get_image()
	var planche := Image.create(CASE.x * ANGLES.size(), CASE.y * 2, false, premiere.get_format())
	planche.fill(FOND)
	for i in _vues.size():
		var img: Image = _vues[i].get_texture().get_image()
		planche.blit_rect(img, Rect2i(Vector2i.ZERO, CASE),
			Vector2i((i % ANGLES.size()) * CASE.x, (i / ANGLES.size()) * CASE.y))
	for x in planche.get_width():
		planche.set_pixel(x, CASE.y, OR)
		planche.set_pixel(x, CASE.y - 1, OR)

	var err := planche.save_png(_sortie)
	print("planche %d×%d → %s (%s)"
		% [planche.get_width(), planche.get_height(), _sortie,
			"écrite" if err == OK else "ERREUR %d" % err])
	print("   colonnes : %s" % ", ".join(PackedStringArray(ANGLES.map(func(a): return a["quoi"]))))
	print("   HAUT = %s   ·   BAS = le SCULPT de Jordan"
		% ("LA PISTE chanfreinée" if _chanfrein else "le TÉMOIN tel qu'il part"))
	quit(0 if err == OK else 1)


func _faire_vue(mesh: ArrayMesh, direction: Vector3) -> SubViewport:
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
	env.ambient_light_energy = 0.85
	var monde := WorldEnvironment.new()
	monde.environment = env
	vue.add_child(monde)

	var lumiere := DirectionalLight3D.new()
	lumiere.rotation_degrees = Vector3(-42, -38, 0)
	lumiere.light_energy = 1.2
	vue.add_child(lumiere)

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	vue.add_child(instance)

	if _ouest:
		direction.x = -direction.x
	var cible: Vector3 = _cible if _cible != Vector3.INF else Vector3.ONE * (BM.COTE * 0.5)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _zoom if _zoom > 0.0 else BM.COTE * 1.5
	camera.position = cible + direction.normalized() * 30.0
	vue.add_child(camera)
	camera.look_at_from_position(camera.position, cible, Vector3.UP)
	return vue


func _sommets(mesh: ArrayMesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var a: Array = mesh.surface_get_arrays(s)
		if not a.is_empty():
			n += (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return n


func _lire(chemin: String) -> ArrayMesh:
	var document := GLTFDocument.new()
	var etat := GLTFState.new()
	if document.append_from_file(chemin, etat) != OK:
		return null
	var scene: Node = document.generate_scene(etat)
	if scene == null:
		return null
	var trouve: ArrayMesh = _chercher(scene)
	scene.queue_free()
	return trouve


func _chercher(noeud: Node) -> ArrayMesh:
	if noeud.has_method("get_mesh"):
		var m = noeud.call("get_mesh")
		if m is ArrayMesh:
			return m
	for enfant in noeud.get_children():
		var t: ArrayMesh = _chercher(enfant)
		if t != null:
			return t
	return null
