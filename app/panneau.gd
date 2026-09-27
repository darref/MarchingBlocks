extends PanelContainer
## UN PANNEAU POSÉ SUR LA VUE — translucide au repos, plein sous la main.
##
## ⚠ REPRIS DE SOLUTILES (`ui/sidebar.gd`), et c'est voulu : MarchingBlocks est le même genre de
## logiciel, en 3D (Jordan, 27 septembre 2026). Les leçons qu'il porte y ont été payées :
##
## ⚠ ON TEINTE `self_modulate`, PAS `modulate`. Le premier ne touche que le fond ; le second délaverait
## le texte et les boutons avec lui, et un panneau dont on ne lit plus les libellés est cassé.
## ⚠ ON TESTE LE RECTANGLE, PAS `mouse_entered` : entrer dans un bouton fait « sortir » du panneau, et
## il clignoterait à chaque survol.

## Opacité du fond quand le curseur est ailleurs.
const AU_REPOS := 0.62
## Vitesse du fondu, en unités d'opacité par seconde.
const VITESSE := 6.0


func _ready() -> void:
	self_modulate.a = AU_REPOS


func _process(delta: float) -> void:
	var dedans: bool = get_global_rect().has_point(get_global_mouse_position())
	self_modulate.a = move_toward(self_modulate.a, 1.0 if dedans else AU_REPOS, VITESSE * delta)


## Le curseur est-il sur ce panneau ? La vue s'en sert pour ne pas peindre SOUS un panneau.
func survole() -> bool:
	return visible and get_global_rect().has_point(get_global_mouse_position())
