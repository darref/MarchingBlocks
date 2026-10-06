extends RefCounted
## LE PROJET — les COUCHES du monde peint, ce qui les habille, et ce qui en survit entre deux sessions.
##
## **DÉCIDÉ (Jordan, 27 septembre 2026)** : le monde peint est indépendant du travail qu'on tranche, et
## il a plusieurs COUCHES. Une couche, c'est UNE SOURCE de tuiles (le témoin calculé, ou un `.glb`
## sculpté) et SES cases peintes — son voisinage ne regarde que ses cases : une couche de roche et une
## couche de glace ne se déforment pas l'une l'autre. Retrancher une couche change ses tuiles, JAMAIS
## ses cases.
##
## ⚠ **CE QUI EST ENREGISTRÉ, C'EST CE QUI NE SE REDÉDUIT PAS** : les cases et la source. Le lot tranché
## se redéduit de la source — il n'est qu'en CACHE, et le cache n'est cru que si la source n'a pas
## changé depuis (`empreinte`). L'artiste réenregistre dans Blender ; un lot périmé montrerait son
## ancien travail sans rien dire.
##
## Fonctions PURES, sans nœud : c'est ce qui les rend gardables par `DEV_TOOLS/test_projet.gd`.

const FE := preload("res://addons/marchingblocks_core/feuillage.gd")

const FORMAT := "marchingblocks-project"
## ⚠ 2 depuis le 4 octobre 2026 : les cases s'écrivent en BINAIRE (`cases_b64`, voir `vers_texte`). Un exe d'avant
## qui lirait ce fichier n'y trouverait pas `cases` et ouvrirait des couches VIDES — puis les enregistrerait : la
## version le lui fait refuser (« made by a newer MarchingBlocks »). La version 1 reste lue.
const VERSION := 2
const EXTENSION := "mbproj"
const DOSSIER_CACHE := "user://cache"
## LE FORMAT DU CACHE. ⚠ 2 depuis le 29 septembre 2026 : le lot porte la PROVENANCE de chaque tuile (le
## sommet du témoin d'où elle vient, lu par l'atelier World). Un lot d'avant ne la porte pas : il passe
## pour périmé et se retranche, sinon « d'où vient cette tuile ? » resterait muet sans dire pourquoi.
## ⚠ 3 depuis le 30 septembre 2026 : UNE tuile par clé (charte §3). Un lot d'avant porte des exemplaires
## « ~k » que le peintre ne pose plus : il passe pour périmé et se retranche.
const FORMAT_DU_CACHE := 3

## La source « témoin calculé ». Toute autre source non vide est un chemin de `.glb`.
const TEMOIN := "witness"


## Une couche neuve : aucune source, aucune case, aucun témoin à elle.
## ⚠ **UNE COUCHE POSSÈDE SON TÉMOIN (Jordan, 30 septembre 2026)** : `temoin` est le chemin de SON témoin
## lié (`.mbtiles`), "" tant qu'elle n'en a pas modélisé — elle montre alors le témoin calculé. Avant, le
## témoin modélisé était UN par projet : le remodeler pour une couche changeait en silence les tuiles d'une
## autre au chargement suivant (sa source avait changé, donc elle était retranchée).
## `id` : un identifiant STABLE (le nom se change, et deux couches peuvent le porter), qui nomme ses fichiers.
## `poids`, `choix` : les VARIANTES VOULUES dans le monde de la couche (4 octobre 2026) — {clé: [base, var1, …]} et
## {sommet: rang} (la règle : `MB.tuile_du_sommet`). Les variantes elles-mêmes sont dans son témoin.
static func couche(nom: String, id := "") -> Dictionary:
	return {"nom": nom, "source": "", "visible": true, "cases": {}, "temoin": "", "id": id, "poids": {}, "choix": {}}


## UNE COUCHE D'EAU (Jordan, 1er octobre 2026) : l'eau appartient au monde entier, rangée dans ses PROPRES
## couches, indépendantes des couches de tuiles. ⚠ ON N'ENREGISTRE QUE LES SOURCES : lacs, rivières et océans
## s'en redéduisent (`fluides.gd`), comme le lot tranché se redéduit de sa source.
static func couche_d_eau(nom: String, id := "") -> Dictionary:
	return {"nom": nom, "visible": true, "preset": "stylise", "sources": [], "id": id}


## ⚠ LES CASES S'ÉCRIVENT D'UN BLOC (Jordan, 2 octobre 2026 : « trop d'algos lents pendant l'édition ») : sur
## l'exemple (194 692 cases), chaque enregistrement bâtissait un tableau de 584 076 nombres, que `JSON.stringify` posait
## UN PAR LIGNE (indenté) — 4,8 Mo, ~270 ms, et une image de ~0,9 s une seconde après chaque geste. Les cases passent
## par un `PackedInt32Array`, que le moteur écrit lui-même en « [x, y, z, …] » sur une ligne, à la place d'une marque
## dans le JSON. Même format, relu par `depuis_texte` à l'identique ; 2,5 Mo, ~100 ms.
## ⚠ PUIS EN BINAIRE (4 octobre 2026, version 2) : sur l'exemple de 739 481 cases, `str()` des 2,2 millions de nombres
## coûtait ~340 ms (~440 ms le texte entier), sur un autre fil qui attendait parfois 3 s de démarrer derrière les cartes
## PBR, et ~470 ms de plus sur le fil principal à sa reprise. Les cases sont les octets du `PackedInt32Array` (x, y, z
## à la suite, petit-boutiste) en base64, sous `cases_b64` : ~70 ms. Elles se relisent sans analyser 2,2 millions de
## nombres JSON. `cases` (version 1, un tableau de nombres) reste lu.
## `c["cases"]` : un dictionnaire {case: true} ou un tableau de cases (`GridMap.get_used_cells()`).
## `travaux` : les chemins des travaux importés (étape 2), dans l'ordre — la liste survit à la session (3 octobre 2026).
static func vers_texte(couches: Array, active: int, eaux: Array = [], travaux: Array = [],
		feuillage: Dictionary = {}) -> String:
	var sorties: Array = []
	var blocs: Array[String] = []
	for c in couches:
		var liste: Array = c["cases"].keys() if c["cases"] is Dictionary else c["cases"]
		var plat := PackedInt32Array()
		plat.resize(liste.size() * 3)
		var i := 0
		for p in liste:
			var v: Vector3i = p
			plat[i] = v.x
			plat[i + 1] = v.y
			plat[i + 2] = v.z
			i += 3
		# ⚠ UNE COUCHE VIDE S'ÉCRIT "" : `raw_to_base64` d'un tableau vide crie une erreur dans la console (vu le 4 octobre
		# 2026, à chaque enregistrement d'un projet neuf) ; "" se relit en zéro case.
		blocs.append("\"%s\"" % ("" if plat.is_empty() else Marshalls.raw_to_base64(plat.to_byte_array())))
		var sortie := {"nom": c["nom"], "source": c["source"],
			"visible": c["visible"], "cases_b64": MARQUE_CASES % (blocs.size() - 1), "temoin": str(c.get("temoin", "")),
			"id": str(c.get("id", ""))}
		var poids: Dictionary = c.get("poids", {})
		if not poids.is_empty():
			var p := {}
			for cle in poids:
				p[cle] = (poids[cle] as Array).map(func(w): return int(w))
			sortie["poids"] = p
		var choix: Dictionary = c.get("choix", {})
		if not choix.is_empty():
			var plat_choix: Array = []
			for s in choix:
				var v: Vector3i = s
				plat_choix.append_array([v.x, v.y, v.z, int(choix[s])])
			sortie["choix"] = plat_choix
		sorties.append(sortie)
	var sorties_eau: Array = []
	for e in eaux:
		var plat: Array = []
		for s in e["sources"]:
			var v: Vector3i = s
			plat.append_array([v.x, v.y, v.z])
		sorties_eau.append({"nom": e["nom"], "visible": e["visible"], "preset": e["preset"], "id": str(e["id"]),
			"sources": plat})
	var tout := {"format": FORMAT, "version": VERSION, "active": active, "couches": sorties, "eaux": sorties_eau}
	if not travaux.is_empty():
		tout["travaux"] = travaux.map(func(t): return str(t))
	# LE FEUILLAGE (6 octobre 2026) : ses modèles et ses plants (`feuillage.gd`). Absent tant qu'il est vide.
	if not feuillage.is_empty() and not (feuillage.get("modeles", []) as Array).is_empty():
		tout["feuillage"] = feuillage
	var texte := JSON.stringify(tout, "	")
	for k in blocs.size():
		texte = texte.replace("\"%s\"" % (MARQUE_CASES % k), blocs[k])
	return texte


## La marque d'un bloc de cases dans le JSON, remplacée par le bloc lui-même (`vers_texte`).
const MARQUE_CASES := "@@marchingblocks-cells-%d@@"


## Rend {"couches": [...], "active": int}, ou {} en ajoutant la raison à `erreurs`.
## ⚠ UN FICHIER ABÎMÉ EST REFUSÉ EN ENTIER, jamais à moitié lu : rouvrir un monde auquel il manque une
## couche sans le dire, c'est la perdre au prochain enregistrement automatique.
static func depuis_texte(texte: String, erreurs: Array) -> Dictionary:
	# ⚠ `JSON.new().parse` et non `JSON.parse_string` : celui-ci crie dans la console à chaque fichier
	# abîmé, alors que le refus est déjà DIT à l'utilisateur.
	# ⚠ LES CASES BINAIRES SONT SORTIES DU TEXTE AVANT L'ANALYSE (version 2) : l'analyseur JSON parcourt une chaîne
	# caractère par caractère, et ~12 Mo de base64 lui coûtaient plus que les nombres de la version 1. Chaque bloc est
	# remplacé par son rang, et rendu ensuite.
	var blocs := PackedStringArray()
	var marque := "\"cases_b64\":"
	var morceaux := PackedStringArray()
	var debut := 0     # le texte déjà recopié s'arrête ici
	var cherche := 0   # la prochaine marque se cherche à partir d'ici
	while true:
		var k := texte.find(marque, cherche)
		if k < 0:
			break
		var a := k + marque.length()
		while a < texte.length() and texte[a] in [" ", "\t", "\n", "\r"]:
			a += 1
		cherche = a
		if a >= texte.length() or texte[a] != "\"":
			continue   # pas un texte : laissé à l'analyse, qui le refusera
		a += 1
		var b := texte.find("\"", a)
		if b < 0:
			break
		morceaux.append(texte.substr(debut, a - debut))
		morceaux.append(str(blocs.size()))
		blocs.append(texte.substr(a, b - a))
		debut = b
		cherche = b
	if not blocs.is_empty():
		morceaux.append(texte.substr(debut))
		texte = "".join(morceaux)
	var json := JSON.new()
	var brut = json.data if json.parse(texte) == OK else null
	if not brut is Dictionary:
		erreurs.append("not a JSON object")
		return {}
	if brut.get("format", "") != FORMAT:
		erreurs.append("not a MarchingBlocks project")
		return {}
	if int(brut.get("version", 0)) > VERSION:
		erreurs.append("made by a newer MarchingBlocks (format %d)" % int(brut.get("version", 0)))
		return {}
	var liste = brut.get("couches", null)
	if not liste is Array or (liste as Array).is_empty():
		erreurs.append("no layer")
		return {}
	var couches: Array = []
	for i in (liste as Array).size():
		var c = liste[i]
		if not c is Dictionary:
			erreurs.append("layer %d is not an object" % i)
			return {}
		var plat = c.get("cases", [])
		if c.has("cases_b64"):
			# Version 2 : les octets d'un PackedInt32Array, en base64 (sorti du texte avant l'analyse : le JSON n'en
			# porte que le rang). Un texte qui n'en est pas rend un tableau vide (refusé s'il ne l'était pas) ; un
			# nombre d'entiers qui n'est pas un multiple de 3 est refusé plus bas, comme en version 1.
			var rang_bloc = c["cases_b64"]
			var b64: String = blocs[int(rang_bloc)] if rang_bloc is String and (rang_bloc as String).is_valid_int() 				and int(rang_bloc) < blocs.size() else ""
			var octets := Marshalls.base64_to_raw(b64) if b64 != "" else PackedByteArray()
			if not rang_bloc is String or (octets.is_empty() and b64 != ""):
				erreurs.append("layer %d: cells are not x, y, z triples" % i)
				return {}
			plat = octets.to_int32_array()
		elif not plat is Array:
			plat = null
		if plat == null or plat.size() % 3 != 0:
			erreurs.append("layer %d: cells are not x, y, z triples" % i)
			return {}
		var cases := {}
		if plat is PackedInt32Array:
			var entiers: PackedInt32Array = plat
			for k in range(0, entiers.size(), 3):
				cases[Vector3i(entiers[k], entiers[k + 1], entiers[k + 2])] = true
		else:
			for k in range(0, plat.size(), 3):
				cases[Vector3i(int(plat[k]), int(plat[k + 1]), int(plat[k + 2]))] = true
		# ⚠ Un projet d'avant le 30 septembre 2026 n'a ni `temoin` ni `id` : aucun témoin à la couche, et un
		# identifiant donné par l'écran à l'ouverture.
		# Les variantes (4 octobre 2026) : un projet d'avant n'en a pas ; une entrée malformée refuse le fichier.
		var poids_lu = c.get("poids", {})
		var poids := {}
		if not poids_lu is Dictionary:
			erreurs.append("layer %d: variant weights are not an object" % i)
			return {}
		for cle in poids_lu:
			var w = poids_lu[cle]
			if not w is Array or (w as Array).any(func(x): return not (x is float or x is int)):
				erreurs.append("layer %d: the weights of « %s » are not numbers" % [i, cle])
				return {}
			poids[str(cle)] = (w as Array).map(func(x): return int(x))
		var choix_lu = c.get("choix", [])
		if not choix_lu is Array or (choix_lu as Array).size() % 4 != 0:
			erreurs.append("layer %d: variant choices are not x, y, z, variant quadruples" % i)
			return {}
		var choix := {}
		for k in range(0, (choix_lu as Array).size(), 4):
			choix[Vector3i(int(choix_lu[k]), int(choix_lu[k + 1]), int(choix_lu[k + 2]))] = int(choix_lu[k + 3])
		couches.append({"nom": str(c.get("nom", "Layer %d" % (i + 1))), "source": str(c.get("source", "")),
			"visible": bool(c.get("visible", true)), "cases": cases, "temoin": str(c.get("temoin", "")),
			"id": str(c.get("id", "")), "poids": poids, "choix": choix})
	var active: int = clampi(int(brut.get("active", 0)), 0, couches.size() - 1)
	# Les couches d'eau : un projet d'avant le 1er octobre 2026 n'en a pas.
	var eaux: Array = []
	var liste_eau = brut.get("eaux", [])
	if not liste_eau is Array:
		erreurs.append("water layers are not a list")
		return {}
	for i in (liste_eau as Array).size():
		var e = liste_eau[i]
		if not e is Dictionary:
			erreurs.append("water layer %d is not an object" % i)
			return {}
		var plat = e.get("sources", [])
		if not plat is Array or (plat as Array).size() % 3 != 0:
			erreurs.append("water layer %d: sources are not x, y, z triples" % i)
			return {}
		var sources: Array = []
		for k in range(0, (plat as Array).size(), 3):
			sources.append(Vector3i(int(plat[k]), int(plat[k + 1]), int(plat[k + 2])))
		eaux.append({"nom": str(e.get("nom", "Water %d" % (i + 1))), "visible": bool(e.get("visible", true)),
			"preset": str(e.get("preset", "stylise")), "sources": sources, "id": str(e.get("id", ""))})
	# Les travaux importés (3 octobre 2026) : un projet d'avant n'en a pas ; une entrée qui n'est pas un texte est
	# écartée (ce n'est qu'une liste de raccourcis, pas du travail).
	var travaux: Array = []
	var liste_travaux = brut.get("travaux", [])
	if liste_travaux is Array:
		for t in liste_travaux:
			if t is String and t != "" and not travaux.has(t):
				travaux.append(t)
	# Le feuillage (6 octobre 2026) : un projet d'avant n'en a pas ; une entrée malformée refuse le fichier entier.
	var feuillage := FE.depuis_donnees(brut.get("feuillage", null), erreurs)
	if feuillage.is_empty():
		return {}
	return {"couches": couches, "active": active, "eaux": eaux, "travaux": travaux, "feuillage": feuillage}


## CE QUI DIT QUE LA SOURCE A CHANGÉ. Vide si elle n'existe pas (ou pas encore).
## ⚠ Le témoin ne change qu'avec le logiciel : sa version en fait partie.
## ⚠ Un projet d'avant le 29 septembre 2026 porte encore un champ « pbr » par couche : il est ignoré.
static func empreinte(source: String) -> String:
	if source == "":
		return ""
	if source == TEMOIN:
		return "witness|%s" % ProjectSettings.get_setting("application/config/version", "")
	if not FileAccess.file_exists(source):
		return ""
	# ⚠ LE CONTENU, PAS LA DATE : la date n'est précise qu'à la seconde, et deux enregistrements de même
	# taille dans la même seconde passeraient pour identiques.
	return FileAccess.get_md5(source)


static func chemin_cache(source: String) -> String:
	return "%s/%s.res" % [DOSSIER_CACHE, source.md5_text()]


## Met un lot tranché en cache, marqué de l'empreinte de sa source. Rend "" ou la raison d'un échec.
## `empreinte_` : celle du fichier dont le lot a été lu, relevée à ce moment-là (un lot écrit plus tard — `marquer` —
## garde l'empreinte de SA source, jamais celle d'un fichier réécrit depuis : un cache en retard se voit périmé).
static func mettre_en_cache(lot: MeshLibrary, source: String, empreinte_ := "") -> String:
	DirAccess.make_dir_recursive_absolute(DOSSIER_CACHE)
	marquer(lot, empreinte_ if empreinte_ != "" else empreinte(source))
	var e: int = ResourceSaver.save(lot, chemin_cache(source), ResourceSaver.FLAG_COMPRESS)
	return "" if e == OK else "cache not written (error %d)" % e


## Le lot marqué de l'empreinte de sa source, sans l'écrire (ce que lit l'étiquette de la liste des couches).
static func marquer(lot: MeshLibrary, e: String) -> void:
	lot.set_meta("empreinte", e)
	lot.set_meta("format_du_cache", FORMAT_DU_CACHE)


## Le lot en cache : {"lot": MeshLibrary ou null, "a_jour": bool}.
## ⚠ UN CACHE PÉRIMÉ EST QUAND MÊME RENDU, marqué `a_jour = false` : si le `.glb` a disparu, c'est
## tout ce qui reste de la couche, et l'appelant décide — retrancher si la source est là, sinon
## montrer le vieux lot en le DISANT.
static func lire_cache(source: String) -> Dictionary:
	var chemin := chemin_cache(source)
	if not FileAccess.file_exists(chemin):
		return {"lot": null, "a_jour": false}
	var lot := ResourceLoader.load(chemin, "", ResourceLoader.CACHE_MODE_IGNORE) as MeshLibrary
	if lot == null:
		return {"lot": null, "a_jour": false}
	var e: String = empreinte(source)
	return {"lot": lot, "a_jour": e != "" and str(lot.get_meta("empreinte", "")) == e
		and int(lot.get_meta("format_du_cache", 1)) == FORMAT_DU_CACHE}
