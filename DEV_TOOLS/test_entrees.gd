extends SceneTree
##
## LES TESTS DES ENTRÉES — clavier ET manette, et rien qui ne se joue qu'à l'un des deux.
##
## ⚠ Ces tests ne vérifient pas « les bonnes touches sont là » (ça, une capture d'écran le dit) : ils
## gardent des propriétés STRUCTURELLES, celles qu'on casse six mois plus tard sans s'en apercevoir —
## une action ajoutée au clavier seulement, une lettre gravée écrite à la place d'une position, deux
## actions sur la même touche, une installation qui double les liaisons.
##
## LANCEMENT
##   godot --headless --path D:/UnderMend --script res://DEV_TOOLS/test_entrees.gd
## Code de sortie 0 si tout passe, 1 sinon.

const Entrees := preload("res://CLIENT/entrees.gd")

var echecs: int = 0
var verifs: int = 0


func _initialize() -> void:
	print("TESTS — Undermend, les entrées\n")
	Entrees.installer()

	test_actions_posees()
	test_toujours_les_deux_peripheriques()
	test_positions_et_non_lettres()
	test_zqsd_et_wasd_sont_la_meme_chose()
	test_aucune_liaison_partagee()
	test_reinstaller_efface_l_ancien()
	test_systeme_au_clavier_seulement()

	print("")
	if echecs == 0:
		print("TOUT PASSE — %d vérifications." % verifs)
	else:
		print("%d ÉCHEC(S) sur %d vérifications." % [echecs, verifs])
	quit(1 if echecs > 0 else 0)


# --- outillage ---------------------------------------------------------------------------------------

func _verifier(condition: bool, quoi: String) -> void:
	verifs += 1
	if not condition:
		echecs += 1
		print("  ÉCHEC — " + quoi)


func _titre(texte: String) -> void:
	print("• " + texte)


func _touches(action: String) -> Array:
	var liste: Array = []
	for evenement in InputMap.action_get_events(action):
		if evenement is InputEventKey:
			liste.append(evenement)
	return liste


func _manette(action: String) -> Array:
	var liste: Array = []
	for evenement in InputMap.action_get_events(action):
		if evenement is InputEventJoypadButton or evenement is InputEventJoypadMotion:
			liste.append(evenement)
	return liste


## Une empreinte d'événement, pour repérer deux actions qui se disputent la même liaison.
func _empreinte(evenement: InputEvent) -> String:
	if evenement is InputEventKey:
		return "touche %d alt=%s" % [evenement.physical_keycode if evenement.physical_keycode != 0 else -evenement.keycode, evenement.alt_pressed]
	if evenement is InputEventJoypadButton:
		return "bouton %d" % evenement.button_index
	if evenement is InputEventJoypadMotion:
		return "axe %d %s" % [evenement.axis, signf(evenement.axis_value)]
	return str(evenement)


# --- les tests ---------------------------------------------------------------------------------------

func test_actions_posees() -> void:
	_titre("toutes les actions existent, avec leur zone morte")
	for action in Entrees.JEU:
		_verifier(InputMap.has_action(action), "l'action de jeu « %s » manque" % action)
		_verifier(is_equal_approx(InputMap.action_get_deadzone(action), Entrees.ZONE_MORTE),
			"zone morte de « %s » : %f" % [action, InputMap.action_get_deadzone(action)])
	for action in Entrees.SYSTEME:
		_verifier(InputMap.has_action(action), "l'action système « %s » manque" % action)


## Vu échouer : manette retirée d'une action de jeu.
func test_toujours_les_deux_peripheriques() -> void:
	_titre("toute action de JEU se fait au clavier ET à la manette")
	for action in Entrees.JEU:
		_verifier(not _touches(action).is_empty(), "« %s » n'a aucune touche" % action)
		_verifier(not _manette(action).is_empty(), "« %s » n'a rien sur la manette" % action)


## Vu échouer : `keycode` écrit à la place de `physical_keycode`.
func test_positions_et_non_lettres() -> void:
	_titre("les touches sont des POSITIONS, jamais des lettres gravées")
	for action in Entrees.JEU.keys() + Entrees.SYSTEME.keys():
		for evenement in _touches(action):
			_verifier(evenement.physical_keycode != 0 and evenement.keycode == 0,
				"« %s » : touche liée par sa lettre (keycode %d) — un clavier français ou américain y perdrait" % [action, evenement.keycode])


## La garantie qui fait que ZQSD et WASD sont la MÊME liaison. Si ces quatre positions changent, c'est
## un choix, et il doit se voir ici.
func test_zqsd_et_wasd_sont_la_meme_chose() -> void:
	_titre("les positions de W, A, S, D — soit Z, Q, S, D sur un clavier français")
	var attendu := {"gauche": KEY_A, "droite": KEY_D, "haut": KEY_W, "bas": KEY_S}
	for action in attendu:
		var positions: Array = []
		for evenement in _touches(action):
			positions.append(evenement.physical_keycode)
		_verifier(attendu[action] in positions, "« %s » devrait contenir la position %s, il a %s" % [action, OS.get_keycode_string(attendu[action]), str(positions)])


## Vu échouer : une même touche liée à deux actions.
func test_aucune_liaison_partagee() -> void:
	_titre("aucune liaison ne sert deux actions à la fois")
	var vues := {}
	for action in Entrees.JEU.keys() + Entrees.SYSTEME.keys():
		for evenement in InputMap.action_get_events(action):
			var empreinte := _empreinte(evenement)
			_verifier(not vues.has(empreinte), "%s sert « %s » et « %s »" % [empreinte, vues.get(empreinte, ""), action])
			vues[empreinte] = action


## Vu échouer : `erase_action` retiré de `_poser`.
##
## ⚠ Vérifier qu'une réinstallation ne DOUBLE pas une liaison ne prouverait rien : Godot ignore un
## événement déjà présent dans une action, donc ça ne peut pas arriver. Ce qui casse pour de bon, c'est
## la liaison PÉRIMÉE — celle qu'on a retirée de la carte et qui resterait branchée.
func test_reinstaller_efface_l_ancien() -> void:
	_titre("réinstaller les entrées efface les liaisons périmées, et n'en double aucune")
	var avant := {}
	for action in Entrees.JEU:
		avant[action] = InputMap.action_get_events(action).size()
	var perimee := InputEventKey.new()
	perimee.physical_keycode = KEY_P  # une liaison d'une carte précédente, qu'on vient de retirer
	InputMap.action_add_event("agir", perimee)
	Entrees.installer()
	for action in Entrees.JEU:
		_verifier(InputMap.action_get_events(action).size() == avant[action],
			"« %s » : %d liaisons après réinstallation, %d attendues" % [action, InputMap.action_get_events(action).size(), avant[action]])
	var restes := 0
	for evenement in InputMap.action_get_events("agir"):
		if evenement is InputEventKey and evenement.physical_keycode == KEY_P:
			restes += 1
	_verifier(restes == 0, "la liaison périmée (P) est restée branchée sur « agir »")


func test_systeme_au_clavier_seulement() -> void:
	_titre("les actions système restent au clavier — pas de plein écran par un pouce égaré")
	for action in Entrees.SYSTEME:
		_verifier(not _touches(action).is_empty(), "« %s » n'a aucune touche" % action)
		_verifier(_manette(action).is_empty(), "« %s » ne doit rien avoir sur la manette" % action)
