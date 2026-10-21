extends RefCounted
## LE CONTRAT DE LICENCE (`app/textes/LICENSE.txt`, le modèle OUTIL de `D:/SpannerGames/LEGAL`, français qui fait foi
## puis anglais) : livré à côté de l'exe, et ACCEPTÉ au premier lancement — une fois, retenu dans `reglages.cfg`.
## Un contrat qui change (sa VERSION, ci-dessous) se fait accepter de nouveau.
## ⚠ Seulement dans l'exe livré (`Edition.livree()`) : jamais depuis l'éditeur ni les suites.

const CHEMIN := "res://app/textes/LICENSE.txt"
## ⚠ À MONTER quand le texte change sur le fond (pas pour une coquille) : chaque acheteur le relira.
const VERSION := "2"
const REGLAGES := "user://reglages.cfg"


static func texte() -> String:
	return FileAccess.get_file_as_string(CHEMIN)


static func accepte(reglages_chemin := REGLAGES) -> bool:
	var r := ConfigFile.new()
	r.load(reglages_chemin)
	return str(r.get_value("contrat", "accepte", "")) == VERSION


static func accepter(reglages_chemin := REGLAGES) -> void:
	var r := ConfigFile.new()
	r.load(reglages_chemin)
	r.set_value("contrat", "accepte", VERSION)
	r.save(reglages_chemin)
