extends SceneTree
## SONDE — le coût d'un APERÇU de forme spéciale (recalculé à chaque case visée) sur un long conduit de taille 7, dans
## un massif plein de 40³ (« OUVERT » de la charte, §5). Ne conçoit rien, mesure.
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_cout_apercu_forme.gd

const FS := preload("res://addons/marchingblocks_core/formes_speciales.gd")


func _initialize() -> void:
	var occ := {}
	for x in 40:
		for y in 40:
			for z in 40:
				occ[Vector3i(x, y, z)] = true
	for cas in [["tunnel", "rond", 7], ["tunnel", "carre", 7], ["tunnel", "arche", 7], ["puits", "rond", 7],
			["pont", "rond", 7], ["escalier", "rond", 7], ["tunnel", "rond", 3]]:
		var r := {"quoi": cas[0], "profil": cas[1], "taille": cas[2], "longueur": 32, "garde_corps": true,
			"a": Vector3i(0, 20, 20), "face_a": Vector3i(-1, 0, 0)}
		if cas[0] == "puits":
			r["a"] = Vector3i(20, 39, 20)
			r["face_a"] = Vector3i(0, 1, 0)
		var t0 := Time.get_ticks_usec()
		var n := 5
		var s: Dictionary = {}
		for i in n:
			s = FS.forme(occ, r)
		print("%s %s taille %d : %.1f ms (%d posées, %d creusées, erreur « %s »)" % [cas[0], cas[1], cas[2],
			(Time.get_ticks_usec() - t0) / 1000.0 / n, s["poser"].size(), s["effacer"].size(), s["erreur"]])
	quit(0)
