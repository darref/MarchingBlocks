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
	ed._aller_a("monde")
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
	await _play_test(ed)
	_vrai(_play_test_fini, "le Play test est allé JUSQU'AU BOUT (sinon une erreur l'a abandonné en silence)")

	ed.queue_free()
	await process_frame
	_rendre_les_reglages()
	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	print("VERDICT : %s" % ("OK" if _echecs == 0 else "ÉCHEC"))
	quit(0 if _echecs == 0 else 1)


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
	var oeil: Vector3 = ed._vue._camera.global_position
	var espace: PhysicsDirectSpaceState3D = ed._vue._vue.find_world_3d().direct_space_state
	var traverse := espace.intersect_ray(PhysicsRayQueryParameters3D.create(ed._vue._cible, oeil, 2))
	var boule := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.15
	boule.shape = sphere
	boule.transform = Transform3D(Basis(), oeil)
	boule.collision_mask = 2
	_vrai(traverse.is_empty() and espace.intersect_shape(boule, 1).is_empty(),
		"bras-ressort : rien du décor entre lui et l'œil, ni autour de l'œil (œil en %s)" % oeil)
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
	var reste: String = ProjectSettings.globalize_path(ed._chemin_temoin_modele())
	if FileAccess.file_exists(reste):
		DirAccess.remove_absolute(reste)
	_vrai(ed._droite_temoin.visible and not ed._droite.visible, "Witness : la barre du MODELEUR, pas celle de la peinture")
	ed._input(_cle(KEY_TAB))
	var mo: Node3D = ed._modeleur
	_vrai(ed._vue.edition and mo.maillage != null and mo.visible, "Tab entre en édition, le témoin est chargé")
	if mo.maillage == null:
		return
	var f0: int = mo.maillage.faces.size()
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
	var hit: Dictionary = mo.maillage.lancer_rayon(cam.project_ray_origin(centre_vue), cam.project_ray_normal(centre_vue))
	_vrai(not hit.is_empty(), "le centre de la vue tombe sur le témoin")
	if hit.is_empty():
		return
	var f: int = hit["face"]
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	clic.position = centre_vue
	ed._vue._gui_input(clic)
	_egal(mo.sel_f, {f: true}, "un clic choisit la face VISIBLE sous la souris")
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
		pc.position = cam.unproject_position(m.lerp(mo.maillage.centre(f), 0.05))
		ed._vue._gui_input(pc)
	ed._input(_cle(KEY_ENTER))
	_egal(mo.maillage.faces.size(), f0 + 1, "K, deux clics, Entrée : la face visée est fendue en deux")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_egal(mo.maillage.faces.size(), f0, "Ctrl+Z défait la coupe")
	# L'enregistrement : le fichier, relu, redonne le même maillage ; et il rejoint les travaux.
	var raison: String = ed._enregistrer_le_temoin_modele()
	var chemin: String = ed._chemin_temoin_modele()
	_egal(raison, "", "le témoin modélisé s'enregistre")
	var relu: ArrayMesh = BM.travail_depuis_glb(chemin)
	_vrai(relu != null and ME.depuis(relu).faces.size() == mo.maillage.faces.size(),
		"relu depuis son .glb, le témoin modélisé a le même nombre de faces")
	_vrai(ed._travaux.any(func(t): return String(t["chemin"]) == chemin), "il rejoint les travaux de l'étape 2")
	ed._minuterie_temoin.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))
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
