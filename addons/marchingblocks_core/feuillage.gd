@tool
extends RefCounted
## LE FEUILLAGE — DEMANDÉ PAR JORDAN (6 octobre 2026) : « l'atelier Foliage (un placement dans le monde de foliages
## comme des arbres dont on importe le fichier 3D comme glb et on place dans cet atelier sur un socle qui représente le
## sol pour cerner à quel offset l'objet sera placé par rapport au sol, et ensuite prévoir toutes les règles
## intelligentes de placement ; l'atelier Foliage a le monde dans sa vue comme World mais il ne pourra que placer des
## foliages, n'importe où avec des modes : dans le vide, planté au sol voisinage libre, planté au sol débordement) ».
##
## ⚠ **ICI VIT LA RÈGLE, ET RIEN QUE LA RÈGLE** (comme `outils.gd`) : des fonctions pures qui lisent le monde par des
## `Callable` et rendent des décisions. Aucun nœud, aucune annulation. Elles partiront dans les greffons (charte §0, la
## liste des greffons à faire) : d'où des noms de données courts et sans surprise.
##
## UN MODÈLE (un `.glb` importé) : {id, nom, chemin, decalage, echelle, echelle_alea, rayon, hauteur, vent}.
##   • `decalage` — en unités DU MODÈLE : de combien son origine est posée AU-DESSUS du sol (négatif : enfoncée). Réglé
##     sur le SOCLE de l'atelier ; c'est ce qui enterre les racines d'un arbre sous la surface ;
##   • `echelle` — le facteur de tout le modèle ; `echelle_alea` — chaque plant tire un facteur dans [1 − a, 1 + a] ;
##   • `rayon` — l'EMPREINTE au sol, en cases (à l'échelle 1) : ce que « voisinage libre » garde libre ;
##   • `hauteur` — le haut du modèle au-dessus de son ORIGINE, en unités du modèle (mesuré sur le fichier) : avec le
##     décalage et l'échelle, la hauteur qui doit rester dégagée au-dessus du sol (`hauteur_au_dessus_du_sol`) ;
##   • `vent` — de 0 (immobile) à 1 : l'amplitude du balancement (le rendu, pas la règle).
## UN PLANT : {id, modele, p, lacet, echelle, mode} — `p` est le point AU SOL (le décalage s'ajoute au rendu), `lacet`
## en radians autour de +Y, `echelle` le tirage du plant (le modèle a la sienne), `mode` « air » ou « sol ».
##
## LES TROIS MODES DE PLACEMENT (PROPOSÉ : le sens précis de chacun) :
##   • « air » — DANS LE VIDE : là où l'on clique, sur le plan de la grille, rien n'est demandé au monde sinon de ne pas
##     être DANS la matière ;
##   • « sol_libre » — PLANTÉ AU SOL, VOISINAGE LIBRE : sur la surface vue des tuiles ; refusé si le sol penche trop,
##     dans l'eau, si l'EMPREINTE n'est pas portée par le sol (au bord d'une falaise), si la matière l'empêche de pousser
##     (sous un surplomb), ou si un autre plant empiète sur son empreinte ;
##   • « sol_debord » — PLANTÉ AU SOL, DÉBORDEMENT : sur la surface, la pente et l'eau seules comptent ; il peut DÉBORDER
##     d'un bord, chevaucher la matière et ses voisins — seul l'espacement du pinceau le sépare des autres.

const MODES := ["air", "sol_libre", "sol_debord"]
## La pente maximale d'un sol où l'on plante, en degrés (PROPOSÉ).
const PENTE_MAXI := 40.0
## L'écart de hauteur toléré sous l'empreinte, en cases (PROPOSÉ) : un sol sculpté n'est jamais plat.
const TOLERANCE_SOL := 0.35
## Les points du bord de l'empreinte qu'on interroge.
const ECHANTILLONS := 8
## Deux plants plus proches que ça sont le même : on ne plante pas deux fois au même endroit.
const DOUBLON := 0.05
## La taille des seaux de l'index des plants, en cases.
const SEAU := 4.0


static func modele(id: int, nom: String, chemin: String) -> Dictionary:
	return {"id": id, "nom": nom, "chemin": chemin, "decalage": 0.0, "echelle": 1.0, "echelle_alea": 0.2,
		"rayon": 0.5, "hauteur": 1.0, "vent": 0.5}


static func plant(id: int, m: int, p: Vector3, lacet: float, echelle: float, mode: String) -> Dictionary:
	return {"id": id, "modele": m, "p": p, "lacet": lacet, "echelle": echelle, "mode": "air" if mode == "air" else "sol"}


## Le facteur total d'un plant (son tirage × celui du modèle).
static func echelle_de(m: Dictionary, pl: Dictionary) -> float:
	return float(m["echelle"]) * float(pl["echelle"])


## Sa hauteur au-dessus du sol, en cases : (haut du modèle + décalage) × échelle.
static func hauteur_au_dessus_du_sol(m: Dictionary, pl: Dictionary) -> float:
	return maxf(0.0, (float(m["hauteur"]) + float(m["decalage"])) * echelle_de(m, pl))


## OÙ LE MODÈLE EST POSÉ : au point du sol, tourné de son lacet, à son échelle, son origine levée du DÉCALAGE (en unités
## du modèle, donc à l'échelle du plant).
static func transformation(m: Dictionary, pl: Dictionary) -> Transform3D:
	var s := echelle_de(m, pl)
	var b := Basis(Vector3.UP, float(pl["lacet"])).scaled(Vector3.ONE * s)
	return Transform3D(b, (pl["p"] as Vector3) + Vector3(0.0, float(m["decalage"]) * s, 0.0))


# ── L'INDEX DES PLANTS ───────────────────────────────────────────────────────────────────────────────

## {seaux: {Vector2i: [plant, …]}, rayon_maxi} — pour ne pas comparer chaque candidat à des milliers de plants.
static func index(plants: Array, modeles: Dictionary) -> Dictionary:
	var ix := {"seaux": {}, "rayon_maxi": 0.0}
	for pl in plants:
		indexer(ix, pl, modeles)
	return ix


static func indexer(ix: Dictionary, pl: Dictionary, modeles: Dictionary) -> void:
	var k := _seau(pl["p"])
	if not ix["seaux"].has(k):
		ix["seaux"][k] = []
	(ix["seaux"][k] as Array).append(pl)
	if modeles.has(pl["modele"]):
		ix["rayon_maxi"] = maxf(ix["rayon_maxi"], _rayon(modeles[pl["modele"]], pl))


static func desindexer(ix: Dictionary, pl: Dictionary) -> void:
	var k := _seau(pl["p"])
	if ix["seaux"].has(k):
		(ix["seaux"][k] as Array).erase(pl)


static func _seau(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / SEAU), floori(p.z / SEAU))


## Les plants dont le point est à moins de `portee` de `p` (dans le plan, à une hauteur près de `portee` + 2).
static func proches(ix: Dictionary, p: Vector3, portee: float) -> Array:
	var sortie: Array = []
	var lo := _seau(p - Vector3(portee, 0, portee))
	var hi := _seau(p + Vector3(portee, 0, portee))
	for x in range(lo.x, hi.x + 1):
		for z in range(lo.y, hi.y + 1):
			for pl in ix["seaux"].get(Vector2i(x, z), []):
				var q: Vector3 = pl["p"]
				if Vector2(q.x - p.x, q.z - p.z).length() <= portee and absf(q.y - p.y) <= portee + 2.0:
					sortie.append(pl)
	return sortie


static func _rayon(m: Dictionary, pl: Dictionary) -> float:
	return float(m["rayon"]) * echelle_de(m, pl)


# ── LA RÈGLE ─────────────────────────────────────────────────────────────────────────────────────────

## Peut-on planter `pl` (déjà tiré : point, lacet, échelle) dans ce mode ? "" si oui, sinon la raison :
## « dans_la_matiere », « trop_pentu », « dans_l_eau », « au_bord », « sous_la_matiere », « trop_pres », « deja_la ».
## `monde` : {"sol": Callable(x, z, y_haut) → null ou {y, normale}, "plein": Callable(Vector3i) → bool,
## "eau": Callable(Vector3) → bool (facultatif)} ; `normale` : celle du sol au point (UP dans le vide).
## `espacement` : la distance minimale aux autres plants, quel que soit le mode (le pinceau).
static func verifier(m: Dictionary, pl: Dictionary, normale: Vector3, mode: String, monde: Dictionary,
		ix: Dictionary, modeles: Dictionary, espacement := 0.0, pente_maxi := PENTE_MAXI) -> String:
	var p: Vector3 = pl["p"]
	var plein: Callable = monde["plein"]
	var r := _rayon(m, pl)
	# Les voisins : d'abord le doublon, partout.
	var exige_voisin := maxf(espacement, DOUBLON)
	var portee := exige_voisin
	if mode == "sol_libre":
		portee = maxf(portee, r + float(ix.get("rayon_maxi", 0.0)))
	for autre in proches(ix, p, portee):
		var q: Vector3 = autre["p"]
		var d := Vector2(q.x - p.x, q.z - p.z).length()
		if d < DOUBLON:
			return "deja_la"
		if d < espacement:
			return "trop_pres"
		if mode == "sol_libre" and modeles.has(autre["modele"]) and d < r + _rayon(modeles[autre["modele"]], autre):
			return "trop_pres"
	if mode == "air":
		if plein.call(Vector3i(floori(p.x), floori(p.y), floori(p.z))):
			return "dans_la_matiere"
		return ""
	# Planté au sol : la pente, l'eau.
	if normale.normalized().y < cos(deg_to_rad(pente_maxi)) - 1e-6:
		return "trop_pentu"
	var eau: Callable = monde.get("eau", Callable())
	if eau.is_valid() and eau.call(p + Vector3(0, 0.1, 0)):
		return "dans_l_eau"
	if mode != "sol_libre":
		return ""
	# VOISINAGE LIBRE : l'empreinte portée par le sol, à peu près à la même hauteur…
	var sol: Callable = monde["sol"]
	var bords: Array = [Vector2.ZERO]
	for k in ECHANTILLONS:
		var a := TAU * float(k) / float(ECHANTILLONS)
		bords.append(Vector2(cos(a), sin(a)) * r)
	for b: Vector2 in bords:
		if b == Vector2.ZERO:
			continue
		var g = sol.call(p.x + b.x, p.z + b.y, p.y + 1.0)
		if g == null or absf(float(g["y"]) - p.y) > TOLERANCE_SOL:
			return "au_bord"
	# … et rien de plein au-dessus, sur sa hauteur, au centre et au bord de l'empreinte (à mi-rayon : le bord exact
	# frôle les parois voisines qu'on vient de déclarer portées).
	var h := hauteur_au_dessus_du_sol(m, pl)
	var y0 := floori(p.y + 0.3)
	var y1 := floori(p.y + maxf(h, 0.3))
	for b: Vector2 in bords:
		var q := Vector2(p.x, p.z) + b * 0.5
		for y in range(y0, y1 + 1):
			if plein.call(Vector3i(floori(q.x), y, floori(q.y))):
				return "sous_la_matiere"
	return ""


## Le tirage d'un plant : un lacet au hasard (sinon 0) et un facteur dans [1 − a, 1 + a].
static func tirer(m: Dictionary, rng: RandomNumberGenerator, lacet_alea := true) -> Dictionary:
	var a := clampf(float(m["echelle_alea"]), 0.0, 0.9)
	return {"lacet": rng.randf() * TAU if lacet_alea else 0.0, "echelle": 1.0 + rng.randf_range(-a, a)}


## UN CLIC : le plant au point visé `p` (sol ou plan), avec sa normale. Rend {"plant": … ou null, "raison"}.
static func planter(m: Dictionary, p: Vector3, normale: Vector3, mode: String, monde: Dictionary, ix: Dictionary,
		modeles: Dictionary, rng: RandomNumberGenerator, espacement := 0.0, lacet_alea := true,
		pente_maxi := PENTE_MAXI) -> Dictionary:
	var t := tirer(m, rng, lacet_alea)
	var pl := plant(-1, int(m["id"]), p, t["lacet"], t["echelle"], mode)
	var raison := verifier(m, pl, normale, mode, monde, ix, modeles, espacement, pente_maxi)
	return {"plant": pl if raison == "" else null, "raison": raison}


## LE PINCEAU : `essais` points tirés dans le disque de `rayon` autour de `centre` (x, z ; y : la hauteur d'où l'on
## cherche le sol, ou le plan en mode « air »), chacun posé sur le sol puis vérifié — les plants acceptés entrent dans
## l'index au fur et à mesure (deux candidats du même coup se respectent). Rend {"plants": [...], "refus": {raison: n}}.
static func semer(m: Dictionary, centre: Vector3, rayon: float, essais: int, mode: String, monde: Dictionary,
		ix: Dictionary, modeles: Dictionary, rng: RandomNumberGenerator, espacement := 0.0, lacet_alea := true,
		pente_maxi := PENTE_MAXI) -> Dictionary:
	var sortie := {"plants": [], "refus": {}}
	var tirage := func() -> Dictionary: return tirer(m, rng, lacet_alea)
	for i in essais:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * rayon
		_semer_un(m, centre.x + cos(a) * d, centre.z + sin(a) * d, centre.y, tirage, mode, monde, ix, modeles,
			espacement, pente_maxi, sortie)
	return sortie


## LE PINCEAU, SANS LE HASARD — ses candidats donnés : [[x, z, lacet, échelle], …], dans l'ordre. C'est le corps de
## `semer` (le même `_semer_un`) : les cas d'épreuve des greffons l'emploient, parce qu'aucun moteur ne reproduit le
## générateur de Godot (parité des greffons, 7 octobre 2026). Rend {"plants", "refus"} comme `semer`.
static func semer_candidats(m: Dictionary, y_haut: float, candidats: Array, mode: String, monde: Dictionary,
		ix: Dictionary, modeles: Dictionary, espacement := 0.0, pente_maxi := PENTE_MAXI) -> Dictionary:
	var sortie := {"plants": [], "refus": {}}
	for c in candidats:
		var tirage := func() -> Dictionary: return {"lacet": float(c[2]), "echelle": float(c[3])}
		_semer_un(m, float(c[0]), float(c[1]), y_haut, tirage, mode, monde, ix, modeles, espacement, pente_maxi, sortie)
	return sortie


## Un candidat du pinceau au point (x, z) : posé sur le sol cherché sous `y_haut` (ou sur le plan `y_haut` en « air »),
## tiré (`tirage`, APRÈS le sol : l'ordre des tirages du générateur), vérifié, et indexé s'il est accepté.
static func _semer_un(m: Dictionary, x: float, z: float, y_haut: float, tirage: Callable, mode: String,
		monde: Dictionary, ix: Dictionary, modeles: Dictionary, espacement: float, pente_maxi: float,
		sortie: Dictionary) -> void:
	var refus: Dictionary = sortie["refus"]
	var p := Vector3(x, y_haut, z)
	var n := Vector3.UP
	if mode != "air":
		var g = (monde["sol"] as Callable).call(x, z, y_haut)
		if g == null:
			refus["pas_de_sol"] = int(refus.get("pas_de_sol", 0)) + 1
			return
		p.y = float(g["y"])
		n = g["normale"]
	var t: Dictionary = tirage.call()
	var pl := plant(-1, int(m["id"]), p, t["lacet"], t["echelle"], mode)
	var raison := verifier(m, pl, n, mode, monde, ix, modeles, espacement, pente_maxi)
	if raison != "":
		refus[raison] = int(refus.get(raison, 0)) + 1
		return
	(sortie["plants"] as Array).append(pl)
	indexer(ix, pl, modeles)


## Les plants à effacer : ceux dont le point est à moins de `rayon` de `p`.
static func a_effacer(ix: Dictionary, p: Vector3, rayon: float) -> Array:
	return proches(ix, p, rayon).filter(func(pl): return ((pl["p"] as Vector3) - p).length() <= rayon + 0.5)


## L'EAU AU POINT q, telle que l'atelier la lit (`verifier` demande `eau(p + 0,1 vers le haut)`) : la case
## (⌊q.x⌋, ⌊q.y + ECART_EAU⌋, ⌊q.z⌋) porte-t-elle de l'eau ? Sortie de l'écran pour les greffons (7 octobre 2026).
const ECART_EAU := 0.2


static func case_d_eau(q: Vector3) -> Vector3i:
	return Vector3i(floori(q.x), floori(q.y + ECART_EAU), floori(q.z))


# ── LE VENT — les données de chaque plant (le rendu est un shader : `app/feuillage_vue.gd`, réécrit par chaque moteur) ──

## La direction du vent, dans le plan x z (PROPOSÉ).
const SENS_DU_VENT := Vector2(1.0, 0.35)


## CE QUE CHAQUE PLANT DONNE AU SHADER DU VENT : (sol — le y du plant —, hauteur au-dessus du sol, phase, amplitude du
## modèle). La phase vient de la POSITION (deux arbres voisins ne se balancent pas ensemble ; jamais `randi()`).
## Sortie de `feuillage_vue.gd` pour être la règle des greffons (7 octobre 2026).
static func vent_du_plant(m: Dictionary, pl: Dictionary) -> Color:
	var p: Vector3 = pl["p"]
	return Color(p.y, hauteur_au_dessus_du_sol(m, pl), fposmod(p.x * 0.37 + p.z * 0.71, TAU), float(m["vent"]))


## LE BALANCEMENT d'un sommet (en espace MONDE, sa normale aussi) au temps t — le `vertex()` du shader du vent
## (`feuillage_vue.gd`), ligne à ligne : penché sous le vent ∝ carré de la hauteur relative, deux rafales, plus le
## frisson des feuilles le long de la normale. Rend le sommet déplacé. Une hauteur nulle : immobile.
static func balancement(sommet: Vector3, normale: Vector3, vent: Color, t: float, sens := SENS_DU_VENT) -> Vector3:
	var haut := vent.g
	if haut <= 0.0:
		return sommet
	var h := clampf((sommet.y - vent.r) / haut, 0.0, 1.0)
	var phase := vent.b
	var ampleur := vent.a * haut * 0.05
	var b := 0.35 + 0.6 * sin(t * 1.1 + phase) + 0.3 * sin(t * 2.3 + phase * 1.7)
	var s := sens.normalized() * b * ampleur * h * h
	var v := sommet + Vector3(s.x, 0.0, s.y)
	return v + normale * sin(t * 7.0 + v.dot(Vector3(2.1, 1.7, 2.9))) * 0.015 * vent.a * h


## LE SOL DES CASES — la surface quand on n'a pas de tuiles (les tests, un monde sans lot) : le dessus de la plus haute
## case pleine de la colonne sous `y_haut`, à y + 1, normale vers le haut. `y_bas` : on ne cherche pas plus bas.
static func sol_des_cases(plein: Callable, x: float, z: float, y_haut: float, y_bas := -64) -> Variant:
	var cx := floori(x)
	var cz := floori(z)
	for y in range(floori(y_haut) - 1, y_bas - 1, -1):
		if plein.call(Vector3i(cx, y, cz)) and not plein.call(Vector3i(cx, y + 1, cz)):
			return {"y": float(y + 1), "normale": Vector3.UP}
	return null


# ── LE FICHIER ───────────────────────────────────────────────────────────────────────────────────────

## Ce que le projet enregistre : {"modeles": [...], "plants": [m, x, y, z, lacet, echelle, mode (0 air, 1 sol), …]}.
static func vers_donnees(modeles: Array, plants: Array) -> Dictionary:
	var ms: Array = []
	for m in modeles:
		ms.append({"id": int(m["id"]), "nom": str(m["nom"]), "chemin": str(m["chemin"]),
			"decalage": float(m["decalage"]), "echelle": float(m["echelle"]), "echelle_alea": float(m["echelle_alea"]),
			"rayon": float(m["rayon"]), "hauteur": float(m["hauteur"]), "vent": float(m["vent"])})
	var plat: Array = []
	for pl in plants:
		var p: Vector3 = pl["p"]
		plat.append_array([int(pl["modele"]), snappedf(p.x, 0.0001), snappedf(p.y, 0.0001), snappedf(p.z, 0.0001),
			snappedf(float(pl["lacet"]), 0.0001), snappedf(float(pl["echelle"]), 0.0001), 0 if pl["mode"] == "air" else 1])
	return {"modeles": ms, "plants": plat}


## Rend {"modeles", "plants"} (les plants numérotés 1, 2…), ou {} en ajoutant la raison à `erreurs`.
## ⚠ UNE ENTRÉE MALFORMÉE REFUSE LE TOUT (comme le projet) ; un plant d'un modèle inconnu est refusé aussi : il ne se
## dessinerait pas, et serait perdu au prochain enregistrement sans qu'on le sache.
static func depuis_donnees(d: Variant, erreurs: Array) -> Dictionary:
	if d == null:
		return {"modeles": [], "plants": []}
	if not d is Dictionary:
		erreurs.append("foliage is not an object")
		return {}
	var modeles: Array = []
	var ids := {}
	var liste = d.get("modeles", [])
	if not liste is Array:
		erreurs.append("foliage models are not a list")
		return {}
	for i in (liste as Array).size():
		var e = liste[i]
		if not e is Dictionary or not (e.get("id") is float or e.get("id") is int):
			erreurs.append("foliage model %d is malformed" % i)
			return {}
		var m := modele(int(e["id"]), str(e.get("nom", "Model %d" % (i + 1))), str(e.get("chemin", "")))
		for cle in ["decalage", "echelle", "echelle_alea", "rayon", "hauteur", "vent"]:
			var v = e.get(cle, m[cle])
			if not (v is float or v is int):
				erreurs.append("foliage model %d: « %s » is not a number" % [i, cle])
				return {}
			m[cle] = float(v)
		if ids.has(m["id"]):
			erreurs.append("foliage model id %d appears twice" % m["id"])
			return {}
		ids[m["id"]] = true
		modeles.append(m)
	var plat = d.get("plants", [])
	if not plat is Array or (plat as Array).size() % 7 != 0:
		erreurs.append("foliage plants are not groups of seven numbers")
		return {}
	var plants: Array = []
	for k in range(0, (plat as Array).size(), 7):
		for j in 7:
			if not (plat[k + j] is float or plat[k + j] is int):
				erreurs.append("foliage plant %d is not made of numbers" % (k / 7))
				return {}
		var mid := int(plat[k])
		if not ids.has(mid):
			erreurs.append("foliage plant %d uses model %d, which does not exist" % [k / 7, mid])
			return {}
		plants.append(plant(plants.size() + 1, mid, Vector3(plat[k + 1], plat[k + 2], plat[k + 3]), float(plat[k + 4]),
			float(plat[k + 5]), "air" if int(plat[k + 6]) == 0 else "sol"))
	return {"modeles": modeles, "plants": plants}
