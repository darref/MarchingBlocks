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

const SOURCE := "C:/Users/jorda/Documents/MarchingBlocks/station"
const COPIE := "user://station_tournage"
const PAD := Vector3(-42.5, 0.0, 6.5)

var _prise := "jeu"
var _projet_copie := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--prise="):
			_prise = a.substr("--prise=".length())
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
			["soleil_energie", 1.3], ["soleil_hauteur", 28.0], ["soleil_azimut", 140.0], ["soleil_couleur", Color("#e8eeff")],
			["ambiante_couleur", Color("#6878a0")], ["ambiante_energie", 2.2], ["sdfgi", true], ["ssao", true],
			["ssil", true], ["glow", true], ["glow_intensite", 1.1], ["brouillard", false], ["tonemap", 2],
			["exposition", 1.1]]:
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
	_courir(true)
	await _aller([Vector3(-23.0, 0, 0.5), Vector3(-10.0, 0, 0.5), Vector3(0.5, 0, 0.5)], "Spine", "Portholes onto the solar wings")
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
	await _aller([Vector3(0.5, 0, -12.0), Vector3(0.5, 0, 0.5), Vector3(23.0, 0, 0.5)], "Spine", "East, to the reactor")
	_courir(false)
	_plan("jeu_reacteur")
	await _aller([Vector3(23.0, 0, -8.0), Vector3(23.0, 0, -15.0)], "Reactor", "Plasma core, coolant pit")
	_cam_d = 6.0
	_cam_e = 0.5
	await _regarder_autour(5.5)
	_cam_d = 4.0
	_cam_e = 0.3
	_courir(true)
	await _aller([Vector3(23.0, 0, -6.0), Vector3(23.0, 0, 0.5), Vector3(36.0, 0, 0.5)], "Spine", "To the observation dome")
	_courir(false)
	_plan("jeu_belvedere")
	await _aller([Vector3(44.0, 0, 0.5)], "Observation dome", "Glass all around")
	_cam_d = 7.0
	_cam_e = 0.35
	await _regarder_autour(6.0)
	_cam_d = 14.0
	_cam_e = 0.9
	await _images(int(4.0 * FPS))
	_plan("jeu_fin")
	await _touche(KEY_ESCAPE, "Esc", "Back to World")


# ── LE PLAY EDIT ─────────────────────────────────────────────────────────────────────────────────────

func _prise_edit() -> void:
	_ecran._activer(_couche["Hull"])
	var p := await _entrer_dans("Play edit")
	if p == null:
		print("⚠ pas de personnage")
		return
	_plan("edit_debut")
	_vue._azimut = PI * 0.5
	_montrer("Play edit", "Walk around, and build with the World tools")
	await _regarder_autour(3.0)
	# 1. UNE PASSERELLE au pinceau : on peint devant soi, vers le nord du hangar.
	await _aller([Vector3(-46.0, 0, 6.0)], "W A S D", "Walk to the hangar floor")
	_vue._azimut = 0.0
	await _images(20)
	await _cliquer_bouton("Cube", "Brush: Cube")
	await _touche(KEY_A, "A", "Add")
	await _peindre_monde(Vector3(-50, 0, 3), Vector3(-41, 0, 3), 2.0, "Left drag", "Paint a low wall, from the character's view")
	await _peindre_monde(Vector3(-50, 1, 3), Vector3(-44, 1, 3), 1.4, "Left drag", "One more row")
	await _touche(KEY_Z, "Ctrl + Z", "Undo the stroke", true)
	await _touche(KEY_Y, "Ctrl + Y", "Redo", true)
	# 2. UNE SALLE (Room) tracée sur le sol du hangar, montée de trois étages.
	_plan("edit_room")
	await _aller([Vector3(-40.0, 0, -4.0)], "W A S D", "Find some room")
	_vue._azimut = PI * 0.75
	await _images(15)
	await _cliquer_bouton("Room", "Special shape: Room")
	await _glisser_monde(Vector3(-50, 0, -9), Vector3(-44, 0, -5), 1.4, "Left drag", "Draw a room on the floor")
	await _images(int(1.0 * FPS))
	# 3. UN ESCALIER contre la nouvelle salle, et on monte sur son toit.
	_plan("edit_stairs")
	await _cliquer_bouton("Stairs", "Special shape: Stairs")
	await _bouger(_sur(Vector3(-45.0, 3.5, -4.4)), 0.8)
	await _clic(MOUSE_BUTTON_LEFT, "Click a wall", "Stairs up to the roof")
	await _images(int(1.0 * FPS))
	await _aller([Vector3(-46.5, 0, 0.0), Vector3(-46.5, 3, -4.0), Vector3(-47.5, 4, -7.0)], "W A S D", "Climb", true)
	_cam_d = 6.0
	_cam_e = 0.45
	await _regarder_autour(3.0)
	_cam_d = 4.0
	_cam_e = 0.3
	# 4. DU VERRE : une baie dans le mur du hangar, la couche Glass.
	_plan("edit_verre")
	_ecran._activer(_couche["Glass"])
	_montrer("Layer: Glass", "Each layer is its own witness and materials")
	await _aller([Vector3(-47.5, 4, -9.0)], "W A S D", "To the hangar wall")
	_vue._azimut = 0.0
	await _images(15)
	await _cliquer_bouton("Cube", "Brush: Cube")
	await _touche(KEY_A, "A", "Add")
	await _peindre_monde(Vector3(-52, 6, -13), Vector3(-42, 6, -13), 1.8, "Left drag", "Glass into the hangar wall")
	await _images(int(1.0 * FPS))
	# 5. UN TUNNEL dans le mur du hangar vers le nord, puis on saute en bas et on y entre.
	_plan("edit_tunnel")
	_ecran._activer(_couche["Deck"])
	await _aller([Vector3(-47.5, 4, -5.0), Vector3(-40.0, 0, -9.0)], "W A S D", "Down again", true)
	_vue._azimut = 0.0
	await _images(15)
	await _cliquer_bouton("Tunnel", "Special shape: Tunnel")
	await _bouger(_sur(Vector3(-38.5, 1.2, -12.6)), 0.8)
	await _clic(MOUSE_BUTTON_LEFT, "Click a wall", "Tunnel through the hull")
	await _images(int(1.0 * FPS))
	await _aller([Vector3(-38.5, 0, -14.0), Vector3(-38.5, 0, -18.0)], "W A S D", "Walk through it")
	_vue._azimut = PI
	await _regarder_autour(3.0)
	# 6. CREUSER : Dig, on ouvre une fenêtre dans la coque.
	_plan("edit_dig")
	await _cliquer_bouton("Sphere", "Brush: Sphere")
	await _touche(KEY_D, "D", "Dig")
	await _peindre_monde(Vector3(-36.0, 1.5, -16.0), Vector3(-36.0, 1.5, -18.0), 1.2, "Left drag", "Dig a hole in the hull")
	await _images(int(1.5 * FPS))
	await _aller([Vector3(-38.5, 0, -12.0), Vector3(-42.0, 0, 2.0)], "W A S D", "Back to the hangar")
	_cam_d = 12.0
	_cam_e = 0.7
	await _regarder_autour(5.0)
	_plan("edit_fin")
	await _touche(KEY_ESCAPE, "Esc", "Back to World")


## Peindre d'un point du monde à un autre : la souris suit leur projection à l'écran, bouton tenu.
func _peindre_monde(a: Vector3, b: Vector3, duree: float, carte: String, detail: String) -> void:
	await _bouger(_sur(a), 0.5)
	_montrer(carte, detail)
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
