extends SceneTree
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
func _initialize() -> void:
	for r in BM.RETRAITS:
		var t0 := Time.get_ticks_msec()
		var bilan: Dictionary = BM.librairie(r)
		var lot: MeshLibrary = bilan["lot"]
		var m: ArrayMesh = BM.maillage_du_temoin(0, r)
		print("retrait %s : %d tuiles, %d manquantes, %d erreurs, %d remarques, aabb %s, %d ms" % [r, lot.get_item_list().size(), bilan["manquantes"].size(), bilan["erreurs"].size(), bilan["remarques"].size(), m.get_aabb(), Time.get_ticks_msec()-t0])
		for e in bilan["erreurs"].slice(0,3): print("  E ", e)
		for e in bilan["remarques"].slice(0,3): print("  R ", e)
	quit()
