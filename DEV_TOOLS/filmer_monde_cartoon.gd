extends "res://DEV_TOOLS/filmer_ui.gd"
##
## LE MONDE CARTOON EN VIDÉO (18 octobre 2026) — « ensuite vidéo MP4 et gif comme d'habitude ». Un survol d'environ 90 s du
## projet bâti par `batir_monde_cartoon.gd`, dans la VRAIE appli (atelier World), la caméra seule à la main du script :
##   tour   — un tour complet de l'île, de haut (le GIF : la boucle se referme) ;
##   bourg  — on descend sur la place pavée et on passe sous l'arche de la prairie ;
##   canyon, montagnes, volcan, mer (l'arche de mer, vue du large), desert, marais_foret — des passages lents ;
##   sous_terre — dans les galeries larges, de la salle de cristal à celle des champignons, par la salle sous le bourg ;
##   fin    — on remonte au-dessus de l'île.
## Les panneaux de l'appli sont MASQUÉS pendant la prise (le monde plein cadre ; le GIF garde son intro avec toute l'UI).
## Ciel bleu de dessin animé, lumière franche, SDFGI ; sous terre, une TORCHE accrochée à la caméra, l'ambiante relevée et
## le halo allumé (l'émission du cristal et des champignons).
##
## ⚠ ON FILME UNE COPIE (la leçon du monde client) : le dossier est copié dans le user:// du worktree, ses chemins réécrits.
##
## LANCEMENT (sur le PC, plein écran : sinon l'enregistreur rogne) :
##   Godot_v4.7-stable_win64_console.exe --path <worktree> --fullscreen --fixed-fps 30 --write-movie <rush>.avi \
##       --script res://DEV_TOOLS/filmer_monde_cartoon.gd
## Les lignes « PLAN <nom> image <n> » donnent les coupes.

const SOURCE := "C:/Users/jorda/Documents/MarchingBlocks/monde_cartoon"
const COPIE := "user://cartoon_tournage"
const PLAINE := 15.0
const DEMI := 80.0

var _projet_copie := ""
var _essai := false
var _vues := {}
var _masques: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seulement="):
			_seulement = a.substr("--seulement=".length())
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


func _copier_le_projet() -> String:
	var dest := ProjectSettings.globalize_path(COPIE).replace("\\", "/")
	_vider(dest)
	_copier_dossier(SOURCE, dest)
	_reecrire(dest, dest)
	var t := FileAccess.get_file_as_string(dest.path_join("vues.json"))
	var v = JSON.parse_string(t)
	if v is Dictionary:
		_vues = v
	return dest.path_join("monde_cartoon.mbproj")


func _reecrire(d: String, dest: String) -> void:
	for f in DirAccess.get_files_at(d):
		if f.get_extension() in ["mbproj", "mbtiles"]:
			var chemin := d.path_join(f)
			var t := FileAccess.get_file_as_string(chemin)
			var w := FileAccess.open(chemin, FileAccess.WRITE)
			w.store_string(t.replace(SOURCE, dest))
			w.close()
	for s in DirAccess.get_directories_at(d):
		_reecrire(d.path_join(s), dest)


func _copier_dossier(de: String, vers: String) -> void:
	DirAccess.make_dir_recursive_absolute(vers)
	for f in DirAccess.get_files_at(de):
		DirAccess.copy_absolute(de.path_join(f), vers.path_join(f))
	for d in DirAccess.get_directories_at(de):
		if d != "photos":
			_copier_dossier(de.path_join(d), vers.path_join(d))


func _derouler() -> void:
	await _images(60)
	if not await _ecran._ouvrir(_projet_copie):
		print("⚠ la copie ne s'ouvre pas : %s" % _projet_copie)
		_rendre_les_reglages()
		quit(1)
		return
	_vue = _ecran._vue
	if _ecran._legende_formes != null:
		_ecran._legende_formes.basculer(false, false)
	await _ecran._changer_d_atelier("monde")
	# La souris hors de la vue : pas de pinceau fantôme.
	var m := InputEventMouseMotion.new()
	m.position = Vector2(-50, -50)
	m.global_position = m.position
	Input.parse_input_event(m)
	_masquer_l_ui()
	_ciel_de_dessin_anime(false)
	_poser_camera(Vector3(0, 12, 0), 0.7, 0.75, 175.0)
	await _images(150)    # le feuillage, l'eau, les ombres et les transitions se posent
	if _seulement == "sous_terre":
		# L'ESSAI : le souterrain seul, une photo toutes les deux secondes, sans film.
		_essai = true
		await _sous_terre()
		_rendre_les_reglages()
		quit(0)
		return
	await _tour()
	await _passage("bourg", [
		[Vector3(0, 46, 70), Vector3(0, 15, 6)], [Vector3(0, 28, 26), Vector3(0, 16, 0)],
		[Vector3(-3, 21, 2), Vector3(0, 19, -24)], [Vector3(0, 19.5, -14), Vector3(0, 20, -34)],
		[Vector3(0, 20, -26), Vector3(0, 21, -44)], [Vector3(0, 24, -38), Vector3(0, 20, -60)]], 10.0)
	await _passage("canyon", [
		[Vector3(30, 44, 36), Vector3(56, 18, 14)], [Vector3(46, 38, 40), Vector3(58, 18, 12)],
		[Vector3(64, 36, 40), Vector3(58, 18, 8)]], 6.0)
	await _passage("montagnes", [
		[Vector3(8, 44, -14), Vector3(34, 26, -46)], [Vector3(22, 46, -22), Vector3(44, 24, -42)],
		[Vector3(34, 50, -24), Vector3(48, 22, -42)]], 7.0)
	await _passage("volcan", [
		[Vector3(-22, 42, 36), Vector3(-56, 26, 16)], [Vector3(-30, 46, 14), Vector3(-56, 26, 16)],
		[Vector3(-34, 44, -2), Vector3(-56, 25, 16)]], 6.0)
	await _passage("mer", [
		[Vector3(-4, 10, DEMI + 26), Vector3(-13, 7, DEMI - 2)], [Vector3(-12, 8, DEMI + 18), Vector3(-13, 8, DEMI - 4)],
		[Vector3(-22, 12, DEMI + 14), Vector3(-10, 9, DEMI - 6)]], 7.0)
	await _passage("desert", [
		[Vector3(72, 34, 92), Vector3(46, 15, 52)], [Vector3(54, 30, 84), Vector3(40, 15, 52)],
		[Vector3(36, 30, 82), Vector3(36, 15, 50)]], 6.0)
	await _passage("marais_foret", [
		[Vector3(-22, 28, 74), Vector3(-44, 12, 48)], [Vector3(-34, 28, 46), Vector3(-50, 13, 28)],
		[Vector3(-40, 32, 8), Vector3(-58, 17, -12)], [Vector3(-36, 34, -22), Vector3(-48, 17, -46)]], 9.0)
	await _sous_terre()
	_masquer_l_ui()
	_ciel_de_dessin_anime(false)
	await _passage("fin", [
		[Vector3(0, 22, 24), Vector3(0, 15, 0)], [Vector3(0, 60, 80), Vector3(0, 12, 0)],
		[Vector3(0, 120, 150), Vector3(0, 10, 0)]], 6.0)
	await _images(15)
	_plan("fin_fin")
	_rendre_les_reglages()
	quit(0)


## Le monde plein cadre : tout ce qui est posé par-dessus la vue (barres, rail, guide, légende, bandes) est caché.
func _masquer_l_ui() -> void:
	var corps: Node = _vue.get_parent()
	for n in corps.get_children():
		if n != _vue and n is CanvasItem:
			(n as CanvasItem).visible = false
	var colonne: Node = corps.get_parent()
	for n in colonne.get_children():
		if n != corps and n is CanvasItem:
			(n as CanvasItem).visible = false


## Un ciel bleu de dessin animé, un soleil franc et chaud, des couleurs un peu poussées ; sous terre, l'ambiante relevée
## (les galeries de roche) et le halo pour l'émission.
func _ciel_de_dessin_anime(sous_terre: bool) -> void:
	var env: Environment = _vue._env
	var ciel: ProceduralSkyMaterial = _vue._ciel_du_jeu
	ciel.sky_top_color = Color("#3d8be0")
	ciel.sky_horizon_color = Color("#bfe7ff")
	ciel.ground_horizon_color = Color("#bfe7ff")
	ciel.ground_bottom_color = Color("#7fb6e6")
	env.background_mode = Environment.BG_SKY
	env.sky.sky_material = ciel
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#cfe2ff") if not sous_terre else Color("#b8b0ff")
	env.ambient_light_energy = 1.25 if not sous_terre else 1.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.04
	env.glow_enabled = true
	env.glow_intensity = 0.7 if not sous_terre else 1.0
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = true
	env.ssao_intensity = 1.6
	# SDFGI (Jordan, 18 octobre 2026 : « n'oublie pas d'activer la SDFGI au tournage, il faudra une torche pour les
	# intérieurs ») : la lumière qui rebondit dehors ; sous terre, la TORCHE accrochée à la caméra (une lumière chaude,
	# avec ombres) et l'émission du cristal et des champignons.
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_energy = 1.0
	_torche(sous_terre)
	var soleil: DirectionalLight3D = _vue._soleil
	soleil.light_energy = 1.35 if not sous_terre else 0.4
	soleil.light_color = Color("#fff3dc")
	soleil.rotation_degrees = Vector3(-52, 35, 0)


var _lampe: OmniLight3D
var _devant: OmniLight3D


## La torche : une lumière ponctuelle chaude, un peu au-dessus et à droite de l'œil (comme tenue à bout de bras).
func _torche(allumee: bool) -> void:
	if _lampe == null:
		_lampe = OmniLight3D.new()
		_lampe.light_color = Color("#ffc67a")
		# ⚠ À 3,2 (portée 16) LA GALERIE RESTAIT NOIRE AU PREMIER TOURNAGE : le SDFGI éteint l'ambiante sous la voûte.
		_lampe.light_energy = 5.5
		_lampe.omni_range = 30.0
		_lampe.omni_attenuation = 0.7
		_lampe.shadow_enabled = true
		_lampe.light_bake_mode = Light3D.BAKE_DYNAMIC
		_vue.camera().add_child(_lampe)
		_lampe.position = Vector3(0.6, 0.4, -0.3)
	_lampe.visible = allumee
	# Une seconde lueur, devant : la torche n'éclaire que ce qui est près ; celle-ci révèle le fond de la galerie.
	if _devant == null:
		_devant = OmniLight3D.new()
		_devant.light_color = Color("#d9e4ff")
		_devant.light_energy = 3.2
		_devant.omni_range = 22.0
		_devant.omni_attenuation = 0.9
		_vue.camera().add_child(_devant)
		_devant.position = Vector3(0, 0.5, -7.0)
	_devant.visible = allumee


func _poser_oeil(oeil: Vector3, cible: Vector3) -> void:
	var d := oeil - cible
	_poser_camera(cible, atan2(d.x, d.z), asin(clampf(d.y / d.length(), -1.0, 1.0)), d.length())


## UN TOUR de l'île : 12 s pour 2π, la boucle se referme sur elle-même.
func _tour() -> void:
	_plan("tour")
	var n := int(12.0 * FPS)
	for i in n:
		var t := float(i) / n
		_poser_camera(Vector3(0, 12, 0), 0.7 + TAU * t, 0.72 + 0.05 * sin(TAU * t), 175.0 - 12.0 * sin(TAU * t))
		await _images(1)
	_plan("tour_fin")


## Un passage : des images-clés [œil, cible], une courbe de Catmull-Rom sur les deux, la vitesse douce aux bouts.
func _passage(nom: String, cles: Array, duree: float) -> void:
	_plan(nom)
	var n := int(duree * FPS)
	for i in n:
		var t := _doux(float(i) / (n - 1)) * (cles.size() - 1)
		var k := mini(int(t), cles.size() - 2)
		var u := t - k
		var oeil := _catmull(cles, k, u, 0)
		var cible := _catmull(cles, k, u, 1)
		_poser_oeil(oeil, cible)
		await _images(1)


func _catmull(cles: Array, k: int, u: float, j: int) -> Vector3:
	var p0: Vector3 = cles[maxi(k - 1, 0)][j]
	var p1: Vector3 = cles[k][j]
	var p2: Vector3 = cles[k + 1][j]
	var p3: Vector3 = cles[mini(k + 2, cles.size() - 1)][j]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u)


## SOUS TERRE : l'axe des galeries, retrouvé comme le bâtisseur l'a creusé (le même bruit : graine 7, fréquence 0,1, le
## serpentement de 3 cases qui s'éteint aux bouts) — la caméra file au milieu, 0,8 au-dessus de l'axe.
func _axe(points: Array) -> Array:
	var bruit := FastNoiseLite.new()
	bruit.seed = 7
	bruit.frequency = 0.1
	var sortie: Array = []
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var n := maxi(int(a.distance_to(b) * 2.0), 1)
		var cote := Vector3(-(b - a).z, 0, (b - a).x).normalized()
		for j in n + 1:
			var t := float(j) / n
			sortie.append(a.lerp(b, t) + cote * bruit.get_noise_3d(a.x + t * 40.0, 0, a.z) * 3.0 * sin(t * PI)
				+ Vector3(0, 0.8, 0))
	return sortie


func _sous_terre() -> void:
	_ciel_de_dessin_anime(true)
	# Dans la salle de cristal, l'œil contre la paroi ouest, puis les deux galeries jusqu'aux champignons.
	var g0: Array = [Vector3(-20, 7.8, -22), Vector3(-6, 7.8, -12), Vector3(4, 7.8, -6)]
	var g1: Array = [Vector3(4, 7.8, -6), Vector3(14, 7.8, 8), Vector3(22, 7.8, 22)]
	var axe := _axe(g0) + _axe(g1)
	_plan("sous_terre")
	# L'arrivée : la salle de cristal vue de son bord.
	var o := Vector3(-20, 9.5, -22)
	var cles := [[o + Vector3(-10, 0.5, -6), o + Vector3(4, -1.5, 2)], [o + Vector3(-6, 0.0, 0), o + Vector3(8, -1.5, 4)]]
	await _passage("salle_cristal", cles, 4.0)
	# Le long de l'axe : on regarde six points devant.
	var pas := 0.18
	var s := 0.0
	var longueur := 0.0
	for i in axe.size() - 1:
		longueur += (axe[i] as Vector3).distance_to(axe[i + 1])
	var n := int(longueur / pas)
	_plan("galeries")
	var depart := _poser_sur(axe, 0.0)
	for i in n:
		s = float(i) * pas
		var oeil := _poser_sur(axe, s)
		var cible := _poser_sur(axe, s + 6.0)
		if i < 30:
			oeil = (o + Vector3(-6, 0, 0)).lerp(oeil, float(i) / 30.0)
		_poser_oeil(oeil, cible + Vector3(0, -0.4, 0))
		await _images(1)
		if _essai and i % 60 == 30:
			root.get_texture().get_image().save_png(SOURCE.path_join("photos/essai_sous_terre_%03d.png" % i))
	# La salle des champignons : un panoramique lent.
	var c := Vector3(22, 9.5, 22)
	await _passage("salle_champignons", [[_poser_sur(axe, longueur), c + Vector3(4, -2, 6)],
		[c + Vector3(-2, 0.5, -2), c + Vector3(8, -2, 6)], [c + Vector3(2, 1.0, -4), c + Vector3(-6, -2, 8)]], 6.0)
	print("sous terre : %.0f cases d'axe, départ %s" % [longueur, depart])


## Le point de l'axe à la distance `s` de son début.
func _poser_sur(axe: Array, s: float) -> Vector3:
	var reste := s
	for i in axe.size() - 1:
		var a: Vector3 = axe[i]
		var b: Vector3 = axe[i + 1]
		var d := a.distance_to(b)
		if reste <= d and d > 0.0:
			return a.lerp(b, reste / d)
		reste -= d
	return axe.back()
