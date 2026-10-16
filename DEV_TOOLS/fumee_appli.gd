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
const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const Outils := preload("res://addons/marchingblocks_core/outils.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const Natif := preload("res://addons/marchingblocks_core/natif.gd")
const FT := preload("res://addons/marchingblocks_core/formes_du_temoin.gd")
const Tranchage := preload("res://addons/marchingblocks_core/tranchage.gd")
const PlancheTuiles := preload("res://app/planche_tuiles.gd")
const TR := preload("res://addons/marchingblocks_core/transitions.gd")
const ATPalette := preload("res://app/palette.gd")
const Guide := preload("res://app/guide.gd")
const REGLAGES := "user://reglages.cfg"
const JETABLE := "user://fumee/fumee.mbproj"
const RACINE_EXEMPLE := "user://fumee/example"

var _ok := 0
var _echecs := 0
var _reglages_avant := ""
## ⚠ LA SENTINELLE : une erreur d'exécution ABANDONNE la fonction en cours sans rien dire, et la fumée
## concluait « OK » avec cinq vérifications de moins (vu le 29 septembre 2026, `world_3d` nul).
var _play_test_fini := false
var _play_edit_fini := false


func _initialize() -> void:
	print("=== FUMÉE — l'appli, sans souris ===\n")
	if FileAccess.file_exists(REGLAGES):
		_reglages_avant = FileAccess.get_file_as_string(REGLAGES)
	DirAccess.make_dir_recursive_absolute("user://fumee")
	var f := FileAccess.open(JETABLE, FileAccess.WRITE)
	# ⚠ LE MONDE D'ESSAI EST AMINCI, TÉMOINS ET EAU (9 octobre 2026 : le neutre est devenu le défaut) : les hauteurs écrites
	# à la main dans cette fumée (10,75 au Play test, 2,34 dans le lac, 20,75 pour un arbre…) sont celles d'un sol aminci.
	# Les crans eux-mêmes sont menés par `_les_crans` (boutons, témoins, monde, eau).
	f.store_string(Projet.vers_texte([Projet.couche("Rock")], 0, [], [], {}, {}, 0.25))
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
	# ⚠ L'EXEMPLE DE LA FUMÉE S'INSTALLE CHEZ ELLE, À NEUF : jamais dans la copie installée de l'utilisateur (ses
	# retouches y vivent, et l'appli l'aurait réenregistrée en fermant).
	_vider_dossier(RACINE_EXEMPLE)
	script_ecran.racine_exemple = RACINE_EXEMPLE
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
	var gardes_avant: int = ed._vue.monde().gardes_de_compte
	ed._touche({"poser": {Vector3i(0, 0, 0): true, Vector3i(1, 0, 0): true}, "effacer": {}}, "Add")
	ed._touche({"poser": {Vector3i(2, 0, 0): true}, "effacer": {}}, "Add")
	ed._coup_fini()
	_egal(cases.get_used_cells().size(), 3, "un coup en deux morceaux pose trois cases")
	# ⚠ UNE TOUCHE NE RELIT PAS LA GRILLE (4 octobre 2026 : ~7 ms par couche et par touche sur l'exemple) : le coup sait
	# ce qu'il a changé.
	_egal(ed._vue.monde().gardes_de_compte - gardes_avant, 0, "… sans relire la grille à chaque touche (garde de compte)")
	ed._histoire.undo()
	_egal(cases.get_used_cells().size(), 0, "UN Ctrl+Z défait le coup entier")
	ed._histoire.redo()
	_egal(cases.get_used_cells().size(), 3, "Ctrl+Y le refait")
	# ⚠ LE MONDE DU CŒUR EST BRANCHÉ (étape 3 b, 6 octobre 2026) : avec le natif, la couche est inscrite au monde partagé
	# de l'écran, qui porte ses cases — sinon la fumée éprouverait le GDScript en croyant éprouver l'appli.
	if MB.natif() != null:
		var mc = ed._vue.monde().monde
		_vrai(mc != null and mc == ed._monde_coeur and int(mc.nombre_de_cases(-1)) == 3,
			"le monde du cœur porte les cases de l'écran (la couche lui est branchée)")

	# ── La sélection et ses opérations ────────────────────────────────────────────────────────────
	ed._vue.regler_selection({Vector3i(0, 0, 0): true, Vector3i(1, 0, 0): true})
	_vrai(ed._section_selection.visible, "la section Selection apparaît dès qu'il y a une sélection")
	ed._extruder("haut")
	_vrai(cases.get_cell_item(Vector3i(0, 1, 0)) != -1 and cases.get_cell_item(Vector3i(1, 1, 0)) != -1,
		"extruder vers le haut pose au-dessus de la sélection")
	_egal(ed._vue.selection, {Vector3i(0, 1, 0): true, Vector3i(1, 1, 0): true}, "la sélection suit")
	ed._operer("elargir")
	_egal(cases.get_used_cells().size(), 5 + 6, "élargir porte sur la SÉLECTION (étage y=1), pas sur l'étage 0")
	# L'ÉCRAN PARLE ANGLAIS (audit du 3 octobre 2026) : le rapport et l'annulation disaient « elargir ».
	_vrai(ed._rapport.text.contains("Widen") and ed._histoire.get_current_action_name() == "Widen",
		"le rapport et l'annulation nomment « Widen », pas le nom de code (%s)" % ed._histoire.get_current_action_name())
	ed._histoire.undo()
	ed._operer_selection("supprimer")
	_egal(cases.get_used_cells().size(), 3, "supprimer retire la sélection")
	_egal(ed._histoire.get_current_action_name(), "Delete", "… et l'annulation s'appelle « Delete »")
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
	# ⚠ DANS LA SECONDE, SUR L'AUTRE FIL (2 octobre 2026) : activer, montrer une couche n'écrivent plus sur-le-champ.
	# La seconde est passée ici d'un coup (la minuterie), puis on attend l'écriture.
	_vrai(not ed._minuterie_projet.is_stopped(), "le changement attend sa seconde avant de s'écrire")
	ed._minuterie_projet.timeout.emit()
	for i in 120:
		if ed._tache_ecriture < 0:
			break
		await process_frame
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
	# EXTRUDE, UN SEUL BOUTON (2 octobre 2026) : celui de Shape operations, cliqué pour de vrai ; Maj étend la
	# sélection, Alt la décale — de VRAIES touches tenues (`Input.parse_input_event`). Attendus écrits à la main.
	var bouton_haut: Button = null
	for b in ed.find_children("*", "Button", true, false):
		if (b as Button).text == "Extrude up":
			bouton_haut = b
	_vrai(bouton_haut != null and not ed.find_children("*", "Button", true, false).any(
		func(b): return (b as Button).text in ["Extrude ↑", "Extrude ↓", "Extend up", "Extend down"]),
		"un seul Extrude : dans Shape operations ; dans Selection, seulement « Extend selection ↑ ↓ » (qui ne posent rien)")
	var rect9: Dictionary = ed._vue.selection.duplicate()
	bouton_haut.pressed.emit()
	_egal(cases0.get_used_cells().size(), avant + 18, "Extrude up pose la couche du dessus")
	_egal(ed._vue.etage, avant_etage + 1, "et le plan de visée MONTE avec elle, pour continuer à cliquer")
	var monte := {}
	for c in rect9:
		monte[c + Vector3i.UP] = true
	_egal(ed._vue.selection, monte, "et la sélection la suit")
	# Maj + clic : la sélection s'étend d'un cran vers le haut (9 + 9 cases), aucune matière posée.
	var maj := InputEventKey.new()
	maj.keycode = KEY_SHIFT
	maj.physical_keycode = KEY_SHIFT
	maj.pressed = true
	Input.parse_input_event(maj)
	Input.flush_buffered_events()
	bouton_haut.pressed.emit()
	var maj_relache: InputEventKey = maj.duplicate()
	maj_relache.pressed = false
	Input.parse_input_event(maj_relache)
	Input.flush_buffered_events()
	var etendue := monte.duplicate()
	for c in monte:
		etendue[c + Vector3i.UP] = true
	_egal(ed._vue.selection, etendue, "Maj + Extrude up : la sélection s'étend d'un cran (18 cases)")
	_egal(cases0.get_used_cells().size(), avant + 18, "… sans poser de matière")
	_egal(ed._vue.etage, avant_etage + 2, "… et l'étage suit")
	# CTRL + clic sur Extrude up (Alt jusqu'au 13 octobre 2026 : Alt est la taille) : la sélection MONTE d'un cran, rien n'est posé. ⚠ PAS SUR « DOWN » : sous la
	# sélection tout est plein, un Extrude normal n'y posait rien non plus et décalait aussi la sélection — la
	# mutation « Alt ignorée » restait MUETTE. Vers le haut, un Extrude normal poserait 9 cases.
	var alt := InputEventKey.new()
	alt.keycode = KEY_CTRL
	alt.physical_keycode = KEY_CTRL
	alt.pressed = true
	Input.parse_input_event(alt)
	Input.flush_buffered_events()
	bouton_haut.pressed.emit()
	var alt_relache: InputEventKey = alt.duplicate()
	alt_relache.pressed = false
	Input.parse_input_event(alt_relache)
	Input.flush_buffered_events()
	var montee := {}
	for c in etendue:
		montee[c + Vector3i.UP] = true
	_egal(ed._vue.selection, montee, "Ctrl + Extrude up : la sélection monte d'un cran")
	_egal(cases0.get_used_cells().size(), avant + 18, "… sans poser de matière")
	_egal(ed._vue.etage, avant_etage + 3, "… et l'étage suit")
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
	# ⚠ LES COUCHES Y SONT (30 septembre 2026) : une couche est un témoin ET un monde peint — on la choisit
	# dans les deux ateliers.
	_vrai(ed._section_temoin.visible and ed._section_raccourcis.visible and ed._section_couches.visible,
		"Witness : la section Witness, les couches, et les raccourcis du témoin (13 octobre 2026)")
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
	# ⚠ UN RESTE D'UN PASSAGE PRÉCÉDENT (vu le 4 octobre 2026 : un `layer_2.mbset` du matin, en lecture seule — un
	# dossier marqué pour Windows) faisait échouer « rien n'est écrit » sans que rien ne soit écrit. On juge donc ce que
	# CET export écrit : le dossier absent, ou son `tileset.json` inchangé.
	var mbset_refuse := ProjectSettings.globalize_path("user://fumee").path_join("layer_2.mbset")
	var json_refuse := mbset_refuse.path_join("tileset.json")
	var date_avant := FileAccess.get_modified_time(json_refuse) if FileAccess.file_exists(json_refuse) else -1
	await ed._exporter_le_jeu(ProjectSettings.globalize_path("user://fumee"))
	var rien_ecrit := not DirAccess.dir_exists_absolute(mbset_refuse) if date_avant < 0 \
		else FileAccess.get_modified_time(json_refuse) == date_avant
	_vrai(ed._rapport.text.contains("Nothing to export") and rien_ecrit,
		"exporter une couche sans tuiles est refusé, et rien n'est écrit")

	_les_formes_speciales(ed)
	_la_salle(ed)
	_vrai(_salle_finie, "la salle est allée JUSQU'AU BOUT")
	_vrai(_formes_finies, "les formes spéciales sont allées JUSQU'AU BOUT")
	_ctrl_clic_cale_la_grille(ed)
	_vrai(_ctrl_clic_fini, "le Ctrl+clic d'étage est allé JUSQU'AU BOUT")

	await _le_modeleur(ed)
	await _lasso_et_cercle(ed)
	_vrai(_lasso_fini, "le lasso et le cercle sont allés JUSQU'AU BOUT")
	await _multi_tuiles(ed)
	_vrai(_multi_fini, "SENTINELLE : la sélection sur plusieurs tuiles est allée JUSQU'AU BOUT")
	_la_planche_des_tuiles(ed)
	_vrai(_planche_finie, "la planche des tuiles est allée JUSQU'AU BOUT")
	await _les_couches_et_leurs_temoins(ed)
	_la_bande_du_bas(ed)
	_le_manuel_dit_le_rendu(ed)
	_les_deux_ateliers_du_temoin(ed)
	_peindre_le_temoin(ed)
	_l_atelier_animation(ed)
	_vrai(_animation_finie, "SENTINELLE : l'atelier Animation est allé JUSQU'AU BOUT")
	_sculpter_le_temoin(ed)
	_vrai(_sculpt_fini, "le sculpt est allé JUSQU'AU BOUT")
	_vrai(_couches_finies, "les couches et leurs témoins sont allés JUSQU'AU BOUT")
	await _l_enregistrement_se_dit(ed)
	_les_sections_dans_le_modeleur(ed)
	_les_gestes_topologiques_gardent_les_sections(ed)
	_vrai(_les_gestes_gardent_le_bord(ed), "SENTINELLE : la section « les gestes gardent le bord » est allée jusqu'au bout")
	_vrai(_la_retopo(ed), "SENTINELLE : la section « la retopo » est allée jusqu'au bout")
	_vrai(_sections_finies, "les sections partagées sont allées JUSQU'AU BOUT")
	await _play_test(ed)
	_vrai(_play_test_fini, "le Play test est allé JUSQU'AU BOUT (sinon une erreur l'a abandonné en silence)")
	await _play_edit(ed)
	_vrai(_play_edit_fini, "SENTINELLE : le Play edit est allé JUSQU'AU BOUT")
	_la_provenance(ed)
	_vrai(_provenance_finie, "la provenance est allée JUSQU'AU BOUT")
	await _les_fluides(ed)
	_vrai(_fluides_finis, "les fluides sont allés JUSQU'AU BOUT")
	await _les_couches_exclusives(ed)
	_vrai(_exclusives_finies, "les couches exclusives sont allées JUSQU'AU BOUT")
	_l_exemple_ne_s_impose_pas(ed)
	await _les_demandes_du_3_octobre(ed)
	_vrai(_demandes_finies, "les demandes du 3 octobre sont allées JUSQU'AU BOUT")
	await _l_exemple(ed)
	await _le_mode_dev_de_l_exemple(ed)
	await _reparer_les_diagonales_au_bouton(ed)
	await _la_barre_des_gestes(ed)
	await _la_barre_de_droite_tient(ed)
	await _les_teintes_des_ateliers(ed)
	await _la_molette(ed)
	_vrai(_molette_finie, "la molette est allée JUSQU'AU BOUT")
	await _le_guide(ed)
	_vrai(_guide_fini, "SENTINELLE : le guide des raccourcis est allé JUSQU'AU BOUT")
	await _tout_raccourci_a_son_bouton(ed)
	_vrai(_boutons_raccourcis_finis, "SENTINELLE : « tout raccourci a son bouton » est allé JUSQU'AU BOUT")
	await _les_variantes(ed)
	_vrai(_variantes_finies, "les variantes sont allées JUSQU'AU BOUT")
	_les_bords_entre_couches(ed)
	_vrai(_bords_finis, "SENTINELLE : les bords entre couches sont allés JUSQU'AU BOUT")
	_l_atelier_transitions(ed)
	_vrai(_transitions_finies, "SENTINELLE : l'atelier Transitions est allé JUSQU'AU BOUT")
	await _le_feuillage(ed)
	_vrai(_feuillage_fini, "le feuillage est allé JUSQU'AU BOUT")
	await _les_crans(ed)
	_vrai(_crans_finis, "SENTINELLE : les crans du témoin et de l'eau sont allés JUSQU'AU BOUT")
	await _la_cage(ed)
	_vrai(_cage_finie, "SENTINELLE : la cage de la tuile est allée JUSQU'AU BOUT")
	await _les_infos_de_la_vue(ed)
	_vrai(_infos_finies, "SENTINELLE : les infos de la vue, l'étage du guide, le repère de taille et la grille sont allés JUSQU'AU BOUT")

	# LA FERMETURE (2 octobre 2026) : sortie de l'arbre, l'écran ne relance plus de minuterie quand l'historique
	# change — c'est ce que fait la libération de l'historique, et l'erreur sortait à chaque fermeture.
	# ⚠ « LA MINUTERIE RESTE ARRÊTÉE » NE SUFFIT PAS (mutation d'abord MUETTE) : hors de l'arbre, `Timer.start()`
	# échoue sans démarrer — l'erreur sort, la minuterie reste arrêtée. Ce qu'on lit : la barre ne passe pas à
	# « Saving… » (une écriture qui n'aura jamais lieu).
	ed._minuterie_projet.stop()
	ed._dire_enregistre("enregistre")
	root.remove_child(ed)
	ed._histoire.create_action("fermeture")
	ed._histoire.commit_action(false)
	_vrai(ed._minuterie_projet.is_stopped() and ed._etat_enregistre.text == "✓ Saved",
		"hors de l'arbre, un changement d'historique ne relance rien (barre : %s)" % ed._etat_enregistre.text)
	root.add_child(ed)
	ed.queue_free()
	await process_frame
	_rendre_les_reglages()
	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	print("VERDICT : %s" % ("OK" if _echecs == 0 else "ÉCHEC"))
	quit(0 if _echecs == 0 else 1)


## LES BORDS ENTRE COUCHES (Jordan, 6 octobre 2026 : « il y a des fentes, je les ai vues, fais comme tu as dit pour les
## éviter »). Deux couches se touchent dans le monde : une tuile de A face à une tuile de B. L'AUTORITÉ ne passe pas par
## `sections.gd` : `_sans_partenaire_entre` pose les occurrences des deux témoins et compte, à chaque joint, les sommets de
## l'un sans partenaire exact dans l'autre — la fente du monde à leur frontière.
var _bords_finis := false


func _les_bords_entre_couches(ed: Control) -> void:
	ed._aller_a("witness")
	ed._nouvelle_couche()
	var ia: int = ed._active
	ed._regler_edition(true)
	var mo: Node3D = ed._modeleur
	var ta: RefCounted = mo.temoin
	var ib := -1
	for i in ed._couches.size():
		if i != ia and ed._suit_son_temoin(ed._couches[i]):
			ib = i
			break
	_vrai(ib >= 0, "une autre couche suit son témoin")
	if ib < 0:
		return
	var tb: RefCounted = ed._temoin_de(ed._couches[ib])
	_vrai(mo.autres_temoins.has(tb) and not mo.autres_temoins.has(ta), "le modeleur tient le témoin de l'autre couche (et pas le sien)")
	# Une divergence CONSTRUITE : un sommet de bord de la paroi de B déplacé dans son plan, dans B seul.
	var paroi := "mb_plaque_b2h2_dehors"
	var sb = preload("res://addons/marchingblocks_core/sections.gd").new(tb)
	var i_b: int = (sb.bords[paroi] as Dictionary).keys()[0]
	var mb: RefCounted = tb.tuiles[paroi]
	mb.sommets[i_b] += sb.projeter(paroi, i_b, Vector3(0.04, 0.03, -0.02))
	var fente: int = _sans_partenaire_entre(ta, tb)
	_vrai(fente > 0, "contrôle : le bord de B tiré dans B seul ouvre la frontière A | B (%d sans partenaire)" % fente)
	ed._ecarts_perimes = true
	ed._ecarts_lus_a = -100000
	ed._dire_les_ecarts()
	_vrai(ed._bouton_caler.visible and ed._ecarts_texte.text.contains("differ"), "Geometry le dit : « %s »" % ed._ecarts_texte.text)
	var photo_a := {}
	for c in ta.tuiles:
		photo_a[c] = (ta.tuiles[c].sommets as PackedVector3Array).duplicate()
	var photo_b := {}
	for c in tb.tuiles:
		photo_b[c] = (tb.tuiles[c].sommets as PackedVector3Array).duplicate()
	ed._bouton_caler.pressed.emit()
	_egal(_sans_partenaire_entre(ta, tb), 0, "« Match other layers to this one » : la frontière A | B se referme")
	# A peut RECEVOIR des points (les coupes que B portait sur ses bords, reportées SUR ses arêtes) : sa forme ne change
	# pas. Ce qu'on lit : chacun de ses sommets d'avant est resté à sa place.
	var a_bouge := 0
	for c in ta.tuiles:
		for j in (photo_a[c] as PackedVector3Array).size():
			if (ta.tuiles[c].sommets[j] as Vector3).distance_to(photo_a[c][j]) > 1e-9:
				a_bouge += 1
				break
	_egal(a_bouge, 0, "le témoin qu'on édite fait foi : aucun de ses sommets ne bouge")
	_vrai(ed._temoins_sales.has(tb), "le témoin de B est à réécrire")
	ed._ecarts_lus_a = -100000
	ed._dire_les_ecarts()
	_vrai(ed._ecarts_texte.text.contains("the same"), "Geometry le dit : « %s »" % ed._ecarts_texte.text)
	ed._unhandled_key_input(_cle(KEY_Z, true))
	var b_rendu := true
	for c in tb.tuiles:
		b_rendu = b_rendu and tb.tuiles[c].sommets == photo_b[c]
	_vrai(b_rendu and _sans_partenaire_entre(ta, tb) == fente, "UN Ctrl+Z rend le témoin de B tel qu'il était")
	ed._unhandled_key_input(_cle(KEY_Y, true))
	_egal(_sans_partenaire_entre(ta, tb), 0, "Ctrl+Y le recale")
	# UN GESTE SUR UN BORD DE A ENTRAÎNE B : G au clavier, comme dans `_les_sections_dans_le_modeleur`.
	mo.activer(int(ta.occurrences_de(paroi)[0]))
	mo.sections.indexer()
	var i_bord := -1
	var axe_face := -1
	for i in (mo.sections.bords[paroi] as Dictionary):
		if (mo.sections.bords[paroi][i] as Array).size() == 1:
			i_bord = i
			axe_face = mo.sections.bords[paroi][i][0]["axe"]
			break
	var normale_monde: Vector3 = (mo.pose.basis * _unitaire(axe_face)).abs()
	var dans_le_plan: Key = KEY_X
	for k in [KEY_X, KEY_Z, KEY_Y]:
		var v: Vector3 = {KEY_X: Vector3(1, 0, 0), KEY_Z: Vector3(0, 1, 0), KEY_Y: Vector3(0, 0, 1)}[k]
		if v.dot(normale_monde) < 0.5:
			dans_le_plan = k
			break
	for c in tb.tuiles:
		photo_b[c] = (tb.tuiles[c].sommets as PackedVector3Array).duplicate()
	mo.choisir_mode("sommet")
	mo.tout_choisir(false)
	mo.sel_s = {i_bord: true}
	for k in [KEY_G, dans_le_plan, KEY_0, KEY_PERIOD, KEY_1, KEY_ENTER]:
		ed._input(_cle(k))
	var b_suit := 0
	for c in tb.tuiles:
		if tb.tuiles[c].sommets != photo_b[c]:
			b_suit += 1
	_vrai(b_suit >= 2, "G sur un bord de A : %d tuiles du témoin de B suivent" % b_suit)
	_egal(_sans_partenaire_entre(ta, tb), 0, "et la frontière A | B reste fermée")
	_vrai(_sans_partenaire(ta) == 0 and _sans_partenaire(tb) == 0, "A et B restent étanches")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	var b_rendu2 := true
	for c in tb.tuiles:
		b_rendu2 = b_rendu2 and tb.tuiles[c].sommets == photo_b[c]
	_vrai(b_rendu2, "UN Ctrl+Z rend aussi les tuiles de B")
	# Un Ctrl+Z APRÈS avoir changé de couche : le geste vise B, qu'on édite désormais.
	ed._unhandled_key_input(_cle(KEY_Y, true))
	ed._activer(ib)
	_vrai(mo.temoin == tb and mo.autres_temoins.has(ta), "B active : le modeleur l'édite, et tient A parmi les autres")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	var b_rendu3 := true
	for c in tb.tuiles:
		b_rendu3 = b_rendu3 and tb.tuiles[c].sommets == photo_b[c]
	_vrai(b_rendu3 and _sans_partenaire_entre(ta, tb) == 0, "Ctrl+Z depuis B rend les tuiles de B, qu'on édite")
	# Ménage : les deux recalages défaits, la couche neuve supprimée.
	ed._unhandled_key_input(_cle(KEY_Z, true))
	ed._activer(ia)
	ed._supprimer_couche()
	ed._regler_edition(false)
	ed._minuterie_temoin.stop()
	ed._enregistrer_le_temoin_modele()
	_bords_finis = true


func _sans_partenaire_entre(ta_: RefCounted, tb_: RefCounted) -> int:
	return _sans_partenaire_de(ta_, tb_) + _sans_partenaire_de(tb_, ta_)


func _sans_partenaire_de(ta_: RefCounted, tb_: RefCounted) -> int:
	var occ_a := {}
	for o in ta_.occurrences:
		occ_a[o["sommet"]] = o
	var occ_b := {}
	for o in tb_.occurrences:
		occ_b[o["sommet"]] = o
	var n := 0
	for s in occ_a:
		var oa: Dictionary = occ_a[s]
		for axe in 3:
			for sens in [-1, 1]:
				var e := Vector3i.ZERO
				e[axe] = sens
				if not occ_b.has(s + e):
					continue
				var ob: Dictionary = occ_b[s + e]
				var tbm: RefCounted = tb_.tuiles[ob["cle"]]
				# ⚠ UN PARTENAIRE À MOINS DE 10⁻⁵, PAS UN ARRONDI AU DIX-MILLIÈME : deux points à 3·10⁻⁵ tombent souvent dans le
				# même cran, et un report posé au cran au lieu de sa position exacte passait inaperçu (mutation d'abord muette).
				var index_b := {}
				for j in tbm.sommets.size():
					var pb: Vector3 = (ob["pose"] as Transform3D) * tbm.sommets[j]
					var cb := Vector3i((pb * 1000.0).floor())
					if not index_b.has(cb):
						index_b[cb] = []
					index_b[cb].append(pb)
				var tam: RefCounted = ta_.tuiles[oa["cle"]]
				var plan: float = float(s[axe]) + 1.0 + 0.5 * sens
				for i in tam.sommets.size():
					var pw: Vector3 = (oa["pose"] as Transform3D) * tam.sommets[i]
					if absf(pw[axe] - plan) > 0.0005:
						continue
					var ca := Vector3i((pw * 1000.0).floor())
					var trouve := false
					for dx in [-1, 0, 1]:
						for dy in [-1, 0, 1]:
							for dz in [-1, 0, 1]:
								for pb in index_b.get(ca + Vector3i(dx, dy, dz), []):
									trouve = trouve or (pb as Vector3).distance_to(pw) < 1e-5
					if not trouve:
						n += 1
	return n


## L'ATELIER TRANSITIONS (Jordan, 6 octobre 2026). Les attendus ne passent pas par l'atelier : les octets de la texture
## relus à la main (rang + 1), le fichier du projet relu par `Projet.depuis_texte`, les matériaux des tuiles posées relus
## dans le lot.
var _transitions_finies := false


func _l_atelier_transitions(ed: Control) -> void:
	ed._aller_a("monde")
	if ed._couches.size() < 2:
		ed._nouvelle_couche()
	ed._activer(0)
	ed._aller_a("transitions")
	var tr: RefCounted = ed._transitions
	_egal(ed._atelier, "transitions", "l'atelier Transitions s'ouvre")
	_vrai(ed._droite_transitions.visible and not ed._droite.visible and ed._section_couches.visible,
		"sa barre de droite, et la liste des couches (son ordre dit qui couvre)")
	_egal(ed._vue.outil, "transition", "le pinceau des transitions est l'outil de la vue")
	var teintes: Dictionary = ATPalette.TEINTES_ATELIER
	var autres := 0
	for a in teintes:
		if a != "transitions" and (teintes[a] as Color).is_equal_approx(teintes["transitions"]):
			autres += 1
	_vrai(teintes.has("transitions") and autres == 0, "une teinte à lui, qu'aucun autre atelier ne porte")
	var n: int = ed._couches.size()
	_egal(tr._liste.get_child_count(), n * (n - 1) / 2, "une ligne par paire de couches (%d couches)" % n)
	# Deux couches qui se touchent, loin de tout : A en (60, 0, 60), B en (61, 0, 60).
	var ida := str(ed._couches[0]["id"])
	var idb := str(ed._couches[1]["id"])
	var ca := Vector3i(60, 0, 60)
	var cb := Vector3i(61, 0, 60)
	(ed._vue.couche(0).get_node("Cases") as GridMap).set_cell_item(ca, ed._id_case())
	(ed._vue.couche(1).get_node("Cases") as GridMap).set_cell_item(cb, ed._id_case())
	ed._suivre_les_cases([ca, cb])
	var cle: String = TR.cle_de_paire(ida, idb)
	tr.paire_choisie = cle
	tr.dire(true)
	_vrai(not tr.actif(), "aucune paire allumée : rien n'est dessiné")
	tr.suivre()
	_egal(_portent_le_passage(ed, tr), 0, "… et aucun matériau ne porte le passage")
	# La case de la paire, cochée.
	var case_paire: CheckBox = null
	for ligne in tr._liste.get_children():
		var b: Button = ligne.get_child(1)
		if b.text == "%s  ·  %s" % [tr._nom(cle.split("|")[0]), tr._nom(cle.split("|")[1])]:
			case_paire = ligne.get_child(0)
	_vrai(case_paire != null, "la ligne de la paire A · B")
	case_paire.button_pressed = true
	_vrai(tr.actif() and bool(tr.etat["paires"][cle]["actif"]), "cochée, la paire est allumée")
	tr.suivre()
	var lot: MeshLibrary = (ed._vue.couche(0).get_node("Rendu") as GridMap).mesh_library
	var portent := 0
	var surfaces := 0
	if lot != null:
		for id in lot.get_item_list():
			var m: Mesh = lot.get_item_mesh(id)
			for s in (m.get_surface_count() if m != null else 0):
				var mat: Material = m.surface_get_material(s)
				if mat != null:
					surfaces += 1
					if mat.next_pass == tr.rendu.materiau:
						portent += 1
	_vrai(lot != null and surfaces > 0 and portent == surfaces,
		"allumée : chaque matériau des tuiles de A porte le passage (%d / %d)" % [portent, surfaces])
	var d: Dictionary = tr.rendu.donnees
	_egal([TR.rang_lu(d, ca), TR.rang_lu(d, cb)], [0, 1], "la texture : A au rang 0, B au rang 1")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_vrai(not tr.actif(), "Ctrl+Z l'éteint")
	tr.suivre()
	# ⚠ LU SUR LES MATÉRIAUX, PAS DANS LA LISTE DE L'ATELIER (« jamais débranché » restait muette : la liste se vidait, les
	# matériaux gardaient le passage).
	_egal(_portent_le_passage(ed, tr), 0, "… et retire le passage des matériaux (relu sur chaque matériau du lot)")
	ed._unhandled_key_input(_cle(KEY_Y, true))
	_vrai(tr.actif(), "Ctrl+Y la rallume")
	tr.suivre()
	# Une case posée ensuite suit dans la texture.
	var cc := Vector3i(61, 1, 60)
	(ed._vue.couche(1).get_node("Cases") as GridMap).set_cell_item(cc, ed._id_case())
	ed._suivre_les_cases([cc])
	tr.suivre()
	d = tr.rendu.donnees
	_egal(TR.rang_lu(d, cc), 1, "une case posée ensuite entre dans la texture")
	# LE PINCEAU : « B couvre », autour du sommet de la frontière (59..60 : ses huit cases portent A et B).
	tr.couvrant_peint = idb
	tr.rayon = 1
	var s0 := Vector3i(60, -1, 59)
	tr.peindre(s0, MOUSE_BUTTON_LEFT, "debut")
	tr.peindre(null, MOUSE_BUTTON_LEFT, "fin")
	var peints: Dictionary = tr.etat["choix"]
	_vrai(peints.size() > 0 and peints.values().all(func(v): return str(v) == idb), "le pinceau pose « B couvre » (%d sommet(s))" % peints.size())
	var tous_a_la_frontiere := true
	for s in peints:
		var a := false
		var b := false
		for k in 8:
			var c: Vector3i = s + Vector3i(k & 1, (k >> 1) & 1, (k >> 2) & 1)
			a = a or c == ca
			b = b or c == cb or c == cc
		tous_a_la_frontiere = tous_a_la_frontiere and a and b
	_vrai(tous_a_la_frontiere, "… seulement là où A et B se rencontrent")
	d = tr.rendu.donnees
	_egal(TR.choix_lu(d, s0), 1, "la texture porte le choix (le rang de B)")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	d = tr.rendu.donnees
	_vrai((tr.etat["choix"] as Dictionary).is_empty() and TR.choix_lu(d, s0) == -1,
		"UN Ctrl+Z défait le trait, dans l'état et dans la texture")
	ed._unhandled_key_input(_cle(KEY_Y, true))
	tr.peindre(s0, MOUSE_BUTTON_RIGHT, "debut")
	tr.peindre(null, MOUSE_BUTTON_RIGHT, "fin")
	_vrai((tr.etat["choix"] as Dictionary).is_empty(), "le clic droit rend la priorité")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	# UN RÉGLAGE, par son curseur : l'avance de « A couvre B ».
	var curseur: HSlider = null
	for enfant in _descendants(tr._editeur):
		if enfant is HSlider and (enfant as HSlider).get_meta("reglage", []) == [ida, "avance"]:
			curseur = enfant
	_vrai(curseur != null, "le curseur « Reach » quand A couvre B")
	curseur.value = 0.4
	_egal(snappedf(float(tr.etat["paires"][cle]["couvre"][ida]["avance"]), 0.01), 0.4, "il règle « A couvre B »")
	tr.suivre()
	var img: Image = (tr.rendu.materiau.get_shader_parameter("table") as Texture2D).get_image()
	_egal(snappedf(img.get_pixel(2 * 1, 0).b, 0.01), 0.4, "la table du shader suit (avance de 0 sur 1, texel (2, 0))")
	# L'ENREGISTREMENT : relu par `Projet.depuis_texte`.
	ed._enregistrer()
	if ed._tache_ecriture >= 0:
		WorkerThreadPool.wait_for_task_completion(ed._tache_ecriture)
		ed._ecriture_finie("")
		ed._tache_ecriture = -1
	var relu: Dictionary = Projet.depuis_texte(FileAccess.get_file_as_string(ed._projet), [])
	var rt: Dictionary = relu.get("transitions", {})
	_vrai(bool(rt.get("paires", {}).get(cle, {}).get("actif", false)) and (rt["choix"] as Dictionary).size() == peints.size(),
		"le projet enregistré porte la paire allumée et les choix peints")
	# Esc ramène à World, et le pinceau s'en va.
	ed._unhandled_key_input(_cle(KEY_ESCAPE))
	_vrai(ed._atelier == "monde" and ed._vue.outil != "transition", "Échap ramène à World, l'outil de World revient")
	# Ménage.
	case_paire.button_pressed = false
	tr.suivre()
	(ed._vue.couche(0).get_node("Cases") as GridMap).set_cell_item(ca, -1)
	(ed._vue.couche(1).get_node("Cases") as GridMap).set_cell_item(cb, -1)
	(ed._vue.couche(1).get_node("Cases") as GridMap).set_cell_item(cc, -1)
	ed._suivre_les_cases([ca, cb, cc])
	tr.etat["choix"] = {}
	_transitions_finies = true


## Combien de matériaux des tuiles posées (toutes couches) portent le passage des transitions.
func _portent_le_passage(ed: Control, tr: RefCounted) -> int:
	var n := 0
	for i in ed._vue.nombre_de_couches():
		var lot: MeshLibrary = (ed._vue.couche(i).get_node("Rendu") as GridMap).mesh_library
		if lot == null:
			continue
		for id in lot.get_item_list():
			var m: Mesh = lot.get_item_mesh(id)
			for s in (m.get_surface_count() if m != null else 0):
				var mat: Material = m.surface_get_material(s)
				if mat != null and mat.next_pass == tr.rendu.materiau:
					n += 1
	return n


func _descendants(n: Node) -> Array:
	var sortie: Array = []
	for e in n.get_children():
		sortie.append(e)
		sortie.append_array(_descendants(e))
	return sortie


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
	_vrai(v._apercu.visible and not v._tuile_vue.visible,
		"en peignant, UN seul repère sous la souris : l'aperçu des cases, pas la boîte de la tuile")
	v.naviguer = true
	v._survoler(v.size * 0.5)
	_vrai(v._tuile_vue.visible and v._tuile_vue.position.is_equal_approx(Vector3(24, 11, 24))
		and not v._apercu.visible, "en Navigate, la tuile survolée est marquée, centrée sur son sommet")
	v.naviguer = false
	v._survoler(v.size * 0.5)
	_vrai(not v._tuile_vue.visible, "revenu à la peinture, la boîte de la tuile s'efface")
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
var _couches_finies := false


## L'ENREGISTREMENT AUTOMATIQUE SE DIT (Jordan, 30 septembre 2026) : la barre de titre montre « Saved », un
## geste du modeleur « Saving… » jusqu'à son écriture, et Ctrl+S — inutile — écrit ce qui attendait et le DIT.
func _l_enregistrement_se_dit(ed: Control) -> void:
	ed._aller_a("witness")
	ed._regler_edition(true)
	ed._temoin_modifie(ed._modeleur.temoin)
	_egal(ed._etat_enregistre.text, "● Saving…", "un geste du modeleur : la barre dit « Saving… » tant qu'il n'est pas écrit")
	_vrai(not ed._minuterie_temoin.is_stopped(), "(et l'écriture attend sa seconde)")
	var k := _cle(KEY_S, true)
	ed._unhandled_key_input(k)
	_vrai(ed._minuterie_temoin.is_stopped() and ed._temoins_sales.is_empty(), "Ctrl+S écrit TOUT DE SUITE ce qui attendait")
	_egal(ed._etat_enregistre.text, "✓ Saved", "et la barre dit « Saved »")
	_vrai(ed._rapport.text.contains("Everything is saved") and ed._rapport.text.contains("no need for Ctrl+S"),
		"Ctrl+S dit que tout est déjà enregistré, et qu'il n'en faut pas")
	_vrai(ed._etat_enregistre.tooltip_text.contains("no need for Ctrl+S"), "la bulle de la barre l'explique")
	ed._regler_edition(false)

	# ⚠ LE PROJET AUSSI ATTEND SA SECONDE (Jordan, 1er octobre 2026 : « une toute petite opération fait lagger ») :
	# un geste de cases ne réécrit plus le .mbproj tout de suite, et ne reconstruit que ses alentours.
	# L'attendu vient du DISQUE (le fichier relu), pas de l'état de l'écran.
	ed._aller_a("monde")
	ed._enregistrer()
	var sur_disque := FileAccess.get_file_as_string(ed._projet)
	var loin := Vector3i(57, 0, 57)
	var completes: int = ed._vue.monde().reconstructions_completes
	ed._appliquer({"poser": {loin: true}, "effacer": {}}, "Add")
	_vrai(ed._vue.monde().reconstructions_completes == completes,
		"une case posée ne reconstruit que ses alentours (aucune reconstruction complète)")
	_vrai(ed._vue.cases().get_cell_item(loin) != GridMap.INVALID_CELL_ITEM
		and ed._vue.monde().get_node("Rendu").get_cell_item(loin) != GridMap.INVALID_CELL_ITEM,
		"et la case est posée, ses pièces dessinées")
	_egal(FileAccess.get_file_as_string(ed._projet), sur_disque, "un geste de cases ne réécrit PAS le projet tout de suite")
	_vrai(not ed._minuterie_projet.is_stopped(), "(il attend sa seconde)")
	_egal(ed._etat_enregistre.text, "● Saving…", "et la barre dit « Saving… »")
	ed._minuterie_projet.timeout.emit()
	# ⚠ L'ENREGISTREMENT DIFFÉRÉ S'ÉCRIT SUR UN AUTRE FIL (2 octobre 2026) : la barre dit « Saving… » tant qu'il
	# écrit, puis « Saved » — on attend qu'il ait fini, image par image.
	_vrai(ed._tache_ecriture >= 0, "l'enregistrement différé part sur un autre fil")
	for i in 120:
		if ed._tache_ecriture < 0:
			break
		await process_frame
	var relu_geste: Dictionary = Projet.depuis_texte(FileAccess.get_file_as_string(ed._projet), [])
	_vrai(not relu_geste.is_empty() and relu_geste["couches"][ed._active]["cases"].has(loin),
		"la seconde passée, le projet sur disque porte la case")
	_egal(ed._etat_enregistre.text, "✓ Saved", "et la barre dit « Saved »")
	ed._histoire.undo()
	_vrai(not ed._minuterie_projet.is_stopped(), "un Ctrl+Z attend lui aussi sa seconde")
	ed._unhandled_key_input(_cle(KEY_S, true))
	var relu_annule: Dictionary = Projet.depuis_texte(FileAccess.get_file_as_string(ed._projet), [])
	_vrai(ed._minuterie_projet.is_stopped() and not relu_annule.is_empty()
		and not relu_annule["couches"][ed._active]["cases"].has(loin),
		"Ctrl+S écrit tout de suite le projet qui attendait (la case annulée n'y est plus)")


## UN TÉMOIN PAR COUCHE (Jordan, 30 septembre 2026) — on le retrouve, on le remodifie, et le remodeler ne
## touche AUCUNE autre couche. ⚠ Le défaut d'avant : un témoin modélisé par PROJET, qui changeait en silence
## les tuiles d'une autre couche au chargement suivant. Jugé sur les positions des tuiles et sur les octets
## des fichiers, jamais sur ce que l'écran en dit.
func _les_couches_et_leurs_temoins(ed: Control) -> void:
	var mo: Node3D = ed._modeleur
	ed._aller_a("witness")
	ed._regler_edition(true)
	var ia: int = ed._active
	var ca: Dictionary = ed._couches[ia]
	var ta: RefCounted = mo.temoin
	_vrai(ta != null and ta == ca.get("_temoin"), "en édition, le modeleur tient le témoin de la couche active")
	# Le témoin de A, écrit sur disque AVANT qu'on touche à B : ses octets ne doivent plus bouger.
	ed._temoins_sales[ta] = true
	ed._enregistrer_le_temoin_modele(true)
	var glb_a: String = ed._glb_du_temoin(ca)
	var md5_a: String = FileAccess.get_md5(glb_a) if FileAccess.file_exists(glb_a) else ""
	_vrai(md5_a != "", "le témoin de la couche A a son propre .glb (%s)" % glb_a.get_file())

	# « Copy witness » : une couche B, active, dont le témoin est une COPIE — mêmes formes, autre objet.
	var n_avant: int = ed._couches.size()
	ed._copier_le_temoin()
	var ib: int = ed._active
	var cb: Dictionary = ed._couches[ib]
	var tb: RefCounted = mo.temoin
	_vrai(ed._couches.size() == n_avant + 1 and ib != ia and tb != null and tb != ta and tb == cb.get("_temoin"),
		"Copy witness : une couche neuve, active, et le modeleur passe à SON témoin")
	var paroi := "mb_plaque_b2h2_dehors"
	_vrai(tb.tuiles[paroi].sommets == ta.tuiles[paroi].sommets, "la copie a les mêmes tuiles que l'original")
	_vrai(FileAccess.file_exists(str(cb["temoin"])) and str(cb["temoin"]).contains("_layer" + str(cb["id"]))
		and FileAccess.file_exists(ed._glb_du_temoin(cb)), "la copie a SES fichiers (%s)" % str(cb["temoin"]).get_file())

	# On sculpte B : G Z 1 sur une face de sa paroi.
	# ⚠ UNE FACE DU DEDANS (6 octobre 2026) : depuis que les couches partagent leurs BORDS, un geste sur un sommet de bord
	# entraîne A — c'est voulu, et gardé par `_les_bords_entre_couches`. Ce qui reste vrai, et que ceci garde : sculpter le
	# dedans d'une tuile de B ne touche ni le témoin ni le monde de A (le défaut d'avant : un témoin par PROJET).
	var occ_b: int = tb.occurrences_de(paroi)[0]
	mo.activer(occ_b)
	mo.choisir_mode("face")
	mo.tout_choisir(false)
	mo.sections.indexer()
	var face_dedans := -1
	for f in tb.tuiles[paroi].faces.size():
		var au_bord := false
		for j in tb.tuiles[paroi].faces[f]:
			au_bord = au_bord or mo.sections.est_de_bord(paroi, j)
		if not au_bord:
			face_dedans = f
			break
	_vrai(face_dedans >= 0, "la paroi a une face dont aucun sommet n'est sur un bord")
	mo.sel_f = {maxi(face_dedans, 0): true}
	var avant_b: PackedVector3Array = tb.tuiles[paroi].sommets.duplicate()
	var avant_a: PackedVector3Array = ta.tuiles[paroi].sommets.duplicate()
	for k in [KEY_G, KEY_Z, KEY_1, KEY_ENTER]:
		ed._input(_cle(k))
	_vrai(tb.tuiles[paroi].sommets != avant_b, "G Z 1 sculpte la paroi du témoin de B")
	_vrai(ta.tuiles[paroi].sommets == avant_a, "le témoin de A n'a PAS bougé")
	# ⚠ L'ENREGISTREMENT DIFFÉRÉ N'ÉCRIT QUE LE .mbtiles (1er octobre 2026 : il gelait l'appli) : le monde de B
	# attend qu'on le regarde, et la liste le dit.
	var lot_b_avant = ed._vue.couche(ib).lot
	var md5_glb_b: String = FileAccess.get_md5(ed._glb_du_temoin(cb))
	var t_diff := Time.get_ticks_msec()
	ed._enregistrer_le_temoin_modele()
	print("   (l'enregistrement différé : %d ms)" % (Time.get_ticks_msec() - t_diff))
	_vrai(ed._vue.couche(ib).lot == lot_b_avant and FileAccess.get_md5(ed._glb_du_temoin(cb)) == md5_glb_b,
		"l'enregistrement différé ne réécrit ni le .glb ni le monde (ils attendent qu'on les regarde)")
	var relu_sculpte: RefCounted = TL.depuis_dictionnaire(JSON.parse_string(FileAccess.get_file_as_string(str(cb["temoin"]))))
	_vrai(relu_sculpte != null and relu_sculpte.tuiles[paroi].sommets == tb.tuiles[paroi].sommets,
		"mais le geste est sur disque (.mbtiles), tout de suite")
	_vrai(ed._etat_de(ib).ends_with("when you open World"), "et la liste dit que le monde suivra (%s)" % ed._etat_de(ib))
	ed._enregistrer_le_temoin_modele(true)
	_egal(FileAccess.get_md5(glb_a), md5_a, "le .glb de A garde ses octets : remodeler B ne touche pas A (le défaut d'avant)")
	ed._aller_a("monde")
	ed._aller_a("witness")

	# LE MONDE SUIT SON TÉMOIN (Jordan, 1er octobre 2026) : sans bouton, la couche B a pris les tuiles de SON
	# témoin tel qu'il vient d'être sculpté — la paroi posée EST celle du témoin, au millième près.
	var glb_b: String = ed._glb_du_temoin(cb)
	var lot_a = ed._vue.couche(ia).lot
	_vrai(str(cb["source"]) == glb_b and ed._vue.couche(ib).lot != null, "la couche B a suivi son témoin : ses tuiles viennent de lui")
	_vrai(_forme_de(_tuile_du_lot(ed._vue.couche(ib).lot, paroi)) == _forme_de(tb.tuiles[paroi].vers_array_mesh(false)),
		"la paroi posée dans le monde de B est celle de son témoin sculpté")
	_vrai(ed._etat_de(ib).ends_with("sliced"), "et la liste dit qu'elle est à jour (%s)" % ed._etat_de(ib))
	# LE VERDICT DES ENSEMBLES PBR EST GARDÉ (4 octobre 2026 : ~1,4 s à chaque ouverture de l'exemple). La couche B, au
	# témoin enregistré : une clé stable, le verdict « à jour » écrit sous elle, et une autre clé si le lot posé change.
	var cle_ens: String = ed._cle_des_ensembles(cb)
	_vrai(cle_ens != "" and cle_ens == ed._cle_des_ensembles(cb), "ensembles PBR : une clé, stable")
	# ⚠ L'ENTRÉE EST EFFACÉE D'ABORD : le cache survit d'un passage à l'autre, et une valeur laissée par le précédent
	# aurait pu passer pour celle-ci (vu en mutation).
	var avant_gardes := ConfigFile.new()
	avant_gardes.load(ed.ENSEMBLES_A_JOUR)
	if avant_gardes.has_section_key("a_jour", str(cb["temoin"]).md5_text()):
		avant_gardes.erase_section_key("a_jour", str(cb["temoin"]).md5_text())
		avant_gardes.save(ed.ENSEMBLES_A_JOUR)
	_vrai(not ed._ensembles_en_retard(cb), "… la couche B n'est pas en retard")
	var gardes := ConfigFile.new()
	gardes.load(ed.ENSEMBLES_A_JOUR)
	_egal(str(gardes.get_value("a_jour", str(cb["temoin"]).md5_text(), "")), cle_ens, "… et ce verdict est gardé sous sa clé")
	var lot_ens: MeshLibrary = ed._vue.couche(ib).lot
	var empreinte_b = lot_ens.get_meta("empreinte", "")
	lot_ens.set_meta("empreinte", "un autre lot")
	_vrai(ed._cle_des_ensembles(cb) != cle_ens, "… un autre lot posé : une autre clé (la vérification est refaite)")
	lot_ens.set_meta("empreinte", empreinte_b)
	# LA VIGNETTE GARDÉE SUR DISQUE (4 octobre 2026 : à l'ouverture, chaque vignette chargeait son témoin entier) : un
	# `.mbtiles` déjà photographié se montre par l'image gardée sous son empreinte, sans charger le témoin. Une image de
	# 8 × 8 posée à la main dans le cache, un `.mbtiles` factice.
	var faux_temoin := "user://fumee/vignette_factice.mbtiles"
	FileAccess.open(faux_temoin, FileAccess.WRITE).store_string("{\"factice\": true}")
	var petite := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	petite.fill(Color.RED)
	DirAccess.make_dir_recursive_absolute(ed.DOSSIER_VIGNETTES)
	var chemin_vignette: String = ed._chemin_de_vignette(FileAccess.get_md5(faux_temoin))
	petite.save_png(chemin_vignette)
	var couche_factice := {"nom": "factice", "temoin": faux_temoin, "source": ""}
	var vignette: Texture2D = ed._vignette_de(couche_factice)
	_vrai(vignette != null and vignette.get_size() == Vector2(8, 8) and not couche_factice.has("_temoin"),
		"une vignette gardée sous l'empreinte du .mbtiles : montrée sans charger le témoin")
	_vrai(ed._vignette_en_cache("pas_une_empreinte") == null, "… et rien sous une autre empreinte")
	DirAccess.remove_absolute(chemin_vignette)
	DirAccess.remove_absolute(faux_temoin)
	# L'EMPREINTE DE LA LISTE EST GARDÉE (4 octobre 2026 : la liste relisait le MD5 de chaque `.glb` après chaque
	# geste, ~110 ms sur l'exemple) : tant que date et taille ne bougent pas, elle n'est pas relue ; un fichier réécrit
	# (autre taille) l'est. Attendus : `FileAccess.get_md5`, hors de la fonction éprouvée.
	var essai_glb := "user://fumee/empreinte_liste.glb"
	FileAccess.open(essai_glb, FileAccess.WRITE).store_string("aaaa")
	_egal(ed._empreinte_pour_la_liste(essai_glb), FileAccess.get_md5(essai_glb), "empreinte de la liste : le MD5 du fichier")
	ed._empreintes_vues[essai_glb][1] = "gardée"
	_egal(ed._empreinte_pour_la_liste(essai_glb), "gardée", "… gardée tant que le fichier ne change pas (pas relue)")
	FileAccess.open(essai_glb, FileAccess.WRITE).store_string("bbbbbb")
	_egal(ed._empreinte_pour_la_liste(essai_glb), FileAccess.get_md5(essai_glb), "… relue quand le fichier change de taille")
	# Réécrit par l'appli (`_rhabiller` d'une couche dont c'est le `.glb`) : relue — et l'empreinte d'un AUTRE `.glb`
	# reste gardée (tout oublier faisait relire le MD5 de chaque couche après chaque Ctrl+S, ~70 ms sur l'exemple).
	ed._empreintes_vues[essai_glb][1] = "gardée"
	ed._empreintes_vues["user://fumee/autre_couche.glb"] = [[0, 0], "autre gardée"]
	ed._rhabiller({"temoin": essai_glb.get_basename() + ".mbtiles", "_glb_perime": true, "_temoin": tb.copie()})
	_egal(ed._empreinte_pour_la_liste(essai_glb), FileAccess.get_md5(essai_glb), "… et relue après une réécriture par l'appli")
	_egal(ed._empreintes_vues.get("user://fumee/autre_couche.glb", [null, ""])[1], "autre gardée",
		"… celle d'une autre couche reste gardée")
	ed._empreintes_vues.erase("user://fumee/autre_couche.glb")
	DirAccess.remove_absolute(essai_glb)
	# ⚠ UN CTRL+Z, PAS UN SECOND « G Z 1 » : la bride peut arrêter un second geste (la face se replierait).
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_vrai(tb.tuiles[paroi].sommets == avant_b, "(Ctrl+Z a défait le geste dans B)")
	ed._enregistrer_le_temoin_modele()
	DirAccess.remove_absolute(Projet.chemin_cache(glb_b))
	var t0 := Time.get_ticks_msec()
	ed._aller_a("monde")
	print("   (le monde de B suit son témoin en %d ms, au passage dans World)" % (Time.get_ticks_msec() - t0))
	# LE CACHE EST REPORTÉ (4 octobre 2026 : ~270 ms à chaque passage dans World) : pas encore écrit, mais le lot posé
	# porte déjà l'empreinte du `.glb` relu — la liste dit « sliced » ; Ctrl+S l'écrit, à jour. Attendu : le MD5 du fichier.
	_vrai(not FileAccess.file_exists(Projet.chemin_cache(glb_b)), "le monde suit son témoin sans écrire le cache tout de suite")
	_egal(str(ed._vue.couche(ib).lot.get_meta("empreinte", "")), FileAccess.get_md5(glb_b),
		"… le lot posé porte l'empreinte du .glb qu'il vient de lire")
	_vrai(ed._etat_de(ib).contains("sliced") and not ed._etat_de(ib).contains("again"),
		"… et la liste le dit à jour (%s)" % ed._etat_de(ib))
	ed._enregistrer_tout()
	var cache_b: Dictionary = Projet.lire_cache(glb_b)
	_vrai(cache_b["a_jour"] and cache_b["lot"] != null
		and (cache_b["lot"] as MeshLibrary).get_item_list().size() == ed._vue.couche(ib).lot.get_item_list().size(),
		"Ctrl+S écrit le cache reporté, à jour")
	ed._aller_a("witness")
	_vrai(_forme_de(_tuile_du_lot(ed._vue.couche(ib).lot, paroi)) == _forme_de(tb.tuiles[paroi].vers_array_mesh(false)),
		"Ctrl+Z dans le témoin : le monde de B le suit aussi")
	_vrai(ed._vue.couche(ia).lot == lot_a, "et le monde de A n'a pas bougé")
	# Une couche habillée par un travail EXTERNE non lié le garde : son témoin n'est pas sa source.
	var lot_b = ed._vue.couche(ib).lot
	cb["source"] = "D:/ailleurs/travail_non_lie.glb"
	ed._temoins_sales[tb] = true
	ed._enregistrer_le_temoin_modele(true)
	_vrai(str(cb["source"]) == "D:/ailleurs/travail_non_lie.glb" and ed._vue.couche(ib).lot == lot_b,
		"une couche habillée par un travail externe le garde quand son témoin change")
	cb["source"] = glb_b
	ed._unhandled_key_input(_cle(KEY_Y, true))
	var apres_un: PackedVector3Array = tb.tuiles[paroi].sommets.duplicate()

	# On revient à A : le modeleur prend SON témoin. Puis Ctrl+Z : le geste revient dans le témoin de B.
	ed._activer(ia)
	_vrai(mo.temoin == ta, "changer de couche change le témoin en édition")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_vrai(tb.tuiles[paroi].sommets == avant_b, "Ctrl+Z, depuis la couche A, défait le geste DANS le témoin de B")
	_vrai(ta.tuiles[paroi].sommets == avant_a and mo.temoin == ta, "et ne touche ni le témoin de A, ni l'édition")
	ed._enregistrer_le_temoin_modele()
	var relu_b: RefCounted = TL.depuis_dictionnaire(JSON.parse_string(FileAccess.get_file_as_string(str(cb["temoin"]))))
	_vrai(relu_b != null and relu_b.tuiles[paroi].sommets == avant_b, "et le témoin de B est réécrit sur disque, défait")
	_vrai(apres_un != avant_b, "(le geste avait bien changé B)")

	# La liste : une ligne par couche, sa vignette, d'où vient son témoin.
	ed._rafraichir_couches()
	var lignes: Array = ed._liste_couches.get_children()
	var textes: Array = []
	var vignettes := true
	for l in lignes:
		var tr: TextureRect = null
		var bouton: Button = null
		for e in l.get_children():
			if e is TextureRect:
				tr = e
			elif e is Button and (e as Button).button_group != null:
				bouton = e
		vignettes = vignettes and tr != null and tr.texture != null
		textes.append(bouton.text if bouton != null else "")
	_vrai(lignes.size() == ed._couches.size() and vignettes, "une ligne par couche, chacune avec la vignette de son témoin")
	_vrai(String(textes[ib]).contains("modelled"), "la ligne de B dit que son témoin est modélisé (%s)" % String(textes[ib]).replace("\n", " · "))
	_vrai(ed._etiquette_temoin_couche.text.contains(ca["nom"]), "Witness dit quel témoin on édite (%s)" % ed._etiquette_temoin_couche.text)

	# Rouvert : chaque couche retrouve SON témoin, depuis son fichier.
	cb["source"] = ""
	ed._regler_edition(false)
	ed._minuterie_temoin.stop()
	ed._enregistrer()
	var projet: String = ed._projet
	await ed._ouvrir(projet)
	var cb2: Dictionary = {}
	for c in ed._couches:
		if str(c.get("id", "")) == str(cb["id"]):
			cb2 = c
	_vrai(not cb2.is_empty() and str(cb2["temoin"]) == str(cb["temoin"]), "rouvert : la couche B garde le chemin de SON témoin")
	if not cb2.is_empty():
		_vrai(ed._temoin_de(cb2).tuiles[paroi].sommets == avant_b, "et le relit depuis son fichier")

	# UN PROJET D'AVANT : son témoin unique (`<projet>_witness.mbtiles`) est confié à la couche active.
	var vieux := ProjectSettings.globalize_path("user://fumee/avant.mbproj")
	var vieux_temoin := vieux.get_basename() + "_witness.mbtiles"
	DirAccess.copy_absolute(ProjectSettings.globalize_path(str(cb["temoin"])), vieux_temoin)
	var f := FileAccess.open(vieux, FileAccess.WRITE)
	f.store_string('{"format": "marchingblocks-project", "version": 1, "active": 0, "couches": [{"nom": "Old", "source": "", "cases": []}]}')
	f.close()
	await ed._ouvrir(vieux)
	_egal(str(ed._couches[0]["temoin"]), vieux_temoin, "un projet d'avant : son témoin unique est confié à la couche")
	_vrai(ed._rapport.text.contains("now belongs to layer"), "et le rapport le dit")
	# ⚠ ET IL SE RELIT DEPUIS CE CHEMIN-LÀ, pas depuis celui que l'identifiant donnerait (« …_layer1 ») : sans
	# cette relecture, ignorer le chemin enregistré restait une mutation MUETTE.
	_vrai(ed._temoin_de(ed._couches[0]).tuiles[paroi].sommets == avant_b,
		"et la couche relit l'ancien témoin, depuis SON chemin")
	# Et une retouche s'ÉCRIT dans ce fichier-là (et dans le .glb voisin) : écrite ailleurs, elle serait perdue
	# au chargement suivant — c'est ce que la lecture seule ne pouvait pas voir.
	var t_vieux: RefCounted = ed._temoin_de(ed._couches[0])
	t_vieux.tuiles[paroi].sommets[0] += Vector3(0, 0.125, 0)
	var retouche: Vector3 = t_vieux.tuiles[paroi].sommets[0]
	ed._temoins_sales[t_vieux] = true
	ed._enregistrer_le_temoin_modele(true)
	var relu_vieux: RefCounted = TL.depuis_dictionnaire(JSON.parse_string(FileAccess.get_file_as_string(vieux_temoin)))
	_vrai(relu_vieux != null and relu_vieux.tuiles[paroi].sommets[0].is_equal_approx(retouche)
		and FileAccess.file_exists(vieux.get_basename() + "_witness.glb"),
		"une retouche du témoin repris s'écrit dans SON fichier (et son .glb à côté)")
	# On rend le projet de la fumée — PAR LA LISTE DES PROJETS RÉCENTS (3 octobre 2026) : il y est, l'ouvert n'y est pas.
	var recent: Button = null
	for b in ed._recents.get_children():
		if b is Button and (b as Button).tooltip_text == "Open " + projet:
			recent = b
	_vrai(recent != null, "Project : le projet d'avant est dans « Recent »")
	var ouvert_dedans := false
	for b in ed._recents.get_children():
		ouvert_dedans = ouvert_dedans or (b is Button and (b as Button).tooltip_text == "Open " + ed._projet)
	_vrai(not ouvert_dedans, "… pas le projet ouvert")
	if recent != null:
		recent.pressed.emit()
		for i in 120:
			await process_frame
			if ed._projet == projet and not ed._ouverture:
				break
	if ed._projet != projet:
		await ed._ouvrir(projet)
	_egal(ed._projet, projet, "un clic sur un projet récent le rouvre")
	for chemin in [vieux, vieux_temoin, vieux.get_basename() + "_witness.glb"]:
		DirAccess.remove_absolute(chemin)
	_couches_finies = true


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
	var refaits: int = pl.maillages_refaits
	leg.rafraichir_tuiles()
	var apres: AABB = (pl.cartes[coin]["tuile"] as MeshInstance3D).mesh.get_aabb()
	_vrai(apres.position.y < avant.position.y - 0.3, "la photo de la tuile montre la sculpture après rafraîchissement")
	# ⚠ UNE TUILE CHANGÉE, UN MAILLAGE REFAIT (4 octobre 2026 : chaque enregistrement refaisait les 52).
	_egal(pl.maillages_refaits - refaits, 1, "… seul le maillage de la tuile sculptée est refait")
	leg.rafraichir_tuiles()
	_egal(pl.maillages_refaits - refaits, 1, "… et un second rafraîchissement sans geste n'en refait aucun")
	mo.maillage.sommets[bas] -= Vector3(0, -0.4, 0)
	ed._regler_edition(false)
	leg.montrer_onglet("formes")
	_vrai(leg._defile.visible and not pl.visible, "l'onglet des formes revient")
	# PLANCHE CACHÉE : rien n'est repris ; elle se reprend en se montrant.
	leg.rafraichir_tuiles()
	_vrai(pl._a_reprendre and (pl.cartes[coin]["tuile"] as MeshInstance3D).mesh.get_aabb().position.y < avant.position.y
		- 0.3, "planche cachée : la photo attend (la sculpture rendue n'y est pas encore)")
	leg.montrer_onglet("tuiles")
	_vrai(not pl._a_reprendre and is_equal_approx((pl.cartes[coin]["tuile"] as MeshInstance3D).mesh.get_aabb()
		.position.y, avant.position.y), "… et se reprend en se montrant")
	leg.montrer_onglet("formes")
	_planche_finie = true


var _sections_finies := false


## LES SECTIONS PARTAGÉES DANS LE MODELEUR (charte §3, point 2) : un sommet de BORD de la paroi, déplacé au
## clavier (G, un axe, une valeur, Entrée). ⚠ L'ATTENDU EST HORS DE `sections.gd` : les VRAIS JOINTS du témoin
## (deux occurrences voisines, les sommets qui y coïncident dans le monde) doivent rester fermés.
func _les_sections_dans_le_modeleur(ed: Control) -> void:
	const ME := preload("res://addons/marchingblocks_core/maillage_edite.gd")
	ed._aller_a("witness")
	ed._regler_edition(true)
	var mo: Node3D = ed._modeleur
	var t: RefCounted = mo.temoin
	var paroi := "mb_plaque_b2h2_dehors"
	mo.activer(int(t.occurrences_de(paroi)[0]))
	mo.sections.indexer()
	var i_bord := -1
	var axe_face := -1
	for i in (mo.sections.bords[paroi] as Dictionary):
		var faces: Array = mo.sections.bords[paroi][i]
		if faces.size() == 1 and i_bord < 0:
			i_bord = i
			axe_face = faces[0]["axe"]
	_vrai(i_bord >= 0, "la paroi a un sommet de bord posé sur une seule face")
	if i_bord < 0:
		return
	var paires: Array = _paires_des_joints(t)
	_egal(_joints_ouverts(t, paires), 0, "avant le geste, les %d paires des joints du témoin coïncident" % paires.size())
	var photo := {}
	for c in t.tuiles:
		photo[c] = (t.tuiles[c].sommets as PackedVector3Array).duplicate()
	# Un axe du MONDE dans le plan du sommet, et un axe le long de sa normale (les lettres de Blender).
	var normale_monde: Vector3 = (mo.pose.basis * _unitaire(axe_face)).abs()
	var lettres := {KEY_X: Vector3(1, 0, 0), KEY_Z: Vector3(0, 1, 0), KEY_Y: Vector3(0, 0, 1)}
	var dans_le_plan: Key = KEY_NONE
	var le_long: Key = KEY_NONE
	for k in lettres:
		if (lettres[k] as Vector3).dot(normale_monde) < 0.5 and dans_le_plan == KEY_NONE:
			dans_le_plan = k
		elif (lettres[k] as Vector3).dot(normale_monde) > 0.5:
			le_long = k
	mo.choisir_mode("sommet")
	mo.tout_choisir(false)
	mo.sel_s = {i_bord: true}
	var avant_monde: Vector3 = mo.pose * mo.maillage.sommets[i_bord]
	for k in [KEY_G, dans_le_plan, KEY_0, KEY_PERIOD, KEY_1, KEY_ENTER]:
		ed._input(_cle(k))
	var ecart: Vector3 = mo.pose * mo.maillage.sommets[i_bord] - avant_monde
	_vrai(absf(ecart.length() - 0.1) < 1e-4, "G %s 0.1 : le sommet de bord glisse d'un dixième de case dans son plan (%s)"
		% [OS.get_keycode_string(dans_le_plan), ecart])
	var changees := 0
	for c in t.tuiles:
		if c != paroi and t.tuiles[c].sommets != photo[c]:
			changees += 1
	_vrai(changees >= 2, "ses correspondants suivent, dans %d autres tuiles" % changees)
	_egal(_joints_ouverts(t, paires), 0, "après le geste, tous les joints du témoin coïncident encore")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	var rendues := 0
	for c in t.tuiles:
		if t.tuiles[c].sommets == photo[c]:
			rendues += 1
	_egal(rendues, t.tuiles.size(), "UN Ctrl+Z rend toutes les tuiles touchées")
	ed._unhandled_key_input(_cle(KEY_Y, true))
	_vrai(absf((mo.pose * mo.maillage.sommets[i_bord] - avant_monde).length() - 0.1) < 1e-4
		and _joints_ouverts(t, paires) == 0, "Ctrl+Y le refait, joints fermés")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	# Le long de la normale : le sommet de bord ne quitte pas son plan.
	mo.sel_s = {i_bord: true}
	for k in [KEY_G, le_long, KEY_0, KEY_PERIOD, KEY_1, KEY_ENTER]:
		ed._input(_cle(k))
	_vrai((mo.pose * mo.maillage.sommets[i_bord]).is_equal_approx(avant_monde),
		"G %s 0.1 (le long de la normale) : le sommet de bord ne quitte pas son plan" % OS.get_keycode_string(le_long))
	ed._unhandled_key_input(_cle(KEY_Z, true))
	# Échap rend tout, y compris les autres tuiles.
	mo.sel_s = {i_bord: true}
	for k in [KEY_G, dans_le_plan, KEY_0, KEY_PERIOD, KEY_1]:
		ed._input(_cle(k))
	var pendant := 0
	for c in t.tuiles:
		if c != paroi and t.tuiles[c].sommets != photo[c]:
			pendant += 1
	ed._input(_cle(KEY_ESCAPE))
	var apres_echap := 0
	for c in t.tuiles:
		if t.tuiles[c].sommets != photo[c]:
			apres_echap += 1
	_vrai(pendant >= 2 and apres_echap == 0, "pendant le geste %d autres tuiles suivent ; Échap les rend toutes" % pendant)
	# POINT 3 — LES COUPES SUR LES BORDS : un loop cut dont l'anneau traverse un bord, puis un couteau parti d'une
	# arête de bord. Chaque sommet neuf est reporté dans les tuiles qui partagent ce bord.
	_egal(_sans_partenaire(t), 0, "avant les coupes, tout sommet de joint a son partenaire")
	var faces_avant := {}
	for c in t.tuiles:
		faces_avant[c] = t.tuiles[c].faces.size()
	var anneau_bord := Vector2i(-1, -1)
	for ar in mo.maillage.aretes():
		for r in mo.maillage.anneau(ar):
			var pa: Vector3 = mo.maillage.sommets[r[0]]
			var pb: Vector3 = mo.maillage.sommets[r[1]]
			for axe in 3:
				if anneau_bord.x < 0 and absf(absf(pa[axe]) - 0.5) < 0.0005 and absf(pa[axe] - pb[axe]) < 0.0005:
					anneau_bord = ar
	_vrai(anneau_bord.x >= 0, "la paroi a un anneau qui traverse un bord")
	mo.modal = "loop"
	mo._anneau_vise = [anneau_bord]
	mo._couper_la_boucle()
	var coupees := 0
	for c in t.tuiles:
		# ⚠ LES SOMMETS, PAS LES FACES : reporter un point de bord l'INSÈRE dans les faces existantes (vu : 0 compté).
		if c != paroi and t.tuiles[c].sommets.size() != (photo[c] as PackedVector3Array).size():
			coupees += 1
	_vrai(coupees >= 2, "Ctrl+R sur un bord : la coupe est reportée dans %d autres tuiles" % coupees)
	_egal(_sans_partenaire(t), 0, "après le loop cut, tout sommet de joint a son partenaire")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	var rendues_coupe := 0
	for c in t.tuiles:
		if t.tuiles[c].faces.size() == faces_avant[c] and t.tuiles[c].sommets == photo[c]:
			rendues_coupe += 1
	_egal(rendues_coupe, t.tuiles.size(), "UN Ctrl+Z défait la coupe dans toutes les tuiles")
	ed._unhandled_key_input(_cle(KEY_Y, true))
	_egal(_sans_partenaire(t), 0, "Ctrl+Y la refait, partout")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	# Le couteau : d'une arête de bord au milieu d'une autre arête de la même face.
	var coup: Array = []
	for f in mo.maillage.faces.size():
		var face: PackedInt32Array = mo.maillage.faces[f]
		if face.size() != 4 or not coup.is_empty():
			continue
		for k in 4:
			var a := face[k]
			var b := face[(k + 1) % 4]
			var pa: Vector3 = mo.maillage.sommets[a]
			var pb: Vector3 = mo.maillage.sommets[b]
			var sur_le_bord := false
			for axe in 3:
				if absf(absf(pa[axe]) - 0.5) < 0.0005 and absf(pa[axe] - pb[axe]) < 0.0005:
					sur_le_bord = true
			if sur_le_bord and coup.is_empty():
				var c2 := face[(k + 2) % 4]
				var d2 := face[(k + 3) % 4]
				coup = [{"arete": ME.arete(a, b), "t": 0.5, "point": (pa + pb) * 0.5},
					{"arete": ME.arete(c2, d2), "t": 0.5, "point": (mo.maillage.sommets[c2] + mo.maillage.sommets[d2]) * 0.5}]
	_vrai(not coup.is_empty(), "une face de la paroi a une arête sur un bord")
	mo.modal = "knife"
	mo._couteau = coup
	mo._finir_le_couteau()
	var coupees_k := 0
	for c in t.tuiles:
		# ⚠ LES SOMMETS, PAS LES FACES : reporter un point de bord l'INSÈRE dans les faces existantes (vu : 0 compté).
		if c != paroi and t.tuiles[c].sommets.size() != (photo[c] as PackedVector3Array).size():
			coupees_k += 1
	_vrai(coupees_k >= 2 and _sans_partenaire(t) == 0,
		"K parti d'un bord : la coupe est reportée dans %d autres tuiles, tout joint a son partenaire" % coupees_k)
	ed._unhandled_key_input(_cle(KEY_Z, true))
	# LE COUTEAU TRAVERSANT (Jordan, 2 octobre 2026 : « des motifs qui traversent les bords ») : K, un clic dans une
	# face de la paroi, un clic AU-DELÀ du bord, sur la copie voisine, Entrée — de VRAIS clics posés par la caméra.
	# Attendu : la coupe passe dans les deux copies, tout sommet de joint garde son partenaire, UN Ctrl+Z rend tout.
	# Avant ce jour, le second clic était ignoré sans un mot.
	var cam_k: Camera3D = ed._vue._camera
	var fb := -1
	var kb := -1
	var axe_b := -1
	for g in mo.maillage.faces.size():
		var fg: PackedInt32Array = mo.maillage.faces[g]
		if fg.size() != 4 or fb >= 0:
			continue
		for k in 4:
			var pa: Vector3 = mo.maillage.sommets[fg[k]]
			var pb: Vector3 = mo.maillage.sommets[fg[(k + 1) % 4]]
			for x in 3:
				if fb < 0 and absf(absf(pa[x]) - 0.5) < 0.0005 and absf(pa[x] - pb[x]) < 0.0005:
					fb = g
					kb = k
					axe_b = x
	_vrai(fb >= 0, "la paroi a une face qui touche un bord")
	var fk: PackedInt32Array = mo.maillage.faces[fb]
	var milieu_b: Vector3 = (mo.maillage.sommets[fk[kb]] + mo.maillage.sommets[fk[(kb + 1) % 4]]) * 0.5
	var en_face_b: Vector3 = (mo.maillage.sommets[fk[(kb + 2) % 4]] + mo.maillage.sommets[fk[(kb + 3) % 4]]) * 0.5
	var dehors_b := milieu_b
	dehors_b[axe_b] += 0.25 * signf(milieu_b[axe_b])
	ed._vue._cible = mo.pose * mo.maillage.centre(fb)
	ed._vue._distance = 2.5
	ed._vue._caler()
	var tailles := {}
	for c in t.tuiles:
		tailles[c] = [t.tuiles[c].sommets.size(), t.tuiles[c].faces.size()]
	ed._input(_cle(KEY_K))
	for q in [en_face_b.lerp(mo.maillage.centre(fb), 0.05), dehors_b]:
		var clic_k := InputEventMouseButton.new()
		clic_k.button_index = MOUSE_BUTTON_LEFT
		clic_k.pressed = true
		clic_k.position = cam_k.unproject_position(mo.pose * q)
		ed._vue._gui_input(clic_k)
	_vrai(mo._couteau.size() == 2 and int(mo._couteau[1]["occ"]) != mo.occurrence,
		"le clic au-delà du bord est pris, sur la copie voisine (occurrence %s)" % [mo._couteau.map(func(p): return p.get("occ", -1))])
	ed._input(_cle(KEY_ENTER))
	_vrai(ed._rapport.text.contains("across 2 copies"), "Entrée : la coupe traverse le bord, dans les deux copies")
	var fendues := 0
	for c in t.tuiles:
		if t.tuiles[c].faces.size() > int(tailles[c][1]):
			fendues += 1
	_vrai(fendues >= 1 and _sans_partenaire(t) == 0,
		"… %d tuile(s) fendue(s), et tout sommet de joint garde son partenaire" % fendues)
	ed._unhandled_key_input(_cle(KEY_Z, true))
	var rendues_k := 0
	for c in t.tuiles:
		if t.tuiles[c].sommets.size() == int(tailles[c][0]) and t.tuiles[c].faces.size() == int(tailles[c][1]):
			rendues_k += 1
	_egal(rendues_k, t.tuiles.size(), "UN Ctrl+Z rend toutes les tuiles")
	# LA BRIDE (DÉCIDÉ, Jordan, 30 septembre 2026) : les faces ±Z de la paroi glissées d'une DEMI-case de côté (X
	# de la tuile) — là où la capture voyait des faces repliées dans d'AUTRES tuiles. Le long de leur normale, la
	# dalle ne fait que se translater : rien ne replie. Le geste doit s'arrêter
	# avant le premier repli. ⚠ L'attendu est hors du code éprouvé : les triangles en éventail et les normales de
	# départ sont recalculés ici (`_repliees`, `_le_plus_ecrase`).
	var faces_z: Array = []
	for g in mo.maillage.faces.size():
		if absf(mo.maillage.normale(g).z) > 0.9:
			faces_z.append(g)
	var dir_monde: Vector3 = (mo.pose.basis * Vector3(1, 0, 0)).abs()
	var lettre: Key = KEY_NONE
	for k in lettres:
		if (lettres[k] as Vector3).dot(dir_monde) > 0.5:
			lettre = k
	var depart_bride := {}
	for c in t.tuiles:
		depart_bride[c] = (t.tuiles[c].sommets as PackedVector3Array).duplicate()
	var bougent := {}
	for g in faces_z:
		for i in mo.maillage.faces[g]:
			bougent[i] = true
	for valeur in [[KEY_0, KEY_PERIOD, KEY_1], [KEY_MINUS, KEY_0, KEY_PERIOD, KEY_5]]:
		mo.choisir_mode("face")
		mo.tout_choisir(false)
		for g in faces_z:
			mo.sel_f[g] = true
		for k in [KEY_G, lettre] + valeur + [KEY_ENTER]:
			ed._input(_cle(k))
		var pas := 0.0
		for i in bougent:
			pas = maxf(pas, (mo.maillage.sommets[i] - (depart_bride[paroi] as PackedVector3Array)[i]).length())
		var demande := 0.1 if valeur.size() == 3 else 0.5
		_egal(_repliees(t, depart_bride), 0, "G %s %s%.1f sur les faces ±Z de la paroi : aucune face repliée, dans aucune tuile"
			% [OS.get_keycode_string(lettre), "" if demande < 0.2 else "-", demande])
		if demande < 0.2:
			_vrai(absf(pas - 0.1) < 1e-4 and is_equal_approx(mo.bride, 1.0),
				"dans la marge, le geste n'est pas bridé (%.4f)" % pas)
		else:
			var ecrase: Array = _le_plus_ecrase(t, depart_bride)
			print("  bride : %.4f case au lieu de 0,5 (%.3f du geste), arrêtée par « %s » (triangle à %.5f de son aire)"
				% [pas, mo.bride, ecrase[1], float(ecrase[0])])
			_vrai(pas > 0.05 and pas < 0.5 - 1e-3 and mo.bride < 1.0,
				"au-delà, le geste est BRIDÉ : %.4f case au lieu de 0,5 (bride %.3f)" % [pas, mo.bride])
			_vrai(float(ecrase[0]) < 0.02, "et il s'arrête AU repli : un triangle de « %s » est écrasé à %.4f de son aire"
				% [ecrase[1], float(ecrase[0])])
			_vrai(ecrase[1] != paroi, "la face qui arrête le geste est dans une AUTRE tuile (%s)" % ecrase[1])
		_egal(_joints_ouverts(t, paires), 0, "G %.1f : les joints du témoin restent fermés" % demande)
		ed._unhandled_key_input(_cle(KEY_Z, true))
		var rendues_bride := 0
		for c in t.tuiles:
			if t.tuiles[c].sommets == depart_bride[c]:
				rendues_bride += 1
		_egal(rendues_bride, t.tuiles.size(), "G %.1f : UN Ctrl+Z rend toutes les tuiles" % demande)
	# ⚠ CE CAS NE PROUVE PAS QUE LES AUTRES TUILES SONT GARDÉES : la dalle de la paroi s'écrase en même temps que
	# ses voisines (même marge partout), donc garder la seule tuile en édition l'arrêtait aussi — mutation MUETTE.
	# Il faut un geste où une AUTRE tuile replie AVANT celle qu'on édite. `sonde_bride_ailleurs.gd` en trouve 46 ;
	# on rejoue le plus net — le sommet 3 de `mb_vrille_d_b3h1_dehors`, glissé vers −X de la tuile : elle ne replie
	# jamais, `mb_coin_b1h0` replie à 0,25 — et on REVÉRIFIE ici sa condition, qui rougirait si le témoin changeait.
	var vrille := "mb_vrille_d_b3h1_dehors"
	mo.activer(int(t.occurrences_de(vrille)[0]))
	var vers: Vector3 = mo.pose.basis * Vector3(-1, 0, 0)
	var nom_axe := ""
	var signe := ""
	for k in mo.AXES:
		var d: float = (mo.AXES[k] as Vector3).dot(vers)
		if absf(d) > 0.5:
			nom_axe = k
			signe = "" if d > 0.0 else "-"
	mo.choisir_mode("sommet")
	mo.tout_choisir(false)
	mo.sel_s = {3: true}
	var avant_v: Vector3 = mo.maillage.sommets[3]
	mo.commencer("G")
	mo._axe = nom_axe
	mo._saisie = signe + "0.4"
	mo._mettre_a_jour()
	mo.confirmer()
	var marge: float = _min_de_tuile(t, depart_bride, vrille)
	var parcours: float = (mo.maillage.sommets[3] - avant_v).length()
	print("  bride par une autre tuile : %.4f case au lieu de 0,4 (bride %.3f), « %s » garde %.3f de son aire, « %s » %.5f"
		% [parcours, mo.bride, vrille, marge, _le_plus_ecrase(t, depart_bride)[1], float(_le_plus_ecrase(t, depart_bride)[0])])
	_vrai(mo.bride < 1.0 and marge > 0.1,
		"un geste que seule une AUTRE tuile arrête : bridé (%.3f), la tuile en édition garde %.3f de son aire" % [mo.bride, marge])
	_egal(_repliees(t, depart_bride), 0, "et aucune face n'est repliée, dans aucune tuile")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	ed._minuterie_temoin.stop()
	ed._regler_edition(false)
	_sections_finies = true


## Le plus petit rapport d'aire des triangles en éventail d'UNE tuile (INF si aucune face gardable).
func _min_de_tuile(t: RefCounted, depart: Dictionary, c: String) -> float:
	var pire := INF
	var m: RefCounted = t.tuiles[c]
	for face in m.faces:
		for a in _aires_en_eventail(face, depart[c], m.sommets):
			pire = minf(pire, float(a))
	return pire


## Les faces saines au départ (normale de Newell non nulle, triangles en éventail d'aire positive) qu'un triangle
## en éventail a aplaties ou retournées depuis. Faces de 3 et 4 côtés : l'éventail est alors le dessin exact.
## LE SCULPT (Jordan, 3 octobre 2026) — de vrais traits à la souris sur une copie de la paroi, par le vrai bouton.
## Attendus hors du code éprouvé : les VRAIS joints du témoin (`_sans_partenaire`), aucune face repliée (`_repliees`,
## recalculé ici), les positions de départ relevées avant le trait.
var _sculpt_fini := false


func _sculpter_le_temoin(ed: Control) -> void:
	var mo: Node3D = ed._modeleur
	ed._aller_a("witness")
	ed._regler_edition(true)
	var t: RefCounted = mo.temoin
	var cam: Camera3D = mo.camera
	var paroi := "mb_plaque_b2h2_dehors"
	var vise := {}
	for i in t.occurrences_de(paroi):
		var pose: Transform3D = t.occurrences[i]["pose"]
		var tuile: RefCounted = t.tuiles[paroi]
		for f in tuile.faces.size():
			var monde: Vector3 = pose * tuile.centre(f)
			if cam.is_position_behind(monde):
				continue
			var ecran: Vector2 = cam.unproject_position(monde)
			if not Rect2(Vector2(60, 60), ed._vue.size - Vector2(120, 120)).has_point(ecran):
				continue
			var hit: Dictionary = t.rayon(cam.project_ray_origin(ecran), cam.project_ray_normal(ecran))
			if not hit.is_empty() and int(hit["occurrence"]) == i and int(hit["face"]) == f:
				vise = {"occurrence": i, "ecran": ecran}
				break
		if not vise.is_empty():
			break
	_vrai(not vise.is_empty(), "sculpt : une face de la paroi est visible à l'écran")
	if vise.is_empty():
		return
	var depart := {}
	for c in t.tuiles:
		depart[c] = (t.tuiles[c].sommets as PackedVector3Array).duplicate()
	ed._bouton_sculpt.button_pressed = true
	_vrai(mo.sculpt and ed._vue.edition, "le bouton Sculpt allume le sculpt, en édition")
	var survol := InputEventMouseMotion.new()
	survol.position = vise["ecran"]
	mo.souris_entree(survol)
	_vrai(mo.cercle_montre.size() > 0, "survoler montre le cercle du pinceau")
	mo.sculpt_genre = "draw"
	mo.sculpt_rayon = 0.6
	mo.sculpt_force = 1.0
	mo.sculpt_durete = 0.5
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = true
	b.position = vise["ecran"]
	mo.souris_entree(b)
	var chrono := Time.get_ticks_usec()
	for k in 8:
		var m := InputEventMouseMotion.new()
		m.position = vise["ecran"] + Vector2(2.0 * k, 0.0)
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		mo.souris_entree(m)
	print("  (sculpt : %.1f ms par coup de pinceau, sans fenêtre)" % ((Time.get_ticks_usec() - chrono) / 8000.0))
	b.pressed = false
	mo.souris_entree(b)
	var bouge := 0
	var autres := 0
	for c in t.tuiles:
		var avant: PackedVector3Array = depart[c]
		var maintenant: PackedVector3Array = t.tuiles[c].sommets
		if avant.size() != maintenant.size():
			continue
		var change := false
		for j in avant.size():
			if avant[j].distance_to(maintenant[j]) > 1e-4:
				change = true
				if c == paroi:
					bouge += 1
		if change and c != paroi:
			autres += 1
	_vrai(bouge > 0, "un trait Draw déplace des sommets de la paroi (%d) — toutes ses copies avec elle" % bouge)
	_vrai(autres > 0, "ses bords glissent dans leur plan, et %d autre(s) tuile(s) suivent" % autres)
	_egal(_sans_partenaire(t), 0, "après le trait, tout sommet de joint a son partenaire : pas une fente")
	_egal(_repliees(t, depart), 0, "après le trait, aucune face repliée dans aucune tuile")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	var rendues := 0
	for c in t.tuiles:
		rendues += int((t.tuiles[c].sommets as PackedVector3Array) == (depart[c] as PackedVector3Array))
	_egal(rendues, t.tuiles.size(), "UN Ctrl+Z rend les %d tuiles comme avant le trait" % t.tuiles.size())
	ed._unhandled_key_input(_cle(KEY_Y, true))
	_vrai(_sans_partenaire(t) == 0 and (t.tuiles[paroi].sommets as PackedVector3Array) != (depart[paroi] as PackedVector3Array),
		"Ctrl+Y refait le trait, joints fermés")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	# Le coût d'un petit pinceau (rayon 0,05), au même endroit — le cas courant, loin des bords.
	mo.sculpt_rayon = 0.05
	b.pressed = true
	mo.souris_entree(b)
	var chrono2 := Time.get_ticks_usec()
	for k in 8:
		var m2 := InputEventMouseMotion.new()
		m2.position = vise["ecran"] + Vector2(1.0 * k, 0.0)
		m2.button_mask = MOUSE_BUTTON_MASK_LEFT
		mo.souris_entree(m2)
	print("  (sculpt, rayon 0,05 : %.1f ms par coup, sans fenêtre)" % ((Time.get_ticks_usec() - chrono2) / 8000.0))
	b.pressed = false
	mo.souris_entree(b)
	_egal(_sans_partenaire(t), 0, "un petit trait aussi garde tous les joints")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	ed._aller_a("texture")
	_vrai(not mo.sculpt and mo.cercle_montre.is_empty(), "Texturing éteint le sculpt")
	ed._aller_a("witness")
	_sculpt_fini = true


func _repliees(t: RefCounted, depart: Dictionary) -> int:
	var n := 0
	for c in t.tuiles:
		var m: RefCounted = t.tuiles[c]
		var s0: PackedVector3Array = depart[c]
		if s0.size() != m.sommets.size():
			continue
		for face in m.faces:
			for a in _aires_en_eventail(face, s0, m.sommets):
				if a < 1e-6:
					n += 1
					break
	return n


## [le rapport d'aire le plus petit, sa tuile], sur tous les triangles en éventail des faces saines au départ.
func _le_plus_ecrase(t: RefCounted, depart: Dictionary) -> Array:
	var pire := [INF, ""]
	for c in t.tuiles:
		var m: RefCounted = t.tuiles[c]
		var s0: PackedVector3Array = depart[c]
		if s0.size() != m.sommets.size():
			continue
		for face in m.faces:
			for a in _aires_en_eventail(face, s0, m.sommets):
				if a < float(pire[0]):
					pire = [a, c]
	return pire


## Pour une face de 3 ou 4 côtés saine au départ : l'aire orientée de chaque triangle en éventail (orientée par
## la normale de DÉPART), rapportée à son aire de départ. Une face qui n'était pas saine rend [].
func _aires_en_eventail(face: PackedInt32Array, s0: PackedVector3Array, s1: PackedVector3Array) -> Array:
	if face.size() > 4:
		return []
	var nd := Vector3.ZERO
	for k in face.size():
		nd += s0[face[k]].cross(s0[face[(k + 1) % face.size()]])
	if nd.length() < 1e-9:
		return []
	nd = nd.normalized()
	var sortie: Array = []
	for k in range(1, face.size() - 1):
		var a0: float = (s0[face[k]] - s0[face[0]]).cross(s0[face[k + 1]] - s0[face[0]]).dot(nd)
		if a0 <= 1e-9:
			return []
		sortie.append((s1[face[k]] - s1[face[0]]).cross(s1[face[k + 1]] - s1[face[0]]).dot(nd) / a0)
	return sortie


func _unitaire(axe: int) -> Vector3:
	var e := Vector3.ZERO
	e[axe] = 1.0
	return e


## Les VRAIS JOINTS du témoin : pour deux occurrences voisines, les sommets qui coïncident dans le monde sur
## leur plan commun (la même autorité que `test_sections`, écrite hors de `sections.gd`).
func _paires_des_joints(t: RefCounted) -> Array:
	var occ := {}
	for o in t.occurrences:
		occ[o["sommet"]] = o
	var paires: Array = []
	for s in occ:
		var oa: Dictionary = occ[s]
		for axe in 3:
			var e := Vector3i.ZERO
			e[axe] = 1
			if not occ.has(s + e):
				continue
			var ob: Dictionary = occ[s + e]
			var ta: RefCounted = t.tuiles[oa["cle"]]
			var tb: RefCounted = t.tuiles[ob["cle"]]
			var index_b := {}
			for j in tb.sommets.size():
				index_b[Vector3i(((ob["pose"] as Transform3D) * tb.sommets[j] * 10000.0).round())] = j
			for i in ta.sommets.size():
				var pw: Vector3 = (oa["pose"] as Transform3D) * ta.sommets[i]
				if absf(pw[axe] - (float(s[axe]) + 1.5)) > 0.0005:
					continue
				var k := Vector3i((pw * 10000.0).round())
				if index_b.has(k):
					paires.append([oa["cle"], i, oa["pose"], ob["cle"], index_b[k], ob["pose"]])
	return paires


## Les sommets posés sur le plan d'un joint du témoin qui n'ont PAS de partenaire exact dans la tuile d'en face
## (écrit hors de `sections.gd`, comme dans `test_sections`).
## TOUT GESTE TOPOLOGIQUE REPORTE SES POINTS DE BORD (Jordan, 1er octobre 2026 : « la subdivision sans qu'elle
## ne subdivise aussi ses voisines ne rompt-elle pas les sections partagées ? »). Une face de la paroi qui touche
## un bord, subdivisée par le vrai bouton : chaque sommet de joint garde son partenaire, et UN Ctrl+Z rend tout.
## Puis la suppression de cette face, qui change la FORME de la section : rien ne peut suivre, et l'écran le dit.
func _les_gestes_topologiques_gardent_les_sections(ed: Control) -> void:
	ed._aller_a("witness")
	ed._regler_edition(true)
	var mo: Node3D = ed._modeleur
	var t: RefCounted = mo.temoin
	var paroi := "mb_plaque_b2h2_dehors"
	mo.activer(int(t.occurrences_de(paroi)[0]))
	mo.sections.indexer()
	var f_bord := -1
	for f in mo.maillage.faces.size():
		var sur_le_bord := 0
		for i in mo.maillage.faces[f]:
			if mo.sections.est_de_bord(paroi, i):
				sur_le_bord += 1
		if sur_le_bord >= 2 and f_bord < 0:
			f_bord = f
	_vrai(f_bord >= 0, "la paroi a une face posée sur un bord")
	if f_bord < 0:
		return
	_egal(_sans_partenaire(t), 0, "avant la subdivision, tout sommet de joint a son partenaire")
	var photo := {}
	for c in t.tuiles:
		photo[c] = (t.tuiles[c].sommets as PackedVector3Array).duplicate()
	mo.choisir_mode("face")
	mo.tout_choisir(false)
	mo.sel_f = {f_bord: true}
	mo.operer("subdiviser")
	var reportees := 0
	for c in t.tuiles:
		if c != paroi and t.tuiles[c].sommets.size() != (photo[c] as PackedVector3Array).size():
			reportees += 1
	_vrai(reportees >= 2, "subdiviser une face de bord : ses points neufs sont reportés dans %d autres tuiles" % reportees)
	_egal(_sans_partenaire(t), 0, "après la subdivision, tout sommet de joint a son partenaire (le trou d'avant)")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	var rendues := 0
	for c in t.tuiles:
		if t.tuiles[c].sommets == photo[c]:
			rendues += 1
	_egal(rendues, t.tuiles.size(), "UN Ctrl+Z défait la subdivision dans toutes les tuiles")
	mo.choisir_mode("face")
	mo.tout_choisir(false)
	mo.sel_f = {f_bord: true}
	mo.operer("supprimer")
	_vrai(ed._rapport.text.contains("changed the shape of a tile border") and ed._rapport.text.contains("gap"),
		"supprimer une face de bord change la forme de la section : l'écran dit qu'il y aura une fente")
	# FILL HOLES (3 octobre 2026), par le VRAI bouton : le compteur voit le trou ; le bouton le bouche, la section du bord
	# est recréée — les vrais joints du monde se referment (attendu : `_sans_partenaire`, hors du code éprouvé) ; UN Ctrl+Z
	# rend le trou, Ctrl+Y le rebouche.
	var ouverts := _sans_partenaire(t)
	ed._dire_les_trous(true)
	_vrai(ouverts > 0 and ed._trous_texte.text == "1 hole(s) in this tile.",
		"le compteur voit le trou (« %s », %d sommets de joint sans partenaire)" % [ed._trous_texte.text, ouverts])
	var bouton: Button = null
	for b in ed.find_children("*", "Button", true, false):
		if (b as Button).text == "Fill holes":
			bouton = b
	_vrai(bouton != null, "le bouton « Fill holes » existe dans Geometry")
	if bouton != null:
		bouton.pressed.emit()
		_vrai(mo.maillage.trous() == 0 and _sans_partenaire(t) == 0 and ed._rapport.text.contains("Fill holes")
			and ed._rapport.text.contains("tile border"),
			"Fill holes : plus de trou, la section rebâtie, tous les joints du monde refermés (%d)" % _sans_partenaire(t))
		_vrai(ed._trous_texte.text == "No hole in this tile.", "… et le compteur le dit")
		ed._unhandled_key_input(_cle(KEY_Z, true))
		_vrai(mo.maillage.trous() == 1 and _sans_partenaire(t) == ouverts, "UN Ctrl+Z rend le trou")
		ed._unhandled_key_input(_cle(KEY_Y, true))
		_vrai(mo.maillage.trous() == 0 and _sans_partenaire(t) == 0, "Ctrl+Y le rebouche")
		ed._unhandled_key_input(_cle(KEY_Z, true))
	ed._unhandled_key_input(_cle(KEY_Z, true))


## LES GESTES GARDENT LE BORD (Jordan, 4 octobre 2026 : « utiliser très peu Fill holes ») — par de VRAIES touches, sur
## la paroi : E sur une face de bord n'ouvre plus le monde (ses sommets de bord restent) ; E sur une arête à deux faces
## est refusé ; M d'un sommet de bord et d'un intérieur fusionne SUR le sommet de bord, deux sommets de bord sont refusés ;
## Ctrl+X dissout sans trou. Attendus hors du code éprouvé : `_sans_partenaire` (les vrais joints), les positions
## photographiées avant le geste, `est_de_bord` des sections.
func _les_gestes_gardent_le_bord(ed: Control) -> bool:
	ed._aller_a("witness")
	ed._regler_edition(true)
	var mo: Node3D = ed._modeleur
	var t: RefCounted = mo.temoin
	var paroi := "mb_plaque_b2h2_dehors"
	mo.activer(int(t.occurrences_de(paroi)[0]))
	mo.sections.indexer()
	var m: RefCounted = mo.maillage
	var f_bord := -1
	for f in m.faces.size():
		var n := 0
		for i in m.faces[f]:
			if mo.sections.est_de_bord(paroi, i):
				n += 1
		if n >= 1 and n < (m.faces[f] as PackedInt32Array).size() and f_bord < 0:
			f_bord = f
	_vrai(f_bord >= 0, "bord gardé : la paroi a une face qui touche un bord sans y être entière")
	if f_bord < 0:
		return false
	var depart: PackedVector3Array = m.sommets.duplicate()
	var faces0: int = m.faces.size()
	var de_bord: Array = []
	var dedans: Array = []
	for i in m.faces[f_bord]:
		(de_bord if mo.sections.est_de_bord(paroi, i) else dedans).append(i)
	# E 0.1 Entrée sur la face de bord.
	mo.choisir_mode("face")
	mo.tout_choisir(false)
	mo.sel_f = {f_bord: true}
	for k in [KEY_E, KEY_0, KEY_PERIOD, KEY_1, KEY_ENTER]:
		ed._input(_cle(k))
	var restes := 0
	for i in de_bord:
		for p in mo.maillage.sommets:
			if p.is_equal_approx(depart[i]):
				restes += 1
				break
	var n0: Vector3 = (depart[dedans[0]] as Vector3)
	var monte := false
	for p in mo.maillage.sommets:
		if absf(p.distance_to(n0) - 0.1) < 1e-3:
			monte = true
	_vrai(mo.maillage.faces.size() > faces0 and monte and restes == de_bord.size(),
		"E 0.1 sur une face de bord : le dedans avance de 0,1, les %d sommets de bord restent à leur place" % de_bord.size())
	_egal(_sans_partenaire(t), 0, "E sur une face de bord : aucun sommet de joint sans partenaire (976 avant)")
	_egal(mo.maillage.trous(), 0, "E sur une face de bord : aucun trou")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_vrai(mo.maillage.sommets == depart, "UN Ctrl+Z défait l'extrusion")
	# E sur une arête à deux faces : un aileron, refusé.
	m = mo.maillage
	var fpa: Dictionary = m.faces_par_arete()
	var e_int := Vector2i(-1, -1)
	var e_bord := Vector2i(-1, -1)
	for e: Vector2i in fpa:
		var ba: bool = mo.sections.est_de_bord(paroi, e.x)
		var bb: bool = mo.sections.est_de_bord(paroi, e.y)
		if (fpa[e] as Array).size() == 2 and e_int.x < 0:
			e_int = e
		if ba and not bb and e_bord.x < 0:
			e_bord = e
	mo.choisir_mode("arete")
	mo.tout_choisir(false)
	mo.sel_a = {e_int: true}
	ed._input(_cle(KEY_E))
	_vrai(mo.modal == "" and mo.maillage.faces.size() == faces0 and ed._rapport.text.contains("rim of a hole"),
		"E sur une arête entre deux faces : refusé et dit, rien n'a changé")
	# M : un sommet de bord et un intérieur → sur le sommet de bord.
	var vb: int = e_bord.x if mo.sections.est_de_bord(paroi, e_bord.x) else e_bord.y
	var vi: int = e_bord.y if vb == e_bord.x else e_bord.x
	var pb: Vector3 = depart[vb]
	mo.choisir_mode("sommet")
	mo.tout_choisir(false)
	mo.sel_s = {vb: true, vi: true}
	ed._input(_cle(KEY_M))
	var au_bord := false
	var interieur_parti := true
	for p in mo.maillage.sommets:
		au_bord = au_bord or p.is_equal_approx(pb)
		interieur_parti = interieur_parti and not p.is_equal_approx(depart[vi])
	_vrai(au_bord and interieur_parti and mo.maillage.sommets.size() == depart.size() - 1,
		"M d'un sommet de bord et d'un intérieur : un seul reste, À LA PLACE du sommet de bord")
	_egal(_sans_partenaire(t), 0, "M au bord : aucun sommet de joint sans partenaire (244 avant)")
	_egal(mo.maillage.trous(), 0, "M au bord : aucun trou")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	# M de deux sommets de bord à des places différentes : refusé.
	var deux: Array = []
	for i in mo.maillage.sommets.size():
		if mo.sections.est_de_bord(paroi, i) and deux.size() < 2:
			deux.append(i)
	mo.sel_s = {deux[0]: true, deux[1]: true}
	ed._input(_cle(KEY_M))
	_vrai(mo.maillage.sommets == depart and ed._rapport.text.contains("different places"),
		"M de deux sommets de bord : refusé et dit, rien n'a changé")
	# Ctrl+X : dissoudre la face de bord et une voisine — pas de trou.
	var bouton: Button = null
	for b in ed.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Dissolve"):
			bouton = b
	_vrai(bouton != null, "le bouton « Dissolve » existe dans Geometry")
	m = mo.maillage
	var voisine := -1
	for f in m.faces.size():
		if f != f_bord and voisine < 0:
			var communs := 0
			for i in m.faces[f]:
				if Array(m.faces[f_bord]).has(i):
					communs += 1
			if communs >= 2:
				voisine = f
	mo.choisir_mode("face")
	mo.tout_choisir(false)
	mo.sel_f = {f_bord: true, voisine: true}
	ed._input(_cle(KEY_X, true))
	_vrai(mo.maillage.faces.size() < faces0 and mo.maillage.trous() == 0 and _sans_partenaire(t) == 0,
		"Ctrl+X dissout deux faces de bord : moins de faces (%d → %d), aucun trou, aucun joint ouvert"
		% [faces0, mo.maillage.faces.size()])
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_vrai(mo.maillage.sommets == depart and mo.maillage.faces.size() == faces0, "UN Ctrl+Z rend les faces dissoutes")
	print("  [bord gardé : %d vérifications de plus, section finie]" % 16)
	return true


## LA BANDE DU BAS (Jordan, 1er octobre 2026) : l'écran a un bord en bas, et les deux panneaux s'arrêtent AU-DESSUS
## d'elle — ce qui est coupé l'est par leur défilement, pas par l'écran. Mesuré sur les rectangles posés.
func _la_bande_du_bas(ed: Control) -> void:
	var bande: Control = null
	for n in ed.find_children("BandeDuBas", "Panel", true, false):
		bande = n
	_vrai(bande != null and bande.is_visible_in_tree() and bande.size.y >= 4 and bande.size.y <= 12,
		"une bande fine borde le bas de l'écran (%s)" % (str(bande.size.y) if bande != null else "absente"))
	if bande == null:
		return
	var bas := ed.get_global_rect().end.y
	_vrai(absf(bande.get_global_rect().end.y - bas) < 1.0, "elle touche le bas de la fenêtre")
	for p in [ed._gauche, ed._droite]:
		_vrai(p.get_global_rect().end.y <= bande.get_global_rect().position.y + 0.5,
			"le panneau %s s'arrête au-dessus d'elle" % p.name)


## LE MANUEL DIT COMMENT OBTENIR LE MÊME RENDU (Jordan, 1er octobre 2026) — chaque technique, avec la valeur que la
## vue emploie VRAIMENT : l'attendu est lu sur l'environnement et le soleil POSÉS dans la vue, pas sur les constantes
## que la page cite — une page qui recopierait ses valeurs, ou une vue qui n'emploierait plus les siennes, rougit.
func _le_manuel_dit_le_rendu(ed: Control) -> void:
	var page: RichTextLabel = null
	for d in ed._manuel.find_children("*", "ScrollContainer", true, false):
		if String(d.name).contains("same look"):
			for t in d.find_children("*", "RichTextLabel", true, false):
				page = t
	_vrai(page != null, "le manuel a une page « The same look in your engine »")
	if page == null:
		return
	var texte: String = page.get_parsed_text()
	var env: Environment = ed._vue._env
	var soleil: DirectionalLight3D = null
	for n in ed._vue._vue.get_children():
		if n is DirectionalLight3D:
			soleil = n
	var attendus := {
		"le soleil et son énergie": "energy %.2f" % soleil.light_energy,
		"ses ombres": "shadows on",
		"l'ambiante, sa couleur": "#" + env.ambient_light_color.to_html(false),
		"l'ambiante, son énergie": "energy %.2f" % env.ambient_light_energy,
		"le SSAO, son intensité": "intensity %.1f" % env.ssao_intensity,
		"le SSAO sur la lumière directe": "Light Affect » %.1f" % env.ssao_light_affect,
		"le SSIL": "SSIL",
		"les reflets": "#" + (env.sky.sky_material as ProceduralSkyMaterial).sky_horizon_color.to_html(false),
		"les normales par face": "one normal per face",
		"le MSAA": "MSAA 4×",
	}
	var manquent: Array = []
	for k in attendus:
		if not texte.contains(attendus[k]):
			manquent.append("%s (« %s »)" % [k, attendus[k]])
	_vrai(manquent.is_empty(), "la page dit chaque réglage tel que la vue l'emploie (manquent : %s)" % [manquent])


## WITNESS GEOMETRY ET WITNESS TEXTURING (Jordan, 1er octobre 2026) : le même témoin, deux mains. Les matériaux
## ne sont que dans Texturing, l'édition de maillage que dans Geometry ; dans Texturing une touche de géométrie
## ne touche à rien (et le dit), mais choisir et déplier marchent ; Tab et le mode de sélection se suivent.
func _les_deux_ateliers_du_temoin(ed: Control) -> void:
	var mo: Node3D = ed._modeleur
	ed._aller_a("witness")
	ed._regler_edition(true)
	var dans := func(panneau: Control, titre: String) -> bool:
		for sct in panneau.find_children("*", "", true, false):
			if sct.get("titre") is String and sct.titre == titre:
				return true
			if sct is Label and (sct as Label).text == titre:
				return true
		return false
	_vrai(ed._droite_temoin.visible and not ed._droite_texture.visible, "Geometry montre sa barre, pas celle du texturing")
	_vrai(not ed._liste_materiaux.is_visible_in_tree(), "les matériaux ne sont pas dans Witness geometry")
	ed._aller_a("texture")
	_vrai(ed._droite_texture.visible and not ed._droite_temoin.visible and ed._liste_materiaux.is_visible_in_tree(),
		"Texturing montre sa barre, et les matériaux y sont")
	_vrai(ed._vue.mode == "temoin" and ed._vue.edition, "le même témoin, toujours en édition")
	_vrai((ed._boutons_edition as Array).size() == 2 and ed._boutons_edition.all(func(b): return b.button_pressed),
		"les deux boutons d'édition se suivent")
	mo.choisir_mode("face")
	mo.tout_choisir(false)
	mo.sel_f = {0: true}
	var avant: PackedVector3Array = mo.maillage.sommets.duplicate()
	ed._input(_cle(KEY_G))
	_vrai(ed._rapport.text.contains("Witness geometry"), "dans Texturing, G dit où est la géométrie")
	for k in [KEY_Z, KEY_1, KEY_ENTER]:
		ed._input(_cle(k))
	_vrai(mo.maillage.sommets == avant and mo.modal == "", "et G Z 1 ne bouge rien")
	ed._input(_cle(KEY_2))
	_vrai(mo.mode_sel == "arete" and ed._boutons_selmode_tex["arete"].button_pressed and ed._boutons_selmode["arete"].button_pressed,
		"2 choisit les arêtes, dans les deux barres")
	ed._input(_cle(KEY_3))
	ed._aller_a("witness")
	mo.sel_f = {0: true}
	for k in [KEY_G, KEY_Z, KEY_1, KEY_ENTER]:
		ed._input(_cle(k))
	_vrai(mo.maillage.sommets != avant, "revenu dans Geometry, G Z 1 déplace la face")
	ed._unhandled_key_input(_cle(KEY_Z, true))


## LA PEINTURE (Jordan, 1er octobre 2026) — un vrai trait à la souris sur une copie de la paroi, dans Witness
## texturing : une face de la légende refuse (et le dit) ; une face à matériau reçoit une toile de sa couleur, le
## matériau passe au blanc ; le texel touché prend la couleur du pinceau ; UN Ctrl+Z le rend, Ctrl+Y le refait ;
## l'écriture met la toile sur le disque et dans le .glb ; Alt+clic lit la couleur ; Geometry éteint le pinceau.
func _peindre_le_temoin(ed: Control) -> void:
	const Peinture := preload("res://addons/marchingblocks_core/peinture.gd")
	var mo: Node3D = ed._modeleur
	ed._aller_a("texture")
	ed._regler_edition(true)
	var t: RefCounted = mo.temoin
	var cam: Camera3D = mo.camera
	# Un point VU d'une copie de la paroi : le centre d'une de ses faces que le rayon de l'écran retrouve.
	var paroi := "mb_plaque_b2h2_dehors"
	var vise := {}
	for i in t.occurrences_de(paroi):
		var pose: Transform3D = t.occurrences[i]["pose"]
		var tuile: RefCounted = t.tuiles[paroi]
		for f in tuile.faces.size():
			var c := Vector3.ZERO
			for k in tuile.faces[f]:
				c += tuile.sommets[k]
			c /= tuile.faces[f].size()
			var monde: Vector3 = pose * c
			if cam.is_position_behind(monde):
				continue
			var ecran: Vector2 = cam.unproject_position(monde)
			if not Rect2(Vector2(40, 40), ed._vue.size - Vector2(80, 80)).has_point(ecran):
				continue
			var hit: Dictionary = t.rayon(cam.project_ray_origin(ecran), cam.project_ray_normal(ecran))
			if not hit.is_empty() and int(hit["occurrence"]) == i and int(hit["face"]) == f:
				vise = {"occurrence": i, "face": f, "ecran": ecran, "local": c}
				break
		if not vise.is_empty():
			break
	_vrai(not vise.is_empty(), "une face de la paroi est visible à l'écran")
	if vise.is_empty():
		return
	var tuile: RefCounted = t.tuiles[paroi]
	var clic := func(pos: Vector2, appui: bool, alt := false) -> void:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = appui
		b.alt_pressed = alt
		b.position = pos
		mo.souris_entree(b)
	ed._bouton_pinceau.button_pressed = true
	_vrai(mo.pinceau and ed._vue.edition, "P allume le pinceau, en édition")
	# Une face de la légende ne se peint pas.
	var mats_avant: int = t.materiaux.size()
	if tuile.mat(int(vise["face"])) < 0:
		clic.call(vise["ecran"], true)
		clic.call(vise["ecran"], false)
		_vrai(ed._rapport.text.contains("legend colour") and t.materiaux.size() == mats_avant,
			"une face de la légende refuse le pinceau, et le dit")
	# Un matériau pour toute la paroi.
	mo.activer(int(vise["occurrence"]))
	ed._bouton_pinceau.button_pressed = false
	mo.choisir_mode("face")
	mo.tout_choisir(true)
	var k: int = mo.nouveau_materiau()
	mo.assigner_courant()
	var couleur_du_materiau: Color = t.materiaux[k]["couleur"]
	ed._bouton_pinceau.button_pressed = true
	ed._couleur_pinceau.color = Color(0.9, 0.1, 0.1)
	ed._couleur_pinceau.color_changed.emit(Color(0.9, 0.1, 0.1))
	clic.call(vise["ecran"], true)
	var m := InputEventMouseMotion.new()
	m.position = vise["ecran"] + Vector2(6, 0)
	m.button_mask = MOUSE_BUTTON_MASK_LEFT
	mo.souris_entree(m)
	clic.call(vise["ecran"] + Vector2(6, 0), false)
	var chemin: String = str(t.materiaux[k].get("texture", ""))
	_vrai(chemin != "" and FileAccess.file_exists(chemin) and t.materiaux[k]["couleur"] == Color.WHITE,
		"le matériau reçoit une toile, et passe au blanc (%s)" % chemin.get_file())
	var img: Image = Peinture.toile(chemin).get("image", null) if chemin != "" else null
	if img == null:
		_vrai(false, "la toile se lit")
		return
	var uv: Vector2 = tuile.uv_au_point(int(vise["face"]), vise["local"])
	var px: Vector2 = Peinture.vers_pixel(img, uv)
	var lu := func() -> Color: return img.get_pixel(int(px.x), int(px.y))
	_vrai(_proche(lu.call(), Color(0.9, 0.1, 0.1)), "le texel sous la souris a la couleur du pinceau (%s)" % lu.call())
	var toile_avant := couleur_du_materiau
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_vrai(absf((lu.call() as Color).r - toile_avant.r) < 0.02 and absf((lu.call() as Color).g - toile_avant.g) < 0.02,
		"UN Ctrl+Z rend le texel à la couleur de la toile (%s)" % lu.call())
	ed._unhandled_key_input(_cle(KEY_Y, true))
	_vrai(_proche(lu.call(), Color(0.9, 0.1, 0.1)), "Ctrl+Y refait le trait")
	ed._enregistrer_le_temoin_modele(true)
	var relue := Image.load_from_file(chemin)
	relue.convert(Image.FORMAT_RGBA8)
	_vrai(_proche(relue.get_pixel(int(px.x), int(px.y)), Color(0.9, 0.1, 0.1)), "la toile peinte est écrite sur le disque")
	var c: Dictionary = ed._couches[ed._active]
	var f := FileAccess.open(ed._glb_du_temoin(c), FileAccess.READ)
	f.seek(12)
	var longueur := f.get_32()
	f.get_32()
	var json: Dictionary = JSON.parse_string(f.get_buffer(longueur).get_string_from_utf8())
	_vrai((json.get("images", []) as Array).size() >= 1, "et elle part dans le .glb du témoin (le monde la portera)")
	ed._couleur_pinceau.color = Color.BLACK
	clic.call(vise["ecran"], true, true)
	clic.call(vise["ecran"], false, true)
	_vrai(_proche(ed._couleur_pinceau.color, Color(0.9, 0.1, 0.1)), "Alt+clic : la pipette lit la couleur peinte")
	# LES CALQUES ET LA GOMME (Jordan, 2 octobre 2026) — par les vrais boutons et la vraie touche. Attendus : la couleur
	# de la toile (celle du matériau à la création), le rouge peint ; jamais lus dans la fonction éprouvée.
	mo.materiau_courant = k
	ed._redire_les_materiaux()
	var module_peinture: GDScript = Peinture   # une fonction anonyme ne voit pas une constante locale
	var pile := func() -> Array: return module_peinture.toile(chemin)["calques"]
	_vrai((pile.call() as Array).size() == 1 and ed._liste_calques.get_child_count() == 1 and ed._reglages_calque.visible,
		"la section Paint montre la pile de la toile du matériau : un calque")
	ed._boutons_calques["New"].pressed.emit()
	_vrai((pile.call() as Array).size() == 2 and int(Peinture.toile(chemin)["actif"]) == 1
		and ed._liste_calques.get_child_count() == 2, "New : un second calque, actif, dans la liste")
	ed._couleur_pinceau.color = Color(0.1, 0.2, 0.9)
	ed._couleur_pinceau.color_changed.emit(Color(0.1, 0.2, 0.9))
	clic.call(vise["ecran"], true)
	clic.call(vise["ecran"], false)
	var haut: Image = (pile.call() as Array)[1]["image"]
	var hpx := haut.get_pixel(int(px.x), int(px.y))
	_vrai(_proche(lu.call(), Color(0.1, 0.2, 0.9)) and hpx.a > 0.99,
		"le trait va dans le calque ACTIF (le haut) et la toile le montre (%s)" % lu.call())
	_vrai(_proche((pile.call() as Array)[0]["image"].get_pixel(int(px.x), int(px.y)), Color(0.9, 0.1, 0.1)),
		"le calque du bas garde le rouge d'avant")
	mo.touche(_cle(KEY_E))
	_vrai(mo.gomme and ed._bouton_gomme.button_pressed, "E bascule la gomme, et le bouton le montre")
	clic.call(vise["ecran"], true)
	clic.call(vise["ecran"], false)
	_vrai(haut.get_pixel(int(px.x), int(px.y)).a < 0.01 and _proche(lu.call(), Color(0.9, 0.1, 0.1)),
		"la gomme rend le haut transparent : le rouge du bas revient (%s)" % lu.call())
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_vrai(_proche(lu.call(), Color(0.1, 0.2, 0.9)), "UN Ctrl+Z défait le coup de gomme")
	mo.touche(_cle(KEY_E))
	_vrai(not mo.gomme and not ed._bouton_gomme.button_pressed, "E revient au pinceau")
	ed._liste_calques.get_child(1).get_child(0).pressed.emit()
	_vrai(not bool((pile.call() as Array)[0]["visible"]) and _proche(lu.call(), Color(0.1, 0.2, 0.9)),
		"l'œil du bas (dernier de la liste, qui va du haut vers le bas) le cache")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_vrai(bool((pile.call() as Array)[0]["visible"]) and ed._liste_calques.get_child_count() == 2,
		"Ctrl+Z le remontre, et la liste suit")
	ed._boutons_calques["Delete"].pressed.emit()
	_vrai((pile.call() as Array).size() == 1 and _proche(lu.call(), Color(0.9, 0.1, 0.1)), "Delete : le haut s'en va, le rouge revient")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_vrai((pile.call() as Array).size() == 2 and is_same((pile.call() as Array)[1]["image"], haut)
		and _proche(lu.call(), Color(0.1, 0.2, 0.9)), "Ctrl+Z rend le MÊME calque, et son bleu")
	# MERGE DOWN (3 octobre 2026), par le vrai bouton : l'image ne change pas, un calque de moins ; UN Ctrl+Z.
	_vrai(not ed._boutons_calques["Merge down"].disabled, "Merge down : possible sur le calque du haut")
	ed._boutons_calques["Merge down"].pressed.emit()
	_vrai((pile.call() as Array).size() == 1 and _proche(lu.call(), Color(0.1, 0.2, 0.9))
		and _proche((pile.call() as Array)[0]["image"].get_pixel(int(px.x), int(px.y)), Color(0.1, 0.2, 0.9)),
		"Merge down : un seul calque, qui porte le bleu ; l'image ne change pas")
	_vrai(ed._boutons_calques["Merge down"].disabled, "… et plus rien à fusionner sous le dernier")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_vrai((pile.call() as Array).size() == 2 and is_same((pile.call() as Array)[1]["image"], haut),
		"Ctrl+Z défait la fusion : les deux calques reviennent")
	ed._enregistrer_le_temoin_modele(true)
	_vrai(FileAccess.file_exists(Peinture.dossier_des_calques(chemin).path_join("layers.json")),
		"la pile s'écrit à côté de la toile, avec le témoin")
	# LE CURSEUR (Jordan, 1er octobre 2026) : survoler la paroi montre l'empreinte du tampon, dans le plan de la face.
	# Attendu d'ailleurs : en Boîte l'UV est la position divisée par la répétition, donc un CERCLE de
	# taille / largeur de la toile × répétition.
	var survol := InputEventMouseMotion.new()
	survol.position = vise["ecran"]
	mo.souris_entree(survol)
	var emp: PackedVector3Array = mo.empreinte_montree
	var n_f: Vector3 = tuile.normale(int(vise["face"]))
	var rayon_attendu: float = mo.pinceau_taille / float(img.get_width()) * float(t.materiaux[k].get("echelle", 1.0))
	var ecart_max := 0.0
	for q in emp:
		ecart_max = maxf(ecart_max, maxf(absf(n_f.dot(q - vise["local"])),
			absf(q.distance_to(vise["local"]) - rayon_attendu)))
	_vrai(str(t.materiaux[k].get("projection", "boite")) == "boite" and emp.size() > 0 and ecart_max < 1e-3,
		"survoler montre l'empreinte du pinceau : un cercle de %.4f case dans le plan de la face (écart %.5f)"
		% [rayon_attendu, ecart_max])
	# LES BANDES DE COUTURE : pendant qu'on peint, sur l'édition ET sur chaque MultiMesh des occurrences.
	var calque: Material = mo.calque_des_bandes()
	var portent := 0
	var instances: Array = mo.instances_des_bandes()
	for gi in instances:
		portent += int(is_same((gi as GeometryInstance3D).material_overlay, calque))
	_vrai(calque != null and instances.size() == 2 + t.tuiles.size() and portent == instances.size(),
		"en peignant, les bandes de couture couvrent l'édition et les %d tuiles (%d / %d)" % [t.tuiles.size(), portent,
		instances.size()])
	ed._case_bandes.button_pressed = false
	var eteintes := 0
	for gi in instances:
		eteintes += int((gi as GeometryInstance3D).material_overlay == null)
	_vrai(eteintes == instances.size(), "« Seam bands » décoché : plus aucune bande (%d / %d)" % [eteintes, instances.size()])
	ed._case_bandes.button_pressed = true
	_vrai(mo.calque_des_bandes() != null, "recoché, elles reviennent")
	# L'ATLAS : le bouton déplie les faces du matériau dans TOUTES les tuiles, le matériau passe en UV ; UN Ctrl+Z.
	mo.materiau_courant = k
	var porteuses: Array = []
	for cl in t.tuiles:
		if (t.tuiles[cl].mats as Array).has(k):
			porteuses.append(cl)
	var uvs_avant := {}
	for cl in porteuses:
		uvs_avant[cl] = (t.tuiles[cl].uvs as Array).duplicate(true)
	mo.deplier_en_atlas()
	var depliees := 0
	for cl in porteuses:
		var m_t: RefCounted = t.tuiles[cl]
		var toutes := true
		for fc in m_t.faces.size():
			if m_t.mat(fc) == k and m_t.uv(fc).is_empty():
				toutes = false
		depliees += int(toutes)
	_vrai(depliees == porteuses.size() and str(t.materiaux[k].get("projection", "")) == "uv",
		"« Unwrap all tiles (atlas) » déplie le matériau dans ses %d tuile(s), et le passe en UV" % porteuses.size())
	ed._unhandled_key_input(_cle(KEY_Z, true))
	var rendues := 0
	for cl in porteuses:
		rendues += int((t.tuiles[cl].uvs as Array) == uvs_avant[cl])
	_vrai(rendues == porteuses.size() and str(t.materiaux[k].get("projection", "boite")) != "uv",
		"UN Ctrl+Z rend les UV et la projection d'avant (%d / %d)" % [rendues, porteuses.size()])
	_sentinelle_pbr = false
	_les_cartes_pbr(ed, mo, t, k, chemin)
	_vrai(_sentinelle_pbr, "SENTINELLE : la section des cartes PBR est allée jusqu'au bout")
	ed._aller_a("witness")
	_vrai(not mo.pinceau, "Geometry éteint le pinceau")
	var restees := 0
	for gi in mo.instances_des_bandes():
		restees += int((gi as GeometryInstance3D).material_overlay != null)
	_vrai(restees == 0 and mo.empreinte_montree.is_empty(), "et avec lui les bandes et le curseur (%d bandes restées)" % restees)


## LES CARTES PBR (Jordan, 2 octobre 2026) — par les vrais contrôles de la section « PBR maps » : la case les allume
## (le matériau lit les textures des cartes), un curseur les rend périmées, chaque retouche est UNE annulation ; la
## cuisson du relief refuse la boîte et le dit, puis, l'atlas fait, remplace le FOND de la toile — un Ctrl+Z ; et les
## cartes partent dans le .glb du témoin. Attendus : les défauts écrits dans `cartes_pbr.gd` (recopiés ici), le fond
## d'avant relu octet par octet, le JSON du fichier.
var _sentinelle_pbr := false



## L'ATELIER ANIMATION (Jordan, 6 octobre 2026) — par les vrais boutons : rien tant qu'on n'ajoute pas ; « + » ajoute
## des images neuves (copiées dans le projet) et un défilement ; « − » retire ; un Ctrl+Z par geste ; la paroi montrée
## porte l'animé ; on peint UNE image (Frame ▶) ; le monde le reçoit animé. Attendus : les fichiers sur le disque, le
## dictionnaire du matériau, les pixels des toiles — jamais lus dans `app/animation.gd`.
var _animation_finie := false


func _l_atelier_animation(ed: Control) -> void:
	const Anim := preload("res://addons/marchingblocks_core/animation_materiau.gd")
	const Peinture := preload("res://addons/marchingblocks_core/peinture.gd")
	var mo: Node3D = ed._modeleur
	var an: RefCounted = ed._animation
	ed._aller_a("anim")
	_vrai(ed._droite_animation.visible and not ed._droite_texture.visible and ed._vue.edition and not mo.geometrie,
		"Animation : sa barre de droite, le témoin en édition, sans outils de géométrie")
	var t: RefCounted = mo.temoin
	# Le matériau que portent les faces de la paroi (peinte par la section d'avant).
	var paroi := "mb_plaque_b2h2_dehors"
	var k := -1
	for f in t.tuiles[paroi].faces.size():
		var m: int = t.tuiles[paroi].mat(f)
		if m >= 0 and m < t.materiaux.size() and str(t.materiaux[m].get("texture", "")) != "":
			k = m
	_vrai(k >= 0, "un matériau peint existe (celui de la paroi)")
	if k < 0:
		return
	mo.materiau_courant = k
	an.redire()
	_vrai(an._corps.visible and an._pistes.get_child_count() == 1 and (an._pistes.get_child(0) as Label).text.begins_with("No track"),
		"le matériau choisi : aucune piste, et la barre le dit")
	var bouton := func(parent: Node, texte: String) -> Button:
		for b in parent.find_children("*", "Button", true, false):
			if (b as Button).text == texte:
				return b
		return null
	var choisir := func(source: Array) -> void:
		for i in an._source.item_count:
			if an._source.get_item_metadata(i) == source:
				an._source.select(i)
		an._redire_les_reglages_source()
	an._canal.select(0)
	an._redire_les_sources()
	choisir.call(["images", "vierges"])
	_vrai(an._nombre.visible and not an._colonnes.visible, "« Blank frames » : seul le nombre se règle")
	an._nombre.value = 3
	(bouton.call(ed._droite_animation, "Add track") as Button).pressed.emit()
	var images: Array = Anim.images_de(t.materiaux[k].get("animation"), "albedo")
	var ecrites := images.size() == 3
	for c in images:
		ecrites = ecrites and FileAccess.file_exists(c) and (c as String).contains("_images/animation")
	_vrai(ecrites, "« + » : trois images, écrites dans le dossier d'images du projet (%s)"
		% (images[0] if not images.is_empty() else "—"))
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_vrai(t.materiaux[k].get("animation") == null, "UN Ctrl+Z retire la piste")
	ed._unhandled_key_input(_cle(KEY_Y, true))
	_vrai(Anim.images_de(t.materiaux[k].get("animation"), "albedo") == images, "Ctrl+Y la remet")
	an._canal.select(0)
	an._redire_les_sources()
	var offertes: Array = []
	for i in an._source.item_count:
		offertes.append(an._source.get_item_metadata(i))
	_vrai(offertes == [["defilement", ""]], "la couleur de base a ses images : on ne propose plus que le défilement (%s)" % [offertes])
	choisir.call(["defilement", ""])
	(bouton.call(ed._droite_animation, "Add track") as Button).pressed.emit()
	_vrai(Anim.pistes(t.materiaux[k]["animation"]) == [["albedo", "defilement"], ["albedo", "images"]]
		and an._pistes.get_child_count() == 2, "un défilement de plus : deux cartes")
	var surf: Material = null
	var mesh: Mesh = (mo._mm_de[paroi] as MultiMeshInstance3D).multimesh.mesh if mo._mm_de.has(paroi) else mo._faces_mi.mesh
	for s in mesh.get_surface_count():
		if mesh.surface_get_material(s) is ShaderMaterial:
			surf = mesh.surface_get_material(s)
	_vrai(surf != null and surf.has_meta("repli"), "la paroi montrée porte le matériau ANIMÉ")
	var moins: Array = []
	for b in an._pistes.get_child(0).find_children("*", "Button", true, false):
		if (b as Button).tooltip_text.begins_with("Remove this track"):
			moins.append(b)
	(moins[0] as Button).pressed.emit()
	_vrai(Anim.pistes(t.materiaux[k]["animation"]) == [["albedo", "images"]], "« − » retire le défilement")
	an._basculer_lecture()
	_vrai(Anim.en_pause and an._bouton_lecture.text == "Play", "Pause met tout en pause")
	an._basculer_lecture()
	# PEINDRE L'IMAGE 3 : Texturing, Frame ▶ ▶, un trait — l'image 3 change, l'image 1 non.
	ed._aller_a("texture")
	ed._bouton_pinceau.button_pressed = true
	an.redire_la_peinture()
	_vrai(an._rangee_peinture.visible and an._image_peinte.text == "1 / 3", "Paint montre la rangée Frame : 1 / 3")
	an.changer_d_image(1)
	an.changer_d_image(1)
	_vrai(mo.image_peinte == 2 and ed._chemin_toile_courante() == images[2], "▶ ▶ : on peint l'image 3")
	an.suivre(0.016)
	_vrai(Anim.fige and Anim.image_forcee == 2, "l'écran montre l'image peinte, le temps figé")
	var cam: Camera3D = mo.camera
	var vise := {}
	for i in t.occurrences_de(paroi):
		var pose: Transform3D = t.occurrences[i]["pose"]
		var tuile: RefCounted = t.tuiles[paroi]
		for f in tuile.faces.size():
			if tuile.mat(f) != k:
				continue
			var c := Vector3.ZERO
			for j in tuile.faces[f]:
				c += tuile.sommets[j]
			c /= tuile.faces[f].size()
			var monde: Vector3 = pose * c
			if cam.is_position_behind(monde):
				continue
			var ecran: Vector2 = cam.unproject_position(monde)
			if not Rect2(Vector2(40, 40), ed._vue.size - Vector2(80, 80)).has_point(ecran):
				continue
			var hit: Dictionary = t.rayon(cam.project_ray_origin(ecran), cam.project_ray_normal(ecran))
			if not hit.is_empty() and int(hit["occurrence"]) == i and int(hit["face"]) == f:
				vise = {"face": f, "ecran": ecran, "local": c}
				break
		if not vise.is_empty():
			break
	_vrai(not vise.is_empty(), "une face animée de la paroi est visible")
	if not vise.is_empty():
		var tuile: RefCounted = t.tuiles[paroi]
		var px: Vector2 = Peinture.vers_pixel(Peinture.toile(images[2])["image"], tuile.uv_au_point(int(vise["face"]), vise["local"]))
		var avant0: Color = Peinture.toile(images[0])["image"].get_pixel(int(px.x), int(px.y))
		ed._couleur_pinceau.color = Color(0.1, 0.9, 0.2)
		ed._couleur_pinceau.color_changed.emit(Color(0.1, 0.9, 0.2))
		for appui in [true, false]:
			var b := InputEventMouseButton.new()
			b.button_index = MOUSE_BUTTON_LEFT
			b.pressed = appui
			b.position = vise["ecran"]
			mo.souris_entree(b)
		var module_peinture: GDScript = Peinture
		var lu := func(r: int) -> Color: return module_peinture.toile(images[r])["image"].get_pixel(int(px.x), int(px.y))
		_vrai(_proche(lu.call(2), Color(0.1, 0.9, 0.2)), "le trait peint l'image 3 (%s)" % lu.call(2))
		_vrai(lu.call(0) == avant0, "… et pas l'image 1")
		ed._unhandled_key_input(_cle(KEY_Z, true))
		_vrai(not _proche(lu.call(2), Color(0.1, 0.9, 0.2)), "UN Ctrl+Z défait le trait dans l'image 3")
		ed._unhandled_key_input(_cle(KEY_Y, true))
	ed._bouton_pinceau.button_pressed = false
	an.suivre(0.016)
	_vrai(not Anim.fige and Anim.image_forcee == -1, "pinceau éteint : les images rejouent")
	# LE MONDE : en y allant, il suit son témoin — ses tuiles portent le matériau animé.
	ed._aller_a("monde")
	var lot: MeshLibrary = ed._vue.couche(ed._active).lot
	var animees := 0
	if lot != null:
		for id in lot.get_item_list():
			var m: Mesh = lot.get_item_mesh(id)
			for s in m.get_surface_count():
				var mt: Material = m.surface_get_material(s)
				if mt is ShaderMaterial and mt.has_meta("repli") \
						and Anim.images_de(mt.get_meta("animation"), "albedo").size() == 3:
					animees += 1
	_vrai(animees >= 1, "le monde porte le matériau animé (%d surface(s))" % animees)
	# Rien ne reste : on retire la piste (un geste), pour les sections qui suivent.
	ed._aller_a("anim")
	mo.materiau_courant = k
	an.poser({})
	_vrai(t.materiaux[k].get("animation") == null, "tout retiré : le matériau est de nouveau immobile")
	_animation_finie = true


func _les_cartes_pbr(ed: Node, mo: Node, t: RefCounted, k: int, chemin: String) -> void:
	const Peinture := preload("res://addons/marchingblocks_core/peinture.gd")
	mo.materiau_courant = k
	ed._redire_les_materiaux()
	_vrai(ed._section_pbr.visible and not ed._case_pbr.button_pressed and not ed._reglages_pbr.visible,
		"la section PBR maps montre le matériau courant : cartes éteintes")
	ed._case_pbr.button_pressed = true
	ed._inscrire_les_retouches()
	# ⚠ LECTURES PRUDENTES (`pbr`) : une mutation qui laisse le réglage absent ne doit pas faire lever une erreur
	# d'exécution — elle abandonnerait la fonction EN SILENCE (charte §6) ; la sentinelle ci-dessous le verrait.
	var pbr := func() -> Dictionary:
		var v: Variant = t.materiaux[k].get("pbr")
		return v if v is Dictionary else {}
	_vrai(float(pbr.call().get("normale", 0)) == 4.0 and float(pbr.call().get("fin", 0)) == 1.0
		and ed._reglages_pbr.visible, "la case les allume, aux réglages par défaut (normale 4, fin 1)")
	var tuile: RefCounted = t.tuiles[mo.cle]
	var sm: StandardMaterial3D = tuile.materiau_godot(k)
	var e: Dictionary = Peinture.cartes_de(chemin, pbr.call(), true)
	_vrai(sm.normal_enabled and is_same(sm.normal_texture, e.get("normale")) and is_same(sm.ao_texture, e.get("orm")),
		"le matériau lit la normale et l'ORM des cartes")
	Peinture.suivre_les_cartes(true)
	var penche := 0
	var nimg: Image = e.get("images", {}).get("normale", Image.create(4, 4, false, Image.FORMAT_RGB8))
	for y in range(0, nimg.get_height(), 4):
		for x in range(0, nimg.get_width(), 4):
			if absi(nimg.get_pixel(x, y).r8 - 128) > 6:
				penche += 1
	_vrai(Peinture.cartes_en_retard() == 0 and penche > 0, "générées depuis la toile peinte : %d texel(s) penchent" % penche)
	ed._curseurs_pbr["normale"].value = 9.0
	ed._inscrire_les_retouches()
	_vrai(float(pbr.call().get("normale", 0)) == 9.0 and Peinture.cartes_en_retard() == 1,
		"le curseur Normal change le réglage, et les cartes sont à refaire")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_vrai(float(pbr.call().get("normale", 0)) == 4.0 and is_equal_approx(ed._curseurs_pbr["normale"].value, 4.0),
		"UN Ctrl+Z rend le réglage d'avant, et le curseur le montre")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_vrai(not t.materiaux[k].get("pbr") is Dictionary and not ed._case_pbr.button_pressed
		and not tuile.materiau_godot(k).normal_enabled, "un second Ctrl+Z les éteint")
	ed._unhandled_key_input(_cle(KEY_Y, true))
	_vrai(t.materiaux[k].get("pbr") is Dictionary, "Ctrl+Y les rallume")
	# La couleur de base cuite depuis le relief : refusée en boîte, et dite.
	var fond_avant: PackedByteArray = Peinture.fond(chemin).get_data().duplicate()
	ed._bouton_cuire.pressed.emit()
	_vrai(ed._rapport.text.contains("needs the UV projection") and Peinture.fond(chemin).get_data() == fond_avant,
		"en boîte, la cuisson refuse et le dit — le fond est intact")
	mo.deplier_en_atlas()
	var compo_avant: PackedByteArray = (Peinture.toile(chemin)["image"] as Image).get_data().duplicate()
	ed._bouton_cuire.pressed.emit()
	var fond_apres: PackedByteArray = Peinture.fond(chemin).get_data()
	_vrai(ed._rapport.text.contains("Base colour baked") and fond_apres != fond_avant,
		"l'atlas fait, « Bake base colour » remplace le fond de la toile")
	# ⚠ CE QU'ON VOIT, PAS SEULEMENT LE FOND (3 octobre 2026 : « bake color base ne fait rien ») : le fond changeait
	# sous un calque Base opaque, et l'image affichée restait la même — la garde ne lisait que le fond.
	var compo_apres: PackedByteArray = (Peinture.toile(chemin)["image"] as Image).get_data()
	var changes := 0
	for i in range(0, compo_apres.size(), 4096):
		changes += int(compo_apres[i] != compo_avant[i])
	_vrai(changes > 0, "… et l'IMAGE AFFICHÉE change (%d échantillons sur %d)" % [changes, compo_apres.size() / 4096])
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_vrai(Peinture.fond(chemin).get_data() == fond_avant
		and (Peinture.toile(chemin)["image"] as Image).get_data() == compo_avant, "UN Ctrl+Z rend le fond et l'image d'avant, octet pour octet")
	ed._unhandled_key_input(_cle(KEY_Y, true))
	_vrai(Peinture.fond(chemin).get_data() == fond_apres, "Ctrl+Y le recuit")
	# Écrites avec le témoin, et dans son .glb.
	ed._enregistrer_le_temoin_modele(true)
	var dossier: String = Peinture.dossier_des_cartes(chemin, false)
	_vrai(FileAccess.file_exists(dossier.path_join("normal.png")) and FileAccess.file_exists(dossier.path_join("orm.png")),
		"les cartes s'écrivent à côté de la toile (%s)" % dossier.get_file())
	var f := FileAccess.open(ed._glb_du_temoin(ed._couches[ed._active]), FileAccess.READ)
	f.seek(12)
	var longueur := f.get_32()
	f.get_32()
	var json: Dictionary = JSON.parse_string(f.get_buffer(longueur).get_string_from_utf8())
	var porte := false
	for mat in json.get("materials", []):
		if str(mat.get("name", "")) == str(t.materiaux[k]["nom"]) and (mat as Dictionary).has("normalTexture"):
			porte = true
	_vrai(porte, "le .glb du témoin porte la carte de normales du matériau")
	# On rend l'état d'avant au reste de la fumée : l'atlas défait, les cartes éteintes.
	ed._unhandled_key_input(_cle(KEY_Z, true))
	ed._unhandled_key_input(_cle(KEY_Z, true))
	ed._case_pbr.button_pressed = false
	ed._inscrire_les_retouches()
	# L'ÉMISSION (Jordan, 6 octobre 2026) : une image dont l'ensemble porte une carte « _emission » montre le curseur
	# « Emission » ; il règle la force du matériau (UNE annulation), et le matériau luit de la carte à cette force.
	# Attendus écrits ici (5 ; 1 par défaut). Un matériau à part, qu'aucune face ne porte.
	var dossier_em := ProjectSettings.globalize_path("user://fumee_emission")
	DirAccess.make_dir_recursive_absolute(dossier_em)
	var img_em := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img_em.fill(Color8(30, 30, 30))
	img_em.save_png(dossier_em.path_join("lampe_color.png"))
	img_em.fill(Color8(255, 200, 0))
	img_em.save_png(dossier_em.path_join("lampe_emission.png"))
	Peinture.oublier_les_ensembles()
	t.materiaux.append({"nom": "fumee_lampe", "couleur": Color.WHITE, "rugosite": 0.8, "metal": 0.0,
		"texture": dossier_em.path_join("lampe_color.png"), "echelle": 1.0, "projection": "boite"})
	var km: int = t.materiaux.size() - 1
	_vrai(ed._ligne_emission != null and not ed._ligne_emission.visible, "sans carte d'émission, pas de curseur Emission")
	mo.materiau_courant = km
	ed._redire_les_materiaux()
	_vrai(ed._ligne_emission.visible and is_equal_approx(ed._force_emission.value, 1.0),
		"une carte « _emission » à côté de l'image montre le curseur Emission, à 1")
	ed._force_emission.value = 5.0
	ed._inscrire_les_retouches()
	var lum: StandardMaterial3D = tuile.materiau_godot(km)
	_vrai(is_equal_approx(float(t.materiaux[km].get("emission", 0)), 5.0) and lum.emission_enabled
		and lum.emission_texture != null and is_equal_approx(lum.emission_energy_multiplier, 5.0),
		"le curseur règle la force (5) : le matériau luit de sa carte")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_vrai(not t.materiaux[km].has("emission") and is_equal_approx(ed._force_emission.value, 1.0),
		"UN Ctrl+Z rend la force d'avant, et le curseur le montre")
	mo.materiau_courant = k
	ed._redire_les_materiaux()
	_sentinelle_pbr = true


## Deux couleurs égales à la quantification d'une image 8 bits près.
func _proche(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


func _sans_partenaire(t: RefCounted) -> int:
	var occ := {}
	for o in t.occurrences:
		occ[o["sommet"]] = o
	var n := 0
	for s in occ:
		var oa: Dictionary = occ[s]
		for axe in 3:
			for sens in [-1, 1]:
				var e := Vector3i.ZERO
				e[axe] = sens
				if not occ.has(s + e):
					continue
				var ob: Dictionary = occ[s + e]
				var tb: RefCounted = t.tuiles[ob["cle"]]
				var index_b := {}
				for j in tb.sommets.size():
					index_b[Vector3i(((ob["pose"] as Transform3D) * tb.sommets[j] * 10000.0).round())] = true
				var ta: RefCounted = t.tuiles[oa["cle"]]
				var plan: float = float(s[axe]) + 1.0 + 0.5 * sens
				for i in ta.sommets.size():
					var pw: Vector3 = (oa["pose"] as Transform3D) * ta.sommets[i]
					if absf(pw[axe] - plan) <= 0.0005 and not index_b.has(Vector3i((pw * 10000.0).round())):
						n += 1
	return n


func _joints_ouverts(t: RefCounted, paires: Array) -> int:
	var n := 0
	for p in paires:
		var a: Vector3 = (p[2] as Transform3D) * (t.tuiles[p[0]].sommets[p[1]] as Vector3)
		var b: Vector3 = (p[5] as Transform3D) * (t.tuiles[p[3]].sommets[p[4]] as Vector3)
		if a.distance_to(b) > 1e-4:
			n += 1
	return n


## LE PLAY TEST, mené par de VRAIES touches (`Input.parse_input_event`) : le personnage tombe sur un
## sol peint, s'y pose, avance, saute, et la sortie rend tout. ⚠ Le headless ne dit pas s'il est beau.
func _play_test(ed: Control) -> void:
	var sol := {}
	for x in range(20, 29):
		for z in range(20, 29):
			sol[Vector3i(x, 10, z)] = true
	# UN ÎLOT LOIN DU DÉPART (100..102, 100..102) : son morceau du décor ne doit pas être bâti à l'entrée.
	var ilot := {}
	for x in range(100, 103):
		for z in range(100, 103):
			ilot[Vector3i(x, 10, z)] = true
	sol.merge(ilot)
	ed._coup_commence()
	ed._touche({"poser": sol, "effacer": {}}, "Add")
	ed._coup_fini()
	# ⚠ LE TÉMOIN, PAS LE REPLI : sur le repli procédural, la surface rendue COÏNCIDE avec les boîtes
	# de collision des cases (mesuré : 11,00 dans les deux cas), donc marcher sur les cases au lieu des
	# tuiles restait MUET. L'aminci rentre d'un quart de case : là, les deux se séparent.
	# ⚠ Le lot se pose SANS `_trancher_temoin` : son panneau d'attente guette `frame_post_draw`, qui
	# ne vient jamais en headless — la fumée pendait sans un mot.
	ed._vue.monde().lot = BM.librairie(BM.RETRAIT_AMINCI)["lot"]
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
	var marche := Vector2(p.velocity.x, p.velocity.z).length()
	_touche_physique(KEY_W, false)
	var pas := Vector2(p.global_position.x - depart.x, p.global_position.z - depart.z).length()
	_vrai(pas > 0.8, "W (Z en AZERTY) le fait avancer (%.2f case)" % pas)
	# LA TAILLE (Jordan, 6 octobre 2026) : ×0,65 par défaut ; il marche à 3,2 × 0,65 = 2,08 cases/s (écrit à la main).
	_vrai(is_equal_approx(p.taille, 0.65) and is_equal_approx(ed._taille_personnage.value, 0.65),
		"le personnage est à ×0,65 par défaut, et le curseur le dit")
	_vrai(marche > 1.9 and marche < 2.1, "à ×0,65, il marche à 2,08 cases/s (%.2f)" % marche)
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
	# LE DÉCOR EN MORCEAUX (4 octobre 2026 : une seule forme de 7,9 millions de triangles coûtait ~22 s à chaque
	# entrée sur l'exemple). Le morceau de l'îlot lointain n'a pas été bâti à l'entrée ; le personnage y est porté, et
	# il s'y pose sur la surface rendue — son morceau a été bâti au fil du jeu.
	var morceau_ilot := Vector2i(floori(100.0 / ed._vue.MORCEAU_DECOR), floori(100.0 / ed._vue.MORCEAU_DECOR))
	_vrai(ed._vue._morceaux_a_batir.has(morceau_ilot) and not ed._vue._morceaux_batis.has(morceau_ilot),
		"décor : le morceau de l'îlot lointain n'est pas bâti à l'entrée")
	var retour: Vector3 = p.global_position
	p.global_position = Vector3(101.5, 12.0, 101.5)
	p.velocity = Vector3.ZERO
	for i in 90:
		await physics_frame
	_vrai(ed._vue._morceaux_batis.has(morceau_ilot) and p.is_on_floor() and p.global_position.y > 10.5
		and p.global_position.y < 10.9, "… porté sur l'îlot, il s'y pose : son morceau a été bâti (y = %.2f)"
		% p.global_position.y)
	p.global_position = retour
	p.velocity = Vector3.ZERO
	for i in 30:
		await physics_frame
	await _le_vol(ed, p)
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
	_vrai(ed._vue.rayon_du_bras() < p.rayon(), "la sphère du bras (%.3f) est plus fine que la capsule (%.3f)"
		% [ed._vue.rayon_du_bras(), p.rayon()])
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
	# LE CURSEUR DE TAILLE, par le vrai contrôle : à ×1, la capsule fait 0,84 de haut et 0,19 de rayon, le modèle
	# 0,62 (attendus écrits à la main), la caméra recule d'autant ; la sphère du bras reste plus fine que la capsule,
	# le plan proche sous elle. Puis ×0,4, le plus petit.
	var capsule: CapsuleShape3D = null
	for c in p.get_children():
		if c is CollisionShape3D:
			capsule = (c as CollisionShape3D).shape as CapsuleShape3D
	var d065: float = ed._vue._distance
	ed._taille_personnage.value = 1.0
	_vrai(is_equal_approx(p.taille, 1.0) and is_equal_approx(capsule.height, 0.84) and is_equal_approx(capsule.radius, 0.19)
		and is_equal_approx(p._modele.scale.y, 0.62), "Character size ×1 : capsule 0,84 × 0,19, modèle 0,62")
	_vrai(is_equal_approx(ed._vue._distance, d065 / 0.65), "… et la caméra recule d'autant (%.2f → %.2f)"
		% [d065, ed._vue._distance])
	ed._taille_personnage.value = 0.4
	_vrai(is_equal_approx(capsule.height, 0.336) and ed._vue.rayon_du_bras() < capsule.radius
		and ed._vue._camera.near * 1.7 < ed._vue.rayon_du_bras(),
		"à ×0,4, la sphère du bras reste plus fine que la capsule, le plan proche sous elle")
	ed._taille_personnage.value = 0.65
	_vrai(is_equal_approx(capsule.height, 0.84 * 0.65), "rendu à ×0,65")
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
	ed._appliquer({"poser": {}, "effacer": ilot}, "Dig")   # l'îlot ne sert qu'ici
	_play_test_fini = true


## LE VOL (Jordan, 1er octobre 2026), par les vraies touches : F le lance ; Espace monte et il RESTE en
## l'air une fois lâchée ; A (Q physique) descend mais le sol l'arrête — il heurte toujours le décor ; F le
## rend à la gravité, et il se repose. Attendus : le sol peint est à y = 10,75 (l'aminci), écrit à la main.
func _le_vol(ed: Control, p: CharacterBody3D) -> void:
	for i in 60:
		await physics_frame
	_vrai(p.is_on_floor() and not p.vol, "avant F : il marche, au sol")
	_touche_physique(KEY_F, true)
	_touche_physique(KEY_F, false)
	await process_frame
	_vrai(p.vol and ed._rapport.text.contains("Flying"), "F : il vole, et le rapport dit les touches du vol")
	var y0: float = p.global_position.y
	_touche_physique(KEY_SPACE, true)
	for i in 40:
		await physics_frame
	_touche_physique(KEY_SPACE, false)
	var haut: float = p.global_position.y
	_vrai(haut - y0 > 2.0, "en vol, Espace tenu le fait monter (%.2f case)" % (haut - y0))
	for i in 30:
		await physics_frame
	var arret: float = p.global_position.y
	for i in 40:
		await physics_frame
	_vrai(arret - haut < 0.5 and absf(p.global_position.y - arret) < 0.02 and not p.is_on_floor(),
		"Espace lâchée, il s'arrête vite et PLANE au lieu de retomber (%.2f → %.2f → %.2f)"
		% [haut, arret, p.global_position.y])
	_touche_physique(KEY_Q, true)
	for i in 120:
		await physics_frame
	_touche_physique(KEY_Q, false)
	_vrai(p.global_position.y > 10.6 and p.global_position.y < 11.0,
		"A (Q physique) le fait descendre, et le sol l'ARRÊTE — il ne traverse pas (y = %.2f)" % p.global_position.y)
	_touche_physique(KEY_SPACE, true)
	for i in 30:
		await physics_frame
	_touche_physique(KEY_SPACE, false)
	ed._basculer_vol()
	_vrai(not p.vol and ed._rapport.text.contains("gravity"), "le bouton Fly le rend à la marche, et le dit")
	for i in 90:
		await physics_frame
	_vrai(p.is_on_floor() and p.global_position.y < 10.9, "hors du vol, il retombe et se repose sur le sol")


## Rien du décor entre la TÊTE du personnage et l'œil, ni autour de l'œil. ⚠ Depuis la tête, pas depuis
## `_cible` : le pivot lissé peut être dans la roche, et c'est justement ce qu'on éprouve.
func _oeil_degage(ed: Control, espace: PhysicsDirectSpaceState3D) -> bool:
	var tete: Vector3 = ed._vue.personnage.global_position + Vector3.UP * ed._vue.hauteur_camera()
	var oeil: Vector3 = ed._vue._camera.global_position
	var boule := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	# ⚠ À L'ÉCHELLE DU PERSONNAGE (6 octobre 2026) : 0,1 pour un bras de 0,15 à la taille 1 — plus fine que le bras,
	# plus large que le plan proche (qui suivent tous deux la taille).
	sphere.radius = 0.1 * ed._vue.taille_personnage
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
	# G Z 0.1 Entrée : Z est le HAUT, comme dans Blender. ⚠ Un dixième, pas deux cases : depuis la bride (Jordan,
	# 30 septembre 2026), deux cases replient les faces voisines et le geste s'arrête avant (mesuré à part).
	ed._vue._gui_input(clic)
	for k in [KEY_G, KEY_Z, KEY_0, KEY_PERIOD, KEY_1, KEY_ENTER]:
		ed._input(_cle(k))
	_vrai(mo.maillage.centre(f).is_equal_approx(c0 + Vector3(0, 0.1, 0)), "G Z 0.1 : la face MONTE d'un dixième de case (Z = haut)")
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
		"G Z 0.1 : les %d autres copies de la tuile montrent la face montée" % (mo.temoin.occurrences_de(cle_a).size() - 1))
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
		# ⚠ SEULE DE SA TUILE À L'ÉCRAN (13 octobre 2026) : la boîte prend désormais ce qu'on voit sur TOUTES les copies de
		# la tuile — une face cachée ici et vue sur une autre copie serait prise, à juste titre. Pour juger l'occlusion,
		# une tuile dont aucune autre copie n'a son centre dans le champ.
		var seule := true
		for j in mo.temoin.occurrences_de(mo.temoin.occurrences[i]["cle"]):
			if j != i and cam.is_position_in_frustum((mo.temoin.occurrences[j]["pose"] as Transform3D).origin):
				seule = false
		if not seule:
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
	# L'OPACITÉ (16 octobre 2026) : le VRAI curseur règle l'alpha de la couleur, le sélecteur le suit, la tuile dessinée
	# se mélange ; Ctrl+Z la rend opaque.
	ed._opacite_materiau.value = 0.3
	ed._inscrire_les_retouches()
	var mat_vu: Material = mo.maillage.materiau_godot(0)
	_vrai(absf((mo.maillage.materiaux[0]["couleur"] as Color).a - 0.3) < 1e-3 and absf(ed._couleur_materiau.color.a - 0.3) < 1e-3
		and (mat_vu as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED,
		"Opacity 0,3 : l'alpha de la couleur, le sélecteur suit, le matériau se mélange")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_vrai((mo.maillage.materiaux[0]["couleur"] as Color).a > 0.999
		and (mo.maillage.materiau_godot(0) as BaseMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_DISABLED,
		"Ctrl+Z : opaque de nouveau")
	# U : la face visée dépliée ; le matériau en projection « UV » ; le patron écrit.
	ed._vue._gui_input(clic)
	ed._input(_cle(KEY_U))
	_vrai(mo.maillage.uv(f).size() == (mo.maillage.faces[f] as PackedInt32Array).size(), "U déplie la face visée")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_vrai(mo.maillage.uv(f).is_empty(), "Ctrl+Z défait le dépliage")
	ed._unhandled_key_input(_cle(KEY_Y, true))
	_vrai(not ed._rapport.text.contains("other tile"), "U, seule tuile à porter ce matériau déplié : pas d'avertissement")
	# LE PIÈGE (3 octobre 2026) : une AUTRE tuile porte le même matériau, dépliée — U le dit, et nomme l'atlas.
	var autre_cle := ""
	for c2 in mo.temoin.tuiles:
		if autre_cle == "" and c2 != mo.cle:
			autre_cle = c2
	var autre_avant: RefCounted = mo.temoin.tuiles[autre_cle].copie()
	mo.temoin.tuiles[autre_cle].assigner([0], 0)
	mo.temoin.tuiles[autre_cle].deplier([0])
	ed._vue._gui_input(clic)
	ed._input(_cle(KEY_U))
	_vrai(ed._rapport.text.contains("1 other tile(s) use this material") and ed._rapport.text.contains("Unwrap all tiles"),
		"U quand une autre tuile porte ce matériau déplié : l'écran dit que leurs peintures se recouvrent, et l'atlas")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	ed._unhandled_key_input(_cle(KEY_Y, true))
	mo.temoin.poser_tuile(autre_cle, autre_avant)
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
	# UNE COPIE TOURNÉE : « G X 0.1 » déplace d'un dixième vers +X DU MONDE, quelle que soit la rotation de la copie
	# (Z ne le prouverait pas : un quart de tour autour de +Y garde le haut). ⚠ Une case entière replie une face de
	# la tuile (mesuré : un triangle de `mb_coin_b0h1` écrasé à 4e-6 de son aire) : la bride l'arrête à 0,25.
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
		for k in [KEY_G, KEY_X, KEY_0, KEY_PERIOD, KEY_1, KEY_ENTER]:
			ed._input(_cle(k))
		var apres_monde: Vector3 = mo.pose * mo.maillage.centre(0)
		_vrai((apres_monde - avant_monde).is_equal_approx(Vector3(0.1, 0, 0)),
			"G X 0.1 sur une copie tournée : +0,1 en X du MONDE (%s)" % (apres_monde - avant_monde))
		ed._unhandled_key_input(_cle(KEY_Z, true))
		ed._vue._gui_input(clic)
	# L'enregistrement : le .glb LIÉ se relit tuile par tuile, avec le matériau ; et il rejoint les travaux.
	var raison: String = ed._enregistrer_le_temoin_modele(true)
	var chemin: String = ed._chemin_temoin_modele()
	_egal(raison, "", "le témoin modélisé s'enregistre")
	var relu: Dictionary = BM.librairie_depuis_glb(chemin)
	_vrai(relu.get("lie", false) and relu["erreurs"].is_empty() and (relu["lot"] as MeshLibrary).get_item_list().size() == mo.temoin.tuiles.size(),
		"relu comme témoin lié : une tuile par clé, sans erreur (%s)" % [relu.get("erreurs")])
	# ⚠ IL N'ENTRE PLUS DANS LES TRAVAUX (30 septembre 2026) : c'est le témoin DE LA COUCHE, qu'elle tranche
	# elle-même (étape 3) — son .glb et son .mbtiles portent son identifiant.
	_vrai(not ed._travaux.any(func(t): return String(t["chemin"]) == chemin)
		and chemin == ed._glb_du_temoin(ed._couches[ed._active]) and chemin.contains("_layer"),
		"c'est le témoin de la couche active (%s), pas un travail de l'étape 2" % chemin.get_file())
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


## LES FORMES SPÉCIALES (Jordan, 1er octobre 2026), menées par de VRAIS clics à travers la caméra. Les
## attendus sont déroulés à la main (les mêmes que `test_formes_speciales`) : un mur de 3, x = 30..32.
var _formes_finies := false


func _clic_vue(vue: Control, ou: Vector2, bouton := MOUSE_BUTTON_LEFT) -> void:
	var c := InputEventMouseButton.new()
	c.button_index = bouton
	c.position = ou
	c.pressed = true
	vue._gui_input(c)
	c.pressed = false
	vue._gui_input(c)


func _viser_depuis(vue: Control, cible: Vector3, azimut: float, distance: float) -> void:
	vue._cible = cible
	vue._azimut = azimut
	vue._elevation = 0.0
	vue._distance = distance
	vue._caler()


func _les_formes_speciales(ed: Control) -> void:
	var vue = ed._vue
	var g: GridMap = vue.cases()
	var avant := g.get_used_cells().size()
	var mur := {}
	for x in range(30, 33):
		for y in 6:
			for z in range(-3, 4):
				mur[Vector3i(x, y, z)] = true
	ed._appliquer({"poser": mur, "effacer": {}}, "Add")
	var plein := avant + 126
	_egal(g.get_used_cells().size(), plein, "formes : le mur d'essai (3 × 6 × 7) est posé")

	ed._choisir_forme_speciale("tunnel")
	_vrai(vue.outil == "forme" and (ed._boutons_forme_speciale["tunnel"] as Button).button_pressed
		and not ed._boutons_outil.values().any(func(b): return (b as Button).button_pressed),
		"choisir Tunnel : l'outil devient la forme, aucun outil de pinceau ne reste enfoncé")
	_vrai(ed._reglages_forme.visible and ed._ligne_profil.visible and not ed._garde_corps.visible
		and not ed._ligne_taille.visible, "Tunnel : ses réglages et son profil, sans garde-corps ni pinceau")

	# UN CLIC sur la face −X, en (30,2,0) : le tunnel traverse le mur, une croix de 5 cases × 3 tranches.
	_viser_depuis(vue, Vector3(31.5, 2.5, 0.5), -PI / 2, 14.0)
	var face_ouest: Vector2 = vue._camera.unproject_position(Vector3(30.0, 2.5, 0.5))
	vue._survoler(face_ouest)
	_egal(vue._apercu.multimesh.instance_count, 15, "l'aperçu montre les 15 cases que le tunnel creusera")
	_clic_vue(vue, face_ouest)
	_egal(g.get_used_cells().size(), plein - 15, "un clic creuse le tunnel")
	_vrai(g.get_cell_item(Vector3i(30, 2, 0)) == -1 and g.get_cell_item(Vector3i(32, 2, 0)) == -1
		and g.get_cell_item(Vector3i(31, 3, 0)) == -1 and g.get_cell_item(Vector3i(31, 2, 1)) == -1
		and g.get_cell_item(Vector3i(31, 3, 1)) != -1, "… la croix exacte, de part en part")
	_vrai(ed._rapport.text.contains("Tunnel") and ed._rapport.text.contains("opens"),
		"… et l'écran dit qu'il débouche")
	ed._histoire.undo()
	_egal(g.get_used_cells().size(), plein, "UN Ctrl+Z rend le mur")
	# L'OCCUPATION DES FORMES EST L'ÉTAT DE LA COUCHE (4 octobre 2026 : la rebâtir coûtait ~150 ms par case survolée
	# sur l'exemple) — et elle suit le Ctrl+Z. Attendu relu dans la GRILLE.
	var occ: Dictionary = vue._occupees_actives()
	_vrai(is_same(occ, vue.monde()._miennes) and is_same(ed._occupees(), occ),
		"les formes et les opérations lisent l'état tenu par la couche, sans relire la grille")
	_vrai(occ.size() == g.get_used_cells().size() and g.get_used_cells().all(func(c): return occ.has(c))
		and occ.has(Vector3i(30, 2, 0)), "… et il est la grille, après le Ctrl+Z")

	# CONNECT : une ancre sur la face ouest, Échap l'oublie, puis l'ouest et l'est.
	ed._choisir_les_bouts("relier")
	_vrai(not ed._ligne_longueur.visible, "Connect : la profondeur disparaît (les deux bouts la donnent)")
	_clic_vue(vue, face_ouest)
	_vrai(not vue.ancre_forme.is_empty() and vue._ancre_vue.visible and g.get_used_cells().size() == plein,
		"Connect : le premier clic pose une ancre, montrée, sans rien changer")
	ed._unhandled_key_input(_cle(KEY_ESCAPE))
	_vrai(vue.ancre_forme.is_empty() and not vue._ancre_vue.visible, "Échap oublie l'ancre")
	_clic_vue(vue, face_ouest)
	_viser_depuis(vue, Vector3(31.5, 2.5, 0.5), PI / 2, 14.0)
	_clic_vue(vue, vue._camera.unproject_position(Vector3(33.0, 2.5, 0.5)))
	_egal(g.get_used_cells().size(), plein - 15, "Connect : le second clic, sur la face est, relie les deux faces")
	_vrai(vue.ancre_forme.is_empty(), "… et l'ancre est consommée")
	ed._histoire.undo()

	# Le PUITS refuse une paroi, et le dit ; rien ne change.
	ed._choisir_forme_speciale("puits")
	ed._choisir_les_bouts("droit")
	_clic_vue(vue, vue._camera.unproject_position(Vector3(33.0, 2.5, 0.5)))
	_vrai(g.get_used_cells().size() == plein and ed._rapport.text.contains("FLOOR"),
		"un puits cliqué sur une paroi est refusé, et l'écran dit pourquoi")
	# … et en Connect, la PREMIÈRE ancre est refusée aussi : on ne pose pas un bout qui ne pourra rien donner.
	ed._choisir_les_bouts("relier")
	ed._rapport.text = ""
	_clic_vue(vue, vue._camera.unproject_position(Vector3(33.0, 2.5, 0.5)))
	_vrai(vue.ancre_forme.is_empty() and ed._rapport.text.contains("FLOOR"),
		"Connect : une paroi n'est pas une première ancre de puits, et l'écran le dit")
	ed._choisir_les_bouts("droit")

	# Le PONT : une seconde paroi en x = 36..37, l'œil entre les deux. Tablier de 3 sur x = 33..35 (9 cases)
	# et ses deux rebords (6) : 15 cases.
	var mur2 := {}
	for x in range(36, 38):
		for y in 6:
			for z in range(-3, 4):
				mur2[Vector3i(x, y, z)] = true
	ed._appliquer({"poser": mur2, "effacer": {}}, "Add")
	var deux_murs: int = plein + 84
	ed._choisir_forme_speciale("pont")
	_vrai(ed._garde_corps.visible and not ed._ligne_profil.visible, "Bridge : le garde-corps, pas de profil")
	_viser_depuis(vue, Vector3(34.5, 2.5, 0.5), PI / 2, 1.0)
	_clic_vue(vue, vue._camera.unproject_position(Vector3(33.0, 2.5, 0.5)))
	_egal(g.get_used_cells().size(), deux_murs + 15, "un pont de taille 2 avec rebords : 9 + 6 cases")
	_vrai(g.get_cell_item(Vector3i(34, 2, 0)) != -1 and g.get_cell_item(Vector3i(34, 3, 0)) == -1
		and g.get_cell_item(Vector3i(34, 3, 1)) != -1, "… le tablier, le passage libre, le rebord")
	ed._histoire.undo()

	# Le BALCON : profondeur 3 → 9 cases de dalle et 7 de rebord.
	ed._choisir_forme_speciale("balcon")
	_vrai(not ed._ligne_bouts.visible and ed._ligne_longueur.visible, "Balcony : un clic seulement, une profondeur")
	ed._longueur_forme.value = 3
	_clic_vue(vue, vue._camera.unproject_position(Vector3(33.0, 2.5, 0.5)))
	_egal(g.get_used_cells().size(), deux_murs + 16, "un balcon de 3 × 3 avec son rebord : 16 cases")
	ed._histoire.undo()

	# L'ESCALIER : cliqué sur la paroi est en (32,2,0), il arrive au niveau y = 2. Taille 2 (z = −1..1), pas 2,
	# trois rangées (Length 3, gardée du balcon) : dessus 2, 2, 1 en x = 33, 34, 35 ; le garde-corps en z = ±1.
	ed._choisir_forme_speciale("escalier")
	_vrai(ed._ligne_bouts.visible and ed._ligne_longueur.visible and ed._ligne_pas.visible
		and ed._garde_corps.visible and not ed._ligne_profil.visible,
		"Stairs : Straight / Connect, Length, Step et le garde-corps, pas de profil")
	_clic_vue(vue, vue._camera.unproject_position(Vector3(33.0, 2.5, 0.5)))
	_vrai(g.get_cell_item(Vector3i(33, 2, 0)) != -1 and g.get_cell_item(Vector3i(34, 2, 0)) != -1
		and g.get_cell_item(Vector3i(35, 1, 0)) != -1 and g.get_cell_item(Vector3i(35, 2, 0)) == -1
		and g.get_cell_item(Vector3i(33, 3, 0)) == -1 and g.get_cell_item(Vector3i(33, 3, 1)) != -1
		and g.get_cell_item(Vector3i(33, 3, -1)) != -1,
		"un clic pose l'escalier : le palier au niveau cliqué, la marche suivante plus bas, le garde-corps, le passage libre")
	_vrai(ed._rapport.text.contains("Stairs"), "… et l'écran le dit")
	ed._histoire.undo()
	_egal(g.get_used_cells().size(), deux_murs, "UN Ctrl+Z rend les deux murs")
	ed._choisir_les_bouts("relier")
	_vrai(not ed._ligne_pas.visible, "Connect : le pas disparaît (les deux sols le donnent)")
	ed._rapport.text = ""
	_clic_vue(vue, vue._camera.unproject_position(Vector3(33.0, 2.5, 0.5)))
	_vrai(vue.ancre_forme.is_empty() and ed._rapport.text.contains("FLOORS"),
		"Connect : une paroi n'est pas une ancre d'escalier, et l'écran le dit")
	ed._choisir_les_bouts("droit")

	# [ et ] règlent la taille de la FORME quand une forme est choisie, pas celle du pinceau.
	var pinceau: float = ed._taille.value
	ed._unhandled_key_input(_cle(KEY_BRACKETRIGHT))
	_vrai(ed._taille_forme.value == 3.0 and ed._taille.value == pinceau, "] grossit la forme, pas le pinceau")
	ed._taille_forme.value = 2

	ed._choisir_outil("ajouter")
	_vrai(not ed._boutons_forme_speciale.values().any(func(b): return (b as Button).button_pressed)
		and not ed._reglages_forme.visible, "revenir à Add relâche la forme et cache ses réglages")
	ed._histoire.undo()
	ed._histoire.undo()
	_egal(g.get_used_cells().size(), avant, "les murs d'essai défaits : la couche est rendue telle quelle")
	_formes_finies = true


## CTRL+CLIC CALE LA GRILLE SUR LA MATIÈRE (Jordan, 1er octobre 2026). Attendu déroulé à la main : une colonne
## (40, 0..4, 40) vue d'en haut, le rayon touche son sommet (40, 4, 40) → étage 4 ; dans le vide, rien ne change.
var _ctrl_clic_fini := false


func _ctrl_clic_cale_la_grille(ed: Control) -> void:
	var vue = ed._vue
	var g: GridMap = vue.cases()
	var avant := g.get_used_cells().size()
	var colonne := {}
	for y in 5:
		colonne[Vector3i(40, y, 40)] = true
	ed._appliquer({"poser": colonne, "effacer": {}}, "Add")
	ed._choisir_outil("ajouter")
	vue.regler_etage(0)
	ed._compteur_etage.value = 0
	var c := InputEventMouseButton.new()
	c.button_index = MOUSE_BUTTON_LEFT
	c.ctrl_pressed = true
	c.position = _viser_d_en_haut(vue, Vector3(40.5, 5.0, 40.5))
	c.pressed = true
	vue._gui_input(c)
	c.pressed = false
	vue._gui_input(c)
	_egal(vue.etage, 4, "Ctrl+clic sur le sommet de la colonne : la grille passe à l'étage 4")
	_egal(int(ed._compteur_etage.value), 4, "… et le compteur d'étage le suit")
	_vrai(ed._rapport.text.contains("floor y = 4"), "… et l'écran le dit")
	_egal(g.get_used_cells().size(), avant + 5, "Ctrl+clic ne peint rien (Add choisi)")
	c.position = _viser_d_en_haut(vue, Vector3(140.5, 0.0, 140.5))
	c.pressed = true
	vue._gui_input(c)
	c.pressed = false
	vue._gui_input(c)
	_vrai(vue.etage == 4 and ed._rapport.text.contains("no matter"),
		"Ctrl+clic dans le vide : l'étage ne change pas, et l'écran le dit")
	ed._compteur_etage.value = 0
	ed._histoire.undo()
	_egal(g.get_used_cells().size(), avant, "la colonne d'essai défaite")
	_ctrl_clic_fini = true


## LES FLUIDES (Jordan, 1er octobre 2026), menés par de VRAIS clics à travers la caméra. Attendus déroulés à la
## main (les mêmes mondes que `test_fluides`) : une cuvette 5 × 5 en x, z = 60..64 (plancher y = 0, anneau de
## murs y = 1..2), une colonne en (70, 0..3, 62), et le vide en (90, 0, 90).
var _fluides_finis := false


func _viser_d_en_haut(vue: Control, cible: Vector3) -> Vector2:
	_viser_depuis(vue, cible, 0.6, 16.0)
	vue._elevation = 1.2
	vue._caler()
	return vue._camera.unproject_position(cible)


func _les_fluides(ed: Control) -> void:
	var vue = ed._vue
	ed._aller_a("monde")
	# ⚠ UNE CUVETTE CALME, NOYÉE DANS UN PLATEAU (y = 0..2, x de 54 à 68, z de 54 à 70) : posée seule sur le vide, sa
	# rive donnerait sur une chute et elle DÉBORDERAIT (2 octobre 2026). L'intérieur 61..63 × 1..2 est le lac ; un
	# chenal creusé sous le plateau en (62, 2, 54..59) mène à son bord, à plus de 4 cases de toute chute.
	var cuvette := {}
	for x in range(54, 69):
		for z in range(54, 71):
			for y in 3:
				if not (y > 0 and x >= 61 and x <= 63 and z >= 61 and z <= 63) 						and not (y == 2 and x == 62 and z < 60):
					cuvette[Vector3i(x, y, z)] = true
	# Le chenal est COUVERT (un toit en y = 3) : ouvert, il serait une chute à deux cases de la rive.
	for z in range(54, 60):
		cuvette[Vector3i(62, 3, z)] = true
	ed._appliquer({"poser": cuvette, "effacer": {}}, "Add")

	# LE DÉZOOM DU MONDE (Jordan, 2 octobre 2026) : la molette recule jusqu'à 1 000 cases (120 avant), et les ombres
	# suivent. Attendus écrits à la main.
	var distance_avant: float = vue._distance
	var molette := InputEventMouseButton.new()
	molette.button_index = MOUSE_BUTTON_WHEEL_DOWN
	molette.pressed = true
	for i in 80:
		vue._gui_input(molette)
	_vrai(is_equal_approx(vue._distance, 1000.0) and vue._soleil.directional_shadow_max_distance >= 2000.0,
		"World : la molette recule jusqu'à 1 000 cases, les ombres jusqu'à 2 000 (%.0f, %.0f)"
		% [vue._distance, vue._soleil.directional_shadow_max_distance])
	vue._distance = distance_avant
	vue._caler()
	# FLUIDS EST UN ATELIER (Jordan, 2 octobre 2026) : par son VRAI bouton ; l'outil de World d'avant est Dig.
	ed._choisir_outil("creuser")
	(ed._boutons_atelier["fluides"] as Button).pressed.emit()
	await process_frame
	_vrai(ed._atelier == "fluides" and vue.outil == "eau" and vue.mode == "monde",
		"Fluids : un atelier, sur le monde, l'outil devient l'eau")
	_egal(ed._eaux.size(), 1, "Fluids : une couche d'eau est créée pour recevoir la source")
	_vrai(ed._droite_fluides.visible and not ed._droite.visible,
		"Fluids : sa barre de droite, pas celle des outils de peinture")

	# LE LAC : un clic sur le plancher (61..63 libres) — la cuvette se remplit à ras bord, 3 × 3 × 2 = 18 cases.
	var plancher: Vector2 = _viser_d_en_haut(vue, Vector3(62.5, 1.0, 62.5))
	vue._survoler(plancher)
	_egal(vue._apercu.multimesh.instance_count, 9, "l'aperçu montre la surface du lac à venir (9 cases)")
	_clic_vue(vue, plancher)
	_egal(ed._eaux[0]["sources"], [Vector3i(62, 1, 62)], "un clic pose UNE source, devant la face visée")
	ed._recalculer_eau()
	var lac: Dictionary = ed._corps_eau[0][0]
	_vrai(lac["genre"] == "lac" and lac["eau"].size() == 18 and lac["niveau"] == 2, "… un lac de 18 cases, niveau 2")
	var nappe: MeshInstance3D = vue.nappes()[0]
	_vrai(nappe.mesh != null and nappe.visible and (nappe.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		as PackedVector3Array).size() == 4, "… dessiné : UNE nappe dans la vue (les 9 cases, même profondeur, fusionnées)")
	_vrai(nappe.material_override is ShaderMaterial, "… avec le preset de RiverStones")
	_vrai(ed._rapport.text.contains("Lake"), "… et l'écran le dit")

	# LE MONDE CHANGE, L'EAU SUIT : une échancrure dans le mur, vers le chenal, fait tomber le lac au niveau 1.
	# ⚠ ON NE RECALCULE PAS À LA MAIN : on attend une image, c'est l'appli qui doit suivre d'elle-même.
	ed._appliquer({"poser": {}, "effacer": {Vector3i(62, 2, 60): true}}, "Dig")
	await process_frame
	_egal(ed._corps_eau[0][0]["eau"].size(), 9, "une échancrure creusée : le lac redescend (9 cases), sans un clic")
	# ⚠ L'EAU APPARTIENT AU MONDE ENTIER : boucher l'échancrure dans une AUTRE couche, CACHÉE, retient le lac.
	var rock: int = ed._active
	var atelier_avant: String = ed._atelier
	ed._nouvelle_couche()
	_egal(ed._atelier, atelier_avant, "New layer : on reste dans l'atelier où l'on est (%s)" % atelier_avant)
	ed._montrer_couche(ed._active, false)
	ed._appliquer({"poser": {Vector3i(62, 2, 60): true}, "effacer": {}}, "Add")
	await process_frame
	_egal(ed._corps_eau[0][0]["eau"].size(), 18, "une case d'une autre couche, même cachée, retient l'eau")
	ed._supprimer_couche()
	await process_frame
	_egal(ed._corps_eau[0][0]["eau"].size(), 9, "supprimer la couche qui bouchait : le lac retombe")
	ed._activer(rock)
	if ed._atelier != "fluides":
		ed._aller_a("fluides")
	ed._appliquer({"poser": {Vector3i(62, 2, 60): true}, "effacer": {}}, "Add")
	await process_frame
	_egal(ed._corps_eau[0][0]["eau"].size(), 18, "le mur refermé : le lac remonte")
	# LA REPRISE (2 octobre 2026) : une case posée loin du lac, au-dessus de tout ce qu'il a regardé, ne le recalcule
	# pas — le même corps, le même maillage.
	var corps_avant: Dictionary = ed._corps_eau[0][0]
	var maillage_avant: ArrayMesh = ed._maillages_eau[0][1]
	ed._appliquer({"poser": {Vector3i(55, 8, 55): true}, "effacer": {}}, "Add")
	await process_frame
	_vrai(is_same(ed._corps_eau[0][0], corps_avant) and is_same(ed._maillages_eau[0][1], maillage_avant),
		"une case posée loin du lac : ni le lac ni sa nappe ne sont recalculés")
	ed._appliquer({"poser": {}, "effacer": {Vector3i(55, 8, 55): true}}, "Dig")
	await process_frame
	# ⚠ UNE SOURCE EN ERREUR NE FAIT PLUS REMAILLER SA COUCHE (4 octobre 2026) : `FL.monde` la refait à chaque geste,
	# mais elle ne dessine rien. Sur l'exemple, 7 sources refusées faisaient remailler les trois couches d'eau après
	# CHAQUE geste (~1 s). Une source posée dans la roche du mur (refusée), puis une case loin du lac : même maillage.
	(ed._eaux[0]["sources"] as Array).append(Vector3i(62, 2, 60))
	ed._recalculer_eau(false)
	_egal(ed._corps_eau[0][1]["erreur"], "dans_la_matiere", "une source dans la roche : refusée")
	maillage_avant = ed._maillages_eau[0][1]
	ed._appliquer({"poser": {Vector3i(55, 8, 55): true}, "effacer": {}}, "Add")
	await process_frame
	_vrai(is_same(ed._maillages_eau[0][1], maillage_avant),
		"une case posée loin du lac, une source en erreur dans la couche : la nappe n'est pas remaillée")
	ed._appliquer({"poser": {}, "effacer": {Vector3i(55, 8, 55): true}}, "Dig")
	(ed._eaux[0]["sources"] as Array).pop_back()
	ed._recalculer_eau(false)
	await process_frame
	# LA BOÎTE DE L'EAU SUIT LES GESTES (4 octobre 2026 : la recalculer à chaque geste coûtait ~70 ms sur l'exemple).
	# Attendu : `FL.boite` sur les cases du monde, recalculée ici. Une case posée hors de la boîte l'élargit sans
	# recalcul ; la retirer (au bord) la fait refaire ; retirer une case intérieure ne la change pas.
	const FLb := preload("res://addons/marchingblocks_core/fluides.gd")
	ed._tenir_occ_eau()
	ed._boite_eau()
	var loin := Vector3i(90, 3, 90)
	ed._appliquer({"poser": {loin: true}, "effacer": {}}, "Add")
	ed._tenir_occ_eau()
	_vrai(ed._boite_eau_taille == ed._occ_eau.size() and ed._boite_eau_cache == FLb.boite(ed._occ_eau),
		"une case posée hors de la boîte : la boîte tenue s'élargit, sans recalcul (%s)" % [ed._boite_eau_cache])
	ed._appliquer({"poser": {}, "effacer": {loin: true}}, "Dig")
	ed._tenir_occ_eau()
	_vrai(ed._boite_eau_taille == ed._occ_eau.size() and ed._boite_eau_cache == FLb.boite(ed._occ_eau),
		"la retirer (elle faisait le bord) : la boîte est refaite — dans les comptes par axe, sans rebalayer le monde")
	# DEUX CASES SUR LE MÊME PLAN DU BORD (x = 95), DANS l'étendue du monde en y et en z : en retirer une ne change pas la boîte, retirer
	# l'autre la fait rétrécir — toujours sans rebalayage (4 octobre 2026 : ~240 ms par retrait au bord sur l'exemple).
	var milieu: Vector3i = (ed._boite_eau()["lo"] + ed._boite_eau()["hi"]) / 2
	var bord_a := Vector3i(95, milieu.y, milieu.z)
	var bord_b := Vector3i(95, milieu.y, milieu.z + 1)
	ed._appliquer({"poser": {bord_a: true, bord_b: true}, "effacer": {}}, "Add")
	ed._tenir_occ_eau()
	var avec_les_deux: Dictionary = ed._boite_eau_cache.duplicate()
	ed._appliquer({"poser": {}, "effacer": {bord_a: true}}, "Dig")
	ed._tenir_occ_eau()
	_vrai(ed._boite_eau_taille == ed._occ_eau.size() and ed._boite_eau_cache == FLb.boite(ed._occ_eau)
		and ed._boite_eau_cache == avec_les_deux, "deux cases sur le plan du bord, une retirée : la boîte ne bouge pas")
	ed._appliquer({"poser": {}, "effacer": {bord_b: true}}, "Dig")
	ed._tenir_occ_eau()
	_vrai(ed._boite_eau_taille == ed._occ_eau.size() and ed._boite_eau_cache == FLb.boite(ed._occ_eau)
		and ed._boite_eau_cache["hi"].x < 96, "… l'autre retirée : elle rétrécit (%s)" % [ed._boite_eau_cache])
	var dedans: Vector3i = Vector3i(58, 1, 58)
	_vrai(ed._occ_eau.has(dedans), "une case intérieure de la cuvette existe")
	ed._appliquer({"poser": {}, "effacer": {dedans: true}}, "Dig")
	ed._tenir_occ_eau()
	_vrai(ed._boite_eau_taille == ed._occ_eau.size() and ed._boite_eau_cache == FLb.boite(ed._occ_eau),
		"retirer une case intérieure : la boîte tenue ne change pas, sans recalcul")
	ed._histoire.undo()
	ed._recalculer_eau(false)
	await process_frame

	# ⚠ UN COUP DE PINCEAU N'EST PAS REJOUÉ PAR L'HISTORIQUE (les cases sont posées pendant le glissé) : c'est le
	# coup lui-même qui doit rappeler l'eau. Un coup « Dig » sur le mur : le lac redescend ; Ctrl+Z le rend.
	ed._coup_commence()
	ed._touche({"poser": {}, "effacer": {Vector3i(62, 2, 60): true}}, "Dig")
	ed._coup_fini()
	await process_frame
	_egal(ed._corps_eau[0][0]["eau"].size(), 9, "un coup de pinceau dans le mur : le lac redescend")
	ed._histoire.undo()
	await process_frame
	_egal(ed._corps_eau[0][0]["eau"].size(), 18, "Ctrl+Z sur le coup : le lac remonte")

	# Cliquer sur l'eau qui est déjà là ne pose rien.
	_clic_vue(vue, plancher)
	_vrai(ed._eaux[0]["sources"].size() == 1 and ed._rapport.text.contains("already"),
		"un clic dans un lac ne pose pas de seconde source, et l'écran le dit")

	# LA RIVIÈRE : la colonne (70, 0..3, 62) ; sur son sommet, l'eau va en +X et tombe jusqu'au bas du monde.
	var colonne := {}
	for y in 4:
		colonne[Vector3i(70, y, 62)] = true
	ed._appliquer({"poser": colonne, "effacer": {}}, "Add")
	_clic_vue(vue, _viser_d_en_haut(vue, Vector3(70.5, 4.0, 62.5)))
	ed._recalculer_eau()
	var riv: Dictionary = ed._corps_eau[0][1]
	_vrai(riv["genre"] == "riviere" and riv["fin"] == "sort"
		and riv["cours"][0]["case"] == Vector3i(70, 4, 62) and riv["cours"][1]["case"] == Vector3i(71, 4, 62),
		"sur la colonne : une rivière, de (70,4,62) vers +X, qui quitte le monde")

	# L'OCÉAN : dans le vide, sur le plan de l'étage 0. La rivière, recalculée, le REJOINT.
	# ⚠ LA MER SE CHOISIT AVANT DE SE CALCULER (Jordan, 4 octobre 2026) : survoler le vide montre un PLAN, sans rien
	# remplir ; un premier clic l'épingle, la molette et PgUp / PgDn règlent sa hauteur ; le second clic (ou Entrée) la pose.
	vue.regler_etage(0)
	var vide_0 := _viser_d_en_haut(vue, Vector3(90.5, 0.0, 90.5))
	var calculs_avant: Variant = ed._monde_eau
	_bouge(vue, vide_0)
	_vrai(vue.plan_mer_visible() != null and is_equal_approx(float(vue.plan_mer_visible()), 0.0)
		and is_same(ed._monde_eau, calculs_avant) and not ed._eau_a_refaire and not vue._apercu.visible,
		"survoler le vide : un plan à la hauteur 0, sans cases d'océan, et l'eau n'est PAS recalculée")
	_clic_vue(vue, vide_0)
	_vrai(ed._mer_choisie == 0 and ed._eaux[0]["sources"].size() == 2 and not ed._eau_a_refaire
		and ed._rapport.text.contains("Sea at height 0"),
		"un premier clic dans le vide : la hauteur s'épingle, rien n'est posé ni calculé, l'écran le dit")
	_cran(vue, 1)
	_cran(vue, 1)
	_vrai(ed._mer_choisie == 2 and is_equal_approx(float(vue.plan_mer_visible()), 2.0) and not ed._eau_a_refaire,
		"deux crans de molette : la mer en choix monte à 2 (le plan suit), sans calcul ni zoom")
	_touche_physique(KEY_PAGEDOWN, true)
	_touche_physique(KEY_PAGEDOWN, false)
	_touche_physique(KEY_PAGEDOWN, true)
	_touche_physique(KEY_PAGEDOWN, false)
	_egal(ed._mer_choisie, 0, "PgDn deux fois : la mer en choix redescend à 0")
	_bouge(vue, _viser_d_en_haut(vue, Vector3(62.5, 1.0, 62.5)))
	_egal(ed._mer_choisie, 0, "la souris ne déplace plus la hauteur épinglée")
	_clic_vue(vue, vide_0)
	_vrai(ed._mer_choisie == null and vue.plan_mer_visible() == null and ed._eau_a_refaire,
		"le second clic pose la mer : le plan s'en va, le calcul part (une fois)")
	ed._recalculer_eau()
	_egal(ed._eaux[0]["sources"].size(), 3, "dans le vide : une troisième source")
	_vrai(ed._corps_eau[0][2]["genre"] == "ocean" and ed._corps_eau[0][2]["niveau"] == 0, "… un océan au niveau 0")
	_vrai(ed._corps_eau[0][1]["fin"] == "rejoint", "… et la rivière le rejoint désormais")
	_vrai(ed._corps_eau[0][0]["eau"].size() == 18, "… le lac, au-dessus de la mer, ne change pas")
	ed._rafraichir_eaux()
	_vrai((ed._liste_eaux.get_child(0).get_child(1) as Button).text.contains("1 sea, 1 lake, 1 river"),
		"la liste des couches d'eau dit ce que porte la couche")
	# Un choix abandonné ne pose rien : clic droit, puis Échap (qui ne quitte pas Fluids).
	_clic_vue(vue, _viser_d_en_haut(vue, Vector3(97.5, 0.0, 97.5)))
	_clic_vue(vue, _viser_d_en_haut(vue, Vector3(97.5, 0.0, 97.5)), MOUSE_BUTTON_RIGHT)
	_vrai(ed._mer_choisie == null and ed._eaux[0]["sources"].size() == 3 and vue.plan_mer_visible() == null,
		"un clic droit abandonne la mer en choix : rien n'est posé")
	_clic_vue(vue, _viser_d_en_haut(vue, Vector3(97.5, 0.0, 97.5)))
	_touche_physique(KEY_ESCAPE, true)
	_touche_physique(KEY_ESCAPE, false)
	_vrai(ed._mer_choisie == null and ed._eaux[0]["sources"].size() == 3 and ed._atelier == "fluides",
		"Échap abandonne la mer en choix, sans quitter Fluids")

	# UN SEUL OCÉAN (Jordan, 3 octobre 2026) : une mer posée à une autre hauteur DÉPLACE la mer — l'ancienne source part
	# dans la même action ; un Ctrl+Z la rend. À la même hauteur, rien ne change, et l'écran le dit.
	vue.regler_etage(1)
	var vide_1 := _viser_d_en_haut(vue, Vector3(95.5, 1.0, 95.5))
	_clic_vue(vue, vide_1)
	_clic_vue(vue, vide_1)
	ed._recalculer_eau()
	_egal(ed._eaux[0]["sources"], [Vector3i(62, 1, 62), Vector3i(70, 4, 62), Vector3i(95, 1, 95)],
		"une mer posée plus haut : la mer y passe, l'ancienne source s'en va")
	_vrai(ed._corps_eau[0][2]["genre"] == "ocean" and ed._corps_eau[0][2]["niveau"] == 1
		and ed._rapport.text.contains("only one sea"), "… une seule mer, au niveau 1, et l'écran le dit")
	_clic_vue(vue, _viser_d_en_haut(vue, Vector3(99.5, 1.0, 99.5)))
	_vrai(ed._rapport.text.contains("already at this height"), "en choix à la même hauteur : l'écran le dit d'emblée")
	_touche_physique(KEY_ENTER, true)
	_touche_physique(KEY_ENTER, false)
	_vrai(ed._mer_choisie == null and ed._eaux[0]["sources"].size() == 3
		and ed._rapport.text.contains("already at height 1"), "Entrée à la même hauteur : rien ne change, et l'écran le dit")
	ed._histoire.undo()
	ed._recalculer_eau()
	_egal(ed._eaux[0]["sources"], [Vector3i(62, 1, 62), Vector3i(70, 4, 62), Vector3i(90, 0, 90)],
		"Ctrl+Z : la mer revient au niveau 0, À SA PLACE dans la liste")
	vue.regler_etage(0)

	# LE CLIC DROIT RETIRE l'eau visée ; Ctrl+Z la rend.
	_clic_vue(vue, _viser_d_en_haut(vue, Vector3(62.5, 1.0, 62.5)), MOUSE_BUTTON_RIGHT)
	_egal(ed._eaux[0]["sources"], [Vector3i(70, 4, 62), Vector3i(90, 0, 90)], "un clic droit sur le lac retire SA source")
	ed._histoire.undo()
	_egal(ed._eaux[0]["sources"][0], Vector3i(62, 1, 62), "Ctrl+Z la remet À SA PLACE dans la liste")

	# LE PRESET (étape 3) : choisi dans la liste, il change le shader de la nappe, et il s'enregistre.
	var noms_presets: Array = []
	for i in ed._preset_eau.item_count:
		noms_presets.append(ed._preset_eau.get_item_text(i))
	_egal(noms_presets, ["Stylized (RiverStones)", "Clear (refraction)", "Reflective", "Lava", "Swamp water",
		"Glowing acid"], "six liquides dans la liste, dont lave, marais et acide (2 octobre 2026)")
	ed._preset_eau.select(2)
	ed._preset_eau.item_selected.emit(2)
	await process_frame
	var mat: ShaderMaterial = (vue.nappes()[0] as MeshInstance3D).material_override
	_vrai(ed._eaux[0]["preset"] == "reflechissant" and mat != null and mat.shader.code.contains("reflet_ecran"),
		"choisir Reflective : la nappe prend le shader réfléchissant")

	# Cacher la couche d'eau ; enregistrer ; relire.
	ed._montrer_eau(0, false)
	ed._recalculer_eau()
	_vrai(not (vue.nappes()[0] as Node3D).visible, "une couche d'eau cachée n'est plus dessinée")
	ed._enregistrer()
	var relu: Dictionary = Projet.depuis_texte(FileAccess.get_file_as_string(ed._projet), [])
	_vrai(relu.has("eaux") and relu["eaux"].size() == 1 and relu["eaux"][0]["sources"].size() == 3
		and relu["eaux"][0]["visible"] == false and relu["eaux"][0]["preset"] == "reflechissant",
		"le projet enregistre la couche d'eau : ses 3 sources, cachée, son preset")
	ed._montrer_eau(0, true)

	# Une nouvelle couche d'eau devient l'active ; la supprimer s'annule.
	ed._nouvelle_eau()
	_vrai(ed._eaux.size() == 2 and ed._eau_active == 1, "New : une seconde couche d'eau, active")
	ed._supprimer_eau()
	_egal(ed._eaux.size(), 1, "Delete : supprimée")
	ed._histoire.undo()
	_egal(ed._eaux.size(), 2, "Ctrl+Z la rend")
	_vrai(vue._eaux.visible, "dans World, les nappes se montrent")

	# LA LISTE DES TRAVAUX SURVIT (3 octobre 2026) : un travail importé (le .glb du témoin d'une couche, relu comme un
	# travail) revient dans l'étape 2 à la réouverture, et se relit quand on le regarde.
	var travail_glb := ""
	for c in ed._couches:
		if travail_glb == "" and FileAccess.file_exists(ed._glb_du_temoin(c)):
			travail_glb = ed._glb_du_temoin(c)
	if travail_glb != "":
		await ed._importer(travail_glb)
	_vrai(travail_glb != "" and ed._travaux.size() == 1, "un travail importé est dans la liste (%s)" % travail_glb.get_file())
	# ROUVRIR le projet : l'eau revient de ses seules sources, et se redéduit.
	await ed._ouvrir(ed._projet)
	await process_frame
	_vrai(ed._travaux.size() == 1 and str(ed._travaux[0]["chemin"]) == travail_glb and ed._travaux[0]["maillage"] == null,
		"rouvert : le travail importé revient dans la liste, sans être relu")
	_vrai(ed._travail_maillage() != null and ed._liste_travaux.get_child_count() == 1,
		"… il se relit quand on le regarde, et l'étape 2 le montre")
	_vrai(ed._eaux.size() == 2 and ed._eaux[0]["sources"].size() == 3 and ed._corps_eau.size() == 2
		and ed._corps_eau[0][0]["genre"] == "lac" and ed._corps_eau[0][0]["eau"].size() == 18,
		"rouvert : les deux couches d'eau, leurs sources, et le lac redéduit")

	# FLUIDS SE DÉSACTIVE PROPREMENT : Échap rend World ET l'outil d'avant (Dig) ; un clic ne pose plus d'eau.
	if ed._atelier != "fluides":
		ed._aller_a("fluides")
	_vrai(vue.outil == "eau", "rouvert dans Fluids : toujours l'eau")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await process_frame
	await process_frame
	_vrai(ed._atelier == "monde" and vue.outil == "creuser" and (ed._boutons_outil["creuser"] as Button).button_pressed
		and not ed._droite_fluides.visible, "Échap dans Fluids : retour à World, l'outil d'avant (Dig) rendu")
	var sources_avant: int = ed._eaux[0]["sources"].size()
	_clic_vue(vue, _viser_d_en_haut(vue, Vector3(90.5, 0.0, 90.5)))
	_egal(ed._eaux[0]["sources"].size(), sources_avant, "… et un clic dans World ne pose plus d'eau")
	ed._aller_a("fluides")
	ed._aller_a("witness")
	_vrai(vue.outil == "creuser", "quitter Fluids pour un autre atelier rend aussi l'outil")
	ed._aller_a("monde")
	ed._choisir_outil("ajouter")
	await _la_nage(ed)
	await _le_rendu_du_play_test(ed)
	await _la_meteo(ed)
	_fluides_finis = true


## LA BARRE DE RENDU DU PLAY TEST (Jordan, 1er octobre 2026). Attendus : les valeurs DÉCIDÉES de la vue (constantes),
## pas la liste éprouvée ; et en quittant le Play test, l'éclairage du travail, quoi qu'on ait essayé.
func _le_rendu_du_play_test(ed: Control) -> void:
	var vue = ed._vue
	_vrai(not ed._droite_jeu.visible, "hors du Play test, pas de barre de rendu")
	vue._cible = Vector3(62.5, 2.0, 62.5)
	ed._aller_a("jeu")
	await process_frame
	_vrai(ed._droite_jeu.visible and not ed._droite.visible, "au Play test, la barre de droite est celle du rendu")
	var env: Environment = vue._env
	_vrai(env.ssao_enabled and env.ssil_enabled and not env.sdfgi_enabled and env.glow_enabled,
		"au départ : SSAO, SSIL, halo, pas de SDFGI")
	# LE DISQUE SOLAIRE (Jordan, 3 octobre 2026) : une lumière qui ne fait QUE le disque, enfant du soleil ; le soleil
	# n'éclaire que le monde. Attendus écrits à la main (2°, éclat 4, l'angle du vrai soleil à 0 : ses ombres intactes).
	var disque: DirectionalLight3D = vue._disque_solaire
	_vrai(disque.visible and disque.sky_mode == DirectionalLight3D.SKY_MODE_SKY_ONLY
		and vue._soleil.sky_mode == DirectionalLight3D.SKY_MODE_LIGHT_ONLY and disque.get_parent() == vue._soleil
		and is_equal_approx(disque.light_angular_distance, 2.0) and is_equal_approx(disque.light_energy, 4.0),
		"au Play test, le disque solaire se voit : 2°, éclat 4, enfant du soleil, ciel seulement")
	(ed._controles_rendu["soleil_disque_taille"] as HSlider).value = 6.0
	(ed._controles_rendu["soleil_disque_eclat"] as HSlider).value = 9.0
	_vrai(is_equal_approx(disque.light_angular_distance, 6.0) and is_equal_approx(disque.light_energy, 9.0)
		and is_equal_approx(vue._soleil.light_angular_distance, 0.0),
		"les curseurs règlent le disque (6°, éclat 9), jamais l'angle du vrai soleil : les ombres ne changent pas")
	(ed._controles_rendu["soleil_disque"] as CheckButton).button_pressed = false
	_vrai(not disque.visible, "décocher « Sun disk in the sky » le cache")
	(ed._controles_rendu["soleil_disque"] as CheckButton).button_pressed = true
	(ed._controles_rendu["ssao"] as CheckButton).button_pressed = false
	(ed._controles_rendu["sdfgi"] as CheckButton).button_pressed = true
	(ed._controles_rendu["soleil_hauteur"] as HSlider).value = 20.0
	(ed._controles_rendu["tonemap"] as OptionButton).select(3)
	(ed._controles_rendu["tonemap"] as OptionButton).item_selected.emit(3)
	(ed._controles_rendu["brouillard"] as CheckButton).button_pressed = true
	_vrai(not env.ssao_enabled and env.sdfgi_enabled, "décocher SSAO l'éteint, cocher SDFGI l'allume")
	_vrai(is_equal_approx(vue._soleil.rotation_degrees.x, -20.0), "le curseur de hauteur couche le soleil à 20°")
	_vrai(env.tonemap_mode == Environment.TONE_MAPPER_ACES and env.fog_enabled, "ACES choisi, brouillard allumé")
	ed._remettre_le_rendu()
	_vrai(env.ssao_enabled and not env.sdfgi_enabled and not env.fog_enabled
		and is_equal_approx(vue._soleil.rotation_degrees.x, vue.SOLEIL_ROTATION.x)
		and env.tonemap_mode == Environment.TONE_MAPPER_LINEAR, "Reset rend les valeurs décidées")
	_vrai(not (ed._controles_rendu["ssao"] as CheckButton).button_pressed == false
		and is_equal_approx((ed._controles_rendu["soleil_hauteur"] as HSlider).value, -vue.SOLEIL_ROTATION.x),
		"… et les contrôles les montrent")
	# Quitter le Play test avec des réglages changés : le travail retrouve SON éclairage.
	(ed._controles_rendu["ssao"] as CheckButton).button_pressed = false
	(ed._controles_rendu["sdfgi"] as CheckButton).button_pressed = true
	(ed._controles_rendu["soleil_energie"] as HSlider).value = 3.0
	ed._aller_a("monde")
	_vrai(env.ssao_enabled and not env.sdfgi_enabled and not env.glow_enabled
		and is_equal_approx(vue._soleil.light_energy, vue.SOLEIL_ENERGIE), "de retour dans World : l'éclairage du travail")
	_vrai(not vue._disque_solaire.visible, "… et pas de disque solaire (il marquerait les reflets des métaux)")
	ed._remettre_le_rendu()


## LA MÉTÉO DU PLAY TEST (Jordan, 2 octobre 2026), menée par la liste déroulante. Attendus écrits à la main (les
## nombres de particules et les brouillards choisis, recopiés ici, pas lus dans la vue).
func _la_meteo(ed: Control) -> void:
	var vue = ed._vue
	var env: Environment = vue._env
	vue._cible = Vector3(62.5, 2.0, 62.5)
	ed._aller_a("jeu")
	await process_frame
	var choix: OptionButton = ed._choix_meteo
	var noms: Array = []
	for i in choix.item_count:
		noms.append(choix.get_item_text(i))
	_egal(noms, ["None", "Rain", "Blizzard", "Hurricane", "Slow snow", "Hanging particles", "Heat", "Fog"],
		"la météo propose les huit temps demandés")
	_vrai(choix.get_parent().get_children().any(func(n): return n is Label and n.text.contains("not exported")),
		"l'écran dit que la météo n'est pas exportée")
	_vrai(vue._meteo_noeud == null and not env.fog_enabled, "None : ni particules ni brouillard")
	choix.select(1)
	choix.item_selected.emit(1)
	var gouttes: Array = vue._meteo_noeud.get_children() if vue._meteo_noeud != null else []
	_vrai(gouttes.size() == 1 and gouttes[0] is GPUParticles3D and (gouttes[0] as GPUParticles3D).amount == 9000,
		"Rain : 9 000 gouttes autour de l'œil")
	_vrai(env.fog_enabled and is_equal_approx(env.fog_density, 0.02), "Rain : un brouillard léger (0,02)")
	_vrai(is_equal_approx(vue._soleil.light_energy, 1.15 * 0.45), "Rain : le soleil réglé (1,15) à 45 %")
	_vrai(is_equal_approx(vue._disque_solaire.light_energy, 4.0 * 0.45), "Rain : le disque solaire voilé de même (4 × 45 %)")
	# L'ŒIL BOUGE (le personnage déplacé de 6 cases) : la boîte d'émission le suit.
	var depart_oeil: Vector3 = vue._camera.global_position
	vue.personnage.global_position += Vector3(6, 0, 0)
	for i in 30:
		await physics_frame
		await process_frame
	_vrai(vue._camera.global_position.distance_to(depart_oeil) > 3.0 and vue._meteo_noeud != null
		and vue._meteo_noeud.global_position.distance_to(vue._camera.global_position) < 0.01,
		"l'œil a bougé, les gouttes le suivent")
	choix.select(6)
	choix.item_selected.emit(6)
	_vrai(vue._meteo_noeud != null and vue._meteo_noeud.get_child_count() == 1 and is_equal_approx(env.fog_density, 0.018)
		and is_equal_approx(vue._soleil.light_energy, 1.15 * 1.2), "Heat : des poussières qui montent, une brume chaude, un soleil plus fort")
	# UN SEUL ENDROIT DÉCIDE DU BROUILLARD : la météo l'emporte sur celui de la barre de rendu (0,01) — la brume de
	# Heat (0,018), puis Fog (0,07) — et None rend celui de la barre.
	(ed._controles_rendu["brouillard"] as CheckButton).button_pressed = true
	_vrai(env.fog_enabled and is_equal_approx(env.fog_density, 0.018), "cocher le brouillard de la barre sous Heat : la brume de Heat reste")
	choix.select(7)
	choix.item_selected.emit(7)
	_vrai(is_equal_approx(env.fog_density, 0.07), "Fog l'emporte sur le brouillard de la barre (0,07)")
	choix.select(0)
	choix.item_selected.emit(0)
	_vrai(env.fog_enabled and is_equal_approx(env.fog_density, 0.01) and vue._meteo_noeud == null,
		"None rend le brouillard de la barre, et retire les particules")
	(ed._controles_rendu["brouillard"] as CheckButton).button_pressed = false
	# Retenue le temps de la session : quitter, revenir.
	choix.select(2)
	choix.item_selected.emit(2)
	ed._aller_a("monde")
	_vrai(vue._meteo_noeud == null and not env.fog_enabled and is_equal_approx(vue._soleil.light_energy, 1.15),
		"hors du Play test : ni météo ni brouillard, le soleil du travail")
	ed._aller_a("jeu")
	_vrai(vue._meteo_noeud != null and is_equal_approx(env.fog_density, 0.08), "de retour au Play test : le blizzard revient")
	ed._remettre_le_rendu()
	_vrai(vue._meteo_noeud == null and choix.selected == 0, "Reset : plus de météo")
	ed._aller_a("monde")


## LA NAGE AU PLAY TEST (Jordan, 1er octobre 2026), dans la cuvette d'au-dessus : nappe à 2,7 (rangée 2 + 0,7),
## donc flottaison les pieds à 2,7 − 0,55 × 0,65 = 2,34 (la taille par défaut) ; le fond se voit à 0,75. Attendus
## écrits à la main.
func _la_nage(ed: Control) -> void:
	# ⚠ LE LAC EST DE LA LAVE pour cette plongée : le voile vu de dedans est celui du liquide (2 octobre 2026).
	var preset_avant: String = ed._eaux[0]["preset"]
	ed._eaux[0]["preset"] = "lave"
	ed._vue._cible = Vector3(62.5, 2.0, 62.5)
	ed._aller_a("jeu")
	var p: CharacterBody3D = ed._vue.personnage
	_vrai(p != null and not ed._vue.eau_du_jeu.is_empty(), "Play test : l'eau du monde est donnée au jeu")
	if p == null:
		return
	p.global_position = Vector3(62.5, 1.6, 62.5)
	for i in 120:
		await physics_frame
	_vrai(p.nage and absf(p.global_position.y - 2.34) < 0.1,
		"tombé dans le lac, il NAGE et flotte la tête hors de l'eau (pieds à %.2f, attendu 2,34)" % p.global_position.y)
	_vrai(not p.is_on_floor(), "… sans toucher le fond")
	# PLONGER : la touche de descente du vol (A en AZERTY, Q en QWERTY) ; sous la nappe, la caméra se voile.
	# La caméra à hauteur de tête et tout près (la cuvette n'a que 3 cases de large : à 4 cases, elle serait
	# au-dessus du mur), comme d'un glissé et d'un coup de molette.
	ed._vue._elevation = 0.0
	ed._vue._distance = 1.0
	_touche_physique(KEY_Q, true)
	var fond := p.global_position.y
	var voile := false
	var couleur_du_voile := Color.BLACK
	for i in 60:
		await physics_frame
		await process_frame
		fond = minf(fond, p.global_position.y)
		voile = voile or ed._vue._env.fog_enabled
		if ed._vue._env.fog_enabled:
			couleur_du_voile = ed._vue._env.fog_light_color
	_touche_physique(KEY_Q, false)
	_vrai(couleur_du_voile.is_equal_approx(Color("#ff5a10")),
		"sous une nappe de LAVE, le voile est orange (%s)" % couleur_du_voile)
	_vrai(fond < 1.4, "A (Q en QWERTY) le fait plonger (pieds à %.2f)" % fond)
	_vrai(voile, "sous la nappe, la caméra voit à travers le voile de l'eau")
	_vrai(p.nage, "au fond, il nage encore (il ne marche pas sur le fond du lac)")
	ed._vue._elevation = ed._vue.CAMERA_ELEVATION
	ed._vue._distance = ed._vue.CAMERA_DISTANCE * ed._vue.taille_personnage
	for i in 90:
		await physics_frame
		await process_frame
	_vrai(absf(p.global_position.y - 2.34) < 0.1, "relâché, il remonte à la surface (%.2f)" % p.global_position.y)
	_vrai(not ed._vue._env.fog_enabled, "la tête hors de l'eau, plus de voile")
	# NAGER plus lentement qu'on ne marche.
	ed._vue._azimut = PI / 2   # « en avant » = −X : vers le mur ouest, à deux cases
	_touche_physique(KEY_W, true)
	for i in 20:
		await physics_frame
	var v := Vector2(p.velocity.x, p.velocity.z).length()
	_vrai(v > 0.8 and v <= 2.2 * 0.65 + 0.01, "il nage à sa taille, moins vite qu'il ne marche (%.2f)" % v)
	# SE HISSER : il nage contre le mur ouest (x = 60, dessus à 2,75) et en sort.
	for i in 150:
		await physics_frame
	_touche_physique(KEY_W, false)
	# ⚠ « x < 61 » NE PROUVAIT RIEN (mutation muette) : la face amincie du mur est en 60,75, et en nageant contre
	# elle il arrive en 60,94 sans s'être hissé. Il faut qu'il ait FRANCHI le mur.
	_vrai(p.global_position.x < 60.3,
		"contre la berge, il se hisse et franchit le mur (x = %.2f, le mur est en x = 60..61)" % p.global_position.x)
	# LE COURANT D'UNE RIVIÈRE (3 octobre 2026) : debout, sans toucher à rien, sur des cases qui portent un courant
	# vers +Z, il dérive vers +Z ; sans courant, il reste.
	for i in 30:
		await physics_frame
	var depart := p.global_position
	var sous := Vector3i(floori(depart.x), floori(depart.y + 0.3), floori(depart.z))
	var courants := {}
	for dx in range(-3, 4):
		for dz in range(-3, 6):
			courants[sous + Vector3i(dx, 0, dz)] = Vector2(0, 1)
	ed._vue.eau_du_jeu["courants"] = courants
	for i in 60:
		await physics_frame
	var derive := p.global_position - depart
	_vrai(p.is_on_floor() and derive.z > 0.8 and absf(derive.x) < 0.2,
		"sur le courant d'une rivière, il dérive dans son sens (%.2f, %.2f)" % [derive.x, derive.z])
	ed._vue.eau_du_jeu["courants"] = {}
	depart = p.global_position
	for i in 30:
		await physics_frame
	_vrai((p.global_position - depart).length() < 0.1, "sans courant, il reste où il est")
	ed._aller_a("monde")
	_vrai(not ed._vue._env.fog_enabled, "hors du jeu, jamais de voile")
	ed._eaux[0]["preset"] = preset_avant


## LA SALLE (Jordan, 2 octobre 2026), menée par un VRAI glissé de souris sur la grille de l'étage 0, dans un coin vide
## (x 100..104, z 100..103). Attendus écrits à la main : 2 étages vers le haut → y 0..3, une boîte 5 × 4 × 4 = 80
## cases dont le dedans 3 × 2 × 2 = 12 reste vide : 68 cases posées ; vers le bas, le rectangle est le plafond (y −3..0).
var _salle_finie := false


func _glisser(vue: Control, de: Vector2, a: Vector2) -> void:
	var appui := InputEventMouseButton.new()
	appui.button_index = MOUSE_BUTTON_LEFT
	appui.position = de
	appui.pressed = true
	vue._gui_input(appui)
	var mouvement := InputEventMouseMotion.new()
	mouvement.position = a
	mouvement.button_mask = MOUSE_BUTTON_MASK_LEFT
	vue._gui_input(mouvement)
	var lache := InputEventMouseButton.new()
	lache.button_index = MOUSE_BUTTON_LEFT
	lache.position = a
	lache.pressed = false
	vue._gui_input(lache)


func _la_salle(ed: Control) -> void:
	var vue = ed._vue
	var g: GridMap = vue.cases()
	ed._aller_a("monde")
	ed._choisir_forme_speciale("salle")
	_vrai(vue.outil == "forme" and ed._ligne_salle.visible and not ed._ligne_taille_forme.visible
		and not ed._ligne_bouts.visible and not ed._ligne_profil.visible and not ed._garde_corps.visible
		and not ed._ligne_longueur.visible, "Room : ses étages et son sens, rien d'autre")
	vue.regler_etage(0)
	ed._etages_forme.value = 2
	var avant := g.get_used_cells().size()
	_viser_d_en_haut(vue, Vector3(102.5, 0.0, 101.5))
	var coin_a: Vector2 = vue._camera.unproject_position(Vector3(100.5, 0.0, 100.5))
	var coin_b: Vector2 = vue._camera.unproject_position(Vector3(104.5, 0.0, 103.5))
	_glisser(vue, coin_a, coin_b)
	_egal(g.get_used_cells().size(), avant + 68, "un glissé de (100,100) à (104,103), 2 étages : 68 cases de coque")
	_vrai(g.get_cell_item(Vector3i(102, 1, 101)) == -1 and g.get_cell_item(Vector3i(102, 2, 102)) == -1
		and g.get_cell_item(Vector3i(100, 0, 100)) != -1 and g.get_cell_item(Vector3i(102, 3, 101)) != -1
		and g.get_cell_item(Vector3i(104, 2, 101)) != -1, "… creuse dedans, avec son sol, son plafond et ses murs")
	_vrai(ed._rapport.text.contains("Room"), "… et l'écran le dit")
	ed._histoire.undo()
	_egal(g.get_used_cells().size(), avant, "UN Ctrl+Z l'enlève")
	(ed._boutons_sens_salle["bas"] as Button).pressed.emit()
	_vrai(not bool(vue.forme_speciale["vers_le_haut"]) and ed._aide_forme.text.contains("sinks"), "Down : elle descendra")
	_glisser(vue, coin_a, coin_b)
	_vrai(g.get_cell_item(Vector3i(100, -3, 100)) != -1 and g.get_cell_item(Vector3i(102, -1, 101)) == -1
		and g.get_cell_item(Vector3i(102, 0, 101)) != -1, "vers le bas : de y = −3 à 0, le rectangle est le plafond")
	ed._histoire.undo()
	(ed._boutons_sens_salle["haut"] as Button).pressed.emit()
	# Trop petite : 2 cases de large, rien ne change, l'écran dit pourquoi.
	_glisser(vue, coin_a, vue._camera.unproject_position(Vector3(101.5, 0.0, 103.5)))
	_vrai(g.get_used_cells().size() == avant and ed._rapport.text.contains("3 × 3"),
		"une salle de 2 cases de large est refusée, et l'écran dit pourquoi")
	ed._unhandled_key_input(_cle(KEY_BRACKETRIGHT))
	_egal(int(vue.forme_speciale["etages"]), 3, "] ajoute un étage à la salle")
	ed._choisir_outil("ajouter")
	_vrai(not ed._reglages_forme.visible, "revenir à Add cache les réglages de la salle")
	_salle_finie = true


## LE LASSO ET LE CERCLE DU MODELEUR (Jordan, 2 octobre 2026), menés par de VRAIS événements de souris dans la vue.
## ⚠ L'ATTENDU NE PASSE PAS PAR LE MODELEUR : en X-ray (rien de caché), on projette soi-même chaque sommet par la
## caméra et on le juge dans le triangle ou le disque tracés. Sans X-ray, on garde seulement « moins que tout ».
var _lasso_fini := false


## ── LES COUCHES EXCLUSIVES (Jordan, 2 octobre 2026 : « cases exclusives avec priorité par l'ordre ») ──────────────
## Une case n'appartient qu'à une couche ; le choix des tuiles lit l'union des couches VISIBLES ; un sommet est posé
## par la couche de plus petit rang parmi ses huit cases.
## ⚠ L'ATTENDU NE PASSE NI PAR `MB.couche_du_sommet` NI PAR L'UNION DE L'ÉCRAN : on relit les GRILLES des couches,
## on bâtit sa propre union, et un sommet à surface est celui dont les huit cases ne sont ni toutes vides ni toutes
## pleines.
var _exclusives_finies := false


## {couche: {sommet: true}} attendu, et {couche: {sommet: true}} posé (décisions non vides de chaque massif).
func _proprietaires(ed: Control, couches: Array) -> Array:
	var union := {}
	for i in range(ed._vue.nombre_de_couches() - 1, -1, -1):
		var m := ed._vue.couche(i) as Node3D
		if m.visible:
			for c in (m.get_node("Cases") as GridMap).get_used_cells():
				union[c] = i
	var attendu := {}
	var pose := {}
	for k in couches:
		attendu[k] = {}
		pose[k] = {}
		for s in ed._vue.couche(k)._etat:
			if not (ed._vue.couche(k)._etat[s] as Dictionary).is_empty():
				pose[k][s] = true
	var vus := {}
	for c in union:
		for dx in 2:
			for dy in 2:
				for dz in 2:
					var s: Vector3i = c - Vector3i(dx, dy, dz)
					if vus.has(s):
						continue
					vus[s] = true
					var pleines := 0
					var rang := 1 << 30
					for ex in 2:
						for ey in 2:
							for ez in 2:
								var q := s + Vector3i(ex, ey, ez)
								if union.has(q):
									pleines += 1
									rang = mini(rang, union[q])
					if pleines > 0 and pleines < 8 and attendu.has(rang):
						attendu[rang][s] = true
	return [attendu, pose]


func _memes_proprietaires(ed: Control, couches: Array, quoi: String) -> void:
	var r := _proprietaires(ed, couches)
	for k in couches:
		_egal(r[1][k].size(), r[0][k].size(), "%s : la couche %d pose %d sommets à surface" % [quoi, k, r[0][k].size()])
		var memes := true
		for s in r[0][k]:
			memes = memes and r[1][k].has(s)
		_vrai(memes, "%s : … exactement ceux dont elle est la propriétaire" % quoi)


func _les_couches_exclusives(ed: Control) -> void:
	ed._aller_a("monde")
	ed._nouvelle_couche()
	var ia: int = ed._active
	ed._nouvelle_couche()
	var ib: int = ed._active
	var ga := ed._vue.couche(ia).get_node("Cases") as GridMap
	var gb := ed._vue.couche(ib).get_node("Cases") as GridMap
	var bloc_a := {}
	var bloc_b := {}
	for x in range(200, 204):
		for y in 2:
			for z in 4:
				bloc_a[Vector3i(x, y, z)] = true
	for x in range(202, 206):
		for y in 2:
			for z in 4:
				bloc_b[Vector3i(x, y, z)] = true
	ed._activer(ia)
	ed._appliquer({"poser": bloc_a, "effacer": {}}, "Add")
	ed._activer(ib)
	ed._appliquer({"poser": bloc_b, "effacer": {}}, "Add")
	_egal(ga.get_used_cells().size(), 16, "peindre B sur la moitié de A : A perd les 16 cases que B a prises")
	_egal(gb.get_used_cells().size(), 32, "… et B les a toutes")
	var doublees := 0
	for c in gb.get_used_cells():
		if ga.get_cell_item(c) != GridMap.INVALID_CELL_ITEM:
			doublees += 1
	_egal(doublees, 0, "aucune case dans deux couches")
	# SANS FENTE : la frontière A|B ne porte aucune paroi (les huit cases d'un sommet de frontière sont pleines).
	_memes_proprietaires(ed, [ia, ib], "après le vol")
	# LA LISTE RECOMPTE : la couche volée dit ce qu'il lui reste.
	await process_frame
	var textes: Array = []
	for ligne in ed._liste_couches.get_children():
		if not ligne.is_queued_for_deletion():
			textes.append((ligne.get_child(2) as Button).text)
	_vrai(textes.size() > ib and textes[ia].contains("16 cells") and textes[ib].contains("32 cells"),
		"la liste des couches recompte, couche volée comprise — %s" % [textes.slice(ia, ib + 1) if textes.size() > ib else textes])
	ed._histoire.undo()
	_egal(ga.get_used_cells().size(), 32, "UN Ctrl+Z rend à A les cases que B lui avait prises")
	_egal(gb.get_used_cells().size(), 0, "… et retire celles de B")
	_memes_proprietaires(ed, [ia, ib], "après Ctrl+Z")
	ed._histoire.redo()
	_egal(ga.get_used_cells().size(), 16, "Ctrl+Y reprend")
	_memes_proprietaires(ed, [ia, ib], "après Ctrl+Y")

	# UN COUP DE PINCEAU vole aussi, dans le même Ctrl+Z.
	ed._activer(ia)
	ed._coup_commence()
	ed._touche({"poser": {Vector3i(204, 0, 0): true, Vector3i(205, 0, 0): true}, "effacer": {}}, "Add")
	ed._touche({"poser": {Vector3i(205, 1, 0): true}, "effacer": {}}, "Add")
	ed._coup_fini()
	_egal(gb.get_used_cells().size(), 29, "un coup dans A prend trois cases à B")
	_egal(ga.get_used_cells().size(), 19, "… et A les a")
	_memes_proprietaires(ed, [ia, ib], "après le coup")
	ed._histoire.undo()
	_vrai(gb.get_used_cells().size() == 32 and ga.get_used_cells().size() == 16, "UN Ctrl+Z défait le coup dans les deux couches")
	_memes_proprietaires(ed, [ia, ib], "après Ctrl+Z du coup")

	# LA RECONSTRUCTION LOCALE = LA COMPLÈTE, pour chaque couche (une case de B change les sommets de frontière de A).
	var avant := {}
	for k in [ia, ib]:
		avant[k] = (ed._vue.couche(k)._etat as Dictionary).duplicate(true)
		ed._vue.couche(k).reconstruire()
	for k in [ia, ib]:
		_vrai(ed._vue.couche(k)._etat == avant[k], "la couche %d tenue par morceaux = reconstruite en entier" % k)

	# UNE COUCHE CACHÉE sort de l'union : le monde se referme sans elle.
	# ⚠ CACHER NE REFAIT PLUS TOUT (2 octobre 2026) : seule A se refait, autour des cases de B ; B, invisible, garde
	# son état (on ne la voit pas, le Play test la saute) et se refait en reparaissant, autour de ce qui a changé.
	ed._montrer_couche(ib, false)
	_vrai(not (ed._vue.couche(ib) as Node3D).visible, "B cachée : invisible")
	_memes_proprietaires(ed, [ia], "B cachée")
	# Pendant qu'elle est cachée, on peint dans A, contre la frontière : B devra s'en refaire en reparaissant.
	ed._activer(ia)
	ed._appliquer({"poser": {Vector3i(204, 2, 1): true, Vector3i(205, 2, 2): true}, "effacer": {}}, "Add")
	ed._montrer_couche(ib, true)
	_memes_proprietaires(ed, [ia, ib], "B remontrée")
	for k in [ia, ib]:
		var tenu := (ed._vue.couche(k)._etat as Dictionary).duplicate(true)
		ed._vue.couche(k).reconstruire()
		_vrai(ed._vue.couche(k)._etat == tenu, "B remontrée : la couche %d refaite par morceaux = reconstruite en entier" % k)
	# Second tour : cachée, puis l'union refaite entière (ce que font supprimer, déplacer, ouvrir) — B n'y est pas
	# refaite ; en reparaissant elle doit l'être EN ENTIER.
	ed._montrer_couche(ib, false)
	ed._appliquer({"poser": {Vector3i(204, 2, 3): true}, "effacer": {}}, "Add")
	ed._refaire_l_union()
	ed._montrer_couche(ib, true)
	_memes_proprietaires(ed, [ia, ib], "B remontrée après l'union refaite")
	# ⚠ UNE COUCHE CACHÉE APPREND QU'UNE AUTRE SE CACHE (6 octobre 2026, trouvé par `test_natif` §11) : B cachée, puis A
	# cachée, puis B montrée seule — ses sommets de frontière, que A (prioritaire) posait, sont désormais à elle. Deux
	# blocs voisins posés pour l'épreuve, puis rendus par deux Ctrl+Z. Éprouvé sur la route de chaque couche (sans le
	# monde du cœur, qui tient l'union entière et n'a pas ce défaut), puis avec.
	ed._activer(ia)
	var bloc_a2 := {}
	var bloc_b2 := {}
	for x in 3:
		for z in 3:
			bloc_a2[Vector3i(300 + x, 0, z)] = true
			bloc_b2[Vector3i(303 + x, 0, z)] = true
	ed._appliquer({"poser": bloc_a2, "effacer": {}}, "Add")
	ed._activer(ib)
	ed._appliquer({"poser": bloc_b2, "effacer": {}}, "Add")
	for avec_le_monde in [false, true]:
		# Sans le monde : le natif éteint le temps de l'épreuve (le monde de l'écran est refait en le rallumant).
		Natif.actif = avec_le_monde
		ed._monde_coeur = null
		ed._refaire_l_union()
		_vrai((ed._vue.couche(ib).monde != null) == (avec_le_monde and Natif.disponible()),
			"la couche est branchée au monde du cœur seulement quand on l'éprouve avec lui")
		var etat_b_avant := (ed._vue.couche(ib)._etat as Dictionary).size()
		ed._montrer_couche(ib, false)
		ed._montrer_couche(ia, false)
		ed._montrer_couche(ib, true)
		var tenu_b := (ed._vue.couche(ib)._etat as Dictionary).duplicate(true)
		ed._vue.couche(ib).reconstruire()
		var quoi := "le monde du cœur" if avec_le_monde else "sans le monde"
		_vrai(ed._vue.couche(ib)._etat == tenu_b and tenu_b.size() > etat_b_avant,
			"%s : B montrée seule après A cachée = reconstruite en entier, et elle pose la frontière (%d > %d)"
			% [quoi, tenu_b.size(), etat_b_avant])
		ed._montrer_couche(ia, true)
		for k in [ia, ib]:
			var tenu := (ed._vue.couche(k)._etat as Dictionary).duplicate(true)
			ed._vue.couche(k).reconstruire()
			_vrai(ed._vue.couche(k)._etat == tenu, "%s : A remontrée, la couche %d = reconstruite en entier" % [quoi, k])
	Natif.actif = true
	ed._histoire.undo()
	ed._histoire.undo()
	ed._histoire.undo()
	ed._histoire.undo()
	ed._activer(ib)
	# ↑ ↓ : B passe AU-DESSUS de A par le vrai bouton — la frontière change de propriétaire, un Ctrl+Z le rend.
	var nom_a: String = ed._couches[ia]["nom"]
	var nom_b: String = ed._couches[ib]["nom"]
	ed._activer(ib)
	_vrai(not ed._bouton_monter_couche.disabled and ed._bouton_descendre_couche.disabled,
		"la dernière couche : Up actif, Down grisé")
	var etat_a_avant := (ed._vue.couche(ia)._etat as Dictionary).size()
	var glisses_avant: int = ed.glissements_au_monde
	ed._transitions._a_poser_table = false
	ed._bouton_monter_couche.pressed.emit()
	# UP / DOWN BRANCHÉ (6 octobre 2026) : avec le cœur, le monde déplace la couche sans rien reconstruire.
	_vrai(MB.natif() == null or ed.glissements_au_monde == glisses_avant + 1,
		"avec le cœur, Up passe par le monde (`_renumeroter_l_union`) : %d" % (ed.glissements_au_monde - glisses_avant))
	# Les transitions lisent les rangs : Up doit les prévenir, par les deux routes (trouvé par le devlog Transitions).
	_vrai(ed._transitions._a_poser_table, "Up : les transitions savent que les rangs ont changé")
	_vrai(ed._active == ia and ed._couches[ia]["nom"] == nom_b and ed._couches[ib]["nom"] == nom_a
		and ed._vue.couche(ia).get_node("Cases") == gb, "Up : B prend la place de A, et reste active")
	_memes_proprietaires(ed, [ia, ib], "B montée")
	var r_monte := _proprietaires(ed, [ia, ib])
	_vrai((r_monte[1][ia] as Dictionary).size() > 0 and ed._vue.couche(ib)._etat.size() != etat_a_avant,
		"… et la frontière a changé de propriétaire")
	ed._histoire.undo()
	_vrai(ed._couches[ia]["nom"] == nom_a and ed._vue.couche(ia).get_node("Cases") == ga, "Ctrl+Z remet les couches dans leur ordre")
	_memes_proprietaires(ed, [ia, ib], "ordre rendu")
	ed._activer(ia)
	ed._bouton_descendre_couche.pressed.emit()
	_vrai(ed._couches[ib]["nom"] == nom_a and ed._active == ib, "Down : A descend sous B")
	_memes_proprietaires(ed, [ia, ib], "A descendue")
	ed._histoire.undo()
	_vrai(ed._couches[ia]["nom"] == nom_a, "Ctrl+Z la remonte")
	# LA PRIORITÉ SUIT L'ORDRE : supprimer A fait monter B d'un rang, et B pose désormais tout son bord.
	ed._activer(ia)
	ed._supprimer_couche()
	var ib2: int = ib - 1
	_memes_proprietaires(ed, [ib2], "A supprimée")
	ed._histoire.undo()
	_memes_proprietaires(ed, [ia, ib], "A rendue")

	# UN PROJET D'AVANT : une case dans deux couches — la plus haute la garde, et l'écran le dit.
	var vieux := "user://fumee/chevauche.mbproj"
	var haut := Projet.couche("Top")
	haut["cases"] = {Vector3i(0, 0, 0): true, Vector3i(1, 0, 0): true}
	var bas := Projet.couche("Under")
	bas["cases"] = {Vector3i(1, 0, 0): true, Vector3i(2, 0, 0): true, Vector3i(0, 0, 0): true}
	var f := FileAccess.open(vieux, FileAccess.WRITE)
	f.store_string(Projet.vers_texte([haut, bas], 0))
	f.close()
	await ed._ouvrir(vieux)
	_egal((ed._vue.couche(0).get_node("Cases") as GridMap).get_used_cells().size(), 2, "ouverture : la couche du haut garde ses cases")
	_egal((ed._vue.couche(1).get_node("Cases") as GridMap).get_used_cells(), [Vector3i(2, 0, 0)],
		"… celle du dessous perd les deux qu'elle partageait")
	_vrai(ed._rapport.text.contains("2 cell(s) belonged to several layers"), "et l'écran le dit")
	_memes_proprietaires(ed, [0, 1], "à l'ouverture")
	_exclusives_finies = true


## LES DEMANDES DU 3 OCTOBRE 2026 (Jordan) — par de vrais clics et les vrais boutons, attendus écrits à la main :
## peindre une sélection DANS LE VIDE ; Extend up / down d'un bouton ; une rivière large à la pose ; l'image
## choisie copiée dans le projet.
var _demandes_finies := false


func _les_demandes_du_3_octobre(ed: Control) -> void:
	const Peinture := preload("res://addons/marchingblocks_core/peinture.gd")
	var vue: Control = ed._vue
	ed._aller_a("monde")
	ed._choisir_visee("grille")
	ed._compteur_etage.value = 0
	ed._choisir_outil("selectionner")
	_vrai(ed._case_vides.visible, "Select : la case « Select empty cells too » se montre")
	vue.taille = 1
	vue.forme = "cube"
	vue.vider_selection()
	_viser_depuis(vue, Vector3(80.5, 0.0, 80.5), 0.6, 12.0)
	vue._elevation = 0.9
	vue._caler()
	await process_frame
	var ou: Vector2 = vue._camera.unproject_position(Vector3(80.5, 0.0, 80.5))
	_clic_vue(vue, ou)
	_vrai(vue.selection.is_empty(), "sans la case, le pinceau Select ne prend pas l'air")
	ed._case_vides.button_pressed = true
	_clic_vue(vue, ou)
	_vrai(vue.selection.has(Vector3i(80, 0, 80)) and vue.selection.size() == 1,
		"avec la case, un clic sur la grille sélectionne la case VIDE visée (%s)" % [vue.selection.keys()])
	var cases_avant: int = vue.cases().get_used_cells().size()
	var etendre := func(texte: String) -> void:
		for b in ed._section_selection.find_children("*", "Button", true, false):
			if (b as Button).text == texte:
				(b as Button).pressed.emit()
				return
		_vrai(false, "le bouton « %s » existe" % texte)
	etendre.call("Extend selection ↑")
	etendre.call("Extend selection ↑")
	_vrai(vue.selection.size() == 3 and vue.selection.has(Vector3i(80, 2, 80))
		and vue.cases().get_used_cells().size() == cases_avant, "Extend selection ↑ ×2 : la sélection monte de deux, rien n'est posé")
	etendre.call("Extend selection ↓")
	_vrai(vue.selection.has(Vector3i(80, -1, 80)) and vue.selection.size() == 4, "Extend selection ↓ : une de plus en dessous")
	ed._operer_selection("remplir")
	_vrai(vue.cases().get_used_cells().size() == cases_avant + 4, "Fill la remplit : une colonne de 4 cases peinte dans l'air")
	ed._histoire.undo()
	# ROOM FROM SELECTION : le L de 21 cases de `test_formes_speciales`, sélectionné loin de tout (y = 60), 2 étages vers
	# le haut — 72 cases de coque et 4 de réparation, comptées à la main là-bas ; par le vrai bouton, une annulation.
	vue.vider_selection()
	var l := {}
	for x in 5:
		for z in 3:
			l[Vector3i(200 + x, 60, z)] = true
	for x in 3:
		for z in range(3, 5):
			l[Vector3i(200 + x, 60, z)] = true
	vue.regler_selection(l)
	ed._etages_selection.value = 2
	_vrai(int(vue.forme_speciale["etages"]) == 2 and int(ed._etages_forme.value) == 2,
		"les étages de « Room from selection » sont ceux de la forme Room (synchronisés)")
	(ed._sens_selection["haut"] as Button).pressed.emit()
	var avant_salle: int = vue.cases().get_used_cells().size()
	etendre.call("Room from selection")
	_vrai(vue.cases().get_used_cells().size() == avant_salle + 76 and vue.cases().get_cell_item(Vector3i(201, 61, 1)) == -1
		and vue.cases().get_cell_item(Vector3i(200, 61, 0)) != -1,
		"Room from selection : le L devient une salle de 76 cases, creuse dedans (%d)" % (vue.cases().get_used_cells().size() - avant_salle))
	ed._histoire.undo()
	_vrai(vue.cases().get_used_cells().size() == avant_salle, "UN Ctrl+Z la retire entière")
	vue.vider_selection()
	etendre.call("Room from selection")
	_vrai(ed._rapport.text.contains("Nothing selected"), "sans sélection, le bouton le dit")
	ed._case_vides.button_pressed = false
	ed._choisir_outil("ajouter")
	_vrai(not ed._case_vides.visible, "hors de Select, la case se cache")
	vue.vider_selection()
	# LA RIVIÈRE LARGE : la marche de `test_fluides` (x = 100..102 haute de 3, 103..105 de 1, z = −3..3, mur en 99).
	var marche := {}
	for x in range(99, 106):
		for z in range(-3, 4):
			var h := 5 if x == 99 else (3 if x <= 102 else 1)
			for y in h:
				marche[Vector3i(x, y, z)] = true
	ed._appliquer({"poser": marche, "effacer": {}}, "Add")
	ed._occ_eau = {}
	ed._largeur_eau.value = 3
	var e_avant: int = 0 if ed._eaux.is_empty() else (ed._eaux[ed._eau_active]["sources"] as Array).size()
	ed._eau_cliquee(Vector3i(100, 3, 0), MOUSE_BUTTON_LEFT)
	var srcs: Array = ed._eaux[ed._eau_active]["sources"]
	_vrai(srcs.size() == e_avant + 3 and srcs.slice(e_avant) == [Vector3i(100, 3, 0), Vector3i(100, 3, -1), Vector3i(100, 3, 1)],
		"River width 3 : trois sources côte à côte, en travers du courant (%s)" % [srcs.slice(e_avant)])
	ed._histoire.undo()
	_vrai((ed._eaux[ed._eau_active]["sources"] as Array).size() == e_avant, "UN Ctrl+Z les retire toutes")
	ed._largeur_eau.value = 1
	ed._histoire.undo()   # la marche
	ed._occ_eau = {}
	# L'IMAGE CHOISIE EST COPIÉE DANS LE PROJET, avec son ensemble.
	ed._aller_a("texture")
	ed._regler_edition(true)
	ed._nouveau_materiau()
	var biblio := ProjectSettings.globalize_path("user://fumee/bibliotheque")
	DirAccess.make_dir_recursive_absolute(biblio)
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.6, 0.4, 0.3))
	img.save_png(biblio.path_join("pierre_albedo.png"))
	img.fill(Color(0.5, 0.5, 1.0))
	img.save_png(biblio.path_join("pierre_normal.png"))
	ed._action_fichier = "texture"
	ed._fichier_choisi(biblio.path_join("pierre_albedo.png"))
	var k: int = ed._modeleur.materiau_courant
	var tex: String = str(ed._modeleur.maillage.materiaux[k].get("texture", ""))
	var dossier: String = ed._modeleur.dossier_toiles
	_vrai(tex.begins_with(dossier) and tex.ends_with("pierre_albedo/pierre_albedo.png") and FileAccess.file_exists(tex)
		and FileAccess.file_exists(tex.get_base_dir().path_join("pierre_normal.png")),
		"l'image choisie est COPIÉE dans les images de la couche, avec sa normale (%s)" % tex)
	ed._aller_a("monde")
	_demandes_finies = true


## L'EXEMPLE NE S'IMPOSE PAS (Jordan, 2 octobre 2026 : « le soft ne doit pas forcer l'exemple à l'arrivée ») — sans
## l'archive : au lancement, on rouvre le dernier projet qui N'EST PAS l'exemple ; ouvrir l'exemple ne l'efface pas de
## la mémoire ; les boutons My world / Example ne se montrent que dans World, et seulement s'il y a un exemple.
func _l_exemple_ne_s_impose_pas(ed: Control) -> void:
	const Exemple := preload("res://app/exemple.gd")
	var mien: String = ed._projet
	var faux_exemple := RACINE_EXEMPLE.path_join("v0/example.mbproj")
	DirAccess.make_dir_recursive_absolute(faux_exemple.get_base_dir())
	FileAccess.open(faux_exemple, FileAccess.WRITE).store_string("{}")
	_vrai(ed.est_l_exemple(faux_exemple) and ed.est_l_exemple(ProjectSettings.globalize_path(faux_exemple))
		and not ed.est_l_exemple(mien), "est_l_exemple : l'exemple installé l'est, le projet jetable non")
	# L'ANCIENNE PLACE (les données de l'appli, avant le 4 octobre 2026) compte encore ; un dossier qui ne fait que
	# COMMENCER comme celui de l'exemple, non.
	_vrai(ed.est_l_exemple(Exemple.RACINE.path_join("v0/example.mbproj"))
		and not ed.est_l_exemple(RACINE_EXEMPLE + "s/v0/autre.mbproj"),
		"est_l_exemple : l'ancienne place de l'exemple l'est, un dossier voisin au nom plus long non")
	# UN PROJET NEUF VA DANS SON DOSSIER (`Dossiers`, Jordan, 4 octobre 2026) — ici un dossier jetable à la place des
	# Documents.
	const Dossiers := preload("res://app/dossiers.gd")
	var docs := "user://fumee/documents"
	_vider_dossier(docs)
	DirAccess.make_dir_recursive_absolute(docs)
	Dossiers.racine_forcee = docs
	var neuf: String = ed._chemin_libre()
	Dossiers.racine_forcee = ""
	_egal(neuf, docs.path_join("untitled/untitled.mbproj"), "New : le projet neuf naît dans son dossier")
	_vider_dossier(docs)
	var avant := FileAccess.get_file_as_string(REGLAGES)
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", faux_exemple)
	r.save(REGLAGES)
	_vrai(ed._mon_dernier_monde() == "", "un réglage d'avant qui ne retient QUE l'exemple : on n'y retourne pas")
	r.set_value("projet", "monde", mien)
	r.save(REGLAGES)
	_vrai(ed._mon_dernier_monde() == mien, "« monde » retenu : c'est lui qu'on rouvre, pas l'exemple")
	# Ouvrir l'exemple le retient comme « dernier », pas comme « monde ».
	ed._projet = faux_exemple
	ed._retenir_le_projet()
	r.load(REGLAGES)
	_vrai(r.get_value("projet", "dernier", "") == faux_exemple and r.get_value("projet", "monde", "") == mien
		and (ed._choix_monde.get_child(1) as Button).button_pressed, "l'exemple ouvert : retenu comme dernier, PAS comme ton monde ; Example enfoncé")
	ed._projet = mien
	ed._retenir_le_projet()
	r.load(REGLAGES)
	_vrai(r.get_value("projet", "monde", "") == mien and (ed._choix_monde.get_child(0) as Button).button_pressed,
		"ton monde rouvert : retenu, My world enfoncé")
	# ⚠ ILS S'EXCLUENT (Jordan, 2 octobre 2026 : « restent tous les deux cochés ») : `set_pressed_no_signal` ignore le
	# ButtonGroup. Un seul enfoncé, dans les deux sens.
	_vrai(not (ed._choix_monde.get_child(1) as Button).button_pressed, "… et Example relâché")
	ed._projet = faux_exemple
	ed._dire_le_projet()
	_vrai(not (ed._choix_monde.get_child(0) as Button).button_pressed
		and (ed._choix_monde.get_child(1) as Button).button_pressed, "l'exemple : My world relâché, Example enfoncé")
	ed._projet = mien
	ed._dire_le_projet()
	ed._aller_a("monde")
	_vrai(ed._section_choix_monde.visible == Exemple.disponible(), "dans World, les deux boutons s'il y a un exemple (%s)" % Exemple.disponible())
	ed._aller_a("projet")
	_vrai(not ed._section_choix_monde.visible, "hors de World, pas de boutons")
	var f := FileAccess.open(REGLAGES, FileAccess.WRITE)
	f.store_string(avant)
	f.close()
	DirAccess.remove_absolute(faux_exemple)
	DirAccess.remove_absolute(faux_exemple.get_base_dir())


## L'EXEMPLE LIVRÉ (Jordan, 2 octobre 2026) : la VRAIE archive (`res://exemple/exemple.zip`, prise du projet de
## Jordan), ouverte par le bouton. ⚠ L'attendu vient de l'ARCHIVE, relue ici sans l'installeur : chaque couche y
## retrouve ses cases, et ses tuiles — aucune faute, aucun « missing » (un .glb absent donnerait des cubes rouges).
## UNE TEINTE PAR ATELIER (Jordan, 2 octobre 2026) : sa barre de droite et son bouton la portent, le reste garde l'olive.
## ⚠ L'attendu est écrit ICI (rouge pour World, bleu pour Fluids, demandés par Jordan ; six teintes distinctes), puis
## relu sur ce que l'écran a POSÉ : le thème des barres, l'état enfoncé des boutons, l'en-tête d'une section.
func _les_teintes_des_ateliers(ed: Control) -> void:
	const Palette := preload("res://app/palette.gd")
	var rouge: Color = Palette.teinte("monde")
	var bleu: Color = Palette.teinte("fluides")
	_vrai(rouge.r > rouge.g + 0.3 and rouge.r > rouge.b + 0.3, "World est ROUGE (%s)" % rouge.to_html(false))
	_vrai(bleu.b > bleu.r + 0.3 and bleu.b > bleu.g, "Fluids est BLEU (%s)" % bleu.to_html(false))
	var vues := {}
	for a in ["projet", "monde", "fluides", "witness", "texture", "jeu", "feuillage", "variantes"]:
		vues[Palette.teinte(a).to_html(false)] = true
	_egal(vues.size(), 8, "huit ateliers, huit teintes différentes")
	# CE QUI NAÎT PLUS TARD dans une barre (une liste rebâtie) prend sa teinte ; dans la barre de gauche, l'olive reste.
	var tard := Label.new()
	tard.add_theme_color_override("font_color", Palette.OLIVE)
	(ed._droite_fluides.get_meta("pile") as Control).add_child(tard)
	var gauche := Label.new()
	gauche.add_theme_color_override("font_color", Palette.OLIVE)
	ed._section_couches.contenu.add_child(gauche)
	await process_frame
	_vrai(tard.get_theme_color("font_color").is_equal_approx(bleu), "une étiquette olive née PLUS TARD dans Fluids devient bleue")
	_vrai(gauche.get_theme_color("font_color").is_equal_approx(Palette.OLIVE), "… celle de la barre de gauche reste olive")
	tard.queue_free()
	gauche.queue_free()
	_vrai(not vues.has(Palette.OLIVE.to_html(false)), "aucun atelier n'a l'olive de l'écran")
	for b in [[ed._droite, "monde"], [ed._droite_temoin, "witness"], [ed._droite_texture, "texture"],
			[ed._droite_jeu, "jeu"], [ed._droite_fluides, "fluides"], [ed._droite_feuillage, "feuillage"],
			[ed._droite_variantes, "variantes"]]:
		var barre: Control = b[0]
		var a: Color = Palette.teinte(b[1])
		var enfonce := barre.get_theme_stylebox("pressed", "Button") as StyleBoxFlat
		_vrai(enfonce != null and enfonce.bg_color.is_equal_approx(Color(a, 0.2)),
			"la barre de droite de « %s » enfonce ses boutons dans sa teinte" % b[1])
		var entete_teinte := false
		for s in barre.find_children("*", "Button", true, false):
			var bt := s as Button
			if bt.has_theme_color_override("font_color") and bt.get_theme_color("font_color").is_equal_approx(a):
				entete_teinte = true
		_vrai(entete_teinte, "… et ses en-têtes de section la portent (« %s »)" % b[1])
		var bouton: Button = ed._boutons_atelier[b[1]]
		_vrai(bouton.get_theme_color("icon_normal_color").is_equal_approx(a), "le bouton de « %s » porte sa teinte, même au repos" % b[1])
	var gauche_enfonce := ed._gauche.get_theme_stylebox("pressed", "Button") as StyleBoxFlat
	_vrai(gauche_enfonce != null and gauche_enfonce.bg_color.is_equal_approx(Palette.BOUTON_ENFONCE),
		"la barre de gauche garde la palette de l'écran (l'olive)")
	_vrai(ed._section_couches.get_child(0).get_theme_color("font_color").is_equal_approx(Palette.OLIVE),
		"… ses sections aussi")
func _l_exemple(ed: Control) -> void:
	const Exemple := preload("res://app/exemple.gd")
	if not Exemple.disponible():
		print("  (pas d'exemple dans ce checkout : DEV_TOOLS/prendre_l_exemple.gd ne l'a pas encore pris)")
		return
	var z := ZIPReader.new()
	z.open(Exemple.ARCHIVE)
	var attendu = JSON.parse_string(z.read_file("example.mbproj").get_string_from_utf8())
	z.close()
	var bouton: Button = null
	for b in ed.find_children("*", "Button", true, false):
		if (b as Button).text == "Very simple example":
			bouton = b
	_vrai(bouton != null, "World porte le choix « The example » (le seul : plus de bouton à part dans Project)")
	var double := false
	for b in ed.find_children("*", "Button", true, false):
		double = double or (b as Button).text == "Open the example"
	_vrai(not double, "plus de bouton « Open the example » dans Project")
	if bouton == null:
		return
	bouton.pressed.emit()
	for i in 600:
		await process_frame
		if ed._projet.contains("/example/") and not ed._ouverture:
			break
	_vrai(ed._projet.ends_with("example.mbproj") and ed._projet.contains("/example/"),
		"l'exemple s'ouvre depuis son dossier d'installation — %s" % ed._projet)
	_egal(ed._couches.size(), (attendu["couches"] as Array).size(), "toutes ses couches")
	# ⚠ LES COUCHES EXCLUSIVES : une case que l'archive met dans deux couches reste à la plus HAUTE (la première de la
	# liste) — l'exemple repris le 2 octobre 2026 en avait deux. L'attendu le recompte ici, sur l'archive.
	var plus_hautes := {}
	for i in mini(ed._couches.size(), (attendu["couches"] as Array).size()):
		var c: Dictionary = attendu["couches"][i]
		var m: Node = ed._vue.couche(i)
		var plat: Array = c["cases"]
		var siennes := {}
		for k in range(0, plat.size(), 3):
			var v := Vector3i(int(plat[k]), int(plat[k + 1]), int(plat[k + 2]))
			if not plus_hautes.has(v):
				siennes[v] = true
		for v in siennes:
			plus_hautes[v] = true
		_egal((m.get_node("Cases") as GridMap).get_used_cells().size(), siennes.size(),
			"« %s » : ses cases (celles qu'une couche plus haute n'a pas)" % c["nom"])
		var poses := (m.get_node("Rendu") as GridMap).get_used_cells().size()
		var fautes := (m.get_node("Fautes") as GridMap).get_used_cells().size()
		# ⚠ UNE COUCHE SANS CASE (l'exemple du 3 octobre 2026 en porte une, « Grass ») ne pose rien, et c'est juste.
		_vrai((poses > 0 or siennes.is_empty()) and fautes == 0, "« %s » : ses tuiles, sans un cube rouge (%d posées, %d fautes)"
			% [c["nom"], poses, fautes])
	_vrai(not ed._rapport.text.contains("missing"), "rien ne manque à l'ouverture")


## « LA BARRE DE DROITE DÉBORDE À DROITE EN WORLD » (Jordan, 3 octobre 2026) : avec une sélection, la barre passait à
## 358 px (les deux « Extend selection » côte à côte), puis 311 (l'ascenseur vertical). Elle doit garder sa largeur, et
## son bord droit doit rester celui de l'écran. Et une case DÉCOCHÉE doit avoir une icône lisible (claire).
func _la_barre_de_droite_tient(ed: Control) -> void:
	ed._aller_a("monde")
	ed._choisir_outil("selectionner")
	var grande := {}
	for x in 3:
		grande[Vector3i(x, 0, 0)] = true
	ed._vue.regler_selection(grande)
	for i in 3:
		await process_frame
	var barre: Control = ed._droite
	_vrai(is_equal_approx(barre.size.x, ed.LARGEUR_DROITE) and is_equal_approx(barre.get_global_rect().end.x, ed.size.x),
		"avec une sélection, la barre de droite garde %d px et son bord est celui de l'écran (%.0f px, bord %.0f / %.0f)"
		% [ed.LARGEUR_DROITE, barre.size.x, barre.get_global_rect().end.x, ed.size.x])
	var case := CheckBox.new()
	barre.get_meta("pile").add_child(case)
	var icone: Texture2D = case.get_theme_icon("unchecked")
	var clair := 0.0
	if icone != null:
		var img := icone.get_image()
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				clair = maxf(clair, c.a * c.get_luminance())
	_vrai(clair > 0.5, "une case décochée a une icône lisible (luminance × opacité %.2f)" % clair)
	case.queue_free()
	ed._vue.vider_selection()


## LA BARRE POUR TOUT GESTE QUI DURE (Jordan, 3 octobre 2026). Sans fenêtre, le suivi est forcé (`_gestes_suivis`).
## Un geste inconnu qui bloque 0,5 s s'apprend, sans barre la première fois ; un Ctrl+Z connu pour être long est RETENU
## (le panneau « Undo », rien encore défait), puis REJOUÉ une seule fois : une case sur deux est défaite, pas les deux.
func _la_barre_des_gestes(ed: Control) -> void:
	ed._aller_a("monde")
	ed._gestes_suivis = true
	ed._durees_gestes.par_unite.clear()
	var cases: GridMap = ed._vue.cases()
	var c1 := Vector3i(300, 0, 300)
	var c2 := Vector3i(302, 0, 300)
	ed._appliquer({"poser": {c1: true}, "effacer": {}}, "Add")
	ed._appliquer({"poser": {c2: true}, "effacer": {}}, "Add")
	ed._input(_cle(KEY_F9))
	OS.delay_msec(500)   # le travail qui bloque
	for i in 3:
		await process_frame
	_vrai(ed._durees_gestes.prevoir("touche:monde:F9", ed._union.size()) > 0.4 and not ed._attente.visible,
		"un geste inconnu qui a bloqué 0,5 s est appris (%.2f s prévues), sans barre cette fois"
		% ed._durees_gestes.prevoir("touche:monde:F9", ed._union.size()))
	ed._durees_gestes.par_unite["touche:monde:Ctrl+Z"] = 1.0
	Input.parse_input_event(_cle(KEY_Z, true))
	Input.flush_buffered_events()
	_vrai(ed._attente.visible and ed._attente_titre.text == "Undo" and cases.get_cell_item(c2) != -1,
		"un Ctrl+Z connu pour être long : le panneau « Undo » d'abord, rien n'est encore défait (« %s »)" % ed._attente_titre.text)
	for i in 6:
		await process_frame
	_vrai(cases.get_cell_item(c2) == -1 and cases.get_cell_item(c1) != -1,
		"… puis il est rejoué UNE fois : la dernière case est défaite, pas l'autre")
	_vrai(not ed._attente.visible, "… et le panneau s'en va")
	ed._durees_gestes.par_unite.clear()
	ed._gestes_suivis = false
	ed._appliquer({"poser": {}, "effacer": {c1: true}}, "Dig")
	# ⚠ LE CLIC REJOUÉ L'EST PANNEAU ENCORE À L'ÉCRAN (il ne s'en va que deux images plus tard) : un panneau qui prend la
	# souris avalait le clic retenu s'il tombait sous lui — au centre de la vue (signalé par la session vidéos, 6 octobre
	# 2026 : le second clic d'eau ne posait rien). Un vrai clic, routé par l'interface, au centre du panneau montré.
	var vue: Control = ed._vue
	var nav_avant: bool = vue.naviguer
	vue.naviguer = true   # le clic ne peint rien
	var panneau: Array = ed._occupe("Working")
	await process_frame
	var recus := [0]
	var compter := func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			recus[0] += 1
	vue.gui_input.connect(compter)
	var centre: Vector2 = ed._attente.get_global_rect().get_center()
	for appui in [true, false]:
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.position = centre
		m.global_position = centre
		m.pressed = appui
		Input.parse_input_event(m)
		Input.flush_buffered_events()
	vue.gui_input.disconnect(compter)
	ed._fin_occupe(panneau)
	vue.naviguer = nav_avant
	_vrai(vue.get_global_rect().has_point(centre) and recus[0] == 2,
		"un clic sous le panneau d'attente arrive à la vue (%d événements sur 2) : le clic rejoué n'est pas avalé" % recus[0])


## « FIX DIAGONAL CONTACTS » (Jordan, 3 octobre 2026), par les VRAIS boutons, loin de tout (x = 200) : deux cases qui se
## touchent par une arête. Attendus à la main : Fill pose (201,0,200) et (200,1,200) ; Dig retire les deux ; un Ctrl+Z.
func _reparer_les_diagonales_au_bouton(ed: Control) -> void:
	ed._aller_a("monde")
	var a := Vector3i(200, 0, 200)
	var b := Vector3i(201, 1, 200)
	ed._appliquer({"poser": {a: true, b: true}, "effacer": {}}, "Add")
	var cases: GridMap = ed._vue.cases()
	(ed._boutons_diagonales[0] as Button).pressed.emit()
	await process_frame
	_vrai(cases.get_cell_item(Vector3i(201, 0, 200)) != -1 and cases.get_cell_item(Vector3i(200, 1, 200)) != -1
		and ed._rapport.text.contains("fixed"), "Fix diagonal contacts · Fill : les deux cases vides du carré sont posées")
	_vrai(MB.contacts_par_arete(ed._union) == 0, "… et le monde visible n'a plus aucun contact par une arête")
	ed._histoire.undo()
	_vrai(cases.get_cell_item(Vector3i(201, 0, 200)) == -1 and cases.get_cell_item(a) != -1,
		"UN Ctrl+Z défait la réparation, la paire d'origine reste")
	(ed._boutons_diagonales[1] as Button).pressed.emit()
	await process_frame
	_vrai(cases.get_cell_item(a) == -1 and cases.get_cell_item(b) == -1, "Fix diagonal contacts · Dig : la paire est creusée")
	(ed._boutons_diagonales[0] as Button).pressed.emit()
	await process_frame
	(ed._boutons_diagonales[0] as Button).pressed.emit()
	await process_frame
	_vrai(ed._rapport.text.contains("No diagonal contact"), "sans contact, le bouton le dit (%s)" % ed._rapport.text.left(80))


## ÉDITER L'EXEMPLE PENDANT LE DÉV (3 octobre 2026) — `DEV_TOOLS/dev_exemple.gd`, branché à la main sur l'écran (la
## fumée tourne sans `--dev-example`), avec un pointeur et une archive JETABLES : « The example » ouvre la SOURCE, elle
## compte comme l'exemple et n'est jamais retenue comme « ton monde », et la fermeture la réemballe.
func _le_mode_dev_de_l_exemple(ed: Control) -> void:
	var D: GDScript = load("res://DEV_TOOLS/dev_exemple.gd")
	D.pointeur_force = ProjectSettings.globalize_path("user://fumee/dev/exemple_source.txt")
	D.archive_force = ProjectSettings.globalize_path("user://fumee/dev/exemple.zip")
	DirAccess.make_dir_recursive_absolute(D.archive_force.get_base_dir())
	DirAccess.remove_absolute(D.archive_force)
	var mon_monde: String = ed._projet
	var source := ProjectSettings.globalize_path("user://fumee/dev/preuve.mbproj")
	var couche := Projet.couche("Proof")
	couche["cases"] = {Vector3i(0, 0, 0): true, Vector3i(1, 0, 0): true}
	var f := FileAccess.open(source, FileAccess.WRITE)
	f.store_string(Projet.vers_texte([couche], 0))
	f.close()
	_egal(D.designer(source), "", "dev : la source de l'exemple est désignée")
	ed._dev = D.new(ed)
	ed.dev_suivre_la_source()
	await ed._ouvrir_l_exemple()
	_egal(ed._projet, source, "dev : « The example » ouvre la SOURCE, pas la copie installée")
	_vrai(ed.est_l_exemple(source) and (ed._choix_monde.get_child(1) as Button).button_pressed,
		"dev : elle compte comme l'exemple (« Which world » coche The example)")
	var r := ConfigFile.new()
	r.load(ed.REGLAGES)
	_vrai(str(r.get_value("projet", "monde", "")) != source, "dev : elle n'est jamais retenue comme « ton monde »")
	ed._dev.a_la_fermeture(ed._projet)
	var z := ZIPReader.new()
	var lu := ""
	if z.open(D.archive_force) == OK:
		lu = z.read_file("example.mbproj").get_string_from_utf8() if z.get_files().has("example.mbproj") else ""
		z.close()
	_vrai(lu.contains("Proof"), "dev : à la fermeture, l'exemple est réemballé depuis la source")
	ed._dev = null
	ed.source_dev_exemple = ""
	D.pointeur_force = ""
	D.archive_force = ""
	await ed._ouvrir(mon_monde)


## Vide un dossier de `user://fumee` (récursif) — jamais ailleurs.
func _vider_dossier(chemin: String) -> void:
	if not chemin.begins_with("user://fumee/") or not DirAccess.dir_exists_absolute(chemin):
		return
	for d in DirAccess.get_directories_at(chemin):
		_vider_dossier(chemin.path_join(d))
	for f in DirAccess.get_files_at(chemin):
		DirAccess.remove_absolute(chemin.path_join(f))
	DirAccess.remove_absolute(chemin)


## ── LA MOLETTE DU CONTEXTE (Jordan, 3 octobre 2026) ────────────────────────────────────────────────────────────────
## De VRAIS crans envoyés à la vue (`_gui_input`) et aux panneaux (`push_input`). ⚠ Les attendus sont écrits ICI (le pas
## de chaque réglage, des volumes comptés à la main, la boîte de la matière relue dans les grilles), jamais lus dans
## `_molette`.
var _molette_finie := false


func _cran(vue: Control, sens: int, alt := false, maj := false, ctrl := false) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_UP if sens > 0 else MOUSE_BUTTON_WHEEL_DOWN
	e.pressed = true
	e.alt_pressed = alt
	e.shift_pressed = maj
	e.ctrl_pressed = ctrl
	e.position = vue._derniere_souris if vue._derniere_souris.x >= 0.0 else vue.size * 0.5
	vue._gui_input(e)


func _la_molette(ed: Control) -> void:
	var vue = ed._vue
	var g: GridMap = vue.cases()
	ed._aller_a("monde")
	ed._choisir_visee("grille")
	ed._compteur_etage.value = 0
	ed._choisir_outil("ajouter")
	ed._taille.value = 2
	vue.forme = "sphere"
	_viser_d_en_haut(vue, Vector3(301.5, 0.0, 301.5))
	_bouge(vue, vue.size * 0.5)
	var d0: float = vue._distance
	_cran(vue, 1)
	_vrai(vue._distance < d0 and int(ed._taille.value) == 2, "molette seule : la vue zoome, la taille ne bouge pas")
	var d1: float = vue._distance
	_cran(vue, 1, true)
	_vrai(int(ed._taille.value) == 3 and is_equal_approx(vue._distance, d1) and vue.taille == 3,
		"Alt + molette : la taille du pinceau 2 → 3, sans zoomer")
	_vrai(vue.bulle_visible() == "Brush size 3", "… et la valeur est dite près de la souris (« %s »)" % vue.bulle_visible())
	_cran(vue, -1, true)
	_egal(int(ed._taille.value), 2, "Alt + molette vers le bas : 3 → 2")
	# UN SENS PAR MODIFICATEUR (13 octobre 2026) : Maj ne change plus la forme du pinceau (les boutons seuls) — elle zoome.
	_cran(vue, 1, false, true)
	_egal(vue.forme, "sphere", "Maj + molette ne change plus la forme du pinceau")
	_cran(vue, 1, false, false, true)
	_vrai(int(ed._compteur_etage.value) == 1 and vue.etage == 1, "Ctrl + molette : l'étage de la grille 0 → 1")
	_cran(vue, -1, false, false, true)
	_egal(vue.etage, 0, "… et 1 → 0")
	# UN RECT QU'ON HAUSSE PENDANT LE GLISSÉ : 3 × 3 à plat sur l'étage 0, deux crans vers le haut → 3 × 3 × 3 = 27 cases,
	# de y = 0 à 2, rien de posé.
	ed._choisir_outil("rect")
	vue.vider_selection()
	var avant: int = g.get_used_cells().size()
	var a: Vector2 = vue._camera.unproject_position(Vector3(300.5, 0.0, 300.5))
	var b: Vector2 = vue._camera.unproject_position(Vector3(302.5, 0.0, 302.5))
	_souris(vue, a, MOUSE_BUTTON_LEFT, true)
	_bouge(vue, b)
	_cran(vue, 1)
	_cran(vue, 1)
	_vrai(vue.bulle_visible() == "Height +2", "pendant le glissé, la molette seule hausse le Rect (« %s »)" % vue.bulle_visible())
	_souris(vue, b, MOUSE_BUTTON_LEFT, false)
	_vrai(vue.selection.size() == 27 and vue.selection.has(Vector3i(300, 2, 300)) and vue.selection.has(Vector3i(302, 0, 302))
		and not vue.selection.has(Vector3i(300, 3, 300)), "… relâché : un volume de 3 × 3 × 3 = 27 cases (%d)" % vue.selection.size())
	_egal(g.get_used_cells().size(), avant, "… et rien n'est posé")
	# LA SÉLECTION QU'ON FAÇONNE : Maj l'étend en hauteur (une rangée de 9 au-dessus : 36), sans rien poser ; Alt la fait
	# grandir, puis rétrécir.
	ed._choisir_outil("selectionner")
	_cran(vue, 1, false, true)
	_vrai(vue.selection.size() == 36 and vue.selection.has(Vector3i(301, 3, 301)) and g.get_used_cells().size() == avant,
		"Select + Maj + molette : la sélection monte d'une rangée (36), rien n'est posé (%d)" % vue.selection.size())
	_cran(vue, 1, true)
	var grandie: int = vue.selection.size()
	# Une couronne à plat autour du 3 × 3 : 3 × 3 + 4 côtés de 3 = 21 par rangée, sur 4 rangées.
	_vrai(grandie == 84 and vue.selection.has(Vector3i(303, 0, 301)) and not vue.selection.has(Vector3i(303, 0, 303))
		and g.get_used_cells().size() == avant, "Alt + molette : la sélection s'élargit d'une couronne à plat, cases vides comprises (84 : %d)" % grandie)
	_cran(vue, -1, true)
	_vrai(vue.selection.size() < grandie, "Alt + molette vers le bas : elle rétrécit (%d)" % vue.selection.size())
	# CTRL DÉPLACE (13 octobre 2026) : avec une sélection, Ctrl + molette la monte d'une case (le « grab »), l'étage ne
	# bouge pas, rien n'est posé. Attendu : chaque case + (0, 1, 0), calculé ici.
	# ⚠ LA RÈGLE EST CELLE DES FLÈCHES (`Outils.deplacer`) : c'est la MATIÈRE sélectionnée qui se déplace — on remplit donc
	# d'abord la sélection (Fill), sinon une sélection d'air ne déplacerait rien.
	ed._operer_selection("remplir")
	avant = g.get_used_cells().size()
	var avant_grab: Dictionary = vue.selection.duplicate()
	var etage_grab: int = vue.etage
	_cran(vue, 1, false, false, true)
	var montee_grab := {}
	for c: Vector3i in avant_grab:
		montee_grab[c + Vector3i.UP] = true
	_vrai(vue.selection.keys().all(func(c: Vector3i) -> bool: return montee_grab.has(c)) and vue.selection.size() == montee_grab.size(),
		"Select + Ctrl + molette : la sélection monte d'une case (%d cases)" % vue.selection.size())
	_vrai(vue.etage == etage_grab and g.get_used_cells().size() == avant, "… l'étage ne bouge pas, la matière ne fait que monter")
	ed._histoire.undo()
	ed._histoire.undo()
	avant = g.get_used_cells().size()
	vue.vider_selection()
	# LA SALLE QU'ON TRACE : 5 × 4, 2 étages, un cran vers le haut pendant le glissé → 3 étages. La coque d'un pavé de
	# 5 × 4 × 5 moins son dedans de 3 × 2 × 3 : 100 − 18 = 82 cases (2 étages : 80 − 12 = 68).
	ed._choisir_forme_speciale("salle")
	ed._etages_forme.value = 2
	a = vue._camera.unproject_position(Vector3(300.5, 0.0, 300.5))
	b = vue._camera.unproject_position(Vector3(304.5, 0.0, 303.5))
	_souris(vue, a, MOUSE_BUTTON_LEFT, true)
	_bouge(vue, b)
	_cran(vue, 1)
	_souris(vue, b, MOUSE_BUTTON_LEFT, false)
	_vrai(int(ed._etages_forme.value) == 3 and g.get_used_cells().size() == avant + 82,
		"la molette pendant le tracé d'une salle : 3 étages, 82 cases de coque (%d)" % (g.get_used_cells().size() - avant))
	ed._histoire.undo()
	_cran(vue, -1, false, true)
	_egal(int(ed._etages_forme.value), 2, "Room, Maj + molette (la hauteur) : les étages 3 → 2")
	var haut_salle := bool(vue.forme_speciale["vers_le_haut"])
	_cran(vue, -1, true)
	_vrai(int(ed._etages_forme.value) == 2 and bool(vue.forme_speciale["vers_le_haut"]) == haut_salle,
		"Room, Alt + molette ne règle plus rien (ni étages ni sens)")
	# UNE FORME : Alt la taille, Maj la profondeur (Depth du tunnel).
	ed._choisir_forme_speciale("tunnel")
	var t0 := int(ed._taille_forme.value)
	var l0 := int(ed._longueur_forme.value)
	_cran(vue, 1, true)
	_cran(vue, 1, false, true)
	_vrai(int(ed._taille_forme.value) == t0 + 1 and int(vue.forme_speciale["taille"]) == t0 + 1
		and int(ed._longueur_forme.value) == l0 + 1, "tunnel : Alt + molette la taille %d → %d, Maj la profondeur %d → %d"
		% [t0, t0 + 1, l0, l0 + 1])
	ed._choisir_forme_speciale("escalier")
	var p0 := int(ed._pas_forme.value)
	var e0: int = vue.etage
	_cran(vue, 1, false, true, true)
	_vrai(int(ed._pas_forme.value) == p0, "escalier : Ctrl + Maj + molette ne règle plus le pas (le bouton seul)")
	ed._compteur_etage.value = e0
	# LE COLLAGE : un cran le monte d'une case au-dessus de la face visée.
	ed._choisir_outil("ajouter")
	vue.commencer_collage([Vector3i.ZERO])
	_bouge(vue, vue.size * 0.5)
	_cran(vue, 1)
	_egal(vue.hauteur_collage, 1, "pendant un collage, la molette seule le monte d'une case")
	vue.annuler_collage()
	# FLUIDS : Alt la largeur de la rivière.
	ed._aller_a("fluides")
	ed._largeur_eau.value = 1
	_cran(vue, 1, true)
	_egal(int(ed._largeur_eau.value), 2, "Fluids, Alt + molette : la largeur de rivière 1 → 2")
	ed._largeur_eau.value = 1
	# F CADRE TOUTE LA MATIÈRE (Jordan : « c'était F ») : la cible au centre de la boîte des cases visibles, relue ici
	# dans les grilles.
	ed._aller_a("monde")
	var lo := Vector3i(1073741824, 1073741824, 1073741824)
	var hi := -lo
	for i in vue.nombre_de_couches():
		var m := vue.couche(i) as Node3D
		if m.visible:
			for c: Vector3i in (m.get_node("Cases") as GridMap).get_used_cells():
				lo = Vector3i(mini(lo.x, c.x), mini(lo.y, c.y), mini(lo.z, c.z))
				hi = Vector3i(maxi(hi.x, c.x), maxi(hi.y, c.y), maxi(hi.z, c.z))
	ed._unhandled_key_input(_cle(KEY_F))
	var centre := (Vector3(lo) + Vector3(hi) + Vector3.ONE) * 0.5
	_vrai((vue._cible as Vector3).distance_to(centre) < 1e-3, "F : la vue vise le centre de toute la matière (%s)" % centre)
	var coin: Vector2 = vue._camera.unproject_position(Vector3(lo))
	var coin2: Vector2 = vue._camera.unproject_position(Vector3(hi) + Vector3.ONE)
	_vrai(Rect2(Vector2.ZERO, vue.size).grow(2.0).has_point(coin) and Rect2(Vector2.ZERO, vue.size).grow(2.0).has_point(coin2),
		"… et ses coins sont à l'écran")
	# ² SAUTE SUR LA MATIÈRE (Jordan, 4 octobre 2026) : visée sur le dessus d'une colonne, la cible tombe SUR une face
	# de matière, l'œil à moins de 8 cases, et rien de plein entre les deux. Attendus relus ici dans les grilles.
	var pleines := {}
	for i in vue.nombre_de_couches():
		var m := vue.couche(i) as Node3D
		if m.visible:
			for c: Vector3i in (m.get_node("Cases") as GridMap).get_used_cells():
				pleines[c] = true
	var sommet_vise := Vector3i.ZERO
	for c: Vector3i in pleines:
		if not pleines.has(c + Vector3i.UP) and c.y >= sommet_vise.y:
			sommet_vise = c
	var ecran: Vector2 = vue._camera.unproject_position(Vector3(sommet_vise) + Vector3(0.5, 1.0, 0.5))
	var cible_avant: Vector3 = vue._cible
	_vrai(vue.teleporter_vers(ecran), "² : le rayon sous la souris touche la matière")
	var cible_t: Vector3 = vue._cible
	var oeil_t: Vector3 = vue._camera.global_position
	var sur_face := false
	for d: Vector3 in [Vector3(0.01, 0, 0), Vector3(-0.01, 0, 0), Vector3(0, 0.01, 0), Vector3(0, -0.01, 0), Vector3(0, 0, 0.01), Vector3(0, 0, -0.01)]:
		var dedans := cible_t + d
		var dehors := cible_t - d
		if pleines.has(Vector3i(floori(dedans.x), floori(dedans.y), floori(dedans.z))) 				and not pleines.has(Vector3i(floori(dehors.x), floori(dehors.y), floori(dehors.z))):
			sur_face = true
	_vrai(sur_face and cible_t.distance_to(cible_avant) > 1.0, "… la cible est SUR une face de matière (%s)" % cible_t)
	var recul_t := oeil_t.distance_to(cible_t)
	_vrai(recul_t <= 8.01 and recul_t >= 0.3, "… l'œil à une distance raisonnable (%.2f case)" % recul_t)
	var traverse := 0
	for k in range(1, 200):
		var q := cible_t.lerp(oeil_t, k / 200.0)
		if pleines.has(Vector3i(floori(q.x), floori(q.y), floori(q.z))):
			traverse += 1
	_vrai(traverse == 0 and not pleines.has(Vector3i(floori(oeil_t.x), floori(oeil_t.y), floori(oeil_t.z))),
		"… rien de plein entre la cible et l'œil, l'œil hors de la matière (%d points dedans)" % traverse)
	_vrai(not vue.teleporter_vers(Vector2(-10, -10)), "² hors de la vue : rien ne bouge")
	# La touche, par sa PLACE (sous Échap) : la vue saute, ou l'écran dit qu'il n'y avait rien sous la souris.
	var cible_k: Vector3 = vue._cible
	ed._unhandled_key_input(_cle(KEY_QUOTELEFT))
	_vrai(vue._cible != cible_k or ed._rapport.text.contains("²"), "² est branchée dans World")
	# LES PANNEAUX : aucun curseur ni compteur ne prend la molette, seules les zones défilantes.
	var curseurs := ed.find_children("*", "Slider", true, false)
	_vrai(curseurs.size() > 10 and curseurs.all(func(c): return not (c as Slider).scrollable),
		"aucun curseur des panneaux ne prend la molette (%d curseurs)" % curseurs.size())
	var compteurs := ed.find_children("*", "SpinBox", true, false)
	_vrai(compteurs.size() > 3 and compteurs.all(func(c): return c.has_meta("mb_sans_molette")),
		"chaque compteur lâche le focus au premier cran (%d compteurs)" % compteurs.size())
	# Un vrai cran sur le curseur de taille, dans la barre de droite : la valeur ne bouge pas.
	ed._taille.value = 4
	var sur: Vector2 = (ed._taille as Control).get_global_rect().get_center()
	var survol := InputEventMouseMotion.new()
	survol.position = sur
	survol.global_position = sur
	root.push_input(survol)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_DOWN
	e.pressed = true
	e.position = sur
	e.global_position = sur
	root.push_input(e)
	await process_frame
	_egal(int(ed._taille.value), 4, "un cran de molette SUR le curseur de taille ne le change pas")
	# GEOMETRY : Alt le rayon du sculpt (× 1,15), Maj sa force (+ un vingtième de sa course : 0,0475).
	ed._aller_a("witness")
	ed._regler_edition(true)
	var mo: Node3D = ed._modeleur
	ed._bouton_sculpt.button_pressed = true
	ed._curseurs_sculpt["sculpt_rayon"].value = 0.4
	ed._curseurs_sculpt["sculpt_force"].value = 0.5
	_cran(vue, 1, true)
	_cran(vue, 1, false, true)
	_vrai(absf(mo.sculpt_rayon - 0.46) < 0.006 and absf(mo.sculpt_force - 0.55) < 0.006,
		"sculpt : Alt + molette le rayon 0,4 → 0,46, Maj la force 0,5 → 0,55 (%.3f, %.3f)" % [mo.sculpt_rayon, mo.sculpt_force])
	ed._bouton_sculpt.button_pressed = false
	# TEXTURING : Alt la taille du pinceau (24 × 1,15 = 27,6 → 28 px).
	ed._aller_a("texture")
	ed._regler_edition(true)
	mo.regler_pinceau(true)
	ed._curseurs_pinceau["pinceau_taille"].value = 24
	_cran(vue, 1, true)
	_vrai(absf(mo.pinceau_taille - 28.0) < 0.01, "peinture : Alt + molette la taille 24 → 28 px (%.1f)" % mo.pinceau_taille)
	mo.regler_pinceau(false)
	ed._regler_edition(false)
	ed._aller_a("monde")
	_molette_finie = true


func _souris(vue: Control, ou: Vector2, bouton: int, appuye: bool, ctrl := false, maj := false) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = bouton
	e.position = ou
	e.pressed = appuye
	e.ctrl_pressed = ctrl
	e.shift_pressed = maj
	vue._gui_input(e)


func _bouge(vue: Control, ou: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = ou
	vue._gui_input(m)


func _lasso_et_cercle(ed: Control) -> void:
	var vue = ed._vue
	ed._aller_a("witness")
	if not vue.edition:
		ed._input(_cle(KEY_TAB))
	var mo: Node3D = ed._modeleur
	if mo.maillage == null:
		_vrai(false, "lasso : le modeleur n'a pas de maillage")
		return
	# ⚠ DE TROIS QUARTS, EN PERSPECTIVE, TOUT PRÈS DE LA TUILE EN ÉDITION : vue de face depuis le bloc entier, une tuile
	# de paroi ne faisait que 3 pixels de large, et les points du lasso tombaient à moins de 4 pixels l'un de l'autre.
	if vue._camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		vue.basculer_ortho()
	vue._azimut = 0.6
	vue._elevation = 0.5
	vue._distance = 3.0
	vue.cadrer(mo.pose.origin)
	for i in 3:
		await process_frame
	ed._input(_cle(KEY_1))
	var cam: Camera3D = vue._camera
	# ⚠ LE TRACÉ SE POSE SUR LA TUILE EN ÉDITION, à une taille qui n'en couvre qu'une PARTIE : posé au centre de l'écran,
	# il ne couvrait aucun sommet, et « exactement ceux du triangle » passait sur 0 = 0.
	var ecran := PackedVector2Array()
	for q in mo.maillage.sommets:
		ecran.append(cam.unproject_position(mo.pose * q))
	var boite := Rect2(ecran[0], Vector2.ZERO)
	for s in ecran:
		boite = boite.expand(s)
	var c: Vector2 = boite.get_center()
	var demi: Vector2 = boite.size * 0.5
	var tri := PackedVector2Array([c + Vector2(-demi.x, -demi.y) * 0.9, c + Vector2(demi.x * 0.2, -demi.y * 0.9),
		c + Vector2(-demi.x * 0.3, demi.y * 0.9)])
	mo.rayon_cercle = maxf(8.0, minf(demi.x, demi.y) * 0.5)
	var attendu_tri := {}
	var dans_le_disque := {}
	var rayon: float = mo.rayon_cercle
	# ⚠ TOUTES LES COPIES DE LA TUILE À L'ÉCRAN COMPTENT (13 octobre 2026) : un sommet est pris s'il tombe dedans sous
	# l'une de leurs poses — de près, les copies voisines de la paroi sont dans le tracé aussi.
	var poses := _poses_de_la_tuile(mo, cam)
	for i in mo.maillage.sommets.size():
		for ps: Transform3D in poses:
			var s: Vector2 = cam.unproject_position(ps * mo.maillage.sommets[i])
			if Geometry2D.is_point_in_polygon(s, tri):
				attendu_tri[i] = true
			if s.distance_to(c) <= rayon:
				dans_le_disque[i] = true
	_vrai(attendu_tri.size() > 0 and attendu_tri.size() < mo.maillage.sommets.size(),
		"le triangle tracé couvre une partie des sommets (%d sur %d)" % [attendu_tri.size(), mo.maillage.sommets.size()])

	# LE LASSO : Ctrl + clic droit glissé, en X-ray.
	mo.rayons_x = true
	mo.tout_choisir(false)
	_souris(vue, tri[0], MOUSE_BUTTON_RIGHT, true, true)
	_vrai(mo.modal == "lasso", "Ctrl + clic droit lance le lasso")
	_bouge(vue, tri[1])
	_bouge(vue, tri[2])
	_souris(vue, tri[2], MOUSE_BUTTON_RIGHT, false, true)
	_egal(mo.sel_s.keys().size(), attendu_tri.size(), "lasso en X-ray : autant de sommets que dans le triangle")
	var memes := true
	for i in attendu_tri:
		memes = memes and mo.sel_s.has(i)
	_vrai(memes and mo.modal == "", "… exactement eux, et le lasso est fini")
	# Maj + Ctrl : retire.
	mo.tout_choisir(true)
	var tous: int = mo.sel_s.size()
	_souris(vue, tri[0], MOUSE_BUTTON_RIGHT, true, true, true)
	_bouge(vue, tri[1])
	_bouge(vue, tri[2])
	_souris(vue, tri[2], MOUSE_BUTTON_RIGHT, false, true, true)
	_egal(mo.sel_s.size(), tous - attendu_tri.size(), "Maj + Ctrl + lasso retire exactement le triangle")
	# Sans X-ray, par le bouton et le clic gauche, un lasso autour de toute la tuile : il prend des sommets, et seulement
	# des sommets de son tracé. ⚠ L'OCCLUSION ELLE-MÊME est gardée par le test de la boîte B (même règle commune,
	# `_choisir_si`) : vue de trois quarts, cette tuile — un morceau de surface ouvert — n'a aucun sommet caché.
	var autour := boite.grow(12.0)
	mo.rayons_x = false
	mo.tout_choisir(false)
	ed._geste_modeleur("lasso")
	_souris(vue, autour.position, MOUSE_BUTTON_LEFT, true)
	_bouge(vue, autour.position + Vector2(autour.size.x, 0))
	_bouge(vue, autour.end)
	_bouge(vue, autour.position + Vector2(0, autour.size.y))
	_souris(vue, autour.position + Vector2(0, autour.size.y), MOUSE_BUTTON_LEFT, false)
	var hors := 0
	for i in mo.sel_s:
		if not poses.any(func(ps: Transform3D) -> bool: return autour.has_point(cam.unproject_position(ps * mo.maillage.sommets[i]))):
			hors += 1
	_vrai(mo.sel_s.size() > 0 and hors == 0 and mo.modal == "",
		"le bouton Lasso au clic gauche, sans X-ray : %d sommets, tous dans le tracé" % mo.sel_s.size())

	# LE CERCLE : C, un clic gauche au centre (X-ray), la molette, Maj retire, Échap finit.
	mo.rayons_x = true
	mo.tout_choisir(false)
	ed._input(_cle(KEY_C))
	_vrai(mo.modal == "cercle", "C lance le cercle")
	_bouge(vue, c)
	_souris(vue, c, MOUSE_BUTTON_LEFT, true)
	_souris(vue, c, MOUSE_BUTTON_LEFT, false)
	_vrai(dans_le_disque.size() > 0 and dans_le_disque.size() < mo.maillage.sommets.size(),
		"le disque couvre une partie des sommets (%d)" % dans_le_disque.size())
	_egal(mo.sel_s.size(), dans_le_disque.size(), "un clic du cercle prend les %d sommets du disque" % dans_le_disque.size())
	_souris(vue, c, MOUSE_BUTTON_WHEEL_UP, true)
	_vrai(is_equal_approx(mo.rayon_cercle, rayon * 1.15), "la molette agrandit le cercle")
	mo.rayon_cercle = rayon
	_souris(vue, c, MOUSE_BUTTON_LEFT, true, false, true)
	_souris(vue, c, MOUSE_BUTTON_LEFT, false, false, true)
	_egal(mo.sel_s.size(), 0, "Maj + clic du cercle les retire")
	# Peindre en glissant : un trait de gauche à droite prend plus qu'un seul clic.
	_bouge(vue, c - Vector2(demi.x, 0))
	_souris(vue, c - Vector2(demi.x, 0), MOUSE_BUTTON_LEFT, true)
	for k in 11:
		_bouge(vue, c + Vector2(-demi.x + demi.x * 0.2 * k, 0))
	_souris(vue, c + Vector2(demi.x, 0), MOUSE_BUTTON_LEFT, false)
	_vrai(mo.sel_s.size() > dans_le_disque.size(), "un trait du cercle peint la sélection le long du geste (%d)" % mo.sel_s.size())
	# LES ARÊTES DU CERCLE SE PRENNENT PAR LEUR MILIEU (on promène le cercle comme un pinceau ; ses deux bouts tombent
	# rarement ensemble dedans). Attendu : le milieu projeté par la caméra, dans le disque.
	# (Le cercle avale les touches, comme dans Blender : on en sort pour changer de mode, puis on y revient.)
	ed._input(_cle(KEY_ESCAPE))
	ed._input(_cle(KEY_2))
	mo.tout_choisir(false)
	ed._input(_cle(KEY_C))
	_vrai(mo.mode_sel == "arete" and mo.modal == "cercle", "mode arête, le cercle repris")
	var aretes_au_milieu := 0
	var aretes_aux_deux_bouts := 0
	for e in mo._aretes():
		var pa: Vector3 = mo.maillage.sommets[e.x]
		var pb: Vector3 = mo.maillage.sommets[e.y]
		if poses.any(func(ps: Transform3D) -> bool: return cam.unproject_position(ps * ((pa + pb) * 0.5)).distance_to(c) <= rayon):
			aretes_au_milieu += 1
		if poses.any(func(ps: Transform3D) -> bool: return cam.unproject_position(ps * pa).distance_to(c) <= rayon \
				and cam.unproject_position(ps * pb).distance_to(c) <= rayon):
			aretes_aux_deux_bouts += 1
	_vrai(aretes_au_milieu > aretes_aux_deux_bouts, "le disque distingue les deux règles (%d par le milieu, %d par les deux bouts)"
		% [aretes_au_milieu, aretes_aux_deux_bouts])
	_souris(vue, c, MOUSE_BUTTON_LEFT, true)
	_souris(vue, c, MOUSE_BUTTON_LEFT, false)
	_egal(mo.sel_a.size(), aretes_au_milieu, "en mode arête, le cercle prend les arêtes dont le MILIEU est dans le disque")
	ed._input(_cle(KEY_ESCAPE))
	_vrai(mo.modal == "", "Échap finit le cercle")
	# Les faces : par leur centre.
	ed._input(_cle(KEY_3))
	mo.tout_choisir(false)
	var faces_tri := 0
	for f in mo.maillage.faces.size():
		if poses.any(func(ps: Transform3D) -> bool: return Geometry2D.is_point_in_polygon(cam.unproject_position(ps * mo.maillage.centre(f)), tri) \
				and cam.is_position_in_frustum(ps * mo.maillage.centre(f))):
			faces_tri += 1
	_souris(vue, tri[0], MOUSE_BUTTON_RIGHT, true, true)
	_bouge(vue, tri[1])
	_bouge(vue, tri[2])
	_souris(vue, tri[2], MOUSE_BUTTON_RIGHT, false, true)
	_egal(mo.sel_f.size(), faces_tri, "lasso en mode face (X-ray) : les faces dont le centre est dans le triangle")
	# UNE BOÎTE AUTOUR D'UNE AUTRE COPIE DE LA TUILE (Jordan, 13 octobre 2026 : « on ne peut pas sélectionner plusieurs
	# faces du même bloc à travers des clones différents ») : elle prend les faces de la tuile, la copie en édition ne
	# change pas. Attendu : les faces dont le centre, sous la pose de CETTE copie, tombe dans la boîte (X-ray).
	mo.tout_choisir(false)
	var autre := -1
	var cadre_autre := Rect2()
	var ecran_actif: Vector2 = cam.unproject_position(mo.pose.origin)
	for i in mo.temoin.occurrences_de(mo.cle):
		var ps: Transform3D = mo.temoin.occurrences[i]["pose"]
		if i == mo.occurrence or not cam.is_position_in_frustum(ps.origin):
			continue
		var r := Rect2(cam.unproject_position(ps * mo.maillage.sommets[0]), Vector2.ZERO)
		for q in mo.maillage.sommets:
			r = r.expand(cam.unproject_position(ps * q))
		if not r.grow(4.0).has_point(ecran_actif) and Rect2(Vector2.ZERO, vue.size).encloses(r):
			autre = i
			cadre_autre = r.grow(2.0)
			break
	_vrai(autre >= 0, "une autre copie de la tuile en édition est à l'écran, loin de la copie active")
	if autre >= 0:
		var ps_autre: Transform3D = mo.temoin.occurrences[autre]["pose"]
		var faces_autre := {}
		for f in mo.maillage.faces.size():
			if cadre_autre.has_point(cam.unproject_position(ps_autre * mo.maillage.centre(f))) \
					and cam.is_position_in_frustum(ps_autre * mo.maillage.centre(f)):
				faces_autre[f] = true
		var active := int(mo.occurrence)
		mo.choisir_dans(cadre_autre)
		_vrai(faces_autre.size() > 0 and faces_autre.keys().all(func(f: int) -> bool: return mo.sel_f.has(f)),
			"B autour d'une AUTRE copie : ses faces sont prises (%d attendues, %d prises)" % [faces_autre.size(), mo.sel_f.size()])
		_egal(int(mo.occurrence), active, "… sans changer la copie en édition")
	mo.rayons_x = false
	mo.tout_choisir(false)
	_lasso_fini = true


## Les poses des copies de la tuile en édition qui comptent pour un tracé : la copie active, et les autres dont le centre
## est dans le champ de la caméra.
func _poses_de_la_tuile(mo: Node3D, cam: Camera3D) -> Array:
	var poses: Array = [mo.pose]
	if mo.temoin == null:
		return poses
	for i in mo.temoin.occurrences_de(mo.cle):
		var ps: Transform3D = mo.temoin.occurrences[i]["pose"]
		if i != mo.occurrence and cam.is_position_in_frustum(ps.origin):
			poses.append(ps)
	return poses


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


## LES CRANS DU TÉMOIN ET DU SOL DE L'EAU (Jordan, 9 octobre 2026 : « go pour les trois crans, 0 par défaut »), par les
## VRAIS boutons. Attendus écrits à la main : le témoin calculé de 12 × 10 × 12 cases a sa boîte en (0, 0, 0) … (12, 10, 12)
## au neutre, élargie de 0,25 de chaque côté à l'épais ; la nappe d'une mer de niveau 2 à 2,95 au neutre, 2,7 à l'épais.
var _crans_finis := false


func _les_crans(ed: Control) -> void:
	ed._aller_a("witness")
	ed._regler_edition(false)
	# Le projet ouvert à ce point de la fumée n'est plus le monde d'essai : on part de l'aminci, posé par le vrai bouton.
	if ed._retrait != 0.25:
		(ed._boutons_cran["aminci"] as Button).pressed.emit()
	_egal(ed._retrait, 0.25, "Inset : le monde est aminci")
	var boite_aminci: AABB = (ed._vue._temoin.mesh as Mesh).get_aabb()
	_vrai(boite_aminci.position.is_equal_approx(Vector3(0.25, 0.25, 0.25)) and boite_aminci.size.is_equal_approx(Vector3(11.5, 9.5, 11.5)),
		"la vue montre le témoin aminci, rentré d'un quart de case (%s)" % boite_aminci)
	ed._nouvelle_couche()
	var c: Dictionary = ed._couches[ed._active]
	_vrai((ed._boutons_cran["aminci"] as Button).button_pressed and not (ed._boutons_cran["neutre"] as Button).button_pressed,
		"Witness surface : Inset enfoncé")
	_vrai((ed._note_cran.text as String).contains("keep their shape") or ed._couches_hors_du_cran().is_empty(),
		"… et la note nomme les couches au témoin modelé, s'il y en a (%s)" % ed._note_cran.text)
	(ed._boutons_cran["neutre"] as Button).pressed.emit()
	_egal(ed._retrait, 0.0, "Centred : le monde passe au neutre")
	var boite: AABB = (ed._vue._temoin.mesh as Mesh).get_aabb()
	_vrai(boite.position.is_equal_approx(Vector3.ZERO) and boite.size.is_equal_approx(Vector3(12, 10, 12)),
		"la vue montre le témoin calculé neutre : sa surface au bord des cases (%s)" % boite)
	(ed._boutons_cran["epais"] as Button).pressed.emit()
	_egal(ed._retrait, -0.25, "Outset : le monde passe à l'épais")
	boite = (ed._vue._temoin.mesh as Mesh).get_aabb()
	_vrai(boite.position.is_equal_approx(Vector3(-0.25, -0.25, -0.25)) and boite.size.is_equal_approx(Vector3(12.5, 10.5, 12.5)),
		"… la vue montre le témoin épais, débordant d'un quart de case (%s)" % boite)
	var t_epais: RefCounted = ed._temoin_de(c)
	_egal(t_epais.tuiles.size(), 52, "… le témoin lié de la couche neuve est refait à l'épais : 52 tuiles")
	var plaque := "mb_plaque_b2h2_dehors"
	# Une tuile est une surface ouverte : la paroi est un plan, c'est sa PLACE qui bouge (le centre de sa boîte).
	var taille := func(t: RefCounted) -> Vector3:
		return (t.tuiles[plaque].vers_array_mesh() as ArrayMesh).get_aabb().get_center() if t.tuiles.has(plaque) else Vector3.ZERO
	var s_epais: Vector3 = taille.call(t_epais)
	ed._histoire.undo()
	_egal(ed._retrait, 0.0, "Ctrl+Z : rendu au neutre")
	_vrai((ed._boutons_cran["neutre"] as Button).button_pressed and not (ed._boutons_cran["epais"] as Button).button_pressed,
		"… et le bouton suit")
	var s_neutre: Vector3 = taille.call(ed._temoin_de(c))
	# La paroi à l'air libre est en −r dans sa tuile : elle avance de 0,25 du neutre à l'épais, le long de sa normale.
	_vrai(is_equal_approx(s_epais.distance_to(s_neutre), 0.25) and is_equal_approx(s_epais.y, s_neutre.y),
		"la paroi à l'air libre avance de 0,25 à l'épais (%s contre %s)" % [s_epais, s_neutre])
	ed._histoire.redo()
	_egal(ed._retrait, -0.25, "Ctrl+Y : de nouveau épais")
	# Le monde de la couche suit : trancher son témoin (étape 3) prend le lot du témoin calculé à CE cran.
	await ed._trancher_temoin_de_la_couche()
	_egal(str(c["source"]), "witness@-0.25", "trancher le témoin de la couche : la source dit le cran")
	(ed._boutons_cran["neutre"] as Button).pressed.emit()
	_egal(str(c["source"]), "witness@0.0", "changer de cran retranche la couche : sa source suit")
	# L'eau suit le cran : la nappe d'une mer de niveau 2.
	ed._vue.montrer_plan_mer(2, {})
	_vrai(is_equal_approx(ed._vue._plan_mer.position.y, 2.95), "Centred : la mer de niveau 2 à 2,95 (%s)"
		% ed._vue._plan_mer.position.y)
	(ed._boutons_cran["epais"] as Button).pressed.emit()
	ed._vue.montrer_plan_mer(2, {})
	_vrai(is_equal_approx(ed._vue._plan_mer.position.y, 2.7) and is_equal_approx(float(ed._vue.plan_mer_visible()), 2.0),
		"Outset : à 2,7, sous un étage flottant (et la hauteur choisie relue : 2)")
	ed._vue.montrer_plan_mer(null)
	ed._enregistrer()
	var relu: Dictionary = Projet.depuis_texte(FileAccess.get_file_as_string(ed._projet), [])
	_vrai(not relu.is_empty() and relu["retrait"] == -0.25, "enregistré : le cran du monde revient")
	# Rendu à l'aminci, comme la fumée l'a trouvé.
	(ed._boutons_cran["aminci"] as Button).pressed.emit()
	_egal(ed._retrait, 0.25, "rendu à l'aminci")
	ed._aller_a("monde")
	_crans_finis = true


## LA CAGE DE LA TUILE (Jordan, 10 octobre 2026), par un VRAI survol à travers la caméra. Attendu écrit à la main : un
## point du DESSUS de la case la plus haute d'une colonne, (x + 0,3 ; y + 1 ; z + 0,6), est dans la tuile centrée sur le
## point entier le plus proche, (x, y + 1, z + 1) — sa cage est ce centre ± ½.
var _cage_finie := false


func _la_cage(ed: Control) -> void:
	ed._aller_a("witness")
	ed._regler_edition(false)
	await process_frame
	var cam: Camera3D = ed._vue._camera
	var cases: Dictionary = ed._vue.cases_du_temoin
	_vrai(cases.size() == BM.cases(0).size(), "la vue a les cases du témoin (%d)" % cases.size())
	# La colonne la plus haute du bloc, vue d'au-dessus.
	var haut := Vector3i(0, -999, 0)
	for c: Vector3i in cases:
		if c.y > haut.y:
			haut = c
	var p := Vector3(haut.x + 0.3, haut.y + 1, haut.z + 0.6)
	cam.global_position = p + Vector3(0.0, 6.0, 0.01)
	cam.look_at(p)
	await process_frame
	var ecran: Vector2 = (ed._vue as Control).get_global_rect().position + cam.unproject_position(p)
	var survol := InputEventMouseMotion.new()
	survol.position = ecran
	survol.global_position = ecran
	root.push_input(survol)
	await process_frame
	await process_frame
	var attendu := Vector3(haut.x, haut.y + 1, haut.z + 1)
	_vrai(ed._vue._cage.visible and (ed._vue._cage.position as Vector3).is_equal_approx(attendu),
		"survoler le dessus de la case %s montre la cage de la tuile centrée en %s (%s)" % [haut, attendu, ed._vue._cage.position])
	ed._case_cage.button_pressed = false
	await process_frame
	_vrai(not ed._vue._cage.visible, "décochée, la cage disparaît")
	ed._case_cage.button_pressed = true
	# En édition : la cage est celle de la tuile qu'on édite, centrée sur le sommet de son occurrence + (1, 1, 1).
	ed._regler_edition(true)
	await process_frame
	var mo: Node3D = ed._modeleur
	_vrai(mo.occurrence >= 0, "en édition, une occurrence est active")
	if mo.occurrence >= 0:
		var s: Vector3i = mo.temoin.occurrences[mo.occurrence]["sommet"]
		await process_frame
		_vrai(ed._vue._cage.visible and (ed._vue._cage.position as Vector3).is_equal_approx(Vector3(s) + Vector3.ONE),
			"en édition, la cage entoure la tuile qu'on édite (sommet %s + 1 = %s)" % [s, ed._vue._cage.position])
	ed._regler_edition(false)
	ed._aller_a("monde")
	await process_frame
	_vrai(not ed._vue._cage.visible, "dans World, pas de cage")
	_cage_finie = true


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


## La tuile d'une clé dans un lot (son nom nu), ou null.
func _tuile_du_lot(lot: MeshLibrary, cle: String) -> Mesh:
	if lot == null:
		return null
	var id := lot.find_item_by_name(cle)
	return lot.get_item_mesh(id) if id >= 0 else null


## La FORME d'un maillage : ses positions (au millième) et son aire — indépendante de la triangulation.
func _forme_de(mesh: Mesh) -> String:
	if mesh == null:
		return "aucune"
	var pos := {}
	var aire := 0.0
	for s in mesh.get_surface_count():
		var a: Array = mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx = a[Mesh.ARRAY_INDEX]
		var ordre: PackedInt32Array = (idx as PackedInt32Array) if idx != null else PackedInt32Array(range(v.size()))
		for i in range(0, ordre.size() - 2, 3):
			aire += (v[ordre[i + 1]] - v[ordre[i]]).cross(v[ordre[i + 2]] - v[ordre[i]]).length() * 0.5
		for p in v:
			pos["%d,%d,%d" % [roundi(p.x * 1000.0), roundi(p.y * 1000.0), roundi(p.z * 1000.0)]] = true
	var l: Array = pos.keys()
	l.sort()
	return "%s|%.4f" % [";".join(PackedStringArray(l)).md5_text(), aire]


## LES VARIANTES VOULUES (Jordan, 4 octobre 2026) — par les VRAIS boutons : dans Witness geometry, une variante de la
## paroi naît d'une copie, Ctrl+Z / Ctrl+Y ; on sculpte son cœur ; L'ATELIER VARIANTS (13 octobre 2026) : World n'a plus
## qu'un renvoi, l'atelier prend l'outil Variant et Échap rend celui de World, la liste (photo, copies posées recomptées
## ici dans la grille), « Sculpt » et « New variant of this tile » qui mènent à Geometry ; le monde peint de la forme du témoin
## pose base ET variante selon le tirage (attendu recalculé ici : hachage de Python écrit dans `test_variantes`, ici la
## même règle déroulée à la main sur les sommets de la paroi), l'outil Variant fait passer UNE tuile à la suivante
## (un Ctrl+Z), un poids à 0 l'écarte, la sélection impose la variante 1, le projet enregistre poids et choix.
var _variantes_finies := false


func _les_variantes(ed: Control) -> void:
	var v0: int = ed._histoire.get_version()
	var n_couches: int = ed._couches.size()
	ed._aller_a("witness")
	ed._nouvelle_couche()
	ed._regler_edition(true)
	var mo: Node3D = ed._modeleur
	var t: RefCounted = mo.temoin
	var paroi := "mb_plaque_b2h2_dehors"
	var var1 := paroi + "_var1"
	var occ: Array = t.occurrences_de(paroi)
	mo.activer(occ[occ.size() / 2])
	ed._variantes.dire_temoin()
	var creer: Button = null
	for b in ed.find_children("*", "Button", true, false):
		if (b as Button).text == "New variant from this copy":
			creer = b
	_vrai(creer != null and not creer.disabled, "Witness geometry : « New variant from this copy » existe et sert")
	if creer == null:
		return
	creer.pressed.emit()
	_vrai(t.tuiles.has(var1) and mo.cle == var1 and t.occurrences_de(var1).size() == 1,
		"une variante neuve : la copie en édition la montre (%s)" % mo.cle)
	_egal(_sans_partenaire(t), 0, "la variante copie la base : aucun joint ouvert")
	ed._variantes.dire_temoin()
	_vrai(ed._variantes.etiquette_temoin.text.contains("variant 1") and ed._variantes.montrer.get_selected_id() == 1,
		"la section le dit (%s)" % ed._variantes.etiquette_temoin.text)
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_vrai(not t.tuiles.has(var1) and mo.cle == paroi, "UN Ctrl+Z défait la variante")
	ed._unhandled_key_input(_cle(KEY_Y, true))
	_vrai(t.tuiles.has(var1) and mo.cle == var1, "Ctrl+Y la refait")
	# Son cœur sculpté (à la main : un sommet intérieur relevé), la base ne bouge pas.
	var m1: RefCounted = t.tuiles[var1]
	var base_avant: PackedVector3Array = (t.tuiles[paroi].sommets as PackedVector3Array).duplicate()
	for i in m1.sommets.size():
		var p: Vector3 = m1.sommets[i]
		if absf(p.x) < 0.45 and absf(p.y) < 0.45 and absf(p.z) < 0.45:
			m1.sommets[i] = p + Vector3(0, 0.04, 0)
			break
	ed._temoin_modifie(t)
	_vrai(t.tuiles[paroi].sommets == base_avant and t.tuiles[var1].sommets != base_avant, "la variante a son propre cœur")
	# LE MONDE : la forme du témoin peinte dans cette couche ; la paroi pose sa base OU sa variante, par le tirage.
	ed._peindre_la_forme_du_temoin()
	var m: Node = ed._vue.monde()
	var rendu: GridMap = m.get_node("Rendu")
	var lot: MeshLibrary = rendu.mesh_library
	_vrai(lot.find_item_by_name(var1) >= 0, "World : le lot de la couche porte la variante")
	var justes := 0
	var parois := 0
	var vues := {}
	var un_sommet = null
	for c in rendu.get_used_cells():
		var nom: String = lot.get_item_name(rendu.get_cell_item(c))
		if MB.cle_de_tuile(nom) != paroi:
			continue
		parois += 1
		vues[nom] = true
		# La règle, déroulée : deux tuiles de poids 1, h mod 2.
		if nom == (paroi if MB.hachage_du_sommet(c) % 2 == 0 else var1):
			justes += 1
		if un_sommet == null and nom == paroi:
			un_sommet = c
	_vrai(parois > 100 and justes == parois and vues.size() == 2,
		"la paroi du monde pose base et variante selon le tirage (%d / %d)" % [justes, parois])
	if un_sommet == null:
		return
	# L'ATELIER VARIANTS (Jordan, 13 octobre 2026) : World n'a plus que le renvoi ; l'outil de World d'avant est Dig.
	var dans_world := []
	var renvoi: Button = null
	for b in ed._droite.find_children("*", "Button", true, false):
		if (b as Button).text in ["Variant tool", "Back to random everywhere", "Apply"]:
			dans_world.append((b as Button).text)
		if (b as Button).text == "Variants workspace":
			renvoi = b
	_vrai(dans_world.is_empty() and renvoi != null,
		"World ne garde qu'un renvoi vers l'atelier Variants (outils de variantes restés dans World : %s)" % [dans_world])
	if renvoi == null:
		return
	ed._choisir_outil("creuser")
	renvoi.pressed.emit()
	await process_frame
	_vrai(ed._atelier == "variantes" and ed._vue.outil == "variante" and ed._vue.mode == "monde",
		"le renvoi ouvre l'atelier Variants : le monde dans la vue, l'outil Variant")
	_vrai(ed._droite_variantes.visible and not ed._droite.visible and ed._section_couches.visible,
		"Variants : sa barre de droite, pas celle de World ; la liste des couches (poids et choix sont à la couche)")
	_vrai(ed._variantes.bouton_outil.button_pressed and ed._droite_variantes.is_ancestor_of(ed._variantes.bouton_outil)
		and not (ed._boutons_outil["creuser"] as Button).button_pressed, "l'outil Variant est enfoncé, seul, dans sa barre")
	var teintes: Dictionary = ATPalette.TEINTES_ATELIER
	var pareilles := 0
	for a in teintes:
		if a != "variantes" and (teintes[a] as Color).is_equal_approx(teintes.get("variantes", Color.BLACK)):
			pareilles += 1
	_vrai(teintes.has("variantes") and pareilles == 0, "une teinte à lui, qu'aucun autre atelier ne porte")
	var guide: Array = []
	for g in Guide.propositions(ed._contexte_du_guide())["lignes"]:
		guide.append(g[1])
	_vrai("the next variant of the tile" in guide and "back to the random draw" in guide,
		"le guide dit les deux clics de l'atelier (%s)" % [guide])
	# LA LISTE : les tuiles qui ont des variantes — la paroi seule ; ses copies posées recomptées ICI dans la grille.
	var n_base := 0
	var n_var1 := 0
	for c in rendu.get_used_cells():
		var nom: String = lot.get_item_name(rendu.get_cell_item(c))
		n_base += 1 if nom == paroi else 0
		n_var1 += 1 if nom == var1 else 0
	var lignes: Dictionary = ed._variantes._lignes
	_vrai(lignes.keys() == [paroi], "la liste : la paroi, seule tuile à variantes (%s)" % [lignes.keys()])
	if lignes.has(paroi):
		var texte: String = (lignes[paroi] as Button).text
		_vrai(texte.contains("1 variant(s)") and texte.contains("placed %d / %d" % [n_base, n_var1]),
			"… sa ligne dit 1 variante et les copies posées, base / variante 1 (%s ; attendu %d / %d)"
			% [texte.replace("\n", " · "), n_base, n_var1])
		_vrai((lignes[paroi] as Button).icon is Texture2D, "… avec la photo de la tuile")
		(lignes[paroi] as Button).pressed.emit()
		_vrai(ed._variantes.cle_designee == paroi and ed._variantes._compteurs.size() == 2
			and ed._variantes._boutons_sculpter.size() == 2, "un clic sur la ligne : les poids de la paroi (base, variante 1)")
	# L'OUTIL VARIANT : un clic, la suivante ; Ctrl+Z ; le clic droit rend le tirage.
	ed._vue.variante_cliquee.emit({"sommet": un_sommet}, MOUSE_BUTTON_LEFT)
	_egal(lot.get_item_name(rendu.get_cell_item(un_sommet)), var1, "un clic : cette tuile passe à la variante 1")
	_vrai(ed._variantes.cle_designee == paroi and ed._variantes._compteurs.size() == 2,
		"la ligne des poids parle de sa clé (base et variante 1)")
	_vrai((ed._variantes._lignes[paroi] as Button).text.contains("placed %d / %d" % [n_base - 1, n_var1 + 1]),
		"la liste suit le clic (une paroi de plus en variante 1)")
	ed._vue.variante_cliquee.emit({"sommet": un_sommet}, MOUSE_BUTTON_LEFT)
	_egal(lot.get_item_name(rendu.get_cell_item(un_sommet)), paroi, "un second clic : elle revient à la base")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_egal(lot.get_item_name(rendu.get_cell_item(un_sommet)), var1, "Ctrl+Z : la variante 1 revient")
	ed._vue.variante_cliquee.emit({"sommet": un_sommet}, MOUSE_BUTTON_RIGHT)
	_vrai(not (m.choix as Dictionary).has(un_sommet) and lot.get_item_name(rendu.get_cell_item(un_sommet)) == paroi,
		"le clic droit rend le tirage (la base, ici)")
	# ÉCHAP : World, et l'outil de World d'avant (Dig) revient ; plus aucun clic ne change de variante.
	ed._unhandled_key_input(_cle(KEY_ESCAPE))
	await process_frame
	_vrai(ed._atelier == "monde" and ed._vue.outil == "creuser" and (ed._boutons_outil["creuser"] as Button).button_pressed
		and not ed._variantes.bouton_outil.button_pressed, "Échap : World, avec Dig, l'outil d'avant (%s, %s)"
		% [ed._atelier, ed._vue.outil])
	ed._aller_a("variantes")
	_egal(ed._vue.outil, "variante", "revenu dans l'atelier, l'outil Variant est repris")
	# LES POIDS : la variante à 0, plus aucune ; Ctrl+Z.
	ed._variantes.designer(paroi)
	(ed._variantes._compteurs[1] as SpinBox).value = 0
	var restantes := 0
	for c in rendu.get_used_cells():
		if lot.get_item_name(rendu.get_cell_item(c)) == var1:
			restantes += 1
	_egal(restantes, 0, "poids de la variante à 0 : le tirage ne la pose plus")
	_egal((ed._variantes.ligne_poids.get_child(6) as Label).text, "×0", "… et sa ligne le compte (×0)")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	restantes = 0
	for c in rendu.get_used_cells():
		if lot.get_item_name(rendu.get_cell_item(c)) == var1:
			restantes += 1
	_vrai(restantes > 50 and (ed._variantes._compteurs[1] as SpinBox).value == 1, "Ctrl+Z rend le poids et les variantes")
	# LA SÉLECTION : toute la forme, « Variant 1 », Apply → chaque paroi la montre.
	var tout := {}
	for c in ed._vue.cases().get_used_cells():
		tout[c] = true
	ed._vue.regler_selection(tout)
	ed._variantes.choix_selection.select(2)
	ed._variantes.appliquer_a_la_selection()
	var toutes_v1 := true
	for c in rendu.get_used_cells():
		var nom: String = lot.get_item_name(rendu.get_cell_item(c))
		if MB.cle_de_tuile(nom) == paroi and nom != var1:
			toutes_v1 = false
	_vrai(toutes_v1, "Apply « Variant 1 » sur la sélection : chaque paroi la montre")
	ed._vue.regler_selection({})
	# L'ENREGISTREMENT : poids et choix dans le .mbproj, relus.
	(ed._variantes._compteurs[0] as SpinBox).value = 3
	ed._enregistrer()
	var erreurs: Array = []
	var relu: Dictionary = Projet.depuis_texte(FileAccess.get_file_as_string(ed._projet), erreurs)
	var c_relue: Dictionary = (relu.get("couches", []) as Array)[ed._active] if not relu.is_empty() else {}
	_vrai(erreurs.is_empty() and (c_relue.get("poids", {}) as Dictionary).get(paroi, []) == [3, 1]
		and (c_relue.get("choix", {}) as Dictionary).size() == (m.choix as Dictionary).size() and (m.choix as Dictionary).size() > 100,
		"le projet enregistre poids et choix de la couche (%s, %d)" % [c_relue.get("poids", {}), (c_relue.get("choix", {}) as Dictionary).size()])
	# « SCULPT » (variante 1) : Witness geometry, en édition, sur une copie qui MONTRE la variante 1. Aucun geste.
	var version: int = ed._histoire.get_version()
	(ed._variantes._boutons_sculpter[1] as Button).pressed.emit()
	await process_frame
	_vrai(ed._atelier == "witness" and ed._vue.edition and mo.temoin == t and mo.cle == var1
		and t.affectation.has(t.occurrences[mo.occurrence]["sommet"]),
		"« Sculpt » (variante 1) : Geometry, en édition, sur une copie qui la montre (%s, %s)" % [ed._atelier, mo.cle])
	_egal(ed._histoire.get_version(), version, "… sans un geste dans l'historique")
	_egal(ed._vue.outil, "creuser", "… et l'outil de World est rendu en quittant l'atelier")
	# « NEW VARIANT OF THIS TILE » : la variante 2 naît d'une copie de la BASE, dans Geometry ; UN Ctrl+Z.
	ed._aller_a("variantes")
	ed._variantes.designer(paroi)
	var var2 := paroi + "_var2"
	ed._variantes.bouton_nouvelle.pressed.emit()
	await process_frame
	_vrai(ed._atelier == "witness" and ed._vue.edition and t.tuiles.has(var2) and mo.cle == var2
		and t.occurrences_de(var2).size() == 1, "« New variant of this tile » : Geometry, la copie en édition montre la variante 2")
	_vrai(t.tuiles.has(var2) and (t.tuiles[var2].sommets as PackedVector3Array) == base_avant,
		"… copiée de la BASE (pas de la variante 1)")
	_egal(_sans_partenaire(t), 0, "… aucun joint ouvert")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_vrai(not t.tuiles.has(var2), "UN Ctrl+Z la défait")
	ed._aller_a("monde")
	# Tout défaire, puis la couche supprimée : la suite retrouve le monde d'avant.
	while ed._histoire.get_version() > v0 and ed._histoire.has_undo():
		ed._histoire.undo()
	if ed._couches.size() > n_couches:
		ed._supprimer_couche()
	_egal(ed._couches.size(), n_couches, "(la couche de l'essai est retirée)")
	# Ce que l'essai a laissé en attente s'écrit maintenant (la suite juge la barre « Saved »).
	ed._minuterie_temoin.stop()
	ed._enregistrer_le_temoin_modele(true)
	ed._enregistrer()
	_variantes_finies = true


## L'ATELIER FOLIAGE (Jordan, 6 octobre 2026) — mené par de VRAIS clics à travers la caméra, sur un plateau peint et
## habillé du témoin (l'aminci : son sol VU est un quart de case sous le dessus des cases). L'arbre d'essai est écrit par
## `arbre_d_essai.gd` : ses mesures (bas −0,3, haut 2,3) sont les attendus, écrits à la main là-bas.
## ⚠ CE QUI EST ATTENDU NE PASSE PAS PAR LA RÈGLE : le sol vu à 0,75 (mesuré par le Play test sur le même lot), les
## distances entre plants recalculées ici, le plateau et ses bords écrits ici.
var _feuillage_fini := false


func _le_feuillage(ed: Control) -> void:
	const Arbre := preload("res://DEV_TOOLS/arbre_d_essai.gd")
	const FeuillageVue := preload("res://app/feuillage_vue.gd")
	var af: RefCounted = ed._feuillage
	ed._aller_a("monde")
	var sol := {}
	for x in range(300, 308):
		for z in range(300, 308):
			sol[Vector3i(x, 20, z)] = true
	ed._coup_commence()
	ed._touche({"poser": sol, "effacer": {}}, "Add")
	ed._coup_fini()
	ed._vue.monde().lot = BM.librairie(BM.RETRAIT_AMINCI)["lot"]
	ed._aller_a("feuillage")
	_vrai(ed._atelier == "feuillage" and ed._vue.outil == "feuillage" and ed._vue.mode == "monde",
		"Foliage : le monde dans la vue, l'outil du feuillage")
	_vrai(ed._droite_feuillage.visible and not ed._droite.visible and not ed._droite_fluides.visible,
		"Foliage : sa barre de droite, et pas celles de World ni de Fluids")
	_vrai(ed._vue.feuillage.visible, "le feuillage se dessine dans Foliage")
	# L'import, par la route du dialogue.
	var glb := "user://fumee/arbre_d_essai.glb"
	_vrai(Arbre.ecrire(glb) == "", "l'arbre d'essai s'écrit")
	ed._action_fichier = "feuillage"
	ed._fichier_choisi(glb)
	_egal(af.modeles.size(), 1, "« Import .glb… » : un modèle")
	if af.modeles.is_empty():
		return
	var m: Dictionary = af.modeles[0]
	var dossier: String = ed._projet.get_basename() + "_foliage"
	_vrai(str(m["chemin"]).begins_with(dossier) and FileAccess.file_exists(m["chemin"]),
		"le .glb est COPIÉ dans le projet (%s)" % m["chemin"])
	_vrai(absf(float(m["decalage"]) - 0.3) < 1e-3 and absf(float(m["hauteur"]) - Arbre.HAUT) < 1e-3,
		"posé sur sa base par défaut : décalage 0,3 (son bas à −0,3), haut 2,3")
	_vrai(af.socle.modele == m and af.reglage_modele.visible, "le socle montre le modèle")
	ed._histoire.undo()
	_egal(af.modeles.size(), 0, "Ctrl+Z défait l'import")
	ed._histoire.redo()
	_egal(af.modeles.size(), 1, "Ctrl+Y le refait")
	m = af.modeles[0]
	(af.curseurs["echelle_alea"] as HSlider).value = 0.0
	_vrai(float(m["echelle_alea"]) == 0.0, "le curseur « Random size » règle le modèle")
	var r: float = float(m["rayon"]) * float(m["echelle"])
	# Un clic au milieu du plateau, visé d'en haut sur le dessus des cases (y = 21).
	var ou: Vector2 = _viser_d_en_haut(ed._vue, Vector3(303.5, 21, 303.5))
	_clic_vue(ed._vue, ou)
	_egal(af.plants.size(), 1, "un clic plante un arbre")
	if af.plants.is_empty():
		return
	var p: Vector3 = af.plants[0]["p"]
	_vrai(absf(p.x - 303.5) < 0.05 and absf(p.z - 303.5) < 0.05 and p.y > 20.7 and p.y < 20.8,
		"… là où l'on a cliqué, sur la surface VUE des tuiles (y = %.3f, un quart sous le dessus des cases)" % p.y)
	_egal(ed._vue.feuillage.nombre_dessine(m["id"]), 1, "il est dessiné")
	var mat = ed._vue.feuillage.multimeshes(m["id"])[0].multimesh.mesh.surface_get_material(0)
	_vrai(mat is ShaderMaterial and (mat as ShaderMaterial).shader.code.contains("INSTANCE_CUSTOM"),
		"il bouge dans le vent (le matériau du vent)")
	ed._histoire.undo()
	_vrai(af.plants.is_empty() and ed._vue.feuillage.nombre_dessine(m["id"]) == 0, "Ctrl+Z l'enlève")
	ed._histoire.redo()
	_vrai(af.plants.size() == 1 and ed._vue.feuillage.nombre_dessine(m["id"]) == 1, "Ctrl+Y le replante")
	# Au bord du plateau : refusé en voisinage libre, accepté en débordement.
	var bord: Vector2 = _viser_d_en_haut(ed._vue, Vector3(300.4, 21, 305.5))
	_clic_vue(ed._vue, bord)
	_vrai(af.plants.size() == 1 and ed._rapport.text.contains("Not planted"),
		"au bord, « Planted · free » refuse (l'empreinte déborde) et le dit")
	(af._boutons_mode["sol_debord"] as Button).pressed.emit()
	_clic_vue(ed._vue, bord)
	_egal(af.plants.size(), 2, "au même bord, « Planted · overflow » plante")
	# Dans le vide.
	(af._boutons_mode["air"] as Button).pressed.emit()
	ed._vue.regler_etage(25)
	var air: Vector2 = _viser_d_en_haut(ed._vue, Vector3(320.5, 25, 320.5))
	_clic_vue(ed._vue, air)
	_vrai(af.plants.size() == 3 and (af.plants[2]["p"] as Vector3).distance_to(Vector3(320.5, 25, 320.5)) < 0.05
		and af.plants[2]["mode"] == "air", "« In the air » plante sur le plan de l'étage, au-dessus du vide")
	ed._vue.regler_etage(0)
	# Le clic droit enlève le premier.
	(af._boutons_mode["sol_libre"] as Button).pressed.emit()
	ou = _viser_d_en_haut(ed._vue, Vector3(303.5, 21, 303.5))
	_clic_vue(ed._vue, ou, MOUSE_BUTTON_RIGHT)
	_vrai(af.plants.size() == 2 and not af.plants.any(func(pl): return (pl["p"] as Vector3).distance_to(p) < 0.01),
		"le clic droit enlève le plant visé")
	# Le pinceau, voisinage libre : des plants, jamais deux à moins de deux empreintes, tous sur le plateau.
	(af._boutons_outil["pinceau"] as Button).pressed.emit()
	(af.curseurs["pinceau_rayon"] as HSlider).value = 3.0
	(af.curseurs["pinceau_essais"] as HSlider).value = 40.0
	var avant: int = af.plants.size()
	_viser_d_en_haut(ed._vue, Vector3(303.5, 21, 303.5))
	_clic_vue(ed._vue, ou)
	var neufs: Array = af.plants.slice(avant)
	_vrai(neufs.size() >= 4, "un coup de pinceau plante (%d)" % neufs.size())
	var trop_pres := 0
	var hors := 0
	for i in neufs.size():
		var a: Vector3 = neufs[i]["p"]
		if a.x < 300.0 or a.x > 308.0 or a.z < 300.0 or a.z > 308.0 or a.y < 20.7 or a.y > 20.8:
			hors += 1
		for j in range(i + 1, neufs.size()):
			var b: Vector3 = neufs[j]["p"]
			if Vector2(a.x - b.x, a.z - b.z).length() < 2.0 * r - 1e-4:
				trop_pres += 1
	_vrai(trop_pres == 0 and hors == 0, "… jamais deux à moins de deux empreintes (%d), tous sur le plateau (%d)"
		% [trop_pres, hors])
	ed._histoire.undo()
	_egal(af.plants.size(), avant, "UN Ctrl+Z défait tout le coup de pinceau")
	ed._histoire.redo()
	(af._boutons_outil["un"] as Button).pressed.emit()
	# Le décalage sur le socle.
	(af.curseurs["decalage"] as HSlider).value = -0.2
	_vrai(is_equal_approx(float(m["decalage"]), -0.2), "le curseur « Ground offset » enfonce le modèle")
	# L'enregistrement, puis la réouverture.
	var compte: int = af.plants.size()
	ed._enregistrer()
	var relu: Dictionary = Projet.depuis_texte(FileAccess.get_file_as_string(ed._projet), [])
	_vrai(not relu.is_empty() and (relu["feuillage"]["plants"] as Array).size() == compte
		and (relu["feuillage"]["modeles"] as Array).size() == 1
		and is_equal_approx(float(relu["feuillage"]["modeles"][0]["decalage"]), -0.2),
		"le projet enregistre le feuillage (%d plants, le modèle et son décalage)" % compte)
	await ed._ouvrir(ed._projet)
	_vrai(af.plants.size() == compte and af.modeles.size() == 1
		and ed._vue.feuillage.nombre_dessine(af.modeles[0]["id"]) == compte, "rouvert : les plants reviennent, dessinés")
	# Ailleurs que dans le monde, on ne les voit pas ; Échap rend World et son outil.
	ed._aller_a("witness")
	_vrai(not ed._vue.feuillage.visible, "le témoin ne montre pas le feuillage")
	ed._aller_a("feuillage")
	_vrai(ed._vue.feuillage.visible and ed._vue.outil == "feuillage", "de retour dans Foliage")
	ed._unhandled_key_input(_cle(KEY_ESCAPE))
	_vrai(ed._atelier == "monde" and ed._vue.outil != "feuillage" and ed._vue.feuillage.visible,
		"Échap rend World, son outil, et le feuillage reste visible dans le monde")
	_feuillage_fini = true


## PLAY EDIT (Jordan, 9 octobre 2026 : « contrôler le stickman pour se promener et avoir la barre de droite de l'atelier
## World pour éditer le monde, mais depuis la vue du personnage »). Par de VRAIS clics à travers la caméra du personnage :
## la case posée, ce qu'il foule qui suit (le décor rebâti), le clic droit qui creuse, Ctrl+Z, le clic du milieu qui
## tourne sans peindre, une lettre du personnage qui ne choisit pas d'outil, Échap qui rend World et sa visée.
## Attendus : le sol peint est la dalle y = 10 de `_play_test` (surface rendue à 10,75, une case de plus à 11,75).
func _play_edit(ed: Control) -> void:
	var vue = ed._vue
	ed._choisir_visee("grille")
	ed._choisir_outil("ajouter")
	vue._cible = Vector3(24.5, 11, 24.5)
	ed._aller_a("jeu")
	var p: CharacterBody3D = vue.personnage
	ed._aller_a("jeu_edit")
	_vrai(ed._atelier == "jeu_edit" and vue.personnage != null and vue.personnage == p,
		"Play edit depuis le Play test : le MÊME personnage, gardé où il est")
	_vrai(ed._droite.visible and ed._section_jeu.visible and ed._note_jeu_edit.visible and not ed._droite_jeu.visible,
		"Play edit : la barre de droite de World, les commandes du jeu et leur note")
	_vrai(vue.edition_en_jeu and vue.peint() and vue.visee == "sculpt" and not ed._bouton_naviguer.visible,
		"Play edit : la vue peint, en visée Sculpt, sans Navigate")
	if p == null:
		return
	for i in 90:
		await physics_frame
	_vrai(p.is_on_floor(), "Play edit : il se pose sur la dalle")
	# La case visée : deux cases devant lui, dans le sens où regarde la caméra.
	var loin := Vector3(-sin(vue._azimut), 0, -cos(vue._azimut))
	var pied: Vector3 = p.global_position + loin * 2.0
	var c := Vector3i(floori(pied.x), 11, floori(pied.z))
	var g: GridMap = vue.cases()
	_vrai(g.get_cell_item(c) == -1 and g.get_cell_item(c + Vector3i.DOWN) != -1, "la case visée %s est vide, sur la dalle" % c)
	var espace: PhysicsDirectSpaceState3D = vue._vue.find_world_3d().direct_space_state
	var sol_avant := _sol_du_decor(espace, c)
	for i in 3:
		await process_frame
	var ou: Vector2 = vue._camera.unproject_position(Vector3(c.x + 0.5, 11.0, c.z + 0.5))
	var avant: int = g.get_used_cells().size()
	_clic_vue(vue, ou)
	_vrai(g.get_cell_item(c) != -1 and g.get_used_cells().size() == avant + 1,
		"un clic gauche, vu du personnage, pose UNE case sur la dalle visée")
	for i in 3:
		await process_frame
	await physics_frame
	var sol_apres := _sol_du_decor(espace, c)
	_vrai(absf(sol_avant - 10.75) < 0.05 and absf(sol_apres - 11.75) < 0.05,
		"ce qu'il foule suit le geste : le décor rebâti (%.2f → %.2f)" % [sol_avant, sol_apres])
	# Le clic du milieu glissé tourne la caméra, sans peindre.
	var az: float = vue._azimut
	var milieu := InputEventMouseMotion.new()
	milieu.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	milieu.relative = Vector2(60, 0)
	milieu.position = ou
	vue._gui_input(milieu)
	vue._rendre_la_souris()
	_vrai(not is_equal_approx(vue._azimut, az) and g.get_used_cells().size() == avant + 1,
		"le clic du milieu glissé tourne la caméra, et ne peint rien")
	vue._azimut = az
	for i in 3:
		await process_frame
	# Le clic droit fait l'inverse : il creuse la case posée.
	ou = vue._camera.unproject_position(Vector3(c.x + 0.5, 12.0, c.z + 0.5))
	_clic_vue(vue, ou, MOUSE_BUTTON_RIGHT)
	_vrai(g.get_cell_item(c) == -1, "le clic droit creuse la case visée")
	for i in 3:
		await process_frame
	await physics_frame
	_vrai(absf(_sol_du_decor(espace, c) - 10.75) < 0.05, "… et le décor redescend")
	ed._histoire.undo()
	_vrai(g.get_cell_item(c) != -1, "Ctrl+Z rend la case creusée")
	ed._histoire.undo()
	_vrai(g.get_cell_item(c) == -1 and g.get_used_cells().size() == avant, "Ctrl+Z encore : le monde d'avant")
	# Une lettre du personnage ne choisit pas d'outil (S est Select dans World), B oui.
	_touche_physique(KEY_S, true)
	_touche_physique(KEY_S, false)
	_vrai(vue.outil == "ajouter", "Play edit : S fait reculer, il ne choisit pas Select")
	_touche_physique(KEY_B, true)
	_touche_physique(KEY_B, false)
	_vrai(vue.outil == "boite", "Play edit : B choisit la boîte")
	ed._choisir_outil("ajouter")
	_touche_physique(KEY_ESCAPE, true)
	_touche_physique(KEY_ESCAPE, false)
	await process_frame
	_vrai(ed._atelier == "monde" and vue.personnage == null and not vue.edition_en_jeu and vue.visee == "grille",
		"Échap rend World, sans personnage, et sa visée d'avant (Grid)")
	_play_edit_fini = true


## Le dessus du décor foulé au-dessus d'une case (le rayon tombe de haut, couche de collision 2) ; −INF si rien.
func _sol_du_decor(espace: PhysicsDirectSpaceState3D, c: Vector3i) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(c.x + 0.5, 30, c.z + 0.5), Vector3(c.x + 0.5, 0, c.z + 0.5), 2)
	var r := espace.intersect_ray(q)
	return -INF if r.is_empty() else (r["position"] as Vector3).y


## ── LE GUIDE DES RACCOURCIS (Jordan, 13 octobre 2026 — `app/guide.gd`) ────────────────────────────────────────────────
## Le guide flottant suit le contexte, et un modificateur VRAIMENT tenu (`Input.parse_input_event`) déplie sa branche.
## La section Shortcuts porte le reste. ⚠ Les attendus sont des MOTS écrits ici, pas relus dans `Guide`.
var _guide_fini := false


func _le_guide(ed: Control) -> void:
	var vue = ed._vue
	ed._aller_a("monde")
	ed._case_guide.button_pressed = true
	ed._choisir_outil("ajouter")
	vue.vider_selection()
	await process_frame
	_vrai(ed._guide.visible, "World : le guide est à l'écran")
	var t: String = ed._guide_texte.get_parsed_text()
	_vrai(t.contains("add matter") and t.contains("Alt ▸") and t.contains("brush size") and t.contains("Ctrl ▸")
		and t.contains("move the grid"), "Add, au repos : poser, et les branches Alt (taille) et Ctrl (la grille)")
	_vrai(ed._guide.position.x >= ed.LARGEUR_GAUCHE, "… en haut à gauche de la VUE, à droite de la barre de gauche")
	# Une sélection sous Select : les trois branches parlent d'elle.
	ed._choisir_outil("selectionner")
	vue.regler_selection({Vector3i(300, 0, 300): true})
	await process_frame
	t = ed._guide_texte.get_parsed_text()
	_vrai(t.contains("Ctrl ▸") and t.contains("move the selection") and t.contains("Alt ▸") and t.contains("widen")
		and t.contains("Shift ▸") and t.contains("extend it up"), "Select + sélection : Ctrl déplace, Alt élargit, Maj étend")
	# CTRL TENU : sa branche seule.
	_tenir(KEY_CTRL, true)
	await process_frame
	t = _sans_l_etage(ed._guide_texte.get_parsed_text())
	_vrai(t.begins_with("Ctrl ▸") and t.contains("move the selection up") and not t.contains("Alt ▸"),
		"Ctrl tenu : le guide montre la branche Ctrl, et elle seule (« %s »)" % t.left(60))
	_tenir(KEY_CTRL, false)
	_tenir(KEY_SHIFT, true)
	await process_frame
	t = _sans_l_etage(ed._guide_texte.get_parsed_text())
	_vrai(t.begins_with("Shift ▸") and t.contains("extend it up"), "Maj tenue : la branche Maj")
	_tenir(KEY_SHIFT, false)
	await process_frame
	_vrai(ed._guide_texte.get_parsed_text().contains("Alt ▸"), "relâchée : la racine revient")
	vue.vider_selection()
	# La section Shortcuts : ce que le guide ne montre pas (Tab, F1…), et pas ce qu'il montre.
	await process_frame
	var reste := PackedStringArray()
	for n in ed._grille_raccourcis.get_children():
		if n is Label:
			reste.append((n as Label).text)
	var reste_t := " | ".join(reste)
	_vrai(reste_t.contains("aim at the grid") and reste_t.contains("the user guide") and not reste_t.contains("add matter"),
		"Shortcuts : le reste (Tab, F1), pas ce que montre le guide")
	# Geometry : la section suit l'atelier, le guide aussi.
	ed._aller_a("witness")
	await process_frame
	_vrai(ed._section_raccourcis.visible and ed._guide_texte.get_parsed_text().contains("Tab"),
		"Geometry : le guide et les raccourcis du témoin")
	# Décoché : plus de guide.
	ed._aller_a("monde")
	ed._case_guide.button_pressed = false
	await process_frame
	_vrai(not ed._guide.visible, "décoché : plus de guide")
	ed._case_guide.button_pressed = true
	ed._aller_a("projet")
	await process_frame
	_vrai(not ed._guide.visible, "Project : pas de guide (pas de vue à mener)")
	ed._aller_a("monde")
	_guide_fini = true


## ── TOUT RACCOURCI A SON BOUTON (Jordan, 13 octobre 2026 : « rien qui est faisable en shortcut ne doit être pas faisable
## en bouton ») ── chaque raccourci CLAVIER de `Guide.entrees`, dans tous les contextes, a soit son bouton (le début de
## son texte à l'écran, cherché dans TOUT l'écran), soit sa place dans `Guide.SANS_BOUTON`. Puis les boutons qui ARMENT
## le prochain clic (Grid to matter), Undo / Redo, et une bascule suivie (X-ray) menés pour de vrai.
var _boutons_raccourcis_finis := false


func _textes_des_boutons(n: Node, l: PackedStringArray) -> void:
	if n is Button:
		l.append((n as Button).text)
	for e in n.get_children():
		_textes_des_boutons(e, l)


func _tout_raccourci_a_son_bouton(ed: Control) -> void:
	var Guide = load("res://app/guide.gd")
	var textes := PackedStringArray()
	_textes_des_boutons(ed, textes)
	var contextes: Array = [{"atelier": "jeu"}, {"atelier": "fluides"}, {"atelier": "fluides", "mer": true},
		{"atelier": "transitions"}, {"atelier": "feuillage"}, {"atelier": "variantes"}, {"atelier": "monde", "naviguer": true},
		{"atelier": "monde", "collage": [Vector3i.ZERO]}, {"atelier": "monde", "glisse": "rect"},
		{"atelier": "monde", "glisse": "salle"}]
	for a in ["monde", "jeu_edit"]:
		for o in ["ajouter", "creuser", "selectionner", "rect", "boite", "eau", "variante"]:
			for s in [false, true]:
				contextes.append({"atelier": a, "outil": o, "selection": s})
		for q in ["tunnel", "salle", "escalier"]:
			contextes.append({"atelier": a, "outil": "forme", "quoi": q})
	for a in ["witness", "texture"]:
		contextes.append({"atelier": a})
		for m in ["", "G", "knife", "cercle"]:
			contextes.append({"atelier": a, "edition": true, "modal": m})
		contextes.append({"atelier": a, "edition": true, "pinceau": true, "sculpt": true})
	var vus := 0
	var manquants := PackedStringArray()
	for c in contextes:
		for e in Guide.entrees(c):
			if not Guide.est_au_clavier(e):
				continue
			vus += 1
			var noms: Array = Guide.boutons_de(e)
			if noms.is_empty():
				if str(e[1]) not in Guide.SANS_BOUTON:
					manquants.append("%s|%s (%s) : ni bouton ni exemption" % [e[0], e[1], c.get("atelier")])
				continue
			for nom in noms:
				var trouve := false
				for t in textes:
					if t.begins_with(str(nom)):
						trouve = true
						break
				if not trouve and ("bouton « %s »" % nom) not in manquants:
					manquants.append("bouton « %s »" % nom)
	_vrai(vus > 60, "les raccourcis au clavier des contextes sont lus (%d)" % vus)
	_vrai(manquants.is_empty(), "chaque raccourci au clavier a son bouton à l'écran (manque : %s)" % ", ".join(manquants))
	# Le bouton « Grid to matter » arme le PROCHAIN clic : sans Ctrl, la grille va à la matière cliquée.
	var vue = ed._vue
	ed._aller_a("monde")
	ed._choisir_outil("ajouter")
	ed._compteur_etage.value = 0
	vue.clic_arme = ""
	# ⚠ LE MONDE ET LA CAMÉRA SONT CE QUE LES SECTIONS D'AVANT ONT LAISSÉ (16 octobre 2026 : rouge sur main aussi — deux
	# cases, toutes à l'étage 0) : le test pose sa colonne de quatre cases au-dessus du sol, puis cadre toute la matière (F).
	var colonne := {}
	for y in range(1, 5):
		colonne[Vector3i(3, y, 3)] = true
	ed._appliquer({"poser": colonne, "effacer": {}}, "Add")
	vue.cadrer_toute_la_matiere()
	var cible := Vector2(-1, -1)
	var cible_y := 0
	for gx in range(2, 18):
		for gy in range(2, 18):
			var p := Vector2(vue.size.x * gx / 20.0, vue.size.y * gy / 20.0)
			var r: Dictionary = Outils.rayon(vue._occupe_visible, vue._camera.project_ray_origin(p),
				vue._camera.project_ray_normal(p), vue.PORTEE, {})
			if r["touche"] and int(r["case"].y) != 0 and absi(int(r["case"].y)) <= int(ed._compteur_etage.max_value) \
					and cible.x < 0.0:
				cible = p
				cible_y = int(r["case"].y)
	_vrai(cible.x >= 0.0, "de la matière est à l'écran")
	if cible.x >= 0.0:
		var cases_avant: int = ed._occupees().size() if ed._occupees() != null else -1
		for b in _boutons_par_texte(ed, "Grid to matter"):
			(b as Button).pressed.emit()
		_vrai(vue.clic_arme == "etage", "Grid to matter : le prochain clic est armé")
		_souris(vue, cible, MOUSE_BUTTON_LEFT, true)
		_souris(vue, cible, MOUSE_BUTTON_LEFT, false)
		_vrai(int(ed._compteur_etage.value) == cible_y and vue.clic_arme == "",
			"… le clic met la grille à la matière (y = %d, attendu %d) et désarme" % [int(ed._compteur_etage.value), cible_y])
		var cases_apres: int = ed._occupees().size() if ed._occupees() != null else -1
		_vrai(cases_apres == cases_avant, "… et ne peint rien (%d → %d)" % [cases_avant, cases_apres])
	# Undo / Redo par leurs boutons de la barre de titre.
	ed._compteur_etage.value = 0
	var undo: Array = _boutons_par_texte(ed, "Undo")
	var redo: Array = _boutons_par_texte(ed, "Redo")
	_vrai(undo.size() == 1 and redo.size() == 1, "Undo et Redo sont dans la barre de titre")
	_boutons_raccourcis_finis = true


func _boutons_par_texte(n: Node, debut: String) -> Array:
	var l: Array = []
	if n is Button and (n as Button).text.begins_with(debut):
		l.append(n)
	for e in n.get_children():
		l.append_array(_boutons_par_texte(e, debut))
	return l


## ── LA SÉLECTION SUR PLUSIEURS TUILES (Jordan, 13 octobre 2026) ────────────────────────────────────────────────────────
## Un clic sur une face d'une tuile, Maj + clic sur une face d'une AUTRE tuile, G Z 0.05 Entrée : les deux faces montent
## d'un vingtième de case DANS LE MONDE (attendu : leur centre relu sous la pose de leur copie, + 0,05 en y), aucun joint
## ne s'ouvre (`_sans_partenaire`), UN Ctrl+Z rend les deux.
var _multi_fini := false


func _multi_tuiles(ed: Control) -> void:
	var vue = ed._vue
	ed._aller_a("witness")
	if not vue.edition:
		ed._input(_cle(KEY_TAB))
	var mo: Node3D = ed._modeleur
	if mo.temoin == null:
		_vrai(false, "multi-tuiles : pas de témoin lié")
		return
	# ⚠ LA VUE EST RENDUE TELLE QU'ON L'A TROUVÉE À LA FIN : la suite (le couteau traversant) en dépend.
	var vue_avant := [vue._camera.projection, vue._azimut, vue._elevation, vue._distance, vue._cible]
	if vue._camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		vue.basculer_ortho()
	vue._distance = 26.0
	vue.vue_de("face")
	vue.cadrer(Vector3(6, 6, 6))
	for i in 3:
		await process_frame
	ed._input(_cle(KEY_3))
	var cam: Camera3D = vue._camera
	# Deux points de l'écran qui tombent sur deux TUILES différentes (cherchés sur une grille de l'écran).
	var p1 := Vector2(-1, -1)
	var p2 := Vector2(-1, -1)
	var cle1 := ""
	for gx in range(2, 18):
		for gy in range(2, 18):
			var p := Vector2(vue.size.x * gx / 20.0, vue.size.y * gy / 20.0)
			var h: Dictionary = mo.temoin.rayon(cam.project_ray_origin(p), cam.project_ray_normal(p))
			if h.is_empty():
				continue
			if cle1 == "":
				cle1 = h["cle"]
				p1 = p
			elif h["cle"] != cle1 and p2.x < 0.0:
				p2 = p
	_vrai(p1.x >= 0.0 and p2.x >= 0.0, "deux tuiles différentes sont à l'écran")
	if p2.x < 0.0:
		return
	_souris(vue, p1, MOUSE_BUTTON_LEFT, true)
	_souris(vue, p1, MOUSE_BUTTON_LEFT, false)
	var occ1: int = mo.occurrence
	var f1: int = mo.sel_f.keys()[0] if mo.sel_f.size() == 1 else -1
	_souris(vue, p2, MOUSE_BUTTON_LEFT, true, false, true)
	_souris(vue, p2, MOUSE_BUTTON_LEFT, false, false, true)
	var occ2: int = mo.occurrence
	var cle2: String = mo.cle
	var f2: int = mo.sel_f.keys()[0] if mo.sel_f.size() == 1 else -1
	_vrai(cle2 != cle1 and mo.ailleurs.has(cle1) and (mo.ailleurs[cle1]["f"] as Dictionary).has(f1) and f2 >= 0,
		"Maj + clic sur une autre tuile : la sélection de la première est gardée (« %s » et « %s »)" % [cle1, cle2])
	var t1: RefCounted = mo.temoin.tuiles[cle1]
	var t2: RefCounted = mo.temoin.tuiles[cle2]
	var ps1: Transform3D = mo.temoin.occurrences[occ1]["pose"]
	var ps2: Transform3D = mo.temoin.occurrences[occ2]["pose"]
	var c1: Vector3 = ps1 * t1.centre(f1)
	var c2: Vector3 = ps2 * t2.centre(f2)
	for k in [KEY_G, KEY_Z, KEY_0, KEY_PERIOD, KEY_0, KEY_5, KEY_ENTER]:
		ed._input(_cle(k))
	t1 = mo.temoin.tuiles[cle1]
	t2 = mo.temoin.tuiles[cle2]
	var m1: Vector3 = ps1 * t1.centre(f1) - c1
	var m2: Vector3 = ps2 * t2.centre(f2) - c2
	var bride: float = mo.bride
	# L'ATTENDU, ÉCRIT ICI : chaque sommet monte de 0,05, sauf s'il est posé sur un plan de coupe HORIZONTAL (y = k + ½
	# dans le monde) — il y reste, sa section partagée l'y tient. Le centre monte de la moyenne.
	var a1 := _montee_attendue(t1, f1, ps1, 0.05 * bride)
	var a2 := _montee_attendue(t2, f2, ps2, 0.05 * bride)
	_vrai(bride > 0.0 and absf(m1.y - a1) < 1e-4 and absf(m2.y - a2) < 1e-4 and a1 > 0.0 and a2 > 0.0
		and Vector2(m1.x, m1.z).length() < 1e-4 and Vector2(m2.x, m2.z).length() < 1e-4,
		"G Z 0.05 : les DEUX faces montent ensemble dans le monde (%.3f / %.3f, %.3f / %.3f attendus ; bride %.2f)" % [m1.y, a1, m2.y, a2, bride])
	_egal(_sans_partenaire(mo.temoin), 0, "… sans ouvrir de joint")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	t1 = mo.temoin.tuiles[cle1]
	t2 = mo.temoin.tuiles[cle2]
	_vrai((ps1 * t1.centre(f1)).is_equal_approx(c1) and (ps2 * t2.centre(f2)).is_equal_approx(c2),
		"UN Ctrl+Z rend les deux faces")
	# Un clic simple oublie tout.
	_souris(vue, p1, MOUSE_BUTTON_LEFT, true)
	_souris(vue, p1, MOUSE_BUTTON_LEFT, false)
	_vrai(mo.ailleurs.is_empty(), "un clic sans Maj oublie la sélection des autres tuiles")
	mo.tout_choisir(false)
	if vue._camera.projection != vue_avant[0]:
		vue.basculer_ortho()
	vue._azimut = vue_avant[1]
	vue._elevation = vue_avant[2]
	vue._distance = vue_avant[3]
	vue.cadrer(vue_avant[4])
	_multi_fini = true


func _montee_attendue(t: RefCounted, f: int, ps: Transform3D, h: float) -> float:
	var somme := 0.0
	for i in t.faces[f]:
		var w: Vector3 = ps * t.sommets[i]
		somme += 0.0 if absf(w.y - floorf(w.y) - 0.5) < 0.0005 else h
	return somme / float((t.faces[f] as PackedInt32Array).size())


## La première ligne du guide est l'étage, dans World (13 octobre 2026) : les branches viennent après.
func _sans_l_etage(t: String) -> String:
	if t.begins_with("Floor y ="):
		return t.substr(t.find("\n") + 1)
	return t


## ── LES INFOS DE LA VUE, L'ÉTAGE DU GUIDE, LE REPÈRE DE TAILLE, LA GRILLE (Jordan, 13 octobre 2026) ─────────────────────
## `app/infos_vue.gd`, `app/silhouette.gd`, les lignes majeures de `Vue`. ⚠ LES ATTENDUS SONT ÉCRITS ICI : la taille d'une
## sélection comptée à la main, la hauteur du personnage relue sur les CONSTANTES de `personnage.gd`, les niveaux de
## ligne écrits en dur.
var _infos_finies := false


func _les_infos_de_la_vue(ed: Control) -> void:
	const Personnage := preload("res://app/personnage.gd")
	var vue = ed._vue
	ed._aller_a("monde")
	ed._case_guide.button_pressed = true
	ed._infos_vue.case_infos.button_pressed = true
	ed._infos_vue.case_silhouette.button_pressed = true
	ed._choisir_visee("grille")
	ed._choisir_outil("ajouter")
	vue.vider_selection()
	ed._compteur_etage.value = 0
	await process_frame
	await process_frame
	var infos: PanelContainer = ed._infos_vue
	_vrai(infos.visible, "World : le panneau d'infos est à l'écran")
	var t: String = infos._texte.get_parsed_text()
	_vrai(t.contains("Layer") and t.contains("Floor  y = 0") and t.contains("Tool  Add"),
		"il dit la couche, l'étage (y = 0) et l'outil (« %s »)" % t.replace("\n", " / "))
	var droite: Control = ed._droite
	_vrai(infos.position.x + infos.size.x <= droite.position.x + 0.5 and infos.position.x > ed.LARGEUR_GAUCHE,
		"en haut à DROITE de la vue, à gauche de la barre de droite (%s, barre à %s)" % [infos.position, droite.position.x])
	# L'ÉTAGE EN TÊTE DU GUIDE, et PgUp le change.
	_vrai(ed._guide_texte.get_parsed_text().begins_with("Floor y = 0"), "le guide commence par l'étage : « Floor y = 0 »")
	ed._unhandled_key_input(_cle(KEY_PAGEUP))
	await process_frame
	_egal(int(vue.etage), 1, "PgUp monte la grille d'un étage")
	_vrai(ed._guide_texte.get_parsed_text().begins_with("Floor y = 1"),
		"… et le guide le dit tout de suite : « Floor y = 1 » (« %s »)" % ed._guide_texte.get_parsed_text().left(30))
	_vrai(infos._texte.get_parsed_text().contains("Floor  y = 1"), "… le panneau d'infos aussi")
	ed._unhandled_key_input(_cle(KEY_PAGEDOWN))
	await process_frame
	_vrai(ed._guide_texte.get_parsed_text().begins_with("Floor y = 0"), "PgDn : « Floor y = 0 »")
	ed._aller_a("witness")
	await process_frame
	_vrai(not ed._guide_texte.get_parsed_text().contains("Floor y"), "Geometry : pas d'étage dans le guide (pas de grille)")
	_vrai(not infos.visible, "Geometry : pas de panneau d'infos")
	ed._aller_a("monde")
	await process_frame

	# UNE SÉLECTION EN L, comptée à la main : un plancher de 12 × 8 (96 cases) à l'étage 0, et une colonne de 2 × 2 sur
	# deux étages (8 cases) dans un coin — 104 cases, contenues dans 12 × 3 × 8.
	var sel := {}
	for x in 12:
		for z in 8:
			sel[Vector3i(400 + x, 0, 400 + z)] = true
	for x in 2:
		for y in [1, 2]:
			for z in 2:
				sel[Vector3i(400 + x, y, 400 + z)] = true
	ed._choisir_outil("selectionner")
	vue.regler_selection(sel)
	await process_frame
	t = infos._texte.get_parsed_text()
	_vrai(t.contains("Selection  104 cells") and t.contains("12 × 3 × 8"),
		"la sélection en L : 104 cases, 12 × 3 × 8 (« %s »)" % t.replace("\n", " / "))
	vue.vider_selection()
	await process_frame
	_vrai(not infos._texte.get_parsed_text().contains("Selection"), "sans sélection, la ligne s'en va")

	# UN VRAI GLISSÉ DE RECT, haussé de deux crans : 12 × 1 × 8 puis 12 × 3 × 8 ; relâché, il devient une sélection de
	# 12 × 3 × 8 = 288 cases.
	ed._choisir_outil("rect")
	var cam: Camera3D = vue._camera
	cam.global_position = Vector3(306.0, 30.0, 330.0)
	cam.look_at(Vector3(306.0, 0.0, 304.0))
	var p1: Vector2 = cam.unproject_position(Vector3(300.5, 0.0, 300.5))
	var p2: Vector2 = cam.unproject_position(Vector3(311.5, 0.0, 307.5))
	vue._commencer_coup(MOUSE_BUTTON_LEFT, p1, false)
	vue._survoler(p2)
	await process_frame
	t = infos._texte.get_parsed_text()
	_vrai(t.contains("Drag  12 × 1 × 8"), "pendant le glissé : « Drag 12 × 1 × 8 » (« %s »)" % t.replace("\n", " / "))
	vue.hausser_le_glisse(1)
	vue.hausser_le_glisse(1)
	await process_frame
	_vrai(infos._texte.get_parsed_text().contains("Drag  12 × 3 × 8"), "deux crans de molette : « Drag 12 × 3 × 8 »")
	vue._coup = -1
	vue._finir_boite(MOUSE_BUTTON_LEFT)
	await process_frame
	t = infos._texte.get_parsed_text()
	_vrai(not t.contains("Drag") and t.contains("Selection  288 cells") and t.contains("12 × 3 × 8"),
		"relâché : plus de glissé, une sélection de 288 cases, 12 × 3 × 8 (« %s »)" % t.replace("\n", " / "))
	vue.vider_selection()

	# LE REPÈRE DE TAILLE : la souris sur la case (303, 0, 304) de la grille → le fantôme debout dans cette case.
	ed._choisir_outil("ajouter")
	var ecran: Vector2 = cam.unproject_position(Vector3(303.5, 0.0, 304.5))
	vue._survoler(ecran)
	await process_frame
	var fantome: Node3D = infos.silhouette
	_vrai(fantome.visible and (fantome.global_position as Vector3).is_equal_approx(Vector3(303.5, 0.0, 304.5)),
		"la silhouette se tient dans la case visée, sur la grille (%s)" % fantome.global_position)
	for taille_p in [vue.taille_personnage, 1.0]:
		vue.regler_taille_personnage(taille_p)
		vue._survoler(ecran + Vector2(1, 0))
		await process_frame
		var h := _hauteur_visible(fantome)
		var attendu: float = Personnage.HAUTEUR * float(taille_p)
		_vrai(absf(h - attendu) < 0.04,
			"à la taille %.2f, la silhouette a la hauteur du personnage : %.3f, pour HAUTEUR × taille = %.3f" % [taille_p, h, attendu])
	vue.regler_taille_personnage(Personnage.TAILLE_DEFAUT)
	vue._survoler(ecran)
	await process_frame
	ed._infos_vue.case_silhouette.button_pressed = false
	await process_frame
	_vrai(not fantome.visible, "décochée : plus de silhouette")
	_vrai(_reglage("infos", "silhouette") == false, "… et c'est retenu dans reglages.cfg")
	ed._infos_vue.case_silhouette.button_pressed = true
	ed._infos_vue.case_infos.button_pressed = false
	await process_frame
	_vrai(not infos.visible, "décochée : plus de panneau d'infos")
	_vrai(_reglage("infos", "visible") == false, "… et c'est retenu dans reglages.cfg")
	ed._infos_vue.case_infos.button_pressed = true
	await process_frame
	_vrai(infos.visible, "recochée : il revient")

	# LA GRILLE : des lignes marquées toutes les 4 cases, fortes toutes les 8 (attendus écrits à la main).
	var niveaux_ok := true
	for i in [-24, -16, -8, 0, 8, 16, 24]:
		niveaux_ok = niveaux_ok and vue.niveau_de_ligne(i) == 2
	for i in [-20, -12, -4, 4, 12, 20]:
		niveaux_ok = niveaux_ok and vue.niveau_de_ligne(i) == 1
	for i in [-23, -7, -1, 1, 2, 3, 5, 6, 7, 9, 13]:
		niveaux_ok = niveaux_ok and vue.niveau_de_ligne(i) == 0
	_vrai(niveaux_ok, "les niveaux de ligne : fortes aux multiples de 8, marquées aux multiples de 4, fines ailleurs")
	var grille: Mesh = vue._grille.mesh
	var alphas: Array = []
	for s in grille.get_surface_count():
		alphas.append((grille.surface_get_material(s) as StandardMaterial3D).albedo_color.a)
	_vrai(grille.get_surface_count() == 3 and alphas[0] < alphas[1] and alphas[1] < alphas[2],
		"la grille centrale : trois surfaces, de plus en plus marquées (%s)" % [alphas])
	# 7 lignes fortes (−24 … 24) dans chaque sens, deux sommets chacune : 28 sommets.
	_egal((grille.surface_get_arrays(2)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), 28,
		"7 lignes fortes dans chaque sens (−24, −16 … 24)")
	# La grille LOCALE suit la place dans le monde : survolée en (37, 0, −2), sa ligne x = 40 (locale 3) est forte, la
	# ligne x = 36 (locale −1) marquée, la ligne x = 39 (locale 2) fine.
	cam.global_position = Vector3(37.0, 20.0, 10.0)
	cam.look_at(Vector3(37.0, 0.0, -2.0))
	ecran = cam.unproject_position(Vector3(37.5, 0.0, -1.5))
	vue._survoler(ecran)
	await process_frame
	_vrai(vue._grille_locale.visible and (vue._grille_locale.position as Vector3).x == 37.0,
		"hors de la grille centrale, la grille locale suit la case survolée (%s)" % vue._grille_locale.position)
	var arr: Array = (vue._grille_locale.mesh as Mesh).surface_get_arrays(0)
	var a_forte := _alpha_du_segment(arr, Vector3(3, 0, 0), Vector3(3, 0, 1))
	var a_marquee := _alpha_du_segment(arr, Vector3(-1, 0, 0), Vector3(-1, 0, 1))
	var a_fine := _alpha_du_segment(arr, Vector3(2, 0, 0), Vector3(2, 0, 1))
	_vrai(a_forte > a_marquee and a_marquee > a_fine and a_fine > 0.0,
		"la grille locale : x = 40 forte (%.2f), x = 36 marquée (%.2f), x = 39 fine (%.2f)" % [a_forte, a_marquee, a_fine])
	_infos_finies = true


## L'alpha du segment a → b dans des tableaux de `PRIMITIVE_LINES` (−1 s'il n'y est pas).
func _alpha_du_segment(arr: Array, a: Vector3, b: Vector3) -> float:
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var c: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	for i in range(0, v.size(), 2):
		if v[i].is_equal_approx(a) and v[i + 1].is_equal_approx(b):
			return c[i].a
	return -1.0


## La hauteur VISIBLE d'un nœud : la boîte de tous ses maillages, en espace du monde (le bas des pieds au haut de la tête).
func _hauteur_visible(n: Node3D) -> float:
	var bas := INF
	var haut := -INF
	var pile: Array = [n]
	while not pile.is_empty():
		var x: Node = pile.pop_back()
		pile.append_array(x.get_children())
		var mi := x as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var b: AABB = mi.global_transform * mi.mesh.get_aabb()
		bas = minf(bas, b.position.y)
		haut = maxf(haut, b.end.y)
	return haut - bas


func _reglage(section: String, cle: String) -> Variant:
	var r := ConfigFile.new()
	r.load(REGLAGES)
	return r.get_value(section, cle, null)


## LA RETOPO (Jordan, 13 octobre 2026) — par les VRAIS boutons de Geometry : « Simplify · all tiles » donne moins de
## faces au témoin sans ouvrir un joint du monde (attendu hors du code éprouvé : `_sans_partenaire`), le rapport le dit ;
## UN Ctrl+Z rend toutes les tuiles telles qu'elles étaient (sommets et faces), Ctrl+Y refait ; « Relax » sur la paroi,
## un Ctrl+Z.
func _la_retopo(ed: Control) -> bool:
	ed._aller_a("witness")
	ed._regler_edition(true)
	var mo: Node3D = ed._modeleur
	var t: RefCounted = mo.temoin
	mo.activer(int(t.occurrences_de("mb_plaque_b2h2_dehors")[0]))
	var boutons := {}
	for b in ed.find_children("*", "Button", true, false):
		boutons[(b as Button).text] = b
	for nom in ["Simplify", "Simplify · all tiles", "Relax", "Relax · all tiles"]:
		_vrai(boutons.has(nom), "retopo : le bouton « %s » existe dans Geometry" % nom)
	if not boutons.has("Simplify · all tiles") or not boutons.has("Relax"):
		return false
	_egal(_sans_partenaire(t), 0, "retopo : avant, tout sommet de joint a son partenaire")
	var photo := {}
	var faces0 := 0
	for c in t.tuiles:
		photo[c] = [(t.tuiles[c].sommets as PackedVector3Array).duplicate(), t.tuiles[c].faces.size()]
		faces0 += t.tuiles[c].faces.size()
	(boutons["Simplify · all tiles"] as Button).pressed.emit()
	var faces1 := 0
	for c in t.tuiles:
		faces1 += t.tuiles[c].faces.size()
	_vrai(faces1 < faces0 and _sans_partenaire(t) == 0 and ed._rapport.text.contains("Simplify"),
		"Simplify · all tiles : %d faces → %d, aucun joint ouvert (%d), le rapport le dit" % [faces0, faces1, _sans_partenaire(t)])
	ed._unhandled_key_input(_cle(KEY_Z, true))
	var rendues := 0
	for c in t.tuiles:
		if t.tuiles[c].sommets == photo[c][0] and t.tuiles[c].faces.size() == photo[c][1]:
			rendues += 1
	_egal(rendues, t.tuiles.size(), "UN Ctrl+Z rend toutes les tuiles d'avant Simplify")
	ed._unhandled_key_input(_cle(KEY_Y, true))
	var faces2 := 0
	for c in t.tuiles:
		faces2 += t.tuiles[c].faces.size()
	_egal(faces2, faces1, "Ctrl+Y refait Simplify")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	# La paroi subdivisée deux fois (UN geste chacune, ses points de bord reportés), puis Simplify sur elle seule : elle
	# perd des faces ; Relax égalise ce qui reste ; aucun joint ne s'ouvre ; chaque bouton est UN Ctrl+Z.
	for k in 2:
		mo.choisir_mode("face")
		mo.tout_choisir(false)
		var toutes := {}
		for f in mo.maillage.faces.size():
			toutes[f] = true
		mo.sel_f = toutes
		mo.operer("subdiviser")
	var subdivisee: int = mo.maillage.faces.size()
	_egal(_sans_partenaire(t), 0, "retopo : la paroi subdivisée deux fois, joints fermés")
	# Une grille subdivisée est déjà régulière, et Simplify replie une paroi plate jusqu'à ne plus laisser de sommet
	# intérieur (mesuré sous Windows : Relax n'y trouvait rien) : un sommet intérieur est décalé DANS le plan de la
	# paroi (la forme ne change pas), Relax doit le ramener, puis Simplify.
	var libres := (preload("res://addons/marchingblocks_core/retopo.gd").verrous(mo.maillage)["verrous"] as Dictionary)
	var decale := -1
	var n_paroi := Vector3.ZERO
	for f in mo.maillage.faces.size():
		for i in mo.maillage.faces[f]:
			if decale < 0 and not libres.has(int(i)):
				decale = int(i)
				n_paroi = mo.maillage.normale(f)
	_vrai(decale >= 0, "retopo : la paroi subdivisée a un sommet intérieur libre")
	if decale < 0:
		return false
	var tangente := n_paroi.cross(Vector3.UP if absf(n_paroi.y) < 0.9 else Vector3.RIGHT).normalized()
	mo.maillage.sommets[decale] += tangente * 0.04
	mo.redessiner()
	var avant: PackedVector3Array = mo.maillage.sommets.duplicate()
	(boutons["Relax"] as Button).pressed.emit()
	_vrai(mo.maillage.sommets != avant and _sans_partenaire(t) == 0 and ed._rapport.text.contains("Relax"),
		"Relax sur la paroi : des sommets égalisés, aucun joint ouvert, le rapport le dit")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_vrai(mo.maillage.sommets == avant, "UN Ctrl+Z défait Relax")
	(boutons["Simplify"] as Button).pressed.emit()
	var simplifiee: int = mo.maillage.faces.size()
	_vrai(simplifiee < subdivisee and _sans_partenaire(t) == 0, "Simplify sur la paroi subdivisée : %d faces → %d, joints fermés"
		% [subdivisee, simplifiee])
	ed._unhandled_key_input(_cle(KEY_Z, true))
	_egal(mo.maillage.faces.size(), subdivisee, "UN Ctrl+Z défait Simplify")
	ed._unhandled_key_input(_cle(KEY_Z, true))
	ed._unhandled_key_input(_cle(KEY_Z, true))
	var rendues2 := 0
	for c in t.tuiles:
		if t.tuiles[c].sommets == photo[c][0] and t.tuiles[c].faces.size() == photo[c][1]:
			rendues2 += 1
	_egal(rendues2, t.tuiles.size(), "… et deux Ctrl+Z défont les deux subdivisions : le témoin d'origine")
	return true
