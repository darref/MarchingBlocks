extends RefCounted
## LA COULEUR DE LA LUMIÈRE — trois bits, donc huit couleurs.
##
## Rouge, vert et bleu sont des BITS : le jaune est rouge + vert, le violet rouge + bleu, le cyan
## vert + bleu, le blanc les trois. C'est ce qui rend les vitres LOGIQUES sans une table à écrire :
## une vitre ne garde que ce qu'elle laisse passer (un ET). Un blanc derrière une vitre rouge sort
## rouge, un bleu derrière la même vitre ne sort plus du tout, et deux vitres empilées se composent
## toutes seules — jaune puis cyan donne vert.
##
## ⚠ PROPOSÉ, ET ISOLÉ EXPRÈS : une cible réagit à la couleur EXACTE d'un faisceau, faisceau par
## faisceau. Un blanc ne fait pas fondre la glace, un violet n'allume pas un œil jaune, et un rouge
## et un bleu qui frappent la même cible ne s'additionnent pas en violet. Ce qu'on voit est vrai : un
## trait rouge touche la glace, la glace fond. Le jour où la règle change (« le blanc contient le
## rouge »), c'est `convient()` qui change, et rien d'autre.

const NOIR := 0
const ROUGE := 1
const VERT := 2
const JAUNE := 3
const BLEU := 4
const VIOLET := 5
const CYAN := 6
const BLANC := 7

const NOMS := ["NOIR", "ROUGE", "VERT", "JAUNE", "BLEU", "VIOLET", "CYAN", "BLANC"]


## Ce qui sort d'une vitre `filtre` quand `couleur` y entre. NOIR : plus rien ne sort.
static func filtrer(couleur: int, filtre: int) -> int:
	return couleur & filtre


## Une cible qui attend `attendue` réagit-elle à un faisceau `recue` ?
static func convient(recue: int, attendue: int) -> bool:
	return recue == attendue


static func nom(couleur: int) -> String:
	return NOMS[couleur]
