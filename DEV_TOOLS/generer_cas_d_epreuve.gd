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
const FM := preload("res://addons/marchingblocks_core/format_monde.gd")
## ⚠ UN SEUL FICHIER, LIVRÉ À CHAQUE GREFFON : tous doivent passer les MÊMES cas.
const CIBLES := [
	"res://addons/marchingblocks_paint/conformance.json",
	"res://engines/unity/com.marchingblocks.paint/Tests/conformance.json",
	"res://engines/unreal/MarchingBlocksPaint/Tests/conformance.json",
]
## ⚠ LA LECTURE DU MONDE PEINT (`world.json`, 29 septembre 2026) : mêmes trois greffons, même parade.
const CIBLES_MONDE := [
	"res://addons/marchingblocks_paint/world_conformance.json",
	"res://engines/unity/com.marchingblocks.paint/Tests/world_conformance.json",
	"res://engines/unreal/MarchingBlocksPaint/Tests/world_conformance.json",
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
	_ecrire(FM.cas_d_epreuve(), CIBLES_MONDE)
	quit(0)


## ⚠ UNE CASE TIENT SUR UNE LIGNE : « [x, y, z] ». Indentés, les triplets prenaient cinq lignes chacun, et
## les mondes des formes spéciales (1er octobre 2026) portaient `tools_conformance.json` à 460 Ko. Les
## tests comparent le JSON RELU, jamais le texte : le format est libre.
static func _ecrire(cas: Dictionary, cibles: Array) -> void:
	var texte := JSON.stringify(cas, "  ")
	var triplet := RegEx.new()
	triplet.compile("\\[\\s*(-?\\d+),\\s*(-?\\d+),\\s*(-?\\d+)\\s*\\]")
	texte = triplet.sub(texte, "[$1, $2, $3]", true)
	for cible in cibles:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cible).get_base_dir())
		var f := FileAccess.open(cible, FileAccess.WRITE)
		f.store_string(texte)
		f.close()
		print("%d cas → %s (%d octets)" % [(cas["cases"] as Array).size(), cible, texte.length()])
