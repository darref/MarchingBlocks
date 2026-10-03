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
## Une forme spéciale posée d'un clic (ou au second clic d'un « Connect ») : `modif` = {poser, effacer}.
signal forme_posee(modif: Dictionary, nom: String, info: Dictionary)
## Ce qu'il faut DIRE d'une forme : un refus du cœur (`code` = son erreur), une ancre posée ou oubliée.
signal forme_dite(code: String, info: Dictionary)
## LA TUILE SOUS LA SOURIS, dans World (le sens inverse de la légende des formes) :
## {"sommet", "nom" (l'item posé, "" s'il n'y en a pas), "faute" (un cube rouge), "lot"} ; {} = aucune.
signal tuile_survolee(info: Dictionary)
## L'outil Water (charte §5, « le mode Fluids ») : la case où une source se poserait, sous la souris (ou null).
signal eau_survolee(source: Variant)
signal eau_cliquee(source: Variant, bouton: int)
## Ctrl+clic en World : la case de matière touchée (couches visibles), ou `null` si le rayon ne touche rien.
signal etage_sur_la_matiere(case: Variant)

const Massif := preload("res://addons/marchingblocks_core/massif_peint.gd")
const Outils := preload("res://addons/marchingblocks_core/outils.gd")
const FS := preload("res://addons/marchingblocks_core/formes_speciales.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const EauMaillage := preload("res://addons/marchingblocks_core/eau_maillage.gd")
const EauPresets := preload("res://addons/marchingblocks_core/eau_presets.gd")
const Personnage := preload("res://app/personnage.gd")
const LegendeFormes := preload("res://app/legende_formes.gd")

## Jusqu'où porte le rayon de sculpture, en cases.
const PORTEE := 400.0
const TEINTE_AJOUTER := Color(0.55, 0.82, 0.45, 0.32)
const TEINTE_CREUSER := Color(0.9, 0.38, 0.24, 0.36)
const TEINTE_SELECTIONNER := Color(0.42, 0.62, 0.98, 0.3)
const TEINTE_SELECTION := Color(0.42, 0.62, 0.98, 0.22)
const TEINTE_BOITE := Color(0.42, 0.62, 0.98, 0.1)
const TEINTE_ANCRE := Color(1.0, 0.82, 0.25, 0.6)
const TEINTE_EAU := Color(0.3, 0.68, 1.0, 0.34)

var _vue: SubViewport

# ── L'AMBIANCE LUMINEUSE — UNE SEULE SOURCE (1er octobre 2026). La vue la lit, et le manuel (F1, « Getting the same
# look in your engine ») l'écrit au client depuis ces mêmes constantes : une page qui recopierait les valeurs
# divergerait au premier réglage retouché (charte §6).
const SOLEIL_ROTATION := Vector3(-48, -34, 0)
const SOLEIL_ENERGIE := 1.15
const AMBIANTE_COULEUR := Color("#8892a4")
const AMBIANTE_ENERGIE := 1.1
const SSAO_INTENSITE := 2.5
const SSAO_SUR_LE_SOLEIL := 0.6
const REFLETS_HAUT := Color("#8892a4")
const REFLETS_HORIZON := Color("#9aa2b0")
const REFLETS_SOL := Color("#5a606c")
const CIEL_HAUT := Color("#2e1a6e")
const CIEL_HORIZON := Color("#3c86b4")
const CIEL_SOL := Color("#0c0e18")
const CIEL_COURBE_DU_SOL := 0.6
const MSAA := Viewport.MSAA_4X
var _camera: Camera3D
var _cible := Vector3(6, 4, 6)
var _azimut := 0.7
var _elevation := 0.55
var _distance := 26.0
## LE DÉZOOM DU MONDE (Jordan, 2 octobre 2026 : « on doit pouvoir dézoomer beaucoup plus loin ») : 120 cases ne
## laissaient pas voir une grande carte entière. Le témoin garde 120 (un bloc de 12³).
const DISTANCE_MAXI_MONDE := 1000.0

var _temoin: MeshInstance3D
## LES PLANS DE COUPE du témoin — là où le trancheur coupe. Montrés à la demande (« Show the cells »).
var _plans_de_coupe: MeshInstance3D
var _plans_voulus := false
## Un `MassifPeint` par COUCHE du monde (`projet.gd`). On peint sur la couche ACTIVE ; les autres restent
## visibles, chacune rendue avec SON lot et selon SES cases seulement.
var _couches: Node3D
## Les nappes d'eau, une par couche d'eau (`poser_eaux`) : à côté des couches de tuiles, jamais dedans — `couche(i)`
## compte les enfants de `_couches`.
var _eaux: Node3D
var _soleil: DirectionalLight3D
## L'EAU DU PLAY TEST, posée par l'écran avant de jouer : {"cases" (l'eau dormante des couches d'eau VISIBLES),
## "oceans" (leurs niveaux), "boite" (`FL.boite` du monde)}. Vide : on ne nage nulle part.
var eau_du_jeu := {}
## Le voile sous l'eau : la couleur de l'eau vue de dedans, et sa densité.
const VOILE_COULEUR := Color("#1d5a6e")
const VOILE_DENSITE := 0.18
var _active := -1
var _grille: MeshInstance3D
## La grille LOCALE : un morceau de grille qui suit le curseur quand il sort de la grille centrale —
## sans elle, on peint à l'aveugle dès qu'on s'éloigne du centre du monde.
var _grille_locale: MeshInstance3D
## L'APERÇU : les cases EXACTES que le prochain clic changera, avant qu'on clique.
var _apercu: MultiMeshInstance3D
var _selection_vue: MultiMeshInstance3D
## LA ZONE D'UNE FORME DU TÉMOIN, allumée pendant qu'on survole sa carte (`legende_formes.gd`).
var _zone_vue: MultiMeshInstance3D
## LA TUILE désignée : celle qu'on survole dans World, ou celle d'où elle vient, dans le témoin. Une
## boîte d'une case centrée sur le SOMMET — c'est exactement la place d'une pièce (charte §2).
var _tuile_vue: MeshInstance3D
## Le dernier sommet dit par `tuile_survolee` : on ne le redit pas à chaque pixel.
var _tuile_dite: Variant = null

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
## LES FORMES SPÉCIALES (outil « forme ») — la règle vit dans `formes_speciales.gd`, la vue ne fait que
## viser, montrer et émettre. `ancre_forme` : la première ancre d'un « Connect » ({case, face}), vide sinon.
var forme_speciale := {"quoi": "tunnel", "relier": false, "profil": "rond", "taille": 2, "longueur": 8,
	"garde_corps": true, "pas": 2, "etages": 3, "vers_le_haut": true}
## La salle se TRACE (un rectangle sur la grille de l'étage), elle ne s'ancre pas : son aperçu, gardé par sa clé.
var _cle_salle := ""
var _salle_vue := {}
var ancre_forme := {}
var _cle_forme := ""
var _forme_vue := {}
var _ancre_vue: MultiMeshInstance3D
## La SÉLECTION — des cases de la couche active. ⚠ Un état d'écran, pas une donnée : elle n'est ni
## enregistrée ni annulable, et se vide quand on change de couche.
var selection := {}
## Le pinceau Select prend aussi les cases VIDES (Jordan, 3 octobre 2026 : peindre l'empreinte d'une pièce).
var selection_vide := false
## LE COLLAGE EN COURS — le presse-papiers (décalages relatifs, `Outils.copier`) qui suit la souris
## jusqu'au clic. Vide hors d'un collage.
var collage: Array = []

## "temoin", "monde" ou "jeu".
var mode := "temoin"
## LE MODELEUR (`modeleur.gd`) : branché par l'écran. En mode témoin, `edition` le montre à la place du
## témoin figé, et lui donne la souris (Tab, comme dans Blender).
var modeleur: Node3D
var edition := false
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
var _ciel_du_jeu: ProceduralSkyMaterial
var _ciel_neutre: ProceduralSkyMaterial
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
	_vue.msaa_3d = MSAA
	add_child(_vue)

	var env := Environment.new()
	_env = env
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#101216")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIANTE_COULEUR
	env.ambient_light_energy = AMBIANTE_ENERGIE
	# ⚠ LA LUMIÈRE DES CREUX : SSAO + SSIL, EN ESPACE ÉCRAN (Jordan, 1er octobre 2026 : « une lumière ambiante
	# afin que tout soit au moins légèrement visible […] afin de bien voir les reliefs qu'on crée », puis « en mode
	# World aussi, on n'y voit rien »). Jugé à l'image (`DEV_TOOLS/capture_eclairage.gd`) : les faces à l'ombre
	# s'éclaircissent, les creux prennent une ombre douce, le relief se lit — dans Witness et dans World.
	# ⚠ PAS LE SDFGI, ESSAYÉ ET MESURÉ : il ne voit PAS une géométrie modifiée (une dalle émissive posée après coup
	# ne teinte rien) tant qu'il ne se reconstruit pas, et le reconstruire après chaque geste noircit les ombres
	# pendant ~45 images (0,75 s) — un clignotement à chaque enregistrement. L'espace écran suit chaque image.
	# ⚠ Monter l'ambiante SEULE (1,5) rend tout visible mais APLATIT le relief.
	env.ssao_enabled = true
	# ⚠ L'OCCLUSION AU SOLEIL AUSSI (Jordan, 1er octobre 2026 : « le SSAO n'est visible qu'à l'ombre ») : par défaut
	# elle n'assombrit que l'AMBIANTE (`ssao_light_affect` = 0), qui ne pèse presque rien au soleil. Ce n'est pas
	# une affaire de normales lissées — lisser arrondirait les arêtes vives sans rien y changer.
	env.ssao_light_affect = SSAO_SUR_LE_SOLEIL
	env.ssao_intensity = SSAO_INTENSITE
	env.ssil_enabled = true
	# LE CIEL DU PLAY TEST (Jordan, 1er octobre 2026) : bleu-violet foncé en haut, turquoise tirant sur le
	# bleu-violet à l'horizon, un sol de ciel peu visible repoussé vers le bas. Montré en jeu seulement
	# (`background_mode`) ; l'ambiante reste sa COULEUR, pour que le monde s'éclaire pareil dedans et dehors.
	var ciel := ProceduralSkyMaterial.new()
	ciel.sky_top_color = CIEL_HAUT
	ciel.sky_horizon_color = CIEL_HORIZON
	ciel.sky_curve = 0.12
	ciel.ground_horizon_color = CIEL_HORIZON
	ciel.ground_bottom_color = CIEL_SOL
	ciel.ground_curve = CIEL_COURBE_DU_SOL   # grand : le sol garde la teinte de l'horizon longtemps, son sombre arrive bas
	ciel.sun_angle_max = 8.0
	_ciel_du_jeu = ciel
	# ⚠ CE QUE REFLÈTENT LES MÉTAUX (Jordan, 1er octobre 2026 : « le métallique sur les parois marron est trop
	# fort ») : un métal n'éclaire presque pas par diffusion, il REFLÈTE son environnement — et le nôtre était le
	# fond presque noir. Ses parois (métal 0,57) tombaient au noir à l'ombre. Hors du jeu, les reflets viennent
	# d'un ciel NEUTRE, de la teinte de l'ambiante ; en jeu, du ciel qu'on voit.
	_ciel_neutre = ProceduralSkyMaterial.new()
	_ciel_neutre.sky_top_color = REFLETS_HAUT
	_ciel_neutre.sky_horizon_color = REFLETS_HORIZON
	_ciel_neutre.ground_horizon_color = REFLETS_HORIZON
	_ciel_neutre.ground_bottom_color = REFLETS_SOL
	_ciel_neutre.sun_angle_max = 0.0
	env.sky = Sky.new()
	env.sky.sky_material = _ciel_neutre
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var monde_env := WorldEnvironment.new()
	monde_env.environment = env
	_vue.add_child(monde_env)

	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = SOLEIL_ROTATION
	soleil.light_energy = SOLEIL_ENERGIE
	soleil.shadow_enabled = true
	_vue.add_child(soleil)
	_soleil = soleil
	rendu_par_defaut()

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
	_eaux = Node3D.new()
	_eaux.name = "Eaux"
	_vue.add_child(_eaux)

	_grille = MeshInstance3D.new()
	_grille.mesh = _maillage_grille()
	_vue.add_child(_grille)

	_grille_locale = MeshInstance3D.new()
	_grille_locale.mesh = _maillage_grille_locale()
	_grille_locale.visible = false
	_vue.add_child(_grille_locale)

	_apercu = _nuage_de_cases(1.03)
	_selection_vue = _nuage_de_cases(1.01)
	_ancre_vue = _nuage_de_cases(1.06)
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

	_zone_vue = LegendeFormes.nuage_de_zone([], LegendeFormes.TEINTE_ZONE)
	_vue.add_child(_zone_vue)
	_tuile_vue = MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 1.04
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.no_depth_test = true
	mt.albedo_color = Color(1, 1, 1, 0.45)
	cube.material = mt
	_tuile_vue.mesh = cube
	_tuile_vue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tuile_vue.visible = false
	_vue.add_child(_tuile_vue)

	_camera = Camera3D.new()
	_camera.fov = 45
	_vue.add_child(_camera)
	_caler()
	montrer(mode)


# ── ce qu'on montre ──────────────────────────────────────────────────────────────────────────────────

func brancher_modeleur(m: Node3D) -> void:
	modeleur = m
	_vue.add_child(m)
	m.camera = _camera
	m.visible = false


func regler_edition(oui: bool) -> void:
	edition = oui
	montrer(mode)


func montrer(quoi: String) -> void:
	mode = quoi
	_temoin.visible = quoi == "temoin" and not edition
	if modeleur != null:
		modeleur.visible = quoi == "temoin" and edition
	_plans_de_coupe.visible = quoi == "temoin" and _plans_voulus
	_couches.visible = quoi == "monde" or quoi == "jeu"
	_eaux.visible = quoi == "monde" or quoi == "jeu"
	_grille.visible = quoi == "monde"
	_apercu.visible = false
	_grille_locale.visible = false
	if _zone_vue != null:
		_zone_vue.visible = false
	if _tuile_vue != null:
		_tuile_vue.visible = false
	_tuile_dite = null
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


## Change la place d'une couche dans la pile (l'ordre des couches EST leur priorité).
func deplacer_couche(de: int, vers: int) -> void:
	_couches.move_child(_couches.get_child(de), vers)


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

## LES VUES DU PAVÉ NUMÉRIQUE, celles de Blender : 1 face, 3 droite, 7 dessus ; avec Ctrl, l'opposée.
## ⚠ En axes de Blender : « face » regarde vers +Y de Blender, donc l'œil est du côté −Y de Blender, qui
## est +Z de Godot.
func vue_de(nom: String, opposee := false) -> void:
	match nom:
		"face":
			_azimut = PI if opposee else 0.0
			_elevation = 0.0
		"droite":
			_azimut = -PI / 2.0 if opposee else PI / 2.0
			_elevation = 0.0
		"dessus":
			_azimut = 0.0
			_elevation = -1.5 if opposee else 1.5
	_caler()


## 5 — perspective ou orthographique.
func basculer_ortho() -> bool:
	if _camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_camera.size = _distance * 0.8
	else:
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	return _camera.projection == Camera3D.PROJECTION_ORTHOGONAL


## LA ZONE D'UNE FORME — allumée à travers la roche : la salle d'une grotte est DEDANS le bloc.
func montrer_zone(cases: Array, taille := 1.0) -> void:
	LegendeFormes.remplir_zone(_zone_vue, cases if mode == "temoin" else [], taille)


## Montre la place d'une pièce (le sommet `v` est au centre de la case `v + (1, 1, 1)`), ou rien (`null`).
func montrer_tuile(sommet: Variant) -> void:
	_tuile_vue.visible = sommet != null
	if sommet != null:
		_tuile_vue.position = Vector3(sommet as Vector3i) + Vector3.ONE


## QUELLE TUILE EST SOUS LA SOURIS — dans la couche ACTIVE. Rend {} si le rayon ne touche rien.
## ⚠ **LE RAYON TOUCHE UNE CASE ; LA TUILE EST CELLE DU SOMMET.** Le point touché est sur la face de la
## case, et la pièce du sommet `v` occupe [v + ½, v + 3/2] (charte §2) : `v = ⌊p − ½⌋`. Sur l'axe de la
## face, p est entier, et le sommet trouvé est celui qui chevauche les DEUX côtés de la face — celui
## dont la pièce porte cette surface.
## ⚠ **ON LIT CE QUI EST POSÉ, PAS CE QUE LA RÈGLE POSERAIT** : l'item de la grille `Rendu` à ce sommet,
## et son nom. Recalculer la pose serait une seconde description du peintre (charte §6).
func tuile_sous(position: Vector2) -> Dictionary:
	var m := monde()
	if m == null:
		return {}
	var origine: Vector3 = _camera.project_ray_origin(position)
	var sens: Vector3 = _camera.project_ray_normal(position).normalized()
	var r: Dictionary = Outils.rayon(_occupe_actif, origine, sens, PORTEE)
	if not r["touche"]:
		return {}
	var c: Vector3i = r["case"]
	var n: Vector3i = r["normale"]
	var axe := 0 if n.x != 0 else (1 if n.y != 0 else 2)
	var plan: float = float(c[axe]) + (1.0 if n[axe] > 0 else 0.0)
	var p: Vector3 = origine + sens * ((plan - origine[axe]) / sens[axe])
	p[axe] = plan
	var sommet := Vector3i(floori(p.x - 0.5), floori(p.y - 0.5), floori(p.z - 0.5))
	var rendu := m.get_node("Rendu") as GridMap
	var fautes := m.get_node("Fautes") as GridMap
	var id: int = rendu.get_cell_item(sommet)
	var lot: MeshLibrary = rendu.mesh_library
	return {"sommet": sommet, "nom": lot.get_item_name(id) if id >= 0 and lot != null else "",
		"faute": fautes.get_cell_item(sommet) != -1, "lot": lot}


func _dire_la_tuile(position: Vector2) -> void:
	var info := tuile_sous(position) if mode == "monde" else {}
	# ⚠ LE VIDE N'EFFACE PAS : pour aller cliquer « Show it in the witness », la souris quitte la tuile et
	# traverse du ciel. La dernière tuile désignée reste dite jusqu'à ce qu'on en survole une autre.
	if info.is_empty():
		_marquer_la_tuile_dite()
		return
	var ou: Variant = info.get("sommet", null)
	var cle := [ou, info.get("nom", "")]
	if cle != _tuile_dite:
		_tuile_dite = cle
		tuile_survolee.emit(info)
	_marquer_la_tuile_dite()


## ⚠ **UN SEUL REPÈRE SOUS LA SOURIS (Jordan, 1er octobre 2026 : « le preview de case aligné sur la grille et
## celui aligné sur la tuile […] c'est brouillon »).** Les deux se chevauchaient, décalés d'une demi-case
## (la case `p` occupe [p, p+1], la tuile du sommet v occupe [v + ½, v + 3/2]). Quand on PEINT, le repère
## est l'aperçu des cases, calé sur la grille : c'est ce que le clic changera. La boîte blanche de la tuile
## ne se montre qu'en Navigate, où rien n'est peint et où l'on regarde le monde tuile par tuile. Le
## bandeau « Where is it from? » suit la tuile survolée dans les deux cas.
func _marquer_la_tuile_dite() -> void:
	montrer_tuile(_tuile_dite[0] if naviguer and _tuile_dite != null else null)


## Cadrer une forme sous l'angle de sa photo, pour que la vue ressemble à la carte qu'on a cliquée.
## `recul_mini` : pour une seule tuile, la distance de la photo collerait l'œil au bloc — on ne verrait
## plus où elle est dans le témoin.
func cadrer_zone(cases: Array, azimut: float, elevation: float, recul_mini := 4.0) -> void:
	var centre: Vector3 = LegendeFormes.centre_de(cases)
	_cible = centre
	_azimut = azimut
	_elevation = elevation
	_distance = clampf(LegendeFormes.rayon_de(cases, centre) * 2.2 + 4.5, recul_mini, 60.0)
	_caler()


## « . » du pavé — cadrer un point.
func cadrer(centre: Vector3) -> void:
	_cible = centre
	_caler()


func _caler() -> void:
	if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		_camera.size = _distance * 0.8
	var direction := Vector3(cos(_elevation) * sin(_azimut), sin(_elevation),
		cos(_elevation) * cos(_azimut))
	_camera.look_at_from_position(_cible + direction * _distance, _cible, Vector3.UP)
	# Les ombres suivent le recul : à 100 cases (le défaut du moteur) une carte vue de loin n'en avait plus.
	if _soleil != null and mode != "jeu":
		_soleil.directional_shadow_max_distance = maxf(100.0, _distance * 2.0)


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
	if mode == "temoin" and edition and modeleur != null and modeleur.souris_entree(event):
		accept_event()
		return
	if naviguer and mode == "monde" and _naviguer(event):
		accept_event()
		return
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Dans le témoin on modélise de PRÈS : une case entière doit pouvoir remplir l'écran.
			_distance = maxf(1.0 if mode == "temoin" else 4.0, _distance / 1.12)
			_caler()
			accept_event()
			return
		if b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(DISTANCE_MAXI_MONDE if mode == "monde" else 120.0, _distance * 1.12)
			_caler()
			accept_event()
			return
		# ⚠ CTRL+CLIC CALE LA GRILLE SUR LA MATIÈRE, quel que soit l'outil : ce n'est pas un coup, rien
		# n'est peint, et la visée n'y change rien — le rayon cherche toujours la matière visible.
		if mode == "monde" and b.button_index == MOUSE_BUTTON_LEFT and b.ctrl_pressed and b.pressed \
				and _coup < 0:
			var r: Dictionary = Outils.rayon(_occupe_visible, _camera.project_ray_origin(b.position),
				_camera.project_ray_normal(b.position), PORTEE, {})
			etage_sur_la_matiere.emit(r["case"] if r["touche"] else null)
			accept_event()
			return
		if mode == "monde" and (b.button_index == MOUSE_BUTTON_LEFT or b.button_index == MOUSE_BUTTON_RIGHT):
			if b.pressed and _coup < 0:
				_commencer_coup(b.button_index, b.position, b.shift_pressed)
			elif not b.pressed and b.button_index == _coup:
				_coup = -1
				_pose_du_coup = {}
				if _coin_boite != null and _est_salle():
					_finir_salle()
				elif _coin_boite != null:
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
			or (mode == "temoin" and not edition and (m.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0)
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
	_dire_la_tuile(position)
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
	if outil == "forme":
		if _est_salle():
			_survoler_salle(position)
		else:
			_survoler_forme(position)
		return
	if outil == "eau":
		eau_survolee.emit(source_visee(position))
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
			montrees = toutes if selection_vide and g == "selectionner" else toutes.filter(_occupe_actif)
	var teinte: Color = {"ajouter": TEINTE_AJOUTER, "creuser": TEINTE_CREUSER}.get(g, TEINTE_SELECTIONNER)
	_remplir(_apercu, montrees, teinte)


## Une nouvelle case sous la souris pendant un coup : on applique le geste. `_derniere` évite de
## rejouer la même ancre à chaque pixel.
func _toucher(position: Vector2) -> void:
	if _coin_boite != null:
		if _est_salle():
			_survoler_salle(position)
		else:
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
				elif selection_vide or _occupe_actif(c):
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
	if outil == "forme" and _est_salle():
		# LA SALLE SE TRACE : un coin au clic, l'autre au relâché, à plat sur la grille de l'étage (comme Rect).
		var depart = case_sous(position)
		if depart == null or bouton != MOUSE_BUTTON_LEFT:
			return
		_coup = bouton
		_coin_boite = depart
		_coin_fin = depart
		_survoler_salle(position)
		return
	if outil == "forme":
		_cliquer_forme(bouton, position)
		return
	if outil == "eau":
		eau_cliquee.emit(source_visee(position), bouton)
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


# ── les formes spéciales ─────────────────────────────────────────────────────────────────────────────

## ⚠ **UNE FORME VISE TOUJOURS LA MATIÈRE DE LA COUCHE ACTIVE, QUELLE QUE SOIT LA VISÉE** : elle part d'une
## FACE (une paroi, un sol), et seule la couche active peut changer. La grille n'a pas de face à offrir.
func _point_forme(position: Vector2) -> Dictionary:
	if cases() == null:
		return {}
	var r: Dictionary = Outils.rayon(_occupe_actif, _camera.project_ray_origin(position),
		_camera.project_ray_normal(position), PORTEE)
	return r if r["touche"] else {}


## La demande faite au cœur pour ce point : un clic droit devant soi, ou la seconde ancre d'un « Connect ».
func _demande_forme(point: Dictionary) -> Dictionary:
	var r := forme_speciale.duplicate()
	if bool(r["relier"]) and not ancre_forme.is_empty() and r["quoi"] != "balcon":
		r["a"] = ancre_forme["case"]
		r["face_a"] = ancre_forme["face"]
		r["b"] = point["case"]
		r["face_b"] = point["normale"]
	else:
		r["relier"] = false
		r["a"] = point["case"]
		r["face_a"] = point["normale"]
	return r


## ⚠ LE CŒUR N'EST RAPPELÉ QUE QUAND LA CASE OU LA FACE VISÉE CHANGE (ou les réglages) : un conduit long
## parcourt des milliers de cases, et le refaire à chaque pixel ferait ramer la souris.
func _forme_sous(point: Dictionary) -> Dictionary:
	var demande := _demande_forme(point)
	var cle := "%s|%s|%s" % [demande, ancre_forme, cases().get_instance_id()]
	if cle != _cle_forme:
		_cle_forme = cle
		_forme_vue = FS.forme(_occupees_actives(), demande)
	return _forme_vue


## Rien à montrer tant qu'aucune ancre n'est posée en « Connect » : seule la case qui la recevrait s'allume.
func _attend_la_premiere_ancre() -> bool:
	return bool(forme_speciale["relier"]) and ancre_forme.is_empty() and forme_speciale["quoi"] != "balcon"


func _survoler_forme(position: Vector2) -> void:
	_montrer_ancre()
	var point := _point_forme(position)
	if point.is_empty():
		_apercu.visible = false
		return
	if _attend_la_premiere_ancre():
		_remplir(_apercu, [point["case"]], TEINTE_ANCRE)
		return
	var r := _forme_sous(point)
	if r["erreur"] != "":
		_remplir(_apercu, [point["case"]], TEINTE_CREUSER)
		return
	if not r["effacer"].is_empty():
		_remplir(_apercu, r["effacer"].keys(), TEINTE_CREUSER)
	else:
		_remplir(_apercu, r["poser"].keys(), TEINTE_AJOUTER)


func _montrer_ancre() -> void:
	_remplir(_ancre_vue, [ancre_forme["case"]] if not ancre_forme.is_empty() else [], TEINTE_ANCRE)


## Un clic : la première ancre d'un « Connect », ou la forme elle-même. Le clic DROIT oublie l'ancre.
func _cliquer_forme(bouton: int, position: Vector2) -> void:
	if bouton == MOUSE_BUTTON_RIGHT:
		oublier_ancre()
		return
	var point := _point_forme(position)
	if point.is_empty():
		return
	if _attend_la_premiere_ancre():
		var n: Vector3i = FS.normale_de(forme_speciale["quoi"], _occupees_actives(), point["case"], point["normale"],
			true)
		if n == Vector3i.ZERO:
			forme_dite.emit(FS.erreur_d_ancre(forme_speciale["quoi"], true), {})
			return
		ancre_forme = {"case": point["case"], "face": point["normale"]}
		_montrer_ancre()
		forme_dite.emit("ancre", {"case": point["case"], "normale": n})
		_survoler(position)
		return
	var r := _forme_sous(point)
	if r["erreur"] != "":
		forme_dite.emit(r["erreur"], r)
		return
	ancre_forme = {}
	_cle_forme = ""
	_montrer_ancre()
	forme_posee.emit({"poser": r["poser"], "effacer": r["effacer"]}, forme_speciale["quoi"], r)


# ── l'eau ────────────────────────────────────────────────────────────────────────────────────────────

## LA CASE OÙ POSER UNE SOURCE : devant la face de matière visée — toutes les couches VISIBLES, l'eau
## appartient au monde entier —, sinon sur le plan de l'étage (cliquer dans le vide pose un océan à cette
## hauteur). Null si le rayon ne trouve rien.
func source_visee(position: Vector2) -> Variant:
	var r: Dictionary = Outils.rayon(_occupe_visible, _camera.project_ray_origin(position),
		_camera.project_ray_normal(position), PORTEE)
	if r["touche"] and r["normale"] != Vector3i.ZERO:
		return r["case"] + r["normale"]
	return case_sous(position)


func montrer_apercu(cases_: Array, teinte: Color) -> void:
	_remplir(_apercu, cases_, teinte)


## Les nappes : [[maillage ou null, matériau, visible], …], une par couche d'eau, dans l'ordre.
func poser_eaux(nappes: Array) -> void:
	while _eaux.get_child_count() > nappes.size():
		var n := _eaux.get_child(_eaux.get_child_count() - 1)
		_eaux.remove_child(n)
		n.free()
	while _eaux.get_child_count() < nappes.size():
		var mi := MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_eaux.add_child(mi)
	for i in nappes.size():
		var mi := _eaux.get_child(i) as MeshInstance3D
		mi.mesh = nappes[i][0]
		mi.material_override = nappes[i][1]
		mi.visible = nappes[i][2]


func nappes() -> Array:
	return _eaux.get_children()


## LA SALLE (Jordan, 2 octobre 2026) — la règle vit dans le cœur (`FS.salle`).
func _est_salle() -> bool:
	return outil == "forme" and forme_speciale["quoi"] == "salle"


## ⚠ LE CŒUR N'EST RAPPELÉ QUE QUAND UN COIN, LES ÉTAGES OU LE SENS CHANGENT : une grande salle compte des milliers
## de cases, et la refaire à chaque pixel ferait ramer la souris.
func _salle_entre(a: Vector3i, b: Vector3i) -> Dictionary:
	var cle := "%s|%s|%s|%s|%s" % [a, b, forme_speciale["etages"], forme_speciale["vers_le_haut"],
		cases().get_instance_id() if cases() != null else 0]
	if cle != _cle_salle:
		_cle_salle = cle
		_salle_vue = FS.salle(_occupees_actives(), a, b, int(forme_speciale["etages"]),
			bool(forme_speciale["vers_le_haut"]))
	return _salle_vue


## L'aperçu : la coque à poser en vert, la roche à creuser en rouge, et la boîte de la salle.
func _survoler_salle(position: Vector2) -> void:
	var c = case_sous(position)
	if _coin_boite == null:
		_boite_vue.visible = false
		_remplir(_ancre_vue, [], TEINTE_CREUSER)
		_remplir(_apercu, [c] if c != null else [], TEINTE_AJOUTER)
		return
	if c != null:
		_coin_fin = c
	var r := _salle_entre(_coin_boite, _coin_fin)
	if r["erreur"] != "":
		_boite_vue.visible = false
		_remplir(_ancre_vue, [], TEINTE_CREUSER)
		_remplir(_apercu, [_coin_boite, _coin_fin], TEINTE_CREUSER)
		return
	_remplir(_apercu, r["poser"].keys(), TEINTE_AJOUTER)
	_remplir(_ancre_vue, r["effacer"].keys(), TEINTE_CREUSER)
	var bas: Vector3i = r["boite"][0]
	var haut: Vector3i = r["boite"][1]
	var taille_boite := Vector3(haut - bas + Vector3i.ONE)
	_boite_vue.scale = taille_boite
	_boite_vue.position = Vector3(bas) + taille_boite * 0.5
	_boite_vue.visible = true


func _finir_salle() -> void:
	var r := _salle_entre(_coin_boite, _coin_fin)
	_coin_boite = null
	_coin_fin = null
	_cle_salle = ""
	_boite_vue.visible = false
	_remplir(_ancre_vue, [], TEINTE_CREUSER)
	if r["erreur"] != "":
		forme_dite.emit(r["erreur"], r)
		return
	forme_posee.emit({"poser": r["poser"], "effacer": r["effacer"]}, "salle", r)


func oublier_ancre() -> void:
	if ancre_forme.is_empty():
		return
	ancre_forme = {}
	_cle_forme = ""
	_montrer_ancre()
	forme_dite.emit("ancre_oubliee", {})
	rafraichir()


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
	_cle_forme = ""   # le monde a pu changer : l'aperçu d'une forme se recalcule
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
## La sphère du bras-ressort : plus que le demi-plan proche de la caméra (~0,08 en diagonale), et
## ⚠ PLUS FINE QUE LA CAPSULE du personnage (0,19) : centrée sur sa tête, elle tient DANS la capsule, qui
## ne pénètre jamais le décor — donc le lancer ne part jamais de la roche. Il ignorerait sinon la paroi
## où il commence (`cast_motion` ne voit pas ce que la forme touche déjà).
const RAYON_DU_BRAS := 0.15
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
	personnage.surface_eau = surface_eau_au_point
	_orbite_d_avant = [_cible, _azimut, _elevation, _distance]
	_elevation = CAMERA_ELEVATION
	_distance = CAMERA_DISTANCE
	personnage.cap_camera = _azimut
	# Le halo des yeux violets : allumé pour le jeu seulement, il changerait le jugement des teintes.
	_env.glow_enabled = true
	_env.glow_intensity = 0.9
	_env.glow_bloom = 0.05
	_env.glow_hdr_threshold = 1.0
	_env.background_mode = Environment.BG_SKY
	_env.sky.sky_material = _ciel_du_jeu
	_sous_l_eau = false
	_appliquer_tout_le_rendu()
	_appliquer_meteo()
	_suivre(0.0)
	return ""


func finir_partie() -> void:
	_rendre_la_souris()
	if personnage != null:
		personnage.queue_free()
		personnage = null
	if _decor != null:
		_decor.queue_free()
		_decor = null
	if _meteo_noeud != null:
		_meteo_noeud.queue_free()
		_meteo_noeud = null
	if _env != null:
		_sous_l_eau = false
		_rendre_le_travail()
		_env.background_mode = Environment.BG_COLOR
		_env.sky.sky_material = _ciel_neutre
	if not _orbite_d_avant.is_empty():
		_cible = _orbite_d_avant[0]
		_azimut = _orbite_d_avant[1]
		_elevation = _orbite_d_avant[2]
		_distance = _orbite_d_avant[3]
		_orbite_d_avant = []
		_caler()


## Le mode vol du personnage (F). Rend vrai s'il vole désormais.
func basculer_vol() -> bool:
	if personnage == null:
		return false
	personnage.basculer_vol()
	return personnage.vol


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
	# ⚠ UN RELÂCHÉ PERDU (fenêtre qui perd la main, Alt+Tab) laisserait la souris capturée pour de bon.
	if _souris_avant_capture != Vector2.INF and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
			and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_rendre_la_souris()
	var focus := get_viewport().gui_get_focus_owner()
	var libre :=not (focus is LineEdit or focus is TextEdit) and is_visible_in_tree()
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
	# EN VOL : Espace ou E montent, A descend (Q / E sur un QWERTY) — les touches de Navigate.
	var monter := 0.0
	if libre:
		if Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_E):
			monter += 1.0
		if Input.is_physical_key_pressed(KEY_Q):
			monter -= 1.0
	personnage.monter = monter
	personnage.saut = libre and Input.is_physical_key_pressed(KEY_SPACE)
	personnage.course = libre and Input.is_physical_key_pressed(KEY_SHIFT)
	personnage.cap_camera = _azimut
	if personnage.global_position.y < _plus_bas - CHUTE:
		reapparaitre()
	_suivre(get_process_delta_time())
	# SOUS L'EAU, LA CAMÉRA VOIT À TRAVERS UN VOILE : sans lui, l'œil sous la nappe voit le monde aussi net qu'à
	# l'air libre, et l'on ne sait plus qu'on a plongé.
	var sous := surface_eau_au_point(_camera.global_position) > _camera.global_position.y
	var liquide := liquide_au_point(_camera.global_position) if sous else ""
	if sous != _sous_l_eau or liquide != _liquide_traverse:
		_sous_l_eau = sous
		_liquide_traverse = liquide
		_appliquer_brouillard()
	if _meteo_noeud != null:
		_meteo_noeud.global_position = _camera.global_position


# ── LE RENDU DU PLAY TEST ────────────────────────────────────────────────────────────────────────────

## LES RÉGLAGES QU'ON ESSAIE AU PLAY TEST (Jordan, 1er octobre 2026 : « une barre de droite au mode Play test pour
## activer ou décocher les effets de rendu »). ⚠ LEURS DÉFAUTS SONT LES VALEURS DÉCIDÉES plus haut (soleil, ambiante,
## SSAO, ciel du jeu) : « Reset » rend exactement le rendu de la charte, et une seule source les porte. ⚠ ILS NE
## VALENT QU'AU PLAY TEST : en le quittant, `_rendre_le_travail` rend l'éclairage du travail, quels qu'ils soient —
## World et Witness s'éclairent comme le dit la page 6 du manuel. ⚠ Le SDFGI, écarté du travail (il ne voit pas une
## géométrie qui change), est proposé ici : au Play test, rien ne change pendant qu'on joue.
const REGLAGES_RENDU := [
	{"cle": "soleil_azimut", "groupe": "Light", "nom": "Sun direction", "genre": "curseur", "min": -180.0, "max": 180.0, "pas": 1.0, "defaut": SOLEIL_ROTATION.y},
	{"cle": "soleil_hauteur", "groupe": "Light", "nom": "Sun height", "genre": "curseur", "min": 2.0, "max": 90.0, "pas": 1.0, "defaut": -SOLEIL_ROTATION.x},
	{"cle": "soleil_energie", "groupe": "Light", "nom": "Sun strength", "genre": "curseur", "min": 0.0, "max": 4.0, "pas": 0.05, "defaut": SOLEIL_ENERGIE},
	{"cle": "soleil_couleur", "groupe": "Light", "nom": "Sun colour", "genre": "couleur", "defaut": Color(1, 1, 1)},
	{"cle": "ombres", "groupe": "Light", "nom": "Shadows", "genre": "case", "defaut": true},
	{"cle": "ambiante_couleur", "groupe": "Light", "nom": "Ambient colour", "genre": "couleur", "defaut": AMBIANTE_COULEUR},
	{"cle": "ambiante_energie", "groupe": "Light", "nom": "Ambient strength", "genre": "curseur", "min": 0.0, "max": 3.0, "pas": 0.05, "defaut": AMBIANTE_ENERGIE},
	{"cle": "ciel_haut", "groupe": "Sky", "nom": "Sky, top", "genre": "couleur", "defaut": CIEL_HAUT},
	{"cle": "ciel_horizon", "groupe": "Sky", "nom": "Sky, horizon", "genre": "couleur", "defaut": CIEL_HORIZON},
	{"cle": "ciel_sol", "groupe": "Sky", "nom": "Sky, below", "genre": "couleur", "defaut": CIEL_SOL},
	{"cle": "ssao", "groupe": "Effects", "nom": "SSAO — shade in the hollows", "genre": "case", "defaut": true},
	{"cle": "ssao_intensite", "groupe": "Effects", "nom": "SSAO strength", "genre": "curseur", "min": 0.0, "max": 6.0, "pas": 0.1, "defaut": SSAO_INTENSITE},
	{"cle": "ssil", "groupe": "Effects", "nom": "SSIL — light bouncing nearby", "genre": "case", "defaut": true},
	{"cle": "sdfgi", "groupe": "Effects", "nom": "SDFGI — global illumination", "genre": "case", "defaut": false},
	{"cle": "ssr", "groupe": "Effects", "nom": "SSR — screen reflections", "genre": "case", "defaut": false},
	{"cle": "glow", "groupe": "Effects", "nom": "Glow", "genre": "case", "defaut": true},
	{"cle": "glow_intensite", "groupe": "Effects", "nom": "Glow strength", "genre": "curseur", "min": 0.0, "max": 3.0, "pas": 0.05, "defaut": 0.9},
	{"cle": "brouillard", "groupe": "Effects", "nom": "Fog", "genre": "case", "defaut": false},
	{"cle": "brouillard_densite", "groupe": "Effects", "nom": "Fog density", "genre": "curseur", "min": 0.0, "max": 0.1, "pas": 0.001, "defaut": 0.01},
	{"cle": "brouillard_couleur", "groupe": "Effects", "nom": "Fog colour", "genre": "couleur", "defaut": CIEL_HORIZON},
	{"cle": "brouillard_volumique", "groupe": "Effects", "nom": "Volumetric fog", "genre": "case", "defaut": false},
	{"cle": "volumique_densite", "groupe": "Effects", "nom": "Volumetric density", "genre": "curseur", "min": 0.0, "max": 0.1, "pas": 0.001, "defaut": 0.02},
	{"cle": "tonemap", "groupe": "Camera", "nom": "Tone mapping", "genre": "choix", "choix": ["Linear", "Reinhard", "Filmic", "ACES", "AgX"], "defaut": 0},
	{"cle": "exposition", "groupe": "Camera", "nom": "Exposure", "genre": "curseur", "min": 0.2, "max": 3.0, "pas": 0.05, "defaut": 1.0},
	{"cle": "luminosite", "groupe": "Camera", "nom": "Brightness", "genre": "curseur", "min": 0.5, "max": 2.0, "pas": 0.05, "defaut": 1.0},
	{"cle": "contraste", "groupe": "Camera", "nom": "Contrast", "genre": "curseur", "min": 0.5, "max": 2.0, "pas": 0.05, "defaut": 1.0},
	{"cle": "saturation", "groupe": "Camera", "nom": "Saturation", "genre": "curseur", "min": 0.0, "max": 2.0, "pas": 0.05, "defaut": 1.0},
]
## Les valeurs courantes, clé → valeur.
var rendu := {}
var _sous_l_eau := false
var _liquide_traverse := ""


## Le liquide (le preset de sa couche d'eau) qui contient `p`, ou "" : le voile sous la surface en dépend.
func liquide_au_point(p: Vector3) -> String:
	if eau_du_jeu.is_empty():
		return ""
	var k: Variant = EauMaillage.case_d_eau_au_point(eau_du_jeu["cases"], p)
	if k != null:
		return str(eau_du_jeu["cases"][k])
	return str(eau_du_jeu.get("preset_ocean", "")) if surface_eau_au_point(p) > -INF else ""


# ── LA MÉTÉO DU PLAY TEST ────────────────────────────────────────────────────────────────────────────

## LA MÉTÉO (Jordan, 2 octobre 2026) : juger un monde peint sous différents temps. ⚠ ELLE NE VAUT QU'AU PLAY TEST :
## ni enregistrée dans le projet, ni exportée dans le `.mbworld`, ni dans les greffons — l'écran le dit.
## PROPOSÉ (points ouverts de la charte) : un seul temps à la fois, intensité fixe, sur l'IMAGE seulement (le
## personnage n'est ni poussé ni ralenti), retenu le temps de la session (rendu en rentrant au Play test), « None »
## par Reset.
const METEOS := [["aucune", "None"], ["pluie", "Rain"], ["blizzard", "Blizzard"], ["ouragan", "Hurricane"],
	["neige", "Slow snow"], ["particules", "Hanging particles"], ["chaleur", "Heat"], ["brouillard", "Fog"]]
## Le brouillard qu'un temps impose : [couleur, densité].
const METEO_BROUILLARD := {
	"brouillard": [Color("#9aa3ad"), 0.07],
	"blizzard": [Color("#dfe6ee"), 0.08],
	"ouragan": [Color("#5f6670"), 0.05],
	"pluie": [Color("#7d8794"), 0.02],
	# ⚠ LA CHALEUR N'EST PAS UNE ONDULATION DE L'IMAGE : un quad plein écran relit l'image AVANT que les objets
	# transparents soient dessinés, et il effaçait la lave et la mer (vu à l'image). Une brume chaude à la place.
	"chaleur": [Color("#e3b98a"), 0.018],
}
## Ce que la météo fait au soleil : un FACTEUR sur sa force réglée (le réglage de la barre reste celui de l'artiste).
const METEO_SOLEIL := {"pluie": 0.45, "ouragan": 0.3, "blizzard": 0.5, "brouillard": 0.6, "neige": 0.75,
	"chaleur": 1.2}
## Les particules d'un temps : nombre, durée de vie, demi-boîte d'émission autour de l'œil, vitesse, dispersion
## (degrés), gravité, genre de goutte (« trait », « flocon », « poussiere »), couleur.
## ⚠ DENSES PRÈS DE L'ŒIL : une boîte de 28 cases de côté pour 2 500 gouttes ne montrait qu'une douzaine de traits
## à l'image ; la boîte est resserrée et le nombre monté.
const METEO_PARTICULES := {
	"pluie": [9000, 0.9, Vector3(9, 7, 9), Vector3(0.6, -16, 0.3), 3.0, Vector3(0, -4, 0), "trait", Color(0.78, 0.84, 0.95, 0.5)],
	"ouragan": [12000, 0.6, Vector3(10, 7, 10), Vector3(18, -10, 4), 8.0, Vector3(0, -6, 0), "trait", Color(0.72, 0.76, 0.84, 0.55)],
	"blizzard": [9000, 1.4, Vector3(9, 7, 9), Vector3(8, -2, 3), 25.0, Vector3(0, -0.5, 0), "flocon", Color(1, 1, 1, 0.95)],
	"neige": [5000, 9.0, Vector3(10, 7, 10), Vector3(0.2, -0.9, 0.1), 30.0, Vector3.ZERO, "flocon", Color(1, 1, 1, 0.95)],
	"particules": [2500, 12.0, Vector3(8, 5, 8), Vector3(0.05, 0.03, 0.04), 180.0, Vector3.ZERO, "poussiere", Color(1.0, 0.85, 0.55, 0.85)],
	"chaleur": [1200, 4.0, Vector3(8, 2, 8), Vector3(0, 0.5, 0), 20.0, Vector3.ZERO, "poussiere", Color(1.0, 0.72, 0.42, 0.5)],
}
var meteo := "aucune"
var _meteo_noeud: Node3D


func regler_meteo(m: String) -> void:
	meteo = m
	if personnage != null:
		_appliquer_meteo()


func _appliquer_meteo() -> void:
	if _meteo_noeud != null:
		_meteo_noeud.queue_free()
		_meteo_noeud = null
	# ⚠ « EN JEU » = UN PERSONNAGE, PAS `mode` : `commencer_partie` pose la météo AVANT que l'écran passe la vue en
	# mode « jeu ».
	if personnage != null and meteo != "aucune":
		_meteo_noeud = Node3D.new()
		_meteo_noeud.name = "Meteo"
		_vue.add_child(_meteo_noeud)
		_meteo_noeud.global_position = _camera.global_position
		if METEO_PARTICULES.has(meteo):
			_meteo_noeud.add_child(_particules(METEO_PARTICULES[meteo]))
	_appliquer_brouillard()
	if personnage != null:
		_appliquer_rendu("soleil_energie")


## Des particules qui SUIVENT L'ŒIL : la boîte d'émission bouge avec la caméra, les gouttes déjà lâchées restent
## dans le monde (`local_coords` faux) — on marche sous la pluie, elle ne nous colle pas au visage.
static func _particules(r: Array) -> GPUParticles3D:
	var g := GPUParticles3D.new()
	g.amount = r[0]
	g.lifetime = r[1]
	g.preprocess = r[1]
	g.local_coords = false
	var boite: Vector3 = r[2]
	g.visibility_aabb = AABB(-boite * 2.0, boite * 4.0)
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = boite
	var v: Vector3 = r[3]
	m.direction = v.normalized()
	m.spread = r[4]
	m.initial_velocity_min = v.length() * 0.85
	m.initial_velocity_max = v.length() * 1.15
	m.gravity = r[5]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = r[7]
	var maillage: Mesh
	match r[6]:
		"trait":
			# Une goutte étirée, alignée sur sa vitesse : la pluie oblique de l'ouragan reste oblique.
			m.particle_flag_align_y = true
			var b := BoxMesh.new()
			b.size = Vector3(0.012, 0.45, 0.012)
			maillage = b
		"flocon":
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			mat.albedo_texture = _disque_doux()
			var q := QuadMesh.new()
			q.size = Vector2(0.09, 0.09)
			maillage = q
		_:
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			mat.albedo_texture = _disque_doux()
			mat.emission_enabled = true
			mat.emission = Color(r[7]).lightened(0.2)
			mat.emission_energy_multiplier = 1.5
			var q := QuadMesh.new()
			q.size = Vector2(0.04, 0.04)
			maillage = q
	maillage.surface_set_material(0, mat)
	g.process_material = m
	g.draw_pass_1 = maillage
	return g


## UN FLOCON, UNE POUSSIÈRE : un disque blanc qui s'efface vers son bord (vu à l'image : des carrés, sans lui).
static var _disque: Texture2D


static func _disque_doux() -> Texture2D:
	if _disque == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 32
		tex.height = 32
		_disque = tex
	return _disque


func regler_rendu(cle: String, valeur: Variant) -> void:
	rendu[cle] = valeur
	if personnage != null:
		_appliquer_rendu(cle)


## Tout revient aux valeurs décidées (et s'applique si l'on joue).
func rendu_par_defaut() -> void:
	for r in REGLAGES_RENDU:
		rendu[r["cle"]] = r["defaut"]
	if personnage != null:
		_appliquer_tout_le_rendu()


func _appliquer_tout_le_rendu() -> void:
	for cle in rendu:
		_appliquer_rendu(cle)


func _appliquer_rendu(cle: String) -> void:
	var v: Variant = rendu[cle]
	match cle:
		"soleil_azimut":
			_soleil.rotation_degrees.y = v
		"soleil_hauteur":
			_soleil.rotation_degrees.x = -v
		"soleil_energie":
			# La météo assombrit (ou force) le soleil RÉGLÉ, sans toucher au réglage.
			_soleil.light_energy = float(v) * (float(METEO_SOLEIL.get(meteo, 1.0)) if personnage != null else 1.0)
		"soleil_couleur":
			_soleil.light_color = v
		"ombres":
			_soleil.shadow_enabled = v
		"ambiante_couleur":
			_env.ambient_light_color = v
		"ambiante_energie":
			_env.ambient_light_energy = v
		"ciel_haut":
			_ciel_du_jeu.sky_top_color = v
		"ciel_horizon":
			_ciel_du_jeu.sky_horizon_color = v
			_ciel_du_jeu.ground_horizon_color = v
		"ciel_sol":
			_ciel_du_jeu.ground_bottom_color = v
		"ssao":
			_env.ssao_enabled = v
		"ssao_intensite":
			_env.ssao_intensity = v
		"ssil":
			_env.ssil_enabled = v
		"sdfgi":
			_env.sdfgi_enabled = v
		"ssr":
			_env.ssr_enabled = v
		"glow":
			_env.glow_enabled = v
		"glow_intensite":
			_env.glow_intensity = v
		"brouillard", "brouillard_densite", "brouillard_couleur":
			_appliquer_brouillard()
		"brouillard_volumique":
			_env.volumetric_fog_enabled = v
		"volumique_densite":
			_env.volumetric_fog_density = v
		"tonemap":
			_env.tonemap_mode = int(v)
		"exposition":
			_env.tonemap_exposure = v
		"luminosite", "contraste", "saturation":
			_env.adjustment_enabled = true
			_env.adjustment_brightness = rendu.get("luminosite", 1.0)
			_env.adjustment_contrast = rendu.get("contraste", 1.0)
			_env.adjustment_saturation = rendu.get("saturation", 1.0)


## ⚠ LE VOILE SOUS L'EAU L'EMPORTE SUR LE BROUILLARD CHOISI, et le rend en remontant : un seul endroit décide du
## brouillard, sinon le voile éteignait celui de l'artiste en sortant de l'eau.
## ⚠ UN SEUL ENDROIT DÉCIDE DU BROUILLARD, DANS CET ORDRE : sous une nappe, le voile de SON liquide ; sinon le
## brouillard de la MÉTÉO (Fog, Blizzard, Hurricane, Rain) ; sinon celui de la barre de rendu.
func _appliquer_brouillard() -> void:
	if _sous_l_eau:
		var v: Array = EauPresets.VOILES.get(_liquide_traverse, [VOILE_COULEUR, VOILE_DENSITE])
		_env.fog_enabled = true
		_env.fog_light_color = v[0]
		_env.fog_density = v[1]
		_env.fog_sky_affect = 1.0
	elif personnage != null and METEO_BROUILLARD.has(meteo):
		var b: Array = METEO_BROUILLARD[meteo]
		_env.fog_enabled = true
		_env.fog_light_color = b[0]
		_env.fog_density = b[1]
		_env.fog_sky_affect = 0.8
	else:
		_env.fog_enabled = personnage != null and bool(rendu.get("brouillard", false))
		_env.fog_light_color = rendu.get("brouillard_couleur", CIEL_HORIZON)
		_env.fog_density = rendu.get("brouillard_densite", 0.01)
		_env.fog_sky_affect = 0.5


## L'ÉCLAIRAGE DU TRAVAIL (World, Witness) : celui de la charte, quoi qu'on ait essayé au Play test.
func _rendre_le_travail() -> void:
	_soleil.rotation_degrees = SOLEIL_ROTATION
	_soleil.light_energy = SOLEIL_ENERGIE
	_soleil.light_color = Color(1, 1, 1)
	_soleil.shadow_enabled = true
	_env.ambient_light_color = AMBIANTE_COULEUR
	_env.ambient_light_energy = AMBIANTE_ENERGIE
	_env.ssao_enabled = true
	_env.ssao_intensity = SSAO_INTENSITE
	_env.ssil_enabled = true
	_env.sdfgi_enabled = false
	_env.ssr_enabled = false
	_env.glow_enabled = false
	_env.fog_enabled = false
	_env.volumetric_fog_enabled = false
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.tonemap_exposure = 1.0
	_env.adjustment_enabled = false


## La surface de l'eau au-dessus de `p`, −INF hors de l'eau (la règle vit dans le cœur, `EauMaillage`).
func surface_eau_au_point(p: Vector3) -> float:
	if eau_du_jeu.is_empty():
		return -INF
	return EauMaillage.niveau_au_point(eau_du_jeu["cases"], eau_du_jeu["oceans"], eau_du_jeu["boite"], p)


## LA CAMÉRA À LA TROISIÈME PERSONNE, TENUE PAR UN BRAS-RESSORT — DEMANDÉ PAR JORDAN (29 septembre 2026) :
## « une collision avec un spring arm pour que ça ne passe jamais à travers le décor ».
##
## ⚠ **UNE SPHÈRE, PAS UN RAYON.** Le rayon d'avant ne voyait que l'axe : l'œil s'arrêtait juste devant
## la paroi, mais le plan proche de la caméra, lui, a une largeur — il la traversait, et l'on voyait
## l'intérieur de la roche. On lance une SPHÈRE du rayon du plan proche (`RAYON_DU_BRAS`), du personnage
## vers l'œil, contre le décor ; la caméra se pose là où la sphère a dû s'arrêter.
## ⚠ **RENTRER TOUT DE SUITE, RESSORTIR EN DOUCEUR** : le ressort. Rentrer en retard, c'est passer une
## image à travers la paroi ; ressortir d'un coup, c'est un saut de caméra à chaque pilier franchi.
## ⚠ **LE PIVOT LISSÉ PEUT ÊTRE DANS LA ROCHE** : `_cible` suit la tête avec retard, et dans un virage
## serré, sous un plafond, il reste une image derrière une arête. Le bras partait de lui, donc de la roche,
## et ignorait la paroi où il commençait. On lance d'abord la sphère de la VRAIE tête (libre par
## construction, voir `RAYON_DU_BRAS`) vers le pivot lissé : le pivot s'arrête avant la paroi.
func _suivre(dt: float) -> void:
	var tete := personnage.global_position + Vector3.UP * CAMERA_HAUTEUR
	_cible = tete if dt <= 0.0 else _cible.lerp(tete, minf(1.0, 18.0 * dt))
	var direction := Vector3(cos(_elevation) * sin(_azimut), sin(_elevation), cos(_elevation) * cos(_azimut))
	var pivot := _cible
	var libre := _distance
	# ⚠ `find_world_3d()`, PAS `world_3d` : sur un SubViewport qui a son propre monde, `world_3d` est NUL.
	# Le rayon de caméra d'avant ne tournait donc JAMAIS — et rien ne le disait.
	var monde_3d := _vue.find_world_3d()
	var espace := monde_3d.direct_space_state if monde_3d != null else null
	if espace != null:
		pivot = tete + (_cible - tete) * _course_libre(espace, tete, _cible - tete)
		libre = _distance * _course_libre(espace, pivot, direction * _distance)
	# Le ressort : rentrer sans délai, ressortir en douceur.
	if dt <= 0.0 or libre < _bras:
		_bras = libre
	else:
		_bras = minf(libre, lerpf(_bras, libre, minf(1.0, 6.0 * dt)))
	_camera.look_at_from_position(pivot + direction * _bras, pivot, Vector3.UP)


## La part libre (0..1) d'un déplacement de la sphère du bras contre le décor du jeu.
static func _course_libre(espace: PhysicsDirectSpaceState3D, depuis: Vector3, deplacement: Vector3) -> float:
	if deplacement.length_squared() < 1e-10:
		return 1.0
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RAYON_DU_BRAS
	q.shape = sphere
	q.transform = Transform3D(Basis(), depuis)
	q.motion = deplacement
	q.collision_mask = 2
	var r := espace.cast_motion(q)
	return 1.0 if r.is_empty() else r[0]


## Où était le curseur quand le glissé a commencé (coordonnées de la fenêtre) ; INF hors d'un glissé.
var _souris_avant_capture := Vector2.INF


## DEMANDÉ PAR JORDAN (1er octobre 2026) : en Play test, la souris ne sort pas de la fenêtre quand on
## tient le clic pour s'orienter. Pendant le glissé elle est CAPTURÉE (cachée, les mouvements relatifs
## continuent sans bord) ; au relâché elle reparaît là où le glissé a commencé.
## ⚠ PAS « CONFINED » : coincé au bord de la fenêtre, le curseur ne rend plus de mouvement, la caméra s'arrête.
func _capturer_la_souris() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	_souris_avant_capture = get_viewport().get_mouse_position()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _rendre_la_souris() -> void:
	if _souris_avant_capture == Vector2.INF:
		return
	var ou := _souris_avant_capture
	_souris_avant_capture = Vector2.INF
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.warp_mouse(ou)


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
			if b.button_index == MOUSE_BUTTON_LEFT or b.button_index == MOUSE_BUTTON_RIGHT:
				_capturer_la_souris()
		elif b.button_index == MOUSE_BUTTON_LEFT or b.button_index == MOUSE_BUTTON_RIGHT:
			if (b.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT)) == 0:
				_rendre_la_souris()
	elif event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		if (m.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_azimut -= m.relative.x * 0.008
			_elevation = clampf(_elevation + m.relative.y * 0.006, ELEVATION_MINI, ELEVATION_MAXI)
		elif (m.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
			_azimut -= m.relative.x * 0.008
