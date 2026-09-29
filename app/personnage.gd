extends CharacterBody3D
## LE PERSONNAGE DE PLAY TEST — DEMANDÉ PAR JORDAN (29 septembre 2026) : « un stickman funkopop tout
## noir avec des yeux violets luminescents et un outline violet de la même couleur, animé en 3D ».
##
## Il sert à une seule chose : MARCHER dans le monde peint, à l'échelle d'un joueur, pour juger ce
## qu'aucune vue orbitale ne dit — une marche trop haute, un tunnel trop bas, une arche qu'on ne passe
## pas. Il ne change aucune case.
##
## ⚠ **TOUT EST BÂTI ICI, EN PRIMITIVES, SANS FICHIER.** Aucun modèle emprunté (le logiciel est vendu,
## même raison que pour les icônes), et rien à importer : le personnage existe dès que l'appli existe.
## ⚠ **L'ANIMATION EST PROCÉDURALE** : des pivots (épaules, hanches, cou) tournés par des sinus. Une
## `AnimationPlayer` figerait des clés qu'on devrait fondre à la main entre marche, course et saut ;
## ici chaque pose est une fonction de la vitesse, donc les transitions sont continues par construction.
## ⚠ **IL NE LIT PAS LE CLAVIER LUI-MÊME** : la vue lui passe `entree` (x à droite, y en avant, dans le
## repère de la CAMÉRA), `saut` et `course`. C'est ce qui le rend menable sans clavier dans la fumée.

## La couleur des yeux ET du contour — une seule constante, puisque c'est « la même couleur ».
const VIOLET := Color("#b23cff")
const NOIR := Color("#08080b")

## En cases (1 unité = 1 case). ⚠ **PLUS PETIT QU'UNE CASE** : un tunnel d'une case doit se traverser.
const ECHELLE := 0.62
## ⚠ LA CAPSULE ENVELOPPE LA SILHOUETTE : la tête culmine à 1,36 × ECHELLE = 0,84, et fait 0,20 de
## rayon. Plus petite, la tête traverserait les plafonds qu'on veut précisément éprouver.
const RAYON := 0.19
const HAUTEUR := 0.84
const VITESSE_MARCHE := 3.2
const VITESSE_COURSE := 5.6
const GRAVITE := 22.0
## ⚠ **LE SAUT FRANCHIT UNE CASE ET DEMIE**, pas une : sauter exactement une case laisse le pied au
## ras de l'arête, et un monde en cases est fait de marches d'une case.
const HAUTEUR_DE_SAUT := 1.45
## La marche que le pas gravit sans sauter. ⚠ L'aminci taille des marches d'un QUART de case (charte
## §4) : sans ce pas, le personnage butait sur chaque bord de dalle.
const MARCHE := 0.3
## Le temps de grâce : on peut encore sauter juste après avoir quitté le bord.
const GRACE := 0.12

var entree := Vector2.ZERO
var saut := false
var course := false
## Le cap de la caméra (radians autour de +Y) : « en avant » est l'avant de la CAMÉRA, aplati.
var cap_camera := 0.0

var _modele: Node3D
var _tete: Node3D
var _torse: Node3D
var _epaule_g: Node3D
var _epaule_d: Node3D
var _hanche_g: Node3D
var _hanche_d: Node3D
var _phase := 0.0
var _en_l_air := 0.0
var _depuis_le_sol := 0.0
var _saut_tenu := false
var _ecrasement := 0.0
var _cap := 0.0


func _init() -> void:
	name = "Personnage"
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.25
	# ⚠ SEUL LE DÉCOR DE PLAY TEST LE PORTE (couche 2) : les grilles de la vue gardent leurs boîtes de
	# collision par case (couche 1), qui ne suivent pas la surface visible — l'aminci est un quart de
	# case en retrait, et l'on marcherait au-dessus du sol qu'on voit.
	collision_layer = 0
	collision_mask = 2
	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RAYON
	capsule.height = HAUTEUR
	forme.shape = capsule
	forme.position.y = HAUTEUR * 0.5
	add_child(forme)
	_batir_le_modele()


# ── LE CORPS ────────────────────────────────────────────────────────────────────────────────────────
#
# Un Funko Pop : une TÊTE énorme (presque la moitié de la hauteur), un corps de bâton. Tout est noir ;
# les yeux sont deux amandes violettes qui ÉMETTENT (l'environnement de Play test active le halo), et
# chaque pièce du corps porte une seconde passe : la coque inversée, grossie, violette — le contour.

func _batir_le_modele() -> void:
	var corps := _matiere_du_corps()
	_modele = Node3D.new()
	_modele.scale = Vector3.ONE * ECHELLE
	add_child(_modele)

	_torse = Node3D.new()
	_torse.position.y = 0.46
	_modele.add_child(_torse)
	_torse.add_child(_capsule(0.085, 0.36, Vector3(0, 0.1, 0), corps))

	# Les jambes pendent de hanches posées sous le torse.
	_hanche_g = _pivot(_modele, Vector3(-0.075, 0.46, 0))
	_hanche_d = _pivot(_modele, Vector3(0.075, 0.46, 0))
	for h in [_hanche_g, _hanche_d]:
		h.add_child(_capsule(0.045, 0.46, Vector3(0, -0.23, 0), corps))
		h.add_child(_sphere(0.06, Vector3(0, -0.45, -0.02), corps, Vector3(1, 0.7, 1.4)))

	_epaule_g = _pivot(_torse, Vector3(-0.12, 0.25, 0))
	_epaule_d = _pivot(_torse, Vector3(0.12, 0.25, 0))
	for e in [_epaule_g, _epaule_d]:
		e.add_child(_capsule(0.038, 0.36, Vector3(0, -0.17, 0), corps))
		e.add_child(_sphere(0.05, Vector3(0, -0.36, 0), corps))

	# LA TÊTE : large, un peu écrasée, portée par un cou court.
	_tete = _pivot(_torse, Vector3(0, 0.32, 0))
	_tete.add_child(_capsule(0.04, 0.12, Vector3(0, 0.03, 0), corps))
	_tete.add_child(_sphere(0.3, Vector3(0, 0.3, 0), corps, Vector3(1.08, 0.94, 1.0)))
	var yeux := StandardMaterial3D.new()
	yeux.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	yeux.albedo_color = VIOLET
	yeux.emission_enabled = true
	yeux.emission = VIOLET
	yeux.emission_energy_multiplier = 4.0
	# ⚠ −Z EST L'AVANT (la convention de Godot) : c'est vers là que `_orienter` tourne le modèle.
	for x in [-0.115, 0.115]:
		var oeil := _sphere(0.06, Vector3(x, 0.3, -0.262), yeux, Vector3(0.95, 1.25, 0.45))
		oeil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_tete.add_child(oeil)


func _matiere_du_corps() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = NOIR
	m.roughness = 0.45
	m.metallic_specular = 0.6
	# LE CONTOUR : la coque inversée. On dessine la même pièce grossie, vue de DERRIÈRE seulement
	# (`CULL_FRONT`), sans lumière : seul son liseré dépasse de la silhouette.
	var contour := StandardMaterial3D.new()
	contour.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	contour.cull_mode = BaseMaterial3D.CULL_FRONT
	contour.grow = true
	contour.grow_amount = 0.022
	contour.albedo_color = VIOLET
	# ⚠ Un peu d'émission : le contour doit rester VIOLET à l'ombre, comme les yeux.
	contour.emission_enabled = true
	contour.emission = VIOLET
	contour.emission_energy_multiplier = 1.4
	m.next_pass = contour
	return m


func _pivot(parent: Node3D, ou: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = ou
	parent.add_child(p)
	return p


func _capsule(rayon: float, hauteur: float, ou: Vector3, m: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = rayon
	mesh.height = hauteur
	mesh.radial_segments = 16
	mesh.rings = 6
	var i := MeshInstance3D.new()
	i.mesh = mesh
	i.position = ou
	i.material_override = m
	return i


func _sphere(rayon: float, ou: Vector3, m: Material, etirement := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = rayon
	mesh.height = rayon * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	var i := MeshInstance3D.new()
	i.mesh = mesh
	i.position = ou
	i.scale = etirement
	i.material_override = m
	return i


# ── LE MOUVEMENT ────────────────────────────────────────────────────────────────────────────────────

func _physics_process(dt: float) -> void:
	var avant := Vector3(-sin(cap_camera), 0.0, -cos(cap_camera))
	var droite := Vector3(-avant.z, 0.0, avant.x)
	var voulu := droite * entree.x + avant * entree.y
	if voulu.length_squared() > 1.0:
		voulu = voulu.normalized()
	var vitesse := VITESSE_COURSE if course else VITESSE_MARCHE
	# Une inertie courte : on démarre et on s'arrête vite, mais pas au pixel près.
	var reactivite := 14.0 if is_on_floor() else 4.0
	var plan := Vector3(velocity.x, 0.0, velocity.z).lerp(voulu * vitesse, minf(1.0, reactivite * dt))
	velocity.x = plan.x
	velocity.z = plan.z

	if is_on_floor():
		_depuis_le_sol = 0.0
	else:
		_depuis_le_sol += dt
		velocity.y -= GRAVITE * dt
	# ⚠ UN SAUT PAR APPUI : tenir Espace ne fait pas rebondir.
	if saut and not _saut_tenu and _depuis_le_sol <= GRACE:
		velocity.y = sqrt(2.0 * GRAVITE * HAUTEUR_DE_SAUT)
		_depuis_le_sol = GRACE + 1.0
		floor_snap_length = 0.0
	_saut_tenu = saut
	if velocity.y <= 0.0:
		floor_snap_length = 0.25

	var avant_le_pas := global_position
	var etait_en_l_air := not is_on_floor()
	move_and_slide()
	if is_on_floor() and is_on_wall() and voulu.length_squared() > 0.01:
		_gravir(voulu * vitesse * dt, avant_le_pas)
	if etait_en_l_air and is_on_floor() and _en_l_air > 0.18:
		_ecrasement = clampf(_en_l_air * 0.6, 0.08, 0.3)
	_en_l_air = 0.0 if is_on_floor() else _en_l_air + dt
	_orienter(voulu, dt)
	_animer(dt)


## LE PAS : buté contre une paroi plus basse que `MARCHE`, on monte dessus au lieu de s'arrêter.
## Trois essais de mouvement, jamais un déplacement à l'aveugle : monter, avancer là-haut, redescendre.
func _gravir(pas: Vector3, depart: Vector3) -> void:
	var t := global_transform
	t.origin = depart
	var haut := Vector3.UP * MARCHE
	if test_move(t, haut):
		return
	t.origin += haut
	var loin := pas.normalized() * maxf(pas.length(), RAYON * 0.6)
	if test_move(t, loin):
		return
	t.origin += loin
	var chute := KinematicCollision3D.new()
	if not test_move(t, -haut, chute):
		return
	global_position = t.origin + chute.get_travel()


func _orienter(voulu: Vector3, dt: float) -> void:
	if voulu.length_squared() > 0.01:
		_cap = lerp_angle(_cap, atan2(-voulu.x, -voulu.z), minf(1.0, 12.0 * dt))
	_modele.rotation.y = _cap


# ── L'ANIMATION ─────────────────────────────────────────────────────────────────────────────────────
#
# Trois poses fondues entre elles par la vitesse et le sol : REPOS (il respire, les bras se balancent à
# peine), MARCHE / COURSE (bras et jambes en opposition, le corps rebondit et se penche), EN L'AIR (bras
# levés, une jambe repliée). À l'atterrissage, la grosse tête S'ÉCRASE un instant — le geste du jouet.

func _animer(dt: float) -> void:
	var v := Vector2(velocity.x, velocity.z).length()
	var allure := clampf(v / VITESSE_COURSE, 0.0, 1.0)
	var au_sol := is_on_floor()
	_phase += dt * (2.5 + v * 3.2)
	var s := sin(_phase)
	var temps := Time.get_ticks_msec() * 0.001

	var jambe := s * 0.95 * allure
	var bras := -s * 0.85 * allure
	var bras_ecart := 0.08 + 0.04 * sin(temps * 1.7) * (1.0 - allure)
	var penche := 0.18 * allure
	var rebond := absf(cos(_phase)) * 0.05 * allure
	var souffle := sin(temps * 2.2) * 0.012 * (1.0 - allure)
	if not au_sol:
		var monte := clampf(velocity.y / 6.0, -1.0, 1.0)
		jambe = 0.6
		bras = -0.4
		bras_ecart = 1.1 + 0.4 * monte
		penche = 0.05
		rebond = 0.0

	var k := minf(1.0, 16.0 * dt)
	_hanche_g.rotation.x = lerpf(_hanche_g.rotation.x, jambe, k)
	_hanche_d.rotation.x = lerpf(_hanche_d.rotation.x, -jambe if au_sol else -0.25, k)
	_epaule_g.rotation.x = lerpf(_epaule_g.rotation.x, bras, k)
	_epaule_d.rotation.x = lerpf(_epaule_d.rotation.x, -bras, k)
	_epaule_g.rotation.z = lerpf(_epaule_g.rotation.z, -bras_ecart, k)
	_epaule_d.rotation.z = lerpf(_epaule_d.rotation.z, bras_ecart, k)
	_torse.rotation.x = lerpf(_torse.rotation.x, -penche, k)
	_torse.position.y = 0.46 + rebond + souffle
	# La tête compense la moitié du penché et hoche au rythme du pas : elle regarde où l'on va.
	_tete.rotation.x = lerpf(_tete.rotation.x, penche * 0.5 + sin(_phase * 2.0) * 0.04 * allure, k)
	_tete.rotation.z = lerpf(_tete.rotation.z, sin(temps * 0.9) * 0.05 * (1.0 - allure), k)

	_ecrasement = move_toward(_ecrasement, 0.0, dt * 1.6)
	_modele.scale = Vector3(ECHELLE * (1.0 + _ecrasement * 0.6), ECHELLE * (1.0 - _ecrasement),
		ECHELLE * (1.0 + _ecrasement * 0.6))
