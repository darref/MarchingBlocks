extends SceneTree
##
## LA PLANCHE DU PBR ESPACE MONDE — le témoin habillé, et le monde peint avec ses tuiles.
##
## LANCEMENT — ⚠ AVEC FENÊTRE, jamais en headless (le headless ne rend RIEN) :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/planche_pbr_monde.gd -- --sortie=D:/MarchingBlocks/ART/pbr_monde.png
##
## ⚠ **DEUX RANGÉES, PARCE QUE LA PROMESSE A DEUX MOITIÉS** (Jordan, 27 septembre 2026) :
##   • EN HAUT, le TÉMOIN d'un seul tenant, le matériau posé en `material_override` — ce que montre la
##     vue du greffon quand la case est cochée ;
##   • EN BAS, un vrai `MassifPeint` dont les cases sont celles du témoin, rendu avec les 52 TUILES
##     tranchées sous le PBR. ⚠ C'est la rangée qui compte : une couture d'espace monde ne peut se voir
##     QUE là, où chaque tuile est un maillage à part, tourné par le GridMap. Si le bas redonne le haut,
##     le matériau suit réellement dans les tuiles.
## ⚠ Même cadrage, même lumière, même fond (charte §6 : un rendu de contrôle doit reproduire le contexte).

const BM := preload("res://addons/marching_blocks_plugin_godot/blocs_maitres.gd")
const PBR := preload("res://addons/marching_blocks_plugin_godot/pbr_monde.gd")

const CASE := Vector2i(520, 520)
const FOND := Color("#101216")
const OR := Color("#ebbb69")
const ANGLES := [
	{"quoi": "trois quarts haut", "dir": Vector3(1.0, 0.8, 1.0), "zoom": 1.5},
	{"quoi": "de face, rasant", "dir": Vector3(0.15, 0.18, 1.0), "zoom": 1.5},
	{"quoi": "de près", "dir": Vector3(1.0, 0.6, 0.7), "zoom": 0.45},
]

var _sortie := "D:/MarchingBlocks/ART/pbr_monde.png"
var _vues: Array = []
var _images := 0


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--sortie="):
			_sortie = option.substr("--sortie=".length())
	var matiere: ShaderMaterial = PBR.matiere()
	if matiere == null:
		print("⚠ textures absentes de %s — lancer d'abord DEV_TOOLS/batir_pbr_monde.gd" % PBR.DOSSIER)
		quit(1)
		return

	var bilan: Dictionary = BM.librairie(matiere)
	print("lot : %d tuiles, %d erreur(s) de tranchage" % [(bilan["lot"] as MeshLibrary).get_item_list().size(),
		(bilan["erreurs"] as Array).size()])

	for a in ANGLES:
		var temoin := MeshInstance3D.new()
		temoin.mesh = BM.maillage_moitie(0)
		temoin.material_override = matiere
		_vues.append(_faire_vue(temoin, a))
	for a in ANGLES:
		_vues.append(_faire_vue(_monde_peint(bilan["lot"]), a))
	process_frame.connect(_image)


## Un `MassifPeint` réel, câblé sur le lot, et peint avec les cases du témoin.
func _monde_peint(lot: MeshLibrary) -> Node3D:
	var massif: Node3D = load("res://addons/marching_blocks_plugin_godot/massif_peint.gd").new()
	massif.lot = lot
	massif.preparer()
	var cases: GridMap = massif.get_node("Cases")
	var id: int = cases.mesh_library.find_item_by_name("case")
	for c in BM.cases(0):
		cases.set_cell_item(c, id)
	var bilan: Dictionary = massif.reconstruire()
	print("monde peint : %s" % str(bilan))
	# La grille des cases se dessine elle aussi : on la cache, on veut voir les TUILES.
	cases.visible = false
	return massif


func _image() -> void:
	_images += 1
	if _images < 8:
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
	print("planche %d×%d → %s (%s)" % [planche.get_width(), planche.get_height(), _sortie,
		"écrite" if err == OK else "ERREUR %d" % err])
	print("   HAUT = le témoin d'un seul tenant   ·   BAS = le monde peint avec les tuiles")
	quit(0 if err == OK else 1)


func _faire_vue(sujet: Node3D, angle: Dictionary) -> SubViewport:
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
	vue.add_child(sujet)

	var cible := Vector3.ONE * (BM.COTE * 0.5)
	if float(angle["zoom"]) < 1.0:
		cible = Vector3(4.5, 6.0, 5.0)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = BM.COTE * float(angle["zoom"])
	camera.position = cible + (angle["dir"] as Vector3).normalized() * 40.0
	vue.add_child(camera)
	camera.look_at_from_position(camera.position, cible, Vector3.UP)
	return vue
