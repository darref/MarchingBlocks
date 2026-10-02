@tool
extends RefCounted
## LES FLUIDES — d'un clic, un lac, une rivière ou un océan, DÉDUITS des cases (charte §5, « le mode Fluids »).
##
## **DÉCIDÉ (Jordan, 1er octobre 2026)** : un clic pose une SOURCE ; ce qu'elle devient se déduit du monde, et
## se redéduit à chaque changement de cases. On n'enregistre jamais une surface, et l'eau ne touche jamais aux
## cases (§3).
##
## TROIS CAS, UNE SEULE QUESTION — « où l'eau peut-elle aller ? » :
##   - **océan** : la source est dans le VIDE — rien de plein sous elle dans sa colonne. Le niveau est celui du
##     clic ; l'eau occupe toutes les cases vides reliées à l'HORIZON (le bord de la boîte du monde) sans monter
##     au-dessus du niveau. **DÉCIDÉ** : une cavité n'est inondée que si un conduit qui y mène est ouvert SOUS
##     l'eau, et alors jusqu'au niveau (vases communicants : pas de poche d'air piégée) ;
##   - **lac** : l'eau, tombée au sol, ne trouve à son étage aucune case d'où tomber — c'est un CREUX. Il se
##     remplit jusqu'à son SEUIL : le niveau le plus haut où il ne déborde pas. Un lac ne déborde jamais (sa
##     source n'est pas infinie) ;
##   - **rivière** : l'eau, tombée au sol, peut couler plus bas. Elle suit le chemin le plus court à son étage
##     jusqu'à une case d'où tomber, tombe (cascade), et recommence. Un creux rencontré en route se REMPLIT
##     jusqu'à son seuil puis déborde (un lac sur la rivière). Elle s'arrête en quittant la boîte du monde
##     (« sort »), en rejoignant une autre eau (« rejoint »), ou dans un creux sans issue (« ferme »).
##
## ⚠ **LE SEUIL EST UN REMPLISSAGE PAR PRIORITÉ (*priority-flood*)** : la priorité d'une case est la plus haute
## altitude qu'il faut franchir pour l'atteindre depuis le fond. Les cases sortent du tas par priorité
## croissante ; la première qui touche l'horizon (ou une autre eau) fixe P, et le lac est tout ce qui est sorti
## sous P — niveau P − 1. C'est exact, sans essai de niveau en niveau, et ça absorbe d'eux-mêmes les creux
## voisins plus bas que le seuil.
##
## ⚠ **TOUT EST EN ENTIERS ET DÉPARTAGÉ PAR L'ORDRE D'INSERTION** : la règle sera réécrite en C# et en C++ par
## les greffons (comme les formes spéciales). Voisins dans un ordre fixe (`VOISINS`), tas départagé par un
## compteur d'insertion : aucun départage qui dépende d'une table de hachage.
##
## ⚠ **LA BOÎTE DU MONDE** : celle des cases pleines, élargie d'une case. Son bord est donc toujours vide : c'est
## l'HORIZON. Une eau qui l'atteint est sortie du monde.

## Au-delà, un remplissage s'arrête et la source est refusée (« trop_grand ») : un océan sur un monde immense
## gèlerait l'appli.
const VOLUME_MAXI := 64 * 64 * 64
## Une rivière de plus d'étapes est refusée (« trop_long ») — une garde, pas une règle.
const ETAPES_MAXI := 4096

## L'ordre des voisins : il départage tout. Horizontaux d'abord (+X, −X, +Z, −Z), puis bas, puis haut.
const HORIZONTALES := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const VOISINS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	Vector3i(0, -1, 0), Vector3i(0, 1, 0)]
const BAS := Vector3i(0, -1, 0)
const HAUT := Vector3i(0, 1, 0)


## La boîte du monde, élargie d'une case : [lo, hi]. Vide si le monde l'est.
static func boite(occupees: Dictionary) -> Dictionary:
	if occupees.is_empty():
		return {}
	var lo := Vector3i(2147483647, 2147483647, 2147483647)
	var hi := Vector3i(-2147483647, -2147483647, -2147483647)
	for c: Vector3i in occupees:
		lo = Vector3i(mini(lo.x, c.x), mini(lo.y, c.y), mini(lo.z, c.z))
		hi = Vector3i(maxi(hi.x, c.x), maxi(hi.y, c.y), maxi(hi.z, c.z))
	return {"lo": lo - Vector3i.ONE, "hi": hi + Vector3i.ONE}


static func _dans(b: Dictionary, c: Vector3i) -> bool:
	var lo: Vector3i = b["lo"]
	var hi: Vector3i = b["hi"]
	return c.x >= lo.x and c.y >= lo.y and c.z >= lo.z and c.x <= hi.x and c.y <= hi.y and c.z <= hi.z


## L'horizon : les côtés et le dessous de la boîte. ⚠ PAS LE DESSUS : l'eau ne monte pas, et celle qui coule
## sur le toit le plus haut du monde est à la rangée du haut sans l'avoir quitté.
static func _au_bord(b: Dictionary, c: Vector3i) -> bool:
	var lo: Vector3i = b["lo"]
	var hi: Vector3i = b["hi"]
	return c.x == lo.x or c.y == lo.y or c.z == lo.z or c.x == hi.x or c.z == hi.z


## La source est-elle dans le VIDE : rien de plein sous elle, dans sa colonne ?
static func dans_le_vide(occupees: Dictionary, source: Vector3i) -> bool:
	var b := boite(occupees)
	if b.is_empty():
		return true
	var lo: Vector3i = b["lo"]
	var c := source
	while c.y > lo.y:
		c += BAS
		if occupees.has(c):
			return false
	return true


## L'OCÉAN au niveau `niveau` : toutes les cases vides de la boîte, au plus à ce niveau, reliées (par les
## faces) à l'horizon. Rend {"eau": {case: true}, "erreur": ""} ; erreur « trop_grand » au-delà de `maxi`.
## Un océan sous le monde entier, ou sans monde, n'a aucune case : il n'est qu'un plan, à l'horizon.
static func ocean(occupees: Dictionary, niveau: int, maxi := VOLUME_MAXI) -> Dictionary:
	var eau := {}
	var b := boite(occupees)
	if b.is_empty():
		return {"eau": eau, "erreur": ""}
	var lo: Vector3i = b["lo"]
	if niveau < lo.y:
		return {"eau": eau, "erreur": ""}
	# Un coin de la boîte : il est au bord, donc vide, et le bord est d'un seul tenant sous le niveau.
	var depart := lo
	eau[depart] = true
	var file: Array[Vector3i] = [depart]
	var i := 0
	while i < file.size():
		var c: Vector3i = file[i]
		i += 1
		for f: Vector3i in VOISINS:
			var v: Vector3i = c + f
			if v.y > niveau or eau.has(v) or occupees.has(v) or not _dans(b, v):
				continue
			eau[v] = true
			if eau.size() > maxi:
				return {"eau": {}, "erreur": "trop_grand"}
			file.append(v)
	return {"eau": eau, "erreur": ""}


# ── le tas (priorité, ordre d'insertion) ─────────────────────────────────────────────────────────────

static func _avant(a: Array, b: Array) -> bool:
	return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])


static func _pousser(tas: Array, e: Array) -> void:
	tas.append(e)
	var i := tas.size() - 1
	while i > 0:
		var p := (i - 1) >> 1
		if not _avant(tas[i], tas[p]):
			break
		var t: Array = tas[i]
		tas[i] = tas[p]
		tas[p] = t
		i = p


static func _tirer(tas: Array) -> Array:
	var haut: Array = tas[0]
	var dernier: Array = tas.pop_back()
	if not tas.is_empty():
		tas[0] = dernier
		var i := 0
		var n := tas.size()
		while true:
			var g := 2 * i + 1
			var d := g + 1
			var m := i
			if g < n and _avant(tas[g], tas[m]):
				m = g
			if d < n and _avant(tas[d], tas[m]):
				m = d
			if m == i:
				break
			var t: Array = tas[i]
			tas[i] = tas[m]
			tas[m] = t
			i = m
	return haut


## LE CREUX : remplissage par priorité depuis `c`, l'eau déjà là (`eau`) faisant office d'issue.
## Rend {"niveau", "cases": {case: true}, "seuil": case au-dessus du bord par où ça déborde, ou null,
## "issue": "sort" | "rejoint" | "ferme", "erreur"}. Sans issue (cavité close), le lac monte jusqu'à `plafond`.
static func _creux(occupees: Dictionary, b: Dictionary, eau: Callable, c: Vector3i, plafond: int,
		maxi: int) -> Dictionary:
	var tas: Array = []
	var seq := 0
	var vus := {c: true}
	var pred := {}
	var prio := {c: c.y}
	_pousser(tas, [c.y, seq, c])
	seq += 1
	var sortis: Array[Vector3i] = []
	while not tas.is_empty():
		var e: Array = _tirer(tas)
		var p: int = e[0]
		var u: Vector3i = e[2]
		var est_eau: bool = eau.call(u)
		if est_eau or _au_bord(b, u):
			# L'issue : tout ce qui est sorti sous P est le lac.
			var lac := {}
			for s in sortis:
				if prio[s] < p:
					lac[s] = true
			# Le seuil : la première case du chemin dont la priorité atteint P (elle est à l'altitude P).
			var chemin: Array[Vector3i] = []
			var w: Variant = u
			while w != null:
				chemin.push_front(w)
				w = pred.get(w)
			var seuil: Variant = null
			for s in chemin:
				if prio[s] >= p:
					seuil = s
					break
			return {"niveau": p - 1, "cases": lac, "seuil": seuil, "issue": "rejoint" if est_eau else "sort",
				"erreur": ""}
		sortis.append(u)
		if sortis.size() > maxi:
			return {"erreur": "trop_grand"}
		for f: Vector3i in VOISINS:
			var v: Vector3i = u + f
			if vus.has(v) or occupees.has(v) or not _dans(b, v):
				continue
			vus[v] = true
			pred[v] = u
			var q := maxi(p, v.y)
			prio[v] = q
			_pousser(tas, [q, seq, v])
			seq += 1
	# Cavité close : le lac monte jusqu'au plafond demandé, ou jusqu'au haut de la cavité si elle est plus basse.
	var ferme := {}
	var niveau := c.y
	for s in sortis:
		if prio[s] <= plafond:
			ferme[s] = true
			niveau = maxi(niveau, s.y)
	return {"niveau": niveau, "cases": ferme, "seuil": null, "issue": "ferme", "erreur": ""}


## LA COULÉE À PLAT : depuis `c`, à son étage, le plus court chemin (largeur d'abord, voisins dans l'ordre)
## jusqu'à une case d'où l'eau tombe, rejoint une eau, ou quitte le monde. `ignorer` : le lac qu'on vient de
## quitter, au-dessus duquel on passe sans y retomber.
## Rend {"chemin": Array[Vector3i], "fin": "" (tombe ensuite) | "sort" | "rejoint"} ou {} si c'est un creux.
static func _a_plat(occupees: Dictionary, b: Dictionary, eau: Callable, c: Vector3i, ignorer: Dictionary,
		maxi: int) -> Dictionary:
	var pred := {c: null}
	var file: Array[Vector3i] = [c]
	var i := 0
	while i < file.size():
		var u: Vector3i = file[i]
		i += 1
		var d: Vector3i = u + BAS
		var fin := "?"
		if not ignorer.has(d) and eau.call(d):
			fin = "rejoint"
		elif not occupees.has(d) and not ignorer.has(d) and _dans(b, d):
			fin = ""
		elif _au_bord(b, u):
			fin = "sort"
		if fin == "?":
			for f: Vector3i in HORIZONTALES:
				var v: Vector3i = u + f
				if occupees.has(v) or not _dans(b, v) or pred.has(v):
					continue
				if eau.call(v):
					fin = "rejoint"
					break
				pred[v] = u
				file.append(v)
		if fin != "?":
			var chemin: Array[Vector3i] = []
			var w: Variant = u
			while w != null:
				chemin.push_front(w)
				w = pred[w]
			return {"chemin": chemin, "fin": fin}
		if file.size() > maxi:
			return {"erreur": "trop_grand"}
	return {}


## UNE SOURCE. `eau_fixe` : l'eau déjà là (les océans), que la source peut rejoindre.
## Rend :
##   genre   — "ocean", "lac", "riviere", ou "" sur erreur ;
##   erreur  — "" ou dans_la_matiere, dans_l_eau, trop_grand, trop_long ;
##   niveau  — océan et lac : le niveau (la plus haute rangée de cases d'eau) ;
##   eau     — {case: true} : TOUT le volume d'eau de la source (lacs de la rivière compris ; pas l'océan d'un
##             autre) ;
##   lacs    — [{niveau, cases}] ; un lac seul en a un, une rivière autant que de creux remplis en route ;
##   cours   — [{case, genre}] dans l'ordre : "coule" (à plat), "chute" (cascade), "lac" (entrée dans le lac
##             d'indice `lac`) ;
##   fin     — rivière : "sort", "rejoint" ou "ferme" ; lac : "ferme" s'il est dans une cavité close.
static func source(occupees: Dictionary, s: Vector3i, eau_fixe: Dictionary = {}, maxi := VOLUME_MAXI) -> Dictionary:
	var r := {"genre": "", "erreur": "", "niveau": 0, "eau": {}, "lacs": [], "cours": [], "fin": ""}
	if occupees.has(s):
		r["erreur"] = "dans_la_matiere"
		return r
	if eau_fixe.has(s):
		r["erreur"] = "dans_l_eau"
		return r
	if dans_le_vide(occupees, s):
		var o := ocean(occupees, s.y, maxi)
		if o["erreur"] != "":
			r["erreur"] = o["erreur"]
			return r
		r["genre"] = "ocean"
		r["niveau"] = s.y
		r["eau"] = o["eau"]
		return r
	var b := boite(occupees)
	var lacs_d := {}
	var eau := func(c: Vector3i) -> bool: return eau_fixe.has(c) or lacs_d.has(c)
	# Le clic au-dessus du sol : on descend jusqu'à lui, sans rien noter.
	# ⚠ Bornée au fond de la boîte : `dans_le_vide` garantit un sol, mais une boucle sans fin ne se garde pas
	# sur une promesse.
	var c := s
	while not occupees.has(c + BAS) and c.y > (b["lo"] as Vector3i).y:
		c += BAS
		if eau_fixe.has(c):
			r["erreur"] = "dans_l_eau"
			return r
	var cours: Array = []
	var lacs: Array = []
	var ignorer := {}
	var premier := true
	var etapes := 0
	while true:
		etapes += 1
		if etapes > ETAPES_MAXI or cours.size() > ETAPES_MAXI:
			return _refus(r, "trop_long")
		var plat := _a_plat(occupees, b, eau, c, ignorer, maxi)
		if plat.has("erreur"):
			return _refus(r, plat["erreur"])
		if plat.is_empty():
			var creux := _creux(occupees, b, eau, c, s.y, maxi)
			if creux["erreur"] != "":
				return _refus(r, creux["erreur"])
			lacs.append({"niveau": creux["niveau"], "cases": creux["cases"]})
			for k in creux["cases"]:
				lacs_d[k] = true
			if premier:
				r["genre"] = "lac"
				r["niveau"] = creux["niveau"]
				r["fin"] = "ferme" if creux["issue"] == "ferme" else ""
				break
			cours.append({"case": c, "genre": "lac", "lac": lacs.size() - 1})
			if creux["issue"] == "ferme":
				r["fin"] = "ferme"
				break
			# Un lac qui touche une autre eau à son seuil s'y déverse directement.
			if eau.call(creux["seuil"]):
				r["fin"] = "rejoint"
				break
			c = creux["seuil"]
			ignorer = creux["cases"]
			continue
		premier = false
		r["genre"] = "riviere"
		for k: Vector3i in plat["chemin"]:
			if cours.is_empty() or cours[-1]["case"] != k:
				cours.append({"case": k, "genre": "coule"})
		if plat["fin"] != "":
			r["fin"] = plat["fin"]
			break
		ignorer = {}
		# La chute : jusqu'au sol, à une eau, ou hors du monde.
		var u: Vector3i = plat["chemin"][-1]
		var fin := ""
		while true:
			var v: Vector3i = u + BAS
			if eau.call(v):
				fin = "rejoint"
				break
			if occupees.has(v):
				break
			cours.append({"case": v, "genre": "chute"})
			u = v
			# ⚠ Le FOND seulement : une cascade qui longe un côté de la boîte tombe au pied d'une falaise du
			# bord du monde, et doit aller jusqu'en bas (ou jusqu'à l'océan).
			if v.y == (b["lo"] as Vector3i).y:
				fin = "sort"
				break
		if fin != "":
			r["fin"] = fin
			break
		c = u
	r["cours"] = cours
	r["lacs"] = lacs
	r["eau"] = lacs_d
	return r


static func _refus(r: Dictionary, erreur: String) -> Dictionary:
	r["genre"] = ""
	r["erreur"] = erreur
	r["eau"] = {}
	r["lacs"] = []
	r["cours"] = []
	r["fin"] = ""
	return r


## LE MONDE D'EAU : toutes les sources, les océans d'abord (ils ne dépendent de personne), puis chacune des
## autres contre les océans SEULEMENT — l'ordre des sources ne change donc rien. Deux rivières peuvent se
## recouvrir : on les dessine l'une sur l'autre.
## Rend {"corps": [un résultat de `source` par source, dans l'ordre donné], "ocean": {case: true}}.
static func monde(occupees: Dictionary, sources: Array, maxi := VOLUME_MAXI) -> Dictionary:
	var corps: Array = []
	corps.resize(sources.size())
	var ocean_d := {}
	for i in sources.size():
		var s: Vector3i = sources[i]
		if not occupees.has(s) and dans_le_vide(occupees, s):
			corps[i] = source(occupees, s, {}, maxi)
			for k in corps[i]["eau"]:
				ocean_d[k] = true
	for i in sources.size():
		if corps[i] == null:
			corps[i] = source(occupees, sources[i], ocean_d, maxi)
	return {"corps": corps, "ocean": ocean_d}


## LA SURFACE d'une eau : ses cases dont la case du dessus n'est ni de l'eau ni pleine. Sous un plafond
## (une galerie noyée) il n'y a pas de surface.
static func surface(eau: Dictionary, occupees: Dictionary) -> Array[Vector3i]:
	var s: Array[Vector3i] = []
	for c: Vector3i in eau:
		var h: Vector3i = c + HAUT
		if not eau.has(h) and not occupees.has(h):
			s.append(c)
	return s


## LA PROFONDEUR sous une case d'eau, en cases d'eau jusqu'au fond (elle comprise) ; −1 si l'eau descend
## jusqu'au bas du monde sans rencontrer de fond (un océan au large).
static func profondeur(eau: Dictionary, occupees: Dictionary, c: Vector3i) -> int:
	var n := 0
	var u := c
	while eau.has(u):
		n += 1
		u += BAS
	return n if occupees.has(u) else -1
