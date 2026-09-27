extends SceneTree
##
## PRÉPARE LE PROJET D'ESSAI UNITY — le vrai témoin, exporté par l'appli, pour être lu par le vrai glTFast.
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/preparer_essai_unity.gd
##
## Écrit dans `engines/unity/test-project/Assets/` :
##   witness.mbset/          le jeu de tuiles du témoin, tel que « Export to engines » l'écrit ;
##   witness_cells.json      ses cases, en espace du FORMAT ;
##   witness_expected.json   ce que MarchingBlocks pose dessus — l'attendu, calculé par `MB.poses()`.
## ⚠ L'attendu vient de la RÉFÉRENCE, pas du greffon Unity : `WitnessTests.cs` compare le greffon à lui.

const BM := preload("res://addons/marching_blocks_plugin_godot/blocs_maitres.gd")
const FN := preload("res://addons/marching_blocks_plugin_godot/format_neutre.gd")
const World := preload("res://addons/marchingblocks_paint/mb_world.gd")
const CIBLE := "D:/MarchingBlocks/engines/unity/test-project/Assets"


## ⚠ DIFFÉRÉ : pendant `_initialize`, le `_ready()` du monde n'a pas encore tourné — sa grille `Cells`
## n'existe pas, le script plante, et un script planté n'appelle jamais `quit()` : il PEND (charte §6).
func _initialize() -> void:
	_preparer.call_deferred()


func _preparer() -> void:
	var lot: MeshLibrary = BM.librairie()["lot"]
	var r: Dictionary = FN.exporter(lot, CIBLE, "witness", "MarchingBlocks (test)")
	if r.has("erreur"):
		print("✗ " + r["erreur"])
		quit(1)
		return
	var pleines: Dictionary = BM.cases(0)
	var cellules: Array = []
	for c in pleines:
		cellules.append([c.x, c.y, c.z])
	var comptes := {}
	var familles: Dictionary = FN.familles_du_lot(lot)
	for cle in familles:
		comptes[cle] = (familles[cle] as Array).size()
	_ecrire(CIBLE.path_join("witness_cells.json"), cellules)
	_ecrire(CIBLE.path_join("witness_expected.json"), FN.attendu(pleines, comptes))
	_ecrire(CIBLE.path_join("witness_geometry.json"), _coutures(pleines))
	print("%s — %d tuiles, %d cases" % [r["dossier"], r["tuiles"], cellules.size()])
	quit(0)


func _ecrire(chemin: String, donnees) -> void:
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string(JSON.stringify(donnees))
	f.close()


## L'EMPREINTE DE LA GÉOMÉTRIE POSÉE par le greffon Godot : le centre de chaque triangle placé, en espace
## du FORMAT, × 1 200 (les coordonnées du témoin sont des multiples de 1/12 : des entiers EXACTS, donc
## aucun arrondi ne bascule d'un moteur à l'autre), triés, puis un MD5. Une tuile tournée ou reflétée à
## tort change l'empreinte.
## ⚠ **ELLE REMPLACE UN CONTRÔLE D'ÉTANCHÉITÉ QUI ÉTAIT AVEUGLE** : les tuiles du témoin aminci sont des
## boîtes CLOSES et DISJOINTES (sa matière est rentrée d'un quart de case, elle ne traverse jamais un plan
## de coupe) — 0 arête ouverte quelles que soient les rotations, mesuré en les annulant toutes. Un
## contrôle qui ne peut pas échouer ne garde rien (charte §6).
func _coutures(pleines: Dictionary) -> Dictionary:
	var w: Node3D = World.new()
	root.add_child(w)
	for c in pleines:
		(w.get_node("Cells") as GridMap).set_cell_item(c, 0)
	w.tileset = CIBLE.path_join("witness.mbset/tileset.json")
	var g := w.get_node("Tiles") as GridMap
	var centres := PackedStringArray()
	for v in g.get_used_cells():
		var xf: Transform3D = g.transform * Transform3D(g.get_basis_with_orthogonal_index(
			g.get_cell_item_orientation(v)), g.map_to_local(v))
		var m: Mesh = g.mesh_library.get_item_mesh(g.get_cell_item(v))
		for s in m.get_surface_count():
			var a: Array = m.surface_get_arrays(s)
			var p: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var o: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null 				else PackedInt32Array(range(p.size()))
			for t in range(0, o.size(), 3):
				var c: Vector3 = (xf * p[o[t]] + xf * p[o[t + 1]] + xf * p[o[t + 2]]) * 400.0
				centres.append("%d,%d,%d" % [roundi(c.x), roundi(c.y), roundi(c.z)])
	w.free()
	centres.sort()
	var empreinte := "\n".join(centres).md5_text()
	print("géométrie : %d triangles, empreinte %s" % [centres.size(), empreinte])
	return {"triangles": centres.size(), "centroids_md5": empreinte}
