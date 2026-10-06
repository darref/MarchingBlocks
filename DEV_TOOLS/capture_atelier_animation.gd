extends SceneTree
## CAPTURE — l'atelier Animation, MarchingBlocks ouvert pour de vrai (6 octobre 2026). AVEC FENÊTRE.
##
## LANCEMENT (dans une COPIE à dossier de données isolé : `config/use_custom_user_dir`, l'appli réécrit reglages.cfg)
##   Godot_v4.7-stable_win64_console.exe --path <copie> --script res://DEV_TOOLS/capture_atelier_animation.gd
##
## Toutes les faces du dessus du témoin reçoivent un matériau dont la couleur de base défile et dont l'émission joue
## quatre images de bandes ; on photographie l'atelier, puis la même vue un peu plus tard (l'image a changé), puis
## Texturing avec la rangée Frame. Les photos vont dans user://capture_animation_app/.

const Projet := preload("res://app/projet.gd")
const Anim := preload("res://addons/marchingblocks_core/animation_materiau.gd")
const JETABLE := "user://capture_anim/capture.mbproj"

var _ecran: Control
var _dossier := ""


func _initialize() -> void:
	_dossier = ProjectSettings.globalize_path("user://capture_animation_app")
	DirAccess.make_dir_recursive_absolute(_dossier)
	DirAccess.make_dir_recursive_absolute("user://capture_anim")
	var f := FileAccess.open(JETABLE, FileAccess.WRITE)
	f.store_string(Projet.vers_texte([Projet.couche("Rock")], 0))
	f.close()
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", JETABLE)
	r.save("user://reglages.cfg")
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	_derouler()


func _derouler() -> void:
	await _images(20)
	_ecran._aller_a("texture")
	_ecran._regler_edition(true)
	await _images(5)
	var mo = _ecran._modeleur
	var k: int = mo.nouveau_materiau()
	mo.regler_materiau(k, "couleur", Color.WHITE)
	# Les faces du dessus de TOUTES les tuiles (le matériau est partagé par le témoin).
	for c in mo.temoin.tuiles:
		var tuile: RefCounted = mo.temoin.tuiles[c]
		var dessus: Array = []
		for face in tuile.faces.size():
			if tuile.normale(face).y > 0.9:
				dessus.append(face)
		tuile.assigner(dessus, k)
	mo.redessiner()
	mo._rafraichir_les_tuiles_qui_portent(-2)
	# Une couleur de base à damier qui défile, une émission de quatre images de bandes qui avancent.
	var damier := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			damier.set_pixel(x, y, Color(0.25, 0.45, 0.3) if ((x / 16) + (y / 16)) % 2 == 0 else Color(0.15, 0.3, 0.2))
	var bandes: Array = []
	for i in 4:
		var b := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		b.fill(Color.BLACK)
		b.fill_rect(Rect2i(0, i * 16, 64, 6), Color(0.2, 1.0, 0.9))
		bandes.append(b)
	var dossier := ProjectSettings.globalize_path("user://capture_anim/images")
	var a := Anim.ajouter({}, "albedo", "images", {"images": Anim._ecrire([damier], dossier, "damier")["images"]})
	a = Anim.ajouter(a, "albedo", "defilement", {"u": 0.0, "v": -0.3})
	a = Anim.ajouter(a, "emission", "images", {"images": Anim._ecrire(bandes, dossier, "bandes")["images"], "ips": 4.0})
	a = Anim.ajouter(a, "emission", "pulsation", {"frequence": 0.5, "mini": 0.3})
	mo.materiau_courant = k
	_ecran._aller_a("anim")
	_ecran._animation.poser(a)
	_ecran._vue._distance = 22.0
	_ecran._vue.cadrer(Vector3(6, 8, 6))
	await _images(30)
	_photo("1_atelier")
	await _images(25)
	_photo("2_plus_tard")
	_ecran._aller_a("texture")
	_ecran._bouton_pinceau.button_pressed = true
	_ecran._animation.redire_la_peinture()
	await _images(10)
	_photo("3_texturing_frame")
	quit(0)


func _images(n: int) -> void:
	for i in n:
		await process_frame


func _photo(nom: String) -> void:
	var img: Image = root.get_texture().get_image()
	var chemin: String = _dossier.path_join(nom + ".png")
	img.save_png(chemin)
	print("%s → %s" % [nom, chemin])
