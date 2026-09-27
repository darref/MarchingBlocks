extends SceneTree

## SONDE — COMPLÉTER LE TROU PLUTÔT QUE REFUSER LE GESTE : ce que ça coûte en matière.
##
## ⚠ **L'IDÉE EST DE JORDAN (25 septembre 2026)** : « au lieu de mettre dans un état rouge quand un
## creusement n'est pas carré, on pourrait le résoudre en ne faisant qu'un trou solo quand on creuse une
## fois, puis si on creuse à côté on complète le trou pour qu'il soit carré ».
##
## ⚠ **LE DÉCLENCHEUR N'EST PAS L'ADJACENCE, C'EST LA DIAGONALE.** Deux trous solo en (0,0) et (1,1) ne
## sont pas adjacents et produisent pourtant un contact diagonal. La règle appliquée ici est donc : quand
## un carré 2×2 (dans l'un des trois plans) montre exactement DEUX vides EN DIAGONALE, on vide les deux
## cases restantes. C'est le même prédicat que `sonde_monde_sans_diagonale.gd` — le pinceau appliquerait
## exactement la règle qui définit le monde, pas une approximation.
##
## ⚠ **CE QUE CETTE SONDE CHERCHE : LA CASCADE.** Compléter un carré peut créer une diagonale ailleurs,
## qui se complète à son tour. La terminaison est acquise — on ne fait que RETIRER de la matière, donc
## la suite est strictement décroissante et bornée. Ce qui n'est pas acquis, c'est l'AMPLEUR : si un clic
## creuse la moitié du massif, l'idée est morte quelle que soit son élégance.
##
## ⚠ **ELLE NE DIT PAS SI LE GESTE EST AGRÉABLE.** Un creusement qui emporte trois cases au lieu d'une
## peut être une bonne surprise ou une trahison ; ça se juge à la main, dans l'éditeur, avec Jordan.

## ⚠ **LA RÈGLE A DÉMÉNAGÉ DANS `marching_blocks.gd` (25 septembre 2026), et cette sonde l'appelle au
## lieu de la porter.** Elle l'avait écrite en premier, mais trois appelants en dépendent désormais — le
## vérificateur, cette sonde, et le pinceau. ⚠ Le contrôle qui valide le déménagement : cette sonde doit
## rendre EXACTEMENT les mêmes nombres qu'avant (×1,70 au hasard, ×1,00 sur les gestes contigus, ×2,67
## sur l'escalier). « Une extraction qui change sa sortie n'est pas une extraction » (charte §6).
const MB := preload("res://addons/marching_blocks_plugin_godot/marching_blocks.gd")

const COTE := 10
const CREUSEMENTS := 60

## Les trois plans, chacun donné par ses deux vecteurs de bord.
const PLANS := [
	[Vector3i(1, 0, 0), Vector3i(0, 1, 0)],
	[Vector3i(1, 0, 0), Vector3i(0, 0, 1)],
	[Vector3i(0, 1, 0), Vector3i(0, 0, 1)],
]


func _initialize() -> void:
	print("=== COMPLÉTER LE TROU PLUTÔT QUE REFUSER — CE QUE ÇA COÛTE ===\n")
	print("massif plein de %d³ = %d cases ; %d creusements d'UNE case, au hasard\n"
		% [COTE, COTE * COTE * COTE, CREUSEMENTS])

	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var pleines := {}
	for x in COTE:
		for y in COTE:
			for z in COTE:
				pleines[Vector3i(x, y, z)] = true

	var demande := 0
	var pire := 0
	var cascades := 0
	for essai in CREUSEMENTS:
		var p := Vector3i(rng.randi_range(0, COTE - 1), rng.randi_range(0, COTE - 1),
			rng.randi_range(0, COTE - 1))
		if not pleines.has(p):
			continue
		demande += 1
		var avant: int = pleines.size()
		pleines.erase(p)
		var ajoutees: int = _completer(pleines)
		if ajoutees > 0:
			cascades += 1
		var emportees: int = avant - pleines.size()
		pire = maxi(pire, emportees)
		if emportees > 4:
			print("   ⚠ creusement en %s → %d cases emportées" % [str(p), emportees])

	var retirees: int = COTE * COTE * COTE - pleines.size()
	print("\n   %d creusement(s) demandé(s) → %d case(s) retirée(s)  ·  amplification ×%.2f"
		% [demande, retirees, float(retirees) / maxf(1.0, float(demande))])
	print("   %d creusement(s) ont déclenché une complétion  ·  le pire a emporté %d cases"
		% [cascades, pire])
	print("   il reste %d cases sur %d (%.1f %% du massif)"
		% [pleines.size(), COTE * COTE * COTE,
			100.0 * float(pleines.size()) / float(COTE * COTE * COTE)])

	# ⚠ **LE CONTRÔLE QUI COMPTE : la règle atteint-elle son but ?** Une complétion qui laisserait une
	# seule diagonale rendrait tout le reste faux — le monde ne serait pas celui qu'on croit mesurer.
	print("\n   diagonales restantes : %d  %s"
		% [_diagonales(pleines), "✓" if _diagonales(pleines) == 0 else "⚠ LA RÈGLE NE TIENT PAS"])

	_les_gestes_reels()
	quit(0)


## ⚠ **LE CHIFFRE AU HASARD EST ADVERSARIAL, ET LE PRENDRE POUR LA RÉALITÉ SERAIT LA FAUTE D'INSTRUMENT
## HABITUELLE (charte §6).** Des creusements dispersés MAXIMISENT les diagonales ; un humain creuse des
## cases contiguës — un tunnel, une salle, un puits. On mesure donc les gestes que Jordan a nommés
## lui-même, case par case comme il cliquerait, la complétion s'appliquant après CHAQUE clic.
##
## ⚠ L'escalier est là exprès : c'est le geste délibérément diagonal, donc celui qui paiera le plus. Si
## la règle doit agacer quelqu'un, c'est là — et il vaut mieux le savoir avant de la proposer.
func _les_gestes_reels() -> void:
	print("\n── LES GESTES RÉELS, case par case comme on clique ──")
	for geste in [
		{"quoi": "puits vertical 1×1, 8 de fond", "cases": _colonne(Vector3i(5, 2, 5), 8)},
		{"quoi": "tunnel 1×1, traversant", "cases": _ligne(Vector3i(5, 3, 0), Vector3i(0, 0, 1), 10)},
		{"quoi": "tunnel 2×2, traversant", "cases": _pave(Vector3i(4, 3, 0), Vector3i(2, 2, 10))},
		{"quoi": "grotte 3×3×2", "cases": _pave(Vector3i(2, 2, 2), Vector3i(3, 2, 3))},
		{"quoi": "escalier EN DIAGONALE (le pire)", "cases": _escalier(Vector3i(2, 2, 2), 6)},
	]:
		var pleines := {}
		for x in COTE:
			for y in COTE:
				for z in COTE:
					pleines[Vector3i(x, y, z)] = true
		var avant: int = pleines.size()
		var demande := 0
		var pire := 0
		for p in geste["cases"]:
			if not pleines.has(p):
				continue
			demande += 1
			var av: int = pleines.size()
			pleines.erase(p)
			_completer(pleines)
			pire = maxi(pire, av - pleines.size())
		var retirees: int = avant - pleines.size()
		print("   %-34s %2d clic(s) → %3d case(s)  ·  ×%.2f  ·  pire clic : %d"
			% [geste["quoi"], demande, retirees,
				float(retirees) / maxf(1.0, float(demande)), pire])


func _colonne(depart: Vector3i, hauteur: int) -> Array:
	return _ligne(depart, Vector3i(0, 1, 0), hauteur)


func _ligne(depart: Vector3i, pas: Vector3i, combien: int) -> Array:
	var sortie: Array = []
	for i in combien:
		sortie.append(depart + pas * i)
	return sortie


func _pave(coin: Vector3i, taille: Vector3i) -> Array:
	var sortie: Array = []
	for x in taille.x:
		for y in taille.y:
			for z in taille.z:
				sortie.append(coin + Vector3i(x, y, z))
	return sortie


## Un escalier : chaque marche décalée d'une case en x ET en y. C'est LE geste que la règle punit.
func _escalier(depart: Vector3i, marches: int) -> Array:
	var sortie: Array = []
	for i in marches:
		sortie.append(depart + Vector3i(i, i, 0))
	return sortie


## Vide les cases nécessaires jusqu'à ce qu'aucun carré 2×2 ne montre deux vides en diagonale.
## Rend le nombre de cases vidées EN PLUS du geste demandé.
##
## ⚠ **ON NE FAIT QUE RETIRER, jamais ajouter.** C'est ce qui garantit la terminaison : la matière est
## strictement décroissante et minorée. Choisir « boucher au lieu de creuser » selon le cas rendrait la
## boucle non monotone, donc potentiellement sans fin — et c'est aussi ce que Jordan a demandé, on
## COMPLÈTE le trou.
## ⚠ **BORNÉE AU CUBE, comme l'était la version que cette sonde portait elle-même.** C'est ce qui rend le
## contrôle d'extraction valide : sans la borne, la règle répare aussi les diagonales de BORDURE et rend
## 94 cases au lieu de 92 sur le même tirage. Les deux réponses sont justes — elles ne répondent pas à la
## même question. Le pinceau, lui, appellera la version NON bornée : dans un monde peint, l'extérieur est
## réellement du vide.
func _completer(pleines: Dictionary) -> int:
	return MB.completer_les_carres(pleines, COTE)


func _diagonales(pleines: Dictionary) -> int:
	var combien := 0
	for x in COTE - 1:
		for y in COTE - 1:
			for z in COTE - 1:
				var o := Vector3i(x, y, z)
				for plan in PLANS:
					var a: Vector3i = o
					var b: Vector3i = o + plan[0]
					var c: Vector3i = o + plan[1]
					var d: Vector3i = o + plan[0] + plan[1]
					if not pleines.has(a) and not pleines.has(d) \
							and pleines.has(b) and pleines.has(c):
						combien += 1
					elif not pleines.has(b) and not pleines.has(c) \
							and pleines.has(a) and pleines.has(d):
						combien += 1
	return combien
