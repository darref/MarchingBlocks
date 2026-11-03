extends SceneTree
##
## LE LOGICIEL LIBRE — « About », la licence GPL-3.0 livrée, les dons, la vérification des mises à jour sur GitHub,
## l'exemple téléchargé depuis la dernière version, les avis des licences tierces, et l'appli menée sans rien à
## accepter ni à activer. Remplace `test_vente.gd` (Jordan, 3 novembre 2026 : « MarchingBlocks devient OpenSource et
## réclame des dons […] il n'y a plus besoin de démo »).
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_a_propos.gd
##
## ⚠ `reglages.cfg` EST RENDU tel quel à la fin, même en cas d'échec (comme la fumée).
## ⚠ AUCUN RÉSEAU : les URL vraies ne sont jamais appelées ; hors ligne est éprouvé sur une adresse où rien n'écoute.

const MisesAJour := preload("res://app/mises_a_jour.gd")
const Avis := preload("res://app/avis_tiers.gd")
const Dons := preload("res://app/dons.gd")
const APropos := preload("res://app/a_propos.gd")
const Associations := preload("res://app/associations.gd")
const Projet := preload("res://app/projet.gd")
const Exemple := preload("res://app/exemple.gd")

const REGLAGES := "user://reglages.cfg"
const JETABLES := "user://a_propos_essai"
const R_ESSAI := "user://a_propos_essai/reglages.cfg"

var _ok := 0
var _echecs := 0
var _reglages_avant := ""
var _avait_des_reglages := false


func _initialize() -> void:
	print("=== LE LOGICIEL LIBRE ===\n")
	_avait_des_reglages = FileAccess.file_exists(REGLAGES)
	if _avait_des_reglages:
		_reglages_avant = FileAccess.get_file_as_string(REGLAGES)
	_mener.call_deferred()


func _mener() -> void:
	_effacer(ProjectSettings.globalize_path(JETABLES))
	_licence()
	_plus_de_vente()
	_dons()
	_mises_a_jour()
	_exemple_telecharge()
	await _mise_a_jour_hors_ligne()
	_avis()
	_associations()
	await _appli()
	_finir()


# ── 1. LA LICENCE ──────────────────────────────────────────────────────────────────────────────────────

func _licence() -> void:
	print("— la licence —")
	var t := APropos.texte_de_la_licence()
	_vrai(t.begins_with("                    GNU GENERAL PUBLIC LICENSE\n                       Version 3, 29 June 2007"),
		"res://LICENSE est la GPL version 3")
	_vrai(t.contains("END OF TERMS AND CONDITIONS") and t.length() > 30000, "… entière (%d caractères)" % t.length())
	# L'export l'embarque (sinon « About » la montrerait vide) : elle doit être dans le filtre de chaque préréglage.
	var p := ConfigFile.new()
	_egal(p.load("res://export_presets.cfg"), OK, "export_presets.cfg se lit")
	var n := 0
	for s in p.get_sections():
		if s.ends_with(".options") or not s.begins_with("preset."):
			continue
		n += 1
		_vrai(str(p.get_value(s, "include_filter", "")).split(",").has("LICENSE"),
			"le préréglage « %s » embarque LICENSE" % p.get_value(s, "name", s))
		_vrai(not bool(p.get_value(s, "encrypt_pck", false)), "le préréglage « %s » n'est pas chiffré (code ouvert)"
			% p.get_value(s, "name", s))
		_vrai(str(p.get_value(s, "custom_features", "")) == "", "le préréglage « %s » ne pose plus de balise d'édition"
			% p.get_value(s, "name", s))
	_egal(n, 1, "un seul préréglage : plus d'éditions (site, Steam, itch, démo)")
	for g in ["res://addons/marchingblocks_paint/LICENSE", "res://engines/unity/com.marchingblocks.paint/LICENSE.md",
			"res://engines/unreal/MarchingBlocksPaint/LICENSE"]:
		if FileAccess.file_exists(g):
			_vrai(FileAccess.get_file_as_string(g).contains("MIT"), "le greffon garde sa licence MIT : %s" % g.get_file())


## Ce que la vente laissait : rien ne doit rester (un fichier oublié se ferait charger par une scène).
func _plus_de_vente() -> void:
	for f in ["res://app/edition.gd", "res://app/demo.gd", "res://app/licence.gd", "res://app/contrat.gd",
			"res://app/vente.gd", "res://app/textes/LICENSE.txt"]:
		_vrai(not FileAccess.file_exists(f), "%s est retiré" % f.get_file())
	_vrai(not ClassDB.class_exists("MBLicence"), "la bibliothèque native ne porte plus MBLicence")


# ── 2. LES DONS ────────────────────────────────────────────────────────────────────────────────────────

func _dons() -> void:
	print("— les dons —")
	_vrai(Dons.PLATEFORMES.size() >= 2, "au moins deux plateformes de dons")
	var noms: Array = []
	for p in Dons.PLATEFORMES:
		noms.append(p["nom"])
	_vrai(noms.has("Ko-fi") and noms.has("GitHub Sponsors"), "Ko-fi et GitHub Sponsors (Jordan, 3 novembre 2026)")
	# UNE LISTE, TROIS ENDROITS (`dons.gd`) : le bouton « Sponsor » de GitHub et le README disent la même chose.
	var funding := FileAccess.get_file_as_string("res://.github/FUNDING.yml")
	var lisez := FileAccess.get_file_as_string("res://README.md")
	_vrai(funding != "" and lisez != "", ".github/FUNDING.yml et README.md existent")
	for p in Dons.PLATEFORMES:
		_vrai(str(p["url"]).begins_with("https://"), "%s : un lien en https" % p["nom"])
		_vrai(funding.contains(str(p["funding"])), "FUNDING.yml porte « %s »" % p["funding"])
		_vrai(lisez.contains(str(p["url"])), "le README porte %s" % p["url"])
	_vrai(lisez.contains(MisesAJour.DEPOT + "/releases"), "le README mène aux versions publiées")


# ── 3. LES MISES À JOUR ────────────────────────────────────────────────────────────────────────────────

func _mises_a_jour() -> void:
	print("— les mises à jour —")
	for c in [["0.9.1", "0.9.0", true], ["0.9.0", "0.9.0", false], ["0.8.9", "0.9.0", false], ["0.9.10", "0.9.9", true],
			["1.0", "0.9.9", true], ["0.9.0.1", "0.9.0", true], ["0.9", "0.9.0", false], ["v0.9.2", "0.9.1", true],
			["0.9.1-beta", "0.9.0", true], ["abc", "0.9.0", false], ["", "0.9.0", false], ["0.10.0", "0.9.0", true]]:
		_egal(MisesAJour.plus_recente(c[0], c[1]), c[2], "« %s » plus récente que « %s » : %s" % c)
	# La réponse de GitHub (`releases/latest`), raccourcie : l'étiquette `v…` et la page de la version.
	var gh := '{"tag_name": "v1.2.0", "name": "MarchingBlocks 1.2.0", "html_url": "https://github.com/darref/MarchingBlocks/releases/tag/v1.2.0", "assets": []}'
	_egal(MisesAJour.lire_la_reponse(gh, "1.1.0"),
		{"version": "1.2.0", "lien": "https://github.com/darref/MarchingBlocks/releases/tag/v1.2.0"},
		"GitHub : la version (sans le « v ») et la page de la version")
	_egal(MisesAJour.lire_la_reponse(gh, "1.2.0"), {}, "GitHub, la même version : rien")
	_egal(MisesAJour.lire_la_reponse('{"tag_name": "v1.2.0", "html_url": "http://x.test/d"}', "1.1.0")["lien"], "",
		"GitHub : un lien qui n'est pas en https n'est pas gardé")
	_egal(MisesAJour.lire_la_reponse('{"message": "Not Found", "documentation_url": "https://docs.github.com"}', "1.1.0"),
		{}, "GitHub sans version publiée (404) : rien")
	var r := MisesAJour.lire_la_reponse('{"version": "0.9.1", "date": "2027-02-12", "notes": "https://x.test/n", "download": "https://x.test/d"}', "0.9.0")
	_egal(r, {"version": "0.9.1", "lien": "https://x.test/d"}, "notre forme : la version et le lien de téléchargement")
	_egal(MisesAJour.lire_la_reponse('{"version": "0.9.1", "download": "file:///c:/x.exe"}', "0.9.0")["lien"], "",
		"… jamais un lien file://")
	_egal(MisesAJour.lire_la_reponse("<html>404</html>", "0.9.0"), {}, "une page d'erreur : rien")
	_egal(MisesAJour.lire_la_reponse('[1, 2]', "0.9.0"), {}, "un JSON d'une autre forme : rien")
	_egal(MisesAJour.URL, "https://api.github.com/repos/darref/MarchingBlocks/releases/latest",
		"l'URL livrée est celle des versions publiées du dépôt")
	_vrai(MisesAJour.url_remplie() and not MisesAJour.url_remplie("http://x.test/j"), "en https, elle part ; en http, non")
	DirAccess.make_dir_recursive_absolute(JETABLES)
	DirAccess.remove_absolute(R_ESSAI)
	_vrai(MisesAJour.voulue(R_ESSAI), "la vérification est voulue par défaut")
	MisesAJour.regler(false, R_ESSAI)
	_vrai(not MisesAJour.voulue(R_ESSAI), "la case la coupe, et c'est retenu")


## L'EXEMPLE TÉLÉCHARGÉ (Jordan, 18 octobre 2026 ; depuis GitHub le 3 novembre 2026) : `example.json` lu sans rien laisser
## passer de faux, et le fichier reçu comparé à sa taille et à son SHA-256. Attendus écrits à la main.
func _exemple_telecharge() -> void:
	_egal(Exemple.url_description(), "https://github.com/darref/MarchingBlocks/releases/latest/download/example.json",
		"example.json est un fichier de la dernière version publiée")
	var sha := "a".repeat(64)
	_egal(Exemple.lire_la_description('{"file": "x.zip", "size": 12, "sha256": "%s", "url": "https://x.test/v1/x.zip"}' % sha),
		{"url": "https://x.test/v1/x.zip", "taille": 12, "sha256": sha}, "une description juste est lue")
	for faux in ['{"size": 12, "sha256": "%s", "url": "http://x.test/e.zip"}' % sha,
			'{"size": 12, "sha256": "abc", "url": "https://x.test/e.zip"}',
			'{"size": 0, "sha256": "%s", "url": "https://x.test/e.zip"}' % sha,
			'{"size": 99999999999, "sha256": "%s", "url": "https://x.test/e.zip"}' % sha,
			'{"size": 12, "sha256": "%s", "url": "https://x.test/e.zip"}' % "g".repeat(64),
			"<html>404</html>", "[]"]:
		_egal(Exemple.lire_la_description(faux), {}, "une description fausse est refusée : %s" % faux.left(40))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(JETABLES))
	var chemin := ProjectSettings.globalize_path(JETABLES).path_join("exemple_essai.zip")
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string("hello world\n")
	f.close()
	# SHA-256 de « hello world » suivi d'un saut de ligne, calculé hors de Godot (sha256sum).
	var bon := {"taille": 12, "sha256": "a948904f2f0f479b8f8197694b30184b0d2ed1c1cd2a1ec0fb85d299a192a447"}
	_vrai(Exemple.conforme(chemin, bon), "le fichier annoncé est reconnu (taille et SHA-256)")
	_vrai(not Exemple.conforme(chemin, {"taille": 12, "sha256": "b" + bon["sha256"].substr(1)}), "un SHA-256 différent est refusé")
	_vrai(not Exemple.conforme(chemin, {"taille": 13, "sha256": bon["sha256"]}), "une taille différente est refusée")
	_vrai(not Exemple.conforme(chemin + ".absent", bon), "un fichier absent est refusé")


## Hors ligne (une adresse où rien n'écoute) : la requête part, ne bloque rien, et ne dit rien.
func _mise_a_jour_hors_ligne() -> void:
	var m: Node = MisesAJour.new()
	root.add_child(m)
	var dit := [false]
	m.disponible.connect(func(_v: String, _l: String) -> void: dit[0] = true)
	var t0 := Time.get_ticks_msec()
	var parti: bool = m.lancer("0.9.0", "https://127.0.0.1:9/latest.json")
	_vrai(Time.get_ticks_msec() - t0 < 500, "lancer la vérification ne bloque pas (%d ms)" % (Time.get_ticks_msec() - t0))
	for i in 120:
		await process_frame
	_vrai(not dit[0], "hors ligne, rien n'est dit (requête partie : %s)" % parti)
	_vrai(not m.lancer("0.9.0", "http://127.0.0.1:9/latest.json"), "une URL en http : aucune requête ne part")
	m.queue_free()


# ── 4. LES AVIS ET LES ASSOCIATIONS ────────────────────────────────────────────────────────────────────

func _avis() -> void:
	print("— les avis —")
	var a := Avis.texte()
	for mot in ["Godot Engine", "godot-cpp", "Open Sans font", "FreeType", "OFL-1.1", "Open Font License", "GNU GPL v3.0"]:
		_vrai(a.contains(mot), "les avis tiers nomment « %s »" % mot)
	_vrai(not a.contains("Monocypher"), "… et plus Monocypher (parti avec les clés de licence)")


func _associations() -> void:
	var r := ConfigFile.new()
	_vrai(Associations.a_inscrire(r, "C:/x/MarchingBlocks.exe", "0.9.0"), "un exe jamais inscrit s'inscrit")
	_vrai(not Associations.a_inscrire(r, "C:/x/MarchingBlocks.exe", "0.9.0", true),
		"… sauf si l'installeur l'a posé (c'est lui qui inscrit et désinscrit)")
	DirAccess.make_dir_recursive_absolute(JETABLES + "/installe")
	var f := FileAccess.open(JETABLES + "/installe/unins000.exe", FileAccess.WRITE)
	f.close()
	_vrai(Associations.installe_par_l_installeur(ProjectSettings.globalize_path(JETABLES + "/installe/MarchingBlocks.exe")),
		"le désinstalleur à côté de l'exe : installé par l'installeur")
	_vrai(not Associations.installe_par_l_installeur(ProjectSettings.globalize_path(JETABLES + "/MarchingBlocks.exe")),
		"sans lui : non")


# ── 5. L'APPLI : RIEN À ACCEPTER, RIEN À ACTIVER ───────────────────────────────────────────────────────

func _appli() -> void:
	print("— l'appli —")
	var jetable := _projet_jetable()
	_reglages_neufs({"projet": {"dernier": jetable, "monde": jetable}})
	var dehors := ProjectSettings.globalize_path(JETABLES + "/dehors")
	DirAccess.make_dir_recursive_absolute(dehors)
	var ed: Control = (load("res://app/editor.tscn") as PackedScene).instantiate()
	root.add_child(ed)
	for i in 10:
		await process_frame
	_egal(ProjectSettings.globalize_path(ed._projet), ProjectSettings.globalize_path(jetable),
		"le dernier projet s'ouvre tout de suite (ni contrat ni clé avant)")
	var dialogues := 0
	for d in ed.find_children("*", "AcceptDialog", true, false):
		if (d as Window).visible:
			dialogues += 1
	_egal(dialogues, 0, "aucune fenêtre ne s'ouvre au lancement")
	_vrai(ed._case_maj != null and ed._case_maj.visible, "la case des mises à jour est dans Project")
	var soutien := false
	for b in ed.find_children("*", "Button", true, false):
		if (b as Button).text == "Support":
			soutien = true
	_vrai(soutien, "le bouton « Support » est dans la barre")
	# Toutes les sorties ouvrent leur dialogue : plus de démo qui les refuse.
	for q in ["tileset", "monde", "exporter", "patron", "enregistrer", "ouvrir"]:
		ed._rapport.text = ""
		ed._demander(q)
		_vrai(ed._dialogue.visible, "« %s » ouvre son dialogue" % q)
		ed._dialogue.hide()
	ed._a_propos.ouvrir_about()
	var about := ed._a_propos.dialogue_about as AcceptDialog
	var texte := _textes(about)
	_vrai(texte.contains("GNU General Public License v3.0") and texte.contains("v%s" %
		ProjectSettings.get_setting("application/config/version", "")), "About dit la version et la GPL v3.0")
	var liens: Array = []
	for l in about.find_children("*", "LinkButton", true, false):
		liens.append((l as LinkButton).uri)
	_vrai(liens.has(MisesAJour.DEPOT), "About mène au code source")
	for p in Dons.PLATEFORMES:
		_vrai(liens.has(p["url"]), "About mène à %s" % p["nom"])
	ed._a_propos.montrer_un_texte("License", APropos.texte_de_la_licence())
	_vrai(ed._a_propos.dialogue_texte.visible, "le texte de la licence se montre")
	about.hide()
	ed._a_propos.dialogue_texte.hide()
	ed._dire_la_mise_a_jour("9.9.9", "https://github.com/darref/MarchingBlocks/releases/tag/v9.9.9")
	_vrai(ed._bouton_maj.visible and ed._bouton_maj.text == "Update 9.9.9 available",
		"une mise à jour se dit dans la barre de titre")
	ed._toujours_ecrire()
	ed._attendre_l_ecriture()
	root.remove_child(ed)
	ed.free()
	await process_frame


# ── LES OUTILS ─────────────────────────────────────────────────────────────────────────────────────────

func _projet_jetable() -> String:
	DirAccess.make_dir_recursive_absolute(JETABLES)
	var chemin := JETABLES + "/monde.mbproj"
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string(Projet.vers_texte([Projet.couche("Rock")], 0))
	f.close()
	return chemin


func _reglages_neufs(sections: Dictionary) -> void:
	var r := ConfigFile.new()
	for s in sections:
		for k in sections[s]:
			r.set_value(s, k, sections[s][k])
	r.save(REGLAGES)


func _textes(n: Node) -> String:
	var t := ""
	for c in n.find_children("*", "Label", true, false):
		t += (c as Label).text + "\n"
	return t


static func _effacer(dossier: String) -> void:
	var d := DirAccess.open(dossier)
	if d == null:
		return
	d.include_hidden = true
	for f in d.get_files():
		FileAccess.set_read_only_attribute(dossier.path_join(f), false)
		d.remove(f)
	for sd in d.get_directories():
		_effacer(dossier.path_join(sd))
	FileAccess.set_read_only_attribute(dossier, false)
	DirAccess.remove_absolute(dossier)


func _rendre_les_reglages() -> void:
	if _avait_des_reglages:
		var f := FileAccess.open(REGLAGES, FileAccess.WRITE)
		f.store_string(_reglages_avant)
		f.close()
	else:
		DirAccess.remove_absolute(REGLAGES)


func _finir() -> void:
	_rendre_les_reglages()
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
