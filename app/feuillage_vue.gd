extends Node3D
## LE FEUILLAGE À L'ÉCRAN — les plants posés dans le monde (atelier Foliage, 6 octobre 2026). La règle est dans le cœur
## (`feuillage.gd`) ; ici, on charge les `.glb`, on les dessine en MULTIMESH (un par partie de modèle : des milliers
## d'arbres coûtent quelques appels de dessin), et ils BOUGENT DANS LE VENT.
##
## ⚠ LE VENT EST UN SHADER, PAS L'ANIMATION DU FICHIER (PROPOSÉ) : Jordan veut « du décor d'arbres animé » pour ses
## devlogs. Un balancement en espace MONDE, proportionnel au carré de la hauteur au-dessus du SOL du plant, marche sur
## n'importe quel arbre, sans squelette, et reste une MultiMesh. Chaque matériau du fichier est REPRIS dans ce shader
## (couleur, image, couleur de sommet, découpe ou mélange alpha, rugosité, métal, normale) : il garde son aspect.
## Ce que chaque plant porte (INSTANCE_CUSTOM) : x le sol (y monde), y sa hauteur au-dessus du sol, z une phase (deux
## arbres voisins ne se balancent pas ensemble), w l'amplitude de son modèle. Une hauteur nulle : immobile.
## ⚠ L'animation PROPRE du fichier (un squelette, une `AnimationPlayer`) n'est pas jouée : OUVERT.

const FE := preload("res://addons/marchingblocks_core/feuillage.gd")

## La direction du vent, dans le plan (PROPOSÉ).
const SENS_DU_VENT := Vector2(1.0, 0.35)

## Le cache des modèles chargés : chemin → {"parties": [[Mesh, Transform3D, [Material, …]], …], "aabb", "erreur",
## "date"} — relu si le fichier a changé.
static var _charges := {}
static var _shaders := {}

## id du modèle → [MultiMeshInstance3D, …] (une par partie).
var _multimeshes := {}
var _fantome: Node3D
var _anneaux: MeshInstance3D


func _ready() -> void:
	_fantome = Node3D.new()
	_fantome.name = "Fantome"
	add_child(_fantome)
	_anneaux = MeshInstance3D.new()
	_anneaux.name = "Anneaux"
	_anneaux.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_anneaux.material_override = m
	add_child(_anneaux)


# ── LE CHARGEMENT ────────────────────────────────────────────────────────────────────────────────────

## Le modèle d'un `.glb` : ses parties (maillage, pose dans le modèle, matériaux de ses surfaces), sa boîte. Mis en cache.
static func charger(chemin: String) -> Dictionary:
	var date := FileAccess.get_modified_time(chemin) if FileAccess.file_exists(chemin) else -1
	if _charges.has(chemin) and _charges[chemin]["date"] == date:
		return _charges[chemin]
	var d := {"parties": [], "aabb": AABB(), "erreur": "", "date": date}
	if date < 0:
		d["erreur"] = "file not found"
		_charges[chemin] = d
		return d
	var doc := GLTFDocument.new()
	var etat := GLTFState.new()
	var e := doc.append_from_file(chemin, etat)
	if e != OK:
		d["erreur"] = "not a readable glTF file (error %d)" % e
		_charges[chemin] = d
		return d
	var scene := doc.generate_scene(etat)
	if scene == null:
		d["erreur"] = "the file has no scene"
		_charges[chemin] = d
		return d
	var premiere := true
	for n in _descendants(scene):
		var mesh = n.get("mesh") if n is Node3D else null
		if mesh is ImporterMesh:
			mesh = (mesh as ImporterMesh).get_mesh()
		if not mesh is Mesh or (mesh as Mesh).get_surface_count() == 0:
			continue
		var pose := _pose_dans(n as Node3D, scene)
		var mats: Array = []
		for s in (mesh as Mesh).get_surface_count():
			var mat: Material = null
			if n is MeshInstance3D:
				mat = (n as MeshInstance3D).get_surface_override_material(s)
			if mat == null:
				mat = (mesh as Mesh).surface_get_material(s)
			mats.append(mat)
		d["parties"].append([mesh, pose, mats])
		var boite: AABB = pose * (mesh as Mesh).get_aabb()
		d["aabb"] = boite if premiere else (d["aabb"] as AABB).merge(boite)
		premiere = false
	scene.free()
	if d["parties"].is_empty():
		d["erreur"] = "the file has no mesh"
	_charges[chemin] = d
	return d


static func _descendants(n: Node) -> Array:
	var sortie: Array = [n]
	for c in n.get_children():
		sortie.append_array(_descendants(c))
	return sortie


static func _pose_dans(n: Node3D, racine: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != racine:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


## Les réglages qu'on déduit d'un modèle chargé : posé sur sa base (son point le plus bas au sol), une empreinte d'un
## peu plus du tiers de sa plus grande largeur (les couronnes de deux arbres voisins se frôlent), sa hauteur.
static func reglages_par_defaut(d: Dictionary) -> Dictionary:
	var b: AABB = d["aabb"]
	return {"decalage": -b.position.y, "rayon": maxf(0.05, 0.35 * maxf(b.size.x, b.size.z)), "hauteur": b.end.y}


# ── LE VENT ──────────────────────────────────────────────────────────────────────────────────────────

const CODE_VENT := """
shader_type spatial;
render_mode world_vertex_coords, @CULL@;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform bool a_texture = false;
uniform bool couleur_sommet = false;
uniform float rugosite = 1.0;
uniform sampler2D tex_rugosite : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 canal_rugosite = vec4(0.0, 1.0, 0.0, 0.0);
uniform bool a_rugosite = false;
uniform float metal = 0.0;
uniform sampler2D tex_metal : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 canal_metal = vec4(0.0, 0.0, 1.0, 0.0);
uniform bool a_metal = false;
uniform sampler2D tex_normale : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool a_normale = false;
uniform float force_normale = 1.0;
uniform float seuil_alpha = 0.5;
uniform vec2 sens_vent = vec2(1.0, 0.35);

void vertex() {
	float haut = INSTANCE_CUSTOM.y;
	if (haut > 0.0) {
		float h = clamp((VERTEX.y - INSTANCE_CUSTOM.x) / haut, 0.0, 1.0);
		float phase = INSTANCE_CUSTOM.z;
		float ampleur = INSTANCE_CUSTOM.w * haut * 0.05;
		float t = TIME;
		// le balancement : penché sous le vent, deux rafales qui ne se répètent pas ensemble
		float b = 0.35 + 0.6 * sin(t * 1.1 + phase) + 0.3 * sin(t * 2.3 + phase * 1.7);
		VERTEX.xz += normalize(sens_vent) * b * ampleur * h * h;
		// le frisson des feuilles, plus fort en haut
		VERTEX += NORMAL * sin(t * 7.0 + dot(VERTEX, vec3(2.1, 1.7, 2.9))) * 0.015 * INSTANCE_CUSTOM.w * h;
	}
}

void fragment() {
	vec4 c = albedo;
	if (a_texture) { c *= texture(tex_albedo, UV); }
	if (couleur_sommet) { c *= COLOR; }
	ALBEDO = c.rgb;
	@ALPHA@
	ROUGHNESS = rugosite * (a_rugosite ? dot(texture(tex_rugosite, UV), canal_rugosite) : 1.0);
	METALLIC = metal * (a_metal ? dot(texture(tex_metal, UV), canal_metal) : 1.0);
	if (a_normale) { NORMAL_MAP = texture(tex_normale, UV).rgb; NORMAL_MAP_DEPTH = force_normale; }
}
"""


## Le shader du vent pour un face-arrière (« back », « disabled », « front ») et une transparence (« opaque »,
## « decoupe », « melange ») — en cache : un shader par combinaison.
static func shader_du_vent(cull: String, alpha: String) -> Shader:
	var cle := cull + "|" + alpha
	if not _shaders.has(cle):
		var s := Shader.new()
		s.code = CODE_VENT.replace("@CULL@", "cull_" + cull).replace("@ALPHA@", {
			"opaque": "",
			"decoupe": "ALPHA = c.a; ALPHA_SCISSOR_THRESHOLD = seuil_alpha;",
			"melange": "ALPHA = c.a;"}[alpha])
		_shaders[cle] = s
	return _shaders[cle]


## Le matériau d'une surface, repris dans le shader du vent. Un matériau qui n'est pas standard (un shader du
## fichier — ce qui n'arrive pas avec un .glb) garde son aspect sans vent.
static func materiau_du_vent(m: Material) -> Material:
	if m != null and not m is BaseMaterial3D:
		return m
	var s := m as BaseMaterial3D
	var cull := "back"
	var alpha := "opaque"
	if s != null:
		cull = {BaseMaterial3D.CULL_DISABLED: "disabled", BaseMaterial3D.CULL_FRONT: "front"}.get(s.cull_mode, "back")
		if s.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
			alpha = "decoupe"
		elif s.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_HASH,
				BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS]:
			alpha = "melange"
	var v := ShaderMaterial.new()
	v.shader = shader_du_vent(cull, alpha)
	v.set_shader_parameter("sens_vent", SENS_DU_VENT)
	if s == null:
		v.set_shader_parameter("albedo", Color(0.8, 0.8, 0.8))
		return v
	v.set_shader_parameter("albedo", s.albedo_color)
	v.set_shader_parameter("a_texture", s.albedo_texture != null)
	v.set_shader_parameter("tex_albedo", s.albedo_texture)
	v.set_shader_parameter("couleur_sommet", s.vertex_color_use_as_albedo)
	v.set_shader_parameter("rugosite", s.roughness)
	v.set_shader_parameter("a_rugosite", s.roughness_texture != null)
	v.set_shader_parameter("tex_rugosite", s.roughness_texture)
	v.set_shader_parameter("canal_rugosite", _canal(s.roughness_texture_channel))
	v.set_shader_parameter("metal", s.metallic)
	v.set_shader_parameter("a_metal", s.metallic_texture != null)
	v.set_shader_parameter("tex_metal", s.metallic_texture)
	v.set_shader_parameter("canal_metal", _canal(s.metallic_texture_channel))
	v.set_shader_parameter("a_normale", s.normal_enabled and s.normal_texture != null)
	v.set_shader_parameter("tex_normale", s.normal_texture)
	v.set_shader_parameter("force_normale", s.normal_scale)
	v.set_shader_parameter("seuil_alpha", s.alpha_scissor_threshold)
	return v


static func _canal(c: int) -> Vector4:
	return [Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1),
		Vector4(0.299, 0.587, 0.114, 0)][clampi(c, 0, 4)]


## Les maillages du vent d'un modèle chargé, une fois par modèle (un par partie) : une COPIE de chaque maillage dont
## chaque surface porte son matériau repris dans le shader du vent. ⚠ Une MultiMesh n'a pas de matériau par surface
## (seulement une surcharge pour tout le maillage) : c'est le maillage qui les porte.
static func maillages_du_vent(d: Dictionary) -> Array:
	if not d.has("vent"):
		var sortie: Array = []
		for partie in d["parties"]:
			var source: Mesh = partie[0]
			var copie := ArrayMesh.new()
			for s in source.get_surface_count():
				copie.add_surface_from_arrays(source.surface_get_primitive_type(s), source.surface_get_arrays(s))
				copie.surface_set_material(s, materiau_du_vent(partie[2][s]))
			sortie.append(copie)
		d["vent"] = sortie
	return d["vent"]


# ── LES PLANTS ───────────────────────────────────────────────────────────────────────────────────────

## Tout le feuillage : `modeles` [{id, chemin, …}], `plants` [{modele, p, lacet, echelle}, …]. Un modèle dont le fichier
## manque ne dessine rien (l'atelier le dit).
func poser(modeles: Array, plants: Array) -> void:
	var par_modele := {}
	for m in modeles:
		par_modele[m["id"]] = []
	for pl in plants:
		if par_modele.has(pl["modele"]):
			(par_modele[pl["modele"]] as Array).append(pl)
	for id in _multimeshes.keys():
		if not par_modele.has(id):
			for mmi in _multimeshes[id]:
				(mmi as Node).queue_free()
			_multimeshes.erase(id)
	for m in modeles:
		poser_modele(m, par_modele[m["id"]])


## Les plants d'UN modèle (un coup de pinceau ne refait que lui).
func poser_modele(m: Dictionary, plants: Array) -> void:
	var d := charger(str(m["chemin"]))
	var id: int = m["id"]
	var parties: Array = d["parties"]
	var mmis: Array = _multimeshes.get(id, [])
	while mmis.size() > parties.size():
		(mmis.pop_back() as Node).queue_free()
	var maillages := maillages_du_vent(d)
	while mmis.size() < parties.size():
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = maillages[mmis.size()]
		mmi.multimesh = mm
		add_child(mmi)
		mmis.append(mmi)
	_multimeshes[id] = mmis
	for k in parties.size():
		var mm := (mmis[k] as MultiMeshInstance3D).multimesh
		mm.mesh = maillages[k]
		var inst := instances(m, plants, parties[k][1])
		mm.instance_count = plants.size()
		for i in plants.size():
			mm.set_instance_transform(i, inst[0][i])
			mm.set_instance_custom_data(i, inst[1][i])


## CE QUE CHAQUE PLANT DONNE À LA MULTIMESH D'UNE PARTIE : [poses, données du vent]. La pose : celle du plant
## (`FE.transformation`) puis celle de la partie dans le modèle. Le vent : (sol, hauteur au-dessus du sol, phase,
## amplitude). ⚠ SORTI DE `poser_modele` POUR ÊTRE ÉPROUVÉ : sans rendu (headless), une MultiMesh ne rend pas ce
## qu'on lui a donné.
static func instances(m: Dictionary, plants: Array, pose_partie: Transform3D) -> Array:
	var poses: Array = []
	var vent: Array = []
	for pl in plants:
		poses.append(FE.transformation(m, pl) * pose_partie)
		var p: Vector3 = pl["p"]
		vent.append(Color(p.y, FE.hauteur_au_dessus_du_sol(m, pl), fposmod(p.x * 0.37 + p.z * 0.71, TAU),
			float(m["vent"])))
	return [poses, vent]


## Combien de plants de ce modèle sont dessinés (pour les tests).
func nombre_dessine(id: int) -> int:
	if not _multimeshes.has(id) or (_multimeshes[id] as Array).is_empty():
		return 0
	return ((_multimeshes[id] as Array)[0] as MultiMeshInstance3D).multimesh.instance_count


func multimeshes(id: int) -> Array:
	return _multimeshes.get(id, [])


# ── L'APERÇU ─────────────────────────────────────────────────────────────────────────────────────────

## Le modèle en FANTÔME (vert : accepté, rouge : refusé) aux poses données ; [] le cache.
func montrer_fantome(m: Variant, poses: Array, teinte: Color) -> void:
	for c in _fantome.get_children():
		c.queue_free()
	if m == null or poses.is_empty():
		return
	var d := charger(str(m["chemin"]))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(teinte, 0.45)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for partie in d["parties"]:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = partie[0]
		mm.instance_count = poses.size()
		for i in poses.size():
			mm.set_instance_transform(i, (poses[i] as Transform3D) * (partie[1] as Transform3D))
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_fantome.add_child(mmi)


## Des cercles à plat : [[centre, rayon, couleur], …] — l'empreinte, le pinceau.
func montrer_anneaux(anneaux: Array) -> void:
	if anneaux.is_empty():
		_anneaux.mesh = null
		return
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for a in anneaux:
		var c: Vector3 = a[0]
		var r: float = a[1]
		im.surface_set_color(a[2])
		var n := 48
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			im.surface_add_vertex(c + Vector3(cos(a0) * r, 0.03, sin(a0) * r))
			im.surface_add_vertex(c + Vector3(cos(a1) * r, 0.03, sin(a1) * r))
	im.surface_end()
	_anneaux.mesh = im
