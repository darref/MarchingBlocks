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

