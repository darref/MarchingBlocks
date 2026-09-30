extends SceneTree
##
## FUMÉE — l'appli entière, chargée pour de vrai et menée sans souris : outils, sélection, annulation,
## couches, enregistrement et réouverture.
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/fumee_appli.gd
##
## ⚠ **CE QUE ÇA NE DIT PAS** : si c'est beau, si l'aperçu se lit, si le rayon tombe où l'œil l'attend.
## Le headless ne rend rien (charte §6). Ça dit que les gestes changent les BONNES cases, dans la BONNE
## couche, et que Ctrl+Z et la réouverture les rendent.
## ⚠ **LE PROJET DE L'UTILISATEUR N'EST JAMAIS TOUCHÉ** : `reglages.cfg` est pointé sur un projet jetable,
## puis rendu tel quel à la fin — même en cas d'échec.

const Projet := preload("res://app/projet.gd")
const Outils := preload("res://addons/marchingblocks_core/outils.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const FT := preload("res://addons/marchingblocks_core/formes_du_temoin.gd")
const Tranchage := preload("res://addons/marchingblocks_core/tranchage.gd")
const PlancheTuiles := preload("res://app/planche_tuiles.gd")
const REGLAGES := "user://reglages.cfg"
const JETABLE := "user://fumee/fumee.mbproj"

var _ok := 0
var _echecs := 0
var _reglages_avant := ""
## ⚠ LA SENTINELLE : une erreur d'exécution ABANDONNE la fonction en cours sans rien dire, et la fumée
## concluait « OK » avec cinq vérifications de moins (vu le 29 septembre 2026, `world_3d` nul).
var _play_test_fini := false


func _initialize() -> void:
	print("=== FUMÉE — l'appli, sans souris ===\n")
	if FileAccess.file_exists(REGLAGES):
		_reglages_avant = FileAccess.get_file_as_string(REGLAGES)
	DirAccess.make_dir_recursive_absolute("user://fumee")
	var f := FileAccess.open(JETABLE, FileAccess.WRITE)
	f.store_string(Projet.vers_texte([Projet.couche("Rock")], 0))
	f.close()
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", JETABLE)
	r.save(REGLAGES)
	_mener.call_deferred()


func _mener() -> void:
	# ⚠ L'ÉCRAN DOIT SE CHARGER, SINON RIEN NE COMPTE : un `editor.gd` qui ne compilait plus a laissé la fumée
	# conclure « 98 vérifications, OK » (29 septembre 2026). On l'exige d'abord, et on s'arrête net sinon.
	var script_ecran := load("res://app/editor.gd") as GDScript
	if script_ecran == null or not script_ecran.can_instantiate():
		_vrai(false, "app/editor.gd ne se CHARGE pas : rien d'autre n'est éprouvé")
		_rendre_les_reglages()
		print("
%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
		print("VERDICT : ÉCHEC")
		quit(1)
		return
	var ed: Control = (load("res://app/editor.tscn") as PackedScene).instantiate()
	root.add_child(ed)
	for i in 10:
		await process_frame
	_egal(ed._projet, JETABLE, "l'appli rouvre le dernier projet")
	_egal(ed._couches.size(), 1, "une couche relue")
	_vrai(ed._bouton_supprimer_couche.disabled, "une seule couche : « Delete » est grisé")
	var atelier_btn: Control = ed._boutons_atelier["witness"]
	var ancetre := atelier_btn.get_parent()
	while ancetre != null and not (ancetre is ScrollContainer) and ancetre != ed._gauche:
		ancetre = ancetre.get_parent()
	_vrai(ancetre == ed._gauche, "les ateliers sont ÉPINGLÉS : aucun défilement au-dessus d'eux")
	# ── Play test : un monde vide est REFUSÉ, et on reste dans World ───────────────────────────────
	ed._aller_a("jeu")
	_vrai(ed._atelier == "monde" and ed._vue.personnage == null and ed._rapport.text.contains("empty"),
		"Play test sur un monde vide : refusé, on reste dans World, et l'écran le dit")
	_egal((ed._boutons_atelier["monde"] as Button).text, "World", "l'atelier s'appelle World")
	ed._aller_a("monde")
	var cases: GridMap = ed._vue.cases()

	# ── Un coup d'ajout : deux morceaux, UN Ctrl+Z ────────────────────────────────────────────────
	ed._coup_commence()
	ed._touche({"poser": {Vector3i(0, 0, 0): true, Vector3i(1, 0, 0): true}, "effacer": {}}, "Add")
	ed._touche({"poser": {Vector3i(2, 0, 0): true}, "effacer": {}}, "Add")
	ed._coup_fini()
	_egal(cases.get_used_cells().size(), 3, "un coup en deux morceaux pose trois cases")
	ed._histoire.undo()
	_egal(cases.get_used_cells().size(), 0, "UN Ctrl+Z défait le coup entier")
	ed._histoire.redo()
	_egal(cases.get_used_cells().size(), 3, "Ctrl+Y le refait")

	# ── La sélection et ses opérations ────────────────────────────────────────────────────────────
	ed._vue.regler_selection({Vector3i(0, 0, 0): true, Vector3i(1, 0, 0): true})
	_vrai(ed._section_selection.visible, "la section Selection apparaît dès qu'il y a une sélection")
	ed._operer_selection("extruder_haut")
	_vrai(cases.get_cell_item(Vector3i(0, 1, 0)) != -1 and cases.get_cell_item(Vector3i(1, 1, 0)) != -1,
		"extruder vers le haut pose au-dessus de la sélection")
	_egal(ed._vue.selection, {Vector3i(0, 1, 0): true, Vector3i(1, 1, 0): true}, "la sélection suit")
	ed._operer("elargir")
	_egal(cases.get_used_cells().size(), 5 + 6, "élargir porte sur la SÉLECTION (étage y=1), pas sur l'étage 0")
	ed._histoire.undo()
	ed._operer_selection("supprimer")
	_egal(cases.get_used_cells().size(), 3, "supprimer retire la sélection")
	ed._operer_selection("")
	_vrai(ed._vue.selection.is_empty() and not ed._section_selection.visible, "Échap / Clear vide la sélection")

	# ── Le rayon de sculpture, par la vraie caméra ────────────────────────────────────────────────
	ed._choisir_visee("sculpt")
	var cam: Camera3D = ed._vue._camera
	var ecran: Vector2 = cam.unproject_position(Vector3(1.5, 0.5, 0.5))
	var point: Dictionary = ed._vue.point_vise(ecran, "creuser")
	_vrai(point.get("touche", false) and point["case"] == Vector3i(1, 0, 0),
		"en sculpture, le rayon de la caméra touche la case visée — rendu %s" % point.get("case"))
	var cibles: Array = ed._vue.cibles(ecran, "ajouter")
	_vrai(not cibles.is_empty() and not cases.get_cell_item(cibles[0]) != -1,
		"ajouter vise une case VIDE contre la face touchée — rendu %s" % [cibles])
	ed._choisir_visee("grille")

	# ── Une seconde couche : indépendante, et Ctrl+Z vise la BONNE couche ─────────────────────────
	ed._nouvelle_couche()
	_egal(ed._couches.size(), 2, "une couche de plus")
	_egal(ed._vue.cases().get_used_cells().size(), 0, "la nouvelle couche est vide")
	ed._appliquer({"poser": {Vector3i(9, 0, 9): true}, "effacer": {}}, "Add")
	ed._activer(0)
	ed._histoire.undo()
	_egal((ed._vue.couche(1).get_node("Cases") as GridMap).get_used_cells().size(), 0,
		"Ctrl+Z depuis la couche 0 défait la case posée dans la couche 1")
	_egal(ed._vue.cases().get_used_cells().size(), 3, "et laisse la couche 0 intacte")
	_egal((ed._vue.couche(1).get_node("Rendu") as GridMap).get_used_cells().size()
		+ (ed._vue.couche(1).get_node("Fautes") as GridMap).get_used_cells().size(), 0,
		"et REBÂTIT le rendu de la couche 1 — pas celui de la couche qu'on regarde")
	ed._histoire.redo()

	# ── Supprimer une couche s'annule ─────────────────────────────────────────────────────────────
	ed._activer(1)
	ed._supprimer_couche()
	_egal(ed._couches.size(), 1, "supprimer une couche")
	ed._histoire.undo()
	_egal(ed._couches.size(), 2, "Ctrl+Z rend la couche supprimée")
	_egal((ed._vue.couche(1).get_node("Cases") as GridMap).get_used_cells().size(), 1, "avec ses cases")

	# ── Enregistrée à chaque changement, relue à l'identique ──────────────────────────────────────
	var e: Array = []
	var relu: Dictionary = Projet.depuis_texte(FileAccess.get_file_as_string(JETABLE), e)
	_egal(relu.get("couches", []).size(), 2, "le fichier porte les deux couches, sans qu'on ait rien enregistré")
	if relu.get("couches", []).size() == 2:
		_egal(relu["couches"][0]["cases"].size(), 3, "avec les cases de la couche 0")
		_egal(relu["couches"][1]["cases"].size(), 1, "et celle de la couche 1")

	# ── La boîte et le rectangle, par la vue ─────────────────────────────────────────────────────
	#
	# ⚠ **LA BOÎTE PRENAIT LA MATIÈRE, ELLE PREND LE VOLUME — ET CES TROIS TESTS DISAIENT L'ANCIEN
	# COMPORTEMENT.** On ne les desserre pas : on les remplace par la propriété VOULUE. Un pavé vide
	# n'existait pas, donc ni Fill ni Extrude n'avaient de prise sur une pièce à bâtir (Jordan,
	# 28 septembre 2026).
	# La couche 0 porte la rangée (0,0,0) (1,0,0) (2,0,0).
	ed._activer(0)
	var vue = ed._vue
	var cases0 := ed._vue.couche(0).get_node("Cases") as GridMap
	vue.outil = "boite"
	vue._maj_du_coup = false
	vue._coin_boite = Vector3i(1, 0, 0)
	vue._coin_fin = Vector3i(3, 1, 0)
	vue._finir_boite(MOUSE_BUTTON_LEFT)
	_egal(vue.selection.size(), 6, "la boîte prend tout le VOLUME entre ses coins, cases vides comprises")
	_vrai(vue.selection.has(Vector3i(3, 1, 0)), "y compris une case où il n'y a rien")
	vue._coin_boite = Vector3i(7, 0, 0)
	vue._coin_fin = Vector3i(7, 0, 0)
	vue._maj_du_coup = true
	vue._finir_boite(MOUSE_BUTTON_LEFT)
	_egal(vue.selection.size(), 7, "une boîte avec Maj AJOUTE à la sélection")
	vue._maj_du_coup = false
	vue._coin_boite = Vector3i(7, 0, 0)
	vue._coin_fin = Vector3i(7, 0, 0)
	vue._finir_boite(MOUSE_BUTTON_RIGHT)
	_egal(vue.selection.size(), 6, "une boîte au clic droit RETIRE de la sélection")

	# ⚠ LE CREUX NE VAUT QUE POUR LA BOÎTE : un rectangle plat n'a pas de dedans.
	vue.creux = true
	vue._coin_boite = Vector3i(0, 0, 0)
	vue._coin_fin = Vector3i(2, 2, 2)
	vue._finir_boite(MOUSE_BUTTON_LEFT)
	_egal(vue.selection.size(), 26, "une boîte CREUSE de 3³ rend sa peau, 27 moins le cœur")
	_vrai(not vue.selection.has(Vector3i(1, 1, 1)), "et son cœur est bien vide")

	# LE RECTANGLE : toujours à plat, et le creux ne s'y applique pas.
	vue.outil = "rect"
	vue._coin_boite = Vector3i(0, 4, 0)
	vue._coin_fin = Vector3i(2, 4, 2)
	vue._finir_boite(MOUSE_BUTTON_LEFT)
	_egal(vue.selection.size(), 9, "le rectangle prend ses 3×3 cases, et le creux ne s'y applique pas")
	vue.creux = false

	# FILL puis EXTRUDE : le geste qui monte une pièce, et l'étage qui suit.
	var avant := cases0.get_used_cells().size()
	ed._operer_selection("remplir")
	_egal(cases0.get_used_cells().size(), avant + 9, "Fill pose de la matière dans les 9 cases du rectangle")
	var avant_etage: int = ed._vue.etage
	ed._operer_selection("extruder_haut")
	_egal(cases0.get_used_cells().size(), avant + 18, "Extrude ↑ pose la couche du dessus")
	_egal(ed._vue.etage, avant_etage + 1, "et le plan de visée MONTE avec elle, pour continuer à cliquer")
	ed._histoire.undo()
	ed._histoire.undo()
	_egal(cases0.get_used_cells().size(), avant, "deux Ctrl+Z rendent la couche telle qu'elle était")
	# ⚠ ON REND L'ÉTAT QUE LA SUITE ATTEND — sélection {(0,0,0), (1,0,0)} — PAR LE MÊME GESTE, jamais
	# en posant `selection` à la main : un test qui se met lui-même dans l'état qu'il prétend mesurer
	# ne mesure plus rien.
	vue.outil = "boite"
	vue._coin_boite = Vector3i(0, 0, 0)
	vue._coin_fin = Vector3i(1, 0, 0)
	vue._finir_boite(MOUSE_BUTTON_LEFT)
	vue.outil = "ajouter"
	_vrai(not vue._boite_vue.visible, "la boîte disparaît au relâché")

	# ── NAVIGATE : un interrupteur, plus une visée (Jordan, 29 septembre 2026) ────────────────────
	#
	# Tab n'alterne plus que Grid et Sculpt ; Espace bascule la navigation, et la visée d'avant revient
	# telle quelle. Les touches sont MAINTENUES pour de vrai (`Input.parse_input_event`), lues par leur
	# PLACE : AZEQSD en AZERTY = QWEASD en QWERTY.
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	var vues_visees: Array = [vue.visee]
	for i in 2:
		ed._input(tab)
		vues_visees.append(vue.visee)
	_egal(vues_visees, ["grille", "sculpt", "grille"], "Tab alterne Grid et Sculpt, et SEULEMENT eux")
	ed._choisir_visee("sculpt")
	var espace := InputEventKey.new()
	espace.keycode = KEY_SPACE
	espace.pressed = true
	ed._input(espace)
	_vrai(vue.naviguer and vue.visee == "sculpt" and ed._bouton_naviguer.button_pressed,
		"Espace allume Navigate, sans toucher à la visée, et le bouton le montre")
	ed._input(tab)
	_vrai(not vue.naviguer and vue.visee == "grille", "Tab en vol reprend la visée suivante et quitte le vol")
	ed._input(espace)
	_vrai(vue.naviguer, "Espace rallume Navigate")
	var avant_nav := cases0.get_used_cells().size()
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	clic.position = vue.size * 0.5
	vue._gui_input(clic)
	clic.pressed = false
	vue._gui_input(clic)
	_egal(cases0.get_used_cells().size(), avant_nav, "en Navigate, un clic ne peint rien")
	_egal(vue._coup, -1, "et ne commence aucun coup")
	var oeil: Vector3 = vue._camera.global_position
	var regard: Vector3 = -vue._camera.global_transform.basis.z
	vue.regarder(Vector2(80, 25))
	_vrai(vue._camera.global_position.distance_to(oeil) < 1e-3, "regarder laisse l'œil EN PLACE")
	_vrai(regard.angle_to(-vue._camera.global_transform.basis.z) > 0.2, "et tourne le regard")
	oeil = vue._camera.global_position
	var devant: Vector3 = -vue._camera.global_transform.basis.z
	vue.voler(Vector3(0, 0, 1), 0.5)
	var pas_fait: Vector3 = vue._camera.global_position - oeil
	_vrai(absf(pas_fait.y) < 1e-4, "avancer reste À PLAT, même en regardant vers le bas")
	_vrai(pas_fait.dot(Vector3(devant.x, 0, devant.z)) > 0.0, "et va vers où l'on regarde")
	# LES VRAIES TOUCHES, tenues quelques images : E monte, A (Q en QWERTY) descend, Z (W) avance.
	for cas in [[KEY_E, "E monte"], [KEY_Q, "A (Q en QWERTY) descend"], [KEY_W, "Z (W en QWERTY) avance"]]:
		oeil = vue._camera.global_position
		devant = -vue._camera.global_transform.basis.z
		_tenir(cas[0], true)
		for i in 6:
			await process_frame
		_tenir(cas[0], false)
		var bouge: Vector3 = vue._camera.global_position - oeil
		var ok: bool = bouge.y > 0.05 if cas[0] == KEY_E else (bouge.y < -0.05 if cas[0] == KEY_Q
			else bouge.dot(Vector3(devant.x, 0, devant.z)) > 0.05 and absf(bouge.y) < 1e-4)
		_vrai(ok, "touche tenue : " + cas[1])
	var outil_avant: String = vue.outil
	var s_touche := InputEventKey.new()
	s_touche.keycode = KEY_S
	s_touche.physical_keycode = KEY_S
	s_touche.pressed = true
	ed._unhandled_key_input(s_touche)
	_egal(vue.outil, outil_avant, "en Navigate, S vole vers l'arrière et ne choisit pas Select")
	var a_touche := InputEventKey.new()
	a_touche.keycode = KEY_A
	a_touche.physical_keycode = KEY_Q
	a_touche.pressed = true
	# ⚠ DEPUIS DIG : l'outil était déjà Add, donc « A choisit Add » ne changeait rien — la garde était
	# muette (vu en mutation).
	ed._choisir_outil("creuser")
	ed._unhandled_key_input(a_touche)
	_egal(vue.outil, "creuser", "en Navigate, A (AZERTY) descend et ne choisit pas Add")
	ed._choisir_outil(outil_avant)
	ed._input(espace)
	_vrai(not vue.naviguer and vue.visee == "grille", "Espace éteint Navigate et rend la visée")
	ed._choisir_visee("grille")

	# ── LE CONTEXTE : ce qui ne sert pas ici ne s'affiche pas (Jordan, 29 septembre 2026) ─────────
	ed._aller_a("projet")
	_vrai(ed._section_projet.visible and ed._etapes_artiste.all(func(e): return e.visible)
		and ed._etapes_monde.all(func(e): return e.visible), "Project : Save · open et les quatre étapes")
	_vrai(ed._bouton_trancher_travail.disabled, "rien d'importé : « Slice the selected work » est grisé")
	ed._aller_a("witness")
	_vrai(not ed._droite.visible, "Witness : pas de barre d'outils de peinture")
	_vrai(ed._section_temoin.visible and not ed._section_raccourcis.visible and not ed._section_couches.visible,
		"Witness : la section Witness, sans raccourcis de peinture ni couches")
	_vrai(not ed._section_projet.visible and not ed._etapes_artiste.any(func(e): return e.visible)
		and not ed._etapes_monde.any(func(e): return e.visible),
		"Witness : ni Save · open ni aller-retour — ils vivent dans Project seul")
	_vrai(not ed._section_monde_peint.visible, "Witness : pas de Painted world")
	_vrai(not ed._bouton_revoir_temoin.visible, "« Show the witness » absent quand on regarde déjà le témoin")
	_la_legende_des_formes(ed)
	ed._aller_a("monde")
	_vrai(ed._legende_formes.visible and ed._legende_formes.atelier == "monde",
		"World : le bandeau passe au sens inverse (d'où vient la tuile)")
	_vrai(ed._droite.visible and not ed._section_temoin.visible and ed._section_raccourcis.visible
		and ed._section_couches.visible, "World : outils, couches, raccourcis — et plus de section Witness")
	_vrai(not ed._section_projet.visible and not ed._etapes_monde.any(func(e): return e.visible),
		"World : ni Save · open ni aller-retour")
	_vrai(ed._section_monde_peint.visible, "World : la section Painted world (exporter le monde entier)")
	ed._choisir_outil("rect")
	_vrai(not ed._ligne_taille.visible and not ed._ligne_forme.visible and not ed._creux.visible,
		"Rect : ni pinceau ni Hollow")
	ed._choisir_outil("boite")
	_vrai(ed._creux.visible and not ed._ligne_taille.visible, "Box : Hollow, sans pinceau")
	ed._choisir_outil("ajouter")
	_vrai(ed._ligne_taille.visible and not ed._creux.visible, "Add : le pinceau revient, Hollow s'en va")

	# ── Déplacer : par le bouton, puis par les flèches, qui suivent la caméra ─────────────────────
	# Sélection : (0,0,0) (1,0,0). La caméra regarde depuis +x +z (azimut 0,7) : « devant » est −z,
	# « droite » est +x — calculé à la main, pas par la fonction.
	ed._deplacer(Vector3i(0, 1, 0))
	_egal(vue.selection, {Vector3i(0, 1, 0): true, Vector3i(1, 1, 0): true}, "Y + monte la sélection d'une case")
	_vrai(cases.get_cell_item(Vector3i(0, 0, 0)) == -1 and cases.get_cell_item(Vector3i(0, 1, 0)) != -1,
		"la matière est partie d'en bas, arrivée en haut")
	ed._deplacer_a_l_ecran(Vector2i(0, -1))
	_egal(vue.selection, {Vector3i(0, 1, -1): true, Vector3i(1, 1, -1): true}, "la flèche haut éloigne de la caméra : −z")
	ed._deplacer_a_l_ecran(Vector2i(1, 0))
	_egal(vue.selection, {Vector3i(1, 1, -1): true, Vector3i(2, 1, -1): true}, "la flèche droite va à droite : +x")
	ed._histoire.undo()
	ed._histoire.undo()
	ed._histoire.undo()
	_egal(cases.get_used_cells().size(), 3, "trois Ctrl+Z rendent la rangée d'origine")
	_vrai(cases.get_cell_item(Vector3i(0, 0, 0)) != -1, "à sa place")

	# ── Copier dans une couche, coller dans l'autre, par le vrai clic du collage ──────────────────
	vue.regler_selection({Vector3i(0, 0, 0): true, Vector3i(1, 0, 0): true})
	_vrai(ed._copier(), "copier une sélection")
	ed._activer(1)
	ed._coller()
	_vrai(not vue.collage.is_empty(), "coller entre en mode collage")
	var ou_coller: Vector2 = vue._camera.unproject_position(Vector3(20.5, 0.0, 20.5))
	vue._commencer_coup(MOUSE_BUTTON_LEFT, ou_coller, false)
	_vrai(vue.collage.is_empty(), "un clic pose le collage et en sort")
	var couche1: GridMap = vue.cases()
	_egal(couche1.get_used_cells().size(), 3, "le collage atterrit dans la couche 1 (1 case déjà là + 2 collées)")
	_egal((ed._vue.couche(0).get_node("Cases") as GridMap).get_used_cells().size(), 3, "la couche 0 n'a pas bougé")
	ed._coller()
	vue._commencer_coup(MOUSE_BUTTON_RIGHT, ou_coller, false)
	_vrai(vue.collage.is_empty() and couche1.get_used_cells().size() == 3, "le clic droit abandonne le collage sans rien poser")

	# ── L'export vers les moteurs refuse une couche sans tuiles ────────────────────────────────────
	# La couche 1 n'a jamais été tranchée : exporter livrerait le repli procédural sous le nom de l'artiste.
	await ed._exporter_le_jeu(ProjectSettings.globalize_path("user://fumee"))
	_vrai(ed._rapport.text.contains("Nothing to export") and not DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path("user://fumee").path_join("layer_2.mbset")),
		"exporter une couche sans tuiles est refusé, et rien n'est écrit")

	await _le_modeleur(ed)
	_la_planche_des_tuiles(ed)
	_vrai(_planche_finie, "la planche des tuiles est allée JUSQU'AU BOUT")
	await _play_test(ed)
	_vrai(_play_test_fini, "le Play test est allé JUSQU'AU BOUT (sinon une erreur l'a abandonné en silence)")
	_la_provenance(ed)
	_vrai(_provenance_finie, "la provenance est allée JUSQU'AU BOUT")

	ed.queue_free()
	await process_frame
	_rendre_les_reglages()
	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	print("VERDICT : %s" % ("OK" if _echecs == 0 else "ÉCHEC"))
	quit(0 if _echecs == 0 else 1)


## LA LÉGENDE DES FORMES (Jordan, 29 septembre 2026) : un bandeau en haut de la vue, dans Witness seul ;
## survoler une carte allume sa zone dans la vue, un clic y cadre, la flèche replie le bandeau.
## ⚠ Le centre de l'arche est calculé à la main (voir `test_formes_du_temoin`), pas par la fonction.
func _la_legende_des_formes(ed: Control) -> void:
	var leg: Control = ed._legende_formes
	_vrai(leg.visible, "Witness : la légende des formes est là")
	_egal(leg.cartes.size(), 23, "22 formes et le finisseur, une carte chacune")
	var carte_arche: Control = null
	for enfant in leg._rangee.get_children():
		if enfant.has_meta("carte") and enfant.get_meta("carte")["id"] == "arche":
			carte_arche = enfant
	_vrai(carte_arche != null, "la carte de l'arche existe")
	if carte_arche == null:
		return
	var zone: MultiMeshInstance3D = ed._vue._zone_vue
	carte_arche.mouse_entered.emit()
	_vrai(zone.visible and zone.multimesh.instance_count == 26, "survoler l'arche allume ses 26 cases dans la vue")
	carte_arche.mouse_exited.emit()
	_vrai(not zone.visible, "la quitter les éteint")
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	# ⚠ Le cadrage change l'orbite, et la suite (les flèches qui suivent la caméra) suppose celle d'avant.
	var v: Control = ed._vue
	var orbite := [v._cible, v._azimut, v._elevation, v._distance]
	carte_arche.gui_input.emit(clic)
	_vrai(ed._vue._cible.is_equal_approx(Vector3(7.5, 122.0 / 26.0 + 0.5, 4.0)), "un clic cadre la vue sur l'arche")
	v._cible = orbite[0]
	v._azimut = orbite[1]
	v._elevation = orbite[2]
	v._distance = orbite[3]
	v._caler()
	var h_ouvert: float = leg.size.y
	_vrai(h_ouvert > 150.0, "le bandeau ouvert a sa hauteur (%.0f)" % h_ouvert)
	leg._poignee.gui_input.emit(clic)
	leg.basculer(leg.ouvert, false)   # fin de l'animation, sans attendre
	_vrai(not leg.ouvert and leg.size.y < 30.0 and not leg._panneau.visible,
		"un clic sur la flèche replie le bandeau (reste la poignée : %.0f)" % leg.size.y)
	leg._poignee.gui_input.emit(clic)
	leg.basculer(leg.ouvert, false)
	_vrai(leg.ouvert and absf(leg.size.y - h_ouvert) < 0.5, "un second clic le rouvre")
	ed._aller_a("monde")
	carte_arche.mouse_entered.emit()
	_vrai(not zone.visible, "hors du témoin, une zone survolée ne s'allume pas")
	carte_arche.mouse_exited.emit()
	ed._aller_a("witness")


var _provenance_finie := false


## LE SENS INVERSE, dans World : la tuile sous la souris dit de quelle forme du témoin elle vient, et
## « Show it in the witness » y mène. Le monde est celui du Play test : un sol de 9 × 9 en y = 10, habillé
## du témoin tranché. ⚠ L'attendu du sommet est calculé à la main ; celui de la provenance vient du MODÈLE
## (`Tranchage.cle_du_sommet` sur les cases du témoin), pas de la méta qu'on éprouve.
func _la_provenance(ed: Control) -> void:
	ed._aller_a("monde")
	var v: Control = ed._vue
	var leg: Control = ed._legende_formes
	_vrai(leg.visible and leg._provenance.visible and not leg._defile.visible,
		"World : le bandeau montre la provenance, pas les cartes")
	_egal(leg._p_nom.text, "Hover a tile", "rien de survolé : le bandeau dit quoi faire")
	# Vu d'au-dessus, visé au centre : le rayon tombe sur le dessus de la case (24, 10, 24), en x = z = 24,3.
	# Le sommet v porte la pièce [v + ½, v + 3/2] : ⌊24,3 − ½⌋ = 23, ⌊11 − ½⌋ = 10 → (23, 10, 23).
	v._cible = Vector3(24.3, 11.0, 24.3)
	v._azimut = 0.0
	v._elevation = 1.45
	v._distance = 10.0
	v._caler()
	var info: Dictionary = v.tuile_sous(v.size * 0.5)
	_egal(info.get("sommet", null), Vector3i(23, 10, 23), "la tuile sous la souris : le sommet, à la main")
	var nom: String = info.get("nom", "")
	_vrai(nom != "" and not info["faute"], "une tuile y est posée (%s)" % nom)
	v._survoler(v.size * 0.5)
	_vrai(v._tuile_vue.visible and v._tuile_vue.position.is_equal_approx(Vector3(24, 11, 24)),
		"la tuile survolée est marquée dans le monde, centrée sur son sommet")
	var source: Variant = FT.sommet_source(info.get("lot", null), nom)
	_vrai(source != null, "le lot sait d'où vient cette tuile")
	if source == null:
		return
	var modele: Dictionary = Tranchage.cle_du_sommet(BM.cases(0), source, MB.plafond_de(BM.cases(0)))
	_egal(modele.get("cle", ""), nom,
		"le sommet source porte, dans le témoin, la MÊME clé que la tuile posée")
	_vrai(not leg.provenance.is_empty() and leg._p_voir.visible and leg._p_photo.texture != null,
		"le bandeau nomme la forme, montre sa photo et offre « Show it in the witness »")
	_vrai(leg._p_detail.text.contains("(%d, %d, %d)" % [source.x, source.y, source.z]), "et dit le coin exact")
	v._survoler(Vector2(2, 2))   # du ciel : la tuile désignée RESTE, sinon on n'atteindrait jamais le bouton
	_vrai(not leg.provenance.is_empty(), "passer sur du vide ne l'efface pas")
	leg.voir()
	_egal(ed._atelier, "witness", "« Show it in the witness » mène au témoin")
	_vrai(v._cible.is_equal_approx(Vector3(source) + Vector3.ONE), "cadré sur le sommet source")
	_vrai(v._tuile_vue.visible and v._tuile_vue.position.is_equal_approx(Vector3(source) + Vector3.ONE)
		and not v._zone_vue.visible, "la place exacte marquée — la tuile seule, la forme ne la noie pas")
	var encadree := ""
	for enfant in leg._rangee.get_children():
		if enfant.has_meta("carte") and (enfant as Control).get_theme_stylebox("panel") == enfant.get_meta("styles")[1]:
			encadree = enfant.get_meta("carte")["id"]
	_egal(encadree, leg.cartes.filter(func(c): return c["id"] == FT.cartes_du_sommet(leg.cartes, source)[0]["id"])[0]["id"],
		"la carte de la forme est encadrée dans le bandeau")
	_vrai(leg._defile.visible and not leg._provenance.visible, "Witness : le bandeau rend ses cartes")
	# Le repli procédural ne vient d'aucun témoin : on le DIT.
	ed._aller_a("monde")
	var lot_avant: MeshLibrary = v.monde().lot
	v.monde().lot = null
	v.monde().reconstruire()
	v._cible = Vector3(24.3, 11.0, 24.3)   # « Show it in the witness » a déplacé la caméra
	v._azimut = 0.0
	v._elevation = 1.45
	v._distance = 10.0
	v._caler()
	v._survoler(v.size * 0.5)
	_egal(leg._p_nom.text, "Not from a witness", "sur les tuiles intégrées, le bandeau dit qu'elles ne viennent d'aucun témoin")
	v.monde().lot = lot_avant
	v.monde().reconstruire()
	_provenance_finie = true


var _planche_finie := false


## LA PLANCHE DES TUILES (charte §3) : l'onglet « The tiles » du bandeau de Witness. ⚠ LES ATTENDUS VIENNENT
## D'AILLEURS : le nombre de cartes, des listes du MODÈLE ; les copies allumées, recomptées sommet par sommet
## par la règle du trancheur (`cle_du_sommet`) ; les demi-cases fantômes, comptées sur les bits de la classe.
func _la_planche_des_tuiles(ed: Control) -> void:
	ed._aller_a("witness")
	var leg = ed._legende_formes
	leg.montrer_onglet("tuiles")
	var pl = leg.planche
	var attendues: int = MB.pieces_a_sculpter().size() + MB.exterieures_a_sculpter().size()
	_egal(pl.cartes.size(), attendues, "la planche montre une carte par tuile du monde")
	_vrai(pl.visible and not leg._defile.visible, "l'onglet des tuiles remplace celui des formes")
	var t: Dictionary = BM.cases(0)
	var plafond: int = MB.plafond_de(t)
	var copies_de := {}
	var vus := {}
	for c in t:
		for s in MB.sommets_de(c):
			if vus.has(s):
				continue
			vus[s] = true
			var k: String = Tranchage.cle_du_sommet(t, s, plafond).get("cle", "")
			if k != "":
				copies_de[k] = int(copies_de.get(k, 0)) + 1
	var fantomes_justes := true
	var photos := true
	for cle in pl.cartes:
		var bits := -1
		for c in MB.classes():
			if c["nom"] == MB.nom_nu(cle):
				bits = c["bits"]
		var pleins := 0
		for k in 8:
			if bits & (1 << k):
				pleins += 1
		var vue: SubViewport = pl.cartes[cle]["vue"]
		var boites := 0
		for enfant in vue.get_children():
			if enfant is MeshInstance3D and (enfant as MeshInstance3D).mesh is BoxMesh:
				boites += 1
		fantomes_justes = fantomes_justes and boites == pleins
		var tuile: MeshInstance3D = pl.cartes[cle]["tuile"]
		photos = photos and tuile.mesh != null and tuile.mesh.get_surface_count() > 0
	_vrai(fantomes_justes, "chaque photo montre en fantôme les demi-cases pleines de SA classe")
	_vrai(photos, "chaque photo porte le maillage de sa tuile")
	var paroi := "mb_plaque_b2h2_dehors"
	(pl.cartes[paroi]["fond"] as Control).mouse_entered.emit()
	_egal(ed._vue._zone_vue.multimesh.instance_count, int(copies_de.get(paroi, -1)),
		"survoler la paroi allume TOUTES ses copies (recomptées par le trancheur)")
	(pl.cartes[paroi]["fond"] as Control).mouse_exited.emit()
	_vrai(not ed._vue._zone_vue.visible, "et quitter la carte les éteint")
	_vrai(PlancheTuiles.role_de(paroi).contains("wall") and PlancheTuiles.role_de("mb_plaque_b4h0").contains("ground"),
		"la paroi dit qu'elle est un mur, le sol qu'il est un sol")
	# Le clic, hors édition : une boîte blanche sur une copie de CETTE tuile.
	var coin := "mb_coin_b1h0_dehors"
	leg.tuile_choisie.emit(coin)
	var v = ed._vue
	var sommet := Vector3i((v._tuile_vue.position - Vector3.ONE).round())
	_vrai(v._tuile_vue.visible and Tranchage.cle_du_sommet(t, sommet, plafond).get("cle", "") == coin,
		"un clic montre une copie de la tuile choisie")
	# En édition : la tuile choisie passe en édition.
	ed._regler_edition(true)
	leg.tuile_choisie.emit(coin)
	_egal(ed._modeleur.cle, coin, "en édition, un clic sur la carte met la tuile en édition")
	# Les photos suivent la sculpture : un sommet de la tuile déplacé, la photo le montre après rafraîchissement.
	var mo: Node3D = ed._modeleur
	var avant: AABB = (pl.cartes[coin]["tuile"] as MeshInstance3D).mesh.get_aabb()
	var bas := 0
	for i in mo.maillage.sommets.size():
		if mo.maillage.sommets[i].y < mo.maillage.sommets[bas].y:
			bas = i
	mo.maillage.sommets[bas] += Vector3(0, -0.4, 0)
	leg.rafraichir_tuiles()
	var apres: AABB = (pl.cartes[coin]["tuile"] as MeshInstance3D).mesh.get_aabb()
	_vrai(apres.position.y < avant.position.y - 0.3, "la photo de la tuile montre la sculpture après rafraîchissement")
	mo.maillage.sommets[bas] -= Vector3(0, -0.4, 0)
	ed._regler_edition(false)
	leg.montrer_onglet("formes")
	_vrai(leg._defile.visible and not pl.visible, "l'onglet des formes revient")
	_planche_finie = true


## LE PLAY TEST, mené par de VRAIES touches (`Input.parse_input_event`) : le personnage tombe sur un
## sol peint, s'y pose, avance, saute, et la sortie rend tout. ⚠ Le headless ne dit pas s'il est beau.
func _play_test(ed: Control) -> void:
	var sol := {}
	for x in range(20, 29):
		for z in range(20, 29):
			sol[Vector3i(x, 10, z)] = true
	ed._coup_commence()
	ed._touche({"poser": sol, "effacer": {}}, "Add")
	ed._coup_fini()
	# ⚠ LE TÉMOIN, PAS LE REPLI : sur le repli procédural, la surface rendue COÏNCIDE avec les boîtes
	# de collision des cases (mesuré : 11,00 dans les deux cas), donc marcher sur les cases au lieu des
	# tuiles restait MUET. L'aminci rentre d'un quart de case : là, les deux se séparent.
	# ⚠ Le lot se pose SANS `_trancher_temoin` : son panneau d'attente guette `frame_post_draw`, qui
	# ne vient jamais en headless — la fumée pendait sans un mot.
	ed._vue.monde().lot = BM.librairie()["lot"]
	var avant: int = ed._vue.cases().get_used_cells().size()
	ed._vue._cible = Vector3(24.5, 11, 24.5)
	ed._aller_a("jeu")
	var p: CharacterBody3D = ed._vue.personnage
	_vrai(ed._atelier == "jeu" and p != null, "Play test sur un monde peint : le personnage apparaît")
	if p == null:
		return
	_vrai(not ed._droite.visible and ed._section_jeu.visible, "la barre des outils se retire, les commandes du jeu apparaissent")
	_vrai(not ed._zone_reference.visible and not ed._section_projet.visible and not ed._section_couches.visible,
		"Play test : ni référence, ni projet, ni couches — le jeu seul")
	_vrai(p.global_position.y > 11.0, "il apparaît AU-DESSUS du sol peint")
	for i in 90:
		await physics_frame
	_vrai(p.is_on_floor(), "il tombe et se POSE sur les tuiles (pas à travers)")
	_vrai(p.global_position.y > 10.5 and p.global_position.y < 10.9,
		"il se pose sur la surface RENDUE, un quart de case sous la case pleine (y = %.2f)" % p.global_position.y)
	var depart: Vector3 = p.global_position
	_touche_physique(KEY_W, true)
	for i in 40:
		await physics_frame
	_touche_physique(KEY_W, false)
	var pas := Vector2(p.global_position.x - depart.x, p.global_position.z - depart.z).length()
	_vrai(pas > 0.8, "W (Z en AZERTY) le fait avancer (%.2f case)" % pas)
	for i in 20:
		await physics_frame
	var y0: float = p.global_position.y
	_touche_physique(KEY_SPACE, true)
	var sommet := y0
	for i in 20:
		await physics_frame
		sommet = maxf(sommet, p.global_position.y)
	_touche_physique(KEY_SPACE, false)
	_vrai(sommet - y0 > 1.0, "Espace le fait sauter de plus d'une case (%.2f)" % (sommet - y0))
	var az: float = ed._vue._azimut
	var glisse := InputEventMouseMotion.new()
	glisse.button_mask = MOUSE_BUTTON_MASK_RIGHT
	glisse.relative = Vector2(80, 0)
	ed._vue._gui_input(glisse)
	_vrai(not is_equal_approx(ed._vue._azimut, az), "clic droit glissé : la caméra tourne autour de lui")
	# Clic GAUCHE glissé : lacet ET hauteur.
	var el: float = ed._vue._elevation
	var gauche := InputEventMouseMotion.new()
	gauche.button_mask = MOUSE_BUTTON_MASK_LEFT
	gauche.relative = Vector2(40, 30)
	ed._vue._gui_input(gauche)
	_vrai(ed._vue._elevation > el, "clic gauche glissé : la caméra monte autour de lui")
	# LE BRAS-RESSORT : une vue voulue À TRAVERS le sol. ⚠ « l'œil reste au-dessus du sol » était un mauvais
	# critère — près du bord du plateau, l'œil passe légitimement SOUS lui en le contournant (vu : 10,17).
	# La propriété, c'est : RIEN du décor entre le personnage et l'œil, ni autour de l'œil.
	ed._vue._elevation = -1.2
	ed._vue._distance = 8.0
	for i in 5:
		await process_frame
	var espace: PhysicsDirectSpaceState3D = ed._vue._vue.find_world_3d().direct_space_state
	_vrai(_oeil_degage(ed, espace), "bras-ressort : rien du décor entre lui et l'œil, ni autour de l'œil (œil en %s)"
		% ed._vue._camera.global_position)
	# LE PIVOT LISSÉ DANS LA ROCHE : `_cible` suit la tête avec retard, et peut rester une image derrière
	# une arête. On l'y met exprès — DANS la dalle du sol (l'aminci la tient entre 10,25 et 10,75) — et
	# l'on regarde d'un peu au-dessus. ⚠ Le bras qui partait de `_cible` butait sur la face par dessous
	# et posait l'œil sous le sol.
	# ⚠ Et la tête n'est libre que si la sphère tient DANS la capsule : plus large, collé à une paroi,
	# le premier lancer partirait lui aussi de la roche.
	_vrai(ed._vue.RAYON_DU_BRAS < p.RAYON, "la sphère du bras (%.2f) est plus fine que la capsule (%.2f)"
		% [ed._vue.RAYON_DU_BRAS, p.RAYON])
	ed._vue._elevation = 0.38
	ed._vue._cible = Vector3(p.global_position.x, 10.5, p.global_position.z)
	ed._vue._suivre(0.001)
	_vrai(_oeil_degage(ed, espace), "bras-ressort : un pivot lissé resté dans la roche ne fait pas passer l'œil "
		+ "à travers (œil en %s)" % ed._vue._camera.global_position)
	ed._vue._elevation = 0.38
	ed._vue._distance = 4.0
	var d: float = ed._vue._distance
	var molette := InputEventMouseButton.new()
	molette.button_index = MOUSE_BUTTON_WHEEL_UP
	molette.pressed = true
	ed._vue._gui_input(molette)
	_vrai(ed._vue._distance < d, "la molette rapproche la caméra")
	# ⚠ PAR LE VRAI CHEMIN DES TOUCHES, vue AU CLAVIER : c'est elle qui a la main en Play test, et une
	# vue qui avalerait les touches priverait l'écran d'Échap. Appeler `_unhandled_key_input` en direct
	# ne l'aurait jamais vu.
	_vrai(ed._vue.has_focus(), "en Play test, la vue a le clavier (Espace ne re-clique aucun bouton)")
	_touche_physique(KEY_ESCAPE, true)
	_touche_physique(KEY_ESCAPE, false)
	await process_frame
	_vrai(ed._atelier == "monde" and ed._vue.personnage == null and ed._vue._decor == null,
		"Échap rend World, sans personnage ni décor")
	_egal(ed._vue.cases().get_used_cells().size(), avant, "le Play test n'a changé aucune case")
	_play_test_fini = true


## Rien du décor entre la TÊTE du personnage et l'œil, ni autour de l'œil. ⚠ Depuis la tête, pas depuis
## `_cible` : le pivot lissé peut être dans la roche, et c'est justement ce qu'on éprouve.
func _oeil_degage(ed: Control, espace: PhysicsDirectSpaceState3D) -> bool:
	var tete: Vector3 = ed._vue.personnage.global_position + Vector3.UP * ed._vue.CAMERA_HAUTEUR
	var oeil: Vector3 = ed._vue._camera.global_position
	var boule := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.1
	boule.shape = sphere
	boule.transform = Transform3D(Basis(), oeil)
	boule.collision_mask = 2
	var q := PhysicsRayQueryParameters3D.create(tete, oeil, 2)
	q.hit_back_faces = true
	return espace.intersect_ray(q).is_empty() and espace.intersect_shape(boule, 1).is_empty()


func _tenir(touche: Key, appuyee: bool) -> void:
	_touche_physique(touche, appuyee)


## LE MODELEUR DU TÉMOIN, mené au clavier et à la souris comme Blender : Tab, 3, un clic, E 1 Entrée,
## Ctrl+Z / Ctrl+Y, G Z 2, X, Ctrl+R, et l'enregistrement qui le range parmi les travaux. Jugé sur des
## positions et des comptes calculés ICI, à partir de ce que le clic a touché.
func _le_modeleur(ed: Control) -> void:
	const ME := preload("res://addons/marchingblocks_core/maillage_edite.gd")
	ed._aller_a("witness")
	# ⚠ UN TÉMOIN MODÉLISÉ LAISSÉ PAR UN PASSAGE PRÉCÉDENT fausserait tous les comptes : la minuterie
	# d'enregistrement (une seconde après chaque geste) l'avait RÉÉCRIT après sa suppression — vu le 29
	# septembre 2026, le passage suivant partait d'un témoin déjà coupé.
	for reste in [ed._chemin_temoin_modele(), ed._chemin_modele_natif()]:
		var r: String = ProjectSettings.globalize_path(reste)
		if FileAccess.file_exists(r):
			DirAccess.remove_absolute(r)
	_vrai(ed._droite_temoin.visible and not ed._droite.visible, "Witness : la barre du MODELEUR, pas celle de la peinture")
	ed._input(_cle(KEY_TAB))
	var mo: Node3D = ed._modeleur
	_vrai(ed._vue.edition and mo.temoin != null and mo.maillage != null and mo.visible,
		"Tab entre en édition, le témoin LIÉ est chargé")
	if mo.maillage == null:
		return
	ed._input(_cle(KEY_3))
	_egal(mo.mode_sel, "face", "3 : mode face")
	# ⚠ ON RECADRE : les essais de vol de Navigate ont emmené la caméra ailleurs. Vue de face, sur le bloc.
	ed._vue._distance = 26.0
	ed._vue.vue_de("face")
	ed._vue.cadrer(Vector3(6, 6, 6))
	# Le clic : au centre de la vue. On calcule ICI quelle face le rayon touche.
	for i in 3:
		await process_frame
	var cam: Camera3D = ed._vue._camera
	var centre_vue: Vector2 = ed._vue.size * 0.5
	# ⚠ TÉMOIN LIÉ (charte §3) : le rayon trouve une OCCURRENCE ; la face est une face de SA tuile, et tout ce
	# qui suit se juge dans le repère de cette tuile (une rotation autour de +Y garde le haut : « G Z 2 »
	# monte de deux cases dans les deux repères).
	var hit: Dictionary = mo.temoin.rayon(cam.project_ray_origin(centre_vue), cam.project_ray_normal(centre_vue))
	_vrai(not hit.is_empty(), "le centre de la vue tombe sur le témoin")
	if hit.is_empty():
		return
	var f: int = hit["face"]
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	clic.position = centre_vue
	ed._vue._gui_input(clic)
	_vrai(mo.occurrence == int(hit["occurrence"]) and mo.cle == hit["cle"],
		"le clic met l'occurrence visée en édition (« %s »)" % hit["cle"])
	_egal(mo.sel_f, {f: true}, "un clic choisit la face VISIBLE sous la souris")
	var cle_a: String = mo.cle
	var f0: int = mo.maillage.faces.size()
	var c0: Vector3 = mo.maillage.centre(f)
	var n0: Vector3 = mo.maillage.normale(f)
	# E 1 Entrée : extruder d'une case le long de la normale.
	for k in [KEY_E, KEY_1, KEY_ENTER]:
		ed._input(_cle(k))
	_vrai(mo.maillage.faces.size() > f0, "E : des faces de côté en plus (%d → %d)" % [f0, mo.maillage.faces.size()])
	_vrai(mo.maillage.centre(f).is_equal_approx(c0 + n0), "E 1 Entrée : la face avance d'UNE case le long de sa normale")
	var apres_e: int = mo.maillage.faces.size()
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_egal(mo.maillage.faces.size(), f0, "Ctrl+Z défait l'extrusion d'un coup")
	_vrai(mo.maillage.centre(f).is_equal_approx(c0), "Ctrl+Z rend la face à sa place")
	ed._unhandled_key_input(_cle(KEY_Y, true))
	_egal(mo.maillage.faces.size(), apres_e, "Ctrl+Y la refait")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	# G Z 2 Entrée : Z est le HAUT, comme dans Blender.
	ed._vue._gui_input(clic)
	for k in [KEY_G, KEY_Z, KEY_2, KEY_ENTER]:
		ed._input(_cle(k))
	_vrai(mo.maillage.centre(f).is_equal_approx(c0 + Vector3(0, 2, 0)), "G Z 2 : la face MONTE de deux cases (Z = haut)")
	# ⚠ LES AUTRES COPIES SUIVENT : le maillage partagé par les occurrences de la tuile porte la face montée.
	var partage: Mesh = (mo._mm_de[cle_a] as MultiMeshInstance3D).multimesh.mesh
	var dans_le_partage := {}
	for s in partage.get_surface_count():
		for q in (partage.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			dans_le_partage[Vector3i((q * 1000.0).round())] = true
	var suivent := true
	for i in (mo.maillage.faces[f] as PackedInt32Array):
		suivent = suivent and dans_le_partage.has(Vector3i((mo.maillage.sommets[i] * 1000.0).round()))
	_vrai(suivent and mo.temoin.tuiles[cle_a] == mo.maillage and mo.temoin.occurrences_de(cle_a).size() > 1,
		"G Z 2 : les %d autres copies de la tuile montrent la face montée" % (mo.temoin.occurrences_de(cle_a).size() - 1))
	ed._unhandled_key_input(_cle(KEY_Z, true))
	# Échap annule un geste : rien ne change, rien ne s'inscrit.
	ed._vue._gui_input(clic)
	for k in [KEY_G, KEY_X, KEY_3]:
		ed._input(_cle(k))
	ed._input(_cle(KEY_ESCAPE))
	_vrai(mo.maillage.centre(f).is_equal_approx(c0) and mo.modal == "", "Échap annule G : la face n'a pas bougé")
	# X : supprimer la face ouvre un trou.
	ed._input(_cle(KEY_X))
	_egal(mo.maillage.faces.size(), f0 - 1, "X supprime la face choisie")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_egal(mo.maillage.faces.size(), f0, "et Ctrl+Z la rend")
	# Ctrl+R : l'anneau sous la souris, coupé au clic.
	mo.souris = centre_vue
	ed._input(_cle(KEY_R, true))
	_egal(mo.modal, "loop", "Ctrl+R vise un anneau")
	ed._vue._gui_input(clic)
	_vrai(mo.maillage.faces.size() > f0 and mo.modal == "", "le clic coupe l'anneau (%d faces, geste « %s »)" % [mo.maillage.faces.size(), mo.modal])
	ed._unhandled_key_input(_cle(KEY_Z, true))
	# B SUR TOUTE LA VUE : sans X-ray, seulement ce qu'on VOIT — moins qu'en X-ray, et aucune face de dos.
	# ⚠ TÉMOIN LIÉ : ce qui cache une face peut être une AUTRE occurrence. On met donc en édition une
	# occurrence dont le centre, vu de la caméra, est derrière une autre (le premier impact n'est pas elle).
	var cachee := -1
	var examinees := 0
	for i in mo.temoin.occurrences.size():
		if cachee >= 0:
			break
		var po: Transform3D = mo.temoin.occurrences[i]["pose"]
		if not cam.is_position_in_frustum(po.origin) or not Rect2(Vector2.ZERO, ed._vue.size).has_point(cam.unproject_position(po.origin)):
			continue
		examinees += 1
		# À DEMI : des faces tournées vers l'œil, dont certaines vues et d'autres cachées (par une autre copie).
		var tu: RefCounted = mo.temoin.tuiles[mo.temoin.occurrences[i]["cle"]]
		var vues_ici := 0
		var cachees_ici := 0
		for g in tu.faces.size():
			var cw: Vector3 = po * tu.centre(g)
			if (po.basis * tu.normale(g)).dot(cam.global_position - cw) <= 0.0:
				continue
			# ⚠ LES RAYONS DE LA VUE (la vue de face est ORTHOGRAPHIQUE : ils ne partent pas de l'œil).
			var ecr: Vector2 = cam.unproject_position(cw)
			var oo: Vector3 = cam.project_ray_origin(ecr)
			var hc: Dictionary = mo.temoin.rayon(oo, cam.project_ray_normal(ecr))
			if not hc.is_empty() and float(hc["distance"]) < oo.distance_to(cw) - 0.01:
				cachees_ici += 1
			else:
				vues_ici += 1
		if vues_ici > 0 and cachees_ici > 0:
			cachee = i
	_vrai(cachee >= 0, "une occurrence à demi cachée par d'autres est dans la vue")
	mo.activer(maxi(cachee, 0))
	ed._input(_cle(KEY_3))
	mo.tout_choisir(false)
	mo.rayons_x = false
	mo.choisir_dans(Rect2(Vector2.ZERO, ed._vue.size))
	var vues: Array = mo.sel_f.keys()
	var dos := 0
	for g in vues:
		if (mo.pose.basis * mo.maillage.normale(g)).dot(cam.global_position - mo.pose * mo.maillage.centre(g)) <= 0.0:
			dos += 1
	mo.tout_choisir(false)
	mo.rayons_x = true
	mo.choisir_dans(Rect2(Vector2.ZERO, ed._vue.size))
	var toutes: int = mo.sel_f.size()
	mo.rayons_x = false
	mo.tout_choisir(false)
	_vrai(vues.size() > 0 and vues.size() < toutes, "B sans X-ray : %d faces vues, contre %d en X-ray" % [vues.size(), toutes])
	_egal(dos, 0, "B sans X-ray : aucune face qui tourne le dos à l'œil")
	# ⚠ LA VRAIE GARDE DE L'OCCLUSION : moins que toutes les faces TOURNÉES VERS L'ŒIL dans la vue — certaines
	# sont cachées derrière d'autres. « Moins qu'en X-ray » seul resterait vrai sans aucun rayon : les faces
	# de dos sont déjà écartées par leur normale.
	var tournees := 0
	for g in mo.maillage.faces.size():
		var cg: Vector3 = mo.pose * mo.maillage.centre(g)
		if Rect2(Vector2.ZERO, ed._vue.size).has_point(cam.unproject_position(cg)) and cam.is_position_in_frustum(cg) \
				and (mo.pose.basis * mo.maillage.normale(g)).dot(cam.global_position - cg) > 0.0:
			tournees += 1
	_vrai(vues.size() < tournees, "B sans X-ray : %d faces vues sur %d tournées vers l'œil — les cachées sont écartées"
		% [vues.size(), tournees])
	# Ctrl+B : l'arête visée, biseautée de 0,1 tapé.
	ed._input(_cle(KEY_2))
	ed._vue._gui_input(clic)
	_egal(mo.sel_a.size(), 1, "2 puis un clic : une arête choisie")
	ed._input(_cle(KEY_B, true))
	_egal(mo.modal, "bevel", "Ctrl+B biseaute")
	for k in [KEY_0, KEY_PERIOD, KEY_1, KEY_ENTER]:
		ed._input(_cle(k))
	_vrai(mo.modal == "" and mo.maillage.faces.size() > f0, "Ctrl+B 0.1 Entrée : le biseau est posé (%d faces)"
		% mo.maillage.faces.size())
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_egal(mo.maillage.faces.size(), f0, "Ctrl+Z défait le biseau")
	# K : deux points sur deux arêtes de la face visée, Entrée.
	ed._input(_cle(KEY_3))
	var face: PackedInt32Array = mo.maillage.faces[f]
	var m1: Vector3 = (mo.maillage.sommets[face[0]] + mo.maillage.sommets[face[1]]) * 0.5
	var m2: Vector3 = (mo.maillage.sommets[face[2]] + mo.maillage.sommets[face[3]]) * 0.5
	ed._input(_cle(KEY_K))
	_egal(mo.modal, "knife", "K prend le couteau")
	for m in [m1, m2]:
		var pc := InputEventMouseButton.new()
		pc.button_index = MOUSE_BUTTON_LEFT
		pc.pressed = true
		# Un cheveu vers le centre de la face : on vise la face, pas son arête pile.
		pc.position = cam.unproject_position(mo.pose * m.lerp(mo.maillage.centre(f), 0.05))
		ed._vue._gui_input(pc)
	ed._input(_cle(KEY_ENTER))
	_egal(mo.maillage.faces.size(), f0 + 1, "K, deux clics, Entrée : la face visée est fendue en deux")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_egal(mo.maillage.faces.size(), f0, "Ctrl+Z défait la coupe")
	# LES MATÉRIAUX : un neuf, assigné à la face visée ; Ctrl+Z / Ctrl+Y ; une rafale de retouches = UNE annulation.
	ed._vue._gui_input(clic)
	ed._nouveau_materiau()
	_egal(mo.maillage.materiaux.size(), 1, "New material : un matériau")
	ed._assigner_materiau()
	_egal(mo.maillage.mat(f), 0, "Assign : la face visée prend le matériau")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_egal(mo.maillage.mat(f), -1, "Ctrl+Z : elle le rend")
	ed._unhandled_key_input(_cle(KEY_Y, true))
	_egal(mo.maillage.mat(f), 0, "Ctrl+Y : elle le reprend")
	mo.materiau_courant = 0
	ed._redire_les_materiaux()
	var couleur0: Color = mo.maillage.materiaux[0]["couleur"]
	for c in [Color(0.5, 0.2, 0.2), Color(0.7, 0.15, 0.1), Color(0.9, 0.1, 0.1)]:
		ed._retoucher("couleur", c)
	ed._inscrire_les_retouches()
	_vrai((mo.maillage.materiaux[0]["couleur"] as Color).is_equal_approx(Color(0.9, 0.1, 0.1)), "la couleur retouchée")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_vrai((mo.maillage.materiaux[0]["couleur"] as Color).is_equal_approx(couleur0),
		"trois retouches de couleur : UN Ctrl+Z les défait toutes")
	ed._unhandled_key_input(_cle(KEY_Y, true))
	# U : la face visée dépliée ; le matériau en projection « UV » ; le patron écrit.
	ed._vue._gui_input(clic)
	ed._input(_cle(KEY_U))
	_vrai(mo.maillage.uv(f).size() == (mo.maillage.faces[f] as PackedInt32Array).size(), "U déplie la face visée")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_vrai(mo.maillage.uv(f).is_empty(), "Ctrl+Z défait le dépliage")
	ed._unhandled_key_input(_cle(KEY_Y, true))
	ed._retoucher("projection", "uv")
	ed._inscrire_les_retouches()
	var patron: String = ProjectSettings.globalize_path("user://fumee/patron.png")
	_egal(ed._exporter_le_patron(patron), "", "Export UV layout écrit le patron")
	var img := Image.load_from_file(patron)
	_vrai(img != null and img.get_width() == 2048, "le patron fait 2048 × 2048")
	DirAccess.remove_absolute(patron)
	# UNE AUTRE TUILE : un clic sur une occurrence d'une autre clé la met en édition ; on l'extrude, on revient
	# à la première, et Ctrl+Z défait l'extrusion de la tuile qu'on n'édite PLUS.
	var ailleurs := Vector2(-1, -1)
	var hit_b: Dictionary = {}
	for gx in range(2, 18):
		for gy in range(2, 18):
			var pt: Vector2 = ed._vue.size * Vector2(gx / 20.0, gy / 20.0)
			var h: Dictionary = mo.temoin.rayon(cam.project_ray_origin(pt), cam.project_ray_normal(pt))
			if not h.is_empty() and h["cle"] != cle_a and ailleurs.x < 0:
				ailleurs = pt
				hit_b = h
	_vrai(ailleurs.x >= 0, "une occurrence d'une autre tuile est visible")
	if ailleurs.x >= 0:
		var clic_b := InputEventMouseButton.new()
		clic_b.button_index = MOUSE_BUTTON_LEFT
		clic_b.pressed = true
		clic_b.position = ailleurs
		ed._vue._gui_input(clic_b)
		var cle_b: String = mo.cle
		_vrai(cle_b == hit_b["cle"] and mo.sel_f == {int(hit_b["face"]): true},
			"un clic sur une autre tuile la met en édition, sa face choisie")
		var fb0: int = mo.maillage.faces.size()
		for k in [KEY_E, KEY_1, KEY_ENTER]:
			ed._input(_cle(k))
		_vrai(mo.temoin.tuiles[cle_b].faces.size() > fb0, "E sur l'autre tuile l'extrude")
		ed._vue._gui_input(clic)
		_egal(mo.cle, cle_a, "un clic ramène la première tuile en édition")
		ed._unhandled_key_input(_cle(KEY_Z, true))
		_egal(mo.temoin.tuiles[cle_b].faces.size(), fb0, "Ctrl+Z défait l'extrusion de la tuile qu'on n'édite plus")
		_egal(mo.cle, cle_a, "et l'édition reste sur la tuile en cours")
		ed._vue._gui_input(clic)
	# UNE COPIE TOURNÉE : « G X 1 » déplace d'une case vers +X DU MONDE, quelle que soit la rotation de la copie
	# (Z ne le prouverait pas : un quart de tour autour de +Y garde le haut).
	var tournee := -1
	for i in mo.temoin.occurrences.size():
		var b: Basis = (mo.temoin.occurrences[i]["pose"] as Transform3D).basis
		if tournee < 0 and not b.x.is_equal_approx(Vector3.RIGHT):
			tournee = i
	_vrai(tournee >= 0, "le témoin a des copies tournées")
	if tournee >= 0:
		mo.activer(tournee)
		mo.choisir_mode("face")
		mo.tout_choisir(false)
		mo.sel_f = {0: true}
		var avant_monde: Vector3 = mo.pose * mo.maillage.centre(0)
		for k in [KEY_G, KEY_X, KEY_1, KEY_ENTER]:
			ed._input(_cle(k))
		var apres_monde: Vector3 = mo.pose * mo.maillage.centre(0)
		_vrai((apres_monde - avant_monde).is_equal_approx(Vector3(1, 0, 0)),
			"G X 1 sur une copie tournée : +1 en X du MONDE (%s)" % (apres_monde - avant_monde))
		ed._unhandled_key_input(_cle(KEY_Z, true))
		ed._vue._gui_input(clic)
	# L'enregistrement : le .glb LIÉ se relit tuile par tuile, avec le matériau ; et il rejoint les travaux.
	var raison: String = ed._enregistrer_le_temoin_modele()
	var chemin: String = ed._chemin_temoin_modele()
	_egal(raison, "", "le témoin modélisé s'enregistre")
	var relu: Dictionary = BM.librairie_depuis_glb(chemin)
	_vrai(relu.get("lie", false) and relu["erreurs"].is_empty() and (relu["lot"] as MeshLibrary).get_item_list().size() == mo.temoin.tuiles.size(),
		"relu comme témoin lié : une tuile par clé, sans erreur (%s)" % [relu.get("erreurs")])
	_vrai(ed._travaux.any(func(t): return String(t["chemin"]) == chemin), "il rejoint les travaux de l'étape 2")
	var rouge := false
	var id_a: int = (relu["lot"] as MeshLibrary).find_item_by_name(cle_a)
	if id_a >= 0:
		var tuile_relue: Mesh = (relu["lot"] as MeshLibrary).get_item_mesh(id_a)
		for i in tuile_relue.get_surface_count():
			var sm := tuile_relue.surface_get_material(i) as BaseMaterial3D
			rouge = rouge or (sm != null and sm.albedo_color.is_equal_approx(Color(0.9, 0.1, 0.1)))
	_vrai(rouge, "la tuile relue porte le matériau rouge (aucun override ne l'efface)")
	# Rouvert : le .mbtiles fait foi — la face garde SON matériau.
	var faces_avant: int = mo.maillage.faces.size()
	mo.temoin = null
	mo.maillage = null
	ed._regler_edition(false)
	ed._regler_edition(true)
	_vrai(mo.temoin != null and mo.temoin.tuiles[cle_a].faces.size() == faces_avant and mo.temoin.tuiles[cle_a].mat(f) == 0,
		"rouvert depuis son .mbtiles : la face visée garde son matériau")
	ed._minuterie_temoin.stop()
	ed._minuterie_materiau.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ed._chemin_modele_natif()))
	ed._input(_cle(KEY_TAB))
	_vrai(not ed._vue.edition and not mo.visible, "Tab sort de l'édition")
	ed._aller_a("monde")


func _cle(k: Key, ctrl := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	e.ctrl_pressed = ctrl
	return e


func _touche_physique(touche: Key, appuyee: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = touche
	e.keycode = touche
	e.pressed = appuyee
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _rendre_les_reglages() -> void:
	if _reglages_avant == "":
		DirAccess.remove_absolute(REGLAGES)
	else:
		var f := FileAccess.open(REGLAGES, FileAccess.WRITE)
		f.store_string(_reglages_avant)
		f.close()
	DirAccess.remove_absolute(JETABLE)


func _vrai(v: bool, quoi: String) -> void:
	if v:
		_ok += 1
	else:
		_echecs += 1
		print("  ✗ " + quoi)


func _egal(a, b, quoi: String) -> void:
	if a == b:
		_ok += 1
	else:
		_echecs += 1
		print("  ✗ %s — rendu %s, attendu %s" % [quoi, a, b])
