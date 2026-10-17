extends "res://DEV_TOOLS/filmer_ui.gd"
##
## L'INTRO DES GIF — demandée par Jordan (16 octobre 2026) : « une demi-seconde au début, où l'on voit le soft en entier avec
## son UI et une petite manipulation qui passe du witness de base à celui sculpté, pour chaque prochain gif ».
##
## Ouvre la COPIE de tournage du monde client, atelier Witness, l'appli entière à l'écran (curseur dessiné) : une couche
## neuve montre le témoin CALCULÉ (la base cubique, la légende), la souris va sur la couche « Meadow » et clique — son témoin
## SCULPTÉ et peint apparaît. La ligne « PLAN intro image <n> » donne le début de la demi-seconde (le geste puis le clic) :
## `01_scripts/intro_gif.py` la coupe et la colle devant chaque GIF.
## ⚠ La couche neuve est ENREGISTRÉE dans la copie : recopier le monde avant un autre tournage.
##
## LANCEMENT (copie de tournage, user:// à part) :
##   Godot_v4.7-stable_win64_console.exe --path D:/SpannerGames/ATELIER/MarchingBlocks/worktrees/MB_tournage_monde_client --fixed-fps 30 \
##       --write-movie <rush>.avi --script res://DEV_TOOLS/filmer_intro_temoin.gd [-- --projet=<.mbproj>]

const PROJET_DEFAUT := "C:/Users/jorda/AppData/Roaming/MB_tournage_monde_client/monde_client/monde_client.mbproj"
const SCULPTEE := "Meadow"

var _projet := PROJET_DEFAUT


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--projet="):
			_projet = a.substr("--projet=".length())
	if FileAccess.file_exists(SAUVEGARDE):
		DirAccess.copy_absolute(SAUVEGARDE, REGLAGES)
	if FileAccess.file_exists(REGLAGES):
		DirAccess.copy_absolute(REGLAGES, SAUVEGARDE)
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
	_aides()
	_derouler.call_deferred()


func _derouler() -> void:
	await _images(60)
	if not await _ecran._ouvrir(_projet):
		print("⚠ la copie ne s'ouvre pas : %s" % _projet)
		_rendre_les_reglages()
		quit(1)
		return
	_vue = _ecran._vue
	if _ecran._legende_formes != null:
		_ecran._legende_formes.basculer(false, false)
	var k := -1
	for i in _ecran._couches.size():
		if str(_ecran._couches[i].get("nom", "")) == SCULPTEE:
			k = i
	if k < 0:
		print("⚠ pas de couche %s" % SCULPTEE)
		_rendre_les_reglages()
		quit(1)
		return
	await _ecran._changer_d_atelier("witness")
	# Le témoin sculpté chargé une fois (sinon son chargement tomberait dans la demi-seconde), puis une couche neuve : la base.
	# ⚠ HORS ÉDITION, WITNESS MONTRE LE TÉMOIN CALCULÉ quelle que soit la couche (vu à l'image) : c'est l'édition (Tab) qui
	# montre le témoin de la couche. On y entre sur Meadow (son témoin chargé, ses copies bâties), puis sur la couche neuve.
	_ecran._activer(k)
	await _images(30)
	await _ecran._basculer_edition(true)
	await _images(60)
	_ecran._nouvelle_couche()
	await _images(150)    # la vue, les ombres, la vignette de la couche neuve
	print("en édition : %s, couche %s" % [_ecran._vue.edition,
		_ecran._couches[_ecran._active]["nom"]])
	var rangee := _rangee_de(SCULPTEE)
	if rangee == null:
		print("⚠ la rangée de %s n'est pas dans la liste" % SCULPTEE)
		_rendre_les_reglages()
		quit(1)
		return
	# La liste des couches DÉFILE : Meadow est sous son bord (le clic tombait sur le rapport, vu à l'image).
	var defile := rangee.get_parent()
	while defile != null and not defile is ScrollContainer:
		defile = defile.get_parent()
	if defile != null:
		(defile as ScrollContainer).ensure_control_visible(rangee)
		await _images(10)
	var cible := rangee.get_global_rect().get_center()
	print("rangée %s : %s ; fenêtre %s ; vue %s ; active %d" % [SCULPTEE, rangee.get_global_rect(), root.size,
		_ecran.get_viewport_rect(), _ecran._active])
	await _bouger(cible + Vector2(150, 260), 0.5)
	await _images(20)
	_plan("intro")        # la demi-seconde commence : la souris arrive sur la couche, clique
	await _bouger(cible, 0.2)
	_plan("clic")
	await _clic(MOUSE_BUTTON_LEFT)
	print("après le clic : active %d (%s)" % [_ecran._active, _ecran._couches[_ecran._active]["nom"]])
	await _images(30)
	_plan("fin")
	_rendre_les_reglages()
	quit(0)


## Le bouton d'une couche dans la liste : son texte commence par son nom.
func _rangee_de(nom: String) -> Button:
	var pile: Array = [_ecran]
	while not pile.is_empty():
		var n: Node = pile.pop_back()
		if n is Button and (n as Button).is_visible_in_tree() and (n as Button).text.begins_with(nom + "\n"):
			return n
		pile.append_array(n.get_children())
	return null
