extends Node
## LA FENÊTRE — toujours en 2:1 (charte §3). Chargé en autoload : la règle vaut pour toute scène lancée.
##
## Deux choses différentes, et il ne faut pas les confondre :
##   • le CONTENU reste en 2:1 quelle que soit la fenêtre — c'est l'aspect `keep` de project.godot qui
##     pose les bandes noires, en plein écran comme en fenêtre maximisée ;
##   • la FENÊTRE elle-même reste en 2:1 pendant qu'on l'étire — c'est ce script. Godot ne sait pas
##     contraindre un rapport pendant que Windows pilote le redimensionnement : on recale la taille après
##     chaque changement, par `MiseEnPage.taille_fenetre()`, qui est testée.
##
## ⚠ MESURÉ : écouter `size_changed` ne recale RIEN. Avec l'étirement `viewport`, le viewport racine
## garde sa taille de base (320×160) quand la fenêtre change, et une fenêtre forcée à 1000×700 par
## SetWindowPos est restée hors 2:1. On lit donc `Window.size` à chaque image : un Vector2i comparé.
##
## ⚠ Le recalage ne se fait jamais depuis un signal de Windows : redimensionner pendant son propre
## message de redimensionnement, c'est lui répondre avant qu'il ait fini de parler.

const MiseEnPage := preload("res://CLIENT/mise_en_page.gd")

## PROPOSÉ — si le recalage pendant le glisser tremble, passer à false : on recale alors une fois que la
## taille ne bouge plus depuis ATTENTE_RELACHE secondes. À juger avec Jordan, à la souris.
const RECALER_PENDANT_LE_GLISSER := true
const ATTENTE_RELACHE := 0.15

var _precedente := Vector2i.ZERO  # la dernière taille 2:1 voulue : c'est d'elle qu'on part pour savoir quel bord bouge
var _vue := Vector2i.ZERO  # la dernière taille lue
var _a_recaler := false
var _depuis := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fenetre := get_window()
	fenetre.min_size = MiseEnPage.FENETRE_MIN
	_precedente = fenetre.size
	_vue = fenetre.size
	_recaler()


func _process(delta: float) -> void:
	var taille := get_window().size
	if taille != _vue:
		_vue = taille
		_a_recaler = true
		_depuis = 0.0
	if not _a_recaler:
		return
	_depuis += delta
	if RECALER_PENDANT_LE_GLISSER or _depuis >= ATTENTE_RELACHE:
		_a_recaler = false
		_recaler()


func _recaler() -> void:
	var fenetre := get_window()
	if fenetre.mode != Window.MODE_WINDOWED:
		return  # plein écran ou maximisée : l'écran impose sa taille, l'aspect `keep` pose les bandes
	var ecran := DisplayServer.screen_get_usable_rect(fenetre.current_screen).size
	var decorations := fenetre.get_size_with_decorations() - fenetre.size
	var voulue := MiseEnPage.taille_fenetre(fenetre.size, _precedente, MiseEnPage.FENETRE_MIN, ecran - decorations)
	_precedente = voulue
	if voulue != fenetre.size:
		fenetre.size = voulue


func _unhandled_input(event: InputEvent) -> void:
	var touche := event as InputEventKey
	if touche == null or not touche.pressed or touche.echo:
		return
	if touche.keycode == KEY_F11 or (touche.keycode == KEY_ENTER and touche.alt_pressed):
		basculer_plein_ecran()
		get_viewport().set_input_as_handled()


func basculer_plein_ecran() -> void:
	var fenetre := get_window()
	fenetre.mode = Window.MODE_WINDOWED if fenetre.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
