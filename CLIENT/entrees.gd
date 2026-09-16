extends Node
## LES ENTRÉES — le jeu se joue ENTIÈREMENT au clavier ou ENTIÈREMENT à la manette (DÉCIDÉ).
##
## ⚠ UNE SEULE AUTORITÉ, ET C'EST CE FICHIER. La carte des entrées ne va PAS dans project.godot : deux
## descriptions d'une même chose divergent au premier réglage, et project.godot ne garde aucun
## commentaire — or chaque ligne ci-dessous a une raison. L'InputMap est rempli au démarrage, en
## autoload, avant toute scène. ⚠ L'ORDRE des autoloads, lui, ne se garantit pas : l'éditeur le réécrit
## en enregistrant project.godot, donc `fenetre.gd` vérifie que l'action existe avant de s'en servir.
##
## ⚠ POSITIONS DE TOUCHES, PAS LETTRES GRAVÉES. `physical_keycode` désigne la POSITION de la touche,
## nommée d'après un clavier américain : W, A, S, D. Sur un clavier français, ces quatre positions SONT
## Z, Q, S, D. Une seule ligne sert donc ZQSD ici et WASD ailleurs, sans que personne ne reconfigure
## rien. Écrire `keycode` — la lettre gravée — casserait l'un des deux claviers ; un test le garde.
##
## ⚠ Chaque action de JEU porte au moins une touche ET au moins un bouton ou un axe de manette. C'est
## une propriété STRUCTURELLE, gardée par `DEV_TOOLS/test_entrees.gd` : on ne peut pas ajouter une
## action jouable à un seul périphérique sans faire rougir le test.

## ⚠ C'est AUSSI la zone morte par défaut de Godot : l'écrire ici la rend visible et réglable, mais le
## test qui la vérifie ne garde que contre une valeur aberrante, pas contre un oubli.
const ZONE_MORTE := 0.2

## Les actions de JEU. `touches` : des POSITIONS (voir l'en-tête) ; `boutons` et `axes` : la manette,
## disposition Xbox telle que Godot la normalise. Un axe est [axe, signe].
const JEU := {
	"gauche": {
		"touches": [KEY_A, KEY_LEFT],  # position de A : Q sur un clavier français
		"boutons": [JOY_BUTTON_DPAD_LEFT],
		"axes": [[JOY_AXIS_LEFT_X, -1.0]],
	},
	"droite": {
		"touches": [KEY_D, KEY_RIGHT],
		"boutons": [JOY_BUTTON_DPAD_RIGHT],
		"axes": [[JOY_AXIS_LEFT_X, 1.0]],
	},
	"haut": {
		"touches": [KEY_W, KEY_UP],  # position de W : Z sur un clavier français
		"boutons": [JOY_BUTTON_DPAD_UP],
		"axes": [[JOY_AXIS_LEFT_Y, -1.0]],
	},
	"bas": {
		"touches": [KEY_S, KEY_DOWN],
		"boutons": [JOY_BUTTON_DPAD_DOWN],
		"axes": [[JOY_AXIS_LEFT_Y, 1.0]],
	},
	## Descendre par une entrée, remonter, et plus tard parler, prendre, poser.
	"agir": {
		"touches": [KEY_SPACE],
		"boutons": [JOY_BUTTON_A],
		"axes": [],
	},
	## PROPOSÉ — maintenu, pas basculé : on court tant qu'on appuie. La gâchette droite est là pour ceux
	## qui gardent le pouce sur les boutons d'action.
	"courir": {
		"touches": [KEY_SHIFT],
		"boutons": [JOY_BUTTON_B],
		"axes": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	},
}

## Les actions SYSTÈME — clavier seulement, et c'est VOULU : on ne bascule pas en plein écran d'un
## pouce égaré sur une manette. `touches_avec_alt` demande Alt en plus.
const SYSTEME := {
	"plein_ecran": {
		"touches": [KEY_F11],
		"touches_avec_alt": [KEY_ENTER],
	},
}


func _ready() -> void:
	installer()


## Remplit l'InputMap. ⚠ IDEMPOTENTE : on efface l'action avant de la reposer, sinon la rappeler
## doublerait chaque liaison — et une touche liée deux fois déclenche deux fois.
static func installer() -> void:
	for action in JEU:
		_poser(action, JEU[action])
	for action in SYSTEME:
		_poser(action, SYSTEME[action])


static func _poser(action: String, carte: Dictionary) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, ZONE_MORTE)
	for position in carte.get("touches", []):
		InputMap.action_add_event(action, _touche(position))
	for position in carte.get("touches_avec_alt", []):
		InputMap.action_add_event(action, _touche(position, true))
	for bouton in carte.get("boutons", []):
		var evenement := InputEventJoypadButton.new()
		evenement.button_index = bouton
		InputMap.action_add_event(action, evenement)
	for axe in carte.get("axes", []):
		var evenement := InputEventJoypadMotion.new()
		evenement.axis = axe[0]
		evenement.axis_value = axe[1]
		InputMap.action_add_event(action, evenement)


static func _touche(position: int, avec_alt: bool = false) -> InputEventKey:
	var evenement := InputEventKey.new()
	evenement.physical_keycode = position
	evenement.alt_pressed = avec_alt
	return evenement


# ── ce que le jeu demande ───────────────────────────────────────────────────────────────────────────

## Le déplacement voulu, de -1 à 1 sur chaque axe. Le stick est analogique, les touches et la croix
## valent 1 : c'est la même fonction pour les deux périphériques, et personne n'a à savoir lequel sert.
static func deplacement() -> Vector2:
	return Input.get_vector("gauche", "droite", "haut", "bas")


static func court() -> bool:
	return Input.is_action_pressed("courir")


static func agit() -> bool:
	return Input.is_action_just_pressed("agir")


## Pour les outils : ce que Godot voit branché, au format « 0 : nom ».
static func manettes() -> Array:
	var noms: Array = []
	for id in Input.get_connected_joypads():
		noms.append("%d : %s" % [id, Input.get_joy_name(id)])
	return noms
