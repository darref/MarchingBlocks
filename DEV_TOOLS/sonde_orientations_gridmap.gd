extends SceneTree
##
## SONDE — les VINGT-QUATRE orientations d'un GridMap sont-elles bien les 24 rotations du cube ?
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_orientations_gridmap.gd
##
## ⚠ POURQUOI ELLE EXISTE, ET POURQUOI ELLE PASSE AVANT TOUT LE RESTE. « Marching Blocks » repose sur
## un pari : 256 configurations se replient en 23 classes PARCE QU'ON PEUT TOURNER une pièce de
## n'importe laquelle des 24 rotations du cube. Si GridMap n'en offre que quelques-unes, le repli ne
## tient plus, il faut fabriquer un mesh par orientation manquante, et le lot explose.
##
## ⚠ ET C'EST EXACTEMENT LE GENRE DE TABLE QU'ON RECOPIE SANS VÉRIFIER. `sonde_gridmap_3d.gd` n'a
## mesuré que QUATRE index (0, 22, 10, 16), les quarts de tour autour de Y, et elle écrit elle-même :
## « une table d'index recopiée sans être vérifiée est exactement le genre de chose qui pose des
## falaises tournées à l'envers sans qu'aucune erreur ne le dise ». Les vingt autres n'ont jamais été
## mesurées. On ne bâtit pas une table de 256 lignes sur une supposition.
##
## CE QU'ELLE VÉRIFIE :
##   1. les 24 index rendent 24 bases DISTINCTES ;
##   2. chacune est une rotation PROPRE (déterminant +1) — un miroir serait inutilisable, et c'est
##      justement ce que GridMap ne sait pas faire ;
##   3. chacune envoie le cube sur lui-même : tout coin tombe sur un coin ;
##   4. les 24 permutations des 8 coins sont distinctes → les 24 rotations sont TOUTES atteignables ;
##   5. régression : les quatre index historiques sont bien les quarts de tour horaires autour de Y ;
##   6. l'aller-retour `basis → index → basis` est fidèle.
##
## ⚠ ELLE IMPRIME AUSSI LA TABLE INVERSE — permutation des 8 coins → index d'orientation. C'est
## LITTÉRALEMENT l'entrée du générateur de la table des 256 : sans elle, on saurait qu'une rotation
## existe sans savoir quel numéro la demande.
##
## Elle ne modifie rien. Elle mesure et elle imprime.

## Les 8 coins d'un 2×2×2, dans l'ordre des BITS : bit t = x + 2y + 4z, avec x, y, z dans {0, 1}.
## ⚠ CET ORDRE EST UN CONTRAT. La table des 256 s'indexera dessus ; le changer ici sans le changer là
## produirait des pièces justes posées au mauvais endroit — la panne la plus silencieuse qui soit.
const COINS := [
	Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0),
	Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1),
]

## Les quatre index déjà mesurés (Spirit3D, puis `sonde_gridmap_3d.gd`) : les quarts de tour horaires
## autour de Y. Ils servent ici de RÉGRESSION — s'ils bougent, c'est la sonde qui a tort.
const QUARTS := [0, 22, 10, 16]

var _ok := 0
var _echecs := 0


func _initialize() -> void:
	print("=== SONDE — les 24 orientations orthogonales d'un GridMap ===\n")
	var grille := GridMap.new()

	var permutations: Array = []
	var par_permutation := {}

	print("%-6s %-26s %-26s %-26s  %s" % ["index", "X →", "Y →", "Z →", "permutation des 8 coins"])
	print("-".repeat(118))

	for index in 24:
		var base: Basis = grille.get_basis_with_orthogonal_index(index)

		# 2. une rotation PROPRE, jamais un miroir.
		var det := base.determinant()
		_dire(absf(det - 1.0) < 0.0001,
			"l'index %d n'est pas une rotation propre (déterminant %.3f)" % [index, det])

		# 3. le cube tombe sur lui-même, coin par coin.
		var permutation: Array = []
		var tous_des_coins := true
		for t in COINS.size():
			# ⚠ ON TOURNE AUTOUR DU CENTRE DU CUBE, pas autour d'un coin. Les coins sont donc exprimés
			# en ±1 le temps de la rotation, puis ramenés en 0/1. Tourner les coordonnées 0/1 telles
			# quelles ferait sortir la moitié des coins de la boîte, et la permutation serait fausse
			# sans que rien ne s'en plaigne.
			var v: Vector3 = COINS[t] * 2.0 - Vector3.ONE
			var w: Vector3 = base * v
			var arrive := Vector3(
				roundf((w.x + 1.0) * 0.5), roundf((w.y + 1.0) * 0.5), roundf((w.z + 1.0) * 0.5))
			if not _est_un_coin(w):
				tous_des_coins = false
			permutation.append(int(arrive.x) + 2 * int(arrive.y) + 4 * int(arrive.z))
		_dire(tous_des_coins, "l'index %d n'envoie pas le cube sur lui-même" % index)

		# 4. la permutation n'a jamais été vue : deux index qui rendraient la même rotation en
		#    cacheraient une manquante.
		var cle := _en_chaine(permutation)
		_dire(not par_permutation.has(cle),
			"l'index %d refait la rotation de l'index %s" % [index, str(par_permutation.get(cle, -1))])
		par_permutation[cle] = index
		permutations.append(permutation)

		# 6. aller-retour fidèle.
		var retour: int = grille.get_orthogonal_index_from_basis(base)
		_dire(retour == index, "l'index %d se relit en %d" % [index, retour])

		print("%-6d %-26s %-26s %-26s  %s" % [index,
			_vecteur(base * Vector3.RIGHT), _vecteur(base * Vector3.UP), _vecteur(base * Vector3.BACK),
			cle])

	# 1 et 4 — le compte global.
	_dire(par_permutation.size() == 24,
		"%d rotations distinctes seulement, il en faut 24" % par_permutation.size())

	# 5. la régression sur les quatre quarts de tour autour de Y.
	print("\n── RÉGRESSION : les quatre index historiques %s ──" % str(QUARTS))
	for i in QUARTS.size():
		var base: Basis = grille.get_basis_with_orthogonal_index(QUARTS[i])
		var haut: Vector3 = base * Vector3.UP
		_dire(haut.is_equal_approx(Vector3.UP),
			"l'index %d ne garde pas Y vers le haut (%s)" % [QUARTS[i], haut])
		var vers: Vector3 = base * Vector3.FORWARD
		var attendu: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, -i * PI / 2.0)
		_dire(vers.is_equal_approx(attendu),
			"l'index %d ne vaut pas %d quart(s) de tour horaire (%s au lieu de %s)"
				% [QUARTS[i], i, vers, attendu])
		print("   index %2d → avant = %s" % [QUARTS[i], _vecteur(vers)])

	# ⚠ LA TABLE QUI SERT VRAIMENT À LA SUITE : de la rotation VOULUE vers l'index à demander.
	print("\n── TABLE INVERSE — permutation des 8 coins → index d'orientation ──")
	print("   (c'est l'entrée du générateur de la table des 256 : elle dit QUEL numéro demander)")
	var cles: Array = par_permutation.keys()
	cles.sort()
	for cle in cles:
		print("   %s → %d" % [cle, par_permutation[cle]])

	grille.free()

	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	if _echecs == 0:
		print("VERDICT : OK — les 24 rotations du cube sont TOUTES atteignables par un GridMap.")
		print("          « Marching Blocks » peut donc tenir son pari : 256 configurations, 23 classes,")
		print("          une pièce sculptée par classe, tournée à la pose.")
	else:
		print("VERDICT : ÉCHEC — le repli par rotation ne tient pas tel quel. NE PAS écrire la table")
		print("          des 256 avant d'avoir compris ce que GridMap refuse.")
	quit(1 if _echecs > 0 else 0)


func _dire(condition: bool, quoi: String) -> void:
	if condition:
		_ok += 1
	else:
		_echecs += 1
		print("  ÉCHEC — %s" % quoi)


## Un vecteur tourné retombe-t-il sur un coin du cube (±1 sur les trois axes) ?
func _est_un_coin(w: Vector3) -> bool:
	for axe in 3:
		if absf(absf(w[axe]) - 1.0) > 0.0001:
			return false
	return true


func _en_chaine(permutation: Array) -> String:
	var morceaux: Array = []
	for p in permutation:
		morceaux.append(str(p))
	return "".join(morceaux)


func _vecteur(v: Vector3) -> String:
	return "(%.0f, %.0f, %.0f)" % [v.x, v.y, v.z]
