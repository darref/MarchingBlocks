extends RefCounted
## LA MISE EN PAGE DE L'ÉCRAN PARTAGÉ — un seul nombre : la position du SÉPARATEUR.
##
## ⚠ PUR : pas de `Node`, pas de rendu, pas d'horloge. Le client donne le temps écoulé et ce qu'il sait
## du joueur, il reçoit une position de séparateur. Tout ce qui décide de ce qu'on voit se teste donc
## sans écran (DEV_TOOLS/test_mise_en_page.gd).
##
## La surface est toujours À GAUCHE, la grotte toujours À DROITE (charte §3). Trois positions :
##   640  surface seule
##   480  surface, près d'une entrée ou pendant qu'un événement de grotte est montré
##   160  dans une grotte — la surface ne quitte jamais l'écran sous terre
## Passer de l'une à l'autre ne permute rien : le séparateur GLISSE.
##
## ⚠ TOUT EST EN PIXELS DE BASE, et la base a DOUBLÉ le 16 septembre 2026 : 640×320, cases de 32, parce
## que le lot de tuiles acheté est en 32×32. Le compte de CASES à l'écran n'a pas bougé (20 × 10), ni le
## 2:1, ni l'agrandissement entier (×2 en 1280, ×3 en 1920, ×4 en 1440p, ×6 en 4K).

const LARGEUR := 640
const HAUTEUR := 320
const CASE := 32

const SURFACE_SEULE := 640
const PRES_ENTREE := 480
const SOUS_TERRE := 160

## PROPOSÉ — en CASES, jamais en pixels. La bande s'ouvre à RAYON_ENTREE d'une entrée et ne se referme
## qu'au-delà de RAYON_ENTREE + MARGE_ENTREE : sans cet écart, un joueur qui longe le seuil ferait
## balayer l'écran en boucle.
const RAYON_ENTREE := 3.0
const MARGE_ENTREE := 1.0

## PROPOSÉ — à régler à l'œil avec Jordan.
const DUREE_BALAYAGE := 0.3
## PROPOSÉ — ce que la bande reste ouverte après le dernier événement montré.
const MAINTIEN := 0.5

## PROPOSÉ — deux fois la base : en dessous, le pixel art n'est plus lisible.
const FENETRE_MIN := Vector2i(1280, 640)

var proche := false
var balayage := Balayage.new(SURFACE_SEULE, SOUS_TERRE, SURFACE_SEULE)
var evenements := FileEvenements.new()


## Un événement de résolution rendu par `Monde.resoudre()`, à montrer dans la bande pendant `duree`
## secondes. ⚠ Ne sert qu'en surface : sous terre, la file est vidée à la prochaine avancée (OUVERT,
## charte §3 — par défaut, rien ne bouge).
func signaler(grille: int, pos: Vector2i, duree: float) -> void:
	evenements.ajouter(grille, pos, duree)


## Une image. `distance_entree` : distance en cases à l'entrée la plus proche (INF s'il n'y en a pas) ;
## ignorée sous terre.
func avancer(delta: float, sous_terre: bool, distance_entree: float) -> void:
	if sous_terre:
		evenements.vider()  # PROPOSÉ : descendre, c'est choisir de regarder la grotte où l'on est
	else:
		proche = proche_entree(proche, distance_entree)
	balayage.viser(cible(sous_terre, proche, evenements.en_cours()))
	balayage.avancer(delta)
	# ⚠ L'horloge d'un événement ne tourne que bande OUVERTE : pendant le balayage d'ouverture, le joueur
	# ne le voit pas encore, et le temps qu'il doit le voir ne s'use pas.
	evenements.avancer(delta, not sous_terre and not balayage.en_mouvement())


func pixel() -> int:
	return balayage.pixel()


# ── les règles, une fonction chacune ────────────────────────────────────────────────────────────────

static func cible(sous_terre: bool, pres_d_une_entree: bool, evenement_montre: bool) -> int:
	if sous_terre:
		return SOUS_TERRE
	if pres_d_une_entree or evenement_montre:
		return PRES_ENTREE
	return SURFACE_SEULE


static func proche_entree(etait_proche: bool, distance: float) -> bool:
	return distance <= (RAYON_ENTREE + MARGE_ENTREE if etait_proche else RAYON_ENTREE)


## `pos` en cases (flottantes), `entrees` des cases entières. La plus proche gagne ; à égalité, la
## première de la liste — jamais l'ordre de mise à jour. {"index": -1, "distance": INF} si aucune.
static func entree_la_plus_proche(pos: Vector2, entrees: Array) -> Dictionary:
	var meilleure := {"index": -1, "distance": INF}
	for i in entrees.size():
		var centre := Vector2(entrees[i]) + Vector2(0.5, 0.5)
		var d := pos.distance_to(centre)
		if d < meilleure["distance"]:
			meilleure = {"index": i, "distance": d}
	return meilleure


## Où chaque caméra doit placer le joueur (ou sa projection) : au milieu de la partie VISIBLE de sa vue.
## x = surface, y = grotte, en pixels de sa vue. Quand le séparateur glisse, les caméras glissent avec.
static func centres(separateur: int) -> Vector2i:
	return Vector2i(separateur / 2, separateur + (LARGEUR - separateur) / 2)


## ⚠ Une vue entièrement cachée cesse de se rendre — mais se remet à rendre dès que la CIBLE la montre,
## sans attendre le premier pixel : sinon sa première colonne visible serait une image périmée.
static func grotte_rendue(separateur: int, cible_: int) -> bool:
	return separateur < LARGEUR or cible_ < LARGEUR


static func surface_rendue(separateur: int, cible_: int) -> bool:
	return separateur > 0 or cible_ > 0


## La taille 2:1 d'une fenêtre que l'utilisateur étire vers `demandee` depuis `precedente`. C'est la
## dimension qu'il a le plus changée qui commande (une case de hauteur vaut deux de largeur) : tirer le
## bord droit élargit, tirer le bas rehausse. ⚠ Idempotente — la taille rendue, redemandée, se rend
## elle-même : sinon recaler la fenêtre relancerait un recalage, à l'infini.
static func taille_fenetre(demandee: Vector2i, precedente: Vector2i, minimum: Vector2i = FENETRE_MIN,
		maximum: Vector2i = Vector2i(1 << 30, 1 << 30)) -> Vector2i:
	var dw := absi(demandee.x - precedente.x)
	var dh := absi(demandee.y - precedente.y)
	var h: int = demandee.y if 2 * dh > dw else demandee.x / 2
	var h_min := maxi(minimum.y, (minimum.x + 1) / 2)
	var h_max := maxi(h_min, mini(maximum.y, maximum.x / 2))  # un écran trop petit : le plancher gagne
	h = clampi(h, h_min, h_max)
	return Vector2i(2 * h, h)


# ── le balayage ─────────────────────────────────────────────────────────────────────────────────────

## Un nombre qui glisse vers sa cible en `duree` secondes, départ et arrivée adoucis, INTERRUPTIBLE.
##
## Chaque trajet est une courbe d'Hermite : il part de la position ET de la vitesse courantes, et arrive
## à vitesse nulle. Changer de cible en plein mouvement ne fait donc ni saut de position ni à-coup de
## vitesse, et ne crée aucun objet. La position est une FONCTION du temps écoulé, pas une intégration :
## à 30 ou à 240 images par seconde, le séparateur est au même endroit au même instant.
##
## ⚠ Un élan trop fort VERS une cible proche la dépasserait (la courbe reste monotone tant que
## élan × durée ≤ 3 × écart). Il est plafonné : le séparateur ne dépasse jamais sa cible.
class Balayage:
	var duree: float
	var borne_min: float
	var borne_max: float
	var position: float
	var cible: float
	var _depart: float
	var _elan := 0.0
	var _temps: float

	func _init(depart: float, min_: float, max_: float, duree_: float = DUREE_BALAYAGE) -> void:
		position = depart
		cible = depart
		_depart = depart
		borne_min = min_
		borne_max = max_
		duree = duree_
		_temps = duree_

	func viser(nouvelle: float) -> void:
		if nouvelle == cible:
			return
		var elan := vitesse()
		var ecart := nouvelle - position
		if ecart == 0.0:
			elan = 0.0
		elif elan * duree / ecart > 3.0:
			elan = 3.0 * ecart / duree
		_depart = position
		_elan = elan
		cible = nouvelle
		_temps = 0.0

	func avancer(delta: float) -> void:
		if _temps >= duree:
			position = cible
			return
		_temps = minf(_temps + delta, duree)
		if _temps >= duree:
			position = cible
			return
		var s := _temps / duree
		var s2 := s * s
		var s3 := s2 * s
		var p := _depart * (2.0 * s3 - 3.0 * s2 + 1.0) + duree * _elan * (s3 - 2.0 * s2 + s) \
				+ cible * (3.0 * s2 - 2.0 * s3)
		position = clampf(p, borne_min, borne_max)

	## En unités par seconde.
	func vitesse() -> float:
		if _temps >= duree:
			return 0.0
		var s := _temps / duree
		var s2 := s * s
		return (_depart * (6.0 * s2 - 6.0 * s) + duree * _elan * (3.0 * s2 - 4.0 * s + 1.0) \
				+ cible * (6.0 * s - 6.0 * s2)) / duree

	func en_mouvement() -> bool:
		return _temps < duree

	## ⚠ Quantifié au pixel de base : l'agrandissement entier garde le trait net.
	func pixel() -> int:
		return roundi(position)


# ── les événements montrés ──────────────────────────────────────────────────────────────────────────

## Les événements de grotte à montrer, DANS L'ORDRE où `resoudre()` les a rendus — la fonte, puis
## l'allumage. Chacun a sa durée ; la bande reste ouverte tant qu'il en reste, puis le temps d'un MAINTIEN.
## PROPOSÉ (OUVERT, charte §3) : des événements de grottes différentes passent l'un après l'autre.
class FileEvenements:
	var _file: Array = []  # {"grille", "case", "duree"}
	var _ecoule := 0.0
	var _maintien := 0.0

	func ajouter(grille: int, pos: Vector2i, duree: float) -> void:
		_file.append({"grille": grille, "case": pos, "duree": duree})

	## `visible` : la bande est ouverte. Fermée, seul le maintien s'use.
	func avancer(delta: float, visible: bool) -> void:
		if _file.is_empty():
			_maintien = maxf(_maintien - delta, 0.0)
			return
		if not visible:
			return
		_ecoule += delta
		while not _file.is_empty() and _ecoule >= _file[0]["duree"]:
			_ecoule -= _file[0]["duree"]
			_file.pop_front()
		if _file.is_empty():
			_maintien = maxf(MAINTIEN - _ecoule, 0.0)
			_ecoule = 0.0

	func en_cours() -> bool:
		return not _file.is_empty() or _maintien > 0.0

	## L'événement montré, avec sa progression de 0 à 1 — {} pendant le maintien ou s'il n'y en a pas.
	func courant() -> Dictionary:
		if _file.is_empty():
			return {}
		var e: Dictionary = _file[0].duplicate()
		e["progression"] = _ecoule / e["duree"] if e["duree"] > 0.0 else 1.0
		return e

	func vider() -> void:
		_file.clear()
		_ecoule = 0.0
		_maintien = 0.0
