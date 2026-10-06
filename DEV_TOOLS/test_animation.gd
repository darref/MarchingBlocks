extends SceneTree
## TEST — les textures animées (`animation_materiau.gd`) : Jordan, 6 octobre 2026.
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_animation.gd
##
## ⚠ LES ATTENDUS VIENNENT D'AILLEURS (charte §6) : les images au temps t et la pulsation, déroulées à la main ; l'ordre
## d'une séquence, écrit à la main ; les cases d'une planche, peintes ici de couleurs connues ; les extras du .glb, lus
## dans le JSON du FICHIER (pas par l'importeur de Godot) ; la phase, recalculée ici par la formule du shader écrite à
## nouveau. ⚠ Le headless ne compile pas les shaders ni ne garde les textures envoyées : le shader se juge avec fenêtre
## (`DEV_TOOLS/capture_animation.gd`).

const Anim := preload("res://addons/marchingblocks_core/animation_materiau.gd")
const Peinture := preload("res://addons/marchingblocks_core/peinture.gd")
const ME := preload("res://addons/marchingblocks_core/maillage_edite.gd")
const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const FN := preload("res://addons/marchingblocks_core/format_neutre.gd")
const Projet := preload("res://app/projet.gd")
const Cartes := preload("res://addons/marchingblocks_core/cartes_pbr.gd")

var _ok := 0
var _echecs := 0
var _premier := ""
var _dossier := ""
var _au_bout := false


func _initialize() -> void:
	print("=== TEST — les textures animées ===\n")
	_dossier = ProjectSettings.globalize_path("user://test_animation")
	DirAccess.make_dir_recursive_absolute(_dossier)
	_vider(_dossier)
	Anim.oublier()
	Peinture.oublier()
	_le_modele()
	_le_temps()
	_la_phase()
	_les_sequences_et_les_planches()
	_le_materiau()
	_la_peinture_d_une_image()
	_le_trajet_du_glb()
	_au_bout = true
	Anim.oublier()
	Peinture.oublier()
	_dire(_au_bout, "SENTINELLE : la suite est allée au bout")
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


func _vider(dossier: String) -> void:
	if not DirAccess.dir_exists_absolute(dossier):
		return
	for d in DirAccess.get_directories_at(dossier):
		_vider(dossier.path_join(d))
		DirAccess.remove_absolute(dossier.path_join(d))
	for f in DirAccess.get_files_at(dossier):
		DirAccess.remove_absolute(dossier.path_join(f))


## Deux couleurs égales à l'arrondi d'un PNG 8 bits près.
func _proches(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.006 and absf(a.g - b.g) < 0.006 and absf(a.b - b.b) < 0.006


func _unie(c: Color, n := 8) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return img


## 1. LE MODÈLE : on ne crée que ce qu'on utilise ; une piste par (canal, genre) ; la pulsation est celle de
## l'émission ; une piste d'images sans image n'existe pas ; les réglages sont bornés.
func _le_modele() -> void:
	_dire(Anim.normaliser(null).is_empty() and Anim.normaliser({}).is_empty() and Anim.pistes(null).is_empty(),
		"pas d'animation : rien")
	var a := Anim.ajouter({}, "albedo", "defilement", {"v": -0.5})
	_dire(a == {"albedo": {"defilement": {"u": 0.0, "v": -0.5, "synchro": true}}}, "une piste de défilement : %s" % a)
	_dire(Anim.ajouter(a, "albedo", "defilement").has("erreur"), "deux défilements sur un canal : refusé")
	_dire(Anim.ajouter(a, "albedo", "pulsation").has("erreur"), "une pulsation sur la couleur de base : refusée")
	_dire(Anim.ajouter(a, "normale", "images").has("erreur"), "une piste d'images sans image : refusée")
	a = Anim.ajouter(a, "emission", "pulsation", {"frequence": 2.0})
	a = Anim.ajouter(a, "normale", "images", {"images": ["x.png", "y.png"], "ips": 999.0})
	_dire(Anim.pistes(a) == [["albedo", "defilement"], ["normale", "images"], ["emission", "pulsation"]],
		"les pistes dans l'ordre fixe : %s" % [Anim.pistes(a)])
	_dire(is_equal_approx(float(a["normale"]["images"]["ips"]), Anim.IPS_MAXI), "les images/s sont bornées (60)")
	_dire(not bool(a["normale"]["images"]["synchro"]) and bool(a["albedo"]["defilement"]["synchro"]),
		"par défaut : défilement synchro, images décalées")
	var b := Anim.regler(a, "albedo", "defilement", "u", 50.0)
	_dire(is_equal_approx(float(b["albedo"]["defilement"]["u"]), Anim.VITESSE_MAXI), "une vitesse est bornée (10)")
	_dire(Anim.regler(a, "orm", "defilement", "u", 1.0) == a, "régler une piste absente ne change rien")
	var c := Anim.retirer(a, "albedo", "defilement")
	_dire(not c.has("albedo") and c.has("emission"), "retirer la seule piste d'un canal retire le canal")
	_dire(Anim.retirer(Anim.retirer(c, "normale", "images"), "emission", "pulsation").is_empty(),
		"tout retiré : plus d'animation")
	_dire(Anim.normaliser({"albedo": {"images": {"images": []}}, "bidule": {}, "emission": {"vague": {}}}).is_empty(),
		"des pistes inconnues ou vides sont écartées")
	_dire(Anim.images_de(a, "normale") == ["x.png", "y.png"] and Anim.images_de(a, "albedo").is_empty(),
		"les images d'un canal")


## 2. LE TEMPS : l'image au temps t et la pulsation, déroulées à la main.
func _le_temps() -> void:
	# 4 images à 2 images/s : t = 0 → 0 ; 0,6 → floor(1,2) = 1 ; 1,5 → 3 ; 2,1 → floor(4,2) = 4 → 0.
	var vues: Array = []
	for t in [0.0, 0.6, 1.5, 2.1]:
		vues.append(Anim.image_au_temps(4, 2.0, false, t))
	_dire(vues == [0, 1, 3, 0], "en boucle : %s" % [vues])
	# En aller-retour, 4 images : 0 1 2 3 2 1 0 1… (période 6).
	vues = []
	for k in 8:
		vues.append(Anim.image_au_temps(4, 1.0, true, float(k) + 0.5))
	_dire(vues == [0, 1, 2, 3, 2, 1, 0, 1], "en aller-retour : %s" % [vues])
	_dire(Anim.image_au_temps(1, 5.0, true, 3.7) == 0 and Anim.image_au_temps(0, 5.0, false, 3.7) == 0,
		"une seule image (ou aucune) : l'image 0")
	# Une phase de ½ sur 4 images avance de 2 images.
	_dire(Anim.image_au_temps(4, 1.0, false, 0.2, 0.5) == 2, "une phase de ½ décale de deux images sur quatre")
	_dire(is_equal_approx(Anim.pulsation_au_temps(1.0, 0.2, 0.0), 1.0)
		and is_equal_approx(Anim.pulsation_au_temps(1.0, 0.2, 0.5), 0.2)
		and is_equal_approx(Anim.pulsation_au_temps(1.0, 0.2, 0.25), 0.6),
		"la pulsation : 1 au sommet, le minimum au creux, la moitié entre les deux")
	_dire(is_equal_approx(Anim.pulsation_au_temps(0.0, 0.2, 0.37), 1.0), "sans fréquence : pas de pulsation")


## 3. LA PHASE D'UNE COPIE : déterministe, dans [0, 1[, différente d'une place à l'autre — recalculée ici par la formule
## du shader, écrite à nouveau.
func _la_phase() -> void:
	var distinctes := {}
	var justes := true
	var bornees := true
	for x in 10:
		for z in 10:
			var o := Vector3(x * 1.0 + 1.0, 3.0, z * 1.0 - 4.0)
			var p := Anim.phase_de(o)
			var q: Vector3 = floor(o + Vector3(0.5, 0.5, 0.5))
			var r := Vector3(fposmod(q.x * 0.3183099 + 0.71, 1.0), fposmod(q.y * 0.3183099 + 0.113, 1.0),
				fposmod(q.z * 0.3183099 + 0.419, 1.0)) * 17.0
			var attendu := fposmod(r.x * r.y * r.z * (r.x + r.y + r.z), 1.0)
			justes = justes and absf(p - attendu) < 1e-4
			bornees = bornees and p >= 0.0 and p < 1.0
			distinctes[snappedf(p, 0.001)] = true
	_dire(justes, "la phase est celle de la formule du shader")
	_dire(bornees, "la phase est dans [0, 1[")
	_dire(distinctes.size() >= 90, "cent places, %d phases différentes" % distinctes.size())
	_dire(Anim.phase_de(Vector3(2, 3, 4)) == Anim.phase_de(Vector3(2.2, 3.1, 3.9)), "la phase ne dépend que de la case")


## 4. LES SÉQUENCES ET LES PLANCHES : l'ordre naturel des noms, la taille de la première, une planche lue de gauche à
## droite puis de haut en bas, les bornes.
func _les_sequences_et_les_planches() -> void:
	var source := _dossier.path_join("source")
	DirAccess.make_dir_recursive_absolute(source)
	var couleurs := {"frame_10.png": Color.BLUE, "frame_2.png": Color.GREEN, "frame_1.png": Color.RED}
	for nom in couleurs:
		_unie(couleurs[nom], 8).save_png(source.path_join(nom))
	# La seconde dans l'ordre est plus GRANDE : elle est ramenée à la taille de la première.
	_unie(Color.GREEN, 16).save_png(source.path_join("frame_2.png"))
	var fichiers := PackedStringArray([source.path_join("frame_10.png"), source.path_join("frame_1.png"),
		source.path_join("frame_2.png")])
	var dest := _dossier.path_join("anim")
	var r := Anim.importer_sequence(fichiers, dest, "rock_albedo")
	var images: Array = r.get("images", [])
	_dire(images.size() == 3, "trois images importées (%s)" % str(r.get("erreur", "")))
	if images.size() == 3:
		var lues: Array = images.map(func(c: String) -> Image: return Image.load_from_file(c))
		_dire(lues[0].get_pixel(2, 2).is_equal_approx(Color.RED) and lues[1].get_pixel(2, 2).is_equal_approx(Color.GREEN)
			and lues[2].get_pixel(2, 2).is_equal_approx(Color.BLUE), "dans l'ordre NATUREL : frame_1, frame_2, frame_10")
		_dire(lues.all(func(i: Image) -> bool: return i.get_size() == Vector2i(8, 8)), "toutes à la taille de la première")
		_dire(images[0].begins_with(dest) and images[0].get_file() == "rock_albedo_0000.png", "copiées dans le projet")
	var r2 := Anim.importer_sequence(PackedStringArray([source.path_join("frame_1.png")]), dest, "rock_albedo")
	_dire((r2.get("images", [""]) as Array)[0].get_file() == "rock_albedo_2_0000.png",
		"une seconde importation ne recouvre pas la première")
	# Une planche de 4 × 2, cases de 4 pixels, chacune de sa couleur ; 6 images lues.
	var planche := Image.create(16, 8, false, Image.FORMAT_RGBA8)
	var teintes: Array = []
	for k in 8:
		var c := Color.from_hsv(k / 8.0, 1.0, 1.0)
		teintes.append(c)
		planche.fill_rect(Rect2i((k % 4) * 4, (k / 4) * 4, 4, 4), c)
	planche.save_png(source.path_join("planche.png"))
	var r3 := Anim.importer_planche(source.path_join("planche.png"), 4, 2, 6, dest, "sheet")
	var cases: Array = r3.get("images", [])
	var justes := cases.size() == 6
	for k in cases.size():
		var img := Image.load_from_file(cases[k])
		justes = justes and img.get_size() == Vector2i(4, 4) and _proches(img.get_pixel(1, 1), teintes[k])
	_dire(justes, "une planche 4 × 2, six images : les bonnes cases, dans l'ordre")
	_dire(Anim.importer_planche(source.path_join("planche.png"), 0, 2, 0, dest, "x").has("erreur"),
		"une planche sans colonne : refusée")
	var trop: Array = []
	for k in 5:
		trop.append(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	_dire(Anim._ecrire(trop, dest, "petit").has("images"), "cinq petites images passent")
	var grandes: Array = [Image.create(8192, 8192, false, Image.FORMAT_L8), Image.create(8, 8, false, Image.FORMAT_L8)]
	_dire(Anim._ecrire(grandes, dest, "trop").has("erreur"), "2 × 8192² pixels : refusé (trop de mémoire)")
	var neuves := Anim.images_neuves(3, Vector2i(4, 4), Color.YELLOW, dest, "vierge")
	_dire((neuves.get("images", []) as Array).size() == 3 and Image.load_from_file(neuves["images"][2]).get_pixel(0, 0)
		.is_equal_approx(Color.YELLOW), "trois images neuves, unies")
	var dup := Anim.dupliquer_image(neuves["images"], 0, dest)
	var liste: Array = dup.get("images", [])
	_dire(liste.size() == 4 and liste[0] == neuves["images"][0] and liste[2] == neuves["images"][1]
		and Image.load_from_file(liste[1]).get_pixel(0, 0).is_equal_approx(Color.YELLOW),
		"copier l'image 0 l'insère juste après elle")


## 5. LE MATÉRIAU : le statique porte l'image 0 de chaque canal animé et les extras ; le montré est animé, son statique
## en repli ; ses tableaux portent les images ; ses réglages sont ceux des pistes.
func _le_materiau() -> void:
	Anim.oublier()
	Peinture.oublier()
	var dest := _dossier.path_join("materiau")
	var albedo: Array = Anim.images_neuves(3, Vector2i(8, 8), Color.RED, dest, "a")["images"]
	var lueur: Array = Anim.images_neuves(2, Vector2i(8, 8), Color.CYAN, dest, "e")["images"]
	var a := Anim.ajouter({}, "albedo", "images", {"images": albedo, "ips": 6.0, "aller_retour": true, "synchro": true})
	a = Anim.ajouter(a, "albedo", "defilement", {"u": 0.25, "v": -0.5, "synchro": false})
	a = Anim.ajouter(a, "emission", "images", {"images": lueur})
	a = Anim.ajouter(a, "emission", "pulsation", {"frequence": 2.0, "mini": 0.3})
	var m: RefCounted = ME.new()
	for p in [Vector3(-0.5, -0.5, -0.5), Vector3(0.5, -0.5, -0.5), Vector3(0.5, 0.5, -0.5), Vector3(-0.5, 0.5, -0.5)]:
		m.sommets.append(p)
	m._ajouter(PackedInt32Array([0, 3, 2, 1]), Color.WHITE, -1, PackedVector2Array())
	# Une image FIXE et des cartes déduites demandées : l'albedo animé par images doit quand même s'en passer.
	var fixe: String = Anim.images_neuves(1, Vector2i(8, 8), Color.GRAY, dest, "fixe")["images"][0]
	m.materiaux.append({"nom": "screen", "couleur": Color.WHITE, "rugosite": 0.6, "metal": 0.0, "texture": fixe,
		"echelle": 1.0, "animation": a, "emission": 2.5, "pbr": Cartes.DEFAUTS.duplicate()})
	m.assigner([0], 0)
	var sm: StandardMaterial3D = m.materiau_godot(0)
	_dire(sm.albedo_texture != null and is_same(sm.albedo_texture, Peinture.texture_de(albedo[0])),
		"le statique montre l'image 0 de la couleur de base (la toile PARTAGÉE de l'image)")
	_dire(sm.emission_enabled and is_same(sm.emission_texture, Peinture.texture_de(lueur[0]))
		and is_equal_approx(sm.emission_energy_multiplier, 2.5), "… et l'image 0 de l'émission, à la force du matériau")
	_dire(not sm.normal_enabled and sm.roughness_texture == null,
		"un albedo animé par images n'a pas de cartes déduites, même demandées (Jordan)")
	var sans: Dictionary = (m.materiaux[0] as Dictionary).duplicate()
	sans.erase("animation")
	var m3: RefCounted = ME.new()
	m3.materiaux.append(sans)
	_dire(m3.materiau_godot(0).normal_enabled, "contrôle : la même image fixe, sans animation, les a")
	_dire((sm.get_meta("extras", {}) as Dictionary).get("mb_animation") == Anim.normaliser(a),
		"les extras portent l'animation")
	var montre: Material = m.materiau_affiche(0)
	_dire(montre is ShaderMaterial and is_same(montre.get_meta("repli"), sm), "le montré est animé, le statique en repli")
	_dire(is_same(m.materiau_affiche(0), montre), "le même animé à chaque appel (partagé)")
	var tab: Texture2DArray = montre.get_shader_parameter("albedo_images")
	_dire(tab != null and tab.get_layers() == 3 and tab.get_width() == 8, "le tableau de la couleur de base : 3 couches")
	_dire(montre.get_shader_parameter("albedo_reglages") == Vector4i(3, 1, 1, 0),
		"ses réglages : 3 images, aller-retour, images synchro, défilement décalé (%s)"
		% montre.get_shader_parameter("albedo_reglages"))
	_dire(montre.get_shader_parameter("albedo_mouvement") == Vector4(0.25, -0.5, 6.0, 0.0), "le défilement et les images/s")
	_dire(montre.get_shader_parameter("pulsation") == Vector3(2.0, 0.3, 0.0), "la pulsation (décalée par défaut)")
	_dire(montre.get_shader_parameter("a_emission") == true and is_equal_approx(float(montre.get_shader_parameter(
		"force_emission")), 2.5), "l'émission et sa force")
	var mesh: ArrayMesh = m.vers_array_mesh()
	_dire(is_same(mesh.surface_get_material(0), montre), "le maillage dessiné porte l'animé")
	_dire(Anim.figer_le_maillage(mesh) == 1 and is_same(mesh.surface_get_material(0), sm), "figé : le statique")
	_dire(Anim.animer_le_maillage(mesh) == 1 and is_same(mesh.surface_get_material(0), montre),
		"animé de nouveau : le même animé")
	var export: Material = Anim.statique_pour_l_export(montre)
	var ex: Dictionary = Anim.animation_des_extras(export)
	_dire(ex.get("albedo", {}).get("images", {}).get("images", []) == ["a_0000.png", "a_0001.png", "a_0002.png"]
		and not is_same(export, sm), "pour l'export, les images ne sont nommées que par leur nom de fichier")
	# Sans animation : le statique, tel quel.
	var m2: RefCounted = ME.new()
	m2.materiaux.append({"nom": "still", "couleur": Color.WHITE, "rugosite": 0.8, "metal": 0.0, "texture": "",
		"echelle": 1.0})
	_dire(m2.materiau_affiche(0) is StandardMaterial3D and not m2.materiau_godot(0).has_meta("extras"),
		"un matériau sans animation reste un StandardMaterial3D, sans extras")


## 6. PEINDRE UNE IMAGE : le tableau de textures suit la toile de l'image peinte (à la prochaine image, pas au tampon).
func _la_peinture_d_une_image() -> void:
	Anim.oublier()
	Peinture.oublier()
	var dest := _dossier.path_join("peinture")
	var images: Array = Anim.images_neuves(3, Vector2i(16, 16), Color.BLACK, dest, "p")["images"]
	var tab := Anim.tableau_de(images)
	_dire(tab != null and is_same(Anim.tableau_de(images.duplicate()), tab), "le tableau est partagé")
	var calque: Image = Peinture.calque_actif(images[1])
	Peinture.tamponner(calque, Vector2(8, 8), 3.0, Color.WHITE, 1.0, 1.0)
	Peinture.composer(images[1])
	var e: Dictionary = Anim._tableaux.values()[0]
	_dire(e["sales"] == {1: true}, "peindre l'image 1 marque SA couche (%s)" % e["sales"])
	_dire(Anim._image_de(images[1], Vector2i(16, 16)).get_pixel(8, 8).is_equal_approx(Color.WHITE),
		"la couche se relit dans la TOILE peinte (pas encore écrite)")
	Anim.avancer(0.1)
	_dire((e["sales"] as Dictionary).is_empty(), "à la prochaine image, la couche est posée")
	_dire(is_equal_approx(Anim.temps, 0.1), "le temps avance")
	Anim.en_pause = true
	Anim.avancer(0.5)
	_dire(is_equal_approx(Anim.temps, 0.1), "en pause, il n'avance plus")
	Anim.en_pause = false
	Anim.fige = true
	Anim.avancer(0.5)
	_dire(is_equal_approx(Anim.temps, 0.1), "figé (on peint), il n'avance plus")
	Anim.fige = false
	Anim.vitesse = 2.0
	Anim.avancer(0.5)
	_dire(is_equal_approx(Anim.temps, 1.1), "à la vitesse 2, une demi-seconde en vaut une")


## 7. LE TRAJET : un témoin dont un matériau est animé → .glb (les extras dans le JSON du FICHIER, un matériau
## standard) → le lot du monde (animé) → le cache (écrit statique, relu animé) → le .mbset (statique, sans chemin) →
## un témoin relu (l'animation revient) et repris par le nom.
func _le_trajet_du_glb() -> void:
	Anim.oublier()
	Peinture.oublier()
	var dest := _dossier.path_join("trajet")
	var images: Array = Anim.images_neuves(4, Vector2i(8, 8), Color.ORANGE, dest, "lava")["images"]
	var a := Anim.ajouter({}, "albedo", "images", {"images": images, "ips": 8.0})
	a = Anim.ajouter(a, "albedo", "defilement", {"v": -0.25})
	var t: RefCounted = TL.depuis_le_temoin_calcule()
	t.materiaux.append({"nom": "lava", "couleur": Color.WHITE, "rugosite": 0.8, "metal": 0.0, "texture": "",
		"echelle": 1.0, "projection": "boite", "animation": a})
	for c in t.tuiles:
		t.tuiles[c].assigner(range(t.tuiles[c].faces.size()), 0)
	var glb := dest.path_join("lava.glb")
	_dire(t.vers_glb(glb) == "", "le témoin animé s'écrit")
	var js := _json_du_glb(glb)
	var mat: Dictionary = {}
	for x in js.get("materials", []):
		if str(x.get("name", "")) == "lava":
			mat = x
	var extras: Dictionary = (mat.get("extras", {}) as Dictionary).get("mb_animation", {})
	_dire(Anim.normaliser(extras) == Anim.normaliser(a), "le .glb porte l'animation dans les extras du matériau : %s"
		% JSON.stringify(extras).left(160))
	_dire((mat.get("pbrMetallicRoughness", {}) as Dictionary).has("baseColorTexture"),
		"… un matériau standard, avec l'image 0 en couleur de base")
	var bilan: Dictionary = BM.librairie_depuis_glb(glb)
	_dire((bilan.get("erreurs", ["?"]) as Array).is_empty(), "il se relit lié, sans erreur (%s)"
		% str(bilan.get("erreurs", [])).left(120))
	var lot: MeshLibrary = bilan.get("lot")
	var animes := _animes(lot, a)
	_dire(animes >= 50, "le lot du monde : %d surface(s) animées, avec l'animation d'origine" % animes)
	_dire(Anim.lot_anime(lot), "le lot se sait animé")
	# Le cache : écrit statique, relu animé ; le lot vivant reste animé.
	var source := dest.path_join("source_du_cache.glb")
	DirAccess.copy_absolute(glb, source)
	_dire(Projet.mettre_en_cache(lot, source) == "", "le lot animé se met en cache")
	_dire(_animes(lot, a) == animes, "le lot vivant est resté animé")
	var brut := ResourceLoader.load(Projet.chemin_cache(source), "", ResourceLoader.CACHE_MODE_IGNORE) as MeshLibrary
	_dire(brut != null and not Anim.lot_anime(brut), "le cache est écrit STATIQUE (pas de shader ni de tableaux dedans)")
	var relu: Dictionary = Projet.lire_cache(source)
	_dire(relu.get("lot") != null and _animes(relu["lot"], a) == animes, "relu, il redevient animé")
	# Le .mbset : statique, les images par leur seul nom.
	var r: Dictionary = FN.exporter(lot, dest, "lava", "test")
	_dire(not r.has("erreur"), "le .mbset s'écrit (%s)" % str(r.get("erreur", "")))
	var js2 := _json_du_glb(dest.path_join("lava.mbset/tiles.glb"))
	var dans: Dictionary = {}
	for x in js2.get("materials", []):
		if str(x.get("name", "")) == "lava":
			dans = x
	var ex2: Dictionary = (dans.get("extras", {}) as Dictionary).get("mb_animation", {})
	_dire((dans.get("pbrMetallicRoughness", {}) as Dictionary).has("baseColorTexture")
		and ex2.get("albedo", {}).get("images", {}).get("images", []) == ["lava_0000.png", "lava_0001.png",
		"lava_0002.png", "lava_0003.png"], "tiles.glb : un matériau standard, ses images nommées sans chemin : %s"
		% JSON.stringify(ex2).left(160))
	# Relu comme témoin (le retour de Blender) : l'animation revient ; et sans extras, elle est reprise par le nom.
	var relu_t: RefCounted = TL.depuis_glb(glb, dest.path_join("retour"))
	var m_lu: Dictionary = {}
	if relu_t != null:
		for x in relu_t.materiaux:
			if str(x.get("nom", "")) == "lava":
				m_lu = x
	_dire(Anim.normaliser(m_lu.get("animation")) == Anim.normaliser(a), "relu d'un .glb, le témoin garde l'animation")
	if relu_t != null:
		for x in relu_t.materiaux:
			x.erase("animation")
		_dire(relu_t.reprendre_les_reglages(t) >= 1 and Anim.normaliser(m_lu.get("animation")) == Anim.normaliser(a),
			"sans extras (Blender ne les rend pas toujours), elle est reprise du témoin d'avant par le nom")


func _animes(lot: MeshLibrary, a: Dictionary) -> int:
	var n := 0
	if lot == null:
		return 0
	for id in lot.get_item_list():
		var mesh: Mesh = lot.get_item_mesh(id)
		for s in mesh.get_surface_count():
			var mt: Material = mesh.surface_get_material(s)
			if mt is ShaderMaterial and mt.has_meta("repli") and mt.get_meta("animation") == Anim.normaliser(a):
				n += 1
	return n


func _json_du_glb(chemin: String) -> Dictionary:
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		return {}
	f.seek(12)
	var longueur := f.get_32()
	f.get_32()
	var lu: Variant = JSON.parse_string(f.get_buffer(longueur).get_string_from_utf8())
	return lu if lu is Dictionary else {}
