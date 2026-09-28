extends SceneTree
##
## SONDE — deux jeux complets sont-ils atteignables, et quel critère définit « intérieur » ?
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_deux_contextes.gd
##
## ⚠ ELLE NE MODIFIE RIEN.
##
## ── DEUX QUESTIONS QUE LES DÉCISIONS DE JORDAN RENDENT BLOQUANTES ───────────────────────────────────
##
## Jordan a choisi un bloc unique de 7³ ET deux jeux de géométrie complets. Deux jeux complets veulent
## dire 68 classes en INTÉRIEUR et 68 en EXTÉRIEUR, donc 136 récoltes distinctes. Un 7³ n'offre que 216
## sommets, et un monde d'essai de 20³ n'a réalisé que 35 classes en double contexte.
##   1. QUEL EST LE N MINIMUM ? On cherche cette fois en maximisant le DOUBLE CONTEXTE, pas les classes.
##
## ⚠ **ET LE CRITÈRE D'« INTÉRIEUR » EST SUSPECT.** Un tunnel ouvert aux deux bouts est CONNECTÉ au
## dehors : le remplissage depuis le bord le déclare donc EXTÉRIEUR, et l'on remettrait de la falaise au
## fond d'une galerie — le défaut d'aujourd'hui, retourné. D'où :
##   2. ON COMPARE DEUX CRITÈRES sur un monde qui contient un tunnel traversant :
##        (A) VIDE ENCLOS   — le vide ne communique pas avec le bord (connexité) ;
##        (B) ROCHE DESSUS  — il y a de la matière au-dessus du vide (le vocabulaire de Jordan :
##                            « sol de grotte » ≠ « sol de massif », et ce qui les sépare est le toit).
##      Le critère qui classe le tunnel en EXTÉRIEUR est disqualifié.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")

const VOISINS := [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]


func _initialize() -> void:
	print("=== SONDE — DEUX JEUX COMPLETS, ET LE BON CRITÈRE ===\n")
	_deux_le_critere()
	_un_le_n_minimum()
	quit(0)


# ── outils ──────────────────────────────────────────────────────────────────────────────────────────

func _dehors(pleines: Dictionary, n: int) -> Dictionary:
	var dehors := {}
	var pile: Array = []
	for x in n:
		for y in n:
			for z in n:
				var c := Vector3i(x, y, z)
				if pleines.has(c):
					continue
				if x == 0 or y == 0 or z == 0 or x == n - 1 or y == n - 1 or z == n - 1:
					if not dehors.has(c):
						dehors[c] = true
						pile.append(c)
	while not pile.is_empty():
		var c: Vector3i = pile.pop_back()
		for d in VOISINS:
			var q: Vector3i = c + d
			if q.x < 0 or q.y < 0 or q.z < 0 or q.x >= n or q.y >= n or q.z >= n:
				continue
			if pleines.has(q) or dehors.has(q):
				continue
			dehors[q] = true
			pile.append(q)
	return dehors


## (B) Y a-t-il de la matière AU-DESSUS de cette case vide ?
func _couverte(pleines: Dictionary, c: Vector3i, n: int) -> bool:
	for y in range(c.y + 1, n):
		if pleines.has(Vector3i(c.x, y, c.z)):
			return true
	return false


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


## Classe chaque sommet porteur selon un critère, et rend {nom: {"int": bool, "ext": bool}}.
## `critere` : "enclos" ou "dessus".
func _par_contexte(pleines: Dictionary, n: int, critere: String) -> Dictionary:
	var dehors: Dictionary = _dehors(pleines, n) if critere == "enclos" else {}
	var sortie := {}
	for vx in range(n - 1):
		for vy in range(n - 1):
			for vz in range(n - 1):
				var v := Vector3i(vx, vy, vz)
				var b: int = MB.bits(pleines, v)
				if not MB.porte_une_surface(b):
					continue
				var dedans := 0
				var dehors_n := 0
				for t in 8:
					var q: Vector3i = v + MB.COINS[t]
					if pleines.has(q):
						continue
					var est_interieur: bool
					if critere == "enclos":
						est_interieur = not dehors.has(q)
					else:
						est_interieur = _couverte(pleines, q, n)
					if est_interieur:
						dedans += 1
					else:
						dehors_n += 1
				var nom: String = MB.classer(b)["nom"]
				if not sortie.has(nom):
					sortie[nom] = {"int": false, "ext": false}
				if dedans > 0 and dehors_n == 0:
					(sortie[nom] as Dictionary)["int"] = true
				elif dehors_n > 0 and dedans == 0:
					(sortie[nom] as Dictionary)["ext"] = true
	return sortie


func _compte_deux(par: Dictionary) -> int:
	var deux := 0
	for nom in par:
		if (par[nom] as Dictionary)["int"] and (par[nom] as Dictionary)["ext"]:
			deux += 1
	return deux


# ── 2. LE CRITÈRE — un tunnel traversant les sépare ─────────────────────────────────────────────────

func _deux_le_critere() -> void:
	print("── LE CRITÈRE D'« INTÉRIEUR » : LE TUNNEL TRAVERSANT TRANCHE ──")
	var n := 12
	# Un massif plein, percé d'un tunnel de 2×2 qui le traverse d'un bord à l'autre en z.
	var pleines := {}
	for x in n:
		for y in n:
			for z in n:
				pleines[Vector3i(x, y, z)] = true
	var tunnel: Array = []
	for z in n:
		for x in [5, 6]:
			for y in [4, 5]:
				var c := Vector3i(x, y, z)
				pleines.erase(c)
				tunnel.append(c)
	# On enlève aussi le ciel : tout ce qui est au-dessus de y = 8 devient du vide ouvert.
	for x in n:
		for y in range(9, n):
			for z in n:
				pleines.erase(Vector3i(x, y, z))

	var dehors: Dictionary = _dehors(pleines, n)
	var tunnel_enclos := 0
	var tunnel_couvert := 0
	for c in tunnel:
		if not pleines.has(c):
			if not dehors.has(c):
				tunnel_enclos += 1
			if _couverte(pleines, c, n):
				tunnel_couvert += 1
	print("   un massif de %d³ percé d'un tunnel 2×2 débouchant aux DEUX bouts : %d cases de tunnel"
		% [n, tunnel.size()])
	print("     critère (A) VIDE ENCLOS  : %d / %d cases de tunnel jugées INTÉRIEUR"
		% [tunnel_enclos, tunnel.size()])
	print("     critère (B) ROCHE DESSUS : %d / %d cases de tunnel jugées INTÉRIEUR"
		% [tunnel_couvert, tunnel.size()])
	if tunnel_enclos == 0:
		print("   ⚠ VERDICT : le critère (A) déclare TOUT le tunnel extérieur — il est DISQUALIFIÉ.")
		print("     On remettrait de la paroi de falaise au fond d'une galerie.")
	print("")


# ── 1. LE N MINIMUM POUR DEUX JEUX COMPLETS ─────────────────────────────────────────────────────────

func _un_le_n_minimum() -> void:
	print("── LE N MINIMUM POUR 68 CLASSES DANS LES DEUX CONTEXTES (136 récoltes) ──")
	var cible: int = MB.pieces_a_sculpter().size()
	print("   plancher par comptage : (N−1)³ ≥ 2 × %d = %d  ⇒  N ≥ 7" % [cible, cible * 2])
	print("   critère utilisé : ROCHE DESSUS (le seul qui survive au tunnel)\n")
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	print("   N   sommets   classes   en INTÉRIEUR   en EXTÉRIEUR   dans les DEUX")
	for n in [7, 8, 9, 10]:
		var meilleur := -1
		var meilleur_pleines := {}
		for essai in 2:
			var pleines := {}
			for x in n:
				for y in n:
					for z in n:
						pleines[Vector3i(x, y, z)] = true
			var score: int = _compte_deux(_par_contexte(pleines, n, "dessus"))
			for pas in 700:
				var p := Vector3i(rng.randi_range(0, n - 1), rng.randi_range(0, n - 1),
					rng.randi_range(0, n - 1))
				var avait: bool = pleines.has(p)
				if avait:
					pleines.erase(p)
				else:
					pleines[p] = true
				var ok: bool = not pleines.is_empty() and _connexe(pleines)
				var s2: int = _compte_deux(_par_contexte(pleines, n, "dessus")) if ok else -1
				if ok and s2 >= score:
					score = s2
				else:
					if avait:
						pleines[p] = true
					else:
						pleines.erase(p)
			if score > meilleur:
				meilleur = score
				meilleur_pleines = pleines.duplicate()
		var par: Dictionary = _par_contexte(meilleur_pleines, n, "dessus")
		var ints := 0
		var exts := 0
		for nom in par:
			if (par[nom] as Dictionary)["int"]:
				ints += 1
			if (par[nom] as Dictionary)["ext"]:
				exts += 1
		print("   %d   %7d   %7d   %12d   %12d   %d / %d%s"
			% [n, (n - 1) * (n - 1) * (n - 1), par.size(), ints, exts, meilleur, cible,
				"   ← DEUX JEUX COMPLETS" if meilleur >= cible else ""])
	print("\n   ⚠ PLANCHER, pas plafond : une recherche aveugle sous contrainte de connexité trouve")
	print("     moins qu'un bloc conçu. Un « 40/68 » ne prouve pas que 68 soit hors d'atteinte ;")
	print("     il prouve seulement que le hasard ne l'a pas trouvé à cette taille.")
