extends SceneTree
## Les sommets récoltés du témoin (les 541 d'où viennent les tuiles) qu'aucune carte de la légende ne
## contient — le « sens inverse » de World n'aurait rien à nommer pour eux.
const FT := preload("res://addons/marchingblocks_core/formes_du_temoin.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const Tranchage := preload("res://addons/marchingblocks_core/tranchage.gd")

func _initialize() -> void:
	var l: Array = FT.legende()
	var pleines: Dictionary = BM.cases(0)
	var plafond: int = FT.MB.plafond_de(pleines)
	var orphelins: Array = []
	var total := 0
	for x in BM.COTE - 1:
		for y in BM.COTE - 1:
			for z in BM.COTE - 1:
				var v := Vector3i(x, y, z)
				if Tranchage.cle_du_sommet(pleines, v, plafond).is_empty():
					continue
				total += 1
				if FT.cartes_du_sommet(l, v).is_empty():
					orphelins.append(v)
	print("%d sommets récoltés, %d sans carte" % [total, orphelins.size()])
	var par := {}
	for v in orphelins:
		var k := "x=%d" % v.x
		par[k] = int(par.get(k, 0)) + 1
	print(par)
	print(orphelins.slice(0, 60))
	quit(0)
