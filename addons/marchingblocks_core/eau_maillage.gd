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
## La lame d'une cascade est EN AVANT de cette distance sur le plan qui sépare la colonne de la lèvre de celle d'où
## l'eau vient. ⚠ **PLUS EN RETRAIT (Jordan, 3 octobre 2026 : « les cascades ont des bugs de construction »)** : à 0,1
## en retrait, elle passait 0,15 devant la falaise amincie — et le relief SCULPTÉ de la falaise (qui a le droit de
## déborder, règle (A)) la perçait de pointes noires à chaque case. À 0,3 devant le plan, elle est à 0,55 de la
## falaise lisse. Une LÈVRE plate relie la bande d'en haut (qui s'arrête au plan) au haut de la lame.
const LAME := 0.3
## L'océan s'étend au-delà de la boîte du monde jusqu'à cette distance : « aussi loin que la vue montre ».
const LARGE := 2000.0

const DORMANTE := 0.0
const COURANTE := 0.5
const CASCADE := 1.0


## Le maillage d'une liste de corps (des résultats de `FL.source`), contre les cases pleines `occupees`.
## Rend un ArrayMesh d'une surface, ou null s'il n'y a rien à dessiner.
## ⚠ **TOUT CE QUI EST À PLAT PASSE PAR `_poser_les_plats`, SANS JONCTION EN T (Jordan, 3 octobre 2026 : « des bandes
## fines de vide là où la découpe se fait »)** : les nappes fusionnées en grands rectangles (et le large, et les bandes
## de rivière) posaient le coin d'un rectangle AU MILIEU du côté de son voisin. Le GPU ne garantit rien sur un tel
## sommet : un fil de pixels de fond passait le long de chaque côté partagé.
static func maillage(corps: Array, occupees: Dictionary) -> ArrayMesh:
	var a := _tableaux()
	var b := FL.boite(occupees)
	var plats: Array = []
	var vus := {}
	for r in corps:
		if r == null or r["erreur"] != "":
			continue
		match r["genre"]:
			"ocean":
				var niveau: int = r["niveau"]
				var h := NAN
				if not b.is_empty() and niveau > (b["hi"] as Vector3i).y:
					h = niveau + NAPPE   # le monde est noyé : les colonnes s'arrêtent au haut de la boîte, pas l'eau
				plats.append_array(rectangles_de_nappe(r["eau"], occupees,
					surface_des_colonnes(r.get("colonnes", null), occupees, b, niveau), niveau, h))
				plats.append_array(_large(b, float(niveau) + NAPPE))
			"lac":
				plats.append_array(rectangles_de_nappe(r["eau"], occupees, null, r["niveau"]))
			"riviere":
				for lac in r["lacs"]:
					plats.append_array(rectangles_de_nappe(lac["cases"], occupees, null, lac["niveau"]))
				_riviere(a, r["cours"], occupees, plats, vus)
	_poser_les_lames(a, vus, plats)
	_poser_les_plats(a, plats)
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


## LES PLATS SANS JONCTION EN T : chaque rectangle horizontal {x0, x1, z0, z1, h, couleur} ; un sommet d'un AUTRE
## rectangle de même hauteur posé sur l'un de ses côtés y est inséré, et le rectangle est alors dessiné en éventail
## autour de son centre (un polygone convexe : aucun triangle plat). Sans sommet inséré, deux triangles, comme avant.
## UV = (x, z) du monde, partout. Les coordonnées sont des multiples de 0,05 : comparées en vingtièmes, exactement.
static func _poser_les_plats(a: Dictionary, plats: Array) -> void:
	var sur_z := {}   # (h, z) → [x des sommets sur cette ligne]
	var sur_x := {}   # (h, x) → [z]
	for r: Dictionary in plats:
		var hk := _k(r["h"])
		for x in [r["x0"], r["x1"]]:
			for z in [r["z0"], r["z1"]]:
				_noter(sur_z, Vector2i(hk, _k(z)), _k(x))
				_noter(sur_x, Vector2i(hk, _k(x)), _k(z))
	for cle in sur_z:
		(sur_z[cle] as Array).sort()
	for cle in sur_x:
		(sur_x[cle] as Array).sort()
	for r: Dictionary in plats:
		var hk := _k(r["h"])
		var x0 := _k(r["x0"])
		var x1 := _k(r["x1"])
		var z0 := _k(r["z0"])
		var z1 := _k(r["z1"])
		# Le tour, dans un sens fixe : (x0,z0) → (x1,z0) → (x1,z1) → (x0,z1).
		var tour: Array[Vector2i] = [Vector2i(x0, z0)]
		for x in _entre(sur_z.get(Vector2i(hk, z0), []), x0, x1):
			tour.append(Vector2i(x, z0))
		tour.append(Vector2i(x1, z0))
		for z in _entre(sur_x.get(Vector2i(hk, x1), []), z0, z1):
			tour.append(Vector2i(x1, z))
		tour.append(Vector2i(x1, z1))
		var retour: Array = _entre(sur_z.get(Vector2i(hk, z1), []), x0, x1)
		retour.reverse()
		for x in retour:
			tour.append(Vector2i(x, z1))
		tour.append(Vector2i(x0, z1))
		var monte: Array = _entre(sur_x.get(Vector2i(hk, x0), []), z0, z1)
		monte.reverse()
		for z in monte:
			tour.append(Vector2i(x0, z))
		var h: float = r["h"]
		var c: Color = r["couleur"]
		if tour.size() == 4:
			_plat(a, r["x0"], r["x1"], r["z0"], r["z1"], h, c)
			continue
		var base: int = (a["v"] as PackedVector3Array).size()
		var centre := Vector3((float(r["x0"]) + float(r["x1"])) * 0.5, h, (float(r["z0"]) + float(r["z1"])) * 0.5)
		a["v"].append(centre)
		a["n"].append(Vector3.UP)
		a["c"].append(c)
		a["uv"].append(Vector2(centre.x, centre.z))
		for t in tour:
			var p := Vector3(t.x / 20.0, h, t.y / 20.0)
			a["v"].append(p)
			a["n"].append(Vector3.UP)
			a["c"].append(c)
			a["uv"].append(Vector2(p.x, p.z))
		var n := tour.size()
		for k in n:
			# Le tour est celui de `_plat` ((x0,z0) → (x1,z0) → (x1,z1)) : le produit vectoriel de (centre, k, k+1)
			# pointe vers le BAS, à l'opposé de la normale — l'ordre que Godot veut (charte §4).
			a["i"].append_array([base, base + 1 + k, base + 1 + (k + 1) % n])


static func _k(v: float) -> int:
	return roundi(v * 20.0)


static func _noter(d: Dictionary, cle: Vector2i, v: int) -> void:
	if not d.has(cle):
		d[cle] = [v]
	elif not (d[cle] as Array).has(v):
		(d[cle] as Array).append(v)


## Les valeurs triées de `l` strictement entre a et b.
static func _entre(l: Array, a: int, b: int) -> Array:
	var sortie: Array = []
	var i := l.bsearch(a, false)
	while i < l.size() and int(l[i]) < b:
		sortie.append(l[i])
		i += 1
	return sortie


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


## La case `c` à la hauteur `h`, avancée de `DEBORD` sous chaque voisine pleine de son étage : un rectangle pour
## `_poser_les_plats`.
static func _case_plate(c: Vector3i, h: float, occupees: Dictionary, couleur: Color) -> Dictionary:
	var xm := DEBORD if occupees.has(c + Vector3i(-1, 0, 0)) else 0.0
	var xp := DEBORD if occupees.has(c + Vector3i(1, 0, 0)) else 0.0
	var zm := DEBORD if occupees.has(c + Vector3i(0, 0, -1)) else 0.0
	var zp := DEBORD if occupees.has(c + Vector3i(0, 0, 1)) else 0.0
	return {"x0": c.x - xm, "x1": c.x + 1 + xp, "z0": c.z - zm, "z1": c.z + 1 + zp, "h": h, "couleur": couleur}


## LA SURFACE DESSINÉE d'une eau dormante de niveau `niveau` : `FL.surface` (rien au-dessus), PLUS ses cases du niveau
## sous un plafond. ⚠ **SOUS UN ÉTAGE FLOTTANT, L'EAU SE VOIT (Jordan, 3 octobre 2026 : « un mauvais raccord là où
## l'océan passe une case de gap sous un étage flottant de matière »)** : la case pleine du dessus ne se voit qu'à un
## quart de case au-dessus de son bas (l'aminci), donc à 0,55 au-dessus de la nappe — il y a de l'air, et la nappe y
## manquait : un trou noir sous chaque surplomb. Une case noyée PLUS BAS que le niveau sous un plafond (une galerie
## sous pression) n'a toujours pas de surface : l'eau y touche la roche.
static func surface_dessinee(eau: Dictionary, occupees: Dictionary, niveau: int) -> Array[Vector3i]:
	var s := FL.surface(eau, occupees)
	for c: Vector3i in eau:
		if c.y == niveau and occupees.has(c + Vector3i.UP):
			s.append(c)
	return s


## LES RECTANGLES D'UNE NAPPE : chaque case de surface est le rectangle [x − débord, x + 1 + débord] × [z …] à la
## hauteur de sa rangée + `NAPPE`, de la couleur de sa profondeur (comme `_case_plate`) ; puis
##   1. dans une RANGÉE (même y, même z), les cases contiguës en x de même couleur et de mêmes débords en z
##      s'unissent (le débord en x du premier et du dernier reste) ;
##   2. deux bandes de rangées VOISINES en z, de même étendue en x (débords compris), de même couleur, sans débord
##      sur leur bord commun, s'unissent.
## Chaque union ne joint que deux rectangles qui partagent un côté ENTIER : l'aire couverte est exactement celle des
## carrés d'avant. Ordre fixe (y, z, x) : la sortie ne dépend d'aucune table de hachage (les greffons la réécriront).
## `surface` : la surface et ses profondeurs déjà connues ({case: profondeur}, `surface_des_colonnes`), sinon null —
## elle est alors relue dans `eau` (`FL.surface`, ou `surface_dessinee` si le `niveau` de l'eau est donné ;
## `FL.profondeur`). `h_forcee` : la hauteur de toute la nappe, si ce n'est pas la rangée + `NAPPE` (un océan qui noie
## le monde : ses colonnes s'arrêtent au haut de la boîte).
static func rectangles_de_nappe(eau: Dictionary, occupees: Dictionary, surface: Variant = null, niveau: Variant = null,
		h_forcee := NAN) -> Array:
	var profondeurs: Dictionary = {}
	if surface == null:
		for c: Vector3i in (FL.surface(eau, occupees) if niveau == null else surface_dessinee(eau, occupees, niveau)):
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
			r = {"x0": x0, "x1": x1, "z0": b["z"] - b["zm"], "z1": b["z"] + 1 + b["zp"],
				"h": h_forcee if not is_nan(h_forcee) else b["y"] + NAPPE,
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
## `FL.surface` + `FL.profondeur` (ou `surface_dessinee`, si le `niveau` est donné), sans relire le volume. Le haut
## d'un tronçon est en surface si la case du dessus n'est pas pleine (au-dessus, rien n'est de l'eau : le tronçon est
## maximal), ou s'il est AU NIVEAU de l'océan (sous un étage flottant) ; sa profondeur est sa hauteur, ou −1 s'il
## descend jusqu'au fond de la boîte (sans fond). Null si les tronçons manquent.
static func surface_des_colonnes(colonnes: Variant, occupees: Dictionary, b: Dictionary, niveau: Variant = null) -> Variant:
	if colonnes == null or b.is_empty():
		return null
	var lo_y: int = (b["lo"] as Vector3i).y
	var s := {}
	for t: Array in colonnes:
		var haut := Vector3i(t[0], t[3], t[1])
		if occupees.has(haut + Vector3i.UP) and (niveau == null or t[3] != int(niveau)):
			continue
		s[haut] = -1 if t[2] == lo_y else t[3] - t[2] + 1
	return s


## L'océan hors de la boîte du monde : quatre grands rectangles autour d'elle, sans fond. Sans monde, un seul.
static func _large(b: Dictionary, h: float) -> Array:
	var c := _couleur(Vector2.ZERO, DORMANTE, 1.0)
	var r := func(x0: float, x1: float, z0: float, z1: float) -> Dictionary:
		return {"x0": x0, "x1": x1, "z0": z0, "z1": z1, "h": h, "couleur": c}
	if b.is_empty():
		return [r.call(-LARGE, LARGE, -LARGE, LARGE)]
	var lo: Vector3i = b["lo"]
	var hi: Vector3i = b["hi"]
	var x0 := float(lo.x)
	var x1 := float(hi.x + 1)
	var z0 := float(lo.z)
	var z1 := float(hi.z + 1)
	return [r.call(-LARGE, LARGE, -LARGE, z0), r.call(-LARGE, LARGE, z1, LARGE), r.call(-LARGE, x0, z0, z1),
		r.call(x1, LARGE, z0, z1)]


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
## lame par suite de « chute ». Les bandes (et les lèvres) partent dans `plats`, les lames dans `vus` (posées ensuite
## par `_poser_les_lames`, toutes rivières réunies).
## ⚠ PAS UNE BANDE PAR CASE « COULE » — VU À L'IMAGE (`capture_fluides.gd`) : la lèvre (la case d'où l'eau tombe)
## est au-dessus du VIDE, sa bande flottait en l'air en haut de chaque cascade ; et la case où l'eau retombe est
## une « chute », elle n'en avait pas : chaque marche d'un escalier restait sèche.
## ⚠ **UNE CASE, UNE BANDE (Jordan, 3 octobre 2026)** : deux rivières qui passent au même endroit posaient deux bandes
## (et deux lames) l'une dans l'autre — du scintillement, et une eau deux fois plus opaque. `vus` retient ce qui est
## posé, pour toutes les rivières d'une couche.
static func _riviere(a: Dictionary, cours: Array, occupees: Dictionary, plats: Array, vus: Dictionary) -> void:
	var n := cours.size()
	for i in n:
		var e: Dictionary = cours[i]
		var c: Vector3i = e["case"]
		if e["genre"] == "lac" or not occupees.has(c + Vector3i.DOWN) or vus.has(c):
			continue
		var d := Vector3i.ZERO
		if i + 1 < n and _horizontal(cours[i + 1]["case"] - c):
			d = cours[i + 1]["case"] - c
		elif i > 0 and _horizontal(c - cours[i - 1]["case"]):
			d = c - cours[i - 1]["case"]
		vus[c] = true
		plats.append(_case_plate(c, c.y + RIVIERE, occupees, _couleur(Vector2(d.x, d.z), COURANTE, 0.05)))
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
			_lame(levre, cours[j - 1]["case"], d, occupees, vus)
			i = j
		else:
			i += 1


## La lame d'une cascade, de la lèvre `levre` (la case d'où l'eau tombe) jusqu'à la dernière case de chute `bas`,
## `LAME` DEVANT le plan de la falaise qu'elle quitte (le côté −`d`). Retenue dans `vus` sous la clé de son plan et de sa
## place sur ce plan ; deux rivières qui tombent au même endroit n'en font qu'une, de la plus haute lèvre au plus bas
## pied. Sans sens connu, au milieu de la colonne.
static func _lame(levre: Vector3i, bas: Vector3i, d: Vector3i, occupees: Dictionary, vus: Dictionary) -> void:
	var haut := levre.y + RIVIERE
	var pied := bas.y - 0.3
	# Le plan : x = const (axe 0) ou z = const (axe 2) ; `a` la case le long du plan ; `plan` le plan de la falaise.
	var axe := 0 if d.x != 0 else 2
	var sens: int = d.x if d.x != 0 else d.z
	var a_le_long: int = levre.z if axe == 0 else levre.x
	var plan := 0.0
	var coord := 0.0
	if sens == 0:
		axe = 2
		sens = 1
		a_le_long = levre.x
		coord = levre.z + 0.5
		plan = coord
	else:
		var bord: int = levre.x if axe == 0 else levre.z
		plan = float(bord) if sens > 0 else float(bord + 1)
		coord = plan + LAME * sens
	# La lèvre : la bande de la case d'avant s'arrête au plan de la falaise ; elle s'avance jusqu'à la lame. Seulement
	# si cette case porte une bande (elle repose sur la matière), sinon elle flotterait.
	var avant := levre - d
	var levre_plate := d != Vector3i.ZERO and occupees.has(avant + Vector3i.DOWN) and not occupees.has(avant)
	var cle := "%d|%d|%d" % [axe, roundi(coord * 20.0), a_le_long]
	var l: Dictionary = vus.get(cle, {})
	if l.is_empty():
		vus[cle] = {"axe": axe, "sens": sens, "coord": coord, "plan": plan, "a": a_le_long, "haut": haut, "pied": pied,
			"d": d, "levre": levre_plate}
	else:
		l["haut"] = maxf(l["haut"], haut)
		l["pied"] = minf(l["pied"], pied)
		l["levre"] = l["levre"] or levre_plate


## Les lames retenues dans `vus`, et leurs lèvres. ⚠ **UNE LAME S'ÉLARGIT DE `LAME` AU BOUT QUI N'A PAS DE VOISINE SUR
## SON PLAN** : posée devant la falaise, elle ne rejoignait plus celle de l'autre face à un coin saillant — on y voyait
## l'arête de la roche entre deux rideaux. Élargies, les deux se rejoignent pile au coin (à `LAME` de chaque face) ; à
## un coin rentrant, le bout élargi entre dans la roche, qui le cache.
static func _poser_les_lames(a: Dictionary, vus: Dictionary, plats: Array) -> void:
	for cle in vus:
		if not cle is String:
			continue
		var l: Dictionary = vus[cle]
		var axe: int = l["axe"]
		var cle_plan := "%d|%d|" % [axe, roundi(float(l["coord"]) * 20.0)]
		var debut := float(l["a"]) - (0.0 if vus.has(cle_plan + str(int(l["a"]) - 1)) or l["d"] == Vector3i.ZERO else LAME)
		var fin := float(l["a"]) + 1.0 + (0.0 if vus.has(cle_plan + str(int(l["a"]) + 1)) or l["d"] == Vector3i.ZERO else LAME)
		var haut: float = l["haut"]
		var pied: float = l["pied"]
		var coord: float = l["coord"]
		var dd: Vector3i = l["d"]
		var c := _couleur(Vector2(dd.x, dd.z), CASCADE, 0.05)
		var n := Vector3(l["sens"], 0, 0) if axe == 0 else Vector3(0, 0, l["sens"])
		var p: Array
		if axe == 0:
			p = [Vector3(coord, haut, debut), Vector3(coord, haut, fin), Vector3(coord, pied, fin), Vector3(coord, pied, debut)]
		else:
			p = [Vector3(debut, haut, coord), Vector3(fin, haut, coord), Vector3(fin, pied, coord), Vector3(debut, pied, coord)]
		_quad(a, p, n, c, [Vector2(debut, haut), Vector2(fin, haut), Vector2(fin, pied), Vector2(debut, pied)])
		if l["levre"]:
			# La lèvre, à plat, du plan de la falaise jusqu'à la lame : une bande qui coule (la cascade la prolonge).
			var cl := _couleur(Vector2(dd.x, dd.z), COURANTE, 0.05)
			var p0: float = minf(l["plan"], coord)
			var p1: float = maxf(l["plan"], coord)
			if axe == 0:
				plats.append({"x0": p0, "x1": p1, "z0": debut, "z1": fin, "h": haut, "couleur": cl})
			else:
				plats.append({"x0": debut, "x1": fin, "z0": p0, "z1": p1, "h": haut, "couleur": cl})
