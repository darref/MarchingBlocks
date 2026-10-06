extends SceneTree
## L'ATELIER FOLIAGE, PHOTOGRAPHIÉ (6 octobre 2026) — un plateau habillé du témoin, une butte, l'arbre d'essai planté
## au pinceau en voisinage libre, puis en débordement ; deux photos à une demi-seconde d'écart (le vent bouge les
## couronnes), le socle, et le fantôme refusé au bord.
##
## LANCEMENT — ⚠ AVEC FENÊTRE :
##   xvfb-run -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --path . \
##       --script res://DEV_TOOLS/capture_feuillage.gd -- --dossier=/tmp/captures
## ⚠ Comme `capture_app.gd` : un projet jetable, et `reglages.cfg` rendu tel quel à la fin.

const Projet := preload("res://app/projet.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const Arbre := preload("res://DEV_TOOLS/arbre_d_essai.gd")
const REGLAGES := "user://reglages.cfg"
const JETABLE := "user://capture/feuillage.mbproj"

var _dossier := "D:/MarchingBlocks/ART/app"
var _ecran: Control
var _reglages_avant := ""


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--dossier="):
			_dossier = option.substr("--dossier=".length())
	DirAccess.make_dir_recursive_absolute(_dossier)
	if FileAccess.file_exists(REGLAGES):
		_reglages_avant = FileAccess.get_file_as_string(REGLAGES)
	DirAccess.make_dir_recursive_absolute("user://capture")
	var f := FileAccess.open(JETABLE, FileAccess.WRITE)
	f.store_string(Projet.vers_texte([Projet.couche("Rock")], 0))
	f.close()
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", JETABLE)
	r.save(REGLAGES)
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	_derouler()


func _derouler() -> void:
	await _images(20)
	var e := _ecran
	e._aller_a("monde")
	var sol := {}
	for x in range(0, 16):
		for z in range(0, 16):
			sol[Vector3i(x, 0, z)] = true
			if x >= 10 and z >= 10:
				sol[Vector3i(x, 1, z)] = true
				sol[Vector3i(x, 2, z)] = true
	e._coup_commence()
	e._touche({"poser": sol, "effacer": {}}, "Add")
	e._coup_fini()
	e._vue.monde().lot = BM.librairie()["lot"]
	e._aller_a("feuillage")
	var glb := "user://capture/arbre.glb"
	Arbre.ecrire(glb)
	e._action_fichier = "feuillage"
	e._fichier_choisi(glb)
	var af: RefCounted = e._feuillage
	af.mode = "sol_libre"
	var monde: Dictionary = af.monde()
	var ix: Dictionary = af._ix
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var m: Dictionary = af.modeles[0]
	var r: Dictionary = af.FE.semer(m, Vector3(7, 4, 7), 9.0, 300, "sol_libre", monde, ix, af._par_id(), rng)
	for pl in r["plants"]:
		af.plants.append(pl)
	af._tout_redessiner()
	print("plants : %d (refus %s)" % [af.plants.size(), r["refus"]])
	var vue = e._vue
	vue._cible = Vector3(8.0, 1.5, 8.0)
	vue._azimut = 0.7
	vue._elevation = 0.45
	vue._distance = 22.0
	vue._caler()
	await _images(30)
	_photo("feuillage_1_libre")
	await create_timer(0.6).timeout
	_photo("feuillage_2_vent")
	# De près, au ras du sol.
	vue._cible = Vector3(6.0, 1.5, 6.0)
	vue._distance = 9.0
	vue._elevation = 0.2
	vue._caler()
	await _images(10)
	_photo("feuillage_3_pres")
	# Le fantôme refusé au bord du plateau.
	var ou: Vector2 = vue._camera.unproject_position(Vector3(0.3, 1.0, 6.0))
	af.survoler(ou)
	await _images(5)
	_photo("feuillage_4_fantome")
	# Le socle, de près : la barre de droite.
	af._remplir_reglages()
	await _images(10)
	var img := root.get_texture().get_image()
	var socle: Control = af.socle
	var rect := Rect2i(socle.get_global_rect())
	if rect.size.x > 0 and rect.size.y > 0:
		var morceau := img.get_region(rect)
		morceau.save_png(_dossier.path_join("feuillage_5_socle.png"))
		print("socle → %s" % rect)
	if _reglages_avant != "":
		var g := FileAccess.open(REGLAGES, FileAccess.WRITE)
		g.store_string(_reglages_avant)
		g.close()
	quit(0)


func _images(n: int) -> void:
	for i in n:
		await process_frame


func _photo(nom: String) -> void:
	var img := root.get_texture().get_image()
	var chemin := _dossier.path_join(nom + ".png")
	var err := img.save_png(chemin)
	print("%s → %s" % [nom, chemin if err == OK else "ÉCHEC %d" % err])
