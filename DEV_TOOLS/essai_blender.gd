extends SceneTree
##
## L'ESSAI BLENDER — les UV et la texture survivent-elles à un vrai passage dans Blender ?
##
## LANCEMENT (sur la machine qui a Blender)
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/essai_blender.gd -- --preparer --dossier=C:/tmp/mb
##   blender --background --factory-startup --python DEV_TOOLS/essai_blender.py -- C:/tmp/mb
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/essai_blender.gd -- --verifier --dossier=C:/tmp/mb
##
## ⚠ **CE QUE LES SUITES NE PEUVENT PAS DIRE.** `test_blocs_maitres` §15 et `test_faux_artiste` relisent
## NOS fichiers. Ici, c'est Blender qui les relit et les réécrit :
##   • le témoin OBJ, importé puis exporté en .glb : ses UV doivent revenir celles de la règle, À
##     L'ENDROIT (l'OBJ compte `v` depuis le bas, le glTF depuis le haut — deux conversions, une par
##     côté, et une seule oubliée retournerait la texture) ;
##   • le faux travail d'artiste, importé puis réexporté : texture, UV, deux objets ou un, il doit se
##     trancher comme avant — 541 items, 0 erreur, 0 remarque.
## ⚠ Ce n'est PAS une suite : il lui faut Blender. Il rend quand même un verdict et un code.

const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const Faux := preload("res://DEV_TOOLS/faux_artiste.gd")

var _echecs := 0


func _initialize() -> void:
	var dossier := ""
	var mode := ""
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--dossier="):
			dossier = option.substr(10)
		elif option in ["--preparer", "--verifier"]:
			mode = option
	if dossier == "" or mode == "":
		print("usage : -- --preparer|--verifier --dossier=<dossier hors du projet>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(dossier)
	if mode == "--preparer":
		var e: String = BM.exporter_le_bloc(dossier.path_join("temoin.obj"))
		var m: Dictionary = Faux.fabriquer(dossier.path_join("faux.glb"))
		print("préparé : temoin.obj (%s), faux.glb (%s)" % ["ok" if e == "" else e,
			"ok" if m["erreur"] == "" else m["erreur"]])
		quit(0 if e == "" and m["erreur"] == "" else 1)
		return
	_verifier_le_temoin(dossier.path_join("temoin_blender.glb"))
	_verifier_le_faux(dossier.path_join("faux_blender.glb"))
	print("VERDICT : %s" % ("ÉCHEC" if _echecs > 0 else "OK"))
	quit(1 if _echecs > 0 else 0)


func _dire(condition: bool, quoi: String) -> void:
	if not condition:
		_echecs += 1
		print("  ÉCHEC — %s" % quoi)


func _verifier_le_temoin(chemin: String) -> void:
	print("1. le témoin revenu de Blender")
	var journal: Array = []
	var relu: ArrayMesh = BM._lire_glb(chemin, journal)
	_dire(relu != null, "illisible : %s" % str(journal))
	if relu == null:
		return
	var uv_de: Callable = BM._uv_du_temoin(0)
	var triangles := 0
	var faux := 0
	var sans_uv := 0
	for s in relu.get_surface_count():
		var arrays: Array = relu.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_TEX_UV] == null:
			sans_uv += 1
			continue
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var idx = arrays[Mesh.ARRAY_INDEX]
		var ordre: PackedInt32Array = (idx as PackedInt32Array) if idx != null \
			else PackedInt32Array(range(v.size()))
		for t in range(0, ordre.size() - 2, 3):
			triangles += 1
			var attendu: PackedVector2Array = uv_de.call(v[ordre[t]], v[ordre[t + 1]], v[ordre[t + 2]])
			for k in 3:
				if attendu[k].distance_to(uv[ordre[t + k]]) > 0.0005:
					faux += 1
					break
	_dire(sans_uv == 0, "%d surface(s) revenues sans UV" % sans_uv)
	_dire(triangles > 30000, "seulement %d triangles relus" % triangles)
	_dire(faux == 0, "%d triangle(s) sur %d reviennent avec d'autres UV que la règle" % [faux, triangles])
	print("   %d triangles, %d aux UV fausses, %d surface(s) sans UV" % [triangles, faux, sans_uv])


func _verifier_le_faux(chemin: String) -> void:
	print("2. le faux travail revenu de Blender")
	var bilan: Dictionary = BM.librairie_depuis_glb(chemin)
	var lot: MeshLibrary = bilan["lot"]
	_dire((bilan["erreurs"] as Array).is_empty(), "%d erreur(s) : %s"
		% [(bilan["erreurs"] as Array).size(), str((bilan["erreurs"] as Array).slice(0, 3))])
	_dire(lot.get_item_list().size() == 549, "%d items au lieu de 549" % lot.get_item_list().size())
	var gardees: Array = (bilan["remarques"] as Array).filter(
		func(r: String) -> bool: return r.begins_with("couture") or r.begins_with("texture"))
	_dire(gardees.is_empty(), "%d remarque(s) : %s" % [gardees.size(), str(gardees.slice(0, 2))])
	var sans_texture := 0
	for id in lot.get_item_list():
		var mesh: Mesh = lot.get_item_mesh(id)
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s) as StandardMaterial3D
			if m == null or m.albedo_texture == null or mesh.surface_get_arrays(s)[Mesh.ARRAY_TEX_UV] == null:
				sans_texture += 1
	_dire(sans_texture == 0, "%d surface(s) de tuile sans texture ou sans UV" % sans_texture)
	print("   %d items, %d erreur(s), %d remarque(s) (%s)" % [lot.get_item_list().size(),
		(bilan["erreurs"] as Array).size(), (bilan["remarques"] as Array).size(),
		str(bilan["remarques"]).substr(0, 160)])
