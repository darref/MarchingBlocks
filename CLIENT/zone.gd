extends Node2D
## UNE ZONE PEINTE — la scène que l'on peint dans l'éditeur, et la seule porte entre elle et CORE.
##
## Structure attendue, et les noms comptent :
##   Zone (ce script)
##   ├── Surface
##   │   ├── Sol       (TileMapLayer) — le terrain ; ⚠ une case non peinte est un MUR
##   │   ├── Objets    (TileMapLayer) — les entrées, peintes au pinceau
##   │   └── Marqueurs (Node2D)       — les objets du catalogue, un nœud chacun
##   └── Grottes
##       ├── Grotte1 (CLIENT/grotte.gd) — départ + segments, avec sa Coupe et ses Marqueurs
##       └── Grotte2 …
##
## ⚠ DEUX FAÇONS DE POSER, ET ELLES NE SE CHEVAUCHENT PAS. Ce qui n'a AUCUNE propriété se peint au
## pinceau sur « Objets » (l'entrée : ce qu'elle vise est déduit, pas écrit). Ce qui porte des propriétés
## — l'orientation d'un miroir, la couleur d'un cristal, les dépendances d'une porte — est un MARQUEUR,
## parce qu'une tuile ne sait pas citer d'autres objets (voir CLIENT/marqueur.gd).
##
## ⚠ Ce nœud ne calcule AUCUNE règle : il rassemble les calques et laisse `CLIENT/niveau.gd` déduire le
## monde. Les grottes sont numérotées dans l'ordre de l'arbre — 1, 2, … — c'est-à-dire dans l'ordre que
## le peintre voit dans l'éditeur, et c'est le seul endroit où cet ordre compte.

const Niveau := preload("res://CLIENT/niveau.gd")


func grottes() -> Array:
	var liste: Array = []
	var noeud := get_node_or_null("Grottes")
	if noeud == null:
		return liste
	for enfant in noeud.get_children():
		if enfant.has_method("description"):
			liste.append(enfant.description())
	return liste


## Les marqueurs de la surface, décrits. ⚠ Un enfant sans `description()` est ignoré : on ne devine pas
## ce qu'un nœud étranger voudrait dire.
func marqueurs() -> Array:
	var liste: Array = []
	var noeud := get_node_or_null("Surface/Marqueurs")
	if noeud == null:
		return liste
	for enfant in noeud.get_children():
		if enfant.has_method("description"):
			liste.append(enfant.description())
	return liste


## Rend {"monde", "chemins", "entrees", "erreurs"} — voir `CLIENT/niveau.gd`. ⚠ `erreurs` non vide veut
## dire que la CARTE est fautive : à afficher, jamais à taire.
## LES CALQUES DE MASSIF, dans l'ordre de l'arbre — un par ÉTAGE.
##
## ⚠ LE MONDE EST FAIT DE MASSIFS (Jordan, 18 septembre). Ce ne sont pas des reliefs poses sur un fond :
## ce sont eux le terrain, et `Sol` n'est que la matiere peinte À L'INTÉRIEUR de leurs cadres, `Nappe`
## celle qui est ajourée par-dessus. D'où leur place en tête de l'arbre — donc dessinés DERRIÈRE — et
## d'où le fait qu'il en faut un par étage.
##
## ⚠ On les reconnaît par leur PRÉFIXE, pas par un chemin exact : « Massif00 », « Massif01 »… et l'ancien
## « Massifs » tout court, pour qu'une zone peinte avant les étages continue de se charger.
func massifs() -> Array:
	var liste: Array = []
	var surface := get_node_or_null("Surface")
	if surface == null:
		return liste
	for enfant in surface.get_children():
		if enfant is TileMapLayer and String(enfant.name).begins_with("Massif"):
			liste.append(enfant)
	return liste


func construire() -> Dictionary:
	return Niveau.construire(get_node_or_null("Surface/Sol"), get_node_or_null("Surface/Objets"), grottes(),
		get_node_or_null("Surface/Props"), marqueurs(), massifs())
