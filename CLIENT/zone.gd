extends Node2D
## UNE ZONE PEINTE — la scène que l'on peint dans l'éditeur, et la seule porte entre elle et CORE.
##
## Structure attendue, et les noms comptent :
##   Zone (ce script)
##   ├── Surface
##   │   ├── Sol     (TileMapLayer) — le terrain ; ⚠ une case non peinte est un MUR
##   │   └── Objets  (TileMapLayer) — les entrées, et plus tard tout le catalogue
##   └── Grottes
##       ├── Grotte1 (CLIENT/grotte.gd) — départ + segments, avec sa Coupe et ses Objets
##       └── Grotte2 …
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


## Rend {"monde", "chemins", "entrees", "erreurs"} — voir `CLIENT/niveau.gd`. ⚠ `erreurs` non vide veut
## dire que la CARTE est fautive : à afficher, jamais à taire.
func construire() -> Dictionary:
	return Niveau.construire(get_node_or_null("Surface/Sol"), get_node_or_null("Surface/Objets"), grottes(),
		get_node_or_null("Surface/Props"))
