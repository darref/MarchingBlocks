extends SceneTree
## Sonde : la base (témoin calculé, cran neutre) subdivisée à N niveaux et lissée P passes, rendue de 3/4 — pour choisir
## un chanfrein franc. `-- --niveau=N --passes=P --force=F --sortie=<png>`.
const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const F := preload("res://DEV_TOOLS/forge_temoins.gd")

func _initialize() -> void:
	var niveau := 1
	var passes := 3
	var force := 0.6
	var sortie := "user://chanfrein.png"
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		match kv[0]:
			"niveau": niveau = int(kv[1])
			"passes": passes = int(kv[1])
			"force": force = float(kv[1])
			"sortie": sortie = kv[1]
	var t = TL.depuis_le_temoin_calcule(0.0)
	F.subdiviser_tout(t, niveau)
	var b := F.chanfreiner(t, force)
	if passes > 0:
		b["lissage"] = F.lisser_base(t, passes, 0.5)
	print("niveau %d passes %d force %.2f : %s, %d triangles" % [niveau, passes, force, b, F.triangles(t)])
	var mi := MeshInstance3D.new()
	mi.mesh = t.assemble()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.78, 0.72)
	mi.material_override = mat
	var vp := SubViewport.new()
	vp.size = Vector2i(900, 700)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	vp.add_child(mi)
	var cam := Camera3D.new()
	vp.add_child(cam)
	var bb: AABB = mi.mesh.get_aabb()
	var c := bb.get_center()
	var oeil := c + Vector3(1, 0.8, 1).normalized() * bb.size.length() * float(OS.get_environment("MB_RECUL") if OS.get_environment("MB_RECUL") != "" else "0.85")
	cam.transform = Transform3D(Basis.looking_at(c - oeil), oeil)
	print("aabb ", bb, " cam ", cam.global_position)
	var sol := DirectionalLight3D.new()
	vp.add_child(sol)
	sol.rotation_degrees = Vector3(-50, 35, 0)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_color = Color(0.5, 0.52, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	vp.add_child(env)
	for i in 8:
		await process_frame
	vp.get_texture().get_image().save_png(sortie)
	quit(0)
