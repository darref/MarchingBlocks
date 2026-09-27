extends SceneTree
##
## SONDE — LA LECTURE D'UN `.glb` EST-ELLE REPRODUCTIBLE ?
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_lecture_stable.gd -- --fichier=C:/chemin.glb [--fois=5]
##
## ── POURQUOI ELLE EXISTE ────────────────────────────────────────────────────────────────────────────
##
## ⚠ **DEUX DE MES PROPRES SONDES SE SONT CONTREDITES SUR LE MÊME FAIT.** Le même fichier, lu par le
## même code à vingt minutes d'intervalle, a rendu `UV oui · texture OUI · cull=2` puis
## `UV NON · texture aucune · cull=0`. Tant que ce n'est pas tranché, **toutes** les conclusions tirées
## de ces attributs cette nuit sont suspendues — y compris « il n'y a pas de bogue de matériau », que
## j'ai écrit dans un message de commit.
##
## ── CE QU'ELLE SÉPARE ───────────────────────────────────────────────────────────────────────────────
##
##   • **l'empreinte du fichier**, relevée à chaque tour : si elle change, il n'y a aucun mystère —
##     c'est un autre fichier, et c'est la première chose à écarter ;
##   • **la variation DANS une même exécution** → c'est l'état de Godot (cache, ordre de chargement) ;
##   • **la variation ENTRE exécutions** → c'est l'environnement du projet (configuration, import).
##
## ⚠ Sans ce partage je ne saurais même pas quoi soupçonner, et j'ai déjà poursuivi quatre causes
## fausses cette nuit faute d'avoir isolé une variable à la fois.
##
## ── ELLE LIT PAR LES DEUX CHEMINS ───────────────────────────────────────────────────────────────────
##
## Le chemin BRUT (`GLTFDocument` directement) et le chemin du GREFFON (`BlocsMaitres._lire_glb`, qui
## reconstruit les normales quand le fichier n'en porte pas). ⚠ Si seul le second varie, c'est notre
## code ; si les deux varient, c'est en dessous de nous.

const BM := preload("res://addons/marching_blocks_plugin_godot/blocs_maitres.gd")

var _fichier := ""
var _fois := 5


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--fichier="):
			_fichier = option.substr("--fichier=".length())
		if option.begins_with("--fois="):
			_fois = maxi(1, int(option.substr("--fois=".length())))
	if _fichier == "" or not FileAccess.file_exists(_fichier):
		print("il faut --fichier=<un .glb existant>")
		quit(1)
		return

	print("=== LA LECTURE EST-ELLE REPRODUCTIBLE ? ===\n")
	print("fichier : %s" % _fichier)
	print("taille  : %d octets" % FileAccess.get_file_as_bytes(_fichier).size())
	print("md5     : %s\n" % FileAccess.get_md5(_fichier))

	var releves: Array = []
	for essai in _fois:
		var brut: String = _decrire(_lire_brut(_fichier))
		# ⚠ Le chemin du greffon imprime lui-même sa trace de reconstruction : on la laisse passer, elle
		# fait partie du relevé.
		var journal: Array = []
		var greffon: String = _decrire(BM._lire_glb(_fichier, journal))
		releves.append({"brut": brut, "greffon": greffon})
		print("   tour %d" % (essai + 1))
		print("      chemin BRUT    : %s" % brut)
		print("      chemin GREFFON : %s" % greffon)
		if not journal.is_empty():
			print("      journal : %s" % str(journal))

	# ── LE VERDICT ──────────────────────────────────────────────────────────────────────────────────
	var brut_stable := true
	var greffon_stable := true
	for r in releves:
		if r["brut"] != releves[0]["brut"]:
			brut_stable = false
		if r["greffon"] != releves[0]["greffon"]:
			greffon_stable = false

	print("\n── DANS CETTE EXÉCUTION ──")
	print("   chemin BRUT    : %s" % ("STABLE" if brut_stable else "⚠ VARIE d'un tour à l'autre"))
	print("   chemin GREFFON : %s" % ("STABLE" if greffon_stable else "⚠ VARIE d'un tour à l'autre"))
	print("\n⚠ Cette sonde ne dit RIEN de la variation ENTRE exécutions : pour ça il faut la relancer")
	print("   et comparer les lignes. Une exécution ne peut pas se mesurer elle-même.")
	# ⚠ ON IMPRIME LA SIGNATURE EN CLAIR, sur une ligne facile à comparer d'un lancement à l'autre.
	print("\nSIGNATURE brut=%s | greffon=%s" % [releves[0]["brut"], releves[0]["greffon"]])
	quit(0)


## Tout ce qui nous intéresse d'un maillage, en une ligne comparable d'un tour à l'autre.
func _decrire(mesh: ArrayMesh) -> String:
	if mesh == null:
		return "NULL"
	if mesh.get_surface_count() == 0:
		return "VIDE"
	var arrays: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var dit := "%d som., UV %s, coul %s, norm %s" % [
		v.size(),
		"oui" if arrays[Mesh.ARRAY_TEX_UV] != null else "NON",
		"oui" if arrays[Mesh.ARRAY_COLOR] != null else "NON",
		"oui" if arrays[Mesh.ARRAY_NORMAL] != null else "NON"]
	var m: Material = mesh.surface_get_material(0)
	var std := m as StandardMaterial3D
	if std == null:
		dit += ", matière %s" % ("AUCUNE" if m == null else m.get_class())
	else:
		dit += ", tex %s, vcol %s, cull %d" % [
			"OUI" if std.albedo_texture != null else "aucune",
			"oui" if std.vertex_color_use_as_albedo else "NON",
			std.cull_mode]
	return dit


func _lire_brut(chemin: String) -> ArrayMesh:
	var document := GLTFDocument.new()
	var etat := GLTFState.new()
	if document.append_from_file(chemin, etat) != OK:
		return null
	var scene: Node = document.generate_scene(etat)
	if scene == null:
		return null
	var trouve: ArrayMesh = _chercher(scene)
	scene.queue_free()
	return trouve


## ⚠ ON RECONNAÎT UN NŒUD À CE QU'IL SAIT FAIRE : `ImporterMeshInstance3D` N'HÉRITE PAS de
## `MeshInstance3D`, et un `is MeshInstance3D` a déjà déclaré « aucun maillage » sur un fichier sain.
func _chercher(noeud: Node) -> ArrayMesh:
	if noeud.has_method("get_mesh"):
		var m = noeud.call("get_mesh")
		if m is ArrayMesh:
			return m
	for enfant in noeud.get_children():
		var t: ArrayMesh = _chercher(enfant)
		if t != null:
			return t
	return null
