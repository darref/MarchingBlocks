extends SceneTree
##
## TEST — le projet et ses couches (`app/projet.gd`), et la grille locale de la vue (`app/vue.gd`).
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_projet.gd
##
## ⚠ **CE QUI EST GARDÉ, C'EST CE QU'ON PERDRAIT SANS LE VOIR** : un monde qui revient avec une case en
## moins, un fichier abîmé lu à moitié puis réécrit par l'enregistrement automatique, un lot en cache
## cru à jour alors que l'artiste a réenregistré son `.glb`. Les attendus sont écrits à la main.

const Projet := preload("res://app/projet.gd")
const Vue := preload("res://app/vue.gd")

const DOSSIER := "user://test_projet"

var _ok := 0
var _echecs := 0


func _initialize() -> void:
	print("=== TEST — le projet et ses couches ===\n")
	DirAccess.make_dir_recursive_absolute(DOSSIER)

	# ── 1. L'aller-retour d'un projet à deux couches ──────────────────────────────────────────────
	var roche := Projet.couche("Roche")
	roche["source"] = Projet.TEMOIN
	roche["cases"] = {Vector3i(0, 0, 0): true, Vector3i(-3, 2, 41): true, Vector3i(100, -7, -64): true}
	var glace := Projet.couche("Glace")
	glace["source"] = "D:/quelque/part/glace.glb"
	glace["visible"] = false
	var texte := Projet.vers_texte([roche, glace], 1)
	var erreurs: Array = []
	var relu: Dictionary = Projet.depuis_texte(texte, erreurs)
	_vrai(erreurs.is_empty(), "un projet bien formé se relit sans erreur")
	_egal(relu.get("active", -1), 1, "la couche active revient")
	var couches: Array = relu.get("couches", [])
	_egal(couches.size(), 2, "les deux couches reviennent")
	if couches.size() == 2:
		_egal(couches[0]["nom"], "Roche", "le nom revient")
		_egal(couches[0]["source"], "witness", "la source témoin revient")
		_egal(couches[1]["visible"], false, "une couche cachée reste cachée")
		_egal(couches[1]["source"], "D:/quelque/part/glace.glb", "le chemin du travail revient")
		var cases: Dictionary = couches[0]["cases"]
		_egal(cases.size(), 3, "les trois cases reviennent, pas une de plus")
		for p in [Vector3i(0, 0, 0), Vector3i(-3, 2, 41), Vector3i(100, -7, -64)]:
			_vrai(cases.has(p), "la case %s revient À SA PLACE (coordonnées négatives comprises)" % p)
		_egal(couches[1]["cases"].size(), 0, "une couche vide revient vide")

	# ── 2. Un fichier abîmé est refusé EN ENTIER ─────────────────────────────────────────────────
	for cas in [
		["pas du json {", "du texte qui n'est pas du JSON"],
		['{"format": "autre", "version": 1, "couches": [{}]}', "un autre format"],
		['{"format": "marchingblocks-project", "version": 99, "couches": [{}]}', "une version plus récente"],
		['{"format": "marchingblocks-project", "version": 1, "couches": []}', "aucune couche"],
		['{"format": "marchingblocks-project", "version": 1, "couches": [{"cases": [1, 2]}]}',
			"des cases qui ne sont pas des triplets"],
		['{"format": "marchingblocks-project", "version": 1, "couches": [{"nom": "a"}, 3]}',
			"une couche qui n'est pas un objet — même après une couche saine"],
	]:
		var e: Array = []
		_vrai(Projet.depuis_texte(cas[0], e).is_empty() and not e.is_empty(), "refusé, avec sa raison : %s" % cas[1])

	var e2: Array = []
	var borne: Dictionary = Projet.depuis_texte(
		'{"format": "marchingblocks-project", "version": 1, "active": 9, "couches": [{}, {}]}', e2)
	_egal(borne.get("active", -1), 1, "une couche active hors de la liste est ramenée dans la liste")

	# ── 3. Le cache n'est cru que si la source n'a pas changé ────────────────────────────────────
	var source := DOSSIER + "/travail.glb"
	_ecrire(source, "premiere version")
	var lot := MeshLibrary.new()
	lot.create_item(0)
	lot.set_item_name(0, "mb_essai")
	_egal(Projet.mettre_en_cache(lot, source), "", "le lot s'écrit en cache")
	var lu: Dictionary = Projet.lire_cache(source)
	_vrai(lu["lot"] != null and lu["a_jour"], "relu aussitôt, le cache est à jour")
	if lu["lot"] != null:
		_egal((lu["lot"] as MeshLibrary).get_item_name(0), "mb_essai", "le cache rend le même lot")
	# Un cache d'avant la provenance (format 1) : même source, même empreinte, mais PÉRIMÉ — sinon « d'où
	# vient cette tuile ? » resterait muet sur un lot qui ne sait pas le dire.
	var ancien := MeshLibrary.new()
	ancien.set_meta("empreinte", Projet.empreinte(source))
	ResourceSaver.save(ancien, Projet.chemin_cache(source), ResourceSaver.FLAG_COMPRESS)
	_vrai(not Projet.lire_cache(source)["a_jour"], "un cache d'un format plus ancien est PÉRIMÉ")
	Projet.mettre_en_cache(lot, source)

	# Réenregistrer le fichier change sa taille : l'empreinte doit bouger.
	_ecrire(source, "seconde version, plus longue")
	lu = Projet.lire_cache(source)
	_vrai(not lu["a_jour"], "le travail réenregistré rend le cache PÉRIMÉ")
	_vrai(lu["lot"] != null, "un cache périmé est quand même rendu — c'est tout ce qui reste si la source part")

	DirAccess.remove_absolute(source)
	_egal(Projet.empreinte(source), "", "une source disparue n'a pas d'empreinte")
	_vrai(not Projet.lire_cache(source)["a_jour"], "une source disparue n'est jamais « à jour »")
	_egal(Projet.empreinte(""), "", "une couche sans source n'a pas d'empreinte")
	DirAccess.remove_absolute(Projet.chemin_cache(source))

	# ── 4. La grille locale : où s'arrête la grille centrale ─────────────────────────────────────
	# DEMI_GRILLE = 24 : lignes de −24 à +24, donc cases de −24 à 23.
	_vrai(Vue.sur_la_grille_centrale(Vector3i(0, 0, 0)), "le centre est sur la grille centrale")
	_vrai(Vue.sur_la_grille_centrale(Vector3i(-24, 3, 23)), "la case −24 / 23 est la dernière couverte")
	_vrai(not Vue.sur_la_grille_centrale(Vector3i(24, 0, 0)), "la case 24 en x déborde : grille locale")
	_vrai(not Vue.sur_la_grille_centrale(Vector3i(0, 0, -25)), "la case −25 en z déborde : grille locale")

	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	print("VERDICT : %s" % ("OK" if _echecs == 0 else "ÉCHEC"))
	quit(0 if _echecs == 0 else 1)


func _ecrire(chemin: String, texte: String) -> void:
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string(texte)
	f.close()


func _vrai(v: bool, quoi: String) -> void:
	if v:
		_ok += 1
	else:
		_echecs += 1
		print("  ✗ " + quoi)


func _egal(a, b, quoi: String) -> void:
	if a == b:
		_ok += 1
	else:
		_echecs += 1
		print("  ✗ %s — rendu %s, attendu %s" % [quoi, a, b])
