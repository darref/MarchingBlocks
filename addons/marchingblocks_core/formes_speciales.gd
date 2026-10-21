@tool
extends RefCounted
## LES FORMES SPÉCIALES — tunnel, puits, pont, balcon et escalier, posés d'un ou deux clics.
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

const QUOI := ["tunnel", "puits", "pont", "balcon", "escalier"]
const PROFILS := ["rond", "carre", "arche"]

## La marche droite (un clic) et la profondeur d'un balcon : au plus tant de cases.
const LONGUEUR_MAXI := 64
## Deux ancres plus éloignées que ça (en cases, entre leurs centres) ne se relient pas.
const ECART_MAXI := 128
## L'escalier d'un clic : chaque marche fait de 1 à tant de rangées de profondeur.
const PAS_MAXI := 4

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
##   escalier relié — la face doit être un SOL (le dessus d'une case), et la normale EST cette face ;
##   les autres — la face doit être une paroi (horizontale), et la normale est ESTIMÉE.
static func normale_de(quoi: String, occupees: Dictionary, c: Vector3i, face: Vector3i, relier := false) -> Vector3i:
	if quoi == "puits":
		return face if face.x == 0 and face.z == 0 and face.y != 0 else Vector3i.ZERO
	if quoi == "escalier" and relier:
		return face if face == Vector3i(0, 1, 0) else Vector3i.ZERO
	if face.y != 0 or (face.x == 0 and face.z == 0):
		return Vector3i.ZERO
	return normale_estimee(occupees, c, face)


## Le refus d'une ancre que `normale_de` rejette.
static func erreur_d_ancre(quoi: String, relier: bool) -> String:
	if quoi == "puits":
		return "pas_un_sol"
	if quoi == "escalier" and relier:
		return "pas_un_dessus"
	return "pas_de_paroi"


static func _creuse(quoi: String) -> bool:
	return quoi == "tunnel" or quoi == "puits"


## LA FORME. `r` porte :
##   quoi        — "tunnel", "puits", "pont", "balcon" ou "escalier" ;
##   a, face_a   — la case cliquée et la face par laquelle on l'a visée ;
##   relier      — vrai : relier à la seconde ancre (b, face_b) ; faux : un clic, tout droit ;
##   profil      — "rond", "carre" ou "arche" (tunnel et puits ; le pont a son TABLIER) ;
##   taille      — 1 à 7, comme le pinceau : le demi-côté du profil est `taille - 1` ;
##   longueur    — un clic : la profondeur maximale (tunnel, puits), la portée (pont), la profondeur du
##                 balcon ;
##   garde_corps — pont, balcon et escalier : un rebord d'une case sur leurs côtés (sans objet si taille = 1) ;
##   pas         — l'escalier d'un clic : la profondeur d'une marche, de 1 à `PAS_MAXI` rangées.
## Rend {"poser", "effacer", "erreur", "ouvert", "reparees"} ; `erreur` vide si tout va bien, sinon l'un
## de : pas_de_paroi, pas_un_sol, pas_un_dessus, meme_case, trop_long, trop_raide, rien_en_face, trop_grand,
## forme_inconnue.
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
	var relier: bool = bool(r.get("relier", false)) and quoi != "balcon"
	var a: Vector3i = r["a"]
	var na := normale_de(quoi, occupees, a, r["face_a"], relier)
	if na == Vector3i.ZERO:
		sortie["erreur"] = erreur_d_ancre(quoi, relier)
		return sortie
	var creuse := _creuse(quoi)

	var choisies := {}
	if quoi == "balcon":
		choisies = _balcon(a, na, longueur, demi, garde)
	elif quoi == "escalier":
		if relier:
			var b: Vector3i = r["b"]
			if normale_de(quoi, occupees, b, r["face_b"], true) == Vector3i.ZERO:
				sortie["erreur"] = "pas_un_dessus"
				return sortie
			if b == a:
				sortie["erreur"] = "meme_case"
				return sortie
			if _p(b - a, b - a) > ECART_MAXI * ECART_MAXI:
				sortie["erreur"] = "trop_long"
				return sortie
			choisies = _escalier_relie(occupees, a, b, demi, garde)
		else:
			var pas: int = clampi(int(r.get("pas", 2)), 1, PAS_MAXI)
			choisies = _escalier(occupees, a, na, longueur, pas, demi, garde)
	else:
		var points: Array[Vector3i] = []
		if relier:
			var b: Vector3i = r["b"]
			var nb := normale_de(quoi, occupees, b, r["face_b"])
			if nb == Vector3i.ZERO:
				sortie["erreur"] = erreur_d_ancre(quoi, false)
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
		# ⚠ UN SEGMENT DROIT SUR UN AXE (le cas courant : une paroi droite) SE BALAIE PAR TRANCHES (3 octobre 2026) :
		# t ne dépend que de la coordonnée le long de l'axe, a et b que des deux autres — le profil est testé UNE fois
		# par case de la tranche, puis posé sur chaque position retenue le long de l'axe. Mêmes tests, même sortie
		# (gardée par les cas d'épreuve des greffons, recalculés et comparés) ; un aperçu de tunnel de taille 7 sur
		# 32 cases passait ~115 ms à balayer sa boîte case par case.
		var axe := -1
		if (dv.x != 0 and dv.y == 0 and dv.z == 0):
			axe = 0
		elif (dv.x == 0 and dv.y != 0 and dv.z == 0):
			axe = 1
		elif (dv.x == 0 and dv.y == 0 and dv.z != 0):
			axe = 2
		if axe >= 0:
			var le_long: Array[int] = []
			for k in range(bas[axe], haut[axe] + 1):
				var q := p0
				q[axe] = k
				var t: int = _p(q - p0, dv)
				if t < 0 and (e0 == 0 or t * t > e0 * e0 * ddv):
					continue
				if t > ddv and (e1 == 0 or (t - ddv) * (t - ddv) > e1 * e1 * ddv):
					continue
				le_long.append(k)
			var i1: int = (axe + 1) % 3
			var i2: int = (axe + 2) % 3
			for c1 in range(bas[i1], haut[i1] + 1):
				for c2 in range(bas[i2], haut[i2] + 1):
					var d := Vector3i.ZERO
					d[i1] = c1 - p0[i1]
					d[i2] = c2 - p0[i2]
					var dest := _classer_dans_le_profil(_p(d, u), _p(d, v), uu, vv, h2, demi, profil, avec_rebord)
					if dest == 0:
						continue
					var cible: Dictionary = corps if dest == 1 else (rebords if dest == 2 else passage)
					for k in le_long:
						var q := Vector3i.ZERO
						q[axe] = k
						q[i1] = c1
						q[i2] = c2
						cible[q] = true
			continue
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


## Où tombe une case de coordonnées en travers (ca, cb) dans le profil : 0 dehors, 1 le corps, 2 un rebord du
## garde-corps, 3 le passage au-dessus du tablier. LES MÊMES TESTS que la boucle case par case de `_balayer`.
static func _classer_dans_le_profil(ca: int, cb: int, uu: int, vv: int, h2: int, demi: int, profil: String,
		avec_rebord: bool) -> int:
	var a2: int = ca * ca
	var b2: int = cb * cb
	match profil:
		"rond":
			return 1 if a2 * vv + b2 * uu <= h2 * uu * vv else 0
		"carre":
			return 1 if a2 <= h2 * uu and b2 <= h2 * vv else 0
		"arche":
			if cb >= 0:
				return 1 if a2 * vv + b2 * uu <= h2 * uu * vv else 0
			return 1 if a2 <= h2 * uu and b2 <= h2 * vv else 0
		"tablier":
			if a2 <= h2 * uu and 4 * b2 <= vv:
				return 1
			if avec_rebord and cb > 0 and 4 * b2 <= 9 * vv and a2 <= h2 * uu:
				return 2 if a2 > (demi - 1) * (demi - 1) * uu else 3
	return 0


## RÉPARER LES CONTACTS DIAGONAUX D'UN MONDE — DEMANDÉ PAR JORDAN (3 octobre 2026 : « un bouton fix diagonals errors
## dans World »). Un BOUTON, donc un geste voulu : ce n'est pas la complétion silencieuse retirée du pinceau (§2, « le
## rouge, pas la complétion »), qui reste retirée.
##   pleines      — les cases du monde (l'union des couches visibles) ;
##   creuse       — faux : on COMBLE chaque damier (ses deux cases vides deviennent pleines) ; vrai : on le CREUSE (ses
##                  deux cases pleines se vident), seulement si elles sont toutes deux dans `modifiables` (la couche
##                  active), sinon on le comble ;
##   figees       — des cases qu'on ne peut pas remplir (celles d'une couche cachée : les poser les lui volerait).
## Par tours, comme `_reparer` : chaque tour lit l'état du tour d'avant. ⚠ UNE CASE NE CHANGE QU'UNE FOIS (on ne vide
## que des cases d'origine, on ne remplit que des cases vides jamais vidées) : ça termine toujours. Un damier qu'aucune
## règle ne peut défaire reste — `restantes` les compte (`MB.contacts_par_arete` sur l'état final).
##   depart       — les cases d'où partir (l'atelier Preshape, 21 octobre 2026 : la COQUILLE de la forme — un damier a
##                  toujours ses cases pleines au bord du vide, l'intérieur n'en porte pas) ; vide : toutes les cases.
## Rend {"poser", "effacer", "restantes"}.
static func reparer_les_diagonales(pleines: Dictionary, creuse: bool, modifiables: Dictionary = {},
		figees: Dictionary = {}, depart: Array = []) -> Dictionary:
	var poser := {}
	var effacer := {}
	var front: Array = depart if not depart.is_empty() else pleines.keys()
	while not front.is_empty():
		var a_poser := {}
		var a_effacer := {}
		for c in front:
			for plan in PLANS:
				var e1: Vector3i = plan[0]
				var e2: Vector3i = plan[1]
				for o in [c, c - e1, c - e2, c - e1 - e2]:
					var p00: Vector3i = o
					var p10: Vector3i = o + e1
					var p01: Vector3i = o + e2
					var p11: Vector3i = o + e1 + e2
					var f00: bool = poser.has(p00) or (pleines.has(p00) and not effacer.has(p00))
					var f10: bool = poser.has(p10) or (pleines.has(p10) and not effacer.has(p10))
					var f01: bool = poser.has(p01) or (pleines.has(p01) and not effacer.has(p01))
					var f11: bool = poser.has(p11) or (pleines.has(p11) and not effacer.has(p11))
					if not (f00 == f11 and f10 == f01 and f00 != f10):
						continue
					var vides: Array = [p10, p01] if f00 else [p00, p11]
					var pleins: Array = [p00, p11] if f00 else [p10, p01]
					if creuse and modifiables.has(pleins[0]) and modifiables.has(pleins[1]) \
							and not poser.has(pleins[0]) and not poser.has(pleins[1]):
						a_effacer[pleins[0]] = true
						a_effacer[pleins[1]] = true
					elif not (effacer.has(vides[0]) or effacer.has(vides[1]) or figees.has(vides[0])
							or figees.has(vides[1])):
						a_poser[vides[0]] = true
						a_poser[vides[1]] = true
		front = []
		for q in a_effacer:
			if not effacer.has(q):
				effacer[q] = true
				front.append(q)
		for q in a_poser:
			if not poser.has(q) and not effacer.has(q):
				poser[q] = true
				front.append(q)
		if poser.size() + effacer.size() > Outils.VOLUME_MAXI * 8:
			break
	var fin := {}
	for c in pleines:
		if not effacer.has(c):
			fin[c] = true
	for c in poser:
		fin[c] = true
	var MB := load("res://addons/marchingblocks_core/marching_blocks.gd")
	return {"poser": poser, "effacer": effacer, "restantes": MB.contacts_par_arete(fin)}


## Les six voisines de `c` par une face sont-elles toutes dans `changees` ?
static func _entouree(changees: Dictionary, c: Vector3i) -> bool:
	return (changees.has(c + Vector3i(1, 0, 0)) and changees.has(c - Vector3i(1, 0, 0))
		and changees.has(c + Vector3i(0, 1, 0)) and changees.has(c - Vector3i(0, 1, 0))
		and changees.has(c + Vector3i(0, 0, 1)) and changees.has(c - Vector3i(0, 0, 1)))


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


## L'ESCALIER D'UN CLIC — contre une paroi, il ARRIVE au niveau de la case cliquée.
##
## On clique la paroi là où l'escalier doit déboucher : le palier est la rangée devant la case cliquée, son
## dessus au niveau de celle-ci, et chaque rangée plus loin de la paroi descend. La rangée j (j ≥ 1 : le plus
## petit j tel que (d·n)² ≤ j²·|n|², la distance à la paroi arrondie au-dessus — la règle du balcon, parois
## diagonales comprises) a son dessus à a.y − (j − 1) / pas : une marche fait `pas` rangées.
## L'escalier finit à la première rangée dont TOUTES les cases du dessus sont déjà pleines — il a rejoint le
## sol —, sinon au bout de `longueur` rangées. Chaque colonne est pleine jusqu'au sol (`_colonne`).
static func _escalier(occupees: Dictionary, a: Vector3i, n: Vector3i, longueur: int, pas: int, demi: int,
		garde: bool) -> Dictionary:
	var nn: int = _p(n, n)
	var m := Vector3i(-n.z, 0, n.x)
	var portee: int = longueur + demi + 1
	var rangees := {}
	for x in range(-portee, portee + 1):
		for z in range(-portee, portee + 1):
			var d := Vector3i(x, 0, z)
			var av: int = _p(d, n)
			var lat: int = _p(d, m)
			if av <= 0 or lat * lat > demi * demi * nn:
				continue
			var j := 1
			while av * av > j * j * nn:
				j += 1
			if j > longueur:
				continue
			if not rangees.has(j):
				rangees[j] = []
			rangees[j].append(d)
	var corps := {}
	for j in range(1, longueur + 1):
		if not rangees.has(j):
			continue
		var dessus: int = a.y - (j - 1) / pas
		var au_sol := true
		for d in rangees[j]:
			if not occupees.has(Vector3i(a.x + d.x, dessus, a.z + d.z)):
				au_sol = false
				break
		if au_sol:
			break
		for d in rangees[j]:
			var lat: int = _p(d, m)
			var bord: bool = garde and demi >= 1 and lat * lat > (demi - 1) * (demi - 1) * nn
			_colonne(occupees, corps, Vector3i(a.x + d.x, dessus, a.z + d.z), bord)
	return corps


## L'ESCALIER RELIÉ — de SOL à SOL : deux cases cliquées par leur dessus, l'escalier monte de la plus basse
## (L) à la plus haute (H), en ligne droite à plat.
##
## D = (H − L) à plat, R = H.y − L.y. Une colonne c est dans la bande quand, d = c − L à plat, t = d·D est dans
## [0, D·D] et (d·u)² ≤ demi²·D·D (u = (−D.z, 0, D.x)) ; plus la traversée à plat de L à H, pour qu'un
## escalier fin reste relié par les faces. Son dessus : L.y + t·R / D·D (division entière, t ramené dans
## [0, D·D]) — les marches se partagent la longueur, et deux colonnes voisines ne diffèrent jamais de plus
## d'une case. ⚠ **PLUS RAIDE QU'UNE CASE PAR CASE, C'EST REFUSÉ** (R² > D·D : trop_raide) : il faudrait
## sauter. Le `pas` ne sert pas ici : c'est l'écart des deux sols qui le fixe.
static func _escalier_relie(occupees: Dictionary, a: Vector3i, b: Vector3i, demi: int, garde: bool) -> Dictionary:
	var bas: Vector3i = a if a.y <= b.y else b
	var haut: Vector3i = b if a.y <= b.y else a
	var bas_plat := Vector3i(bas.x, 0, bas.z)
	var dv := Vector3i(haut.x - bas.x, 0, haut.z - bas.z)
	var ddv: int = _p(dv, dv)
	var montee: int = haut.y - bas.y
	if montee * montee > ddv:
		return {"erreur": "trop_raide"}
	var u := Vector3i(-dv.z, 0, dv.x)
	var colonnes := {}
	for x in range(mini(bas.x, haut.x) - demi - 1, maxi(bas.x, haut.x) + demi + 2):
		for z in range(mini(bas.z, haut.z) - demi - 1, maxi(bas.z, haut.z) + demi + 2):
			var d := Vector3i(x - bas.x, 0, z - bas.z)
			var t: int = _p(d, dv)
			var lat: int = _p(d, u)
			if t >= 0 and t <= ddv and lat * lat <= demi * demi * ddv:
				colonnes[Vector3i(x, 0, z)] = true
	for q in traverser(bas_plat, Vector3i(haut.x, 0, haut.z)):
		colonnes[q] = true
	var corps := {}
	for c in colonnes:
		var d: Vector3i = c - bas_plat
		var t: int = clampi(_p(d, dv), 0, ddv)
		var lat: int = _p(d, u)
		var bord: bool = garde and demi >= 1 and lat * lat > (demi - 1) * (demi - 1) * ddv
		_colonne(occupees, corps, Vector3i(c.x, bas.y + t * montee / ddv, c.z), bord)
	return corps


## Une colonne d'escalier : son dessus et tout ce qui est vide dessous, jusqu'au sol. ⚠ Sans sol à moins de
## `LONGUEUR_MAXI` cases (un escalier au-dessus du vide), une volée de DEUX cases d'épaisseur : une seule
## laisserait deux marches voisines se toucher par une arête. Un dessus déjà plein : rien. Le bord porte le
## garde-corps, la case au-dessus de son dessus.
static func _colonne(occupees: Dictionary, corps: Dictionary, dessus: Vector3i, bord: bool) -> void:
	if occupees.has(dessus):
		return
	corps[dessus] = true
	var dessous: Array[Vector3i] = []
	var sol := false
	for k in range(1, LONGUEUR_MAXI + 1):
		var q: Vector3i = dessus - Vector3i(0, k, 0)
		if occupees.has(q):
			sol = true
			break
		dessous.append(q)
	if sol:
		for q in dessous:
			corps[q] = true
	else:
		corps[dessus - Vector3i(0, 1, 0)] = true
	if bord:
		corps[dessus + Vector3i.UP] = true


## LA RÉPARATION DES CONTACTS DIAGONAUX que la forme a créés. Rend le nombre de cases ajoutées au geste.
##
## LA SALLE (Jordan, 2 octobre 2026 : « une special shape Room, qui permet de tracer une sélection en surface à plat
## sur la grille, et d'extruder vers le haut ou le bas de tant d'étages, tout en conservant le creux dans le volume »).
## `a`, `b` : deux coins du rectangle tracé sur le plan de l'étage (même `y`). Vers le haut, ce rectangle est le SOL
## et la salle monte ; vers le bas, il est le PLAFOND et elle descend. `etages` = la hauteur LIBRE à l'intérieur.
## Murs, sol et plafond font une case ; tout ce qui est dedans est creux — la roche qui s'y trouvait est creusée.
## ⚠ HORS DE `QUOI` ET DE `forme()` : elle ne s'ancre pas sur une face, elle se trace ; et elle n'est pas encore dans
## les cas d'épreuve des greffons (charte §0, « les greffons attendent la fin du logiciel »).
## Rend {"poser", "effacer", "erreur" (trop_petit | trop_grand), "reparees", "boite": [bas, haut]}.
const ETAGES_MAXI := 32


## LA SALLE D'UNE SÉLECTION (Jordan, 3 octobre 2026 : « une fonction pour dessiner une sélection quelconque à plat, et
## l'extruder en room verticalement »). L'EMPREINTE est la sélection vue d'en haut (ses (x, z)) ; sa base est la plus
## basse rangée de la sélection vers le haut, la plus haute vers le bas. Comme `salle` : vers le haut l'empreinte est le
## SOL, vers le bas le PLAFOND ; `etages` = la hauteur libre. Le sol et le plafond couvrent toute l'empreinte ; les MURS
## sont ses cases de BORD (un de leurs quatre voisins horizontaux hors de l'empreinte) ; le reste est creux — la roche
## qui s'y trouvait est creusée. Une empreinte sans case intérieure (trop mince) est « trop_petit ». Mêmes réparations
## et même retour que `salle`.
static func salle_depuis(occupees: Dictionary, selection: Dictionary, etages: int, vers_le_haut: bool) -> Dictionary:
	var r := {"poser": {}, "effacer": {}, "erreur": "", "reparees": 0, "boite": []}
	if selection.is_empty():
		r["erreur"] = "vide"
		return r
	var empreinte := {}
	var base: int = 0
	var premier := true
	for c: Vector3i in selection:
		empreinte[Vector2i(c.x, c.z)] = true
		if premier or (c.y < base if vers_le_haut else c.y > base):
			base = c.y
			premier = false
	var dedans := {}
	for p: Vector2i in empreinte:
		if empreinte.has(p + Vector2i(1, 0)) and empreinte.has(p + Vector2i(-1, 0)) \
				and empreinte.has(p + Vector2i(0, 1)) and empreinte.has(p + Vector2i(0, -1)):
			dedans[p] = true
	if dedans.is_empty():
		r["erreur"] = "trop_petit"
		return r
	var e: int = clampi(etages, 1, ETAGES_MAXI)
	var y0: int = base if vers_le_haut else base - e - 1
	var y1: int = y0 + e + 1
	if empreinte.size() * (e + 2) > Outils.VOLUME_MAXI:
		r["erreur"] = "trop_grand"
		return r
	var poser: Dictionary = r["poser"]
	var effacer: Dictionary = r["effacer"]
	var lo := Vector3i(2147483647, y0, 2147483647)
	var hi := Vector3i(-2147483647, y1, -2147483647)
	for p: Vector2i in empreinte:
		lo = Vector3i(mini(lo.x, p.x), y0, mini(lo.z, p.y))
		hi = Vector3i(maxi(hi.x, p.x), y1, maxi(hi.z, p.y))
		for y in range(y0, y1 + 1):
			var c := Vector3i(p.x, y, p.y)
			if y == y0 or y == y1 or not dedans.has(p):
				if not occupees.has(c):
					poser[c] = true
			elif occupees.has(c):
				effacer[c] = true
	r["reparees"] = _reparer(occupees, poser, effacer, false)
	r["boite"] = [lo, hi]
	return r


static func salle(occupees: Dictionary, a: Vector3i, b: Vector3i, etages: int, vers_le_haut: bool) -> Dictionary:
	var r := {"poser": {}, "effacer": {}, "erreur": "", "reparees": 0, "boite": []}
	var x0: int = mini(a.x, b.x)
	var x1: int = maxi(a.x, b.x)
	var z0: int = mini(a.z, b.z)
	var z1: int = maxi(a.z, b.z)
	# ⚠ AU MOINS 3 × 3 : deux murs face à face, et une case de dedans entre eux.
	if x1 - x0 < 2 or z1 - z0 < 2:
		r["erreur"] = "trop_petit"
		return r
	var e: int = clampi(etages, 1, ETAGES_MAXI)
	var y0: int = a.y if vers_le_haut else a.y - e - 1
	var y1: int = y0 + e + 1
	if (x1 - x0 + 1) * (z1 - z0 + 1) * (e + 2) > Outils.VOLUME_MAXI:
		r["erreur"] = "trop_grand"
		return r
	var poser: Dictionary = r["poser"]
	var effacer: Dictionary = r["effacer"]
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			for y in range(y0, y1 + 1):
				var c := Vector3i(x, y, z)
				if x == x0 or x == x1 or z == z0 or z == z1 or y == y0 or y == y1:
					if not occupees.has(c):
						poser[c] = true
				elif occupees.has(c):
					effacer[c] = true
	# Une coque posée contre le monde peut le toucher par une arête seulement : la forme répare ce qu'elle crée.
	r["reparees"] = _reparer(occupees, poser, effacer, false)
	r["boite"] = [Vector3i(x0, y0, z0), Vector3i(x1, y1, z1)]
	return r


## Par TOURS, comme `MB.completer_les_carres` : on relève tous les carrés 2×2 en damier qui contiennent une
## case changée au tour d'avant, puis on applique tout d'un coup — l'ordre de parcours ne peut donc rien
## changer, ce qui compte pour trois implémentations. Creuser vide la paire PLEINE, remplir comble la paire
## VIDE : la matière va dans un seul sens, donc ça termine.
static func _reparer(occupees: Dictionary, poser: Dictionary, effacer: Dictionary, creuse: bool) -> int:
	var front: Array = (effacer if creuse else poser).keys()
	var ajoutees := 0
	while not front.is_empty():
		var a_changer := {}
		for c in front:
			# ⚠ UNE CASE DONT LES SIX VOISINES PAR UNE FACE ONT CHANGÉ COMME ELLE ne peut toucher aucun damier : chaque
			# carré qui la contient contient aussi deux de ces voisines, de son état — or un damier n'a jamais deux coins
			# voisins égaux (3 octobre 2026 : l'intérieur d'un tunnel creusé, ~60 % de ses cases, était relu 48 fois
			# chacune). On ne la regarde pas. ⚠ Vérifier les dix-huit voisines (arêtes comprises) rendait la même chose :
			# mutation équivalente, mesurée.
			if creuse and _entouree(effacer, c):
				continue
			if not creuse and _entouree(poser, c):
				continue
			for plan in PLANS:
				var e1: Vector3i = plan[0]
				var e2: Vector3i = plan[1]
				for o in [c, c - e1, c - e2, c - e1 - e2]:
					var p00: Vector3i = o
					var p10: Vector3i = o + e1
					var p01: Vector3i = o + e2
					var p11: Vector3i = o + e1 + e2
					# ⚠ `plein` ÉCRIT EN LIGNE (3 octobre 2026) : appelée 48 fois par case, la fonction anonyme coûtait
					# l'essentiel d'un aperçu de tunnel (~100 ms pour 3 700 cases). Même expression.
					var f00: bool = poser.has(p00) or (occupees.has(p00) and not effacer.has(p00))
					var f10: bool = poser.has(p10) or (occupees.has(p10) and not effacer.has(p10))
					var f01: bool = poser.has(p01) or (occupees.has(p01) and not effacer.has(p01))
					var f11: bool = poser.has(p11) or (occupees.has(p11) and not effacer.has(p11))
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
