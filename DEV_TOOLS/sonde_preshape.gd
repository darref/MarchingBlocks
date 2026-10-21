extends SceneTree
## LA SONDE DE PRESHAPE (21 octobre 2026, la 1.1.0) — la preuve À L'IMAGE : un vrai monde ouvert, des formes de
## plusieurs familles posées par l'atelier sur son sol (chacune dans un pack), photographiées de biais ; et le fantôme
## seul, avant la pose. Les formes, leurs matières, leurs coutures avec le monde et leurs transitions se jugent sur ces
## photos.
##
## LANCEMENT — ⚠ AVEC FENÊTRE, sur une COPIE du `.mbproj` (l'atelier l'enregistre) :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_preshape.gd -- \
##       --projet=<copie>.mbproj --dossier=<photos>
## ⚠ Ne pas l'interrompre : il rend `reglages.cfg` à la fin.

const REGLAGES := "user://reglages.cfg"
## [forme, pack, recul de la caméra]
const POSES := [
	["montagne", "Snowy peak", 70.0],
	["volcan", "Breached cone", 70.0],
	["mesa", "Desert butte", 50.0],
	["pyramide", "Mesoamerican", 50.0],
	["chateau", "Stone castle", 75.0],
	["aqueduc", "Roman aqueduct", 75.0],
	["arche", "Delicate arch", 40.0],
	["village", "Hamlet", 55.0],
	["canyon", "Slot gorge", 60.0],
	["labyrinthe", "Hedge maze", 45.0],
]
var _projet := ""
var _dossier := ""
var _reglages_avant := ""
var _ecran: Control


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--projet="):
			_projet = option.substr("--projet=".length())
		elif option.begins_with("--dossier="):
			_dossier = option.substr("--dossier=".length())
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
	await _ecran._changer_d_atelier("preformes")
	await _images(60)
	var ap: RefCounted = _ecran._preformes
	# Le sol : la plus haute case de chaque colonne du monde visible.
	var sol := {}
	for c in _ecran._union:
		var k := Vector2i(c.x, c.z)
		if not sol.has(k) or c.y > int(sol[k]):
			sol[k] = c.y
	var bas := Vector2i(1 << 20, 1 << 20)
	var haut := -bas
	for k in sol:
		bas = bas.min(k)
		haut = haut.max(k)
	print("MONDE : %d colonnes, de %s à %s" % [sol.size(), bas, haut])
	var centre := Vector2((bas.x + haut.x) * 0.5, (bas.y + haut.y) * 0.5)
	var rayon := minf(haut.x - bas.x, haut.y - bas.y) * 0.32
	for i in POSES.size():
		var p: Array = POSES[i]
		ap.choisir(p[0])
		for pk in ap._packs_de(p[0]):
			if pk["nom"] == p[1]:
				ap._appliquer_pack(pk["valeurs"])
		ap.quart = 0
		ap.decalage = 0
		ap.ancrer = true
		ap._refaire()
		var a := TAU * i / POSES.size()
		var q := Vector2i((centre + Vector2(cos(a), sin(a)) * rayon).round())
		var y: int = int(sol.get(q, 0)) + 1
		var ancre := Vector3i(q.x, y, q.y)
		# Le fantôme d'abord, pour la première forme.
		if i == 0:
			ap._ancre = ancre
			ap._suivre_l_ancre()
			await _photo(Vector3(ancre) + Vector3(0, 10, 0), p[2], "00_fantome_%s" % p[0])
		var t0 := Time.get_ticks_msec()
		await ap.poser(ancre)
		print("POSÉ : %s (%s) en %s, %d ms" % [p[0], p[1], ancre, Time.get_ticks_msec() - t0])
		ap._ancre = null
		ap._suivre_l_ancre()
		await _images(40)
		await _photo(Vector3(ancre) + Vector3(0, 6, 0), p[2], "%02d_%s" % [i + 1, p[0]])
	await _ecran._changer_d_atelier("monde")
	await _images(30)
	_ecran._vue.cadrer_toute_la_matiere()
	await _images(30)
	_ecran.get_viewport().get_texture().get_image().save_png(_dossier.path_join("99_tout.png"))
	_finir(0)


func _photo(cible: Vector3, recul: float, nom: String) -> void:
	var vue = _ecran._vue
	vue._cible = cible
	vue._distance = recul
	vue._azimut = 0.8
	vue._elevation = 0.55
	vue._caler()
	await _images(25)
	_ecran.get_viewport().get_texture().get_image().save_png(_dossier.path_join(nom + ".png"))


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
