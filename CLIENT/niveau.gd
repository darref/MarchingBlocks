extends RefCounted
## LE NIVEAU PEINT — la carte est la VÉRITÉ, le monde de CORE en est DÉDUIT.
##
## **DÉCIDÉ (Jordan, 16 septembre 2026)** — on peint dans l'éditeur, et au chargement ce fichier
## construit les grilles et les objets de `CORE/monde.gd` à partir de ce qui est peint. Il n'y a donc
## jamais deux descriptions d'un même lieu : la seconde est CALCULÉE, jamais écrite à la main. Déplacer
## un mur, c'est le repeindre, et rien d'autre.
##
## CE QUE LA CARTE DOIT DIRE, ET OÙ
##   calque « sol »    — le terrain. Chaque tuile porte `mur` (bool) : ce qui arrête la lumière.
##                       ⚠ UNE CASE NON PEINTE EST UN MUR. Le vide est plein : on ne peut pas oublier
##                       de peindre le bord du monde, et une carte à trous ne laisse pas fuir la lumière.
##   calque « objets » — les objets SANS propriété, par la donnée `objet` (le nom du type, "" sinon).
##   les marqueurs     — les objets AVEC propriétés (CLIENT/marqueur.gd), un nœud chacun.
##   une grotte        — son CHEMIN (départ + segments droits, charte §2) et sa coupe peinte.
##
## ⚠ POURQUOI DEUX CANAUX. Une tuile ne porte qu'un dessin ; l'orientation d'un miroir, la couleur d'un
## cristal et surtout la liste `depend_de` d'une porte antique sont des PROPRIÉTÉS. Et `depend_de` cite
## d'autres objets par leurs identifiants, distribués à la pose : aucune tuile ne peut l'écrire, et une
## liste de nombres saisie à la main serait fausse au premier objet ajouté. Les marqueurs citent donc des
## NOMS, et ce fichier les résout en identifiants une fois tout posé.
##
## ⚠ UNE ENTRÉE NE DIT PAS OÙ ELLE MÈNE : ON LE DÉDUIT. On cherche sa case dans le chemin de chaque
## grotte — celle qui passe dessous est la sienne, et la colonne est l'indice dans la table. La bouche
## est la première case NON MUR de cette colonne, en descendant depuis le plafond : le peintre creuse
## un puits, et la lumière tombe où il l'a creusé. Peindre une entrée là où aucune grotte ne passe est
## une erreur signalée, jamais un lien à écrire une seconde fois.
##
## ⚠ Ce fichier lit des `TileMapLayer` mais n'est PAS un Node : on lui passe les calques, il rend un
## monde et une liste d'erreurs. C'est ce qui permet à `DEV_TOOLS/test_niveau.gd` de lui présenter des
## cartes bâties en code, sans scène ni écran.

const Monde := preload("res://CORE/monde.gd")
const Catalogue := preload("res://CORE/catalogue.gd")
const Direction := preload("res://CORE/direction.gd")

const SURFACE := 0

## L'ALTITUDE 1 — le dessus des plateaux, et c'est une GRILLE, pas une propriété de case.
##
## ⚠ POURQUOI UNE GRILLE. `CORE` sait déjà tenir plusieurs grilles reliées par des PORTAILS : c'est ce qui
## fait marcher les grottes. Un plateau est exactement ça — un lieu où l'on est ou l'on n'est pas, relié au
## sol par des passages nommés. Donc `CORE` n'apprend RIEN : ni altitude, ni troisième axe, ni ordre de
## mise à jour. Et la lumière fait gratuitement ce qu'il faut — un rayon au sol ne traverse pas un plateau,
## un rayon sur le plateau ne descend pas au sol.
##
## ⚠ L'identifiant est haut exprès : les grottes prennent 1, 2, … dans l'ordre de l'arbre, et se
## marcheraient dessus.
const PLATEAU := 1000


## Construit le monde d'un niveau peint.
##   sol, objets : les deux calques de la surface (`objets` peut être null)
##   grottes     : [{"depart": Vector2i, "segments": Array[Vector2i], "coupe": TileMapLayer,
##                   "objets": TileMapLayer}] — les grilles sont numérotées 1, 2, … dans cet ordre
## Rend {"monde", "chemins", "entrees", "erreurs"}. ⚠ `erreurs` non vide veut dire que la CARTE est
## fautive : on rend quand même ce qu'on a pu construire, pour que l'éditeur montre le reste.
static func construire(sol, objets, grottes: Array, props = null, marqueurs = null, massifs = null) -> Dictionary:
	var erreurs: Array = []
	var monde = Monde.new()

	# 1. Les chemins d'abord : ce sont eux qui donnent la largeur des grottes ET le sens des entrées.
	var chemins := {}
	var occupees := {}  # case de surface -> grotte qui passe dessous
	for i in grottes.size():
		var id := i + 1
		var trace := chemin(grottes[i]["depart"], grottes[i]["segments"], erreurs, id)
		chemins[id] = trace
		for colonne in trace.size():
			var c: Vector2i = trace[colonne]
			if occupees.has(c):
				erreurs.append("grotte %d : passe sous %s, déjà traversée par la grotte %d — une entrée y serait ambiguë" % [id, c, occupees[c]])
			else:
				occupees[c] = id

	# 2. La surface.
	var taille := _taille(sol, erreurs, "le sol de la surface")
	monde.ajouter_grille(SURFACE, taille.x, taille.y)
	_poser_murs(monde, SURFACE, sol, taille, props)

	# 2 bis. Les plateaux, s'il y en a. ⚠ MÊME RÈGLE QU'EN SURFACE : une case non peinte est un MUR. À
	# l'altitude 1, le vide n'est pas du sol, c'est du vide — on ne marche que là où un massif est peint.
	var plateaux := massifs != null and not (massifs.get_used_cells() as Array).is_empty()
	if plateaux:
		monde.ajouter_grille(PLATEAU, taille.x, taille.y)
		for y in taille.y:
			for x in taille.x:
				var pos := Vector2i(x, y)
				if massifs.get_cell_tile_data(pos) == null:
					monde.poser_mur(PLATEAU, pos)
		# ⚠ La PAROI d'un massif est un mur EN HAUT AUSSI : on ne marche pas sur la tranche d'une falaise.
		for pos in massifs.get_used_cells():
			var d = massifs.get_cell_tile_data(pos)
			if d != null and d.get_custom_data("mur") and not monde.est_mur(PLATEAU, pos):
				monde.poser_mur(PLATEAU, pos)

	# 3. Les grottes : la coupe doit faire exactement la longueur du chemin.
	for id in chemins:
		var coupe = grottes[id - 1]["coupe"]
		var mesure := _taille(coupe, erreurs, "la coupe de la grotte %d" % id)
		var attendue: int = chemins[id].size()
		if mesure.x != attendue:
			erreurs.append("grotte %d : la coupe fait %d colonnes, son chemin %d — la table est la vérité (charte §2)" % [id, mesure.x, attendue])
		monde.ajouter_grille(id, attendue, mesure.y)
		_poser_murs(monde, id, coupe, Vector2i(attendue, mesure.y), grottes[id - 1].get("props"))

	# 4. Les objets, une fois les grilles là.
	var entrees: Array = []
	var noms := {}          # nom de marqueur -> identifiant dans le monde
	var a_resoudre: Array = []  # [identifiant, nom, [noms cités]] — voir l'étape 5
	_poser_objets(monde, SURFACE, objets, chemins, entrees, erreurs)
	_poser_marqueurs(monde, SURFACE, marqueurs, chemins, entrees, noms, a_resoudre, erreurs)
	for id in chemins:
		_poser_objets(monde, id, grottes[id - 1].get("objets"), chemins, entrees, erreurs)
		_poser_marqueurs(monde, id, grottes[id - 1].get("marqueurs"), chemins, entrees, noms, a_resoudre, erreurs)

	# 4 bis. Les escaliers : ce qui relie les deux altitudes.
	var escaliers: Array = []
	if plateaux:
		_poser_escaliers(monde, massifs, escaliers, erreurs)

	# 5. Les dépendances, une fois TOUT posé : un marqueur peut dépendre d'un autre posé après lui.
	_resoudre_dependances(monde, noms, a_resoudre, erreurs)

	for erreur in monde.valider():
		erreurs.append("monde : " + erreur)
	return {"monde": monde, "chemins": chemins, "entrees": entrees, "escaliers": escaliers,
		"erreurs": erreurs}


## La table d'une grotte : la case de départ, puis un pas par case le long de chaque segment.
## ⚠ Les segments sont DROITS (charte §2, les diagonales restent OUVERTES) : un segment oblique est
## refusé ici plutôt que d'inventer une convention de longueur.
static func chemin(depart: Vector2i, segments: Array, erreurs: Array = [], id: int = 0) -> Array:
	var cases: Array = [depart]
	var courante := depart
	for segment in segments:
		var pas: Vector2i = Vector2i(segment).sign()
		if pas.x != 0 and pas.y != 0:
			erreurs.append("grotte %d : segment %s en diagonale — OUVERT (charte §2)" % [id, segment])
			return cases
		var reste: int = absi(segment.x) + absi(segment.y)
		for n in reste:
			courante += pas
			cases.append(courante)
	return cases


## La case de surface sous laquelle passe une colonne de grotte — c'est ce qui fait défiler la vue de
## dessus quand on marche dans la grotte (charte §2).
static func case_de_surface(chemins: Dictionary, grotte: int, colonne: float) -> Vector2:
	var table: Array = chemins[grotte]
	var c := colonne - 0.5
	var i := clampi(floori(c), 0, table.size() - 1)
	var j := mini(i + 1, table.size() - 1)
	return Vector2(table[i]).lerp(Vector2(table[j]), clampf(c - i, 0.0, 1.0)) + Vector2(0.5, 0.5)


# ── la lecture des calques ──────────────────────────────────────────────────────────────────────────

static func _taille(calque, erreurs: Array, quoi: String) -> Vector2i:
	if calque == null:
		erreurs.append("%s : calque manquant" % quoi)
		return Vector2i.ONE
	var rect: Rect2i = calque.get_used_rect()
	if rect.size == Vector2i.ZERO:
		erreurs.append("%s : rien n'est peint" % quoi)
		return Vector2i.ONE
	if rect.position.x < 0 or rect.position.y < 0:
		erreurs.append("%s : peint en coordonnées négatives %s — la carte commence à (0, 0)" % [quoi, rect.position])
	return Vector2i(maxi(rect.end.x, 1), maxi(rect.end.y, 1))


## ⚠ UN DÉCOR QUI BLOQUE AJOUTE UN MUR. Un arbre, un rocher posé par-dessus le terrain arrête les pieds ;
## il doit donc arrêter la lumière, et c'est la MÊME donnée `mur` qui le dit. Sans cette ligne, le calque
## des décors n'existerait que pour la physique, et on aurait deux mondes : celui qu'on traverse et celui
## que la lumière traverse.
static func _poser_murs(monde, grille: int, calque, taille: Vector2i, dessus = null) -> void:
	if calque == null:
		return
	for y in taille.y:
		for x in taille.x:
			var pos := Vector2i(x, y)
			var donnees = calque.get_cell_tile_data(pos)
			var mur: bool = donnees == null or donnees.get_custom_data("mur")
			if not mur and dessus != null:
				var par_dessus = dessus.get_cell_tile_data(pos)
				mur = par_dessus != null and par_dessus.get_custom_data("mur")
			if mur:
				monde.poser_mur(grille, pos)


static func _poser_objets(monde, grille: int, calque, chemins: Dictionary, entrees: Array, erreurs: Array) -> void:
	if calque == null:
		return
	var cellules: Array = calque.get_used_cells()
	cellules.sort()  # ⚠ l'ordre de pose ne doit jamais dépendre de l'ordre de peinture
	for pos in cellules:
		var donnees = calque.get_cell_tile_data(pos)
		var type: String = donnees.get_custom_data("objet") if donnees != null else ""
		if type == "":
			erreurs.append("grille %d, case %s : tuile posée sur le calque des objets sans type" % [grille, pos])
			continue
		if not Catalogue.TYPES.has(type):
			erreurs.append("grille %d, case %s : type inconnu « %s »" % [grille, pos, type])
			continue
		if type == "ENTREE":
			_poser_entree(monde, grille, pos, chemins, entrees, erreurs)
		elif monde.poser(type, grille, pos) == -1:
			erreurs.append("grille %d, case %s : %s n'a pas pu être posé (case occupée ou murée)" % [grille, pos, type])


## LES ESCALIERS — le seul passage entre le sol et le dessus d'un plateau.
##
## ⚠ UN ESCALIER EST RECONNU PAR SON NOM, jamais par sa position dans l'atlas : le jour où un autre lot
## remplacera celui-ci, seules les positions changeront (charte §6).
##
## ⚠ CE QU'ON DÉDUIT, ET LA RÈGLE TIENT EN UNE LIGNE : une case d'escalier dont le DESSUS est un plateau
## où l'on marche et le DESSOUS un sol où l'on marche est un passage. On y pose deux portails, un par
## sens. Le peintre ne déclare donc aucune liaison — il pose un escalier au bord de son plateau, et le
## lien s'en déduit, exactement comme une entrée déduit sa grotte du chemin qui passe dessous.
static func _poser_escaliers(monde, massifs, escaliers: Array, erreurs: Array) -> void:
	var cellules: Array = massifs.get_used_cells()
	cellules.sort()  # ⚠ l'ordre de pose ne doit jamais dépendre de l'ordre de peinture
	for pos in cellules:
		var donnees = massifs.get_cell_tile_data(pos)
		if donnees == null:
			continue
		var nom: String = donnees.get_custom_data("nom")
		if not ("escalier" in nom or "rampe" in nom):
			continue
		# ⚠ TYPES EXPLICITES : `pos` vient d'un Array nu, donc il est Variant et `:=` n'a rien à inférer.
		# Faute déjà consignée dans ce projet, et refaite — elle ne coûte qu'un refus de compilation,
		# ce qui est la bonne façon d'échouer.
		var haut: Vector2i = pos + Vector2i(0, -1)
		var bas: Vector2i = pos + Vector2i(0, 1)
		# ⚠ LE DESSOUS DOIT SORTIR DU PLATEAU, et c'est un test qui me l'a appris. Ma première règle
		# disait « le dessus est du plateau, le dessous est du sol praticable » — or le SOL EST
		# PRATICABLE PARTOUT, y compris sous un massif : cette condition ne discriminait rien, et tout
		# escalier peint au milieu d'un plateau fabriquait un passage vers nulle part. Ce qui relie
		# vraiment, c'est un escalier posé au BORD : son dessus est le plateau, son dessous n'en est plus.
		if monde.est_mur(PLATEAU, haut) or monde.est_mur(SURFACE, bas) or not monde.est_mur(PLATEAU, bas):
			continue  # cet escalier ne relie rien : ce n'est qu'un dessin, et ce n'est pas une faute
		var descente: int = monde.poser("ENTREE", PLATEAU, pos, {
			"vers_grille": SURFACE, "vers_case": bas, "vers_direction": Direction.S})
		var montee: int = monde.poser("ENTREE", SURFACE, pos, {
			"vers_grille": PLATEAU, "vers_case": haut, "vers_direction": Direction.N})
		if descente == -1 or montee == -1:
			erreurs.append("escalier « %s » en %s : la case n'est pas libre dans les deux altitudes" % [nom, pos])
			continue
		escaliers.append({"case": pos, "nom": nom, "vers_haut": haut, "vers_bas": bas})


## Les marqueurs d'une grille. ⚠ L'ORDRE DE POSE NE DÉPEND PAS DE L'ORDRE DE L'ARBRE : on trie par case,
## comme les tuiles. Les identifiants du monde sont distribués à la pose ; les faire dépendre de l'ordre
## où le peintre a créé ses nœuds rendrait deux cartes identiques différentes au premier glisser-déposer.
static func _poser_marqueurs(monde, grille: int, liste, chemins: Dictionary, entrees: Array,
		noms: Dictionary, a_resoudre: Array, erreurs: Array) -> void:
	if liste == null:
		return
	var tries: Array = (liste as Array).duplicate()
	tries.sort_custom(func(a, b):
		if a["case"].y != b["case"].y:
			return a["case"].y < b["case"].y
		return a["case"].x < b["case"].x)

	for m in tries:
		var nom: String = m["nom"]
		var type: String = m["type"]
		var pos: Vector2i = m["case"]
		if type == "":
			erreurs.append("marqueur « %s » (grille %d, case %s) : sans type — voir CORE/catalogue.gd" % [nom, grille, pos])
			continue
		if not Catalogue.TYPES.has(type):
			erreurs.append("marqueur « %s » (grille %d, case %s) : type inconnu « %s »" % [nom, grille, pos, type])
			continue
		if noms.has(nom):
			erreurs.append("marqueur « %s » : ce nom sert déjà — une dépendance ne saurait lequel désigner" % nom)
			continue

		if type == "ENTREE":
			_poser_entree(monde, grille, pos, chemins, entrees, erreurs)
			continue

		# ⚠ `depend_de` porte des NOMS, le monde attend des IDENTIFIANTS : on le VIDE avant de poser, et
		# l'étape 5 le remplit.
		#
		# ⚠ ET CE VIDAGE A L'AIR INUTILE — il ne l'est pas, et je me suis fait prendre. Sur une carte
		# saine, l'étape 5 écrase de toute façon : le retirer ne fait rougir aucun test. Mais sur une
		# valeur MAL FORMÉE (une chaîne au lieu d'une liste, ce que la peinture à la main produit), il n'y
		# a rien à écraser : `Monde.valider()` lit alors une chaîne là où il attend un tableau, et le
		# chargeur PLANTE au lieu de signaler. Un garde-fou qui semble mort peut n'être qu'un garde-fou
		# dont les tests ne voient jamais le cas — voir `test_depend_de_mal_forme()`.
		var props: Dictionary = (m["proprietes"] as Dictionary).duplicate(true)
		var cites: Array = []
		if props.has("depend_de"):
			var brut = props["depend_de"]
			if brut is Array:
				cites = brut
			else:
				erreurs.append("marqueur « %s » : « depend_de » doit être une liste de noms, pas %s"
					% [nom, type_string(typeof(brut))])
			props["depend_de"] = []

		var identifiant: int = monde.poser(type, grille, pos, props)
		if identifiant == -1:
			erreurs.append("marqueur « %s » (grille %d, case %s) : %s n'a pas pu être posé — case murée, occupée, hors grille, ou propriété inconnue" % [nom, grille, pos, type])
			continue
		noms[nom] = identifiant
		if not cites.is_empty():
			a_resoudre.append([identifiant, nom, cites])


## Les noms cités par `depend_de` deviennent des identifiants. ⚠ C'est ici, et nulle part ailleurs, que
## le peintre est protégé du décalage des identifiants : il écrit « OeilNord », jamais un nombre.
static func _resoudre_dependances(monde, noms: Dictionary, a_resoudre: Array, erreurs: Array) -> void:
	for entree in a_resoudre:
		var identifiant: int = entree[0]
		var nom: String = entree[1]
		var ids: Array = []
		for cite in entree[2]:
			var vise := str(cite)
			if not noms.has(vise):
				erreurs.append("marqueur « %s » : dépend de « %s », qui n'est le nom d'aucun marqueur" % [nom, vise])
				continue
			if noms[vise] == identifiant:
				erreurs.append("marqueur « %s » : dépend de lui-même" % nom)
				continue
			ids.append(noms[vise])
		monde.objets[identifiant]["depend_de"] = ids


static func _poser_entree(monde, grille: int, pos: Vector2i, chemins: Dictionary, entrees: Array, erreurs: Array) -> void:
	if grille != SURFACE:
		erreurs.append("case %s : une entrée se peint sur la surface, pas dans une grotte" % pos)
		return
	for id in chemins:
		var colonne: int = (chemins[id] as Array).find(pos)
		if colonne == -1:
			continue
		var bouche := _bouche(monde, id, colonne)
		if bouche == -1:
			erreurs.append("entrée %s : la colonne %d de la grotte %d n'a pas de puits — tout y est muré" % [pos, colonne, id])
			return
		var identifiant: int = monde.poser("ENTREE", SURFACE, pos, {
			"vers_grille": id, "vers_case": Vector2i(colonne, bouche), "vers_direction": Direction.S,
		})
		if identifiant == -1:
			erreurs.append("entrée %s : la case n'est pas libre" % pos)
			return
		entrees.append({"case": pos, "grotte": id, "colonne": colonne, "bouche": Vector2i(colonne, bouche)})
		return
	erreurs.append("entrée %s : aucune grotte ne passe sous cette case" % pos)


## La bouche : la première case NON murée de la colonne, en descendant depuis le plafond. Rend -1 si la
## colonne est pleine.
static func _bouche(monde, grille: int, colonne: int) -> int:
	var hauteur: int = monde.grilles[grille]["hauteur"]
	for y in hauteur:
		if not monde.est_mur(grille, Vector2i(colonne, y)):
			return y
	return -1
