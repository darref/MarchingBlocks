extends SceneTree
##
## SONDE — la légende du témoin : ce que la couleur dit du contexte.
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_legende_contexte.gd
##
## Elle ne conçoit rien : elle compte ce que `_coque_sous_voxels` peint réellement, et confronte le
## compte au critère lu à la source. Écrite parce que le commentaire de `_quad` avance « 76 % du bloc
## est souterrain » — un chiffre qu'aucun instrument ne rendait.

const MB := preload("res://addons/marching_blocks_plugin_godot/marching_blocks.gd")
const BM := preload("res://addons/marching_blocks_plugin_godot/blocs_maitres.gd")
const RP := preload("res://addons/marching_blocks_plugin_godot/repli_procedural.gd")


func _initialize() -> void:
	print("\n=== SONDE — LA LÉGENDE DU TÉMOIN ===\n")
	_ce_que_le_critere_dit_des_cases()
	_ce_que_la_coque_peint_vraiment()
	_le_bloc_deplace_vers_les_x_negatifs()
	quit(0)


## Les trois teintes de base, celles que `_quad` pose quand la case n'est pas sous roche.
func _teintes_claires() -> Array:
	return [RP.COULEUR_DESSUS, RP.COULEUR_PAROI, RP.COULEUR_PLAFOND]


func _est_claire(c: Color) -> bool:
	for base in _teintes_claires():
		if is_equal_approx(c.r, base.r) and is_equal_approx(c.g, base.g) and is_equal_approx(c.b, base.b):
			return true
	return false


## Combien de quads sombres / clairs dans un maillage. Un quad = deux triangles = six sommets, tous de
## la même couleur ; on compte donc par sommet et l'on divise.
func _compter(mesh: ArrayMesh) -> Dictionary:
	if mesh.get_surface_count() == 0:
		return {"clairs": 0, "sombres": 0}
	var couleurs: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var clairs := 0
	var sombres := 0
	for c in couleurs:
		if _est_claire(c):
			clairs += 1
		else:
			sombres += 1
	return {"clairs": clairs / 6, "sombres": sombres / 6}


func _ce_que_le_critere_dit_des_cases() -> void:
	print("── 1. LE CRITÈRE, CASE PAR CASE ──")
	var pleines: Dictionary = BM.cases(0)
	var plafond: int = MB.plafond_de(pleines)
	var sous_roche := 0
	for c in pleines:
		if MB.case_sous_roche(pleines, c, plafond):
			sous_roche += 1
	var part := 100.0 * float(sous_roche) / float(pleines.size())
	print("   %d cases pleines, plafond y = %d" % [pleines.size(), plafond])
	print("   %d sous roche, %d à l'air libre  →  %.1f %% de souterrain"
		% [sous_roche, pleines.size() - sous_roche, part])


func _ce_que_la_coque_peint_vraiment() -> void:
	print("\n── 2. CE QUE LA COQUE PEINT ──")
	for retrait in [0.0, 0.25]:
		var mesh: ArrayMesh = BM._coque_sous_voxels(BM.cases(0), retrait)
		var n: Dictionary = _compter(mesh)
		var total: int = n["clairs"] + n["sombres"]
		var part := 0.0 if total == 0 else 100.0 * float(n["sombres"]) / float(total)
		print("   retrait %.2f : %d quads — %d sombres, %d clairs  →  %.1f %% de faces souterraines"
			% [retrait, total, n["sombres"], n["clairs"], part])


## ⚠ LE POINT QUI SE MESURE PLUTÔT QU'IL NE SE SUPPOSE. `_coque_sous_voxels` retrouve la case d'un
## sous-voxel par une DIVISION ENTIÈRE. En GDScript elle tronque VERS ZÉRO : pour une case en x = −1,
## les sous-voxels vont de −4 à −1 et rendent 0, pas −1. La sonde translate donc le même bloc et
## compare — si les comptes diffèrent, la carte des contextes ne suit pas le bloc.
func _le_bloc_deplace_vers_les_x_negatifs() -> void:
	print("\n── 3. LE MÊME BLOC, TRANSLATÉ EN x NÉGATIF ──")
	var origine: Dictionary = BM.cases(0)
	var decale := {}
	for c in origine:
		var p: Vector3i = c
		decale[Vector3i(p.x - BM.COTE, p.y, p.z)] = true
	var a: Dictionary = _compter(BM._coque_sous_voxels(origine, 0.25))
	var b: Dictionary = _compter(BM._coque_sous_voxels(decale, 0.25))
	print("   à l'origine : %d sombres / %d quads" % [a["sombres"], a["clairs"] + a["sombres"]])
	print("   translaté   : %d sombres / %d quads" % [b["sombres"], b["clairs"] + b["sombres"]])
	if a["sombres"] == b["sombres"]:
		print("   → la légende suit le bloc.")
	else:
		print("   ⚠ ÉCART DE %d QUADS — la légende NE SUIT PAS le bloc en coordonnées négatives."
			% absi(a["sombres"] - b["sombres"]))
