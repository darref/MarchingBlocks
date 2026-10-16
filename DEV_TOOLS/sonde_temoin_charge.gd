extends SceneTree
## SONDE — le témoin que l'écran charge pour une couche (`_temoin_de`) : sommets d'une tuile, contre le témoin calculé.
##   godot --headless --path . --script res://DEV_TOOLS/sonde_temoin_charge.gd -- --projet=<.mbproj> --couche=Meadow
const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")

func _initialize() -> void:
	var projet := ""
	var nom := "Meadow"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--projet="):
			projet = a.substr(9)
		elif a.begins_with("--couche="):
			nom = a.substr(9)
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(projet))
	for c in d["couches"]:
		if str(c["nom"]) == nom:
			var chemin: String = c["temoin"]
			print("témoin : %s, existe : %s" % [chemin, FileAccess.file_exists(chemin)])
			var t: RefCounted = TL.depuis_dictionnaire(JSON.parse_string(FileAccess.get_file_as_string(chemin)))
			var base: RefCounted = TL.depuis_le_temoin_calcule(0.0)
			if t == null:
				print("illisible")
				break
			var cle: String = "mb_plaque_b2h2_dehors"
			print("tuiles %d ; %s : %d sommets (calculé : %d) ; matériaux %d" % [t.tuiles.size(), cle,
				t.tuiles[cle].sommets.size(), base.tuiles[cle].sommets.size(), t.materiaux.size()])
	quit(0)
