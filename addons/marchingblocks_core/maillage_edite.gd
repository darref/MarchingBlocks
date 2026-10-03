extends RefCounted
## LE MAILLAGE QU'ON ÉDITE — le cœur du modeleur du témoin.
##
## **DÉCIDÉ (Jordan, 29 septembre 2026)** : le modeleur REMPLACE Blender. L'artiste ne quitte plus
## l'appli : le témoin s'édite ici, polygone par polygone, puis se tranche. Ce fichier ne dessine rien et
## n'écoute aucune souris : il porte la DONNÉE (des sommets, des faces à N côtés) et les OPÉRATIONS
## (extruder, inset, supprimer, fusionner, remplir, subdiviser, loop cut…), toutes éprouvables sans écran.
## L'écran (`app/modeleur.gd`) ne fait que viser et appeler.
##
## ⚠ **LE CODE DE BLENDER N'EST PAS RECOPIÉ, ET CE N'EST PAS UNE PRÉFÉRENCE : il est sous GPL** (charte).
## Les gestes et leurs résultats imitent Blender ; les algorithmes sont écrits ici.
##
## ── LES CONVENTIONS ─────────────────────────────────────────────────────────────────────────────────
##
## ⚠ **UNE FACE TOURNE DANS LE SENS TRIGONOMÉTRIQUE VUE DE DEHORS** : la normale sortante est celle de
## la main droite (Newell). C'est l'INVERSE de ce que Godot stocke (ses faces avant sont horaires, charte
## §4) : la conversion se fait à UN seul endroit dans chaque sens, `depuis()` et `vers_array_mesh()`.
## ⚠ **PAS D'ARÊTE LIBRE** : une arête n'existe que dans une face. C'est le modèle du témoin (une coque
## fermée) et ce qui garde le maillage étanche : une opération qui retire une face ouvre un TROU qu'on
## voit, jamais une arête pendante qu'on ne verrait pas.
## ⚠ **UNE TEINTE PAR FACE** — la légende du témoin (six teintes, §9.5). Une face née d'une opération
## prend celle de la face dont elle sort.

var sommets := PackedVector3Array()
## Array de PackedInt32Array.
var faces: Array = []
var teintes := PackedColorArray()
## LE MATÉRIAU DE CHAQUE FACE — un indice dans `materiaux`, ou −1 : la teinte de la légende (§9.5).
## ⚠ **IL SUIT LA TEINTE PARTOUT** : chaque opération qui fabrique, recopie ou retire une face fait la même
## chose aux deux tableaux. Une face née d'une opération prend le matériau de celle dont elle sort.
var mats := PackedInt32Array()
## LES UV DÉPLIÉS (U) — un PackedVector2Array par face, un UV par coin ; vide = pas déplié.
## ⚠ **UNE OPÉRATION QUI DÉFORME UNE FACE EFFACE SES UV** (une face neuve, un sommet inséré, une face
## fendue) : on ne devine pas l'UV d'un point neuf. La face retombe sur la projection en boîte, et l'écran
## dit combien de faces sont à redéplier. Une face seulement DÉPLACÉE (G, R, S, l'extrusion de sa région)
## garde les siens.
var uvs: Array = []
## LES MATÉRIAUX — DÉCIDÉ (Jordan, 29 septembre 2026) : « matériaux + projections ». Chacun :
## {"nom", "couleur": Color, "rugosite", "metal", "texture": chemin d'image ou "", "echelle": cases par
## répétition}. ⚠ **LES UV NE SONT PAS STOCKÉS : ILS SE PROJETTENT DEPUIS LA POSITION** (en boîte, sur
## l'axe dominant de la normale), au dessin comme à l'export. Une face née d'une extrusion ou d'un biseau
## est donc texturée sans rien déplier ; et une texture tuilable dont la période divise la case se raccorde
## d'une tuile à l'autre — la discipline de l'artiste (§3), servie par construction là où c'est possible.
var materiaux: Array = []


func copie() -> RefCounted:
	var m: RefCounted = get_script().new()
	m.sommets = sommets.duplicate()
	for f in faces:
		m.faces.append((f as PackedInt32Array).duplicate())
	m.teintes = teintes.duplicate()
	m.mats = mats.duplicate()
	for u in uvs:
		m.uvs.append((u as PackedVector2Array).duplicate())
	m.materiaux = materiaux.duplicate(true)
	return m


func mat(f: int) -> int:
	return mats[f] if f < mats.size() else -1


## Les UV de la face, s'ils sont valides (un par coin), sinon vide.
func uv(f: int) -> PackedVector2Array:
	if f < uvs.size() and (uvs[f] as PackedVector2Array).size() == (faces[f] as PackedInt32Array).size():
		return uvs[f]
	return PackedVector2Array()


func _effacer_uv(f: int) -> void:
	if f < uvs.size():
		uvs[f] = PackedVector2Array()


## Ajoute une face avec sa teinte et son matériau — les deux tableaux restent alignés.
## ⚠ **ON COMPLÈTE D'ABORD** : un maillage bâti à la main (des faces sans matériau) garderait sinon un
## tableau `mats` plus court, et le matériau d'une face neuve atterrirait sur une face ancienne.
func _ajouter(face: PackedInt32Array, teinte: Color, m: int, u := PackedVector2Array()) -> void:
	while mats.size() < faces.size():
		mats.append(-1)
	while teintes.size() < faces.size():
		teintes.append(Color.WHITE)
	while uvs.size() < faces.size():
		uvs.append(PackedVector2Array())
	faces.append(face)
	teintes.append(teinte)
	mats.append(m)
	uvs.append(u)


# ── L'ENTRÉE ET LA SORTIE ───────────────────────────────────────────────────────────────────────────

## Lit un maillage de Godot : soude les sommets par POSITION, retourne les faces dans le sens du modèle,
## et RECOLLE les quads. ⚠ **LE TÉMOIN EST FAIT DE QUADS POSÉS EN DEUX TRIANGLES CONSÉCUTIFS**
## (`BlocsMaitres._quad` : [0,1,2] puis [0,2,3]) : une paire qui partage sa diagonale et reste plane redevient
## UN quad. Sans ça, l'artiste éditerait deux fois plus de faces, et ni la boucle d'arêtes ni le loop cut
## ne trouveraient leur chemin — ils ne suivent que des quads.
## ⚠ **`materiau_de` (facultatif) RELIT LES MATÉRIAUX ET LES UV** — un travail revenu de Blender devient ainsi
## éditable sans perdre sa peinture (charte §3, « le retour garde tout ce que le glTF porte »). Il reçoit le
## matériau d'une surface et rend {"mat": indice (−1 = la légende), "teinte": Color ou null}. Une face à
## matériau garde les UV de ses coins ; deux triangles ne se recollent en quad que s'ils ont le même
## matériau ET les mêmes UV aux deux sommets qu'ils partagent (sinon la couture d'UV serait perdue).
## Sans lui, rien ne change : la géométrie et les teintes, comme avant.
static func depuis(mesh: Mesh, epsilon := 0.00001, materiau_de := Callable()) -> RefCounted:
	var m: RefCounted = load("res://addons/marchingblocks_core/maillage_edite.gd").new()
	var index := {}
	var tris: Array = []
	var couleurs_tri: Array = []
	var mats_tri: Array = []
	var uv_tri: Array = []   # par triangle : {sommet: uv} (vide sans matériau)
	for s in mesh.get_surface_count():
		var a: Array = mesh.surface_get_arrays(s)
		var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var col = a[Mesh.ARRAY_COLOR]
		var ind = a[Mesh.ARRAY_INDEX]
		var uv_src = a[Mesh.ARRAY_TEX_UV]
		var mat_surface := -1
		var teinte_surface = null
		if materiau_de.is_valid():
			var r: Dictionary = materiau_de.call(mesh.surface_get_material(s))
			mat_surface = int(r.get("mat", -1))
			teinte_surface = r.get("teinte", null)
		var n: int = (ind as PackedInt32Array).size() if ind != null else pos.size()
		for t in range(0, n, 3):
			var ids := PackedInt32Array()
			var teinte := Color.WHITE
			var uv_ici := {}
			# ⚠ ORDRE RETOURNÉ : Godot stocke en horaire, le modèle en trigonométrique.
			for k in [0, 2, 1]:
				var i: int = ind[t + k] if ind != null else t + k
				var p: Vector3 = pos[i]
				var cle := Vector3i(roundi(p.x / epsilon), roundi(p.y / epsilon), roundi(p.z / epsilon))
				if not index.has(cle):
					index[cle] = m.sommets.size()
					m.sommets.append(p)
				ids.append(index[cle])
				if col != null and (col as PackedColorArray).size() > i:
					teinte = col[i]
				if mat_surface >= 0 and uv_src != null and (uv_src as PackedVector2Array).size() > i:
					uv_ici[index[cle]] = uv_src[i]
			if teinte_surface != null:
				teinte = teinte_surface
			if ids[0] == ids[1] or ids[1] == ids[2] or ids[0] == ids[2]:
				continue
			tris.append(ids)
			couleurs_tri.append(teinte)
			mats_tri.append(mat_surface)
			uv_tri.append(uv_ici)
	var i := 0
	while i < tris.size():
		if i + 1 < tris.size():
			var q := _recoller(m.sommets, tris[i], tris[i + 1])
			if not q.is_empty() and couleurs_tri[i] == couleurs_tri[i + 1] and mats_tri[i] == mats_tri[i + 1] \
					and _uv_accordes(uv_tri[i], uv_tri[i + 1]):
				var uq := PackedVector2Array()
				if not (uv_tri[i] as Dictionary).is_empty():
					for v in q:
						uq.append(uv_tri[i][v] if (uv_tri[i] as Dictionary).has(v) else uv_tri[i + 1][v])
				m._ajouter(q, couleurs_tri[i], mats_tri[i], uq)
				i += 2
				continue
		var ut := PackedVector2Array()
		if not (uv_tri[i] as Dictionary).is_empty():
			for v in tris[i]:
				ut.append(uv_tri[i][v])
		m._ajouter(tris[i], couleurs_tri[i], mats_tri[i], ut)
		i += 1
	return m


## Deux triangles ont-ils les mêmes UV aux sommets qu'ils partagent ? (Vrai si aucun ne porte d'UV.)
static func _uv_accordes(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() != b.is_empty():
		return false
	for v in a:
		if b.has(v) and not (a[v] as Vector2).is_equal_approx(b[v]):
			return false
	return true


## Deux triangles qui partagent une arête, parcourue dans des SENS OPPOSÉS, coplanaires, et qui forment
## un quad CONVEXE : rend ce quad, sinon vide.
## ⚠ **N'IMPORTE QUELLE PAIRE, PAS UN MOTIF.** La première version ne reconnaissait que le motif de
## `BlocsMaitres._quad` ; le propre écrivain du modèle (`vers_array_mesh`) en produit un autre, et un
## cube relu revenait en douze triangles — vu rougir.
static func _recoller(s: PackedVector3Array, t1: PackedInt32Array, t2: PackedInt32Array) -> PackedInt32Array:
	for i in 3:
		var u := t1[i]
		var v := t1[(i + 1) % 3]
		var w := t1[(i + 2) % 3]
		for j in 3:
			if t2[j] == v and t2[(j + 1) % 3] == u:
				var x := t2[(j + 2) % 3]
				if x == w:
					return PackedInt32Array()
				# t1 = u→v→w, t2 = v→u→x : le quad insère x entre u et v.
				var q := PackedInt32Array([u, x, v, w])
				if _normale_de(s, t1).dot(_normale_de(s, t2)) < 0.9999:
					return PackedInt32Array()
				var n := _normale_de(s, q)
				for k in 4:
					var a: Vector3 = s[q[k]]
					var b: Vector3 = s[q[(k + 1) % 4]]
					var c: Vector3 = s[q[(k + 2) % 4]]
					if (b - a).cross(c - b).dot(n) <= 1e-12:
						return PackedInt32Array()
				return q
	return PackedInt32Array()


## Le maillage que Godot dessine : triangulé, faces retournées en horaire, une normale PLATE par face et
## sa teinte. ⚠ Un quad se coupe en éventail ; au-delà, `Geometry2D.triangulate_polygon` sur la face
## projetée — un éventail sur une face concave déborderait de la face.
func vers_array_mesh(avec_normales := true) -> ArrayMesh:
	return vers_array_mesh_de(range(faces.size()), avec_normales)


## La même chose pour une PARTIE des faces — ce qui bouge pendant un geste, redessiné seul (le reste est
## dessiné une fois au début du geste : un G qui suit la souris ne peut pas rebâtir 15 000 faces par image).
func vers_array_mesh_de(choix: Array, avec_normales := true) -> ArrayMesh:
	# Une SURFACE PAR MATÉRIAU, dans l'ordre : la légende (−1) d'abord. Le trancheur garde une surface par
	# matériau (`Decoupe.trancher`), et l'export glTF en fait une primitive chacune.
	var groupes := {}
	for f in choix:
		var m := mat(f)
		if m >= materiaux.size():
			m = -1
		if not groupes.has(m):
			groupes[m] = []
		groupes[m].append(f)
	var cles: Array = groupes.keys()
	cles.sort()
	var mesh := ArrayMesh.new()
	for m in cles:
		var pos := PackedVector3Array()
		var nor := PackedVector3Array()
		var col := PackedColorArray()
		var uv_sortie := PackedVector2Array()
		var echelle: float = maxf(0.01, float(materiaux[m].get("echelle", 1.0))) if m >= 0 else 1.0
		var mode: String = str(materiaux[m].get("projection", "boite")) if m >= 0 else "boite"
		for f in groupes[m]:
			var face: PackedInt32Array = faces[f]
			var n := normale(f)
			for t in trianguler(f):
				# Horaire pour Godot : le triangle trigonométrique [a,b,c] s'écrit [a,c,b].
				for k in [0, 2, 1]:
					var p: Vector3 = sommets[face[t[k]]]
					pos.append(p)
					nor.append(n)
					col.append(teintes[f] if f < teintes.size() else Color.WHITE)
					if m >= 0:
						var depl := uv(f) if mode == "uv" else PackedVector2Array()
						uv_sortie.append(depl[t[k]] if not depl.is_empty() else projeter(p, n, echelle, "boite" if mode == "uv" else mode))
		if pos.is_empty():
			continue
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = pos
		if avec_normales:
			a[Mesh.ARRAY_NORMAL] = nor
		# ⚠ LA COULEUR DE SOMMET SUR LA SEULE LÉGENDE (mesuré le 1er octobre 2026) : écrite partout, elle partait en
		# COLOR_0 sur chaque primitive du glTF, et l'import de Godot faisait multiplier les matériaux de l'artiste
		# par la teinte de la légende — le monde s'éclairait autrement que le modeleur, tuile par tuile.
		if m < 0:
			a[Mesh.ARRAY_COLOR] = col
		if m >= 0:
			a[Mesh.ARRAY_TEX_UV] = uv_sortie
			# Une carte de normales a besoin de TANGENTES, dans la convention du moteur : celles de MikkTSpace
			# (`SurfaceTool.generate_tangents`), que les importeurs glTF recalculent de la même façon.
			if avec_normales and a_des_cartes(materiaux[m]):
				a = avec_tangentes(a)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		# ⚠ **CHAQUE SURFACE PORTE SON MATÉRIAU, LA LÉGENDE COMPRISE.** Un `material_override` unique (la
		# couleur de sommet) remplaçait ceux de TOUTES les surfaces — à l'écran comme dans le .glb : les
		# matériaux se seraient effacés sans un mot.
		mesh.surface_set_material(mesh.get_surface_count() - 1, materiau_godot(m) if m >= 0 else materiau_de_legende())
	return mesh


## Les tableaux d'une surface, TANGENTES calculées (MikkTSpace) — s'il y a des normales et des UV ; sinon tels quels.
## ⚠ Les tangentes d'un tableau POSÉ (tourné, en miroir) ne se transportent pas : on les recalcule après la pose.
static func avec_tangentes(a: Array) -> Array:
	if a[Mesh.ARRAY_NORMAL] == null or a[Mesh.ARRAY_TEX_UV] == null or (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
		return a
	var st := SurfaceTool.new()
	st.create_from_arrays(a)
	st.generate_tangents()
	return st.commit_to_arrays()


static var _legende: StandardMaterial3D


## La teinte de légende, lue dans la couleur de sommet.
static func materiau_de_legende() -> StandardMaterial3D:
	if _legende == null:
		_legende = StandardMaterial3D.new()
		_legende.resource_name = "legend"
		_legende.vertex_color_use_as_albedo = true
		_legende.roughness = 0.9
	return _legende


## LA PROJECTION EN BOÎTE : les UV d'un point selon l'axe dominant de la normale de sa face, divisés par
## l'échelle (en cases par répétition). ⚠ **LE SIGNE DE L'AXE ENTRE DANS U** : sans lui, deux faces
## opposées (le mur est et le mur ouest) montreraient la texture en miroir l'une de l'autre.
## LES PROJECTIONS PLANES ("dessus", "face", "cote") appliquent UNE formule à toutes les faces, quelle que
## soit leur normale — comme la projection plane de Blender : une face perpendiculaire au plan y est
## étirée, c'est attendu (on la choisit pour un sol, ou pour un mur vu d'un seul côté).
static func projeter(p: Vector3, n: Vector3, echelle: float, mode := "boite") -> Vector2:
	match mode:
		"dessus":
			return Vector2(p.x, p.z) / echelle
		"face":
			return Vector2(p.x, -p.y) / echelle
		"cote":
			return Vector2(-p.z, -p.y) / echelle
	var a := n.abs()
	var uv: Vector2
	if a.x >= a.y and a.x >= a.z:
		uv = Vector2(-p.z * signf(n.x), -p.y)
	elif a.y >= a.z:
		uv = Vector2(p.x, p.z * signf(n.y))
	else:
		uv = Vector2(p.x * signf(n.z), -p.y)
	return uv / echelle


var _cache_godot := {}


## L'UV QUE LE RENDU DONNE AU POINT `p` DE LA FACE `f` — la règle de `vers_array_mesh_de`, au point près : les UV
## dépliés de la face, interpolés sur le triangle qui porte `p` ; sinon la projection du matériau. Vector2.INF
## pour une face sans matériau (la teinte de la légende n'a pas d'image).
func uv_au_point(f: int, p: Vector3) -> Vector2:
	var m := mat(f)
	if m < 0 or m >= materiaux.size():
		return Vector2.INF
	var echelle: float = maxf(0.01, float(materiaux[m].get("echelle", 1.0)))
	var mode: String = str(materiaux[m].get("projection", "boite"))
	var n := normale(f)
	var depl := uv(f) if mode == "uv" else PackedVector2Array()
	if depl.is_empty():
		return projeter(p, n, echelle, "boite" if mode == "uv" else mode)
	var face: PackedInt32Array = faces[f]
	var meilleur := Vector2.INF
	var ecart := INF
	for t in trianguler(f):
		var a: Vector3 = sommets[face[t[0]]]
		var b: Vector3 = sommets[face[t[1]]]
		var c: Vector3 = sommets[face[t[2]]]
		var w: Vector3 = Geometry3D.get_triangle_barycentric_coords(p, a, b, c)
		var dehors := maxf(0.0, -minf(w.x, minf(w.y, w.z)))
		if dehors < ecart:
			ecart = dehors
			meilleur = depl[t[0]] * w.x + depl[t[1]] * w.y + depl[t[2]] * w.z
	return meilleur


## Le StandardMaterial3D d'un matériau (gardé tant que sa définition ne change pas).
func materiau_godot(m: int) -> StandardMaterial3D:
	var d: Dictionary = materiaux[m]
	var cle := JSON.stringify(d)
	if _cache_godot.has(cle):
		return _cache_godot[cle]
	var sm := StandardMaterial3D.new()
	sm.resource_name = str(d.get("nom", "material"))
	sm.albedo_color = d.get("couleur", Color.WHITE)
	sm.roughness = float(d.get("rugosite", 0.8))
	sm.metallic = float(d.get("metal", 0.0))
	var chemin: String = str(d.get("texture", ""))
	if chemin != "":
		# ⚠ LA TOILE PARTAGÉE (`peinture.gd`) : toutes les tuiles qui portent ce matériau lisent la MÊME texture,
		# et un coup de pinceau la met à jour partout, sans rien redessiner.
		var Peinture: Script = load("res://addons/marchingblocks_core/peinture.gd")
		sm.albedo_texture = Peinture.texture_de(chemin)
		# L'ENSEMBLE PBR DE L'IMAGE (3 octobre 2026) : les cartes faites par l'auteur de la texture, à côté d'elle
		# (`Peinture.ensemble_de`) — elles l'emportent sur les cartes déduites, qui ne font que les deviner.
		var ens: Dictionary = Peinture.ensemble_de(chemin) if bool(d.get("ensemble", true)) else {}
		if not ens.is_empty() and sm.albedo_texture != null:
			if ens["normale"] != null:
				sm.normal_enabled = true
				sm.normal_texture = ens["normale"]
			if ens["orm"] != null:
				sm.roughness = 1.0
				sm.roughness_texture = ens["orm"]
				sm.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
				sm.metallic_texture = ens["orm"]
				sm.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
				sm.ao_enabled = true
				sm.ao_texture = ens["orm"]
				sm.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		# LES CARTES PBR DÉDUITES de l'albedo (`cartes_pbr.gd`), si le matériau les demande : normale, et l'ORM
		# (R occlusion, G rugosité, B métal BLANC — le facteur « metal » reste seul maître). Partagées comme la toile.
		elif d.get("pbr") is Dictionary and sm.albedo_texture != null:
			var c: Dictionary = Peinture.cartes_de(chemin, d["pbr"], str(d.get("projection", "boite")) != "uv")
			if not c.is_empty():
				sm.normal_enabled = true
				sm.normal_texture = c["normale"]
				sm.roughness = 1.0
				sm.roughness_texture = c["orm"]
				sm.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
				sm.metallic_texture = c["orm"]
				sm.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
				sm.ao_enabled = true
				sm.ao_texture = c["orm"]
				sm.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	_cache_godot[cle] = sm
	return sm


## Le matériau `d` porte-t-il des cartes (une normale à lire, donc des TANGENTES à donner) : déduites, ou celles de
## l'ensemble PBR de son image ?
static func a_des_cartes(d: Dictionary) -> bool:
	if d.get("pbr") is Dictionary:
		return true
	var chemin := str(d.get("texture", ""))
	if chemin == "" or not bool(d.get("ensemble", true)):
		return false
	return not (load("res://addons/marchingblocks_core/peinture.gd").ensemble_de(chemin) as Dictionary).is_empty()


## Assigne un matériau (ou −1, la légende) à des faces.
func assigner(choix: Array, m: int) -> void:
	while mats.size() < faces.size():
		mats.append(-1)
	for f in choix:
		mats[f] = m


static func _couleur(v: Variant) -> Color:
	if v is Array and (v as Array).size() >= 3:
		return Color(float(v[0]), float(v[1]), float(v[2]), float(v[3]) if (v as Array).size() > 3 else 1.0)
	return Color.WHITE


# ── LE DÉPLIAGE (U) ─────────────────────────────────────────────────────────────────────────────────
#
# **DÉCIDÉ (Jordan, 29 septembre 2026)** : un dépliage d'UV, pour peindre des textures qui ne se répètent
# pas. ⚠ **CE N'EST PAS LE « UNWRAP » EXACT DE BLENDER (LSCM, un solveur de moindres carrés)** : c'est
# l'équivalent de son « Smart UV Project », qui convient aux formes du témoin, faites de faces planes :
#   1. les ÎLOTS : des faces voisines dont la normale reste à moins de `angle` de celle qui a lancé l'îlot ;
#   2. chaque îlot est MIS À PLAT sur son plan moyen — sans aucune déformation quand l'îlot est plan ;
#   3. les îlots sont RANGÉS par étagères dans le carré [0,1], sans se chevaucher, avec une marge, à UNE
#      échelle commune (une case fait la même taille dans tout le patron : la texture a une densité égale).

## Déplie les faces `choix` (toutes si vide). Rend {"ilots": nombre, "faces": nombre}.
func deplier(choix: Array = [], angle := 66.0, marge := 0.01) -> Dictionary:
	var plats := ilots_a_plat(choix, angle)
	ranger(plats, marge)
	poser_uvs(plats)
	return {"ilots": plats.size(), "faces": (choix if not choix.is_empty() else range(faces.size())).size()}


## Les îlots de `choix` (toutes les faces s'il est vide), chacun MIS À PLAT sur son plan moyen, pas encore rangés :
## [{"uv": {face: PackedVector2Array}, "min": Vector2, "taille": Vector2}]. `ranger` les place, `poser_uvs` les écrit
## — séparés pour que l'atlas du témoin (`TemoinLie.deplier_en_atlas`) range ceux de TOUTES les tuiles ensemble.
func ilots_a_plat(choix: Array = [], angle := 66.0) -> Array:
	var dans := {}
	for f in (choix if not choix.is_empty() else range(faces.size())):
		dans[f] = true
	var fpa := faces_par_arete()
	var seuil := cos(deg_to_rad(angle))
	var ilot_de := {}
	var ilots: Array = []
	for depart in dans:
		if ilot_de.has(depart):
			continue
		var n0 := normale(depart)
		var ilot: Array = [depart]
		ilot_de[depart] = ilots.size()
		var file: Array = [depart]
		while not file.is_empty():
			var f: int = file.pop_back()
			var face: PackedInt32Array = faces[f]
			for k in face.size():
				for g in fpa.get(arete(face[k], face[(k + 1) % face.size()]), []):
					if dans.has(g) and not ilot_de.has(g) and normale(g).dot(n0) >= seuil:
						ilot_de[g] = ilots.size()
						ilot.append(g)
						file.append(g)
		ilots.append(ilot)
	# 2. À plat : chaque îlot sur son plan moyen (normales pondérées par l'aire).
	var plats: Array = []   # [{faces, uv: {f: PackedVector2Array}, min, max}]
	for ilot in ilots:
		var nrm := Vector3.ZERO
		for f in ilot:
			nrm += normale(f) * _aire(f)
		nrm = nrm.normalized() if nrm.length_squared() > 1e-12 else normale(ilot[0])
		var haut_ref := Vector3.UP if absf(nrm.y) < 0.9 else Vector3.BACK
		# Vu de DEHORS (l'œil regarde vers −N) : u vers la droite, v vers le bas de l'image (comme `projeter`).
		var droite := haut_ref.cross(nrm).normalized()
		var haut := nrm.cross(droite).normalized()
		var par_face := {}
		var bmin := Vector2(INF, INF)
		var bmax := Vector2(-INF, -INF)
		for f in ilot:
			var u := PackedVector2Array()
			for i in faces[f]:
				var q: Vector3 = sommets[i]
				var t := Vector2(q.dot(droite), -q.dot(haut))
				u.append(t)
				bmin = bmin.min(t)
				bmax = bmax.max(t)
			par_face[f] = u
		plats.append({"uv": par_face, "min": bmin, "taille": bmax - bmin})
	return plats


## 3. Le rangement, par étagères : les plus hauts d'abord, sur une largeur qui vise un carré ; puis tout est ramené
## dans [0,1] à UNE échelle (la même densité de texels partout). Écrit les UV rangés dans chaque îlot.
static func ranger(plats: Array, marge := 0.01) -> void:
	if plats.is_empty():
		return
	var aire := 0.0
	for pl in plats:
		aire += (pl["taille"] as Vector2).x * (pl["taille"] as Vector2).y
	var largeur := maxf(sqrt(aire) * 1.15, 1e-6)
	for pl in plats:
		largeur = maxf(largeur, (pl["taille"] as Vector2).x)
	var jeu := largeur * marge
	var ordre: Array = range(plats.size())
	ordre.sort_custom(func(a: int, b: int) -> bool: return plats[a]["taille"].y > plats[b]["taille"].y)
	var x := jeu
	var y := jeu
	var etagere := 0.0
	var etendue := Vector2.ZERO
	for i in ordre:
		var t: Vector2 = plats[i]["taille"]
		if x + t.x + jeu > largeur + 2.0 * jeu and x > jeu:
			x = jeu
			y += etagere + jeu
			etagere = 0.0
		plats[i]["place"] = Vector2(x, y)
		x += t.x + jeu
		etagere = maxf(etagere, t.y)
		etendue = etendue.max(Vector2(x, y + t.y + jeu))
	var echelle := 1.0 / maxf(etendue.x, etendue.y)
	for pl in plats:
		for f in pl["uv"]:
			var u: PackedVector2Array = pl["uv"][f]
			for k in u.size():
				u[k] = (u[k] - pl["min"] + pl["place"]) * echelle
			pl["uv"][f] = u


## Écrit les UV rangés des îlots dans le maillage.
func poser_uvs(plats: Array) -> void:
	while uvs.size() < faces.size():
		uvs.append(PackedVector2Array())
	for pl in plats:
		for f in pl["uv"]:
			uvs[f] = pl["uv"][f]


func _aire(f: int) -> float:
	var face: PackedInt32Array = faces[f]
	var a := Vector3.ZERO
	for i in range(1, face.size() - 1):
		a += (sommets[face[i]] - sommets[face[0]]).cross(sommets[face[i + 1]] - sommets[face[0]])
	return a.length() * 0.5


## Combien de faces portent un matériau en projection « uv » SANS UV valides — à redéplier.
func faces_a_deplier() -> int:
	var n := 0
	for f in faces.size():
		var m := mat(f)
		if m >= 0 and m < materiaux.size() and str(materiaux[m].get("projection", "")) == "uv" and uv(f).is_empty():
			n += 1
	return n


## LE PATRON — une image des arêtes dépliées, à peindre dans un logiciel de dessin (« Export UV layout »).
func dessiner_patron(taille := 1024) -> Image:
	var img := Image.create(taille, taille, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.1, 0.1, 0.12, 1.0))
	var encre := Color(0.95, 0.85, 0.4, 1.0)
	for f in faces.size():
		var u := uv(f)
		for k in u.size():
			_ligne(img, u[k] * taille, u[(k + 1) % u.size()] * taille, encre)
	return img


static func _ligne(img: Image, a: Vector2, b: Vector2, c: Color) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / float(n))
		var x := clampi(int(p.x), 0, img.get_width() - 1)
		var y := clampi(int(p.y), 0, img.get_height() - 1)
		img.set_pixel(x, y, c)


# ── LE FORMAT NATIF (.mbmesh) ──────────────────────────────────────────────────────────────────────
#
# ⚠ **LE MODÈLE S'ENREGISTRE DANS SON PROPRE FORMAT, ET LE .glb N'EN EST QU'UNE SORTIE.** Relire le .glb
# regroupe les faces par surface et ne sait plus QUELLE face portait QUEL matériau : l'assignation se
# perdrait à chaque réouverture. Le `.mbmesh` (JSON) garde tout : sommets, faces, teintes, matériaux.

func vers_dictionnaire() -> Dictionary:
	var s: Array = []
	for p in sommets:
		s.append_array([p.x, p.y, p.z])
	var f: Array = []
	for face in faces:
		f.append(Array(face))
	# ⚠ LES COULEURS EN NOMBRES, PAS EN HEXADÉCIMAL : `to_html` arrondit à 1/255 — un vert à 0,3 revenait à
	# 0,302, et les teintes de la légende auraient dérivé à chaque enregistrement (vu rougir).
	var t: Array = []
	for c in teintes:
		t.append([c.r, c.g, c.b, c.a])
	var mt: Array = []
	for d in materiaux:
		var e: Dictionary = d.duplicate()
		var c: Color = d.get("couleur", Color.WHITE)
		e["couleur"] = [c.r, c.g, c.b, c.a]
		mt.append(e)
	return {"format": "marchingblocks-mesh", "version": 1, "sommets": s, "faces": f, "teintes": t,
		"mats": Array(mats), "uvs": _uvs_en_listes(), "materiaux": mt}


func _uvs_en_listes() -> Array:
	var sortie: Array = []
	for f in faces.size():
		var l: Array = []
		for p in uv(f):
			l.append_array([p.x, p.y])
		sortie.append(l)
	return sortie


static func depuis_dictionnaire(d: Dictionary) -> RefCounted:
	var m: RefCounted = load("res://addons/marchingblocks_core/maillage_edite.gd").new()
	if str(d.get("format", "")) != "marchingblocks-mesh":
		return null
	var s: Array = d.get("sommets", [])
	for i in range(0, s.size() - 2, 3):
		m.sommets.append(Vector3(float(s[i]), float(s[i + 1]), float(s[i + 2])))
	var fs: Array = d.get("faces", [])
	var ts: Array = d.get("teintes", [])
	var ms: Array = d.get("mats", [])
	var us: Array = d.get("uvs", [])
	for k in fs.size():
		var face := PackedInt32Array()
		for i in fs[k]:
			face.append(int(i))
		var u := PackedVector2Array()
		if k < us.size():
			for i in range(0, (us[k] as Array).size() - 1, 2):
				u.append(Vector2(float(us[k][i]), float(us[k][i + 1])))
		m._ajouter(face, _couleur(ts[k]) if k < ts.size() else Color.WHITE, int(ms[k]) if k < ms.size() else -1, u)
	for e in d.get("materiaux", []):
		var x: Dictionary = (e as Dictionary).duplicate()
		x["couleur"] = _couleur(e.get("couleur", [1, 1, 1, 1]))
		m.materiaux.append(x)
	return m


## Les triangles d'une face, en positions LOCALES de la face ([[0,1,2], [0,2,3]…]), trigonométriques.
func trianguler(f: int) -> Array:
	var face: PackedInt32Array = faces[f]
	var n := face.size()
	if n == 3:
		return [[0, 1, 2]]
	if n == 4:
		return [[0, 1, 2], [0, 2, 3]]
	var nrm := normale(f)
	var u := nrm.cross(Vector3.UP if absf(nrm.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := nrm.cross(u)
	var plan := PackedVector2Array()
	for i in face:
		var p: Vector3 = sommets[i]
		plan.append(Vector2(p.dot(u), p.dot(v)))
	var idx := Geometry2D.triangulate_polygon(plan)
	var sortie: Array = []
	if idx.is_empty():
		for i in range(1, n - 1):
			sortie.append([0, i, i + 1])
		return sortie
	for t in range(0, idx.size(), 3):
		var tri := [idx[t], idx[t + 1], idx[t + 2]]
		# `triangulate_polygon` peut rendre l'autre sens : on le remet dans celui de la face.
		var a: Vector3 = sommets[face[tri[0]]]
		var b: Vector3 = sommets[face[tri[1]]]
		var c: Vector3 = sommets[face[tri[2]]]
		if (b - a).cross(c - a).dot(nrm) < 0.0:
			tri = [tri[0], tri[2], tri[1]]
		sortie.append(tri)
	return sortie


# ── LA GÉOMÉTRIE ────────────────────────────────────────────────────────────────────────────────────

## La normale d'une face, par Newell : juste pour toute face plane ou presque, quel que soit N.
func normale(f: int) -> Vector3:
	return _normale_de(sommets, faces[f])


## LES GARDES DE REPLI — DÉCIDÉ (Jordan, 30 septembre 2026) : un geste ne replie aucune face, dans aucune
## tuile. Pour chaque face de `choix`, ses triangles de DÉPART (ceux que `trianguler` dessine) et sa normale de
## départ ; la face est repliée dès qu'un de ces triangles s'aplatit ou se retourne par rapport à elle.
## ⚠ Une face déjà repliée au départ n'est pas gardée : on ne bride pas un geste pour ce qu'il n'a pas fait.
const SEUIL_DE_REPLI := 1e-7

func gardes_de_repli(choix: Array) -> Array:
	var gardes: Array = []
	for f in choix:
		var n := normale(f)
		if n == Vector3.ZERO:
			continue
		var tris := trianguler(f)
		var saine := true
		for t in tris:
			if _aire_orientee(faces[f], t, n) <= SEUIL_DE_REPLI:
				saine = false
				break
		if saine:
			gardes.append([f, tris, n])
	return gardes


## Vrai si une face gardée s'est repliée depuis `gardes_de_repli`.
func replie(gardes: Array) -> bool:
	for g in gardes:
		var face: PackedInt32Array = faces[int(g[0])]
		for t in g[1]:
			if _aire_orientee(face, t, g[2]) <= SEUIL_DE_REPLI:
				return true
	return false


func _aire_orientee(face: PackedInt32Array, t: Array, n: Vector3) -> float:
	var a: Vector3 = sommets[face[t[0]]]
	return (sommets[face[t[1]]] - a).cross(sommets[face[t[2]]] - a).dot(n)


static func _normale_de(s: PackedVector3Array, face: PackedInt32Array) -> Vector3:
	var n := Vector3.ZERO
	for i in face.size():
		var a: Vector3 = s[face[i]]
		var b: Vector3 = s[face[(i + 1) % face.size()]]
		n += Vector3((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y))
	return n.normalized()


func centre(f: int) -> Vector3:
	var c := Vector3.ZERO
	for i in faces[f]:
		c += sommets[i]
	return c / float((faces[f] as PackedInt32Array).size())


static func arete(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))


## {arête: [faces]} — l'adjacence, recalculée à la demande (le maillage change à chaque geste).
func faces_par_arete() -> Dictionary:
	var d := {}
	for f in faces.size():
		var face: PackedInt32Array = faces[f]
		for i in face.size():
			var e := arete(face[i], face[(i + 1) % face.size()])
			if not d.has(e):
				d[e] = []
			d[e].append(f)
	return d


func aretes() -> Array:
	return faces_par_arete().keys()


## Le premier point touché par un rayon : {"face", "point", "distance"} ou {}.
func lancer_rayon(origine: Vector3, direction: Vector3) -> Dictionary:
	var meilleur := {}
	var d_min := INF
	for f in faces.size():
		var face: PackedInt32Array = faces[f]
		for t in trianguler(f):
			var hit = Geometry3D.ray_intersects_triangle(origine, direction, sommets[face[t[0]]],
				sommets[face[t[1]]], sommets[face[t[2]]])
			if hit != null:
				var d: float = origine.distance_to(hit)
				if d < d_min:
					d_min = d
					meilleur = {"face": f, "point": hit, "distance": d}
	return meilleur


# ── L'ACCÉLÉRATEUR DE RAYONS ─────────────────────────────────────────────────────────────────────────
#
# ⚠ **MESURÉ : UN RAYON BRUT COÛTE ~25 ms SUR LE TÉMOIN** (15 560 faces testées). Un clic, passe ; une
# sélection par boîte qui ignore le CACHÉ tire un rayon par élément, et en demanderait des milliers.
# Une GRILLE range chaque face dans les cases que touche sa boîte ; un rayon ne teste que les faces des
# cases qu'il TRAVERSE (Amanatides & Woo), et s'arrête dès qu'un impact est plus proche que la sortie de la
# case courante. `lancer_rayon` (brut) reste la RÉFÉRENCE : l'accélérateur doit rendre exactement la même
# face, et c'est ce que le test vérifie.
# ⚠ La grille est une PHOTO : elle ne suit pas les sommets. L'écran la rebâtit après chaque changement.

var _grille := {}
var _grille_min := Vector3.ZERO
var _grille_pas := 1.0
var _grille_n := Vector3i.ZERO


func preparer_rayons(pas := 1.0) -> void:
	_grille = {}
	_grille_pas = pas
	if sommets.is_empty():
		_grille_n = Vector3i.ZERO
		return
	var bmin := sommets[0]
	var bmax := sommets[0]
	for p in sommets:
		bmin = bmin.min(p)
		bmax = bmax.max(p)
	_grille_min = bmin - Vector3.ONE * 1e-3
	_grille_n = Vector3i(((bmax - _grille_min) / pas).floor()) + Vector3i.ONE
	for f in faces.size():
		var face: PackedInt32Array = faces[f]
		var fmin: Vector3 = sommets[face[0]]
		var fmax: Vector3 = fmin
		for i in face:
			fmin = fmin.min(sommets[i])
			fmax = fmax.max(sommets[i])
		var a := _case_de(fmin)
		var b := _case_de(fmax)
		for x in range(a.x, b.x + 1):
			for y in range(a.y, b.y + 1):
				for z in range(a.z, b.z + 1):
					var c := Vector3i(x, y, z)
					if not _grille.has(c):
						_grille[c] = []
					_grille[c].append(f)


func _case_de(p: Vector3) -> Vector3i:
	var c := Vector3i(((p - _grille_min) / _grille_pas).floor())
	return c.clamp(Vector3i.ZERO, _grille_n - Vector3i.ONE)


func lancer_rayon_rapide(origine: Vector3, direction: Vector3) -> Dictionary:
	if _grille_n == Vector3i.ZERO:
		preparer_rayons()
	if _grille_n == Vector3i.ZERO:
		return {}
	var d := direction.normalized()
	var boite := AABB(_grille_min, Vector3(_grille_n) * _grille_pas)
	# Le point d'entrée dans la grille (l'origine elle-même si elle est dedans).
	var t0 := 0.0
	if not boite.has_point(origine):
		var entree = boite.intersects_ray(origine, d)
		if entree == null:
			return {}
		t0 = origine.distance_to(entree)
	var p := origine + d * (t0 + 1e-6)
	var c := _case_de(p)
	var pas := Vector3i(int(signf(d.x)), int(signf(d.y)), int(signf(d.z)))
	var t_max := Vector3.INF
	var t_delta := Vector3.INF
	for axe in 3:
		if absf(d[axe]) > 1e-12:
			var bord: float = _grille_min[axe] + (c[axe] + (1 if pas[axe] > 0 else 0)) * _grille_pas
			t_max[axe] = t0 + (bord - p[axe]) / d[axe]
			t_delta[axe] = _grille_pas / absf(d[axe])
	var testees := {}
	var meilleur := {}
	var d_min := INF
	while c.x >= 0 and c.y >= 0 and c.z >= 0 and c.x < _grille_n.x and c.y < _grille_n.y and c.z < _grille_n.z:
		for f in _grille.get(c, []):
			if testees.has(f):
				continue
			testees[f] = true
			var face: PackedInt32Array = faces[f]
			for t in trianguler(f):
				var hit = Geometry3D.ray_intersects_triangle(origine, d, sommets[face[t[0]]],
					sommets[face[t[1]]], sommets[face[t[2]]])
				if hit != null:
					var dist: float = origine.distance_to(hit)
					if dist < d_min:
						d_min = dist
						meilleur = {"face": f, "point": hit, "distance": dist}
		# La sortie de cette case : un impact plus proche ne peut plus être battu.
		var sortie := minf(t_max.x, minf(t_max.y, t_max.z))
		if d_min <= sortie:
			break
		if t_max.x <= t_max.y and t_max.x <= t_max.z:
			c.x += pas.x
			t_max.x += t_delta.x
		elif t_max.y <= t_max.z:
			c.y += pas.y
			t_max.y += t_delta.y
		else:
			c.z += pas.z
			t_max.z += t_delta.z
	return meilleur


## Le point est-il VU depuis `oeil` ? Vrai si le premier impact du rayon vers lui n'est pas plus proche
## que lui (à `marge` près) — ce que la boîte B demande pour ignorer le caché.
func visible_depuis(oeil: Vector3, p: Vector3, marge := 1e-3) -> bool:
	var vers := p - oeil
	var hit := lancer_rayon_rapide(oeil, vers)
	return hit.is_empty() or float(hit["distance"]) >= vers.length() - marge


# ── LES TRANSFORMATIONS (G, R, S) ───────────────────────────────────────────────────────────────────

## Applique `t` aux sommets `ids`. G, R et S n'en sont que trois formes : un déplacement, une rotation ou
## une échelle AUTOUR DU PIVOT, que l'écran compose.
## ⚠ **L'ÉDITION PROPORTIONNELLE (O)** : avec `rayon > 0`, les sommets NON choisis à moins de `rayon` du
## plus proche sommet choisi suivent en partie, selon une retombée douce (3t² − 2t³, la « Smooth » de
## Blender). Les positions de départ sont celles d'AVANT le geste : l'écran rejoue depuis elles.
## `candidats` (facultatif) : les seuls sommets qui PEUVENT suivre — l'écran les calcule une fois par geste,
## pour ne pas mesurer chaque sommet du maillage contre chaque sommet choisi à chaque mouvement de souris.
func transformer(ids: Array, t: Transform3D, depart: PackedVector3Array, rayon := 0.0, candidats: Array = []) -> void:
	var choisis := {}
	for i in ids:
		choisis[i] = true
		sommets[i] = t * depart[i]
	if rayon <= 0.0:
		return
	for i in (candidats if not candidats.is_empty() else range(sommets.size())):
		if choisis.has(i):
			continue
		var d := INF
		for j in ids:
			d = minf(d, depart[i].distance_to(depart[j]))
		if d >= rayon:
			sommets[i] = depart[i]
			continue
		var x := 1.0 - d / rayon
		var w := x * x * (3.0 - 2.0 * x)
		sommets[i] = depart[i].lerp(t * depart[i], w)


# ── LES OPÉRATIONS DE TOPOLOGIE ─────────────────────────────────────────────────────────────────────

## E sur des FACES — l'extrusion de RÉGION. Les faces choisies se détachent : leurs sommets sont
## dupliqués, et chaque arête de BORD de la région reçoit un quad de côté. Rend {"sommets": les nouveaux
## (à déplacer), "normale": la moyenne des faces, "bord": [[p, q, face]…] les arêtes de bord orientées}.
## ⚠ **L'ORIENTATION DU QUAD DE CÔTÉ EST FORCÉE PAR SES DEUX VOISINES** : `[a, b, b', a']` parcourt a→b à
## l'inverse de la face du dehors (qui avait b→a) et b'→a' à l'inverse de la face extrudée (a'→b'). Un
## seul autre ordre, et la coque se retournait par bandes.
func extruder_faces(choix: Array) -> Dictionary:
	var region := {}
	for f in choix:
		region[f] = true
	var usage := {}
	for f in region:
		var face: PackedInt32Array = faces[f]
		for i in face.size():
			var e := arete(face[i], face[(i + 1) % face.size()])
			usage[e] = usage.get(e, 0) + 1
	var double := {}
	var nrm := Vector3.ZERO
	for f in region:
		nrm += normale(f)
		for i in faces[f]:
			if not double.has(i):
				double[i] = sommets.size()
				sommets.append(sommets[i])
	var bord: Array = []
	var cotes: Array = []
	for f in region:
		var face: PackedInt32Array = faces[f]
		for i in face.size():
			var a: int = face[i]
			var b: int = face[(i + 1) % face.size()]
			if usage[arete(a, b)] == 1:
				cotes.append([PackedInt32Array([a, b, double[b], double[a]]), teintes[f], mat(f)])
				bord.append([double[a], double[b], f])
		var neuve := PackedInt32Array()
		for i in face:
			neuve.append(double[i])
		faces[f] = neuve
	for c in cotes:
		_ajouter(c[0], c[1], c[2])
	var nouveaux: Array = double.values()
	var carte := nettoyer()
	return {"sommets": _renumeroter(nouveaux, carte), "normale": nrm.normalized(),
		"bord": bord.map(func(e): return [carte[e[0]], carte[e[1]], e[2]])}


## E sur des ARÊTES : chaque arête choisie lance un quad hors de sa face (le rebord d'un trou, le bord
## d'une paroi ouverte). Rend les nouveaux sommets.
func extruder_aretes(choix: Array) -> Array:
	var fpa := faces_par_arete()
	var double := {}
	var nouvelles: Array = []
	for e in choix:
		var e2: Vector2i = e
		if not fpa.has(e2):
			continue
		var f: int = fpa[e2][0]
		var face: PackedInt32Array = faces[f]
		var a := e2.x
		var b := e2.y
		# Le sens de l'arête DANS sa face : le quad neuf la parcourt à l'envers.
		var ia := face.find(a)
		if face[(ia + 1) % face.size()] != b:
			var t := a
			a = b
			b = t
		for i in [a, b]:
			if not double.has(i):
				double[i] = sommets.size()
				sommets.append(sommets[i])
		nouvelles.append([PackedInt32Array([b, a, double[a], double[b]]), teintes[f], mat(f)])
	for n in nouvelles:
		_ajouter(n[0], n[1], n[2])
	return double.values()


## I — L'INSET DE RÉGION : une extrusion SANS profondeur, dont le bord seul rentre de `epaisseur` DANS le
## plan de ses faces. ⚠ Le décalage de chaque sommet de bord suit la BISSECTRICE de ses deux arêtes, divisée
## par le cosinus du demi-angle : l'épaisseur reste constante le long d'un bord qui tourne (un coin de
## carré rentre de √2 × e en diagonale, pas de e). Plafonné, pour qu'un angle aigu ne parte pas à l'infini.
func inserer(choix: Array, epaisseur: float) -> Dictionary:
	var r := extruder_faces(choix)
	var perps := {}
	for e in r["bord"]:
		var p: int = e[0]
		var q: int = e[1]
		var d: Vector3 = (sommets[q] - sommets[p]).normalized()
		var dedans: Vector3 = normale(e[2]).cross(d).normalized()
		for i in [p, q]:
			if not perps.has(i):
				perps[i] = []
			perps[i].append(dedans)
	var depart := sommets.duplicate()
	for i in perps:
		var somme := Vector3.ZERO
		for v in perps[i]:
			somme += v
		if somme.length_squared() < 1e-12:
			continue
		var dir := somme.normalized()
		var c: float = maxf(dir.dot(perps[i][0]), 0.25)
		sommets[i] = depart[i] + dir * (epaisseur / c)
	return r


## X — SUPPRIMER. Sur des faces : les faces. Sur des arêtes ou des sommets : toute face qui les touche.
## ⚠ **ÇA OUVRE UN TROU, ET C'EST VOULU** : il se voit, et F le rebouche.
func supprimer_faces(choix: Array) -> void:
	var ote := {}
	for f in choix:
		ote[f] = true
	var gardees: Array = []
	var gt := PackedColorArray()
	var gm := PackedInt32Array()
	var gu: Array = []
	for f in faces.size():
		if not ote.has(f):
			gardees.append(faces[f])
			gt.append(teintes[f])
			gm.append(mat(f))
			gu.append(uv(f))
	faces = gardees
	teintes = gt
	mats = gm
	uvs = gu
	nettoyer()


func supprimer_sommets(choix: Array) -> void:
	var ote := {}
	for i in choix:
		ote[i] = true
	var fs: Array = []
	for f in faces.size():
		for i in faces[f]:
			if ote.has(i):
				fs.append(f)
				break
	supprimer_faces(fs)


func supprimer_aretes(choix: Array) -> void:
	var fpa := faces_par_arete()
	var fs := {}
	for e in choix:
		for f in fpa.get(e, []):
			fs[f] = true
	supprimer_faces(fs.keys())


## M — FUSIONNER AU CENTRE : les sommets choisis n'en font plus qu'un, à leur moyenne. Les faces qui
## s'effondrent (moins de trois sommets distincts) disparaissent. Rend le sommet restant (renuméroté).
func fusionner(choix: Array) -> int:
	if choix.size() < 2:
		return choix[0] if choix.size() == 1 else -1
	var c := Vector3.ZERO
	for i in choix:
		c += sommets[i]
	var cible: int = choix[0]
	sommets[cible] = c / float(choix.size())
	var vers := {}
	for i in choix:
		vers[i] = cible
	for f in faces.size():
		var face: PackedInt32Array = faces[f]
		for k in face.size():
			face[k] = vers.get(face[k], face[k])
		faces[f] = face
	var carte := nettoyer()
	return carte[cible]


## F — REMPLIR : une face neuve sur les sommets choisis. ⚠ **L'ORDRE N'EST PAS CELUI DU CLIC** : on les
## range par angle autour de leur centre, dans le plan des faces voisines. ⚠ **LE SENS EST IMPOSÉ PAR LES
## VOISINES** : si une face existante parcourt déjà a→b, la neuve doit parcourir b→a — sinon la coque se
## retourne là où l'on rebouche. Rend l'indice de la face, ou −1.
func remplir(choix: Array) -> int:
	if choix.size() < 3:
		return -1
	var c := Vector3.ZERO
	for i in choix:
		c += sommets[i]
	c /= float(choix.size())
	# Le plan : la moyenne des normales des faces qui touchent ces sommets, sinon trois points.
	var voisins := {}
	for i in choix:
		voisins[i] = true
	var nrm := Vector3.ZERO
	var teinte := Color.WHITE
	var m := -1
	for f in faces.size():
		for i in faces[f]:
			if voisins.has(i):
				nrm += normale(f)
				teinte = teintes[f]
				m = mat(f)
				break
	if nrm.length_squared() < 1e-10:
		nrm = (sommets[choix[1]] - sommets[choix[0]]).cross(sommets[choix[2]] - sommets[choix[0]])
	nrm = nrm.normalized()
	var u := nrm.cross(Vector3.UP if absf(nrm.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := nrm.cross(u)
	var ordre: Array = choix.duplicate()
	ordre.sort_custom(func(a: int, b: int) -> bool:
		var pa: Vector3 = sommets[a] - c
		var pb: Vector3 = sommets[b] - c
		return atan2(pa.dot(v), pa.dot(u)) < atan2(pb.dot(v), pb.dot(u)))
	var face := PackedInt32Array(ordre)
	# Le sens : contre les arêtes orientées des voisines.
	var orientees := {}
	for f in faces:
		for k in (f as PackedInt32Array).size():
			orientees[Vector2i(f[k], f[(k + 1) % f.size()])] = true
	var pour := 0
	var contre := 0
	for k in face.size():
		var a := face[k]
		var b := face[(k + 1) % face.size()]
		if orientees.has(Vector2i(a, b)):
			contre += 1
		if orientees.has(Vector2i(b, a)):
			pour += 1
	if contre > pour:
		face.reverse()
	_ajouter(face, teinte, m)
	return faces.size() - 1


## SUBDIVISER : chaque face choisie devient un quad par sommet, autour de son centre et des milieux de
## ses arêtes. ⚠ **UNE VOISINE NON CHOISIE REÇOIT LE MILIEU DE L'ARÊTE COMMUNE** — elle gagne un sommet
## (un quad devient un pentagone) : sans ça, le milieu flotterait sur son arête, et la coque aurait une
## fente en T. Rend les faces neuves.
func subdiviser(choix: Array) -> Array:
	var region := {}
	for f in choix:
		region[f] = true
	var milieux := {}
	for f in region:
		var face: PackedInt32Array = faces[f]
		for i in face.size():
			var e := arete(face[i], face[(i + 1) % face.size()])
			if not milieux.has(e):
				milieux[e] = sommets.size()
				sommets.append((sommets[e.x] + sommets[e.y]) * 0.5)
	var gardees: Array = []
	var gt := PackedColorArray()
	var gm := PackedInt32Array()
	var gu: Array = []
	var neuves: Array = []
	for f in faces.size():
		var face: PackedInt32Array = faces[f]
		if region.has(f):
			var ci := sommets.size()
			sommets.append(centre(f))
			var n := face.size()
			for i in n:
				var avant := arete(face[(i - 1 + n) % n], face[i])
				var apres := arete(face[i], face[(i + 1) % n])
				neuves.append(gardees.size())
				gardees.append(PackedInt32Array([face[i], milieux[apres], ci, milieux[avant]]))
				gt.append(teintes[f])
				gm.append(mat(f))
				gu.append(PackedVector2Array())
		else:
			var avec := _avec_milieux(face, milieux)
			gardees.append(avec)
			gt.append(teintes[f])
			gm.append(mat(f))
			gu.append(uv(f) if avec.size() == face.size() else PackedVector2Array())
	faces = gardees
	teintes = gt
	mats = gm
	uvs = gu
	return neuves


## Une face dont certaines arêtes ont reçu un milieu : on l'insère entre leurs deux bouts.
static func _avec_milieux(face: PackedInt32Array, milieux: Dictionary) -> PackedInt32Array:
	var sortie := PackedInt32Array()
	for i in face.size():
		var a := face[i]
		var b := face[(i + 1) % face.size()]
		sortie.append(a)
		var e := arete(a, b)
		if milieux.has(e):
			sortie.append(milieux[e])
	return sortie


## L'ANNEAU D'ARÊTES — ce que traverse un loop cut (Ctrl+R) : de quad en quad, l'arête OPPOSÉE, jusqu'à
## boucler ou tomber sur une face qui n'est pas un quad. Rend les arêtes ORIENTÉES [[a, b]…] : le point à
## t de a vers b correspond, d'un quad à l'autre, au point à t de l'arête suivante — sans ça, la coupe
## zigzaguerait.
func anneau(depart: Vector2i) -> Array:
	var fpa := faces_par_arete()
	if not fpa.has(depart):
		return []
	var sortie: Array = [[depart.x, depart.y]]
	var vues := {depart: true}
	var premieres: Array = fpa[depart]
	# ⚠ LES DEUX SENS PARTENT CHACUN DANS UNE DES DEUX FACES DE L'ARÊTE, et gardent l'orientation de
	# départ [x, y] : le point à t de x vers y doit correspondre, partout, au point à t de l'arête suivante.
	for sens in mini(2, premieres.size()):
		var courante: Array = [depart.x, depart.y]
		var f: int = premieres[sens]
		while (faces[f] as PackedInt32Array).size() == 4:
			var face: PackedInt32Array = faces[f]
			var ia := face.find(courante[0])
			var ib := face.find(courante[1])
			# Le voisin de a qui n'est pas b, et le voisin de b qui n'est pas a : l'arête OPPOSÉE, orientée.
			var da: int
			var db: int
			if (ib - ia + 4) % 4 == 1:
				da = face[(ia + 3) % 4]
				db = face[(ib + 1) % 4]
			else:
				da = face[(ia + 1) % 4]
				db = face[(ib + 3) % 4]
			var e := arete(da, db)
			if vues.has(e):
				break
			vues[e] = true
			if sens == 0:
				sortie.append([da, db])
			else:
				sortie.push_front([da, db])
			courante = [da, db]
			var suivante := -1
			for g in fpa.get(e, []):
				if g != f:
					suivante = g
			if suivante < 0:
				break
			f = suivante
	return sortie


## Ctrl+R — LE LOOP CUT : chaque arête de l'anneau est coupée à `t`, et chaque quad traversé se fend en
## deux. Les faces au bout d'un anneau ouvert reçoivent le point neuf dans leur contour (même raison que
## pour subdiviser : pas de fente en T). Rend les sommets neufs, dans l'ordre de l'anneau.
func couper_en_boucle(depart: Vector2i, t := 0.5) -> Array:
	var ring := anneau(depart)
	if ring.is_empty():
		return []
	var milieux := {}
	var neufs: Array = []
	for e in ring:
		var a: int = e[0]
		var b: int = e[1]
		var k := arete(a, b)
		if milieux.has(k):
			continue
		milieux[k] = sommets.size()
		neufs.append(sommets.size())
		sommets.append(sommets[a].lerp(sommets[b], t))
	var gardees: Array = []
	var gt := PackedColorArray()
	var gm := PackedInt32Array()
	var gu: Array = []
	for f in faces.size():
		var face: PackedInt32Array = faces[f]
		var coupees: Array = []
		for i in face.size():
			if milieux.has(arete(face[i], face[(i + 1) % face.size()])):
				coupees.append(i)
		if face.size() == 4 and coupees.size() == 2 and (coupees[1] - coupees[0]) == 2:
			var i0: int = coupees[0]
			var p := [face[i0], face[(i0 + 1) % 4], face[(i0 + 2) % 4], face[(i0 + 3) % 4]]
			var m1: int = milieux[arete(p[0], p[1])]
			var m2: int = milieux[arete(p[2], p[3])]
			gardees.append(PackedInt32Array([p[0], m1, m2, p[3]]))
			gardees.append(PackedInt32Array([m1, p[1], p[2], m2]))
			gt.append(teintes[f])
			gt.append(teintes[f])
			gm.append(mat(f))
			gm.append(mat(f))
			gu.append(PackedVector2Array())
			gu.append(PackedVector2Array())
		else:
			var avec := _avec_milieux(face, milieux)
			gardees.append(avec)
			gt.append(teintes[f])
			gm.append(mat(f))
			gu.append(uv(f) if avec.size() == face.size() else PackedVector2Array())
	faces = gardees
	teintes = gt
	mats = gm
	uvs = gu
	return neufs


## Alt+clic — LA BOUCLE D'ARÊTES : de sommet en sommet, l'arête qui ne partage AUCUNE face avec la
## précédente. Définie sur un sommet de valence 4 (un quad-mesh régulier) ; ailleurs, la boucle s'arrête.
func boucle(depart: Vector2i) -> Array:
	var fpa := faces_par_arete()
	var voisins := {}
	for e in fpa:
		for i in [e.x, e.y]:
			if not voisins.has(i):
				voisins[i] = []
			voisins[i].append(e)
	var sortie: Array = [depart]
	var vues := {depart: true}
	for bout in [depart.y, depart.x]:
		var e := depart
		var v: int = bout
		while true:
			var autour: Array = voisins.get(v, [])
			if autour.size() != 4:
				break
			var fs: Array = fpa.get(e, [])
			var suivante := Vector2i(-1, -1)
			for c in autour:
				if c == e:
					continue
				var partage := false
				for f in fpa.get(c, []):
					if f in fs:
						partage = true
				if not partage:
					suivante = c
			if suivante.x < 0 or vues.has(suivante):
				break
			vues[suivante] = true
			sortie.append(suivante)
			v = suivante.y if suivante.x == v else suivante.x
			e = suivante
	return sortie


# ── LE BISEAU ET LE COUTEAU ─────────────────────────────────────────────────────────────────────────

## Ctrl+B — LE BISEAU D'ARÊTES, un segment de largeur `largeur`.
##
## Chaque COIN de face touché par une arête biseautée recule :
##   - une seule de ses deux arêtes est biseautée → le coin glisse de `largeur` sur l'AUTRE arête (le point
##     est partagé avec la face voisine de cette arête, qui le reçoit dans son contour : pas de fente en T) ;
##   - ses deux arêtes le sont → le coin rentre DANS la face, à `largeur` des deux (l'onglet).
## Chaque arête biseautée devient un quad entre les coins reculés de ses deux faces. Aux BOUTS d'une chaîne,
## il reste un petit trou : il est rebouché par une face qui suit le trou À L'ENVERS — l'orientation vient
## des voisines, jamais d'une supposition.
## ⚠ **LE TROU DU BOUT GARDE LE SOMMET D'ORIGINE** : au coin d'un cube, un petit triangle coplanaire à la
## face voisine reste là où Blender couperait le coin. La forme est la même, la topologie a une face de plus.
## ⚠ Une largeur est plafonnée à 49 % de l'arête sur laquelle elle glisse : deux biseaux ne se croisent pas.
## Rend les faces neuves (les quads du biseau).
func biseauter(choix: Array, largeur: float) -> Array:
	var fpa := faces_par_arete()
	var sel := {}
	for e in choix:
		if (fpa.get(e, []) as Array).size() == 2:
			sel[e] = true
	if sel.is_empty() or largeur <= 0.0:
		return []
	var avant_bords := _bords_orientes()
	var sur_arete := {}   # Vector2i(v, x) orienté → le point à `largeur` de v vers x
	var remplace := {}    # Vector2i(face, indice) → le sommet qui remplace ce coin
	var depart := sommets.duplicate()
	for f in faces.size():
		var face: PackedInt32Array = faces[f]
		var n := face.size()
		for i in n:
			var v := face[i]
			var p := face[(i - 1 + n) % n]
			var s := face[(i + 1) % n]
			var s_in := sel.has(arete(p, v))
			var s_out := sel.has(arete(v, s))
			if s_in and s_out:
				var u1: Vector3 = (depart[p] - depart[v]).normalized()
				var u2: Vector3 = (depart[s] - depart[v]).normalized()
				var bis := (u1 + u2)
				var demi := u1.angle_to(u2) * 0.5
				var k := sommets.size()
				sommets.append(depart[v] + bis.normalized() * (largeur / maxf(sin(demi), 0.2)) \
					if bis.length_squared() > 1e-12 else depart[v])
				remplace[Vector2i(f, i)] = k
			elif s_out:
				remplace[Vector2i(f, i)] = _point_sur(sur_arete, depart, v, p, largeur)
			elif s_in:
				remplace[Vector2i(f, i)] = _point_sur(sur_arete, depart, v, s, largeur)
	# Les faces refaites : leurs coins remplacés, et sur chaque arête NON biseautée, les points que les
	# voisines y ont posés (dans l'ordre, du premier bout vers le second).
	var neuves_faces: Array = []
	var neuves_teintes := PackedColorArray()
	var neuves_mats := PackedInt32Array()
	var neuves_uvs: Array = []
	var coins := {}       # Vector2i(face, indice) → sommet final (pour les quads du biseau)
	for f in faces.size():
		var face: PackedInt32Array = faces[f]
		var n := face.size()
		var sortie := PackedInt32Array()
		for i in n:
			var v := face[i]
			var s := face[(i + 1) % n]
			var c: int = remplace.get(Vector2i(f, i), v)
			coins[Vector2i(f, i)] = c
			sortie.append(c)
			if not sel.has(arete(v, s)):
				for cle in [Vector2i(v, s), Vector2i(s, v)]:
					if sur_arete.has(cle):
						sortie.append(sur_arete[cle])
		var refaite := _sans_doublons(sortie)
		neuves_faces.append(refaite)
		neuves_teintes.append(teintes[f])
		neuves_mats.append(mat(f))
		neuves_uvs.append(uv(f) if refaite == face else PackedVector2Array())
	# Les quads du biseau.
	var quads: Array = []
	for e in sel:
		var f1 := -1
		var f2 := -1
		var i1a := -1
		var i1b := -1
		var i2a := -1
		var i2b := -1
		for f in fpa[e]:
			var face: PackedInt32Array = faces[f]
			var ia := face.find(e.x)
			var ib := face.find(e.y)
			if face[(ia + 1) % face.size()] == e.y:
				f1 = f
				i1a = ia
				i1b = ib
			else:
				f2 = f
				i2a = ia
				i2b = ib
		if f1 < 0 or f2 < 0:
			continue
		var q := _sans_doublons(PackedInt32Array([coins[Vector2i(f1, i1b)], coins[Vector2i(f1, i1a)],
			coins[Vector2i(f2, i2a)], coins[Vector2i(f2, i2b)]]))
		if q.size() >= 3:
			quads.append(neuves_faces.size())
			neuves_faces.append(q)
			neuves_teintes.append(teintes[f1])
			neuves_mats.append(mat(f1))
			neuves_uvs.append(PackedVector2Array())
	faces = neuves_faces
	teintes = neuves_teintes
	mats = neuves_mats
	uvs = neuves_uvs
	# Les trous des bouts : toute arête orientée restée seule, qui n'était pas un bord AVANT.
	_reboucher(avant_bords)
	nettoyer()
	var sortie_faces: Array = []
	for f in quads:
		if f < faces.size():
			sortie_faces.append(f)
	return sortie_faces


func _point_sur(sur_arete: Dictionary, depart: PackedVector3Array, v: int, x: int, largeur: float) -> int:
	var cle := Vector2i(v, x)
	if not sur_arete.has(cle):
		var d: Vector3 = depart[x] - depart[v]
		sur_arete[cle] = sommets.size()
		sommets.append(depart[v] + d.normalized() * minf(largeur, d.length() * 0.49))
	return sur_arete[cle]


static func _sans_doublons(f: PackedInt32Array) -> PackedInt32Array:
	var sortie := PackedInt32Array()
	for i in f.size():
		if f[i] != f[(i + 1) % f.size()]:
			sortie.append(f[i])
	return sortie


## Les arêtes orientées qui n'ont pas de jumelle (un bord), en positions — pour ne reboucher que les trous
## qu'une opération vient d'ouvrir, jamais un bord que l'artiste a voulu.
func _bords_orientes() -> Dictionary:
	var orientees := {}
	for f in faces:
		for k in (f as PackedInt32Array).size():
			orientees[Vector2i(f[k], f[(k + 1) % f.size()])] = true
	var bords := {}
	for e in orientees:
		if not orientees.has(Vector2i(e.y, e.x)):
			bords[_cle_pos(sommets[e.x], sommets[e.y])] = true
	return bords


static func _cle_pos(a: Vector3, b: Vector3) -> String:
	return "%s|%s" % [a.snapped(Vector3.ONE * 1e-5), b.snapped(Vector3.ONE * 1e-5)]


func _reboucher(avant: Dictionary) -> void:
	var orientees := {}
	for f in faces:
		for k in (f as PackedInt32Array).size():
			orientees[Vector2i(f[k], f[(k + 1) % f.size()])] = true
	var suivant := {}
	for e in orientees:
		if orientees.has(Vector2i(e.y, e.x)):
			continue
		if avant.has(_cle_pos(sommets[e.x], sommets[e.y])):
			continue
		suivant[e.x] = e.y
	var vus := {}
	for depart in suivant.keys():
		if vus.has(depart):
			continue
		var boucle := PackedInt32Array()
		var v: int = depart
		while suivant.has(v) and not vus.has(v):
			vus[v] = true
			boucle.append(v)
			v = suivant[v]
		if v != depart or boucle.size() < 3:
			continue
		# Le trou est parcouru dans le sens de ses bords : la face qui le bouche le parcourt à l'envers.
		boucle.reverse()
		_ajouter(boucle, teintes[0] if not teintes.is_empty() else Color.WHITE, mat(0) if not faces.is_empty() else -1)


## K — LE COUTEAU : une coupe qui suit des points posés SUR DES ARÊTES, `[{"arete": Vector2i, "t": float}…]`
## (t de x vers y). Deux points consécutifs doivent border une MÊME face : elle est fendue entre eux. Chaque
## point neuf entre aussi dans l'autre face de son arête (pas de fente en T). Rend les sommets neufs, ou []
## si un pas ne tombe dans aucune face commune — et alors rien n'est coupé.
func couper(points: Array) -> Array:
	if points.size() < 2:
		return []
	var sauve := copie()
	var neufs: Array = []
	var ids: Array = []
	for pt in points:
		var e: Vector2i = pt["arete"]
		var t: float = clampf(float(pt["t"]), 0.0, 1.0)
		var i: int
		if t < 1e-4:
			i = e.x
		elif t > 1.0 - 1e-4:
			i = e.y
		else:
			i = _inserer_sur_arete(e, sommets[e.x].lerp(sommets[e.y], t))
			if i < 0:
				_restaurer(sauve)
				return []
			neufs.append(i)
		ids.append(i)
	for k in range(ids.size() - 1):
		if not _fendre(ids[k], ids[k + 1]):
			_restaurer(sauve)
			return []
	return neufs


## LE COUTEAU PAR POSITIONS (Jordan, 2 octobre 2026 : le couteau traversant) : chaque point est une POSITION posée
## sur une arête (ou un sommet) de CE maillage, retrouvée au moment de couper — un tracé qui repasse plusieurs fois
## dans la même tuile la coupe plusieurs fois, et les indices d'arêtes d'avant la première coupe ne valent plus.
## Rend les sommets neufs (comme `couper`) ; [] et rien de changé si un point n'est sur aucune arête.
## ⚠ CHAQUE POINT EST RETROUVÉ SUR LE MAILLAGE TEL QU'IL EST QUAND ON L'INSÈRE : deux points qui se suivent sur la
## MÊME arête (un trait qui la longe) — `couper` cherchait le second sur l'arête que le premier venait de fendre, ne la
## trouvait plus, et refusait toute la coupe. Un pas le long d'une arête existante ne fend rien ; deux points qui
## tombent sur le même sommet n'en font qu'un.
func couper_aux_positions(points: Array, tolerance := 1e-4) -> Array:
	var sauve := copie()
	var neufs: Array = []
	var ids: Array = []
	for p in points:
		var q := point_de_coupe(p, tolerance)
		if q.is_empty():
			_restaurer(sauve)
			return []
		var e: Vector2i = q["arete"]
		var t: float = q["t"]
		var i: int
		if t < 1e-4:
			i = e.x
		elif t > 1.0 - 1e-4:
			i = e.y
		else:
			i = _inserer_sur_arete(e, q["point"])
			if i < 0:
				_restaurer(sauve)
				return []
			neufs.append(i)
		if ids.is_empty() or ids[-1] != i:
			ids.append(i)
	if ids.size() < 2:
		_restaurer(sauve)
		return []
	for k in range(ids.size() - 1):
		if not _fendre(ids[k], ids[k + 1]):
			_restaurer(sauve)
			return []
	return neufs


## Le point de coupe à la position `p` : {"arete", "t", "point"} — un sommet à `tolerance` près (t = 0), sinon l'arête
## la plus proche à `tolerance` près ; {} sinon.
func point_de_coupe(p: Vector3, tolerance := 1e-4) -> Dictionary:
	for i in sommets.size():
		if sommets[i].distance_to(p) <= tolerance:
			for face: PackedInt32Array in faces:
				var k := Array(face).find(i)
				if k >= 0:
					var j := face[(k + 1) % face.size()]
					var e := arete(i, j)
					return {"arete": e, "t": 0.0 if e.x == i else 1.0, "point": sommets[i]}
	var meilleur := {}
	var d_min := tolerance
	for face: PackedInt32Array in faces:
		for k in face.size():
			var a := face[k]
			var b := face[(k + 1) % face.size()]
			var e := arete(a, b)
			var pa: Vector3 = sommets[e.x]
			var pb: Vector3 = sommets[e.y]
			var ab := pb - pa
			var t := clampf((p - pa).dot(ab) / maxf(ab.length_squared(), 1e-12), 0.0, 1.0)
			var d := (pa + ab * t).distance_to(p)
			if d <= d_min:
				d_min = d
				meilleur = {"arete": e, "t": t, "point": pa + ab * t}
	return meilleur


func _restaurer(m: RefCounted) -> void:
	sommets = m.sommets
	faces = m.faces
	teintes = m.teintes
	mats = m.mats
	uvs = m.uvs


## Un point neuf sur l'arête e, inséré dans TOUTES les faces qui la bordent. Rend son indice, ou −1.
func _inserer_sur_arete(e: Vector2i, p: Vector3) -> int:
	var i := sommets.size()
	var touche := false
	for f in faces.size():
		var face: PackedInt32Array = faces[f]
		for k in face.size():
			var a := face[k]
			var b := face[(k + 1) % face.size()]
			if arete(a, b) == e:
				face.insert(k + 1, i)
				faces[f] = face
				_effacer_uv(f)
				touche = true
				break
	if not touche:
		return -1
	sommets.append(p)
	return i


## Fend en deux la face qui contient a ET b (non voisins dans son contour). Rend faux s'il n'y en a pas.
func _fendre(a: int, b: int) -> bool:
	if a == b:
		return false
	for f in faces.size():
		var face: PackedInt32Array = faces[f]
		var ia := face.find(a)
		var ib := face.find(b)
		if ia < 0 or ib < 0:
			continue
		var n := face.size()
		if (ib - ia + n) % n == 1 or (ia - ib + n) % n == 1:
			return true   # déjà une arête : rien à couper
		var une := PackedInt32Array()
		var k := ia
		while true:
			une.append(face[k])
			if k == ib:
				break
			k = (k + 1) % n
		var autre := PackedInt32Array()
		k = ib
		while true:
			autre.append(face[k])
			if k == ia:
				break
			k = (k + 1) % n
		faces[f] = une
		_effacer_uv(f)
		_ajouter(autre, teintes[f], mat(f))
		return true
	return false


# ── LE MÉNAGE ───────────────────────────────────────────────────────────────────────────────────────

## Retire les sommets répétés d'affilée dans une face, les faces de moins de trois sommets, et les
## sommets que plus aucune face n'emploie. Rend la carte {ancien: nouveau} des sommets gardés.
func nettoyer() -> Dictionary:
	var gardees: Array = []
	var gt := PackedColorArray()
	var gm := PackedInt32Array()
	var gu: Array = []
	for f in faces.size():
		var face: PackedInt32Array = faces[f]
		var propre := PackedInt32Array()
		for i in face.size():
			if face[i] != face[(i + 1) % face.size()]:
				propre.append(face[i])
		var distincts := {}
		for i in propre:
			distincts[i] = true
		if distincts.size() >= 3:
			gardees.append(propre)
			gt.append(teintes[f] if f < teintes.size() else Color.WHITE)
			gm.append(mat(f))
			gu.append(uv(f) if propre.size() == face.size() else PackedVector2Array())
	faces = gardees
	teintes = gt
	mats = gm
	uvs = gu
	var emploi := {}
	for face in faces:
		for i in face:
			emploi[i] = true
	var carte := {}
	var neufs := PackedVector3Array()
	for i in sommets.size():
		if emploi.has(i):
			carte[i] = neufs.size()
			neufs.append(sommets[i])
	sommets = neufs
	for f in faces.size():
		var face: PackedInt32Array = faces[f]
		for k in face.size():
			face[k] = carte[face[k]]
		faces[f] = face
	return carte


static func _renumeroter(ids: Array, carte: Dictionary) -> Array:
	var sortie: Array = []
	for i in ids:
		if carte.has(i):
			sortie.append(carte[i])
	return sortie
