extends Node3D
## LE REPÈRE DE TAILLE — DEMANDÉ PAR JORDAN (13 octobre 2026 : « rendre plus évident le scaling du monde »).
##
## Le personnage du Play test, en FANTÔME gris translucide, immobile, posé dans le monde sous le curseur : on juge
## d'un coup d'œil la hauteur d'une falaise ou d'une salle, à l'échelle du joueur.
##
## ⚠ **C'EST LE VRAI PERSONNAGE** (`personnage.gd`), pas une seconde description de sa silhouette (charte §6) : une
## instance dont la physique et l'animation sont coupées et dont toutes les pièces portent le même matériau fantôme.
## Sa taille suit le réglage « Character size » de la vue (`Vue.taille_personnage`) par `regler_taille`, comme au jeu.
## Il ne touche à rien : couche et masque de collision vides, aucune ombre.

const Personnage := preload("res://app/personnage.gd")

## PROPOSÉ : un gris bleuté à 45 % — assez pour lire la silhouette, pas assez pour cacher la case visée derrière.
const TEINTE := Color(0.78, 0.8, 0.84, 0.45)

var corps: CharacterBody3D


func _init() -> void:
	name = "Silhouette"
	corps = Personnage.new()
	corps.name = "Fantome"
	corps.process_mode = Node.PROCESS_MODE_DISABLED
	corps.collision_layer = 0
	corps.collision_mask = 0
	add_child(corps)
	var m := StandardMaterial3D.new()
	m.albedo_color = TEINTE
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.9
	# Le fantôme ne s'éclaire qu'à moitié : à l'ombre d'une falaise il doit rester lisible.
	m.emission_enabled = true
	m.emission = Color(TEINTE, 1.0) * 0.25
	_habiller(corps, m)


func _habiller(n: Node, m: Material) -> void:
	for f in n.get_children():
		if f is GeometryInstance3D:
			(f as GeometryInstance3D).material_override = m
			(f as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_habiller(f, m)


func regler_taille(t: float) -> void:
	corps.regler_taille(t)


## Debout sur `pied` (un point du monde), tourné vers `oeil` (son avant, −Z, regarde la caméra).
func poser(pied: Vector3, oeil: Vector3) -> void:
	position = pied
	var d := Vector2(oeil.x - pied.x, oeil.z - pied.z)
	if d.length() > 0.001:
		rotation = Vector3(0.0, atan2(-d.x, -d.y), 0.0)
