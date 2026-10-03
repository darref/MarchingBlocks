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
## LA CASCADE EST UN RIDEAU EN VOLUME, REFERMÉ CONTRE LA FAÇADE (Jordan, 3 octobre 2026 : « trop carrées, sans remous,
## texture animée moche, sans volume, et pas refermées contre la façade »). Ce n'est plus une lame plate posée devant
## la falaise, mais une NAPPE COURBE :
##   - elle part de la lèvre À PLAT, au bout de la bande (le plan de la falaise, à la hauteur de la bande), et se
##     courbe vers l'avant comme une eau lancée — `LAME` × √(chute / `ARC`) —, puis tombe presque droite, en
##     s'écartant encore un peu (`EVASE` par case de chute, jusqu'à `EVASE_MAXI`) ;
##   - à un bout sans voisine sur son plan, elle s'arrondit (`ARRONDI`, un quart d'ellipse) et RENTRE DANS LA ROCHE
##     (`DANS_LA_ROCHE` derrière le plan, la falaise amincie est à 0,25) : de profil, plus de jour entre l'eau et la
##     paroi ; elle dépasse la case de `DEPASSE` à ce bout ;
##   - ⚠ À 0,3 DEVANT LE PLAN DÈS LE HAUT, le relief SCULPTÉ de la falaise la perçait (règle (A)) : la courbe part du
##     plan (au-dessus de la roche) et est à `LAME` dès 0,7 de chute ;
##   - au pied, le REMOUS (genre 0,75) : un anneau d'écume posé sur l'eau où elle tombe, qui s'évase autour des bouts
##     arrondis (`REMOUS` de large), et des EMBRUNS, un voile qui monte devant le pied (`EMBRUN` de haut). Ils sont
##     posés APRÈS tout le reste du maillage (`maillage`) : transparents, ils doivent passer par-dessus la nappe.
## Le contrat de la cascade et du remous : COLOR.a est la quantité d'ÉCUME (0 en haut, 1 au pied), pas une profondeur.
const LAME := 0.35
const ARC := 0.7
const EVASE := 0.04
const EVASE_MAXI := 0.2
const DANS_LA_ROCHE := 0.4
const ARRONDI := 0.35
const DEPASSE := 0.1
const REMOUS := 0.85
const EMBRUN := 0.9
## L'écume monte de 0 à 1 sur cette hauteur au-dessus de l'eau où la cascade tombe.
const MONTEE_D_ECUME := 1.3
## L'océan s'étend au-delà de la boîte du monde jusqu'à cette distance : « aussi loin que la vue montre ».
const LARGE := 2000.0

const DORMANTE := 0.0
const COURANTE := 0.5
const REMOUS_GENRE := 0.75
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
	var sources: Array = []
	# Les eaux DORMANTES (océan, lacs, lacs des rivières) : une cascade qui tombe dans l'une d'elles pose son remous sur
	# SA nappe, pas au fond (`_lame`).
	var dormantes: Array = []
	for r in corps:
		if r == null or r["erreur"] != "":
			continue
		if r["genre"] == "ocean" or r["genre"] == "lac":
			dormantes.append(r["eau"])
		elif r["genre"] == "riviere":
			for lac in r["lacs"]:
				dormantes.append(lac["cases"])
	vus["dormantes"] = dormantes
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
				_riviere(a, r["cours"], occupees, plats, vus, sources)
	var remous: Array = []
	_poser_les_lames(a, vus, remous, plats)
	for c: Vector3i in sources:
		remous.append_array(_source(c))
	_poser_les_plats(a, plats)
	for g: Dictionary in remous:
		_grille(a, g)
	_sans_orphelins(a)
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
		if r.has("pts"):
			# Des SOMMETS d'autre chose (le haut d'une cascade, posé sur le bout de sa bande) : à insérer, rien à dessiner.
			for q: Vector3 in r["pts"]:
				_noter(sur_z, Vector2i(_k(q.y), _k(q.z)), _k(q.x))
				_noter(sur_x, Vector2i(_k(q.y), _k(q.x)), _k(q.z))
			continue
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
		if r.has("pts"):
			continue
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


## Retire les sommets qu'aucun triangle n'emploie (le centre d'un disque, où tous les triangles d'un côté sont plats) :
## l'export glTF les ôte, et le maillage relu n'aurait plus les mêmes sommets que celui qu'on dessine.
static func _sans_orphelins(a: Dictionary) -> void:
	var idx: PackedInt32Array = a["i"]
	var n: int = (a["v"] as PackedVector3Array).size()
	var neuf := PackedInt32Array()
	neuf.resize(n)
	neuf.fill(-1)
	for i in idx:
		neuf[i] = 0
	var k := 0
	for i in n:
		if neuf[i] == 0:
			neuf[i] = k
			k += 1
	if k == n:
		return
	for cle in ["v", "n", "c", "uv"]:
		var src = a[cle]
		var dst = src.duplicate()
		dst.resize(k)
		for i in n:
			if neuf[i] >= 0:
				dst[neuf[i]] = src[i]
		a[cle] = dst
	for t in idx.size():
		idx[t] = neuf[idx[t]]
	a["i"] = idx


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
static func _riviere(a: Dictionary, cours: Array, occupees: Dictionary, plats: Array, vus: Dictionary,
		sources: Array = []) -> void:
	var n := cours.size()
	# LA SOURCE (Jordan, 3 octobre 2026 : « il manque aussi la source ») : la première case d'une rivière qui coule sur la
	# matière — l'eau n'y sort plus de nulle part, elle y SOURD (`_source`). Une rivière qui part d'un lac qui déborde
	# n'en a pas : elle sort du lac. Une seule par case.
	if n > 0 and cours[0]["genre"] == "coule" and occupees.has((cours[0]["case"] as Vector3i) + Vector3i.DOWN) \
			and not sources.has(cours[0]["case"]):
		sources.append(cours[0]["case"])
	for i in n:
		var e: Dictionary = cours[i]
		var c: Vector3i = e["case"]
		if e["genre"] == "lac" or not occupees.has(c + Vector3i.DOWN) or vus.has(c):
			continue
		var d := sens_du_cours(cours, i)
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


## Le SENS du courant à la case `i` d'un cours (horizontal, ou nul) : vers la case suivante si elle est à côté, sinon
## depuis la précédente. La règle de la bande dessinée (`_riviere`) ET du courant du Play test (`courants`).
static func sens_du_cours(cours: Array, i: int) -> Vector3i:
	var c: Vector3i = cours[i]["case"]
	if i + 1 < cours.size() and _horizontal(cours[i + 1]["case"] - c):
		return cours[i + 1]["case"] - c
	if i > 0 and _horizontal(c - cours[i - 1]["case"]):
		return c - cours[i - 1]["case"]
	return Vector3i.ZERO


## LE COURANT D'UNE RIVIÈRE, pour le Play test (3 octobre 2026) : {case: sens (x, z)} sur chaque case du cours qui
## REPOSE SUR LA MATIÈRE (celles qui portent une bande) et dont le sens est connu. On y marche : il pousse.
static func courants(cours: Array, occupees: Dictionary) -> Dictionary:
	var sortie := {}
	for i in cours.size():
		var e: Dictionary = cours[i]
		var c: Vector3i = e["case"]
		if e["genre"] == "lac" or not occupees.has(c + Vector3i.DOWN):
			continue
		var d := sens_du_cours(cours, i)
		if d != Vector3i.ZERO and not sortie.has(c):
			sortie[c] = Vector2(d.x, d.z)
	return sortie


## La cascade d'une rivière, de la lèvre `levre` (la case d'où l'eau tombe) jusqu'à la dernière case de chute `bas`,
## sur le plan de la falaise qu'elle quitte (le côté −`d`). Retenue dans `vus` sous la clé de son plan et de sa place
## sur ce plan ; deux rivières qui tombent au même endroit n'en font qu'une, de la plus haute lèvre au plus bas pied.
## Sans sens connu, au milieu de la colonne, droite.
## `sol` : la hauteur de l'eau où elle tombe — la bande de `bas` s'il repose sur la matière, sinon la nappe d'en dessous
## (`bas.y − 0,3` = rangée du dessous + `NAPPE`). Le pied de la nappe est 0,15 plus bas, sous l'eau.
static func _lame(levre: Vector3i, bas: Vector3i, d: Vector3i, occupees: Dictionary, vus: Dictionary) -> void:
	var haut := levre.y + RIVIERE
	var pied := bas.y - 0.3
	var sol := bas.y + RIVIERE if occupees.has(bas + Vector3i.DOWN) else pied
	# ⚠ TOMBÉE DANS UN CREUX QU'ELLE REMPLIT, la chute finit au FOND (la case du bas repose sur la matière) : le remous y
	# était posé sous la nappe, invisible (vu à l'image). Sur l'eau dormante qui noie `bas`, il est sur sa nappe.
	for eau: Dictionary in vus.get("dormantes", []):
		if eau.has(bas):
			var h := bas
			while eau.has(h + Vector3i.UP):
				h += Vector3i.UP
			sol = h.y + NAPPE
			pied = minf(pied, sol - 0.15)
			break
	# Le plan : x = const (axe 0) ou z = const (axe 2) ; `a` la case le long du plan ; `plan` le plan de la falaise.
	var axe := 0 if d.x != 0 else 2
	var sens: int = d.x if d.x != 0 else d.z
	var a_le_long: int = levre.z if axe == 0 else levre.x
	var plan := 0.0
	if sens == 0:
		axe = 2
		sens = 1
		a_le_long = levre.x
		plan = levre.z + 0.5
	else:
		var bord: int = levre.x if axe == 0 else levre.z
		plan = float(bord) if sens > 0 else float(bord + 1)
	var cle := "%d|%d|%d" % [axe, roundi(plan * 20.0), a_le_long]
	var l: Dictionary = vus.get(cle, {})
	if l.is_empty():
		vus[cle] = {"axe": axe, "sens": sens, "plan": plan, "a": a_le_long, "haut": haut, "pied": pied, "sol": sol,
			"d": d}
	else:
		l["haut"] = maxf(l["haut"], haut)
		l["pied"] = minf(l["pied"], pied)
		l["sol"] = minf(l["sol"], sol)


## Les chutes successives d'une nappe : sa courbe (fine en haut, où elle se cintre), puis tous les 0,5, puis son pied.
## Ne dépend que de la hauteur totale : deux cascades voisines de même lèvre et de même pied ont les mêmes rangées.
static func _chutes(total: float) -> PackedFloat32Array:
	var c := PackedFloat32Array()
	for h in [0.0, 0.02, 0.06, 0.12, 0.2, 0.3, 0.42, 0.55, ARC]:
		if h < total - 0.01:
			c.append(h)
	var h := ARC + 0.5
	while h < total - 0.2:
		c.append(h)
		h += 0.5
	c.append(total)
	return c


## Jusqu'où la nappe est sortie du plan après `chute` cases de chute (au milieu, loin des bouts).
static func _sortie(chute: float) -> float:
	return LAME * sqrt(clampf(chute / ARC, 0.0, 1.0)) + minf(EVASE * maxf(chute - ARC, 0.0), EVASE_MAXI)


## Le profil en travers : 1 au milieu, 0 au bout d'un bout libre (où la nappe est rentrée dans la roche).
static func _profil(u: float, u0: float, u1: float, libre0: bool, libre1: bool) -> float:
	var r := 1.0
	if libre0 and u < u0 + ARRONDI:
		var t := clampf((u - u0) / ARRONDI, 0.0, 1.0)
		r = minf(r, sqrt(1.0 - (1.0 - t) * (1.0 - t)))
	if libre1 and u > u1 - ARRONDI:
		var t := clampf((u1 - u) / ARRONDI, 0.0, 1.0)
		r = minf(r, sqrt(1.0 - (1.0 - t) * (1.0 - t)))
	return r


## La position, devant le plan, d'un point de la nappe : `r` son profil en travers, `chute` sa chute. Tout en haut elle
## est sur le plan (au bout de la bande) ; dès 0,15 de chute ses bouts libres sont à `DANS_LA_ROCHE` derrière.
static func _devant(r: float, chute: float) -> float:
	return lerpf(-DANS_LA_ROCHE * clampf(chute / 0.15, 0.0, 1.0), _sortie(chute), r)


## Le point (u, chute) d'une cascade retenue `l`, dans le monde.
static func _point_de_lame(l: Dictionary, u: float, chute: float) -> Vector3:
	var r := 0.0 if l["droite"] else _profil(u, l["u0"], l["u1"], l["libre0"], l["libre1"])
	var p: float = float(l["plan"]) + (0.0 if l["droite"] else _devant(r, chute)) * int(l["sens"])
	var y: float = float(l["haut"]) - chute
	return Vector3(p, y, u) if int(l["axe"]) == 0 else Vector3(u, y, p)


## La normale d'une cascade en (u, chute), par différences — vers l'AVANT : (vers le bas) × (le long du plan) pointe vers
## −x pour l'axe 0, vers +z pour l'axe 2, d'où `_signe`.
static func _normale_de_lame(l: Dictionary, u: float, chute: float) -> Vector3:
	var e := 0.01
	var tu := _point_de_lame(l, u + e, chute) - _point_de_lame(l, u - e, chute)
	var th := _point_de_lame(l, u, chute + e) - _point_de_lame(l, u, maxf(chute - e, 0.0))
	var n := th.cross(tu) * _signe(l)
	if n.length() < 1e-9:
		return Vector3(l["sens"], 0, 0) if int(l["axe"]) == 0 else Vector3(0, 0, l["sens"])
	return n.normalized()


static func _signe(l: Dictionary) -> int:
	return -int(l["sens"]) if int(l["axe"]) == 0 else int(l["sens"])


## Les cascades retenues dans `vus` : chacune posée tout de suite (opaque), son remous gardé dans `remous` (transparent,
## posé en dernier). ⚠ **UN BOUT SANS VOISINE SUR SON PLAN S'ARRONDIT ET RENTRE DANS LA ROCHE** ; un bout qui en a une
## reste droit et finit sur la frontière de la case, où la voisine reprend (mêmes rangées, mêmes points).
static func _poser_les_lames(a: Dictionary, vus: Dictionary, remous: Array, plats: Array = []) -> void:
	for cle in vus:
		if not cle is String or cle == "dormantes":
			continue
		var l: Dictionary = vus[cle]
		var u_case: int = l["a"]
		l["droite"] = l["d"] == Vector3i.ZERO
		var cle_plan := "%d|%d|" % [l["axe"], roundi(float(l["plan"]) * 20.0)]
		l["libre0"] = not l["droite"] and not vus.has(cle_plan + str(u_case - 1))
		l["libre1"] = not l["droite"] and not vus.has(cle_plan + str(u_case + 1))
		l["u0"] = float(u_case) - (DEPASSE if l["libre0"] else 0.0)
		l["u1"] = float(u_case) + 1.0 + (DEPASSE if l["libre1"] else 0.0)
		var us := _travers(l)
		var haut: float = l["haut"]
		var sol: float = l["sol"]
		var total: float = haut - float(l["pied"])
		var dd: Vector3i = l["d"]
		var courant := Vector2(dd.x, dd.z)
		var g := {"p": [], "n": [], "c": [], "uv": []}
		for chute in _chutes(total):
			var rp: Array = []
			var rn: Array = []
			var rc: Array = []
			var ruv: Array = []
			for u in us:
				var p := _point_de_lame(l, u, chute)
				var e := clampf(1.0 - (p.y - sol) / MONTEE_D_ECUME, 0.0, 1.0)
				rp.append(p)
				rn.append(_normale_de_lame(l, u, chute))
				rc.append(_couleur(courant, CASCADE, e * e))
				ruv.append(Vector2(u, p.y))
			g["p"].append(rp)
			g["n"].append(rn)
			g["c"].append(rc)
			g["uv"].append(ruv)
		_grille(a, g)
		# ⚠ SON HAUT EST SUR LE BOUT DE LA BANDE qui y arrive : ses sommets y sont insérés (`_poser_les_plats`), sinon des
		# jonctions en T — un fil de fond le long de la lèvre. Ils sont des multiples de 0,05, comme les plats.
		plats.append({"pts": g["p"][0]})
		# LE REMOUS : au pied, là où la nappe traverse l'eau (`sol`). Chaque point du pied s'écarte selon la normale de la
		# nappe à cet endroit — devant au milieu, de côté sur les bouts arrondis : l'anneau fait le tour.
		var chute_sol := clampf(haut - sol, 0.0, total)
		var pieds: Array = []
		var dirs: Array = []
		for u in us:
			var p := _point_de_lame(l, u, chute_sol)
			var n := _normale_de_lame(l, u, chute_sol)
			var h := Vector3(n.x, 0.0, n.z)
			if h.length() < 0.2:
				h = Vector3(l["sens"], 0, 0) if int(l["axe"]) == 0 else Vector3(0, 0, l["sens"])
			pieds.append(Vector3(p.x, sol, p.z))
			dirs.append(h.normalized())
		remous.append(_couronne(pieds, dirs, us, courant, sol, [0.0, 0.25, 0.55, REMOUS], [0.0, 0.0, 0.0, 0.0],
			[1.0, 0.85, 0.45, 0.0], true))
		# Les embruns montent DEVANT la nappe seulement : sur les bouts arrondis ils s'effacent (leur écume × le profil),
		# sinon ils y faisaient deux ailerons durs de chaque côté (vu à l'image).
		var profils: Array = []
		for u in us:
			profils.append(1.0 if l["droite"] else pow(_profil(u, l["u0"], l["u1"], l["libre0"], l["libre1"]), 3.0))
		remous.append(_couronne(pieds, dirs, us, courant, sol, [0.06, 0.16, 0.22, 0.2], [0.0, 0.3, 0.6, EMBRUN],
			[0.95, 0.7, 0.35, 0.0], false, profils))


## Les points en travers d'une cascade : les bouts arrondis finement, les frontières des cases, le milieu.
static func _travers(l: Dictionary) -> Array:
	var u0: float = l["u0"]
	var u1: float = l["u1"]
	var us: Array = []
	# Des multiples de 0,05 (le haut de la nappe est inséré dans la bande, comparée en vingtièmes).
	for f in [0.0, 0.05, 0.1, 0.2, 0.3, ARRONDI]:
		if l["libre0"]:
			us.append(u0 + f)
		if l["libre1"]:
			us.append(u1 - f)
	var a: int = l["a"]
	for u in [float(a), a + 0.5, a + 1.0]:
		us.append(u)
	us.sort()
	var propres: Array = []
	for u: float in us:
		if u < u0 - 0.001 or u > u1 + 0.001:
			continue
		if propres.is_empty() or u - float(propres[-1]) > 0.005:
			propres.append(u)
	return propres


## Une couronne du remous autour du pied : rangée k à `ecarts[k]` du pied, `montees[k]` au-dessus de l'eau, d'écume
## `ecumes[k]` (× `poids[i]` s'il est donné). `a_plat` : l'anneau posé sur l'eau (normale vers le haut, 0,02 au-dessus) ;
## sinon les embruns, debout.
static func _couronne(pieds: Array, dirs: Array, us: Array, courant: Vector2, sol: float, ecarts: Array, montees: Array,
		ecumes: Array, a_plat: bool, poids: Array = []) -> Dictionary:
	var g := {"p": [], "n": [], "c": [], "uv": []}
	for k in ecarts.size():
		var rp: Array = []
		var rn: Array = []
		var rc: Array = []
		var ruv: Array = []
		for i in us.size():
			var p: Vector3 = pieds[i] + dirs[i] * float(ecarts[k]) + Vector3(0, float(montees[k]) + (0.02 if a_plat else 0.0), 0)
			rp.append(p)
			rn.append(Vector3.UP if a_plat else dirs[i])
			rc.append(_couleur(courant, REMOUS_GENRE, float(ecumes[k]) * (float(poids[i]) if not poids.is_empty() else 1.0)))
			ruv.append(Vector2(us[i], sol - float(ecarts[k]) * 1.5 if a_plat else p.y))
		g["p"].append(rp)
		g["n"].append(rn)
		g["c"].append(rc)
		g["uv"].append(ruv)
	return g


## LA SOURCE d'une rivière, sur la bande de la case `c` : l'eau SOURD — un bouillon d'écume en disque, bombé au centre,
## qui s'étale et s'efface (`SOURCE` de rayon), et un petit voile d'embruns. Genre « remous » (transparent, en dernier) ;
## UV : (angle × rayon, hauteur − rayon) — le bouillon du motif s'écarte du centre.
const SOURCE := 0.7
const SOURCE_DOME := 0.08


static func _source(c: Vector3i) -> Array:
	var centre := Vector3(c.x + 0.5, c.y + RIVIERE, c.z + 0.5)
	var tours := 16
	var disque := {"p": [], "n": [], "c": [], "uv": []}
	var rayons := [0.0, 0.2, 0.42, SOURCE]
	var bosses := [SOURCE_DOME, SOURCE_DOME * 0.7, SOURCE_DOME * 0.3, 0.02]
	var ecumes := [1.0, 0.95, 0.6, 0.0]
	for k in rayons.size():
		var rp: Array = []
		var rn: Array = []
		var rc: Array = []
		var ruv: Array = []
		for i in tours + 1:
			var ang := TAU * float(i % tours) / tours
			var d := Vector3(cos(ang), 0, sin(ang))
			rp.append(centre + d * float(rayons[k]) + Vector3(0, float(bosses[k]), 0))
			rn.append(Vector3.UP)
			rc.append(_couleur(Vector2.ZERO, REMOUS_GENRE, ecumes[k]))
			ruv.append(Vector2(ang * 0.6, centre.y - float(rayons[k]) * 1.5))
		disque["p"].append(rp)
		disque["n"].append(rn)
		disque["c"].append(rc)
		disque["uv"].append(ruv)
	var voile := {"p": [], "n": [], "c": [], "uv": []}
	for k in 3:
		var r: float = [0.12, 0.2, 0.24][k]
		var h: float = [0.02, 0.18, 0.34][k]
		var rp: Array = []
		var rn: Array = []
		var rc: Array = []
		var ruv: Array = []
		for i in tours + 1:
			var ang := TAU * float(i % tours) / tours
			var d := Vector3(cos(ang), 0, sin(ang))
			rp.append(centre + d * r + Vector3(0, h, 0))
			rn.append(d)
			rc.append(_couleur(Vector2.ZERO, REMOUS_GENRE, [0.8, 0.45, 0.0][k]))
			ruv.append(Vector2(ang * 0.6, centre.y + h))
		voile["p"].append(rp)
		voile["n"].append(rn)
		voile["c"].append(rc)
		voile["uv"].append(ruv)
	return [disque, voile]


## Une grille de sommets (`p`, `n`, `c`, `uv` : des rangées de même longueur) en triangles. Chaque triangle est tourné à
## l'endroit pour Godot d'après la normale de son premier sommet (charte §4) ; un triangle sans aire n'est pas posé.
static func _grille(a: Dictionary, g: Dictionary) -> void:
	var p: Array = g["p"]
	var nr := p.size()
	if nr < 2:
		return
	var nc: int = (p[0] as Array).size()
	var base: int = (a["v"] as PackedVector3Array).size()
	for i in nr:
		for j in nc:
			a["v"].append(p[i][j])
			a["n"].append(g["n"][i][j])
			a["c"].append(g["c"][i][j])
			a["uv"].append(g["uv"][i][j])
	var v: PackedVector3Array = a["v"]
	for i in nr - 1:
		for j in nc - 1:
			var k := [base + i * nc + j, base + i * nc + j + 1, base + (i + 1) * nc + j + 1, base + (i + 1) * nc + j]
			for t in [[k[0], k[1], k[2]], [k[0], k[2], k[3]]]:
				var x: Vector3 = (v[t[1]] - v[t[0]]).cross(v[t[2]] - v[t[0]])
				if x.length() < 1e-7:
					continue
				# Tourné d'après la normale de son PREMIER sommet : là où la nappe se replie (le coin du haut d'un bout
				# libre, qui rentre dans la roche), la normale moyenne du quad le retournait.
				if x.dot(a["n"][t[0]]) > 0.0:
					a["i"].append_array([t[0], t[2], t[1]])
				else:
					a["i"].append_array([t[0], t[1], t[2]])
