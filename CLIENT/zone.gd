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
func construire() -> Dictionary:
	return Niveau.construire(get_node_or_null("Surface/Sol"), get_node_or_null("Surface/Objets"), grottes(),
		get_node_or_null("Surface/Props"), marqueurs())
