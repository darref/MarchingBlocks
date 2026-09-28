extends SceneTree
##
## ÉCRIT LES CAS D'ÉPREUVE à côté de chaque greffon :
##   - ceux de la RÈGLE DE POSE (`FormatNeutre.cas_d_epreuve()`) → `conformance.json`, les trois greffons ;
##   - ceux des OUTILS D'ÉDITION (`EpreuveOutils.cas_d_epreuve()`) → `tools_conformance.json`, les trois
##     greffons (Godot depuis le 28 septembre 2026).
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/generer_cas_d_epreuve.gd
##
## ⚠ À RELANCER À CHAQUE CHANGEMENT DE LA RÈGLE OU DES OUTILS — et ce n'est pas laissé à la mémoire :
## `test_greffon_peinture` rougit si un fichier livré n'est plus celui que la référence produit.

const FN := preload("res://addons/marchingblocks_core/format_neutre.gd")
const EO := preload("res://addons/marchingblocks_core/epreuve_outils.gd")
## ⚠ UN SEUL FICHIER, LIVRÉ À CHAQUE GREFFON : tous doivent passer les MÊMES cas.
const CIBLES := [
	"res://addons/marchingblocks_paint/conformance.json",
	"res://engines/unity/com.marchingblocks.paint/Tests/conformance.json",
	"res://engines/unreal/MarchingBlocksPaint/Tests/conformance.json",
]
const CIBLES_OUTILS := [
	"res://addons/marchingblocks_paint/tools_conformance.json",
	"res://engines/unity/com.marchingblocks.paint/Tests/tools_conformance.json",
	"res://engines/unreal/MarchingBlocksPaint/Tests/tools_conformance.json",
]


func _initialize() -> void:
	var outils: Dictionary = EO.cas_d_epreuve()
	if outils.has("erreur"):
		printerr(outils["erreur"])
		quit(1)
		return
	_ecrire(FN.cas_d_epreuve(), CIBLES)
	_ecrire(outils, CIBLES_OUTILS)
	quit(0)


static func _ecrire(cas: Dictionary, cibles: Array) -> void:
	var texte := JSON.stringify(cas, "  ")
	for cible in cibles:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cible).get_base_dir())
		var f := FileAccess.open(cible, FileAccess.WRITE)
		f.store_string(texte)
		f.close()
		print("%d cas → %s (%d octets)" % [(cas["cases"] as Array).size(), cible, texte.length()])
