@tool
extends RefCounted
## LES FRANCHISSEURS — DÉCIDÉ (Jordan, 20 octobre 2026 : « Mb n'est pas fini, il faut un workshop de franchiseurs
## (escaliers, pentes) éditables, et placables par dessus le terrain là où le test le permet », puis « Test de pose,
## sculpté, commençons avec pente et escaliers »). Charte, « l'atelier des franchisseurs ».
##
## ⚠ **ICI VIT LA RÈGLE, ET RIEN QUE LA RÈGLE** (comme `feuillage.gd`) : des fonctions pures qui lisent le monde par un
## `Callable` et rendent des décisions. Aucun nœud, aucune annulation. Elles partiront dans les greffons.
## ⚠ À NE PAS CONFONDRE avec l'outil « Stairs » de World (`formes_speciales.gd`), qui taille des CASES en escalier : un
## franchisseur est un OBJET SCULPTÉ posé par-dessus le terrain, jamais dans les tuiles (la règle de pose ne change pas).
##
## UN MODÈLE : {id, nom, genre, largeur, hauteur, longueur, maillage}.
##   • `genre` — « escalier » ou « pente » (le maillage de départ, `maillage_de_depart`) ;
##   • `largeur`, `hauteur`, `longueur` — en CASES, entières : la largeur de passage, la hauteur FRANCHIE (le mur), la
##     profondeur au sol devant le mur ;
##   • `sculpte` — vrai dès que l'artiste a retouché le maillage dans le modeleur : changer les dimensions le perdrait ;
##   • `maillage` — le `MaillageEdite` SCULPTÉ (son dictionnaire, `.mbmesh`), dans le repère du modèle : x ∈ [0, largeur]
##     (la largeur), y ∈ [0, hauteur] (le haut), z ∈ [−longueur, 0] — on MONTE vers −z, le pied en z = 0, le mur en
##     z = −longueur. L'artiste le resculpte à son goût ; le test de pose ne lit que ses CASES (largeur × longueur).
## UNE POSE : {id, modele, bas, quart} — `bas` la case du pied (la case vide, sur le sol d'en bas, au bout de la rampe
## le plus loin du mur, à gauche en montant), `quart` le quart de tour : la direction de la montée est `DIRECTIONS[quart]`.
##
## LE TEST DE POSE (`verifier`, rend "" ou une raison) — sur les cases, comme le reste de la règle :
##   • chaque case de la rampe (largeur × longueur, sur `hauteur` cases de haut) est VIDE, et la case sous chaque case du
##     pied est PLEINE (le sol d'en bas) → sinon « pas_de_sol » ou « encombre » ;
##   • le MUR, la rangée devant la rampe, est PLEIN sur toute la hauteur → sinon « pas_de_mur » ;
##   • le PALIER, au-dessus du mur, est VIDE (une case de passage) → sinon « pas_de_palier » ;
##   • aucune case n'est déjà prise par une autre pose → sinon « deja_pris ».

const GENRES := ["escalier", "pente"]
## La direction de la MONTÉE pour chaque quart de tour (0 : vers −z, puis dans le sens horaire vu de dessus).
const DIRECTIONS := [Vector3i(0, 0, -1), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0)]
const RAISONS := {
	"pas_de_sol": "Nothing to stand on at the foot",
	"encombre": "Something is in the way",
	"pas_de_mur": "No wall of this height to climb",
	"pas_de_palier": "No landing at the top",
	"deja_pris": "Another crossing is already there",
}
## Les marches par case de hauteur, pour l'escalier de départ.
const MARCHES_PAR_CASE := 3


static func modele(id: int, nom: String, genre: String, largeur := 1, hauteur := 1, longueur := 1) -> Dictionary:
	var m := {"id": id, "nom": nom, "genre": genre if genre in GENRES else "escalier",
		"largeur": maxi(1, largeur), "hauteur": maxi(1, hauteur), "longueur": maxi(1, longueur), "maillage": {},
		"sculpte": false}
	return m


static func pose(id: int, m: int, bas: Vector3i, quart: int) -> Dictionary:
	return {"id": id, "modele": m, "bas": bas, "quart": posmod(quart, 4)}


## La direction de la largeur (à droite en montant) pour un quart de tour.
static func droite(quart: int) -> Vector3i:
	var d: Vector3i = DIRECTIONS[posmod(quart, 4)]
	return Vector3i(-d.z, 0, d.x)


## LES CASES DE LA RAMPE : celles que le franchisseur occupe (largeur × longueur × hauteur), devant le mur.
static func cases_de(m: Dictionary, p: Dictionary) -> Array:
	var d: Vector3i = DIRECTIONS[int(p["quart"])]
	var r := droite(int(p["quart"]))
	var bas: Vector3i = p["bas"]
	var sortie: Array = []
	for w in int(m["largeur"]):
		for i in int(m["longueur"]):
			for j in int(m["hauteur"]):
				sortie.append(bas + r * w + d * i + Vector3i.UP * j)
	return sortie


## LE TEST DE POSE. `plein(case) -> bool` lit le monde ; `prises` : {case: id de pose} des autres poses.
static func verifier(m: Dictionary, p: Dictionary, plein: Callable, prises := {}) -> String:
	var d: Vector3i = DIRECTIONS[int(p["quart"])]
	var r := droite(int(p["quart"]))
	var bas: Vector3i = p["bas"]
	var L := int(m["longueur"])
	var h := int(m["hauteur"])
	for c in cases_de(m, p):
		if prises.has(c) and prises[c] != p.get("id", -1):
			return "deja_pris"
	for w in int(m["largeur"]):
		var pied := bas + r * w
		for i in L:
			if not plein.call(pied + d * i + Vector3i.DOWN):
				return "pas_de_sol"
			for j in h:
				if plein.call(pied + d * i + Vector3i.UP * j):
					return "encombre"
		var mur := pied + d * L
		for j in h:
			if not plein.call(mur + Vector3i.UP * j):
				return "pas_de_mur"
		if plein.call(mur + Vector3i.UP * h):
			return "pas_de_palier"
	return ""


## LE QUART DE TOUR QUI CONVIENT à une case visée : le premier dont le test passe (la montée va vers le mur), −1 sinon.
## `prefere` d'abord (celui du dernier coup, ou de la caméra) : le fantôme ne tourne pas sans raison.
static func orienter(m: Dictionary, bas: Vector3i, plein: Callable, prises := {}, prefere := 0) -> int:
	for k in 4:
		var q := posmod(prefere + k, 4)
		if verifier(m, pose(-1, int(m["id"]), bas, q), plein, prises) == "":
			return q
	return -1


## OÙ LE MAILLAGE EST POSÉ : le repère du modèle (x largeur, y haut, montée vers −z, en cases) tourné du quart de tour et
## porté sur ses cases. En CASES : le monde le met à l'échelle de sa taille de case.
static func transformation(m: Dictionary, p: Dictionary) -> Transform3D:
	var q := int(p["quart"])
	var b := Basis(Vector3.UP, -q * PI / 2.0)
	var d := Vector3(DIRECTIONS[q])
	var r := Vector3(droite(q))
	var W := float(m["largeur"])
	var L := float(m["longueur"])
	var h := float(m["hauteur"])
	var centre_monde := Vector3(p["bas"]) + Vector3(0.5, 0.0, 0.5) + d * (L - 1.0) / 2.0 + r * (W - 1.0) / 2.0 \
		+ Vector3(0.0, h / 2.0, 0.0)
	var centre_local := Vector3(W / 2.0, h / 2.0, -L / 2.0)
	return Transform3D(b, centre_monde - b * centre_local)


## POSER PARTOUT OÙ ÇA TIENT : chaque case de `candidats` (des cases VIDES, sur un sol), dans l'ordre, reçoit le modèle au
## premier quart qui passe le test de pose — les poses déjà là et celles qui viennent d'être posées comptent. Rend les
## nouvelles poses (ids à partir de `premier_id`). Ce que Generate fera aux marches de ses chemins (l'étape 5).
static func poser_partout(m: Dictionary, candidats: Array, plein: Callable, deja: Array, modeles: Dictionary,
		premier_id := 1) -> Array:
	var prises := prises_de(modeles, deja)
	var nouvelles: Array = []
	for c in candidats:
		var q := orienter(m, c, plein, prises)
		if q < 0:
			continue
		var p := pose(premier_id + nouvelles.size(), int(m["id"]), c, q)
		nouvelles.append(p)
		for k in cases_de(m, p):
			prises[k] = p["id"]
	return nouvelles


## {case: id} de toutes les poses (pour `verifier`).
static func prises_de(modeles: Dictionary, poses: Array) -> Dictionary:
	var d := {}
	for p in poses:
		var m = modeles.get(int(p["modele"]))
		if m == null:
			continue
		for c in cases_de(m, p):
			d[c] = p["id"]
	return d


# ── LE PROJET ────────────────────────────────────────────────────────────────────────────────────────

## Ce que le `.mbproj` garde (clé `"franchisseurs"`) : {"modeles": [les dictionnaires, le maillage en `.mbmesh`],
## "poses": liste plate, 5 nombres par pose : modèle, x, y, z de la case du bas, quart}.
static func vers_donnees(modeles: Array, poses: Array) -> Dictionary:
	if modeles.is_empty():
		return {}
	var plat: Array = []
	for p in poses:
		var b: Vector3i = p["bas"]
		plat.append_array([int(p["modele"]), b.x, b.y, b.z, int(p["quart"])])
	var ms: Array = []
	for m in modeles:
		ms.append((m as Dictionary).duplicate(true))
	return {"modeles": ms, "poses": plat}


## La relecture : {"modeles", "poses"}, ou {} (et l'erreur dite) si une entrée est malformée — comme le feuillage, une
## entrée fausse refuse le tout plutôt que d'en garder une partie.
static func depuis_donnees(brut: Variant, erreurs: Array) -> Dictionary:
	if brut == null:
		return {"modeles": [], "poses": []}
	if not brut is Dictionary or not brut.get("modeles") is Array or not brut.get("poses", []) is Array:
		erreurs.append("crossings: not {modeles, poses}")
		return {}
	var modeles: Array = []
	var ids := {}
	for m in brut["modeles"]:
		if not m is Dictionary or not m.has("id") or not str(m.get("genre", "")) in GENRES:
			erreurs.append("crossings: a model is malformed")
			return {}
		var d := modele(int(m["id"]), str(m.get("nom", "Crossing")), str(m["genre"]), int(m.get("largeur", 1)),
			int(m.get("hauteur", 1)), int(m.get("longueur", 1)))
		d["maillage"] = m.get("maillage", {}) if m.get("maillage", {}) is Dictionary else {}
		d["sculpte"] = bool(m.get("sculpte", false))
		modeles.append(d)
		ids[d["id"]] = true
	var plat: Array = brut.get("poses", [])
	if plat.size() % 5 != 0:
		erreurs.append("crossings: poses are not groups of 5 numbers")
		return {}
	var poses: Array = []
	for k in range(0, plat.size(), 5):
		if not ids.has(int(plat[k])):
			erreurs.append("crossings: a pose names a model that does not exist")
			return {}
		poses.append(pose(k / 5 + 1, int(plat[k]), Vector3i(int(plat[k + 1]), int(plat[k + 2]), int(plat[k + 3])),
			int(plat[k + 4])))
	return {"modeles": modeles, "poses": poses}


# ── LES MAILLAGES DE DÉPART ──────────────────────────────────────────────────────────────────────────

## LE MAILLAGE DE DÉPART d'un modèle, à resculpter : un PRISME — le profil (les marches, ou le triangle de la pente) dans
## le plan (z, y), extrudé sur la largeur. Fermé et étanche (le modèle du `MaillageEdite` : pas d'arête libre), en quads
## sauf les deux flancs (un polygone chacun) : ce que le modeleur sait biseauter, couper, sculpter.
static func maillage_de_depart(m: Dictionary) -> RefCounted:
	var L := float(m["longueur"])
	var h := float(m["hauteur"])
	var profil: Array = []   # Vector2(z, y), du pied (z = 0, y = 0) au haut du mur, puis le dessous
	if m["genre"] == "pente":
		profil = [Vector2(0, 0), Vector2(-L, h), Vector2(-L, 0)]
	else:
		var n := maxi(1, int(round(h * MARCHES_PAR_CASE)))
		var giron := L / n
		var hauteur_marche := h / n
		profil.append(Vector2(0, 0))
		for k in n:
			profil.append(Vector2(-giron * k, hauteur_marche * (k + 1)))
			profil.append(Vector2(-giron * (k + 1), hauteur_marche * (k + 1)))
		profil.append(Vector2(-L, 0))
	return prisme(profil, float(m["largeur"]))


## Un prisme : `profil` (Vector2(z, y), un polygone simple) extrudé de x = 0 à x = `largeur`.
static func prisme(profil: Array, largeur: float) -> RefCounted:
	var me: RefCounted = load("res://addons/marchingblocks_core/maillage_edite.gd").new()
	var n := profil.size()
	for x in [0.0, largeur]:
		for q in profil:
			me.sommets.append(Vector3(x, (q as Vector2).y, (q as Vector2).x))
	# Le sens du profil (aire signée dans le plan (z, y)) donne la normale sortante de chaque arête : un escalier n'est
	# pas convexe, une orientation « loin du centre » retournerait ses contremarches du haut.
	var aire := 0.0
	for i in n:
		var a: Vector2 = profil[i]
		var b: Vector2 = profil[(i + 1) % n]
		aire += a.x * b.y - b.x * a.y
	var signe := 1.0 if aire > 0.0 else -1.0
	var gauche := PackedInt32Array()
	var droite_ := PackedInt32Array()
	for i in n:
		gauche.append(i)
		droite_.append(n + i)
	_ajouter(me, gauche, Vector3.LEFT)
	_ajouter(me, droite_, Vector3.RIGHT)
	for i in n:
		var j := (i + 1) % n
		var e: Vector2 = (profil[j] as Vector2) - (profil[i] as Vector2)
		# Profil dans le sens trigonométrique : la normale sortante de l'arête (du, dv) est (dv, −du) ; u = z, v = y.
		var sortante := Vector3(0.0, -e.x, e.y) * signe
		_ajouter(me, PackedInt32Array([i, j, n + j, n + i]), sortante)
	return me


## Ajoute une face TOURNÉE VERS `sortante` (sens trigonométrique vu de dehors, la convention du `MaillageEdite`).
static func _ajouter(me: RefCounted, f: PackedInt32Array, sortante: Vector3) -> void:
	var nrm := Vector3.ZERO
	for k in f.size():
		var a: Vector3 = me.sommets[f[k]]
		var b: Vector3 = me.sommets[f[(k + 1) % f.size()]]
		nrm += Vector3((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y))
	if nrm.dot(sortante) < 0.0:
		f.reverse()
	me.faces.append(f)
	me.teintes.append(Color(0.75, 0.72, 0.66))
	me.mats.append(-1)
	me.uvs.append(PackedVector2Array())
