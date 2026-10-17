extends "res://DEV_TOOLS/filmer_ui.gd"
##
## LE TUNNEL DE VERRE DU MONDE CLIENT — un GIF demandé par Jordan (16 octobre 2026) : « la même île, mais qui a un tunnel
## commençant dehors et qui s'enfonce dans la mer puis dans le sol, traverse une grande salle et ressort dans l'île pour
## remonter en vue haute et tournoyer un court instant autour de l'île ».
##
## Ouvre la COPIE de tournage de `monde_client.mbproj` (bâti par `DEV_TOOLS/batir_monde_client.gd`, qui écrit l'axe du
## tunnel dans `tunnel.json` à côté du projet), atelier World, sans les aides ; puis un seul plan-séquence :
##   1. l'approche, dehors, de l'îlot et de la bouche du tube ;
##   2. le tube : par-dessus l'îlot, la plongée, sous la mer (plus lent, le regard levé vers la surface), sous la plage,
##      la salle (lent, le regard vers le puits de lumière), la remontée ;
##   3. la sortie : la caméra monte en vue haute sur l'île ;
##   4. un court tour autour de l'île.
## ⚠ ON FILME UNE COPIE (voir `filmer_monde_client.gd`) : `dernier` pointe nulle part, seul le script ouvre la copie.
##
## LANCEMENT (copie de tournage, user:// à part) :
##   Godot_v4.7-stable_win64_console.exe --path D:/SpannerGames/ATELIER/MarchingBlocks/worktrees/MB_tournage_monde_client --fixed-fps 30 \
##       --write-movie <rush>.avi --script res://DEV_TOOLS/filmer_tunnel_client.gd [-- --projet=<.mbproj>]

const PROJET_DEFAUT := "C:/Users/jorda/AppData/Roaming/MB_tournage_monde_client/monde_client/monde_client.mbproj"
const CENTRE := Vector3(0.5, 9.0, -4.5)       # le centre de l'île, pour la vue haute
const REGARD := 5.0                            # on regarde à tant de cases devant soi, dans le tube

var _projet := PROJET_DEFAUT
var _axe: Array = []          # l'axe du tunnel (Vector3), lu dans tunnel.json
var _longueurs: Array = []    # la longueur cumulée à chaque point
var _salle: Array = []


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
	_derouler.call_deferred()


func _derouler() -> void:
	var t := FileAccess.get_file_as_string(_projet.get_base_dir().path_join("tunnel.json"))
	var d: Variant = JSON.parse_string(t)
	if not d is Dictionary:
		print("⚠ tunnel.json absent ou illisible à côté de %s" % _projet)
		_rendre_les_reglages()
		quit(1)
		return
	for p in d["chemin"]:
		_axe.append(Vector3(p[0], p[1], p[2]))
	_salle = d["salle"]
	_longueurs = [0.0]
	for i in range(1, _axe.size()):
		_longueurs.append(_longueurs[i - 1] + (_axe[i] - _axe[i - 1]).length())
	await _images(60)
	if not await _ecran._ouvrir(_projet):
		print("⚠ la copie ne s'ouvre pas : %s" % _projet)
		_rendre_les_reglages()
		quit(1)
		return
	print("couches : %d" % _ecran._couches.size())
	_vue = _ecran._vue
	if _ecran._legende_formes != null:
		_ecran._legende_formes.basculer(false, false)
	await _ecran._changer_d_atelier("monde")
	var m := InputEventMouseMotion.new()
	m.position = Vector2(140, 700)
	m.global_position = m.position
	Input.parse_input_event(m)
	var debut: Vector3 = _axe[0]
	var oeil0 := debut + Vector3(16, 13, 34)
	var vise0 := debut + Vector3(-2, -3, -16)
	_poser_oeil(oeil0, vise0)
	await _images(150)    # le feuillage, l'eau et les ombres se posent

	# 1. L'APPROCHE : de haut et de côté, on descend vers la bouche du tube, l'île derrière.
	_plan("approche")
	var n := 70
	var bouche := _au(0.0) + (_au(0.0) - _au(3.0)).normalized() * 1.0
	for i in n:
		var k := _doux(float(i) / (n - 1))
		_poser_oeil(oeil0.lerp(bouche, k), vise0.lerp(_au(REGARD), k))
		await _images(1)

	# 2. LE TUBE : la vitesse suit l'endroit, le regard se lève sous la mer et dans la salle.
	_plan("tube")
	var s := 0.0
	var v := 9.0
	var total: float = _longueurs.back()
	var leve := 0.0
	while s < total:
		var p := _lisse(s)
		var cible := _vitesse(p)
		v = lerpf(v, cible, 0.06)
		var dans_la_salle := _dans_la_salle(p)
		var sous_la_mer := p.y < 2.0 and p.z > 76.0 and p.z < 100.0
		leve = lerpf(leve, 2.2 if dans_la_salle else (1.4 if sous_la_mer else 0.0), 0.05)
		var vise := _lisse(minf(s + REGARD, total + REGARD)) + Vector3(leve * 0.6 if sous_la_mer else 0.0, leve, 0)
		_poser_oeil(p, vise)
		await _images(1)
		s += v / FPS
	_plan("sortie")

	# 3. LA SORTIE : on monte en vue haute au-dessus de l'île, le regard glisse vers son centre.
	var fin := _lisse(total)
	var avant := (_au(total) - _au(total - 3.0)).normalized()
	var az := atan2(fin.x - CENTRE.x, fin.z - CENTRE.z)
	var haut := _oeil_orbite(az, 0.92, 105.0)
	n = 75
	for i in n:
		var k := _doux(float(i) / (n - 1))
		var o := fin.lerp(haut, k) + avant * 10.0 * sin(PI * k)
		_poser_oeil(o, (fin + avant * REGARD).lerp(CENTRE, _doux(minf(1.0, k * 1.4))))
		await _images(1)

	# 4. UN COURT TOUR autour de l'île.
	_plan("tour")
	n = 90
	for i in n:
		var k := float(i) / (n - 1)
		_poser_camera(CENTRE, az + 1.1 * _doux(k) + 0.25 * k, lerpf(0.92, 0.72, _doux(k)), lerpf(105.0, 122.0, _doux(k)))
		await _images(1)
	await _images(10)
	_plan("fin")
	_rendre_les_reglages()
	quit(0)


## Le point de l'axe à la longueur `s` (au-delà des bouts : prolongé tout droit).
func _au(s: float) -> Vector3:
	if s <= 0.0:
		return _axe[0] + (_axe[0] - _axe[1]).normalized() * -s
	for i in range(1, _axe.size()):
		if s <= _longueurs[i]:
			return _axe[i - 1].lerp(_axe[i], (s - _longueurs[i - 1]) / (_longueurs[i] - _longueurs[i - 1]))
	var n := _axe.size()
	return _axe[n - 1] + (_axe[n - 1] - _axe[n - 2]).normalized() * (s - _longueurs.back())


## L'axe ADOUCI dans les coudes (une moyenne sur ±2 cases) : la caméra ne casse pas sa trajectoire.
func _lisse(s: float) -> Vector3:
	var somme := Vector3.ZERO
	for k in 9:
		somme += _au(s + (k - 4) * 0.5)
	return somme / 9.0


func _dans_la_salle(p: Vector3) -> bool:
	return p.z >= float(_salle[0][2]) - 1.0 and p.z <= float(_salle[1][2]) + 2.0 and p.y < float(_salle[1][1])


## La vitesse voulue, en cases par seconde : posée sur l'îlot, lente sous la mer et dans la salle, vive sous la terre.
func _vitesse(p: Vector3) -> float:
	if _dans_la_salle(p):
		return 6.0
	if p.y < 2.0 and p.z > 76.0 and p.z < 100.0:
		return 7.0
	if p.y > 5.0 and p.z > 100.0:
		return 10.0
	if p.z > float(_salle[1][2]):
		return 16.0
	return 12.0


func _oeil_orbite(az: float, el: float, dist: float) -> Vector3:
	return CENTRE + Vector3(cos(el) * sin(az), sin(el), cos(el) * cos(az)) * dist


## La caméra à l'ŒIL donné, qui regarde `vise` (le modèle d'orbite de la vue : cible, azimut, élévation, distance).
func _poser_oeil(oeil: Vector3, vise: Vector3) -> void:
	var d := oeil - vise
	_poser_camera(vise, atan2(d.x, d.z), asin(clampf(d.y / d.length(), -1.0, 1.0)), d.length())
