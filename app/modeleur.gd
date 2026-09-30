extends Node3D
## LE MODELEUR DU TÉMOIN — l'écran de `maillage_edite.gd` : viser, sélectionner, et les gestes de Blender.
##
## **DÉCIDÉ (Jordan, 29 septembre 2026)** : il REMPLACE Blender. Palier 1 : l'édition de maillage.
##
## Ce nœud vit dans le monde 3D de la vue (`vue.gd`). Il DESSINE le maillage édité (faces teintées,
## arêtes, sommets, sélection en orange) et TRADUIT la souris et le clavier en opérations du cœur. Il ne
## tient pas l'annulation : chaque geste fini émet `change(avant, apres, nom)`, et l'écran l'inscrit dans
## SON historique — un Ctrl+Z pour un geste, comme partout dans l'appli.
##
## ── LES AXES SONT CEUX DE BLENDER ───────────────────────────────────────────────────────────────────
## ⚠ **Z MONTE.** Le témoin arrive dans Blender avec Z en haut : un artiste qui tape « G Z 1 » veut
## monter d'une case. X = X de Godot, Y (Blender, vers l'arrière) = −Z de Godot, Z (Blender) = Y de Godot.
## La traduction vit dans `AXES`, et nulle part ailleurs.

signal change(avant: RefCounted, apres: RefCounted, nom: String)
signal dit(texte: String)

const ME := preload("res://addons/marchingblocks_core/maillage_edite.gd")
const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const Sections := preload("res://addons/marchingblocks_core/sections.gd")

const AXES := {"x": Vector3(1, 0, 0), "y": Vector3(0, 0, -1), "z": Vector3(0, 1, 0)}
const ORANGE := Color(1.0, 0.55, 0.1)
## Rayon de capture d'un clic sur un sommet ou une arête, en pixels.
const CAPTURE := 14.0

var maillage: RefCounted
var camera: Camera3D
## "sommet", "arete" ou "face" — 1, 2, 3.
var mode_sel := "face"
var sel_s := {}
var sel_a := {}
var sel_f := {}
var proportionnel := false
## Alt+Z — le « X-ray » de Blender : la boîte B prend aussi ce qui est caché. Éteint, elle ne prend que ce
## qu'on VOIT (un rayon par élément, contre `lancer_rayon_rapide`).
var rayons_x := false
var rayon_prop := 1.0

## LE GESTE EN COURS : "" (aucun), "G", "R", "S", "I", "bevel" (Ctrl+B), "B" (boîte), "loop" (Ctrl+R),
## "knife" (K).
var modal := ""
var _axe := ""
var _saisie := ""
var _avant: RefCounted          # le maillage d'avant le geste (Échap le rend)
var _depart := PackedVector3Array()
var _ids: Array = []
var _pivot := Vector3.ZERO
var _souris0 := Vector2.ZERO
var souris := Vector2.ZERO
var _nom_geste := ""
var _normale_extrusion := Vector3.ZERO
var _faces_inset: Array = []
var _base_inset: RefCounted
var _coin_boite := Vector2.ZERO
var _anneau_vise: Array = []
var _aretes_biseau: Array = []
## Pour I et Ctrl+B : les faces que l'opération touche (indices du maillage de départ), et leur nombre.
var _faces_touchees: Array = []
var _n_depart := 0
## Les points du couteau posés jusqu'ici : [{"arete", "t", "point"}].
var _couteau: Array = []

## LE DESSIN EN DEUX MORCEAUX PENDANT UN GESTE : ce qui ne bouge pas (dessiné une fois au début), ce qui
## bouge (redessiné à chaque mouvement). ⚠ MESURÉ sur le témoin : un redessin complet coûtait ~250 ms,
## soit quatre images par seconde pour un G qui suit la souris.
var _faces_dyn_mi: MeshInstance3D
var _aretes_dyn_mi: MeshInstance3D
var _faces_mobiles: Array = []
var _aretes_mobiles: Array = []
var _candidats: Array = []
## Les arêtes, gardées tant que la TOPOLOGIE ne change pas (un G ne change que des positions).
var _cache_aretes: Array = []
var _topo_sale := true
var _faces_mi: MeshInstance3D
var _sel_mi: MeshInstance3D
var _aretes_mi: MeshInstance3D
var _sommets_mm: MultiMeshInstance3D
var _apercu_mi: MeshInstance3D

## ── LE TÉMOIN LIÉ (charte §3, une tuile par clé, 30 septembre 2026) ────────────────────────────────
##
## Le modeleur édite LA TUILE DE L'OCCURRENCE VISÉE, dans le repère de référence de sa clé : `maillage` est
## `temoin.tuiles[cle]`, et `pose` dit où l'occurrence active est posée. Tout ce qui dessine l'édition vit
## sous `_edition`, posé à l'occurrence ; toutes les autres occurrences sont dessinées par `_occurrences`,
## une MultiMesh PAR TUILE qui partage le maillage de sa tuile — sculpter l'une les change toutes, à chaque
## mouvement de souris (`_propager`).
## ⚠ **TOUT CE QUI PARLE À LA CAMÉRA PASSE PAR LA POSE** (`_origine`, `_direction`, `_ecran`, `_oeil`,
## `_axe_camera`, `_vers_la_tuile`) : « G Z 1 » monte toujours d'une case DANS LE MONDE, quelle que soit la
## rotation de la copie qu'on sculpte. Sans témoin lié, la pose est l'identité : rien ne change.
## ⚠ Cliquer une occurrence d'une AUTRE tuile change de tuile, et vide la sélection (les indices sont ceux
## d'une tuile) — comme les copies liées de Blender, qu'on édite une à la fois. Une autre occurrence de la
## MÊME tuile garde la sélection.
var temoin: RefCounted
var occurrence := -1
var cle := ""
var pose := Transform3D.IDENTITY
var _edition: Node3D
var _occurrences: Node3D
var _mm_de := {}          # clé → MultiMeshInstance3D
## ── LES SECTIONS PARTAGÉES (charte §3, point 2) ─────────────────────────────────────────────────────
## Pendant G, R et S, un sommet de BORD ne glisse que dans son plan (le long de l'arête s'il en touche deux),
## et entraîne ses correspondants de TOUTES les tuiles — le témoin ne peut plus s'ouvrir sous la main.
## ⚠ PAS pendant une EXTRUSION : elle crée des sommets posés sur ceux qu'elle extrude, qui n'ont pas de
## correspondants ; c'est une affaire de topologie, celle du point 3.
var sections: RefCounted
var _photo := {}             # clé → positions au début du geste (pour rejouer, et pour Échap)
var _touchees := {}          # clé → true : les AUTRES tuiles que le geste peut toucher
var _propages_ici: Array = []   # les sommets de la tuile en édition qui bougent par propagation
var _sections_du_geste := false
var _rang_dans_mm := {}   # occurrence → rang dans la MultiMesh de sa tuile


func _init() -> void:
	name = "Modeleur"
	_edition = Node3D.new()
	_edition.name = "Edition"
	add_child(_edition)
	_occurrences = Node3D.new()
	_occurrences.name = "Occurrences"
	add_child(_occurrences)
	# ⚠ PAS DE `material_override` : chaque surface porte son matériau (`MaillageEdite.vers_array_mesh_de`).
	_faces_mi = MeshInstance3D.new()
	_edition.add_child(_faces_mi)
	_faces_dyn_mi = MeshInstance3D.new()
	_edition.add_child(_faces_dyn_mi)
	_sel_mi = _instance_translucide(Color(ORANGE, 0.35))
	_aretes_mi = MeshInstance3D.new()
	var ma := StandardMaterial3D.new()
	ma.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ma.vertex_color_use_as_albedo = true
	ma.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_aretes_mi.material_override = ma
	_aretes_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_edition.add_child(_aretes_mi)
	_aretes_dyn_mi = MeshInstance3D.new()
	_aretes_dyn_mi.material_override = ma
	_aretes_dyn_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_edition.add_child(_aretes_dyn_mi)
	_sommets_mm = MultiMeshInstance3D.new()
	var boite := BoxMesh.new()
	boite.size = Vector3.ONE * 0.05
	var mb := StandardMaterial3D.new()
	mb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mb.vertex_color_use_as_albedo = true
	boite.material = mb
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = boite
	_sommets_mm.multimesh = mm
	_sommets_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_edition.add_child(_sommets_mm)
	_apercu_mi = MeshInstance3D.new()
	var mp := StandardMaterial3D.new()
	mp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mp.albedo_color = Color(1, 0.9, 0.2)
	mp.no_depth_test = true
	_apercu_mi.material_override = mp
	_edition.add_child(_apercu_mi)


func _instance_translucide(c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_edition.add_child(mi)
	return mi


func charger(m: RefCounted) -> void:
	maillage = m
	_vider_selection()
	redessiner()


## CHARGE UN TÉMOIN LIÉ : une MultiMesh par tuile pour les occurrences, puis l'occurrence `active` en édition.
func charger_temoin(t: RefCounted, active := 0) -> void:
	temoin = t
	for enfant in _occurrences.get_children():
		enfant.queue_free()
	_mm_de = {}
	_rang_dans_mm = {}
	var par_cle := {}
	for i in t.occurrences.size():
		var c: String = t.occurrences[i]["cle"]
		if not par_cle.has(c):
			par_cle[c] = []
		_rang_dans_mm[i] = (par_cle[c] as Array).size()
		par_cle[c].append(i)
	for c in par_cle:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = t.tuiles[c].vers_array_mesh()
		mm.instance_count = (par_cle[c] as Array).size()
		for k in (par_cle[c] as Array).size():
			mm.set_instance_transform(k, t.occurrences[par_cle[c][k]]["pose"])
		mmi.multimesh = mm
		_occurrences.add_child(mmi)
		_mm_de[c] = mmi
	occurrence = -1
	cle = ""
	sections = Sections.new(t)
	activer(clampi(active, 0, t.occurrences.size() - 1))


## L'occurrence `i` passe en édition : sa tuile devient `maillage`, et elle est dessinée par `_edition` (on
## la cache dans sa MultiMesh). Changer de TUILE vide la sélection ; une autre occurrence de la même la garde.
func activer(i: int) -> void:
	if temoin == null or i < 0 or i >= temoin.occurrences.size():
		return
	if occurrence >= 0:
		_montrer_l_occurrence(occurrence, true)
	var ancienne := cle
	occurrence = i
	cle = temoin.occurrences[i]["cle"]
	pose = temoin.occurrences[i]["pose"]
	_edition.transform = pose
	_montrer_l_occurrence(i, false)
	maillage = temoin.tuiles[cle]
	if cle != ancienne:
		_vider_selection()
		redessiner()
	else:
		_dessiner_selection()


func _montrer_l_occurrence(i: int, oui: bool) -> void:
	var c: String = temoin.occurrences[i]["cle"]
	if not _mm_de.has(c):
		return
	var t: Transform3D = temoin.occurrences[i]["pose"]
	if not oui:
		t = Transform3D(Basis().scaled(Vector3.ZERO), t.origin)
	(_mm_de[c] as MultiMeshInstance3D).multimesh.set_instance_transform(_rang_dans_mm[i], t)


## LA PROPAGATION : la tuile du témoin EST le maillage édité (un geste peut l'avoir remplacé par une copie),
## et toutes ses occurrences redessinées d'un coup — elles partagent le même maillage Godot.
func _propager() -> void:
	if temoin == null or cle == "":
		return
	temoin.tuiles[cle] = maillage
	if _mm_de.has(cle):
		(_mm_de[cle] as MultiMeshInstance3D).multimesh.mesh = maillage.vers_array_mesh()


## Redessine les occurrences d'une tuile (hors de celle en édition, qui a son propre dessin).
func _rafraichir_tuile(c: String) -> void:
	if _mm_de.has(c):
		(_mm_de[c] as MultiMeshInstance3D).multimesh.mesh = temoin.tuiles[c].vers_array_mesh()


## Pose un maillage tel quel — c'est ce que l'annulation appelle. Avec un témoin lié, `m` porte en méta la
## clé de sa tuile (`instantane`) : c'est CETTE tuile qui est remplacée, où que soit l'édition. Un `TL.Lot`
## en pose plusieurs d'un coup (un geste dont les sections partagées ont entraîné d'autres tuiles).
func remplacer(m: RefCounted) -> void:
	if temoin != null and m is TL.Lot:
		for c in (m as TL.Lot).tuiles:
			temoin.poser_tuile(c, (m as TL.Lot).tuiles[c])
			_rafraichir_tuile(c)
		_rafraichir_les_tuiles_qui_portent(-2)
		if (m as TL.Lot).tuiles.has(cle):
			maillage = temoin.tuiles[cle]
			_vider_selection()
		redessiner()
		return
	if temoin != null and m.has_meta("cle"):
		var c: String = m.get_meta("cle")
		temoin.poser_tuile(c, m)
		if _mm_de.has(c):
			(_mm_de[c] as MultiMeshInstance3D).multimesh.mesh = temoin.tuiles[c].vers_array_mesh()
		# Les matériaux reviennent avec la tuile, et ils sont communs : celles qui en portent se redessinent.
		_rafraichir_les_tuiles_qui_portent(-2)
		if c != cle:
			redessiner()   # la tuile en édition garde sa sélection, mais ses matériaux ont pu revenir
			return
		maillage = temoin.tuiles[c]
	else:
		maillage = m.copie()
	_vider_selection()
	redessiner()


## Une copie du maillage édité, marquée de la clé de sa tuile — ce que l'annulation garde.
func instantane() -> RefCounted:
	var m: RefCounted = maillage.copie()
	if cle != "":
		m.set_meta("cle", cle)
	return m


## Émet un geste fini : `avant` (pris au début) et l'état présent, marqués de la clé de la tuile.
func _emettre(avant: RefCounted, nom: String) -> void:
	if cle != "":
		avant.set_meta("cle", cle)
	change.emit(avant, instantane(), nom)


# ── LA CAMÉRA, VUE DEPUIS LA TUILE ──────────────────────────────────────────────────────────────────

func _origine(p: Vector2) -> Vector3:
	return pose.affine_inverse() * camera.project_ray_origin(p)


func _direction(p: Vector2) -> Vector3:
	return (pose.basis.inverse() * camera.project_ray_normal(p)).normalized()


func _ecran(q: Vector3) -> Vector2:
	return camera.unproject_position(pose * q)


func _oeil() -> Vector3:
	return pose.affine_inverse() * camera.global_position


## Un axe de la caméra (0 = droite, 1 = haut, 2 = vers l'œil), dans le repère de la tuile.
func _axe_camera(i: int) -> Vector3:
	return pose.basis.inverse() * camera.global_transform.basis[i]


## Une direction du monde, dans le repère de la tuile.
func _vers_la_tuile(v: Vector3) -> Vector3:
	return pose.basis.inverse() * v


# ── LE DESSIN ───────────────────────────────────────────────────────────────────────────────────────

func redessiner() -> void:
	if maillage == null:
		return
	_topo_sale = true
	_faces_dyn_mi.mesh = null
	_aretes_dyn_mi.mesh = null
	_faces_mi.mesh = maillage.vers_array_mesh()
	# La grille des rayons est une PHOTO du maillage : elle se rebâtit à chaque changement dessiné.
	maillage.preparer_rayons()
	_propager()
	_dessiner_selection()


func _aretes() -> Array:
	if _topo_sale:
		_cache_aretes = maillage.aretes()
		_topo_sale = false
	return _cache_aretes


## Au début d'un geste : ce qui peut bouger (les sommets choisis, et avec l'édition proportionnelle ceux
## qui sont à portée), les faces et les arêtes qui les touchent ; tout le reste est dessiné UNE fois.
func _preparer_le_geste() -> void:
	var mobiles := {}
	for i in _ids:
		mobiles[i] = true
	_candidats = []
	if proportionnel:
		var loin := 0.0
		for i in _ids:
			loin = maxf(loin, _depart[i].distance_to(_pivot))
		for i in _depart.size():
			if not mobiles.has(i) and _depart[i].distance_to(_pivot) <= loin + rayon_prop:
				_candidats.append(i)
				mobiles[i] = true
	_preparer_les_sections(mobiles)
	for i in _propages_ici:
		mobiles[i] = true
	_faces_mobiles = []
	var statiques: Array = []
	for f in maillage.faces.size():
		var bouge := false
		for i in maillage.faces[f]:
			if mobiles.has(i):
				bouge = true
				break
		if bouge:
			_faces_mobiles.append(f)
		else:
			statiques.append(f)
	_faces_mi.mesh = maillage.vers_array_mesh_de(statiques)
	_aretes_mobiles = []
	var fixes: Array = []
	for e in _aretes():
		if mobiles.has(e.x) or mobiles.has(e.y):
			_aretes_mobiles.append(e)
		else:
			fixes.append(e)
	_aretes_mi.mesh = _lignes(fixes, _aretes_choisies())


## I ET Ctrl+B CHANGENT LA TOPOLOGIE À CHAQUE MOUVEMENT : l'opération est rejouée sur le maillage de départ.
## ⚠ Mais elle ne touche que les faces qui ont un sommet dans `sommets` : le reste est dessiné UNE fois.
## Les faces touchées gardent leur indice, et les faces neuves viennent APRÈS les `_n_depart` anciennes.
func _preparer_le_geste_topologique(sommets: Dictionary) -> void:
	_faces_touchees = []
	var statiques: Array = []
	var aretes_touchees := {}
	for f in maillage.faces.size():
		var touche := false
		for i in maillage.faces[f]:
			if sommets.has(i):
				touche = true
				break
		if touche:
			_faces_touchees.append(f)
			var face: PackedInt32Array = maillage.faces[f]
			for k in face.size():
				aretes_touchees[ME.arete(face[k], face[(k + 1) % face.size()])] = true
		else:
			statiques.append(f)
	_n_depart = maillage.faces.size()
	_faces_mi.mesh = maillage.vers_array_mesh_de(statiques)
	_aretes_mi.mesh = _lignes(_aretes().filter(func(e): return not aretes_touchees.has(e)), {})
	_sel_mi.mesh = null
	_sommets_mm.multimesh.instance_count = 0


func _redessiner_le_geste_topologique() -> void:
	var dyn: Array = _faces_touchees.filter(func(f): return f < maillage.faces.size())
	dyn.append_array(range(_n_depart, maillage.faces.size()))
	_faces_dyn_mi.mesh = maillage.vers_array_mesh_de(dyn)
	var vues := {}
	var liste: Array = []
	for f in dyn:
		var face: PackedInt32Array = maillage.faces[f]
		for k in face.size():
			var e := ME.arete(face[k], face[(k + 1) % face.size()])
			if not vues.has(e):
				vues[e] = true
				liste.append(e)
	_aretes_dyn_mi.mesh = _lignes(liste, {})
	_dessiner_voile()
	_propager()


func _redessiner_le_geste() -> void:
	_faces_dyn_mi.mesh = maillage.vers_array_mesh_de(_faces_mobiles)
	_aretes_dyn_mi.mesh = _lignes(_aretes_mobiles, _aretes_choisies())
	_dessiner_voile()
	_propager()


func _lignes(liste: Array, choisies: Dictionary) -> ArrayMesh:
	var lp := PackedVector3Array()
	var lc := PackedColorArray()
	for e in liste:
		lp.append(maillage.sommets[e.x])
		lp.append(maillage.sommets[e.y])
		var c := ORANGE if choisies.has(e) else Color(0.05, 0.05, 0.06, 0.55)
		lc.append(c)
		lc.append(c)
	return _mesh_de(lp, Mesh.PRIMITIVE_LINES, lc)


func _dessiner_selection() -> void:
	if maillage == null:
		return
	_dessiner_voile()
	_aretes_mi.mesh = _lignes(_aretes(), _aretes_choisies())
	_dessiner_sommets()


## Les faces choisies, un voile orange un cheveu au-dessus de la surface.
func _dessiner_voile() -> void:
	var pos := PackedVector3Array()
	for f in _faces_choisies():
		var face: PackedInt32Array = maillage.faces[f]
		var decal: Vector3 = maillage.normale(f) * 0.004
		for t in maillage.trianguler(f):
			for k in [0, 2, 1]:
				pos.append(maillage.sommets[face[t[k]]] + decal)
	_sel_mi.mesh = _mesh_de(pos, Mesh.PRIMITIVE_TRIANGLES)


## Les sommets : seulement en mode sommet (sinon ils noient tout).
func _dessiner_sommets() -> void:
	var mm := _sommets_mm.multimesh
	if mode_sel == "sommet":
		mm.instance_count = maillage.sommets.size()
		for i in maillage.sommets.size():
			mm.set_instance_transform(i, Transform3D(Basis(), maillage.sommets[i]))
			mm.set_instance_color(i, ORANGE if sel_s.has(i) else Color(0.05, 0.05, 0.06))
	else:
		mm.instance_count = 0


static func _mesh_de(pos: PackedVector3Array, primitive: int, col := PackedColorArray()) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if pos.is_empty():
		return mesh
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = pos
	if not col.is_empty():
		a[Mesh.ARRAY_COLOR] = col
	mesh.add_surface_from_arrays(primitive, a)
	return mesh


# ── LA SÉLECTION ────────────────────────────────────────────────────────────────────────────────────

func _vider_selection() -> void:
	sel_s = {}
	sel_a = {}
	sel_f = {}


## Les sommets que touche la sélection, quel que soit le mode — ce que G, R et S déplacent.
func sommets_choisis() -> Array:
	var d := {}
	match mode_sel:
		"sommet":
			d = sel_s.duplicate()
		"arete":
			for e in sel_a:
				d[e.x] = true
				d[e.y] = true
		"face":
			for f in sel_f:
				for i in maillage.faces[f]:
					d[i] = true
	return d.keys()


func _faces_choisies() -> Array:
	if mode_sel == "face":
		return sel_f.keys()
	# En mode sommet ou arête, une face est choisie quand TOUS ses sommets le sont (comme Blender).
	var s := {}
	for i in sommets_choisis():
		s[i] = true
	var fs: Array = []
	for f in maillage.faces.size():
		var tous := true
		for i in maillage.faces[f]:
			if not s.has(i):
				tous = false
				break
		if tous:
			fs.append(f)
	return fs


func _aretes_choisies() -> Dictionary:
	if mode_sel == "arete":
		return sel_a
	var s := {}
	for i in sommets_choisis():
		s[i] = true
	var d := {}
	for e in _aretes():
		if s.has(e.x) and s.has(e.y):
			d[e] = true
	return d


## 1 2 3 — changer de mode CONVERTIT la sélection (comme Blender) : on ne la perd pas en passant de face
## à sommet.
func choisir_mode(m: String) -> void:
	if m == mode_sel or maillage == null:
		mode_sel = m
		return
	var s := sommets_choisis()
	var d := {}
	for i in s:
		d[i] = true
	mode_sel = m
	_vider_selection()
	match m:
		"sommet":
			sel_s = d
		"arete":
			for e in maillage.aretes():
				if d.has(e.x) and d.has(e.y):
					sel_a[e] = true
		"face":
			for f in maillage.faces.size():
				var tous := true
				for i in maillage.faces[f]:
					tous = tous and d.has(i)
				if tous:
					sel_f[f] = true
	_dessiner_selection()


func tout_choisir(oui: bool) -> void:
	_vider_selection()
	if oui:
		match mode_sel:
			"sommet":
				for i in maillage.sommets.size():
					sel_s[i] = true
			"arete":
				for e in maillage.aretes():
					sel_a[e] = true
			"face":
				for f in maillage.faces.size():
					sel_f[f] = true
	_dessiner_selection()


## Un clic : ce qu'il y a sous la souris, dans le mode courant. ⚠ **ON NE CHOISIT QUE CE QU'ON VOIT** : le
## rayon trouve d'abord la face visible, puis le sommet ou l'arête DE CETTE FACE le plus proche du clic —
## jamais un sommet caché derrière, qui se projetterait au même endroit.
func cliquer(p: Vector2, ajouter: bool, boucle := false) -> void:
	# AVEC UN TÉMOIN LIÉ, on vise d'abord l'OCCURRENCE (toutes les copies, pas seulement celle en édition) :
	# elle passe en édition, et la face touchée est une face de SA tuile.
	var hit: Dictionary
	if temoin != null:
		hit = temoin.rayon(camera.project_ray_origin(p), camera.project_ray_normal(p))
		if not hit.is_empty() and int(hit["occurrence"]) != occurrence:
			activer(int(hit["occurrence"]))
	if not ajouter:
		_vider_selection()
	if temoin == null:
		hit = maillage.lancer_rayon_rapide(_origine(p), _direction(p))
	if hit.is_empty():
		_dessiner_selection()
		return
	var f: int = hit["face"]
	var face: PackedInt32Array = maillage.faces[f]
	match mode_sel:
		"face":
			if boucle:
				var e := _arete_proche(face, p)
				for r in maillage.anneau(e):
					for g in maillage.faces_par_arete().get(ME.arete(r[0], r[1]), []):
						sel_f[g] = true
			else:
				_basculer(sel_f, f, ajouter)
		"arete":
			var e := _arete_proche(face, p)
			if boucle:
				for b in maillage.boucle(e):
					sel_a[b] = true
			else:
				_basculer(sel_a, e, ajouter)
		"sommet":
			if boucle:
				for b in maillage.boucle(_arete_proche(face, p)):
					sel_s[b.x] = true
					sel_s[b.y] = true
			else:
				var meilleur := -1
				var d_min := INF
				for i in face:
					var d: float = _ecran(maillage.sommets[i]).distance_to(p)
					if d < d_min:
						d_min = d
						meilleur = i
				_basculer(sel_s, meilleur, ajouter)
	_dessiner_selection()


static func _basculer(d: Dictionary, k: Variant, ajouter: bool) -> void:
	if ajouter and d.has(k):
		d.erase(k)
	else:
		d[k] = true


func _arete_proche(face: PackedInt32Array, p: Vector2) -> Vector2i:
	var meilleure := Vector2i(face[0], face[1])
	var d_min := INF
	for k in face.size():
		var a := face[k]
		var b := face[(k + 1) % face.size()]
		var pa := _ecran(maillage.sommets[a])
		var pb := _ecran(maillage.sommets[b])
		var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, pa, pb))
		if d < d_min:
			d_min = d
			meilleure = ME.arete(a, b)
	return meilleure


## B — LA BOÎTE : tout ce dont la projection tombe dans le rectangle. ⚠ **ELLE PREND AUSSI CE QUI EST
## CACHÉ**, comme Blender en mode « X-ray » : c'est connu, et dit dans l'aide.
func choisir_dans(r: Rect2) -> void:
	r = r.abs()
	match mode_sel:
		"sommet":
			for i in maillage.sommets.size():
				var p: Vector3 = maillage.sommets[i]
				if r.has_point(_ecran(p)) and _vu(p):
					sel_s[i] = true
		"arete":
			for e in _aretes():
				var a: Vector3 = maillage.sommets[e.x]
				var b: Vector3 = maillage.sommets[e.y]
				if r.has_point(_ecran(a)) and r.has_point(_ecran(b)) \
						and _vu((a + b) * 0.5):
					sel_a[e] = true
		"face":
			for f in maillage.faces.size():
				var c: Vector3 = maillage.centre(f)
				# ⚠ EN X-RAY, LES FACES DE DOS AUSSI (comme Blender) : l'écart de dos n'est qu'une part de « ce qu'on voit ».
				if r.has_point(_ecran(c)) and camera.is_position_in_frustum(pose * c) \
						and (rayons_x or (maillage.normale(f).dot(_vers_l_oeil(c)) > 0.0 and _vu(c))):
					sel_f[f] = true
	_dessiner_selection()


## La direction du point vers l'œil (en orthographique, l'œil est à l'infini derrière l'écran).
func _vers_l_oeil(p: Vector3) -> Vector3:
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return _axe_camera(2)
	return (_oeil() - p).normalized()


## Le point est-il VU ? Toujours vrai en X-ray (Alt+Z).
func _vu(p: Vector3) -> bool:
	if rayons_x:
		return true
	# ⚠ AVEC UN TÉMOIN LIÉ, CE QUI CACHE PEUT ÊTRE UNE AUTRE OCCURRENCE : le rayon interroge tout le témoin
	# (vu rougir dans `fumee_appli` : la seule tuile en édition ne cachait jamais rien).
	if temoin != null:
		var pw: Vector3 = pose * p
		var ow: Vector3 = camera.global_position
		if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
			ow = pw + camera.global_transform.basis.z * 1000.0
		var h: Dictionary = temoin.rayon(ow, pw - ow)
		return h.is_empty() or float(h["distance"]) >= ow.distance_to(pw) - 2e-3
	var oeil: Vector3 = _oeil()
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		oeil = p + _axe_camera(2) * 1000.0
	return maillage.visible_depuis(oeil, p, 2e-3)


# ── LES GESTES ──────────────────────────────────────────────────────────────────────────────────────

## Lance G, R, S (et E, I, qui s'en servent). Rend faux s'il n'y a rien à transformer.
func commencer(geste: String) -> bool:
	if maillage == null or modal != "":
		return false
	var ids := sommets_choisis()
	if ids.is_empty() and geste in ["G", "R", "S", "E", "I", "bevel"]:
		dit.emit("[i]Nothing selected.[/i] Click a face (3), an edge (2) or a vertex (1) first.")
		return false
	_avant = maillage.copie()
	_axe = ""
	_saisie = ""
	_souris0 = souris
	match geste:
		"E":
			_nom_geste = "Extrude"
			if mode_sel == "face":
				var r: Dictionary = maillage.extruder_faces(sel_f.keys())
				_normale_extrusion = r["normale"]
				_ids = r["sommets"]
			elif mode_sel == "arete":
				_normale_extrusion = Vector3.ZERO
				_ids = maillage.extruder_aretes(sel_a.keys())
			else:
				dit.emit("[i]Extrude works on faces (3) or edges (2).[/i]")
				_avant = null
				return false
			modal = "G"
		"bevel":
			_aretes_biseau = _aretes_choisies().keys()
			if _aretes_biseau.is_empty():
				dit.emit("[i]Bevel works on selected edges (2), or on the edges of selected faces.[/i]")
				_avant = null
				return false
			_nom_geste = "Bevel"
			_base_inset = maillage.copie()
			modal = "bevel"
			_ids = ids
			var bouts := {}
			for e in _aretes_biseau:
				bouts[e.x] = true
				bouts[e.y] = true
			_preparer_le_geste_topologique(bouts)
		"I":
			if mode_sel != "face":
				dit.emit("[i]Inset works on faces (3).[/i]")
				_avant = null
				return false
			_nom_geste = "Inset"
			_faces_inset = sel_f.keys()
			_base_inset = maillage.copie()
			modal = "I"
			_ids = ids
			var dans := {}
			for f in _faces_inset:
				for i in maillage.faces[f]:
					dans[i] = true
			_preparer_le_geste_topologique(dans)
		_:
			_nom_geste = {"G": "Move", "R": "Rotate", "S": "Scale"}[geste]
			modal = geste
			_ids = ids
	_depart = maillage.sommets.duplicate()
	# Le PIVOT : la moyenne de ce qu'on transforme (après une extrusion, les sommets neufs, à la place des
	# anciens).
	var c := Vector3.ZERO
	for i in _ids:
		c += _depart[i]
	_pivot = c / maxf(1.0, float(_ids.size()))
	# Une extrusion vient de changer la topologie : le cache d'arêtes est périmé AVANT de préparer le geste.
	_topo_sale = true
	_sections_du_geste = sections != null and modal in ["G", "R", "S"] and _nom_geste != "Extrude"
	if _sections_du_geste:
		sections.indexer()
		_photo = sections.photo()
	if modal in ["G", "R", "S"]:
		_preparer_le_geste()
	if modal == "G" and _nom_geste == "Extrude" and _normale_extrusion != Vector3.ZERO:
		_axe = "normale"
	_mettre_a_jour()
	return true


func _mettre_a_jour() -> void:
	if modal == "bevel":
		maillage = _base_inset.copie()
		var w: float = maxf(0.0, _valeur(_ecart_ecran() / _pixels_par_unite()))
		maillage.biseauter(_aretes_biseau, w)
		_vider_selection()
		_redessiner_le_geste_topologique()
		dit.emit("[b]Bevel[/b]  width %.3f   [i](type a number · Enter or click to confirm · Esc to cancel)[/i]" % w)
		return
	if modal == "I":
		maillage = _base_inset.copie()
		var t: float = maxf(0.0, _valeur(_ecart_ecran() / _pixels_par_unite()))
		maillage.inserer(_faces_inset, t)
		sel_f = {}
		for f in _faces_inset:
			sel_f[f] = true
		_redessiner_le_geste_topologique()
		dit.emit("[b]Inset[/b]  thickness %.3f   [i](type a number · Enter or click to confirm · Esc to cancel)[/i]" % t)
		return
	var t := Transform3D.IDENTITY
	var axe := _direction_d_axe()
	match modal:
		"G":
			var delta := _glissement()
			if _saisie != "":
				delta = (axe if axe != Vector3.ZERO else _vers_la_tuile(AXES["x"])) * _valeur(0.0)
			elif axe != Vector3.ZERO:
				delta = axe * delta.dot(axe)
			t = Transform3D(Basis(), delta)
			dit.emit("[b]%s[/b]  %s   %s" % [_nom_geste, _dire_vecteur(pose.basis * delta), _aide_axe()])
		"R":
			# ⚠ L'ANGLE À L'ÉCRAN, AUTOUR DE L'AXE QUI POINTE VERS L'ŒIL : l'écran a son y vers le bas, donc un
			# angle qui croît y tourne dans le sens HORAIRE, soit −angle autour de l'axe vers l'œil. Un axe
			# imposé qui regarde de l'autre côté inverse le sens, pour que la pièce suive toujours la souris.
			# Tapé, l'angle est en degrés, main droite autour de l'axe (celui de Blender).
			var ps := _ecran(_pivot)
			var vers_oeil := _axe_camera(2)
			var autour: Vector3 = axe if axe != Vector3.ZERO else vers_oeil
			var angle := -((souris - ps).angle() - (_souris0 - ps).angle())
			if autour.dot(vers_oeil) < 0.0:
				angle = -angle
			if _saisie != "":
				angle = deg_to_rad(_valeur(0.0))
			t = Transform3D(Basis(), _pivot) * Transform3D(Basis(autour.normalized(), angle), Vector3.ZERO) 				* Transform3D(Basis(), -_pivot)
			dit.emit("[b]Rotate[/b]  %.1f°   %s" % [rad_to_deg(angle), _aide_axe()])
		"S":
			var ps := _ecran(_pivot)
			var f := souris.distance_to(ps) / maxf(1.0, _souris0.distance_to(ps))
			if _saisie != "":
				f = _valeur(1.0)
			var echelle := Vector3.ONE * f
			if axe != Vector3.ZERO:
				var a := axe.abs()
				echelle = Vector3.ONE + a * (f - 1.0)
			t = Transform3D(Basis(), _pivot) * Transform3D(Basis.from_scale(echelle), Vector3.ZERO) \
				* Transform3D(Basis(), -_pivot)
			dit.emit("[b]Scale[/b]  %.3f   %s" % [f, _aide_axe()])
	maillage.transformer(_ids, t, _depart, rayon_prop if proportionnel else 0.0, _candidats)
	_contraindre_et_propager()
	_redessiner_le_geste()


func _aide_axe() -> String:
	var a: String = {"x": "along X", "y": "along Y", "z": "along Z (up)", "normale": "along the normal", "": ""}[_axe]
	return "[i]%s%s · X Y Z constrain · type a value · Enter / click confirms · Esc cancels%s[/i]" % [
		a, " · typed: " + _saisie if _saisie != "" else "",
		" · proportional %.2f (wheel)" % rayon_prop if proportionnel else ""]


static func _dire_vecteur(v: Vector3) -> String:
	# Dit en axes de BLENDER : x, y = −z de Godot, z = y de Godot.
	return "X %.3f  Y %.3f  Z %.3f" % [v.x, -v.z, v.y]


func _direction_d_axe() -> Vector3:
	if _axe == "normale":
		return _normale_extrusion
	return _vers_la_tuile(AXES.get(_axe, Vector3.ZERO))


## Le déplacement monde qui suit la souris, dans le plan de l'écran passant par le pivot.
func _glissement() -> Vector3:
	var n := -_axe_camera(2)
	var plan := Plane(n, _pivot)
	var p0 = plan.intersects_ray(_origine(_souris0), _direction(_souris0))
	var p1 = plan.intersects_ray(_origine(souris), _direction(souris))
	if p0 == null or p1 == null:
		return Vector3.ZERO
	return p1 - p0


func _ecart_ecran() -> float:
	var ps := _ecran(_pivot)
	return souris.distance_to(ps) - _souris0.distance_to(ps)


func _pixels_par_unite() -> float:
	var droite := _axe_camera(0)
	return maxf(1.0, _ecran(_pivot + droite).distance_to(_ecran(_pivot)))


## Ce qui a été TAPÉ, sinon `defaut`. « -2.5 », « 3 », « . » (rien) acceptés.
func _valeur(defaut: float) -> float:
	if _saisie == "" or _saisie == "-" or _saisie == ".":
		return defaut
	return float(_saisie)


## Au début d'un geste (et quand l'édition proportionnelle change de rayon) : ce que la propagation PEUT
## atteindre depuis les sommets qui bougent — pour ne redessiner que ces tuiles-là à chaque mouvement.
func _preparer_les_sections(mobiles: Dictionary) -> void:
	_touchees = {}
	_propages_ici = []
	if not _sections_du_geste:
		return
	var sonde := {}
	for i in mobiles:
		if sections.est_de_bord(cle, i):
			sonde[i] = Vector3.ONE
	var atteints: Dictionary = sections.propager(cle, sonde)
	for c in atteints:
		if c == cle:
			for i in atteints[c]:
				if not mobiles.has(i):
					_propages_ici.append(i)
		else:
			_touchees[c] = true


## À chaque mouvement : chaque sommet de bord qui a bougé est ramené DANS son plan, et ses correspondants
## suivent — dans la tuile en édition comme dans les autres, toujours depuis les positions de départ.
func _contraindre_et_propager() -> void:
	if not _sections_du_geste:
		return
	var deltas := {}
	for liste in [_ids, _candidats]:
		for i in liste:
			if not sections.est_de_bord(cle, i):
				continue
			var d: Vector3 = sections.projeter(cle, i, maillage.sommets[i] - _depart[i])
			maillage.sommets[i] = _depart[i] + d
			deltas[i] = d
	if deltas.is_empty():
		return
	var r: Dictionary = sections.propager(cle, deltas)
	for i in r.get(cle, {}):
		maillage.sommets[i] = _depart[i] + (r[cle][i] as Vector3)
	r.erase(cle)
	sections.deplacer(r, _photo)
	for c in r:
		_rafraichir_tuile(c)


## LA COMPLÉTION APRÈS UNE COUPE (point 3) : un sommet neuf posé sur un bord est reporté sur chaque face de sa
## classe, dans toutes les tuiles (`Sections.completer`). Rend vrai quand d'autres tuiles ont été coupées — le
## geste est alors émis ici, en UN lot (une annulation pour toutes).
## ⚠ Seuls le loop cut et le couteau passent ici (Jordan, 30 septembre 2026). Extruder, inset, biseau,
## subdiviser sur un bord n'y passent PAS encore : leurs sommets neufs restent sans correspondants.
func _completer_apres(avant_actif: RefCounted, nom: String) -> bool:
	if sections == null:
		return false
	var copies := {}
	var r: Dictionary = sections.completer(func(c: String) -> void:
		if c != cle:
			copies[c] = temoin.tuiles[c].copie())
	if int(r["echecs"]) > 0:
		dit.emit("[color=#e0603c]%d border point(s) could not be carried to a matching tile[/color] — "
			% int(r["echecs"]) + "that border does not run there.")
	if copies.is_empty():
		return false
	var avant := TL.Lot.new()
	var apres := TL.Lot.new()
	avant.tuiles[cle] = avant_actif
	apres.tuiles[cle] = maillage.copie()
	for c in copies:
		avant.tuiles[c] = copies[c]
		apres.tuiles[c] = temoin.tuiles[c].copie()
		_rafraichir_tuile(c)
	change.emit(avant, apres, nom)
	return true


## Un geste qui a touché d'autres tuiles : UNE annulation pour toutes (un `TL.Lot` avant, un après).
func _emettre_le_lot(avant_actif: RefCounted, nom: String) -> void:
	var avant := TL.Lot.new()
	var apres := TL.Lot.new()
	avant.tuiles[cle] = avant_actif
	apres.tuiles[cle] = maillage.copie()
	for c in _touchees:
		var a: RefCounted = temoin.tuiles[c].copie()
		a.sommets = (_photo[c] as PackedVector3Array).duplicate()
		avant.tuiles[c] = a
		apres.tuiles[c] = temoin.tuiles[c].copie()
	change.emit(avant, apres, nom)


func confirmer() -> void:
	if modal == "" or _avant == null:
		return
	modal = ""
	var avant: RefCounted = _avant
	_avant = null
	if _sections_du_geste and not _touchees.is_empty():
		_emettre_le_lot(avant, _nom_geste)
	else:
		_emettre(avant, _nom_geste)
	_sections_du_geste = false
	dit.emit("[b]%s[/b] done. [i]Ctrl+Z undoes it.[/i]" % _nom_geste)
	redessiner()


func annuler() -> void:
	if modal == "":
		return
	if _avant != null:
		maillage = _avant
	if _sections_du_geste:
		for c in _touchees:
			temoin.tuiles[c].sommets = (_photo[c] as PackedVector3Array).duplicate()
			_rafraichir_tuile(c)
		_sections_du_geste = false
	modal = ""
	_avant = null
	_apercu_mi.mesh = null
	redessiner()
	dit.emit("[i]Cancelled.[/i]")


## Une opération d'un coup (sans suivre la souris) : X, M, F, subdiviser, Ctrl+R au clic.
func operer(nom: String) -> void:
	if maillage == null or modal != "":
		return
	var avant: RefCounted = maillage.copie()
	var libelle := ""
	match nom:
		"supprimer":
			libelle = "Delete"
			match mode_sel:
				"face":
					maillage.supprimer_faces(sel_f.keys())
				"arete":
					maillage.supprimer_aretes(sel_a.keys())
				"sommet":
					maillage.supprimer_sommets(sel_s.keys())
			_vider_selection()
		"fusionner":
			libelle = "Merge at center"
			var i: int = maillage.fusionner(sommets_choisis())
			_vider_selection()
			if i >= 0 and mode_sel == "sommet":
				sel_s[i] = true
		"remplir":
			libelle = "Fill"
			var f: int = maillage.remplir(sommets_choisis())
			if f < 0:
				dit.emit("[i]Fill needs three vertices or more.[/i]")
				return
			choisir_mode("face")
			_vider_selection()
			sel_f[f] = true
		"subdiviser":
			libelle = "Subdivide"
			var fs := _faces_choisies()
			if fs.is_empty():
				dit.emit("[i]Subdivide works on selected faces.[/i]")
				return
			var neuves: Array = maillage.subdiviser(fs)
			choisir_mode("face")
			_vider_selection()
			for f in neuves:
				sel_f[f] = true
		_:
			return
	_emettre(avant, libelle)
	redessiner()
	dit.emit("[b]%s[/b] done. [i]Ctrl+Z undoes it.[/i]" % libelle)


## Ctrl+R — le loop cut : l'anneau sous la souris s'éclaire en jaune ; un clic le coupe au milieu.
func commencer_boucle() -> void:
	if maillage == null or modal != "":
		return
	modal = "loop"
	_viser_boucle()
	dit.emit("[b]Loop cut[/b] — point an edge: its ring lights up. Click to cut, Esc to cancel.")


func _viser_boucle() -> void:
	_anneau_vise = []
	var hit: Dictionary = maillage.lancer_rayon_rapide(_origine(souris), _direction(souris))
	var lp := PackedVector3Array()
	if not hit.is_empty():
		var e := _arete_proche(maillage.faces[hit["face"]], souris)
		_anneau_vise = [e]
		for r in maillage.anneau(e):
			lp.append(maillage.sommets[r[0]].lerp(maillage.sommets[r[1]], 0.5))
	# L'aperçu : les milieux reliés dans l'ordre de l'anneau.
	var lignes := PackedVector3Array()
	for i in range(lp.size() - 1):
		lignes.append(lp[i])
		lignes.append(lp[i + 1])
	_apercu_mi.mesh = _mesh_de(lignes, Mesh.PRIMITIVE_LINES)


func _couper_la_boucle() -> void:
	modal = ""
	_apercu_mi.mesh = null
	if _anneau_vise.is_empty():
		return
	var avant: RefCounted = maillage.copie()
	var neufs: Array = maillage.couper_en_boucle(_anneau_vise[0], 0.5)
	if neufs.is_empty():
		return
	choisir_mode("sommet")
	_vider_selection()
	for i in neufs:
		sel_s[i] = true
	if not _completer_apres(avant, "Loop cut"):
		_emettre(avant, "Loop cut")
	redessiner()
	dit.emit("[b]Loop cut[/b] — %d new vertices, selected: G to slide them. [i]Ctrl+Z undoes it.[/i]" % neufs.size())


## K — LE COUTEAU : chaque clic pose un point sur l'arête visée la plus proche (sur la face qu'on VOIT) ;
## la coupe se dessine en jaune ; Entrée coupe, Retour arrière ôte le dernier point, Échap abandonne.
## ⚠ **DEUX POINTS CONSÉCUTIFS DOIVENT BORDER UNE MÊME FACE** (`MaillageEdite.couper`) : sinon rien n'est
## coupé, et on le DIT — une coupe à moitié faite serait pire que pas de coupe.
func commencer_couteau() -> void:
	if maillage == null or modal != "":
		return
	modal = "knife"
	_couteau = []
	_dessiner_couteau()
	dit.emit("[b]Knife[/b] — click points on edges; each step must stay on one face. Enter cuts, "
		+ "Backspace removes the last point, Esc cancels.")


func _point_vise_du_couteau() -> Dictionary:
	var hit: Dictionary = maillage.lancer_rayon_rapide(_origine(souris), _direction(souris))
	if hit.is_empty():
		return {}
	var e := _arete_proche(maillage.faces[hit["face"]], souris)
	var a: Vector3 = maillage.sommets[e.x]
	var b: Vector3 = maillage.sommets[e.y]
	var ab := b - a
	var t := clampf((hit["point"] - a).dot(ab) / maxf(ab.length_squared(), 1e-12), 0.0, 1.0)
	# ⚠ Près d'un bout, on colle AU SOMMET : une coupe qui passe à 1 % d'un coin laisserait une arête minuscule.
	if t < 0.08:
		t = 0.0
	elif t > 0.92:
		t = 1.0
	return {"arete": e, "t": t, "point": a.lerp(b, t)}


func _poser_point_de_couteau() -> void:
	var p := _point_vise_du_couteau()
	if not p.is_empty():
		_couteau.append(p)
	_dessiner_couteau()


func _dessiner_couteau() -> void:
	var lignes := PackedVector3Array()
	var pts: Array = _couteau.map(func(p): return p["point"])
	var vise := _point_vise_du_couteau()
	if not vise.is_empty():
		pts.append(vise["point"])
	for i in range(pts.size() - 1):
		lignes.append(pts[i])
		lignes.append(pts[i + 1])
	# Une petite croix sur chaque point.
	for p in pts:
		for d in [Vector3(0.05, 0, 0), Vector3(0, 0.05, 0), Vector3(0, 0, 0.05)]:
			lignes.append(p - d)
			lignes.append(p + d)
	_apercu_mi.mesh = _mesh_de(lignes, Mesh.PRIMITIVE_LINES)


func _finir_le_couteau() -> void:
	modal = ""
	_apercu_mi.mesh = null
	if _couteau.size() < 2:
		dit.emit("[i]The knife needs two points or more.[/i]")
		_couteau = []
		return
	var avant: RefCounted = maillage.copie()
	var neufs: Array = maillage.couper(_couteau)
	_couteau = []
	if neufs.is_empty() and maillage.faces.size() == avant.faces.size():
		dit.emit("[color=#e0603c]Nothing cut[/color] — each step of the knife must stay on ONE face. "
			+ "[i]Place the points again, face by face.[/i]")
		return
	if not _completer_apres(avant, "Knife"):
		_emettre(avant, "Knife")
	redessiner()
	dit.emit("[b]Knife[/b] done. [i]Ctrl+Z undoes it.[/i]")


# ── L'ENTRÉE ────────────────────────────────────────────────────────────────────────────────────────

## La souris dans la vue. Rend vrai quand l'événement est pris. Le clic du milieu et la molette restent à
## la vue (tourner, glisser, zoomer — les réflexes de Blender) sauf pendant un geste proportionnel.
func souris_entree(event: InputEvent) -> bool:
	if maillage == null or camera == null:
		return false
	if event is InputEventMouseMotion:
		souris = (event as InputEventMouseMotion).position
		if modal in ["G", "R", "S", "I", "bevel"]:
			_mettre_a_jour()
			return true
		if modal == "knife":
			_dessiner_couteau()
			return true
		if modal == "loop":
			_viser_boucle()
			return true
		return modal == "B"
	if not event is InputEventMouseButton:
		return false
	var b := event as InputEventMouseButton
	souris = b.position
	if modal in ["G", "R", "S"] and proportionnel and b.pressed and \
			b.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		rayon_prop = maxf(0.05, rayon_prop * (1.15 if b.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15))
		# Le rayon a changé : ce qui peut bouger aussi.
		_preparer_le_geste()
		_mettre_a_jour()
		return true
	if not b.pressed and not (modal == "B" and b.button_index == MOUSE_BUTTON_LEFT):
		return b.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]
	match b.button_index:
		MOUSE_BUTTON_LEFT:
			if modal in ["G", "R", "S", "I", "bevel"]:
				confirmer()
			elif modal == "knife":
				_poser_point_de_couteau()
			elif modal == "loop":
				_couper_la_boucle()
			elif modal == "B":
				if b.pressed:
					_coin_boite = b.position
				else:
					modal = ""
					choisir_dans(Rect2(_coin_boite, b.position - _coin_boite))
					dit.emit("[i]Box selection.[/i]")
			else:
				cliquer(b.position, b.shift_pressed, b.alt_pressed)
			return true
		MOUSE_BUTTON_RIGHT:
			if modal != "":
				annuler()
				return true
			return false
	return false


## Le clavier (appelé par l'écran). Rend vrai quand la touche est prise.
func touche(k: InputEventKey) -> bool:
	if maillage == null or not k.pressed:
		return false
	# PENDANT UN GESTE : contraintes, saisie, confirmer, annuler.
	if modal == "knife":
		match k.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				_finir_le_couteau()
			KEY_ESCAPE:
				_couteau = []
				modal = ""
				_apercu_mi.mesh = null
				dit.emit("[i]Knife cancelled.[/i]")
			KEY_BACKSPACE:
				if not _couteau.is_empty():
					_couteau.pop_back()
					_dessiner_couteau()
		return true
	if modal in ["G", "R", "S", "I", "bevel"]:
		match k.keycode:
			KEY_X, KEY_Y, KEY_Z:
				var a := OS.get_keycode_string(k.keycode).to_lower()
				_axe = "" if _axe == a else a
			KEY_ENTER, KEY_KP_ENTER:
				confirmer()
				return true
			KEY_ESCAPE:
				annuler()
				return true
			KEY_BACKSPACE:
				_saisie = _saisie.substr(0, maxi(0, _saisie.length() - 1))
			KEY_MINUS, KEY_KP_SUBTRACT:
				_saisie = _saisie.substr(1) if _saisie.begins_with("-") else "-" + _saisie
			KEY_PERIOD, KEY_KP_PERIOD, KEY_COMMA:
				if not _saisie.contains("."):
					_saisie += "."
			_:
				var chiffre := _chiffre(k)
				if chiffre == "":
					return true
				_saisie += chiffre
		_mettre_a_jour()
		return true
	if modal in ["loop", "B"]:
		if k.keycode == KEY_ESCAPE:
			modal = ""
			_apercu_mi.mesh = null
			dit.emit("[i]Cancelled.[/i]")
		return true
	if k.ctrl_pressed:
		if k.keycode == KEY_R:
			commencer_boucle()
			return true
		if k.keycode == KEY_B:
			commencer("bevel")
			return true
		return false
	# 1 2 3 de la RANGÉE DU HAUT, par leur place (sur un AZERTY, « 1 » est sous « & ») ; ceux du pavé
	# numérique sont les VUES, et restent à l'écran.
	if k.physical_keycode in [KEY_1, KEY_2, KEY_3] and k.keycode < KEY_KP_0:
		choisir_mode({KEY_1: "sommet", KEY_2: "arete", KEY_3: "face"}[k.physical_keycode])
		dit.emit("[i]%s select.[/i]" % {KEY_1: "Vertex", KEY_2: "Edge", KEY_3: "Face"}[k.physical_keycode])
		return true
	match k.keycode:
		KEY_A:
			tout_choisir(not k.alt_pressed)
		KEY_G, KEY_R, KEY_S, KEY_E, KEY_I:
			commencer(OS.get_keycode_string(k.keycode))
		KEY_K:
			commencer_couteau()
		KEY_B:
			modal = "B"
			dit.emit("[b]Box select[/b] — drag a rectangle (it also takes what is hidden). Esc cancels.")
		KEY_X, KEY_DELETE:
			operer("supprimer")
		KEY_M:
			operer("fusionner")
		KEY_F:
			operer("remplir")
		KEY_Z:
			if k.alt_pressed:
				rayons_x = not rayons_x
				dit.emit("[i]X-ray %s[/i] — the box %s." % ["ON" if rayons_x else "off",
					"also takes what is hidden" if rayons_x else "only takes what you see"])
			else:
				return false
		KEY_U:
			deplier_selection()
		KEY_O:
			proportionnel = not proportionnel
			dit.emit("[i]Proportional editing %s[/i] (radius %.2f — the wheel changes it during a move)."
				% ["ON" if proportionnel else "off", rayon_prop])
		_:
			return false
	return true


## Un chiffre de la rangée du haut ou du pavé, par sa PLACE : sur un AZERTY, « 1 » est sous « & ».
static func _chiffre(k: InputEventKey) -> String:
	var p := k.physical_keycode
	if p >= KEY_0 and p <= KEY_9:
		return str(p - KEY_0)
	if k.keycode >= KEY_KP_0 and k.keycode <= KEY_KP_9:
		return str(k.keycode - KEY_KP_0)
	return ""


# ── LES MATÉRIAUX ───────────────────────────────────────────────────────────────────────────────────

## Le matériau qu'on assigne : un indice de `maillage.materiaux`, ou −1 (la teinte de la légende).
var materiau_courant := -1


func nouveau_materiau() -> int:
	var avant: RefCounted = maillage.copie()
	var n: int = maillage.materiaux.size()
	# Une couleur par matériau neuf, tournant sur le cercle chromatique : on les distingue d'un coup d'œil.
	maillage.materiaux.append({"nom": "Material %d" % (n + 1), "couleur": Color.from_hsv(fmod(0.08 + n * 0.17, 1.0), 0.45, 0.75),
		"rugosite": 0.8, "metal": 0.0, "texture": "", "echelle": 1.0})
	materiau_courant = n
	_emettre(avant, "New material")
	redessiner()
	return n


## Assigne le matériau courant aux faces choisies.
func assigner_courant() -> void:
	var fs := _faces_choisies()
	if fs.is_empty():
		dit.emit("[i]Select faces first (3), then Assign.[/i]")
		return
	var avant: RefCounted = maillage.copie()
	maillage.assigner(fs, materiau_courant)
	_emettre(avant, "Assign material")
	redessiner()
	dit.emit("[b]Material[/b] %s → %d face(s). [i]Ctrl+Z undoes it.[/i]" % [
		"legend colour" if materiau_courant < 0 else str(maillage.materiaux[materiau_courant]["nom"]), fs.size()])


## Change une propriété d'un matériau, À VIF (l'écran regroupe une rafale de retouches en UNE annulation).
func regler_materiau(k: int, cle: String, valeur: Variant) -> void:
	if k < 0 or k >= maillage.materiaux.size():
		return
	maillage.materiaux[k][cle] = valeur
	redessiner()
	_rafraichir_les_tuiles_qui_portent(k)


## Les matériaux sont PARTAGÉS par les 52 tuiles : en retoucher un redessine les occurrences des tuiles qui
## le portent (`k` = −2 : toutes celles qui portent un matériau, après une annulation).
func _rafraichir_les_tuiles_qui_portent(k: int) -> void:
	if temoin == null:
		return
	for c in temoin.tuiles:
		if c == cle or not _mm_de.has(c):
			continue
		var m: RefCounted = temoin.tuiles[c]
		var porte := false
		for x in m.mats:
			if x == k or (k == -2 and x >= 0):
				porte = true
				break
		if porte:
			(_mm_de[c] as MultiMeshInstance3D).multimesh.mesh = m.vers_array_mesh()


## U — DÉPLIER : les faces choisies (tout le témoin si rien n'est choisi).
func deplier_selection() -> void:
	if maillage == null:
		return
	var fs := _faces_choisies()
	var avant: RefCounted = maillage.copie()
	var r: Dictionary = maillage.deplier(fs)
	_emettre(avant, "Unwrap")
	redessiner()
	dit.emit(("[b]Unwrapped[/b] — %d face(s) in %d island(s), laid out in the 0–1 square at one scale. "
		+ "[i]Export UV layout… to paint on it; give the material the « UV » projection.[/i]")
		% [r["faces"], r["ilots"]])


## Le pivot de la sélection (sa moyenne) — pour cadrer la vue (touche « . » du pavé).
func centre_de_la_selection() -> Variant:
	var ids := sommets_choisis()
	if ids.is_empty():
		return null
	var c := Vector3.ZERO
	for i in ids:
		c += maillage.sommets[i]
	return pose * (c / float(ids.size()))   # un point du MONDE : la vue y cadre


## Le maillage pour le trancheur et le fichier : sans normales (plat), avec ses teintes.
func vers_glb(chemin: String) -> String:
	var racine := Node3D.new()
	racine.name = "Witness"
	var mi := MeshInstance3D.new()
	mi.name = "witness"
	# ⚠ PAS DE `material_override` : il effaçait les matériaux de l'export.
	mi.mesh = maillage.vers_array_mesh(false)
	racine.add_child(mi)
	var doc := GLTFDocument.new()
	var etat := GLTFState.new()
	var err := doc.append_from_scene(racine, etat)
	if err == OK:
		err = doc.write_to_filesystem(etat, chemin)
	racine.free()
	return "" if err == OK else "could not write %s (error %d)" % [chemin, err]
