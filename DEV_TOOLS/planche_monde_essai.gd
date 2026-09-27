extends SceneTree
##
## LA PLANCHE DU MONDE D'ESSAI — regarder ce que la peinture a donné.
##
## LANCEMENT — ⚠ AVEC FENÊTRE, jamais en headless (le headless ne rend rien) :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/planche_monde_essai.gd -- --sortie=D:/MarchingBlocks/ART/planche_monde.png
##
## ── CE QU'ELLE MONTRE, ET CE QU'ELLE NE PROUVE PAS ──────────────────────────────────────────────────
##
## Elle charge `NIVEAUX/monde_essai_3d.tscn` — la scène qu'on peut ouvrir et continuer à peindre — et la
## rend sous quatre angles : d'ensemble, de près sur le TUNNEL, sur l'ARCHE, et par-dessous.
##
## ⚠ **ELLE NE PROUVE AUCUN COMPTE.** Le « 0 faute » est une mesure de `reconstruire()`, imprimée par
## `faire_monde_essai.gd` ; une image ne peut ni la confirmer ni la démentir. Elle répond à une seule
## question, et c'est celle qu'aucun compteur ne sait traiter : **est-ce que ça tient debout à l'œil ?**
## Un trou entre deux pièces, une tuile retournée, une orientation qui bat — voilà ce qui se voit ici et
## nulle part ailleurs. *Une mesure de couverture répond à « a-t-on posé quelque chose », jamais à
## « est-ce la bonne chose »* (charte §6).
##
## ⚠ **LE VENTRE EST VU PAR DESSOUS EXPRÈS.** C'est là qu'un enroulement inversé se voit : les faces de
## dessous disparaîtraient au `cull_mode`, et l'on verrait à travers le monde. C'est exactement la faute
## qui a coûté une planche au repli procédural, et qu'aucun test n'avait su attraper.

## ⚠ RÉGLABLE, et ça a failli me tromper : écrit en dur, ce chemin rendait TOUJOURS le monde de
## production. Lancée après avoir fabriqué un monde d'essai, la planche aurait montré l'ancien — et
## j'aurais conclu que l'amincissement ne donnait rien, sur une image du mauvais sujet.
var SCENE := "res://NIVEAUX/monde_essai_3d.tscn"

const PANNEAU := Vector2i(640, 520)
const FOND := Color("#101216")

var _vues: Array = []
var _sortie := "planche_monde.png"
var _images := 0


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--sortie="):
			_sortie = option.substr("--sortie=".length())
		elif option.begins_with("--scene="):
			SCENE = option.substr("--scene=".length())
	print("scène rendue : %s" % SCENE)

	if not ResourceLoader.exists(SCENE):
		print("« %s » n'existe pas — lance d'abord DEV_TOOLS/faire_monde_essai.gd" % SCENE)
		quit(1)
		return

	# cible, distance, hauteur de caméra, légende
	var angles: Array = [
		{"cible": Vector3(8, 3, 8), "taille": 26.0, "dir": Vector3(1, 0.75, 1), "quoi": "d'ensemble"},
		{"cible": Vector3(6, 3, 4), "taille": 11.0, "dir": Vector3(1, 0.35, 0.25), "quoi": "le TUNNEL"},
		{"cible": Vector3(5.5, 4, 13), "taille": 12.0, "dir": Vector3(0.6, 0.3, 1), "quoi": "l'ARCHE"},
		{"cible": Vector3(8, 1, 8), "taille": 24.0, "dir": Vector3(1, -0.85, 1), "quoi": "PAR DESSOUS"},
	]
	for a in angles:
		_vues.append(_faire_vue(a))

	process_frame.connect(_image)


func _image() -> void:
	_images += 1
	if _images < 5:   # ⚠ laisser les SubViewport rendre avant de capturer
		return

	var premiere: Image = _vues[0].get_texture().get_image()
	var planche := Image.create(PANNEAU.x * 2, PANNEAU.y * 2, false, premiere.get_format())
	planche.fill(FOND)
	for i in _vues.size():
		var img: Image = _vues[i].get_texture().get_image()
		planche.blit_rect(img, Rect2i(Vector2i.ZERO, PANNEAU),
			Vector2i((i % 2) * PANNEAU.x, (i / 2) * PANNEAU.y))

	var err := planche.save_png(_sortie)
	print("planche %d×%d → %s (%s)" % [planche.get_width(), planche.get_height(), _sortie,
		"écrite" if err == OK else "ERREUR %d" % err])
	print("   haut-gauche : d'ensemble      haut-droite : le TUNNEL")
	print("   bas-gauche  : l'ARCHE         bas-droite  : PAR DESSOUS")
	print("\n⚠ Ce qu'on cherche : un TROU entre deux pièces, une tuile RETOURNÉE (on verrait au travers),")
	print("   une orientation qui bat le long d'un mur droit. Les comptes, eux, sont déjà mesurés.")
	quit(0 if err == OK else 1)


func _faire_vue(angle: Dictionary) -> SubViewport:
	var vue := SubViewport.new()
	vue.size = PANNEAU
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
	lumiere.rotation_degrees = Vector3(-46, -37, 0)
	lumiere.light_energy = 1.15
	vue.add_child(lumiere)

	# ⚠ UNE INSTANCE PAR VUE : chaque `SubViewport` a son propre `World3D`, donc un nœud ne peut pas être
	# partagé entre eux. Les quatre mondes sont identiques, seules les caméras diffèrent.
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	vue.add_child(scene)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = angle["taille"]
	var cible: Vector3 = angle["cible"]
	camera.position = cible + (angle["dir"] as Vector3).normalized() * 60.0
	vue.add_child(camera)
	camera.look_at_from_position(camera.position, cible, Vector3.UP)
	return vue
