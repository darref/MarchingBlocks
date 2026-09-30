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
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")

const FORMAT := "marchingblocks-linked-witness"
const VERSION := 1

var tuiles := {}          # clé → MaillageEdite
var materiaux: Array = []
var occurrences: Array = []   # [{sommet, cle, orientation, pose: Transform3D}]


## Le témoin calculé, en tuiles liées (~2 s : `BlocsMaitres.tuiles_du_temoin` ne découpe que 52 sommets).
static func depuis_le_temoin_calcule() -> RefCounted:
	var t: RefCounted = load("res://addons/marchingblocks_core/temoin_lie.gd").new()
	var calc: Dictionary = BM.tuiles_du_temoin()
	for cle in calc:
		t.tuiles[cle] = ME.depuis(calc[cle]["mesh"])
	t._partager()
	t._deduire_les_occurrences()
	return t


func _deduire_les_occurrences() -> void:
	var grille := GridMap.new()
	occurrences = []
	for o in BM.occurrences_du_temoin(0):
		if not tuiles.has(o["cle"]):
			continue
		var e: Dictionary = o.duplicate()
		e["pose"] = Transform3D(grille.get_basis_with_orthogonal_index(o["orientation"]),
			Vector3(o["sommet"]) + Vector3.ONE)
		occurrences.append(e)
	grille.free()


## Toutes les tuiles pointent le MÊME tableau de matériaux.
func _partager() -> void:
	for cle in tuiles:
		tuiles[cle].materiaux = materiaux


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
	t.occurrences = occurrences
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


## LE TÉMOIN ASSEMBLÉ, pour le montrer ou le ranger dans la liste des travaux : chaque occurrence posée.
## Une surface par matériau (Godot plafonne un maillage à 256 surfaces).
func assemble() -> ArrayMesh:
	var par_cle := {}
	for cle in tuiles:
		par_cle[cle] = tuiles[cle].vers_array_mesh(false)
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
func vers_glb(chemin: String) -> String:
	var maillages := {}
	for cle in tuiles:
		maillages[cle] = tuiles[cle].vers_array_mesh(false)
	return BM.ecrire_le_temoin_lie(chemin, maillages)


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
	return {"format": FORMAT, "version": VERSION, "materiaux": mt, "tuiles": t}


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
	t._partager()
	t._deduire_les_occurrences()
	return t
