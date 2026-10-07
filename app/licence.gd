extends RefCounted
## LA CLÉ DE LICENCE — édition SITE seulement (charte §0, « la vente » ; DÉCIDÉ par Jordan le 3 octobre 2026 :
## « clé signée nominative, hors ligne, SANS limite de machines »).
##
## Une clé est au nom de l'acheteur, SIGNÉE (Ed25519) par la clé privée de SpannerGames, et vérifiée ICI, HORS LIGNE,
## par la clé publique ci-dessous. Aucune activation, aucun serveur, aucun compte de machines. Le format, écrit UNE
## fois (et recopié tel quel dans `DEV_TOOLS/licence_signer.py`, l'outil de Jordan, puis dans la fonction du site) :
##   MBK1.<charge en base64url sans « = »>.<signature en base64url sans « = »>
##   charge : JSON UTF-8 {"product": "MarchingBlocks", "name", "email", "id", "issued"}
##   signature : Ed25519 (RFC 8032) de « MBK1. » + charge
## ⚠ LA VÉRIFICATION EST NATIVE (`MBLicence`, Monocypher dans la partie privée de la GDExtension) : Godot n'a pas
## Ed25519. Sans la bibliothèque, aucune clé n'est bonne — l'export refuse de toute façon un exe sans elle.
## ⚠ CE QUE ÇA NE FAIT PAS (charte §0, le chiffrement) : rien n'empêche un déterminé de modifier l'exe. La clé rend
## l'achat honnête simple ; le rempart reste la licence (le contrat).

const Natif := preload("res://addons/marchingblocks_core/natif.gd")

const PREFIXE := "MBK1."
const PRODUIT := "MarchingBlocks"
## LA CLÉ PUBLIQUE DE SPANNERGAMES (32 octets). Sa clé privée vit HORS du dépôt :
## `C:/Users/jorda/.marchingblocks/licence_ed25519_privee.hex` (`licence_signer.py publique` la redonne ; l'export
## vérifie que les deux vont ensemble).
const CLE_PUBLIQUE := "4d8d36e46cdfca13d6311fffa92e358e47aa61a4272f7328b3102b62a687cfb6"
## LES CLÉS RÉVOQUÉES (leur "id") — le contrat (art. 11) permet de révoquer une clé diffusée publiquement. Hors ligne,
## une révocation n'atteint que les versions publiées APRÈS elle.
const REVOQUEES: Array[String] = []

const REGLAGES := "user://reglages.cfg"


## Lit une clé : {"ok": bool, "raison": texte d'écran (anglais) si refusée, et ce qu'elle porte — "nom", "email",
## "id", "date"}. `publique` : la clé publique en hexadécimal, `revoquees` : les "id" refusés (les suites donnent
## les leurs, jetables).
static func lire(cle: String, publique := CLE_PUBLIQUE, revoquees: Array[String] = REVOQUEES) -> Dictionary:
	# Une clé collée depuis un e-mail arrive coupée en lignes, avec des espaces : on les ôte tous.
	var nette := ""
	for ch in cle:
		if ch not in [" ", "\t", "\n", "\r"]:
			nette += ch
	if nette == "":
		return _refus("Paste your license key.")
	var parts := nette.split(".")
	if not nette.begins_with(PREFIXE) or parts.size() != 3:
		return _refus("This is not a MarchingBlocks license key (it starts with MBK1.).")
	var charge := de_base64url(parts[1])
	var signature := de_base64url(parts[2])
	if charge.is_empty() or signature.size() != 64:
		return _refus("This key is incomplete — copy it again, in full, from your purchase e-mail.")
	var verificateur: Object = verificateur()
	if verificateur == null:
		return _refus("The license check could not run: MarchingBlocks is incomplete. Reinstall it.")
	var message := PREFIXE.to_utf8_buffer()
	message.append_array(charge)
	if not verificateur.verifier(publique.hex_decode(), message, signature):
		return _refus("This key is not valid — copy it again, in full, from your purchase e-mail.")
	var d: Variant = JSON.parse_string(charge.get_string_from_utf8())
	if not d is Dictionary:
		return _refus("This key is not valid.")
	if str(d.get("product", "")) != PRODUIT:
		return _refus("This key is for another product.")
	var nom := str(d.get("name", "")).strip_edges()
	if nom == "":
		return _refus("This key is not valid.")
	if str(d.get("id", "")) in revoquees:
		return _refus("This key has been revoked. Contact SpannerGames.")
	return {"ok": true, "raison": "", "nom": nom, "email": str(d.get("email", "")), "id": str(d.get("id", "")),
		"date": str(d.get("issued", ""))}


static func _refus(raison: String) -> Dictionary:
	return {"ok": false, "raison": raison}


## Le vérificateur natif (`MBLicence`), ou null si la bibliothèque manque. ⚠ Même quand le natif est ÉTEINT
## (`MB_NATIF=0`) : cet interrupteur choisit la route des calculs, pas la licence.
static func verificateur() -> Object:
	Natif.disponible()   # charge l'extension si elle ne l'est pas
	if not ClassDB.class_exists("MBLicence"):
		return null
	return ClassDB.instantiate("MBLicence")


## base64url sans « = » → octets ; vide si un caractère n'en est pas.
static func de_base64url(s: String) -> PackedByteArray:
	if s == "":
		return PackedByteArray()
	for ch in s:
		if not (ch >= "A" and ch <= "Z" or ch >= "a" and ch <= "z" or ch >= "0" and ch <= "9" or ch == "-" or ch == "_"):
			return PackedByteArray()
	if s.length() % 4 == 1:
		return PackedByteArray()
	var b := s.replace("-", "+").replace("_", "/")
	while b.length() % 4 != 0:
		b += "="
	return Marshalls.base64_to_raw(b)


## octets → base64url sans « = » (les suites signent avec).
static func vers_base64url(o: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(o).replace("+", "-").replace("/", "_").rstrip("=")


## La clé enregistrée (texte brut), "" s'il n'y en a pas.
static func cle_enregistree(reglages_chemin := REGLAGES) -> String:
	var r := ConfigFile.new()
	r.load(reglages_chemin)
	return str(r.get_value("licence", "cle", ""))


static func enregistrer(cle: String, reglages_chemin := REGLAGES) -> void:
	var r := ConfigFile.new()
	r.load(reglages_chemin)
	r.set_value("licence", "cle", cle.strip_edges())
	r.save(reglages_chemin)


## La licence en vigueur : la clé enregistrée, lue. {"ok": false} s'il n'y en a pas.
static func en_vigueur(reglages_chemin := REGLAGES, publique := CLE_PUBLIQUE) -> Dictionary:
	var cle := cle_enregistree(reglages_chemin)
	if cle == "":
		return _refus("")
	return lire(cle, publique)
