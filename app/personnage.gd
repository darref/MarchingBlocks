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
## LA TAILLE DU PERSONNAGE (Jordan, 6 octobre 2026 : « régler le scale du stickman, et le mettre un peu plus petit,
## ×0,65 par défaut, histoire que le monde paraisse un peu plus grand »). Un FACTEUR sur tout ce qui fait sa silhouette :
## le modèle, la capsule, la flottaison, la vitesse de marche, de course et de nage (un petit qui court aussi vite qu'un
## grand ne fait pas paraître le monde plus grand), et la caméra que la vue tient sur lui.
## ⚠ **CE QUI NE SUIT PAS, PROPOSÉ** : le SAUT (1,45 case), le PAS (0,3 : les marches de l'aminci restent d'un quart de
## case) et la sortie de l'eau — un monde en cases est fait de marches d'une case, et un petit personnage qui ne
## pourrait plus les franchir ne jugerait plus le monde ; et le VOL, qui sert à se déplacer.
const TAILLE_DEFAUT := 0.65
const TAILLE_MINI := 0.4
const TAILLE_MAXI := 1.5
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
## LE VOL (Jordan, 1er octobre 2026 : « un mode fly au stickman en play test »). Ni gravité ni pas : on
## monte et descend à volonté, mais ⚠ **IL HEURTE TOUJOURS LE DÉCOR** — le Play test sert à juger le
## monde, et traverser la roche n'en dirait rien. Maj vole plus vite, comme elle court.
const VITESSE_VOL := 5.0
const VITESSE_VOL_RAPIDE := 11.0

## LA NAGE (Jordan, 1er octobre 2026 : « go pour la nage au Play test »). Immergé de plus de `IMMERSION`, il nage :
## il flotte les pieds `FLOTTE` sous la nappe (la tête dehors), nage plus lentement, plonge avec la touche de
## descente du vol, remonte avec Espace, et se hisse sur une berge d'au plus `SORTIE` en nageant contre elle — la
## berge d'un lac à ras bord est à 0,6 au-dessus de ses pieds, une marche de 0,3 ne l'en sortirait jamais.
const VITESSE_NAGE := 2.2
const VITESSE_NAGE_RAPIDE := 3.4
const IMMERSION := 0.35
const FLOTTE := 0.55
const PLONGEE := 3.0
const SORTIE := 1.0

var entree := Vector2.ZERO
var saut := false
## La surface de l'eau au-dessus d'un point (−INF hors de l'eau), fournie par la vue ; vide : pas d'eau.
var surface_eau := Callable()
## LE COURANT D'UNE RIVIÈRE sous les pieds (un sens unitaire, ou zéro), fourni par la vue ; vide : aucun.
## Sur la bande d'une rivière, il pousse le personnage de `COURANT` cases/s (3 octobre 2026) — on y marche encore,
## à contre-courant plus lentement.
var courant_eau := Callable()
const COURANT := 1.6
## Vrai : il nage (lu par l'animation, la vue et les tests).
var nage := false
var course := false
## Vrai : il vole. `monter` (−1..1) est la commande verticale, lue seulement en vol.
var vol := false
var monter := 0.0
## Le cap de la caméra (radians autour de +Y) : « en avant » est l'avant de la CAMÉRA, aplati.
var cap_camera := 0.0
## Le facteur de taille (`TAILLE_DEFAUT`) ; à régler par `regler_taille`.
var taille := TAILLE_DEFAUT

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
var _forme: CollisionShape3D


func _init() -> void:
	name = "Personnage"
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.25
	# ⚠ SEUL LE DÉCOR DE PLAY TEST LE PORTE (couche 2) : les grilles de la vue gardent leurs boîtes de
	# collision par case (couche 1), qui ne suivent pas la surface visible — l'aminci est un quart de
	# case en retrait, et l'on marcherait au-dessus du sol qu'on voit.
	collision_layer = 0
	collision_mask = 2
	_forme = CollisionShape3D.new()
	_forme.shape = CapsuleShape3D.new()
	add_child(_forme)
	_batir_le_modele()
	regler_taille(taille)


## Change la taille (bornée à `TAILLE_MINI` .. `TAILLE_MAXI`) : la capsule et le modèle tout de suite. ⚠ Les pieds
## restent où ils sont (l'origine est aux pieds) : grandir contre un plafond le fait remonter par la physique.
func regler_taille(t: float) -> void:
	taille = clampf(t, TAILLE_MINI, TAILLE_MAXI)
	var capsule := _forme.shape as CapsuleShape3D
	capsule.radius = rayon()
	capsule.height = HAUTEUR * taille
	_forme.position.y = HAUTEUR * taille * 0.5
	_modele.scale = Vector3.ONE * ECHELLE * taille


func rayon() -> float:
	return RAYON * taille


func vitesse_marche() -> float:
	return VITESSE_MARCHE * taille


func vitesse_course() -> float:
	return VITESSE_COURSE * taille


func vitesse_nage() -> float:
	return VITESSE_NAGE * taille


func vitesse_nage_rapide() -> float:
	return VITESSE_NAGE_RAPIDE * taille


## Les pieds sous la nappe quand il flotte, et l'immersion à partir de laquelle il nage : à sa taille.
func flotte() -> float:
	return FLOTTE * taille


func immersion() -> float:
	return IMMERSION * taille


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
	if vol:
		nage = false
		_voler(voulu, dt)
		return
	# ⚠ ON SONDE LE TORSE (+0,5), ni les pieds ni le bas du corps : au fond d'un lac, les pieds sont sur le dessus VU
	# du plancher (0,75 dans sa case), et un point à +0,2 tombe encore dans la case PLEINE du plancher — hors de
	# l'eau pour la règle ; il marchait au fond (vu rougir dans la fumée).
	# ⚠ JAMAIS SOUS +0,3, quelle que soit sa taille : le dessus vu du plancher est à 0,75 dans sa case, et la sonde
	# doit sortir de cette case pleine.
	var s: float = surface_eau.call(global_position + Vector3.UP * maxf(0.3, 0.5 * taille)) 		if surface_eau.is_valid() else -INF
	nage = s > global_position.y + immersion()
	if nage:
		_nager(voulu, s, dt)
		return
	var vitesse := vitesse_course() if course else vitesse_marche()
	# Une inertie courte : on démarre et on s'arrête vite, mais pas au pixel près.
	var reactivite := 14.0 if is_on_floor() else 4.0
	var pousse := Vector3.ZERO
	if courant_eau.is_valid() and is_on_floor():
		pousse = courant_eau.call(global_position) * COURANT
	var plan := Vector3(velocity.x, 0.0, velocity.z).lerp(voulu * vitesse + pousse, minf(1.0, reactivite * dt))
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


## En vol : la vitesse rejoint la commande dans les trois axes, avec une inertie un peu plus longue qu'au
## sol — on plane. ⚠ `move_and_slide` quand même : il glisse le long des parois, il ne les traverse pas.
func _voler(voulu: Vector3, dt: float) -> void:
	var vitesse := VITESSE_VOL_RAPIDE if course else VITESSE_VOL
	var cible := (voulu + Vector3.UP * clampf(monter, -1.0, 1.0)).limit_length(1.0) * vitesse
	# ⚠ L'inertie verticale est plus courte : lâcher Espace laissait monter 0,7 case de plus (mesuré).
	var plan := Vector3(velocity.x, 0.0, velocity.z).lerp(Vector3(cible.x, 0.0, cible.z), minf(1.0, 7.0 * dt))
	velocity = Vector3(plan.x, lerpf(velocity.y, cible.y, minf(1.0, 14.0 * dt)), plan.z)
	floor_snap_length = 0.0
	move_and_slide()
	_en_l_air = 0.0
	_depuis_le_sol = GRACE + 1.0
	_saut_tenu = saut
	_orienter(voulu, dt)
	_animer(dt)


## Bascule le vol. En le quittant, la gravité reprend d'où l'on est : on retombe.
func basculer_vol() -> void:
	vol = not vol
	monter = 0.0
	if not vol:
		floor_snap_length = 0.25
		velocity.y = minf(velocity.y, 0.0)


## LA NAGE : la vitesse horizontale rejoint la commande avec une inertie longue (l'eau freine) ; la verticale
## rejoint la hauteur de flottaison — plus bas tant qu'on plonge, un peu plus haut tant qu'on tient Espace. Pas de
## gravité : c'est la flottaison qui tient le corps. Contre une berge, il s'y hisse (`SORTIE`).
func _nager(voulu: Vector3, s: float, dt: float) -> void:
	var vitesse := vitesse_nage_rapide() if course else vitesse_nage()
	var plan := Vector3(velocity.x, 0.0, velocity.z).lerp(voulu * vitesse, minf(1.0, 4.0 * dt))
	var cible_y := s - flotte()
	if monter < 0.0:
		cible_y -= PLONGEE
	elif saut:
		cible_y += 0.25
	var vy := clampf((cible_y - global_position.y) * 4.0, -3.0, 3.0)
	velocity = Vector3(plan.x, lerpf(velocity.y, vy, minf(1.0, 5.0 * dt)), plan.z)
	floor_snap_length = 0.0
	var avant := global_position
	move_and_slide()
	if is_on_wall() and voulu.length_squared() > 0.01:
		_gravir(voulu * vitesse * dt, avant, SORTIE)
	_en_l_air = 0.0
	_depuis_le_sol = 0.0
	_saut_tenu = saut
	_orienter(voulu, dt)
	_animer(dt)


## LE PAS : buté contre une paroi plus basse que `hauteur` (`MARCHE` à pied), on monte dessus au lieu de s'arrêter.
## Trois essais de mouvement, jamais un déplacement à l'aveugle : monter, avancer là-haut, redescendre.
func _gravir(pas: Vector3, depart: Vector3, hauteur := MARCHE) -> void:
	var t := global_transform
	t.origin = depart
	var haut := Vector3.UP * hauteur
	if test_move(t, haut):
		return
	t.origin += haut
	var loin := pas.normalized() * maxf(pas.length(), rayon() * 0.6)
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
	var allure := clampf(v / vitesse_course(), 0.0, 1.0)
	var au_sol := is_on_floor()
	# Des jambes plus courtes font plus de pas pour la même vitesse : la cadence suit la taille.
	_phase += dt * (2.5 + v * 3.2 / taille)
	var s := sin(_phase)
	var temps := Time.get_ticks_msec() * 0.001

	var jambe := s * 0.95 * allure
	var bras := -s * 0.85 * allure
	var bras_ecart := 0.08 + 0.04 * sin(temps * 1.7) * (1.0 - allure)
	var penche := 0.18 * allure
	var rebond := absf(cos(_phase)) * 0.05 * allure
	var souffle := sin(temps * 2.2) * 0.012 * (1.0 - allure)
	if nage:
		# À LA NAGE : une brasse — les bras s'écartent et reviennent ensemble, les jambes battent à contretemps ; à
		# l'arrêt, il fait du surplace, debout, les bras qui godillent.
		var elan := clampf(v / vitesse_nage_rapide(), 0.0, 1.0)
		var brasse := sin(temps * 4.0)
		jambe = sin(temps * 5.0) * (0.25 + 0.2 * elan)
		bras = -0.6 * elan + brasse * 0.25
		bras_ecart = 0.7 + 0.5 * brasse
		penche = 0.1
		rebond = sin(temps * 2.0) * 0.02
		souffle = 0.0
	elif vol:
		# EN VOL : couché dans le sens de la marche selon la vitesse, bras écartés vers l'avant, jambes
		# qui traînent derrière et battent lentement ; à l'arrêt, il flotte droit et ondule.
		var elan := clampf(v / VITESSE_VOL_RAPIDE, 0.0, 1.0)
		var monte := clampf(velocity.y / VITESSE_VOL, -1.0, 1.0)
		# ⚠ Les épaules sont en OPPOSITION (la droite prend −bras) : les bras s'ouvrent en ailes par l'écart.
		jambe = -0.35 * elan + sin(temps * 3.0) * 0.12
		bras = sin(temps * 2.0) * 0.08
		bras_ecart = 1.25 - 0.25 * elan + 0.25 * monte
		penche = 0.1 - 0.2 * monte * (1.0 - elan)
		rebond = sin(temps * 2.4) * 0.03
		souffle = 0.0
	elif not au_sol:
		var monte := clampf(velocity.y / 6.0, -1.0, 1.0)
		jambe = 0.6
		bras = -0.4
		bras_ecart = 1.1 + 0.4 * monte
		penche = 0.05
		rebond = 0.0

	var k := minf(1.0, 16.0 * dt)
	# En vol, c'est TOUT le corps qui se couche vers l'avant avec la vitesse, pas le seul torse.
	var couche := -0.85 * clampf(v / VITESSE_VOL_RAPIDE, 0.0, 1.0) if vol else 0.0
	if nage:
		couche = -1.25 * clampf(v / vitesse_nage(), 0.0, 1.0)   # à plat sur l'eau quand il avance
	_modele.rotation.x = lerpf(_modele.rotation.x, couche, minf(1.0, 6.0 * dt))
	_hanche_g.rotation.x = lerpf(_hanche_g.rotation.x, jambe, k)
	# En vol, les deux jambes traînent ensemble, la droite à contretemps.
	var jambe_d := (jambe - sin(temps * 3.0) * 0.24) if vol \
		else (-jambe if au_sol or nage else -0.25)
	_hanche_d.rotation.x = lerpf(_hanche_d.rotation.x, jambe_d, k)
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
	var e := ECHELLE * taille
	_modele.scale = Vector3(e * (1.0 + _ecrasement * 0.6), e * (1.0 - _ecrasement), e * (1.0 + _ecrasement * 0.6))
