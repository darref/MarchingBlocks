extends RefCounted
## LE CATALOGUE DES PRÉFORMES (l'atelier Preshape, la 1.1.0 — Jordan, 21 octobre 2026 : « des listes d'algo très
## ergonomiquement pour créer une multitude de grandes formes paramétrables »).
##
## Ici : la liste des formes (une ligne par fichier), leurs familles, les rôles de leurs parties, et ce qui est COMMUN à
## toutes — les valeurs ramenées à leurs bornes, le quart de tour, l'enfoncement, la réparation des contacts diagonaux,
## l'ancrage au sol, la coquille que montre le fantôme, la vignette d'un pack. PUR : aucun écran, aucun monde (le monde
## n'entre que par la fonction `occupe` d'`ancrer`). Gardé par `DEV_TOOLS/test_preshapes.gd`.
##
## ⚠ LA LISTE EST ÉCRITE À LA MAIN, PAS LUE DANS LE DOSSIER : dans un exe exporté, les scripts deviennent des `.gdc` /
## `.remap` et un parcours de dossier ne rend pas les mêmes noms.

const FS := preload("res://addons/marchingblocks_core/formes_speciales.gd")
const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const Bati := preload("res://app/preshapes/bati.gd")

const FAMILLES := ["reliefs", "eau", "sous_terre", "antique", "fortifications", "habitat", "jeu", "pures"]
const NOMS_FAMILLES := {"reliefs": "Landforms", "eau": "Water basins", "sous_terre": "Underground",
	"antique": "Ancient buildings", "fortifications": "Fortifications", "habitat": "Houses and villages",
	"jeu": "Game layouts", "pures": "Pure shapes"}

const SCRIPTS := [
	preload("res://app/preshapes/reliefs/montagne.gd"),
	preload("res://app/preshapes/reliefs/chaine.gd"),
	preload("res://app/preshapes/reliefs/volcan.gd"),
	preload("res://app/preshapes/reliefs/mesa.gd"),
	preload("res://app/preshapes/reliefs/collines.gd"),
	preload("res://app/preshapes/reliefs/canyon.gd"),
	preload("res://app/preshapes/reliefs/cratere.gd"),
	preload("res://app/preshapes/reliefs/dunes.gd"),
	preload("res://app/preshapes/reliefs/aiguilles.gd"),
	preload("res://app/preshapes/reliefs/arche.gd"),
	preload("res://app/preshapes/reliefs/archipel.gd"),
	preload("res://app/preshapes/reliefs/terrasses.gd"),
	preload("res://app/preshapes/eau/cascade.gd"),
	preload("res://app/preshapes/eau/atoll.gd"),
	preload("res://app/preshapes/sous_terre/grotte.gd"),
	preload("res://app/preshapes/sous_terre/galeries.gd"),
	preload("res://app/preshapes/sous_terre/puits.gd"),
	preload("res://app/preshapes/antique/pyramide.gd"),
	preload("res://app/preshapes/antique/ziggourat.gd"),
	preload("res://app/preshapes/antique/temple.gd"),
	preload("res://app/preshapes/antique/amphitheatre.gd"),
	preload("res://app/preshapes/antique/obelisque.gd"),
	preload("res://app/preshapes/antique/cromlech.gd"),
	preload("res://app/preshapes/antique/aqueduc.gd"),
	preload("res://app/preshapes/antique/pont.gd"),
	preload("res://app/preshapes/antique/phare.gd"),
	preload("res://app/preshapes/fortifications/rempart.gd"),
	preload("res://app/preshapes/fortifications/tour.gd"),
	preload("res://app/preshapes/fortifications/chateau.gd"),
	preload("res://app/preshapes/fortifications/bastion.gd"),
	preload("res://app/preshapes/fortifications/motte.gd"),
	preload("res://app/preshapes/habitat/maison.gd"),
	preload("res://app/preshapes/habitat/village.gd"),
	preload("res://app/preshapes/jeu/bordures.gd"),
	preload("res://app/preshapes/jeu/labyrinthe.gd"),
	preload("res://app/preshapes/jeu/ile_flottante.gd"),
	preload("res://app/preshapes/pures/sphere.gd"),
	preload("res://app/preshapes/pures/cylindre.gd"),
	preload("res://app/preshapes/pures/tore.gd"),
	preload("res://app/preshapes/pures/spirale.gd"),
	preload("res://app/preshapes/pures/voute.gd"),
]

## LES RÔLES des parties d'une forme ; l'atelier donne une couche du projet à chacun (comme Generate).
const ROLES := ["sol", "sol2", "sable", "roche", "neige", "chemin", "pierre", "toit"]
const NOMS_ROLES := {"sol": "Ground", "sol2": "Second ground", "sable": "Sand", "roche": "Rock", "neige": "Snow",
	"chemin": "Paving, paths", "pierre": "Masonry", "toit": "Roofs"}
## Le rôle qui le remplace quand aucune couche ne lui est donnée.
const REPLI := {"sol2": "sol", "sable": "sol", "neige": "roche", "roche": "sol", "chemin": "pierre", "pierre": "roche",
	"toit": "pierre"}
## La teinte de chaque rôle dans le fantôme et les vignettes ; ROUGE : ce que la forme creuse.
const TEINTES := {"sol": Color(0.45, 0.78, 0.38), "sol2": Color(0.28, 0.55, 0.3), "sable": Color(0.93, 0.8, 0.5),
	"roche": Color(0.6, 0.6, 0.64), "neige": Color(0.96, 0.97, 1.0), "chemin": Color(0.72, 0.55, 0.38),
	"pierre": Color(0.86, 0.8, 0.68), "toit": Color(0.72, 0.3, 0.24)}
const ROUGE := Color(0.92, 0.36, 0.24)

## Au-delà, le fantôme ne montre que la coquille (les cases qui touchent le vide) — toujours, en fait : l'intérieur ne se
## voit pas. Au-delà de CASES_MAXI, la forme est refusée (les bornes des facteurs l'empêchent ; c'est un garde-fou).
const CASES_MAXI := 400000
## L'ancrage au sol descend au plus de tant de cases sous chaque colonne.
const ANCRAGE_MAXI := 24

static var _formes: Array = []
static var _par_id := {}


static func formes() -> Array:
	if _formes.is_empty():
		for s in SCRIPTS:
			var f: RefCounted = s.new()
			_formes.append(f)
			_par_id[f.id] = f
	return _formes


static func forme(id: String) -> RefCounted:
	formes()
	return _par_id.get(id)


static func de_la_famille(famille: String) -> Array:
	return formes().filter(func(f): return famille == "" or f.famille == famille)


## Les valeurs d'une forme : ses défauts, puis `entree`, ramenée à ses bornes (un pack abîmé ne casse rien).
static func valeurs(f: RefCounted, entree: Dictionary = {}) -> Dictionary:
	var v := {}
	for d in f.facteurs():
		var k: String = d["cle"]
		var x: Variant = entree.get(k, d["defaut"])
		if d.has("choix"):
			v[k] = clampi(int(x) if (x is int or x is float) else int(d["defaut"]), 0, (d["choix"] as Array).size() - 1)
		elif d.get("bool", false):
			v[k] = bool(x) if (x is bool or x is int or x is float) else bool(d["defaut"])
		else:
			var n: float = float(x) if (x is int or x is float) else float(d["defaut"])
			n = clampf(n, float(d["mini"]), float(d["maxi"]))
			v[k] = int(round(n)) if float(d["pas"]) >= 1.0 else n
	return v


## LA FORME BÂTIE : {"cases": {rôle: {Vector3i: true}}, "creuser": {Vector3i: true}, "compte": int, "boite": AABB en
## cases (min, taille)}. `quart` : quarts de tour autour de y ; `enfoncer` : cases sous le sol visé. `reparer` : les
## contacts diagonaux de la forme seule sont comblés (le fantôme s'en passe, la pose non).
static func construire(id: String, entree: Dictionary, graine: int, quart := 0, enfoncer := 0, reparer := true) -> Dictionary:
	var f: RefCounted = forme(id)
	if f == null:
		return {"cases": {}, "creuser": {}, "compte": 0, "boite": AABB()}
	var b := Bati.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([id, graine])
	f.construire(valeurs(f, entree), b, rng)
	var brut: Dictionary = b.resoudre()
	# Réparée AVANT le quart de tour et l'enfoncement : les tranches d'un relief se lisent en hauteurs locales.
	if reparer:
		reparer_les_diagonales(brut, b.bandes)
	var q := posmod(quart, 4)
	var r := {"cases": {}, "creuser": {}}
	for role in brut["cases"]:
		var d := {}
		for c in brut["cases"][role]:
			d[tourner(c, q) + Vector3i(0, -enfoncer, 0)] = true
		r["cases"][role] = d
	for c in brut["creuser"]:
		r["creuser"][tourner(c, q) + Vector3i(0, -enfoncer, 0)] = true
	_mesurer(r)
	return r


static func tourner(c: Vector3i, quart: int) -> Vector3i:
	match quart:
		1:
			return Vector3i(-c.z, c.y, c.x)
		2:
			return Vector3i(-c.x, c.y, -c.z)
		3:
			return Vector3i(c.z, c.y, -c.x)
	return c


static func _mesurer(r: Dictionary) -> void:
	var n := 0
	var bas := Vector3i(1 << 30, 1 << 30, 1 << 30)
	var haut := -bas
	for role in r["cases"]:
		for c in r["cases"][role]:
			n += 1
			bas = bas.min(c)
			haut = haut.max(c)
	for c in r["creuser"]:
		bas = bas.min(c)
		haut = haut.max(c)
	r["compte"] = n
	r["boite"] = AABB(Vector3(bas), Vector3(haut - bas + Vector3i.ONE)) if haut.x >= bas.x else AABB()


## Toutes les cases pleines de la forme : {Vector3i: rôle}.
static func pleines(r: Dictionary) -> Dictionary:
	var t := {}
	for role in r["cases"]:
		for c in r["cases"][role]:
			t[c] = role
	return t


## LES CONTACTS PAR UNE ARÊTE (les cubes rouges) de la forme seule, comblés par `FS.reparer_les_diagonales`, partie de
## la COQUILLE (sur toutes les cases, une montagne attendait 0,8 s) — et pas du tout quand le compteur natif n'en voit
## aucun.
## ⚠ LE RÔLE D'UNE CASE AJOUTÉE : devenue un DESSUS, elle prend la matière de sa hauteur si la forme a dit ses tranches
## (`bandes`, un relief), sinon celle des dessus voisins de MÊME HAUTEUR — prendre la roche du corps d'une colonne voisine
## plus haute posait de la roche sur un plat d'herbe (mesuré : 12 paires sur la montagne par défaut ; prolonger la matière
## de sa propre colonne en faisait 19, une colonne prolongée change de tranche). Une case ajoutée sous une autre prend le
## rôle d'une voisine de côté ou du dessous.
static func reparer_les_diagonales(r: Dictionary, bandes: Array = []) -> int:
	var t := pleines(r)
	if MB.contacts_par_arete(t) == 0:
		return 0
	var rep: Dictionary = FS.reparer_les_diagonales(t, false, {}, {}, coquille(t))
	var ajoutees: Array = (rep["poser"] as Dictionary).keys()
	var origine := t.duplicate()
	for c in ajoutees:
		t[c] = ""
	# UN RELIEF DIT SES TRANCHES (`Bati.bandes`) : un dessus ajouté prend la matière de sa hauteur, comme la forme l'aurait
	# nommé. Ceux-là ne votent plus.
	var fixes := {}
	if not bandes.is_empty():
		for c in ajoutees:
			if not t.has(c + Vector3i.UP):
				t[c] = Bati.par_hauteur(c.y + 1, bandes)
				fixes[c] = true
	# Trois passes : les voisines d'origine d'abord (leur rôle est sûr), puis les cases ajoutées déjà nommées.
	for passe in 3:
		for c in ajoutees:
			if fixes.has(c):
				continue
			var role := _role_ajoute(origine, t, c)
			if role == "" and passe > 0:
				role = _role_ajoute(t, t, c)
			if role != "" or passe == 2:
				t[c] = role if role != "" else "pierre"
	# Puis les dessus ajoutés côte à côte s'accordent : chacun prend la matière la plus fréquente des dessus voisins de
	# même hauteur, jusqu'à ce que rien ne change (deux cases ajoutées voisines se nommaient l'une sans l'autre).
	for tour_ in 20:
		var change := false
		for c in ajoutees:
			if t.has(c + Vector3i.UP) or fixes.has(c):
				continue
			var compte := {}
			for d in _HUIT:
				var q: Vector3i = c + d
				if t.has(q) and not t.has(q + Vector3i.UP):
					# Une voisine par une face compte plus qu'une voisine en biais, une case d'origine plus qu'une ajoutée.
					var poids := (3 if d.x == 0 or d.z == 0 else 1) * (2 if origine.has(q) else 1)
					compte[t[q]] = int(compte.get(t[q], 0)) + poids
			var meilleur: String = t[c]
			for k in compte:
				if int(compte[k]) > int(compte.get(meilleur, 0)):
					meilleur = k
			if meilleur != t[c]:
				t[c] = meilleur
				change = true
		if not change:
			break
	for c in ajoutees:
		var role: String = t[c]
		if not (r["cases"] as Dictionary).has(role):
			r["cases"][role] = {}
		r["cases"][role][c] = true
	return ajoutees.size()


const _HUIT := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(1, 0, 1),
	Vector3i(-1, 0, 1), Vector3i(1, 0, -1), Vector3i(-1, 0, -1)]


## Le rôle d'une case ajoutée `c`, lu dans `roles` ; `t` dit ce qui est plein (pour savoir qui est un dessus).
static func _role_ajoute(roles: Dictionary, t: Dictionary, c: Vector3i) -> String:
	var lire := func(q: Vector3i) -> String: return str(roles.get(q, ""))
	if not t.has(c + Vector3i.UP):
		var compte := {}
		for d in _HUIT:
			var q: Vector3i = c + d
			if lire.call(q) != "" and not t.has(q + Vector3i.UP):
				compte[roles[q]] = int(compte.get(roles[q], 0)) + 1
		if not compte.is_empty():
			var meilleur := ""
			for k in compte:
				if meilleur == "" or int(compte[k]) > int(compte[meilleur]):
					meilleur = k
			return meilleur
		if lire.call(c + Vector3i.DOWN) != "":
			return roles[c + Vector3i.DOWN]
	for d in [Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK, Vector3i.UP]:
		if lire.call(c + d) != "":
			return roles[c + d]
	for d in [Vector3i(1, -1, 0), Vector3i(-1, -1, 0), Vector3i(0, -1, 1), Vector3i(0, -1, -1)] + _HUIT:
		if lire.call(c + d) != "":
			return roles[c + d]
	return ""


## L'ANCRAGE AU SOL : sous chaque colonne de la forme (posée en `ancre`) qui part de sa base (la case la plus basse à
## `base` ou dessous), on descend jusqu'à la matière du monde (`occupe(case du monde) -> bool`), au plus ANCRAGE_MAXI
## cases ; ces cases prennent le rôle de la case la plus basse de la colonne. Rend {Vector3i local: rôle} (rien n'est
## posé : l'appelant les ajoute).
## ⚠ SEULEMENT LES COLONNES DE LA BASE : sous une arche, un pont, une île flottante, la case la plus basse est en l'air
## exprès — la combler boucherait l'arche.
static func fondations(r: Dictionary, ancre: Vector3i, occupe: Callable, base := 0) -> Dictionary:
	var plus_bas := {}   # Vector2i → [y, rôle]
	for role in r["cases"]:
		for c in r["cases"][role]:
			var k := Vector2i(c.x, c.z)
			if not plus_bas.has(k) or c.y < int(plus_bas[k][0]):
				plus_bas[k] = [c.y, role]
	var sortie := {}
	for k in plus_bas:
		var y: int = plus_bas[k][0]
		if y > base:
			continue
		var c := Vector3i(k.x, y - 1, k.y)
		var pris := {}
		var touche := false
		for i in ANCRAGE_MAXI:
			if r["creuser"].has(c) or occupe.call(c + ancre):
				touche = true
				break
			pris[c] = true
			c += Vector3i.DOWN
		if touche:
			for p in pris:
				sortie[p] = plus_bas[k][1]
	return sortie


## LA COQUILLE : les cases pleines dont une des six voisines est vide — ce que le fantôme montre.
static func coquille(t: Dictionary) -> Array:
	var sortie: Array = []
	for c in t:
		if not (t.has(c + Vector3i.UP) and t.has(c + Vector3i.DOWN) and t.has(c + Vector3i.LEFT)
				and t.has(c + Vector3i.RIGHT) and t.has(c + Vector3i.FORWARD) and t.has(c + Vector3i.BACK)):
			sortie.append(c)
	return sortie


## LA VIGNETTE d'une forme bâtie : vue de dessus, la teinte du rôle de la plus haute case, ombrée par la hauteur ; ce
## qu'elle creuse en sombre.
static func vignette(r: Dictionary, cote := 48) -> Image:
	var img := Image.create(cote, cote, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var b: AABB = r["boite"]
	if b.size.x <= 0:
		return img
	var echelle := float(cote - 4) / maxf(b.size.x, b.size.z)
	var haut := {}   # Vector2i → [y, rôle]
	for role in r["cases"]:
		for c in r["cases"][role]:
			var k := Vector2i(c.x, c.z)
			if not haut.has(k) or c.y > int(haut[k][0]):
				haut[k] = [c.y, role]
	var creux := {}
	for c in r["creuser"]:
		creux[Vector2i(c.x, c.z)] = true
	var y0 := b.position.y
	var dy := maxf(b.size.y, 1.0)
	var ox := (cote - b.size.x * echelle) * 0.5
	var oz := (cote - b.size.z * echelle) * 0.5
	for px in cote:
		for pz in cote:
			var k := Vector2i(floori(b.position.x + (px - ox) / echelle), floori(b.position.z + (pz - oz) / echelle))
			if haut.has(k):
				var t := 0.55 + 0.45 * (float(haut[k][0]) - y0) / dy
				var col: Color = TEINTES.get(haut[k][1], Color.WHITE)
				img.set_pixel(px, pz, Color(col.r * t, col.g * t, col.b * t, 1.0))
			elif creux.has(k):
				img.set_pixel(px, pz, Color(0.18, 0.12, 0.12, 1.0))
	return img
