extends "res://DEV_TOOLS/filmer_scifi.gd"
##
## DEVLOG — L'ATELIER ANIMATION : LES TEXTURES ANIMÉES. Demandé par Jordan (6 octobre 2026 : « fait un dev log pour chaque
## nouveauté »). L'atelier tel qu'il marche : un matériau du témoin, « + » une piste (canal × source), SES seuls réglages,
## chaque geste changeant l'image en direct ; puis le monde peint où tout bouge, et le Play test (ciel noir, glow).
##
## ⚠ LE TERRAIN : la station de `filmer_scifi.gd` (ses modules, sa traversée), mais dans un PROJET À NOUS, dans les données
## de la copie de tournage (`user://station_anim/`) — le projet « scifi » de Jordan (`Documents/MarchingBlocks/scifi/`)
## n'est JAMAIS ouvert. Trois matières y sont remplacées par leurs variantes faites pour bouger
## (`SpannerGames/PROJETS/MarchingBlocks/01_scripts/textures_animation.py` → `BIBLIOTHEQUE/textures/anim/`) :
##   - Lab, murs : `lab_screen` (écran vide à l'albedo) + 24 images d'émission (une SÉQUENCE) ;
##   - Reactor, murs : `reactor_conduit` (paquets d'énergie le long de v) → un défilement en v ;
##   - Reactor, plafond : `reactor_fan` + deux PLANCHES 4 × 4 (couleur de base et émission) → les pales tournent ;
##   - Reactor, sol : `reactor_floor` de la station → une pulsation de l'émission.
##
## ⚠ CE QUE LE PRODUIT FAIT, ET RIEN DE PLUS (charte du produit, « l'atelier Animation ») : les greffons ne jouent pas
## encore l'animation (ils reçoivent l'image 0) — on ne montre aucun moteur. Le défilement est en v (les quarts de tour
## ne le touchent pas) ; un défilement en u partirait dans le sens de chaque copie.
## ⚠ LE DIALOGUE DE FICHIERS est natif (Windows) : il ne se pilote pas par événements. Le script vise « Add track »,
## puis donne au dialogue ce que la main y aurait choisi (`_fichiers_choisis`, le chemin du produit APRÈS le dialogue) ;
## la carte de touche dit ce qui est choisi.
##
## LANCEMENT — dans la COPIE de tournage D:/MB_tournage_animation (`custom_user_dir_name="MB_tournage_animation"`) :
##   cp D:/MarchingBlocks/DEV_TOOLS/filmer_animation.gd D:/MB_tournage_animation/DEV_TOOLS/
##   Godot_v4.7-stable_win64_console.exe --path D:/MB_tournage_animation --fixed-fps 30 \
##       --write-movie D:/SpannerGames/PROJETS/MarchingBlocks/02_rushes/animation.avi \
##       --script res://DEV_TOOLS/filmer_animation.gd
##   `-- --seulement=<partie>` : atelier, monde, jeu (le projet, ses textures et la station sont toujours refaits).

const ANIM := "D:/SpannerGames/BIBLIOTHEQUE/textures/anim"
const DOSSIER_ANIM := "user://station_anim"
## Couche → [sol, mur, plafond] : le dossier de l'ensemble PBR de chacun (sous TEXTURES ou ANIM).
const MATIERES := {
	"Hull": [TEXTURES + "/hull_floor", TEXTURES + "/hull_wall", TEXTURES + "/hull_ceiling"],
	"Lab": [TEXTURES + "/lab_floor", ANIM + "/lab_screen", TEXTURES + "/lab_ceiling"],
	"Reactor": [TEXTURES + "/reactor_floor", ANIM + "/reactor_conduit", ANIM + "/reactor_fan"],
}

var _projet_anim := ""


## Comme `filmer_ui._initialize`, SANS l'exemple : il n'est pas dans une copie git (`exemple/exemple.zip` est ignoré), et
## ce tournage ouvre son propre projet. Les réglages de la copie sont sauvés, puis rendus à la fin.
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seulement="):
			_seulement = a.substr("--seulement=".length())
	if FileAccess.file_exists(SAUVEGARDE):
		DirAccess.copy_absolute(SAUVEGARDE, REGLAGES)
	if FileAccess.file_exists(REGLAGES):
		DirAccess.copy_absolute(REGLAGES, SAUVEGARDE)
	_projet_anim = ProjectSettings.globalize_path(DOSSIER_ANIM).path_join("station.mbproj")
	_preparer_le_projet()
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", _projet_anim)
	r.save(REGLAGES)
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	Input.use_accumulated_input = false
	_derouler.call_deferred()


func _derouler() -> void:
	await _images(30)
	await _ecran._ouvrir(_projet_anim)
	_ecran._changer_d_atelier("monde")
	_ecran._legende_formes.basculer(false, false)
	_vue = _ecran._vue
	for i in _ecran._couches.size():
		_couche[str(_ecran._couches[i].get("nom", ""))] = i
	print("couches : %s" % [_couche])
	_aides()
	_plan("textures")
	await _textures_anim()
	_plan("station")
	await _s_station()
	await _images(10)
	for partie in ["atelier", "monde", "jeu"]:
		if _seulement != "" and _seulement != partie and partie != "atelier":
			continue
		_plan(partie)
		await Callable(self, "_a_" + partie).call()
		await _images(int(0.5 * FPS))
	_plan("fin")
	_ecran._enregistrer()
	_rendre_les_reglages()
	quit(0)


## Le projet neuf, À NOUS : dans les données de la copie de tournage, refait à chaque tournage.
func _preparer_le_projet() -> bool:
	var dossier := _projet_anim.get_base_dir()
	_vider(dossier)
	DirAccess.make_dir_recursive_absolute(dossier)
	var couches := []
	for i in COUCHES_SCIFI.size():
		couches.append({"nom": COUCHES_SCIFI[i]["nom"], "source": "", "visible": true, "cases": [], "temoin": "",
			"id": str(i + 1)})
	var f := FileAccess.open(_projet_anim, FileAccess.WRITE)
	f.store_string(JSON.stringify({"format": "marchingblocks-project", "version": 2, "active": 0,
		"couches": couches, "eaux": []}, "\t"))
	f.close()
	print("projet neuf : %s" % _projet_anim)
	return true


# ── 0. LES MATÉRIAUX (hors champ : le devlog de la station les a montrés) ─────────────────────────────

func _textures_anim() -> void:
	for i in COUCHES_SCIFI.size():
		var d: Dictionary = COUCHES_SCIFI[i]
		_ecran._activer(_couche[d["nom"]])
		await _ecran._changer_d_atelier("texture")
		_ecran._regler_edition(true)
		await _images(10)
		var mo = _ecran._modeleur
		var t = mo.temoin
		var ks := {}
		var roles := ["sol", "mur", "plafond"]
		for r in 3:
			var k: int = mo.nouveau_materiau()
			var chemin: String = MATIERES[d["nom"]][r]
			var nom: String = chemin.get_file()
			_ecran._action_fichier = "texture"
			_ecran._fichier_choisi("%s/%s_albedo.png" % [chemin, nom])
			mo.regler_materiau(k, "nom", nom)
			mo.regler_materiau(k, "echelle", 1.0)
			mo.regler_materiau(k, "projection", "boite")
			mo.regler_materiau(k, "metal", d["metal"])
			mo.regler_materiau(k, "rugosite", d["rugosite"])
			mo.regler_materiau(k, "emission", 4.0)
			ks[roles[r]] = k
			await _images(2)
		for cle in t.tuiles:
			var tu = t.tuiles[cle]
			var par := {"sol": [], "mur": [], "plafond": []}
			for f in tu.faces.size():
				var ny: float = tu.normale(f).y
				par["sol" if ny > 0.7 else ("plafond" if ny < -0.7 else "mur")].append(f)
			for role in par:
				if not (par[role] as Array).is_empty():
					tu.assigner(par[role], ks[role])
		mo.redessiner()
		mo._rafraichir_les_tuiles_qui_portent(-2)
		_ecran._temoin_modifie(t)
		_ecran._enregistrer_le_temoin_modele(true)
		_ecran._regler_edition(false)
		print("couche %s : matériaux %s" % [d["nom"], ks])
	await _ecran._changer_d_atelier("monde")


# ── 1. L'ATELIER ─────────────────────────────────────────────────────────────────────────────────────

func _a_atelier() -> void:
	var an = _ecran._animation
	# LE LABO : 24 images d'émission sur les écrans.
	await _choisir_la_couche("Lab")
	await _cliquer_bouton("Animation", "The Animation workshop")
	_cadrer_le_temoin(0.15)
	await _images(int(1.0 * FPS))
	await _images(int(0.8 * FPS))
	await _cliquer_debut("lab_screen", "Pick a material of the witness: the lab wall")
	await _images(int(0.6 * FPS))
	await _choisir_dans_la_liste(an._canal, "Emission", "Map: Emission")
	await _choisir_dans_la_liste(an._source, "Frames from image files…", "Source: frames from image files")
	await _ajouter_des_images(an, "emission", "fichiers", _sequence(ANIM + "/lab_screen_frames"),
		"24 PNG frames, screen_000 … screen_023")
	await _derive_temoin(4.0)
	await _glisser_curseur(_curseur_de("Emission · Frames", 0), 4.0, "Drag", "Frames/s: slower")
	await _derive_temoin(2.0)
	await _glisser_curseur(_curseur_de("Emission · Frames", 0), 24.0, "Drag", "Frames/s: faster")
	await _derive_temoin(2.0)
	await _glisser_curseur(_curseur_de("Emission · Frames", 0), 12.0, "Drag", "Frames/s: 12")
	await _cocher(_case_de("Emission · Frames", "Copies in sync"), "Click", "Copies in sync: every screen plays together")
	await _derive_temoin(3.5)
	await _cocher(_case_de("Emission · Frames", "Copies in sync"), "Click", "Unticked: each copy starts at its own moment")
	await _derive_temoin(3.0)

	# LE RÉACTEUR : un défilement sur les conduits, une pulsation sous la grille, un ventilateur en planches.
	await _choisir_la_couche("Reactor")
	# Prise 2 : à 0,42 × la diagonale et rasante, la caméra était DANS le témoin du réacteur (un canyon noir) — dehors.
	_cadrer_le_temoin(0.3, 0.75, 0.2)
	await _images(int(1.2 * FPS))
	await _cliquer_debut("reactor_conduit", "The reactor wall: two energy conduits")
	await _choisir_dans_la_liste(an._canal, "Emission", "Map: Emission")
	await _choisir_dans_la_liste(an._source, "Scroll", "Source: Scroll")
	await _cliquer_bouton("Add track", "Add track: the energy flows")
	await _derive_temoin(3.0)
	await _glisser_curseur(_curseur_de("Emission · Scroll", 1), -0.9, "Drag", "Along (v): faster, upward")
	await _derive_temoin(2.5)
	await _glisser_curseur(_curseur_de("Emission · Scroll", 1), 0.5, "Drag", "Along (v): downward")
	await _derive_temoin(2.0)
	await _glisser_curseur(_curseur_de("Emission · Scroll", 1), -0.6, "Drag", "Along (v): up again")
	await _derive_temoin(1.5)

	_cadrer_le_temoin(0.85, 0.8, 0.1)
	await _cliquer_debut("reactor_floor", "The reactor floor: the glow under the grate")
	await _choisir_dans_la_liste(an._canal, "Emission", "Map: Emission")
	await _choisir_dans_la_liste(an._source, "Pulse", "Source: Pulse")
	await _cliquer_bouton("Add track", "Add track: the emission breathes")
	await _derive_temoin(3.0)
	await _glisser_curseur(_curseur_de("Emission · Pulse", 0), 1.2, "Drag", "Beats/s: faster")
	await _glisser_curseur(_curseur_de("Emission · Pulse", 1), 0.0, "Drag", "Low: down to dark")
	await _derive_temoin(3.0)
	await _cocher(_case_de("Emission · Pulse", "Copies in sync"), "Click", "Copies in sync: one heartbeat")
	await _derive_temoin(3.5)
	await _cocher(_case_de("Emission · Pulse", "Copies in sync"), "Click", "Out of sync: a ripple of lights")
	await _derive_temoin(2.0)

	_cadrer_le_temoin(-0.45, 0.7, 0.2)
	await _cliquer_debut("reactor_fan", "The reactor ceiling: a fan")
	await _choisir_dans_la_liste(an._canal, "Base colour", "Map: Base colour")
	await _choisir_dans_la_liste(an._source, "Frames from a sheet…", "Source: a sprite sheet")
	await _ajouter_des_images(an, "albedo", "planche", PackedStringArray([ANIM + "/reactor_fan/reactor_fan_albedo_sheet.png"]),
		"reactor_fan_albedo_sheet.png · 4 × 4")
	await _choisir_dans_la_liste(an._canal, "Emission", "Map: Emission")
	await _choisir_dans_la_liste(an._source, "Frames from a sheet…", "Source: a sprite sheet")
	await _ajouter_des_images(an, "emission", "planche", PackedStringArray([ANIM + "/reactor_fan/reactor_fan_emission_sheet.png"]),
		"reactor_fan_emission_sheet.png · 4 × 4")
	await _derive_temoin(4.0)
	# LA LECTURE : tout s'arrête, tout repart.
	await _cliquer_bouton("Pause", "Pause: every animated material stops")
	await _derive_temoin(1.5)
	await _cliquer_bouton("Play", "Play")
	await _glisser_curseur(an._vitesse, 3.0, "Drag", "Speed: ×3, for this session")
	await _derive_temoin(2.0)
	await _glisser_curseur(an._vitesse, 1.0, "Drag", "Speed: ×1")
	await _derive_temoin(1.5)


## Une couche active, d'un clic dans la liste des couches (sinon par l'écran).
func _choisir_la_couche(nom: String) -> void:
	var b := _bouton_qui(_ecran, func(x: Button) -> bool: return x.text.begins_with(nom + "\n"))
	# ⚠ PRISE 1 : la ligne « Reactor » dépassait le bas de la liste des couches (coupée par son ScrollContainer) ; le
	# clic tombait hors de la liste, la couche restait Lab — et toutes les pistes suivantes allaient aux matériaux du labo.
	# La molette fait défiler la liste jusqu'à ce que la ligne y tienne entière, PUIS on clique ; on vérifie après.
	if b != null:
		var defile: Node = b.get_parent()
		while defile != null and not defile is ScrollContainer:
			defile = defile.get_parent()
		if defile != null:
			var zone: Rect2 = (defile as Control).get_global_rect()
			if not zone.encloses(b.get_global_rect()):
				await _bouger(zone.get_center(), 0.4)
				var sens := MOUSE_BUTTON_WHEEL_DOWN if b.get_global_rect().end.y > zone.end.y else MOUSE_BUTTON_WHEEL_UP
				for i in 30:
					if zone.encloses(b.get_global_rect()):
						break
					_presser(sens, true)
					_presser(sens, false)
					await _images(2)
				await _images(12)
		await _bouger(b.get_global_rect().get_center(), 0.5)
		await _clic(MOUSE_BUTTON_LEFT, "Click", "Layer %s" % nom)
	if _ecran._active != _couche[nom]:
		print("⚠ la couche %s n'a pas pris le clic : activée par l'écran" % nom)
		_ecran._activer(_couche[nom])
		_montrer("Layers", "Layer %s" % nom)
	print("couche active : %s" % _ecran._couches[_ecran._active]["nom"])
	await _images(int(0.8 * FPS))
	_ecran._animation.redire()


func _bouton_qui(n: Node, f: Callable) -> Button:
	if n is Button and (n as Button).is_visible_in_tree() and f.call(n):
		return n
	for e in n.get_children():
		var t := _bouton_qui(e, f)
		if t != null:
			return t
	return null


## Un bouton dont le texte COMMENCE par `debut` (un matériau animé dit « · 1 track » après son nom).
func _cliquer_debut(debut: String, detail: String) -> void:
	var b := _bouton_qui(_ecran._droite_animation, func(x: Button) -> bool: return x.text.begins_with(debut))
	if b == null:
		print("⚠ bouton introuvable : %s" % debut)
		return
	await _bouger(b.get_global_rect().get_center(), 0.6)
	await _clic(MOUSE_BUTTON_LEFT, "Click", detail)


## « Add track » d'une source d'images : la souris clique le bouton, le dialogue natif reçoit ce que la main y choisit.
func _ajouter_des_images(an, canal: String, source: String, fichiers: PackedStringArray, carte: String) -> void:
	var b := _bouton(_ecran._droite_animation, "Add track")
	if b == null:
		print("⚠ Add track introuvable")
		return
	await _bouger(b.get_global_rect().get_center(), 0.6)
	_montrer("Add track", "then, in the file dialog: " + carte)
	await _images(int(1.4 * FPS))
	an._en_attente = {"canal": canal, "source": source}
	an._fichiers_choisis(fichiers)
	await _images(int(0.6 * FPS))
	print("pistes : %s" % [an.animation_courante().keys()])


func _sequence(dossier: String) -> PackedStringArray:
	var l := PackedStringArray()
	for f in DirAccess.get_files_at(dossier):
		if f.ends_with(".png"):
			l.append(dossier.path_join(f))
	return l


## La carte d'une piste (« Emission · Frames ») dans la barre.
func _carte_de(titre: String) -> Control:
	for c in _ecran._animation._pistes.get_children():
		for l in c.find_children("*", "Label", true, false):
			if (l as Label).text == titre:
				return c
	print("⚠ carte introuvable : %s" % titre)
	return null


func _curseur_de(titre: String, rang: int) -> HSlider:
	var c := _carte_de(titre)
	if c == null:
		return null
	var l := c.find_children("*", "HSlider", true, false)
	return (l[rang] as HSlider) if rang < l.size() else null


func _case_de(titre: String, texte: String) -> CheckBox:
	var c := _carte_de(titre)
	if c == null:
		return null
	for x in c.find_children("*", "CheckBox", true, false):
		if (x as CheckBox).text == texte:
			return x
	return null


## Un glissé sur un curseur, de sa valeur à `valeur` (de vrais événements : appui, mouvement, relâche).
func _glisser_curseur(s: HSlider, valeur: float, carte: String, detail: String) -> void:
	if s == null:
		print("⚠ curseur introuvable : %s" % detail)
		return
	var r := s.get_global_rect()
	var x_de := func(v: float) -> float:
		var t := (v - s.min_value) / (s.max_value - s.min_value)
		return r.position.x + 8.0 + t * (r.size.x - 16.0)
	await _bouger(Vector2(x_de.call(s.value), r.get_center().y), 0.5)
	_montrer(carte, detail)
	_presser(MOUSE_BUTTON_LEFT, true)
	await _images(2)
	await _bouger(Vector2(x_de.call(valeur), r.get_center().y), 0.9)
	_presser(MOUSE_BUTTON_LEFT, false)
	await _images(int(0.3 * FPS))
	print("curseur %s → %.2f" % [detail, s.value])


func _cocher(c: CheckBox, carte: String, detail: String) -> void:
	if c == null:
		print("⚠ case introuvable : %s" % detail)
		return
	await _bouger(c.get_global_rect().get_center() + Vector2(-c.size.x * 0.5 + 12, 0), 0.5)
	await _clic(MOUSE_BUTTON_LEFT, carte, detail)


## La caméra sur le témoin de la couche active : son centre, de côté (les murs) ou d'en haut / d'en bas.
func _cadrer_le_temoin(elevation: float, recul := 0.42, coin := 0.45) -> void:
	var t = _ecran._modeleur.temoin
	if t == null:
		return
	var boite := AABB()
	var premier := true
	for o in t.occurrences:
		var p: Vector3 = (o["pose"] as Transform3D).origin
		if premier:
			boite = AABB(p, Vector3.ZERO)
			premier = false
		else:
			boite = boite.expand(p)
	# Prise 1 : à 0,85 × la diagonale, le témoin remplissait l'image sans qu'un détail se lise — plus près, un coin.
	var oeil := Vector3(boite.end.x, boite.get_center().y, boite.end.z)
	_vue._cible = boite.get_center().lerp(oeil, coin)
	_vue._azimut = 0.6
	_vue._elevation = elevation
	_vue._distance = maxf(boite.size.length() * recul, 8.0)
	_vue._caler()
	print("témoin : %s" % boite)


## La caméra dérive lentement autour du témoin, le temps de voir l'effet.
func _derive_temoin(duree: float) -> void:
	for i in int(duree * FPS):
		_vue._azimut += 0.0025
		_vue._caler()
		await _images(1)


# ── 2. LE MONDE PEINT : tout bouge ──────────────────────────────────────────────────────────────────

func _a_monde() -> void:
	await _cliquer_bouton("World", "World: the painted station plays it all")
	await _bouger(Vector2(root.size.x + 40, root.size.y * 0.5), 0.3)
	await _images(int(1.0 * FPS))
	# Le labo A, ses écrans au dehors ; puis le réacteur, ses conduits, son toit qui respire.
	_regarder(Vector3(-28, 6, -21), Vector3(-15, 2, -20))
	for i in int(5.0 * FPS):
		_vue._azimut += 0.003
		_vue._caler()
		await _images(1)
	_regarder(Vector3(36, 14, 16), Vector3(17, 3, 0))
	for i in int(6.0 * FPS):
		_vue._azimut += 0.004
		_vue._caler()
		await _images(1)
	_poser_camera(Vector3(-2, 2, -2), 0.7, 0.6, 70.0)
	_montrer("World", "Every copy of a tile plays its material")
	await _tourner(4.0)


# ── 3. LE PLAY TEST : ciel noir, glow ────────────────────────────────────────────────────────────────

func _a_jeu() -> void:
	var p0 := Vector3((PLATEFORME[0] + PLATEFORME[3]) * 0.5 + 0.5, 1, 0.5)
	_vue._cible = p0
	_cam_haut = false
	_cam_d = 3.0
	_cam_e = 0.28
	for r in [["ciel_haut", Color.BLACK], ["ciel_horizon", Color.BLACK], ["ciel_sol", Color.BLACK],
			["soleil_disque", false], ["soleil_energie", 0.6], ["soleil_hauteur", 35.0], ["soleil_couleur", Color("#9fb4ff")],
			["ambiante_couleur", Color("#3a4660")], ["ambiante_energie", 1.6], ["ssao", false], ["ssil", false],
			["glow", true], ["glow_intensite", 1.3], ["brouillard", true], ["brouillard_densite", 0.035],
			["brouillard_couleur", Color("#0a1020")], ["exposition", 1.15]]:
		_vue.regler_rendu(r[0], r[1])
	await _cliquer_bouton("Play test", "Play test: black sky, fog, glow")
	await _bouger(Vector2(root.size.x + 40, root.size.y + 40), 0.3)
	await _images(int(1.5 * FPS))
	if _vue.personnage == null:
		print("⚠ pas de personnage")
		return
	_vue._azimut = PI * 0.5
	var y := 1.0
	await _aller([Vector3(-30.5, y, 0.5), Vector3(-20.5, y, 0.5), Vector3(-14.5, y, 0.5), Vector3(-10.5, y, 0.5),
		Vector3(0.5, y, 0.5)], "W A S D", "Through the airlock, along the spine")
	await _aller([Vector3(0.5, y, 9.0), Vector3(0.5, 0, 14.5)], "W A S D", "The lab: its screens play")
	_cam_d = 4.0
	_cam_e = 0.12
	await _regarder_autour(4.5)
	_cam_e = 0.28
	await _aller([Vector3(0.5, y, 9.0), Vector3(0.5, y, 0.5), Vector3(10.5, y, 0.5), Vector3(13.5, 0, 4.5)],
		"Space", "Into the reactor", true)
	_cam_d = 6.0
	_cam_e = 0.35
	await _aller([Vector3(20.5, 0, 4.5), Vector3(20.5, 0, -4.5)], "W A S D", "Energy up the walls, a pulse in the floor")
	# Prise 2 : le ventilateur du plafond, vu en levant la caméra (recul 1,5, élévation −0,5) — la tête du stickman
	# remplissait l'image. Le ventilateur se montre dans l'atelier ; ici, le sol et les murs.
	await _regarder_autour(4.0)
	_cam_e = 0.5
	await _aller([Vector3(13.5, 0, -4.5), Vector3(13.5, 0, 3.5)], "W A S D", "Around the core")
	await _regarder_autour(3.0)
	await _touche(KEY_ESCAPE, "Esc", "Back to World")
