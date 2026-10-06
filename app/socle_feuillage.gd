extends SubViewportContainer
## LE SOCLE — le modèle de feuillage posé sur un morceau de SOL, pour régler « à quel offset l'objet sera placé par
## rapport au sol » (Jordan, 6 octobre 2026). Un disque de pierre dont le dessus EST le sol (y = 0), un plan
## translucide qui le prolonge (on voit ce qui passe dessous : les racines), l'anneau de l'EMPREINTE, et le modèle tel
## qu'il sera planté — décalage, échelle et vent compris (c'est le même dessin que dans le monde : `FeuillageVue`).
## Glisser tourne autour, la molette rapproche.

const FE := preload("res://addons/marchingblocks_core/feuillage.gd")
const FeuillageVue := preload("res://app/feuillage_vue.gd")

var _vue: SubViewport
var _camera: Camera3D
var _plants: FeuillageVue
var _sol: MeshInstance3D
var _plan: MeshInstance3D
var _azimut := 0.7
var _elevation := 0.35
var _distance := 4.0
var _hauteur_visee := 1.0
var modele: Variant = null


func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(0, 220)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vue = SubViewport.new()
	_vue.own_world_3d = true
	_vue.msaa_3d = Viewport.MSAA_4X
	add_child(_vue)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#15181d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8a93a3")
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	_vue.add_child(we)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-50, 35, 0)
	soleil.shadow_enabled = true
	_vue.add_child(soleil)
	# Le socle : un disque de pierre dont le DESSUS est le sol.
	_sol = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.08
	cyl.height = 0.3
	var pierre := StandardMaterial3D.new()
	pierre.albedo_color = Color("#6b6459")
	pierre.roughness = 0.95
	cyl.material = pierre
	_sol.mesh = cyl
	_sol.position = Vector3(0, -0.15, 0)
	_vue.add_child(_sol)
	# Le plan du sol, translucide : ce qui passe dessous (les racines) se voit au travers.
	_plan = MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(6, 6)
	var verre := StandardMaterial3D.new()
	verre.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	verre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	verre.albedo_color = Color(0.71, 0.74, 0.52, 0.18)
	verre.cull_mode = BaseMaterial3D.CULL_DISABLED
	plan.material = verre
	_plan.mesh = plan
	_plan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_plan.position = Vector3(0, 0.002, 0)
	_vue.add_child(_plan)
	_plants = FeuillageVue.new()
	_vue.add_child(_plants)
	_camera = Camera3D.new()
	_camera.fov = 40
	_vue.add_child(_camera)
	_caler()


## Montre ce modèle (ou rien), à ses réglages du moment. Un plant à l'origine, d'échelle de tirage 1.
func montrer(m: Variant) -> void:
	modele = m
	if _plants == null:
		return
	if m == null:
		_plants.poser([], [])
		_plants.montrer_anneaux([])
		return
	var pl := FE.plant(1, int(m["id"]), Vector3.ZERO, 0.0, 1.0, "sol")
	_plants.poser([m], [pl])
	var r := float(m["rayon"]) * float(m["echelle"])
	_plants.montrer_anneaux([[Vector3.ZERO, r, Color(0.71, 0.74, 0.52)]])
	# Le socle et le plan à la taille de l'empreinte ; la caméra cadre le modèle entier.
	var largeur := maxf(r * 1.6, 0.6)
	_sol.scale = Vector3(largeur, 1.0, largeur)
	_plan.scale = Vector3.ONE * maxf(1.0, largeur)
	var h := maxf(FE.hauteur_au_dessus_du_sol(m, pl), 0.3)
	_hauteur_visee = h * 0.45
	_distance = maxf(h, largeur * 2.0) * 2.0
	_caler()


func _caler() -> void:
	if _camera == null:
		return
	var cible := Vector3(0, _hauteur_visee, 0)
	var dir := Vector3(cos(_elevation) * sin(_azimut), sin(_elevation), cos(_elevation) * cos(_azimut))
	_camera.position = cible + dir * _distance
	_camera.look_at(cible, Vector3.UP)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask != 0:
		var m := event as InputEventMouseMotion
		_azimut -= m.relative.x * 0.01
		_elevation = clampf(_elevation + m.relative.y * 0.01, -0.6, 1.4)
		_caler()
		accept_event()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(0.5, _distance / 1.12)
		elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(200.0, _distance * 1.12)
		else:
			return
		_caler()
		accept_event()


func plants() -> FeuillageVue:
	return _plants
