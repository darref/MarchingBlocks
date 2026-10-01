extends SceneTree
## CAPTURE — l'éclairage du témoin ET du monde (Jordan, 1er octobre 2026 : « une lumière ambiante afin que tout
## soit au moins légèrement visible, voire du SDFGI pour le witness, afin de bien voir les reliefs qu'on crée et
## ce qu'ils rendent » ; puis « l'éclairage en mode World aussi, on n'y voit rien »).
## Photographie Witness et World (le monde peint de la forme du témoin, habillé du témoin calculé) sous plusieurs
## réglages, même cadrage. Projet JETABLE ; réglages rendus à la fin.
##   godot --path D:/MarchingBlocks --script res://DEV_TOOLS/capture_eclairage.gd -- [--dossier=…] [--seul]
## `--seul` : seulement l'éclairage de l'appli tel qu'il est (pour juger le résultat).

const Projet := preload("res://app/projet.gd")
const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const REGLAGES := "user://reglages.cfg"
const JETABLE := "user://capture_eclairage/capture.mbproj"
var _dossier := "D:/MarchingBlocks/ART/eclairage"
var _reglages_avant := ""
var _ecran: Control


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--dossier="):
			_dossier = option.substr("--dossier=".length())
	DirAccess.make_dir_recursive_absolute(_dossier)
	if FileAccess.file_exists(REGLAGES):
		_reglages_avant = FileAccess.get_file_as_string(REGLAGES)
	DirAccess.make_dir_recursive_absolute("user://capture_eclairage")
	var f := FileAccess.open(JETABLE, FileAccess.WRITE)
	f.store_string(Projet.vers_texte([Projet.couche("Rock")], 0))
	f.close()
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", JETABLE)
	r.save(REGLAGES)
	root.size = Vector2i(1600, 900)
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	_derouler()


func _derouler() -> void:
	await _images(30)
	var vue = _ecran._vue
	var env: Environment = vue._env
	# Le monde : la forme du témoin peinte, habillée du témoin calculé (son .glb lié, relu sans trancher).
	_ecran._aller_a("monde")
	await _images(5)
	_ecran._peindre_la_forme_du_temoin()
	var glb := ProjectSettings.globalize_path("user://capture_eclairage/temoin.glb")
	TL.depuis_le_temoin_calcule().vers_glb(glb)
	vue.monde().lot = BM.librairie_depuis_glb(glb)["lot"]
	# Un pavé de la paroi marron de Jordan (métal 0,57, rugosité 1) posé à l'ombre du bloc, et un témoin à 0.
	for k in 2:
		var pave := MeshInstance3D.new()
		pave.mesh = BoxMesh.new()
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.4414, 0.335, 0.1845)
		m.metallic = [0.57, 0.0][k]
		m.roughness = 1.0
		pave.material_override = m
		pave.position = Vector3(-1.5 + 1.4 * k, 0.5, 6)
		vue._vue.add_child(pave)
	var reglages := {"seul": func(): pass}
	if not "--seul" in OS.get_cmdline_user_args():
		reglages = {
			"a_actuel": func(): pass,
			"f_ssao_ssil": func():
				env.ssao_enabled = true
				env.ssil_enabled = true,
			"g_ssao_ssil_ambiante_1_1": func():
				env.ssao_enabled = true
				env.ssil_enabled = true
				env.ambient_light_energy = 1.1,
		}
	var vues := [["temoin", Vector3(6, 6, 6), 0.7, 0.55, 26.0], ["temoin", Vector3(6, 6, 6), 0.7 + PI, 0.4, 26.0],
		["monde", Vector3(6, 6, 6), 0.7 + PI, 0.45, 22.0], ["monde", Vector3(3, 3, 9), -0.6, 0.15, 9.0]]
	for nom in reglages:
		reglages[nom].call()
		for k in vues.size():
			var v: Array = vues[k]
			_ecran._aller_a("witness" if v[0] == "temoin" else "monde")
			vue._cible = v[1]
			vue._azimut = v[2]
			vue._elevation = v[3]
			vue._distance = v[4]
			vue._caler()
			await _images(40)
			vue._vue.get_texture().get_image().save_png(_dossier.path_join("%s_%s_%d.png" % [nom, v[0], k]))
			print("photo %s_%s_%d" % [nom, v[0], k])
	# Le Play test : son ciel, vu à hauteur du personnage puis d'un peu plus haut.
	_ecran._aller_a("jeu")
	await _images(30)
	vue.personnage.global_position = Vector3(4.5, 13.5, 8.5)   # sur le plateau : le ciel se voit
	vue.personnage.velocity = Vector3.ZERO
	await _images(30)
	for k in 2:
		vue._elevation = [0.02, 0.35][k]
		await _images(30)
		vue._vue.get_texture().get_image().save_png(_dossier.path_join("jeu_%d.png" % k))
		print("photo jeu_%d" % k)
	_ecran._aller_a("monde")
	if _reglages_avant != "":
		var f := FileAccess.open(REGLAGES, FileAccess.WRITE)
		f.store_string(_reglages_avant)
		f.close()
	quit(0)


func _images(n: int) -> void:
	for k in n:
		await process_frame
