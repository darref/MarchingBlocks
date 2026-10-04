extends SceneTree
##
## PRENDRE L'EXEMPLE — emballe la SOURCE de l'exemple (`dev_exemple.gd` : `~/.marchingblocks/exemple_source.txt`,
## sinon `C:/Users/jorda/Documents/MarchingBlocks/test/test.mbproj`) dans
## `res://exemple/exemple.zip`, l'exemple que l'exe livre (`app/exemple.gd`). DÉCIDÉ (Jordan, 2 octobre 2026) : il
## suit ses modifications tant que le développement n'est pas clos, puis il est FIGÉ.
##
## LANCEMENT (et `exporter_marchingblocks.sh` le lance avant chaque export) :
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/prendre_l_exemple.gd [-- --projet=<chemin>]
##
## ⚠ **FIGÉ** : si `res://exemple/FIGE` existe, rien n'est repris — l'archive en place est celle qui part.
## ⚠ **ON NE TOUCHE À RIEN CHEZ JORDAN** : tout est LU ; les `.glb` des témoins sont écrits dans un dossier
##   temporaire, jamais à côté de son projet.
## ⚠ **LE .glb D'UN TÉMOIN EST REFAIT DEPUIS SON .mbtiles** : chez Jordan il peut manquer (la couche tient alors
##   de son cache, que l'acheteur n'a pas) ; sans lui, l'exemple s'ouvrirait en cubes rouges.
## ⚠ **LES CHEMINS ABSOLUS DEVIENNENT `{EXEMPLE}/…`**, et le nom du projet « example » : `test_witness.mbtiles`
##   part en `example_witness.mbtiles`. Un chemin référencé qui n'existe pas est DIT, et laissé tel quel.

const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const Projet := preload("res://app/projet.gd")
const Exemple := preload("res://app/exemple.gd")
const SOURCE_DEFAUT := "C:/Users/jorda/Documents/MarchingBlocks/test/test.mbproj"
const SORTIE := "res://exemple/exemple.zip"
const FIGE := "res://exemple/FIGE"
const NOM := "example"
## Retire la liste des travaux importés (`"travaux": [...]`) du texte d'un projet.
const REGLE_TRAVAUX := ",\\s*\"travaux\":\\s*\\[[^\\]]*\\]"


func _initialize() -> void:
	# LA SOURCE est celle du mode dev (`dev_exemple.gd` : `~/.marchingblocks/exemple_source.txt`, sinon SOURCE_DEFAUT).
	# ⚠ `load`, pas `preload` : `dev_exemple.gd` précharge ce script-ci.
	var source: String = load("res://DEV_TOOLS/dev_exemple.gd").source()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--projet="):
			source = a.substr("--projet=".length())
	if FileAccess.file_exists(FIGE):
		print("EXEMPLE : figé (%s) — l'archive en place part telle quelle." % FIGE)
		quit(0)
		return
	var raison := prendre(source, ProjectSettings.globalize_path(SORTIE))
	if raison != "":
		print("⚠ EXEMPLE NON PRIS : ", raison)
		quit(1)
		return
	quit(0)


## Rend "" ou la raison de l'échec.
static func prendre(source: String, sortie: String) -> String:
	if not FileAccess.file_exists(source):
		return "projet introuvable : " + source
	var dossier := source.get_base_dir()
	var base := source.get_file().get_basename()
	var texte := FileAccess.get_file_as_string(source)
	# Les travaux importés (étape 2) sont des raccourcis de l'auteur, pas de l'exemple : retirés (sinon ses `.glb`
	# partiraient dans l'archive).
	texte = RegEx.create_from_string(REGLE_TRAVAUX).sub(texte, "")
	var etat = JSON.parse_string(texte)
	if not (etat is Dictionary) or not etat.has("couches"):
		return "projet illisible : " + source
	var tmp := OS.get_temp_dir().path_join("mb_exemple")
	DirAccess.make_dir_recursive_absolute(tmp)
	# {chemin absolu d'origine: octets} — les .glb refaits sont rangés sous le chemin qu'ils AURAIENT chez Jordan.
	var fichiers := {source: texte.to_utf8_buffer()}
	var textes := {source: texte}
	for c in etat["couches"]:
		var temoin := str(c.get("temoin", ""))
		if temoin == "" or not FileAccess.file_exists(temoin):
			continue
		var t_texte := FileAccess.get_file_as_string(temoin)
		textes[temoin] = t_texte
		fichiers[temoin] = t_texte.to_utf8_buffer()
		var d = JSON.parse_string(t_texte)
		var t: RefCounted = TL.depuis_dictionnaire(d) if d is Dictionary else null
		if t == null:
			return "témoin illisible : " + temoin
		var glb := temoin.get_basename() + ".glb"
		var ecrit := tmp.path_join(glb.get_file())
		var r: String = t.vers_glb(ecrit)
		if r != "":
			return "le .glb de %s n'a pas pu être écrit : %s" % [temoin, r]
		fichiers[glb] = FileAccess.get_file_as_bytes(ecrit)
		var s := str(c.get("source", ""))
		if s != "" and s != Projet.TEMOIN and s != glb:
			if FileAccess.file_exists(s):
				fichiers[s] = FileAccess.get_file_as_bytes(s)
			else:
				print("  ⚠ source absente, laissée telle quelle : ", s)
	# Les chemins absolus cités dans les textes (images des matériaux, sources) : on emporte ceux qui existent.
	var re := RegEx.create_from_string("\"([A-Za-z]:/[^\"]+)\"")
	for chemin in textes.keys():
		for m in re.search_all(textes[chemin]):
			var p := m.get_string(1)
			if fichiers.has(p):
				continue
			if FileAccess.file_exists(p):
				fichiers[p] = FileAccess.get_file_as_bytes(p)
			else:
				print("  ⚠ chemin cité absent, laissé tel quel : ", p)
	# Le nom de chaque fichier dans l'archive, et la table de réécriture.
	var noms := {}
	for p in fichiers:
		var rel: String = p.substr(dossier.length() + 1) if p.begins_with(dossier + "/") else "external/" + p.get_file()
		if rel.begins_with(base):
			rel = NOM + rel.substr(base.length())
		noms[p] = rel
	var ordre: Array = noms.keys()
	ordre.sort_custom(func(a, b): return a.length() > b.length())
	var z := ZIPPacker.new()
	DirAccess.make_dir_recursive_absolute(sortie.get_base_dir())
	if z.open(sortie) != OK:
		return "archive impossible à écrire : " + sortie
	var empreinte := HashingContext.new()
	empreinte.start(HashingContext.HASH_MD5)
	var tailles := 0
	var cles: Array = noms.keys()
	cles.sort_custom(func(a, b): return noms[a] < noms[b])
	for p in cles:
		var octets: PackedByteArray = fichiers[p]
		if textes.has(p):
			var t2: String = textes[p]
			for q in ordre:
				t2 = t2.replace(q, Exemple.MARQUE + "/" + noms[q])
			octets = t2.to_utf8_buffer()
		z.start_file(noms[p])
		z.write_file(octets)
		z.close_file()
		empreinte.update(noms[p].to_utf8_buffer())
		empreinte.update(octets)
		tailles += octets.size()
	z.start_file("STAMP")
	var marque := empreinte.finish().hex_encode()
	z.write_file(marque.to_utf8_buffer())
	z.close_file()
	z.close()
	print("EXEMPLE : %d fichiers, %.1f Mo, empreinte %s → %s" % [noms.size(), tailles / 1048576.0, marque.substr(0, 12), sortie])
	for p in cles:
		print("  ", noms[p])
	return ""
