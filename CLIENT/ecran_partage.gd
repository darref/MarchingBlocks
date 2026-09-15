extends Node2D
## L'ÉCRAN PARTAGÉ — deux vues rendues à pleine taille, un séparateur, et l'affichage ne fait que ROGNER.
##
## ⚠ On ne redimensionne JAMAIS un `SubViewport` pendant le balayage : changer sa taille réalloue sa
## cible de rendu, à chaque image. Les deux vues rendent en permanence à 320×160 ; ce nœud dessine la
## partie gauche de la surface et la partie droite de la grotte, et ne change que deux rectangles quand
## le séparateur bouge (charte §3).
##
## Ce nœud ne DÉCIDE rien : la position vient de `MiseEnPage`, qui est pure et testée. Il affiche.
##
## Usage : le jeu met ses mondes dans `surface` et `grotte`, appelle `afficher()` chaque image, et place
## ses caméras par `centrer()`.

const MiseEnPage := preload("res://CLIENT/mise_en_page.gd")

## PROPOSÉ — l'or du logo (MARQUE/embleme.png), un pixel de base. À juger avec Jordan.
const COULEUR_DEMARCATION := Color("#EBBB69")

var surface: SubViewport
var grotte: SubViewport
var separateur: int = MiseEnPage.SURFACE_SEULE


func _init() -> void:
	surface = _vue("Surface")
	grotte = _vue("Grotte")


func _vue(nom: String) -> SubViewport:
	var vue := SubViewport.new()
	vue.name = nom
	vue.size = Vector2i(MiseEnPage.LARGEUR, MiseEnPage.HAUTEUR)
	vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vue.snap_2d_transforms_to_pixel = true
	vue.snap_2d_vertices_to_pixel = true
	vue.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(vue)
	return vue


## Chaque image : la position du séparateur en pixels de base, et sa cible.
func afficher(pixel: int, cible: int) -> void:
	_rendre(surface, MiseEnPage.surface_rendue(pixel, cible))
	_rendre(grotte, MiseEnPage.grotte_rendue(pixel, cible))
	if pixel != separateur:
		separateur = pixel
		queue_redraw()  # seulement quand il bouge : les textures des vues, elles, se mettent à jour seules


## ⚠ Une vue cachée cesse de se RENDRE, pas d'être simulée : ses nœuds continuent de tourner.
func _rendre(vue: SubViewport, oui: bool) -> void:
	var mode := SubViewport.UPDATE_ALWAYS if oui else SubViewport.UPDATE_DISABLED
	if vue.render_target_update_mode != mode:
		vue.render_target_update_mode = mode


## Place `camera` pour que `point` (monde de la vue) tombe au milieu de la partie VISIBLE de sa vue.
func centrer(camera: Camera2D, point: Vector2, dans_la_grotte: bool) -> void:
	var centres := MiseEnPage.centres(separateur)
	var x: int = centres.y if dans_la_grotte else centres.x
	camera.position = point.round()
	camera.offset = Vector2(MiseEnPage.LARGEUR / 2 - x, 0)
	camera.force_update_scroll()


func _draw() -> void:
	var s := separateur
	var l := MiseEnPage.LARGEUR
	var h := MiseEnPage.HAUTEUR
	if s > 0:
		draw_texture_rect_region(surface.get_texture(), Rect2(0, 0, s, h), Rect2(0, 0, s, h))
	if s < l:
		draw_texture_rect_region(grotte.get_texture(), Rect2(s, 0, l - s, h), Rect2(s, 0, l - s, h))
		draw_rect(Rect2(s, 0, 1, h), COULEUR_DEMARCATION)  # sur la première colonne de la grotte
