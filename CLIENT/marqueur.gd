@tool
extends Node2D
## UN OBJET DU CATALOGUE, POSÉ À LA MAIN — miroir, vitre, cristal, œil, porte antique.
##
## **DÉCIDÉ (Jordan, 16 septembre 2026)** — les objets du catalogue sont des NŒUDS, pas des tuiles.
##
## ⚠ LA RAISON N'EST PAS LE CONFORT, C'EST `depend_de`. Une `PORTE_ANTIQUE` dépend d'autres objets, et
## `CORE/monde.gd` attend une liste de leurs IDENTIFIANTS. Or ces identifiants sont distribués à la pose,
## à la file (`_prochain_id`) : ajoute un cristal ailleurs sur la carte, et tous les suivants glissent.
## Aucune tuile ne peut porter ça, et une liste de nombres écrite à la main serait fausse au premier
## objet ajouté, sans que rien ne le signale. On cite donc des NOMS, et `CLIENT/niveau.gd` les résout en
## identifiants une fois TOUT posé.
##
## ⚠ LE NOM DU NŒUD EST L'IDENTITÉ. Godot interdit déjà à deux frères de porter le même nom : l'unicité
## est donc gratuite, et lisible dans l'arbre de l'éditeur. Renommer un marqueur cité par un autre est
## signalé au chargement, jamais avalé.
##
## ⚠ LA CASE EST LA VÉRITÉ, LA POSITION EN EST DÉDUITE. On règle `case` ; le nœud se place tout seul au
## centre de cette case. Lire la case depuis la position en pixels donnerait deux descriptions d'un même
## lieu, et un objet à cheval sur deux cases au premier glissement de souris (charte §6).
##
## LES PROPRIÉTÉS vont dans `proprietes`, telles que le catalogue les nomme :
##   MIROIR         {"orientation": 0..7}                 — pas de 22,5°, c'est une LIGNE
##   VITRE          {"filtre": Couleur, "concentre": bool}
##   CRISTAL        {"couleur": Couleur, "direction": 0..7, "laser": bool}
##   OEIL_SACRE     {"couleur": Couleur}
##   RAI_DE_CIEL    {"direction": 0..7, "couleur": Couleur, "laser": bool}
##   PORTE_ANTIQUE  {"depend_de": ["NomA", "NomB"], "mode": "tous" | "un"}
## ⚠ Une propriété mal orthographiée est REFUSÉE à la pose par `CORE/monde.gd` — jamais posée en silence
## avec sa valeur par défaut. L'avertissement de configuration ci-dessous te le dit avant même de lancer.

const Catalogue := preload("res://CORE/catalogue.gd")
const Direction := preload("res://CORE/direction.gd")
const CASE := 32

@export var type: String = "":
	set(valeur):
		type = valeur
		update_configuration_warnings()
		queue_redraw()

@export var cellule := Vector2i.ZERO:
	set(valeur):
		cellule = valeur
		position = Vector2(cellule * CASE) + Vector2(CASE, CASE) * 0.5
		queue_redraw()

@export var proprietes: Dictionary = {}:
	set(valeur):
		proprietes = valeur
		update_configuration_warnings()
		queue_redraw()


## Ce que `CLIENT/niveau.gd` attend d'un marqueur. Le nom vient du nœud : c'est lui que `depend_de` cite.
func description() -> Dictionary:
	return {
		"nom": String(name),
		"type": type,
		"case": cellule,
		"proprietes": proprietes.duplicate(true),
	}


# ── ce que l'éditeur en montre ──────────────────────────────────────────────────────────────────────

## ⚠ Un marqueur invisible serait pire qu'une tuile : on ne saurait ni où il est, ni comment il est
## tourné. Le gizmo dessine sa case, son type, et l'ORIENTATION quand il en a une — un miroir mal tourné
## doit se voir en peignant, pas se découvrir en jouant.
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var demi := CASE * 0.5
	var cadre := Rect2(-demi, -demi, CASE, CASE)
	var teinte := Color(1, 1, 1, 0.9) if Catalogue.TYPES.has(type) else Color(1, 0.3, 0.3, 0.9)
	draw_rect(cadre, Color(teinte.r, teinte.g, teinte.b, 0.12), true)
	draw_rect(cadre, teinte, false, 1.0)

	if not Catalogue.TYPES.has(type):
		return
	var fiche: Dictionary = Catalogue.TYPES[type]
	# Le miroir est une LIGNE à deux faces : on la dessine à son angle, pas une flèche.
	if fiche.get("optique", "") == "miroir":
		var orientation: int = proprietes.get("orientation", 0)
		var angle := -deg_to_rad(22.5 * orientation)
		var bout := Vector2(cos(angle), sin(angle)) * demi * 0.9
		draw_line(-bout, bout, Color(0.6, 0.9, 1.0), 2.0)
	# Ce qui émet porte une flèche dans sa direction.
	if fiche.get("emission", "") != "":
		var direction: int = proprietes.get("direction", Direction.S)
		var vers := Vector2(Direction.VECTEURS[posmod(direction, 8)]).normalized() * demi * 0.8
		draw_line(Vector2.ZERO, vers, Color(1.0, 0.85, 0.4), 2.0)
		draw_circle(vers, 2.0, Color(1.0, 0.85, 0.4))


## ⚠ Les fautes se disent DANS L'ÉDITEUR, pas au lancement. Un triangle jaune sur le nœud coûte moins
## cher qu'une partie lancée pour apprendre qu'on a écrit « orientaton ».
func _get_configuration_warnings() -> PackedStringArray:
	var avertissements: PackedStringArray = []
	if type == "":
		avertissements.append("Ce marqueur n'a pas de type — voir CORE/catalogue.gd.")
		return avertissements
	if not Catalogue.TYPES.has(type):
		avertissements.append("Type inconnu « %s ». Types connus : %s" % [type, ", ".join(Catalogue.TYPES.keys())])
		return avertissements
	var defauts: Dictionary = Catalogue.TYPES[type].get("props", {})
	for cle in proprietes:
		if not defauts.has(cle):
			avertissements.append("« %s » n'est pas une propriété de %s. Attendues : %s"
				% [cle, type, ", ".join(defauts.keys()) if not defauts.is_empty() else "aucune"])
	if Catalogue.TYPES[type].get("depend", false):
		var cites = proprietes.get("depend_de", [])
		if not cites is Array:
			avertissements.append("« depend_de » doit être une liste de NOMS de marqueurs.")
		elif cites.is_empty():
			avertissements.append("Un %s sans « depend_de » ne serait jamais actif." % type)
	return avertissements
