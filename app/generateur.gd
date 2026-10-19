extends RefCounted
## LE GÉNÉRATEUR DE MONDES — la 1.0.0 (Jordan, 19 octobre 2026 : « des mondes de taille / forme / réseaux de chemins /
## souterrains / aspects différents ? contrôlables ? » — « fais-le » ; SANS IA, même jour).
##
## Une liste de champs (`DEFAUTS`) et une GRAINE font un monde, toujours le même pour les mêmes champs. Ici, rien que du
## calcul : pas d'écran, pas de couche. Le monde sort par RÔLES (`ROLES` : le sol, la roche, le sable…) ; l'atelier
## (`atelier_generation.gd`) donne une couche du projet à chaque rôle et pose le tout en UNE action annulable.
##
## Ce qu'il tient — les règles payées par les tournages (charte, « UN ATELIER DE GÉNÉRATION DE MONDE ») :
##   • UNE MATIÈRE PAR NIVEAU : deux rôles ne se touchent pas sur un même plat (sinon « ça fait des carrés »), sauf les
##     chemins et « Blend materials », qui rendent la liste des TRANSITIONS à allumer ;
##   • AUCUN CONTACT PAR UNE ARÊTE (le monde les marquerait en rouge) : réparés ici, dans les colonnes puis sous terre ;
##   • JAMAIS PLUS D'UNE CASE À MONTER sur un chemin (le `_route` de `filmer_haut`) : le stickman y passe, en sautant ;
##   • DES GALERIES DE TROIS CASES DE HAUT au moins, fermées : elles ne s'ouvrent que par leurs entrées (pas sur la mer).
##
## `generer(champs)` rend {"cases": {rôle: {Vector3i: true}}, "colonnes", "eaux", "transitions", "lieux", "entrees",
## "rapport"} ; `apercu(monde)` rend l'image vue de haut que montre l'atelier.

## Les rôles, dans l'ordre de priorité des couches qu'on leur propose (le souterrain en tête : un sommet est posé par la
## couche de plus petit rang, et une berge pendrait sous la voûte — leçon du monde cartoon).
const ROLES := ["souterrain", "chemin", "sol", "sol2", "sable", "neige", "roche"]
const NOMS_ROLES := {
	"sol": "Ground", "sol2": "Second ground", "sable": "Sand, shores", "roche": "Rock, mountains",
	"neige": "Snow, peaks", "chemin": "Paths, places", "souterrain": "Cave walls",
}
## Le rôle qui le remplace quand aucune couche ne lui est donnée.
const REPLI := {"sol2": "sol", "sable": "sol", "chemin": "sol", "neige": "roche", "souterrain": "roche", "roche": "sol"}

const FORMES := ["ile", "archipel", "continent", "vallee", "plateau", "croquis"]
const NOMS_FORMES := {"ile": "Island", "archipel": "Archipelago", "continent": "Continent (one coast)",
	"vallee": "Valley", "plateau": "Plateau (cliffs all around)", "croquis": "Sketch (an image)"}

const DEFAUTS := {
	"graine": 1,
	"largeur": 96, "profondeur": 96, "hauteur": 28,
	"forme": "ile",
	"croquis": "",
	"mer": 4,
	"relief": 0.6,
	"detail": 0.5,
	"falaises": 0.35,
	"lieux": 4,
	"boucles": 0.3,
	"souterrains": 0.4,
	"puits": 0.2,
	"lacs": 2,
	"sources": 1,
	"lave": 0,
	"sable": 0.5,
	"roche": 0.5,
	"neige": 0.3,
	"sol2": 0.3,
	"melange": false,
	"parois_roche": false,
	"tout_remplacer": true,
	"feuillage": 0.5,
}
## Les bornes de chaque champ numérique : [mini, maxi].
const BORNES := {
	"largeur": [16, 256], "profondeur": [16, 256], "hauteur": [8, 64], "mer": [0, 24],
	"relief": [0.0, 1.0], "detail": [0.0, 1.0], "falaises": [0.0, 1.0], "lieux": [0, 12], "boucles": [0.0, 1.0],
	"souterrains": [0.0, 1.0], "puits": [0.0, 1.0], "lacs": [0, 8], "sources": [0, 8], "lave": [0, 4],
	"sable": [0.0, 1.0], "roche": [0.0, 1.0], "neige": [0.0, 1.0], "sol2": [0.0, 1.0], "feuillage": [0.0, 1.0],
}

const VIDE := -1
const DIRS4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var p := {}
var W := 0
var D := 0
var x0 := 0
var z0 := 0
var mer := 0
var H := 0
var rng := RandomNumberGenerator.new()
var _n1 := FastNoiseLite.new()
var _n2 := FastNoiseLite.new()
var _n3 := FastNoiseLite.new()
var _hum := FastNoiseLite.new()
var _mont := FastNoiseLite.new()   # où sont les massifs (basse fréquence)
var h := PackedInt32Array()      # le dessus de chaque colonne (VIDE : rien)
var role := PackedStringArray()  # le rôle du dessus de chaque colonne
var fige := PackedByteArray()    # 1 : colonne d'un chemin, d'une place ou d'un lac (rien ne la change plus)
var _croquis_lieux: Array = []
var lieux: Array = []            # Vector3i : le centre de chaque place
var entrees: Array = []          # Vector3i : la bouche de chaque entrée du souterrain
var eaux: Array = []             # {"nom", "preset", "sources": [Vector3i]}
var air := {}                    # Vector3i → creusé (salles, galeries, entrées)
var bouches := {}                # Vector3i → creusé par une entrée (escalier, puits) : le souterrain s'ouvre là
var parois := {}                 # Vector3i → rôle d'une case pleine qui borde le souterrain
var rapport := {}
var semis: Array = []            # [x, z, y_haut, rôle] : un point à planter (l'atelier y pose un modèle du projet)


static func champs(entree: Dictionary = {}) -> Dictionary:
	var c := DEFAUTS.duplicate()
	for k in entree:
		if c.has(k):
			c[k] = entree[k]
	for k in BORNES:
		var b: Array = BORNES[k]
		if b[0] is int:
			c[k] = clampi(int(c[k]), b[0], b[1])
		else:
			c[k] = clampf(float(c[k]), b[0], b[1])
	c["graine"] = int(c["graine"])
	if not str(c["forme"]) in FORMES:
		c["forme"] = "ile"
	c["melange"] = bool(c["melange"])
	c["parois_roche"] = bool(c["parois_roche"])
	c["tout_remplacer"] = bool(c["tout_remplacer"])
	return c


## Le monde entier. `colonnes_seules` : la heightmap, les chemins et l'eau, sans les cases (l'aperçu de l'atelier).
static func generer(entree: Dictionary, colonnes_seules := false) -> Dictionary:
	var g = load("res://app/generateur.gd").new()
	return g._generer(champs(entree), colonnes_seules)


func _generer(c: Dictionary, colonnes_seules: bool) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	p = c
	W = int(p["largeur"])
	D = int(p["profondeur"])
	x0 = -W / 2
	z0 = -D / 2
	H = int(p["hauteur"])
	mer = mini(int(p["mer"]), H - 4)
	rng.seed = hash([int(p["graine"]), "mb-generateur"])
	for n in [_n1, _n2, _n3, _hum, _mont]:
		n.seed = rng.randi()
	var echelle := 1.0 / float(maxi(mini(W, D), 16))
	_n1.frequency = 2.2 * echelle
	_n1.fractal_octaves = 2 + int(round(float(p["detail"]) * 3.0))
	_n1.fractal_gain = 0.35 + 0.3 * float(p["detail"])
	_n2.frequency = 3.5 * echelle
	_n2.fractal_octaves = 3
	_n3.frequency = 2.8 * echelle
	_n3.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_n3.fractal_octaves = 3
	_hum.frequency = 3.0 * echelle
	_mont.frequency = 1.6 * echelle
	_mont.fractal_octaves = 2
	h.resize(W * D)
	role.resize(W * D)
	fige.resize(W * D)
	fige.fill(0)
	_terrain()
	_roles()
	_lieux_et_chemins()
	_lacs_et_sources()
	if not bool(p["melange"]):
		_un_role_par_plat()
	# Réparer les contacts monte des colonnes, et une marche peut alors dépasser le palier : les deux, jusqu'au calme.
	var reparees := 0
	for tour in 8:
		var n := _sans_contact_colonnes()
		reparees += n
		if (str(p["forme"]) == "plateau" or not _relacher(marche())) and n == 0:
			break
	rapport["colonnes_reparees"] = reparees
	if rapport.has("chemins_marches_hautes"):
		rapport["chemins_marches_hautes"] = _adoucir_les_chemins()
	var sortie := {"champs": p, "largeur": W, "profondeur": D, "origine": Vector2i(x0, z0), "mer": mer, "hauteur": H,
		"h": h, "role": role, "lieux": lieux, "eaux": eaux, "transitions": _transitions(), "rapport": rapport}
	if not colonnes_seules:
		_souterrain()
		sortie["entrees"] = entrees
		sortie["bouches"] = bouches
		_semer()
		sortie["semis"] = semis
		sortie["cases"] = _cases()
	rapport["ms"] = Time.get_ticks_msec() - t0
	return sortie


# ── LA FORME ET LE RELIEF ───────────────────────────────────────────────────────────────────────────

func i_de(x: int, z: int) -> int:
	return (z - z0) * W + (x - x0)


func dedans(x: int, z: int) -> bool:
	return x >= x0 and x < x0 + W and z >= z0 and z < z0 + D


func hauteur_a(x: int, z: int) -> int:
	return h[i_de(x, z)] if dedans(x, z) else VIDE


## Le bruit ramené à 0..1.
func _b(n: FastNoiseLite, x: float, z: float) -> float:
	return clampf(n.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)


func _terrain() -> void:
	var forme := str(p["forme"])
	var blocs: Array = []
	if forme == "archipel":
		# Des îles SÉPARÉES : deux centres jamais plus près que leurs rayons et un bras de mer.
		var voulu := rng.randi_range(3, 6)
		for essai in 200:
			if blocs.size() >= voulu:
				break
			var b := Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6), rng.randf_range(0.14, 0.3))
			var loin := true
			for autre in blocs:
				if Vector2(b.x, b.y).distance_to(Vector2(autre.x, autre.y)) < b.z + autre.z + 0.14:
					loin = false
			if loin:
				blocs.append(b)
	var cote := rng.randi_range(0, 3)
	var image := _image_du_croquis() if forme == "croquis" else null
	var haut_utile := float(H - 2 - mer)
	var elev := PackedFloat32Array()
	elev.resize(W * D)
	elev.fill(-1.0)
	var libres: Array = []     # les élévations calculées (pas imposées) : on les étire sur toute la hauteur
	for z in range(z0, z0 + D):
		for x in range(x0, x0 + W):
			var u := (float(x - x0) + 0.5) / float(W) * 2.0 - 1.0
			var v := (float(z - z0) + 0.5) / float(D) * 2.0 - 1.0
			var bruit := _n1.get_noise_2d(x, z)
			var masse := 0.0          # > 0 : terre
			var forcee := -1.0        # une élévation imposée (plateau, croquis), sinon −1
			match forme:
				"ile", "plateau":
					masse = 0.8 - sqrt(u * u + v * v) + 0.35 * bruit
					if forme == "plateau":
						forcee = 0.55 + 0.1 * _b(_n2, x, z) if masse > 0.2 else -1.0
				"archipel":
					masse = -1.0
					for b in blocs:
						var bb: Vector3 = b
						masse = maxf(masse, (bb.z - Vector2(u - bb.x, v - bb.y).length()) / bb.z * 0.7)
					masse += 0.18 * bruit - 0.05
				"continent":
					var t := [u + 1.0, 1.0 - u, v + 1.0, 1.0 - v][cote] as float   # 0 au rivage choisi, 2 en face
					masse = t * 0.75 - 0.3 + 0.35 * bruit
				"vallee":
					masse = 1.0
					# Les crêtes sur les deux longs bords, le fond au milieu.
					var travers := absf(v) if W >= D else absf(u)
					forcee = clampf(pow(travers, 1.6) * (0.75 + 0.35 * bruit) + 0.04, 0.0, 1.0)
				"croquis":
					var lu: Vector2 = _lire_croquis(image, x, z)
					masse = lu.x
					forcee = lu.y
			var i := i_de(x, z)
			h[i] = 0
			if masse <= 0.0:
				if mer == 0:
					h[i] = VIDE
				else:
					h[i] = clampi(mer - 1 - int(-masse * 10.0), 0, mer - 1)
				role[i] = "sable"
				continue
			var e: float
			if forcee >= 0.0:
				e = forcee
				if forme != "vallee":
					e = clampf(e + 0.12 * _n2.get_noise_2d(x, z), 0.0, 1.0)
			else:
				# Des collines partout, et des MASSIFS là où le bruit lent le veut : leurs crêtes (bruit « ridged ») font la
				# roche et la neige. « Relief » règle la part des massifs autant que la hauteur.
				var monte := clampf(masse * 1.8, 0.0, 1.0)
				var collines := _b(_n2, x, z)
				var massif := smoothstep(0.62 - 0.3 * float(p["relief"]), 0.85, _b(_mont, x, z))
				var cretes := _b(_n3, x, z)
				e = pow(monte, 0.8) * (0.08 + 0.3 * collines + massif * (0.35 + 0.55 * cretes))
				libres.append(e)
				elev[i] = -2.0 - e    # marquée « à étirer »
				continue
			elev[i] = e
	# ⚠ ÉTIRÉE (vu à l'aperçu : le bruit n'atteint presque jamais ses extrêmes, et les mondes restaient bas, sans roche ni
	# neige) : la plus haute colonne sur cent touche le haut du monde, « Relief » en garde une part.
	var plafond := 1.0
	if not libres.is_empty():
		libres.sort()
		plafond = maxf(float(libres[int(float(libres.size() - 1) * 0.995)]), 0.05)
	var part := lerpf(0.3, 1.0, float(p["relief"]))
	for i in h.size():
		if elev[i] == -1.0:
			continue          # la mer (ou le vide), déjà posée
		var e := elev[i]
		if e <= -2.0:
			e = clampf((-e - 2.0) / plafond, 0.0, 1.0)
		h[i] = mer + 1 + int(round(e * part * haut_utile))
	_en_marches()


## LES FALAISES : la hauteur se range en marches de 1 (douces) à 4 cases (falaises franches).
## Puis aucune marche ne dépasse ce palier : la colonne trop haute descend (« Cliffs » à 0 : une case à la fois).
func _en_marches() -> void:
	var s := marche()
	for i in h.size():
		if h[i] > mer + 1:
			h[i] = mer + 1 + s * int(floor(float(h[i] - mer - 1) / float(s)))
	if str(p["forme"]) != "plateau":   # le plateau garde sa falaise tout autour, de toute sa hauteur
		_relacher(s)


## Aucune colonne ne dépasse ses voisines de plus de `s` : la trop haute descend (les colonnes figées — chemins, places,
## lacs — ne bougent pas). Rend vrai si une colonne a bougé.
func _relacher(s: int) -> bool:
	var bouge := false
	for tour in 256:
		var change := false
		for sens in [1, -1]:
			var debut := 0 if sens == 1 else h.size() - 1
			var i := debut
			while i >= 0 and i < h.size():
				if h[i] > mer + 1:
					var x := i % W
					var z := i / W
					var plus_bas := h[i]
					for d in DIRS4:
						var nx: int = x + d.x
						var nz: int = z + d.y
						if nx >= 0 and nz >= 0 and nx < W and nz < D:
							var hn := h[nz * W + nx]
							if hn >= mer + 1 and hn + s < plus_bas:
								plus_bas = hn + s
					if plus_bas < h[i] and fige[i] == 0:
						h[i] = plus_bas
						change = true
				i += sens
		if not change:
			break
		bouge = true
	return bouge


func marche() -> int:
	return 1 + int(round(float(p["falaises"]) * 3.0))


func _image_du_croquis() -> Image:
	var chemin := str(p["croquis"])
	var img := Image.load_from_file(chemin) if chemin != "" and FileAccess.file_exists(chemin) else null
	if img == null:
		rapport["croquis"] = "absent" if chemin == "" else "illisible"
		return null
	img.convert(Image.FORMAT_RGB8)
	img.resize(W, D, Image.INTERPOLATE_NEAREST)
	# LES LIEUX DU CROQUIS : chaque tache ROUGE est une place.
	var vus := {}
	for z in D:
		for x in W:
			if vus.has(Vector2i(x, z)) or _teinte(img.get_pixel(x, z)) != "lieu":
				continue
			var pile := [Vector2i(x, z)]
			var somme := Vector2.ZERO
			var n := 0
			while not pile.is_empty():
				var q: Vector2i = pile.pop_back()
				if vus.has(q) or q.x < 0 or q.y < 0 or q.x >= W or q.y >= D or _teinte(img.get_pixel(q.x, q.y)) != "lieu":
					continue
				vus[q] = true
				somme += Vector2(q)
				n += 1
				for d in DIRS4:
					pile.append(q + d)
			var c := somme / float(n)
			_croquis_lieux.append(Vector2i(int(c.x) + x0, int(c.y) + z0))
	rapport["croquis"] = "lu"
	return img


## Ce que dit une couleur du croquis : la mer (bleu), le sable (jaune), la montagne (gris), les pics (blanc), une place
## (rouge) ; tout le reste est de la terre.
static func _teinte(c: Color) -> String:
	if c.b > c.r + 0.15 and c.b > c.g + 0.05:
		return "mer"
	if c.r > 0.6 and c.g < 0.35 and c.b < 0.35:
		return "lieu"
	if c.r > 0.55 and c.g > 0.5 and c.b < 0.42:
		return "sable"
	if minf(c.r, minf(c.g, c.b)) > 0.85:
		return "pic"
	if maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b)) < 0.12 and c.v > 0.3:
		return "montagne"
	return "terre"


## [masse, élévation] d'une colonne du croquis : la couleur moyennée sur un voisinage (les bords ne sont pas des marches
## d'escalier au pixel près), et le bruit pour que la montagne ne soit pas une table.
func _lire_croquis(img: Image, x: int, z: int) -> Vector2:
	if img == null:
		var u := (float(x - x0) + 0.5) / float(W) * 2.0 - 1.0
		var v := (float(z - z0) + 0.5) / float(D) * 2.0 - 1.0
		return Vector2(0.8 - sqrt(u * u + v * v), -1.0)
	var ix := x - x0
	var iz := z - z0
	var mer_part := 0.0
	var e := 0.0
	var n := 0.0
	var r := 2
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var qx := clampi(ix + dx, 0, W - 1)
			var qz := clampi(iz + dz, 0, D - 1)
			var t := _teinte(img.get_pixel(qx, qz))
			n += 1.0
			match t:
				"mer":
					mer_part += 1.0
				"sable":
					e += 0.02
				"montagne":
					e += 0.7
				"pic":
					e += 1.0
				_:
					e += 0.22
	var terre := 1.0 - mer_part / n
	if terre < 0.5 - 0.15 * _n1.get_noise_2d(x, z):
		return Vector2(-(0.5 - terre) - 0.05, -1.0)
	var elev := e / maxf(n - mer_part, 1.0)
	return Vector2(terre, clampf(elev * (0.85 + 0.3 * _b(_n2, x, z)), 0.0, 1.0))


# ── L'ASPECT : UN RÔLE PAR COLONNE ───────────────────────────────────────────────────────────────────

## LA NEIGE ET LA ROCHE EN PARTS DE LA TERRE (vu à l'aperçu : une ligne à hauteur fixe tombait au-dessus des sommets
## d'un monde bas, et la neige n'existait jamais) : « Snow » à 1 couvre les 15 % les plus hauts des colonnes de terre,
## « Rock » à 1 les 35 % suivants. Lues une fois, sur la heightmap d'avant les chemins.
var _lignes := {}


func ligne_de_neige() -> int:
	return int(_lignes.get("neige", 1 << 20))


func ligne_de_roche() -> int:
	return int(_lignes.get("roche", 1 << 20))


func _mesurer_les_lignes() -> void:
	var terre: Array = []
	for v in h:
		if v >= mer + 1:
			terre.append(v)
	if terre.is_empty():
		return
	terre.sort()
	var n := terre.size()
	var part_neige := 0.15 * float(p["neige"])
	var part_roche := part_neige + 0.35 * float(p["roche"])
	if float(p["neige"]) >= 0.02:
		_lignes["neige"] = maxi(int(terre[clampi(int(float(n) * (1.0 - part_neige)), 0, n - 1)]), mer + 3)
	if float(p["roche"]) >= 0.02:
		_lignes["roche"] = maxi(int(terre[clampi(int(float(n) * (1.0 - part_roche)), 0, n - 1)]), mer + 2)


func _roles() -> void:
	_mesurer_les_lignes()
	var neige := ligne_de_neige()
	var roche := ligne_de_roche()
	var rivage := _distance_a_la_mer()
	var large_sable := 1.0 + float(p["sable"]) * 6.0
	var seuil_sol2 := 1.0 - 2.0 * float(p["sol2"])
	for z in range(z0, z0 + D):
		for x in range(x0, x0 + W):
			var i := i_de(x, z)
			if h[i] == VIDE or h[i] < mer + 1:
				continue
			var r := "sol"
			if h[i] >= neige:
				r = "neige"
			elif h[i] >= roche:
				r = "roche"
			elif float(p["sable"]) > 0.02 and rivage[i] <= large_sable and h[i] <= mer + 1 + int(float(p["sable"]) * 2.0):
				r = "sable"
			elif float(p["sol2"]) > 0.02 and _hum.get_noise_2d(x, z) > seuil_sol2:
				r = "sol2"
			role[i] = r


## La distance de chaque colonne à la mer (en colonnes, 4-voisins) ; très grande sans mer.
func _distance_a_la_mer() -> PackedInt32Array:
	var d := PackedInt32Array()
	d.resize(W * D)
	d.fill(1 << 20)
	if mer == 0:
		return d
	var file: Array = []
	for z in range(z0, z0 + D):
		for x in range(x0, x0 + W):
			var i := i_de(x, z)
			if h[i] != VIDE and h[i] < mer:
				d[i] = 0
				file.append(Vector2i(x, z))
	var t := 0
	while t < file.size():
		var q: Vector2i = file[t]
		t += 1
		var dq := d[i_de(q.x, q.y)]
		for dd in DIRS4:
			var n: Vector2i = q + dd
			if dedans(n.x, n.y) and d[i_de(n.x, n.y)] > dq + 1:
				d[i_de(n.x, n.y)] = dq + 1
				file.append(n)
	return d


## UNE MATIÈRE PAR NIVEAU (Jordan, 6 octobre 2026 : « sans mélange de matières dans le même étage collé, sinon ça fait des
## carrés ») : chaque plat (colonnes voisines au même dessus) prend le rôle le plus présent sur lui. Les chemins et les
## places gardent le leur (ils allument une transition) ; les plats sous la mer ne comptent pas.
func _un_role_par_plat() -> void:
	var vu := PackedByteArray()
	vu.resize(W * D)
	vu.fill(0)
	var changees := 0
	for z in range(z0, z0 + D):
		for x in range(x0, x0 + W):
			var i0 := i_de(x, z)
			if vu[i0] == 1 or h[i0] == VIDE or h[i0] < mer + 1 or role[i0] == "chemin":
				continue
			var plat: Array = []
			var compte := {}
			var pile := [Vector2i(x, z)]
			while not pile.is_empty():
				var q: Vector2i = pile.pop_back()
				if not dedans(q.x, q.y):
					continue
				var i := i_de(q.x, q.y)
				if vu[i] == 1 or h[i] != h[i0] or role[i] == "chemin":
					continue
				vu[i] = 1
				plat.append(i)
				compte[role[i]] = int(compte.get(role[i], 0)) + 1
				for d in DIRS4:
					pile.append(q + d)
			var meilleur := role[i0]
			for r in compte:
				if int(compte[r]) > int(compte[meilleur]):
					meilleur = r
			for i in plat:
				if role[i] != meilleur:
					role[i] = meilleur
					changees += 1
	rapport["plats_unifies"] = changees


# ── LES LIEUX ET LES CHEMINS ─────────────────────────────────────────────────────────────────────────

func _lieux_et_chemins() -> void:
	var n := int(p["lieux"])
	var places: Array = []
	if not _croquis_lieux.is_empty():
		for q in _croquis_lieux:
			var k: Vector2i = q
			if dedans(k.x, k.y) and h[i_de(k.x, k.y)] > mer:
				places.append(k)
	else:
		var roche := ligne_de_roche()
		var ecart := float(mini(W, D)) / (sqrt(float(maxi(n, 1))) + 1.0)
		var rivage := _distance_a_la_mer()
		for essai in n * 60:
			if places.size() >= n:
				break
			var k := Vector2i(rng.randi_range(x0 + 4, x0 + W - 5), rng.randi_range(z0 + 4, z0 + D - 5))
			var i := i_de(k.x, k.y)
			if h[i] == VIDE or h[i] <= mer or h[i] >= roche or rivage[i] < 4:
				continue
			var loin := true
			for autre in places:
				if Vector2(autre).distance_to(Vector2(k)) < ecart * (1.0 - float(essai) / float(n * 120)):
					loin = false
			if loin:
				places.append(k)
	# Les places : un rond pavé, à plat.
	for k in places:
		var hp := maxi(h[i_de(k.x, k.y)], mer + 1)
		var r := 2.6
		for dz in range(-3, 4):
			for dx in range(-3, 4):
				var q: Vector2i = k + Vector2i(dx, dz)
				if Vector2(dx, dz).length() > r or not dedans(q.x, q.y):
					continue
				var i := i_de(q.x, q.y)
				h[i] = hp
				role[i] = "chemin"
				fige[i] = 1
		lieux.append(Vector3i(k.x, hp, k.y))
	rapport["lieux"] = lieux.size()
	if places.size() < 2:
		rapport["chemins"] = 0
		return
	# Les liaisons : l'arbre le plus court, puis des boucles.
	var liens := _arbre_couvrant(places)
	var longueur := 0
	var marches_hautes := 0
	var grille := _grille_des_chemins()
	for l in liens:
		var a: Vector2i = places[l[0]]
		var b: Vector2i = places[l[1]]
		var trace: PackedVector2Array = grille.get_point_path(a - Vector2i(x0, z0), b - Vector2i(x0, z0))
		if trace.is_empty():
			continue
		var cols: Array = []
		for pt in trace:
			cols.append(Vector2i(int(pt.x), int(pt.y)) + Vector2i(x0, z0))
		longueur += cols.size()
		_tailler(cols)
	marches_hautes = _adoucir_les_chemins()
	rapport["chemins"] = liens.size()
	rapport["chemins_longueur"] = longueur
	rapport["chemins_marches_hautes"] = marches_hautes


func _arbre_couvrant(places: Array) -> Array:
	var liens: Array = []
	var dedans_ := {0: true}
	while dedans_.size() < places.size():
		var meilleur := []
		var bd := INF
		for a in dedans_:
			for b in places.size():
				if dedans_.has(b):
					continue
				var d := Vector2(places[a]).distance_to(Vector2(places[b]))
				if d < bd:
					bd = d
					meilleur = [a, b]
		dedans_[meilleur[1]] = true
		liens.append(meilleur)
	# Les boucles : les liaisons courtes qui manquent, une part d'entre elles.
	var restes: Array = []
	for a in places.size():
		for b in range(a + 1, places.size()):
			var deja := false
			for l in liens:
				if (l[0] == a and l[1] == b) or (l[0] == b and l[1] == a):
					deja = true
			if not deja:
				restes.append([a, b, Vector2(places[a]).distance_to(Vector2(places[b]))])
	restes.sort_custom(func(x: Array, y: Array) -> bool: return x[2] < y[2])
	for k in int(round(float(p["boucles"]) * float(places.size()))):
		if k < restes.size():
			liens.append([restes[k][0], restes[k][1]])
	return liens


## La grille du chemin : chaque colonne coûte selon sa pente (un chemin contourne les falaises quand il le peut) ; la mer
## coûte cher (une chaussée la traverse si rien d'autre ne passe), le vide est fermé.
func _grille_des_chemins() -> AStarGrid2D:
	var g := AStarGrid2D.new()
	g.region = Rect2i(0, 0, W, D)
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	g.update()
	for z in range(z0, z0 + D):
		for x in range(x0, x0 + W):
			var i := i_de(x, z)
			var q := Vector2i(x - x0, z - z0)
			if h[i] == VIDE:
				g.set_point_solid(q, true)
				continue
			var pente := 0
			for d in DIRS4:
				var hn := hauteur_a(x + d.x, z + d.y)
				if hn != VIDE:
					pente = maxi(pente, absi(hn - h[i]))
			# La mer est fermée : deux îles ne se relient pas par une chaussée (vu à l'aperçu : des traits droits sur l'eau).
			if h[i] <= mer:
				g.set_point_solid(q, true)
				continue
			g.set_point_weight_scale(q, 1.0 + 3.0 * float(pente))
	return g


## Le chemin posé sur ses colonnes : deux colonnes de large, sa hauteur ne change jamais de plus d'une case d'un pas au
## suivant (on creuse une tranchée dans la colline, on remblaie le creux, une chaussée passe la mer).
func _tailler(cols: Array) -> void:
	var n := cols.size()
	var t := PackedInt32Array()
	t.resize(n)
	for k in n:
		t[k] = maxi(h[i_de(cols[k].x, cols[k].y)], mer + 1)
	var fin := t[n - 1]
	for k in range(1, n):
		t[k] = clampi(t[k], t[k - 1] - 1, t[k - 1] + 1)
	t[n - 1] = fin
	for k in range(n - 2, -1, -1):
		t[k] = clampi(t[k], t[k + 1] - 1, t[k + 1] + 1)
	for k in n:
		var c: Vector2i = cols[k]
		var sens: Vector2i = (cols[mini(k + 1, n - 1)] - cols[maxi(k - 1, 0)])
		var cote := Vector2i(clampi(-sens.y, -1, 1), clampi(sens.x, -1, 1))
		for q in [c, c + cote]:
			if not dedans(q.x, q.y):
				continue
			var i := i_de(q.x, q.y)
			if fige[i] == 1:
				continue   # une place, ou un autre chemin déjà posé : il garde sa hauteur (`_adoucir_les_chemins` raccorde)
			h[i] = t[k]
			role[i] = "chemin"
			fige[i] = 1


## Là où deux chemins se croisent à des hauteurs différentes, une marche de plus d'une case peut rester : on remblaie le
## bas jusqu'à ce qu'il n'en reste plus (ou qu'on ait fait le tour). Rend celles qui restent.
func _adoucir_les_chemins() -> int:
	for tour in 64:
		var change := false
		for z in range(z0, z0 + D):
			for x in range(x0, x0 + W):
				var i := i_de(x, z)
				if role[i] != "chemin":
					continue
				for d in DIRS4:
					if not dedans(x + d.x, z + d.y):
						continue
					var j := i_de(x + d.x, z + d.y)
					if role[j] == "chemin" and h[j] < h[i] - 1:
						h[j] = h[i] - 1
						change = true
		if not change:
			break
	var restent := 0
	for z in range(z0, z0 + D):
		for x in range(x0, x0 + W):
			var i := i_de(x, z)
			if role[i] != "chemin":
				continue
			for d in DIRS4:
				if dedans(x + d.x, z + d.y) and role[i_de(x + d.x, z + d.y)] == "chemin" \
						and absi(h[i_de(x + d.x, z + d.y)] - h[i]) > 1:
					restent += 1
	return restent


# ── L'EAU ────────────────────────────────────────────────────────────────────────────────────────────

## La mer (une source dans le vide, au niveau voulu), les lacs et les mares de lave (des cuvettes creusées, une source au
## fond : le calcul de l'appli les remplit), les sources des rivières (sur un haut, près d'une chute).
func _lacs_et_sources() -> void:
	if mer > 0:
		var large := Vector3i(x0 + W + 8, mer, z0 + D / 2)
		eaux.append({"nom": "Sea", "preset": "stylise", "sources": [large]})
	var lacs: Array = []
	var roche := ligne_de_roche()
	for k in int(p["lacs"]):
		var s: Variant = _cuvette(mer + 2, roche - 1, "sable")
		if s != null:
			lacs.append(s)
	if not lacs.is_empty():
		eaux.append({"nom": "Lakes", "preset": "stylise", "sources": lacs})
	var laves: Array = []
	for k in int(p["lave"]):
		var s: Variant = _cuvette(maxi(roche - 2, mer + 3), H, "roche")
		if s != null:
			laves.append(s)
	if not laves.is_empty():
		eaux.append({"nom": "Lava", "preset": "lave", "sources": laves})
	var sources: Array = []
	for essai in int(p["sources"]) * 200:
		if sources.size() >= int(p["sources"]):
			break
		var x := rng.randi_range(x0 + 3, x0 + W - 4)
		var z := rng.randi_range(z0 + 3, z0 + D - 4)
		var i := i_de(x, z)
		if h[i] < mer + 5 or fige[i] == 1:
			continue
		# Un haut à plat, et une chute à moins de quatre colonnes (sinon le premier bassin ne déborde pas).
		var plat := true
		for d in DIRS4:
			if hauteur_a(x + d.x, z + d.y) != h[i]:
				plat = false
		var chute := false
		for d in DIRS4:
			for r in range(2, 5):
				var hn := hauteur_a(x + d.x * r, z + d.y * r)
				if hn != VIDE and hn < h[i]:
					chute = true
		if plat and chute:
			sources.append(Vector3i(x, h[i] + 1, z))
			fige[i] = 1
	if not sources.is_empty():
		eaux.append({"nom": "Rivers", "preset": "stylise", "sources": sources})
	rapport["lacs"] = lacs.size()
	rapport["laves"] = laves.size()
	rapport["sources"] = sources.size()


## Une cuvette ronde creusée dans un plat entre deux hauteurs : son fond deux cases sous le plat, sa lèvre au plat. Rend
## la case de sa source (au-dessus du fond), ou null.
func _cuvette(bas: int, haut: int, fond: String) -> Variant:
	for essai in 120:
		var r := rng.randi_range(3, 6)
		var x := rng.randi_range(x0 + r + 3, x0 + W - r - 4)
		var z := rng.randi_range(z0 + r + 3, z0 + D - r - 4)
		var hc := h[i_de(x, z)]
		if hc < bas or hc > haut:
			continue
		# Un plat d'abord ; après soixante essais, une LÈVRE remontée là où le terrain descend (une digue).
		var ok := true
		for dz in range(-r - 2, r + 3):
			for dx in range(-r - 2, r + 3):
				var i := i_de(x + dx, z + dz)
				if fige[i] == 1 or (h[i] < hc and essai < 60) or h[i] < hc - 3:
					ok = false
		if not ok:
			continue
		# ⚠ LA LÈVRE EST FIGÉE (vu à l'image : une mare de lave fuyait et couvrait la mer — la digue remontée était rabotée
		# ensuite par `_relacher`, qui descend une colonne plus haute que ses voisines).
		for dz in range(-r - 2, r + 3):
			for dx in range(-r - 2, r + 3):
				var i := i_de(x + dx, z + dz)
				if h[i] < hc:
					h[i] = hc
				fige[i] = 1
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if Vector2(dx, dz).length() > float(r) + 0.4 * _n2.get_noise_2d(x + dx, z + dz):
					continue
				var i := i_de(x + dx, z + dz)
				h[i] = hc - 2
				role[i] = fond
				fige[i] = 1
		return Vector3i(x, hc - 1, z)
	return null


# ── LES CONTACTS PAR UNE ARÊTE ──────────────────────────────────────────────────────────────────────

## Dans les colonnes : deux colonnes en diagonale qui dépassent leurs deux voisines communes ne se touchent que par une
## arête verticale. On monte la plus haute des deux voisines (le rôle de sa colonne ne change pas).
func _sans_contact_colonnes() -> int:
	var total := 0
	for tour in 32:
		var change := 0
		for z in range(z0, z0 + D - 1):
			for x in range(x0, x0 + W - 1):
				var a := i_de(x, z)
				var b := i_de(x + 1, z)
				var c := i_de(x, z + 1)
				var d := i_de(x + 1, z + 1)
				for paire in [[a, d, b, c], [b, c, a, d]]:
					var p1: int = h[paire[0]]
					var p2: int = h[paire[1]]
					var q1: int = h[paire[2]]
					var q2: int = h[paire[3]]
					if mini(p1, p2) > maxi(q1, q2):
						# On monte une des deux basses ; si toutes deux sont figées (deux chemins), on descend une haute.
						if fige[paire[2]] == 1 and fige[paire[3]] == 1:
							var descend: int = paire[0] if fige[paire[0]] == 0 else paire[1]
							if fige[descend] == 1:
								continue
							h[descend] = maxi(q1, q2)
						else:
							var monte: int = paire[2] if (q1 >= q2 and fige[paire[2]] == 0) or fige[paire[3]] == 1 								else paire[3]
							if h[monte] == VIDE:
								role[monte] = role[paire[0]]
							h[monte] = mini(p1, p2)
						change += 1
		total += change
		if change == 0:
			break
	return total


# ── LE SOUTERRAIN ────────────────────────────────────────────────────────────────────────────────────

func _plein(c: Vector3i) -> bool:
	if not dedans(c.x, c.z) or c.y < 0:
		return false
	return c.y <= h[i_de(c.x, c.z)] and not air.has(c)


## Une case peut-elle être creusée sans ouvrir le souterrain sur le dehors : deux cases pleines au-dessus d'elle et de
## ses huit voisines, et pas sous la mer qui l'envahirait par une fissure.
func _creusable(c: Vector3i) -> bool:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var hn := hauteur_a(c.x + dx, c.z + dz)
			if hn == VIDE or hn < c.y + 3:
				return false
	return c.y >= 1


func _souterrain() -> void:
	var amount := float(p["souterrains"])
	var salles: Array = []
	if amount < 0.02:
		rapport["salles"] = 0
		rapport["entrees"] = 0
		return
	var voulu := int(round(amount * float(W * D) / 2304.0 * 2.5)) + 1
	for essai in voulu * 40:
		if salles.size() >= mini(voulu, 40):
			break
		var rx := rng.randi_range(3, 6)
		var rz := rng.randi_range(3, 6)
		var hh := rng.randi_range(3, 5)
		var x := rng.randi_range(x0 + rx + 2, x0 + W - rx - 3)
		var z := rng.randi_range(z0 + rz + 2, z0 + D - rz - 3)
		var plafond := 1 << 20
		for dz in range(-rz - 1, rz + 2):
			for dx in range(-rx - 1, rx + 2):
				plafond = mini(plafond, h[i_de(x + dx, z + dz)])
		var haut := plafond - 3 - hh
		if haut < 1:
			continue
		var yf := rng.randi_range(maxi(1, haut - 6), haut)
		var loin := true
		for s in salles:
			if Vector2(s[0].x, s[0].z).distance_to(Vector2(x, z)) < float(rx + rz + s[1] + s[2]) * 0.75:
				loin = false
		if not loin:
			continue
		salles.append([Vector3i(x, yf, z), rx, rz, hh])
	for s in salles:
		_creuser_salle(s)
	# Les galeries : l'arbre le plus court entre les salles, puis des boucles (même réglage que les chemins).
	var centres: Array = []
	for s in salles:
		centres.append(Vector2i(s[0].x, s[0].z))
	var galeries := 0
	if salles.size() >= 2:
		for l in _arbre_couvrant(centres):
			if _galerie(salles[l[0]][0], salles[l[1]][0]):
				galeries += 1
	# Les entrées : une salle sur trois (au moins une) monte au jour par un escalier ; « Wells » en fait des puits.
	var n_entrees := maxi(1, int(ceil(float(salles.size()) / 3.0))) if not salles.is_empty() else 0
	var ordre := range(salles.size())
	for k in n_entrees:
		var s: Array = salles[ordre[k * salles.size() / maxi(n_entrees, 1)]]
		var ok := _puits(s) if rng.randf() < float(p["puits"]) else _escalier(s)
		if not ok:
			ok = _escalier(s) or _puits(s)
	# Reboucher une case contre un contact peut baisser un plafond (vu au test, au haut d'un escalier) : on rend les
	# trois cases de haut, puis on répare encore, jusqu'au calme.
	var reparees := 0
	for tour in 4:
		reparees += _sans_contact_souterrain()
		if _hauteur_sous_plafond() == 0:
			break
	_les_parois()
	rapport["salles"] = salles.size()
	rapport["galeries"] = galeries
	rapport["entrees"] = entrees.size()
	rapport["creusees"] = air.size()
	rapport["souterrain_repare"] = reparees


func _creuser_salle(s: Array) -> void:
	var c: Vector3i = s[0]
	var rx: int = s[1]
	var rz: int = s[2]
	var hh: int = s[3]
	for dz in range(-rz, rz + 1):
		for dx in range(-rx, rx + 1):
			var d2 := pow(float(dx) / float(rx), 2) + pow(float(dz) / float(rz), 2)
			if d2 > 1.0 + 0.2 * _n2.get_noise_2d(c.x + dx, c.z + dz):
				continue
			# Une voûte : le plafond descend vers les bords, jamais sous trois cases de haut.
			var haut := maxi(3, hh - int(round(d2 * 2.0)))
			for y in range(c.y, c.y + haut):
				var q := Vector3i(c.x + dx, y, c.z + dz)
				if _creusable(q):
					air[q] = true


## Une galerie de trois cases de large et de haut, sol à plat qui ne monte que d'une case par pas. Refusée (rien n'est
## creusé) si elle ouvrirait le souterrain sur le dehors ou monterait trop raide.
func _galerie(a: Vector3i, b: Vector3i) -> bool:
	var dist := maxi(absi(b.x - a.x), absi(b.z - a.z))
	if dist == 0 or absi(b.y - a.y) > dist:
		return false
	var cases: Array = []
	for k in dist + 1:
		var t := float(k) / float(dist)
		var cx := int(round(lerpf(a.x, b.x, t)))
		var cz := int(round(lerpf(a.z, b.z, t)))
		var cy := int(round(lerpf(a.y, b.y, t)))
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				for y in range(cy, cy + 3):
					var q := Vector3i(cx + dx, y, cz + dz)
					if not _creusable(q):
						return false
					cases.append(q)
	for q in cases:
		air[q] = true
	return true


## Un escalier qui monte d'une case par pas depuis le bord de la salle jusqu'au jour, dans la direction où le dessus est
## le plus proche. La bouche est sur la terre (jamais sous la mer) ; une lèvre d'une case la garde des rivières.
func _escalier(s: Array) -> bool:
	var c: Vector3i = s[0]
	var meilleur: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var dd: Vector2i = d
		var r: int = s[1] if dd.x != 0 else s[2]
		var cases: Array = []
		var y := c.y
		var x := c.x + dd.x * (r - 1)
		var z := c.z + dd.y * (r - 1)
		var sorti := false
		for pas in 64:
			x += dd.x
			z += dd.y
			y += 1
			var hn := hauteur_a(x, z)
			if hn == VIDE or (hn <= mer and mer > 0):
				break
			var cote := Vector2i(-dd.y, dd.x)
			for o in [-1, 0, 1]:
				for yy in range(y, y + 3):
					cases.append(Vector3i(x + cote.x * o, yy, z + cote.y * o))
			if y > hn:
				sorti = hn > mer + 1 or mer == 0
				break
		if sorti and (meilleur.is_empty() or cases.size() < (meilleur[0] as Array).size()):
			meilleur = [cases, Vector3i(x, y, z)]
	if meilleur.is_empty():
		return false
	for q in meilleur[0]:
		air[q] = true
		bouches[q] = true
	entrees.append(meilleur[1])
	return true


## Un puits de deux cases sur deux, du plafond de la salle au jour (il faut voler pour le remonter).
func _puits(s: Array) -> bool:
	var c: Vector3i = s[0]
	var hc := mini(mini(hauteur_a(c.x, c.z), hauteur_a(c.x + 1, c.z)), mini(hauteur_a(c.x, c.z + 1), hauteur_a(c.x + 1, c.z + 1)))
	if hc <= mer + 1 and mer > 0:
		return false
	for dz in 2:
		for dx in 2:
			var top := hauteur_a(c.x + dx, c.z + dz)
			for y in range(c.y, top + 1):
				air[Vector3i(c.x + dx, y, c.z + dz)] = true
				bouches[Vector3i(c.x + dx, y, c.z + dz)] = true
	entrees.append(Vector3i(c.x, hc + 1, c.z))
	return true


## Sur chaque sol creusé, les deux cases au-dessus sont creusées aussi (sous la croûte). Rend le nombre creusé.
func _hauteur_sous_plafond() -> int:
	var n := 0
	for a in air.keys():
		var c: Vector3i = a
		if not _plein(c + Vector3i.DOWN):
			continue
		for k in [1, 2]:
			var q: Vector3i = c + Vector3i.UP * k
			if _plein(q) and q.y <= h[i_de(q.x, q.z)]:
				air[q] = true
				parois.erase(q)
				n += 1
	return n


## Les cases pleines qui bordent le souterrain prennent le rôle « souterrain » (sauf la croûte du dessus).
func _les_parois() -> void:
	var voisins := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1),
		Vector3i(0, 0, -1)]
	for a in air:
		for d in voisins:
			var q: Vector3i = a + d
			if _plein(q) and q.y < h[i_de(q.x, q.z)] - 1:
				parois[q] = "souterrain"


## Sous terre, le même contrôle que le monde cartoon (`_sans_contact` de `batir_monde_cartoon.gd`) : deux cases pleines
## (ou vides) qui ne se touchent que par une arête ; on rebouche une case creusée de préférence.
func _sans_contact_souterrain() -> int:
	var plans := [[Vector3i(1, 0, 0), Vector3i(0, 1, 0)], [Vector3i(1, 0, 0), Vector3i(0, 0, 1)],
		[Vector3i(0, 1, 0), Vector3i(0, 0, 1)]]
	var a_voir := {}
	for c in air:
		for pl in plans:
			for u in [Vector3i.ZERO, -pl[0]]:
				for v in [Vector3i.ZERO, -pl[1]]:
					a_voir[[c + u + v, pl]] = true
	var total := 0
	for tour in 50:
		var suivants := {}
		for cle in a_voir:
			var a: Vector3i = cle[0]
			var pl: Array = cle[1]
			var b: Vector3i = a + pl[0]
			var d: Vector3i = a + pl[1]
			var e: Vector3i = a + pl[0] + pl[1]
			var pa := _plein(a)
			if pa != _plein(e) or _plein(b) != _plein(d) or pa == _plein(b):
				continue
			# ⚠ ON CREUSE D'ABORD (vu au test : reboucher une case creusée baissait le plafond d'une entrée à deux cases) :
			# une pleine qui touche par l'arête, si elle est sous la croûte ; sinon on rebouche une case creusée.
			var vides: Array = [b, d] if pa else [a, e]
			var pleines: Array = [a, e] if pa else [b, d]
			var choix := Vector3i(0, -1, 0)
			for pp in pleines:
				var q: Vector3i = pp
				if dedans(q.x, q.z) and q.y >= 1 and q.y < h[i_de(q.x, q.z)] - 1:
					choix = q
					break
			if choix.y >= 0:
				air[choix] = true
				parois.erase(choix)
			else:
				for vv in vides:
					if air.has(vv):
						choix = vv
						break
				if choix.y < 0:
					continue
				air.erase(choix)
				parois[choix] = "souterrain"
			total += 1
			for pl2 in plans:
				for u in [Vector3i.ZERO, -pl2[0]]:
					for v in [Vector3i.ZERO, -pl2[1]]:
						suivants[[choix + u + v, pl2]] = true
		if suivants.is_empty():
			break
		a_voir = suivants
	return total


# ── LE FEUILLAGE ───────────────────────────────────────────────────────────────────────────────────

## LES POINTS À PLANTER (Jordan, 19 octobre 2026 : « fais le feuillage d'abord ») : une part des colonnes de chaque
## rôle, plus dense en sous-bois (le second sol), rare sur la roche et la neige ; jamais sur un chemin, une place, un
## lac, une source, la mer, ni près d'une entrée du souterrain. Le point est jeté au hasard dans sa colonne ; l'atelier
## cherche le vrai sol des tuiles sous `y_haut` et vérifie le plant comme le pinceau de Foliage.
const DENSITES := {"sol": 0.22, "sol2": 0.6, "sable": 0.05, "roche": 0.05, "neige": 0.02}


func _semer() -> void:
	var part := float(p["feuillage"])
	if part <= 0.0:
		rapport["semis"] = 0
		return
	var pres_d_une_entree := {}
	for e in entrees:
		for dz in range(-3, 4):
			for dx in range(-3, 4):
				pres_d_une_entree[Vector2i(e.x + dx, e.z + dz)] = true
	for z in range(z0, z0 + D):
		for x in range(x0, x0 + W):
			var i := i_de(x, z)
			if h[i] == VIDE or h[i] <= mer or fige[i] == 1 or pres_d_une_entree.has(Vector2i(x, z)):
				continue
			if air.has(Vector3i(x, h[i], z)):
				continue   # le haut d'un puits
			if rng.randf() >= part * float(DENSITES.get(role[i], 0.0)):
				continue
			semis.append([float(x) + rng.randf_range(-0.4, 0.4), float(z) + rng.randf_range(-0.4, 0.4), float(h[i]) + 2.0,
				role[i]])
	rapport["semis"] = semis.size()


# ── LA SORTIE ────────────────────────────────────────────────────────────────────────────────────────

## Les paires de rôles qui se touchent sur un même plat (au moins huit fois) : l'atelier allume leur transition.
func _transitions() -> Array:
	var compte := {}
	for z in range(z0, z0 + D):
		for x in range(x0, x0 + W):
			var i := i_de(x, z)
			if h[i] == VIDE or h[i] < mer + 1:
				continue
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				if not dedans(x + d.x, z + d.y):
					continue
				var j := i_de(x + d.x, z + d.y)
				if h[j] != h[i] or role[j] == role[i]:
					continue
				var paire := [role[i], role[j]]
				paire.sort()
				compte[paire] = int(compte.get(paire, 0)) + 1
	var sortie: Array = []
	for paire in compte:
		if int(compte[paire]) >= 8:
			sortie.append(paire)
	return sortie


func _cases() -> Dictionary:
	var par := {}
	for r in ROLES:
		par[r] = {}
	var roche_dessous := bool(p["parois_roche"])
	var total := 0
	for z in range(z0, z0 + D):
		for x in range(x0, x0 + W):
			var i := i_de(x, z)
			if h[i] == VIDE:
				continue
			var r := role[i]
			for y in range(0, h[i] + 1):
				var c := Vector3i(x, y, z)
				if air.has(c):
					continue
				var rc: String = parois.get(c, r)
				if roche_dessous and y < h[i] and rc == r:
					rc = "roche"
				par[rc][c] = true
				total += 1
	rapport["cases"] = total
	var comptes := {}
	for r in par:
		comptes[r] = (par[r] as Dictionary).size()
	rapport["par_role"] = comptes
	return par


## L'APERÇU vu de haut : la teinte du rôle, plus claire en haut ; la mer bleue selon sa profondeur ; les places en rouge,
## les entrées du souterrain en noir, l'eau des lacs et la lave à leur source.
const TEINTES := {
	"sol": Color("#6aa84f"), "sol2": Color("#3d7a3a"), "sable": Color("#e2cf8c"), "roche": Color("#8d8a86"),
	"neige": Color("#f2f4f7"), "chemin": Color("#c9a26b"), "souterrain": Color("#5b4b6b"),
}


static func apercu(monde: Dictionary, taille_maxi := 256) -> Image:
	var w: int = monde["largeur"]
	var d: int = monde["profondeur"]
	var hh: PackedInt32Array = monde["h"]
	var rr: PackedStringArray = monde["role"]
	var m: int = monde["mer"]
	var haut: int = monde["hauteur"]
	var img := Image.create(w, d, false, Image.FORMAT_RGB8)
	for z in d:
		for x in w:
			var i := z * w + x
			var c := Color("#1d1f24")
			if hh[i] != VIDE:
				if hh[i] < m:
					c = Color("#2b6a9e").lerp(Color("#123a63"), clampf(float(m - hh[i]) / 6.0, 0.0, 1.0))
				else:
					var base: Color = TEINTES.get(rr[i], Color.MAGENTA)
					var k := float(hh[i] - m) / float(maxi(haut - m, 1))
					c = base.darkened(0.5 * (1.0 - k)) if k < 0.5 else base.lightened(0.35 * (k - 0.5))
					# L'ombre des marches : une colonne plus basse que sa voisine du nord-ouest s'assombrit.
					var xn := maxi(x - 1, 0)
					var zn := maxi(z - 1, 0)
					if hh[zn * w + xn] > hh[i]:
						c = c.darkened(0.18)
			img.set_pixel(x, z, c)
	var o: Vector2i = monde["origine"]
	for e in monde["eaux"]:
		var teinte := Color("#e8622c") if e["preset"] == "lave" else Color("#4fa3e0")
		for s in e["sources"]:
			var q := Vector2i(s.x, s.z) - o
			if q.x < 0 or q.y < 0 or q.x >= w or q.y >= d:
				continue
			_rond(img, q, 2, teinte)
	for l in monde["lieux"]:
		_rond(img, Vector2i(l.x, l.z) - o, 1, Color("#d93b3b"))
	for e in monde.get("entrees", []):
		_rond(img, Vector2i(e.x, e.z) - o, 1, Color("#000000"))
	var k := maxi(1, taille_maxi / maxi(w, d))
	if k > 1:
		img.resize(w * k, d * k, Image.INTERPOLATE_NEAREST)
	return img


static func _rond(img: Image, c: Vector2i, r: int, teinte: Color) -> void:
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var q := c + Vector2i(dx, dz)
			if dx * dx + dz * dz <= r * r and q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
				img.set_pixel(q.x, q.y, teinte)
