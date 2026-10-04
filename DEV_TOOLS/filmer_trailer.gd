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
const Projet := preload("res://app/projet.gd")
const REGLAGES := "user://reglages.cfg"
const DOSSIER := "user://filmer_trailer"
const SAUVEGARDE := "user://reglages.cfg.avant_filmer"
const FPS := 30.0

## L'ÎLE — une règle, un endroit : tous les lieux du monde filmé.
const MER := 5                            # le niveau de la mer
const RAYON := 34.0                       # le rayon de l'île
const VOLCAN := Vector2i(15, -13)
const LAC := Vector2i(-12, 6)             # le lac du plateau
const PLATEAU := 17                       # le bord du lac
const CHENAL_X := -12                     # le chenal part du lac vers le nord (z croissant)
const BOUCHON := [12, 13]                 # les z du bouchon de roche qui retient le lac
const MARAIS := Vector2i(14, 15)

var _ecran: Control
var _vue
var _chemin := ""
var _image := 0
var _bruit := FastNoiseLite.new()
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

	await _construire()
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


# ── LA CONSTRUCTION DE L'ÎLE ─────────────────────────────────────────────────────────────────────────

func _construire() -> void:
	var t0 := Time.get_ticks_msec()
	# Vider l'exemple : ses cases, puis ses eaux.
	for nom in _couche:
		_ecran._activer(_couche[nom])
		var occ: Dictionary = _ecran._occupees()
		if not occ.is_empty():
			_ecran._appliquer({"poser": {}, "effacer": occ}, "Dig")
	while not _ecran._eaux.is_empty():
		_ecran._retirer_eau(_ecran._eaux[0])
	await _images(2)

	_bruit.seed = 7
	_bruit.frequency = 0.045
	_bruit.fractal_octaves = 4
	var par_couche := {"GreyRock": {}, "Grass": {}, "Desert": {}}
	var n := int(RAYON) + 4
	for x in range(-n, n + 1):
		for z in range(-n, n + 1):
			var h := _hauteur(x, z)
			if h < 0:
				continue
			var dessus := _dessus(x, z, h)
			for y in range(0, h + 1):
				var nom := "GreyRock"
				if y > h - (2 if dessus == "Desert" else 1):
					nom = dessus
				par_couche[nom][Vector3i(x, y, z)] = true
	for nom in par_couche:
		_ecran._activer(_couche[nom])
		_ecran._appliquer({"poser": par_couche[nom], "effacer": {}}, "Add")
		print("couche %s : %d cases" % [nom, par_couche[nom].size()])
	# Les contacts diagonaux qui resteraient : le vrai bouton « Fix diagonal contacts · Fill », dans la roche.
	_ecran._activer(_couche["GreyRock"])
	_ecran._reparer_les_diagonales(false)
	await _images(2)

	# L'EAU, par le vrai clic de l'atelier Fluids : la mer (épinglée puis posée), le lac, le marais, la lave.
	_ecran._changer_d_atelier("fluides")
	var large := Vector3i(int(RAYON) + 3, MER, 0)
	_ecran._eau_cliquee(large, MOUSE_BUTTON_LEFT)
	_ecran._eau_cliquee(large, MOUSE_BUTTON_LEFT)
	_ecran._eaux[_ecran._eau_active]["preset"] = "transparent"
	_ecran._eau_cliquee(Vector3i(LAC.x, PLATEAU - 2, LAC.y), MOUSE_BUTTON_LEFT)
	_nouvelle_eau("Swamp", "marais")
	_ecran._eau_cliquee(Vector3i(MARAIS.x, MER + 1, MARAIS.y), MOUSE_BUTTON_LEFT)
	_nouvelle_eau("Lava", "lave")
	_ecran._eau_cliquee(Vector3i(VOLCAN.x, 26, VOLCAN.y), MOUSE_BUTTON_LEFT)
	for e in _ecran._eaux:
		print("eau %s (%s) : %d sources" % [e["nom"], e["preset"], (e["sources"] as Array).size()])
	await _ecran._recalculer_eau(false)
	_ecran._changer_d_atelier("monde")
	_ecran._legende_formes.basculer(false, false)
	print("l'île est construite en %d ms" % (Time.get_ticks_msec() - t0))


func _nouvelle_eau(nom: String, preset: String) -> void:
	var etat := Projet.couche_d_eau(nom)
	etat["preset"] = preset
	_ecran._ajouter_eau(etat)


## La hauteur du dessus de la colonne (x, z) ; -1 : pas de terre.
func _hauteur(x: int, z: int) -> int:
	var p := Vector2(x, z)
	var b := _bruit.get_noise_2d(x, z)
	var r := p.length() / RAYON + b * 0.12
	if r > 1.0:
		return -1
	var h := pow(1.0 - r, 0.7) * 16.0 + b * 4.0
	# Le nord du chenal finit en FALAISE au-dessus de la mer : la cascade y tombe.
	if absf(x - CHENAL_X) < 9 and z > 10 and r < 0.97:
		h = maxf(h, 11.0 + b * 2.0)
	# Le volcan, et son cratère.
	var dv := p.distance_to(Vector2(VOLCAN))
	if dv < 11.0:
		h = maxf(h, 31.0 * pow(1.0 - dv / 11.0, 0.9) + 4.0)
		if dv < 3.2:
			h = 25.0
		elif dv < 4.2:
			# ⚠ UNE LÈVRE CONTINUE (marchingblocks-76, 5 octobre 2026) : sans elle, huit cases isolées à 26 se
			# touchaient par une arête — des contacts diagonaux, et leurs cubes rouges au bord du cratère.
			h = maxf(h, 27.0)
	# Le plateau du lac : un bord à PLATEAU, une cuvette au milieu.
	var dl := p.distance_to(Vector2(LAC))
	if dl < 10.0:
		var plat := lerpf(float(PLATEAU), h, clampf((dl - 7.5) / 2.5, 0.0, 1.0))
		h = maxf(h, plat) if dl >= 7.5 else float(PLATEAU)
		if dl < 5.0:
			h = PLATEAU - 4
	# Le chenal : du bord du lac vers le nord, en pente douce ; le BOUCHON reste plein (on l'ouvrira au plan 4).
	if absi(x - CHENAL_X) <= 1 and z > LAC.y + 4 and z < 34:
		if not BOUCHON.has(z):
			h = minf(h, lerpf(float(PLATEAU - 4), 9.0, clampf((z - 10) / 18.0, 0.0, 1.0)))
	# Le marais : une cuvette basse, bordée.
	var dm := p.distance_to(Vector2(MARAIS))
	if dm < 6.5:
		h = MER + 3 if dm >= 4.5 else MER
	return int(round(h))


## La couche du dessus : la plage au ras de l'eau, la roche sur le volcan et les pentes raides, l'herbe ailleurs.
func _dessus(x: int, z: int, h: int) -> String:
	if Vector2(x, z).distance_to(Vector2(VOLCAN)) < 11.0:
		return "GreyRock"
	if h <= MER + 1:
		return "Desert"
	var pente := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var hv := _hauteur(x + d.x, z + d.y)
		pente = maxi(pente, absi(h - hv) if hv >= 0 else h)
	return "GreyRock" if pente >= 4 else "Grass"


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
