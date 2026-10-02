extends SceneTree
## SONDE — ce que coûte l'eau, étape par étape, sur un vrai monde (Jordan, 2 octobre 2026 : « les algos d'eau sont
## beaucoup trop lents »). Elle ne conçoit rien : elle chronomètre.
##
## Le monde : les cases de `test.mbproj` (LU, jamais écrit), sinon un plateau de synthèse. Les sources : un océan
## au ras du sol, un lac dans un creux, une rivière posée sur le plus haut point. Chaque étape est mesurée seule :
## la boîte, « dans le vide », l'océan, chaque source, le maillage.
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_cout_eau.gd [-- chemin.mbproj]

const Projet := preload("res://app/projet.gd")
const FL := preload("res://addons/marchingblocks_core/fluides.gd")
const EM := preload("res://addons/marchingblocks_core/eau_maillage.gd")


func _initialize() -> void:
	var chemin := "C:/Users/jorda/Desktop/test.mbproj"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		chemin = args[0]
	var occ := {}
	var sources_du_projet: Array = []
	if chemin == "exemple":
		var z := ZIPReader.new()
		z.open("res://exemple/exemple.zip")
		var p := Projet.depuis_texte(z.read_file("example.mbproj").get_string_from_utf8(), [])
		for c in p.get("couches", []):
			for k in c["cases"]:
				occ[k] = true
		for e in p.get("eaux", []):
			sources_du_projet.append_array(e["sources"])
		print("monde : l'exemple, %d cases, %d sources d'eau" % [occ.size(), sources_du_projet.size()])
	elif FileAccess.file_exists(chemin):
		var p := Projet.depuis_texte(FileAccess.get_file_as_string(chemin), [])
		for c in p.get("couches", []):
			for k in c["cases"]:
				occ[k] = true
		print("monde : %s, %d cases" % [chemin.get_file(), occ.size()])
	else:
		for x in 60:
			for z in 60:
				for y in 1 + (x * 7 + z * 3) % 6:
					occ[Vector3i(x, y, z)] = true
		print("monde de synthèse : %d cases" % occ.size())
	var b := FL.boite(occ)
	print("boîte : %s → %s" % [b["lo"], b["hi"]])
	var t := Time.get_ticks_usec()
	for i in 10:
		FL.boite(occ)
	print("boite() : %.1f ms" % ((Time.get_ticks_usec() - t) / 10000.0))
	# Les sources : la colonne la plus haute (rivière), un océan au niveau du sol le plus bas + 1.
	var haut := Vector3i(0, -999, 0)
	var colonnes := {}
	for c: Vector3i in occ:
		if c.y > haut.y:
			haut = c
		var k := Vector2i(c.x, c.z)
		colonnes[k] = maxi(colonnes.get(k, -999), c.y)
	var lo: Vector3i = b["lo"]
	var hi: Vector3i = b["hi"]
	var sources: Array = [Vector3i(lo.x, lo.y + 3, lo.z), haut + Vector3i(0, 1, 0)]
	# Un lac : une colonne plus basse que ses quatre voisines.
	for k: Vector2i in colonnes:
		var h: int = colonnes[k]
		var creux := true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if colonnes.get(k + d, -999) <= h:
				creux = false
		if creux:
			sources.append(Vector3i(k.x, h + 1, k.y))
			break
	if not sources_du_projet.is_empty():
		sources = sources_du_projet
	print("sources : %s" % [sources])
	for s in sources:
		t = Time.get_ticks_usec()
		var vide := FL.dans_le_vide(occ, s)
		var tv := (Time.get_ticks_usec() - t) / 1000.0
		t = Time.get_ticks_usec()
		var r := FL.source(occ, s)
		print("  %s : %s, %d cases, %d de cours, erreur « %s » — source %.1f ms (dans_le_vide %.1f ms)" % [s, r["genre"],
			r["eau"].size(), r["cours"].size(), r["erreur"], (Time.get_ticks_usec() - t) / 1000.0, tv])
	t = Time.get_ticks_usec()
	var w := FL.monde(occ, sources)
	var tm := (Time.get_ticks_usec() - t) / 1000.0
	t = Time.get_ticks_usec()
	var m := EM.maillage(w["corps"], occ)
	print("monde() : %.1f ms ; maillage : %.1f ms (%d sommets)" % [tm, (Time.get_ticks_usec() - t) / 1000.0,
		0 if m == null else (m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()])
	quit(0)
