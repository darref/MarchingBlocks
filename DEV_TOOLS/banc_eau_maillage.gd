extends SceneTree
## BANC (headless) — le maillage de l'eau sur l'EXEMPLE livré, étape par étape (4 octobre 2026 : 880 ms pour la couche
## d'eau aux 100 rivières, refaite après chaque geste). Installe l'exemple dans un dossier jetable, lit son projet,
## déduit l'eau (`FL.monde`), puis chronomètre `EauMaillage.maillage` et ses étapes, rejouées. Ne conçoit rien.
##   godot --headless --path . --script res://DEV_TOOLS/banc_eau_maillage.gd

const Exemple := preload("res://app/exemple.gd")
const Projet := preload("res://app/projet.gd")
const FL := preload("res://addons/marchingblocks_core/fluides.gd")
const EM := preload("res://addons/marchingblocks_core/eau_maillage.gd")
const DOSSIER := "user://banc_eau_maillage"


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
	print("monde : %d cases, %d couches d'eau, %d sources" % [occ.size(), p["eaux"].size(), toutes.size()])
	var t := Time.get_ticks_usec()
	var w: Dictionary = FL.monde(occ, toutes)
	print("FL.monde complet : %d ms" % _ms(t))
	# Chaque source seule (contre l'océan déjà calculé), les plus chères d'abord.
	var b := FL.boite(occ)
	var couts: Array = []
	for i in toutes.size():
		var s: Vector3i = toutes[i]
		t = Time.get_ticks_usec()
		var r: Dictionary = FL.source(occ, s, w["ocean"], FL.VOLUME_MAXI, b)
		couts.append([_ms(t), i, r["genre"], r["erreur"], (r["eau"] as Dictionary).size(), (r["cours"] as Array).size()])
	for i in toutes.size():
		if not occ.has(toutes[i]) and FL.dans_le_vide(occ, toutes[i], b):
			t = Time.get_ticks_usec()
			var o: Dictionary = FL.source(occ, toutes[i], {}, FL.VOLUME_MAXI, b)
			print("l'océan (source %d) seul : %d ms · %d cases d'eau · niveau %d · boîte %s" % [i, _ms(t),
				(o["eau"] as Dictionary).size(), o["niveau"], b])
			t = Time.get_ticks_usec()
			var d := {}
			for k in o["eau"]:
				d[k] = true
			print("   recopier son eau dans un dictionnaire : %d ms" % _ms(t))
			break
	couts.sort_custom(func(x, y): return x[0] > y[0])
	var total := 0
	for c in couts:
		total += int(c[0])
	print("somme des sources seules : %d ms ; les plus chères :" % total)
	for c in couts.slice(0, 8):
		print("   %5d ms · source %d · %s %s · %d cases d'eau · %d de cours" % c)
	t = Time.get_ticks_usec()
	FL.boite(occ)
	print("FL.boite : %d ms" % _ms(t))
	var k := 0
	for i in p["eaux"].size():
		var n: int = (p["eaux"][i]["sources"] as Array).size()
		var corps: Array = (w["corps"] as Array).slice(k, k + n)
		k += n
		var genres := {}
		for r in corps:
			var g: String = r["genre"] if r["erreur"] == "" else "erreur"
			genres[g] = genres.get(g, 0) + 1
		t = Time.get_ticks_usec()
		var m := EM.maillage(corps, occ)
		print("── couche d'eau %d : %s · maillage %d ms · %d sommets" % [i, genres, _ms(t),
			0 if m == null else m.surface_get_array_len(0)])
		_etapes(corps, occ)
	quit()


## Les étapes de `EauMaillage.maillage`, rejouées dans le même ordre.
func _etapes(corps: Array, occ: Dictionary) -> void:
	var a := EM._tableaux()
	var t := Time.get_ticks_usec()
	var b := FL.boite(occ)
	var t_boite := _ms(t)
	var plats: Array = []
	var vus := {}
	var sources: Array = []
	var dormantes: Array = []
	for r in corps:
		if r == null or r["erreur"] != "":
			continue
		if r["genre"] == "ocean" or r["genre"] == "lac":
			dormantes.append(r["eau"])
		elif r["genre"] == "riviere":
			for lac in r["lacs"]:
				dormantes.append(lac["cases"])
	vus["dormantes"] = dormantes
	var t_nappes := 0
	var t_rivieres := 0
	var nb_cours := 0
	for r in corps:
		if r == null or r["erreur"] != "":
			continue
		t = Time.get_ticks_usec()
		match r["genre"]:
			"ocean":
				var niveau: int = r["niveau"]
				plats.append_array(EM.rectangles_de_nappe(r["eau"], occ,
					EM.surface_des_colonnes(r.get("colonnes", null), occ, b, niveau), niveau, NAN))
				t_nappes += _ms(t)
			"lac":
				plats.append_array(EM.rectangles_de_nappe(r["eau"], occ, null, r["niveau"]))
				t_nappes += _ms(t)
			"riviere":
				for lac in r["lacs"]:
					plats.append_array(EM.rectangles_de_nappe(lac["cases"], occ, null, lac["niveau"]))
				t_nappes += _ms(t)
				t = Time.get_ticks_usec()
				nb_cours += (r["cours"] as Array).size()
				EM._riviere(a, r["cours"], occ, plats, vus, sources)
				t_rivieres += _ms(t)
	var remous: Array = []
	t = Time.get_ticks_usec()
	EM._poser_les_lames(a, vus, remous, plats)
	var t_lames := _ms(t)
	t = Time.get_ticks_usec()
	for c: Vector3i in sources:
		remous.append_array(EM._source(c))
	var t_sources := _ms(t)
	t = Time.get_ticks_usec()
	EM._poser_les_plats(a, plats)
	var t_plats := _ms(t)
	t = Time.get_ticks_usec()
	for g: Dictionary in remous:
		EM._grille(a, g)
	var t_grilles := _ms(t)
	t = Time.get_ticks_usec()
	EM._sans_orphelins(a)
	var t_orph := _ms(t)
	print("   boîte %d · nappes %d · rivières %d (%d cases de cours) · lames %d · sources %d · plats %d (%d) · remous %d (%d) · orphelins %d"
		% [t_boite, t_nappes, t_rivieres, nb_cours, t_lames, t_sources, t_plats, plats.size(), t_grilles, remous.size(), t_orph])


func _ms(t: int) -> int:
	return (Time.get_ticks_usec() - t) / 1000
