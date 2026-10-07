extends SceneTree
## PRÉPARER LA LIVRAISON — ce qui accompagne l'exe dans un dossier livré, tiré des règles de l'appli (UNE source) :
##   LICENSE.txt               le contrat (`app/textes/LICENSE.txt`, tel quel)
##   THIRD_PARTY_NOTICES.txt   les avis des licences tierces (`app/avis_tiers.gd`, le même texte que « About »)
## et, avec `--installeur` (la version SITE, installée par Inno Setup) :
##   icones/*.ico              les icônes des fichiers et des dossiers (`Associations.ecrire_les_icones`)
##   associations.iss          la section [Registry] de l'installeur, écrite d'après `Associations.TYPES` : les MÊMES
##                             clés que l'appli pose elle-même quand elle n'est pas installée
##
## LANCEMENT (par `exporter_marchingblocks.sh`) :
##   godot --headless --path <projet> --script res://DEV_TOOLS/preparer_livraison.gd -- --sortie=<dossier> [--installeur]

const Associations := preload("res://app/associations.gd")
const Contrat := preload("res://app/contrat.gd")
const Avis := preload("res://app/avis_tiers.gd")


func _initialize() -> void:
	var sortie := ""
	var installeur := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.trim_prefix("--sortie=")
		elif a == "--installeur":
			installeur = true
	if sortie == "" or not DirAccess.dir_exists_absolute(sortie):
		printerr("⚠ --sortie=<dossier existant> manquant (%s)" % sortie)
		quit(1)
		return
	var erreurs := 0
	erreurs += _ecrire(sortie.path_join("LICENSE.txt"), Contrat.texte().replace("\r\n", "\n").replace("\n", "\r\n"))
	erreurs += _ecrire(sortie.path_join("THIRD_PARTY_NOTICES.txt"), Avis.texte().replace("\n", "\r\n"))
	if installeur:
		var raison := Associations.ecrire_les_icones(sortie.path_join("icones"))
		if raison != "":
			printerr("⚠ icônes : " + raison)
			erreurs += 1
		erreurs += _ecrire(sortie.path_join("associations.iss"), texte_iss())
	print("LIVRAISON : %s%s — %s" % [sortie, " (installeur)" if installeur else "", "OK" if erreurs == 0 else "ÉCHEC"])
	quit(0 if erreurs == 0 else 1)


## La section [Registry] d'Inno Setup. `HKA` : HKEY_CURRENT_USER pour une installation par utilisateur (la nôtre).
## ⚠ « uninsdeletekey » sur le type (MarchingBlocks.Project…), « uninsdeletevalue » + « uninsdeletekeyifempty » sur
## l'extension : la désinstallation retire ce qu'elle a posé, sans arracher une extension qu'un autre programme
## aurait reprise entre-temps. Les guillemets se DOUBLENT dans une chaîne d'Inno.
static func texte_iss() -> String:
	var l := PackedStringArray(["; Écrit par DEV_TOOLS/preparer_livraison.gd d'après app/associations.gd — ne pas éditer.",
		"[Registry]"])
	var base := "Software\\Classes\\"
	for t in Associations.TYPES:
		l.append('Root: HKA; Subkey: "%s%s"; ValueType: string; ValueName: ""; ValueData: "%s"; Flags: uninsdeletevalue uninsdeletekeyifempty'
			% [base, t["ext"], t["id"]])
		l.append('Root: HKA; Subkey: "%s%s"; ValueType: string; ValueName: ""; ValueData: "%s"; Flags: uninsdeletekey'
			% [base, t["id"], t["nom"]])
		l.append('Root: HKA; Subkey: "%s%s\\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\\icones\\%s"'
			% [base, t["id"], t["ico"]])
		if t["ouvrir"]:
			l.append('Root: HKA; Subkey: "%s%s\\shell\\open\\command"; ValueType: string; ValueName: ""; ValueData: """{app}\\MarchingBlocks.exe"" ""%%1"""'
				% [base, t["id"]])
	return "\r\n".join(l) + "\r\n"


func _ecrire(chemin: String, texte: String) -> int:
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	if f == null:
		printerr("⚠ impossible d'écrire " + chemin)
		return 1
	f.store_string(texte)
	f.close()
	return 0
