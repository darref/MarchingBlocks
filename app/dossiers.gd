extends RefCounted
##
## OÙ L'APPLI RANGE CE QU'ELLE CRÉE D'ELLE-MÊME — DÉCIDÉ (Jordan, 4 octobre 2026) : « que l'exe crée un dossier simple
## dans Documents pour y mettre tous les fichiers qu'il crée automatiquement, pour rester propre ».
##
## `Documents/MarchingBlocks/` reçoit ce qui est à l'utilisateur : chaque projet neuf DANS SON DOSSIER
## (`untitled/untitled.mbproj` et ses témoins à côté de lui), et l'exemple installé (`Example/`). Ils s'empilaient en
## vrac dans les données de l'appli (AppData), cachés, mêlés au reste.
## ⚠ **LE CACHE, LES RÉGLAGES ET LES ICÔNES RESTENT DANS LES DONNÉES DE L'APPLI** (`user://`) : c'est la convention de
## Windows, et Documents est souvent synchronisé par OneDrive — un cache de plusieurs Mo y repartirait à chaque
## tranchage.
## ⚠ **SEULEMENT DANS L'EXE** (`OS.has_feature("template")`, comme les associations de fichiers) : depuis l'éditeur ou
## les suites, l'appli écrirait dans les Documents du développeur ; elle reste alors dans `user://`.

const NOM := "MarchingBlocks"
const EXEMPLE := "Example"

## La fumée la détourne vers un dossier jetable.
static var racine_forcee := ""


## La règle, pure : dans l'exe, `<Documents>/MarchingBlocks` ; ailleurs (ou sans dossier Documents), `user://`.
static func racine_pour(exe: bool, documents: String) -> String:
	if exe and documents != "":
		return documents.replace("\\", "/").path_join(NOM)
	return "user://"


## Le dossier des projets neufs et de l'exemple.
static func racine() -> String:
	if racine_forcee != "":
		return racine_forcee
	return racine_pour(OS.has_feature("template"), OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS))


## Où l'exemple s'installe : `<racine>/Example` dans l'exe, `user://example` ailleurs (l'ancienne place).
static func exemple() -> String:
	var r := racine()
	return "user://example" if r == "user://" else r.path_join(EXEMPLE)


## Un projet neuf libre, chacun dans son dossier : `<racine>/untitled/untitled.mbproj`, puis `untitled 2/…`. Le dossier
## est créé. "" si rien ne peut être écrit.
static func projet_libre(extension: String, racine_ := "") -> String:
	var base := racine_ if racine_ != "" else racine()
	for n in range(1, 10000):
		var nom := "untitled" if n == 1 else "untitled %d" % n
		var dossier := base.path_join(nom)
		if DirAccess.dir_exists_absolute(dossier) or FileAccess.file_exists(base.path_join(nom + "." + extension)):
			continue
		if DirAccess.make_dir_recursive_absolute(dossier) != OK:
			return ""
		return dossier.path_join(nom + "." + extension)
	return ""
