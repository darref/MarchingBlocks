extends SceneTree
##
## TEST — le projet et ses couches (`app/projet.gd`), et la grille locale de la vue (`app/vue.gd`).
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_projet.gd
##
## ⚠ **CE QUI EST GARDÉ, C'EST CE QU'ON PERDRAIT SANS LE VOIR** : un monde qui revient avec une case en
## moins, un fichier abîmé lu à moitié puis réécrit par l'enregistrement automatique, un lot en cache
## cru à jour alors que l'artiste a réenregistré son `.glb`. Les attendus sont écrits à la main.

const Projet := preload("res://app/projet.gd")
const Vue := preload("res://app/vue.gd")

const DOSSIER := "user://test_projet"

var _ok := 0
var _echecs := 0


func _initialize() -> void:
	print("=== TEST — le projet et ses couches ===\n")
	DirAccess.make_dir_recursive_absolute(DOSSIER)

	# ── 1. L'aller-retour d'un projet à deux couches ──────────────────────────────────────────────
	var roche := Projet.couche("Roche")
	roche["source"] = Projet.TEMOIN
	roche["cases"] = {Vector3i(0, 0, 0): true, Vector3i(-3, 2, 41): true, Vector3i(100, -7, -64): true}
	var glace := Projet.couche("Glace")
	glace["source"] = "D:/quelque/part/glace.glb"
	glace["visible"] = false
	var texte := Projet.vers_texte([roche, glace], 1)
	var erreurs: Array = []
	var relu: Dictionary = Projet.depuis_texte(texte, erreurs)
	_vrai(erreurs.is_empty(), "un projet bien formé se relit sans erreur")
	_egal(relu.get("active", -1), 1, "la couche active revient")
	var couches: Array = relu.get("couches", [])
	_egal(couches.size(), 2, "les deux couches reviennent")
	if couches.size() == 2:
		_egal(couches[0]["nom"], "Roche", "le nom revient")
		_egal(couches[0]["source"], "witness", "la source témoin revient")
		_egal(couches[1]["visible"], false, "une couche cachée reste cachée")
		_egal(couches[1]["source"], "D:/quelque/part/glace.glb", "le chemin du travail revient")
		var cases: Dictionary = couches[0]["cases"]
		_egal(cases.size(), 3, "les trois cases reviennent, pas une de plus")
		for p in [Vector3i(0, 0, 0), Vector3i(-3, 2, 41), Vector3i(100, -7, -64)]:
			_vrai(cases.has(p), "la case %s revient À SA PLACE (coordonnées négatives comprises)" % p)
		_egal(couches[1]["cases"].size(), 0, "une couche vide revient vide")

	# ── 1 bis. Une couche possède SON témoin (30 septembre 2026) : son chemin et son id reviennent ────────
	var a := Projet.couche("A", "3")
	a["temoin"] = "D:/projets/monde_3.mbtiles"
	var relu_a: Dictionary = Projet.depuis_texte(Projet.vers_texte([a], 0), [])
	_egal(relu_a["couches"][0]["temoin"], "D:/projets/monde_3.mbtiles", "le témoin d'une couche revient")
	_egal(relu_a["couches"][0]["id"], "3", "l'identifiant d'une couche revient")
	var d_avant: Dictionary = Projet.depuis_texte(
		'{"format": "marchingblocks-project", "version": 1, "couches": [{"nom": "old", "source": "witness", "cases": []}]}', [])
	_vrai(d_avant["couches"][0]["temoin"] == "" and d_avant["couches"][0]["id"] == "",
		"un projet d'avant (sans témoin ni id par couche) se relit : aucun témoin à la couche")

	# ── 2. Un fichier abîmé est refusé EN ENTIER ─────────────────────────────────────────────────
	for cas in [
		["pas du json {", "du texte qui n'est pas du JSON"],
		['{"format": "autre", "version": 1, "couches": [{}]}', "un autre format"],
		['{"format": "marchingblocks-project", "version": 99, "couches": [{}]}', "une version plus récente"],
		['{"format": "marchingblocks-project", "version": 1, "couches": []}', "aucune couche"],
		['{"format": "marchingblocks-project", "version": 1, "couches": [{"cases": [1, 2]}]}',
			"des cases qui ne sont pas des triplets"],
		['{"format": "marchingblocks-project", "version": 1, "couches": [{"nom": "a"}, 3]}',
			"une couche qui n'est pas un objet — même après une couche saine"],
	]:
		var e: Array = []
		_vrai(Projet.depuis_texte(cas[0], e).is_empty() and not e.is_empty(), "refusé, avec sa raison : %s" % cas[1])

	var e2: Array = []
	var borne: Dictionary = Projet.depuis_texte(
		'{"format": "marchingblocks-project", "version": 1, "active": 9, "couches": [{}, {}]}', e2)
	_egal(borne.get("active", -1), 1, "une couche active hors de la liste est ramenée dans la liste")

	# ── 3. Le cache n'est cru que si la source n'a pas changé ────────────────────────────────────
	var source := DOSSIER + "/travail.glb"
	_ecrire(source, "premiere version")
	var lot := MeshLibrary.new()
	lot.create_item(0)
	lot.set_item_name(0, "mb_essai")
	_egal(Projet.mettre_en_cache(lot, source), "", "le lot s'écrit en cache")
	var lu: Dictionary = Projet.lire_cache(source)
	_vrai(lu["lot"] != null and lu["a_jour"], "relu aussitôt, le cache est à jour")
	if lu["lot"] != null:
		_egal((lu["lot"] as MeshLibrary).get_item_name(0), "mb_essai", "le cache rend le même lot")
	# Un cache d'avant la provenance (format 1) : même source, même empreinte, mais PÉRIMÉ — sinon « d'où
	# vient cette tuile ? » resterait muet sur un lot qui ne sait pas le dire.
	var ancien := MeshLibrary.new()
	ancien.set_meta("empreinte", Projet.empreinte(source))
	ResourceSaver.save(ancien, Projet.chemin_cache(source), ResourceSaver.FLAG_COMPRESS)
	_vrai(not Projet.lire_cache(source)["a_jour"], "un cache d'un format plus ancien est PÉRIMÉ")
	Projet.mettre_en_cache(lot, source)

	# Réenregistrer le fichier change sa taille : l'empreinte doit bouger.
	_ecrire(source, "seconde version, plus longue")
	lu = Projet.lire_cache(source)
	_vrai(not lu["a_jour"], "le travail réenregistré rend le cache PÉRIMÉ")
	_vrai(lu["lot"] != null, "un cache périmé est quand même rendu — c'est tout ce qui reste si la source part")

	DirAccess.remove_absolute(source)
	_egal(Projet.empreinte(source), "", "une source disparue n'a pas d'empreinte")
	_vrai(not Projet.lire_cache(source)["a_jour"], "une source disparue n'est jamais « à jour »")
	_egal(Projet.empreinte(""), "", "une couche sans source n'a pas d'empreinte")
	DirAccess.remove_absolute(Projet.chemin_cache(source))

	# ── 4. La grille locale : où s'arrête la grille centrale ─────────────────────────────────────
	# DEMI_GRILLE = 24 : lignes de −24 à +24, donc cases de −24 à 23.
	_vrai(Vue.sur_la_grille_centrale(Vector3i(0, 0, 0)), "le centre est sur la grille centrale")
	_vrai(Vue.sur_la_grille_centrale(Vector3i(-24, 3, 23)), "la case −24 / 23 est la dernière couverte")
	_vrai(not Vue.sur_la_grille_centrale(Vector3i(24, 0, 0)), "la case 24 en x déborde : grille locale")
	_vrai(not Vue.sur_la_grille_centrale(Vector3i(0, 0, -25)), "la case −25 en z déborde : grille locale")

	_les_fichiers_dans_windows()

	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	print("VERDICT : %s" % ("OK" if _echecs == 0 else "ÉCHEC"))
	quit(0 if _echecs == 0 else 1)


func _ecrire(chemin: String, texte: String) -> void:
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string(texte)
	f.close()


func _vrai(v: bool, quoi: String) -> void:
	if v:
		_ok += 1
	else:
		_echecs += 1
		print("  ✗ " + quoi)


func _egal(a, b, quoi: String) -> void:
	if a == b:
		_ok += 1
	else:
		_echecs += 1
		print("  ✗ %s — rendu %s, attendu %s" % [quoi, a, b])


## ── 5. LES FICHIERS DANS WINDOWS (Jordan, 30 septembre 2026) : icônes et double-clic ─────────────────────
## ⚠ Seules les fonctions PURES : le registre n'est jamais touché par un test. Les attendus sont relus dans les
## OCTETS et le TEXTE produits, pas recalculés par les fonctions éprouvées.
func _les_fichiers_dans_windows() -> void:
	const A := preload("res://app/associations.gd")
	# Le .ico : en-tête (réservé 0, type 1, 4 images), et chaque entrée pointe une vraie image PNG.
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.4, 0.7, 0.3))
	var ico: PackedByteArray = A.ico_depuis_image(img)
	_vrai(ico.decode_u16(0) == 0 and ico.decode_u16(2) == 1 and ico.decode_u16(4) == 4, "le .ico a l'en-tête d'une icône à 4 images")
	var pngs_justes := true
	var tailles: Array = []
	for k in 4:
		var e := 6 + 16 * k
		var taille := int(ico[e]) if ico[e] != 0 else 256
		tailles.append(taille)
		var longueur := ico.decode_u32(e + 8)
		var debut := ico.decode_u32(e + 12)
		var png := ico.slice(debut, debut + longueur)
		var relu := Image.new()
		pngs_justes = pngs_justes and png.slice(0, 8) == PackedByteArray([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]) \
			and relu.load_png_from_buffer(png) == OK and relu.get_width() == taille
	_vrai(pngs_justes and tailles == [256, 48, 32, 16], "chaque entrée du .ico est un PNG de sa taille (%s)" % [tailles])
	# Le .reg : la partie utilisateur SEULEMENT, les chaînes échappées, un chemin accentué intact.
	var exe := "C:/Users/Jérôme D/Jeux/MarchingBlocks.exe"
	var texte: String = A.texte_d_inscription(exe, "C:/Users/Jérôme D/AppData/icones")
	_vrai(texte.begins_with("Windows Registry Editor Version 5.00") and not texte.contains("HKEY_LOCAL_MACHINE")
		and texte.contains(r"[HKEY_CURRENT_USER\Software\Classes\.mbproj]"), "le .reg n'écrit QUE dans la partie de l'utilisateur")
	# ⚠ CHAÎNES BRUTES (r"…") : l'attendu se lit tel qu'il est dans le fichier .reg, sans double échappement.
	_vrai(texte.contains(r'@="\"C:\\Users\\Jérôme D\\Jeux\\MarchingBlocks.exe\" \"%1\""'),
		"le double-clic lance l'exe, guillemets et « %1 » échappés, chemin accentué intact")
	_vrai(texte.contains(r"[HKEY_CURRENT_USER\Software\Classes\MarchingBlocks.Project\DefaultIcon]")
		and texte.contains(r'icones\\projet.ico"') and texte.contains(r'icones\\temoin.ico"'), "chaque type a son icône")
	_vrai(not texte.contains(r"MarchingBlocks.Witness\shell"), "un témoin (.mbtiles) ne s'ouvre pas seul : pas de double-clic")
	var retrait: String = A.texte_de_desinscription()
	_vrai(retrait.contains(r"[-HKEY_CURRENT_USER\Software\Classes\.mbproj]")
		and retrait.contains(r"[-HKEY_CURRENT_USER\Software\Classes\MarchingBlocks.Project]"), "la désinscription efface ce que l'inscription a posé")
	_egal(A.desktop_ini("C:/x/dossier_tuiles.ico"), "[.ShellClassInfo]\r\n" + r"IconResource=C:\x\dossier_tuiles.ico,0" + "\r\n",
		"le desktop.ini d'un dossier désigne son icône")
	# Le projet reçu par double-clic : un .mbproj qui EXISTE, rien d'autre.
	var vrai_projet := ProjectSettings.globalize_path(DOSSIER).path_join("double_clic.mbproj")
	_ecrire(vrai_projet, "{}")
	_egal(A.projet_en_argument(PackedStringArray(["--quelque-chose", vrai_projet])), vrai_projet, "le .mbproj passé en argument est ouvert")
	_egal(A.projet_en_argument(PackedStringArray(["C:/absent.mbproj", "D:/x.glb"])), "", "ni un projet absent, ni un autre fichier")
	DirAccess.remove_absolute(vrai_projet)
	# S'inscrire : au premier lancement, quand l'exe a bougé ou changé de version — jamais après un refus.
	var r := ConfigFile.new()
	_vrai(A.a_inscrire(r, "C:/a.exe", "0.1"), "premier lancement : on s'inscrit")
	r.set_value("associations", "exe", "C:/a.exe")
	r.set_value("associations", "version", "0.1")
	_vrai(not A.a_inscrire(r, "C:/a.exe", "0.1"), "déjà inscrit, même exe, même version : rien")
	_vrai(A.a_inscrire(r, "D:/ailleurs/a.exe", "0.1") and A.a_inscrire(r, "C:/a.exe", "0.2"), "exe déplacé ou nouvelle version : on se réinscrit")
	r.set_value("associations", "refus", true)
	_vrai(not A.a_inscrire(r, "D:/ailleurs/a.exe", "0.2"), "après un refus (la case décochée), plus jamais d'inscription automatique")
