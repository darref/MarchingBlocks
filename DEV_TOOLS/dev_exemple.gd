extends RefCounted
##
## ÉDITER L'EXEMPLE PENDANT LE DÉVELOPPEMENT — DEMANDÉ PAR JORDAN (3 octobre 2026) : « un moyen qui ne se retrouve pas
## dans le produit final d'éditer l'exemple de monde pendant le dev et de le maintenir dans le soft — un projet
## sauvegardé à un emplacement du disque que tu remets comme l'exemple du soft à chaque fois ».
##
## ⚠ **CE FICHIER NE PART PAS DANS L'EXE** : `DEV_TOOLS/*` est exclu de l'export (`export_presets.cfg`). L'écran ne le
## charge que si l'appli tourne SANS modèle d'export (`OS.has_feature("template")` faux) ET avec `--dev-example` —
## lancée par `DEV_TOOLS/editer_l_exemple.cmd`. Les suites de tests (sans ce drapeau) ne le voient jamais : elles
## n'ouvriront pas le vrai projet source.
##
## **LA SOURCE** est un projet ordinaire, n'importe où sur le disque ; son chemin est écrit dans
## `~/.marchingblocks/exemple_source.txt` (HORS du dépôt, comme la clé). Sans ce fichier : `SOURCE_DEFAUT`.
## `prendre_l_exemple.gd` lit la même source : une seule réponse à « quel projet est l'exemple ».
##
## En mode dev, l'appli :
##   - ouvre la SOURCE au lancement (on l'édite pour de vrai, elle s'enregistre toute seule à sa place) ;
##   - la compte comme « l'exemple » (« Which world » coche The example, elle n'est jamais retenue comme ton monde) ;
##   - montre une section « DEV · EXAMPLE » : la source, Repack now, Use this project as the example, Open the source ;
##   - RÉEMBALLE `exemple/exemple.zip` à la fermeture si la source était ouverte (l'appli de dev suivante, et l'export,
##     livrent donc ce qu'on vient de faire).
## ⚠ `exemple/FIGE` arrête tout réemballage, ici comme à l'export.

const PrendreLExemple := preload("res://DEV_TOOLS/prendre_l_exemple.gd")
const SOURCE_DEFAUT := "C:/Users/jorda/Desktop/test.mbproj"
const ARCHIVE := "res://exemple/exemple.zip"
const FIGE := "res://exemple/FIGE"
const DRAPEAU := "--dev-example"

## Détournements pour la fumée : un pointeur et une archive JETABLES (jamais la vraie source, jamais le vrai zip).
static var pointeur_force := ""
static var archive_force := ""

var ecran: Control
var _etiquette: Label
var _source_ouverte := false


## Le fichier qui désigne la source : `~/.marchingblocks/exemple_source.txt`.
static func pointeur() -> String:
	if pointeur_force != "":
		return pointeur_force
	var maison := OS.get_environment("USERPROFILE")
	if maison == "":
		maison = OS.get_environment("HOME")
	return maison.replace("\\", "/").path_join(".marchingblocks").path_join("exemple_source.txt")


## Le projet source de l'exemple : celui que désigne `pointeur_` s'il existe, sinon `SOURCE_DEFAUT`.
static func source(pointeur_ := "") -> String:
	var p := pointeur_ if pointeur_ != "" else pointeur()
	if FileAccess.file_exists(p):
		var s := FileAccess.get_file_as_string(p).strip_edges().replace("\\", "/")
		if s != "":
			return s
	return SOURCE_DEFAUT


## Désigne `chemin` comme la source de l'exemple. Rend "" ou la raison.
static func designer(chemin: String, pointeur_ := "") -> String:
	var p := pointeur_ if pointeur_ != "" else pointeur()
	chemin = ProjectSettings.globalize_path(chemin).replace("\\", "/")
	if not FileAccess.file_exists(chemin):
		return "no such project: " + chemin
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return "cannot write " + p
	f.store_string(chemin + "\n")
	f.close()
	return ""


## Réemballe la source dans l'archive. Rend "" ou la raison (« figé » en est une).
static func reemballer(source_ := "", archive := ARCHIVE) -> String:
	if FileAccess.file_exists(FIGE):
		return "the example is frozen (exemple/FIGE) — nothing repacked"
	if archive == ARCHIVE and archive_force != "":
		archive = archive_force
	return PrendreLExemple.prendre(source_ if source_ != "" else source(), ProjectSettings.globalize_path(archive))


## Le mode dev est-il demandé ?
static func demande() -> bool:
	return not OS.has_feature("template") and (OS.get_cmdline_user_args().has(DRAPEAU)
		or OS.get_cmdline_args().has(DRAPEAU))


func _init(p_ecran: Control) -> void:
	ecran = p_ecran


## Le même chemin, écrit pareil (pour comparer).
static func meme(a: String, b: String) -> bool:
	return a != "" and b != "" and ProjectSettings.globalize_path(a).replace("\\", "/").simplify_path().to_lower() \
		== ProjectSettings.globalize_path(b).replace("\\", "/").simplify_path().to_lower()


## La section de la barre de gauche.
func panneau(Section: GDScript, bouton: Callable, texte: Callable) -> Control:
	var s: Control = Section.new("Dev · example", true, null)
	s.contenu.add_child(texte.call("DEV ONLY — not in the exported app. The example the app ships is repacked from "
		+ "this source when you close, and before every export.", 11, Color("e0a040")))
	_etiquette = texte.call("", 11, Color("b0b0b0"))
	s.contenu.add_child(_etiquette)
	s.contenu.add_child(bouton.call("Open the example source", "Opens the source project of the example, to edit it.",
		func() -> void: ecran.dev_ouvrir_la_source(), "ouvrir"))
	s.contenu.add_child(bouton.call("Use this project as the example", "The open project becomes the source of the "
		+ "example (written in ~/.marchingblocks/exemple_source.txt).", _designer_l_ouvert, "monde"))
	s.contenu.add_child(bouton.call("Repack the example now", "Writes exemple/exemple.zip from the source — what the "
		+ "app shows under « The example » and what the export ships.", reemballer_maintenant, "enregistrer"))
	dire()
	return s


func dire() -> void:
	if _etiquette != null:
		_etiquette.text = "source: " + source() + ("\n(frozen: exemple/FIGE)" if FileAccess.file_exists(FIGE) else "")


func _designer_l_ouvert() -> void:
	var r := designer(ecran.dev_projet_ouvert())
	dire()
	ecran.dev_dire("[color=#e0603c]Not changed:[/color] " + r if r != ""
		else "[b]This project is now the example source.[/b] Repack (or close the app) to ship it.")
	ecran.dev_suivre_la_source()


func reemballer_maintenant() -> void:
	ecran.dev_tout_ecrire()
	var debut := Time.get_ticks_msec()
	var r := reemballer()
	ecran.dev_dire(("[color=#e0603c]Example not repacked:[/color] " + r) if r != ""
		else "[b]Example repacked[/b] from %s (%.1f s). « The example » installs it under a new stamp." % [
			source().get_file(), (Time.get_ticks_msec() - debut) / 1000.0])


## À la fermeture : si la source a été ouverte pendant la session, on réemballe.
func a_la_fermeture(projet_ouvert: String) -> void:
	if not (_source_ouverte or meme(projet_ouvert, source())):
		return
	var r := reemballer()
	print("DEV · EXAMPLE : " + ("non réemballé — " + r if r != "" else "réemballé depuis " + source()))


func noter_ouverture(chemin: String) -> void:
	if meme(chemin, source()):
		_source_ouverte = true
