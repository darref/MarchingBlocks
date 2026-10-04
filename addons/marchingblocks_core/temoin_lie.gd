extends RefCounted
## LE TÉMOIN LIÉ, ÉDITABLE — une tuile par clé, en copies liées (charte §3, Jordan, 30 septembre 2026).
##
## Le modèle que le modeleur de l'appli édite : les 52 tuiles (un `MaillageEdite` chacune, dans le repère
## de RÉFÉRENCE de sa clé, centré sur son sommet), un jeu de matériaux COMMUN, et les occurrences du
## témoin (`BlocsMaitres.occurrences_du_temoin`) — chaque sommet à surface montre la tuile de sa clé.
## On sculpte une occurrence : c'est la tuile qu'on sculpte, donc toutes ses occurrences suivent.
##
## ⚠ **LES MATÉRIAUX SONT UN SEUL TABLEAU, PARTAGÉ PAR RÉFÉRENCE** entre les 52 tuiles : un matériau neuf
## existe partout, et l'indice d'une face veut dire la même chose dans toutes les tuiles. `MaillageEdite.
## copie()` le duplique (c'est juste pour un maillage seul) : `poser_tuile` le re-partage.
## ⚠ **LES OCCURRENCES NE S'ENREGISTRENT PAS** : elles se DÉDUISENT du témoin (§6), comme dans le `.glb`.

const ME := preload("res://addons/marchingblocks_core/maillage_edite.gd")
const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")

const FORMAT := "marchingblocks-linked-witness"
const VERSION := 1

## UN LOT DE TUILES, pour l'annulation d'un geste qui en touche PLUSIEURS (les sections partagées : tirer un
## sommet de bord entraîne ses correspondants dans d'autres tuiles). {clé: copie de MaillageEdite}.
class Lot extends RefCounted:
	var tuiles := {}


var tuiles := {}          # nom de tuile (clé, ou `<clé>_var<k>`) → MaillageEdite
var materiaux: Array = []
## [{sommet, cle (la TUILE que montre l'occurrence), modele (sa clé), orientation, pose: Transform3D}]
var occurrences: Array = []
## LES VARIANTES VOULUES (Jordan, 4 octobre 2026) : {sommet du témoin: k} — les occurrences qui montrent la variante k
## de leur clé. Une variante est une tuile de plus dans `tuiles` (`<clé>_var<k>`), sculptée comme les autres : ses
## copies sont les occurrences qui lui sont affectées, et ses bords sont ceux de sa clé (`Sections` la range dans les
## classes de sa clé). ⚠ LE TÉMOIN MONTRE CE QUE LE MONDE MONTRERA : une variante y est posée à côté de ses voisines
## du témoin, et c'est là qu'on juge ses raccords.
var affectation := {}


## Le témoin calculé, en tuiles liées (~2 s : `BlocsMaitres.tuiles_du_temoin` ne découpe que 52 sommets).
static func depuis_le_temoin_calcule() -> RefCounted:
	var t: RefCounted = load("res://addons/marchingblocks_core/temoin_lie.gd").new()
	var calc: Dictionary = BM.tuiles_du_temoin()
	for cle in calc:
		t.tuiles[cle] = ME.depuis(calc[cle]["mesh"])
	t._partager()
	t._deduire_les_occurrences()
	return t


## UN TÉMOIN LIÉ RELU D'UN `.glb` (revenu de Blender) — il devient éditable dans l'appli (charte §3,
## Jordan, 30 septembre 2026 : au retour, le travail devient le témoin de la couche). null si le fichier
## n'est pas un témoin lié.
## ⚠ **ON GARDE LA PEINTURE** : chaque matériau devient UNE entrée du témoin (partagée par toutes les tuiles
## qui le portent, reconnue par son objet), avec ses UV ; son image est écrite en PNG dans `dossier_images`
## (le maillage éditable référence ses textures par chemin). Les six teintes de la légende redeviennent des
## teintes (matériau −1), reconnues par leur NOM — c'est ainsi qu'elles partent (`BlocsMaitres`).
static func depuis_glb(chemin: String, dossier_images: String, erreurs: Array = []) -> RefCounted:
	var RP := load("res://addons/marchingblocks_core/repli_procedural.gd")
	var lu: Dictionary = BM.tuiles_liees(chemin, erreurs, [])
	if lu.is_empty():
		return null
	var t: RefCounted = load("res://addons/marchingblocks_core/temoin_lie.gd").new()
	var legende := {}
	for teinte in RP.TEINTES:
		legende[str(teinte["nom"])] = teinte["couleur"]
	var connus := {}   # id d'objet du matériau → indice
	var materiau_de := func(mat: Material) -> Dictionary:
		if mat == null:
			return {"mat": -1, "teinte": null}
		if legende.has(mat.resource_name):
			return {"mat": -1, "teinte": legende[mat.resource_name]}
		# ⚠ LE TÉMOIN MODÉLISÉ ÉCRIT SA LÉGENDE EN UN SEUL MATÉRIAU (« legend »), les teintes dans la couleur des
		# sommets (`MaillageEdite.materiau_de_legende`) : lu comme un vrai matériau, il peignait TOUTES les
		# faces de la légende d'un matériau blanc (vu rougir, `test_temoin_lie`).
		if mat.resource_name == ME.materiau_de_legende().resource_name:
			return {"mat": -1, "teinte": null}
		var id := mat.get_instance_id()
		if connus.has(id):
			return {"mat": connus[id], "teinte": null}
		var e := {"nom": mat.resource_name if mat.resource_name != "" else "Material %d" % (t.materiaux.size() + 1),
			"couleur": Color.WHITE, "rugosite": 0.8, "metal": 0.0, "texture": "", "echelle": 1.0, "projection": "uv"}
		if mat is BaseMaterial3D:
			var sm := mat as BaseMaterial3D
			e["couleur"] = sm.albedo_color
			e["rugosite"] = sm.roughness
			e["metal"] = sm.metallic
			if sm.albedo_texture != null and sm.albedo_texture.get_image() != null:
				DirAccess.make_dir_recursive_absolute(dossier_images)
				# ⚠ LES CARTES DU glTF REVIENNENT AUSSI (3 octobre 2026) : la normale et l'ORM que portait le matériau
				# sont écrits À CÔTÉ de l'albedo, sous les noms d'un ENSEMBLE (`_color`, `_normal_gl`, `_arm`) —
				# `Peinture.ensemble_de` les retrouve comme ceux d'une bibliothèque. Avant, le témoin revenait de
				# Blender avec son albedo seul.
				var base := dossier_images.path_join("%s_%d" % [chemin.get_file().get_basename(), t.materiaux.size()])
				var png := base + "_color.png"
				if sm.albedo_texture.get_image().save_png(png) == OK:
					e["texture"] = png
					_ecrire_les_cartes_du_gltf(sm, base)
		connus[id] = t.materiaux.size()
		t.materiaux.append(e)
		return {"mat": connus[id], "teinte": null}
	for cle in lu["pieces"]:
		t.tuiles[cle] = ME.depuis(lu["pieces"][cle], 0.00001, materiau_de)
	t.affectation = (lu.get("affectation", {}) as Dictionary).duplicate()
	t._partager()
	t._deduire_les_occurrences()
	return t


## La normale (`<base>_normal_gl.png`, convention glTF = OpenGL) et l'ORM (`<base>_arm.png` : R occlusion, G rugosité,
## B métal — la disposition du glTF) d'un matériau importé, s'il en porte.
static func _ecrire_les_cartes_du_gltf(sm: BaseMaterial3D, base: String) -> void:
	if sm.normal_enabled and sm.normal_texture != null and sm.normal_texture.get_image() != null:
		var n := sm.normal_texture.get_image().duplicate() as Image
		if n.is_compressed():
			n.decompress()
		n.save_png(base + "_normal_gl.png")
	var mr: Image = sm.roughness_texture.get_image() if sm.roughness_texture != null else null
	var ao: Image = sm.ao_texture.get_image() if sm.ao_enabled and sm.ao_texture != null else null
	if mr == null and ao == null:
		return
	var taille: Vector2i = (mr if mr != null else ao).get_size()
	var arm := Image.create(taille.x, taille.y, false, Image.FORMAT_RGB8)
	var a := _rgba8(mr, taille)
	var o := _rgba8(ao, taille)
	for y in taille.y:
		for x in taille.x:
			var r := o.get_pixel(x, y).r if o != null else 1.0
			var g := a.get_pixel(x, y).g if a != null else 1.0
			var b := a.get_pixel(x, y).b if a != null else 1.0
			arm.set_pixel(x, y, Color(r, g, b))
	arm.save_png(base + "_arm.png")


static func _rgba8(img: Image, taille: Vector2i) -> Image:
	if img == null:
		return null
	var c := img.duplicate() as Image
	if c.is_compressed():
		c.decompress()
	c.convert(Image.FORMAT_RGBA8)
	if c.get_size() != taille:
		c.resize(taille.x, taille.y, Image.INTERPOLATE_BILINEAR)
	return c


## LES RÉGLAGES QUE LE glTF NE PORTE PAS (3 octobre 2026) — cartes déduites (`pbr`), choix de l'ensemble (`ensemble`),
## répétition (`echelle`) — repris de `ancien` (le témoin d'avant le retour de Blender), matériau par matériau, par
## leur NOM. Un matériau dont les cartes étaient DÉDUITES les redéduit de son albedo (mêmes réglages, même rendu) plutôt
## que de garder la copie figée que le .glb a rapportée. Rend le nombre de matériaux repris.
func reprendre_les_reglages(ancien: RefCounted) -> int:
	if ancien == null:
		return 0
	var par_nom := {}
	for m in ancien.materiaux:
		par_nom[str(m.get("nom", ""))] = m
	var n := 0
	for m in materiaux:
		var a: Dictionary = par_nom.get(str(m.get("nom", "")), {})
		if a.is_empty():
			continue
		if a.get("pbr") is Dictionary:
			m["pbr"] = (a["pbr"] as Dictionary).duplicate(true)
			# Ses cartes venaient-elles d'un ensemble posé à côté de son image ? Alors le .glb a rapporté CET ensemble,
			# qu'on garde ; sinon elles étaient déduites, et on les redéduit.
			var Peinture := load("res://addons/marchingblocks_core/peinture.gd")
			var tex := str(a.get("texture", ""))
			if not (bool(a.get("ensemble", true)) and tex != "" and not Peinture.ensemble_de(tex).is_empty()):
				m["ensemble"] = false
		elif a.has("ensemble"):
			m["ensemble"] = a["ensemble"]
		if a.has("echelle"):
			m["echelle"] = a["echelle"]
		n += 1
	return n


func _deduire_les_occurrences() -> void:
	var grille := GridMap.new()
	occurrences = []
	for o in BM.occurrences_du_temoin(0):
		if not tuiles.has(o["cle"]):
			continue
		var e: Dictionary = o.duplicate()
		e["modele"] = o["cle"]
		e["pose"] = Transform3D(grille.get_basis_with_orthogonal_index(o["orientation"]),
			Vector3(o["sommet"]) + Vector3.ONE)
		occurrences.append(e)
	grille.free()
	_reaffecter()


## La tuile que montre chaque occurrence, d'après `affectation` ; une affectation vers une variante absente est oubliée.
func _reaffecter() -> void:
	var modele_de := {}
	for o in occurrences:
		modele_de[o["sommet"]] = o["modele"]
	for s in affectation.keys():
		if not modele_de.has(s) or not tuiles.has(MB.nom_de_variante(modele_de[s], int(affectation[s]))):
			affectation.erase(s)
	for o in occurrences:
		o["cle"] = MB.nom_de_variante(o["modele"], int(affectation.get(o["sommet"], 0)))


## ── LES VARIANTES : créer, affecter, supprimer — chacune rend ce qu'il faut pour l'annulation (`etat_des_variantes`).

## Combien de variantes porte la clé `cle`.
func nombre_de_variantes(cle: String) -> int:
	return MB.nombre_de_variantes(cle, tuiles)


## UNE VARIANTE NEUVE de la clé de l'occurrence `i`, COPIE de la tuile que cette occurrence montre, et l'occurrence
## passe à elle. Rend son nom, ou "" (plus de place : `MB.VARIANTES_MAXI`).
func creer_variante(i: int) -> String:
	if i < 0 or i >= occurrences.size():
		return ""
	var cle: String = occurrences[i]["modele"]
	var k: int = nombre_de_variantes(cle) + 1
	if k > MB.VARIANTES_MAXI:
		return ""
	var nom: String = MB.nom_de_variante(cle, k)
	tuiles[nom] = (tuiles[occurrences[i]["cle"]] as RefCounted).copie()
	_partager()
	affectation[occurrences[i]["sommet"]] = k
	_reaffecter()
	return nom


## L'occurrence `i` montre la variante `k` de sa clé (0 : la base). Rend false si cette variante n'existe pas.
func affecter(i: int, k: int) -> bool:
	if i < 0 or i >= occurrences.size():
		return false
	if k > 0 and not tuiles.has(MB.nom_de_variante(occurrences[i]["modele"], k)):
		return false
	if k <= 0:
		affectation.erase(occurrences[i]["sommet"])
	else:
		affectation[occurrences[i]["sommet"]] = k
	_reaffecter()
	return true


## SUPPRIME la variante `nom` : ses occurrences reviennent à la base, et les variantes suivantes de la clé descendent
## d'un rang (une variante 3 sans 2 ne serait jamais posée). Rend false si `nom` n'est pas une variante.
func supprimer_variante(nom: String) -> bool:
	var k: int = MB.rang_de_variante(nom)
	if k == 0 or not tuiles.has(nom):
		return false
	var cle: String = MB.cle_de_tuile(nom)
	var n: int = nombre_de_variantes(cle)
	tuiles.erase(nom)
	for j in range(k + 1, n + 1):
		tuiles[MB.nom_de_variante(cle, j - 1)] = tuiles[MB.nom_de_variante(cle, j)]
		tuiles.erase(MB.nom_de_variante(cle, j))
	for o in occurrences:
		if o["modele"] != cle or not affectation.has(o["sommet"]):
			continue
		var r := int(affectation[o["sommet"]])
		if r == k:
			affectation.erase(o["sommet"])
		elif r > k:
			affectation[o["sommet"]] = r - 1
	_reaffecter()
	return true


## L'ÉTAT DES VARIANTES, pour l'annulation : leurs tuiles (copies) et l'affectation.
func etat_des_variantes() -> Dictionary:
	var t := {}
	for nom in tuiles:
		if MB.rang_de_variante(nom) > 0:
			t[nom] = tuiles[nom].copie()
	return {"tuiles": t, "affectation": affectation.duplicate()}


func poser_etat_des_variantes(e: Dictionary) -> void:
	for nom in tuiles.keys():
		if MB.rang_de_variante(nom) > 0:
			tuiles.erase(nom)
	for nom in e["tuiles"]:
		tuiles[nom] = (e["tuiles"][nom] as RefCounted).copie()
	_partager()
	affectation = (e["affectation"] as Dictionary).duplicate()
	_reaffecter()


## Toutes les tuiles pointent le MÊME tableau de matériaux.
func _partager() -> void:
	for cle in tuiles:
		tuiles[cle].materiaux = materiaux
		# ⚠ ET LE MÊME CACHE DE MATÉRIAUX GODOT (mesuré le 1er octobre 2026) : chaque tuile fabriquait le sien, donc
		# sa propre copie d'un matériau du témoin — le .glb en portait une par tuile (« Green », « Green2 »…), et
		# un témoin relu de Blender en aurait fait autant d'entrées.
		tuiles[cle]._cache_godot = _cache_godot_commun


var _cache_godot_commun := {}


## Remplace la tuile `cle` par une COPIE de `m` — c'est ce que l'annulation appelle. Les matériaux de `m`
## deviennent ceux de tout le témoin (en place : le tableau partagé reste le même objet).
func poser_tuile(cle: String, m: RefCounted) -> void:
	var c: RefCounted = m.copie()
	materiaux.assign(c.materiaux)
	tuiles[cle] = c
	_partager()


func copie() -> RefCounted:
	var t: RefCounted = get_script().new()
	t.materiaux = materiaux.duplicate(true)
	for cle in tuiles:
		t.tuiles[cle] = tuiles[cle].copie()
	t._partager()
	t.affectation = affectation.duplicate()
	t.occurrences = occurrences.duplicate(true)
	return t


## Les occurrences d'une clé (indices dans `occurrences`).
func occurrences_de(cle: String) -> Array:
	var sortie: Array = []
	for i in occurrences.size():
		if occurrences[i]["cle"] == cle:
			sortie.append(i)
	return sortie


## LE RAYON : l'occurrence touchée la première. {occurrence, cle, face, distance, point (monde)} ou {}.
## ⚠ Chaque occurrence est éprouvée dans le repère de sa tuile (la grille de rayons de la tuile), après un
## tri par sa BOÎTE : une case, plus une demi-case de débord toléré de chaque côté (règle (A)).
func rayon(origine: Vector3, direction: Vector3) -> Dictionary:
	var d := direction.normalized()
	var meilleur := {}
	var boite := AABB(-Vector3.ONE, Vector3.ONE * 2.0)
	for i in occurrences.size():
		var pose: Transform3D = occurrences[i]["pose"]
		var inverse: Transform3D = pose.affine_inverse()
		var o_local: Vector3 = inverse * origine
		var d_local: Vector3 = (inverse.basis * d).normalized()
		var entree = boite.intersects_ray(o_local, d_local)
		if entree == null and not boite.has_point(o_local):
			continue
		var tuile: RefCounted = tuiles[occurrences[i]["cle"]]
		var hit: Dictionary = tuile.lancer_rayon_rapide(o_local, d_local)
		if hit.is_empty():
			continue
		var point: Vector3 = pose * (hit["point"] as Vector3)
		var dist: float = origine.distance_to(point)
		if meilleur.is_empty() or dist < float(meilleur["distance"]):
			meilleur = {"occurrence": i, "cle": occurrences[i]["cle"], "face": hit["face"],
				"distance": dist, "point": point}
	return meilleur


## L'ATLAS DU TÉMOIN (Jordan, 1er octobre 2026) : les îlots de TOUTES les tuiles rangés ensemble dans le carré
## [0,1], à UNE échelle. Déplier tuile par tuile rangeait chacune dans le MÊME carré : deux tuiles d'un même
## matériau partageaient leur peinture. `materiau` : −2 toutes les faces, sinon celles qui portent ce matériau
## (−1, la légende). Les copies d'une tuile restent liées : une tuile a UNE place dans l'atlas, pas une par copie.
func deplier_en_atlas(materiau := -2, angle := 66.0, marge := 0.004) -> Dictionary:
	var plats: Array = []
	var n_faces := 0
	var touchees := {}
	for c in tuiles:
		var t: RefCounted = tuiles[c]
		var choix: Array = []
		for f in t.faces.size():
			if materiau == -2 or t.mat(f) == materiau:
				choix.append(f)
		if choix.is_empty():
			continue
		for pl in t.ilots_a_plat(choix, angle):
			pl["cle"] = c
			plats.append(pl)
		n_faces += choix.size()
		touchees[c] = true
	ME.ranger(plats, marge)
	for pl in plats:
		tuiles[pl["cle"]].poser_uvs([pl])
	return {"tuiles": touchees.keys(), "ilots": plats.size(), "faces": n_faces}


## LES TRIANGLES UV DES ÎLOTS qui lisent l'image `chemin` (faces dépliées d'un matériau en projection UV qui la
## porte), à plat, trois par triangle — le masque de la dilatation des cartes PBR (`cartes_pbr.gd`). Une face sans
## UV retombe sur la boîte (elle ne lit pas l'atlas) : elle n'entre pas.
func triangles_uv_de(chemin: String) -> PackedVector2Array:
	var sortie := PackedVector2Array()
	var lisent := {}
	for k in materiaux.size():
		if str(materiaux[k].get("texture", "")) == chemin and str(materiaux[k].get("projection", "")) == "uv":
			lisent[k] = true
	if lisent.is_empty():
		return sortie
	for c in tuiles:
		var t: RefCounted = tuiles[c]
		for f in t.faces.size():
			if not lisent.has(t.mat(f)):
				continue
			var u: PackedVector2Array = t.uv(f)
			if u.is_empty():
				continue
			for tri in t.trianguler(f):
				sortie.append(u[tri[0]])
				sortie.append(u[tri[1]])
				sortie.append(u[tri[2]])
	return sortie


## L'ALBEDO CUIT DEPUIS LE RELIEF GÉOMÉTRIQUE — DEMANDÉ PAR JORDAN (2 octobre 2026 : « déduire aussi l'albedo du
## relief géométrique, comme dans Materialize, autre algorithme »). Pour chaque texel d'un îlot qui lit `chemin`
## (projection UV : un texel = UN point d'une tuile), le point de la tuile, et trois choses lues dans le MAILLAGE :
##   • l'ORIENTATION de sa face (sol, paroi, plafond — une couleur chacun, fondues) ;
##   • la CONVEXITÉ : près d'une arête saillante, la couleur d'usure (`arete`), selon l'angle et la distance ;
##   • la CONCAVITÉ : près d'une arête rentrante, l'ombre de cavité (`cavite`).
## ⚠ **LE LONG DES PLANS DE COUPE, ARÊTES ET CAVITÉS S'ÉTEIGNENT** (sur 1/16 de case) : de l'autre côté du plan, la
## voisine du monde n'est pas celle du témoin — la discipline des coupes (§3) : là, seule l'orientation compte, et
## elle est la même des deux côtés (une section partagée a les mêmes faces). Une arête posée SUR un plan de coupe n'a
## pas de face voisine dans la tuile : elle n'est ni saillante ni rentrante.
## ⚠ Seules les tuiles DÉPLIÉES ont un texel par point : en boîte ou en plan l'image se répète, et un relief cuit
## n'aurait pas de sens — l'appelant le refuse et le dit. Rend {"image": Image RGBA8 (îlots dilatés), "texels": n}.
const RELIEF_DEFAUTS := {"sol": [0.42, 0.55, 0.26], "paroi": [0.52, 0.44, 0.36], "plafond": [0.36, 0.34, 0.38],
	"arete": [0.80, 0.76, 0.68], "usure": 0.7, "cavite": 0.6, "largeur": 0.06}
const BANDE_DE_COUPE := 1.0 / 16.0


static func reglages_du_relief(r: Variant) -> Dictionary:
	var d := RELIEF_DEFAUTS.duplicate(true)
	if r is Dictionary:
		for k in r:
			if d.has(k):
				d[k] = r[k]
	return d


func albedo_du_relief(chemin: String, r: Variant, taille: Vector2i) -> Dictionary:
	var g := reglages_du_relief(r)
	var col := func(k: String) -> Color:
		var a: Array = g[k]
		return Color(float(a[0]), float(a[1]), float(a[2]))
	var c_sol: Color = col.call("sol")
	var c_paroi: Color = col.call("paroi")
	var c_plafond: Color = col.call("plafond")
	var c_arete: Color = col.call("arete")
	var usure := float(g["usure"])
	var cavite := float(g["cavite"])
	var largeur := maxf(0.005, float(g["largeur"]))
	var w := taille.x
	var h := taille.y
	var donnees := PackedByteArray()
	donnees.resize(w * h * 4)
	var masque := PackedByteArray()
	masque.resize(w * h)
	var lisent := {}
	for k in materiaux.size():
		if str(materiaux[k].get("texture", "")) == chemin and str(materiaux[k].get("projection", "")) == "uv":
			lisent[k] = true
	var texels := 0
	for c in tuiles:
		var t: RefCounted = tuiles[c]
		# Les faces de chaque arête de la tuile (deux au plus : le témoin est orienté et étanche par tuile).
		var faces_de := {}
		for f in t.faces.size():
			var fa: PackedInt32Array = t.faces[f]
			for i in fa.size():
				var a: int = fa[i]
				var b: int = fa[(i + 1) % fa.size()]
				var k := "%d|%d" % [mini(a, b), maxi(a, b)]
				if not faces_de.has(k):
					faces_de[k] = []
				faces_de[k].append(f)
		for f in t.faces.size():
			if not lisent.has(t.mat(f)):
				continue
			var u: PackedVector2Array = t.uv(f)
			if u.is_empty():
				continue
			var fa: PackedInt32Array = t.faces[f]
			var n: Vector3 = t.normale(f)
			# Les arêtes de la face qui comptent : [a, b, angle signé] (+ saillante, − rentrante).
			var aretes: Array = []
			for i in fa.size():
				var ia: int = fa[i]
				var ib: int = fa[(i + 1) % fa.size()]
				var voisines: Array = faces_de["%d|%d" % [mini(ia, ib), maxi(ia, ib)]]
				if voisines.size() != 2:
					continue
				var autre: int = voisines[0] if voisines[1] == f else voisines[1]
				var n2: Vector3 = t.normale(autre)
				var angle := acos(clampf(n.dot(n2), -1.0, 1.0))
				if angle < 0.05:
					continue
				var centre := Vector3.ZERO
				for s in t.faces[autre]:
					centre += t.sommets[s]
				centre /= float((t.faces[autre] as PackedInt32Array).size())
				var milieu: Vector3 = (t.sommets[ia] + t.sommets[ib]) * 0.5
				var signe := -1.0 if (centre - milieu).dot(n) > 0.0 else 1.0
				aretes.append([t.sommets[ia], t.sommets[ib], signe * angle / (PI * 0.5)])
			var w_sol := smoothstep(0.35, 0.75, n.y)
			var w_plafond := smoothstep(0.35, 0.75, -n.y)
			var base := c_paroi.lerp(c_sol, w_sol).lerp(c_plafond, w_plafond)
			for tri in t.trianguler(f):
				var pa: Vector3 = t.sommets[fa[tri[0]]]
				var pb: Vector3 = t.sommets[fa[tri[1]]]
				var pc: Vector3 = t.sommets[fa[tri[2]]]
				var ua := u[tri[0]] * Vector2(w, h)
				var ub := u[tri[1]] * Vector2(w, h)
				var uc := u[tri[2]] * Vector2(w, h)
				var aire := (ub - ua).cross(uc - ua)
				if absf(aire) < 1e-9:
					continue
				var x0 := clampi(floori(minf(ua.x, minf(ub.x, uc.x))), 0, w - 1)
				var x1 := clampi(ceili(maxf(ua.x, maxf(ub.x, uc.x))), 0, w - 1)
				var y0 := clampi(floori(minf(ua.y, minf(ub.y, uc.y))), 0, h - 1)
				var y1 := clampi(ceili(maxf(ua.y, maxf(ub.y, uc.y))), 0, h - 1)
				for y in range(y0, y1 + 1):
					for x in range(x0, x1 + 1):
						var q := Vector2(x + 0.5, y + 0.5)
						var l1 := (uc - ub).cross(q - ub) / aire
						var l2 := (ua - uc).cross(q - uc) / aire
						var l3 := 1.0 - l1 - l2
						# Un texel touché d'un demi-texel est pris (le filtrage lit au bord de l'îlot).
						var tol := 0.75 / maxf(1.0, sqrt(absf(aire)))
						if l1 < -tol or l2 < -tol or l3 < -tol:
							continue
						var p := pa * l1 + pb * l2 + pc * l3
						var bord := minf(0.5 - absf(p.x), minf(0.5 - absf(p.y), 0.5 - absf(p.z)))
						var eteint := smoothstep(0.0, BANDE_DE_COUPE, bord)
						var saillant := 0.0
						var rentrant := 0.0
						for e in aretes:
							var d := _distance_au_segment_3d(p, e[0], e[1])
							if d >= largeur:
								continue
							var force: float = absf(float(e[2])) * (1.0 - d / largeur)
							if float(e[2]) > 0.0:
								saillant = maxf(saillant, force)
							else:
								rentrant = maxf(rentrant, force)
						saillant = clampf(saillant * eteint, 0.0, 1.0)
						rentrant = clampf(rentrant * eteint, 0.0, 1.0)
						var couleur := base.lerp(c_arete, saillant * usure) * (1.0 - rentrant * cavite)
						var i := y * w + x
						if masque[i] == 0:
							texels += 1
						masque[i] = 255
						donnees[i * 4] = int(clampf(couleur.r, 0.0, 1.0) * 255.0 + 0.5)
						donnees[i * 4 + 1] = int(clampf(couleur.g, 0.0, 1.0) * 255.0 + 0.5)
						donnees[i * 4 + 2] = int(clampf(couleur.b, 0.0, 1.0) * 255.0 + 0.5)
						donnees[i * 4 + 3] = 255
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, donnees)
	if texels > 0:
		img = load("res://addons/marchingblocks_core/cartes_pbr.gd").dilater(img,
			Image.create_from_data(w, h, false, Image.FORMAT_L8, masque))
	return {"image": img, "texels": texels}


static func _distance_au_segment_3d(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var l := ab.length_squared()
	var t := 0.0 if l <= 0.0 else clampf((p - a).dot(ab) / l, 0.0, 1.0)
	return p.distance_to(a + ab * t)


## LE TÉMOIN ASSEMBLÉ, pour le montrer ou le ranger dans la liste des travaux : chaque occurrence posée.
## Une surface par matériau (Godot plafonne un maillage à 256 surfaces).
func assemble() -> ArrayMesh:
	var par_cle := {}
	for cle in tuiles:
		# Avec ses normales (une par face) : sans elles, un matériau à carte de normales n'a pas de tangentes à lire, et
		# le moteur le dit à chaque vignette (3 octobre 2026).
		par_cle[cle] = tuiles[cle].vers_array_mesh(true)
	var racine := Node3D.new()
	for o in occurrences:
		var mi := MeshInstance3D.new()
		mi.mesh = par_cle[o["cle"]]
		mi.transform = o["pose"]
		racine.add_child(mi)
	var sortie: ArrayMesh = BM._tous_les_maillages(racine)
	racine.free()
	return sortie


## Le `.glb` lié (celui que le trancheur relit tuile par tuile). Rend "" ou la raison.
## ⚠ **DEUX DESTINATIONS, DEUX ÉCRITURES (1er octobre 2026)** :
##   • pour le MONDE (le `.glb` de la couche) : avec les normales du modeleur — UNE par face. Sans elles, la
##     relecture recalculait une normale par TRIANGLE, et une face sculptée (plus plane) s'éclairait dans le
##     monde autrement que dans le modeleur ;
##   • pour BLENDER (`pour_blender`) : sans normales (ombrage plat, comme le témoin calculé) et SOUDÉ — le
##     modeleur écrit une soupe de triangles, et une soupe ne se sculpte pas dans Blender.
func vers_glb(chemin: String, pour_blender := false) -> String:
	var maillages := {}
	for cle in tuiles:
		var m: ArrayMesh = tuiles[cle].vers_array_mesh(not pour_blender)
		maillages[cle] = _soudee(m) if pour_blender else m
	# ⚠ LES CARTES PBR AVANT D'ÉCRIRE, ET APRÈS LES MAILLAGES : le .glb embarque les textures telles qu'elles sont à cet
	# instant — une génération encore en route partirait neutre (pente nulle) dans le monde et dans les moteurs ; et
	# ce sont les maillages qui DEMANDENT les cartes (`materiau_godot`) : appelé avant eux, rien n'était à refaire
	# (vu rougir, `test_cartes_pbr`). Les textures se mettent à jour en place, les maillages les citent déjà.
	load("res://addons/marchingblocks_core/peinture.gd").suivre_les_cartes(true)
	return BM.ecrire_le_temoin_lie(chemin, maillages, affectation)


## Un maillage SOUDÉ : un sommet par (position, UV, couleur), surface par surface, matériau gardé.
static func _soudee(mesh: ArrayMesh) -> ArrayMesh:
	var sortie := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var a: Array = mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var uv = a[Mesh.ARRAY_TEX_UV]
		var col = a[Mesh.ARRAY_COLOR]
		var idx = a[Mesh.ARRAY_INDEX]
		var ordre: PackedInt32Array = (idx as PackedInt32Array) if idx != null else PackedInt32Array(range(v.size()))
		var connus := {}
		var nv := PackedVector3Array()
		var nuv := PackedVector2Array()
		var ncol := PackedColorArray()
		var nidx := PackedInt32Array()
		for i in ordre:
			var p: Vector3 = v[i]
			var cle := "%d|%d|%d" % [roundi(p.x * 100000.0), roundi(p.y * 100000.0), roundi(p.z * 100000.0)]
			if uv != null:
				cle += "|%d|%d" % [roundi(uv[i].x * 1000000.0), roundi(uv[i].y * 1000000.0)]
			if col != null:
				cle += "|" + (col[i] as Color).to_html()
			if not connus.has(cle):
				connus[cle] = nv.size()
				nv.append(p)
				if uv != null:
					nuv.append(uv[i])
				if col != null:
					ncol.append(col[i])
			nidx.append(connus[cle])
		var b := []
		b.resize(Mesh.ARRAY_MAX)
		b[Mesh.ARRAY_VERTEX] = nv
		b[Mesh.ARRAY_INDEX] = nidx
		if uv != null:
			b[Mesh.ARRAY_TEX_UV] = nuv
		if col != null:
			b[Mesh.ARRAY_COLOR] = ncol
		sortie.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b)
		sortie.surface_set_material(sortie.get_surface_count() - 1, mesh.surface_get_material(s))
	return sortie


func vers_dictionnaire() -> Dictionary:
	var t := {}
	for cle in tuiles:
		var d: Dictionary = tuiles[cle].vers_dictionnaire()
		d.erase("materiaux")
		t[cle] = d
	var mt: Array = []
	for m in materiaux:
		var e: Dictionary = m.duplicate()
		var c: Color = m.get("couleur", Color.WHITE)
		e["couleur"] = [c.r, c.g, c.b, c.a]
		mt.append(e)
	var aff: Array = []
	for s in affectation:
		var v: Vector3i = s
		aff.append_array([v.x, v.y, v.z, int(affectation[s])])
	return {"format": FORMAT, "version": VERSION, "materiaux": mt, "tuiles": t, "affectation": aff}


## null si ce n'est pas un témoin lié, ou s'il vient d'une version plus récente.
static func depuis_dictionnaire(d: Dictionary) -> RefCounted:
	if str(d.get("format", "")) != FORMAT or int(d.get("version", 0)) > VERSION:
		return null
	var t: RefCounted = load("res://addons/marchingblocks_core/temoin_lie.gd").new()
	for e in d.get("materiaux", []):
		var x: Dictionary = (e as Dictionary).duplicate()
		x["couleur"] = ME._couleur(e.get("couleur", [1, 1, 1, 1]))
		t.materiaux.append(x)
	var td: Dictionary = d.get("tuiles", {})
	for cle in td:
		var m: RefCounted = ME.depuis_dictionnaire(td[cle])
		if m == null:
			return null
		t.tuiles[cle] = m
	# Les variantes (4 octobre 2026) : un témoin d'avant n'en a pas ; une affectation malformée refuse le fichier.
	var aff = d.get("affectation", [])
	if not aff is Array or (aff as Array).size() % 4 != 0:
		return null
	for k in range(0, (aff as Array).size(), 4):
		t.affectation[Vector3i(int(aff[k]), int(aff[k + 1]), int(aff[k + 2]))] = int(aff[k + 3])
	t._partager()
	t._deduire_les_occurrences()
	return t
