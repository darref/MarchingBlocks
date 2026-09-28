extends SceneTree
##
## SONDE — où un GridMap pose-t-il réellement ses cases ?
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_gridmap_centrage.gd
##
## ⚠ POURQUOI, ET C'EST UN DÉCALAGE QUI NE SE VOIT PAS SUR UN SOL PLAT. Le greffon pose ses pièces sur
## les SOMMETS du réseau, pas sur les cases : une pièce est centrée sur le coin commun à huit cellules.
## Le rendu vit donc sur une grille décalée d'une demi-case. En modèle 2D, ce décalage valait
## `(-0,5 ; 0 ; -0,5)` — le y à zéro parce que le modèle n'était dual qu'en plan. En modèle ORIENTÉ, il
## doit valoir `-0,5` **sur les trois axes**.
##
## ⚠ MAIS ENCORE FAUT-IL SAVOIR OÙ GODOT POSE SES CASES. `GridMap` expose `cell_center_x`,
## `cell_center_y` et `cell_center_z`, et leurs défauts ne sont pas les mêmes sur les trois axes. Poser
## le décalage de mémoire, c'est décaler tout le rendu d'une demi-case en hauteur : invisible sur un sol
## plat, catastrophique sur une falaise — et aucune erreur ne le dirait.
##
## Elle ne modifie rien. Elle mesure et elle imprime.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")


func _initialize() -> void:
	print("=== SONDE — le centrage des cases d'un GridMap ===\n")

	var grille := GridMap.new()
	print("défauts : cell_center_x = %s   cell_center_y = %s   cell_center_z = %s"
		% [str(grille.cell_center_x), str(grille.cell_center_y), str(grille.cell_center_z)])

	for taille in [1.0, 2.0]:
		grille.cell_size = Vector3.ONE * taille
		print("\n── cell_size = %.1f ──" % taille)
		for c in [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 1),
				Vector3i(-1, -1, -1)]:
			print("   map_to_local%s = %s" % [str(c), str(grille.map_to_local(c))])

	# ⚠ CE QUI NOUS INTÉRESSE VRAIMENT : l'écart entre le centre de la case (0,0,0) et l'origine. C'est
	# lui qui dit de combien la grille de RENDU doit être décalée pour que ses pièces tombent sur les
	# coins des cases peintes, et non sur leurs centres.
	grille.cell_size = Vector3.ONE
	var centre: Vector3 = grille.map_to_local(Vector3i.ZERO)
	print("\n── CE QU'IL FAUT EN CONCLURE ──")
	print("   centre de la case (0,0,0), cell_size 1 : %s" % str(centre))
	print("   une case occupe donc [%s ; %s]"
		% [str(centre - Vector3.ONE * 0.5), str(centre + Vector3.ONE * 0.5)])

	# Le sommet que lit `MB.bits(pleines, v)` est le coin commun aux huit cellules v … v+(1,1,1).
	# En coordonnées du monde, ce coin est le centre du bloc 2×2×2, donc le centre de la case (0,0,0)
	# décalé d'une DEMI-CASE dans chaque sens positif.
	var sommet_monde: Vector3 = centre + Vector3.ONE * 0.5
	print("   le sommet lu par bits(p, (0,0,0)) est en %s" % str(sommet_monde))
	print("   → la grille de RENDU doit être décalée de %s par rapport à la grille des CASES"
		% str(sommet_monde - centre))

	# Contrôle : les huit cellules que ce sommet lit doivent l'entourer, chacune à une demi-case.
	print("\n── CONTRÔLE : les huit cellules lues entourent-elles bien ce point ? ──")
	var loin := 0
	for t in 8:
		var cellule: Vector3i = MB.COINS[t]
		var ecart: Vector3 = grille.map_to_local(cellule) - sommet_monde
		var ok: bool = absf(absf(ecart.x) - 0.5) < 0.0001 \
			and absf(absf(ecart.y) - 0.5) < 0.0001 \
			and absf(absf(ecart.z) - 0.5) < 0.0001
		if not ok:
			loin += 1
		print("   bit %d, cellule %s : écart %s %s" % [t, str(cellule), str(ecart), "" if ok else "⚠"])
	print("   %s" % ("les huit sont à une demi-case : le sommet est bien leur coin commun" if loin == 0
		else "⚠ %d cellule(s) ne sont PAS à une demi-case — le décalage ci-dessus est faux" % loin))

	grille.free()
	quit(0 if loin == 0 else 1)
