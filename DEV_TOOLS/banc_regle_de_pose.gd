extends SceneTree
## BANC (headless) — la règle de pose sur l'EXEMPLE (4 octobre 2026 : reconstruire les couches en coûte l'essentiel,
## à l'ouverture et quand on cache une couche). Chronomètre, sur les sommets de la plus grande couche, chaque morceau
## de la décision d'un sommet (`MB.pose_du_sommet` et ce qu'elle appelle). Ne conçoit rien.
##   godot --headless --path . --script res://DEV_TOOLS/banc_regle_de_pose.gd

const Exemple := preload("res://app/exemple.gd")
const Projet := preload("res://app/projet.gd")
const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")


func _initialize() -> void:
	var erreurs: Array = []
	var chemin := Exemple.installer(Exemple.ARCHIVE, "user://banc_regle_de_pose", erreurs)
	var p := Projet.depuis_texte(FileAccess.get_file_as_string(chemin), erreurs)
	var union := {}
	var grande: Array = []
	for i in (p["couches"] as Array).size():
		var c: Dictionary = p["couches"][i]
		var liste: Array = c["cases"].keys() if c["cases"] is Dictionary else c["cases"]
		for k in liste:
			if not union.has(k):
				union[k] = i
		if liste.size() > grande.size():
			grande = liste
	var plafond := MB.plafond_de(union)
	var sommets := {}
	for c in grande:
		for s in MB.sommets_de(c):
			sommets[s] = true
	print("union %d cases, plafond %d ; %d sommets dans la plus grande couche" % [union.size(), plafond, sommets.size()])
	var cles := {}
	for c in MB.classes():
		cles[c] = 0
	var t := Time.get_ticks_usec()
	for s in sommets:
		MB.couche_du_sommet(union, s)
	_trace("couche_du_sommet", t)
	t = Time.get_ticks_usec()
	var bs := {}
	for s in sommets:
		bs[s] = MB.bits(union, s)
	_trace("bits", t)
	t = Time.get_ticks_usec()
	for s in sommets:
		MB.classer(bs[s])
	_trace("classer", t)
	t = Time.get_ticks_usec()
	var au_ciel := 0
	for s in sommets:
		if MB.exterieur_possible(bs[s]):
			au_ciel += 1
			MB.sous_le_ciel(union, s, plafond)
	_trace("sous_le_ciel (%d sommets à tester)" % au_ciel, t)
	t = Time.get_ticks_usec()
	for s in sommets:
		MB.pose_du_sommet(union, s, cles, plafond)
	_trace("pose_du_sommet entière", t)
	quit()


func _trace(nom: String, t0: int) -> void:
	print("%-50s %8.1f ms" % [nom, (Time.get_ticks_usec() - t0) / 1000.0])
