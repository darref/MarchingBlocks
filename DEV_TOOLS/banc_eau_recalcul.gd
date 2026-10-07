extends SceneTree
## BANC (headless) — LE BUDGET DE L'EAU RECALCULÉE DANS UN GREFFON (7 octobre 2026, le contrat de l'eau recalculée,
## PARITE.md §12). Sur l'EXEMPLE livré (le plus grand monde qu'on ait : une mer de millions de cases), ce que coûte à un
## éditeur de refaire l'eau quand on peint : la règle (`FL.monde`) et la nappe (`EauMaillage.tableaux_du_maillage`),
##   - en ENTIER (ce que fait un greffon sans reprise),
##   - pour un GESTE, avec la reprise de l'appli (`FL.monde` avec `avant` et `changees`, la mémoire des nappes),
## la mer relue de ses tronçons (l'appli) ou de son eau (ce que lit un greffon). Ne conçoit rien, mesure.
##   godot --headless --path . --script res://DEV_TOOLS/banc_eau_recalcul.gd           (le cœur natif s'il est là)
##   MB_NATIF=0 godot --headless --path . --script res://DEV_TOOLS/banc_eau_recalcul.gd (le GDScript seul : le greffon
##                                                                                      Godot, qui ne charge pas le cœur)

const Exemple := preload("res://app/exemple.gd")
const Projet := preload("res://app/projet.gd")
const FL := preload("res://addons/marchingblocks_core/fluides.gd")
const EM := preload("res://addons/marchingblocks_core/eau_maillage.gd")
const Natif := preload("res://addons/marchingblocks_core/natif.gd")
const DOSSIER := "user://banc_eau_recalcul"


func _initialize() -> void:
	var erreurs: Array = []
	var chemin := Exemple.installer(Exemple.ARCHIVE, DOSSIER, erreurs)
	if chemin == "":
		print("⚠ %s" % [erreurs])
		quit(1)
		return
	var p := Projet.depuis_texte(FileAccess.get_file_as_string(chemin), erreurs)
	var occ := {}
	for c in p["couches"]:
		for k in c["cases"]:
			occ[k] = true
	var toutes: Array = []
	for e in p["eaux"]:
		toutes.append_array(e["sources"])
	print("cœur natif : %s" % ("OUI" if Natif.noyau() != null else "non (GDScript seul)"))
	print("monde : %d cases pleines, %d couches d'eau, %d sources" % [occ.size(), p["eaux"].size(), toutes.size()])
	var t := Time.get_ticks_usec()
	var w: Dictionary = FL.monde(occ, toutes)
	var t_regle := _ms(t)
	print("RÈGLE, en entier (FL.monde) : %d ms · mer %d cases" % [t_regle, (w["ocean"] as Dictionary).size()])
	var t_nappe := 0
	var t_nappe_sans := 0
	var k := 0
	for i in p["eaux"].size():
		var n: int = (p["eaux"][i]["sources"] as Array).size()
		var corps: Array = (w["corps"] as Array).slice(k, k + n)
		k += n
		# Deux fois chacun, le meilleur : le premier appel d'une passe paie des allocations (mesuré : 3,9 s puis 1,6 s).
		var a := {}
		var dt := 1 << 30
		for _essai in 2:
			t = Time.get_ticks_usec()
			a = EM.tableaux_du_maillage(corps, occ, w["boite"])
			dt = mini(dt, _ms(t))
		t_nappe += dt
		# Ce que lit un greffon : les corps sans les tronçons de la mer (la surface relue de son eau).
		var sans: Array = corps.map(func(r: Dictionary) -> Dictionary:
			var d := r.duplicate()
			d.erase("colonnes")
			return d)
		var dt_sans := 1 << 30
		for _essai in 2:
			t = Time.get_ticks_usec()
			EM.tableaux_du_maillage(sans, occ, w["boite"])
			dt_sans = mini(dt_sans, _ms(t))
		t_nappe_sans += dt_sans
		var genres := {}
		for r in corps:
			var g: String = r["genre"] if r["erreur"] == "" else "refus"
			genres[g] = int(genres.get(g, 0)) + 1
		print("  NAPPE couche %d %s : %d ms (mer relue de son eau : %d ms) · %d triangles" % [i, genres, dt, dt_sans,
			(a["i"] as PackedInt32Array).size() / 3])
	print("NAPPE, en entier, toutes couches : %d ms (mer relue de son eau : %d ms)" % [t_nappe, t_nappe_sans])
	print("TOUT REFAIRE (règle + nappes) : %d ms" % (t_regle + t_nappe))
	# UN GESTE, avec la reprise de l'appli : une case posée à côté d'une rivière, puis une case loin de toute eau
	# (au-dessus du point le plus haut).
	var pres := Vector3i.ZERO
	for r in w["corps"]:
		if r["erreur"] == "" and r["genre"] == "riviere" and not (r["cours"] as Array).is_empty():
			var c0: Vector3i = r["cours"][(r["cours"] as Array).size() / 2]["case"]
			for d in FL.HORIZONTALES:
				if not occ.has(c0 + d) and not (w["ocean"] as Dictionary).has(c0 + d):
					pres = c0 + d
					break
			if pres != Vector3i.ZERO:
				break
	var haut := Vector3i(0, -999, 0)
	for c in occ:
		if c.y > haut.y:
			haut = c
	for geste in [["une case posée à côté d'une rivière", pres], ["une case posée loin de l'eau (sur le sommet)", haut + Vector3i(0, 1, 0)]]:
		var memoires: Array = []
		k = 0
		for i in p["eaux"].size():
			var n: int = (p["eaux"][i]["sources"] as Array).size()
			var m := {}
			EM.tableaux_du_maillage((w["corps"] as Array).slice(k, k + n), occ, w["boite"], m)
			memoires.append(m)
			k += n
		var occ2 := occ.duplicate()
		occ2[geste[1]] = true
		t = Time.get_ticks_usec()
		var w2: Dictionary = FL.monde(occ2, toutes, FL.VOLUME_MAXI, w, {geste[1]: true}, null)
		var dt_regle := _ms(t)
		var repris := 0
		for i in toutes.size():
			if is_same(w2["corps"][i], w["corps"][i]):
				repris += 1
		t = Time.get_ticks_usec()
		k = 0
		for i in p["eaux"].size():
			var n: int = (p["eaux"][i]["sources"] as Array).size()
			var corps2: Array = (w2["corps"] as Array).slice(k, k + n)
			var corps1: Array = (w["corps"] as Array).slice(k, k + n)
			k += n
			if range(n).all(func(j): return is_same(corps1[j], corps2[j])):
				continue   # comme l'écran : une couche dont tous les corps sont repris garde sa nappe
			EM.tableaux_du_maillage(corps2, occ2, w2["boite"], memoires[i])
		var dt_nappe := _ms(t)
		print("GESTE — %s %s : règle %d ms (%d sources reprises sur %d), nappes %d ms, total %d ms" % [geste[0], geste[1],
			dt_regle, repris, toutes.size(), dt_nappe, dt_regle + dt_nappe])
	quit()


func _ms(t: int) -> int:
	return (Time.get_ticks_usec() - t) / 1000
