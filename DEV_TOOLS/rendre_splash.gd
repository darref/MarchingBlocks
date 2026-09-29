extends SceneTree
##
## LE FOND DU SPLASH — « Sculpt one block. Paint a world. », rendu avec le VRAI produit.
##
## LANCEMENT — ⚠ AVEC FENÊTRE, jamais en headless (le headless ne rend RIEN) :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/rendre_splash.gd -- --sortie=D:/chemin/splash_fond.png
##
## Au premier plan, le témoin de 12³ (l'aminci, tel qu'il part chez l'artiste) flotte, strié de ses
## plans de coupe en or ; derrière lui, un monde peint avec SES tuiles, par le vrai peintre, s'éloigne
## dans la brume. Aucune image empruntée, aucun modèle généré : c'est ce que l'acheteur aura.
##
## ⚠ CE SCRIPT NE REND QUE LE FOND. La signature (logo et nom de la compagnie, dans un coin) est collée
## par `MARQUE/composer_splash.py`, la même pour chaque logiciel.
##
## ⚠ ON REND DANS UN SubViewport, PAS DANS LA FENÊTRE : Windows rogne une fenêtre plus haute que l'écran
## moins la barre des tâches (mesuré : 1920 × 1017 au lieu de 1080).

const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const MP := preload("res://addons/marchingblocks_core/massif_peint.gd")

const LARGEUR := 1920
const HAUTEUR := 1080
const OR := Color(0.80, 0.64, 0.27)
const BRUME := Color("#7a6070")
const HORIZON := Color("#d9a65c")
## Le monde : un relief en terrasses, `ETENDUE` cases de côté.
const ETENDUE := 110
const LACET := 45.0
const INCLINAISON := 22.0

var _sortie := "D:/MarchingBlocks/MARQUE/splash_fond.png"
var _vue: SubViewport
var _bloc: Node3D
## `--lacets=20,110` rend une image par orientation du témoin (`<sortie>_<lacet>.png`), pour choisir.
var _lacets: Array = []
var _camera: Camera3D


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--sortie="):
			_sortie = option.substr("--sortie=".length())
		if option.begins_with("--lacets="):
			for l in option.substr("--lacets=".length()).split(","):
				_lacets.append(float(l))
	_vue = SubViewport.new()
	_vue.size = Vector2i(LARGEUR, HAUTEUR)
	_vue.msaa_3d = Viewport.MSAA_8X
	_vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vue)
	_ambiance()
	_monde()
	_temoin()
	_derouler()


func _derouler() -> void:
	for lacet in _lacets:
		_orienter(lacet)
		for _k in 6:
			await process_frame
		_vue.get_texture().get_image().save_png(_sortie.get_basename() + "_%d.png" % lacet)
	if not _lacets.is_empty():
		print("orientations rendues : ", _lacets)
		quit(0)
		return
	for _k in 12:
		await process_frame
	var img := _vue.get_texture().get_image()
	img.save_png(_sortie)
	print("fond du splash : ", _sortie, " (", img.get_width(), "×", img.get_height(), ")")
	quit(0)


## Un crépuscule : zénith violet profond, horizon olive doré, et une brume qui efface les bords du monde.
## ⚠ Le « sol » du ciel prend la couleur de la brume : sinon, au-delà du monde, on voit du violet.
func _ambiance() -> void:
	var ciel := ProceduralSkyMaterial.new()
	ciel.sky_top_color = Color("#2b1a55")
	ciel.sky_horizon_color = HORIZON
	ciel.sky_curve = 0.07
	ciel.ground_horizon_color = HORIZON
	ciel.ground_bottom_color = BRUME
	ciel.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = ciel
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = BRUME
	env.fog_depth_begin = 30.0
	env.fog_depth_end = 125.0
	env.fog_depth_curve = 1.6
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	_vue.add_child(we)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-22, 160, 0)
	soleil.light_color = Color("#ffe2b0")
	soleil.light_energy = 1.1
	soleil.shadow_enabled = true
	soleil.directional_shadow_max_distance = 120.0
	_vue.add_child(soleil)
	_camera = Camera3D.new()
	_camera.fov = 42
	_camera.far = 400
	_vue.add_child(_camera)
	_camera.transform = Transform3D(Basis(), Vector3(-2, 16, -2)).looking_at(Vector3(40, 8, 46))


## Le monde peint : un relief en terrasses, débarrassé de ses contacts diagonaux (charte §2), et peint
## par le vrai peintre avec les tuiles du témoin.
func _monde() -> void:
	var bruit := FastNoiseLite.new()
	bruit.seed = 11
	bruit.frequency = 0.022
	bruit.fractal_octaves = 2
	var pleines := {}
	for x in ETENDUE:
		for z in ETENDUE:
			var n := bruit.get_noise_2d(x, z) * 0.5 + 0.5
			var h := clampi(int(pow(n, 1.6) * 16.0), 1, 12)
			for y in h:
				pleines[Vector3i(x, y, z)] = true
	print("contacts diagonaux réparés : ", MB.completer_les_carres(pleines, 0))
	var bilan := BM.librairie()
	var massif = MP.new()
	_vue.add_child(massif)
	massif.preparer()
	var cases: GridMap = massif.get_node("Cases")
	for c in pleines:
		cases.set_cell_item(c, 0)
	cases.visible = false
	massif.lot = bilan["lot"]
	print("monde : ", massif.reconstruire())


## Le témoin, flottant au premier plan, et ses plans de coupe tracés en or sur sa boîte. Placé dans le
## repère de la CAMÉRA (devant, à gauche, un peu haut) : bouger la caméra ne le perd pas.
func _temoin() -> void:
	var t := _camera.transform   # ⚠ pas `global_transform` : rien n'est encore dans l'arbre
	var devant := -t.basis.z
	var bloc := Node3D.new()
	bloc.position = t.origin + devant * 22.0 - t.basis.x * 5.8 + t.basis.y * 2.6
	_vue.add_child(bloc)
	_bloc = bloc
	_orienter(LACET)
	var maillage := MeshInstance3D.new()
	maillage.mesh = BM.maillage_moitie(0)
	maillage.position = -Vector3.ONE * BM.COTE * 0.5
	# ⚠ Sans ombre : celle d'un bloc qui flotte fait une tache noire au milieu du monde.
	maillage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bloc.add_child(maillage)
	var lignes := MeshInstance3D.new()
	lignes.mesh = _plans_de_coupe(BM.COTE)
	lignes.position = maillage.position
	lignes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bloc.add_child(lignes)


## Les plans de coupe passent par les CENTRES des cases (charte §2) : en `k + ½`. On trace leurs traces
## sur les six faces de la boîte, discrètes, et les douze arêtes de la boîte, qui brillent.
## Le lacet choisit la face montrée ; l'INCLINAISON, autour de l'axe horizontal de la caméra, bascule le
## dessus du témoin vers l'œil — c'est là que sont ses formes (canyon, arche), pas sur ses faces sciées.
func _orienter(lacet: float) -> void:
	var droite := _camera.transform.basis.x
	_bloc.basis = Basis(droite, deg_to_rad(INCLINAISON)) * Basis(Vector3.UP, deg_to_rad(lacet)) 		* Basis().scaled(Vector3.ONE * 0.5)


func _plans_de_coupe(cote: int) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var fin := StandardMaterial3D.new()
	fin.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fin.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fin.albedo_color = Color(OR, 0.35)
	var vif := StandardMaterial3D.new()
	vif.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vif.albedo_color = OR * 2.4
	var n := float(cote)
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, fin)
	for axe in 3:
		for k in cote:
			var q := _carre(axe, float(k) + 0.5, n)
			for i in 4:
				mesh.surface_add_vertex(q[i])
				mesh.surface_add_vertex(q[(i + 1) % 4])
	mesh.surface_end()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, vif)
	for axe in 3:
		for c in [0.0, n]:
			var q := _carre(axe, c, n)
			for i in 4:
				mesh.surface_add_vertex(q[i])
				mesh.surface_add_vertex(q[(i + 1) % 4])
	mesh.surface_end()
	return mesh


func _carre(axe: int, c: float, n: float) -> Array:
	var q: Array = []
	for uv in [Vector2(0, 0), Vector2(n, 0), Vector2(n, n), Vector2(0, n)]:
		var p := Vector3.ZERO
		p[axe] = c
		p[(axe + 1) % 3] = uv.x
		p[(axe + 2) % 3] = uv.y
		q.append(p)
	return q
