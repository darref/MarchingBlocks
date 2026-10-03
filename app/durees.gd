extends RefCounted
##
## CE QUE DURE CHAQUE GESTE — DEMANDÉ PAR JORDAN (3 octobre 2026 : « il y a encore la majorité des moments où quelque
## chose se fait en durant sans qu'une barre de progression se montre »).
##
## Un travail fait sur le fil principal GÈLE l'écran : on ne peut montrer une barre qu'AVANT lui. Il faut donc SAVOIR
## qu'il sera long. Cette table l'apprend : chaque geste (un bouton, une touche, un clic dans la vue — une CLÉ) est
## chronométré ; ce qu'il a duré, rapporté à la taille du monde, prédit la fois suivante. Elle s'enregistre dans les
## réglages : ce qu'une session a appris sert à la suivante.
##
## PUR : aucun nœud, aucun fichier — l'écran (`editor.gd`) la nourrit et la lit.

## Au-delà, on montre la barre (Jordan, 1er octobre 2026 : « dans tout processus qui dépasse 0,4 s »).
const SEUIL := 0.4
## En dessous, une première mesure n'est pas retenue (la table ne garde que ce qui compte).
const NEGLIGEABLE := 0.1
## La part de la nouvelle mesure dans la moyenne : un geste qui a changé de coût se corrige en deux ou trois fois.
const POIDS_NEUF := 0.5
## Un monde vide n'est pas gratuit : la taille comptée a un plancher.
const TAILLE_DE_BASE := 1000

## {clé: secondes par (taille + TAILLE_DE_BASE)}
var par_unite := {}


## Ce que le geste `cle` devrait durer sur un monde de `taille` cases (0 s'il n'est pas connu).
func prevoir(cle: String, taille: int) -> float:
	return float(par_unite.get(cle, 0.0)) * float(maxi(taille, 0) + TAILLE_DE_BASE)


func doit_montrer(cle: String, taille: int) -> bool:
	return prevoir(cle, taille) >= SEUIL


## Ce que le geste `cle` a duré, sur un monde de `taille` cases.
func apprendre(cle: String, secondes: float, taille: int) -> void:
	var u := secondes / float(maxi(taille, 0) + TAILLE_DE_BASE)
	if not par_unite.has(cle):
		if secondes < NEGLIGEABLE:
			return
		par_unite[cle] = u
		return
	par_unite[cle] = lerpf(float(par_unite[cle]), u, POIDS_NEUF)


func vers_dictionnaire() -> Dictionary:
	return par_unite.duplicate()


func depuis_dictionnaire(d: Variant) -> void:
	par_unite.clear()
	if d is Dictionary:
		for k in d:
			if (d[k] is float or d[k] is int) and float(d[k]) > 0.0:
				par_unite[str(k)] = float(d[k])
