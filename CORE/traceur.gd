extends RefCounted
## LE TRAJET D'UN FAISCEAU — une fonction de l'état, jamais une simulation.
##
## Pas de photon qui avance d'une image à l'autre, pas d'ordre de mise à jour : on donne le monde et
## l'ensemble des objets actifs, on reçoit le trajet complet. Le client l'anime s'il veut ; il ne le
## recalcule jamais (charte §6).
##
## Ce qu'on rend :
##   pas      — chaque case traversée, avec la direction, la couleur et le laser À L'ENTRÉE de la case
##   impacts  — chaque objet rencontré : {id, couleur, laser}. C'est ce que lit la résolution
##   fin      — pourquoi le faisceau s'arrête (constantes ci-dessous)
##   boucle_depuis — sur une fin BOUCLE, l'indice du pas où la boucle commence.
##
## ⚠ UNE BOUCLE N'EST PAS UNE ERREUR, C'EST UNE INFORMATION. Ce qu'elle devient — un laser, un
## piège, rien — appartient à la trame de chaque énigme (charte §4). Le traceur ne tranche pas : il
## la SIGNALE, avec l'endroit où elle se referme, et la règle qui s'en servira n'aura rien à retrouver.

const Catalogue := preload("res://CORE/catalogue.gd")
const Couleur := preload("res://CORE/couleur.gd")
const Direction := preload("res://CORE/direction.gd")

const SORTIE := "SORTIE"      # quitte la grille
const MUR := "MUR"            # entre dans un mur
const COIN := "COIN"          # diagonale entre deux cases dont l'une est un mur
const OBSTACLE := "OBSTACLE"  # arrêté par un objet
const RASANT := "RASANT"      # arrive le long d'un miroir
const ABSORBE := "ABSORBE"    # une vitre n'a rien laissé passer
const BOUCLE := "BOUCLE"      # repasse dans un état déjà vu


static func tracer(monde, source_id: int, actifs: Dictionary) -> Dictionary:
	var source: Dictionary = monde.objets[source_id]
	var grille: int = source["grille"]
	var pos: Vector2i = source["case"]
	var direction: int = source["direction"]
	var couleur: int = source["couleur"]
	var laser: bool = source["laser"]

	var pas: Array = []
	var impacts: Array = []
	var vus := {}
	var fin := ""
	var boucle_depuis := -1

	while true:
		var v: Vector2i = Direction.VECTEURS[direction]
		var suivante := pos + v
		if not monde.dans_grille(grille, suivante):
			fin = SORTIE
			break
		# ⚠ PROPOSÉ : une diagonale ne se glisse pas entre deux coins si L'UN des deux est plein — ce
		# qu'on voit doit être vrai, et un trait qui frôle un coin de mur a l'air de le traverser.
		if Direction.diagonale(direction) and (monde.est_mur(grille, Vector2i(pos.x + v.x, pos.y)) \
				or monde.est_mur(grille, Vector2i(pos.x, pos.y + v.y))):
			fin = COIN
			break
		if monde.est_mur(grille, suivante):
			fin = MUR
			break
		pos = suivante

		var cle := _cle(grille, pos, direction, couleur, laser)
		if vus.has(cle):
			fin = BOUCLE
			boucle_depuis = vus[cle]
			break
		vus[cle] = pas.size()
		pas.append({"grille": grille, "case": pos, "direction": direction, "couleur": couleur, "laser": laser})

		var id: int = monde.objet_en(grille, pos)
		if id == -1:
			continue
		var objet: Dictionary = monde.objets[id]
		impacts.append({"id": id, "couleur": couleur, "laser": laser})

		match Catalogue.TYPES[objet["type"]]["optique"]:
			"miroir":
				if Direction.rasant(direction, objet["orientation"]):
					fin = RASANT
					break
				direction = Direction.reflechir(direction, objet["orientation"])
			"vitre":
				couleur = Couleur.filtrer(couleur, objet["filtre"])
				if couleur == Couleur.NOIR:
					fin = ABSORBE
					break
				if objet["concentre"]:
					laser = true
			"bloque":
				fin = OBSTACLE
				break
			"traverse_si_actif":
				if not actifs.has(id):
					fin = OBSTACLE
					break
			"portail":
				# La case d'arrivée est une BOUCHE : on y apparaît, on n'y traite rien, on repart. Sans
				# ça, deux entrées qui se font face se renverraient le faisceau à l'infini.
				grille = objet["vers_grille"]
				pos = objet["vers_case"]
				direction = objet["vers_direction"]
				var arrivee := _cle(grille, pos, direction, couleur, laser)
				if vus.has(arrivee):
					fin = BOUCLE
					boucle_depuis = vus[arrivee]
					break
				vus[arrivee] = pas.size()
				pas.append({"grille": grille, "case": pos, "direction": direction, "couleur": couleur, "laser": laser})

	return {"source": source_id, "pas": pas, "impacts": impacts, "fin": fin, "boucle_depuis": boucle_depuis}


static func _cle(grille: int, pos: Vector2i, direction: int, couleur: int, laser: bool) -> int:
	return ((((grille * 65536 + pos.x) * 65536 + pos.y) * 8 + direction) * 8 + couleur) * 2 + int(laser)
