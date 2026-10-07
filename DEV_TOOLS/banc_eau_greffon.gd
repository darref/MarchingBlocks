extends SceneTree
## BANC (headless) — L'EAU RECALCULÉE DU GREFFON GODOT SUR L'EXEMPLE LIVRÉ (7 octobre 2026, PARITE.md §12). Le plus
## grand monde qu'on ait (une mer de centaines de milliers de cases, des dizaines de rivières) ; ce que fait le nœud
## `MarchingBlocksWater` (`_compute`, le chemin même du fil à part), mesuré et comparé :
##   1. TOUT REFAIRE (sans base : le premier calcul, ou le bouton sans reprise) — la règle et les nappes des couches ;
##   2. UN GESTE avec la reprise : une case près d'une rivière, une case loin de l'eau (au-dessus du sommet), une case
##      retirée sous la mer, puis des gestes au hasard — et chacun = le calcul entier (mêmes corps, même sac par couche) ;
##   3. LE BOUT EN BOUT : l'appli exporte l'exemple (`FormatMonde.exporter`, les nappes CUITES par `EauMaillage` comme le
##      fait l'écran) ; la nappe recalculée par le greffon est le sac de chaque `water/<nom>.glb` relu (couleurs à 1/255),
##      et le sac des tableaux du cœur au millionième près (tolérances des cas).
##   godot --headless --path . --script res://DEV_TOOLS/banc_eau_greffon.gd [-- gestes=N]
## Rend 0 si tout est égal. Les temps sont MESURÉS, pas jugés (machine partagée : des écarts de × 2 d'une passe à l'autre).

const Exemple := preload("res://app/exemple.gd")
const Projet := preload("res://app/projet.gd")
const FL := preload("res://addons/marchingblocks_core/fluides.gd")
const EM := preload("res://addons/marchingblocks_core/eau_maillage.gd")
const FM := preload("res://addons/marchingblocks_core/format_monde.gd")
const Natif := preload("res://addons/marchingblocks_core/natif.gd")
const Water := preload("res://addons/marchingblocks_paint/mb_water.gd")
const WaterNode := preload("res://addons/marchingblocks_paint/mb_water_node.gd")
const Sac := preload("res://DEV_TOOLS/eau_sac.gd")
const DOSSIER := "user://banc_eau_greffon"

var _echecs := 0


func _initialize() -> void:
	var n_hasard := 4
	for a in OS.get_cmdline_user_args():
		if a.begins_with("gestes="):
			n_hasard = int(a.trim_prefix("gestes="))
	var erreurs: Array = []
	var chemin := Exemple.installer(Exemple.ARCHIVE, DOSSIER, erreurs)
	if chemin == "":
		print("⚠ %s" % [erreurs])
		quit(1)
		return
	var p := Projet.depuis_texte(FileAccess.get_file_as_string(chemin), erreurs)
	var occ := {}
	var couches: Array = []
	for c in p["couches"]:
		couches.append((c["cases"] as Dictionary).duplicate())
		for k in c["cases"]:
			occ[k] = true
	var sources: Array = []
	var counts: Array = []
	for e in p["eaux"]:
		sources.append_array(e["sources"])
		counts.append((e["sources"] as Array).size())
	print("cœur natif (pour la nappe cuite) : %s ; le greffon : GDScript seul" % ("OUI" if Natif.noyau() != null else "non"))
	print("monde : %d cases pleines (couches de tuiles : %s), %d couches d'eau %s, %d sources" % [occ.size(),
		(p["couches"] as Array).map(func(c: Dictionary) -> int: return (c["cases"] as Dictionary).size()), counts.size(),
		counts, sources.size()])
	# 1. TOUT REFAIRE.
	var entier := {}
	for essai in 2:
		var job := {"layers": _couches(couches), "sources": sources, "counts": counts, "base": {}}
		WaterNode._compute(job)
		print("TOUT REFAIRE (passe %d) : %.2f s" % [essai + 1, job["seconds"]])
		entier = job
	var base: Dictionary = entier["out"]
	var mer := 0
	for r in base["world"]["bodies"]:
		if r["kind"] == "sea":
			mer = (r["water"] as Dictionary).size()
	print("  mer de %d cases ; triangles par couche : %s" % [mer, (base["arrays"] as Array).map(
		func(a: Dictionary) -> int: return (a["i"] as PackedInt32Array).size() / 3)])
	# 3 d'abord (sur l'état importé) : LE BOUT EN BOUT, contre la nappe cuite et contre le cœur.
	_contre_la_nappe_cuite(p, occ, sources, counts, base)
	# 2. LES GESTES.
	var pres := Vector3i.ZERO
	for r in base["world"]["bodies"]:
		if r["error"] == "" and r["kind"] == "river" and not (r["course"] as Array).is_empty():
			var c0: Vector3i = r["course"][(r["course"] as Array).size() / 2]["cell"]
			for d in Water.HORIZONTAL:
				if not occ.has(c0 + d) and not (base["world"]["sea"] as Dictionary).has(c0 + d):
					pres = c0 + d
					break
			if pres != Vector3i.ZERO:
				break
	var haut := Vector3i(0, -999, 0)
	for c in occ:
		if c.y > haut.y:
			haut = c
	# Une case de mer contre la côte (la plus haute) : peindre DANS la mer la recalcule.
	var dans_la_mer := Vector3i(0, -999, 0)
	for c: Vector3i in base["world"]["sea"]:
		if c.y > dans_la_mer.y and Water.HORIZONTAL.any(func(d: Vector3i) -> bool: return occ.has(c + d)):
			dans_la_mer = c
	var gestes: Array = [["une case posée à côté d'une rivière", [pres], []],
		["une case posée loin de l'eau (sur le sommet)", [haut + Vector3i.UP], []],
		["une case posée dans la mer, contre la côte", [dans_la_mer], []]]
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 1007
	var b: Dictionary = base["world"]["box"]
	for k in n_hasard:
		var c := Vector3i(hasard.randi_range(b["lo"].x, b["hi"].x), hasard.randi_range(b["lo"].y, b["hi"].y),
			hasard.randi_range(b["lo"].z, b["hi"].z))
		gestes.append(["au hasard %d" % k, [] if occ.has(c) else [c], [c] if occ.has(c) else []])
	var temps: Array = []
	for g in gestes:
		# Posée dans la première couche de tuiles, retirée de celle qui la tient : les autres couches ne changent pas.
		for c in g[1]:
			(couches[0] as Dictionary)[c] = true
		for c in g[2]:
			for l: Dictionary in couches:
				l.erase(c)
		var inc := {"layers": _couches(couches), "sources": sources, "counts": counts, "base": base}
		WaterNode._compute(inc)
		var ent := {"layers": _couches(couches), "sources": sources, "counts": counts, "base": {}}
		WaterNode._compute(ent)
		var ecart := _ecart(inc["out"], ent["out"], counts.size())
		temps.append(inc["seconds"])
		print("GESTE — %s %s : %.2f s avec la reprise (%s), %.2f s en entier — %s" % [g[0], g[1] + g[2], inc["seconds"],
			inc["reused"] + " ; " + inc["detail"], ent["seconds"], "= l'entier" if ecart == "" else "⚠ " + ecart])
		if ecart != "":
			_echecs += 1
		base = inc["out"]
	temps.sort()
	print("GESTES : %d, avec la reprise de %.2f à %.2f s (médiane %.2f s)" % [temps.size(), temps[0], temps[-1],
		temps[temps.size() / 2]])
	print("VERDICT : %s (%d écart(s))" % ["OK" if _echecs == 0 else "ÉCHEC", _echecs])
	quit(0 if _echecs == 0 else 1)


## Les cases de chaque couche de tuiles, en tableaux (ce que le nœud lit de chaque GridMap : `get_used_cells`).
func _couches(couches: Array) -> Array:
	return couches.map(func(l: Dictionary) -> Array: return l.keys())


## L'écart entre deux calculs : "" s'ils rendent les mêmes corps et les mêmes sacs.
func _ecart(a: Dictionary, b: Dictionary, n_couches: int) -> String:
	var ba: Array = a["world"]["bodies"]
	var bb: Array = b["world"]["bodies"]
	for j in bb.size():
		var x: Dictionary = ba[j]
		var y: Dictionary = bb[j]
		for k in ["kind", "error", "level", "end", "water"]:
			if x[k] != y[k]:
				return "le corps %d diffère (%s)" % [j, k]
		if (x["lakes"] as Array).size() != (y["lakes"] as Array).size() or x["course"] != y["course"]:
			return "le corps %d diffère (lacs ou cours)" % j
		for i in (x["lakes"] as Array).size():
			if x["lakes"][i]["level"] != y["lakes"][i]["level"] or x["lakes"][i]["cells"] != y["lakes"][i]["cells"]:
				return "le corps %d diffère (lac %d)" % [j, i]
	for i in n_couches:
		var s := Sac.meme_sac(Sac.triangles(b["arrays"][i]), Sac.triangles(a["arrays"][i]))
		if s != "":
			return "la nappe de la couche %d : %s" % [i, s]
	return ""


## LE BOUT EN BOUT : l'appli exporte l'exemple avec ses nappes cuites ; chaque nappe recalculée en est le sac.
func _contre_la_nappe_cuite(p: Dictionary, occ: Dictionary, sources: Array, counts: Array, base: Dictionary) -> void:
	var t := Time.get_ticks_usec()
	var w := FL.monde(occ, sources)
	var couches: Array = []
	for c in p["couches"]:
		couches.append({"nom": c["nom"], "visible": true, "source": "", "lot": null, "cases": (c["cases"] as Dictionary).keys()})
	var eaux: Array = []
	var coeur: Array = []
	var k := 0
	for i in counts.size():
		var n: int = counts[i]
		var corps: Array = (w["corps"] as Array).slice(k, k + n)
		k += n
		var a := EM.tableaux_du_maillage(corps, occ, w["boite"])
		coeur.append(a)
		eaux.append({"nom": p["eaux"][i]["nom"], "visible": true, "preset": "transparent",
			"sources": p["eaux"][i]["sources"], "maillage": EM.maillage(corps, occ, w["boite"])})
	var dossier := ProjectSettings.globalize_path(DOSSIER).path_join("export")
	DirAccess.make_dir_recursive_absolute(dossier)
	var r: Dictionary = FM.exporter(couches, dossier, "exemple", "banc", eaux)
	if r.has("erreur"):
		print("⚠ export : %s" % r["erreur"])
		_echecs += 1
		return
	print("l'appli exporte l'exemple (règle, nappes cuites, .mbworld) : %.1f s" % ((Time.get_ticks_usec() - t) / 1e6))
	var monde = JSON.parse_string(FileAccess.get_file_as_string(str(r["dossier"]).path_join("world.json")))
	var lu: Dictionary = Water.read(monde)
	var tol := Sac.TOL.duplicate()
	tol["color"] = 1.0 / 255.0 + 1e-6
	for i in counts.size():
		var e: Dictionary = lu["water"][i]
		var nom: String = e["name"]
		var refaite := Sac.triangles(base["arrays"][i])
		var s_coeur := Sac.meme_sac(Sac.triangles(coeur[i]), refaite)
		var s_cuite := "pas de nappe cuite" if not e["mesh"] is String else \
			Sac.meme_sac(Sac.triangles(_arrays_du_glb(str(r["dossier"]).path_join(e["mesh"]))), refaite, tol)
		print("  couche « %s » : %d triangles — contre le cœur : %s ; contre la nappe cuite (.glb) : %s" % [nom,
			refaite.size(), "même sac" if s_coeur == "" else "⚠ " + s_coeur, "même sac" if s_cuite == "" else "⚠ " + s_cuite])
		if s_coeur != "" or (refaite.size() > 0 and s_cuite != ""):
			_echecs += 1


func _arrays_du_glb(chemin: String) -> Dictionary:
	var doc := GLTFDocument.new()
	var etat := GLTFState.new()
	if doc.append_from_file(chemin, etat) != OK or etat.get_meshes().is_empty():
		return {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "uv": PackedVector2Array(),
			"i": PackedInt32Array()}
	var a: Array = ((etat.get_meshes()[0] as GLTFMesh).mesh as ImporterMesh).get_surface_arrays(0)
	return {"v": a[Mesh.ARRAY_VERTEX], "n": a[Mesh.ARRAY_NORMAL], "c": a[Mesh.ARRAY_COLOR], "uv": a[Mesh.ARRAY_TEX_UV],
		"i": a[Mesh.ARRAY_INDEX]}
