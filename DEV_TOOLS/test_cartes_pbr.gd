extends SceneTree
## TEST — les cartes PBR déduites de l'albedo, et l'albedo cuit depuis le relief (Jordan, 2 octobre 2026).
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_cartes_pbr.gd
##
## ⚠ LES ATTENDUS VIENNENT D'AILLEURS (charte §6) : une pente écrite à la main et sa normale calculée ici ; le SENS de
## la normale comparé à celui du moteur (`Image.bump_map_to_normal_map`, une autre autorité) ; l'invariance par
## translation d'une image qui se répète ; la couleur d'un point de tuile recalculée depuis la géométrie lue ici
## (normale de face, distance aux arêtes, plans de coupe), jamais par `albedo_du_relief`.

const Cartes := preload("res://addons/marchingblocks_core/cartes_pbr.gd")
const Peinture := preload("res://addons/marchingblocks_core/peinture.gd")
const ME := preload("res://addons/marchingblocks_core/maillage_edite.gd")
const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const FN := preload("res://addons/marchingblocks_core/format_neutre.gd")
const Tileset := preload("res://addons/marchingblocks_paint/mb_tileset.gd")

var _ok := 0
var _echecs := 0
var _premier := ""
var _dossier := ""
var _emission_au_bout := false


func _initialize() -> void:
	print("=== TEST — les cartes PBR déduites ===\n")
	_dossier = ProjectSettings.globalize_path("user://test_cartes_pbr")
	DirAccess.make_dir_recursive_absolute(_dossier)
	for f in DirAccess.get_files_at(_dossier):
		DirAccess.remove_absolute(_dossier.path_join(f))
	Peinture.oublier()
	_une_image_unie_est_plate()
	_la_pente_et_son_sens()
	_ce_qui_se_repete_reste_raccord()
	_hauteur_occlusion_rugosite()
	_la_dilatation_et_le_masque()
	_les_cartes_suivent_la_toile()
	_le_materiau_et_les_tangentes()
	_les_cartes_partent_dans_le_glb()
	_le_retour_de_blender()
	_le_trajet_jusqu_au_greffon()
	_l_albedo_du_relief()
	_les_ensembles()
	_l_emission()
	# SENTINELLE : une erreur d'exécution abandonne la fonction en silence.
	_dire(_emission_au_bout, "la section de l'émission est allée au bout")
	Peinture.oublier()
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
		if _echecs <= 12:
			print("  ÉCHEC — %s" % quoi)


func _unie(n: int, c: Color) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return img


func _octet(img: Image, x: int, y: int, canal: int) -> int:
	return img.get_data()[(y * img.get_width() + x) * (3 if img.get_format() == Image.FORMAT_RGB8 else 4) + canal]


## 1. Une image UNIE n'a pas de relief : normale (128, 128, 255), occlusion pleine, rugosité de base, métal blanc.
func _une_image_unie_est_plate() -> void:
	var r: Dictionary = Cartes.generer(_unie(64, Color(0.4, 0.3, 0.2)), {"rugosite": 0.6})
	var n: Image = r["normale"]
	var o: Image = r["orm"]
	var ecart := 0
	for y in range(0, 64, 7):
		for x in range(0, 64, 7):
			ecart = maxi(ecart, absi(_octet(n, x, y, 0) - 127) + absi(_octet(n, x, y, 1) - 127)
				+ absi(_octet(n, x, y, 2) - 255))
			ecart = maxi(ecart, absi(_octet(o, x, y, 0) - 255) + absi(_octet(o, x, y, 1) - 153) + absi(_octet(o, x, y, 2) - 255))
	_dire(ecart <= 2, "une image unie : normale plate, occlusion pleine, rugosité 0,6 = 153, métal 255 (écart %d)" % ecart)


## 2. LA PENTE : h = 0,25 + 0,5·x/(w−1). Sobel / 8 sur une rampe linéaire rend exactement sa pente par pixel ;
## n = normalize(−pente·force, 0, 1), écrit ici. Puis LE SENS, comparé à celui du moteur.
func _la_pente_et_son_sens() -> void:
	var w := 32
	var haut := PackedFloat32Array()
	haut.resize(w * w)
	for y in w:
		for x in w:
			haut[y * w + x] = 0.25 + 0.5 * x / float(w - 1)
	var force := 4.0
	var r: Dictionary = Cartes.depuis_la_hauteur(haut, w, w, {"normale": force}, false)
	var n: Image = r["normale"]
	var pente := 0.5 / float(w - 1)
	var v := Vector3(-pente * force, 0.0, 1.0).normalized()
	var attendu := [int(clampf(127.5 + v.x * 127.5, 0, 255)), 127, int(clampf(127.5 + v.z * 127.5, 0, 255))]
	var lu := [_octet(n, 15, 15, 0), _octet(n, 15, 15, 1), _octet(n, 15, 15, 2)]
	_dire(absi(lu[0] - attendu[0]) <= 1 and absi(lu[1] - attendu[1]) <= 1 and absi(lu[2] - attendu[2]) <= 1,
		"la normale d'une rampe vers +x : %s, attendu %s (calculé ici)" % [str(lu), str(attendu)])
	# Le même champ, versé vers le BAS de l'image.
	for y in w:
		for x in w:
			haut[y * w + x] = 0.25 + 0.5 * y / float(w - 1)
	var rb: Dictionary = Cartes.depuis_la_hauteur(haut, w, w, {"normale": force}, false)
	var g_notre := _octet(rb["normale"], 15, 15, 1)
	var r_notre := _octet(r["normale"], 15, 15, 0)
	# L'AUTRE AUTORITÉ : le moteur (« OpenGL », la convention du glTF) sur les deux mêmes rampes.
	var moteur_x := _rampe_image(w, true)
	moteur_x.bump_map_to_normal_map(force * w)
	var moteur_y := _rampe_image(w, false)
	moteur_y.bump_map_to_normal_map(force * w)
	var r_moteur := moteur_x.get_pixel(15, 15).r8
	var g_moteur := moteur_y.get_pixel(15, 15).g8
	_dire(signi(r_notre - 128) == signi(r_moteur - 128) and r_notre != 127,
		"le sens en X est celui du moteur (nous %d, moteur %d)" % [r_notre, r_moteur])
	_dire(signi(g_notre - 128) == signi(g_moteur - 128) and g_notre != 127,
		"le sens en Y est celui du moteur, +Y vers le haut de l'image (nous %d, moteur %d)" % [g_notre, g_moteur])


func _rampe_image(w: int, en_x: bool) -> Image:
	var img := Image.create(w, w, false, Image.FORMAT_RF)
	for y in w:
		for x in w:
			var t := (x if en_x else y) / float(w - 1)
			img.set_pixel(x, y, Color(0.25 + 0.5 * t, 0, 0))
	return img


## 3. CE QUI SE RÉPÈTE RESTE RACCORD : l'image décalée d'une demi-largeur rend les cartes décalées d'autant — vrai
## seulement si les bords se lisent en boucle. Et le contrôle : sans la boucle, ce n'est plus vrai au bord.
## ⚠ Le décalage est de 64 texels, le pas de la pyramide (÷64) : un décalage qui n'en est pas un multiple bouge la
## grille des moyennes sous l'image, et rend des écarts de 3 ou 4 sur 255 qui ne disent rien du bouclage (mesuré).
func _ce_qui_se_repete_reste_raccord() -> void:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for y in n:
		for x in n:
			var v := 0.5 + 0.25 * sin(TAU * x / n * 2.0) * cos(TAU * y / n) + rng.randf_range(-0.1, 0.1)
			img.set_pixel(x, y, Color(v, v, v))
	var roule := _rouler(img, n / 2)
	var a: Dictionary = Cartes.generer(img, null, true)
	var b: Dictionary = Cartes.generer(roule, null, true)
	var ecart := _ecart_max(_rouler(a["normale"], n / 2), b["normale"])
	var ecart_orm := _ecart_max(_rouler(a["orm"], n / 2), b["orm"])
	_dire(ecart <= 1 and ecart_orm <= 1, "en boucle, décaler l'image décale les cartes (écart normale %d, ORM %d)" % [ecart, ecart_orm])
	var c: Dictionary = Cartes.generer(img, null, false)
	var d: Dictionary = Cartes.generer(roule, null, false)
	var ecart_sans := _ecart_max(_rouler(c["normale"], n / 2), d["normale"])
	_dire(ecart_sans > 10, "contrôle : sans la boucle, le bord casse le raccord (écart %d)" % ecart_sans)
	# Le bord d'une carte en boucle se raccorde au bord opposé : colonne 0 et colonne n−1 voisines.
	var saut_bord := 0
	var saut_dedans := 0
	for y in n:
		saut_bord = maxi(saut_bord, absi(_octet(a["normale"], 0, y, 0) - _octet(a["normale"], n - 1, y, 0)))
		for x in n - 1:
			saut_dedans = maxi(saut_dedans, absi(_octet(a["normale"], x, y, 0) - _octet(a["normale"], x + 1, y, 0)))
	_dire(saut_bord <= saut_dedans, "le bord se raccorde comme l'intérieur (saut au bord %d, dedans %d)" % [saut_bord, saut_dedans])


func _rouler(img: Image, dx: int) -> Image:
	var w := img.get_width()
	var sortie := Image.create(w, img.get_height(), false, img.get_format())
	sortie.blit_rect(img, Rect2i(0, 0, w - dx, img.get_height()), Vector2i(dx, 0))
	sortie.blit_rect(img, Rect2i(w - dx, 0, dx, img.get_height()), Vector2i(0, 0))
	return sortie


func _ecart_max(a: Image, b: Image) -> int:
	var da := a.get_data()
	var db := b.get_data()
	var m := 0
	for i in da.size():
		m = maxi(m, absi(da[i] - db[i]))
	return m


## 4. La HAUTEUR suit la clarté (et l'inverse sur demande) ; l'OCCLUSION noircit un creux ; la RUGOSITÉ y monte.
func _hauteur_occlusion_rugosite() -> void:
	var n := 64
	var img := _unie(n, Color(0.3, 0.3, 0.3))
	for y in n:
		for x in n:
			if Vector2(x - 20, y - 32).length() < 6:
				img.set_pixel(x, y, Color(0.9, 0.9, 0.9))   # une bosse claire
			if Vector2(x - 44, y - 32).length() < 6:
				img.set_pixel(x, y, Color(0.02, 0.02, 0.02))   # un creux sombre
	var r: Dictionary = Cartes.generer(img, {"variation": 0.5})
	var h: Image = r["hauteur"]
	var o: Image = r["orm"]
	var bosse := h.get_pixel(20, 32).r8
	var creux := h.get_pixel(44, 32).r8
	var plat := h.get_pixel(32, 5).r8
	_dire(bosse > plat + 20 and creux < plat - 20, "le clair est haut, le sombre est bas (bosse %d, plat %d, creux %d)" % [bosse, plat, creux])
	var ri: Dictionary = Cartes.generer(img, {"variation": 0.5, "inverser": true})
	var hi: Image = ri["hauteur"]
	var somme := hi.get_pixel(20, 32).r8 + bosse
	_dire(absi(somme - 255) <= 2, "« Dark is high » renverse la hauteur autour du milieu (%d + %d)" % [hi.get_pixel(20, 32).r8, bosse])
	_dire(_octet(o, 44, 32, 0) < _octet(o, 32, 5, 0) - 20, "l'occlusion noircit le creux (%d contre %d au plat)" % [_octet(o, 44, 32, 0), _octet(o, 32, 5, 0)])
	_dire(_octet(o, 44, 32, 1) > _octet(o, 20, 32, 1) + 20, "le creux est plus rugueux que la bosse (%d contre %d)" % [_octet(o, 44, 32, 1), _octet(o, 20, 32, 1)])
	var metal := true
	for i in range(2, o.get_data().size(), 3):
		if o.get_data()[i] != 255:
			metal = false
			break
	_dire(metal, "le métal n'est jamais deviné : le canal bleu est blanc partout")


## 5. LA DILATATION : dans le masque l'image est intacte au bit près ; hors du masque, un texel prend la couleur de
## l'îlot le plus proche. Le MASQUE d'un triangle couvre son aire, et pas plus loin qu'un texel.
func _la_dilatation_et_le_masque() -> void:
	var n := 64
	var img := _unie(n, Color.BLACK)
	var m := Image.create(n, n, false, Image.FORMAT_L8)
	img.fill_rect(Rect2i(4, 20, 10, 10), Color.RED)
	m.fill_rect(Rect2i(4, 20, 10, 10), Color.WHITE)
	img.fill_rect(Rect2i(50, 20, 10, 10), Color.BLUE)
	m.fill_rect(Rect2i(50, 20, 10, 10), Color.WHITE)
	var d: Image = Cartes.dilater(img, m)
	var intact := true
	for y in range(20, 30):
		for x in range(4, 14):
			if d.get_pixel(x, y) != img.get_pixel(x, y):
				intact = false
	_dire(intact, "dans l'îlot, l'image est intacte")
	var pres_rouge := d.get_pixel(17, 25)
	var pres_bleu := d.get_pixel(46, 25)
	_dire(pres_rouge.r > 0.6 and pres_rouge.b < 0.4 and pres_bleu.b > 0.6 and pres_bleu.r < 0.4,
		"hors des îlots, la couleur du plus proche (près du rouge %s, près du bleu %s)" % [str(pres_rouge), str(pres_bleu)])
	_dire(d.get_pixel(32, 60).a > 0.99, "un texel loin de tout est rempli quand même")
	var tri := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.5, 0.0), Vector2(0.0, 0.5)])
	var mk: Image = Cartes.masque_des_triangles(tri, Vector2i(n, n))
	var compte := 0
	for y in n:
		for x in n:
			if mk.get_pixel(x, y).r > 0.5:
				compte += 1
	# L'aire : 32 × 32 / 2 = 512 texels ; élargie d'un texel le long d'un périmètre de ~109 texels.
	_dire(compte >= 512 and compte <= 512 + 109 + 40, "le masque d'un triangle de 512 texels en couvre %d (son aire, élargie d'un texel)" % compte)
	_dire(mk.get_pixel(5, 5).r > 0.5 and mk.get_pixel(40, 40).r < 0.5, "il couvre son dedans, pas le loin")
	# L'élargissement d'un texel : le centre (16,5 ; 16,5) est hors du triangle (x + y = 33 > 32) mais à 0,71 texel de
	# l'hypoténuse — couvert ; (17,5 ; 17,5) est à 2,1 texels — pas couvert.
	_dire(mk.get_pixel(16, 16).r > 0.5 and mk.get_pixel(17, 17).r < 0.5,
		"le masque déborde d'un texel au plus : le filtrage au bord d'un îlot lit encore l'îlot")


## 6. LES CARTES SUIVENT LA TOILE : peindre les rend périmées, la génération les pose dans les MÊMES textures ; elles
## s'écrivent, se relisent sans calcul quand la signature tient, et sont refaites quand l'image a changé ailleurs.
func _les_cartes_suivent_la_toile() -> void:
	Peinture.oublier()
	var chemin := _dossier.path_join("toile.png")
	Peinture.nouvelle_toile(chemin, Color(0.5, 0.5, 0.5), 64)
	var e: Dictionary = Peinture.cartes_de(chemin, null, true)
	var tex_n: ImageTexture = e["normale"]
	_dire(Peinture.cartes_en_retard() == 1, "une toile neuve attend ses cartes")
	Peinture.suivre_les_cartes(true)
	_dire(Peinture.cartes_en_retard() == 0, "la génération les pose")
	var plat_avant := (e["images"]["normale"] as Image).get_pixel(32, 32)
	var calque: Image = Peinture.calque_actif(chemin)
	Peinture.tamponner(calque, Vector2(32, 32), 8.0, Color.WHITE, 1.0, 1.0)
	Peinture.composer(chemin)
	_dire(Peinture.cartes_en_retard() == 1, "peindre les rend périmées")
	Peinture.suivre_les_cartes()
	_dire(Peinture.cartes_en_retard() == 1 and int(Peinture._cartes.values()[0]["tache"]) < 0,
		"pas pendant le geste : la main ne s'est pas posée, aucune génération lancée")
	Peinture.suivre_les_cartes(true)
	var e2: Dictionary = Peinture.cartes_de(chemin, null, true)
	_dire(is_same(e2["normale"], tex_n), "la MÊME texture (le matériau la cite une fois)")
	var bord := (e2["images"]["normale"] as Image).get_pixel(40, 32)
	_dire(bord.r > plat_avant.r + 0.05, "le flanc droit d'une bosse peinte penche vers +x (%.2f contre %.2f)" % [bord.r, plat_avant.r])
	Peinture.cartes_de(chemin, {"normale": 8.0}, true)
	_dire(Peinture.cartes_en_retard() == 1, "changer un réglage les rend périmées")
	Peinture.suivre_les_cartes(true)
	var fort := (e2["images"]["normale"] as Image).get_pixel(40, 32)
	_dire(fort.r > bord.r + 0.02, "plus de force, plus de pente (%.2f contre %.2f)" % [fort.r, bord.r])
	# UNE GÉNÉRATION DÉPASSÉE : lancée sur un autre fil avec un réglage, qui change avant qu'elle ne finisse. Elle se
	# montre, mais ne vaut pas « à jour » : la suivante part, et ce qui reste posé répond au DERNIER réglage —
	# attendu par une génération directe, faite ici avec lui.
	Peinture.cartes_de(chemin, {"normale": 3.0}, true)
	OS.delay_msec(Peinture.CALME_MS + 60)
	Peinture.suivre_les_cartes()
	var lancee: bool = int(Peinture._cartes.values()[0]["tache"]) >= 0
	Peinture.cartes_de(chemin, {"normale": 12.0}, true)
	Peinture.suivre_les_cartes(true)
	var directe: Dictionary = Cartes.generer(Peinture.toile(chemin)["image"], {"normale": 12.0}, true)
	_dire(lancee and _ecart_max(e2["images"]["normale"], directe["normale"]) == 0,
		"une génération dépassée ne vaut pas « à jour » : ce qui reste répond au dernier réglage (lancée %s)" % str(lancee))
	Peinture.cartes_de(chemin, {"normale": 8.0}, true)
	Peinture.suivre_les_cartes(true)
	# L'écriture et la relecture.
	Peinture.enregistrer()
	var ecrites: Array = Peinture.enregistrer_les_cartes()
	var dossier := Peinture.dossier_des_cartes(chemin)
	_dire(ecrites.size() == 1 and FileAccess.file_exists(dossier.path_join("normal.png"))
		and FileAccess.file_exists(dossier.path_join("orm.png")) and FileAccess.file_exists(dossier.path_join("height.png")),
		"les cartes s'écrivent à côté de l'image (%s)" % str(ecrites))
	var ecrite := (e2["images"]["normale"] as Image).duplicate() as Image
	Peinture.oublier()
	var e3: Dictionary = Peinture.cartes_de(chemin, {"normale": 8.0}, true)
	_dire(Peinture.cartes_en_retard() == 0 and _ecart_max(e3["images"]["normale"], ecrite) == 0,
		"relues sans calcul quand la signature tient")
	Peinture.oublier()
	Peinture.cartes_de(chemin, {"normale": 2.0}, true)
	_dire(Peinture.cartes_en_retard() == 1, "d'autres réglages : la signature ne tient plus")
	Peinture.oublier()
	var autre := _unie(64, Color(0.1, 0.1, 0.1))
	autre.save_png(chemin)
	Peinture.cartes_de(chemin, {"normale": 8.0}, true)
	_dire(Peinture.cartes_en_retard() == 1, "une image changée ailleurs : refaites")
	Peinture.oublier()


## 7. LE MATÉRIAU : avec « pbr », la normale et l'ORM sont les textures des cartes, canaux R/G/B ; sans, rien. Et
## les TANGENTES : là où la carte de normales les lit, dans le sens de u de la projection (écrit ici).
func _le_materiau_et_les_tangentes() -> void:
	Peinture.oublier()
	var chemin := _dossier.path_join("cube.png")
	Peinture.nouvelle_toile(chemin, Color(0.5, 0.4, 0.3), 64)
	var m: RefCounted = _cube()
	m.materiaux.append({"nom": "rock", "couleur": Color.WHITE, "rugosite": 0.8, "metal": 0.3, "texture": chemin,
		"echelle": 1.0, "pbr": Cartes.DEFAUTS.duplicate()})
	m.assigner(range(m.faces.size()), 0)
	var sm: StandardMaterial3D = m.materiau_godot(0)
	var e: Dictionary = Peinture.cartes_de(chemin, Cartes.DEFAUTS, true)
	_dire(sm.normal_enabled and is_same(sm.normal_texture, e["normale"]), "la carte de normales est celle des cartes")
	_dire(is_same(sm.roughness_texture, e["orm"]) and sm.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		and is_same(sm.metallic_texture, e["orm"]) and sm.metallic_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		and sm.ao_enabled and is_same(sm.ao_texture, e["orm"]) and sm.ao_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED,
		"l'ORM : occlusion en R, rugosité en G, métal en B")
	_dire(is_equal_approx(sm.metallic, 0.3) and is_equal_approx(sm.roughness, 1.0), "le facteur de métal reste le curseur (0,3), la rugosité vient de la carte")
	var mesh: ArrayMesh = m.vers_array_mesh()
	var a: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var tg = a[Mesh.ARRAY_TANGENT]
	_dire(tg != null and (tg as PackedFloat32Array).size() == v.size() * 4, "les tangentes sont là, une par sommet")
	if tg != null and (tg as PackedFloat32Array).size() == v.size() * 4:
		# La projection boîte (écrite ici, d'après la règle) : dessus u = +x ; face +x : u = −z ; face +z : u = +x.
		var mauvais := 0
		for i in v.size():
			var t := Vector3(tg[i * 4], tg[i * 4 + 1], tg[i * 4 + 2])
			var attendu := Vector3.ZERO
			var nn := nrm[i]
			if nn.y > 0.9:
				attendu = Vector3(1, 0, 0)
			elif nn.y < -0.9:
				attendu = Vector3(1, 0, 0)
			elif nn.x > 0.9:
				attendu = Vector3(0, 0, -1)
			elif nn.x < -0.9:
				attendu = Vector3(0, 0, 1)
			elif nn.z > 0.9:
				attendu = Vector3(1, 0, 0)
			else:
				attendu = Vector3(-1, 0, 0)
			if t.dot(attendu) < 0.99:
				mauvais += 1
		_dire(mauvais == 0, "chaque tangente suit le sens de u de la projection boîte (%d de travers)" % mauvais)
	m.materiaux[0].erase("pbr")
	var sans: StandardMaterial3D = m.materiau_godot(0)
	_dire(not sans.normal_enabled and sans.roughness_texture == null, "sans « pbr », ni normale ni ORM")
	# La pose d'un tableau (le monde) RECALCULE les tangentes qu'il portait, tournées avec lui.
	var pose := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(3, 0, 0))
	var posee: Array = BM._tableaux_poses(a, pose)
	var tp = posee[Mesh.ARRAY_TANGENT]
	var vp: PackedVector3Array = posee[Mesh.ARRAY_VERTEX]
	var tourne := 0
	if tp != null and (tp as PackedFloat32Array).size() == vp.size() * 4:
		for i in vp.size():
			var t0 := Vector3(tg[i * 4], tg[i * 4 + 1], tg[i * 4 + 2])
			var t1 := Vector3(tp[i * 4], tp[i * 4 + 1], tp[i * 4 + 2])
			if (pose.basis * t0).dot(t1) > 0.99:
				tourne += 1
	_dire(tourne == vp.size(), "posé (un quart de tour), chaque tangente a tourné avec la tuile (%d / %d)" % [tourne, vp.size()])
	Peinture.oublier()


## Un cube unité centré, six quads trigonométriques vus de dehors.
func _cube() -> RefCounted:
	var m: RefCounted = ME.new()
	var s := 0.5
	for p in [Vector3(-s, -s, -s), Vector3(s, -s, -s), Vector3(s, s, -s), Vector3(-s, s, -s),
			Vector3(-s, -s, s), Vector3(s, -s, s), Vector3(s, s, s), Vector3(-s, s, s)]:
		m.sommets.append(p)
	for f in [[0, 3, 2, 1], [4, 5, 6, 7], [0, 4, 7, 3], [1, 2, 6, 5], [3, 7, 6, 2], [0, 1, 5, 4]]:
		m._ajouter(PackedInt32Array(f), Color.WHITE, -1, PackedVector2Array())
	return m


## 8. LE .glb : un témoin dont un matériau dérive ses cartes les écrit — normale, occlusion, métal-rugosité dans le
## JSON du fichier, et l'attribut TANGENT sur ses primitives.
func _les_cartes_partent_dans_le_glb() -> void:
	Peinture.oublier()
	var chemin := _dossier.path_join("temoin.png")
	Peinture.nouvelle_toile(chemin, Color(0.5, 0.4, 0.3), 64)
	var calque: Image = Peinture.calque_actif(chemin)
	Peinture.tamponner(calque, Vector2(20, 20), 6.0, Color.WHITE, 1.0, 1.0)
	Peinture.composer(chemin)
	var t: RefCounted = TL.depuis_le_temoin_calcule()
	t.materiaux.append({"nom": "rock", "couleur": Color.WHITE, "rugosite": 0.8, "metal": 0.0, "texture": chemin,
		"echelle": 1.0, "pbr": Cartes.DEFAUTS.duplicate()})
	var une: String = t.tuiles.keys()[0]
	t.tuiles[une].assigner(range(t.tuiles[une].faces.size()), 0)
	var glb := _dossier.path_join("temoin.glb")
	var err: String = t.vers_glb(glb)
	_dire(err == "", "le témoin s'écrit (%s)" % err)
	var js := _json_du_glb(glb)
	var mat_pbr: Dictionary = {}
	var indice := -1
	for i in (js.get("materials", []) as Array).size():
		if str(js["materials"][i].get("name", "")) == "rock":
			mat_pbr = js["materials"][i]
			indice = i
	_dire(mat_pbr.has("normalTexture") and mat_pbr.has("occlusionTexture")
		and (mat_pbr.get("pbrMetallicRoughness", {}) as Dictionary).has("metallicRoughnessTexture"),
		"le matériau du .glb porte normale, occlusion et métal-rugosité : %s" % JSON.stringify(mat_pbr).left(200))
	var tangentes := true
	var vues := 0
	for mesh in js.get("meshes", []):
		for prim in mesh.get("primitives", []):
			if int(prim.get("material", -1)) == indice:
				vues += 1
				if not (prim["attributes"] as Dictionary).has("TANGENT"):
					tangentes = false
	_dire(vues > 0 and tangentes, "ses primitives portent leurs tangentes (%d primitive(s))" % vues)
	_dire(Peinture.cartes_en_retard() == 0, "le .glb n'est parti qu'avec des cartes à jour")
	Peinture.oublier()


## 8 ter. LE RETOUR DE BLENDER (3 octobre 2026) : un témoin lié relu d'un .glb garde ses cartes — la normale et l'ORM du
## matériau écrits à côté de son albedo sous des noms d'ENSEMBLE — et, repris du témoin d'avant par le nom du matériau,
## ses réglages de cartes déduites. Avant, il revenait avec son albedo seul.
func _le_retour_de_blender() -> void:
	Peinture.oublier()
	Peinture.oublier_les_ensembles()
	var chemin := _dossier.path_join("retour.png")
	Peinture.nouvelle_toile(chemin, Color(0.5, 0.4, 0.3), 64)
	Peinture.tamponner(Peinture.calque_actif(chemin), Vector2(20, 20), 6.0, Color.WHITE, 1.0, 1.0)
	Peinture.composer(chemin)
	var t: RefCounted = TL.depuis_le_temoin_calcule()
	var reglages: Dictionary = Cartes.DEFAUTS.duplicate()
	reglages["contraste"] = 3.0
	t.materiaux.append({"nom": "rock", "couleur": Color.WHITE, "rugosite": 0.8, "metal": 0.0, "texture": chemin,
		"echelle": 2.0, "pbr": reglages})
	for cle in t.tuiles:
		t.tuiles[cle].assigner(range(t.tuiles[cle].faces.size()), 0)
	var glb := _dossier.path_join("retour.glb")
	_dire(t.vers_glb(glb) == "", "le témoin peint s'écrit")
	var cartes: Dictionary = Peinture.cartes_de(chemin, reglages, true)
	var parties := {"normale": (cartes["normale"] as Texture2D).get_image(), "orm": (cartes["orm"] as Texture2D).get_image()}
	var images := _dossier.path_join("retour_images")
	# ⚠ VIDÉ D'ABORD : les cartes d'un passage précédent rendaient muette la mutation « rien n'est écrit ».
	for f in DirAccess.get_files_at(images):
		DirAccess.remove_absolute(images.path_join(f))
	var lu: RefCounted = TL.depuis_glb(glb, images)
	_dire(lu != null, "relu comme témoin lié")
	if lu == null:
		return
	var m: Dictionary = {}
	for x in lu.materiaux:
		if str(x.get("nom", "")) == "rock":
			m = x
	var tex := str(m.get("texture", ""))
	_dire(tex.ends_with("_color.png") and FileAccess.file_exists(tex), "l'albedo revient, nommé comme un ensemble (%s)" % tex.get_file())
	var base := tex.trim_suffix("_color.png")
	_dire(FileAccess.file_exists(base + "_normal_gl.png") and FileAccess.file_exists(base + "_arm.png"),
		"la normale et l'ORM du matériau sont écrits à côté")
	var trouves: Dictionary = Cartes.compagnons(tex, DirAccess.get_files_at(images))
	_dire(trouves.has("normale") and trouves.has("orm"), "… et se retrouvent comme un ensemble : %s" % trouves)
	var n := Image.load_from_file(base + "_normal_gl.png") if FileAccess.file_exists(base + "_normal_gl.png") else null
	var attendue: Image = (parties["normale"] as Image).duplicate()
	if n != null:
		n.convert(Image.FORMAT_RGB8)
		attendue.convert(Image.FORMAT_RGB8)
	_dire(n != null and n.get_size() == attendue.get_size() and _ecart_max(n, attendue) <= 2,
		"la normale revenue est celle qui est partie (écart %d)" % (_ecart_max(n, attendue) if n != null and n.get_size() == attendue.get_size() else -1))
	var arm := Image.load_from_file(base + "_arm.png") if FileAccess.file_exists(base + "_arm.png") else null
	var orm: Image = (parties["orm"] as Image).duplicate()
	var ecart_g := 999
	if arm != null and arm.get_size() == orm.get_size():
		arm.convert(Image.FORMAT_RGB8)
		orm.convert(Image.FORMAT_RGB8)
		ecart_g = 0
		for y in orm.get_height():
			for x in orm.get_width():
				ecart_g = maxi(ecart_g, absi(_octet(arm, x, y, 1) - _octet(orm, x, y, 1)))
				ecart_g = maxi(ecart_g, absi(_octet(arm, x, y, 0) - _octet(orm, x, y, 0)))
	_dire(ecart_g <= 2, "l'ORM revenu porte l'occlusion (R) et la rugosité (G) parties (écart %d)" % ecart_g)
	_dire(not m.has("pbr"), "sans le témoin d'avant, aucun réglage de cartes déduites (le glTF ne les porte pas)")
	_egal_int(lu.reprendre_les_reglages(t), 1, "repris du témoin d'avant : le matériau « rock », par son nom")
	_dire(m.get("pbr") is Dictionary and float(m["pbr"].get("contraste", 0)) == 3.0 and float(m.get("echelle", 0)) == 2.0,
		"… ses réglages de cartes et sa répétition")
	_dire(m.get("ensemble", true) == false, "… et ses cartes, qui étaient DÉDUITES, se redéduisent (l'ensemble rapporté est écarté)")
	Peinture.oublier()
	Peinture.oublier_les_ensembles()


func _egal_int(a: int, b: int, quoi: String) -> void:
	_dire(a == b, "%s (%d, attendu %d)" % [quoi, a, b])


## 8 bis. LE TRAJET ENTIER : le témoin lié et ses cartes → son .glb → le tranchage (la relecture liée) → le lot du
## monde → « Export to engines » (.mbset) → le greffon Godot GRATUIT, qui ne charge rien du cœur. À chaque étape :
## une carte de normales et des tangentes là où le matériau les demande.
func _le_trajet_jusqu_au_greffon() -> void:
	Peinture.oublier()
	var chemin := _dossier.path_join("trajet.png")
	Peinture.nouvelle_toile(chemin, Color(0.5, 0.4, 0.3), 64)
	Peinture.tamponner(Peinture.calque_actif(chemin), Vector2(30, 30), 8.0, Color.WHITE, 1.0, 1.0)
	Peinture.composer(chemin)
	var t: RefCounted = TL.depuis_le_temoin_calcule()
	t.materiaux.append({"nom": "rock", "couleur": Color.WHITE, "rugosite": 0.8, "metal": 0.0, "texture": chemin,
		"echelle": 1.0, "pbr": Cartes.DEFAUTS.duplicate()})
	for c in t.tuiles:
		t.tuiles[c].assigner(range(t.tuiles[c].faces.size()), 0)
	var glb := _dossier.path_join("trajet.glb")
	_dire(t.vers_glb(glb) == "", "le témoin lié s'écrit")
	var bilan: Dictionary = BM.librairie_depuis_glb(glb)
	_dire((bilan.get("erreurs", ["?"]) as Array).is_empty(), "il se relit lié, sans erreur (%s)" % str(bilan.get("erreurs", [])).left(120))
	var lot: MeshLibrary = bilan.get("lot")
	var avec := 0
	var tangentes := 0
	if lot != null:
		for id in lot.get_item_list():
			var mesh: Mesh = lot.get_item_mesh(id)
			for sf in mesh.get_surface_count():
				var mat := mesh.surface_get_material(sf) as BaseMaterial3D
				if mat != null and mat.normal_texture != null:
					avec += 1
					var tg = mesh.surface_get_arrays(sf)[Mesh.ARRAY_TANGENT]
					if tg != null and (tg as PackedFloat32Array).size() == (mesh.surface_get_arrays(sf)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() * 4:
						tangentes += 1
	_dire(avec >= 50 and tangentes == avec, "le lot du monde : %d surface(s) avec la carte de normales, %d avec leurs tangentes" % [avec, tangentes])
	var r: Dictionary = FN.exporter(lot, _dossier, "trajet", "test")
	_dire(not r.has("erreur"), "le .mbset s'écrit (%s)" % str(r.get("erreur", "")))
	var js := _json_du_glb(_dossier.path_join("trajet.mbset/tiles.glb"))
	var indices := {}
	for i in (js.get("materials", []) as Array).size():
		var m: Dictionary = js["materials"][i]
		if m.has("normalTexture") and m.has("occlusionTexture") and (m.get("pbrMetallicRoughness", {}) as Dictionary).has("metallicRoughnessTexture"):
			indices[i] = true
	var prims := 0
	var prims_tg := 0
	for mesh in js.get("meshes", []):
		for prim in mesh.get("primitives", []):
			if indices.has(int(prim.get("material", -1))):
				prims += 1
				prims_tg += int((prim["attributes"] as Dictionary).has("TANGENT"))
	_dire(not indices.is_empty() and prims >= 50 and prims_tg == prims,
		"tiles.glb : le matériau porte normale, occlusion, métal-rugosité ; %d primitive(s), %d avec TANGENT" % [prims, prims_tg])
	var lu: Dictionary = Tileset.load_tileset(_dossier.path_join("trajet.mbset/tileset.json"))
	var lib: MeshLibrary = lu.get("library")
	var dans_greffon := 0
	if lib != null:
		for id in lib.get_item_list():
			var mesh: Mesh = lib.get_item_mesh(id)
			for sf in mesh.get_surface_count():
				var mat := mesh.surface_get_material(sf) as BaseMaterial3D
				var tg = mesh.surface_get_arrays(sf)[Mesh.ARRAY_TANGENT]
				if mat != null and mat.normal_texture != null and mat.ao_texture != null and tg != null:
					dans_greffon += 1
	_dire(dans_greffon >= 50, "le greffon Godot les charge : %d surface(s) avec normale, occlusion et tangentes (%s)" % [dans_greffon, str(lu.get("error", ""))])
	Peinture.oublier()


func _json_du_glb(chemin: String) -> Dictionary:
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		return {}
	f.seek(12)
	var longueur := f.get_32()
	f.get_32()
	var lu: Variant = JSON.parse_string(f.get_buffer(longueur).get_string_from_utf8())
	return lu if lu is Dictionary else {}


## 9. L'ALBEDO DU RELIEF, sur le témoin calculé déplié en atlas. Les attendus sont recalculés ICI depuis la géométrie :
## au cœur d'un sol, la couleur des sols ; au cœur d'une paroi, celle des parois ; tout près d'une arête saillante loin
## des coupes, l'usure dosée par la distance ; sur une arête posée contre un plan de coupe, rien que la base.
func _l_albedo_du_relief() -> void:
	Peinture.oublier()
	var t: RefCounted = TL.depuis_le_temoin_calcule()
	var chemin := _dossier.path_join("relief.png")
	Peinture.nouvelle_toile(chemin, Color.WHITE, 512)
	t.materiaux.append({"nom": "ground", "couleur": Color.WHITE, "rugosite": 0.8, "metal": 0.0, "texture": chemin,
		"echelle": 1.0, "projection": "uv"})
	for c in t.tuiles:
		t.tuiles[c].assigner(range(t.tuiles[c].faces.size()), 0)
	t.deplier_en_atlas(0)
	var g := {"sol": [0.2, 0.6, 0.2], "paroi": [0.6, 0.4, 0.2], "plafond": [0.2, 0.2, 0.6], "arete": [1.0, 1.0, 1.0],
		"usure": 1.0, "cavite": 0.5, "largeur": 0.1}
	var debut := Time.get_ticks_msec()
	var r: Dictionary = t.albedo_du_relief(chemin, g, Vector2i(512, 512))
	var img: Image = r["image"]
	_dire(int(r["texels"]) > 10000, "l'atlas est cuit : %d texels, %d ms" % [int(r["texels"]), Time.get_ticks_msec() - debut])
	var sol := Color(0.2, 0.6, 0.2)
	var paroi := Color(0.6, 0.4, 0.2)
	var sols := 0
	var sols_justes := 0
	var parois := 0
	var parois_justes := 0
	var usures := 0
	var usures_justes := 0
	var coupes := 0
	var coupes_justes := 0
	var pres_coupes := 0
	var pres_coupes_justes := 0
	for c in t.tuiles:
		var m: RefCounted = t.tuiles[c]
		var aretes := _aretes_independantes(m)
		for f in m.faces.size():
			var u: PackedVector2Array = m.uv(f)
			if u.is_empty():
				continue
			var n: Vector3 = m.normale(f)
			var fa: PackedInt32Array = m.faces[f]
			# Le centre de la face (trouvé dans un de ses triangles, pour avoir son UV).
			for tri in m.trianguler(f):
				var p: Vector3 = (m.sommets[fa[tri[0]]] + m.sommets[fa[tri[1]]] + m.sommets[fa[tri[2]]]) / 3.0
				var q: Vector2 = (u[tri[0]] + u[tri[1]] + u[tri[2]]) / 3.0
				var px := Vector2i(int(q.x * 512), int(q.y * 512))
				if _aire_uv(u, tri) * 512 * 512 < 40.0:
					continue   # trop petit pour qu'un texel soit sûrement dedans
				var loin := _bord(p) > 1.0 / 16.0 + 0.02 and _dist_aux_aretes(p, aretes, f) > 0.1 + 0.02
				if not loin:
					continue
				var lu := img.get_pixelv(px)
				if n.y > 0.9:
					sols += 1
					if _proche(lu, sol):
						sols_justes += 1
				elif absf(n.y) < 0.1:
					parois += 1
					if _proche(lu, paroi):
						parois_justes += 1
			# Une arête saillante de la face, loin des coupes : un point à 0,03 d'elle, vers l'intérieur de la face.
			for e in aretes:
				if not (e["faces"] as Array).has(f) or float(e["signe"]) <= 0.0:
					continue
				var milieu: Vector3 = (e["a"] + e["b"]) * 0.5
				var dedans := _vers_l_interieur(m, f, milieu)
				var p2: Vector3 = milieu + dedans * 0.03
				if _bord(p2) < 1.0 / 16.0 + 0.03 or (e["b"] - e["a"]).length() < 0.2:
					continue
				var autre_pres := false
				for e2 in aretes:
					if e2 != e and (e2["faces"] as Array).has(f) and absf(float(e2["angle"])) > 0.05 \
							and TL._distance_au_segment_3d(p2, e2["a"], e2["b"]) < 0.1:
						autre_pres = true
				if autre_pres:
					continue
				var uvp := _uv_du_point(m, f, p2)
				if uvp == Vector2.INF:
					continue
				# L'attendu au CENTRE du texel lu, ramené sur la face (un texel de l'atlas fait ~0,02 case : prendre
				# l'attendu au point visé ferait juger la quantification, pas la règle).
				var px := Vector2i(int(uvp.x * 512), int(uvp.y * 512))
				var attendu: Variant = _attendu_au_texel(m, f, px, aretes, g)
				if attendu == null:
					continue
				usures += 1
				if _proche(img.get_pixelv(px), attendu, 0.02):
					usures_justes += 1
				# Le même bord saillant tout près d'un plan de coupe : l'usure s'y ÉTEINT (attendu recalculé, et il faut
				# que l'extinction y change vraiment quelque chose, sinon ce point ne garderait rien).
				for bout in [[e["a"], e["b"]], [e["b"], e["a"]]]:
					var le_long: Vector3 = (bout[1] - bout[0]).normalized()
					var p4: Vector3 = bout[0] + le_long * 0.012 + dedans * 0.03
					if _bord(p4) < 0.0 or _bord(p4) > 1.0 / 32.0:
						continue
					var uv4 := _uv_du_point(m, f, p4)
					if uv4 == Vector2.INF:
						continue
					var px4 := Vector2i(int(uv4.x * 512), int(uv4.y * 512))
					var eteint: Variant = _attendu_au_texel(m, f, px4, aretes, g)
					var allume: Variant = _attendu_au_texel(m, f, px4, aretes, g, false)
					if eteint == null or absf((eteint as Color).r - (allume as Color).r) < 0.05:
						continue
					pres_coupes += 1
					if _proche(img.get_pixelv(px4), eteint, 0.02):
						pres_coupes_justes += 1
			# Une arête SUR un plan de coupe (ouverte dans la tuile) : à son pied, la base seule.
			for e in aretes:
				if not (e["faces"] as Array).has(f) or (e["faces"] as Array).size() != 1:
					continue
				var milieu: Vector3 = (e["a"] + e["b"]) * 0.5
				if _bord(milieu) > 0.01:
					continue
				var p3: Vector3 = milieu + _vers_l_interieur(m, f, milieu) * 0.01
				var uvp3 := _uv_du_point(m, f, p3)
				if uvp3 == Vector2.INF:
					continue
				var base3 := paroi.lerp(sol, smoothstep(0.35, 0.75, n.y)).lerp(Color(0.2, 0.2, 0.6), smoothstep(0.35, 0.75, -n.y))
				coupes += 1
				if _proche(img.get_pixelv(Vector2i(int(uvp3.x * 512), int(uvp3.y * 512))), base3, 0.03):
					coupes_justes += 1
	_dire(sols > 20 and sols_justes == sols, "au cœur des sols, la couleur des sols (%d / %d)" % [sols_justes, sols])
	_dire(parois > 20 and parois_justes == parois, "au cœur des parois, la couleur des parois (%d / %d)" % [parois_justes, parois])
	_dire(usures > 100 and usures_justes == usures, "près d'une arête saillante, l'usure dosée par la distance (%d / %d)" % [usures_justes, usures])
	_dire(pres_coupes > 20 and pres_coupes_justes == pres_coupes,
		"près d'un plan de coupe, l'usure s'éteint (%d / %d)" % [pres_coupes_justes, pres_coupes])
	_dire(coupes > 20 and coupes_justes >= coupes * 0.95, "contre un plan de coupe, la base seule (%d / %d)" % [coupes_justes, coupes])
	Peinture.oublier()


## La couleur attendue au centre du texel `px` d'une face, recalculée ICI : orientation (normale de Newell), arêtes
## lues ici (angle, signe), distance, extinction près des plans de coupe. null si le centre du texel n'est pas sur la
## face.
func _attendu_au_texel(m: RefCounted, f: int, px: Vector2i, aretes: Array, g: Dictionary, eteindre := true) -> Variant:
	var q := (Vector2(px) + Vector2(0.5, 0.5)) / 512.0
	var fa: PackedInt32Array = m.faces[f]
	var u: PackedVector2Array = m.uv(f)
	var p := Vector3.INF
	for tri in m.trianguler(f):
		var a := u[tri[0]]
		var b := u[tri[1]]
		var c := u[tri[2]]
		var aire := (b - a).cross(c - a)
		if absf(aire) < 1e-12:
			continue
		var l1 := (c - b).cross(q - b) / aire
		var l2 := (a - c).cross(q - c) / aire
		var l3 := 1.0 - l1 - l2
		if l1 >= 0.0 and l2 >= 0.0 and l3 >= 0.0:
			p = m.sommets[fa[tri[0]]] * l1 + m.sommets[fa[tri[1]]] * l2 + m.sommets[fa[tri[2]]] * l3
			break
	if p == Vector3.INF:
		return null
	var col := func(k: String) -> Color:
		return Color(float(g[k][0]), float(g[k][1]), float(g[k][2]))
	var n := _normale_ici(m, f)
	var base: Color = (col.call("paroi") as Color).lerp(col.call("sol"), smoothstep(0.35, 0.75, n.y)).lerp(
		col.call("plafond"), smoothstep(0.35, 0.75, -n.y))
	var largeur := float(g["largeur"])
	var saillant := 0.0
	var rentrant := 0.0
	for e in aretes:
		if not (e["faces"] as Array).has(f) or absf(float(e["angle"])) < 0.05:
			continue
		var d := TL._distance_au_segment_3d(p, e["a"], e["b"])
		if d >= largeur:
			continue
		var force := float(e["angle"]) / (PI * 0.5) * (1.0 - d / largeur)
		if float(e["signe"]) > 0.0:
			saillant = maxf(saillant, force)
		else:
			rentrant = maxf(rentrant, force)
	var eteint := smoothstep(0.0, 1.0 / 16.0, _bord(p)) if eteindre else 1.0
	saillant = clampf(saillant * eteint, 0.0, 1.0)
	rentrant = clampf(rentrant * eteint, 0.0, 1.0)
	return base.lerp(col.call("arete"), saillant * float(g["usure"])) * (1.0 - rentrant * float(g["cavite"]))


func _proche(a: Color, b: Color, tol := 0.02) -> bool:
	return absf(a.r - b.r) <= tol and absf(a.g - b.g) <= tol and absf(a.b - b.b) <= tol


func _bord(p: Vector3) -> float:
	return minf(0.5 - absf(p.x), minf(0.5 - absf(p.y), 0.5 - absf(p.z)))


func _aire_uv(u: PackedVector2Array, tri: Array) -> float:
	return absf((u[tri[1]] - u[tri[0]]).cross(u[tri[2]] - u[tri[0]])) * 0.5


## Les arêtes de la tuile, lues ICI : extrémités, faces qui la portent, angle et signe (+ saillante).
func _aretes_independantes(m: RefCounted) -> Array:
	var par := {}
	for f in m.faces.size():
		var fa: PackedInt32Array = m.faces[f]
		for i in fa.size():
			var a: int = fa[i]
			var b: int = fa[(i + 1) % fa.size()]
			var k := Vector2i(mini(a, b), maxi(a, b))
			if not par.has(k):
				par[k] = {"a": m.sommets[a], "b": m.sommets[b], "faces": [], "angle": 0.0, "signe": 0.0}
			par[k]["faces"].append(f)
	for k in par:
		var e: Dictionary = par[k]
		if (e["faces"] as Array).size() != 2:
			continue
		var f1: int = e["faces"][0]
		var f2: int = e["faces"][1]
		var n1: Vector3 = _normale_ici(m, f1)
		var n2: Vector3 = _normale_ici(m, f2)
		e["angle"] = acos(clampf(n1.dot(n2), -1.0, 1.0))
		var c2 := Vector3.ZERO
		for s in m.faces[f2]:
			c2 += m.sommets[s]
		c2 /= float((m.faces[f2] as PackedInt32Array).size())
		e["signe"] = -1.0 if (c2 - (e["a"] + e["b"]) * 0.5).dot(n1) > 0.0 else 1.0
	return par.values()


## La normale d'une face, recalculée ici (Newell).
func _normale_ici(m: RefCounted, f: int) -> Vector3:
	var fa: PackedInt32Array = m.faces[f]
	var n := Vector3.ZERO
	for i in fa.size():
		var a: Vector3 = m.sommets[fa[i]]
		var b: Vector3 = m.sommets[fa[(i + 1) % fa.size()]]
		n += Vector3((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y))
	return n.normalized()


func _dist_aux_aretes(p: Vector3, aretes: Array, f: int) -> float:
	var d := INF
	for e in aretes:
		if (e["faces"] as Array).has(f) and absf(float(e["angle"])) > 0.05:
			d = minf(d, TL._distance_au_segment_3d(p, e["a"], e["b"]))
	return d


## Du milieu d'une arête vers le centre de la face, dans son plan.
func _vers_l_interieur(m: RefCounted, f: int, milieu: Vector3) -> Vector3:
	var c := Vector3.ZERO
	for s in m.faces[f]:
		c += m.sommets[s]
	c /= float((m.faces[f] as PackedInt32Array).size())
	return (c - milieu).normalized()


## L'UV d'un point d'une face (interpolé dans le triangle qui le contient), INF s'il n'est dans aucun.
func _uv_du_point(m: RefCounted, f: int, p: Vector3) -> Vector2:
	var fa: PackedInt32Array = m.faces[f]
	var u: PackedVector2Array = m.uv(f)
	for tri in m.trianguler(f):
		var a: Vector3 = m.sommets[fa[tri[0]]]
		var b: Vector3 = m.sommets[fa[tri[1]]]
		var c: Vector3 = m.sommets[fa[tri[2]]]
		var w: Vector3 = Geometry3D.get_triangle_barycentric_coords(p, a, b, c)
		if w.x >= -1e-4 and w.y >= -1e-4 and w.z >= -1e-4:
			return u[tri[0]] * w.x + u[tri[1]] * w.y + u[tri[2]] * w.z
	return Vector2.INF


## LES ENSEMBLES PBR (Jordan, 3 octobre 2026 : « sur les ensembles PBR appliqués aux UV d'un witness de test, je ne vois
## toujours que l'albedo ») — les cartes faites par l'auteur de la texture, trouvées à côté d'elle par leur nom. Attendus
## écrits à la main : les noms, les pixels des cartes posées.
func _les_ensembles() -> void:
	var ps := func(l: Array) -> PackedStringArray: return PackedStringArray(l)
	var c: Dictionary = Cartes.compagnons("D:/x/cliff_rocks_01_color_1k.png", ps.call(["cliff_rocks_01_color_1k.png",
		"cliff_rocks_01_normal_dx_1k.png", "cliff_rocks_01_normal_gl_1k.png", "cliff_rocks_01_roughness_1k.png",
		"cliff_rocks_01_ambient_occlusion_1k.png", "cliff_rocks_01_height_1k.png", "cliff_rocks_01_metallic_1k.png",
		"cliff_rocks_01_color_1k.png.import", "autre_normal_gl_1k.png"]))
	_dire(c == {"normale": "cliff_rocks_01_normal_gl_1k.png", "rugosite": "cliff_rocks_01_roughness_1k.png",
		"occlusion": "cliff_rocks_01_ambient_occlusion_1k.png", "metal": "cliff_rocks_01_metallic_1k.png",
		"hauteur": "cliff_rocks_01_height_1k.png"}, "ensemble « _color_ » : chaque carte trouvée, la normale OpenGL préférée — %s" % c)
	c = Cartes.compagnons("rock_color.png", ps.call(["rock_color.png", "rock_normal_dx.png"]))
	_dire(c == {"normale": "rock_normal_dx.png", "normale_dx": true}, "une normale DirectX seule : prise, et dite DirectX — %s" % c)
	c = Cartes.compagnons("Rock_Diff_2K.JPG", ps.call(["Rock_Diff_2K.JPG", "Rock_Nor_GL_2K.jpg", "Rock_ARM_2K.jpg"]))
	_dire(c == {"normale": "Rock_Nor_GL_2K.jpg", "orm": "Rock_ARM_2K.jpg"}, "nommage Poly Haven (diff, nor_gl, arm), casse gardée — %s" % c)
	c = Cartes.compagnons("rock_base_color.png", ps.call(["rock_base_color.png", "rock_normal.png", "rock_roughness.png"]))
	_dire(c == {"normale": "rock_normal.png", "rugosite": "rock_roughness.png"}, "« base_color » remplacé en entier — %s" % c)
	_dire(Cartes.compagnons("rock.png", ps.call(["rock.png", "rock_normal.png"])).is_empty(), "sans mot de couleur : pas d'ensemble")
	_dire(Cartes.compagnons("rock_colored.png", ps.call(["rock_colored.png", "rock_normaled.png", "rock_normal.png"])).is_empty(),
		"« colored » n'est pas le mot « color » : pas d'ensemble")

	# Les pixels : une normale DirectX a le vert inversé ; l'ORM range occlusion, rugosité, métal (blanc s'il manque).
	var n := Image.create(2, 2, false, Image.FORMAT_RGB8)
	n.fill(Color8(128, 77, 255))
	var dx: Image = Cartes.normale_de_l_ensemble(n, Vector2i(2, 2), true)
	_dire(dx.get_pixel(1, 1).g8 == 255 - 77 and dx.get_pixel(1, 1).r8 == 128, "DirectX → OpenGL : vert inversé (77 → 178)")
	var gris := func(v: int) -> Image:
		var i := Image.create(4, 4, false, Image.FORMAT_RGB8)
		i.fill(Color8(v, v, v))
		return i
	var orm: Image = Cartes.orm_de_l_ensemble(Vector2i(2, 2), gris.call(51), gris.call(153), null)
	var px := orm.get_pixel(0, 1)
	_dire(px.r8 == 51 and px.g8 == 153 and px.b8 == 255 and orm.get_size() == Vector2i(2, 2),
		"ORM : occlusion en R (51), rugosité en G (153), métal absent = blanc, à la taille demandée — %s" % px)

	# Le matériau : de vrais fichiers, un ensemble à côté d'une image.
	var dossier := _dossier.path_join("ensemble")
	DirAccess.make_dir_recursive_absolute(dossier)
	for f in DirAccess.get_files_at(dossier):
		DirAccess.remove_absolute(dossier.path_join(f))
	Peinture.oublier()
	Peinture.oublier_les_ensembles()
	var ecrire := func(nom: String, couleur: Color) -> void:
		var i := Image.create(8, 8, false, Image.FORMAT_RGB8)
		i.fill(couleur)
		i.save_png(dossier.path_join(nom))
	ecrire.call("pierre_color.png", Color8(200, 60, 40))
	ecrire.call("pierre_normal_gl.png", Color8(128, 191, 255))
	ecrire.call("pierre_roughness.png", Color8(102, 102, 102))
	ecrire.call("pierre_ao.png", Color8(179, 179, 179))
	var chemin := dossier.path_join("pierre_color.png")
	var m: RefCounted = _cube()
	m.materiaux.append({"nom": "pierre", "couleur": Color.WHITE, "rugosite": 0.8, "metal": 0.0, "texture": chemin,
		"echelle": 1.0, "projection": "boite"})
	m.assigner(range(m.faces.size()), 0)
	var sm: StandardMaterial3D = m.materiau_godot(0)
	_dire(sm.normal_enabled and sm.normal_texture != null
		and (sm.normal_texture.get_image().get_pixel(3, 3) as Color).g8 == 191,
		"un matériau dont l'image a un ensemble : SA carte de normales, sans rien cocher")
	var o: Image = sm.roughness_texture.get_image() if sm.roughness_texture != null else null
	_dire(o != null and o.get_pixel(3, 3).r8 == 179 and o.get_pixel(3, 3).g8 == 102 and o.get_pixel(3, 3).b8 == 255
		and sm.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_GREEN and sm.ao_enabled
		and is_same(sm.ao_texture, sm.roughness_texture) and sm.ao_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED,
		"… et SON occlusion (179) et SA rugosité (102), rangées en ORM")
	# ⚠ Godot rend un tableau de tangentes même quand on n'en a pas donné : on juge leur SENS — celui de u dans la
	# projection boîte (face +x : u = −z ; face −x : u = +z ; −z : u = −x), écrit ici d'après la règle.
	var ta: Array = m.vers_array_mesh().surface_get_arrays(0)
	var tg = ta[Mesh.ARRAY_TANGENT]
	var nn: PackedVector3Array = ta[Mesh.ARRAY_NORMAL]
	var de_travers := 0
	if tg != null and (tg as PackedFloat32Array).size() == nn.size() * 4:
		for i in nn.size():
			var attendu := Vector3(0, 0, -1) if nn[i].x > 0.9 else (Vector3(0, 0, 1) if nn[i].x < -0.9
				else (Vector3(-1, 0, 0) if nn[i].z < -0.9 else Vector3(1, 0, 0)))
			if Vector3(tg[i * 4], tg[i * 4 + 1], tg[i * 4 + 2]).dot(attendu) < 0.99:
				de_travers += 1
	else:
		de_travers = -1
	_dire(de_travers == 0, "… et le maillage porte des tangentes CALCULÉES, dans le sens de u (%d de travers)" % de_travers)
	# L'ensemble l'emporte sur les cartes déduites.
	var m2: RefCounted = _cube()
	m2.materiaux.append({"nom": "pierre", "couleur": Color.WHITE, "rugosite": 0.8, "metal": 0.0, "texture": chemin,
		"echelle": 1.0, "pbr": Cartes.DEFAUTS.duplicate()})
	var sm2: StandardMaterial3D = m2.materiau_godot(0)
	_dire(is_same(sm2.normal_texture, Peinture.ensemble_de(chemin)["normale"]), "ensemble ET cartes déduites : l'ensemble l'emporte")
	# Écarté par l'artiste : plus de carte (ni déduite : la case n'est pas cochée).
	var m3: RefCounted = _cube()
	m3.materiaux.append({"nom": "pierre", "couleur": Color.WHITE, "rugosite": 0.8, "metal": 0.0, "texture": chemin,
		"echelle": 1.0, "ensemble": false})
	var sm3: StandardMaterial3D = m3.materiau_godot(0)
	_dire(not sm3.normal_enabled and sm3.roughness_texture == null, "« ensemble » décoché : l'image seule")
	Peinture.oublier_les_ensembles()


## 11. L'ÉMISSION (Jordan, 6 octobre 2026 : « ajouter l'emission et l'inclure dans le PBR »). Une carte `_emission` /
## `_emissive` à côté de l'albedo : trouvée par son nom, posée dans le matériau avec la force du matériau, partie dans le
## .glb (emissiveTexture + KHR_materials_emissive_strength), jusqu'au lot du monde, au .mbset et au greffon Godot, et
## revenue d'un .glb de Blender. Attendus écrits ici : les noms, les pixels posés à la main, la force 3,5.
func _l_emission() -> void:
	var ps := func(a: Array) -> PackedStringArray: return PackedStringArray(a)
	var c: Dictionary = Cartes.compagnons("panel_color.png", ps.call(["panel_color.png", "panel_emission.png"]))
	_dire(c.get("emission", "") == "panel_emission.png", "« _emission » est l'émission de l'ensemble : %s" % c)
	c = Cartes.compagnons("Panel_BaseColor_2K.png", ps.call(["Panel_BaseColor_2K.png", "Panel_Emissive_2K.png",
		"Panel_Normal_2K.png"]))
	_dire(c.get("emission", "") == "Panel_Emissive_2K.png" and c.get("normale", "") == "Panel_Normal_2K.png",
		"« _Emissive » aussi, à côté d'une normale : %s" % c)
	var dossier := _dossier.path_join("emission")
	DirAccess.make_dir_recursive_absolute(dossier)
	for f in DirAccess.get_files_at(dossier):
		DirAccess.remove_absolute(dossier.path_join(f))
	Peinture.oublier()
	Peinture.oublier_les_ensembles()
	var albedo := Image.create(8, 8, false, Image.FORMAT_RGB8)
	albedo.fill(Color8(40, 40, 50))
	albedo.save_png(dossier.path_join("lampe_color.png"))
	# L'émission : noire, une bande jaune sur la rangée 3 (ce qui luit).
	var em := Image.create(8, 8, false, Image.FORMAT_RGB8)
	em.fill(Color8(0, 0, 0))
	for x in 8:
		em.set_pixel(x, 3, Color8(255, 220, 40))
	em.save_png(dossier.path_join("lampe_emission.png"))
	var chemin := dossier.path_join("lampe_color.png")
	var e: Dictionary = Peinture.ensemble_de(chemin)
	_dire(not e.is_empty() and e.get("emission") != null and e["normale"] == null and e["orm"] == null,
		"une émission SEULE fait un ensemble, sans relief")
	var avec := func(d: Dictionary) -> StandardMaterial3D:
		var m: RefCounted = _cube()
		var base := {"nom": "lampe", "couleur": Color.WHITE, "rugosite": 0.8, "metal": 0.0, "texture": chemin,
			"echelle": 1.0, "projection": "boite"}
		base.merge(d, true)
		m.materiaux.append(base)
		m.assigner(range(m.faces.size()), 0)
		return m.materiau_godot(0)
	var sm: StandardMaterial3D = avec.call({"emission": 4.0})
	var lue: Image = sm.emission_texture.get_image() if sm.emission_texture != null else null
	_dire(sm.emission_enabled and lue != null and lue.get_pixel(5, 3).r8 == 255 and lue.get_pixel(5, 3).g8 == 220
		and lue.get_pixel(5, 4).r8 == 0 and sm.emission == Color.WHITE,
		"le matériau luit de SA carte : la bande jaune, le reste noir")
	_dire(is_equal_approx(sm.emission_energy_multiplier, 4.0), "… à la force du matériau (4)")
	# ⚠ En ADD (le défaut de Godot), la couleur blanche s'ajoutait à la carte : le témoin luisait blanc uni.
	_dire(sm.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY,
		"… la couleur MULTIPLIE la carte (glTF), elle ne s'y ajoute pas — sinon le noir luit blanc")
	_dire(not sm.normal_enabled and sm.roughness_texture == null, "… et sans relief inventé")
	_dire(is_equal_approx((avec.call({}) as StandardMaterial3D).emission_energy_multiplier, 1.0),
		"sans réglage, la force vaut 1 (celle du glTF)")
	_dire(not (avec.call({"ensemble": false}) as StandardMaterial3D).emission_enabled,
		"« ensemble » décoché : pas d'émission")
	var avec_pbr: StandardMaterial3D = avec.call({"pbr": Cartes.DEFAUTS.duplicate()})
	_dire(avec_pbr.emission_enabled and avec_pbr.normal_enabled and avec_pbr.normal_texture != null,
		"émission seule ET cartes déduites : les deux (l'émission ne porte pas de relief)")
	Peinture.oublier()

	# Le trajet : témoin lié → .glb → lot du monde → .mbset → greffon Godot.
	var t: RefCounted = TL.depuis_le_temoin_calcule()
	t.materiaux.append({"nom": "lampe", "couleur": Color.WHITE, "rugosite": 0.8, "metal": 0.0, "texture": chemin,
		"echelle": 1.0, "projection": "boite", "emission": 3.5})
	for cle in t.tuiles:
		t.tuiles[cle].assigner(range(t.tuiles[cle].faces.size()), 0)
	var glb := dossier.path_join("lampe.glb")
	_dire(t.vers_glb(glb) == "", "le témoin qui luit s'écrit")
	var js := _json_du_glb(glb)
	var vu := false
	for m in js.get("materials", []):
		if str(m.get("name", "")) == "lampe":
			var fort: Dictionary = (m.get("extensions", {}) as Dictionary).get("KHR_materials_emissive_strength", {})
			vu = m.has("emissiveTexture") and is_equal_approx(float(fort.get("emissiveStrength", 0)), 3.5)
	_dire(vu, "le .glb porte emissiveTexture et la force 3,5 (KHR_materials_emissive_strength)")
	var bilan: Dictionary = BM.librairie_depuis_glb(glb)
	var lot: MeshLibrary = bilan.get("lot")
	_dire(_surfaces_qui_luisent(lot, 3.5) >= 50, "le lot du monde luit : %d surface(s) avec l'émission à 3,5"
		% _surfaces_qui_luisent(lot, 3.5))
	var r: Dictionary = FN.exporter(lot, dossier, "lampe", "test")
	_dire(not r.has("erreur"), "le .mbset s'écrit (%s)" % str(r.get("erreur", "")))
	var js2 := _json_du_glb(dossier.path_join("lampe.mbset/tiles.glb"))
	var dans_mbset := false
	for m in js2.get("materials", []):
		var fort: Dictionary = (m.get("extensions", {}) as Dictionary).get("KHR_materials_emissive_strength", {})
		if m.has("emissiveTexture") and is_equal_approx(float(fort.get("emissiveStrength", 0)), 3.5):
			dans_mbset = true
	_dire(dans_mbset, "tiles.glb du .mbset porte l'émission et sa force")
	var lu_g: Dictionary = Tileset.load_tileset(dossier.path_join("lampe.mbset/tileset.json"))
	var lib: MeshLibrary = lu_g.get("library")
	_dire(_surfaces_qui_luisent(lib, 3.5) >= 50, "le greffon Godot les charge lumineuses : %d surface(s)"
		% _surfaces_qui_luisent(lib, 3.5))

	# Le retour de Blender : la carte revient à côté de l'albedo, la force dans le matériau.
	var images := dossier.path_join("retour_images")
	DirAccess.make_dir_recursive_absolute(images)
	for f in DirAccess.get_files_at(images):
		DirAccess.remove_absolute(images.path_join(f))
	var relu: RefCounted = TL.depuis_glb(glb, images)
	var m_lu: Dictionary = {}
	if relu != null:
		for x in relu.materiaux:
			if str(x.get("nom", "")) == "lampe":
				m_lu = x
	var tex := str(m_lu.get("texture", ""))
	var em_lue := tex.trim_suffix("_color.png") + "_emission.png"
	var img_lue := Image.load_from_file(em_lue) if tex != "" and FileAccess.file_exists(em_lue) else null
	_dire(img_lue != null and img_lue.get_pixel(5, 3).g8 == 220 and img_lue.get_pixel(5, 4).r8 == 0,
		"revenue d'un .glb, l'émission est écrite à côté de l'albedo (%s)" % em_lue.get_file())
	_dire(is_equal_approx(float(m_lu.get("emission", 0)), 3.5), "… avec sa force (3,5)")
	_dire(Cartes.compagnons(tex, DirAccess.get_files_at(images)).has("emission"), "… et se retrouve comme un ensemble")
	_emission_au_bout = true
	Peinture.oublier()
	Peinture.oublier_les_ensembles()


func _surfaces_qui_luisent(lib: MeshLibrary, force: float) -> int:
	var n := 0
	if lib == null:
		return 0
	for id in lib.get_item_list():
		var mesh: Mesh = lib.get_item_mesh(id)
		for sf in mesh.get_surface_count():
			var mat := mesh.surface_get_material(sf) as BaseMaterial3D
			if mat != null and mat.emission_enabled and mat.emission_texture != null \
					and is_equal_approx(mat.emission_energy_multiplier, force) 					and (mat.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY or mat.emission == Color.BLACK):
				n += 1
	return n
