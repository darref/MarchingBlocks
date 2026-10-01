extends RefCounted
## LES FICHIERS DE MARCHINGBLOCKS DANS WINDOWS — leurs icônes, et le double-clic qui ouvre un projet.
##
## **DÉCIDÉ (Jordan, 30 septembre 2026)** : « au premier lancement, double-clic oui, dossiers aussi ».
##   • `.mbproj` (le projet) : son icône, et un double-clic l'ouvre dans MarchingBlocks ;
##   • `.mbtiles` (le témoin d'une couche) : son icône (il ne s'ouvre pas seul : c'est son projet qu'on ouvre) ;
##   • les DOSSIERS `.mbset/` et `.mbworld/` : leur icône, par un `desktop.ini` posé dedans à l'export.
## ⚠ **UNE ICÔNE DE FICHIER NE VIENT PAS DU FICHIER, MAIS DU REGISTRE** (extension → type → icône). Le logiciel est
## vendu en UN exécutable, sans installateur : il s'inscrit donc LUI-MÊME, dans la partie du registre propre à
## l'utilisateur (HKEY_CURRENT_USER — jamais HKEY_LOCAL_MACHINE : ni droits d'administrateur, ni autres
## comptes touchés), au premier lancement, et de nouveau si l'exécutable a changé de place ou de version.
## ⚠ **PAR UN FICHIER `.reg` EN UTF-16**, importé par `reg import` : passer les valeurs en arguments de `reg add`
## aurait remis les guillemets et les « %1 » à la merci de la citation de la ligne de commande, et un chemin
## accentué (un prénom dans `C:\Users\…`) exige l'Unicode.
## ⚠ Les icônes sont des PNG de la marque (`MARQUE/generer_icones_fichiers.py`) convertis en `.ico` dans le
## dossier de données de l'appli : un `.ico` n'est pas une ressource que l'export emporterait.
## Tout ce qui se calcule est une fonction PURE (gardée par `test_projet`) ; seul `inscrire` touche au système.

const RACINE := "HKEY_CURRENT_USER\\Software\\Classes"
const TYPES := [
	{"ext": ".mbproj", "id": "MarchingBlocks.Project", "nom": "MarchingBlocks project",
		"png": "res://MARQUE/fichier_projet.png", "ico": "projet.ico", "ouvrir": true},
	{"ext": ".mbtiles", "id": "MarchingBlocks.Witness", "nom": "MarchingBlocks layer witness",
		"png": "res://MARQUE/fichier_temoin.png", "ico": "temoin.ico", "ouvrir": false},
]
const DOSSIERS := {
	"mbset": {"png": "res://MARQUE/dossier_tuiles.png", "ico": "dossier_tuiles.ico"},
	"mbworld": {"png": "res://MARQUE/dossier_monde.png", "ico": "dossier_monde.ico"},
}
const TAILLES := [256, 48, 32, 16]


## UN `.ico` fait d'images PNG (une par taille) — le format que Windows lit depuis Vista.
static func ico_depuis_image(img: Image) -> PackedByteArray:
	var pngs: Array = []
	for t in TAILLES:
		var copie := img.duplicate() as Image
		copie.convert(Image.FORMAT_RGBA8)
		copie.resize(t, t, Image.INTERPOLATE_LANCZOS)
		pngs.append(copie.save_png_to_buffer())
	var sortie := PackedByteArray()
	sortie.append_array(_u16(0))
	sortie.append_array(_u16(1))
	sortie.append_array(_u16(pngs.size()))
	var decalage: int = 6 + 16 * pngs.size()
	for k in pngs.size():
		var t: int = TAILLES[k]
		sortie.append(t if t < 256 else 0)   # 0 veut dire 256
		sortie.append(t if t < 256 else 0)
		sortie.append(0)
		sortie.append(0)
		sortie.append_array(_u16(1))
		sortie.append_array(_u16(32))
		sortie.append_array(_u32((pngs[k] as PackedByteArray).size()))
		sortie.append_array(_u32(decalage))
		decalage += (pngs[k] as PackedByteArray).size()
	for p in pngs:
		sortie.append_array(p)
	return sortie


static func _u16(v: int) -> PackedByteArray:
	return PackedByteArray([v & 0xff, (v >> 8) & 0xff])


static func _u32(v: int) -> PackedByteArray:
	return PackedByteArray([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff])


## Une chaîne de fichier `.reg` : \ et " échappés.
static func _chaine_reg(s: String) -> String:
	return "\"%s\"" % s.replace("\\", "\\\\").replace("\"", "\\\"")


static func _windows(chemin: String) -> String:
	return chemin.replace("/", "\\")


## LE TEXTE DU `.reg` QUI INSCRIT les types : `exe` (chemin de l'exécutable), `icones` (dossier des .ico).
static func texte_d_inscription(exe: String, icones: String) -> String:
	var l := PackedStringArray(["Windows Registry Editor Version 5.00", ""])
	for t in TYPES:
		l.append("[%s\\%s]" % [RACINE, t["ext"]])
		l.append("@=" + _chaine_reg(t["id"]))
		l.append("")
		l.append("[%s\\%s]" % [RACINE, t["id"]])
		l.append("@=" + _chaine_reg(t["nom"]))
		l.append("")
		l.append("[%s\\%s\\DefaultIcon]" % [RACINE, t["id"]])
		l.append("@=" + _chaine_reg(_windows(icones.path_join(t["ico"]))))
		l.append("")
		if t["ouvrir"]:
			l.append("[%s\\%s\\shell\\open\\command]" % [RACINE, t["id"]])
			l.append("@=" + _chaine_reg("\"%s\" \"%%1\"" % _windows(exe)))
			l.append("")
	return "\r\n".join(l) + "\r\n"


## LE TEXTE DU `.reg` QUI DÉSINSCRIT tout ce que `texte_d_inscription` a posé (le « - » efface la clé).
static func texte_de_desinscription() -> String:
	var l := PackedStringArray(["Windows Registry Editor Version 5.00", ""])
	for t in TYPES:
		l.append("[-%s\\%s]" % [RACINE, t["ext"]])
		l.append("[-%s\\%s]" % [RACINE, t["id"]])
		l.append("")
	return "\r\n".join(l) + "\r\n"


## Le `desktop.ini` d'un dossier : son icône.
static func desktop_ini(icone: String) -> String:
	return "[.ShellClassInfo]\r\nIconResource=%s,0\r\n" % _windows(icone)


## Le projet passé en argument (un double-clic sur un `.mbproj`), "" s'il n'y en a pas — ou s'il n'existe pas.
static func projet_en_argument(args: PackedStringArray) -> String:
	for a in args:
		if a.get_extension().to_lower() == "mbproj" and FileAccess.file_exists(a):
			return a
	return ""


## Faut-il s'inscrire ? Au premier lancement, et quand l'exécutable a changé de place ou de version — jamais
## si l'utilisateur a retiré les associations (la case de Project) : son refus tient d'un lancement à l'autre.
static func a_inscrire(reglages: ConfigFile, exe: String, version: String) -> bool:
	if bool(reglages.get_value("associations", "refus", false)):
		return false
	return str(reglages.get_value("associations", "exe", "")) != exe \
		or str(reglages.get_value("associations", "version", "")) != version


## Écrit un texte en UTF-16 LE avec sa marque d'ordre — ce que `reg import` et `desktop.ini` lisent en Unicode.
static func _ecrire_utf16(chemin: String, texte: String) -> bool:
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(PackedByteArray([0xff, 0xfe]))
	f.store_buffer(texte.to_utf16_buffer())
	f.close()
	return true


## LE DOSSIER DES ICÔNES, dans les données de l'appli.
static func dossier_des_icones() -> String:
	return OS.get_user_data_dir().path_join("icones")


## Écrit les `.ico` (types et dossiers). Rend "" ou la raison.
static func ecrire_les_icones(dossier: String) -> String:
	DirAccess.make_dir_recursive_absolute(dossier)
	var liste: Array = []
	for t in TYPES:
		liste.append([t["png"], t["ico"]])
	for k in DOSSIERS:
		liste.append([DOSSIERS[k]["png"], DOSSIERS[k]["ico"]])
	for e in liste:
		var tex := load(e[0]) as Texture2D
		if tex == null or tex.get_image() == null:
			return "icon %s missing" % e[0]
		var f := FileAccess.open(dossier.path_join(e[1]), FileAccess.WRITE)
		if f == null:
			return "cannot write %s" % dossier.path_join(e[1])
		f.store_buffer(ico_depuis_image(tex.get_image()))
		f.close()
	return ""


## S'INSCRIT : icônes écrites, `.reg` importé, icônes de l'Explorateur rafraîchies. Rend "" ou la raison.
static func inscrire(exe: String) -> String:
	var dossier := dossier_des_icones()
	var raison := ecrire_les_icones(dossier)
	if raison != "":
		return raison
	return _importer(dossier.path_join("inscrire.reg"), texte_d_inscription(exe, dossier))


static func desinscrire() -> String:
	return _importer(dossier_des_icones().path_join("desinscrire.reg"), texte_de_desinscription())


static func _importer(chemin: String, texte: String) -> String:
	DirAccess.make_dir_recursive_absolute(chemin.get_base_dir())
	if not _ecrire_utf16(chemin, texte):
		return "cannot write %s" % chemin
	var sortie: Array = []
	var code := OS.execute("reg", ["import", _windows(chemin)], sortie, true)
	if code != 0:
		return "reg import failed (%d): %s" % [code, "".join(PackedStringArray(sortie)).strip_edges()]
	# L'Explorateur garde ses icônes en cache : on lui demande de les relire (au mieux ; sans effet grave sinon).
	OS.execute("ie4uinit.exe", ["-show"], [], false)
	return ""


## L'ICÔNE D'UN DOSSIER EXPORTÉ (.mbset / .mbworld) : son `desktop.ini`, caché, et le dossier marqué « lecture
## seule » — c'est cet attribut du DOSSIER qui fait lire son `desktop.ini` à Windows. Sans effet hors de Windows,
## ou si les icônes n'ont pas été écrites (appli jamais inscrite). Rend vrai si le dossier est marqué.
## ⚠ PAS PAR `attrib` (mesuré le 1er octobre 2026, dans l'exe) : `OS.execute` met chaque argument entre
## guillemets, `attrib` refuse un « "+h" » (« Format incorrect du paramètre »)… et rend le code 0. Rien n'était
## posé, sans un mot. Godot pose lui-même caché et lecture seule ; il ne sait pas poser « système », dont
## l'icône n'a pas besoin.
## ⚠ UN `desktop.ini` CACHÉ NE SE RÉÉCRIT PAS TEL QUEL : Windows refuse de remplacer un fichier caché par un
## fichier normal — on lui ôte l'attribut d'abord.
static func marquer_dossier(dossier: String, icones := "") -> bool:
	if OS.get_name() != "Windows":
		return false
	var genre := dossier.get_extension().to_lower()
	if not DOSSIERS.has(genre):
		return false
	var icone := (icones if icones != "" else dossier_des_icones()).path_join(DOSSIERS[genre]["ico"])
	if not FileAccess.file_exists(icone) or not DirAccess.dir_exists_absolute(dossier):
		return false
	var ini := dossier.path_join("desktop.ini")
	if FileAccess.file_exists(ini):
		FileAccess.set_hidden_attribute(ini, false)
	if not _ecrire_utf16(ini, desktop_ini(icone)):
		return false
	return FileAccess.set_hidden_attribute(ini, true) == OK and FileAccess.set_read_only_attribute(dossier, true) == OK
