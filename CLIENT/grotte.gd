@tool
extends Node2D
## UNE GROTTE PEINTE — sa coupe, et le CHEMIN qu'elle suit sur la grille de surface (charte §2).
##
## ⚠ `@tool` POUR UNE SEULE RAISON : LE CHEMIN EST INVISIBLE. Une entrée doit être peinte sur une case
## que cette grotte traverse, sinon `CLIENT/niveau.gd` la refuse — mais rien, dans l'éditeur, ne montrait
## où passe le tunnel. On peignait donc à l'aveugle, pour l'apprendre au lancement. Le gizmo ci-dessous
## dessine la table sur la grille de surface, pendant qu'on peint.
##
## ⚠ Il ne dessine PAS une seconde vérité : il affiche `Niveau.chemin()`, la même fonction que le
## chargeur appelle. Un gizmo qui recalculerait le trajet à sa façon finirait par mentir (charte §2).
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
##   Coupe     (TileMapLayer) — la grotte vue de côté ; une case non peinte est de la roche
##   Objets    (TileMapLayer) — les entrées, peintes au pinceau
##   Marqueurs (Node2D)       — les objets du catalogue, un nœud chacun (CLIENT/marqueur.gd)

const Niveau := preload("res://CLIENT/niveau.gd")
const CASE := 32

@export var depart := Vector2i.ZERO:
	set(valeur):
		depart = valeur
		queue_redraw()
		update_configuration_warnings()

@export var segments: Array[Vector2i] = []:
	set(valeur):
		segments = valeur
		queue_redraw()
		update_configuration_warnings()


## Ce que `CLIENT/niveau.gd` attend d'une grotte. Les calques peuvent manquer : il le signalera.
func description() -> Dictionary:
	return {
		"depart": depart,
		"segments": segments,
		"coupe": get_node_or_null("Coupe"),
		"objets": get_node_or_null("Objets"),
		"props": get_node_or_null("Props"),
		"marqueurs": marqueurs(),
	}


## Les marqueurs de cette grotte, décrits. ⚠ Un enfant qui n'a pas de `description()` est ignoré : on ne
## devine pas ce qu'un nœud étranger voudrait dire.
func marqueurs() -> Array:
	var liste: Array = []
	var noeud := get_node_or_null("Marqueurs")
	if noeud == null:
		return liste
	for enfant in noeud.get_children():
		if enfant.has_method("description"):
			liste.append(enfant.description())
	return liste


# ── ce que l'éditeur en montre ──────────────────────────────────────────────────────────────────────

## Le chemin, case par case, sur la grille de surface. ⚠ Les nœuds de zone sont tous à l'origine
## (`Surface` comme `GrotteN`) : une case dessinée en `case × 32` tombe donc exactement sur la grille
## qu'on peint, sans transformation à entretenir.
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var table: Array = Niveau.chemin(depart, segments)
	var teinte := Color(0.92, 0.73, 0.41)  # l'or du logo : c'est déjà la couleur de la démarcation
	for i in table.size():
		var coin := Vector2(table[i] * CASE)
		var carre := Rect2(coin, Vector2(CASE, CASE))
		draw_rect(carre, Color(teinte.r, teinte.g, teinte.b, 0.16), true)
		draw_rect(carre, Color(teinte.r, teinte.g, teinte.b, 0.55), false, 1.0)
		# La colonne 0 est marquée : c'est elle qui dit dans quel sens la coupe se déroule.
		if i == 0:
			draw_rect(Rect2(coin + Vector2(4, 4), Vector2(CASE - 8, CASE - 8)), teinte, false, 2.0)


## ⚠ La faute se dit DANS L'ÉDITEUR. Un segment en diagonale est refusé par le chargeur (charte §2,
## OUVERT) : autant l'apprendre en le tapant qu'au lancement.
func _get_configuration_warnings() -> PackedStringArray:
	var avertissements: PackedStringArray = []
	for segment in segments:
		if segment.x != 0 and segment.y != 0:
			avertissements.append("Le segment %s est en diagonale — refusé (charte §2, OUVERT)." % str(segment))
		if segment == Vector2i.ZERO:
			avertissements.append("Un segment nul n'avance à rien.")
	var coupe := get_node_or_null("Coupe")
	if coupe != null and coupe is TileMapLayer:
		var attendue: int = Niveau.chemin(depart, segments).size()
		var mesuree: int = (coupe as TileMapLayer).get_used_rect().end.x
		if mesuree > 0 and mesuree != attendue:
			avertissements.append("La coupe fait %d colonnes, le chemin %d — la table est la vérité." % [mesuree, attendue])
	return avertissements
