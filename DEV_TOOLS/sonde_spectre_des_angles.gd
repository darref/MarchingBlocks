extends SceneTree

## SONDE — LE SPECTRE DES ANGLES : de quoi une surface est-elle faite ?
##
## ⚠ **ELLE EXISTE PARCE QUE JORDAN A MODELÉ SA RÉPONSE PLUTÔT QUE DE LA DÉCRIRE (26 septembre 2026).**
## Il a repris le témoin tel qu'il part et en a retiré ce qu'il appelle ses contremarches. Restait à
## savoir CE QU'IL AVAIT FAIT — et ni une image ni un compteur de lèvres ne le disent. L'aire des faces,
## rangée par angle depuis l'horizontale, le dit en cinq lignes : un chanfrein pur ne montre que 0°, 45°
## et 90° ; un lissage dual étale le spectre.
##
## ⚠ **ET ELLE A COMMENCÉ PAR MENTIR, FAUTE DE LIRE LA TOPOLOGIE.** `surface_get_arrays()` rend les
## sommets UNIQUES et la topologie à part : les maillages d'ici n'ont pas d'index, **un `.glb` revenu
## de Blender SI**. Lus trois par trois, ses 7 260 sommets fabriquaient 2 420 triangles imaginaires, et
## la sonde a décrit une surface « arrondie » avec des angles à 4°, 9°, 17°, 23°, 34°, 56°, 59°, 63° —
## rien de tout cela n'existe. Le vrai spectre est **0°, 45°, 90°** : un chanfrein, et rien d'autre.
## `Topologie.triangles_de()` porte désormais la règle, pour tout le monde.
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks ##       --script res://DEV_TOOLS/sonde_spectre_des_angles.gd -- --fichier=C:/chemin/vers/le.glb
const BM := preload("res://addons/marching_blocks_plugin_godot/blocs_maitres.gd")
const Topologie := preload("res://DEV_TOOLS/topologie.gd")
var _fichier := ""

func _initialize() -> void:
	for o in OS.get_cmdline_user_args():
		if o.begins_with("--fichier="):
			_fichier = o.substr("--fichier=".length())
	_decrire("LE TÉMOIN QUI EST PARTI (aminci)", BM.maillage_moitie(0))
	_decrire("LE LISSÉ à 0,35", BM.maillage_lisse(0, 0.5, 0.35))
	_decrire("LE LISSÉ à 1,00", BM.maillage_lisse(0, 0.5, 1.0))
	_decrire("LES FACES DIRECTES", BM.maillage_direct(0))
	var m: ArrayMesh = _lire(_fichier)
	if m == null:
		print("illisible")
		quit(1)
		return
	_decrire("LE SCULPT DE JORDAN", m)
	quit(0)


func _decrire(quoi: String, mesh: ArrayMesh) -> void:
	var v: PackedVector3Array = Topologie.triangles_de(mesh)
	var mini := Vector3.INF
	var maxi := -Vector3.INF
	for p in v:
		mini = mini.min(p)
		maxi = maxi.max(p)
	print("── %s ──" % quoi)
	print("   %d sommets, %d triangles" % [v.size(), v.size() / 3])
	print("   boîte : (%.3f, %.3f, %.3f) → (%.3f, %.3f, %.3f)"
		% [mini.x, mini.y, mini.z, maxi.x, maxi.y, maxi.z])
	# ── L'ORIENTATION DES FACES, pondérée par l'AIRE ──
	var seaux := {"horizontal exact": 0.0, "à moins de 1°": 0.0, "à moins de 6°": 0.0,
		"oblique": 0.0, "vertical à moins de 6°": 0.0, "vertical exact": 0.0}
	var aire_totale := 0.0
	var aires: Array = []
	for i in range(0, v.size() - 2, 3):
		var n: Vector3 = (v[i + 1] - v[i]).cross(v[i + 2] - v[i])
		var aire: float = 0.5 * n.length()
		if aire < 0.0000001:
			continue
		aire_totale += aire
		aires.append(aire)
		var c: float = absf(n.normalized().y)
		if c > 0.999999:
			seaux["horizontal exact"] += aire
		elif c > 0.99985:
			seaux["à moins de 1°"] += aire
		elif c > 0.9945:
			seaux["à moins de 6°"] += aire
		elif c > 0.1045:
			seaux["oblique"] += aire
		elif c > 0.000001:
			seaux["vertical à moins de 6°"] += aire
		else:
			seaux["vertical exact"] += aire
	for k in seaux:
		print("      %-24s %8.2f case²  (%.1f %%)"
			% [k, seaux[k], 100.0 * float(seaux[k]) / maxf(0.0001, aire_totale)])
	# LES ANGLES EXACTS PRÉSENTS, pondérés par l'aire
	var par_angle := {}
	for i in range(0, v.size() - 2, 3):
		var nn: Vector3 = (v[i + 1] - v[i]).cross(v[i + 2] - v[i])
		var ai: float = 0.5 * nn.length()
		if ai < 0.0000001:
			continue
		var deg: float = rad_to_deg(acos(clampf(absf(nn.normalized().y), 0.0, 1.0)))
		var cle: int = roundi(deg)
		par_angle[cle] = float(par_angle.get(cle, 0.0)) + ai
	var angles: Array = par_angle.keys()
	angles.sort()
	print("   angle depuis l'HORIZONTALE (0 = plat, 90 = mur) :")
	for d in angles:
		if float(par_angle[d]) > 0.05:
			print("      %3d° : %7.2f case²" % [d, par_angle[d]])
	aires.sort()
	print("   aire totale %.1f case² · plus petit triangle %.6f · médiane %.6f · plus grand %.4f"
		% [aire_totale, aires[0], aires[aires.size() / 2], aires[aires.size() - 1]])
	print("")


func _lire(chemin: String) -> ArrayMesh:
	if not FileAccess.file_exists(chemin):
		return null
	var d := GLTFDocument.new()
	var e := GLTFState.new()
	if d.append_from_file(chemin, e) != OK:
		return null
	var s: Node = d.generate_scene(e)
	if s == null:
		return null
	return _chercher(s)


func _chercher(n: Node) -> ArrayMesh:
	if n.has_method("get_mesh"):
		var m = n.call("get_mesh")
		if m is ArrayMesh:
			return m
	for c in n.get_children():
		var t: ArrayMesh = _chercher(c)
		if t != null:
			return t
	return null
