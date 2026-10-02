extends SceneTree
## CAPTURE — la peinture du témoin, AVEC FENÊTRE (le headless ne garde pas les mises à jour de texture).
##   godot --path D:/MarchingBlocks --script res://DEV_TOOLS/capture_peinture.gd -- [--dossier=…]
## Un matériau uni sur tous les dessus du témoin, puis des traits de pinceau menés à la souris sur ce qu'on voit.
## Projet JETABLE ; réglages rendus à la fin.

const Projet := preload("res://app/projet.gd")
const REGLAGES := "user://reglages.cfg"
const JETABLE := "user://capture_peinture/capture.mbproj"
var _dossier := "D:/MarchingBlocks/ART/peinture"
var _reglages_avant := ""
var _ecran: Control


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--dossier="):
			_dossier = option.substr("--dossier=".length())
	DirAccess.make_dir_recursive_absolute(_dossier)
	if FileAccess.file_exists(REGLAGES):
		_reglages_avant = FileAccess.get_file_as_string(REGLAGES)
	var dossier := ProjectSettings.globalize_path("user://capture_peinture")
	DirAccess.make_dir_recursive_absolute(dossier)
	for nom in DirAccess.get_files_at(dossier):
		DirAccess.remove_absolute(dossier.path_join(nom))
	var f := FileAccess.open(JETABLE, FileAccess.WRITE)
	f.store_string(Projet.vers_texte([Projet.couche("Rock")], 0))
	f.close()
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", JETABLE)
	r.save(REGLAGES)
	root.size = Vector2i(1600, 900)
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	_derouler()


func _derouler() -> void:
	await _images(30)
	_ecran._aller_a("texture")
	_ecran._regler_edition(true)
	await _images(5)
	var mo = _ecran._modeleur
	var t: RefCounted = mo.temoin
	# Un matériau uni, vert mousse, sur tous les DESSUS de toutes les tuiles.
	var k: int = mo.nouveau_materiau()
	mo.regler_materiau(k, "couleur", Color(0.42, 0.62, 0.38))
	mo.regler_materiau(k, "echelle", 2.0)   # une image pour deux cases : le dessin se lit
	for cle in t.tuiles:
		var tuile: RefCounted = t.tuiles[cle]
		var dessus: Array = []
		for face in tuile.faces.size():
			if tuile.normale(face).y > 0.9:
				dessus.append(face)
		tuile.assigner(dessus, k)
	mo.redessiner()
	mo._rafraichir_les_tuiles_qui_portent(-2)
	_ecran._vue._distance = 18.0
	_ecran._vue.cadrer(Vector3(6, 9, 6))
	await _images(10)
	_photo("0_avant")
	# Le pinceau, et des traits menés à la souris sur ce que le rayon voit.
	_ecran._bouton_pinceau.button_pressed = true
	var taille: Vector2 = _ecran._vue.size
	for trait_ in [[Color(0.85, 0.2, 0.15), 18.0, 0.3], [Color(0.95, 0.85, 0.3), 10.0, 0.8], [Color(0.2, 0.3, 0.9), 30.0, 0.0]]:
		mo.pinceau_couleur = trait_[0]
		mo.pinceau_taille = trait_[1]
		mo.pinceau_durete = trait_[2]
		var y0 := randf_range(0.35, 0.65) * taille.y
		var points: Array = []
		for i in 40:
			points.append(Vector2(lerpf(0.3, 0.7, i / 39.0) * taille.x, y0 + sin(i * 0.35) * 60.0))
		_souris(points[0], true)
		for p in points:
			var m := InputEventMouseMotion.new()
			m.position = p
			m.button_mask = MOUSE_BUTTON_MASK_LEFT
			mo.souris_entree(m)
		_souris(points[-1], false)
		await _images(3)
	await _images(10)
	_photo("1_peint")
	# L'ATLAS : le même matériau déplié dans toutes les tuiles ensemble, la toile remise à plat, puis les mêmes traits —
	# chaque tuile a sa place : rien ne se répète plus d'une tuile à l'autre (ses copies, elles, suivent).
	mo.materiau_courant = k
	mo.deplier_en_atlas()
	var chemin: String = t.materiaux[k]["texture"]
	var Peinture := load("res://addons/marchingblocks_core/peinture.gd")
	(Peinture.toile(chemin)["image"] as Image).fill(Color(0.42, 0.62, 0.38))
	Peinture.montrer(chemin)
	for trait_ in [[Color(0.85, 0.2, 0.15), 6.0, 0.3], [Color(0.95, 0.85, 0.3), 4.0, 0.8]]:
		mo.pinceau_couleur = trait_[0]
		mo.pinceau_taille = trait_[1]
		mo.pinceau_durete = trait_[2]
		var y1 := randf_range(0.4, 0.6) * taille.y
		var pts: Array = []
		for i in 40:
			pts.append(Vector2(lerpf(0.3, 0.7, i / 39.0) * taille.x, y1 + sin(i * 0.35) * 60.0))
		_souris(pts[0], true)
		for q in pts:
			var mm := InputEventMouseMotion.new()
			mm.position = q
			mm.button_mask = MOUSE_BUTTON_MASK_LEFT
			mo.souris_entree(mm)
		_souris(pts[-1], false)
		await _images(3)
	await _images(10)
	_photo("2_atlas")
	# LE CURSEUR ET LES BANDES DE COUTURE : de près, la souris au repos sur la matière, un gros pinceau mi-dur.
	_ecran._vue._distance = 7.0
	_ecran._vue.cadrer(Vector3(6, 9, 6))
	await _images(10)
	mo.pinceau_taille = 60.0
	mo.pinceau_durete = 0.5
	mo.pinceau_couleur = Color(0.95, 0.85, 0.3)
	var survol := InputEventMouseMotion.new()
	survol.position = taille * 0.5
	mo.souris_entree(survol)
	await _images(5)
	print("empreinte : %d points" % mo.empreinte_montree.size())
	_photo("3_curseur_et_bandes")
	# LES CALQUES ET LA GOMME : un calque neuf, un large trait bleu dessus, puis la gomme au milieu du trait — le
	# dessous revient là où l'on a gommé.
	var Peinture2 := load("res://addons/marchingblocks_core/peinture.gd")
	Peinture2.nouveau_calque(chemin, "Blue")
	mo.pinceau_couleur = Color(0.15, 0.3, 0.95)
	mo.pinceau_taille = 30.0
	mo.pinceau_durete = 0.8
	var bleu: Array = []
	for i in 40:
		bleu.append(Vector2(lerpf(0.25, 0.75, i / 39.0) * taille.x, 0.5 * taille.y))
	_souris(bleu[0], true)
	for q in bleu:
		var mb := InputEventMouseMotion.new()
		mb.position = q
		mb.button_mask = MOUSE_BUTTON_MASK_LEFT
		mo.souris_entree(mb)
	_souris(bleu[-1], false)
	mo.regler_gomme(true)
	_souris(taille * 0.5 + Vector2(-60, 0), true)
	for j in 20:
		var mg := InputEventMouseMotion.new()
		mg.position = taille * 0.5 + Vector2(lerpf(-60, 60, j / 19.0), 0)
		mg.button_mask = MOUSE_BUTTON_MASK_LEFT
		mo.souris_entree(mg)
	_souris(taille * 0.5 + Vector2(60, 0), false)
	mo.regler_gomme(false)
	await _images(10)
	_photo("4_calques_et_gomme")
	print("rapport : ", _ecran._rapport.text.substr(0, 160))
	if _reglages_avant != "":
		var f := FileAccess.open(REGLAGES, FileAccess.WRITE)
		f.store_string(_reglages_avant)
		f.close()
	quit(0)


func _souris(p: Vector2, appui: bool) -> void:
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = appui
	b.position = p
	_ecran._modeleur.souris_entree(b)


func _photo(nom: String) -> void:
	root.get_texture().get_image().save_png(_dossier.path_join(nom + ".png"))
	print("photo ", nom)


func _images(n: int) -> void:
	for k in n:
		await process_frame
