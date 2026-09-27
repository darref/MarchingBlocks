extends SceneTree
##
## LA PLANCHE DES TUILES — celles du témoin et celles d'un sculpt, côte à côte.
##
## LANCEMENT — ⚠ AVEC FENÊTRE, jamais en headless (le headless ne rend RIEN) :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/planche_tuiles_sculptees.gd \
##       -- --fichier=C:/chemin/vers/le.glb --sortie=D:/MarchingBlocks/ART/tuiles.png
##
## ── LA QUESTION À LAQUELLE ELLE RÉPOND ──────────────────────────────────────────────────────────────
##
## *« La peinture ne recrée pas du tout les bonnes formes »* (Jordan, 25 septembre 2026) — alors que tous
## les compteurs sont verts : 68 classes, 0 erreur, et des pièces de la bonne TAILLE. Il ne reste qu'une
## question, et aucun compteur ne sait la traiter : **à quoi ressemblent les tuiles livrées ?**
##
## ⚠ **LIGNE DU HAUT : le TÉMOIN. LIGNE DU BAS : le SCULPT.** Les deux dans le même cadrage, la même
## lumière, le même fond — seule la source change. Un rendu de contrôle jugé dans un cadre différent de
## son témoin a déjà menti dans ce projet (charte §6).
##
## ⚠ **LES CLASSES MONTRÉES SONT LES PLUS POSÉES D'UN MONDE RÉEL**, pas un échantillon au hasard :
## `mb_plaque_b4h0` (le sol), `mb_plaque_b0h4` (le plafond), `mb_plaque_b2h2` (le mur),
## `mb_arete_b2h0` (l'arête de falaise), `mb_coin_b1h0` (le coin saillant) — celle qu'une case peinte
## SEULE produit, donc exactement le cas que Jordan a essayé.

const BM := preload("res://addons/marching_blocks_plugin_godot/blocs_maitres.gd")

const CASE := Vector2i(300, 300)
const FOND := Color("#101216")
const OR := Color("#ebbb69")

## ⚠ ÉCRITES EXPRÈS : ce sont les tuiles qui portent un monde. `anomalies()` garantit ailleurs qu'elles
## existent ; ici on veut précisément celles-là, pas un tirage.
const CLASSES := [
	{"nom": "mb_coin_b1h0", "quoi": "coin (1 case peinte)"},
	{"nom": "mb_plaque_b4h0", "quoi": "le SOL"},
	{"nom": "mb_plaque_b2h2", "quoi": "le MUR"},
	{"nom": "mb_plaque_b0h4", "quoi": "le PLAFOND"},
	{"nom": "mb_arete_b2h0", "quoi": "arête de falaise"},
]

var _fichier := ""
var _sortie := "tuiles.png"
var _vues: Array = []
var _images := 0


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--fichier="):
			_fichier = option.substr("--fichier=".length())
		if option.begins_with("--sortie="):
			_sortie = option.substr("--sortie=".length())
	if _fichier == "":
		print("il faut --fichier=<le .glb sculpté>")
		quit(1)
		return

	var temoin: MeshLibrary = (BM.librairie()["lot"] as MeshLibrary)
	var bilan: Dictionary = BM.librairie_depuis_glb(_fichier)
	var sculpte: MeshLibrary = bilan["lot"]
	print("relu du disque : %s   ·   absent(s) : %s\n"
		% [str(bilan["sculptes"]), str(bilan["absents"])])
	# ⚠ SI LE BLOC EST « ABSENT », le lot est le témoin CALCULÉ et la ligne du bas ne montrerait pas le
	# sculpt du tout. On le dit fort plutôt que de rendre une image qui rassure à tort.
	if not (bilan["absents"] as Array).is_empty():
		print("⚠⚠ le bloc n'a PAS été relu du disque : la ligne du bas serait le témoin calculé.")
		quit(1)
		return

	for source in [temoin, sculpte]:
		for c in CLASSES:
			var id: int = source.find_item_by_name(c["nom"])
			var mesh: Mesh = source.get_item_mesh(id) if id >= 0 else null
			_vues.append(_faire_vue(mesh))
	process_frame.connect(_image)


func _image() -> void:
	_images += 1
	if _images < 5:   # ⚠ laisser les SubViewport rendre avant de capturer
		return
	var premiere: Image = _vues[0].get_texture().get_image()
	var planche := Image.create(CASE.x * CLASSES.size(), CASE.y * 2, false, premiere.get_format())
	planche.fill(FOND)
	for i in _vues.size():
		var img: Image = _vues[i].get_texture().get_image()
		planche.blit_rect(img, Rect2i(Vector2i.ZERO, CASE),
			Vector2i((i % CLASSES.size()) * CASE.x, (i / CLASSES.size()) * CASE.y))
	for x in planche.get_width():
		planche.set_pixel(x, CASE.y, OR)
		planche.set_pixel(x, CASE.y - 1, OR)

	var err := planche.save_png(_sortie)
	print("planche %d×%d → %s (%s)"
		% [planche.get_width(), planche.get_height(), _sortie,
			"écrite" if err == OK else "ERREUR %d" % err])
	print("\n   colonnes : %s"
		% ", ".join(PackedStringArray(CLASSES.map(func(c): return c["quoi"]))))
	print("   HAUT = le témoin   ·   BAS = le sculpt de Jordan")
	print("\n⚠ Une tuile noire = absente du lot. Une tuile en plusieurs morceaux = un fragment")
	print("   d'architecture pris au premier sommet qui produisait cette classe.")
	quit(0 if err == OK else 1)


## ⚠ UNE PIÈCE EST UN CUBE UNITÉ CENTRÉ SUR L'ORIGINE : même cadrage pour les dix, sinon une pièce plus
## grosse à l'écran passerait pour une pièce plus grosse tout court.
func _faire_vue(mesh: Mesh) -> SubViewport:
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

	if mesh != null:
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		vue.add_child(instance)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.9
	camera.position = Vector3(1.0, 0.75, 1.0).normalized() * 10.0
	vue.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3.ZERO, Vector3.UP)
	return vue
