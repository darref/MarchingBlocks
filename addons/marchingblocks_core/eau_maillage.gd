@tool
extends RefCounted
## LE MAILLAGE DE L'EAU — ce que `fluides.gd` a déduit, rendu en surfaces (charte §5, « le mode Fluids »).
##
## ⚠ **LE PLAN NE COULE PAS, SEULE L'ANIMATION COULE** (Jordan, 1er octobre 2026) : une nappe plate par lac et
## par océan, une bande plate par case de rivière, une lame verticale par cascade. Le courant est une DONNÉE
## portée par les sommets ; c'est le shader qui le fait défiler.
##
## LE CONTRAT DE DONNÉES (PROPOSÉ, à exporter tel quel vers les moteurs à l'étape 4) — chaque sommet porte :
##   COLOR.r, COLOR.g — le courant dans le plan (x, z), ramené de [−1, 1] à [0, 1] ; (0,5 ; 0,5) = eau dormante ;
##   COLOR.b          — le GENRE : 0 dormante (lac, océan), 0,5 rivière, 1 cascade ;
##   COLOR.a          — la profondeur sous la surface, en cases / 8, plafonnée à 1 ; 1 aussi pour « sans fond » ;
##   UV               — (x, z) du monde sur les nappes ; (travers, y) sur une cascade, pour qu'elle défile en bas.
##
## LES HAUTEURS, dans une case `y` qui occupe [y, y+1] (charte §2) :
##   - la matière du témoin AMINCI rentre d'un quart de case : le dessus d'une case pleine `y − 1` se voit en
##     y − 0,25 (mesuré au Play test : 10,75 sur un sol d'étage 10) ;
##   - un lac de niveau L déborde par une case vide en L + 1, donc son bord est une case pleine en L, dont le
##     dessus se voit en L + 0,75 : la nappe est juste dessous, en L + `NAPPE` ;
##   - une rivière en case `y` coule sur le dessus de `y − 1` : la bande est en y + `RIVIERE`.
## ⚠ PROPOSÉ, À JUGER À L'IMAGE : l'art de l'artiste peut déplacer ces dessus.
##
## ⚠ **UNE NAPPE DÉBORDE SOUS LA ROCHE QUI LA BORDE** (`DEBORD`) : la paroi amincie est en retrait d'un quart
## de case dans sa case ; une nappe coupée au bord de la sienne laisserait une fente de fond noir contre chaque
## rive. Elle s'avance donc dans la case pleine voisine, où la roche la cache.

const FL := preload("res://addons/marchingblocks_core/fluides.gd")

const NAPPE := 0.7
const RIVIERE := -0.15
const DEBORD := 0.45
## La lame d'une cascade est EN RETRAIT de cette distance sur le plan qui sépare la colonne de la lèvre de celle
## d'où l'eau vient : la falaise amincie est à 0,25 en retrait, la lame passe 0,15 devant elle, et la bande d'en
## haut (qui va jusqu'au plan) la recouvre de 0,1 — la nappe et la lame se rejoignent sans fente.
const LAME := 0.1
## L'océan s'étend au-delà de la boîte du monde jusqu'à cette distance : « aussi loin que la vue montre ».
const LARGE := 2000.0

const DORMANTE := 0.0
const COURANTE := 0.5
const CASCADE := 1.0


## Le maillage d'une liste de corps (des résultats de `FL.source`), contre les cases pleines `occupees`.
## Rend un ArrayMesh d'une surface, ou null s'il n'y a rien à dessiner.
static func maillage(corps: Array, occupees: Dictionary) -> ArrayMesh:
	var a := _tableaux()
	var b := FL.boite(occupees)
	for r in corps:
		if r == null or r["erreur"] != "":
			continue
		match r["genre"]:
			"ocean":
				_nappe(a, r["eau"], occupees, surface_des_colonnes(r.get("colonnes", null), occupees, b))
				_large(a, b, float(r["niveau"]) + NAPPE)
			"lac":
				_nappe(a, r["eau"], occupees)
			"riviere":
				for lac in r["lacs"]:
					_nappe(a, lac["cases"], occupees)
				_riviere(a, r["cours"], occupees)
	if (a["v"] as PackedVector3Array).is_empty():
		return null
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = a["v"]
	arr[Mesh.ARRAY_NORMAL] = a["n"]
	arr[Mesh.ARRAY_COLOR] = a["c"]
	arr[Mesh.ARRAY_TEX_UV] = a["uv"]
	arr[Mesh.ARRAY_INDEX] = a["i"]
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func _tableaux() -> Dictionary:
	return {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(),
		"uv": PackedVector2Array(), "i": PackedInt32Array()}


static func _couleur(courant: Vector2, genre: float, profondeur: float) -> Color:
	return Color(courant.x * 0.5 + 0.5, courant.y * 0.5 + 0.5, genre, clampf(profondeur, 0.0, 1.0))


## Un quad, coins dans l'ordre du tour, normale `n` ; l'ordre des triangles est REMIS à l'endroit pour Godot
## (faces avant HORAIRES, charte §4 : le produit vectoriel stocké pointe à l'opposé de la normale).
static func _quad(a: Dictionary, p: Array, n: Vector3, c: Color, uv: Array) -> void:
	var base: int = (a["v"] as PackedVector3Array).size()
	for k in 4:
		a["v"].append(p[k])
		a["n"].append(n)
		a["c"].append(c)
		a["uv"].append(uv[k])
	var x: Vector3 = (p[1] - p[0]).cross(p[2] - p[0])
	if x.dot(n) > 0.0:
		a["i"].append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	else:
		a["i"].append_array([base, base + 1, base + 2, base, base + 2, base + 3])


## Un rectangle horizontal [x0, x1] × [z0, z1] à la hauteur h, UV = (x, z) du monde.
static func _plat(a: Dictionary, x0: float, x1: float, z0: float, z1: float, h: float, c: Color) -> void:
	_quad(a, [Vector3(x0, h, z0), Vector3(x1, h, z0), Vector3(x1, h, z1), Vector3(x0, h, z1)], Vector3.UP, c,
		[Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)])


## La case `c` à la hauteur `h`, avancée de `DEBORD` sous chaque voisine pleine de son étage.
static func _case_plate(a: Dictionary, c: Vector3i, h: float, occupees: Dictionary, couleur: Color) -> void:
	var xm := DEBORD if occupees.has(c + Vector3i(-1, 0, 0)) else 0.0
	var xp := DEBORD if occupees.has(c + Vector3i(1, 0, 0)) else 0.0
	var zm := DEBORD if occupees.has(c + Vector3i(0, 0, -1)) else 0.0
	var zp := DEBORD if occupees.has(c + Vector3i(0, 0, 1)) else 0.0
	_plat(a, c.x - xm, c.x + 1 + xp, c.z - zm, c.z + 1 + zp, h, couleur)


## La nappe d'une eau dormante : sa surface (`FL.surface`), à la hauteur de sa rangée + `NAPPE`.
## ⚠ **PAS UN CARRÉ PAR CASE — DEMANDÉ PAR JORDAN (2 octobre 2026)** : un océan en posait un par case de sa surface.
## Les cases sont FUSIONNÉES en grands rectangles (`rectangles_de_nappe`), sans rien changer à ce qu'on voit : même
## aire couverte (débords compris), même couleur par point, mêmes UV (x, z du monde). ⚠ Ce n'est PAS un plan
## unique : il traverserait les grottes sèches au niveau de l'eau.
static func _nappe(a: Dictionary, eau: Dictionary, occupees: Dictionary, surface: Variant = null) -> void:
	for r in rectangles_de_nappe(eau, occupees, surface):
		_plat(a, r["x0"], r["x1"], r["z0"], r["z1"], r["h"], r["couleur"])


## LES RECTANGLES D'UNE NAPPE : chaque case de surface est le rectangle [x − débord, x + 1 + débord] × [z …] à la
## hauteur de sa rangée + `NAPPE`, de la couleur de sa profondeur (comme `_case_plate`) ; puis
##   1. dans une RANGÉE (même y, même z), les cases contiguës en x de même couleur et de mêmes débords en z
##      s'unissent (le débord en x du premier et du dernier reste) ;
##   2. deux bandes de rangées VOISINES en z, de même étendue en x (débords compris), de même couleur, sans débord
##      sur leur bord commun, s'unissent.
## Chaque union ne joint que deux rectangles qui partagent un côté ENTIER : l'aire couverte est exactement celle des
## carrés d'avant. Ordre fixe (y, z, x) : la sortie ne dépend d'aucune table de hachage (les greffons la réécriront).
## `surface` : la surface et ses profondeurs déjà connues ({case: profondeur}, `surface_des_colonnes`), sinon null —
## elle est alors relue dans `eau` (`FL.surface`, `FL.profondeur`).
static func rectangles_de_nappe(eau: Dictionary, occupees: Dictionary, surface: Variant = null) -> Array:
	var profondeurs: Dictionary = {}
	if surface == null:
		for c: Vector3i in FL.surface(eau, occupees):
			profondeurs[c] = FL.profondeur(eau, occupees, c)
	else:
		profondeurs = surface
	var cases: Array = _triees(profondeurs.keys())
	# 1. Les rangées.
	var bandes: Array = []
	var cour := {}
	for c: Vector3i in cases:
		var p: int = profondeurs[c]
		var couleur := _couleur(Vector2.ZERO, DORMANTE, 1.0 if p < 0 else p / 8.0)
		var xm := DEBORD if occupees.has(c + Vector3i(-1, 0, 0)) else 0.0
		var xp := DEBORD if occupees.has(c + Vector3i(1, 0, 0)) else 0.0
		var zm := DEBORD if occupees.has(c + Vector3i(0, 0, -1)) else 0.0
		var zp := DEBORD if occupees.has(c + Vector3i(0, 0, 1)) else 0.0
		if not cour.is_empty() and cour["y"] == c.y and cour["z"] == c.z and cour["fin"] == c.x \
				and cour["xp"] == 0.0 and xm == 0.0 and cour["zm"] == zm and cour["zp"] == zp \
				and cour["couleur"] == couleur:
			cour["fin"] = c.x + 1
			cour["xp"] = xp
			continue
		if not cour.is_empty():
			bandes.append(cour)
		cour = {"y": c.y, "z": c.z, "debut": c.x, "fin": c.x + 1, "xm": xm, "xp": xp, "zm": zm, "zp": zp,
			"couleur": couleur}
	if not cour.is_empty():
		bandes.append(cour)
	# 2. Les bandes voisines en z, de même étendue : chaque bande cherche, dans la rangée d'au-dessus, celle qui la
	# prolonge (index par (y, z+1, étendue, couleur)).
	var rects: Array = []
	var ouverts := {}   # (y, z_fin, x0, x1, couleur) → rectangle encore prolongeable
	for b: Dictionary in bandes:
		var x0: float = b["debut"] - b["xm"]
		var x1: float = b["fin"] + b["xp"]
		var cle := [b["y"], b["z"], x0, x1, b["couleur"]]
		var r: Variant = ouverts.get(cle, null)
		# ⚠ Pas de test « sans débord vers le bas » : deux bandes de même étendue ont les mêmes cases en x, et celle
		# d'en dessous est de l'eau — la bande n'a donc jamais de débord vers elle (mutation ÉQUIVALENTE, mesurée).
		if r != null:
			ouverts.erase(cle)
			r["z1"] = b["z"] + 1 + b["zp"]
		else:
			r = {"x0": x0, "x1": x1, "z0": b["z"] - b["zm"], "z1": b["z"] + 1 + b["zp"], "h": b["y"] + NAPPE,
				"couleur": b["couleur"]}
			rects.append(r)
		if b["zp"] == 0.0:
			ouverts[[b["y"], b["z"] + 1, x0, x1, b["couleur"]]] = r
	return rects


## Les cases dans l'ordre (y, z, x). ⚠ PAR UNE CLÉ ENTIÈRE ET LE TRI NATIF : un `sort_custom` appelait une fonction
## GDScript à chaque comparaison — ~70 ms pour les 10 000 cases de surface d'un océan (mesuré, `sonde_cout_eau.gd`).
static func _triees(cases: Array) -> Array:
	if cases.is_empty():
		return cases
	var lo := Vector3i(2147483647, 2147483647, 2147483647)
	var hi := -lo
	for c: Vector3i in cases:
		lo = Vector3i(mini(lo.x, c.x), mini(lo.y, c.y), mini(lo.z, c.z))
		hi = Vector3i(maxi(hi.x, c.x), maxi(hi.y, c.y), maxi(hi.z, c.z))
	var nx := hi.x - lo.x + 1
	var nz := hi.z - lo.z + 1
	var cles := PackedInt64Array()
	cles.resize(cases.size())
	for i in cases.size():
		var c: Vector3i = cases[i]
		cles[i] = (int(c.y - lo.y) * nz + (c.z - lo.z)) * nx + (c.x - lo.x)
	cles.sort()
	var rendu: Array = []
	rendu.resize(cles.size())
	for i in cles.size():
		var k: int = cles[i]
		rendu[i] = Vector3i(lo.x + k % nx, lo.y + k / (nx * nz), lo.z + (k / nx) % nz)
	return rendu


## LA SURFACE D'UN OCÉAN, LUE SUR SES TRONÇONS (`FL.ocean`, « colonnes ») : {case: profondeur}, la même que
## `FL.surface` + `FL.profondeur`, sans relire le volume. Le haut d'un tronçon est en surface si la case du dessus n'est
## pas pleine (au-dessus, rien n'est de l'eau : le tronçon est maximal) ; sa profondeur est sa hauteur, ou −1 s'il
## descend jusqu'au fond de la boîte (sans fond). Null si les tronçons manquent.
static func surface_des_colonnes(colonnes: Variant, occupees: Dictionary, b: Dictionary) -> Variant:
	if colonnes == null or b.is_empty():
		return null
	var lo_y: int = (b["lo"] as Vector3i).y
	var s := {}
	for t: Array in colonnes:
		var haut := Vector3i(t[0], t[3], t[1])
		if occupees.has(haut + Vector3i.UP):
			continue
		s[haut] = -1 if t[2] == lo_y else t[3] - t[2] + 1
	return s


## L'océan hors de la boîte du monde : quatre grands rectangles autour d'elle, sans fond. Sans monde, un seul.
static func _large(a: Dictionary, b: Dictionary, h: float) -> void:
	var c := _couleur(Vector2.ZERO, DORMANTE, 1.0)
	if b.is_empty():
		_plat(a, -LARGE, LARGE, -LARGE, LARGE, h, c)
		return
	var lo: Vector3i = b["lo"]
	var hi: Vector3i = b["hi"]
	var x0 := float(lo.x)
	var x1 := float(hi.x + 1)
	var z0 := float(lo.z)
	var z1 := float(hi.z + 1)
	_plat(a, -LARGE, LARGE, -LARGE, z0, h, c)
	_plat(a, -LARGE, LARGE, z1, LARGE, h, c)
	_plat(a, -LARGE, x0, z0, z1, h, c)
	_plat(a, x1, LARGE, z0, z1, h, c)


## LA SURFACE DE L'EAU AU-DESSUS DU POINT `p` — pour nager au Play test. `cases` : les cases d'eau DORMANTE (lacs,
## lacs des rivières, océans) ; `oceans` : leurs niveaux, pour le large hors de `boite` (`FL.boite`). Rend la hauteur
## de la nappe de la colonne d'eau qui contient p (la même que celle qu'on DESSINE : rangée du haut + `NAPPE`), ou
## −INF si p n'est dans aucune eau. ⚠ Une rivière n'en est pas : sa bande est une lame de 0,1 case, on y marche.
## ⚠ L'appelant compare : p peut être dans la case du haut mais AU-DESSUS de la nappe (entre L + 0,7 et L + 1).
## ⚠ LA RÈGLE DIT CE QUE LE DESSIN MONTRE : la nappe s'avance de `DEBORD` sous la roche voisine (et la paroi amincie
## est en retrait d'un quart de case), donc un point d'une case PLEINE à moins de `DEBORD` d'une case d'eau est DANS
## cette eau. Sans ça, un nageur collé à la berge avait le centre du corps dans la case du mur : « hors de l'eau »,
## il retombait au fond et ne pouvait plus sortir (vu dans la fumée, par une mutation muette).
static func niveau_au_point(cases: Dictionary, oceans: Array, boite: Dictionary, p: Vector3) -> float:
	var k: Variant = case_d_eau_au_point(cases, p)
	if k != null:
		var h: Vector3i = k
		while cases.has(h + Vector3i.UP):
			h += Vector3i.UP
		return h.y + NAPPE
	var c := Vector3i(floori(p.x), floori(p.y), floori(p.z))
	if oceans.is_empty():
		return -INF
	var dehors := boite.is_empty()
	if not dehors:
		var lo: Vector3i = boite["lo"]
		var hi: Vector3i = boite["hi"]
		dehors = c.x < lo.x or c.x > hi.x or c.z < lo.z or c.z > hi.z or c.y < lo.y
	var plus_haut: int = oceans.max()
	return plus_haut + NAPPE if dehors and c.y <= plus_haut else -INF


## LA CASE D'EAU QUI CONTIENT `p` (dans `cases`), ou null — la case de p, sinon une voisine dont p est à moins de
## `DEBORD` (la nappe dessinée s'y avance sous la roche). Une seule règle pour la surface ET pour le liquide qu'on
## traverse (le voile du Play test).
static func case_d_eau_au_point(cases: Dictionary, p: Vector3) -> Variant:
	var c := Vector3i(floori(p.x), floori(p.y), floori(p.z))
	var fx := p.x - c.x
	var fz := p.z - c.z
	var dx := 1 if fx > 1.0 - DEBORD else (-1 if fx < DEBORD else 0)
	var dz := 1 if fz > 1.0 - DEBORD else (-1 if fz < DEBORD else 0)
	for d: Vector3i in [Vector3i.ZERO, Vector3i(dx, 0, 0), Vector3i(0, 0, dz), Vector3i(dx, 0, dz)]:
		if cases.has(c + d):
			return c + d
	return null


static func _horizontal(d: Vector3i) -> bool:
	return d.y == 0 and absi(d.x) + absi(d.z) == 1


## Une rivière : une bande sur chaque case du cours qui REPOSE SUR DE LA MATIÈRE, dans le sens du courant ; une
## lame par suite de « chute ».
## ⚠ PAS UNE BANDE PAR CASE « COULE » — VU À L'IMAGE (`capture_fluides.gd`) : la lèvre (la case d'où l'eau tombe)
## est au-dessus du VIDE, sa bande flottait en l'air en haut de chaque cascade ; et la case où l'eau retombe est
## une « chute », elle n'en avait pas : chaque marche d'un escalier restait sèche.
static func _riviere(a: Dictionary, cours: Array, occupees: Dictionary) -> void:
	var n := cours.size()
	for i in n:
		var e: Dictionary = cours[i]
		var c: Vector3i = e["case"]
		if e["genre"] == "lac" or not occupees.has(c + Vector3i.DOWN):
			continue
		var d := Vector3i.ZERO
		if i + 1 < n and _horizontal(cours[i + 1]["case"] - c):
			d = cours[i + 1]["case"] - c
		elif i > 0 and _horizontal(c - cours[i - 1]["case"]):
			d = c - cours[i - 1]["case"]
		_case_plate(a, c, c.y + RIVIERE, occupees, _couleur(Vector2(d.x, d.z), COURANTE, 0.05))
	var i := 0
	while i < n:
		var e: Dictionary = cours[i]
		var c: Vector3i = e["case"]
		if e["genre"] == "chute":
			# La suite de chutes et la case d'où elle tombe (la dernière « coule », juste au-dessus).
			var j := i
			while j < n and cours[j]["genre"] == "chute":
				j += 1
			var levre: Vector3i = cours[i - 1]["case"] if i > 0 else c + Vector3i.UP
			var d := Vector3i.ZERO
			if i >= 2 and _horizontal(levre - cours[i - 2]["case"]):
				d = levre - cours[i - 2]["case"]
			else:
				for f: Vector3i in FL.HORIZONTALES:
					if occupees.has(c - f):
						d = f
						break
			_lame(a, levre, cours[j - 1]["case"], d)
			i = j
		else:
			i += 1


## La lame d'une cascade, de la lèvre `levre` (la case d'où l'eau tombe) jusqu'à la dernière case de chute
## `bas`, collée à la falaise qu'elle quitte (le côté −`d`). Sans sens connu, au milieu de la colonne.
static func _lame(a: Dictionary, levre: Vector3i, bas: Vector3i, d: Vector3i) -> void:
	var haut := levre.y + RIVIERE
	var pied := bas.y - 0.3
	var c := _couleur(Vector2(d.x, d.z), CASCADE, 0.05)
	if d.x != 0:
		var x := float(levre.x) + (-LAME if d.x > 0 else 1.0 + LAME)
		_quad(a, [Vector3(x, haut, levre.z), Vector3(x, haut, levre.z + 1), Vector3(x, pied, levre.z + 1),
			Vector3(x, pied, levre.z)], Vector3(d.x, 0, 0), c,
			[Vector2(levre.z, haut), Vector2(levre.z + 1, haut), Vector2(levre.z + 1, pied), Vector2(levre.z, pied)])
	else:
		var sz: int = d.z if d.z != 0 else 1
		var z := float(levre.z) + (-LAME if sz > 0 else 1.0 + LAME)
		if d.z == 0:
			z = levre.z + 0.5
		_quad(a, [Vector3(levre.x, haut, z), Vector3(levre.x + 1, haut, z), Vector3(levre.x + 1, pied, z),
			Vector3(levre.x, pied, z)], Vector3(0, 0, sz), c,
			[Vector2(levre.x, haut), Vector2(levre.x + 1, haut), Vector2(levre.x + 1, pied), Vector2(levre.x, pied)])
