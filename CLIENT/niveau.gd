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
##   calque « objets » — les objets du catalogue, par la donnée `objet` (le nom du type, "" sinon).
##   une grotte        — son CHEMIN (départ + segments droits, charte §2) et sa coupe peinte.
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


## Construit le monde d'un niveau peint.
##   sol, objets : les deux calques de la surface (`objets` peut être null)
##   grottes     : [{"depart": Vector2i, "segments": Array[Vector2i], "coupe": TileMapLayer,
##                   "objets": TileMapLayer}] — les grilles sont numérotées 1, 2, … dans cet ordre
## Rend {"monde", "chemins", "entrees", "erreurs"}. ⚠ `erreurs` non vide veut dire que la CARTE est
## fautive : on rend quand même ce qu'on a pu construire, pour que l'éditeur montre le reste.
static func construire(sol, objets, grottes: Array, props = null) -> Dictionary:
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
	_poser_objets(monde, SURFACE, objets, chemins, entrees, erreurs)
	for id in chemins:
		_poser_objets(monde, id, grottes[id - 1].get("objets"), chemins, entrees, erreurs)

	for erreur in monde.valider():
		erreurs.append("monde : " + erreur)
	return {"monde": monde, "chemins": chemins, "entrees": entrees, "erreurs": erreurs}


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
