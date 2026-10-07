extends SceneTree
## LA CAPTURE DE L'EAU RECALCULÉE DU GREFFON GODOT (7 octobre 2026, PARITE.md §12 : « à l'image, la nappe recalculée sous
## les six presets, à côté de la nappe cuite du même monde — indiscernables »).
##
## L'appli exporte un monde avec ses nappes CUITES (`FormatMonde.exporter`) ; le greffon l'importe DEUX fois
## (`WorldFile.build`), chacune dans son propre monde 3D (deux SubViewport, même caméra, même lumière, même instant) :
## à gauche la nappe cuite telle qu'importée, à droite la nappe que le greffon a REFAITE (`rebuild_water_now`). Les cases
## sont dessinées en cubes gris (les couches n'ont pas de jeu de tuiles : seule l'eau est jugée). Pour chaque aspect :
## une image côte à côte, et l'écart mesuré pixel à pixel (moyen, maximal, part des pixels à plus de 8/255).
##
## LANCEMENT — ⚠ AVEC FENÊTRE (le headless ne rend rien) :
##   Godot_v4.7-stable_win64_console.exe --path <dépôt> --script res://DEV_TOOLS/capture_eau_greffon.gd \
##       -- --dossier=C:/chemin/des/captures [--exemple]
## `--exemple` : l'exemple livré aussi, s'il a été exporté par `banc_eau_greffon.gd` (user://banc_eau_greffon/export).

const FL := preload("res://addons/marchingblocks_core/fluides.gd")
const EM := preload("res://addons/marchingblocks_core/eau_maillage.gd")
const FM := preload("res://addons/marchingblocks_core/format_monde.gd")
const WorldFile := preload("res://addons/marchingblocks_paint/mb_world_file.gd")
const WaterNode := preload("res://addons/marchingblocks_paint/mb_water_node.gd")
const Shaders := preload("res://addons/marchingblocks_paint/mb_shaders.gd")

const TAILLE := Vector2i(960, 640)

var _dossier := ""
var _exemple := false
var _plans: Array = []   # [nom, chemin du world.json, caméra (position, cible)]
var _vues: Array = []    # deux SubViewport
var _eaux: Array = []    # les nœuds d'eau de chaque côté
var _etape := 0
var _attente := 0
var _plan := -1
var _aspect := -1
var _bilan: Array = []


func _initialize() -> void:
	for o in OS.get_cmdline_user_args():
		if o.begins_with("--dossier="):
			_dossier = o.substr("--dossier=".length())
		elif o == "--exemple":
			_exemple = true
	if _dossier == "":
		_dossier = ProjectSettings.globalize_path("user://capture_eau_greffon")
	DirAccess.make_dir_recursive_absolute(_dossier)
	var f = JSON.parse_string(FileAccess.get_file_as_string("res://addons/marchingblocks_paint/water_mesh_conformance.json"))
	_plans.append(["basin", _exporter(f, "a cliff above a basin", [[Vector3i(2, 5, 1)]]), null, Vector3(9.0, 6.0, -9.0)])
	_plans.append(["island", _exporter(f, "island", [[Vector3i(-1, 2, -1)], [Vector3i(4, 4, 4)]]),
		[Vector3(14.0, 11.0, 16.0), Vector3(4.0, 2.0, 4.0)]])
	var ex := ProjectSettings.globalize_path("user://banc_eau_greffon/export/exemple.mbworld/world.json")
	if _exemple and FileAccess.file_exists(ex):
		_plans.append(["exemple", ex, null, Vector3(-9.0, 7.0, 11.0)])


## Le monde nommé des cas, exporté par l'appli avec ses nappes cuites (une couche d'eau par liste de sources).
func _exporter(f: Dictionary, monde: String, couches_d_eau: Array) -> String:
	var occ := {}
	for c in f["worlds"][monde]:
		occ[Vector3i(int(c[0]), int(c[1]), int(c[2]))] = true
	var toutes: Array = []
	for l in couches_d_eau:
		toutes.append_array(l)
	var w := FL.monde(occ, toutes)
	var eaux: Array = []
	var k := 0
	for i in couches_d_eau.size():
		var n: int = (couches_d_eau[i] as Array).size()
		eaux.append({"nom": "Water %d" % i, "visible": true, "preset": "stylise", "sources": couches_d_eau[i],
			"maillage": EM.maillage((w["corps"] as Array).slice(k, k + n), occ)})
		k += n
	var dossier := ProjectSettings.globalize_path("user://capture_eau_greffon/" + monde.replace(" ", "_"))
	DirAccess.make_dir_recursive_absolute(dossier)
	var r := FM.exporter([{"nom": "Rock", "visible": true, "source": "", "lot": null, "cases": occ.keys()}], dossier,
		"monde", "capture", eaux)
	return str(r["dossier"]).path_join("world.json")


func _process(_delta: float) -> bool:
	if _attente > 0:
		_attente -= 1
		return false
	match _etape:
		0:   # le plan suivant
			_plan += 1
			if _plan >= _plans.size():
				var f := FileAccess.open(_dossier.path_join("bilan.txt"), FileAccess.WRITE)
				f.store_string("\n".join(PackedStringArray(_bilan)) + "\n")
				f.close()
				print("\n".join(PackedStringArray(_bilan)))
				print("captures dans %s" % _dossier)
				return true
			_monter(_plans[_plan])
			_aspect = -1
			_etape = 1
		1:   # l'aspect suivant
			_aspect += 1
			if _aspect >= Shaders.WATER_LOOKS.size():
				for v in _vues:
					v.queue_free()
				_vues = []
				_etape = 0
				_attente = 2
				return false
			for cote in _eaux:
				for w in cote:
					w.look = Shaders.WATER_LOOKS[_aspect]
					w.rebuild()
			_attente = 12
			_etape = 2
		2:   # la prise
			_prendre()
			_etape = 1
	return false


## Deux mondes 3D côte à côte : le même monde importé deux fois ; à droite, l'eau refaite par le greffon.
func _monter(plan: Array) -> void:
	_eaux = []
	var tenants: Array = []
	var t0 := Time.get_ticks_msec()
	for cote in 2:
		var v := SubViewport.new()
		v.size = TAILLE
		v.own_world_3d = true
		v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		v.msaa_3d = Viewport.MSAA_4X
		root.add_child(v)
		_vues.append(v)
		var env := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_SKY
		var ciel := Sky.new()
		ciel.sky_material = ProceduralSkyMaterial.new()
		e.sky = ciel
		e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.environment = e
		v.add_child(env)
		var soleil := DirectionalLight3D.new()
		soleil.rotation_degrees = Vector3(-50, -35, 0)
		soleil.shadow_enabled = true
		v.add_child(soleil)
		var tenant := Node3D.new()
		v.add_child(tenant)
		var b := WorldFile.build(plan[1], tenant)
		if b.has("error"):
			push_error("capture : %s" % b["error"])
			continue
		var eaux: Array = (b["extras"] as Array).filter(func(x: Node) -> bool: return x.get_script() == WaterNode)
		_eaux.append(eaux)
		if cote == 1 and not eaux.is_empty():
			var dt: float = eaux[0].rebuild_water_now()
			_bilan.append("%s : nappe refaite par le greffon en %.2f s (%s)" % [plan[0], dt, eaux[0].last_reused])
		tenants.append([tenant, b["nodes"], v])
	# LA MÊME CAMÉRA des deux côtés : pour l'exemple, cadrée sur une cascade de l'eau refaite (à droite).
	var cible: Vector3
	var oeil: Vector3
	if plan[2] != null:
		oeil = plan[2][0]
		cible = plan[2][1]
	else:
		cible = _une_cascade(_eaux[1] if _eaux.size() > 1 else [])
		oeil = cible + (plan[3] as Vector3)
	for t in tenants:
		_cubes(t[0], t[1], cible, 26.0 if plan[2] == null else 1e9)
		var cam := Camera3D.new()
		cam.fov = 55.0
		(t[2] as SubViewport).add_child(cam)
		cam.look_at_from_position(oeil, cible)
		cam.current = true
	print("%s monté en %.1f s" % [plan[0], (Time.get_ticks_msec() - t0) / 1000.0])


## Le pied d'une cascade de l'eau refaite (pour cadrer l'exemple) : le milieu de la plus longue chute d'une rivière.
func _une_cascade(eaux: Array) -> Vector3:
	var mene: Node = eaux[0] if not eaux.is_empty() else null
	var meilleur := Vector3.ZERO
	var long := 0
	if mene == null or mene._base.is_empty():
		return meilleur
	for r in mene._base["world"]["bodies"]:
		if r["error"] != "" or r["kind"] != "river":
			continue
		var n := 0
		for e in r["course"]:
			if e["kind"] == "fall":
				n += 1
				if n > long:
					long = n
					meilleur = Vector3(e["cell"]) + Vector3(0.5, 0.5, 0.5)
			else:
				n = 0
	return meilleur


## Les cases des couches, en cubes gris (à moins de `rayon` de la cible).
func _cubes(tenant: Node3D, couches: Array, cible: Vector3, rayon: float) -> void:
	var cases: Array = []
	for l in couches:
		for c: Vector3i in l.cells():
			if (Vector3(c) + Vector3.ONE * 0.5).distance_to(cible) < rayon:
				cases.append(c)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var boite := BoxMesh.new()
	# Une case pleine, un cube d'une case : la nappe qui déborde sous la roche y disparaît, comme sous les tuiles.
	boite.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.48, 0.45, 0.42)
	mat.roughness = 0.95
	boite.material = mat
	mm.mesh = boite
	mm.instance_count = cases.size()
	for i in cases.size():
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(cases[i]) + Vector3.ONE * 0.5))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	tenant.add_child(mi)


## L'image côte à côte (cuite à gauche, refaite à droite) et l'écart pixel à pixel.
func _prendre() -> void:
	if _vues.size() != 2:
		return
	var a := (_vues[0] as SubViewport).get_texture().get_image()
	var b := (_vues[1] as SubViewport).get_texture().get_image()
	a.convert(Image.FORMAT_RGB8)
	b.convert(Image.FORMAT_RGB8)
	var somme := 0.0
	var maxi := 0
	var forts := 0
	var da := a.get_data()
	var db := b.get_data()
	for i in da.size():
		var d := absi(int(da[i]) - int(db[i]))
		somme += d
		maxi = maxi if d <= maxi else d
		if d > 8:
			forts += 1
	var duo := Image.create_empty(TAILLE.x * 2 + 8, TAILLE.y, false, Image.FORMAT_RGB8)
	duo.fill(Color.WHITE)
	duo.blit_rect(a, Rect2i(Vector2i.ZERO, TAILLE), Vector2i.ZERO)
	duo.blit_rect(b, Rect2i(Vector2i.ZERO, TAILLE), Vector2i(TAILLE.x + 8, 0))
	var nom: String = "%s_%s.png" % [_plans[_plan][0], Shaders.WATER_LOOKS[_aspect]]
	duo.save_png(_dossier.path_join(nom))
	var ligne := "%s : écart moyen %.3f/255, maximal %d/255, %.3f %% des valeurs à plus de 8/255" % [nom,
		somme / da.size(), maxi, 100.0 * forts / da.size()]
	_bilan.append(ligne)
	print(ligne)
