extends SceneTree
##
## OPEN SOURCE — l'édition (release / dev), la vérification des mises à jour sur GitHub, l'exemple téléchargé depuis le
## dépôt, la licence MIT et les avis des licences tierces, « About » et ses liens. Charte §0, « open source »
## (remplace `test_vente.gd` : plus de clé, de démo ni de contrat depuis le 3 novembre 2026).
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_a_propos.gd
##
## ⚠ `reglages.cfg` n'est jamais touché : les réglages d'essai vivent dans un dossier jetable.

const Edition := preload("res://app/edition.gd")
const MisesAJour := preload("res://app/mises_a_jour.gd")
const Avis := preload("res://app/avis_tiers.gd")
const APropos := preload("res://app/a_propos.gd")
const Associations := preload("res://app/associations.gd")
const Exemple := preload("res://app/exemple.gd")

const JETABLES := "user://a_propos_essai"
const R_ESSAI := "user://a_propos_essai/reglages.cfg"

var _ok := 0
var _echecs := 0


func _initialize() -> void:
	print("=== OPEN SOURCE : À PROPOS, MISES À JOUR ===\n")
	_mener.call_deferred()


func _mener() -> void:
	_effacer(ProjectSettings.globalize_path(JETABLES))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(JETABLES))
	_editions()
	_mises_a_jour()
	_exemple_telecharge()
	await _mise_a_jour_hors_ligne()
	_licence_et_avis()
	_associations()
	await _about()
	_finir()


func _editions() -> void:
	print("— les éditions —")
	_egal(Edition.d_apres(func(_b: String) -> bool: return false), Edition.DEV, "l'éditeur, les suites : dev")
	_egal(Edition.d_apres(func(b: String) -> bool: return b == "template"), Edition.RELEASE, "un exe exporté : release")
	# Un exe exporté avec une ancienne balise d'édition reste une release ordinaire : aucune ne restreint plus rien.
	for b in ["edition_demo", "edition_site", "edition_steam", "edition_itch"]:
		_egal(Edition.d_apres(func(x: String) -> bool: return x in ["template", b]), Edition.RELEASE,
			"l'ancienne balise « %s » ne change rien" % b)
	_egal(Edition.nom(), Edition.DEV, "les suites tournent en édition dev")
	_vrai(not Edition.livree(), "… donc pas livrée")
	Edition.forcee = Edition.RELEASE
	_vrai(Edition.livree() and Edition.libelle() == "Release build", "forcée en release : livrée, « Release build »")
	Edition.forcee = ""


func _mises_a_jour() -> void:
	print("— les mises à jour —")
	for c in [["0.9.1", "0.9.0", true], ["0.9.0", "0.9.0", false], ["0.8.9", "0.9.0", false], ["0.9.10", "0.9.9", true],
			["1.0", "0.9.9", true], ["0.9.0.1", "0.9.0", true], ["0.9", "0.9.0", false], ["v1.2.0", "1.1.0", true],
			["1.1.1-beta", "1.1.0", true], ["abc", "1.1.0", false], ["", "1.1.0", false], ["1.10.0", "1.9.0", true]]:
		_egal(MisesAJour.plus_recente(c[0], c[1]), c[2], "« %s » plus récente que « %s » : %s" % c)
	# La réponse de GitHub (« releases/latest »), écrite à la main d'après la documentation de l'API.
	var gh := '{"tag_name": "v1.2.0", "name": "MarchingBlocks 1.2.0", "html_url": "https://github.com/darref/MarchingBlocks/releases/tag/v1.2.0", "draft": false, "prerelease": false}'
	_egal(MisesAJour.lire_la_reponse(gh, "1.1.0"),
		{"version": "1.2.0", "lien": "https://github.com/darref/MarchingBlocks/releases/tag/v1.2.0"},
		"GitHub annonce plus récent : la version sans « v », et la page de la Release")
	_egal(MisesAJour.lire_la_reponse(gh, "1.2.0"), {}, "la même version : rien")
	_egal(MisesAJour.lire_la_reponse('{"tag_name": "v1.2.0", "html_url": "http://x.test/r"}', "1.1.0"),
		{"version": "1.2.0", "lien": ""}, "un lien qui n'est pas en https n'est pas gardé")
	_egal(MisesAJour.lire_la_reponse('{"message": "Not Found"}', "1.1.0"), {}, "aucune Release publiée (404 de GitHub) : rien")
	# L'ancien format du site reste lu.
	_egal(MisesAJour.lire_la_reponse('{"version": "1.2.0", "download": "https://x.test/d"}', "1.1.0"),
		{"version": "1.2.0", "lien": "https://x.test/d"}, "l'ancien format {version, download} est encore lu")
	_egal(MisesAJour.lire_la_reponse("<html>404</html>", "1.1.0"), {}, "une page d'erreur : rien")
	_egal(MisesAJour.lire_la_reponse('[1, 2]', "1.1.0"), {}, "un JSON d'une autre forme : rien")
	_vrai(MisesAJour.url_remplie(), "l'URL livrée est remplie (l'API GitHub du dépôt)")
	_vrai(MisesAJour.URL.begins_with("https://api.github.com/repos/darref/MarchingBlocks/"), "… celle du dépôt public")
	_vrai(not MisesAJour.url_remplie("http://x.test/j"), "une URL en http ne part pas")
	DirAccess.remove_absolute(R_ESSAI)
	_vrai(MisesAJour.voulue(R_ESSAI), "la vérification est voulue par défaut")
	MisesAJour.regler(false, R_ESSAI)
	_vrai(not MisesAJour.voulue(R_ESSAI), "la case la coupe, et c'est retenu")


## Hors ligne (une adresse où rien n'écoute) : la requête part, ne bloque rien, et ne dit rien.
func _mise_a_jour_hors_ligne() -> void:
	var m: Node = MisesAJour.new()
	root.add_child(m)
	var dit := [false]
	m.disponible.connect(func(_v: String, _l: String) -> void: dit[0] = true)
	var t0 := Time.get_ticks_msec()
	var parti: bool = m.lancer("1.1.0", "https://127.0.0.1:9/latest")
	_vrai(Time.get_ticks_msec() - t0 < 500, "lancer la vérification ne bloque pas (%d ms)" % (Time.get_ticks_msec() - t0))
	for i in 120:
		await process_frame
	_vrai(not dit[0], "hors ligne, rien n'est dit (requête partie : %s)" % parti)
	m.queue_free()


## L'EXEMPLE TÉLÉCHARGÉ : `example.json` dans le dépôt, puis le zip d'une Release, vérifié (taille, SHA-256).
func _exemple_telecharge() -> void:
	print("— l'exemple —")
	_egal(Exemple.url_description(), "https://raw.githubusercontent.com/darref/MarchingBlocks/main/exemple/example.json",
		"example.json est lu dans le dépôt public, branche main")
	var sha := "a".repeat(64)
	var url := "https://github.com/darref/MarchingBlocks/releases/download/v1.1.0/MarchingBlocks-1.1.0-example.zip"
	_egal(Exemple.lire_la_description('{"file": "x.zip", "size": 12, "sha256": "%s", "url": "%s"}' % [sha, url]),
		{"url": url, "taille": 12, "sha256": sha}, "une description juste est lue")
	for faux in ['{"size": 12, "sha256": "%s", "url": "http://x.test/e.zip"}' % sha,
			'{"size": 12, "sha256": "abc", "url": "https://x.test/e.zip"}',
			'{"size": 0, "sha256": "%s", "url": "https://x.test/e.zip"}' % sha,
			'{"size": 99999999999, "sha256": "%s", "url": "https://x.test/e.zip"}' % sha,
			'{"size": 12, "sha256": "%s", "url": "https://x.test/e.zip"}' % "g".repeat(64),
			"<html>404</html>", "[]"]:
		_egal(Exemple.lire_la_description(faux), {}, "une description fausse est refusée : %s" % faux.left(40))
	var chemin := ProjectSettings.globalize_path(JETABLES).path_join("exemple_essai.zip")
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string("hello world\n")
	f.close()
	# SHA-256 de « hello world » suivi d'un saut de ligne, calculé hors de Godot (sha256sum).
	var bon := {"taille": 12, "sha256": "a948904f2f0f479b8f8197694b30184b0d2ed1c1cd2a1ec0fb85d299a192a447"}
	_vrai(Exemple.conforme(chemin, bon), "le fichier annoncé est reconnu (taille et SHA-256)")
	_vrai(not Exemple.conforme(chemin, {"taille": 12, "sha256": "b" + bon["sha256"].substr(1)}), "un SHA-256 différent est refusé")
	_vrai(not Exemple.conforme(chemin, {"taille": 13, "sha256": bon["sha256"]}), "une taille différente est refusée")


func _licence_et_avis() -> void:
	print("— la licence, les avis —")
	var t := APropos.licence()
	_vrai(t.begins_with("MIT License") and t.contains("Permission is hereby granted, free of charge"),
		"res://LICENSE est la licence MIT")
	_egal(t, FileAccess.get_file_as_string("res://addons/marchingblocks_paint/LICENSE"),
		"… la même que celle du greffon Godot (une seule licence pour tout le dépôt)")
	var a := Avis.texte()
	for mot in ["Godot Engine", "godot-cpp", "Monocypher", "FreeType", "Open Font License"]:
		_vrai(a.contains(mot), "les avis tiers nomment « %s »" % mot)


func _associations() -> void:
	var r := ConfigFile.new()
	_vrai(Associations.a_inscrire(r, "C:/x/MarchingBlocks.exe", "1.1.0"), "un exe jamais inscrit s'inscrit")
	_vrai(not Associations.a_inscrire(r, "C:/x/MarchingBlocks.exe", "1.1.0", true),
		"… sauf si l'installeur l'a posé (c'est lui qui inscrit et désinscrit)")


## About : les liens du dépôt et des dons, la licence ; aucune trace de clé, de démo ni de contrat à accepter.
func _about() -> void:
	print("— About —")
	var liens: Array = APropos.liens()
	var adresses: Array = liens.map(func(l: Array) -> String: return l[1])
	_vrai("https://github.com/darref/MarchingBlocks" in adresses, "About mène au dépôt GitHub")
	_vrai("https://github.com/sponsors/darref" in adresses, "About mène à GitHub Sponsors")
	_vrai(adresses.all(func(u: String) -> bool: return u.begins_with("https://")), "tous les liens sont en https")
	var p: Node = APropos.new()
	root.add_child(p)
	p.au_lancement()
	_vrai(p.dialogue_about == null, "au lancement, aucun dialogue ne s'ouvre (ni contrat, ni clé)")
	_vrai(p._verif == null, "hors de l'exe livré, aucune vérification ne part")
	p.ouvrir_about()
	await process_frame
	var texte := _textes(p.dialogue_about)
	_vrai(texte.contains("MIT license") and texte.contains("open source"), "About dit la licence MIT")
	for interdit in ["license key", "Licensed to", "demo", "All rights reserved", "Steam"]:
		_vrai(not texte.contains(interdit), "About ne parle plus de « %s »" % interdit)
	var boutons := ""
	for b in p.dialogue_about.find_children("*", "BaseButton", true, false):
		boutons += str(b.get("text")) + "\n"
	_vrai(boutons.contains("License (MIT)") and boutons.contains("Third-party notices") and boutons.contains("Sponsors"),
		"About porte la licence, les avis et le lien Sponsors")
	p.queue_free()


# ── LES OUTILS ─────────────────────────────────────────────────────────────────────────────────────────

static func _effacer(dossier: String) -> void:
	var d := DirAccess.open(dossier)
	if d == null:
		return
	d.include_hidden = true
	for f in d.get_files():
		d.remove(f)
	for sd in d.get_directories():
		_effacer(dossier.path_join(sd))
	DirAccess.remove_absolute(dossier)


func _textes(n: Node) -> String:
	var t := ""
	for c in n.find_children("*", "Label", true, false):
		t += (c as Label).text + "\n"
	return t


func _finir() -> void:
	Edition.forcee = ""
	_effacer(ProjectSettings.globalize_path(JETABLES))
	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	print("VERDICT : %s" % ("OK" if _echecs == 0 else "ÉCHEC"))
	quit(0 if _echecs == 0 else 1)


func _vrai(c: bool, quoi: String) -> void:
	if c:
		_ok += 1
	else:
		_echecs += 1
		print("  ✗ " + quoi)


func _egal(a: Variant, b: Variant, quoi: String) -> void:
	if a == b:
		_ok += 1
	else:
		_echecs += 1
		print("  ✗ %s — rendu %s, attendu %s" % [quoi, a, b])
