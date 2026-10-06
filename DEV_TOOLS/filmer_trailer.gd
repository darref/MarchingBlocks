extends SceneTree
##
## LE TOURNAGE DU TRAILER — la playlist MarchingBlocks (D:/SpannerGames/PROJETS/MarchingBlocks/CLAUDE.md) se filme
## ENTIÈREMENT par script (Jordan, 4 octobre 2026), dans un monde que le script CONSTRUIT lui-même (Jordan, 5 octobre
## 2026 : « tu fais tout toi-même et tu le rends diversifié, dynamique et stylé »). Chaque case est posée par les VRAIS
## gestes de l'appli (`_appliquer`, le pinceau, `_eau_cliquee`) : rien n'est truqué, l'image est celle du logiciel.
##
## On part de l'EXEMPLE livré (pour ses trois témoins : GreyRock, Grass, Desert), vidé, puis l'île : un volcan et son
## lac de lave, un plateau et son lac retenu par un bouchon de roche, un marais, des plages, la mer.
##
## LANCEMENT — dans la COPIE de tournage (1920 × 1080, données à part ; le dépôt et l'exe de Jordan n'y sont pour rien) :
##   cp D:/MarchingBlocks/DEV_TOOLS/filmer_trailer.gd D:/MarchingBlocks_tournage/DEV_TOOLS/
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks_tournage --fixed-fps 30 \
##       --write-movie D:/SpannerGames/PROJETS/MarchingBlocks/02_rushes/trailer.avi \
##       --script res://DEV_TOOLS/filmer_trailer.gd
## ⚠ Ne jamais l'interrompre : il rend les réglages à la fin.
## Chaque plan écrit son image de départ (« PLAN <nom> image <n> ») : à 30 images/s, la seconde du rush est n / 30.

const Exemple := preload("res://app/exemple.gd")
const REGLAGES := "user://reglages.cfg"
const DOSSIER := "user://filmer_trailer"
const SAUVEGARDE := "user://reglages.cfg.avant_filmer"
const FPS := 30.0

## L'ÎLE — ses lieux vivent dans `filmer_ile.gd` (une règle, un endroit).
const Ile := preload("res://DEV_TOOLS/filmer_ile.gd")
const MER := Ile.MER
const VOLCAN := Ile.VOLCAN
const LAC := Ile.LAC
const PLATEAU := Ile.PLATEAU
const CHENAL_X := Ile.CHENAL_X
const BOUCHON := Ile.BOUCHON
const MARAIS := Ile.MARAIS


var _ecran: Control
var _vue
var _chemin := ""
var _image := 0
var _couche := {}                         # nom → indice


func _initialize() -> void:
	if FileAccess.file_exists(SAUVEGARDE):
		DirAccess.copy_absolute(SAUVEGARDE, REGLAGES)
	if FileAccess.file_exists(REGLAGES):
		DirAccess.copy_absolute(REGLAGES, SAUVEGARDE)
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
	# Le bandeau « Where is it from? » se replie avant de filmer (Jordan, 5 octobre 2026).
	_ecran._legende_formes.basculer(false, false)
	_vue = _ecran._vue
	for i in _ecran._couches.size():
		_couche[str(_ecran._couches[i].get("nom", ""))] = i
	print("couches : %s" % [_couche])

	# ── PLAN 0 — L'ACCROCHE : UN bloc se sculpte en gros plan (le modeleur du témoin, une face extrudée à la
	# souris). « Sculpt one block. » Le geste est ANNULÉ à la fin : le témoin de l'exemple ne change pas, et
	# l'île se peint avec lui. ─────────────────────────────────────────────────────────────────────────────
	_ecran._activer(_couche["Grass"])
	_ecran._aller_a("witness")
	await _images(10)
	_ecran._regler_edition(true)
	await _images(10)
	var mo = _ecran._modeleur
	# Le bloc ENTIER à l'image (de trop près, on voyait un paysage, pas un bloc), puis la caméra s'approche.
	_poser_camera({"cible": Vector3(6, 6, 6), "azimut": 0.5, "elevation": 0.5, "distance": 27.0})
	await _images(5)
	var centre_vue: Vector2 = _vue.size * 0.5
	# Une PLAQUE de faces au milieu (une seule face extrudée ne se voyait pas).
	# La face sous le centre de la vue, puis ses voisines tournées vers le haut, tout près, au même niveau.
	# Un point du DESSUS herbeux (le centre de la vue tombait sur un mur).
	mo.cliquer(centre_vue + Vector2(-100, -120), false)
	if not mo.sel_f.is_empty():
		var f0: int = mo.sel_f.keys()[0]
		var c0: Vector3 = mo.maillage.centre(f0)
		print("accroche : face %d, centre %s, normale %s, %d faces" % [f0, c0, mo.maillage.normale(f0),
			mo.maillage.faces.size()])
		# ⚠ LE MODELEUR ÉDITE UNE TUILE (32 faces, coordonnées dans ±0,5) et TOUTES ses copies du bloc suivent :
		# on prend le DESSUS de la tuile cliquée, et chaque copie se soulève avec elle — c'est le plan.
		mo.tout_choisir(false)
		for f in mo.maillage.faces.size():
			if mo.maillage.normale(f).y > 0.7:
				mo.sel_f[f] = true
	print("accroche : %d faces choisies" % mo.sel_f.size())
	_plan("accroche")
	await _images(int(0.8 * FPS))
	mo.souris = centre_vue
	mo.commencer("E")
	var n := int(3.2 * FPS)
	for i in n:
		var t := _doux(float(i) / float(n - 1))
		mo.souris = centre_vue + Vector2(0, -60.0 * t)
		mo._mettre_a_jour()
		_vue._azimut = 0.5 + 0.6 * t
		_vue._distance = lerpf(27.0, 21.0, t)
		_vue._caler()
		await _images(1)
	await _images(int(0.8 * FPS))
	mo.annuler()
	_ecran._regler_edition(false)
	_ecran._aller_a("monde")
	_ecran._legende_formes.basculer(false, false)
	await _images(5)
	# `-- --seulement=accroche` : la mise au point du premier plan, sans tourner tout le reste.
	if OS.get_cmdline_user_args().has("--seulement=accroche"):
		_rendre_les_reglages()
		quit(0)
		return

	await Ile.new(self, _ecran, _couche).construire()
	await _images(30)

	# ── PLAN 1 — L'ÎLE ENTIÈRE, en orbite lente (8 s) ─────────────────────────────────────────────────
	_plan("orbite")
	await _mouvement(8.0,
		{"cible": Vector3(0, 8, 0), "azimut": 0.2, "elevation": 0.62, "distance": 95.0},
		{"cible": Vector3(0, 8, 0), "azimut": 1.1, "elevation": 0.5, "distance": 80.0})

	# ── PLAN 2 — LE VOLCAN : on frôle le cratère de lave (5 s) ───────────────────────────────────────
	_plan("volcan")
	var v := Vector3(VOLCAN.x, 27, VOLCAN.y)
	await _mouvement(5.0,
		{"cible": v, "azimut": 2.4, "elevation": 0.25, "distance": 34.0},
		{"cible": v, "azimut": 3.2, "elevation": 0.7, "distance": 16.0})

	# ── PLAN 3 — LE MARAIS (4 s) ─────────────────────────────────────────────────────────────────────
	_plan("marais")
	var m := Vector3(MARAIS.x, MER + 2, MARAIS.y)
	await _mouvement(4.0,
		{"cible": m, "azimut": -0.4, "elevation": 0.45, "distance": 22.0},
		{"cible": m, "azimut": 0.3, "elevation": 0.35, "distance": 16.0})

	# ── PLAN 4 — ON OUVRE LA FALAISE : Dig sur le bouchon, le lac se vide en rivière et tombe en cascade ──
	_plan("falaise")
	var bouchon := Vector3(CHENAL_X, PLATEAU - 1, BOUCHON[0])
	_poser_camera({"cible": bouchon + Vector3(0, 0, 6), "azimut": -2.3, "elevation": 0.42, "distance": 30.0})
	await _images(int(1.5 * FPS))
	_ecran._choisir_outil("creuser")
	var trou := {}
	for z in BOUCHON:
		for dx in [-1, 0, 1]:
			for y in range(PLATEAU - 3, PLATEAU + 1):
				trou[Vector3i(CHENAL_X + dx, y, z)] = true
	_ecran._activer(_couche["GreyRock"])
	_ecran._appliquer({"poser": {}, "effacer": trou}, "Dig")
	_ecran._activer(_couche["Grass"])
	_ecran._appliquer({"poser": {}, "effacer": trou}, "Dig")
	await _ecran._recalculer_eau(false)
	await _mouvement(5.0,
		{"cible": bouchon + Vector3(0, 0, 6), "azimut": -2.3, "elevation": 0.42, "distance": 30.0},
		{"cible": bouchon + Vector3(0, -6, 16), "azimut": -1.6, "elevation": 0.3, "distance": 34.0})

	# ── PLAN 5 — LA PEINTURE : une île neuve sort de la mer, rangée après rangée (Add, un seul coup) ──────
	_plan("peinture")
	_ecran._choisir_outil("ajouter")
	_ecran._activer(_couche["Grass"])
	var ile := Vector3i(-30, 0, -26)
	_poser_camera({"cible": Vector3(ile) + Vector3(0.5, 4, 0.5), "azimut": -0.9, "elevation": 0.5, "distance": 34.0})
	await _images(15)
	_ecran._coup_commence()
	for etage in 10:
		var rayon := 10 - etage
		for x in range(-rayon, rayon + 1):
			var rangee := {}
			for z in range(-rayon, rayon + 1):
				if x * x + z * z <= rayon * rayon:
					rangee[ile + Vector3i(x, etage, z)] = true
			_ecran._touche({"poser": rangee, "effacer": {}}, "Add")
			_vue._azimut += 0.004
			_vue._caler()
			await _images(1)
	_ecran._coup_fini()
	await _images(int(1.5 * FPS))

	# ── PLAN 6 — LE PLAY TEST : le personnage sur le plateau, au bord du lac (6 s) ──────────────────────
	_plan("play_test")
	_vue._cible = Vector3(LAC.x + 7, PLATEAU + 3, LAC.y - 4)
	_ecran._aller_a("jeu")
	await _images(int(1.0 * FPS))
	_touche(KEY_W, true)
	for i in int(4 * FPS):
		# ⚠ La caméra du jeu se recale : la distance et l'angle sont tenus à chaque image.
		# Plus haut (0,55) : à 0,3 le bras de la caméra rentrait contre le décor et collait au personnage.
		_vue._distance = 7.5
		_vue._elevation = 0.55
		_vue._azimut += 0.012
		await _images(1)
	_touche(KEY_W, false)
	for i in int(1 * FPS):
		_vue._distance = 7.5
		_vue._elevation = 0.55
		await _images(1)
	_touche(KEY_ESCAPE, true)
	_touche(KEY_ESCAPE, false)
	await _images(5)

	_plan("fin")
	_rendre_les_reglages()
	quit(0)


# ── LA CAMÉRA ────────────────────────────────────────────────────────────────────────────────────────

func _poser_camera(c: Dictionary) -> void:
	_vue._cible = c["cible"]
	_vue._azimut = c["azimut"]
	_vue._elevation = c["elevation"]
	_vue._distance = c["distance"]
	_vue._caler()


## Un mouvement de caméra lissé, de `a` vers `b`, en `duree` secondes.
func _mouvement(duree: float, a: Dictionary, b: Dictionary) -> void:
	var n := int(duree * FPS)
	for i in n:
		var t := _doux(float(i) / float(n - 1))
		_vue._cible = (a["cible"] as Vector3).lerp(b["cible"], t)
		_vue._azimut = lerpf(a["azimut"], b["azimut"], t)
		_vue._elevation = lerpf(a["elevation"], b["elevation"], t)
		_vue._distance = lerpf(a["distance"], b["distance"], t)
		_vue._caler()
		await _images(1)


func _doux(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# ── L'OUTILLAGE ──────────────────────────────────────────────────────────────────────────────────────

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


func _vider(chemin: String) -> void:
	if not DirAccess.dir_exists_absolute(chemin):
		return
	for d in DirAccess.get_directories_at(chemin):
		_vider(chemin.path_join(d))
	for f in DirAccess.get_files_at(chemin):
		DirAccess.remove_absolute(chemin.path_join(f))
	DirAccess.remove_absolute(chemin)


func _rendre_les_reglages() -> void:
	if FileAccess.file_exists(SAUVEGARDE):
		DirAccess.copy_absolute(SAUVEGARDE, REGLAGES)
		DirAccess.remove_absolute(SAUVEGARDE)
