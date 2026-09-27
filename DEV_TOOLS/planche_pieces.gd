extends SceneTree
##
## LA PLANCHE DES PIÈCES — regarder une tuile SEULE, saillante contre rentrante.
##
## LANCEMENT — ⚠ AVEC FENÊTRE (le headless ne rend rien) :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/planche_pieces.gd -- --sortie=D:/MarchingBlocks/ART/planche_pieces.png
##
## ── POURQUOI ELLE EXISTE ────────────────────────────────────────────────────────────────────────────
##
## Jordan, 24 septembre : *« le bloc maître massif a son coin rentrant qui est un coin saillant, ce qui
## fait qu'après tranchage ça ne remplit pas sa fonction là où il devrait laisser apparaître des coins
## rentrants, par différence avec les coins saillants. »*
##
## ⚠ **AUCUN COMPTEUR N'ATTRAPE ÇA.** `verifier_octants` garantit que la matière est PRÉSENTE dans les
## octants qui bordent le vide ; il ne dit rien de sa FORME. Une pièce peut porter de la surface dans
## tous ses octants et présenter malgré tout un angle convexe là où le modèle veut un angle concave.
## Seule une image de la pièce SEULE le montre — dans un monde assemblé, elle est noyée dans ses voisines.
##
## ── CE QU'ON COMPARE ────────────────────────────────────────────────────────────────────────────────
##
## Quatre classes, en colonnes : un coin SAILLANT, un coin RENTRANT, une arête SAILLANTE, une arête
## RENTRANTE. UNE seule ligne : le lot unique, aminci.
##
## ⚠ **LA COMPARAISON QUI JUSTIFIAIT CET OUTIL N'EXISTE PLUS (Jordan, 25 septembre 2026).** Il montrait
## DEUX lignes — le lot PLEIN et le lot MOITIÉ — pour répondre à « la pièce rentrante creuse-t-elle
## encore un angle concave une fois amincie, ou devient-elle un bloc posé ? ». L'aminci étant désormais
## le seul mode, il n'y a plus de second terme à la comparaison.
##
## ⚠ **CE QUI RESTE GARDE SA RAISON D'ÊTRE** : un contrôle À L'ŒIL des quatre formes caractéristiques.
## Aucun compteur ne dit si une pièce est à l'endroit — trois fois la couverture fut parfaite et le rendu
## faux, et seule une image l'a montré (charte §6).

const MB := preload("res://addons/marching_blocks_plugin_godot/marching_blocks.gd")

const CASE := Vector2i(300, 300)
const FOND := Color("#101216")

## ⚠ LES NOMS SONT ÉCRITS, et c'est assumé : ce sont ceux que Jordan désigne. `anomalies()` garantit
## ailleurs qu'ils existent ; ici on veut précisément CES quatre-là, pas un échantillon.
const CLASSES := [
	{"nom": "mb_coin_b1h0", "quoi": "coin SAILLANT"},
	{"nom": "mb_equerre_creuse_b4h1", "quoi": "coin RENTRANT"},
	{"nom": "mb_arete_b2h0", "quoi": "arête SAILLANTE"},
	{"nom": "mb_arete_creuse_b4h2", "quoi": "arête RENTRANTE"},
]

## ⚠ RESTE UNE LISTE, bien qu'elle n'ait plus qu'un seul élément : la mise en page se DÉDUIT de
## `LOTS.size()` (voir `_image`), donc y remettre un terme à comparer un jour ne demandera pas de
## retoucher la grille.
const LOTS := [
	{"chemin": "res://ART/marching_blocks.tres", "quoi": "lot aminci"},
]

var _vues: Array = []
var _sortie := "planche_pieces.png"
var _images := 0


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--sortie="):
			_sortie = option.substr("--sortie=".length())

	for lot_def in LOTS:
		var chemin: String = lot_def["chemin"]
		if not ResourceLoader.exists(chemin):
			print("⚠ « %s » n'existe pas — lance d'abord faire_monde_essai.gd" % chemin)
			quit(1)
			return
		var lot: MeshLibrary = ResourceLoader.load(chemin) as MeshLibrary
		for classe in CLASSES:
			var id: int = lot.find_item_by_name(classe["nom"])
			var mesh: Mesh = lot.get_item_mesh(id) if id >= 0 else null
			print("%-14s %-24s %s" % [lot_def["quoi"], classe["nom"],
				"absente du lot" if mesh == null else "%d surface(s)" % mesh.get_surface_count()])
			_vues.append(_faire_vue(mesh))

	process_frame.connect(_image)


func _image() -> void:
	_images += 1
	if _images < 5:
		return
	var premiere: Image = _vues[0].get_texture().get_image()
	var planche := Image.create(CASE.x * CLASSES.size(), CASE.y * LOTS.size(), false,
		premiere.get_format())
	planche.fill(FOND)
	for i in _vues.size():
		var img: Image = _vues[i].get_texture().get_image()
		planche.blit_rect(img, Rect2i(Vector2i.ZERO, CASE),
			Vector2i((i % CLASSES.size()) * CASE.x, (i / CLASSES.size()) * CASE.y))
	var err := planche.save_png(_sortie)
	print("\nplanche %d×%d → %s (%s)" % [planche.get_width(), planche.get_height(), _sortie,
		"écrite" if err == OK else "ERREUR %d" % err])
	print("   colonnes : %s" % ", ".join(PackedStringArray(CLASSES.map(func(c): return c["quoi"]))))
	print("   lignes   : %s" % ", ".join(PackedStringArray(LOTS.map(func(l): return l["quoi"]))))
	print("\n⚠ Ce qu'on regarde : la pièce RENTRANTE creuse-t-elle bien un angle concave, ou est-elle")
	print("   devenue un bloc posé — donc convexe ? Aucun compteur ne répond à ça, seule l'image.")
	quit(0 if err == OK else 1)


## ⚠ UNE PIÈCE EST UN CUBE UNITÉ CENTRÉ SUR L'ORIGINE : même cadrage pour les huit, sinon une pièce
## plus grosse à l'écran passerait pour une pièce plus grosse tout court.
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
