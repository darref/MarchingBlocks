extends SceneTree
## SONDE — LE PBR À TRAVERS LE glTF DE GODOT (2 octobre 2026). Ne conçoit rien : dit ce qui EXISTE.
## Un quad à UV projetés, un StandardMaterial3D avec albedo, normale, rugosité, métal, occlusion ; écrit en .glb par
## GLTFDocument, relu par GLTFDocument. Questions : quelles textures le fichier porte (lu dans le JSON), si TANGENT
## part, si la relecture rend un matériau aux mêmes textures et des tangentes ; et la vitesse d'une passe GDScript
## sur 1024² (le générateur doit-il aller au GPU ?).

func _img(c: Color) -> Image:
	var i := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	i.fill(c)
	return i

func _initialize() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [[Vector3(0,0,0), Vector2(0,1)], [Vector3(0,0,-1), Vector2(0,0)], [Vector3(1,0,-1), Vector2(1,0)],
			[Vector3(0,0,0), Vector2(0,1)], [Vector3(1,0,-1), Vector2(1,0)], [Vector3(1,0,0), Vector2(1,1)]]:
		st.set_normal(Vector3.UP)
		st.set_uv(v[1])
		st.add_vertex(v[0])
	for avec_tangentes in [false, true]:
		var s2 := SurfaceTool.new()
		s2.create_from(st.commit(), 0)
		if avec_tangentes:
			s2.generate_tangents()
		var mesh := s2.commit()
		var sm := StandardMaterial3D.new()
		sm.resource_name = "pbr"
		sm.albedo_texture = ImageTexture.create_from_image(_img(Color(0.8, 0.5, 0.2)))
		sm.normal_enabled = true
		sm.normal_texture = ImageTexture.create_from_image(_img(Color(0.5, 0.5, 1.0)))
		sm.roughness = 1.0
		sm.roughness_texture = ImageTexture.create_from_image(_img(Color(0.3, 0.3, 0.3)))
		sm.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		sm.metallic = 1.0
		sm.metallic_texture = ImageTexture.create_from_image(_img(Color(0, 0, 0)))
		sm.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		sm.ao_enabled = true
		sm.ao_texture = ImageTexture.create_from_image(_img(Color(0.7, 0.7, 0.7)))
		sm.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		mesh.surface_set_material(0, sm)
		var mi := MeshInstance3D.new()
		mi.name = "quad"
		mi.mesh = mesh
		var racine := Node3D.new()
		racine.add_child(mi)
		mi.owner = racine
		var doc := GLTFDocument.new()
		var etat := GLTFState.new()
		doc.append_from_scene(racine, etat)
		var chemin := OS.get_temp_dir().path_join("sonde_pbr_%s.glb" % str(avec_tangentes))
		print("écriture : ", doc.write_to_filesystem(etat, chemin))
		# Le JSON du fichier.
		var f := FileAccess.open(chemin, FileAccess.READ)
		f.seek(12)
		var lj := f.get_32(); f.get_32()
		var js: Dictionary = JSON.parse_string(f.get_buffer(lj).get_string_from_utf8())
		print("— tangentes générées : ", avec_tangentes)
		print("  attributs : ", js["meshes"][0]["primitives"][0]["attributes"].keys())
		print("  matériau  : ", JSON.stringify(js["materials"][0]))
		print("  images    : ", js.get("images", []).size())
		# Relu.
		var d2 := GLTFDocument.new()
		var e2 := GLTFState.new()
		d2.append_from_file(chemin, e2)
		var sc := d2.generate_scene(e2)
		var n := sc.find_children("*", "", true, false)
		for c in n:
			if c.has_method("get_mesh") or "mesh" in c:
				var m: Variant = c.mesh
				if m == null: continue
				var am: Mesh = m.get_mesh() if m.has_method("get_mesh") else m
				var a := am.surface_get_arrays(0)
				var mat: BaseMaterial3D = am.surface_get_material(0)
				print("  relu : tangentes ", a[Mesh.ARRAY_TANGENT] != null and (a[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size() > 0,
					" normal_tex ", mat.normal_texture != null, " rough_tex ", mat.roughness_texture != null,
					" canal ", mat.roughness_texture_channel, " metal_tex ", mat.metallic_texture != null, " canal ", mat.metallic_texture_channel,
					" ao ", mat.ao_texture != null, " ao_canal ", mat.ao_texture_channel)
		sc.free()
		racine.free()
	# Vitesse d'une passe GDScript.
	var n2 := 1024 * 1024
	var src := PackedByteArray(); src.resize(n2 * 4)
	var out := PackedFloat32Array(); out.resize(n2)
	var t0 := Time.get_ticks_usec()
	for i in n2:
		var j := i * 4
		out[i] = (src[j] * 0.299 + src[j + 1] * 0.587 + src[j + 2] * 0.114) / 255.0
	print("passe GDScript luminance 1024² : %d ms" % ((Time.get_ticks_usec() - t0) / 1000))
	var img := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	img.fill(Color.GRAY)
	t0 = Time.get_ticks_usec()
	var b := img.duplicate(); b.resize(64, 64, Image.INTERPOLATE_BILINEAR); b.resize(1024, 1024, Image.INTERPOLATE_CUBIC)
	print("flou par pyramide natif : %d ms" % ((Time.get_ticks_usec() - t0) / 1000))
	t0 = Time.get_ticks_usec()
	var h := img.duplicate(); h.convert(Image.FORMAT_RGBA8); h.bump_map_to_normal_map(1.0)
	print("bump_map_to_normal_map 1024² : %d ms" % ((Time.get_ticks_usec() - t0) / 1000))
	print("RenderingDevice : ", RenderingServer.get_rendering_device() != null)
	quit(0)
