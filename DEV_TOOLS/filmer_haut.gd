extends "res://DEV_TOOLS/filmer_formes.gd"
##
## DEVLOG — UN MONDE VU DE HAUT, À LA ZELDA (A LINK TO THE PAST) OU À LA POKÉMON. Demandé par Jordan (6 octobre 2026) :
## « un monde style Nintendo avec un sol plat et des collines peu hautes, un ou plusieurs niveaux de hauteur, en utilisant
## l'exemple du soft avec ses 3 layers de witness, pour faire une zone de chaque, et des zones mélangées sur le chemin entre
## elles, avec des galeries commençant par un puits dans le sol et des tunnels et des rooms, puis remontée avec un escalier
## dans la grotte, et sortie par un balcon, et retour sur la map. Filme de haut pour montrer qu'on peut faire un jeu style
## ALttP ou Pokémon avec le soft. »
##
## ⚠ CE QUE LE LOGICIEL IMPOSE, ET QUI DESSINE LE MONDE (relevé le 6 octobre 2026) :
##   - trois couches dans l'exemple, une par témoin : GreyRock, Grass, Desert → trois ZONES, chacune à son niveau ; une
##     colonne est d'une seule matière, et une matière ne change que là où la hauteur change (voir `SOL`) ;
##   - le monde n'a pas de contact diagonal : les contours bruités des collines en créent à chaque damier de colonnes. Le
##     relief est NETTOYÉ avant d'être posé (`_sans_damier` : on remonte la paire basse), le bouton Fix fait le reste ;
##   - les formes n'agissent que sur la couche ACTIVE : tout le réseau de grottes est sous des colonnes de PURE roche ;
##   - un escalier d'un clic ARRIVE au niveau de la case cliquée et descend jusqu'au sol (une marche par `pas` rangées) :
##     cliqué haut dans une grande salle, il monte de toute sa hauteur ; une arche de taille 2 a un sol plat ; un tunnel
##     d'un clic s'arrête dans la première salle qu'il trouve, ou débouche dehors ;
##   - le stickman avance là où regarde la caméra, W A S D seules ou par deux. Vu de haut, la caméra NE TOURNE PAS (le
##     nord en haut de l'image) : il prend l'une des huit directions — la marche d'un Zelda. Sous terre, la caméra repasse
##     derrière lui (vue de haut, elle verrait le plafond) ;
##   - il ne gravit pas une case sans sauter (1,45 de saut) : un saut par marche, un saut par-dessus le rebord du balcon.
##
## LANCEMENT — dans la COPIE de tournage :
##   cp D:/MarchingBlocks/DEV_TOOLS/filmer_*.gd D:/SpannerGames/ATELIER/MarchingBlocks/copies/tournage_figee/DEV_TOOLS/
##   Godot_v4.7-stable_win64_console.exe --path D:/SpannerGames/ATELIER/MarchingBlocks/copies/tournage_figee --fixed-fps 30 \
##       --write-movie D:/SpannerGames/PROJETS/MarchingBlocks/02_rushes/haut.avi --script res://DEV_TOOLS/filmer_haut.gd
##   `-- --seulement=<partie>` : exemple, terre, collines, grottes, jeu (la terre et les formes sont toujours faites).

## LE MONDE — une règle, un endroit. x vers l'est, z vers le sud ; vu de haut, le nord est en haut de l'image.
const G := 6                       # le dessus du sol de l'herbe (SOL["herbe"])
const FOND_SOL := 2                    # le bas des colonnes
const FOND_ROC := -6               # sous la zone des grottes
const BOITE_ROC := Rect2i(2, -36, 48, 32)   # où le fond descend à FOND_ROC (x, z, largeur, profondeur)
const X0 := -56
const X1 := 56
const Z0 := -40
const Z1 := 40
## Les trois zones : le centre de chacune et la hauteur de son sol ; entre deux, une CEINTURE où elles se mêlent par
## taches — chaque tache à la hauteur de SA zone.
## ⚠ UNE MATIÈRE NE CHANGE QUE LÀ OÙ LA HAUTEUR CHANGE (Jordan, 6 octobre 2026 : « sans mélange de matières dans le même
## étage collé, sinon ça fait des carrés ») : deux couches côte à côte au même niveau se dessinent chacune comme si
## l'autre était du vide, et leur frontière fait des carrés. D'où un sol par zone (désert 5, herbe 6, roche 7), des
## colonnes d'une seule matière, et `_un_niveau_une_matiere` en dernier.
const CENTRES := {"herbe": Vector2(-32, 4), "sable": Vector2(30, 24), "roche": Vector2(30, -18)}
const SOL := {"sable": 5, "herbe": 6, "roche": 7}
const CEINTURE := 40.0             # large : à 14 puis 26, le mélange se voyait à peine (carte_haut.png)
## Les collines : [centre, rayons (x, z), montée]. Une colline à deux niveaux = deux entrées superposées.
const COLLINES := [
	[Vector2(-24, -8), Vector2(9, 8), 2],       # H1 : la colline aux escaliers, le départ
	[Vector2(-25, -11), Vector2(4.5, 3.0), 4],  # H1, son second niveau
	[Vector2(-44, -24), Vector2(7, 6), 2],
	[Vector2(-46, 22), Vector2(7, 8), 2],
	[Vector2(-46, 21), Vector2(3, 3), 4],
	[Vector2(-14, 28), Vector2(6, 4), 2],       # dans la ceinture herbe / sable
	[Vector2(-8, -27), Vector2(6, 5), 2],       # dans la ceinture herbe / roche
	[Vector2(22, 29), Vector2(8, 5), 2],        # les mesas du désert
	[Vector2(22, 29), Vector2(4, 2.5), 4],
	[Vector2(45, 20), Vector2(5, 7), 3],
	[Vector2(10, 31), Vector2(4, 3), 2],
	[Vector2(42, 33), Vector2(6, 3), 2],
	[Vector2(18, -7), Vector2(2, 2), 1],        # des rochers dans la zone de roche
	[Vector2(4, -32), Vector2(3, 2), 2],
	[Vector2(49, -2), Vector2(3, 3), 2],
	[Vector2(24, 6), Vector2(2, 2), 1],
]
## Le haut plateau de roche, où la grotte remonte : un grand bloc à falaises.
const PLATEAU := Vector2(36, -21)
const PLATEAU_R := Vector2(15, 15)
const PLATEAU_DESSUS := 14
## Les passages (polylignes) : gardés libres de collines, pour que la traversée ne bute pas. Pas d'autre matière.
const CHEMINS := [
	[Vector2(-50, 8), Vector2(-30, 8), Vector2(-16, 3), Vector2(-7, -6), Vector2(1, -15), Vector2(3, -19)],
	[Vector2(36, -6), Vector2(34, 6), Vector2(31, 16), Vector2(30, 22)],
	[Vector2(-30, 8), Vector2(-14, 19), Vector2(8, 22), Vector2(30, 22), Vector2(40, 26)],
]
const LARGEUR_CHEMIN := 1.6
## La clairière du puits : de la roche nue, à plat.
const PUITS := Vector2i(11, -20)
const CLAIRIERE := 6.0
## Les salles : [coin, coin opposé (x, z), étage de la grille, hauteur libre].
const SALLE_1 := [Vector2i(8, -23), Vector2i(14, -17), -2, 4]     # au pied du puits
const SALLE_A := [Vector2i(20, -23), Vector2i(25, -17), -2, 4]    # la salle du milieu
const SALLE_2 := [Vector2i(31, -27), Vector2i(41, -13), -2, 13]   # la grande salle, sous le plateau
const X_ESCALIER := 36
const GROTTES := Rect2i(5, -25, 27, 11)   # l'emprise des salles 1 et A et des tunnels (x, z, largeur, profondeur)
const X_MONTEE := -24               # où l'on taille les escaliers de H1
const Z_TUNNELS := -20

var _bruit := FastNoiseLite.new()
var _taches := FastNoiseLite.new()
var _h := {}                       # Vector2i → hauteur du dessus
var _m := {}                       # Vector2i → "herbe" | "sable" | "roche"
var _salles := {}                  # nom → [bas, haut] des vides mesurés
var _pied_h1 := Vector3.ZERO       # le pied des escaliers de la colline H1
var _pied_h1b := Vector3.ZERO
var _sortie := Vector3i.ZERO       # la case de la falaise sud du plateau, au niveau du sol de la galerie
var _arrivee := Vector3i.ZERO      # le palier de l'escalier de la grande salle
## La caméra du Play test, tenue à chaque image (`_images`) : vue de haut, ou derrière le stickman sous terre.
var _cam_d := 10.0
var _cam_e := 1.05
var _cam_haut := true


func _derouler() -> void:
	if _seulement == "carte":
		# La carte du relief, vue de haut, en PNG : juger le monde AVANT de filmer (une case = 4 pixels).
		_relief()
		var im := Image.create((X1 - X0 + 1) * 4, (Z1 - Z0 + 1) * 4, false, Image.FORMAT_RGB8)
		var teinte := {"herbe": Color("#3fa34d"), "sable": Color("#d8c27a"), "roche": Color("#7a7a7a")}
		for k in _h:
			var c: Color = (teinte[_m[k]] as Color).darkened(clampf(0.5 - 0.05 * (_h[k] - 5), 0.0, 0.6))
			im.fill_rect(Rect2i((k.x - X0) * 4, (k.y - Z0) * 4, 4, 4), c)
		im.save_png("D:/SpannerGames/PROJETS/MarchingBlocks/03_montage/carte_haut.png")
		_rendre_les_reglages()
		quit(0)
		return
	await _images(30)
	await _ecran._ouvrir(_chemin)
	_ecran._changer_d_atelier("monde")
	_ecran._legende_formes.basculer(false, false)
	_vue = _ecran._vue
	for i in _ecran._couches.size():
		_couche[str(_ecran._couches[i].get("nom", ""))] = i
	_aides()
	for partie in ["exemple", "terre", "collines", "grottes", "jeu"]:
		if _seulement != "" and _seulement != partie and not partie in ["terre", "collines", "grottes"]:
			continue
		_plan(partie)
		await Callable(self, "_h_" + partie).call()
		await _images(int(0.5 * FPS))
	_plan("fin")
	_rendre_les_reglages()
	quit(0)


# ── 0. L'EXEMPLE : trois couches, trois témoins ─────────────────────────────────────────────────────

func _h_exemple() -> void:
	_vue.cadrer_toute_la_matiere()
	var az: float = _vue._azimut
	_montrer("3 layers", "The example: GreyRock, Grass, Desert — a witness each")
	for i in int(3.5 * FPS):
		_vue._azimut = az + 0.35 * _doux(i / (3.5 * FPS))
		_vue._caler()
		await _images(1)


# ── 1. LA TERRE : une couche, une zone ──────────────────────────────────────────────────────────────

func _h_terre() -> void:
	for nom in _couche:
		_ecran._activer(_couche[nom])
		var occ: Dictionary = _ecran._occupees()
		if not occ.is_empty():
			_ecran._appliquer({"poser": {}, "effacer": occ}, "Dig")
	while not _ecran._eaux.is_empty():
		_ecran._retirer_eau(_ecran._eaux[0])
	_relief()
	var roche := {}
	var herbe := {}
	var sable := {}
	for k in _h:
		var h: int = _h[k]
		var m: String = _m[k]
		var fond := FOND_ROC if BOITE_ROC.has_point(k) else FOND_SOL
		for y in range(fond, h + 1):
			var c := Vector3i(k.x, y, k.y)
			if m == "herbe":
				herbe[c] = true
			elif m == "sable":
				sable[c] = true
			else:
				roche[c] = true
	print("monde : roche %d, herbe %d, sable %d" % [roche.size(), herbe.size(), sable.size()])
	# Vu de haut, tout le monde dans l'image ; chaque couche se pose en trois bandes, d'ouest en est.
	_poser_camera(Vector3(0, G, 0), 0.0, 1.2, 128.0)
	await _images(10)
	for etape in [["GreyRock", roche, "Layer 1 · GreyRock", "The rock zone, and the bedrock under everything"],
			["Grass", herbe, "Layer 2 · Grass", "The grass zone, west"],
			["Desert", sable, "Layer 3 · Desert", "The desert zone, and the paths"]]:
		_ecran._activer(_couche[etape[0]])
		_montrer(etape[2], etape[3])
		var tout: Dictionary = etape[1]
		for bande in 3:
			var x_a := X0 + bande * (X1 - X0 + 1) / 3
			var x_b := X0 + (bande + 1) * (X1 - X0 + 1) / 3
			var part := {}
			for c in tout:
				if c.x >= x_a and (c.x < x_b or bande == 2):
					part[c] = true
			_ecran._appliquer({"poser": part, "effacer": {}}, "Add")
			await _derive(0.6)
		await _derive(0.8)
	_ecran._activer(_couche["GreyRock"])
	await _ecran._reparer_les_diagonales(false)
	_montrer("3 zones", "And where two zones meet, they mix")
	await _derive(2.0)


## La caméra de haut dérive doucement vers le nord-est : le monde vit pendant qu'il se pose.
func _derive(duree: float) -> void:
	for i in int(duree * FPS):
		_vue._azimut += 0.0009
		_vue._caler()
		await _images(1)


## Le relief et la matière de chaque colonne : le sol de sa zone, les collines à falaises, le plateau, la bordure.
func _relief() -> void:
	_bruit.seed = 11
	_bruit.frequency = 0.09
	_taches.seed = 23
	_taches.frequency = 0.1
	for x in range(X0, X1 + 1):
		for z in range(Z0, Z1 + 1):
			var k := Vector2i(x, z)
			var p := Vector2(x + 0.5, z + 0.5)
			var m := _zone(p)
			var h: int = SOL[m]
			var bord := mini(mini(x - X0, X1 - x), mini(z - Z0, Z1 - z))
			var epaisseur := 3 + int(round(1.5 * (_bruit.get_noise_2d(x * 0.7, z * 0.7) + 1.0)))
			if bord < epaisseur:
				# La bordure : un rempart de roche bossu, qui ferme la carte comme celle d'un Zelda.
				h = 10 + int(round(1.2 * (_bruit.get_noise_2d(x * 1.3 + 50, z * 1.3) + 1.0)))
				m = "roche"
			elif _dans(p, PLATEAU, PLATEAU_R) or _sous_les_salles(k):
				h = PLATEAU_DESSUS
				m = "roche"
			elif Vector2(PUITS).distance_to(p) < CLAIRIERE:
				m = "roche"
				h = SOL["roche"]
			elif GROTTES.has_point(k):
				# ⚠ Au-dessus des salles et des tunnels, de la PURE roche : les formes ne creusent que la couche active.
				m = "roche"
				h = SOL["roche"]
			elif not _sur_un_chemin(p):
				for col in COLLINES:
					if _dans(p, col[0], col[1]):
						h = maxi(h, SOL[m] + int(col[2]))
			_h[k] = h
			_m[k] = m
	_sans_damier()
	_un_niveau_une_matiere()


## Deux colonnes voisines (diagonales comprises) au même niveau ont la même matière : chaque plage d'un même niveau prend
## la matière qui y domine.
func _un_niveau_une_matiere() -> void:
	var vu := {}
	var changees := 0
	for k0 in _h:
		if vu.has(k0):
			continue
		var plage := [k0]
		vu[k0] = true
		var i := 0
		var compte := {}
		while i < plage.size():
			var k: Vector2i = plage[i]
			i += 1
			compte[_m[k]] = int(compte.get(_m[k], 0)) + 1
			for dx in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					var n := k + Vector2i(dx, dz)
					if _h.has(n) and not vu.has(n) and _h[n] == _h[k0]:
						vu[n] = true
						plage.append(n)
		var meilleure := ""
		for m in compte:
			if meilleure == "" or compte[m] > compte[meilleure]:
				meilleure = m
		for k in plage:
			if _m[k] != meilleure:
				_m[k] = meilleure
				changees += 1
	print("un niveau, une matière : %d colonne(s) changée(s)" % changees)


## La zone de ce point : la plus proche (distances bruitées : des frontières organiques) ; dans la ceinture, des taches
## de la seconde, d'autant plus nombreuses qu'on approche de la frontière.
func _zone(p: Vector2) -> String:
	var ds := []
	var i := 0
	for nom in CENTRES:
		# ⚠ UN BRUIT PAR ZONE : le même, ajouté aux trois distances, s'annulait dans leur différence (troisième tournage :
		# des frontières droites, une ceinture vide).
		i += 1
		var d: float = (CENTRES[nom] as Vector2).distance_to(p) + 16.0 * _bruit.get_noise_2d(p.x * 0.5 + 300.0 * i, p.y * 0.5)
		ds.append([d, nom])
	ds.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	var w := clampf((ds[1][0] - ds[0][0]) / CEINTURE, 0.0, 1.0)
	# Le bruit simplex reste surtout entre -0,6 et 0,6 : étiré, pour que les taches soient franches.
	var t := clampf(0.5 + 0.8 * _taches.get_noise_2d(p.x, p.y), 0.0, 1.0)
	return ds[1][1] if t < 0.5 * (1.0 - w) else ds[0][1]


func _dans(p: Vector2, centre: Vector2, r: Vector2) -> bool:
	var d := (p - centre) / r
	return d.length() < 1.0 + 0.16 * _bruit.get_noise_2d(p.x * 1.6, p.y * 1.6)


## Les salles et leurs murs sont TOUJOURS sous le plateau, quel que soit le bruit de son contour.
func _sous_les_salles(k: Vector2i) -> bool:
	var s: Array = SALLE_2
	return k.x >= s[0].x - 3 and k.x <= s[1].x + 3 and k.y >= s[0].y - 3 and k.y <= s[1].y + 3


func _sur_un_chemin(p: Vector2) -> bool:
	for ch in CHEMINS:
		for i in ch.size() - 1:
			var a: Vector2 = ch[i]
			var b: Vector2 = ch[i + 1]
			var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
			if p.distance_to(a.lerp(b, t)) < LARGEUR_CHEMIN:
				return true
	return false


## ⚠ PAS DE DAMIER : dans un carré de 2 × 2 colonnes, si les deux diagonales sont l'une toute plus haute que l'autre, à
## un niveau les cases ne se touchent que par l'arête. On remonte la paire basse jusqu'au bas de la paire haute.
func _sans_damier() -> void:
	for passe in 30:
		var change := 0
		for x in range(X0, X1):
			for z in range(Z0, Z1):
				var a := Vector2i(x, z)
				var b := Vector2i(x + 1, z)
				var c := Vector2i(x, z + 1)
				var d := Vector2i(x + 1, z + 1)
				for paire in [[a, d, b, c], [b, c, a, d]]:
					var haut := mini(_h[paire[0]], _h[paire[1]])
					if haut > maxi(_h[paire[2]], _h[paire[3]]):
						for q in [paire[2], paire[3]]:
							_h[q] = maxi(_h[q], haut)
						change += 1
		if change == 0:
			print("relief sans damier après %d passe(s)" % (passe + 1))
			return
	print("⚠ des damiers restent dans le relief")


# ── 2. LES COLLINES : des escaliers de pierre taillés dans la falaise ──────────────────────────────

func _h_collines() -> void:
	# H1 est toute en herbe : l'escalier se taille dans la couche Grass (une matière par niveau, la sienne).
	_ecran._activer(_couche["Grass"])
	# La falaise sud du premier niveau de H1, puis celle du second : lues sur le relief, d'en bas vers le nord.
	var x := X_MONTEE
	var mur1 := _premier_plein(Vector3i(x, G + 2, 12), Vector3i(0, 0, -1))
	_poser_camera(Vector3(x + 0.5, G + 2, mur1.z), 0.0, 1.0, 26.0)
	await _images(15)
	await _cliquer_bouton("Stairs", "Special shape: Stairs, against the cliff")
	await _forme_au(_face(mur1, Vector3i(0, 0, 1)), "Stairs up the hill")
	var mur2 := _premier_plein(Vector3i(x, G + 4, mur1.z - 1), Vector3i(0, 0, -1))
	await _forme_au(_face(mur2, Vector3i(0, 0, 1)), "And up to the second level")
	# Les pieds : la rangée devant la dernière marche (l'escalier finit où il touche le sol).
	_pied_h1 = Vector3(x + 0.5, G + 1, _bout_d_escalier(Vector2i(x, mur1.z + 1), G) + 1.2)
	_pied_h1b = Vector3(x + 0.5, G + 3, _bout_d_escalier(Vector2i(x, mur2.z + 1), G + 2) + 1.2)
	print("H1 : murs %s %s, pieds %s %s" % [mur1, mur2, _pied_h1, _pied_h1b])
	await _images(int(0.8 * FPS))


## La dernière rangée de l'escalier, vers le sud : la première dont le dessus est au niveau du sol.
func _bout_d_escalier(depuis: Vector2i, sol: int) -> int:
	var occ: Dictionary = _ecran._occupees()
	var z := depuis.y
	while z < depuis.y + 12 and occ.has(Vector3i(depuis.x, sol + 1, z)):
		z += 1
	return z


# ── 3. LES GROTTES : les salles, le puits, les tunnels, l'escalier, la galerie, le balcon ──────────

func _h_grottes() -> void:
	_ecran._activer(_couche["GreyRock"])
	# Les salles, tracées sous la clairière et sous le plateau : invisibles du dehors.
	_regarder(Vector3(25, 62, 22), Vector3(25, 0, -20))
	await _images(15)
	await _cliquer_bouton("Room", "Special shape: Room")
	await _salle(SALLE_1, "A hall under the clearing")
	_salles["1"] = _vide_de(SALLE_1)
	await _salle(SALLE_A, "A middle room")
	_salles["A"] = _vide_de(SALLE_A)
	await _salle(SALLE_2, "A great hall under the plateau")
	_salles["2"] = _vide_de(SALLE_2)
	print("salles : %s" % [_salles])
	# Le puits : rond, taille 3, dans le sol de la clairière ; il s'arrête dans la salle du dessous.
	_regarder(Vector3(PUITS.x + 0.5, SOL["roche"] + 22, PUITS.y + 12), Vector3(PUITS.x + 0.5, SOL["roche"], PUITS.y + 0.5))
	await _images(12)
	await _cliquer_bouton("Well", "Well")
	await _cliquer_bouton("Round", "Profile: Round")
	await _touche(KEY_BRACKETRIGHT, "]", "Size 3")
	await _profondeur(20)
	await _forme_au(_face(Vector3i(PUITS.x, SOL["roche"], PUITS.y), Vector3i(0, 1, 0)), "A well in the ground")
	await _images(int(0.6 * FPS))
	# Dans la première salle : un tunnel en arche, de plain-pied, vers l'est.
	var s1: Array = _salles["1"]
	var y1: int = s1[0].y
	_regarder(Vector3(s1[0].x + 0.6, y1 + 2.2, Z_TUNNELS + 0.5), Vector3(s1[1].x + 1, y1 + 1.0, Z_TUNNELS + 0.5))
	await _images(15)
	await _cliquer_bouton("Tunnel", "Tunnel")
	await _cliquer_bouton("Arch", "Profile: Arch — a flat floor, a vault")
	await _touche(KEY_BRACKETLEFT, "[", "Size 2")
	await _profondeur(40)
	await _forme_au(_face(Vector3i(s1[1].x + 1, y1 + 1, Z_TUNNELS), Vector3i(-1, 0, 0)), "East, to the next room")
	var sa: Array = _salles["A"]
	_regarder(Vector3(sa[0].x + 0.6, y1 + 2.2, Z_TUNNELS + 0.5), Vector3(sa[1].x + 1, y1 + 1.0, Z_TUNNELS + 0.5))
	await _images(15)
	await _forme_au(_face(Vector3i(sa[1].x + 1, y1 + 1, Z_TUNNELS), Vector3i(-1, 0, 0)), "And on, under the plateau")
	# La grande salle : l'œil au fond nord, face au mur sud ; l'escalier y monte presque jusqu'au plafond.
	var s2: Array = _salles["2"]
	var b2: Vector3i = s2[0]
	var h2: Vector3i = s2[1]
	_arrivee = Vector3i(X_ESCALIER, h2.y - 2, h2.z + 1)
	# ⚠ LA FALAISE SE LIT AVANT DE CREUSER : après, la rangée de la galerie est vide jusqu'au dehors.
	# ⚠ DEPUIS LE PIED DU PLATEAU, pas depuis le bord sud : le rempart de la bordure serait trouvé d'abord.
	_sortie = _premier_plein(Vector3i(X_ESCALIER, _arrivee.y, -2), Vector3i(0, 0, -1))
	# ⚠ Le regard vise sous le palier (premier tournage : visé à mi-hauteur de la salle, le palier sortait par le HAUT de
	# l'image et le clic tombait sur un bouton du panneau).
	_regarder(Vector3(X_ESCALIER + 0.5, b2.y + 3.0, b2.z + 0.6), Vector3(X_ESCALIER + 0.5, _arrivee.y - 1.0, h2.z + 1))
	await _images(15)
	await _cliquer_bouton("Stairs", "Stairs, inside the great hall")
	await _champ(_ecran._pas_forme, 1, "Step", "1 row per step: steep")
	await _forme_au(_face(_arrivee, Vector3i(0, 0, -1)), "Stairs up the south wall")
	await _cliquer_bouton("Tunnel", "Tunnel")
	await _forme_au(_face(_arrivee + Vector3i(0, 2, 0), Vector3i(0, 0, -1)), "From the landing, out through the cliff")
	# Dehors : un balcon à la bouche de la galerie, à fleur de son sol.
	_regarder(Vector3(_sortie) + Vector3(0.5, 9, 16), Vector3(_sortie) + Vector3(0.5, 0.5, 0.5))
	await _images(15)
	await _cliquer_bouton("Balcony", "Balcony")
	await _profondeur(3)
	await _forme_au(_face(_sortie, Vector3i(0, 0, 1)), "A balcony over the map")
	print("arrivée %s, sortie %s" % [_arrivee, _sortie])
	await _images(int(0.8 * FPS))


func _vide_de(s: Array) -> Array:
	return _boite_vide(s[0].x, s[1].x, s[0].y, s[1].y, s[2], s[2] + s[3] + 2)


## LE CHEMIN QU'IL PEUT VRAIMENT FAIRE, calculé sur le relief : de colonne en colonne (diagonales comprises si les deux
## voisines droites passent aussi), jamais plus d'UNE case à monter (un saut), descendre autant qu'on veut. ⚠ Dans les
## zones mêlées, roche (7) et sable (5) font des marches de DEUX cases : au quatrième tournage, il y restait bloqué.
## Rend un point toutes les 3 colonnes, et l'arrivée.
func _route(de: Vector2, a: Vector2) -> Array:
	var depart := Vector2i(floori(de.x), floori(de.y))
	var but := Vector2i(floori(a.x), floori(a.y))
	var avant := {depart: depart}
	var file := [depart]
	var i := 0
	while i < file.size():
		var c: Vector2i = file[i]
		i += 1
		if c == but:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			var n: Vector2i = c + d
			if avant.has(n) or not _passe(c, n):
				continue
			if d.x != 0 and d.y != 0 and not (_passe(c, c + Vector2i(d.x, 0)) and _passe(c, c + Vector2i(0, d.y))):
				continue
			avant[n] = c
			file.append(n)
	if not avant.has(but):
		print("⚠ pas de chemin de %s à %s" % [depart, but])
		return [_sol_de(a.x, a.y)]
	var cases := [but]
	while cases[0] != depart:
		cases.push_front(avant[cases[0]])
	var points := []
	for j in range(3, cases.size() - 1, 3):
		points.append(_sol_de(cases[j].x + 0.5, cases[j].y + 0.5))
	points.append(_sol_de(a.x, a.y))
	print("chemin de %s à %s : %d colonnes" % [depart, but, cases.size()])
	return points


func _passe(c: Vector2i, n: Vector2i) -> bool:
	return _h.has(n) and int(_h[n]) - int(_h[c]) <= 1 and Vector2(n).distance_to(Vector2(PUITS)) > 3.0


## Le point où l'on marche au-dessus de la colonne (x, z) du relief posé (les formes n'y sont pas).
func _sol_de(x: float, z: float) -> Vector3:
	return Vector3(x, int(_h.get(Vector2i(floori(x), floori(z)), G)) + 1, z)


## Un champ numérique du panneau : un clic dedans, Ctrl+A, le nombre tapé, Entrée.
func _champ(boite: SpinBox, n: int, carte: String, detail: String) -> void:
	var champ: LineEdit = boite.get_line_edit()
	if not champ.is_visible_in_tree():
		print("⚠ le champ %s n'est pas visible" % carte)
		return
	await _bouger(champ.get_global_rect().get_center(), 0.5)
	await _clic(MOUSE_BUTTON_LEFT, carte, detail)
	_cle(KEY_A, true, true)
	_cle(KEY_A, false, true)
	for ch in str(n):
		var e := InputEventKey.new()
		e.keycode = KEY_0 + int(ch)
		e.physical_keycode = e.keycode
		e.unicode = ch.unicode_at(0)
		e.pressed = true
		_envoyer(e)
		var r: InputEventKey = e.duplicate()
		r.pressed = false
		_envoyer(r)
		await _images(3)
	_cle(KEY_ENTER, true)
	_cle(KEY_ENTER, false)
	await _images(10)
	print("%s : %d" % [carte, int(boite.value)])


# ── 4. LE JEU, VU DE HAUT ───────────────────────────────────────────────────────────────────────────

func _h_jeu() -> void:
	_vue._cible = _sol_de(-34.5, 8.5)
	_cam_haut = true
	_cam_d = 8.0
	_cam_e = 1.05
	await _cliquer_bouton("Play test", "Play test, seen from above")
	# La souris quitte l'image (deuxième tournage : le curseur restait posé sur le bouton Play test tout le jeu).
	await _bouger(Vector2(root.size.x + 40, root.size.y + 40), 0.3)
	await _images(int(0.5 * FPS))
	# Un soleil haut et franc, comme dans un jeu vu de haut : des ombres courtes, des couleurs nettes.
	_montrer("Render", "A high sun, short shadows")
	for reglage in [["soleil_hauteur", 58.0], ["soleil_azimut", 160.0], ["soleil_energie", 1.3], ["glow", true]]:
		_vue.regler_rendu(reglage[0], reglage[1])
		await _images(3)
	await _images(int(1.2 * FPS))
	var p: CharacterBody3D = _vue.personnage
	if p == null:
		print("⚠ pas de personnage")
		return
	print("taille du stickman : %.2f" % p.taille)
	# La colline : l'escalier, le second niveau, puis on saute des rebords vers l'est.
	await _aller([Vector3(_pied_h1.x, G + 1, _pied_h1.z + 4), _pied_h1], "W A S D", "Eight directions, like a Zelda")
	await _aller([Vector3(_pied_h1.x, G + 3, _pied_h1b.z + 2), _pied_h1b], "Space", "Up the stairs", true)
	await _aller([Vector3(_pied_h1.x, G + 5, _pied_h1b.z - 5)], "Space", "Up to the top", true)
	await _aller([_sol_de(-18.5, -10.5), _sol_de(-12.5, -9.5)], "W A S D", "Hop down the ledges", true)
	# Le chemin, à travers la zone mêlée herbe / roche, jusqu'à la clairière.
	await _aller(_route(Vector2(-12.5, -9.5), Vector2(4.5, -19.5)), "W A S D", "Grass gives way to rock, a level up", true)
	# Le puits : on tombe dedans. La caméra plonge avec lui.
	# ⚠ LA CAMÉRA VERTICALE, au-dessus du trou : penchée (1,35), son bras butait contre la paroi du puits et elle finissait
	# DANS la tête du stickman (quatrième tournage). Droite, elle reste dehors et le regarde tomber dans le noir.
	_cam_d = 8.0
	_cam_e = 1.5
	await _aller([_sol_de(PUITS.x + 0.5, PUITS.y + 0.5)], "W A S D", "Into the well")
	for i in int(4 * FPS):
		if p.is_on_floor() and p.global_position.y < SOL["roche"] - 2:
			break
		await _images(1)
	print("au fond du puits : %s" % p.global_position)
	# ⚠ SOUS TERRE, LE PLAY TEST EST NOIR avec ses réglages par défaut (leçon du devlog des galeries) : SSAO et SSIL
	# coupées, l'ambiante et l'exposition montées. Ce sont des réglages de la barre Render, que l'utilisateur a aussi.
	_montrer("Render", "More light for the caves")
	_vue.regler_rendu("ssao", false)
	_vue.regler_rendu("ssil", false)
	_vue.regler_rendu("ambiante_energie", 2.4)
	_vue.regler_rendu("exposition", 1.3)
	_cam_haut = false
	# ⚠ À 2,6 (la distance par défaut du petit stickman), il remplissait l'image dans l'escalier (deuxième tournage).
	_cam_d = 3.8
	_cam_e = 0.5
	var s1: Array = _salles["1"]
	var s2: Array = _salles["2"]
	var y0: float = s1[0].y
	var zt := Z_TUNNELS + 0.5
	var xs := X_ESCALIER + 0.5
	await _aller([Vector3(s1[1].x + 0.5, y0, zt), Vector3(s2[0].x + 1.5, y0, zt), Vector3(xs, y0, s2[0].z + 0.8)],
		"W A S D", "Tunnels and rooms")
	await _aller([Vector3(xs, _arrivee.y + 1, _arrivee.z - 0.6)], "Space", "Up the stairs, a jump per step", true)
	# ⚠ LE SOL DE LA GALERIE EST UNE MARCHE AU-DESSUS DU PALIER (deuxième tournage : il restait au pied) : un saut.
	await _aller([Vector3(xs, _arrivee.y + 1, _sortie.z + 1.5)], "W A S D", "Out through the cliff", true)
	await _regarder_autour(3.0)
	# Le balcon : un saut par-dessus son rebord, et l'on retombe sur la carte. La caméra remonte au-dessus de lui.
	_vue.regler_rendu("ssao", true)
	_vue.regler_rendu("ssil", true)
	_vue.regler_rendu("ambiante_energie", 1.1)
	_vue.regler_rendu("exposition", 1.0)
	_cam_haut = true
	_cam_d = 8.0
	_cam_e = 1.05
	await _aller([_sol_de(xs, _sortie.z + 6.5)], "Space", "Over the rail, back on the map", true)
	await _aller(_route(Vector2(xs, _sortie.z + 6.5), Vector2(30.5, 21.5)), "W A S D",
		"South: rock gives way to sand, a level down", true)
	await _images(int(0.6 * FPS))
	# La fin : la caméra s'élève au-dessus de tout le monde.
	_montrer("Mouse wheel", "The whole map")
	# Verticale, elle aussi : penchée, le bras butait contre un rebord et l'image devenait la tête du stickman.
	_cam_d = 80.0
	_cam_e = 1.5
	await _images(int(4.5 * FPS))
	await _touche(KEY_ESCAPE, "Esc", "Back to World")


## Le stickman va de point en point. VU DE HAUT (`_cam_haut`), la caméra ne tourne pas : W A S D seules ou par deux, l'une
## des huit directions la plus proche du point visé. SOUS TERRE, la caméra se tourne vers le point et W suffit.
## `sauter` : un saut quand le point est plus haut, ou quand il n'avance plus (une marche, un rebord).
func _aller(points: Array, carte: String, detail: String, sauter := false) -> void:
	var p: CharacterBody3D = _vue.personnage
	if p == null:
		print("⚠ pas de personnage")
		return
	_montrer(carte, detail)
	var depuis_saut := 99
	var repere := p.global_position
	for cible in points:
		for i in int(25 * FPS):
			var d: Vector3 = cible - p.global_position
			var plat := Vector2(d.x, d.z)
			if plat.length() < 0.4:
				break
			var u := plat.normalized()
			if not _cam_haut:
				_vue._azimut = lerp_angle(_vue._azimut, atan2(-u.x, -u.y), 0.22)
			_touches_vers(u)
			depuis_saut += 1
			if i % 6 == 0:
				var coince := p.global_position.distance_to(repere) < 0.08 and i > 0
				repere = p.global_position
				if sauter and depuis_saut >= 10 and (d.y > 0.3 or coince):
					depuis_saut = 0
					_cle(KEY_SPACE, true)
					await _images(2)
					_cle(KEY_SPACE, false)
			await _images(1)
		var reste := Vector2(cible.x - p.global_position.x, cible.z - p.global_position.z).length()
		print("%s %s : stickman en %s" % ["point atteint" if reste < 0.5 else "⚠ POINT MANQUÉ", cible, p.global_position])
	for k in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_cle(k, false)
	await _images(6)


## Les touches qui mènent vers `u` (à plat, x et z du monde), dans le repère de la caméra : avant = son regard aplati.
func _touches_vers(u: Vector2) -> void:
	var az: float = _vue._azimut
	var avant := Vector2(-sin(az), -cos(az))
	var droite := Vector2(cos(az), -sin(az))
	var f := u.dot(avant)
	var r := u.dot(droite)
	_cle(KEY_W, f > 0.38)
	_cle(KEY_S, f < -0.38)
	_cle(KEY_D, r > 0.38)
	_cle(KEY_A, r < -0.38)


## Un regard autour, à la bouche de la galerie (la caméra derrière lui, qui tourne).
func _regarder_autour(duree: float) -> void:
	var n := int(duree * FPS)
	var a0: float = _vue._azimut
	for i in n:
		_vue._azimut = a0 + 0.9 * sin(TAU * float(i) / float(n - 1))
		await _images(1)


## Comme `filmer_ui._images`, mais la caméra du Play test est celle de CE tournage : elle glisse vers la distance et
## l'élévation voulues, et, vue de haut, vers le nord (azimut 0).
func _images(n: int) -> void:
	for i in n:
		await process_frame
		_image += 1
		_carte_age += 1.0 / FPS
		if _ecran != null and _ecran._atelier == "jeu" and _vue != null:
			_vue._distance = lerpf(_vue._distance, _cam_d, 0.06)
			_vue._elevation = lerpf(_vue._elevation, _cam_e, 0.06)
			if _cam_haut:
				_vue._azimut = lerp_angle(_vue._azimut, 0.0, 0.06)
		if _dessin != null:
			_dessin.queue_redraw()
