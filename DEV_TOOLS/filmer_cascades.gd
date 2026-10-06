extends "res://DEV_TOOLS/filmer_formes.gd"
##
## DEVLOG — L'ÎLE DES CASCADES. Demandé par Jordan (6 octobre 2026) : « une île remplie de cascades et de bassins qui
## débordent naturellement les uns sur les autres et qui finissent soit dans l'océan soit dans des bassins ».
##
## ⚠ CE QUE LE LOGICIEL FAIT DE L'EAU, ET QUI DESSINE L'ÎLE (fluides.gd, relevé le 6 octobre 2026) :
##   - un bassin se remplit jusqu'à son point de fuite le plus bas MOINS UN : chaque bassin a donc une ÉCHANCRURE d'une
##     case dans sa lèvre, côté mer — c'est par là, et par là seulement, qu'il déborde ;
##   - la rivière va, à plat, vers la chute la PLUS PROCHE : l'échancrure mène droit au bord de la terrasse, et le bassin
##     suivant est creusé juste au pied, là où l'eau tombe ;
##   - UNE source fait toute la chaîne (bassin, chute, bassin… mer) ; le PREMIER bassin ne déborde que si une chute est à
##     moins de 4 cases de son seuil (l'échancrure du sommet fait moins d'une case) ;
##   - une rivière ne finit que dans la mer : les « bassins où elle finit » sont des LAGONS reliés à la mer par un passage
##     sous l'eau — la mer inonde tout ce qui lui est relié sous son niveau.
## Les gestes sont ceux de filmer_ui.gd (vrais événements ; curseur et carte de touche dessinés par-dessus).
##
## LANCEMENT — dans la COPIE de tournage :
##   cp D:/MarchingBlocks/DEV_TOOLS/filmer_*.gd D:/MarchingBlocks_tournage/DEV_TOOLS/
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks_tournage --fixed-fps 30 \
##       --write-movie D:/SpannerGames/PROJETS/MarchingBlocks/02_rushes/cascades.avi --script res://DEV_TOOLS/filmer_cascades.gd

## L'ÎLE — une règle, un endroit.
const MER_ILE := 5
const SOMMET := 34                 # le dessus de la terrasse du sommet
const MARCHE := 4                  # la hauteur d'une terrasse
const LARGEUR := 6                 # sa largeur, le long d'un rayon
const TERRASSES := 7               # k = 0 (le sommet) à 6 (h = 10)
const R0 := 12.0                   # le rayon du sommet (à 8, les quatre bassins du sommet se touchaient : la chaîne large se vidait par une autre)
const PLAGE := 6                   # le dessus de la plage (une case au-dessus de la mer)
const FOND_ILE := -6
## Les quatre chaînes : leur angle, où elles finissent, et leur largeur de rivière.
const CHAINES := [
	{"angle": 0.35, "fin": "mer", "large": false},
	# ⚠ PLUS DE CHAÎNE LARGE (River width 3) : même partie de la lèvre, une échancrure de 3 cases a toujours une case de
	# côté au-dessus du bassin ; les trois rivières y retombaient (`rejoint`, 1 bassin sur 7, trois essais).
	{"angle": 1.95, "fin": "lagon", "large": false},
	{"angle": 3.55, "fin": "mer", "large": false},
	{"angle": 5.05, "fin": "lagon", "large": false},
]

var _bassins := []                 # par chaîne : [centre (Vector3i du fond), …] du sommet à la plage


func _derouler() -> void:
	await _images(30)
	await _ecran._ouvrir(_chemin)
	_ecran._changer_d_atelier("monde")
	_ecran._legende_formes.basculer(false, false)
	_vue = _ecran._vue
	for i in _ecran._couches.size():
		_couche[str(_ecran._couches[i].get("nom", ""))] = i
	_aides()
	for partie in ["construire", "mer", "chaines", "detour", "baignade"]:
		# `-- --seulement=<partie>` : l'île et la mer sont toujours là, puis la seule partie demandée.
		if _seulement != "" and _seulement != partie and not partie in ["construire", "mer"]:
			continue
		_plan(partie)
		await Callable(self, "_c_" + partie).call()
		await _images(int(0.5 * FPS))
	_plan("fin")
	_rendre_les_reglages()
	quit(0)


# ── 1. CONSTRUIRE L'ÎLE, PAR ÉTAPES VISIBLES ─────────────────────────────────────────────────────────

func _c_construire() -> void:
	for nom in _couche:
		_ecran._activer(_couche[nom])
		var occ: Dictionary = _ecran._occupees()
		if not occ.is_empty():
			_ecran._appliquer({"poser": {}, "effacer": occ}, "Dig")
	while not _ecran._eaux.is_empty():
		_ecran._retirer_eau(_ecran._eaux[0])
	var roche := {}
	var herbe := {}
	var sable := {}
	var n := int(R0 + LARGEUR * TERRASSES + 18)
	for x in range(-n, n + 1):
		for z in range(-n, n + 1):
			var h := _h(x + 0.5, z + 0.5)
			if h < FOND_ILE:
				continue
			var r := Vector2(x + 0.5, z + 0.5).length()
			var terrasse := r <= _bord(atan2(z + 0.5, x + 0.5), TERRASSES - 1)
			for y in range(FOND_ILE, h + 1):
				var c := Vector3i(x, y, z)
				if terrasse and y == h:
					herbe[c] = true
				elif not terrasse and y > h - 2:
					sable[c] = true
				else:
					roche[c] = true
	# Les bassins, les échancrures, les lagons : creusés dans tout ce qui précède.
	var creux := {}
	_bassins.clear()
	for ch in CHAINES:
		_bassins.append(_creuser_la_chaine(ch, creux))
	for d in [roche, herbe, sable]:
		for c in creux:
			d.erase(c)
	_poser_camera(Vector3(0, 12, 0), 0.6, 0.55, 150.0)
	await _images(10)
	_montrer("World", "The rock of the island")
	_ecran._activer(_couche["GreyRock"])
	_ecran._appliquer({"poser": roche, "effacer": {}}, "Add")
	await _orbite(3.0, 0.6, 0.9, 150.0, 125.0)
	_montrer("World", "Grass on every terrace")
	_ecran._activer(_couche["Grass"])
	_ecran._appliquer({"poser": herbe, "effacer": {}}, "Add")
	await _orbite(2.5, 0.9, 1.15, 125.0, 115.0)
	_montrer("World", "Sand on the beaches")
	_ecran._activer(_couche["Desert"])
	_ecran._appliquer({"poser": sable, "effacer": {}}, "Add")
	_ecran._activer(_couche["GreyRock"])
	_ecran._reparer_les_diagonales(false)
	await _orbite(2.5, 1.15, 1.4, 115.0, 105.0)
	print("île : roche %d, herbe %d, sable %d, creusé %d" % [roche.size(), herbe.size(), sable.size(), creux.size()])


## Les bassins d'une chaîne, du sommet à la plage, leurs échancrures ; le lagon s'il y en a un. Rend les fonds.
func _creuser_la_chaine(ch: Dictionary, creux: Dictionary) -> Array:
	var a: float = ch["angle"]
	var u := Vector2(cos(a), sin(a))
	var v := Vector2(-u.y, u.x)
	var rayon := 2.8 if ch["large"] else 2.5
	var demi := 1 if ch["large"] else 0
	var fonds := []
	for k in TERRASSES:
		var h := SOMMET - MARCHE * k
		# ⚠ LE BASSIN TOUCHE LE PIED DE LA TERRASSE DU DESSUS (6 octobre 2026) : à 0,6 case du mur, la chute tombait une
		# fois sur deux à côté, sur l'herbe, et la rivière filait au bord suivant sans le remplir (3 bassins pleins sur 7).
		# Au sommet, il reste DANS la terrasse : trop près du bord, il s'ouvrait sur la pente et ne retenait rien.
		var rc := (_bord(a, 0) - rayon - 0.7) if k == 0 else (_bord(a, k - 1) + rayon + 0.1)
		var centre := u * rc
		for x in range(int(centre.x) - 4, int(centre.x) + 5):
			for z in range(int(centre.y) - 4, int(centre.y) + 5):
				if Vector2(x + 0.5, z + 0.5).distance_to(centre) <= rayon:
					for y in range(h - 2, h + 1):
						creux[Vector3i(x, y, z)] = true
		# L'échancrure : une case de la lèvre, du bassin jusqu'au bord de la terrasse, côté mer.
		# ⚠ L'ÉCHANCRURE PART DE LA LÈVRE, PAS DU CENTRE : large de 3, ses cases de côté passaient AU-DESSUS du bassin ; la
		# rivière y « tombait » dans son propre lac et s'arrêtait là (`rejoint`, 1 bassin sur 7 — mesuré le 6 octobre 2026).
		var t := rc + rayon - 0.6
		while t <= _bord(a, k) + 0.7:
			for w in range(-demi, demi + 1):
				var p: Vector2 = u * t + v * w
				creux[Vector3i(floori(p.x), h, floori(p.y))] = true
			t += 0.35
		fonds.append(Vector3i(floori(centre.x), h - 3, floori(centre.y)))
	if ch["fin"] == "lagon":
		# Le lagon : un bassin au pied de la dernière chute, creusé sous la mer, et un passage sous l'eau vers le large.
		var rl := _bord(a, TERRASSES - 1) + 3.6
		var cl := u * rl
		for x in range(int(cl.x) - 5, int(cl.x) + 6):
			for z in range(int(cl.y) - 5, int(cl.y) + 6):
				if Vector2(x + 0.5, z + 0.5).distance_to(cl) <= 3.3:
					for y in range(1, PLAGE + 1):
						creux[Vector3i(x, y, z)] = true
		var t := rl
		while t <= _rivage(a) + 4.0:
			var p := u * t
			for w in [-1, 0, 1]:
				var q: Vector2 = p + v * w
				for y in range(1, 4):
					creux[Vector3i(floori(q.x), y, floori(q.y))] = true
			t += 0.35
		fonds.append(Vector3i(floori(cl.x), 0, floori(cl.y)))
	return fonds


## Le bord extérieur de la terrasse k dans la direction a : des anneaux ondulés, PARALLÈLES (même ondulation pour tous),
## pour que le long d'un rayon chaque terrasse fasse exactement LARGEUR — les bassins tombent juste.
func _bord(a: float, k: int) -> float:
	return R0 + LARGEUR * k + 1.6 * sin(3.0 * a) + 0.9 * sin(5.0 * a + 1.3)


func _rivage(a: float) -> float:
	return _bord(a, TERRASSES - 1) + 7.0 + 1.5 * sin(4.0 * a + 0.7)


## La hauteur du dessus de la colonne (x, z).
func _h(x: float, z: float) -> int:
	var r := Vector2(x, z).length()
	var a := atan2(z, x)
	for k in TERRASSES:
		if r <= _bord(a, k):
			return SOMMET - MARCHE * k
	var rv := _rivage(a)
	if r <= rv:
		return PLAGE
	if r <= rv + 14.0:
		return int(round(MER_ILE - 2 - (r - rv) * 0.45))
	return FOND_ILE - 1


func _orbite(duree: float, az0: float, az1: float, d0: float, d1: float) -> void:
	var n := int(duree * FPS)
	for i in n:
		var t := _doux(float(i) / float(n - 1))
		_vue._azimut = lerpf(az0, az1, t)
		_vue._distance = lerpf(d0, d1, t)
		_vue._caler()
		await _images(1)


# ── 2. LA MER : un clic dans le vide l'épingle, PgUp / PgDn règle son niveau, Entrée la pose ──────────

func _c_mer() -> void:
	await _cliquer_bouton("Fluids", "Fluids workshop")
	await _images(10)
	var avant := int(_ecran._compteur_etage.value)
	if avant != MER_ILE:
		_montrer("PgUp / PgDn", "Water height: y = %d" % MER_ILE)
		for i in absi(MER_ILE - avant):
			var k := KEY_PAGEUP if MER_ILE > avant else KEY_PAGEDOWN
			_cle(k, true)
			_cle(k, false)
			await _images(2)
	# Un coin du monde où rien n'est posé dans la colonne : là, un clic choisit la MER.
	var coin := float(R0 + LARGEUR * TERRASSES + 16)
	var vide := Vector3(coin * 0.92, MER_ILE, coin * 0.92)
	_regarder(vide + Vector3(-70, 55, -20), vide)
	await _images(10)
	_dans_l_image(vide, "la mer")
	await _bouger(_sur(vide), 0.8)
	await _clic(MOUSE_BUTTON_LEFT, "Click the void", "The sea: pick its height")
	# ⚠ LE SECOND CLIC, PAS ENTRÉE : le bouton Fluids, cliqué juste avant, a le focus, et Entrée le RE-CLIQUAIT — la mer
	# restait en suspens, et le clic suivant (sur un bassin) la posait à sa place (vu au premier essai).
	await _clic(MOUSE_BUTTON_LEFT, "Click again", "Place the sea")
	await _ecran._recalculer_eau(false)
	print("mer : %d cases, en suspens : %s ; rapport : %s" % [(_ecran._ocean_eau as Dictionary).size(), _ecran._mer_choisie, _ecran._rapport.text])
	_dire_l_eau("mer")
	await _images(int(1.0 * FPS))


# ── 3. LES CHAÎNES : une source au sommet, et toute la descente se calcule ─────────────────────────────

func _c_chaines() -> void:
	var nb_sources: int = (_ecran._eaux[_ecran._eau_active]["sources"] as Array).size() if not _ecran._eaux.is_empty() else 0
	for i in CHAINES.size():
		var ch: Dictionary = CHAINES[i]
		var fonds: Array = _bassins[i]
		var haut: Vector3i = fonds[0]
		var a: float = ch["angle"]
		var u := Vector3(cos(a), 0, sin(a))
		# Viser le fond du bassin du sommet, d'au-dessus.
		_regarder(Vector3(haut) + Vector3(0.5, 22, 0.5) - u * 14.0, Vector3(haut) + Vector3(0.5, 0, 0.5))
		await _images(12)
		if ch["large"]:
			await _molette_alt(2, "Alt + Wheel", "River width: 3")
		var vise := Vector3(haut) + Vector3(0.5, 1.02, 0.5)
		var loc: Vector2 = _vue._camera.unproject_position(vise)
		print("chaîne %d : vise %s, la vue y trouve %s (attendu %s)" % [i, vise, _vue.source_visee(loc), haut + Vector3i.UP])
		await _forme_au(Vector3(haut) + Vector3(0.5, 1.02, 0.5),
			"One source: the whole chain of pools follows" if i == 0 else "A source in the summit pool")
		# ⚠ OUVERT (6 octobre 2026) : deux clics sur quatre, pourtant SUR la vue et visant la bonne case (vérifié :
		# `source_visee` rend la case attendue), n'ont rien posé, sans un message. En attendant de comprendre, si le clic
		# n'a rien posé, on appelle ce qu'il appelle (`_eau_cliquee`, sur la case qu'il vise) — et le journal le dit.
		# ⚠ UN GESTE LENT EST RETENU PUIS REJOUÉ (`_noter_le_geste`, editor.gd:2582) : après le premier calcul d'eau,
		# l'appli sait qu'un clic d'eau prend du temps ; elle montre d'abord son panneau d'attente, PUIS rejoue le clic.
		# On attend donc le rejeu (1 s : mesuré, il ne vient jamais, même en 6 s) avant de conclure que rien n'a été posé.
		var avant: int = nb_sources
		for attente in int(1.0 * FPS):
			if (_ecran._eaux[_ecran._eau_active]["sources"] as Array).size() != avant:
				break
			await _images(1)
		if (_ecran._eaux[_ecran._eau_active]["sources"] as Array).size() == avant:
			print("⚠ chaîne %d : le clic n'a rien posé ; `_eau_cliquee` appelé sur %s" % [i, haut + Vector3i.UP])
			_ecran._eau_cliquee(haut + Vector3i.UP, MOUSE_BUTTON_LEFT)
		nb_sources = (_ecran._eaux[_ecran._eau_active]["sources"] as Array).size()
		await _ecran._recalculer_eau(false)
		_dire_l_eau("chaîne %d" % i)
		print("rapport : %s" % _ecran._rapport.text)
		await _images(int(0.6 * FPS))
		# La caméra descend la chaîne, de bassin en bassin, de côté.
		var cote := Vector3(-u.z, 0, u.x)
		var points := []
		for f in fonds:
			var p := Vector3(f) + Vector3(0.5, 2.0, 0.5)
			points.append([p + cote * 16.0 + u * 6.0 + Vector3(0, 9, 0), p])
		await _descendre(points, 7.0)
		if ch["large"]:
			await _molette_alt(-2, "Alt + Wheel", "River width: 1")


## Ce que l'appli a calculé : chaque source, son genre, sa fin, ses bassins (la mise au point, dans le journal).
func _dire_l_eau(quand: String) -> void:
	for i in _ecran._eaux.size():
		var srcs: Array = _ecran._eaux[i]["sources"]
		for j in mini(srcs.size(), _ecran._corps_eau[i].size() if i < _ecran._corps_eau.size() else 0):
			var r: Dictionary = _ecran._corps_eau[i][j]
			print("%s — source %s : %s, fin « %s », %d bassin(s), erreur « %s »" % [quand, srcs[j], r["genre"],
				r.get("fin", ""), (r.get("lacs", []) as Array).size(), r["erreur"]])


func _descendre(points: Array, duree: float) -> void:
	var n := int(duree * FPS)
	var segs := points.size() - 1
	for i in n:
		var t := float(i) / float(n - 1) * segs
		var k := mini(int(t), segs - 1)
		var w := _doux(t - k)
		_regarder((points[k][0] as Vector3).lerp(points[k + 1][0], w), (points[k][1] as Vector3).lerp(points[k + 1][1], w))
		await _images(1)


## Alt + molette au-dessus de la vue : la largeur de la rivière (la molette du contexte de Fluids).
func _molette_alt(crans: int, carte: String, detail: String) -> void:
	_montrer(carte, detail)
	await _bouger(_vue.get_global_transform_with_canvas() * (_vue.size * 0.5), 0.3)
	_cle(KEY_ALT, true)
	for i in absi(crans):
		for oui in [true, false]:
			var b := InputEventMouseButton.new()
			b.button_index = MOUSE_BUTTON_WHEEL_UP if crans > 0 else MOUSE_BUTTON_WHEEL_DOWN
			b.pressed = oui
			b.alt_pressed = true
			b.position = _souris
			b.global_position = _souris
			_envoyer(b)
		await _images(8)
	_cle(KEY_ALT, false)
	await _images(int(0.5 * FPS))
	print("largeur de rivière : %s" % _ecran.get("_largeur_riviere"))


# ── 4. LE DÉTOUR : on creuse la lèvre d'un bassin, l'eau change de route en direct ─────────────────────

func _c_detour() -> void:
	await _touche(KEY_ESCAPE, "Esc", "Back to World")
	var ch: Dictionary = CHAINES[2]
	var fonds: Array = _bassins[2]
	var f: Vector3i = fonds[3]
	var a: float = ch["angle"]
	var u := Vector3(cos(a), 0, sin(a))
	var cote := Vector3(-u.z, 0, u.x)
	var h := SOMMET - MARCHE * 3
	_regarder(Vector3(f) + cote * 14.0 + u * 10.0 + Vector3(0, 12, 0), Vector3(f) + Vector3(0, 2, 0))
	await _images(15)
	await _touche(KEY_D, "D", "Dig")
	if _vue.visee != "sculpt":
		await _touche(KEY_TAB, "Tab", "Sculpt aim")
	for i in 3:
		await _touche(KEY_BRACKETLEFT, "[", "Smallest brush")
	# La lèvre, sur le côté du bassin : deux cases, la seconde plus bas que l'échancrure — le nouveau point de fuite.
	var levre := f + Vector3i(roundi(cote.x * 3.0), 3, roundi(cote.z * 3.0))
	await _forme_au(Vector3(levre) + Vector3(0.5, 1.02, 0.5), "Dig the rim of a pool")
	await _forme_au(Vector3(levre) + Vector3(0.5, 0.02, 0.5), "Deeper than its notch")
	await _ecran._recalculer_eau(false)
	await _images(int(2.5 * FPS))
	await _touche(KEY_Z, "Ctrl + Z", "Undo: the water takes its old way back", true)
	await _touche(KEY_Z, "Ctrl + Z", "Undo", true)
	await _ecran._recalculer_eau(false)
	await _images(int(2.0 * FPS))


# ── 5. LA BAIGNADE : au Play test, on saute d'une terrasse dans un bassin ──────────────────────────────

func _c_baignade() -> void:
	var ch: Dictionary = CHAINES[0]
	var f: Vector3i = _bassins[0][2]
	var a: float = ch["angle"]
	var u := Vector3(cos(a), 0, sin(a))
	var cote := Vector3(-u.z, 0, u.x)
	var depart := Vector3(f) + cote * 4.5 + Vector3(0.5, 4, 0.5)
	_vue._cible = depart
	await _cliquer_bouton("Play test", "Play test")
	await _images(int(1.0 * FPS))
	var vers := (Vector3(f) + Vector3(0.5, 0, 0.5) - depart)
	vers.y = 0
	vers = vers.normalized()
	_vue._azimut = atan2(-vers.x, -vers.z)
	await _tenir(KEY_W, 1.6, "W A S D", "Walk to the edge…")
	await _touche(KEY_SPACE, "Space", "…and jump in")
	await _tenir(KEY_W, 1.2, "W A S D", "Swim")
	await _images(int(1.5 * FPS))
	await _touche(KEY_ESCAPE, "Esc", "Back to World")
