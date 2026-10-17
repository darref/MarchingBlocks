extends "res://DEV_TOOLS/filmer_haut.gd"
##
## DEVLOG — LE CŒUR C++ (Jordan, 6 octobre 2026 : « fait un dev log pour chaque nouveauté »). La règle de pose, le massif,
## l'océan, la découpe et le monde du cœur réécrits en C++ (GDExtension) ; le GDScript reste la référence et le repli
## (`MB_NATIF=0` l'éteint). Ce script mène les MÊMES gestes, dans le même ordre, sur le même monde, et chronomètre chacun
## autour du VRAI appel (`Time.get_ticks_usec`) : le chiffre affiché est celui de CETTE prise.
##
## ⚠ PAS DE `--write-movie` : le Movie Maker filme à pas de temps FIXE, un geste de 800 ms y devient UNE image et la lenteur
## disparaît. Ce script tourne en TEMPS RÉEL ; la fenêtre (titre `MB_COEUR_CAPTURE`) est filmée de l'extérieur par
## `D:/SpannerGames/PROJETS/MarchingBlocks/01_scripts/capture_coeur.py` (ffmpeg gfxcapture, 30 images/s).
##
## LANCEMENT — dans la COPIE `D:/SpannerGames/ATELIER/MarchingBlocks/worktrees/MB_tournage_coeur` (1920 × 1080, sans bord, données à part) :
##   cp D:/MarchingBlocks/DEV_TOOLS/filmer_coeur.gd D:/SpannerGames/ATELIER/MarchingBlocks/worktrees/MB_tournage_coeur/DEV_TOOLS/
##   1. une fois : Godot…_console.exe --path D:/SpannerGames/ATELIER/MarchingBlocks/worktrees/MB_tournage_coeur --script res://DEV_TOOLS/filmer_coeur.gd -- --preparer
##      (le monde de ~120 000 cases, en trois couches, bâti avec le natif et enregistré, puis sa sauvegarde) ;
##   2. chaque prise : la même commande sans `--preparer` ; `MB_NATIF=0` dans l'environnement pour la prise GDScript.
##   Les lignes `MARQUE <nom> <ms unix>` disent où couper ; `MESURE <geste> <ms>` ce qui a été mesuré.
## ⚠ Ne jamais l'interrompre : il rend les réglages à la fin.

const Natif := preload("res://addons/marchingblocks_core/natif.gd")
const PREP := "user://coeur_prep"
const TITRE_FENETRE := "MB_COEUR_CAPTURE"
const FOND_COEUR := -9             # le bas de chaque colonne : le monde fait ~120 000 cases, comme les mesures de la charte
const BORD_MER := 6                # les colonnes du bord restent vides : la mer les prendra…
const NIVEAU_MER := 4              # …à ce niveau (le sol le plus bas de l'île est à 5)

var _preparer := false
var _projet_coeur := ""
var _t_derniere := 0
# Le chronomètre affiché : le geste, puis ce qu'il a coûté dans CETTE prise.
var _chrono_geste := ""
var _chrono_valeur := ""
var _chrono_note := ""
var _chrono_age := 99.0
var _flash := 0
var _mode := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--preparer":
			_preparer = true
		if a.begins_with("--seulement="):
			_seulement = a.substr("--seulement=".length())
	if FileAccess.file_exists(SAUVEGARDE):
		DirAccess.copy_absolute(SAUVEGARDE, REGLAGES)
	if FileAccess.file_exists(REGLAGES):
		DirAccess.copy_absolute(REGLAGES, SAUVEGARDE)
	Engine.max_fps = 60
	DisplayServer.window_set_title(TITRE_FENETRE)
	load("res://app/editor.gd").racine_exemple = PREP
	if _preparer:
		_vider(PREP)
		var erreurs: Array = []
		_chemin = Exemple.installer(Exemple.ARCHIVE, PREP, erreurs)
		if _chemin == "":
			print("⚠ l'exemple ne s'installe pas : %s" % [erreurs])
			_rendre_les_reglages()
			quit(1)
			return
		var f := FileAccess.open(PREP.path_join("chemin.txt"), FileAccess.WRITE)
		f.store_string(_chemin)
		f.close()
	else:
		_chemin = FileAccess.get_file_as_string(PREP.path_join("chemin.txt")).strip_edges()
		if _chemin == "" or not FileAccess.file_exists(_chemin + ".sauve"):
			print("⚠ rien de préparé : lancer d'abord avec -- --preparer")
			_rendre_les_reglages()
			quit(1)
			return
		# LE MÊME MONDE À CHAQUE PRISE : le projet enregistré par la préparation, rendu tel quel (les gestes de la prise
		# d'avant — Up, la mer, le pinceau — s'étaient enregistrés dedans).
		DirAccess.copy_absolute(_chemin + ".sauve", _chemin)
	# Au lancement, un projet NEUF et vide (aucun « dernier monde ») : l'ouverture du grand monde est le premier geste filmé.
	var r := ConfigFile.new()
	r.save(REGLAGES)
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	Input.use_accumulated_input = false
	_mode = "C++ core" if Natif.noyau() != null else "GDScript  (MB_NATIF=0)"
	print("MODE %s" % _mode)
	_derouler.call_deferred()


func _derouler() -> void:
	DisplayServer.window_set_title(TITRE_FENETRE)
	# ⚠ La fenêtre sortait ~1920 × 1030 (Windows la tient dans la zone de travail, au-dessus de la barre des tâches) :
	# une bande noire en bas de la capture. En plein écran (sans mode exclusif), 1920 × 1080 pour de vrai.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	await _images(30)
	print("FENETRE %s" % DisplayServer.window_get_size())
	_vue = _ecran._vue
	if _preparer:
		await _preparer_le_monde()
		_rendre_les_reglages()
		quit(0)
		return
	_relief()   # les hauteurs du monde préparé (le même bruit, la même graine) : où viser
	_aides()
	# LE FEU VERT DE LA CAPTURE : `capture_coeur.py` crée ce fichier quand ffmpeg filme pour de vrai (⚠ sur une machine
	# chargée, `gfxcapture` a échoué une fois à démarrer — « WGC thread init timed out » — et la prise était perdue).
	var go := OS.get_environment("MB_COEUR_GO")
	if go != "":
		var limite := Time.get_ticks_msec() + 90000
		while not FileAccess.file_exists(go) and Time.get_ticks_msec() < limite:
			await _images(1)
		print("FEU VERT %s" % FileAccess.file_exists(go))
	await _attendre_s(1.0)
	# LE TOP : un éclair magenta plein cadre, pour caler la vidéo sur les marques (chaque prise a le sien).
	_flash = 12
	_marque("flash")
	await _images(12)
	_flash = 0
	await _attendre_s(1.5)
	for partie in ["ouvrir", "peindre", "couches", "mer", "riviere", "trancher"]:
		if _seulement != "" and _seulement != partie and partie != "ouvrir":
			continue
		_marque("debut_" + partie)
		await Callable(self, "_c_" + partie).call()
		_marque("fin_" + partie)
		await _attendre_s(0.8)
	_marque("fin")
	_rendre_les_reglages()
	quit(0)


# ── LA PRÉPARATION (une fois) : le monde vu de haut, plus profond, en trois couches ───────────────────

func _preparer_le_monde() -> void:
	await _ecran._ouvrir(_chemin)
	_ecran._changer_d_atelier("monde")
	for i in _ecran._couches.size():
		_couche[str(_ecran._couches[i].get("nom", ""))] = i
	for nom in _couche:
		_ecran._activer(_couche[nom])
		var occ: Dictionary = _ecran._occupees()
		if not occ.is_empty():
			_ecran._appliquer({"poser": {}, "effacer": occ}, "Dig")
	while not _ecran._eaux.is_empty():
		_ecran._retirer_eau(_ecran._eaux[0])
	_relief()
	# ⚠ LA MER A BESOIN D'UNE COLONNE VIDE DANS LA BOÎTE DU MONDE (`FL.dans_le_vide` : rien dessous ; `FL.boite` : les
	# cases, une de marge — au premier essai, un fond marin plat faisait du clic une rivière). Le rempart du monde vu de
	# haut est retiré : un anneau VIDE, que la mer remplira, et une seule case au fond de chaque coin pour tenir la boîte.
	var parts := {"GreyRock": {}, "Grass": {}, "Desert": {}}
	var nom_de := {"roche": "GreyRock", "herbe": "Grass", "sable": "Desert"}
	for k in _h:
		var bord := mini(mini(k.x - X0, X1 - k.x), mini(k.y - Z0, Z1 - k.y))
		if bord < BORD_MER:
			continue
		for y in range(FOND_COEUR, int(_h[k]) + 1):
			parts[nom_de[_m[k]]][Vector3i(k.x, y, k.y)] = true
	for coin in [Vector3i(X0, FOND_COEUR, Z0), Vector3i(X1, FOND_COEUR, Z0), Vector3i(X0, FOND_COEUR, Z1), Vector3i(X1, FOND_COEUR, Z1)]:
		parts["GreyRock"][coin] = true
	for nom in parts:
		_ecran._activer(_couche[nom])
		_ecran._appliquer({"poser": parts[nom], "effacer": {}}, "Add")
		await _images(2)
	_ecran._activer(_couche["GreyRock"])
	await _ecran._reparer_les_diagonales(false)
	_ecran._activer(_couche["Grass"])
	_ecran._enregistrer()
	await _images(5)
	DirAccess.copy_absolute(_chemin, _chemin + ".sauve")
	var total := 0
	for i in _ecran._couches.size():
		var n: int = (_ecran._vue.couche(i).get_node("Cases") as GridMap).get_used_cells().size()
		print("couche %s : %d cases" % [_ecran._couches[i]["nom"], n])
		total += n
	print("PREPARE %s : %d cases" % [_chemin, total])


# ── 1. OUVRIR : le grand monde, trois couches ────────────────────────────────────────────────────────

func _c_ouvrir() -> void:
	_annoncer("Open a 3-layer world")
	await _attendre_s(1.5)
	var t := Time.get_ticks_usec()
	_marque("action_ouvrir")
	await _ecran._ouvrir(_chemin)
	var us := Time.get_ticks_usec() - t
	_ecran._changer_d_atelier("monde")
	_ecran._legende_formes.basculer(false, false)
	_vue = _ecran._vue
	for i in _ecran._couches.size():
		_couche[str(_ecran._couches[i].get("nom", ""))] = i
	var total := 0
	for i in _ecran._couches.size():
		total += (_ecran._vue.couche(i).get_node("Cases") as GridMap).get_used_cells().size()
	_mesure("ouvrir", us, "Open a 3-layer world", "%s cells" % _milliers(total))
	_vue = _ecran._vue
	_vue_large()
	await _attendre_s(3.0)


# ── 2. PEINDRE : de grands coups de pinceau (taille 7) sur l'herbe ──────────────────────────────────────

func _c_peindre() -> void:
	_ecran._activer(_couche["Grass"])
	_poser_camera(Vector3(-30, G, 4), 0.0, 0.85, 62.0)
	await _attendre_s(0.6)
	await _bouger(_sur(_haut_de(Vector2i(-40, -4))), 0.5)
	await _touche(KEY_TAB, "Tab", "Sculpt aim: paint ON the matter")
	await _touche(KEY_A, "A", "Add")
	for i in 6:
		_cle(KEY_BRACKETRIGHT, true)
		_cle(KEY_BRACKETRIGHT, false)
		await _images(2)
	_montrer("]  ×6", "The biggest brush")
	await _attendre_s(0.8)
	var coups := [[Vector2i(-48, -10), Vector2i(-14, -10)], [Vector2i(-48, 0), Vector2i(-14, 0)],
		[Vector2i(-48, 10), Vector2i(-14, 10)], [Vector2i(-31, -18), Vector2i(-31, 20)]]
	var travail := 0
	var pas := 0
	var pire := 0
	var t_mur := Time.get_ticks_usec()
	_annoncer("Paint 4 big strokes")
	_marque("action_peindre")
	for c in coups:
		var r: Array = await _coup_mesure(c[0], c[1], 45)
		travail += r[0]
		pas += r[1]
		pire = maxi(pire, r[2])
	var mur := Time.get_ticks_usec() - t_mur
	print("MESURE peindre_mur %.1f ms" % (mur / 1000.0))
	print("MESURE peindre_pire_pas %.1f ms" % (pire / 1000.0))
	_mesure("peindre", travail, "Paint 4 big strokes", "%d brush steps, %s ms each on average" % [pas,
		_milliers_f(travail / 1000.0 / maxf(1.0, pas))])
	await _attendre_s(3.0)
	# Ctrl+Z ×4 : chaque coup s'annule d'un seul geste (le monde revient à celui de la préparation).
	_montrer("Ctrl + Z  ×4", "Undo every stroke")
	await _attendre_s(0.8)
	_marque("action_annuler")
	var annuler := 0
	for i in 4:
		_cle(KEY_CTRL, true)
		var t := Time.get_ticks_usec()
		_cle(KEY_Z, true, true)
		annuler += Time.get_ticks_usec() - t
		await _images(2)
		_cle(KEY_Z, false, true)
		_cle(KEY_CTRL, false)
		await _images(6)
	# ⚠ PAS AFFICHÉ : la frappe ne coûte que ~0,3 ms — l'annulation se fait plus loin (pas sur ce fil, ou pas à
	# l'appui) ; le chronomètre ne l'entoure pas, donc ce chiffre ne dirait rien.
	print("MESURE annuler_frappes %.1f ms" % (annuler / 1000.0))
	await _attendre_s(2.5)


## Un glissé du clic gauche, `n` pas d'une colonne à l'autre ; rend [µs passées dans l'appli, pas, pire pas].
func _coup_mesure(a: Vector2i, b: Vector2i, n: int) -> Array:
	await _bouger(_sur(_haut_de(a)), 0.3)
	_montrer("Left drag", "Paint")
	var total := 0
	var pire := 0
	var t := Time.get_ticks_usec()
	_presser(MOUSE_BUTTON_LEFT, true)
	total += Time.get_ticks_usec() - t
	for i in n:
		var c := Vector2(a).lerp(Vector2(b), float(i + 1) / float(n))
		var avant := _souris
		_souris = _sur(_haut_de(Vector2i(roundi(c.x), roundi(c.y))))
		var m := InputEventMouseMotion.new()
		m.position = _souris
		m.global_position = _souris
		m.relative = _souris - avant
		m.button_mask = _masque
		t = Time.get_ticks_usec()
		_envoyer(m)
		var d := Time.get_ticks_usec() - t
		total += d
		pire = maxi(pire, d)
		await _images(1)
	t = Time.get_ticks_usec()
	_presser(MOUSE_BUTTON_LEFT, false)
	total += Time.get_ticks_usec() - t
	await _images(2)
	return [total, n, pire]


# ── 3. LES COUCHES : Up, Down, cacher, montrer ─────────────────────────────────────────────────────────

func _c_couches() -> void:
	_vue_large()
	_ecran._activer(_couche["Grass"])
	await _attendre_s(0.8)
	var monter: Button = _ecran._bouton_monter_couche
	var descendre: Button = _ecran._bouton_descendre_couche
	# Grass est au rang 1 : Up la passe au-dessus de GreyRock, Down la remet.
	var rang: int = _ecran._active
	print("Grass au rang %d" % rang)
	var premier: Button = monter if rang > 0 else descendre
	var second: Button = descendre if rang > 0 else monter
	var n1 := "Up" if rang > 0 else "Down"
	var n2 := "Down" if rang > 0 else "Up"
	await _clic_mesure(premier, "Layer " + n1, "Move the Grass layer " + n1.to_lower())
	await _attendre_s(2.8)
	await _clic_mesure(second, "Layer " + n2, "And back " + n2.to_lower())
	await _attendre_s(2.8)
	var oeil: Button = _ecran._liste_couches.get_child(_ecran._active).get_child(0)
	await _clic_mesure(oeil, "Hide a layer", "Hide the Grass layer")
	await _attendre_s(2.5)
	oeil = _ecran._liste_couches.get_child(_ecran._active).get_child(0)
	await _clic_mesure(oeil, "Show a layer", "Show it again")
	await _attendre_s(2.5)


## La souris va sur le bouton et clique ; le chronomètre entoure l'APPUI et le RELÂCHER (les boutons de l'appli agissent
## à l'un ou à l'autre, sur ce fil) — pas l'image d'attente entre les deux.
func _clic_mesure(b: Button, geste: String, detail: String) -> void:
	await _viser(b)
	_annoncer(geste)
	_montrer("Click", detail)
	await _images(2)
	_marque("action_" + geste.replace(" ", "_"))
	var t := Time.get_ticks_usec()
	_presser(MOUSE_BUTTON_LEFT, true)
	var us := Time.get_ticks_usec() - t
	await _images(1)
	t = Time.get_ticks_usec()
	_presser(MOUSE_BUTTON_LEFT, false)
	us += Time.get_ticks_usec() - t
	_mesure(geste, us, geste, "")
	await _images(2)


# ── 4. LA MER : l'atelier Fluids, une eau neuve, deux clics dans le vide ────────────────────────────────

func _c_mer() -> void:
	await _cliquer_bouton("Fluids", "Fluids workshop")
	await _attendre_s(0.5)
	await _cliquer_bouton("New", "New water layer")
	var niveau := NIVEAU_MER
	var avant := int(_ecran._compteur_etage.value)
	if avant != niveau:
		_montrer("PgUp / PgDn", "Water height: y = %d" % niveau)
		for i in absi(niveau - avant):
			var k := KEY_PAGEUP if niveau > avant else KEY_PAGEDOWN
			_cle(k, true)
			_cle(k, false)
			await _images(2)
	# Dans l'anneau vide, au sud-ouest : une colonne où rien n'est posé, dans la boîte du monde.
	var vide := Vector3(X0 + 2.5, niveau, Z1 - 2.5)
	_poser_camera(Vector3(-10, G, 10), 0.6, 0.75, 120.0)
	await _attendre_s(0.6)
	await _bouger(_sur(vide), 0.6)
	await _clic(MOUSE_BUTTON_LEFT, "Click the void", "The sea: pick its height")
	print("mer choisie : %s ; rapport : %s" % [_ecran._mer_choisie, _ecran._rapport.text.left(200)])
	_annoncer("Place the sea")
	_montrer("Click again", "Place the sea")
	# ⚠ LA MER SE POSE À L'APPUI (`_eau_cliquee`), et l'eau se calcule à l'image suivante : le chronomètre part avant.
	_marque("action_mer")
	var t := Time.get_ticks_usec()
	_presser(MOUSE_BUTTON_LEFT, true)
	await _images(3)
	_presser(MOUSE_BUTTON_LEFT, false)
	# L'eau se recalcule à l'image suivante (`call_deferred`), derrière le panneau « Water » : on attend qu'il soit fini.
	await _images(2)
	while _ecran._eau_a_refaire or not _ecran._pile_attente.is_empty():
		await _images(1)
	var us := Time.get_ticks_usec() - t
	var calcul: float = float(_ecran._durees.get("eau", 0.0)) * 1000.0
	print("rapport : %s" % _ecran._rapport.text.left(300))
	print("MESURE mer_calcul %.0f ms (%d cases d'eau)" % [calcul, (_ecran._ocean_eau as Dictionary).size()])
	print("MESURE mer_mur %.1f ms" % (us / 1000.0))
	# ⚠ LE MUR DE LA MER suit surtout les IMAGES (le panneau « Water » attend d'être dessiné) : sur une carte graphique
	# partagée par d'autres tournages, il mesurait la charge des autres. On affiche le calcul de l'eau, chronométré par
	# l'appli elle-même autour de `FL.monde` et du maillage (`_durees["eau"]`).
	_mesure("mer", int(calcul * 1000.0), "Place the sea: water solved in", "%s water cells" % _milliers((_ecran._ocean_eau as Dictionary).size()))
	await _attendre_s(3.0)


# ── 4 bis. UNE RIVIÈRE : une source au haut plateau, qui descend jusqu'à la mer ──────────────────────

func _c_riviere() -> void:
	await _cliquer_bouton("Fluids", "Fluids workshop")
	await _attendre_s(0.4)
	var p := Vector2i(roundi(PLATEAU.x), roundi(PLATEAU.y))
	_poser_camera(Vector3(p.x, PLATEAU_DESSUS, p.y + 8), 0.4, 0.75, 60.0)
	await _attendre_s(0.6)
	await _bouger(_sur(_haut_de(p) + Vector3(0, 0.02, 0)), 0.6)
	_annoncer("A river on the plateau: water solved in")
	_montrer("Click", "A spring: the river finds its way to the sea")
	_marque("action_riviere")
	_presser(MOUSE_BUTTON_LEFT, true)
	await _images(3)
	_presser(MOUSE_BUTTON_LEFT, false)
	await _images(2)
	while _ecran._eau_a_refaire or not _ecran._pile_attente.is_empty():
		await _images(1)
	var calcul: float = float(_ecran._durees.get("eau", 0.0)) * 1000.0
	print("rapport : %s" % _ecran._rapport.text.left(300))
	_mesure("riviere", int(calcul * 1000.0), "A river on the plateau: water solved in", "")
	await _attendre_s(3.5)
	await _touche(KEY_ESCAPE, "Esc", "Back to World")
	await _attendre_s(0.4)


# ── 5. TRANCHER : le témoin de la couche, retranché, et la couche rhabillée ─────────────────────────────

func _c_trancher() -> void:
	_ecran._activer(_couche["GreyRock"])
	_poser_camera(Vector3(30, 9, -14), 0.6, 0.7, 70.0)
	# Le bouton est dans l'atelier Project (étape 3, « Dress the world »).
	await _cliquer_bouton("Project", "Project workshop")
	await _attendre_s(0.6)
	var b := _bouton(_ecran, "Slice this layer's witness")
	if b == null:
		print("⚠ bouton de tranchage introuvable")
		return
	await _cliquer_bouton_mesure("Slice this layer's witness", "Re-slice the witness")


func _cliquer_bouton_mesure(texte: String, geste: String) -> void:
	var b := _bouton(_ecran, texte)
	await _viser(b)
	_annoncer(geste)
	_montrer("Click", texte)
	_marque("action_trancher")
	var t := Time.get_ticks_usec()
	_presser(MOUSE_BUTTON_LEFT, true)
	await _images(1)
	_presser(MOUSE_BUTTON_LEFT, false)
	await _images(1)
	while not _ecran._pile_attente.is_empty():
		await _images(1)
	var us := Time.get_ticks_usec() - t
	_mesure("trancher", us, geste, "the witness sliced, the layer dressed again")
	await _attendre_s(3.0)


## ⚠ UN BOUTON PEUT ÊTRE HORS DE SON PANNEAU (sous le bord, ou au-dessus quand le panneau a défilé) : la molette le
## ramène, comme le ferait la main, puis on attend que le défilement s'arrête (filmer_ui : sinon le clic glisse).
func _viser(b: Control) -> void:
	var defile := b.get_parent()
	while defile != null and not defile is ScrollContainer:
		defile = defile.get_parent()
	if defile != null:
		var zone := (defile as Control).get_global_rect().grow(-4)
		if not zone.encloses(b.get_global_rect()):
			await _bouger(zone.get_center(), 0.4)
			for i in 60:
				if zone.encloses(b.get_global_rect()):
					break
				var sens := MOUSE_BUTTON_WHEEL_DOWN if b.get_global_rect().end.y > zone.end.y else MOUSE_BUTTON_WHEEL_UP
				_presser(sens, true)
				_presser(sens, false)
				await _images(2)
			await _images(12)
	await _bouger(b.get_global_rect().get_center(), 0.5)


func _vue_large() -> void:
	_poser_camera(Vector3(0, G, 0), 0.3, 0.9, 150.0)


# ── L'OUTILLAGE DU TEMPS RÉEL ───────────────────────────────────────────────────────────────────────

func _haut_de(p: Vector2i) -> Vector3:
	return Vector3(p.x + 0.5, float(_h.get(p, G)) + 1.0, p.y + 0.5)


func _marque(nom: String) -> void:
	print("MARQUE %s %d" % [nom, int(Time.get_unix_time_from_system() * 1000.0)])


func _annoncer(geste: String) -> void:
	_chrono_geste = geste
	_chrono_valeur = "…"
	_chrono_note = ""
	_chrono_age = 0.0
	if _dessin != null:
		_dessin.queue_redraw()


func _mesure(cle: String, us: int, geste: String, note: String) -> void:
	var ms := us / 1000.0
	_marque("mesure_" + cle.replace(" ", "_"))
	print("MESURE %s %.1f ms" % [cle, ms])
	_chrono_geste = geste
	_chrono_valeur = ("%s ms" % _milliers_f(ms)) if ms < 10000.0 else ("%.1f s" % (ms / 1000.0))
	_chrono_note = note
	_chrono_age = 0.0


func _milliers(n: int) -> String:
	var s := str(n)
	var r := ""
	while s.length() > 3:
		r = "," + s.right(3) + r
		s = s.left(s.length() - 3)
	return s + r


## 0,2 → « 0.2 » ; 12,3 → « 12 » ; 1 234 → « 1,234 ».
func _milliers_f(ms: float) -> String:
	if ms < 10.0:
		return "%.1f" % ms
	return _milliers(roundi(ms))


## Attendre en TEMPS RÉEL (pas en images : une image peut durer une seconde quand le GDScript calcule).
func _attendre_s(s: float) -> void:
	var fin := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < fin:
		await _images(1)


## La souris glisse en temps réel (le nombre d'événements suit les images : un déplacement sans geste n'en dépend pas).
func _bouger(vers: Vector2, duree: float) -> void:
	var depuis := _souris
	var debut := Time.get_ticks_msec()
	while true:
		var t := _doux(float(Time.get_ticks_msec() - debut) / (duree * 1000.0))
		var avant := _souris
		_souris = depuis.lerp(vers, t)
		var m := InputEventMouseMotion.new()
		m.position = _souris
		m.global_position = _souris
		m.relative = _souris - avant
		m.button_mask = _masque
		_envoyer(m)
		await _images(1)
		if t >= 1.0:
			break


func _images(n: int) -> void:
	for i in n:
		await process_frame
		var maintenant := Time.get_ticks_usec()
		var dt := 0.0 if _t_derniere == 0 else (maintenant - _t_derniere) / 1000000.0
		_t_derniere = maintenant
		_image += 1
		_carte_age += minf(dt, 0.1)
		_chrono_age += minf(dt, 0.1)
		if _dessin != null:
			_dessin.queue_redraw()


func _dessiner() -> void:
	super._dessiner()
	var l := _dessin.size.x
	# Le mode de CETTE prise, en haut au milieu de la vue (lu dans `Natif.noyau()`, pas écrit à la main).
	var tm := 26
	var lm := _police.get_string_size(_mode, HORIZONTAL_ALIGNMENT_LEFT, -1, tm).x
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0.07, 0.06, 0.1, 0.82)
	fond.set_corner_radius_all(10)
	var cpp := _mode.begins_with("C++")
	fond.border_color = Color(0.79, 0.63, 0.27) if cpp else Color(0.6, 0.62, 0.7)
	fond.set_border_width_all(2)
	_dessin.draw_style_box(fond, Rect2((l - lm) * 0.5 - 20, 64, lm + 40, 46))
	_dessin.draw_string(_police, Vector2((l - lm) * 0.5, 97), _mode, HORIZONTAL_ALIGNMENT_LEFT, -1, tm,
		Color(1.0, 0.85, 0.45) if cpp else Color(0.92, 0.93, 0.97))
	# Le chronomètre : le geste, et ce qu'il a coûté dans cette prise. Il reste 4 s.
	if _chrono_geste != "" and _chrono_age < 4.5:
		var a := clampf((4.5 - _chrono_age) / 0.4, 0.0, 1.0)
		var tg := 34
		var tv := 64
		var tn := 26
		var lg := _police.get_string_size(_chrono_geste, HORIZONTAL_ALIGNMENT_LEFT, -1, tg).x
		var lv := _police.get_string_size(_chrono_valeur, HORIZONTAL_ALIGNMENT_LEFT, -1, tv).x
		var ln := _police.get_string_size(_chrono_note, HORIZONTAL_ALIGNMENT_LEFT, -1, tn).x
		var largeur := maxf(maxf(lg, lv), ln) + 64
		var haut := 170.0 if _chrono_note != "" else 136.0
		var x0 := (l - largeur) * 0.5
		var y0 := 124.0
		var f2 := StyleBoxFlat.new()
		f2.bg_color = Color(0.07, 0.06, 0.1, 0.86 * a)
		f2.set_corner_radius_all(14)
		_dessin.draw_style_box(f2, Rect2(x0, y0, largeur, haut))
		_dessin.draw_string(_police, Vector2((l - lg) * 0.5, y0 + 44), _chrono_geste, HORIZONTAL_ALIGNMENT_LEFT, -1, tg,
			Color(0.85, 0.85, 0.9, a))
		_dessin.draw_string(_police, Vector2((l - lv) * 0.5, y0 + 112), _chrono_valeur, HORIZONTAL_ALIGNMENT_LEFT, -1, tv,
			Color(1, 1, 1, a))
		if _chrono_note != "":
			_dessin.draw_string(_police, Vector2((l - ln) * 0.5, y0 + 150), _chrono_note, HORIZONTAL_ALIGNMENT_LEFT, -1,
				tn, Color(0.75, 0.75, 0.82, a))
	if _flash > 0:
		_dessin.draw_rect(Rect2(Vector2.ZERO, _dessin.size), Color(1, 0, 1))
