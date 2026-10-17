extends "res://DEV_TOOLS/filmer_haut.gd"
##
## LA STATION SPATIALE EN VIDÉO — demandé par Jordan (17 octobre 2026) : « tout à la fin un play test en vidéo de deux
## minutes et une autre vidéo de 2 minutes en play edit », puis « rajoute de la lumière ambiante suffisante avec du sdfgi
## activé quand tu filmes ». Deux prises, sur le projet bâti par `batir_station.gd` :
##   --prise=jeu   le Play test : on naît dans le hangar, on traverse la station à pied jusqu'au belvédère ;
##   --prise=edit  le Play edit : depuis la vue du personnage, on bâtit avec la barre de World (pinceau, Room, Stairs,
##                 Tunnel, verre) dans le hangar et contre la coque.
##
## ⚠ ON FILME UNE COPIE (la leçon du monde client, 16 octobre 2026) : le dossier du projet est copié dans le user:// du
## worktree de tournage, ses chemins absolus réécrits ; « dernier » ne pointe nulle part ; seul le script ouvre la copie.
## ⚠ SDFGI ne voit pas une géométrie posée après coup (charte §3, « l'éclairage ») : en Play edit, ce qu'on bâtit peut
## rester mal éclairé un moment — l'ambiante forte est là pour ça.
##
## LANCEMENT (avec fenêtre, sur le PC) :
##   Godot_v4.7-stable_win64_console.exe --path <worktree> --fixed-fps 30 --write-movie <rush>.avi \
##       --script res://DEV_TOOLS/filmer_station.gd -- --prise=jeu|edit
## Les lignes « PLAN <nom> image <n> » donnent les coupes.

var SOURCE := "C:/Users/jorda/Documents/MarchingBlocks/station"
const COPIE := "user://station_tournage"
const PAD := Vector3(-42.5, 0.0, 6.5)

var _prise := "jeu"
var _projet_copie := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--prise="):
			_prise = a.substr("--prise=".length())
		elif a.begins_with("--source="):
			SOURCE = a.substr("--source=".length())
	if FileAccess.file_exists(SAUVEGARDE):
		DirAccess.copy_absolute(SAUVEGARDE, REGLAGES)
	if FileAccess.file_exists(REGLAGES):
		DirAccess.copy_absolute(REGLAGES, SAUVEGARDE)
	_projet_copie = _copier_le_projet()
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", "")
	r.set_value("projet", "monde", "")
	r.set_value("guide", "visible", false)
	r.set_value("infos", "visible", false)
	r.set_value("infos", "silhouette", false)
	r.save(REGLAGES)
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	Input.use_accumulated_input = false
	_derouler.call_deferred()


## La copie du projet : tout le dossier, puis les chemins absolus réécrits dans les fichiers texte (.mbproj, .mbtiles).
func _copier_le_projet() -> String:
	var dest := ProjectSettings.globalize_path(COPIE).replace("\\", "/")
	_vider(dest)
	_copier_dossier(SOURCE, dest)
	for f in _fichiers(dest):
		if f.get_extension() in ["mbproj", "mbtiles"]:
			var t := FileAccess.get_file_as_string(f)
			var w := FileAccess.open(f, FileAccess.WRITE)
			w.store_string(t.replace(SOURCE, dest))
			w.close()
	return dest.path_join("station.mbproj")


func _copier_dossier(de: String, vers: String) -> void:
	DirAccess.make_dir_recursive_absolute(vers)
	for f in DirAccess.get_files_at(de):
		DirAccess.copy_absolute(de.path_join(f), vers.path_join(f))
	for d in DirAccess.get_directories_at(de):
		if d != "photos":
			_copier_dossier(de.path_join(d), vers.path_join(d))


func _fichiers(d: String) -> Array:
	var sortie := []
	for f in DirAccess.get_files_at(d):
		sortie.append(d.path_join(f))
	return sortie


func _derouler() -> void:
	await _images(60)
	if not await _ecran._ouvrir(_projet_copie):
		print("⚠ la copie ne s'ouvre pas : %s" % _projet_copie)
		_rendre_les_reglages()
		quit(1)
		return
	_vue = _ecran._vue
	for i in _ecran._couches.size():
		_couche[str(_ecran._couches[i].get("nom", ""))] = i
	if _ecran._legende_formes != null:
		_ecran._legende_formes.basculer(false, false)
	await _ecran._changer_d_atelier("monde")
	_aides()
	_regler_l_espace()
	if _prise == "edit":
		await _prise_edit()
	else:
		await _prise_jeu()
	_rendre_les_reglages()
	quit(0)


## L'espace : un ciel noir, une étoile pour soleil, une ambiante bleutée assez forte pour qu'aucun coin ne soit noir,
## SDFGI (la lumière des panneaux et du plasma qui rebondit), SSAO, SSIL, un halo pour l'émission.
func _regler_l_espace() -> void:
	for r in [["ciel_haut", Color.BLACK], ["ciel_horizon", Color("#02030a")], ["ciel_sol", Color.BLACK],
			["soleil_disque", true], ["soleil_disque_taille", 1.2], ["soleil_disque_eclat", 10.0],
			["soleil_energie", 1.7], ["soleil_hauteur", 62.0], ["soleil_azimut", 140.0], ["soleil_couleur", Color("#e8eeff")],
			# ⚠ SDFGI REMPLACE L'AMBIANTE DANS CE QUI EST COUVERT (vu au premier tournage : le hangar et l'hydroponie noirs) :
			# l'ambiante au plus fort, l'exposition relevée, et la lumière vient surtout de l'émission des matières.
			["ambiante_couleur", Color("#7888b0")], ["ambiante_energie", 3.0], ["sdfgi", true], ["ssao", true],
			["ssil", true], ["glow", true], ["glow_intensite", 1.1], ["brouillard", false], ["tonemap", 2],
			["exposition", 1.4]]:
		_vue.regler_rendu(r[0], r[1])


func _entrer_dans(atelier_bouton: String) -> CharacterBody3D:
	_vue._cible = PAD
	_cam_haut = false
	_cam_d = 4.0
	_cam_e = 0.3
	await _cliquer_bouton(atelier_bouton, "")
	await _bouger(Vector2(root.size.x + 40, root.size.y + 40), 0.2)
	await _images(int(1.5 * FPS))
	return _vue.personnage


func _courir(oui: bool) -> void:
	_cle(KEY_SHIFT, oui)


# ── LE PLAY TEST ─────────────────────────────────────────────────────────────────────────────────────

func _prise_jeu() -> void:
	var p := await _entrer_dans("Play test")
	if p == null:
		print("⚠ pas de personnage")
		return
	_plan("jeu_hangar")
	_vue._azimut = PI * 0.35
	_montrer("Play test", "The hangar, open to space")
	await _regarder_autour(4.5)
	_courir(true)
	await _aller([Vector3(-40.0, 0, 0.5), Vector3(-34.0, 0, 0.5), Vector3(-23.0, 0, 0.5)], "Hangar", "Into the spine corridor")
	_courir(false)
	_plan("jeu_hydroponie")
	await _aller([Vector3(-23.0, 0, 6.0), Vector3(-23.0, 0, 15.0)], "Hydroponics", "Grow lights, irrigation, a glass roof")
	_cam_d = 5.0
	_cam_e = 0.45
	await _regarder_autour(5.0)
	_cam_d = 4.0
	_cam_e = 0.3
	await _aller([Vector3(-23.0, 0, 0.5), Vector3(-23.0, 0, -8.0), Vector3(-23.0, 0, -14.0)], "Lab", "White tiles, a lit ceiling")
	_cam_d = 5.0
	_cam_e = 0.4
	await _regarder_autour(4.0)
	_cam_d = 4.0
	_cam_e = 0.3
	_courir(true)
	await _aller([Vector3(-23.0, 0, -6.0), Vector3(-23.0, 0, 0.5), Vector3(-10.0, 0, 0.5), Vector3(0.5, 0, 0.5)], "Spine",
		"Portholes onto the solar wings")
	_courir(false)
	_plan("jeu_commandement")
	await _aller([Vector3(0.5, 0, -6.0), Vector3(0.5, 0, -13.5)], "Data core", "Scrolling data walls")
	await _aller([Vector3(-2.5, 0, -21.0)], "Command deck", "Screens, a hologram, the observation bay")
	_cam_d = 5.5
	_cam_e = 0.35
	await _regarder_autour(5.5)
	_cam_d = 4.0
	_cam_e = 0.3
	_courir(true)
	await _aller([Vector3(0.5, 0, -12.0), Vector3(0.5, 0, 0.5), Vector3(22.0, 0, 0.5)], "Spine", "East, past the portholes")
	_courir(false)
	_plan("jeu_quartiers")
	# (la table des quartiers est en x 20..23, z 10..11 : on la contourne par l'est)
	await _aller([Vector3(22.0, 0, 8.0), Vector3(26.0, 0, 9.0), Vector3(26.0, 0, 13.0)], "Crew quarters", "Cabins, warm lights")
	_cam_d = 5.0
	_cam_e = 0.4
	await _regarder_autour(4.5)
	_cam_d = 4.0
	_cam_e = 0.3
	await _aller([Vector3(26.0, 0, 9.0), Vector3(22.0, 0, 7.0), Vector3(23.0, 0, 0.5)], "Spine", "To the reactor")
	_plan("jeu_reacteur")
	await _aller([Vector3(23.0, 0, -8.0), Vector3(23.0, 0, -15.0)], "Reactor", "Plasma core, coolant under glass")
	_cam_d = 6.0
	_cam_e = 0.5
	await _regarder_autour(5.5)
	# La fin : la caméra s'élève au-dessus du cœur.
	_cam_d = 9.0
	_cam_e = 1.0
	await _images(int(5.0 * FPS))
	_plan("jeu_fin")
	await _touche(KEY_ESCAPE, "Esc", "Back to World")


# ── LE PLAY EDIT ─────────────────────────────────────────────────────────────────────────────────────

## ⚠ LE PLAY EDIT VISE CE QUE LA CAMÉRA VOIT (essais du 17 octobre 2026) : un point du monde choisi d'avance tombait hors de
## l'image (au-dessus, sous les panneaux), et le clic partait sur un bouton. Chaque geste commence par `_viser` : la caméra
## se tourne vers le point, recule et monte jusqu'à ce qu'il soit DANS la vue. Les outils et les formes sont choisis par
## l'écran lui-même (un clic sur un bouton d'une barre qui défile tombait à côté), la carte le dit à l'image.
func _prise_edit() -> void:
	_ecran._activer(_couche["Hull"])
	var p := await _entrer_dans("Play edit")
	if p == null:
		print("⚠ pas de personnage")
		return
	_plan("edit_debut")
	_montrer("Play edit", "Walk around, and build with the World tools")
	await _regarder_autour(3.0)
	_compter("depart")
	# 1. LE PINCEAU : un muret devant soi, puis on l'annule.
	await _aller([Vector3(-44.0, 0, 7.5)], "W A S D", "Walk across the hangar")
	_brosse("ajouter", "cube", "Add · brush: Cube")
	await _viser(Vector3(-44.0, 0.5, 10.5))
	await _peindre_monde(Vector3(-46.0, 0.5, 10.5), Vector3(-42.0, 0.5, 10.5), 1.6, "Left drag", "Paint a low wall")
	await _peindre_monde(Vector3(-46.0, 0.9, 10.5), Vector3(-42.0, 0.9, 10.5), 1.2, "Left drag", "One more row")
	_compter("muret")
	await _images(int(0.8 * FPS))
	await _touche(KEY_Z, "Ctrl + Z", "Undo", true)
	await _touche(KEY_Z, "Ctrl + Z", "Undo", true)
	_compter("annule")
	# 2. UN TUNNEL dans la coque sud : une fenêtre sur l'espace.
	_plan("edit_tunnel")
	_speciale("tunnel", "arche", 3, "Special shape: Tunnel · Arch")
	await _cliquer_monde(Vector3(-44.0, 1.5, 12.95), "Click a wall", "Tunnel through the hull")
	_compter("tunnel")
	_cam_d = 4.0
	_cam_e = 0.3
	await _aller([Vector3(-44.0, 0, 12.0), Vector3(-44.0, 1, 13.8)], "W A S D · Space", "A window onto space", true)
	_cam_d = 5.0
	_cam_e = 0.15
	await _regarder_autour(3.5)
	# 3. UNE SALLE tracée au sol, à l'ouest ; un escalier contre son mur est.
	_plan("edit_salle")
	_cam_d = 4.0
	_cam_e = 0.3
	await _aller([Vector3(-44.0, 0, 11.5), Vector3(-44.0, 0, 9.0), Vector3(-38.0, 0, 8.5)], "W A S D", "Find some room", true)
	_speciale("salle", "", 0, "Special shape: Room")
	await _viser(Vector3(-53.5, 0.0, 8.5))
	await _peindre_monde(Vector3(-51.5, 0.0, 5.5), Vector3(-55.5, 0.0, 11.5), 1.4, "Left drag", "Draw a room on the floor")
	await _images(int(1.0 * FPS))
	_compter("salle")
	_plan("edit_escalier")
	_speciale("escalier", "", 3, "Special shape: Stairs")
	await _cliquer_monde(Vector3(-51.45, 3.5, 8.5), "Click a wall", "Stairs up to the roof")
	_compter("escalier")
	_cam_d = 6.0
	_cam_e = 0.45
	await _aller([Vector3(-41.5, 0, 8.5), Vector3(-50.5, 4, 8.5), Vector3(-53.5, 4, 8.5)], "W A S D · Space", "Climb", true)
	_cam_d = 7.0
	_cam_e = 0.6
	await _regarder_autour(3.0)
	# 4. DU VERRE sur le toit, puis on CREUSE le toit et l'on saute dedans.
	_plan("edit_verre")
	_ecran._activer(_couche["Glass"])
	_montrer("Layer: Glass", "Each layer has its own witness and materials")
	await _images(int(1.0 * FPS))
	_brosse("ajouter", "cube", "Add · brush: Cube")
	await _viser(Vector3(-55.0, 4.5, 8.5))
	await _peindre_monde(Vector3(-55.0, 4.5, 6.0), Vector3(-55.0, 4.5, 11.0), 1.4, "Left drag", "Glass on the roof")
	_compter("verre")
	_plan("edit_creuser")
	_ecran._activer(_couche["Hull"])
	_brosse("creuser", "sphere", "Dig · brush: Sphere")
	await _viser(Vector3(-53.0, 4.5, 10.5))
	await _peindre_monde(Vector3(-53.0, 4.5, 10.0), Vector3(-53.0, 4.5, 11.0), 0.6, "Left drag", "Dig through the roof")
	await _images(int(0.6 * FPS))
	_compter("creuser")
	# On redescend par l'escalier, et la caméra recule sur tout ce qu'on a bâti.
	_cam_d = 6.0
	_cam_e = 0.45
	await _aller([Vector3(-50.5, 4, 8.5), Vector3(-41.5, 0, 8.5), Vector3(-38.5, 0, 6.5)], "W A S D", "Back down the stairs")
	_plan("edit_recul")
	_montrer("Play edit", "A room, stairs, glass, a hole and a tunnel — built on foot")
	await _tourner_vers(PI * 0.45)
	_cam_d = 18.0
	_cam_e = 0.7
	await _images(int(7.0 * FPS))
	_plan("edit_fin")


func _brosse(outil: String, forme: String, carte: String) -> void:
	_ecran._choisir_outil(outil)
	_ecran._choisir_forme(forme)
	_montrer(carte, "")


func _speciale(quoi: String, profil: String, taille: int, carte: String) -> void:
	_ecran._choisir_forme_speciale(quoi)
	if profil != "":
		_ecran._choisir_le_profil(profil)
	if taille > 0:
		_vue.forme_speciale["taille"] = taille
		_ecran._contexte_des_outils()
	_montrer(carte, "")


## La caméra se tourne vers `point` et recule, monte, jusqu'à le voir au milieu de la vue (pas sous un panneau).
func _viser(point: Vector3) -> void:
	var p: CharacterBody3D = _vue.personnage
	var d := point - p.global_position
	var az := atan2(-d.x, -d.z)
	await _tourner_vers(az)
	var zone: Rect2 = (_vue as Control).get_global_rect().grow(-140)
	for essai in 6:
		await _images(int(1.4 * FPS))
		var e := _sur(point)
		if zone.has_point(e):
			print("VISÉE %s : à l'écran en %s (essai %d)" % [point, e, essai])
			return
		# Un point trop HAUT à l'écran : la caméra regarde plus à l'horizontale (l'élévation baisse) ; trop bas : elle plonge.
		_cam_d = minf(_cam_d + 1.0, 10.0)
		_cam_e = clampf(_cam_e + (-0.12 if e.y < zone.get_center().y else 0.12), -0.05, 1.2)
	print("⚠ VISÉE %s : hors de la vue (%s)" % [point, _sur(point)])


func _cliquer_monde(point: Vector3, carte: String, detail: String) -> void:
	await _viser(point)
	await _bouger(_sur(point), 0.8)
	_sonder(point)
	await _clic(MOUSE_BUTTON_LEFT, carte, detail)
	await _images(int(0.8 * FPS))


## La caméra tourne (en douceur) jusqu'à regarder dans la direction de l'azimut donné.
func _tourner_vers(az: float) -> void:
	var a0: float = _vue._azimut
	var n := int(0.8 * FPS)
	for i in n:
		_vue._azimut = lerp_angle(a0, az, _doux(float(i + 1) / n))
		await _images(1)
	await _images(6)


## Peindre d'un point du monde à un autre : la souris suit leur projection à l'écran, bouton tenu.
func _sonder(a: Vector3) -> void:
	var sous: Control = root.gui_get_hovered_control()
	print("SONDE clic %s (monde %s) sur %s" % [_souris, a, sous.get_class() if sous else "rien"])


func _peindre_monde(a: Vector3, b: Vector3, duree: float, carte: String, detail: String) -> void:
	await _bouger(_sur(a), 0.5)
	_montrer(carte, detail)
	var sous: Control = root.gui_get_hovered_control()
	print("SONDE souris %s (monde %s) sur %s ; outil %s, visée %s, peint %s, atelier %s" % [_souris, a,
		sous.get_path() if sous else "rien", _vue.outil, _vue.visee, _vue.peint(), _ecran._atelier])
	_presser(MOUSE_BUTTON_LEFT, true)
	var n := maxi(1, int(duree * FPS))
	for i in n:
		var q := a.lerp(b, float(i + 1) / n)
		var avant := _souris
		_souris = _sur(q)
		var m := InputEventMouseMotion.new()
		m.position = _souris
		m.global_position = _souris
		m.relative = _souris - avant
		m.button_mask = _masque
		_envoyer(m)
		await _images(1)
	_presser(MOUSE_BUTTON_LEFT, false)
	await _images(int(0.4 * FPS))


func _glisser_monde(a: Vector3, b: Vector3, duree: float, carte: String, detail: String) -> void:
	await _peindre_monde(a, b, duree, carte, detail)


## Le compte des cases de chaque couche : dit, après chaque geste du Play edit, ce qui a vraiment été posé ou creusé.
var _avant := {}


func _compter(quoi: String) -> void:
	if _ecran._manuel != null and _ecran._manuel.visible:
		_ecran._manuel.visible = false
		print("⚠ le manuel était ouvert : fermé")
	var n := {}
	for nom in _couche:
		var g := _vue.couche(_couche[nom]).get_node("Cases") as GridMap
		n[nom] = g.get_used_cells().size()
	var d := []
	for nom in n:
		if _avant.has(nom) and int(n[nom]) != int(_avant[nom]):
			d.append("%s %+d" % [nom, int(n[nom]) - int(_avant[nom])])
	var p: CharacterBody3D = _vue.personnage
	print("GESTE %s : %s — stickman en %s — « %s »" % [quoi, ", ".join(d) if not d.is_empty() else "rien",
		p.global_position if p else "?", (_ecran._rapport.text as String).left(160) if _ecran._rapport else ""])
	_avant = n


## Comme `filmer_haut._images`, mais en Play edit AUSSI (son atelier est « jeu_edit » : la caméra n'y suivait pas les
## réglages, et chaque visée restait hors de la vue — mesuré le 17 octobre 2026).
func _images(n: int) -> void:
	for i in n:
		await process_frame
		_image += 1
		_carte_age += 1.0 / FPS
		if _ecran != null and _ecran._atelier in ["jeu", "jeu_edit"] and _vue != null:
			_vue._distance = lerpf(_vue._distance, _cam_d, 0.06)
			_vue._elevation = lerpf(_vue._elevation, _cam_e, 0.06)
		if _dessin != null:
			_dessin.queue_redraw()
