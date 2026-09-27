extends SceneTree
##
## TEST — les opérations d'étage (`addons/undermend/etages.gd`).
##
## LANCEMENT
##   godot --headless --path D:/UnderMend --script res://DEV_TOOLS/test_etages.gd
##
## ⚠ **POURQUOI CE TEST EXISTE** : la règle vivait DANS l'écran du greffon, que rien ne testait — un
## greffon d'éditeur ne se teste pas en headless. En la sortant pour la partager avec le logiciel
## MarchingBlocks (27 septembre 2026), elle devient une fonction pure, donc enfin gardable. Les attendus
## sont écrits à la main, case par case, sur une croix de cinq cases : jamais recalculés par la fonction.

const Etages := preload("res://addons/undermend/etages.gd")

var _ok := 0
var _echecs := 0


func _initialize() -> void:
	print("=== TEST — les opérations d'étage ===\n")
	# Une croix à l'étage 0 — un centre et ses quatre voisines — et une case isolée à l'étage 1.
	#
	#     z=-1    . # .
	#     z= 0    # # #        (0,0,0) est le centre, le seul entouré
	#     z=+1    . # .
	var croix := {}
	for c in [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1),
			Vector3i(0, 0, -1), Vector3i(5, 1, 5)]:
		croix[c] = true

	var haut: Dictionary = Etages.operer(croix, 0, "haut")
	_egal(haut["poser"], [Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(-1, 1, 0), Vector3i(0, 1, 1),
		Vector3i(0, 1, -1)], "étendre vers le haut recopie les cinq cases une case plus haut")
	_egal(haut["effacer"], [], "étendre vers le haut n'efface rien")

	var bas: Dictionary = Etages.operer(croix, 1, "bas")
	_egal(bas["poser"], [Vector3i(5, 0, 5)], "étendre l'étage 1 vers le bas ne pose que sous la case isolée")

	var creuser: Dictionary = Etages.operer(croix, 0, "creuser")
	_egal(creuser["effacer"], [Vector3i(0, 0, 0)], "creuser n'évide que le centre, seul entouré")
	_egal(creuser["poser"], [], "creuser ne pose rien")

	var elargir: Dictionary = Etages.operer(croix, 0, "elargir")
	# La couronne d'une croix : les quatre bouts gagnent chacun trois voisines, dont les coins partagés.
	_egal(elargir["poser"], [Vector3i(2, 0, 0), Vector3i(-2, 0, 0), Vector3i(0, 0, 2), Vector3i(0, 0, -2),
		Vector3i(1, 0, 1), Vector3i(1, 0, -1), Vector3i(-1, 0, 1), Vector3i(-1, 0, -1)],
		"élargir pose la couronne de la croix, dans le PLAN — jamais en hauteur")

	var vide: Dictionary = Etages.operer(croix, 7, "haut")
	_egal(vide["poser"], [], "un étage vide ne rend rien à faire")

	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	print("VERDICT : %s" % ("ÉCHEC" if _echecs > 0 else "OK"))
	quit(1 if _echecs > 0 else 0)


func _egal(obtenu: Dictionary, attendu: Array, quoi: String) -> void:
	var a := {}
	for c in attendu:
		a[c] = true
	var bon: bool = a.size() == obtenu.size()
	for c in a:
		if not obtenu.has(c):
			bon = false
	if bon:
		_ok += 1
		print("  ✓ %s" % quoi)
	else:
		_echecs += 1
		print("  ÉCHEC — %s : obtenu %s" % [quoi, str(obtenu.keys())])
