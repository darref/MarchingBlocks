extends SceneTree
##
## SONDE — quelle part des sommets tombe dans le cas « MIXTE », et que doit-on en faire ?
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/UnderMend \
##       --script res://DEV_TOOLS/sonde_bouche_de_grotte.gd
##
## ⚠ ELLE NE MODIFIE RIEN.
##
## ── LE CRITÈRE EST ARRÊTÉ, MAIS IL LAISSE UN TROU ───────────────────────────────────────────────────
##
## Mesuré : « ROCHE AU-DESSUS » est le seul critère STABLE entre l'échelle du bloc maître (7³) et celle
## du monde peint — 0 sommet sur 108 change d'avis, contre 11 % pour l'occlusion du ciel. C'est donc lui
## qu'on retient, et son défaut (le dessous d'un surplomb compte comme intérieur) est un choix d'art
## défendable, pas une panne.
##
## ⚠ **MAIS IL Y A UN TROISIÈME CAS QUE JE N'AI PAS CHIFFRÉ.** Un sommet dont CERTAINES cases vides sont
## coiffées et d'autres non — une BOUCHE DE GROTTE — n'est ni intérieur ni extérieur. Le pinceau devra
## pourtant poser une tuile et une seule.
##
##   • s'ils sont rares, c'est un cas limite avec une valeur par défaut ;
##   • s'ils sont nombreux, toutes les entrées de grotte tombent dans une zone indéfinie et le plan
##     binaire ne tient pas.
##
## ── CE QU'ELLE MESURE ───────────────────────────────────────────────────────────────────────────────
##
## Sur un monde réaliste (relief irrégulier + galeries qui débouchent au jour), la part des sommets
## INTÉRIEUR / EXTÉRIEUR / MIXTE, et la part des mixtes qui touchent une classe EXTÉRIEURE POSSIBLE —
## car pour les 46 classes structurellement intérieures, la question ne se pose même pas : il n'existe
## qu'une variante, et le mixte se résout tout seul.

const MB := preload("res://addons/undermend/marching_blocks.gd")

const N := 26
const VOISINS := [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]


func _initialize() -> void:
	print("=== SONDE — LA BOUCHE DE GROTTE ===\n")
	var rng := RandomNumberGenerator.new()
	rng.seed = 606

	# ── UN MONDE RÉALISTE : un relief irrégulier, creusé de galeries qui DÉBOUCHENT au jour ─────────
	var pleines := {}
	var hauteurs := {}
	for x in N:
		for z in N:
			hauteurs[Vector2i(x, z)] = 10 + rng.randi_range(0, 5)
	# on lisse un peu, pour un relief et non un bruit
	for passe in 2:
		var neuf := {}
		for x in N:
			for z in N:
				var somme := 0
				var combien := 0
				for dx in range(-1, 2):
					for dz in range(-1, 2):
						var k := Vector2i(x + dx, z + dz)
						if hauteurs.has(k):
							somme += int(hauteurs[k])
							combien += 1
				neuf[Vector2i(x, z)] = int(round(float(somme) / float(combien)))
		hauteurs = neuf
	for x in N:
		for z in N:
			for y in range(0, int(hauteurs[Vector2i(x, z)])):
				pleines[Vector3i(x, y, z)] = true

	# ⚠ **DES GALERIES QUI DÉBOUCHENT AU JOUR — MA PREMIÈRE VERSION N'EN CREUSAIT AUCUNE.**
	# Elle partait de y = 3 à 8, sous un relief haut de 10 à 15 : les galeries étaient ENTIÈREMENT
	# enterrées, et leurs sorties tombaient sur le bord vertical du monde, qui n'est pas une ouverture
	# vers le ciel. La sonde lisait alors « 0 % de mixte » — l'absence de bouche, pas une propriété du
	# modèle. On part donc d'une case de SURFACE et l'on s'enfonce.
	var galeries := 0
	for g in 5:
		var sx: int = rng.randi_range(2, N - 3)
		var sz: int = rng.randi_range(2, N - 3)
		var p := Vector3i(sx, int(hauteurs[Vector2i(sx, sz)]) - 1, sz)
		for pas in 70:
			for dy in [0, 1]:
				pleines.erase(p + Vector3i(0, dy, 0))
			galeries += 1
			var d: Vector3i = VOISINS[rng.randi_range(0, 5)]
			if rng.randf() < 0.35:
				d = Vector3i(0, -1, 0)   # biais vers le bas : on s'enfonce plutôt qu'on ne remonte
			var q: Vector3i = p + d
			if q.x >= 1 and q.z >= 1 and q.y >= 2 and q.x < N - 1 and q.z < N - 1 \
				and q.y <= int(hauteurs[Vector2i(q.x, q.z)]):
				p = q

	print("   monde %d³ : %d cases pleines, relief lissé, %d pas de galerie depuis les flancs\n"
		% [N, pleines.size(), galeries])

	# ── LES CLASSES EXTÉRIEURES POSSIBLES (calcul exact, comme mesuré plus tôt) ─────────────────────
	var ext_possible := {}
	for c in MB.classes():
		if not MB.porte_une_surface(c["bits"]):
			continue
		var ok := true
		for t in MB.BAS:
			if (c["bits"] & (1 << int(t))) == 0 and (c["bits"] & (1 << (int(t) + 2))) != 0:
				ok = false
				break
		if ok:
			ext_possible[c["nom"]] = true

	var couverte: Dictionary = _couverture(pleines)

	# ⚠ LE GARDE-FOU : la sonde vérifie SA PROPRE PRÉMISSE avant de conclure. Une « bouche » est une
	# case vide COIFFÉE ayant un voisin vide NON coiffé. Sans aucune bouche, le monde ne peut pas
	# produire de sommet mixte, et « 0 % » ne mesurerait que cette absence.
	var bouches := 0
	for c in couverte:
		var cc: Vector3i = c
		for d in VOISINS:
			var q: Vector3i = cc + d
			if q.x < 0 or q.y < 0 or q.z < 0 or q.x >= N or q.y >= N or q.z >= N:
				continue
			if not pleines.has(q) and not couverte.has(q):
				bouches += 1
				break
	print("   cases de BOUCHE (vide coiffé touchant un vide à ciel ouvert) : %d" % bouches)
	if bouches == 0:
		print("\n   ⚠⚠ INSTRUMENT INVALIDE : ce monde ne contient aucune bouche de grotte, donc aucun")
		print("       sommet mixte ne PEUT y naître. Aucun pourcentage n'est publié.")
		quit(1)
		return

	var compte := {"int": 0, "ext": 0, "mixte": 0}
	var mixte_a_variante := 0
	var mixte_sans_variante := 0
	for vx in range(N - 1):
		for vy in range(N - 1):
			for vz in range(N - 1):
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
				var etat := "mixte"
				if couv > 0 and libre == 0:
					etat = "int"
				elif libre > 0 and couv == 0:
					etat = "ext"
				compte[etat] = int(compte[etat]) + 1
				if etat == "mixte":
					# ⚠ Le mixte ne pose un VRAI problème que si la classe a deux variantes.
					if ext_possible.has(MB.classer(b)["nom"]):
						mixte_a_variante += 1
					else:
						mixte_sans_variante += 1

	var total: int = int(compte["int"]) + int(compte["ext"]) + int(compte["mixte"])
	print("   sur %d sommets porteurs :" % total)
	print("     INTÉRIEUR : %6d  (%.1f %%)" % [compte["int"], 100.0 * float(compte["int"]) / float(total)])
	print("     EXTÉRIEUR : %6d  (%.1f %%)" % [compte["ext"], 100.0 * float(compte["ext"]) / float(total)])
	print("     MIXTE     : %6d  (%.1f %%)" % [compte["mixte"], 100.0 * float(compte["mixte"]) / float(total)])
	print("\n   parmi les MIXTES :")
	print("     %d appartiennent à une classe qui a DEUX variantes  → il faut trancher" % mixte_a_variante)
	print("     %d à une classe structurellement intérieure         → aucune ambiguïté, une seule tuile"
		% mixte_sans_variante)
	var part: float = 100.0 * float(mixte_a_variante) / float(total)
	print("\n   ⚠ LA VRAIE ZONE INDÉFINIE EST DONC DE %.1f %% DES SOMMETS." % part)
	print("     Sous quelques pour cent, une valeur par défaut suffit (et « intérieur » est le choix")
	print("     prudent : une roche d'ombre à l'air libre se remarque moins qu'une roche lessivée")
	print("     au fond d'une galerie). Au-delà, il faudra que le peintre puisse corriger à la main.")
	quit(0)


func _couverture(pleines: Dictionary) -> Dictionary:
	var couverte := {}
	for x in N:
		for z in N:
			var vu := false
			for y in range(N - 1, -1, -1):
				var c := Vector3i(x, y, z)
				if pleines.has(c):
					vu = true
				elif vu:
					couverte[c] = true
	return couverte
