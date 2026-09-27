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

## La source « témoin calculé ». Toute autre source non vide est un chemin de `.glb`.
const TEMOIN := "witness"


## Une couche neuve : aucune source, aucune case.
static func couche(nom: String) -> Dictionary:
	return {"nom": nom, "source": "", "pbr": false, "visible": true, "cases": {}}


static func vers_texte(couches: Array, active: int) -> String:
	var sorties: Array = []
	for c in couches:
		var plat: Array = []
		for p in c["cases"]:
			var v: Vector3i = p
			plat.append_array([v.x, v.y, v.z])
		sorties.append({"nom": c["nom"], "source": c["source"], "pbr": c["pbr"],
			"visible": c["visible"], "cases": plat})
	return JSON.stringify({"format": FORMAT, "version": VERSION, "active": active, "couches": sorties},
		"\t")


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
		couches.append({"nom": str(c.get("nom", "Layer %d" % (i + 1))), "source": str(c.get("source", "")),
			"pbr": bool(c.get("pbr", false)), "visible": bool(c.get("visible", true)), "cases": cases})
	var active: int = clampi(int(brut.get("active", 0)), 0, couches.size() - 1)
	return {"couches": couches, "active": active}


## CE QUI DIT QUE LA SOURCE A CHANGÉ. Vide si elle n'existe pas (ou pas encore).
## ⚠ Le témoin ne change qu'avec le logiciel : sa version en fait partie. Le PBR aussi, puisque le
## matériau est posé AVANT le tranchage et part dans chaque tuile.
static func empreinte(source: String, pbr: bool) -> String:
	if source == "":
		return ""
	if source == TEMOIN:
		return "witness|%s|%s" % [pbr, ProjectSettings.get_setting("application/config/version", "")]
	if not FileAccess.file_exists(source):
		return ""
	# ⚠ LE CONTENU, PAS LA DATE : la date n'est précise qu'à la seconde, et deux enregistrements de même
	# taille dans la même seconde passeraient pour identiques.
	return FileAccess.get_md5(source)


static func chemin_cache(source: String, pbr: bool) -> String:
	return "%s/%s.res" % [DOSSIER_CACHE, ("%s|%s" % [source, pbr]).md5_text()]


## Met un lot tranché en cache, marqué de l'empreinte de sa source. Rend "" ou la raison d'un échec.
static func mettre_en_cache(lot: MeshLibrary, source: String, pbr: bool) -> String:
	DirAccess.make_dir_recursive_absolute(DOSSIER_CACHE)
	lot.set_meta("empreinte", empreinte(source, pbr))
	var e: int = ResourceSaver.save(lot, chemin_cache(source, pbr), ResourceSaver.FLAG_COMPRESS)
	return "" if e == OK else "cache not written (error %d)" % e


## Le lot en cache : {"lot": MeshLibrary ou null, "a_jour": bool}.
## ⚠ UN CACHE PÉRIMÉ EST QUAND MÊME RENDU, marqué `a_jour = false` : si le `.glb` a disparu, c'est
## tout ce qui reste de la couche, et l'appelant décide — retrancher si la source est là, sinon
## montrer le vieux lot en le DISANT.
static func lire_cache(source: String, pbr: bool) -> Dictionary:
	var chemin := chemin_cache(source, pbr)
	if not FileAccess.file_exists(chemin):
		return {"lot": null, "a_jour": false}
	var lot := ResourceLoader.load(chemin, "", ResourceLoader.CACHE_MODE_IGNORE) as MeshLibrary
	if lot == null:
		return {"lot": null, "a_jour": false}
	var e: String = empreinte(source, pbr)
	return {"lot": lot, "a_jour": e != "" and str(lot.get_meta("empreinte", "")) == e}
