extends RefCounted
## HUIT DIRECTIONS, ET LA SEULE FORMULE DE RÉFLEXION DU JEU.
##
## Une direction est un entier de 0 à 7, par pas de 45°, dans le sens trigonométrique TEL QU'ON LE
## VOIT à l'écran. La grille a son y vers le bas, donc le nord est (0, -1).
##
## Un miroir a une orientation de 0 à 7, par pas de 22,5° : c'est une LIGNE à deux faces, donc huit
## positions couvrent un demi-tour. Un rayon d'angle φ qui frappe une ligne d'angle θ repart en
## 2θ − φ ; exprimé dans ces unités, c'est `orientation − direction` — des entiers, pas un flottant.
##
## ⚠ MESURÉ (charte §4, et `test_lumiere.gd` le refait contre la géométrie vectorielle) : avec les
## seules orientations PAIRES (pas de 45°), les axes restent des axes et les diagonales restent des
## diagonales — deux familles qui ne se rencontrent jamais. Ce sont les orientations IMPAIRES qui les
## relient. C'est ce qui ordonne les deux premiers pouvoirs.

const E := 0
const NE := 1
const N := 2
const NO := 3
const O := 4
const SO := 5
const S := 6
const SE := 7

const VECTEURS := [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]


static func reflechir(direction: int, orientation: int) -> int:
	return posmod(orientation - direction, 8)


## Le rayon court le long du miroir. ⚠ PROPOSÉ : la tranche l'arrête (traceur, fin « RASANT »).
static func rasant(direction: int, orientation: int) -> bool:
	return posmod(2 * direction - orientation, 8) == 0


static func diagonale(direction: int) -> bool:
	return direction % 2 == 1
