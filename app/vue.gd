extends SubViewportContainer
## LA VUE 3D — ce que SoluTiles dessinait à plat dans son canevas, ici dans un monde en trois dimensions.
##
## Deux choses à montrer, jamais en même temps :
##   • le TÉMOIN (ou le travail importé) — ce que l'artiste sculpte, qu'on fait tourner ;
##   • le MONDE DE TEST — un `MassifPeint` réel, qu'on peint case par case avec le lot tranché.
##
## ⚠ **LE PINCEAU EST ICI PARCE QUE L'ÉDITEUR GODOT N'EST PLUS LÀ.** Le greffon s'appuyait sur le
## pinceau natif du GridMap ; un logiciel autonome doit écrire le sien. C'est la « sélection maison »
## de la charte §5 : en 3D un clic est un RAYON, et on le coupe contre le plan de l'ÉTAGE courant — ce
## que fait l'éditeur natif avec son niveau de sol.
##
## ⚠ La vue ne décide rien de ce qu'on peint : elle dit QUELLE case le rayon touche, et l'écran
## (`editor.gd`) applique le coup avec SON historique d'annulation.

signal coup_commence
signal case_touchee(case: Vector3i, poser: bool)
signal coup_fini

const Massif := preload("res://addons/undermend/massif_peint.gd")

var _vue: SubViewport
var _camera: Camera3D
var _cible := Vector3(6, 4, 6)
var _azimut := 0.7
var _elevation := 0.55
var _distance := 26.0

var _temoin: MeshInstance3D
var _monde: Node3D
var _grille: MeshInstance3D
var _fantome: MeshInstance3D

## "temoin" ou "monde".
var mode := "temoin"
var etage := 0

var _coup := -1          # le bouton qui peint, -1 hors d'un coup
var _derniere := Vector3i(1 << 20, 0, 0)


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vue = SubViewport.new()
	_vue.own_world_3d = true
	_vue.msaa_3d = Viewport.MSAA_4X
	add_child(_vue)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#101216")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8892a4")
	env.ambient_light_energy = 0.8
	var monde_env := WorldEnvironment.new()
	monde_env.environment = env
	_vue.add_child(monde_env)

	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-48, -34, 0)
	soleil.light_energy = 1.15
	soleil.shadow_enabled = true
	_vue.add_child(soleil)

	_temoin = MeshInstance3D.new()
	_vue.add_child(_temoin)

	_monde = Massif.new()
	_monde.name = "MondeDeTest"
	_monde.preparer()
	# ⚠ LA GRILLE DES CASES NE SE MONTRE PAS : elle porte la palette de peinture (des cubes), et c'est
	# le RENDU — les tuiles tranchées — qu'on veut voir. Les fautes, elles, restent visibles : un cube
	# rouge est précisément ce qu'on doit voir.
	(_monde.get_node("Cases") as Node3D).visible = false
	_vue.add_child(_monde)

	_grille = MeshInstance3D.new()
	_grille.mesh = _maillage_grille()
	_vue.add_child(_grille)

	_fantome = MeshInstance3D.new()
	var boite := BoxMesh.new()
	boite.size = Vector3.ONE * 1.02
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.706, 0.741, 0.522, 0.35)
	boite.material = m
	_fantome.mesh = boite
	_fantome.visible = false
	_vue.add_child(_fantome)

	_camera = Camera3D.new()
	_camera.fov = 45
	_vue.add_child(_camera)
	_caler()
	montrer(mode)


# ── ce qu'on montre ──────────────────────────────────────────────────────────────────────────────────

func montrer(quoi: String) -> void:
	mode = quoi
	_temoin.visible = quoi == "temoin"
	_monde.visible = quoi == "monde"
	_grille.visible = quoi == "monde"
	_fantome.visible = false
	_placer_grille()


func montrer_maillage(mesh: Mesh, surcharge: Material) -> void:
	_temoin.mesh = mesh
	_temoin.material_override = surcharge


func monde() -> Node:
	return _monde


func cases() -> GridMap:
	return _monde.get_node("Cases") as GridMap


func regler_etage(y: int) -> void:
	etage = y
	_placer_grille()


# ── la caméra ────────────────────────────────────────────────────────────────────────────────────────

func _caler() -> void:
	var direction := Vector3(cos(_elevation) * sin(_azimut), sin(_elevation),
		cos(_elevation) * cos(_azimut))
	_camera.look_at_from_position(_cible + direction * _distance, _cible, Vector3.UP)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(4.0, _distance / 1.12)
			_caler()
			accept_event()
			return
		if b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(120.0, _distance * 1.12)
			_caler()
			accept_event()
			return
		if mode == "monde" and (b.button_index == MOUSE_BUTTON_LEFT or b.button_index == MOUSE_BUTTON_RIGHT):
			if b.pressed and _coup < 0:
				_coup = b.button_index
				_derniere = Vector3i(1 << 20, 0, 0)
				coup_commence.emit()
				_toucher(b.position)
			elif not b.pressed and b.button_index == _coup:
				_coup = -1
				coup_fini.emit()
			accept_event()
			return
	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		# ⚠ Clic du milieu = tourner, Maj + milieu = glisser — les réflexes de Blender, puisque c'est
		# de là que vient l'artiste. Dans le témoin, le clic gauche tourne aussi : il n'y a rien à peindre.
		var tourne: bool = (m.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0 \
			or (mode == "temoin" and (m.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0)
		if tourne and m.shift_pressed:
			var droite: Vector3 = _camera.global_transform.basis.x
			var haut: Vector3 = _camera.global_transform.basis.y
			_cible += (-droite * m.relative.x + haut * m.relative.y) * _distance * 0.0016
			_caler()
			accept_event()
			return
		if tourne:
			_azimut -= m.relative.x * 0.01
			_elevation = clampf(_elevation + m.relative.y * 0.01, -1.4, 1.4)
			_caler()
			accept_event()
			return
		if mode == "monde":
			_survoler(m.position)
			if _coup >= 0:
				_toucher(m.position)


# ── le pinceau ───────────────────────────────────────────────────────────────────────────────────────

## La case que le rayon touche sur le plan de l'étage, ou `null`.
## ⚠ La case `p` occupe `[p, p+1]` (charte §2) : on coupe le plan y = étage et on prend le PLANCHER,
## jamais un arrondi — un arrondi décalerait d'une demi-case tout ce qu'on peint.
func case_sous(position: Vector2) -> Variant:
	var origine: Vector3 = _camera.project_ray_origin(position)
	var sens: Vector3 = _camera.project_ray_normal(position)
	if absf(sens.y) < 0.0001:
		return null
	var t: float = (float(etage) - origine.y) / sens.y
	if t <= 0.0:
		return null
	var p: Vector3 = origine + sens * t
	return Vector3i(floori(p.x), etage, floori(p.z))


func _survoler(position: Vector2) -> void:
	var c = case_sous(position)
	_fantome.visible = c != null
	if c != null:
		_fantome.position = Vector3(c) + Vector3.ONE * 0.5


func _toucher(position: Vector2) -> void:
	var c = case_sous(position)
	if c == null or c == _derniere:
		return
	_derniere = c
	case_touchee.emit(c, _coup == MOUSE_BUTTON_LEFT)


# ── la grille de l'étage ─────────────────────────────────────────────────────────────────────────────

const DEMI_GRILLE := 24


func _maillage_grille() -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.706, 0.741, 0.522, 0.18)
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, m)
	for i in range(-DEMI_GRILLE, DEMI_GRILLE + 1):
		mesh.surface_add_vertex(Vector3(i, 0, -DEMI_GRILLE))
		mesh.surface_add_vertex(Vector3(i, 0, DEMI_GRILLE))
		mesh.surface_add_vertex(Vector3(-DEMI_GRILLE, 0, i))
		mesh.surface_add_vertex(Vector3(DEMI_GRILLE, 0, i))
	mesh.surface_end()
	return mesh


func _placer_grille() -> void:
	if _grille != null:
		_grille.position = Vector3(0, etage + 0.002, 0)
