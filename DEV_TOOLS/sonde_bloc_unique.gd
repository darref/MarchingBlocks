extends SceneTree
##
## SONDE — le bloc maître UNIQUE est-il meilleur, et répare-t-il le défaut de contexte ?
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_bloc_unique.gd
##
## ⚠ ELLE NE MODIFIE RIEN.
##
## ⚠ **SA PREMIÈRE VERSION A MENTI, ET LA FAUTE EST ÉCRITE ICI PLUTÔT QUE CORRIGÉE EN SILENCE.** Elle
## partait d'un remplissage ALÉATOIRE i.i.d. puis sautait l'essai s'il n'était pas 6-connexe. Or un
## tirage dense n'est presque jamais connexe d'un seul morceau : aucun essai ne démarrait pour N=6 ni
## N=8, et la sonde imprimait « 0 / 68 » pour les deux tout en trouvant « 68 / 68 » pour N=7.
## ⚠ **LE TELL EST LA NON-MONOTONIE** : un bloc de 8³ contient un 7³, donc il atteint au moins autant.
## Un résultat non monotone en N accuse l'INSTRUMENT, jamais la géométrie.
## On part donc du cube PLEIN — connexe par construction — et on CREUSE en maintenant la connexité.
##
## CE QU'ELLE MESURE
##   1. LA DISTRIBUTION DES GERMES sur les neuf blocs : les 28 germes sont tous présents et tous
##      appariés (mesuré ailleurs). Le risque n'est donc pas « un raccord invisible » mais « le MÊME
##      raccord sculpté à N endroits, dans M fichiers, sans rien qui force qu'ils soient identiques ».
##   2. UN BLOC UNIQUE CONNEXE : un seul objet sculptable, et ce qu'il coûte en germes.
##   3. LE CONTEXTE DÉDUIT : si le bloc contient un vide ENCLOS, « intérieur » et « extérieur » se
##      déduisent par remplissage depuis le bord — et les classes à double contexte peuvent livrer
##      DEUX variantes, au lieu d'une liste écrite à la main (5 déclarées, 10 mesurées).

const MB := preload("res://addons/marching_blocks_plugin_godot/marching_blocks.gd")
const BM := preload("res://addons/marching_blocks_plugin_godot/blocs_maitres.gd")

const VOISINS := [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

## Combien de cases de vide enclos on cherche au minimum : une grotte, pas une bulle.
const GROTTE_VOULUE := 10


func _initialize() -> void:
	print("=== SONDE — LE BLOC UNIQUE ===\n")
	_un_distribution_des_germes()
	_deux_bloc_connexe()
	quit(0)


# ── outils partagés ─────────────────────────────────────────────────────────────────────────────────

func _canoniques() -> Dictionary:
	var canon := {}
	var liste: Array = []
	for face in MB.FACES:
		for m in 16:
			var pleins: Array = []
			for i in 4:
				if (m & (1 << i)) != 0:
					pleins.append(int(face["coins"][i]))
			var cle: String = MB._cle_de_germe(face["coins"], pleins)
			if canon.has(cle):
				continue
			liste.append(cle)
			canon[cle] = cle
			for r in MB.rotations_actives():
				var f2: Array = []
				for t in face["coins"]:
					f2.append(int(r["coins"][int(t)]))
				var p2: Array = []
				for t in pleins:
					p2.append(int(r["coins"][int(t)]))
				var autre: String = MB._cle_de_germe(f2, p2)
				if not canon.has(autre):
					canon[autre] = cle
	return {"canon": canon, "liste": liste}


func _porteurs(pleines: Dictionary, n: int) -> Array:
	var sortie: Array = []
	for vx in range(n - 1):
		for vy in range(n - 1):
			for vz in range(n - 1):
				var v := Vector3i(vx, vy, vz)
				if MB.porte_une_surface(MB.bits(pleines, v)):
					sortie.append(v)
	return sortie


func _classes_de(pleines: Dictionary, n: int) -> Dictionary:
	var vus := {}
	for v in _porteurs(pleines, n):
		vus[MB.classer(MB.bits(pleines, v))["nom"]] = true
	return vus


func _germes_de(pleines: Dictionary, n: int, canon: Dictionary) -> Dictionary:
	var compte := {}
	for v in _porteurs(pleines, n):
		var som: Vector3i = v
		for face in MB.FACES:
			var pleins: Array = []
			for k in 4:
				var t: int = int(face["coins"][k])
				if pleines.has(som + MB.COINS[t]):
					pleins.append(t)
			var cle: String = canon.get(MB._cle_de_germe(face["coins"], pleins), "?")
			compte[cle] = int(compte.get(cle, 0)) + 1
	return compte


func _connexe(pleines: Dictionary) -> bool:
	if pleines.is_empty():
		return false
	var depart: Vector3i = pleines.keys()[0]
	var vus := {depart: true}
	var pile: Array = [depart]
	while not pile.is_empty():
		var p: Vector3i = pile.pop_back()
		for d in VOISINS:
			var q: Vector3i = p + d
			if pleines.has(q) and not vus.has(q):
				vus[q] = true
				pile.append(q)
	return vus.size() == pleines.size()


## Les cases vides atteintes depuis l'EXTÉRIEUR du bloc. Le reste du vide est ENCLOS : c'est la grotte.
func _dehors(pleines: Dictionary, n: int) -> Dictionary:
	var dehors := {}
	var pile: Array = []
	for x in n:
		for y in n:
			for z in n:
				var p := Vector3i(x, y, z)
				if pleines.has(p):
					continue
				if x == 0 or y == 0 or z == 0 or x == n - 1 or y == n - 1 or z == n - 1:
					if not dehors.has(p):
						dehors[p] = true
						pile.append(p)
	while not pile.is_empty():
		var p: Vector3i = pile.pop_back()
		for d in VOISINS:
			var q: Vector3i = p + d
			if q.x < 0 or q.y < 0 or q.z < 0 or q.x >= n or q.y >= n or q.z >= n:
				continue
			if pleines.has(q) or dehors.has(q):
				continue
			dehors[q] = true
			pile.append(q)
	return dehors


func _enclos(pleines: Dictionary, n: int) -> int:
	return n * n * n - pleines.size() - _dehors(pleines, n).size()


# ── 1. LA DISTRIBUTION DES GERMES SUR LES NEUF BLOCS ────────────────────────────────────────────────

func _un_distribution_des_germes() -> void:
	print("── 1. COMBIEN D'ENDROITS L'ARTISTE DOIT-IL GARDER IDENTIQUES ? ──")
	var c: Dictionary = _canoniques()
	var canon: Dictionary = c["canon"]
	var total := {}
	var blocs := {}
	for i in BM.nombre():
		var g: Dictionary = _germes_de(BM.cases(i), BM.COTE, canon)
		for cle in g:
			total[cle] = int(total.get(cle, 0)) + int(g[cle])
			if not blocs.has(cle):
				blocs[cle] = {}
			(blocs[cle] as Dictionary)[i] = true
	var somme := 0
	var pire := 0
	var pire_cle := ""
	for cle in total:
		somme += int(total[cle])
		if int(total[cle]) > pire:
			pire = int(total[cle])
			pire_cle = cle
	print("   %d instances pour %d germes distincts" % [somme, total.size()])
	print("   le pire : %s — sculpté %d fois, sur %d blocs distincts"
		% [pire_cle, pire, (blocs[pire_cle] as Dictionary).size()])
	print("   ⚠ gardés seulement par une comparaison d'AIRE (`verifier_couture`), pas de SECTION.\n")


# ── 2. UN BLOC UNIQUE, CONNEXE, AVEC UNE GROTTE ─────────────────────────────────────────────────────

## Score lexicographique : d'abord les classes, ensuite la taille de la grotte (plafonnée).
func _score(pleines: Dictionary, n: int) -> Array:
	return [_classes_de(pleines, n).size(), mini(_enclos(pleines, n), GROTTE_VOULUE)]


func _mieux(a: Array, b: Array) -> bool:
	if a[0] != b[0]:
		return a[0] > b[0]
	return a[1] >= b[1]


func _deux_bloc_connexe() -> void:
	print("── 2. UN SEUL BLOC, CONNEXE, ET QUI CONTIENT UNE GROTTE ──")
	var cible: int = MB.pieces_a_sculpter().size()
	var c: Dictionary = _canoniques()
	var canon: Dictionary = c["canon"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242

	print("   les NEUF blocs de 4³ : 576 cases, 243 sommets, 1212 instances de germes, 68 classes\n")
	print("   amorce = cube PLEIN, puis on creuse en gardant la matière d'un seul morceau")
	print("   N   cases   sommets   classes   grotte   instances de germes")
	for n in [5, 6, 7, 8]:
		var meilleur_score: Array = [-1, -1]
		var meilleur: Dictionary = {}
		for essai in 3:
			# ⚠ AMORCE CONNEXE PAR CONSTRUCTION : le cube plein.
			var pleines := {}
			for x in n:
				for y in n:
					for z in n:
						pleines[Vector3i(x, y, z)] = true
			var score: Array = _score(pleines, n)
			for pas in 1400:
				var p := Vector3i(rng.randi_range(0, n - 1), rng.randi_range(0, n - 1),
					rng.randi_range(0, n - 1))
				var avait: bool = pleines.has(p)
				if avait:
					pleines.erase(p)
				else:
					pleines[p] = true
				var ok: bool = not pleines.is_empty() and _connexe(pleines)
				var s2: Array = _score(pleines, n) if ok else [-1, -1]
				if ok and _mieux(s2, score):
					score = s2
				else:
					if avait:
						pleines[p] = true
					else:
						pleines.erase(p)
			if _mieux(score, meilleur_score):
				meilleur_score = score
				meilleur = pleines.duplicate()
		var instances := 0
		if not meilleur.is_empty():
			var g: Dictionary = _germes_de(meilleur, n, canon)
			for cle in g:
				instances += int(g[cle])
		print("   %d   %5d   %7d   %d / %d   %6d   %d%s" % [n, n * n * n,
			(n - 1) * (n - 1) * (n - 1), meilleur_score[0], cible, _enclos(meilleur, n), instances,
			"   ← COMPLET et CONNEXE" if meilleur_score[0] >= cible else ""])
		if meilleur_score[0] >= cible:
			_trois_le_contexte(meilleur, n)


# ── 3. LE CONTEXTE SE DÉDUIT-IL DANS UN SEUL BLOC ? ─────────────────────────────────────────────────

func _trois_le_contexte(pleines: Dictionary, n: int) -> void:
	var dehors: Dictionary = _dehors(pleines, n)
	var par_classe := {}   # nom -> {"int": bool, "ext": bool}
	for v in _porteurs(pleines, n):
		var som: Vector3i = v
		var a_dehors := false
		var a_enclos := false
		for t in 8:
			var q: Vector3i = som + MB.COINS[t]
			if pleines.has(q):
				continue
			if dehors.has(q):
				a_dehors = true
			else:
				a_enclos = true
		var nom: String = MB.classer(MB.bits(pleines, som))["nom"]
		if not par_classe.has(nom):
			par_classe[nom] = {"int": false, "ext": false}
		if a_enclos and not a_dehors:
			(par_classe[nom] as Dictionary)["int"] = true
		elif a_dehors and not a_enclos:
			(par_classe[nom] as Dictionary)["ext"] = true

	var deux := 0
	var seulement_int := 0
	var seulement_ext := 0
	for nom in par_classe:
		var d: Dictionary = par_classe[nom]
		if d["int"] and d["ext"]:
			deux += 1
		elif d["int"]:
			seulement_int += 1
		elif d["ext"]:
			seulement_ext += 1
	print("        contexte déduit par remplissage depuis le bord :")
	print("          %d classe(s) présentes dans les DEUX contextes  → deux variantes possibles" % deux)
	print("          %d seulement en INTÉRIEUR, %d seulement en EXTÉRIEUR"
		% [seulement_int, seulement_ext])
	print("        ⚠ à comparer aux 10 classes à double contexte mesurées sur les neuf blocs.")
