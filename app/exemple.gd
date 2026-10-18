extends RefCounted
##
## L'EXEMPLE LIVRÉ — DÉCIDÉ (Jordan, 2 octobre 2026) : « un mode Exemple qui garde le projet
## C:/Users/jorda/Desktop/test.mbproj et continue de le mettre à jour avec les modifications que je vais continuer de
## faire tant que le dev n'est pas clos, figé ensuite ».
##
## `DEV_TOOLS/prendre_l_exemple.gd` emballe ce projet et ses fichiers (témoins, leurs `.glb`, leurs images) dans
## `res://exemple/exemple.zip`, à chaque export de l'exe, tant que `res://exemple/FIGE` n'existe pas. Les chemins
## absolus y sont remplacés par `MARQUE` ; l'installation les remet, vers le dossier où elle écrit.
##
## ⚠ **UNE INSTALLATION PAR VERSION DE L'EXEMPLE, JAMAIS ÉCRASÉE** : l'exemple s'ouvre comme un projet ordinaire et
## s'enregistre tout seul (§5). Le réinstaller par-dessus perdrait ce que l'utilisateur y a fait ; un exemple plus
## récent (un autre `STAMP`) va dans un autre dossier.

const Projet := preload("res://app/projet.gd")
const MisesAJour := preload("res://app/mises_a_jour.gd")
## L'archive EMBARQUÉE : en développement seulement depuis le 18 octobre 2026 (l'export ne la prend plus, voir plus bas).
const ARCHIVE := "res://exemple/exemple.zip"
const MARQUE := "{EXEMPLE}"
const RACINE := "user://example"
## Les fichiers texte dont les chemins sont réécrits. Les autres (.glb, .png) sont copiés tels quels.
const TEXTES := ["mbproj", "mbtiles"]


static func disponible(archive := ARCHIVE) -> bool:
	return FileAccess.file_exists(archive)


## Installe l'exemple (s'il ne l'est pas déjà) et rend le chemin ABSOLU de son `.mbproj` ; "" en ajoutant la raison
## à `erreurs`.
static func installer(archive := ARCHIVE, racine := RACINE, erreurs: Array = []) -> String:
	var z := ZIPReader.new()
	if z.open(archive) != OK:
		erreurs.append("the example is not in this build")
		return ""
	var fichiers := z.get_files()
	var marque := z.read_file("STAMP").get_string_from_utf8().strip_edges() if fichiers.has("STAMP") else ""
	var nom_projet := ""
	for f in fichiers:
		if f.get_extension() == Projet.EXTENSION:
			nom_projet = f
	if marque == "" or nom_projet == "":
		z.close()
		erreurs.append("the example archive is incomplete")
		return ""
	var dossier := ProjectSettings.globalize_path(racine).path_join(marque.substr(0, 12))
	var projet := dossier.path_join(nom_projet)
	if FileAccess.file_exists(projet):
		z.close()
		return projet
	for f in fichiers:
		if f == "STAMP" or f.ends_with("/"):
			continue
		var cible := dossier.path_join(f)
		DirAccess.make_dir_recursive_absolute(cible.get_base_dir())
		var octets := z.read_file(f)
		if TEXTES.has(f.get_extension()):
			octets = octets.get_string_from_utf8().replace(MARQUE, dossier).to_utf8_buffer()
		var sortie := FileAccess.open(cible, FileAccess.WRITE)
		if sortie == null:
			z.close()
			erreurs.append("cannot write %s" % cible)
			return ""
		sortie.store_buffer(octets)
		sortie.close()
	z.close()
	return projet


## ⚠ **UN EXEMPLE DÉCOMPRESSÉ À LA MAIN** (18 octobre 2026 : la 0.9.4 installée n'ouvrait pas l'île cartoon dézippée sur
## le Bureau — 17 couches en cubes rouges, « {EXEMPLE}/… is missing ») : ses chemins disent encore `MARQUE`. On fait sur
## place ce que fait `installer` : chaque `.mbproj` et `.mbtiles` du dossier du projet pointe vers ce dossier. Rend le
## nombre de fichiers réécrits (0 pour un projet ordinaire, qui n'est pas touché).
static func installer_sur_place(projet: String) -> int:
	if not FileAccess.get_file_as_string(projet).contains(MARQUE):
		return 0
	var dossier := projet.get_base_dir()
	var n := 0
	for f in DirAccess.get_files_at(dossier):
		if not TEXTES.has(f.get_extension()):
			continue
		var chemin := dossier.path_join(f)
		var texte := FileAccess.get_file_as_string(chemin)
		if not texte.contains(MARQUE):
			continue
		var sortie := FileAccess.open(chemin, FileAccess.WRITE)
		if sortie == null:
			continue
		sortie.store_string(texte.replace(MARQUE, dossier))
		sortie.close()
		n += 1
	return n



# ── L'EXEMPLE TÉLÉCHARGÉ — DÉCIDÉ (Jordan, 18 octobre 2026 : « passer l'exemple fourni avec le soft en téléchargeable
# depuis le soft ouvert avec un bouton », hébergé « dans SpannerGames ») ──────────────────────────────────────────────
# L'exe ne l'embarque plus (234 Mo sur 335). Le bouton « Example world » lit `example.json` sur le site, à côté de
# `latest.json` (même domaine : une seule URL à remplir, `MisesAJour.URL`), télécharge le zip qu'il nomme, vérifie sa
# TAILLE et son SHA-256, le garde dans `TELECHARGEE`, puis l'installe comme avant. Une fois téléchargé, il ne se
# retélécharge plus. Hors ligne, ou le site pas encore en ligne : « Open… » accepte aussi un zip d'exemple téléchargé à
# la main (la page itch.io de la démo le propose à côté de l'exe).

const TELECHARGEE := "user://example/example.zip"
## La plus grosse archive acceptée (une réponse détournée ne remplira pas le disque).
const TAILLE_MAXI := 1024 * 1024 * 1024


static func url_description(url_maj := MisesAJour.URL) -> String:
	return url_maj.get_base_dir() + "/example.json"


## L'archive à installer sans réseau : l'embarquée (développement), sinon celle déjà téléchargée ; "" sinon.
static func archive_locale() -> String:
	if disponible(ARCHIVE):
		return ARCHIVE
	return TELECHARGEE if FileAccess.file_exists(TELECHARGEE) else ""


## Ce que dit `example.json` : {"url", "taille", "sha256"}, ou {} si la réponse est fausse. ⚠ L'URL n'est gardée qu'en
## https, l'empreinte qu'en 64 chiffres hexadécimaux, la taille qu'entre 1 octet et `TAILLE_MAXI`.
static func lire_la_description(texte: String) -> Dictionary:
	var j := JSON.new()   # (pas `JSON.parse_string` : une page d'erreur l'écrirait en rouge dans la console)
	if j.parse(texte) != OK or not j.data is Dictionary:
		return {}
	var d: Dictionary = j.data
	var url := str(d.get("url", ""))
	var sha := str(d.get("sha256", "")).to_lower()
	var taille: Variant = d.get("size", 0)
	if not url.begins_with("https://") or sha.length() != 64 or not sha.is_valid_hex_number() 			or not (taille is float or taille is int) or int(taille) <= 0 or int(taille) > TAILLE_MAXI:
		return {}
	return {"url": url, "taille": int(taille), "sha256": sha}


## Le fichier reçu est-il celui que la description annonce ?
static func conforme(chemin: String, description: Dictionary) -> bool:
	if not FileAccess.file_exists(chemin):
		return false
	var f := FileAccess.open(chemin, FileAccess.READ)
	var taille := f.get_length() if f != null else -1
	if f != null:
		f.close()
	return taille == int(description["taille"]) and FileAccess.get_sha256(chemin) == str(description["sha256"])
