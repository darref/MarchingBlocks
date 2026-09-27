@tool
extends EditorPlugin
## Registers the MarchingBlocksWorld node. Painting is done with Godot's own GridMap editor on its
## "Cells" child — nothing new to learn.

func _enter_tree() -> void:
	add_custom_type("MarchingBlocksWorld", "Node3D", preload("res://addons/marchingblocks_paint/mb_world.gd"),
		null)


func _exit_tree() -> void:
	remove_custom_type("MarchingBlocksWorld")
