extends SceneTree
## Ce que la légende des formes rend : cases, tuiles, tuiles propres à chaque carte.
const FT := preload("res://addons/marchingblocks_core/formes_du_temoin.gd")

func _initialize() -> void:
	var t := Time.get_ticks_msec()
	var l: Array = FT.legende()
	print("légende en %d ms" % (Time.get_ticks_msec() - t))
	var toutes := {}
	for c in l:
		for k in c["cles"]:
			toutes[k] = true
		print("%-18s %3d cases  %2d tuiles " % [c["nom"], c["cases"].size(), c["cles"].size()])
	print("union : %d clés" % toutes.size())
	print("finisseur : %s" % [FT.cases_du_finisseur()])
	quit(0)
