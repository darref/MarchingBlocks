extends SceneTree
##
## SONDE — le témoin EXPORTÉ est-il soudé ? Mesuré sur les OCTETS du `.glb`, pas sur le maillage d'avant.
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_soudure_glb.gd [-- --fichier=C:/chemin/du.glb]
##
## ⚠ **POURQUOI LIRE LES OCTETS** : `sonde_topologie_export.gd` mesure le maillage AVANT l'écriture, en le
## soudant elle-même. Elle ne peut pas voir ce que l'écriture défait. Et relire par `GLTFDocument` ne
## vaudrait pas mieux : l'importeur de Godot peut fusionner ou séparer des sommets à sa façon. On lit
## ici le JSON et le tampon binaire comme Blender les reçoit (charte §6 : vérifier que l'instrument
## mesure bien ce qu'on croit).
##
## ⚠ **DEUX COMPTES D'ARÊTES OUVERTES, ET LEUR ÉCART EST LA RÉPONSE** :
##   • par INDICE de sommet — ce que Blender voit : une arête entre deux sommets non partagés est un
##     bord, une couture qu'on voit dans le modeleur ;
##   • par POSITION — la surface réelle : une arête ouverte là est un vrai TROU.
## Un maillage soudé a le même compte des deux côtés (zéro). Un maillage en soupe de triangles a zéro
## trou mais toutes ses arêtes ouvertes.
## ⚠ Soudé DANS TOUT LE FICHIER, pas primitive par primitive : Blender importe les primitives d'un
## maillage dans UN objet, mais ne partage aucun sommet entre elles — une teinte par primitive coupe
## donc la surface à chaque changement de teinte.

const BM := preload("res://addons/marching_blocks_plugin_godot/blocs_maitres.gd")

const TAILLES := {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}


func _initialize() -> void:
	print("=== SONDE — LA SOUDURE DU TÉMOIN EXPORTÉ ===\n")
	var fichier := ""
	for o in OS.get_cmdline_user_args():
		if o.begins_with("--fichier="):
			fichier = o.substr("--fichier=".length())
	if fichier == "":
		DirAccess.make_dir_recursive_absolute("user://sonde")
		fichier = ProjectSettings.globalize_path("user://sonde/temoin_exporte.glb")
		var raison: String = BM.exporter_le_bloc(fichier)
		if raison != "":
			print("✗ l'export a échoué : " + raison)
			quit(1)
			return
		print("exporté → %s" % fichier)
	var b: Dictionary = bilan(fichier)
	if b.has("erreur"):
		print("✗ " + b["erreur"])
		quit(1)
		return
	print("  %d primitive(s), %d triangles" % [b["primitives"], b["triangles"]])
	print("  sommets écrits : %d — positions distinctes : %d" % [b["sommets"], b["positions"]])
	print("  arêtes ouvertes PAR INDICE (ce que Blender voit) : %d" % b["ouvertes_indice"])
	print("  arêtes ouvertes PAR POSITION (vrais trous)       : %d" % b["ouvertes_position"])
	print("  arêtes à 3 faces ou plus (par position)          : %d" % b["non_manifold"])
	var soude: bool = b["sommets"] == b["positions"] and b["ouvertes_indice"] == 0
	print("\nVERDICT : %s" % ("SOUDÉ — chaque position n'est écrite qu'une fois, aucune couture"
		if soude else "NON SOUDÉ"))
	quit(0)


## Le bilan d'un `.glb`, lu octet par octet. Public : un test s'en sert.
static func bilan(chemin: String) -> Dictionary:
	var octets := FileAccess.get_file_as_bytes(chemin)
	if octets.size() < 20 or octets.decode_u32(0) != 0x46546C67:
		return {"erreur": "pas un .glb : %s" % chemin}
	var long_json: int = octets.decode_u32(12)
	var json = JSON.parse_string(octets.slice(20, 20 + long_json).get_string_from_utf8())
	var debut_bin: int = 20 + long_json + 8
	var bin: PackedByteArray = octets.slice(debut_bin, debut_bin + octets.decode_u32(20 + long_json))

	var positions: Array = []    # toutes les positions écrites, dans l'ordre global
	var triangles: Array = []    # [a, b, c] en indices GLOBAUX
	var primitives := 0
	for m in json.get("meshes", []):
		for prim in m.get("primitives", []):
			primitives += 1
			var base: int = positions.size()
			var pos: Array = _lire(json, bin, int(prim["attributes"]["POSITION"]))
			positions.append_array(pos)
			var idx: Array = _lire(json, bin, int(prim["indices"])) if prim.has("indices") \
				else range(pos.size())
			for t in range(0, idx.size() - 2, 3):
				triangles.append([base + int(idx[t]), base + int(idx[t + 1]), base + int(idx[t + 2])])

	var cle_de := {}
	var ids := PackedInt32Array()
	for p in positions:
		var v: Vector3 = p
		var cle := "%d,%d,%d" % [roundi(v.x * 1e5), roundi(v.y * 1e5), roundi(v.z * 1e5)]
		if not cle_de.has(cle):
			cle_de[cle] = cle_de.size()
		ids.append(cle_de[cle])
	var par_indice := {}
	var par_position := {}
	for tri in triangles:
		for k in 3:
			var a: int = tri[k]
			var b: int = tri[(k + 1) % 3]
			var ci := Vector2i(mini(a, b), maxi(a, b))
			par_indice[ci] = par_indice.get(ci, 0) + 1
			var cp := Vector2i(mini(ids[a], ids[b]), maxi(ids[a], ids[b]))
			par_position[cp] = par_position.get(cp, 0) + 1
	var ouvertes_indice := 0
	for e in par_indice:
		if par_indice[e] == 1:
			ouvertes_indice += 1
	var ouvertes_position := 0
	var non_manifold := 0
	for e in par_position:
		if par_position[e] == 1:
			ouvertes_position += 1
		elif par_position[e] > 2:
			non_manifold += 1
	return {"primitives": primitives, "triangles": triangles.size(), "sommets": positions.size(),
		"positions": cle_de.size(), "ouvertes_indice": ouvertes_indice,
		"ouvertes_position": ouvertes_position, "non_manifold": non_manifold}


## Un accesseur glTF : des Vector3 pour VEC3/FLOAT, des entiers pour SCALAR.
static func _lire(json: Dictionary, bin: PackedByteArray, i: int) -> Array:
	var acc: Dictionary = json["accessors"][i]
	var vue: Dictionary = json["bufferViews"][int(acc["bufferView"])]
	var type_c: int = int(acc["componentType"])
	var taille: int = TAILLES[type_c]
	var n_comp: int = 3 if acc["type"] == "VEC3" else 1
	var pas: int = int(vue.get("byteStride", taille * n_comp))
	var debut: int = int(vue.get("byteOffset", 0)) + int(acc.get("byteOffset", 0))
	var sortie: Array = []
	for k in int(acc["count"]):
		var o: int = debut + k * pas
		if n_comp == 3:
			sortie.append(Vector3(bin.decode_float(o), bin.decode_float(o + 4), bin.decode_float(o + 8)))
		else:
			match type_c:
				5121:
					sortie.append(bin.decode_u8(o))
				5123:
					sortie.append(bin.decode_u16(o))
				_:
					sortie.append(bin.decode_u32(o))
	return sortie
