@tool
extends RefCounted
## LES OUTILS DE PEINTURE — viser, choisir les cases d'un pinceau, et dire ce qu'un geste change.
##
## **DÉCIDÉ (Jordan, 27 septembre 2026)** — le plan de la barre d'outils (charte §5) : deux VISÉES
## (grille, sculpture), les mêmes OUTILS (ajouter, creuser, sélectionner), un pinceau à taille et forme.
## La visée ne décide que de la façon de trouver le point ; l'outil, de ce qu'on en fait.
##
## ⚠ **ICI VIT LA RÈGLE, ET RIEN QUE LA RÈGLE.** Comme `etages.gd` : des fonctions pures qui lisent des
## cases et rendent `{poser, effacer}`. Aucun nœud, aucune annulation — chaque appelant applique avec
## SON historique. C'est ce qui les rend gardables en headless (`DEV_TOOLS/test_outils.gd`), et
## partageables avec le greffon, dont la sélection maison est encore OUVERTE (charte §5).

const FACES := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

const FORMES := ["sphere", "cube", "disque"]


## LE RAYON CONTRE LA MATIÈRE — un parcours case par case (Amanatides & Woo).
##
## `occupe(c: Vector3i) -> bool` dit si une case est pleine. Rend {"touche": bool, "case": Vector3i,
## "normale": Vector3i} — la normale est celle de la FACE par laquelle le rayon est entré.
##
## ⚠ **ON VISE L'OCCUPATION, PAS LE RENDU** : le rendu est aminci, sculpté, et déborde de sa case ; un
## relief peut appartenir au sommet voisin. L'occupation est la seule vérité (charte §3).
## ⚠ **LA CASE DE DÉPART EST SAUTÉE** : une caméra entrée dans la matière toucherait sinon sa propre case,
## sans normale, à chaque clic.
## ⚠ `ignorer` — les cases que le rayon traverse comme du vide : ce qu'un coup d'ajout vient de poser.
## Sans ce verrou, glisser en ajoutant bâtit une tour vers la caméra au lieu d'une peau sur la surface.
static func rayon(occupe: Callable, origine: Vector3, sens: Vector3, portee: float,
		ignorer: Dictionary = {}) -> Dictionary:
	var rien := {"touche": false, "case": Vector3i.ZERO, "normale": Vector3i.ZERO}
	if sens.length_squared() < 1e-12:
		return rien
	sens = sens.normalized()
	var c := Vector3i(floori(origine.x), floori(origine.y), floori(origine.z))
	var pas := Vector3i.ZERO
	var t_max := Vector3(INF, INF, INF)
	var t_delta := Vector3(INF, INF, INF)
	for axe in 3:
		if absf(sens[axe]) < 1e-12:
			continue
		pas[axe] = 1 if sens[axe] > 0.0 else -1
		var bord: float = float(c[axe] + 1) if sens[axe] > 0.0 else float(c[axe])
		t_max[axe] = (bord - origine[axe]) / sens[axe]
		t_delta[axe] = absf(1.0 / sens[axe])
	while true:
		var axe := 0
		if t_max.y < t_max[axe]:
			axe = 1
		if t_max.z < t_max[axe]:
			axe = 2
		var t: float = t_max[axe]
		if t > portee:
			return rien
		c[axe] += pas[axe]
		t_max[axe] += t_delta[axe]
		if not ignorer.has(c) and occupe.call(c):
			var n := Vector3i.ZERO
			n[axe] = -pas[axe]
			return {"touche": true, "case": c, "normale": n}
	return rien


## Le point d'ANCRAGE du pinceau. `point` = {"touche", "case", "normale"} : en sculpture, ce que le
## rayon a touché ; sinon (grille, ou rayon perdu) la case du plan d'étage, `touche` à faux.
## ⚠ AJOUTER POSE CONTRE LA FACE VISÉE, les autres outils agissent SUR la case touchée.
static func ancre(outil: String, point: Dictionary) -> Vector3i:
	var c: Vector3i = point["case"]
	if outil == "ajouter" and point["touche"]:
		return c + (point["normale"] as Vector3i)
	return c


## Les cases d'un pinceau, triées. `taille` 1 = une case ; le rayon est `taille - 1`.
##   sphère — |d|² ≤ r² : 1, 7, 33… cases ;
##   cube   — tout le cube : 1, 27, 125… ;
##   disque — la sphère COUPÉE au plan perpendiculaire à la normale : le pinceau de façade, qui garnit
##            ou creuse une paroi sans l'épaissir. Sans normale (la grille), le plan est horizontal.
static func pinceau(ancre_: Vector3i, normale: Vector3i, taille: int, forme: String) -> Array[Vector3i]:
	var r: int = maxi(0, taille - 1)
	var n: Vector3i = normale if normale != Vector3i.ZERO else Vector3i.UP
	var cases: Array[Vector3i] = []
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			for z in range(-r, r + 1):
				var d := Vector3i(x, y, z)
				var dedans: bool
				match forme:
					"cube":
						dedans = true
					"disque":
						dedans = d.length_squared() <= r * r and d.x * n.x + d.y * n.y + d.z * n.z == 0
					_:
						dedans = d.length_squared() <= r * r
				if dedans:
					cases.append(ancre_ + d)
	cases.sort()
	return cases


## Ce qu'un outil CHANGE sur ces cases : ajouter ne pose que dans le vide, creuser n'efface que la
## matière. Sélectionner ne change rien aux cases — elle n'a pas d'entrée ici.
static func modification(outil: String, cibles: Array, occupe: Callable) -> Dictionary:
	var poser := {}
	var effacer := {}
	for c in cibles:
		var plein: bool = occupe.call(c)
		if outil == "ajouter" and not plein:
			poser[c] = true
		elif outil == "creuser" and plein:
			effacer[c] = true
	return {"poser": poser, "effacer": effacer}


## LES OPÉRATIONS SUR LA SÉLECTION. Rend {"poser", "effacer", "selection"} — la sélection d'APRÈS.
##   supprimer         — efface la matière sélectionnée ;
##   extruder_haut/bas — pose la couche d'à côté, et la sélection LA SUIT : on répète pour monter une
##                       paroi ;
##   grandir           — ajoute la matière qui touche la sélection par une face ;
##   retrecir          — (les greffons) ne garde que les cases pleines dont les six voisines sont sélectionnées ;
##   retrecir_bord     — (l'appli) retire le bord : les cases où la sélection s'arrête d'un côté et continue de l'autre ;
##   connexe           — toute la matière reliée à la sélection par des faces ;
##   remplir           — POSE de la matière dans chaque case sélectionnée qui est vide.
##
## ⚠ **UNE SÉLECTION EST UN ENSEMBLE DE CASES, PLEINES OU VIDES — ET CE COMMENTAIRE DISAIT L'INVERSE.**
## Il annonçait « la sélection rendue ne porte que de la MATIÈRE : une case vide ne sert à rien »,
## alors que `extruder_haut` posait déjà `apres[p]` sans regarder `occupees`. La phrase était une
## seconde description qui avait divergé de son code (charte §6) — et elle empêchait de concevoir
## `remplir`, qui n'a de sens que sur des cases VIDES.
## ⚠ Les opérations qui ont besoin de matière la filtrent à l'usage (`supprimer`, `copier`,
## `deplacer`, `grandir`, `connexe`) : une sélection de VOLUME ne leur enlève rien.
static func operer_selection(occupees: Dictionary, selection: Dictionary, quoi: String) -> Dictionary:
	var poser := {}
	var effacer := {}
	var apres := {}
	match quoi:
		"supprimer":
			for c in selection:
				if occupees.has(c):
					effacer[c] = true
		"extruder_haut", "extruder_bas":
			var pas := Vector3i.UP if quoi == "extruder_haut" else Vector3i.DOWN
			for c in selection:
				var p: Vector3i = c + pas
				if not occupees.has(p):
					poser[p] = true
				apres[p] = true
		"grandir":
			for c in selection:
				if occupees.has(c):
					apres[c] = true
				for f in FACES:
					if occupees.has(c + f):
						apres[c + f] = true
		"retrecir":
			# ⚠ LA RÈGLE D'AVANT, GARDÉE POUR LES GREFFONS (« les greffons attendent la fin du logiciel », §0) : ses cas
			# d'épreuve sont dans `tools_conformance.json`. L'appli emploie `retrecir_bord` ; les trois greffons la
			# prendront (liste des greffons à faire).
			for c in selection:
				if not occupees.has(c):
					continue
				var interieur := true
				for f in FACES:
					if not selection.has(c + f):
						interieur = false
						break
				if interieur:
					apres[c] = true
		"retrecir_bord":
			# ⚠ **LE BORD DANS LE SENS OÙ LA SÉLECTION S'ÉTEND (Jordan, 2 octobre 2026 : « shrink ne fonctionne pas,
			# il la supprime »)** : on ne gardait que les cases dont les SIX voisines étaient sélectionnées — or une
			# sélection est presque toujours mince (un Rect d'une case, une peau peinte au Select), chaque case y a
			# du non-sélectionné dessus ou dessous, et tout disparaissait ; les cases vides étaient jetées aussi. Une
			# case est du bord quand, sur un axe, la sélection continue d'un côté et s'arrête de l'autre : un
			# rectangle perd son pourtour, une ligne ses bouts, un cube sa peau ; une case seule reste.
			for c in selection:
				var bord := false
				for f in FACES:
					if selection.has(c - f) and not selection.has(c + f):
						bord = true
						break
				if not bord:
					apres[c] = true
		"remplir":
			# ⚠ **ON NE TOUCHE PAS À LA SÉLECTION** : remplir puis extruder puis remplir est le geste
			# qui monte une pièce, et il demande que la sélection reste où elle est.
			for c in selection:
				apres[c] = true
				if not occupees.has(c):
					poser[c] = true
		"connexe":
			var file: Array = []
			for c in selection:
				if occupees.has(c) and not apres.has(c):
					apres[c] = true
					file.append(c)
			while not file.is_empty():
				var c: Vector3i = file.pop_back()
				for f in FACES:
					var v: Vector3i = c + f
					if occupees.has(v) and not apres.has(v):
						apres[v] = true
						file.append(v)
	return {"poser": poser, "effacer": effacer, "selection": apres}


## LE VOLUME D'UNE BOÎTE — TOUTES les cases entre deux coins, bornes comprises, pleines ou vides.
##
## ⚠ **C'EST CE QUI DISTINGUE UNE BOÎTE D'UN PINCEAU DE SÉLECTION**, et ce qui rend `remplir` possible :
## on désigne un VOLUME à bâtir, pas une matière à reprendre. `dans_la_boite` (qui ne rend que la
## matière) reste pour qui veut l'autre question.
##
## `creux` — ne garde que la PEAU du pavé : la salle creuse de Jordan. ⚠ Une boîte de moins de trois
## cases d'épaisseur sur un axe n'a pas d'intérieur : elle est alors pleine, et c'est juste — vider ce
## qui n'a pas de dedans rendrait une boîte VIDE, donc un geste sans effet que rien n'expliquerait.
##
## ⚠ **ON BORNE LE VOLUME**, parce qu'ici on parcourt la BOÎTE et non la matière : deux coins éloignés
## par accident (un rayon perdu à l'horizon) demanderaient des millions de cases et gèleraient l'écran.
## Au-delà, on rend vide plutôt que de ramer — l'appelant le DIT.
const VOLUME_MAXI := 262144


static func volume_de_la_boite(a: Vector3i, b: Vector3i, creux := false) -> Dictionary:
	var bas := Vector3i(mini(a.x, b.x), mini(a.y, b.y), mini(a.z, b.z))
	var haut := Vector3i(maxi(a.x, b.x), maxi(a.y, b.y), maxi(a.z, b.z))
	var etendue: Vector3i = haut - bas + Vector3i.ONE
	if etendue.x * etendue.y * etendue.z > VOLUME_MAXI:
		return {}
	var dedans := {}
	for x in range(bas.x, haut.x + 1):
		for y in range(bas.y, haut.y + 1):
			for z in range(bas.z, haut.z + 1):
				if creux \
						and x > bas.x and x < haut.x \
						and y > bas.y and y < haut.y \
						and z > bas.z and z < haut.z:
					continue
				dedans[Vector3i(x, y, z)] = true
	return dedans


## LA SÉLECTION EN BOÎTE — la matière entre deux coins, bornes comprises.
## ⚠ On parcourt la MATIÈRE, jamais le volume de la boîte : une boîte de 100³ ferait un million de
## tours pour quelques centaines de cases pleines.
static func dans_la_boite(occupees: Dictionary, a: Vector3i, b: Vector3i) -> Dictionary:
	var bas := Vector3i(mini(a.x, b.x), mini(a.y, b.y), mini(a.z, b.z))
	var haut := Vector3i(maxi(a.x, b.x), maxi(a.y, b.y), maxi(a.z, b.z))
	var dedans := {}
	for c in occupees:
		var p: Vector3i = c
		if p.x >= bas.x and p.x <= haut.x and p.y >= bas.y and p.y <= haut.y and p.z >= bas.z and p.z <= haut.z:
			dedans[p] = true
	return dedans


## DÉPLACER la matière sélectionnée d'un décalage. Rend {"poser", "effacer", "selection"}.
## ⚠ **UN DÉPLACEMENT QUI RECOUVRE SA SOURCE** (décaler de 1 une rangée de 3) ne doit ni effacer ce qu'il
## vient de poser ni reposer ce qui reste : on n'efface que la source QUI N'EST PAS destination, on ne
## pose que la destination QUI EST VIDE — ou qui ne l'est que par la source partie.
## ⚠ La matière d'accueil reste : déplacer sur une paroi FUSIONNE, jamais n'écrase.
static func deplacer(occupees: Dictionary, selection: Dictionary, decalage: Vector3i) -> Dictionary:
	var source := {}
	for c in selection:
		if occupees.has(c):
			source[c] = true
	var destination := {}
	for c in source:
		destination[(c as Vector3i) + decalage] = true
	var effacer := {}
	for c in source:
		if not destination.has(c):
			effacer[c] = true
	var poser := {}
	for c in destination:
		if not occupees.has(c) or effacer.has(c):
			poser[c] = true
	return {"poser": poser, "effacer": effacer, "selection": destination}


## COPIER — la matière sélectionnée, ramenée à son point d'ANCRAGE : le milieu de sa face du dessous.
## C'est là qu'elle se pose au collage, contre la face visée, comme une case qu'on ajoute.
## Rend un tableau trié de décalages relatifs.
static func copier(occupees: Dictionary, selection: Dictionary) -> Array[Vector3i]:
	var cases: Array[Vector3i] = []
	for c in selection:
		if occupees.has(c):
			cases.append(c)
	if cases.is_empty():
		return cases
	var bas: Vector3i = cases[0]
	var haut: Vector3i = cases[0]
	for c in cases:
		bas = Vector3i(mini(bas.x, c.x), mini(bas.y, c.y), mini(bas.z, c.z))
		haut = Vector3i(maxi(haut.x, c.x), maxi(haut.y, c.y), maxi(haut.z, c.z))
	# ⚠ `floori` sur la somme, pas une division entière : (−3 + 0) / 2 rendrait −1 en GDScript (vers
	# zéro) là où le milieu est −2 — le collage glisserait d'une case selon le signe des coordonnées.
	var ancrage := Vector3i(floori((bas.x + haut.x) / 2.0), bas.y, floori((bas.z + haut.z) / 2.0))
	var relatives: Array[Vector3i] = []
	for c in cases:
		relatives.append(c - ancrage)
	relatives.sort()
	return relatives


## COLLER un presse-papiers à une ancre. Ne pose que dans le vide ; la matière d'accueil reste.
static func coller(occupees: Dictionary, presse_papiers: Array, ancre_: Vector3i) -> Dictionary:
	var poser := {}
	var apres := {}
	for d in presse_papiers:
		var c: Vector3i = ancre_ + (d as Vector3i)
		apres[c] = true
		if not occupees.has(c):
			poser[c] = true
	return {"poser": poser, "effacer": {}, "selection": apres}
