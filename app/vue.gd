extends SubViewportContainer
## LA VUE 3D — ce que SoluTiles dessinait à plat dans son canevas, ici dans un monde en trois dimensions.
##
## Deux choses à montrer, jamais en même temps :
##   • le TÉMOIN (ou le travail importé) — ce que l'artiste sculpte, qu'on fait tourner ;
##   • le MONDE (« World », ex-« Test world ») — un `MassifPeint` réel, qu'on peint case par case avec
##     le lot tranché ;
##   • et, par-dessus le monde, le PLAY TEST (`mode == "jeu"`) : le même monde, sans pinceau, où l'on
##     marche avec un personnage (`personnage.gd`).
##
## ⚠ **LE PINCEAU EST ICI PARCE QUE L'ÉDITEUR GODOT N'EST PLUS LÀ.** Le greffon s'appuyait sur le
## pinceau natif du GridMap ; un logiciel autonome doit écrire le sien. C'est la « sélection maison »
## de la charte §5 : en 3D un clic est un RAYON, et on le coupe contre le plan de l'ÉTAGE courant — ce
## que fait l'éditeur natif avec son niveau de sol.
##
## ⚠ La vue ne décide rien de ce qu'on peint : elle dit QUELLE case le rayon touche, et l'écran
## (`editor.gd`) applique le coup avec SON historique d'annulation.

signal coup_commence
## Ce qu'un coup CHANGE aux cases de la couche active : {"poser", "effacer"} (`Outils.modification`).
signal touche(modif: Dictionary, nom: String)
signal coup_fini
signal selection_changee
## Le clic qui pose le presse-papiers : l'ancre, contre la face visée comme une case qu'on ajoute.
signal colle(ancre: Vector3i)
## Une boîte au-delà de `Outils.VOLUME_MAXI` cases rend vide : l'écran doit le DIRE, sinon le glissé
## semble ne rien faire.
signal boite_trop_grande

const Massif := preload("res://addons/marchingblocks_core/massif_peint.gd")
const Outils := preload("res://addons/marchingblocks_core/outils.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const Personnage := preload("res://app/personnage.gd")

## Jusqu'où porte le rayon de sculpture, en cases.
const PORTEE := 400.0
const TEINTE_AJOUTER := Color(0.55, 0.82, 0.45, 0.32)
const TEINTE_CREUSER := Color(0.9, 0.38, 0.24, 0.36)
const TEINTE_SELECTIONNER := Color(0.42, 0.62, 0.98, 0.3)
const TEINTE_SELECTION := Color(0.42, 0.62, 0.98, 0.22)
const TEINTE_BOITE := Color(0.42, 0.62, 0.98, 0.1)

var _vue: SubViewport
var _camera: Camera3D
var _cible := Vector3(6, 4, 6)
var _azimut := 0.7
var _elevation := 0.55
var _distance := 26.0

var _temoin: MeshInstance3D
## LES PLANS DE COUPE du témoin — là où le trancheur coupe. Montrés à la demande (« Show the cells »).
var _plans_de_coupe: MeshInstance3D
var _plans_voulus := false
## Un `MassifPeint` par COUCHE du monde (`projet.gd`). On peint sur la couche ACTIVE ; les autres restent
## visibles, chacune rendue avec SON lot et selon SES cases seulement.
var _couches: Node3D
var _active := -1
var _grille: MeshInstance3D
## La grille LOCALE : un morceau de grille qui suit le curseur quand il sort de la grille centrale —
## sans elle, on peint à l'aveugle dès qu'on s'éloigne du centre du monde.
var _grille_locale: MeshInstance3D
## L'APERÇU : les cases EXACTES que le prochain clic changera, avant qu'on clique.
var _apercu: MultiMeshInstance3D
var _selection_vue: MultiMeshInstance3D

## LA BARRE D'OUTILS (charte §5, plan du 27 septembre 2026). La visée dit comment trouver le point :
## "grille" (le plan de l'étage) ou "sculpt" (la matière). L'outil dit ce qu'on en fait.
## **LA NAVIGATION N'EST PLUS UNE VISÉE — DÉCIDÉ PAR JORDAN (29 septembre 2026).** Elle était la
## troisième visée du cycle de Tab (28 septembre) ; elle en sort. Tab alterne Grid et Sculpt, qui
## restent ensemble, et la navigation est un INTERRUPTEUR à part, basculé par Espace : on vole, on
## revient, et la visée d'avant est toujours là. Elle ne vise RIEN : aucun clic ne peint.
const VISEES := ["grille", "sculpt"]
## Vrai pendant qu'on vole (AZEQSD, clic droit pour regarder).
var naviguer := false
## Cases par seconde. ⚠ Proportionnelle à la distance d'orbite : de près on ajuste, de loin on traverse.
const VITESSE_DE_VOL := 0.6
var visee := "grille"
var outil := "ajouter"
var taille := 1
var forme := "sphere"
## ⚠ **HOLLOW NE VAUT QUE POUR LA BOÎTE 3D.** Un rectangle du plan n'a pas de dedans : l'évidemment
## d'une boîte de moins de trois cases d'épaisseur la laisse pleine (`Outils.volume_de_la_boite`).
var creux := false
## La SÉLECTION — des cases de la couche active. ⚠ Un état d'écran, pas une donnée : elle n'est ni
## enregistrée ni annulable, et se vide quand on change de couche.
var selection := {}
## LE COLLAGE EN COURS — le presse-papiers (décalages relatifs, `Outils.copier`) qui suit la souris
## jusqu'au clic. Vide hors d'un collage.
var collage: Array = []

## "temoin", "monde" ou "jeu".
var mode := "temoin"
var etage := 0

var _coup := -1          # le bouton qui peint, -1 hors d'un coup
var _derniere := ""
## Le verrou de coup : ce qu'un coup d'AJOUT a posé, que son rayon traverse (`Outils.rayon`).
var _pose_du_coup := {}
var _derniere_souris := Vector2(-1, -1)
## La boîte en cours de tracé : ses deux coins, et si Maj était tenue au départ.
var _coin_boite: Variant = null
var _coin_fin: Variant = null
var _maj_du_coup := false
var _boite_vue: MeshInstance3D

## ── LE PLAY TEST ──
var _env: Environment
var personnage: CharacterBody3D
## Le décor qu'il foule : la SURFACE RENDUE des tuiles, pas les boîtes par case des grilles.
var _decor: StaticBody3D
var _depart := Vector3.ZERO
var _plus_bas := 0.0
## L'orbite d'avant le Play test, rendue à la sortie : on retrouve le monde tel qu'on l'avait laissé.
var _orbite_d_avant: Array = []
## La longueur actuelle du bras-ressort (≤ `_distance`).
var _bras := 0.0


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Un clic dans la vue lui donne le clavier : Espace ne doit plus « cliquer » le dernier bouton.
	focus_mode = Control.FOCUS_CLICK
	_vue = SubViewport.new()
	_vue.own_world_3d = true
	_vue.msaa_3d = Viewport.MSAA_4X
	add_child(_vue)

	var env := Environment.new()
	_env = env
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
	_plans_de_coupe = MeshInstance3D.new()
	_plans_de_coupe.mesh = _maillage_plans_de_coupe(BM.COTE)
	_plans_de_coupe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_plans_de_coupe.visible = false
	_vue.add_child(_plans_de_coupe)

	_couches = Node3D.new()
	_couches.name = "MondeDeTest"
	_vue.add_child(_couches)

	_grille = MeshInstance3D.new()
	_grille.mesh = _maillage_grille()
	_vue.add_child(_grille)

	_grille_locale = MeshInstance3D.new()
	_grille_locale.mesh = _maillage_grille_locale()
	_grille_locale.visible = false
	_vue.add_child(_grille_locale)

	_apercu = _nuage_de_cases(1.03)
	_selection_vue = _nuage_de_cases(1.01)
	_boite_vue = MeshInstance3D.new()
	var boite := BoxMesh.new()
	var mb := StandardMaterial3D.new()
	mb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mb.cull_mode = BaseMaterial3D.CULL_DISABLED
	mb.albedo_color = TEINTE_BOITE
	boite.material = mb
	_boite_vue.mesh = boite
	_boite_vue.visible = false
	_vue.add_child(_boite_vue)

	_camera = Camera3D.new()
	_camera.fov = 45
	_vue.add_child(_camera)
	_caler()
	montrer(mode)


# ── ce qu'on montre ──────────────────────────────────────────────────────────────────────────────────

func montrer(quoi: String) -> void:
	mode = quoi
	_temoin.visible = quoi == "temoin"
	_plans_de_coupe.visible = quoi == "temoin" and _plans_voulus
	_couches.visible = quoi == "monde" or quoi == "jeu"
	_grille.visible = quoi == "monde"
	_apercu.visible = false
	_grille_locale.visible = false
	if _boite_vue != null:
		_boite_vue.visible = false
	_dessiner_selection()
	_placer_grille()


func montrer_plans_de_coupe(oui: bool) -> void:
	_plans_voulus = oui
	_plans_de_coupe.visible = mode == "temoin" and oui


## LES PLANS DE COUPE : le trancheur coupe par les CENTRES des cases, sur les trois axes (charte §2) —
## la case `p` occupe `[p, p+1]`, donc les plans sont en `p + ½`, de 0 à COTE − 1 sur chaque axe, et
## couvrent tout le bloc [0, COTE]³. Un voile très léger, et son contour un peu plus net : on doit voir
## à travers, c'est l'art qui compte. ⚠ **L'ALPHA S'EMPILE** : on regarde à travers douze plans par axe,
## et 0,055 chacun noyait le bloc dans un brouillard vert (vu à l'image). 0,018 laisse lire la matière.
## ⚠ `CULL_DISABLED` : un plan se regarde des deux côtés. ⚠ Aucune ombre : un voile qui ombrerait le
## témoin changerait ce qu'on juge.
static func _maillage_plans_de_coupe(cote: int) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var voile := StandardMaterial3D.new()
	voile.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	voile.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	voile.cull_mode = BaseMaterial3D.CULL_DISABLED
	voile.albedo_color = Color(0.706, 0.741, 0.522, 0.018)
	var contour := StandardMaterial3D.new()
	contour.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	contour.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	contour.albedo_color = Color(0.706, 0.741, 0.522, 0.22)
	var n := float(cote)
	var coins: Array = []
	for axe in 3:
		for k in cote:
			var c := float(k) + 0.5
			var q: Array = []
			for uv in [Vector2(0, 0), Vector2(n, 0), Vector2(n, n), Vector2(0, n)]:
				var p := Vector3.ZERO
				p[axe] = c
				p[(axe + 1) % 3] = uv.x
				p[(axe + 2) % 3] = uv.y
				q.append(p)
			coins.append(q)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, voile)
	for q in coins:
		for i in [0, 1, 2, 0, 2, 3]:
			mesh.surface_add_vertex(q[i])
	mesh.surface_end()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, contour)
	for q in coins:
		for i in 4:
			mesh.surface_add_vertex(q[i])
			mesh.surface_add_vertex(q[(i + 1) % 4])
	mesh.surface_end()
	return mesh


func montrer_maillage(mesh: Mesh, surcharge: Material) -> void:
	_temoin.mesh = mesh
	_temoin.material_override = surcharge


## La couche ACTIVE — celle que le pinceau touche.
func monde() -> Node:
	return couche(_active)


func couche(i: int) -> Node:
	if i < 0 or i >= _couches.get_child_count():
		return null
	return _couches.get_child(i)


func cases() -> GridMap:
	var m := monde()
	return m.get_node("Cases") as GridMap if m != null else null


func nombre_de_couches() -> int:
	return _couches.get_child_count()


func ajouter_couche() -> Node:
	var massif := Massif.new()
	massif.name = "Couche"
	massif.preparer()
	# ⚠ LA GRILLE DES CASES NE SE MONTRE PAS : elle porte la palette de peinture (des cubes), et c'est
	# le RENDU — les tuiles tranchées — qu'on veut voir. Les fautes, elles, restent visibles : un cube
	# rouge est précisément ce qu'on doit voir.
	(massif.get_node("Cases") as Node3D).visible = false
	_couches.add_child(massif)
	return massif


## Sort une couche de la vue SANS la détruire : l'historique peut la rendre (`inserer_couche`).
func detacher_couche(m: Node) -> void:
	_couches.remove_child(m)
	_active = mini(_active, _couches.get_child_count() - 1)


func inserer_couche(m: Node, i: int) -> void:
	_couches.add_child(m)
	_couches.move_child(m, clampi(i, 0, _couches.get_child_count() - 1))


## ⚠ `free()` ET NON `queue_free()` : les couches du projet suivant se posent DANS LA MÊME IMAGE, et
## une couche en sursis garderait son indice d'ici là.
func vider_couches() -> void:
	while _couches.get_child_count() > 0:
		var m := _couches.get_child(0)
		_couches.remove_child(m)
		m.free()
	_active = -1


func activer(i: int) -> void:
	_active = clampi(i, -1, _couches.get_child_count() - 1)
	vider_selection()


func regler_etage(y: int) -> void:
	etage = y
	_placer_grille()


# ── la caméra ────────────────────────────────────────────────────────────────────────────────────────

func _caler() -> void:
	var direction := Vector3(cos(_elevation) * sin(_azimut), sin(_elevation),
		cos(_elevation) * cos(_azimut))
	_camera.look_at_from_position(_cible + direction * _distance, _cible, Vector3.UP)


## LA NAVIGATION — la caméra VOLE au lieu d'orbiter.
##
## ⚠ **ON GARDE LE MODÈLE D'ORBITE** (cible, azimut, élévation, distance) et on déplace la CIBLE : la
## caméra reste à `distance` devant elle. Regarder autour de soi fait donc pivoter la cible autour de la
## caméra, pas l'inverse — sinon l'œil tournerait autour d'un point invisible, ce qui est l'orbite et
## non le regard. Et repasser en Grid ou Sculpt retrouve une orbite cohérente, sans saut.
func regarder(relatif: Vector2) -> void:
	var oeil := _camera.global_position
	_azimut -= relatif.x * 0.005
	_elevation = clampf(_elevation + relatif.y * 0.005, -1.4, 1.4)
	var direction := Vector3(cos(_elevation) * sin(_azimut), sin(_elevation), cos(_elevation) * cos(_azimut))
	_cible = oeil - direction * _distance
	_caler()


## `axes` : x à droite, y en haut, z en AVANT. ⚠ Avancer reste À PLAT : on vise le sol en marchant,
## et A / E (AZERTY ; Q / E en QWERTY) portent seuls la hauteur — sinon regarder vers le bas enfoncerait dans le terrain.
func voler(axes: Vector3, dt: float) -> void:
	if axes == Vector3.ZERO:
		return
	var avant := -_camera.global_transform.basis.z
	avant.y = 0.0
	avant = avant.normalized() if avant.length_squared() > 1e-6 else Vector3(-sin(_azimut), 0, -cos(_azimut))
	var droite := Vector3(-avant.z, 0.0, avant.x)
	var pas := (droite * axes.x + Vector3.UP * axes.y + avant * axes.z).normalized()
	_cible += pas * VITESSE_DE_VOL * maxf(_distance, 4.0) * dt
	_caler()


## ⚠ **LES TOUCHES SE LISENT PAR LEUR PLACE, PAS PAR LEUR LETTRE** (`physical_keycode`) : ZQSD sur
## un clavier AZERTY, WASD sur un QWERTY — le même geste de la main gauche. Lire les lettres aurait
## donné un clavier sur deux à l'envers. AZEQSD en AZERTY = QWEASD en QWERTY : Z S avancent et
## reculent, Q D vont de côté, A descend, E monte — et Espace, qui montait, sert désormais à basculer.
## ⚠ Un champ de texte qui a la main garde ses touches : on tape le nom d'une couche avec des Z et des S.
func _process(dt: float) -> void:
	if mode == "jeu":
		_mener_le_jeu()
		return
	if not naviguer or mode != "monde" or not is_visible_in_tree():
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	var axes := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		axes.z += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		axes.z -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		axes.x += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		axes.x -= 1.0
	if Input.is_physical_key_pressed(KEY_E):
		axes.y += 1.0
	if Input.is_physical_key_pressed(KEY_Q):
		axes.y -= 1.0
	voler(axes, dt)


func _gui_input(event: InputEvent) -> void:
	# ⚠ LA SOURIS SEULEMENT : la vue a le clavier en Play test, et avaler ses touches ici priverait
	# l'écran d'Échap et de Retour arrière.
	if mode == "jeu" and event is InputEventMouse:
		_souris_du_jeu(event)
		accept_event()
		return
	if naviguer and mode == "monde" and _naviguer(event):
		accept_event()
		return
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
				_commencer_coup(b.button_index, b.position, b.shift_pressed)
			elif not b.pressed and b.button_index == _coup:
				_coup = -1
				_pose_du_coup = {}
				if _coin_boite != null:
					_finir_boite(b.button_index)
				else:
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


## En Navigate, la souris ne peint pas : le clic droit glissé regarde, la molette et le clic du
## milieu gardent leur rôle (zoom, orbite). Rend vrai quand l'événement est pris.
func _naviguer(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		return b.button_index == MOUSE_BUTTON_LEFT or b.button_index == MOUSE_BUTTON_RIGHT
	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		if (m.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
			regarder(m.relative)
			return true
	return false


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


## LE POINT VISÉ : {"touche", "case", "normale"}, ou {} si rien.
## ⚠ En sculpture, un rayon qui ne touche aucune matière retombe sur le plan de l'étage : sans ça, on ne
## pourrait jamais poser la première case d'un monde vide.
## ⚠ AJOUTER voit toutes les couches VISIBLES — on pose de l'herbe sur la roche d'une autre couche ;
## creuser et sélectionner ne voient que la couche ACTIVE, la seule qu'ils peuvent changer.
func point_vise(position: Vector2, geste: String) -> Dictionary:
	if visee == "sculpt":
		var occupe: Callable = _occupe_visible if geste == "ajouter" else _occupe_actif
		var r: Dictionary = Outils.rayon(occupe, _camera.project_ray_origin(position),
			_camera.project_ray_normal(position), PORTEE, _pose_du_coup)
		if r["touche"]:
			return r
	var c = case_sous(position)
	if c == null:
		return {}
	return {"touche": false, "case": c, "normale": Vector3i.ZERO}


## Les cases du pinceau sous la souris, pour ce geste.
func cibles(position: Vector2, geste: String) -> Array[Vector3i]:
	var point := point_vise(position, geste)
	if point.is_empty():
		return []
	return Outils.pinceau(Outils.ancre(geste, point), point["normale"], taille, forme)


## Le geste réel : le clic DROIT fait l'inverse — ajouter ↔ creuser, sélectionner → désélectionner.
func geste(bouton: int) -> String:
	if bouton != MOUSE_BUTTON_RIGHT:
		return outil
	match outil:
		"ajouter":
			return "creuser"
		"creuser":
			return "ajouter"
	return "deselectionner"


func _occupe_actif(c: Vector3i) -> bool:
	var g := cases()
	return g != null and g.get_cell_item(c) != -1


func _occupe_visible(c: Vector3i) -> bool:
	for m in _couches.get_children():
		if (m as Node3D).visible and (m.get_node("Cases") as GridMap).get_cell_item(c) != -1:
			return true
	return false


func _survoler(position: Vector2) -> void:
	_derniere_souris = position
	# ⚠ EN NAVIGATE, RIEN N'EST VISÉ, DONC RIEN N'EST PROMIS : un aperçu laissé à l'écran ferait croire
	# qu'un clic peindra.
	if naviguer:
		_apercu.visible = false
		_grille_locale.visible = false
		_boite_vue.visible = false
		return
	var g: String = geste(_coup) if _coup >= 0 else outil
	var point := point_vise(position, g)
	var plan = case_sous(position)
	# ⚠ La grille locale ne sert qu'à la visée de GRILLE : en sculpture, c'est la matière qui porte.
	_grille_locale.visible = visee == "grille" and plan != null and not sur_la_grille_centrale(plan)
	if plan != null:
		# ⚠ Calée sur les LIGNES de la grille, pas sur le centre de la case : la case `p` occupe
		# `[p, p+1]`, donc son coin est en `p` et ses lignes tombent sur des entiers.
		_grille_locale.position = Vector3(plan.x, etage + 0.002, plan.z)
	if not collage.is_empty():
		_survoler_collage(position)
		return
	if outil == "boite" or outil == "rect":
		_survoler_boite(position)
		return
	if point.is_empty() or cases() == null:
		_apercu.visible = false
		return
	var toutes := Outils.pinceau(Outils.ancre(g, point), point["normale"], taille, forme)
	# ⚠ L'APERÇU MONTRE CE QUI CHANGERA, pas le pinceau entier : une sphère de 33 cases dont 4 seulement
	# sont vides n'en posera que 4, et c'est ces 4 qu'il faut voir.
	var montrees: Array = []
	match g:
		"ajouter":
			montrees = Outils.modification("ajouter", toutes, _occupe_actif)["poser"].keys()
		"creuser":
			montrees = Outils.modification("creuser", toutes, _occupe_actif)["effacer"].keys()
		_:
			montrees = toutes.filter(_occupe_actif)
	var teinte: Color = {"ajouter": TEINTE_AJOUTER, "creuser": TEINTE_CREUSER}.get(g, TEINTE_SELECTIONNER)
	_remplir(_apercu, montrees, teinte)


## Une nouvelle case sous la souris pendant un coup : on applique le geste. `_derniere` évite de
## rejouer la même ancre à chaque pixel.
func _toucher(position: Vector2) -> void:
	if _coin_boite != null:
		_survoler_boite(position)
		return
	var g := geste(_coup)
	var point := point_vise(position, g)
	if point.is_empty() or cases() == null:
		return
	var cle := "%s|%s" % [Outils.ancre(g, point), point["normale"]]
	if cle == _derniere:
		return
	_derniere = cle
	var toutes := Outils.pinceau(Outils.ancre(g, point), point["normale"], taille, forme)
	match g:
		"selectionner", "deselectionner":
			for c in toutes:
				if g == "deselectionner":
					selection.erase(c)
				elif _occupe_actif(c):
					selection[c] = true
			_dessiner_selection()
			selection_changee.emit()
		_:
			var modif: Dictionary = Outils.modification(g, toutes, _occupe_actif)
			if g == "ajouter":
				for c in modif["poser"]:
					_pose_du_coup[c] = true
			if not modif["poser"].is_empty() or not modif["effacer"].is_empty():
				touche.emit(modif, "Add" if g == "ajouter" else "Dig")
	_survoler(position)


func _commencer_coup(bouton: int, position: Vector2, maj: bool) -> void:
	# ⚠ UN COLLAGE N'EST PAS UN COUP : un clic le pose (gauche) ou l'abandonne (droit), et c'est fini.
	if not collage.is_empty():
		if bouton == MOUSE_BUTTON_LEFT:
			var point := point_vise(position, "ajouter")
			if not point.is_empty():
				colle.emit(Outils.ancre("ajouter", point))
		annuler_collage()
		return
	if outil == "boite" or outil == "rect":
		var depart := _coin_vise(position)
		if depart.is_empty():
			return
		_coup = bouton
		_maj_du_coup = maj
		_coin_boite = depart["case"]
		_coin_fin = depart["case"]
		_survoler_boite(position)
		return
	_coup = bouton
	_derniere = ""
	_pose_du_coup = {}
	# ⚠ Un clic de sélection SANS Maj repart de zéro ; avec Maj, il ajoute — le réflexe de Blender.
	if outil == "selectionner" and bouton == MOUSE_BUTTON_LEFT and not maj:
		vider_selection()
	coup_commence.emit()
	_toucher(position)


## LE COIN VISÉ PAR UN GLISSÉ DE BOÎTE OU DE RECTANGLE.
##
## ⚠ **LE RECTANGLE IGNORE LA VISÉE, ET C'EST TOUT SON INTÉRÊT.** Il se pose toujours à PLAT sur le
## plan de l'étage courant, même en visée Sculpt : c'est le geste qui trace le sol d'une pièce, puis
## qu'on extrude étage par étage. Le laisser suivre la matière le rendrait bosselé, donc inutilisable
## pour poser un plan.
func _coin_vise(position: Vector2) -> Dictionary:
	if outil == "rect":
		var c = case_sous(position)
		if c == null:
			return {}
		return {"touche": false, "case": c, "normale": Vector3i.ZERO}
	return point_vise(position, "selectionner")


## LA BOÎTE : un coin au clic, l'autre sous la souris ; au relâché, le VOLUME entre les deux devient la
## sélection. Maj ajoute, le clic droit retire — les mêmes réflexes que le pinceau de sélection.
##
## ⚠ **ELLE PRENAIT LA MATIÈRE, ELLE PREND DÉSORMAIS LE VOLUME** (`volume_de_la_boite`). C'est ce qui
## permet de désigner une pièce AVANT de la bâtir : un pavé vide n'avait aucune existence, donc ni
## Fill ni Extrude n'avaient de prise. Les opérations qui veulent de la matière la filtrent à l'usage,
## donc rien de ce qui marchait ne change (Delete efface toujours la seule matière du pavé).
func _survoler_boite(position: Vector2) -> void:
	var point := _coin_vise(position)
	if _coin_boite == null:
		# Pas encore de tracé : on montre la case où la boîte commencerait.
		_boite_vue.visible = false
		if point.is_empty():
			_apercu.visible = false
		else:
			_remplir(_apercu, [point["case"]], TEINTE_SELECTIONNER)
		return
	if not point.is_empty():
		_coin_fin = point["case"]
	var a: Vector3i = _coin_boite
	var b: Vector3i = _coin_fin
	var bas := Vector3i(mini(a.x, b.x), mini(a.y, b.y), mini(a.z, b.z))
	var haut := Vector3i(maxi(a.x, b.x), maxi(a.y, b.y), maxi(a.z, b.z))
	var taille_boite := Vector3(haut - bas + Vector3i.ONE)
	_boite_vue.scale = taille_boite
	_boite_vue.position = Vector3(bas) + taille_boite * 0.5
	_boite_vue.visible = true
	_remplir(_apercu, _volume_vise(a, b).keys(), TEINTE_SELECTIONNER)


## Le volume que ce glissé désigne. ⚠ `creux` ne s'applique qu'à la boîte : évider un rectangle plat
## n'aurait aucun sens, et `volume_de_la_boite` le rendrait plein de toute façon.
func _volume_vise(a: Vector3i, b: Vector3i) -> Dictionary:
	return Outils.volume_de_la_boite(a, b, creux and outil == "boite")


func _finir_boite(bouton: int) -> void:
	var dedans: Dictionary = _volume_vise(_coin_boite, _coin_fin)
	if dedans.is_empty():
		boite_trop_grande.emit()
	var nouvelle: Dictionary = selection.duplicate() if _maj_du_coup or bouton == MOUSE_BUTTON_RIGHT else {}
	for c in dedans:
		if bouton == MOUSE_BUTTON_RIGHT:
			nouvelle.erase(c)
		else:
			nouvelle[c] = true
	_coin_boite = null
	_coin_fin = null
	_boite_vue.visible = false
	regler_selection(nouvelle)


func _occupees_actives() -> Dictionary:
	var occupees := {}
	var g := cases()
	if g != null:
		for c in g.get_used_cells():
			occupees[c] = true
	return occupees


## LE COLLAGE : le presse-papiers suit la souris, contre la face visée, en vert là où il posera.
func commencer_collage(presse_papiers: Array) -> void:
	collage = presse_papiers
	rafraichir()


func annuler_collage() -> void:
	collage = []
	_apercu.visible = false
	rafraichir()


func _survoler_collage(position: Vector2) -> void:
	var point := point_vise(position, "ajouter")
	if point.is_empty():
		_apercu.visible = false
		return
	var ancre_: Vector3i = Outils.ancre("ajouter", point)
	var ou: Array = []
	for d in collage:
		ou.append(ancre_ + (d as Vector3i))
	_remplir(_apercu, ou, TEINTE_AJOUTER)


func vider_selection() -> void:
	if selection.is_empty():
		return
	selection = {}
	_dessiner_selection()
	selection_changee.emit()


func regler_selection(nouvelle: Dictionary) -> void:
	selection = nouvelle
	_dessiner_selection()
	selection_changee.emit()


## ⚠ **ON MONTRE TOUTE LA SÉLECTION, CASES VIDES COMPRISES — ET C'ÉTAIT L'INVERSE.** Elle ne montrait
## que ce qui était encore de la MATIÈRE, ce qui avait un sens quand une sélection ne pouvait en porter
## d'autre. Depuis le rectangle et le pavé, tracer une pièce vide ne dessinait **rien** : on désignait
## un volume sans le voir, donc on ne pouvait ni le remplir ni l'extruder avec confiance.
func _dessiner_selection() -> void:
	if _selection_vue == null:
		return
	var vues: Array = selection.keys() if mode == "monde" else []
	_remplir(_selection_vue, vues, TEINTE_SELECTION)


## Rafraîchit ce qui dépend des cases : à rappeler après chaque changement de monde.
func rafraichir() -> void:
	_dessiner_selection()
	if _derniere_souris.x >= 0.0 and mode == "monde":
		_survoler(_derniere_souris)


## Un nuage de cubes translucides, UN SEUL appel de dessin quel que soit leur nombre.
func _nuage_de_cases(cote: float) -> MultiMeshInstance3D:
	var boite := BoxMesh.new()
	boite.size = Vector3.ONE * cote
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	boite.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = boite
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.visible = false
	_vue.add_child(instance)
	return instance


func _remplir(nuage: MultiMeshInstance3D, liste: Array, teinte: Color) -> void:
	var mm := nuage.multimesh
	mm.instance_count = liste.size()
	for i in liste.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(liste[i]) + Vector3.ONE * 0.5))
		mm.set_instance_color(i, teinte)
	nuage.visible = not liste.is_empty()


## La case est-elle couverte par la grille centrale ? Les lignes vont de −DEMI_GRILLE à +DEMI_GRILLE,
## donc les cases de −DEMI_GRILLE à DEMI_GRILLE − 1.
static func sur_la_grille_centrale(c: Vector3i) -> bool:
	return c.x >= -DEMI_GRILLE and c.x < DEMI_GRILLE and c.z >= -DEMI_GRILLE and c.z < DEMI_GRILLE


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


## Un carré de grille autour de la case survolée, qui S'EFFACE vers ses bords : il dit où l'on est
## sans prétendre être un plancher. ⚠ L'alpha vient de la couleur de SOMMET — un seul maillage, calé
## une fois, déplacé à chaque survol ; rien ne se reconstruit en suivant la souris.
const RAYON_LOCAL := 6


func _maillage_grille_locale() -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, m)
	var r := float(RAYON_LOCAL)
	# La case survolée va de 0 à 1 : le carré est centré sur son MILIEU, en (0,5 ; 0,5).
	for i in range(-RAYON_LOCAL, RAYON_LOCAL + 2):
		for k in range(-RAYON_LOCAL, RAYON_LOCAL + 1):
			for seg in [[Vector3(i, 0, k), Vector3(i, 0, k + 1)], [Vector3(k, 0, i), Vector3(k + 1, 0, i)]]:
				for sommet in seg:
					var d: float = (Vector2(sommet.x, sommet.z) - Vector2(0.5, 0.5)).length() / (r + 0.5)
					mesh.surface_set_color(Color(0.706, 0.741, 0.522, 0.3 * clampf(1.0 - d, 0.0, 1.0)))
					mesh.surface_add_vertex(sommet)
	mesh.surface_end()
	return mesh


func _placer_grille() -> void:
	if _grille != null:
		_grille.position = Vector3(0, etage + 0.002, 0)


# ── LE PLAY TEST ─────────────────────────────────────────────────────────────────────────────────────
#
# DEMANDÉ PAR JORDAN (29 septembre 2026) : marcher et sauter dans le monde peint avec un personnage,
# caméra à la troisième personne qui tourne autour de lui en LACET au clic droit glissé, molette pour
# rapprocher ou éloigner.
#
# ⚠ **IL FOULE CE QU'ON VOIT, PAS LES CASES.** Les grilles `Rendu` portent une boîte de collision par
# octant plein (`RP.collision`) : la case entière, alors que la matière rendue de l'aminci est un quart
# de case en retrait. Marcher sur les boîtes ferait flotter le personnage au-dessus du sol visible, et
# buter contre des murs invisibles. On bâtit donc un décor à part (couche de collision 2) à partir des
# TRIANGLES des tuiles posées, rotations comprises — et c'est ce qu'il faut éprouver : l'art de l'artiste.
# ⚠ Il est bâti UNE fois à l'entrée : le Play test ne change aucune case.

const CAMERA_DISTANCE := 4.0
const CAMERA_ELEVATION := 0.38
## La sphère du bras-ressort : un peu plus que le demi-plan proche de la caméra (0,05 à 45°).
const RAYON_DU_BRAS := 0.2
## Au clic gauche glissé, la hauteur de vue reste entre ces bornes : sous le sol, on ne voit rien.
const ELEVATION_MINI := -0.35
const ELEVATION_MAXI := 1.35
const CAMERA_HAUTEUR := 0.6
## Sous le point le plus bas du monde, de tant de cases : on est tombé, on repart du départ.
const CHUTE := 25.0


## Entre en Play test. Rend "" si l'on joue, sinon la raison — en anglais, l'écran l'affiche.
func commencer_partie() -> String:
	finir_partie()
	var triangles := PackedVector3Array()
	var colonnes := {}
	_plus_bas = INF
	for m in _couches.get_children():
		if not (m as Node3D).visible:
			continue
		for nom in ["Rendu", "Fautes"]:
			var g := m.get_node_or_null(nom) as GridMap
			if g != null:
				triangles.append_array(_triangles_poses(g))
		for c in (m.get_node("Cases") as GridMap).get_used_cells():
			_plus_bas = minf(_plus_bas, c.y)
			var cle := Vector2i(c.x, c.z)
			colonnes[cle] = maxi(colonnes.get(cle, c.y), c.y)
	if triangles.is_empty() or colonnes.is_empty():
		return "The world is empty — paint some ground in World first."

	_decor = StaticBody3D.new()
	_decor.name = "DecorDuJeu"
	_decor.collision_layer = 2
	_decor.collision_mask = 0
	var forme := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	# ⚠ LES DEUX FACES : la découpe laisse les pièces OUVERTES sur leurs plans de coupe (charte §4), et
	# un triangle vu de dos ne retiendrait rien.
	concave.backface_collision = true
	concave.set_faces(triangles)
	forme.shape = concave
	_decor.add_child(forme)
	_vue.add_child(_decor)

	# LE DÉPART : la colonne peinte la plus proche de ce qu'on regardait, au-dessus de sa plus haute case.
	var vise := Vector2(_cible.x, _cible.z)
	var meilleure := Vector2i.ZERO
	var d_min := INF
	for cle in colonnes:
		var d := vise.distance_squared_to(Vector2(cle) + Vector2(0.5, 0.5))
		if d < d_min:
			d_min = d
			meilleure = cle
	_depart = Vector3(meilleure.x + 0.5, colonnes[meilleure] + 1.6, meilleure.y + 0.5)

	personnage = Personnage.new()
	_vue.add_child(personnage)
	personnage.global_position = _depart
	_orbite_d_avant = [_cible, _azimut, _elevation, _distance]
	_elevation = CAMERA_ELEVATION
	_distance = CAMERA_DISTANCE
	personnage.cap_camera = _azimut
	# Le halo des yeux violets : allumé pour le jeu seulement, il changerait le jugement des teintes.
	_env.glow_enabled = true
	_env.glow_intensity = 0.9
	_env.glow_bloom = 0.05
	_env.glow_hdr_threshold = 1.0
	_suivre(0.0)
	return ""


func finir_partie() -> void:
	if personnage != null:
		personnage.queue_free()
		personnage = null
	if _decor != null:
		_decor.queue_free()
		_decor = null
	if _env != null:
		_env.glow_enabled = false
	if not _orbite_d_avant.is_empty():
		_cible = _orbite_d_avant[0]
		_azimut = _orbite_d_avant[1]
		_elevation = _orbite_d_avant[2]
		_distance = _orbite_d_avant[3]
		_orbite_d_avant = []
		_caler()


func reapparaitre() -> void:
	if personnage == null:
		return
	personnage.global_position = _depart
	personnage.velocity = Vector3.ZERO


## Les triangles de toutes les tuiles d'une grille, en coordonnées du monde. Le maillage d'un item est
## lu une fois ; la pose (case, quart de tour, décalage d'une demi-case de `Rendu`) s'applique d'un bloc.
static func _triangles_poses(g: GridMap) -> PackedVector3Array:
	var sortie := PackedVector3Array()
	var lot := g.mesh_library
	if lot == null:
		return sortie
	var par_item := {}
	var base := g.global_transform
	for c in g.get_used_cells():
		var id := g.get_cell_item(c)
		if not par_item.has(id):
			var mesh := lot.get_item_mesh(id)
			par_item[id] = lot.get_item_mesh_transform(id) * mesh.get_faces() if mesh != null \
				else PackedVector3Array()
		var pose := Transform3D(g.get_basis_with_orthogonal_index(g.get_cell_item_orientation(c)),
			g.map_to_local(c))
		sortie.append_array((base * pose) * (par_item[id] as PackedVector3Array))
	return sortie


## Le clavier se lit par la PLACE des touches (ZQSD / WASD, comme Navigate). ⚠ Un champ de texte qui a
## la main garde ses touches.
func _mener_le_jeu() -> void:
	if personnage == null:
		return
	var focus := get_viewport().gui_get_focus_owner()
	var libre := not (focus is LineEdit or focus is TextEdit) and is_visible_in_tree()
	var e := Vector2.ZERO
	if libre:
		if Input.is_physical_key_pressed(KEY_W):
			e.y += 1.0
		if Input.is_physical_key_pressed(KEY_S):
			e.y -= 1.0
		if Input.is_physical_key_pressed(KEY_D):
			e.x += 1.0
		if Input.is_physical_key_pressed(KEY_A):
			e.x -= 1.0
	personnage.entree = e
	personnage.saut = libre and Input.is_physical_key_pressed(KEY_SPACE)
	personnage.course = libre and Input.is_physical_key_pressed(KEY_SHIFT)
	personnage.cap_camera = _azimut
	if personnage.global_position.y < _plus_bas - CHUTE:
		reapparaitre()
	_suivre(get_process_delta_time())


## LA CAMÉRA À LA TROISIÈME PERSONNE, TENUE PAR UN BRAS-RESSORT — DEMANDÉ PAR JORDAN (29 septembre 2026) :
## « une collision avec un spring arm pour que ça ne passe jamais à travers le décor ».
##
## ⚠ **UNE SPHÈRE, PAS UN RAYON.** Le rayon d'avant ne voyait que l'axe : l'œil s'arrêtait juste devant
## la paroi, mais le plan proche de la caméra, lui, a une largeur — il la traversait, et l'on voyait
## l'intérieur de la roche. On lance une SPHÈRE du rayon du plan proche (`RAYON_DU_BRAS`), du personnage
## vers l'œil, contre le décor ; la caméra se pose là où la sphère a dû s'arrêter.
## ⚠ **RENTRER TOUT DE SUITE, RESSORTIR EN DOUCEUR** : le ressort. Rentrer en retard, c'est passer une
## image à travers la paroi ; ressortir d'un coup, c'est un saut de caméra à chaque pilier franchi.
func _suivre(dt: float) -> void:
	var vers := personnage.global_position + Vector3.UP * CAMERA_HAUTEUR
	_cible = vers if dt <= 0.0 else _cible.lerp(vers, minf(1.0, 18.0 * dt))
	var direction := Vector3(cos(_elevation) * sin(_azimut), sin(_elevation), cos(_elevation) * cos(_azimut))
	var libre := _distance
	# ⚠ `find_world_3d()`, PAS `world_3d` : sur un SubViewport qui a son propre monde, `world_3d` est NUL.
	# Le rayon de caméra d'avant ne tournait donc JAMAIS — et rien ne le disait.
	var monde_3d := _vue.find_world_3d()
	var espace := monde_3d.direct_space_state if monde_3d != null else null
	if espace != null:
		var q := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = RAYON_DU_BRAS
		q.shape = sphere
		q.transform = Transform3D(Basis(), _cible)
		q.motion = direction * _distance
		q.collision_mask = 2
		var r := espace.cast_motion(q)
		if not r.is_empty():
			libre = _distance * r[0]
	# Le ressort : rentrer sans délai, ressortir en douceur.
	if dt <= 0.0 or libre < _bras:
		_bras = libre
	else:
		_bras = minf(libre, lerpf(_bras, libre, minf(1.0, 6.0 * dt)))
	_camera.look_at_from_position(_cible + direction * _bras, _cible, Vector3.UP)


## Clic droit glissé : la caméra tourne autour du personnage, en LACET seulement (Jordan). Clic GAUCHE
## glissé (Jordan, 29 septembre 2026) : en lacet ET en hauteur. Molette : plus près, plus loin. Aucun clic
## ne peint.
func _souris_du_jeu(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(1.5, _distance / 1.12)
		elif b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(16.0, _distance * 1.12)
		elif b.pressed:
			# ⚠ Le clic rend la main clavier à la vue : sinon Espace « clique » le dernier bouton touché.
			grab_focus()
	elif event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		if (m.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_azimut -= m.relative.x * 0.008
			_elevation = clampf(_elevation + m.relative.y * 0.006, ELEVATION_MINI, ELEVATION_MAXI)
		elif (m.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
			_azimut -= m.relative.x * 0.008
