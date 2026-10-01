@tool
extends RefCounted
## LES FORMES SPÉCIALES — tunnel, puits, pont et balcon, posés d'un ou deux clics.
##
## **DEMANDÉ PAR JORDAN (1er octobre 2026)** : un onglet « Special shapes » à côté des opérations de forme.
## Un tunnel dans une paroi et un puits dans un sol, PERPENDICULAIRES à leur surface, capables de rejoindre
## une seconde salle en restant ouverts aux deux embouchures ; un pont entre deux parois face à face ; un
## balcon contre une paroi. Et la généralisation qu'il a proposée : deux cases sur deux parois quelconques
## (diagonales comprises), un PROFIL, et l'outil les relie.
##
## ⚠ **TUNNEL, PUITS ET PONT SONT LA MÊME OPÉRATION** : relier deux ANCRES (une case et la normale de sa
## paroi) par un conduit — une JAMBE perpendiculaire à chaque paroi, puis un raccord droit entre leurs
## bouts —, balayé par un profil. Le tunnel et le puits CREUSENT dans la roche, le pont REMPLIT dans l'air.
## Le balcon n'a qu'une ancre et ne relie rien : une dalle contre la paroi.
##
## ⚠ **TOUT EST EN ENTIERS, ET CE N'EST PAS UNE COQUETTERIE** : la règle est réécrite en C# et en C++ par
## les trois greffons (`tools_conformance.json`). Une courbe en flottants se départagerait autrement d'un
## langage à l'autre sur les cases du bord ; ici chaque test est une comparaison d'entiers EXACTE — les
## distances au carré, jamais une racine. Les centres de cases sont les points de calcul : tous les
## décalages sont entiers.
##
## ⚠ **LE MONDE N'A PAS DE CONTACT DIAGONAL** (charte §2), et un conduit balayé en biais en crée à chaque
## marche. **DÉCIDÉ (Jordan, 1er octobre 2026)** : la forme RÉPARE ELLE-MÊME ceux qu'elle crée — le
## tunnel creuse aussi la paire pleine d'un carré en damier, le pont remplit aussi la paire vide. Ce n'est
## pas la complétion que la charte retire au pinceau : c'est la forme générée qui doit être propre, et l'on
## ne touche qu'aux carrés qui contiennent une case changée par elle. Un damier qui préexistait ailleurs
## n'est pas notre affaire.

const Outils := preload("res://addons/marchingblocks_core/outils.gd")

const QUOI := ["tunnel", "puits", "pont", "balcon"]
const PROFILS := ["rond", "carre", "arche"]

## La marche droite (un clic) et la profondeur d'un balcon : au plus tant de cases.
const LONGUEUR_MAXI := 64
## Deux ancres plus éloignées que ça (en cases, entre leurs centres) ne se relient pas.
const ECART_MAXI := 128

const PLANS := [
	[Vector3i(1, 0, 0), Vector3i(0, 1, 0)],
	[Vector3i(1, 0, 0), Vector3i(0, 0, 1)],
	[Vector3i(0, 1, 0), Vector3i(0, 0, 1)],
]

const HORIZONTALES := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]


## Produit scalaire en entiers 64 bits. ⚠ Les composantes d'un `Vector3i` lues une à une sont des `int`
## de GDScript (64 bits) ; multiplier deux `Vector3i` entre eux resterait en 32 bits.
static func _p(a: Vector3i, b: Vector3i) -> int:
	return int(a.x) * int(b.x) + int(a.y) * int(b.y) + int(a.z) * int(b.z)


static func _signe(x: int) -> int:
	return 1 if x > 0 else (-1 if x < 0 else 0)


## LA NORMALE D'UNE PAROI, ESTIMÉE — ce qui rend les parois DIAGONALES possibles.
##
## Dans un monde de cases, une paroi à 45° est un ESCALIER : la face cliquée dit ±X ou ±Z, jamais la
## diagonale. On additionne les faces HORIZONTALES exposées (case pleine, voisine vide) de la fenêtre 3³
## autour de la case cliquée, puis on ARRONDIT à l'une des huit directions du plan : une composante est
## gardée (son signe) si elle vaut au moins la moitié de la plus grande. Une paroi droite rend sa face ; un
## escalier régulier rend la diagonale.
## ⚠ **TOUTES LES FACES, CELLES DE DOS COMPRISES.** Un premier jet écartait celles qui tournent le dos à la
## face cliquée (F · face < 0) : sur une paroi diagonale de DEUX cases d'épaisseur, il gardait les −Z
## (perpendiculaires à +X) mais pas les −X, et rendait (1, 0, 0) au lieu de (1, 0, 1). Sans filtre, l'avant
## et l'arrière d'une paroi mince s'annulent symétriquement : la somme garde la direction.
## ⚠ Une fenêtre de 3³ et pas plus : au coin d'une salle, les faces de la paroi voisine tireraient la
## normale en biais. Si l'arrondi est nul ou tourne le dos à la face cliquée, on garde la face.
static func normale_estimee(occupees: Dictionary, c: Vector3i, face: Vector3i) -> Vector3i:
	var sx := 0
	var sz := 0
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				var q: Vector3i = c + Vector3i(x, y, z)
				if not occupees.has(q):
					continue
				for f in HORIZONTALES:
					if not occupees.has(q + f):
						sx += f.x
						sz += f.z
	var m: int = maxi(absi(sx), absi(sz))
	if m == 0:
		return face
	var n := Vector3i(_signe(sx) if 2 * absi(sx) >= m else 0, 0, _signe(sz) if 2 * absi(sz) >= m else 0)
	if _p(n, face) <= 0:
		return face
	return n


## La normale qu'une forme retient pour une ancre, ou ZERO si la face ne lui convient pas.
##   puits — la face doit être un sol ou un plafond, et la normale EST cette face ;
##   les autres — la face doit être une paroi (horizontale), et la normale est ESTIMÉE.
static func normale_de(quoi: String, occupees: Dictionary, c: Vector3i, face: Vector3i) -> Vector3i:
	if quoi == "puits":
		return face if face.x == 0 and face.z == 0 and face.y != 0 else Vector3i.ZERO
	if face.y != 0 or (face.x == 0 and face.z == 0):
		return Vector3i.ZERO
	return normale_estimee(occupees, c, face)


static func _creuse(quoi: String) -> bool:
	return quoi == "tunnel" or quoi == "puits"


## LA FORME. `r` porte :
##   quoi        — "tunnel", "puits", "pont" ou "balcon" ;
##   a, face_a   — la case cliquée et la face par laquelle on l'a visée ;
##   relier      — vrai : relier à la seconde ancre (b, face_b) ; faux : un clic, tout droit ;
##   profil      — "rond", "carre" ou "arche" (tunnel et puits ; le pont a son TABLIER) ;
##   taille      — 1 à 7, comme le pinceau : le demi-côté du profil est `taille - 1` ;
##   longueur    — un clic : la profondeur maximale (tunnel, puits), la portée (pont), la profondeur du
##                 balcon ;
##   garde_corps — pont et balcon : un rebord d'une case sur leurs côtés (sans objet si taille = 1).
## Rend {"poser", "effacer", "erreur", "ouvert", "reparees"} ; `erreur` vide si tout va bien, sinon l'un
## de : pas_de_paroi, pas_un_sol, meme_case, trop_long, rien_en_face, trop_grand, forme_inconnue.
## `ouvert` (un clic, tunnel et puits) : la marche a débouché dans un vide ; sinon le conduit est aveugle.
static func forme(occupees: Dictionary, r: Dictionary) -> Dictionary:
	var quoi: String = r.get("quoi", "")
	var sortie := {"poser": {}, "effacer": {}, "erreur": "", "ouvert": false, "reparees": 0}
	if not quoi in QUOI:
		sortie["erreur"] = "forme_inconnue"
		return sortie
	var profil: String = "tablier" if quoi == "pont" else String(r.get("profil", "rond"))
	if not profil in PROFILS and profil != "tablier":
		sortie["erreur"] = "forme_inconnue"
		return sortie
	var demi: int = clampi(int(r.get("taille", 1)), 1, 7) - 1
	var longueur: int = clampi(int(r.get("longueur", 8)), 1, LONGUEUR_MAXI)
	var garde: bool = bool(r.get("garde_corps", false))
	var a: Vector3i = r["a"]
	var na := normale_de(quoi, occupees, a, r["face_a"])
	if na == Vector3i.ZERO:
		sortie["erreur"] = "pas_un_sol" if quoi == "puits" else "pas_de_paroi"
		return sortie
	var creuse := _creuse(quoi)

	var choisies := {}
	if quoi == "balcon":
		choisies = _balcon(a, na, longueur, demi, garde)
	else:
		var points: Array[Vector3i] = []
		if bool(r.get("relier", false)):
			var b: Vector3i = r["b"]
			var nb := normale_de(quoi, occupees, b, r["face_b"])
			if nb == Vector3i.ZERO:
				sortie["erreur"] = "pas_un_sol" if quoi == "puits" else "pas_de_paroi"
				return sortie
			if b == a:
				sortie["erreur"] = "meme_case"
				return sortie
			if _p(b - a, b - a) > ECART_MAXI * ECART_MAXI:
				sortie["erreur"] = "trop_long"
				return sortie
			points = _chemin(a, na, b, nb, demi, creuse)
		else:
			# UN CLIC : tout droit. Creuser — jusqu'à la DERNIÈRE case pleine avant le premier vide (débouché),
			# sinon `longueur` cases dans la roche (un conduit aveugle) ; remplir (le pont) — jusqu'à la
			# première matière en face.
			# ⚠ **LE TUNNEL S'ARRÊTE SUR LA PAROI D'EN FACE, PAS DANS LA SALLE** : il finissait sur la première
			# case vide, et sa dernière tranche creusait une rigole dans le sol de la salle atteinte (vu en
			# écrivant le test de l'embouchure). C'est la même fin qu'en reliant deux ancres. Une paroi d'UNE
			# case d'épaisseur n'a pas de seconde case : le conduit va alors jusqu'au vide.
			var sens: Vector3i = -na if creuse else na
			var fin := Vector3i.ZERO
			var trouve := false
			for k in range(1, longueur + 1):
				var q: Vector3i = a + sens * k
				if occupees.has(q) != creuse:
					fin = q - sens if creuse and k > 1 else q
					trouve = true
					break
			if not trouve:
				if not creuse:
					sortie["erreur"] = "rien_en_face"
					return sortie
				fin = a + sens * longueur
			sortie["ouvert"] = trouve
			points = [a, fin]
		var c := _balayer(points, demi, profil, garde)
		if c.has("erreur"):
			sortie["erreur"] = c["erreur"]
			return sortie
		choisies = c
	if choisies.has("erreur"):
		sortie["erreur"] = choisies["erreur"]
		return sortie

	var poser := {}
	var effacer := {}
	for q in choisies:
		if creuse and occupees.has(q):
			effacer[q] = true
		elif not creuse and not occupees.has(q):
			poser[q] = true
	sortie["reparees"] = _reparer(occupees, poser, effacer, creuse)
	sortie["poser"] = poser
	sortie["effacer"] = effacer
	return sortie


## LE CHEMIN À DEUX ANCRES : A, le bout de sa jambe, le bout de celle de B, B.
##
## Chaque jambe part PERPENDICULAIRE à sa paroi — dans la roche pour un conduit qu'on creuse (−n), dans
## l'air pour un pont (+n) — sur `demi + 1` cases : la longueur qu'il faut pour que l'embouchure entière
## soit droite. ⚠ Une jambe ne dépasse jamais le TIERS du trajet vers l'autre ancre (mesuré sur sa
## projection) : deux parois proches se croiseraient sinon. Deux parois face à face donnent quatre points
## alignés, donc un conduit droit.
static func _chemin(a: Vector3i, na: Vector3i, b: Vector3i, nb: Vector3i, demi: int, creuse: bool) -> Array[Vector3i]:
	var da: Vector3i = -na if creuse else na
	var db: Vector3i = -nb if creuse else nb
	var ea: Vector3i = a + da * _jambe(a, da, b, demi)
	var eb: Vector3i = b + db * _jambe(b, db, a, demi)
	var points: Array[Vector3i] = []
	for p in [a, ea, eb, b]:
		if points.is_empty() or points[points.size() - 1] != p:
			points.append(p)
	return points


static func _jambe(depart: Vector3i, sens: Vector3i, autre: Vector3i, demi: int) -> int:
	var voulu: int = demi + 1
	var nn: int = _p(sens, sens)
	var k := 0
	while k * k * nn < voulu * voulu:
		k += 1
	var w: int = _p(sens, autre - depart)
	var dd: int = _p(autre - depart, autre - depart)
	while k > 0 and w > 0 and 3 * k * w > dd:
		k -= 1
	return k


## LE BALAYAGE : l'union, segment par segment, des cases dont le centre tombe dans le PRISME du profil.
##
## Pour un segment P0 → P1 (D = P1 − P0) et une case q (d = q − P0) :
##   le long  — t = d·D dans [0, D·D] ; aux JOINTS (un bout qui n'est ni A ni B), le prisme se prolonge
##              de `demi` cases, sinon l'extérieur d'un coude resterait entaillé ;
##   le repère — u = D × Y = (−Dz, 0, Dx) à plat, v = u × D vers le haut : le profil garde son HAUT, un
##              tunnel qui descend garde un sol horizontal. Un segment vertical prend u = X, v = Z ;
##   en travers — a = d·u, b = d·v ; les coordonnées vraies sont a/|u| et b/|v|, et chaque test est écrit
##              au carré, multiplié par |u|² et |v|² : des entiers.
## Profils (demi-côté h) : rond a² + b² ≤ h² ; carré |a|, |b| ≤ h ; arche — rond au-dessus de l'axe,
## carré dessous (un sol plat, une voûte ronde) ; tablier — |a| ≤ h et |b| ≤ 1/2 (une case d'épaisseur),
## et le garde-corps : la rangée au-dessus (1/2 < b ≤ 3/2) sur les bords (|a| > h − 1), MOINS ce qui est
## au-dessus du passage d'un autre segment (sinon, à un coude, le rebord d'une jambe barrerait le raccord).
static func _balayer(points: Array[Vector3i], demi: int, profil: String, garde: bool) -> Dictionary:
	var corps := {}
	var rebords := {}
	var passage := {}
	var avec_rebord: bool = profil == "tablier" and garde and demi >= 1
	var dernier: int = points.size() - 1
	if dernier < 1:
		return {"erreur": "meme_case"}
	for i in dernier:
		var p0: Vector3i = points[i]
		var p1: Vector3i = points[i + 1]
		var e0: int = demi if i > 0 else 0
		var e1: int = demi if i + 1 < dernier else 0
		var marge: int = demi + 2 + maxi(e0, e1)
		var bas := Vector3i(mini(p0.x, p1.x), mini(p0.y, p1.y), mini(p0.z, p1.z)) - Vector3i.ONE * marge
		var haut := Vector3i(maxi(p0.x, p1.x), maxi(p0.y, p1.y), maxi(p0.z, p1.z)) + Vector3i.ONE * marge
		var etendue: Vector3i = haut - bas + Vector3i.ONE
		if int(etendue.x) * int(etendue.y) * int(etendue.z) > Outils.VOLUME_MAXI:
			return {"erreur": "trop_grand"}
		var dv: Vector3i = p1 - p0
		var ddv: int = _p(dv, dv)
		var u := Vector3i(1, 0, 0)
		var v := Vector3i(0, 0, 1)
		if dv.x != 0 or dv.z != 0:
			u = Vector3i(-dv.z, 0, dv.x)
			v = Vector3i(-dv.x * dv.y, dv.x * dv.x + dv.z * dv.z, -dv.y * dv.z)
		var uu: int = _p(u, u)
		var vv: int = _p(v, v)
		var h2: int = demi * demi
		for q in traverser(p0, p1):
			corps[q] = true
		for x in range(bas.x, haut.x + 1):
			for y in range(bas.y, haut.y + 1):
				for z in range(bas.z, haut.z + 1):
					var q := Vector3i(x, y, z)
					var d: Vector3i = q - p0
					var t: int = _p(d, dv)
					if t < 0 and (e0 == 0 or t * t > e0 * e0 * ddv):
						continue
					if t > ddv and (e1 == 0 or (t - ddv) * (t - ddv) > e1 * e1 * ddv):
						continue
					var ca: int = _p(d, u)
					var cb: int = _p(d, v)
					var a2: int = ca * ca
					var b2: int = cb * cb
					match profil:
						"rond":
							if a2 * vv + b2 * uu <= h2 * uu * vv:
								corps[q] = true
						"carre":
							if a2 <= h2 * uu and b2 <= h2 * vv:
								corps[q] = true
						"arche":
							if cb >= 0:
								if a2 * vv + b2 * uu <= h2 * uu * vv:
									corps[q] = true
							elif a2 <= h2 * uu and b2 <= h2 * vv:
								corps[q] = true
						"tablier":
							if a2 <= h2 * uu and 4 * b2 <= vv:
								corps[q] = true
							elif avec_rebord and cb > 0 and 4 * b2 <= 9 * vv and a2 <= h2 * uu:
								if a2 > (demi - 1) * (demi - 1) * uu:
									rebords[q] = true
								else:
									passage[q] = true
	for q in rebords:
		if not passage.has(q):
			corps[q] = true
	return corps


## LA TRAVERSÉE DE L'AXE — les cases que la droite de centre à centre traverse, un axe à la fois.
##
## ⚠ **SANS ELLE, UN CONDUIT FIN EN BIAIS ÉTAIT TROUÉ** : un profil de taille 1 ne garde que les cases dont
## le centre est EXACTEMENT sur l'axe, donc presque aucune sur une droite oblique. La traversée est ajoutée
## à chaque segment, quel que soit le profil : le conduit est toujours relié PAR LES FACES.
## En entiers : après k pas sur l'axe i, la droite franchit la limite suivante à t = (2k + 1) / (2|Dᵢ|) ;
## on compare deux axes par produits croisés. ⚠ Égalité : le plus petit axe (x, puis y, puis z) d'abord.
static func traverser(p0: Vector3i, p1: Vector3i) -> Array[Vector3i]:
	var d: Vector3i = p1 - p0
	var ad := [absi(d.x), absi(d.y), absi(d.z)]
	var s := [_signe(d.x), _signe(d.y), _signe(d.z)]
	var k := [0, 0, 0]
	var c: Vector3i = p0
	var sortie: Array[Vector3i] = [c]
	for _pas in int(ad[0]) + int(ad[1]) + int(ad[2]):
		var meilleur := -1
		for i in 3:
			if k[i] >= ad[i]:
				continue
			if meilleur < 0 or (2 * k[i] + 1) * ad[meilleur] < (2 * k[meilleur] + 1) * ad[i]:
				meilleur = i
		c[meilleur] += s[meilleur]
		k[meilleur] += 1
		sortie.append(c)
	return sortie


## LE BALCON : une dalle d'une case d'épaisseur au niveau de la case cliquée, qui sort de la paroi de
## `profondeur` cases sur `2·demi + 1` de large ; le garde-corps, la rangée du dessus sur le bord du
## large et les deux côtés (pas contre la paroi, d'où l'on entre). Sur une paroi diagonale (|n|² = 2), les
## mêmes inégalités au carré dessinent la dalle en biais.
static func _balcon(a: Vector3i, n: Vector3i, profondeur: int, demi: int, garde: bool) -> Dictionary:
	var corps := {}
	var nn: int = _p(n, n)
	var m := Vector3i(-n.z, 0, n.x)
	var avec_rebord: bool = garde and demi >= 1 and profondeur >= 2
	var portee: int = profondeur + demi + 1
	for x in range(-portee, portee + 1):
		for z in range(-portee, portee + 1):
			var d := Vector3i(x, 0, z)
			var av: int = _p(d, n)
			var lat: int = _p(d, m)
			if av <= 0 or av * av > profondeur * profondeur * nn or lat * lat > demi * demi * nn:
				continue
			corps[a + d] = true
			if avec_rebord:
				var dedans: bool = av * av <= (profondeur - 1) * (profondeur - 1) * nn \
					and lat * lat <= (demi - 1) * (demi - 1) * nn
				if not dedans:
					corps[a + d + Vector3i.UP] = true
	return corps


## LA RÉPARATION DES CONTACTS DIAGONAUX que la forme a créés. Rend le nombre de cases ajoutées au geste.
##
## Par TOURS, comme `MB.completer_les_carres` : on relève tous les carrés 2×2 en damier qui contiennent une
## case changée au tour d'avant, puis on applique tout d'un coup — l'ordre de parcours ne peut donc rien
## changer, ce qui compte pour trois implémentations. Creuser vide la paire PLEINE, remplir comble la paire
## VIDE : la matière va dans un seul sens, donc ça termine.
static func _reparer(occupees: Dictionary, poser: Dictionary, effacer: Dictionary, creuse: bool) -> int:
	var plein := func(c: Vector3i) -> bool:
		return poser.has(c) or (occupees.has(c) and not effacer.has(c))
	var front: Array = (effacer if creuse else poser).keys()
	var ajoutees := 0
	while not front.is_empty():
		var a_changer := {}
		for c in front:
			for plan in PLANS:
				var e1: Vector3i = plan[0]
				var e2: Vector3i = plan[1]
				for o in [c, c - e1, c - e2, c - e1 - e2]:
					var p00: Vector3i = o
					var p10: Vector3i = o + e1
					var p01: Vector3i = o + e2
					var p11: Vector3i = o + e1 + e2
					var f00: bool = plein.call(p00)
					var f10: bool = plein.call(p10)
					var f01: bool = plein.call(p01)
					var f11: bool = plein.call(p11)
					if f00 == f11 and f10 == f01 and f00 != f10:
						var paire: Array = [p00, p11] if f00 == creuse else [p10, p01]
						for q in paire:
							a_changer[q] = true
		front = []
		for q in a_changer:
			if creuse:
				effacer[q] = true
			else:
				poser[q] = true
			front.append(q)
			ajoutees += 1
		if ajoutees > Outils.VOLUME_MAXI:
			break
	return ajoutees
