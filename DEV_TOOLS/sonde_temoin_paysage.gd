extends SceneTree

## SONDE — LE PREMIER TÉMOIN, CELUI QUI DOIT RESSEMBLER AU MONDE.
##
## ⚠ **ELLE NE CONÇOIT RIEN : elle MESURE une silhouette écrite à la main**, d'après la description que
## Jordan a donnée le 25 septembre 2026 — « essentiellement ce qui se trouve le plus dans le monde, des
## massifs, une grotte toute simple d'un côté du bloc, un tunnel sur un autre côté, une arche simple
## au-dessus d'un massif, un trou vertical sur un des massifs ».
##
## ⚠ **LA FORME APPARTIENT À JORDAN (charte §2, « la main tient la FORME »).** Ce fichier est un
## BROUILLON soumis à son œil, pas une décision : tant qu'il ne l'a pas vue en image, elle ne va nulle
## part. Ce que la sonde apporte, c'est le chiffre qui manque à l'œil — ce que ce témoin couvre, et
## surtout ce qu'il LAISSE, puisque c'est exactement la charge du second témoin.
##
## ⚠ **ET ELLE NE DIT PAS SI LE TÉMOIN EST LISIBLE.** « Un compteur vert ne dit jamais qu'une tuile est
## à sa place » (charte §6) : la lisibilité est le SEUL but de ce premier bloc, et c'est la seule chose
## qu'aucun nombre ici ne peut trancher.

const MB := preload("res://addons/marching_blocks_plugin_godot/marching_blocks.gd")

const COTE := 8

## ⚠ `COUCHES[y][z]` est une rangée de 8 caractères indexée par x. y = 0 est le BAS.
##
## Le relief, en clair :
##   • y0        — le socle, plein ;
##   • x 0-2, z 2-4, y 1-2   — LA GROTTE, ouverte sur la face ouest (x = 0) ;
##   • x 6, y 1, tout z      — LE TUNNEL, traversant du nord (z = 0) au sud (z = 7) ;
##   • x 2, z 6, y 1-4       — LE PUITS, du plateau jusqu'au socle ;
##   • x 4, y 3+             — le val qui sépare les deux massifs ;
##   • x 5-7, jusqu'à y 3    — le massif EST, bas ;
##   • x 0-3, jusqu'à y 4    — le massif OUEST, haut, coiffé de L'ARCHE (x 1, z 1-4, y 5-7).
const COUCHES := [
	[   # y = 0 — le socle
		"########",
		"########",
		"########",
		"########",
		"########",
		"########",
		"########",
		"########",
	],
	[   # y = 1 — la grotte (ouest), le tunnel (x 6), le fond du puits (x 2, z 6)
		"######.#",
		"######.#",
		"...###.#",
		"...###.#",
		"...###.#",
		"######.#",
		"##.###.#",
		"######.#",
	],
	[   # y = 2 — la grotte se poursuit, le tunnel est coiffé
		"########",
		"########",
		"...#####",
		"...#####",
		"...#####",
		"########",
		"##.#####",
		"########",
	],
	[   # y = 3 — le plafond de la grotte, et le val s'ouvre en x = 4
		"####.###",
		"####.###",
		"####.###",
		"####.###",
		"####.###",
		"####.###",
		"##.#.###",
		"####.###",
	],
	[   # y = 4 — le plateau du massif ouest ; le massif est s'arrête plus bas
		"####....",
		"####....",
		"####....",
		"####....",
		"####....",
		"####....",
		"##.#....",
		"####....",
	],
	[   # y = 5 — la crête, percée en x = 1 : c'est l'ouverture de l'arche
		"##......",
		"##......",
		"#.......",
		"#.......",
		"##......",
		"##......",
		"##......",
		"##......",
	],
	[   # y = 6 — les deux pieds de l'arche
		"........",
		".#......",
		"........",
		"........",
		".#......",
		"........",
		"........",
		"........",
	],
	[   # y = 7 — la travée qui les relie
		"........",
		".#......",
		".#......",
		".#......",
		".#......",
		"........",
		"........",
		"........",
	],
]


func _initialize() -> void:
	print("=== LE TÉMOIN PAYSAGE (brouillon, soumis à l'œil de Jordan) ===")
	var pleines: Dictionary = _lire()
	if pleines.is_empty():
		quit(1)
		return
	print("   %d cases pleines sur %d  ·  %d morceau(x) de matière"
		% [pleines.size(), COTE * COTE * COTE, _morceaux(pleines)])

	var plafond: int = MB.plafond_de(pleines)
	var nus := {}
	var variantes := {}
	var n_int := 0
	var n_ext := 0
	for vx in range(COTE - 1):
		for vy in range(COTE - 1):
			for vz in range(COTE - 1):
				var v := Vector3i(vx, vy, vz)
				var b: int = MB.bits(pleines, v)
				if not MB.porte_une_surface(b):
					continue
				var nom: String = MB.classer(b)["nom"]
				if MB.exterieur_possible(b) and MB.sous_le_ciel(pleines, v, plafond):
					variantes[nom] = true
					n_ext += 1
				else:
					nus[nom] = true
					n_int += 1

	var total_int: int = MB.pieces_a_sculpter().size()
	var total_ext: int = MB.classes_exterieures().size()
	print("   INTÉRIEUR %d/%d   EXTÉRIEUR %d/%d   TOTAL %d/%d"
		% [nus.size(), total_int, variantes.size(), total_ext,
			nus.size() + variantes.size(), total_int + total_ext])
	print("   sommets : %d sous roche, %d sous le ciel" % [n_int, n_ext])

	# ⚠ **C'EST LA SORTIE QUI COMPTE VRAIMENT** : ce que ce témoin laisse est la charge EXACTE du
	# second. Sans cette liste, le second témoin se dessinerait à l'aveugle — ou pire, redonderait le
	# premier en croyant compléter.
	var reste_int: Array = []
	for nom in MB.pieces_a_sculpter():
		if not nus.has(nom):
			reste_int.append(nom)
	var reste_ext: Array = []
	for nom in MB.classes_exterieures():
		if not variantes.has(nom):
			reste_ext.append(nom)
	print("\n── CE QUE LE SECOND TÉMOIN DEVRA PORTER ──")
	print("   %d classe(s) d'intérieur, %d variante(s) d'extérieur — %d tuiles en tout"
		% [reste_int.size(), reste_ext.size(), reste_int.size() + reste_ext.size()])
	print("   intérieur : %s" % str(reste_int))
	print("   extérieur : %s" % str(reste_ext))
	quit(0)


## ⚠ Refuse une couche mal formée plutôt que de la deviner — une rangée trop courte décalerait
## silencieusement tout le relief en x.
func _lire() -> Dictionary:
	var pleines := {}
	if COUCHES.size() != COTE:
		print("⚠ %d couches au lieu de %d" % [COUCHES.size(), COTE])
		return {}
	for y in COUCHES.size():
		var rangees: Array = COUCHES[y]
		if rangees.size() != COTE:
			print("⚠ couche y=%d : %d rangées au lieu de %d" % [y, rangees.size(), COTE])
			return {}
		for z in rangees.size():
			var rangee: String = rangees[z]
			if rangee.length() != COTE:
				print("⚠ couche y=%d rangée z=%d : %d caractères au lieu de %d"
					% [y, z, rangee.length(), COTE])
				return {}
			for x in rangee.length():
				if rangee[x] == "#":
					pleines[Vector3i(x, y, z)] = true
	return pleines


## Le nombre de morceaux de matière, par faces. ⚠ Jordan veut un objet d'un seul tenant : une arche
## dont la travée flotte serait un bloc en deux morceaux, et rien d'autre ne le dirait.
func _morceaux(pleines: Dictionary) -> int:
	var vus := {}
	var combien := 0
	for depart in pleines:
		if vus.has(depart):
			continue
		combien += 1
		var pile: Array = [depart]
		vus[depart] = true
		while not pile.is_empty():
			var p: Vector3i = pile.pop_back()
			for d in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN,
					Vector3i.FORWARD, Vector3i.BACK]:
				var q: Vector3i = p + d
				if pleines.has(q) and not vus.has(q):
					vus[q] = true
					pile.append(q)
	return combien
