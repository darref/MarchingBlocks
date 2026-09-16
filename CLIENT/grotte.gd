extends Node2D
## UNE GROTTE PEINTE — sa coupe, et le CHEMIN qu'elle suit sur la grille de surface (charte §2).
##
## ⚠ Le chemin est une TABLE D'ENTIERS, pas une courbe. On donne la case de DÉPART et des segments
## DROITS — un `Vector2i` par segment, où (12, 0) veut dire douze cases vers l'est. La table s'en
## déduit ; la largeur de la coupe peinte DOIT valoir sa longueur, et `CLIENT/niveau.gd` le vérifie
## plutôt que de deviner.
##
## ⚠ Une diagonale est refusée, pas interprétée : elle demanderait une convention de longueur qui
## reste OUVERTE (charte §2).
##
## Enfants attendus, et les noms comptent :
##   Coupe  (TileMapLayer) — la grotte vue de côté ; une case non peinte est de la roche
##   Objets (TileMapLayer) — ce qui s'y pose du catalogue

@export var depart := Vector2i.ZERO
@export var segments: Array[Vector2i] = []


## Ce que `CLIENT/niveau.gd` attend d'une grotte. Les calques peuvent manquer : il le signalera.
func description() -> Dictionary:
	return {
		"depart": depart,
		"segments": segments,
		"coupe": get_node_or_null("Coupe"),
		"objets": get_node_or_null("Objets"),
		"props": get_node_or_null("Props"),
	}
