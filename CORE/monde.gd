extends RefCounted
## LE MONDE D'UNE ÉNIGME — son état, et la seule porte pour le changer.
##
## ⚠ UNE SEULE AUTORITÉ SUR LES RÈGLES (charte §6). Le client affiche `faisceaux` et `actifs`, il ne
## les recalcule jamais : une seconde lecture des règles pour animer divergerait au premier objet
## ajouté au catalogue.
##
## Deux sortes d'état, et la frontière ne se négocie pas :
##   • STOCKÉ — les grilles, les objets et leurs propriétés. C'est ce qu'on sauvegarde ;
##   • DÉRIVÉ — `actifs` et `faisceaux`, recalculés par `resoudre()` depuis le stocké. Jamais
##     sauvegardés : un état dérivé qu'on sauvegarde est un état qui finit par mentir.
##
## Plusieurs grilles dans un même monde : la surface et chaque grotte en sont une, et ce qui les
## relie est un objet ENTREE. Un faisceau qui change de vue ne change donc pas de monde — il n'y a
## rien à synchroniser entre deux vues, puisqu'elles lisent le même état.
##
## ⚠ Pas de `class_name` dans CORE/ : les tests tournent en `--script`, avant que l'éditeur ait indexé
## les classes globales. On `preload`, comme dans River Stones.

const Catalogue := preload("res://CORE/catalogue.gd")
const Resolution := preload("res://CORE/resolution.gd")

## id -> {"largeur": int, "hauteur": int, "murs": PackedByteArray}
var grilles: Dictionary = {}
## id -> {"type": String, "grille": int, "case": Vector2i, "destructible": bool, ...props du type}
var objets: Dictionary = {}

# ── dérivé : recalculé par resoudre(), jamais sauvegardé ──
var actifs: Dictionary = {}
var faisceaux: Array = []

var _index: Dictionary = {}  # Vector3i(grille, x, y) -> id
var _prochain_id: int = 1


# ── grilles ─────────────────────────────────────────────────────────────────────────────────────────

func ajouter_grille(id: int, largeur: int, hauteur: int) -> void:
	if grilles.has(id):
		push_error("Monde : la grille %d existe déjà" % id)
		return
	var murs := PackedByteArray()
	murs.resize(largeur * hauteur)
	murs.fill(0)
	grilles[id] = {"largeur": largeur, "hauteur": hauteur, "murs": murs}


func dans_grille(grille: int, pos: Vector2i) -> bool:
	if not grilles.has(grille):
		return false
	var g: Dictionary = grilles[grille]
	return pos.x >= 0 and pos.y >= 0 and pos.x < g["largeur"] and pos.y < g["hauteur"]


## Hors de la grille compte comme un mur : on peut interroger n'importe quelle case sans garde.
func est_mur(grille: int, pos: Vector2i) -> bool:
	if not dans_grille(grille, pos):
		return true
	var g: Dictionary = grilles[grille]
	var murs: PackedByteArray = g["murs"]
	return murs[pos.y * g["largeur"] + pos.x] != 0


func poser_mur(grille: int, pos: Vector2i) -> void:
	if not dans_grille(grille, pos) or objet_en(grille, pos) != -1:
		push_error("Monde : impossible de murer %s dans la grille %d" % [pos, grille])
		return
	var g: Dictionary = grilles[grille]
	var murs: PackedByteArray = g["murs"]
	murs[pos.y * g["largeur"] + pos.x] = 1
	g["murs"] = murs  # ⚠ un Packed*Array se copie à l'écriture : sans cette ligne, le mur n'existe pas


# ── objets ──────────────────────────────────────────────────────────────────────────────────────────

## Pose un objet du catalogue. Rend son id, ou -1 en le disant. ⚠ Une propriété mal orthographiée est
## REFUSÉE : sinon elle serait posée, jamais lue, et l'objet garderait sa valeur par défaut en silence.
func poser(type: String, grille: int, pos: Vector2i, props: Dictionary = {}) -> int:
	if not Catalogue.TYPES.has(type):
		push_error("Monde : type inconnu « %s »" % type)
		return -1
	if not dans_grille(grille, pos) or est_mur(grille, pos) or objet_en(grille, pos) != -1:
		push_error("Monde : la case %s de la grille %d n'est pas libre pour %s" % [pos, grille, type])
		return -1
	var defauts: Dictionary = Catalogue.TYPES[type].get("props", {})
	for cle in props:
		if cle != "destructible" and not defauts.has(cle):
			push_error("Monde : « %s » n'est pas une propriété de %s" % [cle, type])
			return -1
	var id := _prochain_id
	_prochain_id += 1
	objets[id] = _nouvel_objet(type, grille, pos, props)
	_index[Vector3i(grille, pos.x, pos.y)] = id
	return id


func objet_en(grille: int, pos: Vector2i) -> int:
	return _index.get(Vector3i(grille, pos.x, pos.y), -1)


func retirer(id: int) -> void:
	if not objets.has(id):
		return
	var objet: Dictionary = objets[id]
	var pos: Vector2i = objet["case"]
	_index.erase(Vector3i(objet["grille"], pos.x, pos.y))
	objets.erase(id)


## Change la nature d'un objet sans changer son identité : ce qui dépendait de lui en dépend encore.
func transformer(id: int, type: String) -> void:
	var ancien: Dictionary = objets[id]
	objets[id] = _nouvel_objet(type, ancien["grille"], ancien["case"], {})


## Le geste du joueur sur un miroir, en crans de 22,5°. Le premier pouvoir tourne de deux crans à la
## fois ; c'est au jeu de savoir lequel le joueur possède, pas au monde.
func tourner(id: int, crans: int) -> void:
	if not objets.has(id) or Catalogue.TYPES[objets[id]["type"]]["optique"] != "miroir":
		push_error("Monde : l'objet %d n'est pas un miroir" % id)
		return
	objets[id]["orientation"] = posmod(objets[id]["orientation"] + crans, 8)


func resoudre() -> Array:
	return Resolution.resoudre(self)


## Les fautes d'un montage que le catalogue ne peut pas voir, parce qu'elles dépendent des AUTRES
## objets. À appeler au chargement d'une énigme. Vide si le montage est sain.
func valider() -> Array:
	var erreurs: Array = []
	var ids: Array = objets.keys()
	ids.sort()
	for id in ids:
		var objet: Dictionary = objets[id]
		var nom: String = objet["type"]
		var t: Dictionary = Catalogue.TYPES[nom]
		if t.get("depend", false):
			var liste: Array = objet["depend_de"]
			if liste.is_empty():
				erreurs.append("%s %d : liste de dépendances vide — il ne serait jamais actif" % [nom, id])
			if not objet["mode"] in ["tous", "un"]:
				erreurs.append("%s %d : mode inconnu « %s »" % [nom, id, objet["mode"]])
			for autre in liste:
				if not objets.has(autre):
					erreurs.append("%s %d : dépend de %s, qui n'existe pas" % [nom, id, str(autre)])
				elif Catalogue.TYPES[objets[autre]["type"]].get("depend", false):
					erreurs.append("%s %d : dépend d'un autre dépendant (%d) — la dépendance est toujours directe" % [nom, id, autre])
				elif not Catalogue.peut_etre_actif(objets[autre]["type"]):
					erreurs.append("%s %d : dépend de %d, qui ne peut jamais être actif" % [nom, id, autre])
		if t["optique"] == "portail":
			var vers_grille: int = objet["vers_grille"]
			var vers: Vector2i = objet["vers_case"]
			if not dans_grille(vers_grille, vers) or est_mur(vers_grille, vers):
				erreurs.append("%s %d : bouche d'arrivée hors grille ou dans un mur" % [nom, id])
			elif objet_en(vers_grille, vers) != -1:
				erreurs.append("%s %d : bouche d'arrivée occupée — rien de ce qui y est ne serait traversé" % [nom, id])
	return erreurs


func copie():
	var m = get_script().new()
	m.grilles = grilles.duplicate(true)
	m.objets = objets.duplicate(true)
	m.actifs = actifs.duplicate()
	m.faisceaux = faisceaux.duplicate(true)
	m._index = _index.duplicate()
	m._prochain_id = _prochain_id
	return m


## Empreinte de l'état STOCKÉ : deux mondes d'empreinte égale se résolvent à l'identique.
func empreinte() -> int:
	var morceaux: Array = []
	var gids: Array = grilles.keys()
	gids.sort()
	for g in gids:
		morceaux.append([g, grilles[g]])
	var ids: Array = objets.keys()
	ids.sort()
	for id in ids:
		morceaux.append([id, objets[id]])
	return var_to_str(morceaux).hash()


func _nouvel_objet(type: String, grille: int, pos: Vector2i, props: Dictionary) -> Dictionary:
	var t: Dictionary = Catalogue.TYPES[type]
	var objet := {"type": type, "grille": grille, "case": pos, "destructible": t.get("destructible", false)}
	var defauts: Dictionary = t.get("props", {})
	for cle in defauts:
		objet[cle] = defauts[cle].duplicate(true) if defauts[cle] is Array else defauts[cle]
	for cle in props:
		objet[cle] = props[cle]
	return objet
