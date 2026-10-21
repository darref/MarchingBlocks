extends RefCounted
## UNE PRÉFORME — le modèle de chaque fichier de `app/preshapes/<famille>/` (l'atelier Preshape, la 1.1.0).
##
## Une forme est un algorithme PUR : ses facteurs et une graine → des cases (`bati.gd`). Rien d'autre : pas d'écran, pas
## de monde. L'atelier dessine lui-même ses curseurs depuis `facteurs()` ; ajouter une forme = un fichier, inscrit dans
## `catalogue.gd`.
##
## Un facteur : {"cle", "nom" (à l'écran, anglais), "mini", "maxi", "defaut", "pas" (1 : entier), "aide" (une ligne)} ;
## ou un choix : {"cle", "nom", "choix": [libellés], "defaut": indice, "aide"} ; ou une case à cocher : "bool": true.
## Les tailles sont en CASES.

const Bati := preload("res://app/preshapes/bati.gd")

var id := ""
var nom := ""
var famille := ""
var aide := ""


func facteurs() -> Array:
	return []


## Les PACKS d'un clic : [[nom, {clé: valeur}], …] — les facteurs absents gardent leur défaut.
func packs() -> Array:
	return []


func construire(_v: Dictionary, _b: Bati, _rng: RandomNumberGenerator) -> void:
	pass


static func f(cle: String, nom_: String, mini: float, maxi: float, defaut: float, aide_: String, pas := 1.0) -> Dictionary:
	return {"cle": cle, "nom": nom_, "mini": mini, "maxi": maxi, "defaut": defaut, "pas": pas, "aide": aide_}


static func choix(cle: String, nom_: String, libelles: Array, defaut: int, aide_: String) -> Dictionary:
	return {"cle": cle, "nom": nom_, "choix": libelles, "defaut": defaut, "aide": aide_}


static func coche(cle: String, nom_: String, defaut: bool, aide_: String) -> Dictionary:
	return {"cle": cle, "nom": nom_, "bool": true, "defaut": defaut, "aide": aide_}


## Un bruit de valeur lisse et déterministe, dans [−1, 1] (la graine de la forme le règle).
static func bruit(rng: RandomNumberGenerator, frequence: float, octaves := 3) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = rng.randi()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = frequence
	n.fractal_octaves = octaves
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	return n


## Un point d'une courbe de Bézier quadratique de (0,0) à (longueur, 0), pliée de `pli` (en cases) en son milieu — le
## tracé des formes « le long d'une courbe » (chaîne, rempart, aqueduc).
static func courbe(t: float, longueur: float, pli: float) -> Vector2:
	var a := Vector2(-longueur * 0.5, 0)
	var m := Vector2(0, pli * 2.0)
	var b := Vector2(longueur * 0.5, 0)
	return a.lerp(m, t).lerp(m.lerp(b, t), t)


## La tangente unitaire de `courbe` en t.
static func tangente(t: float, longueur: float, pli: float) -> Vector2:
	var d := courbe(minf(t + 0.01, 1.0), longueur, pli) - courbe(maxf(t - 0.01, 0.0), longueur, pli)
	return d.normalized() if d.length() > 0.0 else Vector2.RIGHT
