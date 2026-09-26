extends SceneTree

## SONDE — L'EXPORT NE PORTE QU'UN BLOC SUR DEUX
##
## ⚠ **JORDAN, 26 septembre 2026 : « est-ce que le témoin exporté était 68/68 ? »** Non. Et la question
## était la bonne à poser AVANT tout le reste : il venait de sculpter le `.glb` que je lui avais donné,
## en raisonnant — justement — que *« s'il est dérivé du témoin canon, ce que le témoin couvre, mon
## sculpt le couvre »*. Le raisonnement est juste ; **c'est la prémisse qui était fausse.**
##
## ⚠ **MESURÉ, ET C'EST UN DÉFAUT DE PÉRIMÈTRE, PAS DE GÉOMÉTRIE :**
##   • `BM.librairie()` — le chemin interne — rend **90/90, 0 manquante, 0 erreur** ;
##   • le MÊME bloc exporté puis relu rend **27/90, 50 manquantes, 0 erreur**.
##
## Le jeu compte désormais **DEUX** blocs maîtres, et le second porte l'essentiel : « le paysage »
## livre 27 tuiles, « le résidu » en livre 84 dont **63 nouvelles**. Or `exporter_le_bloc()` n'écrit que
## `BLOCS[0]` et `librairie_depuis_glb()` ne relit que lui : l'export n'a jamais suivi quand le jeu est
## passé de un bloc à deux.
##
## ⚠ **ET AUCUNE ERREUR NE LE DIT** — ni à l'export, ni au retour. Le pipeline annonce sereinement
## 27 items là où il en faut 90, parce que rien ne compare ce qui PART à ce que le jeu CONTIENT.
## C'est exactement ce que la charte §6 nomme : un compteur vert qui ne dit pas si la chose est à sa
## place. Le contrôle qui manquait tient en une ligne — **le cumul par bloc**, ci-dessous.
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/UnderMend ##       --script res://DEV_TOOLS/sonde_export_partiel.gd

const MB := preload("res://addons/undermend/marching_blocks.gd")
const BM := preload("res://addons/undermend/blocs_maitres.gd")

func _initialize() -> void:
	print("le jeu compte %d bloc(s) :" % BM.nombre())
	for i in BM.nombre():
		print("   %d — « %s » : %d cases" % [i, BM.BLOCS[i]["nom"], BM.cases(i).size()])
	print("")
	var Tranchage := load("res://addons/undermend/tranchage.gd")
	var cumul := {}
	for i in BM.nombre():
		var fautes: Array = []
		var r: Dictionary = Tranchage.trancher(BM.maillage_moitie(i), Vector3i.ONE * BM.COTE, 1.0,
			BM.creuses(i), fautes, false)
		var neuves := 0
		for nom in r:
			if not cumul.has(nom):
				cumul[nom] = true
				neuves += 1
		print("   bloc %d : %d tuile(s) récoltée(s), dont %d NOUVELLES — cumul %d"
			% [i, r.size(), neuves, cumul.size()])
	print("\n⚠ `exporter_le_bloc` n'écrit que BLOCS[0] et `librairie_depuis_glb` ne relit que lui.")
	quit(0)
