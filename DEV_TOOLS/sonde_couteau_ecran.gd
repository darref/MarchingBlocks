extends SceneTree
## SONDE — LE COUTEAU MENÉ À LA SOURIS SUR UN BORD DE TUILE (Jordan, 2 octobre 2026 : « le knife sur une edge
## fusionnée de bord de tuile répétée […] que ça plante pas »). L'appli entière, sans fenêtre : Witness, édition,
## la paroi active ; K, des clics posés par la caméra sur l'arête de bord et AU-DELÀ (sur la copie voisine, qui la
## partage), Entrée. Elle dit ce qui arrive : erreurs, état du modeleur, faces, sommets de joint sans partenaire.
## ⚠ À lancer dans une COPIE à dossier de données isolé (`config/use_custom_user_dir`) : elle réécrit reglages.cfg.

const Projet := preload("res://app/projet.gd")
const ME := preload("res://addons/marchingblocks_core/maillage_edite.gd")
const REGLAGES := "user://reglages.cfg"
const JETABLE := "user://sonde_couteau/sonde.mbproj"
var ed: Control


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("user://sonde_couteau")
	var f := FileAccess.open(JETABLE, FileAccess.WRITE)
	f.store_string(Projet.vers_texte([Projet.couche("Rock")], 0))
	f.close()
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", JETABLE)
	r.save(REGLAGES)
	ed = (load("res://app/editor.tscn") as PackedScene).instantiate()
	root.add_child(ed)
	_mener.call_deferred()


func _mener() -> void:
	for i in 10:
		await process_frame
	ed._aller_a("witness")
	ed._regler_edition(true)
	var mo: Node3D = ed._modeleur
	var t: RefCounted = mo.temoin
	var vue = ed._vue
	var cam: Camera3D = vue._camera
	print("tuiles : %d, occurrences : %d" % [t.tuiles.size(), t.occurrences.size()])
	var essais := 0
	for cle in ["mb_plaque_b2h2_dehors", "mb_plaque_b2h2", "mb_arete_b2h0_dehors", "mb_coin_b1h0_dehors"]:
		if not t.tuiles.has(cle):
			continue
		for occ in (t.occurrences_de(cle) as Array).slice(0, 3):
			mo.activer(int(occ))
			for mode in ["dans la face", "pile sur l'arête", "au-delà, sur la copie voisine", "au-delà, puis retour"]:
				essais += 1
				_essayer(mo, vue, cam, t, cle, mode)
	print("%d essais" % essais)
	quit(0)


func _essayer(mo: Node3D, vue, cam: Camera3D, t: RefCounted, cle: String, mode: String) -> void:
	var m: RefCounted = mo.maillage
	# Une face qui touche un plan de coupe, et son arête de bord.
	var fb := -1
	var kb := -1
	var axe := -1
	for f in m.faces.size():
		var face: PackedInt32Array = m.faces[f]
		if face.size() != 4:
			continue
		for k in 4:
			var pa: Vector3 = m.sommets[face[k]]
			var pb: Vector3 = m.sommets[face[(k + 1) % 4]]
			for x in 3:
				if fb < 0 and absf(absf(pa[x]) - 0.5) < 0.0005 and absf(pa[x] - pb[x]) < 0.0005:
					fb = f
					kb = k
					axe = x
	if fb < 0:
		print("  %s : pas de face de bord" % cle)
		return
	var face: PackedInt32Array = m.faces[fb]
	var a := face[kb]
	var b := face[(kb + 1) % 4]
	var c := face[(kb + 2) % 4]
	var d := face[(kb + 3) % 4]
	var milieu: Vector3 = (m.sommets[a] + m.sommets[b]) * 0.5
	var en_face: Vector3 = (m.sommets[c] + m.sommets[d]) * 0.5
	var centre: Vector3 = m.centre(fb)
	# Au-delà du plan : le milieu, poussé hors de la case d'un quart, dans le plan de la face.
	var dehors := milieu
	dehors[axe] += 0.25 * signf(milieu[axe])
	var points: Array = []
	match mode:
		"dans la face":
			points = [milieu.lerp(centre, 0.05), en_face.lerp(centre, 0.05)]
		"pile sur l'arête":
			points = [milieu, en_face.lerp(centre, 0.05)]
		"au-delà, sur la copie voisine":
			points = [en_face.lerp(centre, 0.05), milieu, dehors]
		"au-delà, puis retour":
			points = [dehors, milieu, en_face.lerp(centre, 0.05)]
	# La caméra regarde la face, d'un peu loin.
	vue._cible = mo.pose * centre
	vue._distance = 2.5
	vue._caler()
	var faces_avant: int = m.faces.size()
	var avant_tuiles := {}
	for k in t.tuiles:
		avant_tuiles[k] = t.tuiles[k].sommets.size()
	ed._input(_cle(KEY_K))
	if mo.modal != "knife":
		print("  %s / %s : K n'a pas pris le couteau (modal « %s »)" % [cle, mode, mo.modal])
		return
	var poses: Array = []
	for p in points:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = true
		e.position = cam.unproject_position(mo.pose * p)
		vue._gui_input(e)
		var r := e.duplicate()
		r.pressed = false
		vue._gui_input(r)
		poses.append(mo._couteau.size())
	# LE DIAGNOSTIC : le tracé tel que le couteau le calculera, et pour chaque morceau, ce qui le ferait échouer.
	var trace: Dictionary = mo._trace_du_couteau(mo._couteau)
	var diag := ""
	if trace.has("erreur"):
		diag = "tracé : " + str(trace["erreur"])
	else:
		var morceaux: Array = []
		for e in trace["points"]:
			if morceaux.is_empty() or int(morceaux[-1]["occ"]) != int(e["occ"]):
				morceaux.append({"occ": int(e["occ"]), "points": []})
			(morceaux[-1]["points"] as Array).append(e["local"])
		for mc in morceaux:
			var tuile: RefCounted = t.tuiles[t.occurrences[int(mc["occ"])]["cle"]]
			var pts: Array = mc["points"]
			for k in pts.size():
				if tuile.point_de_coupe(pts[k]).is_empty():
					diag += " [occ %d : point %d sur aucune arête]" % [mc["occ"], k]
			for k in range(pts.size() - 1):
				if not mo._face_commune(tuile, pts[k], pts[k + 1]):
					diag += " [occ %d : points %d-%d sans face commune]" % [mc["occ"], k, k + 1]
			# La coupe d'essai, pas à pas, sur une copie, comme `couper_aux_positions` : quel pas échoue, et comment.
			var essai: RefCounted = tuile.copie()
			var ids: Array = []
			var nature: Array = []
			for k in pts.size():
				var q: Dictionary = essai.point_de_coupe(pts[k])
				if q.is_empty():
					diag += " [occ %d : point %d introuvable]" % [mc["occ"], k]
					break
				var e: Vector2i = q["arete"]
				var tt: float = q["t"]
				var i: int = e.x if tt < 1e-4 else (e.y if tt > 1.0 - 1e-4 else essai._inserer_sur_arete(e, q["point"]))
				nature.append("s" if (tt < 1e-4 or tt > 1.0 - 1e-4) else "a")
				if ids.is_empty() or ids[-1] != i:
					ids.append(i)
			for k in range(ids.size() - 1):
				var communes := 0
				for fe: PackedInt32Array in essai.faces:
					if Array(fe).has(ids[k]) and Array(fe).has(ids[k + 1]):
						communes += 1
				if not essai._fendre(ids[k], ids[k + 1]):
					diag += " [occ %d : pas %d → %d refusé, %d face(s) les portent tous deux ; points %s]" % [mc["occ"], ids[k], ids[k + 1], communes, nature]
	var clics: String = str(mo._couteau.map(func(p): return [p.get("occ", -1), p["arete"], snappedf(p["t"], 0.01)]))
	if not trace.has("erreur"):
		clics += " → tracé " + str((trace["points"] as Array).map(func(e): return [e["occ"], (e["local"] as Vector3).snappedf(0.01)]))
	var photo := {}
	for k in t.tuiles:
		photo[k] = t.tuiles[k].sommets.size()
	ed._input(_cle(KEY_ENTER))
	var autres := 0
	for k in t.tuiles:
		if k != cle and t.tuiles[k].sommets.size() != avant_tuiles[k]:
			autres += 1
	var orphelins := _sans_partenaire(t)
	var rapport: String = ed._rapport.text.substr(0, 110).replace("\n", " ")
	print("  %s / %s : points posés %s, faces %d → %d, %d autres tuiles, %d sans partenaire, « %s »%s"
		% [cle, mode, poses, faces_avant, mo.maillage.faces.size(), autres, orphelins, rapport,
		("  DIAG" + diag) if diag != "" else ("  CLICS " + clics if rapport.contains("Nothing") else "")])
	var change: bool = t.tuiles.keys().any(func(k): return t.tuiles[k].sommets.size() != photo[k])
	if change:
		ed._unhandled_key_input(_cle(KEY_Z, true))
		var rendues := 0
		for k in t.tuiles:
			if t.tuiles[k].sommets.size() == avant_tuiles[k]:
				rendues += 1
		if rendues != t.tuiles.size():
			print("    ⚠ Ctrl+Z ne rend que %d tuiles sur %d" % [rendues, t.tuiles.size()])
	if mo.modal != "":
		mo.modal = ""


## Recopié de `test_sections` : un sommet sur un joint du monde sans le sommet de la tuile d'en face.
func _sans_partenaire(t: RefCounted) -> int:
	var occ := {}
	for o in t.occurrences:
		occ[o["sommet"]] = o
	var n := 0
	for s in occ:
		var oa: Dictionary = occ[s]
		for axe in 3:
			for sens in [-1, 1]:
				var e := Vector3i.ZERO
				e[axe] = sens
				if not occ.has(s + e):
					continue
				var ob: Dictionary = occ[s + e]
				var tb: RefCounted = t.tuiles[ob["cle"]]
				var index_b := {}
				for j in tb.sommets.size():
					index_b[Vector3i(((ob["pose"] as Transform3D) * tb.sommets[j] * 10000.0).round())] = true
				var ta: RefCounted = t.tuiles[oa["cle"]]
				var plan: float = float(s[axe]) + 1.0 + 0.5 * sens
				for i in ta.sommets.size():
					var pw: Vector3 = (oa["pose"] as Transform3D) * ta.sommets[i]
					if absf(pw[axe] - plan) <= 0.0005 and not index_b.has(Vector3i((pw * 10000.0).round())):
						n += 1
	return n


func _cle(k: Key, ctrl := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	e.ctrl_pressed = ctrl
	return e
