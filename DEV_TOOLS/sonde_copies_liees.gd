extends SceneTree
## SONDE — le témoin lié survit-il à l'aller-retour Blender ?
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_copies_liees.gd -- ecrire <dossier>
##   blender --background --factory-startup --python DEV_TOOLS/sonde_copies_liees.py -- <dossier>
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_copies_liees.gd -- lire <dossier>
##
## « ecrire » : le VRAI export (`BlocsMaitres.exporter_le_temoin_lie`). Blender en retouche UNE occurrence
## (la tuile la plus partagée), et le réécrit deux fois : importé tel quel, et importé avec « Merge
## Vertices ». « lire » : la VRAIE relecture (`librairie_depuis_glb`) des deux fichiers revenus.

const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier: String = args[1]
	DirAccess.make_dir_recursive_absolute(dossier)
	if args[0] == "ecrire":
		print("export : « %s »" % BM.exporter_le_temoin_lie(dossier.path_join("temoin_lie.glb")))
		_compter(dossier.path_join("temoin_lie.glb"))
	else:
		var parti: Dictionary = BM.librairie_depuis_glb(dossier.path_join("temoin_lie.glb"))
		for nom in ["temoin_lie_blender.glb", "temoin_lie_blender_soude.glb"]:
			var chemin := dossier.path_join(nom)
			_compter(chemin)
			var b: Dictionary = BM.librairie_depuis_glb(chemin)
			var changees: Array = []
			for id in b["lot"].get_item_list():
				var n: String = b["lot"].get_item_name(id)
				var avant: int = parti["lot"].find_item_by_name(n)
				if avant < 0 or BM._empreinte_de_forme(b["lot"].get_item_mesh(id)) \
						!= BM._empreinte_de_forme(parti["lot"].get_item_mesh(avant)):
					changees.append(n)
			print("  relu : lié %s, %d tuiles, %s occurrences, erreurs %s, remarques %s, tuiles changées %s"
				% [b.get("lie", false), b["lot"].get_item_list().size(), b.get("occurrences"), b["erreurs"],
				b["remarques"], changees])
	quit(0)


func _compter(chemin: String) -> void:
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		print("absent : ", chemin)
		return
	f.seek(12)
	var longueur := f.get_32()
	f.get_32()
	var json: Dictionary = JSON.parse_string(f.get_buffer(longueur).get_string_from_utf8())
	var porteurs := 0
	for nd in json.get("nodes", []):
		if nd.has("mesh"):
			porteurs += 1
	print("%s : %d nœuds à maillage, %d maillages" % [chemin.get_file(), porteurs, json.get("meshes", []).size()])
