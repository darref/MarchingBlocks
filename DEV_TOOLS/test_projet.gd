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
const Exemple := preload("res://app/exemple.gd")

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

	# ── 1 ter. LES CASES D'UN BLOC (2 octobre 2026) : un tableau de cases (`get_used_cells`) s'écrit comme un
	# dictionnaire, sur UNE ligne (l'ancien JSON posait un nombre par ligne : 4,8 Mo pour l'exemple), et se relit
	# case pour case. Attendu écrit à la main.
	var bloc := Projet.couche("Bloc")
	bloc["cases"] = [Vector3i(1, 2, 3), Vector3i(-4, -5, -6)]
	var texte_bloc := Projet.vers_texte([bloc], 0)
	_vrai(texte_bloc.contains("[1, 2, 3, -4, -5, -6]"), "un tableau de cases s'écrit d'un bloc, sur une ligne")
	var relu_bloc: Dictionary = Projet.depuis_texte(texte_bloc, [])
	_egal(relu_bloc.get("couches", [{}])[0].get("cases", {}).keys(), [Vector3i(1, 2, 3), Vector3i(-4, -5, -6)],
		"… et se relit case pour case")
	_vrai(not texte_bloc.contains("@@"), "… sans marque oubliée dans le fichier")

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

	# ── 1 ter. Les couches d'EAU (1er octobre 2026) : seules les sources s'enregistrent, et elles reviennent ──
	var mer := Projet.couche_d_eau("Sea", "1")
	mer["sources"] = [Vector3i(40, 2, -9)]
	var rivieres := Projet.couche_d_eau("Rivers", "4")
	rivieres["visible"] = false
	rivieres["sources"] = [Vector3i(3, 7, 3), Vector3i(-5, 0, 12)]
	var relu_e: Dictionary = Projet.depuis_texte(Projet.vers_texte([a], 0, [mer, rivieres]), [])
	var eaux: Array = relu_e.get("eaux", [])
	_egal(eaux.size(), 2, "les deux couches d'eau reviennent")
	if eaux.size() == 2:
		_egal([eaux[0]["nom"], eaux[0]["id"], eaux[0]["preset"], eaux[0]["visible"]], ["Sea", "1", "stylise", true],
			"une couche d'eau revient : nom, id, preset, visible")
		_egal(eaux[1]["visible"], false, "une couche d'eau cachée reste cachée")
		_egal(eaux[1]["sources"], [Vector3i(3, 7, 3), Vector3i(-5, 0, 12)],
			"ses sources reviennent DANS L'ORDRE, coordonnées négatives comprises")
	_egal(d_avant.get("eaux", null), [], "un projet d'avant l'eau se relit sans couche d'eau")

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
		['{"format": "marchingblocks-project", "version": 1, "couches": [{}], "eaux": [{"sources": [1, 2]}]}',
			"des sources d'eau qui ne sont pas des triplets"],
		['{"format": "marchingblocks-project", "version": 1, "couches": [{}], "eaux": 5}',
			"des couches d'eau qui ne sont pas une liste"],
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
	_l_exemple()

	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	print("VERDICT : %s" % ("OK" if _echecs == 0 else "ÉCHEC"))
	quit(0 if _echecs == 0 else 1)


## L'EXEMPLE LIVRÉ (2 octobre 2026) : une archive bâtie ICI, à la main — les attendus ne passent pas par l'emballeur.
func _archive(chemin: String, fichiers: Dictionary) -> void:
	var z := ZIPPacker.new()
	z.open(chemin)
	for n in fichiers:
		z.start_file(n)
		z.write_file(fichiers[n] if fichiers[n] is PackedByteArray else str(fichiers[n]).to_utf8_buffer())
		z.close_file()
	z.close()


func _l_exemple() -> void:
	var racine := DOSSIER + "/exemple"
	var archive := DOSSIER + "/exemple.zip"
	_vider(racine)   # une installation d'un passage précédent fausserait « s'installe » et « n'écrase pas »
	var png := PackedByteArray([137, 80, 78, 71, 0, 255, 1, 2])
	_archive(archive, {
		"example.mbproj": '{"source": "{EXEMPLE}/example_witness.glb", "temoin": "{EXEMPLE}/example_witness.mbtiles"}',
		"example_witness.mbtiles": '{"image": "{EXEMPLE}/example_witness_images/a.png"}',
		"example_witness_images/a.png": png,
		"STAMP": "0123456789abcdef0123",
	})
	var erreurs: Array = []
	var chemin := Exemple.installer(archive, racine, erreurs)
	var dossier := ProjectSettings.globalize_path(racine).path_join("0123456789ab")
	_egal(chemin, dossier.path_join("example.mbproj"), "l'exemple s'installe dans un dossier nommé par son STAMP")
	_egal(FileAccess.get_file_as_string(chemin),
		'{"source": "%s/example_witness.glb", "temoin": "%s/example_witness.mbtiles"}' % [dossier, dossier],
		"les chemins du projet pointent dans le dossier d'installation")
	_egal(FileAccess.get_file_as_string(dossier.path_join("example_witness.mbtiles")),
		'{"image": "%s/example_witness_images/a.png"}' % dossier, "… et ceux du témoin aussi")
	_egal(FileAccess.get_file_as_bytes(dossier.path_join("example_witness_images/a.png")), png,
		"une image est copiée telle quelle, octet pour octet")
	_vrai(not FileAccess.file_exists(dossier.path_join("STAMP")), "le STAMP n'est pas copié")
	# L'utilisateur modifie l'exemple : le réinstaller ne l'écrase pas.
	_ecrire(chemin, "modifié par l'utilisateur")
	_egal(Exemple.installer(archive, racine), chemin, "réinstaller rend le même projet")
	_egal(FileAccess.get_file_as_string(chemin), "modifié par l'utilisateur", "… sans écraser ce qu'on y a fait")
	# Un exemple plus récent va dans un AUTRE dossier.
	_archive(archive, {"example.mbproj": "v2", "STAMP": "fedcba9876543210"})
	var v2 := Exemple.installer(archive, racine)
	_vrai(v2.contains("fedcba987654") and FileAccess.get_file_as_string(v2) == "v2"
		and FileAccess.get_file_as_string(chemin) == "modifié par l'utilisateur",
		"un exemple plus récent s'installe à côté, l'ancien reste")
	# Refus.
	_archive(archive, {"example.mbproj": "{}"})
	erreurs = []
	_vrai(Exemple.installer(archive, racine, erreurs) == "" and not erreurs.is_empty(), "une archive sans STAMP est refusée")
	erreurs = []
	_vrai(Exemple.installer(DOSSIER + "/absente.zip", racine, erreurs) == "" and not erreurs.is_empty(),
		"pas d'archive : refusé, et dit")


func _vider(dossier: String) -> void:
	var d := DirAccess.open(dossier)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	for s in d.get_directories():
		_vider(dossier.path_join(s))
		d.remove(s)


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
	_l_icone_d_un_dossier()


## L'ICÔNE D'UN DOSSIER EXPORTÉ, POSÉE POUR DE VRAI (Windows seulement) : un `desktop.ini` caché, le dossier en
## lecture seule. ⚠ MESURÉ DANS L'EXE le 1er octobre 2026 : `attrib` lancé par `OS.execute` refusait ses arguments
## en rendant 0, et rien n'était posé. L'attendu est relu par `attrib` lui-même (une autre autorité que Godot),
## sur un dossier jetable et des icônes de test — jamais celles de l'appli.
func _l_icone_d_un_dossier() -> void:
	if OS.get_name() != "Windows":
		return
	const A := preload("res://app/associations.gd")
	var racine := ProjectSettings.globalize_path(DOSSIER)
	var icones := racine.path_join("icones")
	var dossier := racine.path_join("essai.mbset")
	_vrai(A.ecrire_les_icones(icones) == "", "les icônes de test sont écrites")
	DirAccess.make_dir_recursive_absolute(dossier)
	var marque_1: bool = A.marquer_dossier(dossier, icones)
	_ecrire(dossier.path_join("tileset.json"), "{}")   # un export qui repasse dans un dossier déjà marqué
	var marque_2: bool = A.marquer_dossier(dossier, icones)
	_vrai(marque_1 and marque_2, "le dossier est marqué, et se re-marque (desktop.ini caché réécrit)")
	_vrai(_attributs(dossier).contains("R"), "le dossier est en lecture seule (relu par attrib : « %s »)" % _attributs(dossier))
	_vrai(_attributs(dossier.path_join("desktop.ini")).contains("H"), "son desktop.ini est caché (relu par attrib)")
	var ini := FileAccess.open(dossier.path_join("desktop.ini"), FileAccess.READ)
	var octets := ini.get_buffer(ini.get_length()) if ini != null else PackedByteArray()
	ini = null   # ⚠ refermé : Windows ne supprime pas un fichier ouvert, et le ménage échouait sans un mot
	_vrai(octets.size() > 2 and octets[0] == 0xff and octets[1] == 0xfe
		and octets.slice(2).get_string_from_utf16().contains(r"icones\dossier_tuiles.ico,0"),
		"son desktop.ini (UTF-16) désigne l'icône des jeux de tuiles")
	_vrai(not A.marquer_dossier(racine.path_join("autre.txt"), icones), "un dossier qui n'est ni .mbset ni .mbworld n'est pas marqué")
	# Ménage : lecture seule ôtée, puis tout supprimé.
	FileAccess.set_read_only_attribute(dossier, false)
	FileAccess.set_hidden_attribute(dossier.path_join("desktop.ini"), false)
	for f in ["desktop.ini", "tileset.json"]:
		DirAccess.remove_absolute(dossier.path_join(f))
	DirAccess.remove_absolute(dossier)
	for f in DirAccess.get_files_at(icones):
		DirAccess.remove_absolute(icones.path_join(f))
	DirAccess.remove_absolute(icones)


## Les lettres d'attributs que `attrib` affiche devant le chemin (A, H, R, S…).
func _attributs(chemin: String) -> String:
	var sortie: Array = []
	OS.execute("attrib", [chemin.replace("/", "\\")], sortie, true)
	var ligne := "".join(PackedStringArray(sortie))
	var i := ligne.find(chemin.replace("/", "\\").substr(0, 3))
	return ligne.substr(0, i).strip_edges() if i > 0 else ""
