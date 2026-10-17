extends "res://DEV_TOOLS/filmer_galeries.gd"
##
## DEVLOG — LE PLUS BEAU PAYSAGE. Demandé par Jordan (6 octobre 2026) : « le paysage le plus naturel et beau possible ».
##
## ⚠ CE QUE LE LOGICIEL IMPOSE (relevé le 6 octobre 2026) :
##   - le BEAU rendu (soleil rasant, ciel, glow, SDFGI, tonemap, brouillard, météo) n'existe qu'au PLAY TEST
##     (`_vue.regler_rendu`, `regler_meteo`) ; l'éditeur garde son éclairage de travail. Le paysage se construit dans
##     World, puis se montre au Play test ;
##   - l'eau suit le relief : un lac de montagne, taillé avec un seuil vers la vallée, déborde en rivière ; chaque marche
##     du lit fait une chute ; la rivière finit à la mer ;
##   - trois couches : la roche (pics, falaises, pentes raides), l'herbe (le reste), le sable (plages, lit de la rivière).
## Hérite des gestes (filmer_ui) et du pilotage du stickman (filmer_galeries : `_marcher`).
##
## LANCEMENT — dans la COPIE de tournage :
##   cp D:/MarchingBlocks/DEV_TOOLS/filmer_*.gd D:/SpannerGames/ATELIER/MarchingBlocks/copies/tournage_figee/DEV_TOOLS/
##   Godot_v4.7-stable_win64_console.exe --path D:/SpannerGames/ATELIER/MarchingBlocks/copies/tournage_figee --fixed-fps 30 \
##       --write-movie D:/SpannerGames/PROJETS/MarchingBlocks/02_rushes/paysage.avi --script res://DEV_TOOLS/filmer_paysage.gd

## LE PAYSAGE — une règle, un endroit. Le nord (z < 0) est montagne, le sud (z > 0) descend à la mer.
const MER_P := 5
const TAILLE := 64                 # de -TAILLE à +TAILLE en x et en z
const LAC := Vector2i(-6, -30)     # le lac de montagne, à la tête de la vallée
const LAC_NIVEAU := 30             # le fond du lac ; son seuil est au sud
const RIVAGE := 34                 # la côte, à peu près en z = RIVAGE

var _fbm := FastNoiseLite.new()
var _derniere_pos := Vector3.ZERO
var _montee := 0
var _arete := FastNoiseLite.new()
var _deforme := FastNoiseLite.new()


func _derouler() -> void:
	await _images(30)
	await _ecran._ouvrir(_chemin)
	_ecran._changer_d_atelier("monde")
	_ecran._legende_formes.basculer(false, false)
	_vue = _ecran._vue
	for i in _ecran._couches.size():
		_couche[str(_ecran._couches[i].get("nom", ""))] = i
	_aides()
	for partie in ["terre", "eaux", "lumiere", "vol", "meteo"]:
		_plan(partie)
		await Callable(self, "_p_" + partie).call()
		await _images(int(0.4 * FPS))
	_plan("fin")
	_rendre_les_reglages()
	quit(0)


# ── 1. LA TERRE ──────────────────────────────────────────────────────────────────────────────────────

func _p_terre() -> void:
	for nom in _couche:
		_ecran._activer(_couche[nom])
		var occ: Dictionary = _ecran._occupees()
		if not occ.is_empty():
			_ecran._appliquer({"poser": {}, "effacer": occ}, "Dig")
	while not _ecran._eaux.is_empty():
		_ecran._retirer_eau(_ecran._eaux[0])
	_fbm.seed = 21
	_fbm.frequency = 0.022
	_fbm.fractal_octaves = 5
	_arete.seed = 8
	_arete.frequency = 0.03
	_arete.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_arete.fractal_octaves = 4
	_deforme.seed = 3
	_deforme.frequency = 0.015
	var h := {}
	for x in range(-TAILLE, TAILLE + 1):
		for z in range(-TAILLE, TAILLE + 1):
			h[Vector2i(x, z)] = _hauteur_p(x, z)
	var roche := {}
	var herbe := {}
	var sable := {}
	for k in h:
		var y_top: int = h[k]
		if y_top < -8:
			continue
		var pente := 0
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if h.has(k + d):
				pente = maxi(pente, absi(y_top - int(h[k + d])))
		var dessus := "Grass"
		if y_top <= MER_P + 1 or _dans_le_lit(k.x, k.y) and y_top < LAC_NIVEAU:
			dessus = "Desert"
		# Premier essai : à pente ≥ 3, presque tout était roche (6 657 cases d'herbe seulement) — un paysage brun.
		elif pente >= 5 or y_top >= 46:
			dessus = "GreyRock"
		for y in range(-8, y_top + 1):
			var c := Vector3i(k.x, y, k.y)
			if y == y_top and dessus == "Grass":
				herbe[c] = true
			elif y > y_top - 2 and dessus == "Desert":
				sable[c] = true
			else:
				roche[c] = true
	_regarder(Vector3(70, 70, 110), Vector3(0, 12, 0))
	await _images(10)
	_montrer("World", "Ridged mountains, a valley, a coast")
	_ecran._activer(_couche["GreyRock"])
	_ecran._appliquer({"poser": roche, "effacer": {}}, "Add")
	await _orbite(3.0, 0.55, 0.75, 150.0, 140.0)
	_montrer("World", "Grass where the slope is gentle")
	_ecran._activer(_couche["Grass"])
	_ecran._appliquer({"poser": herbe, "effacer": {}}, "Add")
	await _orbite(2.5, 0.75, 0.95, 140.0, 130.0)
	_montrer("World", "Sand: beaches and the river bed")
	_ecran._activer(_couche["Desert"])
	_ecran._appliquer({"poser": sable, "effacer": {}}, "Add")
	_ecran._activer(_couche["GreyRock"])
	_ecran._reparer_les_diagonales(false)
	await _orbite(2.5, 0.95, 1.15, 130.0, 120.0)
	print("paysage : roche %d, herbe %d, sable %d" % [roche.size(), herbe.size(), sable.size()])


## Le cours de la vallée : x en fonction de z, du lac (nord) à la mer (sud).
func _x_vallee(z: float) -> float:
	return LAC.x + 9.0 * sin((z - LAC.y) * 0.06) + 4.0 * sin((z - LAC.y) * 0.13 + 1.0)


func _dans_le_lit(x: int, z: int) -> bool:
	return z > LAC.y + 6 and absf(x + 0.5 - _x_vallee(z + 0.5)) < 2.0


## La hauteur : collines (fbm), arêtes au nord (bruit « ridged » déformé), la vallée creusée en MARCHES (une chute à chaque
## marche), la côte au sud, le lac dans sa cuvette.
func _hauteur_p(x: int, z: int) -> int:
	var fx := x + 0.5
	var fz := z + 0.5
	var wx := fx + 12.0 * _deforme.get_noise_2d(fx, fz)
	var wz := fz + 12.0 * _deforme.get_noise_2d(fz + 100.0, fx)
	var collines := 12.0 + 7.0 * _fbm.get_noise_2d(wx, wz)
	var nord := clampf((10.0 - fz) / 50.0, 0.0, 1.0)
	var aretes := pow(clampf(_arete.get_noise_2d(wx, wz) * 0.5 + 0.5, 0.0, 1.0), 2.2) * 46.0 * nord
	var y := collines + aretes + 14.0 * nord
	# La côte : tout s'abaisse vers la mer au sud.
	var cote := RIVAGE + 6.0 * _fbm.get_noise_2d(fx * 0.5, 300.0)
	if fz > cote - 14.0:
		var t := clampf((fz - (cote - 14.0)) / 14.0, 0.0, 1.0)
		y = lerpf(y, MER_P + 1.0, smoothstep(0.0, 1.0, t))
	if fz > cote:
		y = MER_P - 1.0 - (fz - cote) * 0.35
	# La vallée : un lit en marches de 3 cases tous les 9 de long, des berges qui remontent en pente.
	if fz > LAC.y + 6 and fz < cote + 2:
		var lit := LAC_NIVEAU - 1 - 3.0 * floorf((fz - LAC.y - 6) / 9.0)
		lit = maxf(lit, MER_P + 1.0)
		var dx := absf(fx - _x_vallee(fz))
		y = minf(y, lit + maxf(0.0, dx - 1.5) * 1.1)
	# Le lac : une cuvette sous son niveau ; son seuil est le départ de la vallée.
	var dl := Vector2(fx, fz).distance_to(Vector2(LAC))
	if dl < 9.0:
		y = minf(y, LAC_NIVEAU - 3 + dl * 0.25) if dl < 6.5 else maxf(minf(y, LAC_NIVEAU + 2.0), LAC_NIVEAU + 1.0)
	return int(round(y))


# ── 2. LES EAUX : la mer, puis le lac — et la rivière se trouve seule ─────────────────────────────────

func _p_eaux() -> void:
	await _cliquer_bouton("Fluids", "Fluids workshop")
	await _images(10)
	var avant := int(_ecran._compteur_etage.value)
	if avant != MER_P:
		_montrer("PgUp / PgDn", "Water height: y = %d" % MER_P)
		for i in absi(MER_P - avant):
			var k := KEY_PAGEUP if MER_P > avant else KEY_PAGEDOWN
			_cle(k, true)
			_cle(k, false)
			await _images(2)
	var vide := Vector3(TAILLE * 0.6, MER_P, TAILLE + 30.0)
	_regarder(vide + Vector3(40, 50, 40), vide)
	await _images(10)
	_dans_l_image(vide, "la mer")
	await _bouger(_sur(vide), 0.8)
	await _clic(MOUSE_BUTTON_LEFT, "Click the void", "The sea: pick its height")
	await _clic(MOUSE_BUTTON_LEFT, "Click again", "Place the sea")
	await _ecran._recalculer_eau(false)
	var fond := Vector3(LAC.x + 0.5, LAC_NIVEAU - 1, LAC.y + 0.5)
	_regarder(fond + Vector3(14, 26, 22), fond)
	await _images(15)
	var n0: int = (_ecran._eaux[_ecran._eau_active]["sources"] as Array).size()
	var case_lac := Vector3i(LAC.x, _hauteur_p(LAC.x, LAC.y) + 1, LAC.y)   # au fond de la cuvette
	await _forme_au(Vector3(case_lac) + Vector3(0.5, 0.02, 0.5), "A mountain lake: it overflows down the valley")
	for attente in int(6 * FPS):
		if (_ecran._eaux[_ecran._eau_active]["sources"] as Array).size() != n0:
			break
		await _images(1)
	if (_ecran._eaux[_ecran._eau_active]["sources"] as Array).size() == n0:
		print("⚠ le clic du lac n'a rien posé ; `_eau_cliquee` appelé sur %s" % case_lac)
		_ecran._eau_cliquee(case_lac, MOUSE_BUTTON_LEFT)
	await _ecran._recalculer_eau(false)
	print("rapport : %s" % _ecran._rapport.text)
	# La caméra descend la vallée, du lac à la mer.
	var pts := []
	for z in range(LAC.y, RIVAGE + 6, 8):
		var xv := _x_vallee(z)
		pts.append([Vector3(xv + 22, 30, z + 14), Vector3(xv, 12, z)])
	await _descendre_p(pts, 9.0)
	_vue._distance = 9.0
	await _images(10)
	await _touche(KEY_ESCAPE, "Esc", "Back to World")


func _descendre_p(points: Array, duree: float) -> void:
	var n := int(duree * FPS)
	var segs := points.size() - 1
	for i in n:
		var t := float(i) / float(n - 1) * segs
		var k := mini(int(t), segs - 1)
		var w := _doux(t - k)
		_regarder((points[k][0] as Vector3).lerp(points[k + 1][0], w), (points[k][1] as Vector3).lerp(points[k + 1][1], w))
		await _images(1)


func _orbite(duree: float, az0: float, az1: float, d0: float, d1: float) -> void:
	var n := int(duree * FPS)
	for i in n:
		var t := _doux(float(i) / float(n - 1))
		_vue._azimut = lerpf(az0, az1, t)
		_vue._distance = lerpf(d0, d1, t)
		_vue._caler()
		await _images(1)


# ── 3. LA LUMIÈRE : le Play test, et ses réglages de rendu ──────────────────────────────────────────

func _p_lumiere() -> void:
	_vue._cible = Vector3(_x_vallee(RIVAGE - 4), 8, RIVAGE - 4)
	await _cliquer_bouton("Play test", "Play test: the real light")
	await _images(int(1.0 * FPS))
	# L'heure dorée : un soleil bas et chaud, un ciel qui rougit à l'horizon, glow, SDFGI, AgX.
	_montrer("Render", "Golden hour: low warm sun")
	# Second essai : à 13° et en ACES, les versants à contre-jour étaient noirs, la mer d'un bleu saturé. Un soleil de
	# fin d'après-midi (24°), DANS LE DOS de la caméra qui remonte la vallée vers le nord, AgX, une ambiante tiède.
	# ⚠ Troisième essai : SDFGI et tonemap AgX/ACES assombrissaient tout (versants vert-noir) ; le rendu PAR DÉFAUT du Play
	# test, lui, est clair (vu dans le devlog des cascades). On le garde, et on ne change que la lumière : un soleil plus
	# bas et doré, un horizon chaud, du glow.
	for reglage in [["soleil_hauteur", 30.0], ["soleil_azimut", 200.0], ["soleil_couleur", Color(1.0, 0.88, 0.72)],
			["soleil_energie", 1.5], ["ciel_horizon", Color("#f2b98a")], ["glow", true], ["glow_intensite", 1.0]]:
		_vue.regler_rendu(reglage[0], reglage[1])
		await _images(4)
	await _images(int(1.5 * FPS))


# ── 4. LE VOL : le stickman remonte la vallée en volant, jusqu'au lac et par-dessus les arêtes ─────────

func _p_vol() -> void:
	var p: CharacterBody3D = _vue.personnage
	if p == null:
		print("⚠ pas de personnage")
		return
	# ⚠ LE STICKMAN TOURNAIT EN ROND (Jordan, 6 octobre 2026 : « il tourne en rond en volant au lieu de se promener pour
	# explorer le paysage ») : en Shift (11 cases/s), avec des points tous les 6 cases et une caméra qui tournait
	# lentement, il dépassait chaque point et revenait le chercher. Désormais : une PROMENADE — un chemin lissé, suivi en
	# « poursuite » (il vise toujours le point du chemin 8 cases devant lui, jamais un point déjà passé), à vitesse de vol
	# normale (5 cases/s), à 4-7 cases du sol ; on n'avance sur le chemin que vers l'avant.
	var chemin := _promenade()
	await _touche(KEY_F, "F", "Fly")
	_montrer("W A S D", "A walk through the landscape")
	_cle(KEY_W, true)
	var k := 0
	for i in int(70 * FPS):
		var pos := p.global_position
		# Le point du chemin le plus proche, vers l'avant seulement.
		while k < chemin.size() - 1 and Vector2(chemin[k + 1].x - pos.x, chemin[k + 1].z - pos.z).length() 				< Vector2(chemin[k].x - pos.x, chemin[k].z - pos.z).length():
			k += 1
		if k >= chemin.size() - 2:
			break
		var vise: Vector3 = chemin[mini(k + 8, chemin.size() - 1)]
		var plat := Vector2(vise.x - pos.x, vise.z - pos.z)
		_vue._azimut = lerp_angle(_vue._azimut, atan2(-plat.x, -plat.y), 0.12)
		_vue._distance = 7.5
		_vue._elevation = 0.32
		var devant := pos + Vector3(plat.normalized().x, 0, plat.normalized().y) * 4.0
		var haut := pos.y - maxf(_sol_sous(pos), _sol_sous(devant))
		# ⚠ COINCÉ (sous un surplomb, contre une paroi) : s'il n'a pas avancé d'une case en 2 s, il monte 1 s tout droit.
		if i % int(2 * FPS) == 0:
			if pos.distance_to(_derniere_pos) < 1.0 and i > 0:
				_montee = int(1 * FPS)
			_derniere_pos = pos
		if _montee > 0:
			_montee -= 1
			_cle(KEY_SPACE, true)
			_cle(KEY_Q, false)
		else:
			_cle(KEY_SPACE, haut < 4.0)
			_cle(KEY_Q, haut > 7.0)
		if i % int(8 * FPS) == 0:
			print("promenade : point %d/%d, stickman en %s" % [k, chemin.size(), pos])
		await _images(1)
	_cle(KEY_SPACE, false)
	_cle(KEY_Q, false)
	_cle(KEY_W, false)
	await _images(int(0.5 * FPS))


## La promenade, case par case : le long de la plage, puis la vallée en remontant les cascades, le tour du lac, et
## par-dessus l'arête jusqu'au versant d'en face.
func _promenade() -> Array:
	var cles := []
	var x0 := _x_vallee(RIVAGE - 4)
	cles.append(Vector2(x0 + 26, RIVAGE - 2))
	cles.append(Vector2(x0 + 10, RIVAGE - 3))
	for z in range(RIVAGE - 6, LAC.y + 8, -6):
		cles.append(Vector2(_x_vallee(z), z))
	for t in range(0, 9):
		var a := PI * 0.5 + t * PI * 2.0 / 8.0
		cles.append(Vector2(LAC.x, LAC.y) + Vector2(cos(a), sin(a)) * 10.0)
	cles.append(Vector2(LAC.x + 18, LAC.y - 14))
	cles.append(Vector2(LAC.x + 34, LAC.y - 4))
	cles.append(Vector2(LAC.x + 40, LAC.y + 16))
	# Lissé (Catmull-Rom), un point par case.
	var chemin := []
	for i in cles.size() - 1:
		var p0: Vector2 = cles[maxi(i - 1, 0)]
		var p1: Vector2 = cles[i]
		var p2: Vector2 = cles[i + 1]
		var p3: Vector2 = cles[mini(i + 2, cles.size() - 1)]
		var n := maxi(1, int(p1.distance_to(p2)))
		for j in n:
			var t := float(j) / n
			var q := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)
			chemin.append(Vector3(q.x, 0, q.y))
	return chemin


func _sol_sous(p: Vector3) -> float:
	var x := floori(p.x)
	var z := floori(p.z)
	return float(_hauteur_p(x, z)) + 1.0


# ── 5. LA MÉTÉO ──────────────────────────────────────────────────────────────────────────────────────

func _p_meteo() -> void:
	# Retour au point de départ (Retour arrière : la touche du jeu), au-dessus de la vallée : au bout du vol, la caméra
	# était dans les arêtes, et la météo s'y filmait dans le noir (premier essai).
	await _touche(KEY_F, "F", "Land")
	await _touche(KEY_BACKSPACE, "Backspace", "Back to the start")
	await _images(int(1.0 * FPS))
	_vue._distance = 8.0
	_vue._elevation = 0.3
	for m in [["pluie", "Rain"], ["neige", "Slow snow"], ["brouillard", "Fog"], ["aucune", "Clear again"]]:
		_montrer("Weather", m[1])
		_vue.regler_meteo(m[0])
		for i in int(3.0 * FPS):
			_vue._azimut += 0.004
			await _images(1)
	_vue._distance = 9.0
	await _images(10)
	await _touche(KEY_ESCAPE, "Esc", "Back to World")
