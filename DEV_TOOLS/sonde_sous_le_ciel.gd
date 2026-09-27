extends SceneTree

## SONDE — `sous_le_ciel()` DIT-IL VRAI SUR UNE FALAISE ?
##
## ⚠ **LA QUESTION VIENT DE L'IMAGE, PAS D'UNE RELECTURE DE CODE (26 septembre 2026).** En peignant la
## légende par occlusion, une chose est apparue : sur un massif de six cases de haut, toute la paroi
## extérieure est déclarée SOUTERRAINE. Jordan : *« regarde `sous_le_ciel` alors. »*
##
## ── CE QUE LA FONCTION FAIT AUJOURD'HUI ─────────────────────────────────────────────────────────────
##
## Elle sonde les **huit** colonnes du voisinage à partir de `sommet.y + 2`, et rend faux dès qu'UNE
## seule porte de la roche. Sur une falaise, quatre de ces huit colonnes sont DANS le massif : elles
## portent forcément de la roche plus haut, puisque la falaise continue. **Le sommet est donc déclaré
## « pas sous le ciel » alors que le vide qu'il borde est à l'air libre.**
##
## ⚠ **ET CE N'EST PAS UN CAS TORDU : c'est le flanc de toute montagne.** Si la mesure le confirme, le
## pinceau pose des tuiles de GROTTE sur la face extérieure d'un massif, partout sauf à son sommet.
##
## ── LA RÈGLE PROPOSÉE, ET POURQUOI ELLE NE ROUVRE PAS LE DÉBAT DE L'OCCLUSION ───────────────────────
##
## On ne sonde que les colonnes dont la case, à l'étage de la pièce, est **VIDE** — celles que le vide
## occupe. Autrement dit : *« le vide que borde cette pièce voit-il le ciel ? »*
##
##   • paroi de falaise → les colonnes d'air n'ont rien au-dessus → **sous le ciel** ;
##   • paroi de grotte  → les colonnes d'air ont de la roche au-dessus → **pas sous le ciel**.
##
## ⚠ **ELLE RESTE UN OUI-OU-NON, ET C'EST CE QUI COMPTE.** La charte §2 a écarté l'occlusion du ciel
## parce qu'elle demande COMBIEN, donc un seuil, donc 11 % de dérive entre deux échelles. Cette
## règle-ci demande toujours « y a-t-il de la roche au-dessus », sans seuil : elle ne rouvre pas ce
## débat. Elle change seulement **de quelles colonnes** on parle.
##
## ⚠ **ON NE CHANGE RIEN : ON MESURE.** Cette fonction a déjà coûté quatre tours de recherche dans la
## mauvaise direction (charte §9), et elle décide à la fois de la récolte et de ce que le pinceau pose.
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_sous_le_ciel.gd

const MB := preload("res://addons/marching_blocks_plugin_godot/marching_blocks.gd")
const BM := preload("res://addons/marching_blocks_plugin_godot/blocs_maitres.gd")

const COTE := 10


func _initialize() -> void:
	print("=== sous_le_ciel() SUR UNE FALAISE ===\n")

	_examiner("UNE MESA de 6 cases de haut", _mesa(6))
	_examiner("LA MÊME, haute d'UNE case", _mesa(1))
	_examiner("UNE SALLE creusée dans la roche", _salle())
	_examiner("LE TÉMOIN LIVRÉ (bloc 0)", BM.cases(0))

	# ── LE CONTRÔLE QUI DOIT ROUGIR ─────────────────────────────────────────────────────────────────
	#
	# ⚠ **SANS LUI, « la règle proposée est meilleure » N'EST QU'UN AVIS.** Une règle plus permissive
	# rend forcément plus de sommets « sous le ciel » ; ça ne prouve pas qu'elle a raison. Ce qui le
	# prouve, c'est qu'elle reste FAUSSE là où elle doit l'être : sous un plafond de grotte, aucune
	# colonne d'air ne voit le ciel, et les deux règles doivent rendre faux.
	print("── LE CONTRÔLE : dans une salle fermée, les DEUX règles doivent dire NON ──")
	var salle: Dictionary = _salle()
	var plafond: int = MB.plafond_de(salle)
	var faux_a := 0
	var faux_b := 0
	var total := 0
	for v in _sommets_de_surface(salle):
		if not _dans_la_salle(v):
			continue
		total += 1
		if not MB.sous_le_ciel(salle, v, plafond):
			faux_a += 1
		if not _sous_le_ciel_propose(salle, v, plafond):
			faux_b += 1
	print("   %d sommet(s) dans la salle · règle actuelle : %d NON · règle proposée : %d NON"
		% [total, faux_a, faux_b])
	print("   %s\n" % ("✓ les deux refusent tout" if faux_a == total and faux_b == total
		else "⚠ l'une des deux laisse passer un sommet de salle fermée"))

	# ── CE QUE LA RÈGLE PROPOSÉE COÛTE À LA RÉCOLTE ─────────────────────────────────────────────────
	#
	# ⚠ **ELLE EST PLUS PERMISSIVE, DONC ELLE NE PEUT RIEN FAIRE PERDRE CÔTÉ EXTÉRIEUR — ET C'EST
	# EXACTEMENT POUR ÇA QU'IL FAUT REGARDER L'AUTRE CÔTÉ.** Tout sommet que la règle actuelle déclare
	# sous le ciel, la proposée le déclare aussi : elle ne sonde qu'un sous-ensemble des colonnes. Le
	# risque n'est donc pas de perdre des tuiles d'AIR LIBRE, il est d'en perdre d'INTÉRIEUR : un
	# sommet qui basculait dehors ne livre plus sa variante nue, et si c'était le seul, la classe
	# disparaît. Se contenter de compter les extérieures gagnées serait une mesure qui ne peut que
	# donner raison à ce qu'on propose.
	print("── CE QUE CHAQUE RÈGLE RÉCOLTE SUR LE TÉMOIN (convention (A), sommets intérieurs) ──")
	var cases: Dictionary = BM.cases(0)
	var a: Dictionary = _recolter(cases, false)
	var b: Dictionary = _recolter(cases, true)
	print("   règle ACTUELLE  : %d tuile(s)" % a.size())
	print("   règle PROPOSÉE  : %d tuile(s)" % b.size())
	var perdues: Array = []
	for nom in a:
		if not b.has(nom):
			perdues.append(nom)
	var gagnees: Array = []
	for nom in b:
		if not a.has(nom):
			gagnees.append(nom)
	perdues.sort()
	gagnees.sort()
	print("   PERDUES (%d) : %s" % [perdues.size(), ", ".join(PackedStringArray(perdues))])
	print("   gagnées (%d) : %s\n" % [gagnees.size(), ", ".join(PackedStringArray(gagnees))])

	print("⚠ Cette sonde compare deux règles ; elle ne change rien au greffon.")
	quit(0)


func _examiner(quoi: String, pleines: Dictionary) -> void:
	var plafond: int = MB.plafond_de(pleines)
	var actuelle := 0
	var proposee := 0
	var total := 0
	var classes_a := {}
	var classes_b := {}
	for v in _sommets_de_surface(pleines):
		total += 1
		var bits: int = MB.bits(pleines, v)
		var peut: bool = MB.exterieur_possible(bits)
		var nom: String = MB.classer(bits)["nom"]
		if peut and MB.sous_le_ciel(pleines, v, plafond):
			actuelle += 1
			classes_a[nom] = true
		if peut and _sous_le_ciel_propose(pleines, v, plafond):
			proposee += 1
			classes_b[nom] = true
	print("── %s ──" % quoi)
	print("   %d cases · %d sommet(s) portant une surface" % [pleines.size(), total])
	print("   sous le ciel — règle ACTUELLE  : %4d sommet(s), %d classe(s) extérieure(s)"
		% [actuelle, classes_a.size()])
	print("   sous le ciel — règle PROPOSÉE  : %4d sommet(s), %d classe(s) extérieure(s)"
		% [proposee, classes_b.size()])
	print("   (il y a %d classes extérieures possibles en tout)\n"
		% MB.classes_exterieures().size())


## LA RÈGLE PROPOSÉE : on ne sonde que les colonnes dont la case est VIDE à l'étage de la pièce.
##
## ⚠ **LE BALAYAGE COMMENCE TOUJOURS À `sommet.y + 2`**, et y toucher rouvrirait la faute que la charte
## §9 raconte : partir de `case.y + 1` fait coiffer chaque pièce par sa propre couche haute, et seules
## 5 des 22 classes extérieures restaient atteignables. Seule la LISTE des colonnes change.
func _sous_le_ciel_propose(pleines: Dictionary, sommet: Vector3i, plafond: int) -> bool:
	for t in 8:
		var base: Vector3i = sommet + MB.COINS[t]
		# ⚠ Une colonne PLEINE ne dit rien du ciel : c'est la matière de la pièce elle-même, et la
		# falaise qui la prolonge vers le haut n'empêche personne de voir le ciel depuis le vide d'à
		# côté. On ne sonde donc que ce que le VIDE occupe.
		if pleines.has(base):
			continue
		for y in range(sommet.y + 2, plafond + 1):
			if pleines.has(Vector3i(base.x, y, base.z)):
				return false
	return true


func _sommets_de_surface(pleines: Dictionary) -> Array:
	var sortie: Array = []
	for x in range(-1, COTE):
		for y in range(-1, COTE):
			for z in range(-1, COTE):
				var v := Vector3i(x, y, z)
				if MB.porte_une_surface(MB.bits(pleines, v)):
					sortie.append(v)
	return sortie


# ── LES FORMES D'ESSAI ──────────────────────────────────────────────────────────────────────────────

## Une mesa : un massif à sommet plat, haut de `hauteur` cases, entouré de vide.
func _mesa(hauteur: int) -> Dictionary:
	var p := {}
	for x in range(2, 8):
		for y in hauteur:
			for z in range(2, 8):
				p[Vector3i(x, y, z)] = true
	return p


## Une salle creusée dans un bloc plein — ses parois ne voient le ciel par aucun chemin.
func _salle() -> Dictionary:
	var p := {}
	for x in COTE:
		for y in 8:
			for z in COTE:
				p[Vector3i(x, y, z)] = true
	for x in range(3, 7):
		for y in range(2, 5):
			for z in range(3, 7):
				p.erase(Vector3i(x, y, z))
	return p


func _dans_la_salle(v: Vector3i) -> bool:
	return v.x >= 2 and v.x <= 6 and v.y >= 1 and v.y <= 4 and v.z >= 2 and v.z <= 6


## La récolte d'une occupation sous l'une ou l'autre règle — convention (A), sommets intérieurs.
##
## ⚠ **C'EST UNE SECONDE DESCRIPTION DE LA BOUCLE DU TRANCHEUR, ET JE LE DIS.** Le vrai trancheur
## appelle `MB.sous_le_ciel()` en dur ; comparer deux règles demande de pouvoir en changer, ce qu'il ne
## permet pas. La boucle est donc recopiée ici — pour une COMPARAISON, jamais pour une autorité. Si les
## deux devaient diverger, c'est celle du trancheur qui a raison.
func _recolter(pleines: Dictionary, propose: bool) -> Dictionary:
	var plafond: int = MB.plafond_de(pleines)
	var sortie := {}
	for x in BM.COTE - 1:
		for y in BM.COTE - 1:
			for z in BM.COTE - 1:
				var v := Vector3i(x, y, z)
				var bits: int = MB.bits(pleines, v)
				if not MB.porte_une_surface(bits):
					continue
				var dehors: bool = MB.exterieur_possible(bits) and (
					_sous_le_ciel_propose(pleines, v, plafond) if propose
					else MB.sous_le_ciel(pleines, v, plafond))
				sortie[MB.nom_en_contexte(MB.classer(bits)["nom"], dehors)] = true
	return sortie
