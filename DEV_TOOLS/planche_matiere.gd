extends SceneTree
##
## LA PLANCHE DES MATIÈRES — que faut-il vraiment corriger pour qu'une tuile sculptée se voie ?
##
## LANCEMENT — ⚠ AVEC FENÊTRE (le headless ne rend RIEN) :
##   Godot_v4.7-stable_win64_console.exe --path D:/UnderMend \
##       --script res://DEV_TOOLS/planche_matiere.gd \
##       -- --fichier=C:/chemin/vers/le.glb --sortie=D:/UnderMend/ART/matiere.png
##
## ── POURQUOI ELLE EXISTE ────────────────────────────────────────────────────────────────────────────
##
## Jordan a demandé de « fusionner » : garder sa texture et rallumer ce que le greffon sait. ⚠ **Mais
## deux réglages sont en cause et ils n'ont pas le même coût**, alors je les éprouve séparément avant
## d'en livrer un :
##
##   • `cull_mode = 2` (aucune face écartée) — les faces ARRIÈRE se rendent par-dessus les avant. La
##     charte a déjà payé ce défaut sur les tuiles d'interface. Le corriger ne touche PAS à l'art.
##   • `vertex_color_use_as_albedo = false` — nos couleurs (ciel / paroi / plafond) sont ignorées.
##     ⚠ L'activer les MULTIPLIE avec la texture : ce n'est pas révéler, c'est TEINDRE. Sur un maillage
##     texturé, ça verdit l'herbe et brunit la roche.
##
## **Si le `cull` seul suffit, la fusion n'a pas à toucher aux couleurs et l'art de l'artiste reste
## intact. S'il faut `vcol`, Jordan doit le savoir AVANT que je le livre.**
##
## ⚠ **ON NE MODIFIE PAS LE MATÉRIAU DES MAILLAGES.** Il est PARTAGÉ par toutes les tuiles d'un même
## lot : le changer pour un essai les changerait toutes, et je mesurerais mon propre effet de bord.
## On passe par un `surface_override_material` sur l'instance, qui laisse la tuile intacte.
##
## ⚠ **ET LA MESURE NE DIRA PAS CE QUI EST BEAU** : elle dit ce qui est VISIBLE. Lequel des rendus
## convient reste un choix d'artiste, donc celui de Jordan.

const BM := preload("res://addons/undermend/blocs_maitres.gd")

const CASE := Vector2i(300, 300)
const FOND := Color("#101216")
const OR := Color("#ebbb69")

## ⚠ DEUX TUILES ÉCRITES, PAS UN ÉCHANTILLON : le SOL est la tuile la plus posée d'un monde réel, et le
## COIN est exactement ce que produit une case peinte seule — le geste que Jordan a essayé en premier.
const TUILES := [
	{"nom": "mb_plaque_b4h0", "quoi": "le SOL"},
	{"nom": "mb_coin_b1h0", "quoi": "le COIN (1 case)"},
]

var _fichier := ""
var _sortie := "matiere.png"
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
	# ⚠ SI LE BLOC N'A PAS ÉTÉ RELU, le lot est le témoin CALCULÉ et toute la planche comparerait le
	# témoin à lui-même en se faisant passer pour un essai de matière.
	if not (bilan["absents"] as Array).is_empty():
		print("⚠⚠ le bloc n'a PAS été relu du disque — cette planche ne mesurerait rien.")
		quit(1)
		return
	var sculpte: MeshLibrary = bilan["lot"]

	_colonnes = [
		{"quoi": "TÉMOIN (référence)", "lot": temoin, "cull": -1, "vcol": -1},
		{"quoi": "sculpt TEL QUEL", "lot": sculpte, "cull": -1, "vcol": -1},
		{"quoi": "+ cull corrigé", "lot": sculpte, "cull": 0, "vcol": -1},
		{"quoi": "+ vcol activé", "lot": sculpte, "cull": -1, "vcol": 1},
		{"quoi": "LES DEUX (fusion)", "lot": sculpte, "cull": 0, "vcol": 1},
	]

	print("=== CE QUE CHAQUE COLONNE APPLIQUE ===")
	for c in _colonnes:
		print("   %-22s cull %s   vcol %s"
			% [c["quoi"],
				("inchangé" if int(c["cull"]) < 0 else "→ arrière écartées"),
				("inchangé" if int(c["vcol"]) < 0 else "→ activé")])
	print("")

	for t in TUILES:
		for c in _colonnes:
			_vues.append(_faire_vue(c["lot"], t["nom"], int(c["cull"]), int(c["vcol"])))
	process_frame.connect(_image)


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
	# ⚠ un trait après la PREMIÈRE colonne : elle est la référence, pas un essai.
	for y in planche.get_height():
		planche.set_pixel(CASE.x, y, OR)
		planche.set_pixel(CASE.x - 1, y, OR)

	var err := planche.save_png(_sortie)
	print("planche %d×%d → %s (%s)"
		% [planche.get_width(), planche.get_height(), _sortie,
			"écrite" if err == OK else "ERREUR %d" % err])
	print("   colonnes : %s" % ", ".join(PackedStringArray(_colonnes.map(func(c): return c["quoi"]))))
	print("   lignes   : %s" % ", ".join(PackedStringArray(TUILES.map(func(t): return t["quoi"]))))
	print("\n⚠ Si « + cull corrigé » suffit, la fusion n'a pas à toucher aux couleurs de sommets")
	print("   et la texture de l'artiste reste intacte. Si « + vcol » est nécessaire, elle TEINT.")
	quit(0 if err == OK else 1)


func _faire_vue(lot: MeshLibrary, nom: String, cull: int, vcol: int) -> SubViewport:
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
			# ⚠ SURCHARGE SUR L'INSTANCE, jamais sur le maillage : le matériau est partagé par tout le
			# lot, et le modifier ici changerait les quatre autres colonnes en même temps.
			if cull >= 0 or vcol >= 0:
				var base: Material = mesh.surface_get_material(0)
				var copie := (base.duplicate() if base != null else StandardMaterial3D.new()) \
					as StandardMaterial3D
				if copie != null:
					if cull >= 0:
						copie.cull_mode = cull as BaseMaterial3D.CullMode
					if vcol >= 0:
						copie.vertex_color_use_as_albedo = vcol > 0
					instance.set_surface_override_material(0, copie)
			vue.add_child(instance)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.9
	camera.position = Vector3(1.0, 0.75, 1.0).normalized() * 10.0
	vue.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3.ZERO, Vector3.UP)
	return vue
