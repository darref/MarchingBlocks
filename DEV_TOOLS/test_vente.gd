extends SceneTree
##
## LA VENTE — la clé de licence (Ed25519), les trois éditions (site, Steam, démo), la vérification des mises à jour,
## le contrat accepté au premier lancement, les avis des licences tierces, et l'appli menée dans chaque édition.
## Charte §0, « la vente ».
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_vente.gd
##
## ⚠ L'ED25519 EST JUGÉ CONTRE D'AUTRES QUE LUI : les vecteurs de la RFC 8032, et des signatures faites par Python
## `cryptography` (OpenSSL) — `vecteurs_ed25519.json`, écrit par `licence_signer.py vecteurs` avec des graines JETABLES.
## ⚠ AUCUNE CLÉ PRIVÉE DE SPANNERGAMES ICI : les clés d'essai sont signées par des graines jetables, et l'appli est
## menée avec la clé publique jetable correspondante (`Vente.cle_publique`).
## ⚠ `reglages.cfg` EST RENDU tel quel à la fin, même en cas d'échec (comme la fumée).

const Licence := preload("res://app/licence.gd")
const Edition := preload("res://app/edition.gd")
const MisesAJour := preload("res://app/mises_a_jour.gd")
const Contrat := preload("res://app/contrat.gd")
const Avis := preload("res://app/avis_tiers.gd")
const Demo := preload("res://app/demo.gd")
const Vente := preload("res://app/vente.gd")
const Associations := preload("res://app/associations.gd")
const Projet := preload("res://app/projet.gd")
const Exemple := preload("res://app/exemple.gd")

const VECTEURS := "res://DEV_TOOLS/vecteurs_ed25519.json"
const REGLAGES := "user://reglages.cfg"
const JETABLES := "user://vente_essai"
const R_ESSAI := "user://vente_essai/reglages.cfg"

## RFC 8032, §7.1, TEST 1 à 3 : graine, publique, message, signature.
const RFC := [
	["9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60",
		"d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a", "",
		"e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"],
	["4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb",
		"3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c", "72",
		"92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00"],
	["c5aa8df43f9f837bedb7442f31dcb7b166d38535076f094b85ce3a2e0b4458f7",
		"fc51cd8e6218a1a38da47ed00230f0580816ed13ba3303ac5deb911548908025", "af82",
		"6291d657deec24024827e69c3abe01a30ce548a284743a445e3680d7db5ac3ac18ff9b538d16f290ae67f760984dc6594a7c15e9716ed28dc027beceea1ec40a"],
]
## L'ordre du groupe d'Ed25519, en petit-boutiste : S + L est la même signature « malléable », qu'il faut REFUSER.
const L_ORDRE := "edd3f55c1a631258d69cf7a2def9de1400000000000000000000000000000010"

var _ok := 0
var _echecs := 0
var _reglages_avant := ""
var _avait_des_reglages := false
var _v: Object


func _initialize() -> void:
	print("=== LA VENTE ===\n")
	_avait_des_reglages = FileAccess.file_exists(REGLAGES)
	if _avait_des_reglages:
		_reglages_avant = FileAccess.get_file_as_string(REGLAGES)
	_mener.call_deferred()


func _mener() -> void:
	# ⚠ LE DOSSIER JETABLE REPART VIDE : un essai d'avant (une mutation qui a écrit dans `dehors`) faussait les suivants
	# — vu le 7 octobre 2026, trois mutations « rouges » pour la mauvaise raison.
	_effacer(ProjectSettings.globalize_path(JETABLES))
	_v = Licence.verificateur()
	_vrai(_v != null, "la bibliothèque native porte MBLicence (sinon, rien d'autre de la clé n'est éprouvé)")
	if _v != null:
		_ed25519()
		_cles()
	_editions()
	_mises_a_jour()
	_exemple_telecharge()
	await _mise_a_jour_hors_ligne()
	_contrat_et_avis()
	_demo()
	_associations()
	await _vente_seule()
	if _v != null:
		await _appli_site()
	await _appli_demo()
	await _appli_steam()
	_finir()


# ── 1. L'ED25519 NATIF, CONTRE LA RFC 8032 ET CONTRE OPENSSL ───────────────────────────────────────────

func _ed25519() -> void:
	print("— Ed25519 —")
	for t in RFC:
		var graine: PackedByteArray = String(t[0]).hex_decode()
		var publique: PackedByteArray = String(t[1]).hex_decode()
		var message: PackedByteArray = String(t[2]).hex_decode()
		var signature: PackedByteArray = String(t[3]).hex_decode()
		_egal(_v.publique_de(graine).hex_encode(), t[1], "RFC 8032 : la publique de la graine %s…" % String(t[0]).left(8))
		_egal(_v.signer(graine, message).hex_encode(), t[3], "RFC 8032 : la signature de « %s »" % t[2])
		_vrai(_v.verifier(publique, message, signature), "RFC 8032 : la signature se vérifie (%s)" % t[2])
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VECTEURS))
	var bons := 0
	var signes := 0
	var faux_refuses := 0
	for e in d["brut"]:
		var g: PackedByteArray = String(e["graine"]).hex_decode()
		var p: PackedByteArray = String(e["publique"]).hex_decode()
		var m: PackedByteArray = String(e["message"]).hex_decode()
		var s: PackedByteArray = String(e["signature"]).hex_decode()
		if _v.verifier(p, m, s):
			bons += 1
		# Ed25519 est déterministe : la MÊME signature, octet pour octet, que celle d'OpenSSL.
		if _v.signer(g, m) == s and _v.publique_de(g) == p:
			signes += 1
		# Un bit changé — dans le message, dans R, dans S, dans la clé — et rien ne passe.
		var refuses := 0
		for cible in ["message", "R", "S", "cle"]:
			var m2 := m.duplicate()
			var s2 := s.duplicate()
			var p2 := p.duplicate()
			match cible:
				"message":
					if m2.is_empty():
						m2.append(0)
					else:
						m2[m2.size() / 2] ^= 0x10
				"R":
					s2[5] ^= 0x01
				"S":
					s2[40] ^= 0x80
				"cle":
					p2[17] ^= 0x04
			if not _v.verifier(p2, m2, s2):
				refuses += 1
		if refuses == 4:
			faux_refuses += 1
	var n: int = (d["brut"] as Array).size()
	_egal(bons, n, "les %d signatures d'OpenSSL (Python cryptography) se vérifient" % n)
	_egal(signes, n, "… et le natif signe EXACTEMENT comme OpenSSL (même publique, même signature)")
	_egal(faux_refuses, n, "… et un bit changé (message, R, S, clé) est refusé, dans les %d cas" % n)
	# La malléabilité : S + L vérifie la même équation, la RFC exige de le refuser.
	var e0: Dictionary = d["brut"][3]
	var s_mall: PackedByteArray = String(e0["signature"]).hex_decode()
	var lo: PackedByteArray = L_ORDRE.hex_decode()
	var retenue := 0
	for k in 32:
		var somme: int = s_mall[32 + k] + lo[k] + retenue
		s_mall[32 + k] = somme & 0xff
		retenue = somme >> 8
	_vrai(not _v.verifier(String(e0["publique"]).hex_decode(), String(e0["message"]).hex_decode(), s_mall),
		"S + L (signature malléable) est refusée")
	_vrai(not _v.verifier(PackedByteArray([1, 2, 3]), PackedByteArray(), PackedByteArray()), "des tailles fausses rendent faux")
	# ⚠ UNE BONNE SIGNATURE SUIVIE D'UN OCTET DE TROP, une clé de 33 octets : refusées (sans la garde des tailles, le
	# natif lirait les 64 / 32 premiers et dirait oui — d'abord muette avec des tableaux vides, 7 octobre 2026).
	var p0: PackedByteArray = String(e0["publique"]).hex_decode()
	var m0: PackedByteArray = String(e0["message"]).hex_decode()
	var s0: PackedByteArray = String(e0["signature"]).hex_decode()
	var s_long := s0.duplicate()
	s_long.append(0)
	var p_long := p0.duplicate()
	p_long.append(0)
	_vrai(_v.verifier(p0, m0, s0) and not _v.verifier(p0, m0, s_long) and not _v.verifier(p_long, m0, s0),
		"une signature de 65 octets, une clé de 33 : refusées")
	_vrai(_v.signer(PackedByteArray([1]), PackedByteArray()).is_empty() and _v.publique_de(PackedByteArray()).is_empty(),
		"une graine qui n'a pas 32 octets ne signe rien")


# ── 2. LES CLÉS ────────────────────────────────────────────────────────────────────────────────────────

## Une clé, faite ici avec la graine `g` (le format de `licence.gd`, signé par le natif).
func _cle(g: PackedByteArray, charge: Dictionary, prefixe := Licence.PREFIXE) -> String:
	var c := JSON.stringify(charge).to_utf8_buffer()
	var m := prefixe.to_utf8_buffer()
	m.append_array(c)
	return prefixe + Licence.vers_base64url(c) + "." + Licence.vers_base64url(_v.signer(g, m))


func _cles() -> void:
	print("— les clés —")
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VECTEURS))
	var pub: String = d["publique_des_cles"]
	for e in d["cles"]:
		var r := Licence.lire(e["cle"], pub)
		_vrai(r["ok"] and r["nom"] == e["nom"] and r["email"] == e["email"],
			"une clé signée par Python se lit ici : « %s » (%s)" % [e["nom"], r.get("raison", "")])
	var cle0: String = d["cles"][0]["cle"]
	# Collée depuis un e-mail : coupée en lignes, des espaces.
	var coupee := ""
	for k in cle0.length():
		coupee += cle0[k] + ("\r\n  " if k % 40 == 39 else "")
	_vrai(Licence.lire("  " + coupee + "\n", pub)["ok"], "une clé coupée en lignes, avec des espaces, se lit")
	_vrai(not Licence.lire(cle0, Licence.CLE_PUBLIQUE)["ok"], "une clé d'essai n'est PAS bonne pour la clé publique livrée")
	_vrai(not Licence.lire(cle0)["ok"], "… ni par défaut")
	# La charge changée (un autre nom), la signature gardée.
	var parts := cle0.split(".")
	var charge: Dictionary = JSON.parse_string(Licence.de_base64url(parts[1]).get_string_from_utf8())
	charge["name"] = "Someone Else"
	var trafiquee := "MBK1." + Licence.vers_base64url(JSON.stringify(charge).to_utf8_buffer()) + "." + parts[2]
	_vrai(not Licence.lire(trafiquee, pub)["ok"], "une clé au nom changé est refusée")
	var g := (d["graine_des_cles"] as String).hex_decode()
	var bonne := _cle(g, {"product": "MarchingBlocks", "name": "Ana", "email": "a@b.c", "id": "x1", "issued": "2026-10-07"})
	var r_bonne := Licence.lire(bonne, pub)
	_vrai(r_bonne["ok"] and r_bonne["nom"] == "Ana" and r_bonne["id"] == "x1" and r_bonne["date"] == "2026-10-07",
		"une clé faite par le natif se relit (nom, id, date)")
	_vrai(not Licence.lire(_cle(g, {"product": "SoluTiles", "name": "Ana", "email": "", "id": "x2", "issued": ""}), pub)["ok"],
		"une clé d'un AUTRE produit, bien signée, est refusée")
	_vrai(not Licence.lire(_cle(g, {"product": "MarchingBlocks", "name": "  ", "email": "", "id": "x3", "issued": ""}), pub)["ok"],
		"une clé sans nom est refusée")
	_vrai(not Licence.lire(bonne, pub, ["x1"] as Array[String])["ok"] and Licence.lire(bonne, pub, ["zz"] as Array[String])["ok"],
		"une clé révoquée (son id) est refusée, les autres non")
	# Le préfixe est SIGNÉ : la même charge signée sans lui (un autre format) ne passe pas.
	var c := JSON.stringify({"product": "MarchingBlocks", "name": "Ana", "email": "", "id": "x4", "issued": ""}).to_utf8_buffer()
	var sans_prefixe := "MBK1." + Licence.vers_base64url(c) + "." + Licence.vers_base64url(_v.signer(g, c))
	_vrai(not Licence.lire(sans_prefixe, pub)["ok"], "une signature de la charge SANS le préfixe « MBK1. » est refusée")
	var refus := 0
	for x in ["", "hello", "MBK1.a.b", "MBK1.!!!.xx", "MBK2." + bonne.trim_prefix("MBK1."), bonne + ".x",
			bonne.left(bonne.length() - 3), "MBK1..", "MBK1." + parts[1] + "."]:
		var r := Licence.lire(x, pub)
		if not r["ok"] and str(r["raison"]) != "":
			refus += 1
	_egal(refus, 9, "neuf textes qui ne sont pas des clés : refusés, chacun avec sa raison")
	_egal(Licence.CLE_PUBLIQUE.length(), 64, "la clé publique livrée : 32 octets en hexadécimal")
	_vrai(Licence.CLE_PUBLIQUE != pub and Licence.CLE_PUBLIQUE != String(RFC[0][1]),
		"la clé publique livrée n'est pas une clé d'essai")
	# Enregistrée, relue.
	DirAccess.make_dir_recursive_absolute(JETABLES)
	DirAccess.remove_absolute(R_ESSAI)
	_vrai(not Licence.en_vigueur(R_ESSAI, pub)["ok"], "sans clé enregistrée, aucune licence")
	Licence.enregistrer("  " + bonne + "\n", R_ESSAI)
	_egal(Licence.en_vigueur(R_ESSAI, pub).get("nom", ""), "Ana", "la clé enregistrée est la licence en vigueur")


# ── 3. LES ÉDITIONS ────────────────────────────────────────────────────────────────────────────────────

func _editions() -> void:
	print("— les éditions —")
	var cas := [
		[[], Edition.DEV, "l'éditeur, les suites"],
		[["template"], Edition.SITE, "un exe exporté SANS balise exige une clé (site)"],
		[["template", "edition_site"], Edition.SITE, "la balise du site"],
		[["template", "edition_steam"], Edition.STEAM, "la balise de Steam"],
		[["template", "edition_demo"], Edition.DEMO, "la balise de la démo"],
		[["template", "edition_steam", "edition_demo"], Edition.DEMO, "Steam + démo : la démo (la plus restreinte)"],
		[["template", "edition_steam", "edition_site"], Edition.SITE, "Steam + site : le site (clé exigée)"],
	]
	for c in cas:
		var balises: Array = c[0]
		_egal(Edition.d_apres(func(b: String) -> bool: return b in balises), c[1], c[2])
	_egal(Edition.nom(), Edition.DEV, "les suites tournent en édition dev")
	Edition.forcee = Edition.DEMO
	_vrai(Edition.est_demo() and Edition.livree(), "forcée en démo : démo, et livrée")
	Edition.forcee = ""


# ── 4. LES MISES À JOUR ────────────────────────────────────────────────────────────────────────────────

## L'EXEMPLE TÉLÉCHARGÉ (Jordan, 18 octobre 2026) : `example.json` lu comme `lire_la_reponse` (rien de faux ne passe),
## et le fichier reçu comparé à sa taille et à son SHA-256 (un octet changé est refusé). Attendus écrits à la main.
func _exemple_telecharge() -> void:
	_egal(Exemple.url_description("https://spannergames.com/marchingblocks/latest.json"),
		"https://spannergames.com/marchingblocks/example.json", "example.json vit à côté de latest.json")
	var sha := "a".repeat(64)
	_egal(Exemple.lire_la_description('{"file": "x.zip", "size": 12, "sha256": "%s", "url": "https://x.test/api/example?f=x.zip"}' % sha),
		{"url": "https://x.test/api/example?f=x.zip", "taille": 12, "sha256": sha}, "une description juste est lue")
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


func _mises_a_jour() -> void:
	print("— les mises à jour —")
	for c in [["0.9.1", "0.9.0", true], ["0.9.0", "0.9.0", false], ["0.8.9", "0.9.0", false], ["0.9.10", "0.9.9", true],
			["1.0", "0.9.9", true], ["0.9.0.1", "0.9.0", true], ["0.9", "0.9.0", false], ["v0.9.2", "0.9.1", true],
			["0.9.1-beta", "0.9.0", true], ["abc", "0.9.0", false], ["", "0.9.0", false], ["0.10.0", "0.9.0", true]]:
		_egal(MisesAJour.plus_recente(c[0], c[1]), c[2], "« %s » plus récente que « %s » : %s" % c)
	var r := MisesAJour.lire_la_reponse('{"version": "0.9.1", "date": "2027-02-12", "notes": "https://x.test/n", "download": "https://x.test/d"}', "0.9.0")
	_egal(r, {"version": "0.9.1", "lien": "https://x.test/d"}, "une réponse plus récente : la version et le lien de téléchargement")
	_egal(MisesAJour.lire_la_reponse('{"version": "0.9.0", "download": "https://x.test/d"}', "0.9.0"), {}, "la même version : rien")
	_egal(MisesAJour.lire_la_reponse('{"version": "0.9.1", "download": "http://x.test/d"}', "0.9.0"),
		{"version": "0.9.1", "lien": ""}, "un lien qui n'est pas en https n'est pas gardé")
	_egal(MisesAJour.lire_la_reponse('{"version": "0.9.1", "download": "file:///c:/x.exe"}', "0.9.0")["lien"], "",
		"… ni un lien file://")
	_egal(MisesAJour.lire_la_reponse("<html>404</html>", "0.9.0"), {}, "une page d'erreur : rien")
	_egal(MisesAJour.lire_la_reponse('[1, 2]', "0.9.0"), {}, "un JSON d'une autre forme : rien")
	_vrai(not MisesAJour.url_remplie(), "l'URL livrée attend encore le domaine (« A-REMPLIR ») : rien ne part")
	_vrai(MisesAJour.url_remplie("https://spannergames.test/mb/latest.json") and not MisesAJour.url_remplie("http://x.test/j"),
		"une URL remplie, en https, part ; en http, non")
	DirAccess.make_dir_recursive_absolute(JETABLES)
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
	var parti: bool = m.lancer("0.9.0", "https://127.0.0.1:9/latest.json")
	_vrai(Time.get_ticks_msec() - t0 < 500, "lancer la vérification ne bloque pas (%d ms)" % (Time.get_ticks_msec() - t0))
	for i in 120:
		await process_frame
	_vrai(not dit[0], "hors ligne, rien n'est dit (requête partie : %s)" % parti)
	_vrai(not m.lancer("0.9.0"), "avec l'URL livrée (à remplir), aucune requête ne part")
	m.queue_free()


# ── 5. LE CONTRAT ET LES AVIS ──────────────────────────────────────────────────────────────────────────

func _contrat_et_avis() -> void:
	print("— le contrat, les avis —")
	var t := Contrat.texte()
	_vrai(t.contains("Contrat de licence d'utilisation") and t.contains("End User License Agreement"),
		"le contrat livré porte le français ET l'anglais")
	_vrai(t.find("Contrat de licence") < t.find("End User License"), "… le français d'abord (il fait foi)")
	_vrai(t.contains("le programme MarchingBlocks") and t.contains("the program MarchingBlocks"), "… au nom du produit")
	_vrai(not t.contains("[NOM DU PRODUIT]") and not t.contains("[À ADAPTER") and not t.contains("[ADAPT"),
		"… sans paragraphe « à adapter » laissé")
	_vrai(t.contains("vérifie au lancement") and t.contains("checks") and t.contains("at launch"),
		"… et l'article des données dit la vérification des mises à jour")
	DirAccess.remove_absolute(R_ESSAI)
	_vrai(not Contrat.accepte(R_ESSAI), "un contrat jamais accepté")
	Contrat.accepter(R_ESSAI)
	_vrai(Contrat.accepte(R_ESSAI), "accepté, c'est retenu")
	var r := ConfigFile.new()
	r.load(R_ESSAI)
	r.set_value("contrat", "accepte", "0")
	r.save(R_ESSAI)
	_vrai(not Contrat.accepte(R_ESSAI), "un contrat accepté dans une AUTRE version se fait accepter de nouveau")
	var a := Avis.texte()
	for mot in ["Godot Engine", "godot-cpp", "Monocypher", "Loup Vaillant", "Open Sans font", "FreeType",
			"OFL-1.1", "Open Font License", "Redistributions in binary form"]:
		_vrai(a.contains(mot), "les avis tiers nomment « %s »" % mot)


# ── 6. LA DÉMO (les règles) ────────────────────────────────────────────────────────────────────────────

func _demo() -> void:
	print("— la démo —")
	# 16 octobre 2026 (Jordan : « tout sauf exporter », « quelque chose d'utilitaire ») : elle enregistre, elle n'exporte pas.
	for q in ["exporter", "tileset", "monde", "patron"]:
		_vrai(Demo.refuse(q), "la démo refuse la sortie « %s »" % q)
	for q in ["ouvrir", "enregistrer", "importer", "texture", "feuillage"]:
		_vrai(not Demo.refuse(q), "la démo permet « %s »" % q)


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


# ── 7. LE PARCOURS DE LANCEMENT, SEUL (quitter) ────────────────────────────────────────────────────────

func _vente_seule() -> void:
	print("— le lancement : quitter —")
	for edition in [Edition.SITE, Edition.STEAM, Edition.DEMO]:
		_reglages_neufs({})
		Edition.forcee = edition
		var v: Node = Vente.new()
		root.add_child(v)
		var res := [null]
		var f := func() -> void: res[0] = await v.au_lancement()
		f.call()
		await process_frame
		_vrai(v.dialogue_contrat != null and v.dialogue_contrat.visible, "%s : le contrat se montre au premier lancement" % edition)
		v.dialogue_contrat.canceled.emit()
		await process_frame
		_egal(res[0], false, "%s : « Quit » sur le contrat — l'appli s'arrête" % edition)
		_vrai(not Contrat.accepte(), "%s : … et le contrat n'est pas retenu" % edition)
		v.queue_free()
	# Le site : contrat accepté, la clé refusée → « Quit ».
	_reglages_neufs({"contrat": {"accepte": Contrat.VERSION}})
	Edition.forcee = Edition.SITE
	var v2: Node = Vente.new()
	root.add_child(v2)
	var res2 := [null]
	var f2 := func() -> void: res2[0] = await v2.au_lancement()
	f2.call()
	await process_frame
	_vrai(v2.dialogue_contrat == null, "site : un contrat déjà accepté ne se remontre pas")
	_vrai(v2.dialogue_cle != null and v2.dialogue_cle.visible, "site : sans clé, la clé est demandée")
	v2.saisie_cle.text = "MBK1.nope.nope"
	v2.activer()
	_vrai(v2.dialogue_cle.visible and v2.erreur_cle.text != "" and res2[0] == null,
		"site : une mauvaise clé est refusée, le dialogue reste, la raison dite (« %s »)" % v2.erreur_cle.text)
	v2.dialogue_cle.canceled.emit()
	await process_frame
	_egal(res2[0], false, "site : « Quit » sur la clé — l'appli s'arrête")
	v2.queue_free()
	# Steam : contrat accepté, aucune clé demandée.
	Edition.forcee = Edition.STEAM
	var v3: Node = Vente.new()
	root.add_child(v3)
	var res3: Variant = await v3.au_lancement()
	_vrai(res3 == true and v3.dialogue_cle == null, "Steam : aucune clé demandée")
	v3.queue_free()
	Edition.forcee = ""


# ── 8. L'APPLI DANS CHAQUE ÉDITION ─────────────────────────────────────────────────────────────────────

func _ecran() -> Control:
	var ed: Control = (load("res://app/editor.tscn") as PackedScene).instantiate()
	root.add_child(ed)
	return ed


func _fermer(ed: Control) -> void:
	ed._toujours_ecrire()
	ed._attendre_l_ecriture()
	root.remove_child(ed)
	ed.free()
	await process_frame


func _appli_site() -> void:
	print("— l'appli, édition site —")
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VECTEURS))
	var pub: String = d["publique_des_cles"]
	var g := (d["graine_des_cles"] as String).hex_decode()
	var cle := _cle(g, {"product": "MarchingBlocks", "name": "Ana Lima", "email": "ana@example.com", "id": "s1", "issued": "2026-10-07"})
	var jetable := _projet_jetable()
	_reglages_neufs({"projet": {"dernier": jetable}})
	Edition.forcee = Edition.SITE
	var ed := _ecran()
	ed._vente.cle_publique = pub
	for i in 4:
		await process_frame
	_vrai(ed._vente.dialogue_contrat != null and ed._vente.dialogue_contrat.visible, "le contrat se montre avant tout projet")
	_egal(ed._projet, "", "… et aucun projet n'est ouvert derrière lui")
	ed._vente.accepter_le_contrat()
	await process_frame
	_vrai(Contrat.accepte(), "« I accept » : retenu")
	_vrai(ed._vente.dialogue_cle != null and ed._vente.dialogue_cle.visible, "puis la clé est demandée")
	ed._vente.saisie_cle.text = cle.substr(0, 30) + "\n" + cle.substr(30)
	ed._vente.activer()
	for i in 10:
		await process_frame
	_vrai(not ed._vente.dialogue_cle.visible, "une bonne clé ferme le dialogue")
	_egal(ed._projet, jetable, "… et le dernier projet s'ouvre ensuite")
	_egal(Licence.cle_enregistree(), cle.substr(0, 30) + "\n" + cle.substr(30), "la clé est retenue")
	_vrai(ed._case_maj.visible, "site : la case des mises à jour est dans Project")
	ed._vente.ouvrir_about()
	var about_texte := _textes(ed._vente.dialogue_about)
	_vrai(about_texte.contains("Licensed to Ana Lima (ana@example.com)") and about_texte.contains("Early Access"),
		"About dit l'édition et à qui la licence est donnée")
	ed._dire_la_mise_a_jour("0.9.1", "https://x.test/d")
	_vrai(ed._bouton_maj.visible and ed._bouton_maj.text == "Update 0.9.1 available", "une mise à jour se dit dans la barre de titre")
	await _fermer(ed)
	# Au lancement suivant : rien ne se remontre.
	var ed2 := _ecran()
	ed2._vente.cle_publique = pub
	for i in 10:
		await process_frame
	_vrai(ed2._vente.dialogue_contrat == null and ed2._vente.dialogue_cle == null, "au lancement suivant : ni contrat, ni clé")
	_egal(ed2._projet, jetable, "… le projet s'ouvre tout de suite")
	_egal(ed2._vente.licence.get("nom", ""), "Ana Lima", "… sous la licence retenue")
	await _fermer(ed2)
	# Une clé enregistrée qui n'est plus bonne (une autre clé publique : un exe d'une autre paire) : redemandée.
	var ed3 := _ecran()
	for i in 6:
		await process_frame
	_vrai(ed3._vente.dialogue_cle != null and ed3._vente.dialogue_cle.visible,
		"une clé retenue qui ne se vérifie pas est redemandée")
	ed3._vente.saisie_cle.text = cle
	ed3._vente.dialogue_cle.hide()
	ed3._vente.fini.emit(true)   # (l'essai continue sans quitter)
	for i in 6:
		await process_frame
	await _fermer(ed3)
	Edition.forcee = ""


func _appli_demo() -> void:
	print("— l'appli, édition démo —")
	var jetable := _projet_jetable()
	_reglages_neufs({"projet": {"dernier": jetable, "monde": jetable}, "contrat": {"accepte": Contrat.VERSION}})
	var md5_avant := FileAccess.get_md5(jetable)
	Edition.forcee = Edition.DEMO
	var dehors := ProjectSettings.globalize_path(JETABLES + "/dehors")
	DirAccess.make_dir_recursive_absolute(dehors)
	var ed := _ecran()
	for i in 10:
		await process_frame
	_egal(ProjectSettings.globalize_path(ed._projet), ProjectSettings.globalize_path(jetable),
		"la démo rouvre « ton monde », comme la version complète")
	_vrai(ed._rapport.text.contains("Free demo"), "… et le rapport dit ce qu'est la démo")
	_vrai(not ed._case_maj.visible, "démo : pas de case des mises à jour")
	for q in ["tileset", "monde", "exporter", "patron"]:
		ed._rapport.text = ""
		ed._demander(q)
		_vrai(not ed._dialogue.visible and ed._rapport.text.contains("Free demo"), "démo : la sortie « %s » refusée, et dite" % q)
	for q in ["enregistrer", "ouvrir"]:
		ed._rapport.text = ""
		ed._demander(q)
		_vrai(ed._dialogue.visible and not ed._rapport.text.contains("Free demo"), "démo : « %s » ouvre son dialogue" % q)
		ed._dialogue.hide()
	# La seconde porte : un choix de fichier de sortie qui arriverait quand même.
	for q in ["tileset", "monde", "patron", "exporter"]:
		ed._action_fichier = q
		ed._rapport.text = ""
		var cible := dehors if q in ["tileset", "monde"] else dehors.path_join("sortie." + ("png" if q == "patron" else "glb"))
		ed._fichier_choisi(cible)
		await process_frame
		_vrai(DirAccess.get_directories_at(dehors).is_empty() and DirAccess.get_files_at(dehors).is_empty()
			and ed._rapport.text.contains("Free demo"), "démo : la sortie « %s » choisie quand même — rien n'est écrit" % q)
	# Un geste : l'enregistrement automatique écrit le projet, là où il est.
	ed._aller_a("monde")
	ed._coup_commence()
	ed._touche({"poser": {Vector3i(0, 0, 0): true}, "effacer": {}}, "Add")
	ed._coup_fini()
	ed._toujours_ecrire()
	ed._attendre_l_ecriture()
	_vrai(FileAccess.get_md5(jetable) != md5_avant and ed._etat_enregistre.text == "✓ Saved",
		"démo : le geste est enregistré dans le projet (✓ Saved)")
	# « Save as » : le projet s'écrit ailleurs, et se relit.
	ed._action_fichier = "enregistrer"
	var copie := dehors.path_join("garde.mbproj")
	ed._fichier_choisi(copie)
	ed._attendre_l_ecriture()
	var err: Array = []
	_vrai(FileAccess.file_exists(copie) and not Projet.depuis_texte(FileAccess.get_file_as_string(copie), err).is_empty()
		and err.is_empty(),
		"démo : « Save as » écrit le projet, lisible")
	DirAccess.remove_absolute(copie)
	# La fermeture ne détruit rien.
	ed._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_vrai(FileAccess.file_exists(jetable), "démo : la fermeture garde le projet")
	root.remove_child(ed)
	ed.free()
	await process_frame
	Edition.forcee = ""


func _appli_steam() -> void:
	print("— l'appli, édition Steam —")
	var jetable := _projet_jetable()
	_reglages_neufs({"projet": {"dernier": jetable}})
	Edition.forcee = Edition.STEAM
	var ed := _ecran()
	for i in 4:
		await process_frame
	_vrai(ed._vente.dialogue_contrat != null and ed._vente.dialogue_contrat.visible, "Steam : le contrat se montre")
	ed._vente.accepter_le_contrat()
	for i in 10:
		await process_frame
	_vrai(ed._vente.dialogue_cle == null, "Steam : aucune clé demandée")
	_egal(ed._projet, jetable, "Steam : le projet s'ouvre")
	_vrai(not ed._case_maj.visible, "Steam : pas de case des mises à jour (Steam livre les siennes)")
	ed._vente.ouvrir_about()
	_vrai(_textes(ed._vente.dialogue_about).contains("Steam account"), "Steam : About dit que la licence vient du compte Steam")
	await _fermer(ed)
	Edition.forcee = ""


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


func _rendre_les_reglages() -> void:
	if _avait_des_reglages:
		var f := FileAccess.open(REGLAGES, FileAccess.WRITE)
		f.store_string(_reglages_avant)
		f.close()
	else:
		DirAccess.remove_absolute(REGLAGES)


func _finir() -> void:
	Edition.forcee = ""
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
