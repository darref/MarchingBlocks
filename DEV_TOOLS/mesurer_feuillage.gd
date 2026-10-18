extends SceneTree
## MESURER DES MODÈLES DE FEUILLAGE — les réglages par défaut que l'atelier Foliage donnerait à chaque `.glb` importé
## (`FeuillageVue.reglages_par_defaut` : décalage, rayon, hauteur), écrits en JSON sur la sortie. Sert à REMPLACER un
## modèle d'un projet en gardant ses plants (Jordan, 18 octobre 2026 : les essences les plus lourdes de l'exemple
## remplacées par des CC0 optimisés) : `D:/SpannerGames/OUTILS/remplacer_feuillage.py` le lance.
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/mesurer_feuillage.gd -- <a.glb> <b.glb>…

const FeuillageVue := preload("res://app/feuillage_vue.gd")


func _initialize() -> void:
	var sortie := {}
	for chemin in OS.get_cmdline_user_args():
		var d := FeuillageVue.charger(chemin)
		sortie[chemin] = {"erreur": d["erreur"]} if d["erreur"] != "" else FeuillageVue.reglages_par_defaut(d)
	print("MESURE " + JSON.stringify(sortie))
	quit(0)
