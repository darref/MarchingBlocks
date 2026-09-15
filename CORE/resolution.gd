extends RefCounted
## RÉSOUDRE UN MONDE — et pourquoi ça se termine TOUJOURS, quel que soit le montage.
##
## Deux familles d'effets, et le catalogue ne sait écrire que celles-là :
##
##   • ce qui est MAINTENU — un œil actif tant qu'on l'éclaire, un cristal qui relaie, une porte
##     antique ouverte tant que ses yeux le sont. État DÉRIVÉ : jamais sauvegardé, recalculé DEPUIS
##     ZÉRO à chaque résolution ;
##   • ce qui est IRRÉVERSIBLE — la glace fond, le feu s'éteint, le laser détruit. État STOCKÉ, et il
##     ne revient pas.
##
## ⚠ LA RÈGLE QUI GARANTIT LA FIN : ce qui est maintenu ne peut qu'AJOUTER de la lumière (émettre,
## laisser passer) ; tout ce qui en RETIRE est irréversible. Le catalogue ne sait pas écrire l'inverse.
## Il en découle deux boucles, et chacune s'arrête pour une raison qu'on peut énoncer :
##
##   1. BOUCLE INTERNE — à état stocké fixé, on part de « rien n'est actif » et l'on recalcule. Les
##      actifs ne font que CROÎTRE d'une passe à l'autre, donc on atteint un point fixe en au plus
##      (nombre d'objets + 1) passes. C'est le PLUS PETIT point fixe, donc il est unique, et c'est ce
##      qui fait qu'un cristal qui ne s'éclaire que lui-même RESTE ÉTEINT : une boucle de lumière ne
##      s'allume pas toute seule, et un montage n'a pas de mémoire.
##   2. BOUCLE EXTERNE — sur les faisceaux du point fixe, on récolte les transformations, on les
##      applique EN BLOC, et l'on recommence. Chaque objet descend un graphe de transformations sans
##      cycle (vérifié par le catalogue) ou disparaît : ça s'arrête aussi.
##
## Aucun ordre de mise à jour à arbitrer. Les impacts sont récoltés, puis appliqués ensemble — comme
## les rencontres d'un même pas dans River Stones — et les rares conflits ont UNE règle écrite ici :
## la destruction l'emporte sur la transformation, quel que soit l'ordre des sources.

const Catalogue := preload("res://CORE/catalogue.gd")
const Couleur := preload("res://CORE/couleur.gd")
const Traceur := preload("res://CORE/traceur.gd")


## Résout `monde` sur place et rend les événements, dans l'ordre où le client doit les animer :
##   {"type": "transforme", "id", "de", "vers"}   {"type": "detruit", "id", "objet"}
##   {"type": "active", "id"}                      {"type": "desactive", "id"}
static func resoudre(monde) -> Array:
	var evenements: Array = []
	var avant: Dictionary = monde.actifs
	var actifs: Dictionary = {}
	var faisceaux: Array = []

	while true:
		var calcul := _point_fixe(monde)
		actifs = calcul["actifs"]
		faisceaux = calcul["faisceaux"]
		var destins := _destins(monde, faisceaux)
		if destins.is_empty():
			break
		var ids: Array = destins.keys()
		ids.sort()
		for id in ids:
			var de: String = monde.objets[id]["type"]
			var vers: String = destins[id]
			if vers == "":
				monde.retirer(id)
				evenements.append({"type": "detruit", "id": id, "objet": de})
			else:
				monde.transformer(id, vers)
				evenements.append({"type": "transforme", "id": id, "de": de, "vers": vers})

	var concernes: Array = avant.keys()
	for id in actifs:
		if not avant.has(id):
			concernes.append(id)
	concernes.sort()
	for id in concernes:
		if actifs.has(id) and not avant.has(id):
			evenements.append({"type": "active", "id": id})
		elif avant.has(id) and not actifs.has(id) and monde.objets.has(id):
			evenements.append({"type": "desactive", "id": id})

	monde.actifs = actifs
	monde.faisceaux = faisceaux
	return evenements


## Ce que fait un faisceau de `couleur` à `objet`, hors laser : {"active": true}, {"devient": TYPE}
## ou rien. La lecture de la couleur passe par `Couleur.convient()`, et par elle seule.
static func reaction(objet: Dictionary, couleur: int) -> Dictionary:
	var t: Dictionary = Catalogue.TYPES[objet["type"]]
	if t.get("active_sur_sa_couleur", false) and Couleur.convient(couleur, objet["couleur"]):
		return {"active": true}
	var reactions: Dictionary = t.get("reactions", {})
	for attendue in reactions:
		if Couleur.convient(couleur, attendue):
			return reactions[attendue]
	return {}


static func _point_fixe(monde) -> Dictionary:
	var actifs: Dictionary = {}
	var faisceaux: Array = []
	var passes := 0
	while true:
		passes += 1
		faisceaux = _tracer_tout(monde, actifs)
		var suivants := _actifs_sous(monde, faisceaux)
		if not _inclus(actifs, suivants):
			push_error("Résolution : un effet maintenu a RETIRÉ de la lumière — le catalogue a écrit ce qu'il ne doit pas savoir écrire")
		if suivants == actifs:
			break
		actifs = suivants
		if passes > monde.objets.size() + 1:
			push_error("Résolution : aucun point fixe en %d passes" % passes)
			break
	return {"actifs": actifs, "faisceaux": faisceaux}


static func _tracer_tout(monde, actifs: Dictionary) -> Array:
	var ids: Array = monde.objets.keys()
	ids.sort()
	var faisceaux: Array = []
	for id in ids:
		var emission: String = Catalogue.TYPES[monde.objets[id]["type"]].get("emission", "")
		if emission == "toujours" or (emission == "si_actif" and actifs.has(id)):
			faisceaux.append(Traceur.tracer(monde, id, actifs))
	return faisceaux


static func _actifs_sous(monde, faisceaux: Array) -> Dictionary:
	var allumes: Dictionary = {}
	for f in faisceaux:
		for impact in f["impacts"]:
			var id: int = impact["id"]
			var objet: Dictionary = monde.objets[id]
			if impact["laser"] and objet["destructible"]:
				continue  # il va être détruit : il ne s'allume pas avant
			if reaction(objet, impact["couleur"]).has("active"):
				allumes[id] = true

	# Les dépendants ne lisent que des activables allumés par la LUMIÈRE (charte : la dépendance est
	# toujours directe, et `Monde.valider()` le garde) — donc une seule passe, dans n'importe quel ordre.
	var ids: Array = monde.objets.keys()
	ids.sort()
	for id in ids:
		var objet: Dictionary = monde.objets[id]
		if Catalogue.TYPES[objet["type"]].get("depend", false) and _condition(objet, allumes):
			allumes[id] = true
	return allumes


static func _condition(objet: Dictionary, allumes: Dictionary) -> bool:
	var liste: Array = objet["depend_de"]
	if liste.is_empty():
		return false
	if objet["mode"] == "un":
		for autre in liste:
			if allumes.has(autre):
				return true
		return false
	for autre in liste:
		if not allumes.has(autre):
			return false
	return true


static func _destins(monde, faisceaux: Array) -> Dictionary:
	var destins: Dictionary = {}
	for f in faisceaux:
		for impact in f["impacts"]:
			var id: int = impact["id"]
			var objet: Dictionary = monde.objets[id]
			if impact["laser"] and objet["destructible"]:
				destins[id] = ""  # ⚠ la destruction ÉCRASE une transformation déjà récoltée
			elif not destins.has(id):
				var r := reaction(objet, impact["couleur"])
				if r.has("devient"):
					destins[id] = r["devient"]
	return destins


static func _inclus(petit: Dictionary, grand: Dictionary) -> bool:
	for id in petit:
		if not grand.has(id):
			return false
	return true
