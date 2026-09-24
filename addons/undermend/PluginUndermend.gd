@tool
extends EditorPlugin
## LE GREFFON UNDERMEND — le panneau de peinture de tuiles 3D, dans la bande de droite de la vue 3D.
##
## ⚠ **IL A PORTÉ UN SECOND BOUTON, « FALAISES », ET IL EST PARTI AVEC LE VERSANT 2D** (Jordan,
## 24 septembre 2026). Il dérivait les parois sous les massifs peints d'un `TileMapLayer`, en s'appuyant
## sur l'addon Better Terrain. ⚠ Better Terrain avait DÉJÀ disparu du disque : le bouton plantait à la
## première pression (`load()` sur un chemin absent) et **rien ne le signalait tant qu'on ne cliquait
## pas**. Un greffon garde ce qu'il sait faire, pas ce qu'il savait faire.
##
## ⚠ **IL NE CONTIENT AUCUNE RÈGLE, ET C'EST LA MÊME DOCTRINE QU'AVANT.** Tout le calcul vit dans
## `blocs_maitres.gd`, `tranchage.gd` et `decoupe.gd` ; cet écran ne fait que les appeler. Un greffon qui
## recalcule finit par diverger de ce qu'il pilote — c'est ce qui était arrivé à la règle des falaises,
## écrite deux fois et déjà divergente à une heure d'intervalle.

const ECRAN := preload("res://addons/undermend/ecran_edition.gd")

var _ecran: Control


func _enter_tree() -> void:
	# ⚠ **LA BANDE DE DROITE DE LA VUE 3D, PLUS L'ÉCRAN ENTIER — DÉCIDÉ (Jordan, 24 septembre 2026).**
	# Le greffon déclarait `_has_main_screen()` : il REMPLAÇAIT la vue 3D, comme les onglets 2D/3D/Script.
	# On ne pouvait donc pas peindre et voir ses outils en même temps, ce qui est pourtant tout l'usage.
	# ⚠ `CONTAINER_SPATIAL_EDITOR_SIDE_RIGHT` existe bien — vérifié, et non supposé
	# (`DEV_TOOLS/sonde_api_editeur.gd` a listé les douze conteneurs, dont les quatre de l'éditeur 3D).
	_ecran = ECRAN.new()
	_ecran.name = "UndermendEdition"
	_ecran.custom_minimum_size = Vector2(320, 0)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_SIDE_RIGHT, _ecran)


func _exit_tree() -> void:
	if _ecran != null:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_SIDE_RIGHT, _ecran)
		_ecran.queue_free()
		_ecran = null

# ⚠ **`_has_main_screen`, `_get_plugin_name`, `_get_plugin_icon` ET `_make_visible` ONT VÉCU ICI.** Ils
# faisaient du greffon un ÉCRAN PRINCIPAL — un onglet qui remplace la vue 3D. Ils n'ont plus lieu d'être
# depuis qu'il est un panneau dans la bande de droite : un panneau ne se déclare pas, il s'ajoute.
