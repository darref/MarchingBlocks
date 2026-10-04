extends SceneTree
## BANC (headless) — le remaillage d'une couche d'eau de l'EXEMPLE quand une rivière change (4 octobre 2026 : ~0,45 s par
## geste de l'eau, la couche aux 93 rivières et à l'océan). Le maillage est appelé comme l'écran l'appelle (la boîte
## donnée, la mémoire des nappes tenue), deux fois : le second appel est celui d'un geste. Puis les étapes des cascades
## rejouées à part. Ne conçoit rien.
##   godot --headless --path . --script res://DEV_TOOLS/banc_eau_rivieres.gd

const Exemple := preload("res://app/exemple.gd")
const Projet := preload("res://app/projet.gd")
const FL := preload("res://addons/marchingblocks_core/fluides.gd")
const EM := preload("res://addons/marchingblocks_core/eau_maillage.gd")
const DOSSIER := "user://banc_eau_rivieres"


func _initialize() -> void:
	var erreurs: Array = []
	var chemin := Exemple.installer(Exemple.ARCHIVE, DOSSIER, erreurs)
	var p := Projet.depuis_texte(FileAccess.get_file_as_string(chemin), erreurs)
	var occ := {}
	for c in p["couches"]:
		for k in c["cases"]:
			occ[k] = true
	var toutes: Array = []
	for e in p["eaux"]:
		toutes.append_array(e["sources"])
	var w: Dictionary = FL.monde(occ, toutes)
	var n0: int = (p["eaux"][0]["sources"] as Array).size()
	var corps: Array = (w["corps"] as Array).slice(0, n0)
	var memoire := {}
	var t := Time.get_ticks_usec()
	var m := EM.maillage(corps, occ, w["boite"], memoire)
	print("premier maillage (nappes à faire) : %d ms · %d sommets" % [_ms(t), m.surface_get_array_len(0)])
	for essai in 3:
		t = Time.get_ticks_usec()
		m = EM.maillage(corps, occ, w["boite"], memoire)
		print("maillage d'un geste (nappes gardées) : %d ms · %d sommets" % [_ms(t), m.surface_get_array_len(0)])
	# Les étapes, rejouées.
	var a := EM._tableaux()
	var plats: Array = []
	var vus := {}
	var sources: Array = []
	var dormantes: Array = []
	for r in corps:
		if r["erreur"] == "" and r["genre"] == "riviere":
			for lac in r["lacs"]:
				dormantes.append(lac["cases"])
		elif r["erreur"] == "":
			dormantes.append(r["eau"])
	vus["dormantes"] = dormantes
	t = Time.get_ticks_usec()
	for r in corps:
		if r["erreur"] == "" and r["genre"] == "riviere":
			EM._riviere(a, r["cours"], occ, plats, vus, sources)
	print("rivières (bandes, cascades retenues) : %d ms · %d cascades" % [_ms(t), vus.size() - 1])
	var lignes := 0
	var points := 0
	for cle in vus:
		if cle is String and cle != "dormantes":
			var l: Dictionary = vus[cle]
			var ch := EM._chutes(float(l["haut"]) - float(l["pied"]))
			lignes += ch.size()
	var remous: Array = []
	t = Time.get_ticks_usec()
	EM._poser_les_lames(a, vus, remous, plats)
	print("lames : %d ms · %d rangées · %d sommets posés" % [_ms(t), lignes, (a["v"] as PackedVector3Array).size()])
	t = Time.get_ticks_usec()
	var b := EM._tableaux()
	for g in remous:
		EM._poser(b, g)
	print("remous : %d ms · %d grilles" % [_ms(t), remous.size()])
	quit()


func _ms(t: int) -> int:
	return (Time.get_ticks_usec() - t) / 1000
