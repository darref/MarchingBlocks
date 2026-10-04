extends SceneTree
##
## LE PREMIER TOURNAGE D'ESSAI — la playlist MarchingBlocks (D:/SpannerGames/PROJETS/MarchingBlocks/CLAUDE.md) se
## filme ENTIÈREMENT par script (Jordan, 4 octobre 2026) : `--write-movie` à pas de temps fixe, caméra et gestes
## scriptés qui appellent les VRAIS outils de l'appli — jamais une animation truquée. Sur l'EXEMPLE livré, installé
## dans un dossier À LUI (jamais la copie de l'utilisateur).
##
## LANCEMENT — ⚠ AVEC FENÊTRE (le headless ne rend rien) :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks --resolution 1920x1080 --fixed-fps 30 \
##       --write-movie D:/SpannerGames/PROJETS/MarchingBlocks/02_rushes/essai.avi \
##       --script res://DEV_TOOLS/filmer_essai.gd
##
## Chaque plan écrit son image de départ (« PLAN <nom> image <n> ») : à 30 images/s, la seconde du rush est n / 30.
## ⚠ Les réglages sont copiés sur le disque avant d'être touchés et rendus à la fin (comme sonde_lags_edition.gd).

const Exemple := preload("res://app/exemple.gd")
const REGLAGES := "user://reglages.cfg"
const DOSSIER := "user://filmer_essai"
const SAUVEGARDE := "user://reglages.cfg.avant_filmer"
const FPS := 30.0
var _ecran: Control
var _chemin := ""
var _image := 0


func _initialize() -> void:
	# ⚠ L'IMAGE SORT EN 1600 × 900, la taille du projet (`window/size/viewport_*`) : ni `--resolution` ni
	# `window_set_size` ici ne la changent (mesuré le 5 octobre 2026) — le Movie Maker la fixe avant ce script.
	if FileAccess.file_exists(SAUVEGARDE):
		DirAccess.copy_absolute(SAUVEGARDE, REGLAGES)
	if FileAccess.file_exists(REGLAGES):
		DirAccess.copy_absolute(REGLAGES, SAUVEGARDE)
	# ⚠ L'EXEMPLE INSTALLÉ S'ENREGISTRE À CHAQUE GESTE : la colline d'un tournage précédent y restait (vue au
	# plan 2 du troisième essai). Il se réinstalle neuf à chaque tournage.
	_vider(DOSSIER)
	var erreurs: Array = []
	_chemin = Exemple.installer(Exemple.ARCHIVE, DOSSIER, erreurs)
	if _chemin == "":
		print("⚠ l'exemple ne s'installe pas : %s" % [erreurs])
		_rendre_les_reglages()
		quit(1)
		return
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", _chemin)
	r.save(REGLAGES)
	load("res://app/editor.gd").racine_exemple = DOSSIER
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	_derouler.call_deferred()


func _derouler() -> void:
	await _images(30)
	var ok: bool = await _ecran._ouvrir(_chemin)
	print("ouverture de l'exemple : %s" % ok)
	_ecran._changer_d_atelier("monde")
	# Le bandeau « Where is it from? » se replie avant de filmer (Jordan, 5 octobre 2026) : il couvrait le haut de la vue.
	_ecran._legende_formes.basculer(false, false)
	# On peint sur l'herbe : la roche grise ne montre aucun relief à l'image.
	for i in _ecran._couches.size():
		if str(_ecran._couches[i].get("nom", "")) == "Grass":
			_ecran._activer(i)
	await _images(60)   # le chargement se jette au montage
	var vue = _ecran._vue
	vue.cadrer_toute_la_matiere()
	var loin: float = vue._distance
	var centre: Vector3 = vue._cible

	# PLAN 1 — L'ORBITE : le monde entier tourne lentement sous l'œil (8 s).
	_plan("orbite")
	var az0: float = vue._azimut
	vue._elevation = 0.5
	for i in int(8 * FPS):
		vue._azimut = az0 + 0.7 * _doux(i / (8 * FPS))
		vue._caler()
		await _images(1)

	# LA NOUVELLE ÎLE : à côté du monde, dans la mer — elle sortira de l'eau au plan 3.
	var boite: Dictionary = preload("res://addons/marchingblocks_core/fluides.gd").boite(_ecran._occupees_du_monde())
	var lo: Vector3i = boite["lo"]
	var ile := Vector3i(int(centre.x), lo.y, lo.z - 14)
	var sommet := Vector3(ile) + Vector3(0.5, 8.0, 0.5)
	var monde_vu := centre

	# PLAN 2 — LE RECUL : de tout près du sommet jusqu'au monde entier (7 s).
	_plan("recul")
	var az1: float = vue._azimut
	for i in int(7 * FPS):
		var t := _doux(i / (7 * FPS))
		vue._cible = Vector3(ile).lerp(monde_vu, t)
		vue._distance = lerpf(6.0, loin, t * t)
		vue._elevation = lerpf(0.35, 0.6, t)
		vue._azimut = az1 + 0.3 * t
		vue._caler()
		await _images(1)

	# PLAN 3 — LA PEINTURE : une colline posée rangée après rangée, en un seul coup de pinceau (Add).
	_plan("peinture")
	_ecran._choisir_outil("ajouter")
	vue._cible = Vector3(ile) + Vector3(0.5, 3.0, 0.5)
	vue._distance = 30.0
	vue._elevation = 0.55
	vue._caler()
	await _images(15)
	_ecran._coup_commence()
	for etage in 9:
		var rayon := 9 - etage
		for x in range(-rayon, rayon + 1):
			var rangee := {}
			for z in range(-rayon, rayon + 1):
				if x * x + z * z <= rayon * rayon:
					rangee[ile + Vector3i(x, etage, z)] = true
			_ecran._touche({"poser": rangee, "effacer": {}}, "Add")
			vue._azimut += 0.004
			vue._caler()
			await _images(1)
	_ecran._coup_fini()
	await _images(int(1.5 * FPS))

	# PLAN 4 — LE PLAY TEST : le personnage apparaît sur la colline et part en marchant (6 s).
	_plan("play_test")
	vue._cible = sommet + Vector3(0, 2, 0)
	_ecran._aller_a("jeu")
	# La caméra recule : à la distance du jeu, le personnage remplissait l'image.
	vue._distance = 7.0
	vue._elevation = 0.35
	vue._caler()
	await _images(int(1.5 * FPS))
	# Il fait le tour du sommet en marchant (la caméra tourne, il la suit) : tout droit, il finissait dans l'eau.
	_touche(KEY_W, true)
	for i in int(3 * FPS):
		vue._azimut += 0.025
		await _images(1)
	_touche(KEY_W, false)
	_touche(KEY_SPACE, true)
	await _images(8)
	_touche(KEY_SPACE, false)
	await _images(int(1 * FPS))
	_touche(KEY_ESCAPE, true)
	_touche(KEY_ESCAPE, false)
	await _images(5)

	_plan("fin")
	_ecran._histoire.undo()   # la colline ne reste pas dans l'exemple installé
	_rendre_les_reglages()
	quit(0)


func _vider(chemin: String) -> void:
	if not DirAccess.dir_exists_absolute(chemin):
		return
	for d in DirAccess.get_directories_at(chemin):
		_vider(chemin.path_join(d))
	for f in DirAccess.get_files_at(chemin):
		DirAccess.remove_absolute(chemin.path_join(f))
	DirAccess.remove_absolute(chemin)


## Lisse un passage de 0 à 1 : la caméra démarre et s'arrête sans à-coup.
func _doux(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _plan(nom: String) -> void:
	print("PLAN %s image %d (%.2f s)" % [nom, _image, _image / FPS])


func _images(n: int) -> void:
	for i in n:
		await process_frame
		_image += 1


func _touche(touche: Key, appuyee: bool) -> void:
	Input.flush_buffered_events()
	var e := InputEventKey.new()
	e.physical_keycode = touche
	e.keycode = touche
	e.pressed = appuyee
	Input.parse_input_event(e)


func _rendre_les_reglages() -> void:
	if FileAccess.file_exists(SAUVEGARDE):
		DirAccess.copy_absolute(SAUVEGARDE, REGLAGES)
		DirAccess.remove_absolute(SAUVEGARDE)
