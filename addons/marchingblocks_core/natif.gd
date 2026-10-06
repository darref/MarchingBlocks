@tool
extends RefCounted
## LE CŒUR NATIF (C++, GDExtension) — le pont. Voir `gdextension/` et la charte (§0, « le cœur C++ »).
##
## ⚠ LE GDSCRIPT RESTE LA RÉFÉRENCE. Chaque fonction accélérée garde son corps GDScript : il sert quand la
## bibliothèque native manque (une plateforme sans binaire, un checkout sans build) et il est l'attendu de
## `DEV_TOOLS/test_natif.gd`, qui exige la MÊME sortie, clé pour clé, dans le même ordre. Le natif ne décide
## rien : la table des 256 configurations lui est donnée par `marching_blocks.gd` (`MB.natif()`).
##
## ⚠ `actif` à faux rend le GDScript partout (les tests, et la variable d'environnement MB_NATIF=0 pour
## comparer à la main). Le changer en cours de session vaut pour les appels SUIVANTS seulement : un massif déjà
## reconstruit garde ce qu'il a posé (même sortie, de toute façon).

const CHEMIN := "res://addons/marchingblocks_core/natif/marchingblocks_natif.gdextension"
const CLASSE := "MBNatif"

static var actif := OS.get_environment("MB_NATIF") != "0"
static var _noyau = null
static var _essaye := false


## Le cœur natif, ou null (éteint, ou bibliothèque absente). Chargé une fois.
static func noyau() -> Variant:
	if not actif:
		return null
	if not _essaye:
		_essaye = true
		_noyau = _charger()
	return _noyau


## La bibliothèque est-elle là (même éteinte) ?
static func disponible() -> bool:
	if not _essaye:
		_essaye = true
		_noyau = _charger()
	return _noyau != null


static func _charger() -> Variant:
	# L'éditeur et l'exe la chargent d'eux-mêmes (`extension_list.cfg`) ; un script lancé par `--script` sur un
	# projet jamais ouvert dans l'éditeur, non : on la charge à la main.
	if not ClassDB.class_exists(CLASSE):
		if not FileAccess.file_exists(CHEMIN):
			return null
		var statut := GDExtensionManager.load_extension(CHEMIN)
		if statut != GDExtensionManager.LOAD_STATUS_OK and statut != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
			push_warning("Le cœur natif ne s'est pas chargé (%d) : le GDScript prend la main." % statut)
			return null
	if not ClassDB.class_exists(CLASSE):
		return null
	return ClassDB.instantiate(CLASSE)
