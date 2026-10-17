extends "res://DEV_TOOLS/filmer_animation.gd"
##
## LE TRAILER FINAL — 60 s et 2 min, pour la page Steam et YouTube. Décision de Jordan (7 octobre 2026) : « le trailer
## final est construit par Claude, par script, maintenant » (plus le monde filmé à la souris en décembre). Le logiciel est
## gelé : on filme ce qu'il fait, rien d'autre.
##
## LA TRAME (validée par Jordan, charte de la playlist) : le geste (un bloc sculpté en gros plan) → la caméra recule, ce
## bloc est devenu une île → on peint (couches, formes, arbres, transitions) → le monde vit (cascade, lave, rivière) →
## le Play test au soleil (marcher, nager, voler, météo) → le carton. Ni visage, ni voix : le produit et la musique.
##
## ⚠ RIEN N'EST DESSINÉ PAR-DESSUS L'APPLI : ni curseur, ni carte de touche (les aides des devlogs). L'image est celle du
## logiciel, seule. Chaque geste passe par les VRAIS outils (`_appliquer`, le pinceau à la souris, `_eau_cliquee`, les
## boutons, l'import de l'atelier Foliage, le modeleur) — la règle « le média vient du vrai produit ».
##
## On HÉRITE des tournages précédents : l'île de `filmer_ile.gd` (volcan, lac retenu, marais), les gestes de
## `filmer_ui.gd`, le pilotage du stickman de `filmer_haut.gd`, le vol de `filmer_feuillage.gd` (refait ici, sur l'île),
## et la station animée de `filmer_animation.gd` (partie « station », dans un projet À NOUS).
##
## LANCEMENT — dans la COPIE de tournage D:/SpannerGames/ATELIER/MarchingBlocks/worktrees/MB_tournage_trailer (1920 × 1080, `custom_user_dir_name="MB_tournage_trailer"`) :
##   cp D:/MarchingBlocks/DEV_TOOLS/filmer_trailer_final.gd D:/SpannerGames/ATELIER/MarchingBlocks/worktrees/MB_tournage_trailer/DEV_TOOLS/
##   Godot_v4.7-stable_win64_console.exe --path D:/SpannerGames/ATELIER/MarchingBlocks/worktrees/MB_tournage_trailer --fixed-fps 30 \
##       --write-movie D:/SpannerGames/PROJETS/MarchingBlocks/02_rushes/trailer_final_ile.avi \
##       --script res://DEV_TOOLS/filmer_trailer_final.gd -- --partie=ile
##   `--partie=` : ile (tout le monde de l'île, d'une traite), station (la station animée), carte (le relief en PNG).
##   `--sans=jeu,…` : sauter des parties de l'île (mise au point).
## ⚠ Ne jamais l'interrompre : il rend les réglages à la fin (ceux de la copie : `custom_user_dir`).
##
## LES PRISES (7 octobre 2026), rushes dans SpannerGames/PROJETS/MarchingBlocks/02_rushes/trailer_final_*.avi :
##   ile2 (toute l'île, 186 s, ~40 min de calcul) — l'éditeur entier ; ile3 — la neige, le plan final ; jeu4, jeu5
##   (`--sans=accroche,recul,peindre,formes,transitions,riviere`) — la plage, la nage, le vol ; station — la station animée.
## ⚠ LE PLAY TEST SE FILME LÀ OÙ LA CAMÉRA NE BUTE PAS : en descendant un versant, le bras de la caméra rentre dans la
##   pente derrière lui (la tête remplit l'image) ; entre les arbres, elle traverse troncs et couronnes (pas de collision).
##   Le sable sec de la plage (dessus à MER + 1) et le vol, caméra haute (12 cases, élévation 0,5), sont propres.
## ⚠ LE VOL S'ARRÊTE NET à chaque prise (3, 4, 5 : 35 à 50 s immobile, W tenu ; en 4 et 5, x et z figés au centième) — d'où la parade « coincé »
##   de `_voler_t` (monter 1 s), qui NE SUFFIT PAS (prise 5 : il monte de 25 à 30, x et z restent figés). Les plans de vol
##   du trailer sont pris AVANT l'arrêt. **CAUSE TROUVÉE ET CORRIGÉE (7 octobre 2026)** : pas le personnage, le PILOTE.
##   Sous Windows, une autre application qui prend la main fait relâcher à Godot toutes les touches enfoncées ; W n'était
##   enfoncée qu'une fois pour tout le vol, Espace et A renvoyées à chaque image. `filmer_ui._process` renfonce désormais
##   chaque touche tenue (`test_pilote_tournage.gd`). Reproduit en headless sur ce tournage (W relâchée au milieu du vol :
##   x et z figés au millionième, y de 24,6 à 29,4 — la prise 5) ; avec la correction, il repart.

const FE_T := preload("res://addons/marchingblocks_core/feuillage.gd")
const SPIRIT_T := "D:/Spirit3D/HEART_WORLD/biomes/maps/"
const CARTE_T := "C:/Users/jorda/AppData/Local/Temp/claude/D--SpannerGames/d195078d-feff-463c-9e41-f90d432ceefa/scratchpad/tf/carte_ile.png"
## Les arbres : [fichier sous maps/, échelle, taille au hasard, vent] — modèles Tripo (IA) de Spirit Heart World, LUS.
const ARBRES_T := {
	"chene": ["biome_plains/obstacles/plains_tree_01/plains_tree_01.glb", 4.5, 0.3, 0.8],
	"pin": ["biome_woodland/obstacles/woodland_tree_02/woodland_tree_02.glb", 6.0, 0.3, 0.6],
	"palmier": ["biome_desert/resources/obstacles/palm+tree+3d+model_Clone1.glb", 5.5, 0.25, 0.9],
}
## L'île qui sort de la mer (plan « peindre ») : son centre, son rayon.
const NEUVE := Vector3i(-30, 0, -26)
const NEUVE_R := 10
const TF_SOLEIL := 20.0         # l'azimut du soleil au Play test (200 dans les devlogs, où l'on regardait au nord)

var _partie := "ile"
var _sans: Array = []
var _af_t: RefCounted
var _construite := false
var _derniere_pos_t := Vector3.ZERO
var _montee_t := 0
var _hauteur_peinte := {}          # Vector2i → dessus peint par le script après la construction (l'île neuve)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--partie="):
			_partie = a.substr("--partie=".length())
		if a.begins_with("--sans="):
			_sans = a.substr("--sans=".length()).split(",")
		if a.begins_with("--seulement="):
			_seulement = a.substr("--seulement=".length())
	if _partie == "station":
		# La station de `filmer_animation.gd` : son projet neuf, à nous, dans les données de la copie.
		super._initialize()
		return
	# L'île : l'exemple livré, installé à part (comme `filmer_ui._initialize`).
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
	Input.use_accumulated_input = false
	_derouler.call_deferred()


## Rien par-dessus l'appli : ni curseur ni carte de touche.
func _dessiner() -> void:
	pass


func _derouler() -> void:
	if _partie == "station":
		await _derouler_station()
		return
	await _images(30)
	var ok: bool = await _ecran._ouvrir(_chemin)
	print("ouverture de l'exemple : %s" % ok)
	_ecran._changer_d_atelier("monde")
	_ecran._legende_formes.basculer(false, false)
	_vue = _ecran._vue
	_af_t = _ecran._feuillage
	_cam_haut = false
	for i in _ecran._couches.size():
		_couche[str(_ecran._couches[i].get("nom", ""))] = i
	print("couches : %s" % [_couche])
	_aides()
	_ile = Ile.new(self, _ecran, _couche)
	if _partie == "carte":
		_ile._bruit.seed = 7
		_ile._bruit.frequency = 0.045
		_ile._bruit.fractal_octaves = 4
		_tf_carte()
		_rendre_les_reglages()
		quit(0)
		return
	for partie in ["accroche", "recul", "peindre", "formes", "transitions", "foret", "eau", "riviere", "vol"]:
		if _sans.has(partie):
			continue
		if partie != "accroche" and not _construite:
			_construite = true
			_plan("construction")
			await _ile.construire()
			await _images(20)
		_plan(partie)
		await Callable(self, "_tf_" + partie).call()
		await _images(int(0.5 * FPS))
	_plan("fin")
	_rendre_les_reglages()
	quit(0)


# ── 0. L'ACCROCHE : UN bloc se sculpte en gros plan ──────────────────────────────────────────────────
## Le modeleur édite UNE tuile et toutes ses copies du bloc suivent (trailer v1, « l'accroche trouvée ») : on prend le
## dessus herbeux d'une tuile, E, et partout dans le bloc la même tuile se soulève. Annulé ensuite.

func _tf_accroche() -> void:
	_ecran._activer(_couche["Grass"])
	_ecran._aller_a("witness")
	await _images(10)
	_ecran._regler_edition(true)
	await _images(10)
	var mo = _ecran._modeleur
	_poser_camera(Vector3(6, 6, 6), 0.35, 0.42, 24.0)
	await _images(5)
	var centre_vue: Vector2 = _vue.size * 0.5
	mo.cliquer(centre_vue + Vector2(-100, -110), false)
	if not mo.sel_f.is_empty():
		mo.tout_choisir(false)
		for f in mo.maillage.faces.size():
			if mo.maillage.normale(f).y > 0.7:
				mo.sel_f[f] = true
	print("accroche : %d faces choisies" % mo.sel_f.size())
	_plan("accroche_geste")
	# Le bloc tourne déjà, puis le geste : la tuile monte, toutes les copies avec elle.
	for i in int(0.8 * FPS):
		_vue._azimut += 0.004
		_vue._caler()
		await _images(1)
	mo.souris = centre_vue
	mo.commencer("E")
	var n := int(2.6 * FPS)
	for i in n:
		var t := _doux(float(i) / float(n - 1))
		mo.souris = centre_vue + Vector2(0, -75.0 * t)
		mo._mettre_a_jour()
		_vue._azimut += 0.006
		_vue._distance = lerpf(24.0, 18.5, t)
		_vue._caler()
		await _images(1)
	for i in int(1.2 * FPS):
		_vue._azimut += 0.004
		_vue._caler()
		await _images(1)
	mo.annuler()
	_ecran._regler_edition(false)
	_ecran._aller_a("monde")
	_ecran._legende_formes.basculer(false, false)
	await _images(5)


# ── 1. LE RECUL : la caméra part d'une case et recule jusqu'à l'île entière ──────────────────────────

func _tf_recul() -> void:
	_ecran._activer(_couche["Grass"])
	# Une colline herbeuse au sud-est du lac : une case, de tout près.
	var p := Vector2i(2, 6)
	var c := Vector3(p.x + 0.5, _ile.hauteur(p.x, p.y) + 1.0, p.y + 0.5)
	_poser_camera(c, 0.6, 0.75, 4.0)
	await _images(int(0.6 * FPS))
	_plan("recul_depart")
	var n := int(6.0 * FPS)
	for i in n:
		var t := float(i) / float(n - 1)
		var e := 1.0 - pow(1.0 - t, 2.6)      # vite d'abord, puis il se pose
		_vue._cible = c.lerp(Vector3(0, 8, 0), _doux(t))
		_vue._distance = lerpf(4.0, 92.0, e)
		_vue._azimut = lerpf(0.6, 1.25, _doux(t))
		_vue._elevation = lerpf(0.75, 0.55, _doux(t))
		_vue._caler()
		await _images(1)
	_plan("orbite")
	await _tf_mouvement(7.0, {"cible": Vector3(0, 8, 0), "azimut": 1.25, "elevation": 0.55, "distance": 92.0},
		{"cible": Vector3(0, 8, 0), "azimut": 2.1, "elevation": 0.45, "distance": 80.0})


# ── 2. ON PEINT : une île sort de la mer, puis le sable, puis la roche, au pinceau et à la souris ─────

func _tf_peindre() -> void:
	_ecran._choisir_outil("ajouter")
	_ecran._activer(_couche["Grass"])
	var centre := Vector3(NEUVE) + Vector3(0.5, 4, 0.5)
	_poser_camera(centre, -0.75, 0.42, 36.0)
	await _images(15)
	_plan("ile_sort")
	_ecran._coup_commence()
	for etage in NEUVE_R:
		var rayon := NEUVE_R - etage
		for x in range(-rayon, rayon + 1):
			var rangee := {}
			for z in range(-rayon, rayon + 1):
				if x * x + z * z <= rayon * rayon:
					rangee[NEUVE + Vector3i(x, etage, z)] = true
					_hauteur_peinte[Vector2i(NEUVE.x + x, NEUVE.z + z)] = etage
			_ecran._touche({"poser": rangee, "effacer": {}}, "Add")
			_vue._azimut += 0.0035
			_vue._caler()
			await _images(1)
	_ecran._coup_fini()
	for i in int(1.2 * FPS):
		_vue._azimut += 0.003
		_vue._caler()
		await _images(1)
	# Le sable : un trait de pinceau à la souris (la vraie route : clic, glissé, lâcher), en visée SCULPT (le pinceau
	# bâtit sur la matière visée) : une ceinture de sable sur les marches basses de l'île neuve.
	# ⚠ Premier tournage : en visée Grid, le trait peignait sur le plan y = 0, SOUS la mer — rien à l'image.
	_plan("pinceau_sable")
	_ecran._activer(_couche["Desert"])
	_ecran._choisir_outil("ajouter")
	_ecran._choisir_visee("sculpt")
	_poser_camera(centre + Vector3(0, -2, 0), -0.3, 0.62, 34.0)
	await _images(10)
	for i in 2:
		_cle(KEY_BRACKETRIGHT, true)
		_cle(KEY_BRACKETRIGHT, false)
		await _images(2)
	var pts := []
	for k in 18:
		var a := -PI * 0.2 + k * PI * 1.4 / 17.0
		var rr := NEUVE_R - 2.5
		pts.append(Vector3(NEUVE.x + 0.5 + cos(a) * rr, 0, NEUVE.z + 0.5 + sin(a) * rr))
	await _tf_glisser(pts, 2.6, MOUSE_BUTTON_LEFT)
	for i in int(0.8 * FPS):
		_vue._azimut += 0.003
		_vue._caler()
		await _images(1)
	# La roche : une crête au sommet, en visée Sculpt.
	_plan("pinceau_roche")
	_ecran._activer(_couche["GreyRock"])
	_poser_camera(centre + Vector3(0, 4, 0), 0.4, 0.35, 30.0)
	await _images(10)
	var haut := Vector3(NEUVE.x + 0.5, 0, NEUVE.z + 0.5)
	await _tf_glisser([haut + Vector3(-2, 0, 1), haut + Vector3(0, 0, 0), haut + Vector3(2, 0, -1)], 1.4, MOUSE_BUTTON_LEFT)
	await _tf_glisser([haut + Vector3(-1, 0, 0), haut + Vector3(1, 0, 0)], 1.0, MOUSE_BUTTON_LEFT)
	for i in int(1.2 * FPS):
		_vue._azimut += 0.004
		_vue._caler()
		await _images(1)
	for i in 2:
		_cle(KEY_BRACKETLEFT, true)
		_cle(KEY_BRACKETLEFT, false)
		await _images(2)
	_ecran._choisir_visee("grille")
	_ecran._activer(_couche["GreyRock"])
	_ecran._reparer_les_diagonales(false)
	_ecran._activer(_couche["Grass"])
	await _images(10)


# ── 3. LES FORMES SPÉCIALES : un escalier et un tunnel dans la falaise nord ─────────────────────────

func _tf_formes() -> void:
	var mur := Vector3(Ile.CHENAL_X + 5, 9, 29)
	_ecran._activer(_couche["GreyRock"])
	_poser_camera(mur + Vector3(0, 1, 0), 0.25, 0.22, 24.0)
	await _images(10)
	await _cliquer_bouton("Stairs", "Stairs")
	_poser_camera(mur + Vector3(0, 1, 0), 0.25, 0.22, 24.0)
	await _bouger(_sur(mur + Vector3(-4, 0, 1.0)), 0.5)
	await _images(int(0.5 * FPS))
	_plan("escalier")
	await _clic(MOUSE_BUTTON_LEFT)
	await _derive_t(1.6, 0.003)
	await _cliquer_bouton("Tunnel", "Tunnel")
	await _bouger(_sur(mur + Vector3(2, 0, 1.0)), 0.5)
	await _images(int(0.4 * FPS))
	_plan("tunnel")
	await _clic(MOUSE_BUTTON_LEFT)
	await _derive_t(2.0, 0.003)
	await _bouger(Vector2(root.size.x + 40, root.size.y * 0.5), 0.2)
	_ecran._activer(_couche["Grass"])


# ── 4. LA FORÊT : l'atelier Foliage, des arbres de Spirit Heart World plantés au pinceau ────────────

func _tf_foret() -> void:
	_poser_camera(Vector3(-4, 14, 4), 0.9, 0.75, 70.0)
	await _cliquer_bouton("Foliage", "Foliage")
	await _images(int(0.5 * FPS))
	await _tf_importer("pin")
	_af_t.curseurs["espacement"].value = 3.0
	await _tf_controle(_af_t._boutons_mode["sol_debord"], "overflow")
	await _tf_controle(_af_t._boutons_outil["pinceau"], "brush")
	_af_t.curseurs["pinceau_rayon"].value = 6.0
	_af_t.curseurs["pinceau_essais"].value = 8.0
	# Les pins : sur le versant ouest, autour du plateau.
	_regarder(Vector3(-46, 46, 30), Vector3(-14, 10, 0))
	await _images(10)
	_plan("foret_pins")
	await _tf_glisser([Vector3(-22, 0, -4), Vector3(-18, 0, -14), Vector3(-10, 0, -20), Vector3(0, 0, -22)], 2.4,
		MOUSE_BUTTON_LEFT)
	await _derive_t(0.6, 0.002)
	await _tf_glisser([Vector3(-24, 0, 2), Vector3(-22, 0, 14), Vector3(-16, 0, 20)], 1.8, MOUSE_BUTTON_LEFT)
	await _derive_t(0.8, 0.002)
	print("forêt : %d plants" % _af_t.plants.size())
	# Les chênes : à l'est du lac, entre le plateau et le marais.
	await _tf_importer("chene")
	_af_t.curseurs["espacement"].value = 3.5
	_regarder(Vector3(34, 40, 40), Vector3(2, 8, 8))
	await _images(10)
	_plan("foret_chenes")
	await _tf_glisser([Vector3(-2, 0, -4), Vector3(4, 0, 4), Vector3(2, 0, 14), Vector3(-2, 0, 22)], 2.4, MOUSE_BUTTON_LEFT)
	await _derive_t(0.6, 0.002)
	await _tf_glisser([Vector3(6, 0, -2), Vector3(10, 0, 6), Vector3(8, 0, 20)], 1.6, MOUSE_BUTTON_LEFT)
	await _derive_t(0.8, 0.002)
	# Les palmiers : la plage du sud-ouest.
	await _tf_importer("palmier")
	_af_t.curseurs["espacement"].value = 3.5
	await _tf_controle(_af_t._boutons_mode["sol_libre"], "free")
	_af_t.curseurs["pinceau_rayon"].value = 3.0
	_regarder(Vector3(-50, 30, 46), Vector3(-20, 6, 22))
	await _images(10)
	_plan("foret_palmiers")
	var plage := []
	for k in 12:
		var a := PI * 0.55 + k * PI * 0.5 / 11.0
		var r := _rayon_de_plage(a)
		plage.append(Vector3(cos(a) * r, 0, sin(a) * r))
	await _tf_glisser(plage, 2.2, MOUSE_BUTTON_LEFT)
	await _derive_t(1.0, 0.002)
	print("forêt : %d plants, %d modèles" % [_af_t.plants.size(), _af_t.modeles.size()])
	_plan("foret_toute")
	await _bouger(Vector2(root.size.x + 40, root.size.y * 0.5), 0.2)
	await _tf_mouvement(5.0, {"cible": Vector3(-4, 8, 2), "azimut": 2.6, "elevation": 0.5, "distance": 78.0},
		{"cible": Vector3(-4, 8, 2), "azimut": 3.4, "elevation": 0.42, "distance": 66.0})


## Le rayon où le dessus est de la plage (sable, au ras de l'eau), le long de l'angle `a`.
func _rayon_de_plage(a: float) -> float:
	for r10 in range(340, 120, -5):
		var r := r10 / 10.0
		var x := floori(cos(a) * r)
		var z := floori(sin(a) * r)
		var h: int = _ile.hauteur(x, z)
		if h >= 0 and h <= Ile.MER + 1 and _ile.dessus(x, z, h) == "Desert":
			return r - 1.0
	return 28.0


## Un modèle `.glb` de Spirit Heart World : la route du dialogue de fichiers (natif, ni filmé ni pilotable), puis ses
## réglages aux curseurs de l'atelier.
func _tf_importer(cle: String) -> void:
	var a: Array = ARBRES_T[cle]
	var n0: int = _af_t.modeles.size()
	_ecran._action_fichier = "feuillage"
	_ecran._fichier_choisi(SPIRIT_T + a[0])
	if _af_t.modeles.size() != n0 + 1:
		print("⚠ import refusé : %s (%s)" % [a[0], _ecran._rapport.text])
		return
	_af_t.curseurs["echelle"].value = a[1]
	_af_t.curseurs["echelle_alea"].value = a[2]
	_af_t.curseurs["vent"].value = a[3]
	await _images(4)
	print("importé %s : %s" % [cle, _af_t.modele_actif()["chemin"]])


# ── 5. LES TRANSITIONS : une clairière de sable dans l'herbe, AU MÊME NIVEAU, puis le fondu ─────────────
## ⚠ Premier tournage : sur la plage de l'île, sable et herbe ne se touchent qu'à une MARCHE (l'herbe est toujours plus
## haute) — le fondu n'avait rien à fondre, et le mauvais couple s'est coché (la liste se refait quand on change un
## représentant : la case visée était libérée). Ici : une clairière où le dessus d'herbe devient du sable, colonne par
## colonne (Dig dans Grass, Add dans Desert, à la même hauteur) — des bords en marches de case, que le fondu adoucit.
const CLAIRIERE_T := Vector2(-4, -12)
const CLAIRIERE_R := 5.0

func _tf_transitions() -> void:
	var tr = _ecran._transitions
	var creuser := {}
	var poser := {}
	var bruit := FastNoiseLite.new()
	bruit.seed = 4
	bruit.frequency = 0.25
	for x in range(-12, 5):
		for z in range(-20, -3):
			var p := Vector2(x + 0.5, z + 0.5)
			if p.distance_to(CLAIRIERE_T) + 1.6 * bruit.get_noise_2d(x, z) > CLAIRIERE_R:
				continue
			var h: int = _ile.hauteur(x, z)
			if h < 0 or _ile.dessus(x, z, h) != "Grass":
				continue
			creuser[Vector3i(x, h, z)] = true
			poser[Vector3i(x, h, z)] = true
	var c := Vector3(CLAIRIERE_T.x, _ile.hauteur(int(CLAIRIERE_T.x), int(CLAIRIERE_T.y)) + 1.0, CLAIRIERE_T.y)
	_regarder(c + Vector3(-7, 11, 12), c)
	await _images(10)
	_plan("clairiere")
	_ecran._activer(_couche["Grass"])
	_ecran._appliquer({"poser": {}, "effacer": creuser}, "Dig")
	_ecran._activer(_couche["Desert"])
	_ecran._appliquer({"poser": poser, "effacer": {}}, "Add")
	_ecran._activer(_couche["Grass"])
	print("clairière : %d colonnes" % poser.size())
	await _derive_t(1.0, 0.002)
	await _cliquer_bouton("Transitions", "Transitions", "Where two layers meet")
	_regarder(c + Vector3(-7, 11, 12), c)
	await _images(int(0.5 * FPS))
	# Les représentants d'abord (le dessus de chaque couche : sinon le fondu prend la falaise).
	for nom in ["Grass", "Desert"]:
		for ligne in tr._materiaux.get_children():
			if (ligne.get_child(0) as Label).text == nom:
				var liste: OptionButton = ligne.get_child(1)
				for i in liste.item_count:
					if liste.get_item_text(i) == "Material 1":
						liste.select(i)
						liste.item_selected.emit(i)
	await _images(6)
	print("transitions avant : paires %s" % [tr.etat["paires"]])
	_plan("transitions_avant")
	await _derive_t(1.0, 0.002)
	# La case de la paire, relue APRÈS (la liste se refait).
	var case_: CheckBox = null
	for ligne in tr._liste.get_children():
		var t: String = (ligne.get_child(1) as Button).text
		if t == "Grass  ·  Desert" or t == "Desert  ·  Grass":
			case_ = ligne.get_child(0)
	if case_ == null:
		print("⚠ paire Grass · Desert introuvable")
	else:
		await _t_visible(case_)
		await _bouger(case_.get_global_rect().get_center(), 0.3)
		_plan("transitions_clic")
		await _clic(MOUSE_BUTTON_LEFT)
	print("transitions : paires %s" % [tr.etat["paires"]])
	await _bouger(Vector2(root.size.x + 40, root.size.y * 0.5), 0.2)
	await _derive_t(3.0, 0.002)
	await _cliquer_bouton("World", "World")
	_ecran._legende_formes.basculer(false, false)


func _tf_controle(c: Control, _detail: String) -> void:
	await _t_visible(c)
	await _bouger(c.get_global_rect().get_center(), 0.3)
	await _clic(MOUSE_BUTTON_LEFT)


func _t_visible(c: Control) -> void:
	var ecran := Rect2(Vector2(0, 40), Vector2(root.size) - Vector2(0, 40))
	if ecran.encloses(c.get_global_rect()):
		return
	var defile := c.get_parent()
	while defile != null and not defile is ScrollContainer:
		defile = defile.get_parent()
	if defile == null:
		return
	await _bouger((defile as Control).get_global_rect().get_center(), 0.3)
	var sens := MOUSE_BUTTON_WHEEL_DOWN if c.get_global_rect().end.y > ecran.end.y else MOUSE_BUTTON_WHEEL_UP
	for i in 60:
		if ecran.encloses(c.get_global_rect()):
			break
		_presser(sens, true)
		_presser(sens, false)
		await _images(2)
	await _images(12)


# ── 6. LE MONDE VIT : la falaise s'ouvre, le lac tombe en cascade ; la lave ; le marais ─────────────

func _tf_eau() -> void:
	# La falaise : Dig sur le bouchon de roche, le lac se vide en rivière et tombe dans la mer (le vrai recalcul).
	var bouchon := Vector3(Ile.CHENAL_X, Ile.PLATEAU - 1, Ile.BOUCHON[0])
	_poser_camera(bouchon + Vector3(0, -1, 5), -2.45, 0.4, 32.0)
	await _images(10)
	_plan("falaise_avant")
	await _derive_t(1.5, 0.002)
	_ecran._choisir_outil("creuser")
	var trou := {}
	for z in Ile.BOUCHON:
		for dx in [-1, 0, 1]:
			for y in range(Ile.PLATEAU - 3, Ile.PLATEAU + 1):
				trou[Vector3i(Ile.CHENAL_X + dx, y, z)] = true
	_plan("falaise_ouverte")
	_ecran._activer(_couche["GreyRock"])
	_ecran._appliquer({"poser": {}, "effacer": trou}, "Dig")
	_ecran._activer(_couche["Grass"])
	_ecran._appliquer({"poser": {}, "effacer": trou}, "Dig")
	await _ecran._recalculer_eau(false)
	await _tf_mouvement(5.0,
		{"cible": bouchon + Vector3(0, -1, 5), "azimut": -2.45, "elevation": 0.4, "distance": 32.0},
		{"cible": bouchon + Vector3(0, -6, 16), "azimut": -1.55, "elevation": 0.22, "distance": 30.0})
	# La cascade de près : sa colonne LUE dans le calcul de l'appli (les pas « chute »), vue depuis la mer.
	# ⚠ Premier tournage : un point deviné laissait la cascade au bord gauche de l'image.
	var col: Vector3i = _colonne_de_la_cascade()
	var cc := Vector3(col.x + 0.5, col.y, col.z + 0.5)
	_plan("cascade_pres")
	for i in int(4.0 * FPS):
		var t := _doux(float(i) / float(4.0 * FPS - 1))
		_regarder(cc + Vector3(lerpf(-9.0, 7.0, t), lerpf(1.0, 4.0, t), 17.0), cc + Vector3(0, -1.5, 0))
		await _images(1)
	# Le volcan : on frôle le lac de lave et la coulée.
	_plan("volcan")
	var v := Vector3(Ile.VOLCAN.x, 26, Ile.VOLCAN.y)
	await _tf_mouvement(5.0, {"cible": v, "azimut": 2.3, "elevation": 0.22, "distance": 36.0},
		{"cible": v, "azimut": 3.3, "elevation": 0.72, "distance": 17.0})
	_plan("marais")
	var m := Vector3(Ile.MARAIS.x, Ile.MER + 2, Ile.MARAIS.y)
	await _tf_mouvement(4.0, {"cible": m, "azimut": -0.5, "elevation": 0.5, "distance": 24.0},
		{"cible": m, "azimut": 0.3, "elevation": 0.36, "distance": 17.0})
	_ecran._choisir_outil("ajouter")


# ── 7. UNE RIVIÈRE D'UN CLIC, et ses aspects ────────────────────────────────────────────────────────

func _tf_riviere() -> void:
	# La source : la plus haute colonne d'herbe du versant nord-est (loin du lac et du volcan) ; la rivière y trouve
	# seule son chemin jusqu'à la mer. ⚠ Premier tournage : sur l'île neuve, 4 cases de rivière, minuscules à l'image.
	var source := Vector3i(0, 0, 0)
	var meilleur := -1
	for x in range(-8, 6):
		for z in range(-26, -14):
			var h: int = _ile.hauteur(x, z)
			if h > meilleur and _ile.dessus(x, z, h) == "Grass" and Vector2(x, z).distance_to(Vector2(Ile.VOLCAN)) > 12.0 					and Vector2(x, z).distance_to(CLAIRIERE_T) > CLAIRIERE_R + 2.0:
				meilleur = h
				source = Vector3i(x, h + 1, z)
	var vise := Vector3(source) + Vector3(0.5, -3, -5)
	_poser_camera(vise, 3.0, 0.5, 34.0)
	_ecran._changer_d_atelier("fluides")
	await _images(15)
	var ile = _ile
	ile._nouvelle_eau("River", "stylise")
	await _images(5)
	_plan("riviere_clic")
	await _derive_t(1.0, 0.002)
	_ecran._eau_cliquee(source, MOUSE_BUTTON_LEFT)
	await _ecran._recalculer_eau(false)
	print("rivière : source %s, rapport « %s »" % [source, _ecran._rapport.text])
	await _derive_t(3.0, 0.003)
	for nom in ["Glowing acid", "Lava", "Swamp"]:
		for i in _ecran._preset_eau.item_count:
			if _ecran._preset_eau.get_item_text(i) == nom:
				_ecran._preset_eau.select(i)
				_ecran._preset_eau.item_selected.emit(i)
		await _ecran._recalculer_eau(false)
		_plan("riviere_" + nom.to_lower().replace(" ", "_"))
		await _derive_t(2.0, 0.003)
	for i in _ecran._preset_eau.item_count:
		if _ecran._preset_eau.get_item_text(i) == "Stylized (RiverStones)":
			_ecran._preset_eau.select(i)
			_ecran._preset_eau.item_selected.emit(i)
	await _ecran._recalculer_eau(false)
	_ecran._changer_d_atelier("monde")
	_ecran._legende_formes.basculer(false, false)
	await _images(5)


# ── 8. LE PLAY TEST : le soleil doré, marcher dans la forêt, nager, voler, la météo ─────────────────

## Le Play test, ses réglages : le soleil doré du devlog du paysage (glow, horizon chaud), dans le dos de la caméra.
func _play_test(depart: Vector3, azimut: float) -> CharacterBody3D:
	_vue._cible = depart
	_cam_haut = false
	for reglage in [["soleil_hauteur", 30.0], ["soleil_azimut", TF_SOLEIL], ["soleil_couleur", Color(1.0, 0.88, 0.72)],
			["soleil_energie", 1.5], ["ciel_horizon", Color("#f2b98a")], ["glow", true], ["glow_intensite", 1.0]]:
		_vue.regler_rendu(reglage[0], reglage[1])
	await _cliquer_bouton("Play test", "Play test")
	await _bouger(Vector2(root.size.x + 40, root.size.y + 40), 0.2)
	_vue._azimut = azimut
	await _images(int(0.8 * FPS))
	var p: CharacterBody3D = _vue.personnage
	if p == null:
		print("⚠ pas de personnage")
	else:
		print("stickman en %s" % p.global_position)
	return p


func _quitter_le_jeu() -> void:
	_cle(KEY_ESCAPE, true)
	await _images(2)
	_cle(KEY_ESCAPE, false)
	await _images(10)
	_ecran._legende_formes.basculer(false, false)


## LE LAC, au Play test, AVANT que la falaise s'ouvre (on filme dans l'ordre qui garde le monde beau ; le montage remet
## l'ordre de la trame). Il marche sur la lèvre plate du lac (à PLATEAU, sans marche ni pente : la caméra ne bute pas),
## entre les chênes, puis saute dans le lac et nage.
## ⚠ Deuxième tournage : en descendant la pente vers la plage, le bras de la caméra butait contre le versant derrière
## lui — la tête du stickman remplissait l'image ; et le lac du plateau était VIDE (la falaise ouverte avant).
func _tf_lac() -> void:
	var l := Vector2(Ile.LAC)
	var arc := []
	for k in 9:
		var ang := -1.25 + k * 2.2 / 8.0          # l'est du lac, du nord-est au sud-est
		# ⚠ Troisième tournage : à 8,7 cases du centre, la pente qui descend du bord (le plat est de 5 à 7,5) ; il a
		# marché deux cases plus bas, puis ne pouvait plus remonter sur la lèvre (trois marches).
		arc.append(Vector3(l.x + 0.5 + cos(ang) * 6.3, 0, l.y + 0.5 + sin(ang) * 6.3))
	_cam_d = 7.0
	_cam_e = 0.42
	var p := await _play_test(Vector3(arc[0].x, Ile.PLATEAU + 1, arc[0].z), 0.0)
	if p == null:
		return
	_plan("lac_marche")
	await _aller(arc, "", "", true)
	_plan("lac_nage")
	_cam_d = 8.0
	_cam_e = 0.38
	await _aller([Vector3(l.x + 3.0, 0, l.y + 3.5), Vector3(l.x + 0.5, 0, l.y + 0.5), Vector3(l.x - 2.5, 0, l.y - 2.0)], "", "",
		false)
	print("nage : stickman en %s (le lac à %d)" % [p.global_position, Ile.PLATEAU])
	await _regarder_autour(3.0)
	await _quitter_le_jeu()


## LE VOL, à la fin : au-dessus de l'île entière (la cascade ouverte, la rivière, la forêt), puis la météo, puis le plan
## large et lent qui sert de fond au carton.
## ⚠ Deuxième tournage : caméra basse (0,3) derrière lui : l'horizon et la mer remplissaient l'image. Plus haute et plus
## loin, l'île se voit SOUS lui.
func _tf_vol() -> void:
	# LA PLAGE D'ABORD : le sable est plat (ni marche ni versant derrière lui : la caméra ne bute pas), la mer d'un côté,
	# l'île et ses arbres de l'autre ; il marche vers la falaise ouverte et sa cascade, entre dans la mer, et nage.
	# ⚠ Troisième tournage : autour du lac, entre les chênes, la caméra traversait les couronnes (le feuillage n'a pas de
	# collision, la caméra non plus) et le stickman restait sous la lèvre — `_tf_lac` n'est plus tourné.
	# ⚠ Quatrième tournage : `_rayon_de_plage` donnait du sable SOUS l'eau (dessus à 4 ou 5, la mer à 5) : il pataugeait
	# contre la falaise. Ici, seulement le sable sec (dessus à MER + 1), sur la côte est, sans palmiers.
	var pas := []
	for k in 10:
		var a := deg_to_rad(38.0 + k * 5.0)
		for r10 in range(340, 150, -5):
			var r := r10 / 10.0
			var x := floori(cos(a) * r)
			var z := floori(sin(a) * r)
			if _ile.hauteur(x, z) == Ile.MER + 1:
				pas.append(Vector3(x + 0.5, 0, z + 0.5))
				break
	print("plage : %d pas %s" % [pas.size(), pas])
	_cam_d = 7.0
	_cam_e = 0.45
	var p := await _play_test(Vector3(pas[0].x, _sol_t(pas[0].x, pas[0].z), pas[0].z), PI * 0.5)
	if p == null:
		return
	_plan("plage_marche")
	await _aller(pas, "", "", true)
	# La nage : droit vers le large, puis le long de la côte vers la cascade (la caméra derrière lui la regarde venir).
	_plan("plage_nage")
	var dernier: Vector3 = pas[pas.size() - 1]
	var large := Vector3(dernier.x, 0, dernier.z) * (40.0 / Vector2(dernier.x, dernier.z).length())
	_cam_d = 8.0
	_cam_e = 0.3
	await _aller([large, Vector3(Ile.CHENAL_X + 6.0, 0, 41.0), Vector3(Ile.CHENAL_X + 2.0, 0, 39.0)], "", "", false)
	print("nage : stickman en %s (la mer à %d)" % [p.global_position, Ile.MER])
	await _images(int(1.5 * FPS))
	_plan("vol_envol")
	_cle(KEY_F, true)
	await _images(2)
	_cle(KEY_F, false)
	_cam_d = 12.0
	_cam_e = 0.5
	_cle(KEY_SPACE, true)
	for i in int(3 * FPS):
		if p.global_position.y > _sol_t(p.global_position.x, p.global_position.z) + 9.0:
			break
		await _images(1)
	_cle(KEY_SPACE, false)
	_plan("vol")
	var cles := [Vector2(p.global_position.x, p.global_position.z), Vector2(-6, 22), Vector2(6, 12), Vector2(10, -4),
		Vector2(6, -18), Vector2(-8, -22), Vector2(-20, -8), Vector2(-18, 8), Vector2(-12, 22), Vector2(-4, 30)]
	await _voler_t(cles)
	for k in [KEY_W, KEY_SPACE, KEY_Q]:
		_cle(k, false)
	_plan("vol_plane")
	_cam_d = 26.0
	_cam_e = 0.5
	await _images(int(3.0 * FPS))
	for m in ["pluie", "neige", "aucune"]:
		_vue.regler_meteo(m)
		_plan("meteo_" + m)
		for i in int(3.5 * FPS):
			_vue._azimut += 0.004
			await _images(1)
	# Le fond du carton : l'île au soleil, de haut, qui tourne lentement.
	_plan("vol_final")
	_cam_d = 40.0
	_cam_e = 0.55
	for i in int(12.0 * FPS):
		_vue._azimut += 0.003
		await _images(1)
	await _quitter_le_jeu()


## Le vol, en poursuite d'un chemin lissé (le devlog du paysage, puis Foliage) : il vise le point 8 cases devant, à 9-12
## cases au-dessus du sol (les arbres n'ont pas de collision : on reste au-dessus des cimes).
func _voler_t(cles: Array) -> void:
	var p: CharacterBody3D = _vue.personnage
	var chemin := []
	for i in cles.size() - 1:
		var p0: Vector2 = cles[maxi(i - 1, 0)]
		var p1: Vector2 = cles[i]
		var p2: Vector2 = cles[i + 1]
		var p3: Vector2 = cles[mini(i + 2, cles.size() - 1)]
		var n := maxi(1, int(p1.distance_to(p2)))
		for j in n:
			var t := float(j) / n
			var q := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)
			chemin.append(Vector3(q.x, 0, q.y))
	_cam_d = 12.0
	_cam_e = 0.5
	_cle(KEY_W, true)
	var k := 0
	for i in int(50 * FPS):
		var pos := p.global_position
		while k < chemin.size() - 1 and Vector2(chemin[k + 1].x - pos.x, chemin[k + 1].z - pos.z).length() \
				< Vector2(chemin[k].x - pos.x, chemin[k].z - pos.z).length():
			k += 1
		if k >= chemin.size() - 2:
			break
		var vise: Vector3 = chemin[mini(k + 8, chemin.size() - 1)]
		var plat := Vector2(vise.x - pos.x, vise.z - pos.z)
		_vue._azimut = lerp_angle(_vue._azimut, atan2(-plat.x, -plat.y), 0.1)
		var devant := pos + Vector3(plat.normalized().x, 0, plat.normalized().y) * 5.0
		var sol := maxf(_sol_t(pos.x, pos.z), _sol_t(devant.x, devant.z))
		for d in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
			sol = maxf(sol, _sol_t(devant.x + d.x, devant.z + d.y))
		var haut := pos.y - sol
		# ⚠ COINCÉ : s'il n'a pas avancé d'une case en 1,5 s, il monte 1 s tout droit (la parade du devlog du paysage).
		# ⚠ Les « 36 s immobile » du troisième tournage n'étaient PAS le bord du plateau mais W relâchée par la perte du
		# focus (voir l'en-tête) ; la parade reste pour un vrai bord.
		if i % int(1.5 * FPS) == 0:
			if i > 0 and pos.distance_to(_derniere_pos_t) < 1.0:
				_montee_t = int(1.0 * FPS)
			_derniere_pos_t = pos
		if _montee_t > 0:
			_montee_t -= 1
			_cle(KEY_SPACE, true)
			_cle(KEY_Q, false)
		else:
			_cle(KEY_SPACE, haut < 9.0)
			_cle(KEY_Q, haut > 12.0)
		if i % int(4 * FPS) == 0:
			print("vol : point %d/%d, stickman en %s" % [k, chemin.size(), pos])
		await _images(1)
	_cle(KEY_W, false)
	_cle(KEY_SPACE, false)
	_cle(KEY_Q, false)


## Le dessus du sol en (x, z) : l'île (ou l'île neuve peinte), la mer sinon.
func _sol_t(x: float, z: float) -> float:
	var k := Vector2i(floori(x), floori(z))
	var h: int = maxi(_ile.hauteur(k.x, k.y), int(_hauteur_peinte.get(k, -1)))
	return float(maxi(h, Ile.MER)) + 1.0


# ── LA STATION ANIMÉE (une seconde prise, dans un projet À NOUS : `filmer_animation.gd`) ───────────────

func _derouler_station() -> void:
	await _images(30)
	await _ecran._ouvrir(_projet_anim)
	_ecran._changer_d_atelier("monde")
	_ecran._legende_formes.basculer(false, false)
	_vue = _ecran._vue
	for i in _ecran._couches.size():
		_couche[str(_ecran._couches[i].get("nom", ""))] = i
	_aides()
	_cam_haut = false
	_plan("textures")
	await _textures_anim()
	_plan("station")
	await _s_station()
	await _images(10)
	# Les pistes d'animation se posent dans l'atelier (la route du devlog) ; rien de cette partie ne sert au trailer.
	_plan("atelier")
	await _a_atelier()
	_plan("monde")
	await _a_monde()
	_plan("jeu")
	await _a_jeu()
	_plan("fin")
	_rendre_les_reglages()
	quit(0)


# ── L'OUTILLAGE ──────────────────────────────────────────────────────────────────────────────────────

func _tf_mouvement(duree: float, a: Dictionary, b: Dictionary) -> void:
	var n := int(duree * FPS)
	for i in n:
		var t := _doux(float(i) / float(n - 1))
		_vue._cible = (a["cible"] as Vector3).lerp(b["cible"], t)
		_vue._azimut = lerpf(a["azimut"], b["azimut"], t)
		_vue._elevation = lerpf(a["elevation"], b["elevation"], t)
		_vue._distance = lerpf(a["distance"], b["distance"], t)
		_vue._caler()
		await _images(1)


func _derive_t(duree: float, vitesse: float) -> void:
	for i in int(duree * FPS):
		_vue._azimut += vitesse
		_vue._caler()
		await _images(1)


## Un glissé de la souris (clic tenu) le long de points du monde : y = 0 → le dessus du sol en (x, z). Seuls les points
## DANS la vue comptent (un point sous un panneau perdait tout le trait, devlog Foliage).
func _tf_glisser(points: Array, duree: float, bouton: int) -> void:
	var ecran_pts: Array = []
	for w in points:
		var q: Vector3 = w
		if q.y == 0.0:
			q.y = _sol_t(q.x, q.z)
		if _dans_l_image(q, "trait"):
			ecran_pts.append(_sur(q))
	if ecran_pts.size() < 2:
		print("⚠ trait : moins de deux points dans la vue")
		return
	var longueur := 0.0
	for i in ecran_pts.size() - 1:
		longueur += (ecran_pts[i] as Vector2).distance_to(ecran_pts[i + 1])
	await _bouger(ecran_pts[0], 0.25)
	_presser(bouton, true)
	await _images(2)
	var n := maxi(1, int(duree * FPS))
	for f in n:
		var s := longueur * float(f + 1) / float(n)
		var p: Vector2 = ecran_pts[ecran_pts.size() - 1]
		for i in ecran_pts.size() - 1:
			var l := (ecran_pts[i] as Vector2).distance_to(ecran_pts[i + 1])
			if s <= l:
				p = (ecran_pts[i] as Vector2).lerp(ecran_pts[i + 1], s / maxf(l, 0.001))
				break
			s -= l
		var m := InputEventMouseMotion.new()
		var avant := _souris
		_souris = p
		m.position = p
		m.global_position = p
		m.relative = p - avant
		m.button_mask = _masque
		_envoyer(m)
		await _images(1)
	_presser(bouton, false)
	await _images(4)


## `--partie=carte` : le relief et la matière de l'île, vus de haut, en PNG (juger le monde avant de filmer).
func _tf_carte() -> void:
	var n := 40
	var im := Image.create((2 * n + 1) * 6, (2 * n + 1) * 6, false, Image.FORMAT_RGB8)
	var teinte := {"Grass": Color("#3fa34d"), "Desert": Color("#d8c27a"), "GreyRock": Color("#7a7a7a")}
	for x in range(-n, n + 1):
		for z in range(-n, n + 1):
			var h: int = _ile.hauteur(x, z)
			var c := Color("#2d6fa8")
			if h >= 0:
				c = (teinte[_ile.dessus(x, z, h)] as Color).darkened(clampf(0.5 - 0.02 * h, 0.0, 0.7))
			if x % 10 == 0 or z % 10 == 0:
				c = c.darkened(0.3)
			im.fill_rect(Rect2i((x + n) * 6, (z + n) * 6, 6, 6), c)
	im.save_png(CARTE_T)
	print("carte -> %s" % CARTE_T)
