extends SceneTree
##
## SONDE — deux corrections à mes propres instruments.
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_bloc_et_ciel.gd
##
## ⚠ ELLE NE MODIFIE RIEN.
##
## ── 1. LA COUVERTURE AVEC LA CONNEXITÉ IMPOSÉE ──────────────────────────────────────────────────────
##
## `sonde_partition_contexte.gd` a trouvé 90/90 dès 8³ — mais en affichant `connexe = NON`. La
## connexité n'était mesurée qu'À LA FIN, pas imposée pendant la montée de colline : la couverture était
## donc atteinte par une POUSSIÈRE DE MORCEAUX, ce qui ne répond pas à « un seul grand bloc maître ».
## ⚠ **Une contrainte qu'on vérifie après coup n'est pas une contrainte.** On l'impose ici à chaque coup.
##
## ── 2. LE CIEL, SANS L'HORIZON ──────────────────────────────────────────────────────────────────────
##
## `sonde_critere_ciel.gd` échantillonnait `dy` de 0 à 2 — donc des directions HORIZONTALES. Un tunnel
## traversant s'échappe alors le long de son propre axe et lit 9 % de « ciel » au lieu de ~0 %, ce qui
## resserre l'écart avec le surplomb (25,6 %) jusqu'à rendre tout seuil fragile.
## ⚠ **Le ciel se regarde vers le HAUT.** On exige donc `dy ≥ 1`, et l'on voit si la séparation s'ouvre.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")

const VOISINS := [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]


func _initialize() -> void:
	print("=== SONDE — BLOC CONNEXE, ET LE CIEL SANS L'HORIZON ===\n")
	_deux_le_ciel()
	_un_le_bloc_connexe()
	quit(0)


# ── 2. LE CIEL SANS L'HORIZON ───────────────────────────────────────────────────────────────────────

func _deux_le_ciel() -> void:
	print("── LE CIEL, HORIZON EXCLU (dy ≥ 1) ──")
	var n := 24
	var directions: Array = []
	for dx in range(-2, 3):
		for dy in range(1, 3):          # ⚠ LA CORRECTION : plus aucune direction horizontale.
			for dz in range(-2, 3):
				directions.append(Vector3(dx, dy, dz).normalized())
	print("   %d directions, toutes strictement montantes" % directions.size())

	var pleines := {}
	for x in n:
		for z in n:
			for y in range(0, 12):
				pleines[Vector3i(x, y, z)] = true
	var tunnel: Array = []
	for z in n:
		for x in [11, 12]:
			for y in [4, 5]:
				var c := Vector3i(x, y, z)
				pleines.erase(c)
				tunnel.append(c)
	var surplomb: Array = []
	for x in range(0, 4):
		for z in range(4, 20):
			for y in [10, 11]:
				var c := Vector3i(x, y, z)
				pleines.erase(c)
				surplomb.append(c)
	for x in range(0, 4):
		for z in range(4, 20):
			pleines[Vector3i(x, 12, z)] = true
	var plein_air: Array = []
	for x in range(8, 20):
		for z in range(4, 20):
			var c := Vector3i(x, 13, z)
			if not pleines.has(c):
				plein_air.append(c)

	print("\n   cas            ciel vu (moyenne)   min      max")
	for paire in [["tunnel", tunnel], ["surplomb", surplomb], ["plein air", plein_air]]:
		var cases: Array = paire[1]
		var somme := 0.0
		var mini_v := 1.0
		var maxi_v := 0.0
		for c in cases:
			var v: float = _ciel(c, pleines, directions, n)
			somme += v
			mini_v = minf(mini_v, v)
			maxi_v = maxf(maxi_v, v)
		print("   %-12s   %14.1f %%   %5.1f %%   %5.1f %%"
			% [paire[0], somme / float(cases.size()) * 100.0, mini_v * 100.0, maxi_v * 100.0])
	print("\n   ⚠ Si « tunnel » tombe vers 0 et que « surplomb » reste franchement au-dessus, un seuil")
	print("     unique sépare les trois cas — là où la connexité et « roche dessus » échouent chacun.\n")


func _ciel(depart: Vector3i, pleines: Dictionary, directions: Array, n: int) -> float:
	var libres := 0
	for d in directions:
		var dir: Vector3 = d
		var p := Vector3(depart) + Vector3(0.5, 0.5, 0.5)
		var echappe := true
		for pas in n * 3:
			p += dir * 0.5
			var c := Vector3i(floori(p.x), floori(p.y), floori(p.z))
			if c.x < 0 or c.y < 0 or c.z < 0 or c.x >= n or c.y >= n or c.z >= n:
				break
			if pleines.has(c):
				echappe = false
				break
		if echappe:
			libres += 1
	return float(libres) / float(directions.size())


# ── 1. LE BLOC CONNEXE ──────────────────────────────────────────────────────────────────────────────

func _couverture(pleines: Dictionary, n: int) -> Dictionary:
	var couverte := {}
	for x in n:
		for z in n:
			var vu := false
			for y in range(n - 1, -1, -1):
				var c := Vector3i(x, y, z)
				if pleines.has(c):
					vu = true
				elif vu:
					couverte[c] = true
	return couverte


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


func _contextes(pleines: Dictionary, n: int) -> Dictionary:
	var couverte: Dictionary = _couverture(pleines, n)
	var dedans := {}
	var dehors := {}
	for vx in range(n - 1):
		for vy in range(n - 1):
			for vz in range(n - 1):
				var v := Vector3i(vx, vy, vz)
				var b: int = MB.bits(pleines, v)
				if not MB.porte_une_surface(b):
					continue
				var couv := 0
				var libre := 0
				for t in 8:
					var q: Vector3i = v + MB.COINS[t]
					if pleines.has(q):
						continue
					if couverte.has(q):
						couv += 1
					else:
						libre += 1
				var nom: String = MB.classer(b)["nom"]
				if couv > 0 and libre == 0:
					dedans[nom] = true
				elif libre > 0 and couv == 0:
					dehors[nom] = true
	return {"int": dedans, "ext": dehors}


func _amorce(n: int, rng: RandomNumberGenerator) -> Dictionary:
	var pleines := {}
	for x in n:
		for z in n:
			var h: int = rng.randi_range(n / 2, n - 2)
			for y in range(0, h + 1):
				pleines[Vector3i(x, y, z)] = true
	for galerie in 3:
		var p := Vector3i(rng.randi_range(1, n - 2), rng.randi_range(1, n / 2),
			rng.randi_range(1, n - 2))
		for pas in n * 4:
			pleines.erase(p)
			var q: Vector3i = p + VOISINS[rng.randi_range(0, 5)]
			if q.x >= 1 and q.z >= 1 and q.y >= 1 and q.x < n - 1 and q.z < n - 1 and q.y < n / 2 + 1:
				p = q
	return pleines


func _un_le_bloc_connexe() -> void:
	print("── LA COUVERTURE AVEC LA CONNEXITÉ IMPOSÉE À CHAQUE COUP ──")
	var total: int = MB.pieces_a_sculpter().size()
	var vise_ext := 0
	for c in MB.classes():
		if not MB.porte_une_surface(c["bits"]):
			continue
		var ok := true
		for t in MB.BAS:
			if (c["bits"] & (1 << int(t))) == 0 and (c["bits"] & (1 << (int(t) + 2))) != 0:
				ok = false
				break
		if ok:
			vise_ext += 1
	print("   objectif : %d en INTÉRIEUR, %d en EXTÉRIEUR, soit %d tuiles"
		% [total, vise_ext, total + vise_ext])
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	print("")
	print("   N   sommets   INTÉRIEUR   EXTÉRIEUR   total   connexe")
	# ⚠ ON DESCEND JUSQU'À 6 : recommander 8³ sans avoir testé 7³ avec la BONNE méthode ferait
	# sculpter un bloc plus gros que nécessaire. La seule évaluation de 7³ jusqu'ici venait de
	# l'amorce aveugle, avec un autre objectif.
	for n in [7]:
		var meilleur := -1
		var m_int := 0
		var m_ext := 0
		for essai in 8:
			var pleines: Dictionary = _amorce(n, rng)
			if not _connexe(pleines):
				continue
			var c: Dictionary = _contextes(pleines, n)
			var score: int = (c["int"] as Dictionary).size() + (c["ext"] as Dictionary).size()
			for pas in 2000:
				var p := Vector3i(rng.randi_range(0, n - 1), rng.randi_range(0, n - 1),
					rng.randi_range(0, n - 1))
				var avait: bool = pleines.has(p)
				if avait:
					pleines.erase(p)
				else:
					pleines[p] = true
				# ⚠ LA CONTRAINTE EST IMPOSÉE, PAS CONSTATÉE : tout coup qui casse l'unicité du
				# morceau est rejeté sur le champ.
				var ok: bool = not pleines.is_empty() and _connexe(pleines)
				var c2: Dictionary = _contextes(pleines, n) if ok else {}
				var s2: int = -1
				if ok:
					s2 = (c2["int"] as Dictionary).size() + (c2["ext"] as Dictionary).size()
				if ok and s2 >= score:
					score = s2
					c = c2
				else:
					if avait:
						pleines[p] = true
					else:
						pleines.erase(p)
			if score > meilleur:
				meilleur = score
				m_int = (c["int"] as Dictionary).size()
				m_ext = (c["ext"] as Dictionary).size()
		print("   %2d   %7d   %6d/%d   %6d/%d   %3d/%d   %s"
			% [n, (n - 1) * (n - 1) * (n - 1), m_int, total, m_ext, vise_ext,
				meilleur, total + vise_ext,
				"oui — UN SEUL BLOC" if meilleur >= total + vise_ext else "oui (incomplet)"])
	print("\n   ⚠ PLANCHER : un bloc CONÇU fera mieux qu'une montée de colline de 500 pas.")
