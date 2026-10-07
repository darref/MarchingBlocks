extends Node
## LA VÉRIFICATION DES MISES À JOUR — édition SITE seulement (Steam livre les siennes). Stratégie de lancement,
## « Mises à jour et licence » : au lancement, l'appli lit un petit JSON sur le site ; si une version plus récente
## existe, la barre de titre le DIT, discrètement ; rien ne se télécharge sans l'acheteur (le lien ouvre « My
## downloads »). Désactivable dans Project. ⚠ JAMAIS BLOQUANTE : hors ligne, site absent, réponse fausse — on se tait.
##
## Le JSON (à poser sur le site à chaque version) :
##   {"version": "0.9.1", "date": "2027-02-12", "notes": "https://…/notes/0.9.1", "download": "https://…/my-downloads"}

## ⚠ À REMPLIR LE JOUR OÙ LE DOMAINE EXISTE (il attend l'argent, charte §0). Tant qu'elle porte « A-REMPLIR »,
## rien ne part sur le réseau, et l'export le rappelle.
const URL := "https://A-REMPLIR.example/marchingblocks/latest.json"
const SECONDES_MAXI := 6.0
const REGLAGES := "user://reglages.cfg"

## Émis quand une version plus récente existe : (version, lien à ouvrir).
signal disponible(version: String, lien: String)

var _requete: HTTPRequest


static func url_remplie(url := URL) -> bool:
	return url.begins_with("https://") and not url.contains("A-REMPLIR")


## La vérification est-elle voulue ? Oui par défaut ; la case de Project la coupe.
static func voulue(reglages_chemin := REGLAGES) -> bool:
	var r := ConfigFile.new()
	r.load(reglages_chemin)
	return bool(r.get_value("mises_a_jour", "verifier", true))


static func regler(oui: bool, reglages_chemin := REGLAGES) -> void:
	var r := ConfigFile.new()
	r.load(reglages_chemin)
	r.set_value("mises_a_jour", "verifier", oui)
	r.save(reglages_chemin)


## "0.9.10" contre "0.9.9" : les NOMBRES se comparent, pas le texte. Un suffixe (« -beta ») est ignoré ; une partie
## manquante vaut 0. Vrai si `distante` est STRICTEMENT plus récente que `locale`.
static func plus_recente(distante: String, locale: String) -> bool:
	var a := _nombres(distante)
	var b := _nombres(locale)
	if a.is_empty() or b.is_empty():
		return false
	for k in maxi(a.size(), b.size()):
		var x: int = a[k] if k < a.size() else 0
		var y: int = b[k] if k < b.size() else 0
		if x != y:
			return x > y
	return false


static func _nombres(v: String) -> Array:
	var tete := v.strip_edges().trim_prefix("v").split("-")[0].split("+")[0]
	var sortie: Array = []
	for p in tete.split("."):
		if not p.is_valid_int():
			return []
		sortie.append(int(p))
	return sortie


## Ce que dit la réponse du site : {"version", "lien"} si elle annonce plus récent que `locale`, {} sinon (réponse
## fausse comprise). ⚠ LE LIEN N'EST GARDÉ QUE S'IL EST EN https : un JSON détourné n'ouvrira pas n'importe quoi.
static func lire_la_reponse(texte: String, locale: String) -> Dictionary:
	var j := JSON.new()   # (pas `JSON.parse_string` : une page d'erreur l'écrirait en rouge dans la console)
	if j.parse(texte) != OK:
		return {}
	var d: Variant = j.data
	if not d is Dictionary or not (d as Dictionary).has("version"):
		return {}
	var version := str(d["version"])
	if not plus_recente(version, locale):
		return {}
	var lien := str(d.get("download", d.get("notes", "")))
	if not lien.begins_with("https://"):
		lien = ""
	return {"version": version, "lien": lien}


## Lance la vérification (une requête, sur le réseau, sans attendre) si elle est voulue et l'URL remplie.
## Rend vrai si une requête est partie.
func lancer(locale: String, url := URL) -> bool:
	if not url_remplie(url) or not voulue():
		return false
	_requete = HTTPRequest.new()
	_requete.timeout = SECONDES_MAXI
	add_child(_requete)
	_requete.request_completed.connect(func(resultat: int, code: int, _entetes: PackedStringArray,
			corps: PackedByteArray) -> void:
		_requete.queue_free()
		if resultat != HTTPRequest.RESULT_SUCCESS or code != 200:
			return   # hors ligne, site absent : on se tait
		var r := lire_la_reponse(corps.get_string_from_utf8(), locale)
		if not r.is_empty():
			disponible.emit(r["version"], r["lien"]))
	return _requete.request(url) == OK
