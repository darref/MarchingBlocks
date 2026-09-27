extends SceneTree
##
## SONDE — « 10 classes à double contexte » est-il un PLAFOND, ou juste ce que nos blocs réalisent ?
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_plafond_contexte.gd
##
## ⚠ ELLE NE MODIFIE RIEN.
##
## ── LA QUESTION, ET POURQUOI ELLE DÉCIDE DE LA TAILLE DU PROJET ─────────────────────────────────────
##
## Mesuré ailleurs : les neuf blocs livrent 10 classes dans les DEUX contextes, et un bloc unique de 7³
## en livre 10 aussi. La coïncidence invite à lire « 10 » comme une propriété du modèle. ⚠ **C'est
## exactement le genre de lecture qu'il faut réfuter avant de concevoir dessus.**
##
## Le contexte n'est PAS une propriété des huit bits : c'est une propriété GLOBALE — le vide autour du
## sommet communique-t-il avec le dehors, ou est-il enclos ? Or n'importe quelle configuration peut être
## rendue enclose en ajoutant de la matière plus loin, sans toucher à ses huit cellules. Si c'est juste,
## les 68 classes peuvent TOUTES apparaître dans les deux contextes, et un jeu à deux contextes demande
## jusqu'à 136 tuiles — pas 78.
##
## ── ⚠ SA PREMIÈRE VERSION S'EST TROMPÉE, ET LA FAUTE RESTE ÉCRITE ICI ───────────────────────────────
##
## Elle érodait 30 % de TOUTE case de surface, six tours de suite, sur une grille de 14³. L'érosion a
## traversé la marge de 3 cases et **débouché dans la cavité** : le vide enclos est tombé à ZÉRO, donc
## il n'existait plus aucun contexte intérieur, et la sonde a imprimé « 0 dans les deux contextes ».
## Ce zéro mesurait l'érosion, pas le modèle.
##
## ⚠ **D'OÙ LE CONTRÔLE DE VALIDITÉ CI-DESSOUS : si le vide enclos est nul, la sonde REFUSE de publier
## des comptes de classes.** Une sonde qui ne vérifie pas sa propre prémisse ne mesure pas son sujet ;
## et un instrument muet sur sa propre panne est pire qu'une absence de mesure.
##
## Les trois corrections : grille 20³ (un cœur profond existe), cavité confinée à 6 cases du bord,
## érosion confinée à la CROÛTE externe (distance ≤ 3), jamais au-delà.

const MB := preload("res://addons/marching_blocks_plugin_godot/marching_blocks.gd")

const N := 20
## La cavité vit entre ces bornes : 6 cases de matière la séparent du bord, quoi que fasse l'érosion.
const CŒUR_MIN := 6
const CŒUR_MAX := 13
## L'érosion ne touche que les cases à cette distance du bord ou moins.
const CROUTE := 3

const VOISINS := [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]


func _initialize() -> void:
	print("=== SONDE — LE PLAFOND DU DOUBLE CONTEXTE ===\n")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260924

	var pleines := {}
	for x in N:
		for y in N:
			for z in N:
				pleines[Vector3i(x, y, z)] = true

	# 1. UNE CAVITÉ ENCLOSE, irrégulière, au cœur — confinée loin du bord.
	var dedans := 0
	var p := Vector3i(N / 2, N / 2, N / 2)
	for pas in 2500:
		if pleines.has(p):
			pleines.erase(p)
			dedans += 1
		var q: Vector3i = p + VOISINS[rng.randi_range(0, 5)]
		if q.x >= CŒUR_MIN and q.y >= CŒUR_MIN and q.z >= CŒUR_MIN \
			and q.x <= CŒUR_MAX and q.y <= CŒUR_MAX and q.z <= CŒUR_MAX:
			p = q

	# 2. UN EXTÉRIEUR ÉRODÉ, irrégulier — confiné à la croûte.
	var dehors_creuse := 0
	for tour in 5:
		var a_retirer: Array = []
		for c in pleines:
			var cc: Vector3i = c
			var d_bord: int = mini(mini(cc.x, cc.y), mini(cc.z,
				mini(N - 1 - cc.x, mini(N - 1 - cc.y, N - 1 - cc.z))))
			if d_bord > CROUTE:
				continue   # ⚠ LA CORRECTION : on ne ronge JAMAIS au-delà de la croûte.
			var expose := d_bord == 0
			if not expose:
				for d in VOISINS:
					if not pleines.has(cc + d):
						expose = true
						break
			if expose and rng.randf() < 0.35:
				a_retirer.append(cc)
		for c in a_retirer:
			pleines.erase(c)
			dehors_creuse += 1

	print("   grille %d³ = %d cases : %d pleines, %d creusées au cœur, %d rongées dans la croûte"
		% [N, N * N * N, pleines.size(), dedans, dehors_creuse])

	# 3. Le DEHORS par remplissage depuis le bord.
	var dehors := {}
	var pile: Array = []
	for x in N:
		for y in N:
			for z in N:
				var c := Vector3i(x, y, z)
				if pleines.has(c):
					continue
				if x == 0 or y == 0 or z == 0 or x == N - 1 or y == N - 1 or z == N - 1:
					if not dehors.has(c):
						dehors[c] = true
						pile.append(c)
	while not pile.is_empty():
		var c: Vector3i = pile.pop_back()
		for d in VOISINS:
			var q2: Vector3i = c + d
			if q2.x < 0 or q2.y < 0 or q2.z < 0 or q2.x >= N or q2.y >= N or q2.z >= N:
				continue
			if pleines.has(q2) or dehors.has(q2):
				continue
			dehors[q2] = true
			pile.append(q2)
	var enclos: int = N * N * N - pleines.size() - dehors.size()
	print("   vide ouvert sur le dehors : %d cases ; vide ENCLOS (la grotte) : %d cases"
		% [dehors.size(), enclos])

	# ⚠ LE CONTRÔLE DE VALIDITÉ — la sonde vérifie sa propre prémisse avant de conclure.
	if enclos <= 0:
		print("\n   ⚠⚠ INSTRUMENT INVALIDE : sans vide enclos, il n'existe AUCUN contexte intérieur,")
		print("       donc « 0 classe dans les deux contextes » ne mesurerait que cette panne.")
		print("       Aucun compte de classes n'est publié. L'érosion a dû déboucher dans la cavité.")
		quit(1)
		return
	print("")

	# 4. Chaque sommet récolté, classé par contexte.
	var par_classe := {}
	for vx in range(N - 1):
		for vy in range(N - 1):
			for vz in range(N - 1):
				var v := Vector3i(vx, vy, vz)
				var b: int = MB.bits(pleines, v)
				if not MB.porte_une_surface(b):
					continue
				var a_dehors := false
				var a_enclos := false
				for t in 8:
					var q3: Vector3i = v + MB.COINS[t]
					if pleines.has(q3):
						continue
					if dehors.has(q3):
						a_dehors = true
					else:
						a_enclos = true
				var nom: String = MB.classer(b)["nom"]
				if not par_classe.has(nom):
					par_classe[nom] = {"int": false, "ext": false}
				if a_enclos and not a_dehors:
					(par_classe[nom] as Dictionary)["int"] = true
				elif a_dehors and not a_enclos:
					(par_classe[nom] as Dictionary)["ext"] = true

	var cible: int = MB.pieces_a_sculpter().size()
	var deux := 0
	var seul_int := 0
	var seul_ext := 0
	for nom in par_classe:
		var d2: Dictionary = par_classe[nom]
		if d2["int"] and d2["ext"]:
			deux += 1
		elif d2["int"]:
			seul_int += 1
		elif d2["ext"]:
			seul_ext += 1
	print("   sur %d classes de surface, réalisées dans ce monde d'essai :" % cible)
	print("     %d dans les DEUX contextes" % deux)
	print("     %d seulement en INTÉRIEUR" % seul_int)
	print("     %d seulement en EXTÉRIEUR" % seul_ext)
	print("     %d jamais vues ici" % (cible - deux - seul_int - seul_ext))
	print("\n   ⚠ VERDICT : %d ≫ 10 signifierait que « 10 » n'est PAS un plafond du modèle, mais" % deux)
	print("     seulement ce que les neuf blocs réalisent — et alors la liste `AMBIGUES` écrite à la")
	print("     main n'a aucune chance d'être juste, quel qu'en soit le contenu.")
	quit(0)
