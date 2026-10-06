extends "res://DEV_TOOLS/filmer_ui.gd"
##
## LE DEVLOG DES FORMES SPÉCIALES — demandé par Jordan (5 octobre 2026) : « l'utilisation de toutes les special shapes,
## d'abord isolément contre des massifs, puis creusage intelligent de galeries, de puits, escaliers dans des rooms, un
## monde rempli de passages secrets créés à la main […] tunnels derrière des cascades traversés en navigation, pareil
## pour des puits sous la mer dans un sol à une case sous la mer, et des montagnes organiques et bossues imbriquées en
## étages. »
##
## Les gestes sont ceux de `filmer_ui.gd` (dont ce script hérite) : de VRAIS événements, la souris sur le bouton, la
## touche frappée ; le curseur et la carte de la touche sont les deux seules aides dessinées par-dessus.
## ⚠ LES FORMES N'AGISSENT QUE SUR LA COUCHE ACTIVE (`_occupees_actives`) : tout ce qui se creuse est dans GreyRock,
## et l'herbe ne coiffe que la prairie (un puits sous un toit d'herbe s'arrêterait sous l'herbe).
##
## LANCEMENT — dans la COPIE de tournage :
##   cp D:/MarchingBlocks/DEV_TOOLS/filmer_*.gd D:/MarchingBlocks_tournage/DEV_TOOLS/
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks_tournage --fixed-fps 30 \
##       --write-movie D:/SpannerGames/PROJETS/MarchingBlocks/02_rushes/formes.avi --script res://DEV_TOOLS/filmer_formes.gd
##   `-- --seulement=<partie>` : monde, isolees, montagne, secrets.

## LE MONDE — une règle, un endroit.
const MER := 5                     # la mer : une seule case d'eau au-dessus du fond (fond à MER - 1)
const PRAIRIE := 6                 # le dessus de la prairie
const FOND := -8                   # le bas de la roche : des salles peuvent se creuser sous la prairie et sous la mer
const X_MIN := -44
const X_MAX := 44
const Z_MER := -17                 # la mer au nord de z = -17 ; la prairie au sud
const Z_MIN := -46
const Z_MAX := 44
## Les six massifs de la première partie : x du centre, sur une rangée en z = 30..37, de y = 7 à 18.
const MASSIFS := [-33, -20, -7, 6, 19, 32]
const MASSIF_Z := Vector2i(30, 37)
const MASSIF_HAUT := 18
## La montagne organique : des bosses imbriquées en étages (centre, rayons) ; une mare au sommet, sa cascade au sud.
const ECHELLE := 1.35              # « une grosse montagne » (Jordan) : les bosses dessinées, agrandies
const BOSSES := [
	[Vector3(0, 7, 4), Vector3(20, 9, 15)],
	[Vector3(-5, 15, 0), Vector3(14, 7, 11)],
	[Vector3(4, 21, 5), Vector3(9, 6, 8)],
	[Vector3(-3, 27, 2), Vector3(5, 5, 5)],
	[Vector3(14, 12, -4), Vector3(7, 6, 6)],
	[Vector3(-16, 11, 9), Vector3(6, 5, 6)],
	[Vector3(7, 16, 14), Vector3(6, 4, 5)],
]
const MARE := Vector3i(5, 30, 7)   # le fond de la mare du sommet
## Les salles creusées par le film (rectangle sur la grille de l'étage : x0, z0, x1, z1 ; étage ; hauteur).
const SALLE_MONTAGNE := [Vector2i(-8, -6), Vector2i(8, 8), 8, 5]   # grande : un intérieur se lit
const SALLE_SOUS_SOL := [Vector2i(-4, -2), Vector2i(4, 4), -5, 3]
const SALLE_SOUS_MER := [Vector2i(-22, -36), Vector2i(-12, -28), -5, 3]
const SALLE_MASSIF := [Vector2i(29, 31), Vector2i(34, 35), 9, 4]
const Z_TUNNEL := -1               # le tunnel qui traverse la montagne d'ouest en est

var _bruit3 := FastNoiseLite.new()


func _derouler() -> void:
	await _images(30)
	await _ecran._ouvrir(_chemin)
	_ecran._changer_d_atelier("monde")
	_ecran._legende_formes.basculer(false, false)
	_vue = _ecran._vue
	for i in _ecran._couches.size():
		_couche[str(_ecran._couches[i].get("nom", ""))] = i
	await _batir()
	_ecran._activer(_couche["GreyRock"])
	_aides()
	await _images(20)
	if _seulement == "sonde":
		_colonne_de_la_cascade()
	for partie in ["monde", "isolees", "montagne", "secrets"]:
		# « monde » (le survol de mise au point) ne tourne que demandé.
		if (_seulement == "" and partie == "monde") or (_seulement != "" and _seulement != partie):
			continue
		_plan(partie)
		await Callable(self, "_partie_" + partie).call()
		await _images(int(0.6 * FPS))
	_plan("fin")
	_rendre_les_reglages()
	quit(0)


# ── LES PARTIES ──────────────────────────────────────────────────────────────────────────────────────

## Le monde entier, en orbite : la mise au point de la construction.
func _partie_monde() -> void:
	for vue in [[Vector3(0, 10, 0), 0.3, 0.6, 110.0], [Vector3(0, 14, 4), 0.2, 0.25, 55.0],
			[Vector3(0, 12, 33), 0.1, 0.35, 60.0], [Vector3(0, 4, -30), 2.8, 0.45, 50.0]]:
		_poser_camera(vue[0], vue[1], vue[2], vue[3])
		var az: float = vue[1]
		for i in int(3.0 * FPS):
			_vue._azimut = az + 0.25 * _doux(i / (3.0 * FPS))
			_vue._caler()
			await _images(1)


## 1. ISOLÉMENT, CONTRE DES MASSIFS : chaque forme, ses réglages, son aperçu (rouge : creusé ; vert : posé).
func _partie_isolees() -> void:
	var face := MASSIF_Z.y + 1
	# Le Tunnel : trois profils.
	var m: int = MASSIFS[0]
	_poser_camera(Vector3(m, 12, face), 0.45, 0.22, 30.0)
	await _images(15)
	await _cliquer_bouton("Tunnel", "Special shape: Tunnel")
	for profil in [["Round", 15.5, -2], ["Arch", 9.5, 0], ["Square", 15.5, 2]]:
		await _cliquer_bouton(profil[0], "Profile: " + profil[0])
		await _forme_au(Vector3(m + profil[2], profil[1], face + 0.05), "A tunnel straight into the wall")
	await _images(int(0.8 * FPS))
	# Le Puits, dans le dessus.
	m = MASSIFS[1]
	_poser_camera(Vector3(m, MASSIF_HAUT, 33), 0.3, 0.85, 26.0)
	await _images(15)
	await _cliquer_bouton("Well", "Special shape: Well")
	await _cliquer_bouton("Round", "Profile: Round")
	await _forme_au(Vector3(m, MASSIF_HAUT + 1.05, 33.5), "A well straight down")
	await _images(int(0.8 * FPS))
	# Le Pont, en « Connect » : deux parois qui ne se font pas face — le tablier se plie.
	_poser_camera(Vector3(-0.5, 13, 34), 0.15, 0.3, 30.0)
	await _images(15)
	await _cliquer_bouton("Bridge", "Special shape: Bridge")
	await _cliquer_bouton("Connect", "Connect: two clicks, two walls")
	await _forme_au(Vector3(MASSIFS[2] + 4.05, 16.5, 33.5), "First wall")
	await _forme_au(Vector3(MASSIFS[3] - 4.05, 11.5, 34.5), "Second wall: the deck bends")
	await _cliquer_bouton("Straight", "Straight: one click")
	await _images(int(0.6 * FPS))
	# Le Balcon.
	m = MASSIFS[3]
	_poser_camera(Vector3(m, 14, face), -0.35, 0.25, 26.0)
	await _images(10)
	await _cliquer_bouton("Balcony", "Special shape: Balcony")
	await _forme_au(Vector3(m, 15.5, face + 0.05), "A balcony, with its rail")
	await _images(int(0.6 * FPS))
	# L'Escalier.
	m = MASSIFS[4]
	_poser_camera(Vector3(m, 12, face + 4), 0.7, 0.3, 30.0)
	await _images(10)
	await _cliquer_bouton("Stairs", "Special shape: Stairs")
	await _forme_au(Vector3(m, 16.5, face + 0.05), "Stairs come down to the ground")
	await _images(int(0.8 * FPS))
	# La Salle : tracée sur la grille, DANS la roche — elle s'y creuse, invisible ; un tunnel la trouve.
	m = MASSIFS[5]
	_poser_camera(Vector3(m, 12, 33), 0.5, 0.55, 30.0)
	await _images(10)
	await _cliquer_bouton("Room", "Special shape: Room")
	await _salle(SALLE_MASSIF, "A room dug INSIDE the rock")
	await _cliquer_bouton("Tunnel", "Tunnel")
	await _cliquer_bouton("Arch", "Profile: Arch")
	_poser_camera(Vector3(m, 11, face), 0.35, 0.2, 24.0)
	await _images(10)
	await _forme_au(Vector3(m - 1, 10.5, face + 0.05), "The tunnel stops in the first room it finds")
	var zs: float = SALLE_MASSIF[0].y + 0.5
	await _naviguer([[Vector3(m - 0.5, 11, face + 14), Vector3(m - 0.5, 10.5, face)],
		[Vector3(m - 0.5, 11, face + 1.5), Vector3(m - 0.5, 10.8, face - 6)],
		[Vector3(m - 0.5, 11, SALLE_MASSIF[1].y + 0.5), Vector3(m - 0.5, 10.8, zs)],
		[Vector3(m - 0.5, 11.5, SALLE_MASSIF[1].y + 0.5), Vector3(SALLE_MASSIF[0].x, 10, zs)]], 7.0)


## 2. LA GROSSE MONTAGNE : une grande salle au cœur, un tunnel de part en part, un tunnel derrière la cascade, un puits
## du sommet, escalier et balcon DEDANS, une crypte sous la prairie ; puis on vole de part en part.
func _partie_montagne() -> void:
	# ⚠ LA SALLE SE CALE SUR LA CASCADE : le tunnel creusé derrière l'eau (au milieu de sa chute) doit y mener. Au
	# premier essai, la salle était plus bas que la chute, et le tunnel « derrière la cascade » ne passait derrière rien.
	var chute := _colonne_de_la_cascade()
	var s: Array = SALLE_MONTAGNE.duplicate()
	s[2] = chute.y - 1
	_poser_camera(Vector3(0, 14, 6), 0.3, 0.5, 75.0)
	await _images(15)
	await _cliquer_bouton("Room", "Special shape: Room")
	await _salle(s, "A great hall in the heart of the mountain")
	var boite := _boite_vide(s[0].x, s[1].x, s[0].y, s[1].y, s[2] - 1, s[2] + s[3] + 2)
	var bas: Vector3i = boite[0]
	var haut: Vector3i = boite[1]
	print("salle de la montagne : %s" % [boite])
	# Le tunnel de part en part, d'ouest en est, SOUS la salle (Depth 64) : au-dessus, il sortait au sommet. Les deux
	# bouches se lisent AVANT de creuser (après, la rangée est vide de bout en bout).
	var y_t: int = bas.y - 7
	var ouest := _premier_plein(Vector3i(-48, y_t, Z_TUNNEL), Vector3i(1, 0, 0))
	var est := _premier_plein(Vector3i(48, y_t, Z_TUNNEL), Vector3i(-1, 0, 0))
	await _cliquer_bouton("Tunnel", "Tunnel")
	await _cliquer_bouton("Arch", "Profile: Arch")
	await _profondeur(64)
	_regarder(Vector3(ouest) + Vector3(-22, 6, 10), Vector3(ouest) + Vector3(0, 0, 0))
	await _images(10)
	await _forme_au(_face(ouest, Vector3i(-1, 0, 0)), "Right through the mountain")
	# Derrière la cascade : la colonne où l'eau de la mare TOMBE (lue dans le calcul de l'eau), le tunnel juste derrière.
	var y_c: int = chute.y
	var sud := _premier_plein(Vector3i(chute.x, y_c, chute.z), Vector3i(0, 0, -1))
	print("cascade en %s, paroi derrière en %s" % [chute, sud])
	await _profondeur(40)
	_regarder(Vector3(sud) + Vector3(7, 4, 14), Vector3(sud) + Vector3(0.5, 1, 0.5))
	await _images(15)
	await _forme_au(_face(sud, Vector3i(0, 0, 1)), "Behind the waterfall, a hidden tunnel")
	# Le puits du sommet, droit dans la salle.
	var sommet := _premier_plein(Vector3i(-2, 48, 4), Vector3i(0, -1, 0))
	_regarder(Vector3(sommet) + Vector3(10, 14, 12), Vector3(sommet))
	await _images(10)
	await _cliquer_bouton("Well", "Well")
	await _cliquer_bouton("Round", "Profile: Round")
	await _forme_au(_face(sommet, Vector3i(0, 1, 0)), "A shaft from the summit into the hall")
	# La crypte, sous la prairie, sous la salle.
	await _cliquer_bouton("Room", "Room")
	_poser_camera(Vector3(0, 0, 4), 0.3, 0.6, 55.0)
	await _salle(SALLE_SOUS_SOL, "A crypt below the hall")
	# DEDANS. ⚠ AU PREMIER TOURNAGE, L'ESCALIER ET LE BALCON ONT ÉTÉ REFUSÉS (aperçu rouge) : leur point visé, une case
	# sous le plafond, sortait du HAUT DE L'IMAGE — le clic tombait sur le plafond, une face horizontale, et
	# l'escalier veut une PAROI (`pas_de_paroi`). L'œil est maintenant au fond sud, à hauteur d'homme, face au mur nord,
	# et chaque point visé est vérifié DANS l'image avant le clic (`_dans_l_image`).
	var cx_s := (bas.x + haut.x) * 0.5 + 0.5
	_regarder(Vector3(cx_s, bas.y + 2.6, haut.z + 0.4), Vector3(cx_s, bas.y + 2.2, bas.z))
	await _images(20)
	var arrivee := Vector3i(bas.x + 5, bas.y + 3, bas.z - 1)   # la case du mur nord où l'escalier arrive
	await _cliquer_bouton("Stairs", "Stairs, inside the hall")
	await _forme_au(_face(arrivee, Vector3i(0, 0, 1)), "Stairs up the north wall")
	# Au palier, une porte : un tunnel droit dans le mur nord, juste au-dessus de l'arrivée — une galerie.
	await _cliquer_bouton("Tunnel", "Tunnel")
	await _cliquer_bouton("Arch", "Profile: Arch")
	await _forme_au(_face(arrivee + Vector3i(0, 1, 0), Vector3i(0, 0, 1)), "From the landing, a gallery")
	# Un balcon sur le mur est (à droite dans l'image), à mi-hauteur.
	await _cliquer_bouton("Balcony", "Balcony, inside")
	# Vers le fond de la salle : plus près, le mur est sortait du bord droit de l'image (vu au tournage).
	await _forme_au(_face(Vector3i(haut.x + 1, bas.y + 3, bas.z + 1), Vector3i(-1, 0, 0)), "A gallery on the east wall")
	await _cliquer_bouton("Well", "Well, down")
	await _forme_au(_face(Vector3i(1, bas.y - 1, (bas.z + haut.z) / 2), Vector3i(0, 1, 0)), "Down into the crypt")
	await _images(int(0.6 * FPS))
	# NAVIGATE : de part en part dans le tunnel d'ouest en est.
	var yv := float(y_t) + 1.0
	var zt := float(Z_TUNNEL) + 0.5
	await _naviguer([[Vector3(ouest.x - 18, yv + 4, zt + 6), Vector3(ouest.x, yv, zt)],
		[Vector3(ouest.x - 2, yv, zt), Vector3(ouest.x + 10, yv, zt)],
		[Vector3(est.x + 1, yv, zt), Vector3(est.x + 12, yv, zt)],
		[Vector3(est.x + 14, yv + 5, zt + 8), Vector3(est.x, yv, zt)]], 10.0)
	# NAVIGATE : à travers la cascade, le tunnel, jusqu'à la salle ; on lève les yeux dans le puits.
	var yc := float(y_c) + 1.0
	var cx := float(sud.x) + 0.5
	var centre := (Vector3(bas) + Vector3(haut) + Vector3.ONE) * 0.5
	await _naviguer([[Vector3(cx, yc + 3, sud.z + 18), Vector3(cx, yc, sud.z)],
		[Vector3(cx, yc, sud.z + 3), Vector3(cx, yc, sud.z - 6)],
		[Vector3(cx, yc, haut.z + 1.5), Vector3(cx, yc, bas.z)],
		[Vector3(cx, yc + 1, haut.z - 1), Vector3(bas.x, bas.y + 1, bas.z)],
		[centre + Vector3(0, -0.5, 1), Vector3(-2.5, centre.y + 8, 4.5)]], 12.0)


## 3. SOUS LA MER : un fond à une case sous l'eau, une salle sous le fond, des puits qui la noient ; on y plonge.
func _partie_secrets() -> void:
	var s: Array = SALLE_SOUS_MER
	var cx: int = (s[0].x + s[1].x) / 2
	var cz: int = (s[0].y + s[1].y) / 2
	_regarder(Vector3(cx - 16, MER + 20, cz - 22), Vector3(cx, s[2], cz))   # au nord, au-dessus de la mer (au sud : dans la montagne)
	await _images(15)
	await _cliquer_bouton("Room", "Special shape: Room")
	await _salle(s, "A room under the seabed")
	await _cliquer_bouton("Well", "Well")
	await _cliquer_bouton("Round", "Profile: Round")
	_regarder(Vector3(cx + 10, MER + 14, cz + 16), Vector3(cx, MER, cz))
	await _images(10)
	await _forme_au(Vector3(cx + 0.5, MER + 0.02, cz + 0.5), "A well in the seabed: the sea pours in")
	await _cliquer_bouton("Square", "Profile: Square")
	await _forme_au(Vector3(s[0].x + 2.5, MER + 0.02, s[0].y + 2.5), "A second shaft")
	await _ecran._recalculer_eau(false)
	await _images(int(1.5 * FPS))
	var fond: float = s[2] + 1.5
	await _naviguer([[Vector3(cx + 6.5, MER + 8, cz + 8.5), Vector3(cx + 0.5, MER, cz + 0.5)],
		[Vector3(cx + 0.5, MER + 2, cz + 0.6), Vector3(cx + 0.5, MER - 6, cz + 0.5)],
		[Vector3(cx + 0.5, fond + 0.5, cz + 0.6), Vector3(cx + 0.5, fond - 6, cz + 0.5)],
		[Vector3(cx + 0.5, fond, cz + 0.5), Vector3(s[0].x, fond, s[0].y)],
		[Vector3(cx + 0.5, fond, cz + 0.5), Vector3(s[1].x + 1, fond, s[1].y + 1)]], 10.0)
	# ⚠ VUE DE L'ÉDITEUR, UNE SALLE NOYÉE A L'AIR SÈCHE (l'eau ne se dessine qu'à sa surface, et il n'y en a pas
	# dedans). Le Play test, lui, met le VOILE sous l'eau : le personnage apparaît dans la salle, et il y nage.
	_vue._cible = Vector3(cx + 0.5, fond, cz + 0.5)
	await _cliquer_bouton("Play test", "Play test: the room is flooded")
	await _images(int(1.0 * FPS))
	await _tenir(KEY_W, 2.5, "W A S D", "Swim")
	await _tenir_avec(KEY_W, KEY_SPACE, 1.5, "Space", "Swim up the shaft")
	await _touche(KEY_ESCAPE, "Esc", "Back to World")


# ── LES GESTES DES FORMES ────────────────────────────────────────────────────────────────────────────

## La souris sur un point du monde, l'aperçu le temps de le lire, puis le clic.
func _forme_au(point: Vector3, detail: String) -> void:
	_dans_l_image(point, detail)
	await _bouger(_sur(point), 0.7)
	await _images(int(0.7 * FPS))
	var dessous := root.gui_get_hovered_control()
	if dessous != _vue and not _vue.is_ancestor_of(dessous):
		print("⚠ sous la souris : %s, pas la vue (%s)" % [dessous, detail])
	print("clic « %s » en %s sur %s" % [detail, _souris, dessous])
	await _clic(MOUSE_BUTTON_LEFT, "Click", detail)
	# La souris quitte la vue : l'aperçu de la forme suivante couvrait ce qui vient d'être fait. Elle va au COIN bas droit :
	# posée sur un bouton du panneau, son infobulle s'ouvrait, et (hypothèse du 6 octobre 2026) le clic suivant dans la
	# vue ne servait qu'à la fermer — trois sources d'eau sur quatre n'étaient pas posées.
	await _bouger(Vector2(root.size.x - 3, root.size.y - 3), 0.5)
	await _images(int(0.5 * FPS))


## Une salle : la grille à son étage (PgUp / PgDn), sa hauteur ([ ]), puis le rectangle tiré sur la grille.
func _salle(s: Array, detail: String) -> void:
	if _vue.visee != "grille":
		await _touche(KEY_TAB, "Tab", "Grid aim: the floor grid")
	var y: int = s[2]
	var avant := int(_ecran._compteur_etage.value)
	if avant != y:
		_montrer("PgUp / PgDn", "Floor grid at y = %d" % y)
		for i in absi(y - avant):
			_cle(KEY_PAGEUP if y > avant else KEY_PAGEDOWN, true)
			_cle(KEY_PAGEUP if y > avant else KEY_PAGEDOWN, false)
			await _images(2)
	for essai in 12:
		if int(_ecran._etages_forme.value) == s[3]:
			break
		var plus: bool = int(_ecran._etages_forme.value) < s[3]
		await _touche(KEY_BRACKETRIGHT if plus else KEY_BRACKETLEFT, "]" if plus else "[",
			"Room height: %d" % s[3])
	var a := Vector3(s[0].x + 0.5, y, s[0].y + 0.5)
	var b := Vector3(s[1].x + 0.5, y, s[1].y + 0.5)
	await _bouger(_sur(a), 0.6)
	_montrer("Left drag", detail)
	_presser(MOUSE_BUTTON_LEFT, true)
	await _bouger(_sur(b), 1.4)
	await _images(int(0.5 * FPS))
	_presser(MOUSE_BUTTON_LEFT, false)
	await _images(int(1.0 * FPS))


## La profondeur d'un tunnel ou d'un puits : un clic dans le champ, Ctrl+A, le nombre tapé, Entrée.
func _profondeur(n: int) -> void:
	var champ: LineEdit = _ecran._longueur_forme.get_line_edit()
	if not champ.is_visible_in_tree():
		print("⚠ le champ Depth n'est pas visible")
		return
	await _bouger(champ.get_global_rect().get_center(), 0.5)
	await _clic(MOUSE_BUTTON_LEFT, "Depth", "%d cells" % n)
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
	print("profondeur : %d" % int(_ecran._longueur_forme.value))


## NAVIGATE (Espace) : l'œil vole de point en point — [œil, ce qu'il regarde] —, la caméra posée EXACTEMENT sur l'œil.
func _naviguer(points: Array, duree: float) -> void:
	# ⚠ LA SOURIS SORT DE LA VUE AVANT : en Navigate, la boîte blanche de la tuile survolée suit la souris, et à un
	# pas de l'œil elle remplissait l'image (vu au premier tournage).
	await _bouger(Vector2(root.size.x - 150, root.size.y - 60), 0.4)
	await _touche(KEY_SPACE, "Space", "Navigate: fly through it")
	var n := int(duree * FPS)
	var segs := points.size() - 1
	for i in n:
		var t := float(i) / float(n - 1) * segs
		var k := mini(int(t), segs - 1)
		var u := _doux(t - k)
		var a: Array = points[k]
		var b: Array = points[k + 1]
		_regarder((a[0] as Vector3).lerp(b[0], u), (a[1] as Vector3).lerp(b[1], u))
		await _images(1)
	await _touche(KEY_SPACE, "Space", "Back to painting")


## La caméra posée sur `oeil`, tournée vers `vers` (le modèle d'orbite de la vue : cible, azimut, élévation, recul).
func _regarder(oeil: Vector3, vers: Vector3) -> void:
	var d := oeil - vers
	var l := maxf(d.length(), 0.01)
	_vue._cible = vers
	_vue._distance = l
	_vue._elevation = asin(clampf(d.y / l, -1.0, 1.0))
	_vue._azimut = atan2(d.x, d.z)
	_vue._caler()


## La colonne (x, z) où l'eau de la mare TOMBE le plus haut : les cases « chute » des rivières calculées par l'appli.
func _colonne_de_la_cascade() -> Vector3i:
	var par_colonne := {}
	var hauteurs := {}
	for i in _ecran._corps_eau.size():
		for r in _ecran._corps_eau[i]:
			var genres := {}
			for pas in r["cours"]:
				genres[pas["genre"]] = int(genres.get(pas["genre"], 0)) + 1
			print("eau %d : %s, erreur « %s », cours %s" % [i, r["genre"], r["erreur"], genres])
			if r["erreur"] != "" or r["genre"] == "ocean":
				continue
			for pas in r["cours"]:
				if pas["genre"] == "chute":
					var c: Vector3i = pas["case"]
					var k := Vector2i(c.x, c.z)
					par_colonne[k] = int(par_colonne.get(k, 0)) + 1
					if not hauteurs.has(k):
						hauteurs[k] = []
					hauteurs[k].append(c.y)
	var meilleure := Vector2i(MARE.x, 30)
	var plus := 0
	for k in par_colonne:
		if par_colonne[k] > plus:
			plus = par_colonne[k]
			meilleure = k
	var ys: Array = hauteurs.get(meilleure, [MARE.y])
	ys.sort()
	var milieu: int = ys[ys.size() / 2]
	print("cascade : %d colonnes de chute, la plus haute en %s (%d cases, y %s)" % [par_colonne.size(), meilleure, plus, ys])
	return Vector3i(meilleure.x, milieu, meilleure.y)


# ── LES LIEUX ────────────────────────────────────────────────────────────────────────────────────────

## ⚠ Un point derrière la caméra, ou hors de l'image, se projette quand même : le clic tomberait ailleurs, en silence.
func _dans_l_image(point: Vector3, quoi: String) -> bool:
	var cam: Camera3D = _vue._camera
	var p: Vector2 = cam.unproject_position(point)
	# ⚠ LA VUE COUVRE TOUTE LA FENÊTRE, SOUS LES PANNEAUX : un point « dans la vue » peut tomber sous le panneau de droite,
	# et le clic va au panneau (vu le 6 octobre 2026 : la mer et trois sources n'ont jamais été posées). On ne garde que
	# la zone entre les deux panneaux.
	var g: Vector2 = _vue.get_global_transform_with_canvas() * p
	var ok: bool = not cam.is_position_behind(point) and Rect2(Vector2(300, 60), Vector2(1300, 980)).has_point(g)
	if not ok:
		print("⚠ hors de l'image : %s (%s) -> %s" % [quoi, point, p])
	return ok


## La première case pleine de la couche active, de `depuis` dans le sens `pas` (au plus 120 cases).
func _premier_plein(depuis: Vector3i, pas: Vector3i) -> Vector3i:
	var occ: Dictionary = _ecran._occupees()
	var c := depuis
	for i in 120:
		if occ.has(c):
			return c
		c += pas
	print("⚠ rien de plein depuis %s vers %s" % [depuis, pas])
	return depuis


## Le centre d'une face de la case `c`, à peine dehors (le rayon de la souris la touche de face).
func _face(c: Vector3i, n: Vector3i) -> Vector3:
	return Vector3(c) + Vector3(0.5, 0.5, 0.5) + Vector3(n) * 0.52


## La boîte des cases VIDES de la couche active dans ce volume : l'intérieur d'une salle creusée. [bas, haut]
func _boite_vide(x0: int, x1: int, z0: int, z1: int, y0: int, y1: int) -> Array:
	var occ: Dictionary = _ecran._occupees()
	var bas := Vector3i(999, 999, 999)
	var haut := -bas
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			for y in range(y0, y1 + 1):
				if not occ.has(Vector3i(x, y, z)):
					bas = Vector3i(mini(bas.x, x), mini(bas.y, y), mini(bas.z, z))
					haut = Vector3i(maxi(haut.x, x), maxi(haut.y, y), maxi(haut.z, z))
	return [bas, haut]


# ── LA CONSTRUCTION DU MONDE ─────────────────────────────────────────────────────────────────────────

func _batir() -> void:
	var t0 := Time.get_ticks_msec()
	for nom in _couche:
		_ecran._activer(_couche[nom])
		var occ: Dictionary = _ecran._occupees()
		if not occ.is_empty():
			_ecran._appliquer({"poser": {}, "effacer": occ}, "Dig")
	while not _ecran._eaux.is_empty():
		_ecran._retirer_eau(_ecran._eaux[0])
	await _images(2)

	_bruit3.seed = 11
	_bruit3.frequency = 0.09
	_bruit3.fractal_octaves = 3
	var roche := {}
	var herbe := {}
	var sable := {}
	# Le sol : la prairie au sud (herbe sur une case), le fond de mer au nord (sable sur deux).
	for x in range(X_MIN, X_MAX + 1):
		for z in range(Z_MIN, Z_MAX + 1):
			var dessus := PRAIRIE if z >= Z_MER else MER - 1
			for y in range(FOND, dessus + 1):
				var c := Vector3i(x, y, z)
				if z >= Z_MER and y == dessus:
					herbe[c] = true
				elif z < Z_MER and z >= Z_MER - 3 and y > dessus - 2:
					sable[c] = true   # la plage ; le fond de mer est de ROCHE, pour que les puits le creusent
				else:
					roche[c] = true
	# Les massifs : six blocs de roche sur la prairie.
	for cx in MASSIFS:
		for x in range(cx - 4, cx + 4):
			for z in range(MASSIF_Z.x, MASSIF_Z.y + 1):
				for y in range(PRAIRIE + 1, MASSIF_HAUT + 1):
					roche[Vector3i(x, y, z)] = true
	# La montagne : une case est pleine si elle tombe dans une bosse (bruitée) — des étages qui débordent les uns
	# sur les autres, des surplombs, rien d'une carte de hauteurs.
	for x in range(-38, 39):
		for z in range(-24, 30):
			for y in range(PRAIRIE + 1, 46):
				if _dans_la_montagne(Vector3(x, y, z)):
					var c := Vector3i(x, y, z)
					roche[c] = true
					herbe.erase(c)
	# La mare du sommet : une cuvette, et une échancrure vers le sud par où l'eau tombera.
	for x in range(MARE.x - 3, MARE.x + 4):
		for z in range(MARE.z - 3, MARE.z + 4):
			if Vector2(x - MARE.x, z - MARE.z).length() <= 3.2:
				for y in range(MARE.y, 46):
					roche.erase(Vector3i(x, y, z))
	# ⚠ L'ÉCHANCRURE DESCEND AU NIVEAU DU FOND DE LA MARE (mesuré le 5 octobre 2026 : arrêtée une case plus haut,
	# l'eau restait un lac d'une case, sans rivière ni cascade).
	for z in range(MARE.z + 3, MARE.z + 20):
		for x in range(MARE.x - 1, MARE.x + 1):
			for y in range(MARE.y, 46):
				roche.erase(Vector3i(x, y, z))
	for nom_cases in [["GreyRock", roche], ["Grass", herbe], ["Desert", sable]]:
		_ecran._activer(_couche[nom_cases[0]])
		_ecran._appliquer({"poser": nom_cases[1], "effacer": {}}, "Add")
		print("couche %s : %d cases" % [nom_cases[0], (nom_cases[1] as Dictionary).size()])
	_ecran._activer(_couche["GreyRock"])
	_ecran._reparer_les_diagonales(false)
	await _images(2)
	# L'eau : la mer (épinglée hors du monde, puis posée), et la mare du sommet.
	_ecran._changer_d_atelier("fluides")
	var large := Vector3i(X_MAX + 4, MER, Z_MIN + 4)
	_ecran._eau_cliquee(large, MOUSE_BUTTON_LEFT)
	_ecran._eau_cliquee(large, MOUSE_BUTTON_LEFT)
	_ecran._eaux[_ecran._eau_active]["preset"] = "transparent"
	_ecran._eau_cliquee(MARE + Vector3i(0, 1, 0), MOUSE_BUTTON_LEFT)
	for e in _ecran._eaux:
		print("eau %s : %d sources" % [e["nom"], (e["sources"] as Array).size()])
	await _ecran._recalculer_eau(false)
	_ecran._changer_d_atelier("monde")
	_ecran._legende_formes.basculer(false, false)
	print("le monde est bâti en %d ms" % (Time.get_ticks_msec() - t0))


func _dans_la_montagne(p: Vector3) -> bool:
	var d := -1.0
	for b in BOSSES:
		var c: Vector3 = b[0]
		c = Vector3(c.x * ECHELLE, 7.0 + (c.y - 7.0) * ECHELLE, c.z * ECHELLE)
		var q: Vector3 = (p - c) / ((b[1] as Vector3) * ECHELLE)
		d = maxf(d, 1.0 - q.length_squared())
	return d + _bruit3.get_noise_3d(p.x, p.y, p.z) * 0.35 > 0.0
