@tool
extends RefCounted
## LES OPÉRATIONS D'ÉTAGE — étendre vers le haut, vers le bas, élargir, creuser.
##
## ⚠ **ELLES VIVENT ICI PARCE QU'ELLES ONT EU DEUX LECTEURS** : l'ancien écran de greffon Godot (supprimé
## le 28 septembre 2026, l'appli le remplace) et le logiciel MarchingBlocks (`app/`). Chacun écrivait sa copie,
## c'était la divergence annoncée (charte §6, « une seconde description d'un même fait diverge
## toujours »). La règle est pure : elle lit des cases, elle rend ce qu'il faut poser et effacer, et
## chaque appelant l'applique avec SON historique d'annulation.

const VOISINES := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
## Les six sens de « face » — l'ordre départage une égalité : le haut d'abord, comme « Extend up ».
const SIX_SENS := [Vector3i.UP, Vector3i.DOWN, Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1),
	Vector3i(0, 0, -1)]


## `occupees` — {Vector3i: true}. Rend {"poser": {Vector3i: true}, "effacer": {Vector3i: true}}.
## `portee` — les cases sur lesquelles on opère. VIDE (le défaut, et le greffon) : toutes celles de
## l'étage. Sinon la SÉLECTION de l'appli (charte §5) : c'est la même opération, sur un autre ensemble —
## pas une seconde règle.
static func operer(occupees: Dictionary, etage: int, quoi: String, portee: Dictionary = {}) -> Dictionary:
	var a_poser := {}
	var a_effacer := {}
	match quoi:
		"haut", "bas":
			var pas := Vector3i.UP if quoi == "haut" else Vector3i.DOWN
			for c in occupees:
				var p: Vector3i = c
				if _dans(p, etage, portee) and not occupees.has(p + pas):
					a_poser[p + pas] = true
		"elargir":
			# ⚠ Une couronne dans le PLAN, pas en hauteur : extruder vers le haut, c'est « étendre ».
			for c in occupees:
				var p: Vector3i = c
				if not _dans(p, etage, portee):
					continue
				for d in VOISINES:
					if not occupees.has(p + d):
						a_poser[p + d] = true
		"creuser":
			# ⚠ Évider, pas effacer : on ne retire que ce qui est entouré, donc le pourtour reste. La
			# gomme fait déjà « effacer », ce bouton n'aurait aucune raison d'être sinon.
			for c in occupees:
				var p: Vector3i = c
				if not _dans(p, etage, portee):
					continue
				var entoure := true
				for d in VOISINES:
					if not occupees.has(p + d):
						entoure = false
						break
				if entoure:
					a_effacer[p] = true
		"face":
			# ⚠ **ÉTENDRE DANS LE SENS OÙ L'ON REGARDE — DEMANDÉ PAR JORDAN (29 septembre 2026)** : « dans le
			# sens opposé de la matière du monde ». Une case est TOURNÉE vers d devant du vide (p + d) et
			# adossée à la matière (p − d). Le sens retenu est celui où le plus de cases sont tournées ;
			# on recopie alors d'une case, comme « haut » et « bas » — un mur choisi s'épaissit vers
			# l'air, un plafond de grotte descend, un sol monte. UN seul sens pour tout l'ensemble : une
			# case par face libre ferait une couronne, c'est-à-dire « élargir » en trois dimensions.
			var meilleur := Vector3i.ZERO
			var compte_meilleur := 0
			for d in SIX_SENS:
				var n := 0
				for c in occupees:
					var p: Vector3i = c
					if _dans(p, etage, portee) and not occupees.has(p + d) and occupees.has(p - d):
						n += 1
				if n > compte_meilleur:
					compte_meilleur = n
					meilleur = d
			if meilleur != Vector3i.ZERO:
				for c in occupees:
					var p: Vector3i = c
					if _dans(p, etage, portee) and not occupees.has(p + meilleur):
						a_poser[p + meilleur] = true
			# ⚠ **LA SÉLECTION SUIT L'EXTENSION — DEMANDÉ PAR JORDAN (30 septembre 2026)** : cliquer en
			# continu, comme Extrude ↑ ↓. Elle est portée d'une case dans le sens retenu, donc sur le
			# nouveau front, adossé à l'ancien : le clic suivant retrouve le même sens et recommence.
			# Toute la sélection se déplace, cases vides comprises — c'est ELLE qui est « allée là ».
			var suivie := {}
			for c in portee:
				suivie[c + meilleur] = true
			return {"poser": a_poser, "effacer": a_effacer, "sens": meilleur, "selection": suivie}
	return {"poser": a_poser, "effacer": a_effacer}


## EXTRUDE — UNE OPÉRATION AU LIEU DE DEUX (Jordan, 2 octobre 2026 : « Extend up / down de Shape operations et
## Extrude ↑ / ↓ de Selection, on ne sait pas lequel fait quoi » — c'était une redondance : mêmes cases posées, mêmes
## icônes ; seul Extrude suivait, et seulement sur une sélection). `quoi` : "haut", "bas" ou "face" (le sens où le
## plus de cases regardent l'air, adossées à la matière — la règle de `operer("face")`). La BASE est la sélection,
## sinon la matière de l'étage `etage`. `mode` (Jordan : « Maj étend et Alt décale ») :
##   "poser"   — pose une case devant chaque case PLEINE de la base, là où c'est vide ; la sélection (s'il y en a une)
##               avance d'un cran, cases vides comprises : on reclique pour continuer ;
##   "etendre" — ne pose rien : la sélection devient la base PLUS la base décalée d'un cran (cases vides comprises) ;
##   "decaler" — ne pose rien : la sélection devient la base décalée d'un cran.
## Rend {"poser", "effacer", "selection", "sens"} ; l'appelant fait suivre l'étage de `sens.y`. Sens nul (une face que
## rien ne regarde) : rien ne change.
static func extruder(occupees: Dictionary, etage: int, quoi: String, selection: Dictionary, mode: String) -> Dictionary:
	var base := selection
	if base.is_empty():
		base = {}
		for c in occupees:
			if (c as Vector3i).y == etage:
				base[c] = true
	var sens := Vector3i.ZERO
	match quoi:
		"haut":
			sens = Vector3i.UP
		"bas":
			sens = Vector3i.DOWN
		"face":
			sens = operer(occupees, etage, "face", selection).get("sens", Vector3i.ZERO)
	var rendu := {"poser": {}, "effacer": {}, "selection": selection, "sens": sens}
	if sens == Vector3i.ZERO or base.is_empty():
		rendu["sens"] = Vector3i.ZERO
		return rendu
	var decalee := {}
	for c in base:
		decalee[(c as Vector3i) + sens] = true
	match mode:
		"etendre":
			var etendue := base.duplicate()
			etendue.merge(decalee)
			rendu["selection"] = etendue
		"decaler":
			rendu["selection"] = decalee
		_:
			for c in base:
				var p: Vector3i = (c as Vector3i) + sens
				if occupees.has(c) and not occupees.has(p):
					rendu["poser"][p] = true
			rendu["selection"] = decalee if not selection.is_empty() else {}
	return rendu


static func _dans(p: Vector3i, etage: int, portee: Dictionary) -> bool:
	return portee.has(p) if not portee.is_empty() else p.y == etage
