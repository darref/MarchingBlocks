extends SceneTree
##
## TEST — les opérations d'étage (`addons/marchingblocks_core/etages.gd`).
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_etages.gd
##
## ⚠ **POURQUOI CE TEST EXISTE** : la règle vivait DANS l'écran du greffon, que rien ne testait — un
## greffon d'éditeur ne se teste pas en headless. En la sortant pour la partager avec le logiciel
## MarchingBlocks (27 septembre 2026), elle devient une fonction pure, donc enfin gardable. Les attendus
## sont écrits à la main, case par case, sur une croix de cinq cases : jamais recalculés par la fonction.

const Etages := preload("res://addons/marchingblocks_core/etages.gd")

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

	# ── « Extend facing » : dans le sens opposé de la matière. Attendus écrits à la main.
	# Un massif x ∈ [−2, 0], y ∈ [0, 1], z ∈ [0, 1] ; on choisit sa face x = 0. Quatre cases regardent
	# +X (adossées à x = −1) ; seules les deux du haut regardent +Y. Le mur s'épaissit vers +X, et
	# SEULEMENT vers +X : pas de rangée posée dessus.
	var massif := {}
	var face_x := {}
	for x in range(-2, 1):
		for y in 2:
			for z in 2:
				massif[Vector3i(x, y, z)] = true
				if x == 0:
					face_x[Vector3i(x, y, z)] = true
	var mur: Dictionary = Etages.operer(massif, 0, "face", face_x)
	_egal(mur["poser"], [Vector3i(1, 0, 0), Vector3i(1, 1, 0), Vector3i(1, 0, 1), Vector3i(1, 1, 1)],
		"extend facing épaissit un mur vers l'air, d'une case, sans couronne")

	# ⚠ CLIQUER EN CONTINU : la sélection rendue est le nouveau front (x = 1), et un second clic, sur le
	# monde augmenté, épaissit encore d'une case (x = 2) — jamais à nouveau x = 1, déjà plein.
	_egal(mur["selection"], [Vector3i(1, 0, 0), Vector3i(1, 1, 0), Vector3i(1, 0, 1), Vector3i(1, 1, 1)],
		"extend facing porte la sélection sur le nouveau front")
	for c in mur["poser"]:
		massif[c] = true
	var encore: Dictionary = Etages.operer(massif, 0, "face", mur["selection"])
	_egal(encore["poser"], [Vector3i(2, 0, 0), Vector3i(2, 1, 0), Vector3i(2, 0, 1), Vector3i(2, 1, 1)],
		"un second clic d'extend facing continue dans le même sens")
	_egal(encore["selection"], [Vector3i(2, 0, 0), Vector3i(2, 1, 0), Vector3i(2, 0, 1), Vector3i(2, 1, 1)],
		"et la sélection suit encore")

	# Un plafond de grotte : une dalle 2×2 à y = 2 sous une dalle à y = 3, rien dessous. Il descend.
	var grotte := {}
	for x in 2:
		for z in 2:
			grotte[Vector3i(x, 2, z)] = true
			grotte[Vector3i(x, 3, z)] = true
	var plafond: Dictionary = Etages.operer(grotte, 2, "face")
	_egal(plafond["poser"], [Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(0, 1, 1), Vector3i(1, 1, 1)],
		"extend facing fait descendre un plafond de grotte")

	# Une corniche de trois cases scellée dans un mur à x = −1 : rien ne l'adosse en hauteur, donc elle
	# s'allonge vers +X. Sans l'adossement, le haut l'emporterait (trois cases à ciel ouvert contre une).
	var corniche := {Vector3i(-1, 2, 0): true}
	var choix := {}
	for x in 3:
		corniche[Vector3i(x, 2, 0)] = true
		choix[Vector3i(x, 2, 0)] = true
	var allonge: Dictionary = Etages.operer(corniche, 2, "face", choix)
	_egal(allonge["poser"], [Vector3i(3, 2, 0)], "extend facing allonge une corniche loin du mur qui la porte")

	# ⚠ L'ÉGALITÉ SE DÉPARTAGE DANS L'ORDRE DE `SIX_SENS` (+X avant −X, +Z, −Z) : sur la croix, chaque bras
	# regarde son propre sens, quatre à égalité. Sans ce cas, départager par le DERNIER restait muet.
	var croix_face: Dictionary = Etages.operer(croix, 0, "face")
	_egal(croix_face["poser"], [Vector3i(2, 0, 0), Vector3i(1, 0, 1), Vector3i(1, 0, -1)],
		"extend facing départage une égalité par le premier sens (+X), toute la croix le suit")

	# Une case qui flotte n'est adossée à rien : aucun sens, rien à faire.
	var seule: Dictionary = Etages.operer({Vector3i(4, 4, 4): true}, 4, "face")
	_egal(seule["poser"], [], "extend facing ne fait rien sur une case adossée à rien")

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
