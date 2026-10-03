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
##     remplit jusqu'à son SEUIL : le niveau le plus haut où il ne déborde pas. ⚠ **IL DÉBORDE SI UNE CHUTE EST
##     PROCHE — DÉCIDÉ (Jordan, 2 octobre 2026 : « un lac qui a une digue qui donne sur une falaise ne déborde pas
##     vers le bas comme une coulée »)** : si, depuis le seuil, l'eau trouve à plat une chute (ou une autre eau) à
##     au plus `PORTEE_DE_DEBORD` cases, le lac devient le premier lac d'une RIVIÈRE qui part du seuil. Sinon
##     (un cratère au milieu d'une plaine) il reste calme : pas de rivière qui rampe jusqu'au bord du monde ;
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
## Un lac déborde si, depuis son seuil, une chute est à au plus tant de cases à plat (PROPOSÉ : « quelques cases »).
const PORTEE_DE_DEBORD := 4

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
static func dans_le_vide(occupees: Dictionary, source: Vector3i, b: Dictionary = {}) -> bool:
	if b.is_empty():
		b = boite(occupees)
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
## faces) à l'horizon. Rend {"eau": {case: true}, "colonnes": [[x, z, y0, y1], …], "erreur": ""} ; erreur
## « trop_grand » au-delà de `maxi`. Un océan sous le monde entier, ou sans monde, n'a aucune case : il n'est qu'un
## plan, à l'horizon.
## ⚠ **PAR TRONÇONS DE COLONNE, PAS CASE PAR CASE (Jordan, 2 octobre 2026 : « les algos d'eau sont beaucoup trop
## lents »)** : un tronçon est un intervalle vertical de cases vides d'une colonne, sous le niveau. Le fond de la boîte
## est l'horizon, donc le tronçon du bas de CHAQUE colonne est de l'océan ; les autres (des grottes sous la roche) le
## sont s'ils touchent, par une face, un tronçon d'océan d'une colonne voisine — leurs intervalles se chevauchent.
## C'est le même ensemble que le remplissage case par case (gardé par `test_fluides`, contre un remplissage écrit dans
## le test), pour un tronçon par colonne au lieu d'une entrée par case. `colonnes` le rend au maillage.
static func ocean(occupees: Dictionary, niveau: int, maxi := VOLUME_MAXI, b: Dictionary = {}) -> Dictionary:
	var eau := {}
	if b.is_empty():
		b = boite(occupees)
	if b.is_empty():
		return {"eau": eau, "colonnes": [], "erreur": ""}
	var lo: Vector3i = b["lo"]
	var hi: Vector3i = b["hi"]
	if niveau < lo.y:
		return {"eau": eau, "colonnes": [], "erreur": ""}
	var haut := mini(niveau, hi.y)
	# Les cases pleines de chaque colonne, sous le niveau.
	var pleins := {}
	for c: Vector3i in occupees:
		if c.y <= haut:
			var k := Vector2i(c.x, c.z)
			if pleins.has(k):
				(pleins[k] as Array).append(c.y)
			else:
				pleins[k] = [c.y]
	# Les tronçons : x, z, y0, y1 à plat ; `debut[colonne]` = [premier tronçon, nombre].
	var tx := PackedInt32Array()
	var tz := PackedInt32Array()
	var t0 := PackedInt32Array()
	var t1 := PackedInt32Array()
	var debut := {}
	for x in range(lo.x, hi.x + 1):
		for z in range(lo.z, hi.z + 1):
			var k := Vector2i(x, z)
			var premier := t0.size()
			var y := lo.y
			if pleins.has(k):
				var ys: Array = pleins[k]
				ys.sort()
				for f: int in ys:
					if f > y:
						tx.append(x)
						tz.append(z)
						t0.append(y)
						t1.append(f - 1)
					y = f + 1
			if y <= haut:
				tx.append(x)
				tz.append(z)
				t0.append(y)
				t1.append(haut)
			debut[k] = Vector2i(premier, t0.size() - premier)
	# Le remplissage, de tronçon en tronçon : le bas de chaque colonne d'abord.
	var dans := PackedByteArray()
	dans.resize(t0.size())
	var file := PackedInt32Array()
	for i in t0.size():
		if t0[i] == lo.y:
			dans[i] = 1
			file.append(i)
	var n := 0
	while n < file.size():
		var i: int = file[n]
		n += 1
		for f: Vector3i in HORIZONTALES:
			var v: Variant = debut.get(Vector2i(tx[i] + f.x, tz[i] + f.z))
			if v == null:
				continue
			for j in range((v as Vector2i).x, (v as Vector2i).x + (v as Vector2i).y):
				if dans[j] == 0 and t0[j] <= t1[i] and t1[j] >= t0[i]:
					dans[j] = 1
					file.append(j)
	var volume := 0
	for i in file:
		volume += t1[i] - t0[i] + 1
	if volume > maxi:
		return {"eau": {}, "colonnes": [], "erreur": "trop_grand"}
	var colonnes: Array = []
	for i in file:
		colonnes.append([tx[i], tz[i], t0[i], t1[i]])
		for y in range(t0[i], t1[i] + 1):
			eau[Vector3i(tx[i], y, tz[i])] = true
	return {"eau": eau, "colonnes": colonnes, "erreur": ""}


# ── le tas (priorité, ordre d'insertion) ─────────────────────────────────────────────────────────────
#
# ⚠ UNE CLÉ ENTIÈRE PAR ENTRÉE (2 octobre 2026, « les algos d'eau sont beaucoup trop lents ») : (priorité, ordre
# d'insertion) tient dans un entier de 64 bits — la priorité décalée de `BIAIS` dans les 32 bits hauts, l'ordre dans
# les bas. Comparer deux entiers rend EXACTEMENT l'ordre (priorité, puis insertion) d'avant, qui comparait des
# tableaux par une fonction ; la case de l'entrée est dans `cases[ordre]`.

const BIAIS := 1 << 20


static func _cle(priorite: int, ordre: int) -> int:
	return ((priorite + BIAIS) << 32) | ordre


static func _pousser(tas: PackedInt64Array, cle: int) -> void:
	tas.append(cle)
	var i := tas.size() - 1
	while i > 0:
		var p := (i - 1) >> 1
		if tas[i] >= tas[p]:
			break
		var t: int = tas[i]
		tas[i] = tas[p]
		tas[p] = t
		i = p


static func _tirer(tas: PackedInt64Array) -> int:
	var haut: int = tas[0]
	var n := tas.size() - 1
	tas[0] = tas[n]
	tas.resize(n)
	var i := 0
	while true:
		var g := 2 * i + 1
		if g >= n:
			break
		var m := g
		if g + 1 < n and tas[g + 1] < tas[g]:
			m = g + 1
		if tas[m] >= tas[i]:
			break
		var t: int = tas[i]
		tas[i] = tas[m]
		tas[m] = t
		i = m
	return haut


## LE CREUX : remplissage par priorité depuis `c`, l'eau déjà là (`fixe`, et les lacs déjà posés, `lacs`) faisant
## office d'issue. Rend {"niveau", "cases": {case: true}, "seuil": case au-dessus du bord par où ça déborde, ou null,
## "issue": "sort" | "rejoint" | "ferme", "erreur", "vus"}. Sans issue (cavité close), le lac monte jusqu'à `plafond`.
static func _creux(occupees: Dictionary, b: Dictionary, fixe: Dictionary, lacs: Dictionary, c: Vector3i, plafond: int,
		maxi: int) -> Dictionary:
	var lo: Vector3i = b["lo"]
	var hi: Vector3i = b["hi"]
	var tas := PackedInt64Array()
	var cases: Array[Vector3i] = [c]
	var vus := {c: true}
	var pred := {}
	var prio := {c: c.y}
	_pousser(tas, _cle(c.y, 0))
	var sortis: Array[Vector3i] = []
	while not tas.is_empty():
		var k := _tirer(tas)
		var p: int = (k >> 32) - BIAIS
		var u: Vector3i = cases[k & 0xFFFFFFFF]
		var est_eau: bool = fixe.has(u) or lacs.has(u)
		if est_eau or u.x == lo.x or u.y == lo.y or u.z == lo.z or u.x == hi.x or u.z == hi.z:
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
				"erreur": "", "vus": vus}
		sortis.append(u)
		if sortis.size() > maxi:
			return {"erreur": "trop_grand"}
		for f: Vector3i in VOISINS:
			var v: Vector3i = u + f
			if vus.has(v) or occupees.has(v) or v.x < lo.x or v.y < lo.y or v.z < lo.z or v.x > hi.x or v.y > hi.y 					or v.z > hi.z:
				continue
			vus[v] = true
			pred[v] = u
			var q := maxi(p, v.y)
			prio[v] = q
			_pousser(tas, _cle(q, cases.size()))
			cases.append(v)
	# Cavité close : le lac monte jusqu'au plafond demandé, ou jusqu'au haut de la cavité si elle est plus basse.
	var ferme := {}
	var niveau := c.y
	for s in sortis:
		if prio[s] <= plafond:
			ferme[s] = true
			niveau = maxi(niveau, s.y)
	return {"niveau": niveau, "cases": ferme, "seuil": null, "issue": "ferme", "erreur": "", "vus": vus}


## LA COULÉE À PLAT : depuis `c`, à son étage, le plus court chemin (largeur d'abord, voisins dans l'ordre)
## jusqu'à une case d'où l'eau tombe, rejoint une eau, ou quitte le monde. `ignorer` : le lac qu'on vient de
## quitter, au-dessus duquel on passe sans y retomber.
## Rend {"chemin": Array[Vector3i], "fin": "" (tombe ensuite) | "sort" | "rejoint", "vus"}, ou {"creux": true, "vus"}
## si c'est un creux ; `vus` : les cases parcourues (l'emprise).
## ⚠ L'EAU EST LUE DANS DEUX DICTIONNAIRES (`fixe`, `lacs`), PLUS PAR UN CALLABLE : appeler une fonction par case
## visitée coûtait plus que la visite (2 octobre 2026, une rivière sur le grand plateau de l'exemple : 2,7 s).
static func _a_plat(occupees: Dictionary, b: Dictionary, fixe: Dictionary, lacs: Dictionary, c: Vector3i,
		ignorer: Dictionary, maxi: int) -> Dictionary:
	var lo: Vector3i = b["lo"]
	var hi: Vector3i = b["hi"]
	var pred := {c: null}
	var file: Array[Vector3i] = [c]
	var i := 0
	while i < file.size():
		var u: Vector3i = file[i]
		i += 1
		var d: Vector3i = u + BAS
		var fin := "?"
		if not ignorer.has(d) and (fixe.has(d) or lacs.has(d)):
			fin = "rejoint"
		elif not occupees.has(d) and not ignorer.has(d) and d.y >= lo.y:
			fin = ""
		elif u.x == lo.x or u.y == lo.y or u.z == lo.z or u.x == hi.x or u.z == hi.z:
			fin = "sort"
		if fin == "?":
			for f: Vector3i in HORIZONTALES:
				var v: Vector3i = u + f
				if occupees.has(v) or v.x < lo.x or v.z < lo.z or v.x > hi.x or v.z > hi.z or pred.has(v):
					continue
				if fixe.has(v) or lacs.has(v):
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
			return {"chemin": chemin, "fin": fin, "vus": pred}
		if file.size() > maxi:
			return {"erreur": "trop_grand"}
	return {"vus": pred, "creux": true}


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
## `b` : la boîte du monde, si l'appelant l'a déjà (`monde` la calcule UNE fois : 57 ms sur l'exemple, par appel).
static func source(occupees: Dictionary, s: Vector3i, eau_fixe: Dictionary = {}, maxi := VOLUME_MAXI,
		b: Dictionary = {}) -> Dictionary:
	if b.is_empty():
		b = boite(occupees)
	var r := {"genre": "", "erreur": "", "niveau": 0, "eau": {}, "lacs": [], "cours": [], "fin": ""}
	if occupees.has(s):
		r["erreur"] = "dans_la_matiere"
		return r
	if eau_fixe.has(s):
		r["erreur"] = "dans_l_eau"
		return r
	if dans_le_vide(occupees, s, b):
		var o := ocean(occupees, s.y, maxi, b)
		if o["erreur"] != "":
			r["erreur"] = o["erreur"]
			return r
		r["genre"] = "ocean"
		r["niveau"] = s.y
		r["eau"] = o["eau"]
		r["colonnes"] = o["colonnes"]
		# L'océan dépend de toute la boîte sous son niveau, et de la rangée du dessus (sa surface).
		var bo := b
		if not bo.is_empty():
			r["emprise"] = [bo["lo"], Vector3i((bo["hi"] as Vector3i).x, s.y + 1, (bo["hi"] as Vector3i).z)]
		r["boite"] = bo
		return r
	var lacs_d := {}
	# Le clic au-dessus du sol : on descend jusqu'à lui, sans rien noter.
	# ⚠ Bornée au fond de la boîte : `dans_le_vide` garantit un sol, mais une boucle sans fin ne se garde pas
	# sur une promesse.
	var emprise := {"lo": s, "hi": s}
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
		var plat := _a_plat(occupees, b, eau_fixe, lacs_d, c, ignorer, maxi)
		if plat.has("erreur"):
			return _refus(r, plat["erreur"])
		_etendre(emprise, plat.get("vus", {}))
		if plat.has("creux"):
			var creux := _creux(occupees, b, eau_fixe, lacs_d, c, s.y, maxi)
			_etendre(emprise, creux.get("vus", {}))
			if creux["erreur"] != "":
				return _refus(r, creux["erreur"])
			lacs.append({"niveau": creux["niveau"], "cases": creux["cases"]})
			for k in creux["cases"]:
				lacs_d[k] = true
			if premier and not (creux["issue"] == "sort"
					and _chute_proche(occupees, b, eau_fixe, lacs_d, creux["seuil"], creux["cases"], maxi, emprise)):
				r["genre"] = "lac"
				r["niveau"] = creux["niveau"]
				r["fin"] = "ferme" if creux["issue"] == "ferme" else ""
				break
			# Le lac déborde (une chute proche de son seuil) : il est le premier lac d'une rivière.
			premier = false
			r["genre"] = "riviere"
			cours.append({"case": c, "genre": "lac", "lac": lacs.size() - 1})
			if creux["issue"] == "ferme":
				r["fin"] = "ferme"
				break
			# Un lac qui touche une autre eau à son seuil s'y déverse directement.
			if eau_fixe.has(creux["seuil"]) or lacs_d.has(creux["seuil"]):
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
			if eau_fixe.has(v) or lacs_d.has(v):
				fin = "rejoint"
				break
			if occupees.has(v):
				break
			cours.append({"case": v, "genre": "chute"})
			_etendre(emprise, {v: true})
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
	_etendre(emprise, {c: true})
	r["emprise"] = [(emprise["lo"] as Vector3i) - Vector3i.ONE, (emprise["hi"] as Vector3i) + Vector3i.ONE]
	r["boite"] = b
	return r


## L'EMPRISE d'une source : la boîte de toutes les cases qu'elle a regardées (élargie d'une case à la fin : on lit
## aussi leurs voisines). Une case changée HORS de l'emprise, la boîte du monde et l'eau des océans inchangées, ne peut
## pas changer ce que la source devient — l'appli reprend alors son résultat sans le recalculer.
static func _etendre(e: Dictionary, cases: Dictionary) -> void:
	var lo: Vector3i = e["lo"]
	var hi: Vector3i = e["hi"]
	for k: Vector3i in cases:
		lo = Vector3i(mini(lo.x, k.x), mini(lo.y, k.y), mini(lo.z, k.z))
		hi = Vector3i(maxi(hi.x, k.x), maxi(hi.y, k.y), maxi(hi.z, k.z))
	e["lo"] = lo
	e["hi"] = hi


## Depuis le seuil d'un lac, l'eau trouve-t-elle à plat une chute (ou une autre eau, ou le bord du monde) à au plus
## `PORTEE_DE_DEBORD` cases ? C'est la même coulée que celle de la rivière (`_a_plat`), bornée.
static func _chute_proche(occupees: Dictionary, b: Dictionary, fixe: Dictionary, lacs: Dictionary, seuil: Variant,
		lac: Dictionary, maxi: int, emprise: Dictionary) -> bool:
	if seuil == null:
		return false
	var plat := _a_plat(occupees, b, fixe, lacs, seuil, lac, mini(maxi, (2 * PORTEE_DE_DEBORD + 1) ** 2))
	_etendre(emprise, plat.get("vus", {}))
	return plat.has("chemin") and (plat["chemin"] as Array).size() - 1 <= PORTEE_DE_DEBORD


static func _refus(r: Dictionary, erreur: String) -> Dictionary:
	r["genre"] = ""
	r["erreur"] = erreur
	r["eau"] = {}
	r["lacs"] = []
	r["cours"] = []
	r["fin"] = ""
	return r


## LA LARGEUR D'UNE RIVIÈRE À LA POSE (Jordan, 3 octobre 2026 : « les waterfalls n'ont pas de largeur réglable à la
## pose ») : `largeur` sources côte à côte, EN TRAVERS du premier pas horizontal de la rivière posée en `s`, centrées
## sur `s` (une case de plus du côté +, quand la largeur est paire). Leurs rivières descendent parallèlement et font
## une cascade large ; deux qui se rejoignent ne posent qu'une eau (le maillage les fusionne). Seules restent les
## voisines qui SONT des rivières (ni dans la matière, ni un lac, ni une mer, ni dans l'eau déjà là) ; `s` d'abord.
## Une source qui n'est pas une rivière ne s'élargit pas : un lac et une mer ont leur propre étendue.
static func sources_en_largeur(occupees: Dictionary, s: Vector3i, largeur: int, eau_fixe: Dictionary = {}) -> Array:
	var r := source(occupees, s, eau_fixe)
	if largeur <= 1 or r["genre"] != "riviere":
		return [s]
	var travers := Vector3i(1, 0, 0)
	var cours: Array = r["cours"]
	for i in range(1, cours.size()):
		var a: Vector3i = cours[i - 1]["case"]
		var b: Vector3i = cours[i]["case"]
		if a.x != b.x or a.z != b.z:
			travers = Vector3i(0, 0, 1) if b.x != a.x else Vector3i(1, 0, 0)
			break
	var sortie: Array = [s]
	var bas := -((largeur - 1) / 2)
	for k in range(bas, bas + largeur):
		if k == 0:
			continue
		var c: Vector3i = s + travers * k
		if occupees.has(c):
			continue
		var rc := source(occupees, c, eau_fixe)
		if rc["erreur"] == "" and rc["genre"] == "riviere":
			sortie.append(c)
	return sortie


## LE MONDE D'EAU : toutes les sources, les océans d'abord (ils ne dépendent de personne), puis chacune des
## autres contre les océans SEULEMENT — l'ordre des sources ne change donc rien. Deux rivières peuvent se
## recouvrir : on les dessine l'une sur l'autre.
## Rend {"corps": [un résultat de `source` par source, dans l'ordre donné], "ocean": {case: true}}.
##
## ⚠ **LA REPRISE (Jordan, 2 octobre 2026 : « les algos d'eau sont beaucoup trop lents »)** : `avant` est le rendu
## d'un appel précédent, `changees` les cases pleines ajoutées ou retirées depuis. Une source dont aucune case changée
## n'est dans l'EMPRISE (`_etendre`), sous la même boîte du monde, est REPRISE telle quelle (le même dictionnaire :
## l'appelant le reconnaît par `is_same`) ; une source qui n'est pas un océan exige en plus que les océans soient
## tous repris. Peindre une montagne au-dessus de la mer ne recalcule plus la mer. `changees` null : tout est refait.
static func monde(occupees: Dictionary, sources: Array, maxi := VOLUME_MAXI, avant: Dictionary = {},
		changees: Variant = null) -> Dictionary:
	var corps: Array = []
	corps.resize(sources.size())
	var b := boite(occupees)
	var vieux := {}
	if changees != null and avant.has("corps") and avant.has("sources"):
		for i in (avant["sources"] as Array).size():
			vieux[avant["sources"][i]] = avant["corps"][i]
	var reprendre := func(s: Vector3i) -> Variant:
		var r: Variant = vieux.get(s, null)
		if r == null or r["erreur"] != "" or not r.has("emprise") or not _boite_compatible(r, b):
			return null
		var lo: Vector3i = r["emprise"][0]
		var hi: Vector3i = r["emprise"][1]
		for c: Vector3i in changees:
			if c.x >= lo.x and c.y >= lo.y and c.z >= lo.z and c.x <= hi.x and c.y <= hi.y and c.z <= hi.z:
				return null
		return r
	var ocean_d := {}
	var oceans_repris := true
	var n_oceans := 0
	for i in sources.size():
		var s: Vector3i = sources[i]
		if not occupees.has(s) and dans_le_vide(occupees, s, b):
			# ⚠ UN SEUL OCÉAN, À UN SEUL NIVEAU (Jordan, 3 octobre 2026) : le premier dans l'ordre des sources l'est ;
			# un autre est refusé (« un_seul_ocean ») — deux plans à deux hauteurs n'ont pas de sens.
			if n_oceans > 0:
				corps[i] = _refus({"genre": "", "erreur": "", "niveau": 0, "eau": {}, "lacs": [], "cours": [],
					"fin": ""}, "un_seul_ocean")
				continue
			n_oceans += 1
			var r: Variant = reprendre.call(s)
			if r == null or r["genre"] != "ocean":
				oceans_repris = false
				r = source(occupees, s, {}, maxi, b)
			corps[i] = r
	# Les océans tous repris, et aucun de perdu : leur eau aussi.
	var n_avant := 0
	for r in avant.get("corps", []):
		if r != null and r["genre"] == "ocean":
			n_avant += 1
	oceans_repris = oceans_repris and not vieux.is_empty() and n_oceans == n_avant and avant.has("ocean")
	if oceans_repris:
		ocean_d = avant["ocean"]
	else:
		for r in corps:
			if r != null:
				for k in r["eau"]:
					ocean_d[k] = true
	for i in sources.size():
		if corps[i] == null:
			var r: Variant = reprendre.call(sources[i]) if oceans_repris else null
			if r == null or r["genre"] == "ocean":
				r = source(occupees, sources[i], ocean_d, maxi, b)
			corps[i] = r
	return {"corps": corps, "ocean": ocean_d, "sources": sources.duplicate()}


## La boîte du monde a-t-elle changé LÀ OÙ la source regardait ? Chaque face (côtés, fond, dessus) qui a bougé doit
## rester hors de l'emprise, à son ancienne place comme à la nouvelle : peindre au-dessus du point le plus haut monte
## le dessus de la boîte, et ne doit pas faire recalculer un lac qui n'est jamais monté jusque-là.
static func _boite_compatible(r: Dictionary, b: Dictionary) -> bool:
	var rb: Dictionary = r.get("boite", {})
	if rb.is_empty() or b.is_empty():
		return rb.is_empty() and b.is_empty()
	var elo: Vector3i = r["emprise"][0]
	var ehi: Vector3i = r["emprise"][1]
	var alo: Vector3i = rb["lo"]
	var ahi: Vector3i = rb["hi"]
	var nlo: Vector3i = b["lo"]
	var nhi: Vector3i = b["hi"]
	for k in 3:
		if alo[k] != nlo[k] and elo[k] <= maxi(alo[k], nlo[k]):
			return false
		if ahi[k] != nhi[k] and ehi[k] >= mini(ahi[k], nhi[k]):
			return false
	return true


## Les cases pleines ajoutées ou retirées entre deux états du monde.
static func changees_entre(avant: Dictionary, apres: Dictionary) -> Dictionary:
	var d := {}
	for c in apres:
		if not avant.has(c):
			d[c] = true
	for c in avant:
		if not apres.has(c):
			d[c] = true
	return d


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
