extends SceneTree
## LA SONDE DU SMOOTH SHADING (19 octobre 2026, la 1.0.0) — la preuve À L'IMAGE : un projet aux témoins sculptés ouvert
## pour de vrai, la MÊME vue photographiée à plat puis lissée (tous les témoins à `--angle`) dans World. Les coutures
## d'ombre aux joints des tuiles se jugent sur ces photos. (`sonde_lissage.gd` est une autre sonde : le chanfrein.)
##
## LANCEMENT — ⚠ AVEC FENÊTRE, sur une COPIE du projet (les témoins sont réécrits) :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_ombrage_lisse.gd -- \
##       --projet=<copie>.mbproj --dossier=<photos> [--angle=45] [--cible=x,y,z] [--distance=14]
## ⚠ Ne pas l'interrompre : il rend `reglages.cfg` à la fin.

const REGLAGES := "user://reglages.cfg"
var _projet := ""
var _dossier := ""
var _angle := 45.0
var _cible := Vector3.INF
var _distance := 14.0
var _reglages_avant := ""
var _ecran: Control


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--projet="):
			_projet = option.substr("--projet=".length())
		elif option.begins_with("--dossier="):
			_dossier = option.substr("--dossier=".length())
		elif option.begins_with("--angle="):
			_angle = float(option.substr("--angle=".length()))
		elif option.begins_with("--distance="):
			_distance = float(option.substr("--distance=".length()))
		elif option.begins_with("--cible="):
			var p := option.substr("--cible=".length()).split(",")
			_cible = Vector3(float(p[0]), float(p[1]), float(p[2]))
	if _projet == "" or _dossier == "":
		push_error("--projet= et --dossier= sont requis")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_dossier)
	if FileAccess.file_exists(REGLAGES):
		_reglages_avant = FileAccess.get_file_as_string(REGLAGES)
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", _projet)
	r.save(REGLAGES)
	root.size = Vector2i(1600, 900)
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	_derouler.call_deferred()


func _derouler() -> void:
	await _images(30)
	await _ecran._ouvrir(_projet)
	await _ecran._changer_d_atelier("monde")
	await _images(60)
	await _vues("plat")
	var n := 0
	for c in _ecran._couches:
		var t: RefCounted = _ecran._temoin_de(c)
		if t == null:
			continue
		t.lissage = _angle
		t._partager()
		_ecran._temoins_sales[t] = true
		n += 1
	print("LISSAGE : %d témoin(s) à %d°" % [n, int(_angle)])
	_ecran._enregistrer_le_temoin_modele(true)
	await _ecran._changer_d_atelier("monde")
	await _images(90)
	await _vues("lisse")
	_finir(0)


func _vues(etat: String) -> void:
	var vue = _ecran._vue
	if _cible == Vector3.INF:
		vue.cadrer_toute_la_matiere()
		_cible = vue._cible
	for k in 2:
		vue._cible = _cible
		vue._distance = _distance
		vue._azimut = 0.7 + k * 1.9
		vue._elevation = 0.5
		vue._caler()
		await _images(20)
		_ecran.get_viewport().get_texture().get_image().save_png(_dossier.path_join("%s_%d.png" % [etat, k]))


func _images(n: int) -> void:
	for i in n:
		await process_frame


func _finir(code: int) -> void:
	_ecran._enregistrer()
	_ecran._attendre_l_ecriture()
	if _reglages_avant != "":
		var f := FileAccess.open(REGLAGES, FileAccess.WRITE)
		f.store_string(_reglages_avant)
		f.close()
	quit(code)
