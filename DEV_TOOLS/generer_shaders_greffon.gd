extends SceneTree
##
## ÉCRIT LES SHADERS DU GREFFON GODOT depuis ceux de l'appli (leur UNIQUE source) :
##   ANIMATION    — `animation_materiau.gd` (`AM.shader()`, ses canaux assemblés) ;
##   TRANSITIONS  — `transitions.gd` (`TR.SHADER`) ;
##   WIND         — `app/feuillage_vue.gd` (`CODE_VENT`, ses @CULL@ / @ALPHA@ laissés au greffon, comme l'appli) ;
##   WATER_<ASPECT> — `eau_presets.gd` (`EP.code`), les six presets.
## dans `addons/marchingblocks_paint/mb_shaders.gd`.
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/generer_shaders_greffon.gd
##
## ⚠ UNE COPIE, PAS UNE SECONDE ÉCRITURE (charte §6, PARITE.md §11) : on ne retouche jamais `mb_shaders.gd`, on
## retouche le shader de l'appli et on relance. `test_greffon_peinture` rougit si le fichier livré n'est plus celui que
## ce script produit.
## ⚠ DEUX TRANSFORMATIONS, ET SEULEMENT DEUX — chacune doit trouver son motif, sinon le script refuse (un shader de
## l'appli réécrit autrement ferait sinon partir une copie qui ne dit plus ce qu'elle croit) :
##   1. L'ESPACE DU FORMAT (animation, transitions) : dans l'appli, le monde de Godot EST l'espace du format (case de
##      1, à l'origine) ; dans le greffon, un nœud MarchingBlocksWorld peut être déplacé, tourné, et sa case n'est pas
##      forcément de 1. Chaque `MODEL_MATRIX` devient `(mb_world_to_format * MODEL_MATRIX)`, un uniforme posé par le
##      greffon (l'inverse de la pose du nœud, divisé par la taille de case) : la phase d'une tuile et les cases lues
##      par le fondu sont celles du FORMAT, comme les cas d'épreuve.
##   2. L'HORLOGE (animation) : l'appli a une horloge globale (`mb_temps`, pause, vitesse) et une image forcée
##      (`mb_image`, quand on peint) ; le greffon ne peint pas les images — une seule horloge, le TIME de Godot.
## Le vent et l'eau partent TELS QUELS : leurs motifs sont en espace monde de Godot (le vent : voir `mb_foliage_node.gd`).

const AM := preload("res://addons/marchingblocks_core/animation_materiau.gd")
const TR := preload("res://addons/marchingblocks_core/transitions.gd")
const EP := preload("res://addons/marchingblocks_core/eau_presets.gd")
const VUE_FEUILLAGE := "res://app/feuillage_vue.gd"

const CIBLE := "res://addons/marchingblocks_paint/mb_shaders.gd"
## L'aspect exporté (anglais) → le preset du cœur.
const ASPECTS := {"stylized": "stylise", "clear": "transparent", "reflective": "reflechissant", "lava": "lave",
	"swamp": "marais", "acid": "acide"}
const UNIFORME_FORMAT := "uniform mat4 mb_world_to_format = mat4(1.0);"
const HORLOGE_APPLI := "global uniform float mb_temps;\nglobal uniform int mb_image;"
const HORLOGE_GREFFON := "#define mb_temps TIME\nconst int mb_image = -1;"


func _initialize() -> void:
	var tout := sorties()
	if tout.has("erreur"):
		printerr(tout["erreur"])
		quit(1)
		return
	for chemin in tout:
		var f := FileAccess.open(chemin, FileAccess.WRITE)
		if f == null:
			printerr("Shaders : impossible d'écrire %s" % chemin)
			quit(1)
			return
		f.store_buffer(tout[chemin])
		f.close()
	print("Shaders du greffon : %s écrit." % CIBLE)
	quit(0)


## L'espace du format : l'uniforme après la ligne `render_mode`, et chaque MODEL_MATRIX au travers.
static func _en_espace_du_format(code: String) -> String:
	var lignes := code.split("\n")
	var sortie := PackedStringArray()
	var pose := false
	for l in lignes:
		sortie.append(l)
		if not pose and l.begins_with("render_mode"):
			sortie.append(UNIFORME_FORMAT)
			pose = true
	if not pose:
		return ""
	return "\n".join(sortie).replace("MODEL_MATRIX", "(mb_world_to_format * MODEL_MATRIX)")


## Chemin → octets. Le test compare le disque à ceci. {"erreur": …} si un motif attendu manque.
static func sorties() -> Dictionary:
	var codes := {}
	var anim: String = AM.shader().code
	if not anim.contains(HORLOGE_APPLI) or not anim.contains("MODEL_MATRIX"):
		return {"erreur": "le shader d'animation n'a plus son horloge globale ou sa MODEL_MATRIX : relire ce générateur"}
	anim = _en_espace_du_format(anim.replace(HORLOGE_APPLI, HORLOGE_GREFFON))
	if anim == "":
		return {"erreur": "le shader d'animation n'a plus de ligne render_mode"}
	codes["ANIMATION"] = anim
	var tr: String = TR.SHADER
	if not tr.contains("MODEL_MATRIX"):
		return {"erreur": "le shader des transitions n'a plus de MODEL_MATRIX : relire ce générateur"}
	tr = _en_espace_du_format(tr)
	if tr == "":
		return {"erreur": "le shader des transitions n'a plus de ligne render_mode"}
	codes["TRANSITIONS"] = tr
	var vue: GDScript = load(VUE_FEUILLAGE)
	var vent: String = vue.get_script_constant_map().get("CODE_VENT", "")
	if not vent.contains("@CULL@") or not vent.contains("@ALPHA@"):
		return {"erreur": "le shader du vent n'a plus ses @CULL@ / @ALPHA@ : relire ce générateur"}
	codes["WIND"] = vent
	for aspect in ASPECTS:
		codes["WATER_" + aspect.to_upper()] = EP.code(ASPECTS[aspect])
	var gd := PackedStringArray([
		"@tool",
		"extends RefCounted",
		"## The MarchingBlocks tool's own shaders, for this plugin: animated textures, transitions between layers, the",
		"## wind in the foliage, and the six water looks.",
		"##",
		"## GENERATED by DEV_TOOLS/generer_shaders_greffon.gd from the MarchingBlocks tool's shaders — do not edit by hand,",
		"## the tool's are the source. Two changes only: `mb_world_to_format` (FORMAT space, where the tool's world IS that",
		"## space) in ANIMATION and TRANSITIONS, and one clock (Godot's TIME) in ANIMATION.",
		"",
		"## The water look exported in world.json → its shader below (an unknown look: the first one).",
		"const WATER_LOOKS := %s" % JSON.stringify(ASPECTS.keys()),
	])
	for nom in codes:
		var code: String = codes[nom]
		if code.contains("\"\"\""):
			return {"erreur": "le shader %s contient des triples guillemets" % nom}
		gd.append("")
		gd.append("const %s := \"\"\"%s\"\"\"" % [nom, code.replace("\\", "\\\\")])
	return {CIBLE: ("\n".join(gd) + "\n").to_utf8_buffer()}
