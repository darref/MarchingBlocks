extends SceneTree
##
## SONDE — quel critère sépare VRAIMENT un intérieur d'un extérieur ?
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/UnderMend \
##       --script res://DEV_TOOLS/sonde_critere_ciel.gd
##
## ⚠ ELLE NE MODIFIE RIEN.
##
## ── DEUX CRITÈRES ONT DÉJÀ ÉCHOUÉ, CHACUN SUR UN CAS RÉEL ───────────────────────────────────────────
##
##   (A) VIDE ENCLOS (connexité)  — échoue sur le TUNNEL TRAVERSANT : mesuré 0 case sur 48 jugée
##       intérieure, alors qu'une galerie est évidemment un intérieur. On remettrait de la falaise au
##       fond d'un tunnel.
##   (B) ROCHE AU-DESSUS          — échoue sur le SURPLOMB EN PLEIN AIR et le dessous d'une ARCHE :
##       il y a de la roche dessus, donc il les déclare intérieurs, alors qu'on est dehors.
##
## ⚠ **UN CRITÈRE QUI SE TROMPE SUR UN CAS QUE LE PLUGIN DOIT SAVOIR PEINDRE N'EST PAS UN DÉTAIL DE
## RÉGLAGE : c'est le défaut n°2 qui revient, simplement déplacé.**
##
## ── LE TROISIÈME : LA VISIBILITÉ DU CIEL ────────────────────────────────────────────────────────────
##
## On lance des rayons depuis la case vide dans l'hémisphère supérieur et l'on compte ceux qui
## s'échappent sans rencontrer de matière. Au fond d'un tunnel, aucun ; sous un surplomb, on voit du
## ciel DE CÔTÉ. C'est une grandeur CONTINUE, donc réglable par un seuil — et c'est ce qu'on vérifie :
## existe-t-il un seuil qui sépare les trois cas d'un coup ?
##
## ⚠ ON CONSTRUIT LES TROIS CAS DANS LA MÊME GRILLE, et non trois grilles séparées : un critère jugé
## sur des scènes différentes se juge sur des éclairages différents. C'est la leçon mesurée du projet —
## « un rendu de contrôle doit reproduire le CONTEXTE, pas seulement la pièce ».

const N := 24
## Les directions de l'hémisphère supérieure, en entiers : on prend toutes les combinaisons de
## −2..2 × 0..2 × −2..2, ce qui donne un échantillonnage grossier mais isotrope et sans trigonométrie.
var _directions: Array = []


func _initialize() -> void:
	print("=== SONDE — LE CRITÈRE DU CIEL ===\n")
	for dx in range(-2, 3):
		for dy in range(0, 3):
			for dz in range(-2, 3):
				if dx == 0 and dy == 0 and dz == 0:
					continue
				_directions.append(Vector3(dx, dy, dz).normalized())
	print("   %d directions échantillonnées dans l'hémisphère supérieure\n" % _directions.size())

	var pleines := {}
	# ── LE DÉCOR : un massif qui occupe la moitié basse, avec trois accidents ───────────────────────
	for x in N:
		for z in N:
			for y in range(0, 12):
				pleines[Vector3i(x, y, z)] = true

	# 1. UN TUNNEL TRAVERSANT, profond : 2×2, à y = 4-5, débouchant aux deux bouts en z.
	var tunnel: Array = []
	for z in N:
		for x in [11, 12]:
			for y in [4, 5]:
				var c := Vector3i(x, y, z)
				pleines.erase(c)
				tunnel.append(c)

	# 2. UN SURPLOMB EN PLEIN AIR : on creuse une encoche dans le flanc x = 0..3, à y = 10-11, en
	#    laissant une dalle au-dessus (y = 12 reste plein sur cette bande).
	var surplomb: Array = []
	for x in range(0, 4):
		for z in range(4, 20):
			for y in [10, 11]:
				var c := Vector3i(x, y, z)
				pleines.erase(c)
				surplomb.append(c)
	for x in range(0, 4):
		for z in range(4, 20):
			pleines[Vector3i(x, 12, z)] = true   # la dalle du surplomb

	# 3. LE PLEIN AIR : les cases juste au-dessus du plateau, là où rien ne coiffe.
	var plein_air: Array = []
	for x in range(8, 20):
		for z in range(4, 20):
			var c := Vector3i(x, 13, z)
			if not pleines.has(c):
				plein_air.append(c)

	print("   décor unique de %d³ : %d cases de tunnel, %d de surplomb, %d de plein air"
		% [N, tunnel.size(), surplomb.size(), plein_air.size()])

	print("\n   cas            ciel vu (moyenne)   roche dessus   vide enclos")
	_mesurer("tunnel", tunnel, pleines)
	_mesurer("surplomb", surplomb, pleines)
	_mesurer("plein air", plein_air, pleines)

	print("\n   ⚠ VERDICT ATTENDU : si « tunnel » voit ~0 % de ciel et « surplomb » nettement plus,")
	print("     alors un SEUIL sur la visibilité du ciel sépare les trois cas, là où (A) et (B)")
	print("     échouent chacun sur l'un d'eux. Sinon, aucun critère simple ne suffit et il faudra")
	print("     que le peintre puisse corriger à la main.")
	quit(0)


func _mesurer(quoi: String, cases: Array, pleines: Dictionary) -> void:
	var somme := 0.0
	var dessus := 0
	for c in cases:
		somme += _ciel(c, pleines)
		if _roche_dessus(c, pleines):
			dessus += 1
	var moyenne: float = somme / maxf(1.0, float(cases.size()))
	print("   %-12s   %14.1f %%   %5d / %-5d  %s"
		% [quoi, moyenne * 100.0, dessus, cases.size(), "(non mesuré ici)"])


## La fraction des directions de l'hémisphère supérieure par lesquelles on s'échappe de la grille.
func _ciel(depart: Vector3i, pleines: Dictionary) -> float:
	var libres := 0
	for d in _directions:
		var dir: Vector3 = d
		var p := Vector3(depart) + Vector3(0.5, 0.5, 0.5)
		var echappe := true
		for pas in N * 2:
			p += dir * 0.5
			var c := Vector3i(floori(p.x), floori(p.y), floori(p.z))
			if c.x < 0 or c.y < 0 or c.z < 0 or c.x >= N or c.y >= N or c.z >= N:
				break
			if pleines.has(c):
				echappe = false
				break
		if echappe:
			libres += 1
	return float(libres) / float(_directions.size())


func _roche_dessus(c: Vector3i, pleines: Dictionary) -> bool:
	for y in range(c.y + 1, N):
		if pleines.has(Vector3i(c.x, y, c.z)):
			return true
	return false
