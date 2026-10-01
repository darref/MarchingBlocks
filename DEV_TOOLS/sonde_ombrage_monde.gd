extends SceneTree
## SONDE — le monde et son témoin s'éclairent-ils pareil ? (Jordan, 1er octobre 2026 : « les matériaux du monde se
## mettent parfois mal à jour dans certaines tuiles, par exemple sur les lèvres, ce n'est pas le même shading »)
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_ombrage_monde.gd -- <projet.mbproj>
##
## Pour chaque tuile du témoin de la couche active : ce que DESSINE le modeleur (`MaillageEdite.vers_array_mesh`)
## contre ce que POSE le monde (la tuile du lot, relue du `.glb` lié par `librairie_depuis_glb`). On compare les
## MATÉRIAUX surface par surface (couleur, rugosité, métal, couleur de sommet, texture) et les NORMALES triangle
## par triangle (appariés par leur centre).

const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")


func _initialize() -> void:
	var chemin: String = OS.get_cmdline_user_args()[0]
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	var c: Dictionary = d["couches"][int(d["active"])]
	var t: RefCounted = TL.depuis_dictionnaire(JSON.parse_string(FileAccess.get_file_as_string(str(c["temoin"]))))
	var glb := str(c["temoin"]).get_basename() + ".glb"
	# « -- <projet> neuf » : le .glb RÉÉCRIT par le code d'aujourd'hui (ailleurs), pas celui qui est sur le disque.
	if "neuf" in OS.get_cmdline_user_args():
		glb = ProjectSettings.globalize_path("user://sonde_ombrage_neuf.glb")
		t.vers_glb(glb)
	var lot: MeshLibrary = BM.librairie_depuis_glb(glb)["lot"]
	print("témoin %s · %d matériaux · glb %s" % [str(c["temoin"]).get_file(), t.materiaux.size(), glb.get_file()])
	var diff_mat := 0
	var diff_nor := 0
	for cle in t.tuiles:
		var a: ArrayMesh = t.tuiles[cle].vers_array_mesh()
		var id := lot.find_item_by_name(cle)
		if id < 0:
			print("  %s absente du lot" % cle)
			continue
		var b: Mesh = lot.get_item_mesh(id)
		var ma := _materiaux(a)
		var mb := _materiaux(b)
		if ma != mb:
			diff_mat += 1
			print("  MATÉRIAUX %s\n     modeleur %s\n     monde    %s" % [cle, ma, mb])
		var na := _normales(a)
		var nb := _normales(b)
		var ecarts := 0
		for k in na:
			if nb.has(k) and (na[k] as Vector3).dot(nb[k]) < 0.99:
				ecarts += 1
		if ecarts > 0 and "detail" in OS.get_cmdline_user_args():
			for k in na:
				if nb.has(k) and (na[k] as Vector3).dot(nb[k]) < 0.99:
					print("     centre %s : modeleur %s, monde %s" % [Vector3(k) / 1000.0, (na[k] as Vector3).snapped(Vector3.ONE * 0.001), (nb[k] as Vector3).snapped(Vector3.ONE * 0.001)])
		if ecarts > 0:
			diff_nor += 1
			print("  NORMALES %s : %d triangles sur %d tournés autrement" % [cle, ecarts, na.size()])
	print("tuiles aux matériaux différents : %d ; aux normales différentes : %d (sur %d)" % [diff_mat, diff_nor, t.tuiles.size()])
	quit(0)


func _materiaux(m: Mesh) -> Array:
	var sortie: Array = []
	for s in m.get_surface_count():
		var mat := m.surface_get_material(s)
		var a: Array = m.surface_get_arrays(s)
		var n: int = (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if a[Mesh.ARRAY_INDEX] != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		if mat is BaseMaterial3D:
			var b := mat as BaseMaterial3D
			sortie.append("%s alb=%s rug=%.2f met=%.2f vcol=%s tex=%s ombr=%d tris=%d" % [b.resource_name, b.albedo_color.to_html(false),
				b.roughness, b.metallic, b.vertex_color_use_as_albedo, b.albedo_texture != null, b.shading_mode, n])
		else:
			sortie.append("%s tris=%d" % [mat, n])
	sortie.sort()
	return sortie


func _normales(m: Mesh) -> Dictionary:
	var sortie := {}
	for s in m.get_surface_count():
		var a: Array = m.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n = a[Mesh.ARRAY_NORMAL]
		var idx = a[Mesh.ARRAY_INDEX]
		var ordre: PackedInt32Array = (idx as PackedInt32Array) if idx != null else PackedInt32Array(range(v.size()))
		for i in range(0, ordre.size() - 2, 3):
			var c: Vector3 = (v[ordre[i]] + v[ordre[i + 1]] + v[ordre[i + 2]]) / 3.0
			var normale: Vector3
			if n != null:
				normale = ((n[ordre[i]] + n[ordre[i + 1]] + n[ordre[i + 2]]) as Vector3).normalized()
			else:
				normale = -(v[ordre[i + 1]] - v[ordre[i]]).cross(v[ordre[i + 2]] - v[ordre[i]]).normalized()
			sortie[Vector3i((c * 1000.0).round())] = normale
	return sortie
