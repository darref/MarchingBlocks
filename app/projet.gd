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

const FORMAT := "marchingblocks-project"
const VERSION := 1
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
static func couche(nom: String, id := "") -> Dictionary:
	return {"nom": nom, "source": "", "visible": true, "cases": {}, "temoin": "", "id": id}


## UNE COUCHE D'EAU (Jordan, 1er octobre 2026) : l'eau appartient au monde entier, rangée dans ses PROPRES
## couches, indépendantes des couches de tuiles. ⚠ ON N'ENREGISTRE QUE LES SOURCES : lacs, rivières et océans
## s'en redéduisent (`fluides.gd`), comme le lot tranché se redéduit de sa source.
static func couche_d_eau(nom: String, id := "") -> Dictionary:
	return {"nom": nom, "visible": true, "preset": "stylise", "sources": [], "id": id}


static func vers_texte(couches: Array, active: int, eaux: Array = []) -> String:
	var sorties: Array = []
	for c in couches:
		var plat: Array = []
		for p in c["cases"]:
			var v: Vector3i = p
			plat.append_array([v.x, v.y, v.z])
		sorties.append({"nom": c["nom"], "source": c["source"],
			"visible": c["visible"], "cases": plat, "temoin": str(c.get("temoin", "")),
			"id": str(c.get("id", ""))})
	var sorties_eau: Array = []
	for e in eaux:
		var plat: Array = []
		for s in e["sources"]:
			var v: Vector3i = s
			plat.append_array([v.x, v.y, v.z])
		sorties_eau.append({"nom": e["nom"], "visible": e["visible"], "preset": e["preset"], "id": str(e["id"]),
			"sources": plat})
	return JSON.stringify({"format": FORMAT, "version": VERSION, "active": active, "couches": sorties,
		"eaux": sorties_eau}, "\t")


## Rend {"couches": [...], "active": int}, ou {} en ajoutant la raison à `erreurs`.
## ⚠ UN FICHIER ABÎMÉ EST REFUSÉ EN ENTIER, jamais à moitié lu : rouvrir un monde auquel il manque une
## couche sans le dire, c'est la perdre au prochain enregistrement automatique.
static func depuis_texte(texte: String, erreurs: Array) -> Dictionary:
	# ⚠ `JSON.new().parse` et non `JSON.parse_string` : celui-ci crie dans la console à chaque fichier
	# abîmé, alors que le refus est déjà DIT à l'utilisateur.
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
		if not plat is Array or (plat as Array).size() % 3 != 0:
			erreurs.append("layer %d: cells are not x, y, z triples" % i)
			return {}
		var cases := {}
		for k in range(0, (plat as Array).size(), 3):
			cases[Vector3i(int(plat[k]), int(plat[k + 1]), int(plat[k + 2]))] = true
		# ⚠ Un projet d'avant le 30 septembre 2026 n'a ni `temoin` ni `id` : aucun témoin à la couche, et un
		# identifiant donné par l'écran à l'ouverture.
		couches.append({"nom": str(c.get("nom", "Layer %d" % (i + 1))), "source": str(c.get("source", "")),
			"visible": bool(c.get("visible", true)), "cases": cases, "temoin": str(c.get("temoin", "")),
			"id": str(c.get("id", ""))})
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
	return {"couches": couches, "active": active, "eaux": eaux}


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
static func mettre_en_cache(lot: MeshLibrary, source: String) -> String:
	DirAccess.make_dir_recursive_absolute(DOSSIER_CACHE)
	lot.set_meta("empreinte", empreinte(source))
	lot.set_meta("format_du_cache", FORMAT_DU_CACHE)
	var e: int = ResourceSaver.save(lot, chemin_cache(source), ResourceSaver.FLAG_COMPRESS)
	return "" if e == OK else "cache not written (error %d)" % e


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
