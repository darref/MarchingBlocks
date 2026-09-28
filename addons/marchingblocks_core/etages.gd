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
	return {"poser": a_poser, "effacer": a_effacer}


static func _dans(p: Vector3i, etage: int, portee: Dictionary) -> bool:
	return portee.has(p) if not portee.is_empty() else p.y == etage
