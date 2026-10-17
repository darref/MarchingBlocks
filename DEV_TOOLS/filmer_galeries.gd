extends "res://DEV_TOOLS/filmer_formes.gd"
##
## DEVLOG — LE RÉSEAU SOUS LA MONTAGNE. Demandé par Jordan (6 octobre 2026) : « dans une montagne un réseau de galeries
## et de rooms et de puits, et à la fin tu traverses le tout avec le stickman ».
##
## ⚠ CE QUE LE LOGICIEL IMPOSE, ET QUI DESSINE LE RÉSEAU (relevé le 6 octobre 2026) :
##   - le stickman fait 0,84 de haut et ne gravit que 0,3 case sans sauter : chaque marche d'escalier est un SAUT ; il
##     avance là où regarde la caméra (on le dirige par l'azimut) ; F le fait voler (il remonte un puits) ;
##   - un tunnel en ARCHE de taille 2 a un sol plat et 3 cases de large : on y marche ; il s'arrête dans la première
##     salle qu'il trouve, ou débouche dehors (« ouvert ») ;
##   - une salle tracée sur la grille à l'étage y a son sol en y et son vide à partir de y + 1 : la salle d'entrée est
##     tracée à l'étage de la prairie, pour qu'on y entre de plain-pied ;
##   - un escalier d'un clic ARRIVE au niveau de la case cliquée du mur ; un tunnel cliqué deux cases plus haut a son sol
##     au niveau du palier : l'escalier mène à la galerie ;
##   - les formes n'agissent que sur la couche ACTIVE : toute la montagne est en GreyRock.
##
## LANCEMENT — dans la COPIE de tournage :
##   cp D:/MarchingBlocks/DEV_TOOLS/filmer_*.gd D:/SpannerGames/ATELIER/MarchingBlocks/copies/tournage_figee/DEV_TOOLS/
##   Godot_v4.7-stable_win64_console.exe --path D:/SpannerGames/ATELIER/MarchingBlocks/copies/tournage_figee --fixed-fps 30 \
##       --write-movie D:/SpannerGames/PROJETS/MarchingBlocks/02_rushes/galeries.avi --script res://DEV_TOOLS/filmer_galeries.gd
##   `-- --seulement=reseau` : bâtir et creuser, sans la traversée.

## LA MONTAGNE ET LE RÉSEAU — une règle, un endroit. Une salle : [coin, coin opposé (x, z), étage de la grille, hauteur].
const PRE := 6                     # le dessus de la prairie
const DOME := 30.0                 # le rayon de la montagne à sa base
const SALLE_ENTREE := [Vector2i(-6, 6), Vector2i(6, 20), PRE, 7]   # haute : l'arche de la galerie tient au-dessus du palier
const SALLE_HAUTE := [Vector2i(-6, -9), Vector2i(6, 0), 10, 5]    # son sol au niveau du palier de l'escalier
const SALLE_SOMMET := [Vector2i(-4, -7), Vector2i(4, -1), 19, 4]
const SALLE_CRYPTE := [Vector2i(-5, 9), Vector2i(5, 15), -7, 3]
const X_ESCALIER := -3             # l'escalier de la salle d'entrée, contre son mur nord

var _bruit_dome := FastNoiseLite.new()
var _entree := {}                  # boîtes [bas, haut] des vides des salles, mesurées après le creusement
var _bouche := Vector3i.ZERO       # la case de la paroi sud où entre le premier tunnel
var _sortie := Vector3i.ZERO       # la case de la paroi ouest où débouche le dernier


func _derouler() -> void:
	await _images(30)
	await _ecran._ouvrir(_chemin)
	_ecran._changer_d_atelier("monde")
	_ecran._legende_formes.basculer(false, false)
	_vue = _ecran._vue
	for i in _ecran._couches.size():
		_couche[str(_ecran._couches[i].get("nom", ""))] = i
	await _batir_la_montagne()
	_ecran._activer(_couche["GreyRock"])
	_aides()
	await _images(20)
	for partie in ["reseau", "traversee"]:
		if _seulement != "" and _seulement != partie and partie != "reseau":   # le réseau est toujours creusé
			continue
		_plan(partie)
		await Callable(self, "_g_" + partie).call()
		await _images(int(0.5 * FPS))
	_plan("fin")
	_rendre_les_reglages()
	quit(0)


# ── LA MONTAGNE ──────────────────────────────────────────────────────────────────────────────────────

func _batir_la_montagne() -> void:
	for nom in _couche:
		_ecran._activer(_couche[nom])
		var occ: Dictionary = _ecran._occupees()
		if not occ.is_empty():
			_ecran._appliquer({"poser": {}, "effacer": occ}, "Dig")
	while not _ecran._eaux.is_empty():
		_ecran._retirer_eau(_ecran._eaux[0])
	_bruit_dome.seed = 5
	_bruit_dome.frequency = 0.06
	_bruit_dome.fractal_octaves = 3
	var roche := {}
	var herbe := {}
	var n := 46
	for x in range(-n, n + 1):
		for z in range(-n, n + 1):
			var h := _dessus_dome(x, z)
			for y in range(-10, h + 1):
				var c := Vector3i(x, y, z)
				if h == PRE and y == PRE:
					herbe[c] = true
				else:
					roche[c] = true
	_ecran._activer(_couche["GreyRock"])
	_ecran._appliquer({"poser": roche, "effacer": {}}, "Add")
	_ecran._activer(_couche["Grass"])
	_ecran._appliquer({"poser": herbe, "effacer": {}}, "Add")
	_ecran._activer(_couche["GreyRock"])
	_ecran._reparer_les_diagonales(false)
	await _images(2)
	print("montagne : roche %d, herbe %d" % [roche.size(), herbe.size()])


## Le dessus de la colonne : un dôme bosselé (bruit), la prairie autour.
func _dessus_dome(x: int, z: int) -> int:
	var r := Vector2(x + 0.5, z + 0.5).length()
	var b := _bruit_dome.get_noise_2d(x, z)
	var rr := r / (DOME * (1.0 + 0.12 * b))
	if rr >= 1.0:
		return PRE
	return PRE + int(round(31.0 * pow(1.0 - rr * rr, 0.7) + 3.0 * b))


# ── LE RÉSEAU, CREUSÉ AUX FORMES SPÉCIALES ───────────────────────────────────────────────────────────

func _g_reseau() -> void:
	_regarder(Vector3(42, 40, 52), Vector3(0, 14, 0))
	await _images(int(1.0 * FPS))
	# 1. Les salles, tracées sur la grille, DANS la roche : invisibles du dehors.
	await _cliquer_bouton("Room", "Special shape: Room")
	await _salle(SALLE_ENTREE, "The entrance hall, at meadow level")
	_entree["entree"] = _vide(SALLE_ENTREE)
	await _salle(SALLE_HAUTE, "An upper hall, behind it")
	_entree["haute"] = _vide(SALLE_HAUTE)
	await _salle(SALLE_SOMMET, "A chamber under the summit")
	_entree["sommet"] = _vide(SALLE_SOMMET)
	await _salle(SALLE_CRYPTE, "A crypt under the meadow")
	_entree["crypte"] = _vide(SALLE_CRYPTE)
	print("salles : %s" % [_entree])
	# 2. Le tunnel d'entrée : en arche, de plain-pied avec la prairie, jusqu'à la salle d'entrée.
	var e: Array = _entree["entree"]
	var y_sol: int = e[0].y
	_bouche = _premier_plein(Vector3i(0, y_sol + 1, 60), Vector3i(0, 0, -1))
	await _cliquer_bouton("Tunnel", "Tunnel")
	await _cliquer_bouton("Arch", "Profile: Arch — a flat floor, a vault")
	await _profondeur(40)
	_regarder(Vector3(_bouche) + Vector3(9, 6, 18), Vector3(_bouche) + Vector3(0.5, 0.5, 0))
	await _images(10)
	await _forme_au(_face(_bouche, Vector3i(0, 0, 1)), "The way in: it stops at the first hall")
	# 3. DANS la salle d'entrée : un escalier contre le mur nord, puis la galerie depuis son palier ; un puits vers la crypte.
	var bas: Vector3i = e[0]
	var haut: Vector3i = e[1]
	var cx := (bas.x + haut.x) * 0.5 + 0.5
	_regarder(Vector3(cx + 2, bas.y + 2.4, haut.z + 0.4), Vector3(cx - 1, bas.y + 2.0, bas.z))
	await _images(15)
	# ⚠ L'ESCALIER ARRIVE 3 CASES PLUS HAUT, LA GALERIE S'OUVRE 2 AU-DESSUS : au premier essai (arrivée à +4 dans une
	# salle de 5), la galerie visait le PLAFOND — hors de l'image, et rien n'a été creusé.
	var arrivee := Vector3i(X_ESCALIER, bas.y + 3, bas.z - 1)
	await _cliquer_bouton("Stairs", "Stairs, inside the hall")
	await _forme_au(_face(arrivee, Vector3i(0, 0, 1)), "Stairs up the north wall")
	await _cliquer_bouton("Tunnel", "Tunnel")
	await _forme_au(_face(arrivee + Vector3i(0, 2, 0), Vector3i(0, 0, 1)), "From the landing, a gallery north")
	await _cliquer_bouton("Well", "Well")
	await _cliquer_bouton("Round", "Profile: Round")
	await _forme_au(_face(Vector3i(4, bas.y - 1, bas.z + 3), Vector3i(0, 1, 0)), "A well down to the crypt")
	# 4. Le puits entre la salle haute et la chambre du sommet : cliqué DEPUIS la chambre, dans son sol.
	var s: Array = _entree["sommet"]
	var sb: Vector3i = s[0]
	var sh: Vector3i = s[1]
	_regarder(Vector3((sb.x + sh.x) * 0.5 + 0.5, sb.y + 2.6, sh.z + 0.4), Vector3((sb.x + sh.x) * 0.5, sb.y, sb.z + 1))
	await _images(15)
	await _forme_au(_face(Vector3i(0, sb.y - 1, (sb.z + sh.z) / 2), Vector3i(0, 1, 0)), "A shaft down to the upper hall")
	# 5. De la chambre du sommet, un tunnel vers l'ouest qui DÉBOUCHE à flanc de montagne.
	await _cliquer_bouton("Tunnel", "Tunnel")
	await _cliquer_bouton("Arch", "Profile: Arch")
	_regarder(Vector3(sh.x + 0.4, sb.y + 2.4, (sb.z + sh.z) * 0.5 + 0.5), Vector3(sb.x, sb.y + 1.5, (sb.z + sh.z) * 0.5))
	await _images(15)
	var z_s: int = (sb.z + sh.z) / 2
	# ⚠ LA PAROI SE LIT AVANT DE CREUSER (après, la rangée est vide de bout en bout — leçon du devlog des formes). Le
	# balcon se pose sur la paroi UNE case sous le sol de la galerie (son sol est à sb.y - 1 : le balcon en est le
	# prolongement).
	_sortie = _premier_plein(Vector3i(-60, sb.y - 1, z_s), Vector3i(1, 0, 0))
	await _forme_au(_face(Vector3i(sb.x - 1, sb.y + 1, z_s), Vector3i(1, 0, 0)), "West, out through the mountain side")
	# 6. Dehors : un balcon à la bouche, à fleur de son sol.
	_regarder(Vector3(_sortie) + Vector3(-16, 5, 10), Vector3(_sortie) + Vector3(0, 1, 0.5))
	await _images(15)
	await _cliquer_bouton("Balcony", "Balcony")
	await _forme_au(_face(_sortie, Vector3i(-1, 0, 0)), "A balcony at the gallery's mouth")
	print("bouche %s, sortie %s" % [_bouche, _sortie])


## La boîte [bas, haut] des cases VIDES d'une salle tracée, dans son rectangle et ses étages.
func _vide(s: Array) -> Array:
	return _boite_vide(s[0].x, s[1].x, s[0].y, s[1].y, s[2], s[2] + s[3] + 2)


# ── LA TRAVERSÉE, AU STICKMAN ────────────────────────────────────────────────────────────────────────

func _g_traversee() -> void:
	var e: Array = _entree["entree"]
	var h: Array = _entree["haute"]
	var s: Array = _entree["sommet"]
	var y0: float = e[0].y
	var hy: float = h[0].y
	var sy: float = s[0].y
	var z_s: float = (s[0].z + s[1].z) * 0.5 + 0.5
	# Le départ, dehors, devant la bouche.
	_vue._cible = Vector3(_bouche.x + 0.5, y0, _bouche.z + 9)
	await _cliquer_bouton("Play test", "Play test: walk through it all")
	await _images(int(0.5 * FPS))
	# ⚠ SOUS TERRE, LE PLAY TEST EST NOIR (le soleil n'y entre pas ; l'ambiante de 1,1 ne suffit pas — premier essai) : la
	# barre de rendu du Play test monte l'ambiante et l'exposition. Ce sont ses réglages, que l'utilisateur a aussi.
	_montrer("Render", "More ambient light for the caves")
	# ⚠ L'AMBIANTE SEULE N'Y SUFFISAIT PAS (second essai : noir complet à 2,6) : la SSAO (2,5, qui n'assombrit QUE
	# l'ambiante) et la SSIL éteignent tout dans une galerie étroite. Coupées ici, pour les grottes.
	_vue.regler_rendu("ssao", false)
	_vue.regler_rendu("ssil", false)
	_vue.regler_rendu("ambiante_energie", 2.4)
	_vue.regler_rendu("exposition", 1.3)
	await _images(int(0.8 * FPS))
	var xs := X_ESCALIER + 0.5
	# Dehors → tunnel → salle d'entrée → le PIED de l'escalier, dans son axe (il a un rebord de chaque côté : de biais,
	# le stickman restait coincé contre lui — premier essai).
	var pied: float = e[0].z + 8.5   # 3 marches de 2 rangées + 2 rangées de palier : le pied est 8 rangées devant le mur
	await _marcher([Vector3(0.5, y0, _bouche.z + 1), Vector3(0.5, y0, pied + 1.5), Vector3(xs, y0, pied + 1.0)],
		"W A S D", "Into the mountain")
	# L'escalier : un saut par marche, jusqu'au palier, puis la galerie vers le nord, jusqu'à la salle haute.
	await _marcher([Vector3(xs, y0 + 3, e[0].z + 0.6), Vector3(xs, hy, e[0].z - 2),
		Vector3(xs, hy, h[1].z - 1)], "Space", "Up the stairs, a jump per step", true)
	# Sous le puits : on vole jusqu'à la chambre du sommet.
	var z_puits: float = (s[0].z + s[1].z) / 2 + 0.5
	await _marcher([Vector3(0.5, hy, z_puits)], "W A S D", "Under the shaft")
	await _voler_jusqu_a(sy + 1.2, Vector3(0.5, sy, z_puits + 2.5))
	# La chambre du sommet → le tunnel ouest → le balcon.
	await _marcher([Vector3(s[0].x + 0.5, sy, z_s), Vector3(_sortie.x - 0.5, sy, z_s)], "W A S D", "Out to the balcony")
	await _regarder_autour(4.0)
	await _touche(KEY_ESCAPE, "Esc", "Back to World")


## Le stickman va de point en point : la caméra (donc sa marche) tournée vers le point suivant, W tenu ; s'il faut
## monter (`sauter`), un saut toutes les 0,4 s. On passe au point suivant à 0,7 case près (à plat).
func _marcher(points: Array, carte: String, detail: String, sauter := false) -> void:
	var p: CharacterBody3D = _vue.personnage
	if p == null:
		print("⚠ pas de personnage")
		return
	_montrer(carte, detail)
	_cle(KEY_W, true)
	var depuis_saut := 0
	for cible in points:
		for i in int(20 * FPS):
			var d: Vector3 = cible - p.global_position
			var plat := Vector2(d.x, d.z)
			if plat.length() < 0.45:
				break
			_vue._azimut = lerp_angle(_vue._azimut, atan2(-plat.x, -plat.y), 0.25)
			_vue._distance = 3.2
			_vue._elevation = 0.45
			depuis_saut += 1
			if sauter and depuis_saut >= 12 and d.y > 0.3:
				depuis_saut = 0
				_cle(KEY_SPACE, true)
				await _images(2)
				_cle(KEY_SPACE, false)
			await _images(1)
		var reste := Vector2(cible.x - p.global_position.x, cible.z - p.global_position.z).length()
		print("%s %s : stickman en %s" % ["point atteint" if reste < 0.5 else "⚠ POINT MANQUÉ", cible, p.global_position])
	_cle(KEY_W, false)
	await _images(6)


## F : il vole ; Espace tenu : il monte, jusqu'à la hauteur voulue ; F : il se pose.
## F : il vole ; Espace tenu : il monte jusqu'à la hauteur voulue ; il s'écarte du puits (sinon, posé, il y retomberait) ;
## F : il se pose.
func _voler_jusqu_a(y: float, a_cote: Vector3) -> void:
	var p: CharacterBody3D = _vue.personnage
	await _touche(KEY_F, "F", "Fly")
	_montrer("Space", "Up the shaft")
	_cle(KEY_SPACE, true)
	for i in int(8 * FPS):
		if p.global_position.y >= y:
			break
		_vue._distance = 2.6
		_vue._elevation = 0.9
		await _images(1)
	_cle(KEY_SPACE, false)
	await _marcher([a_cote], "W A S D", "Off the shaft")
	await _touche(KEY_F, "F", "Land")
	print("vol jusqu'à %.1f : %s" % [y, p.global_position])


func _regarder_autour(duree: float) -> void:
	var n := int(duree * FPS)
	var a0: float = _vue._azimut
	for i in n:
		_vue._azimut = a0 + 1.6 * _doux(float(i) / float(n - 1))
		_vue._distance = 6.0
		_vue._elevation = 0.25
		await _images(1)
