## Sonde : ce que coûte UN enregistrement du projet (sérialiser + écrire + renommer), contre ce que coûte
## la reconstruction d'une couche (`MB.poses`) — sur test.mbproj. Ne conçoit rien, mesure.
extends SceneTree

const Projet := preload("res://app/projet.gd")
const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")

func _initialize() -> void:
	var texte := FileAccess.get_file_as_string("res://test.mbproj")
	var erreurs: Array = []
	var p: Dictionary = Projet.depuis_texte(texte, erreurs)
	var n := 0
	for c in p["couches"]:
		n += (c["cases"] as Dictionary).size()
	print("couches %d, cases %d, %d octets" % [p["couches"].size(), n, texte.length()])
	for essai in 3:
		var t0 := Time.get_ticks_usec()
		var sorties: Array = []
		for c in p["couches"]:
			var e: Dictionary = c.duplicate()
			var cases := {}
			for k in c["cases"]:
				cases[k] = true
			e["cases"] = cases
			sorties.append(e)
		var t1 := Time.get_ticks_usec()
		var s: String = Projet.vers_texte(sorties, 0, [])
		var t2 := Time.get_ticks_usec()
		var f := FileAccess.open("user://sonde_enr.tmp", FileAccess.WRITE)
		f.store_string(s)
		f.close()
		DirAccess.rename_absolute("user://sonde_enr.tmp", "user://sonde_enr.mbproj")
		var t3 := Time.get_ticks_usec()
		print("copie %.1f ms · JSON %.1f ms · écriture %.1f ms · total %.1f ms" %
			[(t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0, (t3 - t0) / 1000.0])
	for c in p["couches"]:
		var t0 := Time.get_ticks_usec()
		MB.poses(c["cases"], {})
		print("couche « %s » (%d cases) : MB.poses %.1f ms" % [c["nom"], c["cases"].size(), (Time.get_ticks_usec() - t0) / 1000.0])
	quit(0)
