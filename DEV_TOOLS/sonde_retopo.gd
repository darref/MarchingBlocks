extends SceneTree
## SONDE — la retopo (`retopo.gd`) : ce que Simplify et Relax font, en chiffres, et ce qu'ils coûtent. Elle ne juge rien
## (c'est `test_maillage_edite`, `test_sections`, `fumee_appli`) : elle dit ce qui EXISTE.
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_retopo.gd

const ME := preload("res://addons/marchingblocks_core/maillage_edite.gd")
const RT := preload("res://addons/marchingblocks_core/retopo.gd")
const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")


func _initialize() -> void:
	for tol in [0.0, 0.01, 0.05]:
		var t: RefCounted = TL.depuis_le_temoin_calcule()
		var av := 0
		var ap := 0
		var verrous := 0
		var debut := Time.get_ticks_msec()
		for c in t.tuiles:
			av += t.tuiles[c].faces.size()
			var r: Dictionary = RT.simplifier(t.tuiles[c], tol)
			ap += t.tuiles[c].faces.size()
			verrous += int(r["verrous"])
		print("Simplify %.2f sur le témoin calculé : %d faces → %d (%d ms, %d sommets verrouillés)" % [tol, av, ap,
			Time.get_ticks_msec() - debut, verrous])
	# Un témoin plus fin : chaque tuile subdivisée deux fois (ce qu'un artiste fait avant de sculpter).
	var t2: RefCounted = TL.depuis_le_temoin_calcule()
	var av2 := 0
	for c in t2.tuiles:
		var m: RefCounted = t2.tuiles[c]
		m.subdiviser(range(m.faces.size()))
		m.subdiviser(range(m.faces.size()))
		av2 += m.faces.size()
	var debut2 := Time.get_ticks_msec()
	var ap2 := 0
	for c in t2.tuiles:
		RT.simplifier(t2.tuiles[c], 0.01)
		ap2 += t2.tuiles[c].faces.size()
	print("Simplify 0,01 sur le témoin subdivisé deux fois : %d faces → %d (%d ms)" % [av2, ap2, Time.get_ticks_msec() - debut2])
	var debut3 := Time.get_ticks_msec()
	var dep := 0
	for c in t2.tuiles:
		dep += int(RT.detendre(t2.tuiles[c])["deplaces"])
	print("Relax ensuite : %d sommets déplacés (%d ms)" % [dep, Time.get_ticks_msec() - debut3])
	quit(0)
