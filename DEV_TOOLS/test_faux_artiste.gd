extends SceneTree
##
## TEST — le retour d'un travail d'artiste, éprouvé sur un FAUX (`faux_artiste.gd`).
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_faux_artiste.gd
##
## ⚠ **CE QUE LE TÉMOIN CALCULÉ NE POUVAIT PAS DIRE.** Toutes les mesures du retour — 0 remarque de
## couture, 17,7 s de tranchage — venaient du témoin lui-même, dont aucun triangle ne chevauche un plan
## de coupe et qui ne porte ni texture ni second objet. Ce faux porte du relief, un liseré d'herbe qui
## sort de sa case, deux objets et une texture ; et chaque garde a son CONTRÔLE NÉGATIF (un artiste
## maladroit, une texture indisciplinée) : un contrôle qui ne sait pas parler ne garde rien (charte §6).
##
## ⚠ **CE QU'IL NE REMPLACE PAS** : l'œil. Un faux équivariant est un artiste parfait ; un vrai ne l'est pas,
## et c'est sur son fichier que les remarques de couture compteront.

const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const Tranchage := preload("res://addons/marchingblocks_core/tranchage.gd")
const FormatNeutre := preload("res://addons/marchingblocks_core/format_neutre.gd")
const Faux := preload("res://DEV_TOOLS/faux_artiste.gd")

const DOSSIER := "user://faux_artiste"

var _ok := 0
var _echecs := 0
var _premier := ""


func _initialize() -> void:
	print("=== TEST — le retour d'un travail d'artiste (un faux) ===\n")
	DirAccess.make_dir_recursive_absolute(DOSSIER)
	# ⚠ UN SCRIPT QUI NE COMPILE PAS FAIT SAUTER SES SECTIONS EN SILENCE, et la suite finissait « OK »
	# (vu ici, 29 septembre 2026, comme dans `test_greffon_peinture`). Chaque script doit se CHARGER.
	for script in [BM, MB, Tranchage, FormatNeutre, Faux]:
		_dire((script as GDScript).can_instantiate(), "%s ne se charge pas" % (script as GDScript).resource_path)
	if _echecs > 0:
		print("VERDICT : ÉCHEC")
		quit(1)
		return
	var lot: MeshLibrary = _le_faux_revient_entier()
	if lot != null:
		_la_texture_suit_dans_les_tuiles(lot)
		_la_texture_indisciplinee_se_voit(lot)
		_la_texture_voyage_dans_le_format(lot)
	_l_artiste_maladroit_se_voit()
	_un_second_objet_n_est_pas_perdu()
	_un_depassement_qui_franchit_la_coupe_se_voit()
	_l_obj_rend_ses_uv_a_l_endroit()
	_le_controle_de_texture_replie_les_points()

	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	if _echecs > 0:
		print("PREMIER ÉCHEC — %s" % _premier)
	print("VERDICT : %s" % ("ÉCHEC" if _echecs > 0 else "OK"))
	quit(1 if _echecs > 0 else 0)


func _dire(condition: bool, quoi: String) -> void:
	if condition:
		_ok += 1
	else:
		_echecs += 1
		if _premier == "":
			_premier = quoi
		print("  ÉCHEC — %s" % quoi)


func _remarques_de(bilan: Dictionary, prefixe: String) -> Array:
	return (bilan.get("remarques", []) as Array).filter(
		func(r: String) -> bool: return r.begins_with(prefixe))


## 1. Le faux se fabrique, exerce ce qu'il prétend, et revient ENTIER par le vrai trancheur.
func _le_faux_revient_entier() -> MeshLibrary:
	print("1. le faux revient entier")
	var chemin := ProjectSettings.globalize_path(DOSSIER + "/travail.glb")
	var m: Dictionary = Faux.fabriquer(chemin)
	_dire(m["erreur"] == "", "le faux ne s'écrit pas : %s" % m["erreur"])
	if m["erreur"] != "":
		return null
	# ⚠ LE FAUX DOIT EXERCER CE QU'IL NOMME, sinon ce test garderait le témoin sous un autre nom.
	_dire(int(m["a_cheval"]) > 150, "seulement %d triangle(s) à cheval sur une coupe" % m["a_cheval"])
	_dire(int(m["frange"]) > 100, "seulement %d triangle(s) de liseré" % m["frange"])
	_dire(int(m["frange_hors_case"]) > 50,
		"seulement %d triangle(s) de liseré sortent de leur case" % m["frange_hors_case"])
	print("   %d triangles, %d à cheval sur une coupe ; liseré : %d triangles, %d hors de leur case ; "
		% [m["triangles"], m["a_cheval"], m["frange"], m["frange_hors_case"]]
		+ "plus grand déplacement %.3f case" % m["plus_grand_deplacement"])

	var journal: Array = []
	var travail: ArrayMesh = BM.travail_depuis_glb(chemin, journal)
	_dire(travail != null, "le faux ne se relit pas : %s" % str(journal))
	if travail == null:
		return null
	_dire(BM.ecart_au_temoin(travail) > 10000,
		"le faux ne s'écarte du témoin que de %d position(s)" % BM.ecart_au_temoin(travail))

	var debut := Time.get_ticks_msec()
	var bilan: Dictionary = BM.librairie_depuis_glb(chemin)
	var duree := (Time.get_ticks_msec() - debut) / 1000.0
	var lot: MeshLibrary = bilan["lot"]
	_dire((bilan["erreurs"] as Array).is_empty(),
		"le faux se tranche avec %d erreur(s) : %s" % [(bilan["erreurs"] as Array).size(),
		str((bilan["erreurs"] as Array).slice(0, 3))])
	_dire((bilan["manquantes"] as Array).is_empty(), "le faux ne livre pas : %s" % str(bilan["manquantes"]))
	_dire(lot.get_item_list().size() == 52,
		"le faux livre %d items, une tuile par clé du monde en fait 52" % lot.get_item_list().size())
	# ⚠ UNE TUILE PAR CLÉ (charte §3) : le faux est d'un seul tenant, donc NON LIÉ — chaque tuile y apparaît à
	# plusieurs endroits, et seule la copie la plus lisible est lue. Ce qui est perdu doit se DIRE.
	_dire(not _remarques_de(bilan, "non lié").is_empty(),
		"un travail d'un seul tenant ne dit pas qu'une seule copie de chaque tuile est lue : %s" % str(bilan["remarques"]))
	var couture: Array = _remarques_de(bilan, "")
	couture = couture.filter(func(r: String) -> bool: return r.begins_with("couture"))
	_dire(couture.is_empty(), "un artiste DISCIPLINÉ reçoit %d remarque(s) de couture : %s"
		% [couture.size(), str(couture.slice(0, 2))])
	_dire(_remarques_de(bilan, "texture").is_empty(),
		"une texture DISCIPLINÉE reçoit une remarque : %s" % str(_remarques_de(bilan, "texture")))

	# ⚠ LE LISERÉ EST ARRIVÉ : il est le seul à porter des faces qui regardent vers le BAS sous un sol à
	# ciel ouvert, donc on compare l'aire tournée vers le bas avec celle d'un tranchage sans lui.
	var bas: float = _aire_vers_le_bas(lot)
	_dire(bas > 0.0, "aucune face tournée vers le bas dans le lot")
	print("   tranché en %.1f s : %d items, %d remarque(s), aire vers le bas %.2f"
		% [duree, lot.get_item_list().size(), (bilan["remarques"] as Array).size(), bas])
	return lot


func _aire_vers_le_bas(lot: MeshLibrary) -> float:
	var aire := 0.0
	for id in lot.get_item_list():
		var mesh: Mesh = lot.get_item_mesh(id)
		for s in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx = arrays[Mesh.ARRAY_INDEX]
			var ordre: PackedInt32Array = (idx as PackedInt32Array) if idx != null \
				else PackedInt32Array(range(v.size()))
			for t in range(0, ordre.size() - 2, 3):
				var n: Vector3 = -(v[ordre[t + 1]] - v[ordre[t]]).cross(v[ordre[t + 2]] - v[ordre[t]])
				if n.normalized().y < -0.9:
					aire += n.length() * 0.5
	return aire


## 2. Chaque tuile porte la texture de l'artiste et ses UV.
func _la_texture_suit_dans_les_tuiles(lot: MeshLibrary) -> void:
	print("2. la texture suit dans les tuiles")
	var sans := 0
	for id in lot.get_item_list():
		var mesh: Mesh = lot.get_item_mesh(id)
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s) as StandardMaterial3D
			var image: Image = m.albedo_texture.get_image() if m != null and m.albedo_texture != null else null
			if image == null or image.is_empty() or mesh.surface_get_arrays(s)[Mesh.ARRAY_TEX_UV] == null:
				sans += 1
	_dire(sans == 0, "%d surface(s) de tuile sans texture lisible ou sans UV" % sans)


## 3. La MÊME géométrie, peinte sans la discipline : le contrôle de texture DOIT parler.
## ⚠ On ne retranche pas : les UV sont les mêmes, seule l'image change.
func _la_texture_indisciplinee_se_voit(lot: MeshLibrary) -> void:
	print("3. une texture indisciplinée se voit")
	var brut: ArrayMesh = BM.maillage_moitie(0)
	var tous := PackedVector3Array()
	for s in brut.get_surface_count():
		tous.append_array(brut.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	tous.append_array(Faux.triangles_de_la_frange())
	var uv_de: Callable = BM._uv_du_temoin(0)
	var uv := PackedVector2Array()
	for t in range(0, tous.size() - 2, 3):
		uv.append_array(uv_de.call(tous[t], tous[t + 1], tous[t + 2]))
	var matiere := StandardMaterial3D.new()
	matiere.albedo_texture = ImageTexture.create_from_image(Faux.texture(tous, uv, false))
	var pieces := {}
	for id in lot.get_item_list():
		var mesh: ArrayMesh = (lot.get_item_mesh(id) as ArrayMesh).duplicate()
		for s in mesh.get_surface_count():
			mesh.surface_set_material(s, matiere)
		pieces[lot.get_item_name(id)] = mesh
	var remarques: Array = []
	Tranchage.verifier_couture_texture(pieces, remarques)
	_dire(remarques.size() == 1 and str(remarques[0]).begins_with("texture"),
		"une texture qui ignore les coupes ne reçoit pas de remarque de texture")
	if not remarques.is_empty():
		print("   %s" % str(remarques[0]).substr(0, 110))


## 4. Le format neutre emporte la texture : images, matériaux texturés, UV sur chaque primitive.
## ⚠ Lu dans le JSON du fichier, sans le lecteur du module (charte §6).
func _la_texture_voyage_dans_le_format(lot: MeshLibrary) -> void:
	print("4. la texture voyage dans le format neutre")
	var r: Dictionary = FormatNeutre.exporter(lot, ProjectSettings.globalize_path(DOSSIER), "faux", "test")
	_dire(not r.has("erreur"), "l'export neutre échoue : %s" % r.get("erreur", ""))
	if r.has("erreur"):
		return
	var octets := FileAccess.get_file_as_bytes(str(r["dossier"]).path_join("tiles.glb"))
	_dire(octets.size() > 20, "tiles.glb est vide")
	if octets.size() <= 20:
		return
	var longueur: int = octets.decode_u32(12)
	var json = JSON.parse_string(octets.slice(20, 20 + longueur).get_string_from_utf8())
	var images: int = (json.get("images", []) as Array).size()
	var textures := 0
	for m in json.get("materials", []):
		if (m as Dictionary).get("pbrMetallicRoughness", {}).has("baseColorTexture"):
			textures += 1
	var sans_uv := 0
	var primitives := 0
	for maillage in json.get("meshes", []):
		# ⚠ Le repère témoin (`mb_frame`) n'est pas une tuile : un tétraèdre de mesure, sans UV.
		if str((maillage as Dictionary).get("name", "")) == "mb_frame":
			continue
		for p in maillage["primitives"]:
			primitives += 1
			if not (p["attributes"] as Dictionary).has("TEXCOORD_0"):
				sans_uv += 1
	_dire(images >= 1, "tiles.glb ne porte aucune image")
	_dire(textures >= 1, "aucun matériau de tiles.glb ne lit une texture de couleur")
	_dire(primitives > 0 and sans_uv == 0, "%d primitive(s) sur %d sans TEXCOORD_0" % [sans_uv, primitives])
	print("   tiles.glb : %d image(s), %d matériau(x) texturé(s), %d primitive(s), %d sans UV"
		% [images, textures, primitives, sans_uv])


## 5. Un artiste qui n'a pas lu la règle : la couture DOIT le dire (contrôle négatif de la section 1).
func _l_artiste_maladroit_se_voit() -> void:
	print("5. un relief maladroit se voit")
	var chemin := ProjectSettings.globalize_path(DOSSIER + "/maladroit.glb")
	var m: Dictionary = Faux.fabriquer(chemin, true, true)
	_dire(m["erreur"] == "", "le faux maladroit ne s'écrit pas")
	var bilan: Dictionary = BM.librairie_depuis_glb(chemin)
	var couture: Array = (bilan["remarques"] as Array).filter(
		func(r: String) -> bool: return r.begins_with("couture"))
	_dire(not couture.is_empty(), "un relief qui ignore le contrat ne reçoit AUCUNE remarque de couture")
	print("   %d remarque(s) de couture" % couture.size())


## 7. Le même travail, la frange rangée dans un SECOND objet placé avant le terrain : rien ne se perd.
## ⚠ Le lecteur ne prenait que le PREMIER maillage : la frange seule, le terrain ignoré sans un mot.
func _un_second_objet_n_est_pas_perdu() -> void:
	print("7. un second objet n'est pas perdu")
	var chemin := ProjectSettings.globalize_path(DOSSIER + "/separe.glb")
	var m: Dictionary = Faux.fabriquer(chemin, true, false, true)
	_dire(m["erreur"] == "", "le faux en deux objets ne s'écrit pas")
	var journal: Array = []
	var travail: ArrayMesh = BM.travail_depuis_glb(chemin, journal)
	var triangles := 0
	if travail != null:
		for s in travail.get_surface_count():
			var a: Array = travail.surface_get_arrays(s)
			triangles += ((a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() if a[Mesh.ARRAY_INDEX] != null
				else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	# La boîte tolérante rogne un peu de frange au bord du bloc : on exige presque tout, pas tout.
	_dire(triangles >= int(m["triangles"]) * 0.97,
		"relu en deux objets : %d triangles sur %d écrits" % [triangles, m["triangles"]])
	var bilan: Dictionary = BM.librairie_depuis_glb(chemin)
	_dire((bilan["remarques"] as Array).any(func(r: String) -> bool: return r.begins_with("objets")),
		"deux objets relus sans que le bilan le DISE")
	print("   %d triangles écrits, %d relus" % [m["triangles"], triangles])


## 8. Un dépassement qui franchit le plan de coupe suivant, vers une région dont le germe est VIDE : la
## couture DOIT le dire. C'est la version d'abord écrite du liseré (0,8 case), gardée comme contrôle.
func _un_depassement_qui_franchit_la_coupe_se_voit() -> void:
	print("8. un dépassement qui franchit la coupe se voit")
	var chemin := ProjectSettings.globalize_path(DOSSIER + "/trop_large.glb")
	var m: Dictionary = Faux.fabriquer(chemin, true, false, false, 0.8)
	_dire(m["erreur"] == "", "le faux trop large ne s'écrit pas")
	var bilan: Dictionary = BM.librairie_depuis_glb(chemin)
	var couture: Array = (bilan["remarques"] as Array).filter(
		func(r: String) -> bool: return r.begins_with("couture"))
	_dire(not couture.is_empty(), "un liseré qui entre dans une tuile vide ne reçoit AUCUNE remarque")
	print("   %d remarque(s) de couture" % couture.size())


## 6. L'OBJ du témoin rend ses UV à l'endroit : `v` compté depuis le bas dans le fichier, depuis le haut
## dans Godot. ⚠ Relu par le lecteur, comparé à ce que la règle donne au même triangle.
func _l_obj_rend_ses_uv_a_l_endroit() -> void:
	print("6. l'OBJ rend ses UV à l'endroit")
	var chemin := ProjectSettings.globalize_path(DOSSIER + "/temoin.obj")
	_dire(BM.exporter_le_bloc(chemin) == "", "l'export OBJ échoue")
	var relu: ArrayMesh = BM._lire_obj(chemin)
	var uv_de: Callable = BM._uv_du_temoin(0)
	var faux := 0
	var vus := 0
	for s in relu.get_surface_count():
		var arrays: Array = relu.surface_get_arrays(s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for t in range(0, v.size() - 2, 3):
			var attendu: PackedVector2Array = uv_de.call(v[t], v[t + 1], v[t + 2])
			vus += 1
			for k in 3:
				if not attendu[k].is_equal_approx(uv[t + k]) and attendu[k].distance_to(uv[t + k]) > 0.00001:
					faux += 1
					break
	_dire(vus > 0 and faux == 0, "%d triangle(s) sur %d reviennent avec d'autres UV" % [faux, vus])
	DirAccess.remove_absolute(chemin)
	DirAccess.remove_absolute(chemin.get_basename() + ".mtl")


## 9. Le contrôle de texture compare les points que la POSE rapproche : la face x+ d'une tuile et la face
## x− d'une autre, à des |z| égaux mais de signes opposés, se rencontrent quand l'une a tourné d'un demi-
## tour. ⚠ Construit à la main : sans ce cas, retirer le repli ne ferait rougir personne — la texture
## disciplinée est uniforme aux coupes, et l'indisciplinée diffère partout.
func _le_controle_de_texture_replie_les_points() -> void:
	print("9. le contrôle de texture replie les points")
	var image := Image.create(2, 1, false, Image.FORMAT_RGB8)
	image.set_pixel(0, 0, Color.RED)
	image.set_pixel(1, 0, Color.BLUE)
	var texture := ImageTexture.create_from_image(image)
	var tuile := func(signe: float, texel: float) -> ArrayMesh:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0.5 * signe, 0.0, 0.2 * signe),
			Vector3(0.5 * signe, 0.0, 0.4 * signe), Vector3(0.3 * signe, 0.1, 0.3 * signe)])
		var u := Vector2((texel + 0.5) / 2.0, 0.5)
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([u, u, u])
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var m := StandardMaterial3D.new()
		m.albedo_texture = texture
		mesh.surface_set_material(0, m)
		return mesh
	var differentes: Array = []
	Tranchage.verifier_couture_texture({"a": tuile.call(1.0, 0.0), "b": tuile.call(-1.0, 1.0)}, differentes)
	_dire(differentes.size() == 1, "deux tuiles qui se rencontrent en miroir, rouge contre bleu : aucune remarque")
	var pareilles: Array = []
	Tranchage.verifier_couture_texture({"a": tuile.call(1.0, 0.0), "b": tuile.call(-1.0, 0.0)}, pareilles)
	_dire(pareilles.is_empty(), "les mêmes, de même couleur, reçoivent une remarque : %s" % str(pareilles))
