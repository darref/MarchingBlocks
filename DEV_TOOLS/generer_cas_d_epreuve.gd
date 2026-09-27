extends SceneTree
##
## ÉCRIT LES CAS D'ÉPREUVE du format neutre (`FormatNeutre.cas_d_epreuve()`) à côté de chaque greffon.
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/generer_cas_d_epreuve.gd
##
## ⚠ À RELANCER À CHAQUE CHANGEMENT DE LA RÈGLE — et ce n'est pas laissé à la mémoire :
## `test_greffon_peinture` rougit si le fichier livré n'est plus celui que la référence produit.

const FN := preload("res://addons/marching_blocks_plugin_godot/format_neutre.gd")
## ⚠ UN SEUL FICHIER, LIVRÉ À CHAQUE GREFFON : les trois doivent passer les MÊMES cas.
const CIBLES := [
	"res://addons/marchingblocks_paint/conformance.json",
	"res://engines/unity/com.marchingblocks.paint/Tests/conformance.json",
]


func _initialize() -> void:
	var cas: Dictionary = FN.cas_d_epreuve()
	var texte := JSON.stringify(cas, "  ")
	for cible in CIBLES:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cible).get_base_dir())
		var f := FileAccess.open(cible, FileAccess.WRITE)
		f.store_string(texte)
		f.close()
		print("%d cas → %s (%d octets)" % [(cas["cases"] as Array).size(), cible, texte.length()])
	quit(0)
