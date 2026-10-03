extends SceneTree
##
## RÉPARER LES CONTACTS DIAGONAUX DE L'EXEMPLE (Jordan, 3 octobre 2026 : « répare les contacts diagonaux de l'exemple »).
## L'exemple repris le 3 octobre en portait 89 (17 cubes rouges dans GreyRock, 152 dans Grass), et `fumee_appli` le
## refusait, à juste titre : un exemple livré ne doit pas en montrer.
##
## LANCEMENT (l'appli FERMÉE sur ce projet — elle le réécrirait en sortant) :
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/reparer_diagonales_exemple.gd [-- --ecrire]
## Sans `--ecrire`, il mesure seulement. Avec, il garde l'original en `<projet>.avant_diagonales` (jamais écrasé).
##
## LA RÈGLE : celle du bouton « Fix diagonal contacts », mode COMBLER (`FS.reparer_les_diagonales`), sur l'UNION des
## couches VISIBLES (c'est l'union que le peintre lit) — on n'y retire rien, l'artiste n'a rien perdu. Une case ajoutée va
## à la couche qui possède le plus de ses six voisines (à égalité : la plus prioritaire, le haut de la liste) ; jamais
## dans une couche cachée. Puis on recompte, par `MB.contacts_par_arete`, hors de la règle de réparation.

const Projet := preload("res://app/projet.gd")
const FS := preload("res://addons/marchingblocks_core/formes_speciales.gd")
const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const DEV := preload("res://DEV_TOOLS/dev_exemple.gd")

const VOISINS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1),
	Vector3i(0, 0, -1)]


func _initialize() -> void:
	var ecrire := OS.get_cmdline_user_args().has("--ecrire")
	var chemin: String = DEV.source()
	print("SOURCE : ", chemin)
	var erreurs: Array = []
	var p := Projet.depuis_texte(FileAccess.get_file_as_string(chemin), erreurs)
	if p.is_empty():
		print("⚠ projet illisible : ", erreurs)
		quit(1)
		return
	var couches: Array = p["couches"]
	var union := {}
	var rang := {}
	var figees := {}
	for i in couches.size():
		var c: Dictionary = couches[i]
		for k in c["cases"]:
			if not c["visible"]:
				figees[k] = true
				continue
			if not union.has(k):
				union[k] = true
				rang[k] = i
	print("union visible : %d cases ; contacts par arête : %d" % [union.size(), MB.contacts_par_arete(union)])
	var r: Dictionary = FS.reparer_les_diagonales(union, false, {}, figees)
	var poser: Dictionary = r["poser"]
	print("à combler : %d case(s) ; restants (cases d'une couche cachée) : %d" % [poser.size(), int(r["restantes"])])
	# Chaque case ajoutée à la couche de ses voisines — dans l'ordre (y, z, x) pour qu'une case posée compte pour la suivante.
	var cles: Array = poser.keys()
	cles.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return [a.y, a.z, a.x] < [b.y, b.z, b.x])
	var par_couche := {}
	for k: Vector3i in cles:
		var votes := {}
		for d in VOISINS:
			if rang.has(k + d):
				votes[rang[k + d]] = int(votes.get(rang[k + d], 0)) + 1
		var meilleure := -1
		for i in votes:
			if meilleure < 0 or votes[i] > votes[meilleure] or (votes[i] == votes[meilleure] and i < meilleure):
				meilleure = i
		if meilleure < 0:
			meilleure = int(p["active"])
		rang[k] = meilleure
		union[k] = true
		(couches[meilleure]["cases"] as Dictionary)[k] = true
		par_couche[couches[meilleure]["nom"]] = int(par_couche.get(couches[meilleure]["nom"], 0)) + 1
	var apres := MB.contacts_par_arete(union)
	print("ajoutées : %s ; contacts par arête après : %d" % [par_couche, apres])
	if apres != 0:
		print("⚠ il en reste : rien n'est écrit.")
		quit(1)
		return
	if not ecrire:
		print("(mesure seule — `--ecrire` pour écrire)")
		quit(0)
		return
	var garde := chemin + ".avant_diagonales"
	if not FileAccess.file_exists(garde):
		DirAccess.copy_absolute(chemin, garde)
	print("original gardé : ", garde)
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string(Projet.vers_texte(couches, p["active"], p["eaux"], p["travaux"]))
	f.close()
	# Relu sur le disque, compté à part.
	var relu := Projet.depuis_texte(FileAccess.get_file_as_string(chemin), erreurs)
	var u2 := {}
	for c in relu["couches"]:
		if c["visible"]:
			for k in c["cases"]:
				u2[k] = true
	print("RELU : %d cases visibles, %d contacts par arête" % [u2.size(), MB.contacts_par_arete(u2)])
	quit(0)
