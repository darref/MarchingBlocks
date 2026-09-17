extends RefCounted
## LA RÈGLE DE LA FALAISE, ÉCRITE UNE SEULE FOIS.
##
## ⚠ ELLE ÉTAIT DÉJÀ ÉCRITE DEUX FOIS, ET LES DEUX AVAIENT DÉJÀ DIVERGÉ. `faire_zone.gd` sautait une case
## si une marche s'y trouvait ; `deriver_falaises.gd` sautait aussi si du plateau s'y trouvait — la
## protection contre un massif posé juste sous un autre. Deux règles écrites à une heure d'intervalle,
## se croyant identiques, déjà différentes sur un cas limite. Ajouter un bouton en aurait fait une
## troisième. Cette version prend la plus défensive des deux.
##
## ⚠ ELLE CALCULE, ELLE NE POSE RIEN. C'est ce qui permet aux trois appelants de l'appliquer à leur
## façon : le générateur marque ses cases prises, la commande écrit directement, le bouton d'éditeur
## passe par l'historique d'annulation. Une règle, trois applications — jamais l'inverse.
##
## UNE FALAISE PEND SOUS LE BORD SUD D'UN PLATEAU. Elle ne se choisit pas par voisinage : elle se DÉDUIT
## du bord qu'elle prolonge, exactement comme la plage se déduit du lac (`_est_plage`). Better Terrain
## n'écrit jamais dans une case qu'on ne lui a pas donnée — peindre un plateau ne peut donc pas créer sa
## paroi, et c'est à ce calcul de le faire.

## Les rangées, de haut en bas. Le milieu se répète autant que la falaise est haute, le pied touche le sol.
## ⚠ Hauteur FIXE à deux, faute de quoi que ce soit dans la carte qui dise qu'un plateau est haut de trois.
const RANGEES := ["milieu", "pied"]


## Les poses à faire : [{case, nom}], triées, pour un résultat indépendant de l'ordre de peinture.
##   plateau : case -> nom de la famille (« massif_herbe », « massif_sable »…)
##   marches : case -> true, les escaliers et rampes posés à la main, qu'on ne recouvre JAMAIS
static func calculer(plateau: Dictionary, marches: Dictionary) -> Array:
	var poses: Array = []
	var cles: Array = plateau.keys()
	cles.sort()  # ⚠ deux cartes identiques doivent rendre la même falaise, quel que soit l'ordre de pose
	for c in cles:
		var pos: Vector2i = c
		if plateau.has(pos + Vector2i(0, 1)):
			continue  # il y a encore du plateau dessous : ce n'est pas un bord sud
		var famille: String = plateau[pos]
		# Un cap à gauche là où l'ouest n'est pas lui-même un bord sud, un cap à droite de même.
		var a_gauche: bool = plateau.has(pos + Vector2i(-1, 0)) and not plateau.has(pos + Vector2i(-1, 1))
		var a_droite: bool = plateau.has(pos + Vector2i(1, 0)) and not plateau.has(pos + Vector2i(1, 1))
		var role := "milieu_a" if _grain(pos) else "milieu_b"
		if not a_gauche:
			role = "gauche"
		elif not a_droite:
			role = "droite"
		for i in RANGEES.size():
			var ou: Vector2i = pos + Vector2i(0, 1 + i)
			# ⚠ On ne recouvre ni une marche ni un plateau : la paroi descend exactement là où l'escalier
			# se tient, et la murer boucherait le passage qu'on vient de construire.
			if marches.has(ou) or plateau.has(ou):
				continue
			poses.append({"case": ou, "nom": "%s_falaise_%s_%s" % [famille, role, RANGEES[i]]})
	return poses


## Le choix entre les deux milieux : une FONCTION de la case, jamais un tirage. Deux exécutions doivent
## rendre la même falaise — sinon relancer l'outil changerait la carte sans qu'on ait rien peint.
static func _grain(pos: Vector2i) -> bool:
	return absi((pos.x * 73856093) ^ (pos.y * 19349663)) % 2 == 0
