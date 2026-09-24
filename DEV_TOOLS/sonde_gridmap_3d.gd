extends SceneTree
## SONDE — l'autotiling 3D par GridMap se pilote-t-il SANS ÉCRAN ?
##
## ⚠ Ce fichier n'est pas un test du jeu : c'est une MESURE d'étude, écrite pour l'analyse de
## faisabilité du passage en 3D. À supprimer si la 3D n'est pas retenue.
##
##   godot --headless --path D:/UnderMend --script res://DEV_TOOLS/sonde_gridmap_3d.gd
##
## CE QU'ELLE VÉRIFIE, ET POURQUOI CHAQUE POINT COMPTE :
##
##  1. `GridMap` + `MeshLibrary` se construisent et se lisent HORS ARBRE et SANS FENÊTRE. Si c'était
##     faux, aucune de nos suites ne pourrait bâtir ses mondes en code, et toute la discipline
##     « un test qu'on n'a pas vu rougir ne garde rien » tomberait avec elles.
##  2. La règle de Spirit3D « silhouette → pièce + orientation » (`_step_top_dir` / `_resolve_dir`,
##     portée ici depuis `heart_world_plateau.gd`) couvre les 13 directions avec SEULEMENT 4 pièces
##     sculptées — nord, nord-ouest, coin nord-ouest, centre — les neuf autres étant des ROTATIONS
##     posées par `set_cell_item(..., orientation)`. C'est le principe que le greffon a généralisé.
##  3. Les quatre index d'orientation employés (0, 22, 10, 16) sont bien les quatre quarts de tour
##     AUTOUR DE Y, et rien d'autre. Une table d'index recopiée sans être vérifiée est exactement le
##     genre de chose qui pose des falaises tournées à l'envers sans qu'aucune erreur ne le dise.
##  4. Le `mur` se relit par le NOM de la pièce — GridMap n'a pas de donnée personnalisée par case,
##     contrairement à `TileData`. C'est la seule différence de fond avec le contrat actuel.

## Les 13 directions, DANS L'ORDRE DES INDEX (l'ordre EST l'index).
const DIRS := [
	"nord", "sud", "est", "ouest",
	"nord_est", "nord_ouest", "sud_est", "sud_ouest",
	"centre",
	"coin_nord_ouest", "coin_nord_est", "coin_sud_est", "coin_sud_ouest",
]
const CENTRE := 8

## direction → pièce de BASE réutilisée (index de DIRS) et nombre de quarts de tour horaire.
const BASE := [0, 0, 0, 0, 5, 5, 5, 5, 8, 9, 9, 9, 9]
const PAS := [0, 2, 1, 3, 1, 0, 2, 3, 0, 0, 1, 2, 3]
## quarts de tour → index d'orientation orthogonale de GridMap (rotation autour de Y).
const YAW := [0, 22, 10, 16]

## Voisinage 8 dans l'ordre attendu par `direction()` : N, E, S, O, NE, NO, SE, SO (y − 1 = nord).
const N8 := [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
	Vector2i(1, -1), Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-1, 1),
]

var _ok := 0
var _echecs := 0


func _initialize() -> void:
	print("=== SONDE GridMap 3D (headless) ===\n")
	_les_orientations_sont_des_quarts_de_tour()
	_quatre_pieces_couvrent_treize_directions()
	_un_plateau_ecrit_et_se_relit()
	_le_mur_se_relit_par_le_nom()
	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	print("VERDICT : %s" % ("ÉCHEC" if _echecs > 0 else "OK"))
	quit(1 if _echecs > 0 else 0)


func _dire(condition: bool, quoi: String) -> void:
	if condition:
		_ok += 1
	else:
		_echecs += 1
		print("  ÉCHEC — %s" % quoi)


# ── 1. les orientations ─────────────────────────────────────────────────────────────────────────────

## ⚠ CE QU'ON VÉRIFIE ICI N'EST PAS UNE CONVENTION, C'EST UNE TABLE RECOPIÉE. Les quatre index
## viennent du C++ de Spirit3D ; s'ils ne sont pas les quatre quarts de tour autour de Y, tout
## l'autotiling par rotation est faux, et il est faux SILENCIEUSEMENT.
func _les_orientations_sont_des_quarts_de_tour() -> void:
	print("1. les quatre index d'orientation (0, 22, 10, 16)")
	var grille := GridMap.new()
	var vus: Array = []
	for i in YAW.size():
		var base: Basis = grille.get_basis_with_orthogonal_index(YAW[i])
		var haut: Vector3 = base * Vector3.UP
		_dire(haut.is_equal_approx(Vector3.UP), "l'index %d ne garde pas Y vers le haut (%s)" % [YAW[i], haut])
		var vers: Vector3 = base * Vector3.FORWARD
		var attendu := Vector3.FORWARD.rotated(Vector3.UP, -i * PI / 2.0)
		_dire(vers.is_equal_approx(attendu),
			"l'index %d ne tourne pas de %d quart(s) de tour horaire (%s au lieu de %s)" % [YAW[i], i, vers, attendu])
		for autre in vus:
			_dire(not vers.is_equal_approx(autre), "l'index %d refait une rotation déjà vue" % YAW[i])
		vus.append(vers)
		print("   index %2d → avant = %s" % [YAW[i], vers])
	grille.free()
	print("   → %d orientations distinctes, toutes autour de Y" % vus.size())


# ── 2. la couverture ────────────────────────────────────────────────────────────────────────────────

## La direction d'une case d'après ses huit voisins EXPOSÉS (plus bas qu'elle).
## Portage exact de `_step_top_dir` (Spirit3D, C++) : coins extérieurs, puis bords, puis coins
## rentrants, puis centre. ⚠ L'ordre des tests EST la règle — un bord droit et un coin rentrant ne
## sont pas départagés par un score mais par cette priorité.
static func direction(e: Array) -> int:
	var n: bool = e[0]
	var est: bool = e[1]
	var s: bool = e[2]
	var o: bool = e[3]
	if n and est: return 4
	if n and o: return 5
	if s and est: return 6
	if s and o: return 7
	if n: return 0
	if s: return 1
	if est: return 2
	if o: return 3
	if e[4]: return 10
	if e[5]: return 9
	if e[6]: return 11
	if e[7]: return 12
	return CENTRE


## (pièce, orientation) pour une direction : la pièce SPÉCIFIQUE si elle existe, sinon la pièce de
## BASE tournée. (-1, 0) si même la base manque — l'appelant n'écrit alors rien.
static func resoudre(ids: Array, dir: int) -> Vector2i:
	var d: int = dir if dir >= 0 and dir < DIRS.size() else CENTRE
	if ids[d] >= 0:
		return Vector2i(ids[d], 0)
	var base: int = BASE[d]
	if ids[base] >= 0:
		return Vector2i(ids[base], YAW[PAS[d]])
	return Vector2i(-1, 0)


## ⚠ LA QUESTION QUI DÉCIDE DU LOT D'ART À ACHETER. En 2D, la charte a mesuré qu'un lot à cadre 4×4
## ne borde qu'une tache convexe et qu'il faut 47 tuiles pour un contour organique. En 3D par
## rotation, quatre pièces suffisent-elles vraiment aux treize directions ?
func _quatre_pieces_couvrent_treize_directions() -> void:
	print("\n2. quatre pièces sculptées pour treize directions")
	var librairie := MeshLibrary.new()
	var ids := _librairie_reduite(librairie)
	var manquantes: Array = []
	var par_rotation := 0
	for d in DIRS.size():
		var choix := resoudre(ids, d)
		if choix.x < 0:
			manquantes.append(DIRS[d])
		elif choix.y != 0:
			par_rotation += 1
	_dire(manquantes.is_empty(), "directions sans pièce : %s" % str(manquantes))
	_dire(par_rotation == 9, "9 directions devraient venir d'une rotation, pas %d" % par_rotation)
	print("   → 13 directions servies : 4 sculptées, %d par rotation, 0 repli" % par_rotation)


## La librairie RÉDUITE : seulement les quatre pièces qu'un lot devrait fournir.
func _librairie_reduite(librairie: MeshLibrary) -> Array:
	var sculptees := {0: "dessus_nord", 5: "dessus_nord_ouest", 8: "dessus_centre", 9: "dessus_coin_nord_ouest"}
	var ids: Array = []
	ids.resize(DIRS.size())
	ids.fill(-1)
	for d in sculptees:
		librairie.create_item(d)
		librairie.set_item_name(d, sculptees[d])
		librairie.set_item_mesh(d, BoxMesh.new())
		ids[d] = d
	# ⚠ On les relit PAR LEUR NOM, jamais par l'index qu'on vient d'écrire : c'est la règle du §6 de
	# la charte (« jamais une tuile par sa position dans l'atlas, toujours par son nom »), et c'est
	# aussi ce que fait Spirit3D (`find_item_by_name`).
	for d in sculptees:
		var relu: int = librairie.find_item_by_name(sculptees[d])
		_dire(relu == d, "« %s » se relit en %d au lieu de %d" % [sculptees[d], relu, d])
	return ids


# ── 3. un plateau écrit, puis relu ──────────────────────────────────────────────────────────────────

## ⚠ LA FORME COMPTE AUTANT QUE LE COMPTE. La charte a appris en 2D qu'un disque ne prouve rien : sa
## frontière est convexe. On prend donc un rectangle ÉCHANCRÉ (donc avec des coins rentrants), une
## croix et une bande d'une seule case — les formes qui ont fait tomber le lot 2D.
func _un_plateau_ecrit_et_se_relit() -> void:
	print("\n3. un plateau écrit dans un GridMap hors arbre")
	for essai in [
		{"nom": "rectangle échancré", "cases": _rectangle_echancre()},
		{"nom": "croix", "cases": _croix()},
		{"nom": "bande d'une case", "cases": _bande()},
	]:
		var cases: Dictionary = essai["cases"]
		var grille := GridMap.new()
		var librairie := MeshLibrary.new()
		var ids := _librairie_reduite(librairie)
		grille.mesh_library = librairie
		var directions := {}
		# ⚠ DEUX PASSES : on fige TOUTE la silhouette avant d'écrire. En écrivant au fil de l'eau, une
		# colonne déjà posée ferait passer sa voisine pour intérieure — Spirit3D a la même note, et le
		# défaut y était « le plateau finit bordé de trous ».
		for c in cases:
			var e: Array = []
			for d in N8:
				e.append(not cases.has(c + d))
			directions[c] = direction(e)
		var ecrites := 0
		for c in cases:
			var choix := resoudre(ids, directions[c])
			if choix.x < 0:
				continue
			grille.set_cell_item(Vector3i(c.x, 1, c.y), choix.x, choix.y)
			ecrites += 1
		_dire(ecrites == cases.size(), "%s : %d cases écrites sur %d" % [essai["nom"], ecrites, cases.size()])
		# Relecture : la case doit rendre la pièce ET l'orientation qu'on y a mises.
		var relues := 0
		var tournees := 0
		for c in cases:
			var item: int = grille.get_cell_item(Vector3i(c.x, 1, c.y))
			var orient: int = grille.get_cell_item_orientation(Vector3i(c.x, 1, c.y))
			var attendu := resoudre(ids, directions[c])
			if item == attendu.x and orient == attendu.y:
				relues += 1
			if orient != 0:
				tournees += 1
		_dire(relues == cases.size(), "%s : %d cases relues à l'identique sur %d" % [essai["nom"], relues, cases.size()])
		# ⚠ « Une case non peinte est un MUR » a son équivalent exact : une case vide rend INVALID_CELL_ITEM.
		var dehors: int = grille.get_cell_item(Vector3i(-99, 1, -99))
		_dire(dehors == GridMap.INVALID_CELL_ITEM, "une case jamais écrite devrait rendre INVALID_CELL_ITEM")
		print("   %s : %d cases, %d posées par rotation, relecture exacte" % [essai["nom"], cases.size(), tournees])
		grille.free()


func _rectangle_echancre() -> Dictionary:
	var cases := {}
	for y in 6:
		for x in 8:
			cases[Vector2i(x, y)] = true
	for y in 2:
		for x in 2:
			cases.erase(Vector2i(6 + x, 4 + y))  # l'échancrure : elle fabrique des coins rentrants
	return cases


func _croix() -> Dictionary:
	var cases := {}
	for i in 7:
		cases[Vector2i(3, i)] = true
		cases[Vector2i(i, 3)] = true
	return cases


func _bande() -> Dictionary:
	var cases := {}
	for x in 6:
		cases[Vector2i(x, 0)] = true
	return cases


# ── 4. le mur ───────────────────────────────────────────────────────────────────────────────────────

## ⚠ LA SEULE VRAIE PERTE EN PASSANT À GRIDMAP : `TileData.get_custom_data("mur")` n'a pas
## d'équivalent. GridMap n'a pas de donnée par case. Le `mur` se relit donc par le NOM de la pièce,
## via une table construite une fois — ce qui reste conforme à la charte (« par son nom, jamais par
## sa position ») mais déplace l'autorité du TileSet vers une table de code.
func _le_mur_se_relit_par_le_nom() -> void:
	print("\n4. le « mur » relu par le nom de la pièce")
	var librairie := MeshLibrary.new()
	var pieces := {0: "roche_nord", 1: "sol_herbe", 2: "roche_centre"}
	for id in pieces:
		librairie.create_item(id)
		librairie.set_item_name(id, pieces[id])
		librairie.set_item_mesh(id, BoxMesh.new())
	var murs := {}
	for id in librairie.get_item_list():
		murs[id] = librairie.get_item_name(id).begins_with("roche")
	var grille := GridMap.new()
	grille.mesh_library = librairie
	grille.set_cell_item(Vector3i(0, 0, 0), 0)
	grille.set_cell_item(Vector3i(1, 0, 0), 1)
	_dire(murs.get(grille.get_cell_item(Vector3i(0, 0, 0)), false), "la roche devrait être un mur")
	_dire(not murs.get(grille.get_cell_item(Vector3i(1, 0, 0)), true), "l'herbe ne devrait pas être un mur")
	var vide: int = grille.get_cell_item(Vector3i(5, 0, 5))
	_dire(not murs.has(vide), "une case vide n'est dans aucune entrée de la table")
	print("   → %d pièces, %d marquées « mur », relues par le nom" % [murs.size(), murs.values().count(true)])
	grille.free()
