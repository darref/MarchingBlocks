extends SceneTree

## SONDE — LE MAILLEUR ET LE BILAN PARLENT-ILS DU MÊME MAILLAGE ?
##
## ⚠ **TROUVÉE PAR ACCIDENT, LE 25 septembre 2026.** En mesurant ce que coûterait de doubler `SOUS`
## pour débloquer le chanfrein, j'ai changé `blocs_maitres.SOUS` de 4 à 8 : la sonde des escaliers a vu
## la grille changer (« 1 cellule = 8 sous-voxels »), et la sonde de topologie a rendu **exactement les
## mêmes 6 624 et 6 164 quads**. Un instrument qui ne bouge pas quand son sujet bouge ne mesure pas son
## sujet (charte §6).
##
## ⚠ **LA CAUSE : `SOUS` EST DÉCRIT À TROIS ENDROITS**, et `DEV_TOOLS/topologie.gd` ne duplique pas
## seulement la constante — il RÉIMPLÉMENTE la coque, retrait par axe compris. Or c'est lui qui produit
## tous les bilans publiés dans la charte (« 15 arêtes ambiguës sur 8 326 quads, 0 trou, valence 4 à
## 91 % »), tandis que c'est `blocs_maitres` qui écrit le `.glb`.
##
## ⚠ **CE QUE CETTE SONDE TRANCHE, ET RIEN DE PLUS** : les deux coques coïncident-elles AUJOURD'HUI ?
##   • si oui, les chiffres publiés sont justes par CHANCE, et la duplication doit disparaître ;
##   • si non, tout ce que la charte affirme sur la topologie décrit un maillage qui ne part pas.
##
## On compare avec le MÊME `bilan()` des deux côtés : seule la coque change, donc tout écart lui est
## imputable et à rien d'autre.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const Topo := preload("res://DEV_TOOLS/topologie.gd")


func _initialize() -> void:
	print("=== LE MAILLEUR ET LE BILAN PARLENT-ILS DU MÊME MAILLAGE ? ===\n")
	print("   blocs_maitres.SOUS = %d   ·   topologie.SOUS = %d   %s\n"
		% [BM.SOUS, Topo.SOUS,
			"✓ d'accord" if BM.SOUS == Topo.SOUS else "⚠ DÉJÀ DIVERGENTS"])

	for bloc in BM.nombre():
		var cases: Dictionary = BM.cases(bloc)
		print("── bloc %d — « %s » ──" % [bloc, BM.BLOCS[bloc]["nom"]])
		for retrait in [0.0, 0.25]:
			var du_mailleur: ArrayMesh = BM._coque_sous_voxels(cases, retrait)
			var de_la_sonde: ArrayMesh = Topo.coque_sous_voxels(cases, retrait)
			var a: Dictionary = Topo.bilan(du_mailleur, cases)
			var b: Dictionary = Topo.bilan(de_la_sonde, cases)
			var accord: bool = a["quads"] == b["quads"] \
				and a["q_bords"] == b["q_bords"] and a["q_multiples"] == b["q_multiples"]
			print("   retrait %.2f  ·  mailleur %5d quads (bords %d, 3+faces %d)"
				% [retrait, a["quads"], a["q_bords"], a["q_multiples"]])
			print("                 ·  sonde    %5d quads (bords %d, 3+faces %d)   %s"
				% [b["quads"], b["q_bords"], b["q_multiples"],
					"✓ IDENTIQUES" if accord else "⚠ ILS DIVERGENT"])
			# ⚠ Le compte de quads peut coïncider sans que les maillages soient les mêmes. On compare
			# donc aussi les SOMMETS, qui distinguent deux coques de même taille mais placées autrement.
			var sa: int = _sommets(du_mailleur)
			var sb: int = _sommets(de_la_sonde)
			if sa != sb:
				print("                 ⚠ sommets : %d contre %d" % [sa, sb])
		print("")
	quit(0)


func _sommets(mesh: ArrayMesh) -> int:
	if mesh == null or mesh.get_surface_count() == 0:
		return 0
	return (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
