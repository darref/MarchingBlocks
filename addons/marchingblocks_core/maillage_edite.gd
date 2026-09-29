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


func copie() -> RefCounted:
	var m: RefCounted = get_script().new()
	m.sommets = sommets.duplicate()
	for f in faces:
		m.faces.append((f as PackedInt32Array).duplicate())
	m.teintes = teintes.duplicate()
	return m


# ── L'ENTRÉE ET LA SORTIE ───────────────────────────────────────────────────────────────────────────

## Lit un maillage de Godot : soude les sommets par POSITION, retourne les faces dans le sens du modèle,
## et RECOLLE les quads. ⚠ **LE TÉMOIN EST FAIT DE QUADS POSÉS EN DEUX TRIANGLES CONSÉCUTIFS**
## (`BlocsMaitres._quad` : [0,1,2] puis [0,2,3]) : une paire qui partage sa diagonale et reste plane redevient
## UN quad. Sans ça, l'artiste éditerait deux fois plus de faces, et ni la boucle d'arêtes ni le loop cut
## ne trouveraient leur chemin — ils ne suivent que des quads.
static func depuis(mesh: Mesh, epsilon := 0.00001) -> RefCounted:
	var m: RefCounted = load("res://addons/marchingblocks_core/maillage_edite.gd").new()
	var index := {}
	var tris: Array = []
	var couleurs_tri: Array = []
	for s in mesh.get_surface_count():
		var a: Array = mesh.surface_get_arrays(s)
		var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var col = a[Mesh.ARRAY_COLOR]
		var ind = a[Mesh.ARRAY_INDEX]
		var n: int = (ind as PackedInt32Array).size() if ind != null else pos.size()
		for t in range(0, n, 3):
			var ids := PackedInt32Array()
			var teinte := Color.WHITE
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
			if ids[0] == ids[1] or ids[1] == ids[2] or ids[0] == ids[2]:
				continue
			tris.append(ids)
			couleurs_tri.append(teinte)
	var i := 0
	while i < tris.size():
		if i + 1 < tris.size():
			var q := _recoller(m.sommets, tris[i], tris[i + 1])
			if not q.is_empty() and couleurs_tri[i] == couleurs_tri[i + 1]:
				m.faces.append(q)
				m.teintes.append(couleurs_tri[i])
				i += 2
				continue
		m.faces.append(tris[i])
		m.teintes.append(couleurs_tri[i])
		i += 1
	return m


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
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var col := PackedColorArray()
	for f in faces.size():
		var face: PackedInt32Array = faces[f]
		var n := normale(f)
		for t in trianguler(f):
			# Horaire pour Godot : le triangle trigonométrique [a,b,c] s'écrit [a,c,b].
			for k in [0, 2, 1]:
				pos.append(sommets[face[t[k]]])
				nor.append(n)
				col.append(teintes[f] if f < teintes.size() else Color.WHITE)
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = pos
	if avec_normales:
		a[Mesh.ARRAY_NORMAL] = nor
	a[Mesh.ARRAY_COLOR] = col
	var mesh := ArrayMesh.new()
	if not pos.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return mesh


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


# ── LES TRANSFORMATIONS (G, R, S) ───────────────────────────────────────────────────────────────────

## Applique `t` aux sommets `ids`. G, R et S n'en sont que trois formes : un déplacement, une rotation ou
## une échelle AUTOUR DU PIVOT, que l'écran compose.
## ⚠ **L'ÉDITION PROPORTIONNELLE (O)** : avec `rayon > 0`, les sommets NON choisis à moins de `rayon` du
## plus proche sommet choisi suivent en partie, selon une retombée douce (3t² − 2t³, la « Smooth » de
## Blender). Les positions de départ sont celles d'AVANT le geste : l'écran rejoue depuis elles.
func transformer(ids: Array, t: Transform3D, depart: PackedVector3Array, rayon := 0.0) -> void:
	var choisis := {}
	for i in ids:
		choisis[i] = true
		sommets[i] = t * depart[i]
	if rayon <= 0.0:
		return
	for i in sommets.size():
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
				cotes.append([PackedInt32Array([a, b, double[b], double[a]]), teintes[f]])
				bord.append([double[a], double[b], f])
		var neuve := PackedInt32Array()
		for i in face:
			neuve.append(double[i])
		faces[f] = neuve
	for c in cotes:
		faces.append(c[0])
		teintes.append(c[1])
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
		nouvelles.append([PackedInt32Array([b, a, double[a], double[b]]), teintes[f]])
	for n in nouvelles:
		faces.append(n[0])
		teintes.append(n[1])
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
	for f in faces.size():
		if not ote.has(f):
			gardees.append(faces[f])
			gt.append(teintes[f])
	faces = gardees
	teintes = gt
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
	for f in faces.size():
		for i in faces[f]:
			if voisins.has(i):
				nrm += normale(f)
				teinte = teintes[f]
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
	faces.append(face)
	teintes.append(teinte)
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
		else:
			gardees.append(_avec_milieux(face, milieux))
			gt.append(teintes[f])
	faces = gardees
	teintes = gt
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
		else:
			gardees.append(_avec_milieux(face, milieux))
			gt.append(teintes[f])
	faces = gardees
	teintes = gt
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


# ── LE MÉNAGE ───────────────────────────────────────────────────────────────────────────────────────

## Retire les sommets répétés d'affilée dans une face, les faces de moins de trois sommets, et les
## sommets que plus aucune face n'emploie. Rend la carte {ancien: nouveau} des sommets gardés.
func nettoyer() -> Dictionary:
	var gardees: Array = []
	var gt := PackedColorArray()
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
	faces = gardees
	teintes = gt
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
