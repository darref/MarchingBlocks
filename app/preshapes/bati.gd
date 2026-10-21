extends RefCounted
## LE CHANTIER D'UNE PRÉFORME (l'atelier Preshape, la 1.1.0 — Jordan, 21 octobre 2026).
##
## Une forme (`forme.gd`) n'écrit qu'ici : des COLONNES (le relief : du bas au haut, un rôle pour le dessus, un pour le
## corps), des CASES (le bâti, posé par-dessus) et des VIDES (ce qu'elle creuse, dans elle-même ET dans le monde).
## `resoudre` en fait des cases par rôle. Tout est en cases locales : (0, 0, 0) est la case posée sur le sol visé, au
## centre de l'emprise ; y monte.
##
## ⚠ « UNE MATIÈRE NE CHANGE QUE LÀ OÙ LA HAUTEUR CHANGE » (charte) : une forme de relief choisit le rôle du dessus
## d'une colonne par sa HAUTEUR seule (`par_hauteur`), jamais par x ou z — deux colonnes de même hauteur ont la même
## matière, et deux matières ne se touchent pas sur un même plat.

## Vector2i(x, z) → [bas, haut, rôle du dessus, rôle du corps] ; bas et haut compris.
var colonnes := {}
## Vector3i → rôle ; une case l'emporte sur la colonne qui la contient.
var cases := {}
## Vector3i → true : creusé (la forme y est vide, et le monde aussi).
var vides := {}
## Les TRANCHES d'un relief (`par_hauteur`), s'il en a : la réparation des contacts (`catalogue.gd`) nomme ses cases
## ajoutées par leur hauteur, comme la forme.
var bandes: Array = []


## Une colonne. Deux colonnes au même endroit se FONDENT : le bas le plus bas, le haut le plus haut, le dessus de la
## plus haute (deux collines qui se recouvrent font une seule colline).
func colonne(x: int, z: int, bas: int, haut: int, dessus: String, corps := "") -> void:
	if haut < bas:
		return
	var k := Vector2i(x, z)
	var c := corps if corps != "" else dessus
	if colonnes.has(k):
		var a: Array = colonnes[k]
		if haut >= int(a[1]):
			colonnes[k] = [mini(bas, int(a[0])), haut, dessus, c]
		else:
			a[0] = mini(bas, int(a[0]))
		return
	colonnes[k] = [bas, haut, dessus, c]


## Le haut de la colonne (x, z), −1000 sans colonne.
func haut(x: int, z: int) -> int:
	var a: Variant = colonnes.get(Vector2i(x, z))
	return int(a[1]) if a != null else -1000


func case(x: int, y: int, z: int, role: String) -> void:
	var c := Vector3i(x, y, z)
	cases[c] = role
	vides.erase(c)


## Un pavé plein, coins compris.
func boite(a: Vector3i, b: Vector3i, role: String) -> void:
	for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
		for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			for z in range(mini(a.z, b.z), maxi(a.z, b.z) + 1):
				case(x, y, z, role)


func vider(x: int, y: int, z: int) -> void:
	var c := Vector3i(x, y, z)
	vides[c] = true
	cases.erase(c)


func vider_boite(a: Vector3i, b: Vector3i) -> void:
	for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
		for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			for z in range(mini(a.z, b.z), maxi(a.z, b.z) + 1):
				vider(x, y, z)


## Un disque plein (ou un anneau, `r_creux` ≥ 0) de rayon `r`, de `bas` à `haut`, centré en (cx, cz).
func cylindre(cx: float, cz: float, r: float, bas: int, haut_: int, role: String, r_creux := -1.0) -> void:
	for x in range(floori(cx - r) - 1, ceili(cx + r) + 2):
		for z in range(floori(cz - r) - 1, ceili(cz + r) + 2):
			var d := Vector2(x - cx, z - cz).length()
			if d <= r + 0.01 and d > r_creux:
				for y in range(bas, haut_ + 1):
					case(x, y, z, role)


func vider_cylindre(cx: float, cz: float, r: float, bas: int, haut_: int) -> void:
	for x in range(floori(cx - r) - 1, ceili(cx + r) + 2):
		for z in range(floori(cz - r) - 1, ceili(cz + r) + 2):
			if Vector2(x - cx, z - cz).length() <= r + 0.01:
				for y in range(bas, haut_ + 1):
					vider(x, y, z)


## Un ellipsoïde plein (`plein`) ou creusé, de demi-axes `r`.
func ellipsoide(centre: Vector3, r: Vector3, role: String, plein := true) -> void:
	for x in range(floori(centre.x - r.x), ceili(centre.x + r.x) + 1):
		for y in range(floori(centre.y - r.y), ceili(centre.y + r.y) + 1):
			for z in range(floori(centre.z - r.z), ceili(centre.z + r.z) + 1):
				var d := Vector3((x - centre.x) / maxf(r.x, 0.5), (y - centre.y) / maxf(r.y, 0.5),
					(z - centre.z) / maxf(r.z, 0.5))
				if d.length_squared() <= 1.0:
					if plein:
						case(x, y, z, role)
					else:
						vider(x, y, z)


## Le rôle du DESSUS d'une colonne par sa hauteur seule : `bandes` = [[hauteur à partir de laquelle, rôle], …] triées.
static func par_hauteur(h: int, bandes: Array) -> String:
	var r := str(bandes[0][1])
	for b in bandes:
		if h >= int(b[0]):
			r = str(b[1])
	return r


## UN CHAMP DE HAUTEURS LISSÉ ({Vector2i: hauteur}) : la moyenne 3 × 3, `passes` fois (une case hors du champ compte 0).
## ⚠ VU À L'IMAGE (21 octobre 2026) : l'érosion tirée case par case, arrondie telle quelle, hérissait la montagne de
## piliers d'une case, chacun coiffé d'herbe.
static func lisser(champ: Dictionary, passes := 1) -> Dictionary:
	var c := champ
	for p in passes:
		var n := {}
		for k in c:
			var s := 0.0
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					s += float(c.get(k + Vector2i(dx, dz), 0.0))
			n[k] = s / 9.0
		c = n
	return c


## UN RELIEF DEPUIS SON CHAMP DE HAUTEURS : chaque colonne arrondie, son dessus nommé par sa hauteur (`bandes`), son corps
## en `paroi` seulement là où elle domine une voisine d'au moins `falaise` cases — ailleurs, du même rôle que son dessus.
## ⚠ VU À L'IMAGE (21 octobre 2026) : un corps toujours en roche rayait chaque marche d'une case d'un liseré gris.
func relief(champ: Dictionary, bandes_: Array, paroi := "roche", falaise := 2) -> void:
	var hauts := {}
	for k in champ:
		var hi := int(round(float(champ[k])))
		if hi >= 1:
			hauts[k] = hi
	for k in hauts:
		var hi: int = hauts[k]
		var plus_bas := hi
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			plus_bas = mini(plus_bas, int(hauts.get(k + d, 0)))
		var dessus := par_hauteur(hi, bandes_)
		colonne(k.x, k.y, 0, hi - 1, dessus, paroi if hi - plus_bas >= falaise else dessus)


## Les cases du chantier, par rôle : {"cases": {rôle: {Vector3i: true}}, "creuser": {Vector3i: true}}.
func resoudre() -> Dictionary:
	var par_role := {}
	for k in colonnes:
		var a: Array = colonnes[k]
		var haut_: int = a[1]
		for y in range(int(a[0]), haut_ + 1):
			var c := Vector3i(k.x, y, k.y)
			if vides.has(c) or cases.has(c):
				continue
			var r: String = a[2] if y == haut_ else a[3]
			if not par_role.has(r):
				par_role[r] = {}
			par_role[r][c] = true
	for c in cases:
		var r: String = cases[c]
		if not par_role.has(r):
			par_role[r] = {}
		par_role[r][c] = true
	return {"cases": par_role, "creuser": vides.duplicate()}
